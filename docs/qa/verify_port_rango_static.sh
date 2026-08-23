#!/usr/bin/env bash
# Static verification for Q-PORT-RANGO
# (Rango flash-bundle completeness + tokay/akita non-regression + layer/VINTF).
#
# Cases:
#   1. Bundle releases/desktop-flash/rango-latest complete
#      (18 imgs + avb + sums + README; prefer init.insmod.rango.cfg)
#   2. sha256sum -c SHA256SUMS EXIT=0
#   3. No *.pem / *.pk8 in bundle
#   4. Symlink isolation: rango-latest ≠ latest ≠ akita-latest;
#      tokay/akita stamps unchanged (or documented)
#   5. README Pixel 10 Pro Fold + REMOTE_BUILD_DIR=…/rango-latest
#   6. flash-from-remote both copies: rango → rango-latest; Pixel 10 Pro Fold
#   7. Layer sanity: vendor/guardtalk/device/rango/; REGEN_HOOKS laguna;
#      VINTF rango excised + foldable touchflow preserved
#   8. adb empty → DEVICE_E2E=HOLD (not invent PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_port_rango_static.sh
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

RANGO_BUNDLE="releases/desktop-flash/rango-latest"
TOKAY_LATEST="releases/desktop-flash/latest"
AKITA_LATEST="releases/desktop-flash/akita-latest"
EXPECTED_TOKAY_STAMP="tokay-20260725-102506"
EXPECTED_AKITA_STAMP="akita-20260725-101434"
EXPECTED_RANGO_STAMP="rango-20260725-133716"
FLASH_REPORT=".agent-comm/inbox/TO_ARCHITECT.md"
LAYER_DIR="vendor/guardtalk/device/rango"
REGEN_HOOKS="$LAYER_DIR/REGEN_HOOKS.md"
VINTF_RANGO="vendor/guardtalk/vintf/vendor_manifest_no_radio_rango.xml"
VINTF_MK="vendor/guardtalk/radio-excised/vintf-excised.mk"
FLASH_ROOT="scripts/flash-from-remote.sh"
FLASH_VENDOR="vendor/guardtalk/scripts/flash-from-remote.sh"
RANGO_OUT="out/target/product/rango"

REQUIRED_IMGS=(
  bootloader.img radio.img boot.img init_boot.img vendor_boot.img
  vendor_kernel_boot.img pvmfw.img dtbo.img vbmeta.img vbmeta_system.img
  vbmeta_vendor.img system.img system_ext.img product.img vendor.img
  vendor_dlkm.img system_dlkm.img super_empty.img
)

echo "=== Q-PORT-RANGO case1: rango-latest symlink + bundle files ==="

if [[ -L "$RANGO_BUNDLE" ]]; then
  target="$(readlink "$RANGO_BUNDLE")"
  if [[ "$target" == rango-* ]]; then
    pass "rango-latest symlink → $target"
  else
    fail "rango-latest must point at rango-* (got $target)"
  fi
  if [[ "$target" == "$EXPECTED_RANGO_STAMP" ]]; then
    pass "rango-latest stamp matches expected $EXPECTED_RANGO_STAMP"
  else
    fail "rango-latest stamp expected $EXPECTED_RANGO_STAMP, got $target"
  fi
elif [[ -d "$RANGO_BUNDLE" ]]; then
  pass "rango-latest is a directory bundle"
else
  fail "rango-latest missing ($RANGO_BUNDLE)"
fi

for img in "${REQUIRED_IMGS[@]}"; do
  require_file "$RANGO_BUNDLE/$img" "$img"
done
require_file "$RANGO_BUNDLE/avb_pkmd.bin" "avb_pkmd.bin (public)"
require_file "$RANGO_BUNDLE/SHA256SUMS" "SHA256SUMS"
require_file "$RANGO_BUNDLE/README-FLASH-DESKTOP.md" "README-FLASH-DESKTOP.md"
# Prefer also present (flash-from-remote rango extras)
require_file "$RANGO_BUNDLE/init.insmod.rango.cfg" "init.insmod.rango.cfg (preferred)"

RANGO_BUNDLE_REAL="$(readlink -f "$RANGO_BUNDLE")"
img_count="$(find "$RANGO_BUNDLE_REAL" -maxdepth 1 -type f -name '*.img' | wc -l | tr -d ' ')"
if [[ "$img_count" == "18" ]]; then
  pass "image count == 18 (flash-from-remote class)"
else
  fail "image count expected 18, got $img_count"
fi

echo "=== Q-PORT-RANGO case2: sha256sum -c SHA256SUMS ==="

