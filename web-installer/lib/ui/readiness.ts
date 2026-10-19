/**
 * Readiness-tier policy for the web installer (F-EXCISE-WEBINSTALL-READINESS-GUARD,
 * extended by T-EXCISE-WEBINSTALL-ACK-ABSORB).
 *
 * Parity with the bash wizard's offerable tiers, whose data comes from the
 * canonical reporter `scripts/gt-ready-devices.sh`. That reporter and
 * `scripts/gt-flash-wizard.sh` are owned by other cards and are NOT edited
 * here. The browser is offline (CSP `connect-src 'none'`), so it cannot call
 * the reporter at runtime; instead the tiers are DERIVED into
 * `./readiness-manifest.ts` by `scripts/gen-readiness-manifest.sh`. There is no
 * hand-maintained second copy to drift.
 *
 * Honesty rule (programme-wide, ruling R5): BOOT_VERIFIED=false. `READY` means
 * "host clauses pass AND a stamp-provenance clause confers readiness", never
 * "this stamp boots". `READY-ACK` means host clauses pass, readiness is NOT
 * stamp-conferred, but a recorded, stamp-specific operator acknowledgement
 * accepts that residual — it is an accepted residual, NOT boot evidence.
 * `BUILD-OK` means host clauses pass but boot is UNVERIFIED. `HOLD` means host
 * clauses pass but the stamp is NOT-STAMP-VERIFIED and unacknowledged.
 *
 * A tier may be selected ONLY if `TIER_POLICY` says so, and a tier whose policy
 * requires an acknowledgement needs the exact codename typed — the control
 * `gt-flash-wizard.sh:176-201` already applies. HOLD and PENDING are not
 * offerable at all.
 *
 * FAIL-CLOSED (T-EXCISE-WEBINSTALL-ACK-ABSORB): a tier's authority is its
 * presence in the explicit `TIER_POLICY` map — never a string union and never a
 * `!== "BUILD-OK"` default. A tier (or an unknown token) absent from the map is
 * REFUSED, so adding a tier upstream cannot silently make it flashable.
 *
 * Nothing here is colour-only: every tier carries a word and a
 * machine-readable data attribute, so an automated check (and a screen reader)
 * can distinguish the tiers without seeing the chip.
 */
import {
  READINESS_MANIFEST,
  READINESS_MANIFEST_PROVENANCE,
  type ReadinessManifestEntry,
  type ReadinessStatus,
} from "./readiness-manifest.js";
import { isOfferedDevice, type OfferedProduct } from "./offered-devices.js";

/** Programme-wide: no hardware is attached, so no build is boot-verified. */
export const BOOT_VERIFIED = false;

export type ReadinessTier = ReadinessStatus;

/** What a tier is allowed to do. `requiresAcknowledgement` is the typed gate. */
export interface TierPolicy {
  /** May this tier be offered for flashing at all? */
  readonly offerable: boolean;
  /** Must the exact codename be typed before this tier may commit? */
  readonly requiresAcknowledgement: boolean;
}

/**
 * THE tier policy — the single source of truth for offerability and the
 * acknowledgement requirement. The `Record<ReadinessTier, TierPolicy>` type is
 * TOTAL: extending `ReadinessStatus` fails to compile until every tier is
 * classified here, and a token absent from the runtime map is refused below.
 */
export const TIER_POLICY: Readonly<Record<ReadinessTier, TierPolicy>> = Object.freeze({
  READY: Object.freeze({ offerable: true, requiresAcknowledgement: false }),
  "READY-ACK": Object.freeze({ offerable: true, requiresAcknowledgement: true }),
  "BUILD-OK": Object.freeze({ offerable: true, requiresAcknowledgement: true }),
  HOLD: Object.freeze({ offerable: false, requiresAcknowledgement: false }),
  PENDING: Object.freeze({ offerable: false, requiresAcknowledgement: false }),
});

function hasOwn<T>(record: Record<string, T>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(record, key);
}

/**
 * The policy for a tier, or `undefined` when the tier is not in the explicit
 * map. This is the fail-closed lookup: an unknown/added token has no policy and
 * every caller must therefore refuse it.
 */
export function tierPolicy(tier: string): TierPolicy | undefined {
  return hasOwn(TIER_POLICY, tier) ? TIER_POLICY[tier as ReadinessTier] : undefined;
}

/** Only tiers whose policy says `offerable` may be flashed. Derived, never listed twice. */
export const OFFERABLE_TIERS: readonly ReadinessTier[] = (
  Object.keys(TIER_POLICY) as ReadinessTier[]
).filter((tier) => TIER_POLICY[tier].offerable);

export function isOfferable(tier: string): boolean {
  return tierPolicy(tier)?.offerable === true;
}

/** Whether committing this tier requires the exact codename to be typed. */
export function tierRequiresAcknowledgement(tier: string): boolean {
  return tierPolicy(tier)?.requiresAcknowledgement === true;
}

/**
 * Chip word for a tier. Non-READY tiers name the residual, not just a colour,
 * and every tier has its own word. An unknown tier is visibly not offerable.
 */
