#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS tokay (Pixel 9) — remote flash script
# Pulls images from the build server and flashes them to the device via fastboot.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration — EDIT THESE
# -----------------------------------------------------------------------------
REMOTE_HOST="${REMOTE_HOST:-openstatestack@192.168.1.4}"
REMOTE_BUILD_DIR="${REMOTE_BUILD_DIR:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/out/target/product/tokay}"
REMOTE_KEY_DIR="${REMOTE_KEY_DIR:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/keys/tokay}"

LOCAL_WORK_DIR="${LOCAL_WORK_DIR:-.}"

FASTBOOT="${FASTBOOT:-fastboot}"

# -----------------------------------------------------------------------------
# Images to download
# -----------------------------------------------------------------------------
FW_IMAGES=(bootloader.img radio.img)
AB_IMAGES=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img)
NOAB_IMAGES=(dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img)
LOGICAL_IMAGES=(system.img system_ext.img product.img vendor.img vendor_dlkm.img system_dlkm.img)
EXTRA_FILES=(super_empty.img avb_pkmd.bin)

ALL_DOWNLOADS=("${FW_IMAGES[@]}" "${AB_IMAGES[@]}" "${NOAB_IMAGES[@]}" "${LOGICAL_IMAGES[@]}" "${EXTRA_FILES[@]}")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log()  { echo "[flash] $*"; }
warn() { echo "[flash] WARNING: $*" >&2; }
die()  { echo "[flash] FATAL: $*" >&2; exit 1; }
step() { echo ""; echo "=== $* ==="; }

# -----------------------------------------------------------------------------
# Step 0 — Sanity checks
# -----------------------------------------------------------------------------
step "0/8  Sanity checks"

command -v "$FASTBOOT" >/dev/null 2>&1 || die "fastboot not found in PATH"
command -v scp >/dev/null 2>&1 || die "scp not found in PATH"
command -v ssh >/dev/null 2>&1 || die "ssh not found in PATH"

log "fastboot: $($FASTBOOT --version 2>&1 | head -1)"
log "remote:   $REMOTE_HOST"
log "build dir: $REMOTE_BUILD_DIR"
log "local work: $LOCAL_WORK_DIR"

# Check device is in fastboot
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
if [[ -z "$DEVICES" ]]; then
    die "No device in fastboot mode. Boot the Pixel 9 into fastboot (vol-down + power) and retry."
fi
log "device: $DEVICES"

# Get current slot
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# Get the OTHER slot (we flash to current slot for simplicity)
TARGET_SLOT="$CURRENT_SLOT"

# -----------------------------------------------------------------------------
# Step 0b — Offer to purge stale cached images
# -----------------------------------------------------------------------------
echo ""
echo "[flash] Local work dir: $LOCAL_WORK_DIR"
STALE_COUNT=$(find "$LOCAL_WORK_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.bin' \) 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STALE_COUNT" -gt 0 ]]; then
    log "Found $STALE_COUNT cached .img/.bin file(s) in $LOCAL_WORK_DIR"
    read -r -p "[flash] Delete all local .img and .bin files before downloading fresh copies? [Y/n] " ans
    case "${ans:-Y}" in
        [Yy]*|"")
            log "Purging stale .img and .bin files..."
            find "$LOCAL_WORK_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.bin' \) -delete
            log "Purged ✓"
            ;;
        *)
            warn "Keeping cached files (force-re-download still applies to logical/boot/vbmeta images)"
            ;;
    esac
else
    log "No cached .img/.bin files found — will download fresh."
fi

# -----------------------------------------------------------------------------
# Step 1 — Download images from build server
# -----------------------------------------------------------------------------
step "1/8  Download images from build server"

