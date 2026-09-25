#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-TELEMETRY (pair of
# T-REMEDIATE-B2-TELEMETRY items 11, 14). Do not trust Backend/Architect
# lunch dumps. Do not treat stale out/target/product/komodo/vendor/build.prop
# as product truth (HOLD until rebuild). On-device EXIF / /data log dirs HOLD.
# Host static + user lunch. No product edits. No USB GO. No wipe. No commit.
# Do not start Q-ONDEVICE / Block 3 / USB GO / item 7.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_telemetry_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

VENDOR_PROP="vendor/google_devices/komodo/sysprop/vendor.prop"
TELE_MK="vendor/guardtalk/device/komodo/guardtalk-telemetry.mk"
TELE_RC="vendor/guardtalk/device/komodo/init.guardtalk.telemetry.rc"
HARDEN_MK="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
RADIO_MK="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
HARDEN_RC="vendor/guardtalk/init/init.guardtalk.hardening.rc"
APPS_EXCISE="vendor/guardtalk/feature-excised/apps-excised.mk"
REGEN="vendor/guardtalk/device/komodo/REGEN_HOOKS.md"
STALE_PROP="out/target/product/komodo/vendor/build.prop"

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

echo "=== Q-REMEDIATE-B2-TELEMETRY independent rematch (items 11,14) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "Q-EXCISE=not started"
echo "Q-KERNEL=not started"
echo "USB_GO=not started"
echo "STALE_OUT_VENDOR_BUILD_PROP=HOLD (not SoT)"
echo

echo "--- required files ---"
require_file "$VENDOR_PROP"
require_file "$TELE_MK"
require_file "$TELE_RC"
require_file "$HARDEN_MK"
require_file "$RADIO_MK"
require_file "$REGEN"

echo
echo "--- packet rg (exif / silentlog / modem / ril mask) ---"
rg -n 'exif_reveal_make_model' "$VENDOR_PROP" vendor/guardtalk/device/komodo/ || true
echo
rg -n 'silentlog.tcp' "$VENDOR_PROP" || true
rg -n 'modem.logging.enable' "$VENDOR_PROP" || true
rg -n 'ril.log_mask' "$VENDOR_PROP" || true

echo
echo "--- vendor.prop defaults (source of record; not stale out/) ---"
require_fixed "persist.vendor.camera.exif_reveal_make_model=false" "$VENDOR_PROP" \
  "vendor.prop EXIF make/model false"
forbid_re '^persist\.vendor\.camera\.exif_reveal_make_model=true$' "$VENDOR_PROP" \
  "vendor.prop EXIF make/model is not true"
require_fixed "persist.vendor.sys.silentlog.tcp=Off" "$VENDOR_PROP" \
  "vendor.prop silentlog.tcp=Off"
forbid_re '^persist\.vendor\.sys\.silentlog\.tcp=On$' "$VENDOR_PROP" \
  "vendor.prop silentlog.tcp is not On"
require_fixed "persist.vendor.sys.modem.logging.enable=false" "$VENDOR_PROP" \
  "vendor.prop modem.logging.enable=false"
forbid_re '^persist\.vendor\.sys\.modem\.logging\.enable=true$' "$VENDOR_PROP" \
  "vendor.prop modem.logging.enable is not true"
require_fixed "persist.vendor.ril.log_mask=0" "$VENDOR_PROP" \
  "vendor.prop ril.log_mask=0"
forbid_re '^persist\.vendor\.ril\.log_mask=[1-9]' "$VENDOR_PROP" \
  "vendor.prop ril.log_mask is not a nonzero Pixel mask"

echo
echo "--- overlay mk + vendor init re-assert ---"
require_fixed "include vendor/guardtalk/device/komodo/guardtalk-telemetry.mk" \
  "$HARDEN_MK" "production-hardening.mk includes guardtalk-telemetry.mk"
require_fixed "init.guardtalk.telemetry.rc:\$(TARGET_COPY_OUT_VENDOR)/etc/init/init.guardtalk.telemetry.rc" \
  "$TELE_MK" "telemetry.mk copies init.guardtalk.telemetry.rc to vendor/etc/init"
require_fixed "logd.logpersistd.enable=false" "$TELE_MK" \
  "telemetry.mk PRODUCT_PROPERTY_OVERRIDES logd.logpersistd.enable=false"
require_fixed 'ifeq ($(TARGET_BUILD_VARIANT),user)' "$TELE_MK" \
  "telemetry.mk user-gates logpersist.start/logcatd drop"
require_fixed '$(filter-out logpersist.start logcatd,$(PRODUCT_PACKAGES))' "$TELE_MK" \
  "telemetry.mk filter-out logpersist.start logcatd on user"
