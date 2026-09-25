# QA Evidence — Q-REMEDIATE-B1-DEBUG-SUITE

**Task:** `Q-REMEDIATE-B1-DEBUG-SUITE` (standalone host suite; does **not** lift `Q-REMEDIATE-B1-DEBUG-M`)  
**Date:** 2026-09-18T10:20:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-011  
**Depends:** none (standalone; pair of `T-REMEDIATE-B1-DEBUG-M` is **not** APPROVED)  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. New `m` / `komodo-debug-latest` **HOLD**. **FLASH_READY=false**. **DEBUG_FLASH_READY=false**. **LIVE_FLASH_CLAIMED=false**. `Q-REMEDIATE-B1-DEBUG-M` stays **BLOCKED**. Status → **REVIEW** (never APPROVED).

Independent rematch. Architect 2026-09-18T10:14:25Z dump and Backend T-DEBUG-M IN_PROGRESS were **not** trusted. Product/source **not** edited. No USB GO. No `m`. No lunch. No flash. No commit. `*_ondevice.sh` **not** run. Pem contents **not** read.

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## DEBUG_FLASH_READY preconditions (this stamp)

| Pred | Rule | Result | Evidence |
|------|------|--------|----------|
| docs lunch | DEC-011 / ENGINEERING_SIDECAR / KOMODO_PORT_FLASH document `lunch komodo-trunk_staging-userdebug` | **PASS** | all three (plus owner-root `TASK_QUEUE.md`) contain the lunch string |
| T-B1-M HOLD | signed-user still HOLD; pem ABSENT is HOLD not FAIL here | **HOLD** | `HOLD CONFIRMED`; both pem stems ABSENT; `/mnt/secure` missing |
| debug stamp | `komodo-debug-latest` ABSENT until pack | **HOLD** | symlink and `komodo-debug-*` dirs ABSENT |
| komodo-latest | still → `komodo-20260915-063833` | **PASS** | `readlink` exact |
| out type | record `ro.build.type`; userdebug allowed | **PASS** / **HOLD** | `userdebug` + `test-keys` dated 2026-09-15; new `m` not proven |
| sidecar su | xbin su / overlay allowed on sidecar; do not FAIL | **HOLD** | both PRESENT 2026-09-15 04:58 |
| FLASH_READY | never invented true | **false** | signed-user predicates incomplete |
| DEBUG_FLASH_READY | never invented true | **false** | new `m` + pack + Q-DEBUG-M not APPROVED |
| LIVE_FLASH_CLAIMED | false | **false** | `src/types.ts` export; debug honesty table |

Missing new `m` and missing `komodo-debug-latest` are **HOLD, not FAIL**, per dispatch. Test-keys / xbin su on this sidecar are **not FAIL** (invert of the signed-user suite).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `verify_remediate_b1_debug_m_host.sh` exists and is executable | **PASS** | `test -x` = yes |
| 2 | Suite EXIT=0 with FAIL=0; absent new `m` / debug stamp HOLD | **PASS** | EXIT=0 PASS=24 FAIL=0 HOLD=10 |
| 3 | FLASH_READY=false; DEBUG_FLASH_READY=false; LIVE_FLASH_CLAIMED=false | **PASS** | suite footer; not invented true |
| 4 | Evidence sibling written | **PASS** | this file + `Q-REMEDIATE-B1-DEBUG-SUITE_SUITE.out` |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b1_debug_m_host.sh
# RESULT: PASS (host)  bash_PASS=24 bash_HOLD=10 FAIL=0
# WRAPPER_EXIT=0
# PRED_PEM=false PRED_NEW_M=false
# RO_BUILD_TYPE=userdebug RO_BUILD_TAGS=test-keys
# FLASH_READY=false DEBUG_FLASH_READY=false
# FLASH_CLASS=HOLD DEBUG_CLASS=HOLD
# LIVE_FLASH_CLAIMED=false
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
# Q-REMEDIATE-B1-DEBUG-M=BLOCKED
# KOMODO_LATEST=komodo-20260915-063833
# KOMODO_DEBUG_LATEST=ABSENT
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-DEBUG-SUITE_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Architect / Backend dumps)

