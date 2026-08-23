/**
 * /install late-steps (5–9) + flash-runner tests — headless, SimulatedDevice
 * only (D-011). Covers the dispatch test matrix: happy path with verbatim
 * command order, PRODUCT_MISMATCH before any write, Nth-flash failure stop,
 * lock refusal, boot-fingerprint mismatch hard stop, canFlash defence,
 * sim-mode labelling, CSP sweep and custody sweep over emitted strings.
 */
import assert from "node:assert/strict";
import { before, test } from "node:test";
import { signedAnchor } from "./fixtures/signed-anchor.js";
import { SimulatedDevice } from "../lib/fastboot/simulated-device.js";
import { FastbootClient, FastbootError } from "../lib/fastboot/client.js";
import { collectingLog } from "../lib/types.js";
import {
  initialInstallState,
  reduce,
  STOP_REASONS,
} from "../lib/install-state/index.js";
import type { InstallState } from "../lib/install-state/machine.js";
import {
  BOOT_MISMATCH_SENTENCE,
  BOOT_STATE_LIMIT_SENTENCE,
  CLOSING_SENTENCE,
  CUSTODY_LIMIT_SENTENCE,
  GATEWAY_LIMIT_SENTENCE,
  checkProduct,
  consoleKind,
  connectStepHtml,
  fingerprintsMatch,
  flashStepHtml,
  isSimMode,
  keepKeyStepHtml,
  lockStepHtml,
  lockStateFromVar,
  simCautionChip,
  simBannerHtml,
  TARGET_PRODUCTS,
  usbAvailable,
  verifyStepHtml,
} from "../routes/install/late-steps.js";
import { runFlashPlan } from "../routes/install/flash-runner.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { INSTALLER_CSP } from "../lib/claims/csp.js";

const ENROLLED = "a".repeat(64);

/** Claim-lint sweep over every emitted late-step string (own-files rule). */
test("claim lint: late-step markup carries no forbidden phrases", () => {
  const samples = [
    connectStepHtml({ sim: true, usbPresent: false, oemUnlockAcked: true }),
    connectStepHtml({ sim: false, usbPresent: true, check: { expected: "tokay", actual: "tokay", match: true }, lockState: "unlocked", oemUnlockAcked: false }),
    flashStepHtml({ sim: true, started: true, currentPartition: "system", donePartitions: [] }),
    lockStepHtml({ sim: true, locked: true }),
    verifyStepHtml({ sim: true, enrolledFingerprint: ENROLLED, outcome: "match" }),
    keepKeyStepHtml(true),
    simBannerHtml(true),
  ];
  for (const html of samples) {
    const hits = lintText(html, "late-steps-emitted");
    assert.deepEqual(hits.map((h) => `${h.rule}: ${h.excerpt}`), [], "claim lint must be clean");
  }
});

// --- helpers -----------------------------------------------------------------

function bytes(length: number, pattern: number): Uint8Array {
  const out = new Uint8Array(length);
  out.fill(pattern % 256);
  return out;
}

let ANCHOR: { pkmd: Uint8Array; vbmeta: Uint8Array };

before(async () => {
  ANCHOR = await signedAnchor();
});

function pkmdBytes(): Uint8Array {
  return ANCHOR.pkmd;
}

/**
 * State advanced to step `step` on the install route with all prior steps
 * legitimately completed. Steps 5–7 need their extra gates: the OEM-unlock
 * ack before device-matched, then flash-step-done and lock-confirmed.
 */
function stateAt(step: number): InstallState {
  let state = initialInstallState("install");
  const advanceActions: Parameters<typeof reduce>[1][] = [
    { type: "acknowledge-intro" },
    { type: "files-picked" },
    { type: "release-verified" },
    { type: "key-flow-chosen", keyFlow: 1 },
    { type: "fingerprint-recorded" },
    { type: "vbmeta-signed" },
  ];
  for (const action of advanceActions) {
    if (state.currentStep >= step) {
      break;
    }
    state = reduce(state, action);
  }
  if (step > 5) {
    state = reduce(reduce(state, { type: "oem-unlock-acked" }), { type: "device-matched", product: "tokay" });
  }
  if (step > 6) {
    state = reduce(state, { type: "flash-step-done" });
  }
  if (step > 7) {
    state = reduce(state, { type: "lock-confirmed" });
  }
  return state;
}

interface GateOverrides {
  hashesMatch?: boolean;
  signatureValid?: boolean;
  product?: string;
  targetProduct?: string;
  signedWithUserKey?: boolean;
}

