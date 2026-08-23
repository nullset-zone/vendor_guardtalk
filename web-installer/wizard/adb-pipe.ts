import { AdbError } from "../src/errors.js";
import { concatBytes } from "./adb-bytes.js";
import {
  HEADER_LEN,
  MAX_PAYLOAD,
  checksum,
  decodeHeader,
  encodePacket,
  type AdbPacket,
} from "./adb-packet.js";

export interface AdbChunkIO {
  write(data: Uint8Array): Promise<void>;
  readChunk(signal?: AbortSignal): Promise<Uint8Array>;
  close(): Promise<void>;
}

/** Hard cap on bytes buffered between packets (hostile-device guard, F4). */
export const MAX_LEFTOVER_BYTES = 1024 * 1024;

export class BufferedAdbPipe {
  private leftover = new Uint8Array(0);
  private cancelled = false;
  private activeRead: AbortController | null = null;

  constructor(private readonly io: AdbChunkIO) {}

  async writePacket(
    command: number,
    arg0: number,
    arg1: number,
    data: Uint8Array,
  ): Promise<void> {
    const raw = encodePacket(command, arg0, arg1, data);
    await this.io.write(raw.subarray(0, HEADER_LEN));
    if (raw.length > HEADER_LEN) {
      await this.io.write(raw.subarray(HEADER_LEN));
    }
  }

  async readPacket(maxPayload = MAX_PAYLOAD): Promise<AdbPacket> {
    const header = await this.readExact(HEADER_LEN);
    const fields = decodeHeader(header);
    if (fields.length > maxPayload) {
      throw new AdbError(`ADB payload ${String(fields.length)} exceeds max`);
    }
    const data =
      fields.length === 0 ? new Uint8Array() : await this.readExact(fields.length);
    // Zero-length payloads legitimately carry check == 0 (AOSP CNXN/AUTH);
    // any non-empty payload must match its checksum (F5).
    if (fields.check !== checksum(data)) {
      throw new AdbError("ADB payload checksum mismatch");
    }
    return {
      command: fields.command,
      arg0: fields.arg0,
      arg1: fields.arg1,
      data,
    };
  }

  /**
   * Abort the in-flight read (if any) without closing. The next read fails
   * closed, and the underlying transport can then release the device (F1).
   */
  cancel(): void {
    this.cancelled = true;
    this.activeRead?.abort();
  }

  async close(): Promise<void> {
    this.cancel();
    // Yield a macrotask so an aborted in-flight transferIn can unwind before
    // the interface/device is released; WebUSB rejects release while a
    // transfer is outstanding, which is exactly the F1 handle leak.
    await new Promise<void>((resolve) => {
      setTimeout(resolve, 0);
    });
    await this.io.close();
  }

  private async readExact(length: number): Promise<Uint8Array> {
    while (this.leftover.length < length) {
      if (this.cancelled) {
        throw new AdbError("ADB stream cancelled");
      }
      const controller = new AbortController();
      this.activeRead = controller;
      let more: Uint8Array;
      try {
        more = await this.io.readChunk(controller.signal);
      } finally {
        if (this.activeRead === controller) {
          this.activeRead = null;
        }
      }
      if (more.length === 0) {
        throw new AdbError("ADB USB stream ended");
      }
      this.leftover = concatBytes(this.leftover, more);
      if (this.leftover.length > MAX_LEFTOVER_BYTES) {
        throw new AdbError(
          `ADB buffered ${String(this.leftover.length)} bytes exceeds the ${String(MAX_LEFTOVER_BYTES)}-byte cap`,
        );
      }
    }
    const out = this.leftover.slice(0, length);
    this.leftover = this.leftover.slice(length);
    return out;
  }
}
