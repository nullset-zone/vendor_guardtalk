# QA Evidence — Q-REMEDIATE-B3-SENSORS (item 17)

**Task:** `Q-REMEDIATE-B3-SENSORS` (independent rematch of `T-REMEDIATE-B3-SENSORS` + `F-REMEDIATE-B3-SENSORS`)  
**Date:** 2026-09-16T13:48:37Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** T-REMEDIATE-B3-SENSORS APPROVED static + F-REMEDIATE-B3-SENSORS APPROVED static (Architect). **Not trusted.**  
**DEC:** DEC-REMEDIATE-002  
**Verdict:** **PASS (host lunch + static)** — device QS tile visibility **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). **PASS HOLD remains.** OS-UX on-device proof **not folded** (`Q-REMEDIATE-B3-OSUX-DEVICE` BLOCKED).

Independent rematch. Backend and Frontend completion reports were **not trusted**. Product source was not edited. Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP / HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `lunch komodo-trunk_staging-user` (session-only GIT_CONFIG for `vendor/adevtool`; no `set -u` around `source build/envsetup.sh`) | **PASS** | `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user` |
| 2 | `GuardTalkFrameworksBaseOverlay` + `GuardTalkSystemUIOverlay` PRESENT in filtered `PRODUCT_PACKAGES` | **PASS** | lunch dump tokens |
| 3 | `PixelConfigOverlayCommon` ABSENT from filtered packages | **PASS** | drop list + KEEP exclude + lunch token ABSENT |
| 4 | `config_supportsMicToggle` / `config_supportsCamToggle` **true** in GuardTalkFrameworksBaseOverlay (not comments-only) | **PASS** | live `<bool>` after XML comment strip; AOSP defaults still false |
| 5 | GuardTalkSystemUIOverlay QS strings **lead** with `mictoggle`/`cameratoggle` | **PASS** | `new_default` (11 tokens) + `default` (14 tokens); stock still lists both; no lockdown tile |
| 6 | `SensorPrivacyService` `allowToggleChange` lock semantics UNTOUCHED (T-OS-CAMMIC) | **PASS** (structural) / **HOLD** (git working-tree) | method order emergency → lock skip iff `ownsLockToggleAuthority` → DISALLOW; persist still calls `allowToggleChange`. `git diff` HOLD: tree is not a git repo this stamp |
| 7 | Validator `SensorToggleHelper.kt` 4-arg `mustDenySensors` + Settings polarity `accessOn = !privacy` | **PASS** | 4-arg `(keyguardShowing, deviceLocked, userUnlocked, strongAuth)`; persist `!accessOn`; Settings `isChecked = !isSensorBlocked`; views not inverted |
| 8 | `adb devices` empty → device tile visibility HOLD | **HOLD** | empty list. Not device-fixed |
| 9 | Do not fold OS-UX on-device proof | **PASS (process)** | `Q-REMEDIATE-B3-OSUX-DEVICE` remains BLOCKED; not started |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b3_sensors_host.sh
# RESULT: PASS (host)  bash_PASS=29 bash_HOLD=4 bash_FAIL=0 PY_RC=0
# Combined: 82 PASS / 0 FAIL / 5 HOLD  (PY_COUNTS pass=53 fail=0 hold=1)
# EXIT=0
```

`pytest platform/tests`: N/A (AOSP overlays + Validator Kotlin, not AEGIS Python platform).

First suite run: two **verifier** FAILs (whole-file `isDeviceLocked` index; `grep -q` + `pipefail` SIGPIPE on `GuardTalkValidator`). Product rematch of those items was already PASS. Suite tightened. **Not product FAILs.**

## Independent rematch (do not trust T/F)

### Lunch overlays

- `GuardTalkFrameworksBaseOverlay` PRESENT (telephony-features + KEEP).
- `GuardTalkSystemUIOverlay` PRESENT (feature-overlays + KEEP).
- `PixelConfigOverlayCommon` in Wave D drop, not KEEP, ABSENT after filter.
- `GuardTalkValidator` PRESENT (in-app toggles ship). Supporting, not a substitute for device tile visibility.

### Overlay bools

AOSP `frameworks/base/core/res/res/values/config.xml` still `false`/`false`. GuardTalk overlay live XML:

```xml
<bool name="config_supportsMicToggle">true</bool>
<bool name="config_supportsCamToggle">true</bool>
```

Hardware HW toggles not restored true. `config_fingerprintSupportsGestures` not restored true. Pixel overlay not restored.

`SensorPrivacyService.supportsSensorToggle` still reads `R.bool.config_supportsMicToggle` / `config_supportsCamToggle`. QS `CameraToggleTile` / `MicrophoneToggleTile` `isAvailable()` still gates on `supportsSensorToggle`.

### QS lead

`quick_settings_tiles_new_default` and `quick_settings_tiles_default` start with `mictoggle,cameratoggle`. Stock catalog still contains both (not required to lead). No `lockdown` token. PolicyModule still registers `cameratoggle` / `mictoggle`. QS `state.value = !isBlocked`.

### T-OS-CAMMIC lock semantics

`canChangeToggleSensorPrivacy` (extracted method):

1. Emergency mic → `return false` first.
2. `isDeviceLocked` drop **only if** `mGuardTalkHooks == null || !ownsLockToggleAuthority()`.
3. `DISALLOW_MICROPHONE_TOGGLE` then `DISALLOW_CAMERA_TOGGLE`.

Public persist still: `canChange` → `allowToggleChange` → Unchecked. Hooks still 4-arg `allowUserToggle`. Policy 4-arg `mustDenySensors` does not OR stale `deviceLocked`.

### Validator / Settings polarity

- `isAccessOn` = `!isSensorPrivacyEnabled`
- `setAccessOn` persists `setSensorPrivacy(..., !accessOn)`; rejects `accessOn && isEnableBlocked`
- Views: `isChecked = accessOn`; disable when `blocked && !accessOn`
- Settings: `isChecked = !isSensorBlocked`; `setSensorBlocked(..., !isChecked)`
- Settings helper and Validator both 4-arg `mustDenySensors` (not `strongAuth=0`)

### HOLDs (expected)

| HOLD | Why |
|------|-----|
| adb empty | device tile visibility / dumpsys / capture not proven |
| `m` not run | QS APK / overlay not rebuilt this stamp |
| git working-tree | `git diff` rc=129 (not a git repo this path); structural rematch stands |
| PASS HOLD | live not claimed; `Q-REMEDIATE-B3-OSUX-DEVICE` BLOCKED |

## Forbidden / not done

- No product edits except this QA suite under `vendor/guardtalk/docs/qa/`
- No doctrine / governance YAML / secrets / AVB keys
- No USB GO, lock, or wipe of `54111FDAS000GN`
- No git commit / push
- No APPROVED claim
- No live / PASS HOLD lift
- No re-dispatch of `T-OS-CAMMIC-*` / `F-OS-CAMMIC-*`
