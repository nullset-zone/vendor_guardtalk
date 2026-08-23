/**
 * Side-by-side comparison renderer over lib/verify SideBySide models.
 * Two mono columns EXPECTED | ACTUAL with MATCH/MISMATCH word chips; long
 * hashes are middle-truncated and expand to the full value on click. The
 * verdict word is always present — never colour-only.
 */
import { truncateMiddle, type SideBySide } from "../verify/side-by-side.js";
import { makeChip } from "./chips.js";
import { escapeHtml } from "./escape.js";

export interface SideBySideRowOptions {
  /** Column width before middle truncation kicks in. */
  readonly cellWidth?: number;
  readonly label: string;
  readonly side: SideBySide;
}

export interface SideBySideRender {
  readonly html: string;
  readonly verdict: "MATCH" | "MISMATCH";
}

function cellHtml(value: string, cellWidth: number, id: string): string {
  const truncated = truncateMiddle(value, cellWidth);
  const needsExpand = truncated !== value;
  const parts = [
    `<span class="sbs-value mono" id="${id}"`,
    ` data-full="${escapeHtml(value)}"`,
    ` data-truncated="${escapeHtml(truncated)}"`,
    needsExpand ? ` role="button" tabindex="0" aria-expanded="false" title="Click to show the full value"` : ``,
    `>${escapeHtml(truncated)}</span>`,
  ];
  return parts.join("");
}

export function renderSideBySideRow(options: SideBySideRowOptions): SideBySideRender {
  const cellWidth = options.cellWidth ?? 32;
  const verdict = options.side.match ? "MATCH" : "MISMATCH";
  const chip = makeChip(verdict, options.side.match ? "verified" : "tripwire");
  const idBase = `sbs-${verdict.toLowerCase()}`;
  const html = [
    `<div class="sbs-row" data-verdict="${verdict}">`,
    `<span class="sbs-label">${escapeHtml(options.label)}</span>`,
    chip,
    `<div class="sbs-columns mono">`,
    `<div class="sbs-col"><span class="sbs-col-head">EXPECTED</span>${cellHtml(options.side.expected, cellWidth, `${idBase}-expected`)}</div>`,
    `<div class="sbs-col"><span class="sbs-col-head">ACTUAL</span>${cellHtml(options.side.actual, cellWidth, `${idBase}-actual`)}</div>`,
    `</div>`,
    `</div>`,
  ].join("");
  return { html, verdict };
}

/**
 * Expands a truncated value cell to its full value (and back). Wires the
 * click-expand contract; keyboard activation included.
 */
export function wireSideBySideExpand(root: HTMLElement): void {
  function toggle(cell: HTMLElement): void {
    const full = cell.getAttribute("data-full");
    const truncated = cell.getAttribute("data-truncated");
    if (full === null || truncated === null) {
      return;
    }
    const expanded = cell.getAttribute("aria-expanded") === "true";
    cell.textContent = expanded ? truncated : full;
    cell.setAttribute("aria-expanded", expanded ? "false" : "true");
  }
  root.addEventListener("click", (event) => {
    const target = event.target;
    if (target instanceof HTMLElement && target.classList.contains("sbs-value")) {
      toggle(target);
    }
  });
  root.addEventListener("keydown", (event) => {
    const target = event.target;
    if (
      (event.key === "Enter" || event.key === " ") &&
      target instanceof HTMLElement &&
      target.classList.contains("sbs-value")
    ) {
      event.preventDefault();
      toggle(target);
    }
  });
}
