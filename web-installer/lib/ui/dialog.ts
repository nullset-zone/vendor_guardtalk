/**
 * Modal dialog helper. Focus is trapped inside while open; Escape cancels by
 * rejecting-style resolution of the awaiter (the pattern proven in
 * wizard/main.ts reconnect F2 fix); confirm resolves with the caller's value.
 */
export interface DialogOptions<T> {
  /** Accessible name source inside the dialog body. */
  readonly labelledBy: string;
  /**
   * Populates the dialog element. Must wire its own controls and call
   * helpers.confirm(value) for the affirmative action and helpers.cancel()
   * for every dismissive path.
   */
  readonly build: (host: HTMLDialogElement, helpers: DialogHelpers<T>) => void;
}

export interface DialogHelpers<T> {
  readonly confirm: (value: T) => void;
  readonly cancel: () => void;
}

export type DialogResult<T> = { readonly cancelled: false; readonly value: T } | { readonly cancelled: true };

const FOCUSABLE_SELECTOR =
  'a[href], area[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])';

export function openDialog<T>(
  options: DialogOptions<T>,
  doc: Document = document,
): Promise<DialogResult<T>> {
  if (typeof doc.createElement !== "function" || typeof HTMLDialogElement === "undefined") {
    return Promise.reject(new Error("openDialog requires a DOM with <dialog> support"));
  }
  let resolveResult: (result: DialogResult<T>) => void = () => undefined;
  const result = new Promise<DialogResult<T>>((resolve) => {
    resolveResult = resolve;
  });
  let settled = false;

  const dialog = doc.createElement("dialog");
  dialog.className = "modal-dialog";
  dialog.setAttribute("aria-labelledby", options.labelledBy);

  const restoreFocusTo: HTMLElement | null =
    doc.activeElement instanceof HTMLElement ? doc.activeElement : null;

  function focusables(): HTMLElement[] {
    return [...dialog.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)];
  }

  function onKeydown(event: KeyboardEvent): void {
    if (event.key === "Escape") {
      // Esc = cancel: resolves the awaiter as cancelled, never silently.
      event.preventDefault();
      helpers.cancel();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }
    const items = focusables();
    if (items.length === 0) {
      event.preventDefault();
      return;
    }
    const first = items[0];
    const last = items[items.length - 1];
    const active = doc.activeElement;
    if (event.shiftKey && active === first) {
      event.preventDefault();
      last?.focus();
    } else if (!event.shiftKey && active === last) {
      event.preventDefault();
      first?.focus();
    }
  }

  function onFocusIn(event: FocusEvent): void {
    const target = event.target;
    if (!(target instanceof Node) || !dialog.contains(target)) {
      focusables()[0]?.focus();
    }
  }

  const helpers: DialogHelpers<T> = {
    confirm: (value) => settle({ cancelled: false, value }),
    cancel: () => settle({ cancelled: true }),
  };

  function settle(value: DialogResult<T>): void {
    if (settled) {
      return;
    }
    settled = true;
    dialog.removeEventListener("keydown", onKeydown);
    dialog.removeEventListener("focusin", onFocusIn);
    if (dialog.open) {
      dialog.close();
    }
    dialog.remove();
    restoreFocusTo?.focus();
    resolveResult(value);
  }

  dialog.addEventListener("cancel", (event) => {
    // Native Esc/route-cancel funnels through the same cancelled resolution.
    event.preventDefault();
    helpers.cancel();
  });
  dialog.addEventListener("close", () => {
    // Any other close route counts as a cancellation.
    helpers.cancel();
  });

  dialog.addEventListener("keydown", onKeydown);
  dialog.addEventListener("focusin", onFocusIn);
  options.build(dialog, helpers);
  doc.body.append(dialog);
  dialog.showModal();
  focusables()[0]?.focus();

  return result;
}
