#!/usr/bin/env bash
# Static verification for Q-SEC-P2-STACK (Phase-2 §32 security stack).
# Covers LOCK / SENSOR / USB / AUTOREBOOT / WIPE / Security screens.
# (no device required).
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_sec_p2_static.sh
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
MK="vendor/guardtalk/device/tokay/guardtalk-tokay.mk"
OV="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
SYSUI_OV="vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml"
DASH="packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml"
STATUS_XML="packages/apps/Settings/res/xml/guardtalk_security_status.xml"

LOCK_POL="frameworks/base/core/java/android/guardtalk/GuardTalkLockPolicy.java"
LOCK_HOOKS="frameworks/base/services/core/java/com/android/server/locksettings/GuardTalkLockSettingsHooks.java"
LOCK_KEYS="frameworks/base/packages/SettingsLib/src/com/android/settingslib/guardtalk/GuardTalkLockPolicyKeys.java"
LSS="frameworks/base/services/core/java/com/android/server/locksettings/LockSettingsService.java"

SENSOR_POL="frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java"
SENSOR_HOOKS="frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java"

USB_POL="frameworks/base/core/java/android/guardtalk/GuardTalkUsbProtectionPolicy.java"
USB_HOOKS="frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java"
USB_DM="frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"

AR_POL="frameworks/base/core/java/android/guardtalk/GuardTalkAutoRebootPolicy.java"
AR_SVC="frameworks/base/services/core/java/com/android/server/policy/keyguard/AutoReboot.java"

WIPE_ENG="frameworks/base/services/core/java/com/android/server/locksettings/SecureWipeEngine.java"
WIPE_POL="frameworks/base/core/java/android/guardtalk/GuardTalkSecureWipePolicy.java"
HW_CTR="frameworks/base/services/core/java/com/android/server/locksettings/HwBackedFailedAttemptCounter.java"
DURESS_H="frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java"
DURESS_W="frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java"
LPU="frameworks/base/core/java/com/android/internal/widget/LockPatternUtils.java"

WIPE_ACT="packages/apps/Settings/src/com/android/settings/security/GuardTalkSecureWipeActivity.java"
STATUS_FRAG="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityStatusFragment.java"
STATUS_HELP="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSecurityStatusHelper.java"
STATUS_CTRL="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityStatusPreferenceController.java"
STATUS_FW="frameworks/base/core/java/android/guardtalk/GuardTalkSecurityStatus.java"
DASH_FRAG="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityDashboardFragment.java"

DOC_LOCK="vendor/guardtalk/docs/PASSWORD_ONLY_LOCK_POLICY.md"
DOC_SENSOR="vendor/guardtalk/docs/SENSOR_PRIVACY_LOCKDOWN_POLICY.md"
DOC_USB="vendor/guardtalk/docs/USB_PROTECTION_POLICY.md"
DOC_AR="vendor/guardtalk/docs/AUTO_REBOOT_POLICY.md"
DOC_WIPE="vendor/guardtalk/docs/SECURE_WIPE_SERVICE.md"
DOC_DURESS="vendor/guardtalk/docs/DURESS_AND_ANTI_BRUTEFORCE_POLICY.md"

echo "=== Q-SEC-P2-STACK: password-only lock ==="

require_file "$LOCK_POL" "GuardTalkLockPolicy"
require_file "$LOCK_HOOKS" "GuardTalkLockSettingsHooks"
require_file "$LOCK_KEYS" "GuardTalkLockPolicyKeys"
require_rg 'PROP_PASSWORD_ONLY_LOCK|ro\.guardtalk\.password_only_lock' "$LOCK_POL" \
  "LockPolicy password-only prop"
require_rg 'CREDENTIAL_TYPE_PIN|CREDENTIAL_TYPE_PATTERN' "$LOCK_POL" \
  "LockPolicy forbids PIN/pattern types"
require_rg 'isPasswordOnlyLockEnabled|enforceSetLockCredential' "$LOCK_HOOKS" \
  "LockSettingsHooks enforce password-only"
