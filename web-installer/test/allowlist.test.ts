import assert from "node:assert/strict";
import { test } from "node:test";
import { assertAllowedProduct, STAGED_PRODUCTS } from "../src/allowlist.js";
import { WrongProductError } from "../src/errors.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

test("all 8 staged products are allowed", () => {
  assert.deepEqual([...STAGED_PRODUCTS], [
    "tokay",
    "akita",
    "komodo",
    "rango",
    "caiman",
    "frankel",
    "stallion",
    "blazer",
  ]);
  for (const product of STAGED_PRODUCTS) {
    assert.doesNotThrow(() => assertAllowedProduct(product));
  }
});

test("unstamped shiba, husky, tegu, comet, and empty product are rejected", () => {
  assert.throws(() => assertAllowedProduct("shiba"), WrongProductError);
  assert.throws(() => assertAllowedProduct("husky"), WrongProductError);
  assert.throws(() => assertAllowedProduct("tegu"), WrongProductError);
  assert.throws(() => assertAllowedProduct("comet"), WrongProductError);
  assert.throws(() => assertAllowedProduct(""), WrongProductError);
});

test("WrongProductError lists tokay, akita, komodo, rango", () => {
  assert.throws(
    () => assertAllowedProduct("shiba"),
    (err: unknown) =>
      err instanceof WrongProductError &&
      err.message.includes("tokay, akita, komodo, rango"),
  );
});

test("rango manifest loads when advertisedDevices includes rango", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "rango";
  manifest.advertisedDevices = ["rango"];
  manifest.sourceStamp = "rango-20260802-130756";
  const bundle = loadChannelFromTexts({
    ...texts,
    manifestJson: JSON.stringify(manifest),
  });
  assert.equal(bundle.manifest.product, "rango");
});

test("shiba manifest fails closed at channel load", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "shiba";
  manifest.advertisedDevices = ["shiba"];
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    WrongProductError,
  );
});
