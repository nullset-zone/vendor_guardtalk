# QA Evidence — Q-REMEDIATE-B1-ONDEVICE

**Task:** `Q-REMEDIATE-B1-ONDEVICE` (independent on-device probe; PASS HOLD lift gate with sibling `Q-REMEDIATE-B2-ONDEVICE`)  
**Date:** 2026-09-16T14:15:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B1-USERBUILD` / `T-REMEDIATE-B1-AVB` / `T-REMEDIATE-B1-DURESS` Architect-APPROVED static — **not trusted**  
**DEC:** DEC-REMEDIATE-003  
**Serial:** `54111FDAS000GN` (Pixel 9 Pro XL komodo)  
**Verdict:** **HOLD (on-device probe)** — `adb devices -l` **empty**. Named unit **absent**. Live props **not read**. Wipe e2e **HOLD** (do NOT wipe). **PASS HOLD remains.** **Not device-fixed.** Status → **REVIEW** (never APPROVED). Never live.

Independent rematch. Host-static APPROVE of USERBUILD / AVB / DURESS was **not trusted**. Product source was not edited. No USB GO. No `fastboot flash`. No `fastboot flashing lock`. No wipe. No `m`. No commit. Sibling `Q-REMEDIATE-B2-ONDEVICE` was **not waited**.

Gate -1 in-process: loaded `.aegis/governance/gates/gate_neg1_guardian_first.yaml` and laws YAML (0, 2, 4, 7, 9, 10, 11, 12, 16). Guardian MCP/HTTP / `mcp1_gate_enforcer` / aegis-verifier **not** called (dispatch forbids).

Empty adb is a **successful HOLD delivery**, not a failure to dispatch. Suite **EXIT 0**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Probe `adb devices -l` first | **PASS (empty recorded)** | suite RAW block; header only |
| 2 | If empty or serial ≠ `54111FDAS000GN`: HOLD REVIEW | **HOLD** | `ADB_LIST_EMPTY=true` `SERIAL_PRESENT=false` |
| 3 | Do not invent live / user / green / SPL pin | **PASS** | no getprop; pin `2026-09-05` not claimed live |
| 4 | If named unit present: rematch `ro.build.type=user`, `ro.debuggable=0`, no `su`, `ro.adb.secure=1` / RSA | **HOLD (not probed)** | empty adb |
| 5 | SPL live vs pin `2026-09-05` — HOLD allowed | **HOLD** | not read |
| 6 | DEC-002: yellow **or** green accepted; orange/red FAIL | **HOLD (not read)** | do not invent yellow/green |
| 7 | Programmatic duress wipe e2e | **HOLD** | no operator-present test-unit confirmation; do NOT wipe |
| 8 | USB duress wipe e2e | **HOLD** | no operator-present test-unit confirmation; do NOT wipe |
| 9 | userdebug / test-keys must not lift PASS HOLD | **HOLD** | image not observed; PASS HOLD remains |
| 10 | No flash / lock / USB GO / wipe / `m` | **PASS** | suite forbidden-actions PASS; not executed |
| 11 | Status REVIEW only; never APPROVED; never device-fixed; never live | **PASS** | this stamp |
| 12 | PASS HOLD remains (this card cannot lift) | **HOLD / PASS** | `PASS_HOLD_LIFTED=false` |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b1_ondevice.sh
# RESULT: HOLD (on-device probe)  bash_PASS=12 bash_HOLD=13 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD_LIFTED=false
# DEVICE=HOLD
# WIPE_E2E=HOLD
# USB_DURESS_WIPE=HOLD
# STATUS=REVIEW
# ADB_LIST_EMPTY=true
# SERIAL_PRESENT=false
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-ONDEVICE_SUITE.out`

`pytest platform/tests` N/A (on-device adb probe, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### adb (this host, this stamp)

`adb devices -l` at suite STAMP `2026-09-16T14:14:24Z` and at pre-suite `2026-09-16T14:12:29Z`:

```
List of devices attached
```

ADB 1.0.41 (34.0.4-debian). Exit 0. No serial lines. Named unit `54111FDAS000GN` **absent**.

Live rematch **not started**:

- `ro.build.type` not read (do not invent `user`)
- `ro.debuggable` not read
- `su` / `overlay_remounter` not probed
- `ro.adb.secure` / RSA prompt not probed
- `ro.build.version.security_patch` not read (pin of record remains `2026-09-05`; live HOLD)
- `ro.boot.verifiedbootstate` not read (DEC-002 yellow OR green; do not invent; orange/red would FAIL if seen)
- `ro.build.tags` not read (do not invent `release-keys`; test-keys would HOLD PASS HOLD)

### Destructive proofs

Not executed. Packet forbids wipe without operator-present test-unit confirmation. USB GO / flash / lock / `m` not executed.

### PASS HOLD

DEC-REMEDIATE-001: PASS HOLD lifts only after Blocks 1–2 **on-device** rematch vs the status board. Empty adb cannot lift it. This card Status is **REVIEW** only. Architect APPROVE of static USERBUILD/AVB/DURESS is **not** a live lift.

## Negatives (must not happen)

| Negative | Result |
|----------|--------|
| Invent live user image from empty adb | **not done** |
| Claim `verifiedbootstate=green` (or yellow) without getprop | **not done** |
| Claim live SPL `2026-09-05` | **not done** |
| Treat empty adb as device-fixed / PASS HOLD lift | **not done** |
| Run programmatic / USB duress wipe | **not done** |
| `fastboot flash` / `fastboot flashing lock` / USB GO / `m` | **not done** |
| Status APPROVED | **not done** |
| Edit product source / doctrine / gates / secrets / AVB keys | **not done** |
| Edit derived `.agent-comm/TASK_QUEUE.md` | **not done** |
| Wait on sibling Q-B2-ONDEVICE | **not done** |

## Coverage gaps

- Named komodo not attached; all live getprop rematch deferred until USB + operator
- RSA prompt not observed
- Wipe e2e remains HOLD even if the unit later appears (needs operator-present confirmation)
- Sibling Block 2 on-device probe is a separate card

## Bugs found

None that fail this probe card. Empty adb is the expected HOLD path this stamp.

`LIVE_DEVICE_CLAIMED=false`
`PASS_HOLD_LIFTED=false`
