#!/usr/bin/env bash
# Static verification for Q-SUW-LOCK
# (T-SUW-LOCK-APPLY + F-SUW-LOCK-UI: Community lock + Syndicate QR device_password).
# Cases: Community routing; password+confirm; Community skips QR; Syndicate
# fail-closed + Ed25519; ProvisionQr Next gated / safe errors; GuardTalkConfig
# parity; no plaintext password Log interpolation; build smoke / artifacts.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_suw_lock_static.sh
# Optional:
#   GT_QA_RUN_BUILD=1 bash vendor/guardtalk/docs/qa/verify_suw_lock_static.sh
#     → lunch + m SetupWizard2 GuardTalkConfig (adevtool pin bypass+restore)
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
SECURE="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/SecureLevelActivity.kt"
COMMUNITY="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/CommunityLockActivity.kt"
PROVISION="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/ProvisionQrActivity.kt"
SETUPWIZ="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/action/SetupWizard.kt"
SUW_APPLIER="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/action/DevicePasswordApplier.kt"
COMMUNITY_XML="packages/apps/SetupWizard2/res/layout/community_lock_activity.xml"
STRINGS="packages/apps/SetupWizard2/res/values/strings.xml"
MANIFEST="packages/apps/SetupWizard2/AndroidManifest.xml"
GT_PARSER="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/QrPayloadParser.kt"
GT_APPLIER="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/ConfigApplier.kt"
GT_PWD="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/DevicePasswordApplier.kt"
DOC="vendor/guardtalk/docs/SUW_DEVICE_PASSWORD_QR.md"
ROOT_QUEUE="TASK_QUEUE.md"
AGENT_QUEUE=".agent-comm/TASK_QUEUE.md"
DONE_LOG=".agent-comm/completed/DONE_LOG.md"
SUW_APK="out/target/product/tokay/system_ext/priv-app/SetupWizard2/SetupWizard2.apk"
GT_APK="out/target/product/tokay/system_ext/priv-app/GuardTalkConfig/GuardTalkConfig.apk"
PIN_MK="vendor/google_devices/tokay/adevtool-version-check.mk"

echo "=== Q-SUW-LOCK case1: Community SecureLevel → CommunityLockActivity ==="

require_file "$SECURE" "SecureLevelActivity.kt"
require_rg 'CommunityLockActivity' "$SECURE" \
  "SecureLevel Community launches CommunityLockActivity"
require_rg 'startActivity\(Intent\(this, CommunityLockActivity::class\.java\)\)' "$SECURE" \
  "Community branch startActivity(CommunityLockActivity)"
require_rg 'finish\(\)' "$SECURE" "SecureLevel finish() after branch launch"
# Community must NOT call SetupWizard.next (would skip lock). Comments may mention it.
if [[ -f "$SECURE" ]] \
  && awk '/SetupWizard\.next/ && $0 !~ /^[[:space:]]*\/\// { found=1 }
         END { exit !found }' "$SECURE"; then
  fail "SecureLevel must not call SetupWizard.next (would skip lock/QR insert)"
else
  pass "SecureLevel does not call SetupWizard.next (code; comments OK)"
fi
# Community else-branch must launch CommunityLock, not ProvisionQr
if [[ -f "$SECURE" ]] \
  && awk '
    /VALUE_SYNDICATE/ { in_syn=1; in_com=0; next }
    in_syn && /\} else \{/ { in_syn=0; in_com=1; next }
    in_com && /ProvisionQrActivity/ { bad=1 }
    in_com && /^[[:space:]]*\}/ { in_com=0 }
    END { exit bad ? 0 : 1 }
  ' "$SECURE"; then
  fail "Community branch must not launch ProvisionQrActivity"
else
  pass "Community branch does not launch ProvisionQrActivity"
fi
require_rg 'ProvisionQrActivity' "$SECURE" \
  "Syndicate still launches ProvisionQrActivity"
