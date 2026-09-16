#!/usr/bin/env bash
# Static verification for Q-PORT-KOMODO
# (Pixel 9 Pro XL stamp completeness + CLI mapping + tokay/akita/rango non-regression).
#
# Cases:
#   1. releases/desktop-flash/komodo-latest → komodo-20260915-063833
#   2. sha256sum -c SHA256SUMS (20/20)
#   3. Required imgs + avb_pkmd.bin + init.insmod.komodo.cfg; super.img omitted OK
#   4. No *.pem/*.pk8; no keys/komodo/; avb_pkmd.bin matches keys/tokay/
#   5. tokay latest inode 193110379; akita-latest inode 193110357
#   6. both flash-from-remote.sh cmp equal; bash -n both
#   7. DEVICE=komodo → komodo-latest; pretty Pixel 9 Pro XL; fips family; extras
#   8. Negative: caiman not komodo; rango stays rango-latest; empty/unknown fail-closed
#   9. Layer vendor/guardtalk/device/komodo/ (zumapro/QFP, not akita Goodix)
#  10. Cite FLASH BUILD_EXIT=0 log (do not claim lunch PASS without running lunch)
#  11. adb empty → DEVICE_E2E=HOLD (do not invent USB PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_port_komodo_static.sh
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

KOMODO_BUNDLE="releases/desktop-flash/komodo-latest"
TOKAY_LATEST="releases/desktop-flash/latest"
AKITA_LATEST="releases/desktop-flash/akita-latest"
RANGO_LATEST="releases/desktop-flash/rango-latest"
EXPECTED_KOMODO_STAMP="komodo-20260915-063833"
EXPECTED_TOKAY_INODE="193110379"
EXPECTED_AKITA_INODE="193110357"
EXPECTED_AVB="7728e30f50bfa5cea165f473175a08803f6a8346642b5aa10913e9d9e6defef6"
FLASH_LOG="/tmp/t-port-komodo-flash-m-20260915T050731Z.log"
LAYER_DIR="vendor/guardtalk/device/komodo"
FLASH_ROOT="scripts/flash-from-remote.sh"
FLASH_VENDOR="vendor/guardtalk/scripts/flash-from-remote.sh"

REQUIRED_IMGS=(
  bootloader.img radio.img boot.img init_boot.img vendor_boot.img
  vendor_kernel_boot.img pvmfw.img dtbo.img vbmeta.img vbmeta_system.img
  vbmeta_vendor.img system.img system_ext.img product.img vendor.img
  vendor_dlkm.img system_dlkm.img super_empty.img
)

echo "=== Q-PORT-KOMODO case1: komodo-latest symlink ==="

if [[ -L "$KOMODO_BUNDLE" ]]; then
  target="$(readlink "$KOMODO_BUNDLE")"
  if [[ "$target" == "$EXPECTED_KOMODO_STAMP" ]]; then
    pass "komodo-latest → $target"
  else
    fail "komodo-latest expected $EXPECTED_KOMODO_STAMP, got $target"
  fi
else
  fail "komodo-latest is not a symlink"
fi

echo "=== Q-PORT-KOMODO case3: required files ==="

for img in "${REQUIRED_IMGS[@]}"; do
  require_file "$KOMODO_BUNDLE/$img" "$img"
done
require_file "$KOMODO_BUNDLE/avb_pkmd.bin" "avb_pkmd.bin (public)"
require_file "$KOMODO_BUNDLE/init.insmod.komodo.cfg" "init.insmod.komodo.cfg"
require_file "$KOMODO_BUNDLE/SHA256SUMS" "SHA256SUMS"
require_file "$KOMODO_BUNDLE/README-FLASH-DESKTOP.md" "README-FLASH-DESKTOP.md"
if [[ -e "$KOMODO_BUNDLE/super.img" ]]; then
  fail "super.img present (expected omitted, akita pattern)"
else
  pass "super.img omitted OK"
fi

echo "=== Q-PORT-KOMODO case2: sha256sum -c SHA256SUMS ==="

SHA_OUT="$(mktemp)"
if (cd "$KOMODO_BUNDLE" && sha256sum -c SHA256SUMS >"$SHA_OUT" 2>&1); then
  pass "sha256sum -c SHA256SUMS EXIT=0"
  ok_lines="$(rg -c ': OK$' "$SHA_OUT" || true)"
  if [[ "${ok_lines:-0}" == "20" ]]; then
    pass "SHA256SUMS verified 20/20"
  else
    fail "expected 20 OK lines, got ${ok_lines:-0}"
  fi
else
  fail "sha256sum -c SHA256SUMS failed"
  cat "$SHA_OUT" || true
fi
rm -f "$SHA_OUT"

echo "=== Q-PORT-KOMODO case4: no private keys; public avb_pkmd ==="

pem_count="$(find -L "$KOMODO_BUNDLE" -maxdepth 1 \( -name '*.pem' -o -name '*.pk8' \) -print | wc -l | tr -d ' ')"
if [[ "$pem_count" == "0" ]]; then
  pass "no .pem/.pk8 in stamp"
