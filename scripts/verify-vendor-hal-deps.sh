#!/usr/bin/env bash
# T-EXCISE-BT-SOCKET-LIB-KEEP — vendor HAL shared-library closure gate.
#
# WHY THIS EXISTS
# ---------------
# The Stallion handset boot-looped on the GuardTalk animation because vendor.img
# shipped HAL binaries whose ELF DT_NEEDED entries did not exist in the image:
#
#   F linker : CANNOT LINK EXECUTABLE "/vendor/bin/hw/android.hardware.contexthub-service.generic":
#              library "android.hardware.bluetooth.socket-V1-ndk.so" not found: needed by main executable
#
# The excision gates that existed before this one checked VINTF manifests,
# PRODUCT_PACKAGES lists, and PRODUCT_COPY_FILES entries. None of them ever
# executed or even read a vendor HAL binary, so a library that a *kept* HAL
# links against could be removed without anything going red. Nothing caught it
# until the handset failed to boot.
#
# The dynamic linker resolves DT_NEEDED at process start, before any code runs.
# A missing entry is therefore fatal to the whole process, not a degraded
# feature: contexthub could not exec, never published ISensorManager,
# system_server blocked in SystemSensorManager.nativeCreate, and Watchdog killed
# the system process at 67 s. One missing .so took the device down.
#
# WHAT THIS GATE ASSERTS
# ----------------------
# For every ELF binary installed in /vendor/bin and /vendor/bin/hw of a stamp's
# vendor.img, each DT_NEEDED library name must resolve to one of:
#
#   1. a file in the same image's /vendor/lib64 (or /vendor/lib64/hw, /egl —
#      both are vendor-namespace search paths per
#      system/linkerconfig/contents/namespace/vendordefault.cc:43-46);
#   2. a name on the explicit EXTERNAL_ALLOW list below, each entry of which is
#      documented as resolving from /system/lib64, the runtime APEX, or an
#      APEX-provided library — see the per-entry comments; or
#   3. nothing else. A gap is a FAIL.
#
# It deliberately does NOT try to validate transitive closure into /system or
# APEX. That would need those partitions' contents, and a name-level allow list
# is the honest, checkable claim: "this binary starts, and we know where each
# name comes from."
#
# USAGE
#   vendor/guardtalk/scripts/verify-vendor-hal-deps.sh [STAMP_DIR]
#
#   STAMP_DIR defaults to releases/desktop-flash/stallion-latest. It may be a
#   stamp directory containing vendor.img, or a path to a vendor.img directly.
#
# EXIT CODES
#   0  every NEEDED name resolved
#   1  at least one real gap (MISSING lines printed)
#   2  cannot run: missing stamp, missing vendor.img, missing debugfs/readelf
#      and objdump, or nothing to check (fails closed — never a silent pass)
#
# This script is READ-ONLY. It extracts into a temp dir and never writes to the
# stamp. No build, no flash, no device.
#
# T-EXCISE-BT-SOCKET-LIB-KEEP note on the allow list: `libapexsupport.so` was
# investigated because it is absent from BOTH the stock and stamped
# vendor/lib64. It is NOT a defect — it resolves from the runtime APEX (present
# at system/system/lib64/libapexsupport.so in the stock unpacked tree). Do not
# "fix" it.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

DEFAULT_STAMP="releases/desktop-flash/stallion-latest"

# ---------------------------------------------------------------------------
# Libraries that legitimately live OUTSIDE vendor.img.
#
# Each entry was checked against the stock unpacked tree for stallion
# (vendor/adevtool/dl/unpacked/stallion-CP1A.260505.005/) rather than assumed.
# Keep this list tight: every name added here weakens the gate. A name that
# SHOULD be in vendor/lib64 must not be added to silence this script.
# ---------------------------------------------------------------------------
EXTERNAL_ALLOW="
libc.so
libm.so
libdl.so
liblog.so
libbase.so
libutils.so
libcutils.so
libbinder_ndk.so
libc++.so
libselinux.so
libapexsupport.so
libnativewindow.so
libsync.so
libvndksupport.so
libEGL.so
libGLESv2.so
libGLESv3.so
libhidlbase.so
libvintf.so
"

# vendor-namespace search subdirectories (vendordefault.cc:43-46)
VENDOR_LIB_SUBDIRS="hw egl"

FAIL=0
CHECKED=0
SKIPPED_NONELF=0

say() { printf '%s\n' "$*"; }

# --- tool discovery (fail closed) ------------------------------------------
if ! command -v debugfs >/dev/null 2>&1; then
    say "FAIL: debugfs not found (needed to read vendor.img). Install e2fsprogs."
    exit 2
fi

READER=""
if command -v readelf >/dev/null 2>&1; then
    READER="readelf"
elif command -v objdump >/dev/null 2>&1; then
    READER="objdump"
else
    say "FAIL: neither readelf nor objdump found (needed to read DT_NEEDED). Install binutils."
    exit 2
fi

# --- resolve the stamp ------------------------------------------------------
STAMP_ARG="${1:-}"
if [ -z "$STAMP_ARG" ]; then
    STAMP_ARG="$ROOT/$DEFAULT_STAMP"
