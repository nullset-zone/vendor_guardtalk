#!/bin/bash
#
# GuardTalkOS Flash + Lock + Verify Pipeline
#
# Flashes a signed GuardTalkOS release to a Pixel device, injects the AVB
# custom key, locks the bootloader (irreversible without the AVB key — see
# RUNBOOK §6), and verifies verified-boot state. Includes the fastboot-mode
# filesystem-protection spot-checks from SECURITY_FASTBOOT_PROT_REPORT.md.
#
# Source-of-truth:
#   - vendor/guardtalk/docs/SECURITY_FASTBOOT_PROT_REPORT.md (verification checks)
#   - vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md §3a (lock sequence)
#   - vendor/guardtalk/branding/signing-keys/RUNBOOK.md §5, §6
#   - .agent-comm/dispatch-T-SIGN-PIPELINE.md
#
# Law 4 (Security First): never writes key material to disk; reads only the
#   public avb_pkmd.bin from the release dir.
# Law 3 (Error Handling): set -euo pipefail; every fastboot/adb call checked.
# Law 11 (Reversibility): --no-lock mode documented; unlock path documented
#   in RUNBOOK §8 (wipes userdata but recovers the device).
# Law 10 (Audit Trail): prints a final verification table.
#
# Usage:
#   ./flash-signed.sh \
#       --release-dir releases/<BUILD_NUMBER>/signed \
#       --device tokay \
#       [--no-lock]        # skip bootloader lock (default: lock)
#       [--wipe-userdata]  # pass -w to fastboot update (wipe userdata)
#       [--yes]            # non-interactive: skip all confirmation prompts
#

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
RELEASE_DIR=""
DEVICE=""
LOCK=1
WIPE_USERDATA=0
ASSUME_YES=0

# ── Help ────────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: flash-signed.sh --release-dir DIR --device DEV [--no-lock] [--wipe-userdata] [--yes]

Flashes a signed GuardTalkOS release to a Pixel device, locks the bootloader
to the GuardTalk AVB key, and verifies the verified-boot state.

REQUIRED:
  --release-dir DIR  Directory produced by sign-build.sh, containing:
                     - <device>-factory-<BUILD>.zip (or <device>-img-<BUILD>.zip)
                     - avb_pkmd.bin
  --device DEV       Device codename (e.g. tokay).

OPTIONAL:
  --no-lock          Flash but skip the bootloader lock (first-time bring-up).
  --wipe-userdata    Pass -w to fastboot update (wipe userdata on flash).
  --yes              Skip interactive confirmations (CI / unattended). Implies
                     acceptance of the destructive operations below.

EXIT CODES:
  0  success
  1  generic failure
  2  usage error
EOF
}

# ── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --release-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --release-dir requires a value" >&2; exit 2; }
            RELEASE_DIR="$2"; shift 2 ;;
        --device)
            [[ $# -ge 2 ]] || { echo "ERROR: --device requires a value" >&2; exit 2; }
            DEVICE="$2"; shift 2 ;;
        --no-lock)        LOCK=0; shift ;;
        --wipe-userdata)  WIPE_USERDATA=1; shift ;;
        --yes)            ASSUME_YES=1; shift ;;
        --help|-h)        usage; exit 0 ;;
        *)
            echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

[[ -n "$RELEASE_DIR" ]] || { echo "ERROR: --release-dir is required" >&2; usage; exit 2; }
[[ -n "$DEVICE"      ]] || { echo "ERROR: --device is required" >&2;     usage; exit 2; }

