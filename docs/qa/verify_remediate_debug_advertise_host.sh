#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-DEBUG-ADVERTISE (DEC-REMEDIATE-011).
# Pair of F-REMEDIATE-DEBUG-ADVERTISE (APPROVED). Do not trust Frontend
# or Architect dumps.
# Host static only. No USB GO. No m. No retarget. Do not invent
# DEBUG_FLASH_READY=true or FLASH_READY=true.
#
# Distinct from Q-REMEDIATE-B1-DEBUG-SUITE
# (verify_remediate_b1_debug_m_host.sh). Do not overwrite that file.
#
# Proves debug-path advertise honesty:
#   KOMODO_DEBUG_FLASH.md exists; current DEBUG_FLASH_READY=false
#   FLASH_READY=false (signed-user; documentary)
#   LIVE_FLASH_CLAIMED=false at src/types.ts:119
#   komodo-latest still → komodo-20260915-063833
#   komodo-debug-latest ABSENT (not invented)
#   debug sidecar distinguished from signed-user FLASH_READY
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_debug_advertise_host.sh
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
DEBUG_DOC="vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md"
SIDECAR="vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md"
INSTALL_README="vendor/guardtalk/web-installer/README.md"
TYPES="vendor/guardtalk/web-installer/src/types.ts"
DIST_TYPES="vendor/guardtalk/web-installer/dist/src/types.js"
LATEST="releases/desktop-flash/komodo-latest"
DEBUG_LATEST="releases/desktop-flash/komodo-debug-latest"
STAMP_NAME="komodo-20260915-063833"
HONESTY_FILES=(
  "${DEBUG_DOC}"
  "${SIDECAR}"
  "${INSTALL_README}"
)

echo "=== Q-REMEDIATE-DEBUG-ADVERTISE independent rematch (DEC-011) ==="
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

echo "--- hygiene: distinct script; do not collide with Q-B1-DEBUG-SUITE ---"
if [[ "$(basename "${SELF}")" == "verify_remediate_b1_debug_m_host.sh" ]]; then
  fail "this suite collided with verify_remediate_b1_debug_m_host.sh"
else
  pass "basename is verify_remediate_debug_advertise_host.sh (distinct)"
fi
if [[ -f "${SIBLING_DEBUG_M}" ]]; then
  pass "${SIBLING_DEBUG_M} still present (not overwritten)"
else
  fail "${SIBLING_DEBUG_M} missing (collision / overwrite?)"
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
echo "--- packet verification commands (independent) ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  rg -n -- "DEBUG_FLASH_READY" "${DEBUG_DOC}"
  pass "rg DEBUG_FLASH_READY hit ${DEBUG_DOC}"
else
  fail "missing ${DEBUG_DOC}"
fi
if rg -n -- "LIVE_FLASH_CLAIMED" "${TYPES}" >/dev/null; then
  rg -n -- "LIVE_FLASH_CLAIMED" "${TYPES}"
  pass "rg LIVE_FLASH_CLAIMED hit ${TYPES}"
else
  fail "rg LIVE_FLASH_CLAIMED missed ${TYPES}"
fi
LATEST_LINK="$(readlink "${LATEST}" 2>/dev/null || true)"
echo "readlink ${LATEST} => ${LATEST_LINK}"
if [[ -e "${DEBUG_LATEST}" || -L "${DEBUG_LATEST}" ]]; then
  echo "komodo-debug-latest PRESENT ($(ls -ld "${DEBUG_LATEST}" 2>/dev/null || true))"
else
  echo "komodo-debug-latest ABSENT"
fi

echo
echo "--- KOMODO_DEBUG_FLASH.md exists; current flags false ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  pass "${DEBUG_DOC} exists"
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
else
  fail "missing ${DEBUG_DOC}"
fi

echo
echo "--- distinguishes debug sidecar vs signed-user FLASH_READY ---"
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- '\*\*Signed user\*\*' "${DEBUG_DOC}" && \
     rg -q -- '\*\*Debug sidecar\*\*' "${DEBUG_DOC}" && \
     rg -q -- 'komodo-trunk_staging-userdebug' "${DEBUG_DOC}" && \
     rg -q -- 'komodo-trunk_staging-user' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} names signed-user vs debug-sidecar lunches"
  else
    fail "${DEBUG_DOC} missing signed-user vs debug-sidecar distinction"
  fi
  if rg -q -- 'Do not treat `komodo-20260915-063833` as the DEC-011 debug flash gate' \
    "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} denies stale ${STAMP_NAME} as this debug gate"
  else
    fail "${DEBUG_DOC} missing stale-stamp denial"
  fi
  if rg -q -- 'It is \*\*not\*\* a signed-user FLASH_READY claim' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} denies signed-user FLASH_READY for the debug channel"
  else
    fail "${DEBUG_DOC} missing signed-user FLASH_READY denial"
  fi
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
    pass "${TYPES} does not assign FLASH_READY=true (FLASH_READY is documentary false)"
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
echo "--- README DEC-011 + sidecar pointer ---"
if [[ -f "${INSTALL_README}" ]]; then
  if rg -q -- '\*\*DEC-011:\*\*' "${INSTALL_README}" && \
     rg -q -- 'DEBUG_FLASH_READY` is \*\*false\*\*' "${INSTALL_README}" && \
     rg -q -- 'komodo-debug-latest' "${INSTALL_README}" && \
     rg -q -- 'Do not retarget' "${INSTALL_README}" && \
     rg -q -- 'KOMODO_DEBUG_FLASH.md' "${INSTALL_README}"; then
    pass "${INSTALL_README} DEC-011 paragraph: DEBUG_FLASH_READY false; no retarget"
  else
    fail "${INSTALL_README} missing DEC-011 honesty paragraph"
  fi
