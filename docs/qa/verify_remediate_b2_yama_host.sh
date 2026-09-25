#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-YAMA (pair of T-REMEDIATE-B2-YAMA
# item 9 residual). Do not trust Backend/Architect dumps.
# Scope: orphan Makefile ABSENT + out-of-tree merge_config SOP.
# Do NOT require a Makefile include (that path was REJECTED).
# Live Image __lsm_yama ABSENT is HOLD, not FAIL. Do not invent PRESENT.
# Do not overwrite verify_remediate_b2_kernel_static.sh. No product edits.
# No USB GO. No kernel Image rewrite. No m. No commit. No ONDEVICE restart.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_yama_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

KERNEL_DIR="device/google/caimito-kernels/6.1"
MK="$KERNEL_DIR/Makefile"
YAMA_FRAG="$KERNEL_DIR/guardtalk-security-yama.config"
SYS_MAP="$KERNEL_DIR/grapheneos/System.map"
IMAGE="$KERNEL_DIR/grapheneos/Image.lz4"
HOOKS="vendor/guardtalk/device/komodo/REGEN_HOOKS.md"
KERNEL_SUITE="vendor/guardtalk/docs/qa/verify_remediate_b2_kernel_static.sh"
ART_DIR="vendor/guardtalk/docs/qa/_artifacts"
KERNEL_LOG="${ART_DIR}/Q-REMEDIATE-B2-YAMA_KERNEL_SUITE.out"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

mkdir -p "$ART_DIR"

echo "=== Q-REMEDIATE-B2-YAMA independent rematch (Makefile absent + SOP) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "USB_GO=not started"
echo "M=not started"
echo "IMAGE_REWRITE=not started"
echo "Q-ONDEVICE=not started"
echo "MAKEFILE_INCLUDE_REQUIRED=false (REJECTED path)"
echo

echo "--- required files ---"
require_file "$YAMA_FRAG"
require_file "$SYS_MAP"
require_file "$IMAGE"
require_file "$HOOKS"
require_file "$KERNEL_SUITE"

echo
echo "--- 1. orphan Makefile ABSENT (test ! -f) ---"
if test ! -f "$MK"; then
  pass "test ! -f $MK (ABSENT)"
else
  fail "$MK EXISTS (orphan Makefile must be absent)"
fi
if test -e "$MK"; then
  fail "$MK exists as some filesystem object"
else
  pass "$MK not present as any type"
fi

echo
echo "--- 2. no Makefile/Android.mk/Android.bp/*.mk (maxdepth 3, ignore .git) ---"
MK_LIST="$(find "$KERNEL_DIR" -maxdepth 3 \
  \( -name .git -o -path '*/.git' -o -path '*/.git/*' \) -prune -o \
  \( -name 'Android.mk' -o -name 'Android.bp' -o -name 'Makefile' -o -name '*.mk' \) \
  -print 2>/dev/null || true)"
if [[ -z "${MK_LIST}" ]]; then
  pass "no Makefile/Android.mk/Android.bp/*.mk under $KERNEL_DIR (maxdepth 3, .git pruned)"
else
  fail "unexpected make files under $KERNEL_DIR: $MK_LIST"
fi

echo
echo "--- 3. fragment CONFIG_SECURITY_YAMA=y ---"
if [[ -f "$YAMA_FRAG" ]] && rg -q '^CONFIG_SECURITY_YAMA=y$' "$YAMA_FRAG"; then
  pass "fragment has CONFIG_SECURITY_YAMA=y"
else
  fail "fragment missing CONFIG_SECURITY_YAMA=y"
fi

echo
echo "--- 4. REGEN_HOOKS out-of-tree merge_config.sh SOP (not Makefile include) ---"
if rg -q 'scripts/kconfig/merge_config.sh' "$HOOKS"; then
  pass "REGEN_HOOKS.md documents scripts/kconfig/merge_config.sh"
else
  fail "REGEN_HOOKS.md missing scripts/kconfig/merge_config.sh"
fi
if rg -q 'guardtalk-security-yama.config' "$HOOKS"; then
  pass "REGEN_HOOKS.md names guardtalk-security-yama.config"
else
  fail "REGEN_HOOKS.md missing fragment name"
fi
if rg -q 'out-of-tree' "$HOOKS"; then
  pass "REGEN_HOOKS.md documents out-of-tree kernel rebuild"
else
  fail "REGEN_HOOKS.md missing out-of-tree kernel rebuild language"
fi
# REJECTED path: requiring an in-tree Makefile include.
if rg -q 'Do \*\*not\*\* add those files under `caimito-kernels/6.1/`' "$HOOKS" \
  || rg -q 'Do \*\*not\*\* add those files' "$HOOKS"; then
  pass "REGEN_HOOKS.md forbids adding Makefile/Android.mk/Android.bp under caimito-kernels/6.1"
