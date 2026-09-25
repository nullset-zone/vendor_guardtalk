#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-M-SUITE (DEC-REMEDIATE-010).
# Standalone host suite. Pair T-REMEDIATE-B1-M is NOT APPROVED; do not refuse.
# Does NOT lift Q-REMEDIATE-B1-M (image PASS stays BLOCKED).
#
# Asserts FLASH_READY image predicates:
#   (1) out/ ro.build.type=user
#   (2) no xbin su / overlay_remounter
#   (3) no testkey (out tags + product AVB path)
#   (4) pem used (file exists at a documented stem AND out is not test-keys)
#
# Pem ABSENT or stale userdebug out/ → HOLD, not FAIL.
# Do not invent FLASH_READY=true. Do not start m. Do not USB GO.
# Do not run *_ondevice.sh. Do not cat pem contents.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b1_m_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

AVB_TREE="vendor/guardtalk/branding/signing-keys/avb.pem"
AVB_SECURE="/mnt/secure/keys/guardtalk/avb.pem"
AOSP_TESTKEY="external/avb/test/data/testkey_rsa4096.pem"
LATE="vendor/guardtalk/device/komodo/BoardConfig-excised-late.mk"
OUT_KOMODO="out/target/product/komodo"
SYS_PROP="${OUT_KOMODO}/system/build.prop"
PROD_PROP="${OUT_KOMODO}/product/etc/build.prop"
VENDOR_PROP="${OUT_KOMODO}/vendor/build.prop"
XBIN_SU="${OUT_KOMODO}/system/xbin/su"
XBIN_OR="${OUT_KOMODO}/system/xbin/overlay_remounter"
VBMETA="${OUT_KOMODO}/vbmeta.img"
AVB_PKMD="${OUT_KOMODO}/avb_pkmd.bin"
SERIAL="54111FDAS000GN"

prop_val() {
  local file="$1" key="$2"
  if [[ -f "$file" ]]; then
    awk -F= -v k="$key" '$1==k {print $2; exit}' "$file" || true
  fi
}

echo "=== Q-REMEDIATE-B1-M-SUITE independent rematch (FLASH_READY image predicates) ==="
echo "ROOT=${ROOT}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "FLASH_READY=false (not invented; computed at end)"
echo "Q-REMEDIATE-B1-M=BLOCKED (this suite does not lift image PASS)"
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
TREE_KEYS="$(find vendor/guardtalk \( -name '*.pem' -o -name '*.pk8' \) 2>/dev/null | head || true)"
if [[ -z "${TREE_KEYS}" ]]; then
  pass "find: no *.pem / *.pk8 under vendor/guardtalk (keys stay offline)"
else
  hold "find listed key files under vendor/guardtalk (existence only; contents not read): ${TREE_KEYS}"
fi

echo
echo "--- PRED pem used (existence only; contents not read) ---"
PEM_OK=0
if [[ -f "${AVB_TREE}" ]]; then
  pass "avb.pem exists at in-tree stem ${AVB_TREE} (existence only)"
  PEM_OK=1
else
  hold "avb.pem ABSENT at in-tree stem ${AVB_TREE}"
fi
if [[ -f "${AVB_SECURE}" ]]; then
  pass "avb.pem exists at secure stem ${AVB_SECURE} (existence only)"
  PEM_OK=1
else
  hold "avb.pem ABSENT at secure stem ${AVB_SECURE}"
fi
if [[ ! -e /mnt/secure ]]; then
  hold "/mnt/secure missing"
fi
if [[ "${PEM_OK}" -eq 1 ]]; then
  echo "PRED_PEM pem=true"
else
  hold "pem used=false (no documented stem present; m must not start; no testkey fallback)"
  echo "PRED_PEM pem=false"
fi

echo
echo "--- PRED no testkey (product AVB path; image tags rematched below) ---"
if [[ -f "${LATE}" ]]; then
  if rg -q -- 'BOARD_AVB_KEY_PATH[[:space:]]*[?:]*=.*testkey' "${LATE}"; then
    fail "NEGATIVE HIT: late BoardConfig assigns AOSP testkey as product path"
  else
    pass "late BoardConfig does not assign AOSP testkey as product path"
  fi
  if rg -qF -- "BOARD_AVB_KEY_PATH ?= ${AVB_TREE}" "${LATE}"; then
    pass "late BoardConfig default path is project avb.pem (pem used requires the file + user out)"
  else
    fail "late BoardConfig missing project avb.pem default path"
  fi
  if rg -qF -- "${AOSP_TESTKEY}" "${LATE}" && \
     ! rg -qF -- "${AVB_TREE}" "${LATE}"; then
    fail "NEGATIVE HIT: late mk product path is AOSP testkey only"
  else
    pass "late mk product path is not AOSP testkey-only"
  fi
else
  fail "missing ${LATE}"
fi

