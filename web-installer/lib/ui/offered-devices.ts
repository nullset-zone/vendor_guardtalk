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

/* ===================================================================== *
 * F-DEVICE-ALIGN-ADVERTISE — the offered set is TRUE and JUSTIFIED.
 *
 * The picker offers FOUR products (`WIZARD_DEVICES`); the tree carries 14
 * device layers (plus `emu64a`, a different shape). Before this section the
 * ten withheld devices had no written reason anywhere in shipped source, so
 * "why is `tegu` not offered?" was answerable only by reading make variables.
 *
 * Measured 2026-10-29T16:16Z at vendor/guardtalk HEAD `fce0c1d` (working tree
 * clean; the wave-18 web-installer change set is COMMITTED, not uncommitted).
 * Lane C was writing `vendor/guardtalk/device/**` concurrently — the newest
 * file there at measurement time was 2026-10-18, i.e. no lane-C write had
 * landed yet. Lane A/B were writing `radio-excised/guardtalk-radio-excised.mk`
 * (15:57Z) and `feature-excised/excision-variants.mk` (15:58Z); the registry
 * rows below were read after those writes.
 *
 * WHY CONSTANTS: the browser is offline (CSP `connect-src 'none'`, D-006), so
 * the page cannot stat the tree at runtime — exactly the D-009/D-011 baking
 * pattern used for `status.json`. `test/offered-completeness.test.ts`
 * re-derives every row from disk and fails when a constant drifts from the
 * tree, so this is not a hand-maintained second source of truth.
 *
 * WHAT THIS SECTION DOES NOT DO: it does not add or remove a product.
 * Widening or narrowing the advertised fleet is an operator decision
 * (`DEC-DEVICE-ALIGN-002`), so `WIZARD_DEVICES` above is untouched.
 * ===================================================================== */

/** A capability a product must ship to be advertised. */
export type CapabilityKey =
  | "rebrand"
  | "voice-filter"
  | "face-filter"
  | "theme"
  | "production-hardening"
  | "blocklist"
  | "excision-registry";

/** Every codename with a device layer under `vendor/guardtalk/device/`. */
export type FleetCodename =
  | "tokay"
  | "akita"
  | "komodo"
  | "rango"
  | "blazer"
  | "caiman"
  | "comet"
  | "frankel"
  | "husky"
  | "mustang"
  | "shiba"
  | "stallion"
  | "tangorpro"
  | "tegu";

/** Every codename that is NOT offered. Exhaustive by construction. */
export type WithheldCodename = Exclude<FleetCodename, OfferedProduct>;

/**
 * Where a device's `vendor_dlkm.modules.blocklist` comes from. Three location
 * conventions coexist (registered in `docs/EXCISION_MATRIX.md` §4.1 by
 * `T-DEVICE-ALIGN-REGISTRY`); this records which one a device uses so the
 * distinction is legible rather than implied.
 */
export type BlocklistSource =
  | "variants-dir"
  | "feature-excised-flat"
  | "device-local"
  | "device-pin";

/**
 * One device's measured capability profile. Every field is a fact that
 * `test/offered-completeness.test.ts` re-derives from the tree:
 *
 *   rebrand             `device/<id>/guardtalk-flags.mk` sets GUARDTALK_PRODUCT_MODEL
 *   voiceFilter         `device/<id>/guardtalk-audio.mk` exists — the ONLY file
 *                       that adds `libguardtalkvoicesw` / `GuardTalkVoice`. The
 *                       `GUARDTALK_VOICE_FILTER := true` declaration alone adds
 *                       nothing, which is why "declared-only" is its own state.
 *   faceFilter          `device/<id>/guardtalk-camera.mk` exists; the face
 *                       filter itself is declared OFF on every phone (T-CAM-EXT-FIX)
 *   theme               per-device wrapper, else the documented `$(wildcard)`
 *                       fallback at `feature-excised/guardtalk-feature-excised.mk:106`
 *                       (DEC-DEVICE-ALIGN-003)
 *   productionHardening own file, else the documented `PRODUCT_DEVICE`-with-tokay
 *                       fallback at `radio-excised/guardtalk-radio-excised.mk:41`
 *   blocklist           resolved through `excision-variants.mk` (see BlocklistSource)
 *   insmod              `device/<id>/guardtalk-insmod.mk`. This is NOT a product
 *                       feature: it repairs adevtool's `find -copy-subdir-files`
 *                       missing `init.insmod.*.cfg` when the kernel dir is a
 *                       symlink. `tokay` needs no repair, so it is never a gap.
 */
