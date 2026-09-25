# QA Evidence — Q-REMEDIATE-B3-OSUX-DEVICE

**Task:** `Q-REMEDIATE-B3-OSUX-DEVICE` (on-device rematch of OS-UX DEVICE HOLD)  
**Date:** 2026-09-16T14:14:37Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-003  
**Depends:** komodo **user** image exists (`T-REMEDIATE-B1-USERBUILD` APPROVED + flash). Flash **not** present this stamp.  
**Serial:** `54111FDAS000GN`  
**Verdict:** **HOLD REVIEW** — `adb devices -l` empty. Documented HOLD delivery **EXIT=0**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). **PASS HOLD remains.**  
**LIVE_DEVICE_CLAIMED:** false  
**Static Q-VIEWER / Q-SENSORS APPROVE treated as live:** false (forbidden)

Independent probe. Architect DISPATCH and static OS-UX / Q-VIEWER / Q-SENSORS APPROVE were **not trusted as live**. Product source was not edited. Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP / HTTP / aegis-verifier / gate_enforcer **not called**. Memory-bank **not edited**. Derived `.agent-comm/TASK_QUEUE.md` **not edited**.

Do **not** re-open `T-OS-CAMMIC-*` / `T-OS-BACK-*` / `T-OS-FILES-*` (APPROVED static). Do **not** fold this card into `Q-REMEDIATE-B3-VIEWER`.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Probe `adb devices -l` first | **HOLD** (process **PASS**) | empty list after header. Artifact `_artifacts/Q-REMEDIATE-B3-OSUX-DEVICE_adb.txt` |
| 2 | Named unit `54111FDAS000GN` on flashed **user** image | **HOLD** | serial absent; no `ro.build.type=user` proof |
| 3 | Cam/mic QS tiles (`mictoggle` / `cameratoggle`) rematch | **HOLD** | not run (no device). Never claimed live from Q-SENSORS static |
| 4 | System back rematch | **HOLD** | not run (no device). Never claimed live from Q-OS-BACK-* static |
| 5 | Files HTMLViewer jpeg/png/webp rematch (never silent) | **HOLD** | not run (no device). Never claimed live from Q-VIEWER static |
| 6 | Empty adb = successful HOLD delivery EXIT=0 | **PASS** | suite EXIT=0; FAIL_COUNT=0 |
| 7 | No USB GO / flash / lock / wipe / `m` / commit / APPROVED / PASS HOLD lift | **PASS** | suite honesty lines; this file |
| 8 | Not folded into Q-VIEWER; T-OS-* not re-opened | **PASS** | process checks in suite |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
adb devices -l
# List of devices attached
# (empty)

bash vendor/guardtalk/docs/qa/verify_remediate_b3_osux_device.sh
# PASS_COUNT=9 FAIL_COUNT=0 HOLD_COUNT=5
# DEVICE_STATE=empty USER_IMAGE=false LIVE_DEVICE_CLAIMED=false
# RESULT: PASS (documented HOLD delivery)  EXIT=0
# OVERALL: HOLD REVIEW (adb empty / wrong serial / not user image). Not device-fixed.
```

Full transcript: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B3-OSUX-DEVICE_SUITE.out`

`pytest platform/tests`: N/A (on-device OS-UX probe, not AEGIS Python platform).

## Packet commands (raw)

### `adb devices -l`

```
List of devices attached

```

Empty. Named serial `54111FDAS000GN` **ABSENT**. `getprop` / `dumpsys` / `query-activities` **not executed**. Device rematch **HOLD**. Device-fixed **not claimed**.

### Cam/mic QS tiles

Not run. HOLD: no adb. Static `Q-REMEDIATE-B3-SENSORS` APPROVE is **not** live tile proof.

### System back

Not run. HOLD: no adb. Static `Q-OS-BACK-NAV` / `Q-OS-BACK-GESTURE` APPROVE is **not** live back proof.

### Files HTMLViewer jpeg/png/webp

Not run. HOLD: no adb. Static `Q-REMEDIATE-B3-VIEWER` APPROVE (`query-activities` HOLD) is **not** live Files-open proof. Empty resolver would be FAIL if a user image were attached (never silent).

## Adversarial / negative matrix

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Empty adb claimed as device-fixed / live PASS HOLD lift | FAIL (forbidden) | HOLD REVIEW; LIVE_DEVICE_CLAIMED=false | PASS (HOLD) |
| Empty adb treated as suite FAIL | EXIT=0 documented HOLD | EXIT=0 FAIL_COUNT=0 | PASS |
| Static Q-VIEWER / Q-SENSORS APPROVE treated as live | forbidden | STATIC_Q_VIEWER_SENSORS_LIVE=false | PASS |
| Fold into Q-REMEDIATE-B3-VIEWER | forbidden | FOLD_INTO_Q_VIEWER=false | PASS |
| Re-open T-OS-CAMMIC / T-OS-BACK / T-OS-FILES | forbidden | left APPROVED static | PASS |
| Silent fail on empty query-activities (if device present) | FAIL | path not taken (no device) | N/A (HOLD) |
| Wrong serial rematch | HOLD REVIEW | no other serials | PASS (empty) |
| USB GO / flash / lock / wipe / `m` | not started | not started | PASS |

## Residuals (not FAIL)

- Cam/mic QS tile visibility + tap vs `dumpsys sensor_privacy` HOLD until flashed **user** image on `54111FDAS000GN`.
- Settings / Files / multi-activity system back + gesture HOLD until that image.
- Files tap-open jpeg/png/webp via HTMLViewer HOLD until that image (`query-activities` is still not tap proof).
- `m` not run. PASS HOLD remains.

## Regression status

- Product source: **not edited**
- `doctrine/` / `governance/laws/` / `governance/gates/`: **untouched**
- `.agent-comm/TASK_QUEUE.md` (derived) / memory-bank: **untouched**
- Tests modified/deleted: **NONE** (new device-probe suite only)
- T-OS-* / F-OS-* / Q-VIEWER / Q-SENSORS cards: **not re-opened, not folded**
