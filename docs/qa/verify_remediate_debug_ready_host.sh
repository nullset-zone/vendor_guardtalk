#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-DEBUG-READY +
# Q-REMEDIATE-DEBUG-READY-SURFACES (DEC-REMEDIATE-018).
# Pair of F-REMEDIATE-DEBUG-READY / F-REMEDIATE-DEBUG-READY-SURFACES
# (APPROVED). Do not trust Frontend or Architect dumps.
# Host static only. No USB GO. No m. No retarget.
# Verifies DEBUG_FLASH_READY=false on KOMODO_DEBUG_FLASH.md, the
# stamp README, the installer README, and ENGINEERING_SIDECAR_USERDEBUG.md.
# A table that claims the flag true is a FAIL. A literal
# DEBUG_FLASH_READY=true or FLASH_READY=true in KOMODO_DEBUG_FLASH.md
# is a FAIL. Does not invent a
# signed-user ready claim or USB GO. Distinct from
# Q-REMEDIATE-DEBUG-ADVERTISE (DEC-011) and
# Q-REMEDIATE-DEBUG-PACK-HONESTY (DEC-017). Do not overwrite those.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_debug_ready_host.sh
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
SIBLING_HONESTY="vendor/guardtalk/docs/qa/verify_remediate_debug_pack_honesty_host.sh"
SIBLING_PACK="vendor/guardtalk/docs/qa/verify_remediate_debug_pack_host.sh"
DEBUG_DOC="vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md"
STAMP_README="releases/desktop-flash/komodo-debug-20260918-180338/README-FLASH-DESKTOP.md"
TYPES="vendor/guardtalk/web-installer/src/types.ts"
DIST_TYPES="vendor/guardtalk/web-installer/dist/src/types.js"
INSTALL_README="vendor/guardtalk/web-installer/README.md"
SIDECAR="vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md"
LATEST="releases/desktop-flash/komodo-latest"
DEBUG_LATEST="releases/desktop-flash/komodo-debug-latest"
LATEST_TARGET="komodo-20260928-052609"
LEFTOVER_NAME="komodo-20260915-063833"
DEBUG_STAMP="komodo-debug-20260918-180338"
OUT_DIR="out/target/product/komodo"
STAMP_DIR="releases/desktop-flash/${DEBUG_STAMP}"
LEFTOVER_DIR="releases/desktop-flash/${LEFTOVER_NAME}"

declare -A DOC_SHA=(
  [boot.img]="449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc"
  [vendor_kernel_boot.img]="a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8"
  [pvmfw.img]="f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8"
  [dtbo.img]="742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433"
)
AB_FILES=(boot.img vendor_kernel_boot.img pvmfw.img dtbo.img)

echo "=== Q-REMEDIATE-DEBUG-READY independent rematch (DEC-018) ==="
echo "ROOT=${ROOT}"
echo "DEBUG_FLASH_READY=unverified (computed below)"
echo "FLASH_READY=false (not invented; sidecar bind is not signed-user FLASH_READY)"
echo "LIVE_FLASH_CLAIMED=unverified (computed below)"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "ONDEVICE=not started"
echo "PASS_HOLD=remains"
echo

echo "--- hygiene: distinct script; do not collide with siblings ---"
if [[ "$(basename "${SELF}")" == "verify_remediate_debug_advertise_host.sh" ]] || \
   [[ "$(basename "${SELF}")" == "verify_remediate_debug_pack_honesty_host.sh" ]] || \
   [[ "$(basename "${SELF}")" == "verify_remediate_debug_pack_host.sh" ]]; then
  fail "this suite collided with a sibling verify script"
else
  pass "basename is verify_remediate_debug_ready_host.sh (distinct)"
fi
for sib in "${SIBLING_ADVERTISE}" "${SIBLING_HONESTY}" "${SIBLING_PACK}"; do
  if [[ -f "${sib}" ]]; then
    pass "${sib} still present (not overwritten)"
  else
    fail "${sib} missing (collision / overwrite?)"
  fi
done
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
echo "--- packet verification commands (independent) ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  rg -n -- "DEBUG_FLASH_READY|USB_GO|FLASH_READY|T-DEBUG-PACK HOLD CONFIRMED" \
    "${DEBUG_DOC}" | head -n 40
  pass "rg flag/HOLD hits ${DEBUG_DOC}"
