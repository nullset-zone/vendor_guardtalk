import assert from "node:assert/strict";
import { test } from "node:test";
import {
  LiveExecuteHoldError,
  LockBeforeCompleteError,
  UnlockCancelledError,
  WrongProductError,
} from "../src/errors.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import { bundleFromBlobs, MockFastboot, tokayBlobs } from "./helpers.js";

function makeOrch(transport: MockFastboot): FlashOrchestrator {
  const { channel, store } = bundleFromBlobs(tokayBlobs());
  return new FlashOrchestrator({ transport, channel, store });
}

test("suite does not claim a live-flash PASS", () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
  const orch = makeOrch(new MockFastboot());
  assert.equal(orch.claimsLiveFlash(), false);
});

test("wrong product (rango) is rejected on connect", async () => {
  const transport = new MockFastboot();
  transport.product = "rango";
  const orch = makeOrch(transport);
  await assert.rejects(() => orch.connect(), WrongProductError);
});

test("unlock cancelled is rejected", async () => {
  const transport = new MockFastboot();
  transport.unlockOk = false;
  const orch = makeOrch(transport);
  await orch.connect();
  await assert.rejects(() => orch.unlock(), UnlockCancelledError);
});

test("lock before the plan completes is rejected", async () => {
  const transport = new MockFastboot();
  transport.unlocked = "yes";
  const orch = makeOrch(transport);
  await orch.connect();
  await orch.unlock();
  await assert.rejects(() => orch.lock(), LockBeforeCompleteError);
  assert.equal(orch.isPlanComplete(), false);
});

test("mocked flash runs firmware then avb key then OS, then lock", async () => {
  const transport = new MockFastboot();
  transport.unlocked = "yes";
  const orch = makeOrch(transport);
  await orch.connect();
  await orch.unlock();
  await orch.executePlan({ onReconnect: async () => undefined });
  assert.equal(orch.isPlanComplete(), true);
  await orch.lock();

  const flashes = transport.log
    .filter((e) => e.type === "flash")
    .map((e) => e.partition);
  assert.deepEqual(flashes, [
    "bootloader",
    "radio",
    "avb_custom_key",
    "boot",
    "vbmeta",
  ]);
  assert.ok(transport.reconnects >= 2);
  assert.ok(transport.log.some((e) => e.command === "flashing lock"));
  assert.equal(LIVE_FLASH_CLAIMED, false);
});

test("live executePlan is HOLD", async () => {
  const transport = new MockFastboot({ live: true });
  transport.unlocked = "yes";
  const orch = makeOrch(transport);
  await orch.connect();
  await orch.unlock();
  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => undefined }),
    LiveExecuteHoldError,
  );
  assert.equal(orch.isPlanComplete(), false);
  assert.equal(
    transport.log.some((e) => e.type === "flash"),
    false,
  );
  assert.equal(LIVE_FLASH_CLAIMED, false);
});

test("live lock is HOLD", async () => {
  const transport = new MockFastboot({ live: true });
  const orch = makeOrch(transport);
  await orch.connect();
  await assert.rejects(() => orch.lock(), LiveExecuteHoldError);
  assert.equal(
    transport.log.some((e) => e.command === "flashing lock"),
    false,
  );
});

test("already-unlocked device does not send flashing unlock", async () => {
  const transport = new MockFastboot();
  transport.unlocked = "yes";
  const orch = makeOrch(transport);
  await orch.connect();
  await orch.unlock();
  assert.equal(
    transport.log.some((e) => e.command === "flashing unlock"),
    false,
  );
});
