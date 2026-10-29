/**
 * Real-transport states for the /install route (F-WEBINSTALL-LIVE-TRANSPORT-UX).
 *
 * `T-WEBINSTALL-WEBUSB-TRANSPORT-BUNDLE` landed a real, pinned transport
 * (`android-fastboot`) behind the existing `FastbootTransport` interface, and
 * `test/transport-live-gate.test.ts` proves `executePlan`/`lock` stay HOLD while
 * `LIVE_FLASH_CLAIMED` is false. What was missing is the UI half: before this
 * module the only related notice was the absent-WebUSB sentence in
 * `routes/install/install-app.ts`, and every other transport state surfaced as a
 * raw error string in a `role="status"` paragraph — or not at all.
 *
 * This module is the ONE place that names, words and announces the five states
 * the real transport can be in:
 *
 *   1. `pairing-refused`   — the user cancelled the picker, or the browser
 *                            refused WebUSB access to the device.
 *   2. `device-disconnected` — the phone stopped answering mid-flow (e.g.
 *                            during a firmware write).
 *   3. `product-mismatch`  — `getvar product` does not match the channel.
 *   4. `webusb-absent`     — no WebUSB (non-Chromium, or not an HTTPS origin).
 *   5. `live-not-enabled`  — `LIVE_FLASH_CLAIMED` is false, so the live
 *                            execute/lock path is HOLD (`LiveExecuteHoldError`).
 *
 * Honesty contract (D-048):
 *   - every state is VISIBLE (`data-transport-state`, a chip that carries its
 *     word) and ANNOUNCED (the shared `lib/ui/live-region.ts` wrapper — one
 *     mechanism, never a second);
 *   - no state's copy asserts, implies or celebrates a completed flash;
 *   - every state is a STOP for the flow: `data-advance="none"` is emitted and
 *     no caller dispatches an advance after setting one;
 *   - `live-not-enabled` is worded as a BUILD POSTURE ("not enabled in this
 *     build"), never as a device error and never as a result.
 *
 * No CSS is added here: the markup reuses `hard-stop-banner` / `mono` /
 * `tripwire-text` and the `gl-*` chip classes, so the focus-ring and contrast
 * floors are untouched by construction.
 */
import { LiveExecuteHoldError } from "../../src/errors.js";
import { STOP_REASONS } from "../install-state/stops.js";
import { makeChip, type ChipKind } from "./chips.js";
import { escapeHtml } from "./escape.js";
import { liveRegionHtml, type LivePoliteness } from "./live-region.js";

/** Stable id of the one announcing region for a transport state. */
export const LIVE_TRANSPORT_REGION_ID = "live-transport-state";

/**
 * The absent-WebUSB sentence, kept verbatim and made first-class: it is the
 * state's headline, so the existing copy no longer lives alone in the route.
 */
export const WEBUSB_ABSENT_NOTICE = "WebUSB is not available. Use the CLI export path.";

/** Why a pairing attempt ended without a claimed device. */
export type PairingRefusalCause = "cancelled" | "denied";

/** The five states. `action` only disambiguates the wording of state 5. */
export type LiveTransportState =
  | { readonly kind: "pairing-refused"; readonly cause: PairingRefusalCause }
  | { readonly kind: "device-disconnected"; readonly detail: string }
  | { readonly kind: "product-mismatch"; readonly expected: string; readonly actual: string }
  | { readonly kind: "webusb-absent" }
  | { readonly kind: "live-not-enabled"; readonly action: "execute" | "lock" };

export type LiveTransportStateKind = LiveTransportState["kind"];

export interface LiveTransportCopy {
  readonly kind: LiveTransportStateKind;
  readonly chipWord: string;
  readonly chipKind: ChipKind;
  readonly title: string;
  readonly headline: string;
  /** Verbatim transport detail (never paraphrased). */
  readonly detail?: string;
  /** What the state does NOT mean — the anti-inference sentence. */
  readonly note?: string;
  readonly remedy: string;
  readonly politeness: LivePoliteness;
  /** Literal `false`: none of these states advances the flow (AC (c)). */
  readonly advances: false;
}

