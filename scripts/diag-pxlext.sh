#!/usr/bin/env bash
# Find WHO logs as PXLEXT_PixelExtensionsClient, and what it binds to.
# Read-only. Run on the Mac with the phone attached.
OUT="${1:-$HOME/GuardTalk-flash/pxlext-diag.txt}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
for p in 5037 5099 5100 5101 5102 5038 5039; do
  if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then export ANDROID_ADB_SERVER_PORT=$p; break; fi
done
say(){ printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }
{
echo "PXLEXT ownership diagnostic  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
adb devices -l
[ -n "$(adb devices | awk '$2=="device"{print $1;exit}')" ] || { echo "NO DEVICE"; exit 1; }

say "1. which process emits PXLEXT? (relaunch camera, then check the pid)"
adb shell 'am force-stop app.grapheneos.camera' 2>/dev/null
adb logcat -c 2>/dev/null
adb shell 'am start -W -n app.grapheneos.camera/.ui.activities.MainActivity' >/dev/null 2>&1
sleep 3
adb logcat -d 2>/dev/null | grep 'PXLEXT' | tail -3
echo "  -- camera pid: $(adb shell 'pidof app.grapheneos.camera' | tr -d '\r')"

say "2. every loaded library in that process mentioning extension/pixel"
PID=$(adb shell 'pidof app.grapheneos.camera' | tr -d '\r')
adb shell "cat /proc/$PID/maps 2>/dev/null" | grep -oiE '[^/]*\.so' | sort -u | grep -iE 'ext|pixel|gcam|googlecamera' | head -25

say "3. is the class in any APK/jar ON THE DEVICE? (dex scan)"
adb shell 'for f in /system_ext/framework/*camera*ext*.jar /system/app/CameraExtensionsProxy/*.apk /product/app/Camera/*.apk; do echo "== $f"; pm dump "$f" >/dev/null 2>&1; done' 2>/dev/null | head

say "4. what does the camera app expect the proxy package/class to be?"
adb logcat -d 2>/dev/null | grep -iE 'ExtensionsManager|VENDOR_ACTION|cameraextensions|bindService' | tail -20

say "5. is CameraExtensionsProxy's own service DECLARED at all? (pm query)"
adb shell 'cmd package query-services -a androidx.camera.extensions.action.VENDOR_ACTION 2>&1' | head -10
adb shell 'dumpsys package com.android.cameraextensions 2>/dev/null | grep -iA4 "Service Resolver|CameraExtensionsProxyService"' | head -20

say "6. direct: dump the package's components"
adb shell 'pm dump com.android.cameraextensions 2>/dev/null | grep -iE "Service|androidx.camera" | head -20'

echo
echo "saved: ${OUT:-stdout}"
} 2>&1 | tee "$OUT"
