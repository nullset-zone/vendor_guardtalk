import assert from "node:assert/strict";
import { test } from "node:test";
import {
  AdbError,
  FastbootError,
  LiveExecuteHoldError,
  LockSafetyError,
  StorageQuotaError,
  UsbDisconnectError,
  UsbPermissionError,
  UsbTimeoutError,
} from "../src/errors.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import { buildFlashPlan } from "../src/plan.js";
import {
  adaptAndroidFastboot,
  classifyUsbError,
  type AndroidFastbootDevice,
} from "../src/transport.js";
import {
  LIVE_FLASH_CLAIMED,
  type CommandResult,
  type FastbootTransport,
  type FlashOptions,
  type ReconnectHook,
} from "../src/types.js";
import { openAdbUsb, type UsbDeviceHandle, type UsbPicker } from "../wizard/adb-usb.js";
import {
  HttpArtifactStore,
  OpfsArtifactStore,
  type OpfsDirectoryHandle,
  type OpfsFileHandle,
} from "../wizard/http-store.js";
import { assessQuota, assertStorageQuotaForBytes } from "../wizard/quota.js";
import { bundleFromBlobs, utf8, type FixtureBlob } from "./helpers.js";

class RecordingLiveDevice implements AndroidFastbootDevice {
  readonly calls: string[] = [];
  isUserspace = "no";
  currentSlot = "a";
  unlocked = "yes";
  product = "caiman";

  async connect(): Promise<void> {
    this.calls.push("connect");
  }

  async getVariable(name: string): Promise<string | null> {
    this.calls.push(`getvar:${name}`);
    if (name === "product") return this.product;
    if (name === "current-slot") return this.currentSlot;
    if (name === "unlocked") return this.unlocked;
    if (name === "is-userspace") return this.isUserspace;
    if (name === "snapshot-update-status") return "none";
    return null;
  }

  async runCommand(command: string): Promise<{ text: string }> {
    this.calls.push(`cmd:${command}`);
    return { text: "OKAY" };
  }

  async flashBlob(partition: string, _blob: Blob): Promise<void> {
    this.calls.push(`flash:${partition}`);
  }

  async upload(_blob: Blob): Promise<void> {
    this.calls.push("upload");
  }

  async reboot(mode?: string, _wait?: boolean, onReconnect?: ReconnectHook): Promise<void> {
    this.calls.push(`reboot:${mode ?? ""}`);
    if (mode === "fastboot") {
      this.isUserspace = "yes";
    } else if (mode === "bootloader") {
      this.isUserspace = "no";
    }
    await onReconnect?.();
  }
}

test("LIVE_FLASH_CLAIMED remains false (Law 7 honesty)", () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
});

test("classifyUsbError maps disconnect, timeout, and permission-loss explicitly", () => {
  const disc = classifyUsbError(new DOMException("device lost", "NetworkError"), "getvar");
  assert.ok(disc instanceof UsbDisconnectError);
  assert.ok(disc instanceof FastbootError);
  assert.equal(disc.code, "USB_DISCONNECTED");
  assert.equal(disc.recoverable, true);

  const tout = classifyUsbError(new DOMException("timed out", "AbortError"), "reboot");
  assert.ok(tout instanceof UsbTimeoutError);
  assert.equal(tout.code, "USB_TIMEOUT");

  const perm = classifyUsbError(new DOMException("denied", "SecurityError"), "connect");
  assert.ok(perm instanceof UsbPermissionError);
  assert.equal(perm.code, "USB_PERMISSION_LOST");
});

test("adaptAndroidFastboot handles getvar current-slot, rebootFastboot, wipeSuper, and USB timeout", async () => {
  const dev = new RecordingLiveDevice();
  const transport = adaptAndroidFastboot(dev, { commandTimeoutMs: 500 });
  await transport.connect();
  assert.equal(await transport.getVar("product"), "caiman");
  assert.equal(await transport.getVar("current-slot"), "a");
  assert.equal(await transport.getVar("unlocked"), "yes");

  await transport.wipeSuper?.(utf8("super-empty"));
  await transport.rebootFastboot?.(async () => undefined);
  assert.equal(await transport.getVar("is-userspace"), "yes");
  assert.ok(dev.calls.includes("upload"));
  assert.ok(dev.calls.includes("cmd:update-super:super:wipe"));
  assert.ok(dev.calls.includes("reboot:fastboot"));

  const hangingDev: AndroidFastbootDevice = {
    connect: () => new Promise(() => undefined),
    getVariable: () => new Promise(() => undefined),
    runCommand: () => new Promise(() => undefined),
    flashBlob: () => Promise.resolve(),
    reboot: () => new Promise(() => undefined),
  };
  const slowTransport = adaptAndroidFastboot(hangingDev, { commandTimeoutMs: 25 });
  await assert.rejects(() => slowTransport.getVar("product"), UsbTimeoutError);
});

