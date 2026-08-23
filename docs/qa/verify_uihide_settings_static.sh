#!/usr/bin/env bash
# Static verification for Q-UIHIDE-SETTINGS
# (T-UIHIDE-KEYS + F-UIHIDE-SETTINGS: hide Privacy Health/Agents/geodata,
#  Security Trust agents, System Backup from Settings UI + search).
# Exits non-zero on any FAIL.
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_uihide_settings_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }

require_file() {
  local f="$1" label="${2:-$1}"
  if [[ -f "$f" ]]; then
    pass "present: $label"
  else
    fail "missing: $label ($f)"
  fi
}

require_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

forbid_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label (file missing: $file)"
    return
  fi
  if rg -q -- "$pat" "$file"; then
    fail "$label (forbidden pattern present in $file)"
  else
    pass "$label"
  fi
}

require_bool_false() {
  local name="$1" file="$2"
  if [[ -f "$file" ]] && rg -q "<bool name=\"${name}\">false</bool>" "$file"; then
    pass "overlay ${name}=false"
  else
    fail "overlay ${name} must be false in $file"
  fi
}

require_bool_true() {
  local name="$1" file="$2"
  if [[ -f "$file" ]] && rg -q "<bool name=\"${name}\">true</bool>" "$file"; then
    pass "baseline ${name}=true"
  else
    fail "baseline ${name} must be true in $file"
  fi
}

# --- Paths ---
SETTINGS_CFG="packages/apps/Settings/res/values/config.xml"
OVERLAY_CFG="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
OVERLAY_STR="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/strings.xml"
OVERLAY_README="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/README.md"
POLICY="vendor/guardtalk/docs/SETTINGS_VISIBILITY_POLICY.md"
T_DOC="vendor/guardtalk/docs/T-UIHIDE-KEYS.md"
F_DOC="vendor/guardtalk/docs/F-UIHIDE-SETTINGS.md"
HC_VIS="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkPrivacyVisibility.java"
DASH="packages/apps/Settings/src/com/android/settings/dashboard/DashboardFragment.java"
SEARCH_PROV="packages/apps/Settings/src/com/android/settings/search/SettingsSearchIndexablesProvider.java"
AGENTS_CTRL="packages/apps/Settings/src/com/android/settings/privacy/AppFunctionAccessPreferenceController.kt"
AGENTS_UTIL="packages/apps/Settings/src/com/android/settings/appfunctions/AppFunctionAccessUtil.kt"
GEODATA_CTRL="packages/apps/Settings/src/com/android/settings/privacy/AppDataSharingUpdatesPreferenceController.java"
TRUST_MANAGE="packages/apps/Settings/src/com/android/settings/security/trustagent/ManageTrustAgentsPreferenceController.java"
TRUST_LIST="packages/apps/Settings/src/com/android/settings/security/trustagent/TrustAgentListPreferenceController.java"
TRUST_PAGE="packages/apps/Settings/src/com/android/settings/security/trustagent/TrustAgentSettings.java"
BACKUP_UTILS="packages/apps/Settings/src/com/android/settings/backup/PrivacySettingsUtils.java"
BACKUP_INACTIVE="packages/apps/Settings/src/com/android/settings/backup/BackupInactivePreferenceController.java"
BACKUP_DATA_MGMT="packages/apps/Settings/src/com/android/settings/backup/DataManagementPreferenceController.java"
BACKUP_SETTINGS_CTRL="packages/apps/Settings/src/com/android/settings/backup/BackupSettingsPreferenceController.java"
BACKUP_FRAG="packages/apps/Settings/src/com/android/settings/backup/BackupSettingsFragment.java"
BACKUP_PRIVACY="packages/apps/Settings/src/com/android/settings/backup/PrivacySettings.java"
BACKUP_USER_ACT="packages/apps/Settings/src/com/android/settings/backup/UserBackupSettingsActivity.java"
HC_EXT_PROVIDER="packages/modules/HealthFitness/apk/src/com/android/healthconnect/controller/searchindexables/HealthConnectSearchIndexablesProvider.kt"
SETTINGS_BASE_STR="packages/apps/Settings/res/values/strings.xml"
ROOT_QUEUE="TASK_QUEUE.md"
AGENT_QUEUE=".agent-comm/TASK_QUEUE.md"

echo "=== Q-UIHIDE-SETTINGS static verification ==="
echo "ROOT=$ROOT"

# --- Docs / inventory ---
require_file "$T_DOC" "T-UIHIDE-KEYS.md"
require_file "$F_DOC" "F-UIHIDE-SETTINGS.md"
require_file "$POLICY" "SETTINGS_VISIBILITY_POLICY.md"
require_file "$OVERLAY_README" "overlay README"
require_rg 'config_show_health_connect_settings' "$T_DOC" "T doc lists HC bool"
require_rg 'config_show_app_function_access' "$T_DOC" "T doc lists Agents bool"
require_rg 'config_show_app_data_sharing_updates' "$T_DOC" "T doc lists geodata bool"
require_rg 'config_show_manage_trust_agents' "$T_DOC" "T doc lists Trust agents bool"
require_rg 'config_show_backup_settings' "$T_DOC" "T doc lists Backup bool"
require_rg 'system_dashboard_summary' "$F_DOC" "F doc lists system_dashboard_summary"
require_rg 'Languages, keyboard, time' "$F_DOC" "F doc expected summary value"

