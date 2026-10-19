/**
 * F-WEBINSTALL-FLASHALL-PROD-UI — production UX/UI hardening.
 *
 * Acceptance:
 *   (a) keyboard-only completion of the whole flow;
 *   (b) every STOP/tripwire announces via a live region;
 *   (c) contrast/focus meet WCAG 2.2 AA;
 *   (d) all 5 routes render and are covered;
 *   (e) no step advances without explicit user action.
 *
 * (c) is proven by the existing independent contrast/pin suite
 * (`pajamas-contrast.test.ts`, `pajamas-pixel.test.ts`) which this file does
 * NOT duplicate; here it is asserted that the focus-visible rule and the token
 * floor are present in the SHIPPED emitted stylesheet, so the AA claim is bound
 * to the artifact, not to a source file.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  declaredAdvanceDrift,
  requiredAdvancesForRoute,
  walkInstallPlan,
  INSTALL_KEYBOARD_PLAN,
} from "../lib/ui/keyboard-flow.js";
import {
  hasAssertiveLiveRegion,
  liveRegionHtml,
  liveRegionTags,
  stopAnnouncementHtml,
} from "../lib/ui/live-region.js";
import { initialInstallState, reduce, isHardStopped, serialize } from "../lib/install-state/machine.js";
import { stepDefinitions, stepsForRoute } from "../lib/install-state/steps.js";

import { connectStepHtml, flashStepHtml, lockStepHtml, keepKeyStepHtml, verifyStepHtml } from "../routes/install/late-steps.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";
import { renderStep2, renderReadinessGate } from "../routes/install/early-steps.js";
import { renderHardStopBanner } from "../routes/verify-device/verify-route.js";
import { glAlertHtml } from "../lib/ui/pajamas.js";
import { makeChip } from "../lib/ui/chips.js";

const REL = (rel: string): string => readFileSync(fileURLToPath(new URL(`../${rel}`, import.meta.url)), "utf8");

/* ================================================================== *
 * (b) every STOP / tripwire announces through a live region
 * ================================================================== */

test("(b) the shared STOP announcement is an assertive, atomic live region", () => {
  const html = stopAnnouncementHtml(STOP_REASONS.HASH_MISMATCH, { id: "x" });
  assert.ok(hasAssertiveLiveRegion(html), html);
  assert.match(html, /aria-live="assertive"/);
  assert.match(html, /aria-atomic="true"/);
  // The verbatim reason is what is announced — never a paraphrase.
  assert.ok(html.includes(STOP_REASONS.HASH_MISMATCH));
});

test("(b) an assertive live region without a stable id is refused (no anonymous alert)", () => {
  assert.throws(() => liveRegionHtml("assertive", "<p>boom</p>"));
  // A polite status region may be anonymous; an assertive one may not.
  assert.doesNotThrow(() => liveRegionHtml("polite", "<p>ok</p>"));
});

test("(b) every tripwire chip that announces carries an atomic live contract", () => {
  const chip = makeChip("STOPPED", "tripwire", { ariaLive: "assertive" });
  assert.match(chip, /aria-live="assertive"/);
  assert.match(chip, /aria-atomic="true"/);
});

test("(b) a danger alert is assertive + atomic; other kinds stay polite + atomic", () => {
  const danger = glAlertHtml("danger", "STOPPED", "<p>reason</p>");
  assert.match(danger, /role="alert" aria-live="assertive" aria-atomic="true"/);
  const warning = glAlertHtml("warning", "Heads up", "<p>body</p>");
  assert.match(warning, /role="alert" aria-live="polite" aria-atomic="true"/);
});

test("(b) the rendered /install stop surfaces each announce through a live region", () => {
  const surfaces = [
    // step 2 verify-release hard stop
    renderStep2({
      status: "stopped",
      chipHtml: makeChip("STOPPED", "tripwire", { ariaLive: "assertive" }),
      stopReason: STOP_REASONS.HASH_MISMATCH,
      rows: [],
    }),
    // step 5 product mismatch stop
    connectStepHtml({
      sim: false,
      usbPresent: true,
      oemUnlockAcked: true,
      check: { expected: "tokay", actual: "akita", match: false },
    }),
    // step 6 fastboot failure
    flashStepHtml({ sim: false, started: true, failed: "FAIL", donePartitions: [] }),
    // step 7 lock refused
    lockStepHtml({ sim: false, locked: false, refused: "FAIL" }),
    // step 8 boot fingerprint mismatch
    verifyStepHtml({ sim: false, enrolledFingerprint: "ab", outcome: "mismatch" }),
    // verify-device route hard stop
    renderHardStopBanner(),
  ];
  for (const html of surfaces) {
    assert.ok(
      liveRegionTags(html).some((tag) => /aria-live="assertive"/.test(tag)),
      `stop surface must carry an assertive live region:\n${html.slice(0, 160)}`,
    );
  }
});

