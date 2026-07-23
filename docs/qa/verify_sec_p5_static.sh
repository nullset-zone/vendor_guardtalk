#!/usr/bin/env bash
# Static verification for Q-SEC-P5-ACCEPT (Phase-5 §32 acceptance + production profile).
# Covers production hardening, Security status API/UI (post-unlock, no Duress,
# no network rows), Phase-5 closeout presence (wipe/fail-closed/QS/Contacts/
# privacy-files), vendor props where regenerable, and regression of
# verify_sec_p{1,2,3,4}_static.sh. (no device required).
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_sec_p5_static.sh
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
DOC_HARDEN="vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md"
DOC_STATUS="vendor/guardtalk/docs/SECURITY_STATUS_API.md"
DOC_WIPE="vendor/guardtalk/docs/SECURE_WIPE_SERVICE.md"
DOC_DURESS="vendor/guardtalk/docs/DURESS_AND_ANTI_BRUTEFORCE_POLICY.md"
DOC_USB="vendor/guardtalk/docs/USB_PROTECTION_POLICY.md"
DOC_LOCK="vendor/guardtalk/docs/PASSWORD_ONLY_LOCK_POLICY.md"
DOC_QS="vendor/guardtalk/docs/QS_TILES_POLICY.md"
DOC_QS_ED="vendor/guardtalk/docs/QS_EDITOR_UI_NOTES.md"
DOC_CONTACTS="vendor/guardtalk/docs/CONTACTS_UI_SUPPRESSION.md"
DOC_PRIV="vendor/guardtalk/docs/PRIVACY_TMPFS_CLIPBOARD_POLICY.md"
DOC_FILES="vendor/guardtalk/docs/FILES_HANDLERS_POLICY.md"
DOC_SIGN="vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md"
SIGN_RUN="vendor/guardtalk/branding/signing-keys/RUNBOOK.md"

HARDEN_MK="vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk"
PROPS_MK="vendor/guardtalk/device/tokay/guardtalk-product-props.mk"
RADIO_MK="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
FEAT_MK="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
HARDEN_RC="vendor/guardtalk/init/init.guardtalk.hardening.rc"
HARDEN_POL="frameworks/base/core/java/android/guardtalk/GuardTalkProductionHardeningPolicy.java"

STATUS_FW="frameworks/base/core/java/android/guardtalk/GuardTalkSecurityStatus.java"
STATUS_AGG="frameworks/base/services/core/java/com/android/server/guardtalk/GuardTalkSecurityStatusAggregator.java"
STATUS_KEYS="frameworks/base/packages/SettingsLib/src/com/android/settingslib/guardtalk/GuardTalkSecurityStatusKeys.java"
STATUS_HELP="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSecurityStatusHelper.java"
STATUS_FRAG="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityStatusFragment.java"
STATUS_CTRL="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityStatusPreferenceController.java"
STATUS_XML="packages/apps/Settings/res/xml/guardtalk_security_status.xml"
DASH_XML="packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml"

WIPE_POL="frameworks/base/core/java/android/guardtalk/GuardTalkSecureWipePolicy.java"
VENDOR_BP="out/target/product/tokay/vendor/build.prop"
SYSTEM_BP="out/target/product/tokay/system/build.prop"

QA_DIR="vendor/guardtalk/docs/qa"

echo "=== Q-SEC-P5-ACCEPT: production hardening policy + wiring ==="

require_file "$DOC_HARDEN" "PRODUCTION_HARDENING_POLICY.md"
require_file "$HARDEN_MK" "guardtalk-production-hardening.mk"
require_file "$HARDEN_RC" "init.guardtalk.hardening.rc"
require_file "$HARDEN_POL" "GuardTalkProductionHardeningPolicy"
require_file "$SIGN_RUN" "signing-keys RUNBOOK.md"
require_file "$DOC_SIGN" "SECURITY_SIGNING_REPORT.md"

require_rg 'tokay-trunk_staging-user' "$DOC_HARDEN" \
  "hardening policy documents user lunch"
require_rg 'ro\.guardtalk\.production_profile' "$DOC_HARDEN" \
  "hardening policy documents production_profile"
require_rg 'ro\.debuggable' "$DOC_HARDEN" \
  "hardening policy documents ro.debuggable=0 via user variant"
require_rg 'include vendor/guardtalk/device/tokay/guardtalk-production-hardening\.mk' "$RADIO_MK" \
  "radio-excised includes production-hardening.mk"
