#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS tokay (Pixel 9) — remote SIGNED flash + lock + verify script
#
# Variant of flash-from-remote.sh for SIGNED releases (produced by sign-build.sh).
# Pulls signed factory images + the GuardTalk AVB public key from the build
# server, injects avb_custom_key BEFORE flashing, flashes the signed images via
# `fastboot update`, locks the bootloader to the GuardTalk AVB key, and verifies
# the verified-boot state (yellow = PASS).
#
# Law 4 (Security First): never writes private key material to disk; only the
#   PUBLIC avb_pkmd.bin blob is downloaded, used, and (optionally) purged.
# Law 3 (Error Handling): set -euo pipefail; every fastboot/adb/scp call checked.
# Law 11 (Reversibility): --no-lock mode + unlock path documented in RUNBOOK §8.
# Law 10 (Audit Trail): verification table printed at end.
# Law 6 (Minimal Footprint): only downloads what is needed; purges local cache
#   only on operator opt-in.
#
# Key differences from flash-from-remote.sh (unsigned):
#   1. Downloads from $REMOTE_RELEASE_DIR (releases/<BUILD>/signed/) — NOT the
#      build output dir.
#   2. Injects avb_custom_key BEFORE flashing (erase -> flash avb_pkmd.bin).
#   3. NO --disable-verification anywhere — signed images have AVB verification
#      ENABLED (vbmeta flags=0); the bootloader verifies the chain against the
#      injected custom key.
#   4. Uses `fastboot update <factory-zip>` for the bulk flash (standard AOSP
#      approach for signed factory images; handles bootloader/radio/super/slots
#      in one command).
#   5. Adds `fastboot flashing lock` step with PERMANENT BRICK WARNING.
#   6. Adds post-boot verification (yellow/green/orange/red case statement).
#   7. Adds optional fastboot-FS-protection spot-check.
#
# Usage:
#   ./flash-from-remote-signed.sh \
#       --release-dir releases/<BUILD>/signed   # remote path to signed release
#       --key-dir     /home/openstatestack/guardtalk-keys/guardtalk
#       --host        openstatestack@192.168.1.4
#       [--no-lock]    # skip bootloader lock (bring-up mode)
#       [--no-wipe]    # skip userdata wipe (not recommended for first signed flash)
#       [--yes]        # skip interactive confirms (DANGEROUS — locks without prompt)
#
#   Or via env vars (like the original):
#   REMOTE_HOST=openstatestack@192.168.1.4 \
#   REMOTE_RELEASE_DIR=/mnt/.../releases/<BUILD>/signed \
#   REMOTE_KEY_DIR=/home/openstatestack/guardtalk-keys/guardtalk \
#   ./flash-from-remote-signed.sh
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Defaults — overridable via env vars or CLI flags
# -----------------------------------------------------------------------------
REMOTE_HOST="${REMOTE_HOST:-openstatestack@192.168.1.4}"
REMOTE_RELEASE_DIR="${REMOTE_RELEASE_DIR:-}"
REMOTE_KEY_DIR="${REMOTE_KEY_DIR:-/home/openstatestack/guardtalk-keys/guardtalk}"

LOCAL_WORK_DIR="${LOCAL_WORK_DIR:-.}"

FASTBOOT="${FASTBOOT:-fastboot}"
ADB="${ADB:-adb}"

LOCK=1
WIPE_USERDATA=1            # default ON for first signed flash (matches original)
ASSUME_YES=0

DEVICE="${DEVICE:-tokay}"  # Pixel 9 codename

# -----------------------------------------------------------------------------
# Helpers (duplicated from flash-from-remote.sh for consistency)
# -----------------------------------------------------------------------------
log()  { echo "[flash-signed] $*"; }
warn() { echo "[flash-signed] WARNING: $*" >&2; }
die()  { echo "[flash-signed] FATAL: $*" >&2; exit 1; }
step() { echo ""; echo "=== $* ==="; }

# Wait for the device to re-appear in fastboot after a reboot-bootloader.
# The device may show up in `fastboot devices` before the USB endpoint is
# fully stable; a getvar probe + short settle delay prevents USB pipe errors
# on large transfers (e.g. the 133MB radio image).
wait_for_fastboot() {
    local max_tries=30
    local i
    for ((i = 1; i <= max_tries; i++)); do
        if "$FASTBOOT" devices 2>/dev/null | grep -q '\<fastboot\>'; then
            log "device back in fastboot (try $i) — probing for stability..."
            # Give the USB endpoint a moment to settle, then confirm the
            # device responds to a real command before proceeding.
            # NOTE: fastboot getvar writes its output to STDERR, so we
            # redirect stderr to stdout for the grep (2>&1).
            sleep 2
            if "$FASTBOOT" getvar product 2>&1 | grep -q 'product:'; then
                log "device stable in fastboot ✓"
                return 0
            fi
            log "device listed but not responsive; retrying..."
        fi
        sleep 2
    done
    die "device did not return to fastboot after reboot (waited $(( max_tries * 2 ))s)"
}

