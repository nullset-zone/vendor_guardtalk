/**
 * Pure fastboot wire-protocol functions: command encoding and response parsing.
 * No I/O here — see client.ts for the driver and usb.ts / simulated-device.ts
 * for transports. Reference: docs/research/READER-B-AVB-FASTBOOT.md §E.
 *
 * Packet grammar (ASCII):
 *   OKAY[reason?]   success; reason is informational on getvar-less commands
 *   FAIL<reason>    failure; reason is verbatim bootloader text
 *   INFO<text>      progress/status line
 *   DATA<size08x>   host must transfer <size> bytes next
 */

const encoder = new TextEncoder();
const decoder = new TextDecoder("ascii");

export type PacketKind = "OKAY" | "FAIL" | "INFO" | "DATA";

export interface FastbootPacket {
  kind: PacketKind;
  /** Remaining bytes after the 4-byte prefix, verbatim. */
  payload: Uint8Array;
  /** payload decoded as ASCII (lossy-safe for diagnostics). */
  text: string;
}

export class ProtocolError extends Error {
  readonly code = "FASTBOOT_PROTOCOL";
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

/**
 * CANONICAL WIRE FORMAT: commands are ASCII strings end-to-end inside the
 * client; `encodeCommand` converts to bytes ONLY at the transport boundary,
 * and `wireToCommand` is its exact inverse. Both transports (WebUSB,
 * SimulatedDevice) MUST go through these two functions — nothing else may
 * invent its own encoding.
 */

/** Encode an ASCII command string (`getvar:x`, `flash:x`, …) to wire bytes. */
export function encodeCommand(command: string): Uint8Array {
  return encoder.encode(command);
}

/** Decode wire bytes back to the ASCII command/response text (inverse of encodeCommand). */
export function wireToCommand(raw: Uint8Array): string {
  return decoder.decode(raw);
}

/** Roundtrip identity proof helper: encode → decode must reproduce the input. */
export function wireRoundTrips(text: string): boolean {
  return wireToCommand(encodeCommand(text)) === text;
}

/** Decode received packet bytes into a classified packet. */
export function decodePacket(raw: Uint8Array): FastbootPacket {
  const head = asciiPrefix(raw, 4);
  const payload = raw.subarray(Math.min(4, raw.length));
  switch (head) {
    case "OKAY":
    case "FAIL":
    case "INFO":
    case "DATA":
      return { kind: head, payload, text: decoder.decode(payload) };
    default:
      throw new ProtocolError(`unexpected fastboot packet ${JSON.stringify(head)}`);
  }
}

function asciiPrefix(raw: Uint8Array, n: number): string {
  return decoder.decode(raw.subarray(0, Math.min(n, raw.length)));
}

// --- Command builders -------------------------------------------------------

export function getvarCommand(variable: string): string {
  return `getvar:${variable}`;
}

export function flashCommand(partition: string): string {
  return `flash:${partition}`;
}

export function eraseCommand(partition: string): string {
  return `erase:${partition}`;
}

export function flashingUnlockCommand(): string {
  return "flashing unlock";
}

export function flashingLockCommand(): string {
  return "flashing lock";
}

export function rebootCommand(target?: "bootloader"): string {
  return target === undefined ? "reboot" : `reboot-${target}`;
}

/** `download:%08x` — 8 lowercase hex digits, zero-padded. */
export function downloadCommand(sizeBytes: number): string {
  if (!Number.isInteger(sizeBytes) || sizeBytes < 0 || sizeBytes > 0xffffffff) {
    throw new ProtocolError(`download size out of range: ${String(sizeBytes)}`);
  }
  const hex = sizeBytes.toString(16).padStart(8, "0");
  return `download:${hex}`;
}

// --- Response helpers -------------------------------------------------------

/** Extract the integer of a `DATA%08x` payload. */
export function parseDataSize(packet: FastbootPacket): number {
  if (!/^[0-9a-fA-F]{8}$/.test(packet.text)) {
    throw new ProtocolError(`malformed DATA payload: ${JSON.stringify(packet.text)}`);
  }
  return Number.parseInt(packet.text, 16);
}

/** Parse `max-download-size` values like `268435456` or `0x10000000`. */
export const MAX_DOWNLOAD_SIZE_VAR = "max-download-size" as const;

export function parseMaxDownloadSize(value: string): number {
  const trimmed = value.trim();
  const parsed = /^0x[0-9a-fA-F]+$/.test(trimmed)
    ? Number.parseInt(trimmed, 16)
    : Number.parseInt(trimmed, 10);
  if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 0xffffffff) {
    throw new ProtocolError(`unusable max-download-size: ${JSON.stringify(value)}`);
  }
  return parsed;
}
