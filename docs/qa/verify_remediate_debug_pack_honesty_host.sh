#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-DEBUG-PACK-HONESTY (DEC-REMEDIATE-017).
# Pair of F-REMEDIATE-DEBUG-PACK-HONESTY (APPROVED). Do not trust Frontend
# or Architect dumps.
# Honesty docs only. Host static. No USB GO. No m. No retarget.
# Does not invent DEBUG_FLASH_READY=true or FLASH_READY=true.
# Distinct from Q-REMEDIATE-DEBUG-ADVERTISE and Q-REMEDIATE-B1-DEBUG-PACK-SUITE.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_debug_pack_honesty_host.sh
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
SIBLING_ADVERTISE="vendor/guardtalk/docs/qa/verify_remediate_debug_advertise_host.sh"
SIBLING_PACK="vendor/guardtalk/docs/qa/verify_remediate_debug_pack_host.sh"
DEBUG_DOC="vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md"
TYPES="vendor/guardtalk/web-installer/src/types.ts"
DIST_TYPES="vendor/guardtalk/web-installer/dist/src/types.js"
LATEST="releases/desktop-flash/komodo-latest"
DEBUG_LATEST="releases/desktop-flash/komodo-debug-latest"
STAMP_NAME="komodo-20260915-063833"
DEBUG_STAMP="komodo-debug-20260918-180338"
OUT_DIR="out/target/product/komodo"
STAMP_DIR="releases/desktop-flash/${DEBUG_STAMP}"
LEFTOVER_DIR="releases/desktop-flash/${STAMP_NAME}"

declare -A DOC_SHA=(
  [boot.img]="449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc"
  [vendor_kernel_boot.img]="a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8"
  [pvmfw.img]="f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8"
  [dtbo.img]="742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433"
)
AB_FILES=(boot.img vendor_kernel_boot.img pvmfw.img dtbo.img)

echo "=== Q-REMEDIATE-DEBUG-PACK-HONESTY independent rematch (DEC-017) ==="
echo "ROOT=${ROOT}"
echo "DEBUG_FLASH_READY=unverified (computed below)"
echo "FLASH_READY=false (not invented; honesty rematch does not lift image PASS)"
echo "LIVE_FLASH_CLAIMED=unverified (computed below)"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "ONDEVICE=not started"
echo "PASS_HOLD=remains"
echo

echo "--- hygiene: distinct script; do not collide with siblings ---"
if [[ "$(basename "${SELF}")" == "verify_remediate_debug_advertise_host.sh" ]] || \
   [[ "$(basename "${SELF}")" == "verify_remediate_debug_pack_host.sh" ]]; then
  fail "this suite collided with a sibling verify script"
else
  pass "basename is verify_remediate_debug_pack_honesty_host.sh (distinct)"
fi
if [[ -f "${SIBLING_ADVERTISE}" ]]; then
  pass "${SIBLING_ADVERTISE} still present (not overwritten)"
else
  fail "${SIBLING_ADVERTISE} missing (collision / overwrite?)"
fi
if [[ -f "${SIBLING_PACK}" ]]; then
  pass "${SIBLING_PACK} still present (not overwritten)"
else
  fail "${SIBLING_PACK} missing (collision / overwrite?)"
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
echo "--- DEC-017 section present; restamp is not a kernel rebuild ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  pass "${DEBUG_DOC} exists"
else
  fail "missing ${DEBUG_DOC}"
fi
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- '## DEC-017 — SHA-identical A/B after packaging restamp is not a kernel rebuild' \
    "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} has DEC-017 heading (SHA-identical restamp ≠ kernel rebuild)"
  else
    fail "${DEBUG_DOC} missing DEC-017 heading"
  fi
  if rg -q -- 'SHA-identical A/B after a packaging restamp is \*\*not\*\* a kernel' \
    "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} states SHA-identical A/B after packaging restamp is not a kernel rebuild"
  else
    fail "${DEBUG_DOC} missing SHA-identical restamp ≠ rebuild sentence"
  fi
  # Line 39 is a single sentence. The later "Do not require a fake new
  # hash" wrap is the same claim; Law 7: do not FAIL the product for wrap.
  if rg -q -- 'does \*\*not\*\* require a fake new hash' "${DEBUG_DOC}" && \
     rg -q -- 'fake new hash' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} does not require a fake new hash"
  else
    fail "${DEBUG_DOC} missing 'do not require a fake new hash'"
  fi
  if rg -q -- 'This note does \*\*not\*\* invent a stamp' "${DEBUG_DOC}" && \
     rg -q -- 'invent a new stamp, symlink, or SKU' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} does not invent a stamp / symlink / SKU"
  else
    fail "${DEBUG_DOC} missing no-invent-stamp language"
  fi
fi

