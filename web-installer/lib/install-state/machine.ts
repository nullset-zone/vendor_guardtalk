/**
 * Pure install-state reducer. Transitions ONLY via named user actions; no
 * timer or implicit advance exists. EVERY recorded stop freezes advancement
 * until reset — guard violations and condition stops are a single freeze tier
 * (lens-3 M-1: the safer reading of this contract was chosen deliberately).
 * Condition stops additionally surface the hard-stop banner via
 * isHardStopped(); only reset clears a freeze.
 */
import {
  flowsAllowedOnRoute,
  stepDefinition,
  stepsForRoute,
  type AdvanceAction,
  type KeyFlowId,
  type RouteId,
  type StopConditionId,
} from "./steps.js";
import { STOP_REASONS, type StopReasonId } from "./stops.js";

/** Every stop freezes: guard violations are true freezes, not soft warnings. */
const FREEZE_REASON_IDS: ReadonlySet<StopReasonId> = new Set<StopReasonId>(
  Object.keys(STOP_REASONS) as StopReasonId[],
);

export interface StopRecord {
  readonly step: number;
  readonly reason: string;
  readonly reasonId: StopReasonId;
}

export interface InstallState {
  readonly route: RouteId;
  readonly currentStep: number;
  readonly completedSteps: ReadonlySet<number>;
  readonly stops: readonly StopRecord[];
  readonly keyFlow?: KeyFlowId;
  /** Set once the step-5 OEM-unlock data-wipe warning is acknowledged. */
  readonly oemUnlockAcked: boolean;
}

export type InstallAction =
  | { type: "acknowledge-intro" }
  | { type: "files-picked" }
  | { type: "release-verified" }
  | { type: "key-flow-chosen"; keyFlow: KeyFlowId }
  | { type: "fingerprint-recorded" }
  | { type: "vbmeta-signed" }
  | { type: "device-matched"; product: string }
  | { type: "oem-unlock-acked" }
  | { type: "flash-step-done" }
  | { type: "lock-confirmed" }
  | { type: "boot-fingerprint-typed"; fingerprint: string }
  | { type: "keep-key-acknowledged" }
  | { type: "back" }
  | { type: "reset" }
  | { type: "stop"; step: number; condition: StopConditionId };

const ADVANCE_ACTION_BY_STEP: Readonly<Record<number, AdvanceAction>> = {
  0: "acknowledge-intro",
  1: "files-picked",
  2: "release-verified",
  3: "fingerprint-recorded",
  4: "vbmeta-signed",
  5: "device-matched",
  6: "flash-step-done",
  7: "lock-confirmed",
  8: "boot-fingerprint-typed",
  9: "keep-key-acknowledged",
};

const CONDITION_TO_REASON: Readonly<Record<StopConditionId, StopReasonId>> = {
  "hash-mismatch": "HASH_MISMATCH",
  "signature-invalid": "SIGNATURE_INVALID",
  "fingerprint-retype-wrong": "FINGERPRINT_RETYPE_WRONG",
  "partition-layout-unknown": "PARTITION_LAYOUT_UNKNOWN",
  "product-mismatch": "PRODUCT_MISMATCH",
  "fastboot-fail": "FASTBOOT_FAIL",
  "boot-fingerprint-mismatch": "BOOT_FINGERPRINT_MISMATCH",
  "user-anchor-mismatch": "USER_ANCHOR_MISMATCH",
};

/** Condition stops render the hard-stop banner; guard freezes do not. */
const HARD_STOP_REASON_IDS: ReadonlySet<StopReasonId> = new Set<StopReasonId>(
  Object.values(CONDITION_TO_REASON),
);

export function initialInstallState(route: RouteId): InstallState {
  if (route === "recover") {
    return {
      route,
      currentStep: -1,
      completedSteps: new Set<number>(),
      stops: [],
      oemUnlockAcked: false,
    };
  }
  const first = stepsForRoute(route)[0];
  if (first === undefined) {
    throw new Error(`route ${route} defines no steps`);
  }
  return { route, currentStep: first, completedSteps: new Set<number>(), stops: [], oemUnlockAcked: false };
}