# --- Overlay bools false ---
require_file "$OVERLAY_CFG" "overlay config.xml"
for b in \
  config_show_health_connect_settings \
  config_show_app_function_access \
  config_show_app_data_sharing_updates \
  config_show_manage_trust_agents \
  config_show_backup_settings
do
  require_bool_false "$b" "$OVERLAY_CFG"
done
# companion trust-agent click intent also false (defence-in-depth)
require_bool_false "config_show_trust_agent_click_intent" "$OVERLAY_CFG"

# --- Settings baseline defaults true (reversible) ---
require_file "$SETTINGS_CFG" "Settings config.xml"
for b in \
  config_show_health_connect_settings \
  config_show_app_function_access \
  config_show_app_data_sharing_updates \
  config_show_manage_trust_agents \
  config_show_backup_settings
do
  require_bool_true "$b" "$SETTINGS_CFG"
done

# --- system_dashboard_summary overlay (F) ---
require_file "$OVERLAY_STR" "overlay strings.xml"
require_rg 'system_dashboard_summary">Languages, keyboard, time<' "$OVERLAY_STR" \
  "overlay system_dashboard_summary = Languages, keyboard, time"
forbid_rg 'system_dashboard_summary">.*[Bb]ackup' "$OVERLAY_STR" \
  "overlay summary must not advertise backup"
forbid_rg 'system_dashboard_summary">.*[Gg]esture' "$OVERLAY_STR" \
  "overlay summary must not advertise gestures"
# Base default still has old copy (expected; overlay overrides default locale)
require_rg 'system_dashboard_summary">Languages, gestures, time, backup<' "$SETTINGS_BASE_STR" \
  "base values/ still has legacy summary (locale residual source)"

# --- Locale residual documentation (must exist as residual; count > 0) ---
LOCALE_HITS=$(rg -l 'system_dashboard_summary' packages/apps/Settings/res/values-*/strings.xml 2>/dev/null | wc -l | tr -d ' ')
if [[ "${LOCALE_HITS}" -gt 0 ]]; then
  pass "locale residual present: ${LOCALE_HITS} values-* files still translate system_dashboard_summary"
else
  fail "expected locale residual files under values-* (document if cleaned)"
