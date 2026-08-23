/**
 * vbmeta image parser — mirrors AvbVBMetaHeader (:2042-2183), AvbFooter
 * (:1978-2039) and _parse_image (:2772-2812) of external/avb/avbtool.py.
 *
 * Header is a fixed 256 bytes ('!4s2L2Q L 2Q*5 Q L L 47sx 80x', :2093-2105);
 * auth and aux block sizes must be multiples of 64 (avb_vbmeta_image.h:100-101).
 */
import { AvbBinaryError, ByteReader, constantTimeEqual } from "./bytes.js";
import {
  Descriptor,
  parseDescriptors,
} from "./descriptors.js";

export const AVB_MAGIC = "AVB0";
export const FOOTER_MAGIC = "AVBf";
export const VBMETA_HEADER_SIZE = 256;
const FOOTER_SIZE = 64;
const MAX_FOOTER_SCAN = 4096; // avbtool.py:2207

export class AvbParseError extends AvbBinaryError {}

/** Algorithm ids per ALGORITHMS dict, avbtool.py:112-197. */
export const enum AlgorithmType {
  NONE = 0,
  SHA256_RSA2048 = 1,
  SHA256_RSA4096 = 2,
  SHA256_RSA8192 = 3,
  SHA512_RSA2048 = 4,
  SHA512_RSA4096 = 5,
}

export function algorithmName(type: number): string {
  switch (type) {
    case AlgorithmType.NONE:
      return "NONE";
    case AlgorithmType.SHA256_RSA2048:
      return "SHA256_RSA2048";
    case AlgorithmType.SHA256_RSA4096:
      return "SHA256_RSA4096";
    case AlgorithmType.SHA256_RSA8192:
      return "SHA256_RSA8192";
    case AlgorithmType.SHA512_RSA2048:
      return "SHA512_RSA2048";
    case AlgorithmType.SHA512_RSA4096:
      return "SHA512_RSA4096";
    default:
      throw new AvbParseError("UNKNOWN_ALGORITHM", `algorithm type ${type} is not supported`);
  }
}

export interface VbmetaHeader {
  magic: string;
  requiredLibavbVersionMajor: number;
  requiredLibavbVersionMinor: number;
  authenticationDataBlockSize: number;
  auxiliaryDataBlockSize: number;
  algorithmType: number;
  hashOffset: number;
  hashSize: number;
  signatureOffset: number;
  signatureSize: number;
  publicKeyOffset: number;
  publicKeySize: number;
  publicKeyMetadataOffset: number;
  publicKeyMetadataSize: number;
  descriptorsOffset: number;
  descriptorsSize: number;
  rollbackIndex: bigint;
  flags: number;
  rollbackIndexLocation: number;
  releaseString: string;
  /** Raw 256-byte header as embedded in the image. */
  raw: Uint8Array;
}

export interface AvbFooter {
  versionMajor: number;
  versionMinor: number;
  originalImageSize: bigint;
  vbmetaOffset: bigint;
  vbmetaSize: bigint;
}

export interface VbmetaImage {
  header: VbmetaHeader;
  /** SHA-256 over header‖aux, from the auth block (undefined for alg NONE). */
  authHash?: Uint8Array | undefined;
  /** Raw RSA signature of header‖aux from the auth block. */
  authSignature?: Uint8Array | undefined;
  descriptors: Descriptor[];
  /** pkmd-encoded public key (1032 B for RSA-4096), if present in the aux block. */
  publicKey?: Uint8Array | undefined;
  /** Public-key metadata blob, if present. */
  publicKeyMetadata?: Uint8Array | undefined;
  footer?: AvbFooter | undefined;
  /**
   * Full parsed blob: header ‖ auth ‖ aux (excludes trailing padding beyond the
   * declared block sizes).
   */
  vbmetaBlob: Uint8Array;
}

function checkAlignment(name: string, value: number): void {
  if (value % 64 !== 0) {
    throw new AvbParseError("BLOCK_ALIGNMENT", `${name} ${value} is not a multiple of 64`);
  }
}