function gateInputs(state: InstallState, overrides: GateOverrides = {}) {
  return {
    state,
    release: {
      hashesMatch: overrides.hashesMatch ?? true,
      signatureValid: overrides.signatureValid ?? true,
    },
    device: {
      product: overrides.product ?? "tokay",
      releaseTargetProduct: overrides.targetProduct ?? "tokay",
    },
    vbmeta: { signedWithUserKey: overrides.signedWithUserKey ?? true },
  };
}

function fullPlan(): {
  avbCustomKey: Uint8Array;
  firmware: { partition: string; data: Uint8Array }[];
  os: { partition: string; data: Uint8Array }[];
  vbmeta: { partition: string; data: Uint8Array }[];
} {
  return {
    avbCustomKey: pkmdBytes(),
    firmware: [
      { partition: "bootloader", data: bytes(2048, 1) },
      { partition: "radio", data: bytes(1024, 2) },
      { partition: "boot", data: bytes(4096, 3) },
      { partition: "vendor_boot", data: bytes(2048, 4) },
      { partition: "dtbo", data: bytes(1024, 5) },
    ],
    os: [
      { partition: "system", data: bytes(8192, 6) },
      { partition: "system_ext", data: bytes(4096, 7) },
      { partition: "product", data: bytes(2048, 8) },
      { partition: "vendor", data: bytes(2048, 9) },
    ],
    vbmeta: [{ partition: "vbmeta", data: ANCHOR.vbmeta }],
  };
}

function flashCommands(log: readonly string[]): readonly string[] {
  return log.filter((line) => line.startsWith("> flash:"));
}

// --- step 5 ------------------------------------------------------------------

test("sim mode: ?sim=1 and env switch both activate; production default stays real WebUSB", () => {
  assert.equal(isSimMode("?sim=1"), true);
  assert.equal(isSimMode(""), false);
  assert.equal(isSimMode("", "1"), true);
  assert.equal(isSimMode(new URLSearchParams("sim=1")), true);
});

test("usb detect: absent navigator.usb routes to the CLI export panel as first-class", () => {
  const html = connectStepHtml({ sim: false, usbPresent: false, oemUnlockAcked: false });
  assert.match(html, /cli-export-panel/);
  assert.match(html, /first-class path/);
  assert.match(html, /data-action="pair-device" disabled/u);
});

test("usb detect: present navigator.usb keeps pairing enabled", () => {
  assert.equal(usbAvailable({ usb: {} }), true);
  assert.equal(usbAvailable({}), false);
  assert.equal(usbAvailable(null), false);
  const html = connectStepHtml({ sim: false, usbPresent: true, oemUnlockAcked: false });
  assert.match(html, /data-action="pair-device"/);
  assert.doesNotMatch(html, /data-action="pair-device" disabled/u);
});

test("product gate: mismatch stops BEFORE any write — zero flash commands in transcript", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { product: "panther" },
  });
  const log = collectingLog();
  const client = new FastbootClient(device, log);

  const actual = await client.getvar("product");
  const check = checkProduct(TARGET_PRODUCTS[0] as string, actual);
  assert.equal(check.match, false);

  // The route records a product-mismatch stop; no runFlashPlan call happens.
  let stopped = stateAt(5);
  if (!check.match) {
    stopped = reduce(stopped, { type: "stop", step: 5, condition: "product-mismatch" });
  }
  assert.ok(stopped.stops.some((s) => s.reasonId === "PRODUCT_MISMATCH"));

  const html = connectStepHtml({
    sim: false,
    usbPresent: true,
    check,
    lockState: lockStateFromVar("no"),
    oemUnlockAcked: false,
    stopped: STOP_REASONS.PRODUCT_MISMATCH,
  });
  assert.match(html, /PRODUCT MISMATCH/);
  assert.match(html, new RegExp(`${STOP_REASONS.PRODUCT_MISMATCH.replace(/[—;]/gu, "\\$&")}`));

  // Defence in depth: even a wrongly-issued runFlashPlan throws before any write.
  await assert.rejects(
    () =>
      runFlashPlan({
        transport: device,
        consoleSink: log,
        plan: fullPlan(),
        gate: gateInputs(stateAt(5), { product: "panther", targetProduct: "tokay" }),
      }),
    (err: unknown) => err instanceof Error && err.message.includes("flash gate unsatisfied"),
  );
  assert.equal(flashCommands(log.lines).length, 0, "no flash command may reach the device");
  assert.equal(device.partitions.size, 0, "nothing may be written");
});

