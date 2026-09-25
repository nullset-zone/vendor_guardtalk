#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-FLASH-HONESTY (DEC-REMEDIATE-010).
# Pair of F-REMEDIATE-FLASH-HONESTY. Do not trust Frontend or Architect dumps.
# Host static only. No USB GO. No m. No retarget. Do not invent FLASH_READY=true.
#
# Proves advertise honesty:
#   LIVE_FLASH_CLAIMED=false
#   stamp README + installer do not claim komodo-20260915-063833 is a signed
#     user FLASH_READY image
#   komodo-latest still points at that stamp (not retargeted)
#   tokay+akita+komodo listed; no new SKU
#   FLASH_READY=true absent except negative tests
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_flash_honesty_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

TYPES="vendor/guardtalk/web-installer/src/types.ts"
DIST_TYPES="vendor/guardtalk/web-installer/dist/src/types.js"
OFFERED="vendor/guardtalk/web-installer/lib/ui/offered-devices.ts"
STAMP_README="releases/desktop-flash/komodo-20260915-063833/README-FLASH-DESKTOP.md"
INSTALL_README="vendor/guardtalk/web-installer/README.md"
WIZARD_HTML="vendor/guardtalk/web-installer/wizard/index.html"
EARLY="vendor/guardtalk/web-installer/routes/install/early-steps.ts"
LATEST="releases/desktop-flash/komodo-latest"
STAMP_NAME="komodo-20260915-063833"
TEST_DIR="vendor/guardtalk/web-installer/test"

# Product/advertise surfaces (not tests). FLASH_READY=true here is a lie.
ADVERTISE_FILES=(
  "${TYPES}"
  "${DIST_TYPES}"
  "${OFFERED}"
  "${STAMP_README}"
  "${INSTALL_README}"
  "${WIZARD_HTML}"
  "${EARLY}"
)

echo "=== Q-REMEDIATE-FLASH-HONESTY independent rematch (DEC-010 advertise) ==="
echo "ROOT=${ROOT}"
echo "LIVE_FLASH_CLAIMED=unverified (computed below)"
echo "FLASH_READY=false (not invented; honesty rematch does not lift image PASS)"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "ONDEVICE=not started"
echo "PASS_HOLD=remains"
echo

echo "--- hygiene: this suite must not start m / USB / ondevice ---"
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
if rg -n -- "LIVE_FLASH_CLAIMED" "${TYPES}" >/dev/null; then
  rg -n -- "LIVE_FLASH_CLAIMED" "${TYPES}"
  pass "rg LIVE_FLASH_CLAIMED hit ${TYPES}"
else
  fail "rg LIVE_FLASH_CLAIMED missed ${TYPES}"
fi
if rg -n -- "FLASH_READY" "${STAMP_README}" >/dev/null; then
  rg -n -- "FLASH_READY" "${STAMP_README}"
  pass "rg FLASH_READY hit ${STAMP_README}"
else
  fail "rg FLASH_READY missed ${STAMP_README}"
fi
LATEST_LINK="$(readlink "${LATEST}" 2>/dev/null || true)"
echo "readlink ${LATEST} => ${LATEST_LINK}"

echo
echo "--- LIVE_FLASH_CLAIMED=false (source of truth + served dist) ---"
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
echo "--- stamp README does not claim signed-user FLASH_READY ---"
if [[ -f "${STAMP_README}" ]]; then
  if rg -q -- 'FLASH_READY=false' "${STAMP_README}"; then
    pass "${STAMP_README} states FLASH_READY=false"
  else
    fail "${STAMP_README} missing FLASH_READY=false"
  fi
  if rg -q -- 'not.*signed.*user' "${STAMP_README}"; then
    pass "${STAMP_README} denies signed-user FLASH_READY for this stamp"
  else
    fail "${STAMP_README} missing signed-user denial"
  fi
  if rg -q -- 'LIVE_FLASH_CLAIMED=false' "${STAMP_README}"; then
    pass "${STAMP_README} states LIVE_FLASH_CLAIMED=false"
  else
    fail "${STAMP_README} missing LIVE_FLASH_CLAIMED=false"
  fi
  if rg -q -- 'FLASH_READY=true' "${STAMP_README}"; then
    fail "NEGATIVE HIT: ${STAMP_README} claims FLASH_READY=true"
  else
    pass "${STAMP_README} has no FLASH_READY=true"
  fi
  if rg -q -- "${STAMP_NAME}" "${STAMP_README}"; then
    pass "${STAMP_README} names ${STAMP_NAME}"
  else
    fail "${STAMP_README} does not name ${STAMP_NAME}"
  fi
