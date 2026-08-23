/**
 * /install/update — user-driven release updates (DECISION_LOG D-003, D-004).
 *
 * The route shape is owned by lib/install-state (ROUTES.update: steps
 * [1,2,3,4,5,6,8,9]; step-3 flows limited to 2/3). This module renders the
 * page skeleton and step panels from lib/ui primitives and drives the machine
 * through reduceUpdate — a thin wrapper around the pure reducer adding one
 * route rule: an unlock request is recorded as ROUTE_STEP_FORBIDDEN and no
 * unlock command is ever composed here. Updates are full packages the user
 * downloads over Tor, verifies, re-signs with their own key, and flashes;
 * GuardTalk cannot push anything (D-004).
 */
import { cspMetaTag } from "../../lib/claims/csp.js";
import { canFlash, flashBlockers } from "../../lib/install-state/gates.js";
import {
  initialInstallState,
  reduce,
  type InstallAction,
  type InstallState,
  type StopRecord,
} from "../../lib/install-state/machine.js";
import { stepDefinition } from "../../lib/install-state/steps.js";
import { STOP_REASONS } from "../../lib/install-state/stops.js";
import { FastbootClient } from "../../lib/fastboot/client.js";
import { SimulatedDevice } from "../../lib/fastboot/simulated-device.js";
import { sha256Hex } from "../../lib/keys/fingerprint.js";
import { hexEqual, parseSha256Sums, proveVbmetaUserSigned } from "../../lib/verify/index.js";
import { verifyDetached, type RsaPublicJwk } from "../../lib/verify/detached-sig.js";
import { compareHex, type SideBySide } from "../../lib/verify/side-by-side.js";
import { makeChip } from "../../lib/ui/chips.js";
import { consoleMarkup } from "../../lib/ui/console.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { renderRail } from "../../lib/ui/rail.js";
import { renderSideBySideRow } from "../../lib/ui/sidebyside.js";
import type { ConsoleLog } from "../../lib/types.js";

/** Inline sentence shown where flow 1 would sit on /install — D-003. */
export const GENERATE_HIDDEN_REASON =
  "You already hold a key for this phone. " +
  "Generating a new one would lock you out — import the key you kept.";

/** Closing screen sentence, verbatim from PLAN.md §1 step 9. */
export const CLOSING_SENTENCE = "GuardTalk cannot update this phone. Only you can.";

/** Q-08 sideload note: fastboot is the shipped path; sideload is unconfirmed. */
export const SIDELOAD_NOTE =
  "// confirm: a recovery-sideload update path is pending human confirmation (Q-08); " +
  "the fastboot path on this page is the shipped path.";

export const UPDATE_INTRO =
  "This is how every future release arrives: you download the release over Tor, " +
  "you verify it, you re-sign it with YOUR key, and you flash it yourself.";

export const UPDATE_NO_PUSH =
  "GuardTalk cannot push anything to your phone — no server takes part in an update.";

export const UPDATE_PAGE_TITLE = "GuardTalkOS — update your install";

const RELEASE_STATE_ALPHA = "alpha";

export interface UpdatePageModel {
  readonly state: InstallState;
  /** ?sim=1 — identical semantics to the install route: visible chip only. */
  readonly simMode: boolean;
  readonly targetProduct: string;
  readonly enrolledFingerprint?: string;
  readonly typedCompare?: SideBySide;
  readonly deviceProduct?: string;
  /** Live lock readout from the paired device — never a historical claim. */
  readonly lockState?: "locked" | "unlocked";
}

/* ------------------------------------------------------------------ */
/* Route-scoped reducer                                                */
/* ------------------------------------------------------------------ */

export interface UnlockRequestAction {
  readonly type: "flashing-unlock-request";
}

export type UpdateRouteAction = InstallAction | UnlockRequestAction;

/**
 * The machine vocabulary has no unlock action; this wrapper makes the route
 * policy explicit: requesting one records the machine's own ROUTE_STEP_FORBIDDEN
 * reason verbatim and changes nothing else. Every runner transition goes
 * through here.
 */
