/**
 * Android sparse image chunker.
 *
 * Parses the Android sparse header (magic 0xED26FF3A, big-endian fields) and
 * emits ordered data chunks ready for `download:` transfers. Raw (non-sparse)
 * images pass through as a single chunk. Reference: system/core/libsparse
 * sparse_format.h; READER-B §E ("sparse images supported by chunked download").
 *
 * Header layout (all big-endian):
 *   u32 magic        0xED26FF3A
 *   u16 major_version
 *   u16 minor_version
 *   u16 file_header_sz
 *   u16 chunk_header_sz
 *   u32 block_size
 *   u32 total_blocks          (in output blocks)
 *   u32 total_chunks
 *   u32 image_checksum        (CRC32 of original data; not verified here)
 */
import { ProtocolError } from "./protocol.js";

export const SPARSE_MAGIC = 0xed26ff3a;

/**
 * Stated, pre-transfer refusal for images whose size defeats the device's
 * download budget. Raised BEFORE any `download:`/`flash:` is sent — a blind
 * re-split of one logical write across multiple flash: rounds is forbidden.
 */
export const OVERSIZE_IMAGE_MESSAGE =
  "image larger than max-download-size — cannot flash safely";

export class SparseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export interface SparseHeader {
  majorVersion: number;
  minorVersion: number;
  fileHeaderSize: number;
  chunkHeaderSize: number;
  blockSize: number;
  totalBlocks: number;
  totalChunks: number;
}

export interface SparseChunk {
  type: "RAW" | "FILL" | "DONT_CARE" | "CRC32";
  /** Expanded byte length of this chunk in the output image. */
  outputSize: number;
  /** Bytes to transfer over download: (expanded data, empty for metadata chunks). */
  data: Uint8Array;
}

const U32 = 4;

function beU32(buf: Uint8Array, off: number): number {
  return (
    (((buf[off] as number) << 24) |
      ((buf[off + 1] as number) << 16) |
      ((buf[off + 2] as number) << 8) |
      (buf[off + 3] as number)) >>>
    0
  );
}

function beU16(buf: Uint8Array, off: number): number {
  return (((buf[off] as number) << 8) | (buf[off + 1] as number)) >>> 0;
}

/** True if the buffer starts with the sparse magic and a plausible header. */
export function isSparseImage(data: Uint8Array): boolean {
  return data.length >= 28 && beU32(data, 0) === SPARSE_MAGIC;
}

export function parseSparseHeader(data: Uint8Array): SparseHeader {
  if (!isSparseImage(data)) {
    throw new SparseError("not an Android sparse image (bad magic)");
  }
  const header: SparseHeader = {
    majorVersion: beU16(data, 4),
    minorVersion: beU16(data, 6),
    fileHeaderSize: beU16(data, 8),
    chunkHeaderSize: beU16(data, 10),
    blockSize: beU32(data, 12),
    totalBlocks: beU32(data, 16),
    totalChunks: beU32(data, 20),
  };
  if (header.blockSize === 0 || header.blockSize % 512 !== 0) {
    throw new SparseError(`implausible block size ${String(header.blockSize)}`);
  }
  return header;
}

/**
 * Expand a sparse image into ordered transfer-ready chunks:
 * RAW → stored bytes, FILL → repeated fill dword expanded to block size,
 * DONT_CARE/CRC32 → zero-length bookkeeping (nothing to download).
 * Output order matches file order so concatenated DATA payloads reproduce
 * the physical image exactly.
 */
export function sparseChunks(data: Uint8Array): SparseChunk[] {
  const header = parseSparseHeader(data);
  if (header.majorVersion !== 1) {
    throw new SparseError(`unsupported sparse version ${String(header.majorVersion)}`);
  }
  const chunks: SparseChunk[] = [];
  let off = header.fileHeaderSize;
  for (let i = 0; i < header.totalChunks; i += 1) {
    if (off + header.chunkHeaderSize > data.length) {
      throw new SparseError(`chunk ${String(i)} header out of bounds`);
    }
    const typeRaw = beU16(data, off);
    const chunkDataSize = beU32(data, off + U32);
    const body = off + header.chunkHeaderSize;
    if (body + chunkDataSize > data.length) {
      throw new SparseError(`chunk ${String(i)} data out of bounds`);
    }
    switch (typeRaw) {
      case 0xcac1: {
        // RAW: chunkDataSize must be a whole number of blocks.
        if (chunkDataSize % header.blockSize !== 0) {
          throw new SparseError(`RAW chunk ${String(i)} size not block-aligned`);
        }
        chunks.push({
          type: "RAW",
          outputSize: chunkDataSize,
          data: data.slice(body, body + chunkDataSize),
        });
        break;
      }
      case 0xcac2: {
        // FILL: 4-byte pattern repeated for the declared block count.
        if (chunkDataSize !== U32) {
          throw new SparseError(`FILL chunk ${String(i)} must carry exactly 4 bytes`);
        }
        const blocks = readChunkBlocks(data, off, header.chunkHeaderSize);
        const outLen = blocks * header.blockSize;
        const fillWord = beU32(data, body);
        chunks.push({
          type: "FILL",
          outputSize: outLen,
          data: expandFill(fillWord, outLen),
        });
        break;
      }
      case 0xcac3: {
        // DONT_CARE: nothing to transfer.
        expectNoData("DONT_CARE", i, chunkDataSize);
        chunks.push({ type: "DONT_CARE", outputSize: 0, data: new Uint8Array(0) });
        break;
      }
      case 0xcac4: {
        // CRC32 checksum chunk: metadata only.
        expectNoData("CRC32", i, chunkDataSize);
        chunks.push({ type: "CRC32", outputSize: 0, data: new Uint8Array(0) });
        break;
      }
      default:
        throw new SparseError(`unknown sparse chunk type 0x${typeRaw.toString(16)} at ${String(i)}`);
    }
    off = body + chunkDataSize;
  }
  return chunks;
}