else
  fail "missing ${STAMP_README}"
fi

echo
echo "--- installer advertise does not claim signed-user FLASH_READY ---"
if [[ -f "${OFFERED}" ]]; then
  if rg -q -- 'KOMODO_STAMP_HONESTY' "${OFFERED}" && \
     rg -q -- "${STAMP_NAME}" "${OFFERED}" && \
     rg -q -- 'not a signed user FLASH_READY image' "${OFFERED}" && \
     rg -q -- 'LIVE_FLASH_CLAIMED=false' "${OFFERED}"; then
    pass "KOMODO_STAMP_HONESTY names ${STAMP_NAME} and denies signed-user FLASH_READY"
  else
    fail "KOMODO_STAMP_HONESTY missing stamp name or signed-user denial"
  fi
  if rg -q -- 'FLASH_READY=true' "${OFFERED}"; then
    fail "NEGATIVE HIT: ${OFFERED} claims FLASH_READY=true"
  else
    pass "${OFFERED} has no FLASH_READY=true"
  fi
else
  fail "missing ${OFFERED}"
fi
if [[ -f "${INSTALL_README}" ]]; then
  INSTALL_WINDOW="$(rg -A2 -- "${STAMP_NAME}" "${INSTALL_README}" || true)"
  if echo "${INSTALL_WINDOW}" | rg -q -- 'signed user' && \
     echo "${INSTALL_WINDOW}" | rg -q -- 'not'; then
    pass "${INSTALL_README} names ${STAMP_NAME} and denies signed user FLASH_READY"
  else
    fail "${INSTALL_README} missing stamp honesty paragraph"
  fi
  if rg -q -- 'FLASH_READY=true' "${INSTALL_README}"; then
    fail "NEGATIVE HIT: ${INSTALL_README} claims FLASH_READY=true"
  else
    pass "${INSTALL_README} has no FLASH_READY=true"
  fi
else
  fail "missing ${INSTALL_README}"
fi
if [[ -f "${WIZARD_HTML}" ]]; then
  if rg -q -- 'data-dec="010"' "${WIZARD_HTML}" && \
     rg -q -- "${STAMP_NAME}" "${WIZARD_HTML}" && \
     rg -q -- 'FLASH_READY=false' "${WIZARD_HTML}" && \
     rg -q -- 'LIVE_FLASH_CLAIMED=false' "${WIZARD_HTML}"; then
    pass "wizard data-dec=010 banner names stamp and FLASH_READY=false"
  else
    fail "wizard missing DEC-010 honesty banner"
  fi
  if rg -q -- 'FLASH_READY=true' "${WIZARD_HTML}"; then
    fail "NEGATIVE HIT: ${WIZARD_HTML} claims FLASH_READY=true"
  else
    pass "${WIZARD_HTML} has no FLASH_READY=true"
  fi
else
  fail "missing ${WIZARD_HTML}"
fi
if [[ -f "${EARLY}" ]]; then
  if rg -q -- 'KOMODO_STAMP_HONESTY' "${EARLY}"; then
    pass "${EARLY} injects KOMODO_STAMP_HONESTY into advertise note"
  else
    fail "${EARLY} does not inject KOMODO_STAMP_HONESTY"
  fi
