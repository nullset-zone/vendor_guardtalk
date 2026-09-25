#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-USERBUILD (pair of T-REMEDIATE-B1-USERBUILD
# items 1, 2, 3, 5). Do not trust Backend/Architect lunch dumps.
# Host static + lunch. Device / xbin / m HOLD if adb empty or no user image.
# No product edits. No USB GO. No wipe. No commit.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b1_userbuild_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

KOMODO_HARDEN="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
USER_EXCISE="vendor/guardtalk/feature-excised/userbuild-excised.mk"
LATE="vendor/guardtalk/radio-excised/product-config-late.mk"
RADIO="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
POLICY="vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md"
SPL_DOC="vendor/guardtalk/docs/SPL_PIN.md"
SIDECAR="vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md"
SPL_FLAG="build/release/flag_values/trunk_staging/RELEASE_PLATFORM_SECURITY_PATCH.textproto"
GEN_PROP="build/soong/scripts/gen_build_prop.py"
ADB_DEBUG="system/core/rootdir/adb_debug.prop.in"
XBIN_SU="out/target/product/komodo/system/xbin/su"
XBIN_OR="out/target/product/komodo/system/xbin/overlay_remounter"
CERT_STEM="vendor/guardtalk/branding/signing-keys/releasekey"
EXPECTED_PIN="2026-09-05"
EXPECTED_LIVE="2026-02-05"

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

echo "=== Q-REMEDIATE-B1-USERBUILD independent rematch (items 1,2,3,5) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "Q-AVB=not started"
echo "USB_GO=not started"
echo

echo "--- required files ---"
require_file "$KOMODO_HARDEN"
require_file "$USER_EXCISE"
require_file "$LATE"
require_file "$RADIO"
require_file "$POLICY"
require_file "$SPL_DOC"
require_file "$SIDECAR"
require_file "$SPL_FLAG"
require_file "$GEN_PROP"
require_file "$ADB_DEBUG"

echo
echo "--- packet rg (su / overlay_remounter) ---"
rg -n "\\bsu\\b|overlay_remounter" \
  vendor/guardtalk/device/komodo \
  vendor/guardtalk/feature-excised \
  vendor/guardtalk/radio-excised || true
echo
echo "--- packet rg (adb.secure / release-keys / testkey) ---"
rg -n "ro.adb.secure|release-keys|testkey" \
  vendor/guardtalk/device/komodo \
  vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md || true
echo
echo "--- packet find (pem/pk8) ---"
PEM_PK8="$(find vendor/guardtalk \( -name '*.pem' -o -name '*.pk8' \) | head || true)"
if [[ -z "${PEM_PK8}" ]]; then
  pass "no *.pem / *.pk8 under vendor/guardtalk"
else
  fail "private key material under vendor/guardtalk: ${PEM_PK8}"
fi

echo
echo "--- static product wiring ---"
require_fixed "ro.adb.secure=1" "$KOMODO_HARDEN" "komodo harden sets ro.adb.secure=1"
require_fixed 'ifeq ($(TARGET_BUILD_VARIANT),user)' "$KOMODO_HARDEN" \
  "komodo harden user-gates production profile / cert"
require_fixed "PRODUCT_DEFAULT_DEV_CERTIFICATE := ${CERT_STEM}" "$KOMODO_HARDEN" \
  "komodo harden cert stem is releasekey"
require_fixed "GUARDTALK_SPL_PIN := ${EXPECTED_PIN}" "$KOMODO_HARDEN" \
  "komodo harden SPL pin of record is ${EXPECTED_PIN}"
# Comment mentions of testkey / ro.debuggable are allowed; Python checks assignments.

require_fixed 'ifeq ($(TARGET_BUILD_VARIANT),user)' "$USER_EXCISE" \
  "userbuild-excised.mk is user-gated"
require_fixed '$(filter-out $(GUARDTALK_USERBUILD_DROP),$(PRODUCT_PACKAGES))' "$USER_EXCISE" \
  "userbuild-excised.mk filter-out PRODUCT_PACKAGES"
require_fixed '$(filter-out $(GUARDTALK_USERBUILD_DROP),$(PRODUCT_PACKAGES_DEBUG))' "$USER_EXCISE" \
  "userbuild-excised.mk filter-out PRODUCT_PACKAGES_DEBUG"
require_fixed "GUARDTALK_USERBUILD_DROP := su overlay_remounter" "$USER_EXCISE" \
  "drop set is su overlay_remounter"
forbid_re 'PRODUCT_PACKAGES[[:space:]]*\+=' "$USER_EXCISE" \
  "userbuild-excised.mk does not add packages"

require_fixed "include vendor/guardtalk/feature-excised/userbuild-excised.mk" "$LATE" \
  "product-config-late.mk includes userbuild-excised.mk"