echo
echo "--- current flags false; pointer may exist; not DEBUG_FLASH_READY=true ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- '\| `DEBUG_FLASH_READY` \| \*\*false\*\*' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} table current DEBUG_FLASH_READY is **false**"
  else
    fail "${DEBUG_DOC} table missing current DEBUG_FLASH_READY **false**"
  fi
  if rg -q -- '\| `FLASH_READY` \| \*\*false\*\*' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} table current FLASH_READY is **false**"
  else
    fail "${DEBUG_DOC} table missing current FLASH_READY **false**"
  fi
  if rg -q -- '\| `LIVE_FLASH_CLAIMED` \| \*\*false\*\*' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} table current LIVE_FLASH_CLAIMED is **false**"
  else
    fail "${DEBUG_DOC} table missing current LIVE_FLASH_CLAIMED **false**"
  fi
  if rg -q -- '\| `DEBUG_FLASH_READY` \| \*\*true\*\*' "${DEBUG_DOC}"; then
    fail "NEGATIVE HIT: ${DEBUG_DOC} table claims DEBUG_FLASH_READY **true**"
  else
    pass "${DEBUG_DOC} table does not claim DEBUG_FLASH_READY **true**"
  fi
  if rg -q -- '\| `FLASH_READY` \| \*\*true\*\*' "${DEBUG_DOC}"; then
    fail "NEGATIVE HIT: ${DEBUG_DOC} table claims FLASH_READY **true**"
  else
    pass "${DEBUG_DOC} table does not claim FLASH_READY **true**"
  fi
  if rg -q -- 'may exist' "${DEBUG_DOC}" && \
     rg -q -- 'Existence is \*\*not\*\*' "${DEBUG_DOC}" && \
     rg -q -- '`DEBUG_FLASH_READY=true`' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} says komodo-debug-latest may exist; existence ≠ DEBUG_FLASH_READY=true"
  else
    fail "${DEBUG_DOC} missing pointer-may-exist / not-ready language"
  fi
  if rg -q -- '\*\*USB_GO:\*\* false' "${DEBUG_DOC}" && \
     rg -q -- 'have \*\*no USB GO\*\*' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} USB_GO=false; no USB GO"
  else
    fail "${DEBUG_DOC} missing USB_GO=false / no USB GO"
  fi
fi