else
  fail "missing ${EARLY}"
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
echo "--- tokay+akita+komodo listed; no new SKU ---"
if [[ -f "${OFFERED}" ]]; then
  for sku in tokay akita komodo; do
    if rg -q -- "id: \"${sku}\"" "${OFFERED}"; then
      pass "WIZARD_DEVICES lists ${sku}"
    else
      fail "WIZARD_DEVICES missing ${sku}"
    fi
  done
  NEW_SKU_HIT="$(rg -n -- 'id: "(shiba|husky|caiman|tegu|comet)"' "${OFFERED}" || true)"
  if [[ -n "${NEW_SKU_HIT}" ]]; then
    fail "NEGATIVE HIT: new SKU offered: ${NEW_SKU_HIT}"
  else
    pass "WIZARD_DEVICES has no shiba/husky/caiman/tegu/comet id"
  fi
  if rg -q -- 'id: "rango"' "${OFFERED}" && \
     rg -q -- 'experimental / boot HOLD' "${OFFERED}"; then
    pass "rango remains experimental / boot HOLD (pre-existing; not a new SKU)"
  else
    hold "rango advertise text missing experimental HOLD chip (pre-existing set)"
  fi
else
  fail "cannot rematch SKU list; ${OFFERED} missing"
fi
if [[ -f "${TYPES}" ]]; then
  if rg -q -- 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo", "rango"\]' "${TYPES}"; then
    pass "ALLOWED_PRODUCTS is tokay+akita+komodo+rango (no new SKU)"
  else
    fail "ALLOWED_PRODUCTS allowlist drifted (new SKU or missing listed SKU)"
  fi
fi

echo
echo "--- FLASH_READY=true absent except negative tests ---"
PRODUCT_TRUE=""
for f in "${ADVERTISE_FILES[@]}"; do
  if [[ -f "${f}" ]] && rg -q -- 'FLASH_READY=true' "${f}"; then
    PRODUCT_TRUE+="${f} "
  fi
done
if [[ -n "${PRODUCT_TRUE}" ]]; then
  fail "NEGATIVE HIT: FLASH_READY=true on advertise surface: ${PRODUCT_TRUE}"
else
  pass "FLASH_READY=true absent from stamp README + installer advertise sources"
fi

if [[ -d "${TEST_DIR}" ]]; then
  POS_TEST="$(rg -n -- 'FLASH_READY=true' "${TEST_DIR}" | rg -v 'doesNotMatch' || true)"
  NEG_TEST="$(rg -n -- 'doesNotMatch.*FLASH_READY=true' "${TEST_DIR}" || true)"
  if [[ -n "${POS_TEST}" ]]; then
    fail "NEGATIVE HIT: test asserts FLASH_READY=true as a positive claim: ${POS_TEST}"
  else
    pass "no test asserts FLASH_READY=true as a positive claim"
  fi
  if [[ -n "${NEG_TEST}" ]]; then
    pass "FLASH_READY=true appears only as doesNotMatch negative tests"
  else
    hold "no doesNotMatch FLASH_READY=true negative tests found"
  fi
else
  hold "${TEST_DIR} ABSENT"
fi

echo
echo "--- residual advertise drift (not a FLASH_READY lie; not a new SKU) ---"
if [[ -f "${INSTALL_README}" ]]; then
  if rg -q -- 'rango.*are not' "${INSTALL_README}"; then
    hold "${INSTALL_README} still says rango is not offered (stale vs WIZARD_DEVICES; DEC-WEBINSTALL-015 residual; not FLASH_READY=true)"
  else
    pass "${INSTALL_README} allowlist no longer denies rango"
  fi
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

# Honesty rematch never lifts FLASH_READY. Stamp remains userdebug/test-keys.
FLASH_READY=false
if [[ "${FAIL}" -ne 0 ]]; then
  FLASH_CLASS="FAIL"
else
  FLASH_CLASS="HOLD"
fi

echo
echo "LIVE_FLASH_CLAIMED=false"
echo "FLASH_READY=${FLASH_READY}"
echo "FLASH_CLASS=${FLASH_CLASS}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
echo "USB_GO=not started"
echo "ONDEVICE=not started"
echo "KOMODO_LATEST=${LATEST_LINK}"
echo "RESULT: $([[ "${FAIL}" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=$([[ "${FAIL}" -eq 0 ]] && echo 0 || echo 1)"
exit "${FAIL}"
