export function concatBytes(left: Uint8Array, right: Uint8Array): Uint8Array {
  const out = new Uint8Array(left.length + right.length);
  out.set(left, 0);
  out.set(right, left.length);
  return out;
}

export function utf8(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

export function cString(text: string): Uint8Array {
  return utf8(`${text}\0`);
}

export function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  for (const byte of bytes) {
    bin += String.fromCharCode(byte);
  }
  return btoa(bin);
}

export function base64UrlToBytes(value: string): Uint8Array {
  const pad = "=".repeat((4 - (value.length % 4)) % 4);
  const b64 = value.replace(/-/g, "+").replace(/_/g, "/") + pad;
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    out[i] = bin.charCodeAt(i);
  }
  return out;
}

export function bytesBeToBigInt(bytes: Uint8Array): bigint {
  let value = 0n;
  for (const byte of bytes) {
    value = (value << 8n) + BigInt(byte);
  }
  return value;
}

export function bigIntToBytesLe(value: bigint, length: number): Uint8Array {
  const out = new Uint8Array(length);
  let next = value;
  for (let i = 0; i < length; i++) {
    out[i] = Number(next & 0xffn);
    next >>= 8n;
  }
  return out;
}

export function bigIntToBytesBe(value: bigint, length: number): Uint8Array {
  const out = new Uint8Array(length);
  let next = value;
  for (let i = length - 1; i >= 0; i--) {
    out[i] = Number(next & 0xffn);
    next >>= 8n;
  }
  return out;
}

export function modPow(base: bigint, exp: bigint, modulus: bigint): bigint {
  let result = 1n;
  let b = base % modulus;
  let e = exp;
  while (e > 0n) {
    if (e & 1n) {
      result = (result * b) % modulus;
    }
    b = (b * b) % modulus;
    e >>= 1n;
  }
  return result;
}
