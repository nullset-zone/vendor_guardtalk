/**
 * CLI export (Phase 3a) — deterministic offline flash script generator.
 *
 * The browser flow is the reference. This module renders the EXACT same
 * operation sequence as POSIX sh so users who refuse Chromium get a
 * first-class equivalent path (PLAN.md §4 row "CLI export equivalence").
 * Every emitted command is annotated with the browser step it mirrors so
 * equivalence stays auditable line-by-line.
 *
 * Guarantees:
 * - pure: no clock, no randomness, no I/O; same plan ⇒ byte-identical script
 * - offline: the generated script never names curl/wget/http/ssh/scp
 * - honest: a value the project does not have is never invented and never
 *   shipped as a pending-confirmation token. The release provenance values
 *   (Q-04 fingerprint, Q-05 onion address) do not exist in this build, so the
 *   script says so and REQUIRES the user to supply them before anything is
 *   unlocked or written (`lib/ui/unavailable.ts`, D-041)
 */
import {
  ONION_ADDRESS_FACT,
  RELEASE_FINGERPRINT_FACT,
  unavailableFactLines,
} from "../ui/unavailable.js";

/** Key custody flows of browser step 3 (PLAN.md §1). */
export type CliKeyFlow = "bring-your-own" | "sign-elsewhere" | "generate-here";

/** One re-signed vbmeta target: top-level or chained partition. */
export interface VbmetaTarget {
  /** Partition name as passed to fastboot, e.g. "vbmeta", "vbmeta_vendor". */
  readonly partition: string;
  /** Image file name inside the release bundle. */
  readonly imageFile: string;
  readonly topLevel: boolean;
}

export interface CliExportPlan {
  /** Release bundle files with digests from SHA256SUMS (browser step 1). */
  readonly releaseFiles: ReadonlyArray<{ name: string; sha256: string }>;
  /** Target `getvar product` value, e.g. "tokay". */
  readonly targetProduct: string;
  readonly keyFlow: CliKeyFlow;
  /**
   * True only when a generate-here user exported their own key material into a
   * PEM themselves. WebCrypto handles are non-extractable, so signing commands
   * are emitted ONLY on this explicit export — stated plainly, never assumed
   * (PLAN.md §2 key-custody contract).
   */
  readonly selfExportedPem?: boolean;
  /** vbmeta images to re-sign and flash (from lib/avb chain detection). */
  readonly vbmetaTargets: ReadonlyArray<VbmetaTarget>;
  /** Firmware partitions flashed first (bootloader/radio/boot/vendor_boot/dtbo). */
  readonly firmwareImages: ReadonlyArray<{ partition: string; imageFile: string }>;
  /** OS images flashed after enrolment (system/system_ext/product/vendor). */
  readonly osImages: ReadonlyArray<{ partition: string; imageFile: string }>;
}

export interface CliExportStep {
  readonly browserStep: number;
  readonly command: string;
}

const ALGORITHM_FLAG = "--algorithm SHA256_RSA4096";
const PADDING_FLAG = "--padding_size 64";

