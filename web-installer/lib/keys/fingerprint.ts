/**
 * Fingerprint derivation. Delegates pkmd encoding to lib/avb/pkmd.ts
 * (single source of truth — no duplicated encoding logic) and hashes the
 * 1032-byte result with SHA-256. This hex string is the only key-derived
 * value ever shown to the user (D-007 display rule).
 */
import { encodePkmd } from "../avb/pkmd.js";

/** SHA-256 over the pkmd encoding of a public JWK, lowercase hex. */
export async function fingerprintFromJwk(jwk: JsonWebKey): Promise<string> {
  const n = jwkToModulus(jwk);
  const e = jwkToExponent(jwk);
  const pkmd = encodePkmd({ n, e });
  return sha256Hex(pkmd);
}

export async function sha256Hex(data: Uint8Array): Promise<string> {
  const digest = await globalThis.crypto.subtle.digest("SHA-256", data as BufferSource);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function requireB64u(value: string | undefined, field: string): Uint8Array {
  if (value === undefined) {
    throw new Error(`JWK is missing ${field}`);
  }
  return base64UrlDecode(value);
}

function jwkToModulus(jwk: JsonWebKey): bigint {
  return bytesToBigInt(requireB64u(jwk.n, "n"));
}

function jwkToExponent(jwk: JsonWebKey): bigint {
  const e = bytesToBigInt(requireB64u(jwk.e, "e"));
  if (e !== 65537n) {
    throw new Error(`unsupported RSA exponent ${e.toString()}; only 65537 is allowed`);
  }
  return e;
}

function base64UrlDecode(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function bytesToBigInt(bytes: Uint8Array): bigint {
  let hex = "";
  for (const b of bytes) {
    hex += b.toString(16).padStart(2, "0");
  }
  return BigInt(`0x${hex}`);
}
