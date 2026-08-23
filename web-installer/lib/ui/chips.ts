/**
 * Status chips (PLAN.md §5): every chip carries its word — status is never
 * colour-only. Kinds map onto the token inventory inherited from
 * wizard/styles.css :root: signal green (--ok) ONLY for verified states,
 * caution amber (--warn) for alpha/pending, tripwire red (--danger) ONLY for
 * failures, neutral ink otherwise.
 */
import { escapeHtml } from "./escape.js";

export type ChipKind = "verified" | "caution" | "tripwire" | "neutral";

export interface ChipOptions {
  /** aria-live politeness; omit for static chips (no live region). */
  readonly ariaLive?: "off" | "polite" | "assertive";
}

const KIND_DATA_ATTR: Readonly<Record<ChipKind, string>> = {
  verified: "chip-verified",
  caution: "chip-caution",
  tripwire: "chip-tripwire",
  neutral: "chip-neutral",
};

/** Signal green is reserved for verified states; tripwire never decorates. */
export function makeChip(word: string, kind: ChipKind, options: ChipOptions = {}): string {
  const text = word.trim();
  if (text.length === 0) {
    throw new Error("chip word is mandatory — status must never be colour-only");
  }
  const attrs = [`class="chip ${KIND_DATA_ATTR[kind]}"`, `data-kind="${kind}"`];
  if (options.ariaLive !== undefined) {
    attrs.push(`aria-live="${options.ariaLive}"`);
  }
  return `<span ${attrs.join(" ")}>${escapeHtml(text)}</span>`;
}
