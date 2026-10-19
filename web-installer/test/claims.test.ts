import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { INSTALLER_CSP, cspMetaTag } from "../lib/claims/csp.js";
import { formatHits, lintFiles, lintText, main } from "../lib/claims/lint-claims.js";

test("forbidden OTA / push / remote-update phrases are caught", () => {
  const fixtures = [
    "This app receives automatic update pushes.",
    "Install over-the-air in one step.",
    "Supports OTA updates.",
    "We'll push the next build to your phone.",
    "Remote update keeps you current.",
  ];
  for (const fixture of fixtures) {
    const hits = lintText(fixture, "fixture.txt");
    assert.ok(hits.some((hit) => hit.rule === "no-ota-language"), fixture);
  }
});

test("superlatives and pressure CTAs are caught", () => {
  for (const fixture of ["Install now!", "One-click setup.", "It's easy to start."]) {
    const hits = lintText(fixture, "fixture.txt");
    assert.ok(hits.some((hit) => hit.rule === "no-superlatives"), fixture);
  }
});

test("security words without a named mechanism are caught", () => {
  const hits = lintText("Your data is safe with us.", "fixture.txt");
  assert.ok(hits.some((hit) => hit.rule === "security-word-requires-mechanism"));
});

test("security words pass when the mechanism is named", () => {
  const allowed = [
    "Protected by your verified boot key.",
    "The package signature is checked before anything is written.",
    "Each file is confirmed by hash comparison.",
    "AVB enforces the boot chain your key signs.",
    "The Gateway never sees your key material.",
    "The installer runs air-gapped; nothing leaves the tab.",
  ];
  for (const fixture of allowed) {
    const hits = lintText(fixture, "fixture.txt");
    assert.deepEqual(hits.filter((hit) => hit.rule === "security-word-requires-mechanism"), [], fixture);
  }
});

test("auto-advance patterns are caught", () => {
  const hits = lintText("setInterval(() => advance(), 1000);", "machine.ts");
  assert.ok(hits.some((hit) => hit.rule === "no-auto-advance"));
});

test("generate-flow references are caught in update-route bundles only", () => {
  const generateLine = "const key = await generateKey('RSA-OAEP');";
  const updateHits = lintText(generateLine, "update-bundle.js", { route: "update" });
  assert.ok(updateHits.some((hit) => hit.rule === "no-generate-flow-on-update"));
  const installHits = lintText(generateLine, "install-bundle.js", { route: "install" });
  assert.deepEqual(installHits.filter((hit) => hit.rule === "no-generate-flow-on-update"), []);
});

test("success markers before fingerprint comparison are caught", () => {
  const hits = lintText("All done — success!", "step8.ts");
  assert.ok(hits.some((hit) => hit.rule === "no-success-before-fingerprint-compare"));
  const withCompare = lintText("Success shown after the fingerprint comparison.", "step8.ts");
  assert.deepEqual(withCompare.filter((hit) => hit.rule === "no-success-before-fingerprint-compare"), []);
});

test("file:line report formatting", () => {
  const hits = lintText("ok line\nOTA update available", "a.txt");
  const report = formatHits(hits);
  assert.match(report, /a\.txt:2 \[no-ota-language\]/);
});

test("CSP string matches D-006 exactly", () => {
  assert.equal(
    INSTALLER_CSP,
    "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'",
  );
  assert.equal(
    cspMetaTag(),
    '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'self\'; style-src \'self\'; img-src \'self\' data:; connect-src \'none\'">',
  );
});

test("lint CLI exits non-zero on hits, zero when clean", () => {
  assert.equal(main([]), 2);
});

// ---------------------------------------------------------------------------
// T-EXCISE-CLAIMS-LINTER-RADIO-FAMILY — radio/RIL/telephony-excision family
// ---------------------------------------------------------------------------

const RADIO_OVERCLAIM_FIXTURE = fileURLToPath(
  new URL("./fixtures/claims/radio-overclaim.txt", import.meta.url),
);
const RADIO_HONEST_FIXTURE = fileURLToPath(
  new URL("./fixtures/claims/radio-honest.txt", import.meta.url),
);

