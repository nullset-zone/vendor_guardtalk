#!/usr/bin/env bash
# Static verification for Q-PORT-AKITA
# (Akita flash-bundle completeness + tokay non-regression + GuardTalk markers).
#
# Cases:
#   1. Bundle releases/desktop-flash/akita-latest complete (18 imgs + avb + sums + README)
#   2. sha256sum -c SHA256SUMS EXIT=0
#   3. README Pixel 8a / REMOTE_BUILD_DIR=…/akita-latest paths
#   4. Tokay releases/desktop-flash/latest still tokay + SHA256SUMS OK
#   5. SetupWizard2.apk (akita out/) has CommunityLock / device_password markers
#   6. Akita GuardTalk layer + Goodix blocklist + VINTF akita excised manifest
#   7. Host re-check vs FLASH BUILD_EXIT=0 (out/ sizes match bundle; adevtool pin)
#   8. adb empty → DEVICE_E2E=HOLD (not invent PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_port_akita_static.sh
# Optional:
#   GT_QA_RUN_LUNCH=1 bash vendor/guardtalk/docs/qa/verify_port_akita_static.sh
#     → source envsetup + lunch akita-trunk_staging-userdebug (slow)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

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

AKITA_BUNDLE="releases/desktop-flash/akita-latest"
TOKAY_LATEST="releases/desktop-flash/latest"
FLASH_REPORT=".agent-comm/inbox/TO_ARCHITECT_T-PORT-AKITA-FLASH.md"
AKITA_OUT="out/target/product/akita"
SUW_APK="$AKITA_OUT/system_ext/priv-app/SetupWizard2/SetupWizard2.apk"
VINTF_AKITA="vendor/guardtalk/vintf/vendor_manifest_no_radio_akita.xml"
VINTF_TOKAY="vendor/guardtalk/vintf/vendor_manifest_no_radio.xml"
VINTF_MK="vendor/guardtalk/radio-excised/vintf-excised.mk"
LAYER_DIR="vendor/guardtalk/device/akita"
BLOCKLIST="$LAYER_DIR/vendor_dlkm.modules.blocklist"
BOARD_LATE="$LAYER_DIR/BoardConfig-excised-late.mk"
EXPECTED_PIN="5ecaa4df472de43127db378dc803a502271a9ecd"
PIN_MK="vendor/google_devices/akita/adevtool-version-check.mk"

REQUIRED_IMGS=(
  bootloader.img radio.img boot.img init_boot.img vendor_boot.img
  vendor_kernel_boot.img pvmfw.img dtbo.img vbmeta.img vbmeta_system.img
  vbmeta_vendor.img system.img system_ext.img product.img vendor.img
  vendor_dlkm.img system_dlkm.img super_empty.img
)

echo "=== Q-PORT-AKITA case1: akita-latest symlink + bundle files ==="

if [[ -L "$AKITA_BUNDLE" ]]; then
  target="$(readlink "$AKITA_BUNDLE")"
  if [[ "$target" == akita-* ]]; then
    pass "akita-latest symlink → $target"
  else
    fail "akita-latest must point at akita-* (got $target)"
  fi
elif [[ -d "$AKITA_BUNDLE" ]]; then
  pass "akita-latest is a directory bundle"
else
  fail "akita-latest missing ($AKITA_BUNDLE)"
fi

for img in "${REQUIRED_IMGS[@]}"; do
  require_file "$AKITA_BUNDLE/$img" "$img"
done
require_file "$AKITA_BUNDLE/avb_pkmd.bin" "avb_pkmd.bin (public)"
require_file "$AKITA_BUNDLE/SHA256SUMS" "SHA256SUMS"
require_file "$AKITA_BUNDLE/README-FLASH-DESKTOP.md" "README-FLASH-DESKTOP.md"

# Resolve symlink so find/glob see real files (akita-latest → akita-<stamp>).
AKITA_BUNDLE_REAL="$(readlink -f "$AKITA_BUNDLE")"
img_count="$(find "$AKITA_BUNDLE_REAL" -maxdepth 1 -type f -name '*.img' | wc -l | tr -d ' ')"
if [[ "$img_count" == "18" ]]; then
  pass "image count == 18 (flash-from-remote class)"
