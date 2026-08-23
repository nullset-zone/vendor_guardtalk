/**
 * Step rail renderer over the lib/install-state step data (machine.ts +
 * steps.ts). Renders an <ol> of steps with current/completed/pending/stopped
 * states, roving-tabindex keyboard navigation, aria-current="step", a
 * tripwire chip + verbatim STOP reason on hard stop, and back hidden after
 * irreversible acknowledgements.
 *
 * The keyboard behaviour lives in resolveRailKey + the controller returned by
 * renderRail, both drivable with synthetic events (no DOM required), so the
 * handler is unit-testable headlessly; wireRail attaches the DOM adapter.
 */
import { isHardStopped, type InstallState } from "../install-state/machine.js";
import { stepDefinition, stepsForRoute } from "../install-state/steps.js";
import { escapeHtml } from "./escape.js";
import { makeChip } from "./chips.js";

export type RailStepStatus = "current" | "completed" | "pending" | "stopped";

export interface RailStepView {
  readonly step: number;
  readonly title: string;
  readonly status: RailStepStatus;
  /** Reachable-by-back targets are selectable; forward steps stay inert. */
  readonly reachableByBack: boolean;
  readonly stopReason?: string;
}

export type RailSelectIntent = "select-current" | "go-back";

export type RailSelectResult =
  | { readonly accepted: true; readonly intent: RailSelectIntent; readonly step: number }
  | { readonly accepted: false; readonly step: number };

export interface RailKeyContext {
  /** Current machine state; used to validate go-back requests. */
  readonly state: InstallState;
  /**
   * Applies the user action to the state machine and returns the new state.
   * Pure reducer — explicit user actions only, never timers.
   */
  readonly dispatch: (action: { type: "back" }) => InstallState;
}

export interface RailHooks {
  /** Called with the index that should receive focus (arrow/Home/End). */
  readonly onFocus?: (index: number) => void;
  /** Called when a selection actually advances the machine (go-back). */
  readonly onSelect?: (step: number) => void;
}

/** Synthetic key event against the rail's button contract (data-step). */
export interface RailKeyEventLike {
  readonly key: string;
  readonly targetStep: number;
}

export type RailKeyAction =
  | { readonly kind: "none" }
  | { readonly kind: "focus"; readonly index: number }
  | { readonly kind: "activate"; readonly index: number };

const ARROW_NEXT: ReadonlySet<string> = new Set(["ArrowDown", "ArrowRight"]);
const ARROW_PREV: ReadonlySet<string> = new Set(["ArrowUp", "ArrowLeft"]);

/**
 * Pure roving-tabindex resolver: given the button count, the currently
 * focused index and the key, decide what happens. Arrow keys wrap; Enter or
 * Space activates the focused step; everything else is ignored here.
 */
export function resolveRailKey(count: number, focusedIndex: number, key: string): RailKeyAction {
  if (count === 0) {
    return { kind: "none" };
  }
  const wrap = (index: number): number => ((index % count) + count) % count;
  if (ARROW_NEXT.has(key)) {
    return { kind: "focus", index: wrap(focusedIndex + 1) };
  }
  if (ARROW_PREV.has(key)) {
    return { kind: "focus", index: wrap(focusedIndex - 1) };
  }
  if (key === "Home") {
    return { kind: "focus", index: 0 };
  }
  if (key === "End") {
    return { kind: "focus", index: count - 1 };
  }
  if (key === "Enter" || key === " ") {
    return { kind: "activate", index: focusedIndex };
  }
  return { kind: "none" };
}

function stoppedRecord(state: InstallState): string | undefined {
  if (!isHardStopped(state)) {
    return undefined;
  }
  const record = [...state.stops].reverse().find((stop) => stop.step === state.currentStep);
  return record === undefined ? undefined : record.reason;
}

function backTargetsFor(state: InstallState): ReadonlySet<number> {
  // Back stays visible except after an irreversible acknowledgement
  // (BACK_PAST_IRREVERSIBLE); the current step's own definition decides.
  const current = stepDefinition(state.currentStep);
  if (current.irreversibleAfterAck || current.backTarget === current.step) {
    return new Set<number>();
  }
  return new Set([current.backTarget]);
}

export function railStepViews(state: InstallState): readonly RailStepView[] {
  const stopped = stoppedRecord(state);
  const backTargets = backTargetsFor(state);
  return stepsForRoute(state.route).map((step) => {
    const definition = stepDefinition(step);
    let status: RailStepStatus;
    if (stopped !== undefined && step === state.currentStep) {
      status = "stopped";
    } else if (state.completedSteps.has(step)) {
      status = "completed";
    } else if (step === state.currentStep) {
      status = "current";
    } else {
      status = "pending";
    }
    return {
      step,
      title: definition.title,
      status,
      reachableByBack: backTargets.has(step),
      ...(stopped !== undefined && step === state.currentStep ? { stopReason: stopped } : {}),
    };
  });
}

