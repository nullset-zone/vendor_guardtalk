import assert from "node:assert/strict";
import { test } from "node:test";
import { HashMismatchError } from "../src/errors.js";
import { assertSha256Match, sha256Hex } from "../src/hash.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import { bundleFromBlobs, MockFastboot, tokayBlobs, utf8 } from "./helpers.js";

test("matching digest passes", () => {
  const data = utf8("public-avb-pkmd");
  assertSha256Match("avb_pkmd.bin", data, sha256Hex(data));
});

test("hash mismatch fails closed", () => {
  const data = utf8("public-avb-pkmd");
  const other = sha256Hex(utf8("tampered"));
  assert.throws(
    () => assertSha256Match("avb_pkmd.bin", data, other),
    HashMismatchError,
  );
});

test("executePlan fails closed when store bytes do not match SHA256SUMS", async () => {
  const blobs = tokayBlobs();
  const { channel } = bundleFromBlobs(blobs);
  const tampered = new Map(blobs.map((b) => [b.name, b.bytes]));
  tampered.set("boot.img", utf8("tampered-boot"));
  const store = {
    async read(name: string): Promise<Uint8Array> {
      const data = tampered.get(name);
      if (data === undefined) {
        throw new Error(name);
      }
      return data;
    },
  };
  const transport = new MockFastboot();
  transport.unlocked = "yes";
  const orch = new FlashOrchestrator({ transport, channel, store });
  await orch.connect();
  await orch.unlock();
  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => undefined }),
    HashMismatchError,
  );
  assert.equal(orch.isPlanComplete(), false);
});
