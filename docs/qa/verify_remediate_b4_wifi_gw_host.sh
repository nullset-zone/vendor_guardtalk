#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B4-WIFI-GW (pair of
# T-REMEDIATE-B4-WIFI-GW item 21). Do not trust Backend/Architect lunch dumps.
# Host static + user lunch. No product edits. No USB GO. No wipe. No commit.
# Do not open Wi-Fi. Do not re-enable RIL/BT/NFC. Do not lift PASS HOLD.
# Do not claim live / device-fixed.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b4_wifi_gw_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

WIFI_MK="vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk"
WIFI_RC="vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc"
WPA_GT="vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf"
SSID_FILE="vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids"
WPA_PIXEL="vendor/google_devices/komodo/proprietary/vendor/etc/wifi/wpa_supplicant_overlay.conf"
FW_OVL="vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay/res/values/config.xml"
SET_OVL="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
HARDEN_MK="vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk"
RADIO_MK="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
REGEN="vendor/guardtalk/device/komodo/REGEN_HOOKS.md"
STALE_WPA="out/target/product/komodo/vendor/etc/wifi/wpa_supplicant_overlay.conf"
STALE_SSID="out/target/product/komodo/vendor/etc/wifi/guardtalk_gateway_ssids"
STALE_RC="out/target/product/komodo/vendor/etc/init/init.guardtalk.wifi-gateway.rc"

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

echo "=== Q-REMEDIATE-B4-WIFI-GW independent rematch (item 21) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "OPEN_WIFI=forbidden"
echo "STALE_OUT_WPA=HOLD (not SoT)"
echo

echo "--- required files ---"
require_file "$WIFI_MK"
require_file "$WIFI_RC"
require_file "$WPA_GT"
require_file "$SSID_FILE"
require_file "$WPA_PIXEL"
require_file "$FW_OVL"
require_file "$SET_OVL"
require_file "$HARDEN_MK"
require_file "$RADIO_MK"
require_file "$REGEN"

echo
echo "--- packet rg (first-user / wpa / SSID file) ---"
rg -n 'no_add_wifi_config|no_wifi_tethering|no_wifi_direct|no_config_wifi' "$FW_OVL" || true
echo
rg -n 'filter_ssids|hs20|interworking' "$WPA_GT" || true
echo
rg -n 'guardtalk-wifi-gateway|wpa_supplicant_overlay|guardtalk_gateway_ssids' "$WIFI_MK" "$HARDEN_MK" || true

echo
echo "--- first-user overlay (GuardTalkFrameworksBaseOverlay) ---"
require_rg '<item>no_add_wifi_config</item>' "$FW_OVL" \
  "first-user restriction no_add_wifi_config"
require_rg '<item>no_wifi_tethering</item>' "$FW_OVL" \
  "first-user restriction no_wifi_tethering"
require_rg '<item>no_wifi_direct</item>' "$FW_OVL" \
  "first-user restriction no_wifi_direct"
require_rg 'config_defaultFirstUserRestrictions' "$FW_OVL" \
  "config_defaultFirstUserRestrictions present"
forbid_rg '<item>no_config_wifi_private</item>' "$FW_OVL" \
  "first-user does not set no_config_wifi_private (GMP add path)"
forbid_rg '<item>no_config_wifi_shared</item>' "$FW_OVL" \
  "first-user does not set no_config_wifi_shared (GMP add path)"

echo
echo "--- Settings overlay (do not open Wi-Fi / hotspot) ---"
require_rg '<bool name="config_show_wifi_settings">true</bool>' "$SET_OVL" \
  "Wi-Fi settings stay shown (gateway path visible)"
require_rg '<bool name="config_show_wifi_hotspot_settings">false</bool>' "$SET_OVL" \
  "hotspot settings stay hidden"
forbid_rg '<bool name="config_show_wifi_hotspot_settings">true</bool>' "$SET_OVL" \
  "hotspot not re-opened"