else
  fail "missing ${DEBUG_DOC}"
fi
if [[ -f "${STAMP_README}" ]]; then
  rg -n -- "DEBUG_FLASH_READY|USB_GO|FLASH_READY" "${STAMP_README}"
  pass "rg flag hits ${STAMP_README}"
else
  fail "missing ${STAMP_README}"
fi
LATEST_LINK="$(readlink "${LATEST}" 2>/dev/null || true)"
DEBUG_LINK="$(readlink "${DEBUG_LATEST}" 2>/dev/null || true)"
echo "readlink ${LATEST} => ${LATEST_LINK:-ABSENT}"
echo "readlink ${DEBUG_LATEST} => ${DEBUG_LINK:-ABSENT}"

echo
echo "--- KOMODO_DEBUG_FLASH.md DEC-018: DEBUG_FLASH_READY is false ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  pass "${DEBUG_DOC} exists"
  if rg -q -- '## DEC-018 —' "${DEBUG_DOC}" && \
     rg -q -- 'binding WITHDRAWN' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} has DEC-018 heading; binding withdrawn"
  else
    fail "${DEBUG_DOC} missing DEC-018 heading"
  fi
  if rg -q -- '\| `DEBUG_FLASH_READY` \| \*\*false\*\*' "${DEBUG_DOC}" && \
     rg -q -- 'komodo-debug-20260918-180338' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} table current DEBUG_FLASH_READY is **false** for 180338"
  else
    fail "${DEBUG_DOC} table missing current DEBUG_FLASH_READY **false** for 180338"
  fi
  if rg -q -- '\| `DEBUG_FLASH_READY` \| \*\*true\*\*' "${DEBUG_DOC}"; then
    fail "NEGATIVE HIT: ${DEBUG_DOC} table claims DEBUG_FLASH_READY **true**"
  else
    pass "${DEBUG_DOC} table does not claim DEBUG_FLASH_READY **true**"
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
  if rg -q -- '\| `FLASH_READY` \| \*\*true\*\*' "${DEBUG_DOC}"; then
    fail "NEGATIVE HIT: ${DEBUG_DOC} table claims FLASH_READY **true**"
  else
    pass "${DEBUG_DOC} table does not claim FLASH_READY **true**"
  fi
  if rg -q -- 'DEBUG_FLASH_READY=true|FLASH_READY=true' "${DEBUG_DOC}"; then
    fail "NEGATIVE HIT: ${DEBUG_DOC} contains a ready=true claim"
  else
    pass "${DEBUG_DOC} does not claim DEBUG_FLASH_READY=true or FLASH_READY=true"
  fi
  if rg -q -- '\*\*USB_GO:\*\* false' "${DEBUG_DOC}" && \
     rg -q -- 'have \*\*no USB GO\*\*' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} USB_GO=false; no USB GO"
  else
    fail "${DEBUG_DOC} missing USB_GO=false / no USB GO"
  fi
  if rg -q -- 'USB_GO:\*\* true|\| `USB_GO` \| \*\*true\*\*' "${DEBUG_DOC}"; then
    fail "NEGATIVE HIT: ${DEBUG_DOC} claims USB_GO true"
  else
    pass "${DEBUG_DOC} does not claim USB_GO true"
  fi
else
  fail "missing ${DEBUG_DOC}"
fi

echo
echo "--- T-DEBUG-PACK HOLD CONFIRMED struck (no unstruck current claim) ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- '~~T-DEBUG-PACK HOLD CONFIRMED' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} strikes T-DEBUG-PACK HOLD CONFIRMED"
  else
    fail "${DEBUG_DOC} missing struck T-DEBUG-PACK HOLD CONFIRMED"
  fi
  UNSTRUCK="$(rg -n -- 'T-DEBUG-PACK HOLD CONFIRMED' "${DEBUG_DOC}" \
    | rg -v -- '~~' || true)"
  if [[ -n "${UNSTRUCK}" ]]; then
    fail "NEGATIVE HIT: unstruck T-DEBUG-PACK HOLD CONFIRMED remains: ${UNSTRUCK}"
  else
    pass "${DEBUG_DOC} has no unstruck T-DEBUG-PACK HOLD CONFIRMED"
  fi
fi