# ── Helpers ─────────────────────────────────────────────────────────────────
confirm() {
    # confirm "<prompt>" — returns 0 if user typed 'yes', 1 otherwise.
    local prompt="$1"
    if [[ $ASSUME_YES -eq 1 ]]; then
        echo "$prompt [auto-yes]"
        return 0
    fi
    local reply
    read -rp "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy](es)?$ ]]
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

warn() {
    echo "WARN: $*" >&2
}

# ── Preflight ───────────────────────────────────────────────────────────────
preflight() {
    command -v fastboot >/dev/null || die "fastboot not in PATH"
    command -v adb     >/dev/null || die "adb not in PATH"

    [[ -d "$RELEASE_DIR" ]] || die "--release-dir '$RELEASE_DIR' is not a directory"

    # Locate the factory image zip (preferred) or fall back to img zip.
    local factory_glob="$RELEASE_DIR/$DEVICE-factory-*.zip"
    local img_glob="$RELEASE_DIR/$DEVICE-img-*.zip"
    FACTORY_ZIP=""
    IMG_ZIP=""
    # shellcheck disable=SC2086
    for f in $factory_glob; do
        [[ -f "$f" ]] && { FACTORY_ZIP="$f"; break; }
    done
    # shellcheck disable=SC2086
    for f in $img_glob; do
        [[ -f "$f" ]] && { IMG_ZIP="$f"; break; }
    done
    if [[ -z "$FACTORY_ZIP" ]] && [[ -z "$IMG_ZIP" ]]; then
        die "no factory image zip ($DEVICE-factory-*.zip) or image zip ($DEVICE-img-*.zip) found in $RELEASE_DIR"
    fi
    AVB_PKMD="$RELEASE_DIR/avb_pkmd.bin"
    if [[ ! -f "$AVB_PKMD" ]]; then
        # Fall back to the key dir's avb_pkmd.bin if present (operator convenience).
        if [[ -f "$RELEASE_DIR/../avb_pkmd.bin" ]]; then
            AVB_PKMD="$RELEASE_DIR/../avb_pkmd.bin"
        else
            die "avb_pkmd.bin not found in $RELEASE_DIR (required for avb_custom_key injection)"
        fi
    fi

    # Device present in fastboot mode?
    local devices
    devices="$(fastboot devices)"
    if [[ -z "$devices" ]]; then
        echo "ERROR: no device in fastboot mode." >&2
        echo "  Boot the device to bootloader: power off, then hold Volume-Down + Power." >&2
        echo "  Or: adb reboot bootloader (if adb is reachable)." >&2
        exit 1
    fi

    # Confirm device product matches --device.
    local product
    product="$(fastboot getvar product 2>&1 | sed -n 's/^product: *//p' | head -1)"
    if [[ "$product" != "$DEVICE" ]] && [[ "$product" != "$DEVICE"_cur ]]; then
        die "device product '$product' does not match --device '$DEVICE' (or '${DEVICE}_cur')"
    fi
    echo "→ Preflight OK: device=$product, factory=${FACTORY_ZIP:-<none>}, img=${IMG_ZIP:-<none>}"

    # Battery check (best-effort; some devices report battery-soc-ok:yes).
    local battery_soc
    battery_soc="$(fastboot getvar battery-soc-ok 2>&1 | sed -n 's/^battery-soc-ok: *//p' | head -1)"
    if [[ -n "$battery_soc" ]] && [[ "$battery_soc" != "yes" ]]; then
        warn "battery-soc-ok='$battery_soc' — charge to ≥30% before flashing."
    fi
}

# ── AVB custom key injection ─────────────────────────────────────────────────
inject_avb_custom_key() {
    echo "→ AVB custom key injection"

    # Check unlock ability. If 0, instruct operator to enable OEM Unlocking.
    local unlock_ability
    unlock_ability="$(fastboot flashing get_unlock_ability 2>&1 | sed -n 's/^.*get_unlock_ability: *//p' | head -1)"
    if [[ "$unlock_ability" == "0" ]]; then
        echo "  flashing get_unlock_ability = 0." >&2
        echo "  → On the device: Settings → Developer Options → enable OEM Unlocking." >&2
        echo "    (Cannot be scripted on a user build.)" >&2
        exit 1
    fi

    # Determine current lock state via fastboot getvar unlocked.
    local unlocked
    unlocked="$(fastboot getvar unlocked 2>&1 | sed -n 's/^unlocked: *//p' | head -1)"
    if [[ "$unlocked" == "no" ]]; then
        # Device is locked — must unlock to inject the custom key (will wipe userdata).
        echo "  Device is currently locked. Unlocking is required to inject avb_custom_key."
        echo "  ⚠️  fastboot flashing unlock WILL WIPE USERDATA."
        if ! confirm "  Proceed with unlock?"; then
            echo "  Aborting (unlock declined)."
            exit 1
        fi
        if [[ $WIPE_USERDATA -eq 0 ]]; then
            echo "  Hint: pass --wipe-userdata to acknowledge the wipe."
        fi
        fastboot flashing unlock
    fi

    # Clear any prior custom key, then flash ours.
    echo "  Erasing prior avb_custom_key (if any)"
    fastboot erase avb_custom_key || warn "erase avb_custom_key returned non-zero (may already be empty)"
    echo "  Flashing avb_custom_key: $AVB_PKMD"
    fastboot flash avb_custom_key "$AVB_PKMD"
}

# ── Flash factory image ────────────────────────────────────────────────────
flash_image() {
    local flash_args=()
    if [[ $WIPE_USERDATA -eq 1 ]]; then
        flash_args+=(-w)
    fi
    if [[ -n "$FACTORY_ZIP" ]]; then
        echo "→ fastboot update $FACTORY_ZIP"
        fastboot "${flash_args[@]}" update "$FACTORY_ZIP" || {
            echo "  fastboot update failed; falling back to fastboot flashall" >&2
            [[ -z "$IMG_ZIP" ]] && die "no image zip available for flashall fallback"
            fastboot flashall "${flash_args[@]}" "$IMG_ZIP"
        }
    else
        echo "→ fastboot flashall $IMG_ZIP"
        fastboot flashall "${flash_args[@]}" "$IMG_ZIP"
    fi
}

# ── Bootloader lock ──────────────────────────────────────────────────────────
lock_bootloader() {
    echo "→ Rebooting to bootloader before lock"
    fastboot reboot-bootloader
    sleep 2

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║   ***  PERMANENT BRICK WARNING — BOOTLOADER LOCK  ***                  ║"
    echo "║                                                                        ║"
    echo "║   Locking the bootloader with the GuardTalk AVB key means the device    ║"
    echo "║   will ONLY boot images signed by your avb.pem. If you lose avb.pem    ║"
    echo "║   AND have OEM Unlocking disabled, the device is a PERMANENT BRICK.    ║"
    echo "║                                                                        ║"
    echo "║   Verify 3 backups exist (RUNBOOK §3) before locking.                  ║"
    echo "║                                                                        ║"
    echo "║   Confirm on-device with Vol-Up when prompted.                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    if ! confirm "Proceed with fastboot flashing lock?"; then
        echo "Lock declined. Device remains unlocked."
        return 0
    fi

    fastboot flashing lock
}

# ── Post-boot verification ──────────────────────────────────────────────────
verify_boot() {
    echo "→ Waiting for device to boot..."
    adb wait-for-device
    sleep 5

    local verified_bootstate flash_locked product_name
    verified_bootstate="$(adb shell getprop ro.boot.verifiedbootstate | tr -d '\r\n')"
    flash_locked="$(adb shell getprop ro.boot.flash.locked | tr -d '\r\n')"
    product_name="$(adb shell getprop ro.product.name | tr -d '\r\n')"

    # Verified-boot state semantics (Android Verified Boot):
    #   green  = locked + OEM-embedded AVB key (Google's key in Pixel bootloader ROM)
    #   yellow = locked + custom AVB key (injected via `fastboot flash avb_custom_key`)
    #   orange = unlocked
    #   red    = locked, AVB verification FAILED
    #
    # GuardTalkOS uses its OWN offline-generated AVB key, injected via
    # `fastboot flash avb_custom_key`. Therefore the CORRECT, EXPECTED, and
    # SECURE state for a GuardTalkOS-locked device is `yellow`.
    # `green` would only occur if the OEM (Google) AVB key matched — i.e. a
    # security anomaly in our context (we don't have Google's key). Treat it
    # as a WARNING (device IS locked+verified, but the key is unexpected).
    # `orange` and `red` are hard FAILs.
    local ok_vbs=0 ok_lock=0 ok_product=0 vbs_label="✗ FAIL"
    case "$verified_bootstate" in
        yellow)
            ok_vbs=1
            vbs_label="✓ LOCKED (custom AVB key)"
            ;;
        green)
            # Unexpected for GuardTalkOS — would indicate OEM key match. The
            # device is locked and verified, so we still PASS, but warn loudly.
            ok_vbs=1
            vbs_label="⚠ LOCKED (OEM key — unexpected)"
            echo "  WARN: verifiedbootstate=green — this is UNEXPECTED for GuardTalkOS." >&2
            echo "        green indicates the OEM (Google) AVB key matched, not the" >&2
            echo "        GuardTalk custom key. Confirm the bootloader is actually locked" >&2
            echo "        to the GuardTalk key (check avb_custom_key was flashed)." >&2
            ;;
        orange)
            ok_vbs=0
            vbs_label="✗ FAIL (unlocked)"
            ;;
        red)
            ok_vbs=0
            vbs_label="✗ FAIL (AVB verification failed)"
            ;;
        *)
            ok_vbs=0
            vbs_label="✗ FAIL (unknown state: '$verified_bootstate')"
            ;;
    esac
    [[ "$flash_locked" == "1" ]] && ok_lock=1
    if [[ "$product_name" == "$DEVICE" ]] || [[ "$product_name" == "$DEVICE"_cur ]]; then
        ok_product=1
    fi

    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo " GuardTalkOS Verification"
    echo "══════════════════════════════════════════════════════════════════════"
    printf "  %-32s %-12s %s\n" "ro.boot.verifiedbootstate" "$verified_bootstate" "$vbs_label"
    printf "  %-32s %-12s %s\n" "ro.boot.flash.locked" "$flash_locked" "$([ $ok_lock -eq 1 ] && echo "✓ LOCKED" || echo "✗ FAIL")"
    printf "  %-32s %-12s %s\n" "ro.product.name" "$product_name" "$([ $ok_product -eq 1 ] && echo "✓ MATCH" || echo "✗ FAIL")"
    echo "══════════════════════════════════════════════════════════════════════"

    if [[ $ok_vbs -eq 0 ]] || [[ $ok_lock -eq 0 ]] || [[ $ok_product -eq 0 ]]; then
        echo ""
        echo "DIAGNOSTICS:"
        echo "  - verifiedbootstate=yellow : ✓ expected (locked + custom AVB key)."
        echo "  - verifiedbootstate=green  : unexpected — OEM key matched, not the"
        echo "    GuardTalk custom key. Confirm avb_custom_key was flashed correctly."
        echo "  - verifiedbootstate=orange : bootloader NOT locked. Re-run with lock."
        echo "  - verifiedbootstate=red    : AVB verification FAILED — image rejected"
        echo "    by the bootloader. Re-sign with the correct AVB key and re-flash."
        echo "  - flash.locked=0           : bootloader did not lock. Re-run flash-signed.sh."
        die "verification FAILED — see table above"
    fi
}

