/**
 * SimulatedDevice — a deterministic in-memory fastboot device implementing the
 * same Transport interface as WebUsbFastbootTransport (client.ts Transport).
 *
 * This is THE E2E backbone: every scripted behaviour is explicit and
 * reproducible — no timers, no randomness, no real hardware (D-011).
 *
 * Scripted state:
 *   - product / bootloader / max-download-size vars
 *   - lock state; unlock/lock transitions with optional refusal
 *   - partition store Map<name, bytes>; flash/erase mutate it
 *   - failure injection: see FailureInjection
 *
 * Wire format matches protocol.ts exactly (OKAY/FAIL/INFO/DATA + 08x sizes),
 * so FastbootClient cannot tell it apart from a real device by shape.
 */
import { encodeCommand, wireToCommand } from "./protocol.js";
import type { Transport } from "./client.js";

export interface DeviceVars {
  product: string;
  bootloader: string;
  "max-download-size": string;
  /** Extra getvar names (enrolled-key hashes, oem vars) used by verify-device. */
  [name: string]: string | undefined;
}

export type InjectionKind =
  | "failNthFlash"
  | "wrongProduct"
  | "refuseUnlock"
  | "refuseLock";

export interface FailureInjection {
  kind: InjectionKind;
  /** For failNthFlash: 1-based index of the flash command that must FAIL. */
  nth?: number;
  /** Verbatim FAIL reason injected into the response. */
  reason: string;
}

export interface SimulatedDeviceOptions {
  vars?: Partial<DeviceVars>;
  initiallyUnlocked?: boolean;
  injection?: FailureInjection;
  /** Seed partitions (e.g. stock images). Keys are partition names. */
  partitions?: Map<string, Uint8Array>;
}

export class SimulatedDevice implements Transport {
  readonly vars: DeviceVars;
  readonly partitions = new Map<string, Uint8Array>();
  unlocked: boolean;
  injection: FailureInjection | undefined;

  /** Every wire event, verbatim (`> cmd` / `< resp`) — mirrors ConsoleLog. */
  readonly transcript: string[] = [];

  private flashCount = 0;
  /** Partition write cursors: consecutive flash:s append (sparse streaming). */
  private writeCursors = new Map<string, number>();
  private lastFlashPartition: string | null = null;
  private pendingDownload: Uint8Array | null = null;
  private queue: Uint8Array[] = [];
  private closed = false;

  constructor(options: SimulatedDeviceOptions = {}) {
    this.vars = {
      product: options.vars?.product ?? "tokay",
      bootloader: options.vars?.bootloader ?? "tokay-1.0-00000000",
      "max-download-size": options.vars?.["max-download-size"] ?? "268435456",
    };
    this.unlocked = options.initiallyUnlocked ?? false;
    this.injection = options.injection;
    if (options.partitions !== undefined) {
      for (const [k, v] of options.partitions) {
        this.partitions.set(k, v.slice());
      }
    }
  }

  // --- Transport interface ----------------------------------------------------

  async send(command: string): Promise<void> {
    this.assertOpen();
    // Canonical boundary: string in → bytes via protocol.encodeCommand →
    // decoded back with wireToCommand, exactly like a real USB read path.
    const encoded = encodeCommand(command);
    const text = wireToCommand(encoded);
    this.transcript.push(`> ${text}`);
    const responses = this.handle(text);
    this.queue.push(...responses);
  }

  async readPacket(): Promise<Uint8Array> {
    this.assertOpen();
    const next = this.queue.shift();
    if (next === undefined) {
      throw new Error("simulated device has no queued response");
    }
    return next;
  }

  async transfer(data: Uint8Array): Promise<void> {
    this.assertOpen();
    if (this.pendingDownload === null) {
      throw new Error("transfer without download:");
    }
    if (data.length !== this.pendingDownload.length) {
      throw new Error(
        `download payload size mismatch: expected ${String(this.pendingDownload.length)}, got ${String(data.length)}`,
      );
    }
    this.pendingDownload = data.slice();
    // Real bootloaders send the terminal OKAY only after the payload lands.
    this.queue.push(encodeCommand("OKAY"));
  }

  /** Idempotent close; further commands throw like an unplugged device. */
  /**
   * Test-only: drop a published getvar so the next query FAILs (H1).
   * Production callers never omit a required var.
   */
  forgetVar(name: keyof DeviceVars): void {
    delete (this.vars as unknown as Record<string, string | undefined>)[name];
  }

