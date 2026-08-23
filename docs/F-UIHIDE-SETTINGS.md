# F-UIHIDE-SETTINGS — Settings XML / dashboard / search UI polish

**Task:** Residual UI polish for listed Privacy / Security / System hides after
`T-UIHIDE-KEYS` (APPROVED). Controllers + overlay bools already hide targets;
this task fixes search-facing / parent dashboard copy only.

**Date:** 2026-07-25  
**Depends on:** `T-UIHIDE-KEYS`  
**QA pair:** `Q-UIHIDE-SETTINGS`

## Alignment with T-UIHIDE-KEYS (no rework)

| # | Label | Overlay bool | Status |
|---|-------|--------------|--------|
| 1 | Health and fitness | `config_show_health_connect_settings=false` | Controllers + `GuardTalkPrivacyVisibility` (Backend) |
| 2 | Agents | `config_show_app_function_access=false` | Controller gate (Backend) |
| 3 | Geodata transmission updates | `config_show_app_data_sharing_updates=false` | Controller gate (Backend) |
| 4 | Trust agents | `config_show_manage_trust_agents=false` | Controller + search page gate (Backend) |
| 5 | Backup | `config_show_backup_settings=false` | Prior F-SYS-HIDE; search raw gated |

## Frontend delta

| File | Change |
|------|--------|
| `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/strings.xml` | `system_dashboard_summary` → `Languages, keyboard, time` |
| `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/README.md` | Document F-UIHIDE-SETTINGS |
| `vendor/guardtalk/docs/SETTINGS_VISIBILITY_POLICY.md` | Parent dashboard summary table |
| This file | Notes for Architect / QA |

## Parent + search-facing copy audit

| Surface | Mentions hidden targets? | Action |
|---------|--------------------------|--------|
| System tile (`system_dashboard_summary`) | Was: gestures, backup | **Fixed** via overlay |
| Privacy tile (`privacy_dashboard_summary`) | No (Permissions, account activity, personal data) | None |
| Security tile (`security_dashboard_summary`) | No (Screen lock, Find My Device, app security) | None |
| More security & privacy summary | No (Autofill, notifications, and more) | None |
| Preference titles in XML | Still present in APK resources | Expected — controllers set `UNSUPPORTED_ON_DEVICE` / non-indexable |

## Non-goals

- No deletion of Backup / Trust / Health APKs or services
- No unrelated Settings culls
- No branding (see `F-BRAND-UI`)
- No controller logic rework unless clear bug (none found)

## Residuals for Q-UIHIDE-SETTINGS

1. **Localized System summaries:** `packages/apps/Settings/res/values-*/strings.xml`
   still translate the old "Languages, gestures, time, backup" string. Overlay
   covers default `values/` only. Non-English locales may still show
   gesture/backup words on the System parent tile until locale RROs or base
   string updates (out of minimal F footprint).
2. **String resources retained:** Titles like `manage_trust_agents`,
   `app_function_access_settings_title`, `backup_data_title`,
   `keywords_backup` remain in the APK for reversibility; they must not appear
   in UI/search when overlay bools are false (Backend gates).
3. **Device smoke:** Confirm on flashed image that Settings search for
   "Backup", "Trust agents", "Agents", "Health", "Data sharing" does not
   surface the five targets.
4. **Sound Prevent Ringing:** Prior accepted residual from F-SYS-HIDE
   (not in this five-target list).

## Verification (static)

```bash
rg -n "config_show_health_connect|config_show_app_function|config_show_app_data_sharing|config_show_manage_trust|config_show_backup" \
  vendor/guardtalk/overlays/GuardTalkSettingsOverlay packages/apps/Settings/res
rg -n "system_dashboard_summary" \
  vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/strings.xml
```

## Rollback (Law 11)

Remove the `system_dashboard_summary` override from the overlay strings.xml
(or restore prior value) and rebuild the overlay / product image.
