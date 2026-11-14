import { assertAllowedProduct } from "../src/allowlist.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { FlashcoreError, LiveExecuteHoldError } from "../src/errors.js";
import { FlashOrchestrator, type LockOptions } from "../src/orchestrator.js";
import { buildFlashPlan, type FlashPlanOptions } from "../src/plan.js";
import { MemoryArtifactStore } from "../src/store.js";
import { adaptAndroidFastboot, type AndroidFastbootDevice } from "../src/transport.js";
import type {
  ArtifactStore,
  BootChainMode,
  ChannelBundle,
  CommandResult,
  FastbootTransport,
  FlashOptions,
  FlashPlan,
  FlashOrderPhase,
  PlanStep,
  ReconnectHook,
} from "../src/types.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import {
  rebootAndroidToBootloader,
  type RebootToFastbootDeps,
} from "./adb-reboot.js";
import { WIZARD_DEVICES, getWizardDevice, isOfferedDevice } from "./devices.js";
import { DryRunTransport } from "./dry-run.js";
import {
  type RecoverableUsbAssessment,
  type WizardFlags,
  type WizardMode,
  WizardGateError,
  assertCanFlash,
  assertCanLock,
  assertCanUnlock,
  canConnect,
  canFlash,
  canLock,
  canPreviewPlan,
  canUnlock,
  classifyRecoverableUsbError,
} from "./gating.js";
import { assessQuota, type QuotaAssessment, type StorageEstimateInput } from "./quota.js";

export interface ChannelTexts {
  manifestJson: string;
  sha256sums: string;
  filesTxt: string;
}

export interface FlashProgress {
  readonly completedSteps: number;
  readonly totalSteps: number;
  readonly percent: number;
  readonly phase: FlashOrderPhase;
  readonly label: string;
  readonly partition?: string;
  readonly artifact?: string;
  readonly slot?: "other";
}

export interface ExecutePlanOptions {
  readonly onReconnect: ReconnectHook;
  readonly onProgress?: (progress: FlashProgress) => void;
}

export interface DeviceTelemetry {
  readonly product: string;
  readonly currentSlot: string;
  readonly unlocked: boolean;
}

export interface ChannelMeta {
  readonly product: string;
  readonly sourceStamp: string;
  readonly channelLabel: string;
  readonly verifiedBootClaim: string;
  readonly bootState: string;
  readonly avbSha256: string;
  readonly artifactCount: number;
}

export class InstallWizard {
  private device: string | null = WIZARD_DEVICES[0]?.id ?? null;
  private channel: ChannelBundle | null = null;
  private plan: FlashPlan | null = null;
  private store: ArtifactStore | null = null;
  private transport: FastbootTransport | null = null;
  private orchestrator: FlashOrchestrator | null = null;
  private connected = false;
  private unlocked = false;
  private currentSlot = "unknown";
  private mode: WizardMode = "preview";
  private bootChain: BootChainMode = WIZARD_DEVICES[0]?.defaultBootChain ?? "gt";
  private superMode: "auto" | "super" | "super_empty" = "auto";
  private bootloaderDualSlot = true;

  selectDevice(id: string): void {
    if (!isOfferedDevice(id)) {
      throw new WizardGateError(`device '${id}' is not offered`);
    }
    assertAllowedProduct(id);
    this.device = id;
    const meta = getWizardDevice(id);
    if (meta) {
      this.bootChain = meta.defaultBootChain;
      this.superMode = "auto";
    }
  }

  getSelectedDevice(): string | null {
    return this.device;
  }

  setBootChain(mode: BootChainMode): FlashPlan | null {
    this.bootChain = mode;
    return this.rebuildPlanIfLoaded();
  }

  getBootChain(): BootChainMode {
    return this.bootChain;
  }

  setSuperMode(mode: "auto" | "super" | "super_empty"): FlashPlan | null {
    this.superMode = mode;
    return this.rebuildPlanIfLoaded();
  }

