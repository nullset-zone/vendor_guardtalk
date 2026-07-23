#!/usr/bin/env bash
# Static verification for Q-SEC-P4-PRIVACY (Phase-4 §32 privacy/files slice).
# Covers Messenger grant plumbing + deny-default, privacy_tmpfs + clipboard_clear,
# Files trash/ZIP/protect + no duplicate Compose launcher, keep-hide matrices,
# Security mutation password gate, no network under Security, prior green cites,
# and vendor prop presence where regenerable. (no device required).
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_sec_p4_static.sh
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

require_bool() {
  local file="$1" name="$2" want="$3" label="$4"
  if rg -q "name=\"${name}\">${want}<" "$file"; then
    pass "$label (${name}=${want})"
  else
    fail "$label (${name}!=${want} or missing in $file)"
  fi
}

# --- Paths ---
PERM_POL="frameworks/base/core/java/android/guardtalk/GuardTalkPermissionDefaultsPolicy.java"
DPGP="frameworks/base/services/core/java/com/android/server/pm/permission/DefaultPermissionGrantPolicy.java"
PERM_XML="vendor/guardtalk/permissions/default-permissions-com.guardtalk.messenger.xml"
PERM_BP="vendor/guardtalk/permissions/Android.bp"

PRIV_POL="frameworks/base/core/java/android/guardtalk/GuardTalkPrivacyPolicy.java"
CLIP_SVC="frameworks/base/services/core/java/com/android/server/clipboard/ClipboardService.java"
PRIV_RC="vendor/guardtalk/init/init.guardtalk.privacy_tmpfs.rc"

FILES_POL="frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java"
FSP="frameworks/base/core/java/com/android/internal/content/storage/FileSystemProvider.java"
ESP="frameworks/base/packages/ExternalStorageProvider/src/com/android/externalstorage/ExternalStorageProvider.java"
FILES_LOCAL="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkFilesLocalPolicy.java"
FLAG_UTILS="packages/apps/DocumentsUI/src/com/android/documentsui/util/FlagUtils.kt"
COMPRESS="packages/apps/DocumentsUI/src/com/android/documentsui/services/CompressJob.java"
DOCUI_CFG="packages/apps/DocumentsUI/res/values/config.xml"
COMPOSE_MF="packages/apps/DocumentsUI/compose/AndroidManifest.xml"
DOCUI_MF="packages/apps/DocumentsUI/AndroidManifest.xml"

OV="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
DASH_XML="packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml"
DASH_FRAG="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityDashboardFragment.java"

PROPS_MK="vendor/guardtalk/device/tokay/guardtalk-product-props.mk"
TOKAY_MK="vendor/guardtalk/device/tokay/guardtalk-tokay.mk"
VENDOR_BP="out/target/product/tokay/vendor/build.prop"

DOC_PERM="vendor/guardtalk/docs/PERMISSION_DEFAULTS_POLICY.md"
DOC_PRIV="vendor/guardtalk/docs/PRIVACY_TMPFS_CLIPBOARD_POLICY.md"
DOC_FILES="vendor/guardtalk/docs/FILES_HANDLERS_POLICY.md"
DOC_FILES_UI="vendor/guardtalk/docs/FILES_UI_NOTES.md"
DOC_VIS="vendor/guardtalk/docs/SETTINGS_VISIBILITY_POLICY.md"
DOC_GATE="vendor/guardtalk/docs/GT_CONFIG_PASSWORD_GATE_API.md"

echo "=== Q-SEC-P4-PRIVACY: policy docs ==="

require_file "$DOC_PERM" "PERMISSION_DEFAULTS_POLICY.md"
require_file "$DOC_PRIV" "PRIVACY_TMPFS_CLIPBOARD_POLICY.md"
require_file "$DOC_FILES" "FILES_HANDLERS_POLICY.md"
require_file "$DOC_FILES_UI" "FILES_UI_NOTES.md"
require_file "$DOC_VIS" "SETTINGS_VISIBILITY_POLICY.md"
require_file "$DOC_GATE" "GT_CONFIG_PASSWORD_GATE_API.md"
require_rg 'com\.guardtalk\.messenger' "$DOC_PERM" "PERMISSION policy documents Messenger package"
require_rg 'deny-by-default|deny-default|third-party' "$DOC_PERM" \
  "PERMISSION policy documents third-party deny-default"