require_fixed "guardtalk-production-hardening.mk" "$RADIO" \
  "radio-excised includes per-device harden mk"

require_fixed "GUARDTALK_SPL_PIN := ${EXPECTED_PIN}" "$SPL_DOC" \
  "SPL_PIN.md documents pin ${EXPECTED_PIN}"
require_fixed "${EXPECTED_LIVE}" "$SPL_DOC" \
  "SPL_PIN.md documents live ${EXPECTED_LIVE}"
require_fixed "string_value: \"${EXPECTED_LIVE}\"" "$SPL_FLAG" \
  "trunk_staging RELEASE_PLATFORM_SECURITY_PATCH still ${EXPECTED_LIVE}"
forbid_re "string_value: \"${EXPECTED_PIN}\"" "$SPL_FLAG" \
  "trunk_staging flag is not silently ${EXPECTED_PIN}"

require_fixed 'if config["BuildVariant"] == "user":' "$GEN_PROP" \
  "gen_build_prop.py has user variant branch"
require_fixed "ro.adb.secure=1" "$GEN_PROP" \
  "AOSP user maps ro.adb.secure=1"
require_fixed "ro.debuggable=0" "$GEN_PROP" \
  "AOSP user maps ro.debuggable=0"
require_fixed "ro.adb.secure=0" "$ADB_DEBUG" \
  "debug_ramdisk adb_debug.prop.in still ro.adb.secure=0 (NOT product truth)"

require_fixed "ro.adb.secure=1" "$POLICY" \
  "policy documents product ro.adb.secure=1"
require_fixed "release-keys" "$POLICY" \
  "policy documents release-keys"
require_fixed "debug_ramdisk" "$POLICY" \
  "policy does not treat debug_ramdisk as product truth"
require_fixed "komodo-trunk_staging-userdebug" "$SIDECAR" \
  "sidecar documents userdebug lunch (not this product)"

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

harden = read("vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk")
excise = read("vendor/guardtalk/feature-excised/userbuild-excised.mk")
late = read("vendor/guardtalk/radio-excised/product-config-late.mk")
radio = read("vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk")
flag = read("build/release/flag_values/trunk_staging/RELEASE_PLATFORM_SECURITY_PATCH.textproto")
gen = read("build/soong/scripts/gen_build_prop.py")
adb_dbg = read("system/core/rootdir/adb_debug.prop.in")
spl = read("vendor/guardtalk/docs/SPL_PIN.md")

hb = user_block(harden)
hc = code_lines(hb or "")
if hb is None:
    out("FAIL", "komodo harden has no TARGET_BUILD_VARIANT=user block")
else:
    out("PASS", "komodo harden user block present")
    if any("ro.adb.secure=1" in line for line in hc):
        out("PASS", "ro.adb.secure=1 is inside the user block (product wiring)")
    else:
        out("FAIL", "ro.adb.secure=1 missing from user block")
    if any("ro.adb.secure=0" in line for line in hc):
        out("FAIL", "silent ADB: ro.adb.secure=0 inside user product block")
    else:
        out("PASS", "user product block does not set ro.adb.secure=0")
    if any(
        "PRODUCT_DEFAULT_DEV_CERTIFICATE" in line
        and "vendor/guardtalk/branding/signing-keys/releasekey" in line
        for line in hc
    ):
        out("PASS", "releasekey stem assigned inside user block")
    else:
        out("FAIL", "releasekey stem not assigned inside user block")
    if any("testkey" in line for line in hc):
        out("FAIL", "testkey is assigned in user product block")
    else:
        out("PASS", "testkey is not the user product cert stem")
    if any("ro.debuggable" in line for line in hc):
        out("FAIL", "user block PRODUCT-forces ro.debuggable")
    else:
        out("PASS", "user block does not PRODUCT-force ro.debuggable")

hcode = code_lines(harden)
if any("PLATFORM_SECURITY_PATCH" in line and ":=" in line for line in hcode):
    out("FAIL", "komodo harden assigns PLATFORM_SECURITY_PATCH (would invent live SPL)")
else:
    out("PASS", "komodo harden does not invent live PLATFORM_SECURITY_PATCH")
if any(
    re.search(r"PRODUCT_PACKAGES\s*\+=", line)
    and re.search(r"\b(su|overlay_remounter)\b", line)
    for line in hcode
):
    out("FAIL", "komodo harden adds su/overlay_remounter")
else:
    out("PASS", "komodo harden does not add su/overlay_remounter")

if "GUARDTALK_SPL_PIN := 2026-09-05" in harden:
    out("PASS", "pin of record GUARDTALK_SPL_PIN=2026-09-05 in harden mk")
else:
    out("FAIL", "GUARDTALK_SPL_PIN pin of record missing or not 2026-09-05")