test("lock-state readback maps bootloader variable onto chip states", () => {
  assert.equal(lockStateFromVar("yes"), "locked");
  assert.equal(lockStateFromVar("no"), "unlocked");
  assert.equal(lockStateFromVar("weird"), "unknown");
  assert.match(connectStepHtml({ sim: false, usbPresent: true, oemUnlockAcked: false }), /data-warning="data-wipe"/);
  assert.match(connectStepHtml({ sim: false, usbPresent: true, oemUnlockAcked: false }), /oem-unlock-ack/);
});

test("second data-wipe warning renders with explicit acknowledgement checkbox", () => {
  const html = connectStepHtml({ sim: false, usbPresent: true, oemUnlockAcked: false });
  assert.match(html, /unlocking wipes ALL data/iu);
});

// --- step 6 ------------------------------------------------------------------

test("happy path: full 5→9 sequence reaches step 9; transcript has every command verbatim in order", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { product: "tokay", bootloader: "tokay-1.0-00000000", "max-download-size": "268435456" },
  });
  const log = collectingLog();
  let state = stateAt(5);
  const client = new FastbootClient(device, log);

  // Step 5: pair → read product → read lock state.
  const product = await client.getvar("product");
  const check = checkProduct(TARGET_PRODUCTS[0] as string, product);
  assert.equal(check.match, true);
  // Lock-state read: the canonical first-install story is an OEM-UNLOCKED
  // device (unlock happened at step 5; locking comes at step 7), so the
  // lock-state classifier reports unlocked and the UI shows the caution chip.
  await client.getvar("bootloader");
  const lockState = lockStateFromVar(device.unlocked ? "no" : "yes");
  assert.equal(lockState, "unlocked");
  state = reduce(reduce(state, { type: "oem-unlock-acked" }), { type: "device-matched", product });

  // Step 6: gated flash of the whole plan (avb_custom_key first, vbmeta last).
  const results = await runFlashPlan({
    transport: device,
    consoleSink: log,
    plan: fullPlan(),
    gate: gateInputs(state),
    onProgress: () => {},
  });
  assert.deepEqual(results[0]?.partition, "avb_custom_key");
  assert.deepEqual(results[results.length - 1]?.partition, "vbmeta");
  state = reduce(state, { type: "flash-step-done" });

  // Step 7: lock with on-device confirmation.
  await client.flashingLock();
  assert.equal(device.unlocked, false);
  state = reduce(state, { type: "lock-confirmed" });

  // Step 8: user TYPES the boot-screen fingerprint; match advances.
  state = reduce(state, { type: "boot-fingerprint-typed", fingerprint: ENROLLED });
  assert.equal(state.currentStep, 9);

  // Step 9: closing screen carries the exact sentence.
  const step9 = keepKeyStepHtml(false);
  assert.ok(step9.includes(CLOSING_SENTENCE), "closing sentence must appear exactly");

  // Verbatim command transcript for the whole sequence, in order.
  const commands = log.lines.filter((line) => line.startsWith("> "));
  assert.deepEqual(commands, [
    "> getvar:product",
    "> getvar:bootloader",
    // H1: budget fetched from the device before the first write.
    "> getvar:max-download-size",
    "> download:00000408",
    "> [1032 byte payload]",
    "> flash:avb_custom_key",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:bootloader",
    "> download:00000400",
    "> [1024 byte payload]",
    "> flash:radio",
    "> download:00001000",
    "> [4096 byte payload]",
    "> flash:boot",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:vendor_boot",
    "> download:00000400",
    "> [1024 byte payload]",
    "> flash:dtbo",
    "> download:00002000",
    "> [8192 byte payload]",
    "> flash:system",
    "> download:00001000",
    "> [4096 byte payload]",
    "> flash:system_ext",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:product",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:vendor",
    "> download:00000780",
    "> [1920 byte payload]",
    "> flash:vbmeta",
    "> flashing lock",
  ]);
  // Every response verbatim too; the step-5 UI renders the unlocked state as
  // an explicit caution chip — locking comes at step 7.
  assert.ok(log.lines.filter((line) => line.startsWith("< ")).length > 0);
  const connectHtml = connectStepHtml({
    sim: false,
    usbPresent: true,
    check,
    lockState: "unlocked",
    oemUnlockAcked: true,
  });
  assert.match(connectHtml, /BOOTLOADER UNLOCKED/);
  assert.match(connectHtml, /chip-caution/);
});

