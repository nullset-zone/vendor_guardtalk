# QA Evidence — Q-OS-CAMMIC-TOGGLE

**Task:** `Q-OS-CAMMIC-TOGGLE` (independent rematch of `T-OS-CAMMIC-TOGGLE`)  
**Date:** 2026-09-16T08:30:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-OS-CAMMIC-TOGGLE` APPROVED (Architect 2026-09-16T08:16:00Z)  
**DEC:** DEC-OS-UX-001  
**Verdict:** **PASS (static / host)** — device dumpsys/appops **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited.

GIP-0: loaded `.aegis/governance/laws/` (24 YAML) and `.aegis/governance/gates/` (11 YAML). Gate -1 in-process. Guardian MCP/HTTP not called.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Evidence PASS/FAIL/HOLD + raw command output | **PASS** | this file + `verify_os_cammic_toggle_static.sh` |
| 2 | `ownsLockToggleAuthority` skips AOSP `isDeviceLocked` blanket in `canChangeToggleSensorPrivacy` | **PASS** | skip only when `mGuardTalkHooks == null \|\| !ownsLockToggleAuthority()`; stock drop log remains |
| 3 | `allowUserToggle(true, …)` always true; privacy-OFF rejected when keyguard / `!userUnlocked` / lockdown `0x20` | **PASS** | policy + host truth-table 6/6 + 3 extras |
| 4 | 4-arg `mustDenySensors` does **not** OR stale `deviceLocked` once keyguard dismissed | **PASS** | 4-arg body never references `deviceLocked`; returns `keyguardShowing` after CE unlock |
| 5 | Emergency-call mic and `DISALLOW_*_TOGGLE` still block | **PASS** | emergency check **before** lock skip; DISALLOW mic/cam **after** skip (not bypassed) |
| 6 | No Lockdown QS tile / no HAL re-enable | **PASS** | no `LockdownTile` / `TILE_SPEC="lockdown"`; overlay QS lists have no `lockdown` token; no camera HAL symbols in T files |
| 7 | Host truth-table rematch (unlocked / keyguard / pre-unlock / lockdown) | **PASS** | 6 core + 3 adversarial extras, fail=0 |
| 8 | Unlocked off blocks capture; on allows | **PASS (static persist/AppOps path)** / **HOLD (device capture)** | persist Unchecked after allow; AppOps `toggle OR mustDeny`. adb empty |
| 9 | Locked / lockdown fail-closed; cannot force sensors ON | **PASS (static)** / **HOLD (device)** | privacy-OFF rejected; `mustDeny` true; AppOps force-deny |
| 10 | `adb` dumpsys/appops | **HOLD** | `adb devices` empty list. Do **not** claim device-fixed |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_os_cammic_toggle_static.sh
# RESULT: PASS (static)  PASS_COUNT=32 HOLD_COUNT=1 FAIL=0 EXIT=0
```

`pytest platform/tests` N/A (AOSP framework policy card, not AEGIS Python platform).

## Independent rematch (do not trust T report)

### AOSP lock blanket skip

`SensorPrivacyService.canChangeToggleSensorPrivacy` (L1118–1148):

1. Emergency mic (`isInEmergencyCall`) → `return false` **first**.
2. `requiresAuthentication() && isDeviceLocked(userId)` → drop **only if** `mGuardTalkHooks == null || !ownsLockToggleAuthority()`.
3. `DISALLOW_MICROPHONE_TOGGLE` → `return false`.
4. `DISALLOW_CAMERA_TOGGLE` → `return false`.
5. else `return true`.

`ownsLockToggleAuthority()` is `sensor_privacy_when_locked || lockdown_fail_closed` (LIVE props both `=1` in `guardtalk-product-props.mk`). GuardTalk therefore owns lock toggle authority; AOSP no longer silently drops **privacy-ON** while `isDeviceLocked`.

### allowUserToggle / mustDeny

- Privacy-ON (`enablePrivacy=true`): `allowUserToggle` returns `true` immediately (Settings/QS camera/mic **off** can persist while locked).
- Privacy-OFF: `!mustDenySensors(...)`.
- 4-arg `mustDenySensors(keyguardShowing, deviceLocked, userUnlocked, flags)`:
  - lockdown (`STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN = 0x20`) → deny
  - `!userUnlocked` → deny
  - else `return keyguardShowing`
  - `deviceLocked` **unused** in the 4-arg body (stale TrustManager cannot force-deny once keyguard is dismissed)

Hooks call the 4-arg form with `isKeyguardLocked()` as `keyguardShowing`.

### Host truth-table (policy ON)

| State | keyguard | deviceLocked | userUnlocked | flags | mustDeny | allow ON | allow OFF |
|-------|----------|--------------|--------------|-------|----------|----------|-----------|
| Unlocked | F | F | T | 0 | F | T | T |
| Stale `isDeviceLocked`, keyguard dismissed | F | T | T | 0 | **F** | T | **T** |
| Keyguard showing | T | T | T | 0 | T | T | F |
| Pre-unlock | F | T | F | 0 | T | T | F |
| Lockdown `0x20` | F | F | T | 0x20 | T | T | F |
| Keyguard + lockdown | T | T | T | 0x20 | T | T | F |

