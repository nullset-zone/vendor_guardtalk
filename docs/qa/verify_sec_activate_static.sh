#!/usr/bin/env bash
# Static verification for Q-SEC-ACTIVATE
# (T-SEC-ACTIVATE + F-SEC-ACTIVATE-UI: Security activation acceptance).
# Covers diagnosis doc, live controllers (not stub), no false Coming soon,
# browse ungated / write fail-closed, GT Info→Validator, no network under
# Security, helpers OR policy, and T/F APPROVED + Settings/GuardTalkConfig EXIT=0.
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_sec_activate_static.sh
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
DIAG="vendor/guardtalk/docs/SECURITY_ACTIVATION_DIAGNOSIS.md"
DASH_XML="packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml"
DASH_FRAG="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityDashboardFragment.java"
GATE_CLIENT="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkConfigGateClient.java"
CONFIG_APPLIER="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/ConfigApplier.kt"
GT_INFO_CTRL="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkGtInfoPreferenceController.java"
GT_CONFIG_CTRL="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkGtConfigPreferenceController.java"
STUB_CTRL="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSecurityStubPreferenceController.java"
LIVE_DIR="packages/apps/Settings/src/com/android/settings/security/guardtalk"
HELPER_DIR="packages/apps/Settings/src/com/android/settings/guardtalk"
SETTINGS_APK="out/target/product/tokay/system_ext/priv-app/Settings/Settings.apk"
GT_CONFIG_APK="out/target/product/tokay/system_ext/priv-app/GuardTalkConfig/GuardTalkConfig.apk"
ROOT_QUEUE="TASK_QUEUE.md"
AGENT_QUEUE=".agent-comm/TASK_QUEUE.md"
DONE_LOG=".agent-comm/completed/DONE_LOG.md"
F_REPORT=".agent-comm/inbox/TO_ARCHITECT.md"

LIVE_CONTROLLERS=(
  "GuardTalkDeviceLockPreferenceController.java"
  "GuardTalkSensorPrivacyPreferenceController.java"
  "GuardTalkUsbProtectionPreferenceController.java"
  "GuardTalkLockdownPreferenceController.java"
  "GuardTalkAutoRebootPreferenceController.java"
  "GuardTalkDuressPreferenceController.java"
  "GuardTalkAntiBruteforcePreferenceController.java"
  "GuardTalkSecureWipePreferenceController.java"
  "GuardTalkSecurityStatusPreferenceController.java"
  "GuardTalkGtConfigPreferenceController.java"
  "GuardTalkGtInfoPreferenceController.java"
)

DASH_KEYS=(
  "guardtalk_security_device_lock"
  "guardtalk_security_sensor_privacy"
  "guardtalk_security_usb_protection"
  "guardtalk_security_lockdown"
  "guardtalk_security_auto_reboot"
  "guardtalk_security_duress"
  "guardtalk_security_anti_bruteforce"
  "guardtalk_security_secure_wipe"
  "guardtalk_security_status"
  "guardtalk_gt_config"
  "guardtalk_gt_info"
)

HELPERS_OR_POLICY=(
  "GuardTalkLockPolicyHelper.java"
  "GuardTalkSensorPrivacyHelper.java"
  "GuardTalkUsbProtectionHelper.java"
  "GuardTalkAutoRebootHelper.java"
)

echo "=== Q-SEC-ACTIVATE: diagnosis doc ==="

require_file "$DIAG" "SECURITY_ACTIVATION_DIAGNOSIS.md"
require_rg 'Per-key matrix' "$DIAG" "diagnosis has per-key matrix"
require_rg 'gt_config_write' "$DIAG" "diagnosis documents gt_config_write write-gate"
require_rg 'ValidatorActivity|guardtalk\.validator' "$DIAG" "diagnosis documents GT Info → Validator"
require_rg 'Must not ship' "$DIAG" "diagnosis forbids network under Security"
for key in "${DASH_KEYS[@]}"; do
  require_rg "$key" "$DIAG" "diagnosis lists key $key"
done
# All shippable keys marked AVAILABLE (not stub-only)
require_rg 'guardtalk_security_device_lock.*\*\*AVAILABLE\*\*|`guardtalk_security_device_lock` \| \*\*AVAILABLE\*\*' \
  "$DIAG" "diagnosis: device_lock AVAILABLE"
require_rg '`guardtalk_gt_info` \| \*\*AVAILABLE\*\*' "$DIAG" "diagnosis: gt_info AVAILABLE"
require_rg 'Helpers report live when policies on|Overlay \*\*OR\*\* prop \*\*OR\*\* framework' \
  "$DIAG" "diagnosis: helpers OR policy acceptance"

echo "=== Q-SEC-ACTIVATE: dashboard XML live controllers (not stub) ==="

