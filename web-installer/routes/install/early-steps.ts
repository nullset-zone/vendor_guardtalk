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
 * failures. Values the project does not have ship as `// confirm` mono
 * placeholders (Q-04/Q-05/Q-06/Q-07) — never invented around.
 *
 * Custody contract (PLAN.md §2, D-007): private material never enters any
 * emitted string; only fingerprints/hashes (public halves) are displayed.
 */
import { STOP_REASONS } from "../../lib/install-state/stops.js";
import type { InstallAction, InstallState, StopRecord } from "../../lib/install-state/machine.js";
import { renderRail } from "../../lib/ui/rail.js";
import { makeChip } from "../../lib/ui/chips.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "../../lib/ui/posture.js";
import { renderKeyDiagram } from "../../lib/ui/key-diagram.js";
import { renderSideBySideRow } from "../../lib/ui/sidebyside.js";
import type { DialogOptions } from "../../lib/ui/dialog.js";
import { Hardening, LineageNote, ProtectionLimit } from "../../lib/claims/components.js";
import {
  compareExact,
  compareHex,
  type SideBySide,
} from "../../lib/verify/side-by-side.js";
import { parseSha256Sums, SumsParseError } from "../../lib/verify/sums.js";
import { verifyDetached, type RsaPublicJwk } from "../../lib/verify/detached-sig.js";
import { sha256Hex } from "../../src/hash.js";
import { fingerprintFromJwk } from "../../lib/keys/fingerprint.js";
import { exportEncryptedPem } from "../../lib/keys/export-enc.js";
import { zeroise } from "../../lib/keys/zeroise.js";
import { importPem, type ImportedKey } from "../../lib/keys/import.js";
import { KEY_ALGORITHM } from "../../lib/keys/generate.js";
import { parseVbmeta } from "../../lib/avb/parser.js";
import { isChainDescriptor } from "../../lib/avb/descriptors.js";
import { resignVbmeta, verifyVbmeta, verifyVbmetaAgainstKey, type KeyMaterial as SignerKeyMaterial } from "../../lib/avb/signer.js";
import { beBytesToBigInt } from "../../lib/avb/bytes.js";
import { encodePkmd, pkmdFingerprint } from "../../lib/avb/pkmd.js";
import { cliExportStepMap, type CliExportPlan } from "../../lib/cli-export/generator.js";

// ---------------------------------------------------------------------------
// Binding copy constants
// ---------------------------------------------------------------------------

/** Step-0 CTA — exact label mandated by the build brief. */
export const ACK_CTA_LABEL = "I understand — begin →";

/** Q-05: releases onion address ships as a mono placeholder. */
export const ONION_PLACEHOLDER = "// confirm onion address (Q-05)";
/** Q-04: release-key fingerprint ships as a mono placeholder. */
export const RELEASE_FINGERPRINT_PLACEHOLDER = "// confirm release-key fingerprint (Q-04)";
/** Q-06: rango marketing name is not grounded in any present source. */
export const RANGO_NAME_PLACEHOLDER = "// confirm device name (Q-06)";
/** Q-07: chained-partition layout confirmation placeholder (verbatim). */
export const PARTITION_LAYOUT_CONFIRM = "// confirm partition layout (Q-07)";

export interface SupportedTarget {
  readonly codename: string;
  readonly deviceName: string;
  readonly status: "supported" | "experimental";
}

/** D-012 / Q-14: tokay+rango first-class; akita behind an explicit flag. */
export const SUPPORTED_TARGETS: readonly SupportedTarget[] = [
  { codename: "tokay", deviceName: "Pixel 9", status: "supported" },
  { codename: "rango", deviceName: RANGO_NAME_PLACEHOLDER, status: "supported" },
];

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

function confirmPlaceholder(text: string): string {
  return `<code class="confirm-placeholder mono">${escapeHtml(text)}</code>`;
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
    "Installer practice here — unlock wipes, a boot anchor signed by your own key, and an explicit lock — follows the discipline published by the GrapheneOS project; GuardTalkOS is an independent implementation and is not affiliated with GrapheneOS.",
  ).html;
}

export interface InstallerChromeParts {
  readonly state: InstallState;
  /** Body HTML of the current step's section. */
  readonly stepHtml: string;
}

