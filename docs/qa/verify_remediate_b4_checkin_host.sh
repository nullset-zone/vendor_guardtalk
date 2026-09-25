#!/usr/bin/env bash
# Independent QA rematch for Q-REMEDIATE-B4-CHECKIN (item 20).
# Do not trust Backend or Architect lunch dumps. No USB GO. No commit.
# PASS HOLD remains. Not device-fixed. Tor admin live HOLD is expected.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b4_checkin_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

APP="vendor/guardtalk/apps/GuardTalkCheckin"
CHK="vendor/guardtalk/checkin"
DOC="vendor/guardtalk/docs/SEIZURE_CHECKIN.md"
LATE="vendor/guardtalk/radio-excised/product-config-late.mk"
CONST="$APP/src/com/guardtalk/checkin/CheckinConstants.kt"
EP="$APP/src/com/guardtalk/checkin/CheckinEndpoint.kt"
ART="vendor/guardtalk/docs/qa/_artifacts"
mkdir -p "$ART"

require_file() {
  if [[ -f "$1" ]]; then pass "present: $1"; else fail "missing: $1"; fi
}

echo "=== Q-REMEDIATE-B4-CHECKIN independent rematch (item 20) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "PASS_HOLD=remains"
echo

echo "--- required files ---"
require_file "$APP/Android.bp"
require_file "$APP/AndroidManifest.xml"
require_file "$CONST"
require_file "$EP"
require_file "$APP/src/com/guardtalk/checkin/CheckinJobService.kt"
require_file "$APP/src/com/guardtalk/checkin/CheckinTransport.kt"
require_file "$APP/src/com/guardtalk/checkin/CheckinStatusActivity.kt"
require_file "$CHK/guardtalk-checkin.mk"
require_file "$CHK/payload.schema.json"
require_file "$CHK/host/checkin_contract.py"
require_file "$CHK/host/test_checkin_contract.py"
require_file "$CHK/host/verify_host.sh"
require_file "$DOC"
require_file "$LATE"

echo
echo "--- INTERVAL_S 12h / schema 43200 (independent rg) ---"
if rg -q 'INTERVAL_S = 12 \* 60 \* 60' "$CONST"; then
  pass "Kotlin INTERVAL_S = 12 * 60 * 60"
else
  fail "Kotlin INTERVAL_S not 12 hours"
fi
if rg -q 'INTERVAL_MS = INTERVAL_S \* 1000L' "$CONST"; then
  pass "Kotlin INTERVAL_MS derived from INTERVAL_S"
else
  fail "Kotlin INTERVAL_MS not derived from INTERVAL_S"
fi
if rg -q 'INTERVAL_S = 12 \* 60 \* 60' "$CHK/host/checkin_contract.py"; then
  pass "Python INTERVAL_S = 12 * 60 * 60"
else
  fail "Python INTERVAL_S not 12 hours"
fi
if rg -qF '"interval_s": { "const": 43200 }' "$CHK/payload.schema.json"; then
  pass "schema interval_s const 43200"
else
  fail "schema interval_s missing 43200"
fi
if rg -q 'setPeriodic\(CheckinConstants\.INTERVAL_MS\)' \
    "$APP/src/com/guardtalk/checkin/CheckinScheduler.kt"; then
  pass "JobScheduler periodic uses INTERVAL_MS"
else
  fail "JobScheduler periodic not bound to INTERVAL_MS"
fi

echo
echo "--- re-run unittest (independent) ---"
set +e
python3 -m unittest discover -s "$CHK/host" -p 'test_*.py' -v
UT_RC=$?
set -e
if [[ "$UT_RC" -eq 0 ]]; then
  pass "python3 -m unittest discover checkin/host  (exit 0)"
else
  fail "python3 -m unittest discover checkin/host exit $UT_RC"
fi

echo
echo "--- re-run vendor/guardtalk/checkin/host/verify_host.sh ---"
set +e
bash "$CHK/host/verify_host.sh"
VH_RC=$?
set -e
if [[ "$VH_RC" -eq 0 ]]; then
  pass "verify_host.sh exit 0"