else
  fail "missing ${INSTALL_README}"
fi
if [[ -f "${SIDECAR}" ]]; then
  if rg -q -- 'DEBUG_FLASH_READY=false' "${SIDECAR}" && \
     rg -q -- 'KOMODO_DEBUG_FLASH.md' "${SIDECAR}" && \
     rg -q -- 'do not retarget' "${SIDECAR}"; then
    pass "${SIDECAR} points at KOMODO_DEBUG_FLASH.md; DEBUG_FLASH_READY=false"
  else
    fail "${SIDECAR} missing DEC-011 pointer / DEBUG_FLASH_READY=false"
  fi
  if rg -q -- 'komodo-trunk_staging-user`' "${SIDECAR}" && \
     rg -q -- 'komodo-trunk_staging-userdebug' "${SIDECAR}"; then
    pass "${SIDECAR} still distinguishes production user vs sidecar userdebug"
  else
    fail "${SIDECAR} lost user vs userdebug distinction"
  fi
else
  fail "missing ${SIDECAR}"
fi

echo
echo "--- komodo-latest still points at ${STAMP_NAME} (not retargeted) ---"
if [[ -L "${LATEST}" ]]; then
  if [[ "${LATEST_LINK}" == "${STAMP_NAME}" ]]; then
    pass "${LATEST} -> ${STAMP_NAME} (relative symlink; not retargeted)"
  else
    fail "NEGATIVE HIT: ${LATEST} retargeted to '${LATEST_LINK}' (want ${STAMP_NAME})"
  fi
else
  fail "${LATEST} is not a symlink"
fi

echo
echo "--- komodo-debug-latest ABSENT (not invented) ---"
DEBUG_HITS="$(ls -d releases/desktop-flash/komodo-debug-* 2>/dev/null || true)"
if [[ -e "${DEBUG_LATEST}" || -L "${DEBUG_LATEST}" ]]; then
  fail "NEGATIVE HIT: ${DEBUG_LATEST} invented (want ABSENT)"
else
  pass "${DEBUG_LATEST} ABSENT (not invented)"
fi
if [[ -n "${DEBUG_HITS}" ]]; then
  fail "NEGATIVE HIT: invented debug stamp path(s): ${DEBUG_HITS}"
else
  pass "no releases/desktop-flash/komodo-debug-* stamp invented"
fi

echo
echo "--- current-value READY=true absent from honesty surfaces ---"
# Denial lists may mention FLAG=true as a thing listing is not.
# Fail only on current-value claims: table **true** or FLAG is **true**.
CURRENT_TRUE=""
for f in "${HONESTY_FILES[@]}"; do
  if [[ -f "${f}" ]]; then
    if rg -q -- 'DEBUG_FLASH_READY` is \*\*true\*\*|DEBUG_FLASH_READY=true[^.]*until|\| `DEBUG_FLASH_READY` \| \*\*true\*\*' "${f}"; then
      CURRENT_TRUE+="${f}:DEBUG "
    fi
    if rg -q -- '\| `FLASH_READY` \| \*\*true\*\*|FLASH_READY` is \*\*true\*\*' "${f}"; then
      CURRENT_TRUE+="${f}:FLASH "
    fi
  fi
done
if [[ -n "${CURRENT_TRUE}" ]]; then
  fail "NEGATIVE HIT: current-value READY=true: ${CURRENT_TRUE}"
else
  pass "honesty docs do not claim current DEBUG_FLASH_READY/FLASH_READY true"
fi
# Denial-list =true is expected in KOMODO_DEBUG_FLASH.md ("listing is not").
if [[ -f "${DEBUG_DOC}" ]]; then
  if rg -q -- 'That listing is \*\*not\*\*' "${DEBUG_DOC}" && \
     rg -q -- '- `DEBUG_FLASH_READY=true`' "${DEBUG_DOC}" && \
     rg -q -- '- `FLASH_READY=true`' "${DEBUG_DOC}" && \
     rg -q -- '- `LIVE_FLASH_CLAIMED=true`' "${DEBUG_DOC}"; then
    pass "${DEBUG_DOC} lists READY=true only as denied claims"
  else
    fail "${DEBUG_DOC} missing denied-claim list for READY=true flags"
  fi
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
echo "KOMODO_DEBUG_LATEST=ABSENT"
echo "RESULT: $([[ "${FAIL}" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=$([[ "${FAIL}" -eq 0 ]] && echo 0 || echo 1)"
exit "${FAIL}"
