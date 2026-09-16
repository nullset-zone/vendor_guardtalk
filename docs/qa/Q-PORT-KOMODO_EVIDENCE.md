# QA Evidence — Q-PORT-KOMODO

**Task:** `Q-PORT-KOMODO` (Pixel 9 Pro XL stamp + CLI rematch + tokay/akita/rango non-regression)  
**Date:** 2026-09-15T07:33:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-PORT-KOMODO-FLASH` ✅ APPROVED (Architect 2026-09-15T07:14:00Z)  
**Verdict:** **PASS (static / host)** — device flash+boot **HOLD** (adb empty, fastboot missing). **Not FLASH live GO.** Status → **REVIEW** (never APPROVED).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` | PASS | symlink inode **193110380** → `komodo-20260915-063833` |
| 2 | `(cd komodo-latest && sha256sum -c SHA256SUMS)` | PASS | EXIT=0; **20/20 OK** (independent QA run 2026-09-15T07:30:32Z and suite re-run) |
| 3 | Required files present; `super.img` omitted OK | PASS | bootloader radio boot init_boot vendor_boot vendor_kernel_boot pvmfw dtbo vbmeta vbmeta_system vbmeta_vendor system system_ext product vendor vendor_dlkm system_dlkm super_empty avb_pkmd.bin init.insmod.komodo.cfg |
| 4 | No `.pem`/`.pk8`; no `keys/komodo/`; public avb | PASS | pem/pk8 count=0; `keys/komodo/` ABSENT; SHA `7728e30f50bfa5cea165f473175a08803f6a8346642b5aa10913e9d9e6defef6` matches `keys/tokay/avb_pkmd.bin` and akita stamp |
| 5 | tokay `latest` inode 193110379; `akita-latest` 193110357 | PASS | `latest` → `tokay-20260725-102506`; `akita-latest` → `akita-20260725-101434` |
| 6 | both `flash-from-remote.sh` `cmp` + `bash -n` | PASS | cmp EXIT=0; bash -n both EXIT=0 |
| 7 | CLI `DEVICE=komodo` | PASS | normalize → `komodo`; pretty `Pixel 9 Pro XL (komodo)`; paths `komodo-latest`; cleanup `tokay\|akita\|komodo` + erase fips; extras `init.insmod.komodo.cfg` |
| 8 | Negative matrix | PASS | `caiman` unmapped (not komodo); `rango` → `rango-latest` (`rango-20260802-130756`); empty/unknown fail-closed |
| 9 | Layer still present (zumapro / QFP, not akita Goodix) | PASS | `vendor/guardtalk/device/komodo/`; `GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 9 Pro XL`; blocklist `syna_touch`/`bcmdhd4390` (no `goodix_brl_touch` entry); REGEN_HOOKS QFP |
| 10 | Lunch | **HOLD (not claimed PASS)** | QA did **not** re-run `lunch`. Cite FLASH log `BUILD_EXIT=0` at `/tmp/t-port-komodo-flash-m-20260915T050731Z.log` (`#### build completed successfully (13:28 (mm:ss)) ####`) + file rematch |
| 11 | USB / adb / fastboot smoke | **HOLD** | `adb devices` empty; `fastboot` not installed — do not invent PASS |