export function reduce(state: InstallState, action: InstallAction): InstallState {
  switch (action.type) {
    case "back":
      return back(state);
    case "reset":
      return initialInstallState(state.route);
    case "stop":
      return recordStop(state, action.step, action.condition);
    case "key-flow-chosen":
      return chooseKeyFlow(state, action.keyFlow);
    case "oem-unlock-acked":
      return ackOemUnlock(state);
    default:
      return advance(state, action);
  }
}

/**
 * True when a CONDITION stop is on record — the hard-stop banner tier.
 * Freezing itself is broader: any stop at all blocks advancement (isFrozen).
 */
export function isHardStopped(state: InstallState): boolean {
  return state.stops.some((stop) => HARD_STOP_REASON_IDS.has(stop.reasonId));
}

/** True while ANY stop is on record; every stop freezes until reset. */
export function isFrozen(state: InstallState): boolean {
  return state.stops.some((stop) => FREEZE_REASON_IDS.has(stop.reasonId));
}

function advance(state: InstallState, action: InstallAction): InstallState {
  if (state.route === "recover") {
    return freeze(state, "OUT_OF_ORDER");
  }
  if (isFrozen(state)) {
    return state;
  }
  const expected = ADVANCE_ACTION_BY_STEP[state.currentStep];
  if (expected === undefined) {
    return freeze(state, "ROUTE_STEP_FORBIDDEN");
  }
  if (action.type !== expected) {
    return freeze(state, "OUT_OF_ORDER");
  }
  if (state.currentStep === 3) {
    const flowViolation = checkKeyFlow(state);
    if (flowViolation !== undefined) {
      return freeze(state, flowViolation);
    }
  }
  if (state.currentStep === 5 && !state.oemUnlockAcked) {
    return freeze(state, "OEM_UNLOCK_ACK_REQUIRED");
  }
  const routeSteps = stepsForRoute(state.route);
  const currentIndex = routeSteps.indexOf(state.currentStep);
  const nextStep = routeSteps[currentIndex + 1];
  const completed = new Set(state.completedSteps);
  completed.add(state.currentStep);
  if (nextStep === undefined) {
    // Terminal step: completion is marked; the step stays current.
    return { ...state, completedSteps: completed };
  }
  return {
    route: state.route,
    currentStep: nextStep,
    completedSteps: completed,
    stops: state.stops,
    oemUnlockAcked: state.currentStep === 5 ? false : state.oemUnlockAcked,
    ...(state.keyFlow !== undefined ? { keyFlow: state.keyFlow } : {}),
  };
}

/**
 * Selecting a key flow is a choice, not an advancement: it records the choice
 * at step 3 and leaves advancing to fingerprint-recorded.
 */
function chooseKeyFlow(state: InstallState, keyFlow: KeyFlowId): InstallState {
  if (state.route === "recover" || state.currentStep !== 3) {
    return freeze(state, "OUT_OF_ORDER");
  }
  if (isFrozen(state)) {
    return state;
  }
  const allowed = flowsAllowedOnRoute(state.route);
  if (allowed !== undefined && !allowed.includes(keyFlow)) {
    return freeze(state, "KEY_FLOW_FORBIDDEN");
  }
  return { ...state, keyFlow };
}

/** Acknowledging the OEM-unlock data-wipe warning is recorded, not an advance. */
function ackOemUnlock(state: InstallState): InstallState {
  if (state.route === "recover" || state.currentStep !== 5) {
    return freeze(state, "OUT_OF_ORDER");
  }
  if (isFrozen(state)) {
    return state;
  }
  if (state.oemUnlockAcked) {
    return state;
  }
  return { ...state, oemUnlockAcked: true };
}

function checkKeyFlow(state: InstallState): StopReasonId | undefined {
  const flow = state.keyFlow;
  if (flow === undefined) {
    return "OUT_OF_ORDER";
  }
  const allowed = flowsAllowedOnRoute(state.route);
  if (allowed !== undefined && !allowed.includes(flow)) {
    return "KEY_FLOW_FORBIDDEN";
  }
  return undefined;
}

