/**
 * Unavailable-fact affordance (F-WEBINSTALL-PLACEHOLDER-RETIREMENT, D-041).
 *
 * A shipped page must never carry a pending-confirmation token. Read by a user,
 * such a token is an instruction with no value behind it; read by an attacker,
 * it is an invitation to supply the missing value. The programme's honesty rule
 * (`status.json` is `alpha`, `preLaunch: true`) allows exactly two legitimate
 * replacements, and this module is the second one:
 *
 *   1. FILL from a real, in-repo product fact (no constant here — a fact that
 *      exists is read from its one source, never copied into this file); or
 *   2. state honestly that the value is UNAVAILABLE, name what is missing,
 *      record where the absence comes from, say what the user must do instead,
 *      and name what it blocks.
 *
 * NOTHING IS INVENTED HERE. Every fact below exists because the value genuinely
 * does not: `status.json` ships `onion.address: null` (Q-05), no release public
 * key is checked into this tree so there is no fingerprint to publish (Q-04),
 * and the chained-partition write order is not recorded in the plan data (Q-07).
 * A future build that acquires one of these values deletes its entry here and
 * renders the value instead — it does not fill this table in.
 *
 * Rendering reuses the existing notice primitive (`glAlertHtml`) and the shared
 * chip primitive (`makeChip`); this module adds no second status or
 * announcement mechanism (D-017).
 */
import { makeChip } from "./chips.js";
import { escapeHtml } from "./escape.js";
import { glAlertHtml } from "./pajamas.js";

/** Open-question ids these facts answer. `Q-06` is absent: its value exists. */
export type MissingFactId = "Q-04" | "Q-05" | "Q-07" | "Q-08";

/** The one chip word every unavailable fact carries. */
export const UNAVAILABLE_CHIP_WORD = "UNAVAILABLE — DO NOT PROCEED";

export interface MissingFact {
  readonly id: MissingFactId;
  /** What is missing, as a noun phrase ("Release onion address"). */
  readonly label: string;
  /** One sentence: the value is not in this build. */
  readonly what: string;
  /** Where the absence is recorded, so the claim is checkable. */
  readonly evidence: string;
  /** Exactly what the user must do instead. Never a guess. */
  readonly action: string;
  /** Which step this gates, and what happens while it is missing. */
  readonly blocks: string;
}

/**
 * Q-05. `status.json` line 9 ships `"address": null` — there has never been an
 * address to publish, so none may appear in the shipped site.
 */
export const ONION_ADDRESS_FACT: MissingFact = Object.freeze({
  id: "Q-05",
  label: "Release onion address",
  what: "this build publishes no address for the release.",
  evidence: "status.json ships onion.address as null, so there is no address to show and none is made up here.",
  action:
    "take the address from the release announcement you already received, through a source you can name. If you cannot name where an address came from, stop — a bundle from an unnamed source is not one you can check.",
  blocks:
    "step 6 (flash). The posture gate there stays shut until you have compared the release against a fingerprint you obtained outside this page.",
});

/**
 * Q-04. No release public key is checked into this tree, so no fingerprint can
 * be published and no value may be guessed.
 */
export const RELEASE_FINGERPRINT_FACT: MissingFact = Object.freeze({
  id: "Q-04",
  label: "Release-key fingerprint",
  what: "this build publishes no fingerprint for the GuardTalk release key.",
  evidence:
    "no release public key is checked into this tree, so there is no key to fingerprint and no value to compare against.",
  action:
    "take the fingerprint from the release announcement, then compare it, character for character, with the fingerprint of the release public key you import at step 2. Both strings must be identical.",
  blocks:
    "step 6 (flash). The posture gate there stays shut until that comparison has been made outside this page.",
});

/**
 * Q-07. The chain-detector stop (`PARTITION_LAYOUT_UNKNOWN`) already halts the
 * flow; this fact explains it without a token the user could try to satisfy.
 */
export const PARTITION_LAYOUT_FACT: MissingFact = Object.freeze({
  id: "Q-07",
  label: "Chained-partition layout",
  what: "the write order these chained vbmeta_* descriptors describe is not recorded, so this installer stops instead of guessing one.",
  evidence:
    "the release carries chained descriptors, and this build's plan data does not map them to a write order.",
  action:
    "do not sign or flash this release from this page. Sign it on a machine where you can read the release's own descriptor list (avbtool info_image), or wait for a build that maps these chains.",
  blocks:
    "step 4 (sign), and therefore every later step: no vbmeta is signed while the layout is unknown.",
});

/**
 * Q-08. The sideload path is unconfirmed, so the page carries no instructions
 * for it. It blocks nothing — the fastboot path on the page is the shipped one,
 * and saying so is more honest than a token that implies the path might exist.
 */
export const SIDELOAD_PATH_FACT: MissingFact = Object.freeze({
  id: "Q-08",
  label: "Recovery-sideload update path",
  what: "no sideload instructions ship, because the path has never been confirmed on hardware.",
  evidence:
    "the fastboot path on this page is the one that has been exercised; the sideload variant has not.",
  action:
    "use the fastboot path on this page. Do not improvise a sideload sequence from another device's instructions.",
  blocks: "nothing here: the fastboot path proceeds normally, and no sideload route is implied.",
});

/** Every unavailable fact, keyed by id. Data only — a test pins the shipped set. */
export const MISSING_FACTS: Readonly<Record<MissingFactId, MissingFact>> = Object.freeze({
  "Q-04": RELEASE_FINGERPRINT_FACT,
  "Q-05": ONION_ADDRESS_FACT,
  "Q-07": PARTITION_LAYOUT_FACT,
  "Q-08": SIDELOAD_PATH_FACT,
});

/**
 * The honest "unavailable" block: chip + a three-row definition list stating
 * what is missing, where the absence is recorded, what to do, and what it
 * blocks. Reuses `glAlertHtml` (the existing notice primitive) so this adds no
 * new announcement mechanism; `data-proceed="forbidden"` makes the refusal
 * machine-checkable.
 */
export function renderUnavailableFact(fact: MissingFact): string {
  const body = [
    `<p class="unavailable-fact__missing">${escapeHtml(fact.label)}: ${escapeHtml(fact.what)}</p>`,
    `<dl class="unavailable-fact__facts">`,
    `<dt>Where the absence is recorded</dt><dd>${escapeHtml(fact.evidence)}</dd>`,
    `<dt>What you must do</dt><dd>${escapeHtml(fact.action)}</dd>`,
    `<dt>What this blocks</dt><dd>${escapeHtml(fact.blocks)}</dd>`,
    `</dl>`,
  ].join("");
  return [
    `<div class="unavailable-fact" data-unavailable="${fact.id}" data-proceed="forbidden">`,
    makeChip(UNAVAILABLE_CHIP_WORD, "caution"),
    glAlertHtml("warning", `${fact.label} — unavailable in this build`, body, "unavailable-fact__notice"),
    `</div>`,
  ].join("");
}

/**
 * Plain-text form for the CLI export. The export is a shell script a user runs
 * in a terminal, so the same honesty rule applies to `#` comments and to the
 * `abort` reason: the text names the missing value and what to do instead.
 * Returned as lines so the emitter controls the `#` prefix (never doubled).
 */
export function unavailableFactLines(fact: MissingFact): readonly string[] {
  return [
    `${fact.label} (${fact.id}) — UNAVAILABLE IN THIS BUILD. DO NOT PROCEED.`,
    `what: ${fact.what}`,
    `why: ${fact.evidence}`,
    `do: ${fact.action}`,
    `blocks: ${fact.blocks}`,
  ];
}
