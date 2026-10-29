/**
 * Posture approval gate (F-WEBINSTALL-POSTURE-APPROVAL-FLOW, D-042).
 *
 * The shipped posture is `alpha` (`status.json`: `installer`/`keyCustody`/
 * `releaseState` all `alpha`, `preLaunch: true`), every packed channel is
 * `dev/unlocked` with `verifiedBootClaim: "none"`, and nothing on this page is
 * GrapheneOS-equivalent locked verified boot. Those facts are not footnotes:
 * they are the terms the user is accepting when they commit to a write.
 *
 * This module holds that posture as DATA and answers one question — may the
 * destructive step open? — in ONE place, so the rendered gate and every guard
 * read the same verdict:
 *
 *   pass              all requirements met (a future production build)
 *   approved          requirements unmet, and this product's exact codename was
 *                     typed at the decision point
 *   approval-required requirements unmet and no valid approval yet  → closed
 *   stop              the posture contradicts itself or uses a state this
 *                     installer cannot present → closed, and NO acknowledgement
 *                     can open it (an unmet requirement stops the flow rather
 *                     than degrading into a warning)
 *
 * NON-BYPASSABLE BY CONSTRUCTION:
 *   - the approval is the device CODENAME typed into an empty text input, so it
 *     cannot be pre-ticked and has no default;
 *   - `acknowledgementMatches` is the exact matcher the readiness gate already
 *     uses (`lib/ui/readiness.ts`), not a second copy;
 *   - an approval is bound to the product it was typed for, so switching device
 *     invalidates it;
 *   - the route guards (`flashNow`, `runUpdateFlow`) re-evaluate this verdict
 *     before any device operation, so the check is not a property of the DOM.
 *
 * Reuse: `chips.ts` for every word, `live-region.ts` for the assertive
 * announcement, `posture.ts` for the pill text and the connectivity/custody
 * invariants, `readiness.ts` for the exact-codename matcher and BOOT_VERIFIED.
 * No new status mechanism, no new storage, no network (D-006/D-007).
 */
import { makeChip } from "./chips.js";
import { escapeHtml } from "./escape.js";
import { liveRegionHtml } from "./live-region.js";
import type { OfferedProduct } from "./offered-devices.js";
import { POSTURE_CONNECTIVITY, POSTURE_CUSTODY, renderPosturePill } from "./posture.js";
import { BOOT_VERIFIED, acknowledgementMatches } from "./readiness.js";

/** The posture word `status.json` ships today. */
export const ALPHA_RELEASE_STATE = "alpha";
/** The channel every packed channel manifest reports. */
export const DEV_UNLOCKED_CHANNEL = "dev/unlocked";
/** The existing authoritative phrasing (README, wizard, schema) — reused verbatim. */
export const NOT_GRAPHENEOS_EQUIVALENT = "not GrapheneOS-equivalent locked verified boot";
/** Release states this installer can present. Anything else fails closed. */
export const KNOWN_RELEASE_STATES: readonly string[] = [ALPHA_RELEASE_STATE, "release"];

/** The posture as data. Mirrors `status.json` + the packed channel manifest. */
export interface PostureFacts {
  readonly releaseState: string;
  readonly preLaunch: boolean;
  readonly liveFlashClaimed: boolean;
  readonly channelLabel: string;
  readonly verifiedBootClaim: string;
}

/**
 * The shipped posture, as constants. `status.json` is never fetched at runtime
 * (CSP `connect-src 'none'`, D-006); this is the D-009/D-011 baking pattern,
 * and `posture-approval.test.ts` pins each field against the live file so a
 * hand-edit cannot drift.
 */
export const SHIPPED_POSTURE: PostureFacts = Object.freeze({
  releaseState: ALPHA_RELEASE_STATE,
  preLaunch: true,
  liveFlashClaimed: false,
  channelLabel: DEV_UNLOCKED_CHANNEL,
  verifiedBootClaim: "none",
});

export type PostureRequirementId =
  | "release-state"
  | "channel"
  | "verified-boot"
  | "live-flash";

export interface PostureRequirement {
  readonly id: PostureRequirementId;
  /** The shipped word, so the user reads the fact rather than a summary. */
  readonly label: string;
  readonly detail: string;
  /** True only when the production fact holds WITHOUT any acknowledgement. */
  readonly met: boolean;
}

/**
 * The requirements a production posture would satisfy on its own. Each one is
 * derived from `facts`, never listed twice: a field that changes flips exactly
 * one requirement.
 */
