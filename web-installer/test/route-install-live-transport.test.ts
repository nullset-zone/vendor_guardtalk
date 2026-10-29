/**
 * F-WEBINSTALL-LIVE-TRANSPORT-UX — the real WebUSB transport's states, surfaced.
 *
 * The transport bundle (`T-WEBINSTALL-WEBUSB-TRANSPORT-BUNDLE`) landed
 * `android-fastboot` behind `FastbootTransport` and proved `executePlan`/`lock`
 * stay HOLD while `LIVE_FLASH_CLAIMED` is false. This suite proves the UI half:
 * each of the five real-transport states is visible, announced through the ONE
 * shared live region, stops the flow, and never implies a flash completed.
 *
 * No USB device is opened and no flash is attempted: `webUsbTransport` is driven
 * through stub `USBDevice` objects whose failures are real `DOMException`s, so
 * the classifiers are exercised through the ACTUAL producers in
 * `lib/fastboot/usb.ts` rather than against hand-typed strings.
 *
 * Acceptance map: (a) states visible+announced, (b) no completion claim,
 * (c) flow stops, (d) LIVE_FLASH_CLAIMED still false and reflected, (e) each
 * state covered with bite, (f) no focus-ring/contrast regression.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  classifyLiveTransportError,
  isLiveTransportStop,
  liveFlashRefusal,
  liveTransportCopy,
  liveTransportPoliteness,
  renderLiveTransportState,
  LIVE_TRANSPORT_REGION_ID,
  WEBUSB_ABSENT_NOTICE,
  type LiveTransportState,
} from "../lib/ui/live-transport.js";
import { hasAssertiveLiveRegion, liveRegionTags } from "../lib/ui/live-region.js";
import { escapeHtml } from "../lib/ui/escape.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";
import { FastbootError, LiveExecuteHoldError } from "../src/errors.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import {
  webUsbTransport,
  type FastbootUsbDevice,
  type UsbConfigSnap,
  type UsbPicker,
} from "../lib/fastboot/usb.js";

/* ================================================================== *
 * Fixtures
 * ================================================================== */

/**
 * Every value the state type allows. The first row is state 1's second cause:
 * the card names one state ("permission denied / no device selected") with two
 * distinguishable causes, and both must be surfaced.
 */
function allStates(): readonly LiveTransportState[] {
  return [
    { kind: "pairing-refused", cause: "cancelled" },
    { kind: "pairing-refused", cause: "denied" },
    { kind: "device-disconnected", detail: "fastboot USB device disappeared" },
    { kind: "product-mismatch", expected: "tokay", actual: "akita" },
    { kind: "webusb-absent" },
    { kind: "live-not-enabled", action: "execute" },
    { kind: "live-not-enabled", action: "lock" },
  ];
}

/** The five card states, one representative row each (state 1: `cancelled`). */
const FIVE: readonly LiveTransportState["kind"][] = [
  "pairing-refused",
  "device-disconnected",
  "product-mismatch",
  "webusb-absent",
  "live-not-enabled",
];

const INSTALLER_ROOT = fileURLToPath(new URL("..", import.meta.url));

function REL(relative: string): string {
  return readFileSync(`${INSTALLER_ROOT}${relative}`, "utf8");
}

/**
 * Parsed, comment-stripped source of one top-level function. Comments are
 * stripped deliberately: several of this card's assertions name the very
 * identifiers the surrounding comments mention, and a comment must never be
 * able to satisfy a wiring assertion (that would be a vacuous pass).
 */
