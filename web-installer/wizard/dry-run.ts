import type {
  CommandResult,
  FastbootTransport,
  FlashOptions,
  ReconnectHook,
} from "../src/types.js";

/**
 * Host/browser stand-in. Does not open USB and must not be reported as a live flash.
 */
export class DryRunTransport implements FastbootTransport {
  readonly dryRun = true as const;
  product = "tokay";
  unlocked = "no";
  snapshot = "none";
  connectCalls = 0;
  reconnects = 0;
  readonly flashed: string[] = [];

  async connect(): Promise<void> {
    this.connectCalls += 1;
  }

  async getVar(name: string): Promise<string> {
    if (name === "product") {
      return this.product;
    }
    if (name === "unlocked") {
      return this.unlocked;
    }
    if (name === "snapshot-update-status") {
      return this.snapshot;
    }
    throw new Error(`dry-run getvar '${name}' is not simulated`);
  }

  async runCommand(command: string): Promise<CommandResult> {
    if (command === "flashing unlock") {
      this.unlocked = "yes";
      return { ok: true, text: "OKAY" };
    }
    if (command === "flashing lock") {
      this.unlocked = "no";
      return { ok: true, text: "OKAY" };
    }
    return { ok: true, text: "OKAY" };
  }

  async flash(partition: string, _data: Uint8Array, _options?: FlashOptions): Promise<void> {
    this.flashed.push(partition);
  }

  async rebootBootloader(onReconnect: ReconnectHook): Promise<void> {
    await onReconnect();
    this.reconnects += 1;
    this.connectCalls += 1;
  }
}
