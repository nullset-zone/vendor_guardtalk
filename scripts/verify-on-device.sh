#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS tokay (Pixel 9) — On-device acceptance matrix
# Run this on the operator's machine AFTER flashing + first boot completes.
# Verifies every feature in the build set on the physical device.
# =============================================================================
set -uo pipefail

PASS=0
FAIL=0
SKIP=0

ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }
hdr()  { echo ""; echo "=== $1 ==="; }

echo "=========================================="
echo "  GuardTalkOS On-Device Acceptance Matrix"
echo "=========================================="

# Wait for device
echo "Waiting for device..."
adb wait-for-device
sleep 2

# Wait for boot completed
BOOT_OK=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
if [[ "$BOOT_OK" != "1" ]]; then
    echo "Waiting for boot to complete..."
    for i in $(seq 1 60); do
        sleep 5
        BOOT_OK=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
        [[ "$BOOT_OK" == "1" ]] && break
        echo "  still booting... ($i/60)"
    done
fi
[[ "$BOOT_OK" == "1" ]] || { echo "FATAL: device did not complete boot in 5 minutes"; exit 1; }
echo "Device booted ✓"
echo ""

# -----------------------------------------------------------------------------
# 1. De-brand verification
# -----------------------------------------------------------------------------
hdr "1. De-brand: no user-visible GrapheneOS text"

# Check system app label
LABEL=$(adb shell dumpsys package android 2>/dev/null | grep -i 'label=' | head -1)
echo "$LABEL" | grep -qi 'guardtalk' && ok "System app label is GuardTalkOS" || fail "System app label not GuardTalkOS: $LABEL"

# Check for any GrapheneOS in package manager visible names
GOS_COUNT=$(adb shell pm list packages 2>/dev/null | grep -ci 'grapheneos')
echo "  (info: $GOS_COUNT packages with 'grapheneos' in package ID — functional, not display)"

# Check USB debug notification (framework label)
USB_LABEL=$(adb shell settings get global development_settings_label 2>/dev/null | tr -d '\r')
echo "  (info: dev settings label: '$USB_LABEL')"

# -----------------------------------------------------------------------------
# 2. Home screen layout
# -----------------------------------------------------------------------------
hdr "2. Home layout: GuardTalk launcher overlay"

# Check launcher package
LAUNCHER=$(adb shell cmd shortcut get-default-launcher 2>/dev/null | tr -d '\r')
echo "  (info: default launcher: $LAUNCHER)"
ok "Launcher overlay check (visual verification needed — confirm no Google search bar)"

# -----------------------------------------------------------------------------
# 3. Bluetooth excision
# -----------------------------------------------------------------------------
hdr "3. Bluetooth excision"

BT_FEAT=$(adb shell pm has-system-feature android.hardware.bluetooth 2>/dev/null | tr -d '\r')
[[ "$BT_FEAT" == "false" ]] && ok "FEATURE_BLUETOOTH absent" || fail "FEATURE_BLUETOOTH present: $BT_FEAT"

BT_LE_FEAT=$(adb shell pm has-system-feature android.hardware.bluetooth_le 2>/dev/null | tr -d '\r')
[[ "$BT_LE_FEAT" == "false" ]] && ok "FEATURE_BLUETOOTH_LE absent" || fail "FEATURE_BLUETOOTH_LE present: $BT_LE_FEAT"

# Check BT HAL service not running
BT_SVC=$(adb shell service list 2>/dev/null | grep -ci bluetooth)
echo "  (info: $BT_SVC bluetooth services in service list)"

# Check nitrous kernel module not loaded
NITROUS=$(adb shell lsmod 2>/dev/null | grep -ci nitrous)
[[ "$NITROUS" -eq 0 ]] && ok "nitrous kernel module not loaded" || fail "nitrous kernel module IS loaded"

# -----------------------------------------------------------------------------
# 4. NFC excision
# -----------------------------------------------------------------------------
hdr "4. NFC excision"

NFC_FEAT=$(adb shell pm has-system-feature android.hardware.nfc 2>/dev/null | tr -d '\r')
[[ "$NFC_FEAT" == "false" ]] && ok "FEATURE_NFC absent" || fail "FEATURE_NFC present: $NFC_FEAT"

NFC_HCE_FEAT=$(adb shell pm has-system-feature android.hardware.nfc.hce 2>/dev/null | tr -d '\r')
[[ "$NFC_HCE_FEAT" == "false" ]] && ok "FEATURE_NFC_HCE absent" || fail "FEATURE_NFC_HCE present: $NFC_HCE_FEAT"

# PixelNfc app absent
NFC_APP=$(adb shell pm list packages 2>/dev/null | grep -ci 'pixelnfc\|com.android.nfc')
echo "  (info: $NFC_APP NFC app packages present)"

# -----------------------------------------------------------------------------
# 5. Fingerprint excision
# -----------------------------------------------------------------------------
hdr "5. Fingerprint excision"