require_file "$DASH_XML" "guardtalk_security_dashboard.xml"
forbid_rg 'GuardTalkSecurityStubPreferenceController' "$DASH_XML" \
  "dashboard XML does not wire StubPreferenceController"
for key in "${DASH_KEYS[@]}"; do
  require_rg "android:key=\"$key\"" "$DASH_XML" "dashboard XML has key $key"
done
require_rg 'GuardTalkDeviceLockPreferenceController' "$DASH_XML" \
  "dashboard wires DeviceLock live controller"
require_rg 'GuardTalkSensorPrivacyPreferenceController' "$DASH_XML" \
  "dashboard wires SensorPrivacy live controller"
require_rg 'GuardTalkUsbProtectionPreferenceController' "$DASH_XML" \
  "dashboard wires UsbProtection live controller"
require_rg 'GuardTalkLockdownPreferenceController' "$DASH_XML" \
  "dashboard wires Lockdown live controller"
require_rg 'GuardTalkAutoRebootPreferenceController' "$DASH_XML" \
  "dashboard wires AutoReboot live controller"
require_rg 'GuardTalkDuressPreferenceController' "$DASH_XML" \
  "dashboard wires Duress live controller"
require_rg 'GuardTalkAntiBruteforcePreferenceController' "$DASH_XML" \
  "dashboard wires AntiBruteforce live controller"
require_rg 'GuardTalkSecureWipePreferenceController' "$DASH_XML" \
  "dashboard wires SecureWipe live controller"
require_rg 'GuardTalkSecurityStatusPreferenceController' "$DASH_XML" \
  "dashboard wires SecurityStatus live controller"
require_rg 'GuardTalkGtConfigPreferenceController' "$DASH_XML" \
  "dashboard wires GtConfig live controller"
require_rg 'GuardTalkGtInfoPreferenceController' "$DASH_XML" \
  "dashboard wires GtInfo live controller"

echo "=== Q-SEC-ACTIVATE: live controllers present; no false Coming soon ==="

for c in "${LIVE_CONTROLLERS[@]}"; do
  require_file "$LIVE_DIR/$c" "$c"
  # Resource / code refs only — comments may say "never Coming soon" (allowed).
  forbid_rg 'R\.string\.guardtalk_security_stub_summary|@string/guardtalk_security_stub_summary' \
    "$LIVE_DIR/$c" \
    "$c has no stub_summary resource ref (false Coming soon)"
  forbid_rg 'setSummary\([^)]*Coming soon' "$LIVE_DIR/$c" \
    "$c does not setSummary Coming soon"
done

# Stub controller must not be referenced from dashboard; may exist as legacy only
require_file "$STUB_CTRL" "legacy StubPreferenceController retained (not wired)"
require_rg 'no dashboard preference should use this controller|F-SEC-ACTIVATE-UI' \
  "$STUB_CTRL" "stub controller documents not-for-dashboard"

# Live summaries: inactive / policy — not stub
require_rg 'guardtalk_security_status_inactive|never false "Coming soon"' \
  "$LIVE_DIR/GuardTalkDeviceLockPreferenceController.java" \
  "DeviceLock uses inactive summary (not stub) when helper false"
require_rg 'guardtalk_security_status_inactive|honest inactive' \
  "$LIVE_DIR/GuardTalkSensorPrivacyPreferenceController.java" \
  "SensorPrivacy uses inactive summary (not stub)"
require_rg 'guardtalk_gt_config_summary_browse|Browse launch is ungated' \
  "$GT_CONFIG_CTRL" "GtConfig browse summary when no write session"

# No stub_summary refs anywhere under live Security controller dir (except stub class name file itself)
if rg -n 'guardtalk_security_stub_summary' "$LIVE_DIR" --glob '*.java' \
  | rg -v 'GuardTalkSecurityStubPreferenceController' | rg -q .; then
  fail "live Security controller dir still references guardtalk_security_stub_summary"
else
  pass "no guardtalk_security_stub_summary refs in live Security controllers"
fi

echo "=== Q-SEC-ACTIVATE: browse ungated / write fail-closed ==="

require_file "$DASH_FRAG" "GuardTalkSecurityDashboardFragment"
require_rg 'Browse of Security|browse is ungated|Browse launch ungated|GT Config browse is ungated' \
  "$DASH_FRAG" "dashboard documents browse ungated"
require_rg 'handleGtConfigClick' "$DASH_FRAG" "dashboard has ungated GT Config launch handler"
require_rg 'launchGtConfig' "$DASH_FRAG" "dashboard launches GT Config for browse"
# Launch path must not assert gt_config_write / assertAuthorized for GT Config open
if rg -n 'handleGtConfigClick|launchGtConfig' -A 20 "$DASH_FRAG" \
  | rg -q 'assertAuthorized|gt_config_write|GT_CONFIG_WRITE|assertMutationAuthorized'; then
  fail "GT Config launch path asserts write-gate (must be browse-ungated)"
