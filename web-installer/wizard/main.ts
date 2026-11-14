import {
  WIZARD_DEVICES,
  deviceFromSearch,
  getWizardDevice,
} from "./devices.js";
import { fetchHostedChannel, hostedChannelBase } from "./hosted-channel.js";
import { HttpArtifactStore } from "./http-store.js";
import { formatMib } from "./quota.js";
import { webUsbAvailable } from "./adb-reboot.js";
import { canLockWithSafety, type SafetyLockGate } from "./gating.js";
import {
  InstallWizard,
  readOptionalFastbootDevice,
  type FlashProgress,
} from "./session.js";
import {
  LIVE_FLASH_CLAIMED,
  type BootChainMode,
  type FlashPlan,
  type PlanStep,
} from "../src/types.js";

const wizard = new InstallWizard();
let reconnectWaiter: (() => void) | null = null;
let reconnectAborter: ((reason: Error) => void) | null = null;
let busyCount = 0;
let loadSeq = 0;
let lastFailedAction: (() => Promise<void>) | null = null;

export class ReconnectCancelledError extends Error {
  constructor() {
    super("reconnect cancelled before the Pixel returned to Fastboot Mode; flash plan aborted");
    this.name = "ReconnectCancelledError";
  }
}

function el<T extends HTMLElement>(id: string): T {
  const node = document.getElementById(id);
  if (node === null) {
    throw new Error(`missing #${id}`);
  }
  return node as T;
}

function logLine(message: string, kind: "info" | "warn" | "error" | "ok" = "info"): void {
  const log = el<HTMLElement>("event-log");
  const item = document.createElement("p");
  item.className = `log-line log-${kind}`;
  item.textContent = message;
  log.append(item);
  log.scrollTop = log.scrollHeight;
}

function setStatus(message: string): void {
  el("status-text").textContent = message;
}

function setAlert(message: string): void {
  const alertText = el("alert-text");
  alertText.textContent = message === "" ? "\u00a0" : message;
}

function currentSafetyGate(): SafetyLockGate {
  const product = wizard.getSelectedDevice() ?? "tokay";
  const devMeta = getWizardDevice(product);
  const channelMeta = wizard.getChannelMeta();
  const isExperimentalOrUnverified =
    devMeta?.status === "experimental" ||
    channelMeta?.verifiedBootClaim === "none" ||
    channelMeta?.bootState === "unlocked";
  return {
    confirmed: (document.getElementById("confirm-lock") as HTMLInputElement | null)?.checked ?? false,
    operatorOverride:
      (document.getElementById("operator-lock-override") as HTMLInputElement | null)?.checked ?? false,
    isExperimentalOrUnverified,
  };
}

function refreshGates(): void {
  if (busyCount > 0) {
    return;
  }
  const gates = wizard.gateState();
  const unlockConfirmed =
    (document.getElementById("confirm-unlock") as HTMLInputElement | null)?.checked ?? false;
  el<HTMLButtonElement>("btn-connect").disabled = !gates.connect;
  el<HTMLButtonElement>("btn-unlock").disabled = !(gates.unlock && unlockConfirmed);
  el<HTMLButtonElement>("btn-flash").disabled = !gates.flash;
  el<HTMLButtonElement>("btn-lock").disabled = !canLockWithSafety(
    wizard.flags(),
    currentSafetyGate(),
  );
  el<HTMLButtonElement>("btn-preview").disabled = !gates.preview;
  el<HTMLButtonElement>("btn-reboot-fastboot").disabled = !webUsbAvailable();
  updateStepRail();
}

function updateStepRail(): void {
  const flags = wizard.flags();
  const completed: Record<number, boolean> = {
    1: true,
    2: flags.connected || flags.unlocked,
    3: flags.connected,
    4: flags.unlocked,
    5: flags.channelLoaded && flags.artifactsReady,
    6: flags.planComplete,
    7: flags.planComplete && !flags.unlocked,
    8: flags.planComplete,
  };
  let currentStep = 3;
  if (!flags.channelLoaded) {
    currentStep = 5;
  } else if (!flags.connected) {
    currentStep = 3;
  } else if (!flags.unlocked) {
    currentStep = 4;
  } else if (!flags.planComplete) {
    currentStep = 6;
  } else {
    currentStep = 7;
  }

  for (let i = 1; i <= 8; i += 1) {
    const li = document.querySelector<HTMLLIElement>(`#step-rail li[data-step="${String(i)}"]`);
    const chip = document.querySelector<HTMLElement>(`[data-step-chip="${String(i)}"]`);
    if (!li || !chip) {
      continue;
    }
    if (i === currentStep) {
      li.setAttribute("aria-current", "step");
      chip.textContent = "CURRENT";
    } else {
      li.removeAttribute("aria-current");
      chip.textContent = completed[i] ? "DONE" : "PENDING";
    }
  }
}

