/**
 * Route Builder C (Phase 3) — /install/update contract tests.
 *
 * Binding refs: DECISION_LOG D-003 (update = steps 1,2,3 flows 2/3 only with
 * generate hidden + reason, 4, 5 no-unlock, 6, 8, 9) and the D-004 release
 * policy: updates are user-driven full packages; GuardTalk ships no push
 * channel of any kind. Markup sweeps run over the emitted page HTML; the
 * happy path runs over SimulatedDevice via FastbootClient.
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  CLOSING_SENTENCE,
  GENERATE_HIDDEN_REASON,
  SIDELOAD_NOTE,
  UPDATE_INTRO,
  UPDATE_NO_PUSH,
  linkSimulatedDevice,
  reduceUpdate,
  renderUpdatePage,
  runUpdateFlow,
  type UpdatePageModel,
} from "../routes/update/update-route.js";
import { INSTALLER_CSP, RELEASE_FETCH_ORIGIN } from "../lib/claims/csp.js";
import { initialInstallState, isHardStopped, reduce, serialize } from "../lib/install-state/machine.js";
import { stepsForRoute } from "../lib/install-state/steps.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";
import { SimulatedDevice } from "../lib/fastboot/simulated-device.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { utf8 } from "./helpers.js";
import { signedAnchor } from "./fixtures/signed-anchor.js";

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

function updateModel(step: number, overrides: Partial<UpdatePageModel> = {}): UpdatePageModel {
  let state = initialInstallState("update");
  // Walk the machine to just before `step`; two-action steps (3 and 5) apply
  // their choice/ack first, then the advancing action.
  for (const current of stepsForRoute("update")) {
    if (current >= step) {
      break;
    }
    switch (current) {
      case 1:
        state = reduce(state, { type: "files-picked" });
        break;
      case 2:
        state = reduce(state, { type: "release-verified" });
        break;
      case 3:
        state = reduce(state, { type: "key-flow-chosen", keyFlow: 2 });
        state = reduce(state, { type: "fingerprint-recorded" });
        break;
      case 4:
        state = reduce(state, { type: "vbmeta-signed" });
        break;
      case 5:
        state = reduce(state, { type: "oem-unlock-acked" });
        state = reduce(state, { type: "device-matched", product: "tokay" });
        break;
      case 6:
        state = reduce(state, { type: "flash-step-done" });
        break;
      case 8:
        state = reduce(state, {
          type: "boot-fingerprint-typed",
          fingerprint: "ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12",
        });
        break;
      case 9:
        state = reduce(state, { type: "keep-key-acknowledged" });
        break;
    }
  }
  return {
    state,
    simMode: false,
    targetProduct: "tokay",
    deviceProduct: "tokay",
    ...overrides,
  };
}

function htmlAtStep(step: number, overrides: Partial<UpdatePageModel> = {}): string {
  return renderUpdatePage(updateModel(step, overrides));
}

/** The full emitted markup across every route step. */
function allStepsHtml(): string {
  return stepsForRoute("update").map((step) => htmlAtStep(step)).join("\n");
}

/* ------------------------------------------------------------------ */
/* Step rail subset                                                    */
/* ------------------------------------------------------------------ */

test("update route renders machine's step subset [1,2,3,4,5,6,8,9] and nothing else", () => {
  assert.deepEqual(stepsForRoute("update"), [1, 2, 3, 4, 5, 6, 8, 9]);
  const html = allStepsHtml();
  for (const step of stepsForRoute("update")) {
    assert.match(html, new RegExp(`data-step="${String(step)}"`), `step ${step} must appear`);
  }
  for (const forbidden of [0, 7]) {
    // data-step="0"/"7" must not exist anywhere (rail items or panels).
    assert.doesNotMatch(html, new RegExp(`data-step="${String(forbidden)}"`));
  }
});

