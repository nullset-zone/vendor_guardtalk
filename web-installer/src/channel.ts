import { assertManifestAllowlist } from "./allowlist.js";
import { ChannelError } from "./errors.js";
import { normalizeSha256 } from "./hash.js";
import {
  ARTIFACT_PHASES,
  FLASH_ORDER,
  type ArtifactPhase,
  type ChannelArtifact,
  type ChannelBundle,
  type ChannelManifest,
  type FileListEntry,
} from "./types.js";

const NAME_RE = /^[A-Za-z0-9._-]+$/;
const SECRET_NAME_RE = /\.(pem|pk8)$/i;

export function parseSha256Sums(text: string): Map<string, string> {
  const out = new Map<string, string>();
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) {
      continue;
    }
    const match = /^([a-fA-F0-9]{64}) [ *](.+)$/.exec(line);
    if (!match) {
      throw new ChannelError(`invalid SHA256SUMS line: ${line}`);
    }
    const digest = normalizeSha256(match[1] ?? "");
    const name = (match[2] ?? "").trim();
    assertSafeName(name);
    if (out.has(name)) {
      throw new ChannelError(`duplicate SHA256SUMS entry: ${name}`);
    }
    out.set(name, digest);
  }
  if (out.size === 0) {
    throw new ChannelError("SHA256SUMS is empty");
  }
  return out;
}

export function parseFilesTxt(text: string): FileListEntry[] {
  const files: FileListEntry[] = [];
  const seen = new Set<string>();
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) {
      continue;
    }
    const match = /^(\S+)\s+(firmware|avb|os)\s+(\d+)$/.exec(line);
    if (!match) {
      throw new ChannelError(`invalid files.txt line: ${line}`);
    }
    const name = match[1] ?? "";
    const phaseRaw = match[2] ?? "";
    if (!isArtifactPhase(phaseRaw)) {
      throw new ChannelError(`invalid files.txt phase: ${phaseRaw}`);
    }
    const size = Number(match[3]);
    assertSafeName(name);
    if (seen.has(name)) {
      throw new ChannelError(`duplicate files.txt entry: ${name}`);
    }
    seen.add(name);
    files.push({ name, phase: phaseRaw, size });
  }
  if (files.length === 0) {
    throw new ChannelError("files.txt lists no artifacts");
  }
  return files;
}

export function parseManifestJson(text: string): ChannelManifest {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text) as unknown;
  } catch {
    throw new ChannelError("manifest.json is not valid JSON");
  }
  if (!isRecord(parsed)) {
    throw new ChannelError("manifest.json must be an object");
  }
  const manifest = readManifest(parsed);
  assertManifestAllowlist(manifest);
  return manifest;
}

export function assembleChannel(
  manifest: ChannelManifest,
  sha256sums: ReadonlyMap<string, string>,
  files: FileListEntry[],
): ChannelBundle {
  assertFlashOrder(manifest.flashOrder);
  if (manifest.factoryZip !== null) {
    throw new ChannelError(
      "factoryZip must be null this wave; consume files.txt + SHA256SUMS",
    );
  }
  if (manifest.verifiedBootClaim !== "none") {
    throw new ChannelError("verifiedBootClaim must be none (DEC-007)");
  }
  if (manifest.channelLabel !== "dev/unlocked") {
    throw new ChannelError("channelLabel must be dev/unlocked (DEC-007)");
  }
  crossCheckArtifacts(manifest, sha256sums, files);
  return { manifest, sha256sums, files };
}

export function loadChannelFromTexts(input: {
  manifestJson: string;
  sha256sums: string;
  filesTxt: string;
}): ChannelBundle {
  return assembleChannel(
    parseManifestJson(input.manifestJson),
    parseSha256Sums(input.sha256sums),
    parseFilesTxt(input.filesTxt),
  );
}

