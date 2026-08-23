/**
 * /install browser bootstrap. Holds session material in memory only,
 * wires data-action clicks to the machine, and zeroises buffers on pagehide.
 */
import { onPageHide, zeroise } from "../../lib/keys/zeroise.js";
import { initialInstallState, reduce, type InstallState } from "../../lib/install-state/machine.js";
import { armoredPemToJwk, type RsaPublicJwk } from "../../lib/verify/detached-sig.js";
import { SimulatedDevice } from "../../lib/fastboot/simulated-device.js";
import { browserUsbPicker, webUsbTransport } from "../../lib/fastboot/usb.js";
import type { Transport } from "../../lib/fastboot/client.js";
import { collectingLog } from "../../lib/types.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import type { KeyMaterial } from "../../lib/avb/signer.js";
import {
  filesReady,
  renderInstallerChrome,
  renderStep0,
  renderStep1,
  renderStep3,
  renderStep3Collect,
  renderStep3FlowDetail,
  renderStep4,
  renderStep4Collect,
  runGenerateFlow,
  runImportFlow,
  runSignElsewhereFlow,
  signVbmetaStep,
  step3Decide,
  verifyRelease,
  type FilePicks,
  type SignViewModel,
} from "./early-steps.js";
import {
  connectStepHtml,
  flashStepHtml,
  isSimMode,
  keepKeyStepHtml,
  lockStepHtml,
  usbAvailable,
  verifyStepHtml,
} from "./late-steps.js";
import { FIRMWARE_ORDER, OS_ORDER, runFlashPlan } from "./flash-runner.js";

interface Session {
  state: InstallState;
  picks: FilePicks;
  packageName: string;
  packageBytes?: Uint8Array | undefined;
  sumsText?: string | undefined;
  sigBytes?: Uint8Array | undefined;
  releaseKeyJwk?: RsaPublicJwk | undefined;
  keyFlow?: 1 | 2 | 3 | undefined;
  privateKey?: CryptoKey | undefined;
  signerMaterial?: KeyMaterial | undefined;
  pkmd?: Uint8Array | undefined;
  fingerprintHex?: string | undefined;
  armoredBackup?: string | undefined;
  signedVbmeta?: Uint8Array | undefined;
  signView?: SignViewModel | undefined;
  deviceProduct?: string | undefined;
  lockState?: "locked" | "unlocked" | "unknown" | undefined;
  transport?: (Transport & { close?: () => Promise<void> }) | undefined;
  notice?: string | undefined;
  images: Record<string, Uint8Array>;
}

const session: Session = {
  state: initialInstallState("install"),
  picks: { package: false, sums: false, sig: false },
  packageName: "release.zip",
  images: {},
};

function sim(): boolean {
  return isSimMode(window.location.search);
}

function cleanup(): void {
  if (session.packageBytes) {
    zeroise(session.packageBytes);
  }
  if (session.sigBytes) {
    zeroise(session.sigBytes);
  }
  if (session.pkmd) {
    zeroise(session.pkmd);
  }
  if (session.signedVbmeta) {
    zeroise(session.signedVbmeta);
  }
  for (const buf of Object.values(session.images)) {
    zeroise(buf);
  }
  session.images = {};
  session.armoredBackup = undefined;
  session.privateKey = undefined;
  session.signerMaterial = undefined;
}

function dispatch(action: Parameters<typeof reduce>[1]): void {
  session.state = reduce(session.state, action);
  render();
}

function root(): HTMLElement {
  const el = document.getElementById("root");
  if (el === null) {
    throw new Error("#root missing");
  }
  return el;
}

