#!/usr/bin/env bash
# Host rematch for T-REMEDIATE-B4-MESSENGER (item 19). Jami GuardTalk Messenger
# baked into komodo user PRODUCT_PACKAGES. Do not trust a missing APK as OK.
# No USB GO. No commit. PASS HOLD remains. Not device-fixed.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b4_messenger_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

APP_BP="vendor/guardtalk/apps/GuardTalkMessenger/Android.bp"
APP_MAN="vendor/guardtalk/apps/GuardTalkMessenger/AndroidManifest.xml"
APP_ACT="vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/MessengerActivity.kt"
APP_RPC="vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/JamiGatewayClient.kt"
APP_GW="vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/GatewayEndpoint.kt"
LATE="vendor/guardtalk/radio-excised/product-config-late.mk"
KOMODO_MK="vendor/guardtalk/device/komodo/guardtalk-messenger.mk"
HARDEN="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
PERM="vendor/guardtalk/permissions/default-permissions-com.guardtalk.messenger.xml"
SOP="vendor/guardtalk/docs/GATEWAY_MESSENGER_PROVISION.md"
APPS_EXCISE="vendor/guardtalk/feature-excised/apps-excised.mk"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
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
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then
    fail "$label (forbidden: $pat)"
  else
    pass "$label"
  fi
}

echo "=== T-REMEDIATE-B4-MESSENGER host rematch (item 19) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo

echo "--- required files ---"
require_file "$APP_BP"
require_file "$APP_MAN"
require_file "$APP_ACT"
require_file "$APP_RPC"
require_file "$APP_GW"
require_file "$LATE"
require_file "$KOMODO_MK"
require_file "$HARDEN"
require_file "$PERM"
require_file "$SOP"

echo
echo "--- package identity + Jami client ---"
require_rg 'name: "GuardTalkMessenger"' "$APP_BP" "Soong name GuardTalkMessenger"
require_rg 'product_specific: true' "$APP_BP" "product_specific bake"
require_rg 'package="com\.guardtalk\.messenger"' "$APP_MAN" "manifest com.guardtalk.messenger"
require_rg 'android.permission.INTERNET' "$APP_MAN" "INTERNET for Gateway jamid"
require_rg 'Account.type' "$APP_RPC" "Jami RING addAccount"
require_rg 'sendTextMessage' "$APP_RPC" "Jami sendTextMessage"
require_rg 'isRfc1918' "$APP_GW" "RFC1918 fail-closed"
require_rg '/jami/jsonrpc' "$APP_GW" "Gateway JSON-RPC path"
require_rg 'package="com\.guardtalk\.messenger"' "$PERM" "default-permissions XML"

echo
echo "--- PRODUCT_PACKAGES wiring ---"
require_rg 'PRODUCT_PACKAGES \+= GuardTalkMessenger' "$LATE" \
  "late pass PRODUCT_PACKAGES GuardTalkMessenger"
require_rg 'PRODUCT_SOONG_NAMESPACES \+= vendor/guardtalk/apps/GuardTalkMessenger' "$LATE" \
  "late Soong namespace"
require_rg 'PRODUCT_PACKAGES \+= GuardTalkMessenger' "$KOMODO_MK" \
  "komodo messenger.mk PRODUCT_PACKAGES"
require_rg 'guardtalk-messenger.mk' "$HARDEN" \
  "hardening includes messenger.mk"

echo
echo "--- no Play Store / browser / GMS in messenger wiring ---"
if rg -v '^\s*#' "$KOMODO_MK" | rg -q 'TrichromeChrome|AppStore|GmsCompat'; then
  fail "messenger.mk non-comment line adds browser/store/GMS"
else
  pass "messenger.mk does not add TrichromeChrome/AppStore/GmsCompat"
fi
require_rg 'No Play Store' "$SOP" "SOP forbids Play Store install"
require_rg 'TrichromeChrome' "$APPS_EXCISE" "apps-excised still lists TrichromeChrome"

