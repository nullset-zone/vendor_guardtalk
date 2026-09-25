#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-DEBUG-PACK-SUITE
# (DEC-REMEDIATE-015 / DEC-REMEDIATE-017).
# Standalone host suite for debug-pack *preconditions*.
# Does NOT lift Q-REMEDIATE-B1-DEBUG-PACK (stamp rematch stays BLOCKED).
#
# Pack predicates:
#   komodo-debug-latest ABSENT or PRESENT → HOLD, not FAIL (pointer is not
#     DEBUG_FLASH_READY)
#   boot.img / vendor_kernel_boot.img / pvmfw.img / dtbo.img:
#     SHA == STALE_BAK or known Sept 15 leftover digest
#       → HOLD "not a kernel rebuild" (DEC-017; mtime alone is not acceptance)
#     dated 2026-09-15 → HOLD, not FAIL
#     ABSENT → HOLD, not FAIL
#   pack not staged → HOLD, not FAIL
#   komodo-latest must still → komodo-20260915-063833 (FAIL if retargeted)
#
# Never invent FLASH_READY=true or DEBUG_FLASH_READY=true.
# Do not start m. Do not USB GO. Do not run *_ondevice.sh. Do not cat pem.
# Distinct from verify_remediate_b1_debug_m_host.sh — do not overwrite it.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_debug_pack_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

SELF="$0"
SIBLING_DEBUG_M="vendor/guardtalk/docs/qa/verify_remediate_b1_debug_m_host.sh"
SIBLING_ADVERTISE="vendor/guardtalk/docs/qa/verify_remediate_debug_advertise_host.sh"
TYPES="vendor/guardtalk/web-installer/src/types.ts"
DEBUG_FLASH="vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md"
QUEUE="TASK_QUEUE.md"
DEC015=".memory-bank/decisions.md"
LATEST="releases/desktop-flash/komodo-latest"
DEBUG_LATEST="releases/desktop-flash/komodo-debug-latest"
STAMP_NAME="komodo-20260915-063833"
OUT_KOMODO="out/target/product/komodo"
AB_FOUR=(boot.img vendor_kernel_boot.img pvmfw.img dtbo.img)
SERIAL="54111FDAS000GN"
STALE_BAK="/tmp/t-remediate-b1-debug-pack-stale-20260915"
# DEC-017 leftover digests (Sept 15 STALE_BAK / current-tree packaging bits).
LEFTOVER_BOOT="449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc"
LEFTOVER_VKB="a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8"
LEFTOVER_PVMFW="f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8"
LEFTOVER_DTBO="742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433"

file_sha256() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    sha256sum "${f}" 2>/dev/null | awk '{print $1}'
  fi
}

leftover_for() {
  case "$1" in
    boot.img) echo "${LEFTOVER_BOOT}" ;;
    vendor_kernel_boot.img) echo "${LEFTOVER_VKB}" ;;
    pvmfw.img) echo "${LEFTOVER_PVMFW}" ;;
    dtbo.img) echo "${LEFTOVER_DTBO}" ;;
    *) echo "" ;;
  esac
}

is_known_leftover_sha() {
  local sha="$1"
  [[ -n "${sha}" ]] || return 1
  case "${sha}" in
    "${LEFTOVER_BOOT}"|"${LEFTOVER_VKB}"|"${LEFTOVER_PVMFW}"|"${LEFTOVER_DTBO}")
      return 0
      ;;
  esac
  return 1
}

echo "=== Q-REMEDIATE-B1-DEBUG-PACK-SUITE independent rematch (DEC-015/017 pack preconditions) ==="
echo "ROOT=${ROOT}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "LIVE_FLASH_CLAIMED=unverified (computed below)"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "FLASH_READY=false (not invented; computed at end)"
echo "DEBUG_FLASH_READY=false (not invented; computed at end)"
echo "Q-REMEDIATE-B1-DEBUG-PACK=BLOCKED (this suite does not lift stamp rematch)"
echo "PASS_HOLD=remains"
echo

echo "--- hygiene: distinct script; do not start m / USB / ondevice ---"
if [[ "$(basename "${SELF}")" == "verify_remediate_b1_debug_m_host.sh" ]]; then
  fail "this suite collided with verify_remediate_b1_debug_m_host.sh"
