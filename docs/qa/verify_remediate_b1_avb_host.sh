#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-AVBSCRIPT (pair of T-REMEDIATE-B1-AVB item 4).
# DEC-REMEDIATE-002 SoT. Do not trust Backend/Architect lunch dumps.
# Host lunch + static rg + find. Custom-key lock color is yellow; operator-goal
# green HOLD — do not invent green. USB duress gate = yellow OR green
# (isVerifiedBootYellowOrGreen). isVerifiedBootGreen ABSENT. komodo user product
# may set usb_duress_wipe.enabled=1 (not a FAIL). Java unset default may be "0".
# Device/lock HOLD if adb empty. Do not lock 54111FDAS000GN. No product Java/mk
# edits. No USB GO. No m. No FLASH_READY=true. No commit.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b1_avb_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

LATE="vendor/guardtalk/device/komodo/BoardConfig-excised-late.mk"
HARDEN="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
REGEN="vendor/guardtalk/device/komodo/REGEN_HOOKS.md"
RUNBOOK="vendor/guardtalk/branding/signing-keys/RUNBOOK.md"
POLICY="vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md"
GITIGN="vendor/guardtalk/branding/signing-keys/.gitignore"
AVB_PEM="vendor/guardtalk/branding/signing-keys/avb.pem"
USB="frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java"
GDEV_BC="vendor/google_devices/komodo/BoardConfig.mk"
AOSP_MAKE="build/make/core/Makefile"
FASTBOOT_RPT="vendor/guardtalk/docs/SECURITY_FASTBOOT_PROT_REPORT.md"
PROJECT_AVB="vendor/guardtalk/branding/signing-keys/avb.pem"
AOSP_TESTKEY="external/avb/test/data/testkey_rsa4096.pem"
CERT_STEM="vendor/guardtalk/branding/signing-keys/releasekey"
SERIAL="54111FDAS000GN"

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

require_re() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then
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

echo "=== Q-REMEDIATE-B1-AVBSCRIPT independent rematch (item 4 AVB + DEC-002 USB SoT) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "BLOCK2_Q=not started"
echo "USB_GO=not started"
echo "LOCK_${SERIAL}=not started"
echo "GREEN=HOLD (do not invent)"
echo "FLASH_READY=false (not invented)"
echo "DEC-002: USB gate yellow||green; user usb_duress_wipe.enabled=1 allowed"
echo

echo "--- required files ---"
require_file "$LATE"
require_file "$HARDEN"
require_file "$REGEN"
require_file "$RUNBOOK"
require_file "$POLICY"
require_file "$GITIGN"
require_file "$USB"
require_file "$GDEV_BC"
require_file "$AOSP_MAKE"
require_file "$FASTBOOT_RPT"

echo
echo "--- packet rg (BOARD_AVB_KEY_PATH / BOARD_AVB_ALGORITHM) ---"
rg -n "BOARD_AVB_KEY_PATH|BOARD_AVB_ALGORITHM" vendor/guardtalk/device/komodo || true
echo
echo "--- packet rg (USB duress + yellow-or-green gate) ---"
rg -n "usb_duress_wipe.enabled|isVerifiedBootYellowOrGreen|isVerifiedBootGreen" "$USB" || true
echo
echo "--- packet find (pem/pk8) ---"
PEM_PK8="$(find vendor/guardtalk \( -name '*.pem' -o -name '*.pk8' \) | head || true)"
if [[ -z "${PEM_PK8}" ]]; then
  pass "no *.pem / *.pk8 under vendor/guardtalk"
else
  fail "private key material under vendor/guardtalk: ${PEM_PK8}"
fi

echo
echo "--- avb.pem must be ABSENT ---"
if test ! -f "$AVB_PEM"; then
  pass "test ! -f ${AVB_PEM} (ABSENT as required)"
else
  fail "NEGATIVE HIT: ${AVB_PEM} exists on this host (keys must stay offline)"
fi

echo
echo "--- git index must not contain pem/pk8 ---"
GIT_KEYS="$(git ls-files -- 'vendor/guardtalk/**/*.pem' 'vendor/guardtalk/**/*.pk8' 'vendor/guardtalk/**/avb.pem' 2>/dev/null || true)"
if [[ -z "${GIT_KEYS}" ]]; then
  pass "git ls-files: no pem/pk8/avb.pem under vendor/guardtalk"
else
  fail "NEGATIVE HIT: git tracks key material: ${GIT_KEYS}"
fi

echo
echo "--- static BoardConfig / docs / USB ---"
require_fixed "BOARD_AVB_ALGORITHM := SHA256_RSA4096" "$LATE" \
  "late BoardConfig sets SHA256_RSA4096"
