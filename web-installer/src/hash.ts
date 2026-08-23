import { HashMismatchError } from "./errors.js";
import { sha256PortableHex } from "./sha256-portable.js";

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** SHA-256 hex digest. Portable (no node:crypto) so the wizard can run in-browser. */
export function sha256Hex(data: Uint8Array): string {
  return sha256PortableHex(data);
}

export function normalizeSha256(hex: string): string {
  const trimmed = hex.trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(trimmed)) {
    throw new HashMismatchError("(invalid digest encoding)");
  }
  return trimmed;
}

export function assertSha256Match(
  name: string,
  data: Uint8Array,
  expectedHex: string,
): void {
  const actual = sha256Hex(data);
  if (actual !== normalizeSha256(expectedHex)) {
    throw new HashMismatchError(name);
  }
}
