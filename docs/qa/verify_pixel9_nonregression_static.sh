#!/usr/bin/env bash
# Static + host rematch for Q-PIXEL9-NONREGRESSION.
# Independent of Backend claims. No USB. Does not execute flash-from-remote.sh body.
# Does not relink latest stamps.
#
# Cases:
#   1. tokay→latest (tokay-20260725-102506 inode 193110379)
#      akita→akita-latest (inode 193110357)
#      komodo→komodo-latest (inode 193110380)
#   2. KEEP both flash-from-remote.sh copies identical; bash -n 0
#   3. DEVICE= mapping: tokay/akita/komodo → those stamps; no rescue dir
#   4. firmware cleanup uart + erase fips + dpm for those three
#   5. no flash_rango_rescue / rescue boot on those three
#   6. wrong DEVICE= fail-closed
#   7. no rango advertise (ALLOWED_PRODUCTS / SUPPORTED_TARGETS)
#   8. USB HOLD (do not invent PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_pixel9_nonregression_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

FLASH_ROOT="scripts/flash-from-remote.sh"
FLASH_VENDOR="vendor/guardtalk/scripts/flash-from-remote.sh"
TOKAY_LATEST="releases/desktop-flash/latest"
AKITA_LATEST="releases/desktop-flash/akita-latest"
KOMODO_LATEST="releases/desktop-flash/komodo-latest"
RANGO_LATEST="releases/desktop-flash/rango-latest"
EXPECTED_TOKAY_STAMP="tokay-20260725-102506"
EXPECTED_TOKAY_INODE="193110379"
EXPECTED_AKITA_INODE="193110357"
EXPECTED_KOMODO_INODE="193110380"
WI_TYPES="vendor/guardtalk/web-installer/src/types.ts"
WI_EARLY="vendor/guardtalk/web-installer/routes/install/early-steps.ts"
WI_DIST_TYPES="vendor/guardtalk/web-installer/dist/src/types.js"
WI_DIST_EARLY="vendor/guardtalk/web-installer/dist/site/install/early-steps.js"

extract_fn() {
  local name="$1" file="$2"
  awk -v n="$name" '
    $0 ~ "^" n "\\(\\) \\{" {c=1}
    c {print}
    c && /^}$/ {exit}
  ' "$file"
}

require_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && grep -Eq -- "$pat" "$file"; then
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
  if grep -Eq -- "$pat" "$file"; then
    fail "$label (forbidden pattern present in $file)"
  else
    pass "$label"
  fi
}

HELPERS="$(mktemp)"
{
  echo 'log()  { echo "[flash] $*" >&2; }'
  echo 'warn() { echo "[flash] WARNING: $*" >&2; }'
  echo 'die()  { echo "[flash] FATAL: $*" >&2; exit 1; }'
  extract_fn normalize_device "$FLASH_ROOT"
  extract_fn device_pretty "$FLASH_ROOT"
  extract_fn apply_remote_paths "$FLASH_ROOT"
  extract_fn apply_grapheneos_firmware_cleanup "$FLASH_ROOT"
} >"$HELPERS"
# shellcheck disable=SC1090
source "$HELPERS"

WORKDIR="$(mktemp -d)"
trap 'rm -f "$HELPERS"; rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR/bin"
FB_LOG="$WORKDIR/fb.log"
SSH_LOG="$WORKDIR/ssh.log"
export FB_LOG SSH_LOG FLASH_DEVICE LOCAL_WORK_DIR
export REMOTE_TREE="$ROOT"
export REMOTE_HOST="qa-stub-host"

cat >"$WORKDIR/bin/fastboot" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${FB_LOG:?}"
exit 0
EOF
chmod +x "$WORKDIR/bin/fastboot"

cat >"$WORKDIR/bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${SSH_LOG:?}"
exit 0
EOF
chmod +x "$WORKDIR/bin/ssh"
export PATH="$WORKDIR/bin:$PATH"
export FASTBOOT="$WORKDIR/bin/fastboot"

