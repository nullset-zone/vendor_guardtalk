#!/usr/bin/env bash
# blazer-stock-probe.sh (v2) — reach fastbootd, flash factory CP1A logicals,
#                             boot stock Android, harvest the kernel log.
#
# v1 BUG (fixed here): it flashed stock vbmeta with verity ON *before* entering
# fastbootd. Stock vbmeta's descriptors hash the STOCK partitions, but `super` still
# contained GuardTalk images, so AVB verification failed and fastbootd never started.
# The proven GuardTalk step-4 procedure flips BOTH vbmeta flags when entering
# fastbootd; this script now does the same.
#
# ONE-LINE FORM:
#   curl -fsSL "http://192.168.2.220:8000/blazer-stock-probe.sh" -o /tmp/bsp.sh && bash /tmp/bsp.sh
#
# ERASES userdata/metadata/super and leaves the device on stock Android.
set -uo pipefail

GT_SERIAL="59080DLCH0022P"
GT_SERVER="oss-c1@192.168.2.220"
GT_TREE="/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree"
GT_STOCK="$GT_TREE/releases/desktop-flash/blazer-stock-cp1a"
GT_RESCUE="$GT_TREE/releases/desktop-flash/blazer-rescue-boot"
GT_HOME="$HOME/GuardTalk-flash"
WORK="$GT_HOME/stock-cp1a"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

BOOTCHAIN=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img pvmfw.img)
LOGICALS=(system.img system_ext.img product.img vendor.img vendor_dlkm.img system_dlkm.img)
VBMETA=(vbmeta.img vbmeta_system.img vbmeta_vendor.img)

