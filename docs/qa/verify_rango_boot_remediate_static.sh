#!/usr/bin/env bash
# Static verification for Q-RANGO-BOOT-REMEDIATE
# Independent rematch of T-RANGO-BOOT-REMEDIATE (RCA STOP, not boot-green).
#
# Cases:
#   1. rango-latest → rango-20260802-130756 (not retargeted; not 145117)
#   2. tokay/akita/komodo latest inodes unchanged
#   3. SHA256SUMS OK on 130756 and 145117
#   4. 145117 exists and is not linked as *-latest
#   5. CLI DEVICE=rango maps to rango-latest (extracted helpers; no USB)
#   6. rango not in ALLOWED_PRODUCTS / wizard production set
#   7. adb empty → USB HOLD (do not invent boot PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_rango_boot_remediate_static.sh
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
  if [[ -f "$file" ]] && grep -qE -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

forbid_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && grep -qE -- "$pat" "$file"; then
    fail "$label (forbidden pattern in $file)"
  else
    pass "$label"
  fi
}

RANGO_LATEST="releases/desktop-flash/rango-latest"
EXPECTED_RANGO_STAMP="rango-20260802-130756"
CANDIDATE_STAMP="rango-20260803-145117"
CANDIDATE_DIR="releases/desktop-flash/${CANDIDATE_STAMP}"
EXPECTED_RANGO_INODE="193110354"
EXPECTED_TOKAY_INODE="193110379"
EXPECTED_AKITA_INODE="193110357"
EXPECTED_KOMODO_INODE="193110380"
FLASH_ROOT="scripts/flash-from-remote.sh"
FLASH_VENDOR="vendor/guardtalk/scripts/flash-from-remote.sh"
TYPES_TS="vendor/guardtalk/web-installer/src/types.ts"
WIZARD_TS="vendor/guardtalk/web-installer/wizard/devices.ts"
LATE_TS="vendor/guardtalk/web-installer/routes/install/late-steps.ts"
EARLY_TS="vendor/guardtalk/web-installer/routes/install/early-steps.ts"
DIST_TYPES="vendor/guardtalk/web-installer/dist/src/types.js"
DIST_WIZARD="vendor/guardtalk/web-installer/dist/wizard/devices.js"
DIST_TARGET="vendor/guardtalk/web-installer/dist/site/install/late-steps.js"
DIST_EARLY="vendor/guardtalk/web-installer/dist/site/install/early-steps.js"
STOCK_VENDOR="releases/desktop-flash/rango-stock-userspace/vendor.img"
EXPECTED_SHA_OK=22

echo "=== Q-RANGO-BOOT-REMEDIATE case1: rango-latest stamp pin ==="

if [[ -L "$RANGO_LATEST" ]]; then
  target="$(readlink "$RANGO_LATEST")"
  if [[ "$target" == "$EXPECTED_RANGO_STAMP" ]]; then
    pass "rango-latest → $target"
  else
    fail "rango-latest expected $EXPECTED_RANGO_STAMP, got $target"
  fi
  if [[ "$target" == "$CANDIDATE_STAMP" ]]; then
    fail "rango-latest was retargeted to $CANDIDATE_STAMP"
  else
    pass "rango-latest is not $CANDIDATE_STAMP"
  fi
else
  fail "rango-latest is not a symlink"
fi

rango_inode="$(stat -c '%i' "$RANGO_LATEST")"
if [[ "$rango_inode" == "$EXPECTED_RANGO_INODE" ]]; then
  pass "rango-latest inode $rango_inode"
else
  fail "rango-latest inode expected $EXPECTED_RANGO_INODE got $rango_inode"
fi

echo "=== Q-RANGO-BOOT-REMEDIATE case2: Pixel 9 latest inodes unchanged ==="

tokay_inode="$(stat -c '%i' releases/desktop-flash/latest)"
akita_inode="$(stat -c '%i' releases/desktop-flash/akita-latest)"
komodo_inode="$(stat -c '%i' releases/desktop-flash/komodo-latest)"
if [[ "$tokay_inode" == "$EXPECTED_TOKAY_INODE" ]]; then
  pass "tokay latest inode $tokay_inode"
