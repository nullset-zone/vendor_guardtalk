/** Android ADB host RSA (2048-bit) and AUTH token signing. */

import { AdbError } from "../src/errors.js";
import {
  base64UrlToBytes,
  bigIntToBytesBe,
  bigIntToBytesLe,
  bytesBeToBigInt,
  bytesToBase64,
  modPow,
} from "./adb-bytes.js";

export const ADB_KEY_STORE_ID = "guardtalk.webadb.rsa-jwk";
const MODULUS_BYTES = 256;
const SHA1_DIGEST_INFO = Uint8Array.of(
  0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00,
  0x04, 0x14,
);

export interface AdbKeyStore {
  get(key: string): string | null;
  set(key: string, value: string): void;
}

export interface AdbRsaKey {
  n: bigint;
  d: bigint;
}

export function memoryKeyStore(init: Record<string, string> = {}): AdbKeyStore {
  const map = new Map(Object.entries(init));
  return {
    get: (key) => map.get(key) ?? null,
    set: (key, value) => {
      map.set(key, value);
    },
  };
}

export function localStorageKeyStore(): AdbKeyStore {
  const storage = globalThis.localStorage;
  if (storage === undefined) {
    return memoryKeyStore();
  }
  return {
    get: (key) => storage.getItem(key),
    set: (key, value) => {
      storage.setItem(key, value);
    },
  };
}

export async function loadOrCreateAdbKey(store: AdbKeyStore): Promise<AdbRsaKey> {
  const existing = store.get(ADB_KEY_STORE_ID);
  if (existing !== null) {
    try {
      return parseJwk(existing);
    } catch {
      // regenerate
    }
  }
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: Uint8Array.of(0x01, 0x00, 0x01),
      hash: "SHA-1",
    },
    true,
    ["sign", "verify"],
  );
  const jwk = await crypto.subtle.exportKey("jwk", pair.privateKey);
  const raw = JSON.stringify(jwk);
  store.set(ADB_KEY_STORE_ID, raw);
  return parseJwk(raw);
}

export function parseJwk(raw: string): AdbRsaKey {
  const parsed = JSON.parse(raw) as { n?: unknown; d?: unknown };
  if (typeof parsed.n !== "string" || typeof parsed.d !== "string") {
    throw new AdbError("stored ADB key is not a private JWK");
  }
  return {
    n: bytesBeToBigInt(base64UrlToBytes(parsed.n)),
    d: bytesBeToBigInt(base64UrlToBytes(parsed.d)),
  };
}

export function signAdbToken(key: AdbRsaKey, token: Uint8Array): Uint8Array {
  if (token.length !== 20) {
    throw new AdbError(`ADB AUTH token must be 20 bytes, got ${String(token.length)}`);
  }
  const digestInfo = new Uint8Array(SHA1_DIGEST_INFO.length + token.length);
  digestInfo.set(SHA1_DIGEST_INFO, 0);
  digestInfo.set(token, SHA1_DIGEST_INFO.length);
  const em = padPkcs1Type1(digestInfo, MODULUS_BYTES);
  const sig = modPow(bytesBeToBigInt(em), key.d, key.n);
  return bigIntToBytesBe(sig, MODULUS_BYTES);
}

export function androidPublicKey(key: AdbRsaKey, comment = "guardtalk@web"): string {
  const modulus = bigIntToBytesLe(key.n, MODULUS_BYTES);
  const word0 = new DataView(modulus.buffer, modulus.byteOffset, 4).getUint32(0, true);
  const n0inv = (-modInverse32(word0)) >>> 0;
  const rr = bigIntToBytesLe((1n << 4096n) % key.n, MODULUS_BYTES);
  const blob = new Uint8Array(4 + 4 + MODULUS_BYTES + MODULUS_BYTES + 4);
  const view = new DataView(blob.buffer);
  view.setUint32(0, 64, true);
  view.setUint32(4, n0inv, true);
  blob.set(modulus, 8);
  blob.set(rr, 8 + MODULUS_BYTES);
  view.setUint32(8 + MODULUS_BYTES + MODULUS_BYTES, 65537, true);
  return `${bytesToBase64(blob)} ${comment}\0`;
}

function padPkcs1Type1(payload: Uint8Array, length: number): Uint8Array {
  const psLen = length - payload.length - 3;
  if (psLen < 8) {
    throw new AdbError("RSA payload is too large for a 2048-bit key");
  }
  const em = new Uint8Array(length);
  em[0] = 0x00;
  em[1] = 0x01;
  em.fill(0xff, 2, 2 + psLen);
  em[2 + psLen] = 0x00;
  em.set(payload, 3 + psLen);
  return em;
}

function modInverse32(value: number): number {
  let inv = 1;
  const n = value >>> 0;
  for (let i = 0; i < 5; i++) {
    inv = Math.imul(inv, 2 - Math.imul(n, inv)) >>> 0;
  }
  return inv;
}
