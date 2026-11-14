import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { encodePkmd } from "../lib/avb/pkmd.js";
import { isAllowedProduct, STAGED_PRODUCTS } from "../src/allowlist.js";
import { loadChannelFromDir } from "../src/channel-fs.js";
import {
  loadChannelFromTexts,
  parseManifestJson,
  parseSha256Sums,
  verifyChannelAvbKey,
} from "../src/channel.js";
import {
  AdbError,
  ChannelError,
  FastbootError,
  HashMismatchError,
  LiveExecuteHoldError,
  LockBeforeCompleteError,
  LockCancelledError,
  LockSafetyError,
  PlanError,
  StorageQuotaError,
  UsbDisconnectError,
  UsbPermissionError,
  UsbTimeoutError,
  WrongProductError,
} from "../src/errors.js";
import { sha256Hex } from "../src/hash.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import { buildFlashPlan } from "../src/plan.js";
import { MemoryArtifactStore } from "../src/store.js";
import {
  adaptAndroidFastboot,
  classifyUsbError,
  type AndroidFastbootDevice,
} from "../src/transport.js";
import {
  LIVE_FLASH_CLAIMED,
  PRODUCTION_RELEASE_CLAIMED,
  type FastbootTransport,
  type FlashOptions,
  type ReconnectHook,
} from "../src/types.js";
import { rebootAndroidToBootloader } from "../wizard/adb-reboot.js";
import { HttpArtifactStore, OpfsArtifactStore, type OpfsDirectoryHandle } from "../wizard/http-store.js";
import { assessQuota, assertStorageQuotaForBytes } from "../wizard/quota.js";
import { bundleFromBlobs, channelTextsFromBlobs, tokayBlobs, utf8, type FixtureBlob } from "./helpers.js";

const HERE = dirname(fileURLToPath(import.meta.url));
const WEB_INSTALLER_ROOT = resolve(HERE, "..");

const EIGHT_STAGED = [
  "tokay",
  "akita",
  "komodo",
  "rango",
  "caiman",
  "frankel",
  "stallion",
  "blazer",
] as const;

function makeTestRsa4096Pkmd(): Uint8Array {
  // Deterministic odd 4096-bit modulus (high bit set, low bit set) for codec/hash tests.
  const n = (1n << 4095n) | 0x123456789abcdef1n;
  return encodePkmd({ n, e: 65537n });
}

function makeMockTransport(opts: {
  dryRun?: boolean;
  vars?: Record<string, string | (() => string)>;
  commandResult?: (cmd: string) => { ok: boolean; text?: string };
  onFlash?: (partition: string, data: Uint8Array, options?: FlashOptions) => void;
  onWipeSuper?: (data: Uint8Array) => void;
  onClose?: () => Promise<void> | void;
  supportFastbootd?: boolean;
}): FastbootTransport {
  const vars = opts.vars ?? {};
  const transport: FastbootTransport = {
    ...(opts.dryRun !== undefined ? { dryRun: opts.dryRun } : {}),
    connect: async () => undefined,
    getVar: async (name: string) => {
      const entry = vars[name];
      if (typeof entry === "function") {
        return entry();
      }
      if (entry !== undefined) {
        return entry;
      }
      if (name === "snapshot-update-status") {
        return "none";
      }
      if (name === "is-userspace") {
        return "yes";
      }
      return "unknown";
    },
    runCommand: async (command: string) => {
      if (opts.commandResult) {
        return opts.commandResult(command);
      }
      return { ok: true };
    },
    flash: async (partition: string, data: Uint8Array, options?: FlashOptions) => {
      opts.onFlash?.(partition, data, options);
    },
    rebootBootloader: async (onReconnect: ReconnectHook) => {
      await onReconnect();
    },
    ...(opts.supportFastbootd !== false
      ? {
          rebootFastboot: async (onReconnect: ReconnectHook) => {
            await onReconnect();
          },
        }
      : {}),
    wipeSuper: async (data: Uint8Array) => {
      opts.onWipeSuper?.(data);
    },
    ...(opts.onClose
      ? {
          close: async () => {
            await opts.onClose?.();
          },
        }
      : {}),
  };
  return transport;
}

