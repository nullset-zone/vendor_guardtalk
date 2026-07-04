#!/bin/bash
#
# GuardTalkOS Release Signing Pipeline
#
# Consumes the GuardTalkOS signing keys (already present on the build server,
# produced by T-SIGN-KEYGEN / generate-signing-keys.sh) plus the unsigned
# target-files / otatools artifacts from `m dist`, and produces a signed,
# lockable release bundle:
#
#   - signed target-files zip
#   - OTA update zip
#   - factory image zip (+ install-optimized zip)
#   - MANIFEST.txt with SHA-256s and key fingerprints
#
# Source-of-truth:
#   - script/generate-release.sh  (apex flag list copied VERBATIM from here)
#   - script/decrypt-keys         (key decryption pattern)
#   - vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md
#   - .agent-comm/dispatch-T-SIGN-PIPELINE.md
#
# Law 4 (Security First): decrypted keys live ONLY in tmpfs (/dev/shm) and are
#   shredded on exit via a trap. No plaintext keys touch persistent disk.
# Law 3 (Error Handling): set -euo pipefail; every step checked.
# Law 10 (Audit Trail): MANIFEST.txt with SHA-256s + key fingerprints.
# Law 22 (Dependency Hygiene): only depends on openssl, unzip, sha256sum,
#   fastboot, and the AOSP releasetools shipped inside the otatools zip.
#
# Usage:
#   ./sign-build.sh \
#       --key-dir     /home/openstatestack/guardtalk-keys/guardtalk \
#       --device      tokay \
#       --build-dir   /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree \
#       --release-out releases/<BUILD_NUMBER> \
#       [--passphrase-env]   # read $GUARDTALK_KEY_PASSPHRASE instead of prompt
#

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
KEY_DIR=""
DEVICE=""
BUILD_DIR=""
RELEASE_OUT=""
PASSPHRASE_ENV=0

# The 9 package keys whose .pk8 + .x509.pem must exist in --key-dir.
# (Matches script/common.sh:136-146 and RUNBOOK.md §2b.)
readonly PACKAGE_KEYS=(
    releasekey
    platform
    shared
    media
    networkstack
    bluetooth
    nfc
    sdk_sandbox
    gmscompat_lib
)

AVB_ALGORITHM="SHA256_RSA4096"

# ── Help ────────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: sign-build.sh --key-dir DIR --device DEV --build-dir DIR --release-out DIR
                     [--passphrase-env]

Signs a GuardTalkOS release for a Pixel device using the operator's keys.

REQUIRED:
  --key-dir DIR       Directory containing the GuardTalkOS signing keys
                      (avb.pem, avb_pkmd.bin, and 9 package .pk8/.x509.pem).
                      Typically /home/openstatestack/guardtalk-keys/guardtalk.
  --device DEV        Device codename. Must be a tokay-class Pixel (tokay, ...).
  --build-dir DIR     Root of the AOSP/GrapheneOS checkout (where `m dist`
                      ran). The otatools zip + target-files zip live under
                      <build-dir>/<release-out>/.
  --release-out PATH  Release output subdirectory (relative to --build-dir or
                      absolute) holding the unsigned target-files zip +
                      otatools zip. Signed outputs land in <release-out>/signed/.

OPTIONAL:
  --passphrase-env    Read the key passphrase from $GUARDTALK_KEY_PASSPHRASE
                      instead of prompting interactively.

ENVIRONMENT:
  GUARDTALK_KEY_PASSPHRASE  Passphrase for the encrypted .pk8 keys (only used
                            with --passphrase-env).

EXIT CODES:
  0  success
  1  generic failure
  2  usage error
EOF
}

# ── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --key-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --key-dir requires a value" >&2; exit 2; }
            KEY_DIR="$2"; shift 2 ;;
        --device)
            [[ $# -ge 2 ]] || { echo "ERROR: --device requires a value" >&2; exit 2; }
            DEVICE="$2"; shift 2 ;;
        --build-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --build-dir requires a value" >&2; exit 2; }
            BUILD_DIR="$2"; shift 2 ;;
        --release-out)
            [[ $# -ge 2 ]] || { echo "ERROR: --release-out requires a value" >&2; exit 2; }
            RELEASE_OUT="$2"; shift 2 ;;
        --passphrase-env)
            PASSPHRASE_ENV=1; shift ;;
        --help|-h)
            usage; exit 0 ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage
            exit 2 ;;
    esac
done

[[ -n "$KEY_DIR"     ]] || { echo "ERROR: --key-dir is required" >&2;     usage; exit 2; }
[[ -n "$DEVICE"      ]] || { echo "ERROR: --device is required" >&2;      usage; exit 2; }
[[ -n "$BUILD_DIR"   ]] || { echo "ERROR: --build-dir is required" >&2;   usage; exit 2; }
[[ -n "$RELEASE_OUT" ]] || { echo "ERROR: --release-out is required" >&2; usage; exit 2; }

# Resolve RELEASE_OUT to an absolute path (relative to BUILD_DIR if not abs).
if [[ "$RELEASE_OUT" != /* ]]; then
    RELEASE_OUT="$BUILD_DIR/$RELEASE_OUT"
fi

# ── Tmpfs workspace for decrypted keys (Law 4) ──────────────────────────────
# Mirror script/decrypt-keys + script/generate-release.sh:18-21.
DECRYPT_DIR="$(mktemp -d /dev/shm/gt-sign.XXXXXX)"
chmod 0700 "$DECRYPT_DIR"
# Reproducible key path for otacerts.zip inside the otatools workdir.
KEYS_SYMLINK=""

cleanup() {
    local rc=$?
    # Shred every file in the tmpfs, then remove the dir. shred -u is best-effort.
    if [[ -n "${DECRYPT_DIR:-}" ]] && [[ -d "$DECRYPT_DIR" ]]; then
        find "$DECRYPT_DIR" -type f -exec shred -u {} + 2>/dev/null || true
        rm -rf "$DECRYPT_DIR"
    fi
    # Remove the otacerts reproducible-path symlink if we created one.
    if [[ -n "${KEYS_SYMLINK:-}" ]] && [[ -L "$KEYS_SYMLINK" ]]; then
        rm -f "$KEYS_SYMLINK"
    fi
    # Clear the passphrase from the environment on the way out.
    unset password 2>/dev/null || true
    exit $rc
}
trap cleanup EXIT INT TERM

# ── Preflight ───────────────────────────────────────────────────────────────
preflight() {
    command -v openssl  >/dev/null || { echo "ERROR: openssl not in PATH" >&2; exit 1; }
    command -v unzip    >/dev/null || { echo "ERROR: unzip not in PATH" >&2;   exit 1; }
    command -v sha256sum>/dev/null || { echo "ERROR: sha256sum not in PATH" >&2; exit 1; }
    command -v shred    >/dev/null || { echo "WARN: shred not in PATH (will use rm)" >&2; }

    [[ -d "$KEY_DIR" ]] || { echo "ERROR: --key-dir '$KEY_DIR' is not a directory" >&2; exit 1; }
    [[ -d "$BUILD_DIR" ]] || { echo "ERROR: --build-dir '$BUILD_DIR' is not a directory" >&2; exit 1; }

    # Validate the 11 expected key files (avb.pem, avb_pkmd.bin, 9 package keys).
    local missing=()
    local k
    for k in "${PACKAGE_KEYS[@]}"; do
        [[ -f "$KEY_DIR/$k.pk8"     ]] || missing+=("$k.pk8")
        [[ -f "$KEY_DIR/$k.x509.pem" ]] || missing+=("$k.x509.pem")
    done
    [[ -f "$KEY_DIR/avb.pem"     ]] || missing+=("avb.pem")
    [[ -f "$KEY_DIR/avb_pkmd.bin" ]] || missing+=("avb_pkmd.bin")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: --key-dir '$KEY_DIR' is missing required key files:" >&2
        printf '  %s\n' "${missing[@]}" >&2
        echo "Expected: avb.pem, avb_pkmd.bin, and 9 package .pk8 + .x509.pem." >&2
        exit 1
    fi

    # Validate build artifacts.
    local target_files="$RELEASE_OUT/$DEVICE-target_files.zip"
    local otatools="$RELEASE_OUT/$DEVICE-otatools.zip"
    [[ -f "$target_files" ]] || {
        echo "ERROR: unsigned target-files zip not found at: $target_files" >&2
        echo "  Run 'm dist' (lunch $DEVICE-cur-user) first, then point --release-out at the output dir." >&2
        exit 1
    }
    [[ -f "$otatools" ]] || {
        echo "ERROR: otatools zip not found at: $otatools" >&2
        echo "  The otatools zip is produced by 'm dist' alongside the target-files zip." >&2
        exit 1
    }

    # tokay-class check (matches generate-release.sh:61 device list).
    if [[ "$DEVICE" != @(tokay|akita|husky|shiba|felix|tangorpro|lynx|cheetah|panther|bluejay|raven|oriole|stallion|tegu|comet|komodo|caiman|rango|mustang|blazer|frankel) ]]; then
        echo "ERROR: device '$DEVICE' is not in the supported list (script/generate-release.sh:56-69)." >&2
        exit 1
    fi
}

# ── Key decryption (replicates script/decrypt-keys) ──────────────────────────
decrypt_keys() {
    echo "→ Decrypting keys into tmpfs: $DECRYPT_DIR"

    # Read the passphrase (or accept empty). Same env-var pattern as decrypt-keys.
    if [[ $PASSPHRASE_ENV -eq 1 ]]; then
        if [[ -z "${GUARDTALK_KEY_PASSPHRASE+x}" ]]; then
            echo "ERROR: --passphrase-env set but \$GUARDTALK_KEY_PASSPHRASE is unset" >&2
            exit 1
        fi
        password="$GUARDTALK_KEY_PASSPHRASE"
    else
        [[ "${password+defined}" = defined ]] || read -rp "Enter key passphrase (empty if none): " -s password
        echo
    fi
    export password

    # Copy the encrypted key set into tmpfs, then decrypt in place.
    cp "$KEY_DIR"/* "$DECRYPT_DIR"/
    chmod 0600 "$DECRYPT_DIR"/*.pk8 "$DECRYPT_DIR"/avb.pem 2>/dev/null || true

    local k
    for k in "${PACKAGE_KEYS[@]}"; do
        if [[ -n "$password" ]]; then
            openssl pkcs8 -inform DER -in "$DECRYPT_DIR/$k.pk8" -passin env:password \
                | openssl pkcs8 -topk8 -outform DER -out "$DECRYPT_DIR/$k.pk8.dec" -nocrypt
            mv "$DECRYPT_DIR/$k.pk8.dec" "$DECRYPT_DIR/$k.pk8"
        else
            openssl pkcs8 -topk8 -inform DER -in "$DECRYPT_DIR/$k.pk8" -outform DER \
                -out "$DECRYPT_DIR/$k.pk8.dec" -nocrypt
            mv "$DECRYPT_DIR/$k.pk8.dec" "$DECRYPT_DIR/$k.pk8"
        fi
    done

    # avb.pem is PEM (not DER) — handle separately, exactly like decrypt-keys:27-33.
    if [[ -n "$password" ]]; then
        openssl pkcs8 -topk8 -in "$DECRYPT_DIR/avb.pem" -passin env:password \
            -out "$DECRYPT_DIR/avb.pem.dec" -nocrypt
        mv "$DECRYPT_DIR/avb.pem.dec" "$DECRYPT_DIR/avb.pem"
    else
        openssl pkcs8 -topk8 -in "$DECRYPT_DIR/avb.pem" -out "$DECRYPT_DIR/avb.pem.dec" -nocrypt
        mv "$DECRYPT_DIR/avb.pem.dec" "$DECRYPT_DIR/avb.pem"
    fi
    chmod 0600 "$DECRYPT_DIR"/*.pk8 "$DECRYPT_DIR"/avb.pem

    # avb_pkmd.bin is a PUBLIC blob — copy as-is, no decryption.
    # (Already copied above.)

    unset password
}

# ── otatools workspace ──────────────────────────────────────────────────────
setup_otatools() {
    echo "→ Unpacking otatools into: $WORK_DIR"
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    unzip -q "$RELEASE_OUT/$DEVICE-otatools.zip" -d "$WORK_DIR"
    # Make soong ignore Android.bp from the unpacked otatools (generate-release.sh:35).
    touch "$WORK_DIR/.find-ignore"

    # Reproducible key path for otacerts.zip (generate-release.sh:37-39).
    KEYS_SYMLINK="$WORK_DIR/keys"
    ln -s "$DECRYPT_DIR" "$KEYS_SYMLINK"
    # sign_target_files_apks resolves key paths relative to CWD (the build-dir
    # root), NOT relative to $WORK_DIR. Use the absolute symlink path so the
    # keys resolve regardless of CWD.
    REL_KEY_DIR="$KEYS_SYMLINK"

    # Prepend otatools bin/ to PATH so releasetools resolve.
    export PATH="$WORK_DIR/bin:$PATH"
}

# ── Signing ─────────────────────────────────────────────────────────────────
sign_target_files() {
    local target_files_input="$RELEASE_OUT/$DEVICE-target_files.zip"
    local signed_out="$SIGNED_DIR/$DEVICE-target_files-signed.zip"

    echo "→ Signing target-files (this is the long step)..."
    echo "  input : $target_files_input"
    echo "  output: $signed_out"

    # NOTE: The --extra_apks / --extra_apex_payload_key list below is copied
    # VERBATIM from script/generate-release.sh lines 74-171. Do NOT paraphrase,
    # trim, or "optimize" — a missing apex entry causes AVB to reject the
    # signature. The list is device-independent within the tokay-class set
    # (script/generate-release.sh:61).
    #
    # ShellCheck: the long flag list is intentionally formatted to mirror the
    # source file line-for-line for auditability.
    sign_target_files_apks \
        -o -d "$REL_KEY_DIR" \
        --avb_vbmeta_key "$REL_KEY_DIR/avb.pem" \
        --avb_vbmeta_algorithm "$AVB_ALGORITHM" \
        --extra_apks com.android.adbd.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.adbd.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks AdServicesApk.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.adservices.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.adservices.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.apex.cts.shim.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.apex.cts.shim.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.appsearch.apk.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.appsearch.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.appsearch.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.art.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.art.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.art.debug.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.art.debug.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks Bluetooth.apk="$REL_KEY_DIR/bluetooth" \
        --extra_apks com.android.bt.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.bt.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.cellbroadcast.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.cellbroadcast.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.compos.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.compos.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.configinfrastructure.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.configinfrastructure.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.conscrypt.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.conscrypt.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.crashrecovery.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.crashrecovery.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.devicelock.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.devicelock.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.extservices.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.extservices.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.hardware.biometrics.face.virtual.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.hardware.biometrics.face.virtual.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.hardware.biometrics.fingerprint.virtual.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.hardware.biometrics.fingerprint.virtual.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.hardware.cas.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.hardware.cas.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks HealthConnectBackupRestore.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks HealthConnectController.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.healthfitness.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.healthfitness.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.i18n.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.i18n.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.ipsec.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.ipsec.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.media.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.media.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.media.swcodec.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.media.swcodec.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.mediaprovider.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.mediaprovider.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.neuralnetworks.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.neuralnetworks.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.nfcservices.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.nfcservices.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks FederatedCompute.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.ondevicepersonalization.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.ondevicepersonalization.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.os.statsd.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.os.statsd.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks SafetyCenterResources.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.permission.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.permission.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.profiling.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.profiling.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.resolv.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.resolv.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.rkpd.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.rkpd.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.runtime.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.runtime.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.scheduling.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.scheduling.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.sdkext.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.sdkext.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.telephonycore.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.telephonycore.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks ServiceConnectivityResources.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.tethering.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.tethering.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.tzdata.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.tzdata.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.uprobestats.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.uprobestats.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks ServiceUwbResources.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.uwb.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.uwb.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.android.virt.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.virt.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks OsuLogin.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks ServiceWifiResources.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks WifiDialog.apk="$REL_KEY_DIR/releasekey" \
        --extra_apks com.android.wifi.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.android.wifi.apex="$REL_KEY_DIR/avb.pem" \
        --extra_apks com.google.pixel.camera.hal.apex="$REL_KEY_DIR/releasekey" \
        --extra_apex_payload_key com.google.pixel.camera.hal.apex="$REL_KEY_DIR/avb.pem" \
        "$target_files_input" "$signed_out"

    echo "  ✓ signed target-files: $signed_out"
    SIGNED_TARGET_FILES="$signed_out"
}

# ── OTA + image generation ──────────────────────────────────────────────────
generate_ota_and_images() {
    # Derive BUILD_NUMBER from the target-files name if not otherwise provided.
    # GrapheneOS convention: <device>-target_files.zip lives in releases/<BUILD_NUMBER>/.
    local build_number
    build_number="$(basename "$RELEASE_OUT")"

    # Capture device name into a local before the subshell below; the subshell
    # sources clear-factory-images-variables.sh which unsets DEVICE, so the
    # later `DEVICE="$DEVICE"` self-reference would trip `set -u` (DEC-022).
    local device_name="$DEVICE"
    local build_num="$build_number"

    local ota_zip="$SIGNED_DIR/$DEVICE-ota_update-$build_number.zip"
    local img_zip="$SIGNED_DIR/$DEVICE-img-$build_number.zip"

    echo "→ Generating OTA update zip"
    ota_from_target_files -k "$REL_KEY_DIR/releasekey" "$SIGNED_TARGET_FILES" "$ota_zip"
    echo "  ✓ $ota_zip"

    echo "→ Generating factory image zip"
    img_from_target_files "$SIGNED_TARGET_FILES" "$img_zip"
    echo "  ✓ $img_zip"

    OTA_ZIP="$ota_zip"
    IMG_ZIP="$img_zip"
    BUILD_NUMBER="$build_number"

    # Factory bundle: source the AOSP factory-image generator. This is the env
    # setup block from generate-release.sh:43-66, scoped to the otatools workdir.
    echo "→ Generating factory bundle (device/common/generate-factory-images-common.sh)"
    (
        cd "$WORK_DIR"
        # The AOSP factory-image generator sources scripts that don't expect
        # `set -u`; disable it inside this subshell so unbound variables in the
        # sourced AOSP code don't abort the pipeline (DEC-022).
        set +u
        # The factory-image generator expects to find the signed target-files
        # and image zips in CWD; copy/symlink them in with the expected names.
        ln -sf "$SIGNED_TARGET_FILES" "$device_name-target_files.zip"
        ln -sf "$IMG_ZIP" "$device_name-img-$build_num.zip"

        source device/common/clear-factory-images-variables.sh
        BUILD="$build_num"
        VERSION="$build_num"
        DEVICE="$device_name"
        PRODUCT="$device_name"

        # Radio images: tokay-class needs bootloader (+ radio, except tangorpro).
        unzip -oq "$SIGNED_TARGET_FILES" OTA/android-info.txt
        get_radio_image() {
            grep "require version-$1" OTA/android-info.txt | cut -d '=' -f 2 | tr '[:upper:]' '[:lower:]'
        }
        # tokay is in the second branch of generate-release.sh:61-66.
        BOOTLOADER="$(get_radio_image bootloader)"
        [[ "$device_name" != "tangorpro" ]] && RADIO="$(get_radio_image baseband)" || RADIO=""
        DISABLE_UART=true
        DISABLE_FIPS=true
        DISABLE_DPM=true

        source device/common/generate-factory-images-common.sh
    )
    FACTORY_ZIP="$WORK_DIR/$DEVICE-factory-$BUILD_NUMBER.zip"
    if [[ -f "$FACTORY_ZIP" ]]; then
        mv "$FACTORY_ZIP" "$SIGNED_DIR/"
        FACTORY_ZIP="$SIGNED_DIR/$DEVICE-factory-$BUILD_NUMBER.zip"
        echo "  ✓ $FACTORY_ZIP"
    else
        echo "  WARN: factory zip not found at expected path; skipping optimize step" >&2
        FACTORY_ZIP=""
    fi
}

# ── Optional fastboot optimize-factory-image ────────────────────────────────
optimize_factory_image() {
    if [[ -z "${FACTORY_ZIP:-}" ]] || [[ ! -f "$FACTORY_ZIP" ]]; then
        return 0
    fi
    command -v fastboot >/dev/null 2>&1 || {
        echo "  WARN: fastboot not in PATH; skipping optimize-factory-image" >&2
        return 0
    }
    # tokay uses MAX_DOWNLOAD_SIZE=0xf900000 (generate-release.sh:184).
    local max_dl
    case "$DEVICE" in
        rango|mustang|blazer|frankel) max_dl="0x10000000" ;;
        *)                             max_dl="0xf900000" ;;
    esac
    echo "→ Optimizing factory image (MAX_DOWNLOAD_SIZE=$max_dl)"
    # Second arg is the inner dir name; output defaults to <name>.zip.
    local install_name="$DEVICE-install-$BUILD_NUMBER"
    fastboot -S "$max_dl" optimize-factory-image "$FACTORY_ZIP" "$install_name"
    if [[ -f "$WORK_DIR/$install_name.zip" ]]; then
        mv "$WORK_DIR/$install_name.zip" "$SIGNED_DIR/"
        echo "  ✓ $SIGNED_DIR/$install_name.zip"
    fi
}

# ── MANIFEST.txt (Law 10 — Audit Trail) ────────────────────────────────────
write_manifest() {
    local manifest="$SIGNED_DIR/MANIFEST.txt"
    {
        echo "GuardTalkOS Signed Release Manifest"
        echo "==================================="
        echo "Generated : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "Device    : $DEVICE"
        echo "Build dir : $BUILD_DIR"
        echo "Release   : $RELEASE_OUT"
        echo "AVB algo  : $AVB_ALGORITHM"
        echo ""
        echo "── Output files ──────────────────────────────────────────────────"
        local f
        for f in "$SIGNED_DIR"/*.zip; do
            [[ -f "$f" ]] || continue
            printf '  %-50s %s\n' "$(basename "$f")" "$(sha256sum "$f" | awk '{print $1}')"
        done
        echo ""
        echo "── Key fingerprints (SHA-256 of each .x509.pem) ─────────────────"
        local k
        for k in "${PACKAGE_KEYS[@]}"; do
            printf '  %-18s %s\n' "$k" "$(sha256sum "$KEY_DIR/$k.x509.pem" | awk '{print $1}')"
        done
        echo ""
        echo "── AVB public-key blob ───────────────────────────────────────────"
        printf '  %-18s %s\n' "avb_pkmd.bin" "$(sha256sum "$KEY_DIR/avb_pkmd.bin" | awk '{print $1}')"
        echo ""
        echo "── Source-of-truth ──────────────────────────────────────────────"
        echo "  Apex key list: script/generate-release.sh:74-171 (copied VERBATIM)"
        echo "  Decrypt pattern: script/decrypt-keys"
        echo "  Runbook: vendor/guardtalk/branding/signing-keys/RUNBOOK.md §7"
    } > "$manifest"
    echo "→ Manifest written: $manifest"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo "GuardTalkOS Release Signing Pipeline (T-SIGN-PIPELINE)"
    echo "Source-of-truth: script/generate-release.sh + script/decrypt-keys"
    echo ""

    preflight

    # Signed outputs land in <release-out>/signed/.
    SIGNED_DIR="$RELEASE_OUT/signed"
    rm -rf "$SIGNED_DIR"
    mkdir -p "$SIGNED_DIR"

    # otatools workdir (sibling of signed/).
    WORK_DIR="$RELEASE_OUT/otatools-work"
    SIGNED_TARGET_FILES=""
    OTA_ZIP=""
    IMG_ZIP=""
    FACTORY_ZIP=""
    BUILD_NUMBER=""

    decrypt_keys
    setup_otatools
    sign_target_files
    generate_ota_and_images
    optimize_factory_image
    write_manifest

    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo " Signing complete. Outputs in: $SIGNED_DIR"
    echo "══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Inspect $SIGNED_DIR/MANIFEST.txt (SHA-256s + key fingerprints)."
    echo "  2. Copy avb_pkmd.bin into the signed dir (or use the one in --key-dir)."
    echo "  3. Run flash-signed.sh --release-dir $SIGNED_DIR --device $DEVICE"
    echo ""
}

main "$@"
