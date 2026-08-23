/**
 * /install/verify-device — Route Builder D (D-002).
 *
 * Exactly two capabilities, offered as equals:
 *  (a) READ — ask the bootloader for the enrolled AVB public-key hash via
 *      getvar candidates; a missing/unparsable answer is reported plainly and
 *      falls through to (b). Nothing is ever guessed.
 *  (b) COMPARE — guided boot-screen fingerprint entry, compared against the
 *      user's pkmd fingerprint (public half only, derived in-tab).
 *
 * Output is a side-by-side EXPECTED (your key fingerprint) | ACTUAL
 * (device-reported) with a MATCH/MISMATCH word chip. MISMATCH raises the
 * BOOT_FINGERPRINT_MISMATCH hard stop with the binding sentence and a link to
 * /install/recover. This route flashes NOTHING — no write verb exists here.
 *
 * Machine integration: the shared reducer owns the route subset ([5, 8]) and
 * the hard-freeze on mismatch. Because the two capabilities are equals rather
 * than a sequential wizard, this page never fabricates machine events (no
 * synthetic acks) — it renders the rail data and records the mismatch stop.
 */
import { cspMetaTag } from "../../lib/claims/csp.js";
import {
  STOP_REASONS,
  flashBlockers,
  initialInstallState,
  reduce,
  stepsForRoute,
  type InstallState,
} from "../../lib/install-state/index.js";
import { isHardStopped } from "../../lib/install-state/machine.js";
import { FastbootClient, FastbootError } from "../../lib/fastboot/client.js";
import { ProtocolError } from "../../lib/fastboot/protocol.js";
import { fingerprintFromJwk } from "../../lib/keys/fingerprint.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { makeChip } from "../../lib/ui/chips.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { renderSideBySideRow } from "../../lib/ui/sidebyside.js";
import { compareHex, type SideBySide } from "../../lib/verify/side-by-side.js";

export const RELEASE_STATE_ALPHA = "alpha";

/** Binding mismatch sentence (PLAN.md §1 step 8). */
export const BOOT_FINGERPRINT_MISMATCH_SENTENCE =
  "do not use this device — it is not running what you signed";

export const RECOVERY_HREF = "/install/recover";

/** Route subset as data — mirrored from lib/install-state/steps.ts. */
export const VERIFY_DEVICE_ROUTE_STEPS: readonly number[] = stepsForRoute("verify-device");

/**
 * Candidate getvar names for the enrolled key hash. Bootloaders differ;
 * every name is tried in order and each answer is reported verbatim. A FAIL
 * on a name is a fact about the device, never a guessed value.
 */
export const ENROLLED_KEY_GETVAR_NAMES: readonly string[] = [
  "avb_custom_key",
  "avb_pkmd_hash",
  "avb_fingerprint",
];

export interface ReadAttempt {
  readonly variable: string;
  readonly outcome: "ok" | "fail" | "protocol-error";
  /** Verbatim device payload or error text — printed to the console. */
  readonly detail: string;
}

export type EnrolledKeyRead =
  | {
      readonly kind: "exposed";
      readonly variable: string;
      readonly normalizedHex: string;
      readonly attempts: readonly ReadAttempt[];
    }
  | {
      readonly kind: "unreadable";
      readonly variable: string;
      readonly rawValue: string;
      readonly attempts: readonly ReadAttempt[];
    }
  | { readonly kind: "not-exposed"; readonly attempts: readonly ReadAttempt[] };

export interface VerifyPageInput {
  readonly simMode?: boolean | undefined;
}

export interface VerifyPageHandlers {
  readonly onReadRequested: () => void;
  readonly onCompareRequested: (typed: string) => void;
  readonly onSimToggled: (on: boolean) => void;
}

const HASH_RE = /^[0-9a-f]{16,128}$/;

/**
 * Normalize a device-reported hash: strip `sha256:`/`0x` prefixes, colons and
 * whitespace, lowercase. Returns null when what remains is not plausibly a
 * hex digest — the caller treats null as "unusable answer", never a guess.
 */
export function normalizeReportedHash(raw: string): string | null {
  const stripped = raw
    .trim()
    .replace(/^sha256:/i, "")
    .replace(/^0x/i, "")
    .replace(/[\s:]/g, "")
    .toLowerCase();
  if (!HASH_RE.test(stripped)) {
    return null;
  }
  return stripped;
}

/**
 * Capability (a): ask every known getvar name for the enrolled key hash.
 * FAIL answers are recorded verbatim and the next name is tried. Transport
 * failures propagate loudly — a dead link is not "not exposed".
 */
export async function readEnrolledKeyHash(client: FastbootClient): Promise<EnrolledKeyRead> {
  const attempts: ReadAttempt[] = [];
  for (const variable of ENROLLED_KEY_GETVAR_NAMES) {
    try {
      const raw = await client.getvar(variable);
      attempts.push({ variable, outcome: "ok", detail: raw });
      const normalized = normalizeReportedHash(raw);
      if (normalized === null) {
        return { kind: "unreadable", variable, rawValue: raw, attempts: [...attempts] };
      }
      return { kind: "exposed", variable, normalizedHex: normalized, attempts: [...attempts] };
    } catch (err) {
      if (err instanceof FastbootError) {
        attempts.push({ variable, outcome: "fail", detail: err.reason });
      } else if (err instanceof ProtocolError) {
        attempts.push({ variable, outcome: "protocol-error", detail: err.message });
      } else {
        throw err;
      }
    }
  }
  return { kind: "not-exposed", attempts: [...attempts] };
}