require_fixed "BOARD_AVB_KEY_PATH ?= vendor/guardtalk/branding/signing-keys/avb.pem" "$LATE" \
  "late BoardConfig default path is project avb.pem (not AOSP testkey)"
require_fixed 'ifeq ($(TARGET_BUILD_VARIANT),user)' "$LATE" \
  "late BoardConfig AVB is user-gated"
require_fixed "include vendor/guardtalk/device/komodo/BoardConfig-excised-late.mk" "$GDEV_BC" \
  "vendor/google_devices/komodo/BoardConfig.mk includes late mk"
if [[ -d "device/google/komodo" ]]; then
  hold "device/google/komodo exists — pointer may also live there (document only)"
else
  pass "device/google/komodo absent (pointer lives in vendor/guardtalk late mk)"
fi
forbid_re 'BOARD_AVB_KEY_PATH[[:space:]]*[?:]*=.*testkey' "$LATE" \
  "late BoardConfig assignment is not AOSP testkey_rsa4096"
require_fixed "external/avb/test/data/testkey_rsa4096.pem" "$AOSP_MAKE" \
  "AOSP Makefile still has testkey fallback when BOARD_AVB_KEY_PATH unset"
require_fixed "## 12. Komodo (Pixel 9 Pro XL) — T-REMEDIATE-B1-AVB" "$RUNBOOK" \
  "RUNBOOK §12 komodo section exists"
require_fixed "### 12c. Komodo lock procedure (operator + designated test unit only)" "$RUNBOOK" \
  "RUNBOOK §12c komodo lock procedure exists"
require_fixed "fastboot flashing lock" "$RUNBOOK" \
  "RUNBOOK documents fastboot flashing lock"
require_fixed "${SERIAL}" "$RUNBOOK" \
  "RUNBOOK names production-custody serial ${SERIAL}"
require_fixed "do not lock" "$RUNBOOK" \
  "RUNBOOK forbids locking ${SERIAL} without operator GO"
require_fixed "**Pixel / GrapheneOS truth** (do not PRODUCT-lie):" "$RUNBOOK" \
  "RUNBOOK §12d documents Pixel truth vs operator goal"
require_fixed "reports **\`yellow\`**" "$RUNBOOK" \
  "RUNBOOK documents custom-key lock reports yellow"
require_fixed "**HOLD.** Not achievable with a GuardTalk project key." "$RUNBOOK" \
  "RUNBOOK documents green HOLD for project key"
require_fixed "This stamp does **not** claim green" "$RUNBOOK" \
  "RUNBOOK does not claim green as achieved"
require_fixed "Custom-key lock color = **yellow** (HOLD vs operator-goal green)." "$POLICY" \
  "POLICY Verified Boot row documents yellow HOLD vs green"
require_fixed "It does **not** claim green." "$POLICY" \
  "POLICY does not claim green as achieved"
require_fixed "A custom-AVB build like GuardTalkOS will **not** be \`green\` unless the AVB key is the OEM key." "$FASTBOOT_RPT" \
  "SECURITY_FASTBOOT_PROT_REPORT.md §4.1: custom-key is not green"
require_fixed "**This is GuardTalkOS's intended production state.**" "$FASTBOOT_RPT" \
  "SECURITY_FASTBOOT_PROT_REPORT.md §4.1: yellow is custom-key locked state"
require_fixed "*.pem" "$GITIGN" "signing-keys .gitignore covers *.pem"
require_fixed "*.pk8" "$GITIGN" "signing-keys .gitignore covers *.pk8"
require_fixed "avb.pem" "$GITIGN" "signing-keys .gitignore covers avb.pem"
require_fixed 'SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0")' "$USB" \
  "USB duress Java unset default is \"0\""
require_fixed 'isVerifiedBootYellowOrGreen' "$USB" \
  "USB duress gate is isVerifiedBootYellowOrGreen (DEC-002)"
require_fixed 'return "yellow".equals(state) || "green".equals(state);' "$USB" \
  "isVerifiedBootYellowOrGreen accepts yellow or green"
forbid_re 'isVerifiedBootGreen' "$USB" \
  "isVerifiedBootGreen identifier ABSENT (DEC-002 renamed)"
# DEC-002: komodo user product MAY set usb_duress_wipe.enabled=1. Not a FAIL.
USB_ON="$(rg -n 'usb_duress_wipe\.enabled[[:space:]]*=[[:space:]]*1' \
  vendor/guardtalk --glob '*.mk' --glob '*.prop' --glob '*.conf' --glob '*.rc' \
  --glob '*.xml' || true)"
