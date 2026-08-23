/**
 * AVB descriptor parse/encode roundtrip.
 *
 * Wire layouts mirror the struct.pack/unpack FORMAT_STRINGs and encode()
 * methods of external/avb/avbtool.py:
 *   - base header      :1181, encode() :1216-1228
 *   - property (tag 0) :1266-1268, encode() :1319-1334
 *   - hashtree (tag 1) :1381-1396, encode() :1487-1508
 *   - hash (tag 2)     :1588-1595, encode() :1658-1676
 *   - cmdline (tag 3)  :1728-1730, encode() :1776-1789
 *   - chain (tag 4)    :1826-1831, encode() :1887-1903
 * Every descriptor is padded with zeros to an 8-byte multiple (:1223-1227).
 */
import {
  AvbBinaryError,
  ByteReader,
  ByteWriter,
  constantTimeEqual,
  roundUpTo,
} from "./bytes.js";

export const DESCRIPTOR_TAG_PROPERTY = 0;
export const DESCRIPTOR_TAG_HASHTREE = 1;
export const DESCRIPTOR_TAG_HASH = 2;
export const DESCRIPTOR_TAG_KERNEL_CMDLINE = 3;
export const DESCRIPTOR_TAG_CHAIN = 4;

/** Common 16-byte descriptor header: tag + num_bytes_following ('!QQ'). */
const HEADER_SIZE = 16;
const HASHTREE_RESERVED = 60; // avbtool.py:1379
const HASH_RESERVED = 60; // avbtool.py:1586
const CHAIN_RESERVED = 60; // avbtool.py:1824

export interface PropertyDescriptor {
  readonly tag: typeof DESCRIPTOR_TAG_PROPERTY;
  /** UTF-8 key bytes, exactly as encoded on the wire. */
  keyBytes: Uint8Array;
  valueBytes: Uint8Array;
}

export interface HashtreeDescriptor {
  readonly tag: typeof DESCRIPTOR_TAG_HASHTREE;
  dmVerityVersion: number;
  imageSize: bigint;
  treeOffset: bigint;
  treeSize: bigint;
  dataBlockSize: number;
  hashBlockSize: number;
  fecNumRoots: number;
  fecOffset: bigint;
  fecSize: bigint;
  hashAlgorithm: string;
  partitionName: string;
  salt: Uint8Array;
  rootDigest: Uint8Array;
  flags: number;
}

export interface HashDescriptor {
  readonly tag: typeof DESCRIPTOR_TAG_HASH;
  imageSize: bigint;
  hashAlgorithm: string;
  partitionName: string;
  salt: Uint8Array;
  digest: Uint8Array;
  flags: number;
}

export interface KernelCmdlineDescriptor {
  readonly tag: typeof DESCRIPTOR_TAG_KERNEL_CMDLINE;
  flags: number;
  kernelCmdline: string;
}

export interface ChainPartitionDescriptor {
  readonly tag: typeof DESCRIPTOR_TAG_CHAIN;
  rollbackIndexLocation: number;
  partitionName: string;
  publicKey: Uint8Array;
  flags: number;
}

export type Descriptor =
  | PropertyDescriptor
  | HashtreeDescriptor
  | HashDescriptor
  | KernelCmdlineDescriptor
  | ChainPartitionDescriptor;

export class AvbDescriptorError extends AvbBinaryError {}

function decodeUtf8(bytes: Uint8Array, what: string): string {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new AvbDescriptorError("UTF8_DECODE", `${what} cannot be decoded as UTF-8`);
  }
}

function asciiField(bytes: Uint8Array): string {
  // avbtool rstrips NUL bytes then decodes ASCII (:1426, :1619).
  let end = bytes.length;
  while (end > 0 && bytes[end - 1] === 0) {
    end--;
  }
  return new TextDecoder("ascii").decode(bytes.subarray(0, end));
}

