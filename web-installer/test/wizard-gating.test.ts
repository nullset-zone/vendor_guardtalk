import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { LiveExecuteHoldError, LockBeforeCompleteError } from "../src/errors.js";
import { channelTextsFromBlobs, MockFastboot, tokayBlobs } from "./helpers.js";
import { WIZARD_DEVICES, deviceFromSearch } from "../wizard/devices.js";
import {
  WizardGateError,
  assertCanFlash,
  canFlash,
  canLock,
} from "../wizard/gating.js";
import { assessQuota, payloadBytes } from "../wizard/quota.js";
import { InstallWizard } from "../wizard/session.js";
import { runGuardedAction } from "../wizard/main.js";

const HERE = dirname(fileURLToPath(import.meta.url));

function gatedWizard(): InstallWizard {
  const session = new InstallWizard();
  session.selectDevice("tokay");
  session.loadChannel(channelTextsFromBlobs(tokayBlobs()));
  return session;
}

test("picker offers tokay, akita, komodo, and rango", () => {
  assert.deepEqual(
    WIZARD_DEVICES.map((d) => d.id),
    ["tokay", "akita", "komodo", "rango"],
  );
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "rango")?.status, "experimental");
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "rango")?.deviceName, "Pixel 10 Pro Fold");
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "tokay")?.deviceName, "Pixel 9");
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "akita")?.deviceName, "Pixel 8a");
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "komodo")?.deviceName, "Pixel 9 Pro XL");
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "tokay")?.status, "supported");
  assert.equal(JSON.stringify(WIZARD_DEVICES).includes("shiba"), false);
  assert.equal(JSON.stringify(WIZARD_DEVICES).includes("caiman"), false);
  assert.equal(JSON.stringify(WIZARD_DEVICES).includes("husky"), false);
});

test("flash is gated until unlock", async () => {
  const session = gatedWizard();
  session.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  session.useDryRunTransport();
  await session.connect();
  await assert.rejects(() => session.executePlan(async () => undefined), WizardGateError);
  assert.equal(canFlash(session.flags()), false);
});

test("lock is gated until flashcore plan completes", async () => {
  const session = gatedWizard();
  session.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  session.useDryRunTransport();
  await session.connect();
  await session.unlock();
  assert.equal(canLock(session.flags()), false);
  await assert.rejects(() => session.lock(), WizardGateError);
});

test("dry-run walks flashcore then allows lock", async () => {
  const session = gatedWizard();
  session.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  const dry = session.useDryRunTransport();
  await session.connect();
  await session.unlock();
  await session.executePlan(async () => undefined);
  assert.equal(session.flags().planComplete, true);
  await session.lock();
  assert.ok(dry.flashed.includes("bootloader"));
  assert.ok(dry.flashed.includes("avb_custom_key"));
  assert.ok(dry.reconnects >= 2);
  assert.equal(session.claimsLiveFlash(), false);
});

test("flashcore lock-before-complete remains the backstop", async () => {
  const { FlashOrchestrator } = await import("../src/orchestrator.js");
  const { bundleFromBlobs } = await import("./helpers.js");
  const { DryRunTransport } = await import("../wizard/dry-run.js");
  const { channel, store } = bundleFromBlobs(tokayBlobs());
  const orch = new FlashOrchestrator({
    transport: new DryRunTransport(),
    channel,
    store,
  });
  await orch.connect();
  await orch.unlock();
  await assert.rejects(() => orch.lock(), LockBeforeCompleteError);
});

test("quota uses actual artifact bytes, not 1700 MiB", () => {
  const fiftyMib = 50 * 1024 * 1024;
  const files = [{ size: fiftyMib }, { size: fiftyMib }];
  assert.equal(payloadBytes(files), 100 * 1024 * 1024);
  const assessment = assessQuota(files, { quota: 10 * 1024 * 1024 });
  assert.equal(assessment.payloadBytes, 100 * 1024 * 1024);
  assert.equal(assessment.lowQuota, true);
  assert.equal(assessment.summary.includes("1700"), false);
  assert.match(assessment.summary, /100\.0 MiB/);
});

test("tiny quota is called out as a private-window problem", () => {
  const files = [{ size: 2 * 1024 * 1024 * 1024 }];
  const assessment = assessQuota(files, { quota: 120 * 1024 * 1024 });
  assert.equal(assessment.likelyPrivateMode, true);
  assert.match(assessment.summary, /Incognito is not a supported path/);
});