elif [ "${STAMP_ARG#/}" = "$STAMP_ARG" ]; then
    STAMP_ARG="$ROOT/$STAMP_ARG"
fi

case "$STAMP_ARG" in
    */vendor.img) VENDOR_IMG="$STAMP_ARG" ;;
    *)            VENDOR_IMG="$STAMP_ARG/vendor.img" ;;
esac

# Also accept an image file directly even if it is not named vendor.img, so the
# gate can be exercised against a synthetic image in a self-test.
if [ -f "$STAMP_ARG" ]; then
    VENDOR_IMG="$STAMP_ARG"
fi

if [ ! -f "$VENDOR_IMG" ]; then
    say "FAIL: vendor.img not found: $VENDOR_IMG"
    exit 2
fi

say "=== GuardTalk vendor HAL dependency closure ==="
say "stamp   : $VENDOR_IMG"
say "reader  : $READER"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gt-hal-deps.XXXXXX")" || {
    say "FAIL: cannot create temp dir"
    exit 2
}
# shellcheck disable=SC2064  # expand WORK now, on purpose
trap "rm -rf '$WORK'" EXIT INT TERM

# Extract only the two subtrees we need. debugfs rdump prints benign
# "Operation not permitted while changing ownership" chatter when not root;
# those lines are expected and are not failures.
extract() {
    local src="$1"
    debugfs -R "rdump $src $WORK" "$VENDOR_IMG" >/dev/null 2>&1
    return 0
}

extract /bin
extract /lib64

BIN_DIR="$WORK/bin"
LIB_DIR="$WORK/lib64"

if [ ! -d "$LIB_DIR" ]; then
    say "FAIL: /lib64 could not be extracted from vendor.img (no libraries to resolve against)"
    exit 2
fi
if [ ! -d "$BIN_DIR" ]; then
    say "FAIL: /bin could not be extracted from vendor.img (no binaries to check)"
    exit 2
fi

lib_count="$(find "$LIB_DIR" -maxdepth 1 -name '*.so' 2>/dev/null | wc -l | tr -d ' ')"
say "lib64   : $lib_count .so entries"
say ""

# --- helpers ---------------------------------------------------------------
is_elf() {
    # ELF magic: 0x7f 'E' 'L' 'F'
    [ -r "$1" ] && [ "$(dd if="$1" bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ]
}

needed_of() {
    if [ "$READER" = "readelf" ]; then
        readelf -d "$1" 2>/dev/null \
            | sed -n 's/.*(NEEDED).*\[\(.*\)\]$/\1/p'
    else
        objdump -p "$1" 2>/dev/null \
            | sed -n 's/^ *NEEDED *\(.*\)$/\1/p'
    fi
}

resolves_in_vendor_lib64() {
    local name="$1" sub
    [ -e "$LIB_DIR/$name" ] && return 0
    for sub in $VENDOR_LIB_SUBDIRS; do
        [ -e "$LIB_DIR/$sub/$name" ] && return 0
    done
    return 1
}

is_external_allowed() {
    local name="$1" a
    for a in $EXTERNAL_ALLOW; do
        [ "$a" = "$name" ] && return 0
    done
    return 1
}

# --- main loop -------------------------------------------------------------
# /bin/hw first: those are the HALs, the class that took the device down.
for dir in "$BIN_DIR/hw" "$BIN_DIR"; do
    [ -d "$dir" ] || continue
    case "$dir" in
        */hw) label="bin/hw" ;;
        *)    label="bin" ;;
    esac

    for bin in "$dir"/*; do
        [ -f "$bin" ] || continue
        if ! is_elf "$bin"; then
            SKIPPED_NONELF=$((SKIPPED_NONELF + 1))
            continue
        fi
        CHECKED=$((CHECKED + 1))

        rel="${bin#$WORK/}"
        missing=""
        while IFS= read -r lib; do
            [ -n "$lib" ] || continue
            resolves_in_vendor_lib64 "$lib" && continue
            is_external_allowed "$lib" && continue
            missing="$missing $lib"
        done <<EOF
$(needed_of "$bin")
EOF

        if [ -n "$missing" ]; then
            FAIL=$((FAIL + 1))
            for m in $missing; do
                say "MISSING $rel -> $m"
            done
        fi
    done
done

# --- summary --------------------------------------------------------------
say ""
if [ "$CHECKED" -eq 0 ]; then
    say "FAIL: no ELF binaries found to check (extraction failed or image is empty)."
    say "Refusing to report PASS on a vacuous run."
    exit 2
fi

say "checked : $CHECKED ELF binaries in /vendor/bin and /vendor/bin/hw"
say "skipped : $SKIPPED_NONELF non-ELF entries"

if [ "$FAIL" -gt 0 ]; then
    say ""
    say "VERDICT: FAIL — $FAIL binary(ies) have unresolved DT_NEEDED libraries."
    say "A missing NEEDED entry is fatal to the whole process at exec time"
    say "(the dynamic linker resolves it before any code runs)."
    exit 1
fi

say ""
say "VERDICT: PASS — every DT_NEEDED name resolves in /vendor/lib64 or the"
say "                  documented external allow list."
exit 0
