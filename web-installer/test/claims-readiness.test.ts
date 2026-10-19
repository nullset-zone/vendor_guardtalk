/**
 * F-WEBINSTALL-FLASHALL-CLAIM-LINT — the readiness-claim family.
 *
 * Acceptance:
 *   (a) the phrase set BITES on a fixture with the gate FAIL;
 *   (b) it is SILENT when the gate PASSes (non-vacuity);
 *   (c) the existing no-boot-overclaim / radio families are UNCHANGED;
 *   (d) the suite stays green and the tested md5 is recorded.
 *
 * The verdict is the linter's ONLY suppression for this family: a whole-run
 * PASS. There is deliberately no same-line allow-list (D-016).
 */
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  lintFiles,
  lintText,
  main,
} from "../lib/claims/lint-claims.js";
import {
  deriveReadinessVerdict,
  resolveReadinessVerdict,
  verdictFromFile,
} from "../lib/claims/readiness-verdict.js";

const OVERCLAIM = fileURLToPath(new URL("./fixtures/claims/readiness-claim-overclaim.txt", import.meta.url));
const HONEST = fileURLToPath(new URL("./fixtures/claims/readiness-claim-honest.txt", import.meta.url));

const LINTER_REL = "lib/claims/lint-claims.ts";
const LINTER_PATH = fileURLToPath(new URL(`../${LINTER_REL}`, import.meta.url));

function readinessHits(hits: ReturnType<typeof lintText>): typeof hits {
  return hits.filter((hit) => hit.rule === "no-readiness-overclaim");
}

/* ------------------------------------------------------------------ *
 * (a) the phrase set bites with the gate FAIL
 * ------------------------------------------------------------------ */

test("(a) readiness phrases bite when the gate is FAIL", () => {
  const mustBite = [
    "This installer is ready to flash every available image.",
    "GuardTalkOS is production ready.",
    "The web installer is ready.",
    "The installer is ready for production.",
    "This installer is ready to ship.",
    "You can flash all images from this page.",
    "Ready to flash every available image.",
    "Every available image can now be flashed.",
    "All images are flashable.",
    "All images are ready.",
  ];
  for (const line of mustBite) {
    const hits = lintText(line, "fixture.txt");
    assert.ok(readinessHits(hits).length > 0, line);
    // Default (no verdict supplied) is FAIL-CLOSED: the family is armed.
  }
});

test("(a) an explicit FAIL verdict arms the family", () => {
  const failVerdict = resolveReadinessVerdict(
    fileURLToPath(new URL("./fixtures/claims/readiness-verdict-fail.json", import.meta.url)),
  );
  assert.equal(failVerdict.ready, false);
  const hits = lintText("This installer is ready.", "fixture.txt", { readinessReady: failVerdict.ready });
  assert.ok(readinessHits(hits).length > 0);
});

test("(a) the overclaim fixture BITES through the CLI-facing lintFiles path", () => {
  // Use an explicit FAIL verdict so the assertion does not depend on the live
  // tree's current readiness (which the Backend lane may legitimately pass).
  const failPath = fileURLToPath(new URL("./fixtures/claims/readiness-verdict-fail.json", import.meta.url));
  const verdict = verdictFromFile(failPath);
  assert.ok(
    lintFiles([OVERCLAIM], { readinessReady: verdict.ready }).some(
      (hit) => hit.rule === "no-readiness-overclaim",
    ),
  );
  assert.equal(main([`--readiness-verdict=${failPath}`, OVERCLAIM]), 1);
});

/* ------------------------------------------------------------------ *
 * (b) silent when the gate PASSes (non-vacuity)
 * ------------------------------------------------------------------ */

test("(b) the SAME phrases are silent when readinessReady is true (non-vacuity)", () => {
  // Non-vacuity: the rule is not a blanket word ban. Exactly the phrases that
  // bite under FAIL stay clean under a whole-run PASS.
  const same = [
    "This installer is ready to flash every available image.",
    "GuardTalkOS is production ready.",
    "The web installer is ready.",
  ];
  for (const line of same) {
    const armed = lintText(line, "fixture.txt");
    const passed = lintText(line, "fixture.txt", { readinessReady: true });
    assert.ok(readinessHits(armed).length > 0, `armed must bite: ${line}`);
    assert.deepEqual(readinessHits(passed), [], `passed must be silent: ${line}`);
  }
});

test("(b) an explicit PASS verdict file silences the family; FAIL does not", () => {
  const passPath = fileURLToPath(new URL("./fixtures/claims/readiness-verdict-pass.json", import.meta.url));
  const failPath = fileURLToPath(new URL("./fixtures/claims/readiness-verdict-fail.json", import.meta.url));
  const pass = verdictFromFile(passPath);
  const fail = verdictFromFile(failPath);
  assert.equal(pass.ready, true);
  assert.equal(fail.ready, false);
  assert.deepEqual(readinessHits(lintFiles([OVERCLAIM], { readinessReady: pass.ready })), []);
  assert.ok(readinessHits(lintFiles([OVERCLAIM], { readinessReady: fail.ready })).length > 0);
});