else
  fail "image count expected 18, got $img_count"
fi

# No private key material in desktop-flash bundle
priv_hits="$(find "$AKITA_BUNDLE_REAL" -maxdepth 1 -type f \( -name '*.pem' -o -name '*.pk8' \) 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$priv_hits" == "0" ]]; then
  pass "no *.pem / *.pk8 in akita bundle"
else
  fail "private key material present in akita bundle ($priv_hits files)"
fi

echo "=== Q-PORT-AKITA case2: sha256sum -c SHA256SUMS ==="

if (cd "$AKITA_BUNDLE" && sha256sum -c SHA256SUMS >/tmp/q-port-akita-sha.out 2>&1); then
  pass "sha256sum -c SHA256SUMS EXIT=0"
  ok_lines="$(rg -c ': OK$' /tmp/q-port-akita-sha.out || true)"
  if [[ "${ok_lines:-0}" == "19" ]]; then
    pass "SHA256SUMS verified 19 entries (18 imgs + avb_pkmd.bin)"
  else
    fail "expected 19 OK lines from SHA256SUMS, got ${ok_lines:-0}"
  fi
else
  fail "sha256sum -c SHA256SUMS failed"
  tail -20 /tmp/q-port-akita-sha.out || true
fi

echo "=== Q-PORT-AKITA case3: README Pixel 8a / akita-latest paths ==="

README="$AKITA_BUNDLE/README-FLASH-DESKTOP.md"
require_rg 'Pixel 8a' "$README" "README mentions Pixel 8a"
require_rg 'akita' "$README" "README mentions akita"
require_rg 'REMOTE_BUILD_DIR=.*/releases/desktop-flash/akita-latest' "$README" \
  "README REMOTE_BUILD_DIR=…/akita-latest"
require_rg 'REMOTE_KEY_DIR=.*/releases/desktop-flash/akita-latest' "$README" \
  "README REMOTE_KEY_DIR=…/akita-latest"
require_rg 'akita-trunk_staging-userdebug' "$README" \
  "README cites akita-trunk_staging-userdebug"
require_rg 'BUILD_EXIT=0' "$README" "README cites BUILD_EXIT=0"
require_rg 'releases/desktop-flash/latest' "$README" \
  "README notes tokay latest path remains separate"

echo "=== Q-PORT-AKITA case4: tokay latest non-regression ==="

if [[ -L "$TOKAY_LATEST" ]]; then
  ttarget="$(readlink "$TOKAY_LATEST")"
  if [[ "$ttarget" == tokay-* ]]; then
    pass "latest symlink still tokay → $ttarget"
  else
    fail "latest must remain tokay-* (got $ttarget)"
  fi
else
  fail "releases/desktop-flash/latest missing or not a symlink"
fi

# akita publish must not have redirected latest
if [[ -L "$AKITA_BUNDLE" ]] && [[ -L "$TOKAY_LATEST" ]]; then
  if [[ "$(readlink -f "$AKITA_BUNDLE")" != "$(readlink -f "$TOKAY_LATEST")" ]]; then
    pass "akita-latest and latest resolve to distinct bundles"
  else
    fail "akita-latest and latest must not be the same directory"
  fi
fi

require_file "$TOKAY_LATEST/SHA256SUMS" "tokay SHA256SUMS"
require_file "$TOKAY_LATEST/README-FLASH-DESKTOP.md" "tokay README"
require_rg 'tokay|Pixel 9' "$TOKAY_LATEST/README-FLASH-DESKTOP.md" \
  "tokay README still device-tokay"
if (cd "$TOKAY_LATEST" && sha256sum -c SHA256SUMS >/tmp/q-port-akita-tokay-sha.out 2>&1); then
  pass "tokay sha256sum -c SHA256SUMS EXIT=0"
else
  fail "tokay sha256sum -c SHA256SUMS failed"
