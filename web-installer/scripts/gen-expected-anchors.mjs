#!/usr/bin/env node
/**
 * gen-expected-anchors.mjs — DELIBERATE (human-run) regeneration of the
 * out-of-band AVB trust-anchor pins (T-WEBINSTALL-TRUST-ANCHOR-VERIFICATION).
 *
 * This script exists to make an anchor change a REVIEWABLE DIFF, not to keep
 * the pins in sync automatically. It is the ONLY way the pins are written, and
 * it is NOT wired into any automatic step (no `make`, no gate, no CI) — running
 * it is an explicit act whose output must be reviewed like any other code:
 * a digest changing here means the trust anchor for a shipped channel moved.
 *
 *   node scripts/gen-expected-anchors.mjs           # print the pin document
 *   node scripts/gen-expected-anchors.mjs --write   # write docs/expected-anchors.json
 *   node scripts/gen-expected-anchors.mjs --check   # exit 1 if the checked-in pin would change
 *
 * It reads, per packed channel: the shipped `channels/<product>/avb_pkmd.bin`
 * (what this tree would hand to a flasher) and the same file inside the
 * release stamp named by the channel's `manifest.sourceStamp` (where the
 * channel was packed from). Both digests are pinned; the gate checks the
 * shipped one, the channel-complete suite checks the two agree.
 *
 * HONESTY: this records hashes of a PUBLIC key and its source copy. It never
 * touches, reads, generates, or commits private key material.
 */

import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { INSTALLER_ROOT, REPO_ROOT } from "./gen-flash-matrix.mjs";
import { ANCHOR_FILE, ANCHORS_SCHEMA } from "./trust-anchor.mjs";

const CHANNELS_ROOT = join(INSTALLER_ROOT, "channels");
const RELEASES = join(REPO_ROOT, "releases", "desktop-flash");
const OUT_PATH = join(INSTALLER_ROOT, "docs", "expected-anchors.json");

const $comment =
  "Out-of-band AVB trust-anchor pins. DEV-CHANNEL: hash-anchored, not signed. Regenerate deliberately (node scripts/gen-expected-anchors.mjs --write) and review the diff; never automatically from the tree you are verifying.";

function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function packedProducts() {
  return readdirSync(CHANNELS_ROOT)
    .filter((name) => existsSync(join(CHANNELS_ROOT, name, "manifest.json")))
    .sort();
}

function buildDocument() {
  const anchors = {};
  for (const product of packedProducts()) {
    const dir = join(CHANNELS_ROOT, product);
    const shipped = join(dir, ANCHOR_FILE);
    if (!existsSync(shipped)) {
      throw new Error(`${product}: no ${ANCHOR_FILE} in the packed channel`);
    }
    const manifest = JSON.parse(readFileSync(join(dir, "manifest.json"), "utf8"));
    const stamp = String(manifest.sourceStamp);
    const sourcePath = join(RELEASES, stamp, ANCHOR_FILE);
    if (!existsSync(sourcePath)) {
      throw new Error(`${product}: ${ANCHOR_FILE} missing from source stamp ${stamp}`);
    }
    const bytes = readFileSync(shipped);
    anchors[product] = {
      file: ANCHOR_FILE,
      sha256: createHash("sha256").update(bytes).digest("hex"),
      size: bytes.length,
      sourceStamp: stamp,
      sourceStampSha256: sha256File(sourcePath),
    };
  }
  const channels = packedProducts().map((product) => {
    const manifest = JSON.parse(readFileSync(join(CHANNELS_ROOT, product, "manifest.json"), "utf8"));
    return manifest.channel;
  });
  const uniqueChannels = [...new Set(channels)];
  if (uniqueChannels.length !== 1) {
    throw new Error(`packed channels disagree on the channel name: ${uniqueChannels.join(", ")}`);
  }
  return {
    $comment,
    schemaVersion: ANCHORS_SCHEMA,
    channel: uniqueChannels[0],
    provenance: {
      pinnedBy:
        "checked-in, review-gated constant. A change to these digests is a reviewable diff. Not a signed root; not GrapheneOS-equivalent (whose public keys live in signed release metadata).",
      generatedBy: "scripts/gen-expected-anchors.mjs (deliberate, human-run; never automatic)",
      whatItProves:
        "the shipped avb_pkmd.bin is byte-identical to a digest a human reviewed; it does not prove the images were signed with this key",
      sourceStampSha256:
        "digest of the same file inside the channel's manifest.sourceStamp release stamp — corroboration a reviewer can re-derive",
    },
    anchors,
  };
}

function strip(text) {
  // The document is fully derived; there is nothing to strip today. Kept as a
  // seam so a future non-derived field does not make --check flaky.
  return text;
}

function main(argv) {
  const write = argv.includes("--write");
  const check = argv.includes("--check");
  const document = buildDocument();
  const json = `${JSON.stringify(document, null, 2)}\n`;
  if (write) {
    writeFileSync(OUT_PATH, json);
    process.stdout.write(`[gen-expected-anchors] wrote ${OUT_PATH}\n`);
    return 0;
  }
  if (check) {
    const current = existsSync(OUT_PATH) ? readFileSync(OUT_PATH, "utf8") : "";
    if (strip(current) !== strip(json)) {
      process.stderr.write(
        "[gen-expected-anchors] DRIFT: docs/expected-anchors.json does not match the tree\n",
      );
      return 1;
    }
    process.stdout.write("[gen-expected-anchors] pins are up to date\n");
    return 0;
  }
  process.stdout.write(json);
  return 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`[gen-expected-anchors] ERROR: ${err instanceof Error ? err.message : String(err)}\n`);
    process.exitCode = 2;
  }
}
