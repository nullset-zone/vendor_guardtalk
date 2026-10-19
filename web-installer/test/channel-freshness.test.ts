/**
 * T-WEBINSTALL-FLASHALL-FRESHNESS — the channel freshness invariant.
 *
 * Acceptance criteria, asserted directly:
 *   (a) a channel whose sourceStamp no longer matches the pointed-at stamp
 *       FAILS (drift is caught);
 *   (b) a current channel PASSES (non-vacuity);
 *   (c) the check is wired into the readiness gate;
 *   (d) the July→September drift is caught.
 *
 * HONESTY: BOOT_VERIFIED=false. Freshness is provenance, not a boot proof.
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import {
  checkChannelFreshness,
  freshnessClause,
  parseStamp,
  type FreshnessInput,
} from "../scripts/channel-freshness.mjs";
import { INSTALLER_ROOT } from "../scripts/gen-flash-matrix.mjs";
import { DEFAULT_RELEASES_DIR, evaluateGate } from "../scripts/readiness-gate.mjs";
import {
  listStampsOnDisk,
  makeRoots,
  probeChannel,
  readManifestClaim,
  resolveLatestPointer,
} from "../scripts/tree-probe.mjs";

const MATRIX_PATH = join(INSTALLER_ROOT, "docs", "flash-matrix.json");
const GATE = join(INSTALLER_ROOT, "scripts", "readiness-gate.mjs");

const TOKAY_JULY = "tokay-20260725-102506";
const TOKAY_SEPT = "tokay-20260928-084839";

function input(overrides: Partial<FreshnessInput> = {}): FreshnessInput {
  const sourceStamp = overrides.sourceStamp ?? TOKAY_SEPT;
  const parsed = parseStamp(sourceStamp);
  return {
    sourceStamp,
    releaseId: parsed?.releaseId ?? "20260928-084839",
    unixEpoch: parsed?.unixEpoch ?? 0,
    currentStamp: TOKAY_SEPT,
    stampsOnDisk: [TOKAY_JULY, TOKAY_SEPT],
    ...overrides,
  };
}

test("FRESHNESS: parseStamp derives releaseId + UTC epoch from a stamp name", () => {
  const parsed = parseStamp(TOKAY_SEPT);
  assert.ok(parsed);
  assert.equal(parsed.product, "tokay");
  assert.equal(parsed.releaseId, "20260928-084839");
  // 2026-09-28T08:48:39Z
  assert.equal(parsed.unixEpoch, Date.UTC(2026, 8, 28, 8, 48, 39) / 1000);
  // Malformed names are refused, not guessed.
  assert.equal(parseStamp("latest"), null);
  assert.equal(parseStamp("tokay-latest"), null);
  assert.equal(parseStamp("tokay-20261301-000000"), null);
});

test("FRESHNESS: (b) a current channel PASSES (non-vacuity)", () => {
  const result = checkChannelFreshness("tokay", input());
  assert.equal(result.fresh, true);
  assert.ok(result.clauses.every((c) => c.ok));
});

test("FRESHNESS: (a) a channel whose sourceStamp no longer matches the stamp FAILS", () => {
  // Packed from July, but the product now points at September.
  const result = checkChannelFreshness(
    "tokay",
    input({ sourceStamp: TOKAY_JULY, currentStamp: TOKAY_SEPT }),
  );
  assert.equal(result.fresh, false);
  const failed = result.clauses.filter((c) => !c.ok).map((c) => c.id);
  assert.deepEqual(failed, ["source-stamp-is-current"]);
  const detail = result.clauses.find((c) => c.id === "source-stamp-is-current")?.detail ?? "";
  assert.match(detail, /STALE/);
  assert.match(detail, /tokay-20260725-102506/);
  assert.match(detail, /tokay-20260928-084839/);
});

test("FRESHNESS: (a) a sourceStamp with no stamp on disk FAILS (cannot be proven)", () => {
  const result = checkChannelFreshness(
    "tokay",
    input({ sourceStamp: "tokay-20260101-000000", currentStamp: "tokay-20260101-000000", stampsOnDisk: [TOKAY_SEPT] }),
  );
  assert.equal(result.fresh, false);
  assert.ok(result.clauses.some((c) => c.id === "source-stamp-exists-on-disk" && !c.ok));
});

test("FRESHNESS: (a) a stamp naming another product FAILS", () => {
  const result = checkChannelFreshness(
    "tokay",
    input({ sourceStamp: "akita-20260928-083403", currentStamp: "akita-20260928-083403", stampsOnDisk: ["akita-20260928-083403"] }),
  );
  assert.equal(result.fresh, false);
  assert.ok(result.clauses.some((c) => c.id === "source-stamp-product-matches" && !c.ok));
});

test("FRESHNESS: (a) a releaseId / unixEpoch that disagrees with the stamp FAILS", () => {
  const wrongId = checkChannelFreshness("tokay", input({ releaseId: "20260725-102506" }));
  assert.equal(wrongId.fresh, false);
  assert.ok(wrongId.clauses.some((c) => c.id === "release-id-matches-stamp" && !c.ok));

  const wrongEpoch = checkChannelFreshness("tokay", input({ unixEpoch: 1 }));
  assert.equal(wrongEpoch.fresh, false);
  assert.ok(wrongEpoch.clauses.some((c) => c.id === "unix-epoch-matches-stamp" && !c.ok));
});

test("FRESHNESS: (a) a malformed sourceStamp FAILS immediately (fail closed)", () => {
  const result = checkChannelFreshness("tokay", input({ sourceStamp: "tokay-latest" }));
  assert.equal(result.fresh, false);
  assert.equal(result.clauses.length, 1);
  assert.equal(result.clauses[0]!.id, "source-stamp-well-formed");
});

test("FRESHNESS: (a) a channel with no current pointer FAILS (absence is not freshness)", () => {
  const result = checkChannelFreshness("tokay", input({ currentStamp: null }));
  assert.equal(result.fresh, false);
  assert.ok(result.clauses.some((c) => c.id === "source-stamp-is-current" && !c.ok));
});

test("FRESHNESS: (d) the July→September drift is caught by the invariant", () => {
  // The exact shipped drift: channel packed in July, pointer moved in September.
  const result = checkChannelFreshness("tokay", {
    sourceStamp: TOKAY_JULY,
    releaseId: "20260725-102506",
    unixEpoch: parseStamp(TOKAY_JULY)!.unixEpoch,
    currentStamp: TOKAY_SEPT,
    stampsOnDisk: [TOKAY_JULY, TOKAY_SEPT],
  });
  assert.equal(result.fresh, false);
  const clause = result.clauses.find((c) => !c.ok);
  assert.equal(clause?.id, "source-stamp-is-current");
});

test("FRESHNESS: freshnessClause collapses one failure per channel, naming it", () => {
  const ok = checkChannelFreshness("tokay", input());
  const stale = checkChannelFreshness("akita", {
    sourceStamp: "akita-20260725-101434",
    releaseId: "20260725-101434",
    unixEpoch: parseStamp("akita-20260725-101434")!.unixEpoch,
    currentStamp: "akita-20260928-083403",
    stampsOnDisk: ["akita-20260725-101434", "akita-20260928-083403"],
  });
  const clause = freshnessClause([ok, stale]);
  assert.equal(clause.id, "channel-freshness");
  assert.equal(clause.ok, false);
  assert.match(clause.detail, /akita/);
  assert.match(clause.detail, /STALE/);
});

test("FRESHNESS: (c) the invariant is wired into the readiness gate (all live channels fresh)", () => {
  const matrix = JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as Record<string, unknown>;
  const result = evaluateGate(matrix);
  const freshness = result.clauses.find((c) => c.id === "channel-freshness");
  assert.ok(freshness, "gate must expose a channel-freshness clause");
  assert.equal(freshness.ok, true);
  assert.match(freshness.detail, /fresh/);
});

test("FRESHNESS: (c) the gate's freshness clause comes from this module (shared implementation)", () => {
  // Reconstruct the gate's own inputs and run the invariant directly; the
  // results must agree with the gate's clause. This proves the gate did not
  // re-implement the rule.
  //
  // T-WEBINSTALL-READINESS-GATE-TREE-BINDING: the gate now evaluates TWO views
  // per packed product — (i) the matrix's own projection, and (ii) the channel
  // manifest actually on disk against the `<product>-latest` pointer re-read
  // from the filesystem. This reconstruction must enumerate the SAME set, or it
  // would be comparing a subset and silently disagreeing.
  const matrix = JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as {
    devices: {
      product: string;
      packed: boolean;
      currentStamp: string | null;
      stampsOnDisk: string[];
      channels: { sourceStamp: string; releaseId: string; unixEpoch: number }[];
    }[];
  };
  const results = [];
  for (const device of matrix.devices) {
    if (!device.packed) continue;
    const product = device.product;

    // (i) the matrix's projection.
    for (const channel of device.channels) {
      results.push(
        checkChannelFreshness(product, {
          sourceStamp: channel.sourceStamp,
          releaseId: channel.releaseId,
          unixEpoch: channel.unixEpoch,
          currentStamp: device.currentStamp,
          stampsOnDisk: device.stampsOnDisk,
        }),
      );
    }

    // (ii) the disk-derived reality, read the same way the gate reads it.
    const diskProbe = probeChannel(makeRoots(INSTALLER_ROOT, DEFAULT_RELEASES_DIR), product);
    const latest = resolveLatestPointer(makeRoots(INSTALLER_ROOT, DEFAULT_RELEASES_DIR), product);
    const claim = readManifestClaim(diskProbe);
    const stamps = [...new Set([
      ...device.channels.map((c) => c.sourceStamp),
      ...(claim.sourceStamp === null ? [] : [claim.sourceStamp]),
    ])];
    for (const stamp of stamps) {
      const fromDisk = stamp === claim.sourceStamp;
      const fromMatrix = device.channels.find((c) => c.sourceStamp === stamp);
      // The gate hands `null` through to `checkChannelFreshness` for a manifest
      // that lacks a claim; mirror that with a sentinel that can never equal
      // the stamp's real token, so the reconstruction says the same thing.
      const releaseId = fromDisk ? claim.releaseId : (fromMatrix?.releaseId ?? null);
      const unixEpoch = fromDisk ? claim.unixEpoch : (fromMatrix?.unixEpoch ?? null);
      results.push(
        checkChannelFreshness(product, {
          sourceStamp: stamp,
          releaseId: releaseId ?? "",
          unixEpoch: unixEpoch ?? Number.NaN,
          currentStamp: latest.target,
          stampsOnDisk: listStampsOnDisk(makeRoots(INSTALLER_ROOT, DEFAULT_RELEASES_DIR), product),
        }),
      );
    }
  }
  const direct = freshnessClause(results);
  const gated = evaluateGate(matrix).clauses.find((c) => c.id === "channel-freshness");
  assert.deepEqual({ ok: gated?.ok, detail: gated?.detail }, { ok: direct.ok, detail: direct.detail });
});

test("FRESHNESS: (c) a stale matrix makes the gate FAIL through THIS clause", () => {
  const matrix = JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as {
    devices: { product: string; packed: boolean; channels: { sourceStamp: string }[] }[];
  };
  const tokay = matrix.devices.find((d) => d.product === "tokay");
  assert.ok(tokay);
  tokay.channels[0]!.sourceStamp = TOKAY_JULY;
  const result = evaluateGate(matrix);
  assert.equal(result.pass, false);
  const freshness = result.clauses.find((c) => c.id === "channel-freshness");
  assert.equal(freshness?.ok, false);
  assert.match(freshness?.detail ?? "", /STALE/);
});

test("FRESHNESS: the CLI gate exposes the same freshness detail", () => {
  const stdout = execFileSync(process.execPath, [GATE], { encoding: "utf8" });
  assert.match(stdout, /\[ok\] channel-freshness: all \d+ packed channel\(s\) are fresh/);
});
