/**
 * T-WEBINSTALL-SIGNED-ROOT-MODE-SURFACE — the readiness gate must NAME the
 * anchor mode in force, and the name must be DERIVED from what validated.
 *
 * Acceptance asserted here:
 *   (a) `--json` carries an explicit anchor-mode field;
 *   (b) the human-readable summary names the mode;
 *   (c)+(d) the field FOLLOWS the mechanism — a probe that changes the
 *           mechanism changes the field (no hardcoded string);
 *   (e) nothing claims `signed`/`verified` while the mode is the review-gated
 *       dev path.
 *
 * The drills run against throwaway trees in os.tmpdir(): the real `channels/`
 * and `releases/desktop-flash/` are never touched.
 *
 * HONESTY: a mode names the AUTHENTICITY MECHANISM. It never says these images
 * boot, and `BOOT_VERIFIED=false` is untouched by this suite.
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { INSTALLER_ROOT } from "../scripts/gen-flash-matrix.mjs";
import { deriveAnchorMode } from "../scripts/anchor-mode.mjs";
import type { AnchorMode } from "../scripts/anchor-mode.mjs";
import { FIXTURE_PRODUCTS, genuineTree } from "./fixtures/tree-fixture.js";

const GATE = join(INSTALLER_ROOT, "scripts", "readiness-gate.mjs");

interface GatePayload {
  gate: string;
  exitCode: number;
  summary: string;
  anchorMode: AnchorMode;
  clauses: { id: string; ok: boolean; detail: string }[];
}

function runGate(args: string[], env: NodeJS.ProcessEnv = process.env): {
  code: number;
  stdout: string;
  stderr: string;
} {
  try {
    const stdout = execFileSync(process.execPath, [GATE, ...args], { encoding: "utf8", stdio: "pipe", env });
    return { code: 0, stdout, stderr: "" };
  } catch (err) {
    const e = err as { status?: number; stdout?: string; stderr?: string };
    return { code: e.status ?? -1, stdout: String(e.stdout ?? ""), stderr: String(e.stderr ?? "") };
  }
}

/** Gate a throwaway fixture tree through the REAL CLI (the operator's invocation). */
function gateFixtureTree(root: string, releasesDir: string): { code: number; payload: GatePayload } {
  const env = { ...process.env, GUARDTALK_INSTALLER_ROOT: root, GUARDTALK_RELEASES_DIR: releasesDir };
  const run = runGate(["--json", `--matrix=${join(root, "docs", "flash-matrix.json")}`], env);
  const payload = JSON.parse(run.stdout) as GatePayload;
  return { code: run.code, payload };
}

/** The one clause whose detail must carry the mode. */
function trustAnchorDetail(payload: GatePayload): string {
  const clause = payload.clauses.find((c) => c.id === "trust-anchor");
  assert.ok(clause !== undefined, "the gate must still expose the trust-anchor clause");
  return clause.detail;
}

/** Values a reader could take as an authenticity claim. */
function modeStrings(mode: AnchorMode): string[] {
  return [mode.id, mode.mechanism, mode.label, mode.channel ?? ""];
}

test("ANCHOR-MODE (a): --json carries an explicit anchor-mode field (live tree)", () => {
  const run = runGate(["--json"]);
  assert.equal(run.code, 0, run.stdout);
  const payload = JSON.parse(run.stdout) as GatePayload;
  assert.ok(payload.anchorMode !== undefined && payload.anchorMode !== null, "--json must carry anchorMode");
  assert.equal(payload.anchorMode.id, "review-gated-pins");
  assert.equal(payload.anchorMode.mechanism, "review-gated-pins");
  assert.equal(payload.anchorMode.validated, true, "the live pins do match");
  assert.equal(payload.anchorMode.signed, false, "the dev channel is NOT signed");
  assert.equal(payload.anchorMode.channel, "dev");
  assert.match(payload.anchorMode.label, /^review-gated-pins \(unsigned/);
  assert.match(payload.anchorMode.label, /not GrapheneOS-equivalent/);
  // The mode is a FIELD, not a clause: the 14-clause contract is unchanged.
  assert.equal(payload.clauses.length, 14);
});

test("ANCHOR-MODE (b): the human summary line names the mode", () => {
  const json = runGate(["--json"]);
  const human = runGate([]);
  const payload = JSON.parse(json.stdout) as GatePayload;
  const summaryLine = human.stdout.split("\n").find((line) => line.startsWith("READINESS-GATE:")) ?? "";
  assert.match(summaryLine, /anchor-mode=review-gated-pins \(unsigned/);
  assert.match(summaryLine, /not GrapheneOS-equivalent/);
  // The same string is in --json.summary, so a machine reader sees it too.
  assert.ok(payload.summary.includes(`anchor-mode=${payload.anchorMode.label}`));
  // And the clause detail — the surface that previously read like a positive.
  assert.match(trustAnchorDetail(payload), /anchor-mode: review-gated-pins \(unsigned/);
});

test("ANCHOR-MODE (c)+(d): the field FOLLOWS the validating mechanism (pins absent ⇒ unverified)", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    // Same tree, same matrix, pins present: the pins mechanism validated.
    const pinned = gateFixtureTree(tree.root, tree.releasesDir);
    assert.equal(pinned.code, 0, "a genuine pinned tree must PASS");
    assert.deepEqual(
      { id: pinned.payload.anchorMode.id, validated: pinned.payload.anchorMode.validated },
      { id: "review-gated-pins", validated: true },
    );

    // Remove ONLY the pin document. The mechanism that validated is GONE, so
    // the mode must follow it — and the gate must FAIL (absence is not
    // integrity), never keep reporting a mode with validated:true.
    tree.writer.writeAnchors(null);
    const unpinned = gateFixtureTree(tree.root, tree.releasesDir);
    assert.equal(unpinned.code, 1, "removing the pins must FAIL, not PASS");
    assert.equal(unpinned.payload.anchorMode.id, "unverified");
    assert.equal(unpinned.payload.anchorMode.mechanism, "none");
    assert.equal(unpinned.payload.anchorMode.validated, false);
    assert.equal(unpinned.payload.anchorMode.signed, false);
    assert.match(unpinned.payload.anchorMode.label, /^unverified/);
    assert.match(trustAnchorDetail(unpinned.payload), /anchor-mode: unverified/);
    assert.notEqual(
      unpinned.payload.anchorMode.label,
      pinned.payload.anchorMode.label,
      "the field must CHANGE when the mechanism changes",
    );
  } finally {
    tree.writer.cleanup();
  }
});

test("ANCHOR-MODE (d): the label is read from the pin document, not hardcoded", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    const dev = gateFixtureTree(tree.root, tree.releasesDir);
    assert.equal(dev.code, 0, "genuine tree must PASS");
    assert.match(dev.payload.anchorMode.label, /channel=dev/);

    // Same bytes, same pins, different DECLARED channel: the emitted string
    // follows the evidence. A hardcoded label could not do this.
    tree.writer.writeAnchors(tree.writer.pins(FIXTURE_PRODUCTS, "staging"));
    const staging = gateFixtureTree(tree.root, tree.releasesDir);
    assert.equal(staging.code, 0, "the pins still match, so the gate still PASSES");
    assert.equal(staging.payload.anchorMode.id, "review-gated-pins");
    assert.equal(staging.payload.anchorMode.channel, "staging");
    assert.match(staging.payload.anchorMode.label, /channel=staging/);
    assert.doesNotMatch(staging.payload.anchorMode.label, /channel=dev/);
  } finally {
    tree.writer.cleanup();
  }
});

