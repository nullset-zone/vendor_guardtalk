import assert from "node:assert/strict";
import { test } from "node:test";
import {
  cliExportStepMap,
  generateCliExport,
  type CliExportPlan,
} from "../lib/cli-export/generator.js";

function basePlan(): CliExportPlan {
  return {
    releaseFiles: [
      { name: "tokay-factory.zip", sha256: "aa11".repeat(16) },
      { name: "SHA256SUMS", sha256: "bb22".repeat(16) },
      { name: "SHA256SUMS.sig", sha256: "cc33".repeat(16) },
    ],
    targetProduct: "tokay",
    keyFlow: "bring-your-own",
    vbmetaTargets: [
      { partition: "vbmeta", imageFile: "vbmeta.img", topLevel: true },
    ],
    firmwareImages: [
      { partition: "bootloader", imageFile: "bootloader.img" },
      { partition: "radio", imageFile: "radio.img" },
      { partition: "boot", imageFile: "boot.img" },
      { partition: "vendor_boot", imageFile: "vendor_boot.img" },
      { partition: "dtbo", imageFile: "dtbo.img" },
    ],
    osImages: [
      { partition: "system", imageFile: "system.img" },
      { partition: "system_ext", imageFile: "system_ext.img" },
      { partition: "product", imageFile: "product.img" },
      { partition: "vendor", imageFile: "vendor.img" },
    ],
  };
}

function chainPlan(): CliExportPlan {
  return {
    ...basePlan(),
    keyFlow: "sign-elsewhere",
    vbmetaTargets: [
      { partition: "vbmeta", imageFile: "vbmeta.img", topLevel: true },
      { partition: "vbmeta_vendor", imageFile: "vbmeta_vendor.img", topLevel: false },
    ],
  };
}

function generateHereSelfExportPlan(): CliExportPlan {
  return { ...basePlan(), keyFlow: "generate-here", selfExportedPem: true };
}

function generateHereNoExportPlan(): CliExportPlan {
  const p: CliExportPlan = { ...basePlan(), keyFlow: "generate-here" };
  return p;
}

const ALL_PLANS: ReadonlyArray<CliExportPlan> = [
  basePlan(),
  chainPlan(),
  generateHereSelfExportPlan(),
];

/** Lines of the script that would execute (comments and blanks removed). */
function executableLines(script: string): string[] {
  return script
    .split("\n")
    .filter((l) => l.trim().length > 0 && !l.trim().startsWith("#"));
}

/** First executable line matching re, with its 0-based line index in the full script. */
function findExecutable(script: string, re: RegExp): { index: number; line: string } {
  const lines = script.split("\n");
  for (const [i, line] of lines.entries()) {
    const trimmed = line.trim();
    if (trimmed.length === 0 || trimmed.startsWith("#")) continue;
    if (re.test(trimmed)) return { index: i, line: trimmed };
  }
  throw new Error(`no executable line matches ${String(re)}`);
}

test("determinism: two generations are byte-identical across every flow variant", () => {
  for (const plan of ALL_PLANS.concat(generateHereNoExportPlan())) {
    assert.equal(generateCliExport(plan), generateCliExport(plan));
  }
});

test("order: avb_custom_key precedes firmware precedes OS precedes vbmeta precedes lock", () => {
  const script = generateCliExport(basePlan());
  const enrol = findExecutable(script, /fastboot flash avb_custom_key /).index;
  const firmware = findExecutable(script, /fastboot flash 'bootloader' /).index;
  const os = findExecutable(script, /fastboot flash 'system' /).index;
  const vbmeta = findExecutable(script, /fastboot flash 'vbmeta' /).index;
  const lock = findExecutable(script, /fastboot flashing lock$/).index;
  assert.ok(enrol < firmware, "avb_custom_key must precede firmware");
  assert.ok(firmware < os, "firmware must precede OS images");
  assert.ok(os < vbmeta, "OS images must precede user-signed vbmeta");
  assert.ok(vbmeta < lock, "user-signed vbmeta must precede flashing lock");
});

test("gate: exact product grep appears before ANY fastboot write or state change", () => {
  const script = generateCliExport(basePlan());
  const gate = findExecutable(
    script,
    /grep -qx 'product: tokay'/,
  );
  assert.ok(gate.index >= 0, "exact-match product gate missing");
  assert.match(gate.line, /getvar product/);
  const firstDeviceOp = findExecutable(
    script,
    /(^|&& )(fastboot (flash|erase|flashing)|fastboot getvar product )/,
  );
  assert.equal(firstDeviceOp.line, gate.line, "first device-touching command must be the gate itself");
  // Every subsequent device op sits after the gate.
  const lines = script.split("\n");
  for (const [i, line] of lines.entries()) {
    const trimmed = line.trim();
    if (!/^(fastboot |.*&& fastboot )/.test(trimmed)) continue;
    if (/getvar product/.test(trimmed)) continue;
    assert.ok(i > gate.index, `device operation before product gate, line ${i + 1}: ${trimmed}`);
  }
  // Re-gate exists after unlock too.
  assert.match(script, /device STILL reports product/, "no post-unlock re-gate");
});

