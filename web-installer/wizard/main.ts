import { WIZARD_DEVICES } from "./devices.js";
import { fetchHostedChannel, hostedChannelBase } from "./hosted-channel.js";
import { HttpArtifactStore } from "./http-store.js";
import { formatMib } from "./quota.js";
import { webUsbAvailable } from "./adb-reboot.js";
import { InstallWizard, readOptionalFastbootDevice } from "./session.js";
import type { FlashPlan, PlanStep } from "../src/types.js";

const wizard = new InstallWizard();
let reconnectWaiter: (() => void) | null = null;
let reconnectAborter: ((reason: Error) => void) | null = null;
let busyCount = 0;
let loadSeq = 0;

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

function refreshGates(): void {
  if (busyCount > 0) {
    return;
  }
  const gates = wizard.gateState();
  el<HTMLButtonElement>("btn-connect").disabled = !gates.connect;
  el<HTMLButtonElement>("btn-unlock").disabled = !gates.unlock;
  el<HTMLButtonElement>("btn-flash").disabled = !gates.flash;
  el<HTMLButtonElement>("btn-lock").disabled = !gates.lock;
  el<HTMLButtonElement>("btn-preview").disabled = !gates.preview;
  el<HTMLButtonElement>("btn-reboot-fastboot").disabled = !webUsbAvailable();
}

function renderPlan(plan: FlashPlan): void {
  const list = el("plan-list");
  list.replaceChildren();
  for (const step of plan.steps) {
    const li = document.createElement("li");
    li.textContent = formatStep(step);
    list.append(li);
  }
  el("plan-meta").textContent =
    `${plan.product} · ${plan.flashOrder.join(" → ")} · ${String(plan.steps.length)} flashcore steps`;
}

function formatStep(step: PlanStep): string {
  if (step.kind === "flash") {
    return `[${step.phase}] flash ${step.partition} ← ${step.artifact}`;
  }
  if (step.kind === "erase") {
    return `[${step.phase}] erase ${step.partition}`;
  }
  if (step.kind === "command") {
    return `[${step.phase}] ${step.command}`;
  }
  return `[${step.phase}] reconnect — ${step.reason}`;
}

function fillDeviceSelect(): void {
  const select = el<HTMLSelectElement>("device");
  select.replaceChildren();
  for (const device of WIZARD_DEVICES) {
    const option = document.createElement("option");
    option.value = device.id;
    option.textContent = device.label;
    select.append(option);
  }
  select.value = WIZARD_DEVICES[0]?.id ?? "tokay";
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
  renderPlan(plan);
  await refreshQuota();
  refreshGates();
  const payload = wizard.assessStorage(null).payloadBytes;
  el("channel-status").textContent =
    `${plan.product} channel ready. Artifacts stay on the server until flashcore reads them.`;
  logLine(`Loaded hosted ${plan.product} channel. Artifact total ${formatMib(payload)}.`, "ok");
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
  // Gate-managed buttons take their resting disabled state from refreshGates(),
  // which has just run; other triggers (device <select>) have no gate.
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
    },
  });
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
      attachLiveIfRequested();
      await wizard.connect();
      logLine("Connected (flashcore connect + product check).", "ok");
      setStatus("Connected. Unlock next.");
    });
  });
  el("btn-unlock").addEventListener("click", () => {
    void runAction("Unlock", async () => {
      await wizard.unlock();
      logLine("Unlock finished. Confirm any wipe prompt on the Pixel.", "ok");
      setStatus("Unlocked. Flash reads artifacts from the server.");
    });
  });
  el("btn-flash").addEventListener("click", () => {
    void runAction("Flash", async () => {
      await wizard.executePlan(waitForReconnect);
      logLine("Flashcore plan complete.", "ok");
      setStatus("Flash complete. Lock is now available.");
    });
  });
  el("btn-lock").addEventListener("click", () => {
    void runAction("Lock", async () => {
      await wizard.lock();
      logLine("Lock command sent. This channel is still labeled dev/unlocked.", "warn");
      setStatus("Lock requested. Not GrapheneOS-equivalent locked verified boot.");
    });
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
  const note = el("webusb-note");
  note.textContent = usb
    ? "This browser exposes WebUSB. Reboot to Fastboot uses WebUSB ADB. Live flash still needs a FastbootDevice; this build does not ship android-fastboot."
    : "This browser has no WebUSB. Reboot to Fastboot and live connect are unavailable. Dry-run and plan preview still work.";
}

function init(): void {
  fillDeviceSelect();
  const initial = WIZARD_DEVICES[0]?.id ?? "tokay";
  wizard.selectDevice(initial);
  markWebUsb();
  bindPlanActions();
  bindDeviceActions();
  bindReconnectAndQuota();
  refreshGates();
  logLine("GuardTalkOS installer ready. LIVE_FLASH_CLAIMED is false.", "info");
  void runAction("Hosted channel", async () => {
    await loadHostedFor(initial);
  });
}

if (typeof document !== "undefined") {
  init();
}
