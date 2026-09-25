# QA Evidence — Q-REMEDIATE-B1-DEBUG-M

**Task:** `Q-REMEDIATE-B1-DEBUG-M` (independent rematch of T-DEBUG-M r3 userdebug `out/`)  
**Date:** 2026-09-18T14:35:19Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-011 / DEC-013 / DEC-014  
**Depends:** `T-REMEDIATE-B1-DEBUG-M` APPROVED 2026-09-18T14:31:53Z (dependency only; dumps **not** trusted)  
**Verdict:** **PASS (host image rematch)** — r3 `m` **BUILD_EXIT=0**.  
`out/.../system/build.prop` `ro.build.type=userdebug` mtime **2026-09-18** (not 2026-09-15).  
**FLASH_READY=false**. **DEBUG_FLASH_READY=false** (pack not done; not invented true).  
**USB_GO=false**. Status → **REVIEW** (never APPROVED).

Independent rematch. Architect 2026-09-18T14:31:53Z APPROVE and Backend
`T-REMEDIATE-B1-DEBUG-M_EVIDENCE.md` / inbox dumps were **not** trusted.
Product/source **not** edited. T-DEBUG-M evidence **not** overwritten.
No USB GO. No `m`. No lunch. No pack. No flash. No commit. Pem contents **not** read.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`.
Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**.
Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent rematch of T-DEBUG-M evidence + `out/` userdebug | **PASS** | this host re-read r3 log + `build.prop` + stamps |
| 2 | `m` EXIT=0 recorded | **PASS** | r3 log L28838 `#### build completed successfully (22:31 (mm:ss)) ####`; L28840 `BUILD_EXIT=0` |
| 3 | FLASH_READY stays false; DEBUG_FLASH_READY not invented true | **PASS** | both **false**; pack ABSENT; `komodo-debug-latest` ABSENT |

## Confirmations (dispatch)

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| r3 `m` BUILD_EXIT | 0 + success banner | `BUILD_EXIT=0`; `#### build completed successfully (22:31)` | **PASS** |
| `ninja: build stopped` / `^FAILED:` | 0 | 0 / 0 | **PASS** |
| lunch combo | userdebug | `COMBO=komodo-trunk_staging-userdebug` | **PASS** |
| `LUNCH_EXIT` | 0 | 0 | **PASS** |
| `TARGET_PRODUCT` | komodo | `komodo` (log L22/L35/L46) | **PASS** |
| `TARGET_BUILD_VARIANT` | userdebug | `userdebug` | **PASS** |
| `BUILD_KEYS` | test-keys **allowed** | `test-keys` | **PASS** (not FAIL) |
| system `build.prop` type | `ro.build.type=userdebug` | `userdebug` | **PASS** |
| system `build.prop` mtime | **2026-09-18** (not 2026-09-15) | `2026-09-18 11:28:52.317616251 +0000` | **PASS** |
| xbin `su` | allowed; do not FAIL | PRESENT 51464 B (mtime 2026-09-15 04:58) | **PASS** (allowed) |
| xbin `overlay_remounter` | allowed | PRESENT 613776 B (mtime 2026-09-15 04:58) | **PASS** (allowed) |
| pem ABSENT | not FAIL here | both stems ABSENT; `TREE_PEM_COUNT=0`; `/mnt/secure` missing | **HOLD** (not FAIL) |
| `FLASH_READY` | false | false | **PASS** |
| `DEBUG_FLASH_READY` | false (pack not done) | false; `komodo-debug-latest` ABSENT; no `komodo-debug-*` dirs | **PASS** |
| `komodo-latest` | still → `komodo-20260915-063833` | exact `readlink` | **PASS** |
| USB GO | not started | `adb devices -l` empty; no flash | **PASS** |

## Independent rematch (do not trust Architect / Backend dumps)

This host, this stamp (2026-09-18T14:35:19Z). Commands were `stat` / `grep` /
`readlink` / `find` / `adb devices` only. `lunch` and `m` were **not** started.

### r3 log

```
path: vendor/guardtalk/docs/qa/T-REMEDIATE-B1-DEBUG-M_M-r3.log
mtime: 2026-09-18 11:49:47.230911273 +0000
size: 3768789
COMBO=komodo-trunk_staging-userdebug
LUNCH_EXIT=0
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=userdebug
BUILD_KEYS=test-keys
#### build completed successfully (22:31 (mm:ss)) ####
BUILD_EXIT=0
M_END=2026-09-18T11:49:47Z
USB_GO=false FLASH_READY=false DEBUG_FLASH_READY=false
ninja: build stopped count=0
^FAILED: count=0
```

META sibling `T-REMEDIATE-B1-DEBUG-M_META-r3.txt` agrees (`BUILD_EXIT=0`,
`COMBO=komodo-trunk_staging-userdebug`). Used as cross-check only.

### `out/target/product/komodo/system/build.prop` (re-read)

```
mtime: 2026-09-18 11:28:52.317616251 +0000
mtime_utc: 2026-09-18T11:28:52Z
size: 5379
ro.build.type=userdebug
ro.build.tags=test-keys
ro.build.flavor=mainline-userdebug
ro.build.id=BP4A.260205.002
ro.system.build.type=userdebug
ro.system.build.tags=test-keys
ro.system.build.fingerprint=google/komodo/komodo:Baklava/BP4A.260205.002/eng.openst:userdebug/test-keys
ro.debuggable=1
ro.secure=1
```

