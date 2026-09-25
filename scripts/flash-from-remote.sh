#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS — remote flash script (multi-device)
# Pulls images from the build server and flashes them via fastboot.
#
# Auto-detects the plugged device (fastboot `product` or adb `ro.product.device`)
# and selects the matching desktop-flash bundle on the build host:
#   tokay    (Pixel 9)           → releases/desktop-flash/latest
#   akita    (Pixel 8a)          → releases/desktop-flash/akita-latest
#   komodo   (Pixel 9 Pro XL)    → releases/desktop-flash/komodo-latest
#   rango    (Pixel 10 Pro Fold) → releases/desktop-flash/rango-latest
#   caiman   (Pixel 9 Pro)       → releases/desktop-flash/caiman-latest
#   comet    (Pixel 9 Pro Fold)  → releases/desktop-flash/comet-latest
#   tegu     (Pixel 9a)          → releases/desktop-flash/tegu-latest
#   stallion (Pixel 10a)         → releases/desktop-flash/stallion-latest
#   shiba    (Pixel 8)           → releases/desktop-flash/shiba-latest
#   husky    (Pixel 8 Pro)       → releases/desktop-flash/husky-latest
#   frankel  (Pixel 10)          → releases/desktop-flash/frankel-latest
#   blazer   (Pixel 10 Pro)      → releases/desktop-flash/blazer-latest
#   mustang  (Pixel 10 Pro XL)   → releases/desktop-flash/mustang-latest
#
# T-PORT-FLASH-CLI-9DEV (P0): the 9 devices above are the DEC-PORT-GEN8910 port
# program. tokay keeps its legacy `latest` bundle alias; every other device uses
# the `<codename>-latest` convention.
#
# If the phone is booted into Android (adb state=device) — or recovery —
# the script reboots it into the bootloader (fastboot) automatically.
#
# Every device except tokay: also downloads init.insmod.<device>.cfg and pushes it
# to /vendor_dlkm/etc/ after reboot (fixes boot-logo hang if vendor_dlkm
# was built without that cfg).
#
# AVB / vbmeta (all devices, critical for rango):
#   Flashes ALL vbmeta* with BOTH --disable-verity and --disable-verification.
#
# Flash order (critical for rango / Pixel 10 Pro Fold):
#   bootloader (BOTH A/B slots) + radio → GrapheneOS firmware cleanup → wipe →
#   **fastbootd + logical** → THEN GuardTalk boot/vbmeta.
#   Entering fastbootd AFTER flashing GuardTalk boot caused G-logo reboot loops
#   (userspace fastbootd never starts → system/vendor never flashed).
#   On laguna (rango|frankel|blazer|mustang), a stock factory rescue boot
#   (releases/desktop-flash/<dev>-rescue-boot/) is ALWAYS flashed before the
#   first fastbootd attempt (prior GT boot often G-logo loops). Logical is
#   flashed, then GuardTalkOS boot replaces rescue.
#   T-PORT-LAGUNA-HYBRID: the FULL GuardTalk laguna boot chain (fullgt) was
#   ABL-rejected on-device, so GT_BOOT_CHAIN=hybrid keeps the step-4 stock
#   rescue boot chain and skips the step-6 GT boot flash. Default is 'gt'
#   (unchanged) — hybrid is operator opt-in and laguna-only.
#
# GrapheneOS flash-all parity (script/generate-release.sh +
# device/common/generate-factory-images-common.sh):
#   ALL (13 devices): dual-slot bootloader via --slot=other dance;
#     oem uart disable; erase dpm_a + dpm_b.
#   Official order after radio: erase avb_custom_key → flash avb_custom_key
#     avb_pkmd.bin → oem uart disable → erase dpm_a/dpm_b → update OS images.
#   rango|mustang|blazer|frankel (laguna/muzel + rango): NO fips erase.
#   Everyone else (tokay/akita/komodo/caiman/comet/tegu/stallion/shiba/husky):
#     also erase fips (Pixel 8/9/10a family). Grouping is EXACTLY
#     script/generate-release.sh — never inferred from SoC (blazer is laguna
#     yet erases no fips).
#   vbmeta is flashed ONCE, after the boot chain (official `update` writes it
#   with the image set). No duplicate mid-sequence vbmeta passes.
#
# Overrides (optional):
#   DEVICE=tokay|akita|komodo|rango|caiman|comet|tegu|stallion|shiba|husky|frankel|blazer|mustang
#   REMOTE_BUILD_DIR=...   REMOTE_KEY_DIR=...
#   REMOTE_HOST=...        REMOTE_TREE=...
#   ALLOW_AVB_KEY_FAIL=1   continue if avb_custom_key flash fails (default: die)
#   GT_BOOT_CHAIN=gt|hybrid  boot-chain mode. Default 'gt' = today's behaviour
#                          (GuardTalk A/B boot chain flashed at step 6).
#                          'hybrid' = laguna-only: keep the step-4 stock factory
#                          rescue boot chain, SKIP the step-6 GT boot flash, keep
#                          the step-7 vbmeta pass. Never auto-selected.
#   CAPTURE_LOGS=1         opt-in post-flash debug capture (fastboot + adb).
#                          DEFAULT OFF. Unset/0 leaves the flash path unchanged.
#                          Writes a timestamped evidence dir and prints its path.
#   CAPTURE_POST_ADB_SECS=N  seconds to keep watching AFTER adb first appears so
#                          a later fallback to fastboot is recorded (default 120).
#                          Only honoured when CAPTURE_LOGS=1.
#
# Post-flash debug capture (CAPTURE_LOGS=1) — opt-in, best-effort, never fatal:
#   The boot watch stops at the FIRST adb enumeration (~30s) and reports
#   "flash complete"; a later G-logo → fastboot fallback is therefore missed.
#   With CAPTURE_LOGS=1 the script keeps watching CAPTURE_POST_ADB_SECS after
#   adb first appears, snapshots BOTH transports, and records the fallback.
#   fastboot/bootloader: oem dmesg, oem bcd read {command,status,recovery,stage},
#                        getvar slot-retry-count/slot-unbootable (a+b), getvar all.
#   adb/Android:         logcat -d (full + errors-only), getprop (key + full),
#                        dumpsys activity exit-info/lastanr + service list,
#                        /sys/fs/pstore/* where reachable.
#   Every capture step is best-effort: a failure logs a warning and never die()s.
#   Evidence dir: <LOCAL_WORK_DIR>/flash-capture-<device>-<YYYYmmdd-HHMMSS>/
#
# Bisect stamps: if REMOTE_BUILD_DIR is set and REMOTE_KEY_DIR is unset,
# KEY_DIR defaults to the same BUILD_DIR (avb_pkmd.bin stays with that stamp).
# Do not assume rango-latest for keys when flashing a REMOTE_BUILD_DIR override.
#
# Mac: re-sync this script from the build host after host-side edits (scp):
#   scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/flash-from-remote.sh \
#       ~/GuardTalk-flash/flash-from-remote.sh
#   chmod +x ~/GuardTalk-flash/flash-from-remote.sh
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REMOTE_HOST="${REMOTE_HOST:-oss-c1@192.168.2.220}"
REMOTE_TREE="${REMOTE_TREE:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree}"

# Empty = auto from plugged device (or DEVICE=). Explicit env wins.
REMOTE_BUILD_DIR="${REMOTE_BUILD_DIR:-}"
REMOTE_KEY_DIR="${REMOTE_KEY_DIR:-}"
DEVICE="${DEVICE:-}"   # optional: tokay|akita|komodo|rango|caiman|comet|tegu|stallion|shiba|husky|frankel|blazer|mustang

LOCAL_WORK_DIR="${LOCAL_WORK_DIR:-.}"

FASTBOOT="${FASTBOOT:-fastboot}"
ADB="${ADB:-adb}"
# Seconds to wait after adb reboot bootloader before giving up
FASTBOOT_WAIT_SECS="${FASTBOOT_WAIT_SECS:-60}"
# Seconds to wait for adb after final reboot (non-tokay insmod cfg push)
ADB_WAIT_SECS="${ADB_WAIT_SECS:-180}"
# Seconds to wait for fastbootd (is-userspace=yes) after reboot fastboot
FASTBOOTD_WAIT_SECS="${FASTBOOTD_WAIT_SECS:-90}"

# Opt-in post-flash debug capture. Default OFF — when 0/unset the flash path,
# logs, and exit codes are unchanged. See the header for what is captured.
CAPTURE_LOGS="${CAPTURE_LOGS:-0}"
# Seconds to keep watching after adb first appears, so a later fallback to
# fastboot is recorded (capture mode only; ignored when CAPTURE_LOGS != 1).
CAPTURE_POST_ADB_SECS="${CAPTURE_POST_ADB_SECS:-120}"
# Timestamped evidence dir, created lazily by capture_dir_init when opted in.
CAPTURE_DIR=""

# Stock factory boot chain for the laguna family (rango|frankel|blazer|mustang)
# when the GuardTalk boot cannot reach fastbootd.
REMOTE_RESCUE_DIR="${REMOTE_RESCUE_DIR:-}"  # set after tree known / device=laguna
# Local dir + image list for the downloaded rescue chain (set by download_rescue_boot).
RESCUE_LOCAL=""

# Boot-chain mode (T-PORT-LAGUNA-HYBRID). 'gt' (default) = unchanged behaviour:
# install the GuardTalk A/B boot chain at step 6. 'hybrid' = keep the stock
# factory rescue boot chain installed at step 4, SKIP the step-6 GuardTalk
# boot-chain flash, keep the step-7 vbmeta pass. Only valid for the laguna
# family, whose shipped fullgt boot chain was ABL-rejected on-device
# (B-PORT-LAGUNA-STATE §3). Never auto-selected — the operator must opt in.
GT_BOOT_CHAIN="${GT_BOOT_CHAIN:-gt}"

