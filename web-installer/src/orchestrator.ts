import { assertAllowedProduct } from "./allowlist.js";
import {
  FastbootError,
  LiveExecuteHoldError,
  LockBeforeCompleteError,
  LockCancelledError,
  UnlockCancelledError,
  WrongProductError,
} from "./errors.js";
import { assertSha256Match } from "./hash.js";
import { buildFlashPlan } from "./plan.js";
import type {
  ArtifactStore,
  ChannelBundle,
  FastbootTransport,
  FlashPlan,
  PlanStep,
  ReconnectHook,
} from "./types.js";
import { isDryRunTransport, LIVE_FLASH_CLAIMED } from "./types.js";

export interface OrchestratorHooks {
  onReconnect: ReconnectHook;
}

export class FlashOrchestrator {
  private readonly transport: FastbootTransport;
  private readonly channel: ChannelBundle;
  private readonly store: ArtifactStore;
  private readonly plan: FlashPlan;
  private connected = false;
  private planComplete = false;

  constructor(opts: {
    transport: FastbootTransport;
    channel: ChannelBundle;
    store: ArtifactStore;
  }) {
    this.transport = opts.transport;
    this.channel = opts.channel;
    this.store = opts.store;
    this.plan = buildFlashPlan(opts.channel);
  }

  getPlan(): FlashPlan {
    return this.plan;
  }

  isPlanComplete(): boolean {
    return this.planComplete;
  }

  claimsLiveFlash(): boolean {
    return LIVE_FLASH_CLAIMED;
  }

  async connect(): Promise<void> {
    await this.transport.connect();
    this.connected = true;
    await this.assertProduct();
  }

  async unlock(): Promise<void> {
    this.requireConnected();
    const unlocked = await this.transport.getVar("unlocked");
    if (unlocked.trim().toLowerCase() === "yes") {
      return;
    }
    const result = await this.transport.runCommand("flashing unlock");
    if (!result.ok) {
      throw new UnlockCancelledError();
    }
  }

  async executePlan(hooks: OrchestratorHooks): Promise<void> {
    this.assertDryRunOnly("execute");
    this.requireConnected();
    await this.assertProduct();
    await this.maybeCancelSnapshot();
    for (const step of this.plan.steps) {
      await this.runStep(step, hooks.onReconnect);
    }
    this.planComplete = true;
  }

  async lock(): Promise<void> {
    this.assertDryRunOnly("lock");
    this.requireConnected();
    if (!this.planComplete) {
      throw new LockBeforeCompleteError();
    }
    const result = await this.transport.runCommand("flashing lock");
    if (!result.ok) {
      throw new LockCancelledError();
    }
  }

  private assertDryRunOnly(action: "execute" | "lock"): void {
    if (!isDryRunTransport(this.transport)) {
      throw new LiveExecuteHoldError(action);
    }
  }

  private requireConnected(): void {
    if (!this.connected) {
      throw new FastbootError("connect() before unlock, flash, or lock");
    }
  }

  private async assertProduct(): Promise<void> {
    const product = (await this.transport.getVar("product")).trim();
    assertAllowedProduct(product);
    if (product !== this.channel.manifest.product) {
      throw new WrongProductError(product);
    }
  }

  private async maybeCancelSnapshot(): Promise<void> {
    let status = "none";
    try {
      status = (await this.transport.getVar("snapshot-update-status")).trim();
    } catch {
      status = "none";
    }
    if (status !== "" && status !== "none") {
      const result = await this.transport.runCommand("snapshot-update:cancel");
      if (!result.ok) {
        throw new FastbootError("snapshot-update:cancel failed");
      }
    }
  }

  private async runStep(step: PlanStep, onReconnect: ReconnectHook): Promise<void> {
    if (step.kind === "flash") {
      await this.flashVerified(step.artifact, step.partition);
      return;
    }
    if (step.kind === "erase") {
      await this.requireOk(`erase:${step.partition}`);
      return;
    }
    if (step.kind === "command") {
      await this.requireOk(step.command);
      return;
    }
    await this.transport.rebootBootloader(onReconnect);
  }

  private async flashVerified(name: string, partition: string): Promise<void> {
    const expected = this.channel.sha256sums.get(name);
    if (expected === undefined) {
      throw new FastbootError(`no SHA-256 for ${name}`);
    }
    const data = await this.store.read(name);
    assertSha256Match(name, data, expected);
    await this.transport.flash(partition, data);
  }

  private async requireOk(command: string): Promise<void> {
    const result = await this.transport.runCommand(command);
    if (!result.ok) {
      throw new FastbootError(`fastboot '${command}' failed`);
    }
  }
}