function checkTagAndSize(
  tag: number,
  expectedTag: number,
  numFollowWithPadding: number,
  bodyLength: number,
  name: string,
): void {
  if (tag !== expectedTag || numFollowWithPadding !== roundUpTo(bodyLength, 8)) {
    throw new AvbDescriptorError(
      "MALFORMED_DESCRIPTOR",
      `data does not look like a ${name} descriptor`,
    );
  }
}

function parseProperty(r: ByteReader, tag: number, nbf: number): PropertyDescriptor {
  // SIZE=32 total incl. 16B common header; key_size + value_size u64 each (:1265-1268).
  const keySize = Number(r.u64());
  const valueSize = Number(r.u64());
  const body = 16 + keySize + 1 + valueSize + 1; // ':1285-1286' — sizes(16) + key + NUL + value + NUL
  checkTagAndSize(tag, DESCRIPTOR_TAG_PROPERTY, nbf, body, "property");
  const keyBytes = r.read(keySize);
  r.skip(1);
  const valueBytes = r.read(valueSize);
  r.skip(1);
  return { tag: DESCRIPTOR_TAG_PROPERTY, keyBytes, valueBytes };
}

function parseHashtree(r: ByteReader, tag: number, nbf: number): HashtreeDescriptor {
  // SIZE = 120 fixed fields + 60 reserved = 180 incl. common header (:1379-1396).
  const dmVerityVersion = r.u32();
  const imageSize = r.u64();
  const treeOffset = r.u64();
  const treeSize = r.u64();
  const dataBlockSize = r.u32();
  const hashBlockSize = r.u32();
  const fecNumRoots = r.u32();
  const fecOffset = r.u64();
  const fecSize = r.u64();
  const hashAlgorithm = asciiField(r.read(32));
  const partitionNameLen = r.u32();
  const saltLen = r.u32();
  const rootDigestLen = r.u32();
  const flags = r.u32();
  r.skip(HASHTREE_RESERVED);
  // SIZE-16 = 104 fixed bytes + 60 reserved = 164 (avbtool.py:1380-1396).
  const body = 164 + partitionNameLen + saltLen + rootDigestLen;
  checkTagAndSize(tag, DESCRIPTOR_TAG_HASHTREE, nbf, body, "hashtree");
  const partitionName = decodeUtf8(r.read(partitionNameLen), "partition name");
  const salt = r.read(saltLen);
  const rootDigest = r.read(rootDigestLen);
  if (rootDigestLen !== 0 && rootDigestLen !== digestSizeForAlgorithm(hashAlgorithm)) {
    throw new AvbDescriptorError("DIGEST_LEN_MISMATCH", "root_digest_len doesn't match hash algorithm");
  }
  return {
    tag: DESCRIPTOR_TAG_HASHTREE,
    dmVerityVersion,
    imageSize,
    treeOffset,
    treeSize,
    dataBlockSize,
    hashBlockSize,
    fecNumRoots,
    fecOffset,
    fecSize,
    hashAlgorithm,
    partitionName,
    salt,
    rootDigest,
    flags,
  };
}

function parseHash(r: ByteReader, tag: number, nbf: number): HashDescriptor {
  // SIZE = 56 fixed fields + 60 reserved = 116 incl. common header (:1587-1595).
  const imageSize = r.u64();
  const hashAlgorithm = asciiField(r.read(32));
  const partitionNameLen = r.u32();
  const saltLen = r.u32();
  const digestLen = r.u32();
  const flags = r.u32();
  r.skip(HASH_RESERVED);
  // SIZE-16 = 56 fixed bytes + 60 reserved = 116 (avbtool.py:1587-1595).
  const body = 116 + partitionNameLen + saltLen + digestLen;
  checkTagAndSize(tag, DESCRIPTOR_TAG_HASH, nbf, body, "hash");
  const partitionName = decodeUtf8(r.read(partitionNameLen), "partition name");
  const salt = r.read(saltLen);
  const digest = r.read(digestLen);
  if (digestLen !== 0 && digestLen !== digestSizeForAlgorithm(hashAlgorithm)) {
    throw new AvbDescriptorError("DIGEST_LEN_MISMATCH", "digest_len doesn't match hash algorithm");
  }
  return {
    tag: DESCRIPTOR_TAG_HASH,
    imageSize,
    hashAlgorithm,
    partitionName,
    salt,
    digest,
    flags,
  };
}