else
  fail "REGEN_HOOKS.md missing forbid-add-makefile language"
fi
FRAG_MK_REFS="$(rg -l 'guardtalk-security-yama' \
  device/google/caimito-kernels vendor/guardtalk --glob '!**/docs/qa/**' 2>/dev/null || true)"
if echo "$FRAG_MK_REFS" | rg -q 'Android\.(mk|bp)|\.mk$|Makefile'; then
  fail "fragment referenced from a Makefile (REJECTED include path)"
else
  pass "fragment not Makefile-included (docs/README/REGEN_HOOKS only)"
fi

echo
echo "--- 6. live System.map __lsm_yama ABSENT is HOLD (not FAIL; do not invent PRESENT) ---"
if [[ ! -f "$SYS_MAP" ]]; then
  fail "live System.map missing"
elif rg -q '__lsm_yama' "$SYS_MAP"; then
  fail "__lsm_yama PRESENT in live grapheneos/System.map (do not invent Image.lz4)"
else
  hold "live grapheneos/System.map __lsm_yama ABSENT (YAMA not in prebuilt Image)"
fi
LSM_LIST="$(rg -n '__lsm_' "$SYS_MAP" || true)"
echo "$LSM_LIST"
if echo "$LSM_LIST" | rg -q '__lsm_capability' \
  && echo "$LSM_LIST" | rg -q '__lsm_selinux' \
  && echo "$LSM_LIST" | rg -q '__lsm_safesetid_security_init' \
  && echo "$LSM_LIST" | rg -q '__lsm_integrity'; then
  pass "live System.map LSM set includes capability/selinux/safesetid/integrity"
else
  fail "live System.map LSM set missing expected entries"
fi
if [[ -f "$IMAGE" ]]; then
  IMG_MTIME="$(stat -c '%y' "$IMAGE" | cut -d. -f1)"
  echo "Image.lz4 mtime=$IMG_MTIME"
  hold "Image.lz4 present (mtime $IMG_MTIME); not treated as rebuilt"
else
  fail "Image.lz4 missing"
fi

echo
echo "--- 5. re-run Q-KERNEL suite (do not overwrite the KERNEL script) ---"
set +e
bash "$KERNEL_SUITE" >"$KERNEL_LOG" 2>&1
KERNEL_EC=$?
set -e
tail -n 20 "$KERNEL_LOG"
if [[ "$KERNEL_EC" -eq 0 ]]; then
  pass "verify_remediate_b2_kernel_static.sh EXIT=0"
else
  fail "verify_remediate_b2_kernel_static.sh EXIT=$KERNEL_EC (expected 0)"
fi
if rg -q 'YAMA_LIVE_IMAGE=HOLD' "$KERNEL_LOG"; then
  pass "KERNEL suite YAMA_LIVE_IMAGE=HOLD"
else
  fail "KERNEL suite missing YAMA_LIVE_IMAGE=HOLD"
fi
if rg -q '__lsm_yama PRESENT' "$KERNEL_LOG"; then
  fail "KERNEL suite reported __lsm_yama PRESENT (do not invent)"
else
  pass "KERNEL suite did not report __lsm_yama PRESENT"
fi
if rg -q 'RESULT: FAIL' "$KERNEL_LOG"; then
  fail "KERNEL suite RESULT: FAIL"
else
  pass "KERNEL suite RESULT is not FAIL"
fi

echo
echo "--- 6b. adb empty → HOLD; do not lift PASS HOLD ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
ADB_DEV="$(echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {print $1}')"
if [[ -z "${ADB_DEV:-}" ]]; then
  hold "adb empty; on-device /proc/sys HOLD; Q-ONDEVICE not started"
else
  hold "adb has $ADB_DEV but Q-ONDEVICE is not started; /proc/sys not claimed live"
fi
hold "PASS HOLD remains (not lifted)"

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=1 EXIT=1"
  echo "LIVE_DEVICE_CLAIMED=false"
  echo "YAMA_LIVE_IMAGE=HOLD"
  echo "PROC_SYS=HOLD"
  echo "DEVICE=HOLD"
  echo "PASS_HOLD=remains"
  echo "MAKEFILE_INCLUDE_REQUIRED=false"
  exit 1
fi
echo "RESULT: PASS (host static)  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=0 EXIT=0"
echo "LIVE_DEVICE_CLAIMED=false"
echo "YAMA_LIVE_IMAGE=HOLD"
echo "PROC_SYS=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
echo "MAKEFILE_INCLUDE_REQUIRED=false"
exit 0
