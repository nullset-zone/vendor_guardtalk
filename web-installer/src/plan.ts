import { PlanError } from "./errors.js";
import { assertAllowedProduct } from "./allowlist.js";
import {
  FLASH_ORDER,
  type ChannelBundle,
  type FlashOrderPhase,
  type FlashPlan,
  type PlanStep,
} from "./types.js";

const C_COLLATOR = new Intl.Collator("en", { sensitivity: "variant" });

/** Build a deterministic plan: firmware → avb_custom_key → OS (DEC-006). */
export function buildFlashPlan(channel: ChannelBundle): FlashPlan {
  const steps: PlanStep[] = [];
  assertAllowedProduct(channel.manifest.product);
  appendFirmwareSteps(channel, steps);
  appendAvbSteps(channel, steps);
  appendPixelHousekeeping(steps);
  appendOsSteps(channel, steps);
  assertPhaseOrder(steps);
  return {
    product: channel.manifest.product,
    flashOrder: FLASH_ORDER,
    steps,
  };
}

export function flashPhaseSequence(plan: FlashPlan): FlashOrderPhase[] {
  const phases: FlashOrderPhase[] = [];
  for (const step of plan.steps) {
    if (step.kind !== "flash") {
      continue;
    }
    const prev = phases[phases.length - 1];
    if (prev !== step.phase) {
      phases.push(step.phase);
    }
  }
  return phases;
}

function namesForPhase(channel: ChannelBundle, phase: "firmware" | "avb" | "os"): string[] {
  return channel.files
    .filter((f) => f.phase === phase)
    .map((f) => f.name)
    .sort((a, b) => C_COLLATOR.compare(a, b));
}

function appendFirmwareSteps(channel: ChannelBundle, steps: PlanStep[]): void {
  const names = namesForPhase(channel, "firmware");
  if (names.length === 0) {
    throw new PlanError("firmware phase is empty");
  }
  for (const name of names) {
    steps.push({
      kind: "flash",
      phase: "firmware",
      artifact: name,
      partition: partitionFor(name),
    });
  }
  steps.push({
    kind: "reconnect",
    phase: "firmware",
    reason: "firmware written; WebUSB session dropped after reboot-bootloader",
  });
}

function appendAvbSteps(channel: ChannelBundle, steps: PlanStep[]): void {
  const names = namesForPhase(channel, "avb");
  if (names.length !== 1 || names[0] !== "avb_pkmd.bin") {
    throw new PlanError("avb phase must be exactly avb_pkmd.bin");
  }
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "avb_custom_key" });
  steps.push({
    kind: "flash",
    phase: "avb_custom_key",
    artifact: "avb_pkmd.bin",
    partition: "avb_custom_key",
  });
}

/** tokay + akita share UART/FIPS/DPM cleanup (same as CLI). */
function appendPixelHousekeeping(steps: PlanStep[]): void {
  steps.push({ kind: "command", phase: "avb_custom_key", command: "oem uart disable" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "fips" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "dpm_a" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "dpm_b" });
}

function appendOsSteps(channel: ChannelBundle, steps: PlanStep[]): void {
  const names = namesForPhase(channel, "os");
  if (names.length === 0) {
    throw new PlanError("os phase is empty");
  }
  for (const name of names) {
    steps.push({
      kind: "flash",
      phase: "os",
      artifact: name,
      partition: partitionFor(name),
    });
  }
  steps.push({
    kind: "reconnect",
    phase: "os",
    reason: "OS written; reconnect after reboot-bootloader",
  });
}

function partitionFor(name: string): string {
  if (name === "avb_pkmd.bin") {
    return "avb_custom_key";
  }
  if (name.endsWith(".img")) {
    return name.slice(0, -".img".length);
  }
  throw new PlanError(`cannot map artifact '${name}' to a partition`);
}

function assertPhaseOrder(steps: PlanStep[]): void {
  const flashes = steps.filter((s) => s.kind === "flash");
  const phases: FlashOrderPhase[] = [];
  for (const step of flashes) {
    const prev = phases[phases.length - 1];
    if (prev !== step.phase) {
      phases.push(step.phase);
    }
  }
  if (phases.length !== FLASH_ORDER.length) {
    throw new PlanError("flash steps must cover firmware → avb_custom_key → os");
  }
  for (let i = 0; i < FLASH_ORDER.length; i += 1) {
    if (phases[i] !== FLASH_ORDER[i]) {
      throw new PlanError("flash step order must be firmware → avb_custom_key → os");
    }
  }
}