This host, this stamp (2026-09-18T10:19:15Z suite):

- DEC-REMEDIATE-011 in `.memory-bank/decisions.md` documents `lunch komodo-trunk_staging-userdebug`
- `vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md` documents the same lunch
- `vendor/guardtalk/docs/KOMODO_PORT_FLASH.md` documents the same lunch
- `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` table: DEBUG_FLASH_READY / FLASH_READY / LIVE_FLASH_CLAIMED all **false**
- `vendor/guardtalk/web-installer/src/types.ts` `export const LIVE_FLASH_CLAIMED = false;`
- `T-REMEDIATE-B1-M` **HOLD CONFIRMED**
- `vendor/guardtalk/branding/signing-keys/avb.pem` **ABSENT**
- `/mnt/secure/keys/guardtalk/avb.pem` **ABSENT**; `/mnt/secure` **missing**
- `git ls-files` no pem/pk8 under `vendor/guardtalk`
- `releases/desktop-flash/komodo-debug-latest` **ABSENT**
- `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833`
- `out/.../system/build.prop` `ro.build.type=userdebug` `ro.build.tags=test-keys` (2026-09-15 04:58)
- product + vendor props `userdebug`
- `system/xbin/su` PRESENT (51464 bytes, 2026-09-15 04:58)
- `system/xbin/overlay_remounter` PRESENT (613776 bytes, 2026-09-15 04:58)
- `adb devices -l` empty
- `Q-REMEDIATE-B1-DEBUG-M` still **BLOCKED**

Sept 15 `out/` is **not** a proven new DEC-011 `m`. Image PASS stays BLOCKED.

## Adversarial / HOLD vs FAIL

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| pem ABSENT both stems | HOLD not FAIL | HOLD | PASS |
| `/mnt/secure` missing | HOLD not FAIL | HOLD | PASS |
| `ro.build.type=userdebug` | record; not FAIL | PASS (recorded) | PASS |
| out dated 2026-09-15 (no new `m`) | HOLD not FAIL | HOLD | PASS |
| xbin su on sidecar | HOLD not FAIL | HOLD | PASS |
| out `test-keys` on sidecar | HOLD not FAIL | HOLD | PASS |
| `komodo-debug-latest` ABSENT | HOLD not FAIL | HOLD | PASS |
| `komodo-latest` retargeted | FAIL | still `komodo-20260915-063833` | PASS |
| FLASH_READY invented true | forbidden | false | PASS |
| DEBUG_FLASH_READY invented true | forbidden | false | PASS |
| LIVE_FLASH_CLAIMED=true | FAIL | false | PASS |
| `m` / USB / ondevice started | forbidden | not started | PASS |
| git-tracked pem/pk8 | FAIL if present | ABSENT | PASS |

## Coverage gaps

- Did not run `lunch` / `m` (forbidden; Backend T-DEBUG-M owns that)
- Did not rematch `avbtool` / vbmeta (not a debug-precondition; pem unused here)
- `Q-REMEDIATE-B1-DEBUG-M` image PASS not executed (stays BLOCKED until T-DEBUG-M APPROVED)
- `Q-REMEDIATE-DEBUG-ADVERTISE` advertise rematch is a different card (not lifted)

## Bugs found

None that are FAIL. Residual DEBUG_FLASH_READY blockers are HOLD: no new userdebug `m`, `komodo-debug-latest` ABSENT, Q-DEBUG-M BLOCKED, empty adb. Signed-user FLASH_READY remains false (pem ABSENT; T-B1-M HOLD).

## Regression status

- Pre-existing host suites: not overwritten
- New files only: `verify_remediate_b1_debug_m_host.sh` (+ evidence + suite out)
- Tests modified/deleted: NONE
- `Q-REMEDIATE-B1-DEBUG-M` status: still BLOCKED
