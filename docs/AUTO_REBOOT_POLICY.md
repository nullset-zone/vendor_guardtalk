# GuardTalk Auto-Reboot Policy

**Task:** `T-SEC-P2-AUTOREBOOT` (Backend) → consumed by `F-SEC-P2-SECURITY-SCREENS` (Frontend)  
**Date:** 2026-07-22

## Purpose

Enforce GuardTalk Auto-reboot by **extending** GrapheneOS `AutoReboot` /
`ExtSettings.AUTO_REBOOT_TIMEOUT` / `sys.auto_reboot_ctl` — not inventing a
parallel stack:

- **Profiles:** Off, 1 hour, 2 hours, 4 hours, 8 hours
- **Inactivity timer:** measured from the start of lock (keyguard showing)
- **Exclusion windows:** do not reboot during calls, camera/video use, file
  copying, or system updates (recovery is out-of-band)
- Password required after reboot (via existing lock-after-reboot policy)
- **No Auto-reboot Quick Settings tile** in this task (Phase 3 registers it;
  short-press toggle / long-press → Security → Auto-reboot)

Out of scope: wipe, duress, anti-bruteforce engines; QS tile registration.

## Product properties (server)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.auto_reboot_profiles` | `1` | Clamp timeout to GuardTalk profiles; honor exclusion pause/resume |
| `ro.guardtalk.auto_reboot_default_ms` | `28800000` (8h) | Snap target when Global value is not a known profile |

Defined in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.

## Overlayable Settings bool

Override in `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`.

| Bool | Overlay | Effect |
|------|---------|--------|
| `config_guardtalk_auto_reboot_profiles` | `true` | Security row + Auto-reboot picker use GuardTalk profiles |

UI uses **bool OR prop** (fail-closed toward GuardTalk profiles). Server
enforcement uses **props only**.

## Profiles ↔ `Settings.Global` / ExtSettings

Canonical setting: `Settings.Global.AUTO_REBOOT_TIMEOUT`
(`settings_reboot_after_timeout`) via `ExtSettings.AUTO_REBOOT_TIMEOUT`
(**milliseconds**).

| Profile | Value (ms) |
|---------|------------|
| Off | `0` |
| 1 hour | `3600000` |
| 2 hours | `7200000` |
| 4 hours | `14400000` |
| 8 hours | `28800000` |

Unknown values (e.g. GrapheneOS default 18h) are snapped to the nearest allowed
profile (default **8h**) and persisted so Settings and init stay aligned.

## Enforcement layers

```text
Keyguard showing / dismissed
        │
        ▼
AutoReboot.onKeyguardShowingStateChanged (extended)
        │  clamp ExtSettings.AUTO_REBOOT_TIMEOUT → profile
        │  if excluded → sys.auto_reboot_ctl=pause
        │  else → resume (if paused) then arm seconds
        ▼
init property_service (sys.auto_reboot_ctl)
        │  timer / pause(remaining) / resume / on_device_unlocked
        ▼
reboot (CE keys dropped; password required)
```

| Layer | Class | Role |
|-------|-------|------|
| Framework policy | `android.guardtalk.GuardTalkAutoRebootPolicy` | Profiles, clamp, exclusion checks |
| Keyguard hook | `AutoReboot` | Arm / pause / resume `sys.auto_reboot_ctl` |
| Init | `property_service.cpp` | `CLOCK_BOOTTIME_ALARM` + pause/resume remaining |
| SettingsLib keys | `GuardTalkAutoRebootKeys` | Stable bool/prop/pref contract |
| Settings helper | `GuardTalkAutoRebootHelper` | Bool **or** prop (UI) |
| Security row | `GuardTalkAutoRebootPreferenceController` | Status + deep-link to Exploit protection |
| Profile picker | `AutoRebootPrefController` | Off/1h/2h/4h/8h when profiles on |

## Inactivity definition

Matches GrapheneOS: timer runs while **keyguard is showing** (device locked).
Unlock cancels the timer (`on_device_unlocked`). This is the anti-forensic
“inactivity while locked” model from design §12.

## Exclusion windows

While locked, `GuardTalkAutoRebootPolicy.isInExclusionWindow()` is polled
(~30s). If active, framework sets `sys.auto_reboot_ctl=pause` (init stores
remaining boottime seconds). When clear, `resume` restores the countdown;
if nothing was paused, the full profile timeout is armed.

| Exclusion | Detection (best-effort) |
|-----------|-------------------------|
| Calls | `TelecomManager.isInCall()` / `AudioManager` in-call modes |
| Video recording / active camera | AppOps `OP_CAMERA` / `OP_RECORD_AUDIO` running |
| File copying | AppOps `OP_WRITE_EXTERNAL_STORAGE` / `OP_MANAGE_EXTERNAL_STORAGE` running |
| System updates | `SystemUpdateManager` status waiting/in-progress/reboot |
| Recovery operations | N/A in system_server (not running in recovery) |

Fail-open on missing services (do not block reboot forever).

## Frontend contract (`F-SEC-P2-SECURITY-SCREENS`)

1. **Auto-reboot row** (`guardtalk_security_auto_reboot`) is live — shows Off /
   Nh profile summary; opens Exploit protection (Auto reboot picker).
2. Picker must offer **only** Off / 1h / 2h / 4h / 8h when
   `config_guardtalk_auto_reboot_profiles=true`.
3. **Do not** register an Auto-reboot Quick Settings tile here — Phase 3
   (`T-SEC-P3-QS`) owns catalog + short-press enable/disable + long-press open.
4. Gate mutations with `GuardTalkConfigMutations.SECURITY_AUTO_REBOOT`.
5. Full Security screen polish remains Frontend-owned.

### Suggested UI copy

- Off: “Off — device will not auto-reboot while locked”
- On: “Reboots after N hours of inactivity while locked”
- Footer: pauses during calls, camera/video, file copy, system updates;
  password required after reboot

### QS tile (Phase 3 — API-ready)

| Action | Behavior |
|--------|----------|
| Short press | Toggle selected profile Off ↔ last non-Off (or default 8h) via `ExtSettings.AUTO_REBOOT_TIMEOUT` |
| Long press | Open Security → Auto-reboot / Exploit protection Auto reboot |

## Fail-closed / fail-open rules

1. Missing / unset props on non-GuardTalk builds ⇒ stock GrapheneOS Auto-reboot
   (full timeout list, no exclusion pause).
2. On GuardTalk (`auto_reboot_profiles=1`): timeouts outside the five profiles
   are snapped before arming.
3. Exclusion check exceptions ⇒ treat as **not** excluded (avoid stuck pause).
4. Init still refuses to start a timer until the device has unlocked at least
   once (GrapheneOS behavior preserved).

## Rollback (Law 11)

1. Set / remove in `guardtalk-tokay.mk`:
   - `ro.guardtalk.auto_reboot_profiles=0` (or remove)
   - remove `ro.guardtalk.auto_reboot_default_ms`
2. Set overlay bool `config_guardtalk_auto_reboot_profiles` to `false`.
3. Revert `AutoReboot.java` / init `pause`/`resume` / Settings controllers if a
   full code rollback is needed.
4. Rebuild: `m services Settings -j$(nproc)` (and `m init` if init changed).

No irreversible state: Global timeout and sysprops are runtime-reversible.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```

### Runtime checks (device)

```bash
getprop ro.guardtalk.auto_reboot_profiles   # expect 1
settings get global settings_reboot_after_timeout
# While locked + in call: logcat -s AutoReboot GuardTalkAutoReboot
# expect pause; after call ends expect resume/arm
```