if [[ -n "${USB_ON}" ]]; then
  pass "komodo user product may set usb_duress_wipe.enabled=1 (DEC-002; not a FAIL)"
else
  hold "no vendor/guardtalk usb_duress_wipe.enabled=1 (Java default 0 still valid; not FAIL)"
fi
forbid_re 'ro\.boot\.verifiedbootstate[[:space:]]*=[[:space:]]*green' vendor/guardtalk/device/komodo \
  "komodo device tree does not PRODUCT-lie verifiedbootstate=green"

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

late = (root / "vendor/guardtalk/device/komodo/BoardConfig-excised-late.mk").read_text()
usb = (root / "frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java").read_text()
runbook = (root / "vendor/guardtalk/branding/signing-keys/RUNBOOK.md").read_text()
policy = (root / "vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md").read_text()
harden = (root / "vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk").read_text()
aosp = (root / "build/make/core/Makefile").read_text()

user_block = re.search(
    r"ifeq\s+\(\$\(TARGET_BUILD_VARIANT\),user\)\s*"
    r"BOARD_AVB_ALGORITHM\s*:=\s*SHA256_RSA4096\s*"
    r"BOARD_AVB_KEY_PATH\s*\?=\s*vendor/guardtalk/branding/signing-keys/avb\.pem\s*"
    r"endif",
    late,
)
if user_block:
    out("PASS", "AVB algorithm+path are inside the user ifeq/endif (not userdebug)")
else:
    out("FAIL", "could not confirm user-only AVB block in BoardConfig-excised-late.mk")

outside = re.sub(
    r"ifeq\s+\(\$\(TARGET_BUILD_VARIANT\),user\).*?endif",
    "",
    late,
    flags=re.S,
)
outside_code = "\n".join(
    ln for ln in outside.splitlines() if not ln.lstrip().startswith("#")
)
if re.search(r"BOARD_AVB_KEY_PATH|BOARD_AVB_ALGORITHM", outside_code):
    out("FAIL", "AVB vars assigned outside the user ifeq (sidecar would inherit)")
else:
    out("PASS", "no BOARD_AVB_* assignments outside the user ifeq")

if "testkey_rsa4096.pem" in late.split("BOARD_AVB_KEY_PATH", 1)[-1][:200] and \
   "vendor/guardtalk/branding/signing-keys/avb.pem" not in late:
    out("FAIL", "late mk product path is AOSP testkey")
else:
    out("PASS", "late mk product path is not AOSP testkey")

fb = re.search(
    r"ifdef BOARD_AVB_KEY_PATH.*?else.*?BOARD_AVB_KEY_PATH\s*:=\s*"
    r"external/avb/test/data/testkey_rsa4096\.pem",
    aosp,
    flags=re.S,
)
if fb:
    out("PASS", "AOSP Makefile fallback to testkey_rsa4096.pem still present when unset")
else:
    out("FAIL", "could not confirm AOSP Makefile testkey fallback")

sec12 = re.search(r"^## 12\. Komodo \(Pixel 9 Pro XL\) — T-REMEDIATE-B1-AVB\s*$", runbook, re.M)
sec12c = "### 12c. Komodo lock procedure" in runbook
lock = "fastboot flashing lock" in runbook
serial = "54111FDAS000GN" in runbook and "do not lock" in runbook.lower()
if sec12 and sec12c and lock and serial:
    out("PASS", "RUNBOOK §12 + §12c lock + do-not-lock serial")
else:
    out("FAIL", f"RUNBOOK §12 incomplete sec12={bool(sec12)} 12c={sec12c} lock={lock} serial={serial}")

# Green PRODUCT-lie: claiming custom-key lock IS green (not documenting HOLD/goal).
lie_pat = re.compile(
    r"(custom[- ]key.{0,80}(is|reports|equals|==).{0,20}green)"
    r"|(verifiedbootstate\s*=\s*green.{0,40}(achieved|current|actual production))",
    re.I | re.S,
)
hold_ok = (
    "does **not** claim green" in runbook
    and "HOLD green" in runbook
    and "yellow" in runbook
)
if hold_ok and not lie_pat.search(runbook):
    out("PASS", "RUNBOOK documents yellow as Pixel custom-key truth; green not claimed")
else:
    out("FAIL", "RUNBOOK green/yellow documentation missing or PRODUCT-lies green")

if "does **not** claim green" in policy and "yellow" in policy and "HOLD green" in policy:
    out("PASS", "POLICY documents yellow Pixel truth and HOLD green")
else:
    out("FAIL", "POLICY missing yellow-vs-green HOLD language")