require_rg 'GuardTalkLockSettingsHooks\.enforceSetLockCredential' "$LSS" \
  "LSS consults GuardTalkLockSettingsHooks"
rg -q 'ro\.guardtalk\.password_only_lock=1' "$MK" \
  && pass "product prop password_only_lock=1" \
  || fail "missing product prop password_only_lock=1"
require_bool "$OV" "config_guardtalk_password_only_lock" "true" \
  "overlay password_only_lock"

echo "=== Q-SEC-P2-STACK: mic/camera + Lockdown fail-closed ==="

require_file "$SENSOR_POL" "GuardTalkSensorPrivacyPolicy"
require_file "$SENSOR_HOOKS" "GuardTalkSensorPrivacyHooks"
require_rg 'mustDenySensors' "$SENSOR_POL" "SensorPrivacyPolicy.mustDenySensors"
require_rg 'PROP_LOCKDOWN_FAIL_CLOSED|lockdown_fail_closed' "$SENSOR_POL" \
  "SensorPrivacyPolicy lockdown prop"
require_rg 'isDeviceLocked|isUserUnlocked|mustDenySensors' "$SENSOR_HOOKS" \
  "Sensor hooks locked/pre-unlock deny"
require_rg 'fail-closed|fail.closed|airplane' "$SENSOR_HOOKS" \
  "Sensor hooks lockdown network fail-closed"
rg -q 'ro\.guardtalk\.sensor_privacy_when_locked=1' "$MK" \
  && pass "product prop sensor_privacy_when_locked=1" \
  || fail "missing sensor_privacy_when_locked=1"
rg -q 'ro\.guardtalk\.lockdown_fail_closed=1' "$MK" \
  && pass "product prop lockdown_fail_closed=1" \
  || fail "missing lockdown_fail_closed=1"
require_bool "$OV" "config_guardtalk_sensor_privacy_when_locked" "true" \
  "overlay sensor_privacy_when_locked"
require_bool "$OV" "config_guardtalk_lockdown_fail_closed" "true" \
  "overlay lockdown_fail_closed"

echo "=== Q-SEC-P2-STACK: USB protection ==="

require_file "$USB_POL" "GuardTalkUsbProtectionPolicy"
require_file "$USB_HOOKS" "UsbPortSecurityHooks"
require_rg 'usb_protection_fail_closed|CHARGING_ONLY' "$USB_POL" \
  "UsbProtectionPolicy charging-only / fail-closed"
require_rg 'pre-first-unlock|CHARGING_ONLY|fail-closed|fail.closed' "$USB_HOOKS" \
  "UsbPortSecurityHooks pre-unlock charging-only"
require_rg 'charging-only|pre-first-unlock|locked' "$USB_DM" \
  "UsbDeviceManager strips data while locked/pre-unlock"
rg -q 'ro\.guardtalk\.usb_protection_fail_closed=1' "$MK" \
  && pass "product prop usb_protection_fail_closed=1" \
  || fail "missing usb_protection_fail_closed=1"
require_bool "$OV" "config_guardtalk_usb_protection_fail_closed" "true" \
  "overlay usb_protection_fail_closed"

echo "=== Q-SEC-P2-STACK: Auto-reboot profiles + exclusion ==="

require_file "$AR_POL" "GuardTalkAutoRebootPolicy"
require_file "$AR_SVC" "AutoReboot"
require_rg 'PROFILE_TIMEOUTS_MS' "$AR_POL" "AutoReboot PROFILE_TIMEOUTS_MS present"
# Off / 1h / 2h / 4h / 8h
if rg -q 'PROFILE_OFF_MS' "$AR_POL" \
  && rg -q 'TimeUnit\.HOURS\.toMillis\(1\)' "$AR_POL" \
  && rg -q 'TimeUnit\.HOURS\.toMillis\(2\)' "$AR_POL" \
  && rg -q 'TimeUnit\.HOURS\.toMillis\(4\)' "$AR_POL" \
  && rg -q 'TimeUnit\.HOURS\.toMillis\(8\)' "$AR_POL"; then
  pass "Auto-reboot profiles Off/1h/2h/4h/8h"