if (cd "$RANGO_BUNDLE" && sha256sum -c SHA256SUMS >/tmp/q-port-rango-sha.out 2>&1); then
  pass "sha256sum -c SHA256SUMS EXIT=0"
  ok_lines="$(rg -c ': OK$' /tmp/q-port-rango-sha.out || true)"
  # 18 imgs + avb_pkmd.bin + init.insmod.rango.cfg = 20
  if [[ "${ok_lines:-0}" -ge 19 ]]; then
    pass "SHA256SUMS verified ${ok_lines} entries (≥19)"
  else
    fail "expected ≥19 OK lines from SHA256SUMS, got ${ok_lines:-0}"
  fi
else
  fail "sha256sum -c SHA256SUMS failed"
  tail -20 /tmp/q-port-rango-sha.out || true
fi

echo "=== Q-PORT-RANGO case3: no private keys in bundle ==="

priv_hits="$(find "$RANGO_BUNDLE_REAL" -maxdepth 1 -type f \( -name '*.pem' -o -name '*.pk8' \) 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$priv_hits" == "0" ]]; then
  pass "no *.pem / *.pk8 in rango bundle"
else
  fail "private key material present in rango bundle ($priv_hits files)"
fi

echo "=== Q-PORT-RANGO case4: symlink isolation + tokay/akita stamps ==="

if [[ -L "$TOKAY_LATEST" ]]; then
  ttarget="$(readlink "$TOKAY_LATEST")"
  if [[ "$ttarget" == tokay-* ]]; then
    pass "latest symlink still tokay → $ttarget"
  else
    fail "latest must remain tokay-* (got $ttarget)"
  fi
  if [[ "$ttarget" == "$EXPECTED_TOKAY_STAMP" ]]; then
    pass "tokay latest stamp unchanged ($EXPECTED_TOKAY_STAMP)"
  else
    fail "tokay stamp changed: expected $EXPECTED_TOKAY_STAMP got $ttarget"
  fi
else
  fail "releases/desktop-flash/latest missing or not a symlink"
fi

if [[ -L "$AKITA_LATEST" ]]; then
  atarget="$(readlink "$AKITA_LATEST")"
  if [[ "$atarget" == akita-* ]]; then
    pass "akita-latest symlink still akita → $atarget"
  else
    fail "akita-latest must remain akita-* (got $atarget)"
  fi
  if [[ "$atarget" == "$EXPECTED_AKITA_STAMP" ]]; then
    pass "akita-latest stamp unchanged ($EXPECTED_AKITA_STAMP)"
  else
    fail "akita stamp changed: expected $EXPECTED_AKITA_STAMP got $atarget"
  fi
else
  fail "releases/desktop-flash/akita-latest missing or not a symlink"
fi

if [[ -L "$RANGO_BUNDLE" ]] && [[ -L "$TOKAY_LATEST" ]] && [[ -L "$AKITA_LATEST" ]]; then
  r_real="$(readlink -f "$RANGO_BUNDLE")"
  t_real="$(readlink -f "$TOKAY_LATEST")"
  a_real="$(readlink -f "$AKITA_LATEST")"
  if [[ "$r_real" != "$t_real" && "$r_real" != "$a_real" && "$t_real" != "$a_real" ]]; then
    pass "rango-latest, latest, akita-latest resolve to three distinct bundles"
  else
    fail "symlink isolation broken: rango=$r_real tokay=$t_real akita=$a_real"
  fi
fi

require_file "$TOKAY_LATEST/SHA256SUMS" "tokay SHA256SUMS"
require_file "$AKITA_LATEST/SHA256SUMS" "akita SHA256SUMS"
if (cd "$TOKAY_LATEST" && sha256sum -c SHA256SUMS >/tmp/q-port-rango-tokay-sha.out 2>&1); then
  pass "tokay sha256sum -c SHA256SUMS EXIT=0"
else
  fail "tokay sha256sum -c SHA256SUMS failed"
fi
if (cd "$AKITA_LATEST" && sha256sum -c SHA256SUMS >/tmp/q-port-rango-akita-sha.out 2>&1); then
  pass "akita sha256sum -c SHA256SUMS EXIT=0"
else
  fail "akita sha256sum -c SHA256SUMS failed"
fi

echo "=== Q-PORT-RANGO case5: README Pixel 10 Pro Fold / rango-latest paths ==="

README="$RANGO_BUNDLE/README-FLASH-DESKTOP.md"
require_rg 'Pixel 10 Pro Fold' "$README" "README mentions Pixel 10 Pro Fold"
require_rg 'rango' "$README" "README mentions rango"
require_rg 'REMOTE_BUILD_DIR=.*/releases/desktop-flash/rango-latest' "$README" \
  "README REMOTE_BUILD_DIR=…/rango-latest"
require_rg 'REMOTE_KEY_DIR=.*/releases/desktop-flash/rango-latest' "$README" \
  "README REMOTE_KEY_DIR=…/rango-latest"
require_rg 'rango-trunk_staging-userdebug' "$README" \
  "README cites rango-trunk_staging-userdebug"
require_rg 'BUILD_EXIT=0' "$README" "README cites BUILD_EXIT=0"
require_rg 'releases/desktop-flash/latest' "$README" \
  "README notes tokay latest path remains separate"