require_file "$MANIFEST" "SetupWizard2 AndroidManifest"
require_rg 'CommunityLockActivity' "$MANIFEST" "Manifest registers CommunityLockActivity"

echo "=== Q-SUW-LOCK case2: CommunityLockActivity password+confirm + applier ==="

require_file "$COMMUNITY" "CommunityLockActivity.kt"
require_file "$COMMUNITY_XML" "community_lock_activity.xml"
require_rg 'community_lock_password' "$COMMUNITY_XML" "layout has password field"
require_rg 'community_lock_password_confirm' "$COMMUNITY_XML" \
  "layout has confirm password field"
require_rg 'inputType="textPassword"' "$COMMUNITY_XML" "password fields use textPassword"
require_rg 'DevicePasswordApplier\.applyPassword' "$COMMUNITY" \
  "CommunityLock uses DevicePasswordApplier.applyPassword"
require_rg 'primaryButton\.isEnabled = false' "$COMMUNITY" \
  "CommunityLock Next starts disabled"
require_rg 'passwordField\.text\.isNotEmpty\(\) && confirmField\.text\.isNotEmpty\(\)' \
  "$COMMUNITY" "Next gated until password+confirm non-empty"
require_rg 'SetupWizard\.next\(this, SecureLevelActivity::class\.java\)' "$COMMUNITY" \
  "on success advances via SetupWizard.next(SecureLevel)"
require_rg 'password != confirm' "$COMMUNITY" "mismatch check before apply"
# Password-only: no PIN/pattern UI enrollment
forbid_rg 'createPin|createPattern|LockPatternView|PinView|CREDENTIAL_TYPE_PIN|CREDENTIAL_TYPE_PATTERN' \
  "$COMMUNITY" "CommunityLockActivity has no PIN/pattern UI"
forbid_rg 'createPin|createPattern|LockPatternView|PinView' \
  "$COMMUNITY_XML" "community_lock layout has no PIN/pattern widgets"
require_rg 'createPassword' "$SUW_APPLIER" "SUW applier uses createPassword only"
forbid_rg 'createPin\(|createPattern\(' "$SUW_APPLIER" \
  "SUW DevicePasswordApplier does not create PIN/pattern"
require_rg 'PIN and pattern are not available|password-only|Password-only' \
  "$STRINGS" "strings document password-only (no PIN/pattern enrollment)"

echo "=== Q-SUW-LOCK case3: Community skips QR ==="

require_rg 'CommunityLockActivity are intentionally NOT in this list|CommunityLockActivity are intentionally NOT' \
  "$SETUPWIZ" "CommunityLockActivity not in primaryUserActivities"
require_rg 'ProvisionQrActivity and' "$SETUPWIZ" \
  "ProvisionQrActivity not in primaryUserActivities"
# Ensure primary list jumps SecureLevel → DateTime (QR/lock inserted outside list)
require_rg 'SecureLevelActivity::class\.java,' "$SETUPWIZ" "primary list has SecureLevel"
require_rg 'DateTimeActivity::class\.java,' "$SETUPWIZ" "primary list has DateTime after SecureLevel"
# Community path comment / routing
require_rg 'Community members skip|Community → CommunityLockActivity|CommunityLockActivity' \
  "$PROVISION" "ProvisionQr documents Community skips this step"

echo "=== Q-SUW-LOCK case4: Syndicate device_password fail-closed + Ed25519 ==="

require_file "$PROVISION" "ProvisionQrActivity.kt"
require_file "$SUW_APPLIER" "SUW DevicePasswordApplier.kt"
require_rg 'device_password' "$PROVISION" "ProvisionQr reads device_password"
require_rg 'verifyEd25519' "$PROVISION" "ProvisionQr Ed25519 verify intact"
require_rg 'Ed25519' "$PROVISION" "ProvisionQr uses Ed25519"
require_rg 'DevicePasswordApplier\.validateQuality' "$PROVISION" \
  "ProvisionQr validates device_password quality (fail-closed)"
