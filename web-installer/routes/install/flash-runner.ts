/**
 * Flash orchestration for /install step 6 (PLAN.md §1) — the ONE place that
 * issues flash commands.
 *
 * Guarantees:
 * - canFlash gate re-checked INTERNALLY before the first write (defence in
 *   depth: callers gate too, but nothing can reach a partition without it).
 * - Fixed order (PLAN.md §1 step 6): avb_custom_key → factory firmware
 *   (bootloader/radio/boot/vendor_boot/dtbo) → GuardTalkOS OS images
 *   (system/system_ext/product/vendor) → user-signed vbmeta(s) LAST.
 * - Every fastboot command + response flows verbatim into the console sink
 *   via FastbootClient's injectable log.
 * - Any FAIL ⇒ FastbootError propagates with the verbatim bootloader reason;
 *   no further commands are sent and later partitions stay untouched.
 */
import { FastbootClient, type FlashOptions, type Progress, type Transport } from "../../lib/fastboot/client.js";
import { MAX_DOWNLOAD_SIZE_VAR, parseMaxDownloadSize } from "../../lib/fastboot/protocol.js";
import { canFlash, type DeviceReadback, type ReleaseVerification, type VbmetaSigning } from "../../lib/install-state/index.js";
import { STOP_REASONS } from "../../lib/install-state/stops.js";
import { proveVbmetaUserSigned } from "../../lib/verify/user-anchor.js";
import type { InstallState } from "../../lib/install-state/machine.js";
import type { ConsoleLog } from "../../lib/types.js";

/** Factory images in canonical flash order (PLAN.md §1 step 6). */
export const FIRMWARE_ORDER = ["bootloader", "radio", "boot", "vendor_boot", "dtbo"] as const;

/** GuardTalkOS partitions in canonical flash order. */
export const OS_ORDER = ["system", "system_ext", "product", "vendor"] as const;

export interface FlashImage {
  readonly partition: string;
  readonly data: Uint8Array;
}

export interface FlashPlan {
  /** YOUR public key, avb_pkmd.bin form — flashed FIRST (key enrolment). */
  readonly avbCustomKey?: Uint8Array;
  readonly firmware: ReadonlyArray<FlashImage>;
  readonly os: ReadonlyArray<FlashImage>;
  /**
   * User-signed vbmeta image(s), flashed LAST — verified boot anchors only
   * after every writable partition already carries this session's content
   * (PLAN.md §2 custody contract item 5: the boot anchor is USER-signed).
   */
  readonly vbmeta: ReadonlyArray<FlashImage>;
}

/** Gate inputs required by runFlashPlan; mirrors lib/install-state gates.ts. */
export interface FlashGateInputs {
  readonly state: InstallState;
  readonly release: ReleaseVerification;
  readonly device: DeviceReadback;
  readonly vbmeta: VbmetaSigning;
}

/** One completed partition write. */
export interface PartitionResult {
  readonly partition: string;
  readonly phase: "enrol" | "firmware" | "os" | "vbmeta";
  readonly bytes: number;
}

export interface RunFlashPlanDeps {
  readonly transport: Transport;
  readonly consoleSink: ConsoleLog;
  readonly onProgress?: (progress: Progress) => void;
  readonly plan: FlashPlan;
  readonly gate: FlashGateInputs;
  /**
   * Download budget override (bytes). Production callers MUST omit this and
   * let runFlashPlan fetch `getvar:max-download-size` itself; the explicit
   * value exists for tests and offline replays. When provided it must parse
   * as a usable budget — an absurd value stops the flow, never a guess.
   */
  readonly maxDownloadSize?: number;
  readonly signal?: AbortSignal;
}

/**
 * H1 stop: the device's download budget is missing or unusable. Raised BEFORE
 * any transfer — flashing without a known budget would send one unchunked
 * download that most bootloaders reject at DATA time, and guessing a chunk
 * size is forbidden.
 */
export class MaxDownloadSizeError extends Error {
  readonly code = "MAX_DOWNLOAD_SIZE_UNAVAILABLE";
  constructor(detail: string) {
    super(`${STOP_REASONS.MAX_DOWNLOAD_SIZE_UNAVAILABLE} (${detail})`);
    this.name = this.constructor.name;
  }
}

async function resolveMaxDownloadSize(deps: RunFlashPlanDeps): Promise<number> {
  if (deps.maxDownloadSize !== undefined) {
    return assertUsableBudget(deps.maxDownloadSize);
  }
  const client = new FastbootClient(deps.transport, deps.consoleSink);
  try {
    const raw = await client.getvar(MAX_DOWNLOAD_SIZE_VAR);
    return assertUsableBudget(parseMaxDownloadSize(raw));
  } catch (error) {
    throw new MaxDownloadSizeError(
      error instanceof Error ? error.message : "unparseable max-download-size",
    );
  }
}

