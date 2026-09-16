/**
 * Independent H1/L2/L3 contrast + token pins (Q-WEBINSTALL-PAJAMAS-CONTRAST).
 * Does not restyle product pages. No live USB flash.
 */
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { INSTALLER_CSP } from "../lib/claims/csp.js";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const D006 =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'";
const REMOTE_REF =
  /design\.guardtalk\.io|@import\s+url\(\s*https?:|fonts\.googleapis|url\(\s*https?:/i;
const HEX = /#[0-9A-Fa-f]{3,8}\b/;
const RESET_SHA256 =
  "baa208696f550d219495495c6e89e7d48386569916e8dea4d2e4fbe9087b071b";
const RESET_OLD_SHA256 =
  "071b14e2acbf1e35fb74b8e019a93a82f15a695c4c6026bd783b50e229bbcc5e";
const RESET_OLD_LINE =
  " * GuardTalk Pajamas document reset (NOT concatenated into dist — would restyle route HTML).";
const RESET_NEW_LINE =
  " * GuardTalk Pajamas document reset (concatenated into dist/site by scripts/build-site.sh).";
const RESET_RULES =
  "*{box-sizing:border-box}\n" +
  "body{margin:0;background:var(--gl-background-color-default);color:var(--gl-text-color-default);" +
  "font-family:var(--gl-font-family);font-size:var(--gl-font-size-base);" +
  "line-height:var(--gl-line-height-base);-webkit-font-smoothing:antialiased}\n" +
  ":where(button,a,input,textarea,select,[role=tab],[role=menuitem],[role=switch])" +
  ":focus-visible{outline:2px solid var(--gl-focus-ring);outline-offset:1px}\n";

function srgbChannel(c: number): number {
  const x = c / 255;
  return x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
}

function relativeLuminance(hex: string): number {
  const h = hex.replace("#", "");
  const r = Number.parseInt(h.slice(0, 2), 16);
  const g = Number.parseInt(h.slice(2, 4), 16);
  const b = Number.parseInt(h.slice(4, 6), 16);
  return 0.2126 * srgbChannel(r) + 0.7152 * srgbChannel(g) + 0.0722 * srgbChannel(b);
}

function contrastRatio(fg: string, bg: string): number {
  const a = relativeLuminance(fg);
  const b = relativeLuminance(bg);
  const lighter = Math.max(a, b);
  const darker = Math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

function readRel(rel: string): string {
  return readFileSync(join(ROOT, rel), "utf8");
}

test("H1 confirm CTA contrast is >=4.5:1 on default/hover/active brand fills", () => {
  const tokens = readRel("design/pajamas/tokens.css");
  assert.match(tokens, /--gl-color-neutral-1000:\s*#0A0B0C;/);
  assert.match(tokens, /--gl-color-brand-500:\s*#C3FF61;/);
  assert.match(tokens, /--gl-color-brand-600:\s*#A6E83C;/);
  assert.match(tokens, /--gl-color-brand-700:\s*#7BAE26;/);
  assert.match(tokens, /--gl-action-confirm-text:\s*var\(--gl-color-neutral-1000\);/);
  assert.match(tokens, /--gl-button-confirm-text:\s*var\(--gl-action-confirm-text\);/);
  assert.match(tokens, /--gl-button-confirm-bg:\s*var\(--gl-action-confirm-bg\);/);
  assert.match(tokens, /--gl-action-confirm-bg:\s*var\(--gl-color-brand-500\);/);
  assert.match(tokens, /--gl-button-confirm-bg-hover:\s*var\(--gl-action-confirm-bg-hover\);/);
  assert.match(tokens, /--gl-action-confirm-bg-hover:\s*var\(--gl-color-brand-600\);/);
  assert.match(tokens, /--gl-action-confirm-bg-active:\s*var\(--gl-color-brand-700\);/);

  const def = contrastRatio("#0A0B0C", "#C3FF61");
  const hover = contrastRatio("#0A0B0C", "#A6E83C");
  const active = contrastRatio("#0A0B0C", "#7BAE26");
  const publishedFail = contrastRatio("#F6F7F5", "#C3FF61");
  assert.ok(def >= 4.5, `default ${def}`);
  assert.ok(hover >= 4.5, `hover ${hover}`);
  assert.ok(active >= 4.5, `active ${active}`);
  assert.ok(publishedFail < 4.5, `published ${publishedFail}`);
  assert.equal(def.toFixed(2), "16.69");
  assert.equal(hover.toFixed(2), "13.35");
  assert.equal(active.toFixed(2), "7.43");
  assert.equal(publishedFail.toFixed(2), "1.10");
});

test("L2 --gl-color-neutral-500 borders are >=3:1; --gl-color-neutral-400 fails", () => {
  const tokens = readRel("design/pajamas/tokens.css");
  assert.match(tokens, /--gl-color-neutral-500:\s*#6B727C;/);
  assert.match(tokens, /--gl-color-neutral-400:\s*#A7AEB8;/);
  assert.match(tokens, /--gl-color-neutral-50:\s*#F6F7F5;/);
  assert.match(tokens, /--gl-color-neutral-0:\s*#FFFFFF;/);

  const n500On50 = contrastRatio("#6B727C", "#F6F7F5");
  const n500OnWhite = contrastRatio("#6B727C", "#FFFFFF");
  const n400On50 = contrastRatio("#A7AEB8", "#F6F7F5");
  const n400OnWhite = contrastRatio("#A7AEB8", "#FFFFFF");
  assert.ok(n500On50 >= 3, `n500/n50 ${n500On50}`);
  assert.ok(n500OnWhite >= 3, `n500/white ${n500OnWhite}`);
  assert.ok(n400On50 < 3, `n400/n50 ${n400On50}`);
  assert.ok(n400OnWhite < 3, `n400/white ${n400OnWhite}`);
  assert.equal(n500On50.toFixed(2), "4.52");
  assert.equal(n500OnWhite.toFixed(2), "4.86");
  assert.equal(n400On50.toFixed(2), "2.08");
  assert.equal(n400OnWhite.toFixed(2), "2.24");

  const route = readRel("routes/install/styles-route.css");
  const wizard = readRel("wizard/styles.css");
  assert.match(route, /\.flow-pick\s*\{[^}]*border:\s*1px dashed var\(--gl-color-neutral-500\)/);
  assert.match(
    route,
    /\.gl-button--default-secondary,\s*\n\.gl-button--default-dashed,\s*\n\.btn-secondary\s*\{[^}]*border-color:\s*var\(--gl-color-neutral-500\)/,
  );
  assert.match(wizard, /--gl-border-color-strong:\s*var\(--gl-color-neutral-500\);/);
});

test("emitted styles-route.css later override wins confirm ink; column stays 720", () => {
  const emitted = readRel("dist/site/install/styles-route.css");
  const published = emitted.indexOf(
    ".gl-button--confirm-primary{background:var(--gl-button-confirm-bg);color:var(--gl-action-primary-text)}",
  );
  const override = emitted.indexOf(
    ".gl-button--confirm-primary {\n  color: var(--gl-button-confirm-text);\n}",
  );
  assert.ok(published >= 0, "published confirm-primary color missing");
  assert.ok(override >= 0, "installer confirm-primary override missing");
  assert.ok(override > published, `override ${override} must follow published ${published}`);
  assert.match(
    emitted,
    /width:\s*min\(720px,\s*calc\(100%\s*-\s*2\s*\*\s*var\(--gl-spacing-8\)\)\)/,
  );
  const route = readRel("routes/install/styles-route.css");
  assert.match(
    route,
    /width:\s*min\(720px,\s*calc\(100%\s*-\s*2\s*\*\s*var\(--gl-spacing-8\)\)\)/,
  );
});

test("installer chrome files invent no hex; reset.css pin is comment-only", () => {
  const route = readRel("routes/install/styles-route.css");
  const wizard = readRel("wizard/styles.css");
  assert.equal(HEX.test(route), false, "styles-route.css invented hex");
  assert.equal(HEX.test(wizard), false, "wizard/styles.css invented hex");

  const resetPath = join(ROOT, "design/pajamas/reset.css");
  const resetBytes = readFileSync(resetPath);
  assert.equal(resetBytes.length, 767);
  assert.equal(createHash("sha256").update(resetBytes).digest("hex"), RESET_SHA256);

  const reset = resetBytes.toString("utf8");
  assert.match(reset, /concatenated into dist\/site by scripts\/build-site\.sh/);
  assert.doesNotMatch(reset, /NOT concatenated/);
  const rules = reset.split("*/", 2)[1] ?? "";
  assert.equal(rules, "\n" + RESET_RULES);

  const reconstructed = reset.replace(RESET_NEW_LINE, RESET_OLD_LINE);
  assert.equal(Buffer.byteLength(reconstructed), 770);
  assert.equal(
    createHash("sha256").update(reconstructed, "utf8").digest("hex"),
    RESET_OLD_SHA256,
  );
});

test("D-006 exact; dist/site has no remote design/font refs; LIVE_FLASH_CLAIMED is false", () => {
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
    const html = readRel(rel);
    assert.ok(html.includes(D006), rel);
    assert.equal(REMOTE_REF.test(html), false, rel);
  }
  const css = readRel("dist/site/install/styles-route.css");
  assert.equal(REMOTE_REF.test(css), false, "emitted CSS remote ref");
  assert.match(readRel("src/types.ts"), /export const LIVE_FLASH_CLAIMED = false;/);
});
