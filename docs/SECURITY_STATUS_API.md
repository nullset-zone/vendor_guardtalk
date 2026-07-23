# GuardTalkOS Security Status API

**Task:** `T-SEC-P5-STATUS` (Backend) → consumed by `F-SEC-P5-STATUS-UI` (Frontend)  
**Date:** 2026-07-23  
**Target:** Pixel 9 (`tokay`)

## Purpose

Document the **post-unlock** Security status data sources for Settings / Frontend.
Aggregates Phase-2/4/5 GuardTalk policies into one snapshot. Extends existing
helpers — **no parallel stack**.

## Hard rules

| Rule | Detail |
|------|--------|
| Post-unlock only | Status screen / search / summaries require CE unlocked **and** device not keyguard-locked |
| No Duress leakage | **Never** expose Duress armed/status on lock screen, status shell, or pre-unlock surfaces |
| No network rows | VPN / Wi‑Fi / Hotspot / Airplane must not appear under Security status |
| Fail-closed gate | Missing `UserManager` / `KeyguardManager` ⇒ status denied |

Duress setup remains on the Security **dashboard** (`guardtalk_security_duress`) with
generic copy only — not on the status page and not on the lock screen.

---

## Entry points

| Layer | Class | Role |
|-------|-------|------|
| Framework | `android.guardtalk.GuardTalkSecurityStatus` | Aggregate + `Snapshot`; post-unlock gate |
| Framework policies | `GuardTalk*Policy` (lock/sensor/USB/auto-reboot/wipe/privacy/files/hardening) | Prop-backed sources |
| Services | `com.android.server.guardtalk.GuardTalkSecurityStatusAggregator` | Thin system_server delegate |
| SettingsLib keys | `com.android.settingslib.guardtalk.GuardTalkSecurityStatusKeys` | Preference key contract |
| Settings helper | `com.android.settings.guardtalk.GuardTalkSecurityStatusHelper` | Overlay-aware `collect()` |
| Settings UI stub | `GuardTalkSecurityStatusFragment` | Binds summaries (polish = Frontend) |
| Dashboard entry | `GuardTalkSecurityStatusPreferenceController` | Opens status; gated post-unlock |

---

## Post-unlock gate

```java
boolean ok = GuardTalkSecurityStatusHelper.isPostUnlockStatusAllowed(context);
// Equivalent: GuardTalkSecurityStatus.isPostUnlockStatusAllowed(context)
```

Semantics:

1. `UserManager.isUserUnlocked(userId)` must be true (CE unlocked).
2. `KeyguardManager.isDeviceLocked(userId)` must be false.
3. Otherwise return false / `Snapshot.denied()` and **do not** bind status rows.

`GuardTalkSecurityStatusFragment` finishes itself when the gate fails (onCreate /
onResume). Search indexing uses the same gate.

---

## Snapshot contract

```java
GuardTalkSecurityStatus.Snapshot s =
        GuardTalkSecurityStatusHelper.collect(context);
if (!s.postUnlockAllowed) {
    // Hide / finish — do not render fields
}
```

### Fields (no Duress)

| Field | Type | Meaning |
|-------|------|---------|
| `postUnlockAllowed` | boolean | Gate result |
| `passwordOnlyLock` | boolean | Password-only lock policy (overlay \|\| prop) |
| `sensorPrivacyPolicy` | boolean | Mic/camera deny-when-locked policy |
| `sensorsForceDenied` | boolean | Sensors currently force-denied |
| `usbProtectionPolicy` | boolean | USB fail-closed policy |
| `usbDataForceDenied` | boolean | USB data currently denied |
| `lockdownFailClosed` | boolean | Lockdown fail-closed policy |
| `lockdownActive` | boolean | User lockdown strong-auth active |
| `autoRebootProfiles` | boolean | Auto-reboot profiles enabled |
| `autoRebootHours` | int | Hours when on; `0` = Off / unknown |
| `secureWipeAvailable` | boolean | Shared secure wipe engine available |
| `antiBruteforceThreshold` | int | Wipe after N HW failures; `0` = off |
| `privacyTmpfs` | boolean | `ro.guardtalk.privacy_tmpfs` |
| `clipboardClear` | boolean | `ro.guardtalk.clipboard_clear` |
| `clipboardClearTimeoutMs` | long | Clipboard auto-clear timeout |
| `filesPolicy` | boolean | Files policy master |
| `filesTrash` | boolean | Trash enabled under files policy |
| `filesCriticalProtect` | boolean | Critical path protect |
| `productionHardening` | boolean | Hardening master prop |
| `productionProfile` | boolean | `ro.guardtalk.production_profile` (user lunch) |
| `debuggableOff` | boolean | `!ro.debuggable` |
| `blockUnknownSources` | boolean | Unknown-source install block |

**Intentionally absent:** `duressArmed`, `duressConfigured`, or any Duress state.

### Framework-only helpers

| Method | Use |
|--------|-----|
| `GuardTalkSecurityStatus.collectPolicyMarkers()` | Prop markers without runtime deny (diagnostics) |
| `GuardTalkSecurityStatus.collect(ctx, requirePostUnlock, …)` | Services path with runtime flags |
| `Snapshot.denied()` | Pre-unlock empty aggregate |
| `Snapshot.create(…)` | Settings overlay-aware assembly |

---