require_rg 'akita-latest' "$README" "README notes akita-latest remains distinct"

echo "=== Q-PORT-RANGO case6: flash-from-remote both copies ==="

for script in "$FLASH_ROOT" "$FLASH_VENDOR"; do
  require_file "$script" "$script"
  require_rg 'rango\) echo "rango"' "$script" \
    "normalize_device maps rango ($script)"
  require_rg 'Pixel 10 Pro Fold \(rango\)' "$script" \
    "device_pretty Pixel 10 Pro Fold ($script)"
  require_rg 'releases/desktop-flash/rango-latest' "$script" \
    "apply_remote_paths → rango-latest ($script)"
  require_rg 'init\.insmod\.rango\.cfg' "$script" \
    "rango extras init.insmod.rango.cfg ($script)"
done

if diff -q "$FLASH_ROOT" "$FLASH_VENDOR" >/dev/null 2>&1; then
  pass "flash-from-remote.sh copies identical (root ↔ vendor)"
else
  fail "flash-from-remote.sh copies diverge (root vs vendor)"
fi

echo "=== Q-PORT-RANGO case7: layer / REGEN_HOOKS laguna / VINTF rango ==="

require_file "$LAYER_DIR/BoardConfig-excised-late.mk" "BoardConfig-excised-late.mk"
require_file "$LAYER_DIR/vendor_dlkm.modules.blocklist" "rango vendor_dlkm.modules.blocklist"
require_file "$REGEN_HOOKS" "REGEN_HOOKS.md"
require_file "$LAYER_DIR/guardtalk-flags.mk" "guardtalk-flags.mk"
require_file "$LAYER_DIR/guardtalk-insmod.mk" "guardtalk-insmod.mk"
require_rg 'laguna' "$REGEN_HOOKS" "REGEN_HOOKS says laguna"
require_rg 'rango is laguna' "$REGEN_HOOKS" "REGEN_HOOKS asserts rango is laguna"
require_rg 'foldable|fold' "$REGEN_HOOKS" "REGEN_HOOKS notes foldable concern"

require_file "$VINTF_RANGO" "vendor_manifest_no_radio_rango.xml"
require_file "$VINTF_MK" "vintf-excised.mk"
require_rg 'vendor_manifest_no_radio_rango.xml' "$VINTF_MK" \
  "vintf-excised selects rango manifest"
require_rg 'touchflow_outer' "$VINTF_RANGO" \
  "rango VINTF keeps foldable touchflow_outer"
require_rg 'Foldable twoshay touchflow_outer is preserved' "$VINTF_RANGO" \
  "rango VINTF documents foldable touchflow concern"

# Host re-check: out/ product images exist and match bundle sizes (if out present)
if [[ -d "$RANGO_OUT" ]]; then
  for img in boot.img system.img vendor.img product.img vbmeta.img system_ext.img; do
    if [[ -f "$RANGO_OUT/$img" ]] && [[ -f "$RANGO_BUNDLE/$img" ]]; then
      bs="$(stat -c%s "$RANGO_BUNDLE/$img")"
      os="$(stat -c%s "$RANGO_OUT/$img")"
      if [[ "$bs" == "$os" ]]; then
        pass "host re-check size match: $img ($bs)"
      else
        fail "size mismatch $img bundle=$bs out=$os"
      fi
    else
      fail "missing out or bundle for size check: $img"
    fi
  done
else
  hold "out/target/product/rango absent — size re-check skipped (cite FLASH BUILD_EXIT=0)"
fi

# Cite FLASH BUILD_EXIT=0 from inbox report if present (may still be FLASH report)
if [[ -f "$FLASH_REPORT" ]] && rg -q 'BUILD_EXIT=0' "$FLASH_REPORT" \
  && rg -qi 'rango' "$FLASH_REPORT"; then
  pass "inbox report cites rango BUILD_EXIT=0"
elif [[ -f "$RANGO_BUNDLE/README-FLASH-DESKTOP.md" ]] \
  && rg -q 'BUILD_EXIT=0' "$RANGO_BUNDLE/README-FLASH-DESKTOP.md"; then
  pass "README cites BUILD_EXIT=0 (FLASH report may have been replaced by QA)"
else
  fail "no BUILD_EXIT=0 cite for rango flash build"
fi

echo "=== Q-PORT-RANGO case8: device E2E / adb (fold smoke) ==="

if command -v adb >/dev/null 2>&1; then
  adb_out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "$adb_out" ]]; then
    pass "adb device(s) present: $(echo "$adb_out" | tr '\n' ' ')"
    hold "device fold flash+boot smoke not executed in this static script (manual)"
  else
    hold "adb present but no device attached — device fold smoke E2E HOLD"
  fi
else
  hold "adb binary unavailable — device fold smoke E2E HOLD"
fi

echo ""
echo "=== Q-PORT-RANGO static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