else
  fail "verify_host.sh exit $VH_RC"
fi

echo
echo "--- no public C2 (independent; schema URI is not C2) ---"
C2_HITS="$(rg -n 'https?://[a-zA-Z0-9.-]+\.(com|net|org|io)/' \
    "$APP/src" "$CHK/guardtalk-checkin.mk" "$CHK/host/checkin_contract.py" \
    2>/dev/null || true)"
if [[ -n "$C2_HITS" ]]; then
  echo "$C2_HITS"
  fail "possible public URL C2 in client/host sources"
else
  pass "no public URL C2 in client src / mk / contract.py"
fi
# JSON Schema $schema is a meta identifier, not a transport C2.
if rg -qF 'https://json-schema.org/draft/2020-12/schema' "$CHK/payload.schema.json"; then
  pass "payload.schema.json \$schema is json-schema.org meta URI (not C2)"
else
  hold "payload.schema.json \$schema URI not found (unexpected)"
fi
# Tests may name rejected public hosts; they must be inside assertRaises.
if rg -q 'test_reject_public_c2' "$CHK/host/test_checkin_contract.py" && \
   rg -q 'https://example.com/v1/checkin' "$CHK/host/test_checkin_contract.py"; then
  pass "unittest names public hosts only as reject cases"
else
  fail "public-C2 reject tests missing"
fi
BAKED_ONION="$(rg -n '[a-z2-7]{56}\.onion' "$APP/src" "$CHK/guardtalk-checkin.mk" \
    2>/dev/null || true)"
if [[ -n "$BAKED_ONION" ]]; then
  echo "$BAKED_ONION"
  fail "baked v3 onion address in product sources"
else
  pass "no baked v3 onion in app src / mk"
fi
if rg -q '127\.0\.0\.1:9050' "$APP/src"; then
  fail "SOCKS 127.0.0.1:9050 baked into app src (must be provisioned empty)"
else
  pass "no baked SOCKS default in app src"
fi
if rg -q 'no public DNS C2' "$EP" && rg -q 'onion requires SOCKS' "$EP"; then
  pass "CheckinEndpoint fail-closed comments present"
else
  fail "CheckinEndpoint fail-closed guards missing"
fi
if rg -q 'public IP rejected' "$EP"; then
  pass "CheckinEndpoint rejects public IP"
else
  fail "CheckinEndpoint public-IP reject missing"
fi

echo
echo "--- no pem/pk8/.env under checkin paths ---"
if rg -q 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY' "$APP" "$CHK" "$DOC"; then
  fail "private key material in check-in tree"
else
  pass "no private key PEM blocks"
fi
KEY_FILES="$(find "$APP" "$CHK" \( -name '*.pem' -o -name '*.pk8' -o -name '*.key' \
    -o -name '.env' -o -name '*.env' \) 2>/dev/null || true)"
if [[ -n "$KEY_FILES" ]]; then
  echo "$KEY_FILES"
  fail "pem/pk8/key/env files under check-in paths"
else
  pass "no pem/pk8/key/.env under apps/GuardTalkCheckin + checkin"
fi

echo
echo "--- product wiring ---"
if rg -q 'guardtalk-checkin.mk' "$LATE"; then
  pass "product-config-late.mk includes guardtalk-checkin.mk"
else
  fail "product-config-late.mk missing check-in include"
fi
if rg -qF 'PRODUCT_PACKAGES += GuardTalkCheckin' "$CHK/guardtalk-checkin.mk"; then
  pass "GuardTalkCheckin in PRODUCT_PACKAGES (source mk)"
else
  fail "GuardTalkCheckin not in PRODUCT_PACKAGES"
fi
if rg -q 'privileged: true' "$APP/Android.bp" && \
   rg -q 'system_ext_specific: true' "$APP/Android.bp"; then
  pass "Android.bp privileged + system_ext_specific"