test("openAdbUsb closes device on claimInterface failure and classifies SecurityError", async () => {
  let closed = false;
  const fakeDevice: UsbDeviceHandle = {
    configurations: [
      {
        configurationValue: 1,
        interfaces: [
          {
            interfaceNumber: 0,
            alternates: [
              {
                interfaceClass: 255,
                interfaceSubclass: 66,
                interfaceProtocol: 1,
                endpoints: [
                  { direction: "in", type: "bulk", endpointNumber: 1 },
                  { direction: "out", type: "bulk", endpointNumber: 2 },
                ],
              },
            ],
          },
        ],
      },
    ],
    configuration: null,
    open: async () => undefined,
    selectConfiguration: async () => undefined,
    claimInterface: async () => {
      throw new DOMException("busy", "SecurityError");
    },
    releaseInterface: async () => undefined,
    close: async () => {
      closed = true;
    },
    transferOut: async () => ({ status: "ok" }),
    transferIn: async () => ({ status: "ok", data: new DataView(new ArrayBuffer(0)) }),
  };

  const picker: UsbPicker = {
    requestDevice: async () => fakeDevice,
  };
  await assert.rejects(() => openAdbUsb(picker), AdbError);
  assert.equal(closed, true);

  const deniedPicker: UsbPicker = {
    requestDevice: async () => {
      throw new DOMException("denied", "NotAllowedError");
    },
  };
  await assert.rejects(
    () => openAdbUsb(deniedPicker),
    (err: unknown) => err instanceof AdbError && /permission/i.test(err.message),
  );
});

test("plan + orchestrator: super_empty.img + fastbootd logical partitions + --slot=other dance (caiman)", async () => {
  const blobs: FixtureBlob[] = [
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl-caiman") },
    { name: "radio.img", phase: "firmware", bytes: utf8("radio-caiman") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("pkmd-caiman") },
    { name: "super_empty.img", phase: "os", bytes: utf8("super-empty-caiman") },
    { name: "system.img", phase: "os", bytes: utf8("sys-caiman") },
    { name: "vendor.img", phase: "os", bytes: utf8("ven-caiman") },
    { name: "boot.img", phase: "os", bytes: utf8("boot-caiman") },
    { name: "vbmeta.img", phase: "os", bytes: utf8("vbmeta-caiman") },
  ];
  const { channel, store } = bundleFromBlobs(blobs, {
    product: "caiman",
    advertisedDevices: ["caiman"],
    sourceStamp: "caiman-20261113-135738",
  });
  const plan = buildFlashPlan(channel, {
    bootloaderDualSlot: true,
    allowExtendedProduct: true,
  });
  assert.equal(plan.superMode, "super_empty");
  assert.equal(plan.bootloaderDualSlot, true);

  const dev = new RecordingLiveDevice();
  dev.product = "caiman";
  const transport = adaptAndroidFastboot(dev);
  const orch = new FlashOrchestrator({
    transport,
    channel,
    store,
    planOptions: { bootloaderDualSlot: true, allowExtendedProduct: true },
  });
  await orch.connect();

  // DEC-009: still blocked without allowLiveExecute
  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => undefined }),
    LiveExecuteHoldError,
  );

  // With explicit allowLiveExecute: runs full --slot=other, fips erase, wipe-super, fastbootd, logicals, boot, vbmeta
  await orch.executePlan({
    onReconnect: async () => undefined,
    allowLiveExecute: true,
  });
  assert.equal(orch.isPlanComplete(), true);
  assert.equal(dev.calls.filter((c) => c === "flash:bootloader:other").length, 2);
  assert.equal(dev.calls.filter((c) => c === "cmd:set_active:other").length, 2);
  assert.ok(dev.calls.includes("cmd:erase:fips"));
  assert.ok(dev.calls.includes("cmd:update-super:super:wipe"));
  assert.ok(dev.calls.includes("reboot:fastboot"));
  const fastbootIdx = dev.calls.indexOf("reboot:fastboot");
  const systemIdx = dev.calls.indexOf("flash:system");
  const bootIdx = dev.calls.indexOf("flash:boot");
  assert.ok(fastbootIdx >= 0 && systemIdx > fastbootIdx && bootIdx > systemIdx);
});

