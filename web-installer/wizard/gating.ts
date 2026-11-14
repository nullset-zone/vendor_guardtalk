/** UI gates. Flashcore still enforces lock-before-complete and LockSafetyError. */

import {
  UsbDisconnectError,
  UsbPermissionError,
  UsbTimeoutError,
} from "../src/errors.js";

export type WizardMode = "preview" | "dry-run" | "live";

export type WizardStepId =
  | "prerequisites"
  | "oem-unlock"
  | "connect"
  | "unlock"
  | "download"
  | "flash"
  | "lock"
  | "verify";

export interface WizardStepMeta {
  readonly number: number;
  readonly id: WizardStepId;
  readonly title: string;
}

export const WIZARD_STEPS: readonly WizardStepMeta[] = [
  { number: 1, id: "prerequisites", title: "Browser & USB prerequisites" },
  { number: 2, id: "oem-unlock", title: "Enable OEM unlocking" },
  { number: 3, id: "connect", title: "Connect device" },
  { number: 4, id: "unlock", title: "Unlock bootloader" },
  { number: 5, id: "download", title: "Download & verify release" },
  { number: 6, id: "flash", title: "Flash release" },
  { number: 7, id: "lock", title: "Safety-gated lock bootloader" },
  { number: 8, id: "verify", title: "Post-install verification" },
];

export interface WizardFlags {
  deviceSelected: boolean;
  channelLoaded: boolean;
  connected: boolean;
  unlocked: boolean;
  planComplete: boolean;
  artifactsReady: boolean;
  dryRun: boolean;
}

export interface SafetyLockGate {
  readonly confirmed: boolean;
  readonly operatorOverride: boolean;
  readonly isExperimentalOrUnverified: boolean;
}

export interface RecoverableUsbAssessment {
  readonly recoverable: boolean;
  readonly kind: "disconnect" | "timeout" | "permission" | "other";
  readonly guidance: string;
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

export function canLockWithSafety(flags: WizardFlags, safety: SafetyLockGate): boolean {
  if (!canLock(flags) || !safety.confirmed) {
    return false;
  }
  if (safety.isExperimentalOrUnverified && !safety.operatorOverride) {
    return false;
  }
  return true;
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

export function assertCanLockWithSafety(flags: WizardFlags, safety: SafetyLockGate): void {
  assertCanLock(flags);
  if (!safety.confirmed) {
    throw new WizardGateError(
      "flashing lock requires explicit confirmation that you understand userdata wipe and lock risks",
    );
  }
  if (safety.isExperimentalOrUnverified && !safety.operatorOverride) {
    throw new WizardGateError(
      "flashing lock is blocked on unverified or experimental targets unless operator override is enabled",
    );
  }
}

export function classifyRecoverableUsbError(err: unknown): RecoverableUsbAssessment {
  if (err instanceof UsbDisconnectError) {
    return {
      recoverable: true,
      kind: "disconnect",
      guidance:
        "USB cable or session disconnected. Confirm the Pixel is still in Fastboot Mode, re-seat the cable, and click Connect / Reconnect to resume.",
    };
  }
  if (err instanceof UsbTimeoutError) {
    return {
      recoverable: true,
      kind: "timeout",
      guidance:
        "USB transfer timed out. On Linux stop fwupd (systemctl stop fwupd.service) and kill any local adb daemon (adb kill-server), then retry.",
    };
  }
  if (err instanceof UsbPermissionError) {
    return {
      recoverable: true,
      kind: "permission",
      guidance:
        "WebUSB permission was denied or lost. Re-open the browser USB device picker, select the Pixel, and grant access.",
    };
  }
  if (err instanceof Error) {
    const name = err.name;
    const msg = err.message.toLowerCase();
    if (name === "NotFoundError" || name === "SecurityError" || msg.includes("permission") || msg.includes("claiminterface")) {
      return {
        recoverable: true,
        kind: "permission",
        guidance:
          "Browser could not claim the USB interface. Run `adb kill-server`, check udev rules (Linux), and re-select the Pixel in the WebUSB picker.",
      };
    }
    if (name === "NetworkError" || msg.includes("disconnect") || msg.includes("transfer")) {
      return {
        recoverable: true,
        kind: "disconnect",
        guidance:
          "USB transport dropped. Keep the Pixel in Fastboot Mode, reconnect the cable (prefer USB-A/direct port), and retry.",
      };
    }
    if (msg.includes("timeout") || msg.includes("timed out")) {
      return {
        recoverable: true,
        kind: "timeout",
        guidance:
          "USB operation timed out. Confirm the device is responsive in Fastboot Mode and retry.",
      };
    }
  }
  return {
    recoverable: false,
    kind: "other",
    guidance: "Review the activity log for the specific error before retrying.",
  };
}