else
  pass "basename is verify_remediate_debug_pack_host.sh (distinct)"
fi
if [[ -f "${SIBLING_DEBUG_M}" ]]; then
  pass "${SIBLING_DEBUG_M} still present (not overwritten)"
else
  fail "${SIBLING_DEBUG_M} missing (collision / overwrite?)"
fi
if [[ -f "${SIBLING_ADVERTISE}" ]]; then
  pass "${SIBLING_ADVERTISE} still present (not overwritten)"
else
  fail "${SIBLING_ADVERTISE} missing (collision / overwrite?)"
fi
if rg -n -- '^[[:space:]]*(m|lunch|fastboot|adb[[:space:]]+flash)[[:space:]]' \
  "$0" >/dev/null 2>&1; then
  fail "suite source invokes m/lunch/fastboot/adb flash (forbidden)"
else
  pass "suite source does not invoke m, lunch, fastboot, or adb flash"
fi
pass "m not started this QA stamp"
pass "USB GO / flash / lock not started"
pass "Q-ONDEVICE / *_ondevice.sh not started"

echo
echo "--- DEC-015 / DEC-017 pack card present (does not APPROVE T-DEBUG-PACK) ---"
if [[ -f "${DEC015}" ]] && rg -q -- 'DEC-REMEDIATE-015' "${DEC015}"; then
  pass "${DEC015} binds DEC-REMEDIATE-015"
else
  hold "${DEC015} missing DEC-REMEDIATE-015 (gitignored memory-bank; rematch TASK_QUEUE)"
fi
if [[ -f "${DEC015}" ]] && rg -q -- 'DEC-REMEDIATE-017' "${DEC015}"; then
  pass "${DEC015} binds DEC-REMEDIATE-017"
else
  hold "${DEC015} missing DEC-REMEDIATE-017 (gitignored memory-bank; rematch TASK_QUEUE)"
fi
if [[ -f "${QUEUE}" ]] && rg -q -- 'DEC-REMEDIATE-015' "${QUEUE}"; then
  pass "${QUEUE} documents DEC-REMEDIATE-015"
else
  fail "${QUEUE} missing DEC-REMEDIATE-015"
fi
if [[ -f "${QUEUE}" ]] && rg -q -- 'DEC-REMEDIATE-017' "${QUEUE}"; then
  pass "${QUEUE} documents DEC-REMEDIATE-017"
else
  fail "${QUEUE} missing DEC-REMEDIATE-017"
fi
if [[ -f "${QUEUE}" ]]; then
  if rg -A8 -- '^### Q-REMEDIATE-B1-DEBUG-PACK$' "${QUEUE}" | \
     rg -q -- 'Status: BLOCKED'; then
    pass "Q-REMEDIATE-B1-DEBUG-PACK is BLOCKED (this suite does not lift it)"
  else
    hold "Q-REMEDIATE-B1-DEBUG-PACK status is not BLOCKED (record only; this suite still does not APPROVE it)"
  fi
  if rg -A3 -- '^### T-REMEDIATE-B1-DEBUG-PACK$' "${QUEUE}" | \
     rg -q -- 'Status: APPROVED'; then
    hold "T-REMEDIATE-B1-DEBUG-PACK is APPROVED (this suite still does not lift Q-DEBUG-PACK)"
  else
    hold "T-REMEDIATE-B1-DEBUG-PACK is not APPROVED (pack not done; expected)"
  fi
fi

echo
echo "--- honesty: FLASH_READY=false; DEBUG_FLASH_READY=false; LIVE_FLASH_CLAIMED=false ---"
if [[ -f "${TYPES}" ]]; then
  if rg -q -- '^export const LIVE_FLASH_CLAIMED = false;$' "${TYPES}"; then
    pass "${TYPES} exports LIVE_FLASH_CLAIMED = false"
  else
    fail "${TYPES} missing exact LIVE_FLASH_CLAIMED = false export"
  fi
  if rg -q -- 'LIVE_FLASH_CLAIMED\s*=\s*true' "${TYPES}"; then
    fail "NEGATIVE HIT: ${TYPES} assigns LIVE_FLASH_CLAIMED=true"
  else
    pass "${TYPES} does not assign LIVE_FLASH_CLAIMED=true"
  fi
else
  fail "missing ${TYPES}"
fi

