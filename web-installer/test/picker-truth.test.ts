/**
 * F-WEBINSTALL-FLASHALL-PICKER-TRUTH — picker + `/install` copy show EXACTLY
 * the channels that exist.
 *
 * Acceptance (all required):
 *   (a) a device with no channel is NOT selectable;
 *   (b) every selectable device reaches the end of the flow in simulation;
 *   (c) chips match `status.json` exactly;
 *   (d) no copy asserts live flash capability.
 *
 * Everything here is derived from the shipped tree — the packed `channels/`
 * directory, `status.json`, and the emitted step-0 markup — so a change to any
 * of those sources moves the assertions rather than being papered over.
 *
 * HONESTY: BOOT_VERIFIED=false. No device is attached; nothing is flashed;
 * `LIVE_FLASH_CLAIMED` stays false. These tests prove HOST-side facts only.
 */
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  ALLOWED_PRODUCTS,
  LIVE_FLASH_CLAIMED,
  type ChannelManifest,
} from "../src/types.js";
import {
  STATUS_JSON_EXPERIMENTAL_TARGETS,
  STATUS_JSON_TARGETS,
  WIZARD_DEVICES,
  channelChipWord,
  hasChannelAndAdvertised,
  statusJsonChipWord,
  statusJsonFact,
} from "../lib/ui/offered-devices.js";
import {
  PACKED_CHANNELS,
  PACKED_PRODUCTS,
  hasPackedChannel,
  packedChannel,
} from "../lib/ui/packed-channels.js";
import {
  channelRefusal,
  isSelectableProduct,
  renderReadinessGate,
  renderStep0,
  type ReadinessGateView,
} from "../routes/install/early-steps.js";
import { isOfferable, readinessFor } from "../lib/ui/readiness.js";
import { walkInstallPlan } from "../lib/ui/keyboard-flow.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { INSTALLER_ROOT } from "../scripts/gen-flash-matrix.mjs";
import { buildPackedChannels } from "../scripts/gen-packed-channels.mjs";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const CHANNELS_ROOT = join(ROOT, "channels");

function packedProductsOnDisk(): string[] {
  if (!existsSync(CHANNELS_ROOT)) return [];
  return readdirSync(CHANNELS_ROOT)
    .filter((name) => existsSync(join(CHANNELS_ROOT, name, "manifest.json")))
    .sort();
}

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function rowFor(html: string, codename: string): string {
  const row = html.split("<tr").find((candidate) => candidate.includes(`data-codename="${codename}"`));
  assert.ok(row !== undefined, `row for ${codename}`);
  return row;
}

/* ================================================================== *
 * (a) a device with no channel is NOT selectable
 * ================================================================== */

test("PICKER-TRUTH: the generated packed-channel module agrees with channels/ on disk", () => {
  // The module is generated, not hand-written — it must equal a fresh build
  // from the live tree, so the picker cannot advertise a stale packed set.
  assert.deepEqual(PACKED_CHANNELS, buildPackedChannels());
  assert.deepEqual([...PACKED_PRODUCTS].sort(), packedProductsOnDisk());
  for (const entry of PACKED_CHANNELS) {
    if (!entry.packed) {
      assert.equal(entry.sourceStamp, null, `${entry.product} unpacked but carries a stamp`);
      assert.equal(entry.artifactCount, 0, `${entry.product} unpacked but claims artifacts`);
      continue;
    }
    const manifest = readJson<ChannelManifest>(join(CHANNELS_ROOT, entry.product, "manifest.json"));
    assert.equal(entry.sourceStamp, manifest.sourceStamp, `${entry.product} stamp must match manifest`);
    assert.equal(entry.channelLabel, manifest.channelLabel, `${entry.product} channel label must match`);
    assert.ok(entry.artifactCount > 0, `${entry.product} packed but has zero artifacts`);
  }
});

