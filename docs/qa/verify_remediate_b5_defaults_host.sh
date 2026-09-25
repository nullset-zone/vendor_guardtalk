#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B5-DEFAULTS (pair of T-REMEDIATE-B5-DEFAULTS
# item 24). Do not trust Backend/Architect lunch dumps.
# Host static + lunch. Stale out/ and empty adb are HOLD, not product FAIL.
# Do not claim MTP impossible when unlocked (AOSP getChargingFunctions HOLD).
# No product edits. No USB GO. No wipe. No commit.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b5_defaults_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

DEFAULTS_MK="vendor/guardtalk/device/komodo/guardtalk-defaults.mk"
INIT_RC="vendor/guardtalk/device/komodo/init.guardtalk.defaults.rc"
HARDEN="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
REGEN="vendor/guardtalk/device/komodo/REGEN_HOOKS.md"
RADIO="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
OVL_BP="vendor/guardtalk/overlays/GuardTalkSettingsProviderOverlay/Android.bp"
OVL_MAN="vendor/guardtalk/overlays/GuardTalkSettingsProviderOverlay/AndroidManifest.xml"
OVL_XML="vendor/guardtalk/overlays/GuardTalkSettingsProviderOverlay/res/values/defaults.xml"
USB_JAVA="frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"
STALE_PROP="out/target/product/komodo/product/etc/build.prop"

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

prop_in() {
  local blob="$1" needle="$2"
  printf '%s\n' "$blob" | tr -s '[:space:]' '\n' | grep -Fxq -- "$needle"
}

echo "=== Q-REMEDIATE-B5-DEFAULTS independent rematch (item 24) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "MTP_UNLOCKED_CLAIM=forbidden (getChargingFunctions HOLD)"
echo

echo "--- required files ---"
require_file "$DEFAULTS_MK"
require_file "$INIT_RC"
require_file "$HARDEN"
require_file "$REGEN"
require_file "$RADIO"
require_file "$OVL_BP"
require_file "$OVL_MAN"
require_file "$OVL_XML"
require_file "$USB_JAVA"

echo
echo "--- packet rg (dataroaming / mtp / bug_report / lock_screen) ---"
rg -n "dataroaming|mtp|bug_report|lock_screen_show_notifications" \
  vendor/guardtalk/device/komodo \
  vendor/guardtalk/overlays/GuardTalkSettingsProviderOverlay || true
echo

echo "--- static product wiring ---"
require_fixed "include vendor/guardtalk/device/komodo/guardtalk-defaults.mk" "$HARDEN" \
  "komodo harden includes guardtalk-defaults.mk"
require_fixed "GuardTalkSettingsProviderOverlay" "$DEFAULTS_MK" \
  "defaults.mk adds GuardTalkSettingsProviderOverlay"
require_fixed "ro.com.android.dataroaming=false" "$DEFAULTS_MK" \
  "defaults.mk sets ro.com.android.dataroaming=false"
require_fixed "persist.sys.usb.config=none" "$DEFAULTS_MK" \
  "defaults.mk sets persist.sys.usb.config=none"
require_fixed "persist.sys.bug_report=0" "$DEFAULTS_MK" \
  "defaults.mk sets persist.sys.bug_report=0"
require_fixed 'ifeq ($(TARGET_BUILD_VARIANT),user)' "$DEFAULTS_MK" \
  "usb/bug_report overrides are user-gated"
require_fixed "init.guardtalk.defaults.rc" "$DEFAULTS_MK" \
  "defaults.mk copies init.guardtalk.defaults.rc"
require_fixed "persist.radio.disabled=1" "$RADIO" \
  "radio-excised still sets persist.radio.disabled=1"
# Comments may name these props; only live assignments fail.
forbid_re '^[[:space:]]*persist\.radio\.disabled=' "$DEFAULTS_MK" \
  "defaults.mk does not assign persist.radio.disabled"
