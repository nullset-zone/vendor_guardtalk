/**
 * PEM key import (flow 2). Parses unencrypted PKCS#8 ("PRIVATE KEY") and
 * PKCS#1 ("RSA PRIVATE KEY") PEM into transient BigInt material for the
 * signing path plus the public JWK for fingerprinting. Encrypted PKCS#8
 * (PBES2: PBKDF2 + AES-KW) is unwrapped via WebCrypto (no deps).
 *
 * All buffers produced here are TRANSIENT: callers must zeroise() them after
 * signing; nothing is cached, logged, or persisted (D-007).
 */
import { decryptEncryptedPem } from "./export-enc.js";

export interface ImportedKey {
  /** Public half as JWK (n/e only). */
  publicJwk: JsonWebKey;
  /** Transient private scalars for the pure-BigInt signing path. */
  material: PrivateMaterial;
}

/** Owned by the caller; scrub() or zeroise() every field after use. */
export interface PrivateMaterial {
  n: Uint8Array;
  e: Uint8Array;
  d: Uint8Array;
  p?: Uint8Array | undefined;
  q?: Uint8Array | undefined;
}

const cryptoRef: Crypto = globalThis.crypto;

export class PemParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

/**
 * Import a PEM text. `passphrase` is required only for encrypted PEMs.
 * Never throws with key material in the message.
 */
export async function importPem(pemText: string, passphrase?: string): Promise<ImportedKey> {
  const label = pemLabel(pemText);
  if (label === null) {
    throw new PemParseError("no PEM block found");
  }
  if (passphrase === undefined || passphrase.length === 0) {
    // Both encrypted formats must refuse to proceed without a passphrase.
    if (label === "ENCRYPTED PRIVATE KEY") {
      throw new PemParseError("encrypted PEM requires a passphrase");
    }
    if (label.startsWith("GUARDTALK")) {
      throw new PemParseError("encrypted key file requires a passphrase");
    }
  }
  if (label === "ENCRYPTED PRIVATE KEY") {
    return importEncryptedPkcs8(pemText, passphrase ?? "");
  }
  if (label === "GUARDTALK ENCRYPTED KEY") {
    return importArmoredEncrypted(pemText, passphrase ?? "");
  }
  const der = pemDer(pemText, label);
  try {
    if (label === "PRIVATE KEY") {
      return buildImported(parsePkcs8(der));
    }
    if (label === "RSA PRIVATE KEY") {
      return buildImported(parsePkcs1(der));
    }
    throw new PemParseError(`unsupported PEM label ${JSON.stringify(label)}`);
  } finally {
    der.fill(0);
  }
}

/** GTKEY-1 armored files from export-enc.ts decrypt straight into PKCS#8. */
export async function importArmoredEncrypted(
  text: string,
  passphrase: string,
): Promise<ImportedKey> {
  const { der } = await decryptEncryptedPem(text, passphrase);
  try {
    return buildImported(parsePkcs8(der));
  } finally {
    der.fill(0);
  }
}

// --- Key structure parsing ---------------------------------------------------

const RSA_OID = [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01];

interface RsaIntegerSet {
  n: bigint;
  e: bigint;
  d: bigint;
  p?: bigint | undefined;
  q?: bigint | undefined;
}

function parsePkcs8(pkcs8: Uint8Array): RsaIntegerSet {
  let rsa: RsaIntegerSet;
  try {
    const outer = readSequence(pkcs8, 0);
    const fields = childrenOf(pkcs8, outer);
    const algId = fields[1];
    const inner = fields[2];
    if (fields.length < 3 || algId === undefined || inner === undefined) {
      throw new PemParseError("PKCS#8 too short");
    }
    // AlgorithmIdentifier ::= SEQUENCE { algorithm OID, parameters ANY }
    const oidTlv = childrenOf(pkcs8, algId)[0];
    if (!isOid(pkcs8, oidTlv, RSA_OID)) {
      throw new PemParseError("PKCS#8 does not contain an RSA key");
    }
    rsa = parsePkcs1(valueBytes(pkcs8, inner));
  } catch (err) {
    if (err instanceof PemParseError) {
      throw err;
    }
    throw new PemParseError("not a valid RSA private key (PKCS#8)");
  }
  return rsa;
}