confirm() {
    # confirm "<prompt>" — returns 0 if user typed 'yes' (or --yes passed).
    local prompt="$1"
    if [[ $ASSUME_YES -eq 1 ]]; then
        echo "$prompt [auto-yes]"
        return 0
    fi
    local reply
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy](es)?$ ]]
}

usage() {
    cat <<'EOF'
Usage: flash-from-remote-signed.sh [OPTIONS]

Pulls a signed GuardTalkOS release from a remote build server, injects the AVB
custom key, flashes signed images via `fastboot update`, locks the bootloader
to the GuardTalk AVB key, and verifies the verified-boot state.

REQUIRED (via flag or env var):
  --release-dir DIR    Remote path to the signed release dir
                       (env: REMOTE_RELEASE_DIR)
  --key-dir DIR        Remote path to the GuardTalk key dir containing
                       avb_pkmd.bin  (env: REMOTE_KEY_DIR)
  --host USER@HOST     Remote build host  (env: REMOTE_HOST)

OPTIONAL:
  --device CODENAME    Device codename (default: tokay; env: DEVICE)
  --no-lock            Flash but skip the bootloader lock (first bring-up)
  --no-wipe            Do NOT pass -w to fastboot update (skip userdata wipe)
  --yes                Skip interactive confirmations (CI / unattended).
                       DANGEROUS: will lock bootloader without prompting.
  --local-dir DIR      Local working directory (default: .; env: LOCAL_WORK_DIR)
  --help, -h           Show this help and exit

EXIT CODES:
  0  success
  1  generic failure
  2  usage error
EOF
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --release-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --release-dir requires a value" >&2; exit 2; }
            REMOTE_RELEASE_DIR="$2"; shift 2 ;;
        --key-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --key-dir requires a value" >&2; exit 2; }
            REMOTE_KEY_DIR="$2"; shift 2 ;;
        --host)
            [[ $# -ge 2 ]] || { echo "ERROR: --host requires a value" >&2; exit 2; }
            REMOTE_HOST="$2"; shift 2 ;;
        --device)
            [[ $# -ge 2 ]] || { echo "ERROR: --device requires a value" >&2; exit 2; }
            DEVICE="$2"; shift 2 ;;
        --local-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --local-dir requires a value" >&2; exit 2; }
            LOCAL_WORK_DIR="$2"; shift 2 ;;
        --no-lock)       LOCK=0; shift ;;
        --no-wipe)       WIPE_USERDATA=0; shift ;;
        --yes)           ASSUME_YES=1; shift ;;
        --help|-h)       usage; exit 0 ;;
        *)
            echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

[[ -n "$REMOTE_RELEASE_DIR" ]] || { echo "ERROR: --release-dir (or REMOTE_RELEASE_DIR) is required" >&2; usage; exit 2; }
[[ -n "$REMOTE_KEY_DIR"     ]] || { echo "ERROR: --key-dir (or REMOTE_KEY_DIR) is required" >&2;     usage; exit 2; }
[[ -n "$REMOTE_HOST"        ]] || { echo "ERROR: --host (or REMOTE_HOST) is required" >&2;           usage; exit 2; }

# Resolve local work dir to an absolute path so scp/cd behave consistently.
mkdir -p "$LOCAL_WORK_DIR"
LOCAL_WORK_DIR="$(cd "$LOCAL_WORK_DIR" && pwd)"

# -----------------------------------------------------------------------------
# Step 0 — Sanity checks
# -----------------------------------------------------------------------------
step "0/8  Sanity checks"

command -v "$FASTBOOT" >/dev/null 2>&1 || die "fastboot not found in PATH"
command -v "$ADB"      >/dev/null 2>&1 || die "adb not found in PATH"
command -v scp >/dev/null 2>&1 || die "scp not found in PATH"
command -v ssh >/dev/null 2>&1 || die "ssh not found in PATH"

log "fastboot:      $($FASTBOOT --version 2>&1 | head -1)"
log "remote host:   $REMOTE_HOST"
log "release dir:   $REMOTE_RELEASE_DIR"
log "key dir:       $REMOTE_KEY_DIR"
log "local work:    $LOCAL_WORK_DIR"
log "device:        $DEVICE"
log "lock:          $([ $LOCK -eq 1 ] && echo "YES (with brick warning)" || echo "NO (--no-lock bring-up mode)")"
log "wipe userdata: $([ $WIPE_USERDATA -eq 1 ] && echo "YES (-w)" || echo "NO (--no-wipe)")"