// ---------------------------------------------------------------------------
// 1. Corrupt SHA-256 / tampered avb_pkmd.bin / truncated manifest (fail-closed)
// ---------------------------------------------------------------------------

test("QA-1a: corrupt artifact SHA-256 fails closed BEFORE transport.flash is called", async () => {
  const blobs = tokayBlobs();
  const { channel } = bundleFromBlobs(blobs);
  // Tamper boot.img bytes in the store (1-byte flip) without updating SHA256SUMS.
  const tamperedMap = new Map(blobs.map((b) => [b.name, new Uint8Array(b.bytes)]));
  const bootBytes = tamperedMap.get("boot.img");
  assert.ok(bootBytes);
  bootBytes[0] = bootBytes[0]! ^ 0xff;
  const store = new MemoryArtifactStore(tamperedMap);

  const flashed: string[] = [];
  const transport = makeMockTransport({
    dryRun: true,
    vars: { product: "tokay", unlocked: "yes" },
    onFlash: (partition) => flashed.push(partition),
  });

  const orch = new FlashOrchestrator({ transport, channel, store });
  await orch.connect();
  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => undefined }),
    (err: unknown) => err instanceof HashMismatchError && err.code === "HASH_MISMATCH",
  );
  assert.equal(flashed.includes("boot"), false, "corrupt boot.img must never reach transport.flash");
  assert.equal(orch.isPlanComplete(), false);
});

test("QA-1b: tampered avb_pkmd.bin fails verifyChannelAvbKey even with matching length or recomputed SHA", () => {
  const pkmd = makeTestRsa4096Pkmd();
  const blobs: FixtureBlob[] = [
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: pkmd },
    { name: "boot.img", phase: "os", bytes: utf8("boot") },
  ];
  const { channel } = bundleFromBlobs(blobs);

  // Positive control: valid RSA-4096 PKMD passes.
  verifyChannelAvbKey(channel, pkmd);

  // Negative control 1: 1-byte flip in modulus/n0inv fails SHA-256 check.
  const flipped = new Uint8Array(pkmd);
  flipped[10] = flipped[10]! ^ 0x01;
  assert.throws(
    () => verifyChannelAvbKey(channel, flipped),
    (err: unknown) => err instanceof HashMismatchError,
  );

  // Negative control 2: truncated avb_pkmd.bin fails size check.
  assert.throws(
    () => verifyChannelAvbKey(channel, pkmd.subarray(0, 16)),
    (err: unknown) => err instanceof ChannelError && err.code === "CHANNEL_INVALID",
  );

  // Negative control 3: corrupted n0inv WITH recomputed SHA-256 still fails decodePkmd structural check.
  const badStruct = new Uint8Array(pkmd);
  badStruct[4] = badStruct[4]! ^ 0xff;
  const { channel: recomputedChannel } = bundleFromBlobs([
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: badStruct },
    { name: "boot.img", phase: "os", bytes: utf8("boot") },
  ]);
  assert.throws(
    () => verifyChannelAvbKey(recomputedChannel, badStruct),
    (err: unknown) => err instanceof ChannelError && /invalid avb_pkmd\.bin public key/.test(err.message),
  );
});

test("QA-1c: truncated manifest, path traversal, secret file, and honesty-claim tampering fail closed", () => {
  const { manifestJson, sha256sums, filesTxt } = channelTextsFromBlobs(tokayBlobs());

  // Truncated JSON
  assert.throws(
    () => parseManifestJson(manifestJson.slice(0, Math.floor(manifestJson.length / 2))),
    (err: unknown) => err instanceof ChannelError,
  );

  // Empty SHA256SUMS
  assert.throws(
    () => parseSha256Sums("   \n# comment only\n"),
    (err: unknown) => err instanceof ChannelError,
  );

  // Path traversal in SHA256SUMS
  const dummyHash = sha256Hex(utf8("x"));
  assert.throws(
    () => parseSha256Sums(`${dummyHash}  ../etc/passwd`),
    (err: unknown) => err instanceof ChannelError,
  );

  // Secret-shaped artifact (.pem / .pk8)
  assert.throws(
    () => parseSha256Sums(`${dummyHash}  avb.pem`),
    (err: unknown) => err instanceof ChannelError,
  );
  assert.throws(
    () => parseSha256Sums(`${dummyHash}  releasekey.pk8`),
    (err: unknown) => err instanceof ChannelError,
  );

  // Tampered verifiedBootClaim !== "none"
  const parsed = JSON.parse(manifestJson) as Record<string, unknown>;
  parsed.verifiedBootClaim = "green";
  assert.throws(
    () => loadChannelFromTexts({ manifestJson: JSON.stringify(parsed), sha256sums, filesTxt }),
    (err: unknown) => err instanceof ChannelError && /verifiedBootClaim/.test(err.message),
  );
});

