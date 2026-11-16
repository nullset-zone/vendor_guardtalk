/**
 * Backend contract test (T-WEBINSTALLER-REMOVE-PUBKEY-BACKEND):
 *
 * Ensures `src/` and `scripts/` require no user-supplied public-key PEM,
 * user key-generation/import, or user-anchor enrolment, while keeping
 * internal channel integrity (`SHA256SUMS`, manifest validation, and
 * internal `avb_pkmd.bin`) and linear WebUSB flashing (`connect` ->
 * `unlock` -> `executePlan` -> `lock`) intact.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { loadChannelFromTexts } from "../src/channel.js";
import { sha256Hex } from "../src/hash.js";
import { MemoryArtifactStore } from "../src/store.js";
import { FlashOrchestrator } from "../src/orchestrator.js";
import { LIVE_FLASH_CLAIMED, type FastbootTransport } from "../src/types.js";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const SRC_DIR = join(ROOT, "src");
const SCRIPTS_DIR = join(ROOT, "scripts");

const FORBIDDEN_USER_KEY_PATTERNS: readonly RegExp[] = [
  /RELEASE_KEY_PEM/,
  /USER_KEY_PEM/,
  /proveVbmetaUserSigned/,
  /armoredPemToJwk/,
  /exportEncryptedPem/,
  /importPem/,
  /generateKey\s*\(/,
];

function collectCodeFiles(dir: string): string[] {
  const out: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...collectCodeFiles(full));
    } else if (/\.(ts|mts|mjs|js|sh)$/.test(entry.name)) {
      out.push(full);
    }
  }
  return out;
}

test("src/ and scripts/ contain no user-supplied PEM or user key-gen/import requirements", () => {
  const files = [...collectCodeFiles(SRC_DIR), ...collectCodeFiles(SCRIPTS_DIR)];
  assert.ok(files.length > 0, "expected src/ and scripts/ files");

  for (const file of files) {
    const text = readFileSync(file, "utf8");
    for (const pattern of FORBIDDEN_USER_KEY_PATTERNS) {
      assert.equal(
        pattern.test(text),
        false,
        `${file} must not reference user-supplied key requirement ${pattern}`,
      );
    }
  }
});

test("linear WebUSB orchestrator flow runs without user-supplied public key", async () => {
  const bootloaderBytes = new Uint8Array([1, 2, 3, 4]);
  const pkmdBytes = new Uint8Array([5, 6, 7, 8]);
  const bootBytes = new Uint8Array([9, 10, 11, 12]);
  const artifacts = new Map<string, Uint8Array>([
    ["bootloader.img", bootloaderBytes],
    ["avb_pkmd.bin", pkmdBytes],
    ["boot.img", bootBytes],
  ]);
  const sha = Object.fromEntries(
    Array.from(artifacts.entries()).map(([k, v]) => [k, sha256Hex(v)]),
  );
  const channel = loadChannelFromTexts({
    manifestJson: JSON.stringify({
      schemaVersion: 1,
      product: "tokay",
      advertisedDevices: ["tokay"],
      channel: "dev",
      bootState: "unlocked",
      channelLabel: "dev/unlocked",
      verifiedBootClaim: "none",
      releaseId: "tokay-20261116-000000",
      unixEpoch: 1794819600,
      sourceStamp: "tokay-20261116-000000",
      flashOrder: ["firmware", "avb_custom_key", "os"],
      factoryZip: null,
      avb: {
        publicKeyFile: "avb_pkmd.bin",
        sha256: sha["avb_pkmd.bin"],
        size: pkmdBytes.byteLength,
      },
      artifacts: [
        { name: "bootloader.img", phase: "firmware", sha256: sha["bootloader.img"], size: 4 },
        { name: "avb_pkmd.bin", phase: "avb", sha256: sha["avb_pkmd.bin"], size: 4 },
        { name: "boot.img", phase: "os", sha256: sha["boot.img"], size: 4 },
      ],
      signature: { required: false, mode: "hash-only", file: null, allowedSigners: null },
    }),
    sha256sums: Object.entries(sha)
      .map(([name, digest]) => `${digest}  ${name}`)
      .join("\n"),
    filesTxt: [
      "bootloader.img firmware 4",
      "avb_pkmd.bin avb 4",
      "boot.img os 4",
    ].join("\n"),
  });
  const store = new MemoryArtifactStore(artifacts);

  const ops: string[] = [];
  const transport: FastbootTransport = {
    dryRun: true,
    async connect() {
      ops.push("connect");
    },
    async getVar(name: string) {
      if (name === "product") return "tokay";
      if (name === "unlocked") return "no";
      if (name === "snapshot-update-status") return "none";
      if (name === "current-slot") return "a";
      return "";
    },
    async runCommand(command: string) {
      ops.push(`cmd:${command}`);
      return { ok: true };
    },
    async flash(partition: string) {
      ops.push(`flash:${partition}`);
    },
    async rebootBootloader(onReconnect) {
      ops.push("reboot-bootloader");
      await onReconnect();
    },
  };

  const orchestrator = new FlashOrchestrator({ transport, channel, store });
  await orchestrator.connect();
  await orchestrator.unlock();
  await orchestrator.executePlan({ onReconnect: async () => {} });
  await orchestrator.lock({ confirmed: true, operatorOverride: true });

  assert.equal(orchestrator.isPlanComplete(), true);
  assert.equal(orchestrator.claimsLiveFlash(), false);
  assert.equal(LIVE_FLASH_CLAIMED, false);
  assert.ok(ops.includes("cmd:flashing unlock"));
  assert.ok(ops.includes("flash:avb_custom_key"));
  assert.ok(ops.includes("cmd:flashing lock"));
});

test("honesty markers remain false in src/types.ts and status.json", () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
  const status = JSON.parse(readFileSync(join(ROOT, "status.json"), "utf8")) as {
    flashCapability?: { liveFlashClaimed?: boolean };
  };
  assert.equal(status.flashCapability?.liveFlashClaimed, false);
});
