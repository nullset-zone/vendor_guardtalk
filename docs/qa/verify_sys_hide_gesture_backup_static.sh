#!/usr/bin/env bash
# Static verification for Q-SYS-HIDE-GESTURE-BACKUP
# (F-SYS-HIDE-GESTURE-BACKUP: hide System Gestures + Privacy Backup UI/search).
# Covers overlay bools, controller/search gates, no APK deletes for this task,
# accepted residual (Sound Prevent Ringing), and F APPROVED + Settings EXIT=0 cites.
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_sys_hide_gesture_backup_static.sh
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

# --- Paths ---
SETTINGS_CFG="packages/apps/Settings/res/values/config.xml"
OVERLAY_CFG="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
OVERLAY_README="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/README.md"
POLICY="vendor/guardtalk/docs/SETTINGS_VISIBILITY_POLICY.md"
GESTURE_CTRL="packages/apps/Settings/src/com/android/settings/gestures/GesturesSettingPreferenceController.java"
PRIVACY_UTILS="packages/apps/Settings/src/com/android/settings/backup/PrivacySettingsUtils.java"
BACKUP_INACTIVE="packages/apps/Settings/src/com/android/settings/backup/BackupInactivePreferenceController.java"
BACKUP_DATA_MGMT="packages/apps/Settings/src/com/android/settings/backup/DataManagementPreferenceController.java"
BACKUP_SETTINGS_CTRL="packages/apps/Settings/src/com/android/settings/backup/BackupSettingsPreferenceController.java"
BACKUP_FRAG="packages/apps/Settings/src/com/android/settings/backup/BackupSettingsFragment.java"
BACKUP_PRIVACY="packages/apps/Settings/src/com/android/settings/backup/PrivacySettings.java"
BACKUP_USER_ACT="packages/apps/Settings/src/com/android/settings/backup/UserBackupSettingsActivity.java"
SOUND_XML="packages/apps/Settings/res/xml/sound_settings.xml"
PREVENT_RING="packages/apps/Settings/src/com/android/settings/gestures/PreventRingingGestureSettings.java"
SETTINGS_APK="out/target/product/tokay/system_ext/priv-app/Settings/Settings.apk"
F_REPORT=".agent-comm/inbox/TO_ARCHITECT_F-SYS-HIDE.md"
ROOT_QUEUE="TASK_QUEUE.md"
AGENT_QUEUE=".agent-comm/TASK_QUEUE.md"

GESTURE_SEARCH_FILES=(
  "packages/apps/Settings/src/com/android/settings/gestures/GestureSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/SystemNavigationGestureSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/SwipeToNotificationSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/OneHandedSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/ButtonNavigationSettingsFragment.java"
  "packages/apps/Settings/src/com/android/settings/gestures/GestureNavigationSettingsFragment.java"
  "packages/apps/Settings/src/com/android/settings/gestures/DoubleTapPowerSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/DoubleTapScreenSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/PickupGestureSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/DoubleTwistGestureSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/PreventRingingGestureSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/PowerMenuSettings.java"
  "packages/apps/Settings/src/com/android/settings/gestures/TapScreenGestureSettings.java"
)

echo "=== Q-SYS-HIDE-GESTURE-BACKUP: config / overlay bools ==="

require_file "$SETTINGS_CFG" "Settings config.xml"
require_file "$OVERLAY_CFG" "GuardTalkSettingsOverlay config.xml"
require_file "$OVERLAY_README" "GuardTalkSettingsOverlay README"
require_file "$POLICY" "SETTINGS_VISIBILITY_POLICY.md"

# Settings defaults true (platform baseline; overlay overrides to false)
require_rg '<bool name="config_show_gesture_settings">true</bool>' "$SETTINGS_CFG" \
  "Settings default config_show_gesture_settings=true"
require_rg '<bool name="config_show_backup_settings">true</bool>' "$SETTINGS_CFG" \
  "Settings default config_show_backup_settings=true"

# Overlay product hide
require_rg '<bool name="config_show_gesture_settings">false</bool>' "$OVERLAY_CFG" \
  "overlay config_show_gesture_settings=false"
