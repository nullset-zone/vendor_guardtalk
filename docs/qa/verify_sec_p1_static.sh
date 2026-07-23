#!/usr/bin/env bash
# Static verification for Q-SEC-P1-SETTINGS + Q-SEC-P1-DEVOPTS + Q-SEC-P1-CONTACTS
# + Q-SEC-P1-UI (Phase-1 Settings/Launcher keep-hide matrices + UI smoke).
# (no device required).
# Usage: from GrapheneOS-worktree root: bash vendor/guardtalk/docs/qa/verify_sec_p1_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAIL=1; }

# Require overlay bool NAME="VALUE" (exact match, comments ignored by rg on line).
require_bool() {
  local file="$1" name="$2" want="$3" label="$4"
  if rg -q "name=\"${name}\">${want}<" "$file"; then
    pass "$label (${name}=${want})"
  else
    fail "$label (${name}!=${want} or missing in $file)"
  fi
}

DASH="packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml"
OV="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
MK="vendor/guardtalk/device/tokay/guardtalk-tokay.mk"
BN="packages/apps/Settings/src/com/android/settings/deviceinfo/BuildNumberPreferenceController.java"
POL="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkDeveloperOptionsPolicy.java"
MGR="frameworks/base/core/java/android/guardtalk/GuardTalkConfigGateManager.java"
SVC="frameworks/base/services/core/java/com/android/server/guardtalk/GuardTalkConfigGateService.java"
SS="frameworks/base/services/java/com/android/server/SystemServer.java"

# --- Q-SEC-P1-CONTACTS paths ---
CVIS="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkContactsVisibility.java"
CDOC="vendor/guardtalk/docs/CONTACTS_UI_SUPPRESSION.md"
LOV="vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/values/config.xml"
PMH="frameworks/base/services/core/java/com/android/server/ext/PackageManagerHooks.java"
APPS_EX="vendor/guardtalk/feature-excised/apps-excised.mk"
CSPC="packages/apps/Settings/src/com/android/settings/applications/contacts/ContactsStoragePreferenceController.java"
CSS="packages/apps/Settings/src/com/android/settings/applications/contacts/ContactsStorageSettings.java"
AAL="packages/apps/Settings/src/com/android/settings/spa/app/AllAppList.kt"
MA="packages/apps/Settings/src/com/android/settings/applications/manageapplications/ManageApplications.java"
ENT="packages/apps/Settings/src/com/android/settings/enterprise/EnterpriseSetDefaultAppsListPreferenceController.java"
SCFG="packages/apps/Settings/res/values/config.xml"

# --- Q-SEC-P1-UI paths ---
TLS="packages/apps/Settings/res/xml/top_level_settings.xml"
TLSE="packages/apps/Settings/res/xml/top_level_settings_expressive.xml"
GT_FRAG="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityDashboardFragment.java"
GT_CLIENT="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkConfigGateClient.java"
SPEC_ACC="packages/apps/Settings/src/com/android/settings/applications/specialaccess/SpecialAccessSettings.java"
SPEC_CTRL="packages/apps/Settings/src/com/android/settings/applications/GuardTalkSpecialAccessPreferenceController.java"
APP_DASH="packages/apps/Settings/src/com/android/settings/applications/AppDashboardFragment.java"
WS="vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/xml/default_workspace_5x5.xml"

echo "=== Q-SEC-P1-SETTINGS / DEVOPTS ==="

[[ -f "$DASH" ]] || fail "missing $DASH"
if rg -i 'wifi|vpn|hotspot|airplane' "$DASH" | rg -v 'MUST NOT|Network /' >/dev/null; then
  fail "network-related prefs found in Security dashboard XML"
else
  pass "no network prefs under Security dashboard XML"
fi

rg -q 'config_use_guardtalk_security_dashboard">true' "$OV" \
  && pass "overlay enables GuardTalk Security dashboard" \
  || fail "overlay Security dashboard not enabled"
rg -q 'config_show_about_build_number">true' "$OV" \
  && pass "build number kept visible in overlay" \
  || fail "build number not kept visible"
rg -q 'config_guardtalk_block_developer_options_unlock">true' "$OV" \
  && pass "overlay blocks Dev Options unlock" \
  || fail "overlay Dev Options block bool false/missing"