test("plan: hybrid rescue-boot + super.img for frankel omits fips erase", () => {
  const blobs: FixtureBlob[] = [
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl-frankel") },
    { name: "radio.img", phase: "firmware", bytes: utf8("radio-frankel") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("pkmd-frankel") },
    { name: "super.img", phase: "os", bytes: utf8("super-frankel") },
    { name: "boot.img", phase: "os", bytes: utf8("boot-frankel") },
    { name: "vbmeta.img", phase: "os", bytes: utf8("vbmeta-frankel") },
  ];
  const { channel } = bundleFromBlobs(blobs, {
    product: "frankel",
    advertisedDevices: ["frankel"],
    sourceStamp: "frankel-20261113-113011",
  });
  const plan = buildFlashPlan(channel, {
    bootChain: "hybrid",
    rescueBootArtifacts: ["boot.img"],
    allowExtendedProduct: true,
  });
  assert.equal(plan.bootChain, "hybrid");
  assert.equal(plan.superMode, "super");
  assert.equal(
    plan.steps.some((s) => s.kind === "erase" && s.partition === "fips"),
    false,
    "laguna (frankel/rango/blazer) must not erase fips",
  );
  assert.ok(plan.steps.some((s) => s.kind === "reboot-fastboot"));
  assert.ok(plan.steps.some((s) => s.kind === "flash" && s.partition === "super"));
});

test("flashing lock safety gate requires confirmation and blocks unverified targets without override", async () => {
  const blobs: FixtureBlob[] = [
    { name: "bootloader.img", phase: "firmware", bytes: utf8("bl") },
    { name: "radio.img", phase: "firmware", bytes: utf8("radio") },
    { name: "avb_pkmd.bin", phase: "avb", bytes: utf8("pkmd") },
    { name: "boot.img", phase: "os", bytes: utf8("boot") },
    { name: "vbmeta.img", phase: "os", bytes: utf8("vbmeta") },
  ];
  const { channel, store } = bundleFromBlobs(blobs, {
    product: "rango",
    advertisedDevices: ["rango"],
    verifiedBootClaim: "none",
    bootState: "unlocked",
  });
  const commands: string[] = [];
  const transport: FastbootTransport = {
    dryRun: false,
    connect: async () => undefined,
    getVar: async (name) => (name === "product" ? "rango" : "none"),
    runCommand: async (cmd): Promise<CommandResult> => {
      commands.push(cmd);
      return { ok: true, text: "OKAY" };
    },
    flash: async (_p, _d, _o?: FlashOptions) => undefined,
    rebootBootloader: async (onReconnect) => onReconnect(),
  };
  const orch = new FlashOrchestrator({ transport, channel, store });
  await orch.connect();
  await orch.executePlan({ onReconnect: async () => undefined, allowLiveExecute: true });

  await assert.rejects(() => orch.lock(), LiveExecuteHoldError);
  await assert.rejects(() => orch.lock({ allowLiveLock: true }), LockSafetyError);
  await assert.rejects(
    () => orch.lock({ allowLiveLock: true, confirmed: true }),
    LockSafetyError,
  );
  await orch.lock({ allowLiveLock: true, confirmed: true, operatorOverride: true });
  assert.ok(commands.includes("flashing lock"));
});

test("quota & OPFS streaming store prevent multi-GB OOM", async () => {
  const GiB = 1024 * 1024 * 1024;
  const assessment = assessQuota(
    [{ size: 2 * GiB }],
    { quota: 4 * GiB, usage: 3 * GiB },
  );
  assert.equal(assessment.availableBytes, 1 * GiB);
  assert.equal(assessment.lowQuota, true);

  assert.throws(
    () => assertStorageQuotaForBytes(2 * GiB, { quota: 4 * GiB, usage: 3 * GiB }, "super.img"),
    StorageQuotaError,
  );

  // HttpArtifactStore refuses to buffer an artifact exceeding maxInMemoryBytes
  const origFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(new Uint8Array(64), {
      status: 200,
      headers: { "content-length": "64" },
    });
  try {
    const store = new HttpArtifactStore("https://example.invalid/", {
      maxInMemoryBytes: 32,
    });
    await assert.rejects(() => store.read("super.img"), StorageQuotaError);

    // OpfsArtifactStore streams chunks directly to OPFS without JS heap buffering limit
    const written: Uint8Array[] = [];
    const opfsDir: OpfsDirectoryHandle = {
      getFileHandle: async (): Promise<OpfsFileHandle> => ({
        createWritable: async () => ({
          write: async (data) => {
            written.push(data);
          },
          close: async () => undefined,
        }),
        getFile: async () => ({
          arrayBuffer: async () => new Uint8Array(64).buffer,
        }),
      }),
    };
    const opfs = new OpfsArtifactStore("https://example.invalid/", opfsDir);
    await opfs.stageToOpfs("super.img");
    const totalWritten = written.reduce((sum, c) => sum + c.byteLength, 0);
    assert.equal(totalWritten, 64);
  } finally {
    globalThis.fetch = origFetch;
  }
});