require_rg '<bool name="config_show_backup_settings">false</bool>' "$OVERLAY_CFG" \
  "overlay config_show_backup_settings=false"

# Overlay must not accidentally leave bools true
forbid_rg '<bool name="config_show_gesture_settings">true</bool>' "$OVERLAY_CFG" \
  "overlay does not set gesture_settings=true"
forbid_rg '<bool name="config_show_backup_settings">true</bool>' "$OVERLAY_CFG" \
  "overlay does not set backup_settings=true"

require_rg 'config_show_gesture_settings' "$OVERLAY_README" \
  "overlay README documents gesture hide bool"
require_rg 'config_show_backup_settings' "$OVERLAY_README" \
  "overlay README documents backup hide bool"
require_rg 'config_show_gesture_settings' "$POLICY" \
  "visibility policy documents gesture bool"
require_rg 'config_show_backup_settings' "$POLICY" \
  "visibility policy documents backup bool"
require_rg 'Gestures \(\`gesture_settings\`\).*false|Gestures.*config_show_gesture_settings.*\*\*false\*\*' \
  "$POLICY" "visibility policy System Gestures overlay=false"
require_rg 'Backup data.*config_show_backup_settings.*\*\*false\*\*|config_show_backup_settings.*\*\*false\*\*' \
  "$POLICY" "visibility policy Privacy Backup overlay=false"

echo "=== Q-SYS-HIDE-GESTURE-BACKUP: Gestures controller + search gates ==="

require_file "$GESTURE_CTRL" "GesturesSettingPreferenceController"
require_rg 'isGestureSettingsAvailable' "$GESTURE_CTRL" \
  "Gestures controller exposes isGestureSettingsAvailable"
require_rg 'config_show_gesture_settings' "$GESTURE_CTRL" \
  "Gestures controller reads config_show_gesture_settings"
require_rg 'UNSUPPORTED_ON_DEVICE' "$GESTURE_CTRL" \
  "Gestures controller returns UNSUPPORTED_ON_DEVICE when hidden"

for f in "${GESTURE_SEARCH_FILES[@]}"; do
  base="$(basename "$f")"
  require_file "$f" "$base"
  require_rg 'isGestureSettingsAvailable' "$f" \
    "gesture search gate: $base uses isGestureSettingsAvailable"
  require_rg 'isPageSearchEnabled' "$f" \
    "gesture search gate: $base defines isPageSearchEnabled"
done

echo "=== Q-SYS-HIDE-GESTURE-BACKUP: Backup controllers + search gates ==="

require_file "$PRIVACY_UTILS" "PrivacySettingsUtils"
require_rg 'config_show_backup_settings' "$PRIVACY_UTILS" \
  "PrivacySettingsUtils gates on config_show_backup_settings"
require_rg 'BACKUP_DATA|backup_data' "$PRIVACY_UTILS" \
  "PrivacySettingsUtils hides backup_data when overlay false"
require_rg 'AUTO_RESTORE|auto_restore' "$PRIVACY_UTILS" \
  "PrivacySettingsUtils hides auto_restore when overlay false"
require_rg 'CONFIGURE_ACCOUNT|configure_account' "$PRIVACY_UTILS" \
  "PrivacySettingsUtils hides configure_account when overlay false"
require_rg 'BACKUP_INACTIVE|backup_inactive' "$PRIVACY_UTILS" \
  "PrivacySettingsUtils hides backup_inactive when overlay false"
# Services remain: IBackupManager still referenced (hide ≠ delete)
require_rg 'IBackupManager' "$PRIVACY_UTILS" \
  "PrivacySettingsUtils still references IBackupManager (service not deleted)"

require_file "$BACKUP_INACTIVE" "BackupInactivePreferenceController"
require_rg 'config_show_backup_settings' "$BACKUP_INACTIVE" \
  "BackupInactivePreferenceController gated"
require_rg 'UNSUPPORTED_ON_DEVICE' "$BACKUP_INACTIVE" \
  "BackupInactivePreferenceController UNSUPPORTED_ON_DEVICE when hidden"

require_file "$BACKUP_DATA_MGMT" "DataManagementPreferenceController"
require_rg 'config_show_backup_settings' "$BACKUP_DATA_MGMT" \
  "DataManagementPreferenceController gated"