else
  pass "GT Config launch path does not assert write-gate"
fi
# Mutations fail-closed via wasSessionOpened
require_rg 'wasSessionOpened' "$DASH_FRAG" \
  "mutations use wasSessionOpened fail-closed"
require_rg 'Fail-closed|fail-closed' "$DASH_FRAG" \
  "dashboard documents fail-closed on gate refuse"
require_file "$GATE_CLIENT" "GuardTalkConfigGateClient"
require_rg 'wasSessionOpened' "$GATE_CLIENT" \
  "GateClient exposes wasSessionOpened"
require_rg 'MUTATION_KEYS' "$DASH_FRAG" \
  "dashboard maps seven mutation keys"

# ConfigApplier still asserts gt_config_write
require_file "$CONFIG_APPLIER" "ConfigApplier.kt"
require_rg 'assertMutationAuthorized' "$CONFIG_APPLIER" \
  "ConfigApplier asserts mutation authorized"
require_rg 'GT_CONFIG_WRITE|gt_config_write' "$CONFIG_APPLIER" \
  "ConfigApplier asserts gt_config_write"
require_rg 'fail-closed|unauthorized \(fail-closed\)' "$CONFIG_APPLIER" \
  "ConfigApplier write-gate fail-closed"

echo "=== Q-SEC-ACTIVATE: GT Info → Validator ==="

require_file "$GT_INFO_CTRL" "GuardTalkGtInfoPreferenceController"
require_rg 'com\.guardtalk\.validator\.ValidatorActivity' "$GT_INFO_CTRL" \
  "GT Info deep-links to ValidatorActivity"
require_rg 'AVAILABLE' "$GT_INFO_CTRL" \
  "GT Info controller can return AVAILABLE"
forbid_rg 'guardtalk_security_stub_summary' "$GT_INFO_CTRL" \
  "GT Info controller is not stub summary"
require_rg 'startActivity' "$GT_INFO_CTRL" \
  "GT Info launches Validator via startActivity"

echo "=== Q-SEC-ACTIVATE: no network under Security dashboard ==="

# Comment may mention network as forbidden; keys/controllers must not introduce network prefs
forbid_rg 'android:key="[^"]*(wifi|vpn|hotspot|airplane|network)[^"]*"' \
  "$DASH_XML" "dashboard XML has no wifi/vpn/hotspot/airplane/network keys"
forbid_rg 'settings:controller="[^"]*(Wifi|Vpn|Hotspot|Airplane|Network)[^"]*"' \
  "$DASH_XML" "dashboard XML has no Wifi/Vpn/Hotspot/Airplane/Network controllers"
# Positive: diagnosis + XML header forbid network
require_rg 'Network / VPN / Wi-Fi / Hotspot / Airplane MUST NOT' "$DASH_XML" \
  "dashboard XML header forbids network controls"
require_rg 'Network / VPN / Wi‑Fi / Hotspot / Airplane under Security' "$DIAG" \
  "diagnosis forbids network under Security"

echo "=== Q-SEC-ACTIVATE: helpers OR policy (T-SEC-ACTIVATE) ==="

for h in "${HELPERS_OR_POLICY[@]}"; do
  require_file "$HELPER_DIR/$h" "$h"
  require_rg 'Overlay OR product prop OR framework policy|OR framework policy' \
    "$HELPER_DIR/$h" "$h documents overlay OR prop OR framework"
  require_rg '\|\|' "$HELPER_DIR/$h" "$h uses OR with framework/policy"
done
require_file "$HELPER_DIR/GuardTalkSecureWipeHelper.java" "GuardTalkSecureWipeHelper"
require_rg 'Overlay bool OR product prop' \
  "$HELPER_DIR/GuardTalkSecureWipeHelper.java" \
  "SecureWipeHelper documents overlay OR prop"

echo "=== Q-SEC-ACTIVATE: T/F APPROVED + Settings/GuardTalkConfig EXIT=0 cites ==="

cite_ok=0
if [[ -f "$ROOT_QUEUE" ]] \
  && rg -q 'T-SEC-ACTIVATE \(Backend\) — APPROVED' "$ROOT_QUEUE"; then
  pass "root TASK_QUEUE cites T-SEC-ACTIVATE APPROVED"
  cite_ok=1
else
  fail "root TASK_QUEUE missing T-SEC-ACTIVATE APPROVED card"
fi
if [[ -f "$ROOT_QUEUE" ]] \
  && rg -q 'F-SEC-ACTIVATE-UI \(Frontend\) — APPROVED' "$ROOT_QUEUE"; then
  pass "root TASK_QUEUE cites F-SEC-ACTIVATE-UI APPROVED"
  cite_ok=1
else
  fail "root TASK_QUEUE missing F-SEC-ACTIVATE-UI APPROVED card"