# -----------------------------------------------------------------------------
# Images to download
# -----------------------------------------------------------------------------
FW_IMAGES=(bootloader.img radio.img)
AB_IMAGES=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img)
NOAB_IMAGES=(dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img)
LOGICAL_IMAGES=(system.img system_ext.img product.img vendor.img vendor_dlkm.img system_dlkm.img)
SUPER_IMAGE=(super.img)
EXTRA_FILES=(super_empty.img avb_pkmd.bin)
# NOTE: vendor_boot_diag.img (diagnostic: factory vendor_boot + init_fatal_panic)
# is downloaded via RANGO_EXTRA_FILES, not flashed by the script. Flash manually
# to capture init's FATAL line via "fastboot oem dmesg".
# Appended after device detect (see apply_device_extra_downloads)
AKITA_EXTRA_FILES=(init.insmod.akita.cfg)
KOMODO_EXTRA_FILES=(init.insmod.komodo.cfg)
RANGO_EXTRA_FILES=(init.insmod.rango.cfg vendor_boot_diag.img)
# T-PORT-FLASH-CLI-9DEV: the 9 DEC-PORT-GEN8910 devices each ship their own
# init.insmod.<codename>.cfg (one entry per device; no shared cfg).
CAIMAN_EXTRA_FILES=(init.insmod.caiman.cfg)
COMET_EXTRA_FILES=(init.insmod.comet.cfg)
TEGU_EXTRA_FILES=(init.insmod.tegu.cfg)
STALLION_EXTRA_FILES=(init.insmod.stallion.cfg)
SHIBA_EXTRA_FILES=(init.insmod.shiba.cfg)
HUSKY_EXTRA_FILES=(init.insmod.husky.cfg)
FRANKEL_EXTRA_FILES=(init.insmod.frankel.cfg)
BLAZER_EXTRA_FILES=(init.insmod.blazer.cfg)
MUSTANG_EXTRA_FILES=(init.insmod.mustang.cfg)
# Rescue chain image set — identical filenames for every laguna device.
RESCUE_IMGS=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img vbmeta.img pvmfw.img)

ALL_DOWNLOADS=("${FW_IMAGES[@]}" "${AB_IMAGES[@]}" "${NOAB_IMAGES[@]}" "${LOGICAL_IMAGES[@]}" "${SUPER_IMAGE[@]}" "${EXTRA_FILES[@]}")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
# Logs go to stderr so command substitutions (e.g. dest="$(download_...)")
# never capture "[flash] ..." lines into path variables.
log()  { echo "[flash] $*" >&2; }
warn() { echo "[flash] WARNING: $*" >&2; }
die()  { echo "[flash] FATAL: $*" >&2; exit 1; }
step() { echo "" >&2; echo "=== $* ===" >&2; }

# laguna platform family (Pixel 10 generation). Single source of truth for the
# hybrid boot-chain gate and the recovery-harvest default.
is_laguna_device() {
    case "${1:-}" in
        rango|frankel|blazer|mustang) return 0 ;;
        *) return 1 ;;
    esac
}

# grapheneos.org/install/cli: fastboot must be at least 35.0.1
require_fastboot_min_version() {
    local ver_line major=0 minor=0 patch=0 packed required_packed
    ver_line="$("$FASTBOOT" --version 2>&1 | head -1 || true)"
    log "fastboot: $ver_line"
    if [[ "$ver_line" =~ ([0-9]+)\.([0-9]+)(\.([0-9]+))? ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[4]:-0}"
    else
        die "could not parse fastboot version from '$ver_line' (need ≥ 35.0.1; grapheneos.org/install/cli)"
    fi
    packed=$((10#$major * 10000 + 10#$minor * 100 + 10#$patch))
    required_packed=$((35 * 10000 + 0 * 100 + 1))
    if (( packed < required_packed )); then
        die "fastboot ${major}.${minor}.${patch} is older than 35.0.1 (grapheneos.org/install/cli). Upgrade Android platform-tools."
    fi
}

# Flash vbmeta* with both disable flags. Args: <part> <image> [extra fastboot args...]
# Do not use an empty bash array here: macOS bash 3.2 + `set -u` dies on
# "${extra[@]}" (unbound variable) when vbmeta_system/vbmeta_vendor have no
# extra args. GrapheneOS flash-all uses `fastboot update` (no arrays / no -u).
flash_vbmeta_img() {
    local part="$1"
    local img="$2"
    shift 2
    log "  flash $part (--disable-verity --disable-verification${*:+ $*}) ← $(basename "$img")"
    if [[ $# -gt 0 ]]; then
        "$FASTBOOT" --disable-verity --disable-verification "$@" \
            flash "$part" "$img" \
            || die "failed to flash $part with --disable-verity --disable-verification"
    else
        "$FASTBOOT" --disable-verity --disable-verification \
            flash "$part" "$img" \
            || die "failed to flash $part with --disable-verity --disable-verification"
    fi
}

# Convenience: flash from LOCAL_WORK_DIR/vbmeta*.img.
# Maps partition name to the correct image file.
flash_vbmeta_partition() {
    local part="$1"
    shift
    local img="$LOCAL_WORK_DIR/vbmeta.img"
    case "$part" in
        vbmeta_system) img="$LOCAL_WORK_DIR/vbmeta_system.img" ;;
        vbmeta_vendor) img="$LOCAL_WORK_DIR/vbmeta_vendor.img" ;;
    esac
    flash_vbmeta_img "$part" "$img" "$@"
}

# Normalize fastboot/adb product string → GuardTalk flash codename.
# Accepts exact codenames and common variant strings returned by fastboot/adb.
# T-PORT-FLASH-CLI-9DEV: all 13 DEC-PORT-GEN8910 codenames are known here.
normalize_device() {
    local raw="${1:-}"
    raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '\r')"
    # Strip leading/trailing whitespace
    raw="$(echo "$raw" | xargs)"
    case "$raw" in
        # --- Pixel 8 family ---
        shiba)   echo "shiba" ;;      # Pixel 8
        husky)   echo "husky" ;;      # Pixel 8 Pro
        akita)   echo "akita" ;;      # Pixel 8a
        # --- Pixel 9 family ---
        tokay)   echo "tokay" ;;      # Pixel 9
        caiman)  echo "caiman" ;;     # Pixel 9 Pro
        komodo)  echo "komodo" ;;     # Pixel 9 Pro XL
        tegu)    echo "tegu" ;;       # Pixel 9a
        comet)   echo "comet" ;;      # Pixel 9 Pro Fold
        # --- Pixel 10 family ---
        frankel) echo "frankel" ;;    # Pixel 10
        blazer)  echo "blazer" ;;     # Pixel 10 Pro
        mustang) echo "mustang" ;;    # Pixel 10 Pro XL
        stallion) echo "stallion" ;;  # Pixel 10a
        rango)   echo "rango" ;;      # Pixel 10 Pro Fold
        # Fallback: match on substring for robustness (model-name variants).
        # No codename is a substring of another, so arm order is not significant.
        *)
            case "$raw" in
                *shiba*)   echo "shiba" ;;
                *husky*)   echo "husky" ;;
                *akita*)   echo "akita" ;;
                *tokay*)   echo "tokay" ;;
                *caiman*)  echo "caiman" ;;
                *komodo*)  echo "komodo" ;;
                *tegu*)    echo "tegu" ;;
                *comet*)   echo "comet" ;;
                *frankel*) echo "frankel" ;;
                *blazer*)  echo "blazer" ;;
                *mustang*) echo "mustang" ;;
                *stallion*) echo "stallion" ;;
                *rango*)   echo "rango" ;;
                *)         echo "" ;;
            esac
            ;;
    esac
}

device_pretty() {
    case "$1" in
        shiba)   echo "Pixel 8 (shiba)" ;;
        husky)   echo "Pixel 8 Pro (husky)" ;;
        akita)   echo "Pixel 8a (akita)" ;;
        tokay)   echo "Pixel 9 (tokay)" ;;
        caiman)  echo "Pixel 9 Pro (caiman)" ;;
        komodo)  echo "Pixel 9 Pro XL (komodo)" ;;
        tegu)    echo "Pixel 9a (tegu)" ;;
        comet)   echo "Pixel 9 Pro Fold (comet)" ;;
        frankel) echo "Pixel 10 (frankel)" ;;
        blazer)  echo "Pixel 10 Pro (blazer)" ;;
        mustang) echo "Pixel 10 Pro XL (mustang)" ;;
        stallion) echo "Pixel 10a (stallion)" ;;
        rango)   echo "Pixel 10 Pro Fold (rango)" ;;
        *) echo "$1" ;;
    esac
}