# Check device is in fastboot
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
if [[ -z "$DEVICES" ]]; then
    die "No device in fastboot mode. Boot the Pixel 9 into fastboot (vol-down + power) and retry."
fi
log "device: $DEVICES"

# Confirm the device product matches the target codename.
PRODUCT_NAME="$("$FASTBOOT" getvar product 2>&1 | sed -n 's/^product: *//p' | head -1 || true)"
if [[ "$PRODUCT_NAME" != "$DEVICE" && "$PRODUCT_NAME" != "${DEVICE}_cur" ]]; then
    die "device product '$PRODUCT_NAME' does not match --device '$DEVICE' (or '${DEVICE}_cur')"
fi
log "product: $PRODUCT_NAME  ✓"

# Get current slot (informational — `fastboot update` manages slots itself)
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# -----------------------------------------------------------------------------
# Step 0b — Offer to purge stale cached images (preserve from original)
# -----------------------------------------------------------------------------
echo ""
echo "[flash-signed] Local work dir: $LOCAL_WORK_DIR"
STALE_COUNT=$(find "$LOCAL_WORK_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.bin' -o -name '*.zip' \) 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STALE_COUNT" -gt 0 ]]; then
    log "Found $STALE_COUNT cached .img/.bin/.zip file(s) in $LOCAL_WORK_DIR"
    read -r -p "[flash-signed] Delete all local .img, .bin, and .zip files before downloading fresh copies? [Y/n] " ans
    case "${ans:-Y}" in
        [Yy]*|"")
            log "Purging stale .img, .bin, and .zip files..."
            find "$LOCAL_WORK_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.bin' -o -name '*.zip' \) -delete
            log "Purged ✓"
            ;;
        *)
            warn "Keeping cached files (signed release zips may be reused if names match — verify MANIFEST.txt!)"
            ;;
    esac
else
    log "No cached .img/.bin/.zip files found — will download fresh."
fi

# -----------------------------------------------------------------------------
# Step 1 — Download signed release artifacts + AVB public key from build server
# -----------------------------------------------------------------------------
step "1/8  Download signed release artifacts"

# The signed release dir (produced by sign-build.sh) contains:
#   - <device>-factory-<BUILD>.zip   (factory bundle: bootloader + radio + flash-all)
#   - <device>-img-<BUILD>.zip       (partition images)
#   - MANIFEST.txt                   (SHA-256s)
#   - avb_pkmd.bin                   (AVB public key blob)  [may also be in key dir]
#
# We download:
#   - The factory zip (preferred; used by `fastboot update`)
#   - The img zip (fallback; used by `fastboot flashall`)
#   - MANIFEST.txt (for SHA-256 cross-check / audit)
#   - avb_pkmd.bin from the KEY DIR (canonical location; the release-dir copy
#     is a convenience duplicate).

# Discover the exact factory/img zip filenames on the remote host.
log "Querying remote release dir for signed artifacts..."
REMOTE_FACTORY_ZIP="$(ssh -o BatchMode=yes "$REMOTE_HOST" \
    "ls -1 '$REMOTE_RELEASE_DIR'/'$DEVICE'-factory-*.zip 2>/dev/null | head -1" 2>/dev/null || true)"
REMOTE_IMG_ZIP="$(ssh -o BatchMode=yes "$REMOTE_HOST" \
    "ls -1 '$REMOTE_RELEASE_DIR'/'$DEVICE'-img-*.zip 2>/dev/null | head -1" 2>/dev/null || true)"

[[ -n "$REMOTE_FACTORY_ZIP" || -n "$REMOTE_IMG_ZIP" ]] \
    || die "no $DEVICE-factory-*.zip or $DEVICE-img-*.zip found in $REMOTE_HOST:$REMOTE_RELEASE_DIR"

FACTORY_ZIP_LOCAL=""
IMG_ZIP_LOCAL=""
if [[ -n "$REMOTE_FACTORY_ZIP" ]]; then
    FACTORY_ZIP_LOCAL="$LOCAL_WORK_DIR/$(basename "$REMOTE_FACTORY_ZIP")"
    log "  downloading $(basename "$REMOTE_FACTORY_ZIP")..."
    scp -q "$REMOTE_HOST:$REMOTE_FACTORY_ZIP" "$FACTORY_ZIP_LOCAL" \
        || die "failed to download factory zip"