  setBootloaderDualSlot(enabled: boolean): FlashPlan | null {
    this.bootloaderDualSlot = enabled;
    return this.rebuildPlanIfLoaded();
  }

  private planOptions(): FlashPlanOptions {
    return {
      bootChain: this.bootChain,
      superMode: this.superMode,
      bootloaderDualSlot: this.bootloaderDualSlot,
      allowExtendedProduct: true,
    };
  }

  private rebuildPlanIfLoaded(): FlashPlan | null {
    if (this.channel === null) {
      return null;
    }
    this.plan = buildFlashPlan(this.channel, this.planOptions());
    this.orchestrator = null;
    return this.plan;
  }

  loadChannel(texts: ChannelTexts): FlashPlan {
    this.channel = loadChannelFromTexts(texts);
    const product = this.channel.manifest.product;
    if (isOfferedDevice(product)) {
      this.device = product;
      const meta = getWizardDevice(product);
      if (meta && !meta.supportedBootChains.includes(this.bootChain)) {
        this.bootChain = meta.defaultBootChain;
      }
    }
    this.plan = buildFlashPlan(this.channel, this.planOptions());
    this.orchestrator = null;
    this.connected = false;
    this.unlocked = false;
    this.currentSlot = "unknown";
    return this.plan;
  }

  getChannelMeta(): ChannelMeta | null {
    if (this.channel === null) {
      return null;
    }
    const m = this.channel.manifest;
    return {
      product: m.product,
      sourceStamp: m.sourceStamp,
      channelLabel: m.channelLabel,
      verifiedBootClaim: m.verifiedBootClaim,
      bootState: m.bootState,
      avbSha256: m.avb.sha256,
      artifactCount: m.artifacts.length,
    };
  }

  attachArtifacts(blobs: ReadonlyMap<string, Uint8Array>): void {
    this.attachStore(new MemoryArtifactStore(blobs));
  }

  attachStore(store: ArtifactStore): void {
    this.requireChannel();
    this.store = store;
    this.orchestrator = null;
  }

  useDryRunTransport(): DryRunTransport {
    const dry = new DryRunTransport();
    dry.product = this.device ?? this.channel?.manifest.product ?? "tokay";
    this.attachTransport(dry, "dry-run");
    return dry;
  }

  useLiveTransport(device: AndroidFastbootDevice): void {
    this.attachTransport(adaptAndroidFastboot(device), "live");
  }

  attachTransport(transport: FastbootTransport, mode: WizardMode): void {
    this.transport = transport;
    this.mode = mode;
    this.orchestrator = null;
    this.connected = false;
    this.unlocked = false;
    this.currentSlot = "unknown";
  }

  flags(): WizardFlags {
    return {
      deviceSelected: this.device !== null,
      channelLoaded: this.channel !== null,
      connected: this.connected,
      unlocked: this.unlocked,
      planComplete: this.orchestrator?.isPlanComplete() ?? false,
      artifactsReady: this.store !== null,
      dryRun: this.mode === "dry-run",
    };
  }

  gateState(): {
    connect: boolean;
    unlock: boolean;
    flash: boolean;
    lock: boolean;
    preview: boolean;
  } {
    const flags = this.flags();
    return {
      connect: canConnect(flags),
      unlock: canUnlock(flags),
      flash: canFlash(flags),
      lock: canLock(flags),
      preview: canPreviewPlan(flags),
    };
  }

  getPlan(): FlashPlan {
    if (this.plan === null) {
      throw new WizardGateError("load a channel before previewing the plan");
    }
    return this.plan;
  }

  assessStorage(estimate: StorageEstimateInput | null, privateModeHint = false): QuotaAssessment {
    const files = this.requireChannel().files;
    return assessQuota(files, estimate, privateModeHint);
  }

  currentMode(): WizardMode {
    return this.mode;
  }

  claimsLiveFlash(): boolean {
    return LIVE_FLASH_CLAIMED;
  }

