import assert from "node:assert/strict";
import { test } from "node:test";
import { HashMismatchError, LiveExecuteHoldError } from "../src/errors.js";
import { assertBlobSha256Match, sha256BlobHex, sha256Hex } from "../src/hash.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import {
  adaptAndroidFastboot,
  connectAndroidFastboot,
  type AndroidFastbootDevice,
} from "../src/transport.js";
import { LIVE_FLASH_CLAIMED, type ArtifactStore } from "../src/types.js";
import { bundleFromBlobs, tokayBlobs, utf8 } from "./helpers.js";

test("sha256BlobHex matches sha256Hex across block boundaries and rejects mismatch", async () => {
  for (const len of [0, 1, 55, 56, 63, 64, 65, 130, 4096]) {
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i += 1) {
      bytes[i] = (i * 31 + 7) & 0xff;
    }
    const blob = new Blob([bytes.subarray(0, Math.floor(len / 2)), bytes.subarray(Math.floor(len / 2))]);
    const expected = sha256Hex(bytes);
    assert.equal(await sha256BlobHex(blob), expected);
    await assertBlobSha256Match(`len-${len}`, blob, expected);
  }
  await assert.rejects(
    () => assertBlobSha256Match("tampered", new Blob([utf8("abc")]), sha256Hex(utf8("xyz"))),
    HashMismatchError,
  );
});

test("FlashOrchestrator streams readBlob -> flashBlob without calling read() when supported", async () => {
  const { channel: bundle, store: memStore } = bundleFromBlobs(tokayBlobs());
  const readCalls: string[] = [];
  const readBlobCalls: string[] = [];
  const flashedBlobs: Array<{ partition: string; size: number }> = [];

  const store: ArtifactStore = {
    async read(name: string): Promise<Uint8Array> {
      readCalls.push(name);
      throw new Error(`read() should not be called when readBlob+flashBlob exist (${name})`);
    },
    async readBlob(name: string): Promise<Blob> {
      readBlobCalls.push(name);
      const data = await memStore.read(name);
      return new Blob([new Uint8Array(data)]);
    },
  };

  const device: AndroidFastbootDevice = {
    async connect() {},
    async getVariable(name: string) {
      if (name === "product") return "tokay";
      if (name === "unlocked") return "yes";
      if (name === "current-slot") return "a";
      if (name === "snapshot-update-status") return "none";
      if (name === "is-userspace") return "yes";
      return null;
    },
    async runCommand() {
      return { text: "OKAY" };
    },
    async flashBlob(partition: string, blob: Blob) {
      flashedBlobs.push({ partition, size: blob.size });
    },
    async reboot(_mode?: string, _wait?: boolean, onReconnect?: () => Promise<void>) {
      if (onReconnect) await onReconnect();
    },
  };

  const transport = adaptAndroidFastboot(device);
  const orch = new FlashOrchestrator({ transport, channel: bundle, store });
  assert.equal(orch.claimsLiveFlash(), false);
  assert.equal(LIVE_FLASH_CLAIMED, false);

  await orch.connect();

  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => {} }),
    LiveExecuteHoldError,
  );

  await orch.executePlan({ onReconnect: async () => {}, allowLiveExecute: true });
  assert.equal(readCalls.length, 0);
  assert.ok(readBlobCalls.length > 0);
  assert.equal(flashedBlobs.length, readBlobCalls.length);
  assert.equal(orch.isPlanComplete(), true);

  await assert.rejects(
    () => orch.lock({ confirmed: true }),
    LiveExecuteHoldError,
  );
  await orch.lock({ confirmed: true, allowLiveLock: true, operatorOverride: true });
});

test("connectAndroidFastboot accepts pre-constructed device or moduleUrl", async () => {
  let connects = 0;
  const device: AndroidFastbootDevice = {
    async connect() {
      connects += 1;
    },
    async getVariable() {
      return "tokay";
    },
    async runCommand() {
      return { text: "OKAY" };
    },
    async flashBlob() {},
    async reboot() {},
  };

  const transport = await connectAndroidFastboot({ device });
  assert.equal(connects, 1);
  assert.equal(transport.dryRun, false);
  assert.equal(await transport.getVar("product"), "tokay");

  const moduleUrl = new URL(
    "../node_modules/android-fastboot/dist/fastboot.min.mjs",
    import.meta.url,
  ).href;
  const viaUrl = await connectAndroidFastboot({
    moduleUrl,
    module: {
      FastbootDevice: class implements AndroidFastbootDevice {
        async connect() { connects += 1; }
        async getVariable() { return "tokay"; }
        async runCommand() { return { text: "OKAY" }; }
        async flashBlob() {}
        async reboot() {}
      },
    },
  });
  assert.equal(connects, 2);
  assert.equal(viaUrl.dryRun, false);
});