for f in "${ALL_DOWNLOADS[@]}"; do
    # Force re-download vbmeta_system and vbmeta_vendor (they may be stale
    # 256-byte empty copies from a previous attempt; we now use the full
    # 8192-byte root vbmeta for all three partitions).
    if [[ "$f" == "vbmeta_system.img" || "$f" == "vbmeta_vendor.img" ]]; then
        log "  force re-downloading $f (vbmeta fix)..."
        rm -f "$LOCAL_WORK_DIR/$f"
    fi
    # Force re-download logical partition images (system/product/system_ext/vendor/
    # vendor_dlkm/system_dlkm). These are rebuilt on every code change and the local
    # cache from a prior flash will be STALE, causing the old (broken) system image to
    # be flashed. Bootloader/radio/boot images are large and rarely change, so keep
    # caching for those.
    case "$f" in
        system.img|system_ext.img|product.img|vendor.img|vendor_dlkm.img|system_dlkm.img|vbmeta.img|boot.img|init_boot.img|vendor_boot.img)
            log "  force re-downloading $f (logical/boot/vbmeta image — always fresh)..."
            rm -f "$LOCAL_WORK_DIR/$f"
            ;;
    esac
    if [[ -f "$LOCAL_WORK_DIR/$f" ]]; then
        log "  $f already present, skipping download"
        continue
    fi
    log "  downloading $f..."
    if [[ "$f" == "avb_pkmd.bin" ]]; then
        scp -q "$REMOTE_HOST:$REMOTE_KEY_DIR/$f" "$LOCAL_WORK_DIR/$f" \
            || die "failed to download $f from $REMOTE_KEY_DIR"
    else
        scp -q "$REMOTE_HOST:$REMOTE_BUILD_DIR/$f" "$LOCAL_WORK_DIR/$f" \
            || die "failed to download $f"
    fi
done
log "All images downloaded ✓"

# Verify all files exist
for f in "${ALL_DOWNLOADS[@]}"; do
    [[ -f "$LOCAL_WORK_DIR/$f" ]] || die "$f missing after download!"
done

# -----------------------------------------------------------------------------
# Step 2 — Flash bootloader + radio (no slot)
# -----------------------------------------------------------------------------
step "2/8  Flash bootloader + radio"

log "Flashing bootloader..."
"$FASTBOOT" flash bootloader "$LOCAL_WORK_DIR/bootloader.img" \
    || die "failed to flash bootloader"

log "Rebooting to fastboot (bootloader flash requires reboot)..."
"$FASTBOOT" reboot-bootloader 2>/dev/null || true

# Wait for device to come back into fastboot (can take up to 30s on Pixel 9)
log "Waiting for device to re-enter fastboot..."
for i in $(seq 1 30); do
    sleep 2
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" ]]; then
        log "device back in fastboot after ${i} attempts ($(( i * 2 ))s)"
        break
    fi
    [[ $((i % 5)) -eq 0 ]] && log "  still waiting... (${i}/30)"
done
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
[[ -n "$DEVICES" ]] || die "device lost after bootloader flash (waited 60s)"

log "Flashing radio..."
"$FASTBOOT" flash radio "$LOCAL_WORK_DIR/radio.img" \
    || die "failed to flash radio"

# Re-query slot (may have changed after bootloader flash)
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
TARGET_SLOT="$CURRENT_SLOT"
log "current-slot after bootloader: ${CURRENT_SLOT:-unknown}"

# -----------------------------------------------------------------------------
# Step 3 — Wipe userdata + metadata
# -----------------------------------------------------------------------------
step "3/8  Wipe userdata + metadata"

# CRITICAL: userdata wipe is REQUIRED for first-boot defaults (launcher
# workspace, setup wizard) to apply. Without it, the old launcher database
# persists and the new home-layout overlay never takes effect.
log "Wiping userdata..."
"$FASTBOOT" erase userdata \
    || die "userdata erase failed. The launcher home-layout overlay will NOT apply without a clean wipe. Manual fix: fastboot -w"
log "Wiping metadata..."
"$FASTBOOT" erase metadata \
    || warn "metadata erase failed (may not be present on all devices — non-fatal)"

# -----------------------------------------------------------------------------
# Step 4 — AVB key handling + flash vbmeta_system/vendor
# -----------------------------------------------------------------------------
step "4/8  AVB key handling + flash vbmeta_system/vendor"

# AVB key: build uses test keys (testkey_rsa4096.pem).
# Pixel 9 has secure-boot: PRODUCTION and no avb_custom_key partition.
# Even if avb_custom_key flashes successfully, the root vbmeta.img has Flags: 0
# (verification ENABLED) with inline hash trees for ALL partitions. If the root
# vbmeta is flashed WITHOUT --disable-verification, the bootloader will attempt
# dm-verity hash tree verification on the modified partitions and fail with
# "dm-verity device corrupted" (reboot mode 0x50).
#
# FIX: ALWAYS use --disable-verification for ALL vbmeta partitions, regardless
# of avb_custom_key status. This sets AVB_VBMETA_IMAGE_FLAGS_HASHTREE_DISABLED
# (flags=2) so the bootloader skips dm-verity verification entirely.
AVB_DISABLE_VERIFICATION=1