else
  fail "found $pem_count pem/pk8 in stamp"
fi
if [[ -e keys/komodo ]]; then
  fail "keys/komodo/ exists (KEYS card HOLD; must stay absent)"
else
  pass "keys/komodo/ absent"
fi
got_avb="$(sha256sum "$KOMODO_BUNDLE/avb_pkmd.bin" | awk '{print $1}')"
tokay_avb="$(sha256sum keys/tokay/avb_pkmd.bin | awk '{print $1}')"
if [[ "$got_avb" == "$EXPECTED_AVB" && "$tokay_avb" == "$EXPECTED_AVB" ]]; then
  pass "avb_pkmd.bin SHA matches keys/tokay/ ($EXPECTED_AVB)"
else
  fail "avb_pkmd mismatch stamp=$got_avb tokay=$tokay_avb expected=$EXPECTED_AVB"
fi
if cmp -s "$KOMODO_BUNDLE/avb_pkmd.bin" keys/tokay/avb_pkmd.bin; then
  pass "cmp avb_pkmd.bin == keys/tokay/avb_pkmd.bin"
else
  fail "cmp avb_pkmd.bin vs keys/tokay/avb_pkmd.bin DIFF"
fi

echo "=== Q-PORT-KOMODO case5: tokay/akita inodes unchanged ==="

tokay_inode="$(stat -c%i "$TOKAY_LATEST")"
akita_inode="$(stat -c%i "$AKITA_LATEST")"
if [[ "$tokay_inode" == "$EXPECTED_TOKAY_INODE" ]]; then
  pass "latest inode $tokay_inode (tokay)"
else
  fail "latest inode expected $EXPECTED_TOKAY_INODE got $tokay_inode"
fi
if [[ "$akita_inode" == "$EXPECTED_AKITA_INODE" ]]; then
  pass "akita-latest inode $akita_inode"
else
  fail "akita-latest inode expected $EXPECTED_AKITA_INODE got $akita_inode"
fi
tokay_tgt="$(readlink "$TOKAY_LATEST")"
akita_tgt="$(readlink "$AKITA_LATEST")"
if [[ "$tokay_tgt" == tokay-* ]]; then
  pass "latest still tokay → $tokay_tgt"
else
  fail "latest must remain tokay-* (got $tokay_tgt)"
fi
if [[ "$akita_tgt" == akita-* ]]; then
  pass "akita-latest still akita → $akita_tgt"
else
  fail "akita-latest must remain akita-* (got $akita_tgt)"
fi

echo "=== Q-PORT-KOMODO case6: flash-from-remote.sh cmp + bash -n ==="

if cmp -s "$FLASH_ROOT" "$FLASH_VENDOR"; then
  pass "cmp scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh"
else
  fail "flash-from-remote.sh copies DIFF"
fi
if bash -n "$FLASH_ROOT"; then
  pass "bash -n $FLASH_ROOT"
else
  fail "bash -n $FLASH_ROOT failed"
fi
if bash -n "$FLASH_VENDOR"; then
  pass "bash -n $FLASH_VENDOR"
else
  fail "bash -n $FLASH_VENDOR failed"
fi

echo "=== Q-PORT-KOMODO case7+8: CLI mapping + negative matrix ==="

# Extract helpers without executing the flash script body (no USB).
eval "$(sed -n '/^normalize_device() {/,/^}$/p; /^device_pretty() {/,/^}$/p' "$FLASH_ROOT")"
eval "$(grep -E '^(AKITA|KOMODO|RANGO)_EXTRA_FILES=' "$FLASH_ROOT")"

nd="$(normalize_device komodo)"
if [[ "$nd" == "komodo" ]]; then
  pass "normalize_device komodo → komodo"
else
  fail "normalize_device komodo → '$nd'"
fi
pretty="$(device_pretty komodo)"
if [[ "$pretty" == "Pixel 9 Pro XL (komodo)" ]]; then
  pass "device_pretty komodo → $pretty"
else
  fail "device_pretty komodo unexpected: '$pretty'"
fi

require_rg 'komodo-latest' "$FLASH_ROOT" "apply_remote_paths komodo → komodo-latest"
require_rg 'tokay\|akita\|komodo' "$FLASH_ROOT" "firmware cleanup tokay|akita|komodo (fips)"
require_rg 'erase fips' "$FLASH_ROOT" "komodo family erase fips"
require_rg 'init.insmod.komodo.cfg' "$FLASH_ROOT" "KOMODO extras init.insmod.komodo.cfg"
if [[ "${KOMODO_EXTRA_FILES[*]}" == "init.insmod.komodo.cfg" ]]; then
  pass "KOMODO_EXTRA_FILES=init.insmod.komodo.cfg"
else
  fail "KOMODO_EXTRA_FILES unexpected: '${KOMODO_EXTRA_FILES[*]}'"
fi

# caiman must not map to komodo
caiman_nd="$(normalize_device caiman)"
if [[ -z "$caiman_nd" ]]; then
  pass "caiman is not mapped (fail-closed, not komodo)"
