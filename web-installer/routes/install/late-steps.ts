/**
 * /install steps 5–9 (PLAN.md §1): connect the device, flash, lock, first
 * boot & verify, keep the key. Builder B scope — early-steps.ts (steps 0–4)
 * is owned by Builder A.
 *
 * Every render function here is a PURE markup emitter (no DOM, no timers, no
 * auto-advance); wiring functions attach behaviour to real elements. All
 * comparisons surface through SideBySide-style expected/actual pairs; status
 * is never colour-only (chips carry words). Simulated sessions MUST label
 * themselves visibly in the UI (D-011) via simCautionChip().
 */
import { escapeHtml } from "../../lib/ui/escape.js";
import { makeChip } from "../../lib/ui/chips.js";
import { STOP_REASONS } from "../../lib/install-state/stops.js";
import { consoleMarkup, type ConsoleLineKind } from "../../lib/ui/console.js";
import { INSTALLER_CSP } from "../../lib/claims/csp.js";
import { ProtectionLimit } from "../../lib/claims/components.js";

export const GATEWAY_URL = "https://guardtalk.io/system/gateway";
export const DOCS_URL = "https://guardtalk.io/docs";
export const RECOVERY_URL = "/install/recover";
export const CLI_EXPORT_STEP = 3;

/** The closing sentence of step 9 — exact wording is part of the contract. */
export const CLOSING_SENTENCE = "GuardTalk cannot update this phone. Only you can.";

/** Step-8 hard-stop sentence — exact wording is part of the contract. */
export const BOOT_MISMATCH_SENTENCE =
  "do not use this device — it is not running what you signed";

/**
 * Stated limits (PLAN §5, lens-2 F5/F6): each named limit ships with its
 * /threat-model link wherever the protective claim is made.
 */
export const BOOT_STATE_LIMIT_SENTENCE =
  "Verified boot checks what your key signs — firmware beneath it (baseband, boot ROM) and a compromised signing machine stay outside that check.";

export const GATEWAY_LIMIT_SENTENCE =
  "The Gateway is a network-defence boundary for your messages, not an absolute one — it has limits of its own.";

export const CUSTODY_LIMIT_SENTENCE =
  "Key custody protects the key on this computer; it cannot cover a signing machine already compromised or a key copied without your knowledge.";

/** Devices this installer targets first-class (DECISION_LOG D-012). */
export const TARGET_PRODUCTS: readonly string[] = ["tokay", "rango"];

// --- sim mode (D-011) --------------------------------------------------------

/** Query/env switch forcing SimulatedDevice so E2E runs host-side. */
export function isSimMode(search: string | URLSearchParams, env?: string): boolean {
  const params = search instanceof URLSearchParams ? search : new URLSearchParams(search);
  if (params.get("sim") === "1") {
    return true;
  }
  return env === "1" || env === "true";
}

/** Visible labelling that a session is simulated — required by D-011. */
export const SIM_LABEL = "SIMULATION";

export function simCautionChip(): string {
  return makeChip(`▲ ${SIM_LABEL} · not a live device`, "caution");
}

export function simBannerHtml(sim: boolean): string {
  if (!sim) {
    return "";
  }
  return [
    `<div class="sim-banner" data-sim="true" role="status">`,
    simCautionChip(),
    `<p class="sim-banner-text mono">This session runs against a simulated device. No hardware is touched; results are reproducible and are not evidence of a real flash.</p>`,
    `</div>`,
  ].join("");
}

// --- WebUSB feature detect + step 5 ------------------------------------------

/** True only when a real WebUSB stack is present. Absent ⇒ CLI path leads. */
export function usbAvailable(navigatorRef: unknown): boolean {
  if (typeof navigatorRef !== "object" || navigatorRef === null) {
    return false;
  }
  return "usb" in navigatorRef;
}

export interface DeviceFacts {
  /** `getvar product` readback. */
  readonly product: string;
  readonly targetProduct: string;
  readonly bootloaderVariable: string;
}

export type LockState = "locked" | "unlocked" | "unknown";

export function lockStateFromVar(value: string): LockState {
  if (value === "yes") {
    return "locked";
  }
  if (value === "no") {
    return "unlocked";
  }
  return "unknown";
}