fi
if [[ -n "$REMOTE_IMG_ZIP" ]]; then
    IMG_ZIP_LOCAL="$LOCAL_WORK_DIR/$(basename "$REMOTE_IMG_ZIP")"
    log "  downloading $(basename "$REMOTE_IMG_ZIP")..."
    scp -q "$REMOTE_HOST:$REMOTE_IMG_ZIP" "$IMG_ZIP_LOCAL" \
        || die "failed to download img zip"
fi

# MANIFEST.txt (best-effort; not fatal if absent)
log "  downloading MANIFEST.txt (best-effort)..."
scp -q "$REMOTE_HOST:$REMOTE_RELEASE_DIR/MANIFEST.txt" "$LOCAL_WORK_DIR/MANIFEST.txt" 2>/dev/null \
    || warn "MANIFEST.txt not found in release dir (non-fatal; audit trail incomplete)"

# avb_pkmd.bin from the KEY DIR (canonical). Fall back to release dir.
AVB_PKMD_LOCAL="$LOCAL_WORK_DIR/avb_pkmd.bin"
if [[ -f "$AVB_PKMD_LOCAL" ]]; then
    log "  avb_pkmd.bin already present locally, reusing (use Step 0b purge to force re-download)"
else
    log "  downloading avb_pkmd.bin from key dir..."
    if ! scp -q "$REMOTE_HOST:$REMOTE_KEY_DIR/avb_pkmd.bin" "$AVB_PKMD_LOCAL" 2>/dev/null; then
        warn "avb_pkmd.bin not found in key dir ($REMOTE_KEY_DIR); trying release dir..."
        scp -q "$REMOTE_HOST:$REMOTE_RELEASE_DIR/avb_pkmd.bin" "$AVB_PKMD_LOCAL" \
            || die "failed to download avb_pkmd.bin from key dir OR release dir"
    fi
fi
[[ -f "$AVB_PKMD_LOCAL" ]] || die "avb_pkmd.bin missing after download!"
AVB_SIZE=""
if stat -c%s "$AVB_PKMD_LOCAL" >/dev/null 2>&1; then
    AVB_SIZE="$(stat -c%s "$AVB_PKMD_LOCAL")"
else
    AVB_SIZE="$(stat -f%z "$AVB_PKMD_LOCAL")"
fi
log "  avb_pkmd.bin: $AVB_SIZE bytes ✓"

# Verify presence
[[ -n "$FACTORY_ZIP_LOCAL" || -n "$IMG_ZIP_LOCAL" ]] || die "no factory/img zip present after download"
[[ -f "$AVB_PKMD_LOCAL" ]] || die "avb_pkmd.bin missing after download"
log "All signed artifacts downloaded ✓"

# -----------------------------------------------------------------------------
# Step 2 — AVB custom key injection (BEFORE flash, MANDATORY)
# -----------------------------------------------------------------------------
step "2/8  AVB custom key injection (BEFORE flash)"

# Per dispatch packet §2: the signed vbmeta is signed with the GuardTalk AVB
# key. The bootloader needs the custom key injected to verify the chain.
# Sequence:
#   1. Check flashing get_unlock_ability (must be 1 to unlock/flash custom key)
#   2. If currently locked: fastboot flashing unlock (WIPES userdata) — required
#      to inject avb_custom_key on a locked device.
#   3. fastboot erase avb_custom_key (clear any prior key)
#   4. fastboot flash avb_custom_key avb_pkmd.bin (inject GuardTalk public key)
#
# NOTE: This step happens BEFORE the image flash so that, when the signed
# vbmeta is flashed, the bootloader can immediately verify it against the
# injected key.

log "Checking flashing get_unlock_ability..."
UNLOCK_ABILITY="$("$FASTBOOT" flashing get_unlock_ability 2>&1 | sed -n 's/^.*get_unlock_ability: *//p' | head -1 || true)"
log "  get_unlock_ability = ${UNLOCK_ABILITY:-unknown}"
if [[ "$UNLOCK_ABILITY" == "0" ]]; then
    echo "[flash-signed] flashing get_unlock_ability = 0." >&2
    echo "[flash-signed]   → On the device: Settings → Developer Options → enable OEM Unlocking." >&2
    echo "[flash-signed]     (Cannot be scripted on a user build.)" >&2
    die "OEM Unlocking is not enabled; cannot proceed with AVB key injection."
fi

