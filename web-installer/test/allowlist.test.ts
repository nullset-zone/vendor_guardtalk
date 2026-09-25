import assert from "node:assert/strict";
import { test } from "node:test";
import { assertAllowedProduct } from "../src/allowlist.js";
import { WrongProductError } from "../src/errors.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { ALLOWED_PRODUCTS } from "../src/types.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

test("tokay, akita, komodo, and rango are allowed", () => {
  assert.deepEqual([...ALLOWED_PRODUCTS], ["tokay", "akita", "komodo", "rango"]);
  assert.doesNotThrow(() => assertAllowedProduct("tokay"));
  assert.doesNotThrow(() => assertAllowedProduct("akita"));
  assert.doesNotThrow(() => assertAllowedProduct("komodo"));
  assert.doesNotThrow(() => assertAllowedProduct("rango"));
});

test("shiba, husky, caiman, tegu, comet, and empty product are rejected", () => {
  assert.throws(() => assertAllowedProduct("shiba"), WrongProductError);
  assert.throws(() => assertAllowedProduct("husky"), WrongProductError);
  assert.throws(() => assertAllowedProduct("caiman"), WrongProductError);
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