Adversarial extras: policy-off does not deny (stock); `lockdown_fail_closed` still denies if `sensor_when_locked` off; 3-arg legacy still ORs `deviceLocked` (Settings helper residual, **not** the T persist path).

### AppOps / persist

- Public `setToggleSensorPrivacy`: `canChange` → `allowToggleChange` → `setToggleSensorPrivacyUnchecked` (persist unchanged once the set is not dropped).
- `effectiveRestriction = toggleEnabled \|\| mustDenySensors` → Camera/Audio clients still force-denied while keyguard / pre-unlock / lockdown even if persisted toggle is off.

### Negatives refuted (static)

| Negative | Result |
|----------|--------|
| Controls still no-op because AOSP `isDeviceLocked` drops privacy-ON | **Refuted** (skip when GuardTalk owns authority) |
| Capture while “off” (unlocked persist dropped) | **Refuted on persist path**; **device capture HOLD** |
| Sensors ON while locked (privacy-OFF accepted / mustDeny false) | **Refuted** (privacy-OFF rejected; AppOps OR mustDeny) |
| Lockdown weakened | **Refuted** (`0x20` still force-denies + airplane path unchanged) |
| HAL re-enable | **Refuted** (no HAL symbols in T files) |
| Lockdown QS tile | **Refuted** (no class/spec; overlay lists lack token) |

Power-menu lockdown action (`GLOBAL_ACTION_KEY_LOCKDOWN`) is **not** a QS tile and is how user lockdown is entered. Out of negative scope.

## Raw command output

### `verify_os_cammic_toggle_static.sh` (EXIT=0)

```text
RESULT: PASS (static)  PASS_COUNT=32 HOLD_COUNT=1 FAIL=0
```

Full host log (suite of record, 2026-09-16T08:30:00Z):

```text
=== Q-OS-CAMMIC-TOGGLE independent rematch ===
ROOT=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree

PASS: present: frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java
PASS: present: frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java
PASS: present: frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java
PASS: present: vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml
PASS: present: vendor/guardtalk/device/tokay/guardtalk-product-props.mk
--- packet rg (sensorprivacy + policy) ---
[rg hits: policy L82/84/101/125/129/138; service L846/847/851/852/887/888/894/895/1118/1129/1131; hooks L46/147/151/157/161/171/183/188/213/219/221/223]

PASS: hooks define ownsLockToggleAuthority
PASS: service consults ownsLockToggleAuthority
PASS: policy defines allowUserToggle
PASS: hooks define allowToggleChange
PASS: service calls allowToggleChange
PASS: AOSP canChangeToggleSensorPrivacy present
PASS: policy defines mustDenySensors
PASS: hooks call mustDenySensors
--- canChangeToggleSensorPrivacy structure ---
STRUCT_PASS: emergency mic check present
STRUCT_PASS: isDeviceLocked blanket present
STRUCT_PASS: ownsLockToggleAuthority skip present
STRUCT_PASS: DISALLOW_MICROPHONE_TOGGLE present
STRUCT_PASS: DISALLOW_CAMERA_TOGGLE present
STRUCT_PASS: emergency BEFORE lock blanket
STRUCT_PASS: lock skip uses ownsLockToggleAuthority AFTER isDeviceLocked
STRUCT_PASS: DISALLOW_* AFTER lock skip (not bypassed)
STRUCT_PASS: skip does not drop when ownsLockToggleAuthority true
PASS: canChangeToggleSensorPrivacy: emergency+DISALLOW still block; lock blanket skipped iff ownsLockToggleAuthority
PASS: stock isDeviceLocked drop log still present (non-GuardTalk path)
STRUCT_PASS: allowUserToggle(enablePrivacy=true) returns true immediately
STRUCT_PASS: allowUserToggle(privacy-OFF) is !mustDenySensors
PASS: allowUserToggle: privacy-ON always; privacy-OFF = !mustDeny
STRUCT_PASS: 4-arg mustDenySensors unused deviceLocked; deny = lockdown | !userUnlocked | keyguardShowing
PASS: 4-arg mustDenySensors does not OR stale deviceLocked
PASS: 3-arg legacy still duplicates deviceLocked (Settings residual, not T persist path)
PASS: STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN = 0x20
PASS: policy isLockdownActive uses USER_LOCKDOWN flag
PASS: hooks read isKeyguardLocked via isKeyguardShowing
PASS: hooks call 4-arg mustDenySensors(keyguardShowing, deviceLocked, ...)
PASS: persist Unchecked path present
PASS: setToggleSensorPrivacy: canChange then allowToggleChange then persist Unchecked
PASS: effectiveRestriction = toggle OR mustDeny
PASS: service AppOps uses effectiveSensorRestriction
PASS: LIVE prop sensor_privacy_when_locked=1
PASS: LIVE prop lockdown_fail_closed=1
--- Lockdown QS ---
PASS: no LockdownTile / TILE_SPEC=lockdown under SystemUI qs/
STRUCT_PASS: quick_settings_tiles_new_default has no lockdown tile (11 tokens)
STRUCT_PASS: quick_settings_tiles_stock has no lockdown tile (33 tokens)
STRUCT_PASS: quick_settings_tiles_default has no lockdown tile (14 tokens)
PASS: GuardTalk SystemUI overlay QS lists have no lockdown tile
PASS: no camera HAL re-enable symbols in policy/hooks/service
--- host truth-table ---
  PASS: unlocked kg=False deviceLocked=False unlocked=True flags=0x0 mustDeny=False allowOn=True allowOff=True expected=(False,True,True)
  PASS: stale_deviceLocked_keyguard_dismissed kg=False deviceLocked=True unlocked=True flags=0x0 mustDeny=False allowOn=True allowOff=True expected=(False,True,True)
  PASS: keyguard_showing kg=True deviceLocked=True unlocked=True flags=0x0 mustDeny=True allowOn=True allowOff=False expected=(True,True,False)
  PASS: pre_unlock kg=False deviceLocked=True unlocked=False flags=0x0 mustDeny=True allowOn=True allowOff=False expected=(True,True,False)
  PASS: lockdown_0x20 kg=False deviceLocked=False unlocked=True flags=0x20 mustDeny=True allowOn=True allowOff=False expected=(True,True,False)
  PASS: keyguard_plus_lockdown kg=True deviceLocked=True unlocked=True flags=0x20 mustDeny=True allowOn=True allowOff=False expected=(True,True,False)
  PASS: policy-off locked does not deny (stock)
  PASS: lockdown_fail_closed denies even if sensor_when_locked off
  PASS: 3-arg residual still ORs deviceLocked (Settings helper; not T persist)
TRUTH_TABLE fail=0
PASS: host truth-table rematch (6 core + 3 adversarial extras)
--- adb ---
List of devices attached
HOLD: adb devices empty — dumpsys/appops not run; not device-fixed

RESULT: PASS (static)  PASS_COUNT=32 HOLD_COUNT=1 FAIL=0
```

