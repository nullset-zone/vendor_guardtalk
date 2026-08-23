/**
 * Big-endian binary primitives shared by the AVB modules.
 *
 * All multi-byte integers in AVB structures are big-endian ("network order")
 * per avbtool.py struct formats using the '!' prefix (e.g. ':2093-2105',
 * ':1181'). u64 fields are handled as bigint to avoid 2^53 precision loss.
 */

export class AvbBinaryError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "AvbBinaryError";
    this.code = code;
  }
}

/** Binary error that preserves an underlying cause (ErrorOptions-aware). */
export class AvbCausedError extends AvbBinaryError {
  readonly cause?: Error | undefined;

  constructor(code: string, message: string, cause?: Error) {
    super(code, message);
    this.cause = cause;
  }
}

export function roundUpTo(value: number, multiple: number): number {
  const remainder = value % multiple;
  if (remainder === 0) {
    return value;
  }
  return value + multiple - remainder;
}

export function toHex(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += ((bytes[i] ?? 0) & 0xff).toString(16).padStart(2, "0");
  }
  return out;
}

export function fromHex(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new AvbBinaryError("ODD_HEX_LENGTH", "hex string must have even length");
  }
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    const byte = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
    if (Number.isNaN(byte)) {
      throw new AvbBinaryError("BAD_HEX_DIGIT", `invalid hex digit pair at ${i * 2}`);
    }
    out[i] = byte;
  }
  return out;
}

/**
 * Length-independent comparison once lengths are equal; differing lengths
 * return false immediately (length itself is not secret here — it is checked
 * against fixed AVB structure sizes upstream).
 */
export function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