log "Checking current lock state..."
UNLOCKED="$("$FASTBOOT" getvar unlocked 2>&1 | sed -n 's/^unlocked: *//p' | head -1 || true)"
log "  unlocked = ${UNLOCKED:-unknown}"
if [[ "$UNLOCKED" == "no" ]]; then
    echo "[flash-signed] Device is currently LOCKED."
    echo "[flash-signed] Unlocking is required to inject avb_custom_key."
    echo "[flash-signed] ⚠️  fastboot flashing unlock WILL WIPE USERDATA."
    if ! confirm "[flash-signed] Proceed with unlock?"; then
        die "unlock declined — cannot inject AVB custom key on a locked device"
    fi
    "$FASTBOOT" flashing unlock \
        || die "fastboot flashing unlock failed"
    log "Device unlocked ✓"
else
    log "Device already unlocked — no unlock needed."
fi

log "Erasing any prior avb_custom_key..."
"$FASTBOOT" erase avb_custom_key 2>/dev/null \
    || warn "erase avb_custom_key returned non-zero (may already be empty — non-fatal)"

log "Flashing avb_custom_key: $AVB_PKMD_LOCAL"
"$FASTBOOT" flash avb_custom_key "$AVB_PKMD_LOCAL" \
    || die "failed to flash avb_custom_key — cannot proceed without it (signed vbmeta would be unverifiable)"
log "avb_custom_key injected ✓ (BEFORE image flash, as required)"

# -----------------------------------------------------------------------------
# Step 3 — Wipe userdata + metadata (unless --no-wipe)
# -----------------------------------------------------------------------------
step "3/8  Wipe userdata + metadata"

if [[ $WIPE_USERDATA -eq 1 ]]; then
    # NOTE: `fastboot update -w` would also wipe, but we erase explicitly here
    # for parity with the original script's behavior and so the wipe happens
    # BEFORE the flash (avoids any chance of the new image's first-boot logic
    # racing with a post-flash wipe).
    log "Wiping userdata..."
    "$FASTBOOT" erase userdata \
        || die "userdata erase failed. Manual fix: fastboot -w"
    log "Wiping metadata..."
    "$FASTBOOT" erase metadata \
        || warn "metadata erase failed (may not be present on all devices — non-fatal)"
else
    log "--no-wipe: skipping userdata/metadata erase (NOT recommended for first signed flash)"
fi

# -----------------------------------------------------------------------------
# Step 4 — Flash signed images via `fastboot update` (preferred)
# -----------------------------------------------------------------------------
step "4/8  Flash signed images"

# Standard AOSP/GrapheneOS approach for signed factory images: extract the
# factory zip and flash bootloader + radio + the inner image zip.
#
# The factory zip has a nested structure:
#   <device>-factory-<build>/
#     bootloader-<device>-*.img
#     radio-<device>-*.img
#     image-<device>-<build>.zip   ← contains android-info.txt at root
#     flash-all.sh
#
# `fastboot update <factory-zip>` does NOT work because it expects
# android-info.txt at the zip root, but it's inside the nested image zip.
# Instead, we extract the factory zip and run `fastboot update` on the
# inner image zip (after flashing bootloader + radio first, like flash-all.sh).
#
# It does NOT use --disable-verification — the signed vbmeta has flags=0
# (verification ENABLED), and the bootloader verifies the chain against the
# avb_custom_key we just injected.

FLASH_ARGS=()
if [[ $WIPE_USERDATA -eq 1 ]]; then
    FLASH_ARGS+=(-w)
fi

flash_factory_zip() {
    local factory_zip="$1"
    local extract_dir
    extract_dir="$(mktemp -d "$LOCAL_WORK_DIR/factory-extract.XXXXXX")"

    log "Extracting factory zip: $(basename "$factory_zip")"
    unzip -q "$factory_zip" -d "$extract_dir" \
        || die "failed to extract factory zip"

    # Find the inner directory (e.g. tokay-factory-20260703/)
    local inner_dir
    inner_dir="$(find "$extract_dir" -maxdepth 1 -type d ! -path "$extract_dir" | head -1)"
    [[ -n "$inner_dir" ]] || die "could not find inner dir in extracted factory zip"

    # 1. Flash bootloader (if present)
    local bootloader_img
    bootloader_img="$(find "$inner_dir" -name 'bootloader-*.img' -maxdepth 1 | head -1)"
    if [[ -n "$bootloader_img" ]]; then
        log "Flashing bootloader: $(basename "$bootloader_img")"
        "$FASTBOOT" flash bootloader "$bootloader_img" \
            || die "failed to flash bootloader"
        log "Rebooting to bootloader..."
        "$FASTBOOT" reboot-bootloader 2>/dev/null || true
        wait_for_fastboot
    fi

    # 2. Flash radio (if present)
    local radio_img
    radio_img="$(find "$inner_dir" -name 'radio-*.img' -maxdepth 1 | head -1)"
    if [[ -n "$radio_img" ]]; then
        log "Flashing radio: $(basename "$radio_img")"
        "$FASTBOOT" flash radio "$radio_img" \
            || die "failed to flash radio"
        log "Rebooting to bootloader..."
        "$FASTBOOT" reboot-bootloader 2>/dev/null || true
        wait_for_fastboot
    fi

    # 3. Flash the inner image zip via `fastboot update`
    local inner_img_zip
    inner_img_zip="$(find "$inner_dir" -name 'image-*.zip' -maxdepth 1 | head -1)"
    [[ -n "$inner_img_zip" ]] || die "could not find image-*.zip inside extracted factory zip"

    log "fastboot update ${FLASH_ARGS[*]} $(basename "$inner_img_zip")"
    "$FASTBOOT" "${FLASH_ARGS[@]}" update "$inner_img_zip" \
        || die "fastboot update (inner image zip) failed"

    # Cleanup extract dir
    rm -rf "$extract_dir"
}