function functionBody(source: string, signature: string): string {
  const stripped = source
    .replace(/\/\*[\s\S]*?\*\//gu, "")
    .replace(/(^|[\s;{}()])\/\/[^\n]*/gu, "$1");
  const start = stripped.indexOf(signature);
  assert.ok(start >= 0, `${signature} must exist in the parsed source`);
  const rest = stripped.slice(start + signature.length);
  const end = rest.search(/\n(?:async )?function /u);
  const body = end < 0 ? rest : rest.slice(0, end);
  assert.ok(body.trim().length > 40, `${signature} must have a real body, not a stub`);
  return body;
}

/* ================================================================== *
 * (a) visible + announced — one shared announcing region
 * ================================================================== */

test("(a) each of the five states is VISIBLE and ANNOUNCED through the shared live region", () => {
  const seen = new Set<string>();
  for (const state of allStates()) {
    const html = renderLiveTransportState(state);
    const copy = liveTransportCopy(state);
    seen.add(state.kind);

    // Visible: the state names itself, carries a worded chip, and shows its text.
    assert.match(html, new RegExp(`data-transport-state="${state.kind}"`, "u"), html);
    assert.ok(html.includes(copy.chipWord), `chip word for ${state.kind}`);
    assert.ok(html.includes(escapeHtml(copy.title)), `title for ${state.kind}`);
    assert.ok(html.includes(escapeHtml(copy.remedy)), `remedy for ${state.kind}`);

    // Announced: exactly ONE region, atomic, carrying the headline text.
    const regions = liveRegionTags(html);
    assert.equal(regions.length, 1, `exactly one live region for ${state.kind}`);
    assert.match(regions[0] ?? "", /aria-atomic="true"/u);
    assert.ok(html.includes(`id="${LIVE_TRANSPORT_REGION_ID}"`), `stable region id`);
    assert.ok(
      html.includes(escapeHtml(copy.headline)),
      `the headline is inside the region (announced) for ${state.kind}`,
    );

    // Politeness is coherent with the severity: a halted operation interrupts.
    if (isLiveTransportStop(state)) {
      assert.equal(liveTransportPoliteness(state), "assertive");
      assert.ok(hasAssertiveLiveRegion(html), `assertive contract for ${state.kind}`);
      assert.match(html, /role="alert" aria-live="assertive" aria-atomic="true"/u);
      assert.match(html, /hard-stop-banner/u);
    } else {
      assert.equal(liveTransportPoliteness(state), "polite");
      assert.match(html, /role="status" aria-live="polite" aria-atomic="true"/u);
      assert.doesNotMatch(html, /aria-live="assertive"/u);
    }
  }
  // Non-vacuity: the loop really walked the five card states.
  assert.deepEqual([...seen].sort(), ["device-disconnected", "live-not-enabled", "pairing-refused", "product-mismatch", "webusb-absent"]);
  assert.deepEqual([...FIVE].sort(), [...seen].sort());
});

test("(a) the absent-WebUSB notice is kept verbatim and made first-class", () => {
  assert.equal(WEBUSB_ABSENT_NOTICE, "WebUSB is not available. Use the CLI export path.");
  const copy = liveTransportCopy({ kind: "webusb-absent" });
  assert.equal(copy.headline, WEBUSB_ABSENT_NOTICE);
  // It is no longer a bare sentence: it is the headline of an announced state.
  const html = renderLiveTransportState({ kind: "webusb-absent" });
  assert.ok(html.includes(WEBUSB_ABSENT_NOTICE));
  assert.ok(liveRegionTags(html).length === 1);
  assert.match(html, /data-transport-state="webusb-absent"/u);
});

test("(a) the product-mismatch state quotes the ONE stop reason, not a paraphrase", () => {
  const copy = liveTransportCopy({ kind: "product-mismatch", expected: "tokay", actual: "akita" });
  assert.equal(copy.headline, STOP_REASONS.PRODUCT_MISMATCH);
  const html = renderLiveTransportState({ kind: "product-mismatch", expected: "tokay", actual: "akita" });
  assert.ok(html.includes(STOP_REASONS.PRODUCT_MISMATCH));
  // The side-by-side fact is present, so the mismatch is checkable by the user.
  assert.ok(html.includes("expected: tokay"));
  assert.ok(html.includes("device reports: akita"));
});

/* ================================================================== *
 * (b) no copy states or implies a completed flash
 * ================================================================== */

/** Phrases that would claim (or congratulate) a write that did not happen. */
const COMPLETION_CLAIMS: readonly RegExp[] = [
  /\bsuccess/iu,
  /\bsucceeded\b/iu,
  /\bflash(?:ed|ing)?\b[^.<]{0,24}\b(?:complete|completed|done|finished)\b/iu,
  /\b(?:install|flash)(?:ed|ation)?\s+(?:is|was)\s+(?:complete|done|finished)\b/iu,
  /\byou'?re\s+all\s+set\b/iu,
  /\bdone\b/iu,
];

/** The honest verb each state family uses instead (proves (b) is not vacuous). */
const HONEST_VERBS: readonly RegExp[] = [
  /wrote nothing|opened nothing|nothing was (?:opened|written)|halted|no write was sent|no further commands|stopped instead/iu,
];

test("(b) no state's copy claims or implies a completed flash", () => {
  for (const state of allStates()) {
    const html = renderLiveTransportState(state);
    for (const pattern of COMPLETION_CLAIMS) {
      assert.doesNotMatch(html, pattern, `${state.kind} must not claim completion: ${String(pattern)}`);
    }
  }
  // Non-vacuity control: every state DOES say what actually happened, so the
  // sweep above is not scanning empty strings.
  for (const state of allStates()) {
    const html = renderLiveTransportState(state);
    assert.ok(
      HONEST_VERBS.some((pattern) => pattern.test(html)),
      `${state.kind} must state the honest outcome`,
    );
  }
});

test("(b) the emitted state markup passes the programme claim linter", () => {
  for (const state of allStates()) {
    const hits = lintText(renderLiveTransportState(state), `live-transport:${state.kind}`);
    assert.deepEqual(
      hits.map((hit) => `${hit.rule}: ${hit.excerpt}`),
      [],
      `claim lint must be clean for ${state.kind}`,
    );
  }
});

test("(b) 'not enabled in this build' is a BUILD POSTURE — never a device error, never a result", () => {
  for (const action of ["execute", "lock"] as const) {
    const html = renderLiveTransportState({ kind: "live-not-enabled", action });
    assert.match(html, /not enabled in this build/u);
    assert.match(html, /LIVE_FLASH_CLAIMED is false/u);
    assert.match(html, /not a device fault/iu);
    assert.match(html, /stopped instead of sending (?:a write|a lock command)/u);
    // It must not blame the phone, and must not read as an outcome.
    assert.doesNotMatch(html, /device (?:error|failure|fault:)/iu);
    assert.doesNotMatch(html, COMPLETION_CLAIMS[0] as RegExp);
  }
  // The two actions are worded differently — proving the copy follows the fact.
  assert.ok(
    renderLiveTransportState({ kind: "live-not-enabled", action: "lock" }).includes("a lock command"),
  );
  assert.ok(
    renderLiveTransportState({ kind: "live-not-enabled", action: "execute" }).includes("a write"),
  );
});

/* ================================================================== *
 * (c) the flow STOPS — machine-checkable at the markup layer
 * ================================================================== */

test("(c) every state is emitted as a no-advance region", () => {
  for (const state of allStates()) {
    const html = renderLiveTransportState(state);
    assert.match(html, /data-advance="none"/u, `${state.kind} must declare no advance`);
    assert.equal(liveTransportCopy(state).advances, false);
  }
});

test("(c) the route renders the state into EVERY step, and its refusal sites return", () => {
  const app = REL("routes/install/install-app.ts");

  // The state reaches the page through one block that every step prefixes with.
  const block = functionBody(app, "function noticeBlock(");
  assert.match(block, /renderLiveTransportState\(session\.transportState\)/u);
  const stepHtml = functionBody(app, "function stepHtml(");
  assert.match(stepHtml, /const notice = noticeBlock\(\);/u);
  assert.doesNotMatch(stepHtml, /session\.notice/u, "no branch may bypass the state block");

  // Every state assignment is followed by a render and a return — never by an
  // advance. (`= undefined` is the per-action reset, not a refusal.)
  const assignments = [...app.matchAll(/session\.transportState = (?!undefined)([^\n]*)\n([\s\S]{0,260})/gu)];
  assert.ok(assignments.length >= 4, `expected the refusal sites, found ${String(assignments.length)}`);
  for (const match of assignments) {
    const tail = match[2] ?? "";
    // The refusal is whatever happens between the assignment and the handler's
    // next `return;` — nothing after that point can be attributed to the state.
    const stopAt = tail.indexOf("return;");
    assert.ok(stopAt >= 0, "a state must stop the handler");
    const region = tail.slice(0, stopAt);
    // Either the handler re-renders, or it dispatches a machine STOP (which
    // renders) — either way the state is painted before the handler returns.
    assert.match(region, /render\(\);|dispatch\(\{ type: "stop"/u, "a state must be painted");
    assert.doesNotMatch(region, /flash-step-done/u, "a state must never advance");
  }
});

test("(c) pairing refusals stop the handler: classify → state → render → return", () => {
  const pair = functionBody(REL("routes/install/install-app.ts"), "async function pairDevice(");
  // (4) WebUSB absent is surfaced as a state, not a bare notice.
  assert.match(pair, /kind: "webusb-absent"/u);
  assert.match(pair, /session\.transport /u);
  // (1) the picker rejection is classified (and an unrecognised error rethrows,
  // preserving the pre-existing handling rather than mislabelling it).
  assert.ok(pair.split("classifyLiveTransportError(").length - 1 >= 2, "both pairing catch sites classify");
  assert.match(pair, /throw err;/u, "a non-state error must keep its existing path");
});

test("(c) flashNow STOPs before any advance: the build gate precedes the plan, and the catch cannot reach the dispatch", () => {
  const flash = functionBody(REL("routes/install/install-app.ts"), "async function flashNow(");
  const gateAt = flash.indexOf("liveFlashRefusal(");
  const guardAt = flash.indexOf("refuseMissingImages()");
  const planAt = flash.indexOf("runFlashPlan(");
  const catchAt = flash.indexOf("} catch (err: unknown) {");
  const dispatchAt = flash.indexOf('dispatch({ type: "flash-step-done" })');

  assert.ok(gateAt >= 0, "the build-level live gate must exist");
  assert.ok(guardAt >= 0, "the no-image guard must still exist");
  assert.ok(planAt >= 0, "the plan must still run");
  assert.ok(catchAt >= 0, "the plan must be wrapped in a catch");
  assert.ok(dispatchAt >= 0, "success must still advance (non-vacuity: not a blanket refusal)");

  assert.ok(gateAt < planAt, "the live gate must run before any plan is built");
  assert.ok(gateAt < guardAt, "the build posture is decided before the device-specific guards");
  assert.ok(catchAt > planAt, "the catch wraps the plan");
  assert.ok(dispatchAt > catchAt, "the advance is outside the catch");

  const catchRegion = flash.slice(catchAt, dispatchAt);
  assert.match(catchRegion, /classifyLiveTransportError\(err\)/u, "the catch classifies");
  assert.match(catchRegion, /return;/u, "the catch exits before the advance");
  assert.equal(flash.split('dispatch({ type: "flash-step-done" })').length, 2, "exactly one advance");
});

/* ================================================================== *
 * (d) LIVE_FLASH_CLAIMED stays false, and the UI derives from it
 * ================================================================== */

test("(d) LIVE_FLASH_CLAIMED is false and the refusal is DERIVED from it", () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);

  // Derived, not hardcoded: the same call flips with the flag…
  assert.deepEqual(liveFlashRefusal({ sim: false, liveFlashClaimed: true }), undefined);
  // …and with the session mode (a simulated session never touches hardware).
  assert.deepEqual(liveFlashRefusal({ sim: true, liveFlashClaimed: false }), undefined);

  const refusal = liveFlashRefusal({ sim: false, liveFlashClaimed: LIVE_FLASH_CLAIMED });
  assert.deepEqual(refusal, { kind: "live-not-enabled", action: "execute" });
  const html = renderLiveTransportState(refusal as LiveTransportState);
  assert.match(html, /LIVE_FLASH_CLAIMED is false/u);
  assert.match(html, /data-transport-state="live-not-enabled"/u);
});

test("(d) the route reads the shipped constant instead of deciding for itself", () => {
  const app = REL("routes/install/install-app.ts");
  assert.match(app, /import \{ LIVE_FLASH_CLAIMED \} from "\.\.\/\.\.\/src\/types\.js";/u);
  assert.match(app, /liveFlashRefusal\(\{ sim: sim\(\), liveFlashClaimed: LIVE_FLASH_CLAIMED \}\)/u);
  // No second copy of the flag: it is never re-declared in the route.
  assert.doesNotMatch(app, /const LIVE_FLASH_CLAIMED/u);
  assert.doesNotMatch(app, /liveFlashClaimed: (?:true|false)/u);
});

/* ================================================================== *
 * (e) classifiers — driven through the REAL producers
 * ================================================================== */

test("(e) the DEC-009 HOLD maps to 'not enabled in this build' (execute and lock)", () => {
  const execute = classifyLiveTransportError(new LiveExecuteHoldError("execute"));
  assert.deepEqual(execute, { kind: "live-not-enabled", action: "execute" });
  const lock = classifyLiveTransportError(new LiveExecuteHoldError("lock"), "lock");
  assert.deepEqual(lock, { kind: "live-not-enabled", action: "lock" });

  // Cross-realm / bundled-copy safety: the same hold is recognised by its code.
  const acrossModules = classifyLiveTransportError(
    Object.assign(new Error("DEC-009: live execute is HOLD. Dry-run only."), { code: "LIVE_EXECUTE_HOLD" }),
  );
  assert.deepEqual(acrossModules, { kind: "live-not-enabled", action: "execute" });
});

test("(e) a bootloader FAIL is NOT a transport state — it is never relabelled", () => {
  // Bite: without this, the catch in flashNow could swallow a device refusal
  // and present it as a build posture.
  assert.equal(classifyLiveTransportError(new FastbootError("partition table does not support vendor_boot")), undefined);
  assert.equal(classifyLiveTransportError(new Error("flash gate unsatisfied")), undefined);
  assert.equal(classifyLiveTransportError("not an error"), undefined);
  assert.equal(classifyLiveTransportError(undefined), undefined);
});

/** A USBDevice stub whose transferIn fails with a real DOMException. */
function failingUsbDevice(transferError: DOMException): {
  picker: UsbPicker;
  device: FastbootUsbDevice;
} {
  const config: UsbConfigSnap = {
    configurationValue: 1,
    interfaces: [
      {
        interfaceNumber: 0,
        alternates: [
          {
            interfaceClass: 255,
            interfaceSubclass: 66,
            interfaceProtocol: 1,
            endpoints: [
              { direction: "in", type: "bulk", endpointNumber: 1 },
              { direction: "out", type: "bulk", endpointNumber: 1 },
            ],
          },
        ],
      },
    ],
  };
  const device: FastbootUsbDevice = {
    configurations: [config],
    open: async () => undefined,
    selectConfiguration: async () => undefined,
    claimInterface: async () => undefined,
    releaseInterface: async () => undefined,
    close: async () => undefined,
    transferOut: async () => ({ status: "ok" }),
    transferIn: async () => {
      throw transferError;
    },
  };
  return { picker: { requestDevice: async () => device }, device };
}

test("(e) state 1 — the real picker translation yields a refused-pairing state", async () => {
  const cancelled: UsbPicker = {
    requestDevice: async () => {
      throw new DOMException("user cancelled chooser", "NotFoundError");
    },
  };
  const cancelErr = await webUsbTransport(cancelled).then(
    () => undefined,
    (err: unknown) => err,
  );
  assert.deepEqual(classifyLiveTransportError(cancelErr), { kind: "pairing-refused", cause: "cancelled" });

  const denied: UsbPicker = {
    requestDevice: async () => {
      throw new DOMException("blocked by permissions policy", "SecurityError");
    },
  };
  const denyErr = await webUsbTransport(denied).then(
    () => undefined,
    (err: unknown) => err,
  );
  assert.deepEqual(classifyLiveTransportError(denyErr), { kind: "pairing-refused", cause: "denied" });

  // Both causes are worded DIFFERENTLY — the user is told what to fix.
  const cancelledCopy = liveTransportCopy({ kind: "pairing-refused", cause: "cancelled" });
  const deniedCopy = liveTransportCopy({ kind: "pairing-refused", cause: "denied" });
  assert.notEqual(cancelledCopy.headline, deniedCopy.headline);
  assert.match(deniedCopy.remedy, /site settings/u);
});

test("(e) state 1 — a claim failure is NOT permission-denied (no mislabelling)", async () => {
  const config: UsbConfigSnap = {
    configurationValue: 1,
    interfaces: [
      {
        interfaceNumber: 0,
        alternates: [
          {
            interfaceClass: 255,
            interfaceSubclass: 66,
            interfaceProtocol: 1,
            endpoints: [
              { direction: "in", type: "bulk", endpointNumber: 1 },
              { direction: "out", type: "bulk", endpointNumber: 1 },
            ],
          },
        ],
      },
    ],
  };
  const device: FastbootUsbDevice = {
    configurations: [config],
    open: async () => undefined,
    selectConfiguration: async () => undefined,
    claimInterface: async () => {
      throw new DOMException("in use by another driver", "InvalidStateError");
    },
    releaseInterface: async () => undefined,
    close: async () => undefined,
    transferOut: async () => ({ status: "ok" }),
    transferIn: async () => ({ status: "ok" }),
  };
  const err = await webUsbTransport({ requestDevice: async () => device }).then(
    () => undefined,
    (thrown: unknown) => thrown,
  );
  assert.ok(err instanceof Error);
  assert.match(err.message, /Could not claim/u);
  assert.equal(classifyLiveTransportError(err), undefined, "a claim failure is not state 1");
});

test("(e) state 2 — a mid-flow disconnect is announced with the verbatim transport reason", async () => {
  const gone = new DOMException("device unplugged", "NotFoundError");
  const { picker } = failingUsbDevice(gone);
  const transport = await webUsbTransport(picker);
  const readErr = await transport.readPacket().then(
    () => undefined,
    (err: unknown) => err,
  );
  const state = classifyLiveTransportError(readErr);
  assert.ok(state !== undefined, "a vanished device must map to a state");
  assert.equal(state.kind, "device-disconnected");
  assert.ok(state.kind === "device-disconnected");
  assert.match(state.detail, /disappeared/u, "the verbatim reason is carried, not paraphrased");

  const html = renderLiveTransportState(state);
  assert.match(html, /data-transport-state="device-disconnected"/u);
  assert.match(html, /did not finish/u);
  assert.match(html, /Do not lock the bootloader/u);
});

/* ================================================================== *
 * (f) no focus-ring / contrast regression
 * ================================================================== */

test("(f) the focus ring still resolves to brand-800 and the shipped rule is unchanged", () => {
  // The state markup adds NO styling: no inline style, no colour literal, no
  // new class that could carry one.
  for (const state of allStates()) {
    const html = renderLiveTransportState(state);
    assert.doesNotMatch(html, /\sstyle\s*=/iu);
    assert.doesNotMatch(html, /#[0-9a-f]{3,8}\b/iu);
  }

  // Cascade: tokens → wizard/styles.css (the installer's override layer).
  const tokens = REL("design/pajamas/tokens.css");
  const wizard = REL("wizard/styles.css");
  assert.match(tokens, /--gl-color-brand-800:\s*#4C6B12;/u);
  assert.match(wizard, /--gl-focus-ring:\s*var\(--gl-color-brand-800\);/u, "the ring is brand-800");
  assert.match(
    wizard,
    /outline:\s*2px solid var\(--gl-focus-ring\);/u,
    "the focus-visible outline still uses the shared ring token",
  );
});

/* ================================================================== *
 * The wiring assertions above must not be satisfiable by a stale read
 * ================================================================== */

test("bite control: the parsed route is the real route (assertions are not vacuous)", () => {
  const app = REL("routes/install/install-app.ts");
  // Anchors that only exist in the real file, so a truncated/stale read fails.
  assert.match(app, /async function flashNow\(/u);
  assert.match(app, /function noticeBlock\(/u);
  assert.match(app, /refuseMissingImages\(\)/u);
  assert.ok(app.length > 20000, "the route source is the full application module");
  // And the module under test is the one the route imports.
  assert.match(app, /from "\.\.\/\.\.\/lib\/ui\/live-transport\.js";/u);
});