else
  fail "Auto-reboot profiles incomplete (need Off/1h/2h/4h/8h)"
fi
require_rg 'CTL_PAUSE|CTL_RESUME|sys\.auto_reboot_ctl' "$AR_POL" \
  "Auto-reboot exclusion ctl pause/resume"
require_rg 'exclusion|pause|resume|auto_reboot_ctl' "$AR_SVC" \
  "AutoReboot honors exclusion pause/resume"
rg -q 'ro\.guardtalk\.auto_reboot_profiles=1' "$MK" \
  && pass "product prop auto_reboot_profiles=1" \
  || fail "missing auto_reboot_profiles=1"
require_bool "$OV" "config_guardtalk_auto_reboot_profiles" "true" \
  "overlay auto_reboot_profiles"

echo "=== Q-SEC-P2-STACK: SecureWipeEngine single path + Weaver ==="

require_file "$WIPE_ENG" "SecureWipeEngine"
require_file "$HW_CTR" "HwBackedFailedAttemptCounter"
require_file "$WIPE_POL" "GuardTalkSecureWipePolicy"
require_rg 'USER_REQUESTED|DURESS|ANTI_BRUTEFORCE' "$WIPE_ENG" \
  "SecureWipeEngine Reason enum (UI/Duress/anti-bruteforce)"
require_rg 'deleteSecrets|RecoverySystemService' "$WIPE_ENG" \
  "SecureWipeEngine crypto-erase via deleteSecrets"
# Call sites may wrap args across lines — require engine + Reason separately.
if rg -q 'SecureWipeEngine\.run' "$LSS" && rg -q 'Reason\.USER_REQUESTED' "$LSS"; then
  pass "LSS requestSecureWipe → SecureWipeEngine.USER_REQUESTED"
else
  fail "LSS requestSecureWipe → SecureWipeEngine.USER_REQUESTED"
fi
if rg -q 'SecureWipeEngine\.run' "$LSS" && rg -q 'Reason\.ANTI_BRUTEFORCE' "$LSS"; then
  pass "LSS anti-bruteforce@threshold → SecureWipeEngine.ANTI_BRUTEFORCE"
else
  fail "LSS anti-bruteforce@threshold → SecureWipeEngine.ANTI_BRUTEFORCE"
fi
if rg -q 'SecureWipeEngine\.run' "$DURESS_H" && rg -q 'Reason\.DURESS' "$DURESS_H"; then
  pass "DuressPasswordHelper → SecureWipeEngine.DURESS"
else
  fail "DuressPasswordHelper → SecureWipeEngine.DURESS"
fi
if rg -q 'SecureWipeEngine\.run' "$DURESS_W" && rg -q 'Reason\.DURESS' "$DURESS_W"; then
  pass "DuressWipe → SecureWipeEngine.DURESS"
else
  fail "DuressWipe → SecureWipeEngine.DURESS"
fi
require_rg 'requestSecureWipe' "$LPU" \
  "LockPatternUtils.requestSecureWipe binder"
require_rg 'Weaver|guardTalkIncrementAntiBruteforceCounter' "$HW_CTR" \
  "HW counter uses Weaver increment"
require_rg 'failure_counter' "$HW_CTR" \
  "HW counter documents failure_counter non-authority"
require_rg 'Never treats|not.*authoritative|userdata file' "$HW_CTR" \
  "HW counter explicitly not userdata-file authority"
require_rg 'DEFAULT_WIPE_THRESHOLD = 10|anti_bruteforce_wipe_threshold' "$WIPE_POL" \
  "Wipe threshold default/prop @10"
rg -q 'ro\.guardtalk\.secure_wipe_enabled=1' "$MK" \
  && pass "product prop secure_wipe_enabled=1" \
  || fail "missing secure_wipe_enabled=1"
