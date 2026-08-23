/**
 * FastbootClient — the only component that speaks fastboot.
 *
 * Every command sent and every response received is recorded verbatim to an
 * injectable ConsoleLog sink (mono console requirement, PLAN §1 step 6).
 * FAIL responses throw FastbootError carrying the verbatim bootloader reason;
 * nothing is retried or swallowed here.
 */
import type { ConsoleLog } from "../types.js";
import {
  decodePacket,
  downloadCommand,
  eraseCommand,
  flashCommand,
  flashingLockCommand,
  flashingUnlockCommand,
  getvarCommand,
  MAX_DOWNLOAD_SIZE_VAR,
  parseDataSize,
  parseMaxDownloadSize,
  ProtocolError,
  rebootCommand,
} from "./protocol.js";
import { imageTransferUnits } from "./sparse.js";

export class FastbootError extends Error {
  /** Verbatim FAIL payload from the device. */
  readonly reason: string;
  readonly code = "FASTBOOT_FAIL";
  constructor(reason: string) {
    super(`fastboot FAIL: ${reason}`);
    this.name = this.constructor.name;
    this.reason = reason;
  }
}

export interface Progress {
  partition: string;
  bytesTotal: number;
  bytesSent: number;
  chunkIndex: number;
  chunkCount: number;
}

/** Transport contract: one command/response round-trip plus bulk data push. */
export interface Transport {
  /** Send one ASCII command; implementations encode via protocol.encodeCommand. */
  send(command: string): Promise<void>;
  readPacket(): Promise<Uint8Array>;
  transfer(data: Uint8Array): Promise<void>;
}

export interface FlashOptions {
  onProgress?: (progress: Progress) => void;
  signal?: AbortSignal;
  /**
   * Download budget (bytes), sourced from getvar max-download-size. When
   * omitted the client FETCHES it from the device itself before planning
   * (audit H1): there is no code path that downloads without a validated
   * budget, and an unusable variable aborts instead of guessing.
   */
  maxDownloadSize?: number;
}

export class FastbootClient {
  private readonly log: ConsoleLog;
  private readonly transport: Transport;

  constructor(transport: Transport, log: ConsoleLog = () => {}) {
    this.transport = transport;
    this.log = log;
  }

  /** `getvar:<var>` → OKAY value. Throws FastbootError with verbatim FAIL reason. */
  async getvar(variable: string): Promise<string> {
    this.log(`> ${getvarCommand(variable)}`);
    await this.transport.send(getvarCommand(variable));
    const packet = await this.readTerminal();
    expect(packet, "OKAY", `getvar:${variable}`);
    return packet.text;
  }

  async erase(partition: string): Promise<void> {
    const packet = await this.roundTrip(eraseCommand(partition));
    expect(packet, "OKAY", `erase:${partition}`);
  }

  async flashingUnlock(): Promise<void> {
    const packet = await this.roundTrip(flashingUnlockCommand());
    expect(packet, "OKAY", "flashing unlock");
  }

  async flashingLock(): Promise<void> {
    const packet = await this.roundTrip(flashingLockCommand());
    expect(packet, "OKAY", "flashing lock");
  }

  async reboot(target?: "bootloader"): Promise<void> {
    const packet = await this.roundTrip(rebootCommand(target));
    expect(packet, "OKAY", rebootCommand(target));
  }

  /**
   * download+flash sequence: `download:%08x` → `DATA%08x` → bulk transfer →
   * `OKAY` → `flash:<partition>` → `OKAY`. The download budget always comes
   * from the device (`getvar:max-download-size`, fetched here when not
   * supplied) and every image is planned by lib/fastboot/sparse.ts into
   * units that each fit that budget (H2): sparse expansions are packed
   * greedily, and a single logical unit larger than the budget aborts BEFORE
   * any transfer instead of being re-split across flash: restarts.
   */
  async flash(partition: string, data: Uint8Array, options: FlashOptions = {}): Promise<void> {
    const budget =
      options.maxDownloadSize !== undefined
        ? assertPositiveBudget(options.maxDownloadSize)
        : await this.fetchMaxDownloadSize();
    const units = imageTransferUnits(data, budget);
    for (let i = 0; i < units.length; i += 1) {
      options.signal?.throwIfAborted();
      await this.downloadAndFlashOnce(
        partition,
        units[i] as Uint8Array,
        i,
        units.length,
        options.onProgress,
      );
    }
  }

