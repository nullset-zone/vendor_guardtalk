#!/usr/bin/env bash
# GuardTalk — reproduce the Stallion camera failure and prove the cause.
# Run ON THE MAC with the handset attached. Read-only except force-stop/launch
# of the camera app itself (no install, no settings change, no flash).
#
#   bash ~/GuardTalk-flash/repro-camera-stallion.sh
#
# The previous capture was a post-hoc dump and could not show whether the app
# DIES or merely ANRs, because nothing launched it. This does.
set -uo pipefail

OUT="${1:-$HOME/GuardTalk-flash/camera-repro.txt}"
CAM="app.grapheneos.camera"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Cursor's Android integration may hold 5037 on this Mac.
for p in 5037 5099 5100 5101 5102 5038 5039; do
    if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then
        export ANDROID_ADB_SERVER_PORT=$p
        break
    fi
done

say() { printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }

{
echo "=============================================="
echo " Stallion camera repro   (adb port ${ANDROID_ADB_SERVER_PORT:-default})"
echo " host: $(hostname)  at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="

adb devices -l
[ -n "$(adb devices | awk '$2=="device"{print $1;exit}')" ] || { echo "NO DEVICE"; exit 1; }

say "1. is the extension proxy present at all?"
adb shell 'pm list packages 2>/dev/null | grep -iE "cameraextensions|CameraExtensionsProxy"' || true
adb shell 'service list 2>/dev/null | grep -iE "ICameraExtensionsProxyService"' || echo "  (not registered)"

say "2. clean slate: force-stop, clear the log buffer"
adb shell "am force-stop $CAM" 2>/dev/null
sleep 1
adb logcat -c 2>/dev/null

ACT="$(adb shell "cmd package resolve-activity --brief $CAM 2>/dev/null | tail -1" | tr -d '\r')"
echo "  activity: ${ACT:-<none>}"

say "3. launch and watch"
adb shell "am start -W -n ${ACT:-$CAM/.MainActivity}" 2>&1 | head -8
echo "  waiting 15s..."
sleep 15

say "4. did the process survive?"
PID="$(adb shell "pidof $CAM" 2>/dev/null | tr -d '\r')"
if [ -n "$PID" ]; then
    echo "  ALIVE (pid $PID)  -> it did NOT die"
else
    echo "  GONE -> it died"
fi

say "5. the decisive test: extension-proxy errors on the main thread"
adb logcat -d 2>/dev/null \
  | grep -iE 'ExtensionsManager|PXLEXT|ICameraExtensionsProxyService|CameraExtensionsProxy|NullPointerException' \
  | tail -40 || true

say "6. configure / ANR / input-dispatch evidence"
adb logcat -d 2>/dev/null \
  | grep -iE 'Unable to configure|TimeoutException|InputDispatcher.*unresponsive|ANR in|Camera2CameraImpl|CameraService.*connect' \
  | tail -40 || true

say "7. crash buffer (app fatals only)"
adb logcat -d -b crash 2>/dev/null | grep -A6 -iE "Process: $CAM" | tail -40 || echo "  (no crash for $CAM)"

say "8. verdict"
CFG=$(adb logcat -d 2>/dev/null | grep -c 'Unable to configure camera')
EXT=$(adb logcat -d 2>/dev/null | grep -ciE 'ExtensionsManager|ICameraExtensionsProxyService|PXLEXT')
ANR=$(adb logcat -d 2>/dev/null | grep -c "ANR in $CAM")
die=$(adb logcat -d -b crash 2>/dev/null | grep -c "Process: $CAM")
echo "  configure_timeouts = $CFG"
echo "  extension_errors   = $EXT"
echo "  anr_count          = $ANR"
echo "  app_crashes        = $die"
echo
if [ "$EXT" -gt 0 ] && [ "$CFG" -gt 0 ]; then
    echo "  => CAUSE B CONFIRMED: extension proxy missing, main thread stalls,"
    echo "     configureStreams times out. Restore CameraExtensionsProxy."
elif [ "$EXT" -eq 0 ] && [ "$CFG" -gt 0 ]; then
    echo "  => Extension proxy is NOT implicated (no extension errors)."
    echo "     configureStreams stalls for some other reason — investigate further."
elif [ "$die" -gt 0 ]; then
    echo "  => The app CRASHES (not an ANR). Read section 7."
else
    echo "  => Inconclusive from these counters; read sections 5-7."
fi

echo
echo "saved: $OUT"
} 2>&1 | tee "$OUT"
