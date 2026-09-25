# QA Evidence — Q-REMEDIATE-B1-M-SUITE

**Task:** `Q-REMEDIATE-B1-M-SUITE` (standalone host suite; pair of `T-REMEDIATE-B1-M` is **not** APPROVED)  
**Date:** 2026-09-18T09:08:54Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-010  
**Depends:** none (standalone; does **not** lift `Q-REMEDIATE-B1-M`)  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. Pem/out gaps **HOLD**. **FLASH_READY=false** (not invented). `Q-REMEDIATE-B1-M` stays **BLOCKED**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Architect 2026-09-18T07:47:21Z ABSENT stamp and Backend T-B1-M HOLD dumps were **not trusted**. Product/source **not** edited. No USB GO. No `m`. No lunch. No flash. No commit. `*_ondevice.sh` **not** run. `Q-ONDEVICE` **not** started.

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## FLASH_READY image predicates (this stamp)

| Pred | Rule | Result | Evidence |
|------|------|--------|----------|
| pem | `avb.pem` at in-tree stem **or** `/mnt/secure/keys/guardtalk/avb.pem` | **HOLD** (false) | both stems ABSENT; `/mnt/secure` missing |
| user out | `out/target/product/komodo` `ro.build.type=user` | **HOLD** (false) | system+product+vendor `userdebug` dated 2026-09-15 |
| xbin | no `su` / `overlay_remounter` | **HOLD** (false) | both PRESENT 2026-09-15 04:58 |
| no testkey | out tags not `test-keys`; product AVB path not AOSP testkey | **HOLD** (out) / **PASS** (wiring) | out `test-keys`; late mk path is project pem |
| pem used | pem present **and** user out **and** not test-keys | **HOLD** (false) | pem ABSENT; stale userdebug out |
| FLASH_READY | true only if all of the above | **false** | never invented true |

Pem absence and userdebug `out/` are **HOLD, not FAIL**, per dispatch. User-out + xbin su would have been FAIL; that contradiction was not present.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `verify_remediate_b1_m_host.sh` exists and is executable | **PASS** | `test -x` = yes |
| 2 | Suite EXIT=0 with FAIL=0; pem/out gaps HOLD | **PASS** | EXIT=0 PASS=10 FAIL=0 HOLD=16 |
| 3 | Evidence file written; FLASH_READY not invented true | **PASS** | this file; `FLASH_READY=false` `FLASH_CLASS=HOLD` |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b1_m_host.sh
# RESULT: PASS (host)  bash_PASS=10 bash_HOLD=16 FAIL=0
# WRAPPER_EXIT=0
# PRED_PEM=false PRED_USER_OUT=false PRED_XBIN_CLEAN=false
# PRED_NO_TESTKEY=false PRED_PEM_USED=false
# FLASH_READY=false FLASH_CLASS=HOLD
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
# Q-REMEDIATE-B1-M=BLOCKED
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-M-SUITE_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Architect / Backend dumps)

This host, this stamp (2026-09-18T09:06:54Z rematch + 09:08:54Z suite):

- `vendor/guardtalk/branding/signing-keys/avb.pem` **ABSENT** (dir: `.gitignore` + `RUNBOOK.md` only)
- `/mnt/secure/keys/guardtalk/avb.pem` **ABSENT**
- `/mnt/secure` **missing**
- `find vendor/guardtalk` `*.pem`/`*.pk8` empty; `git ls-files` empty
- `out/.../system/build.prop` `ro.build.type=userdebug` `ro.build.tags=test-keys` (2026-09-15 04:58)
- product + vendor props same `userdebug` / `test-keys`
- `system/xbin/su` PRESENT (51464 bytes, 2026-09-15 04:58)
- `system/xbin/overlay_remounter` PRESENT (613776 bytes, 2026-09-15 04:58)
- `vbmeta.img` present on userdebug out (not pem-used proof); `avb_pkmd.bin` ABSENT
- `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` (document only; not retargeted)
- `adb devices -l` empty
- Product late mk still points at project `avb.pem`, not AOSP `testkey_rsa4096.pem`

Confirms Architect rematch 2026-09-18T07:47:21Z independently: pem ABSENT, out userdebug + xbin su.

## Adversarial / HOLD vs FAIL

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| pem ABSENT both stems | HOLD | HOLD | PASS |
| `/mnt/secure` missing | HOLD | HOLD | PASS |
| `ro.build.type=userdebug` | HOLD not FAIL | HOLD | PASS |
| xbin su on userdebug | HOLD not FAIL | HOLD | PASS |
| out `test-keys` on userdebug | HOLD not FAIL | HOLD | PASS |
| FLASH_READY invented true | forbidden | false | PASS |
| `m` / USB / ondevice started | forbidden | not started | PASS |
| git-tracked pem/pk8 | FAIL if present | ABSENT | PASS |
| user out + xbin su | FAIL | N/A (out is userdebug) | not hit |

## Coverage gaps

- `avbtool info_image` on stale `vbmeta.img` not run (would still be HOLD; not pem-used proof)
- Lunch not run (out of scope; image predicates only)
- `Q-REMEDIATE-B1-M` image PASS not executed (stays BLOCKED until T-B1-M APPROVED)

## Bugs found

None that are FAIL. Residual FLASH_READY blockers are HOLD: pem ABSENT, stale userdebug `out/`, xbin su, test-keys, empty adb.

## Regression status

- Pre-existing host suites: not overwritten
- New file only: `verify_remediate_b1_m_host.sh` (+ evidence + suite out)
- Tests modified/deleted: NONE
- `Q-REMEDIATE-B1-M` status: still BLOCKED