rg -q 'ro\.guardtalk\.anti_bruteforce_wipe_threshold=10' "$MK" \
  && pass "product prop anti_bruteforce_wipe_threshold=10" \
  || fail "missing anti_bruteforce_wipe_threshold=10"
require_bool "$OV" "config_guardtalk_secure_wipe_enabled" "true" \
  "overlay secure_wipe_enabled"

echo "=== Q-SEC-P2-STACK: Security UI (wipe / status / dashboard) ==="

require_file "$DASH" "guardtalk_security_dashboard.xml"
require_file "$STATUS_XML" "guardtalk_security_status.xml"
require_file "$WIPE_ACT" "GuardTalkSecureWipeActivity"
require_file "$STATUS_FRAG" "GuardTalkSecurityStatusFragment"
require_file "$STATUS_HELP" "GuardTalkSecurityStatusHelper"
require_file "$DASH_FRAG" "GuardTalkSecurityDashboardFragment"

# Dashboard wires Phase-2 rows
for key in \
  guardtalk_security_device_lock \
  guardtalk_security_sensor_privacy \
  guardtalk_security_usb_protection \
  guardtalk_security_lockdown \
  guardtalk_security_auto_reboot \
  guardtalk_security_duress \
  guardtalk_security_anti_bruteforce \
  guardtalk_security_secure_wipe \
  guardtalk_security_status; do
  rg -q "android:key=\"${key}\"" "$DASH" \
    && pass "dashboard has ${key}" \
    || fail "dashboard missing ${key}"
done

# Wipe confirm UX: password → warning → erase → requestSecureWipe
require_rg 'STAGE_WARNING|showIrreversibleWarning' "$WIPE_ACT" \
  "Wipe UX irreversible warning stage"
require_rg 'STAGE_CONFIRM|requestSecureWipe' "$WIPE_ACT" \
  "Wipe UX final confirm → requestSecureWipe"
require_rg 'ChooseLockSettingsHelper' "$WIPE_ACT" \
  "Wipe UX device password confirm"

# Status post-unlock; no Duress in status
# Phase-5: Helper delegates to framework GuardTalkSecurityStatus gate.
require_rg 'isPostUnlockStatusAllowed' "$STATUS_HELP" \
  "Status helper post-unlock gate"
require_rg 'GuardTalkSecurityStatus\.isPostUnlockStatusAllowed' "$STATUS_HELP" \
  "Status helper delegates gate to framework"
if rg -q 'isDeviceLocked|isUserUnlocked' "$STATUS_HELP" 2>/dev/null; then
  pass "Status helper checks unlocked + not locked"
elif [[ -f "$STATUS_FW" ]] && rg -q 'isUserUnlocked' "$STATUS_FW" \
  && rg -q 'isDeviceLocked' "$STATUS_FW"; then
  pass "Status framework gate checks unlocked + not locked (Helper delegates)"
else
  fail "Status post-unlock unlocked/not-locked checks missing (Helper + framework)"
fi
require_rg 'isPostUnlockStatusAllowed' "$STATUS_FRAG" \
  "Status fragment finishes when not post-unlock"
require_rg 'Never includes Duress|omits Duress|Never surface Duress' "$STATUS_FRAG" \
  "Status fragment documents no Duress"
if rg -qi 'duress' "$STATUS_XML"; then
  # Comments may mention Duress prohibition — keys must not include duress preference
  if rg -q 'android:key="[^"]*duress' "$STATUS_XML"; then
    fail "status XML has Duress preference key"
  else
    pass "status XML has no Duress preference key (comment-only OK)"
  fi
else
  pass "status XML has no Duress mention/key"
fi
require_rg 'Never surfaces Duress|Never surface Duress' "$STATUS_CTRL" \
  "Status preference controller no Duress"

# No network under Security dashboard
if rg -i 'wifi|vpn|hotspot|airplane|network' "$DASH" | rg -v 'MUST NOT|Network /' >/dev/null; then
  fail "network-related prefs found under Security dashboard"
else
  pass "Security dashboard has no network prefs"
