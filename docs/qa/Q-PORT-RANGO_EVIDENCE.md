# QA Evidence — Q-PORT-RANGO

**Task:** `Q-PORT-RANGO` (Rango flash-bundle completeness + flash script + tokay/akita non-regression)  
**Date:** 2026-07-25  
**Agent:** QA_ENGINEER (aegis-qa-engineer)  
**Depends:** `T-PORT-RANGO-FLASH` ✅ APPROVED — FLASH READY (Architect 2026-07-25 17:45)  
**Verdict:** **GO** (static + checksums + script/layer) — device fold smoke **HOLD** (adb empty)

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Bundle `releases/desktop-flash/rango-latest` complete (18 imgs + avb + SHA256SUMS + README; prefer `init.insmod.rango.cfg`) | PASS | Symlink → `rango-20260725-133716`; 18 imgs; public `avb_pkmd.bin`; `init.insmod.rango.cfg` present |
| 2 | `(cd rango-latest && sha256sum -c SHA256SUMS)` | PASS | EXIT=0; 20 OK lines (18 imgs + avb + init.insmod) |
| 3 | No `*.pem` / `*.pk8` in bundle | PASS | `find` count = 0 |
| 4 | Symlink isolation: `rango-latest` ≠ `latest` ≠ `akita-latest`; tokay/akita stamps unchanged | PASS | tokay `tokay-20260725-102506`; akita `akita-20260725-101434`; three distinct realpaths; tokay/akita SHA EXIT=0 |
| 5 | README Pixel 10 Pro Fold + `REMOTE_BUILD_DIR=…/rango-latest` | PASS | README-FLASH-DESKTOP.md verified |
| 6 | flash-from-remote both copies: rango → rango-latest; pretty name Pixel 10 Pro Fold | PASS | root ↔ vendor `diff` identical; mapping + pretty name present |
| 7 | Layer sanity: `vendor/guardtalk/device/rango/`; REGEN_HOOKS laguna; VINTF rango excised + foldable touchflow | PASS | layer dir; REGEN_HOOKS laguna; `vendor_manifest_no_radio_rango.xml` keeps `touchflow_outer` |
| 8 | Device fold smoke (boot / fold / branding / Settings / SUW) | **HOLD** | `adb devices` empty — not invent PASS |

## Static script

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_port_rango_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=76 HOLD_COUNT=1 FAIL=0 EXIT=0
```

**Counts:** **76 / 76** PASS (0 FAIL), HOLD=1 (adb), EXIT=0.  
**Script:** `vendor/guardtalk/docs/qa/verify_port_rango_static.sh` (executable).

## Commands executed (this QA session)

| Check | Command | Result |
|-------|---------|--------|
| Symlinks | `readlink releases/desktop-flash/{rango-latest,latest,akita-latest}` | `rango-20260725-133716` / `tokay-20260725-102506` / `akita-20260725-101434` |
| Completeness | loop over 18 required imgs + avb + SHA256SUMS + README + init.insmod | all OK |
| Checksums | `(cd releases/desktop-flash/rango-latest && sha256sum -c SHA256SUMS)` | **EXIT=0** (20 OK) |
| Private keys | `find … \( -name '*.pem' -o -name '*.pk8' \)` | **0** |
| Tokay SHA | `(cd latest && sha256sum -c SHA256SUMS)` | **EXIT=0** |
| Akita SHA | `(cd akita-latest && sha256sum -c SHA256SUMS)` | **EXIT=0** |
| Script parity | `diff -q scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh` | identical |
| Size match | bundle vs `out/target/product/rango/` (boot/system/vendor/product/vbmeta/system_ext) | all **YES** |
| Adb | `adb devices` | empty list |

## Bundle inventory

| Item | Value |
|------|-------|
| Path | `releases/desktop-flash/rango-20260725-133716` |
| Symlink | `rango-latest` → `rango-20260725-133716` |
| Images | 18 (flash-from-remote class) |
| Extras | `avb_pkmd.bin` (public tokay copy per README; `keys/rango/` absent), `SHA256SUMS`, `README-FLASH-DESKTOP.md`, `init.insmod.rango.cfg` |
| Lunch (FLASH cite) | `rango-trunk_staging-userdebug`; BUILD_EXIT=0 |
| Tokay `latest` | Untouched → `tokay-20260725-102506` |
| Akita `akita-latest` | Untouched → `akita-20260725-101434` |

## Layer / VINTF spot checks

| Check | Result |
|-------|--------|
| `vendor/guardtalk/device/rango/` | present (BoardConfig-excised-late, blocklist, REGEN_HOOKS, flags, insmod, …) |
| REGEN_HOOKS SoC | **laguna** (“rango is laguna — not zumapro”) |
| Foldable note in REGEN_HOOKS | concurrent_foldable / unfold RROs called out as non-excision |
| `vendor_manifest_no_radio_rango.xml` | present; header: “Foldable twoshay touchflow_outer is preserved” |
| HAL | `ITwoshayFileDumpService/touchflow_outer` present |
| `vintf-excised.mk` | selects `vendor_manifest_no_radio_rango.xml` for `PRODUCT_DEVICE=rango` |

## Flash script mapping (both copies)

| Codename | Pretty name | Bundle path |
|----------|-------------|-------------|
| `rango` | Pixel 10 Pro Fold (rango) | `…/releases/desktop-flash/rango-latest` |

Both `scripts/flash-from-remote.sh` and `vendor/guardtalk/scripts/flash-from-remote.sh` are byte-identical and include rango extras (`init.insmod.rango.cfg`).

## Adb

```text
List of devices attached
(empty)
```

Runtime device fold smoke **HOLD** (do not invent PASS):

- Desktop flash via `flash-from-remote.sh` with `REMOTE_BUILD_DIR=…/rango-latest` (clean wipe)
- First boot + fold open/close
- GuardTalk branding / Settings / SUW spot checks on Pixel 10 Pro Fold

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| `latest` redirected to rango | forbidden | still tokay-20260725-102506 | PASS |
| `akita-latest` redirected to rango | forbidden | still akita-20260725-101434 | PASS |
| Private keys in desktop-flash | forbidden | none | PASS |
| SHA256SUMS stale vs imgs | fail closed | all OK | PASS |
| Invent device E2E PASS without adb | forbidden | HOLD documented | PASS |
| Bundle missing flash-from-remote required imgs | fail | 18/18 present | PASS |
| VINTF drops foldable touchflow_outer | forbidden | preserved | PASS |
| REGEN_HOOKS claims wrong SoC | forbidden | laguna | PASS |

## Coverage gaps

- No Pixel 10 Pro Fold / adb: cannot verify flash, boot, fold hinge behavior, branding, Settings, or SUW on-device.
- Full `m` not re-run by QA (honest cite of FLASH BUILD_EXIT=0 + out/size re-check + bundle SHA).
- `avb_pkmd.bin` is public tokay copy until `keys/rango/` exists (documented residual from FLASH).

## Gate 5 (Self-Critique)

**Q-PORT-RANGO Gate 5: 95%** (manual rubric; `self_critique` MCP 97/100; `ultimate_critique` MCP unavailable — `python: not found`).

### PQE Assessment: Code Entropy LOW — bundle isolation (rango-latest vs tokay latest vs akita-latest) + device-correct VINTF/laguna layer reduce cross-device regression risk; device fold E2E remains open HOLD.
