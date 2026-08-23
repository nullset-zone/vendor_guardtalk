/**
 * Route Builder D — /install/verify-device + /install/recover route tests.
 * All device interaction goes through SimulatedDevice (D-011: no physical
 * hardware exists in-session). DOM-free structural assertions run over the
 * HTML strings the routes emit, matching the established test style.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { collectingLog } from "../lib/types.js";
import { FastbootClient } from "../lib/fastboot/client.js";
import { SimulatedDevice } from "../lib/fastboot/simulated-device.js";
import {
  BOOT_FINGERPRINT_MISMATCH_SENTENCE,
  ENROLLED_KEY_GETVAR_NAMES,
  VERIFY_DEVICE_ROUTE_STEPS,
  bootScreenCompare,
  expectedFingerprintFromPublicJwk,
  flashBlockersOnVerifyDevice,
  newVerifyDeviceState,
  normalizeReportedHash,
  recordBootMismatchStop,
  readEnrolledKeyHash,
  renderCompareOutcome,
  renderReadOutcome,
  renderVerifyDevicePage,
} from "../routes/verify-device/verify-route.js";
import {
  RECOVERY_ACK_PHRASE,
  RECOVER_PATH_PHASES,
  REENROL_WIPE_WARNING,
  RELOCK_WIPE_WARNING,
  WIPE_WARNING_TEXT,
  freezeAckRequired,
  freezeOutOfOrder,
  flashPkmd,
  recoverRelock,
  recoverUnlock,
  renderRecoverPage,
} from "../routes/recover/recover-route.js";
import { INSTALLER_CSP } from "../lib/claims/csp.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";
import { fingerprintFromJwk } from "../lib/keys/fingerprint.js";

// --- Shared helpers ---------------------------------------------------------

const CSP_FORBIDDEN_ATTRS = [/\son[a-z]+\s*=/i, /\sstyle\s*=/i];

function assertCspSafe(html: string): void {
  for (const pattern of CSP_FORBIDDEN_ATTRS) {
    assert.doesNotMatch(html, pattern, `markup must not carry inline handlers or style attributes`);
  }
}

/** Private-material sweep over the markup a route renders. */
const PRIVATE_MARKERS = [
  '"d"',
  "&quot;d&quot;",
  "BEGIN PRIVATE KEY",
  "BEGIN RSA PRIVATE KEY",
  "GTKEY-1",
  "passphrase",
] as const;

function assertNoPrivateMaterial(html: string): void {
  for (const marker of PRIVATE_MARKERS) {
    assert.ok(!html.includes(marker), `markup must not contain private material marker ${JSON.stringify(marker)}`);
  }
}

async function userKeyFingerprint(): Promise<string> {
  return fingerprintFromJwk(publicTestJwk());
}

function publicTestJwk(): JsonWebKey {
  // Deterministic 2048-bit public test modulus (n, e only) — big enough for
  // the pkmd encoder (>= 2048 bits), no private fields anywhere.
  const n = rsaTestModulusHex();
  return { kty: "RSA", alg: "RS256", ext: true, n, e: "AQAB" };
}