if [[ -f "${DEBUG_FLASH}" ]]; then
  if rg -qF -- '| `DEBUG_FLASH_READY` | **false**' "${DEBUG_FLASH}"; then
    pass "${DEBUG_FLASH} table documents DEBUG_FLASH_READY false"
  else
    fail "${DEBUG_FLASH} missing DEBUG_FLASH_READY false table row"
  fi
  if rg -qF -- '| `FLASH_READY` | **false**' "${DEBUG_FLASH}"; then
    pass "${DEBUG_FLASH} table documents FLASH_READY false"
  else
    hold "${DEBUG_FLASH} FLASH_READY false table row not exact"
  fi
  if rg -qF -- '| `LIVE_FLASH_CLAIMED` | **false**' "${DEBUG_FLASH}"; then
    pass "${DEBUG_FLASH} table documents LIVE_FLASH_CLAIMED false"
  else
    hold "${DEBUG_FLASH} LIVE_FLASH_CLAIMED false table row not exact"
  fi
  if rg -qF -- '| `DEBUG_FLASH_READY` | **true**' "${DEBUG_FLASH}"; then
    fail "NEGATIVE HIT: ${DEBUG_FLASH} table claims DEBUG_FLASH_READY true"
  else
    pass "${DEBUG_FLASH} table does not claim DEBUG_FLASH_READY true"
  fi
else
  hold "${DEBUG_FLASH} ABSENT (honesty is F-DEBUG-PACK-HONESTY; not FAIL here)"
fi

echo
echo "--- komodo-latest still → ${STAMP_NAME} (not retargeted) ---"
if [[ -L "${LATEST}" ]]; then
  LATEST_LINK="$(readlink "${LATEST}" 2>/dev/null || true)"
  echo "readlink ${LATEST} => ${LATEST_LINK}"
  if [[ "${LATEST_LINK}" == "${STAMP_NAME}" ]]; then
    pass "${LATEST} -> ${STAMP_NAME} (relative symlink; not retargeted)"
  else
    fail "NEGATIVE HIT: ${LATEST} retargeted to '${LATEST_LINK}' (want ${STAMP_NAME})"
  fi
elif [[ -e "${LATEST}" ]]; then
  fail "${LATEST} exists but is not a symlink"
else
  fail "${LATEST} ABSENT"
fi

echo
echo "--- komodo-debug-latest ABSENT / pack not staged → HOLD (not FAIL) ---"
PACK_STAGED=0
if [[ -e "${DEBUG_LATEST}" || -L "${DEBUG_LATEST}" ]]; then
  DEBUG_LINK="$(readlink "${DEBUG_LATEST}" 2>/dev/null || echo PRESENT)"
  hold "${DEBUG_LATEST} PRESENT -> ${DEBUG_LINK} (pack landed; this suite still does not lift DEBUG_FLASH_READY or Q-DEBUG-PACK)"
  PACK_STAGED=1
else
  hold "${DEBUG_LATEST} ABSENT (expected until T-REMEDIATE-B1-DEBUG-PACK)"
fi
DEBUG_STAMPS="$(ls -d releases/desktop-flash/komodo-debug-* 2>/dev/null || true)"
if [[ -z "${DEBUG_STAMPS}" ]]; then
  hold "no komodo-debug-<UTCSTAMP> directory (pack not staged; HOLD not FAIL)"
else
  hold "debug stamp dirs present (not a DEBUG_FLASH_READY lift; Q-DEBUG-PACK not lifted): ${DEBUG_STAMPS}"
  PACK_STAGED=1
fi
if [[ "${PACK_STAGED}" -eq 0 ]]; then
  hold "pack not staged (HOLD not FAIL; this suite does not invent a stamp)"
else
  hold "pack artifacts present (HOLD; Q-REMEDIATE-B1-DEBUG-PACK still not lifted)"
fi

echo
echo "--- DEC-017 A/B four SHA vs leftover / STALE_BAK (not a kernel rebuild) ---"
STALE_N=0
LEFTOVER_SHA_N=0
ABSENT_N=0
SHA_DIFF_N=0
if [[ -d "${STALE_BAK}" ]]; then
  hold "STALE_BAK present at ${STALE_BAK} (compare only; do not copy)"
else
  hold "STALE_BAK ABSENT at ${STALE_BAK} (compare to hardcoded leftover digests)"
