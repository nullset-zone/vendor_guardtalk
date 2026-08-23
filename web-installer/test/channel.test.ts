import assert from "node:assert/strict";
import { test } from "node:test";
import { ChannelError, WrongProductError } from "../src/errors.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

test("loads matching manifest + SHA256SUMS + files.txt", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const bundle = loadChannelFromTexts(texts);
  assert.equal(bundle.manifest.product, "tokay");
  assert.equal(bundle.files.length, 5);
  assert.equal(bundle.sha256sums.size, 5);
  assert.ok(bundle.sha256sums.has("avb_pkmd.bin"));
});

test("refuses a factoryZip string (no invented install zip)", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.factoryZip = "tokay-install-000.zip";
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    ChannelError,
  );
});

test("SHA256SUMS vs manifest hash disagreement fails closed", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const badSums = texts.sha256sums.replace(
    /[a-f0-9]{64}  boot\.img/,
    `${"ab".repeat(32)}  boot.img`,
  );
  assert.throws(
    () => loadChannelFromTexts({ ...texts, sha256sums: badSums }),
    ChannelError,
  );
});

test("secret-shaped artifact names are rejected", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        filesTxt: `${texts.filesTxt}\nkey.pem  os  12`,
      }),
    ChannelError,
  );
});

test("akita channel loads when advertisedDevices includes akita", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "akita";
  manifest.advertisedDevices = ["akita"];
  manifest.sourceStamp = "akita-20260725-101434";
  const bundle = loadChannelFromTexts({
    ...texts,
    manifestJson: JSON.stringify(manifest),
  });
  assert.equal(bundle.manifest.product, "akita");
});

test("rango product in pointer-shaped channel is rejected", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as { product: string };
  manifest.product = "rango";
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    WrongProductError,
  );
});