forbid_re 'PRODUCT_PACKAGES[[:space:]]*\+=' "$TELE_MK" \
  "telemetry.mk does not add packages"

# Duplicate sysprop assignments of vendor.prop keys break post_process_props.py.
forbid_re 'persist\.vendor\.camera\.exif_reveal_make_model=' "$TELE_MK" \
  "telemetry.mk does not PRODUCT_PROPERTY_OVERRIDES EXIF vendor.prop key"
forbid_re 'persist\.vendor\.sys\.silentlog\.tcp=' "$TELE_MK" \
  "telemetry.mk does not PRODUCT_PROPERTY_OVERRIDES silentlog vendor.prop key"
forbid_re 'persist\.vendor\.sys\.modem\.logging\.enable=' "$TELE_MK" \
  "telemetry.mk does not PRODUCT_PROPERTY_OVERRIDES modem.logging vendor.prop key"
forbid_re 'persist\.vendor\.ril\.log_mask=' "$TELE_MK" \
  "telemetry.mk does not PRODUCT_PROPERTY_OVERRIDES ril.log_mask vendor.prop key"

require_fixed "setprop persist.vendor.camera.exif_reveal_make_model false" "$TELE_RC" \
  "telemetry.rc re-asserts EXIF false"
require_fixed "setprop persist.vendor.sys.silentlog.tcp Off" "$TELE_RC" \
  "telemetry.rc re-asserts silentlog Off"
require_fixed "setprop persist.vendor.sys.modem.logging.enable false" "$TELE_RC" \
  "telemetry.rc re-asserts modem.logging false"
require_fixed "setprop persist.vendor.ril.log_mask 0" "$TELE_RC" \
  "telemetry.rc re-asserts ril.log_mask 0"
require_fixed "setprop logd.logpersistd.enable false" "$TELE_RC" \
  "telemetry.rc re-asserts logd.logpersistd.enable false"
require_fixed 'setprop persist.logd.logpersistd ""' "$TELE_RC" \
  "telemetry.rc clears persist.logd.logpersistd"
if rg -q '^on post-fs-data$' "$TELE_RC"; then
  pass "telemetry.rc trigger is on post-fs-data"
else
  fail "telemetry.rc missing on post-fs-data"
fi

echo
echo "--- RIL stays disabled (must not re-enable) ---"
require_fixed "persist.radio.disabled=1" "$RADIO_MK" \
  "radio-excised still sets persist.radio.disabled=1"
# Live product assignments only (mk/rc/prop/bp). Do not scan docs/qa — the
# suite itself mentions persist.radio.disabled=0 as a forbidden pattern.
RIL_ZERO="$(rg -l 'persist\.radio\.disabled=0' vendor/guardtalk \
  --glob '*.mk' --glob '*.rc' --glob '*.prop' --glob '*.bp' 2>/dev/null || true)"
if [[ -n "${RIL_ZERO}" ]]; then
  fail "NEGATIVE HIT: persist.radio.disabled=0 in product files: ${RIL_ZERO}"
else
  pass "no persist.radio.disabled=0 in vendor/guardtalk mk/rc/prop/bp"
fi

echo
echo "--- KERNEL rc / apps-excised not this card ---"
if [[ -f "$HARDEN_RC" ]] && rg -q 'exif_reveal_make_model|silentlog|logpersist|logcatd' "$HARDEN_RC"; then
  fail "init.guardtalk.hardening.rc contains telemetry edits (forbidden bleed)"
else
  pass "init.guardtalk.hardening.rc has no telemetry bleed"
fi
if [[ -f "$APPS_EXCISE" ]] && rg -q 'exif_reveal_make_model|silentlog.tcp|logpersist.start' "$APPS_EXCISE"; then
  fail "apps-excised.mk contains telemetry edits (forbidden bleed)"
else
  pass "apps-excised.mk has no telemetry bleed"
fi

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

def assignments(src):
    props = {}
    for line in src.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if "=" in s:
            k, v = s.split("=", 1)
            props[k.strip()] = v.strip()
    return props

vendor = read("vendor/google_devices/komodo/sysprop/vendor.prop")
tele_mk = read("vendor/guardtalk/device/komodo/guardtalk-telemetry.mk")
tele_rc = read("vendor/guardtalk/device/komodo/init.guardtalk.telemetry.rc")
harden = read("vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk")
radio = read("vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk")

vp = assignments(vendor)
expected = {
    "persist.vendor.camera.exif_reveal_make_model": "false",
    "persist.vendor.sys.silentlog.tcp": "Off",
    "persist.vendor.sys.modem.logging.enable": "false",
    "persist.vendor.ril.log_mask": "0",
}
for k, v in expected.items():
    if vp.get(k) == v:
        out("PASS", f"vendor.prop exact {k}={v}")
    else:
        out("FAIL", f"vendor.prop {k}={vp.get(k)!r} (expected {v})")