echo
echo "--- packet rg ---"
rg -n "guardtalk.messenger|jami|Jami" vendor/guardtalk --glob '!out/**' \
  --glob '!**/docs/qa/_artifacts/**' --glob '!**/*.html' | head -n 80 || true

echo
echo "--- python structural rematch ---"
python3 - <<'PY'
import pathlib, re, sys

root = pathlib.Path(".")
fail = 0
pass_n = 0
hold_n = 0

def out(kind, msg):
    global fail, pass_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail += 1
    else:
        hold_n += 1

def read(p):
    return (root / p).read_text(encoding="utf-8", errors="replace")

man = read("vendor/guardtalk/apps/GuardTalkMessenger/AndroidManifest.xml")
if 'package="com.guardtalk.messenger"' in man:
    out("PASS", "manifest package com.guardtalk.messenger")
else:
    out("FAIL", "manifest package mismatch")

if "com.android.vending" in man or "org.chromium.chrome" in man:
    out("FAIL", "manifest references store/browser")
else:
    out("PASS", "manifest has no store/browser package")

gw = read("vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/GatewayEndpoint.kt")
if "isRfc1918" in gw and "JSONRPC_PATH" in gw:
    out("PASS", "GatewayEndpoint RFC1918 + JSONRPC_PATH")
else:
    out("FAIL", "GatewayEndpoint missing RFC1918 or path")

late = read("vendor/guardtalk/radio-excised/product-config-late.mk")
if re.search(r"PRODUCT_PACKAGES \+= GuardTalkMessenger", late):
    out("PASS", "late mk adds GuardTalkMessenger")
else:
    out("FAIL", "late mk missing GuardTalkMessenger")

sop = read("vendor/guardtalk/docs/GATEWAY_MESSENGER_PROVISION.md")
if "jamid" in sop and "PRODUCT_PACKAGES" in sop and "pm install" in sop:
    out("PASS", "SOP names jamid, bake, and rejects pm install")
else:
    out("FAIL", "SOP missing jamid/bake/pm-install language")

print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -eq 0 ]]; then
  pass "python structural rematch exit 0"
else
  fail "python structural rematch exit $PY_RC"
fi

echo
echo "--- lunch komodo-trunk_staging-user ---"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="${ROOT}/vendor/adevtool"
set +e
set +u
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

MSG="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -x 'GuardTalkMessenger' || true)"
if [[ -n "$MSG" ]]; then
  pass "user PRODUCT_PACKAGES contains GuardTalkMessenger"
else
  fail "user PRODUCT_PACKAGES missing GuardTalkMessenger"
fi

PERM_PKG="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -x 'default-permissions-com.guardtalk.messenger' || true)"
if [[ -n "$PERM_PKG" ]]; then
  pass "user PRODUCT_PACKAGES still has default-permissions-com.guardtalk.messenger"
else
  fail "default-permissions-com.guardtalk.messenger dropped from PRODUCT_PACKAGES"
fi

BAD="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -Ex 'TrichromeChrome|TrichromeChromeDualArch|AppStore' || true)"
if [[ -z "$BAD" ]]; then
  pass "user PRODUCT_PACKAGES: TrichromeChrome/AppStore ABSENT"
else
  fail "NEGATIVE HIT: browser/store in PRODUCT_PACKAGES: ${BAD}"
fi

ADB_OUT="$(adb devices 2>/dev/null || true)"
if echo "$ADB_OUT" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  hold "adb device attached — on-device Messenger e2e still PASS HOLD (not this card)"
else
  hold "adb devices empty — on-device Messenger e2e HOLD"
fi

hold "m GuardTalkMessenger not run this card (Soong compile HOLD until rebuild)"
hold "Gateway jamid e2e HOLD (no USB GO; PASS HOLD remains)"
hold "not device-fixed; never APPROVED"

echo
echo "SUMMARY PASS=${PASS_N} FAIL=${FAIL} HOLD=${HOLD_N}"
if [[ "$FAIL" -ne 0 ]]; then
  echo "VERDICT FAIL"
  exit 1
fi
echo "VERDICT PASS (host-static; PASS HOLD remains)"
exit 0
