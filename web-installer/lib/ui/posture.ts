/**
 * Posture pill (PLAN.md §5): exact text `◢ offline · your key · alpha`.
 * Connectivity and custody are invariants of this installer (D-006, D-007),
 * so the renderer refuses status payloads that contradict them; only the
 * release-state word comes from status.json.
 */
import { escapeHtml } from "./escape.js";

export interface PostureFlags {
  readonly connectivity: string;
  readonly custody: string;
  readonly releaseState: string;
}

export const POSTURE_CONNECTIVITY = "offline" as const;
export const POSTURE_CUSTODY = "your key" as const;

export function posturePillText(flags: PostureFlags): string {
  return `◢ ${flags.connectivity} · ${flags.custody} · ${flags.releaseState}`;
}

export function renderPosturePill(flags: PostureFlags): string {
  const text = posturePillText(flags);
  return [
    `<span class="pill pill-posture"`,
    ` data-connectivity="${escapeHtml(flags.connectivity)}"`,
    ` data-custody="${escapeHtml(flags.custody)}"`,
    ` data-release-state="${escapeHtml(flags.releaseState)}">`,
    escapeHtml(text),
    `</span>`,
  ].join("");
}

interface StatusJsonFields {
  release_state?: unknown;
  installer?: unknown;
  network?: unknown;
  key_custody?: unknown;
}

/**
 * Reads the deployed status.json payload. Accepts `release_state`, with
 * `installer` as the alias used in PLAN.md §0 ("installer: alpha").
 */
export function postureFromStatusJson(value: unknown): PostureFlags {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("status.json payload must be an object");
  }
  const fields = value as StatusJsonFields;
  const releaseRaw = fields.release_state ?? fields.installer;
  if (typeof releaseRaw !== "string" || releaseRaw.trim().length === 0) {
    throw new Error("status.json is missing release_state (or the installer alias)");
  }
  if (fields.network !== undefined && fields.network !== POSTURE_CONNECTIVITY) {
    throw new Error(`status.json network must be "${POSTURE_CONNECTIVITY}" — this installer has zero runtime network`);
  }
  if (fields.key_custody !== undefined && fields.key_custody !== "alpha" && fields.key_custody !== POSTURE_CUSTODY) {
    throw new Error(`status.json key_custody "${String(fields.key_custody)}" contradicts single-user key custody`);
  }
  return {
    connectivity: POSTURE_CONNECTIVITY,
    custody: POSTURE_CUSTODY,
    releaseState: releaseRaw.trim(),
  };
}