eb = user_block(excise)
if eb is None:
    out("FAIL", "userbuild-excised.mk has no user gate")
else:
    out("PASS", "userbuild-excised.mk user-gated (userdebug leftover is sidecar)")
    if "PRODUCT_PACKAGES :=" in eb and "filter-out" in eb:
        out("PASS", "user filter-out of PRODUCT_PACKAGES")
    else:
        out("FAIL", "PRODUCT_PACKAGES filter-out missing in user block")
    if "PRODUCT_PACKAGES_DEBUG :=" in eb and "filter-out" in eb:
        out("PASS", "user filter-out of PRODUCT_PACKAGES_DEBUG")
    else:
        out("FAIL", "PRODUCT_PACKAGES_DEBUG filter-out missing in user block")
    if re.search(r"PRODUCT_PACKAGES\s*\+=", eb):
        out("FAIL", "userbuild-excised.mk adds packages")
    else:
        out("PASS", "userbuild-excised.mk is filter-out only")

if "include vendor/guardtalk/feature-excised/userbuild-excised.mk" in late:
    idx_feat = late.find("include vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk")
    idx_user = late.find("include vendor/guardtalk/feature-excised/userbuild-excised.mk")
    if idx_feat >= 0 and idx_user > idx_feat:
        out("PASS", "late include order: feature-excised then userbuild-excised")
    else:
        out("FAIL", "userbuild-excised.mk not after feature-excised in late mk")
else:
    out("FAIL", "product-config-late.mk missing userbuild-excised.mk include")

if "vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-production-hardening.mk" in radio:
    out("PASS", "radio-excised uses per-device harden mk (komodo file wins)")
else:
    out("FAIL", "radio-excised missing per-device harden lookup")

if 'string_value: "2026-02-05"' in flag:
    out("PASS", "live flag file still 2026-02-05 (do not invent 2026-09-05 as live)")
else:
    out("FAIL", f"unexpected live SPL flag contents: {flag.strip()!r}")

user_branch = re.search(
    r'if config\["BuildVariant"\] == "user":\n(?:.*\n){0,8}?.*ro\.adb\.secure=1',
    gen,
)
if user_branch:
    out("PASS", "AOSP user branch emits ro.adb.secure=1 (not debug_ramdisk)")
else:
    out("FAIL", "could not confirm AOSP user→ro.adb.secure=1 mapping")

dbg_off = re.search(
    r'if config\["BuildVariant"\] == "user":[\s\S]*?enable_target_debugging = False',
    gen,
)
if dbg_off:
    out("PASS", "AOSP user branch disables target debugging (ro.debuggable=0 path)")
else:
    out("FAIL", "could not confirm AOSP user disables target debugging")

if "ro.adb.secure=0" in adb_dbg and "/force_debuggable" in adb_dbg:
    out("PASS", "adb_debug.prop.in ro.adb.secure=0 is force_debuggable ramdisk, not product")
else:
    out("FAIL", "adb_debug.prop.in missing expected force_debuggable silent-ADB override")

if "2026-09-05" in spl and "2026-02-05" in spl and "HOLD" in spl:
    out("PASS", "SPL_PIN.md records pin vs live HOLD honestly")
else:
    out("FAIL", "SPL_PIN.md does not honestly record pin vs live HOLD")

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
CERT="$(gbv PRODUCT_DEFAULT_DEV_CERTIFICATE | tail -n 1 | tr -d '[:space:]')"
SPL="$(gbv PLATFORM_SECURITY_PATCH | tail -n 1 | tr -d '[:space:]')"
KEYS="$(gbv BUILD_KEYS | tail -n 1 | tr -d '[:space:]')"
PROPS="$(gbv PRODUCT_PROPERTY_OVERRIDES || true)"
PKGS="$(gbv PRODUCT_PACKAGES || true)"
PKGS_DBG="$(gbv PRODUCT_PACKAGES_DEBUG || true)"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"
echo "TARGET_BUILD_TYPE=${TYPE}"
echo "PRODUCT_DEFAULT_DEV_CERTIFICATE=${CERT}"
echo "PLATFORM_SECURITY_PATCH=${SPL}"
echo "BUILD_KEYS=${KEYS}"

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

if [[ "$CERT" == "$CERT_STEM" ]]; then
  pass "PRODUCT_DEFAULT_DEV_CERTIFICATE is releasekey stem"
elif [[ "$CERT" == *testkey* ]]; then
  fail "NEGATIVE HIT: test-keys as product cert stem (${CERT})"
else
  fail "PRODUCT_DEFAULT_DEV_CERTIFICATE=${CERT} (expected ${CERT_STEM})"
fi