/**
 * Derive the EXPECTED half from the user's PUBLIC key half only. A JWK that
 * carries private fields is refused outright — private material never enters
 * this page (D-007 display rule).
 */
export async function expectedFingerprintFromPublicJwk(jwk: JsonWebKey): Promise<string> {
  if (jwk.d !== undefined || jwk.p !== undefined || jwk.q !== undefined) {
    throw new Error("expected the public half only — refusing a JWK with private fields");
  }
  return fingerprintFromJwk(jwk);
}

/** Normalize the typed boot-screen value (whitespace/colons tolerated). */
export function normalizeTypedFingerprint(typed: string): string {
  return typed.trim().toLowerCase().replace(/[\s:]/g, "");
}

export type CompareOutcome =
  | { readonly kind: "invalid-input"; readonly typed: string }
  | { readonly kind: "compared"; readonly side: SideBySide; readonly verdict: "MATCH" | "MISMATCH" };

/** Capability (b): typed boot-screen value vs the user's key fingerprint. */
export function bootScreenCompare(expectedHex: string, typed: string): CompareOutcome {
  const cleaned = normalizeTypedFingerprint(typed);
  if (!HASH_RE.test(cleaned)) {
    return { kind: "invalid-input", typed };
  }
  const side = compareHex(expectedHex.trim().toLowerCase(), cleaned);
  return { kind: "compared", side, verdict: side.match ? "MATCH" : "MISMATCH" };
}

/** Record the machine hard stop for a fingerprint mismatch. */
export function recordBootMismatchStop(state: InstallState): InstallState {
  return reduce(state, { type: "stop", step: state.currentStep, condition: "boot-fingerprint-mismatch" });
}

/**
 * Flash is impossible on this route by policy AND by machine gates: the route
 * subset never reaches step 6, so every gate reports a blocker. Non-empty for
 * any verify-device state, whatever the caller claims elsewhere.
 */
export function flashBlockersOnVerifyDevice(): readonly string[] {
  const machineBlockers = flashBlockers(
    initialInstallState("verify-device"),
    { hashesMatch: false, signatureValid: false },
    { product: "", releaseTargetProduct: RELEASE_STATE_ALPHA },
    { signedWithUserKey: false },
  );
  return [
    "this route never flashes — verify-device exposes read and compare only",
    ...machineBlockers,
  ];
}

export function renderHardStopBanner(): string {
  return [
    `<div class="hard-stop" data-hard-stop="true" data-stop-id="BOOT_FINGERPRINT_MISMATCH" role="alert">`,
    makeChip("STOPPED", "tripwire", { ariaLive: "assertive" }),
    `<p class="stop-id mono">BOOT_FINGERPRINT_MISMATCH</p>`,
    `<p>${escapeHtml(STOP_REASONS.BOOT_FINGERPRINT_MISMATCH)}</p>`,
    `<p class="binding-sentence mono">${escapeHtml(BOOT_FINGERPRINT_MISMATCH_SENTENCE)}</p>`,
    `<p><a href="${RECOVERY_HREF}" data-link="recovery">Recovery path: ${RECOVERY_HREF}</a></p>`,
    `</div>`,
  ].join("");
}

function sideBySideHtml(side: SideBySide, label: string): string {
  return renderSideBySideRow({ label, side }).html;
}

/** Render the READ outcome: plain statements, side-by-side, hard stop on mismatch. */
export function renderReadOutcome(read: EnrolledKeyRead, expectedFingerprintHex: string): string {
  const parts: string[] = [];
  if (read.kind === "not-exposed") {
    parts.push(
      `<p class="read-status" data-read-state="not-exposed">Not exposed. This bootloader did not ` +
        `publish the enrolled key hash — every known variable name came back FAIL. Nothing was guessed.</p>`,
      `<p><a href="#compare-boot-screen" data-link="fall-through">Use the boot-screen comparison below instead.</a></p>`,
    );
    return parts.join("");
  }
  if (read.kind === "unreadable") {
    parts.push(
      `<p class="read-status" data-read-state="unreadable">Unusable answer. The device replied to ` +
        `<code>getvar:${escapeHtml(read.variable)}</code> with something this installer cannot parse as a hash: ` +
        `<code class="mono">${escapeHtml(read.rawValue)}</code>. It is treated as not verified — ` +
        `use the boot-screen comparison below.</p>`,
      `<p><a href="#compare-boot-screen" data-link="fall-through">Go to the comparison.</a></p>`,
    );
    return parts.join("");
  }
  parts.push(
    `<p class="read-status" data-read-state="exposed">The device published its enrolled key hash via ` +
      `<code>getvar:${escapeHtml(read.variable)}</code>.</p>`,
  );
  const side = compareHex(expectedFingerprintHex.trim().toLowerCase(), read.normalizedHex);
  parts.push(sideBySideHtml(side, `enrolled key (${read.variable})`));
  if (!side.match) {
    parts.push(renderHardStopBanner());
  }
  return parts.join("");
}