function back(state: InstallState): InstallState {
  if (state.route === "recover" || state.currentStep < 0) {
    return freeze(state, "OUT_OF_ORDER");
  }
  const definition = stepDefinition(state.currentStep);
  if (definition.irreversibleAfterAck) {
    return freeze(state, "BACK_PAST_IRREVERSIBLE");
  }
  const target = definition.backTarget;
  if (!stepsForRoute(state.route).includes(target)) {
    return freeze(state, "ROUTE_STEP_FORBIDDEN");
  }
  return { ...state, currentStep: target };
}

function recordStop(state: InstallState, step: number, condition: StopConditionId): InstallState {
  return appendStop(state, step, CONDITION_TO_REASON[condition]);
}

function freeze(state: InstallState, reasonId: StopReasonId): InstallState {
  return appendStop(state, state.currentStep, reasonId);
}

function appendStop(state: InstallState, step: number, reasonId: StopReasonId): InstallState {
  const record: StopRecord = { step, reason: STOP_REASONS[reasonId], reasonId };
  return { ...state, stops: [...state.stops, record] };
}

export interface SerializedInstallState {
  readonly route: RouteId;
  readonly currentStep: number;
  readonly completedSteps: number[];
  readonly keyFlow?: KeyFlowId;
}

/**
 * Deep-link serialization: route + progress ONLY. No key material, no
 * fingerprints, no file contents — those never leave the tab (D-007).
 */
export function serialize(state: InstallState): string {
  const payload: SerializedInstallState & { keyFlow?: KeyFlowId } = {
    route: state.route,
    currentStep: state.currentStep,
    completedSteps: [...state.completedSteps].sort((a, b) => a - b),
  };
  const flow = state.keyFlow;
  if (flow !== undefined) {
    return JSON.stringify({ ...payload, keyFlow: flow });
  }
  return JSON.stringify(payload);
}

export function deserialize(text: string): InstallState {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text) as unknown;
  } catch {
    throw new Error("install-state deep link is not valid JSON");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error("install-state deep link must be an object");
  }
  const record = parsed as Record<string, unknown>;
  const route = record.route;
  if (route !== "install" && route !== "update" && route !== "verify-device" && route !== "recover") {
    throw new Error("install-state deep link has an unknown route");
  }
  const currentStep = record.currentStep;
  if (typeof currentStep !== "number" || !Number.isInteger(currentStep)) {
    throw new Error("install-state deep link has an invalid currentStep");
  }
  const rawCompleted = record.completedSteps;
  if (!Array.isArray(rawCompleted) || !rawCompleted.every((n) => typeof n === "number" && Number.isInteger(n))) {
    throw new Error("install-state deep link has invalid completedSteps");
  }
  const legal = stepsForRoute(route);
  if (route === "recover") {
    if (currentStep !== 0 || rawCompleted.length !== 0) {
      throw new Error("install-state deep link is not valid for the recover route");
    }
  } else if (!legal.includes(currentStep)) {
    throw new Error("install-state deep link currentStep is not on this route");
  }
  if (rawCompleted.some((n) => !legal.includes(n as number))) {
    throw new Error("install-state deep link completedSteps contain a step not on this route");
  }
  let keyFlow: KeyFlowId | undefined;
  const keyFlowValue = record.keyFlow;
  if (keyFlowValue !== undefined) {
    if (keyFlowValue !== 1 && keyFlowValue !== 2 && keyFlowValue !== 3) {
      throw new Error("install-state deep link has an invalid keyFlow");
    }
    const allowed = flowsAllowedOnRoute(route);
    if (allowed !== undefined && !allowed.includes(keyFlowValue)) {
      throw new Error("install-state deep link keyFlow is not allowed on this route");
    }
    keyFlow = keyFlowValue;
  }
  return {
    route,
    currentStep,
    completedSteps: new Set(rawCompleted as number[]),
    stops: [],
    oemUnlockAcked: false,
    ...(keyFlow !== undefined ? { keyFlow } : {}),
  };
}