// ---------------------------------------------------------------------------
// 2. Mismatched device codename (getvar product) rejection
// ---------------------------------------------------------------------------

test("QA-2: mismatched or unstamped getvar product rejects, tears down transport, and blocks mid-session swap", async () => {
  const { channel, store } = bundleFromBlobs(tokayBlobs());

  // Unstamped/unknown device 'shiba'
  let closedCount = 0;
  const shibaTransport = makeMockTransport({
    dryRun: true,
    vars: { product: "shiba" },
    onClose: () => {
      closedCount += 1;
    },
  });
  const shibaOrch = new FlashOrchestrator({ transport: shibaTransport, channel, store });
  await assert.rejects(
    () => shibaOrch.connect(),
    (err: unknown) => err instanceof WrongProductError && err.code === "WRONG_PRODUCT",
  );
  assert.equal(closedCount, 1, "failed connect() must tear down transport");
  await assert.rejects(() => shibaOrch.getCurrentSlot(), (err: unknown) => err instanceof FastbootError);

  // Valid staged device 'akita' connected against 'tokay' channel
  let akitaClosed = 0;
  const akitaTransport = makeMockTransport({
    dryRun: true,
    vars: { product: "akita" },
    onClose: () => {
      akitaClosed += 1;
    },
  });
  const akitaOrch = new FlashOrchestrator({ transport: akitaTransport, channel, store });
  await assert.rejects(() => akitaOrch.connect(), WrongProductError);
  assert.equal(akitaClosed, 1);

  // Mid-session product swap attack: connect sees tokay, executePlan sees komodo
  let calls = 0;
  const flashed: string[] = [];
  const swapTransport = makeMockTransport({
    dryRun: true,
    vars: {
      product: () => {
        calls += 1;
        return calls === 1 ? "tokay" : "komodo";
      },
    },
    onFlash: (p) => flashed.push(p),
  });
  const swapOrch = new FlashOrchestrator({ transport: swapTransport, channel, store });
  await swapOrch.connect();
  await assert.rejects(
    () => swapOrch.executePlan({ onReconnect: async () => undefined }),
    WrongProductError,
  );
  assert.equal(flashed.length, 0, "mid-session product swap must abort before flashing");
});

// ---------------------------------------------------------------------------
// 3. USB disconnect, timeout, permission-loss + ADB timeout + fastbootd gate
// ---------------------------------------------------------------------------

test("QA-3a: classifyUsbError and adaptAndroidFastboot map disconnect, timeout, and permission loss", async () => {
  const netErr = Object.assign(new Error("USB transfer error"), { name: "NetworkError" });
  const permErr = Object.assign(new Error("Access denied"), { name: "SecurityError" });
  const timeErr = Object.assign(new Error("Request timed out"), { name: "TimeoutError" });

  assert.ok(classifyUsbError(netErr, "flash boot") instanceof UsbDisconnectError);
  assert.ok(classifyUsbError(permErr, "connect") instanceof UsbPermissionError);
  assert.ok(classifyUsbError(timeErr, "getvar product") instanceof UsbTimeoutError);

  // Timeout on hanging getVariable
  const hangingDevice: AndroidFastbootDevice = {
    connect: async () => undefined,
    getVariable: () => new Promise<string | null>(() => undefined),
    runCommand: async () => ({ text: "" }),
    flashBlob: async () => undefined,
    reboot: () => new Promise<void>(() => undefined),
  };
  const transport = adaptAndroidFastboot(hangingDevice, {
    commandTimeoutMs: 25,
    rebootTimeoutMs: 25,
  });
  await assert.rejects(
    () => transport.getVar("product"),
    (err: unknown) => err instanceof UsbTimeoutError && err.code === "USB_TIMEOUT" && err.recoverable === true,
  );
  await assert.rejects(
    () => transport.rebootBootloader(async () => undefined),
    (err: unknown) => err instanceof UsbTimeoutError && err.code === "USB_TIMEOUT",
  );
});