function readFooter(img: Uint8Array): AvbFooter | undefined {
  // avbtool scans back from image_size - 64 and tolerates absence (:2791-2797);
  // READER-B §A prescribes an 'AVBf' scan within the last 4 KiB.
  if (img.length < FOOTER_SIZE) {
    return undefined;
  }
  const scanStart = Math.max(0, img.length - MAX_FOOTER_SCAN);
  let found = -1;
  for (let i = img.length - FOOTER_SIZE; i >= scanStart; i--) {
    if (
      img[i] === 0x41 && // 'A'
      img[i + 1] === 0x56 && // 'V'
      img[i + 2] === 0x42 && // 'B'
      img[i + 3] === 0x66 // 'f'
    ) {
      found = i;
      break;
    }
  }
  if (found < 0) {
    return undefined;
  }
  const r = new ByteReader(img.subarray(found, found + FOOTER_SIZE));
  r.read(4); // magic already matched
  const versionMajor = r.u32();
  const versionMinor = r.u32();
  const originalImageSize = r.u64();
  const vbmetaOffset = r.u64();
  const vbmetaSize = r.u64();
  return { versionMajor, versionMinor, originalImageSize, vbmetaOffset, vbmetaSize };
}

function parseHeader(raw: Uint8Array): VbmetaHeader {
  if (raw.length < VBMETA_HEADER_SIZE) {
    throw new AvbParseError(
      "TRUNCATED",
      `buffer holds ${raw.length} byte(s); a vbmeta header needs ${VBMETA_HEADER_SIZE}`,
    );
  }
  const magic = String.fromCharCode(raw[0] ?? 0, raw[1] ?? 0, raw[2] ?? 0, raw[3] ?? 0);
  if (magic !== AVB_MAGIC) {
    throw new AvbParseError("BAD_MAGIC", `expected magic "${AVB_MAGIC}", got "${magic}"`);
  }
  const r = new ByteReader(raw.subarray(0, VBMETA_HEADER_SIZE));
  r.read(4);
  const requiredLibavbVersionMajor = r.u32();
  const requiredLibavbVersionMinor = r.u32();
  const authenticationDataBlockSize = Number(r.u64());
  const auxiliaryDataBlockSize = Number(r.u64());
  const algorithmType = r.u32();
  const hashOffset = Number(r.u64());
  const hashSize = Number(r.u64());
  const signatureOffset = Number(r.u64());
  const signatureSize = Number(r.u64());
  const publicKeyOffset = Number(r.u64());
  const publicKeySize = Number(r.u64());
  const publicKeyMetadataOffset = Number(r.u64());
  const publicKeyMetadataSize = Number(r.u64());
  const descriptorsOffset = Number(r.u64());
  const descriptorsSize = Number(r.u64());
  const rollbackIndex = r.u64();
  const flags = r.u32();
  const rollbackIndexLocation = r.u32();
  const releaseBytes = r.read(47);
  let end = releaseBytes.length;
  while (end > 0 && releaseBytes[end - 1] === 0) {
    end--;
  }
  const releaseString = new TextDecoder().decode(releaseBytes.subarray(0, end));
  return {
    magic,
    requiredLibavbVersionMajor,
    requiredLibavbVersionMinor,
    authenticationDataBlockSize,
    auxiliaryDataBlockSize,
    algorithmType,
    hashOffset,
    hashSize,
    signatureOffset,
    signatureSize,
    publicKeyOffset,
    publicKeySize,
    publicKeyMetadataOffset,
    publicKeyMetadataSize,
    descriptorsOffset,
    descriptorsSize,
    rollbackIndex,
    flags,
    rollbackIndexLocation,
    releaseString,
    raw: raw.slice(0, VBMETA_HEADER_SIZE),
  };
}

function requireBounds(
  label: string,
  start: number,
  size: number,
  limit: number,
): void {
  if (start < 0 || size < 0 || start + size > limit) {
    throw new AvbParseError(
      "TRUNCATED",
      `${label} [${start}, ${start + size}) exceeds buffer of ${limit} byte(s)`,
    );
  }
}

/**
 * Parses a bare vbmeta blob or a footer-bearing partition image.
 * Mirrors avbtool _parse_image (:2799-2812): vbmeta_offset comes from the
 * footer when one exists, otherwise 0.
 */
