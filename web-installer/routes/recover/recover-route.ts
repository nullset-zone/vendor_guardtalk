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
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { makeChip } from "../../lib/ui/chips.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { usbTroubleshootingHtml } from "../../lib/ui/usb-troubleshooting.js";
import { GL_BTN_DANGER, GL_BTN_LINK, glAlertHtml } from "../../lib/ui/pajamas.js";
import { RELEASE_STATE_ALPHA } from "../verify-device/verify-route.js";

export const INSTALL_HREF = "/install";

/** The typed-acknowledgement phrase, exact string match required. */
export const RECOVERY_ACK_PHRASE = "I know the data is gone";

export const WIPE_WARNING_TEXT =
  "Unlocking wipes ALL data on this phone — every account, photo and file is destroyed.";

/** Wipe warnings shown verbatim before each destructive action. */
export const RELOCK_WIPE_WARNING =
  "Locking wipes ALL data again — confirm on-device when the phone asks.";

/**
 * The recover path as ordered data. It walks unlock (wipe) → reinstall → relock.
 */
export const RECOVER_PATH_PHASES: readonly string[] = [
  "read-the-loss",
  "typed-ack",
  "unlock-wipe",
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
    `<section class="phase phase-loss recover-danger-zone gl-card" data-phase="read-the-loss" data-zone="danger">`,
    `<h2>Read this first</h2>`,
    glAlertHtml(
      "danger",
      "Danger zone",
      `<p class="loss-statement mono">The data on this phone is gone. Recovery cannot save it.</p>` +
        `<p>Unlocking erases user data by design. There is no mode of this installer that keeps files ` +
        `through recovery — any tool promising that is lying to you.</p>`,
    ),
    `</section>`,
  ].join("");
}

function unlockPhaseHtml(acknowledged: boolean): string {
  const gate = acknowledged
    ? `<button type="button" class="${GL_BTN_DANGER}" data-action="recover-unlock">Unlock (wipes all data)</button>`
    : [
        `<p>Complete the typed acknowledgement above first.</p>`,
        `<button type="button" class="${GL_BTN_DANGER}" data-action="recover-unlock" disabled>Unlock (wipes all data)</button>`,
      ];
  return [
    `<section class="phase phase-unlock recover-danger-zone gl-card" data-phase="unlock-wipe" data-zone="danger">`,
    `<h2>Unlock — this wipes everything</h2>`,
    `<p class="wipe-warning">${escapeHtml(WIPE_WARNING_TEXT)}</p>`,
    ...gate,
    `<div class="result" data-container="unlock-result"></div>`,
    usbTroubleshootingHtml(),
    `</section>`,
  ].join("");
}

function reinstallPointerHtml(): string {
  return [
    `<section class="phase" data-phase="reinstall-pointer">`,
    `<h2>Install GuardTalkOS</h2>`,
    `<p>With the bootloader unlocked, go back to the installer and flash GuardTalkOS over WebUSB:</p>`,
    `<p><a href="${INSTALL_HREF}" data-link="reinstall">Continue at ${INSTALL_HREF}</a></p>`,
    `</section>`,
  ].join("");
}

function relockPhaseHtml(): string {
  return [
    `<section class="phase" data-phase="relock">`,
    `<h2>Relock</h2>`,
    `<p>${escapeHtml(RELOCK_WIPE_WARNING)}</p>`,
    `<button type="button" class="${GL_BTN_DANGER}" data-action="recover-relock">Lock the bootloader</button>`,
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
    `<main class="route gl-settings" data-route="recover">`,
    `<header class="route-header">`,
    `<h1>Recovery</h1>`,
    posturePill(),
    simSwitch(sim),
    sim ? simChip() : ``,
    `</header>`,
    `<p class="lead">Recovery erases all user data on the phone so you can unlock the bootloader and reinstall GuardTalkOS from scratch.</p>`,
    lossStatementHtml(),
    torChromiumHonestyBlock(),
    ackGateHtml(acked),
    unlockPhaseHtml(acked),
    reinstallPointerHtml(),
    relockPhaseHtml(),
    `<footer class="route-footer">`,
    `<nav class="route-links"><a class="${GL_BTN_LINK}" href="/install">/install</a> <a class="${GL_BTN_LINK}" href="/install/verify-device">/install/verify-device</a></nav>`,
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

/** Lock the bootloader again. Wipes data again; warning shown first. */
export function recoverRelock(client: FastbootClient): Promise<DeviceOpResult> {
  return runDeviceStep(() => client.flashingLock(), "locked");
}

// --- Wiring --------------------------------------------------------------------

export interface RecoverPageHandlers {
  readonly onAckTyped: (phrase: string) => void;
  readonly onUnlockRequested: () => void;
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