rg -q 'ro.guardtalk.block_developer_options=1' "$MK" \
  && pass "product prop block_developer_options=1" \
  || fail "missing block_developer_options prop"
rg -q 'ro.guardtalk.config_password_gate=1' "$MK" \
  && pass "product prop config_password_gate=1" \
  || fail "missing config_password_gate prop"

rg -q 'startService\(GuardTalkConfigGateService.class\)' "$SS" \
  && pass "SystemServer registers GuardTalkConfigGateService" \
  || fail "SystemServer missing gate service start"

rg -q 'GuardTalkDeveloperOptionsPolicy.isUnlockBlocked' "$BN" \
  && pass "BuildNumber controller consults Dev Options policy" \
  || fail "BuildNumber missing policy check"
rg -q 'isUnlockBlocked' "$POL" \
  && pass "GuardTalkDeveloperOptionsPolicy present" \
  || fail "policy helper missing"

rg -q 'service missing \(fail-closed\)' "$MGR" \
  && pass "Manager documents fail-closed on missing binder" \
  || fail "Manager missing fail-closed path"
rg -q 'GuardTalk config gate unavailable \(fail-closed\)' "$MGR" \
  && pass "assertMutationAuthorized throws when binder missing" \
  || fail "assertMutationAuthorized missing null-service throw"

rg -q 'hasActiveSessionLocked' "$SVC" \
  && pass "Service gates mutations on active session" \
  || fail "Service missing session check"
rg -q 'SHELL_UID|ROOT_UID' "$SVC" \
  && pass "Service blocks shell/root session open" \
  || fail "Service missing shell/root reject"

echo "=== Q-SEC-P1-CONTACTS ==="

[[ -f "$CDOC" ]] || fail "missing $CDOC"
[[ -f "$CVIS" ]] || fail "missing GuardTalkContactsVisibility"

rg -q 'config_guardtalk_hide_contacts_ui">true' "$OV" \
  && pass "overlay config_guardtalk_hide_contacts_ui=true" \
  || fail "overlay hide_contacts_ui not true"

rg -q 'config_guardtalk_hide_contacts_ui' "$SCFG" \
  && pass "Settings base defines config_guardtalk_hide_contacts_ui" \
  || fail "Settings base missing hide_contacts_ui bool"
rg -q 'com.android.contacts' "$SCFG" \
  && rg -q 'com.android.providers.contacts' "$SCFG" \
  && pass "Settings base hidden_contacts_packages lists contacts + provider" \
  || fail "Settings base hidden package array incomplete"

rg -q 'PeopleActivity' "$LOV" \
  && rg -q 'com.android.contacts/com.android.contacts.activities.PeopleActivity' "$LOV" \
  && pass "Launcher filtered_components includes PeopleActivity" \
  || fail "Launcher overlay missing PeopleActivity filter"

# PackageManagerHooks: com.android.contacts only (not ContactsProvider)
if rg -q 'restrictedVisibilityPackages' "$PMH" \
  && rg -q '"com.android.contacts"' "$PMH"; then
  if rg -q '"com.android.providers.contacts"' "$PMH"; then
    fail "PackageManagerHooks incorrectly restricts ContactsProvider"
  else
    pass "PackageManagerHooks restricts com.android.contacts only"
  fi
else
  fail "PackageManagerHooks missing com.android.contacts restriction"
fi

# GUARDTALK_APPS_KEEP retains Contacts + ContactsProvider; not in drop list
if awk '
  BEGIN { mode="" }
  /^[[:space:]]*#/ { next }
  /^GUARDTALK_APPS_KEEP[[:space:]]*:=/ { mode="keep"; next }
  /^GUARDTALK_APPS_PACKAGES[[:space:]]*(\+?=|:=)/ { mode="drop"; next }
  mode!="" && /^[A-Z][A-Z0-9_]*[[:space:]]*(\+?=|:=)/ { mode="" }
  mode=="keep" && $1 ~ /^Contacts(\\ )?$/ { keep_c=1 }
  mode=="keep" && $1 ~ /^ContactsProvider(\\ )?$/ { keep_p=1 }
  mode=="drop" && $1 ~ /^Contacts(\\ )?$/ { drop_c=1 }
  mode=="drop" && $1 ~ /^ContactsProvider(\\ )?$/ { drop_p=1 }
  END {
    if (!keep_c || !keep_p) { exit 2 }
    if (drop_c || drop_p) { exit 3 }
    exit 0
  }
