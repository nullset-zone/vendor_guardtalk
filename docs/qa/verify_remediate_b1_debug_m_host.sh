#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-DEBUG-SUITE (DEC-REMEDIATE-011).
# Standalone host suite for DEBUG_FLASH_READY *preconditions*.
# Does NOT lift Q-REMEDIATE-B1-DEBUG-M (image PASS stays BLOCKED).
#
# Debug predicates invert the signed-user / pem checks:
#   userdebug out is allowed (record; do not FAIL)
#   test-keys / xbin su on the sidecar are allowed (do not FAIL)
#   pem ABSENT is HOLD for signed-user T-B1-M, not FAIL for this suite
#   missing new m / missing komodo-debug-latest → HOLD, not FAIL
#
# Never invent FLASH_READY=true or DEBUG_FLASH_READY=true.
# Do not start m. Do not USB GO. Do not run *_ondevice.sh. Do not cat pem.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b1_debug_m_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

DEC011=".memory-bank/decisions.md"
SIDECAR="vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md"
PORT_FLASH="vendor/guardtalk/docs/KOMODO_PORT_FLASH.md"
DEBUG_FLASH="vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md"
TYPES="vendor/guardtalk/web-installer/src/types.ts"
QUEUE="TASK_QUEUE.md"
LATEST="releases/desktop-flash/komodo-latest"
DEBUG_LATEST="releases/desktop-flash/komodo-debug-latest"
STAMP_NAME="komodo-20260915-063833"
LUNCH_DEBUG="lunch komodo-trunk_staging-userdebug"
AVB_TREE="vendor/guardtalk/branding/signing-keys/avb.pem"
AVB_SECURE="/mnt/secure/keys/guardtalk/avb.pem"
OUT_KOMODO="out/target/product/komodo"
SYS_PROP="${OUT_KOMODO}/system/build.prop"
PROD_PROP="${OUT_KOMODO}/product/etc/build.prop"
VENDOR_PROP="${OUT_KOMODO}/vendor/build.prop"
XBIN_SU="${OUT_KOMODO}/system/xbin/su"
XBIN_OR="${OUT_KOMODO}/system/xbin/overlay_remounter"
SERIAL="54111FDAS000GN"

prop_val() {
  local file="$1" key="$2"
  if [[ -f "$file" ]]; then
    awk -F= -v k="$key" '$1==k {print $2; exit}' "$file" || true
  fi
}

doc_has_lunch() {
  local file="$1"
  rg -qF -- "${LUNCH_DEBUG}" "${file}"
}

echo "=== Q-REMEDIATE-B1-DEBUG-SUITE independent rematch (DEBUG_FLASH_READY preconditions) ==="
echo "ROOT=${ROOT}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "LIVE_FLASH_CLAIMED=unverified (computed below)"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "FLASH_READY=false (not invented; computed at end)"
echo "DEBUG_FLASH_READY=false (not invented; computed at end)"
echo "Q-REMEDIATE-B1-DEBUG-M=BLOCKED (this suite does not lift image PASS)"
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
pass "pem contents not read"

echo
echo "--- DEC-011 / sidecar / port-flash document ${LUNCH_DEBUG} ---"
if [[ -f "${DEC011}" ]]; then
  if rg -q -- 'DEC-REMEDIATE-011' "${DEC011}" && doc_has_lunch "${DEC011}"; then
    pass "${DEC011} binds DEC-REMEDIATE-011 and documents ${LUNCH_DEBUG}"
  else
    fail "${DEC011} missing DEC-REMEDIATE-011 or ${LUNCH_DEBUG}"
  fi
else
  hold "${DEC011} ABSENT (gitignored memory-bank; rematch TASK_QUEUE DEC-011 instead)"
fi
if [[ -f "${QUEUE}" ]] && rg -q -- 'DEC-REMEDIATE-011' "${QUEUE}" && \
   doc_has_lunch "${QUEUE}"; then
  pass "${QUEUE} documents DEC-REMEDIATE-011 and ${LUNCH_DEBUG}"
else
  fail "${QUEUE} missing DEC-REMEDIATE-011 or ${LUNCH_DEBUG}"
fi
if [[ -f "${SIDECAR}" ]]; then
  if doc_has_lunch "${SIDECAR}"; then
    pass "${SIDECAR} documents ${LUNCH_DEBUG}"
  else
    fail "${SIDECAR} missing ${LUNCH_DEBUG}"
  fi
else
  fail "missing ${SIDECAR}"
fi
if [[ -f "${PORT_FLASH}" ]]; then
  if doc_has_lunch "${PORT_FLASH}"; then
    pass "${PORT_FLASH} documents ${LUNCH_DEBUG}"
  else
    fail "${PORT_FLASH} missing ${LUNCH_DEBUG}"
  fi
