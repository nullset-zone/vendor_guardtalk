import { assertAllowedProduct } from "./allowlist.js";
import {
  FastbootError,
  LiveExecuteHoldError,
  LockBeforeCompleteError,
  LockCancelledError,
  LockSafetyError,
  UnlockCancelledError,
  WrongProductError,
} from "./errors.js";
import { assertSha256Match } from "./hash.js";
import { buildFlashPlan, type FlashPlanOptions } from "./plan.js";
import type {
  ArtifactStore,
  ChannelBundle,
  FastbootTransport,
  FlashOptions,
  FlashPlan,
  PlanStep,
  ReconnectHook,
} from "./types.js";
import { isDryRunTransport, LIVE_FLASH_CLAIMED } from "./types.js";

export interface OrchestratorHooks {
  onReconnect: ReconnectHook;
  /** DEC-009 explicit opt-in required to execute a plan on a live (non-dryRun) transport. */
  allowLiveExecute?: boolean;
}

export interface LockOptions {
  /** Explicit user confirmation of destructive userdata wipe + bootloader lock. */
  confirmed?: boolean;
  /** DEC-009 explicit opt-in required to lock on a live (non-dryRun) transport. */
  allowLiveLock?: boolean;
  /** Explicit operator override to lock an unverified or experimental target. */
  operatorOverride?: boolean;
}

export class FlashOrchestrator {
  private readonly transport: FastbootTransport;
  private readonly channel: ChannelBundle;
  private readonly store: ArtifactStore;
  private readonly plan: FlashPlan;
  private readonly planOptions: FlashPlanOptions | undefined;
  private connected = false;
  private planComplete = false;
  /**
   * Idempotent teardown of the transport, present only if the transport offers
   * one (WebUSB does; the dry-run mock and the simulator do not).
   */
  private readonly teardown: (() => Promise<void>) | undefined;

