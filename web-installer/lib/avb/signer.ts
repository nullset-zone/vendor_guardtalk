/**
 * SHA256_RSA4096 vbmeta re-signing and verification.
 *
 * Signing recipe (avbtool.py):
 *   - digest: SHA-256 over header(256B) ‖ aux block            (:3261-3268)
 *   - signature: RSA private-key op over
 *       PKCS#1 v1.5 padding ‖ digest                           (:468-505, :134-147)
 *     where the padding is 00 01 ‖ FF×458 ‖ 00 ‖ DER DigestInfo (:140-147)
 *   - auth block = [hash 32B][signature 512B] zero-padded to 64 (:3234-3244, :3276-3281)
 *   - final blob = header ‖ auth ‖ aux                          (:3283)
 *
 * WebCrypto equivalence note (READER-B §B.6): avbtool computes
 * `padding_and_hash = alg.padding + digest` (:474) and applies the RAW RSA
 * private-key operation (`openssl rsautl -sign -raw`, :496). Because that raw
 * block is exactly `EM || 00 01 FF…FF 00 ‖ DER(DigestInfo(sha256)) ‖ digest`,
 * it equals the EMSA-PKCS1-v1_5 encoding of the digest per RFC 8017 §9.2 /
 * §8.2.1, so a standard RSASSA-PKCS1-v1_5 signature over the digest bytes —
 * what WebCrypto's {name: RSASSA-PKCS1-v1_5} produces internally — yields the
 * identical 512-byte signature for e=65537 keys.
 *
 * IMPORTANT: WebCrypto's RSASSA-PKCS1-v1_5 sign/verify primitives take the
 * raw MESSAGE (here header‖aux) and perform EMSA-PKCS1-v1_5 — including the
 * SHA-256 — internally. The separately computed digest is only stored in the
 * auth block; passing it as the "message" would hash twice and break parity.
 */
import {
  AvbBinaryError,
  AvbCausedError,
  beBytesToBigInt,
  bigIntToBeBytes,
  bytesToBase64Url,
  constantTimeEqual,
  modPow,
  toHex,
} from "./bytes.js";
import { decodePkmd } from "./pkmd.js";
import {
  AlgorithmType,
  parseVbmeta,
  VbmetaImage,
} from "./parser.js";

export class AvbSignError extends AvbBinaryError {}
export class AvbVerifyError extends AvbBinaryError {}

/** DER DigestInfo for SHA-256 per RFC 8017 §9.2 note 1 / avbtool.py:143-146. */
export const SHA256_DIGEST_INFO_DER = new Uint8Array([
  0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04,
  0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
]);

const SHA256_DIGEST_LEN = 32;
const RSA4096_SIG_LEN = 512;
const RSA4096_PKMD_LEN = 1032;

export interface KeyMaterial {
  /** Raw RSA modulus. */
  n: bigint;
  /** Public exponent (65537). */
  e: bigint;
  /** Private exponent d; required only when signing. */
  d?: bigint;
}

function checkRsa4096(img: Uint8Array): void {
  const parsed = parseVbmeta(img);
  if (
    parsed.header.algorithmType !== AlgorithmType.SHA256_RSA4096 ||
    parsed.header.signatureSize !== RSA4096_SIG_LEN
  ) {
    throw new AvbSignError(
      "UNSUPPORTED_ALGORITHM",
      `only SHA256_RSA4096 images are supported, got algorithm ${parsed.header.algorithmType}`,
    );
  }
}

/**
 * Rebuilds the auth block of a SHA256_RSA4096 vbmeta image in place:
 * descriptors, aux block and header fields are preserved byte-for-byte;
 * only the 32-byte hash and 512-byte signature change. The output keeps the
 * input length (release string included) unless overridden.
 *
 * Mirrors _generate_vbmeta_blob (:3250-3283): digest over header‖aux, then the
 * signature, then repack [hash][sig] into the existing auth block geometry.
 */
export async function resignVbmeta(
  img: Uint8Array,
  keyMaterial: CryptoKey | KeyMaterial,
): Promise<Uint8Array> {
  checkRsa4096(img);
  const parsed = parseVbmeta(img);
  return signParsed(img, parsed, keyMaterial, undefined);
}

/**
 * Same as resignVbmeta but lets the caller override the release string.
 * Passing `undefined` keeps the embedded release_string untouched.
 */
export async function resignVbmetaWithRelease(
  img: Uint8Array,
  keyMaterial: CryptoKey | KeyMaterial,
  releaseString?: string,
): Promise<Uint8Array> {
  checkRsa4096(img);
  const parsed = parseVbmeta(img);
  return signParsed(img, parsed, keyMaterial, releaseString);
}