function stepHtml(): string {
  const step = session.state.currentStep;
  const notice = session.notice ? `<p class="note" role="status">${escapeHtml(session.notice)}</p>` : "";
  if (step === 0) {
    return notice + renderStep0();
  }
  if (step === 1) {
    return notice + renderStep1(session.picks);
  }
  if (step === 2) {
    return (
      notice +
      `<label for="file-release-key">Release public key PEM (Q-04 is not baked into this build)</label>` +
      `<input type="file" id="file-release-key" data-role="release-key" />` +
      `<button type="button" class="btn-primary" data-action="verify-release">Verify release</button>`
    );
  }
  if (step === 3) {
    if (session.keyFlow === undefined) {
      return notice + renderStep3();
    }
    if (session.fingerprintHex === undefined) {
      return notice + renderStep3Collect(session.keyFlow);
    }
    return notice + renderStep3FlowDetail({ flow: session.keyFlow, fingerprintHex: session.fingerprintHex });
  }
  if (step === 4) {
    if (session.signView !== undefined && "algorithm" in session.signView) {
      return notice + renderStep4(session.signView);
    }
    return notice + renderStep4Collect();
  }
  if (step === 5) {
    return (
      notice +
      connectStepHtml({
        sim: sim(),
        usbPresent: usbAvailable(navigator) || sim(),
        oemUnlockAcked: session.state.completedSteps.has(5),
        ...(session.lockState !== undefined ? { lockState: session.lockState } : {}),
        ...(session.deviceProduct !== undefined
          ? {
              check: {
                expected: "tokay",
                actual: session.deviceProduct,
                match: session.deviceProduct === "tokay",
              },
            }
          : {}),
      }) +
      `<button type="button" class="btn-primary" data-action="oem-unlock-acked">I understand unlocking wipes the phone</button>` +
      `<button type="button" class="btn-primary" data-action="device-matched">Continue once the product matches</button>`
    );
  }
  if (step === 6) {
    return (
      notice +
      flashStepHtml({ sim: sim(), started: false, donePartitions: [] }) +
      `<section class="image-picks"><p>Pick each unpacked partition image. Enrolment writes your pkmd first; user-signed vbmeta is last.</p>` +
      [...FIRMWARE_ORDER, ...OS_ORDER]
        .map((name) => {
          const have = session.images[name] !== undefined ? " picked" : "";
          return `<label for="file-${name}">${name}${have}</label><input type="file" id="file-${name}" data-image="${name}" />`;
        })
        .join("") +
      `</section>` +
      `<button type="button" class="btn-primary" data-action="flash">Flash enrolment, images, then user-signed vbmeta</button>`
    );
  }
  if (step === 7) {
    return (
      notice +
      lockStepHtml({ sim: sim(), locked: false }) +
      `<button type="button" class="btn-primary" data-action="lock-confirmed">I confirmed lock on the device</button>`
    );
  }
  if (step === 8) {
    return (
      notice +
      verifyStepHtml({
        sim: sim(),
        enrolledFingerprint: session.fingerprintHex ?? "",
        outcome: "pending",
      })
    );
  }
  return notice + keepKeyStepHtml(sim());
}

function render(): void {
  root().innerHTML = renderInstallerChrome({ state: session.state, stepHtml: stepHtml() });
  const link = root().querySelector<HTMLAnchorElement>("[data-role='key-download-link']");
  if (link && session.armoredBackup) {
    const blob = new Blob([session.armoredBackup], { type: "application/octet-stream" });
    link.href = URL.createObjectURL(blob);
  }
}

async function readBytes(input: HTMLInputElement): Promise<Uint8Array | undefined> {
  const file = input.files?.[0];
  if (file === undefined) {
    return undefined;
  }
  return new Uint8Array(await file.arrayBuffer());
}

async function readText(input: HTMLInputElement): Promise<string | undefined> {
  const file = input.files?.[0];
  if (file === undefined) {
    return undefined;
  }
  return file.text();
}