test("unqualified radio/RIL/telephony excision absolutes are caught", () => {
  const unqualified = [
    "- Radio is excised (`GUARDTALK_RADIO_EXCISED=true`, `modem` stripped from",
    "Radio/RIL fully excised; baseband radio.img fully removed.",
    "The modem is completely removed.",
    "Telephony is gone.",
    "radio.img fully removed.",
  ];
  for (const fixture of unqualified) {
    const hits = lintText(fixture, "fixture.txt");
    assert.ok(
      hits.some((hit) => hit.rule === "no-radio-excision-overclaim"),
      fixture,
    );
  }
});

test("qualified radio excision statements stay silent (host-side vs runtime verdict)", () => {
  const qualified = [
    "Dead weight with the host-side RIL/telephony userspace excised; the runtime radio verdict remains FALSE (Tier B).",
    "Radio/RIL *userspace* is excised on the host; the baseband (radio.img) still ships as a Tier-B residual.",
    "\"Radio is excised\" here means the host radio/RIL userspace is removed; it is not a baseband-free claim.",
    "A-EXCISE-RADIO_AUDIT: the modem surface is not fully excised.",
  ];
  for (const fixture of qualified) {
    const hits = lintText(fixture, "fixture.txt");
    assert.deepEqual(
      hits.filter((hit) => hit.rule === "no-radio-excision-overclaim"),
      [],
      fixture,
    );
  }
});

test("radio overclaim fixture BITES (CLI-facing lintFiles path)", () => {
  assert.ok(
    lintFiles([RADIO_OVERCLAIM_FIXTURE]).some((hit) => hit.rule === "no-radio-excision-overclaim"),
  );
});

test("radio honest fixture is CLEAN (CLI-facing lintFiles path)", () => {
  assert.deepEqual(
    lintFiles([RADIO_HONEST_FIXTURE]).filter((hit) => hit.rule === "no-radio-excision-overclaim"),
    [],
  );
});

test("radio fixtures prove non-vacuity both ways through the CLI exit code", () => {
  assert.equal(main([RADIO_OVERCLAIM_FIXTURE]), 1);
  assert.equal(main([RADIO_HONEST_FIXTURE]), 0);
});

// ---------------------------------------------------------------------------
// T-EXCISE-CLAIMS-LINTER-RADIO-HARDENING — close H1..H5
// QA's 11 false negatives (C1-C11) and 7 false positives (D1-D6) must flip;
// the attached-qualifier and non-functional-context allow-lists must not become
// a new evasion surface.
// ---------------------------------------------------------------------------

const RADIO_HARDENING_OVERCLAIM_FIXTURE = fileURLToPath(
  new URL("./fixtures/claims/radio-hardening-overclaim.txt", import.meta.url),
);
const RADIO_HARDENING_HONEST_FIXTURE = fileURLToPath(
  new URL("./fixtures/claims/radio-hardening-honest.txt", import.meta.url),
);
const RADIO_HARDENING_CONTEXT_FIXTURE = fileURLToPath(
  new URL("./fixtures/claims/radio-hardening-context.txt", import.meta.url),
);

test("H1-H3: absolute overclaims no longer disarm on a co-occurring scope word", () => {
  const mustBite = [
    // H2 — widened verb set
    "The radio has been fully purged from the image.",
    "RIL has been neutralized.",
    "The modem stack is off for good.",
    "Cellular capability no longer exists in the build.",
    "The baseband was wiped clean.",
    // H3 — sentence split / long gap
    "Radio and modem. Fully excised.",
    "The radio, together with all of its associated vendor blobs and firmware, has been fully excised.",
    // H1 — honest scope vocabulary must not neuter an absolute claim
    "The host device radio is completely removed.",
    "Runtime radio fully removed.",
    "Verdict: radio fully excised.",
    "The radio is fully excised; no exceptions.",
  ];
  for (const fixture of mustBite) {
    const hits = lintText(fixture, "fixture.txt");
    assert.ok(
      hits.some((hit) => hit.rule === "no-radio-excision-overclaim"),
      fixture,
    );
  }
});