export function reduceUpdate(state: InstallState, action: UpdateRouteAction): InstallState {
  if (action.type === "flashing-unlock-request") {
    const record: StopRecord = {
      step: state.currentStep,
      reason: STOP_REASONS.ROUTE_STEP_FORBIDDEN,
      reasonId: "ROUTE_STEP_FORBIDDEN",
    };
    return { ...state, stops: [...state.stops, record] };
  }
  return reduce(state, action);
}

/* ------------------------------------------------------------------ */
/* Shared fragments                                                    */
/* ------------------------------------------------------------------ */

function stopReasonAt(state: InstallState, step: number): string | undefined {
  return [...state.stops].reverse().find((stop) => stop.step === step)?.reason;
}

function pendingCompareRow(role: string, label: string, expected: string, actual: string): string {
  return [
    `<div class="sbs-row" data-verdict="PENDING" data-role="${role}">`,
    `<span class="sbs-label">${escapeHtml(label)}</span>`,
    makeChip("PENDING", "caution"),
    `<div class="sbs-columns mono">`,
    `<div class="sbs-col"><span class="sbs-col-head">EXPECTED</span>`,
    `<span class="sbs-value mono">${escapeHtml(expected)}</span></div>`,
    `<div class="sbs-col"><span class="sbs-col-head">ACTUAL</span>`,
    `<span class="sbs-value mono">${escapeHtml(actual)}</span></div>`,
    `</div></div>`,
  ].join("");
}

function stopParagraph(state: InstallState, step: number): string {
  const reason = stopReasonAt(state, step);
  if (reason === undefined) {
    return "";
  }
  return `<p class="rail-stop-reason" data-role="stop-reason">${escapeHtml(reason)}</p>`;
}

/* ------------------------------------------------------------------ */
/* Step panels                                                         */
/* ------------------------------------------------------------------ */

function step1Html(): string {
  return [
    `<h2>${escapeHtml(stepDefinition(1).title)}</h2>`,
    `<p>Download all three files with Tor Browser from the release onion address:</p>`,
    `<p class="mono confirm-marker">// confirm onion address (Q-05)</p>`,
    `<ol class="release-files">`,
    `<li><span class="mono">GuardTalkOS-&lt;release&gt;.zip</span> — the full release package</li>`,
    `<li><span class="mono">SHA256SUMS</span> — digests for every file in the bundle</li>`,
    `<li><span class="mono">SHA256SUMS.sig</span> — the release key&#39;s detached signature over SHA256SUMS</li>`,
    `</ol>`,
    `<label>Package <input type="file" data-role="release-package" aria-label="Release package file"></label>`,
    `<label>Sums <input type="file" data-role="release-sums" aria-label="SHA256SUMS file"></label>`,
    `<label>Signature <input type="file" data-role="release-sig" aria-label="Detached signature file"></label>`,
    `<p>Pick all three to continue. Files stay in this tab — nothing uploads; this page has no network access.</p>`,
  ].join("");
}

function step2Html(model: UpdatePageModel): string {
  return [
    `<h2>${escapeHtml(stepDefinition(2).title)}</h2>`,
    `<p>Every byte you downloaded is compared against SHA256SUMS in this tab, then the detached `,
    `signature is checked against the GuardTalk release key. Any difference stops the flow here.</p>`,
    pendingCompareRow(
      "hash-compare",
      "package hash",
      "digest from SHA256SUMS",
      "SHA-256 computed in this tab",
    ),
    pendingCompareRow(
      "sig-compare",
      "bundle signature",
      "release key signature",
      "verified in this tab",
    ),
    stopParagraph(model.state, 2),
  ].join("");
}

interface FlowCard {
  readonly flow: 2 | 3;
  readonly title: string;
  readonly body: string;
}

const FLOW_CARDS: readonly FlowCard[] = [
  {
    flow: 2,
    title: "Bring your own key",
    body:
      "Import the PEM file you kept when you first enrolled. An encrypted file asks for the " +
      "secret that opens it. Your key fingerprint is derived in this tab and shown for you to record.",
  },
  {
    flow: 3,
    title: "Sign elsewhere",
    body:
      "Export the descriptor set and the avbtool command, sign on another machine, then import " +
      "the signed vbmeta. It is verified against your public key before the flow continues.",
  },
];