export function lockStateChip(state: LockState): string {
  switch (state) {
    case "locked":
      return makeChip("BOOTLOADER LOCKED", "neutral");
    case "unlocked":
      return makeChip("BOOTLOADER UNLOCKED", "caution");
    default:
      return makeChip("LOCK STATE UNKNOWN", "caution");
  }
}

export interface ProductCheck {
  readonly expected: string;
  readonly actual: string;
  readonly match: boolean;
}

/** Exact-match gate between release target and device readback. */
export function checkProduct(expected: string, actual: string): ProductCheck {
  return { expected, actual, match: expected === actual };
}

export interface ConnectStepViewInput {
  readonly sim: boolean;
  readonly usbPresent: boolean;
  readonly check?: ProductCheck;
  readonly lockState?: LockState;
  readonly oemUnlockAcked: boolean;
  readonly stopped?: string;
}

const OEM_UNLOCK_STEPS: readonly string[] = [
  "On the phone: open Settings → About phone → tap Build number seven times to enable Developer options.",
  "In Settings → System → Developer options: enable OEM unlocking. If it refuses, the device is not yet eligible — stop and re-read the guide.",
  "Reboot into bootloader mode (power off, then hold Power + Volume Down).",
  "From your computer run: fastboot flashing unlock",
  "Confirm on the DEVICE screen with the volume keys and power button. This confirmation exists so a stolen laptop cannot unlock a phone.",
];

/** Second data-wipe warning — explicit acknowledgement gate (oemUnlockAcked). */
export function secondWipeWarning(acked: boolean): string {
  return [
    `<section class="wipe-warning" data-warning="data-wipe">`,
    `<h3 class="mono">Second warning: unlocking wipes ALL data</h3>`,
    `<p>This is not undoable. Photos, messages, accounts, app data — everything on the phone is erased when the bootloader unlocks. Copy anything you need off the device first.</p>`,
    `<label class="ack-row"><input type="checkbox" id="oem-unlock-ack" ${acked ? "checked disabled" : ""}> <span>I understand unlocking erases everything on this phone.</span></label>`,
    `</section>`,
  ].join("");
}

function cliExportPanel(): string[] {
  return [
    `<section class="cli-export-panel" aria-labelledby="cli-export-heading">`,
    `<h2 id="cli-export-heading">No WebUSB? Use the command-line path.</h2>`,
    `<p>Your browser does not expose WebUSB, or you chose not to grant USB access. That is a supported first-class path, not a fallback: step ${String(CLI_EXPORT_STEP)} exports an offline shell script that performs exactly the same operations in exactly the same order.</p>`,
    `<ul class="cli-export-points mono">`,
    `<li>works in any browser, including Firefox and Tor Browser</li>`,
    `<li>same commands, same order as this page — auditable line by line</li>`,
    `<li>runs offline after export; no network access of any kind</li>`,
    `</ul>`,
    `<p><a class="button-link" href="#step-3-export">Go to the step-${String(CLI_EXPORT_STEP)} CLI export</a></p>`,
    `</section>`,
  ];
}