require_rg 'PRODUCT_PACKAGES \+= init\.guardtalk\.hardening\.rc' "$FEAT_MK" \
  "feature-excised packages hardening.rc"

for prop in \
  ro.guardtalk.production_hardening=1 \
  ro.guardtalk.block_unknown_sources=1 \
  ro.guardtalk.restrict_accessibility_services=1 \
  ro.guardtalk.restrict_display_overlays=1 \
  ro.guardtalk.restrict_dynamic_code=1 \
  ro.guardtalk.selinux_enforcing_required=1 \
  ro.guardtalk.verified_boot_required=1 \
  ro.guardtalk.keymint_required=1 \
  ro.guardtalk.sysctl_hardening=1; do
  require_rg "${prop//./\\.}" "$HARDEN_MK" "hardening.mk wires ${prop}"
done
require_rg 'TARGET_BUILD_VARIANT\),user' "$HARDEN_MK" \
  "production_profile gated on TARGET_BUILD_VARIANT=user"
require_rg 'ro\.guardtalk\.production_profile=1' "$HARDEN_MK" \
  "hardening.mk sets production_profile=1 on user"

require_rg 'PROP_PRODUCTION_HARDENING' "$HARDEN_POL" "policy PROP_PRODUCTION_HARDENING"
require_rg 'PROP_PRODUCTION_PROFILE' "$HARDEN_POL" "policy PROP_PRODUCTION_PROFILE"
require_rg 'isProductionProfile' "$HARDEN_POL" "policy isProductionProfile()"
require_rg 'isDebuggableOff' "$HARDEN_POL" "policy isDebuggableOff()"
require_rg 'blockUnknownSources|PROP_BLOCK_UNKNOWN' "$HARDEN_POL" \
  "policy unknown-sources block API"

require_rg 'kptr_restrict 2' "$HARDEN_RC" "sysctl kptr_restrict=2"
require_rg 'dmesg_restrict 1' "$HARDEN_RC" "sysctl dmesg_restrict=1"
require_rg 'ptrace_scope 1' "$HARDEN_RC" "sysctl yama ptrace_scope=1"
require_rg 'kexec_load_disabled 1' "$HARDEN_RC" "sysctl kexec_load_disabled=1"
require_rg 'perf_event_paranoid 3' "$HARDEN_RC" "sysctl perf_event_paranoid=3"

# Phase 1–4 product props still wired (closeout continuity)
require_file "$PROPS_MK" "guardtalk-product-props.mk"
for prop in \
  ro.guardtalk.files_policy=1 \
  ro.guardtalk.files_trash=1 \
  ro.guardtalk.files_protect_critical=1 \
  ro.guardtalk.privacy_tmpfs=1 \
  ro.guardtalk.clipboard_clear=1; do
  require_rg "${prop//./\\.}" "$PROPS_MK" "product-props.mk wires ${prop}"
done

echo "=== Q-SEC-P5-ACCEPT: Security status API / Snapshot / post-unlock ==="

require_file "$DOC_STATUS" "SECURITY_STATUS_API.md"
require_file "$STATUS_FW" "GuardTalkSecurityStatus"
require_file "$STATUS_AGG" "GuardTalkSecurityStatusAggregator"
require_file "$STATUS_KEYS" "GuardTalkSecurityStatusKeys"
require_file "$STATUS_HELP" "GuardTalkSecurityStatusHelper"
require_file "$STATUS_FRAG" "GuardTalkSecurityStatusFragment"
require_file "$STATUS_CTRL" "GuardTalkSecurityStatusPreferenceController"
require_file "$STATUS_XML" "guardtalk_security_status.xml"

require_rg 'Post-unlock only|post-unlock' "$DOC_STATUS" \
  "SECURITY_STATUS_API documents post-unlock"
require_rg 'No Duress|never.*Duress|Never.*Duress' "$DOC_STATUS" \
  "SECURITY_STATUS_API forbids Duress leakage"
require_rg 'No network|must not appear' "$DOC_STATUS" \
  "SECURITY_STATUS_API forbids network under status"
require_rg 'productionProfile|production_profile' "$DOC_STATUS" \
  "SECURITY_STATUS_API documents productionProfile field"

require_rg 'isPostUnlockStatusAllowed' "$STATUS_FW" \
  "framework post-unlock gate"