echo "=== Q-PIXEL9-NONREGRESSION case1: latest stamps + Architect inode pins ==="

if [[ -L "$TOKAY_LATEST" ]]; then
  tokay_tgt="$(readlink "$TOKAY_LATEST")"
  if [[ "$tokay_tgt" == "$EXPECTED_TOKAY_STAMP" ]]; then
    pass "latest → $tokay_tgt"
  else
    fail "latest expected $EXPECTED_TOKAY_STAMP, got $tokay_tgt"
  fi
else
  fail "latest is not a symlink"
fi

akita_tgt="$(readlink "$AKITA_LATEST" 2>/dev/null || true)"
komodo_tgt="$(readlink "$KOMODO_LATEST" 2>/dev/null || true)"
if [[ -L "$AKITA_LATEST" && "$akita_tgt" == akita-* ]]; then
  pass "akita-latest → $akita_tgt"
else
  fail "akita-latest expected akita-* symlink, got '$akita_tgt'"
fi
if [[ -L "$KOMODO_LATEST" && "$komodo_tgt" == komodo-* ]]; then
  pass "komodo-latest → $komodo_tgt"
else
  fail "komodo-latest expected komodo-* symlink, got '$komodo_tgt'"
fi

tokay_inode="$(stat -c%i "$TOKAY_LATEST")"
akita_inode="$(stat -c%i "$AKITA_LATEST")"
komodo_inode="$(stat -c%i "$KOMODO_LATEST")"
if [[ "$tokay_inode" == "$EXPECTED_TOKAY_INODE" ]]; then
  pass "latest inode $tokay_inode"
else
  fail "latest inode expected $EXPECTED_TOKAY_INODE got $tokay_inode"
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

if [[ -d "releases/desktop-flash/$EXPECTED_TOKAY_STAMP" ]]; then
  pass "tokay stamp dir present: $EXPECTED_TOKAY_STAMP"
else
  fail "tokay stamp dir missing: $EXPECTED_TOKAY_STAMP"
fi
if [[ -n "$akita_tgt" && -d "releases/desktop-flash/$akita_tgt" ]]; then
  pass "akita stamp dir present: $akita_tgt"
else
  fail "akita stamp dir missing: $akita_tgt"
fi
if [[ -n "$komodo_tgt" && -d "releases/desktop-flash/$komodo_tgt" ]]; then
  pass "komodo stamp dir present: $komodo_tgt"
else
  fail "komodo stamp dir missing: $komodo_tgt"
fi

if [[ "$tokay_tgt" != "$akita_tgt" && "$tokay_tgt" != "$komodo_tgt" && "$akita_tgt" != "$komodo_tgt" ]]; then
  pass "tokay/akita/komodo latest stamps are distinct"
else
  fail "Pixel 9-family latest stamps collide ($tokay_tgt / $akita_tgt / $komodo_tgt)"
fi

rango_tgt="$(readlink "$RANGO_LATEST" 2>/dev/null || true)"
if [[ "$rango_tgt" == "rango-20260802-130756" ]]; then
  pass "rango-latest still $rango_tgt (Pixel 9 stamps not stolen)"
else
  fail "rango-latest unexpected: '$rango_tgt' (must stay 130756; Pixel 9 non-regression)"
fi
if [[ "$tokay_tgt" != "$rango_tgt" && "$akita_tgt" != "$rango_tgt" && "$komodo_tgt" != "$rango_tgt" ]]; then
  pass "Pixel 9 latest stamps distinct from rango-latest"
else
  fail "a Pixel 9 latest stamp collides with rango-latest"
fi

echo "=== Q-PIXEL9-NONREGRESSION case2: KEEP flash-from-remote.sh identical ==="

if cmp -s "$FLASH_ROOT" "$FLASH_VENDOR"; then
  pass "cmp scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh"
