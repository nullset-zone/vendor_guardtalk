/**
 * F-EXCISE-WEBINSTALL-READINESS-GUARD — web-installer readiness-tier parity.
 *
 * Headless: drives the pure policy + the emitted step-0 markup, so both
 * acceptance paths are provable without a browser:
 *   - READY: commits a selection with no gate and no acknowledgement.
 *   - BUILD-OK blocked: the picker refuses to commit until the codename is
 *     typed; only then does the selection commit.
 *   - HOLD: no acknowledgement path exists; selection never commits.
 * The claim linter is exercised with a deliberately bad fixture (negative
 * control) to prove the new `no-boot-overclaim` rule is non-vacuous.
 *
 * The manifest is GENERATED from the canonical reporter. The determinism test
 * below regenerates it from a captured report and requires a byte-identical
 * result, so it cannot have been hand-written to suit a test.
 */
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { lintFiles, lintText } from "../lib/claims/lint-claims.js";
import { WIZARD_DEVICES } from "../lib/ui/offered-devices.js";
import {
  BOOT_VERIFIED,
  OFFERABLE_TIERS,
  READINESS_PROVENANCE,
  TIER_POLICY,
  acknowledgementMatches,
  buildOkAcknowledgementMatches,
  canCommitSelection,
  canCommitTier,
  isOfferable,
  manifestEntry,
  readinessChipWord,
  readinessFor,
  requiresAcknowledgement,
  requiresBuildOkAcknowledgement,
  selectionRefused,
  tierPolicy,
  tierRequiresAcknowledgement,
} from "../lib/ui/readiness.js";
import {
  READINESS_MANIFEST,
  type ReadinessStatus,
} from "../lib/ui/readiness-manifest.js";
import {
  renderReadinessGate,
  renderStep0,
  type ReadinessGateView,
} from "../routes/install/early-steps.js";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const ROOT = fileURLToPath(new URL("..", import.meta.url));
const CAPTURED_TSV = `${HERE}fixtures/readiness/readiness-report.tsv`;

/** Only the fingerprint-order rule is route-specific; every other rule applies. */
function lintMarkup(html: string, file: string) {
  return lintText(html, file).filter((hit) => hit.rule !== "no-success-before-fingerprint-compare");
}

function rowFor(html: string, codename: string): string {
  const row = html.split("<tr").find((candidate) => candidate.includes(`data-codename="${codename}"`));
  assert.ok(row !== undefined, `row for ${codename}`);
  return row;
}

/** Parse the captured reporter TSV exactly as gen-readiness-manifest.sh does. */
function capturedStatuses(): ReadonlyMap<string, ReadinessStatus> {
  const map = new Map<string, ReadinessStatus>();
  for (const line of readFileSync(CAPTURED_TSV, "utf8").split("\n")) {
    if (line.trim() === "") {
      continue;
    }
    const cells = line.split("\t");
    const codename = cells[0];
    const status = cells[3];
    if (codename === undefined || status === undefined) {
      continue;
    }
    map.set(codename, status as ReadinessStatus);
  }
  return map;
}

// ---------------------------------------------------------------------------
// The manifest is derived, not hand-written
// ---------------------------------------------------------------------------

test("the manifest is exactly what the generator derives from the captured report", () => {
  // `--check --from-tsv` exits non-zero if lib/ui/readiness-manifest.ts differs
  // from the generator's output for the captured reporter TSV. This is the
  // proof that the shipped tiers are derived, not hand-written to suit a test.
  const out = execFileSync(
    "bash",
    ["scripts/gen-readiness-manifest.sh", "--from-tsv", CAPTURED_TSV, "--check"],
    { cwd: ROOT, encoding: "utf8" },
  );
  assert.match(out, /is up to date/);
  assert.ok(READINESS_MANIFEST.length > 0, "manifest must not be vacuous");
  const committed = readFileSync(`${ROOT}lib/ui/readiness-manifest.ts`, "utf8");
  assert.match(committed, /GENERATED FILE — DO NOT EDIT BY HAND/);
});

