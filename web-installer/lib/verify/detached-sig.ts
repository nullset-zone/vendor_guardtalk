/**
 * Offline detached-signature verification (RSASSA-PKCS1-v1_5 / SHA-256).
 * NO network. The release key ships as a placeholder until the human lands
 * the real JWK (Q-04); verification is fully implemented for any RSA JWK.
 */

const MIN_MODULUS_BITS = 2048;
const RSA_ENCRYPTION_OID = new Uint8Array([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]);

export interface RsaPublicJwk {
  readonly kty: "RSA";
  readonly n: string;
  readonly e: string;
}

export interface DetachedSigResult {
  readonly valid: boolean;
  readonly reason?: string;
}

export class SigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DetachedSigError";
  }
}

function hasSubtle(): boolean {
  return (
    typeof globalThis.crypto === "object" &&
    globalThis.crypto !== null &&
    typeof globalThis.crypto.subtle === "object" &&
    globalThis.crypto.subtle !== null
  );
}

export async function verifyDetached(
  sigBytes: Uint8Array,
  signedText: string,
  releaseKeyJwkPlaceholder: RsaPublicJwk,
): Promise<DetachedSigResult> {
  if (!hasSubtle()) {
    return { valid: false, reason: "WebCrypto unavailable in this environment" };
  }
  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "jwk",
      { ...releaseKeyJwkPlaceholder },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      true,
      ["verify"],
    );
  } catch {
    return { valid: false, reason: "release public key could not be imported (malformed JWK)" };
  }
  const data = new TextEncoder().encode(signedText);
  const signature = copyBytes(sigBytes);
  let ok: boolean;
  try {
    ok = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      signature as BufferSource,
      data as BufferSource,
    );
  } catch {
    return { valid: false, reason: "signature encoding does not match the key size" };
  }
  return ok ? { valid: true } : { valid: false, reason: "signature does not verify over SHA256SUMS" };
}

/** Convert an armored PEM public key (SPKI or PKCS#1) to an RSA public JWK. */
export async function armoredPemToJwk(pem: string): Promise<RsaPublicJwk> {
  const base64 = pem
    .split(/\r?\n/)
    .filter((line) => !line.includes("-----"))
    .join("");
  const der = decodeBase64(base64);
  const reader = new DerReader(der);
  const outer = reader.readTlv(0x30);
  const inner = new DerReader(outer.value);
  const first = inner.readTlv();
  if (first.tag === 0x30 && inner.peekTag() === 0x03) {
    // SubjectPublicKeyInfo: SEQUENCE { SEQUENCE { OID rsaEncryption, NULL }, BIT STRING }
    const algorithm = new DerReader(first.value).readTlv().value;
    if (!bytesEqual(algorithm, RSA_ENCRYPTION_OID)) {
      throw new SigError("PEM key is not rsaEncryption");
    }
    const bitString = inner.readTlv(0x03);
    if ((bitString.value[0] ?? -1) !== 0) {
      throw new SigError("unexpected BIT STRING leading byte");
    }
    const rsaKeySequence = new DerReader(bitString.value.subarray(1)).readTlv(0x30);
    return jwkFromRsaPublicKey(new DerReader(rsaKeySequence.value));
  }
  if (first.tag === 0x02) {
    // Raw PKCS#1 RSAPublicKey: SEQUENCE { INTEGER modulus, INTEGER publicExponent }
    return jwkFromRsaPublicKey(new DerReader(outer.value));
  }
  throw new SigError("PEM payload structure not recognised");
}

function jwkFromRsaPublicKey(reader: DerReader): RsaPublicJwk {
  const modulus = readPositiveInteger(reader.readTlv(0x02));
  const exponent = readPositiveInteger(reader.readTlv(0x02));
  const bitLength = modulus.toString(2).length;
  if (bitLength < MIN_MODULUS_BITS) {
    throw new SigError(`RSA modulus too small (${bitLength} bits; minimum ${MIN_MODULUS_BITS})`);
  }
  return { kty: "RSA", n: bigIntToBase64Url(modulus), e: bigIntToBase64Url(exponent) };
}

function readPositiveInteger(tlv: DerElement): bigint {
  if ((tlv.value[0] ?? 0) === 0) {
    return bytesToBigInt(tlv.value.subarray(1));
  }
  return bytesToBigInt(tlv.value);
}

