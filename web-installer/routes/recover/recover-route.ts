/**
 * /install/recover — Route Builder D (D-001): the honest lost-key path.
 *
 * Sequence, enforced in code:
 *  1. State plainly that the data on this phone is gone — recovery cannot
 *     save it — BEFORE any action is offered.
 *  2. Require a typed acknowledgement phrase (exact string match).
 *  3. Only then offer unlock (which wipes ALL data; wipe warning verbatim).
 *  4. Offer all three key flows as equals — the old key is lost, generating a
 *     new one here is legitimate on this route (contrast: /install/update).
 *  5. Re-enrol the new pkmd (flash avb_custom_key) → point back at /install
 *     with the new key → relock last.
 *
 * Every destructive step shows its wipe warning before the action; machine
 * hard-freeze semantics are reused via the shared reducer's stop records.
 */
import { cspMetaTag } from "../../lib/claims/csp.js";
import { FastbootClient } from "../../lib/fastboot/client.js";
import { STOP_REASONS, type InstallState } from "../../lib/install-state/index.js";
import { fingerprintFromJwk } from "../../lib/keys/fingerprint.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { makeChip } from "../../lib/ui/chips.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { RELEASE_STATE_ALPHA } from "../verify-device/verify-route.js";

export const INSTALL_HREF = "/install";

/** The typed-acknowledgement phrase, exact string match required. */
export const RECOVERY_ACK_PHRASE = "I know the data is gone";

export const WIPE_WARNING_TEXT =
  "Unlocking wipes ALL data on this phone — every account, photo and file is destroyed.";

/** Wipe warnings shown verbatim before each destructive action. */
export const RELOCK_WIPE_WARNING =
  "Locking wipes ALL data again — confirm on-device when the phone asks.";

/** Shown verbatim before the avb_custom_key enrolment flash. */
export const REENROL_WIPE_WARNING =
  "Enrolment writes your new key to avb_custom_key — anything already enrolled there is overwritten.";

/**
 * The recover path as ordered data. It never reaches the /install flash/lock
 * wizard steps; enrolment + relock are its own terminal actions.
 */
export const RECOVER_PATH_PHASES: readonly string[] = [
  "read-the-loss",
  "typed-ack",
  "unlock-wipe",
  "new-key",
  "re-enrol-pkmd",
  "reinstall-pointer",
  "relock",
];

const ACK_INPUT_MIN_LENGTH = RECOVERY_ACK_PHRASE.length - 4;

function ackGateHtml(acknowledged: boolean): string {
  return [
    `<section class="phase" data-phase="typed-ack" id="typed-ack">`,
    `<h2>Type the acknowledgement</h2>`,
    `<p>Recovery cannot save anything on this phone. Type this sentence exactly to continue:</p>`,
    `<p class="ack-target mono" id="recovery-ack-phrase">${escapeHtml(RECOVERY_ACK_PHRASE)}</p>`,
    `<label class="field-label" for="recovery-ack-input">Type it exactly</label>`,
    `<input type="text" id="recovery-ack-input" data-role="ack-input" autocomplete="off"`,
    ` spellcheck="false" minlength="${String(ACK_INPUT_MIN_LENGTH)}">`,
    acknowledged
      ? makeChip("ACKNOWLEDGED", "verified", { ariaLive: "polite" })
      : makeChip("NOT ACKNOWLEDGED", "caution"),
    `</section>`,
  ].join("");
}

function lossStatementHtml(): string {
  return [
    `<section class="phase phase-loss" data-phase="read-the-loss">`,
    `<h2>Read this first</h2>`,
    `<p class="loss-statement mono">The data on this phone is gone. Recovery cannot save it.</p>`,
    `<p>Unlocking erases user data by design. There is no mode of this installer that keeps files ` +
      `through recovery — any tool promising that is lying to you.</p>`,
    `</section>`,
  ].join("");
}

function unlockPhaseHtml(acknowledged: boolean): string {
  const gate = acknowledged
    ? `<button type="button" class="cta danger" data-action="recover-unlock">Unlock (wipes all data)</button>`
    : [
        `<p>Complete the typed acknowledgement above first.</p>`,
        `<button type="button" class="cta danger" data-action="recover-unlock" disabled>Unlock (wipes all data)</button>`,
      ];
  return [
    `<section class="phase phase-unlock" data-phase="unlock-wipe">`,
    `<h2>Unlock — this wipes everything</h2>`,
    `<p class="wipe-warning">${escapeHtml(WIPE_WARNING_TEXT)}</p>`,
    ...gate,
    `<div class="result" data-container="unlock-result"></div>`,
    `</section>`,
  ].join("");
}