  async rebootToFastboot(deps?: RebootToFastbootDeps): Promise<void> {
    await rebootAndroidToBootloader(deps ?? {});
  }

  async connect(): Promise<DeviceTelemetry> {
    if (!canConnect(this.flags())) {
      throw new WizardGateError("select a device and load a matching channel before connect");
    }
    const channel = this.requireChannel();
    if (this.device !== channel.manifest.product) {
      throw new WizardGateError(
        `selected '${this.device ?? "(none)"}' does not match channel '${channel.manifest.product}'`,
      );
    }
    const orch = this.requireOrchestrator();
    await orch.connect();
    this.connected = true;
    this.currentSlot = await this.safeReadVar("current-slot", "a");
    const unlockedRaw = await this.safeReadVar("unlocked", "no");
    this.unlocked = unlockedRaw.trim().toLowerCase() === "yes";
    return {
      product: channel.manifest.product,
      currentSlot: this.currentSlot,
      unlocked: this.unlocked,
    };
  }

  getTelemetry(): DeviceTelemetry | null {
    if (!this.connected || this.device === null) {
      return null;
    }
    return {
      product: this.device,
      currentSlot: this.currentSlot,
      unlocked: this.unlocked,
    };
  }

  private async safeReadVar(name: string, fallback: string): Promise<string> {
    if (this.transport === null) {
      return fallback;
    }
    try {
      const value = await this.transport.getVar(name);
      return value.trim() || fallback;
    } catch {
      return fallback;
    }
  }

  async unlock(): Promise<void> {
    assertCanUnlock(this.flags());
    await this.requireOrchestrator().unlock();
    this.unlocked = true;
  }

  async executePlan(onReconnectOrOptions: ReconnectHook | ExecutePlanOptions): Promise<void> {
    this.assertDryRunOnly("execute");
    assertCanFlash(this.flags());
    const opts: ExecutePlanOptions =
      typeof onReconnectOrOptions === "function"
        ? { onReconnect: onReconnectOrOptions }
        : onReconnectOrOptions;

    const orch = this.requireOrchestrator();
    if (!opts.onProgress) {
      await orch.executePlan({ onReconnect: opts.onReconnect });
      return;
    }

    const plan = this.getPlan();
    const totalSteps = plan.steps.length;
    let stepCursor = 0;
    const emitStep = (step: PlanStep) => {
      stepCursor += 1;
      const percent = totalSteps > 0 ? Math.min(100, Math.round((stepCursor / totalSteps) * 100)) : 100;
      const base = {
        completedSteps: stepCursor,
        totalSteps,
        percent,
        phase: step.phase,
        label: describeStep(step),
      };
      if (step.kind === "flash") {
        opts.onProgress?.({
          ...base,
          partition: step.partition,
          artifact: step.artifact,
          ...(step.slot ? { slot: step.slot } : {}),
        });
      } else if (step.kind === "erase") {
        opts.onProgress?.({ ...base, partition: step.partition });
      } else if (step.kind === "wipe-super") {
        opts.onProgress?.({ ...base, partition: "super", artifact: step.artifact });
      } else {
        opts.onProgress?.(base);
      }
    };

    const baseTransport = this.transport!;
    let lastCommandResult: Promise<CommandResult> | null = null;
    const wrappedTransport: FastbootTransport = {
      ...(baseTransport.dryRun !== undefined ? { dryRun: baseTransport.dryRun } : {}),
      connect: () => baseTransport.connect(),
      getVar: (name) => baseTransport.getVar(name),
      runCommand: async (command) => {
        const res = await baseTransport.runCommand(command);
        if (command !== "snapshot-update:cancel") {
          const step = plan.steps[stepCursor];
          if (step && (step.kind === "command" || step.kind === "erase")) {
            emitStep(step);
          }
        }
        return res;
      },
      flash: async (partition, data, options?: FlashOptions) => {
        await baseTransport.flash(partition, data, options);
        const step = plan.steps[stepCursor];
        if (step && step.kind === "flash") {
          emitStep(step);
        }
      },
      rebootBootloader: async (onReconnect) => {
        await baseTransport.rebootBootloader(onReconnect);
        const step = plan.steps[stepCursor];
        if (step && step.kind === "reconnect") {
          emitStep(step);
        }
      },
      ...(baseTransport.rebootFastboot
        ? {
            rebootFastboot: async (onReconnect: ReconnectHook) => {
              await baseTransport.rebootFastboot!(onReconnect);
              const step = plan.steps[stepCursor];
              if (step && step.kind === "reboot-fastboot") {
                emitStep(step);
              }
            },
          }
        : {}),
      ...(baseTransport.wipeSuper
        ? {
            wipeSuper: async (data: Uint8Array) => {
              await baseTransport.wipeSuper!(data);
              const step = plan.steps[stepCursor];
              if (step && step.kind === "wipe-super") {
                emitStep(step);
              }
            },
          }
        : {}),
      ...(baseTransport.close ? { close: () => baseTransport.close!() } : {}),
    };
    void lastCommandResult;

    const progressOrchestrator = new FlashOrchestrator({
      transport: wrappedTransport,
      channel: this.requireChannel(),
      store: this.store!,
      planOptions: this.planOptions(),
    });
    await progressOrchestrator.connect();
    await progressOrchestrator.executePlan({ onReconnect: opts.onReconnect });
    this.orchestrator = progressOrchestrator;
  }

