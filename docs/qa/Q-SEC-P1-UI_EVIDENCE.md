# QA Evidence — Q-SEC-P1-UI

**Task:** `Q-SEC-P1-UI` (final Phase-1 QA)  
**Date:** 2026-07-22  
**Agent:** QA_ENGINEER  
**Depends:** F-SEC-P1-SETTINGS-UI ✅, F-SEC-P1-ABOUT-APPS ✅  
**Verdict:** PASS (static + artifact smoke) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Security immediately after Apps | PASS | `top_level_settings.xml` + `_expressive.xml`: apps `order=-60`, security `order=-55`; fragment `GuardTalkSecurityDashboardFragment` |
| No network under Security | PASS | `guardtalk_security_dashboard.xml` has no wifi/vpn/hotspot/airplane prefs; Network top-level `config_show_top_level_network=true` |
| Main Settings keep/hide | PASS | Overlay KEEP: network/apps/notifications/sound/priority_modes/display/storage/battery/system/about/security/privacy; HIDE: connected_devices/safety_center/location/accounts/emergency/accessibility |
| About phone matrix | PASS | KEEP: device_name/model/firmware/battery/build_number/uptime; HIDE: branded_account, wifi IP/MAC, manual, legal/safety/regulatory, bt_address, feedback, fcc, sim_info |
| Apps matrix + Special Access gate | PASS | KEEP default/special_access/hibernated/battery; HIDE aspect_ratio + cloned_apps; `config_apps_special_access_requires_maintenance=true` + Settings confirm paths |
| Network matrix (not under Security) | PASS | KEEP internet/wifi/airplane/vpn; HIDE hotspot/data_saver/private_dns/adaptive_connectivity |
| GT Config confirm→session→authorize→launch | PASS | `GuardTalkConfigGateClient` + `GuardTalkSecurityDashboardFragment` → `com.guardtalk.config/.ConfigActivity` with `GT_CONFIG_WRITE` |
| Contacts UI absence (Q-CONTACTS) | PASS | Cross-check: hide bool + `GuardTalkContactsVisibility` + Launcher `PeopleActivity` filter (prior Q-SEC-P1-CONTACTS ✅) |
| Dev Options blocked | PASS | Overlay unlock block + `BuildNumberPreferenceController` consults policy |
| Build number visible | PASS | `config_show_about_build_number=true` (MUST) |
| Launcher GT Config/Info kept | PASS | Not in `filtered_components` items; workspace pins both packages |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_p1_static.sh
# ALL STATIC CHECKS PASSED
# PASS: 93  FAIL: 0  EXIT: 0
```

Extended for `Q-SEC-P1-UI`: About/Apps/Network/Main matrices, Security-after-Apps order, GT Config UX, Special Access maintenance gate, Launcher GT keep, Contacts cross-check.

## Artifact smoke (prior tokay build; no fresh `m`)

| Artifact | mtime (UTC) | Finding |
|----------|-------------|---------|
| `Settings.apk` | 2026-07-22 13:50 | DEX symbols: `GuardTalkSecurityDashboardFragment`, `GuardTalkConfigGateClient`, `GuardTalkSpecialAccessPreferenceController`, `GuardTalkAboutPhoneVisibility`, `GuardTalkAppsVisibility`, `GuardTalkDeveloperOptionsPolicy`, `GuardTalkContactsVisibility`, `com.guardtalk.config` / `ConfigActivity` |
| `GuardTalkSettingsOverlay.apk` | 2026-07-22 14:04 | `resources.arsc` contains key overlay bool names (security, maintenance gate, hotspot hide, build_number, DevOpts block, contacts hide, vpn/internet, aspect_ratio) |
| `GuardTalkLauncherOverlay.apk` | 2026-07-22 09:26 | `PeopleActivity` component string in `resources.arsc` |
| Prior `m Settings` | F-SEC-P1-ABOUT-APPS | Signal `review-F-SEC-P1-ABOUT-APPS.json`: `m Settings BUILD_EXIT=0` (adevtool pin bypass+restore) |

### Freshness WARN

- `GuardTalkSecurityDashboardFragment.java` and `SpecialAccessSettings.java` are ~8.5 minutes newer than on-disk `Settings.apk`.
- DEX still contains ABOUT-APPS UX class/string symbols; overlay APK is newer than overlay `config.xml`.
- No rebuild performed this QA session (task allows citing prior green `m Settings`).

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime UI smoke **SKIPPED** (Settings launch, Special Access password prompt, GT Config launch, Dev Options 7-tap).

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Network prefs under Security XML | absent | absent | PASS |
| Hotspot bool false while Network KEEP | hotspot hidden independently of sim_info | `config_show_wifi_hotspot_settings=false` | PASS |
| GT packages in `filtered_components` `<item>` | not filtered | only PeopleActivity item | PASS |
| Comment text mentioning GT packages in Launcher overlay | must not fail check | script scopes to `<item>` only | PASS |
| Special Access deep-link without session | finish/deny | `SpecialAccessSettings.maybeRequestMaintenanceGate` fail-closed | PASS (static) |
| Build number hidden | forbidden | `config_show_about_build_number=true` | PASS |
| ContactsProvider in PM hooks | must not restrict provider | prior Q-CONTACTS: providers.contacts count=0 | PASS (cross-check) |

## Coverage gaps

- Device UI smoke (homepage order, password UX, Special Access gate, Dev Options taps) deferred until adb device available
- Full Settings rebuild after latest ~8.5m source delta not re-run here
- End-to-end gate session TTL expiry while Special Access open: static path covered; runtime not exercised

## PQE Assessment

Code entropy **LOW** — keep/hide driven by overlay bools + small Settings helpers; fail-closed credential/session paths; no APK removal.