async function onAction(action: string, target: HTMLElement): Promise<void> {
  session.notice = undefined;
  if (action === "acknowledge-intro") {
    dispatch({ type: "acknowledge-intro" });
    return;
  }
  if (action === "files-picked") {
    if (!filesReady(session.picks)) {
      session.notice = "All three release files must be picked.";
      render();
      return;
    }
    dispatch({ type: "files-picked" });
    return;
  }
  if (action === "verify-release") {
    if (!session.packageBytes || !session.sumsText || !session.sigBytes || !session.releaseKeyJwk) {
      session.notice = "Pick the package, SHA256SUMS, signature, and release public key first.";
      render();
      return;
    }
    const outcome = await verifyRelease({
      packageName: session.packageName,
      packageBytes: session.packageBytes,
      sumsText: session.sumsText,
      sigBytes: session.sigBytes,
      releaseKeyJwk: session.releaseKeyJwk,
      manifest: { buildId: "local", targetProduct: "tokay", version: "local" },
    });
    if (outcome.kind === "stop") {
      dispatch({ type: "stop", step: 2, condition: outcome.condition });
      return;
    }
    dispatch({ type: "release-verified" });
    return;
  }
  if (action === "key-flow-chosen") {
    const flow = Number(target.getAttribute("data-flow")) as 1 | 2 | 3;
    session.keyFlow = flow;
    session.state = reduce(session.state, { type: "key-flow-chosen", keyFlow: flow });
    render();
    return;
  }
  if (action === "generate-key") {
    const pass = root().querySelector<HTMLInputElement>("[data-role='generate-passphrase']")?.value ?? "";
    const result = await runGenerateFlow(pass);
    session.privateKey = result.privateKey;
    session.pkmd = result.pkmd;
    session.fingerprintHex = result.fingerprintHex;
    session.armoredBackup = result.armoredBackup;
    render();
    return;
  }
  if (action === "import-key") {
    const pemInput = root().querySelector<HTMLInputElement>("[data-role='user-pem']");
    const pem = pemInput ? await readText(pemInput) : undefined;
    const pass = root().querySelector<HTMLInputElement>("[data-role='import-passphrase']")?.value;
    if (!pem) {
      session.notice = "Pick a PEM file.";
      render();
      return;
    }
    const result = await runImportFlow(pem, pass === "" ? undefined : pass);
    session.signerMaterial = result.signerMaterial;
    session.pkmd = result.pkmd;
    session.fingerprintHex = result.fingerprintHex;
    render();
    return;
  }
  if (action === "import-public") {
    const pemInput = root().querySelector<HTMLInputElement>("[data-role='public-pem']");
    const pem = pemInput ? await readText(pemInput) : undefined;
    if (!pem) {
      session.notice = "Pick the public key PEM.";
      render();
      return;
    }
    const result = await runSignElsewhereFlow(pem);
    session.pkmd = result.pkmd;
    session.fingerprintHex = result.fingerprintHex;
    render();
    return;
  }
  if (action === "fingerprint-recorded") {
    if (!session.fingerprintHex || session.keyFlow === undefined) {
      return;
    }
    const typed = root().querySelector<HTMLInputElement>("[data-role='retype']")?.value ?? "";
    const saved = root().querySelector<HTMLInputElement>("[data-role='download-saved']")?.checked ?? false;
    const decision = step3Decide(session.fingerprintHex, session.keyFlow, {
      typedTail: typed,
      downloadSaved: saved,
    });
    if (decision.dispatch === null) {
      session.notice = decision.blockers.join(", ");
      render();
      return;
    }
    dispatch(decision.dispatch);
    return;
  }
  if (action === "sign-vbmeta") {
    const input = root().querySelector<HTMLInputElement>("[data-role='vbmeta']");
    const img = input ? await readBytes(input) : undefined;
    if (!img || !session.fingerprintHex) {
      session.notice = "Pick vbmeta.img and finish the key step first.";
      render();
      return;
    }
    const key = session.privateKey ?? session.signerMaterial;
    const outcome =
      key !== undefined
        ? await signVbmetaStep({
            kind: "sign",
            img,
            key,
            keyFingerprintHex: session.fingerprintHex,
          })
        : session.pkmd !== undefined
          ? await signVbmetaStep({
              kind: "import",
              img,
              expectedPkmd: session.pkmd,
              keyFingerprintHex: session.fingerprintHex,
            })
          : undefined;
    if (outcome === undefined) {
      session.notice = "No signing key is loaded.";
      render();
      return;
    }
    if (outcome.kind === "stop") {
      dispatch({ type: "stop", step: 4, condition: outcome.condition });
      return;
    }
    session.signedVbmeta = outcome.signedImage;
    session.signView = outcome.view;
    render();
    return;
  }
  if (action === "vbmeta-signed") {
    dispatch({ type: "vbmeta-signed" });
    return;
  }
  if (action === "pair-device") {
    await pairDevice();
    return;
  }
  if (action === "oem-unlock-acked") {
    dispatch({ type: "oem-unlock-acked" });
    return;
  }
  if (action === "device-matched" && session.deviceProduct) {
    dispatch({ type: "device-matched", product: session.deviceProduct });
    return;
  }
  if (action === "flash") {
    await flashNow();
    return;
  }
  if (action === "lock-confirmed") {
    dispatch({ type: "lock-confirmed" });
    return;
  }
  if (action === "finish") {
    dispatch({ type: "keep-key-acknowledged" });
  }
}

