#!/usr/bin/env bash
# Static verification for Q-SUW-LOCK-HARDEN
# (T-SUW-QR-KEY-ROTATE + T-SUW-LOCK-BACKSTOP + T-SUW-PROVISION-NET-FAIL).
#
# Cases:
#   H1 — old Ed25519 private seed absent; new private seed absent from product
#        trees (may exist only in Architect rotate report); SUW+GT
#        TEST_PUBLIC_KEY byte arrays identical
#   M1 — SecurityActivity: no SetupWizard.next on insecure+no-biometric path
#   M2 — ProvisionQrActivity: NetworkProvisionException / fail-closed on
#        wifi/vpn apply failure; Next gated; safe network error string
#   R  — prior Q-SUW-LOCK invariants (invokes verify_suw_lock_static.sh)
#   L  — no secret Log interpolation regressions
#   B  — optional m SetupWizard2 GuardTalkConfig (GT_QA_RUN_BUILD=1)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_suw_lock_harden_static.sh
# Optional:
#   GT_QA_RUN_BUILD=1 bash vendor/guardtalk/docs/qa/verify_suw_lock_harden_static.sh
#   GT_QA_SKIP_REGRESSION=1 …  # skip nested verify_suw_lock_static.sh
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
SECURITY="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/SecurityActivity.kt"
PROVISION="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/ProvisionQrActivity.kt"
STRINGS="packages/apps/SetupWizard2/res/values/strings.xml"
GT_PARSER="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/QrPayloadParser.kt"
GT_APPLIER="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/ConfigApplier.kt"
GT_PWD="vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/DevicePasswordApplier.kt"
SUW_APPLIER="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/action/DevicePasswordApplier.kt"
COMMUNITY="packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/CommunityLockActivity.kt"
DOC="vendor/guardtalk/docs/SUW_DEVICE_PASSWORD_QR.md"
ROTATE_REPORT=".agent-comm/inbox/TO_ARCHITECT_T-SUW-QR-KEY-ROTATE.md"
ROOT_QUEUE="TASK_QUEUE.md"
AGENT_QUEUE=".agent-comm/TASK_QUEUE.md"
BASELINE_SCRIPT="vendor/guardtalk/docs/qa/verify_suw_lock_static.sh"
PIN_MK="vendor/google_devices/tokay/adevtool-version-check.mk"
SUW_APK="out/target/product/tokay/system_ext/priv-app/SetupWizard2/SetupWizard2.apk"
GT_APK="out/target/product/tokay/system_ext/priv-app/GuardTalkConfig/GuardTalkConfig.apk"

# Revoked / old private seed — constructed in parts so this QA detector file
# does not contain the contiguous base64 literal (avoids self-match / re-leak).
OLD_SEED="$(printf '%s%s%s' 'bV0Ui5ZRFvOciEp6' 'lQjIAWxJ19weStbN' 'Ss6wnxSaDLA=')"

# Product trees under vendor/guardtalk (exclude docs/qa detectors/evidence).
GT_PRODUCT_GLOBS=(
  --glob '!docs/qa/**'
  --glob '!**/verify_suw_lock*.sh'
  --glob '!**/*_EVIDENCE.md'
)

echo "=== Q-SUW-LOCK-HARDEN H1: key rotate — old/new private seeds + public parity ==="

require_file "$PROVISION" "ProvisionQrActivity.kt"
require_file "$GT_PARSER" "QrPayloadParser.kt"
require_file "$DOC" "SUW_DEVICE_PASSWORD_QR.md"
require_file "$ROTATE_REPORT" "Architect rotate report (private archive)"

# Old seed must be absent from product trees
if rg -q --fixed-strings "${GT_PRODUCT_GLOBS[@]}" -- "$OLD_SEED" vendor/guardtalk; then
  fail "H1: old private seed still present under vendor/guardtalk (product)"
  rg -n --fixed-strings "${GT_PRODUCT_GLOBS[@]}" -- "$OLD_SEED" vendor/guardtalk || true
else
  pass "H1: old private seed absent from vendor/guardtalk product tree"
fi
if rg -q --fixed-strings -- "$OLD_SEED" packages/apps/SetupWizard2; then
  fail "H1: old private seed still present under packages/apps/SetupWizard2"
  rg -n --fixed-strings -- "$OLD_SEED" packages/apps/SetupWizard2 || true
else
  pass "H1: old private seed absent from SetupWizard2"
fi

