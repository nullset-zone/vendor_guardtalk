/**
 * F-DEVICE-ALIGN-ADVERTISE — the offered set is TRUE and JUSTIFIED.
 *
 * The picker offers four products out of fourteen device layers. This suite
 * makes that a *measured* claim:
 *
 *   (1) every row of `DEVICE_FLEET` is re-derived from the tree on disk, so the
 *       shipped constants cannot drift from the files they describe;
 *   (2) every withheld device carries a written, one-line reason in the SHIPPED
 *       source (not in a document the page cannot reach);
 *   (3) `assertOfferedImpliesComplete` is FALSIFIABLE — it throws when a
 *       half-built device is offered, when an unmeasured codename is offered,
 *       and when a withheld device out-ships an offered one;
 *   (4) the hard-won picker truths survive: the offered set is unchanged,
 *       `rango` stays `experimental`, `komodo` keeps `NOT IN status.json`, and
 *       the marketing chip stays separate from the `status.json` chip.
 *
 * HONESTY: BOOT_VERIFIED=false / LIVE_FLASH_CLAIMED=false. Nothing here is a
 * boot or flash claim; "complete" means "holds every overlay the reference
 * layer defines", and §(5) records the one place where the live build chain
 * does not yet reach those overlays.
 */
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  ADVERTISE_REQUIREMENTS,
  DEVICE_FLEET,
  FILTER_LAYER_WIRING,
  LAYER_FILES,
  OfferedCapabilityError,
  WIZARD_DEVICES,
  WITHHELD_REASONS,
  advertiseEligibleIds,
  assertOfferedImpliesComplete,
  capabilitiesOf,
  capabilityGaps,
  deviceCapability,
  isCompleteForAdvertising,
  offeredProductIds,
  statusChipWord,
  statusJsonChipWord,
  withheldReason,
  type BlocklistSource,
  type CapabilityKey,
  type DeviceCapabilityRow,
  type FleetCodename,
} from "../lib/ui/offered-devices.js";

const INSTALLER_ROOT = fileURLToPath(new URL("..", import.meta.url));
/** `vendor/guardtalk` — the repo that owns `device/` and `feature-excised/`. */
const GUARDTALK_ROOT = fileURLToPath(new URL("../..", import.meta.url));
/** The Android `repo` checkout root; present in this workspace, absent standalone. */
const REPO_ROOT = fileURLToPath(new URL("../../../..", import.meta.url));

const DEVICE_DIR = join(GUARDTALK_ROOT, "device");
const VARIANTS_MK = join(GUARDTALK_ROOT, "feature-excised", "excision-variants.mk");
const TOKAY_HARDENING = join(DEVICE_DIR, "tokay", "guardtalk-production-hardening.mk");
const SHARED_THEME = join(GUARDTALK_ROOT, "branding", "guardtalk-theme.mk");

const OFFERED_IDS = ["tokay", "akita", "komodo", "rango"];

/** The 14 device layers, in the order the fleet data uses. */
const FLEET_IDS = [
  "tokay",
  "akita",
  "komodo",
  "rango",
  "blazer",
  "caiman",
  "comet",
  "frankel",
  "husky",
  "mustang",
  "shiba",
  "stallion",
  "tangorpro",
  "tegu",
];

const MARKETING_NAMES: Readonly<Record<string, string>> = {
  tokay: "Pixel 9",
  akita: "Pixel 8a",
  komodo: "Pixel 9 Pro XL",
  rango: "Pixel 10 Pro Fold",
  blazer: "Pixel 10 Pro",
  caiman: "Pixel 9 Pro",
  comet: "Pixel 9 Pro Fold",
  frankel: "Pixel 10",
  husky: "Pixel 8 Pro",
  mustang: "Pixel 10 Pro XL",
  shiba: "Pixel 8",
  stallion: "Pixel 10a",
  tangorpro: "Pixel Tablet",
  tegu: "Pixel 9a",
};