function updateReadinessBadges(product: string): void {
  const meta = getWizardDevice(product);
  const badge = el("device-readiness-badge");
  const chainBadge = el("boot-chain-badge");
  if (meta) {
    badge.textContent = meta.readinessBadge;
    badge.className =
      meta.status === "experimental" ? "badge badge-experimental" : "badge badge-supported";
    chainBadge.textContent = `boot-chain: ${wizard.getBootChain()} · super: ${meta.superMode}`;
  }
  const chainSelect = el<HTMLSelectElement>("boot-chain");
  chainSelect.value = wizard.getBootChain();
  const hybridOption = chainSelect.querySelector<HTMLOptionElement>('option[value="hybrid"]');
  if (hybridOption && meta) {
    const supportsHybrid = meta.supportedBootChains.includes("hybrid");
    hybridOption.disabled = !supportsHybrid;
  }
}

function renderPlan(plan: FlashPlan): void {
  const list = el("plan-list");
  list.replaceChildren();
  for (const step of plan.steps) {
    const li = document.createElement("li");
    li.textContent = formatStep(step);
    list.append(li);
  }
  const meta = getWizardDevice(plan.product);
  const superNote = meta?.superMode === "super" ? "super.img" : "super_empty + fastbootd";
  el("plan-meta").textContent =
    `${plan.product} · ${wizard.getBootChain()} (${superNote}) · ${plan.flashOrder.join(" → ")} · ${String(plan.steps.length)} flashcore steps`;
}

function formatStep(step: PlanStep): string {
  if (step.kind === "flash") {
    const slotNote = step.slot ? ` --slot=${step.slot}` : "";
    return `[${step.phase}] flash ${step.partition}${slotNote} ← ${step.artifact}`;
  }
  if (step.kind === "erase") {
    return `[${step.phase}] erase ${step.partition}`;
  }
  if (step.kind === "command") {
    return `[${step.phase}] ${step.command}`;
  }
  if (step.kind === "wipe-super") {
    return `[${step.phase}] wipe-super ← ${step.artifact}`;
  }
  if (step.kind === "reboot-fastboot") {
    return `[${step.phase}] reboot-fastboot — ${step.reason}`;
  }
  return `[${step.phase}] reconnect — ${step.reason}`;
}

function renderProgress(progress: FlashProgress): void {
  const bar = el("flash-progress-bar");
  const fill = el("flash-progress-fill");
  const text = el("flash-progress-text");
  bar.setAttribute("aria-valuenow", String(progress.percent));
  fill.style.width = `${String(progress.percent)}%`;
  const part = progress.partition ? ` [${progress.partition}]` : "";
  text.textContent = `${String(progress.percent)}% (${String(progress.completedSteps)}/${String(progress.totalSteps)})${part} · ${progress.label}`;
}

function fillDeviceSelect(): void {
  const select = el<HTMLSelectElement>("device");
  select.replaceChildren();
  for (const device of WIZARD_DEVICES) {
    const option = document.createElement("option");
    option.value = device.id;
    option.textContent = device.label;
    option.dataset.status = device.status;
    option.dataset.bootChain = device.defaultBootChain;
    select.append(option);
  }
  select.value = deviceFromSearch(window.location.search);
}

