#!/usr/bin/env node
/**
 * gen-flash-matrix.mjs — GENERATED device × channel × flash-phase matrix.
 *
 * T-WEBINSTALL-FLASHALL-INVENTORY. This script machine-derives the matrix from
 * the four sources that actually exist on disk:
 *
 *   1. the advertised allowlist (src/types.ts ALLOWED_PRODUCTS)
 *   2. the shipped product facts (status.json routes.targets/experimentalTargets)
 *   3. the packed channels (web-installer/channels/<product>/manifest.json +
 *      files.txt + SHA256SUMS)
 *   4. the desktop-flash stamps (releases/desktop-flash/<product>-* and the
 *      <product>-latest pointers) that a packer would read
 *
 * Nothing here is hand-written. Run it and it re-derives the whole artifact:
 *
 *   node scripts/gen-flash-matrix.mjs            # write the artifact
 *   node scripts/gen-flash-matrix.mjs --check    # exit 1 if it would change
 *   node scripts/gen-flash-matrix.mjs --stdout   # print, do not write
 *
 * The emitted artifact is a checked-in JSON document at
 * `docs/flash-matrix.json` with a sibling Markdown rendering.
 *
 * HONESTY: BOOT_VERIFIED=false. This matrix records what is PACKED and what is
 * ADVERTISED; it does not claim any image boots, and it never invents a channel.
 */