forbid_re "ro.com.android.dataroaming=true" "vendor/guardtalk/device/komodo" \
  "komodo vendor does not assign dataroaming=true"
forbid_re '^[[:space:]]*persist\.security\.usb_mode=' "$DEFAULTS_MK" \
  "defaults.mk does not assign persist.security.usb_mode"
forbid_re "PRODUCT_DEFAULT_DEV_CERTIFICATE" "$DEFAULTS_MK" \
  "defaults.mk does not rewrite USERBUILD cert stem"
forbid_re "BOARD_AVB" "$DEFAULTS_MK" \
  "defaults.mk does not rewrite AVB"
forbid_re 'PRODUCT_PACKAGES[[:space:]]*\+=.*\bsu\b' "$DEFAULTS_MK" \
  "defaults.mk does not add su"

require_fixed 'name: "GuardTalkSettingsProviderOverlay"' "$OVL_BP" \
  "overlay Soong name GuardTalkSettingsProviderOverlay"
require_fixed "product_specific: true" "$OVL_BP" \
  "overlay is product_specific"
require_fixed 'certificate: "platform"' "$OVL_BP" \
  "overlay is platform-signed"
require_fixed 'android:targetPackage="com.android.providers.settings"' "$OVL_MAN" \
  "overlay targets SettingsProvider"
require_fixed 'android:isStatic="true"' "$OVL_MAN" \
  "overlay is static"
require_fixed '<integer name="def_lock_screen_show_notifications">0</integer>' "$OVL_XML" \
  "overlay def_lock_screen_show_notifications=0"
require_fixed '<bool name="def_usb_mass_storage_enabled">false</bool>' "$OVL_XML" \
  "overlay def_usb_mass_storage_enabled=false"

require_fixed "property:ro.debuggable=0" "$INIT_RC" \
  "vendor init re-assert is user-only (ro.debuggable=0)"
require_fixed "setprop persist.sys.usb.config none" "$INIT_RC" \
  "vendor init re-asserts persist.sys.usb.config none"
require_fixed "setprop persist.sys.bug_report 0" "$INIT_RC" \
  "vendor init re-asserts persist.sys.bug_report 0"
forbid_re "rild|start radio|ril-daemon" "$INIT_RC" \
  "vendor init does not start RIL"

echo
echo "--- python structural rematch ---"
set +e
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
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

def read(rel):
    p = root / rel
    if not p.is_file():
        out("FAIL", f"unreadable {rel}")
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

def code_lines(src):
    lines = []
    for line in src.splitlines():
        s = line.split("#", 1)[0].strip()
        if s:
            lines.append(s)
    return lines

def user_block(src):
    m = re.search(r"ifeq\s+\(\$\(TARGET_BUILD_VARIANT\),user\)", src)
    if not m:
        return None
    return src[m.start():]

defaults = read("vendor/guardtalk/device/komodo/guardtalk-defaults.mk")
harden = read("vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk")
init_rc = read("vendor/guardtalk/device/komodo/init.guardtalk.defaults.rc")
xml = read("vendor/guardtalk/overlays/GuardTalkSettingsProviderOverlay/res/values/defaults.xml")
usb = read("frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java")
radio = read("vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk")

if "include vendor/guardtalk/device/komodo/guardtalk-defaults.mk" in harden:
    out("PASS", "hardening.mk include of defaults.mk present")
else:
    out("FAIL", "hardening.mk missing defaults.mk include")

dc = code_lines(defaults)
if any("ro.com.android.dataroaming=false" in line for line in dc):
    out("PASS", "dataroaming=false is a live assignment (not comment-only)")
else:
    out("FAIL", "dataroaming=false missing from defaults.mk code")
if any("ro.com.android.dataroaming=true" in line for line in dc):
    out("FAIL", "NEGATIVE HIT: dataroaming=true assigned in defaults.mk")
else:
    out("PASS", "defaults.mk does not assign dataroaming=true")