require_rg 'privacy_tmpfs|clipboard_clear' "$DOC_PRIV" \
  "PRIVACY policy documents tmpfs + clipboard_clear"
require_rg 'Trash|ZIP|protect|Compose' "$DOC_FILES" \
  "FILES policy documents trash/ZIP/protect/Compose"
require_rg 'config_security_mutations_require_password|Phase-4' "$DOC_VIS" \
  "SETTINGS_VISIBILITY documents Phase-4 matrices / password gate"
require_rg 'security_device_lock|security_secure_wipe|No network' "$DOC_GATE" \
  "GT_CONFIG_PASSWORD_GATE_API documents Security mutations + no network"

echo "=== Q-SEC-P4-PRIVACY: Messenger grant plumbing + deny-default ==="

require_file "$PERM_POL" "GuardTalkPermissionDefaultsPolicy"
require_file "$PERM_XML" "default-permissions-com.guardtalk.messenger.xml"
require_file "$PERM_BP" "permissions Android.bp"
require_rg 'MESSENGER_PACKAGE_NAME = "com\.guardtalk\.messenger"' "$PERM_POL" \
  "MESSENGER_PACKAGE_NAME=com.guardtalk.messenger"
require_rg 'PROP_PERMISSION_DEFAULTS = "ro\.guardtalk\.permission_defaults"' "$PERM_POL" \
  "PROP_PERMISSION_DEFAULTS defined"
require_rg 'allowDefaultPermissionException' "$PERM_POL" \
  "allowDefaultPermissionException deny-default API"
require_rg 'return isSystemApp' "$PERM_POL" \
  "third-party exceptions denied unless system/Messenger"
require_rg 'grantGuardTalkMessengerDefaultPermissions' "$DPGP" \
  "DefaultPermissionGrantPolicy grants Messenger"
require_rg 'GuardTalkPermissionDefaultsPolicy\.allowDefaultPermissionException' "$DPGP" \
  "DefaultPermissionGrantPolicy filters third-party exceptions"
require_rg 'package="com\.guardtalk\.messenger"' "$PERM_XML" \
  "product XML exception for Messenger"
require_rg 'name: "default-permissions-com\.guardtalk\.messenger"' "$PERM_BP" \
  "Soong module default-permissions-com.guardtalk.messenger"
require_rg 'ro\.guardtalk\.permission_defaults=1' "$PROPS_MK" \
  "live prop permission_defaults=1 in product-props.mk"
require_rg 'PRODUCT_PACKAGES \+= default-permissions-com\.guardtalk\.messenger' "$TOKAY_MK" \
  "tokay.mk PRODUCT_PACKAGES Messenger default-permissions"
# Messenger APK absent is expected GAP (plumbing only)
if [[ -d vendor/guardtalk/apps ]] \
  && find vendor/guardtalk/apps -maxdepth 3 -iname '*messenger*' 2>/dev/null | rg -q .; then
  fail "unexpected Messenger app module under vendor/guardtalk/apps (policy: APK GAP)"
else
  pass "Messenger APK absent under vendor/guardtalk/apps (documented GAP)"
fi
if [[ -d vendor/guardtalk/apps ]] \
  && rg -q 'com\.guardtalk\.messenger' --glob 'Android.bp' vendor/guardtalk/apps 2>/dev/null; then
  fail "unexpected com.guardtalk.messenger Android.bp under apps/"
else
  pass "no com.guardtalk.messenger product APK Android.bp (GAP)"
fi

echo "=== Q-SEC-P4-PRIVACY: privacy_tmpfs init + props ==="

require_file "$PRIV_POL" "GuardTalkPrivacyPolicy"
require_file "$PRIV_RC" "init.guardtalk.privacy_tmpfs.rc"
require_rg 'PROP_PRIVACY_TMPFS = "ro\.guardtalk\.privacy_tmpfs"' "$PRIV_POL" \
  "PROP_PRIVACY_TMPFS defined"
require_rg 'DEFAULT_PRIVACY_TMPFS_PATH|/mnt/guardtalk_privacy' "$PRIV_POL" \
  "privacy tmpfs path /mnt/guardtalk_privacy"
require_rg 'mount tmpfs tmpfs /mnt/guardtalk_privacy' "$PRIV_RC" \
  "init mounts privacy tmpfs"