/** Full route body: posture pill + rail + current step + lineage footer. */
export function renderInstallerChrome(parts: InstallerChromeParts): string {
  return [
    `<div class="installer" data-route="install">`,
    `<header class="installer-top">${renderPostureHeader()}</header>`,
    `<nav class="installer-rail" aria-label="Installer steps">${renderStepRail(parts.state)}</nav>`,
    `<main class="installer-main" id="installer-main">${parts.stepHtml}</main>`,
    `<footer class="installer-foot">${renderRouteFooter()}</footer>`,
    `</div>`,
  ].join("");
}

// ---------------------------------------------------------------------------
// Step 0 — Before you start
// ---------------------------------------------------------------------------

/** Six-sentence key-custody explanation (binding count: six). */
export const CUSTODY_SENTENCES: readonly string[] = [
  "Your private key is created or imported inside this tab and never leaves it.",
  "The browser holds it as a non-extractable handle, or in memory that is zeroed after use.",
  "Only the public half — a fingerprint you can read and compare — is ever displayed.",
  "Nothing is uploaded: the installer makes no network request of any kind.",
  "An optional encrypted backup file is written only when you ask; sealing happens offline with your passphrase.",
  "GuardTalk's release key proves who built the download; your key alone decides what boots.",
];

function targetTableHtml(): string {
  const akitaNote =
    "akita (Pixel 8a) stays behind an explicit experimental flag pending confirmation — it is not offered by this installer today.";
  const rows = SUPPORTED_TARGETS.map((target) => {
    const chip =
      target.status === "supported"
        ? makeChip("SUPPORTED", "neutral")
        : makeChip("EXPERIMENTAL", "caution");
    return [
      `<tr><th scope="row">${escapeHtml(target.codename)}</th>`,
      `<td>${mono(target.deviceName)}</td>`,
      `<td>${chip}</td></tr>`,
    ].join("");
  }).join("");
  return [
    `<table class="target-table"><caption>This installer writes these devices only</caption>`,
    `<thead><tr><th scope="col">Codename</th><th scope="col">Device</th><th scope="col">Status</th></tr></thead>`,
    `<tbody>${rows}</tbody></table>`,
    `<p class="note">${escapeHtml(akitaNote)}</p>`,
  ].join("");
}

/** Three key flows compared as equals (D-005) — same depth for every column. */
function flowCompareTableHtml(): string {
  const heads = ["Generate here", "Bring your own", "Sign elsewhere"];
  const made = [
    "Inside this browser tab",
    "Wherever you made it",
    "On an offline machine you control",
  ];
  const kept = [
    "Non-extractable handle in this tab; optional encrypted backup file",
    "The PEM file you already keep, offline",
    "The key never touches this computer at all",
  ];
  const best = [
    "You want everything done in one place",
    "You already manage keys yourself",
    "Your signing machine must stay air-gapped",
  ];
  const tr = (label: string, cells: readonly string[]): string =>
    [`<tr><th scope="row">${escapeHtml(label)}</th>`, ...cells.map((c) => `<td>${escapeHtml(c)}</td>`), `</tr>`].join("");
  return [
    `<table class="flow-compare"><caption>The three key paths, compared as equals — none is chosen for you</caption>`,
    `<thead><tr><th scope="col"></th>${heads.map((h) => `<th scope="col">${escapeHtml(h)}</th>`).join("")}</tr></thead>`,
    `<tbody>`,
    tr("Key is made", made),
    tr("What you keep", kept),
    tr("Fits when", best),
    `</tbody></table>`,
  ].join("");
}

