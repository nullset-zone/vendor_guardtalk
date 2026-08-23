/** ADB message framing (system/core/adb protocol.txt). */

export const A_CNXN = 0x4e584e43;
export const A_AUTH = 0x48545541;
export const A_OPEN = 0x4e45504f;
export const A_OKAY = 0x59414b4f;
export const A_CLSE = 0x45534c43;

export const AUTH_TOKEN = 1;
export const AUTH_SIGNATURE = 2;
export const AUTH_RSAPUBLICKEY = 3;

export const A_VERSION = 0x01000000;
export const MAX_PAYLOAD = 4096;
export const HEADER_LEN = 24;

export interface AdbPacket {
  command: number;
  arg0: number;
  arg1: number;
  data: Uint8Array;
}

export function checksum(data: Uint8Array): number {
  let sum = 0;
  for (const byte of data) {
    sum = (sum + byte) & 0xffffffff;
  }
  return sum >>> 0;
}

export function encodePacket(
  command: number,
  arg0: number,
  arg1: number,
  data: Uint8Array,
): Uint8Array {
  const out = new Uint8Array(HEADER_LEN + data.length);
  const view = new DataView(out.buffer, out.byteOffset, HEADER_LEN);
  view.setUint32(0, command, true);
  view.setUint32(4, arg0, true);
  view.setUint32(8, arg1, true);
  view.setUint32(12, data.length, true);
  view.setUint32(16, checksum(data), true);
  view.setUint32(20, (command ^ 0xffffffff) >>> 0, true);
  out.set(data, HEADER_LEN);
  return out;
}

export function decodeHeader(header: Uint8Array): {
  command: number;
  arg0: number;
  arg1: number;
  length: number;
  check: number;
} {
  if (header.length < HEADER_LEN) {
    throw new Error("ADB header is shorter than 24 bytes");
  }
  const view = new DataView(header.buffer, header.byteOffset, HEADER_LEN);
  const command = view.getUint32(0, true);
  const magic = view.getUint32(20, true);
  if (magic !== ((command ^ 0xffffffff) >>> 0)) {
    throw new Error("ADB header magic mismatch");
  }
  return {
    command,
    arg0: view.getUint32(4, true),
    arg1: view.getUint32(8, true),
    length: view.getUint32(12, true),
    check: view.getUint32(16, true),
  };
}

export function commandName(command: number): string {
  const map: Record<number, string> = {
    [A_CNXN]: "CNXN",
    [A_AUTH]: "AUTH",
    [A_OPEN]: "OPEN",
    [A_OKAY]: "OKAY",
    [A_CLSE]: "CLSE",
  };
  return map[command] ?? `0x${command.toString(16)}`;
}