pixel_bad = {
    "persist.vendor.camera.exif_reveal_make_model": "true",
    "persist.vendor.sys.silentlog.tcp": "On",
    "persist.vendor.sys.modem.logging.enable": "true",
}
for k, bad in pixel_bad.items():
    if vp.get(k) == bad:
        out("FAIL", f"NEGATIVE HIT: vendor.prop still Pixel default {k}={bad}")
    else:
        out("PASS", f"vendor.prop {k} is not Pixel default {bad}")
mask = vp.get("persist.vendor.ril.log_mask")
if mask == "0":
    out("PASS", "vendor.prop ril.log_mask is 0 (not Pixel 3)")
elif mask in {"3", "7", "15"}:
    out("FAIL", f"NEGATIVE HIT: vendor.prop ril.log_mask={mask} (Pixel-style mask)")
else:
    out("FAIL", f"vendor.prop ril.log_mask={mask!r} unexpected")

if "include vendor/guardtalk/device/komodo/guardtalk-telemetry.mk" in harden:
    out("PASS", "harden mk includes telemetry overlay")
else:
    out("FAIL", "harden mk missing telemetry overlay include")

user_m = re.search(r"ifeq\s+\(\$\(TARGET_BUILD_VARIANT\),user\)", tele_mk)
if user_m is None:
    out("FAIL", "telemetry.mk has no TARGET_BUILD_VARIANT=user gate")
else:
    block = tele_mk[user_m.start():]
    if "filter-out logpersist.start logcatd" in block:
        out("PASS", "user block filter-out logpersist.start logcatd")
    else:
        out("FAIL", "user block missing logpersist.start/logcatd filter-out")
    if re.search(r"PRODUCT_PACKAGES\s*\+=", block):
        out("FAIL", "user block adds PRODUCT_PACKAGES")
    else:
        out("PASS", "user block is filter-out only")

# PRODUCT_PROPERTY_OVERRIDES of vendor.prop keys is a duplicate-sysprop FAIL.
mk_code = []
for line in tele_mk.splitlines():
    s = line.split("#", 1)[0]
    mk_code.append(s)
mk_join = "\n".join(mk_code)
dup_keys = [
    "persist.vendor.camera.exif_reveal_make_model",
    "persist.vendor.sys.silentlog.tcp",
    "persist.vendor.sys.modem.logging.enable",
    "persist.vendor.ril.log_mask",
]
for k in dup_keys:
    if re.search(rf"{re.escape(k)}\s*=", mk_join):
        out("FAIL", f"telemetry.mk PRODUCT-overrides vendor.prop key {k}")
    else:
        out("PASS", f"telemetry.mk does not duplicate vendor.prop key {k}")

if re.search(r"logd\.logpersistd\.enable\s*=\s*false", mk_join):
    out("PASS", "telemetry.mk sets logd.logpersistd.enable=false")
else:
    out("FAIL", "telemetry.mk missing logd.logpersistd.enable=false")

if "on post-fs-data" in tele_rc:
    out("PASS", "telemetry.rc has post-fs-data")
else:
    out("FAIL", "telemetry.rc missing post-fs-data")
rc_expect = [
    "setprop persist.vendor.camera.exif_reveal_make_model false",
    "setprop persist.vendor.sys.silentlog.tcp Off",
    "setprop persist.vendor.sys.modem.logging.enable false",
    "setprop persist.vendor.ril.log_mask 0",
    "setprop logd.logpersistd.enable false",
]
for stmt in rc_expect:
    if stmt in tele_rc:
        out("PASS", f"telemetry.rc has {stmt}")
    else:
        out("FAIL", f"telemetry.rc missing {stmt}")
if 'setprop persist.radio.disabled' in tele_rc:
    out("FAIL", "telemetry.rc writes persist.radio.disabled (must not re-enable RIL)")
else:
    out("PASS", "telemetry.rc does not touch persist.radio.disabled")

if "persist.radio.disabled=1" in radio:
    out("PASS", "radio-excised persist.radio.disabled=1 remains")
else:
    out("FAIL", "radio-excised missing persist.radio.disabled=1")
if re.search(r"persist\.radio\.disabled\s*=\s*0", radio):
    out("FAIL", "NEGATIVE HIT: persist.radio.disabled=0 in radio-excised")