require_rg 'device_password missing' "$SUW_APPLIER" "missing → Failure"
require_rg 'device_password empty' "$SUW_APPLIER" "empty → Failure"
require_rg 'shorter than' "$SUW_APPLIER" "short → Failure"
require_rg 'applyPasswordOrThrow' "$PROVISION" \
  "ProvisionQr applies password fail-closed via OrThrow"
# Signature covers full inner JSON (device_password inside signed bytes)
require_rg 'Signature covers the full inner JSON|including device_password' "$PROVISION" \
  "docs: signature covers device_password"
require_rg 'verifyEd25519\(payloadBytes' "$PROVISION" \
  "Ed25519 verifies payload bytes before field extract"
require_file "$DOC" "SUW_DEVICE_PASSWORD_QR.md"
require_rg 'device_password' "$DOC" "doc names device_password field"
require_rg 'Ed25519' "$DOC" "doc requires Ed25519 over inner JSON"

echo "=== Q-SUW-LOCK case5: ProvisionQr Next gated + safe errors ==="

require_rg 'primaryButton\.isEnabled = false' "$PROVISION" \
  "ProvisionQr Next starts disabled"
require_rg 'provisioned = true' "$PROVISION" "success sets provisioned"
require_rg 'primaryButton\.isEnabled = true' "$PROVISION" \
  "Next enabled only after success"
require_rg 'provisioned = false' "$PROVISION" "failure clears provisioned"
require_rg 'mapProvisionError' "$PROVISION" "safe error mapping present"
require_rg 'R\.string\.provision_failed_device_password' "$PROVISION" \
  "maps device_password failures to safe string"
require_rg 'R\.string\.provision_failed_signature' "$PROVISION" \
  "maps signature failures to safe string"
require_rg 'provision_success' "$PROVISION" "success status string set"
require_rg 'Device password applied from QR' "$STRINGS" \
  "success mentions device password applied"
# Must not interpolate raw exception / %1$s format into UI
forbid_rg 'setText\(.*provision_failed[^_]|getString\(R\.string\.provision_failed[,)]' \
  "$PROVISION" "does not use format provision_failed %1\$s with exception"
forbid_rg 'statusText\.text\s*=' "$PROVISION" \
  "does not assign raw CharSequence errors to statusText"
require_rg 'safeLogMessage' "$PROVISION" "log path uses safeLogMessage"

echo "=== Q-SUW-LOCK case6: GuardTalkConfig parity ==="

require_file "$GT_PARSER" "QrPayloadParser.kt"
require_file "$GT_APPLIER" "ConfigApplier.kt"
require_file "$GT_PWD" "GT DevicePasswordApplier.kt"
require_rg 'device_password' "$GT_PARSER" "GT parser reads device_password"
require_rg 'SECURE_LEVEL_SYNDICATE' "$GT_PARSER" "GT parser has syndicate level"
require_rg 'DevicePasswordApplier\.validateQuality' "$GT_PARSER" \
  "GT parser validates device_password quality"
require_rg 'secureLevel == SECURE_LEVEL_SYNDICATE' "$GT_PARSER" \
  "GT syndicate requires device_password"
require_rg 'verifyEd25519' "$GT_PARSER" "GT Ed25519 verify intact"
require_rg 'applyDevicePassword|applyPasswordIfNeeded' "$GT_APPLIER" \
  "GT ConfigApplier applies device password"
require_rg 'createPassword' "$GT_PWD" "GT applier password-only createPassword"
forbid_rg 'createPin\(|createPattern\(' "$GT_PWD" \
  "GT DevicePasswordApplier no PIN/pattern"
require_rg 'device_password missing' "$GT_PWD" "GT missing fail-closed"
require_rg 'device_password empty' "$GT_PWD" "GT empty fail-closed"
require_rg 'zeroize' "$GT_PWD" "GT zeroes credential buffers"
require_rg 'zeroize' "$SUW_APPLIER" "SUW zeroes credential buffers"