const TIER_CHIP_WORD: Readonly<Record<ReadinessTier, string>> = Object.freeze({
  READY: "READY",
  "READY-ACK": "READY-ACK · OPERATOR-ACKNOWLEDGED, NOT STAMP-PROVEN",
  "BUILD-OK": "BUILD-OK · BOOT UNVERIFIED",
  HOLD: "HOLD · NOT-STAMP-VERIFIED",
  PENDING: "PENDING · NOT OFFERABLE",
});

export function readinessChipWord(tier: string): string {
  if (!hasOwn(TIER_CHIP_WORD, tier)) {
    return `UNKNOWN (${tier}) · NOT OFFERABLE`;
  }
  return TIER_CHIP_WORD[tier as ReadinessTier];
}

export interface ReadinessView {
  readonly tier: ReadinessTier;
  readonly model: string;
  readonly stamp: string;
  readonly reason: string;
  readonly remedy: string;
  readonly offerable: boolean;
  /** True for every acknowledgement-gated tier (READY-ACK, BUILD-OK). */
  readonly requiresAcknowledgement: boolean;
}

/** The shipped manifest row for a codename, or undefined when the host never listed it. */
export function manifestEntry(codename: string): ReadinessManifestEntry | undefined {
  return READINESS_MANIFEST.find((entry) => entry.codename === codename);
}

function tierOf(codename: string): ReadinessTier {
  // Fail closed: a device the reporter did not classify is treated as PENDING,
  // which is never offerable. Absence is never read as READY.
  return manifestEntry(codename)?.status ?? "PENDING";
}

export function readinessFor(product: OfferedProduct): ReadinessView {
  const entry = manifestEntry(product);
  const tier = tierOf(product);
  const policy = tierPolicy(tier);
  return {
    tier,
    model: entry?.model ?? product,
    stamp: entry?.stamp ?? "-",
    reason: entry?.reason ?? `the readiness report does not classify '${product}'`,
    remedy: entry?.remedy ?? "-",
    offerable: policy?.offerable === true,
    requiresAcknowledgement: policy?.requiresAcknowledgement === true,
  };
}

/**
 * Whether selecting this product needs a typed acknowledgement. True for
 * READY-ACK and BUILD-OK; false for READY and every non-offerable tier.
 */
export function requiresAcknowledgement(product: OfferedProduct): boolean {
  return readinessFor(product).requiresAcknowledgement;
}

/**
 * Backwards-compatible alias (the gate was originally BUILD-OK only). Kept so
 * existing callers/tests keep working; prefer `requiresAcknowledgement`.
 */
export const requiresBuildOkAcknowledgement = requiresAcknowledgement;

/**
 * Exact codename match, mirroring `gt-flash-wizard.sh`'s typed confirmation.
 * A bare `y` is not consent for a build with no proven boot; only the codename
 * itself counts. Surrounding whitespace is tolerated (the bash `read` strips
 * the trailing newline) but case is significant.
 */
export function acknowledgementMatches(product: OfferedProduct, typed: string): boolean {
  return typed.trim() === product;
}

/** Alias for `acknowledgementMatches`; the matcher now serves every ack tier. */
export const buildOkAcknowledgementMatches = acknowledgementMatches;

/**
 * Pure tier policy — the single place "may this commit?" is decided.
 * READY commits. READY-ACK and BUILD-OK commit only with their own codename
 * acknowledged. HOLD and PENDING never commit, whatever was acknowledged.
 * FAIL-CLOSED: a tier absent from `TIER_POLICY` is refused, not defaulted.
 */
export function canCommitTier(
  tier: string,
  product: string,
  acknowledged: string | undefined,
): boolean {
  const policy = tierPolicy(tier);
  if (policy === undefined || !policy.offerable) {
    // Unknown or non-offerable tier: refused, never read as "commits".
    return false;
  }
  if (!policy.requiresAcknowledgement) {
    return true;
  }
  return acknowledged === product;
}

/**
 * Whether a selection may commit. READY always commits; an acknowledgement-gated
 * tier commits only when this exact product has already been acknowledged with
 * its codename. HOLD/PENDING/unknown never commit, whatever was acknowledged.
 */
export function canCommitSelection(
  product: OfferedProduct,
  acknowledged: OfferedProduct | undefined,
): boolean {
  return canCommitTier(readinessFor(product).tier, product, acknowledged);
}

/** Guard for the flash path: an unofferable or unacknowledged target is refused. */
export function selectionRefused(
  product: string,
  acknowledged: OfferedProduct | undefined,
): string | undefined {
  if (!isOfferedDevice(product)) {
    return undefined;
  }
  const view = readinessFor(product);
  if (!view.offerable) {
    return `Device '${product}' is ${view.tier} (${view.reason}); it is not offerable for flashing.`;
  }
  if (!canCommitSelection(product, acknowledged)) {
    return `Device '${product}' is ${view.tier} — an acknowledgement of its codename is required before anything is flashed (${readinessChipWord(view.tier)}).`;
  }
  return undefined;
}

/** Provenance of the shipped manifest, surfaced so the UI can state its source. */
export const READINESS_PROVENANCE = READINESS_MANIFEST_PROVENANCE;