echo
echo "--- GuardTalk wpa overlay ---"
require_rg '^filter_ssids=1$' "$WPA_GT" "wpa overlay filter_ssids=1"
require_rg '^hs20=0$' "$WPA_GT" "wpa overlay hs20=0"
require_rg '^interworking=0$' "$WPA_GT" "wpa overlay interworking=0"
forbid_rg '^hs20=1$' "$WPA_GT" "GuardTalk wpa overlay is not Pixel hs20=1"
forbid_rg '^interworking=1$' "$WPA_GT" "GuardTalk wpa overlay is not Pixel interworking=1"
forbid_rg '^filter_ssids=0$' "$WPA_GT" "filter_ssids is not 0"

echo
echo "--- Pixel wpa overlay (source; must be filtered at lunch) ---"
require_rg '^hs20=1$' "$WPA_PIXEL" "Pixel source still hs20=1 (must not ship)"
require_rg '^interworking=1$' "$WPA_PIXEL" "Pixel source still interworking=1 (must not ship)"
if rg -q '^filter_ssids=' "$WPA_PIXEL"; then
  fail "Pixel source unexpectedly has filter_ssids (regen assumption changed)"
else
  pass "Pixel source has no filter_ssids (late overlay must add it)"
fi

echo
echo "--- SSID allowlist file (comments only, zero SSIDs) ---"
SSID_LIVE="$(awk 'BEGIN{n=0} {s=$0; sub(/^[ \t]+/,"",s); if(s=="" || s ~ /^#/) next; n++; print s} END{printf("SSID_NONCOMMENT_COUNT=%d\n", n)}' "$SSID_FILE")"
echo "$SSID_LIVE"
SSID_N="$(echo "$SSID_LIVE" | awk -F= '/SSID_NONCOMMENT_COUNT/{print $2}')"
if [[ "${SSID_N}" == "0" ]]; then
  pass "guardtalk_gateway_ssids has zero non-comment SSID lines"
else
  fail "guardtalk_gateway_ssids has ${SSID_N} non-comment SSID line(s)"
fi
if rg -i -- 'psk=|wpa_passphrase|wifi_password|pre.?shared' "$SSID_FILE" \
    vendor/guardtalk/device/komodo/wifi/ >/dev/null; then
  fail "NEGATIVE HIT: PSK/passphrase in komodo wifi dir"
else
  pass "komodo wifi dir has no PSK/passphrase"
fi

echo
echo "--- wifi-gateway.mk + harden include ---"
require_rg 'include vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk' \
  "$HARDEN_MK" "production-hardening.mk includes guardtalk-wifi-gateway.mk"
require_rg 'filter-out' "$WIFI_MK" "wifi-gateway.mk filter-out Pixel wpa overlay"
require_rg 'vendor/google_devices/komodo/proprietary/vendor/etc/wifi/wpa_supplicant_overlay.conf' \
  "$WIFI_MK" "wifi-gateway.mk names Pixel overlay dest to drop"
require_rg 'vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf' \
  "$WIFI_MK" "wifi-gateway.mk copies GuardTalk wpa overlay"
require_rg 'vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids' \
  "$WIFI_MK" "wifi-gateway.mk copies SSID list"
require_rg 'init.guardtalk.wifi-gateway.rc' "$WIFI_MK" \
  "wifi-gateway.mk copies vendor init rc"
require_rg 'ro.guardtalk.wifi.gateway_only=1' "$WIFI_MK" \
  "wifi-gateway.mk sets gateway_only=1"
require_rg 'ro.guardtalk.wifi.fail_closed=1' "$WIFI_MK" \
  "wifi-gateway.mk sets fail_closed=1"
forbid_rg 'PRODUCT_PACKAGES[[:space:]]*\+=' "$WIFI_MK" \
  "wifi-gateway.mk does not add PRODUCT_PACKAGES"