function renderKeyChoice(): string {
  const cards = FLOW_CARDS.map((card) =>
    [
      `<section class="flow-card" data-keyflow="${String(card.flow)}">`,
      `<h3>${escapeHtml(card.title)}</h3>`,
      `<p>${escapeHtml(card.body)}</p>`,
      `<button type="button" class="flow-pick" data-keyflow="${String(card.flow)}">` +
        `Choose this flow</button>`,
      `</section>`,
    ].join(""),
  ).join("");
  // Where flow 1 would sit on /install there is deliberately NO card, NO
  // button and NO hidden template — only the reason sentence (D-003).
  const hiddenSlot = [
    `<div class="flow-slot-hidden" data-state="hidden-by-route">`,
    `<p class="flow-hidden-reason">${escapeHtml(GENERATE_HIDDEN_REASON)}</p>`,
    `</div>`,
  ].join("");
  const note =
    `<p class="flow-note">No flow is pre-selected — pick deliberately. ` +
    `The phone will trust only the key you settle on.</p>`;
  return [
    `<h2>${escapeHtml(stepDefinition(3).title)}</h2>`,
    `<div class="flow-cards" role="group" aria-label="Key flows">`,
    cards,
    `</div>`,
    hiddenSlot,
    note,
  ].join("");
}

function step4Html(): string {
  return [
    `<h2>${escapeHtml(stepDefinition(4).title)}</h2>`,
    `<p>Your key re-signs every boot anchor (vbmeta) inside this tab:</p>`,
    `<pre class="mono" data-role="sign-summary">algorithm   SHA256_RSA4096`,
    `key         yours — fingerprint shown once recorded`,
    `new vbmeta  digest appears here after signing</pre>`,
    `<p>Equivalent command from the CLI export path (same order, same args, same files):</p>`,
    `<pre class="mono" data-role="cli-equivalent">avbtool make_vbmeta_image --output vbmeta.img --algorithm SHA256_RSA4096 --key user.pem --padding_size 64</pre>`,
    `<p class="confirm-marker">// confirm partition layout (Q-07): chained vbmeta_* descriptors `,
    `are pending human confirmation; the flow stops with a stated reason when a chain is `,
    `required but unknown.</p>`,
  ].join("\n");
}

function lockStateCopy(lockState: "locked" | "unlocked" | undefined): string {
  if (lockState === "unlocked") {
    return (
      "The bootloader is unlocked. An update flashes through it as it stands — " +
      "the lock state is read, never changed, and no data is wiped."
    );
  }
  if (lockState === "locked") {
    return (
      "The bootloader is locked. This update path does not unlock it. " +
      "If flashing requires an unlocked bootloader, stop here and use the recover path."
    );
  }
  return (
    "Pairing reads the lock state. This page does not claim the bootloader has stayed open — " +
    "only the live readout does. The lock state is read, never changed, and no data is wiped."
  );
}

function step5Html(lockState?: "locked" | "unlocked"): string {
  const readout =
    lockState === undefined
      ? "bootloader open: (read happens after pairing)"
      : `bootloader lock state: ${lockState}`;
  return [
    `<h2>${escapeHtml(stepDefinition(5).title)}</h2>`,
    `<p>Pair the phone over USB. This step reads the product name and the lock state; `,
    `nothing is written to the device here.</p>`,
    `<button type="button" data-device-action="pair">Pair device</button>`,
    pendingCompareRow("product-compare", "product", "this release&#39;s target", "getvar product"),
    `<p class="mono" data-role="lock-readout" data-var="unlocked">${escapeHtml(readout)}</p>`,
    `<p>${escapeHtml(lockStateCopy(lockState))}</p>`,
    `<label class="ack-line">`,
    `<input type="checkbox" data-ack="state-unchanged">`,
    ` I understand this update changes no lock state and wipes no data.`,
    `</label>`,
    `<p class="confirm-note mono">${escapeHtml(SIDELOAD_NOTE)}</p>`,
    `<button type="button" data-step-action="device-match" disabled>` +
      `Continue once the product matches</button>`,
  ].join("");
}