## Static script (suite of record)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_port_komodo_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=64 HOLD_COUNT=3 FAIL=0 EXIT=0
```

Host SHA / cmp / bash -n is the suite. `pytest platform/tests` N/A (AOSP stamp card).

## Independent rematch (do not trust engineer report)

### Stamp

| Item | Value |
|------|-------|
| Symlink | `komodo-latest` → `komodo-20260915-063833` |
| Symlink inode | 193110380 |
| SHA256SUMS | 20 lines, 20 OK, EXIT=0 |
| vbmeta / vbmeta_system / vbmeta_vendor | identical SHA `87bb9d42e52bc0a21f5d01cdbf6ffc6e205ad0234b20219ed2d945a0f09a56a7` |
| avb_pkmd.bin | `7728e30f50bfa5cea165f473175a08803f6a8346642b5aa10913e9d9e6defef6` |
| Private keys | none |
| `super.img` | omitted |

### Non-regression inodes

```text
193110379  releases/desktop-flash/latest → tokay-20260725-102506
193110357  releases/desktop-flash/akita-latest → akita-20260725-101434
193110354  releases/desktop-flash/rango-latest → rango-20260802-130756
193110380  releases/desktop-flash/komodo-latest → komodo-20260915-063833
```

### CLI (extracted functions; flash script body not executed — no USB)

| Hook | Result |
|------|--------|
| `normalize_device komodo` / `KOMODO` | `komodo` |
| `device_pretty komodo` | `Pixel 9 Pro XL (komodo)` |
| `apply_remote_paths komodo` | `…/releases/desktop-flash/komodo-latest` |
| `apply_grapheneos_firmware_cleanup` | `tokay\|akita\|komodo` uart + **erase fips** + dpm |
| `KOMODO_EXTRA_FILES` | `init.insmod.komodo.cfg` |
| `normalize_device caiman` | empty → die unsupported |
| `normalize_device rango` | `rango` → `rango-latest` (not stolen) |
| `normalize_device ""` / `unknown` / `shiba` / `husky` | empty → fail-closed |

### FLASH log cite (lunch not re-run)

```text
#### build completed successfully (13:28 (mm:ss)) ####
BUILD_EXIT=0
END=2026-09-15T05:21:29Z
LOG=/tmp/t-port-komodo-flash-m-20260915T050731Z.log
```

Wrapper (`/tmp/t-port-komodo-flash-wrapper-r3.out`) records `LUNCH_EXIT=0`, `TARGET_PRODUCT=komodo`, `TARGET_BOARD_PLATFORM=zumapro`, `GUARDTALK_RADIO_EXCISED=true`, `PRODUCT_MODEL=GuardTalk Pixel 9 Pro XL`. QA **does not** claim lunch PASS this session.

### Adb

```text
List of devices attached
(empty)
```

`fastboot` not found. Runtime device E2E **HOLD**.

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| `caiman` mapped to komodo | forbidden | unmapped | PASS |
| `rango` stolen to komodo-latest | forbidden | `rango-20260802-130756` | PASS |
| tokay/akita inodes changed | forbidden | 193110379 / 193110357 | PASS |
| pem/pk8 or `keys/komodo/` | forbidden | none | PASS |
| Invent USB PASS | forbidden | HOLD documented | PASS |
| Claim lunch PASS without running | forbidden | HOLD + FLASH log cite | PASS |

INFO (non-blocking): substring fallback checks `rango` before `komodo`, so a synthetic string `komodo-rango` normalizes to `rango`. Production `getvar product` = `komodo` is exact-match. Not a fail for this card.

## Coverage gaps

- No Pixel 9 Pro XL on USB: cannot verify flash, boot, SUW, or live fips erase.
- Full `m` / `lunch` not re-run by QA (honest cite of FLASH `BUILD_EXIT=0` + host file rematch).
- `avb_pkmd.bin` is public tokay copy until `T-PORT-KOMODO-KEYS`.
- Web installer advertise is **out of scope** (`Q-PORT-KOMODO-WEBINSTALL` after F).

## Gate 5 (Self-Critique)

**Q-PORT-KOMODO Gate 5: 93/100** (manual rubric; MCP skipped per dispatch).

| Rubric | Score |
|--------|-------|
| Acceptance | 10 |
| Scope | 10 |
| Tests | 8 (host suite; lunch not re-run; pytest N/A) |
| No-regression | 10 |
| Error handling | 9 |
| Security | 10 |
| Quality | 9 |
| Footprint | 10 |
| Docs | 9 |
| Reversibility | 8 (USB unproven) |

### PQE Assessment: Code Entropy LOW — komodo stamp isolated from tokay/akita/rango publish points; DEVICE fail-closed; public AVB only. Device E2E remains open HOLD.

## Bugs found

None this round. No product-port edits by QA (host script + evidence only).
