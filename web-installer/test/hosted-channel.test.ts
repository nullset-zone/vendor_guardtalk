import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { WizardGateError } from "../wizard/gating.js";
import { fetchHostedChannel, hostedChannelBase } from "../wizard/hosted-channel.js";
import { channelTextsFromBlobs, tokayBlobs } from "./helpers.js";

test("hosted channel URL is per staged product", () => {
  for (const product of [
    "tokay",
    "akita",
    "komodo",
    "rango",
    "caiman",
    "frankel",
    "stallion",
    "blazer",
  ]) {
    assert.equal(hostedChannelBase(product), `../channels/${product}/`);
  }
});

test("hosted channel URL rejects unstamped products", () => {
  assert.throws(() => hostedChannelBase("shiba"), WizardGateError);
  assert.throws(() => hostedChannelBase("tegu"), WizardGateError);
  assert.throws(() => hostedChannelBase("husky"), WizardGateError);
  assert.throws(() => hostedChannelBase("comet"), WizardGateError);
});

test("fetchHostedChannel verifies avb_pkmd.bin SHA-256 and AVB key fail-closed", async () => {
  const blobs = tokayBlobs();
  const realPkmd = new Uint8Array(
    readFileSync(join(import.meta.dirname, "..", "channels", "tokay", "avb_pkmd.bin")),
  );
  const pkmdEntry = blobs.find((b) => b.name === "avb_pkmd.bin");
  assert.ok(pkmdEntry);
  pkmdEntry.bytes = realPkmd;
  const texts = channelTextsFromBlobs(blobs);
  const pkmd = pkmdEntry.bytes;
  const origFetch = globalThis.fetch;
  try {
    globalThis.fetch = (async (input: string | URL | Request) => {
      const url = String(input);
      if (url.endsWith("/manifest.json")) return new Response(texts.manifestJson, { status: 200 });
      if (url.endsWith("/SHA256SUMS")) return new Response(texts.sha256sums, { status: 200 });
      if (url.endsWith("/files.txt")) return new Response(texts.filesTxt, { status: 200 });
      if (url.endsWith("/avb_pkmd.bin")) return new Response(pkmd, { status: 200 });
      return new Response("not found", { status: 404 });
    }) as typeof fetch;

    const ok = await fetchHostedChannel("tokay");
    assert.equal(ok.product, "tokay");

    // Tamper 1 byte of avb_pkmd.bin -> must fail closed
    const tampered = new Uint8Array(pkmd);
    tampered[0] = (tampered[0] ?? 0) ^ 0xff;
    globalThis.fetch = (async (input: string | URL | Request) => {
      const url = String(input);
      if (url.endsWith("/manifest.json")) return new Response(texts.manifestJson, { status: 200 });
      if (url.endsWith("/SHA256SUMS")) return new Response(texts.sha256sums, { status: 200 });
      if (url.endsWith("/files.txt")) return new Response(texts.filesTxt, { status: 200 });
      if (url.endsWith("/avb_pkmd.bin")) return new Response(tampered, { status: 200 });
      return new Response("not found", { status: 404 });
    }) as typeof fetch;

    await assert.rejects(() => fetchHostedChannel("tokay"));
  } finally {
    globalThis.fetch = origFetch;
  }
});