else:
    out("PASS", "radio-excised does not set persist.radio.disabled=0")

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
PRODUCT="$(gbv TARGET_PRODUCT | tail -n 1 | tr -d '[:space:]')"
PROPS="$(gbv PRODUCT_PROPERTY_OVERRIDES || true)"
PKGS="$(gbv PRODUCT_PACKAGES || true)"
COPY="$(gbv PRODUCT_COPY_FILES || true)"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"

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

LOG_PKGS="$(printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -Ex 'logpersist\.start|logcatd' || true)"
if [[ -z "$LOG_PKGS" ]]; then
  pass "user PRODUCT_PACKAGES: logpersist.start and logcatd ABSENT"
else
  fail "user PRODUCT_PACKAGES still has: ${LOG_PKGS}"
fi

PROP_LINES="$(printf '%s\n' "$PROPS" | tr ' ' '\n')"
if echo "$PROP_LINES" | grep -Fxq "logd.logpersistd.enable=false"; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains logd.logpersistd.enable=false"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing logd.logpersistd.enable=false"
fi
if echo "$PROP_LINES" | grep -Eq '^logd\.logpersistd\.enable=true$'; then
  fail "NEGATIVE HIT: logd.logpersistd.enable=true as product override"
else
  pass "PRODUCT_PROPERTY_OVERRIDES does not set logd.logpersistd.enable=true"
fi
if echo "$PROP_LINES" | grep -Fxq "persist.radio.disabled=1"; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains persist.radio.disabled=1 (RIL stays disabled)"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing persist.radio.disabled=1"
fi
if echo "$PROP_LINES" | grep -Eq '^persist\.radio\.disabled=0$'; then
  fail "NEGATIVE HIT: persist.radio.disabled=0 (RIL re-enabled)"
else
  pass "PRODUCT_PROPERTY_OVERRIDES does not set persist.radio.disabled=0"
fi

if echo "$COPY" | grep -q 'init.guardtalk.telemetry.rc'; then
  pass "PRODUCT_COPY_FILES includes init.guardtalk.telemetry.rc"
else
  fail "PRODUCT_COPY_FILES missing init.guardtalk.telemetry.rc"
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
  UD_PKGS="$(gbv PRODUCT_PACKAGES || true)"
  echo "userdebug TARGET_BUILD_VARIANT=${UD_VAR}"
  if [[ "$UD_VAR" == "userdebug" ]]; then
    pass "sidecar lunch is userdebug (not product truth)"
  else
    fail "sidecar lunch variant ${UD_VAR} (expected userdebug)"
  fi
  UD_HIT="$(printf '%s\n' "$UD_PKGS" | tr ' ' '\n' | grep -Ex 'logpersist\.start|logcatd' || true)"
  if [[ -n "$UD_HIT" ]]; then
    pass "sidecar PRODUCT_PACKAGES still has logpersist.start/logcatd (userdebug leftover is NOT product)"
  else
    hold "sidecar PRODUCT_PACKAGES missing logpersist.start/logcatd (unexpected; not product FAIL)"
  fi
fi

echo
echo "--- stale out/vendor/build.prop (HOLD until rebuild; not PASS/FAIL of this card) ---"
if [[ -f "$STALE_PROP" ]]; then
  echo "--- stale vendor.prop telemetry keys ---"
  rg -n 'exif_reveal_make_model|silentlog.tcp|modem.logging.enable|ril.log_mask' "$STALE_PROP" || true
  if rg -q 'persist.vendor.camera.exif_reveal_make_model=true|persist.vendor.sys.silentlog.tcp=On|persist.vendor.sys.modem.logging.enable=true|persist.vendor.ril.log_mask=3' "$STALE_PROP"; then
    hold "stale out/vendor/build.prop still Pixel true/On/log_mask=3 — HOLD until rebuild (not FAIL)"
  else
    hold "stale out/vendor/build.prop present but not Pixel-true; still not product truth (HOLD until rebuild)"
  fi
else
  hold "stale out/vendor/build.prop absent — still not a proven rebuilt user image (m not run by QA)"
fi
hold "m not run this QA stamp (stale vendor/build.prop not product truth; never device-fixed)"

echo
echo "--- adb / on-device EXIF / /data log dirs ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; do not start Q-ONDEVICE; EXIF /data HOLD; not device-fixed"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — device HOLD, EXIF HOLD, /data log dirs HOLD, never device-fixed"
fi
hold "on-device photo EXIF HOLD (Q-REMEDIATE-B2-ONDEVICE BLOCKED)"
hold "runtime /data vendor log dirs HOLD (slog / sit-ril / logpersist not proven empty live)"

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "STALE_OUT_VENDOR_BUILD_PROP=HOLD"
echo "ONDEVICE_EXIF=HOLD"
echo "DATA_LOG_DIRS=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
exit "$FAIL"