/** RSAPrivateKey ::= SEQUENCE { version, n, e, d, p, q, dp, dq, qinv } */
function parsePkcs1(der: Uint8Array): RsaIntegerSet {
  const seq = readSequence(der, 0);
  const tlvs = childrenOf(der, seq);
  if (tlvs.length < 4) {
    throw new PemParseError("RSAPrivateKey too short");
  }
  const version = readPositiveInteger(valueBytes(der, tlvs[0]));
  if (version !== 0n) {
    throw new PemParseError("multi-prime RSA keys are not supported");
  }
  const set: RsaIntegerSet = {
    n: bytesToBigInt(valueBytes(der, tlvs[1])),
    e: bytesToBigInt(valueBytes(der, tlvs[2])),
    d: bytesToBigInt(valueBytes(der, tlvs[3])),
  };
  if (tlvs.length >= 6) {
    set.p = bytesToBigInt(valueBytes(der, tlvs[4]));
    set.q = bytesToBigInt(valueBytes(der, tlvs[5]));
  }
  if (set.e !== 65537n) {
    throw new PemParseError("unsupported RSA exponent; only 65537 is allowed");
  }
  return set;
}

function buildImported(rsa: RsaIntegerSet): ImportedKey {
  const material: PrivateMaterial = {
    n: bigIntToBytes(rsa.n),
    e: bigIntToBytes(rsa.e),
    d: bigIntToBytes(rsa.d),
    p: rsa.p !== undefined ? bigIntToBytes(rsa.p) : undefined,
    q: rsa.q !== undefined ? bigIntToBytes(rsa.q) : undefined,
  };
  const publicJwk: JsonWebKey = {
    kty: "RSA",
    alg: "RS256",
    ext: true,
    n: bytesToBase64Url(material.n),
    e: bytesToBase64Url(material.e),
  };
  return { publicJwk, material };
}

// --- Encrypted PKCS#8 (PBES2: PBKDF2 + AES-256-KW per RFC 8018) --------------

const PBES2_OID = [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x05, 0x0d];
const PBKDF2_OID = [0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x05, 0x0c];
const AES256_KW_OID = [0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x01, 0x2d];

async function importEncryptedPkcs8(pemText: string, passphrase: string): Promise<ImportedKey> {
  const der = pemDer(pemText, "ENCRYPTED PRIVATE KEY");
  try {
    const outer = childrenOf(der, readSequence(der, 0));
    const algorithm = outer[0];
    const encryptedData = outer[1];
    if (algorithm === undefined || encryptedData === undefined || outer.length !== 2) {
      throw new PemParseError("malformed EncryptedPrivateKeyInfo");
    }
    const algFields = childrenOf(der, algorithm);
    const pbes2Oid = algFields[0];
    const algParamsTlv = algFields[1];
    if (
      algFields.length !== 2 ||
      !isOid(der, pbes2Oid, PBES2_OID) ||
      algParamsTlv === undefined
    ) {
      throw new PemParseError("unsupported encryption scheme (want PBES2)");
    }
    const params = childrenOf(der, algParamsTlv);
    const kdfScheme = params[0];
    const encScheme = params[1];
    if (kdfScheme === undefined || encScheme === undefined) {
      throw new PemParseError("malformed PBES2 parameters");
    }
    if (!isOid(der, encScheme, AES256_KW_OID)) {
      throw new PemParseError("unsupported content cipher (want AES-256-KW)");
    }
    const kwParams = childrenOf(der, encScheme);
    if (kwParams.length !== 1) {
      throw new PemParseError("missing AES-KW IV");
    }
    const iv = valueBytes(der, kwParams[0]);

    const kdfFields = childrenOf(der, kdfScheme);
    const kdfOid = kdfFields[0];
    const kdfSeq = kdfFields[1];
    if (kdfFields.length !== 2 || !isOid(der, kdfOid, PBKDF2_OID) || kdfSeq === undefined) {
      throw new PemParseError("unsupported KDF (want PBKDF2)");
    }
    const kdfParams = childrenOf(der, kdfSeq);
    const saltTlv = kdfParams[1];
    const iterTlv = kdfParams[2];
    if (saltTlv === undefined || iterTlv === undefined) {
      throw new PemParseError("malformed PBKDF2 parameters");
    }
    const iterations = Number(readPositiveInteger(valueBytes(der, iterTlv)));

    const baseKey = await cryptoRef.subtle.importKey(
      "raw",
      new TextEncoder().encode(passphrase) as BufferSource,
      "PBKDF2",
      false,
      ["deriveKey"],
    );
    const wrappingKey = await cryptoRef.subtle.deriveKey(
      {
        name: "PBKDF2",
        hash: "SHA-256",
        salt: valueBytes(der, saltTlv) as BufferSource,
        iterations,
      },
      baseKey,
      { name: "AES-KW", length: 256 },
      false,
      ["unwrapKey"],
    );
    let raw: ArrayBuffer;
    try {
      raw = await cryptoRef.subtle.decrypt(
        { name: "AES-KW", iv: iv as BufferSource },
        wrappingKey,
        valueBytes(der, encryptedData) as BufferSource,
      );
    } catch {
      throw new PemParseError("wrong passphrase or corrupted key file");
    }
    const pkcs8 = new Uint8Array(raw);
    try {
      return buildImported(parsePkcs8(pkcs8));
    } finally {
      pkcs8.fill(0);
    }
  } finally {
    der.fill(0);
  }
}

