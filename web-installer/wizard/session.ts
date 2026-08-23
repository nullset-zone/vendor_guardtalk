import { assertAllowedProduct } from "../src/allowlist.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { FlashcoreError, LiveExecuteHoldError } from "../src/errors.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import { buildFlashPlan } from "../src/plan.js";
import { MemoryArtifactStore } from "../src/store.js";
import { adaptAndroidFastboot, type AndroidFastbootDevice } from "../src/transport.js";
import type {
  ArtifactStore,
  ChannelBundle,
  FastbootTransport,
  FlashPlan,
  ReconnectHook,
} from "../src/types.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import {
  rebootAndroidToBootloader,
  type RebootToFastbootDeps,
} from "./adb-reboot.js";
import { WIZARD_DEVICES, isOfferedDevice } from "./devices.js";
import { DryRunTransport } from "./dry-run.js";
import {
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
} from "./gating.js";
import { assessQuota, type QuotaAssessment, type StorageEstimateInput } from "./quota.js";

export interface ChannelTexts {
  manifestJson: string;
  sha256sums: string;
  filesTxt: string;
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
  private mode: WizardMode = "preview";

  selectDevice(id: string): void {
    if (!isOfferedDevice(id)) {
      throw new WizardGateError(`device '${id}' is not offered`);
    }
    assertAllowedProduct(id);
    this.device = id;
  }

  loadChannel(texts: ChannelTexts): FlashPlan {
    this.channel = loadChannelFromTexts(texts);
    const product = this.channel.manifest.product;
    if (isOfferedDevice(product)) {
      this.device = product;
    }
    this.plan = buildFlashPlan(this.channel);
    this.orchestrator = null;
    this.connected = false;
    this.unlocked = false;
    return this.plan;
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

  async connect(): Promise<void> {
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
  }

  async unlock(): Promise<void> {
    assertCanUnlock(this.flags());
    await this.requireOrchestrator().unlock();
    this.unlocked = true;
  }

  async executePlan(onReconnect: ReconnectHook): Promise<void> {
    this.assertDryRunOnly("execute");
    assertCanFlash(this.flags());
    await this.requireOrchestrator().executePlan({ onReconnect });
  }

  async lock(): Promise<void> {
    this.assertDryRunOnly("lock");
    assertCanLock(this.flags());
    await this.requireOrchestrator().lock();
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
      });
    }
    return this.orchestrator;
  }
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