export function concatBytes(parts: readonly Uint8Array[]): Uint8Array {
  let total = 0;
  for (const part of parts) {
    total += part.length;
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

export function bigIntToBeBytes(value: bigint, byteLength: number): Uint8Array {
  if (value < 0n) {
    throw new AvbBinaryError("NEGATIVE_VALUE", "cannot encode negative bigint");
  }
  if (value >= 1n << BigInt(byteLength * 8)) {
    throw new AvbBinaryError("VALUE_OVERFLOW", `value does not fit in ${byteLength} bytes`);
  }
  const out = new Uint8Array(byteLength);
  let v = value;
  for (let i = byteLength - 1; i >= 0; i--) {
    out[i] = Number(v & 0xffn);
    v >>= 8n;
  }
  return out;
}

export function beBytesToBigInt(bytes: Uint8Array, start = 0, end = bytes.length): bigint {
  let value = 0n;
  for (let i = start; i < end; i++) {
    value = (value << 8n) | BigInt(bytes[i] ?? 0);
  }
  return value;
}

/** Sequential big-endian reader over a fixed buffer. */
export class ByteReader {
  private readonly view: DataView;
  private readonly buf: Uint8Array;
  private offset = 0;

  constructor(bytes: Uint8Array) {
    // Copy so readers cannot observe later mutation of the caller's buffer.
    this.buf = Uint8Array.prototype.slice.call(bytes);
    this.view = new DataView(this.buf.buffer, this.buf.byteOffset, this.buf.byteLength);
  }

  get remaining(): number {
    return this.buf.length - this.offset;
  }

  u32(): number {
    if (this.remaining < 4) {
      throw new AvbBinaryError("TRUNCATED", "reader underrun reading u32");
    }
    const v = this.view.getUint32(this.offset, false);
    this.offset += 4;
    return v;
  }

  u64(): bigint {
    if (this.remaining < 8) {
      throw new AvbBinaryError("TRUNCATED", "reader underrun reading u64");
    }
    const v = this.view.getBigUint64(this.offset, false);
    this.offset += 8;
    return v;
  }

  /** Reads a bounded slice; the returned array is a copy of the reader's buffer. */
  read(length: number): Uint8Array {
    if (length < 0 || this.remaining < length) {
      throw new AvbBinaryError("TRUNCATED", `reader underrun reading ${length} bytes`);
    }
    const out = this.buf.slice(this.offset, this.offset + length);
    this.offset += length;
    return out;
  }

  skip(length: number): void {
    if (length < 0 || this.remaining < length) {
      throw new AvbBinaryError("TRUNCATED", "reader underrun skipping");
    }
    this.offset += length;
  }
}

/** Sequential big-endian writer producing a packed buffer. */
export class ByteWriter {
  private readonly chunks: Uint8Array[] = [];

  u32(value: number): this {
    const b = new Uint8Array(4);
    new DataView(b.buffer).setUint32(0, value, false);
    this.chunks.push(b);
    return this;
  }

  u64(value: bigint): this {
    const b = new Uint8Array(8);
    new DataView(b.buffer).setBigUint64(0, value, false);
    this.chunks.push(b);
    return this;
  }

  bytes(data: Uint8Array): this {
    this.chunks.push(Uint8Array.prototype.slice.call(data));
    return this;
  }

  zeros(count: number): this {
    if (count < 0) {
      throw new AvbBinaryError("NEGATIVE_PAD", "cannot write negative padding");
    }
    this.chunks.push(new Uint8Array(count));
    return this;
  }

  /** Writes UTF-8 data NUL-padded to exactly `width` bytes (no extra terminator byte). */
  fixedUtf8(text: string, width: number): this {
    const encoded = new TextEncoder().encode(text);
    if (encoded.length > width) {
      throw new AvbBinaryError("STRING_TOO_LONG", `"${text}" exceeds ${width} bytes`);
    }
    const buf = new Uint8Array(width);
    buf.set(encoded);
    this.chunks.push(buf);
    return this;
  }

  toUint8Array(): Uint8Array {
    return concatBytes(this.chunks);
  }
}

const BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

/** URL-safe base64 without padding, as required by JOSE/JWK (RFC 7515 §2). */
export function bytesToBase64Url(bytes: Uint8Array): string {
  const alphabet = BASE64_ALPHABET;
  let out = "";
  const len = bytes.length;
  let i = 0;
  for (; i + 2 < len; i += 3) {
    const b0 = bytes[i] ?? 0;
    const b1 = bytes[i + 1] ?? 0;
    const b2 = bytes[i + 2] ?? 0;
    const n = ((b0 << 16) | (b1 << 8) | b2) & 0xffffff;
    out += alphabet[(n >> 18) & 63]! + alphabet[(n >> 12) & 63]! +
      alphabet[(n >> 6) & 63]! + alphabet[n & 63]!;
  }
  if (len - i === 1) {
    const n = ((bytes[i] ?? 0) << 16) & 0xff0000;
    out += alphabet[(n >> 18) & 63]! + alphabet[(n >> 12) & 63]!;
  } else if (len - i === 2) {
    const b0 = bytes[i] ?? 0;
    const b1 = bytes[i + 1] ?? 0;
    const n = (((b0 << 16) | (b1 << 8)) & 0xffff00);
    out += alphabet[(n >> 18) & 63]! + alphabet[(n >> 12) & 63]! +
      alphabet[(n >> 6) & 63]!;
  }
  return out;
}

/** Iterative modular exponentiation over bigint (square-and-multiply). */
export function modPow(base: bigint, exponent: bigint, modulus: bigint): bigint {
  if (modulus <= 0n) {
    throw new AvbBinaryError("BAD_MODULUS", "modulus must be positive");
  }
  let result = 1n;
  let b = base % modulus;
  let e = exponent;
  while (e > 0n) {
    if (e & 1n) {
      result = (result * b) % modulus;
    }
    b = (b * b) % modulus;
    e >>= 1n;
  }
  return result;
}

/** Extended-Euclid modular inverse; throws when gcd(a, m) != 1. */
export function modInverse(a: bigint, m: bigint): bigint {
  if (m <= 0n) {
    throw new AvbBinaryError("BAD_MODULUS", "modulus must be positive");
  }
  let [old_r, r] = [((a % m) + m) % m, m];
  let [old_s, s] = [1n, 0n];
  while (r !== 0n) {
    const q = old_r / r;
    [old_r, r] = [r, old_r - q * r];
    [old_s, s] = [s, old_s - q * s];
  }
  if (old_r !== 1n) {
    throw new AvbBinaryError("NO_INVERSE", "modular inverse does not exist");
  }
  return ((old_s % m) + m) % m;
}

export function bitLength(value: bigint): number {
  if (value < 0n) {
    throw new AvbBinaryError("NEGATIVE_VALUE", "bit length of negative number");
  }
  return value === 0n ? 0 : value.toString(2).length;
}

export function roundUpToPowerOfTwo(value: number): number {
  if (value <= 1) {
    return 1;
  }
  return 2 ** Math.ceil(Math.log2(value));
}