test("page skeleton carries the exact CSP meta tag", () => {
  const html = htmlAtStep(1);
  assert.match(
    html,
    new RegExp(`<meta http-equiv="Content-Security-Policy" content="${INSTALLER_CSP}">`),
  );
});

test("update copy states user-driven updates and that GuardTalk cannot push anything", () => {
  const html = allStepsHtml();
  assert.match(html, /verify its SHA256SUMS digest/);
  assert.match(html, /flash the update/);
  assert.ok(html.includes(UPDATE_NO_PUSH));
});

test("sim mode renders the visible simulation chip once (?sim=1 semantics)", () => {
  const plain = htmlAtStep(1);
  assert.doesNotMatch(plain, /SIMULATED DEVICE/);
  const sim = htmlAtStep(1, { simMode: true });
  const hits = sim.match(/SIMULATED DEVICE — NOTHING TOUCHES HARDWARE/g) ?? [];
  assert.equal(hits.length, 1);
  assert.match(sim, /data-kind="caution"/);
});

/* ------------------------------------------------------------------ */
/* Step 3 — generate flow absent, reason sentence present              */
/* ------------------------------------------------------------------ */

test("step 3 markup contains zero user-key generation or PEM import affordances", () => {
  const html = htmlAtStep(3);
  assert.doesNotMatch(html, /data-keyflow="1"/);
  assert.doesNotMatch(html, /data-flow="1"/);
  assert.doesNotMatch(html, /Generate a new key/i);
  assert.doesNotMatch(html, /generate-here/i);
  assert.doesNotMatch(html, /class="flow-pick"/);
  assert.doesNotMatch(html, /Bring your own key/i);
  assert.doesNotMatch(html, /Sign elsewhere/i);
});

test("machine freezes key-flow 1 on this route with KEY_FLOW_FORBIDDEN", () => {
  let state = initialInstallState("update");
  state = reduce(state, { type: "files-picked" });
  state = reduce(state, { type: "release-verified" });
  const chosen = reduce(state, { type: "key-flow-chosen", keyFlow: 1 });
  const last = chosen.stops[chosen.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reasonId, "KEY_FLOW_FORBIDDEN");
  assert.equal(last.reason, STOP_REASONS.KEY_FLOW_FORBIDDEN);
  assert.notEqual(chosen.keyFlow, 1);
});

/* ------------------------------------------------------------------ */
/* Step 5 — no unlock affordance, no unlock command                    */
/* ------------------------------------------------------------------ */