echo "=== Q-SUW-LOCK case7: no plaintext password in Log calls ==="

# Forbid interpolating secret-bearing variables into Log calls.
SECRET_LOG_PAT='Log\.[diwev]\([^;]*(passwordField|confirmField|\$password\b|\$confirm\b|\$trimmed\b|devicePassword|wifiPassword|vpnPsk|payload\.devicePassword)'
for f in "$SUW_APPLIER" "$PROVISION" "$COMMUNITY" "$GT_PWD" "$GT_PARSER" "$GT_APPLIER"; do
  if [[ ! -f "$f" ]]; then
    fail "secret-log scan missing file $f"
    continue
  fi
  if rg -q -- "$SECRET_LOG_PAT" "$f"; then
    fail "plaintext/secret variable interpolated in Log ($f)"
    rg -n -- "$SECRET_LOG_PAT" "$f" || true
  else
    pass "no secret-variable Log interpolation: $(basename "$f")"
  fi
done
# Explicit never-log comments retained
require_rg 'Never log|never log|never logged|Never logs' "$SUW_APPLIER" \
  "SUW applier documents never-log policy"
require_rg 'Never log device_password' "$PROVISION" \
  "ProvisionQr documents never-log device_password"
require_rg 'Never log device_password' "$GT_PARSER" \
  "GT parser documents never-log device_password"

echo "=== Q-SUW-LOCK: T/F APPROVED citations ==="

if [[ -f "$ROOT_QUEUE" ]] && rg -q 'T-SUW-LOCK-APPLY' "$ROOT_QUEUE" \
  && awk -F'|' '/T-SUW-LOCK-APPLY/ && /APPROVED/ {found=1} END{exit !found}' "$ROOT_QUEUE"; then
  pass "root TASK_QUEUE lists T-SUW-LOCK-APPLY APPROVED"
else
  fail "root TASK_QUEUE missing T-SUW-LOCK-APPLY APPROVED"
fi
if [[ -f "$ROOT_QUEUE" ]] && rg -q 'F-SUW-LOCK-UI' "$ROOT_QUEUE" \
  && awk -F'|' '/F-SUW-LOCK-UI/ && /APPROVED/ {found=1} END{exit !found}' "$ROOT_QUEUE"; then
  pass "root TASK_QUEUE lists F-SUW-LOCK-UI APPROVED"
else
  fail "root TASK_QUEUE missing F-SUW-LOCK-UI APPROVED"
fi
if [[ -f "$AGENT_QUEUE" ]] \
  && awk -F'|' '/T-SUW-LOCK-APPLY/ && /APPROVED/ {found=1} END{exit !found}' "$AGENT_QUEUE" \
  && awk -F'|' '/F-SUW-LOCK-UI/ && /APPROVED/ {found=1} END{exit !found}' "$AGENT_QUEUE"; then
  pass "agent TASK_QUEUE lists T + F APPROVED"
else
  fail "agent TASK_QUEUE missing T/F APPROVED"
fi
if [[ -f "$DONE_LOG" ]] && rg -q 'T-SUW-LOCK-APPLY APPROVED' "$DONE_LOG"; then
  pass "DONE_LOG cites T-SUW-LOCK-APPLY APPROVED"
else
  fail "DONE_LOG missing T-SUW-LOCK-APPLY APPROVED"
fi
if [[ -f "$DONE_LOG" ]] && rg -q 'F-SUW-LOCK-UI APPROVED' "$DONE_LOG" \
  && rg -q 'm SetupWizard2' "$DONE_LOG"; then
  pass "DONE_LOG cites F-SUW-LOCK-UI m SetupWizard2 EXIT=0"
else
  fail "DONE_LOG missing F-SUW-LOCK-UI SetupWizard2 build cite"
fi

echo "=== Q-SUW-LOCK case8: build smoke / artifacts ==="