if grep -vE '^\s*#' "$WIFI_MK" | grep -iE 'ril-daemon|libril|Bluetooth|NfcNci|android.hardware.nfc|android.hardware.bluetooth' >/dev/null; then
  fail "NEGATIVE HIT: wifi-gateway.mk non-comment restores RIL/BT/NFC"
else
  pass "wifi-gateway.mk does not restore RIL/BT/NFC"
fi

echo
echo "--- vendor init (wifi-gateway.rc) ---"
require_rg 'setprop persist.vendor.wifi.guardtalk_gateway_only 1' "$WIFI_RC" \
  "wifi-gateway.rc re-asserts persist.vendor.wifi.guardtalk_gateway_only 1"
require_rg '^on post-fs-data$' "$WIFI_RC" "wifi-gateway.rc has on post-fs-data"
forbid_rg 'persist.radio.disabled' "$WIFI_RC" \
  "wifi-gateway.rc does not touch persist.radio.disabled"
forbid_rg 'start[[:space:]]+ril' "$WIFI_RC" "wifi-gateway.rc does not start RIL"
forbid_rg 'ctl.start' "$WIFI_RC" "wifi-gateway.rc does not ctl.start services"

echo
echo "--- RIL stays disabled (must not re-enable) ---"
require_rg 'persist.radio.disabled=1' "$RADIO_MK" \
  "radio-excised still sets persist.radio.disabled=1"
RIL_ZERO="$(rg -l 'persist\.radio\.disabled=0' vendor/guardtalk \
  --glob '*.mk' --glob '*.rc' --glob '*.prop' --glob '*.bp' 2>/dev/null || true)"
if [[ -n "${RIL_ZERO}" ]]; then
  fail "NEGATIVE HIT: persist.radio.disabled=0 in product files: ${RIL_ZERO}"
else
  pass "no persist.radio.disabled=0 in vendor/guardtalk mk/rc/prop/bp"
fi

echo
echo "--- REGEN_HOOKS documents late Pixel filter-out ---"
require_rg 'guardtalk-wifi-gateway.mk' "$REGEN" \
  "REGEN_HOOKS names guardtalk-wifi-gateway.mk"
require_rg 'filter-out' "$REGEN" "REGEN_HOOKS documents Pixel wpa filter-out"

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

fw = read("vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay/res/values/config.xml")
items = re.findall(
    r"<string-array[^>]*name=\"config_defaultFirstUserRestrictions\"[^>]*>(.*?)</string-array>",
    fw,
    flags=re.S,
)
if not items:
    out("FAIL", "config_defaultFirstUserRestrictions missing")
    first = []
else:
    first = re.findall(r"<item>([^<]+)</item>", items[0])
    out("PASS", f"first-user restrictions parsed: {first}")

for need in ("no_add_wifi_config", "no_wifi_tethering", "no_wifi_direct", "no_install_unknown_sources"):
    if need in first:
        out("PASS", f"first-user has {need}")
    else:
        out("FAIL", f"first-user missing {need}")
for forbid in ("no_config_wifi_private", "no_config_wifi_shared", "no_config_wifi"):
    if forbid in first:
        out("FAIL", f"first-user unexpectedly sets {forbid} (blocks privileged GMP add)")
    else:
        out("PASS", f"first-user does not set {forbid}")

wpa = assignments(read("vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf"))
if wpa.get("filter_ssids") == "1":
    out("PASS", "wpa overlay exact filter_ssids=1")
else:
    out("FAIL", f"wpa overlay filter_ssids={wpa.get('filter_ssids')!r}")
if wpa.get("hs20") == "0":
    out("PASS", "wpa overlay exact hs20=0")
else:
    out("FAIL", f"wpa overlay hs20={wpa.get('hs20')!r} (expected 0)")
if wpa.get("interworking") == "0":
    out("PASS", "wpa overlay exact interworking=0")