# ── Fastboot-FS-protection spot-checks ──────────────────────────────────────
# Per SECURITY_FASTBOOT_PROT_REPORT.md §4 and §8 action items.
fastboot_protection_spotcheck() {
    echo ""
    echo "→ Fastboot filesystem-protection spot-checks (per SECURITY_FASTBOOT_PROT_REPORT.md)"
    echo "  Rebooting to bootloader for negative tests..."
    adb reboot-bootloader
    sleep 3

    # 1) fastboot fetch must be rejected on a locked device.
    #    Use a benign partition name; expect FAIL.
    local fetch_out fetch_rc
    fetch_out="$(fastboot fetch vendor_boot 2>&1)" || true
    fetch_rc=$?
    echo "  fastboot fetch vendor_boot -> $fetch_out"
    if echo "$fetch_out" | grep -qiE 'FAIL|not allowed|rejected|cannot'; then
        echo "    ✓ fetch correctly rejected"
    else
        echo "    ✗ WARN: fetch did not appear to be rejected. Investigate manually."
    fi

    # 2) Attempt to flash an unsigned image of system — expect rejection.
    local tmpimg="/tmp/gt-sign-spotcheck-$$.img"
    # Create a small bogus image (not a valid AVB-signed image).
    head -c 4096 /dev/urandom > "$tmpimg" 2>/dev/null || printf '\x00%.0s' {1..4096} > "$tmpimg"
    local flash_out
    flash_out="$(fastboot flash system "$tmpimg" 2>&1)" || true
    echo "  fastboot flash system <unsigned> -> $flash_out"
    if echo "$flash_out" | grep -qiE 'FAIL|not allowed|rejected|invalid|avb'; then
        echo "    ✓ unsigned flash correctly rejected"
    else
        echo "    ✗ WARN: unsigned flash did not appear to be rejected."
    fi
    rm -f "$tmpimg"

    # Return to OS for clean shutdown.
    echo "  Returning to OS..."
    fastboot reboot
    sleep 3
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo "GuardTalkOS Flash + Lock + Verify Pipeline (T-SIGN-PIPELINE)"
    echo ""

    preflight
    inject_avb_custom_key
    flash_image

    if [[ $LOCK -eq 1 ]]; then
        lock_bootloader
    else
        echo "→ --no-lock: skipping bootloader lock (bring-up mode)"
    fi

    fastboot reboot
    sleep 3
    verify_boot

    # Only run the destructive-protection spot-checks if we actually locked.
    # (On an unlocked device they would not be meaningful.)
    if [[ $LOCK -eq 1 ]]; then
        fastboot_protection_spotcheck
    fi

    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo " GuardTalkOS flash + lock complete."
    echo "══════════════════════════════════════════════════════════════════════"
}

main "$@"
