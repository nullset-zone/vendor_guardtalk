#!/usr/bin/env bash
# The device came back to fastboot after ~120s (not 30s like the 0xfc failures).
# Read the bootloader's own record of WHY. Read-only.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
OUT="${1:-$HOME/GuardTalk-flash/why-fastboot.txt}"
{
echo "why did it return to fastboot?  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
fastboot devices 2>&1
echo
echo "=== oem dmesg — the bootloader's record ==="
fastboot oem dmesg 2>&1 | tail -60
echo
echo "=== the lines that classify the failure ==="
fastboot oem dmesg 2>&1 | grep -E \
 'Reboot mode|AB Decisions|exitcode|0xbaba|fastboot enter|0xfc|0x7f00|0x00000100|Attempted to kill|PXL' \
 | tail -25
echo
echo "=== slot / retry state ==="
fastboot getvar current-slot 2>&1 | tail -2
fastboot getvar slot-retry-count:a 2>&1 | tail -2
fastboot getvar slot-retry-count:b 2>&1 | tail -2
fastboot getvar slot-unbootable:a 2>&1 | tail -2
fastboot getvar slot-unbootable:b 2>&1 | tail -2
echo
echo "=== bcd (recovery/command breadcrumbs) ==="
for k in command status recovery stage; do
  printf '  %-9s ' "$k"; fastboot oem bcd read "$k" 2>&1 | head -1
done
echo
echo "saved: $OUT"
} 2>&1 | tee "$OUT"