flash_img_zip() {
    local img_zip="$1"
    # `fastboot flashall` requires ANDROID_PRODUCT_OUT to point to a directory
    # containing android-info.txt and the partition images. The img zip IS
    # that directory in zip form — extract and use flashall.
    local extract_dir
    extract_dir="$(mktemp -d "$LOCAL_WORK_DIR/img-extract.XXXXXX")"
    log "Extracting img zip for flashall: $(basename "$img_zip")"
    unzip -q "$img_zip" -d "$extract_dir" \
        || die "failed to extract img zip"
    log "fastboot flashall ${FLASH_ARGS[*]} (from $extract_dir)"
    (
        cd "$extract_dir"
        export ANDROID_PRODUCT_OUT="$extract_dir"
        "$FASTBOOT" "${FLASH_ARGS[@]}" flashall \
            || die "fastboot flashall failed"
    )
    rm -rf "$extract_dir"
}

if [[ -n "$FACTORY_ZIP_LOCAL" ]]; then
    if ! flash_factory_zip "$FACTORY_ZIP_LOCAL"; then
        warn "factory zip flash failed; attempting fallback to img zip flashall"
        [[ -n "$IMG_ZIP_LOCAL" ]] || die "factory flash failed and no img zip available for fallback"
        flash_img_zip "$IMG_ZIP_LOCAL" \
            || die "img zip flashall fallback also failed"
    fi
else
    [[ -n "$IMG_ZIP_LOCAL" ]] || die "no factory or img zip available for flash"
    flash_img_zip "$IMG_ZIP_LOCAL" \
        || die "img zip flashall failed"
fi
log "Signed images flashed ✓ (AVB verification ENABLED — no --disable-verification used)"

# fastboot update/flashall may reboot the device. Wait for it to be reachable
# in fastboot again before attempting the lock step.
log "Waiting for device to be reachable in fastboot..."
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
if [[ -z "$DEVICES" ]]; then
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
    [[ -n "$DEVICES" ]] || die "device lost after image flash (waited 60s)"
fi

# -----------------------------------------------------------------------------
# Step 5 — Bootloader lock (with PERMANENT BRICK WARNING)
# -----------------------------------------------------------------------------
step "5/8  Bootloader lock"

if [[ $LOCK -eq 0 ]]; then
    warn "--no-lock: skipping bootloader lock (bring-up mode). Device remains UNLOCKED."
    warn "  verifiedbootstate will be 'orange' (unlocked) — this is expected in bring-up."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS signed flash complete (NO LOCK — bring-up mode)"
    echo "  Device is unlocked. Re-run without --no-lock to lock."
    echo "============================================================"
    # Skip steps 6-7 (verify + spot-check) — they would FAIL on an unlocked
    # device (orange state). The operator can run flash-signed.sh locally to
    # lock+verify later, or re-run this script without --no-lock.
    log "Skipping verify + spot-check (device is unlocked — yellow/green states require lock)."
    exit 0
fi

# Ensure we are in bootloader (not fastbootd) for the lock command.
FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
if [[ "$FB_MODE" == "yes" ]]; then
    log "Device in fastbootd; rebooting to bootloader before lock..."
    "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    for i in $(seq 1 30); do
        sleep 2
        FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
        DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
        if [[ -n "$DEVICES" && "$FB_MODE" != "yes" ]]; then
            log "in bootloader after ${i} attempts"
            break
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  still waiting for bootloader... (${i}/30)"
    done
fi