' "$APPS_EX"; then
  pass "apps-excised KEEP Contacts+ContactsProvider; not in drop list"
else
  rc=$?
  if [[ $rc -eq 2 ]]; then
    fail "apps-excised missing Contacts/ContactsProvider in GUARDTALK_APPS_KEEP"
  else
    fail "apps-excised incorrectly drops Contacts/ContactsProvider"
  fi
fi

rg -q 'GuardTalkContactsVisibility.isUiHidden' "$CSPC" \
  && pass "ContactsStoragePreferenceController consults visibility helper" \
  || fail "ContactsStoragePreferenceController missing hide check"
rg -q 'UNSUPPORTED_ON_DEVICE' "$CSPC" \
  && pass "Contacts storage preference returns UNSUPPORTED_ON_DEVICE when hidden" \
  || fail "Contacts storage preference missing UNSUPPORTED_ON_DEVICE"

rg -q 'isPageSearchEnabled' "$CSS" \
  && rg -q 'GuardTalkContactsVisibility.isUiHidden' "$CSS" \
  && pass "ContactsStorageSettings search de-indexed when hidden" \
  || fail "ContactsStorageSettings search gate missing"

rg -q 'GuardTalkContactsVisibility.shouldHidePackage' "$AAL" \
  && pass "AllAppList filters hidden contacts packages" \
  || fail "AllAppList missing shouldHidePackage filter"
rg -q 'GuardTalkContactsVisibility.shouldHidePackage' "$MA" \
  && pass "ManageApplications filters hidden contacts packages" \
  || fail "ManageApplications missing shouldHidePackage filter"
rg -q 'EnterpriseDefaultApps.CONTACTS' "$ENT" \
  && rg -q 'GuardTalkContactsVisibility.isUiHidden' "$ENT" \
  && pass "Enterprise default-apps skips CONTACTS when hidden" \
  || fail "Enterprise default-apps CONTACTS skip missing"

echo "=== Q-SEC-P1-UI (Settings/Launcher matrices + Phase-1 smoke) ==="

# Security immediately after Apps (order -60 apps, -55 security) in both homepage XMLs
for f in "$TLS" "$TLSE"; do
  if awk '
    /android:key="top_level_apps"/ { apps=1; next }
    apps && /android:order="-60"/ { apps_ok=1 }
    /android:key="top_level_security"/ { sec=1; next }
    sec && /android:order="-55"/ { sec_ok=1 }
    END { exit !(apps_ok && sec_ok) }
  ' "$f"; then
    pass "Security order -55 after Apps -60 in $(basename "$f")"
  else
    fail "Security not immediately after Apps in $(basename "$f")"
  fi
  rg -q 'GuardTalkSecurityDashboardFragment' "$f" \
    && pass "homepage wires GuardTalkSecurityDashboardFragment ($(basename "$f"))" \
    || fail "homepage missing GuardTalkSecurityDashboardFragment ($(basename "$f"))"
done

# No network under Security dashboard
if rg -i 'wifi|vpn|hotspot|airplane|network' "$DASH" | rg -v 'MUST NOT|Network /' >/dev/null; then
  fail "network-related prefs found under Security dashboard (UI matrix)"
else
  pass "Security dashboard has no network prefs (UI matrix)"
fi
require_bool "$OV" "config_show_top_level_network" "true" "Network stays top-level (not under Security)"
require_bool "$OV" "config_show_top_level_security" "true" "Security top-level kept"

