/**
 * /install browser bootstrap. Holds session material in memory only,
 * wires data-action clicks to the machine, and zeroises buffers on pagehide.
 */
import { onPageHide, zeroise } from "../../lib/keys/zeroise.js";
import { initialInstallState, reduce, type InstallState } from "../../lib/install-state/machine.js";
import { armoredPemToJwk, type RsaPublicJwk } from "../../lib/verify/detached-sig.js";
import { SimulatedDevice } from "../../lib/fastboot/simulated-device.js";
import { FastbootClient, type Transport } from "../../lib/fastboot/client.js";
import { browserUsbPicker, webUsbTransport } from "../../lib/fastboot/usb.js";
import {
  classifyLiveTransportError,
  liveFlashRefusal,
  renderLiveTransportState,
  type LiveTransportState,
} from "../../lib/ui/live-transport.js";
import { LIVE_FLASH_CLAIMED } from "../../src/types.js";
import { collectingLog } from "../../lib/types.js";
import { escapeHtml } from "../../lib/ui/escape.js";
import type { KeyMaterial } from "../../lib/avb/signer.js";
import {
  DEFAULT_OFFERED_PRODUCT,
  deviceFromSearch,
  parseOfferedDevice,
  type OfferedProduct,
} from "../../lib/ui/offered-devices.js";
import {
  acknowledgementMatches,
  canCommitSelection,
  readinessFor,
  requiresAcknowledgement,
  selectionRefused,
} from "../../lib/ui/readiness.js";
import {
  evaluatePosture,
  postureOpen,
  postureRefusal,
  renderPostureGate,
  SHIPPED_POSTURE,
  type PostureApproval,
} from "../../lib/ui/posture-approval.js";
import {
  channelRefusal,
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
  type ReadinessGateView,
  type SignViewModel,
} from "./early-steps.js";
import {
  connectStepHtml,
  flashStepHtml,
  fingerprintsMatch,
  isSimMode,
  keepKeyStepHtml,
  lockStepHtml,
  usbAvailable,
  verifyStepHtml,
} from "./late-steps.js";
import { FIRMWARE_ORDER, OS_ORDER, runFlashPlan } from "./flash-runner.js";
import { assertPlanImagesPresent } from "../../src/plan.js";
import { GL_BTN_CONFIRM } from "../../lib/ui/pajamas.js";

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
  /**
   * The real transport's current state (F-WEBINSTALL-LIVE-TRANSPORT-UX). One
   * value from `lib/ui/live-transport.ts`, rendered through that module's
   * announcing region — never a second status mechanism, and never an advance.
   */
  transportState?: LiveTransportState | undefined;
  selectedProduct: OfferedProduct;
  /** BUILD-OK device awaiting the typed-codename acknowledgement (not yet selected). */
  pendingBuildOk?: OfferedProduct | undefined;
  /** The BUILD-OK device whose codename the user typed; the only committed BUILD-OK target. */
  acknowledgedBuildOk?: OfferedProduct | undefined;
  /** Step 8 boot-fingerprint comparison result (set by the compare action). */
  verifyOutcome?: "pending" | "match" | "mismatch" | undefined;
  /** The value the user typed at step 8, retained so a mismatch is not lost on re-render. */
  verifyTyped?: string | undefined;
  /**
   * The alpha-posture approval typed at step 6. Held as TYPED; whether it counts
   * is `evaluatePosture`'s decision, and it is bound to the product it was typed
   * for, so switching device invalidates it.
   */
  postureApproval?: PostureApproval | undefined;
  images: Record<string, Uint8Array>;
}