# ⚠️  PERMANENT BRICK WARNING  ⚠️
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║   ***  PERMANENT BRICK WARNING — BOOTLOADER LOCK  ***                ║"
echo "║                                                                        ║"
echo "║   You are about to run: fastboot flashing lock                         ║"
echo "║                                                                        ║"
echo "║   Locking the bootloader with the GuardTalk AVB key means the device    ║"
echo "║   will ONLY boot images signed by your avb.pem. Consequences:          ║"
echo "║                                                                        ║"
echo "║   • If you LOSE avb.pem AND have OEM Unlocking disabled → the device   ║"
echo "║     is a PERMANENT BRICK. There is NO recovery path.                   ║"
echo "║   • fastboot flashing unlock CAN recover (wipes userdata) but ONLY if  ║"
echo "║     get_unlock_ability=1, which requires OEM Unlocking enabled in       ║"
echo "║     Developer Options — that setting has a 24h cooldown on user builds.║"
echo "║                                                                        ║"
echo "║   BEFORE PROCEEDING:                                                   ║"
echo "║     1. Verify 3+ offline backups of avb.pem exist (RUNBOOK §3).        ║"
echo "║     2. Confirm OEM Unlocking is currently enabled on the device.        ║"
echo "║     3. Acknowledge: this is irreversible without the key.              ║"
echo "║                                                                        ║"
echo "║   Confirm on-device with Vol-Up when the fastboot prompt appears.      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
if ! confirm "Proceed with fastboot flashing lock?"; then
    warn "Lock DECLINED. Device remains UNLOCKED."
    warn "Re-run without --no-lock to lock later, or run flash-signed.sh locally."
    warn "Skipping verify (device is unlocked — orange state expected)."
    exit 0
fi

log "Running: fastboot flashing lock"
"$FASTBOOT" flashing lock \
    || die "fastboot flashing lock failed — device may still be unlocked. Manual fix: fastboot flashing lock"
log "Bootloader locked ✓"

# -----------------------------------------------------------------------------
# Step 6 — Reboot + post-boot verification
# -----------------------------------------------------------------------------
step "6/8  Reboot + verify signed-boot state"

log "Rebooting device..."
"$FASTBOOT" reboot 2>/dev/null || warn "reboot returned non-zero (device may still be rebooting)"

log "Waiting for device to boot (adb)..."
# Wait for adb; can take a while on first boot.
"$ADB" wait-for-device || die "adb wait-for-device timed out"
sleep 5

VERIFIED_BOOTSTATE="$("$ADB" shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r\n' || true)"
FLASH_LOCKED="$("$ADB" shell getprop ro.boot.flash.locked 2>/dev/null | tr -d '\r\n' || true)"
PRODUCT_NAME="$("$ADB" shell getprop ro.product.name 2>/dev/null | tr -d '\r\n' || true)"

log "  ro.boot.verifiedbootstate = ${VERIFIED_BOOTSTATE:-<empty>}"
log "  ro.boot.flash.locked      = ${FLASH_LOCKED:-<empty>}"
log "  ro.product.name           = ${PRODUCT_NAME:-<empty>}"

# Verified-boot state semantics (Android Verified Boot):
#   green  = locked + OEM-embedded AVB key (Google's key in Pixel bootloader ROM)
#   yellow = locked + custom AVB key (injected via fastboot flash avb_custom_key)
#   orange = unlocked
#   red    = locked, AVB verification FAILED
#
# GuardTalkOS uses its OWN offline-generated AVB key, injected via
# `fastboot flash avb_custom_key`. Therefore the CORRECT, EXPECTED, and SECURE
# state for a GuardTalkOS-locked device is `yellow`.
# `green` would only occur if the OEM (Google) AVB key matched — i.e. a
# security anomaly in our context. Treat as WARN (device IS locked+verified,
# but the key is unexpected).
# `orange` and `red` are hard FAILs.
OK_VBS=0
OK_LOCK=0
OK_PRODUCT=0
VBS_LABEL="✗ FAIL"
case "$VERIFIED_BOOTSTATE" in
    yellow)
        OK_VBS=1
        VBS_LABEL="✓ LOCKED (custom AVB key) — PASS"
        ;;
    green)
        OK_VBS=1
        VBS_LABEL="⚠ LOCKED (OEM key — UNEXPECTED) — WARN"
        warn "verifiedbootstate=green — UNEXPECTED for GuardTalkOS."
        warn "  green indicates the OEM (Google) AVB key matched, not the GuardTalk"
        warn "  custom key. Confirm avb_custom_key was flashed correctly."
        ;;
    orange)
        OK_VBS=0
        VBS_LABEL="✗ FAIL (unlocked)"
        ;;
    red)
        OK_VBS=0
        VBS_LABEL="✗ FAIL (AVB verification failed)"
        ;;
    *)
        OK_VBS=0
        VBS_LABEL="✗ FAIL (unknown state: '${VERIFIED_BOOTSTATE}')"
        ;;
esac

