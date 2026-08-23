# GuardTalkSettingsOverlay

RRO on `com.android.settings` (`system_ext_specific`, platform cert).

## Current overrides

### Radio / excision grace

- `config_show_sim_info=false`
- `config_show_top_level_connected_devices=false`
- `config_show_data_saver=false`
- `config_wallpaper_picker_package` empty
- `config_show_top_level_accessibility=false`
- `config_show_emergency_settings=false`
- `config_show_private_dns_settings=false`

### T-SEC-P1-SETTINGS / F-SEC-P1-SETTINGS-UI — keep/hide matrix

- `config_use_guardtalk_security_dashboard=true` → GuardTalk Security dashboard
- **KEEP (true):** network, apps, notifications, sound, priority_modes, display,
  storage, battery, system, about_device, security, privacy
- **HIDE (false):** connected_devices, safety_center, location, accounts,
  emergency, accessibility; wallpaper via empty `config_wallpaper_picker_package`
- Security homepage order: `top_level_settings*.xml` places Security after Apps

**API doc:** `vendor/guardtalk/docs/SETTINGS_VISIBILITY_POLICY.md`

### T-SEC-P2-LOCK — password-only device lock

- `config_guardtalk_password_only_lock=true`
- `config_guardtalk_block_smart_lock=true`
- `config_guardtalk_block_biometric_enroll=true`
- `config_hide_none_security_option=true` / `config_hide_swipe_security_option=true`
- Reinforced by `ro.guardtalk.password_only_lock` / `lock_after_reboot` /
  `max_lock_after_timeout_ms` in `guardtalk-tokay.mk`

**API doc:** `vendor/guardtalk/docs/PASSWORD_ONLY_LOCK_POLICY.md`

## Product wiring

```makefile
PRODUCT_PACKAGES += GuardTalkSettingsOverlay
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkSettingsOverlay
```

(Already included via `radio-excised/telephony-features.mk` / feature-excised packages.)

## Related Frontend work (`F-SEC-P1-SETTINGS-UI`)

- ✅ Final Main Settings keep/hide matrix (this overlay)
- ✅ Security immediately after Apps (`packages/apps/Settings/res/xml/top_level_settings*.xml`)
- ✅ Launcher Contacts hide + GT Config/Info keep (`GuardTalkLauncherOverlay`)

## F-SEC-P1-ABOUT-APPS — About / Apps / Network matrices

**About KEEP:** device_name, device_model, firmware, battery, build_number, uptime  
**About HIDE:** branded_account, wifi IP/MAC, manual, legal/safety/regulatory, bt_address, feedback, fcc  
**Apps:** Special access visible but maintenance-gated (`config_apps_special_access_requires_maintenance`); aspect ratio hidden  
**Network KEEP:** Internet/Wi-Fi, Airplane, VPN (under Network & internet only)  
**Network HIDE:** Hotspot (`config_show_wifi_hotspot_settings`), Data Saver, Private DNS, Adaptive  

Dev Options unlock block stays `true`. Never set `config_show_about_build_number=false`.

**API docs:** `ABOUT_PHONE_DEVOPTS_POLICY.md`, `GT_CONFIG_PASSWORD_GATE_API.md`

## F-SEC-P4-SYSTEM-UI — Notifications / Sound / Modes / Display / Storage / Battery / System

**Notifications HIDE:** bubbles, summarization, bundling  
**Sound HIDE:** call volume (radio excised)  
**Modes:** top-level KEEP (no sub-hide)  
**Display HIDE:** Wi‑Fi Display, smooth display (wallpaper already empty pkg)  
**Storage HIDE:** smart storage toggle  
**Battery HIDE:** wireless-charging restrict  
**System HIDE:** gestures (`config_show_gesture_settings`), assist/voice input,
TTS summary, view logs  
**Privacy HIDE:** backup (`config_show_backup_settings` — `backup_data` + related);
Agents; geodata sharing updates; Health Connect (`T-UIHIDE-KEYS`)  
**Security HIDE:** Trust agents (`config_show_manage_trust_agents`)  
**Security:** `config_security_mutations_require_password=true` — mutation rows
require main password via GT Config gate. No network under Security.

### F-SYS-HIDE-GESTURE-BACKUP

- `config_show_gesture_settings=false` — System → Gestures + gesture search pages
- `config_show_backup_settings=false` — Privacy backup_* rows + Backup search index
- Hide ≠ delete BackupManager / gesture services / APKs

### T-UIHIDE-KEYS

- `config_show_app_function_access=false` — Privacy → Agents
- `config_show_app_data_sharing_updates=false` — Privacy → geodata transmission
- `config_show_health_connect_settings=false` — Privacy → Health Connect tile
- `config_show_manage_trust_agents=false` (+ `config_show_trust_agent_click_intent`)
- Backup remains gated by `config_show_backup_settings=false`

### F-UIHIDE-SETTINGS (residual UI polish)

- Overlay `system_dashboard_summary` → `Languages, keyboard, time`
  (removes user-visible "gestures" / "backup" from System parent tile)
- Controllers/bools from T-UIHIDE-KEYS unchanged; no APK deletes

### F-UIHIDE-LOCALE-SUMMARY

- Matching `system_dashboard_summary` overrides in `res/values-*/` for all
  **85** Settings locales that translated the old summary
- EN `values/strings.xml` preserved: `Languages, keyboard, time`
- Docs: `F-UIHIDE-LOCALE-SUMMARY.md`,
  `F-UIHIDE-LOCALE-SUMMARY-translations.json`

**API docs:** `SETTINGS_VISIBILITY_POLICY.md`, `T-UIHIDE-KEYS.md`,
`F-UIHIDE-SETTINGS.md`, `F-UIHIDE-LOCALE-SUMMARY.md`, `FILES_UI_NOTES.md`,
`GT_CONFIG_PASSWORD_GATE_API.md`