test("equivalence map: steps 5,6,7 covered; numbering non-decreasing and within browser range", () => {
  for (const plan of ALL_PLANS) {
    const map = cliExportStepMap(plan);
    const counts = new Map<number, number>();
    for (const entry of map) {
      counts.set(entry.browserStep, (counts.get(entry.browserStep) ?? 0) + 1);
    }
    for (const s of [5, 6, 7]) {
      assert.ok((counts.get(s) ?? 0) >= 1, `browser step ${s} has no mapped CLI command`);
    }
    let prev = -Infinity;
    for (const entry of map) {
      assert.ok(
        entry.browserStep >= prev,
        `step numbers must not regress; got ${entry.browserStep} after ${prev}`,
      );
      prev = entry.browserStep;
    }
    for (const entry of map) {
      assert.ok(
        entry.browserStep >= 1 && entry.browserStep <= 9,
        `mapped step ${entry.browserStep} outside browser flow 1..9`,
      );
    }
  }
});

test("equivalence: mapped flash commands mirror the plan 1:1 (same partitions, same order)", () => {
  const plan = basePlan();
  const flashed = cliExportStepMap(plan)
    .map((m) => /fastboot flash (\S+) (\S+)/.exec(m.command))
    .filter((m): m is RegExpExecArray => m !== null)
    .map((m) => (m[1] ?? "").replace(/'/g, ""));
  assert.deepEqual(flashed, [
    "avb_custom_key",
    ...plan.firmwareImages.map((f) => f.partition),
    ...plan.osImages.map((f) => f.partition),
    ...plan.vbmetaTargets.map((v) => v.partition),
  ]);
});

test("offline guarantee: zero curl/wget/http anywhere in the script", () => {
  for (const plan of ALL_PLANS) {
    const script = generateCliExport(plan);
    assert.doesNotMatch(script, /(curl|wget|http)/i);
    // No network-capable tool on any executable line either.
    for (const line of executableLines(script)) {
      assert.doesNotMatch(line, /\b(curl|wget|ssh|scp|rsync|nc|netcat|ftp|telnet)\b/i);
    }
  }
  for (const entry of cliExportStepMap(chainPlan())) {
    assert.doesNotMatch(entry.command, /(curl|wget|http)/i);
  }
});

test("placeholders: '// confirm' present for onion address + release fingerprint; nothing invented", () => {
  for (const plan of ALL_PLANS) {
    const script = generateCliExport(plan);
    assert.ok(script.includes("// confirm onion address"), "onion address placeholder missing");
    assert.ok(
      script.includes("// confirm release-key fingerprint"),
      "release-key fingerprint placeholder missing",
    );
    assert.match(script, /Q-05/, "onion placeholder should cite its question id");
    assert.match(script, /Q-04/, "fingerprint placeholder should cite its question id");
    assert.doesNotMatch(script, /\.onion/i, "an onion host value was invented");
    // The ONLY long hex literals allowed are exactly the planned release digests.
    const hexes = [...(script.match(/[A-Fa-f0-9]{64}/g) ?? [])].sort();
    assert.deepEqual(
      hexes,
      [...plan.releaseFiles.map((f) => f.sha256.toLowerCase())].sort(),
      "unexpected invented hex value in script",
    );
    // Release key path is itself a confirm placeholder, not an invented path.
    assert.match(script, /RELEASE_KEY_PEM='\/\/ confirm /);
  }
});

test("shell-lint self-checks: 'set -eu' in header; balanced quotes; sane line widths", () => {
  for (const plan of ALL_PLANS) {
    const script = generateCliExport(plan);
    const lines = script.split("\n");
    const setIdx = lines.findIndex((l) => l.trim() === "set -eu");
    assert.ok(setIdx > 0 && setIdx < 45, "'set -eu' must appear early in the header");

    for (const [i, line] of lines.entries()) {
      if (line.startsWith("#")) continue;
      let doubleQuotes = 0;
      let singleQuotes = 0;
      let inSingle = false;
      for (let c = 0; c < line.length; c++) {
        const ch = line.charAt(c);
        if (ch === "'") {
          singleQuotes += 1;
          inSingle = !inSingle;
          continue;
        }
        if (inSingle) continue;
        if (ch === '"') doubleQuotes += 1;
      }
      assert.equal(doubleQuotes % 2, 0, `unbalanced double quotes, line ${i + 1}: ${line}`);
      assert.equal(singleQuotes % 2, 0, `unbalanced single quotes, line ${i + 1}: ${line}`);
      assert.ok(line.length <= 200, `line ${i + 1} too long (${line.length} chars)`);
    }
  }
});

test("sign-elsewhere emits extract_public_key + exact make_vbmeta_image flags per detected chain", () => {
  const plan = chainPlan();
  const script = generateCliExport(plan);
  assert.match(
    script,
    /avbtool extract_public_key --key "\$USER_KEY_PEM" --output avb_pkmd\.bin/,
  );
  const signCalls = script.match(/avbtool make_vbmeta_image[^\n]*/g) ?? [];
  assert.equal(signCalls.length, plan.vbmetaTargets.length);
  for (const call of signCalls) {
    assert.match(call, /--algorithm SHA256_RSA4096/);
    assert.match(call, /--padding_size 64/);
    assert.match(call, /--key "\$USER_KEY_PEM"/);
  }
  const top = script.indexOf("make_vbmeta_image --output 'vbmeta.img'");
  const chained = script.indexOf("make_vbmeta_image --output 'vbmeta_vendor.img'");
  assert.ok(top >= 0 && chained > top, "top-level vbmeta must be signed before chains");
});

test("generate-here WITH self-export still emits avbtool sign commands (documented honestly)", () => {
  const script = generateCliExport(generateHereSelfExportPlan());
  const signCalls = script.match(/avbtool make_vbmeta_image[^\n]*/g) ?? [];
  assert.ok(signCalls.length >= 1, "self-exported key must still produce avbtool sign commands");
  for (const call of signCalls) {
    assert.match(call, /--algorithm SHA256_RSA4096/);
    assert.match(call, /--padding_size 64/);
  }
  assert.match(script, /non-extractable/, "honest export note must accompany the commands");
});

test("generate-here WITHOUT self-export emits NO signing commands and aborts honestly", () => {
  const script = generateCliExport(generateHereNoExportPlan());
  assert.doesNotMatch(script, /avbtool make_vbmeta_image/);
  assert.doesNotMatch(script, /avbtool extract_public_key/);
  assert.match(script, /abort "no exported key material available for CLI signing/);
  assert.match(script, /non-extractable/);
});

test("bring-your-own emits openssl checks but NO key generation of any kind", () => {
  const script = generateCliExport(basePlan());
  assert.match(script, /openssl pkey -in "\$USER_KEY_PEM"/);
  assert.match(script, /openssl rsa -in "\$USER_KEY_PEM"/);
  assert.doesNotMatch(script, /genrsa/);
  assert.doesNotMatch(script, /genpkey/);
  assert.doesNotMatch(script, /req -new/);
});

test("every fastboot write is announced by an echo naming what happens next", () => {
  for (const plan of ALL_PLANS) {
    const lines = generateCliExport(plan).split("\n");
    for (const [i, line] of lines.entries()) {
      const trimmed = line.trim();
      const isWrite =
        /^fastboot (flash|erase|flashing)/.test(trimmed) ||
        /&& fastboot (flash|erase|flashing)/.test(trimmed);
      if (!isWrite) continue;
      const prev = (lines[i - 1] ?? "").trim();
      const announced =
        /^echo '/.test(prev) ||
        line.includes("echo '") ||
        line.includes("printf '%s'");
      assert.ok(announced, `unannounced device operation, line ${i + 1}: ${trimmed}`);
    }
  }
});

test("unlock and lock each carry explicit data-wipe confirmation wording", () => {
  const script = generateCliExport(basePlan());
  const unlock = findExecutable(script, /fastboot flashing unlock/);
  const lock = findExecutable(script, /fastboot flashing lock$/);
  assert.ok(lock.index > unlock.index, "lock must come after unlock");
  assert.match(unlock.line, /WIPES ALL DATA/);
  assert.match(lock.line, /wipes data AGAIN/);
});

test("step-map commands each carry their own '# step N' annotation in the script", () => {
  const plan = basePlan();
  const script = generateCliExport(plan);
  for (const entry of cliExportStepMap(plan)) {
    const escaped = entry.command.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const annotated = new RegExp(`^# step ${entry.browserStep} .*\\n${escaped}$`, "m");
    assert.match(
      script,
      annotated,
      `map command lacks its own '# step ${entry.browserStep}' annotation: ${entry.command}`,
    );
  }
});
