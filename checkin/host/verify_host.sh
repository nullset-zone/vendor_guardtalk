#!/usr/bin/env bash
# Host-static checks for T-REMEDIATE-B4-CHECKIN (item 20).
# No USB. No commit. Tor admin live visibility is HOLD.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

APP="vendor/guardtalk/apps/GuardTalkCheckin"
CHK="vendor/guardtalk/checkin"
DOC="vendor/guardtalk/docs/SEIZURE_CHECKIN.md"
LATE="vendor/guardtalk/radio-excised/product-config-late.mk"
CONST="$APP/src/com/guardtalk/checkin/CheckinConstants.kt"
EP="$APP/src/com/guardtalk/checkin/CheckinEndpoint.kt"

require_file() {
  if [[ -f "$1" ]]; then pass "present: $1"; else fail "missing: $1"; fi
}

echo "=== T-REMEDIATE-B4-CHECKIN host verify (item 20) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo

echo "--- required files ---"
require_file "$APP/Android.bp"
require_file "$APP/AndroidManifest.xml"
require_file "$CONST"
require_file "$EP"
require_file "$APP/src/com/guardtalk/checkin/CheckinJobService.kt"
require_file "$CHK/guardtalk-checkin.mk"
require_file "$CHK/payload.schema.json"
require_file "$CHK/host/checkin_contract.py"
require_file "$DOC"
require_file "$LATE"

echo
echo "--- 12 h interval ---"
if rg -q 'INTERVAL_S = 12 \* 60 \* 60' "$CONST"; then
  pass "Kotlin INTERVAL_S is 12 hours"
else
  fail "Kotlin INTERVAL_S not 12 hours"
fi
if rg -q 'INTERVAL_S = 12 \* 60 \* 60' "$CHK/host/checkin_contract.py"; then
  pass "Python INTERVAL_S is 12 hours"
else
  fail "Python INTERVAL_S not 12 hours"
fi
if rg -qF '"interval_s": { "const": 43200 }' "$CHK/payload.schema.json"; then
  pass "schema interval_s const 43200"
else
  fail "schema interval_s missing 43200"
fi

echo
echo "--- no public C2 / no secrets ---"
C2_HITS="$(rg -n 'https?://[a-zA-Z0-9.-]+\.(com|net|org|io)/' \
    "$APP/src" "$CHK/host/checkin_contract.py" "$CHK/guardtalk-checkin.mk" \
    2>/dev/null || true)"
if [[ -n "$C2_HITS" ]]; then
  echo "$C2_HITS"
  fail "possible public URL C2 in client/host sources"
else
  pass "no public URL C2 in client/host sources"
fi
if rg -q 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY' "$APP" "$CHK" "$DOC"; then
  fail "private key material in check-in tree"
else
  pass "no private key material"
fi
KEY_FILES="$(find "$APP" "$CHK" \( -name '*.pem' -o -name '*.pk8' -o -name '*.key' \) \
    2>/dev/null || true)"
if [[ -n "$KEY_FILES" ]]; then
  fail "key files under check-in paths"
else
  pass "no pem/pk8/key files under check-in paths"
fi
if rg -q 'no public DNS C2' "$EP" && rg -q 'onion requires SOCKS' "$EP"; then
  pass "fail-closed onion/SOCKS + no public DNS in CheckinEndpoint"
else
  fail "fail-closed comments/guards missing in CheckinEndpoint"
fi

echo
echo "--- product wiring ---"
if rg -q 'guardtalk-checkin.mk' "$LATE"; then
  pass "product-config-late.mk includes guardtalk-checkin.mk"
else
  fail "product-config-late.mk missing check-in include"
fi
if rg -qF 'PRODUCT_PACKAGES += GuardTalkCheckin' "$CHK/guardtalk-checkin.mk"; then
  pass "GuardTalkCheckin in PRODUCT_PACKAGES"
else
  fail "GuardTalkCheckin not in PRODUCT_PACKAGES"
fi

echo
echo "--- contract unittest ---"
if python3 -m unittest discover -s "$CHK/host" -p 'test_*.py' -v; then
  pass "unittest checkin_contract"
else
  fail "unittest checkin_contract"
fi

echo
echo "--- Tor admin HOLD honesty ---"
if rg -q 'HOLD' "$DOC" && rg -q 'admin_surface' "$CHK/host/checkin_contract.py"; then
  pass "docs + contract record Tor admin HOLD / tor surface"
else
  fail "missing HOLD or admin_surface"
fi
hold "Gateway/Tor admin not in this GrapheneOS-worktree — live visibility HOLD"
hold "adb empty — not device-fixed"

echo
echo "PASS=$PASS_N FAIL=$FAIL HOLD=$HOLD_N"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
