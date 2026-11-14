import { ChannelError, StorageQuotaError } from "../src/errors.js";
import type { ArtifactStore } from "../src/types.js";
import {
  assertStorageQuotaForBytes,
  DEFAULT_MAX_IN_MEMORY_BYTES,
  formatMib,
  type StorageEstimateInput,
} from "./quota.js";

const SAFE_NAME = /^[A-Za-z0-9._-]+$/;

export interface HttpArtifactStoreOptions {
  /** Guard against OOM when buffering an artifact in JS memory. */
  readonly maxInMemoryBytes?: number;
  /** Optional storage quota estimator (defaults to navigator.storage.estimate when present). */
  readonly estimateQuota?: () => Promise<StorageEstimateInput | null>;
}

/** Fetch one artifact at a time from the hosted channel directory with OOM/quota guards. */
export class HttpArtifactStore implements ArtifactStore {
  private readonly maxInMemoryBytes: number;
  private readonly estimateQuota: (() => Promise<StorageEstimateInput | null>) | undefined;

  constructor(
    private readonly baseUrl: string,
    options: HttpArtifactStoreOptions = {},
  ) {
    this.maxInMemoryBytes = options.maxInMemoryBytes ?? DEFAULT_MAX_IN_MEMORY_BYTES;
    this.estimateQuota = options.estimateQuota;
  }

  async read(name: string): Promise<Uint8Array> {
    const response = await this.fetchChecked(name);
    const contentLength = parseContentLength(response.headers.get("content-length"));
    if (contentLength !== null) {
      if (contentLength > this.maxInMemoryBytes) {
        throw new StorageQuotaError(
          `Artifact '${name}' (${formatMib(contentLength)}) exceeds in-memory limit ` +
            `(${formatMib(this.maxInMemoryBytes)}); use OPFS/streaming store to avoid OOM`,
        );
      }
      if (this.estimateQuota) {
        assertStorageQuotaForBytes(contentLength, await this.estimateQuota(), name);
      }
    }
    if (!response.body) {
      const buf = new Uint8Array(await response.arrayBuffer());
      if (buf.byteLength > this.maxInMemoryBytes) {
        throw new StorageQuotaError(
          `Artifact '${name}' (${formatMib(buf.byteLength)}) exceeds in-memory limit (${formatMib(this.maxInMemoryBytes)})`,
        );
      }
      return buf;
    }
    return readStreamWithLimit(response.body, this.maxInMemoryBytes, name);
  }

  async readStream(name: string): Promise<ReadableStream<Uint8Array>> {
    const response = await this.fetchChecked(name);
    const contentLength = parseContentLength(response.headers.get("content-length"));
    if (contentLength !== null && this.estimateQuota) {
      assertStorageQuotaForBytes(contentLength, await this.estimateQuota(), name);
    }
    if (!response.body) {
      const bytes = new Uint8Array(await response.arrayBuffer());
      return new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(bytes);
          controller.close();
        },
      });
    }
    return response.body;
  }

  private async fetchChecked(name: string): Promise<Response> {
    if (!SAFE_NAME.test(name) || name.includes("..")) {
      throw new ChannelError(`refusing artifact name: ${name}`);
    }
    const url = `${this.baseUrl}${name}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new ChannelError(`artifact not on server: ${name}`);
    }
    return response;
  }
}

/** Minimal structural OPFS directory handle for streaming multi-GB artifacts without JS heap OOM. */
export interface OpfsWritable {
  write(data: Uint8Array): Promise<void>;
  close(): Promise<void>;
  abort?(reason?: unknown): Promise<void>;
}

export interface OpfsFileHandle {
  createWritable(): Promise<OpfsWritable>;
  getFile(): Promise<{ arrayBuffer(): Promise<ArrayBuffer>; stream?(): ReadableStream<Uint8Array> }>;
}

export interface OpfsDirectoryHandle {
  getFileHandle(name: string, options?: { create?: boolean }): Promise<OpfsFileHandle>;
}

/**
 * OPFS-backed streaming store: pipes HTTP response chunks directly to OPFS
 * after checking origin storage quota, avoiding multi-GB JS heap allocation.
 */
export class OpfsArtifactStore implements ArtifactStore {
  constructor(
    private readonly baseUrl: string,
    private readonly dir: OpfsDirectoryHandle,
    private readonly estimateQuota?: () => Promise<StorageEstimateInput | null>,
  ) {}

  async stageToOpfs(name: string): Promise<OpfsFileHandle> {
    const http = new HttpArtifactStore(this.baseUrl, {
      ...(this.estimateQuota ? { estimateQuota: this.estimateQuota } : {}),
    });
    const stream = await http.readStream(name);
    const handle = await this.dir.getFileHandle(name, { create: true });
    const writable = await handle.createWritable();
    const reader = stream.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          break;
        }
        if (value && value.byteLength > 0) {
          await writable.write(value);
        }
      }
      await writable.close();
    } catch (err) {
      if (typeof writable.abort === "function") {
        await writable.abort(err).catch(() => undefined);
      }
      throw err;
    }
    return handle;
  }

  async read(name: string): Promise<Uint8Array> {
    const handle = await this.stageToOpfs(name);
    const file = await handle.getFile();
    return new Uint8Array(await file.arrayBuffer());
  }

  async readStream(name: string): Promise<ReadableStream<Uint8Array>> {
    const handle = await this.stageToOpfs(name);
    const file = await handle.getFile();
    if (typeof file.stream === "function") {
      return file.stream();
    }
    const bytes = new Uint8Array(await file.arrayBuffer());
    return new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(bytes);
        controller.close();
      },
    });
  }
}

function parseContentLength(header: string | null): number | null {
  if (header === null || header.trim() === "") {
    return null;
  }
  const n = Number(header);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

async function readStreamWithLimit(
  stream: ReadableStream<Uint8Array>,
  maxBytes: number,
  name: string,
): Promise<Uint8Array> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (!value || value.byteLength === 0) {
        continue;
      }
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel("exceeded in-memory limit").catch(() => undefined);
        throw new StorageQuotaError(
          `Artifact '${name}' exceeded in-memory limit (${formatMib(maxBytes)}); use OPFS/streaming store to avoid OOM`,
        );
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}
