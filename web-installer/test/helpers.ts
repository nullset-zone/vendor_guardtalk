import { sha256Hex } from "../src/hash.js";
import {
  assembleChannel,
  parseFilesTxt,
  parseManifestJson,
  parseSha256Sums,
} from "../src/channel.js";
import type {
  ChannelBundle,
  ChannelManifest,
  CommandResult,
  FastbootTransport,
  FlashOptions,
  ReconnectHook,
} from "../src/types.js";
import { MemoryArtifactStore } from "../src/store.js";

export interface FixtureBlob {
  name: string;
  phase: "firmware" | "avb" | "os";
  bytes: Uint8Array;
}

export interface RecordedCommand {
  type: "connect" | "getVar" | "runCommand" | "flash" | "reboot";
  name?: string;
  partition?: string;
  sha256?: string;
  command?: string;
  slot?: "other";
}

export function utf8(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

export function tokayBlobs(): FixtureBlob[] {
  return [
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl-tokay-v1") },
    { name: "radio.img", phase: "firmware", bytes: utf8("radio-tokay-v1") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("public-avb-pkmd") },
    { name: "boot.img", phase: "os", bytes: utf8("boot-tokay-v1") },
    { name: "vbmeta.img", phase: "os", bytes: utf8("vbmeta-tokay-v1") },
  ];
}

export function bundleFromBlobs(
  blobs: FixtureBlob[],
  overrides: Partial<ChannelManifest> = {},
): { channel: ChannelBundle; store: MemoryArtifactStore } {
  const artifacts = blobs.map((b) => ({
    name: b.name,
    phase: b.phase,
    sha256: sha256Hex(b.bytes),
    size: b.bytes.byteLength,
  }));
  const avb = artifacts.find((a) => a.name === "avb_pkmd.bin");
  if (avb === undefined) {
    throw new Error("fixture requires avb_pkmd.bin");
  }
  const manifest = {
    schemaVersion: 1 as const,
    product: "tokay",
    advertisedDevices: ["tokay"],
    reservedProducts: [],
    channel: "dev",
    bootState: "unlocked",
    channelLabel: "dev/unlocked",
    verifiedBootClaim: "none",
    releaseId: "20260725-102506",
    unixEpoch: 1784975106,
    sourceStamp: "tokay-20260725-102506",
    flashOrder: ["firmware", "avb_custom_key", "os"],
    factoryZip: null,
    avb: {
      publicKeyFile: "avb_pkmd.bin" as const,
      sha256: avb.sha256,
      size: avb.size,
    },
    artifacts,
    signature: {
      required: false,
      mode: "hash-only" as const,
      file: null,
      allowedSigners: null,
    },
    ...overrides,
  };
  const sums = blobs
    .map((b) => `${sha256Hex(b.bytes)}  ${b.name}`)
    .join("\n");
  const files = [
    "# name  phase  size",
    ...blobs.map((b) => `${b.name}  ${b.phase}  ${b.bytes.byteLength}`),
  ].join("\n");
  const channel = assembleChannel(
    parseManifestJson(JSON.stringify(manifest)),
    parseSha256Sums(sums),
    parseFilesTxt(files),
  );
  const store = new MemoryArtifactStore(
    new Map(blobs.map((b) => [b.name, b.bytes])),
  );
  return { channel, store };
}

export function channelTextsFromBlobs(blobs: FixtureBlob[]): {
  manifestJson: string;
  sha256sums: string;
  filesTxt: string;
} {
  const { channel } = bundleFromBlobs(blobs);
  const manifestJson = JSON.stringify(channel.manifest, null, 2);
  const sha256sums = [...channel.sha256sums.entries()]
    .map(([name, digest]) => `${digest}  ${name}`)
    .join("\n");
  const filesTxt = channel.files
    .map((f) => `${f.name}  ${f.phase}  ${f.size}`)
    .join("\n");
  return { manifestJson, sha256sums, filesTxt };
}

export class MockFastboot implements FastbootTransport {
  readonly dryRun: boolean;
  readonly log: RecordedCommand[] = [];
  product = "tokay";
  unlocked = "no";
  snapshot = "none";
  unlockOk = true;
  lockOk = true;
  connectCalls = 0;
  reconnects = 0;

  constructor(opts: { live?: boolean } = {}) {
    this.dryRun = opts.live !== true;
  }

  async connect(): Promise<void> {
    this.connectCalls += 1;
    this.log.push({ type: "connect" });
  }

  async getVar(name: string): Promise<string> {
    this.log.push({ type: "getVar", name });
    if (name === "product") {
      return this.product;
    }
    if (name === "unlocked") {
      return this.unlocked;
    }
    if (name === "snapshot-update-status") {
      return this.snapshot;
    }
    throw new Error(`unexpected getvar ${name}`);
  }

  async runCommand(command: string): Promise<CommandResult> {
    this.log.push({ type: "runCommand", command });
    if (command === "flashing unlock") {
      return { ok: this.unlockOk, text: this.unlockOk ? "OKAY" : "FAIL" };
    }
    if (command === "flashing lock") {
      return { ok: this.lockOk, text: this.lockOk ? "OKAY" : "FAIL" };
    }
    return { ok: true, text: "OKAY" };
  }

  async flash(
    partition: string,
    data: Uint8Array,
    options?: FlashOptions,
  ): Promise<void> {
    const entry: RecordedCommand = {
      type: "flash",
      partition,
      sha256: sha256Hex(data),
    };
    if (options?.slot !== undefined) {
      entry.slot = options.slot;
    }
    this.log.push(entry);
  }

  async rebootBootloader(onReconnect: ReconnectHook): Promise<void> {
    this.log.push({ type: "reboot" });
    await onReconnect();
    this.reconnects += 1;
    this.connectCalls += 1;
  }
}