  async lock(options?: LockOptions): Promise<void> {
    this.assertDryRunOnly("lock");
    assertCanLock(this.flags());
    await this.requireOrchestrator().lock(options);
    this.unlocked = false;
  }

  classifyError(err: unknown): RecoverableUsbAssessment {
    return classifyRecoverableUsbError(err);
  }

  describeError(err: unknown): string {
    if (err instanceof WizardGateError || err instanceof FlashcoreError) {
      return err.message;
    }
    if (err instanceof Error) {
      return err.message;
    }
    return "unexpected wizard failure";
  }

  private assertDryRunOnly(action: "execute" | "lock"): void {
    if (this.currentMode() !== "dry-run") {
      throw new LiveExecuteHoldError(action);
    }
  }

  private requireChannel(): ChannelBundle {
    if (this.channel === null) {
      throw new WizardGateError("load a hosted channel first");
    }
    return this.channel;
  }

  private requireOrchestrator(): FlashOrchestrator {
    const channel = this.requireChannel();
    if (this.store === null) {
      throw new WizardGateError("artifact blobs are required to run flashcore");
    }
    if (this.transport === null) {
      throw new WizardGateError("attach a transport (dry-run or live) first");
    }
    if (this.orchestrator === null) {
      this.orchestrator = new FlashOrchestrator({
        transport: this.transport,
        channel,
        store: this.store,
        planOptions: this.planOptions(),
      });
    }
    return this.orchestrator;
  }
}

function describeStep(step: PlanStep): string {
  if (step.kind === "flash") {
    const slotSuffix = step.slot ? ` (--slot=${step.slot})` : "";
    return `flash ${step.partition}${slotSuffix} ← ${step.artifact}`;
  }
  if (step.kind === "erase") {
    return `erase ${step.partition}`;
  }
  if (step.kind === "command") {
    return step.command;
  }
  if (step.kind === "wipe-super") {
    return `wipe-super ← ${step.artifact}`;
  }
  if (step.kind === "reboot-fastboot") {
    return `reboot-fastboot — ${step.reason}`;
  }
  return `reconnect — ${step.reason}`;
}

export function readOptionalFastbootDevice(): AndroidFastbootDevice | null {
  const holder = globalThis as typeof globalThis & {
    FastbootDevice?: new () => AndroidFastbootDevice;
  };
  if (typeof holder.FastbootDevice !== "function") {
    return null;
  }
  return new holder.FastbootDevice();
}