  constructor(opts: {
    transport: FastbootTransport;
    channel: ChannelBundle;
    store: ArtifactStore;
    planOptions?: FlashPlanOptions;
  }) {
    this.transport = opts.transport;
    this.channel = opts.channel;
    this.store = opts.store;
    this.planOptions = opts.planOptions;
    const close = (opts.transport as { close?: unknown }).close;
    this.teardown =
      typeof close === "function" ? () => (close.call(opts.transport) as Promise<void>) : undefined;
    this.plan = buildFlashPlan(opts.channel, opts.planOptions);
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

  /**
   * Connect and PROVE the product before the session is usable
   * (T-WEBINSTALL-ORCHESTRATOR-CONNECT-LEAK). `connected` is set only after
   * `assertProduct()` resolves, so no interleaving leaves it true while the
   * product assertion has not succeeded. A failed assertion tears the
   * transport down (when it can be) rather than leaving a claimed device
   * sitting in a session that refuses to use it.
   */
  async connect(): Promise<void> {
    await this.transport.connect();
    try {
      await this.assertProduct();
    } catch (error) {
      this.connected = false;
      await this.teardownAfterFailedConnect();
      throw error;
    }
    this.connected = true;
  }

  async getCurrentSlot(): Promise<string> {
    this.requireConnected();
    return (await this.transport.getVar("current-slot")).trim();
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
    this.assertDryRunOrOptIn("execute", hooks.allowLiveExecute);
    this.requireConnected();
    await this.assertProduct();
    await this.maybeCancelSnapshot();
    for (const step of this.plan.steps) {
      await this.runStep(step, hooks.onReconnect);
    }
    this.planComplete = true;
  }

  async lock(options?: LockOptions): Promise<void> {
    this.assertDryRunOrOptIn("lock", options?.allowLiveLock);
    this.requireConnected();
    if (!this.planComplete) {
      throw new LockBeforeCompleteError();
    }
    this.assertLockSafety(options);
    const result = await this.transport.runCommand("flashing lock");
    if (!result.ok) {
      throw new LockCancelledError();
    }
  }

  private assertDryRunOrOptIn(action: "execute" | "lock", optIn: boolean | undefined): void {
    if (!isDryRunTransport(this.transport) && optIn !== true) {
      throw new LiveExecuteHoldError(action);
    }
  }

  private assertLockSafety(options: LockOptions | undefined): void {
    const isLive = !isDryRunTransport(this.transport);
    if (!isLive && options === undefined) {
      return;
    }
    if (options?.confirmed !== true) {
      throw new LockSafetyError(
        "flashing lock requires explicit confirmation (confirmed: true)",
      );
    }
    const { product, verifiedBootClaim, bootState } = this.channel.manifest;
    const isUnverifiedOrExperimental =
      product === "rango" ||
      verifiedBootClaim === "none" ||
      bootState === "unlocked";
    if (isUnverifiedOrExperimental && options.operatorOverride !== true) {
      throw new LockSafetyError(
        `refusing flashing lock on unverified/experimental target '${product}' ` +
          `(verifiedBootClaim=${verifiedBootClaim}, bootState=${bootState}) without operatorOverride: true`,
      );
    }
  }

  private requireConnected(): void {
    if (!this.connected) {
      throw new FastbootError("connect() before unlock, flash, or lock");
    }
  }

  /**
   * Best-effort teardown after a rejected product assertion. A transport
   * without a close path is left as-is (no invented requirement); a close that
   * itself fails must never mask the product error that caused the teardown.
   */
  private async teardownAfterFailedConnect(): Promise<void> {
    if (this.teardown === undefined) {
      return;
    }
    try {
      await this.teardown();
    } catch {
      // Swallowed by design: the caller gets the product error, not a
      // secondary USB error. `connected` is already false either way.
    }
  }

  private async assertProduct(): Promise<void> {
    const product = (await this.transport.getVar("product")).trim();
    if (!this.planOptions?.allowExtendedProduct) {
      assertAllowedProduct(product);
    }
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
      const flashOpts: FlashOptions | undefined = step.slot ? { slot: step.slot } : undefined;
      await this.flashVerified(step.artifact, step.partition, flashOpts);
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
    if (step.kind === "wipe-super") {
      await this.wipeSuperVerified(step.artifact);
      return;
    }
    if (step.kind === "reboot-fastboot") {
      if (typeof this.transport.rebootFastboot !== "function") {
        throw new FastbootError("transport does not support rebootFastboot (fastbootd)");
      }
      await this.transport.rebootFastboot(onReconnect);
      const isUserspace = (await this.transport.getVar("is-userspace")).trim().toLowerCase();
      if (isUserspace !== "yes") {
        throw new FastbootError(
          `expected fastbootd (is-userspace=yes) after reboot-fastboot, got '${isUserspace}'`,
        );
      }
      return;
    }
    await this.transport.rebootBootloader(onReconnect);
  }

  private async flashVerified(
    name: string,
    partition: string,
    options?: FlashOptions,
  ): Promise<void> {
    const expected = this.channel.sha256sums.get(name);
    if (expected === undefined) {
      throw new FastbootError(`no SHA-256 for ${name}`);
    }
    const data = await this.store.read(name);
    assertSha256Match(name, data, expected);
    await this.transport.flash(partition, data, options);
  }

  private async wipeSuperVerified(name: string): Promise<void> {
    if (typeof this.transport.wipeSuper !== "function") {
      throw new FastbootError("transport does not support wipeSuper");
    }
    const expected = this.channel.sha256sums.get(name);
    if (expected === undefined) {
      throw new FastbootError(`no SHA-256 for ${name}`);
    }
    const data = await this.store.read(name);
    assertSha256Match(name, data, expected);
    await this.transport.wipeSuper(data);
  }

  private async requireOk(command: string): Promise<void> {
    const result = await this.transport.runCommand(command);
    if (!result.ok) {
      throw new FastbootError(`fastboot '${command}' failed`);
    }
  }
}
