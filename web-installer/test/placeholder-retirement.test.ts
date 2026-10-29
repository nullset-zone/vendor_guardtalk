/**
 * F-WEBINSTALL-PLACEHOLDER-RETIREMENT — acceptance proof (D-041).
 *
 * Acceptance:
 *   (a) zero `// confirm` strings in the emitted `dist/site`;
 *   (b) every replacement is actionable and, where it matters, blocks the
 *       destructive step;
 *   (c) nothing fabricated — anything unavailable says so;
 *   (d) the CLI export path handled the same way;
 *   (e) tests assert (a) and (b) — this file.
 *
 * The token is written here as a single const so the assertions stay readable
 * without the literal appearing five times; the check itself is a plain
 * substring scan of every emitted byte under `dist/site`, exactly the grep the
 * card specifies.
 */
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { generateCliExport, type CliExportPlan } from "../lib/cli-export/generator.js";
import { WIZARD_DEVICES } from "../lib/ui/offered-devices.js";
import {
  MISSING_FACTS,
  ONION_ADDRESS_FACT,
  RELEASE_FINGERPRINT_FACT,
  UNAVAILABLE_CHIP_WORD,
  renderUnavailableFact,
  unavailableFactLines,
} from "../lib/ui/unavailable.js";
import { renderStep0, renderStep1, renderStep4 } from "../routes/install/early-steps.js";
import {
  CLOSING_SENTENCE,
  GENERATE_HIDDEN_REASON,
  SIDELOAD_NOTE,
  UPDATE_INTRO,
  UPDATE_NO_PUSH,
} from "../routes/update/update-route.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";

const ROOT_URL = new URL("..", import.meta.url);
const REL = (rel: string): string => readFileSync(fileURLToPath(new URL(rel, ROOT_URL)), "utf8");
const SITE = fileURLToPath(new URL("dist/site", ROOT_URL));

/** The exact token the card forbids in emitted output. */
const FORBIDDEN_TOKEN = "// confirm";

function walk(dir: string): string[] {
  const out: string[] = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) {
      out.push(...walk(full));
    } else {
      out.push(full);
    }
  }
  return out;
}

/* ================================================================== *
 * (a) zero tokens in the emitted site
 * ================================================================== */

test("(a) zero forbidden tokens anywhere in the emitted site", () => {
  const files = walk(SITE);
  assert.ok(files.length > 0, "dist/site must be built before this suite runs");
  const offenders = files.filter((file) => readFileSync(file, "utf8").includes(FORBIDDEN_TOKEN));
  assert.deepEqual(
    offenders.map((file) => file.slice(SITE.length + 1)),
    [],
    "emitted files still carry a pending-confirmation token",
  );
});

test("(a) non-vacuity: the emitted modules carry the honest replacement, not silence", () => {
  // A tree with no content would trivially contain no token. Prove the fact
  // table and both renderers actually ship to the site.
  const facts = REL("dist/site/lib/ui/unavailable.js");
  for (const id of ["Q-04", "Q-05", "Q-07", "Q-08"]) {
    assert.ok(facts.includes(id), `the ${id} fact must reach the emitted site`);
  }
  assert.ok(facts.includes("UNAVAILABLE"), "the honest word must reach the emitted site");
  assert.ok(facts.includes("data-unavailable"), "the emitted block must mark itself");
  assert.ok(
    REL("dist/site/install/early-steps.js").includes("renderUnavailableFact"),
    "the /install route must render the block",
  );
  assert.ok(
    REL("dist/site/install/update/update-route.js").includes("renderUnavailableFact"),
    "the /update route must render the block",
  );
  assert.ok(
    REL("dist/site/lib/cli-export/generator.js").includes("unavailableFactLines"),
    "the CLI export must reuse the same fact text",
  );
});

test("(a) non-vacuity: the five retired constants are gone from source", () => {
  // routes/install/early-steps.ts held four; lib/cli-export/generator.ts held
  // one. Both files must be token-free at the source too, comments included.
  for (const rel of ["routes/install/early-steps.ts", "lib/cli-export/generator.ts"]) {
    assert.equal(REL(rel).includes(FORBIDDEN_TOKEN), false, rel);
  }
});

test("(a) the update route's copy constants carry no token", () => {
  for (const text of [SIDELOAD_NOTE, UPDATE_INTRO, UPDATE_NO_PUSH, CLOSING_SENTENCE, GENERATE_HIDDEN_REASON]) {
    assert.equal(text.includes(FORBIDDEN_TOKEN), false, text);
  }
});

/* ================================================================== *
 * (b) every replacement is actionable and blocks where it matters
 * ================================================================== */