export function connectStepHtml(view: ConnectStepViewInput): string {
  const parts: string[] = [];
  parts.push(simBannerHtml(view.sim));
  parts.push(`<section class="install-step install-step-connect" data-step="5">`);
  parts.push(`<h1>Connect the device.</h1>`);

  if (!view.usbPresent) {
    parts.push(...cliExportPanel());
  }

  parts.push(
    `<div class="pairing-block" data-pairing="${view.usbPresent ? "available" : "absent"}">`,
    view.usbPresent
      ? `<p>Plug the phone in bootloader mode and choose it in the browser's USB picker. Nothing is written to the device in this step.</p>`
      : `<p class="mono">WebUSB unavailable — pairing controls disabled; use the command-line path above.</p>`,
    `<button type="button" class="primary-action" data-action="pair-device"${view.usbPresent ? "" : " disabled"}>Pair device over USB</button>`,
    `</div>`,
  );

  if (view.check !== undefined) {
    const mismatch = !view.check.match;
    parts.push(`<div class="side-by-side product-check" data-check="product" ${mismatch ? 'data-mismatch="true"' : ""}>`);
    parts.push(`<span class="sbs-label mono">product</span>`);
    parts.push(`<span class="sbs-expected mono">expected: ${escapeHtml(view.check.expected)}</span>`);
    parts.push(`<span class="sbs-actual mono">device reports: ${escapeHtml(view.check.actual)}</span>`);
    if (mismatch) {
      parts.push(makeChip("PRODUCT MISMATCH", "tripwire", { ariaLive: "assertive" }));
      parts.push(`<p class="stop-reason tripwire-text">${escapeHtml(STOP_REASONS.PRODUCT_MISMATCH)}</p>`);
    } else {
      parts.push(makeChip("PRODUCT MATCH", "verified"));
    }
    parts.push(`</div>`);
    parts.push(lockStateChip(view.lockState ?? "unknown"));
  }

  parts.push(secondWipeWarning(view.oemUnlockAcked));

  parts.push(`<details class="oem-unlock-guide" data-guide="oem-unlock">`);
  parts.push(`<summary>OEM unlock — how to do it</summary>`);
  parts.push(`<ol class="oem-unlock-steps">`);
  for (const stepLine of OEM_UNLOCK_STEPS) {
    parts.push(`<li>${escapeHtml(stepLine)}</li>`);
  }
  parts.push(`</ol>`);
  parts.push(`<p>The phone will show its own confirmation screen during <code class="mono">fastboot flashing unlock</code>. Unlocking also wipes data again — the checkbox above covers this.</p>`);
  parts.push(`</details>`);

  if (view.stopped !== undefined) {
    parts.push(
      `<div class="hard-stop-banner" role="alert"><span class="tripwire-text mono">STOPPED:</span> <span>${escapeHtml(view.stopped)}</span></div>`,
    );
  }

  parts.push(`</section>`);
  return parts.join("");
}

// --- step 6 ------------------------------------------------------------------

export interface FlashStepViewInput {
  readonly sim: boolean;
  readonly started: boolean;
  readonly failed?: string;
  readonly donePartitions: ReadonlyArray<string>;
  readonly currentPartition?: string;
}

export function flashStepHtml(view: FlashStepViewInput): string {
  const parts: string[] = [];
  parts.push(simBannerHtml(view.sim));
  parts.push(`<section class="install-step install-step-flash" data-step="6">`);
  parts.push(`<h1>Flash GuardTalkOS.</h1>`);
  parts.push(
    `<p class="flash-order-note mono">order: avb_custom_key → bootloader · radio · boot · vendor_boot · dtbo → system · system_ext · product · vendor → vbmeta (last)</p>`,
  );
  parts.push(
    `<p>Every fastboot command and every device response appears verbatim in the console below while flashing proceeds. If any write fails, the flow stops and the output stays on screen.</p>`,
  );
  if (view.started && view.currentPartition !== undefined && view.failed === undefined) {
    parts.push(`<p class="flash-current mono" aria-live="polite">writing: ${escapeHtml(view.currentPartition)}</p>`);
  }
  if (view.donePartitions.length > 0) {
    parts.push(`<ul class="flash-done-list mono">`);
    for (const partition of view.donePartitions) {
      parts.push(`<li data-partition="${escapeHtml(partition)}">done: ${escapeHtml(partition)}</li>`);
    }
    parts.push(`</ul>`);
  }
  if (view.failed !== undefined) {
    parts.push(
      `<div class="hard-stop-banner" role="alert"><span class="tripwire-text mono">FASTBOOT_FAIL:</span> <span>${escapeHtml(STOP_REASONS.FASTBOOT_FAIL)}</span></div>`,
    );
    parts.push(`<p class="fail-reason mono">${escapeHtml(view.failed)}</p>`);
  }
  parts.push(consoleMarkup([]));
  parts.push(`</section>`);
  return parts.join("");
}

