import { HashMismatchError } from "./errors.js";
import { Sha256Stream, sha256PortableHex } from "./sha256-portable.js";

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** SHA-256 hex digest. Portable (no node:crypto) so the wizard can run in-browser. */
export function sha256Hex(data: Uint8Array): string {
  return sha256PortableHex(data);
}

/** Stream-hash a Blob without materializing a full-size Uint8Array in JS heap. */
export async function sha256BlobHex(blob: Blob): Promise<string> {
  const hasher = new Sha256Stream();
  const reader = blob.stream().getReader();
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (value) {
        hasher.update(value);
      }
    }
  } finally {
    reader.releaseLock();
  }
  return hasher.digestHex();
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

export async function assertBlobSha256Match(
  name: string,
  blob: Blob,
  expectedHex: string,
): Promise<void> {
  const expected = normalizeSha256(expectedHex);
  const actual = await sha256BlobHex(blob);
  if (actual !== expected) {
    throw new HashMismatchError(name);
  }
}