async function loadHostedFor(product: string): Promise<void> {
  const seq = ++loadSeq;
  const base = hostedChannelBase(product);
  el("channel-url").textContent = base;
  el("channel-status").textContent = `Loading ${product} from ${base}…`;
  setStatus(`Loading ${product} channel from the server…`);
  const hosted = await fetchHostedChannel(product);
  if (seq !== loadSeq) {
    return;
  }
  wizard.selectDevice(hosted.product);
  const plan = wizard.loadChannel(hosted.texts);
  wizard.attachStore(new HttpArtifactStore(hosted.baseUrl));
  updateReadinessBadges(hosted.product);
  renderPlan(plan);
  const chMeta = wizard.getChannelMeta();
  if (chMeta) {
    el("channel-verify-text").textContent =
      `Stamp ${chMeta.sourceStamp} · ${chMeta.channelLabel} · ${String(chMeta.artifactCount)} artifacts · avb_pkmd.bin SHA-256 ${chMeta.avbSha256.slice(0, 16)}… (verified)`;
  }
  await refreshQuota();
  refreshGates();
  const payload = wizard.assessStorage(null).payloadBytes;
  el("channel-status").textContent =
    `${plan.product} channel ready. Artifacts stay on the server until flashcore reads them.`;
  logLine(`Loaded hosted ${plan.product} channel. Artifact total ${formatMib(payload)}.`, "ok");
  const meta = getWizardDevice(plan.product);
  if (meta?.status === "experimental") {
    logLine(`${plan.product} is experimental — not production-boot-green.`, "warn");
  }
  setStatus("Hosted channel loaded. Use dry-run, then connect.");
}

async function refreshQuota(): Promise<void> {
  let estimate: { quota?: number; usage?: number } | null = null;
  if ("storage" in navigator && navigator.storage.estimate !== undefined) {
    estimate = await navigator.storage.estimate();
  }
  const assessment = wizard.assessStorage(estimate, isPrivateHint());
  const box = el("quota-box");
  box.hidden = false;
  box.className = assessment.lowQuota || assessment.likelyPrivateMode ? "callout danger" : "callout";
  el("quota-text").textContent = assessment.summary;
}

function isPrivateHint(): boolean {
  return el<HTMLInputElement>("private-hint").checked;
}

function clearUsbRecovery(): void {
  el("usb-recovery-box").hidden = true;
  lastFailedAction = null;
}

function showUsbRecovery(err: unknown, retryWork: () => Promise<void>): void {
  const assessment = wizard.classifyError(err);
  if (!assessment.recoverable) {
    return;
  }
  lastFailedAction = retryWork;
  el("usb-recovery-text").textContent = assessment.guidance;
  el("usb-recovery-box").hidden = false;
}

async function waitForReconnect(): Promise<void> {
  const dialog = el<HTMLDialogElement>("reconnect-dialog");
  const button = el<HTMLButtonElement>("reconnect-btn");
  setStatus("Waiting for reconnect after reboot-bootloader.");
  logLine("USB session dropped after reboot-bootloader. Reconnect when the Pixel is back in Fastboot Mode.", "warn");
  dialog.showModal();
  button.focus();
  try {
    await new Promise<void>((resolve, reject) => {
      reconnectWaiter = resolve;
      reconnectAborter = reject;
    });
  } catch (err) {
    if (dialog.open) {
      dialog.close();
    }
    logLine("Reconnect cancelled. Flashcore plan aborted; no further writes were made.", "error");
    setStatus("Reconnect cancelled. The flash plan stopped; start over from Connect.");
    throw err instanceof Error ? err : new ReconnectCancelledError();
  } finally {
    reconnectWaiter = null;
    reconnectAborter = null;
  }
  dialog.close();
  logLine("Reconnect acknowledged. Flashcore continues.", "ok");
}

function setBusy(control: HTMLElement | null, busy: boolean): void {
  if (control === null) {
    return;
  }
  const interactive =
    control instanceof HTMLButtonElement ||
    control instanceof HTMLSelectElement ||
    control instanceof HTMLInputElement;
  if (!interactive) {
    return;
  }
  if (busy) {
    control.disabled = true;
    control.setAttribute("aria-busy", "true");
    return;
  }
  control.removeAttribute("aria-busy");
  if (!(control instanceof HTMLButtonElement)) {
    control.disabled = false;
  }
}

export interface GuardedActionSteps {
  begin(): void;
  settle(): void;
  refresh(): void;
  restore(): void;
  fail(err: unknown): void;
}

export async function runGuardedAction(
  work: () => Promise<void>,
  steps: GuardedActionSteps,
): Promise<void> {
  steps.begin();
  try {
    await work();
    steps.refresh();
  } catch (err) {
    steps.fail(err);
    steps.refresh();
  } finally {
    steps.settle();
    steps.refresh();
    steps.restore();
  }
}