function flashGateHtml(model: UpdatePageModel): string {
  const release = {
    hashesMatch: model.state.completedSteps.has(2),
    signatureValid: model.state.completedSteps.has(2),
  };
  const device = { product: model.deviceProduct ?? "", releaseTargetProduct: model.targetProduct };
  const vbmeta = { signedWithUserKey: model.state.completedSteps.has(4) };
  const blockers = flashBlockers(model.state, release, device, vbmeta);
  const open = canFlash(model.state, release, device, vbmeta);
  const gate = open
    ? [
        makeChip("READY — YOUR SIGNATURE ANCHORS BOOT", "verified"),
        `<button type="button" class="flash-start" data-flash="start">Start flash</button>`,
      ]
    : [
        makeChip("FLASH BLOCKED", "tripwire"),
        `<ul class="flash-blockers">`,
        blockers.map((blocker) => `<li>${escapeHtml(blocker)}</li>`).join(""),
        `</ul>`,
        `<button type="button" class="flash-start" data-flash="start" disabled>Start flash</button>`,
      ];
  return gate.join("");
}

function step6Html(model: UpdatePageModel): string {
  const planRows = [
    `erase avb_custom_key — clear stale enrolment`,
    `flash avb_custom_key — your public key (avb_pkmd.bin)`,
    `flash bootloader, radio, boot, vendor_boot, dtbo — factory firmware`,
    `flash system, system_ext, product, vendor — the GuardTalkOS release`,
    `flash vbmeta LAST — your signature becomes the boot anchor`,
  ]
    .map((row) => `<li>${escapeHtml(row)}</li>`)
    .join("");
  return [
    `<h2>${escapeHtml(stepDefinition(6).title)}</h2>`,
    `<ol class="flash-plan mono">${planRows}</ol>`,
    flashGateHtml(model),
    `<div class="flash-progress" data-role="progress" aria-live="polite"></div>`,
    consoleMarkup([]),
  ].join("");
}

function step8Html(model: UpdatePageModel): string {
  const compare = model.typedCompare === undefined
    ? ""
    : renderSideBySideRow({ label: "boot fingerprint", side: model.typedCompare }).html;
  const stopped = stopReasonAt(model.state, 8);
  const recover = stopped === undefined
    ? ""
    : `<p><a href="/install/recover">Open the recovery path</a></p>`;
  return [
    `<h2>${escapeHtml(stepDefinition(8).title)}</h2>`,
    `<p>Boot the phone once. When the boot screen shows the key fingerprint, type it here. `,
    `It must match the fingerprint of YOUR key recorded earlier.</p>`,
    `<input type="text" class="mono" data-role="boot-fingerprint-input" ` +
      `aria-label="Boot-screen fingerprint" maxlength="64" autocomplete="off" spellcheck="false">`,
    `<p class="mono" data-role="enrolled-fingerprint">` +
      `${escapeHtml(model.enrolledFingerprint ?? "recorded at your key step")}</p>`,
    compare,
    stopParagraph(model.state, 8),
    recover,
  ].join("");
}

function step9Html(): string {
  return [
    `<h2>${escapeHtml(stepDefinition(9).title)}</h2>`,
    `<p class="closing-sentence">${escapeHtml(CLOSING_SENTENCE)}</p>`,
    `<ul class="keep-key-list">`,
    `<li>Keep the encrypted key export switched off unless you need it — it is off by default.</li>`,
    `<li>Store the key file offline, apart from this computer.</li>`,
    `<li>A lost key means the recovery path: it unlocks (wiping everything) and starts from zero.</li>`,
    `</ul>`,
    `<p><a href="/threat-model">What verified boot does not cover</a></p>`,
  ].join("");
}

function stepBodyHtml(model: UpdatePageModel, step: number): string {
  switch (step) {
    case 1:
      return step1Html();
    case 2:
      return step2Html(model);
    case 3:
      return renderKeyChoice();
    case 4:
      return step4Html();
    case 5:
      return step5Html(model.lockState);
    case 6:
      return step6Html(model);
    case 8:
      return step8Html(model);
    case 9:
      return step9Html();
    default:
      throw new Error(`step ${String(step)} is not on the update route`);
  }
}

