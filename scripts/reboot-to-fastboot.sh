#!/usr/bin/env bash
# reboot-to-fastboot.sh
#
# If the Pixel is booted into Android (or recovery) with USB debugging on,
# reboot it into the bootloader (fastboot). If it is already in fastboot,
# exit 0.
#
# The web wizard cannot run adb. Run this on the computer that has the USB
# cable, then continue in the wizard.
#
# Usage:
#   vendor/guardtalk/scripts/reboot-to-fastboot.sh
#
# Env:
#   ADB  FASTBOOT  FASTBOOT_WAIT_SECS  (defaults: adb, fastboot, 60)
set -euo pipefail

ADB="${ADB:-adb}"
FASTBOOT="${FASTBOOT:-fastboot}"
FASTBOOT_WAIT_SECS="${FASTBOOT_WAIT_SECS:-60}"

log() { echo "[fastboot] $*"; }
die() { echo "[fastboot] FATAL: $*" >&2; exit 1; }

adb_first_transport() {
    if ! command -v "$ADB" >/dev/null 2>&1; then
        return 0
    fi
    "$ADB" devices 2>/dev/null \
        | awk 'NR>1 && $1 != "" { print $1 "\t" $2; exit }' \
        || true
}

wait_for_fastboot() {
    local max_secs="${1:-$FASTBOOT_WAIT_SECS}"
    local attempts=$(( (max_secs + 1) / 2 ))
    local i devices
    for i in $(seq 1 "$attempts"); do
        sleep 2
        devices="$("$FASTBOOT" devices 2>/dev/null || true)"
        if [[ -n "$devices" ]]; then
            log "device entered fastboot after ${i} attempts ($(( i * 2 ))s)"
            printf '%s\n' "$devices"
            return 0
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastboot... (${i}/${attempts})"
    done
    devices="$("$FASTBOOT" devices 2>/dev/null || true)"
    [[ -n "$devices" ]]
}

command -v "$FASTBOOT" >/dev/null 2>&1 || die "fastboot not found in PATH (install platform-tools)"

DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
if [[ -n "$DEVICES" ]]; then
    log "Device already in fastboot"
    printf '%s\n' "$DEVICES"
    exit 0
fi

command -v "$ADB" >/dev/null 2>&1 \
    || die "No device in fastboot, and adb is not installed. Enable USB debugging or hold vol-down + power."

transport="$(adb_first_transport)"
if [[ -z "$transport" ]]; then
    die "No device in fastboot or adb. On the phone: enable Developer options + USB debugging, plug USB, accept the RSA prompt. Or hold vol-down + power."
fi

serial="$(printf '%s' "$transport" | awk -F'\t' '{print $1}')"
state="$(printf '%s' "$transport" | awk -F'\t' '{print $2}')"

case "$state" in
    device|recovery|sideload)
        product="$("$ADB" shell getprop ro.product.device 2>/dev/null | tr -d '\r' || true)"
        log "Phone is in Android/adb (serial=$serial, state=$state, product=${product:-unknown})"
        log "Rebooting into fastboot (bootloader)..."
        ;;
    unauthorized)
        die "adb device is unauthorized. Unlock the phone, accept the RSA fingerprint prompt, then re-run."
        ;;
    offline)
        die "adb device is offline (serial=$serial). Unplug/replug USB, toggle USB debugging, then re-run."
        ;;
    *)
        die "adb device state='$state' (serial=$serial) cannot auto-enter fastboot. Hold vol-down + power."
        ;;
esac

"$ADB" reboot bootloader \
    || die "adb reboot bootloader failed. Hold vol-down + power and retry."

wait_for_fastboot "$FASTBOOT_WAIT_SECS" \
    || die "Device did not enter fastboot after adb reboot bootloader (waited ${FASTBOOT_WAIT_SECS}s). Manual: vol-down + power."

log "OK — device is in fastboot. Continue in the wizard (Connect)."
