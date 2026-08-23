/** Canonical step definitions 0–9 (PLAN.md §1) with route applicability data. */

export type RouteId = "install" | "update" | "verify-device" | "recover";

export type KeyFlowId = 1 | 2 | 3;

export type StopConditionId =
  | "hash-mismatch"
  | "signature-invalid"
  | "fingerprint-retype-wrong"
  | "partition-layout-unknown"
  | "product-mismatch"
  | "fastboot-fail"
  | "boot-fingerprint-mismatch"
  | "user-anchor-mismatch";

export type AdvanceAction =
  | "acknowledge-intro"
  | "files-picked"
  | "release-verified"
  | "key-flow-chosen"
  | "fingerprint-recorded"
  | "vbmeta-signed"
  | "device-matched"
  | "oem-unlock-acked"
  | "flash-step-done"
  | "lock-confirmed"
  | "boot-fingerprint-typed"
  | "keep-key-acknowledged";

export interface StepDefinition {
  readonly step: number;
  readonly title: string;
  readonly advanceAction: AdvanceAction;
  readonly stopConditions: readonly StopConditionId[];
  /** Steps the user may revisit via back(); empty for step 0. */
  readonly backTarget: number;
  /**
   * Acks that cannot be undone by back(); data-wipe and unlock warnings must
   * be re-acknowledged after any state reset.
   */
  readonly irreversibleAfterAck: boolean;
}

const STEP_DEFINITIONS: readonly StepDefinition[] = [
  {
    step: 0,
    title: "Before you start",
    advanceAction: "acknowledge-intro",
    stopConditions: [],
    backTarget: 0,
    irreversibleAfterAck: false,
  },
  {
    step: 1,
    title: "Get release over Tor",
    advanceAction: "files-picked",
    stopConditions: [],
    backTarget: 0,
    irreversibleAfterAck: false,
  },
  {
    step: 2,
    title: "Verify release",
    advanceAction: "release-verified",
    stopConditions: ["hash-mismatch", "signature-invalid"],
    backTarget: 1,
    irreversibleAfterAck: false,
  },
  {
    step: 3,
    title: "Your key",
    advanceAction: "key-flow-chosen",
    stopConditions: ["fingerprint-retype-wrong"],
    backTarget: 2,
    irreversibleAfterAck: false,
  },
  {
    step: 4,
    title: "Sign the release",
    advanceAction: "vbmeta-signed",
    stopConditions: ["partition-layout-unknown", "user-anchor-mismatch"],
    backTarget: 3,
    irreversibleAfterAck: false,
  },
  {
    step: 5,
    title: "Connect device",
    advanceAction: "device-matched",
    stopConditions: ["product-mismatch"],
    backTarget: 4,
    irreversibleAfterAck: true,
  },
  {
    step: 6,
    title: "Flash",
    advanceAction: "flash-step-done",
    stopConditions: ["fastboot-fail"],
    backTarget: 5,
    irreversibleAfterAck: false,
  },
  {
    step: 7,
    title: "Lock",
    advanceAction: "lock-confirmed",
    stopConditions: [],
    backTarget: 6,
    irreversibleAfterAck: false,
  },
  {
    step: 8,
    title: "First boot & verify",
    advanceAction: "boot-fingerprint-typed",
    stopConditions: ["boot-fingerprint-mismatch"],
    backTarget: 7,
    irreversibleAfterAck: false,
  },
  {
    step: 9,
    title: "Keep the key",
    advanceAction: "keep-key-acknowledged",
    stopConditions: [],
    backTarget: 8,
    irreversibleAfterAck: false,
  },
];

export function stepDefinitions(): readonly StepDefinition[] {
  return STEP_DEFINITIONS;
}

export function stepDefinition(step: number): StepDefinition {
  const found = STEP_DEFINITIONS[step];
  if (found === undefined || found.step !== step) {
    throw new Error(`unknown step ${step}`);
  }
  return found;
}

/** D-003: update route hides the generate flow; only bring-your-own / sign elsewhere. */
export const UPDATE_ROUTE_ALLOWED_FLOWS: readonly KeyFlowId[] = [2, 3];
export const INSTALL_ROUTE_ALLOWED_FLOWS: readonly KeyFlowId[] = [1, 2, 3];

interface RouteShape {
  readonly steps: readonly number[];
  readonly flowsAllowed?: readonly KeyFlowId[];
  readonly note?: string;
}

/**
 * Route subsets as data (D-001…D-003):
 * - update = steps [1,2,3,4,5,6,8,9], step 3 restricted to flows 2/3.
 * - verify-device = steps [5,8] only.
 * - recover is a custom path: unlock (wipes all data) → new key → reinstall;
 *   it never reaches flash/lock steps of /install and states that plainly.
 */
export const ROUTES: Readonly<Record<RouteId, RouteShape>> = {
  install: { steps: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], flowsAllowed: INSTALL_ROUTE_ALLOWED_FLOWS },
  update: { steps: [1, 2, 3, 4, 5, 6, 8, 9], flowsAllowed: UPDATE_ROUTE_ALLOWED_FLOWS },
  "verify-device": {
    steps: [5, 8],
    note: "read enrolled key where bootloader exposes it; guided boot-screen fingerprint comparison",
  },
  recover: {
    steps: [],
    note: "custom path: unlock wipes all data, then re-enrol a new key, then reinstall",
  },
};

export function stepsForRoute(route: RouteId): readonly number[] {
  return ROUTES[route].steps;
}

export function flowsAllowedOnRoute(route: RouteId): readonly KeyFlowId[] | undefined {
  return ROUTES[route].flowsAllowed;
}
