#!/usr/bin/env node
/**
 * anchor-mode.mjs — WHICH trust mechanism actually authenticated the channels.
 *
 * T-WEBINSTALL-SIGNED-ROOT-MODE-SURFACE. `T-WEBINSTALL-SIGNED-CHANNEL-ROOT`
 * acceptance (d) required the readiness gate to NAME THE MODE IN FORCE, so a
 * reader cannot mistake the dev channel (unsigned, review-gated pins) for a
 * production-signed one. Before this module the only authenticity signal was
 * the `trust-anchor` clause detail, which reads like a POSITIVE:
 *
 *   [ok] trust-anchor: all 4 packed channel(s) match their out-of-band AVB
 *        anchor pins
 *
 * A reader had to already know that "out-of-band AVB anchor pins" means
 * review-gated / unsigned / NOT GrapheneOS-equivalent. That is a legibility
 * failure on the honesty surface: the gate verified something true and left the
 * reader free to read it as "signed".
 *
 * THE MODE IS DERIVED, NEVER HARDCODED. `deriveAnchorMode` takes the EVIDENCE
 * of what actually ran and reports what that evidence supports:
 *
 *   - `signed-root`        — only when a caller supplies a signed-root
 *                            verification result that a verifier PRODUCED
 *                            (`{ mechanism: "signed-root", verified: true }`).
 *                            Since `T-WEBINSTALL-SIGNED-CHANNEL-ROOT` that
 *                            verifier exists: `scripts/channel-signature.mjs`
 *                            verifies a signature over the channel root against
 *                            an out-of-band trust list, and the readiness gate
 *                            feeds its verdict in. The branch still cannot be
 *                            reached by a document CLAIMING to be signed (see
 *                            `signedRootEvidence` below).
 *   - `review-gated-pins`  — the out-of-band pin document was consulted, the
 *                            shipped bytes were compared against every pin, and
 *                            EVERY pin matched (`validated: true`). The label
 *                            always says UNSIGNED.
 *   - `unverified`         — nothing validated: no anchor result (a drill with
 *                            the pin document absent, or a gate that could not
 *                            evaluate), or the pins were consulted and did NOT
 *                            match. `mechanism` still names what ran, so the
 *                            reader can tell "never checked" from "checked and
 *                            failed" — but neither is reported as a mode with
 *                            integrity. Fail closed.
 *
 * WHAT THIS MODULE DOES NOT DO: it does not verify anything itself and it does
 * not raise the mode on a self-description. Trusting `pins.signedRoot === true`
 * would be exactly the laundering this module exists to prevent — the pin
 * document is a checked-in constant, not a signature, and nothing
 * cryptographically binds it to the vbmeta images (see `trust-anchor.mjs`).
 *
 * HONESTY: BOOT_VERIFIED=false. A mode names the AUTHENTICITY MECHANISM only —
 * never that the images boot, and never that a live flash happened.
 */

/** The mode identifiers. `id` is machine-readable; `label` is for humans. */
export const ANCHOR_MODE = Object.freeze({
  /** Checked-in, review-gated AVB anchor pins (`docs/expected-anchors.json`). */
  reviewGatedPins: "review-gated-pins",
  /** A verified signed root (production) — see `scripts/channel-signature.mjs`. */
  signedRoot: "signed-root",
  /** No mechanism validated — fail closed, never "probably fine". */
  unverified: "unverified",
});

/** The qualifier that must never be dropped from the unsigned mode's label. */
export const NOT_GRAPHEMEOS_EQUIVALENT = "not GrapheneOS-equivalent";

/** The label of the `unverified` mode (absence is not integrity). */
const UNVERIFIED_LABEL = `unverified (no validating mechanism ran — ${NOT_GRAPHEMEOS_EQUIVALENT})`;

/**
 * Accept a signed-root result ONLY from a verifier that produced one.
 *
 * `mechanism === "signed-root"` AND `verified === true` are both required, so a
 * document that merely *claims* a signed root cannot raise the mode: a claim has
 * no `mechanism`/`verified` verdict from a verifier behind it. This is the
 * anti-laundering seatbelt for the future signed path.
 *
 * @param {unknown} evidence
 * @returns {{channel:string|null}|null}
 */
