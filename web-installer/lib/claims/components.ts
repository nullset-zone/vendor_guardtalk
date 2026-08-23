/**
 * Claims components (PLAN.md §5, QUESTIONS Q-12): Hardening sentences carry
 * the mechanism that backs them; every ProtectionLimit links to the threat
 * model; LineageNote ships draft attribution wording carrying the
 * `// confirm with counsel` marker. Copy uses protective verbs only.
 */
import { escapeHtml } from "../ui/escape.js";

export const THREAT_MODEL_HREF = "/threat-model" as const;

/** Default mechanism link target for hardening sentences (`// confirm`). */
export const MECHANISM_DEFAULT_HREF = "/install#verify-release" as const;

export interface LinkOptions {
  readonly href?: string;
  readonly label?: string;
}

export interface RenderedClaim {
  readonly html: string;
  readonly text: string;
}

function linkHtml(href: string, label: string): string {
  return `<a href="${escapeHtml(href)}">${escapeHtml(label)}</a>`;
}

/**
 * Hardening sentence: what the installer enforces, with the mechanism named.
 * The optional link points at the enforcing step; when omitted the default
 * verify anchor is used and marked `// confirm`.
 */
export function Hardening(text: string, mechanismLink?: LinkOptions): RenderedClaim {
  if (text.trim().length === 0) {
    throw new Error("Hardening requires a sentence");
  }
  const href = mechanismLink?.href ?? MECHANISM_DEFAULT_HREF;
  const label = mechanismLink?.label ?? "See the verification step";
  const html = [
    `<p class="claim claim-hardening">`,
    escapeHtml(text),
    ` (${linkHtml(href, label)})`,
    `</p>`,
  ].join("");
  return { html, text };
}

/**
 * Protection limit: states plainly what verified boot does not cover,
 * always linked to /threat-model. Never softened.
 */
export function ProtectionLimit(text: string, threatModelLink?: LinkOptions): RenderedClaim {
  if (text.trim().length === 0) {
    throw new Error("ProtectionLimit requires a sentence");
  }
  const href = threatModelLink?.href ?? THREAT_MODEL_HREF;
  const label = threatModelLink?.label ?? "Read the threat model";
  const html = [
    `<p class="claim claim-limit">`,
    escapeHtml(text),
    ` (${linkHtml(href, label)})`,
    `</p>`,
  ].join("");
  return { html, text };
}

/**
 * Attribution note crediting upstream practice (Q-12). Ships draft wording
 * with the binding marker `// confirm with counsel` — rendered visibly so
 * the marker survives into review builds.
 */
export function LineageNote(draftText: string): RenderedClaim {
  if (draftText.trim().length === 0) {
    throw new Error("LineageNote requires draft wording");
  }
  const html = [
    `<p class="claim claim-lineage" data-confirm="with counsel">`,
    escapeHtml(draftText),
    `<span class="confirm-marker">// confirm with counsel</span>`,
    `</p>`,
  ].join("");
  return { html, text: `${draftText} // confirm with counsel` };
}