else
  fail "tokay latest inode expected $EXPECTED_TOKAY_INODE got $tokay_inode"
fi
if [[ "$akita_inode" == "$EXPECTED_AKITA_INODE" ]]; then
  pass "akita-latest inode $akita_inode"
else
  fail "akita-latest inode expected $EXPECTED_AKITA_INODE got $akita_inode"
fi
if [[ "$komodo_inode" == "$EXPECTED_KOMODO_INODE" ]]; then
  pass "komodo-latest inode $komodo_inode"
else
  fail "komodo-latest inode expected $EXPECTED_KOMODO_INODE got $komodo_inode"
fi
tokay_tgt="$(readlink releases/desktop-flash/latest)"
akita_tgt="$(readlink releases/desktop-flash/akita-latest)"
komodo_tgt="$(readlink releases/desktop-flash/komodo-latest)"
pass "tokay latest → $tokay_tgt"
pass "akita-latest → $akita_tgt"
pass "komodo-latest → $komodo_tgt"

echo "=== Q-RANGO-BOOT-REMEDIATE case3: SHA256SUMS 130756 + 145117 ==="

verify_sha() {
  local dir="$1" label="$2"
  local sha_out ok_lines
  require_file "$dir/SHA256SUMS" "$label SHA256SUMS"
  sha_out="$(mktemp)"
  if (cd "$dir" && sha256sum -c SHA256SUMS >"$sha_out" 2>&1); then
    pass "$label sha256sum -c SHA256SUMS EXIT=0"
    ok_lines="$(grep -c ': OK$' "$sha_out" || true)"
    if [[ "${ok_lines:-0}" == "$EXPECTED_SHA_OK" ]]; then
      pass "$label SHA256SUMS verified ${ok_lines}/${EXPECTED_SHA_OK}"
    else
      fail "$label expected ${EXPECTED_SHA_OK} OK lines, got ${ok_lines:-0}"
    fi
  else
    fail "$label sha256sum -c SHA256SUMS failed"
    cat "$sha_out" || true
  fi
  rm -f "$sha_out"
}

verify_sha "releases/desktop-flash/${EXPECTED_RANGO_STAMP}" "130756"
if [[ -d "$CANDIDATE_DIR" ]]; then
  verify_sha "$CANDIDATE_DIR" "145117"
else
  fail "candidate stamp missing: $CANDIDATE_DIR"
fi

echo "=== Q-RANGO-BOOT-REMEDIATE case4: 145117 exists, not linked as latest ==="

if [[ -d "$CANDIDATE_DIR" ]]; then
  pass "candidate dir present: $CANDIDATE_DIR"
else
  fail "candidate dir missing"
fi
require_file "$CANDIDATE_DIR/bootloader.img" "145117 bootloader.img"
require_file "$CANDIDATE_DIR/vendor.img" "145117 vendor.img"

linked_to_candidate=0
while IFS= read -r line; do
  src="${line%% -> *}"
  dst="${line#* -> }"
  if [[ "$dst" == "$CANDIDATE_STAMP" ]]; then
    fail "symlink $src points at $CANDIDATE_STAMP (must not be latest)"
    linked_to_candidate=1
  fi
done < <(find -P releases/desktop-flash -maxdepth 1 -type l -printf '%p -> %l\n')
if [[ "$linked_to_candidate" -eq 0 ]]; then
  pass "no desktop-flash symlink targets $CANDIDATE_STAMP"
fi

pem_count="$(find -L "releases/desktop-flash/${EXPECTED_RANGO_STAMP}" "$CANDIDATE_DIR" -maxdepth 1 \( -name '*.pem' -o -name '*.pk8' \) -print | wc -l | tr -d ' ')"
if [[ "$pem_count" == "0" ]]; then
  pass "no .pem/.pk8 in 130756 or 145117"
else
  fail "found $pem_count pem/pk8 in rango stamps"