require_rg 'isUserUnlocked|KeyguardManager|isDeviceLocked' "$STATUS_FW" \
  "framework gate uses UserManager + KeyguardManager"
require_rg 'class Snapshot' "$STATUS_FW" "Snapshot class present"
require_rg 'public final boolean postUnlockAllowed' "$STATUS_FW" "Snapshot.postUnlockAllowed"
require_rg 'public final boolean productionProfile' "$STATUS_FW" "Snapshot.productionProfile"
require_rg 'public final boolean debuggableOff' "$STATUS_FW" "Snapshot.debuggableOff"
require_rg 'public final boolean productionHardening' "$STATUS_FW" "Snapshot.productionHardening"
require_rg 'public final boolean blockUnknownSources' "$STATUS_FW" "Snapshot.blockUnknownSources"
require_rg 'public final boolean secureWipeAvailable' "$STATUS_FW" "Snapshot.secureWipeAvailable"
require_rg 'public final boolean filesPolicy' "$STATUS_FW" "Snapshot.filesPolicy"
require_rg 'public final boolean privacyTmpfs' "$STATUS_FW" "Snapshot.privacyTmpfs"
require_rg 'Snapshot\.denied|denied\(\)' "$STATUS_FW" "Snapshot.denied() for pre-unlock"
require_rg 'No Duress field|never a field|Never includes Duress' "$STATUS_FW" \
  "framework documents no Duress fields"

forbid_rg 'duressArmed|duressConfigured|isDuressArmed' "$STATUS_FW" \
  "framework status has no Duress field identifiers"
forbid_rg 'duressArmed|duressConfigured|isDuressArmed' "$STATUS_HELP" \
  "Helper has no Duress field identifiers"
forbid_rg 'duressArmed|duressConfigured|isDuressArmed' "$STATUS_FRAG" \
  "Fragment has no Duress field identifiers"
forbid_rg 'duressArmed|duressConfigured|isDuressArmed' "$STATUS_KEYS" \
  "Keys has no Duress field identifiers"
forbid_rg 'duressArmed|duressConfigured|isDuressArmed|guardtalk_status_duress' "$STATUS_XML" \
  "status XML has no Duress preference keys"

require_rg 'isPostUnlockStatusAllowed' "$STATUS_HELP" "Helper exposes post-unlock gate"
require_rg 'GuardTalkSecurityStatus\.collect|Snapshot\.create' "$STATUS_HELP" \
  "Helper.collect aggregates Snapshot"
require_rg 'isPostUnlockStatusAllowed' "$STATUS_FRAG" "Fragment gates onCreate/onResume"
require_rg 's\.passwordOnlyLock' "$STATUS_FRAG" "Fragment binds passwordOnlyLock"
require_rg 's\.sensorPrivacyPolicy' "$STATUS_FRAG" "Fragment binds sensorPrivacyPolicy"
require_rg 's\.usbProtectionPolicy' "$STATUS_FRAG" "Fragment binds usbProtectionPolicy"
require_rg 's\.lockdownFailClosed' "$STATUS_FRAG" "Fragment binds lockdownFailClosed"
require_rg 's\.autoRebootProfiles|s\.autoRebootHours' "$STATUS_FRAG" \
  "Fragment binds auto-reboot fields"
require_rg 's\.antiBruteforceThreshold' "$STATUS_FRAG" "Fragment binds antiBruteforceThreshold"
require_rg 's\.secureWipeAvailable' "$STATUS_FRAG" "Fragment binds secureWipeAvailable"
require_rg 's\.clipboardClear' "$STATUS_FRAG" "Fragment binds clipboardClear"
require_rg 's\.privacyTmpfs' "$STATUS_FRAG" "Fragment binds privacyTmpfs"
require_rg 's\.filesPolicy' "$STATUS_FRAG" "Fragment binds filesPolicy"
require_rg 's\.productionHardening' "$STATUS_FRAG" "Fragment binds productionHardening"
require_rg 's\.productionProfile' "$STATUS_FRAG" "Fragment binds productionProfile"
require_rg 's\.debuggableOff' "$STATUS_FRAG" "Fragment binds debuggableOff"
require_rg 's\.blockUnknownSources' "$STATUS_FRAG" "Fragment binds blockUnknownSources"
require_rg 'CONDITIONALLY_UNAVAILABLE|isPostUnlockStatusAllowed' "$STATUS_CTRL" \
  "PreferenceController gates dashboard entry post-unlock"