echo
echo "--- PRED out ro.build.type=user (stale userdebug = HOLD) ---"
BUILD_TYPE="ABSENT"
BUILD_TAGS="ABSENT"
PROD_TYPE="ABSENT"
PROD_TAGS="ABSENT"
VENDOR_TYPE="ABSENT"
VENDOR_TAGS="ABSENT"
if [[ -f "${SYS_PROP}" ]]; then
  BUILD_TYPE="$(prop_val "${SYS_PROP}" ro.build.type)"
  BUILD_TAGS="$(prop_val "${SYS_PROP}" ro.build.tags)"
  echo "READ ${SYS_PROP} ro.build.type=${BUILD_TYPE} ro.build.tags=${BUILD_TAGS}"
  ls -l "${SYS_PROP}" || true
else
  hold "${SYS_PROP} ABSENT"
fi
if [[ -f "${PROD_PROP}" ]]; then
  PROD_TYPE="$(prop_val "${PROD_PROP}" ro.build.type)"
  PROD_TAGS="$(prop_val "${PROD_PROP}" ro.build.tags)"
  echo "READ ${PROD_PROP} ro.build.type=${PROD_TYPE} ro.build.tags=${PROD_TAGS}"
else
  hold "${PROD_PROP} ABSENT"
fi
if [[ -f "${VENDOR_PROP}" ]]; then
  VENDOR_TYPE="$(prop_val "${VENDOR_PROP}" ro.vendor.build.type)"
  VENDOR_TAGS="$(prop_val "${VENDOR_PROP}" ro.vendor.build.tags)"
  echo "READ ${VENDOR_PROP} ro.vendor.build.type=${VENDOR_TYPE} ro.vendor.build.tags=${VENDOR_TAGS}"
fi

USER_OUT=0
if [[ "${BUILD_TYPE}" == "user" ]]; then
  pass "system ro.build.type=user"
  USER_OUT=1
elif [[ "${BUILD_TYPE}" == "userdebug" ]]; then
  hold "system ro.build.type=userdebug (stale out; not a user FLASH_READY image)"
elif [[ "${BUILD_TYPE}" == "ABSENT" || -z "${BUILD_TYPE}" ]]; then
  hold "system ro.build.type ABSENT (no built image this stamp)"
else
  hold "system ro.build.type=${BUILD_TYPE} (not user; not FAIL while pem/out gap remains)"
fi
if [[ "${PROD_TYPE}" == "userdebug" ]]; then
  hold "product ro.build.type=userdebug (stale out)"
elif [[ "${PROD_TYPE}" == "user" ]]; then
  pass "product ro.build.type=user"
elif [[ -n "${PROD_TYPE}" && "${PROD_TYPE}" != "ABSENT" ]]; then
  hold "product ro.build.type=${PROD_TYPE}"
fi
if [[ "${VENDOR_TYPE}" == "userdebug" ]]; then
  hold "vendor ro.vendor.build.type=userdebug (stale out)"
elif [[ "${VENDOR_TYPE}" == "user" ]]; then
  pass "vendor ro.vendor.build.type=user"
fi

echo
echo "--- PRED no xbin su / overlay_remounter (stale userdebug = HOLD) ---"
XBIN_CLEAN=1
if [[ -e "${XBIN_SU}" ]]; then
  XBIN_CLEAN=0
  ls -l "${XBIN_SU}" || true
  if [[ "${BUILD_TYPE}" == "user" ]]; then
    fail "NEGATIVE HIT: user out still has xbin su ${XBIN_SU}"
  else
    hold "xbin su PRESENT ${XBIN_SU} (stale userdebug out; m not a user image)"
  fi
else
  if [[ "${BUILD_TYPE}" == "user" ]]; then
    pass "xbin su ABSENT on user out"
  else
    hold "xbin su ABSENT — still not a proven built user image (m not run by QA)"
  fi
fi
if [[ -e "${XBIN_OR}" ]]; then
  XBIN_CLEAN=0
  ls -l "${XBIN_OR}" || true
  if [[ "${BUILD_TYPE}" == "user" ]]; then
    fail "NEGATIVE HIT: user out still has xbin overlay_remounter ${XBIN_OR}"
  else
    hold "xbin overlay_remounter PRESENT ${XBIN_OR} (stale userdebug out)"
  fi
else
  if [[ "${BUILD_TYPE}" == "user" ]]; then
    pass "xbin overlay_remounter ABSENT on user out"
  else
    hold "xbin overlay_remounter ABSENT — still not a proven built user image"
  fi
fi

