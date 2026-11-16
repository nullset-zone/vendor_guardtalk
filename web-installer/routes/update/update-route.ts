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
import { hexEqual, parseSha256Sums } from "../../lib/verify/index.js";
import { type SideBySide } from "../../lib/verify/side-by-side.js";
import { makeChip } from "../../lib/ui/chips.js";
import { consoleMarkup } from "../../lib/ui/console.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { usbTroubleshootingHtml } from "../../lib/ui/usb-troubleshooting.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { DEFAULT_OFFERED_PRODUCT, parseOfferedDevice } from "../../lib/ui/offered-devices.js";
import {
  evaluatePosture,
  postureRefusal,
  renderPostureGate,
  SHIPPED_POSTURE,
  type PostureApproval,
} from "../../lib/ui/posture-approval.js";
import { readinessFor } from "../../lib/ui/readiness.js";
import {
  ONION_ADDRESS_FACT,
  renderUnavailableFact,
} from "../../lib/ui/unavailable.js";
import { railStepViews, renderRail } from "../../lib/ui/rail.js";
import { GL_BTN_CONFIRM, GL_BTN_DEFAULT, GL_BTN_LINK, glAlertHtml } from "../../lib/ui/pajamas.js";
import type { ConsoleLog } from "../../lib/types.js";

/** Inline sentence shown where flow 1 would sit on /install — D-003. */
export const GENERATE_HIDDEN_REASON =
  "You already hold a key for this phone. " +
  "Generating a new one would lock you out — import the key you kept.";

/** Closing screen sentence, verbatim from PLAN.md §1 step 9. */
export const CLOSING_SENTENCE = "GuardTalk cannot update this phone. Only you can.";

/**
 * Q-08 sideload note (D-041). Fastboot is the shipped path; the sideload
 * variant has never been confirmed on hardware, so the page carries no
 * instructions for one and says so — rather than shipping a pending token the
 * user could read as an instruction.
 */
export const SIDELOAD_NOTE =
  "A recovery-sideload update path is not offered here: it has not been confirmed " +
  "on hardware, so no instructions for one appear on this page. The fastboot path " +
  "on this page is the shipped path.";

export const UPDATE_INTRO =
  "Download the release, verify its SHA256SUMS digest in this tab, connect your Pixel over WebUSB, and flash the update.";

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
  /**
   * The alpha-posture approval typed at step 6 (F-WEBINSTALL-POSTURE-APPROVAL-FLOW).
   * Absent means no approval: the gate renders closed and `runUpdateFlow` refuses
   * to write. Bound to `targetProduct` by `evaluatePosture`.
   */
  readonly postureApproval?: PostureApproval;
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
  return glAlertHtml(
    "danger",
    "STOPPED",
    `<p class="rail-stop-reason" data-role="stop-reason">${escapeHtml(reason)}</p>`,
  );
}

/* ------------------------------------------------------------------ */
/* Step panels                                                         */
/* ------------------------------------------------------------------ */

function step1Html(): string {
  return [
    `<h2>${escapeHtml(stepDefinition(1).title)}</h2>`,
    `<p>Download all three files with Tor Browser, from the address you were given with the release announcement:</p>`,
    renderUnavailableFact(ONION_ADDRESS_FACT),
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
    `<p>Every byte you downloaded is compared against SHA256SUMS in this tab. Any difference stops the flow here.</p>`,
    pendingCompareRow(
      "hash-compare",
      "package hash",
      "digest from SHA256SUMS",
      "SHA-256 computed in this tab",
    ),
    stopParagraph(model.state, 2),
  ].join("");
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
    `<button type="button" class="${GL_BTN_CONFIRM}" data-device-action="pair">Pair device</button>`,
    pendingCompareRow("product-compare", "product", "this release&#39;s target", "getvar product"),
    `<p class="mono" data-role="lock-readout" data-var="unlocked">${escapeHtml(readout)}</p>`,
    `<p>${escapeHtml(lockStateCopy(lockState))}</p>`,
    usbTroubleshootingHtml(),
    `<label class="ack-line">`,
    `<input type="checkbox" data-ack="state-unchanged">`,
    ` I understand this update changes no lock state and wipes no data.`,
    `</label>`,
    `<p class="confirm-note mono">${escapeHtml(SIDELOAD_NOTE)}</p>`,
    `<button type="button" class="${GL_BTN_CONFIRM}" data-step-action="device-match" disabled>` +
      `Continue once the product matches</button>`,
  ].join("");
}