test("H1: attached qualifiers and residual markers still suppress", () => {
  const mustStaySilent = [
    "host-side userspace excised; runtime radio verdict remains FALSE",
    "the modem surface is not fully excised",
    "baseband still ships; Tier-B residual",
    "Radio/RIL *userspace* is excised on the host; baseband (radio.img) still ships as a Tier-B residual.",
    '"Radio is excised" here means the host radio/RIL userspace is removed; it is not a baseband-free claim.',
    "RIL userspace excised; runtime verdict FALSE.",
    "No radio excision at the baseband layer.",
    "The telephony HAL is removed on the host side; runtime verdict unchanged.",
    "The radio is not excised.",
    "The telephony service is stopped, not removed.",
    "radio excision only, no baseband-free claim.",
  ];
  for (const fixture of mustStaySilent) {
    const hits = lintText(fixture, "fixture.txt");
    assert.deepEqual(
      hits.filter((hit) => hit.rule === "no-radio-excision-overclaim"),
      [],
      fixture,
    );
  }
});

test("H4: UI/build non-functional contexts stay silent without creating an evasion", () => {
  const context = [
    "Radio buttons are removed in the compact layout.",
    "The cellular status icon is removed when the device is offline.",
    "The radio.img partition is removed from the fastboot flash list.",
    "Carrier radio calibration data is removed before flashing.",
    "Radio firmware files are removed from the AOSP device tree by the excision pass.",
    "Telephony permission requests are removed by the privacy overlay.",
  ];
  for (const fixture of context) {
    const hits = lintText(fixture, "fixture.txt");
    assert.deepEqual(
      hits.filter((hit) => hit.rule === "no-radio-excision-overclaim"),
      [],
      fixture,
    );
  }
  // Non-evasion: a bare overclaim still bites even when it names a token the
  // allow-list keys on, because the allow-list requires the full context.
  const stillBites = [
    "The radio is fully removed.",
    "The radio firmware is fully removed from the device.",
  ];
  for (const fixture of stillBites) {
    const hits = lintText(fixture, "fixture.txt");
    assert.ok(
      hits.some((hit) => hit.rule === "no-radio-excision-overclaim"),
      fixture,
    );
  }
});

test("H5: the HAL qualifier is case-insensitive", () => {
  for (const fixture of [
    "The telephony hal is removed on the device.",
    "The telephony HAL is removed on the device.",
  ]) {
    const hits = lintText(fixture, "fixture.txt");
    assert.deepEqual(
      hits.filter((hit) => hit.rule === "no-radio-excision-overclaim"),
      [],
      fixture,
    );
  }
});

test("hyphenated labels and path tokens are not excision overclaims", () => {
  for (const fixture of [
    "the include path radio-excised.mk is used by the build.",
    "apps-excised.mk and vintf-excised.mk are copied.",
    "the directory radio-excised/ holds the variant.",
  ]) {
    const hits = lintText(fixture, "fixture.txt");
    assert.deepEqual(
      hits.filter((hit) => hit.rule === "no-radio-excision-overclaim"),
      [],
      fixture,
    );
  }
});

test("hardening fixtures: overclaim bites while honest + context stay clean", () => {
  assert.ok(
    lintFiles([RADIO_HARDENING_OVERCLAIM_FIXTURE]).some(
      (hit) => hit.rule === "no-radio-excision-overclaim",
    ),
  );
  assert.deepEqual(
    lintFiles([RADIO_HARDENING_HONEST_FIXTURE, RADIO_HARDENING_CONTEXT_FIXTURE]).filter(
      (hit) => hit.rule === "no-radio-excision-overclaim",
    ),
    [],
  );
});

test("hardening fixtures prove non-vacuity both ways through the CLI exit code", () => {
  assert.equal(main([RADIO_HARDENING_OVERCLAIM_FIXTURE]), 1);
  assert.equal(main([RADIO_HARDENING_HONEST_FIXTURE]), 0);
  assert.equal(main([RADIO_HARDENING_CONTEXT_FIXTURE]), 0);
});
