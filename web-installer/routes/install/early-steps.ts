/**
 * /install — steps 0–4 (Route Builder A, Phase 3).
 *
 * Pre-flight → release intake → client-side verification → key custody →
 * vbmeta re-sign. Every screen is a pure renderer over lib/* models plus
 * pure decision functions the shell wires to named machine actions
 * (lib/install-state is the ONLY state authority; nothing here advances
 * on timers, and every button maps to exactly one named machine action).
 *
 * Copy contract (PLAN.md §5): headlines are sentences with a full stop,
 * protective verbs only, chips always carry their word, every limit links
 * /threat-model, signal green only for VERIFIED states, tripwire only for
 * failures. A value the project does not have ships as an honest
 * "unavailable — do not proceed" block (`lib/ui/unavailable.ts`): what is
 * missing, where the absence is recorded, what the user must do, and what it
 * blocks. Nothing is invented, and no pending-confirmation token is shipped
 * (F-WEBINSTALL-PLACEHOLDER-RETIREMENT, D-041).
 *
 * Custody contract (PLAN.md §2, D-007): private material never enters any
 * emitted string; only fingerprints/hashes (public halves) are displayed.
 */
import { STOP_REASONS } from "../../lib/install-state/stops.js";
import type { InstallState } from "../../lib/install-state/machine.js";
import { railStepViews, renderRail } from "../../lib/ui/rail.js";
import { makeChip } from "../../lib/ui/chips.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { GL_BTN_CONFIRM, GL_BTN_DEFAULT, glAlertHtml } from "../../lib/ui/pajamas.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { renderSideBySideRow } from "../../lib/ui/sidebyside.js";
import { Hardening, LineageNote, ProtectionLimit } from "../../lib/claims/components.js";
import { RELEASE_FETCH_ORIGIN } from "../../lib/claims/csp.js";
import {
  ONION_ADDRESS_FACT,
  RELEASE_FINGERPRINT_FACT,
  renderUnavailableFact,
} from "../../lib/ui/unavailable.js";
import {
  compareHex,
  type SideBySide,
} from "../../lib/verify/side-by-side.js";
import { parseSha256Sums, SumsParseError } from "../../lib/verify/sums.js";
import { sha256Hex } from "../../src/hash.js";
import {
  DEFAULT_OFFERED_PRODUCT,
  KOMODO_STAMP_HONESTY,
  WIZARD_DEVICES,
  channelChipWord,
  hasChannelAndAdvertised,
  isOfferedDevice,
  parseOfferedDevice,
  statusChipWord,
  statusJsonChipWord,
  statusJsonFact,
  type OfferedProduct,
} from "../../lib/ui/offered-devices.js";
import { hasPackedChannel } from "../../lib/ui/packed-channels.js";
import {
  BOOT_VERIFIED,
  READINESS_PROVENANCE,
  readinessChipWord,
  readinessFor,
  tierPolicy,
  type ReadinessTier,
} from "../../lib/ui/readiness.js";

// ---------------------------------------------------------------------------
// PICKER-TRUTH selectability — the two facts composed in ONE place
// ---------------------------------------------------------------------------

/**
 * Selectable = advertised AND has a packed channel AND the host offers its
 * readiness tier. F-WEBINSTALL-FLASHALL-PICKER-TRUTH acceptance (a) is the
 * conjunction: a packed channel on a non-offerable tier is still a dead end, and
 * an offerable tier with no channel has nothing to write. The channel half lives
 * in `offered-devices.ts` (`hasChannelAndAdvertised`) because `readiness.js`
 * imports that module and a back-import would cycle; the composition happens
 * here, which already imports both.
 */
export function isSelectableProduct(product: string): boolean {
  if (!isOfferedDevice(product)) {
    return false;
  }
  return hasChannelAndAdvertised(product) && isOfferableInUi(readinessFor(product).tier);
}

function isOfferableInUi(tier: string): boolean {
  return tierPolicy(tier)?.offerable === true;
}

/**
 * Why a product cannot be selected, or `undefined` when it can. The refusal
 * names the missing fact (no channel vs a non-offerable tier) rather than
 * leaving a dead end.
 */