async function signParsed(
  img: Uint8Array,
  parsed: VbmetaImage,
  keyMaterial: CryptoKey | KeyMaterial,
  releaseOverride?: string,
): Promise<Uint8Array> {
  const { header } = parsed;
  if (header.algorithmType !== AlgorithmType.SHA256_RSA4096) {
    throw new AvbSignError(
      "UNSUPPORTED_ALGORITHM",
      `only SHA256_RSA4096 is supported, got algorithm ${header.algorithmType}`,
    );
  }

  let out = Uint8Array.prototype.slice.call(img);
  if (releaseOverride !== undefined) {
    const encoded = new TextEncoder().encode(releaseOverride);
    if (encoded.length > 47) {
      throw new AvbSignError("RELEASE_TOO_LONG", "release string exceeds 47 bytes");
    }
    out.set(encoded, 128);
  }

  // Digest = SHA-256(header ‖ aux), per :3261-3268. Aux sits at 256+authSize.
  const auxStart = 256 + header.authenticationDataBlockSize;
  const dataToHash = out.subarray(0, 256);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    concatForHash(dataToHash, out.subarray(auxStart, auxStart + header.auxiliaryDataBlockSize)),
  );

  // WebCrypto RSASSA-PKCS1-v1_5 takes the raw MESSAGE and hashes internally
  // (RFC 8017 §8.2.2 EMSA-PKCS1-v1_5 inside the primitive), so the message is
  // header‖aux — the same bytes avbtool feeds to its hasher (:468-474). The
  // pre-computed digest is stored in the auth block (:3276-3281) but is NOT
  // what we hand to sign(); feeding it would hash twice.
  let signature: Uint8Array;
  if (keyMaterial instanceof CryptoKey) {
    if (keyMaterial.type !== "private") {
      throw new AvbSignError("BAD_KEY", "expected a private CryptoKey");
    }
    const sigBuf = await crypto.subtle.sign(
      { name: "RSASSA-PKCS1-v1_5" },
      keyMaterial,
      concatForHash(dataToHash, out.subarray(auxStart, auxStart + header.auxiliaryDataBlockSize)),
    );
    signature = new Uint8Array(sigBuf);
  } else {
    const km = keyMaterial;
    if (km.d === undefined) {
      throw new AvbSignError("MISSING_PRIVATE_KEY", "KeyMaterial.d required for signing");
    }
    signature = rawRsaSign(km, emsaPkcs1Sha256(new Uint8Array(digest), modulusByteLength(km)));
  }
  if (signature.length !== RSA4096_SIG_LEN) {
    throw new AvbSignError("BAD_SIGNATURE_LEN", `signature length ${signature.length}`);
  }

  // Auth block layout: [hash at hashOffset][sig at signatureOffset], both taken
  // from the ORIGINAL header so offsets/sizes stay consistent with the block.
  const hashAt = 256 + header.hashOffset;
  const sigAt = 256 + header.signatureOffset;
  if (header.hashSize !== SHA256_DIGEST_LEN) {
    throw new AvbSignError("BAD_HASH_FIELD", `hash_size ${header.hashSize}`);
  }
  out.set(new Uint8Array(digest), hashAt);
  out.set(signature, sigAt);

  // Sanity: the rebuilt auth block must still fit inside the declared sizes.
  if (sigAt + RSA4096_SIG_LEN > 256 + header.authenticationDataBlockSize) {
    throw new AvbSignError("AUTH_OVERFLOW", "signature exceeds auth block");
  }
  return out;
}

function concatForHash(a: Uint8Array, b: Uint8Array): Uint8Array {
  const merged = new Uint8Array(a.length + b.length);
  merged.set(a, 0);
  merged.set(b, a.length);
  return merged;
}

/**
 * EMSA-PKCS1-v1_5 encoding (RFC 8017 §9.2) for SHA-256: 00 01 ‖ FF×(k−3−T)
 * ‖ 00 ‖ DER DigestInfo ‖ digest — byte-identical to avbtool's
 * `padding + digest` block (:474) that the raw RSA op expects.
 */
function emsaPkcs1Sha256(digest: Uint8Array, k: number): Uint8Array {
  const derLen = SHA256_DIGEST_INFO_DER.length;
  const em = new Uint8Array(k);
  em[0] = 0x00;
  em[1] = 0x01;
  const ffCount = k - derLen - digest.length - 3;
  if (ffCount < 8) {
    throw new AvbSignError("EM_TOO_SHORT", `RSA modulus ${k}B too small for PKCS#1 v1.5`);
  }
  em.fill(0xff, 2, 2 + ffCount);
  em[2 + ffCount] = 0x00;
  em.set(SHA256_DIGEST_INFO_DER, 3 + ffCount);
  em.set(digest, 3 + ffCount + derLen);
  return em;
}

function modulusByteLength(key: KeyMaterial): number {
  return (key.n.toString(2).length + 7) >> 3;
}

