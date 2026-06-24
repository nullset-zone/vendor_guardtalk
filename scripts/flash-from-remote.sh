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
NOAB_IMAGES=(dtbo.img vbmeta.img)
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
# Step 1 — Download images from build server
# -----------------------------------------------------------------------------
step "1/8  Download images from build server"

for f in "${ALL_DOWNLOADS[@]}"; do
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

log "Wiping userdata..."
"$FASTBOOT" erase userdata 2>&1 || warn "userdata erase failed (may be DCK-locked — non-fatal)"
log "Wiping metadata..."
"$FASTBOOT" erase metadata 2>/dev/null || warn "metadata erase failed (non-fatal)"

# -----------------------------------------------------------------------------
# Step 4 — AVB key handling + erase stale vbmeta_system/vendor
# -----------------------------------------------------------------------------
step "4/8  AVB key handling + erase stale vbmeta partitions"

# AVB key: build uses test keys (testkey_rsa4096.pem).
# Pixel 9 has secure-boot: PRODUCTION and no avb_custom_key partition.
# Solution: flash vbmeta with --disable-verification (done in step 6).
# Also erase stale vbmeta_system + vbmeta_vendor — our build uses single root
# vbmeta (all hashes inline, no chaining), so these stale partitions cause
# verification conflicts.
AVB_DISABLE_VERIFICATION=1

log "Trying avb_custom_key flash (may fail on Pixel 9 — no partition)..."
"$FASTBOOT" erase avb_custom_key 2>/dev/null || true
if "$FASTBOOT" flash avb_custom_key "$LOCAL_WORK_DIR/avb_pkmd.bin" 2>/dev/null; then
    log "avb_custom_key flashed ✓"
    AVB_DISABLE_VERIFICATION=
else
    warn "avb_custom_key flash failed (partition not present) — will use --disable-verification on vbmeta"
    AVB_DISABLE_VERIFICATION=1
fi

log "Erasing stale vbmeta_system + vbmeta_vendor..."
"$FASTBOOT" --slot "$CURRENT_SLOT" erase vbmeta_system 2>/dev/null || warn "vbmeta_system erase failed (may not exist)"
"$FASTBOOT" --slot "$CURRENT_SLOT" erase vbmeta_vendor 2>/dev/null || warn "vbmeta_vendor erase failed (may not exist)"

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
# Step 6 — Flash physical non-A/B partitions (vbmeta with --disable-verification)
# -----------------------------------------------------------------------------
step "6/8  Flash non-A/B partitions (dtbo + vbmeta)"

for img in "${NOAB_IMAGES[@]}"; do
    part="${img%.img}"
    if [[ "$part" == "vbmeta" && -n "${AVB_DISABLE_VERIFICATION:-}" ]]; then
        log "  flash $part (--disable-verification — test-key build on production-secure device)"
        "$FASTBOOT" --disable-verification --slot "$CURRENT_SLOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part with --disable-verification"
    else
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

# Wait for fastbootd to come up
log "Waiting for fastbootd..."
for i in $(seq 1 30); do
    sleep 2
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" ]]; then
        log "fastbootd ready after ${i} attempts"
        break
    fi
    [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastbootd... (${i}/30)"
done
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
[[ -n "$DEVICES" ]] || die "device lost when entering fastbootd (waited 60s)"

# Wipe super and flash super_empty to reset logical partitions
log "Wiping super partition..."
"$FASTBOOT" wipe-super "$LOCAL_WORK_DIR/super_empty.img" 2>/dev/null \
    || warn "wipe-super failed (may need manual: fastboot wipe-super super_empty.img)"

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
