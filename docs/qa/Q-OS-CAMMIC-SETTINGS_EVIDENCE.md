# QA Evidence — Q-OS-CAMMIC-SETTINGS

**Task:** `Q-OS-CAMMIC-SETTINGS` (independent rematch of `F-OS-CAMMIC-SETTINGS`)  
**Date:** 2026-09-16T08:58:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `F-OS-CAMMIC-SETTINGS` APPROVED (Architect 2026-09-16T08:36:00Z)  
**DEC:** DEC-OS-UX-001  
**Verdict:** **PASS (static / host)** — device Settings/QS vs `dumpsys sensor_privacy` **HOLD**. lunch **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Frontend completion report and Architect APPROVE were **not trusted**. Product source was not edited. This card is Settings/QS UI binding vs true privacy state, **not** a re-run of `Q-OS-CAMMIC-TOGGLE` / `T-OS-CAMMIC-TOGGLE`.

GIP-0: loaded `.aegis/governance/laws/` (24 YAML) and `.aegis/governance/gates/` (11 YAML). Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / aegis-verifier / ask_guardian / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Evidence PASS/FAIL/HOLD + raw command output | **PASS** | this file + `verify_os_cammic_settings_static.sh` + `Q-OS-CAMMIC-SETTINGS_SUITE.out` |
| 2 | Helper + CameraToggleTile + MicrophoneToggleTile 4-arg `mustDenySensors(isKeyguardLocked, …)`; no 3-arg leftover | **PASS** | each call is 4-arg; first arg `keyguardShowing` bound to `km.isKeyguardLocked()` |
| 3 | `isChecked = !isSensorBlocked`; `setChecked(false)` → `setSensorBlocked(true)`; `setChecked(true)` rejected when 4-arg mustDeny | **PASS** | `SensorToggleController` |
| 4 | Disable + locked summary only when 4-arg mustDeny **and** access OFF | **PASS** | `applyGuardTalkAccessUi` / `DISABLED_DEPENDENT_SETTING` |
| 5 | PrivacyControlsFragment lifecycle observers; XML keys `privacy_camera_toggle` / `privacy_mic_toggle` | **PASS** | fragment `addObserver(use(…))` + XML keys |
| 6 | `GuardTalkSensorPrivacyPreferenceController` deep-links `Settings.ACTION_PRIVACY_CONTROLS` | **PASS** | intent + manifest `android.settings.PRIVACY_CONTROLS` → `PrivacyControlsFragment` |
| 7 | QS tiles refuse turning access ON while 4-arg mustDeny; long-click Controls | **PASS** | both tiles `handleClick` refuse + `getLongClickIntent` |
| 8 | Negative: 3-arg leftover still used for enable-blocked | **PASS (refuted)** | no 3-arg call in Helper + two tiles; 3-arg remains policy legacy only |
| 9 | Negative: disable-as-locked while interactively unlocked (stale `isDeviceLocked`) | **PASS (refuted)** | 4-arg enableBlocked=false when kg dismissed + deviceLocked true |
| 10 | Negative: switch moves but AppOps unchanged; QS desync | **HOLD (device AppOps)** / **PASS (static QS bind)** | tiles identical 4-arg bodies; persist invert present; adb empty |
| 11 | Settings/QS match `dumpsys sensor_privacy` | **HOLD** | `adb devices` empty list. Do **not** claim device-fixed |
| 12 | lunch / `m Settings` | **HOLD** | tokay adevtool pin not independently verified (`vendor/adevtool` git ownership); `adevtool-version-check.mk` not edited |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_os_cammic_settings_static.sh
# SUITE_COUNTS PASS_COUNT=81 FAIL_COUNT=0 HOLD_COUNT=1
# HOLD: adb devices empty
# RESULT: PASS (static)  PY_RC=0 EXIT=0
# Combined: 81 PASS / 0 FAIL / 2 HOLD (adevtool/lunch + adb)
```

Full transcript: `vendor/guardtalk/docs/qa/Q-OS-CAMMIC-SETTINGS_SUITE.out`

`pytest platform/tests` N/A (AOSP Settings/SystemUI UI-binding card, not AEGIS Python platform).

## Independent rematch (do not trust F report)

### 4-arg mustDeny / no 3-arg leftover

`GuardTalkSensorPrivacyHelper.areSensorsForceDenied`:

- `keyguardShowing = km.isKeyguardLocked()`
- `deviceLocked = km.isDeviceLocked(userId)` (passed through; unused by 4-arg body once keyguard dismissed)
- `mustDenySensors(keyguardShowing, deviceLocked, userUnlocked, strongAuth)` — **4 args**
- `isSensorEnableBlocked` → `areSensorsForceDenied`

`CameraToggleTile` / `MicrophoneToggleTile` `isGuardTalkSensorEnableBlocked`: same 4-arg + `isKeyguardLocked()`. Bodies identical (no QS desync in the lock signal).

No `mustDenySensors(deviceLocked, userUnlocked, flags)` 3-arg call in those three files.

Policy still has the legacy 3-arg overload that duplicates `deviceLocked` as `keyguardShowing`. That is **not** the Settings/QS enable-blocked path. Stale policy javadoc still says Settings helper uses `isDeviceLocked` as the lock-screen signal — **documentation drift in a Backend file**; F was forbidden from editing it.

### Polarity (access ON = privacy OFF)

```
isChecked()           → !isSensorBlocked(sensor)
setChecked(false)     → setSensorBlocked(sensor, true)   // access OFF still blocks
setChecked(true)      → rejected if Helper.isSensorEnableBlocked (4-arg mustDeny)
```

QS parent: `state.value = !isBlocked`; click `setSensorBlocked(!blocked)`. Child tiles refuse the click when `blocked && mustDeny` (turning access ON) and still call `super.handleClick` otherwise (turning access OFF still reaches persist).

### Fragment / XML / deep-link

- `PrivacyControlsFragment` registers lifecycle observers on `CameraToggleController` and `MicToggleController`.
- XML keys `privacy_camera_toggle` / `privacy_mic_toggle` with matching controller classes.
- Preference controller: `new Intent(Settings.ACTION_PRIVACY_CONTROLS)` (`android.settings.PRIVACY_CONTROLS`).
- Manifest `Settings$PrivacyControlsActivity` → `PrivacyControlsFragment`.
- Both QS tiles override long-click to `ACTION_PRIVACY_CONTROLS` (Controls, not dashboard).

### Host truth-table (UI enable-blocked, policy ON)

| State | keyguard | deviceLocked | userUnlocked | flags | enableBlocked 4-arg | leftover 3-arg would |
|-------|----------|--------------|--------------|-------|---------------------|----------------------|
| Unlocked | F | F | T | 0 | **F** | F |
| Stale `isDeviceLocked`, keyguard dismissed | F | T | T | 0 | **F** | **T** |
| Keyguard showing | T | T | T | 0 | T | T |
| Pre-unlock | F | T | F | 0 | T | T |
| Lockdown `0x20` | F | F | T | 0x20 | T | T |
| Keyguard + lockdown | T | T | T | 0x20 | T | T |

Adversarial: `setChecked(false)` while keyguard still persists blocked=true; `setChecked(true)` while keyguard rejected; stale `deviceLocked` + keyguard dismissed does **not** reject access ON; QS click refuses ON only when 4-arg mustDeny.

## Raw command output

### Packet rg (Settings privacy + XML)

```
packages/apps/Settings/res/xml/privacy_controls_settings.xml:25:        android:key="privacy_camera_toggle"
packages/apps/Settings/res/xml/privacy_controls_settings.xml:32:        android:key="privacy_mic_toggle"
packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java:102:        return !mSensorPrivacyManagerHelper.isSensorBlocked(getSensor());
packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java:106:    public boolean setChecked(boolean isChecked) {
packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java:111:        mSensorPrivacyManagerHelper.setSensorBlocked(getSensor(), !isChecked);
packages/apps/Settings/src/com/android/settings/privacy/PrivacyControlsFragment.java:34:    private static final String CAMERA_KEY = "privacy_camera_toggle";
packages/apps/Settings/src/com/android/settings/privacy/PrivacyControlsFragment.java:35:    private static final String MIC_KEY = "privacy_mic_toggle";
```

### Packet rg (mustDeny / isKeyguardLocked)

```
frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java:149:        final boolean keyguardShowing = km != null && km.isKeyguardLocked();
frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java:153:        return GuardTalkSensorPrivacyPolicy.mustDenySensors(
frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java:149:        final boolean keyguardShowing = km != null && km.isKeyguardLocked();
frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java:153:        return GuardTalkSensorPrivacyPolicy.mustDenySensors(
packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSensorPrivacyHelper.java:85:        final boolean keyguardShowing = km != null && km.isKeyguardLocked();
packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSensorPrivacyHelper.java:90:        return GuardTalkSensorPrivacyPolicy.mustDenySensors(
```

### adb devices

```
List of devices attached

```

Empty list → **HOLD**. `dumpsys sensor_privacy` / AppOps **not run**. **Not device-fixed.**

### lunch

`git -C vendor/adevtool rev-parse HEAD` failed (dubious ownership). Pin SHA not independently verified. `m Settings` not run. `adevtool-version-check.mk` **not edited**. **HOLD.**

## Coverage gaps

- Device Settings switch vs `dumpsys sensor_privacy` / AppOps not proven (no adb).
- lunch / `m Settings` not run.
- Runtime QS long-click and lockscreen tile UNAVAILABLE chrome not exercised.
- Unit-test constructors of Camera/Mic controllers set `ignoreDeviceConfig=true` (skips GuardTalk enable-blocked in tests only; production `(Context, key)` ctor does not).

## Bugs found

- None that FAIL F-OS-CAMMIC-SETTINGS static acceptance.
- Residual (not F): policy 3-arg javadoc still claims Settings helper uses `isDeviceLocked` as the lock-screen signal — stale vs this rematch.
- Residual nit (pre-existing AOSP comments): `CameraToggleController` javadoc says “microphone”; `MicToggleController` says “camera”.

## LIVE_DEVICE_CLAIMED

`false`