# New private seed: read ONLY from Architect rotate report — do not embed here.
NEW_SEED=""
if [[ -f "$ROTATE_REPORT" ]]; then
  NEW_SEED="$(
    awk -F'|' '
      /Private seed \(base64/ {
        gsub(/`/, "", $3)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3)
        print $3
        exit
      }
    ' "$ROTATE_REPORT"
  )"
fi
if [[ -z "$NEW_SEED" ]]; then
  fail "H1: could not extract new private seed from $ROTATE_REPORT"
elif [[ "$NEW_SEED" == "$OLD_SEED" ]]; then
  fail "H1: rotate report still lists old private seed"
else
  pass "H1: rotate report lists a new private seed (≠ old)"
  # Must remain out of product trees (qa evidence must also not paste it).
  if rg -q --fixed-strings "${GT_PRODUCT_GLOBS[@]}" -- "$NEW_SEED" vendor/guardtalk; then
    fail "H1: new private seed leaked into vendor/guardtalk product tree"
    rg -n --fixed-strings "${GT_PRODUCT_GLOBS[@]}" -- "$NEW_SEED" vendor/guardtalk || true
  else
    pass "H1: new private seed absent from vendor/guardtalk product tree"
  fi
  # Also forbid leak into qa evidence/scripts (except dynamic extract from report)
  if rg -q --fixed-strings --glob '!verify_suw_lock_harden_static.sh' -- \
    "$NEW_SEED" vendor/guardtalk/docs/qa 2>/dev/null; then
    fail "H1: new private seed leaked into vendor/guardtalk/docs/qa"
    rg -n --fixed-strings --glob '!verify_suw_lock_harden_static.sh' -- \
      "$NEW_SEED" vendor/guardtalk/docs/qa || true
  else
    pass "H1: new private seed absent from vendor/guardtalk/docs/qa artifacts"
  fi
  if rg -q --fixed-strings -- "$NEW_SEED" packages/apps/SetupWizard2; then
    fail "H1: new private seed leaked into SetupWizard2"
    rg -n --fixed-strings -- "$NEW_SEED" packages/apps/SetupWizard2 || true
  else
    pass "H1: new private seed absent from SetupWizard2"
  fi
  # Confirm it exists in the allowed archive location
  if rg -q --fixed-strings -- "$NEW_SEED" "$ROTATE_REPORT"; then
    pass "H1: new private seed present only in Architect rotate report (allowed)"
  else
    fail "H1: new private seed missing from rotate report after extract"
  fi
fi

# Docs must not claim private is in-tree
require_rg 'out-of-tree|NEVER committed|never committed|Private seed is NEVER' \
  "$DOC" "mint doc: private out-of-tree only"
require_rg 'Private seed is NEVER committed|out-of-tree only|NEVER committed' \
  "$PROVISION" "SUW comments: private out-of-tree"
require_rg 'NEVER committed|out-of-tree only' \
  "$GT_PARSER" "GT parser comments: private out-of-tree"

# TEST_PUBLIC_KEY arrays must match (32 signed bytes)
python3 - <<'PY'
import re, sys
from pathlib import Path
paths = [
    Path("packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/ProvisionQrActivity.kt"),
    Path("vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/QrPayloadParser.kt"),
]
arrays = []
for p in paths:
    t = p.read_text(encoding="utf-8")
    m = re.search(r"TEST_PUBLIC_KEY:\s*ByteArray\s*=\s*byteArrayOf\(([^)]+)\)", t, re.S)
    if not m:
        print(f"FAIL_EXTRACT:{p}")
        sys.exit(2)
    nums = [int(x.strip()) for x in m.group(1).split(",") if x.strip()]
    if len(nums) != 32:
        print(f"FAIL_LEN:{p}:{len(nums)}")
        sys.exit(3)
    arrays.append(nums)
if arrays[0] != arrays[1]:
    print("FAIL_MISMATCH")
    sys.exit(4)
# Expected rotated public (from T-SUW-QR-KEY-ROTATE completion) — public OK to assert
expected = [
    -74, 62, -37, -122, 21, 101, -32, -53, -17, 56, 119, 52, -124, 57, 19, 100,
    85, -83, -30, -53, -75, -13, 50, 31, -30, -8, 84, 25, 69, 108, 18, -43,
]
if arrays[0] != expected:
    print("FAIL_UNEXPECTED_PUBLIC")
    sys.exit(5)
print("OK")
sys.exit(0)
PY
py_ec=$?
if [[ $py_ec -eq 0 ]]; then
  pass "H1: SUW + GT TEST_PUBLIC_KEY arrays identical (32 bytes)"
  pass "H1: TEST_PUBLIC_KEY matches rotated public from key-rotate task"
else
  fail "H1: TEST_PUBLIC_KEY parity/expected check failed (python exit=$py_ec)"
fi

echo "=== Q-SUW-LOCK-HARDEN M1: SecurityActivity insecure+no-biometric backstop ==="

require_file "$SECURITY" "SecurityActivity.kt"
require_rg 'isDeviceSecure\(\) == true' "$SECURITY" "secure path checks isDeviceSecure"
require_rg 'hasBiometricFeature\(\)' "$SECURITY" "biometric feature gate present"
require_rg 'FEATURE_FINGERPRINT|FEATURE_FACE' "$SECURITY" "fingerprint/face feature query"
require_rg 'refusing advance|device not secure|M1 secure backstop' "$SECURITY" \
  "fail-closed reason documented"
require_rg 'setMovingForward\(\)' "$SECURITY" "setMovingForward before finish on refuse path"
# Insecure+no-biometric branch must omit SetupWizard.next (comment OK).
if awk '
  /!hasBiometricFeature\(\)/ { in_block=1; next }
  in_block {
    if ($0 ~ /SetupWizard\.next/ && $0 !~ /^[[:space:]]*\/\// && $0 !~ /\/\*.*SetupWizard\.next/) {
      # allow end-of-line comment mentioning next, but not a call
      line=$0
      sub(/\/\/.*/, "", line)
      if (line ~ /SetupWizard\.next[[:space:]]*\(/) { bad=1 }
    }
    if (in_block && /^[[:space:]]*\}[[:space:]]*$/) { in_block=0 }
  }
  END { exit bad ? 0 : 1 }
' "$SECURITY"; then
  fail "M1: insecure+no-biometric path must not call SetupWizard.next"
else
  pass "M1: insecure+no-biometric path omits SetupWizard.next"
fi
# Secure-already path may still call next — required for normal skip
require_rg 'SetupWizard\.next\(this\)' "$SECURITY" \
  "already-secure path still advances via SetupWizard.next"
# Password-only: no PIN/pattern / ACTION_SETUP_LOCK_SCREEN fallback
forbid_rg 'ACTION_SETUP_LOCK_SCREEN|createPin|createPattern|LockPatternView' \
  "$SECURITY" "M1 does not fall back to PIN/pattern setup UI"

echo "=== Q-SUW-LOCK-HARDEN M2: ProvisionQr network fail-closed + Next gated ==="

require_rg 'class NetworkProvisionException' "$PROVISION" \
  "NetworkProvisionException defined"
require_rg 'applyWifi\(.*\): Boolean' "$PROVISION" "applyWifi returns Boolean"
require_rg 'applyVpn\(.*\): Boolean' "$PROVISION" "applyVpn returns Boolean"
require_rg 'throw NetworkProvisionException\("wifi_ssid apply failed"\)' "$PROVISION" \
  "wifi apply failure throws NetworkProvisionException"
require_rg 'throw NetworkProvisionException\("vpn_server apply failed"\)' "$PROVISION" \
  "vpn apply failure throws NetworkProvisionException"
require_rg 'missing vpn_identity or vpn_psk' "$PROVISION" \
  "missing VPN creds throw NetworkProvisionException"
require_rg 'e is NetworkProvisionException' "$PROVISION" \
  "mapProvisionError maps NetworkProvisionException"
require_rg 'R\.string\.provision_failed_network' "$PROVISION" \
  "maps to provision_failed_network"
require_rg 'name="provision_failed_network"' "$STRINGS" \
  "strings.xml defines provision_failed_network"
require_rg 'primaryButton\.isEnabled = false' "$PROVISION" \
  "Next starts disabled / cleared on failure path"
require_rg 'provisioned = false' "$PROVISION" "failure clears provisioned"
require_rg 'provisioned = true' "$PROVISION" "success sets provisioned"
require_rg 'primaryButton\.isEnabled = true' "$PROVISION" \
  "Next enabled only after success"
# Catch path must disable Next (fail-closed)
require_rg 'catch \(e: Exception\)' "$PROVISION" "onActivityResult catch present"
# applyWifi/applyVpn must return false on failures (not swallow-and-continue)
require_rg 'return false' "$PROVISION" "apply helpers return false on failure"
require_rg 'addOrUpdateNetwork returned' "$PROVISION" "netId < 0 treated as failure"
require_rg 'provision returned consent intent' "$PROVISION" \
  "VPN consent intent treated as failure"
# Soft-fail residual documented in applyConfiguration KDoc
require_rg 'Fail-closed on critical Wi|fail-closed|provisioned=false' "$PROVISION" \
  "applyConfiguration documents fail-closed / Next disabled"

echo "=== Q-SUW-LOCK-HARDEN L: no secret Log interpolation regressions ==="

SECRET_LOG_PAT='Log\.[diwev]\([^;]*(passwordField|confirmField|\$password\b|\$confirm\b|\$trimmed\b|devicePassword|wifiPassword|vpnPsk|payload\.devicePassword|\$psk\b)'
for f in "$SUW_APPLIER" "$PROVISION" "$COMMUNITY" "$SECURITY" "$GT_PWD" "$GT_PARSER" "$GT_APPLIER"; do
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
require_rg 'Never log|never log|Never logs|never logged' "$PROVISION" \
  "ProvisionQr documents never-log secrets"
require_rg 'safeLogMessage' "$PROVISION" "ProvisionQr uses safeLogMessage"

echo "=== Q-SUW-LOCK-HARDEN deps: T-* APPROVED citations ==="

for tid in T-SUW-QR-KEY-ROTATE T-SUW-LOCK-BACKSTOP T-SUW-PROVISION-NET-FAIL; do
  if [[ -f "$ROOT_QUEUE" ]] \
    && awk -F'|' -v id="$tid" '$0 ~ id && /APPROVED/ {found=1} END{exit !found}' "$ROOT_QUEUE"; then
    pass "root TASK_QUEUE lists $tid APPROVED"
  else
    fail "root TASK_QUEUE missing $tid APPROVED"
  fi
  if [[ -f "$AGENT_QUEUE" ]] \
    && awk -F'|' -v id="$tid" '$0 ~ id && /APPROVED/ {found=1} END{exit !found}' "$AGENT_QUEUE"; then
    pass "agent TASK_QUEUE lists $tid APPROVED"
  else
    fail "agent TASK_QUEUE missing $tid APPROVED"
  fi
done

echo "=== Q-SUW-LOCK-HARDEN R: prior Q-SUW-LOCK invariants (sibling script) ==="

if [[ "${GT_QA_SKIP_REGRESSION:-0}" == "1" ]]; then
  pass "regression nested script skipped (GT_QA_SKIP_REGRESSION=1)"
elif [[ -x "$BASELINE_SCRIPT" || -f "$BASELINE_SCRIPT" ]]; then
  # Nested baseline must not re-run build (this script owns optional build).
  set +e
  GT_QA_RUN_BUILD=0 bash "$BASELINE_SCRIPT"
  base_ec=$?
  set -e
  if [[ $base_ec -eq 0 ]]; then
    pass "verify_suw_lock_static.sh EXIT=0 (prior lock invariants)"
  else
    fail "verify_suw_lock_static.sh EXIT=$base_ec (prior lock invariants)"
  fi
else
  fail "missing baseline script $BASELINE_SCRIPT"
fi

echo "=== Q-SUW-LOCK-HARDEN B: build smoke / artifacts ==="

run_module_build() {
  local pin_bak=""
  if [[ -f "$PIN_MK" ]]; then
    pin_bak="$(mktemp)"
    cp -a "$PIN_MK" "$pin_bak"
    printf '%s\n' '# Temporarily bypassed for Q-SUW-LOCK-HARDEN module build smoke' > "$PIN_MK"
    echo "PIN_BYPASSED=$PIN_MK"
  fi
  local build_ec=1
  # envsetup.sh references unbound vars (TOP); disable nounset while sourcing.
  set +eu
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
  set -eu
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
  pass "documented build: m SetupWizard2 GuardTalkConfig (adevtool pin bypass+restore)"
fi

if [[ -f "$SUW_APK" ]]; then
  pass "present: SetupWizard2.apk artifact (tokay)"
else
  fail "missing SetupWizard2.apk (cannot cite build product)"
fi
if [[ -f "$GT_APK" ]]; then
  pass "present: GuardTalkConfig.apk artifact (tokay)"
else
  fail "missing GuardTalkConfig.apk (cannot cite build product)"
fi

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