test("happy path flash: exact ordered transcript incl. payload lines; progress events monotonic per partition", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true, vars: { "max-download-size": "268435456" } });
  const log = collectingLog();
  const plan = fullPlan();
  let lastBytes = -1;

  const results = await runFlashPlan({
    transport: device,
    consoleSink: log,
    plan,
    gate: gateInputs(stateAt(6)),
    onProgress: (p) => {
      assert.ok(p.bytesSent >= lastBytes, "progress must be monotonic");
      lastBytes = p.bytesSent;
    },
  });

  assert.deepEqual(
    results.map((r) => r.partition),
    [
      "avb_custom_key",
      "bootloader",
      "radio",
      "boot",
      "vendor_boot",
      "dtbo",
      "system",
      "system_ext",
      "product",
      "vendor",
      "vbmeta",
    ],
  );
  assert.deepEqual(results[results.length - 1]?.phase, "vbmeta");

  const commands = log.lines.filter((line) => line.startsWith("> "));
  assert.deepEqual(
    commands,
    [
      // H1: budget fetched from the device before the first write.
      "> getvar:max-download-size",
      "> download:00000408",
    "> [1032 byte payload]",
    "> flash:avb_custom_key",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:bootloader",
    "> download:00000400",
    "> [1024 byte payload]",
    "> flash:radio",
    "> download:00001000",
    "> [4096 byte payload]",
    "> flash:boot",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:vendor_boot",
    "> download:00000400",
    "> [1024 byte payload]",
    "> flash:dtbo",
    "> download:00002000",
    "> [8192 byte payload]",
    "> flash:system",
    "> download:00001000",
    "> [4096 byte payload]",
    "> flash:system_ext",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:product",
    "> download:00000800",
    "> [2048 byte payload]",
    "> flash:vendor",
    "> download:00000780",
    "> [1920 byte payload]",
    "> flash:vbmeta",
  ]);
  assert.ok(log.lines.includes("< OKAY268435456"), "H1 budget getvar is in the transcript");
  // Each partition write produces download-OKAY + flash-OKAY (2 per partition).
  const okayCount = log.lines.filter((l) => l === "< OKAY").length;
  assert.ok(okayCount >= results.length * 2, `expected >= ${String(results.length * 2)} OKAY lines, got ${String(okayCount)}`);
});

test("Nth-flash failure ⇒ FASTBOOT_FAIL stop, later partitions untouched, verbatim reason in transcript", async () => {
  const reason = "partition table does not support vendor_boot";
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    injection: { kind: "failNthFlash", nth: 5, reason },
  });
  const log = collectingLog();
  const plan = fullPlan();

  await assert.rejects(
    () =>
      runFlashPlan({
        transport: device,
        consoleSink: log,
        plan,
        gate: gateInputs(stateAt(6)),
      }),
    (err: unknown) => {
      assert.ok(err instanceof FastbootError);
      assert.equal((err as FastbootError).reason, reason);
      return true;
    },
  );

  assert.ok(log.lines.includes(`< FAIL${reason}`), "verbatim FAIL must be in the console transcript");
  // The failing partition's flash COMMAND still appears in the verbatim
  // transcript (FastbootClient logs every command before reading the
  // response) — but the device answered FAIL, so NOTHING was written.
  const flashed = flashCommands(log.lines);
  assert.deepEqual(flashed, [
    "> flash:avb_custom_key",
    "> flash:bootloader",
    "> flash:radio",
    "> flash:boot",
    "> flash:vendor_boot",
  ]);
  const failIndex = log.lines.indexOf(`> flash:vendor_boot`);
  assert.equal(log.lines.indexOf(`< FAIL${reason}`) > failIndex, true);
  assert.ok(
    log.lines.slice(failIndex + 1).every((line) => !line.startsWith("> flash:") || line === "> flash:vendor_boot"),
    "no further commands after FAIL",
  );
  for (const untouched of ["vendor_boot", "dtbo", "system", "system_ext", "product", "vendor", "vbmeta"]) {
    assert.equal(device.partitions.has(untouched), false, `${untouched} must stay untouched`);
  }
  assert.ok(log.lines.every((line) => !line.startsWith("> erase")), "no further commands after FAIL");
});

// --- step 7 ------------------------------------------------------------------

