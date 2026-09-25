#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-DURESS-USB (pair of T-REMEDIATE-B1-DURESS-USB
# item 7). Do not trust Backend/Architect lunch dumps.
# Host lunch + static rg + python truth-table. Wipe e2e HOLD. No USB GO.
# Do not invent green. Do not lock/wipe serial 54111FDAS000GN. No product edits.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b1_duress_usb_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

HARDEN="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
USB="frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java"
DURESS_HELPER="frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java"
DURESS_WIPE="frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java"
POLICY="vendor/guardtalk/docs/USB_PROTECTION_POLICY.md"
SERIAL="54111FDAS000GN"
FLAG="vendor.guardtalk.usb_duress_wipe.enabled=1"
ARTIFACT_DIR="vendor/guardtalk/docs/qa/_artifacts"
ARTIFACT="${ARTIFACT_DIR}/Q-REMEDIATE-B1-DURESS-USB_PRODUCT_PROPERTY_OVERRIDES.txt"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

require_fixed() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -qF -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

forbid_re() {
  local pat="$1" path="$2" label="$3"
  if [[ -e "$path" ]] && rg -q -- "$pat" "$path" 2>/dev/null; then
    fail "$label (forbidden pattern present: $pat)"
  else
    pass "$label"
  fi
}

echo "=== Q-REMEDIATE-B1-DURESS-USB independent rematch (item 7) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "WIPE_E2E=HOLD"
echo "GREEN=HOLD (do not invent)"
echo "LOCK_WIPE_${SERIAL}=not started"
echo "PASS_HOLD=remains"
echo

echo "--- required files ---"
require_file "$HARDEN"
require_file "$USB"
require_file "$DURESS_HELPER"
require_file "$DURESS_WIPE"
require_file "$POLICY"

echo
echo "--- packet rg (UsbPortSecurityHooks) ---"
rg -n "isVerifiedBootYellowOrGreen|usb_duress_wipe|mustDenyUsbDataFunctions|DATA_ROLE_DEVICE" "$USB" || true
echo
echo "--- packet rg (isVerifiedBootGreen must be ABSENT) ---"
if rg -n "isVerifiedBootGreen" "$USB"; then
  fail "isVerifiedBootGreen still present in UsbPortSecurityHooks.java"
else
  echo "(no matches — expected)"
  pass "isVerifiedBootGreen ABSENT from UsbPortSecurityHooks.java"
fi
echo
echo "--- packet rg (Reason.DURESS) ---"
rg -n "Reason.DURESS" frameworks/base/services/core/java/com/android/server/locksettings/ || true
echo
echo "--- packet rg (komodo user flag) ---"
rg -n "usb_duress_wipe|ro.adb.secure" "$HARDEN" || true

echo
echo "--- static Java / mk / policy ---"
require_fixed 'isVerifiedBootYellowOrGreen' "$USB" \
  "UsbPortSecurityHooks has isVerifiedBootYellowOrGreen"
require_fixed 'return "yellow".equals(state) || "green".equals(state);' "$USB" \
  "yellow or green accepted (exact equals, not orange/red/empty)"
require_fixed 'SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0")' "$USB" \
  "Java isUsbDuressWipeEnabled default remains \"0\""
require_fixed 'vendor.guardtalk.usb_duress_wipe.enabled' "$USB" \
  "USB duress prop name present"
require_fixed 'getCurrentDataRole() != UsbPortStatus.DATA_ROLE_DEVICE' "$USB" \
  "DATA_ROLE_DEVICE still required (NONE/HOST do not wipe)"
require_fixed 'DuressWipe.run(context);' "$USB" \
  "USB path still calls DuressWipe.run"
require_fixed 'public static boolean mustDenyUsbDataFunctions(Context ctx)' "$USB" \
  "mustDenyUsbDataFunctions still present"
require_fixed 'return GuardTalkUsbProtectionPolicy.mustDenyUsbData(deviceLocked, userUnlocked);' "$USB" \
  "mustDenyUsbDataFunctions still delegates to fail-closed policy"
require_fixed 'if (ctx == null) {' "$USB" \
  "mustDenyUsbDataFunctions still null-ctx fail-closed"
require_fixed 'if (!mustDenyUsbDataFunctions(ctx)) {' "$USB" \
  "sanitizeUsbFunctions still gated on mustDenyUsbDataFunctions"
require_fixed 'SecureWipeEngine.Reason.DURESS' "$DURESS_HELPER" \
  "DuressPasswordHelper still Reason.DURESS"
require_fixed 'SecureWipeEngine.run(context, SecureWipeEngine.Reason.DURESS);' "$DURESS_WIPE" \
  "DuressWipe.run still Reason.DURESS"