else:
    out("FAIL", f"wpa overlay interworking={wpa.get('interworking')!r} (expected 0)")

pixel = assignments(read("vendor/google_devices/komodo/proprietary/vendor/etc/wifi/wpa_supplicant_overlay.conf"))
if pixel.get("hs20") == "1" and pixel.get("interworking") == "1":
    out("PASS", "Pixel overlay remains hs20=1/interworking=1 (must be filtered at lunch)")
else:
    out("FAIL", f"Pixel overlay unexpected hs20={pixel.get('hs20')!r} interworking={pixel.get('interworking')!r}")

ssid = read("vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids")
live = []
for line in ssid.splitlines():
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    live.append(s)
if live:
    out("FAIL", f"SSID file has non-comment lines: {live}")
else:
    out("PASS", "SSID file comments/blanks only (zero SSIDs)")
secret_re = re.compile(r"psk=|wpa_passphrase|wifi_password|pre.?shared", re.I)
if secret_re.search(ssid):
    out("FAIL", "SSID file contains secret-like token")
else:
    out("PASS", "SSID file has no secret-like token")

wifi_dir = root / "vendor/guardtalk/device/komodo/wifi"
for p in wifi_dir.iterdir() if wifi_dir.is_dir() else []:
    if not p.is_file():
        continue
    txt = p.read_text(encoding="utf-8", errors="replace")
    if secret_re.search(txt):
        out("FAIL", f"secret-like token in {p.name}")
    else:
        out("PASS", f"no secret-like token in {p.name}")

mk = read("vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk")
harden = read("vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk")
if "include vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk" in harden:
    out("PASS", "harden mk includes wifi-gateway overlay")
else:
    out("FAIL", "harden mk missing wifi-gateway include")
if "filter-out" in mk and "wpa_supplicant_overlay.conf" in mk:
    out("PASS", "wifi-gateway.mk filter-out Pixel wpa overlay")
else:
    out("FAIL", "wifi-gateway.mk missing Pixel wpa filter-out")
for needle in (
    "vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf",
    "vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids",
    "vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc",
):
    if needle in mk:
        out("PASS", f"mk copies {needle}")
    else:
        out("FAIL", f"mk missing copy of {needle}")

rc = read("vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc")
if "on post-fs-data" in rc and "setprop persist.vendor.wifi.guardtalk_gateway_only 1" in rc:
    out("PASS", "wifi-gateway.rc post-fs-data re-assert")
else:
    out("FAIL", "wifi-gateway.rc missing post-fs-data re-assert")
if re.search(r"persist\.radio\.disabled\s+0", rc) or "start ril" in rc:
    out("FAIL", "wifi-gateway.rc re-enables RIL")
else:
    out("PASS", "wifi-gateway.rc does not re-enable RIL")

radio = read("vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk")
if "persist.radio.disabled=1" in radio:
    out("PASS", "radio-excised persist.radio.disabled=1 remains")
else:
    out("FAIL", "radio-excised missing persist.radio.disabled=1")

# Vendor SSID file is copied + property-pointed, but no in-tree reader.
# filter_ssids uses the *saved* network set, not this file. Document HOLD.
readers = []
gt = root / "vendor/guardtalk"
for p in gt.rglob("*"):
    if not p.is_file():
        continue
    if p.suffix.lower() not in {".java", ".kt", ".c", ".cc", ".cpp", ".h"}:
        continue
    try:
        txt = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if "guardtalk_gateway_ssids" in txt or "ssid_allowlist_path" in txt:
        readers.append(str(p.relative_to(root)))
if readers:
    out("PASS", f"SSID file has runtime readers: {readers}")
else:
    out(
        "HOLD",
        "no in-tree Java/Kotlin/C reader of guardtalk_gateway_ssids / "
        "ssid_allowlist_path — vendor list is not a runtime firewall; "
        "wpa filter_ssids uses saved networks; empty saved set does not "
        "filter association until an SSID is saved",
    )

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
# Do not set -u around envsetup.
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