async function runAction(label: string, work: () => Promise<void>): Promise<void> {
  const trigger =
    document.activeElement instanceof HTMLElement &&
    document.activeElement.closest<HTMLElement>(".actions") !== null
      ? document.activeElement
      : null;
  await runGuardedAction(work, {
    begin: () => {
      busyCount += 1;
      setBusy(trigger, true);
      setAlert("");
    },
    settle: () => {
      busyCount -= 1;
    },
    refresh: () => {
      refreshGates();
    },
    restore: () => {
      setBusy(trigger, false);
    },
    fail: (err) => {
      const message = wizard.describeError(err);
      logLine(`${label}: ${message}`, "error");
      setAlert(`${label}: ${message}`);
      showUsbRecovery(err, work);
    },
  });
}

function bindOsGuidanceTabs(): void {
  const tabs = document.querySelectorAll<HTMLButtonElement>(".os-tab");
  const selectOs = (os: string) => {
    for (const tab of tabs) {
      const active = tab.dataset.os === os;
      tab.setAttribute("aria-selected", active ? "true" : "false");
    }
    for (const name of ["linux", "macos", "windows"]) {
      const panel = document.getElementById(`os-panel-${name}`);
      if (panel) {
        panel.hidden = name !== os;
      }
    }
  };
  for (const tab of tabs) {
    tab.addEventListener("click", () => {
      if (tab.dataset.os) {
        selectOs(tab.dataset.os);
      }
    });
  }
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes("mac")) {
    selectOs("macos");
  } else if (ua.includes("win")) {
    selectOs("windows");
  } else {
    selectOs("linux");
  }
}

function bindPlanActions(): void {
  el("btn-preview").addEventListener("click", () => {
    renderPlan(wizard.getPlan());
    logLine("Flashcore plan preview only. No USB writes.", "info");
    setStatus("Plan preview from flashcore.");
  });
  el("btn-dry-run").addEventListener("click", () => {
    wizard.useDryRunTransport();
    logLine("Dry-run transport attached. Not a live flash.", "warn");
    setStatus("Dry-run ready. Connect is simulated.");
    refreshGates();
  });
  el("boot-chain").addEventListener("change", (event) => {
    const mode = (event.target as HTMLSelectElement).value as BootChainMode;
    const rebuilt = wizard.setBootChain(mode);
    const product = wizard.getSelectedDevice() ?? "tokay";
    updateReadinessBadges(product);
    if (rebuilt) {
      renderPlan(rebuilt);
    }
    logLine(`Boot-chain mode set to '${mode}'.`, "info");
    refreshGates();
  });
}

function bindDeviceActions(): void {
  el("device").addEventListener("change", (event) => {
    const id = (event.target as HTMLSelectElement).value;
    void runAction("Hosted channel", async () => {
      wizard.selectDevice(id);
      await loadHostedFor(id);
    });
  });
  el("btn-reboot-fastboot").addEventListener("click", () => {
    void runAction("Reboot to Fastboot", async () => {
      clearUsbRecovery();
      await wizard.rebootToFastboot();
      logLine(
        "Sent reboot:bootloader over WebUSB ADB. Wait for the Fastboot screen, then Connect.",
        "ok",
      );
      setStatus("Pixel should be in Fastboot Mode. Connect next.");
    });
  });
  el("btn-connect").addEventListener("click", () => {
    void runAction("Connect", async () => {
      clearUsbRecovery();
      attachLiveIfRequested();
      const telemetry = await wizard.connect();
      el("telemetry-product").textContent = telemetry.product;
      el("telemetry-slot").textContent = telemetry.currentSlot;
      el("telemetry-unlocked").textContent = telemetry.unlocked ? "yes" : "no";
      logLine(
        `Connected (${telemetry.product}, slot=${telemetry.currentSlot}, unlocked=${telemetry.unlocked ? "yes" : "no"}).`,
        "ok",
      );
      setStatus(telemetry.unlocked ? "Connected and unlocked. Flash next." : "Connected. Unlock next.");
    });
  });
  el("confirm-unlock").addEventListener("change", refreshGates);
  el("btn-unlock").addEventListener("click", () => {
    void runAction("Unlock", async () => {
      clearUsbRecovery();
      await wizard.unlock();
      el("telemetry-unlocked").textContent = "yes";
      logLine("Unlock finished. Confirm any wipe prompt on the Pixel.", "ok");
      setStatus("Unlocked. Flash reads artifacts from the server.");
    });
  });
  el("btn-flash").addEventListener("click", () => {
    void runAction("Flash", async () => {
      clearUsbRecovery();
      await wizard.executePlan({
        onReconnect: waitForReconnect,
        onProgress: renderProgress,
      });
      const chMeta = wizard.getChannelMeta();
      el("verify-summary").textContent =
        `Flash plan complete for ${chMeta?.product ?? "device"} (${chMeta?.sourceStamp ?? "unknown"}). ` +
        `avb_pkmd.bin ${chMeta?.avbSha256.slice(0, 16) ?? ""}… · LIVE_FLASH_CLAIMED=${String(LIVE_FLASH_CLAIMED)}.`;
      logLine("Flashcore plan complete.", "ok");
      setStatus("Flash complete. Safety-gated Lock is now available.");
    });
  });
  el("confirm-lock").addEventListener("change", refreshGates);
  el("operator-lock-override").addEventListener("change", refreshGates);
  el("btn-lock").addEventListener("click", () => {
    void runAction("Lock", async () => {
      clearUsbRecovery();
      const safety = currentSafetyGate();
      await wizard.lock({
        confirmed: safety.confirmed,
        operatorOverride: safety.operatorOverride,
      });
      el("telemetry-unlocked").textContent = "no";
      logLine("Lock command sent. This channel is still labeled dev/unlocked.", "warn");
      setStatus("Lock requested. Not GrapheneOS-equivalent locked verified boot.");
    });
  });
  el("btn-usb-retry").addEventListener("click", () => {
    if (lastFailedAction) {
      const retry = lastFailedAction;
      clearUsbRecovery();
      void runAction("USB Retry", retry);
    }
  });
}