test("QA-3b: ADB rebootAndroidToBootloader aborts & closes pipe on timeout without handle leak", async () => {
  let closed = false;
  await assert.rejects(
    () =>
      rebootAndroidToBootloader({
        io: {
          readChunk: () => new Promise<Uint8Array>(() => undefined),
          write: async () => undefined,
          close: async () => {
            closed = true;
          },
        },
        timeoutMs: 25,
      }),
    (err: unknown) => err instanceof AdbError,
  );
  assert.equal(closed, true, "ADB pipe.close() must run on timeout");
});

test("QA-3c: fastbootd gate refuses logical flashing when is-userspace !== 'yes'", async () => {
  const caimanBlobs: FixtureBlob[] = [
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("pkmd") },
    { name: "boot.img", phase: "os", bytes: utf8("boot") },
    { name: "super_empty.img", phase: "os", bytes: utf8("super-empty") },
    { name: "system.img", phase: "os", bytes: utf8("system") },
  ];
  const { channel, store } = bundleFromBlobs(caimanBlobs, {
    product: "caiman",
    advertisedDevices: ["caiman"],
  });

  const flashed: string[] = [];
  const badFastbootdTransport = makeMockTransport({
    dryRun: true,
    vars: { product: "caiman", "is-userspace": "no" },
    onFlash: (p) => flashed.push(p),
  });
  const orch = new FlashOrchestrator({
    transport: badFastbootdTransport,
    channel,
    store,
    planOptions: { allowExtendedProduct: true },
  });
  await orch.connect();
  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => undefined }),
    (err: unknown) => err instanceof FastbootError && /is-userspace=yes/.test(err.message),
  );
  assert.equal(flashed.includes("system"), false, "logical partition must not flash if is-userspace != yes");
});

// ---------------------------------------------------------------------------
// 4. Storage quota exhaustion & OPFS maxInMemoryBytes OOM guard
// ---------------------------------------------------------------------------

test("QA-4: quota exhaustion, private-mode heuristic, and OPFS/HttpArtifactStore OOM guard", async () => {
  const files = [{ size: 900 * 1024 * 1024 }];
  const lowAssessment = assessQuota(files, { quota: 400 * 1024 * 1024, usage: 50 * 1024 * 1024 });
  assert.equal(lowAssessment.lowQuota, true);
  assert.equal(lowAssessment.likelyPrivateMode, true);

  assert.throws(
    () => assertStorageQuotaForBytes(500 * 1024 * 1024, { quota: 400 * 1024 * 1024, usage: 0 }, "super.img"),
    (err: unknown) => err instanceof StorageQuotaError && err.code === "STORAGE_QUOTA_EXCEEDED",
  );

  // HttpArtifactStore: rejects chunked stream exceeding maxInMemoryBytes even without Content-Length
  const origFetch = globalThis.fetch;
  try {
    globalThis.fetch = async () =>
      new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new Uint8Array(64));
            controller.enqueue(new Uint8Array(64));
            controller.close();
          },
        }),
        { status: 200 },
      );
    const http = new HttpArtifactStore("https://example.invalid/ch/", { maxInMemoryBytes: 100 });
    await assert.rejects(
      () => http.read("boot.img"),
      (err: unknown) => err instanceof StorageQuotaError && err.code === "STORAGE_QUOTA_EXCEEDED",
    );

    // OpfsArtifactStore: aborts writable when stream errors mid-transfer
    let aborted = false;
    let closed = false;
    globalThis.fetch = async () =>
      new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new Uint8Array(16));
            controller.error(new Error("network drop"));
          },
        }),
        { status: 200, headers: { "content-length": "32" } },
      );
    const dir: OpfsDirectoryHandle = {
      getFileHandle: async () => ({
        createWritable: async () => ({
          write: async () => undefined,
          close: async () => {
            closed = true;
          },
          abort: async () => {
            aborted = true;
          },
        }),
        getFile: async () => ({ arrayBuffer: async () => new ArrayBuffer(0) }),
      }),
    };
    const opfs = new OpfsArtifactStore("https://example.invalid/ch/", dir);
    await assert.rejects(() => opfs.stageToOpfs("super.img"), /network drop/);
    assert.equal(aborted, true, "OPFS writable must abort on stream error");
    assert.equal(closed, false, "OPFS writable must not close on stream error");
  } finally {
    globalThis.fetch = origFetch;
  }
});