test("ANCHOR-MODE (d): a CLAIMED signed root does not raise the mode (fail closed)", () => {
  const anchorResult = { ok: true, results: [{ product: "tokay", pinned: true }] };
  const pins = { channel: "dev", signedRoot: true, schemaVersion: "expected-anchors/1" };

  // A pin document that merely SAYS it is a signed root is still just a
  // checked-in constant: it must not raise the mode.
  const declared = deriveAnchorMode({ anchorResult, pins });
  assert.equal(declared.id, "review-gated-pins");
  assert.equal(declared.signed, false);

  // A verifier result that did NOT verify must not raise it either.
  const failed = deriveAnchorMode({
    anchorResult,
    pins,
    signatureVerification: { mechanism: "signed-root", verified: false },
  });
  assert.equal(failed.id, "review-gated-pins");
  assert.equal(failed.signed, false);

  // A result from a DIFFERENT mechanism is not a signed root.
  const other = deriveAnchorMode({
    anchorResult,
    pins,
    signatureVerification: { mechanism: "self-declared", verified: true },
  });
  assert.equal(other.id, "review-gated-pins");
  assert.equal(other.signed, false);
});

test("ANCHOR-MODE (c): a VERIFIED signed root flips the mode (the future seam)", () => {
  const anchorResult = { ok: true, results: [{ product: "tokay", pinned: true }] };
  const pins = { channel: "dev" };
  const pinMode = deriveAnchorMode({ anchorResult, pins });
  const signedMode = deriveAnchorMode({
    anchorResult,
    pins,
    signatureVerification: { mechanism: "signed-root", verified: true, channel: "release" },
  });

  assert.equal(pinMode.id, "review-gated-pins");
  assert.equal(pinMode.signed, false);
  assert.equal(signedMode.id, "signed-root");
  assert.equal(signedMode.mechanism, "signed-root");
  assert.equal(signedMode.signed, true);
  assert.equal(signedMode.validated, true);
  assert.equal(signedMode.label, "signed-root (production)");
  assert.notEqual(signedMode.label, pinMode.label);
});

test("ANCHOR-MODE (e): nothing claims signed/verified on the review-gated dev path", () => {
  const json = runGate(["--json"]);
  const human = runGate([]);
  const payload = JSON.parse(json.stdout) as GatePayload;
  assert.equal(payload.anchorMode.signed, false);

  const summaryLine = human.stdout.split("\n").find((line) => line.startsWith("READINESS-GATE:")) ?? "";
  const surfaces = [payload.anchorMode.label, summaryLine, trustAnchorDetail(payload)];
  for (const surface of surfaces) {
    assert.match(surface, /unsigned/, `the mode must say UNSIGNED: ${surface}`);
    // `(?<!un)` allows only "unsigned"/"unverified" — never a positive claim.
    assert.doesNotMatch(surface, /(?<!un)signed/i, `no signed claim allowed: ${surface}`);
    assert.doesNotMatch(surface, /(?<!un)verified/i, `no verified claim allowed: ${surface}`);
  }
  // The machine values carry the same discipline.
  for (const value of modeStrings(payload.anchorMode)) {
    assert.doesNotMatch(value, /(?<!un)signed/i, `no signed claim allowed: ${value}`);
    assert.doesNotMatch(value, /(?<!un)verified/i, `no verified claim allowed: ${value}`);
  }
});