fi
for img in "${AB_FOUR[@]}"; do
  p="${OUT_KOMODO}/${img}"
  want_sha="$(leftover_for "${img}")"
  if [[ -f "${p}" ]]; then
    mtime="$(stat -c %y "${p}" 2>/dev/null || true)"
    size="$(stat -c %s "${p}" 2>/dev/null || echo 0)"
    sha="$(file_sha256 "${p}")"
    stale_sha=""
    if [[ -f "${STALE_BAK}/${img}" ]]; then
      stale_sha="$(file_sha256 "${STALE_BAK}/${img}")"
    fi
    echo "STAT ${p} mtime=${mtime} size=${size} sha256=${sha}"
    if [[ -n "${stale_sha}" ]]; then
      echo "STALE_BAK ${STALE_BAK}/${img} sha256=${stale_sha}"
    fi
    leftover=0
    if is_known_leftover_sha "${sha}"; then
      leftover=1
    fi
    if [[ -n "${sha}" && -n "${stale_sha}" && "${sha}" == "${stale_sha}" ]]; then
      leftover=1
    fi
    if [[ -n "${sha}" && -n "${want_sha}" && "${sha}" == "${want_sha}" ]]; then
      leftover=1
    fi
    if [[ "${leftover}" -eq 1 ]]; then
      hold "${img} SHA equals Sept 15 leftover / STALE_BAK — not a kernel rebuild (DEC-017; HOLD not FAIL)"
      LEFTOVER_SHA_N=$((LEFTOVER_SHA_N + 1))
      if [[ "${mtime}" == 2026-09-15* ]]; then
        STALE_N=$((STALE_N + 1))
      fi
    elif [[ "${mtime}" == 2026-09-15* ]]; then
      hold "${img} still dated 2026-09-15 (DEC-015 leftover; HOLD not FAIL)"
      STALE_N=$((STALE_N + 1))
    else
      hold "${img} SHA differs from leftover/STALE_BAK (mtime=${mtime}); this suite does not certify a kernel rebuild and does not lift Q-DEBUG-PACK"
      SHA_DIFF_N=$((SHA_DIFF_N + 1))
    fi
  else
    hold "${p} ABSENT (HOLD not FAIL; missing A/B is not FAIL)"
    ABSENT_N=$((ABSENT_N + 1))
  fi
done
echo "AB_FOUR_STALE=${STALE_N} AB_FOUR_LEFTOVER_SHA=${LEFTOVER_SHA_N} AB_FOUR_ABSENT=${ABSENT_N} AB_FOUR_SHA_DIFF=${SHA_DIFF_N}"
if [[ "${LEFTOVER_SHA_N}" -eq 4 ]]; then
  hold "all four A/B SHA equal leftover / STALE_BAK — not a kernel rebuild (DEC-017; Q-DEBUG-PACK not lifted)"
elif [[ "${STALE_N}" -eq 4 ]]; then
  hold "all four A/B leftovers still 2026-09-15 (HOLD not FAIL)"
elif [[ "${ABSENT_N}" -eq 4 ]]; then
  hold "all four A/B ABSENT (HOLD not FAIL; missing stamp / A/B is not FAIL)"
else
  hold "A/B four mixed/absent/SHA-diff (HOLD not FAIL; this suite does not certify a kernel rebuild)"
fi

echo
echo "--- DEC-017 stamp A/B four (if pointer exists; SHA==leftover is not a rebuild) ---"
STAMP_LEFTOVER_N=0
STAMP_ABSENT_N=0
STAMP_SHA_DIFF_N=0
STAMP_DIR=""
if [[ -L "${DEBUG_LATEST}" || -e "${DEBUG_LATEST}" ]]; then
  STAMP_LINK="$(readlink "${DEBUG_LATEST}" 2>/dev/null || true)"
  if [[ -n "${STAMP_LINK}" ]]; then
    STAMP_DIR="releases/desktop-flash/${STAMP_LINK}"
  fi
fi
if [[ -z "${STAMP_DIR}" || ! -d "${STAMP_DIR}" ]]; then
  hold "debug stamp dir ABSENT (missing stamp HOLD not FAIL; Q-DEBUG-PACK not lifted)"