import { readFileSync, readdirSync, existsSync, lstatSync, realpathSync, writeFileSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
export const INSTALLER_ROOT = join(HERE, "..");
export const REPO_ROOT = join(INSTALLER_ROOT, "..", "..", "..");

// T-WEBINSTALL-READINESS-RULE-SINGLE-SOURCE: the freshness predicate lives in
// exactly one place (scripts/channel-freshness.mjs). The gate imports it, and so
// does this generator — an inlined copy here previously let the rule the gate
// consumes drift from the rule the gate applies.
import { checkChannelFreshness } from "./channel-freshness.mjs";

/** Phase vocabulary, mirroring src/types.ts FLASH_ORDER + ARTIFACT_PHASES. */
export const FLASH_ORDER = ["firmware", "avb_custom_key", "os"];
export const ARTIFACT_PHASES = ["firmware", "avb", "os"];

/** Config step 0–9 (lib/install-state/steps.ts). The matrix maps artifacts to
 *  the flash step (§6 "Flash") whose phase they belong to; every artifact must
 *  land in exactly one phase so no image is unmapped. */
export const FLASH_STEP = 6;
export const STEP_TITLES = [
  "Before you start",
  "Get release over Tor",
  "Verify release",
  "Your key",
  "Sign the release",
  "Connect device",
  "Flash",
  "Lock",
  "First boot & verify",
  "Keep the key",
];

const STAMP_RE = /^([a-z0-9]+)-([0-9]{8})-([0-9]{6})$/;

export function phaseForArtifact(name) {
  if (name === "bootloader.img" || name === "radio.img") return "firmware";
  if (name === "avb_pkmd.bin") return "avb";
  if (name.endsWith(".img")) return "os";
  return null;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function isSymlink(path) {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
}

/** Parse ALLOWED_PRODUCTS out of src/types.ts without executing TypeScript. */
export function readAllowedProducts() {
  const text = readFileSync(join(INSTALLER_ROOT, "src", "types.ts"), "utf8");
  const match = /export const ALLOWED_PRODUCTS = \[([^\]]*)\]/.exec(text);
  if (match === null) throw new Error("could not locate ALLOWED_PRODUCTS in src/types.ts");
  const line = text.slice(0, match.index).split("\n").length;
  const products = [...match[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  return { products, sourceLine: line };
}

/** Parse the advertised set out of status.json (product facts). */
export function readStatusTargets() {
  const path = join(INSTALLER_ROOT, "status.json");
  const status = readJson(path);
  return {
    targets: status.targets ?? [],
    experimentalTargets: status.experimentalTargets ?? [],
    liveFlashClaimed: status.flashCapability?.liveFlashClaimed ?? null,
    path: "status.json",
  };
}

/** Walk the stamps tree, distinguishing real stamps, pointers, and quarantine. */
export function readStamps(releasesDir) {
  const stamps = [];
  const pointers = new Map();
  if (!existsSync(releasesDir)) return { stamps, pointers };
  for (const entry of readdirSync(releasesDir)) {
    const full = join(releasesDir, entry);
    if (isSymlink(full)) {
      // <product>-latest or latest.quarantined-* — a pointer, not a stamp dir.
      let target = null;
      try {
        target = basename(realpathSync(full));
      } catch {
        target = null;
      }
      const ptr = /^([a-z0-9]+)-latest$/.exec(entry);
      if (ptr !== null) pointers.set(ptr[1], { name: entry, target });
      continue;
    }
    const m = STAMP_RE.exec(entry);
    if (m === null) continue;
    if (!lstatSync(full).isDirectory()) continue;
    stamps.push({ product: m[1], stamp: entry, dir: full });
  }
  stamps.sort((a, b) => a.stamp.localeCompare(b.stamp));
  return { stamps, pointers };
}

/** Read a packed channel dir, or null when the product is not packed. */
export function readPackedChannel(product) {
  const dir = join(INSTALLER_ROOT, "channels", product);
  if (!existsSync(dir)) return null;
  const manifestPath = join(dir, "manifest.json");
  const sumsPath = join(dir, "SHA256SUMS");
  const filesPath = join(dir, "files.txt");
  const missing = [manifestPath, sumsPath, filesPath].filter((p) => !existsSync(p));
  if (missing.length > 0) {
    return {
      dir: `channels/${product}`,
      product,
      incomplete: true,
      missing: missing.map((p) => basename(p)),
    };
  }
  const manifest = readJson(manifestPath);
  const sums = new Map();
  for (const raw of readFileSync(sumsPath, "utf8").split(/\r?\n/)) {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) continue;
    const match = /^([a-fA-F0-9]{64}) [ *](.+)$/.exec(line);
    if (match === null) throw new Error(`invalid SHA256SUMS line in ${sumsPath}: ${line}`);
    sums.set(match[2].trim(), match[1].toLowerCase());
  }
  const files = [];
  for (const raw of readFileSync(filesPath, "utf8").split(/\r?\n/)) {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) continue;
    const match = /^(\S+)\s+(firmware|avb|os)\s+(\d+)$/.exec(line);
    if (match === null) throw new Error(`invalid files.txt line in ${filesPath}: ${line}`);
    files.push({ name: match[1], phase: match[2], size: Number(match[3]) });
  }
  const pointerFile = [`${product}-dev`, "pointer"].find((n) => existsSync(join(dir, n)));
  const pointer = pointerFile === undefined ? null : readFileSync(join(dir, pointerFile), "utf8").trim();
  return {
    dir: `channels/${product}`,
    product,
    incomplete: false,
    manifest,
    sha256sums: sums,
    files,
    pointerFile,
    pointer,
    dirIsSymlinked: existsSync(join(dir, "bootloader.img")) && isSymlink(join(dir, "bootloader.img")),
  };
}

/**
 * The advertised-vs-packed divergence ledger. Each row names the exact source
 * file + line that advertises (or fails to advertise) a product.
 */
export function advertisedVsPacked({ allowed, status, channels, stamps, pointers }) {
  const rows = [];
  const stampNames = new Set(stamps.map((s) => s.stamp));
  const products = new Set([
    ...allowed.products,
    ...status.targets,
    ...status.experimentalTargets,
  ]);
  for (const product of [...products].sort()) {
    const inAllowlist = allowed.products.includes(product);
    const inTargets = status.targets.includes(product);
    const inExperimental = status.experimentalTargets.includes(product);
    const packed = channels.has(product);
    const latest = pointers.get(product) ?? null;
    const latestExists = latest !== null && latest.target !== null && stampNames.has(latest.target);
    // Prefer an explicit current stamp for the freshness comparison; the
    // pointer is the advertised one. Both are recorded.
    const currentStamp = latestExists ? latest.target : null;
    let verdict;
    let reason;
    if (packed && currentStamp !== null) {
      const packedStamp = channels.get(product).manifest.sourceStamp;
      verdict = packedStamp === currentStamp ? "PACKED-CURRENT" : "PACKED-STALE";
      reason =
        packedStamp === currentStamp
          ? "packed channel matches the advertised current stamp"
          : `packed channel sourceStamp ${packedStamp} != advertised current stamp ${currentStamp}`;
    } else if (packed) {
      verdict = "PACKED-NO-CURRENT-POINTER";
      reason = "channel packed but the product has no resolvable <product>-latest pointer";
    } else {
      verdict = "ADVERTISED-NOT-PACKED";
      reason = "advertised but no packed channel on disk";
    }
    const advertisedBy = [];
    if (inAllowlist) advertisedBy.push(`src/types.ts:${allowed.sourceLine} (ALLOWED_PRODUCTS)`);
    if (inTargets) advertisedBy.push(`status.json (routes.targets)`);
    if (inExperimental) advertisedBy.push(`status.json (experimentalTargets)`);
    rows.push({
      product,
      advertisedBy,
      inAllowlist,
      inTargets,
      inExperimental,
      packed,
      packedDir: packed ? `channels/${product}` : null,
      packedSourceStamp: packed ? channels.get(product).manifest.sourceStamp : null,
      advertisedCurrentStamp: currentStamp,
      latestPointer: latest === null ? null : latest.name,
      verdict,
      reason,
      // A device absent from the product facts entirely is called out by name.
      absentFromProductFacts: !inTargets && !inExperimental,
    });
  }
  return rows;
}

/** Build the whole matrix document. Pure with respect to the filesystem. */
export function buildMatrix({ generatedAt, generationCommand, revision }) {
  const allowed = readAllowedProducts();
  const status = readStatusTargets();
  const releasesDir = join(REPO_ROOT, "releases", "desktop-flash");
  const { stamps, pointers } = readStamps(releasesDir);

  const products = new Set([...allowed.products, ...status.targets, ...status.experimentalTargets]);
  const channels = new Map();
  for (const product of products) {
    const packed = readPackedChannel(product);
    if (packed !== null) channels.set(product, packed);
  }

  const devices = [];
  for (const product of [...products].sort()) {
    const packed = channels.get(product) ?? null;
    const productStamps = stamps.filter((s) => s.product === product);
    const latest = pointers.get(product) ?? null;
    const latestTarget = latest === null ? null : latest.target;
    const latestExists = latestTarget !== null && productStamps.some((s) => s.stamp === latestTarget);

    // The channel rows: one per packed channel (never invented).
    const channelRows = [];
    if (packed !== null && !packed.incomplete) {
      const manifest = packed.manifest;
      const artifacts = packed.files.map((f) => {
        const declaredPhase = phaseForArtifact(f.name);
        const inManifest = manifest.artifacts.find((a) => a.name === f.name);
        return {
          name: f.name,
          filesTxtPhase: f.phase,
          declaredPhase,
          phaseMatches: declaredPhase === f.phase,
          flashStep: FLASH_STEP,
          flashOrderPhase:
            f.phase === "avb" ? "avb_custom_key" : f.phase,
          size: f.size,
          sha256: packed.sha256sums.get(f.name) ?? null,
          inManifest: inManifest !== undefined,
        };
      });
      // Any manifest artifact missed by files.txt (or vice versa) is a defect.
      const filesNames = new Set(packed.files.map((f) => f.name));
      const unmapped = manifest.artifacts.map((a) => a.name).filter((n) => !filesNames.has(n));
      const phaseCounts = { firmware: 0, avb: 0, os: 0 };
      for (const a of artifacts) phaseCounts[a.filesTxtPhase] += 1;
      channelRows.push({
        channel: manifest.channel,
        channelLabel: manifest.channelLabel,
        bootState: manifest.bootState,
        verifiedBootClaim: manifest.verifiedBootClaim,
        releaseId: manifest.releaseId,
        unixEpoch: manifest.unixEpoch,
        sourceStamp: manifest.sourceStamp,
        sourceStampIsCurrent: checkChannelFreshness(product, {
          sourceStamp: manifest.sourceStamp,
          releaseId: manifest.releaseId,
          unixEpoch: manifest.unixEpoch,
          currentStamp: latestExists ? latestTarget : null,
          stampsOnDisk: latestExists ? [manifest.sourceStamp] : [],
        }).fresh,
        advertisedCurrentStamp: latestExists ? latestTarget : null,
        artifactCount: artifacts.length,
        phaseCounts,
        unmappedArtifacts: unmapped,
        artifacts,
      });
    }

    devices.push({
      product,
      advertised: {
        inAllowlist: allowed.products.includes(product),
        inTargets: status.targets.includes(product),
        inExperimental: status.experimentalTargets.includes(product),
        absentFromProductFacts:
          !status.targets.includes(product) && !status.experimentalTargets.includes(product),
      },
      packed: packed !== null && !packed.incomplete,
      packedDir: packed === null ? null : packed.dir,
      packedIncomplete: packed !== null && packed.incomplete === true,
      currentStamp: latestExists ? latestTarget : null,
      stampsOnDisk: productStamps.map((s) => s.stamp),
      channels: channelRows,
    });
  }

  const divergence = advertisedVsPacked({ allowed, status, channels, stamps, pointers });

  const packedDevices = devices.filter((d) => d.packed).map((d) => d.product);
  const advertisedOnly = divergence
    .filter((r) => r.verdict === "ADVERTISED-NOT-PACKED")
    .map((r) => r.product);
  const staleChannels = divergence
    .filter((r) => r.verdict === "PACKED-STALE")
    .map((r) => r.product);

  return {
    $comment:
      "GENERATED by scripts/gen-flash-matrix.mjs. DO NOT EDIT BY HAND. Regenerate with the generationCommand below.",
    schemaVersion: 1,
    generatedAt,
    generationCommand,
    revision,
    honesty: {
      bootVerified: false,
      liveFlashClaimed: status.liveFlashClaimed,
      note:
        "Records what is packed and advertised. Proves no image boots. Never invents a channel.",
    },
    counts: {
      allowlist: allowed.products.length,
      statusTargets: status.targets.length,
      statusExperimentalTargets: status.experimentalTargets.length,
      packedChannels: packedDevices.length,
      advertisedNotPacked: advertisedOnly.length,
    },
    sources: {
      allowlist: { path: "src/types.ts", line: allowed.sourceLine, products: allowed.products },
      productFacts: {
        path: status.path,
        targets: status.targets,
        experimentalTargets: status.experimentalTargets,
      },
      channelsRoot: "channels/",
      stampsRoot: "releases/desktop-flash/",
    },
    phases: ARTIFACT_PHASES,
    flashOrder: FLASH_ORDER,
    flashStep: { step: FLASH_STEP, title: STEP_TITLES[FLASH_STEP] },
    devices,
    divergence,
    summary: {
      packedDevices,
      advertisedNotPacked: advertisedOnly,
      staleChannels,
    },
  };
}

/** Render the matrix as Markdown for human review. */
export function renderMarkdown(matrix) {
  const out = [];
  out.push("# Flash matrix — device × channel × flash phase (GENERATED)");
  out.push("");
  out.push(`> DO NOT EDIT BY HAND. Regenerate: \`${matrix.generationCommand}\``);
  out.push(`> Generated at \`${matrix.generatedAt}\`; derived from revision \`${matrix.revision}\`.`);
  out.push(
    `> HONESTY: \`BOOT_VERIFIED=false\`, \`LIVE_FLASH_CLAIMED=${String(
      matrix.honesty.liveFlashClaimed,
    )}\`. This records what is packed; it proves no image boots.`,
  );
  out.push("");
  out.push("## Counts");
  out.push("");
  out.push("| Metric | Value |");
  out.push("|--------|-------|");
  out.push(`| ALLOWED_PRODUCTS | ${matrix.counts.allowlist} |`);
  out.push(`| status.json routes.targets | ${matrix.counts.statusTargets} |`);
  out.push(`| status.json experimentalTargets | ${matrix.counts.statusExperimentalTargets} |`);
  out.push(`| packed channels on disk | ${matrix.counts.packedChannels} |`);
  out.push(`| advertised-but-not-packed | ${matrix.counts.advertisedNotPacked} |`);
  out.push("");
  out.push("## Advertised vs packed (divergence ledger)");
  out.push("");
  out.push("| Product | Verdict | Packed sourceStamp | Advertised current stamp | Advertised by | Reason |");
  out.push("|---------|---------|--------------------|--------------------------|---------------|--------|");
  for (const row of matrix.divergence) {
    out.push(
      `| ${row.product} | ${row.verdict} | ${row.packedSourceStamp ?? "—"} | ${
        row.advertisedCurrentStamp ?? "—"
      } | ${row.advertisedBy.join("; ") || "—"} | ${row.reason} |`,
    );
  }
  out.push("");
  out.push("## Device × channel × phase");
  out.push("");
  out.push(
    `Every artifact is mapped to flash step \`§${matrix.flashStep.step} ${matrix.flashStep.title}\` via its phase (${matrix.phases.join(
      " / ",
    )}); flash order ${matrix.flashOrder.join(" → ")}.`,
  );
  out.push("");
  for (const device of matrix.devices) {
    const advertised = [
      device.advertised.inAllowlist ? "allowlist" : null,
      device.advertised.inTargets ? "targets" : null,
      device.advertised.inExperimental ? "experimental" : null,
    ]
      .filter(Boolean)
      .join(", ");
    out.push(
      `### ${device.product} — ${device.packed ? "PACKED" : "NOT PACKED"}${
        device.advertised.absentFromProductFacts ? " (absent from product facts)" : ""
      }`,
    );
    out.push("");
    out.push(`- advertised by: ${advertised || "—"}`);
    out.push(`- current stamp on disk: ${device.currentStamp ?? "—"}`);
    if (device.channels.length === 0) {
      out.push("- no packed channel");
      out.push("");
      continue;
    }
    for (const channel of device.channels) {
      out.push(
        `- channel \`${channel.channel}/${channel.bootState}\` sourceStamp \`${channel.sourceStamp}\` (${
          channel.sourceStampIsCurrent ? "CURRENT" : "STALE"
        }); artifacts ${channel.artifactCount} (${channel.phaseCounts.firmware} firmware / ${
          channel.phaseCounts.avb
        } avb / ${channel.phaseCounts.os} os)`,
      );
      out.push("");
      out.push("| Artifact | files.txt phase | declared phase | flash order | size | mapped |");
      out.push("|----------|-----------------|----------------|-------------|------|--------|");
      for (const a of channel.artifacts) {
        out.push(
          `| ${a.name} | ${a.filesTxtPhase} | ${a.declaredPhase ?? "UNMAPPED"} | ${a.flashOrderPhase} | ${
            a.size
          } | ${a.phaseMatches && a.inManifest ? "yes" : "NO"} |`,
        );
      }
      out.push("");
    }
  }
  return `${out.join("\n")}\n`;
}

/* ------------------------------------------------------------------ CLI --- */

async function gitRevision() {
  try {
    const { execFile } = await import("node:child_process");
    const { promisify } = await import("node:util");
    const run = promisify(execFile);
    const { stdout } = await run("git", [
      "-C",
      join(REPO_ROOT, "vendor", "guardtalk"),
      "rev-parse",
      "HEAD",
    ]);
    return stdout.trim();
  } catch {
    return "unknown";
  }
}

async function main(argv) {
  const check = argv.includes("--check");
  const stdout = argv.includes("--stdout");
  const generatedAt = process.env.GT_MATRIX_TIMESTAMP ?? new Date().toISOString();
  const matrix = buildMatrix({
    generatedAt,
    generationCommand: "node scripts/gen-flash-matrix.mjs",
    revision: await gitRevision(),
  });
  const json = `${JSON.stringify(matrix, null, 2)}\n`;
  const md = renderMarkdown(matrix);
  if (stdout) {
    process.stdout.write(json);
    return 0;
  }
  const jsonPath = join(INSTALLER_ROOT, "docs", "flash-matrix.json");
  const mdPath = join(INSTALLER_ROOT, "docs", "flash-matrix.md");
  if (check) {
    const currentJson = existsSync(jsonPath) ? readFileSync(jsonPath, "utf8") : "";
    const currentMd = existsSync(mdPath) ? readFileSync(mdPath, "utf8") : "";
    // The timestamp + revision are non-derived bytes; compare the derived data.
    const strip = (text) =>
      text
        .replace(/"generatedAt": "[^"]*"/, '"generatedAt": "-"')
        .replace(/"revision": "[^"]*"/, '"revision": "-"')
        .replace(/Generated at `[^`]*`; derived from revision `[^`]*`/, "Generated at `-`");
    if (strip(currentJson) !== strip(json) || strip(currentMd) !== strip(md)) {
      process.stderr.write(
        "[gen-flash-matrix] DRIFT: docs/flash-matrix.{json,md} do not match the tree\n",
      );
      return 1;
    }
    process.stdout.write("[gen-flash-matrix] matrix is up to date\n");
    return 0;
  }
  writeFileSync(jsonPath, json);
  writeFileSync(mdPath, md);
  process.stdout.write(
    `[gen-flash-matrix] wrote docs/flash-matrix.json + docs/flash-matrix.md ` +
      `(packed=${matrix.counts.packedChannels} advertised-not-packed=${matrix.counts.advertisedNotPacked})\n`,
  );
  return 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main(process.argv.slice(2)).then((code) => {
    process.exitCode = code;
  });
}