const session: Session = {
  state: initialInstallState("install"),
  picks: { package: false, sums: false, sig: false },
  packageName: "release.zip",
  selectedProduct: DEFAULT_OFFERED_PRODUCT,
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

/** Reason/remedy/name for the acknowledgement gate. */
function readinessGateView(product: OfferedProduct): ReadinessGateView {
  const info = readinessFor(product);
  return {
    product,
    deviceName: info.model,
    tier: info.tier,
    reason: info.reason,
    remedy: info.remedy,
  };
}

/**
 * Commit a picker selection. A product with **no packed channel** is refused
 * outright (F-WEBINSTALL-FLASHALL-PICKER-TRUTH acceptance (a)) — the selection
 * is never taken, and the refusal names the missing channel rather than leaving
 * the user at a dead end. A tier the host does not offer is refused likewise;
 * an acknowledgement-gated device (READY-ACK, BUILD-OK) is NOT selected here
 * either — it is parked as `pendingBuildOk` and the typed-codename gate is
 * rendered instead.
 */
function selectProduct(product: OfferedProduct): void {
  // (a) Channel gate first: it is the most basic fact — no channel, no offer.
  const noChannel = channelRefusal(product);
  if (noChannel !== undefined) {
    session.pendingBuildOk = undefined;
    session.notice = noChannel;
    render();
    return;
  }
  if (!canCommitSelection(product, session.acknowledgedBuildOk)) {
    session.pendingBuildOk = product;
    session.notice = undefined;
    render();
    return;
  }
  session.pendingBuildOk = undefined;
  session.selectedProduct = product;
  if (!requiresAcknowledgement(product)) {
    // Leaving an acknowledgement-gated target clears its acknowledgement;
    // re-selecting it later must be re-confirmed, exactly as the bash wizard
    // re-prompts.
    session.acknowledgedBuildOk = undefined;
  }
  session.deviceProduct = undefined;
  session.lockState = undefined;
  render();
}

/** Guard: refuse to advance or flash a target that is unofferable, unacknowledged, or has no packed channel. */
function refuseUnacknowledgedBuildOk(): boolean {
  // (a) A product with no packed channel can never be flashed, whatever else
  // was acknowledged — there is nothing on disk to write.
  const noChannel = channelRefusal(session.selectedProduct);
  if (noChannel !== undefined) {
    session.notice = noChannel;
    render();
    return true;
  }
  const refusal = selectionRefused(session.selectedProduct, session.acknowledgedBuildOk);
  if (refusal === undefined) {
    return false;
  }
  session.notice = refusal;
  render();
  return true;
}

/**
 * Everything that must precede the step body: the shared refusal notice and,
 * when the real transport is in one of its five states, that state's announced
 * region (`lib/ui/live-transport.ts` — the single announcement mechanism).
 */
function noticeBlock(): string {
  const notice = session.notice ? `<p class="note" role="status">${escapeHtml(session.notice)}</p>` : "";
  const transport =
    session.transportState === undefined ? "" : renderLiveTransportState(session.transportState);
  return notice + transport;
}

function stepHtml(): string {
  const step = session.state.currentStep;
  const notice = noticeBlock();
  if (step === 0) {
    const pending = session.pendingBuildOk;
    const gate = pending === undefined ? undefined : readinessGateView(pending);
    return notice + renderStep0(session.selectedProduct, gate);
  }
  if (step === 1) {
    return notice + renderStep1(session.picks);
  }
  if (step === 2) {
    return (
      notice +
      `<label for="file-release-key">Release public key PEM (Q-04 is not baked into this build)</label>` +
      `<input type="file" id="file-release-key" data-role="release-key" />` +
      `<button type="button" class="${GL_BTN_CONFIRM}" data-action="verify-release">Verify release</button>`
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
                expected: session.selectedProduct,
                actual: session.deviceProduct,
                match: session.deviceProduct === session.selectedProduct,
              },
            }
          : {}),
      }) +
      `<button type="button" class="${GL_BTN_CONFIRM}" data-action="oem-unlock-acked">I understand unlocking wipes the phone</button>` +
      `<button type="button" class="${GL_BTN_CONFIRM}" data-action="device-matched">Continue once the product matches</button>`
    );
  }
  if (step === 6) {
    const posture = evaluatePosture(SHIPPED_POSTURE, session.selectedProduct, session.postureApproval);
    const open = postureOpen(posture);
    const postureGate = renderPostureGate({
      verdict: posture,
      product: session.selectedProduct,
      deviceName: readinessFor(session.selectedProduct).model,
      ...(session.postureApproval !== undefined
        ? { typedCodename: session.postureApproval.typedCodename }
        : {}),
    });
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
      postureGate +
      `<button type="button" class="${GL_BTN_CONFIRM}" data-action="flash"${open ? "" : ` disabled aria-disabled="true"`}>Flash enrolment, images, then user-signed vbmeta</button>` +
      (open
        ? ""
        : `<p class="note">The flash action stays unavailable until the posture above is approved for this device.</p>`)
    );
  }
  if (step === 7) {
    return (
      notice +
      lockStepHtml({ sim: sim(), locked: false }) +
      `<button type="button" class="${GL_BTN_CONFIRM}" data-action="lock-confirmed">I confirmed lock on the device</button>`
    );
  }
  if (step === 8) {
    return (
      notice +
      verifyStepHtml({
        sim: sim(),
        enrolledFingerprint: session.fingerprintHex ?? "",
        ...(session.verifyTyped !== undefined ? { typed: session.verifyTyped } : {}),
        outcome: session.verifyOutcome ?? "pending",
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
  // A transport state describes the operation that just ran, so every new user
  // action starts from "no state" — a stale refusal can never be re-announced
  // (or mistaken for the current one) after the user tries again.
  session.transportState = undefined;
  if (action === "back") {
    dispatch({ type: "back" });
    return;
  }
  if (action === "acknowledge-intro") {
    dispatch({ type: "acknowledge-intro" });
    return;
  }
  if (action === "acknowledge-build-ok") {
    const pending = session.pendingBuildOk;
    if (pending === undefined) {
      session.notice = "No BUILD-OK device is waiting for confirmation.";
      render();
      return;
    }
    if (!requiresAcknowledgement(pending)) {
      // Fail closed: only an acknowledgement-gated tier is acknowledgeable.
      session.notice = `Device '${pending}' is ${readinessFor(pending).tier}; it is not offerable and cannot be acknowledged.`;
      render();
      return;
    }
    const typed = root().querySelector<HTMLInputElement>("[data-role='readiness-ack']")?.value ?? "";
    if (!acknowledgementMatches(pending, typed)) {
      session.notice = `Typed confirmation did not match '${pending}'. The ${readinessFor(pending).tier} build is not selected.`;
      render();
      return;
    }
    session.acknowledgedBuildOk = pending;
    session.selectedProduct = pending;
    session.pendingBuildOk = undefined;
    session.deviceProduct = undefined;
    session.lockState = undefined;
    session.notice = `BUILD-OK build '${pending}' selected after typed confirmation. Boot remains UNVERIFIED.`;
    render();
    return;
  }
  if (action === "cancel-build-ok") {
    session.pendingBuildOk = undefined;
    session.notice = "BUILD-OK selection cancelled. The READY device stays selected.";
    render();
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
      manifest: { buildId: "local", targetProduct: session.selectedProduct, version: "local" },
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
  if (action === "compare-fingerprint") {
    // Step 8's explicit user action. Nothing advances until the user submits
    // this comparison (D-018 AC (e)); a mismatch freezes the flow as a hard
    // stop rather than silently continuing.
    const typed =
      root().querySelector<HTMLInputElement>("#boot-fingerprint-input")?.value ?? "";
    session.verifyTyped = typed;
    const enrolled = session.fingerprintHex ?? "";
    if (enrolled === "") {
      session.notice = "Enrol a key at step 3 before comparing the boot fingerprint.";
      render();
      return;
    }
    if (fingerprintsMatch(typed, enrolled)) {
      session.verifyOutcome = "match";
      dispatch({ type: "boot-fingerprint-typed", fingerprint: typed });
      return;
    }
    session.verifyOutcome = "mismatch";
    dispatch({ type: "stop", step: 8, condition: "boot-fingerprint-mismatch" });
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
  if (action === "approve-posture") {
    // Record exactly what was typed — including an empty or wrong value — so the
    // gate can name the mismatch. The verdict decides; this line does not.
    const typed =
      root().querySelector<HTMLInputElement>("[data-role='posture-approval']")?.value ?? "";
    session.postureApproval = { typedCodename: typed, forProduct: session.selectedProduct };
    render();
    return;
  }
  if (action === "oem-unlock-acked") {
    dispatch({ type: "oem-unlock-acked" });
    return;
  }
  if (action === "device-matched") {
    if (refuseUnacknowledgedBuildOk()) {
      return;
    }
    if (!session.deviceProduct) {
      session.notice = "Pair a device before continuing.";
      render();
      return;
    }
    if (session.deviceProduct !== session.selectedProduct) {
      // (3) product mismatch. The state is set BEFORE the stop dispatch so the
      // re-render carries the announcement; the guard below in `flashNow()`
      // repeats the comparison, so no write can be reached by this step alone.
      session.transportState = {
        kind: "product-mismatch",
        expected: session.selectedProduct,
        actual: session.deviceProduct,
      };
      dispatch({ type: "stop", step: 5, condition: "product-mismatch" });
      return;
    }
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
      vars: {
        product: session.selectedProduct,
        unlocked: "yes",
        "max-download-size": "268435456",
      },
    });
    session.lockState = "unlocked";
    session.notice = "Simulated device paired. Nothing touches hardware.";
  } else {
    const picker = browserUsbPicker();
    if (picker === null) {
      // (4) WebUSB absent (non-Chromium, or not an HTTPS origin). The state's
      // headline IS the existing first-class notice, kept verbatim.
      session.transport = undefined;
      session.transportState = { kind: "webusb-absent" };
      render();
      return;
    }
    try {
      session.transport = await webUsbTransport(picker);
    } catch (err: unknown) {
      // (1) the user cancelled the picker, or the browser refused access. Any
      // other failure (e.g. the interface could not be claimed) is not one of
      // the five states, so it keeps the pre-existing handling: rethrow.
      const refusal = classifyLiveTransportError(err);
      if (refusal === undefined) {
        throw err;
      }
      session.transport = undefined;
      session.transportState = refusal;
      render();
      return;
    }
    session.notice = "USB device claimed. Product was read; nothing was written.";
  }
  if (session.transport === undefined) {
    session.notice = "No transport after pairing.";
    render();
    return;
  }
  try {
    const client = new FastbootClient(session.transport, collectingLog());
    session.deviceProduct = await client.getvar("product");
  } catch (err: unknown) {
    session.deviceProduct = undefined;
    // (2) the phone dropped while the product was being read. A state is used
    // ONLY when the error is a transport state; a plain read failure keeps the
    // verbatim message it always had.
    const disconnected = classifyLiveTransportError(err);
    if (disconnected !== undefined) {
      session.transportState = disconnected;
      render();
      return;
    }
    session.notice =
      err instanceof Error ? err.message : "USB device claimed. Product could not be read.";
  }
  render();
}

/** The images step 6 asks the user to pick, in the order the step renders them. */
function offeredImages(): { firmware: readonly string[]; os: readonly string[] } {
  return { firmware: FIRMWARE_ORDER, os: OS_ORDER };
}

function pickedImages(): { firmware: string[]; os: string[] } {
  const offered = offeredImages();
  return {
    firmware: offered.firmware.filter((name) => session.images[name] !== undefined),
    os: offered.os.filter((name) => session.images[name] !== undefined),
  };
}

/**
 * Refuse step 6 when a writable phase has no image picked
 * (T-WEBINSTALL-ORCHESTRATION-NO-IMAGE-GUARD). Without this, an empty pick
 * set degenerates the plan to the enrolment key + user-signed vbmeta, the
 * transcript is all `< OKAY`, and `flash-step-done` advances to step 7 as if
 * an OS had been written. The RULE is `assertPlanImagesPresent` (src/plan.ts,
 * shared with `buildFlashPlan`); this only renders the refusal by naming the
 * images step 6 still needs.
 */
function refuseMissingImages(): boolean {
  const picked = pickedImages();
  const missing = {
    firmware: offeredImages().firmware.filter((name) => !picked.firmware.includes(name)),
    os: offeredImages().os.filter((name) => !picked.os.includes(name)),
  };
  try {
    assertPlanImagesPresent({ firmware: picked.firmware, os: picked.os });
  } catch (err: unknown) {
    // Name the phase the shared rule refused. The rule runs firmware first, so
    // `firmware` is the only other phase a refusal can be about.
    const phase = err instanceof Error && err.message.startsWith("os ") ? "os" : "firmware";
    const named = missing[phase];
    const pickedCount = picked[phase].length;
    session.notice =
      `No ${phase} image is picked, so flashing would write no ${phase}. ` +
      `${pickedCount === 0 ? "Pick every image first" : "Still to pick"}: ${named.join(", ")}. ` +
      "Nothing was written and the flow stays at this step.";
    render();
    return true;
  }
  return false;
}

async function flashNow(): Promise<void> {
  if (refuseUnacknowledgedBuildOk()) {
    return;
  }
  // (5) The build-level gate, before any other prompt: while this build does not
  // claim a live flash (LIVE_FLASH_CLAIMED === false) a REAL transport cannot
  // write at all. Presenting that as a build posture here — rather than letting
  // the plan run and translating a failure afterwards — means the user is never
  // asked to approve a posture for an operation this build refuses to perform.
  // A simulated session writes to SimulatedDevice and is unaffected (D-011).
  const liveRefusal = liveFlashRefusal({ sim: sim(), liveFlashClaimed: LIVE_FLASH_CLAIMED });
  if (liveRefusal !== undefined) {
    session.transportState = liveRefusal;
    render();
    return;
  }
  // The alpha posture must be approved for THIS device before the first write.
  // Re-evaluated here rather than read from the DOM: the disabled button is a
  // courtesy, this is the refusal. Nothing below runs while it is closed.
  const postureBlock = postureRefusal(
    evaluatePosture(SHIPPED_POSTURE, session.selectedProduct, session.postureApproval),
    session.selectedProduct,
  );
  if (postureBlock !== undefined) {
    session.notice = postureBlock;
    render();
    return;
  }
  if (!session.transport || !session.pkmd || !session.signedVbmeta) {
    session.notice = "Pair the device and finish signing before flashing.";
    render();
    return;
  }
  if (session.deviceProduct !== session.selectedProduct) {
    // (3) the same guard the connect step uses, repeated immediately before the
    // plan is built: the mismatch is announced as a state and no plan is built.
    session.transportState = {
      kind: "product-mismatch",
      expected: session.selectedProduct,
      actual: session.deviceProduct ?? "",
    };
    render();
    return;
  }
  if (refuseMissingImages()) {
    return;
  }
  const log = collectingLog();
  const picked = pickedImages();
  try {
    await runFlashPlan({
      transport: session.transport,
      consoleSink: log,
      plan: {
        avbCustomKey: session.pkmd,
        firmware: picked.firmware.map((name) => ({
          partition: name,
          data: session.images[name] as Uint8Array,
        })),
        os: picked.os.map((name) => ({
          partition: name,
          data: session.images[name] as Uint8Array,
        })),
        vbmeta: [{ partition: "vbmeta", data: session.signedVbmeta }],
      },
      gate: {
        state: session.state,
        release: { hashesMatch: true, signatureValid: true },
        device: {
          product: session.deviceProduct,
          releaseTargetProduct: session.selectedProduct,
        },
        vbmeta: { signedWithUserKey: true },
      },
    });
  } catch (err: unknown) {
    // (2) mid-flow disconnect, or (5) a live-path HOLD thrown by the backend
    // orchestrator. Either way the flow STOPS: the advance below is inside no
    // catch, so no failure can reach it. Any other error (a bootloader FAIL) is
    // not a transport state and keeps its pre-existing handling.
    const halted = classifyLiveTransportError(err);
    if (halted === undefined) {
      throw err;
    }
    session.transportState = halted;
    render();
    return;
  }
  dispatch({ type: "flash-step-done" });
}

function onSubmit(event: Event): void {
  // D-018 (F-WEBINSTALL-FLASHALL-PROD-UI AC (a)): pressing Enter in a text
  // input submits the enclosing form WITHOUT firing a click on the submit
  // button. Without this handler the boot-fingerprint compare (step 8) and the
  // keep-key acknowledgement (step 9) are unreachable by keyboard alone. The
  // form's own submit button carries the `data-action`; we reuse it, and
  // suppress the default navigation so the page never reloads (CSP + offline).
  const form = event.target;
  if (!(form instanceof HTMLFormElement)) {
    return;
  }
  event.preventDefault();
  const action = form.querySelector<HTMLElement>("[data-action]")?.getAttribute("data-action");
  if (action === null || action === undefined) {
    return;
  }
  void onAction(action, form).catch((err: unknown) => {
    session.notice = err instanceof Error ? err.message : "action failed";
    render();
  });
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
  if (!(target instanceof HTMLInputElement) && !(target instanceof HTMLSelectElement)) {
    return;
  }
  const role = target.getAttribute("data-role");
  if (role === "target-product" && target instanceof HTMLSelectElement) {
    const parsed = parseOfferedDevice(target.value);
    if (parsed !== undefined) {
      selectProduct(parsed);
    }
    return;
  }
  if (!(target instanceof HTMLInputElement)) {
    return;
  }
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
  const requested = deviceFromSearch(window.location.search);
  // (a) A deep link cannot conjure a channel: a product with no packed channel
  // is refused up front and the default (packed) device stays selected.
  const noChannel = channelRefusal(requested);
  if (noChannel !== undefined) {
    session.notice = noChannel;
  } else if (requiresAcknowledgement(requested)) {
    // A deep link is not consent: park the acknowledgement-gated device behind
    // the gate and keep the READY default until the codename is typed.
    session.pendingBuildOk = requested;
    session.notice = `Device '${requested}' (${readinessFor(requested).tier}) is not selected from a link alone — confirm it below.`;
  } else {
    session.selectedProduct = requested;
  }
  onPageHide(cleanup);
  root().addEventListener("click", onClick);
  root().addEventListener("change", onChange);
  root().addEventListener("submit", onSubmit);
  render();
}

boot();