/** Map a FastbootClient log line onto a console line kind for display. */
export function consoleKind(line: string): ConsoleLineKind {
  if (line.startsWith("> ")) {
    return "cmd";
  }
  if (line.startsWith("< FAIL")) {
    return "fail";
  }
  if (line.startsWith("< INFO")) {
    return "info";
  }
  if (line.startsWith("< OKAY")) {
    return "ok";
  }
  if (line.startsWith("< DATA")) {
    return "device";
  }
  return "info";
}

// --- step 7 ------------------------------------------------------------------

export interface LockStepViewInput {
  readonly sim: boolean;
  readonly refused?: string;
  readonly locked: boolean;
}

export function lockStepHtml(view: LockStepViewInput): string {
  const parts: string[] = [];
  parts.push(simBannerHtml(view.sim));
  parts.push(`<section class="install-step install-step-lock" data-step="7">`);
  parts.push(`<h1>Lock the bootloader.</h1>`);
  parts.push(
    `<p>Sending <code class="mono">flashing lock</code> re-arms verified boot against YOUR key. Confirming on the device wipes its data one final time — expect one more setup wizard afterwards.</p>`,
  );
  parts.push(`<ol class="lock-steps">`);
  parts.push(`<li>Send the lock command from this page (or run <code class="mono">fastboot flashing lock</code> yourself).</li>`);
  parts.push(`<li>The phone shows its own confirmation screen. Accept it there with the volume keys and power button.</li>`);
  parts.push(`<li>Wait for the wipe to finish and the first boot to begin.</li>`);
  parts.push(`</ol>`);
  if (view.locked) {
    parts.push(lockStateChip("locked"));
  }
  if (view.refused !== undefined) {
    parts.push(
      `<div class="hard-stop-banner" role="alert"><span class="tripwire-text mono">LOCK REFUSED:</span> <span>${escapeHtml(STOP_REASONS.FASTBOOT_FAIL)}</span></div>`,
    );
    parts.push(`<p class="fail-reason mono">${escapeHtml(view.refused)}</p>`);
  }
  parts.push(
    `<div class="boot-state-explainer" data-topic="boot-state">`,
    `<h2>What you should see at every boot</h2>`,
    `<p>A locked bootloader running a custom OS shows a boot-state notice on every start, followed by the fingerprint of YOUR public key — the same hex string recorded at step 3. This screen is the point of the whole exercise: the phone itself now proves, every single boot, that it is running exactly what you signed and nothing else.</p>`,
    `<p class="mono">check the key fingerprint on EVERY boot — it takes two seconds and it is the whole contract.</p>`,
    ProtectionLimit(BOOT_STATE_LIMIT_SENTENCE).html,
    `</div>`,
  );
  parts.push(`</section>`);
  return parts.join("");
}

// --- step 8 ------------------------------------------------------------------

/** Whitespace-insensitive comparison per dispatch: strip, compare exactly. */
export function fingerprintsMatch(typed: string, enrolled: string): boolean {
  return typed.trim() === enrolled.trim();
}

export type VerifyOutcome = "pending" | "match" | "mismatch";

export interface VerifyStepViewInput {
  readonly sim: boolean;
  readonly enrolledFingerprint: string;
  readonly typed?: string;
  readonly outcome?: VerifyOutcome;
}

