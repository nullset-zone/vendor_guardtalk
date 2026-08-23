/** Quota math from the loaded channel's actual artifact sizes (not a 1700 MiB guess). */

export const EXTRACT_SLACK_BYTES = 256 * 1024 * 1024;
export const PRIVATE_MODE_QUOTA_HINT_BYTES = 500 * 1024 * 1024;

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
  const usageBytes = typeof usage === "number" ? usage : null;
  const lowQuota = quotaBytes !== null && quotaBytes < required;
  const likelyPrivateMode =
    privateModeHint ||
    (quotaBytes !== null &&
      quotaBytes < PRIVATE_MODE_QUOTA_HINT_BYTES &&
      required > quotaBytes);
  const summary = buildSummary(payload, required, quotaBytes, lowQuota, likelyPrivateMode);
  return {
    payloadBytes: payload,
    requiredBytes: required,
    quotaBytes,
    usageBytes,
    lowQuota,
    likelyPrivateMode,
    summary,
  };
}

function buildSummary(
  payload: number,
  required: number,
  quotaBytes: number | null,
  lowQuota: boolean,
  likelyPrivateMode: boolean,
): string {
  const parts = [
    `This channel's artifacts are ${formatMib(payload)} on disk.`,
    `Origin storage should have about ${formatMib(required)} free (payload plus ${formatMib(EXTRACT_SLACK_BYTES)} slack).`,
  ];
  if (quotaBytes !== null) {
    parts.push(`This browser reports a quota of ${formatMib(quotaBytes)}.`);
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
