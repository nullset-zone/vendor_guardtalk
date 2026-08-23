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
import { INSTALLER_CSP } from "../lib/claims/csp.js";
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
  assert.match(html, /download the release over Tor/);
  assert.match(html, /re-sign it with YOUR key/);
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

test("step 3 markup contains zero generate-flow affordances and the lockout reason", () => {
  const html = htmlAtStep(3);
  // No generate card/button/template of any kind:
  assert.doesNotMatch(html, /data-keyflow="1"/);
  assert.doesNotMatch(html, /data-flow="1"/);
  assert.doesNotMatch(html, /Generate a new key/i);
  assert.doesNotMatch(html, /generate-here/i);
  assert.doesNotMatch(html, /flow-card"[^>]*data-keyflow="1"/);
  assert.equal((html.match(/class="flow-pick"/g) ?? []).length, 2, "only the two allowed flow buttons");
  // Exactly flows 2 and 3 are offered:
  assert.match(html, /data-keyflow="2"/);
  assert.match(html, /data-keyflow="3"/);
  // The reason sentence sits where flow 1 would be:
  assert.ok(html.includes(GENERATE_HIDDEN_REASON));
  assert.match(html, /Generating a new one would lock you out — import the key you kept\./);
  assert.match(html, /class="flow-hidden-reason"/);
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
const RELEASE_SIGNER_PEM = [
  "-----BEGIN PRIVATE KEY-----",
  "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",
  "Ge92VrSDO+cBrmQBuP+EYvusSQ==",
  "-----END PRIVATE KEY-----",
].join("\n");

const RELEASE_PUBLIC_PEM = [
  "-----BEGIN PUBLIC KEY-----",
  "MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAnatSE/z4LRY5CkBQ0s4F",
  "ETfKe1TqfIKD8cZbXY4T1nSEqvKgz+zI4JfYuLmBFVbJLYVbTdY5VIxIAB173ZYP",
  "ST1DQqDGciau+tcmoTc8fyVmtBBOCRm3iUa/sKfH6EdNgZIRkilbf5JlzGAN+g0h",
  "Ym1/vencczSbkIi9kHBL/z7dg5xh1ND3rAt708wfA50z7tG0/j1TcF1mqEQEOROc",
  "FGyDeHxE3hoM1lBdJliFYsQ5Y/7Ykbpe26Kw53hj14IfyaOOssUbSCmdXE9C4uW3",
  "2I/yNGkyk+PzgK4h37tM3juBB9vbQ8akR7QM0Kb5s4+aEhCNI+qyZ7+THDwj2PyW",
  "uSoHFZxC3c/rRoIcMGn4ZtosO3kmvhcZ5eNSouZ5XQWrqXS1KIH56I2JBXdEDb0D",
  "FYdtmOokoYPUe5dZKZ7C3gzEjJ9OZmHODpUjJ2EKQgRahNP81LFrkf0KIi+CtzuO",
  "5L9jhVDjpE2N8TWHgl+82ULNOasQ3Sy0m2EU+UQQQDyTAgMBAAE=",
  "-----END PUBLIC KEY-----",
].join("\n");

function pemBodyBytes(pem: string): Uint8Array {
  const base64 = pem.split(/\r?\n/).filter((line) => !line.includes("-----")).join("");
  return Uint8Array.from(atob(base64), (ch) => ch.charCodeAt(0));
}

async function makeReleaseIdentity(): Promise<{
  jwk: { kty: "RSA"; n: string; e: string };
  sign(text: string): Promise<Uint8Array>;
}> {
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemBodyBytes(RELEASE_SIGNER_PEM) as BufferSource,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const jwk = parseSpkiModulus(pemBodyBytes(RELEASE_PUBLIC_PEM));
  return {
    jwk,
    async sign(text: string): Promise<Uint8Array> {
      const sig = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        privateKey,
        new TextEncoder().encode(text) as BufferSource,
      );
      return new Uint8Array(sig);
    },
  };
}

/** Minimal DER walk of an RSA SPKI blob to the modulus/exponent integers.
 * Purely positional — containers are descended into explicitly — and handles
 * multi-byte DER lengths (an RSA-3072 SPKI is 422 bytes whose lengths use
 * two length bytes). */
function parseSpkiModulus(spki: Uint8Array): { kty: "RSA"; n: string; e: string } {
  function tlv(pos: number): { readonly contentStart: number; readonly contentEnd: number } {
    const tag = spki[pos];
    if (tag === undefined) {
      throw new Error("DER truncated at tag");
    }
    const firstLengthByte = spki[pos + 1];
    if (firstLengthByte === undefined) {
      throw new Error("DER truncated at length");
    }
    let headerLen = 2;
    let length = firstLengthByte;
    if ((length & 0x80) !== 0) {
      const count = length & 0x7f;
      if (count === 0 || count > 4) {
        throw new Error("unsupported DER length form");
      }
      length = 0;
      for (let i = 0; i < count; i += 1) {
        length = length * 256 + (spki[pos + 2 + i] ?? 0);
      }
      headerLen = 2 + count;
    }
    const contentStart = pos + headerLen;
    return { contentStart, contentEnd: contentStart + length };
  }

  const outer = tlv(0);
  const algorithmIdentifier = tlv(outer.contentStart);
  const bitString = tlv(algorithmIdentifier.contentEnd);
  if (spki[bitString.contentStart] !== 0) {
    throw new Error("unexpected BIT STRING padding in SPKI");
  }
  const rsaPublicKey = tlv(bitString.contentStart + 1);
  const modulus = tlv(rsaPublicKey.contentStart);
  const exponent = tlv(modulus.contentEnd);
  return {
    kty: "RSA",
    n: b64url(spki.subarray(modulus.contentStart + 1, modulus.contentEnd)),
    e: b64url(spki.subarray(exponent.contentStart, exponent.contentEnd)),
  };
}

function b64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sha256HexOf(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes as BufferSource);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

interface HappyResult {
  readonly finalStep: number;
  readonly transcript: string;
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
  const identity = await makeReleaseIdentity();
  const sumsText = `${await sha256HexOf(packageBytes)}  ${packageName}\n`;
  const result = await runUpdateFlow({
    release: {
      packageName,
      packageBytes,
      sumsText,
      sigBytes: await identity.sign(sumsText),
      releaseKeyJwk: identity.jwk,
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
    keypath: {
      enrolledFingerprint: "ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12",
      typedFingerprint: "ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12cd34ef56ab12",
    },
    device: link,
  });
  return { finalStep: result.currentStep, transcript: logLines.join("\n") };
}

test("runUpdateFlow refuses a vbmeta that is not signed with the enrolled key", async () => {
  const device = new SimulatedDevice({ vars: { product: "tokay" }, initiallyUnlocked: true });
  const link = linkSimulatedDevice(device);
  const identity = await makeReleaseIdentity();
  const packageName = "GuardTalkOS-tokay-update.zip";
  const packageBytes = utf8("payload");
  const sumsText = `${await sha256HexOf(packageBytes)}  ${packageName}\n`;
  const state = await runUpdateFlow({
    release: {
      packageName,
      packageBytes,
      sumsText,
      sigBytes: await identity.sign(sumsText),
      releaseKeyJwk: identity.jwk,
    },
    plan: {
      targetProduct: "tokay",
      pkmdBytes: (await signedAnchor()).pkmd,
      firmwareImages: [],
      osImages: [],
      vbmeta: { partition: "vbmeta", bytes: utf8("not-a-vbmeta") },
    },
    keypath: { enrolledFingerprint: "aa", typedFingerprint: "aa" },
    device: link,
  });
  assert.equal(state.currentStep, 4);
  assert.ok(isHardStopped(state));
  const last = state.stops[state.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reason, STOP_REASONS.USER_ANCHOR_MISMATCH);
  assert.doesNotMatch(device.transcript.join("\n"), /> flash:/);
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
  assert.match(transcript, /> erase:avb_custom_key/);
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
  const identity = await makeReleaseIdentity();
  const sumsText = `${await sha256HexOf(utf8("the real package"))}  ${packageName}\n`;
  const state = await runUpdateFlow({
    release: {
      packageName,
      packageBytes: utf8("TAMPERED PAYLOAD"),
      sumsText,
      sigBytes: await identity.sign(sumsText),
      releaseKeyJwk: identity.jwk,
    },
    plan: {
      targetProduct: "tokay",
      pkmdBytes: utf8("pkmd"),
      firmwareImages: [],
      osImages: [],
      vbmeta: { partition: "vbmeta", bytes: utf8("vbmeta") },
    },
    keypath: { enrolledFingerprint: "aa", typedFingerprint: "aa" },
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
  assert.doesNotMatch(html, /https?:\/\//i);
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