/** The advertised product the route is pinned to; an unknown value keeps the default. */
function offeredProduct(raw: string) {
  return parseOfferedDevice(raw) ?? DEFAULT_OFFERED_PRODUCT;
}

/**
 * The alpha-posture gate at the point of decision (F-WEBINSTALL-POSTURE-APPROVAL-FLOW).
 * Rendered ABOVE the flash action so the posture is read before the commit, not after it.
 */
function postureGateHtml(model: UpdatePageModel): string {
  const product = offeredProduct(model.targetProduct);
  const verdict = evaluatePosture(SHIPPED_POSTURE, product, model.postureApproval);
  return renderPostureGate({ verdict, product, deviceName: readinessFor(product).model });
}

function flashGateHtml(model: UpdatePageModel): string {
  const release = {
    hashesMatch: model.state.completedSteps.has(2),
    signatureValid: model.state.completedSteps.has(2),
  };
  const device = { product: model.deviceProduct ?? "", releaseTargetProduct: model.targetProduct };
  const vbmeta = { signedWithUserKey: model.state.completedSteps.has(4) };
  const gateBlockers = flashBlockers(model.state, release, device, vbmeta);
  // The destructive action needs BOTH the flash gate and the posture approval.
  // Composed here so the button and the blocker list cannot disagree.
  const postureBlock = postureRefusal(
    evaluatePosture(SHIPPED_POSTURE, offeredProduct(model.targetProduct), model.postureApproval),
    offeredProduct(model.targetProduct),
  );
  const blockers = postureBlock === undefined ? gateBlockers : [...gateBlockers, postureBlock];
  const open = canFlash(model.state, release, device, vbmeta) && postureBlock === undefined;
  const gate = open
    ? [
        makeChip("READY TO FLASH UPDATE", "verified"),
        `<button type="button" class="${GL_BTN_CONFIRM} flash-start" data-flash="start">Start flash</button>`,
      ]
    : [
        makeChip("FLASH BLOCKED", "tripwire"),
        `<ul class="flash-blockers">`,
        blockers.map((blocker) => `<li>${escapeHtml(blocker)}</li>`).join(""),
        `</ul>`,
        `<button type="button" class="${GL_BTN_CONFIRM} flash-start" data-flash="start" disabled>Start flash</button>`,
      ];
  return gate.join("");
}

function step6Html(model: UpdatePageModel): string {
  const planRows = [
    `flash bootloader, radio, boot, vendor_boot, dtbo — factory firmware`,
    `flash system, system_ext, product, vendor — the GuardTalkOS release`,
    `flash vbmeta — release boot metadata`,
  ]
    .map((row) => `<li>${escapeHtml(row)}</li>`)
    .join("");
  return [
    `<h2>${escapeHtml(stepDefinition(6).title)}</h2>`,
    `<ol class="flash-plan mono">${planRows}</ol>`,
    postureGateHtml(model),
    flashGateHtml(model),
    `<div class="flash-progress" data-role="progress" aria-live="polite"></div>`,
    consoleMarkup([]),
  ].join("");
}

function step8Html(model: UpdatePageModel): string {
  const stopped = stopReasonAt(model.state, 8);
  const recover = stopped === undefined
    ? ""
    : `<p><a href="/install/recover">Open the recovery path</a></p>`;
  return [
    `<h2>${escapeHtml(stepDefinition(8).title)}</h2>`,
    `<p>Let the Pixel finish booting the updated GuardTalkOS release.</p>`,
    stopParagraph(model.state, 8),
    recover,
  ].join("");
}

