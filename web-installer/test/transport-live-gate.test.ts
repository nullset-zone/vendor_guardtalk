/**
 * T-WEBINSTALL-WEBUSB-TRANSPORT-BUNDLE.
 *
 * Proves the live WebUSB path has a real, exactly-pinned transport dependency
 * AND stays refused while `LIVE_FLASH_CLAIMED` is false (DEC-009). No USB
 * device is opened here: the live adapter is exercised through a stub module,
 * and the real pinned package is only imported/constructed (never connected).
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { FastbootError, LiveExecuteHoldError } from "../src/errors.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import {
  adaptAndroidFastboot,
  connectAndroidFastboot,
  importAndroidFastboot,
  type AndroidFastbootDevice,
  type AndroidFastbootModule,
} from "../src/transport.js";
import { LIVE_FLASH_CLAIMED } from "../src/types.js";
import type { FastbootTransport } from "../src/types.js";
import { bundleFromBlobs, tokayBlobs, utf8 } from "./helpers.js";

/** The exact commit the source comment names; the pin must be this or newer. */
const PINNED_COMMIT = "ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9";

function readJson(relative: string): Record<string, unknown> {
  const text = readFileSync(new URL(relative, import.meta.url), "utf8");
  return JSON.parse(text) as Record<string, unknown>;
}

class StubFastbootDevice implements AndroidFastbootDevice {
  connects = 0;
  readonly commands: string[] = [];
  readonly flashes: string[] = [];
  readonly rebootTargets: string[] = [];
  readonly flashPayloads: number[][] = [];

  async connect(): Promise<void> {
    this.connects += 1;
  }

  async getVariable(name: string): Promise<string | null> {
    if (name === "product") {
      return "tokay";
    }
    if (name === "unlocked") {
      return "yes";
    }
    if (name === "snapshot-update-status") {
      return "none";
    }
    return null;
  }

  async runCommand(command: string): Promise<{ text: string }> {
    this.commands.push(command);
    return { text: "OKAY" };
  }

  async flashBlob(partition: string, blob: Blob): Promise<void> {
    this.flashes.push(partition);
    this.flashPayloads.push([...new Uint8Array(await blob.arrayBuffer())]);
  }

  async reboot(
    mode?: string,
    _wait?: boolean,
    onReconnect?: () => Promise<void>,
  ): Promise<void> {
    this.rebootTargets.push(mode ?? "");
    await onReconnect?.();
  }
}

/** A module whose constructor hands back one recording stub device. */
function stubModule(): { module: AndroidFastbootModule; device: StubFastbootDevice } {
  const device = new StubFastbootDevice();
  const FastbootDevice = function FastbootDevice(): AndroidFastbootDevice {
    return device;
  } as unknown as new () => AndroidFastbootDevice;
  return { module: { FastbootDevice }, device };
}

function orchestratorFor(transport: FastbootTransport): FlashOrchestrator {
  const { channel, store } = bundleFromBlobs(tokayBlobs());
  return new FlashOrchestrator({ transport, channel, store });
}

/* ---------------------------------------------------------------- *
 * (a) declared, pinned, resolvable
 * ---------------------------------------------------------------- */

test("(a) android-fastboot is a declared dependency pinned to an exact commit", () => {
  const pkg = readJson("../package.json");
  const spec = (pkg.dependencies as Record<string, unknown> | undefined)?.[
    "android-fastboot"
  ];
  assert.equal(typeof spec, "string", "dependencies.android-fastboot must exist");
  const text = spec as string;
  // Exactly one 40-hex commit, no range/caret/tilde/tag/branch.
  assert.match(
    text,
    /^git\+https:\/\/github\.com\/kdrag0n\/fastboot\.js\.git#[0-9a-f]{40}$/,
  );
  assert.equal(text.split("#")[1], PINNED_COMMIT);
  assert.doesNotMatch(text, /[\^~*]|latest|master|main/);
});

test("(a) the lockfile resolves the same commit (reproducible npm ci)", () => {
  const lock = readJson("../package-lock.json");
  const packages = lock.packages as Record<string, Record<string, unknown>>;
  const entry = packages["node_modules/android-fastboot"];
  assert.ok(entry, "lockfile must record node_modules/android-fastboot");
  assert.match(String(entry.resolved), new RegExp(`#${PINNED_COMMIT}$`));
});