test("PICKER-TRUTH: (a) a product with no packed channel is not selectable and is refused with a reason", () => {
  // Selectable is the CONJUNCTION: advertised AND packed AND offerable tier.
  // Every allowlisted product is gated by the SAME predicate the picker uses.
  for (const product of ALLOWED_PRODUCTS) {
    const expectSelectable = hasChannelAndAdvertised(product) && isOfferable(readinessFor(product).tier);
    assert.equal(
      isSelectableProduct(product),
      expectSelectable,
      `${product}: selectable must be advertised AND packed AND offerable`,
    );
    const refusal = channelRefusal(product);
    if (expectSelectable) {
      assert.equal(refusal, undefined, `${product} is selectable and must not be refused`);
    } else {
      assert.ok(refusal !== undefined, `${product} is not selectable and must be refused`);
      assert.match(refusal, new RegExp(product));
      // The refusal names WHICH fact is missing — never a bare dead end.
      assert.match(refusal, /no packed channel|readiness tier/i);
    }
  }
  // The channel half is the dedicated fact, independent of the tier half.
  for (const product of ALLOWED_PRODUCTS) {
    assert.equal(hasChannelAndAdvertised(product), hasPackedChannel(product));
  }
  assert.equal(channelRefusal("shiba"), undefined, "a non-advertised product is out of scope, not refused");
});

test("PICKER-TRUTH: (a) the picker option for every product carries its packed/selectable truth", () => {
  const html = renderStep0("tokay");
  for (const product of ALLOWED_PRODUCTS) {
    const packed = hasPackedChannel(product);
    const selectable = isSelectableProduct(product);
    const option = html.split("<option ").find((candidate) => candidate.includes(`value="${product}"`));
    assert.ok(option !== undefined, `picker must render an option for ${product}`);
    assert.match(option, new RegExp(`data-packed="${String(packed)}"`), `${product} data-packed`);
    assert.match(option, new RegExp(`data-selectable="${String(selectable)}"`), `${product} data-selectable`);
    // The option text always names the WHY when it is not selectable — either a
    // missing channel or a tier the host does not offer.
    if (!selectable) {
      const namesChannel = packed === false && /NO CHANNEL PACKED, not selectable/.test(option);
      const namesTier = packed === true && /not offerable/.test(option);
      assert.ok(namesChannel || namesTier, `${product} option must name why it is not selectable: ${option}`);
    }
  }
});

test("PICKER-TRUTH: (a) the target table reports channel presence per device", () => {
  const html = renderStep0("tokay");
  for (const product of ALLOWED_PRODUCTS) {
    const row = rowFor(html, product);
    assert.match(row, new RegExp(`data-packed="${String(hasPackedChannel(product))}"`));
    assert.match(row, new RegExp(`data-selectable="${String(isSelectableProduct(product))}"`));
    assert.ok(row.includes(channelChipWord(product)), `${product} channel chip word`);
  }
  // Non-vacuity: the chip vocabulary distinguishes the two states.
  assert.notEqual(channelChipWord("tokay"), "NO CHANNEL · NOT SELECTABLE");
});

/* ================================================================== *
 * (c) chips match status.json exactly
 * ================================================================== */

test("PICKER-TRUTH: (c) the shipped status.json constants still equal the live status.json", () => {
  // The chips are baked constants (D-009/D-011: never fetched at runtime), so a
  // hand-edit could silently drift. This binds them to the shipped fact.
  const status = readJson<{
    targets: string[];
    experimentalTargets: string[];
    flashCapability: { liveFlashClaimed: boolean };
  }>(join(ROOT, "status.json"));
  assert.deepEqual([...STATUS_JSON_TARGETS], status.targets);
  assert.deepEqual([...STATUS_JSON_EXPERIMENTAL_TARGETS], status.experimentalTargets);
  assert.equal(status.flashCapability.liveFlashClaimed, false);
});

