#!/usr/bin/env node
/**
 * gen-packed-channels.mjs — GENERATED packed-channel inventory for the browser
 * picker (F-WEBINSTALL-FLASHALL-PICKER-TRUTH acceptance (a)).
 *
 * The picker must offer EXACTLY the products that have a packed channel on
 * disk, and must refuse a product with no channel. The browser ships fully
 * offline (CSP `connect-src 'none'`, D-006), so it cannot read `channels/` at
 * runtime. This script derives the packed set from the tree and emits a small
 * checked-in module the picker imports — the same generated-not-hand-written
 * pattern as `scripts/gen-readiness-manifest.sh` → `lib/ui/readiness-manifest.ts`.
 *
 *   node scripts/gen-packed-channels.mjs            # write the module
 *   node scripts/gen-packed-channels.mjs --check    # exit 1 if it would change
 *   node scripts/gen-packed-channels.mjs --stdout   # print, do not write
 *
 * Sources (ALL READ-ONLY — this script never writes outside its one output):
 *   - the advertised allowlist: src/types.ts ALLOWED_PRODUCTS
 *   - the packed channels:      channels/<product>/{manifest.json,files.txt,SHA256SUMS}
 *
 * A product is PACKED iff all three files exist AND manifest.json parses and
 * declares `product === <product>` and a non-empty `sourceStamp`. A channel
 * directory without those is NOT packed (fail closed) — a half-built channel is
 * never advertised (T-WEBINSTALL-FLASHALL-CHANNEL-COMPLETE (d): no stubs).
 *
 * HONESTY: BOOT_VERIFIED=false. This records what is PACKED; it proves no image
 * boots and asserts no live-flash capability. It never invents a channel.
 */

import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
export const INSTALLER_ROOT = join(HERE, "..");
const CHANNELS_ROOT = join(INSTALLER_ROOT, "channels");
const TYPES_TS = join(INSTALLER_ROOT, "src", "types.ts");
const OUT = join(INSTALLER_ROOT, "lib", "ui", "packed-channels.ts");