test("the shipped manifest reports exactly the statuses in the captured report", () => {
  const captured = capturedStatuses();
  assert.ok(captured.size > 0, "captured report must have rows");
  for (const entry of READINESS_MANIFEST) {
    assert.equal(entry.status, captured.get(entry.codename), `status mismatch for ${entry.codename}`);
  }
  // Every captured device is represented (no silent dropping of an awkward tier).
  for (const codename of captured.keys()) {
    assert.ok(manifestEntry(codename) !== undefined, `missing manifest row for ${codename}`);
  }
  assert.ok(
    READINESS_PROVENANCE.sourceScriptSha256.length === 64,
    "manifest must record the reporter's sha256",
  );
});

// ---------------------------------------------------------------------------
// Tier model
// ---------------------------------------------------------------------------

test("tiers are semantically distinct, not a colour", () => {
  assert.equal(BOOT_VERIFIED, false);
  const words = new Set([
    readinessChipWord("READY"),
    readinessChipWord("READY-ACK"),
    readinessChipWord("BUILD-OK"),
    readinessChipWord("HOLD"),
    readinessChipWord("PENDING"),
  ]);
  assert.equal(words.size, 5, "every tier must carry its own word");
  assert.match(readinessChipWord("BUILD-OK"), /UNVERIFIED/);
  assert.match(readinessChipWord("READY-ACK"), /NOT STAMP-PROVEN/);
  assert.notEqual(readinessChipWord("READY-ACK"), readinessChipWord("READY"));
  assert.match(readinessChipWord("HOLD"), /NOT-STAMP-VERIFIED/);
  assert.deepEqual([...OFFERABLE_TIERS].sort(), ["BUILD-OK", "READY", "READY-ACK"]);
  assert.equal(isOfferable("READY"), true);
  assert.equal(isOfferable("READY-ACK"), true);
  assert.equal(isOfferable("BUILD-OK"), true);
  assert.equal(isOfferable("HOLD"), false);
  assert.equal(isOfferable("PENDING"), false);
});

test("the tier policy map is the single, explicit authority (no string-union default)", () => {
  assert.deepEqual(Object.keys(TIER_POLICY).sort(), ["BUILD-OK", "HOLD", "PENDING", "READY", "READY-ACK"]);
  assert.equal(TIER_POLICY.READY.offerable, true);
  assert.equal(TIER_POLICY.READY.requiresAcknowledgement, false);
  assert.equal(TIER_POLICY["READY-ACK"].offerable, true);
  assert.equal(TIER_POLICY["READY-ACK"].requiresAcknowledgement, true, "READY-ACK is acknowledgement-gated");
  assert.equal(TIER_POLICY["BUILD-OK"].offerable, true);
  assert.equal(TIER_POLICY["BUILD-OK"].requiresAcknowledgement, true);
  assert.equal(TIER_POLICY.HOLD.offerable, false);
  assert.equal(TIER_POLICY.PENDING.offerable, false);
  for (const tier of Object.keys(TIER_POLICY)) {
    assert.equal(tierPolicy(tier)?.offerable, TIER_POLICY[tier as keyof typeof TIER_POLICY].offerable);
    assert.equal(isOfferable(tier), TIER_POLICY[tier as keyof typeof TIER_POLICY].offerable);
    assert.equal(
      tierRequiresAcknowledgement(tier),
      TIER_POLICY[tier as keyof typeof TIER_POLICY].requiresAcknowledgement,
    );
  }
});

test("canCommitTier is FAIL-CLOSED for any tier absent from the explicit map", () => {
  // The exact fail-open QA found: a naive OFFERABLE_TIERS/union extension made
  // `canCommitTier` return true for ANY offerable-looking token that is not
  // BUILD-OK. The explicit map must REFUSE every one of these.
  const INTERLOPERS = [
    "READY-NEW",
    "SUPER-READY",
    "READY_ACK",
    "ready-ack",
    "readystamp",
    "FLASHY",
    "",
    "__proto__",
    "constructor",
    "toString",
    "hasOwnProperty",
  ];
  for (const token of INTERLOPERS) {
    assert.equal(tierPolicy(token), undefined, `no policy for '${token}'`);
    assert.equal(isOfferable(token), false, `'${token}' must not be offerable`);
    assert.equal(
      canCommitTier(token, "rango", "rango"),
      false,
      `'${token}' must be REFUSED even with the exact codename acknowledged`,
    );
    assert.equal(canCommitTier(token, "rango", undefined), false, `'${token}' refused with no acknowledgement`);
    assert.equal(canCommitSelection("rango", undefined), false, `'${token}' cannot resurrect a real device`);
  }
  // Control: the REAL new tier is offerable but still needs its own codename.
  assert.equal(canCommitTier("READY-ACK", "rango", "rango"), true);
  assert.equal(canCommitTier("READY-ACK", "rango", undefined), false, "READY-ACK is not silently committed");
  assert.equal(canCommitTier("READY-ACK", "rango", "tokay"), false, "another device's ack is not consent");
});