/** Textbook RSA over the pre-encoded EM block; mirrors openssl rsautl -raw. */
function rawRsaSign(key: KeyMaterial, em: Uint8Array): Uint8Array {
  const k = (key.n.toString(2).length + 7) >> 3;
  if (em.length !== k) {
    throw new AvbSignError("EM_LENGTH", `EM length ${em.length} != modulus length ${k}`);
  }
  const m = beBytesToBigInt(em);
  if (m >= key.n) {
    throw new AvbSignError("EM_RANGE", "EM does not fit below the modulus");
  }
  const c = modPow(m, key.d ?? 0n, key.n);
  return bigIntToBeBytes(c, k);
}

async function importPublicKeyFromPkmd(pkmd: Uint8Array): Promise<CryptoKey> {
  if (pkmd.length !== RSA4096_PKMD_LEN) {
    throw new AvbVerifyError(
      "BAD_PUBKEY_SIZE",
      `embedded public key is ${pkmd.length} bytes, expected ${RSA4096_PKMD_LEN}`,
    );
  }
  const decoded = decodePkmd(pkmd);
  const jwk: JsonWebKey = {
    kty: "RSA",
    n: bigIntToBase64Url(decoded.n),
    e: bigIntToBase64Url(decoded.e),
    alg: "RS256",
    ext: true,
  };
  try {
    return await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
  } catch (cause) {
    throw new AvbCausedError(
      "IMPORT_FAILED",
      "could not import embedded public key",
      cause as Error,
    );
  }
}

function bigIntToBase64Url(value: bigint): string {
  let hex = value.toString(16);
  if (hex.length % 2 === 1) {
    hex = `0${hex}`;
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytesToBase64Url(bytes);
}

export interface VerifyResult {
  ok: boolean;
  failure?: string;
}

/**
 * Full mirror of verify_vbmeta_signature (:548-594) plus the RSA step:
 * recomputes SHA-256(header‖aux), compares against the stored digest, then
 * verifies the signature against the EMBEDDED public key via WebCrypto.
 * Tampering with any byte after offset 4 (i.e. outside the magic) changes the
 * digest or breaks the signature.
 */
export async function verifyVbmeta(img: Uint8Array): Promise<VerifyResult> {
  let parsed;
  try {
    parsed = parseVbmeta(img);
  } catch (cause) {
    return { ok: false, failure: `parse failed: ${(cause as Error).message}` };
  }
  const { header } = parsed;
  if (
    header.algorithmType !== AlgorithmType.SHA256_RSA4096 ||
    !parsed.authHash ||
    !parsed.authSignature ||
    !parsed.publicKey
  ) {
    return { ok: false, failure: "image is not a signed SHA256_RSA4096 vbmeta" };
  }

  // Step 1 — stored digest must equal SHA-256(header‖aux) (:589-594).
  const auxStart = 256 + header.authenticationDataBlockSize;
  const merged = concatForHash(
    img.subarray(0, 256),
    img.subarray(auxStart, auxStart + header.auxiliaryDataBlockSize),
  );
  const computed = new Uint8Array(await crypto.subtle.digest("SHA-256", merged));
  if (!constantTimeEqual(computed, parsed.authHash)) {
    return { ok: false, failure: "digest mismatch: header/aux changed since signing" };
  }

  // Step 2 — RSA-verify signature against embedded key (mirror of :597-652).
  let publicKey: CryptoKey;
  try {
    publicKey = await importPublicKeyFromPkmd(parsed.publicKey);
  } catch (cause) {
    return { ok: false, failure: `public key unusable: ${(cause as Error).message}` };
  }
  try {
    // WebCrypto hashes the raw message internally (RFC 8017 §8.2.2), so pass
    // header‖aux — NOT the stored digest, which would be hashed a second time.
    const ok = await crypto.subtle.verify(
      { name: "RSASSA-PKCS1-v1_5" },
      publicKey,
      parsed.authSignature as BufferSource,
      merged as BufferSource,
    );
    return ok ? { ok: true } : { ok: false, failure: "signature invalid for embedded key" };
  } catch (cause) {
    return { ok: false, failure: `verification error: ${(cause as Error).message}` };
  }
}

/**
 * Verifies using an explicit pkmd instead of the embedded one (avbtool's
 * --key path, :2575-2583). Fails closed when the embedded key differs.
 */
export async function verifyVbmetaAgainstKey(img: Uint8Array, pkmd: Uint8Array): Promise<VerifyResult> {
  const parsed = parseVbmeta(img);
  if (!parsed.publicKey) {
    return { ok: false, failure: "image carries no public key" };
  }
  if (!constantTimeEqual(parsed.publicKey, pkmd)) {
    return { ok: false, failure: "embedded public key does not match given key." };
  }
  return verifyVbmeta(img);
}

/** Convenience: fingerprint of the embedded public key ("SHA256_1032B" style hex). */
export async function embeddedKeyFingerprintHex(img: Uint8Array): Promise<string> {
  const parsed = parseVbmeta(img);
  if (!parsed.publicKey) {
    throw new AvbVerifyError("NO_PUBLIC_KEY", "image has no embedded public key");
  }
  return toHex(new Uint8Array(await crypto.subtle.digest("SHA-256", parsed.publicKey as BufferSource)));
}