/**
 * The wording for each state. Exported as a function over the state so the
 * copy is derived from the ONE discriminator, never from a second flag.
 */
export function liveTransportCopy(state: LiveTransportState): LiveTransportCopy {
  switch (state.kind) {
    case "pairing-refused":
      if (state.cause === "denied") {
        return {
          kind: state.kind,
          chipWord: "USB ACCESS REFUSED",
          chipKind: "caution",
          title: "WebUSB access was refused",
          headline:
            "The browser denied this page access to the USB device, so the installer could not open it and wrote nothing.",
          note: "A refusal in the browser is not a refusal by the phone.",
          remedy:
            "Allow USB access for this site in the browser's site settings, return the phone to bootloader mode, then pair again. The command-line export at step 3 needs no browser permission.",
          politeness: "polite",
          advances: false,
        };
      }
      return {
        kind: state.kind,
        chipWord: "NO DEVICE SELECTED",
        chipKind: "caution",
        title: "No device was selected",
        headline:
          "The browser's USB picker closed without a device, so the installer opened nothing and wrote nothing.",
        note: "Nothing on the phone changed. This step waits for a device that answers.",
        remedy:
          "Run the pairing step again and choose the phone in the browser's USB list, or use the command-line export at step 3.",
        politeness: "polite",
        advances: false,
      };
    case "device-disconnected":
      return {
        kind: state.kind,
        chipWord: "DEVICE DISCONNECTED",
        chipKind: "tripwire",
        title: "The device disconnected",
        headline:
          "The phone stopped answering on USB, so this page halted and sent no further commands.",
        detail: state.detail,
        note: "Any partition written before the disconnect stays written; this plan did not finish.",
        remedy:
          "Reconnect the phone in bootloader mode and run the write again from this step. Do not lock the bootloader, and do not trust the phone until every partition has been written and the fingerprint check at step 8 has passed.",
        politeness: "assertive",
        advances: false,
      };
    case "product-mismatch":
      return {
        kind: state.kind,
        chipWord: "PRODUCT MISMATCH",
        chipKind: "tripwire",
        title: "This phone is not the channel's target",
        headline: STOP_REASONS.PRODUCT_MISMATCH,
        detail: `expected: ${state.expected} · device reports: ${state.actual}`,
        note: "No write was sent: the product check runs before the first flash command.",
        remedy:
          "Pick the channel that matches the phone, or connect the phone this channel was built for. This page will not write to a device it cannot identify.",
        politeness: "assertive",
        advances: false,
      };
    case "webusb-absent":
      return {
        kind: state.kind,
        chipWord: "NO WEBUSB",
        chipKind: "caution",
        title: "This browser cannot pair over USB",
        headline: WEBUSB_ABSENT_NOTICE,
        note: "This browser exposes no WebUSB here, or this page is not served from an HTTPS origin. Nothing was opened and nothing was written.",
        remedy:
          "The command-line export at step 3 performs the same operations in the same order. It is a first-class path, not a fallback, and it needs no browser permission.",
        politeness: "polite",
        advances: false,
      };
    case "live-not-enabled": {
      const what = state.action === "lock" ? "a lock command" : "a write";
      return {
        kind: state.kind,
        chipWord: "LIVE FLASH NOT ENABLED",
        chipKind: "caution",
        title: "Live flashing is not enabled in this build",
        headline: `Live flashing is not enabled in this build: LIVE_FLASH_CLAIMED is false, so this page stopped instead of sending ${what}.`,
        note: "This is a build posture, not a device fault. The refusal is the same whichever phone is connected.",
        remedy:
          "Use the command-line export at step 3 to run the same commands with fastboot. No action on this page writes to or locks a phone in this build.",
        politeness: "assertive",
        advances: false,
      };
    }
  }
}

/**
 * The rendered state: one announcing region (shared wrapper), the state's own
 * chip word, and the machine-checkable markers a test can bite on.
 */