/** Render the COMPARE outcome for a typed boot-screen value. */
export function renderCompareOutcome(
  expectedHex: string,
  typed: string,
): { readonly html: string; readonly verdict: "MATCH" | "MISMATCH" | "INVALID_INPUT"; readonly hardStop: boolean } {
  const outcome = bootScreenCompare(expectedHex, typed);
  if (outcome.kind === "invalid-input") {
    return {
      html:
        `<p class="compare-status" data-compare-state="invalid-input">That is not a fingerprint. ` +
        `Hexadecimal characters only — type the value exactly as the boot screen shows it.</p>`,
      verdict: "INVALID_INPUT",
      hardStop: false,
    };
  }
  const html = [
    sideBySideHtml(outcome.side, "boot fingerprint"),
    outcome.verdict === "MISMATCH" ? renderHardStopBanner() : "",
  ].join("");
  return { html, verdict: outcome.verdict, hardStop: outcome.verdict === "MISMATCH" };
}

/** Tor/Chromium honesty block — required wherever a device link is involved. */
export function torChromiumHonestyBlock(): string {
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

function comparePanel(): string {
  return [
    `<section class="capability" data-step="8" data-capability="compare" id="compare-boot-screen">`,
    `<h2>Compare the boot-screen fingerprint — step 8</h2>`,
    `<ol class="compare-guide">`,
    `<li>Boot the phone and wait for the boot screen.</li>`,
    `<li>Find the fingerprint line — a long hexadecimal string tied to your key.</li>`,
    `<li>Type it exactly as shown, character for character.</li>`,
    `</ol>`,
    `<label class="field-label" for="boot-fingerprint-input">Boot-screen fingerprint</label>`,
    `<input type="text" id="boot-fingerprint-input" data-role="boot-fingerprint-input" autocomplete="off" spellcheck="false">`,
    `<button type="button" class="cta" data-action="compare-boot-screen">Compare fingerprint</button>`,
    `<div class="result" data-container="compare-result"></div>`,
    `</section>`,
  ].join("");
}

function readPanel(): string {
  return [
    `<section class="capability" data-step="5" data-capability="read" id="read-enrolled-key">`,
    `<h2>Read the enrolled key — step 5</h2>`,
    `<p>Some bootloaders answer getvar requests with the hash of the enrolled AVB public key. ` +
      `Every known variable name is asked, each answer is printed verbatim in the console, and nothing is ` +
      `guessed: if the device does not publish it, this page says so and hands you to the comparison.</p>`,
    `<button type="button" class="cta" data-action="read-enrolled-key">Ask the device</button>`,
    `<div class="result" data-container="read-result"></div>`,
    `</section>`,
  ].join("");
}

/** Full static page. Dynamic areas fill at runtime via the wire function. */
export function renderVerifyDevicePage(input: VerifyPageInput = {}): string {
  const sim = input.simMode === true;
  return [
    cspMetaTag(),
    `<main class="route" data-route="verify-device">`,
    `<header class="route-header">`,
    `<h1>Verify this device</h1>`,
    posturePill(),
    simSwitch(sim),
    sim ? simChip() : ``,
    `</header>`,
    `<p class="lead">Does this phone boot with your key? Two equal capabilities answer that — read the ` +
      `enrolled key hash where the bootloader publishes it, or compare the boot-screen fingerprint by eye ` +
      `and keyboard. Nothing is written to the device here; this route flashes nothing.</p>`,
    torChromiumHonestyBlock(),
    readPanel(),
    comparePanel(),
    `<footer class="route-footer">`,
    `<p>This route never writes to the device. Flashing lives on /install only, behind its own gates.</p>`,
    `<nav class="route-links"><a href="/install">/install</a> <a href="/install/recover">/install/recover</a></nav>`,
    `</footer>`,
    `</main>`,
  ].join("");
}

/** Wire the static page. Delegated listeners only — zero inline handlers. */
export function wireVerifyPage(root: HTMLElement, handlers: VerifyPageHandlers): void {
  root.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }
    const action = target.getAttribute("data-action");
    if (action === "read-enrolled-key") {
      handlers.onReadRequested();
      return;
    }
    if (action === "compare-boot-screen") {
      const input = root.querySelector<HTMLInputElement>('input[data-role="boot-fingerprint-input"]');
      handlers.onCompareRequested(input?.value ?? "");
    }
  });
  root.addEventListener("change", (event) => {
    const target = event.target;
    if (target instanceof HTMLInputElement && target.getAttribute("data-role") === "sim-switch") {
      handlers.onSimToggled(target.checked);
    }
  });
}

/** Convenience for callers driving the real flow headlessly. */
export function isVerifyHardStopped(state: InstallState): boolean {
  return isHardStopped(state);
}

export function newVerifyDeviceState(): InstallState {
  return initialInstallState("verify-device");
}