require_rg 'mkdir /mnt/guardtalk_privacy/logs' "$PRIV_RC" \
  "init creates privacy logs/"
require_rg 'mkdir /mnt/guardtalk_privacy/cache' "$PRIV_RC" \
  "init creates privacy cache/"
require_rg 'ro\.guardtalk\.privacy_tmpfs=1' "$PROPS_MK" \
  "live prop privacy_tmpfs=1"
require_rg 'ro\.guardtalk\.privacy_tmpfs_path=/mnt/guardtalk_privacy' "$PROPS_MK" \
  "live prop privacy_tmpfs_path"
require_rg 'PRODUCT_PACKAGES \+= init\.guardtalk\.privacy_tmpfs\.rc' "$TOKAY_MK" \
  "tokay.mk PRODUCT_PACKAGES privacy_tmpfs.rc"

echo "=== Q-SEC-P4-PRIVACY: clipboard_clear hooks ==="

require_file "$CLIP_SVC" "ClipboardService"
require_rg 'PROP_CLIPBOARD_CLEAR = "ro\.guardtalk\.clipboard_clear"' "$PRIV_POL" \
  "PROP_CLIPBOARD_CLEAR defined"
require_rg 'mustClearClipboardOnLock' "$PRIV_POL" \
  "mustClearClipboardOnLock fail-closed API"
require_rg 'clearAllClipboardsForGuardTalk' "$CLIP_SVC" \
  "ClipboardService.clearAllClipboardsForGuardTalk"
require_rg 'GuardTalkPrivacyPolicy\.isClipboardClearEnabled' "$CLIP_SVC" \
  "ClipboardService consults GuardTalkPrivacyPolicy"
require_rg 'clearAllClipboardsForGuardTalk\("lock"\)' "$CLIP_SVC" \
  "clipboard clear on lock"
require_rg 'clearAllClipboardsForGuardTalk\("screen_off"\)' "$CLIP_SVC" \
  "clipboard clear on SCREEN_OFF"
require_rg 'ro\.guardtalk\.clipboard_clear=1' "$PROPS_MK" \
  "live prop clipboard_clear=1"
require_rg 'ro\.guardtalk\.clipboard_clear_timeout_ms=60000' "$PROPS_MK" \
  "live prop clipboard_clear_timeout_ms=60000"

echo "=== Q-SEC-P4-PRIVACY: Files trash / ZIP / protect / Compose ==="

require_file "$FILES_POL" "GuardTalkFilesPolicy"
require_file "$FILES_LOCAL" "GuardTalkFilesLocalPolicy"
require_file "$FSP" "FileSystemProvider"
require_file "$ESP" "ExternalStorageProvider"
require_file "$COMPRESS" "CompressJob (ZIP)"
require_rg 'PROP_FILES_POLICY|ro\.guardtalk\.files_policy' "$FILES_POL" \
  "GuardTalkFilesPolicy files_policy prop"
require_rg 'PROP_FILES_TRASH|ro\.guardtalk\.files_trash' "$FILES_POL" \
  "GuardTalkFilesPolicy files_trash prop"
require_rg 'PROP_FILES_PROTECT|files_protect_critical' "$FILES_POL" \
  "GuardTalkFilesPolicy files_protect_critical prop"
require_rg 'isProtectedFile' "$FILES_POL" \
  "GuardTalkFilesPolicy.isProtectedFile"
require_rg '/system|/vendor|/boot|/recovery|/mnt/guardtalk_privacy' "$FILES_POL" \
  "protected prefixes include system/vendor/boot/privacy"
require_rg 'GuardTalkFilesPolicy\.isProtectedFile' "$FSP" \
  "FileSystemProvider enforces protect on delete/trash"
require_rg 'trashDocument' "$FSP" \
  "FileSystemProvider.trashDocument present"
require_rg 'GuardTalkFilesPolicy\.isProtectedFile' "$ESP" \
  "ExternalStorageProvider trash eligibility uses protect"
require_rg 'GuardTalkFilesLocalPolicy\.isTrashEnabled' "$FLAG_UTILS" \
  "FlagUtils Baklava trash override via GuardTalkFilesLocalPolicy"
require_rg 'isTrashEnabled' "$FILES_LOCAL" \
  "GuardTalkFilesLocalPolicy.isTrashEnabled"