log "Trying avb_custom_key flash (informational only — does NOT affect --disable-verification)..."
"$FASTBOOT" erase avb_custom_key 2>/dev/null || true
if "$FASTBOOT" flash avb_custom_key "$LOCAL_WORK_DIR/avb_pkmd.bin" 2>/dev/null; then
    log "avb_custom_key flashed ✓ (still using --disable-verification on all vbmeta)"
else
    warn "avb_custom_key flash failed (partition not present) — using --disable-verification on all vbmeta"
fi

log "Flashing vbmeta_system + vbmeta_vendor with --disable-verification..."
# The build produces a single root vbmeta (all hashes inline, no chaining).
# The device has separate vbmeta_system and vbmeta_vendor partitions (64KB).
# Previously, the script ERASED these partitions, which left stale hash trees
# from the previous OS and triggered dm-verity corruption (reboot mode 0x50).
#
# FIX: Flash the root vbmeta.img (8192 bytes, contains all hashtree descriptors)
# to ALL three vbmeta partitions with --disable-verification. fastboot sets
# AVB_VBMETA_IMAGE_FLAGS_HASHTREE_DISABLED (flags=2) on flash, which tells the
# bootloader to skip dm-verity verification entirely.
"$FASTBOOT" --disable-verification flash vbmeta_system "$LOCAL_WORK_DIR/vbmeta_system.img" \
    || die "failed to flash vbmeta_system with --disable-verification"
"$FASTBOOT" --disable-verification flash vbmeta_vendor "$LOCAL_WORK_DIR/vbmeta_vendor.img" \
    || die "failed to flash vbmeta_vendor with --disable-verification"

# -----------------------------------------------------------------------------
# Step 5 — Flash physical A/B partitions (with --slot)
# -----------------------------------------------------------------------------
step "5/8  Flash physical A/B partitions (slot $TARGET_SLOT)"

for img in "${AB_IMAGES[@]}"; do
    part="${img%.img}"
    log "  flash $part (slot $TARGET_SLOT)"
    "$FASTBOOT" --slot "$TARGET_SLOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
        || die "failed to flash $part"
done
log "A/B partitions flashed ✓"

# -----------------------------------------------------------------------------
# Step 6 — Flash physical non-A/B partitions (dtbo + root vbmeta only)
# -----------------------------------------------------------------------------
step "6/8  Flash non-A/B partitions (dtbo + root vbmeta)"

# NOTE: vbmeta_system and vbmeta_vendor were ALREADY flashed in Step 4 with
# --disable-verification. They are non-sloted shared partitions on Pixel 9,
# so flashing them again here with --slot would either be a no-op (harmless)
# or could re-flash with a stale image if the download cache is wrong.
# To avoid double-flashing, we ONLY flash the root vbmeta (vbmeta.img) and
# dtbo here. The root vbmeta is the authoritative one (contains all hashtree
# descriptors); vbmeta_system/vbmeta_vendor are flashed from the same root
# vbmeta.img in Step 4.
for img in "${NOAB_IMAGES[@]}"; do
    part="${img%.img}"
    # SKIP vbmeta_system and vbmeta_vendor — already flashed in Step 4
    [[ "$part" == "vbmeta_system" || "$part" == "vbmeta_vendor" ]] && continue
    if [[ "$part" == "vbmeta" && -n "${AVB_DISABLE_VERIFICATION:-}" ]]; then
        log "  flash $part (--disable-verification — test-key build on production-secure device)"
        "$FASTBOOT" --disable-verification --slot "$CURRENT_SLOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part with --disable-verification"
    elif [[ "$part" == "dtbo" ]]; then
        log "  flash $part (no slot)"
        "$FASTBOOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part"
    fi
done
log "Non-A/B partitions flashed ✓"

# -----------------------------------------------------------------------------
# Step 7 — Flash logical partitions (super) via fastbootd
# -----------------------------------------------------------------------------
step "7/8  Flash logical partitions (super) via fastbootd"

log "Rebooting to fastbootd..."
"$FASTBOOT" reboot fastboot 2>/dev/null || true