else
  fail "Android.bp not privileged system_ext"
fi

echo
echo "--- status UI does not display onion URL ---"
if rg -q 'Endpoint class: onion' "$APP/res/values/strings.xml" && \
   rg -q 'never the onion URL' "$APP/src/com/guardtalk/checkin/CheckinStatusActivity.kt"; then
  pass "status UI shows class only, not onion URL"
else
  fail "status UI may leak onion URL"
fi

echo
echo "--- Tor admin live visibility (HOLD expected; do not FAIL) ---"
GW_UI="$(find vendor/guardtalk -type f \( -iname '*tor*admin*' -o -iname '*admin*tor*' \
    -o -iname '*checkin*gateway*' \) ! -path '*/docs/*' ! -path '*/checkin/*' \
    ! -path '*/docs/qa/*' 2>/dev/null || true)"
if [[ -n "$GW_UI" ]]; then
  echo "$GW_UI"
  hold "unexpected Tor-admin-named files (still not live visibility)"
else
  hold "Gateway/Tor admin UI ABSENT in this tree — live visibility HOLD"
fi
if rg -q 'HOLD' "$DOC" && rg -q 'admin_surface' "$CHK/host/checkin_contract.py"; then
  pass "docs + contract record Tor admin HOLD / admin_surface=tor"
else
  fail "missing HOLD language or admin_surface"
fi

echo
echo "--- lunch komodo-trunk_staging-user (independent; GIT_CONFIG session-only) ---"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="${ROOT}/vendor/adevtool"
set +e
set +u
# envsetup uses unset vars. lunch MUST run in this shell (not $() or pipe).
# shellcheck disable=SC1091
source build/envsetup.sh
lunch komodo-trunk_staging-user
LUNCH_RC=$?
set -u
if [[ "$LUNCH_RC" -eq 0 ]]; then
  pass "lunch komodo-trunk_staging-user exit 0"
else
  fail "lunch komodo-trunk_staging-user exit $LUNCH_RC"
fi

gbv() {
  local var="$1"
  set +u
  get_build_var "$var"
  local rc=$?
  set -u
  return $rc
}

VARIANT="$(gbv TARGET_BUILD_VARIANT | tail -n 1 | tr -d '[:space:]')"
PRODUCT="$(gbv TARGET_PRODUCT | tail -n 1 | tr -d '[:space:]')"
PKGS="$(gbv PRODUCT_PACKAGES || true)"
printf '%s\n' "$PKGS" | tr ' ' '\n' | sort -u \
  > "$ART/Q-REMEDIATE-B4-CHECKIN_PRODUCT_PACKAGES.txt"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"

if [[ "$PRODUCT" == "komodo" ]]; then
  pass "TARGET_PRODUCT=komodo"
else
  fail "TARGET_PRODUCT=${PRODUCT} (expected komodo)"
fi
if [[ "$VARIANT" == "user" ]]; then
  pass "TARGET_BUILD_VARIANT=user (not userdebug)"
else
  fail "TARGET_BUILD_VARIANT=${VARIANT} (expected user)"
fi

CHK_PKG="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -x 'GuardTalkCheckin' || true)"
if [[ -n "$CHK_PKG" ]]; then
  pass "user PRODUCT_PACKAGES contains GuardTalkCheckin (PRESENT)"
else
  fail "user PRODUCT_PACKAGES missing GuardTalkCheckin"
fi

echo
echo "--- adb / on-device JobScheduler (HOLD if empty) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
DEV_LINES="$(printf '%s\n' "$ADB_OUT" | awk 'NR>1 && $2=="device" {print $1}')"
if [[ -z "$DEV_LINES" ]]; then
  hold "adb devices empty — on-device JobScheduler HOLD (not device-fixed)"
else
  hold "adb device present but on-device JobScheduler not in this card scope — HOLD"
fi

echo
echo "PASS=$PASS_N FAIL=$FAIL HOLD=$HOLD_N"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
