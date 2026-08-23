/**
 * Per-partition flash progress (PLAN.md §1 step 6): partition name + byte
 * progress in a mono label. This bar is the ONE allowed motion; every other
 * transition stays within the 180ms budget. Reduced motion is respected by
 * the stylesheet (`prefers-reduced-motion`) — bar jumps become instant there;
 * the label always states partition + bytes in words, never colour-only.
 */
import { escapeHtml } from "./escape.js";

export interface PartitionProgress {
  readonly partition: string;
  /** Bytes written so far. */
  readonly bytesDone: number;
  readonly bytesTotal: number;
}

/** Mono label contract: e.g. `flash bootloader — 1,024 of 4,096 bytes`. */
export function partitionProgressLabel(progress: PartitionProgress): string {
  return `flash ${progress.partition} — ${progress.bytesDone.toLocaleString("en-US")} of ${progress.bytesTotal.toLocaleString("en-US")} bytes`;
}

function clampPercent(done: number, total: number): number {
  if (!(total > 0)) {
    return done >= 0 ? 100 : 0;
  }
  return Math.min(100, Math.max(0, (done / total) * 100));
}

export function renderPartitionProgress(progress: PartitionProgress): string {
  if (progress.bytesTotal < 0 || progress.bytesDone < 0) {
    throw new Error("byte counts must be non-negative");
  }
  const percent = clampPercent(progress.bytesDone, progress.bytesTotal);
  const label = partitionProgressLabel(progress);
  return [
    `<div class="partition-progress" role="progressbar"`,
    ` aria-valuemin="0" aria-valuemax="100" aria-valuenow="${percent.toFixed(1)}"`,
    ` aria-label="${escapeHtml(label)}">`,
    `<span class="partition-progress-label mono">${escapeHtml(label)}</span>`,
    `<span class="partition-progress-track"><span class="partition-progress-fill" data-width-pct="${percent.toFixed(2)}"></span></span>`,
    `</div>`,
  ].join("");
}

/**
 * Wired component. Width updates go through the style PROPERTY at runtime
 * (never an inline style= attribute in markup), so everything these modules
 * emit works under the installer CSP (script-src 'self', no unsafe-inline).
 */
export interface PartitionProgressElement {
  readonly root: HTMLElement;
  update(next: PartitionProgress): void;
}

export function wirePartitionProgress(root: HTMLElement, initial: PartitionProgress): PartitionProgressElement {
  const label = root.querySelector<HTMLElement>(".partition-progress-label");
  const fill = root.querySelector<HTMLElement>(".partition-progress-fill");
  function apply(progress: PartitionProgress): void {
    if (progress.bytesTotal < 0 || progress.bytesDone < 0) {
      throw new Error("byte counts must be non-negative");
    }
    const percent = clampPercent(progress.bytesDone, progress.bytesTotal);
    const text = partitionProgressLabel(progress);
    if (label !== null) {
      label.textContent = text;
    }
    if (fill !== null) {
      fill.dataset.widthPct = percent.toFixed(2);
      fill.style.width = `${percent.toFixed(2)}%`;
    }
    root.setAttribute("aria-valuenow", percent.toFixed(1));
    root.setAttribute("aria-label", text);
  }
  apply(initial);
  return {
    root,
    update(next) {
      apply(next);
    },
  };
}