/* ------------------------------------------------------------------ */
/* Page skeleton                                                       */
/* ------------------------------------------------------------------ */

function simChipHtml(): string {
  return `<p class="sim-chip">${makeChip("SIMULATED DEVICE — NOTHING TOUCHES HARDWARE", "caution")}</p>`;
}

function headerHtml(simMode: boolean): string {
  return [
    `<header class="installer-head">`,
    renderPosturePill({
      connectivity: POSTURE_CONNECTIVITY,
      custody: POSTURE_CUSTODY,
      releaseState: RELEASE_STATE_ALPHA,
    }),
    `<h1>Update your install</h1>`,
    `<p class="route-intro">${escapeHtml(UPDATE_INTRO)}</p>`,
    `<p class="route-intro route-intro-strong">${escapeHtml(UPDATE_NO_PUSH)}</p>`,
    simMode ? simChipHtml() : "",
    `</header>`,
  ].join("");
}

export function renderUpdateInner(model: UpdatePageModel): string {
  const step = model.state.currentStep;
  return [
    headerHtml(model.simMode),
    `<main id="installer-main">`,
    `<nav aria-label="Installer steps">${renderRail(model.state).html}</nav>`,
    `<section class="step-panel" data-route="update" data-step="${String(step)}">`,
    stepBodyHtml(model, step),
    `</section>`,
    `</main>`,
    `<footer class="installer-foot">`,
    `<a href="../recover/">Recovery path (lost key)</a>`,
    `<a href="../../threat-model/">Threat model</a>`,
    `</footer>`,
  ].join("\n");
}

export function renderUpdatePage(model: UpdatePageModel): string {
  return [
    `<!doctype html>`,
    `<html lang="en">`,
    `<head>`,
    `<meta charset="utf-8">`,
    cspMetaTag(),
    `<meta name="viewport" content="width=device-width, initial-scale=1">`,
    `<title>${escapeHtml(UPDATE_PAGE_TITLE)}</title>`,
    `<link rel="stylesheet" href="../styles-route.css">`,
    `</head>`,
    `<body class="route-update" data-route="update">`,
    renderUpdateInner(model),
    `</body>`,
    `</html>`,
  ].join("\n");
}

/* ------------------------------------------------------------------ */
/* Device link + orchestration                                         */
/* ------------------------------------------------------------------ */

/** Narrow surface the update route needs; no unlock operation exists on it. */
export interface UpdateDeviceLink {
  getProduct(): Promise<string>;
  getLockState(): Promise<"locked" | "unlocked">;
  erase(partition: string): Promise<void>;
  flash(partition: string, data: Uint8Array): Promise<void>;
}

/**
 * Wire a SimulatedDevice through FastbootClient so every command lands in the
 * verbatim transcript. Lock state prefers `getvar:unlocked` (the real
 * bootloader variable) and falls back to the simulator flag, which does not
 * script that variable.
 */
export function linkSimulatedDevice(device: SimulatedDevice, log: ConsoleLog = () => {}): UpdateDeviceLink {
  const client = new FastbootClient(device, log);
  return {
    async getProduct() {
      return client.getvar("product");
    },
    async getLockState() {
      try {
        const value = await client.getvar("unlocked");
        return value.trim() === "yes" || value.trim() === "true" ? "unlocked" : "locked";
      } catch {
        return device.unlocked ? "unlocked" : "locked";
      }
    },
    async erase(partition) {
      await client.erase(partition);
    },
    async flash(partition, data) {
      await client.flash(partition, data);
    },
  };
}

export interface UpdateReleaseInput {
  readonly packageName: string;
  readonly packageBytes: Uint8Array;
  readonly sumsText: string;
  readonly sigBytes: Uint8Array;
  readonly releaseKeyJwk: RsaPublicJwk;
}