# pipefail + grep -q SIGPIPE is a false ABSENT when the token is early.
# Strip CR / nsjail chatter; match exact tokens only. Do not use grep -q.
gt_tokens() {
  printf '%s\n' "$1" | tr -d '\r' | tr ' \t' '\n' | grep -E '^[A-Za-z0-9._:=/@+-]+$' || true
}

PROP_TOKENS="$(gt_tokens "$PROPS")"
if printf '%s\n' "$PROP_TOKENS" | grep -Fx -- "persist.radio.disabled=1" >/dev/null; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains persist.radio.disabled=1 (RIL stays disabled)"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing persist.radio.disabled=1"
fi
if printf '%s\n' "$PROP_TOKENS" | grep -Ex -- 'persist\.radio\.disabled=0' >/dev/null; then
  fail "NEGATIVE HIT: persist.radio.disabled=0 (RIL re-enabled)"
else
  pass "PRODUCT_PROPERTY_OVERRIDES does not set persist.radio.disabled=0"
fi
if printf '%s\n' "$PROP_TOKENS" | grep -Fx -- "ro.guardtalk.wifi.gateway_only=1" >/dev/null; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains ro.guardtalk.wifi.gateway_only=1"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing ro.guardtalk.wifi.gateway_only=1"
fi
if printf '%s\n' "$PROP_TOKENS" | grep -Fx -- "ro.guardtalk.wifi.fail_closed=1" >/dev/null; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains ro.guardtalk.wifi.fail_closed=1"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing ro.guardtalk.wifi.fail_closed=1"
fi

COPY_TOKENS="$(gt_tokens "$COPY")"
echo "--- filtered PRODUCT_COPY_FILES wifi hits ---"
printf '%s\n' "$COPY_TOKENS" | grep -E 'wpa_supplicant_overlay|p2p_supplicant_overlay|guardtalk_gateway_ssids|wifi-gateway\.rc' || true

if printf '%s\n' "$COPY_TOKENS" | grep -F -- 'vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf:' >/dev/null; then
  pass "PRODUCT_COPY_FILES includes GuardTalk wpa_supplicant_overlay.conf"
else
  fail "PRODUCT_COPY_FILES missing GuardTalk wpa_supplicant_overlay.conf"
fi
if printf '%s\n' "$COPY_TOKENS" | grep -F -- 'vendor/google_devices/komodo/proprietary/vendor/etc/wifi/wpa_supplicant_overlay.conf:' >/dev/null; then
  fail "NEGATIVE HIT: Pixel wpa_supplicant_overlay.conf still in PRODUCT_COPY_FILES"
else
  pass "Pixel wpa_supplicant_overlay.conf ABSENT from PRODUCT_COPY_FILES"
fi
if printf '%s\n' "$COPY_TOKENS" | grep -F -- 'vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids:' >/dev/null; then
  pass "PRODUCT_COPY_FILES includes guardtalk_gateway_ssids"
else
  fail "PRODUCT_COPY_FILES missing guardtalk_gateway_ssids"
fi
if printf '%s\n' "$COPY_TOKENS" | grep -F -- 'init.guardtalk.wifi-gateway.rc:' >/dev/null; then
  pass "PRODUCT_COPY_FILES includes init.guardtalk.wifi-gateway.rc"
else
  fail "PRODUCT_COPY_FILES missing init.guardtalk.wifi-gateway.rc"
fi
if printf '%s\n' "$COPY_TOKENS" | grep -F -- 'p2p_supplicant_overlay.conf:' >/dev/null; then
  pass "p2p_supplicant_overlay.conf still copied (no_wifi_direct is the block)"
else
  hold "p2p_supplicant_overlay.conf absent from COPY_FILES (unexpected; restriction still required)"
fi

