/**
 * F-WEBINSTALL-POSTURE-APPROVAL-FLOW — acceptance proof (D-042).
 *
 * Acceptance:
 *   (a) `alpha` / `dev/unlocked` / "not GrapheneOS-equivalent" visible at the
 *       decision point;
 *   (b) the acknowledgement is REQUIRED before the destructive step and cannot
 *       be pre-ticked or bypassed;
 *   (c) an unmet posture requirement STOPS the flow;
 *   (d) tests assert (b) and (c) — this file, plus route-update's guard tests;
 *   (e) no new network or storage sink (D-006 `connect-src 'none'`, D-007).
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { initialInstallState, reduce, type InstallState } from "../lib/install-state/machine.js";
import { PACKED_CHANNELS } from "../lib/ui/packed-channels.js";
import {
  ALPHA_RELEASE_STATE,
  DEV_UNLOCKED_CHANNEL,
  NOT_GRAPHENEOS_EQUIVALENT,
  SHIPPED_POSTURE,
  approvalInstruction,
  evaluatePosture,
  postureContradictions,
  postureOpen,
  postureRefusal,
  postureRequirements,
  renderPostureGate,
  type PostureApproval,
  type PostureFacts,
} from "../lib/ui/posture-approval.js";
import { renderUpdatePage } from "../routes/update/update-route.js";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const REL = (rel: string): string => readFileSync(join(ROOT, rel), "utf8");

const APPROVED: PostureApproval = { typedCodename: "tokay", forProduct: "tokay" };

function gate(approval?: PostureApproval, product: "tokay" | "rango" = "tokay"): string {
  return renderPostureGate({
    verdict: evaluatePosture(SHIPPED_POSTURE, product, approval),
    product,
    deviceName: product === "tokay" ? "Pixel 9" : "Pixel 10 Pro Fold",
    ...(approval !== undefined ? { typedCodename: approval.typedCodename } : {}),
  });
}

/** The update route advanced to step 6 — the point where a write is committed. */
function updateStateAtSix(): InstallState {
  let state = initialInstallState("update");
  state = reduce(state, { type: "files-picked" });
  state = reduce(state, { type: "release-verified" });
  state = reduce(state, { type: "key-flow-chosen", keyFlow: 2 });
  state = reduce(state, { type: "fingerprint-recorded" });
  state = reduce(state, { type: "vbmeta-signed" });
  state = reduce(state, { type: "oem-unlock-acked" });
  state = reduce(state, { type: "device-matched", product: "tokay" });
  return state;
}

/* ================================================================== *
 * (a) the posture is legible AT the decision point
 * ================================================================== */

test("(a) the gate states alpha, dev/unlocked and not-GrapheneOS-equivalent in words", () => {
  const html = gate();
  assert.ok(html.includes(ALPHA_RELEASE_STATE), "the release state word must be visible");
  assert.ok(html.includes(DEV_UNLOCKED_CHANNEL), "the channel label must be visible");
  assert.ok(html.includes(NOT_GRAPHENEOS_EQUIVALENT), "the equivalence limit must be visible");
  assert.ok(html.includes("BOOT_VERIFIED=false"), "the boot flag must be visible");
  // Every requirement carries its word, not a colour alone.
  for (const requirement of postureRequirements(SHIPPED_POSTURE)) {
    assert.ok(html.includes(requirement.label), `requirement word missing: ${requirement.label}`);
  }
});

test("(a) the update route renders the gate at step 6, above the flash action", () => {
  const html = renderUpdatePage({
    state: updateStateAtSix(),
    simMode: false,
    targetProduct: "tokay",
    deviceProduct: "tokay",
  });
  assert.match(html, /data-posture-gate="approval-required"/);
  const gateAt = html.indexOf('data-posture-gate="approval-required"');
  const flashAt = html.indexOf('data-flash="start"');
  assert.ok(gateAt >= 0 && flashAt > gateAt, "the posture must be read before the commit control");
  // A closed gate is an assertive, atomic announcement (D-017).
  assert.match(html, /role="alert" aria-live="assertive" aria-atomic="true"/);
});

test("(a) the shipped posture constants still equal the live shipped facts", () => {
  const status = JSON.parse(REL("status.json")) as {
    installer: string;
    releaseState: string;
    preLaunch: boolean;
    keyCustody: string;
    flashCapability: { liveFlashClaimed: boolean };
  };
  assert.equal(SHIPPED_POSTURE.releaseState, status.releaseState);
  assert.equal(SHIPPED_POSTURE.releaseState, status.installer);
  assert.equal(SHIPPED_POSTURE.preLaunch, status.preLaunch);
  assert.equal(SHIPPED_POSTURE.liveFlashClaimed, status.flashCapability.liveFlashClaimed);
  // The channel half is the generated packed-channel data, not a second copy.
  for (const channel of PACKED_CHANNELS) {
    assert.equal(channel.channelLabel, SHIPPED_POSTURE.channelLabel, channel.product);
  }
});

