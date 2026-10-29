/**
 * Type declarations for the readiness gate (T-WEBINSTALL-FLASHALL-READINESS-GATE).
 */
import type { FlashMatrix } from "./gen-flash-matrix.mjs";
import type { AnchorMode, SignedRootVerification } from "./anchor-mode.mjs";
import type { SignedRootStatus, defaultVerifyRunner } from "./channel-signature.mjs";

export interface GateClause {
  id: string;
  description: string;
  ok: boolean;
  detail: string;
}

export interface GateResult {
  pass: boolean;
  clauses: GateClause[];
  /** The authentication mechanism actually in force (T-WEBINSTALL-SIGNED-ROOT-MODE-SURFACE). */
  anchorMode: AnchorMode;
  /**
   * The structured record of the SIGNED CHANNEL ROOT check
   * (T-WEBINSTALL-SIGNED-CHANNEL-ROOT): whether the mode demanded a signature,
   * what the verifier found, which trust list was consulted, and the per-channel
   * verdicts. `anchorMode` stays the legible label; this is the machine record.
   */
  authenticity: GateAuthenticity;
}

/** One packed channel's signed-root verdict, as the gate reports it. */
export interface GateAuthenticityChannel {
  product: string;
  status: SignedRootStatus;
  verified: boolean;
  detail: string;
  statement: string | null;
  signature: string | null;
  trustSource: string | null;
  trustList: string | null;
  channel: string | null;
}

export interface GateAuthenticity {
  /** The mode the gate derived (`anchorMode.id`) — one legible answer. */
  mode: "review-gated-pins" | "signed-root" | "unverified";
  /** Which validator validated (`anchorMode.mechanism`). */
  mechanism: "review-gated-pins" | "signed-root" | "none";
  /** `anchorMode.label`. */
  label: string;
  /** Did THIS run's mode demand a signature? */
  required: boolean;
  /** Did the anchor mode report a signed root? */
  signed: boolean;
  /** What the signed-root verifier found. */
  status: SignedRootStatus;
  verified: boolean;
  trustSource: string | null;
  signer: string | null;
  namespace: string | null;
  detail: string;
  channels: GateAuthenticityChannel[];
}

export declare function evaluateGate(
  /** `null` is accepted and FAILS CLOSED (clause 1: matrix-present). */
  matrix: Record<string, unknown> | FlashMatrix | null,
  options?: {
    allowedProducts?: string[];
    /** Probe a different tree (drills + tests). Defaults to INSTALLER_ROOT. */
    installerRoot?: string;
    /** Where `<product>-latest` pointers live. Defaults to the repo releases dir. */
    releasesDir?: string;
    /** Parsed anchor pins (trust-anchor clause injection point). */
    pins?: unknown;
    /** Path to docs/expected-anchors.json. */
    anchorsPath?: string;
    /** Parsed per-device shape pins (channel-shape clause injection point). */
    shapePins?: unknown;
    /** Path to docs/expected-shape.json. */
    shapePath?: string;
    /**
     * A VERIFIED signed-root result, if a verifier produced one. The gate
     * computes this itself from `scripts/channel-signature.mjs`; the option
     * remains as an injection point for drills.
     */
    signatureVerification?: SignedRootVerification;
    /** Does this mode DEMAND a signed channel root? (`--require-signed-root`.) */
    requireSignedRoot?: boolean;
    /** Explicit `allowed_signers` trust list; defaults to docs/expected-allowed-signers. */
    allowedSignersPath?: string | null;
    /** Injected ssh-keygen runner (tests simulate a missing verifier). */
    signatureRun?: typeof defaultVerifyRunner;
  },
): GateResult;

export declare function runGate(argv: string[]): number;

export declare const DEFAULT_MATRIX: string;
export declare const STATUS_PATH: string;
export declare const DEFAULT_RELEASES_DIR: string;
export { buildMatrix } from "./gen-flash-matrix.mjs";
export type { FlashMatrix };
