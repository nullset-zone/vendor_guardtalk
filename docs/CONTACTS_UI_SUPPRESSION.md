# GuardTalk Contacts UI Suppression

**Task:** `T-SEC-P1-CONTACTS` (Backend)  
**Date:** 2026-07-22

## Purpose

Suppress **Contacts** (`com.android.contacts`) and **Contacts Storage**
(`com.android.providers.contacts`) from user-facing surfaces while keeping both
packages installed for Messenger / system contact APIs.

## Surfaces

| Surface | Mechanism |
|---------|-----------|
| Launcher / all-apps drawer | `GuardTalkLauncherOverlay` `filtered_components` → `PeopleActivity` |
| Settings → Apps → Contacts storage | `ContactsStoragePreferenceController` → `UNSUPPORTED_ON_DEVICE` when hide on |
| Settings search | `ContactsStorageSettings.SEARCH_INDEX_DATA_PROVIDER.isPageSearchEnabled` |
| Show all apps (SPA) | `AllAppListModel.filter` via `GuardTalkContactsVisibility` |
| Manage apps / Show system | `ManageApplications` compound `AppFilter` |
| Default apps (enterprise list) | Skip `EnterpriseDefaultApps.CONTACTS` when hide on |
| Non-system package visibility | `PackageManagerHooks.restrictedVisibilityPackages` includes `com.android.contacts` only (provider stays queryable) |

## Policy API

| Item | Value |
|------|--------|
| Helper | `com.android.settings.guardtalk.GuardTalkContactsVisibility` |
| Overlay bool | `config_guardtalk_hide_contacts_ui` (`true` in `GuardTalkSettingsOverlay`) |
| Package array | `config_guardtalk_hidden_contacts_packages` |
| Product prop | `ro.guardtalk.hide_contacts_ui` (optional reinforcement) |

Default apps (PermissionController) has **no** `ROLE_CONTACTS` row in AOSP
`RoleManager`; enterprise Contacts default row is suppressed above. Contacts is
not presented as a stock Default-apps role.

## Keep installed

`vendor/guardtalk/feature-excised/apps-excised.mk` → `GUARDTALK_APPS_KEEP`
retains `Contacts` + `ContactsProvider`. Do **not** product-filter them out.

## Rollback (Law 11)

1. Set `config_guardtalk_hide_contacts_ui=false` in `GuardTalkSettingsOverlay`
   (or remove the override).
2. Clear `PeopleActivity` from launcher `filtered_components` if restoring icon.
3. Remove `"com.android.contacts"` from `PackageManagerHooks.restrictedVisibilityPackages`.
4. No APK / data migrations; `git revert` of these edits is sufficient.