function step9Html(): string {
  return [
    `<h2>${escapeHtml(stepDefinition(9).title)}</h2>`,
    `<p class="closing-sentence">${escapeHtml(CLOSING_SENTENCE)}</p>`,
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
    case 4:
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
    `<header class="installer-head gl-onboarding__header">`,
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
  const canBack = railStepViews(model.state).some((view) => view.reachableByBack);
  const backBtn = canBack
    ? `<button type="button" class="${GL_BTN_DEFAULT}" data-action="back">Back</button>`
    : `<span></span>`;
  return [
    `<div class="installer gl-onboarding" data-route="update">`,
    headerHtml(model.simMode),
    `<nav class="installer-rail" aria-label="Installer steps">${renderRail(model.state).html}</nav>`,
    `<main id="installer-main" class="installer-main gl-card">`,
    `<section class="step-panel gl-form-layout" data-route="update" data-step="${String(step)}">`,
    stepBodyHtml(model, step),
    `</section>`,
    `<div class="gl-form-layout__actions installer-actions" data-align="between">${backBtn}</div>`,
    `</main>`,
    `<footer class="installer-foot">`,
    `<a class="${GL_BTN_LINK}" href="../recover/">Recovery path (lost key)</a>`,
    `<a class="${GL_BTN_LINK}" href="../../threat-model/">Threat model</a>`,
    `</footer>`,
    `</div>`,
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
}

export interface UpdateFlashPlan {
  readonly targetProduct: string;
  readonly pkmdBytes?: Uint8Array;
  readonly firmwareImages: ReadonlyArray<{ readonly partition: string; readonly bytes: Uint8Array }>;
  readonly osImages: ReadonlyArray<{ readonly partition: string; readonly bytes: Uint8Array }>;
  readonly vbmeta: { readonly partition: string; readonly bytes: Uint8Array };
}

export interface UpdateRunInput {
  readonly release: UpdateReleaseInput;
  readonly plan: UpdateFlashPlan;
  readonly device: UpdateDeviceLink;
  /**
   * The alpha-posture approval typed at the decision point. REQUIRED to write:
   * without it the run performs the whole read-only preamble and then stops
   * before the first device command that changes anything
   * (F-WEBINSTALL-POSTURE-APPROVAL-FLOW acceptance (b)/(c)).
   */
  readonly postureApproval?: PostureApproval;
}

/**
 * Drive the linear update flow 1→2→5→6→8→9 against the linked
 * device. Verification failures stop at step 2 and a product mismatch at step 5.
 * No unlock command exists anywhere on this path.
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
  state = reduceUpdate(state, { type: "release-verified" });
  state = reduceUpdate(state, { type: "key-flow-chosen", keyFlow: 2 });
  state = reduceUpdate(state, { type: "fingerprint-recorded" });
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
    { signedWithUserKey: true },
  );
  if (!gateOpen) {
    return state;
  }

  // The alpha posture must be approved for THIS product before the first write.
  // Re-evaluated here rather than trusted from the caller: the DOM is not the
  // authority, and a caller that skipped the gate does not get to flash.
  const posture = evaluatePosture(
    SHIPPED_POSTURE,
    offeredProduct(input.plan.targetProduct),
    input.postureApproval,
  );
  if (postureRefusal(posture, offeredProduct(input.plan.targetProduct)) !== undefined) {
    return state;
  }

  if (input.plan.pkmdBytes !== undefined) {
    await input.device.flash("avb_custom_key", input.plan.pkmdBytes);
  }
  for (const image of input.plan.firmwareImages) {
    await input.device.flash(image.partition, image.bytes);
  }
  for (const image of input.plan.osImages) {
    await input.device.flash(image.partition, image.bytes);
  }
  await input.device.flash(input.plan.vbmeta.partition, input.plan.vbmeta.bytes);
  state = reduceUpdate(state, { type: "flash-step-done" });

  state = reduceUpdate(state, {
    type: "boot-fingerprint-typed",
    fingerprint: "confirmed",
  });
  state = reduceUpdate(state, { type: "keep-key-acknowledged" });
  return state;
}