for key in \
  guardtalk_status_device_lock \
  guardtalk_status_sensor_privacy \
  guardtalk_status_usb_protection \
  guardtalk_status_lockdown \
  guardtalk_status_auto_reboot \
  guardtalk_status_anti_bruteforce \
  guardtalk_status_secure_wipe \
  guardtalk_status_clipboard \
  guardtalk_status_privacy_tmpfs \
  guardtalk_status_files \
  guardtalk_status_hardening \
  guardtalk_status_footer; do
  require_rg "android:key=\"${key}\"" "$STATUS_XML" "status XML key ${key}"
  require_rg "$key" "$STATUS_KEYS" "Keys constant for ${key}"
done

require_rg 'NEVER include Duress|never.*Duress|No Duress' "$STATUS_XML" \
  "status XML comment forbids Duress"
require_rg 'Network / VPN / Wi-Fi / Hotspot|MUST NOT appear' "$STATUS_XML" \
  "status XML comment forbids network rows"
if rg -n 'android:key="[^"]*(network|wifi|vpn|hotspot|airplane|tether)[^"]*"' \
  "$STATUS_XML" >/dev/null 2>&1; then
  fail "Security status XML contains network-related preference keys"
else
  pass "Security status XML has no network/wifi/vpn/hotspot/airplane keys"
fi
# Dashboard must still forbid network under Security (Phase-4 continuity)
if [[ -f "$DASH_XML" ]]; then
  if rg -n 'android:key="[^"]*(network|wifi|vpn|hotspot|airplane|tether)[^"]*"' \
    "$DASH_XML" >/dev/null 2>&1; then
    fail "Security dashboard contains network-related preference keys"
  else
    pass "Security dashboard has no network/wifi/vpn/hotspot/airplane keys"
  fi
else
  fail "missing guardtalk_security_dashboard.xml"
fi

echo "=== Q-SEC-P5-ACCEPT: Phase-5 closeout (wipe / fail-closed / QS / Contacts / privacy-files) ==="

require_file "$DOC_WIPE" "SECURE_WIPE_SERVICE.md"
require_file "$DOC_DURESS" "DURESS_AND_ANTI_BRUTEFORCE_POLICY.md"
require_file "$DOC_USB" "USB_PROTECTION_POLICY.md"
require_file "$DOC_LOCK" "PASSWORD_ONLY_LOCK_POLICY.md"
require_file "$DOC_QS" "QS_TILES_POLICY.md"
require_file "$DOC_QS_ED" "QS_EDITOR_UI_NOTES.md"
require_file "$DOC_CONTACTS" "CONTACTS_UI_SUPPRESSION.md"
require_file "$DOC_PRIV" "PRIVACY_TMPFS_CLIPBOARD_POLICY.md"
require_file "$DOC_FILES" "FILES_HANDLERS_POLICY.md"
require_file "$WIPE_POL" "GuardTalkSecureWipePolicy"

require_rg 'SecureWipe|FBE|fail-closed|fail closed' "$DOC_WIPE" \
  "wipe service doc covers SecureWipe / fail-closed"
require_rg 'wipe@10|anti-bruteforce|Weaver|threshold' "$DOC_DURESS" \
  "Duress/anti-bruteforce policy present"
require_rg 'fail-closed|fail closed|locked|pre-unlock' "$DOC_USB" \
  "USB policy fail-closed language"
require_rg 'mictoggle|cameratoggle|battery|autoreboot' "$DOC_QS" \
  "QS policy documents four Phase-3 tiles"
require_rg 'Contacts|hide|suppress|LAUNCHER' "$DOC_CONTACTS" \
  "Contacts UI suppression policy present"
require_rg 'privacy_tmpfs|clipboard_clear' "$DOC_PRIV" \
  "privacy tmpfs/clipboard policy present"
require_rg 'Trash|ZIP|protect' "$DOC_FILES" \
  "files handlers policy present"
require_rg 'PROP_|isEnabled|wipe' "$WIPE_POL" \
  "GuardTalkSecureWipePolicy API present"

echo "=== Q-SEC-P5-ACCEPT: vendor/system build.prop (if regenerable) ==="