export function channelRefusal(product: string): string | undefined {
  if (!isOfferedDevice(product)) {
    return undefined;
  }
  if (!hasPackedChannel(product)) {
    return `Device '${product}' is advertised but has no packed channel on this build, so it cannot be selected or flashed. Nothing is offered for it until a channel is packed.`;
  }
  if (!isOfferableInUi(readinessFor(product).tier)) {
    const tier = readinessFor(product).tier;
    return `Device '${product}' is packed but its readiness tier is ${tier} (${readinessChipWord(tier)}), which this installer does not offer for flashing.`;
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Binding copy constants
// ---------------------------------------------------------------------------

/** Step-0 CTA — exact label mandated by the build brief. */
export const ACK_CTA_LABEL = "I understand — begin →";

/**
 * F-WEBINSTALL-PLACEHOLDER-RETIREMENT (D-041). The four pending-confirmation
 * constants that used to live here are retired:
 *
 *   Q-05 release onion address      → UNAVAILABLE (`ONION_ADDRESS_FACT`)
 *   Q-04 release-key fingerprint    → UNAVAILABLE (`RELEASE_FINGERPRINT_FACT`)
 *   Q-07 chained partition layout   → UNAVAILABLE (`PARTITION_LAYOUT_FACT`)
 *   Q-06 device name                → RESOLVED: the fact is `deviceName` in
 *                                     `wizard/devices.ts` ("Pixel 10 Pro Fold",
 *                                     DEC-WEBINSTALL-015). It renders in the
 *                                     step-0 table and is pinned by
 *                                     `test/wizard-gating.test.ts:34`, so the
 *                                     constant had no consumer and is deleted
 *                                     rather than kept as a second copy.
 *
 * No value replaced the three unavailable ones: each renders through
 * `lib/ui/unavailable.ts`, which names what is missing, what to do instead,
 * and what it blocks.
 */

export interface SupportedTarget {
  readonly codename: string;
  readonly deviceName: string;
  readonly status: "supported" | "experimental";
  /** Host-reported readiness tier, derived into the manifest (never hand-written). */
  readonly readiness: ReadinessTier;
  readonly readinessReason: string;
  readonly readinessRemedy: string;
  readonly offerable: boolean;
  /** True for acknowledgement-gated tiers (READY-ACK, BUILD-OK); drives the gate. */
  readonly requiresAcknowledgement: boolean;
}

/** Advertised set from wizard/devices.ts (DEC-WEBINSTALL-015). Rango is experimental / boot HOLD. */
export const SUPPORTED_TARGETS: readonly SupportedTarget[] = WIZARD_DEVICES.map((device) => {
  const view = readinessFor(device.id);
  return {
    codename: device.id,
    deviceName: device.deviceName,
    status: device.status,
    readiness: view.tier,
    readinessReason: view.reason,
    readinessRemedy: view.remedy,
    offerable: view.offerable,
    requiresAcknowledgement: view.requiresAcknowledgement,
  };
});

export const ALPHA_POSTURE_FLAGS = {
  connectivity: POSTURE_CONNECTIVITY,
  custody: POSTURE_CUSTODY,
  releaseState: "alpha",
} as const;

const HEADLINE_CLASS = "step-headline";

function headline(step: number, sentence: string): string {
  if (!sentence.trimEnd().endsWith(".")) {
    throw new Error(`step ${step} headline must be a sentence ending with a full stop`);
  }
  return `<h2 class="${HEADLINE_CLASS}" data-step="${String(step)}">${escapeHtml(sentence)}</h2>`;
}

function mono(value: string): string {
  return `<code class="mono">${escapeHtml(value)}</code>`;
}

// ---------------------------------------------------------------------------
// Page chrome: posture pill, step rail, lineage footer
// ---------------------------------------------------------------------------

export function renderPostureHeader(): string {
  return renderPosturePill(ALPHA_POSTURE_FLAGS);
}

export function renderStepRail(state: InstallState): string {
  return renderRail(state).html;
}

/** Q-12 draft attribution wording — credited upstream, marked for counsel. */
export function renderRouteFooter(): string {
  return LineageNote(
    "Installer practice here — unlock wipes, verified image flashing, and an explicit lock — follows the discipline published by the GrapheneOS project; GuardTalkOS is an independent implementation and is not affiliated with GrapheneOS.",
  ).html;
}

export interface InstallerChromeParts {
  readonly state: InstallState;
  /** Body HTML of the current step's section. */
  readonly stepHtml: string;
}

/** Full route body: posture pill + rail + current step + lineage footer. */
export function renderInstallerChrome(parts: InstallerChromeParts): string {
  const canBack = railStepViews(parts.state).some((view) => view.reachableByBack);
  const backBtn = canBack
    ? `<button type="button" class="${GL_BTN_DEFAULT}" data-action="back">Back</button>`
    : `<span></span>`;
  return [
    `<div class="installer gl-onboarding" data-route="install">`,
    `<header class="installer-top gl-onboarding__header">${renderPostureHeader()}</header>`,
    `<nav class="installer-rail" aria-label="Installer steps">${renderStepRail(parts.state)}</nav>`,
    `<main class="installer-main gl-card" id="installer-main">`,
    `<div class="gl-card__body gl-form-layout">${parts.stepHtml}</div>`,
    `<div class="gl-form-layout__actions installer-actions" data-align="between">${backBtn}</div>`,
    `</main>`,
    `<footer class="installer-foot">${renderRouteFooter()}</footer>`,
    `</div>`,
  ].join("");
}

// ---------------------------------------------------------------------------
// Step 0 — Before you start
// ---------------------------------------------------------------------------

/** Streamlined linear WebUSB installer overview (no user key enrolment). */
export const CUSTODY_SENTENCES: readonly string[] = [
  `Nothing is uploaded. The only network request is a GET of the release files from ${RELEASE_FETCH_ORIGIN}.`,
  "Image digests are verified in this tab against SHA256SUMS before flashing.",
  "WebUSB flashing writes the verified channel images linearly: connect/unlock -> flash -> lock.",
];

function targetPickerHtml(selected: string): string {
  const options = WIZARD_DEVICES.map((device) => {
    const isSelected = device.id === selected ? " selected" : "";
    const view = readinessFor(device.id);
    const requiresAck = view.requiresAcknowledgement ? "true" : "false";
    const offerable = view.offerable ? "true" : "false";
    const packed = hasPackedChannel(device.id);
    const statusFact = statusJsonFact(device.id);
    // The option text names BOTH facts that govern whether this device can be
    // taken: the channel (acceptance (a)) and the tier gate. A device with no
    // channel says so plainly rather than offering a dead end.
    const suffix = !packed
      ? ` — NO CHANNEL PACKED, not selectable`
      : view.offerable
        ? view.requiresAcknowledgement
          ? ` — ${readinessChipWord(view.tier)}, selectable only with its typed codename`
          : ""
        : ` — ${readinessChipWord(view.tier)}, not offerable`;
    return `<option value="${escapeHtml(device.id)}" data-status="${device.status}" data-status-json="${statusFact}" data-packed="${packed ? "true" : "false"}" data-selectable="${isSelectableProduct(device.id) ? "true" : "false"}" data-readiness="${view.tier}" data-requires-ack="${requiresAck}" data-offerable="${offerable}"${isSelected}>${escapeHtml(device.label + suffix)}</option>`;
  }).join("");
  return [
    `<label class="field" for="target-product">Selected device</label>`,
    `<select id="target-product" name="target-product" data-role="target-product">${options}</select>`,
    `<p class="note">A device with no packed channel cannot be selected. A READY device selects normally; a READY-ACK or BUILD-OK device is not selected until you type its codename; a tier the host does not offer cannot be selected at all.</p>`,
  ].join("");
}

function targetTableHtml(): string {
  const advertisedNote =
    "rango is advertised as experimental / boot HOLD — not production-boot-green. " +
    KOMODO_STAMP_HONESTY +
    " caiman, shiba, husky, tegu, and comet stay unstamped and are not offered.";
  const rows = SUPPORTED_TARGETS.map((target) => {
    const chipKind = target.status === "supported" ? "neutral" : "caution";
    const chip = makeChip(statusChipWord(target.status), chipKind);
    const readinessKind = target.readiness === "READY" ? "neutral" : "caution";
    const readinessChip = makeChip(readinessChipWord(target.readiness), readinessKind);
    const requiresAck = target.requiresAcknowledgement ? "true" : "false";
    const offerable = target.offerable ? "true" : "false";
    // (c) the status.json fact is shown EXACTLY — including the honest
    // "NOT IN status.json" for komodo, never an invented "supported".
    const statusFact = statusJsonFact(target.codename);
    const statusJsonChip = makeChip(
      statusJsonChipWord(target.codename),
      statusFact === "absent-from-status-json" ? "caution" : "neutral",
    );
    // (a) the packed-channel fact, and therefore selectability.
    const packed = hasPackedChannel(target.codename);
    const channelChip = makeChip(channelChipWord(target.codename), packed ? "neutral" : "caution");
    return [
      `<tr data-codename="${escapeHtml(target.codename)}" data-status="${target.status}" data-status-json="${statusFact}" data-packed="${packed ? "true" : "false"}" data-selectable="${isSelectableProduct(target.codename) ? "true" : "false"}" data-readiness="${target.readiness}" data-requires-ack="${requiresAck}" data-offerable="${offerable}">`,
      `<th scope="row">${escapeHtml(target.codename)}</th>`,
      `<td>${mono(target.deviceName)}</td>`,
      `<td>${chip}</td>`,
      `<td>${statusJsonChip}</td>`,
      `<td>${channelChip}</td>`,
      `<td>${readinessChip}<span class="readiness-reason">${escapeHtml(target.readinessReason)}</span></td>`,
    ].join("");
  }).join("");
  return [
    `<table class="target-table"><caption>This installer writes these devices only</caption>`,
    `<thead><tr><th scope="col">Codename</th><th scope="col">Device</th><th scope="col">Status</th><th scope="col">status.json</th><th scope="col">Channel</th><th scope="col">Readiness</th></tr></thead>`,
    `<tbody>${rows}</tbody></table>`,
    `<p class="note">${escapeHtml(advertisedNote)}</p>`,
    `<p class="note">The <strong>status.json</strong> column states the shipped product facts exactly; <code class="mono">komodo</code> is absent from those facts and is labelled as such rather than being called supported. The <strong>Channel</strong> column states what is actually packed: a device with no packed channel cannot be selected.</p>`,
    `<p class="note">Readiness tiers are generated from <code class="mono">scripts/gt-ready-devices.sh</code> (${escapeHtml(READINESS_PROVENANCE.sourceScriptSha256.slice(0, 12))}…, ${escapeHtml(READINESS_PROVENANCE.generatedAt)}); packed channels from <code class="mono">scripts/gen-packed-channels.mjs</code>. No device is boot-verified: ${mono(`BOOT_VERIFIED=${String(BOOT_VERIFIED)}`)}.</p>`,
  ].join("");
}

/**
 * A target the user asked for that cannot be selected outright: a BUILD-OK
 * device awaiting its typed codename, or a tier the host does not offer.
 */
export interface ReadinessGateView {
  readonly product: OfferedProduct;
  readonly deviceName: string;
  readonly tier: ReadinessTier;
  readonly reason: string;
  readonly remedy: string;
}

/** Tier-specific copy for the acknowledgement gate. Unknown ack tiers fall back honestly. */
const ACK_GATE_HEADING: Readonly<Partial<Record<ReadinessTier, string>>> = Object.freeze({
  "BUILD-OK": "BUILD-OK — this build is not boot-verified.",
  "READY-ACK": "READY-ACK — acknowledged, not stamp-proven.",
});

const ACK_GATE_LEDE: Readonly<Partial<Record<ReadinessTier, string>>> = Object.freeze({
  "BUILD-OK":
    "Every host check passed for this bundle, but no host check can prove that a phone boots. Boot is UNVERIFIED.",
  "READY-ACK":
    "The host clauses passed, but readiness for this exact stamp is NOT stamp-conferred. A recorded operator acknowledgement accepts that residual for this stamp only — it is not a proof and not boot evidence.",
});

/**
 * Blocking panel for a target that cannot be selected yet — the web-installer
 * parity with `gt-flash-wizard.sh:176-201`. Whether the codename must be typed
 * is decided by the tier policy, NOT by a `=== "BUILD-OK"` literal: any
 * acknowledgement-gated tier (READY-ACK, BUILD-OK) gets the typed gate, while
 * HOLD/PENDING have no acknowledgement path at all. `BOOT_VERIFIED` stays
 * false: nothing here implies a boot result.
 */
export function renderReadinessGate(view: ReadinessGateView): string {
  const bootFlag = `BOOT_VERIFIED=${String(BOOT_VERIFIED)}`;
  const acknowledgeable = tierPolicy(view.tier)?.requiresAcknowledgement === true;
  const heading = acknowledgeable
    ? ACK_GATE_HEADING[view.tier] ?? `${view.tier} — this build requires an acknowledgement.`
    : `${view.tier} — this build is not offerable.`;
  const lede = acknowledgeable
    ? ACK_GATE_LEDE[view.tier] ??
      "This tier requires its codename to be typed before it can be selected."
    : "The host readiness report does not offer this stamp for flashing. It is not selected, and there is no acknowledgement that would select it.";
  const ack = acknowledgeable
    ? [
        `<label for="readiness-ack">Type the device codename (${mono(view.product)}) to select this ${escapeHtml(view.tier)} build:</label>`,
        `<input type="text" id="readiness-ack" name="readiness-ack" data-role="readiness-ack" autocomplete="off" spellcheck="false" />`,
        `<div class="readiness-gate__actions">`,
        `<button type="button" class="${GL_BTN_CONFIRM}" data-action="acknowledge-build-ok">Select ${escapeHtml(view.tier)} build</button>`,
        `<button type="button" class="${GL_BTN_DEFAULT}" data-action="cancel-build-ok">Keep my current device</button>`,
        `</div>`,
      ]
    : [
        `<div class="readiness-gate__actions">`,
        `<button type="button" class="${GL_BTN_DEFAULT}" data-action="cancel-build-ok">Keep my selected device</button>`,
        `</div>`,
      ];
  return [
    `<section class="readiness-gate" data-readiness-gate="${view.tier}" data-product="${escapeHtml(view.product)}" role="alert" aria-live="assertive" aria-atomic="true" aria-labelledby="readiness-gate-heading">`,
    `<h3 id="readiness-gate-heading">${escapeHtml(heading)}</h3>`,
    `<p class="readiness-gate__lede">${escapeHtml(lede)}</p>`,
    `<dl class="readiness-gate__facts">`,
    `<dt>Device</dt><dd>${escapeHtml(view.deviceName)} (${mono(view.product)})</dd>`,
    `<dt>Tier</dt><dd>${escapeHtml(readinessChipWord(view.tier))}</dd>`,
    `<dt>Reason</dt><dd>${escapeHtml(view.reason)}</dd>`,
    `<dt>Remedy</dt><dd>${escapeHtml(view.remedy)}</dd>`,
    `</dl>`,
    `<p class="readiness-gate__flag">${mono(bootFlag)}</p>`,
    ...ack,
    `</section>`,
  ].join("");
}

export function renderStep0(
  selectedProduct: string = DEFAULT_OFFERED_PRODUCT,
  pendingBuildOk?: ReadinessGateView,
): string {
  const selected = parseOfferedDevice(selectedProduct) ?? DEFAULT_OFFERED_PRODUCT;
  const hardenings = [
    Hardening(
      "Every check runs offline in this tab — hashing and image verification happen on this computer with no upload.",
    ).html,
  ].join("");
  const limits = [
    ProtectionLimit(
      "WebUSB flashing needs a Chromium-based browser — Chrome, Edge, Brave, or Chromium; Firefox and Safari cannot reach the phone.",
    ).html,
    ProtectionLimit(
      "Continuing wipes the phone twice — once at unlock, once at lock; photos, codes, and credentials do not survive, so move them off the device first.",
    ).html,
  ].join("");
  const custodyList = CUSTODY_SENTENCES.map((s) => `<li>${escapeHtml(s)}</li>`).join("");
  const gate = pendingBuildOk === undefined ? "" : renderReadinessGate(pendingBuildOk);
  return [
    headline(0, "Read this before you touch the phone."),
    `<p class="lede">This installer puts GuardTalkOS on your Pixel over WebUSB.</p>`,
    `<div class="posture-row">${renderPostureHeader()}${makeChip("ALPHA — READ FIRST", "caution")}</div>`,
    hardenings,
    targetTableHtml(),
    targetPickerHtml(selected),
    gate,
    limits,
    `<section aria-labelledby="custody-heading"><h3 id="custody-heading">How this installer works</h3>`,
    `<ol class="custody-list">${custodyList}</ol></section>`,
    `<button type="button" class="${GL_BTN_CONFIRM}" data-action="acknowledge-intro">${escapeHtml(ACK_CTA_LABEL)}</button>`,
  ].join("");
}

// ---------------------------------------------------------------------------
// Step 1 — Get the release over Tor
// ---------------------------------------------------------------------------

export interface FilePicks {
  readonly package: boolean;
  readonly sums: boolean;
  readonly sig: boolean;
}

/** Advance gate: all three artifacts picked (code-enforced, PLAN.md §1). */
export function filesReady(picks: FilePicks): boolean {
  return picks.package && picks.sums && picks.sig;
}

/** Bucket and object names for the lab GET. The lab key is not a release fingerprint. */
export const RELEASE_BUCKET = "guardtalk-browser-test";
export const RELEASE_PREFIX = "tokay-20260928-084839/";
export const RELEASE_PACKAGE_NAME = "tokay-20260928-084839.zip";
export const RELEASE_SUMS_NAME = "SHA256SUMS";
export const RELEASE_SIG_NAME = "SHA256SUMS.sig";

const RELEASE_OBJECT_NAMES = [RELEASE_PACKAGE_NAME, RELEASE_SUMS_NAME, RELEASE_SIG_NAME] as const;

export function releaseObjectUrl(objectName: (typeof RELEASE_OBJECT_NAMES)[number]): string {
  return `${RELEASE_FETCH_ORIGIN}/${RELEASE_BUCKET}/${RELEASE_PREFIX}${objectName}`;
}

const RELEASE_PATHS: ReadonlySet<string> = new Set(
  RELEASE_OBJECT_NAMES.map((name) => new URL(releaseObjectUrl(name)).pathname),
);

/** True only for the three object URLs on RELEASE_FETCH_ORIGIN. Any other origin is false. */
export function releaseFetchAllowed(url: string): boolean {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.origin !== RELEASE_FETCH_ORIGIN) {
    return false;
  }
  if (parsed.username !== "" || parsed.password !== "") {
    return false;
  }
  if (parsed.search !== "" || parsed.hash !== "") {
    return false;
  }
  return RELEASE_PATHS.has(parsed.pathname);
}

export function assertReleaseFetchUrl(url: string): void {
  if (!releaseFetchAllowed(url)) {
    throw new Error(`Refused fetch: only ${RELEASE_FETCH_ORIGIN} release objects are allowed`);
  }
}

export interface ReleaseFetchResponse {
  readonly ok: boolean;
  readonly status: number;
  arrayBuffer(): Promise<ArrayBuffer>;
}

export type ReleaseFetchImpl = (url: string) => Promise<ReleaseFetchResponse>;

/** GET one allowed object. A URL on any other origin throws before fetchImpl runs. */
export async function getAllowedReleaseObject(
  url: string,
  fetchImpl: ReleaseFetchImpl,
): Promise<Uint8Array> {
  assertReleaseFetchUrl(url);
  const response = await fetchImpl(url);
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (!response.ok) {
    throw new Error(`Release GET failed (${String(response.status)})`);
  }
  return bytes;
}

export interface ReleaseSlots {
  readonly packageName: string;
  readonly packageBytes: Uint8Array;
  readonly sumsText: string;
  readonly sigBytes: Uint8Array;
  readonly picks: FilePicks;
}

/** GET the package, SHA256SUMS, and SHA256SUMS.sig. Does not advance the machine. */
export async function fetchReleaseObjects(fetchImpl: ReleaseFetchImpl): Promise<ReleaseSlots> {
  const packageBytes = await getAllowedReleaseObject(releaseObjectUrl(RELEASE_PACKAGE_NAME), fetchImpl);
  const sumsBytes = await getAllowedReleaseObject(releaseObjectUrl(RELEASE_SUMS_NAME), fetchImpl);
  const sigBytes = await getAllowedReleaseObject(releaseObjectUrl(RELEASE_SIG_NAME), fetchImpl);
  return {
    packageName: RELEASE_PACKAGE_NAME,
    packageBytes,
    sumsText: new TextDecoder().decode(sumsBytes),
    sigBytes,
    picks: { package: true, sums: true, sig: true },
  };
}

/**
 * Q-05 (release onion) and Q-04 (release-key fingerprint). Either fact still
 * rendered with `data-proceed="forbidden"` keeps Continue disabled.
 */
const STEP1_UNPUBLISHED_FACTS = [ONION_ADDRESS_FACT, RELEASE_FINGERPRINT_FACT] as const;

/**
 * Test double for the unpublished-fact gate. Production callers omit this, so
 * both facts stay forbidden. Listing an id clears that fact for this render
 * only. No address and no fingerprint are invented.
 */
export interface Step1ContinueGate {
  readonly clearedFactIds?: readonly ("Q-04" | "Q-05")[];
}

function renderStep1UnpublishedFact(
  fact: (typeof STEP1_UNPUBLISHED_FACTS)[number],
  cleared: boolean,
): string {
  if (!cleared) {
    return renderUnavailableFact(fact);
  }
  return `<div data-unavailable="${fact.id}" data-proceed="allowed"></div>`;
}

export function renderStep1(picks: FilePicks, gate?: Step1ContinueGate): string {
  const cleared = new Set<string>(gate?.clearedFactIds ?? []);
  const factHtml = STEP1_UNPUBLISHED_FACTS.map((fact) =>
    renderStep1UnpublishedFact(fact, cleared.has(fact.id)),
  );
  const unpublishedForbidden = factHtml.some((html) => html.includes('data-proceed="forbidden"'));
  const slotsReady = filesReady(picks);
  const continueEnabled = slotsReady && !unpublishedForbidden;
  const slot = (role: string, label: string): string =>
    [
      `<div class="file-slot" data-role="${role}-slot">`,
      `<label for="file-${role}">${escapeHtml(label)}</label>`,
      `<input type="file" id="file-${role}" data-role="${role}" />`,
      `</div>`,
    ].join("");
  const continueAttrs = continueEnabled ? "" : ` disabled aria-disabled="true"`;
  let note = "";
  if (!slotsReady) {
    note = `<p class="note">All three files must be picked before continuing.</p>`;
  } else if (unpublishedForbidden) {
    note =
      `<p class="note">Continue stays disabled while the release onion address or the release-key fingerprint is unpublished.</p>`;
  }
  const cta =
    `<button type="button" class="${GL_BTN_CONFIRM}" data-action="files-picked"${continueAttrs}>Continue to verification</button>${note}`;
  const fetchButton =
    `<button type="button" class="${GL_BTN_DEFAULT}" data-action="fetch-release">GET the three release files</button>`;
  return [
    headline(1, "Bring the three release files into this tab."),
    `<p class="lede">This step GETs the package, SHA256SUMS, and SHA256SUMS.sig from one origin. You can also pick the same three files.</p>`,
    `<ul class="fetch-points">`,
    ...factHtml.map((html) => `<li>${html}</li>`),
    `</ul>`,
    Hardening(
      `The only network request is a GET from ${RELEASE_FETCH_ORIGIN}. Hashing and the signature check stay in this tab.`,
    ).html,
    fetchButton,
    `<div class="file-slots">${slot("package", "Release package (.zip)")}${slot("sums", "SHA256SUMS")}${slot("sig", "SHA256SUMS.sig")}</div>`,
    makeChip("ALL THREE REQUIRED", "caution"),
    cta,
  ].join("");
}

// ---------------------------------------------------------------------------
// Step 2 — Verify the release
// ---------------------------------------------------------------------------

export interface ReleaseManifestMeta {
  readonly buildId: string;
  readonly targetProduct: string;
  readonly version: string;
}

export interface ComparisonRow {
  readonly label: string;
  readonly html: string;
  readonly verdict: "MATCH" | "MISMATCH";
}

export interface VerifyViewModel {
  readonly status: "verified" | "stopped";
  readonly rows: readonly ComparisonRow[];
  readonly chipHtml?: string;
  readonly stopReason?: string;
  readonly detail?: string;
  readonly meta?: ReleaseManifestMeta;
}

export interface VerifyInput {
  readonly packageName: string;
  readonly packageBytes: Uint8Array;
  readonly sumsText: string;
  readonly manifest: ReleaseManifestMeta;
}

export type VerifyOutcome =
  | { readonly kind: "verified"; readonly view: VerifyViewModel }
  | {
      readonly kind: "stop";
      readonly condition: "hash-mismatch";
      readonly view: VerifyViewModel;
    }

/** Case-insensitive digest comparison routed through lib/verify's model. */
function sbsHexRow(label: string, expected: string, actual: string): ComparisonRow {
  return sbsFromSide(label, compareHex(expected, actual));
}

function sbsFromSide(label: string, side: SideBySide): ComparisonRow {
  const rendered = renderSideBySideRow({ label, side });
  return { label, html: rendered.html, verdict: rendered.verdict };
}

function verifiedChip(): string {
  return makeChip("VERIFIED · SHA256SUMS", "verified", { ariaLive: "polite" });
}

function stopChip(): string {
  return makeChip("STOPPED", "tripwire", { ariaLive: "assertive" });
}

/**
 * Client-side verification: parse SHA256SUMS and hash the package offline.
 * No user-supplied public key PEM is required.
 */
export async function verifyRelease(input: VerifyInput): Promise<VerifyOutcome> {
  let sums;
  try {
    sums = parseSha256Sums(input.sumsText);
  } catch (cause) {
    const detail = cause instanceof SumsParseError ? cause.message : "SHA256SUMS could not be parsed";
    return {
      kind: "stop",
      condition: "hash-mismatch",
      view: { status: "stopped", rows: [], stopReason: STOP_REASONS.HASH_MISMATCH, detail },
    };
  }
  const entry = sums.lookup(input.packageName);
  if (entry === undefined) {
    return {
      kind: "stop",
      condition: "hash-mismatch",
      view: {
        status: "stopped",
        rows: [],
        stopReason: STOP_REASONS.HASH_MISMATCH,
        detail: `SHA256SUMS does not list ${input.packageName}`,
      },
    };
  }
  const actualHex = await sha256Hex(input.packageBytes);
  const hashRow = sbsHexRow(`package sha256 (${input.packageName})`, entry.digest, actualHex);
  if (!hashRow.verdict.startsWith("MATCH")) {
    return {
      kind: "stop",
      condition: "hash-mismatch",
      view: {
        status: "stopped",
        rows: [hashRow],
        stopReason: STOP_REASONS.HASH_MISMATCH,
        chipHtml: stopChip(),
      },
    };
  }
  return {
    kind: "verified",
    view: {
      status: "verified",
      rows: [hashRow],
      chipHtml: verifiedChip(),
      meta: input.manifest,
    },
  };
}

export function renderStep2(view: VerifyViewModel): string {
  const parts: string[] = [headline(2, "Every byte gets checked before anything continues.")];
  if (view.chipHtml !== undefined) {
    parts.push(`<p class="verdict-row">${view.chipHtml}</p>`);
  }
  if (view.stopReason !== undefined) {
    parts.push(
      glAlertHtml(
        "danger",
        "FLOW STOPPED",
        `<p class="stop-reason">${escapeHtml(view.stopReason)}</p>`,
        "stop-banner",
      ),
    );
  }
  if (view.detail !== undefined) {
    parts.push(`<p class="stop-detail mono">${escapeHtml(view.detail)}</p>`);
  }
  for (const row of view.rows) {
    parts.push(row.html);
  }
  if (view.meta !== undefined) {
    parts.push(
      `<dl class="release-meta mono">`,
      `<dt>build id</dt><dd>${escapeHtml(view.meta.buildId)}</dd>`,
      `<dt>device target</dt><dd>${escapeHtml(view.meta.targetProduct)}</dd>`,
      `<dt>version</dt><dd>${escapeHtml(view.meta.version)}</dd>`,
      `</dl>`,
    );
  }
  if (view.status === "verified") {
    parts.push(`<button type="button" class="${GL_BTN_CONFIRM}" data-action="release-verified">Continue to device connection</button>`);
  }
  return parts.join("");
}

// ---------------------------------------------------------------------------
