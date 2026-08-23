import assert from "node:assert/strict";
import { test } from "node:test";
import { INSTALLER_CSP, cspMetaTag } from "../lib/claims/csp.js";
import { formatHits, lintText, main } from "../lib/claims/lint-claims.js";

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
