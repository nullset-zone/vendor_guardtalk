/**
 * Prove a vbmeta image is signed by the enrolled user key (pkmd), never by
 * the GuardTalk release key. This is the PLAN §2.5 / custom-public-key spine.
 */
import { verifyVbmetaAgainstKey } from "../avb/signer.js";

export interface UserAnchorProof {
  readonly ok: boolean;
  readonly reason?: string;
}

/**
 * Constant-time pkmd compare + signature verify against the embedded key.
 * `enrolledPkmd` is the same blob flashed to avb_custom_key.
 */
export async function proveVbmetaUserSigned(
  vbmetaBytes: Uint8Array,
  enrolledPkmd: Uint8Array,
): Promise<UserAnchorProof> {
  try {
    const result = await verifyVbmetaAgainstKey(vbmetaBytes, enrolledPkmd);
    if (result.ok) {
      return { ok: true };
    }
    return {
      ok: false,
      reason: result.failure ?? "vbmeta is not signed with your enrolled key",
    };
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : "vbmeta could not be parsed";
    return { ok: false, reason: message };
  }
}