fi

if [[ -f "$STOCK_VENDOR" && -f "$CANDIDATE_DIR/vendor.img" ]]; then
  if cmp -s "$CANDIDATE_DIR/vendor.img" "$STOCK_VENDOR"; then
    pass "145117 vendor.img IDENTICAL rango-stock-userspace/vendor.img"
  else
    fail "145117 vendor.img DIFF vs rango-stock-userspace/vendor.img"
  fi
else
  hold "stock vendor donor missing — skip IDENTICAL rematch"
fi

echo "=== Q-RANGO-BOOT-REMEDIATE case5: CLI DEVICE=rango → rango-latest ==="

if [[ -f "$FLASH_ROOT" ]]; then
  pass "present: $FLASH_ROOT"
else
  fail "missing flash script $FLASH_ROOT"
fi
if [[ -f "$FLASH_VENDOR" ]]; then
  pass "present: $FLASH_VENDOR"
else
  fail "missing vendor flash script"
fi
if bash -n "$FLASH_ROOT"; then
  pass "bash -n $FLASH_ROOT"
else
  fail "bash -n $FLASH_ROOT failed"
fi

require_rg 'rango \(Pixel 10 Pro Fold\) → releases/desktop-flash/rango-latest' \
  "$FLASH_ROOT" "header maps rango → rango-latest"
require_rg 'DEVICE=tokay\|akita\|komodo\|rango' "$FLASH_ROOT" "DEVICE=rango documented"
require_rg "auto_build=\"\\\$\{REMOTE_TREE\}/releases/desktop-flash/rango-latest\"" \
  "$FLASH_ROOT" "apply_remote_paths rango → rango-latest"

# Extract helpers without executing the flash body / ssh (no USB).
eval "$(sed -n '/^normalize_device() {/,/^}$/p; /^device_pretty() {/,/^}$/p' "$FLASH_ROOT")"

nd="$(normalize_device rango)"
if [[ "$nd" == "rango" ]]; then
  pass "normalize_device rango → rango"
else
  fail "normalize_device rango → '$nd'"
fi
nd_up="$(normalize_device RANGO)"
if [[ "$nd_up" == "rango" ]]; then
  pass "normalize_device RANGO → rango"
else
  fail "normalize_device RANGO → '$nd_up'"
fi
pretty="$(device_pretty rango)"
if [[ "$pretty" == "Pixel 10 Pro Fold (rango)" ]]; then
  pass "device_pretty rango → $pretty"
else
  fail "device_pretty rango unexpected: '$pretty'"
fi

# Local mapping of apply_remote_paths case (no ssh). Confirms DEVICE=rango
# resolves to the live rango-latest symlink → 130756.
REMOTE_TREE="$ROOT"
mapped_build="${REMOTE_TREE}/releases/desktop-flash/rango-latest"
if [[ -d "$mapped_build" && -f "$mapped_build/bootloader.img" ]]; then
  pass "DEVICE=rango mapped dir has bootloader.img"
else
  fail "mapped rango-latest missing bootloader.img"
fi
mapped_tgt="$(readlink "$mapped_build")"
if [[ "$mapped_tgt" == "$EXPECTED_RANGO_STAMP" ]]; then
  pass "DEVICE=rango → rango-latest → $mapped_tgt"
else
  fail "DEVICE=rango mapping retargeted: '$mapped_tgt'"
fi

# Adversarial: Pixel 9 DEVICE must not steal rango-latest
tokay_nd="$(normalize_device tokay)"
akita_nd="$(normalize_device akita)"
komodo_nd="$(normalize_device komodo)"
if [[ "$tokay_nd" == "tokay" && "$akita_nd" == "akita" && "$komodo_nd" == "komodo" ]]; then
  pass "tokay/akita/komodo normalize stay themselves"
else
  fail "Pixel 9 normalize stolen: tokay=$tokay_nd akita=$akita_nd komodo=$komodo_nd"