test("every advertised device carries a host-derived tier", () => {
  for (const device of WIZARD_DEVICES) {
    const view = readinessFor(device.id);
    assert.ok(manifestEntry(device.id) !== undefined, `${device.id} must be classified by the host`);
    assert.equal(view.offerable, isOfferable(view.tier));
  }
});

// ---------------------------------------------------------------------------
// Acceptance: a BUILD-OK device cannot be selected without acknowledgement
// ---------------------------------------------------------------------------

test("READY happy path: READY commits with no gate and no acknowledgement", () => {
  assert.equal(canCommitTier("READY", "tokay", undefined), true);
  assert.equal(canCommitTier("READY", "tokay", "something-else"), true);
  const html = renderStep0("tokay");
  assert.doesNotMatch(html, /data-readiness-gate="/);
  assert.match(html, /option value="tokay"[^>]* selected/);
});

test("BUILD-OK blocked path: rango does not commit until its codename is typed", () => {
  // rango is the laguna BUILD-OK device in the captured report.
  assert.equal(readinessFor("rango").tier, "BUILD-OK");
  assert.equal(requiresBuildOkAcknowledgement("rango"), true);
  assert.equal(canCommitSelection("rango", undefined), false, "no acknowledgement ⇒ no commit");
  // A bare y / wrong case is not consent (parity with gt-flash-wizard.sh).
  assert.equal(buildOkAcknowledgementMatches("rango", "y"), false);
  assert.equal(buildOkAcknowledgementMatches("rango", "Rango"), false);
  assert.equal(buildOkAcknowledgementMatches("rango", ""), false);
  assert.equal(buildOkAcknowledgementMatches("rango", "rango"), true);
  assert.equal(buildOkAcknowledgementMatches("rango", "  rango  "), true);

  const gate: ReadinessGateView = {
    product: "rango",
    deviceName: readinessFor("rango").model,
    tier: "BUILD-OK",
    reason: readinessFor("rango").reason,
    remedy: readinessFor("rango").remedy,
  };
  const blocked = renderStep0("tokay", gate);
  assert.match(blocked, /data-readiness-gate="BUILD-OK"/);
  assert.match(blocked, /data-product="rango"/);
  assert.match(blocked, /data-action="acknowledge-build-ok"/);
  assert.match(blocked, /data-action="cancel-build-ok"/);
  assert.match(blocked, /data-role="readiness-ack"/);
  assert.match(blocked, /BOOT_VERIFIED=false/);
  assert.doesNotMatch(blocked, /BOOT_VERIFIED=true/);
});

test("BUILD-OK acknowledged path: only a matching codename commits the selection", () => {
  assert.equal(canCommitSelection("rango", "rango"), true);
  assert.equal(canCommitTier("BUILD-OK", "rango", "rango"), true);
  assert.equal(canCommitTier("BUILD-OK", "rango", "tokay"), false, "another device's ack is not consent");
  const acknowledged = renderStep0("rango");
  assert.doesNotMatch(acknowledged, /data-readiness-gate="/);
  assert.match(acknowledged, /option value="rango"[^>]* selected/);
});

test("HOLD has no acknowledgement path and never commits", () => {
  assert.equal(canCommitTier("HOLD", "tokay", undefined), false);
  assert.equal(canCommitTier("HOLD", "tokay", "tokay"), false, "typing the codename must not unlock HOLD");
  assert.equal(canCommitTier("PENDING", "tokay", "tokay"), false);
  assert.equal(canCommitSelection("rango", "rango"), true, "control: the offerable tier still commits");
});

test("flash path refuses an unofferable or unacknowledged target", () => {
  assert.match(selectionRefused("rango", undefined) ?? "", /BUILD-OK/);
  assert.equal(selectionRefused("rango", "rango"), undefined, "acknowledged laguna is permitted");
  assert.equal(selectionRefused("shiba", undefined), undefined, "unoffered codename is out of scope");
  // Drive the expectation from the manifest so a host tier change cannot make
  // this assertion silently wrong.
  for (const device of WIZARD_DEVICES) {
    const view = readinessFor(device.id);
    const refusal = selectionRefused(device.id, undefined);
    if (view.tier === "READY") {
      assert.equal(refusal, undefined, `${device.id} is READY and must not be refused`);
    } else {
      assert.ok(refusal !== undefined, `${device.id} is ${view.tier} and must be refused`);
    }
  }
});

test("an unclassified codename fails closed rather than defaulting to READY", () => {
  assert.equal(manifestEntry("not-a-real-codename"), undefined);
  assert.equal(canCommitTier("PENDING", "not-a-real-codename", "not-a-real-codename"), false);
});

// ---------------------------------------------------------------------------
// Honesty: the gate never implies boot verification; the copy stays lint-clean
// ---------------------------------------------------------------------------

test("the acknowledgement gate never states a boot result", () => {
  const gate = renderReadinessGate({
    product: "rango",
    deviceName: readinessFor("rango").model,
    tier: "BUILD-OK",
    reason: readinessFor("rango").reason,
    remedy: readinessFor("rango").remedy,
  });
  assert.match(gate, /not boot-verified/);
  assert.match(gate, /Boot is UNVERIFIED/);
  assert.match(gate, /BOOT_VERIFIED=false/);
  assert.doesNotMatch(gate, /BOOT_VERIFIED=true/);
  assert.doesNotMatch(gate, /\bthis (?:stamp|build|bundle|device) (?:will )?boots?\b/i);
});

test("readiness copy passes the project claim linter in every state", () => {
  const holdView: ReadinessGateView = {
    product: "tokay",
    deviceName: readinessFor("tokay").model,
    tier: readinessFor("tokay").tier,
    reason: readinessFor("tokay").reason,
    remedy: readinessFor("tokay").remedy,
  };
  const buildOkView: ReadinessGateView = {
    product: "rango",
    deviceName: readinessFor("rango").model,
    tier: "BUILD-OK",
    reason: readinessFor("rango").reason,
    remedy: readinessFor("rango").remedy,
  };
  for (const [name, html] of [
    ["step0-plain", renderStep0("tokay")],
    ["step0-build-ok-gate", renderStep0("tokay", buildOkView)],
    ["step0-hold-gate", renderStep0("tokay", holdView)],
    ["step0-acknowledged", renderStep0("rango")],
    ["gate-hold", renderReadinessGate(holdView)],
    ["gate-build-ok", renderReadinessGate(buildOkView)],
  ] as ReadonlyArray<readonly [string, string]>) {
    const hits = lintMarkup(html, `${name}.html`);
    assert.deepEqual(hits, [], hits.map((hit) => `${hit.rule}: ${hit.excerpt}`).join("\n"));
  }
});

test("step 0 renders each device at its manifest tier, in words, with provenance", () => {
  const html = renderStep0("tokay");
  assert.match(html, /gt-ready-devices\.sh/);
  assert.match(html, /BOOT_VERIFIED=false/);
  // Assert against the manifest, not a hardcoded expectation: if the host
  // re-confers READY the markup must follow it, and if it withdraws READY the
  // markup must follow that too.
  for (const codename of ["tokay", "akita", "komodo", "rango"] as const) {
    const entry = manifestEntry(codename);
    assert.ok(entry !== undefined, `${codename} must be classified`);
    const row = rowFor(html, codename);
    assert.match(row, new RegExp(`data-readiness="${entry.status}"`), `${codename} tier in markup`);
    assert.match(
      row,
      new RegExp(`data-requires-ack="${entry.status === "BUILD-OK" ? "true" : "false"}"`),
      `${codename} ack flag in markup`,
    );
    assert.match(row, new RegExp(`data-offerable="${isOfferable(entry.status) ? "true" : "false"}"`));
    // The tier is carried as a WORD, so it is never colour-only.
    assert.ok(row.includes(readinessChipWord(entry.status).replace(/·/g, "·")), `${codename} tier word`);
  }
  assert.match(rowFor(html, "rango"), /BUILD-OK · BOOT UNVERIFIED/);
});

// ---------------------------------------------------------------------------
// Claim-linter negative control (non-vacuous)
// ---------------------------------------------------------------------------

test("claim linter BITES a deliberately bad boot-overclaim fixture", () => {
  const bad = lintText(
    "READY: this build is boot-verified.\nBOOT_VERIFIED=true\nThis device boots.",
    "bad-fixture.txt",
  );
  assert.equal(bad.filter((hit) => hit.rule === "no-boot-overclaim").length, 3);
});

test("claim linter leaves the honest readiness wording alone", () => {
  const honest = lintText("BUILD-OK — this build is not boot-verified; boot is UNVERIFIED.", "honest.txt");
  assert.deepEqual(honest.filter((hit) => hit.rule === "no-boot-overclaim"), []);
});

test("the bad fixture file is caught through the CLI-facing lintFiles path", () => {
  const badFile = fileURLToPath(new URL("./fixtures/claims/readiness-overclaim.txt", import.meta.url));
  const honestFile = fileURLToPath(new URL("./fixtures/claims/readiness-honest.txt", import.meta.url));
  assert.ok(lintFiles([badFile]).some((hit) => hit.rule === "no-boot-overclaim"));
  assert.deepEqual(lintFiles([honestFile]).filter((hit) => hit.rule === "no-boot-overclaim"), []);
});

// ---------------------------------------------------------------------------
// T-EXCISE-WEBINSTALL-ACK-ABSORB — the third tier, fail-closed
// ---------------------------------------------------------------------------

const READY_ACK_TSV = `${HERE}fixtures/readiness/readiness-report-ready-ack.tsv`;

test("a READY-ACK row generates cleanly and renders a DISTINCT, non-READY status", () => {
  const outDir = mkdtempSync(join(tmpdir(), "gt-ready-ack-"));
  const outFile = join(outDir, "readiness-manifest.ts");
  try {
    const stdout = execFileSync("bash", ["scripts/gen-readiness-manifest.sh", "--from-tsv", READY_ACK_TSV], {
      cwd: ROOT,
      encoding: "utf8",
      env: { ...process.env, GT_MANIFEST_OUT: outFile, GT_MANIFEST_TIMESTAMP: "2026-01-01T00:00:00Z" },
    });
    assert.match(stdout, /wrote/);
    const text = readFileSync(outFile, "utf8");
    assert.match(
      text,
      /export type ReadinessStatus = "READY" \| "READY-ACK" \| "BUILD-OK" \| "HOLD" \| "PENDING";/,
    );
    assert.match(text, /codename: "tokay",[\s\S]*?status: "READY-ACK"/, "READY-ACK row emitted");
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }

  // The gate for a READY-ACK target names its OWN tier, requires the codename,
  // and never renders plain READY or claims a boot result.
  const view: ReadinessGateView = {
    product: "tokay",
    deviceName: "Pixel 9",
    tier: "READY-ACK",
    reason: readinessFor("tokay").reason,
    remedy: readinessFor("tokay").remedy,
  };
  const gate = renderReadinessGate(view);
  assert.match(gate, /data-readiness-gate="READY-ACK"/);
  assert.match(gate, /data-role="readiness-ack"/);
  assert.match(gate, /data-action="acknowledge-build-ok"/);
  assert.match(gate, /READY-ACK · OPERATOR-ACKNOWLEDGED, NOT STAMP-PROVEN/);
  assert.doesNotMatch(gate, /Tier<\/dt><dd>READY<\/dd>/, "must not render as plain READY");
  assert.match(gate, /BOOT_VERIFIED=false/);
  assert.doesNotMatch(gate, /BOOT_VERIFIED=true/);
  assert.deepEqual(lintMarkup(gate, "gate-ready-ack.html"), []);
  assert.equal(canCommitTier("READY-ACK", "tokay", undefined), false, "no codename ⇒ no commit");
  assert.equal(canCommitTier("READY-ACK", "tokay", "tokay"), true, "codename ⇒ commits");
});

test("the generator REFUSES an unknown STATUS rather than guessing a tier", () => {
  const outDir = mkdtempSync(join(tmpdir(), "gt-bad-status-"));
  try {
    const badTsv = join(outDir, "bad.tsv");
    writeFileSync(badTsv, "tokay\tPixel 9\ttokay-x\tREADY-NEW\treason\tremedy\n");
    assert.throws(() =>
      execFileSync("bash", ["scripts/gen-readiness-manifest.sh", "--from-tsv", badTsv], {
        cwd: ROOT,
        encoding: "utf8",
        env: { ...process.env, GT_MANIFEST_OUT: join(outDir, "manifest.ts") },
      }),
    );
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// T-EXCISE-WEBINSTALL-ACK-ABSORB — drift decoupled from the live reporter
// ---------------------------------------------------------------------------

test("the drift check uses the RECORDED reporter fingerprint, not the live reporter", () => {
  const sideCar = `${HERE}fixtures/readiness/readiness-report.reporter.sha256`;
  const recorded = (readFileSync(sideCar, "utf8").trim().split(/\s+/)[0] ?? "").trim();
  assert.equal(recorded.length, 64, "sidecar must record a 64-hex fingerprint");
  assert.equal(
    READINESS_PROVENANCE.sourceScriptSha256,
    recorded,
    "shipped provenance must be the recorded fingerprint, not a live hash",
  );

  // The deterministic check still exits 0 even though the live reporter has
  // changed since capture (any upstream reporter edit cannot red this suite).
  const out = execFileSync(
    "bash",
    ["scripts/gen-readiness-manifest.sh", "--from-tsv", CAPTURED_TSV, "--check"],
    { cwd: ROOT, encoding: "utf8" },
  );
  assert.match(out, /is up to date/);

  const outDir = mkdtempSync(join(tmpdir(), "gt-reporter-sha-"));
  try {
    // A TSV with no sibling sidecar records NO live hash: if the generator
    // consulted the live reporter here, this would emit the live sha instead.
    const bareTsv = join(outDir, "bare.tsv");
    copyFileSync(CAPTURED_TSV, bareTsv);
    const bareOut = join(outDir, "bare-manifest.ts");
    execFileSync("bash", ["scripts/gen-readiness-manifest.sh", "--from-tsv", bareTsv], {
      cwd: ROOT,
      encoding: "utf8",
      env: { ...process.env, GT_MANIFEST_OUT: bareOut, GT_MANIFEST_TIMESTAMP: "2026-01-01T00:00:00Z" },
    });
    assert.match(
      readFileSync(bareOut, "utf8"),
      /sourceScriptSha256: "unrecorded"/,
      "no sidecar ⇒ no live hash is consulted on the deterministic path",
    );

    // The fingerprint is an EXPLICIT, injectable documented input.
    const sentinel = "0123456789abcdef".repeat(4);
    const sentinelOut = join(outDir, "sentinel-manifest.ts");
    execFileSync("bash", ["scripts/gen-readiness-manifest.sh", "--from-tsv", CAPTURED_TSV], {
      cwd: ROOT,
      encoding: "utf8",
      env: {
        ...process.env,
        GT_MANIFEST_OUT: sentinelOut,
        GT_REPORTER_SHA: sentinel,
        GT_MANIFEST_TIMESTAMP: "2026-01-01T00:00:00Z",
      },
    });
    assert.match(readFileSync(sentinelOut, "utf8"), new RegExp(`sourceScriptSha256: "${sentinel}"`));
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// Regression controls: the BUILD-OK gate and its aliases stay non-vacuous
// ---------------------------------------------------------------------------

test("the acknowledgement matcher and its compatibility alias agree exactly", () => {
  for (const typed of ["rango", "  rango  ", "y", "Rango", "", "rango extra"]) {
    assert.equal(acknowledgementMatches("rango", typed), buildOkAcknowledgementMatches("rango", typed));
  }
  assert.equal(acknowledgementMatches("rango", "rango"), true);
  assert.equal(acknowledgementMatches("rango", "y"), false);
  // The legacy name still returns the (now policy-derived) ack requirement.
  assert.equal(requiresBuildOkAcknowledgement("rango"), requiresAcknowledgement("rango"));
  assert.equal(requiresAcknowledgement("rango"), true, "BUILD-OK is acknowledgement-gated");
  assert.equal(requiresAcknowledgement("tokay"), false, "a non-gated tier is not");
});
