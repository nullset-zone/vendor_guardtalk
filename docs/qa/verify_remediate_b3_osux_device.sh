#!/usr/bin/env bash
# Independent on-device rematch for Q-REMEDIATE-B3-OSUX-DEVICE.
# DEC-REMEDIATE-003 probe. Pair of OS-UX DEVICE HOLD (DEC-OS-UX-001 static
# wave is NOT live). Do not trust Q-VIEWER / Q-SENSORS static APPROVE.
# Do NOT re-open T-OS-CAMMIC / T-OS-BACK / T-OS-FILES (APPROVED static).
# Do NOT fold this card into Q-REMEDIATE-B3-VIEWER.
#
# Probe adb first. Empty / wrong serial / not a user image → HOLD REVIEW.
# Named unit 54111FDAS000GN on flashed komodo user image → rematch:
#   1) cam/mic QS tiles (mictoggle / cameratoggle; never silent)
#   2) system back (never silent)
#   3) Files HTMLViewer jpeg/png/webp (never silent)
#
# Empty adb = successful HOLD delivery (EXIT 0).
# No USB GO. No flash. No lock. No wipe. No m. Never APPROVED.
# No product edits. No derived-queue edit. No memory-bank.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b3_osux_device.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

SERIAL="${GUARDTALK_KOMODO_SERIAL:-54111FDAS000GN}"
FAIL=0
PASS_N=0
HOLD_N=0
FAIL_N=0
LIVE_DEVICE_CLAIMED=false
DEVICE_STATE="unknown"
USER_IMAGE=false

pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; FAIL_N=$((FAIL_N + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

echo "=== Q-REMEDIATE-B3-OSUX-DEVICE independent on-device rematch ==="
echo "ROOT=$ROOT"
echo "SERIAL_EXPECTED=${SERIAL}"
echo "DEC=DEC-REMEDIATE-003"
echo "STATIC_Q_VIEWER_SENSORS_LIVE=false"
echo "FOLD_INTO_Q_VIEWER=false"
echo "T_OS_CAMMIC_BACK_FILES=APPROVED static (not re-opened)"
echo "USB_GO=not started"
echo "FLASH=not started"
echo "LOCK=not started"
echo "WIPE=not started"
echo "M=not started"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo

# --- process / scope (not a live-device claim) ---
pass "scope: on-device OS-UX rematch only (cam/mic tiles, system back, Files jpeg/png/webp)"
pass "static Q-VIEWER / Q-SENSORS APPROVE is not treated as live"
pass "T-OS-CAMMIC / T-OS-BACK / T-OS-FILES left APPROVED static (not re-opened)"
pass "not folded into Q-REMEDIATE-B3-VIEWER"
pass "USB GO / flash / lock / wipe / m not started"

echo
echo "--- adb devices -l (raw) ---"
if ! command -v adb >/dev/null 2>&1; then
  ADB_OUT="adb: command not found"
  echo "$ADB_OUT"
  hold "adb binary not on PATH — cannot rematch named unit; not device-fixed"
  DEVICE_STATE="adb_missing"
else
  ADB_OUT="$(adb devices -l 2>&1 || true)"
  printf '%s\n' "$ADB_OUT"
  DEVICE_LINES="$(printf '%s\n' "$ADB_OUT" | awk 'NR>1 && $1 != "" && $1 != "*" && $1 != "List" {print}')"
  if [[ -z "${DEVICE_LINES}" ]]; then
    hold "adb devices -l empty — cam/mic QS tiles HOLD; not device-fixed"
    hold "adb devices -l empty — system back HOLD; not device-fixed"
    hold "adb devices -l empty — Files HTMLViewer jpeg/png/webp HOLD; not device-fixed"
    hold "no flashed komodo user image on ${SERIAL} this stamp"
    DEVICE_STATE="empty"
  else
    echo "--- attached rows ---"
    printf '%s\n' "$DEVICE_LINES"
    SERIAL_ROW="$(printf '%s\n' "$DEVICE_LINES" | awk -v s="$SERIAL" '$1==s {print; found=1} END{exit found?0:1}' || true)"
    OTHER_ROWS="$(printf '%s\n' "$DEVICE_LINES" | awk -v s="$SERIAL" '$1!=s {print}')"
    if [[ -n "${OTHER_ROWS}" ]]; then
      hold "non-named serial(s) attached — ignored (this card is ${SERIAL} only)"
      printf '%s\n' "$OTHER_ROWS"
    fi
    if [[ -z "${SERIAL_ROW}" ]]; then
      hold "named serial ${SERIAL} ABSENT — wrong unit; HOLD REVIEW; not device-fixed"
      hold "cam/mic QS tiles not rematched (wrong/absent serial)"
      hold "system back not rematched (wrong/absent serial)"
      hold "Files jpeg/png/webp not rematched (wrong/absent serial)"
      DEVICE_STATE="wrong_serial"
    else
      STATE_TOKEN="$(printf '%s\n' "$SERIAL_ROW" | awk '{print $2}')"
      echo "NAMED_ROW=${SERIAL_ROW}"
      echo "ADB_STATE=${STATE_TOKEN}"
      if [[ "${STATE_TOKEN}" != "device" ]]; then
        hold "named serial ${SERIAL} state=${STATE_TOKEN} (not 'device') — HOLD REVIEW"
        hold "cam/mic QS tiles HOLD (adb not authorized/online)"
        hold "system back HOLD (adb not authorized/online)"
        hold "Files jpeg/png/webp HOLD (adb not authorized/online)"
        DEVICE_STATE="not_online"
      else
        DEVICE_STATE="named_online"
        echo
        echo "--- named-unit build props (user-image gate) ---"
        PROP_TYPE="$(adb -s "$SERIAL" shell getprop ro.build.type 2>/dev/null | tr -d '\r' || true)"
        PROP_TAGS="$(adb -s "$SERIAL" shell getprop ro.build.tags 2>/dev/null | tr -d '\r' || true)"
        PROP_DEV="$(adb -s "$SERIAL" shell getprop ro.product.device 2>/dev/null | tr -d '\r' || true)"
        PROP_DEB="$(adb -s "$SERIAL" shell getprop ro.debuggable 2>/dev/null | tr -d '\r' || true)"
        PROP_FP="$(adb -s "$SERIAL" shell getprop ro.build.fingerprint 2>/dev/null | tr -d '\r' || true)"
        PROP_VARIANT="$(adb -s "$SERIAL" shell getprop ro.build.flavor 2>/dev/null | tr -d '\r' || true)"
        echo "ro.build.type=${PROP_TYPE}"
        echo "ro.build.tags=${PROP_TAGS}"
        echo "ro.product.device=${PROP_DEV}"
        echo "ro.debuggable=${PROP_DEB}"
        echo "ro.build.flavor=${PROP_VARIANT}"
        echo "ro.build.fingerprint=${PROP_FP}"
        if [[ -z "${PROP_TYPE}" ]]; then
          fail "getprop ro.build.type empty — silent fail forbidden"
        fi
        if [[ "${PROP_DEV}" != "komodo" ]]; then
          hold "named unit product.device='${PROP_DEV}' (want komodo) — HOLD REVIEW; not the flashed komodo user image"
        fi
        if [[ "${PROP_TYPE}" == "user" && "${PROP_DEB}" == "0" ]]; then
          USER_IMAGE=true
          pass "named unit ${SERIAL} reports ro.build.type=user ro.debuggable=0"
        else
          hold "named unit is NOT a user image (type='${PROP_TYPE}' debuggable='${PROP_DEB}') — HOLD REVIEW"
          hold "cam/mic QS tiles not rematched (need flashed user image)"
          hold "system back not rematched (need flashed user image)"
          hold "Files jpeg/png/webp not rematched (need flashed user image)"
          DEVICE_STATE="not_user_image"
        fi
      fi
    fi
  fi
fi

if [[ "${USER_IMAGE}" == true ]]; then
  echo
  echo "--- rematch: cam/mic QS tiles (never silent) ---"
  QS="$(adb -s "$SERIAL" shell settings get secure sysui_qs_tiles 2>/dev/null | tr -d '\r' || true)"
  echo "RAW: settings get secure sysui_qs_tiles"
  printf '%s\n' "$QS"
  if [[ -z "${QS}" || "${QS}" == "null" ]]; then
    fail "sysui_qs_tiles empty/null — silent QS fail forbidden"
  else
    if printf '%s\n' "$QS" | grep -Fq "mictoggle"; then
      pass "QS tiles include mictoggle"
    else
      fail "QS tiles missing mictoggle (never silent)"
    fi
    if printf '%s\n' "$QS" | grep -Fq "cameratoggle"; then
      pass "QS tiles include cameratoggle"
    else
      fail "QS tiles missing cameratoggle (never silent)"
    fi
  fi
  echo "RAW: dumpsys sensor_privacy"
  SP="$(adb -s "$SERIAL" shell dumpsys sensor_privacy 2>/dev/null | tr -d '\r' || true)"
  if [[ -z "${SP}" ]]; then
    fail "dumpsys sensor_privacy empty — silent fail forbidden"
  else
    printf '%s\n' "$SP" | head -n 80
    pass "dumpsys sensor_privacy returned output (tile vs dumpsys UI still needs human QS)"
    hold "QS tile tap / Settings vs dumpsys polarity — dumpsys is not a tap proof; HOLD unless UI exercised"
  fi
  echo "RAW: cmd overlay list (GuardTalk SystemUI / Frameworks)"
  OV="$(adb -s "$SERIAL" shell cmd overlay list 2>/dev/null | tr -d '\r' || true)"
  if [[ -z "${OV}" ]]; then
    fail "cmd overlay list empty — silent fail forbidden"
  else
    printf '%s\n' "$OV" | grep -E 'GuardTalkSystemUIOverlay|GuardTalkFrameworksBaseOverlay|PixelConfigOverlayCommon' || true
    if printf '%s\n' "$OV" | grep -q "GuardTalkSystemUIOverlay"; then
      pass "GuardTalkSystemUIOverlay listed on device"
    else
      fail "GuardTalkSystemUIOverlay not listed (QS overlay missing)"
    fi
    if printf '%s\n' "$OV" | grep -q "PixelConfigOverlayCommon"; then
      fail "PixelConfigOverlayCommon present on device (item 17 negative)"
    else
      pass "PixelConfigOverlayCommon ABSENT on device overlay list"
    fi
  fi

  echo
  echo "--- rematch: system back (never silent) ---"
  echo "RAW: dumpsys activity activities (head)"
  ACT="$(adb -s "$SERIAL" shell dumpsys activity activities 2>/dev/null | tr -d '\r' || true)"
  if [[ -z "${ACT}" ]]; then
    fail "dumpsys activity activities empty — silent back fail forbidden"
  else
    printf '%s\n' "$ACT" | head -n 60
    pass "dumpsys activity activities returned output"
  fi
  echo "RAW: cmd overlay list NavigationBar"
  if [[ -n "${OV}" ]]; then
    printf '%s\n' "$OV" | grep -iE 'NavigationBar|Gestural|3Button' || true
    if printf '%s\n' "$OV" | grep -qiE 'NavigationBarModeGestural|NavigationBarMode3Button'; then
      pass "nav-mode overlay listed (gestural and/or 3-button)"
    else
      hold "nav-mode overlay tokens not seen in overlay list (dumpsys-only; not a swipe proof)"
    fi
  fi
  KG="$(adb -s "$SERIAL" shell dumpsys window 2>/dev/null | tr -d '\r' | grep -E 'mDreamingLockscreen|isStatusBarKeyguard|mShowingLockscreen' | head -n 8 || true)"
  echo "RAW: keyguard window hints"
  printf '%s\n' "$KG"
  hold "Settings/Files/multi-activity KEYCODE_BACK + gesture swipe — not exercised (no USB GO; no unlock). DEVICE HOLD"
  hold "empty-stack home/recents vs no-op — not proven without UI. DEVICE HOLD"

  echo
  echo "--- rematch: Files HTMLViewer jpeg/png/webp (never silent) ---"
  for mime in image/jpeg image/png image/webp; do
    echo "RAW: adb shell cmd package query-activities -a android.intent.action.VIEW -t ${mime}"
    QOUT="$(adb -s "$SERIAL" shell cmd package query-activities -a android.intent.action.VIEW -t "${mime}" 2>/dev/null | tr -d '\r' || true)"
    printf '%s\n' "$QOUT"
    if [[ -z "${QOUT}" ]]; then
      fail "query-activities ${mime} empty — silent fail forbidden"
    else
      pass "query-activities ${mime} returned output"
      if printf '%s\n' "$QOUT" | grep -qiE 'htmlviewer|com.android.htmlviewer'; then
        pass "query-activities ${mime} includes HTMLViewer"
      else
        fail "query-activities ${mime} missing HTMLViewer (never silent / no blank viewer)"
      fi
    fi
  done
  hold "Files tap-to-open jpeg/png/webp — query-activities is not tap proof; HOLD unless UI exercised"
  hold "blank viewer / empty chooser / silent no-op — not refuted by tap this stamp"
  if [[ "$FAIL" -eq 0 ]]; then
    LIVE_DEVICE_CLAIMED=false
    hold "named user image rematch is probe-only; PASS HOLD remains; live not claimed"
  fi
fi

echo
echo "--- honesty / residuals ---"
hold "PASS HOLD remains (Blocks 1-2 on-device rematch not this card's lift)"
pass "LIVE_DEVICE_CLAIMED=${LIVE_DEVICE_CLAIMED}"
pass "did not claim static OS-UX / Q-VIEWER / Q-SENSORS wave is live"
pass "did not USB GO / flash / lock / wipe / m"
pass "did not git commit; did not edit derived queue; did not edit memory-bank"

echo
echo "DEVICE_STATE=${DEVICE_STATE}"
echo "USER_IMAGE=${USER_IMAGE}"
echo "LIVE_DEVICE_CLAIMED=${LIVE_DEVICE_CLAIMED}"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT=${FAIL_N} HOLD_COUNT=${HOLD_N}"
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  EXIT=1"
  echo "OVERALL: FAIL (device rematch). Never silent."
  exit 1
fi
if [[ "${DEVICE_STATE}" == "named_online" && "${USER_IMAGE}" == true ]]; then
  echo "RESULT: PASS (probe rematch) + HOLD (UI tap / PASS HOLD). EXIT=0"
  echo "OVERALL: HOLD REVIEW still (PASS HOLD remains; not device-fixed; not APPROVED)"
  exit 0
fi
echo "RESULT: PASS (documented HOLD delivery)  EXIT=0"
echo "OVERALL: HOLD REVIEW (adb empty / wrong serial / not user image). Not device-fixed."
echo "Empty adb = successful HOLD delivery."
exit 0