test("(b) each unavailable fact states what is missing, where, what to do, and what it blocks", () => {
  for (const fact of Object.values(MISSING_FACTS)) {
    const html = renderUnavailableFact(fact);
    assert.ok(html.includes(UNAVAILABLE_CHIP_WORD), `${fact.id}: chip word missing`);
    assert.match(html, /Where the absence is recorded/, `${fact.id}: evidence row missing`);
    assert.match(html, /What you must do/, `${fact.id}: action row missing`);
    assert.match(html, /What this blocks/, `${fact.id}: blocking row missing`);
    assert.ok(html.includes(`data-unavailable="${fact.id}"`), `${fact.id}: not machine-identifiable`);
    assert.match(html, /data-proceed="forbidden"/, `${fact.id}: refusal not marked`);
    // Every field is real prose, not a stub: a one-word value would be a
    // placeholder with extra steps.
    for (const field of [fact.label, fact.what, fact.evidence, fact.action, fact.blocks]) {
      assert.ok(field.trim().length > 20, `${fact.id}: field too thin: ${JSON.stringify(field)}`);
    }
  }
});

test("(b) the facts that gate a destructive step say so, and name the step", () => {
  // Q-04 / Q-05 gate the flash step; Q-07 gates signing. Q-08 gates nothing and
  // is allowed to say exactly that — a false block would be its own overclaim.
  assert.match(ONION_ADDRESS_FACT.blocks, /step 6/);
  assert.match(RELEASE_FINGERPRINT_FACT.blocks, /step 6/);
  assert.match(String(MISSING_FACTS["Q-07"].blocks), /step 4/);
  assert.match(String(MISSING_FACTS["Q-08"].blocks), /nothing/);
});

test("(b) step 1 and step 4 render the blocking affordance, not a token", () => {
  const step1 = renderStep1({ package: false, sums: false, sig: false });
  assert.ok(step1.includes(`data-unavailable="${ONION_ADDRESS_FACT.id}"`));
  assert.ok(step1.includes(`data-unavailable="${RELEASE_FINGERPRINT_FACT.id}"`));
  const step4 = renderStep4({
    status: "stopped",
    algorithm: "SHA256_RSA4096",
    rows: [],
    stopReason: STOP_REASONS.PARTITION_LAYOUT_UNKNOWN,
    chainPartitions: ["vbmeta_system"],
  });
  assert.ok(step4.includes(`data-unavailable="Q-07"`));
  for (const html of [step1, step4, renderStep0()]) {
    assert.equal(html.includes(FORBIDDEN_TOKEN), false);
  }
});

/* ================================================================== *
 * (c) nothing fabricated
 * ================================================================== */

test("(c) no address, host, digest or device name is invented", () => {
  const all = Object.values(MISSING_FACTS).map(renderUnavailableFact).join("\n");
  assert.doesNotMatch(all, /\.onion/i, "no onion host may be invented");
  assert.doesNotMatch(all, /\b[a-z2-7]{56}\b/, "no v3 onion body may be invented");
  // No fingerprint-shaped digest: the whole point is that we do not have one.
  assert.doesNotMatch(all, /[A-Fa-f0-9]{32,}/, "no digest may be invented");
});

test("(c) Q-06 is filled from the shipped product fact instead of a placeholder", () => {
  const rango = WIZARD_DEVICES.find((device) => device.id === "rango");
  assert.equal(rango?.deviceName, "Pixel 10 Pro Fold", "the Q-06 fact is a shipped product value");
  // ...and it renders from that one source, with no second copy.
  assert.ok(renderStep0().includes("Pixel 10 Pro Fold"));
  assert.equal(renderStep0().includes(FORBIDDEN_TOKEN), false);
});

/* ================================================================== *
 * (d) the CLI export path, handled identically
 * ================================================================== */

function cliPlan(): CliExportPlan {
  return {
    releaseFiles: [{ name: "GuardTalkOS-tokay.zip", sha256: "aa11".repeat(16) }],
    targetProduct: "tokay",
    keyFlow: "bring-your-own",
    vbmetaTargets: [{ partition: "vbmeta", imageFile: "vbmeta.img", topLevel: true }],
    firmwareImages: [{ partition: "boot", imageFile: "boot.img" }],
    osImages: [{ partition: "system", imageFile: "system.img" }],
  };
}

test("(d) the CLI export reuses the SAME fact text as the page (one source, no fork)", () => {
  const script = generateCliExport(cliPlan());
  for (const fact of [ONION_ADDRESS_FACT, RELEASE_FINGERPRINT_FACT]) {
    for (const line of unavailableFactLines(fact)) {
      assert.ok(script.includes(`# ${line}`), `CLI export drifted from the page: ${line}`);
    }
  }
  assert.equal(script.includes(FORBIDDEN_TOKEN), false);
});

test("(d) the CLI export requires the values it cannot supply, before any write", () => {
  const script = generateCliExport(cliPlan());
  assert.match(script, /^RELEASE_PROVENANCE_FINGERPRINT=''$/m);
  assert.match(script, /^RELEASE_KEY_PEM=''$/m);
  const guard = script.indexOf('[ -n "$RELEASE_PROVENANCE_FINGERPRINT" ]');
  assert.ok(guard >= 0, "the provenance guard must exist");
  assert.ok(guard < script.indexOf("fastboot erase avb_custom_key"), "guard must precede the first write");
  assert.ok(guard < script.indexOf("&& fastboot flashing unlock"), "guard must precede the wipe");
});