echo
echo "--- leftover SHA HOLD residual still documented ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- 'HOLD residual' "${DEBUG_DOC}" && \
     rg -q -- 'DEC-018 does not erase this HOLD residual' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} keeps DEC-017 leftover SHA HOLD residual"
  else
    fail "${DEBUG_DOC} missing leftover SHA HOLD residual language"
  fi
fi

echo
echo "--- stamp README same flags ---"
if [[ -f "${STAMP_README}" ]]; then
  pass "${STAMP_README} exists"
  if rg -q -- '\| `DEBUG_FLASH_READY` \| \*\*false\*\*' "${STAMP_README}"; then
    pass "${STAMP_README} DEBUG_FLASH_READY is **false**"
  else
    fail "${STAMP_README} missing DEBUG_FLASH_READY **false**"
  fi
  if rg -q -- '\| `DEBUG_FLASH_READY` \| \*\*true\*\*' "${STAMP_README}"; then
    fail "NEGATIVE HIT: ${STAMP_README} claims DEBUG_FLASH_READY **true**"
  else
    pass "${STAMP_README} does not claim DEBUG_FLASH_READY **true**"
  fi
  if rg -q -- '\| `FLASH_READY` \| \*\*false\*\*' "${STAMP_README}"; then
    pass "${STAMP_README} FLASH_READY is **false**"
  else
    fail "${STAMP_README} missing FLASH_READY **false**"
  fi
  if rg -q -- '\| `USB_GO` \| \*\*false\*\*' "${STAMP_README}" && \
     rg -q -- '\*\*USB_GO:\*\* false' "${STAMP_README}"; then
    pass "${STAMP_README} USB_GO=false"
  else
    fail "${STAMP_README} missing USB_GO=false"
  fi
  if rg -q -- '\| `FLASH_READY` \| \*\*true\*\*|USB_GO:\*\* true|\| `USB_GO` \| \*\*true\*\*' \
    "${STAMP_README}"; then
    fail "NEGATIVE HIT: ${STAMP_README} claims FLASH_READY or USB_GO true"
  else
    pass "${STAMP_README} does not claim FLASH_READY/USB_GO true"
  fi
  if rg -q -- 'not a this-continue kernel rebuild' "${STAMP_README}" || \
     rg -q -- 'not\*\* a this-continue kernel rebuild' "${STAMP_README}"; then
    pass "${STAMP_README} denies this-continue kernel rebuild"
  else
    fail "${STAMP_README} missing leftover/packaging honesty"
  fi
else
  fail "missing ${STAMP_README}"
fi

echo
echo "--- live pointers (do not invent; do not move) ---"
if [[ -L "${LATEST}" && "${LATEST_LINK}" == "${LATEST_TARGET}" ]]; then
  pass "${LATEST} -> ${LATEST_TARGET} (not moved)"
else
  fail "NEGATIVE HIT: ${LATEST} is '${LATEST_LINK}' (want ${LATEST_TARGET})"
fi
if [[ -L "${DEBUG_LATEST}" && "${DEBUG_LINK}" == "${DEBUG_STAMP}" ]]; then
  pass "${DEBUG_LATEST} -> ${DEBUG_STAMP}"
elif [[ ! -e "${DEBUG_LATEST}" && ! -L "${DEBUG_LATEST}" ]]; then
  hold "${DEBUG_LATEST} ABSENT (not created; absence is HOLD)"
else
  fail "NEGATIVE HIT: ${DEBUG_LATEST} is '${DEBUG_LINK:-ABSENT}'"
fi
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- "\*\*unchanged\*\* → \`${LEFTOVER_NAME}\`" "${DEBUG_DOC}" || \
     rg -q -- "still \`${LEFTOVER_NAME}\`" "${DEBUG_DOC}"; then
    hold "${DEBUG_DOC} still names ${LEFTOVER_NAME} on a komodo-latest sentence; live pointer is ${LATEST_TARGET} (sentence not rewritten)"
  else
    pass "${DEBUG_DOC} does not bind komodo-latest to ${LEFTOVER_NAME}"
  fi
fi
if [[ -f "${STAMP_README}" ]] && rg -q -- "${LEFTOVER_NAME}" "${STAMP_README}"; then
  hold "${STAMP_README} still names ${LEFTOVER_NAME}; live komodo-latest is ${LATEST_TARGET} (stamp README not rewritten)"
else
  pass "${STAMP_README} does not name ${LEFTOVER_NAME} as komodo-latest"
fi

