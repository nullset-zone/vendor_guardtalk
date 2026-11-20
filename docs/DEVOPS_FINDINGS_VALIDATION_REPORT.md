# GuardTalkOS — Validation & Correction of DevOps Findings Report (v1.1 → v1.2)

**Date:** 2026-11-20  
**Repository:** `nullset-zone/vendor_guardtalk` (baseline audited: `fe8a69b3e7c96d7174a420dc57bd4d60a5316029`)  
**Supersedes / Corrects:** *GuardTalkOS — documentation findings vs fresh checkout (v1.1, 2026-11-19)*

---

## Executive Summary

Every finding (`GT-01`–`GT-08`) from the v1.1 DevOps report was independently re-verified against both the standalone `nullset-zone/vendor_guardtalk` repository and the full Android `repo` checkout (`nullset-zone/platform_manifest.git`, branch `16-qpr2`).

| ID | DevOps Severity | Validation Verdict | Action Taken |
| :--- | :---: | :--- | :--- |
| **GT-01** | MED-HIGH | **Confirmed** — `status.json` nests `liveFlashClaimed` under `flashCapability` and includes additional posture fields (`noOta: true`, `preLaunch`, `onion`, `keyCustody`, `releaseState`, `routes`, `flashCapability.implemented`). | Updated `web-installer/README.md` §8 to document the exact `status.json` schema. |
| **GT-02** | MED-HIGH | **Refuted (methodology error)** — Retired route redirects **do** exist and are generated at build time by `web-installer/scripts/build-site.sh:54-90` (`emit_wizard_redirect`) into `dist/site/install/{update,verify-device,recover}/index.html` → `../../wizard/` and `dist/site/index.html` → `./wizard/`. DevOps grepped unbuilt source (`routes/`, `src/`, `lib/`) without running `npm run routes:build`. **`/wizard/`** (`web-installer/wizard/`) is the authoritative UI. | Clarified `wizard/` vs. `routes/` + `scripts/build-site.sh` build-time redirect emission in `web-installer/README.md` §8. |
| **GT-03** | LOW | **Partially confirmed (curated scope)** — `channel-freshness.mjs`, `channel-signature.mjs`, and `anchor-mode.mjs` are real operational scripts; internal working logs (`PLAN.md`, `PROGRESS.md`, `QUESTIONS_FOR_HUMAN.md`, `DECISION_LOG.md`) are intentionally omitted from end-user docs. | Added `channel-freshness.mjs`, `channel-signature.mjs`, and `anchor-mode.mjs` to `web-installer/README.md` §8. |
| **GT-04..06** | LOW | **Confirmed present, intentionally curated** — `docs/` (68 `.md` files), `scripts/` (including one-off hardware diagnostics and incident scripts), and `branding/` (bootanimation, bootloader-logo, wallpapers, theme, `guardtalk-theme.mk`, `signing-keys/`) exist on disk. User-facing guides intentionally curate operator workflows rather than dumping internal RCA/debug scripts. | Documented in this report; `README.md` and `BUILD_AND_RUN_FOR_DUMMIES.md` remain intentionally curated for newcomers. |
| **GT-07** | INFO | **Refuted (wrong repository / mixed checkout)** — Neither `AGENTS.md` nor `.aegis/config.json` exists in `nullset-zone/vendor_guardtalk` at `fe8a69b` (`git ls-files \| grep -iE 'AGENTS\|aegis'` returns only `.github/workflows/aegis-commit-approval.yml`). AEGIS governance (24 laws + 11 gates) lives in `neurofabric-ventures/AEGIS-Framework.git`, linked at `.aegis/` at the Android `repo` workspace root — intentionally never duplicated inside `vendor_guardtalk`. | Clarified repository architecture and AEGIS linkage below. |
| **GT-08** | INFO | **Confirmed authoritative (closes G-4)** — `scripts/stamp-tree/gt-ready-devices.sh:145-155` (byte-identical to workspace-root `scripts/gt-ready-devices.sh`) is the authoritative specification for `acks/<dev>.ack`. | Added the authoritative `acks/<dev>.ack` `key=value` format to `docs/BUILD_AND_RUN_FOR_DUMMIES.md`. |