else
  fail "flash-from-remote.sh copies DIFF"
fi
root_sha="$(sha256sum "$FLASH_ROOT" | awk '{print $1}')"
vendor_sha="$(sha256sum "$FLASH_VENDOR" | awk '{print $1}')"
if [[ "$root_sha" == "$vendor_sha" ]]; then
  pass "SHA256 both copies $root_sha"
else
  fail "SHA256 mismatch root=$root_sha vendor=$vendor_sha"
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

echo "=== Q-PIXEL9-NONREGRESSION case3: DEVICE= maps to latest stamps; no rescue dir ==="

expect_map() {
  local codename="$1" suffix="$2"
  REMOTE_BUILD_DIR=""
  REMOTE_KEY_DIR=""
  REMOTE_RESCUE_DIR=""
  : >"$SSH_LOG"
  if ! apply_remote_paths "$codename"; then
    fail "apply_remote_paths $codename died"
    return
  fi
  if [[ "$REMOTE_BUILD_DIR" == "$ROOT/releases/desktop-flash/$suffix" ]]; then
    pass "DEVICE=$codename → $suffix"
  else
    fail "DEVICE=$codename expected .../$suffix got $REMOTE_BUILD_DIR"
  fi
  if [[ "$REMOTE_KEY_DIR" == "$ROOT/releases/desktop-flash/$suffix" ]]; then
    pass "DEVICE=$codename KEY_DIR → $suffix"
  else
    fail "DEVICE=$codename KEY_DIR unexpected: $REMOTE_KEY_DIR"
  fi
  if [[ -z "${REMOTE_RESCUE_DIR:-}" ]]; then
    pass "DEVICE=$codename does not set REMOTE_RESCUE_DIR"
  else
    fail "DEVICE=$codename set REMOTE_RESCUE_DIR=$REMOTE_RESCUE_DIR (Pixel 9 must not)"
  fi
}

expect_map tokay latest
expect_map akita akita-latest
expect_map komodo komodo-latest

pretty_tokay="$(device_pretty tokay)"
pretty_akita="$(device_pretty akita)"
pretty_komodo="$(device_pretty komodo)"
[[ "$pretty_tokay" == "Pixel 9 (tokay)" ]] && pass "device_pretty tokay" || fail "device_pretty tokay='$pretty_tokay'"
[[ "$pretty_akita" == "Pixel 8a (akita)" ]] && pass "device_pretty akita" || fail "device_pretty akita='$pretty_akita'"
[[ "$pretty_komodo" == "Pixel 9 Pro XL (komodo)" ]] && pass "device_pretty komodo" || fail "device_pretty komodo='$pretty_komodo'"

nd_tokay="$(normalize_device tokay)"
nd_akita="$(normalize_device akita)"
nd_komodo="$(normalize_device komodo)"
[[ "$nd_tokay" == "tokay" ]] && pass "normalize_device tokay" || fail "normalize_device tokay='$nd_tokay'"
[[ "$nd_akita" == "akita" ]] && pass "normalize_device akita" || fail "normalize_device akita='$nd_akita'"
[[ "$nd_komodo" == "komodo" ]] && pass "normalize_device komodo" || fail "normalize_device komodo='$nd_komodo'"

echo "=== Q-PIXEL9-NONREGRESSION case4: uart + erase fips + dpm for tokay/akita/komodo ==="

require_rg 'tokay\|akita\|komodo' "$FLASH_ROOT" "firmware cleanup case tokay|akita|komodo"
require_rg 'erase fips' "$FLASH_ROOT" "erase fips present in CLI"

