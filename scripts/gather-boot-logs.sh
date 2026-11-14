#!/usr/bin/env bash
# gather-boot-logs.sh — pull EVERYTHING the bootloader will tell us about the last boot.
#
# Read-only. Writes nothing to the phone. Does not reboot, flash, erase, or unlock.
#
# ONE-LINE FORM:
#   curl -fsSL "http://192.168.2.220:8000/gather-boot-logs.sh" -o /tmp/gbl.sh && bash /tmp/gbl.sh
#
# Exit codes:  0 = captured (even if some sources were unavailable)
#              1 = no device on the USB bus
#              2 = upload to the build host failed (logs are still local)
set -uo pipefail

GT_SERVER="oss-c1@192.168.2.220"
GT_TREE="/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree"
GT_SERIAL_EXPECTED="59080DLCH0022P"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$HOME/GuardTalk-flash/logs-$STAMP"
mkdir -p "$OUT" || { echo "cannot create $OUT" >&2; exit 1; }

if [ -t 1 ]; then R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[36m'; D=$'\033[2m'; N=$'\033[0m'
else R=; G=; Y=; B=; D=; N=; fi
say()  { printf '\n%s=== %s ===%s\n' "$B" "$*" "$N"; }
ok()   { printf '%s  OK  %s\n'   "$G" "$*"; }
miss() { printf '%s  --  %s\n'   "$D" "$*"; }
warn() { printf '%s WARN %s\n'   "$Y" "$*"; }

command -v fastboot >/dev/null 2>&1 || { echo "fastboot not on PATH" >&2; exit 1; }

# ---------------------------------------------------------------- device --
say "device"
DEVS="$(fastboot devices 2>&1 | tr -d '\r' | sed '/^[[:space:]]*$/d')"
printf '%s\n' "$DEVS" | sed 's/^/   /'
if [ -z "$DEVS" ]; then
    warn "no fastboot device. Put the phone in fastboot (Vol-Down + Power) and re-run."
    printf '     The screen must say FASTBOOT MODE.\n'
    exit 1
fi

SERIAL="$(printf '%s\n' "$DEVS" | awk 'NR==1{print $1}')"
COUNT="$(printf '%s\n' "$DEVS" | wc -l | tr -d ' ')"
if [ "$COUNT" -ne 1 ]; then
    warn "$COUNT devices attached — logs will be tagged with $SERIAL but verify that is the right one."
fi
if [ "$SERIAL" != "$GT_SERIAL_EXPECTED" ]; then
    warn "serial $SERIAL != expected $GT_SERIAL_EXPECTED — you may be on a different phone."
fi
ok "using serial $SERIAL"
FB() { fastboot -s "$SERIAL" "$@"; }

# ------------------------------------------------------------ getvar all --
# This is the richest single source: partition names+sizes, slot metadata,
# retry counts, boot reason, and the bootloader's own version.
say "getvar all"
FB getvar all > "$OUT/getvar-all.txt" 2>&1
ok "$(wc -l < "$OUT/getvar-all.txt" | tr -d ' ') lines"

# The fields that actually explain a boot loop.
{
  printf '# slot / retry / boot-decision state\n'
  grep -iE 'current-slot|slot-(successful|unbootable|retry)|boot-reason|reboot|last_boot|avb|verity|verified|unlocked|secure|slot-count' \
      "$OUT/getvar-all.txt" 2>/dev/null | sed 's/^[[:space:]]*//'
} > "$OUT/slot-state.txt" 2>&1
ok "slot-state.txt"
sed 's/^/   /' "$OUT/slot-state.txt" | head -30

# ------------------------------------------------------------ oem dmesg --
# The bootloader's log. Present on laguna. Contains the panic reason string
# ("Attempted to kill init!") but NOT init's own output.
say "oem dmesg"
if FB oem dmesg > "$OUT/oem-dmesg.txt" 2>&1; then
    # NOTE: do NOT reject on substrings like "Invalid"/"UNKNOWN". A healthy dmesg
    # legitimately contains "[LNXDBG] Invalid PGTABLE_LEVELS", "Invalidate AP RAM
    # regions" and "UNKNOWN+0x0" stack frames. Only a genuine command REJECTION
    # counts as unusable: fastboot prints "FAILED (remote: ...)" or "unknown oem
    # command" for an unsupported oem subcommand.
    if [ -s "$OUT/oem-dmesg.txt" ] && ! grep -qiE 'FAILED \(remote|unknown oem command|Invalid oem command' "$OUT/oem-dmesg.txt"; then
        ok "$(wc -l < "$OUT/oem-dmesg.txt" | tr -d ' ') lines"
        printf '\n   --- discrimination strings ---\n'
        grep -iE 'exitcode|Attempted to kill|Reboot reason|Reboot mode|AB Decisions|fastboot enter|panic' \
            "$OUT/oem-dmesg.txt" 2>/dev/null | sed 's/^/   /' | head -15
    else
        miss "oem dmesg returned nothing usable"
    fi
else
    miss "oem dmesg unsupported"
fi

# --------------------------------------------------------- oem klog/panic --
for variant in last_kmsg lastkmsg kmsg pstore console-ramoops ramoops bcd; do
    if FB oem "$variant" > "$OUT/oem-$variant.txt" 2>&1; then
        if [ -s "$OUT/oem-$variant.txt" ] && ! grep -qiE 'invalid oem command|not supported|unknown' "$OUT/oem-$variant.txt"; then
            ok "oem $variant ($(wc -c < "$OUT/oem-$variant.txt" | tr -d ' ') bytes)"
        else
            miss "oem $variant unsupported"
            rm -f "$OUT/oem-$variant.txt"
        fi
    else
        miss "oem $variant unavailable"
        rm -f "$OUT/oem-$variant.txt"
    fi
done

# ------------------------------------------------------- fetch partitions --
# `fastboot fetch` reads a RAW partition. This is the only path to the real
# kernel ramoops ring buffer (init's own stdout/stderr: why execv failed).
say "fetch RAM-loggable partitions (the important part)"
FETCHED=0
for part in pstore console-ramoops ramoops metadata misc; do
    if FB fetch "$part" "$OUT/part-$part.bin" > "$OUT/fetch-$part.log" 2>&1; then
        if [ -s "$OUT/part-$part.bin" ]; then
            ok "fetched $part ($(wc -c < "$OUT/part-$part.bin" | tr -d ' ') bytes)"
            FETCHED=$((FETCHED + 1))
        else
            miss "$part empty"
            rm -f "$OUT/part-$part.bin"
        fi
    else
        miss "fetch $part not permitted"
        rm -f "$OUT/part-$part.bin"
    fi
done
[ "$FETCHED" -eq 0 ] && warn "no partition fetchable — ramoops stays on the device (see notes at the end)"

# If we got a pstore/ramoops blob, try to pull readable strings out of it.
for f in "$OUT"/part-pstore.bin "$OUT"/part-console-ramoops.bin "$OUT"/part-ramoops.bin; do
    [ -s "$f" ] || continue
    base="$(basename "$f" .bin)"
    strings -n 6 "$f" 2>/dev/null | grep -iE 'init|execv|mount|avb|dm-|verity|selinux|avc|apex|failed|error|denied|No such' \
        > "$OUT/$base-strings.txt" 2>/dev/null
    ok "$base-strings.txt ($(wc -l < "$OUT/$base-strings.txt" | tr -d ' ') relevant lines)"
done

# ------------------------------------------------------- bcd breadcrumbs --
say "bootloader breadcrumbs"
# `oem bcd` alone only prints usage; the value needs `oem bcd read <field>`.
for f in command status stage recovery; do
    if FB oem bcd read "$f" > "$OUT/bcd-$f.txt" 2>&1; then
        val="$(grep -oE "${f}:[[:space:]]*.*" "$OUT/bcd-$f.txt" 2>/dev/null | sed "s/^${f}:[[:space:]]*//" | tr -d '\r' | head -1)"
        if [ -n "$val" ]; then ok "bcd $f: $val"; else miss "bcd $f: empty (nothing recorded)"; fi
    else
        miss "bcd $f unavailable"; rm -f "$OUT/bcd-$f.txt"
    fi
done

# ------------------------------------------------------------ device info --
say "device info"
FB oem device-info > "$OUT/oem-device-info.txt" 2>&1 && ok "oem device-info" || miss "oem device-info"
FB getvar unlocked > "$OUT/unlocked.txt" 2>&1 && ok "unlocked=$($(command -v grep) -m1 '^unlocked:' "$OUT/unlocked.txt" 2>/dev/null | awk '{print $2}')" || true

# --------------------------------------------------------------- manifest --
say "manifest"
{
  echo "gathered_at_utc : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host            : $(uname -s) $(uname -r) $(uname -m)"
  echo "serial          : $SERIAL"
  echo "device_count    : $COUNT"
  echo "fastboot        : $(fastboot --version 2>&1 | head -1)"
  echo
  echo "--- files (bytes) ---"
  ( cd "$OUT" && ls -l | awk 'NR>1{printf "%-40s %10s\n", $9, $5}' )
} > "$OUT/MANIFEST.txt"
cat "$OUT/MANIFEST.txt" | sed 's/^/   /'

# ----------------------------------------------------------------- upload --
say "upload to build host"
DEST="$GT_TREE/runtime/harvests/logs-blazer-$STAMP"
TARBALL="/tmp/logs-blazer-$STAMP.tar.gz"
( cd "$HOME/GuardTalk-flash" && tar czf "$TARBALL" "logs-$STAMP" 2>/dev/null )
if [ -f "$TARBALL" ] && ssh -o BatchMode=yes -o ConnectTimeout=10 "$GT_SERVER" "mkdir -p '$DEST'" 2>/dev/null \
   && scp -q -o BatchMode=yes "$TARBALL" "$GT_SERVER:$DEST/" 2>/dev/null; then
    ok "uploaded → $DEST/logs-blazer-$STAMP.tar.gz"
    printf '   %sThe agent can read this directly; just tell it the path above.%s\n' "$D" "$N"
else
    warn "upload failed — logs are still local at $OUT"
    exit 2
fi

say "done"
printf '  local : %s\n' "$OUT"
printf '  remote: %s\n' "$DEST"
if [ "$FETCHED" -eq 0 ]; then
    printf '\n  %sNo ramoops partition was fetchable.%s The kernel buffer (which holds\n' "$Y" "$N"
    printf '  init'"'"'s own stderr) then only exists in DRAM after a crash. Options:\n'
    printf '    a) set up USB-visible ramoops via the rescue boot, then re-flash\n'
    printf '    b) enable UART capture on the build host\n'
    printf '  Everything the BOOTLOADER knows is already in this bundle.\n'
fi
printf '\n  %sThis captures logs only. It does not flash, erase, unlock or reboot.%s\n' "$D" "$N"