### Packet `rg` (re-run, not trusted from T)

Hits as listed above. `LockdownTile|TILE_SPEC = "lockdown"` under `SystemUI/.../qs/` → **empty**.

### `adb devices`

```text
List of devices attached

```

Empty. `dumpsys sensor_privacy` / `cmd appops query-op CAMERA` / `RECORD_AUDIO` **not run**.

## Residuals (not T FAILs)

1. **Settings helper 3-arg** `GuardTalkSensorPrivacyHelper.areSensorsForceDenied` still calls `mustDenySensors(deviceLocked, userUnlocked, flags)`, which duplicates `deviceLocked` as the keyguard signal. Service AppOps use 4-arg. UI disable-reason may still follow stale TrustManager — **F-OS-CAMMIC-SETTINGS / Q-OS-CAMMIC-SETTINGS**, not this card.
2. **AOSP Unchecked paths** (emergency unmute, admin DISALLOW reset, hardware toggle) still bypass `allowToggleChange`. Emergency **user** toggle remains blocked by `canChangeToggleSensorPrivacy`. Pre-existing AOSP, not a T regression.
3. **Device capture** while Settings “off” is **HOLD** until adb.
4. **`m services` / lunch** not in this Q packet; T reported adevtool pin HOLD — not re-claimed as PASS.

## Coverage gaps

- No device: persist after reopen, Camera/Audio capture while off, lockscreen QS forcing sensors ON, lockdown airplane restore.
- No instrumentation / CTS for `SensorPrivacyService`.
- Kotlin QS `impl/sensorprivacy/` not in T target files (Frontend residual).

## PQE Assessment

### PQE Assessment: Code Entropy REDUCED

Unlock vs lockscreen/lockdown is an explicit 4-arg policy + dumpsys instead of a silent AOSP drop. Fail-closed lockdown/`!userUnlocked`/keyguard paths remain. Residual entropy: 3-arg Settings helper; Unchecked AOSP emergency/admin; device unverified.

## Gate 5

### Ultimate Critique Score: Gate 5 HUMAN SKIP (MCP absent; score not fabricated)

Manual self-check (not MCP): acceptance 8 (device HOLD), scope 10, static tests 9, independence 10, adversarial 8, edges 8, footprint 10, bug documentation 8, gaps 7, reversibility 10. Informal only.

## GO / NO-GO

**GO for Architect REVIEW** of T-OS-CAMMIC-TOGGLE static claims.  
**Not device-fixed.** Recommend adb smoke (`dumpsys sensor_privacy`, AppOps CAMERA/RECORD_AUDIO, capture while unlocked-off) before treating OS UX cam/mic as production-closed.
