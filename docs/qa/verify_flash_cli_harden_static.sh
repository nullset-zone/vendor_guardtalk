#!/usr/bin/env bash
# Static + host-function rematch for Q-FLASH-CLI-HARDEN.
# Independent of Backend claims. No USB. Does not execute flash-from-remote.sh body.
#
# Cases:
#   1. KEEP copies cmp identical; bash -n both EXIT=0
#   2. require_fastboot_min_version: ≥35.0.1 accept; <35.0.1 and unparseable die
#   3. avb_custom_key flash fail → die unless ALLOW_AVB_KEY_FAIL=1
#   4. REMOTE_BUILD_DIR metacharacters (' " $ \ newline) rejected before ssh
#   5. apply_grapheneos_firmware_cleanup: tokay|akita|komodo erase fips; rango no fips
#   6. rescue boot call still rango-only (Pixel 9 else-branch has no rescue)
#   7. no flashing lock / update image.zip as default
#   8. dead inner avb_pkmd.bin branch gone; optional super/diag still skip-ok
#   9. golden-file command-order prefix vs generate-factory-images-common.sh
#  10. USB / overlay HOLD (do not invent PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_flash_cli_harden_static.sh
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
GOS_GEN="device/common/generate-factory-images-common.sh"
GOS_REL="script/generate-release.sh"

extract_fn() {
  local name="$1" file="$2"
  awk -v n="$name" '
    $0 ~ "^" n "\\(\\) \\{" {c=1}
    c {print}
    c && /^}$/ {exit}
  ' "$file"
}

# Helpers + isolated functions from the product script (no USB body).
HELPERS="$(mktemp)"
{
  echo 'log()  { echo "[flash] $*" >&2; }'
  echo 'warn() { echo "[flash] WARNING: $*" >&2; }'
  echo 'die()  { echo "[flash] FATAL: $*" >&2; exit 1; }'
  extract_fn require_fastboot_min_version "$FLASH_ROOT"
  extract_fn apply_remote_paths "$FLASH_ROOT"
  extract_fn apply_grapheneos_firmware_cleanup "$FLASH_ROOT"
  extract_fn flash_bootloader_ab_both_slots "$FLASH_ROOT"
} >"$HELPERS"
# shellcheck disable=SC1090
source "$HELPERS"
wait_for_fastboot() { return 0; }

WORKDIR="$(mktemp -d)"
trap 'rm -f "$HELPERS"; rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR/bin"
FB_LOG="$WORKDIR/fb.log"
SSH_LOG="$WORKDIR/ssh.log"
export FB_LOG SSH_LOG FB_VERSION_LINE FAIL_FLASH_AVB ALLOW_AVB_KEY_FAIL FLASH_DEVICE LOCAL_WORK_DIR
export FASTBOOT_WAIT_SECS=1 FASTBOOTD_WAIT_SECS=1

cat >"$WORKDIR/bin/fastboot" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${FB_LOG:?}"
if [[ "${1:-}" == "--version" ]]; then
  printf '%s\n' "${FB_VERSION_LINE-fastboot version 35.0.1-qa}"
  exit 0
fi
if [[ "${FAIL_FLASH_AVB:-0}" == "1" && " $* " == *" flash avb_custom_key "* ]]; then
  echo "FAILED (remote: no such partition?)" >&2
  exit 1
fi
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

