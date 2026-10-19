/**
 * Pajamas class-name helpers (DEC-WEBINSTALL-011).
 * Category × variant × size only — no hex, no inline style.
 */
import { escapeHtml } from "./escape.js";

export type ButtonCategory = "default" | "confirm" | "danger";
export type ButtonVariant = "primary" | "secondary" | "tertiary" | "dashed" | "link";
export type ButtonSize = "md" | "sm";
export type AlertKind = "info" | "success" | "warning" | "danger";

/** High-emphasis Next / continue (signal green fill). */
export const GL_BTN_CONFIRM =
  "btn-primary gl-button gl-button--confirm-primary";
/** Back / quiet actions. */
export const GL_BTN_DEFAULT =
  "btn-secondary gl-button gl-button--default-secondary";
/** Recover / wipe hard-stops. */
export const GL_BTN_DANGER = "cta danger gl-button gl-button--danger-primary";
/** Equal-choice cards. */
export const GL_BTN_DASHED =
  "btn-secondary gl-button gl-button--default-dashed";
/** Text-style navigation. */
export const GL_BTN_LINK = "gl-button gl-button--default-link";

export function glButtonClass(
  category: ButtonCategory,
  variant: ButtonVariant,
  size: ButtonSize = "md",
  extra = "",
): string {
  const sizeClass = size === "sm" ? " gl-button--sm" : "";
  const extraClass = extra === "" ? "" : ` ${extra}`;
  return `gl-button gl-button--${category}-${variant}${sizeClass}${extraClass}`;
}

export function glAlertHtml(
  kind: AlertKind,
  title: string,
  bodyHtml: string,
  extraClass = "",
): string {
  const extra = extraClass === "" ? "" : ` ${extraClass}`;
  const titleHtml =
    title === ""
      ? ""
      : `<div class="gl-alert__title">${escapeHtml(title)}</div>`;
  // D-017: keep the `role="alert"` semantic every existing site relies on and
  // STRENGTHEN it with an explicit, atomic live contract. A `danger` alert
  // interrupts (assertive); other kinds announce calmly (polite) but still as
  // one unit. Nothing about the existing markup is removed.
  const politeness = kind === "danger" ? "assertive" : "polite";
  return [
    `<div class="gl-alert gl-alert--${kind}${extra}" role="alert" aria-live="${politeness}" aria-atomic="true">`,
    `<div class="gl-alert__body">`,
    titleHtml,
    bodyHtml,
    `</div></div>`,
  ].join("");
}