export interface DeviceCapabilityRow {
  readonly id: FleetCodename;
  readonly marketingName: string;
  /** `GT_DEVICE_VARIANT_<id>` in `feature-excised/excision-variants.mk`, or "". */
  readonly registryVariant: string;
  /** Is the variant registered in the shared registry? */
  readonly excisionRegistry: "row" | "missing";
  /** `vendor/google_devices/<id>/BoardConfig.mk` carries the GuardTalk hook. */
  readonly googleDevicesHooked: boolean;
  readonly rebrand: "flags" | "absent";
  readonly voiceFilter: "layer" | "declared-only" | "absent";
  readonly faceFilter: "layer" | "declared-off" | "absent";
  readonly theme: "wrapper" | "shared-fallback";
  readonly productionHardening: "own-file" | "tokay-fallback";
  readonly blocklist: BlocklistSource;
  readonly insmod: "own-file" | "not-required";
}

/**
 * The 14 measured device layers. Order is the `vendor/google_devices/*` hook
 * order used by the wave-21 matrix so the two artifacts are comparable.
 *
 * `emu64a` is deliberately absent: it is a Goldfish emulator product
 * (`device/emu64a/guardtalk_emu64a.mk` sets `PRODUCT_DEVICE := emu64a`), not a
 * Pixel device layer. It is a different SHAPE, so folding it into a parity
 * claim would compare an emulator to a phone.
 */