echo
echo "--- documented A/B four: leftover must match the documented digest ---"
AB_EQUAL=0
AB_HOLD=0
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
  if [[ "${h_left}" != "${want}" ]]; then
    fail "${f} leftover digest changed (do not invent a hash)"
  elif [[ "${h_out}" != "${want}" ]]; then
    hold "${f} leftover matches documented digest; out/ does not (user image replaced boot images; digest not invented)"
    AB_HOLD=$((AB_HOLD + 1))
    if [[ "${h_stamp}" == "${want}" ]]; then
      pass "${f} stamp matches documented leftover digest (not rewritten)"
    else
      hold "${f} stamp does not match documented digest (not rewritten, not invented)"
    fi
  elif [[ "${h_stamp}" == "${want}" ]] && \
       cmp -s "${OUT_DIR}/${f}" "${STAMP_DIR}/${f}" && \
       cmp -s "${STAMP_DIR}/${f}" "${LEFTOVER_DIR}/${f}"; then
    pass "${f} SHA+cmp out=stamp=leftover=doc (HOLD residual, not a rebuild claim)"
    AB_EQUAL=$((AB_EQUAL + 1))
  else
    fail "${f} SHA mismatch vs documented leftover (do not invent a fake hash)"
  fi
  if rg -q -- "${want}" "${DEBUG_DOC}" && rg -q -- "${want}" "${STAMP_README}"; then
    pass "both docs name leftover digest for ${f}"
  else
    fail "missing documented digest for ${f} in advertise and/or stamp README"
  fi
done
echo "AB_FOUR_LEFTOVER_SHA=${AB_EQUAL}"
echo "AB_FOUR_OUT_HOLD=${AB_HOLD}"
if [[ $((AB_EQUAL + AB_HOLD)) -eq 4 ]]; then
  if [[ "${AB_HOLD}" -gt 0 ]]; then
    hold "A/B leftover digests match the documented hash; out/ drift is HOLD (${AB_HOLD} file(s)); digest not invented"
  else
    pass "A/B four leftover SHA residual rematched 4/4"
  fi
else
  fail "A/B four leftover digest rematch count $((AB_EQUAL + AB_HOLD)) != 4"
fi

echo
echo "--- SHA256SUMS 20/20 on stamp (integrity; not USB) ---"
if [[ -f "${STAMP_DIR}/SHA256SUMS" ]]; then
  if (cd "${STAMP_DIR}" && sha256sum -c SHA256SUMS --quiet); then
    SUM_N="$(wc -l < "${STAMP_DIR}/SHA256SUMS" | tr -d ' ')"
    if [[ "${SUM_N}" == "20" ]]; then
      pass "stamp SHA256SUMS 20/20"
    else
      fail "stamp SHA256SUMS line count ${SUM_N} != 20"
    fi
  else
    fail "stamp SHA256SUMS verify failed"
  fi
