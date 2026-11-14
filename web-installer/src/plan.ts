import { PlanError } from "./errors.js";
import { assertAllowedProduct } from "./allowlist.js";
import {
  FLASH_ORDER,
  type BootChainMode,
  type ChannelBundle,
  type FlashOrderPhase,
  type FlashPlan,
  type PlanStep,
  type SuperMode,
} from "./types.js";

const C_COLLATOR = new Intl.Collator("en", { sensitivity: "variant" });

const LOGICAL_PARTITIONS = new Set([
  "system",
  "system_ext",
  "product",
  "vendor",
  "vendor_dlkm",
  "system_dlkm",
]);

/** Laguna/muzel + rango must NOT erase `fips` (matches scripts/flash-from-remote.sh). */
const NO_FIPS_ERASE_PRODUCTS = new Set(["rango", "mustang", "blazer", "frankel"]);

/** Extended GuardTalk targets supported by FlashPlan when explicitly enabled. */
const EXTENDED_PLAN_PRODUCTS = new Set(["caiman", "stallion", "frankel", "blazer"]);

export interface FlashPlanOptions {
  readonly bootChain?: BootChainMode;
  readonly bootloaderDualSlot?: boolean;
  readonly superMode?: "auto" | "super" | "super_empty";
  readonly rescueBootArtifacts?: readonly string[];
  readonly allowExtendedProduct?: boolean;
}

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
export function buildFlashPlan(
  channel: ChannelBundle,
  options: FlashPlanOptions = {},
): FlashPlan {
  const steps: PlanStep[] = [];
  const product = channel.manifest.product.trim();
  if (!(options.allowExtendedProduct && EXTENDED_PLAN_PRODUCTS.has(product))) {
    assertAllowedProduct(product);
  }
  const bootChain: BootChainMode = options.bootChain ?? "gt";
  const bootloaderDualSlot = options.bootloaderDualSlot === true;
  const osNames = namesForPhase(channel, "os");
  const superMode = resolveSuperMode(osNames, options.superMode ?? "auto");

  appendFirmwareSteps(channel, steps, bootloaderDualSlot);
  appendAvbSteps(channel, steps);
  appendPixelHousekeeping(product, steps);
  appendOsSteps(channel, steps, { bootChain, superMode, rescueBootArtifacts: options.rescueBootArtifacts });
  assertPhaseOrder(steps);
  return {
    product,
    flashOrder: FLASH_ORDER,
    steps,
    bootChain,
    superMode,
    bootloaderDualSlot,
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

function resolveSuperMode(
  osNames: readonly string[],
  requested: "auto" | "super" | "super_empty",
): SuperMode {
  const hasSuper = osNames.includes("super.img");
  const hasSuperEmpty = osNames.includes("super_empty.img");
  if (requested === "super") {
    if (!hasSuper) {
      throw new PlanError("superMode='super' requested but super.img is absent from os phase");
    }
    return "super";
  }
  if (requested === "super_empty") {
    if (!hasSuperEmpty) {
      throw new PlanError(
        "superMode='super_empty' requested but super_empty.img is absent from os phase",
      );
    }
    return "super_empty";
  }
  if (hasSuper) {
    return "super";
  }
  if (hasSuperEmpty) {
    return "super_empty";
  }
  return "direct";
}

function appendFirmwareSteps(
  channel: ChannelBundle,
  steps: PlanStep[],
  bootloaderDualSlot: boolean,
): void {
  const names = namesForPhase(channel, "firmware");
  assertPlanImagesPresent({ firmware: names });
  for (const name of names) {
    if (bootloaderDualSlot && name === "bootloader.img") {
      // GrapheneOS --slot=other dance (both A/B slots)
      steps.push({
        kind: "flash",
        phase: "firmware",
        artifact: name,
        partition: "bootloader",
        slot: "other",
      });
      steps.push({ kind: "command", phase: "firmware", command: "set_active:other" });
      steps.push({
        kind: "reconnect",
        phase: "firmware",
        reason: "bootloader slot A/B pass 1; reconnect after reboot-bootloader",
      });
      steps.push({
        kind: "flash",
        phase: "firmware",
        artifact: name,
        partition: "bootloader",
        slot: "other",
      });
      steps.push({ kind: "command", phase: "firmware", command: "set_active:other" });
      steps.push({
        kind: "reconnect",
        phase: "firmware",
        reason: "bootloader slot A/B pass 2; reconnect after reboot-bootloader",
      });
      continue;
    }
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

/** Device-specific UART/FIPS/DPM cleanup matching scripts/flash-from-remote.sh. */
function appendPixelHousekeeping(product: string, steps: PlanStep[]): void {
  steps.push({ kind: "command", phase: "avb_custom_key", command: "oem uart disable" });
  if (!NO_FIPS_ERASE_PRODUCTS.has(product)) {
    steps.push({ kind: "erase", phase: "avb_custom_key", partition: "fips" });
  }
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "dpm_a" });
  steps.push({ kind: "erase", phase: "avb_custom_key", partition: "dpm_b" });
}

function appendOsSteps(
  channel: ChannelBundle,
  steps: PlanStep[],
  opts: {
    bootChain: BootChainMode;
    superMode: SuperMode;
    rescueBootArtifacts?: readonly string[] | undefined;
  },
): void {
  const names = namesForPhase(channel, "os");
  assertPlanImagesPresent({ os: names });

  if (opts.superMode === "direct") {
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
    return;
  }

  // Hybrid rescue boot chain (laguna: frankel/rango/blazer): flash rescue boot
  // artifacts first so `reboot fastboot` can reach userspace fastbootd.
  const rescueSet = new Set(opts.rescueBootArtifacts ?? []);
  if (opts.bootChain === "hybrid" && rescueSet.size > 0) {
    for (const artifact of opts.rescueBootArtifacts ?? []) {
      if (!names.includes(artifact)) {
        throw new PlanError(`hybrid rescue artifact '${artifact}' missing from os phase`);
      }
      steps.push({
        kind: "flash",
        phase: "os",
        artifact,
        partition: partitionFor(artifact),
      });
    }
  }

  if (opts.superMode === "super_empty") {
    steps.push({
      kind: "wipe-super",
      phase: "os",
      artifact: "super_empty.img",
      reason: "wipe dynamic partition metadata via super_empty.img",
    });
    steps.push({
      kind: "reboot-fastboot",
      phase: "os",
      reason: "enter fastbootd (is-userspace=yes) to flash logical partitions",
    });
    for (const name of names) {
      if (name === "super_empty.img" || name === "super.img") {
        continue;
      }
      const part = partitionFor(name);
      if (LOGICAL_PARTITIONS.has(part)) {
        steps.push({
          kind: "flash",
          phase: "os",
          artifact: name,
          partition: part,
        });
      }
    }
    steps.push({
      kind: "reconnect",
      phase: "os",
      reason: "logical partitions written; return to bootloader before boot chain & vbmeta",
    });
    for (const name of names) {
      if (name === "super_empty.img" || name === "super.img" || rescueSet.has(name)) {
        continue;
      }
      const part = partitionFor(name);
      if (!LOGICAL_PARTITIONS.has(part)) {
        steps.push({
          kind: "flash",
          phase: "os",
          artifact: name,
          partition: part,
        });
      }
    }
  } else {
    // superMode === "super"
    if (opts.bootChain === "hybrid") {
      steps.push({
        kind: "reboot-fastboot",
        phase: "os",
        reason: "enter fastbootd under hybrid rescue boot chain",
      });
    }
    if (names.includes("super.img")) {
      steps.push({
        kind: "flash",
        phase: "os",
        artifact: "super.img",
        partition: "super",
      });
    }
    if (opts.bootChain === "hybrid") {
      steps.push({
        kind: "reconnect",
        phase: "os",
        reason: "return to bootloader after fastbootd before GuardTalk boot chain & vbmeta",
      });
    }
    for (const name of names) {
      if (name === "super.img" || name === "super_empty.img" || rescueSet.has(name)) {
        continue;
      }
      steps.push({
        kind: "flash",
        phase: "os",
        artifact: name,
        partition: partitionFor(name),
      });
    }
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
