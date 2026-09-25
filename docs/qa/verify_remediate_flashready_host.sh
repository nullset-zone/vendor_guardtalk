#!/usr/bin/env bash
# Q-REMEDIATE-FLASHREADY host aggregator (DEC-REMEDIATE-007).
# Independent re-run of every verify_remediate_*_host.sh plus
# verify_remediate_b2_kernel_static.sh, verify_sec_p5_static.sh,
# verify_brand_sweep_static.sh. Skip *_ondevice.sh.
#
# FLASH_READY=true only if ALL of:
#   (a) every suite EXIT=0 and FAIL=0 (HOLD allowed)
#   (b) avb.pem at vendor/guardtalk/branding/signing-keys/avb.pem
#       OR /mnt/secure/keys/guardtalk/avb.pem
#   (c) out/target/product/komodo ro.build.type=user AND xbin has no
#       su / overlay_remounter
# Missing pem or userdebug/stale out → FLASH_READY=false HOLD, not FAIL.
#
# Do not m. Do not USB GO. Do not flash. Do not invent on-device working.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_flashready_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

QA_DIR="vendor/guardtalk/docs/qa"
AVB_TREE="vendor/guardtalk/branding/signing-keys/avb.pem"
AVB_SECURE="/mnt/secure/keys/guardtalk/avb.pem"
OUT_KOMODO="out/target/product/komodo"
SYS_PROP="${OUT_KOMODO}/system/build.prop"
PROD_PROP="${OUT_KOMODO}/product/etc/build.prop"
XBIN_SU="${OUT_KOMODO}/system/xbin/su"
XBIN_OR="${OUT_KOMODO}/system/xbin/overlay_remounter"

echo "=== Q-REMEDIATE-FLASHREADY independent host aggregator ==="
echo "ROOT=${ROOT}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo

mapfile -t SUITES < <(find "${QA_DIR}" -maxdepth 1 -type f -name 'verify_remediate_*_host.sh' ! -name 'verify_remediate_flashready_host.sh' | sort)
SUITES+=(
  "${QA_DIR}/verify_remediate_b2_kernel_static.sh"
  "${QA_DIR}/verify_sec_p5_static.sh"
  "${QA_DIR}/verify_brand_sweep_static.sh"
)

echo "--- suite inventory ---"
for s in "${SUITES[@]}"; do
  echo "RUN ${s}"
done
echo "SKIP ${QA_DIR}/verify_remediate_b1_ondevice.sh"
echo "SKIP ${QA_DIR}/verify_remediate_b2_ondevice.sh"
echo "SKIP ${QA_DIR}/verify_remediate_b3_osux_device.sh (not *_host.sh)"
echo

ANY_SUITE_FAIL=0
declare -a TABLE_ROWS=()

run_suite() {
  local script="$1"
  local base
  base="$(basename "${script}" .sh)"
  if [[ ! -f "${script}" ]]; then
    echo "FAIL: missing suite ${script}"
    ANY_SUITE_FAIL=1
    TABLE_ROWS+=("${base}|127|0|1|0|FAIL")
    return
  fi
  echo "======== BEGIN ${base} ========"
  local tmp rc pass_n fail_n hold_n verdict
  tmp="$(mktemp)"
  set +e
  bash "${script}" >"${tmp}" 2>&1
  rc=$?
  set -e
  cat "${tmp}"
  pass_n="$(grep -c '^PASS:' "${tmp}" || true)"
  fail_n="$(grep -c '^FAIL:' "${tmp}" || true)"
  hold_n="$(grep -c '^HOLD:' "${tmp}" || true)"
  rm -f "${tmp}"
  if [[ "${rc}" -ne 0 || "${fail_n}" -ne 0 ]]; then
    ANY_SUITE_FAIL=1
    verdict="FAIL"
  else
    verdict="PASS"
  fi
  echo "SUITE_COUNTS name=${base} EXIT=${rc} PASS=${pass_n} FAIL=${fail_n} HOLD=${hold_n} VERDICT=${verdict}"
  echo "======== END ${base} ========"
  echo
  TABLE_ROWS+=("${base}|${rc}|${pass_n}|${fail_n}|${hold_n}|${verdict}")
}

for s in "${SUITES[@]}"; do
  run_suite "${s}"
done

echo "=== FLASH_READY predicates (independent; do not invent true) ==="

PEM_OK=0
if [[ -f "${AVB_TREE}" ]]; then
  echo "PASS: avb.pem exists at in-tree stem ${AVB_TREE} (existence only; contents not read)"
  PEM_OK=1
else
  echo "HOLD: avb.pem ABSENT at in-tree stem ${AVB_TREE}"
fi
if [[ -f "${AVB_SECURE}" ]]; then
  echo "PASS: avb.pem exists at secure stem ${AVB_SECURE} (existence only; contents not read)"
  PEM_OK=1
