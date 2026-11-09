#!/usr/bin/env bash
# One question: what does camerax's ExtensionVersionImpl actually try to bind,
# and is anything able to answer it?
set -uo pipefail
OUT="${1:-$HOME/GuardTalk-flash/vendor-ext-bind.txt}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
for p in 5037 5099 5100 5101 5102 5038 5039; do
  if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then export ANDROID_ADB_SERVER_PORT=$p; break; fi
done
say(){ printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }
{
echo "vendor extension bind diagnostic  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
adb devices -l
[ -n "$(adb devices | awk '$2=="device"{print $1;exit}')" ] || { echo "NO DEVICE"; exit 1; }

say "1. every service the system knows that looks like a camera extension vendor"
adb shell 'cmd package query-services -a androidx.camera.extensions.action.VENDOR_ACTION 2>&1' | head -20

say "2. what did camerax bind to? (full bind sequence, not just the failure line)"
adb shell 'am force-stop app.grapheneos.camera' 2>/dev/null
adb logcat -c 2>/dev/null
adb shell 'am start -W -n app.grapheneos.camera/.ui.activities.MainActivity' >/dev/null 2>&1
sleep 4
adb logcat -d 2>/dev/null | grep -iE 'ExtensionsManager|PXLEXT|bindService|VENDOR_ACTION|CameraExtensionsProxy|cameraextensions' | head -30

say "3. does the proxy APK's service resolve by explicit component?"
adb shell 'cmd package resolve-service -n com.android.cameraextensions/.CameraExtensionsProxyService 2>&1' | head -5
adb shell 'dumpsys package com.android.cameraextensions 2>/dev/null | grep -iB2 -A6 "Service" | head -30'

say "4. is the APK's dex actually loadable? (force dexopt now)"
adb shell 'cmd package compile -m speed -f com.android.cameraextensions 2>&1' | head -5

say "5. after that, can the service be bound?"
adb shell 'cmd package query-services -a androidx.camera.extensions.action.VENDOR_ACTION 2>&1' | head -10

echo
echo "saved: $OUT"
} 2>&1 | tee "$OUT"