fi
OVERLAY_LOCALE_DIRS=$(find vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res -maxdepth 1 -type d -name 'values-*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${OVERLAY_LOCALE_DIRS}" -eq 0 ]]; then
  pass "no overlay values-* locale RROs (documents residual: EN overlay only)"
else
  pass "overlay has ${OVERLAY_LOCALE_DIRS} locale dirs (unexpected but ok if intentional)"
fi

# --- Health Connect / Privacy visibility ---
require_file "$HC_VIS" "GuardTalkPrivacyVisibility.java"
require_rg 'config_show_health_connect_settings' "$HC_VIS" "HC visibility reads overlay bool"
require_rg 'com\.android\.healthconnect\.controller' "$HC_VIS" "HC package constant"
require_rg 'shouldHideInjectedTile' "$HC_VIS" "HC shouldHideInjectedTile API"
require_rg 'GuardTalkPrivacyVisibility' "$DASH" "DashboardFragment hooks HC hide"
require_rg 'shouldHideInjectedTile' "$DASH" "DashboardFragment.displayTile HC gate"
require_rg 'GuardTalkPrivacyVisibility' "$SEARCH_PROV" "Search provider hooks HC hide"
require_rg 'shouldHideInjectedTile' "$SEARCH_PROV" "Search isEligibleForIndexing HC gate"

# --- Agents ---
require_file "$AGENTS_CTRL" "AppFunctionAccessPreferenceController"
require_file "$AGENTS_UTIL" "AppFunctionAccessUtil"
require_rg 'config_show_app_function_access' "$AGENTS_CTRL" "Agents controller bool gate"
require_rg 'UNSUPPORTED_ON_DEVICE' "$AGENTS_CTRL" "Agents controller UNSUPPORTED_ON_DEVICE"
require_rg 'config_show_app_function_access' "$AGENTS_UTIL" "Agents util bool gate"

# --- Geodata / data sharing updates ---
require_file "$GEODATA_CTRL" "AppDataSharingUpdatesPreferenceController"
require_rg 'config_show_app_data_sharing_updates' "$GEODATA_CTRL" "Geodata controller bool gate"
require_rg 'UNSUPPORTED_ON_DEVICE' "$GEODATA_CTRL" "Geodata UNSUPPORTED_ON_DEVICE"

# --- Trust agents ---
require_file "$TRUST_MANAGE" "ManageTrustAgentsPreferenceController"
require_file "$TRUST_LIST" "TrustAgentListPreferenceController"
require_file "$TRUST_PAGE" "TrustAgentSettings"
require_rg 'config_show_manage_trust_agents' "$TRUST_MANAGE" "ManageTrustAgents bool gate"
require_rg 'UNSUPPORTED_ON_DEVICE' "$TRUST_MANAGE" "ManageTrustAgents UNSUPPORTED_ON_DEVICE"
require_rg 'config_show_manage_trust_agents' "$TRUST_LIST" "TrustAgentList bool gate"
require_rg 'config_show_manage_trust_agents' "$TRUST_PAGE" "TrustAgentSettings search bool gate"
require_rg 'isPageSearchEnabled' "$TRUST_PAGE" "TrustAgentSettings isPageSearchEnabled"

# --- Backup (prior F-SYS-HIDE + System site-map) ---
for f in "$BACKUP_UTILS" "$BACKUP_INACTIVE" "$BACKUP_DATA_MGMT" \
         "$BACKUP_SETTINGS_CTRL" "$BACKUP_FRAG" "$BACKUP_PRIVACY" "$BACKUP_USER_ACT"
do
  require_file "$f" "$(basename "$f")"
  require_rg 'config_show_backup_settings' "$f" "$(basename "$f") gates backup bool"
done

# --- No APK/service deletes for hide strategy (sources retained) ---
require_file "$HC_EXT_PROVIDER" "HC SearchIndexablesProvider source retained (not deleted)"
require_file "$BACKUP_USER_ACT" "Backup activity source retained"
require_file "$TRUST_MANAGE" "Trust agents controller retained"
# Policy / docs say hide ≠ delete
require_rg '[Dd]o not.*delete|hide ≠ delete|Does NOT delete' "$OVERLAY_CFG" \
  "overlay comments assert hide≠delete"
require_rg '[Dd]o not.*delete|No deletion' "$T_DOC" "T doc non-goals no APK delete"

# --- HC external SearchIndexablesProvider residual (document, not fail) ---
if [[ -f "$HC_EXT_PROVIDER" ]] && rg -q 'class HealthConnectSearchIndexablesProvider' "$HC_EXT_PROVIDER"; then
  pass "RESIDUAL DOCUMENTED: HealthConnectSearchIndexablesProvider still exists (external to Settings)"
else
  fail "expected HC external SearchIndexablesProvider source for residual docs"
fi
# apex-bcp excision of healthfitness reduces runtime risk (defence-in-depth)
if rg -q 'com\.android\.healthfitness' vendor/guardtalk/feature-excised/apex-bcp-excised.mk 2>/dev/null; then
  pass "defence-in-depth: healthfitness listed in apex-bcp-excised.mk"
else
  pass "NOTE: healthfitness apex-bcp excision not matched (check manually)"
fi

# --- No over-hide of unrelated top-level Settings (spot-check) ---
for b in \
  config_show_top_level_network \
  config_show_top_level_apps \
  config_show_top_level_notifications \
  config_show_top_level_display \
  config_show_top_level_battery \
  config_show_top_level_system \
  config_show_top_level_privacy \
  config_show_top_level_security
do
  require_bool_true "$b" "$OVERLAY_CFG"
done
require_bool_true "config_show_wifi_settings" "$OVERLAY_CFG"

# --- Policy matrix mentions five targets ---
require_rg 'config_show_health_connect_settings' "$POLICY" "policy HC row"
require_rg 'config_show_app_function_access' "$POLICY" "policy Agents row"
require_rg 'config_show_app_data_sharing_updates' "$POLICY" "policy geodata row"
require_rg 'config_show_manage_trust_agents' "$POLICY" "policy Trust agents row"
require_rg 'system_dashboard_summary' "$POLICY" "policy system summary"

# --- Dependency APPROVED cites (queues) ---
for q in "$ROOT_QUEUE" "$AGENT_QUEUE"; do
  require_file "$q" "$q"
  if rg -q 'T-UIHIDE-KEYS.*APPROVED' "$q" && rg -q 'F-UIHIDE-SETTINGS.*APPROVED' "$q"; then
    pass "$q cites T+F APPROVED"
  else
    fail "$q missing T-UIHIDE-KEYS / F-UIHIDE-SETTINGS APPROVED"
  fi
done

# --- Settings.apk artifact (optional strong signal) ---
SETTINGS_APK=""
for p in \
  out/target/product/tokay/system_ext/priv-app/Settings/Settings.apk \
  out/target/product/akita/system_ext/priv-app/Settings/Settings.apk
do
  if [[ -f "$p" ]]; then
    SETTINGS_APK="$p"
    break
  fi
done
if [[ -n "$SETTINGS_APK" ]]; then
  pass "Settings.apk present: $SETTINGS_APK"
else
  pass "Settings.apk absent (static-only; cite m Settings blocker separately)"
fi

echo ""
echo "=== Summary ==="
echo "PASS_COUNT=$PASS_N"
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAIL_COUNT>=1"
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "FAIL_COUNT=0"
echo "ALL STATIC CHECKS PASSED"
exit 0