export interface UpdateFlashPlan {
  readonly targetProduct: string;
  readonly pkmdBytes: Uint8Array;
  readonly firmwareImages: ReadonlyArray<{ readonly partition: string; readonly bytes: Uint8Array }>;
  readonly osImages: ReadonlyArray<{ readonly partition: string; readonly bytes: Uint8Array }>;
  readonly vbmeta: { readonly partition: string; readonly bytes: Uint8Array };
}

export interface UpdateKeypath {
  readonly enrolledFingerprint: string;
  readonly typedFingerprint: string;
}

export interface UpdateRunInput {
  readonly release: UpdateReleaseInput;
  readonly plan: UpdateFlashPlan;
  readonly keypath: UpdateKeypath;
  readonly device: UpdateDeviceLink;
}

/**
 * Drive the full update flow 1→2→3(flow 2)→4→5→6→8→9 against the linked
 * device. Verification failures stop at step 2, a product mismatch at step 5,
 * and a fingerprint mismatch at step 8 — each with the machine's verbatim
 * reason. No unlock command exists anywhere on this path.
 */
export async function runUpdateFlow(input: UpdateRunInput): Promise<InstallState> {
  let state = initialInstallState("update");
  state = reduceUpdate(state, { type: "files-picked" });

  const sums = parseSha256Sums(input.release.sumsText);
  const declared = sums.digestFor(input.release.packageName);
  const actual = await sha256Hex(input.release.packageBytes);
  if (declared === undefined || !hexEqual(declared, actual)) {
    return reduceUpdate(state, { type: "stop", step: state.currentStep, condition: "hash-mismatch" });
  }
  const signature = await verifyDetached(
    input.release.sigBytes,
    input.release.sumsText,
    input.release.releaseKeyJwk,
  );
  if (!signature.valid) {
    return reduceUpdate(state, {
      type: "stop",
      step: state.currentStep,
      condition: "signature-invalid",
    });
  }
  state = reduceUpdate(state, { type: "release-verified" });
  state = reduceUpdate(state, { type: "key-flow-chosen", keyFlow: 2 });
  state = reduceUpdate(state, { type: "fingerprint-recorded" });

  const proof = await proveVbmetaUserSigned(input.plan.vbmeta.bytes, input.plan.pkmdBytes);
  if (!proof.ok) {
    return reduceUpdate(state, {
      type: "stop",
      step: state.currentStep,
      condition: "user-anchor-mismatch",
    });
  }
  state = reduceUpdate(state, { type: "vbmeta-signed" });

  const product = await input.device.getProduct();
  if (product !== input.plan.targetProduct) {
    return reduceUpdate(state, {
      type: "stop",
      step: state.currentStep,
      condition: "product-mismatch",
    });
  }
  await input.device.getLockState();
  state = reduceUpdate(state, { type: "oem-unlock-acked" });
  state = reduceUpdate(state, { type: "device-matched", product });

  const gateOpen = canFlash(
    state,
    { hashesMatch: true, signatureValid: true },
    { product, releaseTargetProduct: input.plan.targetProduct },
    { signedWithUserKey: proof.ok },
  );
  if (!gateOpen) {
    return state;
  }

  await input.device.erase("avb_custom_key");
  await input.device.flash("avb_custom_key", input.plan.pkmdBytes);
  for (const image of input.plan.firmwareImages) {
    await input.device.flash(image.partition, image.bytes);
  }
  for (const image of input.plan.osImages) {
    await input.device.flash(image.partition, image.bytes);
  }
  await input.device.flash(input.plan.vbmeta.partition, input.plan.vbmeta.bytes);
  state = reduceUpdate(state, { type: "flash-step-done" });

  const compare = compareHex(input.keypath.enrolledFingerprint, input.keypath.typedFingerprint);
  if (!compare.match) {
    return reduceUpdate(state, {
      type: "stop",
      step: state.currentStep,
      condition: "boot-fingerprint-mismatch",
    });
  }
  state = reduceUpdate(state, {
    type: "boot-fingerprint-typed",
    fingerprint: input.keypath.typedFingerprint,
  });
  state = reduceUpdate(state, { type: "keep-key-acknowledged" });
  return state;
}