test("unlock button absent from step-5 markup; connect + product + lock read only", () => {
  const html = htmlAtStep(5);
  // No unlock AFFORDANCE may exist: no unlock action, no unlock command, no
  // unlock-labelled control. (Reading the bootloader's protocol variable is
  // required and stays — see the readout assertions below.)
  assert.doesNotMatch(html, /data-action=["']?unlock/i);
  assert.doesNotMatch(html, /flashing\s+unlock/i);
  assert.doesNotMatch(html, />[^<]*unlock[^<]*</i);
  assert.doesNotMatch(html, /\boem\b/i);
  assert.doesNotMatch(html, /data-ack="already/);
  // Connect + product match + lock-state READ are present:
  assert.match(html, /data-device-action="pair"/);
  assert.match(html, /getvar product/);
  assert.match(
    html,
    /data-role="lock-readout" data-var="unlocked"/,
    "protocol-accurate fastboot variable name stays",
  );
  assert.match(html, /bootloader open: \(read happens after pairing\)/);
  assert.match(html, /the lock state is read, never changed/i);
  assert.match(html, /data-ack="state-unchanged"/);
  const escaped = SIDELOAD_NOTE.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  assert.match(html, new RegExp(escaped));
});

test("machine rejects flashing-unlock requests with ROUTE_STEP_FORBIDDEN", () => {
  let state = initialInstallState("update");
  state = reduceUpdate(state, { type: "flashing-unlock-request" });
  const last = state.stops[state.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reasonId, "ROUTE_STEP_FORBIDDEN");
  assert.equal(last.reason, STOP_REASONS.ROUTE_STEP_FORBIDDEN);
  assert.deepEqual([...state.completedSteps], []);

  // Frozen mid-route at step 5: progress unchanged, stop recorded verbatim.
  const atFive = updateModel(5).state;
  const rejected = reduceUpdate(atFive, { type: "flashing-unlock-request" });
  const stop = rejected.stops[rejected.stops.length - 1];
  assert.ok(stop !== undefined);
  assert.equal(stop.reasonId, "ROUTE_STEP_FORBIDDEN");
  assert.equal(rejected.currentStep, 5);
});

/* ------------------------------------------------------------------ */
/* Happy path — full simulated update, transcript without unlock        */
/* ------------------------------------------------------------------ */

/**
 * Stand-in release signer for the happy path. The PEM below is a disposable
 * RSA-3072 keypair generated purely as a test fixture (it signs nothing in
 * the real world); importing it exercises the same code path a real release
 * key would, and the signature over SHA256SUMS is a genuine WebCrypto check —
 * no fixture shortcuts on the gate path.
 */
interface HappyResult {
  readonly finalStep: number;
  readonly transcript: string;
}

async function sha256HexOf(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes as BufferSource);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function driveHappyPath(): Promise<HappyResult> {
  const device = new SimulatedDevice({
    vars: { product: "tokay" },
    initiallyUnlocked: true,
  });
  const logLines: string[] = [];
  const link = linkSimulatedDevice(device, (line) => logLines.push(line));

  const packageName = "GuardTalkOS-tokay-update.zip";
  const packageBytes = utf8("guardtalkos-tokay-update-payload");
  const sumsText = `${await sha256HexOf(packageBytes)}  ${packageName}\n`;
  const result = await runUpdateFlow({
    release: {
      packageName,
      packageBytes,
      sumsText,
    },
    plan: {
      targetProduct: "tokay",
      pkmdBytes: (await signedAnchor()).pkmd,
      firmwareImages: [
        { partition: "bootloader", bytes: utf8("fw-bootloader") },
        { partition: "radio", bytes: utf8("fw-radio") },
      ],
      osImages: [
        { partition: "system", bytes: utf8("os-system") },
        { partition: "vendor", bytes: utf8("os-vendor") },
      ],
      vbmeta: { partition: "vbmeta", bytes: (await signedAnchor()).vbmeta },
    },
    // F-WEBINSTALL-POSTURE-APPROVAL-FLOW acceptance (b): the alpha posture must
    // be approved for this device before the first write, so a happy path has
    // to carry the typed approval.
    postureApproval: { typedCodename: "tokay", forProduct: "tokay" },
    device: link,
  });
  return { finalStep: result.currentStep, transcript: logLines.join("\n") };
}

test("runUpdateFlow REFUSES to write without the alpha-posture approval (no command is sent)", async () => {
  const device = new SimulatedDevice({ vars: { product: "tokay" }, initiallyUnlocked: true });
  const link = linkSimulatedDevice(device);
  const packageName = "GuardTalkOS-tokay-update.zip";
  const packageBytes = utf8("payload-no-approval");
  const sumsText = `${await sha256HexOf(packageBytes)}  ${packageName}\n`;
  const state = await runUpdateFlow({
    release: {
      packageName,
      packageBytes,
      sumsText,
    },
    plan: {
      targetProduct: "tokay",
      pkmdBytes: (await signedAnchor()).pkmd,
      firmwareImages: [{ partition: "boot", bytes: utf8("fw-boot") }],
      osImages: [{ partition: "system", bytes: utf8("os-system") }],
      vbmeta: { partition: "vbmeta", bytes: (await signedAnchor()).vbmeta },
    },
    device: link,
  });
  // The run does the whole read-only preamble and then stops at step 6.
  assert.equal(state.currentStep, 6, "the flow must stop at the decision point");
  assert.equal(state.completedSteps.has(6), false, "step 6 must not be recorded as done");
  const transcript = device.transcript.join("\n");
  assert.doesNotMatch(transcript, /> erase:/, "nothing may be erased without an approval");
  assert.doesNotMatch(transcript, /> flash:/, "nothing may be written without an approval");
  assert.match(transcript, /> getvar:product/, "the read-only preamble still runs");
});

test("runUpdateFlow refuses a mistyped or wrong-product approval too", async () => {
  for (const approval of [
    { typedCodename: "", forProduct: "tokay" as const },
    { typedCodename: "tokay", forProduct: "rango" as const },
    { typedCodename: "TOKAY", forProduct: "tokay" as const },
    { typedCodename: "y", forProduct: "tokay" as const },
  ]) {
    const device = new SimulatedDevice({ vars: { product: "tokay" }, initiallyUnlocked: true });
    const link = linkSimulatedDevice(device);
    const packageName = "GuardTalkOS-tokay-update.zip";
    const packageBytes = utf8(`payload-${approval.typedCodename}-${approval.forProduct}`);
    const sumsText = `${await sha256HexOf(packageBytes)}  ${packageName}\n`;
    const state = await runUpdateFlow({
      release: {
        packageName,
        packageBytes,
        sumsText,
      },
      plan: {
        targetProduct: "tokay",
        pkmdBytes: (await signedAnchor()).pkmd,
        firmwareImages: [{ partition: "boot", bytes: utf8("fw-boot") }],
        osImages: [{ partition: "system", bytes: utf8("os-system") }],
        vbmeta: { partition: "vbmeta", bytes: (await signedAnchor()).vbmeta },
      },
      postureApproval: approval,
      device: link,
    });
    assert.equal(state.currentStep, 6, `approval ${JSON.stringify(approval)} must not open the gate`);
    const transcript = device.transcript.join("\n");
    assert.doesNotMatch(transcript, /> flash:/, `approval ${JSON.stringify(approval)} must write nothing`);
  }
});

test("full update happy path reaches step 9 with NO 'flashing unlock' in the transcript", async () => {
  const { finalStep, transcript } = await driveHappyPath();
  assert.equal(finalStep, 9);
  assert.doesNotMatch(transcript, /flashing unlock/i);
  assert.doesNotMatch(transcript, /flashing:unlock/i);
  // The shipped fastboot commands did happen:
  assert.match(transcript, /> getvar:product/);
  assert.match(transcript, /> flash:avb_custom_key/);
  assert.match(transcript, /> flash:vbmeta/);
  assert.doesNotMatch(transcript, /> erase:avb_custom_key/);
});

/* ------------------------------------------------------------------ */
/* Tamper — verbatim stop reasons from STOP_REASONS                     */
/* ------------------------------------------------------------------ */

test("tampered hash stops at step 2 with the verbatim HASH_MISMATCH reason", () => {
  let state = initialInstallState("update");
  state = reduce(state, { type: "files-picked" });
  const stopped = reduce(state, { type: "stop", step: state.currentStep, condition: "hash-mismatch" });
  assert.equal(stopped.currentStep, 2);
  const last = stopped.stops[stopped.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reason, STOP_REASONS.HASH_MISMATCH);
  assert.equal(last.reason, "hash mismatch — the download does not match SHA256SUMS");
  assert.ok(isHardStopped(stopped));
  assert.equal(reduce(stopped, { type: "files-picked" }).currentStep, 2, "hard stop freezes advancement");

  // Same contract for a broken signature.
  const sigStopped = reduce(state, {
    type: "stop",
    step: state.currentStep,
    condition: "signature-invalid",
  });
  const sigLast = sigStopped.stops[sigStopped.stops.length - 1];
  assert.ok(sigLast !== undefined);
  assert.equal(sigLast.reason, STOP_REASONS.SIGNATURE_INVALID);
});

test("runUpdateFlow stops at step 2 on a tampered package with the verbatim reason", async () => {
  const device = new SimulatedDevice({ vars: { product: "tokay" } });
  const link = linkSimulatedDevice(device);
  const packageName = "GuardTalkOS-tokay-update.zip";
  const sumsText = `${await sha256HexOf(utf8("the real package"))}  ${packageName}\n`;
  const state = await runUpdateFlow({
    release: {
      packageName,
      packageBytes: utf8("TAMPERED PAYLOAD"),
      sumsText,
    },
    plan: {
      targetProduct: "tokay",
      pkmdBytes: utf8("pkmd"),
      firmwareImages: [],
      osImages: [],
      vbmeta: { partition: "vbmeta", bytes: utf8("vbmeta") },
    },
    device: link,
  });
  assert.equal(state.currentStep, 2);
  assert.ok(isHardStopped(state));
  const last = state.stops[state.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reason, STOP_REASONS.HASH_MISMATCH);
  // Nothing reached the device after the stop:
  assert.doesNotMatch(device.transcript.join("\n"), /> flash:/);
});

/* ------------------------------------------------------------------ */
/* CSP + custody sweeps                                                */
/* ------------------------------------------------------------------ */

const CSP_FORBIDDEN_ATTRS = [/\son[a-z]+\s*=/i, /\sstyle\s*=/i];

test("CSP sweep: no inline handlers, no style attributes, no remote references", () => {
  const html = allStepsHtml();
  for (const pattern of CSP_FORBIDDEN_ATTRS) {
    assert.doesNotMatch(html, pattern, `markup violates ${String(pattern)}`);
  }
  const withoutAllowedOrigin = html.replaceAll(RELEASE_FETCH_ORIGIN, "");
  assert.doesNotMatch(withoutAllowedOrigin, /https?:\/\//i);
  assert.match(html, new RegExp(INSTALLER_CSP));
  // No network sinks may exist anywhere in emitted markup:
  assert.doesNotMatch(html, /<script(?![^>]*src="\/)/);
  assert.doesNotMatch(html, /fetch\s*\(|XMLHttpRequest|WebSocket|navigator\.sendBeacon/);
});

test("custody sweep: no private-material sinks; deep-link serialization stays minimal", () => {
  const html = allStepsHtml();
  assert.doesNotMatch(html, /private key/i);
  assert.doesNotMatch(html, /localStorage|sessionStorage|document\.cookie/);
  assert.doesNotMatch(html, /type="password"/);
  // Deep links carry progress only (D-007).
  const snapshot = serialize(initialInstallState("update"));
  const parsed = JSON.parse(snapshot) as Record<string, unknown>;
  assert.deepEqual(Object.keys(parsed).sort(), ["completedSteps", "currentStep", "route"]);
  // No passphrase input anywhere on an update page.
  assert.doesNotMatch(html, /passphrase/i);
});

test("claim lint over route copy: no push-channel phrasing, no auto-advance, no superlatives", () => {
  const source = [
    `const intro = ${JSON.stringify(UPDATE_INTRO)};`,
    `const push = ${JSON.stringify(UPDATE_NO_PUSH)};`,
    `const closing = ${JSON.stringify(CLOSING_SENTENCE)};`,
    `const hidden = ${JSON.stringify(GENERATE_HIDDEN_REASON)};`,
    `const note = ${JSON.stringify(SIDELOAD_NOTE)};`,
  ].join("\n");
  const hits = lintText(source, "route-update-copy", {
    skip: ["generate-in-update"],
  });
  assert.equal(hits.length, 0, `claim lint hits: ${hits.map((hit) => `${hit.rule}: ${hit.text}`).join("; ")}`);
});

test("update route step 5 includes OS-specific USB/udev/driver troubleshooting", () => {
  const html = allStepsHtml();
  assert.match(html, /data-guide="usb-troubleshooting"/);
  assert.match(html, /18d1/);
  assert.match(html, /Google USB Driver/);
});