test("rango can be selected as experimental; unstamped products cannot", () => {
  const session = new InstallWizard();
  assert.doesNotThrow(() => session.selectDevice("rango"));
  assert.throws(() => session.selectDevice("shiba"), WizardGateError);
  assert.throws(() => session.selectDevice("caiman"), WizardGateError);
  assert.throws(() => session.selectDevice("husky"), WizardGateError);
});

test("akita, komodo, and rango can be selected", () => {
  const session = new InstallWizard();
  assert.doesNotThrow(() => session.selectDevice("akita"));
  assert.doesNotThrow(() => session.selectDevice("komodo"));
  assert.doesNotThrow(() => session.selectDevice("rango"));
});

test("deviceFromSearch reads ?device= and rejects unknown products", () => {
  assert.equal(deviceFromSearch("?device=rango"), "rango");
  assert.equal(deviceFromSearch("sim=1&device=akita"), "akita");
  assert.equal(deviceFromSearch(new URLSearchParams("device=komodo")), "komodo");
  assert.equal(deviceFromSearch("?device=shiba"), "tokay");
  assert.equal(deviceFromSearch("?sim=1"), "tokay");
});

test("wizard HTML is GuardTalkOS-branded and carries DEC labels", async () => {
  const html = await readFile(join(HERE, "../wizard/index.html"), "utf8");
  assert.match(html, /GuardTalkOS/);
  assert.match(html, /dev\/unlocked/);
  assert.match(html, /not GrapheneOS-equivalent locked verified boot/);
  assert.match(html, /flash-from-remote\.sh/);
  assert.match(html, /dual-slot/);
  assert.match(html, /data-dec="009"/);
  assert.match(html, /data-dec="010"/);
  assert.match(html, /Live Flash\/Lock are HOLD/);
  assert.match(html, /komodo-20260915-063833/);
  assert.match(html, /not a signed user FLASH_READY image/);
  assert.match(html, /FLASH_READY=false/);
  assert.match(html, /LIVE_FLASH_CLAIMED=false/);
  assert.doesNotMatch(html, /FLASH_READY=true/);
  assert.match(html, /Incognito windows are not a supported path/);
  assert.match(html, /Reconnect after reboot-bootloader/);
  assert.match(html, /Pixel 9 \(tokay\)/);
  assert.match(html, /Pixel 8a \(akita\)/);
  assert.match(html, /Pixel 9 Pro XL \(komodo\)/);
  assert.match(html, /Pixel 10 Pro Fold \(rango\)/);
  assert.match(html, /experimental \/ boot HOLD/);
  assert.match(html, /channels\/tokay/);
  assert.match(html, /reboot-to-fastboot\.sh/);
  assert.match(html, /adb reboot bootloader/);
  assert.match(html, /USB debugging/);
  assert.match(html, /Reboot to Fastboot/);
  assert.match(html, /btn-reboot-fastboot/);
  assert.match(html, /WebUSB ADB/);
  assert.match(html, /reboot:bootloader/);
  assert.doesNotMatch(html, /rango stays hidden/);
  assert.match(html, /tokay \+ akita \+ komodo \+ rango \(experimental \/ boot HOLD\)/);
  assert.doesNotMatch(html, /value="rango"/);
  assert.doesNotMatch(html, /channel-files/);
  assert.doesNotMatch(html, /Load selected files/);
  assert.doesNotMatch(html, /Preview example tokay channel/);
  assert.doesNotMatch(html, /The web installer is the easiest method/);
  assert.doesNotMatch(html, /1700 MiB/);
});

test("wizard HTML carries danger variant and alert regions (Pajamas F1/F4/F9)", async () => {
  const html = await readFile(join(HERE, "../wizard/index.html"), "utf8");
  assert.match(html, /id="btn-unlock"[^>]*class="danger"/);
  assert.match(html, /id="btn-flash"[^>]*class="danger"/);
  assert.match(html, /id="btn-lock"[^>]*class="danger"/);
  assert.doesNotMatch(html, /id="btn-reboot-fastboot"[^>]*class="danger"/);
  assert.match(html, /id="quota-box"[^>]*role="alert"/);
  assert.match(html, /id="alert-text"[^>]*role="alert"/);
  assert.match(html, /id="status-text"[^>]*role="status"/);
});

