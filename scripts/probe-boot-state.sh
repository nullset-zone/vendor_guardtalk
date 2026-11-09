#!/usr/bin/env bash
# The device stayed up 120s with no adb and no fastboot. Find out what it is doing.
# Read-only.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
OUT="${1:-$HOME/GuardTalk-flash/boot-state.txt}"
for p in 5037 5099 5100 5101 5102 5038 5039; do
  if ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then export ANDROID_ADB_SERVER_PORT=$p; break; fi
done
say(){ printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }
{
echo "boot state probe  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
say "adb"
adb devices -l
say "fastboot"
fastboot devices 2>&1
say "is it enumerating on USB at all?"
system_profiler SPUSBDataType 2>/dev/null | grep -iE 'pixel|stallion|google' -A2 | head -12 || echo "  (no google usb device)"
echo
echo "TELL ME WHAT IS ON THE SCREEN:"
echo "  - Google G logo, frozen?"
echo "  - GuardTalk boot animation, looping?"
echo "  - Android home screen / setup wizard?"
echo "  - Black screen?"
echo "  - Recovery / 'No command'?"
} 2>&1 | tee "$OUT"