async function pairDevice(): Promise<void> {
  if (sim()) {
    session.transport = new SimulatedDevice({
      initiallyUnlocked: true,
      vars: { product: "tokay", unlocked: "yes", "max-download-size": "268435456" },
    });
    session.deviceProduct = "tokay";
    session.lockState = "unlocked";
    session.notice = "Simulated device paired. Nothing touches hardware.";
    render();
    return;
  }
  const picker = browserUsbPicker();
  if (picker === null) {
    session.notice = "WebUSB is not available. Use the CLI export path.";
    render();
    return;
  }
  session.transport = await webUsbTransport(picker);
  session.notice = "USB device claimed. Product and lock state will be read next.";
  render();
}

async function flashNow(): Promise<void> {
  if (!session.transport || !session.pkmd || !session.signedVbmeta) {
    session.notice = "Pair the device and finish signing before flashing.";
    render();
    return;
  }
  const log = collectingLog();
  await runFlashPlan({
    transport: session.transport,
    consoleSink: log,
    plan: {
      avbCustomKey: session.pkmd,
      firmware: FIRMWARE_ORDER.filter((name) => session.images[name] !== undefined).map((name) => ({
        partition: name,
        data: session.images[name] as Uint8Array,
      })),
      os: OS_ORDER.filter((name) => session.images[name] !== undefined).map((name) => ({
        partition: name,
        data: session.images[name] as Uint8Array,
      })),
      vbmeta: [{ partition: "vbmeta", data: session.signedVbmeta }],
    },
    gate: {
      state: session.state,
      release: { hashesMatch: true, signatureValid: true },
      device: { product: session.deviceProduct ?? "tokay", releaseTargetProduct: "tokay" },
      vbmeta: { signedWithUserKey: true },
    },
  });
  dispatch({ type: "flash-step-done" });
}

function onClick(event: Event): void {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }
  const action = target.getAttribute("data-action");
  if (action === null) {
    return;
  }
  void onAction(action, target).catch((err: unknown) => {
    session.notice = err instanceof Error ? err.message : "action failed";
    render();
  });
}

function onChange(event: Event): void {
  const target = event.target;
  if (!(target instanceof HTMLInputElement)) {
    return;
  }
  const role = target.getAttribute("data-role");
  if (role === "package" || role === "sums" || role === "sig") {
    void (async () => {
      if (role === "package") {
        session.packageBytes = await readBytes(target);
        session.packageName = target.files?.[0]?.name ?? session.packageName;
        session.picks = { ...session.picks, package: session.packageBytes !== undefined };
      } else if (role === "sums") {
        session.sumsText = await readText(target);
        session.picks = { ...session.picks, sums: session.sumsText !== undefined };
      } else {
        session.sigBytes = await readBytes(target);
        session.picks = { ...session.picks, sig: session.sigBytes !== undefined };
      }
      render();
    })();
    return;
  }
  const imageName = target.getAttribute("data-image");
  if (imageName !== null) {
    void (async () => {
      const data = await readBytes(target);
      if (data !== undefined) {
        session.images[imageName] = data;
        render();
      }
    })();
    return;
  }
  if (role === "release-key") {
    void (async () => {
      const pem = await readText(target);
      if (pem) {
        session.releaseKeyJwk = await armoredPemToJwk(pem);
      }
    })();
  }
}

function boot(): void {
  onPageHide(cleanup);
  root().addEventListener("click", onClick);
  root().addEventListener("change", onChange);
  render();
}

boot();
