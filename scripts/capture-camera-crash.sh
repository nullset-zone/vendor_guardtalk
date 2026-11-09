#!/usr/bin/env bash
# GuardTalk — capture why the Stallion camera still crashes, now that the
# CameraExtensionsProxy APK is installed.
# Run ON THE MAC with the phone on USB. Read-only.
set -uo pipefail

OUT="${1:-$HOME/GuardTalk-flash/camera-crash.txt}"
CAM="app.grapheneos.camera"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

for p in 5037 5099 5100 5101 5102 5038 5039; do
    if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then
        export ANDROID_ADB_SERVER_PORT=$p; break
    fi
done

say(){ printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }

{
echo "=============================================="
echo " Stallion camera crash capture   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="
adb devices -l
[ -n "$(adb devices | awk '$2=="device"{print $1;exit}')" ] || { echo "NO DEVICE"; exit 1; }

say "0. did the APK land, and is it scanned?"
adb shell "pm list packages -f 2>/dev/null | grep -iE 'cameraextensions|CameraExtensionsProxy'" || echo "  (not in pm list)"
adb shell 'ls -l /system/app/CameraExtensionsProxy/ 2>/dev/null' || true

say "1. is ICameraExtensionsProxyService registered NOW?"
adb shell 'service list 2>/dev/null | grep -iE "ICameraExtensionsProxyService|cameraextensions"' \
  || echo "  NOT REGISTERED"

say "2. clean slate + launch"
adb shell "am force-stop $CAM" 2>/dev/null
sleep 1
adb logcat -c 2>/dev/null
ACT="$(adb shell "cmd package resolve-activity --brief $CAM 2>/dev/null | tail -1" | tr -d '\r')"
echo "  activity: ${ACT:-<none>}"
adb shell "am start -W -n ${ACT:-$CAM/.MainActivity}" 2>&1 | head -6
sleep 12

say "3. alive or dead?"
PID="$(adb shell "pidof $CAM" 2>/dev/null | tr -d '\r')"
[ -n "$PID" ] && echo "  ALIVE pid $PID" || echo "  GONE"

say "4. THE CRASH — extension + camera errors"
adb logcat -d 2>/dev/null | grep -iE \
 'ExtensionsManager|PXLEXT|ICameraExtensionsProxyService|CameraExtensionsProxy|Camera2CameraImpl|CameraDevice|CaptureSession|Unable to configure|TimeoutException|CameraAccessException|CameraService::connect|NullPointerException|ClassNotFoundException|IncompatibleClassChange|VerifyError|NoSuchMethod' \
 | tail -80

say "5. crash buffer (app fatals)"
adb logcat -d -b crash 2>/dev/null | tail -60

say "6. package scan result for the APK"
adb shell 'dumpsys package com.android.cameraextensions 2>/dev/null | head -20' || true
adb logcat -d 2>/dev/null | grep -iE 'PackageManager.*cameraextensions|Failed to scan.*CameraExtensions' | tail -10 || true

say "7. counts"
echo "  extension_errors = $(adb logcat -d 2>/dev/null | grep -ciE 'ExtensionsManager|ICameraExtensionsProxyService|PXLEXT')"
echo "  configure_fail  = $(adb logcat -d 2>/dev/null | grep -c 'Unable to configure camera')"
echo "  anr             = $(adb logcat -d 2>/dev/null | grep -c "ANR in $CAM")"
echo "  fatals          = $(adb logcat -d -b crash 2>/dev/null | grep -c "Process: $CAM")"

echo
echo "saved: $OUT"
} 2>&1 | tee "$OUT"
