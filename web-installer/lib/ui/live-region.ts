/**
 * Live-region primitives (F-WEBINSTALL-FLASHALL-PROD-UI, D-017).
 *
 * Every STOP / tripwire / gate announcement the installer emits must reach a
 * screen reader *without waiting for focus*. Relying on the implicit mapping
 * from `role="alert"` alone is fragile: the mapping is a browser convention,
 * not a contract we can assert in a headless test. These helpers make the
 * announcement explicit and machine-checkable:
 *
 *   role="alert" aria-live="assertive" aria-atomic="true"
 *
 * `role="alert"` is kept (it is the semantic landmark assistive tech keys on);
 * `aria-live="assertive"` + `aria-atomic="true"` are added so the whole message
 * is read as one unit, and so a structural test can prove the contract holds
 * for every announcement site.
 *
 * Politeness: a hard STOP is `assertive` (it interrupts — the user must not
 * continue with a wrong image). A progress/status line is `polite`. `off` is
 * available for a region that is deliberately silent but still marked.
 *
 * No inline handlers, no inline style, no network — CSP `default-src 'none'`
 * (D-006) is respected by construction.
 */
import { escapeHtml } from "./escape.js";

export type LivePoliteness = "assertive" | "polite" | "off";

/** The attributes every announcing region carries. Exported so callers and
 *  tests agree on the exact contract rather than re-typing a string. */
export interface LiveRegionAttributes {
  readonly role: "alert" | "status";
  readonly "aria-live": LivePoliteness;
  readonly "aria-atomic": "true";
}

/**
 * Attribute bag for an announcing region. `status`/`polite` is the calm
 * status channel; `alert`/`assertive` is the interrupting channel. Assembly
 * forces `assertive ⇔ alert` and `polite/off ⇔ status` so the two axes cannot
 * drift apart into an incoherent pair (an `alert` that never interrupts, or a
 * `status` that does).
 */
export function liveRegionAttributes(politeness: LivePoliteness, title = ""): string {
  const role = politeness === "assertive" ? "alert" : "status";
  void title;
  return [
    `role="${role}"`,
    `aria-live="${politeness}"`,
    `aria-atomic="true"`,
  ].join(" ");
}

/**
 * Announcement wrapper. `labelHtml` is rendered *inside* the live region so its
 * text is what gets announced; it must already be escaped by the caller (it is
 * the caller's own markup). `id` is required for assertive announcements (a
 * stable, addressable region) and optional otherwise.
 */
export function liveRegionHtml(
  politeness: LivePoliteness,
  labelHtml: string,
  options: { readonly id?: string; readonly className?: string } = {},
): string {
  if (politeness === "assertive" && (options.id === undefined || options.id.length === 0)) {
    throw new Error("assertive live region requires a stable id");
  }
  const idAttr = options.id === undefined ? "" : ` id="${escapeHtml(options.id)}"`;
  const classAttr = options.className === undefined ? "" : ` class="${escapeHtml(options.className)}"`;
  return [
    `<div${idAttr}${classAttr} ${liveRegionAttributes(politeness)}>`,
    labelHtml,
    `</div>`,
  ].join("");
}

/**
 * The canonical hard-STOP announcement: an assertive, atomic region whose
 * first child is the verbatim reason (never a paraphrase) and whose visible
 * `STOPPED` marker precedes it. The reason string is escaped here.
 */
export function stopAnnouncementHtml(
  reason: string,
  options: { readonly id?: string; readonly prefix?: string } = {},
): string {
  const id = options.id ?? "stop-announcement";
  const prefix = options.prefix ?? "STOPPED:";
  const body = [
    `<span class="tripwire-text mono">${escapeHtml(prefix)}</span> `,
    `<span class="stop-reason-verbatim">${escapeHtml(reason)}</span>`,
  ].join("");
  return liveRegionHtml("assertive", body, { id, className: "hard-stop-banner announce-stop" });
}

/**
 * A polite status region for a non-interrupting progress/status line, e.g.
 * "writing: boot". Marked atomic so partial updates are read as a whole.
 */
export function statusAnnouncementHtml(
  text: string,
  options: { readonly id?: string; readonly className?: string } = {},
): string {
  const idAttr = options.id === undefined ? "" : ` id="${escapeHtml(options.id)}"`;
  const classAttr =
    options.className === undefined ? "" : ` class="${escapeHtml(options.className)}"`;
  return [
    `<p${idAttr}${classAttr} ${liveRegionAttributes("polite")}>${escapeHtml(text)}</p>`,
  ].join("");
}

/**
 * Structural predicate used by the acceptance test: does this markup carry an
 * explicit, atomic live region that announces `assertive`?
 */
export function hasAssertiveLiveRegion(html: string): boolean {
  return /role="alert"[^>]*aria-live="assertive"/.test(html) && /aria-atomic="true"/.test(html);
}

/** Every live region in a markup string, as its matched opening tag. */
export function liveRegionTags(html: string): readonly string[] {
  return [...html.matchAll(/<[\w-]+[^>]*aria-live="[^"]*"[^>]*>/g)].map((match) => match[0]);
}
