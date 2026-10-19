/**
 * T-WEBINSTALL-FLASHALL-READINESS-GATE — ONE command, ONE exit code.
 *
 * Acceptance criteria, asserted directly:
 *   (a) one command, one exit code, summary ⇔ exit equivalence;
 *   (b) FAILS on a stale (July-stamp) matrix — the pre-repack state is
 *       reconstructed as a synthetic fixture and must FAIL;
 *   (c) PASSES on a synthetic all-current matrix (non-vacuity BOTH ways);
 *   (d) a missing / stale / mismatched channel each INDEPENDENTLY fails;
 *   (e) the gate reads the same source the copy does (status.json + the
 *       generated matrix), and its verdict is what the claims linter consumes.
 *
 * HONESTY: BOOT_VERIFIED=false. A PASS is "advertised ⟺ packed and fresh".
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { INSTALLER_ROOT, buildMatrix } from "../scripts/gen-flash-matrix.mjs";
import { evaluateGate } from "../scripts/readiness-gate.mjs";
import {
  FIXTURE_PRODUCTS as FIXTURE_PRODUCTS_ALL,
  FIXTURE_STAMPS,
  genuineTree,
  honestMatrix,
} from "./fixtures/tree-fixture.js";

const GATE = join(INSTALLER_ROOT, "scripts", "readiness-gate.mjs");
const MATRIX_PATH = join(INSTALLER_ROOT, "docs", "flash-matrix.json");

function runGateCli(args: string[]): { code: number; stdout: string; stderr: string } {
  try {
    // process.execPath is the node binary running this test; `node` is not on
    // PATH in this repo's environment (see the dispatch packet).
    const stdout = execFileSync(process.execPath, [GATE, ...args], { encoding: "utf8", stdio: "pipe" });
    return { code: 0, stdout, stderr: "" };
  } catch (err) {
    const e = err as { status?: number; stdout?: string; stderr?: string };
    return { code: e.status ?? -1, stdout: String(e.stdout ?? ""), stderr: String(e.stderr ?? "") };
  }
}

function withTempMatrix(mutate: (matrix: Record<string, unknown>) => void): {
  path: string;
  cleanup: () => void;
} {
  const dir = mkdtempSync(join(tmpdir(), "gt-gate-"));
  const matrix = JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as Record<string, unknown>;
  mutate(matrix);
  const path = join(dir, "matrix.json");
  writeFileSync(path, JSON.stringify(matrix, null, 2));
  return { path, cleanup: () => rmSync(dir, { recursive: true, force: true }) };
}

function currentMatrix(): Record<string, unknown> {
  return JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as Record<string, unknown>;
}

test("READINESS-GATE: (a) one command, one exit code, summary ⇔ exit equivalence (live tree)", () => {
  const { code, stdout } = runGateCli(["--json"]);
  const payload = JSON.parse(stdout) as {
    gate: string;
    exitCode: number;
    clauses: { id: string; ok: boolean }[];
  };
  // The printed gate word, the reported exitCode, and the real process exit
  // code must all agree — no DEC-ARCH-027 divergence.
  assert.equal(code, payload.exitCode);
  assert.equal(payload.gate, code === 0 ? "PASS" : code === 1 ? "FAIL" : "ERROR");
  // And the word ⇔ every clause: PASS iff all clauses ok.
  assert.equal(payload.gate === "PASS", payload.clauses.every((c) => c.ok));
});

test("READINESS-GATE: (a) the human summary carries the same verdict word as --json", () => {
  const json = runGateCli(["--json"]);
  const human = runGateCli([]);
  const payload = JSON.parse(json.stdout) as { gate: string };
  assert.match(human.stdout, new RegExp(`READINESS-GATE: ${payload.gate} \\(exit ${String(json.code)}\\)`));
  assert.equal(human.code, json.code);
});

test("READINESS-GATE: the live tree PASSES (advertised ⟺ packed and fresh after CHANNEL-COMPLETE)", () => {
  const { code, stdout } = runGateCli([]);
  assert.equal(code, 0, stdout);
  assert.match(stdout, /READINESS-GATE: PASS/);
});

test("READINESS-GATE: (c) PASSES on a synthetic all-current matrix (non-vacuity)", () => {
  // The gate is not trivially red: an explicitly all-current matrix passes.
  const matrix = currentMatrix();
  const result = evaluateGate(matrix, { allowedProducts: ["tokay", "akita", "komodo", "rango"] });
  assert.equal(result.pass, true);
  assert.ok(result.clauses.every((c) => c.ok));
});

test("READINESS-GATE: (b)+(c) FAILS on a stale matrix, PASSES once the stamp is made current", () => {
  // Reconstruct the pre-repack TOKAY state: manifest says July, pointer says
  // September. This is the DEC-ARCH-025 failure mode on the flash path.
  const stale = withTempMatrix((matrix) => {
    const devices = matrix.devices as { product: string; packed: boolean; currentStamp: string; channels: { sourceStamp: string }[] }[];
    const tokay = devices.find((d) => d.product === "tokay");
    assert.ok(tokay);
    assert.equal(tokay.packed, true);
    tokay.currentStamp = "tokay-20260928-084839";
    for (const channel of tokay.channels) channel.sourceStamp = "tokay-20260725-102506";
  });
  try {
    const failed = runGateCli(["--matrix=" + stale.path]);
    assert.equal(failed.code, 1, failed.stdout);
    assert.match(failed.stdout, /channel-freshness/);
    assert.match(failed.stdout, /tokay-20260725-102506/);
    assert.match(failed.stdout, /READINESS-GATE: FAIL/);

    // Now make the same matrix current → PASS. Same code path, both directions.
    const current = withTempMatrix((matrix) => {
      const devices = matrix.devices as { product: string; channels: { sourceStamp: string }[] }[];
      const tokay = devices.find((d) => d.product === "tokay");
      assert.ok(tokay);
      for (const channel of tokay.channels) channel.sourceStamp = "tokay-20260928-084839";
    });
    try {
      const passed = runGateCli(["--matrix=" + current.path]);
      assert.equal(passed.code, 0, passed.stdout);
      assert.match(passed.stdout, /READINESS-GATE: PASS/);
    } finally {
      current.cleanup();
    }
  } finally {
    stale.cleanup();
  }
});

test("READINESS-GATE: (d) a MISSING channel independently fails", () => {
  const fixture = withTempMatrix((matrix) => {
    const devices = matrix.devices as { product: string }[];
    matrix.devices = devices.filter((d) => d.product !== "akita");
  });
  try {
    const { code, stdout } = runGateCli(["--matrix=" + fixture.path]);
    assert.equal(code, 1);
    assert.match(stdout, /advertised-equals-packed/);
    assert.match(stdout, /akita/);
  } finally {
    fixture.cleanup();
  }
});

test("READINESS-GATE: (d) a STALE channel independently fails (isolated from other clauses)", () => {
  const fixture = withTempMatrix((matrix) => {
    const devices = matrix.devices as { product: string; packed: boolean; currentStamp: string; channels: { sourceStamp: string }[] }[];
    const rango = devices.find((d) => d.product === "rango");
    assert.ok(rango);
    for (const channel of rango.channels) channel.sourceStamp = "rango-20260725-133716";
  });
  try {
    const { code, stdout } = runGateCli(["--matrix=" + fixture.path]);
    assert.equal(code, 1);
    assert.match(stdout, /channel-freshness/);
    assert.match(stdout, /rango-20260725-133716/);
    // The other clauses still pass — this failure is isolated and attributable.
    assert.match(stdout, /\[ok\] advertised-equals-packed/);
    assert.match(stdout, /\[ok\] channel-completeness/);
  } finally {
    fixture.cleanup();
  }
});

test("READINESS-GATE: (d) a phase MISMATCH independently fails", () => {
  const fixture = withTempMatrix((matrix) => {
    const devices = matrix.devices as {
      product: string;
      channels: { artifacts: { name: string; phaseMatches: boolean }[] }[];
    }[];
    const rango = devices.find((d) => d.product === "rango");
    assert.ok(rango);
    rango.channels[0]!.artifacts[0]!.phaseMatches = false;
  });
  try {
    const { code, stdout } = runGateCli(["--matrix=" + fixture.path]);
    assert.equal(code, 1);
    assert.match(stdout, /channel-completeness/);
    assert.match(stdout, /phase or manifest mapping is inconsistent/);
  } finally {
    fixture.cleanup();
  }
});

test("READINESS-GATE: (d) an unusable/missing matrix is ERROR (exit 2), never a silent PASS", () => {
  const { code, stdout } = runGateCli(["--matrix=/nonexistent/does-not-exist.json"]);
  assert.equal(code, 2, stdout);
  assert.match(stdout, /READINESS-GATE: ERROR/);
  assert.doesNotMatch(stdout, /PASS/);
});

test("READINESS-GATE: (d) a stub channel (no artifacts) fails", () => {
  const fixture = withTempMatrix((matrix) => {
    const devices = matrix.devices as { product: string; channels: { artifacts: unknown[] }[] }[];
    const komodo = devices.find((d) => d.product === "komodo");
    assert.ok(komodo);
    komodo.channels[0]!.artifacts = [];
  });
  try {
    const { code, stdout } = runGateCli(["--matrix=" + fixture.path]);
    assert.equal(code, 1);
    assert.match(stdout, /channel-completeness/);
    assert.match(stdout, /stub/);
  } finally {
    fixture.cleanup();
  }
});

test("READINESS-GATE: (e) the gate reads the same source the copy does (matrix + status.json)", () => {
  // The gate consumes docs/flash-matrix.json, which is generated from the
  // packer + schema + shipped channels; the copy's claim discipline consumes
  // the gate's verdict. Prove the matrix the gate reads is the GENERATED one
  // (re-derivable), so gate and copy cannot diverge.
  const committed = currentMatrix();
  const derived = buildMatrix({
    generatedAt: committed.generatedAt as string,
    generationCommand: "node scripts/gen-flash-matrix.mjs",
    revision: committed.revision as string,
  });
  const { code } = runGateCli(["--json"]);
  const derivedResult = evaluateGate(derived as unknown as Record<string, unknown>);
  assert.equal(derivedResult.pass, code === 0);
  // status.json is a gate input via the matrix's honesty flags.
  assert.equal(existsSync(join(INSTALLER_ROOT, "status.json")), true);
  const status = JSON.parse(readFileSync(join(INSTALLER_ROOT, "status.json"), "utf8")) as {
    flashCapability: { liveFlashClaimed: boolean };
  };
  assert.equal(status.flashCapability.liveFlashClaimed, false);
});

test("READINESS-GATE: --verdict-out writes the linter transport { gate: PASS|FAIL }", () => {
  const dir = mkdtempSync(join(tmpdir(), "gt-verdict-"));
  const out = join(dir, "verdict.json");
  try {
    const { code } = runGateCli(["--verdict-out=" + out]);
    assert.ok(existsSync(out), "verdict file must be written");
    const verdict = JSON.parse(readFileSync(out, "utf8")) as { gate: string };
    assert.equal(verdict.gate, code === 0 ? "PASS" : "FAIL");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("READINESS-GATE: a FAIL verdict file is what the claims linter would refuse on", () => {
  // The linter treats any non-PASS verdict as NOT-ready (fail closed). Prove
  // the gate can emit FAIL so the copy is blocked when readiness is not met.
  const fixture = withTempMatrix((matrix) => {
    const devices = matrix.devices as { product: string; packed: boolean; channels: { sourceStamp: string }[] }[];
    const tokay = devices.find((d) => d.product === "tokay");
    assert.ok(tokay);
    tokay.channels[0]!.sourceStamp = "tokay-20260725-102506";
  });
  const dir = mkdtempSync(join(tmpdir(), "gt-verdict-fail-"));
  const out = join(dir, "verdict.json");
  try {
    const { code } = runGateCli(["--matrix=" + fixture.path, "--verdict-out=" + out]);
    assert.equal(code, 1);
    const verdict = JSON.parse(readFileSync(out, "utf8")) as { gate: string; failedClauses: string[] };
    assert.equal(verdict.gate, "FAIL");
    assert.ok(verdict.failedClauses.includes("channel-freshness"));
  } finally {
    fixture.cleanup();
    rmSync(dir, { recursive: true, force: true });
  }
});

/* ===========================================================================
 * T-WEBINSTALL-READINESS-GATE-TREE-BINDING — the gate is bound to the TREE.
 *
 * Before this revision the gate read exactly ONE file (`docs/flash-matrix.json`)
 * and never opened `channels/`, `releases/desktop-flash/` or `status.json` at
 * gate time. A tree with NO channels at all gated PASS because the matrix
 * *claimed* `packed=4`. `docs/flash-matrix.json` is now a convenience
 * projection; when it disagrees with the filesystem, the tree wins and the gate
 * FAILS.
 *
 * Every test below drives the REAL CLI over a throwaway tree in os.tmpdir()
 * (fixtures/tree-fixture.ts). They are PERMANENT: reverting the fix (reading
 * the matrix alone) makes (a), (b) and (d) pass again, so every one of them
 * fails and catches the revert.
 * ======================================================================== */

