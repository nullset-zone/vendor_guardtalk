# QA Evidence — Q-SEC-P1-CONTACTS

**Task:** `Q-SEC-P1-CONTACTS`  
**Date:** 2026-07-22  
**Agent:** QA_ENGINEER  
**Depends:** T-SEC-P1-CONTACTS ✅, F-SEC-P1-SETTINGS-UI ✅  
**Verdict:** PASS (static + artifact smoke) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| API doc present | PASS | `vendor/guardtalk/docs/CONTACTS_UI_SUPPRESSION.md` |
| `GuardTalkContactsVisibility` + overlay hide=true | PASS | Helper + `GuardTalkSettingsOverlay` `config_guardtalk_hide_contacts_ui=true` |
| Launcher `filtered_components` → PeopleActivity | PASS | `GuardTalkLauncherOverlay` + tokay overlay APK `resources.arsc` |
| `PackageManagerHooks` = `com.android.contacts` only | PASS | Source + `services.jar` has contacts string, **0** providers.contacts |
| apps-excised KEEP Contacts/ContactsProvider | PASS | `GUARDTALK_APPS_KEEP`; not in drop list; restore filter present |
| Settings Apps/search/Show-all/Default-apps hooks | PASS | Controllers + AllAppList + ManageApplications + Enterprise list |
| Packages not removed | PASS | KEEP + no APK excision of Contacts modules |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_p1_static.sh
# ALL STATIC CHECKS PASSED (SETTINGS/DEVOPTS + 12 CONTACTS checks)
```

## Artifact smoke (prior tokay build; no fresh `m`)

| Artifact | Finding |
|----------|---------|
| `Settings.apk` | `GuardTalkContactsVisibility`×2, `config_guardtalk_hide_contacts_ui`×2, both package names present |
| `services.jar` | `com.android.contacts`×1, `restrictedVisibilityPackages`×1, `com.android.providers.contacts`×0 |
| `GuardTalkLauncherOverlay.apk` | full component string in `resources.arsc` |
| `GuardTalkSettingsOverlay.apk` | `config_guardtalk_hide_contacts_ui` in `resources.arsc` |

## Adversarial notes

| Case | Result |
|------|--------|
| ContactsProvider in restrictedVisibilityPackages | FAIL would break Messenger; **not present** |
| Contacts/ContactsProvider in GUARDTALK_APPS_PACKAGES drop | **not present**; KEEP + restore |
| Extra LAUNCHER aliases on Contacts | Only `PeopleActivity` has LAUNCHER; aliases have no LAUNCHER category |
| Optional `ro.guardtalk.hide_contacts_ui` product prop | **WARN** — not set in tokay.mk; overlay bool is primary (doc: optional) |
| Runtime launcher/settings UI absence | **SKIP** — `adb devices` empty |

## Coverage gaps

- Device UI smoke (all-apps drawer, Settings search, Show system) deferred until adb device available
- PermissionController default-apps role row: no `ROLE_CONTACTS` in AOSP RoleManager (doc claim; static grep empty) — enterprise row covered