function assertSafeName(name: string): void {
  if (!NAME_RE.test(name) || name.includes("..") || SECRET_NAME_RE.test(name)) {
    throw new ChannelError(`refusing artifact name: ${name}`);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isArtifactPhase(value: string): value is ArtifactPhase {
  return (ARTIFACT_PHASES as readonly string[]).includes(value);
}

function assertFlashOrder(order: string[]): void {
  if (order.length !== FLASH_ORDER.length) {
    throw new ChannelError("flashOrder must be firmware → avb_custom_key → os");
  }
  for (let i = 0; i < FLASH_ORDER.length; i += 1) {
    if (order[i] !== FLASH_ORDER[i]) {
      throw new ChannelError("flashOrder must be firmware → avb_custom_key → os");
    }
  }
}

function readManifest(raw: Record<string, unknown>): ChannelManifest {
  if (raw.schemaVersion !== 1) {
    throw new ChannelError("schemaVersion must be 1");
  }
  const artifacts = readArtifacts(raw.artifacts);
  const reserved = optionalStringArray(raw.reservedProducts, "reservedProducts");
  const followOn = optionalString(raw.factoryZipFollowOn);
  const manifest: ChannelManifest = {
    schemaVersion: 1,
    product: readString(raw.product, "product"),
    advertisedDevices: readStringArray(raw.advertisedDevices, "advertisedDevices"),
    channel: readString(raw.channel, "channel"),
    bootState: readString(raw.bootState, "bootState"),
    channelLabel: readString(raw.channelLabel, "channelLabel"),
    verifiedBootClaim: readString(raw.verifiedBootClaim, "verifiedBootClaim"),
    releaseId: readString(raw.releaseId, "releaseId"),
    unixEpoch: readInt(raw.unixEpoch, "unixEpoch"),
    sourceStamp: readString(raw.sourceStamp, "sourceStamp"),
    flashOrder: readStringArray(raw.flashOrder, "flashOrder"),
    factoryZip: raw.factoryZip === null ? null : readString(raw.factoryZip, "factoryZip"),
    avb: readAvb(raw.avb),
    artifacts,
    signature: readSignature(raw.signature),
  };
  if (reserved !== undefined) {
    manifest.reservedProducts = reserved;
  }
  if (followOn !== undefined) {
    manifest.factoryZipFollowOn = followOn;
  }
  return manifest;
}

function readArtifacts(value: unknown): ChannelArtifact[] {
  if (!Array.isArray(value) || value.length < 1) {
    throw new ChannelError("manifest.artifacts is required");
  }
  return value.map((row, idx) => {
    if (!isRecord(row)) {
      throw new ChannelError(`artifact[${idx}] must be an object`);
    }
    return readArtifactRow(row);
  });
}

function readArtifactRow(row: Record<string, unknown>): ChannelArtifact {
  const name = readString(row.name, "artifact.name");
  const phase = readString(row.phase, "artifact.phase");
  assertSafeName(name);
  if (!isArtifactPhase(phase)) {
    throw new ChannelError(`invalid artifact phase: ${phase}`);
  }
  const sha256 = normalizeSha256(readString(row.sha256, "artifact.sha256"));
  const size = readInt(row.size, "artifact.size");
  if (size < 0) {
    throw new ChannelError(`invalid size for ${name}`);
  }
  return { name, phase, sha256, size };
}

function readAvb(value: unknown): ChannelManifest["avb"] {
  if (!isRecord(value)) {
    throw new ChannelError("avb must be an object");
  }
  if (value.publicKeyFile !== "avb_pkmd.bin") {
    throw new ChannelError("avb.publicKeyFile must be avb_pkmd.bin");
  }
  return {
    publicKeyFile: "avb_pkmd.bin",
    sha256: normalizeSha256(readString(value.sha256, "avb.sha256")),
    size: readInt(value.size, "avb.size"),
  };
}

function readSignature(value: unknown): ChannelManifest["signature"] {
  if (!isRecord(value)) {
    throw new ChannelError("signature must be an object");
  }
  const mode = readString(value.mode, "signature.mode");
  if (mode !== "hash-only" && mode !== "openssh-signify") {
    throw new ChannelError("signature.mode is invalid");
  }
  if (typeof value.required !== "boolean") {
    throw new ChannelError("signature.required must be boolean");
  }
  const note = optionalString(value.note);
  const file = value.file === null ? null : optionalString(value.file) ?? null;
  const allowed = value.allowedSigners === null
    ? null
    : optionalString(value.allowedSigners) ?? null;
  return {
    required: value.required,
    mode,
    file,
    allowedSigners: allowed,
    ...(note !== undefined ? { note } : {}),
  };
}

function readString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new ChannelError(`${field} must be a non-empty string`);
  }
  return value;
}

function optionalString(value: unknown): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new ChannelError("optional string field has the wrong type");
  }
  return value;
}

function readStringArray(value: unknown, field: string): string[] {
  if (!Array.isArray(value)) {
    throw new ChannelError(`${field} must be a string array`);
  }
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== "string") {
      throw new ChannelError(`${field} must be a string array`);
    }
    out.push(item);
  }
  return out;
}

function optionalStringArray(value: unknown, field: string): string[] | undefined {
  if (value === undefined) {
    return undefined;
  }
  return readStringArray(value, field);
}

function readInt(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new ChannelError(`${field} must be an integer`);
  }
  return value;
}

function crossCheckArtifacts(
  manifest: ChannelManifest,
  sha256sums: ReadonlyMap<string, string>,
  files: FileListEntry[],
): void {
  const fromManifest = new Map(manifest.artifacts.map((a) => [a.name, a]));
  if (fromManifest.size !== manifest.artifacts.length) {
    throw new ChannelError("manifest.artifacts has duplicate names");
  }
  assertSameNames(fromManifest, sha256sums, files);
  for (const file of files) {
    const row = fromManifest.get(file.name);
    const digest = sha256sums.get(file.name);
    if (row === undefined || digest === undefined) {
      throw new ChannelError(`missing cross-check row for ${file.name}`);
    }
    if (row.phase !== file.phase || row.size !== file.size) {
      throw new ChannelError(`files.txt disagrees with manifest for ${file.name}`);
    }
    if (digest !== normalizeSha256(row.sha256)) {
      throw new ChannelError(`SHA256SUMS disagrees with manifest for ${file.name}`);
    }
  }
  const avbDigest = sha256sums.get("avb_pkmd.bin");
  if (avbDigest !== normalizeSha256(manifest.avb.sha256)) {
    throw new ChannelError("avb.sha256 does not match SHA256SUMS");
  }
}

function assertSameNames(
  fromManifest: ReadonlyMap<string, ChannelArtifact>,
  sha256sums: ReadonlyMap<string, string>,
  files: FileListEntry[],
): void {
  const fileNames = new Set(files.map((f) => f.name));
  const sumNames = new Set(sha256sums.keys());
  const manNames = new Set(fromManifest.keys());
  for (const set of [fileNames, sumNames, manNames]) {
    if (set.size !== fileNames.size || ![...set].every((n) => fileNames.has(n))) {
      throw new ChannelError(
        "manifest.json, SHA256SUMS, and files.txt name sets must match",
      );
    }
  }
}
