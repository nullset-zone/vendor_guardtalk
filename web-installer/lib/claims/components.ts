/**
 * Claims components (PLAN.md §5, QUESTIONS Q-12): Hardening sentences carry
 * the mechanism that backs them; every ProtectionLimit links to the threat
 * model; LineageNote ships draft attribution wording carrying a visible
 * PENDING-COUNSEL-REVIEW marker.
 *
 * The marker is a REVIEW label, not a value waiting to be filled in. It used to
 * render as a pending-confirmation token, which shipped a placeholder into the
 * production page (F-WEBINSTALL-PLACEHOLDER-RETIREMENT, D-041); the label now
 * states the review state in words a reader can act on, and the
 * `data-confirm="with counsel"` attribute stays so the review tooling still
 * finds it.
 */
import { escapeHtml } from "../ui/escape.js";

export const THREAT_MODEL_HREF = "/threat-model" as const;

/** Default mechanism link target for hardening sentences. */
export const MECHANISM_DEFAULT_HREF = "/install#verify-release" as const;

/** The visible review state of draft attribution wording (Q-12). */
export const COUNSEL_REVIEW_MARKER = "PENDING COUNSEL REVIEW" as const;

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
 * verify anchor is used.
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
 * Attribution note crediting upstream practice (Q-12). Ships draft wording with
 * the visible review marker rendered so the review state survives into review
 * builds — as a label, never as a token a reader might treat as an instruction.
 */
export function LineageNote(draftText: string): RenderedClaim {
  if (draftText.trim().length === 0) {
    throw new Error("LineageNote requires draft wording");
  }
  const html = [
    `<p class="claim claim-lineage" data-confirm="with counsel">`,
    escapeHtml(draftText),
    `<span class="confirm-marker">${COUNSEL_REVIEW_MARKER}</span>`,
    `</p>`,
  ].join("");
  return { html, text: `${draftText} ${COUNSEL_REVIEW_MARKER}` };
}
