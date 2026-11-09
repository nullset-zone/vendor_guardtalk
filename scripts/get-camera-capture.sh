#!/usr/bin/env bash
# GuardTalk — get the Stallion camera capture.
# Run this ON THE MAC. It recovers adb, finds the phone, and captures the
# camera failure in one pass. Read-only against the phone.
#
#   bash ~/GuardTalk-flash/get-camera-capture.sh
#
# Produces ~/GuardTalk-flash/camera-diag.txt
set -uo pipefail

OUT="${1:-$HOME/GuardTalk-flash/camera-diag.txt}"
SERIAL_WANT="67201JEA300680"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

say() { printf '\n\033[36m== %s ==\033[0m\n' "$*"; }
ok()  { printf '   \033[32mOK\033[0m   %s\n' "$*"; }
no()  { printf '   \033[31mNO\033[0m   %s\n' "$*"; }
note(){ printf '        %s\n' "$*"; }

say "0. where is the phone?"
FB="$(fastboot devices 2>/dev/null | awk 'NF{print $1" "$2}')"
if [ -n "$FB" ]; then
    no "phone is in FASTBOOT, not Android:"
    printf '%s\n' "$FB" | sed 's/^/        /'
    note "Rebooting to Android:"
    fastboot reboot >/dev/null 2>&1 && ok "reboot sent — wait for the home screen, then re-run this script"
    exit 3
fi
ok "not in fastboot"

say "1. does macOS see the USB device?"
USB_SEEN=0
if system_profiler SPUSBDataType 2>/dev/null | grep -qiE 'pixel|stallion|google'; then
    USB_SEEN=1
    ok "USB device present"
    system_profiler SPUSBDataType 2>/dev/null | grep -iE 'pixel|stallion|google|Serial Number' | head -6 | sed 's/^/        /'
else
    no "no Google/Pixel USB device at all"
    note "(adb may still reach it over a tunnel, so continuing.)"
fi

say "2. restart adb cleanly"
adb kill-server >/dev/null 2>&1
for p in 5037 5099 5100 5101 5102 5038 5039; do
    if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then
        export ANDROID_ADB_SERVER_PORT=$p
        ok "adb server on port $p"
        break
    fi
done
sleep 2
DEVS="$(adb devices 2>/dev/null | awk 'NR>1 && NF')"
if [ -z "$DEVS" ]; then
    no "adb still sees nothing"
else
    printf '%s\n' "$DEVS" | sed 's/^/        /'
fi
say "3. verdict"
STATE=""
if [ -n "$DEVS" ]; then
    STATE="$(printf '%s\n' "$DEVS" | awk '{print $2}' | head -1)"
fi

case "$STATE" in
    device)
        ok "phone is authorized and reachable"
        if ! printf '%s\n' "$DEVS" | awk '{print $1}' | grep -qx "$SERIAL_WANT"; then
            no "but the serial is not $SERIAL_WANT — refusing to capture from another handset"
            exit 4
        fi
        ;;
    unauthorized)
        no "phone is present but NOT AUTHORIZED"
        note "Unlock the phone and tap ALLOW on 'Allow USB debugging?'"
        note "(tick 'Always allow from this computer'), then re-run this script."
        exit 2
        ;;
    offline)
        no "phone is OFFLINE"
        note "Unplug, replug, then re-run this script."
        exit 2
        ;;
    *)
        no "no usable transport"
        if [ "${USB_SEEN:-0}" = "1" ]; then
            note "macOS sees the phone on USB, so the cable is fine."
            note "That means USB debugging is off, or the phone has not authorized this Mac."
            note "On the phone:"
            note "  Settings -> About phone -> tap 'Build number' 7 times"
            note "  Settings -> System -> Developer options -> USB debugging: ON"
            note "  Unlock the phone (not just the lock screen) and tap ALLOW on the prompt"
        else
            note "macOS does not see the phone at all, so adb cannot either."
            note "Fix the physical connection first, then re-run:"
            note "  - a different cable (charge-only cables look identical)"
            note "  - a port directly on the Mac, not a hub"
            note "  - a different USB port"
            note ""
            note "If the cable is certainly good, USB debugging may also be off:"
            note "  Settings -> About phone -> tap 'Build number' 7 times"
            note "  Settings -> System -> Developer options -> USB debugging: ON"
        fi
        note ""
        note "Also make sure the phone is UNLOCKED with the screen on —"
        note "adb cannot authorize while the lock screen is up."
        exit 1
        ;;
esac

say "4. capturing the camera failure"
note "The script is read-only. It launches nothing."
note "IMPORTANT: when you see 'capturing...', OPEN THE CAMERA APP on the phone"
note "and let it fail. That is what lets us tell cause A from cause B."
note ""
note "Starting in 5 seconds."
sleep 5

DIAG="$(dirname "$0")/diag-camera-stallion.sh"
if [ ! -f "$DIAG" ]; then
    no "diag-camera-stallion.sh not found next to this script"
    note "Fetch it: curl -fsSL 'http://192.168.2.220:8000/diag-camera-stallion.sh' -o \"$DIAG\""
    exit 5
fi

say "capturing — OPEN THE CAMERA APP NOW and wait for it to fail"
bash "$DIAG" "$OUT"
RC=$?

say "5. result"
if [ -f "$OUT" ]; then
    ok "capture written: $OUT"
    printf '        %s bytes, %s lines\n' "$(wc -c < "$OUT" | tr -d ' ')" "$(wc -l < "$OUT" | tr -d ' ')"
    note "Send this file back."
else
    no "no capture file was produced (exit $RC)"
fi
exit "$RC"