// ---------------------------------------------------------------------------
// 5. hybrid vs gt plan matrix + --slot=other + safety-gated flashing lock
// ---------------------------------------------------------------------------

test("QA-5a: hybrid (frankel/rango/blazer) vs gt (caiman/stallion) plan matrix & --slot=other", () => {
  for (const gtProd of ["caiman", "stallion"] as const) {
    const blobs: FixtureBlob[] = [
      { name: "bootloader.img", phase: "firmware", bytes: utf8("bl") },
      { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("pkmd") },
      { name: "super_empty.img", phase: "os", bytes: utf8("se") },
      { name: "system.img", phase: "os", bytes: utf8("sys") },
      { name: "boot.img", phase: "os", bytes: utf8("boot") },
    ];
    const { channel } = bundleFromBlobs(blobs, {
      product: gtProd,
      advertisedDevices: [gtProd],
    });
    const plan = buildFlashPlan(channel, {
      bootChain: "gt",
      bootloaderDualSlot: true,
      allowExtendedProduct: true,
    });
    assert.equal(plan.superMode, "super_empty");
    const slotOtherCount = plan.steps.filter(
      (s) => s.kind === "flash" && s.partition === "bootloader" && s.slot === "other",
    ).length;
    assert.equal(slotOtherCount, 2, `${gtProd} must perform 2-pass --slot=other bootloader dance`);
    assert.ok(plan.steps.some((s) => s.kind === "wipe-super"));
    assert.ok(plan.steps.some((s) => s.kind === "reboot-fastboot"));
    assert.ok(plan.steps.some((s) => s.kind === "erase" && s.partition === "fips"));
  }

  for (const hybridProd of ["frankel", "rango", "blazer"] as const) {
    const blobs: FixtureBlob[] = [
      { name: "bootloader.img", phase: "firmware", bytes: utf8("bl") },
      { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("pkmd") },
      { name: "boot.img", phase: "os", bytes: utf8("boot") },
      { name: "init_boot.img", phase: "os", bytes: utf8("init") },
      { name: "super.img", phase: "os", bytes: utf8("super") },
    ];
    const { channel } = bundleFromBlobs(blobs, {
      product: hybridProd,
      advertisedDevices: [hybridProd],
    });
    const plan = buildFlashPlan(channel, {
      bootChain: "hybrid",
      rescueBootArtifacts: ["boot.img", "init_boot.img"],
      allowExtendedProduct: true,
    });
    assert.equal(plan.bootChain, "hybrid");
    assert.equal(plan.superMode, "super");
    assert.equal(
      plan.steps.some((s) => s.kind === "erase" && s.partition === "fips"),
      false,
      `${hybridProd} must omit fips erase`,
    );
    const bootIdx = plan.steps.findIndex((s) => s.kind === "flash" && s.artifact === "boot.img");
    const superIdx = plan.steps.findIndex((s) => s.kind === "flash" && s.artifact === "super.img");
    assert.ok(bootIdx >= 0 && superIdx > bootIdx, "rescue boot must precede super.img");
  }

  // Negative control: hybrid missing rescue artifact throws PlanError
  const { channel: badHybrid } = bundleFromBlobs(
    [
      ...tokayBlobs(),
      { name: "super.img", phase: "os", bytes: utf8("super") },
    ],
    {
      product: "rango",
      advertisedDevices: ["rango"],
    },
  );
  assert.throws(
    () => buildFlashPlan(badHybrid, { bootChain: "hybrid", rescueBootArtifacts: ["init_boot.img"] }),
    (err: unknown) => err instanceof PlanError && err.code === "PLAN_INVALID",
  );
});