  /**
   * H1: ask THE DEVICE for its download budget and parse it strictly.
   * Missing or unusable values raise an explicit ProtocolError stating the
   * reason — the client never guesses a chunk size or sends unchunked.
   */
  private async fetchMaxDownloadSize(): Promise<number> {
    let raw: string;
    try {
      raw = await this.getvar(MAX_DOWNLOAD_SIZE_VAR);
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw new ProtocolError(
        `device reported unusable max-download-size (${detail}) — refusing to flash without a known budget`,
      );
    }
    try {
      return parseMaxDownloadSize(raw);
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw new ProtocolError(
        `device reported unusable max-download-size ${JSON.stringify(raw)} (${detail}) — refusing to flash without a known budget`,
      );
    }
  }

  /** Raw command passthrough (e.g. `oem …`), still logged verbatim. */
  async raw(command: string): Promise<string> {
    const packet = await this.roundTrip(command);
    return packet.text;
  }

  private async downloadAndFlashOnce(
    partition: string,
    data: Uint8Array,
    index: number,
    count: number,
    onProgress?: (progress: Progress) => void,
  ): Promise<void> {
    const dataPacket = await this.expectKind(downloadCommand(data.length), "DATA");
    const announced = parseDataSize(dataPacket);
    if (announced !== data.length) {
      // Fail-closed abort carrying the announced size verbatim; the INFO text
      // already reached the console log, so the bootloader's own words stay
      // in the transcript (audit M1).
      throw new FastbootError(
        `DATA size mismatch after ${downloadCommand(data.length)}: device accepted ${String(announced)} of ${String(data.length)} bytes`,
      );
    }
    await this.transferLogged(data);
    expect(await this.readTerminal(), "OKAY", "download");
    onProgress?.({
      partition,
      bytesTotal: data.length,
      bytesSent: data.length,
      chunkIndex: index,
      chunkCount: count,
    });
    expect(await this.expectKind(flashCommand(partition), "ANY"), "OKAY", `flash:${partition}`);
  }

  /**
   * Send a command that must be answered with DATA (download:) or any packet
   * (flash:) — draining INFO traffic exactly like readTerminal so
   * protocol-conformant bootloaders that narrate around the handshake do not
   * spuriously abort the install (H3). FAIL still fails fast.
   */
  private async expectKind(command: string, kind: "DATA" | "ANY") {
    this.log(`> ${command}`);
    await this.transport.send(command);
    for (;;) {
      const raw = await this.transport.readPacket();
      const packet = decodePacket(raw);
      this.log(`< ${packet.kind}${packet.text}`);
      if (packet.kind === "FAIL") {
        throw new FastbootError(packet.text);
      }
      if (packet.kind === "INFO") {
        continue;
      }
      const wantsAnyTerminal: boolean = kind === "ANY";
      const wantsData = packet.kind === "DATA";
      if (wantsAnyTerminal || wantsData) {
        return packet;
      }
      throw new ProtocolError(
        `${command}: expected ${wantsAnyTerminal ? "terminal" : "DATA"}, got ${packet.kind}${packet.text}`,
      );
    }
  }

  /**
   * Read packets until a terminal one (OKAY/FAIL). INFO lines are progress —
   * logged verbatim and drained; real devices interleave them freely.
   */
  private async readTerminal() {
    for (;;) {
      const raw = await this.transport.readPacket();
      const packet = decodePacket(raw);
      this.log(`< ${packet.kind}${packet.text}`);
      if (packet.kind !== "INFO") {
        return packet;
      }
    }
  }

  private async roundTrip(command: string) {
    this.log(`> ${command}`);
    await this.transport.send(command);
    return this.readTerminal();
  }

  private async transferLogged(data: Uint8Array): Promise<void> {
    this.log(`> [${String(data.length)} byte payload]`);
    await this.transport.transfer(data);
  }
}

function expect(
  packet: { kind: string; text: string },
  kind: "OKAY",
  context: string,
): void {
  if (packet.kind === "FAIL") {
    throw new FastbootError(packet.text);
  }
  if (packet.kind !== kind) {
    throw new ProtocolError(`${context}: expected ${kind}, got ${packet.kind}${packet.text}`);
  }
}

export function assertPositiveBudget(budget: number): number {
  if (!Number.isSafeInteger(budget) || budget <= 0 || budget > 0xffffffff) {
    throw new ProtocolError(
      `unusable max-download-size: ${JSON.stringify(String(budget))} — refusing to guess a chunk size (audit H1)`,
    );
  }
  return budget;
}