require_fixed 'vendor.guardtalk.usb_duress_wipe.enabled=1' "$HARDEN" \
  "hardening.mk assigns usb_duress_wipe.enabled=1"
require_fixed 'ro.adb.secure=1' "$HARDEN" \
  "USERBUILD ro.adb.secure=1 still in hardening.mk"
require_fixed 'ifeq ($(TARGET_BUILD_VARIANT),user)' "$HARDEN" \
  "hardening.mk still has user ifeq"
require_fixed 'yellow or green' "$POLICY" \
  "USB_PROTECTION_POLICY documents yellow or green"
require_fixed 'USB data-role **DEVICE**' "$POLICY" \
  "USB_PROTECTION_POLICY still requires USB data-role DEVICE"
require_fixed 'SecureWipeEngine.Reason.DURESS' "$POLICY" \
  "USB_PROTECTION_POLICY still documents lockscreen Reason.DURESS"
require_fixed '54111FDAS000GN' "$POLICY" \
  "USB_PROTECTION_POLICY names production-custody serial"
require_fixed 'no USB GO' "$POLICY" \
  "USB_PROTECTION_POLICY still forbids USB GO this stamp"

forbid_re 'isVerifiedBootGreen' "$USB" \
  "isVerifiedBootGreen identifier gone (renamed)"
forbid_re 'USB_DURESS_WIPE_ENABLED_PROP,\s*"1"' "$USB" \
  "Java default is not flipped to \"1\""
forbid_re 'ro\.boot\.verifiedbootstate[[:space:]]*=[[:space:]]*green' vendor/guardtalk/device/komodo \
  "komodo device tree does not PRODUCT-lie verifiedbootstate=green"
forbid_re 'getCurrentDataRole\(\) == UsbPortStatus.DATA_ROLE_NONE' "$USB" \
  "charge-only DATA_ROLE_NONE is not a wipe trigger"
forbid_re 'getCurrentDataRole\(\) == UsbPortStatus.DATA_ROLE_HOST' "$USB" \
  "DATA_ROLE_HOST is not a wipe trigger"

echo
echo "--- python structural rematch ---"
set +e
python3 - <<'PY'
import pathlib
import re
import sys

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
        fail = 1
    else:
        hold_n += 1

usb = (root / "frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java").read_text()
harden = (root / "vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk").read_text()
helper = (root / "frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java").read_text()
wipe = (root / "frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java").read_text()
policy = (root / "vendor/guardtalk/docs/USB_PROTECTION_POLICY.md").read_text()

if "isVerifiedBootGreen" in usb:
    out("FAIL", "isVerifiedBootGreen still in UsbPortSecurityHooks.java")
else:
    out("PASS", "isVerifiedBootGreen identifier ABSENT")

m = re.search(
    r"private static boolean isVerifiedBootYellowOrGreen\(String state\) \{\s*"
    r'return "yellow"\.equals\(state\) \|\| "green"\.equals\(state\);\s*'
    r"\}",
    usb,
)
if m:
    out("PASS", "isVerifiedBootYellowOrGreen body is yellow||green only")
else:
    out("FAIL", "could not confirm isVerifiedBootYellowOrGreen exact body")

def is_verified_boot_yellow_or_green(state):
    return state == "yellow" or state == "green"

cases = [
    ("yellow", True),
    ("green", True),
    ("orange", False),
    ("red", False),
    ("", False),
    ("YELLOW", False),
    ("Green", False),
    ("yellow ", False),
    (" green", False),
    ("unknown", False),
    ("orange-red", False),
]
truth_fail = False
for state, expect in cases:
    got = is_verified_boot_yellow_or_green(state)
    if got != expect:
        out("FAIL", f"truth table {state!r} expected {expect} got {got}")
        truth_fail = True
if not truth_fail:
    out("PASS", "truth table: yellow/green accept; orange/red/empty/case/space reject")

if 'SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0")' in usb:
    out("PASS", "Java flag default remains \"0\" (userdebug/unset stay opt-in)")
else:
    out("FAIL", "Java flag default drifted from \"0\"")

if re.search(r'USB_DURESS_WIPE_ENABLED_PROP,\s*"1"', usb):
    out("FAIL", "NEGATIVE HIT: Java default flipped to \"1\"")
else:
    out("PASS", "Java default is not \"1\"")

if "getCurrentDataRole() != UsbPortStatus.DATA_ROLE_DEVICE" in usb:
    out("PASS", "DATA_ROLE_DEVICE required (NONE/HOST return before wipe)")
else:
    out("FAIL", "DATA_ROLE_DEVICE gate missing")

if "maybeTriggerUsbDuressWipe" in usb and "isVerifiedBootYellowOrGreen(vbootState)" in usb:
    out("PASS", "USB wipe path gates on isVerifiedBootYellowOrGreen")
else:
    out("FAIL", "USB wipe path missing yellow-or-green gate")