test("(b) a missing or malformed verdict file fails closed (never a silent PASS)", () => {
  const missing = verdictFromFile(fileURLToPath(new URL("./fixtures/claims/does-not-exist.json", import.meta.url)));
  assert.equal(missing.ready, false);
  const malformed = verdictFromFile(LINTER_PATH); // TypeScript source is not JSON
  assert.equal(malformed.ready, false);
});

test("(b) derivation from absent facts fails closed, never a synthesized PASS", () => {
  const verdict = deriveReadinessVerdict("/nonexistent-installer-root");
  assert.equal(verdict.ready, false);
  assert.ok(verdict.reasons.length > 0);
  assert.equal(verdict.source, "derived");
});

test("(b) derivation MIRRORS the Backend readiness-gate on the same tree", () => {
  // Acceptance (e): the gate reads the same source the copy does. Since the
  // gate has landed, derivation must AGREE with it — not fight it. We do not
  // shell out to the gate here (that is the gate's own card); we assert this
  // resolver's clause set matches the gate's stated clauses on the live tree.
  const verdict = deriveReadinessVerdict();
  const matrix = JSON.parse(
    readFileSync(fileURLToPath(new URL("../docs/flash-matrix.json", import.meta.url)), "utf8"),
  ) as {
    counts?: { advertisedNotPacked?: number };
    devices?: Array<{
      packed?: boolean;
      currentStamp?: string;
      channels?: Array<{ sourceStamp?: string }>;
    }>;
  };
  const advertisedNotPacked = matrix?.counts?.advertisedNotPacked;
  const stale = (matrix?.devices ?? []).some(
    (device) =>
      device?.packed === true &&
      Array.isArray(device.channels) &&
      device.channels.some(
        (channel) => typeof channel?.sourceStamp === "string" && channel.sourceStamp !== device.currentStamp,
      ),
  );
  const expectReady =
    typeof advertisedNotPacked === "number" && advertisedNotPacked === 0 && !stale;
  assert.equal(
    verdict.ready,
    expectReady,
    `derived readiness must equal the gate's advertised==packed+fresh verdict (reasons: ${verdict.reasons.join("; ")})`,
  );
});

test("(b) the honesty guard flags a claim that MUST block (liveFlashClaimed=true)", () => {
  // Derivation must NOT be vacuous: a live-flash claim with no hardware is the
  // overclaim and must produce NOT ready, whatever else is true.
  const tmp = mkdtempSync(join(tmpdir(), "gt-readiness-"));
  writeFileSync(join(tmp, "status.json"), JSON.stringify({ flashCapability: { liveFlashClaimed: true } }));
  const verdict = deriveReadinessVerdict(tmp);
  assert.equal(verdict.ready, false);
  assert.match(verdict.reasons.join(" "), /liveFlashClaimed=true/);
  rmSync(tmp, { recursive: true, force: true });
});

/* ------------------------------------------------------------------ *
 * (c) the existing families are unchanged
 * ------------------------------------------------------------------ */

test("(c) no-boot-overclaim family is unchanged by the readiness extension", () => {
  const bootBites = [
    "BOOT_VERIFIED=true",
    "This device is boot-verified.",
    "proven to boot",
  ];
  for (const line of bootBites) {
    assert.ok(
      lintText(line, "fixture.txt").some((hit) => hit.rule === "no-boot-overclaim"),
      line,
    );
  }
  // A disclaimer still disarms the boot family, exactly as before.
  assert.deepEqual(
    lintText("This build is not boot-verified; boot is UNVERIFIED.", "fixture.txt").filter(
      (hit) => hit.rule === "no-boot-overclaim",
    ),
    [],
  );
});

test("(c) radio family still bites and still suppresses on qualified statements", () => {
  assert.ok(
    lintText("The modem is completely removed.", "fixture.txt").some(
      (hit) => hit.rule === "no-radio-excision-overclaim",
    ),
  );
  assert.deepEqual(
    lintText("host-side userspace excised; runtime radio verdict remains FALSE", "fixture.txt").filter(
      (hit) => hit.rule === "no-radio-excision-overclaim",
    ),
    [],
  );
});

test("(c) a READINESS overclaim is not silently reclassified as another family", () => {
  const hits = lintText("This installer is ready to flash every available image.", "fixture.txt");
  assert.deepEqual(
    hits.map((hit) => hit.rule),
    ["no-readiness-overclaim"],
  );
});

test("honest alpha copy is clean with the family armed (no false positive)", () => {
  assert.deepEqual(readinessHits(lintFiles([HONEST])), []);
  assert.equal(main([HONEST]), 0);
});

/* ------------------------------------------------------------------ *
 * (d) the tested md5 is recorded
 * ------------------------------------------------------------------ */

test("(d) the tested linter revision is recorded (md5)", () => {
  const digest = createHash("md5").update(readFileSync(LINTER_PATH)).digest("hex");
  // eslint-disable-next-line no-console -- evidence line for the completion report
  process.stdout.write(`\n[lint-claims md5] ${LINTER_REL} ${digest}\n`);
  assert.equal(digest.length, 32);
});
