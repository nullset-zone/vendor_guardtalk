/** UI gates. Flashcore still enforces lock-before-complete. */

export type WizardMode = "preview" | "dry-run" | "live";

export interface WizardFlags {
  deviceSelected: boolean;
  channelLoaded: boolean;
  connected: boolean;
  unlocked: boolean;
  planComplete: boolean;
  artifactsReady: boolean;
  dryRun: boolean;
}

export class WizardGateError extends Error {
  readonly code = "WIZARD_GATE";

  constructor(message: string) {
    super(message);
    this.name = "WizardGateError";
  }
}

export function canConnect(flags: WizardFlags): boolean {
  return flags.deviceSelected && flags.channelLoaded;
}

export function canUnlock(flags: WizardFlags): boolean {
  return flags.deviceSelected && flags.connected;
}

export function canFlash(flags: WizardFlags): boolean {
  return (
    flags.deviceSelected &&
    flags.channelLoaded &&
    flags.connected &&
    flags.unlocked &&
    flags.artifactsReady &&
    flags.dryRun
  );
}

export function canLock(flags: WizardFlags): boolean {
  return flags.planComplete && flags.dryRun;
}

export function canPreviewPlan(flags: WizardFlags): boolean {
  return flags.channelLoaded;
}

export function assertCanUnlock(flags: WizardFlags): void {
  if (!canUnlock(flags)) {
    throw new WizardGateError("connect the device before unlock");
  }
}

export function assertCanFlash(flags: WizardFlags): void {
  if (!flags.unlocked) {
    throw new WizardGateError("unlock the bootloader before flash");
  }
  if (!canFlash(flags)) {
    throw new WizardGateError("flash is gated until connect, unlock, and artifacts");
  }
}

export function assertCanLock(flags: WizardFlags): void {
  if (!canLock(flags)) {
    throw new WizardGateError("lock is gated until the flash plan completes");
  }
}