// --- Minimal DER walker (offset-based; buffers are never copied) -------------

interface Tlv {
  tag: number;
  valueOffset: number;
  valueLength: number;
}

const TAG_SEQUENCE = 0x30;
const TAG_INTEGER = 0x02;
const TAG_OID = 0x06;

function readTlv(buf: Uint8Array, offset: number): Tlv {
  if (offset + 2 > buf.length) {
    throw new PemParseError("DER truncated");
  }
  const tag = buf[offset] as number;
  const firstLen = buf[offset + 1] as number;
  let lenOff = offset + 2;
  let length = firstLen;
  if ((firstLen & 0x80) !== 0) {
    const numBytes = firstLen & 0x7f;
    length = 0;
    for (let i = 0; i < numBytes; i += 1) {
      length = length * 256 + (buf[lenOff] as number);
      lenOff += 1;
    }
  }
  if (lenOff + length > buf.length) {
    throw new PemParseError("DER length exceeds buffer");
  }
  return { tag, valueOffset: lenOff, valueLength: length };
}

function readSequence(buf: Uint8Array, offset: number): Tlv {
  const tlv = readTlv(buf, offset);
  if (tlv.tag !== TAG_SEQUENCE) {
    throw new PemParseError("expected DER SEQUENCE");
  }
  return tlv;
}

function childrenOf(buf: Uint8Array, tlv: Tlv): Tlv[] {
  const out: Tlv[] = [];
  let off = tlv.valueOffset;
  const end = tlv.valueOffset + tlv.valueLength;
  while (off < end) {
    const child = readTlv(buf, off);
    out.push(child);
    off = child.valueOffset + child.valueLength;
  }
  return out;
}

function valueBytes(buf: Uint8Array, tlv: Tlv | undefined): Uint8Array {
  if (tlv === undefined) {
    throw new PemParseError("missing DER field");
  }
  if (tlv.tag !== TAG_INTEGER && tlv.tag !== TAG_SEQUENCE && tlv.tag !== TAG_OID &&
      tlv.tag !== 0x04 && tlv.tag !== 0x30 && !isContextTag(tlv.tag)) {
    // OCTET STRING (0x04), context tags ([0]/[1]) accepted above.
    throw new PemParseError(`unexpected DER tag 0x${tlv.tag.toString(16)}`);
  }
  return buf.subarray(tlv.valueOffset, tlv.valueOffset + tlv.valueLength);
}

function isContextTag(tag: number): boolean {
  return (tag & 0xa0) === 0xa0;
}

function isOid(buf: Uint8Array, tlv: Tlv | undefined, expected: number[]): boolean {
  if (tlv === undefined || tlv.tag !== TAG_OID) {
    return false;
  }
  const value = buf.subarray(tlv.valueOffset, tlv.valueOffset + tlv.valueLength);
  return value.length === expected.length && expected.every((b, i) => value[i] === b);
}

function readPositiveInteger(bytes: Uint8Array): bigint {
  const first = bytes[0];
  if (first !== undefined && first >= 0x80) {
    throw new PemParseError("negative or malformed DER INTEGER");
  }
  return bytesToBigInt(bytes);
}

// --- Encoding helpers --------------------------------------------------------

function bigIntToBytes(value: bigint): Uint8Array {
  let hex = value.toString(16);
  if (hex.length % 2 === 1) {
    hex = `0${hex}`;
  }
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i += 1) {
    out[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function bytesToBigInt(bytes: Uint8Array): bigint {
  let hex = "";
  for (const b of bytes) {
    hex += b.toString(16).padStart(2, "0");
  }
  return hex.length === 0 ? 0n : BigInt(`0x${hex}`);
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemLabel(text: string): string | null {
  const match = /-----BEGIN ([A-Z0-9 ]+)-----/.exec(text);
  return match?.[1] ?? null;
}

function pemDer(text: string, label: string): Uint8Array {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(
    `-----BEGIN ${escaped}-----([A-Za-z0-9+/=\\s]+)-----END ${escaped}-----`,
  );
  const match = re.exec(text);
  if (match === null || match[1] === undefined) {
    throw new PemParseError(`no ${label} PEM body`);
  }
  const b64 = match[1].replace(/\s+/g, "");
  const binary = atob(b64);
  const der = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    der[i] = binary.charCodeAt(i);
  }
  return der;
}
