# QA Evidence — Q-UIHIDE-SETTINGS

**Task:** `Q-UIHIDE-SETTINGS` (Privacy / Trust agents / Backup UI+search absence)  
**Date:** 2026-07-25  
**Agent:** QA_ENGINEER  
**Depends:** `T-UIHIDE-KEYS` ✅ APPROVED, `F-UIHIDE-SETTINGS` ✅ APPROVED  
**Verdict:** **GO (static)** — fresh `m Settings` **BLOCKED** (out-of-scope F-BRAND-UI) — runtime adb **HOLD**

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Overlay five hide bools `=false` | PASS | `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml` |
| Settings defaults `=true` (reversible) | PASS | `packages/apps/Settings/res/values/config.xml` |
| HC Privacy tile + search gated | PASS | `GuardTalkPrivacyVisibility` + `DashboardFragment.displayTile` + `SettingsSearchIndexablesProvider.isEligibleForIndexing` |
| Agents gated | PASS | `AppFunctionAccessPreferenceController` + `AppFunctionAccessUtil` → `UNSUPPORTED_ON_DEVICE` / false |
| Geodata / data-sharing updates gated | PASS | `AppDataSharingUpdatesPreferenceController` |
| Trust agents gated | PASS | `ManageTrustAgentsPreferenceController` + `TrustAgentListPreferenceController` + `TrustAgentSettings` search |
| Backup gated (System site-map) | PASS | 7 backup controllers/utils/search hooks on `config_show_backup_settings` |
| `system_dashboard_summary` no backup advert | PASS | Overlay = `Languages, keyboard, time` |
| Locale residual documented | PASS | 85 `values-*` still translate legacy summary; no overlay `values-*` |
| HC external SearchIndexablesProvider residual | PASS (DOC) | `HealthConnectSearchIndexablesProvider.kt` retained; apex-bcp healthfitness excised |
| No over-hide Network/Apps/etc | PASS | top-level network/apps/notifications/display/battery/system/privacy/security + wifi `true` |
| No APK deletes for hide | PASS | Sources retained; overlay/T docs assert hide≠delete |
| `m Settings` green or cite blocker | **BLOCKER CITED** | `BUILD_EXIT=1` — `R.drawable.ic_guardtalk_logo` missing (`MyDeviceInfoFragment.java:244`, F-BRAND-UI in flight) |
| Device smoke | HOLD | `adb devices` empty |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_uihide_settings_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=95 FAIL_COUNT=0 EXIT=0
```

Log: `/tmp/Q-UIHIDE-SETTINGS-verify.log`

**Counts:** **95 / 95** PASS (0 FAIL).

## Overlay bool inventory

| Bool | Overlay | Settings default |
|------|---------|------------------|
| `config_show_health_connect_settings` | false | true |
| `config_show_app_function_access` | false | true |
| `config_show_app_data_sharing_updates` | false | true |
| `config_show_manage_trust_agents` | false | true |
| `config_show_backup_settings` | false | true |
| `config_show_trust_agent_click_intent` | false | (companion) |

## Controller / search hooks

| Target | Hook |
|--------|------|
| Health and fitness | `GuardTalkPrivacyVisibility` → dashboard + search injected-tile skip |
| Agents | `AppFunctionAccessPreferenceController` / `AppFunctionAccessUtil` |
| Changes in geodata transmission | `AppDataSharingUpdatesPreferenceController` |
| Trust agents | `ManageTrustAgentsPreferenceController`, `TrustAgentListPreferenceController`, `TrustAgentSettings.isPageSearchEnabled` |
| Backup | `PrivacySettingsUtils`, `BackupInactive*`, `DataManagement*`, `BackupSettings*`, `PrivacySettings`, `UserBackupSettingsActivity` |

## `system_dashboard_summary`

| Source | Value |
|--------|-------|
| Overlay `res/values/strings.xml` | `Languages, keyboard, time` |
| Settings `res/values/strings.xml` (base) | `Languages, gestures, time, backup` (overridden by RRO for default locale) |

## Residuals (documented — not FAIL for this task)

| Residual | Status | Notes |
|----------|--------|-------|
| Locale `values-*` System summaries (85 files) | **DOCUMENTED** | May still show gesture/backup words on System tile in non-EN locales until locale RROs / base string updates |
| HC `HealthConnectSearchIndexablesProvider` | **DOCUMENTED** | External provider still in tree; Settings injected-tile path gated; `com.android.healthfitness` apex-bcp excised (defence-in-depth). If APEX ever reintroduced without Settings gate, search hits possible. |
| `TrustAgentsPreferenceController` | **DOCUMENTED WARN** | Availability uses SmartLock block only (not overlay bool). Manage/list/page search are bool-gated — residual if page reached another way. |
| Sound Prevent Ringing | OUT OF SCOPE | Prior F-SYS-HIDE accepted residual |
| Fresh `m Settings` | **BLOCKER** | F-BRAND-UI incomplete drawable `ic_guardtalk_logo` — recommend F-BRAND-UI fix; not a UIHIDE product rewrite |

## Build / artifact

| Source | Result |
|--------|--------|
| `lunch akita-trunk_staging-userdebug` | `LUNCH_EXIT=0` |
| `m Settings -j$(nproc)` | **`BUILD_EXIT=1`** — `MyDeviceInfoFragment.java:244` `cannot find symbol: ic_guardtalk_logo` |
| Prior `Settings.apk` (tokay) | PRESENT (pre-existing artifact; not rebuilt this session) |
| adevtool pin | PIN_OK / unchanged after build attempt |
| Log | `/tmp/q-uihide-m-settings-20260725T084924Z.log` |

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime smoke **HOLD**:

- Privacy: Health and fitness / Agents / geodata updates absent
- Security → Additional protection: Trust agents absent
- System: Backup absent; System summary shows Languages, keyboard, time (EN)
- Settings search for Backup / Trust agents / Agents / Health / Data sharing

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Overlay bools true | would show targets | overlay false; Settings default true | PASS |
| APK delete as hide | forbidden | sources + HC provider retained | PASS |
| Over-hide Network/Apps | forbidden | top-level bools remain true | PASS |
| Invent PASS without script | forbidden | script EXIT=0 recorded | PASS |
| Locale summary cleaned | not required this sprint | 85 residuals documented | PASS (doc) |

## Coverage gaps

- No device/emulator: cannot adb-verify UI hierarchy or live search.
- Fresh Settings rebuild blocked by F-BRAND-UI missing drawable.
- Overlay runtime merge not exercised on device.

## Gate 5 (Self-Critique)

See `.agent-comm/inbox/TO_ARCHITECT.md` — **Q-UIHIDE-SETTINGS Gate 5: 93%** (manual; MCP `ultimate_critique` / `hallucination_guard` unavailable — Not connected).

### PQE Assessment: Code Entropy LOW — overlay-reversible UI hides; controllers/search fail closed when bools false; residuals documented; no over-deletion.
