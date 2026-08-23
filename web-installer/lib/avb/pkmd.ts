/**
 * avb_pkmd.bin codec — the |AvbRSAPublicKeyHeader| format of avbtool.py:411-435:
 *
 *   u32 BE num_bits          # 4096 for RSA-4096
 *   u32 BE n0inv             # 2^32 - modinv(n mod 2^32, 2^32)   (:426-428)
 *   byte[num_bits/8] modulus # big-endian                        (:433, encode_long :246-265)
 *   byte[num_bits/8] rr      # (2^bit_length(n))^2 mod n         (:429-431, Montgomery R^2)
 *
 * Total 1032 bytes for RSA-4096; exponent must be 65537 (:423-424).
 */
import {
  AvbBinaryError,
  beBytesToBigInt,
  bigIntToBeBytes,
  bitLength,
  ByteReader,
  constantTimeEqual,
  modInverse,
} from "./bytes.js";

const U32_MODULUS = 1n << 32n;

export class AvbPkmdError extends AvbBinaryError {}

export interface AvbPublicKeyParams {
  /** Raw RSA modulus. */
  n: bigint;
  /** Public exponent (must be 65537). */
  e: bigint;
}

export interface DecodedPkmd extends AvbPublicKeyParams {
  numBits: number;
  n0inv: number;
  rr: bigint;
}

export function encodePkmd(pub: AvbPublicKeyParams): Uint8Array {
  if (pub.e !== 65537n) {
    throw new AvbPkmdError("BAD_EXPONENT", "Only RSA keys with exponent 65537 are supported.");
  }
  if (pub.n <= 0n) {
    throw new AvbPkmdError("BAD_MODULUS", "modulus must be positive");
  }
  const bits = bitLength(pub.n);
  if (bits % 8 !== 0 || bits < 2048) {
    throw new AvbPkmdError("BAD_MODULUS_SIZE", `unexpected RSA modulus size: ${bits} bits`);
  }
  const numBytes = bits / 8;
  // n0inv = 2^32 - n^{-1} (mod 2^32), per avbtool.py:427-428.
  const n0inv = Number((U32_MODULUS - modInverse(pub.n % U32_MODULUS, U32_MODULUS)) % U32_MODULUS);
  // rr = r^2 mod n with r = 2^bit_length(n), per avbtool.py:430-431.
  const r = 1n << BigInt(bits);
  const rr = (r * r) % pub.n;
  const out = new Uint8Array(8 + numBytes * 2);
  const view = new DataView(out.buffer);
  view.setUint32(0, bits, false);
  view.setUint32(4, n0inv, false);
  out.set(bigIntToBeBytes(pub.n, numBytes), 8);
  out.set(bigIntToBeBytes(rr, numBytes), 8 + numBytes);
  return out;
}

export function decodePkmd(pkmd: Uint8Array): DecodedPkmd {
  if (pkmd.length < 8) {
    throw new AvbPkmdError("TRUNCATED_PKMD", "pkmd shorter than 8-byte header");
  }
  const view = new DataView(pkmd.buffer, pkmd.byteOffset, pkmd.byteLength);
  const numBits = view.getUint32(0, false);
  const n0inv = view.getUint32(4, false);
  if (numBits === 0 || numBits % 8 !== 0) {
    throw new AvbPkmdError("BAD_NUM_BITS", `implausible num_bits ${numBits}`);
  }
  const numBytes = numBits / 8;
  if (pkmd.length !== 8 + numBytes * 2) {
    throw new AvbPkmdError(
      "BAD_PKMD_LENGTH",
      `expected ${8 + numBytes * 2} bytes for a ${numBits}-bit key, got ${pkmd.length}`,
    );
  }
  const r = new ByteReader(pkmd.subarray(8));
  const n = beBytesToBigInt(r.read(numBytes));
  const rr = beBytesToBigInt(r.read(numBytes));
  // Recompute n0inv from n and verify it matches the stored value.
  const expectedN0inv =
    Number((U32_MODULUS - modInverse(n % U32_MODULUS, U32_MODULUS)) % U32_MODULUS) >>> 0;
  if ((n0inv >>> 0) !== expectedN0inv) {
    throw new AvbPkmdError("N0INV_MISMATCH", "stored n0inv does not match modulus");
  }
  return { numBits, n0inv, n, e: 65537n, rr };
}

/** SHA-256 over the raw pkmd bytes, hex-encoded — the user-facing fingerprint. */
export async function pkmdFingerprint(pkmd: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", pkmd as BufferSource);
  const bytes = new Uint8Array(digest);
  let hex = "";
  for (const b of bytes) {
    hex += b.toString(16).padStart(2, "0");
  }
  return hex;
}

/** True when both blobs are the same enrolled public key encoding. */
export function pkmdEqual(a: Uint8Array, b: Uint8Array): boolean {
  return constantTimeEqual(a, b);
}
