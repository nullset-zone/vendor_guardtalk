# QA Evidence — Q-REMEDIATE-B5-MTP

**Task:** `Q-REMEDIATE-B5-MTP` (independent rematch of `T-REMEDIATE-B5-MTP` item **24** residual)  
**Date:** 2026-09-16T15:47:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B5-MTP` Architect-APPROVED static (2026-09-16T15:42:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-006  
**Verdict:** **PASS (host static)** — `getChargingFunctions()` deny → **FUNCTION_NONE**; ADB → **FUNCTION_ADB**; else **FUNCTION_NONE**. **No FUNCTION_MTP return** in that method. `mustDenyUsbData()` still calls `UsbPortSecurityHooks.mustDenyUsbDataFunctions`. On-device gadget **HOLD**. Stale `out/` **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). PASS HOLD remains.

Independent rematch. Backend completion report and Architect APPROVE dumps were **not trusted**. Product/source were **not** edited by QA. Defaults suite **not** overwritten. No USB GO. No `m`. No flash. No commit. `Q-ONDEVICE` **not** started. On-device charging-only **not invented**.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `mustDenyUsbData()` → `FUNCTION_NONE` | **PASS** | brace-matched extract L1782–1794 |
| 2 | `isAdbEnabled()` → `FUNCTION_ADB` | **PASS** | same extract; deny evaluated first |
| 3 | else `FUNCTION_NONE` (not MTP) | **PASS** | three returns: NONE, ADB, NONE |
| 4 | FAIL if method returns `FUNCTION_MTP` | **PASS** (no MTP return) | comment-stripped body; second-view extract |
| 5 | `mustDenyUsbData()` still calls `UsbPortSecurityHooks.mustDenyUsbDataFunctions` | **PASS** | L893–896; not constant `false` |
| 6 | Locked deny not weakened | **PASS** | hooks null-ctx + catch return true; `applyAdbFunction` still strips MTP/PTP/ADB; `isUsbTransferAllowed` fail-closed |
| 7 | Defaults suite not overwritten | **PASS** | md5 `1345c9d0a707c7069e3b4ae0da5e4023` unchanged |
| 8 | `adb devices -l` empty → gadget HOLD | **HOLD** | header only; not device-fixed |
| 9 | On-device charging-only PASS | **HOLD** (never invented) | `m` not run; empty adb |
| 10 | Status REVIEW only; never APPROVED; no commit | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b5_mtp_host.sh
# RESULT: PASS (host)  bash_PASS=13 bash_HOLD=3 PY_RC=0
# PY_COUNTS PASS_COUNT=21 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=34 HOLD_COUNT=3 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# GADGET=HOLD
# ONDEVICE_CHARGING_ONLY=HOLD
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B5-MTP_SUITE.out`

`pytest platform/tests` N/A (AOSP `UsbDeviceManager` Java, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### `UsbDeviceManager.getChargingFunctions()` (L1782–1794)

Brace-matched extract, comments stripped, returns:

1. `if (mustDenyUsbData())` → `UsbManager.FUNCTION_NONE`
2. `if (isAdbEnabled())` → `UsbManager.FUNCTION_ADB`
3. `else` → `UsbManager.FUNCTION_NONE`

`FUNCTION_MTP` **absent** from the method body after comment strip. Exactly one definition. Exactly three returns. `mustDenyUsbData()` is evaluated **before** `isAdbEnabled()`.

### `mustDenyUsbData()` (L893–896)

Still:

```java
return com.android.server.policy.keyguard.UsbPortSecurityHooks
        .mustDenyUsbDataFunctions(mContext);
```

Does **not** return constant `false`.

### `UsbPortSecurityHooks.mustDenyUsbDataFunctions` (L113–132)

- `ctx == null` → `return true`
- `catch (Throwable)` → `return true`
- still `GuardTalkUsbProtectionPolicy.mustDenyUsbData(deviceLocked, userUnlocked)`

### Deny strip (locked path not weakened)

- `applyAdbFunction` L2145–2164 still removes MTP/PTP/ADB when `mustDenyUsbData()`
- `isUsbTransferAllowed` still returns false when `mustDenyUsbData()`

`UsbDeviceManager.java` mtime **2026-09-16T15:40:33Z** (Backend stamp). QA did not edit it.

## Residuals (not FAIL)

- Stale `out/target/product/komodo/product/etc/build.prop` present → **HOLD** (`m` not run)
- `adb devices -l` empty / serial `54111FDAS000GN` absent → gadget **HOLD**. **Not device-fixed.** Do not lift PASS HOLD.
- User can still enable MTP later via Settings `setCurrentFunctions` after unlock — this card only rematches the **charging default**.
- `verify_remediate_b5_defaults_host.sh` still HOLDs unlocked MTP **by that card's design**; this rematch is separate. Defaults suite **not overwritten**.

## Forbidden actions this stamp

USB GO not started. `m` not started. Flash not started. Git commit not started. Derived `.agent-comm/TASK_QUEUE.md` not edited. Memory-bank not edited. `Q-ONDEVICE` not restarted. Product/source not edited. Status **REVIEW only**.