export function verifyStepHtml(view: VerifyStepViewInput): string {
  const parts: string[] = [];
  parts.push(simBannerHtml(view.sim));
  parts.push(`<section class="install-step install-step-verify" data-step="8">`);
  parts.push(`<h1>First boot &amp; verify.</h1>`);
  parts.push(
    `<p>The phone's first boot shows your key's fingerprint on screen. Type it below — character for character — and this page compares it against the key enrolled in step 3.</p>`,
  );
  parts.push(
    `<div class="enrolled-ref mono" data-enrolled="sha256:pkmd">enrolled: ${escapeHtml(view.enrolledFingerprint)}</div>`,
  );
  parts.push(
    `<form class="verify-form" data-form="boot-fingerprint">`,
    `<label for="boot-fingerprint-input">Type the fingerprint shown on the phone's boot screen</label>`,
    `<input class="mono" id="boot-fingerprint-input" name="boot-fingerprint" type="text" autocomplete="off" spellcheck="false" value="${escapeHtml(view.typed ?? "")}">`,
    `<button type="submit" class="primary-action" data-action="compare-fingerprint">Compare</button>`,
    `</form>`,
  );

  if (view.outcome === "match") {
    parts.push(
      `<div class="verify-result" data-outcome="match">`,
      makeChip("VERIFIED · YOUR KEY", "verified", { ariaLive: "polite" }),
      `<p>The fingerprint on the phone matches the key YOU enrolled. Verified boot is anchored to your signature.</p>`,
      `<div class="gateway-handoff" data-handoff="gateway">`,
      `<h2>Next: the Gateway.</h2>`,
      `<p>Messaging moves to the Gateway service. Open these once, bookmark them, then continue reading step 9 before you rely on this phone.</p>`,
      `<ul class="handoff-links">`,
      `<li><a href="${GATEWAY_URL}" rel="noopener noreferrer">guardtalk.io/system/gateway</a></li>`,
      `<li><a href="${DOCS_URL}" rel="noopener noreferrer">GuardTalkOS documentation</a></li>`,
      `</ul>`,
      ProtectionLimit(GATEWAY_LIMIT_SENTENCE).html,
      `<p class="offline-note mono">these pages load over the network when you open them — this installer itself stays fully offline.</p>`,
      `</div>`,
      `</div>`,
    );
  }

  if (view.outcome === "mismatch") {
    parts.push(
      `<div class="verify-result hard-stop-banner" role="alert" data-outcome="mismatch">`,
      makeChip("BOOT_FINGERPRINT_MISMATCH", "tripwire", { ariaLive: "assertive" }),
      `<p class="tripwire-text">${escapeHtml(BOOT_MISMATCH_SENTENCE)}</p>`,
      `<p class="stop-reason mono">${escapeHtml(STOP_REASONS.BOOT_FINGERPRINT_MISMATCH)}</p>`,
      `<p>If typing was not the problem, treat the installation as compromised and start recovery: <a href="${RECOVERY_URL}">/install/recover</a>.</p>`,
      `</div>`,
    );
  }

  parts.push(`</section>`);
  return parts.join("");
}

// --- step 9 ------------------------------------------------------------------

export function keepKeyStepHtml(sim = false): string {
  const parts: string[] = [];
  parts.push(simBannerHtml(sim));
  parts.push(`<section class="install-step install-step-keep-key" data-step="9">`);
  parts.push(`<h1>Keep the key.</h1>`);
  parts.push(`<div class="custody-recap" data-topic="key-custody">`);
  parts.push(`<h2>Where your private key lives</h2>`);
  parts.push(
    `<p>In the browser flow it exists only as a non-extractable WebCrypto handle inside this tab — it cannot leave by code, and it was never sent anywhere. If you exported an encrypted PEM at step 3, that file plus its passphrase is the ONLY other copy in existence. Store it somewhere you will find again; there is no reset link.</p>`,
  );
  parts.push(`<h2>New computer</h2>`);
  parts.push(
    `<p>Import your encrypted PEM on the new machine and continue with <a href="/install/update">/install/update</a> — it walks verify → sign → flash again without generating anything new.</p>`,
  );
  parts.push(`<h2>Next release</h2>`);
  parts.push(
    `<p>Releases ship as packages you download over Tor and sign yourself; nothing arrives on this phone by itself. Expect the same ritual each time: download, verify, re-sign with your key, flash, lock, check the fingerprint at first boot.</p>`,
  );
  parts.push(ProtectionLimit(CUSTODY_LIMIT_SENTENCE).html);
  parts.push(`</div>`);
  parts.push(`<p class="closing-sentence">${escapeHtml(CLOSING_SENTENCE)}</p>`);
  parts.push(
    `<form class="keep-key-ack-form" data-form="keep-key-ack"><button type="submit" class="primary-action" data-action="finish">I have stored my key and my passphrase</button></form>`,
  );
  parts.push(`</section>`);
  return parts.join("");
}

/** CSP meta tag emitted by the route page shell (D-006, zero runtime network). */
export function lateStepsCspMeta(): string {
  return `<meta http-equiv="Content-Security-Policy" content="${INSTALLER_CSP}">`;
}