function assertUsableBudget(value: number): number {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new MaxDownloadSizeError(`unusable max-download-size ${JSON.stringify(String(value))}`);
  }
  return value;
}

export class FlashGateError extends Error {
  readonly blockers: readonly string[];
  constructor(blockers: readonly string[]) {
    super(`${STOP_REASONS.FLASH_GATE_NOT_SATISFIED}: ${blockers.join("; ")}`);
    this.name = this.constructor.name;
    this.blockers = blockers;
  }
}

function orderedFirmware(plan: FlashPlan): ReadonlyArray<FlashImage> {
  return [...plan.firmware].sort((a, b) => rank(FIRMWARE_ORDER, a.partition) - rank(FIRMWARE_ORDER, b.partition));
}

function orderedOs(plan: FlashPlan): ReadonlyArray<FlashImage> {
  return [...plan.os].sort((a, b) => rank(OS_ORDER, a.partition) - rank(OS_ORDER, b.partition));
}

function rank<const T extends readonly string[]>(order: T, partition: string): number {
  const index = order.indexOf(partition);
  return index === -1 ? order.length : index;
}

async function flashOne(
  client: FastbootClient,
  image: FlashImage,
  phase: PartitionResult["phase"],
  deps: RunFlashPlanDeps,
  maxDownloadSize: number,
  byteOffset: number,
): Promise<PartitionResult> {
  // Per-partition byte counts are offset by everything already written so the
  // UI progress bar moves monotonically across the WHOLE plan; partition
  // switches are visible as explicit label changes, not bar resets.
  const onProgress =
    deps.onProgress === undefined
      ? undefined
      : (progress: Progress): void => {
          deps.onProgress?.({ ...progress, bytesSent: progress.bytesSent + byteOffset });
        };
  const options: FlashOptions = {
    maxDownloadSize: maxDownloadSize,
  };
  if (onProgress !== undefined) {
    options.onProgress = onProgress;
  }
  if (deps.signal !== undefined) {
    options.signal = deps.signal;
  }
  await client.flash(image.partition, image.data, options);
  return { partition: image.partition, phase, bytes: image.data.length };
}

/**
 * Drive `plan` over `deps.transport`. Throws BEFORE any command is sent when
 * the canFlash gate is unsatisfied; any FastbootError propagates immediately
 * out of runFlashPlan with the verbatim bootloader reason — the loop never
 * continues past a failure, so later partitions stay untouched.
 */
export async function runFlashPlan(deps: RunFlashPlanDeps): Promise<readonly PartitionResult[]> {
  const { gate } = deps;
  if (!canFlash(gate.state, gate.release, gate.device, gate.vbmeta)) {
    throw new FlashGateError(["flash gate unsatisfied"]);
  }

  // Custom-key spine: every vbmeta in the plan must verify against the
  // enrolled pkmd before any partition is written. A missing pkmd with a
  // present vbmeta is the same refuse — we never flash a GuardTalk-signed
  // (or unsigned) anchor as if it were the user's.
  if (deps.plan.vbmeta.length > 0) {
    const enrolled = deps.plan.avbCustomKey;
    if (enrolled === undefined) {
      throw new FlashGateError([STOP_REASONS.USER_ANCHOR_MISMATCH]);
    }
    for (const image of deps.plan.vbmeta) {
      const proof = await proveVbmetaUserSigned(image.data, enrolled);
      if (!proof.ok) {
        throw new FlashGateError([proof.reason ?? STOP_REASONS.USER_ANCHOR_MISMATCH]);
      }
    }
  }

  // H1: the budget is fetched from THE DEVICE before anything is written.
  // A missing/unusable variable stops the whole plan (MaxDownloadSizeError)
  // instead of attempting one unchunked download.
  const maxDownloadSize = await resolveMaxDownloadSize(deps);

  const client = new FastbootClient(deps.transport, deps.consoleSink);
  const results: PartitionResult[] = [];
  let cumulativeBytes = 0;

  if (deps.plan.avbCustomKey !== undefined) {
    const enrolImage = { partition: "avb_custom_key", data: deps.plan.avbCustomKey };
    results.push(await flashOne(client, enrolImage, "enrol", deps, maxDownloadSize, cumulativeBytes));
    cumulativeBytes += enrolImage.data.length;
  }
  for (const image of orderedFirmware(deps.plan)) {
    results.push(await flashOne(client, image, "firmware", deps, maxDownloadSize, cumulativeBytes));
    cumulativeBytes += image.data.length;
  }
  for (const image of orderedOs(deps.plan)) {
    results.push(await flashOne(client, image, "os", deps, maxDownloadSize, cumulativeBytes));
    cumulativeBytes += image.data.length;
  }
  for (const anchor of deps.plan.vbmeta) {
    results.push(await flashOne(client, anchor, "vbmeta", deps, maxDownloadSize, cumulativeBytes));
    cumulativeBytes += anchor.data.length;
  }
  return results;
}