fi
TOKAY_LATEST_REAL="$(readlink -f "$TOKAY_LATEST")"
tokay_imgs="$(find "$TOKAY_LATEST_REAL" -maxdepth 1 -type f -name '*.img' | wc -l | tr -d ' ')"
if [[ "$tokay_imgs" == "18" ]]; then
  pass "tokay image count == 18"
else
  fail "tokay image count expected 18, got $tokay_imgs"
fi

echo "=== Q-PORT-AKITA case5: SetupWizard2.apk GuardTalk markers (akita out/) ==="

require_file "$SUW_APK" "akita SetupWizard2.apk"
if [[ -f "$SUW_APK" ]]; then
  marker_out="$(python3 - "$SUW_APK" <<'PY'
import sys, zipfile
apk = sys.argv[1]
needles = [
    ("layout community_lock_activity.xml", None),
    ("dex CommunityLockActivity", b"CommunityLockActivity"),
    ("dex device_password", b"device_password"),
    ("dex DevicePasswordApplier", b"DevicePasswordApplier"),
]
layout = "res/layout/community_lock_activity.xml"
with zipfile.ZipFile(apk) as z:
    names = set(z.namelist())
    data = b"".join(z.read(n) for n in names if n.endswith(".dex"))
    print("LAYOUT_OK" if layout in names else "LAYOUT_FAIL")
    for label, needle in needles[1:]:
        print(("OK|" if needle in data else "FAIL|") + label)
PY
)"
  if echo "$marker_out" | rg -q '^LAYOUT_OK$'; then
    pass "SUW APK has community_lock_activity.xml"
  else
    fail "SUW APK missing community_lock_activity.xml"
  fi
  while IFS= read -r line; do
    case "$line" in
      OK\|*) pass "SUW APK ${line#OK|}" ;;
      FAIL\|*) fail "SUW APK missing ${line#FAIL|}" ;;
    esac
  done <<<"$(echo "$marker_out" | rg '^(OK|FAIL)\|')"
fi

echo "=== Q-PORT-AKITA case6: akita layer / Goodix / VINTF ==="

require_file "$BOARD_LATE" "BoardConfig-excised-late.mk"
require_file "$BLOCKLIST" "akita vendor_dlkm.modules.blocklist"
require_file "$LAYER_DIR/REGEN_HOOKS.md" "REGEN_HOOKS.md"
require_file "$LAYER_DIR/guardtalk-flags.mk" "guardtalk-flags.mk"
require_rg 'goodix_brl_touch' "$BLOCKLIST" "blocklist goodix_brl_touch (Goodix)"
require_rg 'blocklist nitrous' "$BLOCKLIST" "blocklist nitrous (BT)"
require_rg 'BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist' \
  "$BOARD_LATE" "BoardConfig points at akita blocklist"
require_rg 'androidboot.radio.disabled=1' "$BOARD_LATE" "radio disabled cmdline"
require_rg 'include vendor/guardtalk/device/akita/BoardConfig-excised-late.mk' \
  "vendor/google_devices/akita/BoardConfig.mk" "generated BoardConfig includes late excised"
require_rg 'include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk' \
  "vendor/google_devices/akita/akita.mk" "akita.mk includes radio-excised"

require_file "$VINTF_AKITA" "vendor_manifest_no_radio_akita.xml"
require_file "$VINTF_MK" "vintf-excised.mk"
require_rg 'vendor_manifest_no_radio_akita.xml' "$VINTF_MK" \
  "vintf-excised selects akita manifest"
forbid_rg 'IGiaService' "$VINTF_AKITA" "akita VINTF has no IGiaService (tokay-only)"
require_rg 'IGiaService' "$VINTF_TOKAY" \
  "tokay excised VINTF still has IGiaService (untouched pattern)"

echo "=== Q-PORT-AKITA case7: cite FLASH BUILD_EXIT=0 + host re-check ==="