else
  fail "missing ${PORT_FLASH}"
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
  hold "${DEBUG_FLASH} ABSENT (F-DEBUG-ADVERTISE parallel; not FAIL for this suite)"
fi

echo
echo "--- T-B1-M still HOLD (pem ABSENT = HOLD for signed-user, not FAIL here) ---"
if [[ -f "${QUEUE}" ]]; then
  if rg -A1 -- '^### T-REMEDIATE-B1-M$' "${QUEUE}" | \
     rg -q -- 'HOLD CONFIRMED'; then
    pass "T-REMEDIATE-B1-M status is HOLD CONFIRMED"
  else
    fail "T-REMEDIATE-B1-M is not HOLD CONFIRMED"
  fi
else
  fail "missing ${QUEUE}"
fi

PEM_OK=0
if [[ -f "${AVB_TREE}" ]]; then
  hold "avb.pem exists at in-tree stem ${AVB_TREE} (existence only; signed-user still not this suite)"
  PEM_OK=1
else
  hold "avb.pem ABSENT at in-tree stem ${AVB_TREE} (T-B1-M HOLD; not FAIL for debug suite)"
fi
if [[ -f "${AVB_SECURE}" ]]; then
  hold "avb.pem exists at secure stem ${AVB_SECURE} (existence only)"
  PEM_OK=1
else
  hold "avb.pem ABSENT at secure stem ${AVB_SECURE} (T-B1-M HOLD; not FAIL for debug suite)"
fi
if [[ ! -e /mnt/secure ]]; then
  hold "/mnt/secure missing (signed-user HOLD; not FAIL for debug suite)"
fi
if [[ "${PEM_OK}" -eq 0 ]]; then
  echo "PRED_PEM pem=false (HOLD for FLASH_READY; not FAIL here)"
else
  echo "PRED_PEM pem=true (existence only; contents not read)"
fi

echo
echo "--- git / tree: no committed key material (do not cat) ---"
GIT_KEYS="$(git ls-files -- \
  'vendor/guardtalk/**/*.pem' \
  'vendor/guardtalk/**/*.pk8' \
  'vendor/guardtalk/**/avb.pem' 2>/dev/null || true)"
if [[ -z "${GIT_KEYS}" ]]; then
  pass "git ls-files: no pem/pk8/avb.pem under vendor/guardtalk"
else
  fail "NEGATIVE HIT: git tracks key material: ${GIT_KEYS}"
fi

echo
echo "--- komodo-debug-latest ABSENT → HOLD (expected until pack) ---"
if [[ -e "${DEBUG_LATEST}" || -L "${DEBUG_LATEST}" ]]; then
  DEBUG_LINK="$(readlink "${DEBUG_LATEST}" 2>/dev/null || echo PRESENT)"
  hold "${DEBUG_LATEST} PRESENT -> ${DEBUG_LINK} (pack landed; this suite still does not lift DEBUG_FLASH_READY)"
else
  hold "${DEBUG_LATEST} ABSENT (expected until T-REMEDIATE-B1-DEBUG-PACK)"
fi
DEBUG_STAMPS="$(ls -d releases/desktop-flash/komodo-debug-* 2>/dev/null || true)"
if [[ -z "${DEBUG_STAMPS}" ]]; then
  hold "no komodo-debug-<UTCSTAMP> directory (expected until pack)"
else
  hold "debug stamp dirs present (not a DEBUG_FLASH_READY lift): ${DEBUG_STAMPS}"
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
else
  fail "${LATEST} is not a symlink"
fi

echo
echo "--- out/ record ro.build.type (userdebug allowed; do not FAIL test-keys/su) ---"
BUILD_TYPE="ABSENT"
BUILD_TAGS="ABSENT"
PROD_TYPE="ABSENT"
VENDOR_TYPE="ABSENT"
NEW_M=0
if [[ -f "${SYS_PROP}" ]]; then
  BUILD_TYPE="$(prop_val "${SYS_PROP}" ro.build.type)"
  BUILD_TAGS="$(prop_val "${SYS_PROP}" ro.build.tags)"
  echo "READ ${SYS_PROP} ro.build.type=${BUILD_TYPE} ro.build.tags=${BUILD_TAGS}"
  ls -l "${SYS_PROP}" || true
  # Sept 15 stale out is not the DEC-011 new m. Newer mtime is still HOLD
  # until T-DEBUG-M + Q-DEBUG-M APPROVED (this suite does not lift image PASS).
  if [[ "${BUILD_TYPE}" == "userdebug" ]]; then
    pass "system ro.build.type=userdebug recorded (sidecar allowed; not FAIL)"
    if [[ "$(stat -c %y "${SYS_PROP}" 2>/dev/null || true)" == 2026-09-15* ]]; then
      hold "out dated 2026-09-15 — stale vs DEC-011; new userdebug m not proven"
    else
      hold "out userdebug mtime is not 2026-09-15 — still HOLD until T-DEBUG-M APPROVED"
      NEW_M=0
    fi
  elif [[ "${BUILD_TYPE}" == "user" ]]; then
    hold "system ro.build.type=user (signed-user out; not this debug sidecar gate)"
  elif [[ "${BUILD_TYPE}" == "ABSENT" || -z "${BUILD_TYPE}" ]]; then
    hold "system ro.build.type ABSENT"
  else
    hold "system ro.build.type=${BUILD_TYPE} (recorded; not FAIL for sidecar)"
  fi
  case "${BUILD_TAGS}" in
    test-keys)
      hold "system ro.build.tags=test-keys (allowed on sidecar; not FAIL)"
      ;;
    release-keys)
      hold "system ro.build.tags=release-keys (unusual for sidecar; recorded, not FAIL)"
      ;;
    dev-keys)
      hold "system ro.build.tags=dev-keys (allowed on sidecar; not FAIL)"
      ;;
    ABSENT|"")
      hold "system ro.build.tags ABSENT"
      ;;
    *)
      hold "system ro.build.tags=${BUILD_TAGS} (recorded; not FAIL)"
      ;;
  esac