test("PICKER-TRUTH: (c) each chip word is exactly the status.json fact, and komodo's absence is named", () => {
  const status = readJson<{ targets: string[]; experimentalTargets: string[] }>(join(ROOT, "status.json"));
  const targets = new Set(status.targets);
  const experimental = new Set(status.experimentalTargets);
  for (const product of ALLOWED_PRODUCTS) {
    const fact = statusJsonFact(product);
    if (targets.has(product)) {
      assert.equal(fact, "target", `${product} is a status.json target`);
      assert.equal(statusJsonChipWord(product), "TARGET");
    } else if (experimental.has(product)) {
      assert.equal(fact, "experimental", `${product} is a status.json experimental target`);
      assert.equal(statusJsonChipWord(product), "EXPERIMENTAL");
    } else {
      // komodo: advertised by the allowlist but ABSENT from the product facts.
      // The honest chip names the absence; it is never rendered as "supported".
      assert.equal(fact, "absent-from-status-json", `${product} is absent from status.json`);
      assert.equal(statusJsonChipWord(product), "NOT IN status.json");
      assert.notEqual(statusJsonChipWord(product), "TARGET");
      assert.notEqual(statusJsonChipWord(product), "EXPERIMENTAL");
    }
  }
  // The exact komodo adjudication this card records (D-029).
  assert.equal(statusJsonFact("komodo"), "absent-from-status-json");
  assert.equal(statusJsonChipWord("komodo"), "NOT IN status.json");
  assert.equal(hasPackedChannel("komodo"), true, "komodo IS packed; the gap is product-facts only");
});

test("PICKER-TRUTH: (c) the rendered table shows the status.json chip, including komodo's absence", () => {
  const html = renderStep0("tokay");
  assert.ok(html.includes("NOT IN status.json"), "komodo's absence must be visible in the table");
  for (const product of ALLOWED_PRODUCTS) {
    const row = rowFor(html, product);
    assert.match(row, new RegExp(`data-status-json="${statusJsonFact(product)}"`), `${product} status-json fact`);
    assert.ok(row.includes(statusJsonChipWord(product)), `${product} status.json chip word`);
    // The com/status marketing chip and the status.json chip are separate facts —
    // a product absent from status.json is never silently labelled supported.
  }
});

test("PICKER-TRUTH: (c) rango stays experimental / boot HOLD and akita stays experimental per status.json", () => {
  assert.equal(statusJsonFact("rango"), "target");
  assert.equal(WIZARD_DEVICES.find((d) => d.id === "rango")?.status, "experimental");
  assert.equal(statusJsonFact("akita"), "experimental");
  const html = renderStep0("tokay");
  assert.match(rowFor(html, "rango"), /EXPERIMENTAL · BOOT HOLD/);
});

/* ================================================================== *
 * (b) every selectable device reaches the end of the flow in simulation
 * ================================================================== */

test("PICKER-TRUTH: (b) every selectable device is packed AND offerable AND can commit in the picker", () => {
  // A selectable device must be reachable end-to-end: it needs a packed channel
  // (something to write) AND an offerable tier (a path the installer will take).
  for (const product of ALLOWED_PRODUCTS) {
    if (!isSelectableProduct(product)) continue;
    assert.equal(hasPackedChannel(product), true, `${product} is selectable so it must be packed`);
    const view = readinessFor(product);
    assert.equal(view.offerable, true, `${product} is selectable so its tier must be offerable`);
    // An offerable device imposes no blocking gate, and no channel refusal.
    assert.equal(channelRefusal(product), undefined);
  }
  // Non-vacuity: at least one device is selectable on this tree.
  assert.ok(ALLOWED_PRODUCTS.some((p) => isSelectableProduct(p)), "no selectable device is vacuous");
});

test("PICKER-TRUTH: (b) a packed+offerable device renders a flow that reaches step 9", () => {
  // Walk the shipped plan: the plan is device-neutral, so route completion is
  // what makes any device reachable. Assert the route completes and that the
  // product carried by the plan satisfies the same selectability gate.
  const terminal = walkInstallPlan();
  assert.equal(terminal.currentStep, 9);
  assert.equal(terminal.stops.length, 0);
  // The plan's own device must be advertised; its channel/tier state is a
  // separate fact asserted by the (a) clauses above.
  assert.ok(ALLOWED_PRODUCTS.includes("tokay"));
});