# hardening.mk must not PRODUCT-force boot color
if re.search(r"ro\.boot\.verifiedbootstate\s*:=", harden) or \
   re.search(r"verifiedbootstate=green", harden):
    out("FAIL", "hardening.mk PRODUCT-forces verifiedbootstate")
else:
    out("PASS", "hardening.mk does not PRODUCT-force verifiedbootstate")

if "isVerifiedBootGreen" in usb:
    out("FAIL", "isVerifiedBootGreen still in UsbPortSecurityHooks.java")
else:
    out("PASS", "isVerifiedBootGreen identifier ABSENT")

yg_body = re.search(
    r"private static boolean isVerifiedBootYellowOrGreen\(String state\) \{\s*"
    r'return "yellow"\.equals\(state\) \|\| "green"\.equals\(state\);\s*'
    r"\}",
    usb,
)
if yg_body:
    out("PASS", "isVerifiedBootYellowOrGreen body is yellow||green only")
else:
    out("FAIL", "could not confirm isVerifiedBootYellowOrGreen exact body")

flag_def = 'SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0")' in usb
maybe = "maybeTriggerUsbDuressWipe" in usb and "isVerifiedBootYellowOrGreen(vbootState)" in usb
if flag_def and maybe:
    out("PASS", "USB Java default 0 and gated on isVerifiedBootYellowOrGreen")
else:
    out("FAIL", f"USB gate drifted flag={flag_def} yellow_or_green={maybe}")

if re.search(r'USB_DURESS_WIPE_ENABLED_PROP,\s*"1"', usb):
    out("FAIL", "NEGATIVE HIT: USB duress Java default flipped to \"1\"")
else:
    out("PASS", "USB duress Java default is not \"1\"")

if "vendor.guardtalk.usb_duress_wipe.enabled=1" in harden:
    out("PASS", "komodo user product may set usb_duress_wipe.enabled=1 (DEC-002; not a FAIL)")
else:
    out("HOLD", "hardening.mk does not set usb_duress_wipe.enabled=1 (Java default 0 valid)")

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
TYPE="$(gbv TARGET_BUILD_TYPE | tail -n 1 | tr -d '[:space:]')"
PRODUCT="$(gbv TARGET_PRODUCT | tail -n 1 | tr -d '[:space:]')"
CERT="$(gbv PRODUCT_DEFAULT_DEV_CERTIFICATE | tail -n 1 | tr -d '[:space:]')"
KEYS="$(gbv BUILD_KEYS | tail -n 1 | tr -d '[:space:]')"
AVB_EN="$(gbv BOARD_AVB_ENABLE | tail -n 1 | tr -d '[:space:]')"
AVB_PATH="$(gbv BOARD_AVB_KEY_PATH | tail -n 1 | tr -d '[:space:]')"
AVB_ALG="$(gbv BOARD_AVB_ALGORITHM | tail -n 1 | tr -d '[:space:]')"
PKGS="$(gbv PRODUCT_PACKAGES || true)"
PKGS_DBG="$(gbv PRODUCT_PACKAGES_DEBUG || true)"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"
echo "TARGET_BUILD_TYPE=${TYPE}"
echo "PRODUCT_DEFAULT_DEV_CERTIFICATE=${CERT}"
echo "BUILD_KEYS=${KEYS}"
echo "BOARD_AVB_ENABLE=${AVB_EN}"
echo "BOARD_AVB_KEY_PATH=${AVB_PATH}"
echo "BOARD_AVB_ALGORITHM=${AVB_ALG}"

if [[ "$PRODUCT" == "komodo" ]]; then
  pass "TARGET_PRODUCT=komodo"
else
  fail "TARGET_PRODUCT=${PRODUCT} (expected komodo)"
fi
if [[ "$VARIANT" == "user" ]]; then
  pass "TARGET_BUILD_VARIANT=user (USERBUILD not regressed to userdebug)"
else
  fail "TARGET_BUILD_VARIANT=${VARIANT} (expected user)"
fi
if [[ "$TYPE" == "release" ]]; then
  pass "TARGET_BUILD_TYPE=release"
else
  fail "TARGET_BUILD_TYPE=${TYPE} (expected release)"
fi
if [[ "$CERT" == "$CERT_STEM" ]]; then
  pass "USERBUILD cert stem still releasekey"
elif [[ "$CERT" == *testkey* ]]; then
  fail "NEGATIVE HIT: USERBUILD cert stem regressed to testkey (${CERT})"
else
  fail "PRODUCT_DEFAULT_DEV_CERTIFICATE=${CERT} (expected ${CERT_STEM})"
fi

if [[ "$AVB_EN" == "true" ]]; then
  pass "BOARD_AVB_ENABLE=true"