function shq(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

function orderedVbmetaTargets(plan: CliExportPlan): ReadonlyArray<VbmetaTarget> {
  return [...plan.vbmetaTargets].sort((a, b) => {
    if (a.topLevel !== b.topLevel) {
      return a.topLevel ? -1 : 1;
    }
    return a.partition < b.partition ? -1 : a.partition > b.partition ? 1 : 0;
  });
}

interface Emitter {
  readonly lines: string[];
  step(n: number): void;
  comment(text: string): void;
  cmd(browserStep: number, description: string, command: string): void;
}

function emitter(): Emitter {
  const lines: string[] = [];
  return {
    lines,
    step(n: number): void {
      lines.push(`# step ${n}`);
    },
    comment(text: string): void {
      lines.push(`# ${text}`);
    },
    cmd(browserStep: number, description: string, command: string): void {
      lines.push(`# step ${browserStep} — ${description}`);
      lines.push(command);
    },
  };
}

function headerLines(plan: CliExportPlan): string[] {
  return [
    "#!/bin/sh",
    "# ============================================================================",
    "# GuardTalkOS WebInstaller — CLI export (offline equivalent path)",
    "#",
    "# What this does:",
    "#   Mirrors the /install browser flow command-for-command without a",
    "#   Chromium-based browser: verify the release, sign the vbmeta image(s)",
    "#   with YOUR key via avbtool, enrol your AVB public key, flash firmware",
    "#   then the OS, then lock the bootloader. Same order, same args, same",
    "#   files as the browser steps — every command names the '# step N' it",
    "#   mirrors.",
    "#",
    "# Prerequisites:",
    "#   - fastboot   (Android platform-tools)",
    "#   - avbtool    (AOSP, version matching your release build)",
    "#   - openssl    (release verification and key checks)",
    "#",
    "# Safety warnings — read before running:",
    "#   - 'fastboot flashing unlock' WIPES ALL DATA on the device.",
    "#   - 'fastboot flashing lock' WIPES ALL DATA again.",
    "#   - A wrong vbmeta signature can leave the device unbootable. Verified",
    "#     boot refuses what you did not sign — that is the contract working,",
    "#     but you will need to reflash to recover.",
    "#",
    ...unavailableFactLines(ONION_ADDRESS_FACT).map((line) => `# ${line}`),
    ...unavailableFactLines(RELEASE_FINGERPRINT_FACT).map((line) => `# ${line}`),
    "#",
    `# Target product: ${plan.targetProduct}`,
    "#   Verified against 'fastboot getvar product' BEFORE ANY write; the",
    "#   script aborts on mismatch (mirror of browser step 5's canFlash gate).",
    "# ============================================================================",
    "",
    "set -eu",
    "",
    "abort() {",
    '  printf \'%s\\n\' "ABORT: $*" >&2',
    "  exit 1",
    "}",
    "",
    "# Required tools present:",
    'command -v fastboot >/dev/null 2>&1 || abort "fastboot not found in PATH"',
    'command -v avbtool >/dev/null 2>&1 || abort "avbtool not found in PATH"',
    'command -v openssl >/dev/null 2>&1 || abort "openssl not found in PATH"',
    "",
    "# --- user configuration -----------------------------------------------------",
    "# Directory holding the downloaded bundle (package, SHA256SUMS, .sig).",
    "RELEASE_DIR='.'",
    "# GuardTalk release PUBLIC key PEM for step-2 signature verification. This",
    "# build publishes no fingerprint for it, so name the file YOU obtained with",
    "# the bundle; the run aborts while this is empty or missing.",
    "RELEASE_KEY_PEM=''",
    "# Detached signature of SHA256SUMS from the same release key.",
    "SHA256SUMS_SIG='SHA256SUMS.sig'",
    "# Your own AVB private key (RSA-4096 PEM). It never leaves this machine.",
    "USER_KEY_PEM='user.pem'",
    "# Release provenance. The address is advisory: this script makes NO network",
    "# request. The fingerprint is REQUIRED: it is the value you obtained out of",
    "# band, and nothing is unlocked or written while it is empty.",
    "RELEASE_BUNDLE_SOURCE=''",
    "RELEASE_PROVENANCE_FINGERPRINT=''",
    "",
  ];
}

function verifySection(plan: CliExportPlan, out: Emitter): void {
  out.lines.push(
    "# ============================================================================",
    "# VERIFY — mirrors browser steps 1–2 (get release over Tor, verify release)",
    "# ============================================================================",
    "",
  );
  out.step(1);
  out.comment("you obtained these three files yourself over Tor Browser:");
  out.comment("the package, SHA256SUMS, and SHA256SUMS.sig, placed in $RELEASE_DIR.");
  out.comment("expected bundle contents, identical to what the browser flow checks:");
  for (const f of plan.releaseFiles) {
    out.comment(`${f.name}  sha256 ${f.sha256}`);
  }
  out.cmd(
    1,
    "all three release artifacts must exist before anything else happens",
    '[ -f "$RELEASE_DIR/SHA256SUMS" ] && [ -f "$RELEASE_DIR/$SHA256SUMS_SIG" ] \\',
  );
  out.lines.push('  || abort "release bundle incomplete: package, SHA256SUMS and signature must all be present"');

  out.step(2);
  out.comment("hash check — equivalent of the browser byte-for-byte compare.");
  out.comment("(GNU coreutils sha256sum shown; on macOS use: shasum -a 256 -c SHA256SUMS)");
  out.cmd(
    2,
    "every package digest matches SHA256SUMS",
    '(cd "$RELEASE_DIR" && sha256sum -c SHA256SUMS)',
  );
  out.comment("detached signature check against the GuardTalk release key:");
  out.comment("this build publishes no fingerprint, so the value below is the one YOU");
  out.comment("obtained out of band. Compare it with what this run prints, not with");
  out.comment("anything on this page.");
  out.cmd(
    2,
    "the release public key you obtained with the bundle is named and present",
    '[ -n "$RELEASE_KEY_PEM" ] && [ -f "$RELEASE_KEY_PEM" ] \\',
  );
  out.lines.push(
    '  || abort "RELEASE_KEY_PEM is empty or missing: name the GuardTalk release PUBLIC key PEM you obtained with the bundle — nothing is verified without it"',
  );
  out.cmd(
    2,
    "print the release fingerprint of the key you hold, for your own comparison",
    'openssl pkey -in "$RELEASE_KEY_PEM" -pubout -outform DER | openssl dgst -sha256',
  );
  out.cmd(
    2,
    "SHA256SUMS was signed by the GuardTalk release key",
    'openssl dgst -sha256 -verify "$RELEASE_KEY_PEM" -signature "$SHA256SUMS_SIG" "$RELEASE_DIR/SHA256SUMS"',
  );
  out.lines.push("");
}

function keySection(plan: CliExportPlan, out: Emitter): void {
  out.lines.push(
    "# ============================================================================",
    "# KEY — mirrors browser steps 3–4 (your key, sign the release)",
    "# ============================================================================",
    "",
  );

  if (plan.keyFlow === "bring-your-own") {
    out.step(3);
    out.comment("bring-your-own: structural checks on the PEM you already own.");
    out.comment("These mirror the browser import path (parse + derive fingerprint).");
    out.comment("Nothing is GENERATED here — your key exists; it is only inspected.");
    out.cmd(
      3,
      "key decrypts cleanly (passphrase prompt if encrypted)",
      'openssl pkey -in "$USER_KEY_PEM" -noout >/dev/null 2>&1 || abort "cannot read user.pem (wrong passphrase?)"',
    );
    out.cmd(
      3,
      "key size is RSA-4096 as AVB requires for SHA256_RSA4096",
      '[ "$(openssl rsa -in "$USER_KEY_PEM" -noout -text 2>/dev/null | grep -c \'4096 bit\')" -eq 1 ] \\',
    );
    out.lines.push('  || abort "user.pem is not an RSA-4096 key"');
    out.cmd(
      3,
      "public modulus hash shown — must match what you recorded at import",
      'openssl rsa -in "$USER_KEY_PEM" -noout -modulus | openssl sha256',
    );
  } else if (plan.keyFlow === "sign-elsewhere") {
    out.step(3);
    out.comment("sign-elsewhere: your key was created on another machine and imported");
    out.comment("here read-only for signing. Nothing is generated in this script.");
    out.cmd(
      3,
      "public key extracted in avbtool pkmd form (1032 bytes) — the same bytes the browser derives",
      'avbtool extract_public_key --key "$USER_KEY_PEM" --output avb_pkmd.bin',
    );
  } else {
    // generate-here
    if (plan.selfExportedPem === true) {
      out.step(3);
      out.comment("generate-here WITH self-exported key material: you generated your");
      out.comment("key in the browser and exported the private PEM yourself. This");
      out.comment("script works only because YOU chose to export — WebCrypto handles");
      out.comment("are non-extractable, so no code path can pull the key out. If the");
      out.comment("file is absent, use the bring-your-own or sign-elsewhere variant.");
      out.cmd(
        3,
        "your exported key file is present",
        '[ -f "$USER_KEY_PEM" ] || abort "user.pem not found — export your key from the browser flow first, or use another CLI variant"',
      );
      out.cmd(
        3,
        "key size is RSA-4096 as AVB requires for SHA256_RSA4096",
        '[ "$(openssl rsa -in "$USER_KEY_PEM" -noout -text 2>/dev/null | grep -c \'4096 bit\')" -eq 1 ] \\',
      );
      out.lines.push('  || abort "user.pem is not an RSA-4096 key"');
    } else {
      out.step(3);
      out.comment("generate-here WITHOUT exported key material: NO CLI SIGNING IS");
      out.comment("POSSIBLE and none is faked here. Browser-generated keys are");
      out.comment("non-extractable by design (key-custody contract); this variant");
      out.comment("refuses to substitute someone else's key. Run step 4 in the");
      out.comment("browser, or restart with the bring-your-own/sign-elsewhere variant.");
      out.lines.push('abort "no exported key material available for CLI signing (see comments above)"');
      return;
    }
  }

  out.step(4);
  out.comment("re-sign every planned vbmeta image with YOUR key, replacing the");
  out.comment("GuardTalk release signature on each boot anchor. Chain partitions");
  out.comment("follow the detected descriptor list — top level first:");
  const targets = orderedVbmetaTargets(plan);
  if (targets.length === 0) {
    out.lines.push('abort "vbmeta plan empty — refusing to continue without signed anchors"');
    return;
  }
  for (const t of targets) {
    out.cmd(
      4,
      `${t.imageFile} signed for partition '${t.partition}'${t.topLevel ? "" : " (chained)"}, algorithm SHA256_RSA4096`,
      `avbtool make_vbmeta_image --output ${shq(t.imageFile)} ${ALGORITHM_FLAG} --key "$USER_KEY_PEM" ${PADDING_FLAG}`,
    );
  }
  out.lines.push("");
}

function flashSection(plan: CliExportPlan, out: Emitter): void {
  out.lines.push(
    "# ============================================================================",
    "# FLASH — mirrors browser steps 5–7 (connect device, flash, lock)",
    "# ============================================================================",
    "",
  );

  // --- step 5: connect device, canFlash gate, unlock -------------------------
  out.step(5);
  // Release provenance FIRST: it is the one check this build cannot perform for
  // the user. Nothing is unlocked and nothing is written while it is empty.
  out.comment("release provenance — the check this build cannot do for you:");
  out.comment("no onion address and no fingerprint are published, so the value above");
  out.comment("is the one you took from the release announcement. An empty value");
  out.comment("stops the run here, before the unlock that wipes the device.");
  out.cmd(
    5,
    "release provenance fingerprint was taken from your release announcement",
    '[ -n "$RELEASE_PROVENANCE_FINGERPRINT" ] \\',
  );
  out.lines.push(
    '  || abort "RELEASE_PROVENANCE_FINGERPRINT is empty: this build publishes no fingerprint, so take it from your release announcement — refusing to unlock or write anything"',
  );
  out.comment("product gate — the CLI twin of the browser canFlash check.");
  out.comment("NOTHING is written before this passes; mismatch aborts cold.");
  out.cmd(
    5,
    `plugged device reports product '${plan.targetProduct}'`,
    `fastboot getvar product 2>&1 | grep -qx ${shq(`product: ${plan.targetProduct}`)} || abort "device product mismatch — expected ${plan.targetProduct}; stopping before ANY write"`,
  );
  out.comment("OEM-unlock equivalent. Unlocking WIPES ALL DATA — the browser made");
  out.comment("you acknowledge this twice; here it is in plain text instead.");
  out.cmd(
    5,
    "unlock the bootloader (confirm on-device; the USB link drops mid-wipe — expected)",
    "echo 'unlocking: this WIPES ALL DATA — confirm on-device' && fastboot flashing unlock || true",
  );
  out.cmd(
    5,
    "explicit pause until the wipe finished and you re-entered bootloader mode",
    'printf \'%s\' "When the device is back in bootloader mode, press Enter to continue... " && read -r REPLY',
  );
  out.comment("re-gate after unlock — identity re-checked before the first write.");
  out.cmd(
    5,
    `device STILL reports product '${plan.targetProduct}' after unlock`,
    `fastboot getvar product 2>&1 | grep -qx ${shq(`product: ${plan.targetProduct}`)} || abort "device changed or lost after unlock — re-run from the start"`,
  );
  out.lines.push("");

  // --- step 6: flash, canonical order ----------------------------------------
  out.step(6);
  out.comment("flash order is fixed: avb_custom_key → firmware → OS → your vbmeta(s).");

  out.cmd(
    6,
    "clear any stale AVB enrolment (may warn on an empty slot — harmless)",
    "echo 'next: clearing stale AVB enrolment' && fastboot erase avb_custom_key || true",
  );
  out.cmd(
    6,
    "enrol YOUR public key: verified boot now trusts only your signature",
    "echo 'next: enrolling your AVB public key (avb_pkmd.bin)' && fastboot flash avb_custom_key avb_pkmd.bin",
  );

  for (const img of plan.firmwareImages) {
    out.cmd(
      6,
      `firmware write begins: partition '${img.partition}' from ${img.imageFile}`,
      `echo 'next: firmware ${img.partition}' && fastboot flash ${shq(img.partition)} ${shq(img.imageFile)}`,
    );
  }

  for (const img of plan.osImages) {
    out.cmd(
      6,
      `OS write begins: partition '${img.partition}' from ${img.imageFile}`,
      `echo 'next: OS ${img.partition}' && fastboot flash ${shq(img.partition)} ${shq(img.imageFile)}`,
    );
  }

  for (const t of orderedVbmetaTargets(plan)) {
    out.cmd(
      6,
      `boot anchor written LAST: ${t.partition} carries YOUR signature`,
      `echo 'next: your signed ${t.partition}' && fastboot flash ${shq(t.partition)} ${shq(t.imageFile)}`,
    );
  }
  out.lines.push("");

  // --- step 7: lock -----------------------------------------------------------
  out.step(7);
  out.comment("lock re-arms verified boot against YOUR enrolled key. This wipes data");
  out.comment("AGAIN — the same warning the browser shows before this step.");
  out.cmd(
    7,
    "lock the bootloader (confirm on-device when prompted)",
    "echo 'next: locking — this wipes data AGAIN — confirm on-device' && fastboot flashing lock",
  );
  out.lines.push("");
}

function footerLines(): string[] {
  return [
    "# ============================================================================",
    "# DONE — browser step 8 happens on the device itself: at first boot, TYPE",
    "# BACK the boot-screen key fingerprint and compare it to the one you",
    "# recorded at step 3. Any difference means: do not use this device.",
    "# Browser step 9 is the sentence that matters most:",
    "#   GuardTalk cannot update this phone. Only you can.",
    "# ============================================================================",
  ];
}

function renderLines(plan: CliExportPlan): string[] {
  const out = emitter();
  out.lines.push(...headerLines(plan));
  verifySection(plan, out);
  keySection(plan, out);
  flashSection(plan, out);
  out.lines.push(...footerLines());
  return out.lines;
}

/**
 * Build the equivalence map: every emitted shell command paired with the
 * browser step number it mirrors. Pure. Used by the equivalence test to prove
 * each flash-producing browser step is covered 1:1 by generated commands.
 */
export function cliExportStepMap(plan: CliExportPlan): CliExportStep[] {
  const map: CliExportStep[] = [];
  let currentStep = 0;
  for (const line of renderLines(plan)) {
    const stepMatch = /^# step (\d+)(?: |$)/.exec(line);
    if (stepMatch !== null && stepMatch[1] !== undefined) {
      currentStep = Number(stepMatch[1]);
      continue;
    }
    const trimmed = line.trim();
    if (
      trimmed.length === 0 ||
      trimmed.startsWith("#") ||
      trimmed.startsWith("abort()") ||
      trimmed.startsWith("}") ||
      trimmed.startsWith("|| abort")
    ) {
      continue;
    }
    if (currentStep < 1) {
      continue;
    }
    map.push({ browserStep: currentStep, command: trimmed });
  }
  return map;
}

/**
 * Generate the deterministic offline CLI export script.
 * Pure function: identical plan ⇒ byte-identical script.
 */
export function generateCliExport(plan: CliExportPlan): string {
  return `${renderLines(plan).join("\n")}\n`;
}
