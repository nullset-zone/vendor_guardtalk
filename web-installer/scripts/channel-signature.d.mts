/**
 * Type declarations for the signed channel root
 * (T-WEBINSTALL-SIGNED-CHANNEL-ROOT).
 *
 * The scheme is the packer's (`ssh-keygen -Y verify`, principal
 * `guardtalk-channel`, namespace `factory images`, payload = `<sig>` minus
 * `.sig`); the addition is that the payload is a canonical statement binding
 * `manifest.json` + `SHA256SUMS`, re-derived from the bytes on disk.
 */

/** Status a single channel's signed-root check can report. */
export type SignedRootStatus = "verified" | "absent" | "invalid" | "untrusted" | "unavailable";

/** One channel's verdict. */
export interface ChannelSignatureResult {
  product: string;
  status: SignedRootStatus;
  verified: boolean;
  detail: string;
  /** Absolute path of `channel-root.txt` (or where it was expected). */
  statement: string | null;
  /** Absolute path of `channel-root.txt.sig` (or where it was expected). */
  signature: string | null;
  /** Where the trust list came from: `explicit` / `out-of-band` / `channel-local`. */
  trustSource: string | null;
  trustList: string | null;
  signer: string | null;
  namespace: string | null;
  /** The channel token the signed statement declares. */
  channel: string | null;
  /** Digests recomputed from the channel dir (never from the statement). */
  digests: Record<string, string>;
}

/** Aggregate verdict over every packed channel. */
export interface ChannelSignaturesResult {
  status: SignedRootStatus;
  verified: boolean;
  /** Did the caller's mode REQUIRE a signature? */
  required: boolean;
  /** `signed-root` ONLY when every packed channel verified; else `none`. */
  mechanism: "signed-root" | "none";
  /** The evidence object `deriveAnchorMode` accepts (a verifier produced it). */
  verification: { mechanism: "signed-root"; verified: boolean; channel?: string | null };
  anyMaterial: boolean;
  trustSource: string | null;
  signer: string | null;
  namespace: string | null;
  detail: string;
  channels: ChannelSignatureResult[];
}

export declare const SIGNED_ROOT_SCHEMA: string;
export declare const ROOT_STATEMENT_FILE: string;
export declare const ROOT_SIGNATURE_FILE: string;
export declare const SIGNATURE_NAMESPACE: string;
export declare const TRUSTED_PRINCIPAL: string;
export declare const ALLOWED_SIGNERS_FILE: string;
export declare const ROOT_BOUND_FILES: readonly string[];
export declare const SIGNATURE_TIMEOUT_MS: number;
export declare const SIGNATURE_STATUS: {
  readonly verified: "verified";
  readonly absent: "absent";
  readonly invalid: "invalid";
  readonly untrusted: "untrusted";
  readonly unavailable: "unavailable";
};

export declare function buildRootStatement(input: {
  product: string;
  channel: string;
  digests: Record<string, string>;
}): string;

export declare function parseRootStatement(text: string): {
  ok: boolean;
  problem: string | null;
  product: string | null;
  channel: string | null;
  digests: Record<string, string>;
};

export declare function checkAllowedSigners(text: string): {
  ok: boolean;
  problem: string | null;
  principals: string[];
};

export declare function defaultVerifyRunner(
  args: string[],
  input: Buffer,
): { status: number | null; stdout: string; stderr: string; error: string | null };

export declare function verifyChannelSignature(input: {
  dir: string;
  product: string;
  installerRoot: string;
  allowedSignersPath?: string | null;
  run?: typeof defaultVerifyRunner;
}): ChannelSignatureResult;

export declare function verifyChannelSignatures(input: {
  channels: Map<string, { packed: boolean } | null | undefined>;
  channelsRoot: string;
  installerRoot: string;
  required?: boolean;
  allowedSignersPath?: string | null;
  run?: typeof defaultVerifyRunner;
}): ChannelSignaturesResult;