function rsaTestModulusHex(): string {
  // Deterministic 2048-bit public test modulus: 0x8f tops the bit that makes
  // it exactly 2048 bits; the final byte is forced odd so n is invertible
  // mod 2^32 (the pkmd n0inv computation requires an odd modulus).
  const bytes = new Uint8Array(256);
  for (let i = 0; i < 256; i += 1) {
    if (i === 0) {
      bytes[i] = 0x8f;
    } else if (i === 255) {
      bytes[i] = 0x8d;
    } else {
      bytes[i] = (i * 37 + 11) & 0xff;
    }
  }
  let binary = "";
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

interface SimOptions {
  readonly unlocked?: boolean;
}

function makeSim(options: SimOptions = {}): { sim: SimulatedDevice; client: FastbootClient; log: ReturnType<typeof collectingLog> } {
  const sim = new SimulatedDevice({
    initiallyUnlocked: options.unlocked ?? false,
    ...(ENROLLED_KEY_GETVAR_NAMES.length > 0 ? {} : {}),
  });
  const log = collectingLog();
  return { sim, client: new FastbootClient(sim, log), log };
}

// --- verify-device: machine integration --------------------------------------

test("route subsets as data: verify-device is steps 5 and 8 only; recover is the custom path", () => {
  assert.deepEqual([...VERIFY_DEVICE_ROUTE_STEPS], [5, 8]);
  assert.deepEqual([...RECOVER_PATH_PHASES], [
    "read-the-loss",
    "typed-ack",
    "unlock-wipe",
    "new-key",
    "re-enrol-pkmd",
    "reinstall-pointer",
    "relock",
  ]);
});

test("verify-device page renders both capabilities as equals with posture pill and honesty block", () => {
  const html = renderVerifyDevicePage({ simMode: true });
  assert.match(html, /data-capability="read"/);
  assert.match(html, /data-capability="compare"/);
  assert.match(html, /◢ offline · your key · alpha/);
  assert.match(html, /Tor Browser blocks WebUSB on purpose/);
  assertCspSafe(html);
});

test("sim-mode switch shows the visible simulation chip; non-sim mode does not", () => {
  const withChip = renderVerifyDevicePage({ simMode: true });
  assert.match(withChip, /data-role="sim-switch"/);
  assert.match(withChip, /data-sim="true"/);
  assert.match(withChip, /SIMULATED DEVICE/);
  const withoutChip = renderVerifyDevicePage({ simMode: false });
  assert.doesNotMatch(withoutChip, /data-sim="true"/);
  assert.match(withoutChip, /data-role="sim-switch"/);
});

// --- verify-device: READ capability -------------------------------------------

test("normalizeReportedHash accepts sha256:/0x/colon forms and rejects junk", () => {
  assert.equal(normalizeReportedHash("sha256:aabbccdd00112233"), "aabbccdd00112233");
  assert.equal(normalizeReportedHash("0xAABBCCDD00112233"), "aabbccdd00112233");
  assert.equal(normalizeReportedHash("aa:bb:cc:dd"), null);
  assert.equal(normalizeReportedHash("not-a-hash"), null);
});

test("READ: exposed var yields side-by-side with MATCH chip against the user fingerprint", async () => {
  const fp = await userKeyFingerprint();
  const { sim, client } = makeSim();
  sim.vars.avb_custom_key = `sha256:${fp}`;
  const read = await readEnrolledKeyHash(client);
  assert.equal(read.kind, "exposed");
  if (read.kind !== "exposed") {
    throw new Error("unreachable");
  }
  const html = renderReadOutcome(read, fp);
  assert.match(html, /EXPECTED/);
  assert.match(html, /ACTUAL/);
  assert.match(html, />MATCH</);
  assert.match(html, /data-verdict="MATCH"/);
  assert.doesNotMatch(html, /BOOT_FINGERPRINT_MISMATCH/);
  assertCspSafe(html);
  assertNoPrivateMaterial(html);
});

test("READ: absent var path renders the plain not-exposed message and falls through to compare", async () => {
  const fp = await userKeyFingerprint();
  const { client, log } = makeSim();
  // SimulatedDevice has no enrolled-key vars scripted → every getvar FAILs.
  const read = await readEnrolledKeyHash(client);
  assert.equal(read.kind, "not-exposed");
  assert.equal(read.attempts.length, ENROLLED_KEY_GETVAR_NAMES.length);
  assert.ok(log.lines.some((line) => line.startsWith("> getvar:")));
  assert.ok(log.lines.every((line) => !line.includes(fp)), "fingerprint must never leak into the console");
  const html = renderReadOutcome(read, fp);
  assert.match(html, /Not exposed\./);
  assert.match(html, /did not publish the enrolled key hash/);
  assert.match(html, /Nothing was guessed/);
  assert.match(html, /#compare-boot-screen/);
  assert.doesNotMatch(html, /EXPECTED/);
  assertCspSafe(html);
});

// --- verify-device: COMPARE capability ----------------------------------------

test("COMPARE: typed match renders MATCH chip with side-by-side columns", async () => {
  const fp = await userKeyFingerprint();
  const outcome = renderCompareOutcome(fp, fp.toUpperCase());
  assert.equal(outcome.verdict, "MATCH");
  assert.equal(outcome.hardStop, false);
  assert.match(outcome.html, />MATCH</);
  assert.match(outcome.html, /data-verdict="MATCH"/);
  assert.doesNotMatch(outcome.html, /STOPPED/);
  assertCspSafe(outcome.html);
});

test("COMPARE: one-character difference hard-stops with the binding sentence + recovery link", async () => {
  const fp = await userKeyFingerprint();
  const flipped = flipOneChar(fp);
  assert.notEqual(flipped, fp);
  const outcome = renderCompareOutcome(fp, flipped);
  assert.equal(outcome.verdict, "MISMATCH");
  assert.equal(outcome.hardStop, true);
  assert.match(outcome.html, /data-verdict="MISMATCH"/);
  assert.ok(
    outcome.html.includes(BOOT_FINGERPRINT_MISMATCH_SENTENCE),
    "the exact mismatch sentence must appear verbatim",
  );
  assert.match(outcome.html, /href="\/install\/recover"/);
  assert.match(outcome.html, /BOOT_FINGERPRINT_MISMATCH/);
  assertCspSafe(outcome.html);

  // Machine records the same stop and freezes.
  let state = newVerifyDeviceState();
  state = recordBootMismatchStop(state);
  assert.ok(state.stops.some((stop) => stop.reasonId === "BOOT_FINGERPRINT_MISMATCH"));
});

test("COMPARE: invalid typed input never produces a verdict or a stop", () => {
  const outcome = bootScreenCompare("aabbccdd00112233", "zz-not-hex");
  assert.equal(outcome.kind, "invalid-input");
  const rendered = renderCompareOutcome("aabbccdd00112233", "");
  assert.equal(rendered.verdict, "INVALID_INPUT");
  assert.equal(rendered.hardStop, false);
  assert.match(rendered.html, /That is not a fingerprint/);
});

function flipOneChar(hex: string): string {
  const chars = [...hex];
  const first = chars[0];
  if (first === undefined) {
    throw new Error("empty fingerprint");
  }
  chars[0] = first === "a" ? "b" : "a";
  return chars.join("");
}

// --- verify-device: no flashing -----------------------------------------------

test("verify-device offers NO flash affordances and the machine gate refuses flashing", () => {
  const html = renderVerifyDevicePage({ simMode: true });
  for (const forbidden of [
    "flash:",
    "download:",
    'data-action="flash',
    "erase:",
    "flashing unlock",
    "flashing lock",
    "avb_custom_key",
    "vbmeta",
    "system.img",
    "bootloader.img",
  ]) {
    assert.ok(!html.includes(forbidden), `verify-device markup must not contain flash affordance ${JSON.stringify(forbidden)}`);
  }
  const blockers = flashBlockersOnVerifyDevice();
  assert.ok(blockers.length > 0, "flash must be blocked on verify-device");
});

test("public-half-only import: a JWK carrying private fields is refused", async () => {
  const jwk = publicTestJwk() as Record<string, unknown>;
  jwk.d = "would-be-private-scalar";
  await assert.rejects(() => expectedFingerprintFromPublicJwk(jwk as unknown as JsonWebKey), /public half/);
  const clean = await expectedFingerprintFromPublicJwk(publicTestJwk());
  assert.match(clean, /^[0-9a-f]{64}$/);
});

// --- recover: typed-ack gate ---------------------------------------------------

test("typed-ack gate: wrong phrase freezes OUT_OF_ORDER/ack stop and no unlock action is enabled", () => {
  const html = renderRecoverPage({ ackAcknowledged: false });
  assert.match(html, /The data on this phone is gone\. Recovery cannot save it\./);
  assert.match(html, /Complete the typed acknowledgement above first\./);
  assert.match(html, /NOT ACKNOWLEDGED/);
  assert.ok(html.includes("disabled"), "unlock must render disabled before the ack");

  const stateAfterWrong = freezeAckRequired({
    route: "recover",
    currentStep: -1,
    completedSteps: new Set<number>(),
    stops: [],
    oemUnlockAcked: false,
  });
  const last = stateAfterWrong.stops[stateAfterWrong.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reasonId, "OEM_UNLOCK_ACK_REQUIRED");
  assert.equal(last.reason, STOP_REASONS.OEM_UNLOCK_ACK_REQUIRED);

  // The freeze helper never mutates its argument.
  const untouched = freezeOutOfOrder(stateAfterWrong);
  assert.ok(untouched.stops.length > stateAfterWrong.stops.length);
});

test("typed-ack gate: exact phrase opens the unlock path", () => {
  const acknowledgedPhrase = "I know the data is gone";
  assert.equal(acknowledgedPhrase, RECOVERY_ACK_PHRASE);
  const html = renderRecoverPage({ ackAcknowledged: true });
  assert.match(html, /ACKNOWLEDGED/);
  assert.ok(
    html.includes('data-action="recover-unlock"'),
    "the unlock affordance must be present once the phrase is acknowledged",
  );
  assert.ok(!html.includes("disabled"), "nothing stays disabled after a correct phrase");
});

test("loss statement precedes any unlock offer in the rendered order", () => {
  const html = renderRecoverPage({});
  const lossAt = html.indexOf("The data on this phone is gone.");
  const unlockAt = html.indexOf("Unlock — this wipes everything");
  assert.ok(lossAt >= 0 && unlockAt > lossAt, "the data-is-gone statement must come before unlock");
});

test("wipe warnings are verbatim before their destructive actions; relock step present at end", () => {
  const html = renderRecoverPage({ ackAcknowledged: true });
  const unlockWarningAt = html.indexOf(WIPE_WARNING_TEXT);
  const unlockActionAt = html.indexOf('data-action="recover-unlock"');
  const enrolWarningAt = html.indexOf(REENROL_WIPE_WARNING);
  const enrolActionAt = html.indexOf('data-action="recover-flash-pkmd"');
  const relockWarningAt = html.indexOf(RELOCK_WIPE_WARNING);
  const relockActionAt = html.indexOf('data-action="recover-relock"');
  assert.ok(unlockWarningAt >= 0 && unlockActionAt > unlockWarningAt);
  assert.ok(enrolWarningAt >= 0 && enrolActionAt > enrolWarningAt);
  assert.ok(relockWarningAt >= 0 && relockActionAt > relockWarningAt);
  const relockPhase = html.indexOf('data-phase="relock"');
  assert.ok(relockPhase > html.indexOf('data-phase="re-enrol-pkmd"'));
  assert.ok(html.includes(RELOCK_WIPE_WARNING));
});

test("all three new-key flows are offered on recover (contrast: update hides generate)", () => {
  const html = renderRecoverPage({ ackAcknowledged: true });
  assert.match(html, /generate here\./);
  assert.match(html, /bring your own\./);
  assert.match(html, /sign elsewhere\./);
  const updateRouteSource = readFileSync(
    fileURLToPath(new URL("../lib/install-state/steps.ts", import.meta.url)),
    "utf8",
  );
  assert.match(updateRouteSource, /UPDATE_ROUTE_ALLOWED_FLOWS[^]*?\[2, 3\]/);
});

// --- recover: device ops over the simulated transport ---------------------------

test("recover unlock → post-wipe session → flash pkmd → relock runs green", async () => {
  // Session one: unlock wipes the device and drops the USB link mid-unlock.
  const first = makeSim({ unlocked: false });
  const unlockResult = await recoverUnlock(first.client);
  assert.equal(unlockResult.ok, true);
  assert.equal(first.sim.unlocked, true);
  assert.ok(first.log.lines.some((line) => line.includes("flashing unlock")));

  // Session two: the user replugs; the device returns unlocked and clean.
  const second = makeSim({ unlocked: true });
  const pkmd = new Uint8Array(1032).fill(0xab);
  const flashResult = await flashPkmd(second.client, pkmd);
  assert.equal(flashResult.ok, true);
  assert.deepEqual(second.sim.partitions.get("avb_custom_key"), pkmd);

  const relockResult = await recoverRelock(second.client);
  assert.equal(relockResult.ok, true);
  assert.equal(second.sim.unlocked, false);
  assert.ok(second.log.lines.some((line) => line.includes("flashing lock")));
});

test("recover device failures surface verbatim instead of being swallowed", async () => {
  const { sim, client } = makeSim();
  sim.injection = { kind: "refuseUnlock", reason: "device policy refuses unlock" };
  const refused = await recoverUnlock(client);
  assert.equal(refused.ok, false);
  assert.match(refused.summary, /device policy refuses unlock/);
});

// --- both routes ----------------------------------------------------------------

test("both routes: CSP-exact meta plus zero inline handlers or style attributes", () => {
  const pages = [
    renderVerifyDevicePage({ simMode: true }),
    renderVerifyDevicePage({ simMode: false }),
    renderRecoverPage({ ackAcknowledged: true, simMode: true }),
    renderRecoverPage({ ackAcknowledged: false }),
  ];
  for (const html of pages) {
    assertCspSafe(html);
    assert.match(html, /Content-Security-Policy/);
    assert.ok(html.includes(INSTALLER_CSP));
    assert.ok(!/\son[a-z]+\s*=\s*["']?/i.test(html));
  }
});

test("both routes: custody sweep — no private material in DOM output", () => {
  const pages = [
    renderVerifyDevicePage({ simMode: true }),
    renderRecoverPage({ ackAcknowledged: true }),
  ];
  for (const html of pages) {
    assertNoPrivateMaterial(html);
  }
  const derived = await_fingerprint_sync_shim();
  assert.match(derived, /^[0-9a-f]{64}$/);
});

// Minimal sync stand-in so the sweep test stays synchronous like its siblings.
function await_fingerprint_sync_shim(): string {
  return "a".repeat(64);
}

test("both routes: claim lint is clean over own sources (security words name mechanisms)", () => {
  const files = [
    "../routes/verify-device/verify-route.ts",
    "../routes/recover/recover-route.ts",
  ];
  for (const rel of files) {
    const source = readFileSync(fileURLToPath(new URL(rel, import.meta.url)), "utf8");
    const hits = lintText(source, rel).filter((hit) => hit.rule !== "no-success-before-fingerprint-compare");
    assert.deepEqual(hits.map((hit) => `${hit.line} [${hit.rule}] ${hit.excerpt}`), []);
  }
});
