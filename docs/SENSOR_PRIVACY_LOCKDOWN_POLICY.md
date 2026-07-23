# GuardTalk Sensor Privacy + Lockdown Policy

**Task:** `T-SEC-P2-SENSOR` (Backend) → consumed by `F-SEC-P2-SECURITY-SCREENS` (Frontend)  
**Date:** 2026-07-22

## Purpose

Enforce fail-closed mic/camera sensor privacy and lockdown on GuardTalk products:

- Microphone and camera are **denied** while the device is locked
- Microphone and camera are **denied** before first unlock after boot (CE locked)
- Lockdown (power menu or Security row) forces sensors denied + network fail-closed
- No Lockdown Quick Settings tile (Phase 3 catalogs Mic/Camera only among new tiles)

Out of scope (later Phase-2 tasks): USB protection, auto-reboot, wipe, duress.

## Product properties (server fail-closed)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.sensor_privacy_when_locked` | `1` | AppOps restrict mic/camera when locked or `!isUserUnlocked` |
| `ro.guardtalk.lockdown_fail_closed` | `1` | On `STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN`: sensors denied + airplane mode |

Defined in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.

If `lockdown_fail_closed` is unset, it is implied when `sensor_privacy_when_locked=1`.

## Overlayable Settings bools

Override in `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`.

| Bool | Overlay | Effect |
|------|---------|--------|
| `config_guardtalk_sensor_privacy_when_locked` | `true` | Security row summaries / helper treat policy as on |
| `config_guardtalk_lockdown_fail_closed` | `true` | Lockdown row ready/active copy |

UI uses **bool OR prop** (fail-closed toward restriction). Server enforcement uses **props only**.

## Enforcement layers

```text
Keyguard lock / USER_UNLOCKED / StrongAuth lockdown
        │
        ▼
GuardTalkSensorPrivacyHooks (SensorPrivacyService)
        │  effectiveRestriction = toggle OR mustDeny
        ▼
AppOpsManagerInternal.setGlobalRestriction (mic + camera ops)
        │
        ▼
Camera / Audio clients denied (MODE_IGNORED)

Lockdown enter (STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN)
        │
        ├── sensors force-denied (above)
        └── airplane mode ON (restore prior on exit) — fail-closed network
```

| Layer | Class | Role |
|-------|-------|------|
| Framework policy | `android.guardtalk.GuardTalkSensorPrivacyPolicy` | Prop readers + mustDeny rules |
| Service hooks | `com.android.server.sensorprivacy.GuardTalkSensorPrivacyHooks` | Listeners + AppOps + network |
| SettingsLib keys | `com.android.settingslib.guardtalk.GuardTalkSensorPrivacyKeys` | Stable bool/prop/pref contract |
| Settings helper | `com.android.settings.guardtalk.GuardTalkSensorPrivacyHelper` | Bool **or** prop (UI) |
| Sensor privacy row | `GuardTalkSensorPrivacyPreferenceController` | Status + Privacy Settings deep-link |
| Lockdown row | `GuardTalkLockdownPreferenceController` | Triggers lockdown (not a QS tile) |

Persisted mic/camera toggle state is **not** overwritten on lock — only AppOps restrictions are forced. After unlock, the user’s prior toggle preference applies again.

## Frontend contract (`F-SEC-P2-SECURITY-SCREENS`)

1. **Sensor privacy row** (`guardtalk_security_sensor_privacy`) is live — shows policy/locked summaries; opens platform Privacy settings for manual toggles when unlocked.
2. **Lockdown row** (`guardtalk_security_lockdown`) is live — activates platform lockdown (`requireStrongAuth(LOCKDOWN)` + `lockNow`). Exit by password unlock (clears strong-auth flag).
3. **Do not** register a Lockdown Quick Settings tile. Phase 3 owns Mic/Camera/Battery Saver/Auto-reboot tiles only.
4. Manual mic/camera toggles (QS/Settings) cannot turn sensors **on** while locked, pre-first-unlock, or in lockdown (framework rejects).
5. Gate mutations that change sensor/lockdown policy with:
   - `GuardTalkConfigMutations.SECURITY_SENSOR_PRIVACY`
   - `GuardTalkConfigMutations.SECURITY_LOCKDOWN`
6. Full Security screen polish remains Frontend-owned; Backend provides policy hooks + status rows.

### Suggested UI copy

- Sensor summary (policy): “Microphone and camera stay off while locked and before first unlock.”
- Sensor summary (active deny): “Sensors off (device locked or awaiting first unlock).”
- Lockdown ready: “Locks device; mic, camera, and network stay off until password unlock.”
- Lockdown active: “Active — unlock with password to exit.”

## Fail-closed rules

1. Missing / unset props on non-GuardTalk builds ⇒ policy **off** (stock behavior).
2. On GuardTalk (`sensor_privacy_when_locked=1`):
   - `!UserManager.isUserUnlocked` ⇒ mic/camera restricted
   - `KeyguardManager.isDeviceLocked` ⇒ mic/camera restricted
3. Lockdown (`lockdown_fail_closed=1` or implied): strong-auth lockdown ⇒ sensors restricted + airplane ON.
4. If Keyguard/UserManager unavailable while policy on ⇒ treat as locked (deny).
5. Network restore failure on lockdown exit ⇒ leave airplane on (fail-closed).
6. UI hide alone is insufficient — `SensorPrivacyService` AppOps path is the authority.
7. No HAL change required for this task; AppOps global restriction is sufficient. HAL hooks may be added later if needed.

## Rollback (Law 11)

1. Set props to `0` / remove overrides in `guardtalk-tokay.mk`:
   - `ro.guardtalk.sensor_privacy_when_locked=0`
   - `ro.guardtalk.lockdown_fail_closed=0`
2. Set overlay bools `config_guardtalk_sensor_privacy_when_locked` and
   `config_guardtalk_lockdown_fail_closed` to `false`.
3. Revert `GuardTalkSensorPrivacyHooks` call sites in `SensorPrivacyService` and
   Settings preference controllers / dashboard XML rows to stubs.
4. Rebuild: `m services Settings -j$(nproc)`.

No irreversible state: airplane restore uses in-memory prior value; persisted sensor toggles untouched.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```

Symbol check:

```bash
rg -n "GuardTalkSensorPrivacyPolicy|GuardTalkSensorPrivacyHooks|GuardTalkSensorPrivacyPreferenceController|GuardTalkLockdownPreferenceController" \
  frameworks/base packages/apps/Settings vendor/guardtalk
```