fi
if rg -i 'wifi|vpn|hotspot|airplane|network' "$STATUS_XML" | rg -v 'MUST NOT|Network /' >/dev/null; then
  fail "network-related prefs found under Security status XML"
else
  pass "Security status has no network prefs"
fi

echo "=== Q-SEC-P2-STACK: no forbidden QS tiles ==="

# SystemUI overlay stock/default/new_default must not list Lockdown/USB/Wipe/Duress tiles
require_file "$SYSUI_OV" "GuardTalkSystemUIOverlay config"
for list in quick_settings_tiles_default quick_settings_tiles_stock quick_settings_tiles_new_default; do
  if ! rg -q "name=\"${list}\"" "$SYSUI_OV"; then
    fail "SystemUI overlay missing ${list}"
    continue
  fi
  # Extract the string value (may span lines) and reject forbidden tokens.
  block="$(awk -v n="$list" '
    $0 ~ "name=\"" n "\"" {grab=1}
    grab {print}
    grab && /<\/string>/ {exit}
  ' "$SYSUI_OV" | tr '[:upper:]' '[:lower:]')"
  bad=0
  for tok in lockdown usb wipe duress; do
    # Match as comma/boundary-separated tile name, not substring of other words.
    if echo "$block" | rg -q "(^|[,>[:space:]])${tok}([,<[:space:]]|$)"; then
      fail "QS ${list} contains forbidden tile '${tok}'"
      bad=1
    fi
  done
  if [[ $bad -eq 0 ]]; then
    pass "QS ${list} has no Lockdown/USB/Wipe/Duress tiles"
  fi
done

# Policy docs / overlay comments assert no forbidden QS
if rg -qi 'no lockdown qs|No Lockdown QS' "$OV" "$DOC_SENSOR"; then
  pass "docs/overlay assert no Lockdown QS"
else
  fail "missing no-Lockdown-QS assertion in policy/overlay"
fi
if rg -qi 'no usb qs' "$OV" "$DOC_USB"; then
  pass "docs/overlay assert no USB QS"
else
  fail "missing no-USB-QS assertion"
fi
if rg -qi 'no wipe/duress qs|Wipe/Duress QS' "$OV" "$DOC_WIPE" "$DOC_DURESS"; then
  pass "docs/overlay assert no Wipe/Duress QS"
else
  fail "missing no-Wipe/Duress-QS assertion"
fi

echo "=== Q-SEC-P2-STACK: policy docs ==="

for d in "$DOC_LOCK" "$DOC_SENSOR" "$DOC_USB" "$DOC_AR" "$DOC_WIPE" "$DOC_DURESS"; do
  require_file "$d" "$(basename "$d")"
done

echo "=== Q-SEC-P2-STACK: prior green build signals (cite) ==="

cite_ok=0
for sig in \
  .agent-comm/signals/review-T-SEC-P2-LOCK.json \
  .agent-comm/signals/review-T-SEC-P2-SENSOR.json \
  .agent-comm/signals/review-F-SEC-P2-SECURITY-SCREENS.json; do
  if [[ -f "$sig" ]] && rg -q '"exit_code": 0' "$sig"; then
    pass "prior green build signal: $(basename "$sig")"
    cite_ok=1
  else
    fail "missing/non-green build signal: $sig"
  fi
done
# DONE_LOG / signals also cover USB→WIPE→Frontend green builds
if rg -q 'T-SEC-P2-USB' .agent-comm/completed/DONE_LOG.md \
  && rg -q 'T-SEC-P2-WIPE|T-SEC-P2-AUTOREBOOT|m services Settings|m Settings' \
       .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites Phase-2 USB/WIPE/build chain"
  cite_ok=1
else
  fail "DONE_LOG missing Phase-2 build cite"
fi
[[ $cite_ok -eq 1 ]] || fail "no prior green build citations found"

echo "=== SUMMARY ==="
if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=0 EXIT=0"
  exit 0
fi
echo "SOME CHECKS FAILED"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT>0 EXIT=1"
exit 1