test("(a) the pinned package resolves and satisfies the adapter interface", async () => {
  const module = await importAndroidFastboot();
  assert.equal(typeof module.FastbootDevice, "function");
  // Construction only; connect() would request a real USB device.
  const device = new module.FastbootDevice();
  for (const name of [
    "connect",
    "getVariable",
    "runCommand",
    "flashBlob",
    "reboot",
  ] as const) {
    assert.equal(typeof device[name], "function", `FastbootDevice.${name}`);
  }
});

/* ---------------------------------------------------------------- *
 * (b) adapter conforms; the simulated path has no static edge
 * ---------------------------------------------------------------- */

test("(b) src/transport.ts has no static android-fastboot import", () => {
  const source = readFileSync(new URL("../src/transport.ts", import.meta.url), "utf8");
  assert.doesNotMatch(
    source,
    /^\s*import\s[^;\n]*["']android-fastboot["']/m,
    "a static import would load WebUSB code on the dry-run path",
  );
  assert.match(source, /export const ANDROID_FASTBOOT_SPECIFIER = "android-fastboot"/);
});

test("(b) adaptAndroidFastboot maps the device onto FastbootTransport", async () => {
  const device = new StubFastbootDevice();
  const transport = adaptAndroidFastboot(device);
  assert.equal(transport.dryRun, false);

  await transport.connect();
  assert.equal(device.connects, 1);
  assert.equal(await transport.getVar("product"), "tokay");

  await transport.flash("boot", utf8("boot-img"));
  await transport.flash("vbmeta", utf8("vbmeta-img"), { slot: "other" });
  assert.deepEqual(device.flashes, ["boot", "vbmeta:other"]);
  assert.deepEqual(device.flashPayloads, [
    [...utf8("boot-img")],
    [...utf8("vbmeta-img")],
  ]);

  let reconnected = 0;
  await transport.rebootBootloader(async () => {
    reconnected += 1;
  });
  assert.deepEqual(device.rebootTargets, ["bootloader"]);
  assert.equal(reconnected, 1);

  assert.deepEqual(await transport.runCommand("oem device-info"), {
    ok: true,
    text: "OKAY",
  });
});

test("(b) adapter fails closed on an empty getvar and a rejected command", async () => {
  const empty = new StubFastbootDevice();
  empty.getVariable = async () => null;
  await assert.rejects(() => adaptAndroidFastboot(empty).getVar("serialno"), FastbootError);

  const failing = new StubFastbootDevice();
  failing.runCommand = async () => {
    throw new Error("FAIL device is locked");
  };
  assert.deepEqual(await adaptAndroidFastboot(failing).runCommand("flashing unlock"), {
    ok: false,
    text: "FAIL device is locked",
  });
});

/* ---------------------------------------------------------------- *
 * (c)+(d) the live path is refused while LIVE_FLASH_CLAIMED is false
 * ---------------------------------------------------------------- */

test("(d) connectAndroidFastboot builds a live transport, yet executePlan/lock stay HOLD", async () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);

  const { module, device } = stubModule();
  const transport = await connectAndroidFastboot({ module });
  assert.equal(transport.dryRun, false, "the real adapter is not a dry run");
  assert.equal(device.connects, 1, "the real library device was connected");

  const orch = orchestratorFor(transport);
  await orch.connect();
  await orch.unlock();

  await assert.rejects(
    () => orch.executePlan({ onReconnect: async () => undefined }),
    LiveExecuteHoldError,
  );
  assert.deepEqual(device.flashes, [], "no partition may be written on a live path");
  assert.equal(orch.isPlanComplete(), false);

  await assert.rejects(() => orch.lock(), LiveExecuteHoldError);
  assert.deepEqual(
    device.commands.filter((command) => command === "flashing lock"),
    [],
  );

  assert.equal(orch.claimsLiveFlash(), false, "the build does not claim a live flash");
  assert.equal(LIVE_FLASH_CLAIMED, false);
});

test("(c) a malformed pinned module fails closed instead of pretending to work", async () => {
  const noExport = {} as AndroidFastbootModule;
  await assert.rejects(() => connectAndroidFastboot({ module: noExport }), FastbootError);

  const wrongType = { FastbootDevice: 42 } as unknown as AndroidFastbootModule;
  await assert.rejects(() => connectAndroidFastboot({ module: wrongType }), FastbootError);
});
