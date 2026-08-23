# QA Evidence — Q-BRAND-SWEEP

**Task:** `Q-BRAND-SWEEP` (Residual GrapheneOS inventory + GuardTalkOS boot/brand verification)  
**Date:** 2026-07-25  
**Agent:** QA_ENGINEER  
**Depends:** `T-BRAND-SWEEP` ✅ APPROVED; `F-BRAND-UI` ✅ APPROVED (CONDITIONAL Gate5 88% — assets/build verified here)  
**Verdict:** **GO** (static + artifact inspection) — device boot smoke **HOLD** (adb empty)  
**Queue status:** **REVIEW** (never APPROVED by QA)

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Inventory residual GrapheneOS; classify kept vs FAIL | PASS | Residual table below; VALUE FAIL=0 |
| 2 | Bootanimation GuardTalk-branded + theme wire via PRODUCT_DEVICE | PASS | md5 match; frame visual; feature-excised + wrappers |
| 3 | About summary/logo, launcher overlay icons, SUW `grapheneos_icon` deleted | PASS | Settings/overlay/MyDeviceInfo/Launcher/SUW checks |
| 4 | VALUE-side GrapheneOS in overlay/SUW strings = 0 | PASS | rg + strict body scan |
| 5 | Evidence under `vendor/guardtalk/docs/qa/` | PASS | This file + script + bootframe artifacts |
| 6 | Device boot smoke | **HOLD** | `adb devices` empty |

## Static script

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_brand_sweep_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=19 HOLD_COUNT=1 FAIL=0 EXIT=0
```

**Counts:** **19 / 19** PASS (0 FAIL), HOLD=1 (adb), EXIT=0.  
Script: `vendor/guardtalk/docs/qa/verify_brand_sweep_static.sh` (executable).

### Mandatory verification commands (re-run)

```text
rg -n '>GrapheneOS<|>grapheneos<' vendor/guardtalk/overlays packages/apps/SetupWizard2/res --glob '**/strings*.xml' || true
→ (no matches)

test -f vendor/guardtalk/branding/bootanimation/bootanimation.zip → OK
md5sum …/bootanimation.zip → 7ba676c5704c6e6ab962fb34cc6590ef

rg PRODUCT_DEVICE|bootanimation.zip|guardtalk-theme
→ feature-excised.mk: device/$(PRODUCT_DEVICE)/guardtalk-theme.mk + branding fallback
→ guardtalk-theme.mk: PRODUCT_COPY_FILES → product/media/bootanimation.zip

test ! -f packages/apps/SetupWizard2/res/drawable/grapheneos_icon.xml → OK (deleted)
```

## Boot asset + theme wire

| Check | Result |
|-------|--------|
| Source zip present (3,172,137 bytes) | PASS |
| md5 `7ba676c5704c6e6ab962fb34cc6590ef` | PASS |
| Frame visual (part0/041 + part1 frames) | PASS — GuardTalk chevron + “guardtalk” wordmark; no GrapheneOS |
| `out/tokay/.../product/media/bootanimation.zip` md5 | PASS (match) |
| `out/akita/.../product/media/bootanimation.zip` md5 | PASS (match) |
| Theme include `$(PRODUCT_DEVICE)` not tokay-hardcoded | PASS |
| tokay + akita thin wrappers → `branding/guardtalk-theme.mk` | PASS |
| Dark zip late filter in theme.mk | PASS |

Artifacts: `vendor/guardtalk/docs/qa/_artifacts/Q-BRAND-SWEEP_bootframe*.png`

## F-BRAND-UI asset claims (Architect CONDITIONAL)

| Claim | QA result |
|-------|-----------|
| `about_settings_summary` → GuardTalkOS | PASS (Settings values + overlay) |
| `ic_guardtalk_logo` in Settings + overlay | PASS |
| `MyDeviceInfoFragment.initHeader` → `R.drawable.ic_guardtalk_logo` | PASS |
| `GuardTalkLauncherOverlay` `ic_launcher_home` | PASS |
| SUW `grapheneos_icon.xml` deleted | PASS |
| Bootanimation theme.mk untouched / md5 stable | PASS |

## Residual table (approved / justified)

| Residual | Class | Verdict | Justification |
|----------|-------|---------|---------------|
| Package ids `app.grapheneos.*` (Camera, PDF, SUW targetPackage, etc.) | ID | **KEEP** | Runtime package rename forbidden |
| Resource *names* `*_grapheneos*` (12 string names; values GuardTalkOS) | R.java | **KEEP** | Immutable symbol contracts |
| Kernel path `…/grapheneos` under device kernels | Path | **KEEP** | Real FS path; not UI |
| Bootloader ABL splash (Pixel/Google stock) | Gap | **KEEP** | No BoardConfig hook; documented in `branding/bootloader-logo/` |
| Docs/README/RUNBOOK lineage mentions | Docs | **KEEP** | Correct GrapheneOS lineage / diagnostics |
| `bootanimation-dark.zip` on disk under branding/ | File | **KEEP** | Not PRODUCT_COPY wired; theme.mk filters dark entries |

### VALUE-side FAIL leftovers

**0** in `vendor/guardtalk/overlays/**/strings*.xml` and `packages/apps/SetupWizard2/res/**/strings*.xml`.

## Adb

```text
List of devices attached
(empty)
```

Device boot smoke **HOLD** — artifact inspection (zip + out/ product media + frame visual) accepted per task packet.

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| VALUE GrapheneOS smuggled in string body (not name) | fail | 0 | PASS |
| Theme include still `device/tokay/…` hardcoded in bridge | fail | PRODUCT_DEVICE | PASS |
| Stale out/ bootanimation ≠ source md5 | fail | tokay+akita match | PASS |
| SUW icon file still shipped | fail | deleted | PASS |
| Invent device boot PASS without adb | forbidden | HOLD | PASS |
| Product rewrite by QA | forbidden | none | PASS |

## Coverage gaps

- No adb: cannot confirm live first-boot animation on device panel.
- Full `m` not re-run by QA (out/ media already matches source md5 from prior builds).
- Locale `values-*` About summary still AOSP legal-info wording (English default + overlay GuardTalkOS; RRO covers default locale — note for optional F follow-up, not VALUE GrapheneOS FAIL).

## Gate 5 (Self-Critique)

**Q-BRAND-SWEEP Gate 5: 94%** (manual rubric; `ultimate_critique` MCP unavailable — `python: not found`).

Manual rubric (0–10 each): acceptance 10, scope 10, script green 10, no regressions/invented device PASS 10, adversarial VALUE/body scan 9, edge (locales) 8, independence 10, minimal footprint 10, bug docs 9, coverage gaps honest 9 → **95/100 ≈ 94%** after discounting MCP critique gap.

### PQE Assessment: Code Entropy LOW — shared PRODUCT_DEVICE theme wire + value-only rebrand reduces device-hardcode and user-visible brand entropy; ABL splash remains known residual gap (not VALUE FAIL).