test("lock refused simulation ⇒ stop at step 7 with the bootloader's verbatim reason", async () => {
  const refusal = "flashing lock is not allowed by carrier";
  const device = new SimulatedDevice({
    injection: { kind: "refuseLock", reason: refusal },
  });
  device.unlocked = true;
  const log = collectingLog();
  const client = new FastbootClient(device, log);

  await assert.rejects(() => client.flashingLock(), (err: unknown) => {
    assert.ok(err instanceof FastbootError);
    assert.equal((err as FastbootError).reason, refusal);
    return true;
  });

  const state = reduce(stateAt(7), { type: "stop", step: 7, condition: "fastboot-fail" });
  assert.ok(state.stops.some((s) => s.reasonId === "FASTBOOT_FAIL"));
  assert.ok(state.stops.some((s) => s.step === 7));

  const html = lockStepHtml({ sim: false, refused: refusal, locked: false });
  assert.match(html, /LOCK REFUSED/);
  assert.match(html, new RegExp(refusal.replace(/[^\w\s]/gu, "\\$&")));
  assert.match(html, /every boot/iu);
});

// --- step 8 ------------------------------------------------------------------

test("typed fingerprint match advances; single-char difference hard-stops with the exact sentence", () => {
  assert.equal(fingerprintsMatch(`  ${ENROLLED}  `, ENROLLED), true, "whitespace strip then exact compare");
  const oneCharOff = `${ENROLLED.slice(0, -1)}b`;
  assert.notEqual(oneCharOff, ENROLLED);
  assert.equal(fingerprintsMatch(oneCharOff, ENROLLED), false);

  const matched = verifyStepHtml({ sim: false, enrolledFingerprint: ENROLLED, outcome: "match" });
  assert.match(matched, /VERIFIED · YOUR KEY/);
  assert.match(matched, /guardtalk\.io\/system\/gateway/u);

  const mismatched = verifyStepHtml({ sim: false, enrolledFingerprint: ENROLLED, outcome: "mismatch" });
  assert.match(mismatched, /BOOT_FINGERPRINT_MISMATCH/);
  assert.ok(mismatched.includes(BOOT_MISMATCH_SENTENCE), "exact sentence must appear verbatim");
  assert.match(mismatched, /\/install\/recover/u);

  const state = reduce(reduce(stateAt(8), { type: "stop", step: 8, condition: "boot-fingerprint-mismatch" }), { type: "keep-key-acknowledged" });
  assert.equal(
    state.stops.some((s) => s.reasonId === "BOOT_FINGERPRINT_MISMATCH"),
    true,
  );
  assert.equal(state.currentStep, 8, "hard stop freezes at step 8");
  // The reducer itself proves the frozen state: keep-key-acknowledged is the
  // step-9 action, and a hard stop makes ANY advance action a no-op.
});

/** Drive the machine legitimately through steps 6 and 7 completions. */
function stateAfterLock(): InstallState {
  let state = stateAt(6);
  state = reduce(state, { type: "flash-step-done" });
  state = reduce(state, { type: "lock-confirmed" });
  return state;
}

test("step 8 driven through flash+lock: typed match advances to 9; mismatch freezes at 8", () => {
  const ready = stateAfterLock();
  assert.equal(ready.currentStep, 8, "flash-step-done then lock-confirmed land at step 8");

  // Route-layer contract: the page compares typed vs enrolled (whitespace-
  // stripped) BEFORE dispatching — match ⇒ advance action; mismatch ⇒ the
  // boot-fingerprint-mismatch condition stop. The pure reducer never sees
  // raw text comparisons.
  const matched = reduce(ready, { type: "boot-fingerprint-typed", fingerprint: ENROLLED });
  assert.equal(matched.currentStep, 9);

  const oneCharOff = `${ENROLLED.slice(0, -1)}b`;
  assert.notEqual(oneCharOff, ENROLLED);
  assert.equal(fingerprintsMatch(oneCharOff, ENROLLED), false);
  const mismatched = reduce(ready, { type: "stop", step: 8, condition: "boot-fingerprint-mismatch" });
  assert.equal(mismatched.currentStep, 8);
  assert.equal(mismatched.stops.some((s) => s.reasonId === "BOOT_FINGERPRINT_MISMATCH"), true);

  // Hard stop freezes ALL advancement: the step-9 action becomes a no-op.
  const frozen = reduce(mismatched, { type: "keep-key-acknowledged" });
  assert.equal(frozen.currentStep, 8);
});