require_file "$BACKUP_SETTINGS_CTRL" "BackupSettingsPreferenceController"
require_rg 'config_show_backup_settings' "$BACKUP_SETTINGS_CTRL" \
  "BackupSettingsPreferenceController isAvailable gated"

require_file "$BACKUP_PRIVACY" "PrivacySettings"
require_rg 'config_show_backup_settings' "$BACKUP_PRIVACY" \
  "PrivacySettings search gated on backup bool"
require_rg 'isPageSearchEnabled' "$BACKUP_PRIVACY" \
  "PrivacySettings defines isPageSearchEnabled"

require_file "$BACKUP_FRAG" "BackupSettingsFragment"
require_rg 'config_show_backup_settings' "$BACKUP_FRAG" \
  "BackupSettingsFragment search gated"
require_rg 'isPageSearchEnabled' "$BACKUP_FRAG" \
  "BackupSettingsFragment defines isPageSearchEnabled"

require_file "$BACKUP_USER_ACT" "UserBackupSettingsActivity"
require_rg 'config_show_backup_settings' "$BACKUP_USER_ACT" \
  "UserBackupSettingsActivity search gated"
require_rg 'F-SYS-HIDE-GESTURE-BACKUP|do not index Backup' "$BACKUP_USER_ACT" \
  "UserBackupSettingsActivity documents hide search gate"

echo "=== Q-SYS-HIDE-GESTURE-BACKUP: no APK/service deletes (F-SYS-HIDE scope) ==="

# Gesture / Backup Settings sources must still exist (UI-hide, not delete)
require_file "$GESTURE_CTRL" "Gestures controller source retained"
require_file "$PRIVACY_UTILS" "Backup PrivacySettingsUtils retained"
require_file \
  "packages/apps/Settings/src/com/android/settings/gestures/GestureSettings.java" \
  "GestureSettings fragment retained"
require_file \
  "packages/apps/Settings/src/com/android/settings/backup/BackupSettingsHelper.java" \
  "BackupSettingsHelper retained"

# Overlay / policy explicitly forbid APK deletion for this feature
require_rg 'Does NOT delete|Hide ≠ delete|Hide = UI' "$OVERLAY_CFG" \
  "overlay comment: hide ≠ delete APKs/services"
require_rg 'Hide = UI|APKs stay|do not delete|≠ delete' "$POLICY" \
  "policy: hide = UI/search only; APKs/services stay"

# F-SYS-HIDE must not introduce PRODUCT_PACKAGES removals of Settings Backup/Gestures
# (pre-existing feature-excised Backup cluster is out of this task's delta)
if rg -n 'F-SYS-HIDE-GESTURE-BACKUP' vendor/guardtalk/feature-excised/ --glob '*.mk' 2>/dev/null | rg -q .; then
  fail "feature-excised references F-SYS-HIDE-GESTURE-BACKUP (unexpected APK excision tie-in)"
else
  pass "feature-excised has no F-SYS-HIDE-GESTURE-BACKUP APK excision tie-in"
fi

# No rm of gesture/backup Settings packages under vendor/guardtalk for this task
if rg -n --glob '*.{mk,sh,bp}' \
  'rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*.*(GestureSettings|BackupSettings|Settings\.apk)' \
  vendor/guardtalk/ 2>/dev/null | rg -q .; then
  fail "vendor/guardtalk contains rm targeting Gesture/Backup/Settings APK paths"
else
  pass "no vendor/guardtalk rm of Gesture/Backup/Settings APK paths"
fi

echo "=== Q-SYS-HIDE-GESTURE-BACKUP: accepted residual (Sound Prevent Ringing) ==="

require_file "$SOUND_XML" "sound_settings.xml"
require_rg 'gesture_prevent_ringing_sound' "$SOUND_XML" \
  "residual: Sound still has gesture_prevent_ringing_sound row (Architect-accepted)"
require_rg 'PreventRingingParentPreferenceController|PreventRingingGestureSettings' "$SOUND_XML" \
  "residual: Sound row wires PreventRinging controller/fragment"
# Dedicated PreventRinging search page IS gated (System Gestures path)
require_rg 'isGestureSettingsAvailable' "$PREVENT_RING" \
  "PreventRingingGestureSettings search page gated (dedicated page hidden)"