else
  fail "BOARD_AVB_ENABLE=${AVB_EN} (expected true)"
fi

if [[ "$AVB_PATH" == "$PROJECT_AVB" ]]; then
  pass "user BOARD_AVB_KEY_PATH is project avb.pem (not AOSP testkey)"
elif [[ "$AVB_PATH" == *testkey* || "$AVB_PATH" == "$AOSP_TESTKEY" ]]; then
  fail "NEGATIVE HIT: user BOARD_AVB_KEY_PATH is AOSP testkey (${AVB_PATH})"
elif [[ -z "$AVB_PATH" ]]; then
  fail "user BOARD_AVB_KEY_PATH empty (would fall back to AOSP testkey at m)"
else
  fail "user BOARD_AVB_KEY_PATH=${AVB_PATH} (expected ${PROJECT_AVB})"
fi

if [[ "$AVB_ALG" == "SHA256_RSA4096" ]]; then
  pass "user BOARD_AVB_ALGORITHM=SHA256_RSA4096"
else
  fail "user BOARD_AVB_ALGORITHM=${AVB_ALG} (expected SHA256_RSA4096)"
fi

case "$KEYS" in
  release-keys)
    pass "BUILD_KEYS=release-keys (post-sign already landed)"
    ;;
  dev-keys)
    hold "BUILD_KEYS=dev-keys until operator post-sign (not FAIL; unsigned lunch honest)"
    ;;
  test-keys)
    fail "NEGATIVE HIT: BUILD_KEYS=test-keys as product"
    ;;
  *)
    fail "BUILD_KEYS=${KEYS} unexpected"
    ;;
esac

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
  hold "userdebug sidecar lunch failed rc=$UD_RC (not product FAIL)"
else
  UD_VAR="$(gbv TARGET_BUILD_VARIANT | tail -n 1 | tr -d '[:space:]')"
  UD_PATH="$(gbv BOARD_AVB_KEY_PATH | tail -n 1 | tr -d '[:space:]')"
  UD_KEYS="$(gbv BUILD_KEYS | tail -n 1 | tr -d '[:space:]')"
  echo "userdebug TARGET_BUILD_VARIANT=${UD_VAR}"
  echo "userdebug BOARD_AVB_KEY_PATH=${UD_PATH}"
  echo "userdebug BUILD_KEYS=${UD_KEYS}"
  if [[ "$UD_VAR" == "userdebug" ]]; then
    pass "sidecar lunch is userdebug (not product truth)"
  else
    fail "sidecar lunch variant ${UD_VAR} (expected userdebug)"
  fi
  if [[ "$UD_PATH" == "$PROJECT_AVB" ]]; then
    fail "NEGATIVE HIT: sidecar inherited project AVB path (user-gate failed)"
  elif [[ -z "$UD_PATH" ]]; then
    pass "sidecar BOARD_AVB_KEY_PATH empty dumpvar (Makefile testkey fallback at m; do not lock)"
  elif [[ "$UD_PATH" == *testkey* || "$UD_PATH" == "$AOSP_TESTKEY" ]]; then
    pass "sidecar BOARD_AVB_KEY_PATH is AOSP testkey fallback (not product; do not lock)"
  else
    hold "sidecar BOARD_AVB_KEY_PATH=${UD_PATH} (document only; product is user+project pem path)"
  fi
  if [[ "$UD_KEYS" == "test-keys" ]]; then
    pass "sidecar BUILD_KEYS=test-keys (not product truth)"
  else
    hold "sidecar BUILD_KEYS=${UD_KEYS} (document only)"
  fi
fi

echo
echo "--- signed vbmeta / lock / adb (HOLD; do not execute lock) ---"
hold "m not run this QA stamp — signed vbmeta / avb_pkmd.bin HOLD (avb.pem ABSENT)"
hold "fastboot flashing lock NOT executed (no USB GO; do not lock ${SERIAL})"
hold "verifiedbootstate green NOT claimed (Pixel custom-key truth is yellow)"

ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q "${SERIAL}[[:space:]]"; then
  hold "adb sees ${SERIAL} — this card is host-only; do not lock; do not start Q-ONDEVICE; not device-fixed"
else
  hold "adb devices empty / no komodo ${SERIAL} — device HOLD, never device-fixed, never lock"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "GREEN=HOLD"
echo "KEYS_SIGN_LOCK=HOLD"
echo "ITEM7_USB_SOT=DEC-002 (yellow||green; user default-on allowed; Java default 0)"
echo "DEVICE=HOLD"
echo "BUILD_KEYS_POSTSIGN=HOLD"
echo "FLASH_READY=false"
exit "$FAIL"
