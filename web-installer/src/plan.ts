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

/**
 * One writable image offered to a plan, before it is put in canonical order.
 * The rule below only COUNTS a phase, so a plan that has resolved its images
 * to artifact NAMES satisfies it as-is — no second mapping step to keep in
 * sync.
 */
export type PlanImage = { readonly partition: string } | string;

/** The image-bearing phases of a plan (avb_custom_key is the key enrolment). */
export interface PlanImages {
  readonly firmware: readonly PlanImage[];
  readonly os: readonly PlanImage[];
}

/**
 * Refuse a plan that carries no writable partition image. `firmware` and `os`
 * are BOTH optional on the input — the rule asserts only the phases the caller
 * actually supplies, so an appender that has not built the other phase yet
 * (or the route's inline plan) is judged on the phase it owns. There is no way
 * to express "present but empty" other than `[]`, which is refused.
 *
 * This is the single implementation of the empty-phase rule (TASK
 * T-WEBINSTALL-ORCHESTRATION-NO-IMAGE-GUARD). It is driven by the
 * `FLASH_ORDER` phases rather than by hand-picked fixed partitions, so
 * `FIRMWARE_ORDER`/`OS_ORDER` in `routes/install/flash-runner.ts` stay a UI
 * subset (ordering + which picks step 6 renders) and never a second, narrower
 * authority on what "required" means.
 */
export function assertPlanImagesPresent(plan: {
  readonly firmware?: readonly PlanImage[];
  readonly os?: readonly PlanImage[];
}): void {
  for (const phase of FLASH_ORDER) {
    if (phase === "avb_custom_key") {
      // Key enrolment is verified separately (pkmd must match the vbmeta
      // anchor); it is not a partition image and never satisfies this rule.
      continue;
    }
    const images: readonly PlanImage[] | undefined = plan[phase];
    if (images !== undefined && images.length === 0) {
      throw new PlanError(`${phase} phase is empty`);
    }
  }
}

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
  assertPlanImagesPresent({ firmware: names });
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

/** tokay + akita + komodo share UART/FIPS/DPM cleanup (same as CLI). */
function appendPixelHousekeeping(steps: PlanStep[]): void {
  steps.push({ kind: "command", phase: "avb_custom_key", command: "oem uart disable" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "fips" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "dpm_a" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "dpm_b" });
}

function appendOsSteps(channel: ChannelBundle, steps: PlanStep[]): void {
  const names = namesForPhase(channel, "os");
  assertPlanImagesPresent({ os: names });
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
