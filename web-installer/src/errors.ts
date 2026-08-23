/** Typed fail-closed errors for the tokay flash orchestrator. */

export class FlashcoreError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
  }
}

export class WrongProductError extends FlashcoreError {
  constructor(product: string) {
    super(
      "WRONG_PRODUCT",
      `product '${product}' is not in the advertised allowlist (tokay, akita)`,
    );
  }
}

export class UnlockCancelledError extends FlashcoreError {
  constructor() {
    super(
      "UNLOCK_CANCELLED",
      "bootloader unlock failed or was cancelled on the device",
    );
  }
}

export class LockCancelledError extends FlashcoreError {
  constructor() {
    super(
      "LOCK_CANCELLED",
      "bootloader lock failed or was cancelled on the device",
    );
  }
}

export class LockBeforeCompleteError extends FlashcoreError {
  constructor() {
    super(
      "LOCK_BEFORE_COMPLETE",
      "flashing lock is a final step and must not run before the flash plan completes",
    );
  }
}

export class HashMismatchError extends FlashcoreError {
  constructor(name: string) {
    super(
      "HASH_MISMATCH",
      `SHA-256 mismatch for '${name}' (fail closed)`,
    );
  }
}

export class ChannelError extends FlashcoreError {
  constructor(message: string) {
    super("CHANNEL_INVALID", message);
  }
}

export class PlanError extends FlashcoreError {
  constructor(message: string) {
    super("PLAN_INVALID", message);
  }
}

export class FastbootError extends FlashcoreError {
  constructor(message: string) {
    super("FASTBOOT", message);
  }
}

/** WebUSB ADB helper (stock Android → bootloader). Not a flash path. */
export class AdbError extends FlashcoreError {
  constructor(message: string) {
    super("WEBUSB_ADB", message);
  }
}

/** DEC-009: live executePlan/lock is HOLD until a later Architect card. */
export class LiveExecuteHoldError extends FlashcoreError {
  constructor(action: "execute" | "lock") {
    super(
      "LIVE_EXECUTE_HOLD",
      `DEC-009: live ${action} is HOLD. Dry-run only; this is not flash-from-remote.sh.`,
    );
  }
}