case "$KEYS" in
  release-keys)
    pass "BUILD_KEYS=release-keys (post-sign already landed)"
    ;;
  dev-keys)
    hold "BUILD_KEYS=dev-keys until operator post-sign (not FAIL; not test-keys)"
    ;;
  test-keys)
    fail "NEGATIVE HIT: BUILD_KEYS=test-keys as product cert stem"
    ;;
  *)
    fail "BUILD_KEYS=${KEYS} unexpected"
    ;;
esac

if [[ "$SPL" == "$EXPECTED_LIVE" ]]; then
  hold "live PLATFORM_SECURITY_PATCH=${SPL} (pin of record ${EXPECTED_PIN}; do not invent live current SPL)"
elif [[ "$SPL" == "$EXPECTED_PIN" ]]; then
  fail "NEGATIVE HIT: live PLATFORM_SECURITY_PATCH claimed ${EXPECTED_PIN} while this card must not invent live SPL"
else
  fail "PLATFORM_SECURITY_PATCH=${SPL} unexpected (expected live HOLD ${EXPECTED_LIVE})"
fi

if echo "$PROPS" | tr ' ' '\n' | grep -Fxq "ro.adb.secure=1"; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains ro.adb.secure=1 on user"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing ro.adb.secure=1 on user"
fi
if echo "$PROPS" | tr ' ' '\n' | grep -Fxq "ro.adb.secure=0"; then
  fail "NEGATIVE HIT: silent ADB (ro.adb.secure=0 as product override)"
else
  pass "PRODUCT_PROPERTY_OVERRIDES does not set ro.adb.secure=0"
fi
if echo "$PROPS" | grep -Eq 'ro\.debuggable='; then
  fail "PRODUCT_PROPERTY_OVERRIDES PRODUCT-forces ro.debuggable"
else
  pass "no PRODUCT-force of ro.debuggable on user dump"
fi

SU_PKGS="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -Ex 'su|overlay_remounter' || true)"
if [[ -z "$SU_PKGS" ]]; then
  pass "user PRODUCT_PACKAGES: su and overlay_remounter ABSENT"
else
  fail "user PRODUCT_PACKAGES still has: ${SU_PKGS}"
fi
SU_DBG="$(printf '%s\n' "$PKGS_DBG" | tr ' ' '\n' | grep -Ex 'su|overlay_remounter' || true)"
if [[ -z "$SU_DBG" ]]; then
  pass "user PRODUCT_PACKAGES_DEBUG: su and overlay_remounter ABSENT"
else
  fail "user PRODUCT_PACKAGES_DEBUG still has: ${SU_DBG}"
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
  UD_CERT="$(gbv PRODUCT_DEFAULT_DEV_CERTIFICATE | tail -n 1 | tr -d '[:space:]')"
  UD_DBG="$(gbv PRODUCT_PACKAGES_DEBUG || true)"
  echo "userdebug TARGET_BUILD_VARIANT=${UD_VAR}"
  echo "userdebug PRODUCT_DEFAULT_DEV_CERTIFICATE=${UD_CERT}"
  if [[ "$UD_VAR" == "userdebug" ]]; then
    pass "sidecar lunch is userdebug (not product truth)"
  else
    fail "sidecar lunch variant ${UD_VAR} (expected userdebug)"
  fi
  UD_HIT="$(printf '%s\n' "$UD_DBG" | tr ' ' '\n' | grep -Ex 'su|overlay_remounter' || true)"
  if [[ -n "$UD_HIT" ]]; then
    pass "sidecar PRODUCT_PACKAGES_DEBUG still has su/overlay_remounter (not this product)"
  else
    hold "sidecar PRODUCT_PACKAGES_DEBUG missing su/overlay_remounter (unexpected; not product FAIL)"
  fi
  if [[ "$UD_CERT" == *testkey* ]]; then
    pass "sidecar cert stem still testkey (userdebug leftover is NOT product truth)"
  else
    hold "sidecar cert stem=${UD_CERT} (document only; product is user+releasekey)"
  fi
fi

echo
echo "--- xbin / m / adb (device HOLD if empty or not a built user image) ---"
if [[ -e "$XBIN_SU" || -e "$XBIN_OR" ]]; then
  hold "stale out xbin still present (m not a user image this stamp):"
  ls -l "$XBIN_SU" "$XBIN_OR" 2>/dev/null || true
else
  hold "out xbin su/overlay_remounter absent — still not a proven built user image (m not run by QA)"
fi
hold "m not run this QA stamp (not a built user image; never device-fixed)"

ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; do not start Q-ONDEVICE; not device-fixed"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — device HOLD, never device-fixed"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "ITEM5_LIVE_SPL=HOLD"
echo "BUILD_KEYS_POSTSIGN=HOLD"
echo "XBIN_M=HOLD"
echo "DEVICE=HOLD"
exit "$FAIL"
