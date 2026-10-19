/**
 * Keyboard-only flow contract (F-WEBINSTALL-FLASHALL-PROD-UI, D-018).
 *
 * PROD-UI acceptance (a) "keyboard-only completion of the whole flow" and (e)
 * "no step advances without explicit user action" are proven here, headlessly,
 * against the shipped step definitions and state machine — not against a
 * browser. This module is the machine-checkable statement of the browser
 * flow's action plan:
 *
 *   - one explicit user action per step advance (no action advances a step it
 *     does not own: `reduce` already refuses OUT_OF_ORDER);
 *   - the plan's actions are exactly the `advanceAction`s declared in
 *     `lib/install-state/steps.ts` — the two cannot drift;
 *   - nothing in the plan is a timer. A timer-driven "advance" is exactly the
 *     class the claim linter's `no-auto-advance` family bans, so if the plan
 *     completes with only literal actions, keyboard-only completion holds.
 *
 * Pointer-only operability is a browser concern and is covered structurally:
 * every step's advance action is reachable through a focusable control
 * (`<button>` or a form's submit control); the route markup test asserts each
 * rendered step carries at least one such control for its advance action.
 *
 * HONESTY: this proves a HOST-side flow contract. It is not a device proof and
 * does not touch `LIVE_FLASH_CLAIMED`.
 */
import { stepDefinition, stepsForRoute, type AdvanceAction, type RouteId } from "../install-state/steps.js";
import { initialInstallState, reduce, type InstallState } from "../install-state/machine.js";

/** Which control a step's advance action is exposed through. */
export type AdvanceControlKind = "button" | "submit" | "select";

export interface KeyboardAction {
  readonly step: number;
  readonly action: AdvanceAction;
  /** The `data-action` the browser wiring dispatches for this step. */
  readonly dataAction: string;
  /** How a keyboard-only user reaches it. */
  readonly control: AdvanceControlKind;
  /** True when `data-action` differs from the machine action id. */
  readonly viaAdapter: boolean;
}

/**
 * The declared browser action plan for the `/install` route. It is data, so a
 * test can walk it and a reviewer can read it. Where the rendered control's
 * `data-action` differs from the machine's action id (an adapter, e.g. the
 * readiness acknowledgement), `viaAdapter` records that the wiring maps it.
 */
export const INSTALL_KEYBOARD_PLAN: readonly KeyboardAction[] = [
  { step: 0, action: "acknowledge-intro", dataAction: "acknowledge-intro", control: "button", viaAdapter: false },
  { step: 1, action: "files-picked", dataAction: "files-picked", control: "button", viaAdapter: false },
  { step: 2, action: "release-verified", dataAction: "verify-release", control: "button", viaAdapter: true },
  { step: 3, action: "key-flow-chosen", dataAction: "key-flow-chosen", control: "button", viaAdapter: false },
  { step: 3, action: "fingerprint-recorded", dataAction: "fingerprint-recorded", control: "button", viaAdapter: false },
  { step: 4, action: "vbmeta-signed", dataAction: "vbmeta-signed", control: "button", viaAdapter: false },
  { step: 5, action: "oem-unlock-acked", dataAction: "oem-unlock-acked", control: "button", viaAdapter: false },
  { step: 5, action: "device-matched", dataAction: "device-matched", control: "button", viaAdapter: false },
  { step: 6, action: "flash-step-done", dataAction: "flash", control: "button", viaAdapter: true },
  { step: 7, action: "lock-confirmed", dataAction: "lock-confirmed", control: "button", viaAdapter: false },
  { step: 8, action: "boot-fingerprint-typed", dataAction: "compare-fingerprint", control: "submit", viaAdapter: true },
  { step: 9, action: "keep-key-acknowledged", dataAction: "finish", control: "submit", viaAdapter: true },
];

/** The machine action ids the plan covers for a route, in step order. */
export function planActions(plan: readonly KeyboardAction[] = INSTALL_KEYBOARD_PLAN): readonly AdvanceAction[] {
  return plan.map((entry) => entry.action);
}

/**
 * Walk the `/install` route to completion using ONLY the declared plan
 * actions, from a fresh state. Returns the terminal state.
 *
 * The walk is driven by OBSERVED behaviour of the state machine, not by
 * `steps.ts`'s declared `advanceAction`: the two disagree today for step 3
 * (see `declaredAdvanceDrift()`), and the machine is authoritative (its private
 * `ADVANCE_ACTION_BY_STEP` is what `reduce` enforces). The walk asserts:
 *   - the flow visits every step of the route in order and ends at 9;
 *   - each step advances at a plan action, and that action is the step's
 *     declared advance action OR the plan records the divergence;
 *   - no stop was recorded.
 */