else
  echo "HOLD: avb.pem ABSENT at secure stem ${AVB_SECURE}"
fi
if [[ ! -e /mnt/secure ]]; then
  echo "HOLD: /mnt/secure missing"
fi
if [[ "${PEM_OK}" -eq 1 ]]; then
  echo "PRED_B pem=true"
else
  echo "PRED_B pem=false"
fi

USER_OUT_OK=0
BUILD_TYPE="ABSENT"
if [[ -f "${SYS_PROP}" ]]; then
  BUILD_TYPE="$(awk -F= '/^ro.build.type=/{print $2; exit}' "${SYS_PROP}" || true)"
  echo "HOLD: ${SYS_PROP} ro.build.type=${BUILD_TYPE}"
else
  echo "HOLD: ${SYS_PROP} ABSENT"
fi
if [[ -f "${PROD_PROP}" ]]; then
  PROD_TYPE="$(awk -F= '/^ro.build.type=/{print $2; exit}' "${PROD_PROP}" || true)"
  echo "HOLD: ${PROD_PROP} ro.build.type=${PROD_TYPE}"
else
  echo "HOLD: ${PROD_PROP} ABSENT"
fi
XBIN_CLEAN=1
if [[ -e "${XBIN_SU}" ]]; then
  echo "HOLD: xbin su PRESENT ${XBIN_SU}"
  ls -l "${XBIN_SU}" || true
  XBIN_CLEAN=0
else
  echo "HOLD: xbin su ABSENT"
fi
if [[ -e "${XBIN_OR}" ]]; then
  echo "HOLD: xbin overlay_remounter PRESENT ${XBIN_OR}"
  ls -l "${XBIN_OR}" || true
  XBIN_CLEAN=0
else
  echo "HOLD: xbin overlay_remounter ABSENT"
fi
if [[ "${BUILD_TYPE}" == "user" && "${XBIN_CLEAN}" -eq 1 ]]; then
  USER_OUT_OK=1
  echo "PRED_C user_out=true"
else
  echo "PRED_C user_out=false (need ro.build.type=user and no xbin su/overlay_remounter)"
fi

ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "--- adb devices -l ---"
echo "${ADB_OUT}"
if echo "${ADB_OUT}" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  echo "HOLD: adb sees a device — still not FLASH_READY proof; Q-ONDEVICE not started"
else
  echo "HOLD: adb devices empty — not device-fixed; on-device working not invented"
fi

PRED_A=1
if [[ "${ANY_SUITE_FAIL}" -ne 0 ]]; then
  PRED_A=0
fi
echo "PRED_A suites_exit0_fail0=$([[ "${PRED_A}" -eq 1 ]] && echo true || echo false)"

FLASH_READY=false
FLASH_CLASS="HOLD"
if [[ "${PRED_A}" -eq 1 && "${PEM_OK}" -eq 1 && "${USER_OUT_OK}" -eq 1 ]]; then
  FLASH_READY=true
  FLASH_CLASS="PASS"
elif [[ "${PRED_A}" -eq 0 ]]; then
  FLASH_READY=false
  FLASH_CLASS="FAIL"
else
  FLASH_READY=false
  FLASH_CLASS="HOLD"
fi

echo
echo "=== FLASHREADY TABLE ==="
printf '%-42s %6s %6s %6s %6s %s\n' "SUITE" "EXIT" "PASS" "FAIL" "HOLD" "VERDICT"
echo "--------------------------------------------------------------------------------"
for row in "${TABLE_ROWS[@]}"; do
  IFS='|' read -r name rc pass_n fail_n hold_n verdict <<<"${row}"
  printf '%-42s %6s %6s %6s %6s %s\n' "${name}" "${rc}" "${pass_n}" "${fail_n}" "${hold_n}" "${verdict}"
done
echo "--------------------------------------------------------------------------------"
printf '%-42s %6s %6s %6s %6s %s\n' "FLASH_READY" "-" "-" "-" "-" "${FLASH_READY} (${FLASH_CLASS})"
echo "PRED_A (suites EXIT=0 FAIL=0)=$([[ "${PRED_A}" -eq 1 ]] && echo true || echo false)"
echo "PRED_B (avb.pem exists)=$([[ "${PEM_OK}" -eq 1 ]] && echo true || echo false)"
echo "PRED_C (out user + no xbin su)=$([[ "${USER_OUT_OK}" -eq 1 ]] && echo true || echo false)"
echo "FLASH_READY=${FLASH_READY}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
echo "USB_GO=not started"
echo "ONDEVICE=not started"

if [[ "${PRED_A}" -eq 0 ]]; then
  echo "RESULT: FAIL (one or more host suites EXIT!=0 or FAIL>0); FLASH_READY=false"
  exit 1
fi
echo "RESULT: PASS (host aggregator; FLASH_READY=${FLASH_READY} ${FLASH_CLASS}; not device-fixed)"
exit 0