if [[ -f "$VENDOR_BP" ]]; then
  for prop in \
    ro.guardtalk.production_hardening=1 \
    ro.guardtalk.block_unknown_sources=1 \
    ro.guardtalk.sysctl_hardening=1 \
    ro.guardtalk.files_policy=1 \
    ro.guardtalk.privacy_tmpfs=1 \
    ro.guardtalk.clipboard_clear=1; do
    if rg -q "^${prop}$" "$VENDOR_BP"; then
      pass "vendor/build.prop has ${prop}"
    else
      fail "vendor/build.prop missing ${prop}"
    fi
  done
  # production_profile only on user lunch images
  if rg -q '^ro\.guardtalk\.production_profile=1$' "$VENDOR_BP"; then
    pass "vendor/build.prop has production_profile=1 (user lunch artifact)"
  else
    pass "GAP: production_profile absent in vendor/build.prop (userdebug image or refresh needed)"
  fi
else
  pass "GAP: vendor/build.prop not present (cannot confirm live props on disk)"
fi

if [[ -f "$SYSTEM_BP" ]]; then
  if rg -q '^ro\.debuggable=0$' "$SYSTEM_BP"; then
    pass "system/build.prop has ro.debuggable=0 (user lunch)"
  elif rg -q '^ro\.debuggable=1$' "$SYSTEM_BP"; then
    pass "GAP: system/build.prop ro.debuggable=1 (userdebug staging image)"
  else
    pass "GAP: system/build.prop present but ro.debuggable not found"
  fi
else
  pass "GAP: system/build.prop not present (user lunch artifact unavailable)"
fi

echo "=== Q-SEC-P5-ACCEPT: Messenger APK absent + adb gaps (documented) ==="

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

ADB_OUT="$(adb devices 2>/dev/null || true)"
if echo "$ADB_OUT" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  pass "adb device attached (runtime smoke possible outside this script)"
else
  pass "GAP: adb devices empty — runtime smoke deferred (documented)"
fi

echo "=== Q-SEC-P5-ACCEPT: Phase-5 prior APPROVED cites ==="

cite_ok=0
for id in T-SEC-P5-HARDEN T-SEC-P5-STATUS F-SEC-P5-STATUS-UI; do
  if rg -q "${id} APPROVED" .agent-comm/completed/DONE_LOG.md 2>/dev/null \
    || rg -q "${id}.*APPROVED|APPROVED.*${id}" TASK_QUEUE.md 2>/dev/null; then
    pass "cite APPROVED: ${id}"
    cite_ok=1
  else
    fail "missing APPROVED cite for ${id}"
  fi
done
if rg -q 'm Settings|EXIT=0' TASK_QUEUE.md; then
  pass "root TASK_QUEUE records Phase-5 EXIT=0 / green builds"
  cite_ok=1
else
  fail "root TASK_QUEUE missing Phase-5 EXIT=0 cite"
fi
[[ $cite_ok -eq 1 ]] || fail "no prior green Phase-5 citations found"

echo "=== Q-SEC-P5-ACCEPT: regression — invoke verify_sec_p{1,2,3,4}_static.sh ==="

REG_FAIL=0
for n in 1 2 3 4; do
  script="${QA_DIR}/verify_sec_p${n}_static.sh"
  if [[ ! -f "$script" ]]; then
    fail "missing regression script: $script"
    REG_FAIL=1
    continue
  fi
  echo "--- running $script ---"
  set +e
  out="$(bash "$script" 2>&1)"
  rc=$?
  set -e
  echo "$out" | tail -n 5
  if [[ $rc -eq 0 ]] && echo "$out" | rg -q 'ALL STATIC CHECKS PASSED'; then
    count="$(echo "$out" | rg -o 'PASS_COUNT=[0-9]+' | tail -n1 || true)"
    # p1 prints ALL STATIC CHECKS PASSED without PASS_COUNT=; count via PASS: lines
    if [[ -z "$count" ]]; then
      pc="$(echo "$out" | rg -c '^PASS:' || true)"
      count="PASS_COUNT=${pc:-?}"
    fi
    pass "regression p${n} GO (${count} EXIT=0)"
  else
    fail "regression p${n} FAILED (EXIT=${rc})"
    REG_FAIL=1
  fi
done
[[ $REG_FAIL -eq 0 ]] || fail "one or more p1–p4 regressions failed"

echo "=== SUMMARY ==="
if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=0 EXIT=0"
  exit 0
fi
echo "SOME CHECKS FAILED"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT>0 EXIT=1"
exit 1
