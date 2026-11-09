#!/usr/bin/env bash
# Why won't CameraExtensionsProxy start?  Read-only + one non-destructive probe.
set -uo pipefail
OUT="${1:-$HOME/GuardTalk-flash/apexext-diag.txt}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
for p in 5037 5099 5100 5101 5102 5038 5039; do
  if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then export ANDROID_ADB_SERVER_PORT=$p; break; fi
done
say(){ printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }
{
echo "CameraExtensionsProxy diagnostic  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
adb devices -l
[ -n "$(adb devices | awk '$2=="device"{print $1;exit}')" ] || { echo "NO DEVICE"; exit 1; }

say "1. SELinux label of the files I hand-inserted"
adb shell 'ls -lZ /system/app/CameraExtensionsProxy/ 2>/dev/null'
adb shell 'ls -lZ /system/app/CameraExtensionsProxy/oat/arm64/ 2>/dev/null'
echo "  (a real system app is u:object_r:system_file:s0)"

say "2. is the package enabled and its service known to PMS?"
adb shell 'dumpsys package com.android.cameraextensions 2>/dev/null | grep -iE "enabled=|stopped=|Service|Permission" | head -20'

say "3. did the process ever start?"
adb shell 'ps -A 2>/dev/null | grep -i cameraextensions' || echo "  never running"

say "4. try to start it explicitly and watch"
adb logcat -c 2>/dev/null
adb shell 'am startservice -n com.android.cameraextensions/com.android.cameraextensions.CameraExtensionsProxyService 2>&1' | head -5
sleep 2
adb shell 'ps -A 2>/dev/null | grep -i cameraextensions' || echo "  still not running"

say "5. what the runtime says about loading it"
adb logcat -d 2>/dev/null | grep -iE \
 'cameraextensions|CameraExtensionsProxy|dex2oat|OatFile|Failed to open|avc: denied|SELinux|INSTALL_FAILED|ClassNotFound|NoClassDef|Rejecting' \
 | tail -50

say "6. the odex I inserted — does ART accept it?"
adb shell 'ls -l /system/app/CameraExtensionsProxy/oat/arm64/ 2>/dev/null'
adb logcat -d 2>/dev/null | grep -iE 'odex|vdex|checksum|oat' | grep -i camera | tail -20 || true

say "7. bind attempts and their error"
adb logcat -d 2>/dev/null | grep -iE 'PXLEXT|PixelExtensionsClient|ICameraExtensionsProxyService|Unable to bind|bindService' | tail -25

echo
echo "saved: $OUT"
} 2>&1 | tee "$OUT"