function signedRootEvidence(evidence) {
  if (typeof evidence !== "object" || evidence === null) return null;
  const candidate = /** @type {Record<string, unknown>} */ (evidence);
  if (candidate.mechanism !== ANCHOR_MODE.signedRoot) return null;
  if (candidate.verified !== true) return null;
  return { channel: typeof candidate.channel === "string" ? candidate.channel : null };
}

/**
 * Did the pin mechanism actually run? Evidence, not assumption: an anchor
 * result exists AND it evaluated at least one channel.
 *
 * @param {unknown} anchorResult
 * @returns {boolean}
 */
function pinsActuallyRan(anchorResult) {
  if (typeof anchorResult !== "object" || anchorResult === null) return false;
  const result = /** @type {Record<string, unknown>} */ (anchorResult);
  return Array.isArray(result.results) && result.results.length > 0;
}

/**
 * Derive the anchor mode from the evidence of what validated.
 *
 * @param {{
 *   anchorResult?: unknown,        // `checkTrustAnchors(...)` output, or null
 *   pins?: unknown,                // `loadAnchorPinsFromText(...)` output, or null
 *   signatureVerification?: unknown, // a verifier's signed-root result, if any
 * }} [evidence]
 * @returns {{
 *   id: "review-gated-pins"|"signed-root"|"unverified",
 *   mechanism: "review-gated-pins"|"signed-root"|"none",
 *   validated: boolean,
 *   signed: boolean,
 *   channel: string|null,
 *   label: string,
 * }}
 */
export function deriveAnchorMode(evidence = {}) {
  const anchorResult = evidence.anchorResult ?? null;
  const pins = evidence.pins ?? null;
  const pinsChannel =
    typeof pins === "object" && pins !== null && typeof (/** @type {any} */ (pins).channel) === "string"
      ? /** @type {string} */ (/** @type {any} */ (pins).channel)
      : null;

  // A signed root, WHEN A VERIFIER PRODUCED ONE, supersedes the pin mechanism:
  // it is the stronger claim and the one that would be in force.
  const signed = signedRootEvidence(evidence.signatureVerification);
  if (signed !== null) {
    return Object.freeze({
      id: ANCHOR_MODE.signedRoot,
      mechanism: ANCHOR_MODE.signedRoot,
      validated: true,
      signed: true,
      channel: signed.channel ?? pinsChannel,
      label: "signed-root (production)",
    });
  }

  // No mechanism ran: fail closed. `validated:false` and no integrity claim.
  if (!pinsActuallyRan(anchorResult)) {
    return Object.freeze({
      id: ANCHOR_MODE.unverified,
      mechanism: "none",
      validated: false,
      signed: false,
      channel: pinsChannel,
      label: UNVERIFIED_LABEL,
    });
  }

  const channelPart = pinsChannel === null ? "" : `, channel=${pinsChannel}`;

  // The pin mechanism RAN and every pin matched: this is the mode in force.
  if (/** @type {any} */ (anchorResult).ok === true) {
    return Object.freeze({
      id: ANCHOR_MODE.reviewGatedPins,
      mechanism: ANCHOR_MODE.reviewGatedPins,
      validated: true,
      signed: false,
      channel: pinsChannel,
      label: `${ANCHOR_MODE.reviewGatedPins} (unsigned${channelPart} — ${NOT_GRAPHEMEOS_EQUIVALENT})`,
    });
  }

  // Nothing validated. Report `unverified` — never a mode that reads like
  // integrity — and say which of the two reasons applies.
  const pinsConsultable =
    typeof pins === "object" && pins !== null && typeof (/** @type {any} */ (pins).problem) === "string";
  return Object.freeze({
    id: ANCHOR_MODE.unverified,
    mechanism: pinsConsultable ? "none" : ANCHOR_MODE.reviewGatedPins,
    validated: false,
    signed: false,
    channel: pinsChannel,
    label: pinsConsultable
      ? UNVERIFIED_LABEL
      : `unverified (review-gated pins did NOT validate — unsigned, ${NOT_GRAPHEMEOS_EQUIVALENT})`,
  });
}
