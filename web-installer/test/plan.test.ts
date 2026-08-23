import assert from "node:assert/strict";
import { test } from "node:test";
import { FLASH_ORDER } from "../src/types.js";
import { buildFlashPlan, flashPhaseSequence } from "../src/plan.js";
import { bundleFromBlobs, tokayBlobs } from "./helpers.js";

test("flash order is firmware → avb_custom_key → os", () => {
  const { channel } = bundleFromBlobs(tokayBlobs());
  const plan = buildFlashPlan(channel);
  assert.deepEqual([...plan.flashOrder], [...FLASH_ORDER]);
  assert.deepEqual(flashPhaseSequence(plan), [
    "firmware",
    "avb_custom_key",
    "os",
  ]);
});

test("artifact flash sequence is bootloader, radio, avb key, then OS", () => {
  const { channel } = bundleFromBlobs(tokayBlobs());
  const flashes = buildFlashPlan(channel)
    .steps.filter((s) => s.kind === "flash")
    .map((s) => ("artifact" in s ? s.artifact : ""));
  assert.deepEqual(flashes, [
    "bootloader.img",
    "radio.img",
    "avb_pkmd.bin",
    "boot.img",
    "vbmeta.img",
  ]);
});

test("avb_pkmd.bin maps to partition avb_custom_key before any OS image", () => {
  const { channel } = bundleFromBlobs(tokayBlobs());
  const steps = buildFlashPlan(channel).steps;
  const avbIndex = steps.findIndex(
    (s) => s.kind === "flash" && s.artifact === "avb_pkmd.bin",
  );
  const osIndex = steps.findIndex((s) => s.kind === "flash" && s.phase === "os");
  assert.ok(avbIndex >= 0 && osIndex > avbIndex);
  const avb = steps[avbIndex];
  assert.equal(avb?.kind, "flash");
  if (avb?.kind === "flash") {
    assert.equal(avb.partition, "avb_custom_key");
    assert.equal(avb.phase, "avb_custom_key");
  }
});

test("firmware reconnect happens before AVB flash", () => {
  const { channel } = bundleFromBlobs(tokayBlobs());
  const steps = buildFlashPlan(channel).steps;
  const reconnect = steps.findIndex(
    (s) => s.kind === "reconnect" && s.phase === "firmware",
  );
  const avb = steps.findIndex(
    (s) => s.kind === "flash" && s.phase === "avb_custom_key",
  );
  assert.ok(reconnect >= 0 && avb > reconnect);
});
