/**
 * Pure gate evaluators consumed by the UI. A flash call may only be made when
 * release verification, device/target match, and a user-signed vbmeta (user
 * key — never a GuardTalk anchor) have ALL reported success.
 */
import type { InstallState } from "./machine.js";
import { STOP_REASONS } from "./stops.js";

export interface ReleaseVerification {
  readonly hashesMatch: boolean;
  readonly signatureValid: boolean;
}

export interface DeviceReadback {
  readonly product: string;
  readonly releaseTargetProduct: string;
}

export interface VbmetaSigning {
  readonly signedWithUserKey: boolean;
  readonly digestHex?: string;
}

export function canFlash(
  state: InstallState,
  release: ReleaseVerification,
  device: DeviceReadback,
  vbmeta: VbmetaSigning,
): boolean {
  return flashBlockers(state, release, device, vbmeta).length === 0;
}

/** Ordered, human-readable blockers; empty array means flashing is permitted. */
export function flashBlockers(
  state: InstallState,
  release: ReleaseVerification,
  device: DeviceReadback,
  vbmeta: VbmetaSigning,
): readonly string[] {
  const blockers: string[] = [];
  if (!(release.hashesMatch && release.signatureValid)) {
    blockers.push("release not verified");
  }
  if (device.product !== device.releaseTargetProduct) {
    blockers.push(STOP_REASONS.PRODUCT_MISMATCH);
  }
  if (!vbmeta.signedWithUserKey) {
    blockers.push("vbmeta is not signed with your key");
  }
  if (!state.completedSteps.has(2)) {
    blockers.push("release verification step not completed");
  }
  if (!state.completedSteps.has(4)) {
    blockers.push("signing step not completed");
  }
  return blockers;
}