/* ================================================================== *
 * (b) required, not pre-ticked, not bypassable
 * ================================================================== */

test("(b) nothing is pre-ticked: no checkbox, and the text input starts empty", () => {
  const html = gate();
  assert.doesNotMatch(html, /<input[^>]*type="checkbox"/i, "an acknowledgement must not be a checkbox");
  assert.doesNotMatch(html, /<input[^>]*\schecked[\s>]/i, "no control may start checked");
  assert.match(html, /<input[^>]*id="posture-approval"[^>]*value=""/, "the input must start empty");
  assert.match(html, /data-role="posture-approval"/);
  assert.match(html, /data-action="approve-posture"/, "the approval control must be reachable");
  assert.ok(html.includes(approvalInstruction("tokay")), "the exact instruction must be shown");
});

test("(b) no approval ⇒ the gate is closed and every guard gets a refusal", () => {
  const closed = evaluatePosture(SHIPPED_POSTURE, "tokay", undefined);
  assert.equal(closed.kind, "approval-required");
  assert.equal(postureOpen(closed), false);
  const refusal = postureRefusal(closed, "tokay");
  assert.ok(refusal !== undefined && refusal.length > 0);
  assert.match(refusal, /posture requirement/);
  // The refusal names the exact value to type, so a notice is actionable.
  assert.ok(refusal.includes(approvalInstruction("tokay")));
});

test("(b) only the exact codename opens it; every near-miss stays closed", () => {
  const refused = ["", " ", "y", "yes", "true", "ok", "1", "TOKAY", "Tokay", "tokay.", "akita"];
  for (const typed of refused) {
    const verdict = evaluatePosture(SHIPPED_POSTURE, "tokay", { typedCodename: typed, forProduct: "tokay" });
    assert.equal(verdict.kind, "approval-required", `"${typed}" must not open the gate`);
    assert.ok(postureRefusal(verdict, "tokay") !== undefined);
  }
  // Non-vacuity: the exact word, modulo surrounding whitespace, does open it.
  for (const typed of ["tokay", " tokay ", "tokay\n"]) {
    const verdict = evaluatePosture(SHIPPED_POSTURE, "tokay", { typedCodename: typed, forProduct: "tokay" });
    assert.equal(verdict.kind, "approved", `"${typed}" must open the gate`);
    assert.equal(postureRefusal(verdict, "tokay"), undefined);
  }
});

test("(b) an approval is bound to one product and does not carry over", () => {
  const verdict = evaluatePosture(SHIPPED_POSTURE, "rango", APPROVED);
  assert.equal(verdict.kind, "approval-required");
  assert.match(postureRefusal(verdict, "rango") ?? "", /typed for 'tokay', not 'rango'/);
});