export function postureRequirements(facts: PostureFacts): readonly PostureRequirement[] {
  return [
    {
      id: "release-state",
      label: `${facts.releaseState} release state`,
      detail: `status.json ships installer/releaseState "${facts.releaseState}" with preLaunch ${String(facts.preLaunch)}; no release of this product has been declared finished.`,
      met: facts.releaseState !== ALPHA_RELEASE_STATE && !facts.preLaunch,
    },
    {
      id: "channel",
      label: `${facts.channelLabel} channel`,
      detail: `every packed channel manifest reports channelLabel "${facts.channelLabel}": the bootloader is expected to stay open, which is not how a finished device ships.`,
      met: facts.channelLabel !== DEV_UNLOCKED_CHANNEL,
    },
    {
      id: "verified-boot",
      label: NOT_GRAPHENEOS_EQUIVALENT,
      detail: `the channel reports verifiedBootClaim "${facts.verifiedBootClaim}", so no locked verified-boot property is being offered.`,
      met: facts.verifiedBootClaim !== "none",
    },
    {
      id: "live-flash",
      label: "no live flash has been claimed",
      detail: `status.json ships flashCapability.liveFlashClaimed ${String(facts.liveFlashClaimed)}; a claimed live flash would be a result no host check produced.`,
      met: facts.liveFlashClaimed === false,
    },
  ];
}

/**
 * Postures that cannot be approved by anyone, because the facts contradict each
 * other or name a state this installer cannot present. A requirement that
 * cannot be met AND cannot be read is a STOP, never a warning.
 */
export function postureContradictions(facts: PostureFacts): readonly string[] {
  const out: string[] = [];
  if (facts.liveFlashClaimed && facts.preLaunch) {
    out.push(
      "This build is flagged pre-launch and also records a live flash. Both cannot be true; no acknowledgement can accept a posture that contradicts itself.",
    );
  }
  if (facts.verifiedBootClaim !== "none" && facts.channelLabel === DEV_UNLOCKED_CHANNEL) {
    out.push(
      `A ${DEV_UNLOCKED_CHANNEL} channel cannot also claim GrapheneOS-equivalent locked verified boot. Both cannot be true; no acknowledgement can accept a posture that contradicts itself.`,
    );
  }
  if (!KNOWN_RELEASE_STATES.includes(facts.releaseState)) {
    out.push(
      `Release state '${facts.releaseState}' is not a state this installer can present. Refusing rather than assuming what it means.`,
    );
  }
  return out;
}

/** The typed approval. Bound to one product so it cannot carry over. */
export interface PostureApproval {
  readonly typedCodename: string;
  readonly forProduct: OfferedProduct;
}

export type PostureVerdictKind = "pass" | "approved" | "approval-required" | "stop";

export interface PostureVerdict {
  readonly kind: PostureVerdictKind;
  readonly requirements: readonly PostureRequirement[];
  readonly unmet: readonly PostureRequirement[];
  /** Why the flow is closed. Empty for `pass` and `approved`. */
  readonly blockers: readonly string[];
  /** Verbatim stop reason; present only for `kind: "stop"`. */
  readonly stopReason?: string;
}

/** The one instruction an approval has to follow. Shown and quoted verbatim. */
export function approvalInstruction(product: OfferedProduct): string {
  return `Type the device codename (${product}) to approve this alpha posture for this device.`;
}

/** True for the two verdicts that let the destructive step open. */
export function postureOpen(verdict: PostureVerdict): boolean {
  return verdict.kind === "pass" || verdict.kind === "approved";
}

/**
 * THE decision. Pure: same facts + same approval ⇒ same verdict. Called by the
 * renderer and by every guard, so the page and the state machine cannot
 * disagree about whether the flow is open.
 */
export function evaluatePosture(
  facts: PostureFacts,
  product: OfferedProduct,
  approval: PostureApproval | undefined,
): PostureVerdict {
  const requirements = postureRequirements(facts);
  const contradictions = postureContradictions(facts);
  if (contradictions.length > 0) {
    return {
      kind: "stop",
      requirements,
      unmet: requirements.filter((requirement) => !requirement.met),
      blockers: contradictions,
      stopReason: contradictions[0] ?? "posture contradicts itself",
    };
  }
  const unmet = requirements.filter((requirement) => !requirement.met);
  if (unmet.length === 0) {
    return { kind: "pass", requirements, unmet: [], blockers: [] };
  }
  const named = unmet.map((requirement) => requirement.label).join("; ");
  const blockers: string[] = [
    `${String(unmet.length)} posture requirement(s) are unmet in this build: ${named}.`,
  ];
  if (approval === undefined) {
    return { kind: "approval-required", requirements, unmet, blockers };
  }
  if (approval.forProduct !== product) {
    blockers.push(
      `The approval was typed for '${approval.forProduct}', not '${product}'. An approval covers one device only and does not carry over.`,
    );
    return { kind: "approval-required", requirements, unmet, blockers };
  }
  if (!acknowledgementMatches(product, approval.typedCodename)) {
    blockers.push(
      `The typed value did not match '${product}'. A bare confirmation is not consent for an alpha build.`,
    );
    return { kind: "approval-required", requirements, unmet, blockers };
  }
  return { kind: "approved", requirements, unmet, blockers: [] };
}

