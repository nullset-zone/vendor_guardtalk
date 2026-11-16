/**
 * Frontend contract test (F-WEBINSTALLER-REMOVE-PUBKEY-UI):
 *
 * Ensures `routes/` and `wizard/` contain zero user-facing public-key PEM
 * uploads, key-generation, key-import, or user-key enrolment prompts, while
 * keeping internal channel integrity (`avb_pkmd.bin`) and linear WebUSB
 * flows intact.
 */
import test from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { renderStep0, renderStep1, renderStep2 } from "../routes/install/early-steps.js";
import { keepKeyStepHtml, lockStepHtml, verifyStepHtml } from "../routes/install/late-steps.js";
import { renderUpdatePage } from "../routes/update/update-route.js";
import { renderRecoverPage } from "../routes/recover/recover-route.js";
import { renderVerifyDevicePage } from "../routes/verify-device/verify-route.js";
import { initialInstallState } from "../lib/install-state/machine.js";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const ROUTES_DIR = join(ROOT, "routes");
const WIZARD_DIR = join(ROOT, "wizard");

const FORBIDDEN_UI_PATTERNS: readonly RegExp[] = [
  /data-role=["']release-key["']/,
  /data-role=["']user-pem["']/,
  /data-role=["']public-pem["']/,
  /data-action=["']generate-key["']/,
  /data-action=["']import-key["']/,
  /data-action=["']import-public["']/,
  /data-action=["']recover-flash-pkmd["']/,
  /data-action=["']read-enrolled-key["']/,
  /Release public key PEM/i,
  /Public key PEM \(SPKI\)/i,
  /Enrol your new key/i,
  /Make the key in this tab/i,
  /Bring a key file you already keep/i,
  /--key user\.pem/,
];

function collectFrontendFiles(dir: string): string[] {
  const out: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...collectFrontendFiles(full));
    } else if (/\.(ts|mts|mjs|js|html)$/.test(entry.name)) {
      out.push(full);
    }
  }
  return out;
}

test("routes/ and wizard/ contain zero user-facing PEM upload, key-gen, or key-import prompts", () => {
  const files = [...collectFrontendFiles(ROUTES_DIR), ...collectFrontendFiles(WIZARD_DIR)];
  assert.ok(files.length > 0, "expected routes/ and wizard/ files");

  for (const file of files) {
    const text = readFileSync(file, "utf8");
    for (const pattern of FORBIDDEN_UI_PATTERNS) {
      assert.equal(
        pattern.test(text),
        false,
        `${file} must not contain user-facing pubkey/PEM prompt ${pattern}`,
      );
    }
  }
});

test("rendered route HTML contains zero user-facing PEM or key-enrolment inputs", () => {
  const markups = [
    renderStep0(),
    renderStep1({ package: false, sums: false, sig: false }),
    renderStep2({ status: "verified", rows: [], meta: { buildId: "b", targetProduct: "tokay", version: "v" } }),
    lockStepHtml({ sim: false, locked: false }),
    verifyStepHtml({ sim: false, outcome: "pending" }),
    keepKeyStepHtml(false),
    renderUpdatePage({ state: initialInstallState("update"), simMode: false, targetProduct: "tokay" }),
    renderRecoverPage({ ackAcknowledged: true }),
    renderVerifyDevicePage({ simMode: false }),
    readFileSync(join(WIZARD_DIR, "index.html"), "utf8"),
  ];

  for (const html of markups) {
    for (const pattern of FORBIDDEN_UI_PATTERNS) {
      assert.equal(
        pattern.test(html),
        false,
        `rendered HTML must not contain ${pattern}`,
      );
    }
  }
});