if any(re.search(r"persist\.radio\.disabled\s*=", line) for line in dc):
    out("FAIL", "defaults.mk rewrites persist.radio.disabled")
else:
    out("PASS", "defaults.mk leaves persist.radio.disabled to radio-excised")
if any("persist.radio.disabled=1" in line for line in code_lines(radio)):
    out("PASS", "radio-excised still assigns persist.radio.disabled=1")
else:
    out("FAIL", "persist.radio.disabled=1 missing from radio-excised")

ub = user_block(defaults)
if ub is None:
    out("FAIL", "defaults.mk has no TARGET_BUILD_VARIANT=user gate")
else:
    out("PASS", "defaults.mk user gate present")
    uc = code_lines(ub)
    if any("persist.sys.usb.config=none" in line for line in uc):
        out("PASS", "persist.sys.usb.config=none is inside the user block")
    else:
        out("FAIL", "persist.sys.usb.config=none missing from user block")
    if any("persist.sys.usb.config=mtp" in line for line in uc):
        out("FAIL", "NEGATIVE HIT: persist.sys.usb.config=mtp in user block")
    else:
        out("PASS", "user block does not set persist.sys.usb.config=mtp")
    if any("persist.sys.bug_report=0" in line for line in uc):
        out("PASS", "persist.sys.bug_report=0 is inside the user block")
    else:
        out("FAIL", "persist.sys.bug_report=0 missing from user block")

pre_user = defaults[: defaults.find("ifeq ($(TARGET_BUILD_VARIANT),user)")] if "ifeq ($(TARGET_BUILD_VARIANT),user)" in defaults else defaults
pre_c = code_lines(pre_user)
if any("persist.sys.usb.config=none" in line for line in pre_c):
    out("FAIL", "persist.sys.usb.config=none leaks outside user gate")
else:
    out("PASS", "persist.sys.usb.config=none does not leak to all variants")

if re.search(r'<integer\s+name="def_lock_screen_show_notifications">0</integer>', xml):
    out("PASS", "overlay integer def_lock_screen_show_notifications=0")
else:
    out("FAIL", "overlay missing def_lock_screen_show_notifications=0")
if re.search(r'<integer\s+name="def_lock_screen_show_notifications">1</integer>', xml):
    out("FAIL", "NEGATIVE HIT: overlay still defaults lock-screen notifications on")
else:
    out("PASS", "overlay does not default lock-screen notifications on")
if re.search(r'<bool\s+name="def_usb_mass_storage_enabled">false</bool>', xml):
    out("PASS", "overlay bool def_usb_mass_storage_enabled=false")
else:
    out("FAIL", "overlay missing def_usb_mass_storage_enabled=false")
if re.search(r'<bool\s+name="def_usb_mass_storage_enabled">true</bool>', xml):
    out("FAIL", "NEGATIVE HIT: overlay enables UMS by default")
else:
    out("PASS", "overlay does not enable UMS by default")

if "property:ro.debuggable=0" in init_rc and "setprop persist.sys.usb.config none" in init_rc:
    out("PASS", "init.rc user-only re-assert of persist.sys.usb.config none")
else:
    out("FAIL", "init.rc missing user-only usb none re-assert")
if re.search(r"^\s*(start|service)\s+", init_rc, re.M):
    out("FAIL", "init.rc starts a service (RIL/other out of scope)")
else:
    out("PASS", "init.rc is setprop-only (no service start)")

fn = re.search(
    r"protected long getChargingFunctions\(\)\s*\{[\s\S]*?return UsbManager\.FUNCTION_MTP;",
    usb,
)
if fn:
    out(
        "HOLD",
        "AOSP getChargingFunctions() still returns FUNCTION_MTP when unlocked and ADB off (frameworks HOLD; not this card; do not claim MTP impossible)",
    )