if [ -t 1 ]; then R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[36m'; D=$'\033[2m'; N=$'\033[0m'
else R=; G=; Y=; B=; D=; N=; fi
hdr(){ printf '\n%s=== %s ===%s\n' "$B" "$*" "$N"; }
ok(){ printf '%s  OK  %s\n' "$G" "$*"; }
warn(){ printf '%s WARN %s\n' "$Y" "$*"; }
die(){ printf '%s FATAL %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
info(){ printf '%s  ..  %s\n' "$D" "$*"; }
FB(){ fastboot -s "$GT_SERIAL" "$@"; }

# ---------------------------------------------------------------- preflight --
hdr "pre-flight"
for t in fastboot scp ssh shasum; do
    command -v "$t" >/dev/null 2>&1 || die "$t not found on PATH"
done
ok "tools present"

DEVS="$(fastboot devices 2>&1 | tr -d '\r' | sed '/^[[:space:]]*$/d')"
[ -n "$DEVS" ] || die "no fastboot device. Hold Vol-Down + Power to enter fastboot."
[ "$(printf '%s\n' "$DEVS" | wc -l | tr -d ' ')" -eq 1 ] || die "multiple devices — refusing to guess"
printf '%s\n' "$DEVS" | grep -q "^${GT_SERIAL}[[:space:]]" || die "not $GT_SERIAL — refusing"
ok "device $GT_SERIAL in fastboot"

ssh -o BatchMode=yes -o ConnectTimeout=10 "$GT_SERVER" true 2>/dev/null || die "cannot ssh $GT_SERVER"
ok "build host reachable"

# ------------------------------------------------------------------ images --
hdr "stock CP1A images"
mkdir -p "$WORK" || die "cannot create $WORK"
cd "$WORK" || die "cd failed"
for f in "${BOOTCHAIN[@]}" "${LOGICALS[@]}" "${VBMETA[@]}" super_empty.img; do
    [ -f "$f" ] || { info "fetch $f"; scp -q -o BatchMode=yes "$GT_SERVER:$GT_STOCK/$f" "./$f" || die "fetch $f failed"; }
done
[ -f SHA256SUMS ] || scp -q -o BatchMode=yes "$GT_SERVER:$GT_STOCK/SHA256SUMS" . || die "no SHA256SUMS"
BAD=0
while read -r sum name; do
    case " ${BOOTCHAIN[*]} ${LOGICALS[*]} ${VBMETA[*]} super_empty.img " in
        *" $name "*) ;;
        *) continue ;;
    esac
    [ -f "$name" ] || { warn "$name missing"; BAD=$((BAD+1)); continue; }
    [ "$(shasum -a 256 "$name" | cut -d' ' -f1)" = "$sum" ] || { warn "$name sha256 mismatch"; BAD=$((BAD+1)); }
done < SHA256SUMS
[ "$BAD" -eq 0 ] || die "$BAD image(s) failed sha256"
ok "all images sha256-verified"

# rescue chain, only used as a fallback
mkdir -p "$GT_HOME/rescue" && cd "$GT_HOME/rescue" || die "mkdir rescue failed"
for f in "${BOOTCHAIN[@]}" vbmeta.img; do
    [ -f "$f" ] || scp -q -o BatchMode=yes "$GT_SERVER:$GT_RESCUE/$f" "./$f" 2>/dev/null || true
done

# ----------------------------------------------------------- reach fastbootd --
# KEY: vbmeta must be flashed with BOTH --disable-verity and --disable-verification
# while `super` still holds mismatched images, or AVB fails and init never starts.
try_fastbootd() {
    local dir="$1" label="$2"
    hdr "flash boot chain: $label"
    cd "$dir" || return 1
    for f in "${BOOTCHAIN[@]}"; do
        [ -f "$f" ] || { warn "$label: $f missing"; return 1; }
        FB flash "${f%.img}" "$f" >/dev/null 2>&1 || { warn "$label: flash ${f%.img} failed"; return 1; }
    done
    local v="$dir/vbmeta.img"
    [ -f "$v" ] || { warn "$label: no vbmeta"; return 1; }
    info "flash vbmeta with --disable-verity --disable-verification"
    FB --disable-verity --disable-verification flash vbmeta "$v" >/dev/null 2>&1 \
        || { warn "$label: vbmeta flash failed"; return 1; }
    ok "$label boot chain flashed"

    hdr "reboot to fastbootd ($label)"
    FB reboot fastboot >/dev/null 2>&1
    sleep 3
    local i us
    for i in $(seq 1 45); do
        us="$(FB getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' | tr -d '\r')"
        [ "$us" = "yes" ] && { ok "fastbootd up after ~${i}s ($label)"; return 0; }
        sleep 1
    done
    warn "$label: fastbootd did NOT come up"
    # Grab the bootloader's view of why, before changing anything else.
    FB oem dmesg > "$GT_HOME/dmesg-$label.txt" 2>&1 || true
    return 1
}

if ! try_fastbootd "$WORK" "stock-CP1A"; then
    warn "falling back to the PROVEN rescue boot chain (BP4A)"
    FB reboot bootloader >/dev/null 2>&1; sleep 4
    try_fastbootd "$GT_HOME/rescue" "rescue-BP4A" \
        || die "fastbootd unreachable with BOTH chains. See $GT_HOME/dmesg-*.txt and report — do not keep re-flashing."
fi

# ------------------------------------------------------------ flash stock --
hdr "wipe super + flash stock logicals"
FB wipe-super "$WORK/super_empty.img" >/dev/null 2>&1 || warn "wipe-super non-zero (continuing)"
cd "$WORK" || die "cd failed"
for f in "${LOGICALS[@]}"; do
    info "flash ${f%.img} (large — please wait)"
    FB flash "${f%.img}" "$f" >/dev/null 2>&1 || die "flash ${f%.img} failed"
done
ok "stock logicals flashed"

hdr "back to bootloader; flash stock vbmeta"
FB reboot bootloader >/dev/null 2>&1; sleep 5
for v in "${VBMETA[@]}"; do
    FB --disable-verity --disable-verification flash "${v%.img}" "$WORK/$v" >/dev/null 2>&1 \
        || warn "flash ${v%.img} failed"
done
ok "vbmeta flashed (verification disabled — see note at end)"

# ----------------------------------------------------------------- boot+log --
hdr "reboot into STOCK Android"
FB --set-active=a >/dev/null 2>&1 || true
FB reboot >/dev/null 2>&1
echo "  Watching up to 5 minutes."

BOOTED=0
for i in $(seq 1 150); do
    sleep 2
    if adb devices 2>/dev/null | grep -qE "${GT_SERIAL}[[:space:]]+device"; then
        BOOTED=1; ok "Android is up after ~$((i*2))s"; break
    fi
    [ $((i % 15)) -eq 0 ] && info "still waiting... ($((i*2))s)"
done

if [ "$BOOTED" -ne 1 ]; then
    printf '\n%s  STOCK DID NOT BOOT%s\n' "$R" "$N"
    printf '  That is a finding, not a script failure. Capture what the screen shows.\n'
    printf '  Bootloader dmesg (if any) is in %s/dmesg-*.txt\n' "$GT_HOME"
    exit 20
fi

hdr "CAPTURE THE KERNEL LOG"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$GT_HOME/kmsg-$STAMP"; mkdir -p "$OUT"
adb shell 'dumpsys dropbox --print SYSTEM_LAST_KMSG' > "$OUT/SYSTEM_LAST_KMSG.txt" 2>&1
adb shell 'ls -l /data/system/dropbox/' > "$OUT/dropbox-listing.txt" 2>&1
adb shell 'cat /sys/fs/pstore/console-ramoops-0'  > "$OUT/pstore-console-ramoops-0.txt" 2>&1
adb shell 'ls -l /sys/fs/pstore/'                 > "$OUT/pstore-listing.txt" 2>&1
adb shell getprop                                 > "$OUT/getprop.txt" 2>&1
adb logcat -d                                     > "$OUT/logcat-boot.txt" 2>&1
{
  echo "captured_at : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "device      : $GT_SERIAL"
  echo "purpose     : kernel log of the last FAILED GuardTalk boot, read by stock init"
  echo "stock_image : CP1A.260505.005"
} > "$OUT/README.txt"
[ -s "$OUT/SYSTEM_LAST_KMSG.txt" ] && ok "SYSTEM_LAST_KMSG ($(wc -l < "$OUT/SYSTEM_LAST_KMSG.txt" | tr -d ' ') lines)" \
    || warn "SYSTEM_LAST_KMSG empty"

TAR="/tmp/kmsg-blazer-$STAMP.tar.gz"
( cd "$GT_HOME" && tar czf "$TAR" "kmsg-$STAMP" 2>/dev/null )
DEST="$GT_TREE/runtime/harvests/kmsg-blazer-$STAMP"
if ssh -o BatchMode=yes "$GT_SERVER" "mkdir -p '$DEST'" 2>/dev/null \
   && scp -q -o BatchMode=yes "$TAR" "$GT_SERVER:$DEST/" 2>/dev/null; then
    ok "uploaded → $DEST"
else
    warn "upload failed; logs local at $OUT"
fi

hdr "done"
printf '  STOCK BOOTED — the device is a working reference now.\n'
printf '  Kernel log: %s/SYSTEM_LAST_KMSG.txt\n' "$OUT"
printf '  %sGive the build-host path to the agent.%s\n' "$D" "$N"
printf '\n  %sNote: verification is DISABLED on this stock install (needed to reach\n' "$D"
printf '  fastbootd with a mismatched super). It does not affect the boot control or\n'
printf '  the pstore recovery.%s\n' "$N"