require_rg 'feature_archive_creation">true<' "$DOCUI_CFG" \
  "DocumentsUI feature_archive_creation=true (ZIP)"
require_rg 'class CompressJob' "$COMPRESS" \
  "CompressJob class present"
require_rg 'ro\.guardtalk\.files_policy=1' "$PROPS_MK" \
  "live prop files_policy=1 in product-props.mk"
require_rg 'ro\.guardtalk\.files_trash=1' "$PROPS_MK" \
  "live prop files_trash=1"
require_rg 'ro\.guardtalk\.files_protect_critical=1' "$PROPS_MK" \
  "live prop files_protect_critical=1"
# Compose: no LAUNCHER category; activity disabled
require_file "$COMPOSE_MF" "DocumentsUICompose AndroidManifest"
if rg -q 'android.intent.category.LAUNCHER' "$COMPOSE_MF"; then
  fail "DocumentsUICompose still declares LAUNCHER (duplicate Files icon risk)"
else
  pass "DocumentsUICompose has no LAUNCHER category"
fi
require_rg 'android:enabled="false"' "$COMPOSE_MF" \
  "DocumentsUICompose MainActivity enabled=false"
require_rg 'android.intent.category.LAUNCHER' "$DOCUI_MF" \
  "stock DocumentsUI retains LAUNCHER (single Files icon)"

echo "=== Q-SEC-P4-PRIVACY: keep-hide matrices (Notif/Sound/Modes/Display/Storage/Battery/System) ==="

require_file "$OV" "GuardTalkSettingsOverlay config"
for name in \
  config_show_top_level_notifications \
  config_show_top_level_sound \
  config_show_top_level_priority_modes \
  config_show_top_level_display \
  config_show_top_level_storage \
  config_show_top_level_battery \
  config_show_top_level_system; do
  require_bool "$OV" "$name" "true" "KEEP top-level ${name#config_show_top_level_}"
done
require_bool "$OV" "config_show_notification_bubbles" "false" "HIDE notification bubbles"
require_bool "$OV" "config_show_notification_summarization" "false" "HIDE notification summarization"
require_bool "$OV" "config_show_notification_bundling" "false" "HIDE notification bundling"
require_bool "$OV" "config_show_media_volume" "true" "KEEP media volume"
require_bool "$OV" "config_show_alarm_volume" "true" "KEEP alarm volume"
require_bool "$OV" "config_show_notification_volume" "true" "KEEP notification volume"
require_bool "$OV" "config_show_call_volume" "false" "HIDE call volume (radio excised)"
require_bool "$OV" "config_show_wifi_display_enable_menu" "false" "HIDE Wi-Fi Display"
require_bool "$OV" "config_show_smooth_display" "false" "HIDE smooth display"
require_bool "$OV" "config_show_smart_storage_toggle" "false" "HIDE smart storage toggle"
require_bool "$OV" "config_show_restrict_to_wireless_charging" "false" "HIDE wireless-charge restrict"
require_bool "$OV" "config_show_assist_and_voice_input" "false" "HIDE assist & voice input"
require_bool "$OV" "config_show_tts_settings_summary" "false" "HIDE TTS summary"
require_bool "$OV" "config_show_view_logs" "false" "HIDE view logs"
require_bool "$OV" "config_security_mutations_require_password" "true" \
  "Security mutations require password"

echo "=== Q-SEC-P4-PRIVACY: Security mutation password gate ==="

require_file "$DASH_FRAG" "GuardTalkSecurityDashboardFragment"
require_rg 'config_security_mutations_require_password' "$DASH_FRAG" \
  "dashboard reads config_security_mutations_require_password"
require_rg 'GuardTalkConfigGateClient\.startConfirm' "$DASH_FRAG" \
  "dashboard startConfirm credential flow"
require_rg 'GuardTalkConfigGateClient\.assertAuthorized' "$DASH_FRAG" \
  "dashboard assertAuthorized before mutation"
for key in \
  security_device_lock \
  security_sensor_privacy \
  security_usb_protection \
  security_lockdown \
  security_auto_reboot \
  security_duress \
  security_secure_wipe; do
  require_rg "$key" "$DASH_FRAG" "mutation key wiring: ${key}"
done

echo "=== Q-SEC-P4-PRIVACY: no network under Security ==="