function bytesToBigInt(bytes: Uint8Array): bigint {
  let result = 0n;
  for (const byte of bytes) {
    result = (result << 8n) | BigInt(byte);
  }
  return result;
}

interface DerElement {
  readonly tag: number;
  readonly value: Uint8Array;
}

class DerReader {
  readonly #bytes: Uint8Array;
  #offset = 0;

  constructor(bytes: Uint8Array) {
    this.#bytes = bytes;
  }

  peekTag(): number {
    return this.#bytes[this.#offset] ?? -1;
  }

  readTlv(expectedTag?: number): DerElement {
    const tag = this.#bytes[this.#offset];
    if (tag === undefined || (tag & 0x1f) === 0x1f) {
      throw new SigError("truncated or unsupported DER tag");
    }
    if (expectedTag !== undefined && tag !== expectedTag) {
      throw new SigError(`expected DER tag 0x${expectedTag.toString(16)}, found 0x${tag.toString(16)}`);
    }
    this.#offset += 1;
    const lengthByte = this.#bytes[this.#offset];
    if (lengthByte === undefined) {
      throw new SigError("truncated DER length");
    }
    let length: number;
    if ((lengthByte & 0x80) === 0) {
      length = lengthByte;
      this.#offset += 1;
    } else {
      const lengthOfLength = lengthByte & 0x7f;
      if (lengthOfLength === 0 || lengthOfLength > 2) {
        throw new SigError("unsupported DER length form");
      }
      this.#offset += 1;
      length = 0;
      for (let i = 0; i < lengthOfLength; i += 1) {
        length = length * 0x100 + (this.#bytes[this.#offset + i] ?? 0);
      }
      this.#offset += lengthOfLength;
    }
    const end = this.#offset + length;
    if (end > this.#bytes.byteLength) {
      throw new SigError("DER length exceeds buffer");
    }
    const value = this.#bytes.subarray(this.#offset, end);
    this.#offset = end;
    return { tag, value };
  }
}

function copyBytes(bytes: Uint8Array): Uint8Array {
  const out = new Uint8Array(bytes.byteLength);
  out.set(bytes);
  return out;
}

function decodeBase64(text: string): Uint8Array {
  const normalized = text.replace(/\s+/g, "");
  const b64 = normalized.replace(/-/g, "+").replace(/_/g, "/");
  const btoaFn = globalThis.atob;
  if (typeof btoaFn === "function") {
    const binary = b64.endsWith("=") ? b64 : padBase64(b64);
    const binaryText = atobSafe(binary);
    const out = new Uint8Array(binaryText.length);
    for (let i = 0; i < binaryText.length; i += 1) {
      out[i] = binaryText.charCodeAt(i);
    }
    return out;
  }
  const nodeBuffer = (globalThis as unknown as {
    Buffer?: { from(data: string, enc: string): Uint8Array };
  }).Buffer;
  if (nodeBuffer !== undefined) {
    return new Uint8Array(nodeBuffer.from(b64, "base64"));
  }
  throw new SigError("no Base64 decoder available");
}

function atobSafe(text: string): string {
  try {
    return atob(text);
  } catch {
    throw new SigError("PEM body is not valid Base64");
  }
}

function padBase64(text: string): string {
  const remainder = text.length % 4;
  return remainder === 0 ? text : text + "=".repeat(4 - remainder);
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  return a.byteLength === b.byteLength && a.every((byte, i) => byte === b[i]);
}

function bigIntToBase64Url(value: bigint): string {
  let hex = value.toString(16);
  if (hex.length % 2 === 1) {
    hex = `0${hex}`;
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.byteLength; i += 1) {
    bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return encodeBase64Url(bytes);
}

function encodeBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  const btoaFn = globalThis.btoa;
  if (typeof btoaFn === "function") {
    return btoaFn(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  const nodeBuffer = (globalThis as unknown as {
    Buffer?: { from(data: Uint8Array): { toString(enc: string): string } };
  }).Buffer;
  if (nodeBuffer !== undefined) {
    return nodeBuffer.from(bytes).toString("base64url");
  }
  throw new SigError("no Base64 encoder available");
}
