/** Single source of truth for every stop reason string. Import everywhere. */

export const STOP_REASONS = {
  HASH_MISMATCH: "hash mismatch — the download does not match SHA256SUMS",
  SIGNATURE_INVALID: "signature does not verify against the release key fingerprint",
  FINGERPRINT_RETYPE_WRONG: "fingerprint retype is wrong — retry allowed, never skipped",
  PARTITION_LAYOUT_UNKNOWN: "chain descriptor present but partition layout unknown",
  PRODUCT_MISMATCH: "device product does not match this release target",
  FASTBOOT_FAIL: "fastboot reported FAIL — flow stopped, verbatim output shown above",
  BOOT_FINGERPRINT_MISMATCH:
    "boot-screen fingerprint does not match your enrolled key — do not use this device; it is not running what you signed",
  OUT_OF_ORDER: "that action does not belong to the current step",
  UNKNOWN_ACTION: "unknown action for this installer state",
  ROUTE_STEP_FORBIDDEN: "this step is not part of the selected route",
  KEY_FLOW_FORBIDDEN: "this key flow is not offered on this route",
  BACK_PAST_IRREVERSIBLE: "back is not available after an irreversible acknowledgement",
  OEM_UNLOCK_ACK_REQUIRED:
    "the data-wipe warning must be acknowledged before the device step can complete",
  FLASH_GATE_NOT_SATISFIED:
    "flash requires release verification, device match, and a user-signed vbmeta",
  MAX_DOWNLOAD_SIZE_UNAVAILABLE:
    "device did not report a usable max-download-size — flow stopped before any transfer",
  USER_ANCHOR_MISMATCH:
    "vbmeta is not signed with your enrolled key — flash refused",
} as const;

export type StopReasonId = keyof typeof STOP_REASONS;

export function stopReason(id: StopReasonId): string {
  return STOP_REASONS[id];
}