function fileText(path: string): string {
  return readFileSync(path, "utf8");
}

function deviceFile(id: string, name: string): string {
  return join(DEVICE_DIR, id, name);
}

/** `device/<id>/<layer file>` — the model⇄disk binding, taken from source. */
function layerFile(id: string, layer: keyof typeof LAYER_FILES): string {
  return deviceFile(id, LAYER_FILES[layer]);
}

/** Parse `VAR := value` out of a makefile, or "" when unset. */
function declared(text: string, variable: string): string {
  const match = new RegExp(`^${variable}[ \t]*:?=[ \t]*(.*)$`, "m").exec(text);
  return match?.[1] === undefined ? "" : match[1].trim();
}

/** The `GT_DEVICE_VARIANT_<id> := <variant>` registry rows. */
function registryRows(): Map<string, string> {
  const text = fileText(VARIANTS_MK);
  const rows = new Map<string, string>();
  for (const match of text.matchAll(/^GT_DEVICE_VARIANT_(\w+)[ \t]*:=[ \t]*(\S+)/gm)) {
    const device = match[1];
    const variant = match[2];
    if (device !== undefined && variant !== undefined) {
      rows.set(device, variant);
    }
  }
  return rows;
}

/** Resolve a registry path (`vendor/guardtalk/...`) against this repo, not the checkout. */
function repoPath(path: string): string {
  const prefix = "vendor/guardtalk/";
  return path.startsWith(prefix) ? join(GUARDTALK_ROOT, path.slice(prefix.length)) : path;
}

/** Derive the blocklist source from the registry data, and prove the file exists. */
function blocklistSourceFor(id: string, variant: string): BlocklistSource {
  const text = fileText(VARIANTS_MK);
  if (new RegExp(`^GT_DEVICE_BLOCKLIST_${id}[ \\t]*:=`, "m").test(text)) {
    const pinned = new RegExp(`^GT_DEVICE_BLOCKLIST_${id}[ \\t]*:=[ \\t]*(\\S+)`, "m").exec(text);
    const path = pinned?.[1];
    assert.ok(path !== undefined, `${id}: pinned blocklist path must be readable`);
    assert.ok(existsSync(repoPath(path)), `${id}: pinned blocklist ${path} must exist`);
    return "device-pin";
  }
  const canonical = new RegExp(`^GT_VARIANT_${variant}_BLOCKLIST[ \\t]*:=[ \\t]*(\\S+)`, "m").exec(text);
  const path = canonical?.[1];
  assert.ok(path !== undefined, `${id}: variant ${variant} must define a BLOCKLIST`);
  assert.ok(existsSync(repoPath(path)), `${id}: blocklist ${path} must exist`);
  if (path.includes("feature-excised/variants/")) {
    return "variants-dir";
  }
  if (path === "vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist") {
    return "feature-excised-flat";
  }
  assert.ok(path.includes(`device/${id}/`), `${id}: unexpected blocklist path ${path}`);
  return "device-local";
}

/** Re-derive one capability row from the tree — the whole point of (1). */
function deriveRow(id: string): DeviceCapabilityRow {
  const flagsPath = layerFile(id, "flags");
  const flags = existsSync(flagsPath) ? fileText(flagsPath) : "";
  const variants = registryRows();
  const variant = variants.get(id) ?? "";

  const audio = existsSync(layerFile(id, "audio"));
  const camera = existsSync(layerFile(id, "camera"));
  const declaresVoice = declared(flags, "GUARDTALK_VOICE_FILTER") === "true";
  const declaresModel = declared(flags, "GUARDTALK_PRODUCT_MODEL") !== "";

  assert.ok(existsSync(layerFile(id, "boardLate")), `${id}: BoardConfig layer`);

  return {
    id: id as FleetCodename,
    marketingName: MARKETING_NAMES[id] ?? "",
    registryVariant: variant,
    excisionRegistry: variant === "" ? "missing" : "row",
    googleDevicesHooked: existsSync(
      join(REPO_ROOT, "vendor", "google_devices", id, "BoardConfig.mk"),
    ),
    rebrand: declaresModel ? "flags" : "absent",
    voiceFilter: audio ? "layer" : declaresVoice ? "declared-only" : "absent",
    faceFilter: camera ? "layer" : flags === "" ? "absent" : "declared-off",
    theme: existsSync(layerFile(id, "theme")) ? "wrapper" : "shared-fallback",
    productionHardening: existsSync(layerFile(id, "hardening")) ? "own-file" : "tokay-fallback",
    blocklist: blocklistSourceFor(id, variant),
    insmod: existsSync(layerFile(id, "insmod")) ? "own-file" : "not-required",
  };
}