// --- flash-runner gate defence ------------------------------------------------

test("canFlash defence: runFlashPlan throws BEFORE issuing anything when gates unsatisfied", async () => {
  const cases: GateOverrides[] = [
    { hashesMatch: false },
    { signatureValid: false },
    { product: "panther", targetProduct: "tokay" },
    { signedWithUserKey: false },
  ];
  for (const overrides of cases) {
    const device = new SimulatedDevice({ initiallyUnlocked: true });
    const log = collectingLog();
    await assert.rejects(
      () =>
        runFlashPlan({
          transport: device,
          consoleSink: log,
          plan: fullPlan(),
          gate: gateInputs(stateAt(6), overrides),
        }),
      (err: unknown) => err instanceof Error && /flash requires release verification/iu.test(err.message),
    );
    assert.equal(log.lines.length, 0, "no command may be logged or sent when the gate fails");
    assert.equal(device.partitions.size, 0);
  }

  const incomplete = new SimulatedDevice({ initiallyUnlocked: true });
  const incompleteLog = collectingLog();
  await assert.rejects(
    () =>
      runFlashPlan({
        transport: incomplete,
        consoleSink: incompleteLog,
        plan: fullPlan(),
        gate: gateInputs(initialInstallState("install")),
      }),
    (err: unknown) => err instanceof Error && err.message.length > 0,
  );
  assert.equal(incompleteLog.lines.length, 0);
});

// --- step 6 UI ----------------------------------------------------------------

test("flash step UI: fail banner keeps verbatim output visible; console kinds classify lines", () => {
  const failed = flashStepHtml({
    sim: true,
    started: true,
    failed: "partition table does not support vendor_boot",
    donePartitions: ["avb_custom_key", "bootloader"],
    currentPartition: "system",
  });
  assert.match(failed, /FASTBOOT_FAIL/);
  assert.match(failed, /partition table does not support vendor_boot/);
  assert.match(failed, /done: avb_custom_key/);
  assert.equal(consoleKind("> flash:boot"), "cmd");
  assert.equal(consoleKind("< FAILnope"), "fail");
  assert.equal(consoleKind("< INFOwriting"), "info");
  assert.equal(consoleKind("< OKAY"), "ok");
  assert.equal(consoleKind("< DATA00000408"), "device");
});

// --- sim labelling ------------------------------------------------------------

test("sim-mode labelling is visible in emitted markup (D-011)", () => {
  const chip = simCautionChip();
  assert.match(chip, /SIMULATION/);
  assert.match(chip, /chip-caution/);
  const banner = simBannerHtml(true);
  assert.match(banner, /simulated device/iu);
  assert.match(banner, /not evidence of a real flash/);
  assert.equal(simBannerHtml(false), "");
  for (const html of [
    connectStepHtml({ sim: true, usbPresent: true, oemUnlockAcked: false }),
    flashStepHtml({ sim: true, started: false, donePartitions: [] }),
    lockStepHtml({ sim: true, locked: false }),
    verifyStepHtml({ sim: true, enrolledFingerprint: ENROLLED }),
    keepKeyStepHtml(true),
  ]) {
    assert.match(html, /SIMULATION/, "every late step must label a simulated session");
    assert.doesNotMatch(html.replace(simBannerHtml(true), ""), /sim-banner/);
  }
});

// --- CSP sweep ----------------------------------------------------------------

