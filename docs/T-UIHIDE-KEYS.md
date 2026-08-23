# T-UIHIDE-KEYS — Settings UI hide inventory

**Task:** Hide listed Privacy / Security / System Settings entries from
user-facing UI **and** Settings search. **Do not** delete system APKs/services.

**Date:** 2026-07-25  
**Overlay:** `vendor/guardtalk/overlays/GuardTalkSettingsOverlay`

## Inventory (keys → controllers → bools)

| # | User-facing label | Preference / surface key | Controller / hook | Config bool (overlay=false) |
|---|-------------------|--------------------------|-------------------|-----------------------------|
| 1 | Health and fitness (HC / locale variants e.g. RU «Здоровье и спорт») | Injected IA_SETTINGS tile package `com.android.healthconnect.controller` (`LegacySettingsEntryPoint`) | `GuardTalkPrivacyVisibility` + `DashboardFragment.displayTile` + search `isEligibleForIndexing` | `config_show_health_connect_settings` |
| 2 | Agents | `privacy_app_function_access` | `AppFunctionAccessPreferenceController` + `AppFunctionAccessUtil` | `config_show_app_function_access` |
| 3 | Changes in geodata transmission (EN: Data sharing updates for location) | `privacy_app_data_sharing_updates` | `AppDataSharingUpdatesPreferenceController` | `config_show_app_data_sharing_updates` |
| 4 | Trust agents | `manage_trust_agents` (+ `trust_agent` list / `TrustAgentSettings`) | `ManageTrustAgentsPreferenceController` + `TrustAgentListPreferenceController` + `TrustAgentsPreferenceController` (prior P2) + `TrustAgentSettings` search gate | `config_show_manage_trust_agents` (+ `config_show_trust_agent_click_intent`) |
| 5 | Backup (System site-map) | `backup_data` / `UserBackupSettingsActivity` (parent=`SystemDashboardFragment`) | Prior `F-SYS-HIDE-GESTURE-BACKUP`: `config_show_backup_settings` + `PrivacySettingsUtils.getInvisibleKey` | `config_show_backup_settings` (**already false**) |

## Files touched

- `packages/apps/Settings/res/values/config.xml` — default bools (true)
- `packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkPrivacyVisibility.java` — **new**
- Controllers / util / dashboard / search / TrustAgentSettings (availability + search)
- `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml` — false overrides
- `vendor/guardtalk/docs/SETTINGS_VISIBILITY_POLICY.md` — policy table
- This file

## Before / after

| Target | Before | After |
|--------|--------|-------|
| Health Connect Privacy tile | Visible if HC APK present (often already excised via apex-bcp) | Hidden when overlay false; search injected raw skipped |
| Agents | Shown when App Function flags on | `UNSUPPORTED_ON_DEVICE` / util returns false |
| Geodata sharing updates | Shown when safety-label DeviceConfig on | `UNSUPPORTED_ON_DEVICE` |
| Trust agents | Could still appear via `config_show_manage_trust_agents=true` despite Smart Lock block | Overlay false + Smart Lock block; page search off |
| Backup | Already hidden (F-SYS-HIDE-GESTURE-BACKUP) | Unchanged; confirmed System site-map gated by same bool |

## Non-goals

- No deletion of BackupManager, TrustAgent services, or HealthFitness APEX packages
- No unrelated Settings culls (Phase 2–5 security stack)

## Build

Prefer `lunch <device>-trunk_staging-userdebug && m Settings` when env ready.
Static verification: `rg` keys + overlay bools (see task verification commands).