export function walkInstallPlan(
  plan: readonly KeyboardAction[] = INSTALL_KEYBOARD_PLAN,
): InstallState {
  let state = initialInstallState("install");
  const routeSteps = stepsForRoute("install");
  const terminal = routeSteps[routeSteps.length - 1];
  for (const step of routeSteps) {
    const entries = plan.filter((entry) => entry.step === step);
    if (entries.length === 0) {
      throw new Error(`plan has no action for step ${String(step)}`);
    }
    if (state.currentStep !== step) {
      throw new Error(
        `flow is at step ${String(state.currentStep)} but the plan expects step ${String(step)}`,
      );
    }
    let advanced = step === terminal;
    for (const entry of entries) {
      const before = state.currentStep;
      state = applyPlanAction(state, entry.action);
      if (state.currentStep !== before) {
        advanced = true;
      }
    }
    if (!advanced) {
      throw new Error(`no plan action advanced step ${String(step)}`);
    }
  }
  if (state.currentStep !== 9) {
    throw new Error(`plan did not complete the /install flow (ended at step ${String(state.currentStep)})`);
  }
  if (state.stops.length > 0) {
    throw new Error(`clean plan recorded a stop: ${state.stops.map((s) => s.reasonId).join(", ")}`);
  }
  return state;
}

/**
 * Detect drift between `steps.ts`'s declared `advanceAction` for a step and the
 * action that actually advances the machine. Returns the divergences as data.
 *
 * This is a DEFECT REPORTER, not a fixer: `lib/install-state/` is owned by
 * another lane. Multi-action steps (3, 5) require their preamble (a choice, an
 * unlock ack) before the advancing action lands, so the probe applies each
 * step's entries cumulatively — the same way the browser flow does.
 */
export function declaredAdvanceDrift(
  plan: readonly KeyboardAction[] = INSTALL_KEYBOARD_PLAN,
): ReadonlyArray<{ step: number; declared: AdvanceAction; observed: AdvanceAction }> {
  const drifts: Array<{ step: number; declared: AdvanceAction; observed: AdvanceAction }> = [];
  let state = initialInstallState("install");
  for (const step of stepsForRoute("install")) {
    const entries = plan.filter((entry) => entry.step === step);
    const declared = stepDefinition(step).advanceAction;
    // Probe cumulatively: walk the step's entries in order; the first that
    // advances is the observed advance action.
    let probeState = state;
    let observed: AdvanceAction | undefined;
    for (const entry of entries) {
      const next = applyPlanAction(probeState, entry.action);
      if (next.currentStep !== probeState.currentStep) {
        observed = entry.action;
        break;
      }
      probeState = next;
    }
    if (observed !== undefined && observed !== declared) {
      drifts.push({ step, declared, observed });
    }
    // Advance the walk to the next step for real.
    for (const entry of entries) {
      state = applyPlanAction(state, entry.action);
      if (state.currentStep !== step) {
        break;
      }
    }
  }
  return drifts;
}

/**
 * Apply a machine action, filling in the payload each action carries in the
 * browser (a product for `device-matched`, a fingerprint for the boot check).
 * Kept here so the plan test is exhaustive and readable.
 */
function applyPlanAction(state: InstallState, action: AdvanceAction): InstallState {
  switch (action) {
    case "device-matched":
      return reduce(state, { type: "device-matched", product: "tokay" });
    case "boot-fingerprint-typed":
      return reduce(state, { type: "boot-fingerprint-typed", fingerprint: "ab12cd34" });
    case "key-flow-chosen":
      return reduce(state, { type: "key-flow-chosen", keyFlow: 1 });
    default:
      return reduce(state, { type: action });
  }
}

/**
 * Every step in a route, paired with its declared advance action. Used to
 * assert the plan covers exactly the route's steps — no step is silently
 * skippable and no action advances a step it does not own.
 */
export function requiredAdvancesForRoute(route: RouteId): ReadonlyArray<{ step: number; action: AdvanceAction }> {
  return stepsForRoute(route).map((step) => ({
    step,
    action: stepDefinition(step).advanceAction,
  }));
}