function itemHtml(view: RailStepView, tabindex: number): string {
  const parts = [
    `<li class="rail-step" data-step="${String(view.step)}" data-status="${view.status}">`,
    `<button type="button" class="rail-step-button mono" data-step="${String(view.step)}"`,
    ` tabindex="${String(tabindex)}"`,
    ` aria-current="${view.status === "current" || view.status === "stopped" ? "step" : "false"}"`,
    ` data-reachable="${view.reachableByBack ? "true" : "false"}">`,
    `${escapeHtml(String(view.step))}. ${escapeHtml(view.title)} `,
  ];
  switch (view.status) {
    case "completed":
      parts.push(makeChip("COMPLETED", "verified"));
      break;
    case "stopped":
      parts.push(makeChip("STOPPED", "tripwire", { ariaLive: "assertive" }));
      break;
    case "pending":
      parts.push(makeChip("PENDING", "caution"));
      break;
    case "current":
      break;
  }
  parts.push(`</button>`);
  if (view.stopReason !== undefined) {
    parts.push(`<span class="rail-stop-reason">${escapeHtml(view.stopReason)}</span>`);
  }
  parts.push(`</li>`);
  return parts.join("");
}

export interface RenderedRail {
  readonly html: string;
  readonly items: readonly RailItem[];
  /** Step buttons in render order (populated only with a live DOM). */
  readonly buttons: readonly HTMLElement[];
  /** Synthetic-event entry point; drivable without a DOM. */
  handleKeyDown(event: RailKeyEventLike, context: RailKeyContext): void;
  selectStep(step: number, context: RailKeyContext): void;
}

export interface RailItem {
  readonly element: HTMLElement;
  readonly view: RailStepView;
}

export function renderRail(state: InstallState, hooks: RailHooks = {}): RenderedRail {
  const views = railStepViews(state);
  const focusIndex = Math.max(
    0,
    views.findIndex((view) => view.status === "current" || view.status === "stopped"),
  );
  const itemsHtml = views.map((view, index) => itemHtml(view, index === focusIndex ? 0 : -1)).join("");
  const html = [`<ol class="rail mono-rail" aria-label="Installer steps">`, itemsHtml, `</ol>`].join("");

  const buttons: HTMLElement[] = [];
  const items: RailItem[] = [];
  if (typeof document !== "undefined") {
    const template = document.createElement("template");
    template.innerHTML = html.trim();
    for (const button of template.content.querySelectorAll<HTMLElement>("button.rail-step-button")) {
      buttons.push(button);
    }
    for (const node of template.content.querySelectorAll<HTMLElement>("li.rail-step")) {
      const attr = node.getAttribute("data-step");
      const view = views.find((candidate) => candidate.step === Number(attr));
      if (view !== undefined) {
        items.push({ element: node, view });
      }
    }
  }

  function indexOfStep(step: number): number {
    return views.findIndex((view) => view.step === step);
  }

  function focusAt(index: number): void {
    const clamped = Math.min(views.length - 1, Math.max(0, index));
    hooks.onFocus?.(clamped);
    const target = buttons[clamped];
    if (target !== undefined) {
      for (const [i, button] of buttons.entries()) {
        button.tabIndex = i === clamped ? 0 : -1;
      }
      target.focus();
    }
  }

  function selectStep(step: number, context: RailKeyContext): void {
    const view = views[indexOfStep(step)];
    if (view === undefined) {
      return;
    }
    if (view.reachableByBack) {
      const next = context.dispatch({ type: "back" });
      const record = next.stops[next.stops.length - 1];
      const blocked = record !== undefined && record.reasonId === "BACK_PAST_IRREVERSIBLE";
      if (!blocked && next.currentStep === step) {
        hooks.onSelect?.(step);
        return;
      }
    }
    if (view.status === "current" || view.status === "stopped") {
      return;
    }
    throw new Error(`step ${String(step)} cannot be selected directly`);
  }

  return {
    html,
    items,
    buttons,
    selectStep,
    handleKeyDown(event, context): void {
      const index = indexOfStep(event.targetStep);
      if (index < 0) {
        return;
      }
      const action = resolveRailKey(views.length, index, event.key);
      if (action.kind === "focus") {
        focusAt(action.index);
        return;
      }
      if (action.kind === "activate") {
        const view = views[action.index];
        if (view?.reachableByBack === true) {
          selectStep(view.step, context);
        }
      }
    },
  };
}

/**
 * DOM adapter: forwards real keyboard events into the synthetic contract.
 * Callers attach this once per rendered rail.
 */
export function wireRail(
  root: HTMLElement,
  rail: RenderedRail,
  context: RailKeyContext,
  doc: Document = document,
): void {
  root.addEventListener("keydown", (event: Event) => {
    if (!(event instanceof doc.defaultView!.KeyboardEvent)) {
      return;
    }
    const target = event.target;
    if (!(target instanceof HTMLElement) || !target.classList.contains("rail-step-button")) {
      return;
    }
    const attr = target.getAttribute("data-step");
    if (attr === null) {
      return;
    }
    event.preventDefault();
    rail.handleKeyDown({ key: event.key, targetStep: Number(attr) }, context);
  });
}

/** Hard-stop banner copy helper: verbatim reason text for the stopped step. */
export function hardStopBanner(state: InstallState): string | undefined {
  return stoppedRecord(state);
}
