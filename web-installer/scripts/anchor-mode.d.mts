/**
 * Type declarations for the anchor-mode derivation
 * (T-WEBINSTALL-SIGNED-ROOT-MODE-SURFACE).
 *
 * The mode names the authentication mechanism ACTUALLY IN FORCE. It is derived
 * from evidence (`scripts/anchor-mode.mjs`), never hardcoded — so a drill that
 * changes the mechanism changes the field.
 */

/** Machine-readable mode identifier. */
export type AnchorModeId = "review-gated-pins" | "signed-root" | "unverified";

/** Human-/machine-readable account of the mode in force. */
export interface AnchorMode {
  readonly id: AnchorModeId;
  /** Which validator produced the result: a pin check, a signed root, or none. */
  readonly mechanism: "review-gated-pins" | "signed-root" | "none";
  /** True only when the mechanism that ran actually validated. */
  readonly validated: boolean;
  /** True only for a VERIFIED signed root. Always false for review-gated pins. */
  readonly signed: boolean;
  /** The channel the pin document declares, when one was consulted. */
  readonly channel: string | null;
  /**
   * The string the gate prints, e.g.
   * `review-gated-pins (unsigned, channel=dev — not GrapheneOS-equivalent)`.
   */
  readonly label: string;
}

/**
 * A signed-root verification result. Only a VERIFIER produces this —
 * `scripts/channel-signature.mjs` is that verifier (T-WEBINSTALL-SIGNED-
 * CHANNEL-ROOT). A document merely claiming `signedRoot: true` does NOT
 * satisfy this shape.
 */
export interface SignedRootVerification {
  mechanism: "signed-root";
  verified: boolean;
  channel?: string;
}

export declare const ANCHOR_MODE: {
  readonly reviewGatedPins: "review-gated-pins";
  readonly signedRoot: "signed-root";
  readonly unverified: "unverified";
};

export declare const NOT_GRAPHEMEOS_EQUIVALENT: string;

export declare function deriveAnchorMode(evidence?: {
  /** `checkTrustAnchors(...)` output, or null when the pin check did not run. */
  anchorResult?: unknown;
  /** `loadAnchorPinsFromText(...)` output, or null when no pin document was read. */
  pins?: unknown;
  /** A verifier's signed-root result, if one exists. */
  signatureVerification?: unknown;
}): AnchorMode;