# Set REMOTE_BUILD_DIR / REMOTE_KEY_DIR from codename unless already set.
apply_remote_paths() {
    local codename="$1"
    local auto_build auto_key
    local build_overridden=0
    case "$codename" in
        tokay)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/latest"
            ;;
        akita)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/akita-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/akita-latest"
            ;;
        komodo)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/komodo-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/komodo-latest"
            ;;
        rango)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/rango-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/rango-latest"
            ;;
        # T-PORT-FLASH-CLI-9DEV: DEC-PORT-GEN8910 devices.
        caiman)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/caiman-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/caiman-latest"
            ;;
        comet)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/comet-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/comet-latest"
            ;;
        tegu)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/tegu-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/tegu-latest"
            ;;
        stallion)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/stallion-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/stallion-latest"
            ;;
        shiba)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/shiba-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/shiba-latest"
            ;;
        husky)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/husky-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/husky-latest"
            ;;
        frankel)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/frankel-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/frankel-latest"
            ;;
        blazer)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/blazer-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/blazer-latest"
            ;;
        mustang)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/mustang-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/mustang-latest"
            ;;
        *)
            die "Unsupported device codename '$codename' (supported: tokay, akita, komodo, rango, caiman, comet, tegu, stallion, shiba, husky, frankel, blazer, mustang)"
            ;;
    esac
    if [[ -z "$REMOTE_BUILD_DIR" ]]; then
        REMOTE_BUILD_DIR="$auto_build"
    else
        build_overridden=1
        log "REMOTE_BUILD_DIR override in effect: $REMOTE_BUILD_DIR"
    fi
    if [[ -z "$REMOTE_KEY_DIR" ]]; then
        # Bisect: keep avb_pkmd.bin with the stamp images (not silent *-latest).
        if [[ "$build_overridden" -eq 1 ]]; then
            REMOTE_KEY_DIR="$REMOTE_BUILD_DIR"
            log "REMOTE_KEY_DIR defaulted to BUILD_DIR override: $REMOTE_KEY_DIR"
        else
            REMOTE_KEY_DIR="$auto_key"
        fi
    else
        log "REMOTE_KEY_DIR override in effect: $REMOTE_KEY_DIR"
    fi
    # Stock rescue boot (laguna family: rango|frankel|blazer|mustang) — used if
    # the GuardTalk boot cannot reach fastbootd. They are the same laguna
    # platform and loop identically without it (B-PORT-LAGUNA-RESCUE-GAP).
    # The -z guard preserves the operator REMOTE_RESCUE_DIR override.
    case "$codename" in
        rango|frankel|blazer|mustang)
            if [[ -z "$REMOTE_RESCUE_DIR" ]]; then
                REMOTE_RESCUE_DIR="${REMOTE_TREE}/releases/desktop-flash/${codename}-rescue-boot"
            fi
            ;;
    esac
    # Catch the bash pitfall: `export REMOTE_TREE=... REMOTE_BUILD_DIR=$REMOTE_TREE/...`
    # expands $REMOTE_TREE from the *previous* environment (often empty) →
    # `/releases/desktop-flash/...` and scp dies. Require an absolute path that
    # exists on the remote *before* downloading 3 GB of images.
    [[ "$REMOTE_BUILD_DIR" == /* ]] \
        || die "REMOTE_BUILD_DIR must be an absolute path (got '$REMOTE_BUILD_DIR'). Do not use \$REMOTE_TREE on the same export line — write the full path."
    # MEDIUM-4: path is interpolated into a single-quoted ssh remote command.
    # Reject quote / dollar / backslash / newline before ssh.
    if [[ "$REMOTE_BUILD_DIR" == *$'\n'* || "$REMOTE_BUILD_DIR" == *$'\r'* ]]; then
        die "REMOTE_BUILD_DIR contains a newline — refusing ssh interpolation"
    fi
    if [[ "${REMOTE_BUILD_DIR//[\'\"\$\\]/}" != "$REMOTE_BUILD_DIR" ]]; then
        die "REMOTE_BUILD_DIR contains shell metacharacters (' \" \$ \\) — refusing ssh interpolation"
    fi
    if [[ "$REMOTE_BUILD_DIR" != "${REMOTE_TREE}"/* && "$REMOTE_BUILD_DIR" != "$REMOTE_TREE" ]]; then
        warn "REMOTE_BUILD_DIR is not under REMOTE_TREE ($REMOTE_TREE) — check you did not lose the tree prefix"
    fi
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" "test -d '$REMOTE_BUILD_DIR' && test -f '$REMOTE_BUILD_DIR/bootloader.img'" \
        || die "remote missing $REMOTE_HOST:$REMOTE_BUILD_DIR/bootloader.img — fix REMOTE_BUILD_DIR (full path, not \$REMOTE_TREE on the same export line)"
}

# Read product from fastboot (stderr: "product: tokay") or adb.
detect_product_fastboot() {
    "$FASTBOOT" getvar product 2>&1 | grep -m1 '^product:' | awk '{print $2}' | tr -d '\r' || true
}

detect_product_adb() {
    if ! command -v "$ADB" >/dev/null 2>&1; then
        return 0
    fi
    "$ADB" shell getprop ro.product.device 2>/dev/null | tr -d '\r' || true
}

# First line from `adb devices` that looks like a transport (skip header/empty).
# Prints: "<serial>\t<state>" or empty.
adb_first_transport() {
    if ! command -v "$ADB" >/dev/null 2>&1; then
        return 0
    fi
    "$ADB" devices 2>/dev/null \
        | awk 'NR>1 && $1 != "" { print $1 "\t" $2; exit }' \
        || true
}

# Wait until `fastboot devices` is non-empty. Args: label seconds
wait_for_fastboot() {
    local label="${1:-fastboot}"
    local max_secs="${2:-$FASTBOOT_WAIT_SECS}"
    local attempts=$(( (max_secs + 1) / 2 ))
    local i
    for i in $(seq 1 "$attempts"); do
        sleep 2
        DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
        if [[ -n "$DEVICES" ]]; then
            log "device entered fastboot after ${i} attempts ($(( i * 2 ))s) [$label]"
            return 0
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastboot... (${i}/${attempts})"
    done
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    [[ -n "$DEVICES" ]]
}

# GrapheneOS flash-all.sh bootloader sequence (both A/B slots):
#   flash --slot=other → set-active=other → reboot-bootloader → repeat.
# Cite: device/common/generate-factory-images-common.sh
flash_bootloader_ab_both_slots() {
    local img="$LOCAL_WORK_DIR/bootloader.img"
    [[ -f "$img" ]] || die "bootloader.img missing at $img"

    log "Flashing bootloader to BOTH slots (GrapheneOS --slot=other dance)..."
    log "  flash bootloader --slot=other (pass 1)"
    "$FASTBOOT" flash --slot=other bootloader "$img" \
        || die "bootloader flash --slot=other failed (pass 1)"
    "$FASTBOOT" --set-active=other \
        || die "set-active=other failed (pass 1)"
    "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    wait_for_fastboot "bootloader pass 1" "$FASTBOOT_WAIT_SECS" \
        || die "device lost after bootloader pass 1"

    log "  flash bootloader --slot=other (pass 2 — covers former active slot)"
    "$FASTBOOT" flash --slot=other bootloader "$img" \
        || die "bootloader flash --slot=other failed (pass 2)"
    "$FASTBOOT" --set-active=other \
        || die "set-active=other failed (pass 2)"
    "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    wait_for_fastboot "bootloader pass 2" "$FASTBOOT_WAIT_SECS" \
        || die "device lost after bootloader pass 2"
    log "Bootloader flashed on both slots ✓"
}

# Device firmware cleanup matching GrapheneOS script/generate-release.sh flags.
# AUTHORITY: script/generate-release.sh (READ-ONLY). Exactly two profiles:
#   rango|mustang|blazer|frankel : DISABLE_UART + DISABLE_DPM          (NO fips)
#   every other program device   : DISABLE_UART + DISABLE_FIPS + DISABLE_DPM
# Never infer this from the SoC: blazer is laguna but must NOT erase fips, while
# stallion is zumapro and MUST. A missing profile is a parity regression, so the
# catch-all arm dies — it must never warn-and-continue (Law 3, fail loudly).
apply_grapheneos_firmware_cleanup() {
    local codename="${FLASH_DEVICE:-}"
    case "$codename" in
        # laguna/muzel (Pixel 10 / 10 Pro / 10 Pro XL) + rango: NO fips erase.
        rango|mustang|blazer|frankel)
            log "$codename: GrapheneOS cleanup (uart disable + erase dpm_a/dpm_b — NO fips)..."
            "$FASTBOOT" oem uart disable \
                || die "oem uart disable failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase dpm_a \
                || die "erase dpm_a failed (required for $codename — clears stale debugpolicy / err -7)"
            "$FASTBOOT" erase dpm_b \
                || die "erase dpm_b failed (required for $codename — clears stale debugpolicy / err -7)"
            log "$codename firmware cleanup ✓"
            ;;
        # Everything else in the 13-device program: UART + FIPS + DPM.
        tokay|akita|komodo|caiman|comet|tegu|stallion|shiba|husky)
            log "$codename: GrapheneOS cleanup (uart + erase fips + erase dpm_a/dpm_b)..."
            "$FASTBOOT" oem uart disable \
                || die "oem uart disable failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase fips \
                || die "erase fips failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase dpm_a \
                || die "erase dpm_a failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase dpm_b \
                || die "erase dpm_b failed (required for $codename GrapheneOS parity)"
            log "$codename firmware cleanup ✓"
            ;;
        # T-PORT-FLASH-CLI-9DEV / A3: a missing profile is a parity regression,
        # not a warning. Never flash a device without GrapheneOS cleanup parity.
        *)
            die "No GrapheneOS firmware-cleanup profile for '$codename' — add it to BOTH this case and script/generate-release.sh"
            ;;
    esac
}

# After FLASH_DEVICE is known, append device-specific downloads.
# Every program device except tokay has an init.insmod.<codename>.cfg.
apply_device_extra_downloads() {
    case "${FLASH_DEVICE:-}" in
        akita)
            for f in "${AKITA_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "akita extras: ${AKITA_EXTRA_FILES[*]}"
            ;;
        komodo)
            for f in "${KOMODO_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "komodo extras: ${KOMODO_EXTRA_FILES[*]}"
            ;;
        rango)
            for f in "${RANGO_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "rango extras: ${RANGO_EXTRA_FILES[*]}"
            ;;
        # T-PORT-FLASH-CLI-9DEV: DEC-PORT-GEN8910 devices (own insmod cfg each).
        caiman)
            for f in "${CAIMAN_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "caiman extras: ${CAIMAN_EXTRA_FILES[*]}"
            ;;
        comet)
            for f in "${COMET_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "comet extras: ${COMET_EXTRA_FILES[*]}"
            ;;
        tegu)
            for f in "${TEGU_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "tegu extras: ${TEGU_EXTRA_FILES[*]}"
            ;;
        stallion)
            for f in "${STALLION_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "stallion extras: ${STALLION_EXTRA_FILES[*]}"
            ;;
        shiba)
            for f in "${SHIBA_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "shiba extras: ${SHIBA_EXTRA_FILES[*]}"
            ;;
        husky)
            for f in "${HUSKY_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "husky extras: ${HUSKY_EXTRA_FILES[*]}"
            ;;
        frankel)
            for f in "${FRANKEL_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "frankel extras: ${FRANKEL_EXTRA_FILES[*]}"
            ;;
        blazer)
            for f in "${BLAZER_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "blazer extras: ${BLAZER_EXTRA_FILES[*]}"
            ;;
        mustang)
            for f in "${MUSTANG_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "mustang extras: ${MUSTANG_EXTRA_FILES[*]}"
            ;;
    esac
}

# Insurance only: GrapheneOS flash-all never adb-pushes this file. It is baked
# into vendor_dlkm.img (guardtalk-insmod.mk). Safe no-op unless FLASH_DEVICE is
# one of the devices with an init.insmod.<device>.cfg (all program devices but
# tokay). Push only if an older vendor_dlkm.img omitted it
# (boot-logo hang / missing Wi‑Fi touch haptics). Never FATAL after Android
# already reached — vendor_dlkm is often EROFS and remount-rw fails.
install_insmod_cfg_via_adb() {
    local codename="${FLASH_DEVICE:-}"
    local cfg_name=""
    case "$codename" in
        akita) cfg_name="init.insmod.akita.cfg" ;;
        komodo) cfg_name="init.insmod.komodo.cfg" ;;
        rango) cfg_name="init.insmod.rango.cfg" ;;
        # T-PORT-FLASH-CLI-9DEV: DEC-PORT-GEN8910 devices.
        caiman) cfg_name="init.insmod.caiman.cfg" ;;
        comet) cfg_name="init.insmod.comet.cfg" ;;
        tegu) cfg_name="init.insmod.tegu.cfg" ;;
        stallion) cfg_name="init.insmod.stallion.cfg" ;;
        shiba) cfg_name="init.insmod.shiba.cfg" ;;
        husky) cfg_name="init.insmod.husky.cfg" ;;
        frankel) cfg_name="init.insmod.frankel.cfg" ;;
        blazer) cfg_name="init.insmod.blazer.cfg" ;;
        mustang) cfg_name="init.insmod.mustang.cfg" ;;
        *) return 0 ;;
    esac
    local cfg="$LOCAL_WORK_DIR/$cfg_name"
    [[ -f "$cfg" ]] || die "$cfg_name missing locally after download"

    if ! command -v "$ADB" >/dev/null 2>&1; then
        warn "adb not found — cannot push $cfg_name (vendor_dlkm.img should already contain it)"
        return 0
    fi

    log "Waiting for adb to check $cfg_name (up to ${ADB_WAIT_SECS}s)..."
    local waited=0
    while [[ "$waited" -lt "$ADB_WAIT_SECS" ]]; do
        if "$ADB" wait-for-device shell true >/dev/null 2>&1; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
        [[ $((waited % 20)) -eq 0 ]] && log "  still waiting for adb... (${waited}/${ADB_WAIT_SECS}s)"
    done

    if ! "$ADB" shell true >/dev/null 2>&1; then
        warn "adb not ready after ${ADB_WAIT_SECS}s — skip cfg push. If stuck on boot logo, re-run with phone booted/adb, or reflash (fixed vendor_dlkm.img)."
        return 0
    fi

    if "$ADB" shell "test -f /vendor_dlkm/etc/$cfg_name" >/dev/null 2>&1; then
        log "$cfg_name already on vendor_dlkm (from image) — skip insurance push"
        return 0
    fi

    log "vendor_dlkm missing $cfg_name — insurance push (adb root + remount)..."
    "$ADB" root >/dev/null 2>&1 || true
    sleep 2
    "$ADB" wait-for-device >/dev/null 2>&1 || true
    if ! "$ADB" remount >/dev/null 2>&1; then
        if ! "$ADB" shell mount -o remount,rw /vendor_dlkm >/dev/null 2>&1; then
            warn "could not remount vendor_dlkm rw (often EROFS). Skip insurance push — phone already reached Android."
            return 0
        fi
    fi

    log "Pushing $cfg_name → /vendor_dlkm/etc/..."
    if ! "$ADB" push "$cfg" "/vendor_dlkm/etc/$cfg_name"; then
        warn "adb push $cfg_name failed (vendor_dlkm read-only). Phone already reached Android; this file is optional insurance."
        return 0
    fi
    if "$ADB" shell "test -f /vendor_dlkm/etc/$cfg_name" >/dev/null 2>&1; then
        log "$cfg_name installed on device ✓"
        log "Rebooting so second-stage modules (audio/haptics/touch) can load..."
        "$ADB" reboot >/dev/null 2>&1 || warn "adb reboot failed (reboot manually)"
    else
        warn "$cfg_name not visible after push — continuing (boot already succeeded)"
    fi
}

# Backward-compatible alias (akita callers / docs).
install_akita_insmod_cfg_via_adb() {
    install_insmod_cfg_via_adb
}

# If phone is in Android (or recovery) via adb, reboot into bootloader.
# Leaves DEVICES set to `fastboot devices` output when ready.
ensure_device_in_fastboot() {
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" ]]; then
        log "Device already in fastboot"
        return 0
    fi

    local transport serial state
    transport="$(adb_first_transport)"
    if [[ -z "$transport" ]]; then
        if ! command -v "$ADB" >/dev/null 2>&1; then
            die "No device in fastboot, and adb is not installed. Install platform-tools, or boot into fastboot manually (vol-down + power)."
        fi
        die "No device in fastboot or adb. Boot into Android with USB debugging enabled, or hold vol-down + power for fastboot, then retry."
    fi

    serial="$(printf '%s' "$transport" | awk -F'\t' '{print $1}')"
    state="$(printf '%s' "$transport" | awk -F'\t' '{print $2}')"

    case "$state" in
        device)
            DETECTED_RAW="$(detect_product_adb)"
            log "Phone is booted into Android (adb serial=$serial, product=${DETECTED_RAW:-unknown})"
            log "Rebooting into fastboot (bootloader) automatically..."
            ;;
        recovery)
            DETECTED_RAW="$(detect_product_adb)"
            log "Phone is in recovery (adb serial=$serial, product=${DETECTED_RAW:-unknown})"
            log "Rebooting into fastboot (bootloader) automatically..."
            ;;
        sideload)
            log "Phone is in sideload mode (adb serial=$serial)"
            log "Rebooting into fastboot (bootloader) automatically..."
            ;;
        unauthorized)
            die "adb device is unauthorized. Unlock the phone, accept the RSA fingerprint prompt, then re-run."
            ;;
        offline)
            die "adb device is offline (serial=$serial). Unplug/replug USB, toggle USB debugging, then re-run."
            ;;
        *)
            die "adb device state='$state' (serial=$serial) cannot auto-enter fastboot. Boot into fastboot manually (vol-down + power)."
            ;;
    esac

    "$ADB" reboot bootloader \
        || die "adb reboot bootloader failed. Boot into fastboot manually (vol-down + power) and retry."

    wait_for_fastboot "adb reboot bootloader" "$FASTBOOT_WAIT_SECS" \
        || die "Device did not enter fastboot after adb reboot bootloader (waited ${FASTBOOT_WAIT_SECS}s). Manual: vol-down + power, then re-run."
}

# -----------------------------------------------------------------------------
# Step 0 — Sanity checks + device detect
# -----------------------------------------------------------------------------
step "0/8  Sanity checks + device detect"

command -v "$FASTBOOT" >/dev/null 2>&1 || die "fastboot not found in PATH"
command -v scp >/dev/null 2>&1 || die "scp not found in PATH"
command -v ssh >/dev/null 2>&1 || die "ssh not found in PATH"

require_fastboot_min_version
log "remote:   $REMOTE_HOST"
log "tree:     $REMOTE_TREE"
log "local work: $LOCAL_WORK_DIR"

DETECTED_RAW=""
ensure_device_in_fastboot
log "device: $DEVICES"

# Resolve codename: DEVICE= override > adb detect > fastboot product
if [[ -n "$DEVICE" ]]; then
    FLASH_DEVICE="$(normalize_device "$DEVICE")"
    [[ -n "$FLASH_DEVICE" ]] || die "DEVICE='$DEVICE' not supported (use tokay, akita, komodo, rango, caiman, comet, tegu, stallion, shiba, husky, frankel, blazer, or mustang)"
    log "DEVICE override: $FLASH_DEVICE ($(device_pretty "$FLASH_DEVICE"))"
else
    if [[ -z "$DETECTED_RAW" ]]; then
        DETECTED_RAW="$(detect_product_fastboot)"
    fi
    # If still empty, try fastboot anyway (adb path may have missed prop)
    if [[ -z "$DETECTED_RAW" ]]; then
        DETECTED_RAW="$(detect_product_fastboot)"
    fi
    FLASH_DEVICE="$(normalize_device "$DETECTED_RAW")"
    if [[ -z "$FLASH_DEVICE" ]]; then
        die "Could not map product '${DETECTED_RAW:-unknown}' to a flash bundle. Set DEVICE=tokay, DEVICE=akita, DEVICE=komodo, DEVICE=rango, DEVICE=caiman, DEVICE=comet, DEVICE=tegu, DEVICE=stallion, DEVICE=shiba, DEVICE=husky, DEVICE=frankel, DEVICE=blazer, or DEVICE=mustang explicitly."
    fi
    log "Detected product='$DETECTED_RAW' → $(device_pretty "$FLASH_DEVICE")"
fi

# Fail closed if fastboot product disagrees with DEVICE override
FB_PRODUCT="$(detect_product_fastboot)"
FB_NORM="$(normalize_device "$FB_PRODUCT")"
if [[ -n "$FB_NORM" && "$FB_NORM" != "$FLASH_DEVICE" ]]; then
    die "Plugged device is '$FB_PRODUCT' but flash target is '$FLASH_DEVICE'. Unplug the other phone or set DEVICE=$FB_NORM."
fi

# Validate GT_BOOT_CHAIN now that the target device is known (T-PORT-LAGUNA-HYBRID).
case "$GT_BOOT_CHAIN" in
    gt|hybrid) : ;;
    *) die "GT_BOOT_CHAIN='$GT_BOOT_CHAIN' is invalid (expected 'gt' (default) or 'hybrid')" ;;
esac
if [[ "$GT_BOOT_CHAIN" == "hybrid" ]] && ! is_laguna_device "$FLASH_DEVICE"; then
    die "GT_BOOT_CHAIN=hybrid is only valid for the laguna family (rango|frankel|blazer|mustang). '$FLASH_DEVICE' is not laguna — use the default GT_BOOT_CHAIN=gt."
fi
if [[ "$GT_BOOT_CHAIN" == "hybrid" ]]; then
    log "boot chain: GT_BOOT_CHAIN=hybrid — stock factory rescue boot stays installed; step-6 GT A/B boot flash WILL BE SKIPPED (laguna fullgt boot is ABL-rejected on-device)"
else
    log "boot chain: GT_BOOT_CHAIN=gt (default) — GuardTalk A/B boot chain is flashed at step 6 (unchanged)"
fi

apply_remote_paths "$FLASH_DEVICE"
apply_device_extra_downloads
log "build dir: $REMOTE_BUILD_DIR"
log "key dir:   $REMOTE_KEY_DIR"

# Get current slot
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# Fail closed if bootloader is locked (flash will fail with a cryptic remote error).
UNLOCKED="$("$FASTBOOT" getvar unlocked 2>&1 | grep -m1 '^unlocked:' | awk '{print $2}' | tr -d '\r' || true)"
UNLOCKED_LC="$(printf '%s' "$UNLOCKED" | tr '[:upper:]' '[:lower:]')"
log "unlocked: ${UNLOCKED:-unknown}"
if [[ "$UNLOCKED_LC" != "yes" ]]; then
    die "Bootloader is LOCKED (unlocked=${UNLOCKED:-unknown}). Unlock first:
  1) Boot Android → Developer options → enable OEM unlocking
  2) Reboot to fastboot:  adb reboot bootloader
  3) Unlock (THIS WIPES THE PHONE):  fastboot flashing unlock
  4) Confirm Unlock on the device screen, wait for wipe + reboot
  5) Re-enter fastboot and re-run this script"
fi

# Flash to current slot
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
        # Always refresh full boot chain + logicals + super + AVB key. Skipping
        # vendor_kernel_boot / dtbo / pvmfw after "keep cache" left rango with
        # mismatched companions vs freshly downloaded boot/vendor_boot
        # (G → fastboot). Skipping super.img left a prior stamp's metadata
        # while system*.img were refreshed (bisect mismatch).
        system.img|system_ext.img|product.img|vendor.img|vendor_dlkm.img|system_dlkm.img|super.img|super_empty.img|vbmeta.img|boot.img|init_boot.img|vendor_boot.img|vendor_kernel_boot.img|dtbo.img|pvmfw.img|avb_pkmd.bin|init.insmod.akita.cfg|init.insmod.komodo.cfg|init.insmod.rango.cfg|init.insmod.caiman.cfg|init.insmod.comet.cfg|init.insmod.tegu.cfg|init.insmod.stallion.cfg|init.insmod.shiba.cfg|init.insmod.husky.cfg|init.insmod.frankel.cfg|init.insmod.blazer.cfg|init.insmod.mustang.cfg)
            log "  force re-downloading $f (logical/boot/vbmeta/super/insmod — always fresh)..."
            rm -f "$LOCAL_WORK_DIR/$f"
            ;;
    esac
    if [[ -f "$LOCAL_WORK_DIR/$f" ]]; then
        log "  $f already present, skipping download"
        continue
    fi
    log "  downloading $f..."
    # Optional images may be legitimately absent from a given bundle (e.g. the
    # stock-control bundle ships no super.img / no vendor_boot_diag.img). Warn
    # and skip rather than die so the flash can proceed with what's present.
    if [[ "$f" == "super.img" || "$f" == "vendor_boot_diag.img" ]]; then
        scp -q "$REMOTE_HOST:$REMOTE_BUILD_DIR/$f" "$LOCAL_WORK_DIR/$f" 2>/dev/null \
            || { warn "optional $f not on server — skipping"; continue; }
    elif [[ "$f" == "avb_pkmd.bin" ]]; then
        scp -q "$REMOTE_HOST:$REMOTE_KEY_DIR/$f" "$LOCAL_WORK_DIR/$f" \
            || die "failed to download $f from $REMOTE_KEY_DIR"
    else
        scp -q "$REMOTE_HOST:$REMOTE_BUILD_DIR/$f" "$LOCAL_WORK_DIR/$f" \
            || die "failed to download $f"
    fi
done
log "All images downloaded ✓"

# Verify all files exist (skip optional ones that may be intentionally absent)
for f in "${ALL_DOWNLOADS[@]}"; do
    if [[ "$f" == "super.img" || "$f" == "vendor_boot_diag.img" ]]; then
        [[ -f "$LOCAL_WORK_DIR/$f" ]] || warn "optional $f absent — continuing without it"
        continue
    fi
    [[ -f "$LOCAL_WORK_DIR/$f" ]] || die "$f missing after download!"
done

# -----------------------------------------------------------------------------
# Step 2 — Flash bootloader (both slots) + radio + GrapheneOS firmware cleanup
# -----------------------------------------------------------------------------
step "2/8  Flash bootloader (A/B) + radio + AVB key + firmware cleanup"

# Dual-slot bootloader (GrapheneOS flash-all) — required for tokay/akita/rango.
flash_bootloader_ab_both_slots

log "Flashing radio..."
"$FASTBOOT" flash radio "$LOCAL_WORK_DIR/radio.img" \
    || die "failed to flash radio"
log "Rebooting to fastboot after radio (GrapheneOS flash-all)..."
"$FASTBOOT" reboot-bootloader 2>/dev/null || true
wait_for_fastboot "after radio" "$FASTBOOT_WAIT_SECS" \
    || die "device lost after radio flash"

# AVB custom key — official position: immediately after radio, BEFORE OS
# images (generate-factory-images-common.sh: erase avb_custom_key → flash
# avb_custom_key avb_pkmd.bin). Loud on failure: without it verified boot
# cannot trust GuardTalkOS keys (vbmeta disable flags are still applied).
[[ -f "$LOCAL_WORK_DIR/avb_pkmd.bin" ]] || die "avb_pkmd.bin missing at $LOCAL_WORK_DIR"
log "Erase + flash avb_custom_key (GrapheneOS official position — before OS images)..."
"$FASTBOOT" erase avb_custom_key \
    || warn "erase avb_custom_key failed (non-fatal — may not exist on some bootloaders)"
if "$FASTBOOT" flash avb_custom_key "$LOCAL_WORK_DIR/avb_pkmd.bin"; then
    log "avb_custom_key flashed ✓"
else
    if [[ "${ALLOW_AVB_KEY_FAIL:-0}" == "1" ]]; then
        warn "avb_custom_key flash FAILED — ALLOW_AVB_KEY_FAIL=1; continuing (vbmeta disable flags still applied)"
    else
        die "avb_custom_key flash FAILED — GuardTalkOS AVB key NOT trusted. Set ALLOW_AVB_KEY_FAIL=1 to continue anyway."
    fi
fi

# UART / FIPS / DPM — cite script/generate-release.sh device flags.
apply_grapheneos_firmware_cleanup

# Re-query slot (A/B dance + radio reboot may have changed it)
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
TARGET_SLOT="$CURRENT_SLOT"
log "current-slot after bootloader/radio/cleanup: ${CURRENT_SLOT:-unknown}"

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

if [[ -n "${CURRENT_SLOT:-}" ]]; then
    log "Resetting active slot to $CURRENT_SLOT (restores slot-retry-count)..."
    "$FASTBOOT" --set-active="$CURRENT_SLOT" 2>/dev/null \
        || warn "set-active failed (continuing)"
fi

# -----------------------------------------------------------------------------
# Step 4 — Enter fastbootd (BEFORE flashing GuardTalk boot images)
# -----------------------------------------------------------------------------
step "4/8  Enter fastbootd (userspace) — before GuardTalk boot flash"

# fastbootd is REQUIRED to wipe-super + flash logical partitions. It is a
# userspace binary reached via `fastboot reboot fastboot`, which boots the
# *currently installed* boot/init_boot/vendor_boot chain. If we flash
# GuardTalk boot first and that chain dies at the Google G logo (laguna),
# fastbootd never starts and system/vendor are never updated → permanent loop.
#
# Order fix: enter fastbootd with the boot chain already on the device (or
# stock rescue on laguna), flash logical, THEN flash GuardTalk boot + vbmeta.

wait_for_fastbootd() {
    local label="${1:-fastbootd}"
    local max_secs="${2:-$FASTBOOTD_WAIT_SECS}"
    local attempts=$(( (max_secs + 1) / 2 ))
    local i FB_MODE
    log "Waiting for fastbootd [$label] (up to ${max_secs}s)..."
    for i in $(seq 1 "$attempts"); do
        sleep 2
        FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
        DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
        if [[ -n "$DEVICES" && "$FB_MODE" == "yes" ]]; then
            log "fastbootd ready after ${i} attempts (is-userspace=yes) [$label]"
            return 0
        fi
        # If device fell back to bootloader (G-logo reboot), stop waiting early.
        if [[ -n "$DEVICES" && "$FB_MODE" == "no" && "$i" -ge 5 ]]; then
            warn "Device back in bootloader (is-userspace=no) — fastbootd boot failed [$label]"
            return 1
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastbootd... (${i}/${attempts}) [is-userspace=${FB_MODE:-unknown}]"
    done
    return 1
}

ensure_in_bootloader() {
    local FB_MODE
    FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" && "$FB_MODE" != "yes" ]]; then
        return 0
    fi
    # Device missing or stuck in fastbootd — try reboot-bootloader / wait.
    if [[ -n "$DEVICES" && "$FB_MODE" == "yes" ]]; then
        log "Currently in fastbootd — rebooting to bootloader..."
        "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    fi
    wait_for_fastboot "ensure bootloader" 60 \
        || die "Could not get device into bootloader. Hold vol-down + power, then re-run."
}

# Downloads stock rescue imgs into LOCAL_WORK_DIR/<device>-rescue.
# Sets RESCUE_LOCAL (does not print the path — logs are on stderr).
download_rescue_boot() {
    local dest="$LOCAL_WORK_DIR/${FLASH_DEVICE:-device}-rescue"
    local f
    [[ -n "${REMOTE_RESCUE_DIR:-}" ]] \
        || die "REMOTE_RESCUE_DIR unset — cannot download stock rescue boot for '${FLASH_DEVICE:-unknown}'"
    mkdir -p "$dest"
    log "Downloading stock factory rescue boot for ${FLASH_DEVICE:-device} from $REMOTE_RESCUE_DIR ..."
    for f in "${RESCUE_IMGS[@]}"; do
        log "  rescue: $f"
        scp -q "$REMOTE_HOST:$REMOTE_RESCUE_DIR/$f" "$dest/$f" \
            || die "failed to download rescue $f from $REMOTE_RESCUE_DIR"
        [[ -f "$dest/$f" ]] || die "rescue file missing after scp: $dest/$f"
    done
    RESCUE_LOCAL="$dest"
    log "Rescue imgs ready in $RESCUE_LOCAL"
}

# Temporarily flash stock factory boot so `reboot fastboot` can reach fastbootd.
flash_rescue_boot_chain() {
    local dest slot f part
    download_rescue_boot
    dest="${RESCUE_LOCAL:?rescue local dir unset}"
    slot="${CURRENT_SLOT:-a}"
    log "Flashing STOCK rescue boot chain (slot $slot) to enter fastbootd..."
    for f in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img; do
        part="${f%.img}"
        [[ -f "$dest/$f" ]] || die "rescue image missing: $dest/$f"
        log "  rescue flash $part (slot $slot) ← $dest/$f"
        "$FASTBOOT" --slot "$slot" flash "$part" "$dest/$f" \
            || die "rescue flash $part failed"
    done
    log "  rescue flash dtbo ← $dest/dtbo.img"
    "$FASTBOOT" flash dtbo "$dest/dtbo.img" || die "rescue flash dtbo failed"
    # Disable verity/verification so rescue boot is not rejected on unlocked GT keys.
    flash_vbmeta_img vbmeta "$dest/vbmeta.img" --slot "$slot"
    flash_vbmeta_img vbmeta_system "$dest/vbmeta.img"
    flash_vbmeta_img vbmeta_vendor "$dest/vbmeta.img"
    "$FASTBOOT" --set-active="$slot" 2>/dev/null || true
    log "Rescue boot chain ready ✓"
}

# Automatic boot-failure harvest (RQ5 one-click): breadcrumbs while still in the
# bootloader, then reflash the stock rescue chain, boot recovery, pull the failed
# boot's console from pstore (ramoops), and print the discriminator lines that
# name the failing component. Ends with the device back in the bootloader, ready
# for the next flash. Disable with AUTO_HARVEST=0 (recovery part: AUTO_RECOVERY_HARVEST=0).
auto_harvest_on_failure() {
    if [[ "${AUTO_HARVEST:-1}" != "1" ]]; then
        log "AUTO_HARVEST=0 — skipping automatic harvest"
        return 0
    fi
    HARVEST_DIR="$LOCAL_WORK_DIR/harvest-${FLASH_DEVICE:-device}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$HARVEST_DIR"
    log "Auto-harvest → $HARVEST_DIR"

    # 1. Bootloader-resident captures (device is already in fastboot; RAM intact).
    "$FASTBOOT" oem dmesg > "$HARVEST_DIR/oem-dmesg.txt" 2>&1 || true
    "$FASTBOOT" oem ramdump klog > "$HARVEST_DIR/oem-ramdump-klog.txt" 2>&1 || true
    local f
    for f in command status recovery stage; do
        "$FASTBOOT" oem bcd read "$f" > "$HARVEST_DIR/bcd-$f.txt" 2>&1 || true
    done
    log "  breadcrumbs captured (oem dmesg / ramdump klog / bcd ×4)"

    # Print oem-dmesg discriminator immediately — this is the useful signal.
    if [[ -s "$HARVEST_DIR/oem-dmesg.txt" ]]; then
        grep -E 'Reboot mode|AB Decisions|exitcode|0xbaba|fastboot enter|0xfc|0x7f00|0x00000100|Attempted to kill' \
            "$HARVEST_DIR/oem-dmesg.txt" > "$HARVEST_DIR/oem-discriminator.txt" 2>/dev/null || true
        if [[ -s "$HARVEST_DIR/oem-discriminator.txt" ]]; then
            warn "=== OEM-DMESG DISCRIMINATOR ==="
            while IFS= read -r line; do warn "  $line"; done < "$HARVEST_DIR/oem-discriminator.txt"
            warn "=== end (full: $HARVEST_DIR/oem-dmesg.txt) ==="
        fi
    fi

    # 1b. Best-effort upload of the harvest to the build host (T-PORT-HARVEST-UPLOAD).
    # Rationale: the one-line discriminator above is only actionable if the FULL
    # log is readable where the build tree lives. Without this, every failure
    # forces a manual scp round-trip from the Operator's laptop before any agent
    # can analyse it. Never fatal — a failed upload must not abort the summary.
    if [[ -n "${REMOTE_HOST:-}" && -n "${REMOTE_TREE:-}" ]]; then
        local _hup_dest="${REMOTE_TREE}/runtime/harvests"
        if ssh -n "$REMOTE_HOST" "mkdir -p '$_hup_dest'" >/dev/null 2>&1 \
           && scp -q -r "$HARVEST_DIR" "$REMOTE_HOST:$_hup_dest/" >/dev/null 2>&1; then
            log "  harvest uploaded → $REMOTE_HOST:$_hup_dest/$(basename "$HARVEST_DIR")"
        else
            warn "  harvest upload failed — logs are local only at $HARVEST_DIR"
        fi
    fi

    # 2. Ramoops needs a kernel boot that extracts pstore — stock recovery via
    # the rescue chain is the reliable vehicle (fastbootd has no dmesg/pstore path).
    # Laguna family widened in T-PORT-LAGUNA-HYBRID (R4): a failed laguna boot
    # previously yielded no kernel log at all. akita keeps its pre-existing arm.
    case "${FLASH_DEVICE:-}" in
        akita|rango|frankel|blazer|mustang) : ;;
        *)
            warn "no rescue profile for '${FLASH_DEVICE:-unknown}' — skipping pstore harvest"
            return 0
            ;;
    esac
    # laguna production ABL (rango|frankel|blazer|mustang): oem bcd write is
    # accepted but NOT honored. Recovery harvest parks the phone on "No command"
    # until Power+VolUp. oem-dmesg already classifies 0xfc / 0x7f00 / 0x100.
    # Default skip for the WHOLE laguna platform (widening the harvest without
    # this guard would trade one bad state for another). Opt in:
    # AUTO_RECOVERY_HARVEST=1
    if is_laguna_device "${FLASH_DEVICE:-}"; then
        AUTO_RECOVERY_HARVEST="${AUTO_RECOVERY_HARVEST:-0}"
    fi
    if [[ "${AUTO_RECOVERY_HARVEST:-1}" != "1" ]]; then
        log "AUTO_RECOVERY_HARVEST=0 — skipping recovery pstore pull (device stays in fastboot)"
        return 0
    fi
    # Subshell: a die inside the rescue flash must not abort the harvest summary.
    if ! ( flash_rescue_boot_chain ) >>"$HARVEST_DIR/rescue-reflash.log" 2>&1; then
        warn "rescue reflash failed (see $HARVEST_DIR/rescue-reflash.log) — skipping pstore"
        return 1
    fi
    log "  rescue chain reflashed — booting recovery for pstore pull"
    "$FASTBOOT" oem bcd write command boot-recovery >>"$HARVEST_DIR/bcd-write.log" 2>&1 || true
    "$FASTBOOT" reboot >>"$HARVEST_DIR/reboot.log" 2>&1 || true

    # 3. Wait for recovery adbd (no USB-debugging authorization needed in recovery).
    local i secs="${RECOVERY_ADB_WAIT_SECS:-120}"
    local got_adb=""
    for ((i=1; i<=secs; i++)); do
        sleep 1
        if "$ADB" devices 2>/dev/null | grep -Eq '[[:space:]](device|recovery|sideload)$'; then
            got_adb=1
            break
        fi
        # Rescue chain + GT super may itself 0xfc back to the bootloader — stop early.
        if [[ -n "$("$FASTBOOT" devices 2>/dev/null)" ]]; then
            local fb_mode
            fb_mode="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
            if [[ "$fb_mode" == "no" && $i -ge 20 ]]; then
                warn "rescue boot returned to bootloader — BCB recovery entry not honored."
                warn "MANUAL: buttons → Recovery mode → 'No command' → Power+VolUp, then:"
                warn "  $ADB shell 'cat /sys/fs/pstore/console-ramoops-0' | tee $HARVEST_DIR/console-ramoops-0.txt"
                return 1
            fi
        fi
        [[ $((i % 20)) -eq 0 ]] && log "  still waiting for recovery adb... (${i}/${secs}s)"
    done
    if [[ -z "$got_adb" ]]; then
        warn "no recovery adb within ${secs}s. MANUAL: Recovery mode (buttons), then:"
        warn "  $ADB shell 'cat /sys/fs/pstore/console-ramoops-0' | tee $HARVEST_DIR/console-ramoops-0.txt"
        return 1
    fi

    # 4. Pull pstore (recovery adbd is root on userdebug; `adb root` is a no-op otherwise).
    "$ADB" root >/dev/null 2>&1 || true
    sleep 2
    "$ADB" wait-for-device >/dev/null 2>&1 || true
    "$ADB" shell 'ls -la /sys/fs/pstore/' > "$HARVEST_DIR/pstore-ls.txt" 2>&1 || true
    "$ADB" shell 'cat /sys/fs/pstore/console-ramoops-0 2>/dev/null' > "$HARVEST_DIR/console-ramoops-0.txt"
    "$ADB" shell 'cat /sys/fs/pstore/dmesg-ramoops-0 2>/dev/null' > "$HARVEST_DIR/dmesg-ramoops-0.txt"
    "$ADB" shell 'cat /sys/fs/pstore/pmsg-ramoops-0 2>/dev/null' > "$HARVEST_DIR/pmsg-ramoops-0.txt"
    "$ADB" shell 'mkdir -p /m && mount -t ext4 /dev/block/bootdevice/by-name/metadata /m 2>/dev/null && ls -laR /m/apex 2>/dev/null' \
        > "$HARVEST_DIR/metadata-apex.txt" 2>&1 || true
    log "  pstore pulled → $HARVEST_DIR"

    # 5. Discriminator scan (RQ4): name the failing component if the console has it.
    if [[ -s "$HARVEST_DIR/console-ramoops-0.txt" ]]; then
        grep -Ei 'Failed to activate|Loop device|loop-control|Coldboot|cold_boot|avc: denied|apexd|panic|Attempted to kill init|reboot_on_failure|bootstrap-apexd' \
            "$HARVEST_DIR/console-ramoops-0.txt" > "$HARVEST_DIR/discriminator.txt" 2>/dev/null || true
        if [[ -s "$HARVEST_DIR/discriminator.txt" ]]; then
            warn "=== DISCRIMINATOR LINES (failed boot console) ==="
            while IFS= read -r line; do warn "  $line"; done < "$HARVEST_DIR/discriminator.txt"
            warn "=== end discriminator (full console: $HARVEST_DIR/console-ramoops-0.txt) ==="
        else
            warn "console captured; no apexd/loop/avc lines matched — inspect $HARVEST_DIR/console-ramoops-0.txt"
        fi
    else
        warn "console-ramoops-0 EMPTY — ramoops did not survive the ABL handoff."
        warn "Next evidence path: UART — fastboot oem uart enable + USB-serial (115200 8N1)."
    fi

    # 6. Leave the device in the bootloader, ready for the next one-command flash.
    "$ADB" reboot bootloader >/dev/null 2>&1 || true
    sleep 5
    return 0
}

# -----------------------------------------------------------------------------
# Opt-in post-flash debug capture (CAPTURE_LOGS=1) — best-effort, never fatal.
# -----------------------------------------------------------------------------
# Mirrors auto_harvest_on_failure's timestamped-dir pattern, but is also safe to
# run on a boot that briefly succeeds (the observed failure is: adb appears,
# then the device falls back to fastboot seconds later). Nothing here may die()
# — a failed capture step logs a warning and continues (Law 3 / Law 9). Callers
# guard on CAPTURE_LOGS, and capture_dir_init is a no-op when not opted in, so
# the default flash path never invokes capture.
capture_dir_init() {
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0
    [[ -n "${CAPTURE_DIR:-}" ]] && return 0
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)"
    CAPTURE_DIR="$LOCAL_WORK_DIR/flash-capture-${FLASH_DEVICE:-device}-${stamp}"
    if mkdir -p "$CAPTURE_DIR" 2>/dev/null; then
        log "CAPTURE_LOGS=1 — post-flash debug evidence → $CAPTURE_DIR"
    else
        warn "could not create capture dir '$CAPTURE_DIR' — capture disabled for this run"
        CAPTURE_DIR=""
    fi
    return 0
}

# capture_run <outfile> <cmd...>: run one capture step; never fatal.
capture_run() {
    local outfile="$1"
    shift
    [[ -n "${CAPTURE_DIR:-}" ]] || return 0
    if { "$@" ; } >"$outfile" 2>&1; then
        return 0
    fi
    warn "capture: '$*' failed (non-fatal; partial output in $(basename "$outfile"))"
    return 0
}

# Bootloader transport: oem dmesg, BCB reads, slot retry/unbootable, getvar all.
capture_fastboot_snapshot() {
    local label="${1:-fastboot}"
    local f
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0
    capture_dir_init
    [[ -n "${CAPTURE_DIR:-}" ]] || return 0
    log "  capture[$label]: fastboot/bootloader transport"
    capture_run "$CAPTURE_DIR/fastboot-$label-oem-dmesg.txt" "$FASTBOOT" oem dmesg
    for f in command status recovery stage; do
        capture_run "$CAPTURE_DIR/fastboot-$label-bcd-$f.txt" "$FASTBOOT" oem bcd read "$f"
    done
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-retry-count-a.txt" "$FASTBOOT" getvar slot-retry-count:a
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-unbootable-a.txt" "$FASTBOOT" getvar slot-unbootable:a
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-retry-count-b.txt" "$FASTBOOT" getvar slot-retry-count:b
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-unbootable-b.txt" "$FASTBOOT" getvar slot-unbootable:b
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-all.txt" "$FASTBOOT" getvar all
    capture_run "$CAPTURE_DIR/fastboot-$label-devices.txt" "$FASTBOOT" devices
    log "  capture[$label]: fastboot snapshot done"
    return 0
}

# Android transport: logcat, props, dumpsys, pstore. Logcat is captured first
# so a subsequent adbd reset cannot lose the interesting window.
capture_adb_snapshot() {
    local label="${1:-adb}"
    local prop f
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0
    capture_dir_init
    [[ -n "${CAPTURE_DIR:-}" ]] || return 0
    if ! "$ADB" shell true >/dev/null 2>&1; then
        warn "  capture[$label]: adb not reachable — skipping adb snapshot"
        return 0
    fi
    log "  capture[$label]: adb/Android transport"
    capture_run "$CAPTURE_DIR/adb-$label-logcat-d.txt" "$ADB" logcat -d
    capture_run "$CAPTURE_DIR/adb-$label-logcat-errors.txt" "$ADB" logcat -d '*:E'
    : >"$CAPTURE_DIR/adb-$label-getprop-key.txt" 2>/dev/null || true
    for prop in \
        ro.build.type ro.build.tags ro.debuggable ro.boot.verifiedbootstate \
        ro.boot.slot_suffix ro.boot.bootreason ro.product.device \
        ro.guardtalk.build ro.guardtalk.version; do
        {
            echo "### $prop"
            "$ADB" shell getprop "$prop" 2>&1 || true
        } >>"$CAPTURE_DIR/adb-$label-getprop-key.txt" 2>&1 || true
    done
    capture_run "$CAPTURE_DIR/adb-$label-getprop-all.txt" "$ADB" shell getprop
    capture_run "$CAPTURE_DIR/adb-$label-dumpsys-exit-info.txt" "$ADB" shell dumpsys activity exit-info
    capture_run "$CAPTURE_DIR/adb-$label-dumpsys-lastanr.txt" "$ADB" shell dumpsys activity lastanr
    capture_run "$CAPTURE_DIR/adb-$label-dumpsys-services.txt" "$ADB" shell dumpsys -l
    capture_run "$CAPTURE_DIR/adb-$label-pstore-ls.txt" "$ADB" shell ls -la /sys/fs/pstore/
    for f in console-ramoops-0 dmesg-ramoops-0 pmsg-ramoops-0; do
        capture_run "$CAPTURE_DIR/adb-$label-$f.txt" "$ADB" shell cat "/sys/fs/pstore/$f"
    done
    log "  capture[$label]: adb snapshot done"
    return 0
}

# laguna (rango|frankel|blazer|mustang): NEVER try the on-device boot chain
# first. After a failed GuardTalk flash it is often a G-logo reboot loop;
# `reboot fastboot` just restarts that loop and the script appears stuck.
# Always install stock factory rescue boot first, then enter fastbootd, flash
# logical, and only then install GuardTalk boot.
case "${FLASH_DEVICE:-}" in
    rango|frankel|blazer|mustang)
    log "${FLASH_DEVICE}: flashing STOCK rescue boot BEFORE fastbootd (avoids G-logo loop from prior GT boot)..."
    ensure_in_bootloader
    CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
    TARGET_SLOT="$CURRENT_SLOT"
    flash_rescue_boot_chain
    log "Rebooting to fastbootd with stock rescue boot..."
    log "(Screen may show Google G briefly — should land in fastbootd, not loop.)"
    "$FASTBOOT" reboot fastboot 2>/dev/null || true
    wait_for_fastbootd "${FLASH_DEVICE}-rescue" "$FASTBOOTD_WAIT_SECS" \
        || die "FAILED to enter fastbootd with stock rescue boot.
Hold vol-down+power for bootloader, then:
  scp $REMOTE_HOST:$REMOTE_RESCUE_DIR/{boot,init_boot,vendor_boot,vendor_kernel_boot,dtbo,vbmeta,pvmfw}.img .
  fastboot --slot a flash boot boot.img
  fastboot --slot a flash init_boot init_boot.img
  fastboot --slot a flash vendor_boot vendor_boot.img
  fastboot --slot a flash vendor_kernel_boot vendor_kernel_boot.img
  fastboot --disable-verity --disable-verification --slot a flash vbmeta vbmeta.img
  fastboot reboot fastboot
  # when is-userspace=yes, re-run this script"
    ;;
    *)
    log "Rebooting to fastbootd (using boot chain currently on device)..."
    "$FASTBOOT" reboot fastboot 2>/dev/null || true
    if ! wait_for_fastbootd "current-boot" "$FASTBOOTD_WAIT_SECS"; then
        die "FAILED to enter fastbootd. Logical partitions cannot be flashed in bootloader mode.
Device may be boot-looping. Get to bootloader (vol-down+power) and re-run.
Restore a working boot image first if needed."
    fi
    ;;
esac

# -----------------------------------------------------------------------------
# Step 5 — Flash logical partitions (super) via fastbootd
# -----------------------------------------------------------------------------
step "5/8  Flash logical partitions (super) via fastbootd"

FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
[[ "$FB_MODE" == "yes" ]] || die "Not in fastbootd (is-userspace=${FB_MODE:-unknown}) — aborting logical flash"

# Preferred: flash the canonical super.img built by lpmake. Its metadata table
# exactly matches the GT logical images, so first-stage init's liblp can build
# the dm-linear devices and mount /system. Flashing 6 logical partitions
# individually after wipe-super leaves fastbootd-generated metadata that the
# (factory) first-stage init could not resolve -> /system never mounted ->
# execv(/system/bin/init) failed with ENOENT -> "kill init! exitcode=0x7f00".
if [[ -f "$LOCAL_WORK_DIR/super.img" ]]; then
    log "Flashing canonical super.img (lpmake metadata matches GT logical images)..."
    "$FASTBOOT" flash super "$LOCAL_WORK_DIR/super.img" \
        || die "failed to flash super.img"
    log "super.img flashed ✓"
else
    warn "super.img not found in bundle — falling back to wipe-super + per-partition flash"
    log "Wiping super partition..."
    "$FASTBOOT" wipe-super "$LOCAL_WORK_DIR/super_empty.img" \
        || die "wipe-super failed. Ensure fastbootd (is-userspace=yes), then: fastboot wipe-super super_empty.img"

    for img in "${LOGICAL_IMAGES[@]}"; do
        part="${img%.img}"
        log "  flash $part (logical)"
        "$FASTBOOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part"
    done
    log "Logical partitions flashed ✓"
fi

log "Rebooting back to fastboot (bootloader)..."
"$FASTBOOT" reboot-bootloader 2>/dev/null || true
wait_for_fastboot "after logical" 60 \
    || die "device lost when returning to bootloader after logical flash"

CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
TARGET_SLOT="$CURRENT_SLOT"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# -----------------------------------------------------------------------------
# Step 6 — Flash GuardTalk physical A/B + dtbo
# -----------------------------------------------------------------------------
step "6/8  Flash GuardTalk boot chain (slot ${TARGET_SLOT:-a}) + dtbo"

if [[ "$GT_BOOT_CHAIN" == "hybrid" ]]; then
    log "GT_BOOT_CHAIN=hybrid — SKIPPING GuardTalk A/B boot-chain flash (step 6)."
    log "  Stock factory rescue boot chain from step 4 stays installed:"
    log "  boot/init_boot/vendor_boot/vendor_kernel_boot/pvmfw/dtbo already on device."
    log "  Hybrid logical set from step 5 is retained; step-7 vbmeta pass still runs."
else
    for img in "${AB_IMAGES[@]}"; do
        part="${img%.img}"
        log "  flash $part (slot ${TARGET_SLOT:-a})"
        "$FASTBOOT" --slot "${TARGET_SLOT:-a}" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part"
    done
    log "  flash dtbo"
    "$FASTBOOT" flash dtbo "$LOCAL_WORK_DIR/dtbo.img" || die "failed to flash dtbo"
    log "GuardTalk boot chain flashed ✓"
fi

# -----------------------------------------------------------------------------
# Step 7 — Single vbmeta pass + set-active
# -----------------------------------------------------------------------------
step "7/8  vbmeta pass (single, after boot chain) + set-active"

log "Flashing vbmeta/vbmeta_system/vbmeta_vendor once (--disable-verity --disable-verification)..."
if [[ -n "${CURRENT_SLOT:-}" ]]; then
    flash_vbmeta_partition vbmeta --slot "$CURRENT_SLOT"
else
    flash_vbmeta_partition vbmeta
fi
flash_vbmeta_partition vbmeta_system
flash_vbmeta_partition vbmeta_vendor

if [[ -n "${CURRENT_SLOT:-}" ]]; then
    log "Setting active slot to $CURRENT_SLOT (resets slot-retry-count)..."
    "$FASTBOOT" --set-active="$CURRENT_SLOT" 2>/dev/null \
        || warn "set-active failed (manual: fastboot --set-active=$CURRENT_SLOT)"
fi

# -----------------------------------------------------------------------------
# Step 8 — Reboot (+ optional insmod push)
# -----------------------------------------------------------------------------
step "8/8  Reboot"

log "Rebooting device..."
"$FASTBOOT" reboot || warn "reboot returned non-zero (device may still be rebooting)"

# Poll for adb (boot OK), unauthorized adb, or return to bootloader (G→fastboot).
# Never fall through into a blind 180s adb wait when the device never enumerates.
BOOT_WATCH_SECS="${BOOT_WATCH_SECS:-120}"
log "Watching boot for up to ${BOOT_WATCH_SECS}s (adb=OK, unauthorized=prompt, fastboot=fail)..."
WATCH_ITERS="$BOOT_WATCH_SECS"
if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
    # Ensure the post-adb fallback window is fully covered even if adb appears late.
    WATCH_ITERS=$((BOOT_WATCH_SECS + CAPTURE_POST_ADB_SECS))
    capture_dir_init
    log "CAPTURE_LOGS=1 — will keep watching up to ${CAPTURE_POST_ADB_SECS}s after adb first appears (fallback capture)"
fi
boot_outcome=""
post_adb_seen=0
post_adb_start=0
post_adb_fallback=0
for i in $(seq 1 "$WATCH_ITERS"); do
    sleep 1
    if command -v "$ADB" >/dev/null 2>&1; then
        adb_list="$("$ADB" devices 2>/dev/null || true)"
        if echo "$adb_list" | awk 'NR>1 && $2=="device" {found=1} END{exit !found}'; then
            if [[ "$boot_outcome" != "adb" ]]; then
                boot_outcome="adb"
                log "adb online after ${i}s — Android reached"
                if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
                    post_adb_seen=1
                    post_adb_start="$i"
                    capture_adb_snapshot "adb-online-${i}s"
                    log "  CAPTURE_LOGS=1 — watching ${CAPTURE_POST_ADB_SECS}s more for a fallback to fastboot..."
                fi
            fi
            # Default path: exit at first adb (unchanged). Capture mode: keep
            # watching so a later adb → fastboot fallback is recorded.
            if [[ "${CAPTURE_LOGS:-0}" == "1" && "$post_adb_seen" == "1" \
                  && $((i - post_adb_start)) -lt "$CAPTURE_POST_ADB_SECS" ]]; then
                :
            else
                break
            fi
        fi
        if echo "$adb_list" | awk 'NR>1 && $2=="unauthorized" {found=1} END{exit !found}'; then
            boot_outcome="unauthorized"
            log "adb unauthorized after ${i}s — Android up; accept RSA prompt on device"
            break
        fi
        if echo "$adb_list" | awk 'NR>1 && $2=="recovery" {found=1} END{exit !found}'; then
            boot_outcome="recovery"
            log "device in adb recovery after ${i}s"
            break
        fi
    fi
    DEVICES_AFTER="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES_AFTER" ]]; then
        FB_MODE_AFTER="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
        if [[ "${FB_MODE_AFTER:-}" != "yes" ]]; then
            sleep 1
            if [[ -n "$("$FASTBOOT" devices 2>/dev/null || true)" ]]; then
                boot_outcome="fastboot"
                log "Device back in fastboot after ${i}s (is-userspace=${FB_MODE_AFTER:-unknown})"
                if [[ "$post_adb_seen" == "1" ]]; then
                    post_adb_fallback=1
                    warn "POST-ADB FALLBACK RECORDED: adb was online at ${post_adb_start}s, device returned to fastboot at ${i}s"
                fi
                if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
                    capture_fastboot_snapshot "fallback-${i}s"
                fi
                break
            fi
        fi
    fi
    [[ $((i % 10)) -eq 0 ]] && log "  still watching boot... (${i}/${WATCH_ITERS}s)"
done

if [[ "${CAPTURE_LOGS:-0}" == "1" && "$post_adb_seen" == "1" \
      && "$post_adb_fallback" == "0" && "$boot_outcome" == "adb" ]]; then
    log "CAPTURE_LOGS=1 — adb stayed up for the ${CAPTURE_POST_ADB_SECS}s post-adb window (no fallback observed)"
fi

if [[ "$boot_outcome" == "fastboot" ]]; then
    warn "Boot failed (G logo → fastboot). Logical partitions ARE flashed."
    warn "Skipping adb init.insmod push — no Android yet."
    warn "IMMEDIATE: restoring slot retries, then AUTOMATIC harvest (rescue → recovery → pstore)..."
    "$FASTBOOT" --set-active=a 2>/dev/null || true
    # One-click harvest: breadcrumbs + failed-boot console via ramoops + verdict lines.
    auto_harvest_on_failure || true
    warn "Classify from oem dmesg (do not invent PASS):"
    warn "  exitcode=0x00007f00     → init/exec kill (status 127; historical)"
    warn "  exitcode=0x00000100     → init exit status 1 (KP; 141438 stockinit class)"
    warn "  Reboot mode: 0xfc       → apexd-bootstrap reboot_on_failure (~18s)"
    warn "  Reboot mode: 0x0 + 0xbaba → Kernel PANIC (normal mode; not bootloader 0xfc)"
    warn "Bisect stamps: keep REMOTE_BUILD_DIR set (do not assume rango-latest)."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS flash INCOMPLETE — boot failure after G"
    echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
    echo "  Remote:   $REMOTE_BUILD_DIR"
    echo "  Harvest:  ${HARVEST_DIR:-<none>} (console-ramoops-0.txt = failed boot)"
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] && echo "  Capture:  ${CAPTURE_DIR:-<none>} (CAPTURE_LOGS=1)"
    echo "  Classes:  0x7f00 | 0x00000100 | 0xfc | 0xbaba/mode 0x0"
    echo "============================================================"
    exit 2
fi

if [[ "$boot_outcome" == "unauthorized" ]]; then
    warn "Android reached but adb unauthorized — accept the prompt, then re-run insmod push or enable USB debugging."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS flash OK (adb unauthorized)"
    echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
    echo "  Remote:   $REMOTE_BUILD_DIR"
    echo "============================================================"
    exit 0
fi

if [[ "$boot_outcome" != "adb" ]]; then
    warn "Neither adb nor fastboot within ${BOOT_WATCH_SECS}s."
    warn "Likely stuck at G/bootanimation (not a script hang). Check the phone screen."
    warn "Skipping adb init.insmod push — will not wait ${ADB_WAIT_SECS}s blindly."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS flash INCOMPLETE — no adb after reboot"
    echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
    echo "  Remote:   $REMOTE_BUILD_DIR"
    echo "  Tip:      if screen shows Android/SUW, enable USB debugging / accept adb"
    echo "============================================================"
    exit 3
fi

case "${FLASH_DEVICE:-}" in
    akita|komodo|rango|caiman|comet|tegu|stallion|shiba|husky|frankel|blazer|mustang)
        step "8b/8  Install init.insmod.${FLASH_DEVICE}.cfg via adb"
        install_insmod_cfg_via_adb
        ;;
esac

# Final best-effort adb snapshot (capture mode only; never fatal, never pushes).
if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
    capture_adb_snapshot "final"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  GuardTalkOS flash complete!"
echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
echo "  Remote:   $REMOTE_BUILD_DIR"
echo "  Work dir: $LOCAL_WORK_DIR"
[[ "${CAPTURE_LOGS:-0}" == "1" ]] && echo "  Capture:  ${CAPTURE_DIR:-<none>} (CAPTURE_LOGS=1)"
echo "  First boot may take a few minutes."
echo "============================================================"
