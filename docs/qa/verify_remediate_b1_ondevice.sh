#!/usr/bin/env bash
# Independent on-device probe for Q-REMEDIATE-B1-ONDEVICE (DEC-REMEDIATE-003).
# Pair of T-REMEDIATE-B1-USERBUILD + AVB + DURESS (Architect-APPROVED static; do not trust).
# PASS HOLD lift gate with sibling Q-REMEDIATE-B2-ONDEVICE (do not wait).
#
# Probe adb first. Empty list / missing serial 54111FDAS000GN = documented HOLD
# (successful HOLD delivery, exit 0). Never invent live. Never APPROVED.
# Never device-fixed. Never lift PASS HOLD from this card.
#
# If the named unit is present: rematch user / debuggable=0 / no su / adb.secure
# / RSA / SPL / verifiedbootstate (DEC-002 yellow OR green). Orange/red FAIL.
# Programmatic + USB duress wipe: HOLD without operator-present confirmation.
# userdebug/test-keys: HOLD; do not lift PASS HOLD.
#
# FORBIDDEN (this script never executes): USB GO, fastboot flash, fastboot
# flashing lock, wipe, `m`, rango, web-installer, git commit/push.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b1_ondevice.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

SERIAL="54111FDAS000GN"
EXPECTED_PIN="2026-09-05"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Refuse destructive / out-of-scope flags (Law 4 / Law 2). Probe-only.
for arg in "$@"; do
  case "$arg" in
    --wipe|--lock|--flash|--usb-go|--usb_go|--m|--live|--approve|--lift)
      echo "REFUSED: $arg is forbidden on Q-REMEDIATE-B1-ONDEVICE (probe-only HOLD)."
      echo "LIVE_DEVICE_CLAIMED=false"
      echo "PASS_HOLD_LIFTED=false"
      exit 0
      ;;
  esac
done

echo "=== Q-REMEDIATE-B1-ONDEVICE independent on-device probe ==="
echo "ROOT=$ROOT"
echo "STAMP=${STAMP}"
echo "SERIAL=${SERIAL}"
echo "DEC=DEC-REMEDIATE-003"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD_LIFTED=false"
echo "Q-REMEDIATE-B2-ONDEVICE=sibling (not waited)"
echo "USB_GO=not started"
echo "FASTBOOT_FLASH=not started"
echo "FASTBOOT_LOCK=not started"
echo "WIPE=not started"
echo "M=not started"
echo

echo "--- forbidden actions (never executed this stamp) ---"
pass "USB GO not executed"
pass "fastboot flash not executed"
pass "fastboot flashing lock not executed"
pass "programmatic duress wipe not executed"
pass "USB duress wipe not executed"
pass "m not executed"
pass "git commit/push not executed"
pass "PASS HOLD not lifted (this card cannot lift it)"
pass "APPROVED not claimed (Status REVIEW only)"

echo
echo "=== RAW: adb devices -l ==="
set +e
ADB_OUT="$(adb devices -l 2>&1)"
ADB_RC=$?
set -e
printf '%s\n' "$ADB_OUT"
echo "ADB_RC=${ADB_RC}"

# Header-only "List of devices attached" with no serial lines = empty.
SERIAL_LINE="$(printf '%s\n' "$ADB_OUT" | grep -E "^${SERIAL}[[:space:]]" || true)"
ANY_SERIAL="$(printf '%s\n' "$ADB_OUT" | awk 'NR>1 && $1 ~ /[A-Za-z0-9]+/ && $2 ~ /device|unauthorized|offline|recovery|sideload|bootloader/ {print}' || true)"

echo
echo "--- serial presence ---"
if [[ -z "$ANY_SERIAL" ]]; then
  echo "ADB_LIST_EMPTY=true"
  echo "SERIAL_PRESENT=false"
  pass "adb devices -l recorded (empty list; honest HOLD)"
  hold "adb devices -l empty — named komodo ${SERIAL} absent this stamp"
  hold "ro.build.type not read — empty adb (do not invent user)"
  hold "ro.debuggable not read — empty adb"
  hold "su presence not probed — empty adb"
  hold "ro.adb.secure / RSA prompt not probed — empty adb"
  hold "SPL live vs pin ${EXPECTED_PIN} not read — empty adb (HOLD allowed anyway)"
  hold "verifiedbootstate not read — empty adb (DEC-002 yellow OR green; do not invent)"
  hold "ro.build.tags / test-keys not read — empty adb (do not lift PASS HOLD)"
  hold "programmatic duress wipe e2e HOLD — no operator-present test-unit confirmation"
  hold "USB duress wipe e2e HOLD — no operator-present test-unit confirmation"
  hold "PASS HOLD remains — empty adb cannot lift Blocks 1–2 on-device rematch"
  hold "not device-fixed — empty adb is successful HOLD delivery, not a live PASS"
