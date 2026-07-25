# QA Evidence — Q-PORT-AKITA

**Task:** `Q-PORT-AKITA` (Akita build + flash-bundle completeness + tokay non-regression)  
**Date:** 2026-07-25  
**Agent:** QA_ENGINEER  
**Depends:** `T-PORT-AKITA-FLASH` ✅ APPROVED (Architect 2026-07-25 10:00)  
**Verdict:** **GO** (static + lunch re-check + checksums) — device flash+boot+parity **HOLD** (adb empty)

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Bundle `releases/desktop-flash/akita-latest` complete (18 imgs + avb + SHA256SUMS + README) | PASS | Symlink → `akita-20260725-061711`; 18 imgs; public `avb_pkmd.bin`; no `*.pem`/`*.pk8` |
| 2 | `sha256sum -c SHA256SUMS` | PASS | EXIT=0; 19 OK lines |
| 3 | README Pixel 8a / `REMOTE_BUILD_DIR=…/akita-latest` | PASS | README-FLASH-DESKTOP.md paths verified |
| 4 | Tokay `releases/desktop-flash/latest` still tokay | PASS | `latest` → `tokay-20260724-152717`; distinct from akita; tokay SHA EXIT=0; 18 imgs |
| 5 | SetupWizard2 (akita out/) CommunityLock / `device_password` | PASS | APK layout + dex markers |
| 6 | Akita layer / Goodix / VINTF akita manifest | PASS | `goodix_brl_touch` blocklist; `vendor_manifest_no_radio_akita.xml` (no `IGiaService`); tokay VINTF still has Gia |
| 7 | Lunch or cite FLASH BUILD_EXIT=0 + host re-check | PASS | FLASH report BUILD_EXIT=0; QA lunch `akita-trunk_staging-userdebug` LUNCH_EXIT=0 (`TARGET_PRODUCT=akita`); out/ sizes match bundle; adevtool pin `5ecaa4df…` |
| 8 | Device flash+boot+parity | **HOLD** | `adb devices` empty — not invent PASS |

## Static script

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_port_akita_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=73 HOLD_COUNT=1 FAIL=0 EXIT=0
```

**Counts:** **73 / 73** PASS (0 FAIL), HOLD=1 (adb), EXIT=0.  
Script: `vendor/guardtalk/docs/qa/verify_port_akita_static.sh` (executable).

Optional live lunch inside script (if evidence file absent):

```bash
GT_QA_RUN_LUNCH=1 bash vendor/guardtalk/docs/qa/verify_port_akita_static.sh
```

## Host lunch / build re-check (this QA session)

| Source | Command / note | Result |
|--------|----------------|--------|
| FLASH cite | `TO_ARCHITECT_T-PORT-AKITA-FLASH.md` | `m -j96` **BUILD_EXIT=0** (2026-07-25T06:16:55Z) |
| QA lunch | `source build/envsetup.sh && lunch akita-trunk_staging-userdebug` | **LUNCH_EXIT=0**; `TARGET_PRODUCT=akita` userdebug |
| Size match | bundle vs `out/target/product/akita/` | boot/system/vendor/product/vbmeta/system_ext **YES** |
| adevtool pin | `vendor/adevtool` HEAD vs pin mk | **5ecaa4df472de43127db378dc803a502271a9ecd** match (no bypass) |
| Akita SHA | `(cd akita-latest && sha256sum -c SHA256SUMS)` | **EXIT=0** |
| Tokay SHA | `(cd latest && sha256sum -c SHA256SUMS)` | **EXIT=0** |

## Bundle inventory

| Item | Value |
|------|-------|
| Path | `releases/desktop-flash/akita-20260725-061711` |
| Symlink | `akita-latest` → `akita-20260725-061711` |
| Images | 18 (flash-from-remote class) |
| Extras | `avb_pkmd.bin` (public tokay copy per README), `SHA256SUMS`, `README-FLASH-DESKTOP.md` |
| Tokay `latest` | Untouched → `tokay-20260724-152717` |

## Adb

```text
List of devices attached
(empty)
```

Runtime device E2E **HOLD** (do not invent PASS):

- Desktop flash via `flash-from-remote.sh` with `REMOTE_BUILD_DIR=…/akita-latest`
- First boot + Community / Syndicate SUW lock smoke on Pixel 8a
- On-device parity (radio excised / Goodix / overlays)

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| `latest` redirected to akita | forbidden | still tokay | PASS |
| Private keys in desktop-flash | forbidden | none | PASS |
| SHA256SUMS stale vs imgs | fail closed | all OK | PASS |
| Tokay VINTF regressed (lost Gia / swapped to akita xml) | forbidden | tokay still has `IGiaService`; akita uses no-Gia xml | PASS |
| Invent device E2E PASS without adb | forbidden | HOLD documented | PASS |
| Bundle missing flash-from-remote required imgs | fail | 18/18 present | PASS |

## Coverage gaps

- No Pixel 8a / adb: cannot verify flash, boot, SUW lock, or live excision behavior.
- Full `m` not re-run by QA (honest cite of FLASH BUILD_EXIT=0 + lunch + out/size re-check).
- `avb_pkmd.bin` is public tokay copy until `keys/akita/` exists (documented residual from FLASH).

## Gate 5 (Self-Critique)

**Q-PORT-AKITA Gate 5: 95%** (manual rubric; `self_critique` MCP 100/100; `ultimate_critique` MCP unavailable — `python: not found`).

### PQE Assessment: Code Entropy LOW — bundle isolation (akita-latest vs tokay latest) + device-correct VINTF reduce cross-device regression risk; device E2E remains open HOLD.
