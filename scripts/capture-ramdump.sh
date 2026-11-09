#!/usr/bin/env bash
# Get a real kernel log off the Stallion. Tries the non-destructive routes in
# order and reports which one the bootloader actually honours.
# Read-only apart from the ramdump capture itself. Run on the Mac.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DEST="${1:-$HOME/GuardTalk-flash/ramdump}"
mkdir -p "$DEST"
say(){ printf '\n\033[36m=== %s ===\033[0m\n' "$*"; }

{
echo "Stallion kernel-log capture  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "dest: $DEST"
say "0. device"
fastboot devices 2>&1
if ! fastboot devices 2>/dev/null | grep -q .; then
  echo "  NO FASTBOOT DEVICE — stop"; exit 1
fi

say "1. what ramdump commands does this bootloader advertise?"
fastboot oem ramdump 2>&1 | head -20

say "2. current ramdump settings (do NOT change them)"
fastboot oem ramdump misc 2>&1 | head -10

say "3. capture oem dmesg in full (bootloader record) — baseline"
fastboot oem dmesg > "$DEST/oem-dmesg-full.txt" 2>&1
echo "  saved $(wc -l < "$DEST/oem-dmesg-full.txt") lines"

say "4. does it expose last_kmsg or pstore via any oem command?"
for c in last_kmsg lastkmsg pstore kmsg console-ramoops ramoops; do
  printf '  oem %-16s -> ' "$c"
  fastboot oem "$c" 2>&1 | head -1
done

say "5. TRIGGER A RAMDUMP (this is the whole point)"
echo "  running: fastboot oem ramdump now"
fastboot oem ramdump now 2>&1 | head -20
echo "  waiting 20s for the dump to be written / offered..."
sleep 20
fastboot devices 2>&1

say "6. did a ramdump appear as a device or a USB mass-storage target?"
system_profiler SPUSBDataType 2>/dev/null | grep -iE 'pixel|stallion|google' -A3 | head -20 || echo "  (no google device on USB)"

say "7. post-trigger bootloader state"
fastboot getvar current-slot 2>&1 | tail -1
fastboot getvar slot-retry-count:a 2>&1 | tail -1

echo
echo "captured into: $DEST"
} 2>&1 | tee "$DEST/capture.txt"