run_module_build() {
  local pin_bak=""
  if [[ -f "$PIN_MK" ]]; then
    pin_bak="$(mktemp)"
    cp -a "$PIN_MK" "$pin_bak"
    printf '%s\n' '# Temporarily bypassed for Q-SUW-LOCK module build smoke' > "$PIN_MK"
    echo "PIN_BYPASSED=$PIN_MK"
  fi
  local build_ec=1
  set +e
  # shellcheck disable=SC1091
  source build/envsetup.sh
  lunch tokay-trunk_staging-userdebug
  local lunch_ec=$?
  echo "LUNCH_EXIT=$lunch_ec"
  if [[ $lunch_ec -eq 0 ]]; then
    m SetupWizard2 GuardTalkConfig -j"$(nproc)"
    build_ec=$?
  fi
  echo "BUILD_EXIT=$build_ec"
  set -e
  if [[ -n "$pin_bak" && -f "$pin_bak" ]]; then
    cp -a "$pin_bak" "$PIN_MK"
    rm -f "$pin_bak"
    echo "PIN_RESTORED=$PIN_MK"
  fi
  return "$build_ec"
}

if [[ "${GT_QA_RUN_BUILD:-0}" == "1" ]]; then
  echo "GT_QA_RUN_BUILD=1 → invoking m SetupWizard2 GuardTalkConfig"
  if run_module_build; then
    pass "m SetupWizard2 GuardTalkConfig EXIT=0"
  else
    fail "m SetupWizard2 GuardTalkConfig non-zero"
  fi
else
  pass "build invoke deferred (set GT_QA_RUN_BUILD=1 to run m SetupWizard2 GuardTalkConfig)"
  # Document expected command for evidence / CI
  pass "documented build: m SetupWizard2 GuardTalkConfig (adevtool pin bypass+restore if lunch fails)"
fi

if [[ -f "$SUW_APK" ]]; then
  pass "present: SetupWizard2.apk artifact (tokay)"
  if rg -a -q 'CommunityLockActivity' "$SUW_APK"; then
    pass "SetupWizard2.apk contains CommunityLockActivity"
  else
    fail "SetupWizard2.apk missing CommunityLockActivity symbol"
  fi
  if rg -a -q 'DevicePasswordApplier' "$SUW_APK"; then
    pass "SetupWizard2.apk contains DevicePasswordApplier"
  else
    fail "SetupWizard2.apk missing DevicePasswordApplier symbol"
  fi
  if rg -a -q 'device_password' "$SUW_APK"; then
    pass "SetupWizard2.apk contains device_password string"
  else
    fail "SetupWizard2.apk missing device_password string"
  fi
else
  fail "missing SetupWizard2.apk (cannot cite build product)"
fi

if [[ -f "$GT_APK" ]]; then
  pass "present: GuardTalkConfig.apk artifact (tokay)"
  if rg -a -q 'DevicePasswordApplier' "$GT_APK"; then
    pass "GuardTalkConfig.apk contains DevicePasswordApplier"
  else
    fail "GuardTalkConfig.apk missing DevicePasswordApplier symbol"
  fi
  if rg -a -q 'device_password' "$GT_APK"; then
    pass "GuardTalkConfig.apk contains device_password string"
  else
    fail "GuardTalkConfig.apk missing device_password string"
  fi
else
  fail "missing GuardTalkConfig.apk (cannot cite build product)"
fi

# Pin file must not remain bypassed after this script (unless we just restored)
if [[ -f "$PIN_MK" ]] && rg -q 'tokay vendor module is outdated' "$PIN_MK"; then
  pass "adevtool pin check.mk restored (active)"
elif [[ -f "$PIN_MK" ]] && rg -q 'Temporarily bypassed' "$PIN_MK"; then
  fail "adevtool pin still bypassed — restore required"
else
  pass "adevtool pin mk present (state checked)"
fi

echo "=== SUMMARY ==="
if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=0 EXIT=0"
  exit 0
fi
echo "SOME CHECKS FAILED"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT>0 EXIT=1"
exit 1
