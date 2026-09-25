# QA Evidence — Q-REMEDIATE-B1-DURESS-USB

**Task:** `Q-REMEDIATE-B1-DURESS-USB` (independent rematch of `T-REMEDIATE-B1-DURESS-USB` **item 7**)  
**Date:** 2026-09-16T13:46:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B1-DURESS-USB` Architect-APPROVED static (2026-09-16T13:33:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-002  
**Verdict:** **PASS (host lunch + static)** — wipe e2e **HOLD**. adb empty **HOLD**. Green **not invented**. Device **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). **PASS HOLD remains.**

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. No USB GO. No lock/wipe of serial `54111FDAS000GN`. `Q-REMEDIATE-B1-ONDEVICE` was **not** started.

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns) and `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Gate -1 in-process. Guardian MCP/HTTP not called (TOOL UNAVAILABLE).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent `lunch komodo-trunk_staging-user` `PRODUCT_PROPERTY_OVERRIDES` contains `vendor.guardtalk.usb_duress_wipe.enabled=1` | **PASS** | artifact token PRESENT; sidecar userdebug ABSENT |
| 2 | yellow or green accepted; `isVerifiedBootGreen` gone; orange/red/empty not accepted | **PASS** | `isVerifiedBootYellowOrGreen` exact body; identifier ABSENT; truth table |
| 3 | `mustDenyUsbDataFunctions` still present; `Reason.DURESS` still in `DuressPasswordHelper` | **PASS** | Java still fail-closed + gadget strip; helper:67 + `DuressWipe.run` |
| 4 | Wipe e2e HOLD; adb empty HOLD | **HOLD** | USB GO not executed; `adb devices` header only |
| 5 | REVIEW only; never APPROVED; no commit; not device-fixed | **PASS** | this card; no product edits |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b1_duress_usb_host.sh
# RESULT: PASS (host)  bash_PASS=44 bash_HOLD=4 PY_RC=0
# PY_COUNTS PASS_COUNT=16 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=60 HOLD_COUNT=4 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# GREEN=HOLD
# WIPE_E2E=HOLD
# USB_GO=not started
# DEVICE=HOLD
# PASS_HOLD=remains
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-DURESS-USB_SUITE.out`  
Overrides dump: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B1-DURESS-USB_PRODUCT_PROPERTY_OVERRIDES.txt`

`pytest platform/tests` N/A (AOSP Java + product mk, not AEGIS Python platform).

First suite run **FAIL** (host): policy markdown says `data-role **DEVICE**`, not the token `DATA_ROLE_DEVICE`. Java still requires `UsbPortStatus.DATA_ROLE_DEVICE`. Suite string tightened; product **not** edited. Second run is the record.

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp (`lunch` ~13:44:34Z):

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
PRODUCT_PROPERTY_OVERRIDES contains:
  vendor.guardtalk.usb_duress_wipe.enabled=1
  ro.adb.secure=1
  ro.guardtalk.production_profile=1
```

Independent python token check of the artifact: flag `=1` PRESENT; flag `=0` ABSENT; `verifiedbootstate=green` ABSENT.

User `PRODUCT_PACKAGES` / `PRODUCT_PACKAGES_DEBUG`: `su` / `overlay_remounter` **ABSENT** (USERBUILD not regressed).

### Sidecar adversarial (not product truth)

`lunch komodo-trunk_staging-userdebug` → `TARGET_BUILD_VARIANT=userdebug`.  
`PRODUCT_PROPERTY_OVERRIDES` does **not** contain `vendor.guardtalk.usb_duress_wipe.enabled=1` (Java default remains `"0"`).

### USB / verified boot (item 7)

`UsbPortSecurityHooks.java`:

- `isVerifiedBootYellowOrGreen` returns `"yellow".equals(state) || "green".equals(state)` only
- `isVerifiedBootGreen` **ABSENT**
- Java `isUsbDuressWipeEnabled` default still `"0"`
- `getCurrentDataRole() != UsbPortStatus.DATA_ROLE_DEVICE` still required
- `mustDenyUsbDataFunctions` still present, null-ctx fail-closed, used by `sanitizeUsbFunctions`
- `DuressWipe.run(context)` still the USB wipe entry

`guardtalk-production-hardening.mk` user `ifeq`: flag `=1` next to `ro.adb.secure=1`. Not in un-gated overrides.

### Lockscreen duress (not rewritten)

- `DuressPasswordHelper.java:67` still `SecureWipeEngine.Reason.DURESS`
- `DuressWipe.java:21` still `SecureWipeEngine.Reason.DURESS`

### Device / wipe

```
adb devices
List of devices attached
(empty)
```

Device HOLD. Wipe e2e **HOLD**. USB GO **not** executed. Serial `54111FDAS000GN` **not** locked or wiped. Live `verifiedbootstate` **not** read. `LIVE_DEVICE_CLAIMED=false`. Green **not invented**.

## Adversarial rematch

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| user lunch missing `usb_duress_wipe.enabled=1` | fail | PRESENT | PASS |
| Java default flipped to `"1"` | fail | still `"0"` | PASS |
| sidecar inherits flag=1 | fail (user-gate broken) | ABSENT | PASS |
| `isVerifiedBootGreen` still present | fail | ABSENT | PASS |
| orange / red / empty / `YELLOW` / trailing space accepted | fail | rejected by truth table | PASS |
| `DATA_ROLE_NONE` / `HOST` as wipe trigger | fail | DEVICE required | PASS |
| `mustDenyUsbDataFunctions` removed / null-ctx open | fail | present; fail-closed | PASS |
| `Reason.DURESS` gone from helper | fail | still present | PASS |
| PRODUCT-lie `verifiedbootstate=green` | fail | absent in komodo tree + user overrides | PASS |
| empty adb → device-fixed / live green / wipe | forbidden | HOLD | PASS (HOLD) |

## Coverage gaps

- Wipe e2e on designated test unit + operator GO (`Q-REMEDIATE-B1-ONDEVICE`, BLOCKED)
- Live `getprop ro.boot.verifiedbootstate` (would be yellow on custom-key; **do not invent**)
- `m` / flashed user image / atest `UsbPortSecurityHooks`
- Stale HOLD text may remain in `PRODUCTION_HARDENING_POLICY.md` / RUNBOOK §12 / `SECURE_WIPE_SERVICE.md` (not this card’s target paths)

## Bugs found

None that fail host AC for item 7. Expected HOLDs recorded. Green not invented. Charge-only-when-locked not weakened.

## Regression status

- Product Java / mk / USB policy: **not edited by QA**
- `doctrine/` / `governance/laws/` / `governance/gates/`: **untouched**
- Derived `.agent-comm/TASK_QUEUE.md`: **untouched**
- Tests modified/deleted: **NONE**
- Pre-existing pytest: N/A