/**
 * The refusal text for a guard, or `undefined` when the flow may open. The
 * approval instruction is appended HERE (not carried inside `blockers`) so the
 * rendered gate shows it once, as the input's label, while a refusal surfaced
 * in a notice still tells the user exactly what to type.
 */
export function postureRefusal(
  verdict: PostureVerdict,
  product: OfferedProduct,
): string | undefined {
  if (postureOpen(verdict)) {
    return undefined;
  }
  if (verdict.kind === "stop") {
    return verdict.blockers.join(" ");
  }
  return [...verdict.blockers, approvalInstruction(product)].join(" ");
}

export interface PostureGateView {
  readonly verdict: PostureVerdict;
  readonly product: OfferedProduct;
  readonly deviceName: string;
  readonly typedCodename?: string;
}

function requirementListHtml(requirements: readonly PostureRequirement[]): string {
  const items = requirements.map(
    (requirement) =>
      [
        `<li data-posture-requirement="${requirement.id}" data-met="${requirement.met ? "true" : "false"}">`,
        makeChip(requirement.met ? "MET" : "NOT MET", requirement.met ? "neutral" : "caution"),
        ` <span class="mono">${escapeHtml(requirement.label)}</span> — ${escapeHtml(requirement.detail)}`,
        `</li>`,
      ].join(""),
  );
  return `<ul class="posture-gate__requirements">${items.join("")}</ul>`;
}

/**
 * The gate at the point of decision (install step 6 / update step 6). While
 * closed it is an assertive, atomic live region (D-017) so the refusal reaches
 * a screen reader without waiting for focus; while open it is a calm summary.
 * The approval control is a text input with no default value — nothing here can
 * be pre-ticked.
 */
export function renderPostureGate(view: PostureGateView): string {
  const open = postureOpen(view.verdict);
  const stopped = view.verdict.kind === "stop";
  const chip = open
    ? makeChip("POSTURE APPROVED — ALPHA, ACCEPTED FOR THIS DEVICE", "caution")
    : stopped
      ? makeChip("FLOW STOPPED — POSTURE CANNOT BE APPROVED", "tripwire", { ariaLive: "assertive" })
      : makeChip("POSTURE REQUIRES YOUR APPROVAL", "caution");
  // The verdict kind is carried as data so a structural check can tell a closed
  // gate from an open one without reading the chip wording.
  const stateLine = `<p class="posture-gate__state" data-posture-gate="${view.verdict.kind}">${chip}</p>`;
  const head = [
    `<h3 class="posture-gate__heading" id="posture-gate-heading">Before anything is written: this build is ${escapeHtml(ALPHA_RELEASE_STATE)}.</h3>`,
    `<p class="posture-gate__pill">${renderPosturePill({
      connectivity: POSTURE_CONNECTIVITY,
      custody: POSTURE_CUSTODY,
      releaseState: ALPHA_RELEASE_STATE,
    })}</p>`,
    `<p class="posture-gate__device">Writing to <span class="mono">${escapeHtml(view.deviceName)}</span> (<span class="mono">${escapeHtml(view.product)}</span>).</p>`,
  ].join("");
  const requirements = requirementListHtml(view.verdict.requirements);
  const flag = `<p class="posture-gate__flag mono">BOOT_VERIFIED=${String(BOOT_VERIFIED)} — no boot evidence exists for any build this page offers.</p>`;

  if (open) {
    return [
      `<section class="posture-gate" aria-labelledby="posture-gate-heading">`,
      stateLine,
      head,
      requirements,
      flag,
      `</section>`,
    ].join("");
  }

  const blockers = view.verdict.blockers
    .map((blocker) => `<li>${escapeHtml(blocker)}</li>`)
    .join("");
  const control = stopped
    ? `<p class="posture-gate__no-path">No acknowledgement opens this gate: the posture itself has to change first. Nothing is written and the flow stays at this step.</p>`
    : [
        `<label for="posture-approval">${escapeHtml(approvalInstruction(view.product))}</label>`,
        `<input type="text" id="posture-approval" name="posture-approval" data-role="posture-approval"`,
        ` autocomplete="off" spellcheck="false" value="${escapeHtml(view.typedCodename ?? "")}" />`,
        `<button type="button" class="btn-secondary posture-gate__approve" data-action="approve-posture">Approve this alpha posture for ${escapeHtml(view.product)}</button>`,
      ].join("");
  const body = [
    stateLine,
    head,
    requirements,
    flag,
    `<ul class="posture-gate__blockers">${blockers}</ul>`,
    control,
  ].join("");
  // Assertive + atomic with a stable id (live-region.ts refuses an anonymous
  // assertive region), so a closed gate is announced the moment it renders.
  return liveRegionHtml("assertive", body, { id: "posture-gate", className: "posture-gate" });
}