export function renderLiveTransportState(state: LiveTransportState): string {
  const copy = liveTransportCopy(state);
  const body: string[] = [
    makeChip(copy.chipWord, copy.chipKind),
    `<p class="live-transport__title"><strong>${escapeHtml(copy.title)}</strong></p>`,
    `<p class="live-transport__headline">${escapeHtml(copy.headline)}</p>`,
  ];
  if (copy.detail !== undefined) {
    body.push(`<p class="live-transport__detail mono">${escapeHtml(copy.detail)}</p>`);
  }
  if (copy.note !== undefined) {
    body.push(`<p class="live-transport__note">${escapeHtml(copy.note)}</p>`);
  }
  body.push(`<p class="live-transport__remedy">${escapeHtml(copy.remedy)}</p>`);

  const className =
    copy.politeness === "assertive"
      ? "live-transport-state hard-stop-banner announce-stop"
      : "live-transport-state";
  const causeAttr =
    state.kind === "pairing-refused" ? ` data-transport-cause="${escapeHtml(state.cause)}"` : "";
  return [
    `<div class="live-transport" data-transport-state="${escapeHtml(copy.kind)}"${causeAttr} data-advance="none">`,
    liveRegionHtml(copy.politeness, body.join(""), {
      id: LIVE_TRANSPORT_REGION_ID,
      className,
    }),
    `</div>`,
  ].join("");
}

/** Politeness of a state, so callers and tests agree without re-deriving it. */
export function liveTransportPoliteness(state: LiveTransportState): LivePoliteness {
  return liveTransportCopy(state).politeness;
}

/** True when the state must interrupt (a started operation was halted). */
export function isLiveTransportStop(state: LiveTransportState): boolean {
  return liveTransportPoliteness(state) === "assertive";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function messageOf(err: unknown): string {
  return err instanceof Error ? err.message : "";
}

/**
 * Map a thrown transport error onto a state, or `undefined` when the error is
 * outside this module's five states (the caller keeps its existing handling —
 * a bootloader `FAIL` is not a transport state and must not be relabelled).
 *
 * The `LiveExecuteHoldError` check is by CLASS *and* by its `code`, so the
 * DEC-009 HOLD is recognised even across a module-instance boundary where
 * `instanceof` would not hold. There is no second copy of the code string: it
 * is read from the error the backend lane throws.
 */
export function classifyLiveTransportError(
  err: unknown,
  action: "execute" | "lock" = "execute",
): LiveTransportState | undefined {
  if (err instanceof LiveExecuteHoldError) {
    return { kind: "live-not-enabled", action };
  }
  if (isRecord(err) && err["code"] === "LIVE_EXECUTE_HOLD") {
    return { kind: "live-not-enabled", action };
  }
  const message = messageOf(err);
  if (message === "") {
    return undefined;
  }
  if (/denied by browser policy/i.test(message)) {
    return { kind: "pairing-refused", cause: "denied" };
  }
  if (/no device was selected/i.test(message)) {
    return { kind: "pairing-refused", cause: "cancelled" };
  }
  if (
    /disappeared|is not open|usb (?:read|write|payload write) failed|read aborted/i.test(message)
  ) {
    return { kind: "device-disconnected", detail: message };
  }
  return undefined;
}

/**
 * The build-level gate: a non-simulated session cannot write while the build
 * does not claim a live flash. Derived from the shipped `LIVE_FLASH_CLAIMED`
 * constant by the caller — this function never decides the flag, it only
 * presents the refusal.
 *
 * `sim: true` returns `undefined`: a simulated session writes to
 * `SimulatedDevice` and never touches hardware, so the live claim is irrelevant
 * to it (D-011).
 */
export function liveFlashRefusal(input: {
  readonly sim: boolean;
  readonly liveFlashClaimed: boolean;
  readonly action?: "execute" | "lock";
}): LiveTransportState | undefined {
  if (input.sim || input.liveFlashClaimed) {
    return undefined;
  }
  return { kind: "live-not-enabled", action: input.action ?? "execute" };
}