const FIXTURE_PRODUCTS = FIXTURE_PRODUCTS_ALL;

/**
 * Run the gate CLI against a fixture tree, in env-driven mode (no flags): the
 * drill is measurable with the SAME zero-flag invocation an operator uses.
 * `GUARDTALK_INSTALLER_ROOT` / `GUARDTALK_RELEASES_DIR` are test-only.
 */
function runFixtureGate(
  root: string,
  releasesDir: string,
  extraArgs: string[] = [],
): { code: number; stdout: string; payload: GatePayload | null } {
  const env = {
    ...process.env,
    GUARDTALK_INSTALLER_ROOT: root,
    GUARDTALK_RELEASES_DIR: releasesDir,
  };
  // Point the gate at the FIXTURE's own matrix. Passing --matrix explicitly is
  // deliberate: the test must not silently fall back to the real repo's
  // docs/flash-matrix.json, whose products the fixture tree does not contain.
  const args = ["--json", `--matrix=${join(root, "docs", "flash-matrix.json")}`, ...extraArgs];
  let code = 0;
  let stdout = "";
  try {
    stdout = execFileSync(process.execPath, [GATE, ...args], {
      encoding: "utf8",
      stdio: "pipe",
      env,
    });
  } catch (err) {
    const e = err as { status?: number; stdout?: string };
    code = e.status ?? -1;
    stdout = String(e.stdout ?? "");
  }
  let payload: GatePayload | null = null;
  try {
    payload = JSON.parse(stdout) as GatePayload;
  } catch {
    payload = null;
  }
  return { code, stdout, payload };
}

