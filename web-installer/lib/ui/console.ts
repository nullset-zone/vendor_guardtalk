/**
 * Mono console component (PLAN.md §1 step 6): verbatim command/response log.
 * Every line is selectable with per-line copy-on-click plus copy-all; a
 * 2000-line ring buffer drops the oldest lines; an aria-live=polite region
 * mirrors the last line only; scrolling sticks to the bottom unless the user
 * scrolled up. Clipboard access is guarded by a user gesture.
 */
import { escapeHtml } from "./escape.js";

export type ConsoleLineKind = "cmd" | "ok" | "info" | "fail" | "device";

export interface ConsoleLine {
  readonly kind: ConsoleLineKind;
  readonly text: string;
}

export const CONSOLE_BUFFER_LIMIT = 2000;

/** Scroll threshold (px) under which the view counts as "at the bottom". */
const STICK_THRESHOLD_PX = 24;

export interface ConsoleElement {
  readonly root: HTMLElement;
  readonly lines: readonly ConsoleLine[];
  appendLine(kind: ConsoleLineKind, text: string): void;
  appendLines(entries: readonly (readonly [ConsoleLineKind, string])[]): void;
  clear(): void;
  copyAll(): Promise<void>;
}

export function renderConsole(): ConsoleElement {
  if (typeof document === "undefined") {
    throw new Error("renderConsole requires a DOM document");
  }
  const lines: ConsoleLine[] = [];

  const root = document.createElement("section");
  root.className = "console";
  root.setAttribute("aria-label", "Installer console");

  const viewport = document.createElement("div");
  viewport.className = "console-viewport mono";
  viewport.setAttribute("role", "log");
  viewport.setAttribute("tabindex", "0");

  const mirror = document.createElement("p");
  mirror.className = "console-mirror";
  mirror.setAttribute("aria-live", "polite");
  mirror.setAttribute("data-mirror", "last-line");

  const copyAllButton = document.createElement("button");
  copyAllButton.type = "button";
  copyAllButton.className = "console-copy-all";
  copyAllButton.textContent = "Copy console output";

  root.append(viewport, mirror, copyAllButton);

  let stickToBottom = true;
  viewport.addEventListener("scroll", () => {
    const distance = viewport.scrollHeight - viewport.scrollTop - viewport.clientHeight;
    stickToBottom = distance <= STICK_THRESHOLD_PX;
  });

  function lineElement(line: ConsoleLine): HTMLElement {
    const row = document.createElement("div");
    row.className = `console-line console-${line.kind}`;
    row.setAttribute("data-kind", line.kind);
    row.textContent = line.text;
    row.title = "Click to copy this line";
    return row;
  }

  function trimToLimit(): void {
    while (lines.length > CONSOLE_BUFFER_LIMIT) {
      lines.shift();
      const first = viewport.firstElementChild;
      if (first !== null) {
        first.remove();
      }
    }
  }

  function appendOne(kind: ConsoleLineKind, text: string): void {
    const line: ConsoleLine = { kind, text };
    lines.push(line);
    const wasEmpty = viewport.childElementCount === 0;
    viewport.append(lineElement(line));
    trimToLimit();
    mirror.textContent = text;
    if (stickToBottom || wasEmpty) {
      viewport.scrollTop = viewport.scrollHeight;
    }
  }

  async function writeClipboard(text: string): Promise<void> {
    const clip = navigator.clipboard;
    if (clip === undefined) {
      throw new Error("Clipboard API is unavailable in this browser");
    }
    await clip.writeText(text);
  }

  function copyTextWithGestureGuard(text: string, gesture: boolean): Promise<void> {
    if (!gesture) {
      return Promise.reject(new Error("clipboard writes require a user gesture"));
    }
    return writeClipboard(text);
  }

  viewport.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }
    const row = target.closest<HTMLElement>(".console-line");
    if (row === null) {
      return;
    }
    void copyTextWithGestureGuard(row.textContent ?? "", event.isTrusted).catch(() => {
      const rejection = new Error("clipboard write was blocked (gesture or permission)");
      root.dispatchEvent(new CustomEvent("console-copy-error", { detail: rejection }));
    });
  });

  copyAllButton.addEventListener("click", (event) => {
    void copyTextWithGestureGuard(lines.map((line) => line.text).join("\n"), event.isTrusted).catch(() => {
      const rejection = new Error("clipboard write was blocked (gesture or permission)");
      root.dispatchEvent(new CustomEvent("console-copy-error", { detail: rejection }));
    });
  });

  return {
    root,
    lines,
    appendLine(kind, text) {
      appendOne(kind, text);
    },
    appendLines(entries) {
      for (const [kind, text] of entries) {
        appendOne(kind, text);
      }
    },
    clear() {
      lines.length = 0;
      viewport.replaceChildren();
      mirror.textContent = "";
    },
    copyAll() {
      return copyTextWithGestureGuard(lines.map((line) => line.text).join("\n"), true);
    },
  };
}

/** Static markup variant (no wiring) for server-rendered or test contexts. */
export function consoleMarkup(lines: readonly (readonly [ConsoleLineKind, string])[]): string {
  const rows = lines
    .map(([kind, text]) => `<div class="console-line console-${kind}" data-kind="${kind}">${escapeHtml(text)}</div>`)
    .join("");
  return [
    `<section class="console" aria-label="Installer console">`,
    `<div class="console-viewport mono" role="log" tabindex="0"><div class="console-lines">${rows}</div></div>`,
    `<p class="console-mirror" aria-live="polite" data-mirror="last-line"></p>`,
    `<button type="button" class="console-copy-all">Copy console output</button>`,
    `</section>`,
  ].join("");
}