echo
echo "--- komodo-latest still documented as ${STAMP_NAME} ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- "unchanged\` → \`${STAMP_NAME}\`" "${DEBUG_DOC}" || \
     rg -q -- "\*\*unchanged\*\* → \`${STAMP_NAME}\`" "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} documents komodo-latest unchanged → ${STAMP_NAME}"
  else
    fail "${DEBUG_DOC} missing komodo-latest → ${STAMP_NAME}"
  fi
  if rg -q -- "still \`${STAMP_NAME}\`" "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} restates komodo-latest still ${STAMP_NAME}"
  else
    fail "${DEBUG_DOC} missing 'still ${STAMP_NAME}'"
  fi
fi

echo
echo "--- live pointers (do not invent; do not retarget) ---"
LATEST_LINK="$(readlink "${LATEST}" 2>/dev/null || true)"
DEBUG_LINK="$(readlink "${DEBUG_LATEST}" 2>/dev/null || true)"
echo "readlink ${LATEST} => ${LATEST_LINK:-ABSENT}"
echo "readlink ${DEBUG_LATEST} => ${DEBUG_LINK:-ABSENT}"
if [[ -L "${LATEST}" && "${LATEST_LINK}" == "${STAMP_NAME}" ]]; then
  pass "${LATEST} -> ${STAMP_NAME} (not retargeted)"
else
  fail "NEGATIVE HIT: ${LATEST} is '${LATEST_LINK}' (want ${STAMP_NAME})"
fi
if [[ -L "${DEBUG_LATEST}" && "${DEBUG_LINK}" == "${DEBUG_STAMP}" ]]; then
  pass "${DEBUG_LATEST} -> ${DEBUG_STAMP} (may exist; not a ready claim)"
elif [[ ! -e "${DEBUG_LATEST}" && ! -L "${DEBUG_LATEST}" ]]; then
  hold "${DEBUG_LATEST} ABSENT (DEC-017 allows may-exist; not FAIL)"
else
  fail "${DEBUG_LATEST} unexpected target '${DEBUG_LINK}'"
fi

echo
echo "--- documented A/B four SHA == live out/ = stamp = leftover ---"
AB_EQUAL=0
for f in "${AB_FILES[@]}"; do
  want="${DOC_SHA[$f]}"
  if [[ ! -f "${OUT_DIR}/${f}" || ! -f "${STAMP_DIR}/${f}" || ! -f "${LEFTOVER_DIR}/${f}" ]]; then
    fail "missing A/B file ${f} in out/, stamp, or leftover"
    continue
  fi
  h_out="$(sha256sum "${OUT_DIR}/${f}" | awk '{print $1}')"
  h_stamp="$(sha256sum "${STAMP_DIR}/${f}" | awk '{print $1}')"
  h_left="$(sha256sum "${LEFTOVER_DIR}/${f}" | awk '{print $1}')"
  echo "${f} out=${h_out} stamp=${h_stamp} leftover=${h_left} doc=${want}"
  if [[ "${h_out}" == "${want}" && "${h_stamp}" == "${want}" && "${h_left}" == "${want}" ]]; then
    if cmp -s "${OUT_DIR}/${f}" "${STAMP_DIR}/${f}" && \
       cmp -s "${STAMP_DIR}/${f}" "${LEFTOVER_DIR}/${f}"; then
      pass "${f} SHA+cmp out=stamp=leftover=doc (STALE_BAK; not a rebuild claim)"
      AB_EQUAL=$((AB_EQUAL + 1))
    else
      fail "${f} sha match but cmp -s failed"
    fi
  else
    fail "${f} SHA mismatch vs documented leftover (do not invent a fake hash)"
  fi
  if rg -q -- "${want}" "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} names leftover digest for ${f}"
  else
    fail "${DEBUG_DOC} missing documented digest for ${f}"
  fi
done
echo "AB_FOUR_LEFTOVER_SHA=${AB_EQUAL}"
if [[ "${AB_EQUAL}" -eq 4 ]]; then
  pass "A/B four SHA-identical after packaging restamp (HOLD-documented, not a kernel rebuild)"
else
  fail "A/B four leftover SHA count ${AB_EQUAL} != 4"
fi

echo
echo "--- LIVE_FLASH_CLAIMED=false (types.ts:119 + served dist) ---"
if [[ -f "${TYPES}" ]]; then
  LINE119="$(sed -n '119p' "${TYPES}")"
  echo "types.ts:119: ${LINE119}"
  if [[ "${LINE119}" == "export const LIVE_FLASH_CLAIMED = false;" ]]; then
    pass "${TYPES}:119 exports LIVE_FLASH_CLAIMED = false"
  else
    fail "${TYPES}:119 is not LIVE_FLASH_CLAIMED = false (got: ${LINE119})"
  fi
  if rg -q -- 'LIVE_FLASH_CLAIMED\s*=\s*true' "${TYPES}"; then
    fail "NEGATIVE HIT: ${TYPES} assigns LIVE_FLASH_CLAIMED=true"
  else
    pass "${TYPES} does not assign LIVE_FLASH_CLAIMED=true"
  fi
else
  fail "missing ${TYPES}"
fi
if [[ -f "${DIST_TYPES}" ]]; then
  if rg -q -- 'export const LIVE_FLASH_CLAIMED = false;' "${DIST_TYPES}"; then
    pass "${DIST_TYPES} exports LIVE_FLASH_CLAIMED = false"
  else
    fail "${DIST_TYPES} missing LIVE_FLASH_CLAIMED = false"
  fi
  if rg -q -- 'LIVE_FLASH_CLAIMED\s*=\s*true' "${DIST_TYPES}"; then
    fail "NEGATIVE HIT: ${DIST_TYPES} assigns LIVE_FLASH_CLAIMED=true"
  else
    pass "${DIST_TYPES} does not assign LIVE_FLASH_CLAIMED=true"
  fi
else
  hold "${DIST_TYPES} ABSENT (source still rematched)"
fi

echo
echo "--- T-PACK status sentence vs owner-root queue (HOLD residual, not FAIL) ---"
if [[ -f "${DEBUG_DOC}" ]] && rg -q -- 'T-REMEDIATE-B1-DEBUG-PACK` is HOLD CONFIRMED' \
  "${DEBUG_DOC}"; then
  hold "${DEBUG_DOC} still says T-DEBUG-PACK HOLD CONFIRMED (queue may have APPROVED later; no product edit)"
else
  pass "${DEBUG_DOC} does not still claim T-DEBUG-PACK HOLD CONFIRMED"
fi

echo
echo "--- adb (device HOLD; do not start Q-ONDEVICE) ---"
ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "${ADB_OUT}"
if echo "${ADB_OUT}" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  hold "adb sees a device — honesty rematch is host-only; USB GO not started"
else
  hold "adb devices empty — not device-fixed; on-device working not invented"
fi

# Honesty rematch never lifts ready flags.
FLASH_READY=false
DEBUG_FLASH_READY=false
if [[ "${FAIL}" -ne 0 ]]; then
  FLASH_CLASS="FAIL"
else
  FLASH_CLASS="HOLD"
fi

echo
echo "LIVE_FLASH_CLAIMED=false"
echo "FLASH_READY=${FLASH_READY}"
echo "DEBUG_FLASH_READY=${DEBUG_FLASH_READY}"
echo "FLASH_CLASS=${FLASH_CLASS}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
echo "USB_GO=not started"
echo "ONDEVICE=not started"
echo "KOMODO_LATEST=${LATEST_LINK}"
echo "KOMODO_DEBUG_LATEST=${DEBUG_LINK:-ABSENT}"
echo "AB_FOUR_LEFTOVER_SHA=${AB_EQUAL}"
echo "RESULT: $([[ "${FAIL}" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=$([[ "${FAIL}" -eq 0 ]] && echo 0 || echo 1)"
exit "${FAIL}"