cleanup_ok() {
  local codename="$1"
  : >"$FB_LOG"
  FLASH_DEVICE="$codename"
  if apply_grapheneos_firmware_cleanup; then
    if grep -qx 'oem uart disable' "$FB_LOG" \
      && grep -qx 'erase fips' "$FB_LOG" \
      && grep -qx 'erase dpm_a' "$FB_LOG" \
      && grep -qx 'erase dpm_b' "$FB_LOG"; then
      pass "$codename cleanup: uart + erase fips + dpm_a/dpm_b"
    else
      fail "$codename cleanup missing uart/fips/dpm (log=$(tr '\n' '|' <"$FB_LOG"))"
    fi
  else
    fail "$codename apply_grapheneos_firmware_cleanup died"
  fi
}
cleanup_ok tokay
cleanup_ok akita
cleanup_ok komodo

echo "=== Q-PIXEL9-NONREGRESSION case5: no rescue boot on tokay/akita/komodo ==="

awk '
  /^# rango: NEVER try the on-device boot chain first/ {p=1}
  p && /^else$/ {e=1; next}
  e {print}
  e && /^fi$/ {exit}
' "$FLASH_ROOT" >"$WORKDIR/rescue_else.txt"
if grep -q 'flash_rango_rescue_boot_chain' "$WORKDIR/rescue_else.txt"; then
  fail "Pixel 9 else-branch calls flash_rango_rescue_boot_chain"
else
  pass "Pixel 9 else-branch has no flash_rango_rescue_boot_chain"
fi
if grep -q 'using boot chain currently on device' "$WORKDIR/rescue_else.txt"; then
  pass "Pixel 9 else-branch uses on-device boot chain (no rescue)"
else
  fail "Pixel 9 else-branch missing on-device boot-chain path"
fi

if awk '
  /^if \[\[ "\$\{FLASH_DEVICE:-\}" == "rango" \]\]; then/ {p=1}
  p {print}
  p && /^else$/ {exit}
' "$FLASH_ROOT" | grep -q 'flash_rango_rescue_boot_chain'; then
  pass "flash_rango_rescue_boot_chain production call stays inside FLASH_DEVICE==rango"
else
  fail "rango production rescue call missing (Pixel 9 isolation unprovable)"
fi

# Call sites besides the function definition.
call_lines="$(grep -n 'flash_rango_rescue_boot_chain' "$FLASH_ROOT" | grep -v '()' || true)"
if echo "$call_lines" | grep -q 'flash_rango_rescue_boot_chain'; then
  pass "rescue function still referenced (definition + rango call sites)"
else
  fail "flash_rango_rescue_boot_chain vanished"
fi
# Harvest pstore rescue profile (auto_harvest_on_failure) must not include tokay/komodo.
if grep -F 'akita|rango' "$FLASH_ROOT" | grep -q 'akita|rango'; then
  pass "harvest profile still akita|rango (pstore only; not Pixel 9 production rescue)"
else
  fail "harvest akita|rango profile missing"
fi
if awk '/# 2. Ramoops/,/^    esac/' "$FLASH_ROOT" | grep -Eq 'tokay|komodo'; then
  fail "tokay/komodo present in ramoops harvest case (must stay akita|rango)"
else
  pass "tokay/komodo absent from ramoops harvest case"
fi

echo "=== Q-PIXEL9-NONREGRESSION case6: wrong DEVICE= fail-closed ==="

for bad in "" unknown caiman shiba husky pixel9 mustang blazer frankel PIXEL9; do
  got="$(normalize_device "$bad")"
  if [[ -z "$got" ]]; then
    pass "normalize_device $(printf '%q' "$bad") → empty (fail-closed)"
  else
    fail "normalize_device $(printf '%q' "$bad") mapped to '$got' (must fail-closed)"
  fi
done
# Documented fallback (not a FAIL this card): casefold Tokay→tokay; substring komodo-xl→komodo.
tokay_casefold="$(normalize_device Tokay)"
komodo_sub="$(normalize_device komodo-xl)"
if [[ "$tokay_casefold" == "tokay" ]]; then
  pass "normalize_device Tokay casefolds to tokay (existing fallback)"
else
  fail "normalize_device Tokay unexpected: '$tokay_casefold'"