else:
    out(
        "HOLD",
        "getChargingFunctions() MTP return not found this stamp — still frameworks HOLD; do not claim MTP impossible when unlocked",
    )

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
TYPE="$(gbv TARGET_BUILD_TYPE | tail -n 1 | tr -d '[:space:]')"
PRODUCT="$(gbv TARGET_PRODUCT | tail -n 1 | tr -d '[:space:]')"
PROPS="$(gbv PRODUCT_PROPERTY_OVERRIDES || true)"
# File dump: command-substitution of the 35k PRODUCT_PACKAGES blob is a
# harness false-ABSENT under `script | tee` (nsjail + pipefail). Redirect
# is the source of truth; do not treat a missing $() blob as product FAIL.
PKGS_FILE="$(mktemp)"
COPY_FILE="$(mktemp)"
trap 'rm -f "$PKGS_FILE" "$COPY_FILE"' EXIT
set +u
get_build_var PRODUCT_PACKAGES >"$PKGS_FILE"
get_build_var PRODUCT_COPY_FILES >"$COPY_FILE"
set -u
echo "PKGS_DUMP_BYTES=$(wc -c <"$PKGS_FILE") COPY_DUMP_BYTES=$(wc -c <"$COPY_FILE")"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"
echo "TARGET_BUILD_TYPE=${TYPE}"

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
if [[ "$TYPE" == "release" ]]; then
  pass "TARGET_BUILD_TYPE=release"
else
  fail "TARGET_BUILD_TYPE=${TYPE} (expected release)"
fi

if prop_in "$PROPS" "ro.com.android.dataroaming=false"; then
  pass "user lunch PRODUCT_PROPERTY_OVERRIDES ro.com.android.dataroaming=false"
else
  fail "user lunch missing ro.com.android.dataroaming=false"
fi
if prop_in "$PROPS" "ro.com.android.dataroaming=true"; then
  fail "NEGATIVE HIT: user lunch still has ro.com.android.dataroaming=true"
else
  pass "user lunch does not set ro.com.android.dataroaming=true"
fi
if prop_in "$PROPS" "persist.sys.usb.config=none"; then
  pass "user lunch PRODUCT_PROPERTY_OVERRIDES persist.sys.usb.config=none"
else
  fail "user lunch missing persist.sys.usb.config=none"
fi
if prop_in "$PROPS" "persist.sys.usb.config=mtp"; then
  fail "NEGATIVE HIT: user lunch persist.sys.usb.config=mtp"
else
  pass "user lunch does not set persist.sys.usb.config=mtp"
fi
if prop_in "$PROPS" "persist.sys.bug_report=0"; then
  pass "user lunch PRODUCT_PROPERTY_OVERRIDES persist.sys.bug_report=0"
else
  fail "user lunch missing persist.sys.bug_report=0"
fi
if prop_in "$PROPS" "persist.radio.disabled=1"; then
  pass "user lunch persist.radio.disabled=1 kept (RIL still excised)"
else
  fail "user lunch lost persist.radio.disabled=1"
fi

# Split dumpvars on any whitespace. Prefer glob on the file dump.
pkg_in_file() {
  local needle="$1" file="$2"
  grep -Fqw -- "$needle" "$file"
}

if pkg_in_file "GuardTalkSettingsProviderOverlay" "$PKGS_FILE"; then
  pass "user PRODUCT_PACKAGES: GuardTalkSettingsProviderOverlay PRESENT"
else
  fail "user PRODUCT_PACKAGES: GuardTalkSettingsProviderOverlay ABSENT"
fi
if grep -Fq -- "init.guardtalk.defaults.rc" "$COPY_FILE"; then
  pass "user PRODUCT_COPY_FILES includes init.guardtalk.defaults.rc"
else
  fail "user PRODUCT_COPY_FILES missing init.guardtalk.defaults.rc"
fi

SU_PKGS="$(tr -s '[:space:]' '\n' <"$PKGS_FILE" | grep -Ex 'su|overlay_remounter' || true)"
if [[ -z "$SU_PKGS" ]]; then
  pass "user PRODUCT_PACKAGES: su and overlay_remounter still ABSENT"