# Main Settings keep/hide (F-SEC-P1-SETTINGS-UI)
require_bool "$OV" "config_show_top_level_apps" "true" "KEEP apps"
require_bool "$OV" "config_show_top_level_notifications" "true" "KEEP notifications"
require_bool "$OV" "config_show_top_level_sound" "true" "KEEP sound"
require_bool "$OV" "config_show_top_level_priority_modes" "true" "KEEP priority_modes"
require_bool "$OV" "config_show_top_level_display" "true" "KEEP display"
require_bool "$OV" "config_show_top_level_storage" "true" "KEEP storage"
require_bool "$OV" "config_show_top_level_battery" "true" "KEEP battery"
require_bool "$OV" "config_show_top_level_system" "true" "KEEP system"
require_bool "$OV" "config_show_top_level_about_device" "true" "KEEP about_device"
require_bool "$OV" "config_show_top_level_privacy" "true" "KEEP privacy"
require_bool "$OV" "config_show_top_level_safety_center" "false" "HIDE safety_center"
require_bool "$OV" "config_show_top_level_location" "false" "HIDE location"
require_bool "$OV" "config_show_top_level_accounts" "false" "HIDE accounts"
require_bool "$OV" "config_show_top_level_connected_devices" "false" "HIDE connected_devices"
require_bool "$OV" "config_show_top_level_accessibility" "false" "HIDE accessibility"
require_bool "$OV" "config_show_emergency_settings" "false" "HIDE emergency"

# About phone matrix (F-SEC-P1-ABOUT-APPS / ABOUT_PHONE policy)
require_bool "$OV" "config_show_device_name" "true" "About KEEP device_name"
require_bool "$OV" "config_show_device_model" "true" "About KEEP device_model"
require_bool "$OV" "config_show_about_firmware_version" "true" "About KEEP firmware"
require_bool "$OV" "config_show_about_battery_info" "true" "About KEEP battery"
require_bool "$OV" "config_show_about_build_number" "true" "About KEEP build_number (MUST)"
require_bool "$OV" "config_show_about_uptime" "true" "About KEEP uptime"
require_bool "$OV" "config_show_branded_account_in_device_info" "false" "About HIDE branded_account"
require_bool "$OV" "config_show_wifi_ip_address" "false" "About HIDE wifi_ip"
require_bool "$OV" "config_show_wifi_mac_address" "false" "About HIDE wifi_mac"
require_bool "$OV" "config_show_manual" "false" "About HIDE manual"
require_bool "$OV" "config_show_about_legal_info" "false" "About HIDE legal"
require_bool "$OV" "config_show_about_safety_info" "false" "About HIDE safety"
require_bool "$OV" "config_show_regulatory_info" "false" "About HIDE regulatory"
require_bool "$OV" "config_show_about_bt_address" "false" "About HIDE bt_address"
require_bool "$OV" "config_show_about_device_feedback" "false" "About HIDE device_feedback"
require_bool "$OV" "config_show_about_fcc_equipment_id" "false" "About HIDE fcc"
require_bool "$OV" "config_show_sim_info" "false" "About HIDE sim_info"

# Apps matrix + Special Access maintenance gate
require_bool "$OV" "config_show_apps_default_apps" "true" "Apps KEEP default_apps"
require_bool "$OV" "config_show_apps_special_access" "true" "Apps KEEP special_access row"
require_bool "$OV" "config_show_apps_hibernated" "true" "Apps KEEP unused/hibernated"
require_bool "$OV" "config_show_apps_battery_usage" "true" "Apps KEEP battery_usage"
require_bool "$OV" "config_show_apps_aspect_ratio" "false" "Apps HIDE aspect_ratio"
require_bool "$OV" "config_cloned_apps_page_enabled" "false" "Apps HIDE cloned_apps"
require_bool "$OV" "config_apps_special_access_requires_maintenance" "true" \
  "Special Access requires maintenance session"

[[ -f "$SPEC_CTRL" ]] || fail "missing GuardTalkSpecialAccessPreferenceController"
rg -q 'isMaintenanceAuthorized' "$SPEC_CTRL" \
  && pass "SpecialAccess controller consults maintenance authorization" \
  || fail "SpecialAccess controller missing maintenance check"
rg -q 'specialAccessRequiresMaintenance' "$SPEC_ACC" \
  && rg -q 'GuardTalkConfigGateClient.startConfirm' "$SPEC_ACC" \
  && pass "SpecialAccessSettings gates deep-link/search with confirm" \
  || fail "SpecialAccessSettings missing maintenance confirm gate"
rg -q 'isSpecialAccessKey' "$APP_DASH" \
  && rg -q 'GuardTalkConfigGateClient.startConfirm' "$APP_DASH" \
  && pass "AppDashboard gates Special Access preference click" \
  || fail "AppDashboard missing Special Access confirm path"

