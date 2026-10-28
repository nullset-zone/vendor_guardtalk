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

test("mismatched product (rango on tokay channel) is rejected on connect", async () => {
  const transport = new MockFastboot();
  transport.product = "rango";
  const orch = makeOrch(transport);
  await assert.rejects(() => orch.connect(), WrongProductError);
});

test("unstamped product (shiba) is rejected on connect", async () => {
  const transport = new MockFastboot();
  transport.product = "shiba";
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

/* ------------------------------------------------------------------ *
 * T-WEBINSTALL-ORCHESTRATOR-CONNECT-LEAK — regression.
 *
 * The defect: `connected = true` was set BEFORE `await assertProduct()`, with
 * no rollback. A rejected connect therefore left every `requireConnected()`
 * guard satisfied, so the full plan would write every partition and run
 * `flashing lock` with no successful product check in the session.
 *
 * This is the acceptance criterion that was previously unproven: after a
 * rejected connect, unlock / executePlan / lock must ALL refuse and NOTHING
 * may reach the transport. It fails if the flag ordering is reverted.
 * ------------------------------------------------------------------ */

const NO_CONNECT = /connect\(\) before unlock, flash, or lock/;

test("a rejected connect() leaves every mutating entry point refusing, with zero writes", async () => {
  const transport = new MockFastboot();
  transport.product = "rango"; // does not match the tokay channel
  const orch = makeOrch(transport);

  await assert.rejects(() => orch.connect(), WrongProductError);

  const afterConnect = transport.log.length;

  await assert.rejects(() => orch.unlock(), NO_CONNECT);
  await assert.rejects(() => orch.executePlan({ onReconnect: async () => {} }), NO_CONNECT);
  await assert.rejects(() => orch.lock(), NO_CONNECT);

  // Refused calls must not reach the transport at all — so no flash, no
  // runCommand (erase / flashing lock travel through it), no reboot.
  assert.equal(
    transport.log.length,
    afterConnect,
    "refused calls must not reach the transport",
  );
  assert.deepEqual(
    transport.log.filter((c) => c.type === "flash" || c.type === "runCommand"),
    [],
    "a rejected connect must leave zero writes",
  );
});

test("a successful connect() still proceeds (non-vacuity for the connect-leak regression)", async () => {
  const transport = new MockFastboot();
  const orch = makeOrch(transport);
  await orch.connect();
  await orch.unlock();
  // The guard is open after a PROVEN product: unlock must reach the transport.
  assert.ok(
    transport.log.some((c) => c.type === "runCommand" || c.type === "getVar"),
    "a proven connect must leave the session usable",
  );
});
