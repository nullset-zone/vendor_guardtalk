# GuardTalk Settings Visibility Policy API

**Task:** `T-SEC-P1-SETTINGS` (Backend) → consumed by `F-SEC-P1-SETTINGS-UI` (Frontend)  
**Date:** 2026-07-22

## Purpose

Drive Main Settings keep/hide and the GuardTalk **Security** category from overlayable
config bools. Hide = UI only (do **not** remove system APKs). Network / VPN / Wi‑Fi /
Hotspot / Airplane stay under **Network & internet**, never under Security.

## Security dashboard skeleton

| Item | Value |
|------|--------|
| Fragment | `com.android.settings.security.guardtalk.GuardTalkSecurityDashboardFragment` |
| Preference XML | `packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml` |
| Enable bool | `config_use_guardtalk_security_dashboard` (`true` in GuardTalkSettingsOverlay) |
| Top-level key | `top_level_security` |
| Wiring | `SecuritySettingsFeatureProviderImpl` + homepage XML fragment |

Stub rows (Phase-2 owns behavior): device lock, sensor privacy, USB protection,
lockdown, auto-reboot, duress, security status, GT Config, GT Info.

## Keep/hide API (overlayable bools)

Override in `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`.

| Preference key | Config bool | Default (Settings) | Overlay (GuardTalk P1) |
|----------------|-------------|--------------------|-------------------------|
| `top_level_network` | `config_show_top_level_network` | true | true |
| `top_level_connected_devices` | `config_show_top_level_connected_devices` | true | false (pre-existing) |
| `top_level_apps` | `config_show_top_level_apps` | true | true |
| `top_level_notifications` | `config_show_top_level_notifications` | true | true |
| `top_level_sound` | `config_show_top_level_sound` | true | true |
| `top_level_priority_modes` | `config_show_top_level_priority_modes` | true | true |
| `top_level_display` | `config_show_top_level_display` | true | true |
| `top_level_wallpaper` | empty `config_wallpaper_picker_package` | (picker pkg) | empty (pre-existing) |
| `top_level_storage` | `config_show_top_level_storage` | true | true |
| `top_level_battery` | `config_show_top_level_battery` | true | true |
| `top_level_system` | `config_show_top_level_system` | true | true |
| `top_level_about_device` | `config_show_top_level_about_device` | true | true |
| `top_level_safety_center` | `config_show_top_level_safety_center` | true | false |
| `top_level_security` | `config_show_top_level_security` | true | true |
| `top_level_privacy` | `config_show_top_level_privacy` | true | true |
| `top_level_location` | `config_show_top_level_location` | true | false |
| `top_level_accounts` | `config_show_top_level_accounts` | true | false |
| `top_level_emergency` | `config_show_emergency_settings` | true | false (pre-existing) |
| `top_level_accessibility` | `config_show_top_level_accessibility` | true | false (pre-existing) |

Shared key constants (SettingsLib):  
`com.android.settingslib.guardtalk.GuardTalkSettingsVisibilityKeys`

Runtime helper (Settings):  
`com.android.settings.guardtalk.GuardTalkSettingsVisibility`

## Frontend contract (`F-SEC-P1-SETTINGS-UI`)

1. Set keep/hide matrix by editing overlay bools only (no APK removal).
2. Place **Security** immediately after **Apps** via preference `android:order` / category
   moves in Settings overlay or XML (Backend left stock category placement).
3. Keep GT Config / GT Info launcher surfaces; Security stub keys
   `guardtalk_gt_config` / `guardtalk_gt_info` are placeholders for later wiring.
4. Do not add network controls under Security.

## Phase-4 sub-matrices (`F-SEC-P4-SYSTEM-UI`)

Top-level categories for Notifications / Sound / Modes / Display / Storage /
Battery / System remain **KEEP**. Sub-item matrices (overlayable bools):

### Notifications

| Item | Config bool | Overlay |
|------|-------------|---------|
| App notifications / history / lock-screen | (stock) | KEEP |
| Bubbles | `config_show_notification_bubbles` | **false** |
| Summarization | `config_show_notification_summarization` | **false** |
| Bundling | `config_show_notification_bundling` | **false** |

### Sound

| Item | Config bool | Overlay |
|------|-------------|---------|
| Media / alarm / notification volumes | `config_show_*_volume` | **true** |
| Notification ringtone / UI sounds | `config_show_notification_ringtone`, `*_sounds` | **true** |
| Call volume | `config_show_call_volume` | **false** (radio excised) |

### Modes (Priority modes)

| Item | Config bool | Overlay |
|------|-------------|---------|
| Top-level Modes | `config_show_top_level_priority_modes` | **true** |
| Zen / Modes pages | (stock) | KEEP (no sub-hide) |

### Display

| Item | Config bool | Overlay |
|------|-------------|---------|
| Brightness / timeout / dark / night / rotate | (stock) | KEEP |
| Wi‑Fi Display cast menu | `config_show_wifi_display_enable_menu` | **false** |
| Smooth display | `config_show_smooth_display` | **false** |
| Wallpaper & style | empty `config_wallpaper_picker_package` | HIDE (P1) |

### Storage

| Item | Config bool | Overlay |
|------|-------------|---------|
| Storage dashboard | `config_show_top_level_storage` | **true** |
| Smart storage toggle | `config_show_smart_storage_toggle` | **false** |

### Battery

| Item | Config bool | Overlay |
|------|-------------|---------|
| Battery dashboard | `config_show_top_level_battery` | **true** |
| Restrict to wireless charging | `config_show_restrict_to_wireless_charging` | **false** |

### System

| Item | Config bool | Overlay |
|------|-------------|---------|
| Languages / updates / reset | `config_show_phone_language`, `*_system_update_*`, `*_reset_*` | **true** |
| Gestures (`gesture_settings`) | `config_show_gesture_settings` | **false** |
| Assist & voice input | `config_show_assist_and_voice_input` | **false** |
| TTS summary | `config_show_tts_settings_summary` | **false** |
| View logs | `config_show_view_logs` | **false** |

### Privacy — Backup (`F-SYS-HIDE-GESTURE-BACKUP`)

| Item | Config bool | Overlay |
|------|-------------|---------|
| Backup data / configure / auto-restore / inactive / management | `config_show_backup_settings` | **false** |
| `UserBackupSettingsActivity` search raw index | same bool (search gate) | **false** |

Hide = UI + Settings search only. BackupManager / transport services / APKs stay installed.
Gestures: `GesturesSettingPreferenceController` + gesture `@SearchIndexable` pages gate on
`config_show_gesture_settings`. Backup: `PrivacySettingsUtils.getInvisibleKey` + related
controllers / search providers gate on `config_show_backup_settings`.

### Security mutations password UX

| Item | Config bool | Overlay |
|------|-------------|---------|
| Gate Security mutation rows | `config_security_mutations_require_password` | **true** |

When true, Device lock / Sensor / USB / Lockdown / Auto-reboot / Duress /
Secure wipe require a GT Config gate session (main device password) before
opening. GT Config itself already used the same confirm→session flow.
**No network / VPN / Wi‑Fi / Hotspot / Airplane under Security.**

## Rollback (Law 11)

1. Set `config_use_guardtalk_security_dashboard=false` (or remove overlay package).
2. Revert homepage fragment to `com.android.settings.security.SecuritySettings` if needed.
3. Restore visibility bools to `true` (or remove overlay overrides).
4. Product boots with stock Settings hierarchy; no persistent state migrations.