interface GatePayload {
  gate: string;
  exitCode: number;
  clauses: { id: string; ok: boolean; detail: string }[];
}

/**
 * THE invariant for every tree-binding test: the printed summary word and the
 * real process exit code agree with each other AND with the clause set. A drill
 * that fails for an incidental reason (or a gate that prints PASS while
 * exiting non-zero) cannot pass this helper.
 */
function assertSummaryIsExit(observed: { code: number; payload: GatePayload | null }, label: string): GatePayload {
  const payload = observed.payload;
  assert.ok(payload !== null, `${label}: gate printed no --json payload`);
  assert.equal(observed.code, payload.exitCode, `${label}: real exit code != reported exitCode`);
  const word = observed.code === 0 ? "PASS" : observed.code === 1 ? "FAIL" : "ERROR";
  assert.equal(payload.gate, word, `${label}: printed word != exit code`);
  assert.equal(
    payload.gate === "PASS",
    payload.clauses.every((c) => c.ok),
    `${label}: printed PASS must be equivalent to every clause ok`,
  );
  return payload;
}

function failingIds(payload: GatePayload): string[] {
  return payload.clauses.filter((c) => !c.ok).map((c) => c.id);
}

test("READINESS-GATE/TREE: (e) a GENUINE tree PASSES, and (a) deleting channels/ makes it FAIL", () => {
  // Non-vacuity BOTH ways on the SAME fixture builder: the genuine tree passes,
  // and the only change is the deletion of channels/ (the tree-bound fact).
  const genuine = genuineTree(FIXTURE_PRODUCTS);
  try {
    const passed = runFixtureGate(genuine.root, genuine.releasesDir);
    const payload = assertSummaryIsExit(passed, "(e) genuine tree");
    assert.equal(passed.code, 0, `genuine tree must PASS:\n${passed.stdout}`);
    assert.equal(payload.gate, "PASS");
    // The tree clauses must be the reason, not an accident.
    for (const id of [
      "channels-on-disk",
      "latest-pointer-on-disk",
      "packed-count-reconciled",
      "matrix-matches-disk",
      "tree-freshness",
      "trust-anchor",
    ]) {
      const c = payload.clauses.find((clause) => clause.id === id);
      assert.ok(c, `genuine tree must expose the ${id} clause`);
      assert.equal(c.ok, true, `genuine tree: ${id} must be ok — ${c.detail}`);
    }

    // (a) Delete channels/ ENTIRELY. Every claim in the matrix is unchanged —
    // it still says packed=2 — but there is nothing on disk to flash.
    for (const product of FIXTURE_PRODUCTS) genuine.writer.dropChannel(product);
    const failed = runFixtureGate(genuine.root, genuine.releasesDir);
    const failPayload = assertSummaryIsExit(failed, "(a) channels/ deleted");
    assert.equal(failed.code, 1, `channels/ deleted must FAIL, not PASS:\n${failed.stdout}`);
    assert.equal(failPayload.gate, "FAIL");
    const ids = failingIds(failPayload);
    assert.ok(ids.includes("channels-on-disk"), `expected channels-on-disk to fail, got ${ids.join(", ")}`);
    assert.ok(ids.includes("matrix-matches-disk"), `expected matrix-matches-disk to fail, got ${ids.join(", ")}`);
    // REVERT-ONLY SAFETY: the pre-fix gate passed every MATRIX-ONLY clause. This
    // asserts the failure is attributable to the TREE, not to a broken matrix.
    const matrixOnly = [
      "matrix-present",
      "advertised-equals-packed",
      "channel-completeness",
      "current-stamp-resolvable",
    ];
    for (const id of matrixOnly) {
      const c = failPayload.clauses.find((clause) => clause.id === id);
      assert.equal(c?.ok, true, `${id} must still pass — the matrix did not change`);
    }
  } finally {
    genuine.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (b) a <product>-latest repointed to a STALE stamp makes the gate FAIL", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    const passed = runFixtureGate(tree.root, tree.releasesDir);
    assert.equal(passed.code, 0, `genuine tree must PASS first:\n${passed.stdout}`);

    // Repoint ONLY tokay at an older stamp that genuinely exists on disk. The
    // matrix is NOT touched: it still claims tokay is current. The gate must
    // re-resolve the pointer from the filesystem and call the channel STALE.
    const stale = FIXTURE_STAMPS.stale.tokay;
    tree.writer.stamp("tokay", stale);
    tree.writer.pointer("tokay", stale);

    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(b) stale pointer");
    assert.equal(failed.code, 1, `stale pointer must FAIL, not PASS:\n${failed.stdout}`);
    const ids = failingIds(payload);
    assert.ok(ids.includes("latest-pointer-on-disk"), `expected latest-pointer-on-disk to fail, got ${ids.join(", ")}`);
    assert.ok(ids.includes("tree-freshness"), `expected tree-freshness to fail, got ${ids.join(", ")}`);
    const pointer = payload.clauses.find((c) => c.id === "latest-pointer-on-disk");
    assert.match(pointer?.detail ?? "", /tokay/);
    assert.match(pointer?.detail ?? "", /STALE/);
    assert.match(pointer?.detail ?? "", new RegExp(stale));
    // The DISK-derived freshness clause names the drift too (channel is packed
    // from the current stamp, the pointer now names the old one).
    const freshness = payload.clauses.find((c) => c.id === "channel-freshness");
    assert.equal(freshness?.ok, false, "disk-derived freshness must catch the repointed pointer");

    // Restore the pointer AND refresh the matrix's projection (the extra stamp
    // dir is still on disk, so an honest matrix lists it) → PASS again.
    tree.writer.pointer("tokay", FIXTURE_STAMPS.current.tokay);
    const refreshed = honestMatrix(FIXTURE_PRODUCTS);
    const tokayDevice = refreshed.devices.find((d) => d.product === "tokay");
    assert.ok(tokayDevice);
    tokayDevice.stampsOnDisk = [FIXTURE_STAMPS.stale.tokay, FIXTURE_STAMPS.current.tokay];
    tree.writer.matrix(refreshed);
    tree.writer.writeAnchors(tree.writer.pins(FIXTURE_PRODUCTS));
    const restored = runFixtureGate(tree.root, tree.releasesDir);
    assert.equal(restored.code, 0, `restoring the pointer must PASS again:\n${restored.stdout}`);
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (b2) a DANGLING <product>-latest is not freshness — FAIL", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    // Point tokay at a stamp name that is not a directory on disk.
    tree.writer.pointer("tokay", "tokay-20990101-000000");
    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(b2) dangling pointer");
    assert.equal(failed.code, 1, `dangling pointer must FAIL:\n${failed.stdout}`);
    assert.ok(failingIds(payload).includes("latest-pointer-on-disk"));
    // A symlink whose target does not exist is reported as ABSENT (the pointer
    // names nothing). It is never silently treated as a current stamp.
    assert.match(
      payload.clauses.find((c) => c.id === "latest-pointer-on-disk")?.detail ?? "",
      /is absent|does not resolve|not a stamp dir/,
    );
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (b3) a channel MISSING one required file is not packed — FAIL", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    // avb_pkmd.bin is the thing that makes the flashed build bootable under our
    // key; a channel without it can flash nothing that boots.
    tree.writer.dropChannelFile("akita", "avb_pkmd.bin");
    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(b3) missing avb_pkmd.bin");
    assert.equal(failed.code, 1, `missing required file must FAIL:\n${failed.stdout}`);
    const clause = payload.clauses.find((c) => c.id === "channels-on-disk");
    assert.equal(clause?.ok, false);
    assert.match(clause?.detail ?? "", /akita: missing avb_pkmd\.bin/);
    // The count is reconciled against what is really flashable: 1, not 2.
    const count = payload.clauses.find((c) => c.id === "packed-count-reconciled");
    assert.equal(count?.ok, false);
    assert.match(count?.detail ?? "", /packedChannels=4.*3 packed/);
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (c) a matrix that CONTRADICTS the tree makes the gate FAIL", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    // The matrix claims tokay's channel was packed from the CURRENT stamp; the
    // manifest.json on disk says it was packed from the July stamp. Everything
    // else is genuine — only the projection lies. The tree wins.
    const stale = FIXTURE_STAMPS.stale.tokay;
    tree.writer.stamp("tokay", stale);
    tree.writer.channel("tokay", stale);
    // (pointer still current, matrix still claims current)

    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(c) contradicting matrix");
    assert.equal(failed.code, 1, `contradicting manifest must FAIL:\n${failed.stdout}`);
    const drift = payload.clauses.find((c) => c.id === "matrix-matches-disk");
    assert.equal(drift?.ok, false);
    assert.match(drift?.detail ?? "", /tokay: matrix sourceStamp .* != manifest\.json on disk/);
    // And the disk-derived freshness clause independently names the staleness.
    assert.equal(payload.clauses.find((c) => c.id === "channel-freshness")?.ok, false);
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (c2) a matrix whose stampsOnDisk / currentStamp are FABRICATED fails", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    // The matrix invents a stamp that does not exist and points the product at
    // it. The tree is untouched and genuine.
    const lying = honestMatrix(FIXTURE_PRODUCTS, {
      tokay: "tokay-20990101-000000",
      akita: FIXTURE_STAMPS.current.akita,
    });
    tree.writer.matrix(lying);
    tree.writer.writeAnchors(tree.writer.pins(FIXTURE_PRODUCTS));
    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(c2) fabricated stamps");
    assert.equal(failed.code, 1, `fabricated matrix must FAIL:\n${failed.stdout}`);
    const ids = failingIds(payload);
    assert.ok(ids.includes("tree-freshness"), `expected tree-freshness, got ${ids.join(", ")}`);
    assert.match(
      payload.clauses.find((c) => c.id === "tree-freshness")?.detail ?? "",
      /tokay: matrix currentStamp tokay-20990101-000000 vs disk pointer tokay-20260928-084839/,
    );
    // The matrix's own freshness claim is also false (no such stamp on disk).
    assert.equal(payload.clauses.find((c) => c.id === "channel-freshness")?.ok, false);
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (d) counts.packedChannels inflated to 99 makes the gate FAIL", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    const passed = runFixtureGate(tree.root, tree.releasesDir);
    assert.equal(passed.code, 0, `genuine tree must PASS first:\n${passed.stdout}`);

    // Inflate ONLY the count. Every other claim is true; the number is not.
    const inflated = honestMatrix(FIXTURE_PRODUCTS);
    inflated.counts.packedChannels = 99;
    tree.writer.matrix(inflated);
    tree.writer.writeAnchors(tree.writer.pins(FIXTURE_PRODUCTS));

    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(d) packed=99");
    assert.equal(failed.code, 1, `inflated count must FAIL:\n${failed.stdout}`);
    const count = payload.clauses.find((c) => c.id === "packed-count-reconciled");
    assert.equal(count?.ok, false);
    assert.match(count?.detail ?? "", /packedChannels=99 but 4 packed channel\(s\) are verified on disk/);
    // REVERT-ONLY SAFETY: nothing else fails — the inflate is isolated.
    assert.deepEqual(failingIds(payload), ["packed-count-reconciled"]);
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: (d2) counts.packedChannels UNDER-counted also FAILS (not only inflation)", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    const under = honestMatrix(FIXTURE_PRODUCTS);
    under.counts.packedChannels = 0;
    tree.writer.matrix(under);
    tree.writer.writeAnchors(tree.writer.pins(FIXTURE_PRODUCTS));
    const failed = runFixtureGate(tree.root, tree.releasesDir);
    const payload = assertSummaryIsExit(failed, "(d2) packed=0");
    assert.equal(failed.code, 1, `under-counted must FAIL:\n${failed.stdout}`);
    assert.ok(failingIds(payload).includes("packed-count-reconciled"));
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: a drill root NEVER reads the real repo's matrix", () => {
  // INCIDENT 2026-10-18T12:13 (D-035). Resolving the DEFAULT matrix against the
  // gate's own install path while probing a drill root made the gate read the
  // REAL matrix and the DRILL tree at once. With no --matrix and no
  // docs/flash-matrix.json in the drill root, the gate must ERROR (exit 2),
  // never fall back to the repo's document and print PASS.
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    rmSync(join(tree.root, "docs", "flash-matrix.json"), { force: true });
    const env = {
      ...process.env,
      GUARDTALK_INSTALLER_ROOT: tree.root,
      GUARDTALK_RELEASES_DIR: tree.releasesDir,
    };
    let code = 0;
    let stdout = "";
    try {
      stdout = execFileSync(process.execPath, [GATE, "--json"], { encoding: "utf8", stdio: "pipe", env });
    } catch (err) {
      const e = err as { status?: number; stdout?: string };
      code = e.status ?? -1;
      stdout = String(e.stdout ?? "");
    }
    assert.equal(code, 2, `a drill root without a matrix must be ERROR, not PASS:\n${stdout}`);
    const payload = JSON.parse(stdout) as GatePayload & { matrix: string };
    assert.equal(payload.gate, "ERROR");
    assert.ok(
      payload.matrix.startsWith(tree.root),
      `the gate must read the DRILL root's matrix, not ${payload.matrix}`,
    );
  } finally {
    tree.writer.cleanup();
  }
});

test("READINESS-GATE/TREE: the gate is SIDE-EFFECT FREE and cwd-independent", () => {
  // The gate must not write by default, and must work from any cwd — the tree
  // it probes is derived from the installer root, not from process.cwd().
  const before = JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as Record<string, unknown>;
  const cwd = process.cwd();
  const elsewhere = mkdtempSync(join(tmpdir(), "gt-cwd-"));
  try {
    process.chdir(elsewhere);
    const run = runGateCli([]);
    assert.equal(run.code, 0, `gate must pass when run from another cwd:\n${run.stdout}`);
  } finally {
    process.chdir(cwd);
    rmSync(elsewhere, { recursive: true, force: true });
  }
  const after = JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as Record<string, unknown>;
  assert.deepEqual(after, before, "the gate must not rewrite docs/flash-matrix.json");
  assert.equal(existsSync(join(INSTALLER_ROOT, "docs", "verdict.json")), false);
});