/** Parse ALLOWED_PRODUCTS out of src/types.ts without executing TypeScript. */
export function readAllowedProducts() {
  const text = readFileSync(TYPES_TS, "utf8");
  const match = text.match(/export const ALLOWED_PRODUCTS = \[(.*?)\] as const;/s);
  if (match === null) {
    throw new Error("could not parse ALLOWED_PRODUCTS from src/types.ts");
  }
  return [...match[1].matchAll(/"([a-z0-9]+)"/g)].map((m) => m[1]);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

/**
 * The packed-channel fact for one product, or null when it is not genuinely
 * packed. Every required input must exist and be coherent; a missing or
 * malformed input is "not packed" (fail closed), never a guess.
 */
export function packedChannelFor(product) {
  const dir = join(CHANNELS_ROOT, product);
  const manifestPath = join(dir, "manifest.json");
  const filesTxtPath = join(dir, "files.txt");
  const sumsPath = join(dir, "SHA256SUMS");
  if (!existsSync(manifestPath) || !existsSync(filesTxtPath) || !existsSync(sumsPath)) {
    return null;
  }
  let manifest;
  try {
    manifest = readJson(manifestPath);
  } catch {
    return null;
  }
  if (manifest?.product !== product) {
    return null;
  }
  const sourceStamp = manifest?.sourceStamp;
  if (typeof sourceStamp !== "string" || sourceStamp.trim() === "") {
    return null;
  }
  // Artifact count is the number of staged image rows the channel declares;
  // files.txt is the packer's own file list, so count its non-empty lines.
  let artifactCount = 0;
  for (const line of readFileSync(filesTxtPath, "utf8").split("\n")) {
    if (line.trim() !== "") {
      artifactCount += 1;
    }
  }
  return {
    product,
    packed: true,
    sourceStamp,
    channelLabel: typeof manifest?.channelLabel === "string" ? manifest.channelLabel : "-",
    artifactCount,
  };
}

/** Every allowlisted product, with its packed state. Derived, never listed twice. */
export function buildPackedChannels() {
  return readAllowedProducts().map((product) => ({
    product,
    ...(packedChannelFor(product) ?? {
      packed: false,
      sourceStamp: null,
      channelLabel: null,
      artifactCount: 0,
    }),
  }));
}

function renderModule(entries) {
  const rows = entries
    .map((entry) =>
      [
        "  {",
        `    product: ${JSON.stringify(entry.product)},`,
        `    packed: ${String(entry.packed)},`,
        `    sourceStamp: ${entry.sourceStamp === null ? "null" : JSON.stringify(entry.sourceStamp)},`,
        `    channelLabel: ${entry.channelLabel === null ? "null" : JSON.stringify(entry.channelLabel)},`,
        `    artifactCount: ${String(entry.artifactCount)},`,
        "  },",
      ].join("\n"),
    )
    .join("\n");
  return [
    "/**",
    " * GENERATED FILE — DO NOT EDIT BY HAND.",
    " *",
    " * Regenerate with: node scripts/gen-packed-channels.mjs",
    " * Drift check:     node scripts/gen-packed-channels.mjs --check",
    " *",
    " * Source of truth: the packed channel tree `channels/<product>/` plus the",
    " * advertised allowlist `src/types.ts` ALLOWED_PRODUCTS. This module exists so",
    " * the OFFLINE browser picker (CSP connect-src 'none', D-006) can offer exactly",
    " * the products that have a packed channel, without reading channels/ at runtime.",
    " *",
    " * HONESTY: BOOT_VERIFIED=false. PACKED means a channel exists on disk; it does",
    " * NOT mean the image boots and it is NOT a live-flash claim. The picker gate",
    " * fails closed: a product absent from this list, or present with packed:false,",
    " * is not selectable.",
    " */",
    "",
    "export interface PackedChannelEntry {",
    "  readonly product: string;",
    "  readonly packed: boolean;",
    "  readonly sourceStamp: string | null;",
    "  readonly channelLabel: string | null;",
    "  readonly artifactCount: number;",
    "}",
    "",
    "export const PACKED_CHANNELS: readonly PackedChannelEntry[] = [",
    rows,
    "];",
    "",
    "/** The products with a packed channel on disk, derived from the list above. */",
    "export const PACKED_PRODUCTS: readonly string[] = PACKED_CHANNELS.filter((c) => c.packed).map(",
    "  (c) => c.product,",
    ");",
    "",
    "/** The packed-channel row for a product, or undefined when it is not advertised. */",
    "export function packedChannel(product: string): PackedChannelEntry | undefined {",
    "  return PACKED_CHANNELS.find((c) => c.product === product);",
    "}",
    "",
    "/** Whether a product has a packed channel. Absence is NOT packed (fail closed). */",
    "export function hasPackedChannel(product: string): boolean {",
    "  return packedChannel(product)?.packed === true;",
    "}",
    "",
  ].join("\n");
}

function main(argv) {
  const entries = buildPackedChannels();
  const rendered = renderModule(entries);
  const check = argv.includes("--check");
  const stdout = argv.includes("--stdout");
  if (stdout) {
    process.stdout.write(rendered);
    return 0;
  }
  if (check) {
    const current = existsSync(OUT) ? readFileSync(OUT, "utf8") : "";
    if (current === rendered) {
      const packed = entries.filter((e) => e.packed).map((e) => e.product);
      process.stdout.write(`[gen-packed-channels] lib/ui/packed-channels.ts is up to date (packed=${packed.join(",")})\n`);
      return 0;
    }
    process.stderr.write("[gen-packed-channels] DRIFT: lib/ui/packed-channels.ts does not match the tree\n");
    return 1;
  }
  if (readdirSync(CHANNELS_ROOT, { withFileTypes: true }).length === 0) {
    process.stderr.write("[gen-packed-channels] channels/ is empty — refusing to emit an all-unpacked manifest\n");
    return 1;
  }
  writeFileSync(OUT, rendered);
  const packed = entries.filter((e) => e.packed).map((e) => e.product);
  process.stdout.write(`[gen-packed-channels] wrote ${OUT} (packed=${packed.join(",")})\n`);
  return 0;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