test("QA-5b: flashing lock safety gate & DEC-009 live-execute HOLD reject all bypass attempts", async () => {
  const { channel, store } = bundleFromBlobs(tokayBlobs());

  // Live transport without allowLiveExecute -> LiveExecuteHoldError
  const liveTransport = makeMockTransport({
    dryRun: false,
    vars: { product: "tokay", unlocked: "yes" },
  });
  const liveOrch = new FlashOrchestrator({ transport: liveTransport, channel, store });
  await liveOrch.connect();
  await assert.rejects(
    () => liveOrch.executePlan({ onReconnect: async () => undefined }),
    (err: unknown) => err instanceof LiveExecuteHoldError && err.code === "LIVE_EXECUTE_HOLD",
  );

  // Lock before plan complete -> LockBeforeCompleteError
  await assert.rejects(
    () => liveOrch.lock({ allowLiveLock: true, confirmed: true, operatorOverride: true }),
    (err: unknown) => err instanceof LockBeforeCompleteError && err.code === "LOCK_BEFORE_COMPLETE",
  );

  // Execute with explicit live opt-in, then test lock bypasses
  await liveOrch.executePlan({ onReconnect: async () => undefined, allowLiveExecute: true });

  // Missing allowLiveLock -> LiveExecuteHoldError
  await assert.rejects(
    () => liveOrch.lock({ confirmed: true, operatorOverride: true }),
    LiveExecuteHoldError,
  );
  // Missing confirmed: true -> LockSafetyError
  await assert.rejects(
    () => liveOrch.lock({ allowLiveLock: true, operatorOverride: true }),
    (err: unknown) => err instanceof LockSafetyError && err.code === "LOCK_SAFETY_GATE",
  );
  // Missing operatorOverride: true on dev/unlocked target -> LockSafetyError
  await assert.rejects(
    () => liveOrch.lock({ allowLiveLock: true, confirmed: true }),
    (err: unknown) => err instanceof LockSafetyError && err.code === "LOCK_SAFETY_GATE",
  );

  // Device cancels flashing lock -> LockCancelledError
  const cancelTransport = makeMockTransport({
    dryRun: false,
    vars: { product: "tokay", unlocked: "yes" },
    commandResult: (cmd) => (cmd === "flashing lock" ? { ok: false } : { ok: true }),
  });
  const cancelOrch = new FlashOrchestrator({ transport: cancelTransport, channel, store });
  await cancelOrch.connect();
  await cancelOrch.executePlan({ onReconnect: async () => undefined, allowLiveExecute: true });
  await assert.rejects(
    () => cancelOrch.lock({ allowLiveLock: true, confirmed: true, operatorOverride: true }),
    LockCancelledError,
  );
});

// ---------------------------------------------------------------------------
// 6. All 8 packed channels on disk + Law 7 honesty flags
// ---------------------------------------------------------------------------

test("QA-6: all 8 staged devices have valid packed channels on disk and Law 7 honesty holds", async () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
  assert.equal(PRODUCTION_RELEASE_CLAIMED, false);
  assert.deepEqual([...STAGED_PRODUCTS].sort(), [...EIGHT_STAGED].sort());
  assert.equal(isAllowedProduct("shiba"), false);

  const statusRaw = JSON.parse(
    readFileSync(join(WEB_INSTALLER_ROOT, "status.json"), "utf8"),
  ) as { flashCapability?: { liveFlashClaimed?: boolean } };
  assert.equal(statusRaw.flashCapability?.liveFlashClaimed, false);

  for (const product of EIGHT_STAGED) {
    const channelDir = join(WEB_INSTALLER_ROOT, "channels", product);
    assert.equal(existsSync(channelDir), true, `missing channel dir for ${product}`);

    // No secret-shaped files in channel dir
    const entries = readdirSync(channelDir);
    for (const entry of entries) {
      assert.equal(/\.(pem|pk8)$/i.test(entry), false, `secret file found in ${product}: ${entry}`);
    }

    const bundle = await loadChannelFromDir(channelDir);
    assert.equal(bundle.manifest.product, product);
    assert.equal(bundle.manifest.verifiedBootClaim, "none");
    assert.equal(bundle.manifest.channelLabel, "dev/unlocked");
  }
});