normalize_fb_line() {
  local -a in=() out=() t
  # shellcheck disable=SC2206
  in=($1)
  for t in "${in[@]}"; do
    if [[ "$t" == */* || "$t" == *.img || "$t" == *.bin ]]; then
      continue
    fi
    out+=("$t")
  done
  printf '%s\n' "${out[*]}"
}

run_step2_prefix() {
  local codename="$1"
  local out="$2"
  : >"$FB_LOG"
  FLASH_DEVICE="$codename"
  LOCAL_WORK_DIR="$WORKDIR/imgs"
  mkdir -p "$LOCAL_WORK_DIR"
  : >"$LOCAL_WORK_DIR/bootloader.img"
  : >"$LOCAL_WORK_DIR/radio.img"
  : >"$LOCAL_WORK_DIR/avb_pkmd.bin"
  FAIL_FLASH_AVB=0
  ALLOW_AVB_KEY_FAIL="${ALLOW_AVB_KEY_FAIL:-0}"
  flash_bootloader_ab_both_slots
  "$FASTBOOT" flash radio "$LOCAL_WORK_DIR/radio.img"
  "$FASTBOOT" reboot-bootloader
  wait_for_fastboot "after radio" 1
  [[ -f "$LOCAL_WORK_DIR/avb_pkmd.bin" ]] || die "avb_pkmd.bin missing"
  "$FASTBOOT" erase avb_custom_key || warn "erase avb_custom_key failed"
  if "$FASTBOOT" flash avb_custom_key "$LOCAL_WORK_DIR/avb_pkmd.bin"; then
    :
  else
    if [[ "${ALLOW_AVB_KEY_FAIL:-0}" == "1" ]]; then
      warn "ALLOW_AVB_KEY_FAIL=1"
    else
      die "avb_custom_key flash FAILED"
    fi
  fi
  apply_grapheneos_firmware_cleanup
  : >"$out"
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    normalize_fb_line "$line" >>"$out"
  done <"$FB_LOG"
}

write_expected() {
  local kind="$1" dest="$2"
  cat >"$dest" <<'EOF'
flash --slot=other bootloader
--set-active=other
reboot-bootloader
flash --slot=other bootloader
--set-active=other
reboot-bootloader
flash radio
reboot-bootloader
erase avb_custom_key
flash avb_custom_key
oem uart disable
EOF
  if [[ "$kind" != "rango" ]]; then
    echo "erase fips" >>"$dest"
  fi
  echo "erase dpm_a" >>"$dest"
  echo "erase dpm_b" >>"$dest"
}

echo "=== Q-FLASH-CLI-HARDEN case1: KEEP copies cmp + bash -n ==="

if [[ -f "$FLASH_ROOT" && -f "$FLASH_VENDOR" ]]; then
  pass "both flash-from-remote.sh present"
else
  fail "missing KEEP copy ($FLASH_ROOT or $FLASH_VENDOR)"
fi
if cmp -s "$FLASH_ROOT" "$FLASH_VENDOR"; then
  pass "cmp KEEP pair IDENTICAL"
else
  fail "KEEP pair DIFF (scripts/ vs vendor/guardtalk/scripts/)"
fi
if bash -n "$FLASH_ROOT"; then
  pass "bash -n $FLASH_ROOT EXIT=0"
else
  fail "bash -n $FLASH_ROOT failed"
fi
if bash -n "$FLASH_VENDOR"; then
  pass "bash -n $FLASH_VENDOR EXIT=0"
else
  fail "bash -n $FLASH_VENDOR failed"
fi

echo "=== Q-FLASH-CLI-HARDEN case2: fastboot ≥ 35.0.1 (MEDIUM-1) ==="

expect_fb_ok() {
  local line="$1" label="$2"
  export FB_VERSION_LINE="$line"
  if ( require_fastboot_min_version ) >/dev/null 2>&1; then
    pass "fastboot accept: $label"
  else
    fail "fastboot should accept: $label ($line)"
  fi
}
expect_fb_die() {
  local line="$1" label="$2"
  export FB_VERSION_LINE="$line"
  if ( require_fastboot_min_version ) >/dev/null 2>&1; then
    fail "fastboot should die: $label ($line)"
  else
    pass "fastboot die: $label"
  fi
}

expect_fb_ok "fastboot version 35.0.1-qa" "35.0.1"
expect_fb_ok "fastboot version 36.0.0" "36.0.0"
expect_fb_ok "fastboot version 35.0.2" "35.0.2"
expect_fb_die "fastboot version 35.0.0" "35.0.0"
expect_fb_die "fastboot version 34.0.5" "34.0.5"
expect_fb_die "fastboot version 35.0" "35.0 (patch defaults 0 → below min)"
expect_fb_die "fastboot: unknown" "unparseable"
expect_fb_die "" "empty version line"

if grep -q 'MIN_FASTBOOT_VERSION_STR="35.0.1"' "$GOS_GEN"; then
  pass "GOS generator MIN_FASTBOOT_VERSION_STR=35.0.1 ($GOS_GEN)"
else
  fail "GOS generator missing MIN_FASTBOOT_VERSION_STR=35.0.1"
fi

echo "=== Q-FLASH-CLI-HARDEN case3: avb_custom_key die unless ALLOW_AVB_KEY_FAIL=1 ==="

AVB_SNIP="$WORKDIR/avb_snip.sh"
awk '
  /# AVB custom key — official position/ {p=1}
  p && /^apply_grapheneos_firmware_cleanup$/ {exit}
  p {print}
' "$FLASH_ROOT" >"$AVB_SNIP"
if grep -q 'ALLOW_AVB_KEY_FAIL' "$AVB_SNIP" && grep -q 'die "avb_custom_key flash FAILED' "$AVB_SNIP"; then
  pass "avb snippet extracted (fail-closed die present)"
else
  fail "could not extract avb fail-closed snippet"
fi

run_avb() {
  local allow="$1"
  export ALLOW_AVB_KEY_FAIL="$allow"
  export FAIL_FLASH_AVB=1
  export LOCAL_WORK_DIR="$WORKDIR/imgs"
  mkdir -p "$LOCAL_WORK_DIR"
  : >"$LOCAL_WORK_DIR/avb_pkmd.bin"
  : >"$FB_LOG"
  # shellcheck disable=SC1090
  source "$AVB_SNIP"
}

if ( run_avb 0 ) >/dev/null 2>&1; then
  fail "avb_custom_key fail with ALLOW unset should die"
else
  pass "avb_custom_key fail → die (ALLOW unset / 0)"
fi
if ( run_avb 1 ) >/dev/null 2>&1; then
  pass "avb_custom_key fail + ALLOW_AVB_KEY_FAIL=1 continues"
else
  fail "ALLOW_AVB_KEY_FAIL=1 should continue"
fi

echo "=== Q-FLASH-CLI-HARDEN case4: REMOTE_BUILD_DIR sanitizer before ssh ==="

REMOTE_TREE="/tmp/gt-qa-harden-tree"
REMOTE_HOST="qa@invalid"
: >"$SSH_LOG"

expect_path_ok() {
  local p="$1" label="$2"
  : >"$SSH_LOG"
  REMOTE_BUILD_DIR="$p"
  REMOTE_KEY_DIR="$p"
  if ( apply_remote_paths tokay ) >/dev/null 2>&1; then
    if [[ -s "$SSH_LOG" ]]; then
      pass "sanitizer allows: $label"
    else
      fail "sanitizer allowed $label but ssh was not reached"
    fi
  else
    fail "sanitizer should allow: $label ($p)"
  fi
}
expect_path_die() {
  local p="$1" label="$2"
  : >"$SSH_LOG"
  REMOTE_BUILD_DIR="$p"
  REMOTE_KEY_DIR="$p"
  if ( apply_remote_paths tokay ) >/dev/null 2>&1; then
    fail "sanitizer should reject: $label"
  else
    if [[ -s "$SSH_LOG" ]]; then
      fail "ssh reached before reject: $label"
    else
      pass "sanitizer rejects before ssh: $label"
    fi
  fi
}

expect_path_ok "/tmp/gt-qa-harden-tree/ok" "clean absolute path"
expect_path_die "relative/no/slash" "non-absolute"
expect_path_die "/tmp/gt-qa-harden-tree/o'k" "single quote"
expect_path_die '/tmp/gt-qa-harden-tree/o"k' "double quote"
expect_path_die '/tmp/gt-qa-harden-tree/o$k' 'dollar'
expect_path_die '/tmp/gt-qa-harden-tree/o\k' "backslash"
newline_path=$'/tmp/gt-qa-harden-tree/o\nk'
expect_path_die "$newline_path" "newline"

echo "=== Q-FLASH-CLI-HARDEN case5: firmware cleanup fips matrix ==="

for d in tokay akita komodo; do
  : >"$FB_LOG"
  FLASH_DEVICE="$d"
  if ( apply_grapheneos_firmware_cleanup ) >/dev/null 2>&1; then
    if grep -qx 'erase fips' "$FB_LOG" \
      && grep -qx 'oem uart disable' "$FB_LOG" \
      && grep -qx 'erase dpm_a' "$FB_LOG" \
      && grep -qx 'erase dpm_b' "$FB_LOG"; then
      pass "$d cleanup: uart + erase fips + dpm_a/dpm_b"
    else
      fail "$d cleanup missing uart/fips/dpm (log=$(tr '\n' '|' <"$FB_LOG"))"
    fi
  else
    fail "$d apply_grapheneos_firmware_cleanup died"
  fi
done

: >"$FB_LOG"
FLASH_DEVICE=rango
if ( apply_grapheneos_firmware_cleanup ) >/dev/null 2>&1; then
  if grep -qx 'erase fips' "$FB_LOG"; then
    fail "rango cleanup must NOT erase fips"
  elif grep -qx 'oem uart disable' "$FB_LOG" \
    && grep -qx 'erase dpm_a' "$FB_LOG" \
    && grep -qx 'erase dpm_b' "$FB_LOG"; then
    pass "rango cleanup: uart + dpm, no fips"
  else
    fail "rango cleanup missing uart/dpm (log=$(tr '\n' '|' <"$FB_LOG"))"
  fi
else
  fail "rango apply_grapheneos_firmware_cleanup died"
fi

if grep -Eq 'DEVICE == @\(stallion\|tegu\|comet\|komodo\|caiman\|tokay\|akita' "$GOS_REL" \
  && grep -A4 'DEVICE == @(stallion|tegu|comet|komodo|caiman|tokay|akita' "$GOS_REL" \
    | grep -q 'DISABLE_FIPS=true'; then
  pass "generate-release.sh Pixel 6–9 family DISABLE_FIPS=true"
else
  fail "generate-release.sh Pixel 6–9 DISABLE_FIPS missing"
fi
if grep -Eq 'DEVICE == @\(rango\|mustang\|blazer\|frankel\)' "$GOS_REL"; then
  rango_block="$(awk '/DEVICE == @\(rango\|mustang\|blazer\|frankel\)/,/^elif/' "$GOS_REL")"
  if grep -q 'DISABLE_FIPS' <<<"$rango_block"; then
    fail "generate-release.sh rango family unexpectedly sets DISABLE_FIPS"
  else
    pass "generate-release.sh rango family has no DISABLE_FIPS"
  fi
else
  fail "generate-release.sh rango family block missing"
fi

echo "=== Q-FLASH-CLI-HARDEN case6: rescue still rango-only ==="

# Production fastbootd-entry rescue (not harvest) must be inside FLASH_DEVICE==rango.
awk '
  /^# rango: NEVER try the on-device boot chain first/ {p=1}
  p {print}
  p && /^# -----/ {exit}
' "$FLASH_ROOT" >"$WORKDIR/rescue_block.txt"
if grep -q 'flash_rango_rescue_boot_chain' "$WORKDIR/rescue_block.txt" \
  && grep -q 'FLASH_DEVICE:-}" == "rango"' "$FLASH_ROOT"; then
  pass "flash_rango_rescue_boot_chain called in rango production branch"
else
  fail "rango production rescue call missing"
fi
# Pixel 9 else-branch between rescue if and step 5 must not call rescue.
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
# Only production call site besides definition + harvest.
prod_calls="$(grep -n 'flash_rango_rescue_boot_chain' "$FLASH_ROOT" | grep -v '()' || true)"
if echo "$prod_calls" | grep -q 'flash_rango_rescue_boot_chain'; then
  pass "rescue function referenced (definition + call sites present)"
else
  fail "flash_rango_rescue_boot_chain vanished"
fi

echo "=== Q-FLASH-CLI-HARDEN case7: no flashing lock / update image.zip default ==="

if grep -nE 'flashing[[:space:]]+lock' "$FLASH_ROOT"; then
  fail "flashing lock present in flash-from-remote.sh (forbidden default)"
else
  pass "no 'flashing lock' in flash-from-remote.sh"
fi
if grep -nE -- '--skip-reboot[[:space:]]+update|update image-.*\.zip' "$FLASH_ROOT"; then
  fail "GOS update image.zip present as default flash path"
else
  pass "no 'update image.zip' default (GuardTalk delta kept)"
fi

echo "=== Q-FLASH-CLI-HARDEN case8: dead inner avb_pkmd.bin branch removed ==="

# Optional super/diag block must not nest avb_pkmd.bin.
opt_block="$(awk '
  /super\.img" \|\| "\$f" == "vendor_boot_diag\.img"/ {p=1}
  p && /elif \[\[ "\$f" == "avb_pkmd\.bin" \]\]/ {exit}
  p {print}
' "$FLASH_ROOT")"
if grep -q 'avb_pkmd.bin' <<<"$opt_block"; then
  fail "avb_pkmd.bin still nested inside optional super/diag branch"
else
  pass "optional super/diag block has no inner avb_pkmd.bin"
fi
if grep -A2 'elif \[\[ "$f" == "avb_pkmd.bin" \]\]' "$FLASH_ROOT" | grep -q 'REMOTE_KEY_DIR'; then
  pass "avb_pkmd.bin is sibling elif (required, KEY_DIR, die on miss)"
else
  fail "avb_pkmd.bin required elif missing"
fi
if grep -q 'optional $f not on server — skipping' "$FLASH_ROOT"; then
  pass "optional super/diag still skip-ok"
else
  fail "optional skip-ok warn missing"
fi

echo "=== Q-FLASH-CLI-HARDEN case9: golden-file prefix vs generate-factory-images-common.sh ==="

# Prove GOS generator still emits the prefix tokens in order (unix flash-all.sh).
require_gos_order() {
  local prev=0 tok
  for tok in \
    'flash --slot=other bootloader' \
    '--set-active=other' \
    'reboot-bootloader' \
    'flash radio' \
    'erase avb_custom_key' \
    'flash avb_custom_key' \
    'oem uart disable' \
    'erase fips' \
    'erase dpm_a' \
    'erase dpm_b'; do
    local n
    n="$(grep -n -F -- "$tok" "$GOS_GEN" | head -1 | cut -d: -f1)"
    if [[ -z "$n" ]]; then
      fail "GOS generator missing token: $tok"
      return
    fi
    if (( n < prev )); then
      fail "GOS generator order broke: $tok at $n after $prev"
      return
    fi
    prev=$n
  done
  pass "GOS generator unix prefix tokens in order (bootloader/radio/avb/uart/fips/dpm)"
}
require_gos_order

# GOS update-zip is AFTER dpm — documented delta, not part of this prefix match.
update_line="$(grep -n 'fastboot -w --skip-reboot update' "$GOS_GEN" | head -1 | cut -d: -f1)"
dpm_line="$(grep -n 'fastboot erase dpm_b' "$GOS_GEN" | head -1 | cut -d: -f1)"
if [[ -n "$update_line" && -n "$dpm_line" && "$update_line" -gt "$dpm_line" ]]; then
  pass "GOS update image.zip sits after dpm (prefix stops before it; GT delta OK)"
else
  fail "could not locate GOS update-after-dpm"
fi

export FAIL_FLASH_AVB=0
export ALLOW_AVB_KEY_FAIL=0
for d in tokay akita komodo rango; do
  got="$WORKDIR/prefix_$d.txt"
  exp="$WORKDIR/expected_$d.txt"
  if [[ "$d" == "rango" ]]; then
    write_expected rango "$exp"
  else
    write_expected pixel9 "$exp"
  fi
  if ! run_step2_prefix "$d" "$got"; then
    fail "step2 prefix dump died for $d"
    continue
  fi
  if cmp -s "$got" "$exp"; then
    pass "golden prefix $d MATCHES GOS flash-all prefix (no update-zip)"
  else
    fail "golden prefix $d DIFF"
    echo "---- expected $d ----" >&2
    cat "$exp" >&2 || true
    echo "---- got $d ----" >&2
    cat "$got" >&2 || true
  fi
done

echo "=== Q-FLASH-CLI-HARDEN case10: USB / overlay HOLD ==="

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
hold "web-installer overlay HOLD (no host browser this card)"

echo ""
echo "=== Q-FLASH-CLI-HARDEN static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