if "DuressWipe.run(context);" in usb:
    out("PASS", "USB path still DuressWipe.run (same engine as lockscreen)")
else:
    out("FAIL", "USB path no longer calls DuressWipe.run")

deny_fn = "public static boolean mustDenyUsbDataFunctions(Context ctx)" in usb
deny_use = usb.count("mustDenyUsbDataFunctions(") >= 6
null_closed = re.search(
    r"if \(ctx == null\) \{\s*return true;",
    usb,
)
if deny_fn and deny_use and null_closed:
    out("PASS", "mustDenyUsbDataFunctions present, used, null-ctx fail-closed")
else:
    out("FAIL", f"charge-only path weakened deny_fn={deny_fn} uses={usb.count('mustDenyUsbDataFunctions(')} null={bool(null_closed)}")

if "GuardTalkUsbProtectionPolicy.stripBlockedDataFunctions" in usb:
    out("PASS", "sanitizeUsbFunctions still strips blocked data functions")
else:
    out("FAIL", "gadget strip missing from sanitizeUsbFunctions")

if "SecureWipeEngine.Reason.DURESS" in helper:
    out("PASS", "DuressPasswordHelper still Reason.DURESS")
else:
    out("FAIL", "DuressPasswordHelper Reason.DURESS missing")

if "SecureWipeEngine.run(context, SecureWipeEngine.Reason.DURESS);" in wipe:
    out("PASS", "DuressWipe.run still Reason.DURESS")
else:
    out("FAIL", "DuressWipe.run Reason.DURESS missing")

user_block = re.search(
    r"ifeq\s+\(\$\(TARGET_BUILD_VARIANT\),user\)\s*(.*?)\s*endif",
    harden,
    flags=re.S,
)
if not user_block:
    out("FAIL", "could not find user ifeq in hardening.mk")
else:
    body = user_block.group(1)
    if "vendor.guardtalk.usb_duress_wipe.enabled=1" in body and "ro.adb.secure=1" in body:
        out("PASS", "user ifeq contains usb_duress_wipe.enabled=1 next to ro.adb.secure=1")
    else:
        out("FAIL", "user ifeq missing flag=1 and/or ro.adb.secure=1")
    outside = harden[: user_block.start()] + harden[user_block.end() :]
    outside_code = "\n".join(
        ln for ln in outside.splitlines() if not ln.lstrip().startswith("#")
    )
    if "vendor.guardtalk.usb_duress_wipe.enabled=1" in outside_code:
        out("FAIL", "flag=1 assigned outside user ifeq (userdebug would inherit)")
    else:
        out("PASS", "flag=1 is user-gated only (not in un-gated overrides)")

if (
    "yellow or green" in policy
    and "data-role **DEVICE**" in policy
    and "DATA_ROLE_NONE" in policy
    and "Reason.DURESS" in policy
):
    out("PASS", "USB_PROTECTION_POLICY documents yellow/green + DEVICE + DURESS")
else:
    out("FAIL", "USB_PROTECTION_POLICY missing yellow/green or DEVICE or DURESS")

if "do not invent" in policy.lower() or "Do not invent on-device" in policy:
    out("PASS", "USB_PROTECTION_POLICY forbids inventing on-device boot color")
else:
    out("HOLD", "policy invent-green language not exact; host still will not invent")

print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
set -e
if [[ "$PY_RC" -eq 0 ]]; then
  pass "python structural rematch exit 0"
else
  fail "python structural rematch exit $PY_RC"
fi

echo
echo "--- lunch komodo-trunk_staging-user (independent; do not skip) ---"
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
PROPS="$(gbv PRODUCT_PROPERTY_OVERRIDES || true)"
PKGS="$(gbv PRODUCT_PACKAGES || true)"
PKGS_DBG="$(gbv PRODUCT_PACKAGES_DEBUG || true)"

mkdir -p "$ARTIFACT_DIR"
printf '%s\n' "$PROPS" > "$ARTIFACT"
echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"
echo "PRODUCT_PROPERTY_OVERRIDES written to ${ARTIFACT}"

if [[ "$PRODUCT" == "komodo" ]]; then
  pass "TARGET_PRODUCT=komodo"
else
  fail "TARGET_PRODUCT=${PRODUCT} (expected komodo)"
fi
if [[ "$VARIANT" == "user" ]]; then
  pass "TARGET_BUILD_VARIANT=user (not userdebug)"
elif [[ "$VARIANT" == "userdebug" ]]; then
  fail "NEGATIVE HIT: userdebug leftover as product lunch truth (variant=$VARIANT)"
else
  fail "TARGET_BUILD_VARIANT=${VARIANT} (expected user)"
fi