else
  echo "ADB_LIST_EMPTY=false"
  echo "ANY_SERIAL:"
  printf '%s\n' "$ANY_SERIAL"
  if [[ -z "$SERIAL_LINE" ]]; then
    echo "SERIAL_PRESENT=false"
    hold "adb attached but serial is not ${SERIAL} — HOLD (do not rematch a different unit)"
    hold "ro.build.type not read — wrong/missing serial"
    hold "ro.debuggable not read — wrong/missing serial"
    hold "su presence not probed — wrong/missing serial"
    hold "ro.adb.secure / RSA prompt not probed — wrong/missing serial"
    hold "SPL live vs pin ${EXPECTED_PIN} not read — wrong/missing serial"
    hold "verifiedbootstate not read — wrong/missing serial"
    hold "programmatic duress wipe e2e HOLD — no operator-present test-unit confirmation"
    hold "USB duress wipe e2e HOLD — no operator-present test-unit confirmation"
    hold "PASS HOLD remains — wrong serial cannot lift on-device rematch"
    hold "not device-fixed"
  else
    echo "SERIAL_PRESENT=true"
    echo "SERIAL_LINE=${SERIAL_LINE}"
    STATE="$(printf '%s\n' "$SERIAL_LINE" | awk '{print $2}')"
    echo "ADB_STATE=${STATE}"

    if [[ "$STATE" != "device" ]]; then
      if [[ "$STATE" == "unauthorized" ]]; then
        hold "adb state=unauthorized — RSA prompt present; operator must authorize; not rematched"
      else
        hold "adb state=${STATE} — not a usable 'device' session; HOLD rematch"
      fi
      hold "ro.build.type not read — adb not in device state"
      hold "ro.debuggable not read — adb not in device state"
      hold "su presence not probed — adb not in device state"
      hold "SPL live vs pin ${EXPECTED_PIN} not read — adb not in device state"
      hold "verifiedbootstate not read — adb not in device state"
      hold "programmatic duress wipe e2e HOLD — no operator-present test-unit confirmation"
      hold "USB duress wipe e2e HOLD — no operator-present test-unit confirmation"
      hold "PASS HOLD remains — unauthorized/offline cannot lift on-device rematch"
      hold "not device-fixed"
    else
      echo
      echo "--- live getprop rematch (do not trust host-static APPROVE) ---"
      gp() { adb -s "$SERIAL" shell getprop "$1" 2>/dev/null | tr -d '\r'; }

      BUILD_TYPE="$(gp ro.build.type)"
      DEBUGGABLE="$(gp ro.debuggable)"
      ADB_SECURE="$(gp ro.adb.secure)"
      SPL_LIVE="$(gp ro.build.version.security_patch)"
      VBS="$(gp ro.boot.verifiedbootstate)"
      TAGS="$(gp ro.build.tags)"
      FINGERPRINT="$(gp ro.build.fingerprint)"
      DEVICE_CODENAME="$(gp ro.product.device)"
      echo "ro.build.type=${BUILD_TYPE}"
      echo "ro.debuggable=${DEBUGGABLE}"
      echo "ro.adb.secure=${ADB_SECURE}"
      echo "ro.build.version.security_patch=${SPL_LIVE}"
      echo "ro.boot.verifiedbootstate=${VBS}"
      echo "ro.build.tags=${TAGS}"
      echo "ro.build.fingerprint=${FINGERPRINT}"
      echo "ro.product.device=${DEVICE_CODENAME}"

      USERDEBUG_OR_TESTKEYS=0

      if [[ "$BUILD_TYPE" == "user" ]]; then
        pass "ro.build.type=user"
      elif [[ "$BUILD_TYPE" == "userdebug" || "$BUILD_TYPE" == "eng" ]]; then
        hold "ro.build.type=${BUILD_TYPE} — still userdebug/eng; do not lift PASS HOLD"
        USERDEBUG_OR_TESTKEYS=1
      else
        hold "ro.build.type=${BUILD_TYPE:-empty} — not proven user; HOLD"
        USERDEBUG_OR_TESTKEYS=1
      fi

      if [[ "$DEBUGGABLE" == "0" ]]; then
        pass "ro.debuggable=0"
      else
        hold "ro.debuggable=${DEBUGGABLE:-empty} — not 0; do not lift PASS HOLD"
        USERDEBUG_OR_TESTKEYS=1
      fi

      echo
      echo "--- su presence (read-only; never invoke su) ---"
      set +e
      SU_WHICH="$(adb -s "$SERIAL" shell 'command -v su; ls -l /system/xbin/su /system/bin/su /system/xbin/overlay_remounter 2>/dev/null' 2>/dev/null | tr -d '\r')"
      set -e
      echo "SU_PROBE:"
      printf '%s\n' "$SU_WHICH"
      if printf '%s\n' "$SU_WHICH" | grep -Eq '^/.*(^|[[:space:]])su$|/system/.*/su$'; then
        hold "su binary visible on device — not a proven user image; do not lift PASS HOLD"
        USERDEBUG_OR_TESTKEYS=1
      elif printf '%s\n' "$SU_WHICH" | grep -q 'overlay_remounter'; then
        hold "overlay_remounter visible on device — do not lift PASS HOLD"
        USERDEBUG_OR_TESTKEYS=1
      else
        pass "no su / overlay_remounter path from command -v / xbin ls (this session)"
      fi

      if [[ "$ADB_SECURE" == "1" ]]; then
        pass "ro.adb.secure=1 (RSA authorization required; this session already authorized)"
      else
        hold "ro.adb.secure=${ADB_SECURE:-empty} — RSA/secure ADB not proven; do not lift PASS HOLD"
      fi

      echo
      echo "--- SPL (live vs pin ${EXPECTED_PIN}; mismatch HOLD is allowed) ---"
      if [[ "$SPL_LIVE" == "$EXPECTED_PIN" ]]; then
        pass "live SPL=${SPL_LIVE} matches pin ${EXPECTED_PIN}"
      else
        hold "live SPL=${SPL_LIVE:-empty} vs pin ${EXPECTED_PIN} — HOLD allowed; do not invent pin as live"
      fi

      echo
      echo "--- verifiedbootstate (DEC-002: yellow OR green accepted; orange/red FAIL) ---"
      case "$VBS" in
        yellow)
          pass "verifiedbootstate=yellow (DEC-002 accepted; not FAIL)"
          hold "operator-goal green still HOLD (yellow is Pixel custom-key truth)"
          ;;
        green)
          pass "verifiedbootstate=green (DEC-002 accepted)"
          ;;
        orange|red)
          fail "verifiedbootstate=${VBS} — DEC-002 FAIL (orange/red)"
          ;;
        *)
          hold "verifiedbootstate=${VBS:-empty} — not yellow/green this stamp; do not invent"
          ;;
      esac

      if [[ "$TAGS" == *test-keys* ]]; then
        hold "ro.build.tags=${TAGS} includes test-keys — HOLD; do not lift PASS HOLD"
        USERDEBUG_OR_TESTKEYS=1
      elif [[ "$TAGS" == *release-keys* ]]; then
        pass "ro.build.tags=${TAGS} (release-keys; still not a PASS HOLD lift by this card)"
      else
        hold "ro.build.tags=${TAGS:-empty} — not proven release-keys"
      fi

      if [[ "$DEVICE_CODENAME" == "komodo" ]]; then
        pass "ro.product.device=komodo"
      else
        hold "ro.product.device=${DEVICE_CODENAME:-empty} — not proven komodo"
      fi

      echo
      echo "--- destructive proofs (never run without operator-present confirmation) ---"
      hold "programmatic duress wipe e2e HOLD — no operator-present test-unit confirmation (do NOT wipe)"
      hold "USB duress wipe e2e HOLD — no operator-present test-unit confirmation (do NOT wipe)"

      if [[ "$USERDEBUG_OR_TESTKEYS" -eq 1 ]]; then
        hold "image still userdebug and/or test-keys — PASS HOLD remains; not device-fixed"
      else
        hold "live props rematched this session — PASS HOLD still remains (wipe e2e HOLD; sibling Q-B2; this card cannot lift)"
      fi
      hold "not device-fixed — Q-REMEDIATE-B1-ONDEVICE Status REVIEW only"
    fi
  fi
fi

echo
echo "--- PASS HOLD / live claims ---"
pass "LIVE_DEVICE_CLAIMED=false (this suite never claims live)"
pass "PASS_HOLD_LIFTED=false (Blocks 1–2 on-device lift is Architect/operator; not this card)"
hold "Q-REMEDIATE-B2-ONDEVICE is a sibling probe — not waited, not claimed complete"

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=1"
  echo "LIVE_DEVICE_CLAIMED=false"
  echo "PASS_HOLD_LIFTED=false"
  echo "DEVICE=HOLD"
  echo "WIPE_E2E=HOLD"
  echo "USB_DURESS_WIPE=HOLD"
  exit 1
fi
echo "RESULT: HOLD (on-device probe)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} FAIL=0 EXIT=0"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD_LIFTED=false"
echo "DEVICE=HOLD"
echo "WIPE_E2E=HOLD"
echo "USB_DURESS_WIPE=HOLD"
echo "STATUS=REVIEW"
exit 0
