# QA Evidence — Q-REMEDIATE-B3-VALIDATOR

**Task:** `Q-REMEDIATE-B3-VALIDATOR` (independent rematch of `F-REMEDIATE-B3-VALIDATOR` items **15, 16**)  
**Date:** 2026-09-16T13:54:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `F-REMEDIATE-B3-VALIDATOR` Architect-APPROVED static (2026-09-16T13:42:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-002  
**Verdict:** **PASS (host static + user lunch)** — device enable/nav **HOLD**. dumpsys `enabled=0` is `COMPONENT_ENABLED_STATE_DEFAULT`. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Frontend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. No USB GO. No wipe. No commit. `Q-ONDEVICE` / USB GO **not** started. `SensorPrivacyService.java` not edited.

GIP-0: loaded `.memory-bank/` (read-only) and `.aegis/governance/` 24 laws + 11 gates. Gate -1 in-process. Guardian MCP/HTTP not called.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent `lunch komodo-trunk_staging-user` → `GuardTalkValidator` PRESENT | **PASS** | `get_build_var PRODUCT_PACKAGES` token `GuardTalkValidator` |
| 2 | Manifest `android:enabled="true"` on `<application>` + both activities | **PASS** | live XML attrs, not comments |
| 3 | No in-tree overlay / `pm disable` of `com.guardtalk.validator` | **PASS** | vendor overlay/apps/device/radio/feature/permissions scan |
| 4 | Exit chrome on ValidatorActivity + ProcessListActivity (`finishAndRemoveTask`) | **PASS** | both layouts include chrome; `exitApp` → `finishAndRemoveTask` |
| 5 | Escape/menu: Settings, camera/mic helper, device status | **PASS** | `EscapeMenu` + `escape_menu.xml` |
| 6 | SensorToggleHelper polarity not inverted | **PASS** | `accessOn = !privacy`; views `isChecked = accessOn` |
| 7 | Status must not include Duress | **PASS** | live strings + `DeviceStatusReporter` + Snapshot |
| 8 | `SensorPrivacyService.java` untouched by this card | **PASS** (structural) / **HOLD** (git) | no Validator import; git metadata absent |
| 9 | `adb devices` empty → device enable/nav HOLD; do not invent `enabled=true` | **HOLD** | adb empty; DEFAULT=0 documented |
| 10 | Status REVIEW only; never APPROVED; no commit | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b3_validator_host.sh
# RESULT: PASS (host)  bash_PASS=27 bash_HOLD=4 bash_FAIL=0 PY_RC=0
# PY_COUNTS pass=52 fail=0 hold=1
# COMBINED: PASS_COUNT=79 HOLD_COUNT=5 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# DEVICE_ENABLE_NAV=HOLD
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B3-VALIDATOR_SUITE.out`

`pytest platform/tests`: N/A (AOSP Validator app / product mk, not AEGIS Python platform).

## Independent rematch (do not trust F / Architect dumps)

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
filtered PRODUCT_PACKAGES: GuardTalkValidator PRESENT
```

Session-only `GIT_CONFIG` `safe.directory` for `vendor/adevtool`. Did **not** `set -u` around `envsetup`.

### Enablement (item 15)

- Live `android:enabled="true"` on `<application>`, `.ValidatorActivity`, `.ProcessListActivity`.
- `PackageManager.COMPONENT_ENABLED_STATE_DEFAULT = 0` (ENABLED=1, DISABLED=2). Audit dumpsys `enabled=0` is DEFAULT (follow manifest), **not** disabled. On-device `enabled=true` **not claimed**.
- No `pm disable` / `setApplicationEnabledSetting` of `com.guardtalk.validator` under vendor GuardTalk product trees.
- No overlay `targetPackage="com.guardtalk.validator"`.
- Settings `guardtalk_gt_info` is `enabled=true` via `GuardTalkGtInfoPreferenceController` (legacy Stub not wired).
- `GUARDTALK_USERBUILD_DROP` is `su overlay_remounter` only.

### Exit + escape (item 16)

- Both screens include `validator_chrome` (`btn_exit` / `btn_menu`).
- Exactly two `Activity` classes. Exit → `finishAndRemoveTask`.
- Escape: Menu / ESC / long-press BACK / long-press or triple-tap title.
- `KEYCODE_HOME` not consumed.
- Menu: `ACTION_SETTINGS` then exit; `SensorToggleViews.bind`; `DeviceStatusReporter.format`.
- Status live copy has no Duress; fail-closed when locked.

### Polarity / SensorPrivacyService

- Helper: `isAccessOn = !isSensorPrivacyEnabled`; persist `privacy = !accessOn`; 4-arg `mustDenySensors`.
- Views do not invert `accessOn`.
- Validator sources do not import `SensorPrivacyService`.
- Git metadata absent in this worktree → git-diff **HOLD**; structural no-import **PASS**.

## Suite bug (not a product FAIL)

First run EXIT=1: `grep -Fxq` in a `pipefail` pipeline SIGPIPE-false-ABSENT. The same dump already printed `GuardTalkValidator`. Suite fixed (no `-q` in the pipe). Re-run EXIT=0.

## Residuals (not FAIL)

- Device enable/nav unverified (adb empty).
- `m GuardTalkValidator` not run.
- Git proof of `SensorPrivacyService` untouched HOLD (no `.git`).
- PASS HOLD remains. Live not claimed.