PROP_LINES="$(printf '%s\n' "$PROPS" | tr ' ' '\n')"
if echo "$PROP_LINES" | grep -Fxq "$FLAG"; then
  pass "user PRODUCT_PROPERTY_OVERRIDES contains ${FLAG}"
else
  fail "user PRODUCT_PROPERTY_OVERRIDES missing ${FLAG}"
fi
if echo "$PROP_LINES" | grep -Fxq "vendor.guardtalk.usb_duress_wipe.enabled=0"; then
  fail "NEGATIVE HIT: user overrides also set usb_duress_wipe.enabled=0"
else
  pass "user PRODUCT_PROPERTY_OVERRIDES does not set usb_duress_wipe.enabled=0"
fi
if echo "$PROP_LINES" | grep -Fxq "ro.adb.secure=1"; then
  pass "user PRODUCT_PROPERTY_OVERRIDES still contains ro.adb.secure=1"
else
  fail "USERBUILD regression: ro.adb.secure=1 missing from user overrides"
fi
if echo "$PROP_LINES" | grep -Fxq "ro.guardtalk.production_profile=1"; then
  pass "user PRODUCT_PROPERTY_OVERRIDES still contains ro.guardtalk.production_profile=1"
else
  fail "user production_profile=1 missing from overrides"
fi
if echo "$PROP_LINES" | grep -Eq '^ro\.boot\.verifiedbootstate=green$'; then
  fail "NEGATIVE HIT: PRODUCT-lie ro.boot.verifiedbootstate=green in overrides"
else
  pass "user PRODUCT_PROPERTY_OVERRIDES does not PRODUCT-lie verifiedbootstate=green"
fi

SU_PKGS="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -Ex 'su|overlay_remounter' || true)"
if [[ -z "$SU_PKGS" ]]; then
  pass "user PRODUCT_PACKAGES: su/overlay_remounter ABSENT (USERBUILD not regressed)"
else
  fail "USERBUILD regression: PRODUCT_PACKAGES still has ${SU_PKGS}"
fi
SU_DBG="$(printf '%s\n' "$PKGS_DBG" | tr ' ' '\n' | grep -Ex 'su|overlay_remounter' || true)"
if [[ -z "$SU_DBG" ]]; then
  pass "user PRODUCT_PACKAGES_DEBUG: su/overlay_remounter ABSENT"
else
  fail "USERBUILD regression: PRODUCT_PACKAGES_DEBUG still has ${SU_DBG}"
fi

echo
echo "--- lunch komodo-trunk_staging-userdebug (sidecar adversarial; not product) ---"
set +e
set +u
lunch komodo-trunk_staging-userdebug
UD_RC=$?
set -u
if [[ "$UD_RC" -ne 0 ]]; then
  hold "userdebug sidecar lunch failed rc=$UD_RC (not product FAIL; static user ifeq is SoT)"
else
  UD_VAR="$(gbv TARGET_BUILD_VARIANT | tail -n 1 | tr -d '[:space:]')"
  echo "userdebug TARGET_BUILD_VARIANT=${UD_VAR}"
  if [[ "$UD_VAR" == "userdebug" ]]; then
    pass "sidecar lunch is userdebug (not product truth)"
  else
    fail "sidecar lunch variant ${UD_VAR} (expected userdebug)"
  fi
  UD_PROPS="$(timeout 120 bash -c 'get_build_var PRODUCT_PROPERTY_OVERRIDES' 2>/dev/null || true)"
  if [[ -z "$UD_PROPS" ]]; then
    hold "userdebug PRODUCT_PROPERTY_OVERRIDES dump empty/timeout (static user ifeq is SoT; not product FAIL)"
  else
    UD_LINES="$(printf '%s\n' "$UD_PROPS" | tr ' ' '\n')"
    if echo "$UD_LINES" | grep -Fxq "$FLAG"; then
      fail "NEGATIVE HIT: sidecar inherited ${FLAG} (user-gate broken)"
    else
      pass "sidecar PRODUCT_PROPERTY_OVERRIDES does not contain ${FLAG} (Java default 0)"
    fi
  fi
fi

echo
echo "--- wipe e2e / adb / USB GO (HOLD; do not execute) ---"
hold "wipe e2e HOLD — designated test unit + operator GO required; not this card"
hold "USB GO NOT executed (no fastboot, no lock, no wipe of ${SERIAL})"
hold "verifiedbootstate green NOT claimed (do not invent live boot color)"

ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q "${SERIAL}[[:space:]]"; then
  hold "adb sees ${SERIAL} — this card is host-only; do not getprop boot color; do not lock; do not wipe; not device-fixed"
else
  hold "adb devices empty / no komodo ${SERIAL} — device HOLD, never device-fixed, never lock/wipe"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "GREEN=HOLD"
echo "WIPE_E2E=HOLD"
echo "USB_GO=not started"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
exit "$FAIL"