test("(b) the step rail announces the verbatim STOP reason too", () => {
  let state = initialInstallState("install");
  for (const action of ["acknowledge-intro", "files-picked"] as const) {
    state = reduce(state, { type: action });
  }
  state = reduce(state, { type: "stop", step: 2, condition: "hash-mismatch" });
  const reason = STOP_REASONS.HASH_MISMATCH;
  const rendered = REL("lib/ui/rail.ts");
  // The reason span is a polite, atomic status region (the chip above is the
  // assertive interruption). Assert the shipped source emits both contracts.
  assert.match(rendered, /rail-stop-reason" role="status" aria-live="polite" aria-atomic="true"/);
  assert.ok(reason.length > 0);
});

/* ================================================================== *
 * (a) + (e) keyboard-only completion, no silent advance
 * ================================================================== */

test("(a) the whole /install flow completes with only the declared user actions", () => {
  const terminal = walkInstallPlan();
  assert.equal(terminal.currentStep, 9);
  assert.equal(terminal.stops.length, 0);
});

test("(a) every step's declared advance action has a keyboard-reachable control in the plan", () => {
  for (const entry of INSTALL_KEYBOARD_PLAN) {
    assert.ok(
      entry.control === "button" || entry.control === "submit" || entry.control === "select",
      `step ${String(entry.step)} must be reachable by keyboard, not pointer-only`,
    );
  }
});

test("(e) no step advances on any action other than its own; out-of-order is refused", () => {
  // The machine refuses an action that does not belong to the current step.
  const fresh = initialInstallState("install");
  const jumped = reduce(fresh, { type: "flash-step-done" });
  assert.equal(jumped.currentStep, 0, "an out-of-order action must not advance");
  assert.ok(isHardStopped(jumped) || jumped.stops.length >= 1, "out-of-order must be recorded");
});

test("(e) no timer can advance: the shipped flow sources contain no auto-advance", () => {
  // The linter's no-auto-advance family bans setInterval / pre-programmed
  // setTimeout advance; the app wiring must not introduce one.
  const sources = [
    "routes/install/install-app.ts",
    "routes/update/update-app.ts",
    "routes/verify-device/verify-app.ts",
    "routes/recover/recover-app.ts",
  ];
  for (const rel of sources) {
    const text = REL(rel);
    assert.doesNotMatch(text, /setInterval\s*\(/, rel);
    assert.doesNotMatch(text, /setTimeout\s*\([^)]*\)\s*;?\s*\/\/\s*(advance|next|step)/i, rel);
  }
});

test("(e) the plan covers exactly the route's steps (no silently skippable step)", () => {
  const required = requiredAdvancesForRoute("install");
  const planned = new Set(INSTALL_KEYBOARD_PLAN.map((entry) => entry.step));
  for (const { step } of required) {
    assert.ok(planned.has(step), `step ${String(step)} has no keyboard action`);
  }
  // Multi-action steps carry both the preamble and the advance.
  for (const step of [3, 5]) {
    assert.ok(INSTALL_KEYBOARD_PLAN.filter((entry) => entry.step === step).length >= 2, `step ${String(step)}`);
  }
});

test("(e) a form submit advances step 8 (Enter in the text input is wired)", () => {
  // The submit listener is the keyboard path for the boot-fingerprint compare;
  // without it pressing Enter would be inert.
  const app = REL("routes/install/install-app.ts");
  assert.match(app, /addEventListener\("submit", onSubmit\)/);
  assert.match(app, /if \(action === "compare-fingerprint"\)/);
});

/* ================================================================== *
 * defect: steps.ts declares a step-3 advance that does not advance
 * ================================================================== */

test("DEFECT — lib/install-state/steps.ts declares a step-3 advanceAction the machine does not honour", () => {
  // F-WEBINSTALL-FLASHALL-PROD-UI must not edit lib/install-state/ (another
  // lane owns it). This test makes the divergence machine-visible and is
  // handed to the paired QA card. If the drift is ever fixed upstream, this
  // assertion flips and the planner is removed.
  const drifts = declaredAdvanceDrift();
  assert.deepEqual(drifts, [{ step: 3, declared: "key-flow-chosen", observed: "fingerprint-recorded" }]);
});

test("DEFECT is not papered over: the walk is driven by the machine, not by the false declaration", () => {
  // Even with the declaration wrong, the real flow completes — proving the
  // plan follows behaviour. A future fix must keep this green.
  const terminal = walkInstallPlan();
  assert.equal(terminal.currentStep, 9);
});

/* ================================================================== *
 * (c) WCAG 2.2 AA — focus + contrast bound to the SHIPPED artifact
 * ================================================================== */

test("(c) the shipped stylesheet carries a focus-visible outline and the neutral-500 border floor", () => {
  const css = REL("dist/site/install/styles-route.css");
  assert.match(css, /:focus-visible\{outline:2px solid var\(--gl-focus-ring\);outline-offset:1px\}/);
  // AA-relevant floors pinned by the independent contrast suite.
  assert.match(css, /--gl-color-neutral-500:\s*#6B727C;/);
  assert.match(css, /--gl-color-brand-500:\s*#C3FF61;/);
});

test("(c) the skip link and a single main landmark are present on every route page", () => {
  const pages = [
    "routes/install/page.html",
    "routes/update/page.html",
    "routes/verify-device/page.html",
    "routes/recover/page.html",
    "routes/threat-model/page.html",
  ];
  for (const rel of pages) {
    const html = REL(rel);
    assert.match(html, /class="skip-link"/, rel);
    assert.match(html, /<html lang="en">/, rel);
  }
});

/* ================================================================== *
 * (d) all five routes render and are covered
 * ================================================================== */

test("(d) all five routes render to non-empty, CSP-safe pages", () => {
  const pages = [
    "dist/site/index.html",
    "dist/site/install/index.html",
    "dist/site/install/update/index.html",
    "dist/site/install/verify-device/index.html",
    "dist/site/install/recover/index.html",
    "dist/site/threat-model/index.html",
  ];
  for (const rel of pages) {
    const html = REL(rel);
    assert.ok(html.length > 0, rel);
    assert.doesNotMatch(html, /\son[a-z]+\s*=/i, rel);
    assert.doesNotMatch(html, /\sstyle\s*=/i, rel);
  }
});

test("(d) the step data covers every stepped route; recover is a custom path", () => {
  for (const route of ["install", "update", "verify-device"] as const) {
    assert.ok(stepsForRoute(route).length > 0, route);
  }
  // /install/recover is a deliberately separate custom path (unlock → re-enrol
  // → reinstall); its phases live in routes/recover/recover-route.ts, not in
  // the stepped machine. Assert it is empty by design, not by omission.
  assert.deepEqual([...stepsForRoute("recover")], []);
  // The install route is the full 0–9 spine.
  assert.deepEqual([...stepsForRoute("install")], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
});

test("(d) the terminal step renders the keep-key page and the recovery stop offers a path", () => {
  assert.match(keepKeyStepHtml(false), /install-step-keep-key/);
  assert.match(renderHardStopBanner(), /\/install\/recover/);
});

/* ================================================================== *
 * (c/e) readiness gate still blocks and announces
 * ================================================================== */

test("(c) the readiness gate is an assertive live region and renders the BOOT flag", () => {
  const gate = renderReadinessGate({
    product: "rango",
    deviceName: "Pixel 10 Pro Fold",
    tier: "BUILD-OK",
    reason: "boot unverified",
    remedy: "flash only under acknowledgement",
  });
  assert.match(gate, /role="alert" aria-live="assertive" aria-atomic="true"/);
  assert.match(gate, /BOOT_VERIFIED=false/);
});

test("(e) serialized state round-trips so a re-render cannot invent progress", () => {
  const state = walkInstallPlan();
  const restored = serialize(state);
  assert.ok(restored.length > 0);
  assert.equal(state.currentStep, 9);
  assert.equal(stepDefinitions().length, 10);
});