PKG_TOKENS="$(gt_tokens "$PKGS")"
echo "--- filtered PRODUCT_PACKAGES overlay / radio hits ---"
printf '%s\n' "$PKG_TOKENS" | grep -E '^(GuardTalkFrameworksBaseOverlay|GuardTalkSettingsOverlay|NfcNci|android.hardware.nfc-service.st|com.android.bluetooth)$' || true

if printf '%s\n' "$PKG_TOKENS" | grep -Fx -- "GuardTalkFrameworksBaseOverlay" >/dev/null; then
  pass "user PRODUCT_PACKAGES contains GuardTalkFrameworksBaseOverlay"
else
  fail "user PRODUCT_PACKAGES missing GuardTalkFrameworksBaseOverlay"
fi
if printf '%s\n' "$PKG_TOKENS" | grep -Fx -- "GuardTalkSettingsOverlay" >/dev/null; then
  pass "user PRODUCT_PACKAGES contains GuardTalkSettingsOverlay"
else
  fail "user PRODUCT_PACKAGES missing GuardTalkSettingsOverlay"
fi
RADIO_HIT="$(printf '%s\n' "$PKG_TOKENS" | grep -Ex 'NfcNci|android.hardware.nfc-service.st|com.android.bluetooth|android.hardware.bluetooth@1.1-service.bcm4398' || true)"
if [[ -z "$RADIO_HIT" ]]; then
  pass "user PRODUCT_PACKAGES: NFC/BT HAL packages still ABSENT"
else
  fail "NEGATIVE HIT: extra radios in PRODUCT_PACKAGES: ${RADIO_HIT}"
fi

echo
echo "--- stale out/ (HOLD until rebuild; not PASS/FAIL of this card) ---"
if [[ -f "$STALE_WPA" ]]; then
  echo "--- stale out wpa overlay ---"
  rg -n 'hs20|interworking|filter_ssids' "$STALE_WPA" || true
  if rg -q '^hs20=1$|^interworking=1$' "$STALE_WPA"; then
    hold "stale out wpa overlay still Pixel hs20=1/interworking=1 — HOLD until rebuild (not FAIL)"
  else
    hold "stale out wpa overlay present but not Pixel-hs20; still not product truth (HOLD until rebuild)"
  fi
else
  hold "stale out wpa overlay absent — still not a proven rebuilt user image (m not run by QA)"
fi
if [[ -f "$STALE_SSID" ]]; then
  hold "stale out has guardtalk_gateway_ssids — still not a proven rebuilt user image without m this stamp"
else
  hold "stale out missing guardtalk_gateway_ssids — HOLD until rebuild"
fi
if [[ -f "$STALE_RC" ]]; then
  hold "stale out has init.guardtalk.wifi-gateway.rc — still not product truth without m this stamp"
else
  hold "stale out missing init.guardtalk.wifi-gateway.rc — HOLD until rebuild"
fi
hold "m not run this QA stamp (stale vendor wifi overlay not product truth; never device-fixed)"

echo
echo "--- empty saved-set / association HOLD ---"
hold "empty saved-network set does not filter association until an SSID is saved (wpa filter_ssids); first-user no_add_wifi_config is the pre-provision Settings block"
hold "upgrade users already created: default-restrictions apply at user creation only (not rematched live)"

echo
echo "--- adb / on-device associate ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; do not USB GO; on-device associate HOLD; not device-fixed"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — on-device associate HOLD, never device-fixed"
fi
hold "on-device coffee-shop / non-gateway associate HOLD (not claimed live)"
hold "PASS HOLD remains; never APPROVED this panel"

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "STALE_OUT_WPA=HOLD"
echo "ONDEVICE_ASSOCIATE=HOLD"
echo "EMPTY_SAVED_SET_FILTER=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
if [[ "$FAIL" -ne 0 ]]; then
  echo "VERDICT FAIL"
  exit 1
fi
echo "VERDICT PASS (host-static; PASS HOLD remains)"
exit 0