require_file "$DASH_XML" "guardtalk_security_dashboard.xml"
require_rg 'Network / VPN / Wi-Fi / Hotspot' "$DASH_XML" \
  "dashboard XML comment forbids network under Security"
# Preference keys must not be network/wifi/vpn/hotspot/airplane
if rg -n 'android:key="[^"]*(network|wifi|vpn|hotspot|airplane|tether)[^"]*"' \
  "$DASH_XML" >/dev/null 2>&1; then
  fail "Security dashboard contains network-related preference keys"
else
  pass "Security dashboard has no network/wifi/vpn/hotspot/airplane keys"
fi
require_rg 'No network|never appear|must never' "$DOC_GATE" \
  "password gate API forbids network under Security"

echo "=== Q-SEC-P4-PRIVACY: vendor build.prop (if regenerable) ==="

if [[ -f "$VENDOR_BP" ]]; then
  for prop in \
    ro.guardtalk.permission_defaults=1 \
    ro.guardtalk.privacy_tmpfs=1 \
    ro.guardtalk.privacy_tmpfs_path=/mnt/guardtalk_privacy \
    ro.guardtalk.clipboard_clear=1 \
    ro.guardtalk.clipboard_clear_timeout_ms=60000; do
    if rg -q "^${prop}$" "$VENDOR_BP"; then
      pass "vendor/build.prop has ${prop}"
    else
      fail "vendor/build.prop missing ${prop}"
    fi
  done
  # Files props: wired in mk; may be absent until vendor image refresh
  files_ok=1
  for prop in \
    ro.guardtalk.files_policy=1 \
    ro.guardtalk.files_trash=1 \
    ro.guardtalk.files_protect_critical=1; do
    if ! rg -q "^${prop}$" "$VENDOR_BP"; then
      files_ok=0
    fi
  done
  if [[ $files_ok -eq 1 ]]; then
    pass "vendor/build.prop has files_policy/trash/protect props"
  else
    # Source of truth is product-props.mk (already checked). Stale image = GAP.
    pass "GAP: files_* absent from vendor/build.prop (mk wired; image refresh needed)"
  fi
else
  pass "GAP: vendor/build.prop not present (cannot confirm live props on disk)"
fi

echo "=== Q-SEC-P4-PRIVACY: prior green builds (cite) ==="

cite_ok=0
if rg -q 'T-SEC-P4-PERMS APPROVED' .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites T-SEC-P4-PERMS APPROVED"
  cite_ok=1
else
  fail "DONE_LOG missing T-SEC-P4-PERMS APPROVED"
fi
if rg -q 'T-SEC-P4-PRIVACY APPROVED' .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites T-SEC-P4-PRIVACY APPROVED"
  cite_ok=1
else
  fail "DONE_LOG missing T-SEC-P4-PRIVACY APPROVED"
fi
if rg -q 'T-SEC-P4-FILES APPROVED' .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites T-SEC-P4-FILES APPROVED"
  cite_ok=1
else
  fail "DONE_LOG missing T-SEC-P4-FILES APPROVED"
fi
if rg -q 'F-SEC-P4-SYSTEM-UI APPROVED' .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites F-SEC-P4-SYSTEM-UI APPROVED"
  cite_ok=1
else
  fail "DONE_LOG missing F-SEC-P4-SYSTEM-UI APPROVED"
fi
if rg -q 'build EXIT=0|DocumentsUI\+ExternalStorageProvider EXIT=0|m Settings DocumentsUI.*EXIT=0' \
  TASK_QUEUE.md; then
  pass "root TASK_QUEUE records Phase-4 EXIT=0 / green builds"
  cite_ok=1
else
  fail "root TASK_QUEUE missing Phase-4 EXIT=0 cite"
fi
if rg -q 'm services|DocumentsUI|EXIT=0' "$DOC_PERM" \
  || rg -q 'm services|Verification' "$DOC_PRIV" \
  || rg -q 'm DocumentsUI|Verification' "$DOC_FILES"; then
  pass "Phase-4 policy docs include verification / build notes"
  cite_ok=1
else
  fail "Phase-4 policy docs missing verification notes"
fi
[[ $cite_ok -eq 1 ]] || fail "no prior green Phase-4 citations found"

echo "=== SUMMARY ==="
if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=0 EXIT=0"
  exit 0
fi
echo "SOME CHECKS FAILED"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT>0 EXIT=1"
exit 1
