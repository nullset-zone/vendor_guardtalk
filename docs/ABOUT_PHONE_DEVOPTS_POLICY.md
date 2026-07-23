# GuardTalk About-phone + Developer Options Policy

**Task:** `T-SEC-P1-DEVOPTS` (Backend) → consumed by `F-SEC-P1-ABOUT-APPS` / `Q-SEC-P1-DEVOPTS`  
**Date:** 2026-07-22

## Purpose

1. Provide About-phone field keep/hide hooks (overlayable config bools).
2. Keep **Build number** visible.
3. Ensure **seven taps** on Build number do **not** unlock Developer Options under GuardTalk policy.
4. Document **userdebug** vs **user/production** behavior.

## Developer Options unlock block

| Mechanism | Location | GuardTalk value |
|-----------|----------|-----------------|
| Settings config bool | `config_guardtalk_block_developer_options_unlock` | `true` (overlay) |
| Product property | `ro.guardtalk.block_developer_options` | `1` (tokay `guardtalk-tokay.mk`) |
| Runtime helper | `com.android.settings.guardtalk.GuardTalkDeveloperOptionsPolicy` | blocks if bool **or** prop |

### Enforcement points (Settings)

| Surface | Behavior when blocked |
|---------|------------------------|
| `BuildNumberPreferenceController` | Preference stays available (Build number visible); taps are consumed and never call `DevelopmentSettingsEnabler.setDevelopmentSettingsEnabled(true)` |
| `DeveloperOptionsController` (System) | Preference stays `CONDITIONALLY_UNAVAILABLE` / hidden |
| `DevelopmentSettingsDashboardFragment` | `onCreate` finishes; search indexing off; `enableDeveloperOptions()` no-ops |

## About-phone keep/hide hooks

Override in `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`.

Runtime helper: `com.android.settings.guardtalk.GuardTalkAboutPhoneVisibility`

| Preference key (`my_device_info.xml`) | Config bool | Default (Settings) | Overlay (GuardTalk P1) |
|--------------------------------------|-------------|--------------------|-------------------------|
| `device_name` | `config_show_device_name` | true | (inherit / Frontend) |
| `branded_account` | `config_show_branded_account_in_device_info` | true | (inherit / Frontend) |
| `phone_number` / `sim_status` / `eid_info` / `imei_info` | `config_show_sim_info` | false (radio excised) | false |
| `device_model` | `config_show_device_model` | true | (inherit / Frontend) |
| `firmware_version` | `config_show_about_firmware_version` | true | true |
| `battery_info` | `config_show_about_battery_info` | true | true |
| `wifi_ip_address` | `config_show_wifi_ip_address` | true | (inherit / Frontend) |
| `wifi_mac_address` / factory MAC | `config_show_wifi_mac_address` | true | (inherit / Frontend) |
| `manual` | `config_show_manual` | (AOSP) | (inherit / Frontend) |
| **`build_number`** | **`config_show_about_build_number`** | **true** | **true (MUST keep)** |

Keys without a dedicated bool (e.g. `legal_container`, `regulatory_info`, `bt_address`, `up_time`) fail open via the helper and may be hidden by Frontend XML overlays in `F-SEC-P1-ABOUT-APPS`.

## userdebug vs user / production

| Profile | Lunch / Build.TYPE | `ro.debuggable` (typical) | GuardTalk Settings policy | Notes |
|---------|--------------------|---------------------------|---------------------------|-------|
| **userdebug** (eng/dev) | `tokay-trunk_staging-userdebug` | `1` | Unlock blocked (overlay + prop) | ADB/root tooling may still exist for engineering; Settings UI path cannot unlock Dev Options via Build taps. Full ADB/USB lockdown is Phase-2/5. |
| **user** (production path) | `tokay-*-user` (P5) | `0` | Unlock blocked (same overlay + prop) | Defense-in-depth with production hardening (`T-SEC-P5-HARDEN`: no `ro.debuggable=1`, release keys, SELinux Enforcing). |

Settings policy is **independent** of `ro.debuggable`: even on userdebug images used for development builds, Build-number taps never enable Developer Options when GuardTalk policy is on.

## Frontend contract (`F-SEC-P1-ABOUT-APPS`)

1. Flip About keep/hide bools in `GuardTalkSettingsOverlay` only (no APK removal).
2. **Never** set `config_show_about_build_number=false`.
3. Keep `config_guardtalk_block_developer_options_unlock=true`.
4. Do not edit `top_level_settings*.xml` ordering here (owned by `F-SEC-P1-SETTINGS-UI`).

## Rollback (Law 11)

1. Set overlay `config_guardtalk_block_developer_options_unlock=false`.
2. Remove `ro.guardtalk.block_developer_options=1` from `guardtalk-tokay.mk` (or set `0`).
3. Restore About field bools as needed.
4. Rebuild Settings / flash; no persistent Settings.Global migration required for the block itself (tap path never wrote enable when blocked).
