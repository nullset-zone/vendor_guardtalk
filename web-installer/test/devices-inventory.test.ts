import assert from "node:assert/strict";
import { test } from "node:test";
import { assertAllowedProduct, assertManifestAllowlist } from "../src/allowlist.js";
import { ChannelError, WrongProductError } from "../src/errors.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import { KOMODO_STAMP_HONESTY, WIZARD_DEVICES } from "../lib/ui/offered-devices.js";
import { hostedChannelBase } from "../wizard/hosted-channel.js";
import { WizardGateError } from "../wizard/gating.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

test("LIVE_FLASH_CLAIMED stays false (inventory card does not claim live flash)", () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
});

test("DEC-010: advertised komodo stamp is not claimed FLASH_READY or user-signed", () => {
  assert.match(KOMODO_STAMP_HONESTY, /komodo-20260915-063833/);
  assert.match(KOMODO_STAMP_HONESTY, /not a signed user FLASH_READY image/);
  assert.match(KOMODO_STAMP_HONESTY, /LIVE_FLASH_CLAIMED=false/);
  assert.doesNotMatch(KOMODO_STAMP_HONESTY, /FLASH_READY=true/);
  assert.deepEqual(
    WIZARD_DEVICES.map((device) => device.id),
    ["tokay", "akita", "komodo", "rango"],
  );
});

test("case-folded and whitespace-only products are rejected", () => {
  assert.throws(() => assertAllowedProduct("Rango"), WrongProductError);
  assert.throws(() => assertAllowedProduct("TOKAY"), WrongProductError);
  assert.throws(() => assertAllowedProduct("   "), WrongProductError);
});

test("trimmed rango is accepted (allowlist trims)", () => {
  assert.doesNotThrow(() => assertAllowedProduct("  rango  "));
});

test("reservedProducts must not include an advertised device", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "rango";
  manifest.advertisedDevices = ["rango"];
  manifest.reservedProducts = ["rango"];
  manifest.sourceStamp = "rango-20260802-130756";
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    ChannelError,
  );
});

test("advertisedDevices must include manifest.product", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "rango";
  manifest.advertisedDevices = ["tokay"];
  manifest.sourceStamp = "rango-20260802-130756";
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    ChannelError,
  );
});

test("empty advertisedDevices fails closed", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.advertisedDevices = [];
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    ChannelError,
  );
});

test("assertManifestAllowlist rejects rango in reservedProducts", () => {
  assert.throws(
    () =>
      assertManifestAllowlist({
        schemaVersion: 1,
        product: "tokay",
        advertisedDevices: ["tokay"],
        reservedProducts: ["rango"],
        channel: "dev",
        bootState: "unlocked",
        channelLabel: "dev/unlocked",
        verifiedBootClaim: "none",
        releaseId: "x",
        unixEpoch: 1,
        sourceStamp: "tokay-20260725-102506",
        flashOrder: ["firmware", "avb_custom_key", "os"],
        factoryZip: null,
        avb: { publicKeyFile: "avb_pkmd.bin", sha256: "ab".repeat(32), size: 1 },
        artifacts: [],
        signature: { required: false, mode: "hash-only", file: null, allowedSigners: null },
      }),
    ChannelError,
  );
});

test("hosted channel URL rejects tegu and comet", () => {
  assert.throws(() => hostedChannelBase("tegu"), WizardGateError);
  assert.throws(() => hostedChannelBase("comet"), WizardGateError);
});

test("WrongProductError for husky lists the four advertised products", () => {
  assert.throws(
    () => assertAllowedProduct("husky"),
    (err: unknown) =>
      err instanceof WrongProductError &&
      err.message.includes("tokay, akita, komodo, rango") &&
      !err.message.includes("shiba"),
  );
});