# Document residual in policy / F APPROVED note
if rg -q 'Prevent Ringing|prevent_ringing|Sound' "$ROOT_QUEUE" \
  && rg -q 'F-SYS-HIDE-GESTURE-BACKUP' "$ROOT_QUEUE"; then
  pass "TASK_QUEUE documents accepted Sound Prevent Ringing residual for F-SYS-HIDE"
else
  fail "TASK_QUEUE missing accepted Sound Prevent Ringing residual note"
fi

echo "=== Q-SYS-HIDE-GESTURE-BACKUP: F APPROVED + Settings EXIT=0 cites ==="

cite_ok=0
if [[ -f "$ROOT_QUEUE" ]] && rg -q 'F-SYS-HIDE-GESTURE-BACKUP' "$ROOT_QUEUE" \
  && rg -q 'APPROVED' "$ROOT_QUEUE"; then
  # Card header or Architect APPROVED line
  if rg -q 'F-SYS-HIDE-GESTURE-BACKUP \(Frontend\) — APPROVED|Architect APPROVED:.*2026-07-24' \
       "$ROOT_QUEUE"; then
    pass "root TASK_QUEUE cites F-SYS-HIDE-GESTURE-BACKUP APPROVED"
    cite_ok=1
  else
    fail "root TASK_QUEUE missing F-SYS-HIDE APPROVED card/line"
  fi
else
  fail "root TASK_QUEUE missing F-SYS-HIDE APPROVED"
fi

if [[ -f "$ROOT_QUEUE" ]] && rg -q 'residual Sound Prevent Ringing' "$ROOT_QUEUE"; then
  pass "root TASK_QUEUE notes residual Sound Prevent Ringing (accepted)"
else
  fail "root TASK_QUEUE missing residual Sound Prevent Ringing acceptance"
fi

if [[ -f "$F_REPORT" ]] && rg -q 'm Settings' "$F_REPORT" && rg -q 'EXIT=0' "$F_REPORT"; then
  pass "TO_ARCHITECT_F-SYS-HIDE cites m Settings EXIT=0"
  cite_ok=1
else
  fail "TO_ARCHITECT_F-SYS-HIDE missing m Settings EXIT=0 cite"
fi

if [[ -f "$AGENT_QUEUE" ]] && rg -q 'F-SYS-HIDE-GESTURE-BACKUP' "$AGENT_QUEUE" \
  && rg -q 'APPROVED' "$AGENT_QUEUE"; then
  pass "agent TASK_QUEUE lists F-SYS-HIDE-GESTURE-BACKUP APPROVED"
  cite_ok=1
else
  fail "agent TASK_QUEUE missing F-SYS-HIDE APPROVED"
fi

# Artifact smoke: Settings.apk present from F build (freshness informational).
# Use rg -a (not strings): dex/xml symbols may not be NUL-terminated C strings.
if [[ -f "$SETTINGS_APK" ]]; then
  pass "present: Settings.apk artifact (tokay)"
  if rg -a -q 'config_show_gesture_settings' "$SETTINGS_APK"; then
    pass "Settings.apk contains config_show_gesture_settings symbol"
  else
    fail "Settings.apk missing config_show_gesture_settings symbol"
  fi
  if rg -a -q 'config_show_backup_settings' "$SETTINGS_APK"; then
    pass "Settings.apk contains config_show_backup_settings symbol"
  else
    fail "Settings.apk missing config_show_backup_settings symbol"
  fi
  if rg -a -q 'isGestureSettingsAvailable' "$SETTINGS_APK"; then
    pass "Settings.apk contains isGestureSettingsAvailable symbol"
  else
    fail "Settings.apk missing isGestureSettingsAvailable symbol"
  fi
else
  fail "missing Settings.apk artifact (cannot cite build product)"
fi

[[ $cite_ok -eq 1 ]] || fail "insufficient F APPROVED / Settings EXIT=0 citations"

echo "=== SUMMARY ==="
if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=0 EXIT=0"
  exit 0
fi
echo "SOME CHECKS FAILED"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT>0 EXIT=1"
exit 1
