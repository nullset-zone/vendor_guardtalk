/** Quota math from the loaded channel's actual artifact sizes (not a 1700 MiB guess). */
import { StorageQuotaError } from "../src/errors.js";

export const EXTRACT_SLACK_BYTES = 256 * 1024 * 1024;
export const PRIVATE_MODE_QUOTA_HINT_BYTES = 500 * 1024 * 1024;
/** Refuse buffering single artifacts larger than 512 MiB into JS heap; stream to OPFS instead. */
export const DEFAULT_MAX_IN_MEMORY_BYTES = 512 * 1024 * 1024;

export interface SizedFile {
  size: number;
}

export interface StorageEstimateInput {
  quota?: number;
  usage?: number;
}

export interface QuotaAssessment {
  payloadBytes: number;
  requiredBytes: number;
  quotaBytes: number | null;
  usageBytes: number | null;
  availableBytes: number | null;
  lowQuota: boolean;
  likelyPrivateMode: boolean;
  summary: string;
}

export function payloadBytes(files: readonly SizedFile[]): number {
  return files.reduce((sum, file) => sum + file.size, 0);
}

export function requiredQuotaBytes(files: readonly SizedFile[]): number {
  return payloadBytes(files) + EXTRACT_SLACK_BYTES;
}

export function formatMib(bytes: number): string {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
}

export function assessQuota(
  files: readonly SizedFile[],
  estimate: StorageEstimateInput | null,
  privateModeHint = false,
): QuotaAssessment {
  const payload = payloadBytes(files);
  const required = payload + EXTRACT_SLACK_BYTES;
  const quota = estimate?.quota;
  const usage = estimate?.usage;
  const quotaBytes = typeof quota === "number" && quota > 0 ? quota : null;
  const usageBytes = typeof usage === "number" && usage >= 0 ? usage : null;
  const availableBytes =
    quotaBytes !== null
      ? Math.max(0, quotaBytes - (usageBytes ?? 0))
      : null;
  const lowQuota = availableBytes !== null && availableBytes < required;
  const likelyPrivateMode =
    privateModeHint ||
    (quotaBytes !== null &&
      quotaBytes < PRIVATE_MODE_QUOTA_HINT_BYTES &&
      required > quotaBytes);
  const summary = buildSummary(payload, required, quotaBytes, availableBytes, lowQuota, likelyPrivateMode);
  return {
    payloadBytes: payload,
    requiredBytes: required,
    quotaBytes,
    usageBytes,
    availableBytes,
    lowQuota,
    likelyPrivateMode,
    summary,
  };
}

export function assertStorageQuotaForBytes(
  requiredBytes: number,
  estimate: StorageEstimateInput | null,
  label = "artifact",
): void {
  const quota = estimate?.quota;
  if (typeof quota !== "number" || quota <= 0) {
    return;
  }
  const usage = typeof estimate?.usage === "number" && estimate.usage >= 0 ? estimate.usage : 0;
  const available = Math.max(0, quota - usage);
  if (available < requiredBytes) {
    throw new StorageQuotaError(
      `Insufficient browser storage quota for ${label}: needs ${formatMib(requiredBytes)}, ` +
        `only ${formatMib(available)} available (quota ${formatMib(quota)}, used ${formatMib(usage)})`,
    );
  }
}

function buildSummary(
  payload: number,
  required: number,
  quotaBytes: number | null,
  availableBytes: number | null,
  lowQuota: boolean,
  likelyPrivateMode: boolean,
): string {
  const parts = [
    `This channel's artifacts are ${formatMib(payload)} on disk.`,
    `Origin storage should have about ${formatMib(required)} free (payload plus ${formatMib(EXTRACT_SLACK_BYTES)} slack).`,
  ];
  if (quotaBytes !== null) {
    parts.push(`This browser reports a quota of ${formatMib(quotaBytes)}.`);
    if (availableBytes !== null && availableBytes < quotaBytes) {
      parts.push(`Available origin storage is ${formatMib(availableBytes)}.`);
    }
  } else {
    parts.push("This browser did not report a usable storage quota.");
  }
  if (lowQuota) {
    parts.push("Quota is below the actual artifact total. Stop and use a normal window with more disk.");
  }
  if (likelyPrivateMode) {
    parts.push("The quota looks like a private window. Incognito is not a supported path.");
  }
  return parts.join(" ");
}