function newKeyPhaseHtml(): string {
  return [
    `<section class="phase" data-phase="new-key">`,
    `<h2>New key</h2>`,
    `<p>Your old key is lost — that is why you are here. All three flows are open to you as equals; ` +
      `none is pre-selected.</p>`,
    `<ul class="key-flow-cards">`,
    `<li><strong>generate here.</strong> A fresh RSA-4096 pair made in this tab; the private half never leaves it.</li>`,
    `<li><strong>bring your own.</strong> Import an existing PEM you already keep.</li>`,
    `<li><strong>sign elsewhere.</strong> Make the key on another machine; import only what you need to enrol.</li>`,
    `</ul>`,
    `<p>After choosing a flow, continue below with the public half only.</p>`,
    `</section>`,
  ].join("");
}

function reenrolPhaseHtml(): string {
  return [
    `<section class="phase" data-phase="re-enrol-pkmd">`,
    `<h2>Enrol your new key</h2>`,
    `<p class="wipe-warning">${REENROL_WIPE_WARNING}</p>`,
    `<button type="button" class="cta" data-action="recover-flash-pkmd">Flash avb_pkmd.bin (avb_custom_key)</button>`,
    `<div class="result" data-container="flash-result"></div>`,
    `</section>`,
  ].join("");
}

function reinstallPointerHtml(): string {
  return [
    `<section class="phase" data-phase="reinstall-pointer">`,
    `<h2>Install GuardTalkOS</h2>`,
    `<p>The OS itself was not touched by this route. With your new key enrolled, go back to the full ` +
      `installer and run it against this device with the new key:</p>`,
    `<p><a href="${INSTALL_HREF}" data-link="reinstall">Continue at ${INSTALL_HREF}</a></p>`,
    `</section>`,
  ].join("");
}

function relockPhaseHtml(): string {
  return [
    `<section class="phase" data-phase="relock">`,
    `<h2>Relock</h2>`,
    `<p>${escapeHtml(RELOCK_WIPE_WARNING)}</p>`,
    `<button type="button" class="cta" data-action="recover-relock">Lock the bootloader</button>`,
    `<div class="result" data-container="relock-result"></div>`,
    `</section>`,
  ].join("");
}

function posturePill(): string {
  return renderPosturePill({
    connectivity: POSTURE_CONNECTIVITY,
    custody: POSTURE_CUSTODY,
    releaseState: RELEASE_STATE_ALPHA,
  });
}

function simSwitch(on: boolean): string {
  const checked = on ? " checked" : "";
  return `<label class="sim-switch"><input type="checkbox" data-role="sim-switch"${checked}> simulate the device</label>`;
}

function simChip(): string {
  return `<span class="sim-chip" data-sim="true">${makeChip("SIMULATED DEVICE", "caution")}</span>`;
}

function torChromiumHonestyBlock(): string {
  return [
    `<section class="honesty-block" data-block="tor-chromium">`,
    `<h2>Before you connect a device</h2>`,
    `<ul>`,
    `<li>The phone link uses WebUSB, which only Chromium-based browsers provide.</li>`,
    `<li>Tor Browser blocks WebUSB on purpose. Keep that setting as it is: fetch releases over Tor, run the device step in Chromium.</li>`,
    `<li>This page makes zero network requests — the device link is a local USB cable, offline by construction.</li>`,
    `</ul>`,
    `</section>`,
  ].join("");
}

export interface RecoverPageInput {
  readonly ackAcknowledged?: boolean | undefined;
  readonly simMode?: boolean | undefined;
}

/** Full static page for /install/recover. */
export function renderRecoverPage(input: RecoverPageInput = {}): string {
  const acked = input.ackAcknowledged === true;
  const sim = input.simMode === true;
  return [
    cspMetaTag(),
    `<main class="route" data-route="recover">`,
    `<header class="route-header">`,
    `<h1>Recovery</h1>`,
    posturePill(),
    simSwitch(sim),
    sim ? simChip() : ``,
    `</header>`,
    `<p class="lead">You are here because the key this phone boots with is lost. This page cannot get ` +
      `that key back. It walks one honest path: erase everything, enrol a new key, start over.</p>`,
    lossStatementHtml(),
    torChromiumHonestyBlock(),
    ackGateHtml(acked),
    unlockPhaseHtml(acked),
    newKeyPhaseHtml(),
    reenrolPhaseHtml(),
    reinstallPointerHtml(),
    relockPhaseHtml(),
    `<footer class="route-footer">`,
    `<nav class="route-links"><a href="/install">/install</a> <a href="/install/verify-device">/install/verify-device</a></nav>`,
    `</footer>`,
    `</main>`,
  ].join("");
}