export function renderStep0(): string {
  const hardenings = [
    Hardening(
      "Every check runs offline in this tab — hashing, signature verification, and signing happen on this computer with no network.",
    ).html,
    Hardening(
      "Verified boot enrols your own key, so the phone refuses system images you did not sign.",
    ).html,
  ].join("");
  const limits = [
    ProtectionLimit(
      "WebUSB flashing needs a Chromium-based browser — Chrome, Edge, Brave, or Chromium; Firefox and Safari cannot reach the phone.",
    ).html,
    ProtectionLimit(
      "Tor Browser cannot flash over USB: fetch the release over Tor, then continue in Chromium — or take the CLI export, an equal path ending at the same signed result.",
    ).html,
    ProtectionLimit(
      "Continuing wipes the phone twice — once at unlock, once at lock; photos, codes, and credentials do not survive, so move them off the device first.",
    ).html,
    ProtectionLimit(
      "Verified boot with your key governs what boots; it does not cover firmware or baseband beneath AVB, a compromised signing machine, or coercion.",
    ).html,
  ].join("");
  const custodyList = CUSTODY_SENTENCES.map((s) => `<li>${escapeHtml(s)}</li>`).join("");
  return [
    headline(0, "Read this before you touch the phone."),
    `<p class="lede">This installer puts GuardTalkOS on your Pixel, locked to a key only you hold.</p>`,
    `<div class="posture-row">${renderPostureHeader()}${makeChip("ALPHA — READ FIRST", "caution")}</div>`,
    hardenings,
    targetTableHtml(),
    limits,
    `<section aria-labelledby="custody-heading"><h3 id="custody-heading">Key custody, in six sentences</h3>`,
    `<ol class="custody-list">${custodyList}</ol></section>`,
    renderKeyDiagram(),
    flowCompareTableHtml(),
    `<button type="button" class="btn-primary" data-action="acknowledge-intro">${escapeHtml(ACK_CTA_LABEL)}</button>`,
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

export function renderStep1(picks: FilePicks): string {
  const ready = filesReady(picks);
  const slot = (role: string, label: string): string =>
    [
      `<div class="file-slot" data-role="${role}-slot">`,
      `<label for="file-${role}">${escapeHtml(label)}</label>`,
      `<input type="file" id="file-${role}" data-role="${role}" />`,
      `</div>`,
    ].join("");
  const cta = [
    `<button type="button" class="btn-primary" data-action="files-picked"`,
    ready ? `` : `disabled aria-disabled="true"`,
    `>Continue to verification</button>`,
    ready ? `` : `<p class="note">All three files must be picked before continuing.</p>`,
  ].join("");
  return [
    headline(1, "Bring the three release files into this tab."),
    `<p class="lede">Fetch the bundle yourself over Tor Browser, then pick the files here:</p>`,
    `<ul class="fetch-points mono">`,
    `<li>onion address: ${confirmPlaceholder(ONION_PLACEHOLDER)}</li>`,
    `<li>cross-check the release fingerprint: ${confirmPlaceholder(RELEASE_FINGERPRINT_PLACEHOLDER)}</li>`,
    `</ul>`,
    Hardening(
      "No network request leaves this page — the files are hashed and checked offline in this tab.",
    ).html,
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
  readonly sigBytes: Uint8Array;
  /** Release public key as a JWK placeholder parameter (Q-04 pending). */
  readonly releaseKeyJwk: RsaPublicJwk;
  readonly manifest: ReleaseManifestMeta;
}

export type VerifyOutcome =
  | { readonly kind: "verified"; readonly view: VerifyViewModel }
  | {
      readonly kind: "stop";
      readonly condition: "hash-mismatch" | "signature-invalid";
      readonly view: VerifyViewModel;
    }

/** Case-insensitive digest comparison routed through lib/verify's model. */
function sbsHexRow(label: string, expected: string, actual: string): ComparisonRow {
  return sbsFromSide(label, compareHex(expected, actual));
}

/** Byte-for-byte comparison (fingerprints, exact strings) via lib/verify. */
function sbsExactRow(label: string, expected: string, actual: string): ComparisonRow {
  return sbsFromSide(label, compareExact(expected, actual));
}

function sbsFromSide(label: string, side: SideBySide): ComparisonRow {
  const rendered = renderSideBySideRow({ label, side });
  return { label, html: rendered.html, verdict: rendered.verdict };
}

function verifiedChip(): string {
  return makeChip("VERIFIED · GUARDTALK RELEASE KEY", "verified", { ariaLive: "polite" });
}

function stopChip(): string {
  return makeChip("STOPPED", "tripwire", { ariaLive: "assertive" });
}

/**
 * Client-side verification: parse SHA256SUMS, hash the package offline,
 * verify the detached signature against the release-key JWK placeholder.
 * Pure aside from WebCrypto/subtle-free hashing (portable SHA-256) — no
 * fetch, no storage, no timers.
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
  const sig = await verifyDetached(input.sigBytes, input.sumsText, input.releaseKeyJwk);
  const sigExpected = "signature verifies against the GuardTalk release key";
  const sigActual = sig.valid ? sigExpected : (sig.reason ?? "signature rejected");
  const sigRow = sbsExactRow("detached signature", sigExpected, sigActual);
  if (!sig.valid) {
    return {
      kind: "stop",
      condition: "signature-invalid",
      view: {
        status: "stopped",
        rows: [hashRow, sigRow],
        stopReason: STOP_REASONS.SIGNATURE_INVALID,
        chipHtml: stopChip(),
      },
    };
  }
  return {
    kind: "verified",
    view: {
      status: "verified",
      rows: [hashRow, sigRow],
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
    parts.push(`<p class="stop-banner"><span class="stop-label">FLOW STOPPED</span></p>`);
    parts.push(`<p class="stop-reason">${escapeHtml(view.stopReason)}</p>`);
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
    parts.push(`<button type="button" class="btn-primary" data-action="release-verified">Continue to your key</button>`);
  }
  return parts.join("");
}

// ---------------------------------------------------------------------------
// Step 3 — Your key (three equal flows, D-005)
// ---------------------------------------------------------------------------

export interface KeyFlowCard {
  readonly flow: 1 | 2 | 3;
  readonly slug: string;
  readonly title: string;
  readonly description: string;
}

export const KEY_FLOW_CARDS: readonly KeyFlowCard[] = [
  {
    flow: 1,
    slug: "generate-here",
    title: "Make the key in this tab",
    description:
      "A fresh RSA-4096 key is created inside this browser; the private half never leaves it. An encrypted backup file is written when you ask.",
  },
  {
    flow: 2,
    slug: "bring-your-own",
    title: "Bring a key file you already keep",
    description:
      "Import an existing PEM; it is read in memory, fingerprinted, and zeroed after signing.",
  },
  {
    flow: 3,
    slug: "sign-elsewhere",
    title: "Sign on another machine",
    description:
      "Take the signing commands to an offline machine you control, then bring the signed result back for checking.",
  },
];

/** One shared card template → the three cards render with identical shape. */
function flowCardHtml(card: KeyFlowCard): string {
  return [
    `<article class="flow-card" data-flow="${String(card.flow)}">`,
    `<h3>${escapeHtml(card.title)}</h3>`,
    `<p>${escapeHtml(card.description)}</p>`,
    `<button type="button" class="btn-secondary" data-action="key-flow-chosen" data-flow="${String(card.flow)}">Choose this path</button>`,
    `</article>`,
  ].join("");
}

export function renderStep3(): string {
  return [
    headline(3, "Choose who makes your signing key."),
    `<p class="lede">No path is selected for you — the three cards below are equals.</p>`,
    `<div class="flow-cards">${KEY_FLOW_CARDS.map(flowCardHtml).join("")}</div>`,
  ].join("");
}

/**
 * Collect phase after a flow is chosen and before a fingerprint exists.
 * Passphrase length is enforced by exportEncryptedPem (≥12).
 */
export function renderStep3Collect(flow: 1 | 2 | 3): string {
  if (flow === 1) {
    return [
      headline(3, "Generate a key in this tab."),
      `<p class="lede">The private handle stays non-extractable. The only other copy is the encrypted file you save.</p>`,
      `<label for="generate-passphrase">Passphrase for the encrypted backup (at least 12 characters)</label>`,
      `<input id="generate-passphrase" data-role="generate-passphrase" type="password" minlength="12" autocomplete="new-password" />`,
      `<button type="button" class="btn-primary" data-action="generate-key">Generate key</button>`,
    ].join("");
  }
  if (flow === 2) {
    return [
      headline(3, "Import the key you already keep."),
      `<label for="file-user-pem">PEM file (PKCS#8, PKCS#1, or GuardTalk encrypted)</label>`,
      `<input type="file" id="file-user-pem" data-role="user-pem" />`,
      `<label for="import-passphrase">Passphrase (required when the file is encrypted)</label>`,
      `<input id="import-passphrase" data-role="import-passphrase" type="password" autocomplete="current-password" />`,
      `<button type="button" class="btn-primary" data-action="import-key">Import key</button>`,
    ].join("");
  }
  return [
    headline(3, "Use a key that signs elsewhere."),
    `<label for="file-public-pem">Public key PEM (SPKI)</label>`,
    `<input type="file" id="file-public-pem" data-role="public-pem" />`,
    `<button type="button" class="btn-primary" data-action="import-public">Continue with this public key</button>`,
  ].join("");
}

/** Step 4 collect: pick the release vbmeta.img before re-signing. */
export function renderStep4Collect(): string {
  return [
    headline(4, "Pick the release vbmeta this tab will re-sign."),
    `<label for="file-vbmeta">vbmeta.img from the unpacked release</label>`,
    `<input type="file" id="file-vbmeta" data-role="vbmeta" />`,
    `<button type="button" class="btn-primary" data-action="sign-vbmeta">Sign with your key</button>`,
  ].join("");
}

export interface FlowDetailInput {
  readonly flow: 1 | 2 | 3;
  readonly fingerprintHex: string;
  /** Flow 3 only: avbtool commands for offline signing. */
  readonly cliCommands?: string;
}

/** Step-3 detail after a flow is chosen: fingerprint + record confirmation. */
export function renderStep3FlowDetail(input: FlowDetailInput): string {
  const parts: string[] = [];
  if (input.flow === 3 && input.cliCommands !== undefined) {
    parts.push(
      `<section aria-labelledby="cli-heading"><h3 id="cli-heading">Run this on your offline signing machine</h3>`,
      `<pre class="cmd-block mono">${escapeHtml(input.cliCommands)}</pre>`,
      `<p class="note">When the machine returns a signed vbmeta, pick it below to continue.</p>`,
      `<div class="file-slot"><label for="file-signed-vbmeta">Signed vbmeta to re-check</label>`,
      `<input type="file" id="file-signed-vbmeta" data-role="signed-vbmeta" /></div>`,
      `</section>`,
    );
  }
  if (input.flow === 1) {
    parts.push(
      `<section aria-labelledby="backup-heading"><h3 id="backup-heading">Encrypted backup file</h3>`,
      `<p class="note">Save the encrypted key file somewhere offline; losing it means losing the ability to re-enrol this key.</p>`,
      `<a class="btn-secondary" data-role="key-download-link" download="guardtalk-user-key.enc">Save encrypted key file</a>`,
      `<p class="check-row"><label><input type="checkbox" data-role="download-saved" /> I saved the encrypted key file</label></p>`,
      `</section>`,
    );
  }
  parts.push(
    `<section aria-labelledby="fp-heading"><h3 id="fp-heading">Record your key fingerprint</h3>`,
    `<p class="fingerprint-row"><span class="fingerprint-label">Key fingerprint (SHA-256 over your public key material)</span>`,
    `<code class="mono" data-fingerprint>${escapeHtml(input.fingerprintHex)}</code></p>`,
    `<div class="retype-row">`,
    `<label for="retype-input">Type the last 8 characters to confirm you recorded it</label>`,
    `<input id="retype-input" data-role="retype" autocomplete="off" spellcheck="false" class="mono" maxlength="8" />`,
    `</div>`,
    `<button type="button" class="btn-primary" data-action="fingerprint-recorded">Record this fingerprint</button>`,
    `</section>`,
  );
  return parts.join("");
}

export interface Step3Guards {
  /** Exact-match retype of the displayed fingerprint's last 8 characters. */
  readonly typedTail: string;
  /** Flow 1 only: the encrypted-backup-saved checkbox state. */
  readonly downloadSaved?: boolean;
}

export interface Step3Decision {
  /** The single machine action to dispatch, or null when blocked. */
  readonly dispatch: InstallAction | null;
  readonly blockers: readonly string[];
  /**
   * Route-visible stop record for a wrong retype. The machine's condition
   * stops hard-freeze by design, and PLAN.md §1 requires the retype to stay
   * retryable — so this record feeds the tripwire banner while the live
   * machine state is left untouched (retry allowed, never skipped).
   */
  readonly retypeStop?: StopRecord;
}

/** Exact, case-sensitive match on the last 8 characters. */
export function retypeMatches(fingerprintHex: string, typedTail: string): boolean {
  return typedTail.trim() === fingerprintHex.slice(-8);
}

/**
 * Pure gate ahead of the single `fingerprint-recorded` machine action.
 * Wrong retype ⇒ FINGERPRINT_RETYPE_WRONG stop-record, retry allowed.
 * Flow 1 additionally demands the saved-backup confirmation.
 */
export function step3Decide(
  fingerprintHex: string,
  flow: 1 | 2 | 3,
  guards: Step3Guards,
): Step3Decision {
  const blockers: string[] = [];
  let retypeStop: StopRecord | undefined;
  if (!retypeMatches(fingerprintHex, guards.typedTail)) {
    blockers.push("retype");
    retypeStop = {
      step: 3,
      reasonId: "FINGERPRINT_RETYPE_WRONG",
      reason: STOP_REASONS.FINGERPRINT_RETYPE_WRONG,
    };
  }
  if (flow === 1 && guards.downloadSaved !== true) {
    blockers.push("download-saved");
  }
  if (blockers.length > 0) {
    return { dispatch: null, blockers, ...(retypeStop !== undefined ? { retypeStop } : {}) };
  }
  return { dispatch: { type: "fingerprint-recorded" }, blockers };
}

// ---------------------------------------------------------------------------
// Key-flow controllers (consume lib/keys; emit public halves only)
// ---------------------------------------------------------------------------

export interface GeneratedFlowResult {
  /** Non-extractable signing handle for the SAME key as the backup file. */
  readonly privateKey: CryptoKey;
  readonly publicJwk: JsonWebKey;
  readonly fingerprintHex: string;
  /** pkmd encoding of the public half — the blob flashed to avb_custom_key. */
  readonly pkmd: Uint8Array;
  /** Passphrase-sealed envelope for the user's offline keeping. */
  readonly armoredBackup: string;
}

function b64uToBigInt(value: string): bigint {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  let hex = "";
  for (let i = 0; i < binary.length; i += 1) {
    hex += binary.charCodeAt(i).toString(16).padStart(2, "0");
  }
  return BigInt(`0x${hex}`);
}

export function pkmdFromJwk(jwk: JsonWebKey): Uint8Array {
  const n = b64uToBigInt(jwk.n ?? "");
  const e = b64uToBigInt(jwk.e ?? "");
  return encodePkmd({ n, e });
}

/**
 * Flow 1: generate the key, seal an encrypted backup, and keep a
 * non-extractable signing handle for the SAME key.
 *
 * lib/keys/generate pins extractable:false, which can never yield the DER
 * the sealed envelope needs — so this controller performs one transient
 * extractable generation (the "extractable twin" pattern of the keys test
 * suite), exports the PKCS#8 once into the passphrase-sealed envelope, then
 * zeroises the DER and re-imports the handle as non-extractable for signing.
 * The transient plaintext exists only between those two awaits (D-007).
 */
export async function runGenerateFlow(passphrase: string): Promise<GeneratedFlowResult> {
  const twinPair = await crypto.subtle.generateKey(KEY_ALGORITHM, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", twinPair.privateKey));
  let armored: string;
  try {
    armored = await exportEncryptedPem({ der }, passphrase);
    const privateKey = await crypto.subtle.importKey(
      "pkcs8",
      der as BufferSource,
      KEY_ALGORITHM,
      false,
      ["sign"],
    );
    const jwk = await crypto.subtle.exportKey("jwk", twinPair.publicKey);
    delete jwk.d;
    delete jwk.p;
    delete jwk.q;
    delete jwk.dp;
    delete jwk.dq;
    delete jwk.qi;
    if (privateKey.extractable) {
      throw new Error("generated signing handle must be non-extractable");
    }
    const fingerprintHex = await fingerprintFromJwk(jwk);
    const pkmd = pkmdFromJwk(jwk);
    return { privateKey, publicJwk: jwk, fingerprintHex, pkmd, armoredBackup: armored };
  } finally {
    zeroise(der);
  }
}

export interface ImportedFlowResult {
  readonly imported: ImportedKey;
  readonly fingerprintHex: string;
  /** pkmd encoding of the public half (enrolment + flow-3 verification). */
  readonly pkmd: Uint8Array;
  readonly fingerprintOfPkmd: string;
  /** Signing material for lib/avb/signer (bigint form). */
  readonly signerMaterial: SignerKeyMaterial;
}

function signerMaterialFrom(imported: ImportedKey): SignerKeyMaterial {
  return {
    n: beBytesToBigInt(imported.material.n),
    e: beBytesToBigInt(imported.material.e),
    d: beBytesToBigInt(imported.material.d),
  };
}

/**
 * Flow 2: import an existing PEM (passphrase when encrypted).
 *
 * Byte copies of n/e/d(/p/q) are zeroised after they have been copied into
 * `signerMaterial`. The BigInt private exponent (`signerMaterial.d`) cannot
 * be overwritten in JavaScript — that is a platform limit, not a wipe.
 */
export async function runImportFlow(pemText: string, passphrase?: string): Promise<ImportedFlowResult> {
  const imported = await importPem(pemText, passphrase);
  const fingerprintHex = await fingerprintFromJwk(imported.publicJwk);
  const pkmd = pkmdFromJwk(imported.publicJwk);
  const signerMaterial = signerMaterialFrom(imported);
  zeroise(imported.material.n);
  zeroise(imported.material.e);
  zeroise(imported.material.d);
  if (imported.material.p !== undefined) {
    zeroise(imported.material.p);
  }
  if (imported.material.q !== undefined) {
    zeroise(imported.material.q);
  }
  return {
    imported,
    fingerprintHex,
    pkmd,
    fingerprintOfPkmd: await pkmdFingerprint(pkmd),
    signerMaterial,
  };
}

export interface SignElsewhereResult {
  readonly fingerprintHex: string;
  readonly pkmd: Uint8Array;
  readonly fingerprintOfPkmd: string;
}

/** Flow 3, part A: learn the public half of the offline key (SPKI PEM). */
export async function runSignElsewhereFlow(publicPem: string): Promise<SignElsewhereResult> {
  const { armoredPemToJwk } = await import("../../lib/verify/detached-sig.js");
  const jwk = await armoredPemToJwk(publicPem);
  const pkmd = pkmdFromJwk(jwk);
  return {
    fingerprintHex: await fingerprintFromJwk(jwk),
    pkmd,
    fingerprintOfPkmd: await pkmdFingerprint(pkmd),
  };
}

/** Flow 3: the exact avbtool commands (browser step 4 mirror) as mono text. */
export function cliSigningCommands(plan: CliExportPlan): string {
  return cliExportStepMap(plan)
    .filter((entry) => entry.browserStep === 4)
    .map((entry) => entry.command)
    .join("\n");
}

// ---------------------------------------------------------------------------
// Step 4 — Sign the release
// ---------------------------------------------------------------------------

export const STEP4_ALGORITHM = "SHA256_RSA4096" as const;

export interface SignViewModel {
  readonly status: "signed" | "verified-import" | "stopped";
  readonly algorithm: string;
  readonly keyFingerprintHex?: string;
  readonly rows: readonly ComparisonRow[];
  readonly chainPartitions?: readonly string[];
  readonly stopReason?: string;
}

export type SignMode =
  | { readonly kind: "sign"; readonly img: Uint8Array; readonly key: CryptoKey | SignerKeyMaterial; readonly keyFingerprintHex: string }
  | { readonly kind: "import"; readonly img: Uint8Array; readonly expectedPkmd: Uint8Array; readonly keyFingerprintHex: string };

export type SignOutcome =
  | { readonly kind: "signed" | "verified-import"; readonly view: SignViewModel; readonly signedImage: Uint8Array }
  | { readonly kind: "stop"; readonly condition: "partition-layout-unknown"; readonly view: SignViewModel };

async function subtleSha256Hex(parts: readonly Uint8Array[]): Promise<string> {
  let total = 0;
  for (const part of parts) {
    total += part.length;
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    merged.set(part, offset);
    offset += part.length;
  }
  const digest = await crypto.subtle.digest("SHA-256", merged as BufferSource);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function chainPartitionsOf(img: Uint8Array): readonly string[] {
  const parsed = parseVbmeta(img);
  return parsed.descriptors.filter(isChainDescriptor).map((d) => d.partitionName);
}

/**
 * Step-4 controller. Chain descriptors detected ⇒ PARTITION_LAYOUT_UNKNOWN
 * stop (Q-07) BEFORE any signing. The input must first verify against its own
 * embedded key — a corrupt input is never quietly re-signed. Then:
 * re-sign with the user's key and prove the roundtrip (fresh digest ==
 * stored digest, signature valid against the embedded key) before the caller
 * may emit `vbmeta-signed`.
 */
export async function signVbmetaStep(mode: SignMode): Promise<SignOutcome> {
  const chains = chainPartitionsOf(mode.img);
  if (chains.length > 0) {
    return {
      kind: "stop",
      condition: "partition-layout-unknown",
      view: {
        status: "stopped",
        algorithm: STEP4_ALGORITHM,
        rows: [],
        chainPartitions: chains,
        stopReason: STOP_REASONS.PARTITION_LAYOUT_UNKNOWN,
      },
    };
  }
  if (!(await verifyVbmeta(mode.img)).ok) {
    throw new Error("input vbmeta failed verification against its embedded key");
  }

  if (mode.kind === "sign") {
    const signed = await resignVbmeta(mode.img, mode.key);
    const roundtrip = await verifyVbmeta(signed);
    if (!roundtrip.ok) {
      throw new Error(`resigned vbmeta failed its own verification: ${roundtrip.failure ?? "unknown"}`);
    }
    const parsed = parseVbmeta(signed);
    const auxStart = 256 + parsed.header.authenticationDataBlockSize;
    const recomputed = await subtleSha256Hex([
      signed.subarray(0, 256),
      signed.subarray(auxStart, auxStart + parsed.header.auxiliaryDataBlockSize),
    ]);
    const stored = parsed.authHash !== undefined ? [...parsed.authHash].map((b) => b.toString(16).padStart(2, "0")).join("") : "";
    const row = sbsHexRow("new vbmeta digest (expected recomputed / actual stored)", recomputed, stored);
    return {
      kind: "signed",
      signedImage: signed,
      view: {
        status: "signed",
        algorithm: STEP4_ALGORITHM,
        keyFingerprintHex: mode.keyFingerprintHex,
        rows: [row],
      },
    };
  }

  const check = await verifyVbmetaAgainstKey(mode.img, mode.expectedPkmd);
  if (!check.ok) {
    throw new Error(`imported vbmeta did not verify against your public key: ${check.failure ?? "unknown"}`);
  }
  const expectedFp = await pkmdFingerprint(mode.expectedPkmd);
  const { embeddedKeyFingerprintHex } = await import("../../lib/avb/signer.js");
  const actualFp = await embeddedKeyFingerprintHex(mode.img);
  const row = sbsHexRow("enrolled key fingerprint (expected yours / actual embedded)", expectedFp, actualFp);
  return {
    kind: "verified-import",
    signedImage: mode.img,
    view: {
      status: "verified-import",
      algorithm: STEP4_ALGORITHM,
      keyFingerprintHex: mode.keyFingerprintHex,
      rows: [row],
    },
  };
}

export function renderStep4(view: SignViewModel): string {
  const parts: string[] = [headline(4, "Your key signs the boot anchor now.")];
  parts.push(`<p class="algo-row"><span class="algo-label">Signing algorithm</span> ${mono(view.algorithm)}</p>`);
  if (view.keyFingerprintHex !== undefined) {
    parts.push(
      `<p class="fingerprint-row"><span class="fingerprint-label">Your key fingerprint</span>`,
      `<code class="mono" data-fingerprint>${escapeHtml(view.keyFingerprintHex)}</code></p>`,
    );
  }
  if (view.stopReason !== undefined) {
    parts.push(`<p class="verdict-row">${stopChip()}</p>`);
    parts.push(`<p class="stop-reason">${escapeHtml(view.stopReason)}</p>`);
    if (view.chainPartitions !== undefined && view.chainPartitions.length > 0) {
      parts.push(
        `<p class="stop-detail">chained partitions detected: ${escapeHtml(view.chainPartitions.join(", "))}</p>`,
      );
    }
    parts.push(`<p class="confirm-line mono">${escapeHtml(PARTITION_LAYOUT_CONFIRM)}</p>`);
  }
  for (const row of view.rows) {
    parts.push(row.html);
  }
  if (view.status !== "stopped") {
    parts.push(`<button type="button" class="btn-primary" data-action="vbmeta-signed">Continue to the device step</button>`);
  }
  return parts.join("");
}

// ---------------------------------------------------------------------------
// Encrypted-backup confirmation dialog (Esc cancels without stranding awaits)
// ---------------------------------------------------------------------------

/**
 * Dialog contract for the flow-1 "saved it?" double-check. Confirm/cancel
 * resolve the awaiting operation only — never the machine. Escape funnels
 * through lib/ui/dialog's cancel path (native `cancel` event included), so
 * an Esc press always resolves the awaiter as cancelled.
 */
export function downloadConfirmDialogOptions(): DialogOptions<boolean> {
  return {
    labelledBy: "dl-confirm-title",
    build(host, helpers) {
      const doc = host.ownerDocument;
      const h2 = doc.createElement("h2");
      h2.id = "dl-confirm-title";
      h2.textContent = "Did the encrypted key file finish saving?";
      const p = doc.createElement("p");
      p.textContent = "Continue only when the file is on disk — this check protects your only backup.";
      const yes = doc.createElement("button");
      yes.type = "button";
      yes.textContent = "Yes, it is saved";
      yes.setAttribute("data-dialog", "confirm");
      yes.addEventListener("click", () => helpers.confirm(true));
      const no = doc.createElement("button");
      no.type = "button";
      no.textContent = "Not yet";
      no.setAttribute("data-dialog", "cancel");
      no.addEventListener("click", () => helpers.cancel());
      host.append(h2, p, yes, no);
    },
  };
}