### Additional Polish Applied in the Same Pass (from `A-DOCS-GUARDTALK-DUMMIES-AUDIT`)
- **`F-001` (`docs/BUILD_AND_RUN_FOR_DUMMIES.md`):** Added `REMOTE_BUILD_DIR="$PWD/releases/desktop-flash/tokay-latest"` to the `GT_FLASH_QUARANTINE_CHECK_ONLY=1` example so it runs cleanly verbatim (exit `0`).
- **`F-002` (`web-installer/README.md`):** Added an explicit footnote on `stallion` clarifying that `wizard/devices.ts` displays `Pixel 9a` while `stallion.mk` / `BUILD_AND_RUN_FOR_DUMMIES.md` identify `stallion` as **Pixel 10a**.
- **`F-003` (`web-installer/README.md`):** Corrected `userdebug/test-keys` to `user/test-keys` (matching live `vbmeta.img` across `*-cur-user` builds; production fleet remains `NO-GO` due to public AOSP `testkey`).
- **`F-004` (`docs/BUILD_AND_RUN_FOR_DUMMIES.md`):** Replaced hardcoded lab IP with `<user>@<build-host>` placeholder and clarified that `REMOTE_RESCUE_DIR` must be an absolute path on `REMOTE_HOST`.

---

## Detailed Corrections to v1.1 Findings

### 1. Why GT-02 ("Retired routes contradicted") Was a False Alarm
In v1.1, DevOps searched `routes/`, `src/`, and `lib/` for `"wizard"` in a fresh clone without building the site and concluded that no redirect to `/wizard/` exists.

**Actual behavior verified on disk (`web-installer/scripts/build-site.sh:54-90`):**
- **`/wizard/`** (sourced from top-level `web-installer/wizard/`, built by `npm run wizard:build`) is the **only active WebUSB installer UI**. There is intentionally no `routes/wizard/` directory.
- When `npm run routes:build` runs `scripts/build-site.sh`, `emit_wizard_redirect()` overwrites the legacy route HTML entrypoints with CSP-hardened redirect pages:
  - `dist/site/index.html` → `./wizard/`
  - `dist/site/install/update/index.html` → `../../wizard/`
  - `dist/site/install/verify-device/index.html` → `../../wizard/`
  - `dist/site/install/recover/index.html` → `../../wizard/`
- Each emitted page includes both `<meta http-equiv="refresh" content="0; url=../../wizard/" />` and `<script src="../redirect.js" defer></script>` (`window.location.replace("../../wizard/")`).
- Legacy `routes/{update,recover,verify-device}/*.ts` modules are retained in source and copied as compiled JS solely so automated placeholder-retirement tests over `dist/site/` continue to verify that no legacy `type="file"` pickers or Tor placeholders leak into the published site.

### 2. Why GT-07 ("`AGENTS.md:80-95` & `.aegis/config.json`") Was Misattributed
Running `git ls-files | grep -iE 'AGENTS|aegis'` in `nullset-zone/vendor_guardtalk` @ `fe8a69b` returns only:
```text
.github/workflows/aegis-commit-approval.yml
```
Neither `AGENTS.md` nor `.aegis/config.json` exists in `vendor_guardtalk`. The v1.1 finding appears to have inspected a different checkout (or an older local workspace).

**Authoritative governance layout:**
- `vendor_guardtalk` is an Android vendor overlay mounted at `vendor/guardtalk/` inside the GrapheneOS `repo` workspace (`nullset-zone/platform_manifest.git`, branch `16-qpr2`).
- AEGIS governance lives in a separate repository (`git@github.com:neurofabric-ventures/AEGIS-Framework.git`), linked via relative symlink `.aegis -> ../aegis-global` at the `repo` workspace root, providing **24 laws** (`.aegis/governance/laws/*.yaml`) and **11 gates** (`.aegis/governance/gates/*.yaml`). Governance doctrine is intentionally never duplicated inside `vendor_guardtalk`.