test("(b) the /install flash path re-evaluates the verdict before any write", () => {
  const app = REL("routes/install/install-app.ts");
  const start = app.indexOf("async function flashNow(");
  assert.ok(start >= 0, "flashNow must exist");
  const rest = app.slice(start + "async function flashNow(".length);
  const end = rest.search(/\n(?:async )?function /u);
  const body = end < 0 ? rest : rest.slice(0, end);
  const postureAt = body.indexOf("postureRefusal(");
  const runAt = body.indexOf("runFlashPlan(");
  assert.ok(postureAt >= 0, "flashNow must consult the posture verdict");
  assert.ok(runAt >= 0, "flashNow must still call runFlashPlan (non-vacuity)");
  assert.ok(postureAt < runAt, "the posture must be checked before the plan runs");
  assert.match(body.slice(postureAt, runAt), /return;/u, "a refused flash must return before the write");
  // The gate is rendered at the decision point and its approval control is wired.
  assert.match(app, /renderPostureGate\(/);
  assert.match(app, /action === "approve-posture"/);
  assert.match(app, /data-role='posture-approval'/);
});

/* ================================================================== *
 * (c) an unmet requirement stops the flow
 * ================================================================== */

test("(c) a contradictory posture is a STOP that no acknowledgement can open", () => {
  const contradictory: PostureFacts = { ...SHIPPED_POSTURE, liveFlashClaimed: true };
  assert.ok(postureContradictions(contradictory).length > 0);
  const verdict = evaluatePosture(contradictory, "tokay", APPROVED);
  assert.equal(verdict.kind, "stop");
  assert.equal(postureOpen(verdict), false);
  assert.ok(verdict.stopReason !== undefined);
  // A stop has no acknowledgement path: the refusal must not offer one.
  assert.equal(postureRefusal(verdict, "tokay"), verdict.blockers.join(" "));
  assert.equal((postureRefusal(verdict, "tokay") ?? "").includes("Type the device codename"), false);
  // The rendered gate offers NO way to accept it.
  const html = renderPostureGate({ verdict, product: "tokay", deviceName: "Pixel 9" });
  assert.match(html, /data-posture-gate="stop"/);
  assert.doesNotMatch(html, /data-action="approve-posture"/, "a stop must not offer an approval control");
  assert.match(html, /No acknowledgement opens this gate/);
});

test("(c) an unknown release state fails closed instead of being read as acceptable", () => {
  const verdict = evaluatePosture({ ...SHIPPED_POSTURE, releaseState: "beta" }, "tokay", APPROVED);
  assert.equal(verdict.kind, "stop");
  assert.match(postureRefusal(verdict, "tokay") ?? "", /beta/);
});

test("(c) a dev/unlocked channel claiming locked verified boot is a STOP", () => {
  const verdict = evaluatePosture(
    { ...SHIPPED_POSTURE, verifiedBootClaim: "grapheneos-equivalent" },
    "tokay",
    APPROVED,
  );
  assert.equal(verdict.kind, "stop");
});

test("(c) a fully production posture opens with no approval at all (no permanent alarm)", () => {
  const production: PostureFacts = {
    releaseState: "release",
    preLaunch: false,
    liveFlashClaimed: false,
    channelLabel: "locked",
    verifiedBootClaim: "grapheneos-equivalent",
  };
  const verdict = evaluatePosture(production, "tokay", undefined);
  assert.equal(verdict.kind, "pass");
  assert.deepEqual([...verdict.unmet], []);
  assert.equal(postureRefusal(verdict, "tokay"), undefined);
  // ...and the open gate is not an alarm.
  const html = renderPostureGate({ verdict, product: "tokay", deviceName: "Pixel 9" });
  assert.equal(html.includes('role="alert"'), false, "an open gate must not interrupt");
  assert.match(html, /data-posture-gate="pass"/);
});

test("(c) the update route blocks the flash action while the gate is closed", () => {
  const closed = renderUpdatePage({
    state: updateStateAtSix(),
    simMode: false,
    targetProduct: "tokay",
    deviceProduct: "tokay",
  });
  // The flash gate would otherwise be open at this state (steps 2 and 4 are
  // complete and the product matches) — so the disabled control is the posture.
  assert.match(closed, /data-flash="start" disabled/);
  assert.doesNotMatch(closed, /data-flash="start">/, "the commit control must not be live");

  const open = renderUpdatePage({
    state: updateStateAtSix(),
    simMode: false,
    targetProduct: "tokay",
    deviceProduct: "tokay",
    postureApproval: APPROVED,
  });
  assert.match(open, /data-posture-gate="approved"/);
  assert.match(open, /data-flash="start">/, "non-vacuity: the approval opens the commit control");
});

/* ================================================================== *
 * (e) no new network or storage sink
 * ================================================================== */

test("(e) the new modules introduce no network call, no storage, no timer", () => {
  for (const rel of ["lib/ui/posture-approval.ts", "lib/ui/unavailable.ts"]) {
    const source = REL(rel);
    assert.doesNotMatch(
      source,
      /\bfetch\s*\(|XMLHttpRequest|new WebSocket|new EventSource|sendBeacon|importScripts/,
      `${rel}: network sink`,
    );
    assert.doesNotMatch(
      source,
      /localStorage|sessionStorage|indexedDB|document\.cookie|caches\./,
      `${rel}: storage sink`,
    );
    assert.doesNotMatch(source, /setInterval\s*\(/, `${rel}: timer`);
  }
});

test("(e) the gate markup is CSP-safe: no inline handler, no inline style, no URL", () => {
  for (const html of [gate(), gate(APPROVED)]) {
    assert.doesNotMatch(html, /\son[a-z]+\s*=/i, "inline handler");
    assert.doesNotMatch(html, /\sstyle\s*=/i, "inline style");
    assert.doesNotMatch(html, /(?:src|href|action)\s*=\s*["'](?:https?:)?\/\//i, "off-box URL");
  }
});