test("CSP sweep: emitted strings carry zero inline handlers/styles/scripts and route CSP equals D-006", () => {
  const samples = [
    connectStepHtml({ sim: true, usbPresent: true, check: { expected: "tokay", actual: "tokay", match: true }, lockState: "locked", oemUnlockAcked: false }),
    flashStepHtml({ sim: true, started: true, currentPartition: "system", donePartitions: [] }),
    lockStepHtml({ sim: false, locked: true }),
    verifyStepHtml({ sim: false, enrolledFingerprint: ENROLLED, outcome: "match" }),
    verifyStepHtml({ sim: false, enrolledFingerprint: ENROLLED, outcome: "mismatch" }),
    keepKeyStepHtml(),
    simBannerHtml(true),
  ];
  const forbidden = [/on\w+\s*=/iu, /javascript:/iu, /<script/iu, /style\s*=\s*["']/iu, /srcdoc/iu, /eval\(/iu, /http:\/\/(?!localhost)/iu];
  for (const html of samples) {
    for (const pattern of forbidden) {
      assert.equal(pattern.test(html), false, `forbidden CSP pattern ${String(pattern)} found`);
    }
  }
  assert.equal(INSTALLER_CSP, "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'");
});

// --- custody sweep ------------------------------------------------------------

test("custody sweep: no key material, passphrase or secret sinks in emitted strings", () => {
  const samples = [
    connectStepHtml({ sim: true, usbPresent: true, oemUnlockAcked: false }),
    flashStepHtml({ sim: true, started: false, donePartitions: [] }),
    lockStepHtml({ sim: false, locked: true }),
    verifyStepHtml({ sim: false, enrolledFingerprint: ENROLLED }),
    keepKeyStepHtml(false),
  ];
  const sinkPatterns = [
    /localStorage|sessionStorage|indexedDB/iu,
    /\bfetch\s*\(|XMLHttpRequest|WebSocket/iu,
    /document\.cookie/iu,
    /BEGIN (RSA )?PRIVATE KEY/iu,
    /passphrase\s*[=:]/iu,
    /private[_ ]?key\s*(bytes|material|hex)\s*[=:]/iu,
  ];
  for (const html of samples) {
    for (const pattern of sinkPatterns) {
      assert.equal(pattern.test(html), false, `custody sink ${String(pattern)} leaked into markup`);
    }
  }
  // Step 9 talks about custody honestly without ever naming storage APIs.
  const step9 = keepKeyStepHtml();
  assert.match(step9, /non-extractable WebCrypto handle/iu);
  assert.match(step9, /encrypted PEM/iu);
});

// --- Phase-5 E1: H1 runner wiring + F5/F6 threat-model links ---------------------

test("user-anchor: unsigned vbmeta is refused before any write", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "268435456" },
  });
  const log = collectingLog();
  const plan = fullPlan();
  plan.vbmeta = [{ partition: "vbmeta", data: bytes(64, 0x11) }];
  await assert.rejects(
    () =>
      runFlashPlan({
        transport: device,
        consoleSink: log,
        plan,
        gate: gateInputs(stateAt(6)),
      }),
    (err: unknown) => err instanceof Error && /magic|anchor|parse failed|vbmeta/i.test(err.message),
  );
  assert.equal(flashCommands(log.lines).length, 0);
  assert.equal(device.partitions.size, 0);
});

test("H1: runFlashPlan fetches getvar:max-download-size once, before the first write", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "268435456" },
  });
  const log = collectingLog();
  const plan = fullPlan();

  const results = await runFlashPlan({
    transport: device,
    consoleSink: log,
    plan,
    gate: gateInputs(stateAt(6)),
  });

  assert.equal(results.length, plan.firmware.length + plan.os.length + plan.vbmeta.length + 1);
  assert.equal(
    log.lines.filter((line) => line === "> getvar:max-download-size").length,
    1,
    "budget is fetched exactly once",
  );
  assert.ok(
    log.lines.indexOf("> getvar:max-download-size") <
      log.lines.findIndex((line) => line.startsWith("> download:")),
    "budget precedes every transfer",
  );
  assert.ok(log.lines.includes("< OKAY268435456"));
});

test("H1: missing max-download-size variable stops the whole plan before ANY transfer", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  device.forgetVar("max-download-size");
  const log = collectingLog();

  await assert.rejects(
    () =>
      runFlashPlan({
        transport: device,
        consoleSink: log,
        plan: fullPlan(),
        gate: gateInputs(stateAt(6)),
      }),
    (err: unknown) => {
      assert.ok(err instanceof Error);
      assert.match(err.message, /max-download-size/iu);
      assert.match(err.message, /flow stopped before any transfer/iu);
      return true;
    },
  );
  assert.equal(device.partitions.size, 0, "nothing may be written");
  assert.equal(log.lines.filter((l) => l.startsWith("> download:")).length, 0);
  assert.equal(log.lines.filter((l) => l.startsWith("> flash:")).length, 0);
});

test("H1: garbage max-download-size value stops the plan with the device's verbatim value", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "banana" },
  });
  const log = collectingLog();
  await assert.rejects(
    () =>
      runFlashPlan({
        transport: device,
        consoleSink: log,
        plan: fullPlan(),
        gate: gateInputs(stateAt(6)),
      }),
    (err: unknown) => {
      assert.ok(err instanceof Error);
      assert.match(err.message, /"banana"/u);
      return true;
    },
  );
  assert.equal(device.partitions.size, 0);
});