# Network matrix (NEVER under Security)
require_bool "$OV" "config_show_internet_settings" "true" "Network KEEP internet"
require_bool "$OV" "config_show_wifi_settings" "true" "Network KEEP wifi"
require_bool "$OV" "config_show_toggle_airplane" "true" "Network KEEP airplane"
require_bool "$OV" "config_show_vpn_options" "true" "Network KEEP vpn"
require_bool "$OV" "config_show_wifi_hotspot_settings" "false" "Network HIDE hotspot"
require_bool "$OV" "config_show_data_saver" "false" "Network HIDE data_saver"
require_bool "$OV" "config_show_private_dns_settings" "false" "Network HIDE private_dns"
require_bool "$OV" "config_show_adaptive_connectivity" "false" "Network HIDE adaptive_connectivity"

# GT Config confirm → session → authorize → launch
[[ -f "$GT_CLIENT" ]] || fail "missing GuardTalkConfigGateClient"
rg -q 'createConfirmDeviceCredentialIntent' "$GT_CLIENT" \
  && rg -q 'onDeviceCredentialConfirmed' "$GT_CLIENT" \
  && rg -q 'MAINTENANCE_ACCESS' "$GT_CLIENT" \
  && pass "GT Config client: confirm → session + maintenance helper" \
  || fail "GT Config client missing confirm/session/maintenance wiring"
rg -q 'startConfirm' "$GT_FRAG" \
  && rg -q 'assertAuthorized' "$GT_FRAG" \
  && rg -q 'com.guardtalk.config' "$GT_FRAG" \
  && rg -q 'ConfigActivity' "$GT_FRAG" \
  && rg -q 'GT_CONFIG_WRITE' "$GT_FRAG" \
  && pass "Security dashboard GT Config: confirm→authorize→launch ConfigActivity" \
  || fail "Security dashboard GT Config launch path incomplete"
rg -q 'guardtalk_gt_config' "$DASH" \
  && pass "Security dashboard exposes guardtalk_gt_config preference" \
  || fail "Security dashboard missing GT Config preference key"

# Launcher: Contacts filtered; GT Config/Info kept (workspace + not filtered)
rg -q 'PeopleActivity' "$LOV" \
  && pass "Launcher filters Contacts PeopleActivity" \
  || fail "Launcher missing PeopleActivity filter"
# Only <item> entries inside filtered_components count (ignore comments).
if awk '
  /name="filtered_components"/ { in_arr=1 }
  in_arr && /<\/string-array>/ { in_arr=0 }
  in_arr && /<item>/ {
    if ($0 ~ /com\.guardtalk\.(config|validator)/) { bad=1 }
  }
  END { exit bad ? 1 : 0 }
' "$LOV"; then
  pass "Launcher filtered_components does not hide GT Config/Info"
else
  fail "Launcher incorrectly filters GT Config/Info packages"
fi
rg -q 'com.guardtalk.config' "$WS" \
  && rg -q 'com.guardtalk.validator' "$WS" \
  && pass "Launcher workspace pins GT Config + GT Info" \
  || fail "Launcher workspace missing GT Config/Info pins"

# Dev Options blocked + build number visible (cross-check DEVOPTS)
require_bool "$OV" "config_guardtalk_block_developer_options_unlock" "true" \
  "Dev Options unlock blocked (UI)"
rg -q 'GuardTalkDeveloperOptionsPolicy.isUnlockBlocked' "$BN" \
  && pass "BuildNumber taps consult Dev Options block (UI)" \
  || fail "BuildNumber missing unlock block (UI)"

# Contacts UI absence cross-check (Q-CONTACTS)
require_bool "$OV" "config_guardtalk_hide_contacts_ui" "true" \
  "Contacts UI hide bool (cross-check Q-CONTACTS)"
[[ -f "$CVIS" ]] \
  && pass "GuardTalkContactsVisibility present (cross-check Q-CONTACTS)" \
  || fail "GuardTalkContactsVisibility missing (cross-check Q-CONTACTS)"

if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  exit 0
fi
echo "SOME CHECKS FAILED"
exit 1