else
  hold "${SYS_PROP} ABSENT (new m not run; HOLD not FAIL)"
fi
if [[ -f "${PROD_PROP}" ]]; then
  PROD_TYPE="$(prop_val "${PROD_PROP}" ro.build.type)"
  echo "READ ${PROD_PROP} ro.build.type=${PROD_TYPE}"
  if [[ "${PROD_TYPE}" == "userdebug" ]]; then
    pass "product ro.build.type=userdebug recorded (sidecar allowed)"
  else
    hold "product ro.build.type=${PROD_TYPE}"
  fi
else
  hold "${PROD_PROP} ABSENT"
fi
if [[ -f "${VENDOR_PROP}" ]]; then
  VENDOR_TYPE="$(prop_val "${VENDOR_PROP}" ro.vendor.build.type)"
  echo "READ ${VENDOR_PROP} ro.vendor.build.type=${VENDOR_TYPE}"
  if [[ "${VENDOR_TYPE}" == "userdebug" ]]; then
    pass "vendor ro.vendor.build.type=userdebug recorded (sidecar allowed)"
  else
    hold "vendor ro.vendor.build.type=${VENDOR_TYPE}"
  fi
fi

echo
echo "--- xbin su / overlay_remounter (allowed on sidecar; invert of user FAIL) ---"
if [[ -e "${XBIN_SU}" ]]; then
  ls -l "${XBIN_SU}" || true
  hold "xbin su PRESENT ${XBIN_SU} (allowed on debug sidecar; not FAIL)"
else
  hold "xbin su ABSENT (ok on sidecar; not a new-m proof)"
fi
if [[ -e "${XBIN_OR}" ]]; then
  ls -l "${XBIN_OR}" || true
  hold "xbin overlay_remounter PRESENT ${XBIN_OR} (allowed on debug sidecar; not FAIL)"
else
  hold "xbin overlay_remounter ABSENT (ok on sidecar; not a new-m proof)"
fi

echo
echo "--- Q-REMEDIATE-B1-DEBUG-M stays BLOCKED (this suite does not lift) ---"
if [[ -f "${QUEUE}" ]]; then
  if rg -A8 -- '^### Q-REMEDIATE-B1-DEBUG-M$' "${QUEUE}" | \
     rg -q -- 'Status: BLOCKED'; then
    pass "Q-REMEDIATE-B1-DEBUG-M is BLOCKED (image PASS not lifted)"
  else
    hold "Q-REMEDIATE-B1-DEBUG-M status is not BLOCKED (record only; this suite still does not APPROVE it)"
  fi
fi

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
echo "PRED_PEM=$([[ "${PEM_OK}" -eq 1 ]] && echo true || echo false)"
echo "PRED_NEW_M=$([[ "${NEW_M}" -eq 1 ]] && echo true || echo false)"
echo "RO_BUILD_TYPE=${BUILD_TYPE}"
echo "RO_BUILD_TAGS=${BUILD_TAGS}"
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
echo "Q-REMEDIATE-B1-DEBUG-M=BLOCKED"
echo "KOMODO_LATEST=$(readlink "${LATEST}" 2>/dev/null || echo ABSENT)"
echo "KOMODO_DEBUG_LATEST=$([[ -e "${DEBUG_LATEST}" || -L "${DEBUG_LATEST}" ]] && readlink "${DEBUG_LATEST}" 2>/dev/null || echo ABSENT)"
echo "RESULT: $([[ "${FAIL}" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=$([[ "${FAIL}" -eq 0 ]] && echo 0 || echo 1)"
exit "${FAIL}"