export function parseVbmeta(input: Uint8Array): VbmetaImage {
  const img = input;
  const footer = readFooter(img);
  const vbmetaOffset = footer ? Number(footer.vbmetaOffset) : 0;
  if (vbmetaOffset < 0 || vbmetaOffset + VBMETA_HEADER_SIZE > img.length) {
    throw new AvbParseError(
      "TRUNCATED",
      `vbmeta at offset ${vbmetaOffset} does not fit in ${img.length}-byte buffer`,
    );
  }
  const header = parseHeader(img.subarray(vbmetaOffset));
  checkAlignment("authentication_data_block_size", header.authenticationDataBlockSize);
  checkAlignment("auxiliary_data_block_size", header.auxiliaryDataBlockSize);

  const authStart = vbmetaOffset + VBMETA_HEADER_SIZE;
  const auxStart = authStart + header.authenticationDataBlockSize;
  const blobEnd = auxStart + header.auxiliaryDataBlockSize;
  requireBounds("authentication_data_block", authStart, header.authenticationDataBlockSize, img.length);
  requireBounds("auxiliary_data_block", auxStart, header.auxiliaryDataBlockSize, img.length);

  const vbmetaBlob = img.slice(vbmetaOffset, blobEnd);
  const authBlock = img.subarray(authStart, auxStart);
  const auxBlock = img.subarray(auxStart, blobEnd);

  requireBounds("hash", header.hashOffset, header.hashSize, authBlock.length);
  requireBounds("signature", header.signatureOffset, header.signatureSize, authBlock.length);
  requireBounds(
    "public_key",
    header.publicKeyOffset,
    header.publicKeySize,
    auxBlock.length,
  );
  requireBounds(
    "public_key_metadata",
    header.publicKeyMetadataOffset,
    header.publicKeyMetadataSize,
    auxBlock.length,
  );
  requireBounds(
    "descriptors",
    header.descriptorsOffset,
    header.descriptorsSize,
    auxBlock.length,
  );

  const algName = algorithmName(header.algorithmType);
  const expectHash = algName.startsWith("SHA256") ? 32 : algName.startsWith("SHA512") ? 64 : 0;
  if (header.hashSize !== expectHash) {
    throw new AvbParseError(
      "HASH_SIZE_MISMATCH",
      `${algName} requires a ${expectHash}-byte digest, header says ${header.hashSize}`,
    );
  }

  const authHash =
    header.hashSize > 0
      ? authBlock.slice(header.hashOffset, header.hashOffset + header.hashSize)
      : undefined;
  const authSignature =
    header.signatureSize > 0
      ? authBlock.slice(header.signatureOffset, header.signatureOffset + header.signatureSize)
      : undefined;

  const descriptorRegion = auxBlock.subarray(
    header.descriptorsOffset,
    header.descriptorsOffset + header.descriptorsSize,
  );
  const descriptors = header.descriptorsSize > 0 ? parseDescriptors(descriptorRegion) : [];

  const publicKey =
    header.publicKeySize > 0
      ? auxBlock.slice(header.publicKeyOffset, header.publicKeyOffset + header.publicKeySize)
      : undefined;
  const publicKeyMetadata =
    header.publicKeyMetadataSize > 0
      ? auxBlock.slice(
          header.publicKeyMetadataOffset,
          header.publicKeyMetadataOffset + header.publicKeyMetadataSize,
        )
      : undefined;

  return {
    header,
    authHash,
    authSignature,
    descriptors,
    publicKey,
    publicKeyMetadata,
    footer,
    vbmetaBlob,
  };
}

/**
 * Locates an AVB footer by scanning the last 4 KiB for the 'AVBf' magic.
 * Returns undefined for bare vbmeta blobs (make_vbmeta_image output has no footer).
 */
export function parseFooter(img: Uint8Array): AvbFooter | undefined {
  return readFooter(img);
}

/** True when both images carry byte-identical headers. */
export function headersEqual(a: VbmetaHeader, b: VbmetaHeader): boolean {
  return constantTimeEqual(a.raw, b.raw);
}