test("wizard styles carry strong border, danger tokens, busy and checkbox sizing (F3/F5/F6/F8)", async () => {
  const css = await readFile(join(HERE, "../wizard/styles.css"), "utf8");
  assert.match(css, /--line-strong:\s*var\(--gl-border-color-strong\)/);
  assert.match(css, /button\.danger\s*{[^}]*--gl-action-danger-bg/);
  assert.match(css, /button\.secondary\s*{[^}]*var\(--line-strong\)/);
  assert.match(css, /button\[aria-busy="true"\]/);
  assert.match(css, /button\.danger:hover:not\(:disabled\)/);
  assert.match(css, /button\.secondary:hover:not\(:disabled\)/);
  assert.match(css, /select:hover/);
  assert.match(css, /\.check input\[type="checkbox"\]\s*{[^}]*width:\s*1\.5rem/);
  assert.match(css, /\.check input\[type="checkbox"\]\s*{[^}]*height:\s*1\.5rem/);
});

interface HarnessButton {
  disabled: boolean;
  ariaBusy: string | null;
}

function gatedActionHarness() {
  let busyCount = 0;
  const gates = { unlock: false };
  const unlockBtn: HarnessButton = { disabled: true, ariaBusy: null };
  const applyGates = () => {
    if (busyCount > 0) {
      return;
    }
    unlockBtn.disabled = !gates.unlock;
  };
  return {
    unlockBtn,
    openGateDuringWork(): void {
      gates.unlock = true;
      applyGates();
    },
    steps: {
      begin: () => {
        busyCount += 1;
        unlockBtn.disabled = true;
        unlockBtn.ariaBusy = "true";
      },
      settle: () => {
        busyCount -= 1;
      },
      refresh: () => {
        applyGates();
      },
      // Mirrors wizard/main.ts setBusy(trigger, false): buttons keep whatever
      // resting disabled state refresh() last applied; only aria-busy clears.
      restore: () => {
        unlockBtn.ariaBusy = null;
      },
      fail: () => {
        throw new Error("fail callback must not run on this path");
      },
    },
  };
}

test("runAction finally ordering propagates gates opened during work", async () => {
  const h = gatedActionHarness();
  await runGuardedAction(async () => {
    h.openGateDuringWork();
    assert.equal(h.unlockBtn.disabled, true, "mid-flight refresh must stay suppressed");
  }, h.steps);
  assert.equal(h.unlockBtn.disabled, false, "gate opened during work must enable the control");
  assert.equal(h.unlockBtn.ariaBusy, null);
});

test("runAction finally ordering propagates gates after a failed action", async () => {
  const h = gatedActionHarness();
  await runGuardedAction(async () => {
    h.openGateDuringWork();
    throw new Error("transport dropped mid-action");
  }, {
    ...h.steps,
    fail: (err) => {
      assert.ok(err instanceof Error);
      assert.equal(err.message, "transport dropped mid-action");
    },
  });
  assert.equal(h.unlockBtn.disabled, false, "gate state must propagate even after failure");
  assert.equal(h.unlockBtn.ariaBusy, null);
});

test("wizard executePlan refuses live mode", async () => {
  const session = gatedWizard();
  session.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  session.attachTransport(new MockFastboot({ live: true }), "live");
  await session.connect();
  await session.unlock();
  assert.equal(session.currentMode(), "live");
  assert.equal(canFlash(session.flags()), false);
  await assert.rejects(
    () => session.executePlan(async () => undefined),
    LiveExecuteHoldError,
  );
});

test("wizard lock refuses live mode", async () => {
  const session = gatedWizard();
  session.attachArtifacts(new Map(tokayBlobs().map((b) => [b.name, b.bytes])));
  session.attachTransport(new MockFastboot({ live: true }), "live");
  await session.connect();
  await session.unlock();
  assert.equal(canLock(session.flags()), false);
  await assert.rejects(() => session.lock(), LiveExecuteHoldError);
});

test("assertCanFlash names unlock as the missing gate", () => {
  assert.throws(
    () =>
      assertCanFlash({
        deviceSelected: true,
        channelLoaded: true,
        connected: true,
        unlocked: false,
        planComplete: false,
        artifactsReady: true,
        dryRun: true,
      }),
    /unlock the bootloader before flash/,
  );
});
