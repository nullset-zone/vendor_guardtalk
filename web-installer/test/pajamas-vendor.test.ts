/**
 * Independent vendor-tree / fail-closed / no-remote-ref checks
 * (Q-WEBINSTALL-PAJAMAS-VENDOR). Does not restyle product pages.
 * Does not move the vendor tree (that probe is a sequential QA shell step).
 */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { INSTALLER_CSP } from "../lib/claims/csp.js";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const PAJAMAS = join(ROOT, "design", "pajamas");
const D006 =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'";
const REMOTE_REF =
  /url\(\s*https?:|@import\s+url\(\s*https?:|design\.guardtalk\.io|fonts\.googleapis/i;

const SOURCE_HASHES: Record<string, { bytes: number; sha256: string }> = {
  "compiled/index-BFboFyqJ.css": {
    bytes: 150350,
    sha256: "6628d695ba3eb77f4113ccc2b5d9db64b8b13039effe0662a609ce60f16d6a46",
  },
  "components.css": {
    bytes: 133075,
    sha256: "cc6634cb0df3b788b97b378e5b4881bd2cbe6352416202954561fae56e4288e3",
  },
  "reset.css": {
    bytes: 767,
    sha256: "baa208696f550d219495495c6e89e7d48386569916e8dea4d2e4fbe9087b071b",
  },
  "templates/CATALOG.json": {
    bytes: 3904,
    sha256: "ef9412eb279e285eb9ab48d4a3ed9c64a43d439290656d6a72fc370abeaa4146",
  },
  "templates/CATALOG.txt": {
    bytes: 2650,
    sha256: "08978f524bd8b7f4b8638fbcc1174af4d577a0e4949d604f0ec9136825120f65",
  },
  "templates.css": {
    bytes: 13843,
    sha256: "99d463b0fc63a85bfd4af47321bc5b2698a83ebf6582eb6983e9d31e81194d67",
  },
  "tokens.css": {
    bytes: 5521,
    sha256: "01d2c7c66184ffef36a0ccfe05d6d1c1c4405bf3d1a9d97b89c0a2a19c7566f4",
  },
  "tokens.json": {
    bytes: 5573,
    sha256: "90664fe417af2cd5983531218528c5f025b9462c07d8f91ad94789cea4a65cb1",
  },
};

function sha256File(path: string): string {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function uniqueGlTokens(css: string): string[] {
  const found = css.match(/--gl-[A-Za-z0-9-]+/g) ?? [];
  return [...new Set(found)].sort();
}

test("SOURCE.txt records 2026-08-23 URLs, hashes, and the vendored file list", () => {
  const source = readFileSync(join(PAJAMAS, "SOURCE.txt"), "utf8");
  assert.match(source, /Fetch date: 2026-08-23/);
  assert.match(source, /https:\/\/design\.guardtalk\.io\/pajamas\//);
  assert.match(source, /https:\/\/design\.guardtalk\.io\/pajamas\/#\/templates\//);
  assert.match(source, /https:\/\/design\.guardtalk\.io\/pajamas\/assets\/index-BFboFyqJ\.css/);
  for (const [rel, meta] of Object.entries(SOURCE_HASHES)) {
    assert.ok(source.includes(meta.sha256), `SOURCE.txt missing sha256 for ${rel}`);
    assert.ok(source.includes(`${rel}  ${meta.bytes}  sha256:`), `SOURCE.txt missing size line for ${rel}`);
  }
});

test("recomputed sha256 of compiled CSS + extracted CSS + catalog matches SOURCE.txt", () => {
  for (const [rel, meta] of Object.entries(SOURCE_HASHES)) {
    const path = join(PAJAMAS, rel);
    assert.equal(statSync(path).size, meta.bytes, `${rel} byte size`);
    assert.equal(sha256File(path), meta.sha256, `${rel} sha256`);
  }
});

test("tokens.css has 114 unique --gl-* custom properties", () => {
  const css = readFileSync(join(PAJAMAS, "tokens.css"), "utf8");
  const tokens = uniqueGlTokens(css);
  assert.equal(tokens.length, 114);
  assert.ok(tokens.includes("--gl-color-brand"));
  assert.ok(tokens.every((name) => name.startsWith("--gl-")));
});

test("extracted and compiled CSS have no remote url / @import / design-site / webfont refs", () => {
  const files = [
    "tokens.css",
    "templates.css",
    "components.css",
    "reset.css",
    "compiled/index-BFboFyqJ.css",
  ];
  for (const rel of files) {
    const text = readFileSync(join(PAJAMAS, rel), "utf8");
    assert.equal(REMOTE_REF.test(text), false, rel);
    assert.equal(text.includes("url(http"), false, `${rel} url(http`);
    assert.equal(text.includes("@import url(http"), false, `${rel} @import url(http`);
  }
});

test("build-site.sh fail-closes on a missing tree, empty files, or missing --gl-* tokens", () => {
  const script = readFileSync(join(ROOT, "scripts", "build-site.sh"), "utf8");
  assert.match(script, /missing Pajamas vendor tree/);
  assert.match(script, /missing or empty Pajamas vendor file/);
  assert.match(script, /has no --gl-\* tokens/);
  assert.ok(script.includes('if [[ ! -d "$PAJAMAS" ]]; then'));
  assert.ok(script.includes("exit 1"));
  assert.ok(script.includes("design\\.guardtalk\\.io|@import url\\(http|fonts\\.googleapis"));
  assert.match(script, /\$VENDOR_TOKENS/);
  assert.match(script, /\$VENDOR_RESET/);
  assert.match(script, /\$VENDOR_TEMPLATES/);
  assert.match(script, /\$VENDOR_COMPONENTS/);
  assert.equal(script.includes("compiled/index-BFboFyqJ.css"), false);
  assert.ok(script.includes("reset.css"));
});

test("vendor tree required files exist and no extra top-level CSS slipped in", () => {
  const names = readdirSync(PAJAMAS);
  assert.ok(names.includes("SOURCE.txt"));
  assert.ok(names.includes("tokens.css"));
  assert.ok(names.includes("templates.css"));
  assert.ok(names.includes("components.css"));
  assert.ok(names.includes("compiled"));
  const extraCss = names.filter(
    (name) => name.endsWith(".css") && !["tokens.css", "templates.css", "components.css", "reset.css"].includes(name),
  );
  assert.deepEqual(extraCss, []);
});

test("D-006 CSP string is exact in the claim constant, build script, and route shells", () => {
  assert.equal(INSTALLER_CSP, D006);
  const script = readFileSync(join(ROOT, "scripts", "build-site.sh"), "utf8");
  assert.ok(script.includes(D006), "build-site.sh CSP");
  const pages = [
    "routes/install/page.html",
    "routes/update/page.html",
    "routes/verify-device/page.html",
    "routes/recover/page.html",
    "routes/threat-model/page.html",
  ];
  for (const rel of pages) {
    const html = readFileSync(join(ROOT, rel), "utf8");
    assert.ok(html.includes(D006), rel);
  }
});

test("LIVE_FLASH_CLAIMED stays false (no live-flash PASS from vendor work)", () => {
  const types = readFileSync(join(ROOT, "src", "types.ts"), "utf8");
  assert.match(types, /export const LIVE_FLASH_CLAIMED = false;/);
});

test("extracted build-site.sh fail-closed block exits 1 when the vendor tree is missing", () => {
  const script = readFileSync(join(ROOT, "scripts", "build-site.sh"), "utf8");
  const start = script.indexOf('if [[ ! -d "$PAJAMAS" ]]; then');
  const end = script.indexOf("cat \\");
  assert.ok(start >= 0 && end > start, "fail-closed block markers");
  const block = script.slice(start, end);
  const result = spawnSync(
    "bash",
    [
      "-c",
      [
        "set -euo pipefail",
        `ROOT=${JSON.stringify(ROOT)}`,
        'PAJAMAS="$ROOT/design/pajamas-ABSENT-Q-WEBINSTALL"',
        'VENDOR_TOKENS="$PAJAMAS/tokens.css"',
        'VENDOR_RESET="$PAJAMAS/reset.css"',
        'VENDOR_TEMPLATES="$PAJAMAS/templates.css"',
        'VENDOR_COMPONENTS="$PAJAMAS/components.css"',
        block,
        "echo SHOULD_NOT_REACH",
      ].join("\n"),
    ],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 1);
  assert.match(result.stderr, /missing Pajamas vendor tree/);
  assert.equal(result.stdout.includes("SHOULD_NOT_REACH"), false);
});