function parseKernelCmdline(r: ByteReader, tag: number, nbf: number): KernelCmdlineDescriptor {
  const flags = r.u32();
  const cmdlineLen = r.u32();
  // SIZE-16 = 8 (avbtool.py:1727-1730); cmdline has no reserved bytes.
  const body = 8 + cmdlineLen;
  checkTagAndSize(tag, DESCRIPTOR_TAG_KERNEL_CMDLINE, nbf, body, "kernel cmdline");
  const kernelCmdline = decodeUtf8(r.read(cmdlineLen), "kernel command-line");
  return { tag: DESCRIPTOR_TAG_KERNEL_CMDLINE, flags, kernelCmdline };
}

function parseChain(r: ByteReader, tag: number, nbf: number): ChainPartitionDescriptor {
  // SIZE = 16 fixed fields + 60 reserved = 92 incl. common header (:1824-1831).
  const rollbackIndexLocation = r.u32();
  const partitionNameLen = r.u32();
  const publicKeyLen = r.u32();
  const flags = r.u32();
  r.skip(CHAIN_RESERVED);
  // SIZE-16 = 16 fixed bytes + 60 reserved = 76 (avbtool.py:1825-1831).
  const body = 76 + partitionNameLen + publicKeyLen;
  checkTagAndSize(tag, DESCRIPTOR_TAG_CHAIN, nbf, body, "chain partition");
  const partitionName = decodeUtf8(r.read(partitionNameLen), "partition name");
  const publicKey = r.read(publicKeyLen);
  return { tag: DESCRIPTOR_TAG_CHAIN, rollbackIndexLocation, partitionName, publicKey, flags };
}

/** SHA-256 / SHA-512 output sizes; mirrors hashlib.new(name).digest_size. */
function digestSizeForAlgorithm(hashAlgorithm: string): number {
  switch (hashAlgorithm) {
    case "sha256":
      return 32;
    case "sha512":
      return 64;
    default:
      return 0;
  }
}

function encodeProperty(d: PropertyDescriptor): Uint8Array {
  // Mirrors AvbPropertyDescriptor.encode() :1319-1334.
  // num_bytes_following = SIZE(32) + key + value + 2 NULs - 16 = 16 + key + value + 2.
  const w = new ByteWriter();
  const numFollow = 16 + d.keyBytes.length + d.valueBytes.length + 2;
  const padding = roundUpTo(numFollow, 8) - numFollow;
  w.u64(BigInt(DESCRIPTOR_TAG_PROPERTY)).u64(BigInt(roundUpTo(numFollow, 8)));
  w.u64(BigInt(d.keyBytes.length)).u64(BigInt(d.valueBytes.length));
  w.bytes(d.keyBytes).zeros(1).bytes(d.valueBytes).zeros(1).zeros(padding);
  return w.toUint8Array();
}

