import assert from "node:assert/strict";
import { test } from "node:test";
import { assertAllowedProduct } from "../src/allowlist.js";
import { WrongProductError } from "../src/errors.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

test("tokay, akita, and komodo are allowed", () => {
  assert.doesNotThrow(() => assertAllowedProduct("tokay"));
  assert.doesNotThrow(() => assertAllowedProduct("akita"));
  assert.doesNotThrow(() => assertAllowedProduct("komodo"));
});

test("rango is rejected", () => {
  assert.throws(() => assertAllowedProduct("rango"), WrongProductError);
});

test("shiba, husky, caiman, and empty product are rejected", () => {
  assert.throws(() => assertAllowedProduct("shiba"), WrongProductError);
  assert.throws(() => assertAllowedProduct("husky"), WrongProductError);
  assert.throws(() => assertAllowedProduct("caiman"), WrongProductError);
  assert.throws(() => assertAllowedProduct(""), WrongProductError);
});

test("rango manifest fails closed at channel load", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "rango";
  manifest.advertisedDevices = ["rango"];
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    WrongProductError,
  );
});