/* ================================================================== *
 * (1) the shipped constants equal the tree
 * ================================================================== */

test("FLEET-TRUTH: device/ carries exactly the 14 layers the fleet data lists", () => {
  const dirs = readdirSync(DEVICE_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  // 15 overlay dirs: the 14 Pixel layers + the emu64a product-namefile shape.
  assert.deepEqual(dirs, [...FLEET_IDS, "emu64a"].sort());
  assert.deepEqual(
    DEVICE_FLEET.map((row) => row.id),
    FLEET_IDS,
    "DEVICE_FLEET must list the 14 device layers in the matrix order",
  );
  assert.equal(DEVICE_FLEET.length, 14);
});

test("FLEET-TRUTH: emu64a is a different shape and is excluded from the fleet", () => {
  // It is a Goldfish product (PRODUCT_DEVICE := emu64a), not a Pixel device
  // layer, so folding it into a parity claim would compare unlike things.
  assert.equal(deviceCapability("emu64a"), undefined);
  assert.equal(
    DEVICE_FLEET.some((row) => row.id === ("emu64a" as FleetCodename)),
    false,
  );
  const product = fileText(join(DEVICE_DIR, "emu64a", "guardtalk_emu64a.mk"));
  assert.match(product, /PRODUCT_DEVICE := emu64a/);
  assert.match(product, /sdk_phone64_arm64/);
});

test("FLEET-TRUTH: every capability row re-derived from disk equals the shipped constant", () => {
  for (const id of FLEET_IDS) {
    assert.deepEqual(
      deviceCapability(id),
      deriveRow(id),
      `${id}: shipped DEVICE_FLEET row drifted from vendor/guardtalk/device/${id}/`,
    );
  }
});

test("FLEET-TRUTH: the registry has one row per device, and no orphan row", () => {
  const rows = registryRows();
  assert.equal(rows.size, 14);
  for (const id of FLEET_IDS) {
    assert.ok(rows.has(id), `${id}: must have a GT_DEVICE_VARIANT_ row`);
    assert.equal(deviceCapability(id)?.registryVariant, rows.get(id));
    assert.equal(deviceCapability(id)?.excisionRegistry, "row");
  }
  assert.deepEqual([...rows.keys()].sort(), [...FLEET_IDS].sort());
});

test("FLEET-TRUTH: every device layer is wired from vendor/google_devices", (t) => {
  if (!existsSync(join(REPO_ROOT, "vendor", "google_devices"))) {
    t.skip("no Android checkout parent — wiring is not observable from a standalone installer");
    return;
  }
  for (const id of FLEET_IDS) {
    const board = join(REPO_ROOT, "vendor", "google_devices", id, "BoardConfig.mk");
    assert.ok(existsSync(board), `${id}: board config must exist`);
    assert.match(
      fileText(board),
      new RegExp(`vendor/guardtalk/device/${id}/BoardConfig-excised-late\\.mk`),
      `${id}: BoardConfig.mk must carry the GuardTalk late hook`,
    );
    assert.equal(deviceCapability(id)?.googleDevicesHooked, true);
  }
});

/* ================================================================== *
 * (2) every withheld device carries a written reason
 * ================================================================== */

test("WITHHELD-TRUTH: the withheld set is exactly the non-offered fleet, and every one has a reason", () => {
  const withheld = FLEET_IDS.filter((id) => !OFFERED_IDS.includes(id));
  assert.equal(withheld.length, 10, "4 offered of 14 leaves 10 withheld");
  assert.deepEqual(Object.keys(WITHHELD_REASONS).sort(), [...withheld].sort());
  for (const id of withheld) {
    const reason = withheldReason(id);
    assert.ok(reason !== undefined, `${id}: withheld device has no written reason`);
    assert.ok(reason.trim().length >= 40, `${id}: reason is a stub: ${JSON.stringify(reason)}`);
    assert.equal(reason.includes("\n"), false, `${id}: reason must be ONE line`);
    assert.doesNotMatch(reason, /\bTBD\b|\bTODO\b|\?\?/, `${id}: reason must be settled prose`);
    // A reason that only says "not offered" would be a restatement, not a reason.
    assert.match(reason, new RegExp(`device/${id}/`), `${id}: reason must cite the device path`);
    assert.match(reason, /incomplete rather than broken/, `${id}: must separate incomplete from broken`);
    assert.match(reason, /guardtalk-audio\.mk|guardtalk-flags\.mk/, `${id}: must name the missing file`);
    assert.match(reason, /packed\/advertised channel/, `${id}: must name the channel fact`);
  }
  // The nine phone ports declare the voice filter and ship no layer; the tablet
  // ships no flag file at all. Two different gaps, each stated as its own.
  for (const id of withheld) {
    const expected = id === "tangorpro" ? /guardtalk-flags\.mk/ : /guardtalk-audio\.mk/;
    assert.match(withheldReason(id) ?? "", expected, `${id}: reason names the wrong gap`);
  }
  assert.notEqual(withheldReason("tegu"), withheldReason("tangorpro"), "tablet gap ≠ phone gap");
});

test("WITHHELD-TRUTH: an offered device never has a withholding reason", () => {
  for (const id of OFFERED_IDS) {
    assert.equal(withheldReason(id), undefined, `${id} is offered and must not carry a reason`);
  }
  assert.equal(withheldReason("emu64a"), undefined, "emu64a is out of scope, not withheld");
});

test("OFFERED-TRUTH: every offered device satisfies every advertisement requirement", () => {
  assert.deepEqual([...offeredProductIds()], OFFERED_IDS, "the offered set is unchanged");
  assert.deepEqual(
    WIZARD_DEVICES.map((device) => device.id),
    OFFERED_IDS,
    "WIZARD_DEVICES must still offer exactly tokay/akita/komodo/rango",
  );
  for (const id of OFFERED_IDS) {
    assert.deepEqual(capabilityGaps(id), [], `${id}: offered but incomplete`);
    assert.equal(isCompleteForAdvertising(id), true);
  }
  // Non-vacuity: the requirements are a real set, and a withheld device fails them.
  assert.ok(ADVERTISE_REQUIREMENTS.length >= 5);
  assert.equal(isCompleteForAdvertising("tegu"), false, "tegu has no voice-filter layer");
  assert.ok(capabilityGaps("tegu").includes("voice-filter"));
});

test("OFFERED-TRUTH: no offered device is less capable than a withheld one", () => {
  const withheld = FLEET_IDS.filter((id) => !OFFERED_IDS.includes(id));
  assert.equal(withheld.length, 10);
  for (const offered of OFFERED_IDS) {
    const offeredRow = deviceCapability(offered);
    assert.ok(offeredRow !== undefined, `${offered}: row must exist`);
    const offeredCaps = capabilitiesOf(offeredRow);
    for (const other of withheld) {
      const withheldRow = deviceCapability(other);
      assert.ok(withheldRow !== undefined, `${other}: row must exist`);
      const withheldCaps = capabilitiesOf(withheldRow);
      const extra = [...withheldCaps].filter((key: CapabilityKey) => !offeredCaps.has(key));
      assert.deepEqual(extra, [], `${other} ships ${extra.join(", ")} that ${offered} lacks`);
      // Strictly better, not merely equal: otherwise "offered" means nothing.
      assert.ok(
        [...offeredCaps].some((key) => !withheldCaps.has(key)),
        `${offered} must exceed withheld ${other} in at least one capability`,
      );
    }
  }
  // Non-vacuity: the comparison is over real capability sets, not empty sets.
  const tokayCaps = capabilitiesOf(deviceCapability("tokay") as DeviceCapabilityRow);
  assert.deepEqual([...tokayCaps].sort(), [...ADVERTISE_REQUIREMENTS].sort());
});

/* ================================================================== *
 * (3) the predicate is falsifiable
 * ================================================================== */

test("PREDICATE: the shipped offered set passes the invariant", () => {
  assert.doesNotThrow(() => assertOfferedImpliesComplete());
  assert.doesNotThrow(() => assertOfferedImpliesComplete(OFFERED_IDS));
});

test("PREDICATE: offering a half-built device throws, naming the missing capability", () => {
  for (const halfBuilt of ["tegu", "caiman", "shiba", "tangorpro"]) {
    assert.throws(
      () => assertOfferedImpliesComplete([...OFFERED_IDS, halfBuilt]),
      (error: unknown) =>
        error instanceof OfferedCapabilityError &&
        error.violations.some((violation) => violation.startsWith(`${halfBuilt}: offered but incomplete`)),
      `${halfBuilt} is excision-only and must not be offerable`,
    );
  }
});

test("PREDICATE: offering an unmeasured codename throws (silence is not evidence)", () => {
  assert.throws(
    () => assertOfferedImpliesComplete(["tokay", "not-a-device"]),
    (error: unknown) =>
      error instanceof OfferedCapabilityError &&
      error.violations.some((violation) => violation.includes("no measured capability row")),
  );
});

test("PREDICATE: an injected fleet proves the check fails on a new delta, not just today's tree", () => {
  // A synthetic product that declares the voice filter but never ships the
  // layer — the exact shape a future half-built port would have.
  const synth: DeviceCapabilityRow = {
    id: "tokay",
    marketingName: "Pixel 9",
    registryVariant: "zumapro_caimito",
    excisionRegistry: "row",
    googleDevicesHooked: true,
    rebrand: "flags",
    voiceFilter: "declared-only",
    faceFilter: "layer",
    theme: "wrapper",
    productionHardening: "own-file",
    blocklist: "feature-excised-flat",
    insmod: "not-required",
  };
  assert.throws(
    () => assertOfferedImpliesComplete(["tokay"], [synth]),
    (error: unknown) =>
      error instanceof OfferedCapabilityError &&
      error.violations.some((violation) => violation.includes("missing voice-filter")),
  );
});

test("PREDICATE: a withheld device that out-ships an offered one throws", () => {
  // Model a regression where the offered device loses its voice layer while a
  // withheld device keeps one — the invariant must catch the inversion.
  const offeredLoses: DeviceCapabilityRow = {
    ...(deviceCapability("tokay") as DeviceCapabilityRow),
    voiceFilter: "declared-only",
  };
  const withheldHas: DeviceCapabilityRow = {
    ...(deviceCapability("blazer") as DeviceCapabilityRow),
    voiceFilter: "layer",
  };
  assert.throws(
    () => assertOfferedImpliesComplete(["tokay"], [offeredLoses, withheldHas]),
    (error: unknown) =>
      error instanceof OfferedCapabilityError &&
      error.violations.some((violation) => violation.includes("LESS capable than withheld blazer")),
  );
});

test("PREDICATE: an empty offered set is rejected as vacuous", () => {
  assert.throws(
    () => assertOfferedImpliesComplete([]),
    (error: unknown) =>
      error instanceof OfferedCapabilityError &&
      error.violations.some((violation) => violation.includes("vacuous")),
  );
});

test("PREDICATE: a withholding reason goes stale when the device becomes complete", () => {
  // The other direction of non-vacuity: a capable device left unadvertised
  // behind an obsolete sentence must fail, not quietly stay out of the picker.
  const nowComplete: DeviceCapabilityRow = {
    ...(deviceCapability("tegu") as DeviceCapabilityRow),
    voiceFilter: "layer",
    theme: "wrapper",
  };
  assert.throws(
    () => assertOfferedImpliesComplete(OFFERED_IDS, [...DEVICE_FLEET.filter((row) => row.id !== "tegu"), nowComplete]),
    (error: unknown) =>
      error instanceof OfferedCapabilityError &&
      error.violations.some((violation) => violation.includes("tegu: withheld but now COMPLETE")),
  );
});

test("ELIGIBILITY: the eligible set is exactly the offered set (no widening applied)", () => {
  // Published for the operator decision, never auto-applied to WIZARD_DEVICES.
  assert.deepEqual([...advertiseEligibleIds()], OFFERED_IDS);
  assert.deepEqual([...offeredProductIds()], OFFERED_IDS);
  // What is NOT eligible is the whole withheld set, each for a measured reason.
  for (const id of FLEET_IDS.filter((candidate) => !OFFERED_IDS.includes(candidate))) {
    assert.equal(isCompleteForAdvertising(id), false, `${id} must not be advertise-eligible`);
    assert.ok(capabilityGaps(id).length > 0, `${id} must have a measured gap`);
  }
});

test("ELIGIBILITY: an empty voice-filter assignment never counts as a capability", () => {
  // `GUARDTALK_VOICE_FILTER :=` is empty: the filter is not declared true, and
  // there is still no guardtalk-audio.mk, so the layer is not built.
  const emptyVoice = deviceCapability("shiba") as DeviceCapabilityRow;
  assert.equal(emptyVoice.voiceFilter, "absent");
  assert.equal(capabilitiesOf(emptyVoice).has("voice-filter"), false);
  // ...and the same device still satisfies the facts it really ships.
  assert.equal(capabilitiesOf(emptyVoice).has("rebrand"), true);
  assert.equal(capabilitiesOf(emptyVoice).has("excision-registry"), true);
});

/* ================================================================== *
 * (4) the hard-won picker truths are untouched
 * ================================================================== */

test("TRUTH-PRESERVED: rango stays experimental / boot HOLD", () => {
  const rango = WIZARD_DEVICES.find((device) => device.id === "rango");
  assert.equal(rango?.status, "experimental");
  // The label is lower-case prose; the CHIP is the upper-case word. They are
  // different surfaces and must both survive.
  assert.match(rango?.label ?? "", /experimental \/ boot HOLD/);
  assert.equal(statusChipWord("experimental"), "EXPERIMENTAL · BOOT HOLD");
  // The capability data must not promote it: a layered device is not a
  // boot-green device, and advertising status is a separate fact.
  assert.equal(isCompleteForAdvertising("rango"), true, "rango is overlay-complete...");
  assert.equal(rango?.status, "experimental", "...and still experimental");
});

test("TRUTH-PRESERVED: komodo keeps NOT IN status.json and the two chips stay separate", () => {
  assert.equal(statusJsonChipWord("komodo"), "NOT IN status.json");
  assert.equal(statusChipWord("supported"), "SUPPORTED");
  // The separation itself: for komodo and rango the two notions disagree, which
  // is exactly why they must not be merged into one chip.
  assert.notEqual(statusChipWord("supported"), statusJsonChipWord("komodo"));
  assert.notEqual(statusChipWord("experimental"), statusJsonChipWord("rango"));
  assert.equal(statusJsonChipWord("rango"), "TARGET");
});

test("TRUTH-PRESERVED: the constants still equal the shipped status.json facts", () => {
  const status = JSON.parse(fileText(join(INSTALLER_ROOT, "status.json"))) as {
    targets: string[];
    experimentalTargets: string[];
    flashCapability: { liveFlashClaimed: boolean };
  };
  assert.equal(status.flashCapability.liveFlashClaimed, false);
  for (const id of OFFERED_IDS) {
    const fact = status.targets.includes(id)
      ? "TARGET"
      : status.experimentalTargets.includes(id)
        ? "EXPERIMENTAL"
        : "NOT IN status.json";
    assert.equal(statusJsonChipWord(id), fact, `${id}: chip drifted from status.json`);
  }
});

/* ================================================================== *
 * (5) the wiring boundary this data does not paper over
 * ================================================================== */

test("WIRING: the recorded audio/camera includers are exactly what the tree contains", () => {
  const offenders: string[] = [];
  const walk = (dir: string): void => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === "node_modules" || entry.name === "dist") continue;
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.name.endsWith(".mk")) continue;
      const text = fileText(full);
      if (/device\/[a-z0-9]+\/guardtalk-(?:audio|camera)\.mk/.test(text)) {
        offenders.push(`vendor/guardtalk/${relative(GUARDTALK_ROOT, full)}`);
      }
    }
  };
  walk(GUARDTALK_ROOT);
  assert.deepEqual(
    offenders.sort(),
    [...FILTER_LAYER_WIRING.includingFiles].sort(),
    "the filter-layer include set changed — update FILTER_LAYER_WIRING with the evidence",
  );
});