[[ "$FLASH_LOCKED" == "1" ]] && OK_LOCK=1
if [[ "$PRODUCT_NAME" == "$DEVICE" || "$PRODUCT_NAME" == "${DEVICE}_cur" ]]; then
    OK_PRODUCT=1
fi

echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo " GuardTalkOS Signed-Flash Verification"
echo "══════════════════════════════════════════════════════════════════════"
printf "  %-34s %-12s %s\n" "ro.boot.verifiedbootstate" "${VERIFIED_BOOTSTATE:-<empty>}" "$VBS_LABEL"
printf "  %-34s %-12s %s\n" "ro.boot.flash.locked"      "${FLASH_LOCKED:-<empty>}"      "$([ $OK_LOCK -eq 1 ] && echo "✓ LOCKED — PASS" || echo "✗ FAIL")"
printf "  %-34s %-12s %s\n" "ro.product.name"           "${PRODUCT_NAME:-<empty>}"      "$([ $OK_PRODUCT -eq 1 ] && echo "✓ MATCH — PASS" || echo "✗ FAIL")"
echo "══════════════════════════════════════════════════════════════════════"

if [[ $OK_VBS -eq 0 ]] || [[ $OK_LOCK -eq 0 ]] || [[ $OK_PRODUCT -eq 0 ]]; then
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
log "Verification PASSED ✓"

# -----------------------------------------------------------------------------
# Step 7 — Fastboot-FS-protection spot-check (optional, per SECURITY report)
# -----------------------------------------------------------------------------
step "7/8  Fastboot filesystem-protection spot-check"

# Reboot to bootloader and verify that fastboot fetch / unsigned flash are
# REJECTED on the locked device. (Same as flash-signed.sh:336-373.)
log "Rebooting to bootloader for negative tests..."
"$ADB" reboot-bootloader 2>/dev/null || true
sleep 3

# Wait for fastboot
for i in $(seq 1 30); do
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    [[ -n "$DEVICES" ]] && break
    sleep 2
    [[ $((i % 5)) -eq 0 ]] && log "  waiting for fastboot... (${i}/30)"
done
DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
[[ -n "$DEVICES" ]] || { warn "device not reachable in fastboot — skipping spot-check"; goto_skip=1; }

if [[ -z "${goto_skip:-}" ]]; then
    # 1) fastboot fetch must be rejected on a locked device.
    log "  test: fastboot fetch vendor_boot (expect REJECT)..."
    FETCH_OUT="$("$FASTBOOT" fetch vendor_boot 2>&1 || true)"
    log "  -> $FETCH_OUT"
    if echo "$FETCH_OUT" | grep -qiE 'FAIL|not allowed|rejected|cannot'; then
        log "  ✓ fetch correctly rejected"
    else
        warn "fetch did not appear to be rejected. Investigate manually."
    fi

    # 2) Attempt to flash an unsigned image of system — expect rejection.
    log "  test: fastboot flash system <unsigned> (expect REJECT)..."
    TMPIMG="/tmp/gt-sign-spotcheck-$$.img"
    head -c 4096 /dev/urandom > "$TMPIMG" 2>/dev/null || printf '\x00%.0s' {1..4096} > "$TMPIMG"
    FLASH_OUT="$("$FASTBOOT" flash system "$TMPIMG" 2>&1 || true)"
    log "  -> $FLASH_OUT"
    if echo "$FLASH_OUT" | grep -qiE 'FAIL|not allowed|rejected|invalid|avb'; then
        log "  ✓ unsigned flash correctly rejected"
    else
        warn "unsigned flash did not appear to be rejected."
    fi
    rm -f "$TMPIMG"
fi

log "Returning to OS..."
"$FASTBOOT" reboot 2>/dev/null || warn "reboot returned non-zero (device may still be rebooting)"

# -----------------------------------------------------------------------------
# Step 8 — Done
# -----------------------------------------------------------------------------
step "8/8  Done"

echo ""
echo "============================================================"
echo "  GuardTalkOS SIGNED flash + lock + verify complete!"
echo "  verifiedbootstate = ${VERIFIED_BOOTSTATE:-<unknown>} (expected: yellow)"
echo "  flash.locked      = ${FLASH_LOCKED:-<unknown>} (expected: 1)"
echo "  product.name      = ${PRODUCT_NAME:-<unknown>}"
echo "  Work dir:         $LOCAL_WORK_DIR"
echo ""
echo "  AVB verification is ENABLED (signed images, no --disable-verification)."
echo "  The device will ONLY boot GuardTalk-signed images."
echo "  Guard avb.pem carefully — loss = permanent brick (RUNBOOK §3)."
echo "============================================================"