# Wait for fastbootd to come up.
# CRITICAL: fastbootd (userspace) is required for logical-partition operations
# (wipe-super, flash system/product/vendor/etc.). In bootloader fastboot these
# commands silently fail or error. fastbootd devices report with the
# "fastbootd" keyword in getvar, so we verify we're actually in fastbootd
# before proceeding — not just that a device is visible.
log "Waiting for fastbootd..."
FASTBOOTD_READY=0
for i in $(seq 1 30); do
    sleep 2
    # Check device is visible AND in fastbootd mode (not bootloader)
    FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" && "$FB_MODE" == "yes" ]]; then
        log "fastbootd ready after ${i} attempts (is-userspace=yes)"
        FASTBOOTD_READY=1
        break
    fi
    [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastbootd... (${i}/30) [is-userspace=${FB_MODE:-unknown}]"
done
if [[ "$FASTBOOTD_READY" -ne 1 ]]; then
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    [[ -n "$DEVICES" ]] || die "device lost when entering fastbootd (waited 60s)"
    # Device is visible but NOT in fastbootd — this means reboot fastboot failed.
    # Try once more.
    warn "Device visible but not in fastbootd (is-userspace=${FB_MODE:-unknown}). Retrying reboot fastboot..."
    "$FASTBOOT" reboot fastboot 2>/dev/null || true
    sleep 5
    for i in $(seq 1 15); do
        sleep 2
        FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
        if [[ "$FB_MODE" == "yes" ]]; then
            log "fastbootd ready on retry"
            FASTBOOTD_READY=1
            break
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  retry: still waiting... (${i}/15)"
    done
    [[ "$FASTBOOTD_READY" -eq 1 ]] || die "FAILED to enter fastbootd after 2 attempts. Logical partitions (system/product/vendor) CANNOT be flashed in bootloader mode. Manual fix: 'fastboot reboot fastboot' then re-run this script from Step 7."
fi

# Wipe super and flash super_empty to reset logical partitions.
# CRITICAL: this MUST succeed — without it, the old logical partitions persist
# and the new images cannot be flashed correctly. Changed from warn to die.
log "Wiping super partition..."
"$FASTBOOT" wipe-super "$LOCAL_WORK_DIR/super_empty.img" \
    || die "wipe-super failed. The old logical partitions were NOT reset. Manual fix: ensure device is in fastbootd ('fastboot getvar is-userspace' should say 'yes'), then run: fastboot wipe-super super_empty.img"

# Flash logical partitions
for img in "${LOGICAL_IMAGES[@]}"; do
    part="${img%.img}"
    log "  flash $part (logical)"
    "$FASTBOOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
        || die "failed to flash $part"
done
log "Logical partitions flashed ✓"

# Reboot back to fastboot (bootloader)
log "Rebooting back to fastboot (bootloader)..."
"$FASTBOOT" reboot-bootloader 2>/dev/null || true

# Wait for device to come back to fastboot
log "Waiting for device to return to fastboot..."
for i in $(seq 1 30); do
    sleep 2
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" ]]; then
        log "device back in fastboot after ${i} attempts"
        break
    fi
    [[ $((i % 5)) -eq 0 ]] && log "  still waiting... (${i}/30)"
done
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
[[ -n "$DEVICES" ]] || die "device lost when returning to fastboot (waited 60s)"

# Re-query slot
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# -----------------------------------------------------------------------------
# Step 8 — Set active slot + reboot
# -----------------------------------------------------------------------------
step "8/8  Set active slot + reboot"

# Set the current slot as active and reset retry count.
# This ensures the bootloader boots the freshly-flashed slot with full retry
# count, avoiding "slot-retry-count exhausted" loops.
if [[ -n "$CURRENT_SLOT" ]]; then
    log "Setting active slot to $CURRENT_SLOT..."
    "$FASTBOOT" --set-active="$CURRENT_SLOT" 2>/dev/null || warn "set-active failed (manual: fastboot --set-active=$CURRENT_SLOT)"
fi

log "Rebooting device..."
"$FASTBOOT" reboot || warn "reboot returned non-zero (device may still be rebooting)"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  GuardTalkOS flash complete!"
echo "  The device will boot. First boot may take a few minutes."
echo "  Work dir: $LOCAL_WORK_DIR"
echo "============================================================"