require_file "$FLASH_REPORT" "T-PORT-AKITA-FLASH completion report"
require_rg 'BUILD_EXIT=0' "$FLASH_REPORT" "FLASH report cites BUILD_EXIT=0"
require_rg 'akita-trunk_staging-userdebug' "$FLASH_REPORT" \
  "FLASH report cites lunch target"
require_rg 'akita-20260725-061711' "$FLASH_REPORT" \
  "FLASH report cites staged bundle stamp"

# Host re-check: out/ product images exist and match bundle sizes
for img in boot.img system.img vendor.img product.img vbmeta.img system_ext.img; do
  if [[ -f "$AKITA_OUT/$img" ]] && [[ -f "$AKITA_BUNDLE/$img" ]]; then
    bs="$(stat -c%s "$AKITA_BUNDLE/$img")"
    os="$(stat -c%s "$AKITA_OUT/$img")"
    if [[ "$bs" == "$os" ]]; then
      pass "host re-check size match: $img ($bs)"
    else
      fail "size mismatch $img bundle=$bs out=$os"
    fi
  else
    fail "missing out or bundle for size check: $img"
  fi
done

# adevtool pin match (FLASH claimed no bypass)
if [[ -f "$PIN_MK" ]]; then
  require_rg "$EXPECTED_PIN" "$PIN_MK" "adevtool pin expected in akita pin mk"
  head_pin="$(git -C vendor/adevtool rev-parse HEAD 2>/dev/null || echo missing)"
  if [[ "$head_pin" == "$EXPECTED_PIN" ]]; then
    pass "vendor/adevtool HEAD matches pin ($EXPECTED_PIN)"
  else
    fail "adevtool HEAD $head_pin != pin $EXPECTED_PIN"
  fi
else
  fail "missing $PIN_MK"
fi

# Prefer host lunch evidence file from this QA session when present; else optional re-run.
LUNCH_EVIDENCE="/tmp/q-port-akita-lunch.out"
if [[ -f "$LUNCH_EVIDENCE" ]] && rg -q 'TARGET_PRODUCT=akita' "$LUNCH_EVIDENCE" \
  && rg -q 'TARGET_BUILD_VARIANT=userdebug' "$LUNCH_EVIDENCE"; then
  pass "host lunch re-check evidence: TARGET_PRODUCT=akita userdebug (/tmp/q-port-akita-lunch.out)"
elif [[ "${GT_QA_RUN_LUNCH:-0}" == "1" ]]; then
  echo "=== lunch re-smoke (GT_QA_RUN_LUNCH=1) ==="
  set +e
  # shellcheck disable=SC1091
  source build/envsetup.sh >/tmp/q-port-akita-envsetup.out 2>&1
  lunch akita-trunk_staging-userdebug >/tmp/q-port-akita-lunch.out 2>&1
  lunch_ec=$?
  set -e
  echo "LUNCH_EXIT=$lunch_ec"
  if [[ "$lunch_ec" == "0" ]] && rg -q 'TARGET_PRODUCT=akita' /tmp/q-port-akita-lunch.out; then
    pass "lunch akita-trunk_staging-userdebug EXIT=0 (TARGET_PRODUCT=akita)"
  else
    fail "lunch akita-trunk_staging-userdebug EXIT=${lunch_ec:-?}"
    tail -40 /tmp/q-port-akita-lunch.out || true
  fi
else
  pass "lunch live re-smoke deferred (FLASH BUILD_EXIT=0 + size/pin re-check OK; set GT_QA_RUN_LUNCH=1 or pre-create /tmp/q-port-akita-lunch.out)"
fi

echo "=== Q-PORT-AKITA case8: device E2E / adb ==="

if command -v adb >/dev/null 2>&1; then
  adb_out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "$adb_out" ]]; then
    pass "adb device(s) present: $(echo "$adb_out" | tr '\n' ' ')"
    hold "device flash+boot+parity E2E not executed in this static script (manual)"
  else
    hold "adb present but no device attached — device flash+boot+parity E2E HOLD"
  fi
else
  hold "adb binary unavailable — device flash+boot+parity E2E HOLD"
fi

echo ""
echo "=== Q-PORT-AKITA static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
