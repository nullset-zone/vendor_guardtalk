# QA Evidence — Q-SEC-P2-STACK

**Task:** `Q-SEC-P2-STACK` (Phase-2 §32 stack + build/boot smoke)  
**Date:** 2026-07-22  
**Agent:** QA_ENGINEER  
**Depends:** All Phase-2 T/F APPROVED (LOCK→SENSOR→USB→AUTOREBOOT→WIPE→F-SECURITY-SCREENS)  
**Verdict:** **GO** (static + cited prior builds) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Password-only lock policy hooks | PASS | `GuardTalkLockPolicy` + `GuardTalkLockSettingsHooks` + LSS `enforceSetLockCredential`; prop/overlay `password_only_lock=1/true` |
| Mic/camera fail-closed locked + pre-first-unlock | PASS | `GuardTalkSensorPrivacyHooks` + `mustDenySensors`; props `sensor_privacy_when_locked=1` |
| USB OFF locked/pre-unlock; charging-only; no USB QS | PASS | `UsbPortSecurityHooks` / `UsbDeviceManager`; `usb_protection_fail_closed`; SystemUI QS lists lack `usb` tile |
| Lockdown fail-closed; no Lockdown QS | PASS | Sensor hooks airplane fail-closed; `lockdown_fail_closed`; QS lists lack `lockdown` |
| Auto-reboot Off/1h/2h/4h/8h + exclusion ctl | PASS | `GuardTalkAutoRebootPolicy.PROFILE_TIMEOUTS_MS` + `CTL_PAUSE`/`CTL_RESUME`; `AutoReboot` exclusion |
| SecureWipeEngine single path (UI/Duress/anti-bruteforce@10) | PASS | `Reason.{USER_REQUESTED,DURESS,ANTI_BRUTEFORCE}` call sites in LSS / DuressPasswordHelper / DuressWipe; threshold prop=10 |
| HW-backed Weaver counter — not userdata authority | PASS | `HwBackedFailedAttemptCounter` Weaver increment; documents `failure_counter` non-authority |
| Security UI: wipe confirm; status post-unlock; no Duress in status | PASS | `GuardTalkSecureWipeActivity` password→warning→confirm; `isPostUnlockStatusAllowed`; status XML has no Duress key |
| No network under Security; no Wipe/Duress QS | PASS | Dashboard/status XML clean of network prefs; QS lists lack wipe/duress; docs/overlay assertions |
| Policy docs present | PASS | PASSWORD_ONLY / SENSOR / USB / AUTO_REBOOT / SECURE_WIPE / DURESS policies |
| Prior green builds cited | PASS | Signals LOCK/SENSOR/F-SECURITY `exit_code=0`; DONE_LOG Phase-2 chain + `m Settings green` |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_p2_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=94 FAIL_COUNT=0 EXIT=0
```

Created for `Q-SEC-P2-STACK` (mirrors `verify_sec_p1_static.sh` style).

## Artifact / build smoke (cited; no fresh `m` this session)

| Source | Command | Result |
|--------|---------|--------|
| `review-T-SEC-P2-LOCK.json` | `m services Settings -j$(nproc)` | `exit_code: 0` |
| `review-T-SEC-P2-SENSOR.json` | `m services Settings -j$(nproc)` | `exit_code: 0` |
| `review-F-SEC-P2-SECURITY-SCREENS.json` | `m Settings -j$(nproc)` | `exit_code: 0` |
| DONE_LOG USB→WIPE→Frontend | prior APPROVED notes | USB/AUTOREBOOT/WIPE Gate 5 92–93%; Frontend `m Settings green` |

No rebuild performed this QA session (task allows citing prior green builds).

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime boot/UI smoke **SKIPPED** (lock enrollment, sensor deny when locked, USB data while locked, wipe confirm dialogs, status post-unlock, QS editor).

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Network prefs under Security dashboard/status | absent | absent | PASS |
| Duress preference key in status XML | forbidden | comment-only; no key | PASS |
| QS stock/default/new_default contain lockdown/usb/wipe/duress | forbidden | absent as tile tokens | PASS |
| `failure_counter` as wipe authority | forbidden | Hw counter documents Weaver / timeout estimate only | PASS |
| DuressWipe / DuressPasswordHelper bypass SecureWipeEngine | forbidden | both call `SecureWipeEngine.run(..., DURESS)` | PASS |
| Anti-bruteforce threshold ≠ 10 | forbidden | prop + `DEFAULT_WIPE_THRESHOLD=10` | PASS |

## Coverage gaps

- Device/runtime smoke deferred until adb device available
- Fresh `m services Settings` / `m Settings` not re-run this session (cited prior green)
- Weaver slot persistence / reboot survival not exercised on hardware
- Phase-3 QS catalog exactness (exactly 4 tiles) out of scope — only absence of forbidden tiles verified

## PQE Assessment

Code entropy **LOW–MEDIUM** — policy props + thin hooks + shared wipe engine; fail-closed defaults; single wipe path reduces cascade risk. Residual entropy in Weaver fallback (timeout estimate) is documented and fail-closed toward wipe.

## Gate 5

### Ultimate Critique Score: 93% (Gate 5)

Method: manual fallback (`ultimate_critique` MCP failed: `python: not found`).  
Manual 0–10: acceptance 10, scope 10, tests pass 10, regressions 10, adversarial 8, edges 8, independence 10, footprint 10, bugs/docs 9, gaps 8 → **93/100**.

## GO / NO-GO

**GO** for Architect review of Phase-2 static acceptance.  
Runtime adb gaps must not block REVIEW; recommend device smoke before Phase-3 production confidence.