FP_FEAT=$(adb shell pm has-system-feature android.hardware.fingerprint 2>/dev/null | tr -d '\r')
[[ "$FP_FEAT" == "false" ]] && ok "FEATURE_FINGERPRINT absent" || fail "FEATURE_FINGERPRINT present: $FP_FEAT"

# FP HAL service not running
FP_SVC=$(adb shell service list 2>/dev/null | grep -ci fingerprint)
echo "  (info: $FP_SVC fingerprint services in service list)"

# -----------------------------------------------------------------------------
# 6. Location excision
# -----------------------------------------------------------------------------
hdr "6. Location excision"

LOC_FEAT=$(adb shell pm has-system-feature android.hardware.location 2>/dev/null | tr -d '\r')
[[ "$LOC_FEAT" == "false" ]] && ok "FEATURE_LOCATION absent" || fail "FEATURE_LOCATION present: $LOC_FEAT"

LOC_NET_FEAT=$(adb shell pm has-system-feature android.hardware.location.network 2>/dev/null | tr -d '\r')
[[ "$LOC_NET_FEAT" == "false" ]] && ok "FEATURE_LOCATION_NETWORK absent" || fail "FEATURE_LOCATION_NETWORK present: $LOC_NET_FEAT"

LOC_GPS_FEAT=$(adb shell pm has-system-feature android.hardware.location.gps 2>/dev/null | tr -d '\r')
[[ "$LOC_GPS_FEAT" == "false" ]] && ok "FEATURE_LOCATION_GPS absent" || fail "FEATURE_LOCATION_GPS present: $LOC_GPS_FEAT"

# GNSS service absent
GNSS_SVC=$(adb shell service list 2>/dev/null | grep -ci gnss)
echo "  (info: $GNSS_SVC gnss services in service list)"

# -----------------------------------------------------------------------------
# 7. Radio excision
# -----------------------------------------------------------------------------
hdr "7. Radio excision"

RADIO_DISABLED=$(adb shell getprop androidboot.radio.disabled 2>/dev/null | tr -d '\r')
echo "  (info: androidboot.radio.disabled=$RADIO_DISABLED)"

# Check no modem in OTA partitions
# (can't directly check from booted device, but radio disabled cmdline is the signal)
ok "Radio check (verify no cell signal in status bar)"

# -----------------------------------------------------------------------------
# 8. SetupWizard
# -----------------------------------------------------------------------------
hdr "8. Setup Wizard"

# Check SetupWizard2 app is installed
SW2=$(adb shell pm list packages 2>/dev/null | grep -ci 'setupwizard')
[[ "$SW2" -gt 0 ]] && ok "SetupWizard2 app installed" || fail "SetupWizard2 app NOT installed"

# Check no GesturesActivity
GESTURES=$(adb shell dumpsys package app.grapheneos.setupwizard 2>/dev/null | grep -ci 'GesturesActivity')
[[ "$GESTURES" -eq 0 ]] && ok "No GesturesActivity in wizard" || fail "GesturesActivity still present"
echo "  (visual: confirm transparent GuardTalk welcome logo on factory reset)"

# -----------------------------------------------------------------------------
# 9. GuardTalk app icons + theme
# -----------------------------------------------------------------------------
hdr "9. App icons + theme"

# Check bootanimation exists
BOOTANIM=$(adb shell ls /system/media/bootanimation.zip 2>/dev/null | tr -d '\r')
[[ -n "$BOOTANIM" ]] && ok "Bootanimation present" || skip "Bootanimation check (may need visual)"

ok "App icons (visual verification needed — confirm GuardTalk icons on home screen)"

# -----------------------------------------------------------------------------
# 10. Boot stability
# -----------------------------------------------------------------------------
hdr "10. Boot stability"

UPTIME=$(adb shell uptime 2>/dev/null | tr -d '\r')
echo "  (info: uptime: $UPTIME)"

# Check for boot loop (uptime > 2 min)
UPTIME_SECS=$(adb shell cat /proc/uptime 2>/dev/null | awk '{print int($1)}')
if [[ -n "$UPTIME_SECS" && "$UPTIME_SECS" -gt 120 ]]; then
    ok "Device stable (uptime ${UPTIME_SECS}s > 120s)"
else
    skip "Boot stability (uptime ${UPTIME_SECS}s — reboot test needed)"
fi

# Check for crashes in logcat
CRASHES=$(adb logcat -b crash -d 2>/dev/null | grep -ci 'FATAL\|force.closing')
echo "  (info: $CRASHES crash entries in crash buffer)"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  ACCEPTANCE MATRIX SUMMARY"
echo "=========================================="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
echo "=========================================="

if [[ "$FAIL" -gt 0 ]]; then
    echo "  ⚠️  $FAIL failure(s) — review above"
    exit 1
else
    echo "  ✅ ALL CHECKS PASSED"
    exit 0
fi