/**
 * Transfer plan for the fastboot client: raw images pass through unchanged
 * (one chunk, same bytes); sparse images expand to their physical byte
 * sequence in file order.
 */
export function imageDownloadChunks(image: Uint8Array): Uint8Array[] {
  if (!isSparseImage(image)) {
    return [image];
  }
  return sparseChunks(image)
    .filter((c) => c.data.length > 0)
    .map((c) => c.data);
}

/** True when the sparse layout uses chunk kinds expansion cannot honour. */
function hasUnsupportedSemantics(chunks: readonly SparseChunk[]): boolean {
  return chunks.some((c) => c.type === "DONT_CARE" || c.type === "CRC32");
}

/**
 * H2 transfer plan: pack the expanded image byte stream into download units
 * that each fit `budget` bytes.
 *
 * Policy (byte-exactness audit H2): a sparse image is ONE logical partition
 * write. It may be streamed as consecutive download:+flash: rounds on the
 * SAME partition — each round appending at the device's write cursor (the
 * semantics SimulatedDevice models). What is NEVER allowed is splitting a
 * single logical unit larger than the budget into multiple flash: rounds,
 * because a real bootloader restarts each flash: at offset 0 and later
 * chunks would silently overwrite earlier ones. So:
 *
 * - raw images must fit the budget in one download: — else ProtocolError;
 * - sparse layouts carrying DONT_CARE/CRC32 are refused outright (expansion
 *   cannot reproduce skip/verify semantics);
 * - expanded sparse bytes are packed greedily into ≤budget units;
 * - any single expanded chunk larger than the budget ⇒ ProtocolError BEFORE
 *   any transfer (`OVERSIZE_IMAGE_MESSAGE`).
 *
 * `budget` must be a positive safe integer; callers source it from
 * `getvar:max-download-size`.
 */
export function imageTransferUnits(image: Uint8Array, budget: number): Uint8Array[] {
  assertPositiveBudget(budget);
  const chunks = isSparseImage(image) ? sparseChunks(image) : [{ type: "RAW" as const, outputSize: image.length, data: image }];
  if (hasUnsupportedSemantics(chunks)) {
    throw new ProtocolError(
      "sparse image contains DONT_CARE/CRC32 chunks — cannot flash safely without skip/verify semantics",
    );
  }
  for (const chunk of chunks) {
    if (chunk.data.length > budget) {
      throw new ProtocolError(`${OVERSIZE_IMAGE_MESSAGE} (chunk ${String(chunk.data.length)} > budget ${String(budget)})`);
    }
  }
  return groupIntoBudgetUnits(
    chunks.filter((c) => c.data.length > 0).map((c) => c.data),
    budget,
  );
}

function assertPositiveBudget(budget: number): void {
  if (!Number.isSafeInteger(budget) || budget <= 0) {
    throw new ProtocolError(`unusable max-download-size: ${JSON.stringify(String(budget))}`);
  }
}

/** Greedy first-fit packing; every part already fits `budget` (asserted above). */
function groupIntoBudgetUnits(parts: readonly Uint8Array[], budget: number): Uint8Array[] {
  const units: Uint8Array[] = [];
  let current: Uint8Array[] = [];
  let currentLength = 0;
  const flush = (): void => {
    if (current.length > 0) {
      units.push(concatBytes(current));
      current = [];
      currentLength = 0;
    }
  };
  for (const part of parts) {
    if (part.length + currentLength > budget) {
      flush();
    }
    current.push(part);
    currentLength += part.length;
  }
  flush();
  return units;
}

function concatBytes(parts: readonly Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const part of parts) {
    out.set(part, off);
    off += part.length;
  }
  return out;
}

function expectNoData(kind: string, index: number, size: number): void {
  if (size !== 0) {
    throw new SparseError(`${kind} chunk ${String(index)} must carry no data`);
  }
}

function readChunkBlocks(data: Uint8Array, chunkOff: number, chunkHdrSz: number): number {
  if (chunkHdrSz < 12) {
    throw new SparseError("chunk header too small for FILL");
  }
  return beU32(data, chunkOff + 8);
}

function expandFill(word: number, length: number): Uint8Array {
  const out = new Uint8Array(length);
  const view = new DataView(out.buffer);
  for (let off = 0; off + U32 <= length; off += U32) {
    view.setUint32(off, word);
  }
  return out;
}