else
  fail "REGRESSION: user PRODUCT_PACKAGES has ${SU_PKGS}"
fi

echo
echo "--- lunch komodo-trunk_staging-userdebug (sidecar adversarial; not product) ---"
set +e
set +u
lunch komodo-trunk_staging-userdebug
UD_RC=$?
set -u
if [[ "$UD_RC" -ne 0 ]]; then
  hold "userdebug sidecar lunch failed rc=$UD_RC (not product FAIL)"
else
  UD_VAR="$(gbv TARGET_BUILD_VARIANT | tail -n 1 | tr -d '[:space:]')"
  UD_PROPS="$(gbv PRODUCT_PROPERTY_OVERRIDES || true)"
  echo "userdebug TARGET_BUILD_VARIANT=${UD_VAR}"
  if [[ "$UD_VAR" == "userdebug" ]]; then
    pass "sidecar lunch is userdebug (not product truth)"
  else
    fail "sidecar lunch variant ${UD_VAR} (expected userdebug)"
  fi
  if prop_in "$UD_PROPS" "ro.com.android.dataroaming=false"; then
    pass "sidecar still has ro.com.android.dataroaming=false (all-variant default)"
  else
    fail "sidecar lost ro.com.android.dataroaming=false"
  fi
  if prop_in "$UD_PROPS" "persist.sys.usb.config=none"; then
    fail "NEGATIVE HIT: sidecar leaked persist.sys.usb.config=none (user-only)"
  else
    pass "sidecar does not set persist.sys.usb.config=none (keeps AOSP adb)"
  fi
  if prop_in "$UD_PROPS" "persist.sys.bug_report=0"; then
    fail "NEGATIVE HIT: sidecar leaked persist.sys.bug_report=0 (user-only)"
  else
    pass "sidecar does not set persist.sys.bug_report=0"
  fi
fi

echo
echo "--- stale out/ (HOLD, never product FAIL) ---"
if [[ -f "$STALE_PROP" ]]; then
  if rg -qF "ro.com.android.dataroaming=true" "$STALE_PROP"; then
    hold "stale out/ product build.prop still ro.com.android.dataroaming=true (m not run; not product FAIL)"
  elif rg -qF "ro.com.android.dataroaming=false" "$STALE_PROP"; then
    hold "stale out/ product build.prop has dataroaming=false — still not a proven rebuilt user image (m not run by QA)"
  else
    hold "stale out/ product build.prop present without dataroaming line (m not run; not product FAIL)"
  fi
  if rg -qF "persist.sys.usb.config" "$STALE_PROP"; then
    hold "stale out/ persist.sys.usb.config may contradict lunch until m (not product FAIL)"
  else
    hold "stale out/ has no persist.sys.usb.config line (not a rebuilt user image)"
  fi
else
  hold "stale out/ product build.prop absent — still not a proven built user image (m not run by QA)"
fi
hold "m not run this QA stamp (not a built user image; never device-fixed)"

echo
echo "--- frameworks getChargingFunctions (out of this card; HOLD) ---"
if rg -n "return UsbManager.FUNCTION_MTP;" "$USB_JAVA" | rg -q "getChargingFunctions|FUNCTION_MTP"; then
  hold "UsbDeviceManager.getChargingFunctions can still return MTP when unlocked with ADB off — frameworks HOLD; do not claim MTP impossible"
else
  hold "getChargingFunctions MTP path still frameworks HOLD (out of this card); unlocked MTP not claimed impossible"
fi
rg -n "getChargingFunctions|FUNCTION_MTP" "$USB_JAVA" | head -n 20 || true

echo
echo "--- adb (device HOLD if empty) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; not device-fixed; do not lift PASS HOLD"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — device HOLD, never device-fixed"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "STALE_OUT=HOLD"
echo "MTP_UNLOCKED=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
exit "$FAIL"
