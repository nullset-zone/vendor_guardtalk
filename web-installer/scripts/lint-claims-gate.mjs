#!/usr/bin/env node
/**
 * Claim-lint gate (F-WEBINSTALL-FLASHALL-CLAIM-LINT).
 *
 * Lints every user-visible copy surface for forbidden claims, including the
 * readiness-claim family, and returns ONE exit code:
 *
 *   0  clean
 *   1  at least one forbidden claim
 *   2  usage / configuration error
 *
 * The readiness verdict is resolved the SAME way the linter library does
 * (`lib/claims/readiness-verdict.ts`): an explicit `--readiness-verdict=<path>`
 * file when given (this is how the Backend lane's readiness gate hands its
 * single exit code across the file-ownership boundary), otherwise derived from
 * the shipped facts. An unknown verdict is FAIL — the readiness family stays
 * armed. Nothing here can manufacture a PASS.
 *
 * Usage:
 *   node scripts/lint-claims-gate.mjs                          # lint emitted site + route sources
 *   node scripts/lint-claims-gate.mjs --readiness-verdict=F    # use the gate's verdict file
 *   node scripts/lint-claims-gate.mjs FILE [...]               # lint specific files
 *
 * HONESTY: a linter is a tripwire, not a proof. It cannot prove copy is true;
 * it can only refuse the phrases the programme has ruled out.
 */
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");
const LINTER = join(ROOT, "lib", "claims", "lint-claims.ts");

/** Copy surfaces that must be linted. Missing entries are skipped (a route may
 *  legitimately not ship yet); the emitted site is preferred when present. */
const COPY_TARGETS = [
  "dist/site/index.html",
  "dist/site/install/index.html",
  "dist/site/install/update/index.html",
  "dist/site/install/verify-device/index.html",
  "dist/site/install/recover/index.html",
  "dist/site/threat-model/index.html",
  "routes/install/early-steps.ts",
  "routes/install/late-steps.ts",
  "routes/update/update-route.ts",
  "routes/verify-device/verify-route.ts",
  "routes/recover/recover-route.ts",
  "routes/threat-model/page.html",
  "src/types.ts",
  "status.json",
];

function collectCopyFiles() {
  const explicit = process.argv.slice(2).filter((a) => !a.startsWith("--"));
  if (explicit.length > 0) {
    return explicit;
  }
  const files = [];
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      if (statSync(full).isDirectory()) {
        walk(full);
      } else if (name.endsWith(".html")) {
        files.push(relative(ROOT, full));
      }
    }
  };
  for (const target of COPY_TARGETS) {
    const full = join(ROOT, target);
    if (!existsSync(full)) {
      continue;
    }
    if (statSync(full).isDirectory()) {
      walk(full);
    } else {
      files.push(target);
    }
  }
  return files;
}

const node = process.execPath;
const tsx = join(ROOT, "node_modules", "tsx", "dist", "cli.mjs");
if (!existsSync(tsx)) {
  process.stderr.write("[lint-claims-gate] tsx not found; run npm install\n");
  process.exit(2);
}
if (!existsSync(LINTER)) {
  process.stderr.write(`[lint-claims-gate] linter not found: ${LINTER}\n`);
  process.exit(2);
}

const files = collectCopyFiles();
if (files.length === 0) {
  process.stderr.write("[lint-claims-gate] no copy files found to lint\n");
  process.exit(2);
}

const forwarded = process.argv.slice(2).filter((a) => a.startsWith("--readiness-verdict="));
const result = spawnSync(node, [tsx, LINTER, ...forwarded, ...files], {
  cwd: ROOT,
  stdio: "inherit",
});
if (result.error) {
  process.stderr.write(`[lint-claims-gate] failed to run linter: ${result.error.message}\n`);
  process.exit(2);
}
process.exit(result.status ?? 2);
