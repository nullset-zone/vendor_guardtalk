import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { ChannelError, HashMismatchError, WrongProductError } from "../src/errors.js";
import { loadChannelFromTexts, verifyChannelAvbKey } from "../src/channel.js";
import { loadChannelFromDir } from "../src/channel-fs.js";
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

test("komodo channel loads when advertisedDevices includes komodo", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as Record<string, unknown>;
  manifest.product = "komodo";
  manifest.advertisedDevices = ["komodo"];
  manifest.sourceStamp = "komodo-20260915-063833";
  const bundle = loadChannelFromTexts({
    ...texts,
    manifestJson: JSON.stringify(manifest),
  });
  assert.equal(bundle.manifest.product, "komodo");
});

test("rango channel loads when advertisedDevices includes rango", () => {
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

test("shiba product in pointer-shaped channel is rejected", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as { product: string };
  manifest.product = "shiba";
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    WrongProductError,
  );
});

test("tegu product in pointer-shaped channel is rejected", () => {
  const texts = channelTextsFromBlobs(tokayBlobs());
  const manifest = JSON.parse(texts.manifestJson) as { product: string };
  manifest.product = "tegu";
  assert.throws(
    () =>
      loadChannelFromTexts({
        ...texts,
        manifestJson: JSON.stringify(manifest),
      }),
    WrongProductError,
  );
});

test("verifyChannelAvbKey and loadChannelFromDir fail closed on tampered or invalid avb_pkmd.bin", async () => {
  const blobs = tokayBlobs();
  const texts = channelTextsFromBlobs(blobs);
  const bundle = loadChannelFromTexts(texts);
  const realPkmd = readFileSync(
    join(import.meta.dirname, "..", "channels", "tokay", "avb_pkmd.bin"),
  );
  const pkmdBlob = blobs.find((b) => b.name === "avb_pkmd.bin");
  assert.ok(pkmdBlob);
  // Real AVB pkmd with matching manifest passes; fixture synthetic blob fails decodePkmd
  assert.throws(() => verifyChannelAvbKey(bundle, pkmdBlob.bytes), ChannelError);

  const tmp = mkdtempSync(join(tmpdir(), "gt-chan-avb-"));
  try {
    const channelDir = join(import.meta.dirname, "..", "channels", "tokay");
    writeFileSync(join(tmp, "manifest.json"), readFileSync(join(channelDir, "manifest.json")));
    writeFileSync(join(tmp, "SHA256SUMS"), readFileSync(join(channelDir, "SHA256SUMS")));
    writeFileSync(join(tmp, "files.txt"), readFileSync(join(channelDir, "files.txt")));
    writeFileSync(join(tmp, "avb_pkmd.bin"), realPkmd);
    const loaded = await loadChannelFromDir(tmp);
    assert.equal(loaded.manifest.product, "tokay");

    // Flip 1 byte in avb_pkmd.bin -> HashMismatchError
    const tampered = Buffer.from(realPkmd);
    tampered[0] = (tampered[0] ?? 0) ^ 0xff;
    writeFileSync(join(tmp, "avb_pkmd.bin"), tampered);
    await assert.rejects(() => loadChannelFromDir(tmp), HashMismatchError);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
});