### 3. Confirmed Authoritative `acks/<dev>.ack` Schema (GT-08 / G-4)
Verified in `scripts/stamp-tree/gt-ready-devices.sh:145-155` (byte-identical to workspace-root `scripts/gt-ready-devices.sh`):
- **Path:** `<ACK_DIR>/<codename>.ack` (default `releases/desktop-flash/acks/<codename>.ack`; override via `GT_READY_ACK_DIR`).
- **Format:** Strict `key=value` lines.
- **Required keys:** `ack_version=1`, `type=operator-ack`, `ruling_id`, `operator`, `device`, `stamp`, `sha256sums_sha256`, `residual`.
- **Optional key:** `acknowledged_at`.
- **Enforcement:** Fail-closed on any mismatch (device remains `HOLD`; an ack never rescues `PENDING` or `BUILD-OK` and never fabricates boot evidence).

---

## How to Reproduce & Verify Accurately Next Time

Most discrepancies in v1.1 came from grepping an unbuilt standalone shallow clone of `vendor_guardtalk` instead of running the build/verification pipeline or checking out the full Android `repo` workspace. Use the exact steps below to reproduce and validate cleanly.

### A. Standalone `vendor_guardtalk` Verification (WebInstaller, Redirects, Host Unit Tests)

```bash
git clone --depth 1 https://github.com/nullset-zone/vendor_guardtalk.git
cd vendor_guardtalk

# 1. Verify exact commit and confirm no stale AGENTS.md / .aegis files exist in this repo
git rev-parse HEAD
git ls-files | grep -iE 'AGENTS|aegis'

# 2. Verify authoritative ack format
bash scripts/stamp-tree/gt-ready-devices.sh --help

# 3. Run Python stdlib host contract tests (no pytest at root)
python3 -m unittest discover -s checkin/host -p 'test_*.py' -v

# 4. Build WebInstaller (/wizard/ + dist/site/ redirects) and verify redirects on built output
cd web-installer
npm ci                     # requires Node.js >= 20
npm run wizard:build
npm run routes:build

# Inspect the redirect generator and emitted HTML
sed -n '54,90p' scripts/build-site.sh
head -n 15 dist/site/index.html \
           dist/site/install/update/index.html \
           dist/site/install/verify-device/index.html \
           dist/site/install/recover/index.html

# 5. Run WebInstaller claim-honesty linter and full test suite
npm run claims:lint
npm test
```

### B. Full GuardTalkOS Workspace Verification (OS Build, Root `scripts/`, QA Suite, AEGIS Governance)

`vendor_guardtalk` is designed to be mounted at `vendor/guardtalk/` inside the GrapheneOS `repo` checkout:

```bash
# 1. Initialize and sync the full GuardTalkOS Android manifest (112 nullset-zone repos + 2 gitlab + 920 AOSP)
mkdir -p GuardTalkOS && cd GuardTalkOS
repo init -u https://github.com/nullset-zone/platform_manifest.git -b 16-qpr2
repo sync -j8

# 2. Link AEGIS governance (separate repo — never duplicated inside vendor_guardtalk)
git clone git@github.com:neurofabric-ventures/AEGIS-Framework.git ../aegis-global
ln -s ../aegis-global .aegis
ls .aegis/governance/laws/  | wc -l   # expects 24
ls .aegis/governance/gates/ | wc -l   # expects 11

# 3. Run root-level host verification gates
bash vendor/guardtalk/checkin/host/verify_host.sh
vendor/guardtalk/scripts/verify-bt-vintf-excision.sh
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v

# 4. Run WebInstaller readiness gate (when releases/desktop-flash/ bundles are staged)
(cd vendor/guardtalk/web-installer && node scripts/readiness-gate.mjs)
```

---

## Honesty Disclosure

- **`LIVE_FLASH_CLAIMED=false`** · **`BOOT_VERIFIED=false`**
- WebInstaller dev/unlocked WebUSB UAT: **GO** (14/14 packed targets on build host).
- Production locked-bootloader fleet: **NO-GO** (pending offline operator production signing keys replacing AOSP `testkey`, signed channel roots via `--require-signed-root`, and human-executed hardware live-flash & boot verification).