fi
if [[ "$komodo_sub" == "komodo" ]]; then
  pass "normalize_device komodo-xl substring-maps to komodo (existing fallback; documented gap)"
else
  fail "normalize_device komodo-xl unexpected: '$komodo_sub'"
fi

# Substring trap: caiman must not become tokay/akita/komodo via fallback.
if [[ -z "$(normalize_device caiman)" ]]; then
  pass "caiman is not mapped onto Pixel 9 family"
else
  fail "caiman leaked onto a supported codename"
fi

if grep -q "DEVICE='\$DEVICE' not supported" "$FLASH_ROOT"; then
  pass "DEVICE override die fail-closed present"
else
  fail "missing DEVICE override fail-closed die"
fi

if grep -q "Unsupported device codename" "$FLASH_ROOT"; then
  pass "apply_remote_paths unsupported-codename die present"
else
  fail "missing apply_remote_paths unsupported die"
fi

REMOTE_BUILD_DIR=""
REMOTE_KEY_DIR=""
REMOTE_RESCUE_DIR=""
# die() calls exit — must run in a subshell so the suite continues.
if ( apply_remote_paths "caiman" ) >/dev/null 2>"$WORKDIR/caiman.err"; then
  fail "apply_remote_paths caiman succeeded (must die)"
else
  if grep -q "Unsupported device codename 'caiman'" "$WORKDIR/caiman.err"; then
    pass "apply_remote_paths caiman dies fail-closed"
  else
    fail "apply_remote_paths caiman died without unsupported-codename message"
  fi
fi

echo "=== Q-PIXEL9-NONREGRESSION case7: no rango advertise ==="

if grep -Eq 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo"\]' "$WI_TYPES"; then
  pass "ALLOWED_PRODUCTS source = tokay, akita, komodo"
else
  fail "ALLOWED_PRODUCTS source unexpected ($WI_TYPES)"
fi
forbid_rg 'rango' "$WI_TYPES" "no rango in ALLOWED_PRODUCTS source"
if grep -q 'codename: "tokay"' "$WI_EARLY" \
  && grep -q 'codename: "akita"' "$WI_EARLY" \
  && grep -q 'codename: "komodo"' "$WI_EARLY"; then
  pass "SUPPORTED_TARGETS lists tokay+akita+komodo"
else
  fail "SUPPORTED_TARGETS missing a Pixel 9-family advertised device"
fi
if grep -E 'codename: "rango"' "$WI_EARLY"; then
  fail "SUPPORTED_TARGETS source advertises rango"
else
  pass "SUPPORTED_TARGETS source has no rango row"
fi
if [[ -f "$WI_DIST_TYPES" ]] && grep -Eq 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo"\]' "$WI_DIST_TYPES"; then
  pass "dist ALLOWED_PRODUCTS = tokay, akita, komodo"
else
  fail "dist ALLOWED_PRODUCTS unexpected ($WI_DIST_TYPES)"
fi
if [[ -f "$WI_DIST_EARLY" ]] && grep -q 'codename: "rango"' "$WI_DIST_EARLY" && grep -A1 'codename: "rango"' "$WI_DIST_EARLY" | grep -q 'supported'; then
  fail "dist SUPPORTED_TARGETS advertises rango as supported"
else
  pass "dist early-steps does not advertise rango as supported"
fi

echo "=== Q-PIXEL9-NONREGRESSION case8: USB HOLD ==="

if command -v adb >/dev/null 2>&1; then
  adb_out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "$adb_out" ]]; then
    hold "adb device(s) present but USB flash NOT executed (dispatch: USB HOLD)"
  else
    hold "adb present but no device — USB E2E HOLD (not invent PASS)"
  fi
else
  hold "adb binary unavailable — USB E2E HOLD"
fi
hold "no live flash_rango_rescue / rescue-boot executed (dispatch: USB HOLD)"

echo ""
echo "=== Q-PIXEL9-NONREGRESSION static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