`ro.build.date` is still the tree `BUILD_DATETIME` pin (`Thu Jul  2 05:59:08 UTC 2026`).
File **mtime** is 2026-09-18 — this is the r3 rewrite, not the 2026-09-15 leftover.

Product prop (`product/etc/build.prop`) mtime 2026-09-18 11:28:52Z:
`ro.build.type=userdebug` / `ro.product.build.type=userdebug`.
Vendor prop (`vendor/build.prop`) `ro.vendor.build.type=userdebug`
(mtime 2026-09-18 10:31:54Z; fingerprint userdebug/test-keys).

### Images (observation; pack is not this card)

| Image | mtime | Note |
|-------|-------|------|
| `system.img` | 2026-09-18 11:45:21Z | this `m` |
| `vbmeta.img` | 2026-09-18 11:49:45Z | this `m` |
| `vendor.img` | 2026-09-18 11:34:39Z | this `m` |
| `product.img` | 2026-09-18 11:34:51Z | this `m` |
| `boot.img` | 2026-09-15 04:59:09Z | incremental leftover; **HOLD for pack**, not FAIL here |

### Sidecar su / keys / stamps

- `system/xbin/su` PRESENT (sidecar allowed; not FAIL). mtime still 2026-09-15
  (ninja did not rebuild the binary; `build.prop` + `system.img` are 2026-09-18).
- `system/xbin/overlay_remounter` PRESENT (allowed).
- `vendor/guardtalk` `*.pem` / `*.pk8`: **0**. `avb.pem` both stems **ABSENT**.
  `/mnt/secure` **missing**. Pem ABSENT is **not FAIL** on this card.
- `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` (not retargeted).
- `komodo-debug-latest` **ABSENT**. No `komodo-debug-*` dirs. Pack not done.
- `adb devices -l` empty. USB GO **not** started.
- No `m` / ninja / soong build process running. This session did **not** start `m`.

### Honesty flags (not invented true)

- `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` table: `DEBUG_FLASH_READY` /
  `FLASH_READY` / `LIVE_FLASH_CLAIMED` all **false**.
- `vendor/guardtalk/web-installer/src/types.ts:119`
  `export const LIVE_FLASH_CLAIMED = false;`
- Owner-root `T-REMEDIATE-B1-M` still **HOLD CONFIRMED** (pem ABSENT).
- T-DEBUG-M evidence file left in place; this file is a **distinct** QA sibling.

## Adversarial / HOLD vs FAIL

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| r3 BUILD_EXIT != 0 | FAIL | 0 + success banner | PASS |
| `build.prop` mtime still 2026-09-15 | FAIL | 2026-09-18 11:28:52Z | PASS |
| `ro.build.type` not userdebug | FAIL | userdebug | PASS |
| lunch was `user` (wrong channel) | FAIL | `komodo-trunk_staging-userdebug` | PASS |
| `TARGET_PRODUCT` not komodo | FAIL | komodo | PASS |
| test-keys on sidecar | allowed; not FAIL | test-keys | PASS |
| xbin su on sidecar | allowed; not FAIL | PRESENT | PASS |
| pem ABSENT | not FAIL here | ABSENT | PASS (HOLD) |
| `FLASH_READY=true` invented | forbidden | false | PASS |
| `DEBUG_FLASH_READY=true` invented | forbidden | false | PASS |
| `komodo-latest` retargeted | FAIL | still `komodo-20260915-063833` | PASS |
| `komodo-debug-latest` present without pack APPROVE | would HOLD pack, not this FAIL | ABSENT | PASS |
| USB GO / `m` started by QA | forbidden | not started | PASS |
| boot.img still 2026-09-15 | HOLD for pack | leftover | HOLD (not FAIL) |

## Coverage gaps

- Did not re-run `lunch` / `m` (forbidden on this card; rematch of existing r3 log + `out/`).
- Did not pack or rematch `komodo-debug-*` (T/Q-DEBUG-PACK).
- Did not rematch signed-user `T-REMEDIATE-B1-M` / pem / AVB (HOLD CONFIRMED remains).
- `pytest platform/tests` N/A (AOSP host rematch, not AEGIS Python platform).
- Incremental `boot.img` leftover is a pack residual, not closed here.

## Bugs found

None that are FAIL. Residuals (HOLD, not this card):

- `DEBUG_FLASH_READY` stays **false** until T-DEBUG-PACK + Q-DEBUG-PACK.
- `FLASH_READY` stays **false** (signed-user pem ABSENT; T-B1-M HOLD CONFIRMED).
- `boot.img` mtime 2026-09-15 (incremental; pack must not treat it as a new signed-user image).
- Empty adb (host-only; USB GO not started).

## Regression status

- T-DEBUG-M evidence / r3 log / META **not** overwritten.
- New files only: this evidence + `Q-REMEDIATE-B1-DEBUG-M_REMATCH.out`.
- Tests modified/deleted: NONE.
- Derived `.agent-comm/TASK_QUEUE.md` **not** edited.
- Status **REVIEW** only. Never APPROVED. No commit.

## Flags of record

```
FLASH_READY=false
DEBUG_FLASH_READY=false
LIVE_FLASH_CLAIMED=false
USB_GO=false
M_STARTED=false
PASS_HOLD=remains
KOMODO_LATEST=komodo-20260915-063833
KOMODO_DEBUG_LATEST=ABSENT
BUILD_EXIT=0
RO_BUILD_TYPE=userdebug
RO_BUILD_TAGS=test-keys
BUILD_PROP_MTIME=2026-09-18T11:28:52Z
```