echo
echo "--- PRED no testkey on out tags (stale userdebug test-keys = HOLD) ---"
NO_TESTKEY=0
eval_tags() {
  local label="$1" tags="$2"
  case "${tags}" in
    release-keys)
      if [[ "${BUILD_TYPE}" == "user" ]]; then
        pass "${label}=release-keys on user out"
      else
        hold "${label}=release-keys but out type is ${BUILD_TYPE} (not FLASH_READY)"
      fi
      ;;
    test-keys)
      if [[ "${BUILD_TYPE}" == "user" ]]; then
        fail "NEGATIVE HIT: ${label}=test-keys on a user out (forbidden testkey fallback)"
      else
        hold "${label}=test-keys on ${BUILD_TYPE} out (stale; not FAIL while pem/out gap remains)"
      fi
      ;;
    dev-keys)
      hold "${label}=dev-keys (unsigned / not post-signed; not FLASH_READY)"
      ;;
    ABSENT|"")
      hold "${label} ABSENT"
      ;;
    *)
      hold "${label}=${tags} unexpected (document only)"
      ;;
  esac
}
eval_tags "system ro.build.tags" "${BUILD_TAGS}"
eval_tags "product ro.build.tags" "${PROD_TAGS}"
if [[ -n "${VENDOR_TAGS}" && "${VENDOR_TAGS}" != "ABSENT" ]]; then
  eval_tags "vendor ro.vendor.build.tags" "${VENDOR_TAGS}"
fi
if [[ "${BUILD_TYPE}" == "user" && "${BUILD_TAGS}" != "test-keys" && -n "${BUILD_TAGS}" ]]; then
  NO_TESTKEY=1
fi

echo
echo "--- vbmeta / avb_pkmd (read-only names; do not invent pem used) ---"
if [[ -f "${VBMETA}" ]]; then
  ls -l "${VBMETA}" || true
  if [[ "${BUILD_TYPE}" == "user" && "${PEM_OK}" -eq 1 ]]; then
    hold "vbmeta.img present on user out — pem-used proof still HOLD without operator key audit"
  else
    hold "vbmeta.img present on ${BUILD_TYPE} out (stale; not pem-used proof)"
  fi
else
  hold "vbmeta.img ABSENT"
fi
if [[ -f "${AVB_PKMD}" ]]; then
  hold "avb_pkmd.bin present (public blob only; not pem-used proof)"
else
  hold "avb_pkmd.bin ABSENT (expected until signed user m)"
fi

echo
echo "--- adb (device HOLD; do not start Q-ONDEVICE) ---"
ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "${ADB_OUT}"
if echo "${ADB_OUT}" | grep -q "${SERIAL}[[:space:]]"; then
  hold "adb sees ${SERIAL} — host-only card; do not start Q-ONDEVICE; not device-fixed"
elif echo "${ADB_OUT}" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  hold "adb sees a device — still not FLASH_READY proof; Q-ONDEVICE not started"
else
  hold "adb devices empty — device HOLD, never device-fixed"
fi

PEM_USED=0
if [[ "${PEM_OK}" -eq 1 && "${USER_OUT}" -eq 1 && "${NO_TESTKEY}" -eq 1 ]]; then
  PEM_USED=1
  pass "pem used inferred (pem present + user out + not test-keys; contents not read)"
else
  hold "pem used=false (need pem present AND user out AND not test-keys)"
fi

FLASH_READY=false
FLASH_CLASS="HOLD"
if [[ "${PEM_OK}" -eq 1 && "${USER_OUT}" -eq 1 && "${XBIN_CLEAN}" -eq 1 && \
      "${NO_TESTKEY}" -eq 1 && "${PEM_USED}" -eq 1 ]]; then
  FLASH_READY=true
  FLASH_CLASS="PASS"
else
  FLASH_READY=false
  if [[ "${FAIL}" -ne 0 ]]; then
    FLASH_CLASS="FAIL"
  else
    FLASH_CLASS="HOLD"
  fi
fi

if [[ "${FLASH_READY}" == "true" ]]; then
  if [[ "${PEM_OK}" -ne 1 || "${USER_OUT}" -ne 1 || "${XBIN_CLEAN}" -ne 1 || \
        "${NO_TESTKEY}" -ne 1 || "${PEM_USED}" -ne 1 ]]; then
    fail "NEGATIVE HIT: FLASH_READY invented true with incomplete predicates"
    FLASH_READY=false
    FLASH_CLASS="FAIL"
  else
    pass "FLASH_READY=true only after pem+user+no-xbin-su+no-testkey+pem-used"
  fi
else
  pass "FLASH_READY not invented true (predicates incomplete or FAIL)"
fi

echo
echo "PRED_PEM=$([[ "${PEM_OK}" -eq 1 ]] && echo true || echo false)"
echo "PRED_USER_OUT=$([[ "${USER_OUT}" -eq 1 ]] && echo true || echo false)"
echo "PRED_XBIN_CLEAN=$([[ "${XBIN_CLEAN}" -eq 1 ]] && echo true || echo false)"
echo "PRED_NO_TESTKEY=$([[ "${NO_TESTKEY}" -eq 1 ]] && echo true || echo false)"
echo "PRED_PEM_USED=$([[ "${PEM_USED}" -eq 1 ]] && echo true || echo false)"
echo "FLASH_READY=${FLASH_READY}"
echo "FLASH_CLASS=${FLASH_CLASS}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
echo "USB_GO=not started"
echo "ONDEVICE=not started"
echo "Q-REMEDIATE-B1-M=BLOCKED"
echo "RESULT: $([[ "${FAIL}" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=$([[ "${FAIL}" -eq 0 ]] && echo 0 || echo 1)"
exit "${FAIL}"