export const DEVICE_FLEET: readonly DeviceCapabilityRow[] = [
  {
    id: "tokay",
    marketingName: "Pixel 9",
    registryVariant: "zumapro_caimito",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "layer",
    faceFilter: "layer",
    theme: "wrapper",
    productionHardening: "own-file",
    blocklist: "feature-excised-flat",
    insmod: "not-required",
  },
  {
    id: "akita",
    marketingName: "Pixel 8a",
    registryVariant: "zuma_akita",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "layer",
    faceFilter: "layer",
    theme: "wrapper",
    productionHardening: "tokay-fallback",
    blocklist: "device-local",
    insmod: "own-file",
  },
  {
    id: "komodo",
    marketingName: "Pixel 9 Pro XL",
    registryVariant: "zumapro_caimito",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "layer",
    faceFilter: "layer",
    theme: "wrapper",
    productionHardening: "own-file",
    blocklist: "device-pin",
    insmod: "own-file",
  },
  {
    id: "rango",
    marketingName: "Pixel 10 Pro Fold",
    registryVariant: "laguna_rango",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "layer",
    faceFilter: "layer",
    theme: "wrapper",
    productionHardening: "tokay-fallback",
    blocklist: "device-local",
    insmod: "own-file",
  },
  {
    id: "blazer",
    marketingName: "Pixel 10 Pro",
    registryVariant: "laguna_muzel",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "caiman",
    marketingName: "Pixel 9 Pro",
    registryVariant: "zumapro_caimito",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "feature-excised-flat",
    insmod: "own-file",
  },
  {
    id: "comet",
    marketingName: "Pixel 9 Pro Fold",
    registryVariant: "zumapro_comet",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "frankel",
    marketingName: "Pixel 10",
    registryVariant: "laguna_muzel",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "husky",
    marketingName: "Pixel 8 Pro",
    registryVariant: "zuma_shusky",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "mustang",
    marketingName: "Pixel 10 Pro XL",
    registryVariant: "laguna_muzel",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "shiba",
    marketingName: "Pixel 8",
    registryVariant: "zuma_shusky",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "stallion",
    marketingName: "Pixel 10a",
    registryVariant: "zumapro_stallion",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
  {
    id: "tangorpro",
    marketingName: "Pixel Tablet",
    registryVariant: "gs201_tangorpro",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "not-required",
  },
  {
    id: "tegu",
    marketingName: "Pixel 9a",
    registryVariant: "zumapro_tegu",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "absent",
    faceFilter: "declared-off",
    theme: "shared-fallback",
    productionHardening: "tokay-fallback",
    blocklist: "variants-dir",
    insmod: "own-file",
  },
];

/**
 * The written reason each withheld device is not offered — the honest one.
 *
 * None of these devices is broken. The nine phone ports assign
 * `GUARDTALK_VOICE_FILTER :=` empty in their own `guardtalk-flags.mk`: the
 * filter is not declared true, and there is still no `guardtalk-audio.mk` —
 * the only file that adds `libguardtalkvoicesw` / `GuardTalkVoice`. That empty
 * assignment, not a build failure, is the gap. `tangorpro`'s sentence is a
 * separate tablet gap and is left as written.
 *
 * `product-common-excised.mk` is deliberately NOT part of this reason:
 * `device/REGEN_HOOKS.md` §5 calls it optional (only devices that need the
 * zumapro `product-common.mk` swap take it, and `akita` holds it for parity
 * alone), so its absence is not a missing capability.
 *
 * Each device also has no packed channel: `channels/` carries a manifest only
 * for the four offered products, so `hasPackedChannel` is false for every row
 * below and the picker would refuse it on that fact alone.
 *
 * This map is a `Record<WithheldCodename, string>`, so adding a device to
 * `FleetCodename` without a reason fails to COMPILE — a withheld device can
 * never be silently unexplained.
 */
export const WITHHELD_REASONS: Readonly<Record<WithheldCodename, string>> = {
  blazer:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/blazer/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  caiman:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/caiman/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  comet:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/comet/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  frankel:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/frankel/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  husky:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/husky/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  mustang:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/mustang/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  shiba:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/shiba/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  stallion:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/stallion/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; it also has the thinnest main-channel build index (5) in the program matrix, so it is incomplete rather than broken, and it has no packed/advertised channel.",
  tangorpro:
    "Withheld: admitted for radio/RIL userspace excision only (DEC-PORT-TANGORPRO-002/-003) — it now has a device/tangorpro/guardtalk-flags.mk declaring the rebrand only (DEC-DEVICE-ALIGN-020), but it still has no GUARDTALK_VOICE_FILTER declaration, no guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice), no guardtalk-camera.mk and no GuardTalk product base, so both privacy filters stay unbuilt; it is incomplete rather than broken, and it has no packed/advertised channel.",
  tegu:
    "Withheld: excision-only port — GUARDTALK_VOICE_FILTER := is empty (the filter is not declared true) and device/tegu/guardtalk-audio.mk (the only file that builds libguardtalkvoicesw / GuardTalkVoice) is still absent, and there is no guardtalk-camera.mk or per-device theme wrapper; radio excision, registry variant and kernel blocklist are present, so it is incomplete rather than broken, and it has no packed/advertised channel.",
};

/** What an OFFERED product must ship. Ordered so a gap message reads naturally. */
export const ADVERTISE_REQUIREMENTS: readonly CapabilityKey[] = [
  "rebrand",
  "voice-filter",
  "face-filter",
  "theme",
  "production-hardening",
  "blocklist",
  "excision-registry",
];

/**
 * The measured wiring state of the voice/face filter layers — recorded because
 * it bounds what "complete" can honestly mean.
 *
 * `device/<codename>/guardtalk-audio.mk` is the ONLY file that adds
 * `libguardtalkvoicesw` / `GuardTalkVoice`, and it is included from exactly two
 * places: `device/tokay/guardtalk-tokay.mk` (whose own header states it is "NOT
 * currently in the product inherit chain") and the `emu64a` emulator layer. No
 * `vendor/google_devices/<codename>/<codename>.mk` includes either. So for
 * every phone in
 * `DEVICE_FLEET` the voice filter is a LAYERED, DECLARED capability that is not
 * currently reached from the live product include chain.
 *
 * That gap is UNIFORM across all 14 devices, so it does not make an offered
 * device less capable than a withheld one — the invariant below is unaffected.
 * It DOES mean "complete" here means "holds every overlay the reference layer
 * defines", not "the package is in the last shipped image". Reported to the
 * Architect as a recommendation (fixing it is a `device/**` change, which this
 * card may not make).
 */
export const FILTER_LAYER_WIRING = {
  /** Every in-tree file that includes a per-device audio/camera filter layer. */
  includingFiles: [
    "vendor/guardtalk/device/tokay/guardtalk-tokay.mk",
    "vendor/guardtalk/device/emu64a/guardtalk-emu-layer.mk",
  ],
  /** `tokay-tokay.mk`'s own header: not in the product inherit chain. */
  reachableFromPhoneProductChain: false,
} as const;

/** The layer files this model is bound to — the model ⇄ disk mapping, once. */
export const LAYER_FILES = {
  flags: "guardtalk-flags.mk",
  audio: "guardtalk-audio.mk",
  camera: "guardtalk-camera.mk",
  theme: "guardtalk-theme.mk",
  insmod: "guardtalk-insmod.mk",
  hardening: "guardtalk-production-hardening.mk",
  boardLate: "BoardConfig-excised-late.mk",
} as const;

/** The row for a codename, or undefined when it is not a fleet device. */
export function deviceCapability(id: string): DeviceCapabilityRow | undefined {
  return DEVICE_FLEET.find((row) => row.id === id);
}

/** The written withholding reason, or undefined when the device is offered/unknown. */
export function withheldReason(id: string): string | undefined {
  const reasons: Readonly<Record<string, string>> = WITHHELD_REASONS;
  return reasons[id];
}

/**
 * The capabilities a row actually satisfies. A declaration alone never counts:
 * `GUARDTALK_VOICE_FILTER := true` on a device with no `guardtalk-audio.mk`
 * builds nothing, so it is `declared-only` and does NOT satisfy `voice-filter`.
 */
export function capabilitiesOf(row: DeviceCapabilityRow): ReadonlySet<CapabilityKey> {
  const caps = new Set<CapabilityKey>();
  if (row.rebrand === "flags") caps.add("rebrand");
  if (row.voiceFilter === "layer") caps.add("voice-filter");
  // A deliberate OFF is a decided state, not a gap; a missing layer with no
  // decision is not.
  if (row.faceFilter === "layer" || row.faceFilter === "declared-off") caps.add("face-filter");
  if (row.theme === "wrapper" || row.theme === "shared-fallback") caps.add("theme");
  if (row.productionHardening === "own-file" || row.productionHardening === "tokay-fallback") {
    caps.add("production-hardening");
  }
  if (
    row.blocklist === "variants-dir" ||
    row.blocklist === "feature-excised-flat" ||
    row.blocklist === "device-local" ||
    row.blocklist === "device-pin"
  ) {
    caps.add("blocklist");
  }
  if (row.excisionRegistry === "row") caps.add("excision-registry");
  return caps;
}

/** The requirements a codename fails. Empty means complete for advertising. */
export function capabilityGaps(
  id: string,
  fleet: readonly DeviceCapabilityRow[] = DEVICE_FLEET,
): readonly CapabilityKey[] {
  const row = fleet.find((candidate) => candidate.id === id);
  if (row === undefined) {
    return [...ADVERTISE_REQUIREMENTS];
  }
  const caps = capabilitiesOf(row);
  return ADVERTISE_REQUIREMENTS.filter((key) => !caps.has(key));
}

/** Is this codename complete enough to advertise? Unknown codenames are not. */
export function isCompleteForAdvertising(
  id: string,
  fleet: readonly DeviceCapabilityRow[] = DEVICE_FLEET,
): boolean {
  return capabilityGaps(id, fleet).length === 0;
}

/**
 * Every device that WOULD satisfy the advertisement requirements today.
 *
 * Published for the operator decision, and never applied automatically: the
 * advertised set is `WIZARD_DEVICES`, and changing it is `DEC-DEVICE-ALIGN-002`
 * territory, not an engineering one. Today this returns exactly the four
 * offered products — a wider result would be a recommendation to report, and a
 * narrower one would mean the shipped picker offers an incomplete device.
 */
export function advertiseEligibleIds(
  fleet: readonly DeviceCapabilityRow[] = DEVICE_FLEET,
): readonly string[] {
  return fleet.filter((row) => capabilityGaps(row.id, fleet).length === 0).map((row) => row.id);
}

/** Raised when the offered set is not justified by the measured capability data. */
export class OfferedCapabilityError extends Error {
  readonly violations: readonly string[];

  constructor(violations: readonly string[]) {
    super(
      `F-DEVICE-ALIGN-ADVERTISE: the offered set is not justified.\n${violations
        .map((violation) => `  - ${violation}`)
        .join("\n")}`,
    );
    this.name = "OfferedCapabilityError";
    this.violations = violations;
  }
}

/**
 * The invariant, as CODE: an offered device is never less capable than a
 * withheld one, and every withheld device carries a written reason.
 *
 * FALSIFIABLE, not advisory:
 *   - offering a half-built device (`tegu`, `caiman`, `tangorpro`) throws,
 *     because it lacks `voice-filter` (for `tangorpro` that is now its only
 *     gap — its rebrand landed in `DEC-DEVICE-ALIGN-020`);
 *   - offering an unknown codename throws — an unmeasured product cannot be
 *     justified by silence;
 *   - a withheld device with no (or a stub) reason throws;
 *   - a withheld device that ships a capability an offered device lacks throws.
 *
 * `Q-DEVICE-ALIGN-ADVERTISE` drives this directly; both parameters are
 * injectable so the QA gate can feed a synthetic fleet and prove the predicate
 * fails on an injected delta rather than only passing on today's tree.
 */
export function assertOfferedImpliesComplete(
  offeredIds: readonly string[] = offeredProductIds(),
  fleet: readonly DeviceCapabilityRow[] = DEVICE_FLEET,
): void {
  const violations: string[] = [];
  const offered = new Set(offeredIds);

  if (offeredIds.length === 0) {
    violations.push("the offered set is empty — a vacuous predicate proves nothing");
  }

  const offeredRows: DeviceCapabilityRow[] = [];
  for (const id of offeredIds) {
    const row = fleet.find((candidate) => candidate.id === id);
    if (row === undefined) {
      violations.push(`${id}: offered but has no measured capability row`);
      continue;
    }
    const missing = capabilityGaps(id, fleet);
    if (missing.length > 0) {
      violations.push(`${id}: offered but incomplete — missing ${missing.join(", ")}`);
    }
    offeredRows.push(row);
  }

  for (const row of fleet) {
    if (offered.has(row.id)) {
      continue;
    }
    const reason = withheldReason(row.id);
    if (reason === undefined || reason.trim().length < 40) {
      violations.push(`${row.id}: withheld without a written reason in shipped source`);
    }
    // Non-vacuity in the other direction: a withholding reason goes STALE the
    // moment the device becomes complete, so it must fail here rather than keep
    // a capable device unadvertised behind an obsolete sentence.
    if (capabilityGaps(row.id, fleet).length === 0) {
      violations.push(`${row.id}: withheld but now COMPLETE — the written reason is stale; re-classify it`);
    }
  }

  const withheldRows = fleet.filter((row) => !offered.has(row.id));
  for (const offeredRow of offeredRows) {
    const offeredCaps = capabilitiesOf(offeredRow);
    for (const withheldRow of withheldRows) {
      const extra = [...capabilitiesOf(withheldRow)].filter((key) => !offeredCaps.has(key));
      if (extra.length > 0) {
        violations.push(
          `${offeredRow.id}: offered but LESS capable than withheld ${withheldRow.id} — ` +
            `the withheld device ships ${extra.join(", ")}`,
        );
      }
    }
  }

  if (violations.length > 0) {
    throw new OfferedCapabilityError(violations);
  }
}