function encodeHashtree(d: HashtreeDescriptor): Uint8Array {
  // Mirrors AvbHashtreeDescriptor.encode() :1487-1508.
  const w = new ByteWriter();
  const nameLen = new TextEncoder().encode(d.partitionName).length;
  // num_bytes_following = SIZE(180) + name + salt + root_digest - 16 (:1495-1496);
  // the 60 reserved bytes count toward the size.
  const numFollow = 164 + nameLen + d.salt.length + d.rootDigest.length;
  const padding = roundUpTo(numFollow, 8) - numFollow;
  w.u64(BigInt(DESCRIPTOR_TAG_HASHTREE)).u64(BigInt(roundUpTo(numFollow, 8)));
  w.u32(d.dmVerityVersion).u64(d.imageSize).u64(d.treeOffset).u64(d.treeSize);
  w.u32(d.dataBlockSize).u32(d.hashBlockSize).u32(d.fecNumRoots);
  w.u64(d.fecOffset).u64(d.fecSize);
  w.fixedUtf8(d.hashAlgorithm, 32);
  w.u32(nameLen).u32(d.salt.length).u32(d.rootDigest.length).u32(d.flags);
  w.zeros(HASHTREE_RESERVED);
  const enc = new TextEncoder();
  w.bytes(enc.encode(d.partitionName)).bytes(d.salt).bytes(d.rootDigest).zeros(padding);
  return w.toUint8Array();
}

function encodeHash(d: HashDescriptor): Uint8Array {
  // Mirrors AvbHashDescriptor.encode() :1658-1676.
  const w = new ByteWriter();
  const nameLen = new TextEncoder().encode(d.partitionName).length;
  // num_bytes_following = SIZE(132) + name + salt + digest - 16 (:1666-1667);
  // the 60 reserved bytes count toward the size.
  const numFollow = 116 + nameLen + d.salt.length + d.digest.length;
  const padding = roundUpTo(numFollow, 8) - numFollow;
  w.u64(BigInt(DESCRIPTOR_TAG_HASH)).u64(BigInt(roundUpTo(numFollow, 8)));
  w.u64(d.imageSize);
  w.fixedUtf8(d.hashAlgorithm, 32);
  w.u32(nameLen).u32(d.salt.length).u32(d.digest.length).u32(d.flags);
  w.zeros(HASH_RESERVED);
  const enc = new TextEncoder();
  w.bytes(enc.encode(d.partitionName)).bytes(d.salt).bytes(d.digest).zeros(padding);
  return w.toUint8Array();
}

function encodeKernelCmdline(d: KernelCmdlineDescriptor): Uint8Array {
  // Mirrors AvbKernelCmdlineDescriptor.encode() :1776-1789.
  const w = new ByteWriter();
  const cmdLen = new TextEncoder().encode(d.kernelCmdline).length;
  const numFollow = 8 + cmdLen;
  const padding = roundUpTo(numFollow, 8) - numFollow;
  w.u64(BigInt(DESCRIPTOR_TAG_KERNEL_CMDLINE)).u64(BigInt(roundUpTo(numFollow, 8)));
  w.u32(d.flags).u32(cmdLen);
  w.bytes(new TextEncoder().encode(d.kernelCmdline)).zeros(padding);
  return w.toUint8Array();
}

function encodeChain(d: ChainPartitionDescriptor): Uint8Array {
  // Mirrors AvbChainPartitionDescriptor.encode() :1887-1903.
  const w = new ByteWriter();
  const nameLen = new TextEncoder().encode(d.partitionName).length;
  // num_bytes_following = SIZE(92) + name + pubkey - 16 (:1894-1895).
  const numFollow = 76 + nameLen + d.publicKey.length;
  const padding = roundUpTo(numFollow, 8) - numFollow;
  w.u64(BigInt(DESCRIPTOR_TAG_CHAIN)).u64(BigInt(roundUpTo(numFollow, 8)));
  w.u32(d.rollbackIndexLocation).u32(nameLen).u32(d.publicKey.length).u32(d.flags);
  w.zeros(CHAIN_RESERVED);
  const enc = new TextEncoder();
  w.bytes(enc.encode(d.partitionName)).bytes(d.publicKey).zeros(padding);
  return w.toUint8Array();
}

