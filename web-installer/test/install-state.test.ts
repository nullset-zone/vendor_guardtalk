import assert from "node:assert/strict";
import { test } from "node:test";
import { deserialize, initialInstallState, isHardStopped, reduce, serialize, type InstallState } from "../lib/install-state/machine.js";
import { flowsAllowedOnRoute, stepsForRoute, UPDATE_ROUTE_ALLOWED_FLOWS } from "../lib/install-state/steps.js";
import { STOP_REASONS, stopReason } from "../lib/install-state/stops.js";

function driveInstall(): InstallState {
  let state = initialInstallState("install");
  const actions = [
    { type: "acknowledge-intro" },
    { type: "files-picked" },
    { type: "release-verified" },
    { type: "key-flow-chosen", keyFlow: 1 as const },
    { type: "fingerprint-recorded" },
    { type: "vbmeta-signed" },
    { type: "oem-unlock-acked" },
    { type: "device-matched", product: "tokay" },
    { type: "flash-step-done" },
    { type: "lock-confirmed" },
    { type: "boot-fingerprint-typed", fingerprint: "ab12cd34" },
  ] as const;
  for (const action of actions) {
    state = reduce(state, action);
  }
  return state;
}

test("happy path reaches step 9 only through explicit actions", () => {
  const finalState = driveInstall();
  assert.equal(finalState.currentStep, 9);
  assert.deepEqual([...finalState.completedSteps].sort((a, b) => a - b), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
  assert.equal(finalState.keyFlow, 1);
});

test("step 9 is terminal; keep-key marks completion without leaving the route", () => {
  const terminal = reduce(driveInstall(), { type: "keep-key-acknowledged" });
  assert.equal(terminal.currentStep, 9);
  assert.ok(terminal.completedSteps.has(9));
  assert.equal(reduce(terminal, { type: "keep-key-acknowledged" }).currentStep, 9);
});

test("device step refuses to complete before the OEM-unlock ack", () => {
  let state = initialInstallState("install");
  for (const action of [
    { type: "acknowledge-intro" },
    { type: "files-picked" },
    { type: "release-verified" },
    { type: "key-flow-chosen", keyFlow: 2 as const },
    { type: "fingerprint-recorded" },
    { type: "vbmeta-signed" },
  ] as const) {
    state = reduce(state, action);
  }
  assert.equal(state.currentStep, 5);
  const skipped = reduce(state, { type: "device-matched", product: "tokay" });
  const last = skipped.stops[skipped.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reasonId, "OEM_UNLOCK_ACK_REQUIRED");
  assert.equal(skipped.currentStep, 5);
});

test("no implicit or timer-driven advance exists in the action vocabulary", () => {
  const state = initialInstallState("install");
  assert.equal(reduce(state, { type: "reset" }).currentStep, state.currentStep);
  const advanced = reduce(state, { type: "acknowledge-intro" });
  assert.notEqual(advanced.currentStep, state.currentStep);
  const frozen = reduce(advanced, { type: "acknowledge-intro" });
  assert.equal(frozen.currentStep, advanced.currentStep);
  assert.ok(frozen.stops.length > 0);
});

test("every out-of-order attempt yields a stop record and unchanged progress", () => {
  const base = reduce(initialInstallState("install"), { type: "acknowledge-intro" });
  const attempts = [
    { type: "vbmeta-signed" },
    { type: "flash-step-done" },
    { type: "lock-confirmed" },
    { type: "boot-fingerprint-typed", fingerprint: "deadbeef" },
    { type: "keep-key-acknowledged" },
    { type: "key-flow-chosen", keyFlow: 2 as const },
  ] as const;
  for (const action of attempts) {
    const next = reduce(base, action);
    assert.equal(next.currentStep, base.currentStep);
    assert.deepEqual(next.completedSteps, base.completedSteps);
    const lastStop = next.stops[next.stops.length - 1];
    assert.ok(lastStop !== undefined);
    assert.equal(lastStop.reasonId, "OUT_OF_ORDER");
    assert.equal(lastStop.reason, STOP_REASONS.OUT_OF_ORDER);
    assert.equal(lastStop.step, base.currentStep);
  }
});

test("stop reasons are a single verbatim vocabulary", () => {
  const values = Object.values(STOP_REASONS);
  assert.equal(new Set(values).size, values.length);
  assert.equal(stopReason("HASH_MISMATCH"), STOP_REASONS.HASH_MISMATCH);
  for (const value of values) {
    assert.equal(typeof value, "string");
    assert.ok(value.length > 0);
  }
});

test("tamper matrix stops at the correct step with the verbatim reason and hard-freezes", () => {
  const matrix: ReadonlyArray<{
    build: () => InstallState;
    condition: "hash-mismatch" | "signature-invalid" | "fingerprint-retype-wrong" | "partition-layout-unknown" | "product-mismatch" | "fastboot-fail" | "boot-fingerprint-mismatch" | "user-anchor-mismatch";
    expectedReason: string;
    atStep: number;
  }> = [
    {
      build: () => initialInstallState("install"),
      condition: "hash-mismatch",
      expectedReason: STOP_REASONS.HASH_MISMATCH,
      atStep: 1,
    },
    {
      build: () =>
        reduce(
          reduce(initialInstallState("install"), { type: "acknowledge-intro" }),
          { type: "files-picked" },
        ),
      condition: "signature-invalid",
      expectedReason: STOP_REASONS.SIGNATURE_INVALID,
      atStep: 2,
    },
    {
      build: () => {
        let state = initialInstallState("install");
        for (const action of [
          { type: "acknowledge-intro" },
          { type: "files-picked" },
          { type: "release-verified" },
          { type: "key-flow-chosen", keyFlow: 2 as const },
          { type: "fingerprint-recorded" },
        ] as const) {
          state = reduce(state, action);
        }
        return state;
      },
      condition: "partition-layout-unknown",
      expectedReason: STOP_REASONS.PARTITION_LAYOUT_UNKNOWN,
      atStep: 4,
    },
    {
      build: () => initialInstallState("verify-device"),
      condition: "product-mismatch",
      expectedReason: STOP_REASONS.PRODUCT_MISMATCH,
      atStep: 5,
    },
    {
      build: () => reduce(driveInstall(), { type: "back" }),
      condition: "boot-fingerprint-mismatch",
      expectedReason: STOP_REASONS.BOOT_FINGERPRINT_MISMATCH,
      atStep: 8,
    },
  ];
  for (const testCase of matrix) {
    const state = testCase.build();
    const stopped = reduce(state, { type: "stop", step: testCase.atStep, condition: testCase.condition });
    const last = stopped.stops[stopped.stops.length - 1];
    assert.ok(last !== undefined);
    assert.equal(last.reason, testCase.expectedReason);
    assert.equal(last.step, testCase.atStep);
    assert.equal(stopped.currentStep, state.currentStep);
    const expected = ADVANCE_ACTION_BY_STEP[testCase.atStep];
    if (expected !== undefined) {
      const afterStop = reduce(stopped, { type: "acknowledge-intro" });
      assert.deepEqual(afterStop.stops, stopped.stops);
      assert.equal(afterStop.currentStep, stopped.currentStep);
      assert.equal(isHardStopped(stopped), true);
    }
  }
});

const ADVANCE_ACTION_BY_STEP: Readonly<Record<number, string>> = {
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

test("fastboot fail stop carries verbatim reason and freezes advancement", () => {
  const state = reduce(driveInstall(), { type: "stop", step: 6, condition: "fastboot-fail" });
  const last = state.stops[state.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reason, STOP_REASONS.FASTBOOT_FAIL);
  const attempted = reduce(state, { type: "flash-step-done" });
  assert.deepEqual(attempted.stops, state.stops);
  assert.equal(attempted.currentStep, state.currentStep);
});

test("update route data encodes D-003 subsets and rejects generate flow", () => {
  assert.deepEqual(stepsForRoute("update"), [1, 2, 3, 4, 5, 6, 8, 9]);
  assert.deepEqual([...UPDATE_ROUTE_ALLOWED_FLOWS], [2, 3]);
  assert.deepEqual(flowsAllowedOnRoute("update"), [2, 3]);
  assert.deepEqual(flowsAllowedOnRoute("install"), [1, 2, 3]);
  assert.deepEqual(stepsForRoute("verify-device"), [5, 8]);
  const update = initialInstallState("update");
  assert.equal(update.currentStep, 1);
});

type GenerateAction = { type: "generate-key" };

test("update route rejects generate flow at type level and runtime", () => {
  const update = initialInstallState("update");
  let state = reduce(update, { type: "files-picked" });
  state = reduce(state, { type: "release-verified" });
  assert.equal(state.currentStep, 3);
  const generateAttempt = reduce(state, { type: "key-flow-chosen", keyFlow: 1 });
  const last = generateAttempt.stops[generateAttempt.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reasonId, "KEY_FLOW_FORBIDDEN");
  assert.equal(generateAttempt.keyFlow, undefined);
  const byoOk = reduce(state, { type: "key-flow-chosen", keyFlow: 3 });
  assert.equal(byoOk.keyFlow, 3);
  assert.equal(byoOk.currentStep, 3);
  const illegal: GenerateAction = { type: "generate-key" };
  assert.equal(
    ["acknowledge-intro", "files-picked", "release-verified", "key-flow-chosen"].includes(illegal.type),
    false,
  );
});

test("deep-link serialization roundtrips without key material fields", () => {
  let state = initialInstallState("update");
  state = reduce(state, { type: "files-picked" });
  state = reduce(state, { type: "release-verified" });
  state = reduce(state, { type: "key-flow-chosen", keyFlow: 2 });
  const text = serialize(state);
  const parsed = JSON.parse(text) as Record<string, unknown>;
  const forbiddenKeys = [
    "key", "privateKey", "publicKey", "pem", "passphrase", "fingerprint",
    "digest", "signature", "sigBytes", "material", "jwk", "n", "e", "d",
    "hashes", "sums", "files", "content", "secret",
  ];
  for (const key of Object.keys(parsed)) {
    assert.equal(forbiddenKeys.includes(key.toLowerCase()), false, `unexpected field ${key}`);
  }
  assert.deepEqual(Object.keys(parsed).sort(), ["completedSteps", "currentStep", "keyFlow", "route"]);
  const restored = deserialize(text);
  assert.equal(restored.route, "update");
  assert.equal(restored.currentStep, state.currentStep);
  assert.equal(restored.keyFlow, 2);
  assert.deepEqual([...restored.completedSteps], [...state.completedSteps]);
});

test("deserialize rejects tampered payloads", () => {
  assert.throws(() => deserialize("{not json"));
  assert.throws(() => deserialize('{"route":"mars"}'), /route/);
  assert.throws(() => deserialize('{"route":"update","currentStep":"x","completedSteps":[]}'), /currentStep/);
  assert.throws(() => deserialize('{"route":"update","currentStep":1,"completedSteps":["a"]}'), /completedSteps/);
  assert.throws(
    () => deserialize('{"route":"update","currentStep":2,"completedSteps":[],"keyFlow":1}'),
    /keyFlow/,
  );
  assert.throws(
    () => deserialize('{"route":"verify-device","currentStep":6,"completedSteps":[2,4,5]}'),
    /currentStep/,
  );
  assert.throws(
    () => deserialize('{"route":"verify-device","currentStep":5,"completedSteps":[2,4]}'),
    /completedSteps/,
  );
  assert.throws(
    () => deserialize('{"route":"recover","currentStep":6,"completedSteps":[2,4,5]}'),
    /recover/,
  );
});