test("H2: runFlashPlan streams a sparse OS image within a small device budget", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "4096" },
  });
  const log = collectingLog();

  const blockA = bytes(4096, 0x11);
  const fill = new Uint8Array(4096);
  const fillView = new DataView(fill.buffer);
  for (let off = 0; off + 4 <= fill.length; off += 4) {
    fillView.setUint32(off, 0xefefefef);
  }
  const blockB = bytes(4096, 0x22);
  const sparse = buildSparseImage(4096, [
    { type: 0xcac1, data: blockA },
    { type: 0xcac2, blocks: 1, fillWord: 0xefefefef },
    { type: 0xcac1, data: blockB },
  ]);

  const results = await runFlashPlan({
    transport: device,
    consoleSink: log,
    plan: { os: [{ partition: "system", data: sparse }], firmware: [], vbmeta: [] },
    gate: gateInputs(stateAt(6)),
  });
  assert.deepEqual(results.map((r) => r.partition), ["system"]);

  const stored = device.partitions.get("system");
  assert.ok(stored !== undefined);
  assert.equal(stored.length, 12288);
  assert.deepEqual([...stored.slice(0, 4096)], [...blockA]);
  assert.deepEqual([...stored.slice(4096, 8192)], [...fill]);
  assert.deepEqual([...stored.slice(8192)], [...blockB]);
  assert.deepEqual(
    log.lines.filter((l) => l.startsWith("> flash:")),
    ["> flash:system", "> flash:system", "> flash:system"],
    "each budget-sized sparse unit is a download+flash pair on the same partition",
  );
});

/** Sparse-image builder mirroring test/fastboot.test.ts (kept route-local). */
function buildSparseImage(blockSize: number, specs: { type: number; blocks?: number; fillWord?: number; data?: Uint8Array }[]): Uint8Array {
  const chunkHeaderSize = 12;
  const parts: Uint8Array[] = [];
  for (const spec of specs) {
    const dataSize = spec.type === 0xcac2 ? 4 : spec.data !== undefined ? spec.data.length : 0;
    const header = new Uint8Array(chunkHeaderSize);
    const view = new DataView(header.buffer);
    view.setUint16(0, spec.type);
    view.setUint32(4, dataSize);
    if (spec.blocks !== undefined) {
      view.setUint32(8, spec.blocks);
    }
    parts.push(header);
    if (spec.data !== undefined) {
      parts.push(spec.data);
    }
    if (spec.type === 0xcac2 && spec.fillWord !== undefined) {
      const word = new Uint8Array(4);
      new DataView(word.buffer).setUint32(0, spec.fillWord);
      parts.push(word);
    }
  }
  const totalBlocks = specs.reduce((sum, s) => sum + (s.blocks ?? (s.data?.length ?? 0) / blockSize), 0);
  const header = new Uint8Array(28);
  const view = new DataView(header.buffer);
  view.setUint32(0, 0xed26ff3a);
  view.setUint16(4, 1);
  view.setUint16(6, 0);
  view.setUint16(8, 28);
  view.setUint16(10, chunkHeaderSize);
  view.setUint32(12, blockSize);
  view.setUint32(16, totalBlocks);
  view.setUint32(20, specs.length);
  const total = parts.reduce((n, p) => n + p.length, header.length);
  const out = new Uint8Array(total);
  out.set(header, 0);
  let off = header.length;
  for (const part of parts) {
    out.set(part, off);
    off += part.length;
  }
  return out;
}

test("F5: step-7 boot-state explainer carries its limit with a /threat-model link", () => {
  const html = lockStepHtml({ sim: false, locked: true });
  assert.ok(html.includes(BOOT_STATE_LIMIT_SENTENCE));
  assert.match(html, /Read the threat model/u);
  assert.match(html, /href="\/threat-model"/u);
});

test("F6: step-8 Gateway handoff states the network-defence limit with a /threat-model link", () => {
  const html = verifyStepHtml({ sim: false, enrolledFingerprint: ENROLLED, outcome: "match" });
  assert.ok(html.includes(GATEWAY_LIMIT_SENTENCE));
  assert.match(html, /guardtalk\.io\/system\/gateway/u);
  assert.match(html, /href="\/threat-model"/u);
});

test("F5: step-9 custody recap carries its limit with a /threat-model link", () => {
  const html = keepKeyStepHtml(false);
  assert.ok(html.includes(CUSTODY_LIMIT_SENTENCE));
  assert.match(html, /href="\/threat-model"/u);
});