else
  fail "missing ${STAMP_DIR}/SHA256SUMS"
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
  if rg -q -- 'FLASH_READY\s*=\s*true' "${TYPES}"; then
    fail "NEGATIVE HIT: ${TYPES} assigns FLASH_READY=true"
  else
    pass "${TYPES} does not assign FLASH_READY=true"
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
echo "--- leftover honesty surfaces (DEC-018 bind; was HOLD residual) ---"
if [[ -f "${INSTALL_README}" ]]; then
  pass "${INSTALL_README} exists"
  if rg -q -- 'DEBUG_FLASH_READY` is \*\*false\*\*' "${INSTALL_README}"; then
    pass "${INSTALL_README} binds DEBUG_FLASH_READY **false**"
  else
    fail "${INSTALL_README} missing DEBUG_FLASH_READY **false**"
  fi
  if rg -q -- 'DEBUG_FLASH_READY` is \*\*true\*\*' "${INSTALL_README}"; then
    fail "NEGATIVE HIT: ${INSTALL_README} claims DEBUG_FLASH_READY **true**"
  else
    pass "${INSTALL_README} does not claim DEBUG_FLASH_READY **true**"
  fi
  if rg -q -- '`USB_GO` stays' "${INSTALL_README}" && \
     rg -q -- 'No USB GO' "${INSTALL_README}"; then
    pass "${INSTALL_README} USB_GO stays **false**; No USB GO"
  else
    fail "${INSTALL_README} missing USB_GO=false / No USB GO"
  fi
  if rg -q -- 'Signed-user `FLASH_READY` stays \*\*false\*\*' "${INSTALL_README}"; then
    pass "${INSTALL_README} signed-user FLASH_READY stays **false**"
  else
    fail "${INSTALL_README} missing signed-user FLASH_READY **false**"
  fi
  if rg -q -- 'leftover SHA' "${INSTALL_README}" && \
     rg -q -- 'HOLD residual' "${INSTALL_README}"; then
    pass "${INSTALL_README} still mentions leftover SHA HOLD residual"
  else
    fail "${INSTALL_README} missing leftover SHA HOLD residual"
  fi
  if rg -q -- 'Do not retarget `komodo-latest`' "${INSTALL_README}" && \
     rg -q -- "${LEFTOVER_NAME}" "${INSTALL_README}"; then
    pass "${INSTALL_README} does not retarget komodo-latest; stale ${LEFTOVER_NAME} stays denied"
  else
    fail "${INSTALL_README} missing do-not-retarget / stale ${LEFTOVER_NAME} denial"
  fi
  if rg -q -- 'USB_GO` \| \*\*true\*\*|USB_GO=true|USB_GO:\*\* true' "${INSTALL_README}"; then
    fail "NEGATIVE HIT: ${INSTALL_README} invents USB_GO true"
  else
    pass "${INSTALL_README} does not invent USB_GO true"
  fi
  if rg -q -- '(^|[^_])FLASH_READY=true|`FLASH_READY` stays \*\*true\*\*' \
    "${INSTALL_README}"; then
    fail "NEGATIVE HIT: ${INSTALL_README} invents FLASH_READY true"
  else
    pass "${INSTALL_README} does not invent FLASH_READY true"
  fi
else
  fail "missing ${INSTALL_README}"
fi
if [[ -f "${SIDECAR}" ]]; then
  pass "${SIDECAR} exists"
  if rg -q -- 'DEBUG_FLASH_READY=false' "${SIDECAR}"; then
    pass "${SIDECAR} binds DEBUG_FLASH_READY=false"
  else
    fail "${SIDECAR} missing DEBUG_FLASH_READY=false"
  fi
  if rg -q -- 'DEBUG_FLASH_READY=true' "${SIDECAR}"; then
    fail "NEGATIVE HIT: ${SIDECAR} claims DEBUG_FLASH_READY=true"
  else
    pass "${SIDECAR} does not claim DEBUG_FLASH_READY=true"
  fi
  if rg -q -- 'USB_GO=false' "${SIDECAR}"; then
    pass "${SIDECAR} USB_GO=false"
  else
    fail "${SIDECAR} missing USB_GO=false"
  fi
  if rg -q -- '`FLASH_READY=false`' "${SIDECAR}"; then
    pass "${SIDECAR} FLASH_READY=false"
  else
    fail "${SIDECAR} missing FLASH_READY=false"
  fi
  if rg -q -- 'leftover SHA HOLD residual' "${SIDECAR}"; then
    pass "${SIDECAR} still mentions leftover SHA HOLD residual"
  else
    fail "${SIDECAR} missing leftover SHA HOLD residual"
  fi
  if rg -q -- 'do not retarget `komodo-latest`' "${SIDECAR}"; then
    pass "${SIDECAR} does not retarget komodo-latest"
  else
    fail "${SIDECAR} missing do not retarget komodo-latest"
  fi
  if rg -q -- 'USB_GO=true' "${SIDECAR}"; then
    fail "NEGATIVE HIT: ${SIDECAR} invents USB_GO=true"
  else
    pass "${SIDECAR} does not invent USB_GO=true"
  fi
  if rg -q -- '(^|[^_])FLASH_READY=true' "${SIDECAR}"; then
    fail "NEGATIVE HIT: ${SIDECAR} invents FLASH_READY=true"
  else
    pass "${SIDECAR} does not invent FLASH_READY=true"
  fi
else
  fail "missing ${SIDECAR}"
fi

echo
echo "--- adb (device HOLD; do not start Q-ONDEVICE) ---"
ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "${ADB_OUT}"
if echo "${ADB_OUT}" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  hold "adb sees a device — advertise rematch is host-only; USB GO not started"
else
  hold "adb devices empty — not device-fixed; on-device working not invented"
fi

# Sidecar advertise stays false. Signed-user ready stays false.
# This rematch never starts USB GO and never lifts either flag.
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