else
  fail "caiman mapped to '$caiman_nd' (must not steal komodo)"
fi

# rango mapping stays rango-latest
rango_nd="$(normalize_device rango)"
if [[ "$rango_nd" == "rango" ]]; then
  pass "normalize_device rango → rango (not komodo)"
else
  fail "rango mapping stolen: '$rango_nd'"
fi
require_rg 'rango-latest' "$FLASH_ROOT" "apply_remote_paths rango → rango-latest"
rango_tgt="$(readlink "$RANGO_LATEST")"
if [[ "$rango_tgt" == rango-* && "$rango_tgt" != *komodo* ]]; then
  pass "rango-latest still $rango_tgt (not stolen by komodo)"
else
  fail "rango-latest unexpected: '$rango_tgt'"
fi
if [[ "$(readlink "$KOMODO_BUNDLE")" != "$rango_tgt" ]]; then
  pass "komodo stamp distinct from rango stamp"
else
  fail "komodo and rango stamps collide"
fi

# empty / unknown fail-closed
empty_nd="$(normalize_device "")"
unk_nd="$(normalize_device unknown)"
if [[ -z "$empty_nd" ]]; then
  pass "empty DEVICE normalize → empty (fail-closed)"
else
  fail "empty DEVICE mapped to '$empty_nd'"
fi
if [[ -z "$unk_nd" ]]; then
  pass "unknown DEVICE normalize → empty (fail-closed)"
else
  fail "unknown DEVICE mapped to '$unk_nd'"
fi
# Script die path for unsupported override (extracted, no USB)
if rg -q "DEVICE='\\\$DEVICE' not supported" "$FLASH_ROOT"; then
  pass "DEVICE override die fail-closed present"
else
  fail "missing DEVICE override fail-closed die"
fi

echo "=== Q-PORT-KOMODO case9: GuardTalk layer still present ==="

if [[ -d "$LAYER_DIR" ]]; then
  pass "layer dir $LAYER_DIR present"
else
  fail "layer dir missing"
fi
require_file "$LAYER_DIR/guardtalk-flags.mk" "guardtalk-flags.mk"
require_file "$LAYER_DIR/BoardConfig-excised-late.mk" "BoardConfig-excised-late.mk"
require_file "$LAYER_DIR/vendor_dlkm.modules.blocklist" "vendor_dlkm.modules.blocklist"
require_rg 'GuardTalk Pixel 9 Pro XL' "$LAYER_DIR/guardtalk-flags.mk" "GUARDTALK_PRODUCT_MODEL Pixel 9 Pro XL"
require_rg 'zumapro' "$LAYER_DIR/BoardConfig-excised-late.mk" "BoardConfig zumapro (not zuma/akita)"
require_rg 'syna_touch' "$LAYER_DIR/vendor_dlkm.modules.blocklist" "blocklist syna_touch (zumapro)"
forbid_rg '^blocklist goodix_brl_touch' "$LAYER_DIR/vendor_dlkm.modules.blocklist" "no akita Goodix blocklist entry"
require_rg 'QFP' "$LAYER_DIR/REGEN_HOOKS.md" "REGEN_HOOKS QFP fingerprint"
forbid_rg 'goodix_brl_touch$' "$LAYER_DIR/guardtalk-flags.mk" "flags are not akita Goodix"

echo "=== Q-PORT-KOMODO case10: FLASH BUILD_EXIT=0 cite (lunch not re-run) ==="

if [[ -f "$FLASH_LOG" ]] && rg -q 'BUILD_EXIT=0' "$FLASH_LOG" \
  && rg -q 'build completed successfully' "$FLASH_LOG"; then
  pass "FLASH log $FLASH_LOG cites BUILD_EXIT=0"
else
  fail "FLASH log missing BUILD_EXIT=0 ($FLASH_LOG)"
fi
if [[ -f "$KOMODO_BUNDLE/README-FLASH-DESKTOP.md" ]] \
  && rg -q 'BUILD_EXIT=0' "$KOMODO_BUNDLE/README-FLASH-DESKTOP.md"; then
  pass "stamp README cites BUILD_EXIT=0"
else
  fail "stamp README missing BUILD_EXIT=0 cite"
fi
hold "lunch komodo-trunk_staging-userdebug not re-run this QA session (heavy); cite FLASH log + file rematch only"

echo "=== Q-PORT-KOMODO case11: adb/device smoke ==="

if command -v adb >/dev/null 2>&1; then
  adb_out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "$adb_out" ]]; then
    hold "adb device(s) present but USB flash smoke NOT executed (dispatch: no USB PASS)"
  else
    hold "adb present but no device attached — device smoke E2E HOLD (not invent PASS)"
  fi
else
  hold "adb binary unavailable — device smoke E2E HOLD"
fi
if ! command -v fastboot >/dev/null 2>&1; then
  hold "fastboot binary unavailable — no live flash"
fi

echo ""
echo "=== Q-PORT-KOMODO static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