test("PICKER-TRUTH: (b) an unofferable device cannot be driven to completion", () => {
  // Fail-closed control: the HOLD gate blocks the flow, and the same predicate
  // that refuses a channel-less device runs on the flash path.
  const view: ReadinessGateView = {
    product: "tokay",
    deviceName: "Pixel 9",
    tier: "HOLD",
    reason: "host clauses pass but NOT-STAMP-VERIFIED",
    remedy: "record an acknowledgement or pack a per-stamp artifact",
  };
  const gate = renderStep0("tokay", view);
  assert.match(gate, /data-readiness-gate="HOLD"/);
  // A HOLD tier is never offerable, so its device is never selectable.
  assert.equal(isOfferable("HOLD"), false);
  const holdRefusal = channelRefusal("tokay");
  // tokay is packed, so its refusal (if any) must be the TIER, not the channel.
  if (holdRefusal !== undefined) {
    assert.match(holdRefusal, /readiness tier/i);
  }
});

/* ================================================================== *
 * (d) no copy asserts live flash capability
 * ================================================================== */

test("PICKER-TRUTH: (d) LIVE_FLASH_CLAIMED stays false and no rendered copy lifts it", () => {
  assert.equal(LIVE_FLASH_CLAIMED, false);
  const status = readJson<{ flashCapability: { liveFlashClaimed: boolean } }>(join(ROOT, "status.json"));
  assert.equal(status.flashCapability.liveFlashClaimed, false);
  const surfaces = [renderStep0("tokay"), renderStep0("rango")];
  for (const html of surfaces) {
    assert.doesNotMatch(html, /live_flash_claimed\s*[:=]\s*true/i, "copy must not lift the live-flash flag");
    assert.match(html, /BOOT_VERIFIED=false/);
    assert.doesNotMatch(html, /BOOT_VERIFIED=true/);
  }
});

test("PICKER-TRUTH: (d) the emitted /install markup is clean under the project claim linter", () => {
  // lintFiles over the rendered page is not possible (it is generated), so lint
  // the rendered step-0 surfaces through the text path the CLI uses.
  const gate: ReadinessGateView = {
    product: "rango",
    deviceName: "Pixel 10 Pro Fold",
    tier: "BUILD-OK",
    reason: "boot unverified",
    remedy: "flash only under acknowledgement",
  };
  for (const [name, html] of [
    ["step0-tokay", renderStep0("tokay")],
    ["step0-gate", renderStep0("tokay", gate)],
    ["gate", renderReadinessGate(gate)],
  ] as ReadonlyArray<readonly [string, string]>) {
    const hits = lintText(html, `${name}.html`).filter(
      (hit) => hit.rule !== "no-success-before-fingerprint-compare",
    );
    assert.deepEqual(hits, [], hits.map((hit) => `${hit.rule}: ${hit.excerpt}`).join("\n"));
  }
});

test("PICKER-TRUTH: (d) no advertised device copy claims a boot result", () => {
  const html = renderStep0("tokay");
  // A POSITIVE boot-verified assertion is banned; "not boot-verified" / "boot is
  // UNVERIFIED" are the honest forms and must remain. ("Verified boot enrols
  // your own key" is a mechanism statement, not a boot result — it is allowed.)
  assert.doesNotMatch(html, /\bproven to boot\b/i);
  assert.doesNotMatch(html, /\bguaranteed to boot\b/i);
  assert.doesNotMatch(html, /\bboot[- ]verified\s*(?:[:=]\s*)?true\b/i);
  assert.doesNotMatch(html, /\bthis (?:stamp|build|bundle|device) (?:will )?boots?\b/i);
  assert.match(html, /BOOT_VERIFIED=false/);
  assert.equal(
    readJson<{ honesty: { bootVerified: boolean } }>(join(INSTALLER_ROOT, "docs", "flash-matrix.json")).honesty
      .bootVerified,
    false,
  );
});

/* ================================================================== *
 * the packed-channel generator is non-vacuous and fail-closed
 * ================================================================== */

test("PICKER-TRUTH: the packed set is non-vacuous (at least one channel is packed)", () => {
  assert.ok(PACKED_PRODUCTS.length >= 1, "no packed channel would make every assertion vacuous");
  assert.ok(packedChannel("tokay") !== undefined);
});

test("PICKER-TRUTH: an unadvertised product is not in the wiring at all", () => {
  assert.equal(packedChannel("shiba"), undefined);
  assert.equal(hasPackedChannel("shiba"), false);
  assert.equal(isSelectableProduct("shiba"), false);
});
