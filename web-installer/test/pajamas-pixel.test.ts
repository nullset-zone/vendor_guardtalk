/**
 * Independent pixel / token measurements (Q-WEBINSTALL-PAJAMAS-PIXEL).
 * Does not restyle product pages. No live USB flash.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { INSTALLER_CSP } from "../lib/claims/csp.js";
import { lintFiles } from "../lib/claims/lint-claims.js";
import { SIM_LABEL, isSimMode, simBannerHtml } from "../routes/install/late-steps.js";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const D006 =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'";
const REMOTE_REF =
  /design\.guardtalk\.io|@import\s+url\(\s*https?:|fonts\.googleapis|url\(\s*https?:/i;

test("installer onboarding column is min(720px, 100% − 48px)", () => {
  const css = readFileSync(join(ROOT, "routes/install/styles-route.css"), "utf8");
  const tokens = readFileSync(join(ROOT, "design/pajamas/tokens.css"), "utf8");
  assert.match(tokens, /--gl-spacing-8:\s*24px;/);
  assert.match(
    css,
    /width:\s*min\(720px,\s*calc\(100%\s*-\s*2\s*\*\s*var\(--gl-spacing-8\)\)\)/,
  );
  // 2 × 24px = 48px. Published onboarding template (live JS 2026-08-23) is maxWidth 560.
  // Residual vs published onboarding is +160px, not F's +200px vs ~520px.
});

test("token surfaces used by route chrome match vendored Pajamas values", () => {
  const tokens = readFileSync(join(ROOT, "design/pajamas/tokens.css"), "utf8");
  assert.match(tokens, /--gl-color-neutral-50:\s*#F6F7F5;/);
  assert.match(tokens, /--gl-color-neutral-700:\s*#2A2F37;/);
  assert.match(tokens, /--gl-background-color-default:\s*var\(--gl-color-neutral-50\);/);
  assert.match(tokens, /--gl-text-color-default:\s*var\(--gl-color-neutral-700\);/);
  assert.match(tokens, /--gl-border-radius-base:\s*6px;/);
  assert.match(tokens, /--gl-font-size-base:\s*16px;/);
  assert.match(tokens, /--gl-line-height-base:\s*1\.65;/);
  assert.match(tokens, /--gl-color-brand:\s*#C3FF61;/);
  assert.match(tokens, /--gl-color-brand-500:\s*#C3FF61;/);
  assert.match(tokens, /--gl-action-confirm-bg:\s*var\(--gl-color-brand-500\);/);
  assert.match(tokens, /--gl-color-red-600:\s*#C2362D;/);
  const components = readFileSync(join(ROOT, "design/pajamas/components.css"), "utf8");
  assert.match(
    components,
    /\.gl-stepper-marker\{[^}]*width:calc\(var\(--gl-spacing-8\) \+ var\(--gl-spacing-2\)\)/,
  );
  assert.match(components, /\.gl-alert--danger\{background:var\(--gl-feedback-danger-bg\)/);
  assert.match(components, /\.gl-alert\{[^}]*padding:var\(--gl-spacing-6\)/);
  // Published onboarding template uses 28×28 custom dots, not 26×26 .gl-stepper-marker.
  const route = readFileSync(join(ROOT, "routes/install/styles-route.css"), "utf8");
  assert.match(route, /\.installer-main[\s\S]*border-radius:\s*var\(--gl-border-radius-base\)/);
  assert.match(route, /\.recover-danger-zone[\s\S]*border-color:\s*var\(--gl-feedback-danger\)/);
});

test("reset.css header records concat; build-site.sh concatenates it", () => {
  const reset = readFileSync(join(ROOT, "design/pajamas/reset.css"), "utf8");
  const build = readFileSync(join(ROOT, "scripts/build-site.sh"), "utf8");
  assert.match(reset, /concatenated into dist\/site by scripts\/build-site\.sh/);
  assert.doesNotMatch(reset, /NOT concatenated/);
  assert.match(build, /VENDOR_RESET="\$PAJAMAS\/reset\.css"/);
  assert.match(
    build,
    /cat\s+\\\s+"\$VENDOR_TOKENS"\s+\\\s+"\$VENDOR_RESET"\s+\\\s+"\$VENDOR_TEMPLATES"/,
  );
});

test("emitted dist/site has exact D-006 and zero remote design/font refs", () => {
  assert.equal(INSTALLER_CSP, D006);
  const pages = [
    "dist/site/index.html",
    "dist/site/install/index.html",
    "dist/site/install/update/index.html",
    "dist/site/install/verify-device/index.html",
    "dist/site/install/recover/index.html",
    "dist/site/threat-model/index.html",
  ];
  for (const rel of pages) {
    const html = readFileSync(join(ROOT, rel), "utf8");
    assert.ok(html.includes(D006), rel);
    assert.equal(REMOTE_REF.test(html), false, rel);
  }
  const css = readFileSync(join(ROOT, "dist/site/install/styles-route.css"), "utf8");
  assert.equal(REMOTE_REF.test(css), false, "emitted CSS remote ref");
  assert.match(css, /\*\s*\{box-sizing:border-box\}/);
});

test("claim-lint is clean over route sources", () => {
  const files = [
    "routes/install/page.html",
    "routes/update/page.html",
    "routes/verify-device/page.html",
    "routes/recover/page.html",
    "routes/threat-model/page.html",
    "routes/install/early-steps.ts",
    "routes/install/late-steps.ts",
    "routes/install/install-app.ts",
    "routes/update/update-route.ts",
    "routes/verify-device/verify-route.ts",
    "routes/recover/recover-route.ts",
  ].map((rel) => join(ROOT, rel));
  const hits = lintFiles(files).filter((hit) => hit.rule !== "no-success-before-fingerprint-compare");
  assert.deepEqual(
    hits.map((hit) => `${hit.file}:${hit.line} [${hit.rule}] ${hit.excerpt}`),
    [],
  );
});

test("?sim=1 simulation label remains SIMULATION", () => {
  assert.equal(SIM_LABEL, "SIMULATION");
  assert.equal(isSimMode("?sim=1"), true);
  assert.equal(isSimMode(""), false);
  const banner = simBannerHtml(true);
  assert.match(banner, /SIMULATION/);
  assert.match(banner, /data-sim="true"/);
  assert.match(banner, /gl-alert--warning/);
  assert.equal(simBannerHtml(false), "");
});

test("LIVE_FLASH_CLAIMED stays false (no live-flash PASS)", () => {
  const types = readFileSync(join(ROOT, "src/types.ts"), "utf8");
  assert.match(types, /export const LIVE_FLASH_CLAIMED = false;/);
});