test("WIRING: no phone product chain includes the per-device filter layers yet", (t) => {
  const googleDevices = join(REPO_ROOT, "vendor", "google_devices");
  if (!existsSync(googleDevices)) {
    t.skip("no Android checkout parent — product chain is not observable");
    return;
  }
  for (const id of FLEET_IDS) {
    const product = join(googleDevices, id, `${id}.mk`);
    assert.ok(existsSync(product), `${id}: ${id}.mk must exist`);
    assert.doesNotMatch(
      fileText(product),
      /guardtalk-(?:audio|camera)\.mk/,
      `${id}: product chain now wires the filter layers — update FILTER_LAYER_WIRING and the report`,
    );
  }
  assert.equal(FILTER_LAYER_WIRING.reachableFromPhoneProductChain, false);
  // tokay's own header is the documented reason its wrapper is not inherited.
  assert.match(
    fileText(join(DEVICE_DIR, "tokay", "guardtalk-tokay.mk")),
    /NOT currently in the product inherit chain/,
  );
});

test("WIRING: the fallbacks the fleet data counts on actually exist", () => {
  assert.ok(existsSync(TOKAY_HARDENING), "tokay hardening is the documented fallback for 12 devices");
  assert.ok(existsSync(SHARED_THEME), "the shared theme is the fallback for withheld devices");
  assert.match(fileText(VARIANTS_MK), /GT_DEVICE_BLOCKLIST_komodo/);
  assert.match(fileText(join(DEVICE_DIR, "komodo", "BoardConfig-excised-late.mk")), /gt-excision-validate-device-blocklist/);
});

test("WIRING: insmod is a build-system repair, so only the reference/tablet exempt it", () => {
  // `guardtalk-insmod.mk` fixes adevtool's `find -copy-subdir-files` when the
  // kernel dir is a symlink — it is NOT a product feature, so its absence must
  // never be read as a capability gap.
  const exempt = DEVICE_FLEET.filter((row) => row.insmod === "not-required").map((row) => row.id);
  assert.deepEqual(exempt.sort(), ["tangorpro", "tokay"]);
  assert.equal(exempt.includes("akita"), false, "akita carries the repair file");
});