fi
caiman_nd="$(normalize_device caiman)"
empty_nd="$(normalize_device "")"
unk_nd="$(normalize_device unknown)"
if [[ -z "$caiman_nd" && -z "$empty_nd" && -z "$unk_nd" ]]; then
  pass "caiman/empty/unknown DEVICE fail-closed"
else
  fail "fail-closed broken: caiman='$caiman_nd' empty='$empty_nd' unknown='$unk_nd'"
fi
if grep -q "DEVICE='\$DEVICE' not supported" "$FLASH_ROOT"; then
  pass "DEVICE override die fail-closed present"
else
  fail "missing DEVICE override fail-closed die"
fi

echo "=== Q-RANGO-BOOT-REMEDIATE case6: rango not advertised ==="

pin_no_rango_array() {
  local file="$1" needle="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    fail "missing $file"
    return
  fi
  if grep -qE -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
  if grep -E -- "$needle" "$file" | grep -q 'rango'; then
    fail "$label contains rango"
  else
    pass "$label does not include rango"
  fi
}

pin_no_rango_array "$TYPES_TS" 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo"\]' \
  "types.ts ALLOWED_PRODUCTS tokay+akita+komodo"
pin_no_rango_array "$WIZARD_TS" 'id: "tokay"|id: "akita"|id: "komodo"' \
  "wizard/devices.ts offered ids"
if grep -q 'id: "rango"' "$WIZARD_TS"; then
  fail "WIZARD_DEVICES offers rango"
else
  pass "WIZARD_DEVICES does not offer rango"
fi
pin_no_rango_array "$LATE_TS" 'TARGET_PRODUCTS: readonly string\[\] = \["tokay", "akita", "komodo"\]' \
  "late-steps TARGET_PRODUCTS tokay+akita+komodo"
if grep -q 'codename: "rango"' "$EARLY_TS"; then
  fail "SUPPORTED_TARGETS lists rango"
else
  pass "SUPPORTED_TARGETS does not list rango"
fi
require_rg 'codename: "tokay"' "$EARLY_TS" "SUPPORTED_TARGETS tokay"
require_rg 'codename: "akita"' "$EARLY_TS" "SUPPORTED_TARGETS akita"
require_rg 'codename: "komodo"' "$EARLY_TS" "SUPPORTED_TARGETS komodo"

if [[ -f "$DIST_TYPES" ]]; then
  pin_no_rango_array "$DIST_TYPES" 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo"\]' \
    "dist types.js ALLOWED_PRODUCTS"
fi
if [[ -f "$DIST_WIZARD" ]]; then
  if grep -q 'id: "rango"' "$DIST_WIZARD"; then
    fail "dist WIZARD_DEVICES offers rango"
  else
    pass "dist WIZARD_DEVICES does not offer rango"
  fi
fi
if [[ -f "$DIST_TARGET" ]]; then
  pin_no_rango_array "$DIST_TARGET" 'TARGET_PRODUCTS = \["tokay", "akita", "komodo"\]' \
    "dist TARGET_PRODUCTS"
fi
if [[ -f "$DIST_EARLY" ]]; then
  if grep -q 'codename: "rango"' "$DIST_EARLY"; then
    fail "dist SUPPORTED_TARGETS lists rango"
  else
    pass "dist SUPPORTED_TARGETS does not list rango as production"
  fi
fi

echo "=== Q-RANGO-BOOT-REMEDIATE case7: USB HOLD (do not invent boot PASS) ==="

if command -v adb >/dev/null 2>&1; then
  adb_out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "${adb_out}" ]]; then
    hold "adb device(s) present: ${adb_out} — this card does not flash; no boot PASS"
  else
    hold "adb devices empty — USB HOLD; no boot PASS"
  fi
else
  hold "adb missing — USB HOLD; no boot PASS"
fi
if command -v fastboot >/dev/null 2>&1; then
  hold "fastboot present but unused — no live flash this card"
else
  hold "fastboot missing — USB HOLD; no boot PASS"
fi

echo ""
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  exit 0
fi
echo "STATIC CHECKS FAILED"
exit 1