function bindReconnectAndQuota(): void {
  el("reconnect-btn").addEventListener("click", () => {
    resolveReconnect();
  });
  const dialog = el<HTMLDialogElement>("reconnect-dialog");
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    abortReconnect();
  });
  dialog.addEventListener("close", () => {
    abortReconnect();
  });
  el("private-hint").addEventListener("change", () => {
    if (!wizard.gateState().preview) {
      return;
    }
    void refreshQuota().catch((err: unknown) => {
      logLine(wizard.describeError(err), "error");
    });
  });
}

function resolveReconnect(): void {
  const done = reconnectWaiter;
  reconnectWaiter = null;
  reconnectAborter = null;
  done?.();
}

function abortReconnect(): void {
  const abort = reconnectAborter;
  const done = reconnectWaiter;
  reconnectWaiter = null;
  reconnectAborter = null;
  if (abort !== null) {
    abort(new ReconnectCancelledError());
  } else {
    done?.();
  }
}

function attachLiveIfRequested(): void {
  if (wizard.currentMode() === "dry-run") {
    return;
  }
  const live = readOptionalFastbootDevice();
  if (live !== null) {
    wizard.useLiveTransport(live);
    logLine("Using adaptAndroidFastboot around a provided FastbootDevice.", "info");
    return;
  }
  if (wizard.currentMode() !== "live") {
    throw new Error(
      "No FastbootDevice is attached. Use Dry-run, or provide window.FastbootDevice (android-fastboot is not bundled).",
    );
  }
}

function markWebUsb(): void {
  const usb = "usb" in navigator;
  const isChromium = /chrom(e|ium)|edg\//i.test(navigator.userAgent);
  el("chromium-check").textContent = isChromium
    ? "Chromium-family browser detected."
    : "Non-Chromium browser detected — switch to Chromium, Chrome, Edge, or Brave for live WebUSB.";
  const note = el("webusb-note");
  note.textContent = usb
    ? "This browser exposes WebUSB. Reboot to Fastboot uses WebUSB ADB. Live flash still needs a FastbootDevice; this build does not ship android-fastboot."
    : "This browser has no WebUSB. Reboot to Fastboot and live connect are unavailable. Dry-run and plan preview still work.";
}

function init(): void {
  fillDeviceSelect();
  const initial = el<HTMLSelectElement>("device").value || deviceFromSearch(window.location.search);
  wizard.selectDevice(initial);
  updateReadinessBadges(initial);
  markWebUsb();
  bindOsGuidanceTabs();
  bindPlanActions();
  bindDeviceActions();
  bindReconnectAndQuota();
  refreshGates();
  logLine(`GuardTalkOS installer ready. LIVE_FLASH_CLAIMED is ${String(LIVE_FLASH_CLAIMED)}.`, "info");
  void runAction("Hosted channel", async () => {
    await loadHostedFor(initial);
  });
}

if (typeof document !== "undefined") {
  init();
}