/** Parses one wire-format descriptor starting at the head of `r`. */
export function parseSingleDescriptor(r: ByteReader): Descriptor {
  const tag = Number(r.u64());
  const numFollowWithPadding = Number(r.u64());
  let parsed: Descriptor;

  switch (tag) {
    case DESCRIPTOR_TAG_PROPERTY:
      parsed = parseProperty(r, tag, numFollowWithPadding);
      break;
    case DESCRIPTOR_TAG_HASHTREE:
      parsed = parseHashtree(r, tag, numFollowWithPadding);
      break;
    case DESCRIPTOR_TAG_HASH:
      parsed = parseHash(r, tag, numFollowWithPadding);
      break;
    case DESCRIPTOR_TAG_KERNEL_CMDLINE:
      parsed = parseKernelCmdline(r, tag, numFollowWithPadding);
      break;
    case DESCRIPTOR_TAG_CHAIN:
      parsed = parseChain(r, tag, numFollowWithPadding);
      break;
    default:
      parsed = {
        tag,
        unknownBody: r.read(numFollowWithPadding),
      } as unknown as Descriptor;
  }
  return parsed;
}

/** Parses a descriptors region into typed objects (mirrors parse_descriptors :1955-1975). */
export function parseDescriptors(data: Uint8Array): Descriptor[] {
  const out: Descriptor[] = [];
  const total = data.length;
  let consumed = 0;
  while (consumed < total) {
    if (total - consumed < HEADER_SIZE) {
      throw new AvbDescriptorError(
        "TRUNCATED_DESCRIPTOR",
        `trailing ${total - consumed} byte(s) cannot hold a descriptor header`,
      );
    }
    const r = new ByteReader(data.subarray(consumed));
    out.push(parseSingleDescriptor(r));
    // num_bytes_following includes the 16-byte header, so progress is exact.
    const tagView = new DataView(data.buffer, data.byteOffset + consumed, 16);
    const nbf = Number(tagView.getBigUint64(8, false));
    consumed += 16 + nbf;
  }
  return out;
}

/** Serializes a descriptor back to wire format, including 8-byte zero padding. */
export function encodeDescriptor(d: Descriptor): Uint8Array {
  switch (d.tag) {
    case DESCRIPTOR_TAG_PROPERTY:
      return encodeProperty(d);
    case DESCRIPTOR_TAG_HASHTREE:
      return encodeHashtree(d);
    case DESCRIPTOR_TAG_HASH:
      return encodeHash(d);
    case DESCRIPTOR_TAG_KERNEL_CMDLINE:
      return encodeKernelCmdline(d);
    case DESCRIPTOR_TAG_CHAIN:
      return encodeChain(d);
    default: {
      const unknown = d as { tag: number; unknownBody?: Uint8Array };
      const body = unknown.unknownBody ?? new Uint8Array(0);
      const padding = roundUpTo(body.length, 8) - body.length;
      const w = new ByteWriter();
      w.u64(BigInt(unknown.tag)).u64(BigInt(roundUpTo(body.length, 8)));
      w.bytes(body).zeros(padding);
      return w.toUint8Array();
    }
  }
}

export function isPropertyDescriptor(d: Descriptor): d is PropertyDescriptor {
  return d.tag === DESCRIPTOR_TAG_PROPERTY;
}
export function isHashtreeDescriptor(d: Descriptor): d is HashtreeDescriptor {
  return d.tag === DESCRIPTOR_TAG_HASHTREE;
}
export function isHashDescriptor(d: Descriptor): d is HashDescriptor {
  return d.tag === DESCRIPTOR_TAG_HASH;
}
export function isKernelCmdlineDescriptor(d: Descriptor): d is KernelCmdlineDescriptor {
  return d.tag === DESCRIPTOR_TAG_KERNEL_CMDLINE;
}
export function isChainDescriptor(d: Descriptor): d is ChainPartitionDescriptor {
  return d.tag === DESCRIPTOR_TAG_CHAIN;
}

/** True when two parsed descriptors are field-for-field identical. */
export function descriptorsEqual(a: Descriptor, b: Descriptor): boolean {
  if (a.tag !== b.tag) {
    return false;
  }
  const ea = encodeDescriptor(a);
  const eb = encodeDescriptor(b);
  return constantTimeEqual(ea, eb);
}