fi
if [[ -f "$AGENT_QUEUE" ]] \
  && rg -q 'T-SEC-ACTIVATE' "$AGENT_QUEUE" \
  && rg -q 'F-SEC-ACTIVATE-UI' "$AGENT_QUEUE"; then
  # Both listed APPROVED in agent table
  if awk -F'|' '/T-SEC-ACTIVATE/ && /APPROVED/ {found=1} END{exit !found}' "$AGENT_QUEUE" \
    && awk -F'|' '/F-SEC-ACTIVATE-UI/ && /APPROVED/ {found=1} END{exit !found}' "$AGENT_QUEUE"; then
    pass "agent TASK_QUEUE lists T-SEC-ACTIVATE + F-SEC-ACTIVATE-UI APPROVED"
    cite_ok=1
  else
    fail "agent TASK_QUEUE missing T/F APPROVED rows"
  fi
else
  fail "agent TASK_QUEUE missing T/F SEC-ACTIVATE entries"
fi

# Build EXIT=0 cite from DONE_LOG and/or F completion report
build_cite=0
if [[ -f "$DONE_LOG" ]] \
  && rg -q 'F-SEC-ACTIVATE-UI APPROVED' "$DONE_LOG" \
  && rg -q 'm Settings GuardTalkConfig EXIT=0' "$DONE_LOG"; then
  pass "DONE_LOG cites F-SEC-ACTIVATE-UI m Settings GuardTalkConfig EXIT=0"
  build_cite=1
  cite_ok=1
else
  fail "DONE_LOG missing F-SEC-ACTIVATE-UI Settings/GuardTalkConfig EXIT=0"
fi
if [[ -f "$DONE_LOG" ]] \
  && rg -q 'T-SEC-ACTIVATE APPROVED' "$DONE_LOG"; then
  pass "DONE_LOG cites T-SEC-ACTIVATE APPROVED"
  cite_ok=1
else
  fail "DONE_LOG missing T-SEC-ACTIVATE APPROVED"
fi
# Optional: live F report still present before QA overwrite
if [[ -f "$F_REPORT" ]] \
  && rg -q 'F-SEC-ACTIVATE-UI|m Settings GuardTalkConfig' "$F_REPORT" \
  && rg -q 'EXIT=0' "$F_REPORT"; then
  pass "TO_ARCHITECT cites m Settings GuardTalkConfig EXIT=0 (F report)"
  build_cite=1
  cite_ok=1
else
  # Not required if DONE_LOG already cited (QA may have overwritten inbox)
  if [[ $build_cite -eq 1 ]]; then
    pass "TO_ARCHITECT F EXIT=0 optional (DONE_LOG already cited)"
  else
    fail "no F Settings/GuardTalkConfig EXIT=0 cite in inbox or DONE_LOG"
  fi
fi

[[ $cite_ok -eq 1 ]] || fail "insufficient T/F APPROVED / build EXIT=0 citations"
[[ $build_cite -eq 1 ]] || fail "missing Settings/GuardTalkConfig EXIT=0 build cite"

echo "=== Q-SEC-ACTIVATE: build artifacts (cited product) ==="

if [[ -f "$SETTINGS_APK" ]]; then
  pass "present: Settings.apk artifact (tokay)"
  if rg -a -q 'ValidatorActivity' "$SETTINGS_APK"; then
    pass "Settings.apk contains ValidatorActivity symbol"
  else
    fail "Settings.apk missing ValidatorActivity symbol"
  fi
  if rg -a -q 'wasSessionOpened' "$SETTINGS_APK"; then
    pass "Settings.apk contains wasSessionOpened symbol"
  else
    fail "Settings.apk missing wasSessionOpened symbol"
  fi
  if rg -a -q 'GuardTalkGtInfoPreferenceController' "$SETTINGS_APK"; then
    pass "Settings.apk contains GuardTalkGtInfoPreferenceController"
  else
    fail "Settings.apk missing GuardTalkGtInfoPreferenceController"
  fi
else
  fail "missing Settings.apk artifact (cannot cite build product)"
fi

if [[ -f "$GT_CONFIG_APK" ]]; then
  pass "present: GuardTalkConfig.apk artifact (tokay)"
  if rg -a -q 'assertMutationAuthorized' "$GT_CONFIG_APK"; then
    pass "GuardTalkConfig.apk contains assertMutationAuthorized symbol"
  else
    fail "GuardTalkConfig.apk missing assertMutationAuthorized symbol"
  fi
  if rg -a -q 'gt_config_write' "$GT_CONFIG_APK"; then
    pass "GuardTalkConfig.apk contains gt_config_write symbol"
  else
    fail "GuardTalkConfig.apk missing gt_config_write symbol"
  fi
else
  fail "missing GuardTalkConfig.apk artifact (cannot cite build product)"
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