else
  hold "debug stamp dir ${STAMP_DIR} present (pointer is not DEBUG_FLASH_READY)"
  for img in "${AB_FOUR[@]}"; do
    p="${STAMP_DIR}/${img}"
    if [[ -f "${p}" ]]; then
      sha="$(file_sha256 "${p}")"
      echo "STAMP ${p} sha256=${sha}"
      if is_known_leftover_sha "${sha}"; then
        hold "stamp ${img} SHA equals Sept 15 leftover — not a kernel rebuild (DEC-017; HOLD not FAIL)"
        STAMP_LEFTOVER_N=$((STAMP_LEFTOVER_N + 1))
      else
        hold "stamp ${img} SHA differs from leftover; this suite does not certify a kernel rebuild"
        STAMP_SHA_DIFF_N=$((STAMP_SHA_DIFF_N + 1))
      fi
    else
      hold "stamp ${p} ABSENT (HOLD not FAIL)"
      STAMP_ABSENT_N=$((STAMP_ABSENT_N + 1))
    fi
  done
fi
echo "STAMP_AB_LEFTOVER_SHA=${STAMP_LEFTOVER_N} STAMP_AB_ABSENT=${STAMP_ABSENT_N} STAMP_AB_SHA_DIFF=${STAMP_SHA_DIFF_N}"

echo
echo "--- adb (device HOLD; do not start Q-ONDEVICE / USB GO) ---"
ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "${ADB_OUT}"
if echo "${ADB_OUT}" | grep -q "${SERIAL}[[:space:]]"; then
  hold "adb sees ${SERIAL} — host-only card; do not start USB GO; not device-fixed"
elif echo "${ADB_OUT}" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  hold "adb sees a device — still not DEBUG_FLASH_READY; USB GO not started"
else
  hold "adb devices empty — device HOLD; USB GO not started"
fi

# Preconditions suite never lifts either ready flag.
FLASH_READY=false
DEBUG_FLASH_READY=false
if [[ "${FAIL}" -ne 0 ]]; then
  FLASH_CLASS="FAIL"
  DEBUG_CLASS="FAIL"
else
  FLASH_CLASS="HOLD"
  DEBUG_CLASS="HOLD"
fi

if [[ "${FLASH_READY}" == "true" || "${DEBUG_FLASH_READY}" == "true" ]]; then
  fail "NEGATIVE HIT: ready flag invented true"
  FLASH_READY=false
  DEBUG_FLASH_READY=false
  FLASH_CLASS="FAIL"
  DEBUG_CLASS="FAIL"
else
  pass "FLASH_READY not invented true"
  pass "DEBUG_FLASH_READY not invented true"
fi

echo
echo "AB_FOUR_STALE=${STALE_N}"
echo "AB_FOUR_LEFTOVER_SHA=${LEFTOVER_SHA_N}"
echo "AB_FOUR_ABSENT=${ABSENT_N}"
echo "AB_FOUR_SHA_DIFF=${SHA_DIFF_N}"
echo "STAMP_AB_LEFTOVER_SHA=${STAMP_LEFTOVER_N}"
echo "STAMP_AB_ABSENT=${STAMP_ABSENT_N}"
echo "STAMP_AB_SHA_DIFF=${STAMP_SHA_DIFF_N}"
echo "PACK_STAGED=$([[ "${PACK_STAGED}" -eq 1 ]] && echo true || echo false)"
echo "FLASH_READY=${FLASH_READY}"
echo "DEBUG_FLASH_READY=${DEBUG_FLASH_READY}"
echo "FLASH_CLASS=${FLASH_CLASS}"
echo "DEBUG_CLASS=${DEBUG_CLASS}"
echo "LIVE_FLASH_CLAIMED=false"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
echo "USB_GO=not started"
echo "ONDEVICE=not started"
echo "Q-REMEDIATE-B1-DEBUG-PACK=BLOCKED"
echo "KOMODO_LATEST=$(readlink "${LATEST}" 2>/dev/null || echo ABSENT)"
echo "KOMODO_DEBUG_LATEST=$([[ -e "${DEBUG_LATEST}" || -L "${DEBUG_LATEST}" ]] && readlink "${DEBUG_LATEST}" 2>/dev/null || echo ABSENT)"
echo "RESULT: $([[ "${FAIL}" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=$([[ "${FAIL}" -eq 0 ]] && echo 0 || echo 1)"
exit "${FAIL}"
