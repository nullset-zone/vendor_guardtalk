import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import {
  LiveExecuteHoldError,
  UsbDisconnectError,
  UsbPermissionError,
  UsbTimeoutError,
} from "../src/errors.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import {
  WIZARD_STEPS,
  WizardGateError,
  assertCanFlash,
  assertCanLockWithSafety,
  assertCanUnlock,
  canLockWithSafety,
  classifyRecoverableUsbError,
  type WizardFlags,
} from "../wizard/gating.js";
import { InstallWizard, type FlashProgress } from "../wizard/session.js";
import { BOOT_VERIFIED } from "../lib/ui/readiness.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

const HERE = dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = join(HERE, "..");
const DIST_SITE = join(PKG_ROOT, "dist", "site");

function allTrueFlags(overrides: Partial<WizardFlags> = {}): WizardFlags {
  return {
    deviceSelected: true,
    channelLoaded: true,
    connected: true,
    unlocked: true,
    planComplete: true,
    artifactsReady: true,
    dryRun: true,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// 1. 8-step wizard gating & state machine
// ---------------------------------------------------------------------------

test("QA-ADV-UI-01: WIZARD_STEPS defines exact 8-step sequence 1..8 with unique IDs", () => {
  assert.equal(WIZARD_STEPS.length, 8);
  assert.deepEqual(
    WIZARD_STEPS.map((s) => ({ number: s.number, id: s.id })),
    [
      { number: 1, id: "prerequisites" },
      { number: 2, id: "oem-unlock" },
      { number: 3, id: "connect" },
      { number: 4, id: "unlock" },
      { number: 5, id: "download" },
      { number: 6, id: "flash" },
      { number: 7, id: "lock" },
      { number: 8, id: "verify" },
    ],
  );
  for (const step of WIZARD_STEPS) {
    assert.ok(step.title.trim().length > 0, `step ${step.id} must have a non-empty title`);
  }
});

test("QA-ADV-UI-02: assertCanUnlock and assertCanFlash fail closed on missing prerequisites", () => {
  assert.throws(
    () => assertCanUnlock(allTrueFlags({ connected: false })),
    WizardGateError,
  );
  assert.throws(
    () => assertCanUnlock(allTrueFlags({ deviceSelected: false })),
    WizardGateError,
  );

  // Unlock gate must block flash even when every other flag is true.
  assert.throws(
    () => assertCanFlash(allTrueFlags({ unlocked: false })),
    (err: unknown) =>
      err instanceof WizardGateError && /unlock/i.test(err.message),
  );

  // Dry-run and artifacts gates must also block flash even when unlocked.
  assert.throws(
    () => assertCanFlash(allTrueFlags({ dryRun: false })),
    WizardGateError,
  );
  assert.throws(
    () => assertCanFlash(allTrueFlags({ artifactsReady: false })),
    WizardGateError,
  );
});

test("QA-ADV-UI-03: assertCanLockWithSafety blocks unconfirmed or unverified targets without explicit operator override", () => {
  const readyFlags = allTrueFlags();

  // Plan not complete -> blocked even with confirmation + override.
  assert.equal(
    canLockWithSafety(allTrueFlags({ planComplete: false }), {
      confirmed: true,
      operatorOverride: true,
      isExperimentalOrUnverified: false,
    }),
    false,
  );
  assert.throws(
    () =>
      assertCanLockWithSafety(allTrueFlags({ planComplete: false }), {
        confirmed: true,
        operatorOverride: true,
        isExperimentalOrUnverified: false,
      }),
    WizardGateError,
  );

  // Unconfirmed -> blocked even with operator override.
  assert.throws(
    () =>
      assertCanLockWithSafety(readyFlags, {
        confirmed: false,
        operatorOverride: true,
        isExperimentalOrUnverified: false,
      }),
    (err: unknown) =>
      err instanceof WizardGateError && /confirmation/i.test(err.message),
  );

  // Experimental/unverified (e.g. rango / akita) without operator override -> blocked.
  assert.equal(
    canLockWithSafety(readyFlags, {
      confirmed: true,
      operatorOverride: false,
      isExperimentalOrUnverified: true,
    }),
    false,
  );
  assert.throws(
    () =>
      assertCanLockWithSafety(readyFlags, {
        confirmed: true,
        operatorOverride: false,
        isExperimentalOrUnverified: true,
      }),
    (err: unknown) =>
      err instanceof WizardGateError && /operator override/i.test(err.message),
  );

  // Verified target with confirmation passes without override.
  assert.doesNotThrow(() =>
    assertCanLockWithSafety(readyFlags, {
      confirmed: true,
      operatorOverride: false,
      isExperimentalOrUnverified: false,
    }),
  );

  // Experimental/unverified target passes only when BOTH confirmed and operatorOverride are true.
  assert.doesNotThrow(() =>
    assertCanLockWithSafety(readyFlags, {
      confirmed: true,
      operatorOverride: true,
      isExperimentalOrUnverified: true,
    }),
  );
});

test("QA-ADV-UI-04: InstallWizard rejects unoffered devices and blocks live execute/lock", async () => {
  const wizard = new InstallWizard();
  assert.throws(() => wizard.selectDevice("shiba"), WizardGateError);
  assert.throws(() => wizard.selectDevice("husky"), WizardGateError);
  assert.throws(() => wizard.selectDevice(""), WizardGateError);

  wizard.selectDevice("tokay");
  wizard.loadChannel(channelTextsFromBlobs(tokayBlobs()));
  wizard.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  wizard.useLiveTransport({
    connect: async () => undefined,
    getVariable: async () => "no",
    runCommand: async () => ({ text: "", dataSize: 0 }),
    flashBlob: async () => undefined,
    reboot: async () => undefined,
  });

  await assert.rejects(
    () => wizard.executePlan(async () => undefined),
    LiveExecuteHoldError,
  );
  await assert.rejects(() => wizard.lock(), LiveExecuteHoldError);
});

// ---------------------------------------------------------------------------
// 2. Live per-partition progress & recoverable USB error classification
// ---------------------------------------------------------------------------

test("QA-ADV-UI-05: dry-run executePlan emits monotonic per-partition progress and unlocks lock gate only after completion", async () => {
  const wizard = new InstallWizard();
  wizard.selectDevice("tokay");
  wizard.loadChannel(channelTextsFromBlobs(tokayBlobs()));
  wizard.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  wizard.useDryRunTransport();

  await wizard.connect();
  await wizard.unlock();
  assert.equal(wizard.gateState().lock, false);

  const events: FlashProgress[] = [];
  await wizard.executePlan({
    onReconnect: async () => undefined,
    onProgress: (p) => events.push(p),
  });

  assert.ok(events.length > 0, "expected progress events during executePlan");
  assert.equal(wizard.gateState().lock, true, "lock gate must open after plan completion");

  let prevStep = 0;
  for (const ev of events) {
    assert.ok(ev.completedSteps > prevStep, "completedSteps must increase monotonically");
    assert.ok(ev.percent >= 0 && ev.percent <= 100, "percent must be within 0..100");
    assert.ok(ev.label.length > 0, "progress label must be non-empty");
    prevStep = ev.completedSteps;
  }
  const last = events.at(-1)!;
  assert.equal(last.completedSteps, last.totalSteps);
  assert.equal(last.percent, 100);
  assert.ok(
    events.some((e) => typeof e.partition === "string" && e.partition.length > 0),
    "expected at least one per-partition progress event",
  );
});

test("QA-ADV-UI-06: classifyRecoverableUsbError handles typed USB errors, DOM USB errors, and fails closed on unknown errors", () => {
  const disconnect = classifyRecoverableUsbError(new UsbDisconnectError("flash", "cable pulled"));
  assert.equal(disconnect.recoverable, true);
  assert.equal(disconnect.kind, "disconnect");
  assert.match(disconnect.guidance, /Fastboot Mode|Reconnect/i);

  const timeout = classifyRecoverableUsbError(new UsbTimeoutError("download"));
  assert.equal(timeout.recoverable, true);
  assert.equal(timeout.kind, "timeout");
  assert.match(timeout.guidance, /fwupd/i);
  assert.match(timeout.guidance, /adb kill-server/i);

  const permission = classifyRecoverableUsbError(new UsbPermissionError("open"));
  assert.equal(permission.recoverable, true);
  assert.equal(permission.kind, "permission");
  assert.match(permission.guidance, /WebUSB/i);

  const domNotFound = new Error("No device selected");
  domNotFound.name = "NotFoundError";
  assert.equal(classifyRecoverableUsbError(domNotFound).kind, "permission");

  const domNetwork = new Error("transferOut failed");
  domNetwork.name = "NetworkError";
  assert.equal(classifyRecoverableUsbError(domNetwork).kind, "disconnect");

  // Non-USB / unknown errors must NOT be misclassified as recoverable USB errors.
  const nonUsb = classifyRecoverableUsbError(new Error("SHA-256 mismatch"));
  assert.equal(nonUsb.recoverable, false);
  assert.equal(nonUsb.kind, "other");
  assert.equal(classifyRecoverableUsbError("raw-string").recoverable, false);
});

// ---------------------------------------------------------------------------
// 3. Built static site routes: OS USB troubleshooting, strict CSP & honesty
// ---------------------------------------------------------------------------

test("QA-ADV-UI-07: built static route HTML pages enforce strict CSP and no inline scripts/styles", async () => {
  const routeHtmlFiles = [
    "install/index.html",
    "install/update/index.html",
    "install/verify-device/index.html",
    "install/recover/index.html",
  ];

  for (const rel of routeHtmlFiles) {
    const html = await readFile(join(DIST_SITE, rel), "utf8");
    assert.match(html, /http-equiv="Content-Security-Policy"/, `${rel}: missing CSP meta`);
    assert.match(html, /default-src 'none'/, `${rel}: CSP must set default-src 'none'`);
    assert.match(html, /script-src 'self'/, `${rel}: CSP must set script-src 'self'`);
    assert.match(html, /style-src 'self'/, `${rel}: CSP must set style-src 'self'`);
    assert.doesNotMatch(html, /unsafe-inline|unsafe-eval/, `${rel}: CSP must forbid unsafe-inline/eval`);
    assert.doesNotMatch(html, /connect-src[^"]*?\*/, `${rel}: CSP connect-src must not wildcard`);
    assert.doesNotMatch(
      html,
      /<script(?![^>]*\bsrc=)[^>]*>/i,
      `${rel}: inline <script> without src is forbidden`,
    );
    assert.doesNotMatch(
      html,
      /\son(?:click|load|change|input)=/i,
      `${rel}: inline event handlers are forbidden`,
    );
    assert.match(html, /<noscript>/, `${rel}: noscript guidance required`);
  }
});

test("QA-ADV-UI-08: built static site includes OS-specific USB/udev/WinUSB/macOS/Chromium troubleshooting", async () => {
  const usbModule = await readFile(
    join(DIST_SITE, "lib", "ui", "usb-troubleshooting.js"),
    "utf8",
  );
  assert.match(usbModule, /18d1/, "must include Google Pixel USB vendor ID 18d1");
  assert.match(usbModule, /udev/, "must include Linux udev rule guidance");
  assert.match(usbModule, /fwupd/, "must include fwupd conflict guidance");
  assert.match(usbModule, /WinUSB/, "must include Windows WinUSB driver guidance");
  assert.match(usbModule, /macOS/, "must include macOS USB guidance");

  const earlySteps = await readFile(join(DIST_SITE, "install", "early-steps.js"), "utf8");
  assert.match(earlySteps, /Chromium/, "install route must include Chromium WebUSB guidance");

  const verifyRoute = await readFile(
    join(DIST_SITE, "install", "verify-device", "verify-route.js"),
    "utf8",
  );
  assert.match(verifyRoute, /Chromium/, "verify-device route must include Chromium guidance");

  const recoverRoute = await readFile(
    join(DIST_SITE, "install", "recover", "recover-route.js"),
    "utf8",
  );
  assert.match(recoverRoute, /Chromium/, "recover route must include Chromium guidance");
});

test("QA-ADV-UI-09: Law 7 honesty invariants hold across status.json, readiness, wizard HTML, and flashcore", async () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
  assert.equal(BOOT_VERIFIED, false);

  const statusRaw = await readFile(join(PKG_ROOT, "status.json"), "utf8");
  const status = JSON.parse(statusRaw) as {
    preLaunch: boolean;
    flashCapability: { liveFlashClaimed: boolean };
    targets: string[];
    experimentalTargets: string[];
  };
  assert.equal(status.preLaunch, true);
  assert.equal(status.flashCapability.liveFlashClaimed, false);
  assert.equal(status.targets.length + status.experimentalTargets.length, 8);

  const wizardHtml = await readFile(join(PKG_ROOT, "wizard", "index.html"), "utf8");
  assert.match(wizardHtml, /LIVE_FLASH_CLAIMED=false/);
  assert.match(wizardHtml, /FLASH_READY=false/);
});