## Preference keys (`GuardTalkSecurityStatusKeys`)

| Constant | Key | Status row |
|----------|-----|------------|
| `PREF_SECURITY_STATUS` | `guardtalk_security_status` | Dashboard entry |
| `PREF_STATUS_DEVICE_LOCK` | `guardtalk_status_device_lock` | Device lock |
| `PREF_STATUS_SENSOR_PRIVACY` | `guardtalk_status_sensor_privacy` | Sensor privacy |
| `PREF_STATUS_USB_PROTECTION` | `guardtalk_status_usb_protection` | USB protection |
| `PREF_STATUS_LOCKDOWN` | `guardtalk_status_lockdown` | Lockdown |
| `PREF_STATUS_AUTO_REBOOT` | `guardtalk_status_auto_reboot` | Auto-reboot |
| `PREF_STATUS_ANTI_BRUTEFORCE` | `guardtalk_status_anti_bruteforce` | Anti-bruteforce |
| `PREF_STATUS_SECURE_WIPE` | `guardtalk_status_secure_wipe` | Wipe availability |
| `PREF_STATUS_CLIPBOARD` | `guardtalk_status_clipboard` | Clipboard clear |
| `PREF_STATUS_PRIVACY_TMPFS` | `guardtalk_status_privacy_tmpfs` | privacy_tmpfs |
| `PREF_STATUS_FILES` | `guardtalk_status_files` | Files policy |
| `PREF_STATUS_HARDENING` | `guardtalk_status_hardening` | Production hardening |
| `PREF_STATUS_FOOTER` | `guardtalk_status_footer` | Footer (no Duress note) |

XML: `packages/apps/Settings/res/xml/guardtalk_security_status.xml`

---

## Source mapping

| Status area | Primary source |
|-------------|----------------|
| Device lock | `GuardTalkLockPolicyHelper` / `GuardTalkLockPolicy` |
| Sensors | `GuardTalkSensorPrivacyHelper` / `GuardTalkSensorPrivacyPolicy` |
| USB | `GuardTalkUsbProtectionHelper` / `GuardTalkUsbProtectionPolicy` |
| Lockdown | Sensor helper + strong-auth flags |
| Auto-reboot | `GuardTalkAutoRebootHelper` / `GuardTalkAutoRebootPolicy` |
| Anti-bruteforce | `GuardTalkSecureWipeHelper` / `GuardTalkSecureWipePolicy` |
| Secure wipe availability | same wipe helper/policy (**not** Duress armed) |
| privacy_tmpfs / clipboard | `GuardTalkPrivacyPolicy` |
| Files | `GuardTalkFilesPolicy` |
| Hardening | `GuardTalkProductionHardeningPolicy` |

Related docs: `PASSWORD_ONLY_LOCK_POLICY.md`, `SENSOR_PRIVACY_LOCKDOWN_POLICY.md`,
`USB_PROTECTION_POLICY.md`, `AUTO_REBOOT_POLICY.md`, `SECURE_WIPE_SERVICE.md`,
`DURESS_AND_ANTI_BRUTEFORCE_POLICY.md`, `PRIVACY_TMPFS_CLIPBOARD_POLICY.md`,
`FILES_HANDLERS_POLICY.md`, `PRODUCTION_HARDENING_POLICY.md`.

---

## Frontend guidance (`F-SEC-P5-STATUS-UI`)

1. Call `GuardTalkSecurityStatusHelper.isPostUnlockStatusAllowed` before showing.
2. Bind rows from `collect()` — prefer keys in `GuardTalkSecurityStatusKeys`.
3. **Do not** query `isDuressArmed` / Duress credential APIs for status UI.
4. Anti-bruteforce row: hide when `antiBruteforceThreshold <= 0`.
5. Hardening: distinguish production profile vs engineering markers (strings already stubbed).
6. Polish copy/layout only — do not invent a second aggregator.

---

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```

Static checks:

```bash
rg -n 'duress|isDuressArmed' \
  frameworks/base/core/java/android/guardtalk/GuardTalkSecurityStatus.java \
  packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSecurityStatusHelper.java \
  packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityStatusFragment.java \
  packages/apps/Settings/res/xml/guardtalk_security_status.xml
# Expect: no Duress status fields (footer string may mention "never shown")
```

---

## Rollback

1. Revert:
   - `frameworks/base/core/java/android/guardtalk/GuardTalkSecurityStatus.java`
   - `frameworks/base/services/core/java/com/android/server/guardtalk/GuardTalkSecurityStatusAggregator.java`
   - `frameworks/base/packages/SettingsLib/.../GuardTalkSecurityStatusKeys.java`
   - Settings helper / fragment / `guardtalk_security_status.xml` / status strings
   - This doc
2. Prior Phase-2 status shell (device lock / sensors / USB / lockdown / auto-reboot /
   anti-bruteforce) remains usable from older helpers if fragment is restored to
   the F-SEC-P2 binding style.
3. No persistent Settings provider schema; no data migration.
4. Product still boots; Security dashboard Duress/wipe rows unchanged.

---

## Acceptance checklist

- [x] Post-unlock aggregate status sources implemented
- [x] No Duress field / lockscreen leakage in status API
- [x] Frontend doc + rollback
- [x] `m services Settings -j$(nproc)` green (EXIT=0; Settings.apk + services.jar; adevtool pin restored)
