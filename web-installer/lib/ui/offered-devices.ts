/**
 * Shared advertised-device labels for the wizard picker and `/install`
 * (DEC-WEBINSTALL-015). Rango is selectable as experimental / boot HOLD —
 * not production-boot-green. Unstamped shiba / husky / caiman are not offered.
 *
 * Lives under lib/ui so route dist (build-site.sh copies lib/) can import it.
 * wizard/devices.ts re-exports this module.
 *
 * DEC-010: listing komodo is not a signed-user FLASH_READY claim for
 * `komodo-20260915-063833`.
 *
 * IMPORT CONSTRAINT: this module must not import `./readiness.js` — that module
 * imports THIS one, and a cycle breaks the named re-exports at load time. The
 * readiness-tier half of "selectable" is therefore composed by the caller
 * (`isSelectableByPolicy` below takes the tier as a plain boolean input).
 */
import { hasPackedChannel } from "./packed-channels.js";

/** Current advertised komodo stamp is userdebug/test-keys, not FLASH_READY. */
export const KOMODO_STAMP_HONESTY =
  "The current komodo stamp komodo-20260915-063833 is userdebug/test-keys, not a signed user FLASH_READY image. LIVE_FLASH_CLAIMED=false.";

export type OfferedDeviceStatus = "supported" | "experimental";

/**
 * Boot-readiness tiers are NOT declared here. They are derived from the
 * canonical reporter `scripts/gt-ready-devices.sh` into
 * `./readiness-manifest.ts` by `scripts/gen-readiness-manifest.sh`, and read
 * through `./readiness.ts`. Keeping the tiers out of this file is deliberate:
 * a hand-maintained second copy of the host's classification is exactly the
 * drift the bash wizard avoids by consuming the reporter's TSV.
 */
export interface WizardDevice {
  readonly id: "tokay" | "akita" | "komodo" | "rango";
  /** Marketing name shown in the /install table (e.g. Pixel 9). */
  readonly deviceName: string;
  /** Picker option text. Experimental devices name HOLD in the label. */
  readonly label: string;
  readonly status: OfferedDeviceStatus;
}

export const WIZARD_DEVICES: readonly WizardDevice[] = [
  { id: "tokay", deviceName: "Pixel 9", label: "Pixel 9 (tokay)", status: "supported" },
  { id: "akita", deviceName: "Pixel 8a", label: "Pixel 8a (akita)", status: "supported" },
  { id: "komodo", deviceName: "Pixel 9 Pro XL", label: "Pixel 9 Pro XL (komodo)", status: "supported" },
  {
    id: "rango",
    deviceName: "Pixel 10 Pro Fold",
    label: "Pixel 10 Pro Fold (rango) — experimental / boot HOLD",
    status: "experimental",
  },
];

export type OfferedProduct = (typeof WIZARD_DEVICES)[number]["id"];

export const DEFAULT_OFFERED_PRODUCT: OfferedProduct = WIZARD_DEVICES[0]?.id ?? "tokay";

/* ===================================================================== *
 * F-WEBINSTALL-FLASHALL-PICKER-TRUTH — the two facts the picker must show
 * EXACTLY, never approximate:
 *
 *   1. Whether the product has a PACKED channel on disk (acceptance (a)):
 *      derived into `./packed-channels.ts` by `scripts/gen-packed-channels.mjs`
 *      and read through `hasPackedChannel` below. A product with no channel is
 *      NOT selectable — the picker refuses it rather than offering a dead end.
 *
 *   2. What `status.json` says about the product (acceptance (c)): the product
 *      facts are `routes.targets` + `routes.experimentalTargets`. `komodo` is
 *      ABSENT from both, so it is recorded as `absent-from-status-json` — not
 *      silently rendered as "supported" (that would be an invented fact).
 *
 * Both facts are SHIPPED CONSTANTS here, mirroring the D-009/D-011 baking
 * pattern: `status.json` is never fetched at runtime (CSP connect-src 'none').
 * ===================================================================== */

/** What `status.json` says about a product, verbatim. */
export type StatusJsonFact = "target" | "experimental" | "absent-from-status-json";

/**
 * The shipped `status.json` product facts, as constants. These are the EXACT
 * values of `routes.targets` / `routes.experimentalTargets`. A test asserts
 * they still equal the live `status.json`, so a hand-edit cannot drift.
 */
export const STATUS_JSON_TARGETS: readonly string[] = ["tokay", "rango"];
export const STATUS_JSON_EXPERIMENTAL_TARGETS: readonly string[] = ["akita"];

/** The `status.json` fact for a product. Absence from both lists is its own fact. */
export function statusJsonFact(product: string): StatusJsonFact {
  if (STATUS_JSON_TARGETS.includes(product)) {
    return "target";
  }
  if (STATUS_JSON_EXPERIMENTAL_TARGETS.includes(product)) {
    return "experimental";
  }
  return "absent-from-status-json";
}

/**
 * The honest chip word for a product, derived from `status.json` EXACTLY
 * (acceptance (c)). This is deliberately SEPARATE from `statusChipWord`
 * (the DEC-WEBINSTALL-015 marketing status) and from the host readiness tier:
 * three distinct facts, three distinct words, never conflated.
 *
 *   target                    → "TARGET"
 *   experimental              → "EXPERIMENTAL"
 *   absent-from-status-json   → "NOT IN status.json" (the komodo case)
 */
export function statusJsonChipWord(product: string): string {
  switch (statusJsonFact(product)) {
    case "target":
      return "TARGET";
    case "experimental":
      return "EXPERIMENTAL";
    case "absent-from-status-json":
      return "NOT IN status.json";
  }
}

/**
 * The honest chip for the packed-channel fact (acceptance (a)). A product with
 * no channel carries "NO CHANNEL · NOT SELECTABLE" so the refusal is visible,
 * not just enforced.
 */
export function channelChipWord(product: string): string {
  return hasPackedChannel(product) ? "CHANNEL PACKED" : "NO CHANNEL · NOT SELECTABLE";
}

/**
 * The CHANNEL half of selectability (acceptance (a)): is this product advertised
 * AND backed by a packed channel on disk?
 *
 * The readiness-tier half is deliberately NOT folded in here — `./readiness.js`
 * imports this module, so importing it back would create a cycle that breaks
 * named exports at load time. Callers compose both halves; see
 * `routes/install/early-steps.ts`'s `isSelectableProduct`.
 */
export function hasChannelAndAdvertised(product: string): boolean {
  return isOfferedDevice(product) && hasPackedChannel(product);
}

export function isOfferedDevice(id: string): id is OfferedProduct {
  return WIZARD_DEVICES.some((device) => device.id === id);
}

export function parseOfferedDevice(raw: string | null | undefined): OfferedProduct | undefined {
  if (raw === undefined || raw === null) {
    return undefined;
  }
  const trimmed = raw.trim();
  return isOfferedDevice(trimmed) ? trimmed : undefined;
}

/** `?device=` from the query string; unknown/missing values fall back to tokay. */
export function deviceFromSearch(search: string | URLSearchParams): OfferedProduct {
  const raw = search instanceof URLSearchParams ? search.toString() : search;
  const params = new URLSearchParams(raw.startsWith("?") ? raw.slice(1) : raw);
  return parseOfferedDevice(params.get("device")) ?? DEFAULT_OFFERED_PRODUCT;
}

export function offeredProductIds(): readonly OfferedProduct[] {
  return WIZARD_DEVICES.map((device) => device.id);
}

export function statusChipWord(status: OfferedDeviceStatus): string {
  return status === "supported" ? "SUPPORTED" : "EXPERIMENTAL · BOOT HOLD";
}