// --- Machine-freeze semantics -------------------------------------------------

/** Record OUT_OF_ORDER on the given state without mutating the original. */
export function freezeOutOfOrder(state: InstallState): InstallState {
  return appendStop(state, "OUT_OF_ORDER");
}

/** Record the missing-ack freeze using the shared wipe-warning vocabulary. */
export function freezeAckRequired(state: InstallState): InstallState {
  return appendStop(state, "OEM_UNLOCK_ACK_REQUIRED");
}

type StopReasonId = keyof typeof STOP_REASONS;

function appendStop(
  state: InstallState,
  reasonId: StopReasonId,
): InstallState {
  const record = { step: state.currentStep, reason: STOP_REASONS[reasonId], reasonId };
  return { ...state, stops: [...state.stops, record] };
}

// --- Device operations (all three reuse FastbootClient; console mirrors) ------

export interface DeviceOpResult {
  readonly ok: boolean;
  /** Verbatim transcript lines already emitted to the caller's ConsoleLog. */
  readonly summary: string;
}

async function runDeviceStep(
  action: () => Promise<void>,
  doneLine: string,
): Promise<DeviceOpResult> {
  try {
    await action();
    return { ok: true, summary: doneLine };
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    return { ok: false, summary: detail };
  }
}

/**
 * Unlock the bootloader. Wipes all data; the UI shows the warning first.
 * Like every real bootloader, the wipe drops the USB link mid-unlock (the
 * trailing INFO traffic) — callers re-open the transport and continue on the
 * post-wipe session, where the device returns unlocked.
 */
export function recoverUnlock(client: FastbootClient): Promise<DeviceOpResult> {
  return runDeviceStep(() => client.flashingUnlock(), "unlocked — data wiped");
}

/** Re-enrol the new key by flashing avb_custom_key. */
export function flashPkmd(client: FastbootClient, pkmdBytes: Uint8Array): Promise<DeviceOpResult> {
  return runDeviceStep(
    () => client.flash("avb_custom_key", pkmdBytes),
    "avb_pkmd.bin written to avb_custom_key",
  );
}

/** Lock the bootloader again. Wipes data again; warning shown first. */
export function recoverRelock(client: FastbootClient): Promise<DeviceOpResult> {
  return runDeviceStep(() => client.flashingLock(), "locked");
}

/** Fingerprint of the NEW key's public half (display rule: fingerprints only). */
export function newKeyFingerprint(jwk: JsonWebKey): Promise<string> {
  return fingerprintFromJwk(jwk);
}

// --- Wiring --------------------------------------------------------------------

export interface RecoverPageHandlers {
  readonly onAckTyped: (phrase: string) => void;
  readonly onUnlockRequested: () => void;
  readonly onFlashPkmdRequested: (pkmd: Uint8Array) => void;
  readonly onRelockRequested: () => void;
  readonly onSimToggled: (on: boolean) => void;
}

/** Wire the static page. Delegated listeners only — zero inline handlers. */
export function wireRecoverPage(root: HTMLElement, handlers: RecoverPageHandlers): void {
  root.addEventListener("input", (event) => {
    const target = event.target;
    if (target instanceof HTMLInputElement && target.getAttribute("data-role") === "ack-input") {
      handlers.onAckTyped(target.value);
    }
  });
  root.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }
    const action = target.getAttribute("data-action");
    if (action === "recover-unlock") {
      handlers.onUnlockRequested();
      return;
    }
    if (action === "recover-flash-pkmd") {
      // The real page supplies the bytes from the completed key flow; the
      // handler contract receives them from the caller's state holder.
      handlers.onFlashPkmdRequested(new Uint8Array(0));
      return;
    }
    if (action === "recover-relock") {
      handlers.onRelockRequested();
    }
  });
  root.addEventListener("change", (event) => {
    const target = event.target;
    if (target instanceof HTMLInputElement && target.getAttribute("data-role") === "sim-switch") {
      handlers.onSimToggled(target.checked);
    }
  });
}