  /**
   * Test-only: prepend packets so they are read before the device's own
   * response (INFO/FAIL injection around a handshake).
   */
  queueAheadForTests(packets: readonly Uint8Array[]): void {
    this.queue.unshift(...packets);
  }

  async close(): Promise<void> {
    await new Promise<void>((resolve) => {
      setTimeout(resolve, 0);
    });
    this.closed = true;
  }

  private assertOpen(): void {
    if (this.closed) {
      throw new Error("simulated device is closed");
    }
  }

  // --- Scripted behaviour -----------------------------------------------------

  fail(reason: string): Uint8Array[] {
    return [encodeCommand(`FAIL${reason}`)];
  }

  okay(): Uint8Array[] {
    return [encodeCommand("OKAY")];
  }

  private handle(command: string): Uint8Array[] {
    if (command.startsWith("getvar:")) {
      const name = command.slice("getvar:".length).trim();
      const table = this.vars as unknown as Record<string, string | undefined>;
      const value = table[name];
      if (value === undefined) {
        return this.fail(`unknown variable ${name}`);
      }
      return [encodeCommand(`OKAY${value}`)];
    }
    if (command.startsWith("download:")) {
      const size = Number.parseInt(command.slice("download:".length), 16);
      this.pendingDownload = new Uint8Array(size);
      return [encodeCommand(`DATA${size.toString(16).padStart(8, "0")}`)];
    }
    if (command.startsWith("flash:")) {
      const partition = command.slice("flash:".length).trim();
      if (this.pendingDownload === null) {
        return this.fail(`no data downloaded for ${partition}`);
      }
      const injected = this.injectedFlashFailure();
      if (injected !== undefined) {
        this.flashCount += 1;
        return this.fail(injected);
      }
      // Fastboot streaming semantics: a download: larger than the device's
      // max-download-size is transferred as consecutive download:+flash:
      // pairs, each appending at the partition's write cursor. A flash: for a
      // DIFFERENT partition retires the previous stream.
      const continues =
        this.lastFlashPartition === partition &&
        (this.writeCursors.get(partition) ?? 0) > 0;
      const merged = concatInto(
        continues ? this.partitions.get(partition) : undefined,
        this.pendingDownload,
      );
      this.partitions.set(partition, merged);
      this.writeCursors.set(partition, merged.length);
      if (this.lastFlashPartition !== null && this.lastFlashPartition !== partition) {
        this.writeCursors.delete(this.lastFlashPartition);
      }
      this.lastFlashPartition = partition;
      this.pendingDownload = null;
      this.flashCount += 1;
      return this.okay();
    }
    if (command.startsWith("erase:")) {
      const partition = command.slice("erase:".length).trim();
      this.partitions.delete(partition);
      this.writeCursors.delete(partition);
      return this.okay();
    }
    if (command === "flashing unlock") {
      if (!this.unlocked && this.injection?.kind === "refuseUnlock") {
        return this.fail(this.injection.reason);
      }
      this.unlocked = true;
      return [encodeCommand("OKAY"), encodeCommand("INFOunlock in progress...")];
    }
    if (command === "flashing lock") {
      if (this.unlocked && this.injection?.kind === "refuseLock") {
        return this.fail(this.injection.reason);
      }
      this.unlocked = false;
      return this.okay();
    }
    if (command === "reboot" || command.startsWith("reboot-")) {
      return this.okay();
    }
    if (command.startsWith("oem ")) {
      return this.fail("simulated device does not implement oem");
    }
    return this.fail(`unsupported command ${JSON.stringify(command)}`);
  }

  private injectedFlashFailure(): string | undefined {
    const injection = this.injection;
    if (injection?.kind !== "failNthFlash") {
      return undefined;
    }
    const nth = injection.nth ?? 1;
    if (this.flashCount + 1 === nth) {
      return injection.reason;
    }
    return undefined;
  }
}

/** Append `slice` after any bytes already stored for this partition. */
function concatInto(existing: Uint8Array | undefined, slice: Uint8Array): Uint8Array {
  if (existing === undefined || existing.length === 0) {
    return slice.slice();
  }
  const out = new Uint8Array(existing.length + slice.length);
  out.set(existing, 0);
  out.set(slice, existing.length);
  return out;
}
