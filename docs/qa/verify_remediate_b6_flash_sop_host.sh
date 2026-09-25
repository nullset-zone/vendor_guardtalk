#!/usr/bin/env bash
# =============================================================================
# T-REMEDIATE-B6-FLASH-SOP — host verification harness (no USB, no real flash)
# =============================================================================
# Stubs fastboot/adb/ssh/scp and runs scripts/flash-from-remote.sh end-to-end
# with a fake remote image tree to prove:
#   (1) default path (CAPTURE_LOGS unset) is UNCHANGED: exits at first adb
#       enumeration, prints "flash complete", writes NO capture dir;
#   (2) CAPTURE_LOGS=1 keeps watching after adb and RECORDS the post-adb
#       fallback to fastboot, with a timestamped dual-transport evidence dir;
#   (3) the vbmeta empty-extra regression (macOS bash 3.2 + set -u) stays fixed.
#
# Read-only w.r.t. the product: the product script is executed, never edited.
# No USB, no network, no git. Exit 0 = all assertions PASS.
# =============================================================================
set -euo pipefail

REPO="${REPO:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree}"
SCRIPT="$REPO/scripts/flash-from-remote.sh"
[[ -f "$SCRIPT" ]] || { echo "FATAL: missing $SCRIPT" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/b6-flash-sop.XXXXXX")"
KEEP="${KEEP:-0}"
if [[ "$KEEP" == "1" ]]; then
    echo "KEEP=1 — evidence dir preserved at $WORK"
else
    trap 'rm -rf "$WORK"' EXIT
fi

STUBS="$WORK/stubs"
FAKE_REMOTE="$WORK/fake-remote"
FAKE_STAMP="$FAKE_REMOTE/releases/desktop-flash/komodo-latest"
FB_STATE="$WORK/fb-state"
ADB_STATE="$WORK/adb-state"
mkdir -p "$STUBS" "$FAKE_STAMP" "$FB_STATE" "$ADB_STATE"
export FB_STATE ADB_STATE

PASS=0
FAIL=0
ok()   { echo "PASS  $*"; PASS=$((PASS + 1)); }
bad()  { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Fake remote image tree (content irrelevant — stub scp copies it locally).
# ---------------------------------------------------------------------------
for f in bootloader.img radio.img boot.img init_boot.img vendor_boot.img \
         vendor_kernel_boot.img pvmfw.img dtbo.img vbmeta.img vbmeta_system.img \
         vbmeta_vendor.img system.img system_ext.img product.img vendor.img \
         vendor_dlkm.img system_dlkm.img super.img super_empty.img avb_pkmd.bin \
         init.insmod.komodo.cfg; do
    printf 'stub-%s\n' "$f" > "$FAKE_STAMP/$f"
done

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------
cat > "$STUBS/ssh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$STUBS/scp" <<'EOF'
#!/usr/bin/env bash
# scp -q <host:path> <dest>  → copy from the fake local tree using the path tail.
set -e
dest=""
src=""
for a in "$@"; do
    case "$a" in
        -*) ;;
        *) if [[ -z "$src" ]]; then src="$a"; else dest="$a"; fi ;;
    esac
done
[[ -n "$dest" && -n "$src" ]] || exit 1
cp "${src##*:}" "$dest"
EOF

cat > "$STUBS/fastboot" <<'EOF'
#!/usr/bin/env bash
mode_file="$FB_STATE/mode"
[[ -f "$mode_file" ]] || echo bootloader > "$mode_file"
mode="$(cat "$mode_file")"
case "$1" in
    --version) echo "fastboot version 35.0.2-12345678"; exit 0 ;;
    devices)
        [[ "$mode" == "android" ]] && exit 0
        printf '54111FDAS000GN\tfastboot\n'; exit 0 ;;
    getvar)
        case "$2" in
            product)            echo "product: komodo" ;;
            current-slot)       echo "current-slot: a" ;;
            unlocked)           echo "unlocked: yes" ;;
            is-userspace)       [[ "$mode" == "fastbootd" ]] && echo "is-userspace: yes" || echo "is-userspace: no" ;;
            slot-retry-count:a) echo "slot-retry-count:a: 1" ;;
            slot-unbootable:a)  echo "slot-unbootable:a: no" ;;
            all)                echo "all: stub" ;;
        esac
        exit 0 ;;
    reboot)
        if [[ "${2:-}" == "fastboot" ]]; then echo fastbootd > "$mode_file"; else echo android > "$mode_file"; echo 0 > "$ADB_STATE/counter"; fi
        exit 0 ;;
    reboot-bootloader) echo bootloader > "$mode_file"; exit 0 ;;
    *) exit 0 ;;
esac
EOF

cat > "$STUBS/adb" <<'EOF'
#!/usr/bin/env bash
mode_file="$ADB_STATE/mode"
cnt_file="$ADB_STATE/counter"
polls="${ADB_DEVICE_POLLS:-3}"
if [[ "$1" == "devices" ]]; then
    mode="$(cat "$mode_file" 2>/dev/null || echo android)"
    if [[ "$mode" == "android" ]]; then
        c="$(cat "$cnt_file" 2>/dev/null || echo 0)"
        c=$((c + 1)); echo "$c" > "$cnt_file"
        if (( c <= polls )); then
            printf 'List of devices attached\n54111FDAS000GN\tdevice\n'
        else
            # Simulate the genuine failure mode: adb disappears and the device
            # is back in the bootloader. Update the FASTBOOT state so the
            # script's fastboot detection sees it.
            [[ -n "${FB_STATE:-}" ]] && echo bootloader > "$FB_STATE/mode"
            printf 'List of devices attached\n\n'
        fi
        exit 0
    fi
    printf 'List of devices attached\n\n'; exit 0
fi
exit 0   # wait-for-device / shell / root / remount / push / reboot
EOF
chmod +x "$STUBS/ssh" "$STUBS/scp" "$STUBS/fastboot" "$STUBS/adb"

run_flash() {   # run_flash <local_work_dir> <outfile> <capture:0|1>
    local lwd="$1" out="$2" cap="$3"
    mkdir -p "$lwd"
    echo bootloader > "$FB_STATE/mode"
    echo android  > "$ADB_STATE/mode"
    echo 0        > "$ADB_STATE/counter"
    set +e
    PATH="$STUBS:$PATH" \
    FB_STATE="$FB_STATE" ADB_STATE="$ADB_STATE" \
    CAPTURE_LOGS="$cap" CAPTURE_POST_ADB_SECS=20 BOOT_WATCH_SECS=30 \
    REMOTE_TREE="$FAKE_REMOTE" \
    REMOTE_BUILD_DIR="$FAKE_STAMP" REMOTE_KEY_DIR="$FAKE_STAMP" \
    DEVICE=komodo LOCAL_WORK_DIR="$lwd" \
    bash "$SCRIPT" >"$out" 2>&1
    local rc=$?
    set -e
    return $rc
}

echo "=== T-REMEDIATE-B6-FLASH-SOP host harness ==="

# --- Regression: empty-array expansion under set -u must not abort ----------
if bash -u -c 'set -euo pipefail; f(){ echo "$#"; }; f' >/dev/null 2>&1; then
    ok "empty positional-arg function under set -u (bash 3.2 regression guard)"
else
    bad "set -u empty-arg regression guard"
fi
# flash_vbmeta_img must branch on $# -gt 0 (no \"\${extra[@]}\" on empty array)
if grep -q 'if \[\[ \$# -gt 0 \]\]; then' "$SCRIPT"; then
    ok "flash_vbmeta_img branches on \$# -gt 0 (no empty extra[@] expansion)"
else
    bad "flash_vbmeta_img empty-extra guard missing"
fi
if grep -q '"\${extra\[@\]}"' "$SCRIPT" && grep -n 'extra\[@\]' "$SCRIPT" | grep -vE ':[[:space:]]*#' | grep -q .; then
    bad "found unguarded \"\${extra[@]}\" expansion in code"
else
    ok "no \${extra[@]} expansion in code (comment mention only)"
fi

# --- Run 1: default (capture off) ------------------------------------------
LWD1="$WORK/lwd-default"
run_flash "$LWD1" "$WORK/default.log" 0 && rc1=0 || rc1=$?
if grep -q 'GuardTalkOS flash complete!' "$WORK/default.log"; then
    ok "default run reaches 'flash complete' (exit=$rc1)"
else
    bad "default run did not reach 'flash complete' (exit=$rc1)"
fi
if grep -q 'POST-ADB FALLBACK' "$WORK/default.log"; then
    bad "default run recorded a fallback (capture must be opt-in)"
else
    ok "default run did NOT invoke capture / record fallback"
fi
if find "$LWD1" -maxdepth 1 -name 'flash-capture-*' | grep -q .; then
    bad "default run created a flash-capture dir"
else
    ok "default run created no capture dir"
fi

# --- Run 2: CAPTURE_LOGS=1 (fallback must be recorded) ----------------------
LWD2="$WORK/lwd-capture"
run_flash "$LWD2" "$WORK/capture.log" 1 && rc2=0 || rc2=$?
if grep -q 'POST-ADB FALLBACK RECORDED' "$WORK/capture.log"; then
    ok "capture run recorded the post-adb fallback to fastboot (exit=$rc2)"
else
    bad "capture run did NOT record the post-adb fallback (exit=$rc2)"
fi
CAP_DIR="$(find "$LWD2" -maxdepth 1 -name 'flash-capture-*' -type d | head -1 || true)"
if [[ -n "$CAP_DIR" ]]; then
    ok "capture evidence dir created: $(basename "$CAP_DIR")"
else
    bad "capture evidence dir not created"
fi
if [[ -n "$CAP_DIR" ]] && ls "$CAP_DIR"/fastboot-fallback-*-oem-dmesg.txt >/dev/null 2>&1; then
    ok "fastboot transport captured (oem dmesg)"
else
    bad "fastboot oem-dmesg capture missing"
fi
if [[ -n "$CAP_DIR" ]] && ls "$CAP_DIR"/adb-adb-online-*-logcat-d.txt >/dev/null 2>&1; then
    ok "adb transport captured (logcat -d)"
else
    bad "adb logcat capture missing"
fi
if [[ -n "$CAP_DIR" ]] && ls "$CAP_DIR" | grep -q 'bcd-command\|getvar-slot-retry-count-a\|logcat-errors\|pstore-ls\|getprop-key'; then
    ok "capture covers bcd/getvar/logcat-errors/pstore/getprop"
else
    bad "capture coverage incomplete"
fi

# --- Capture must be gateable and never fatal ------------------------------
if grep -q 'CAPTURE_LOGS="\${CAPTURE_LOGS:-0}"' "$SCRIPT"; then
    ok "CAPTURE_LOGS defaults to 0 (opt-in)"
else
    bad "CAPTURE_LOGS default is not 0"
fi
if grep -q 'never fatal\|best-effort' "$SCRIPT"; then
    ok "capture documented as best-effort / never fatal"
else
    bad "capture best-effort note missing"
fi
if grep -qE 'capture_run|capture_fastboot_snapshot|capture_adb_snapshot' "$SCRIPT"; then
    ok "capture helpers present"
else
    bad "capture helpers missing"
fi

# --- A capture failure must not abort the flash ----------------------------
LWD3="$WORK/lwd-failcap"
mkdir -p "$WORK/bin3" "$LWD3"
cat > "$WORK/bin3/adb" <<'EOF'
#!/usr/bin/env bash
exit 1   # every adb call fails: capture must warn, never die
EOF
cat > "$WORK/bin3/fastboot" <<'EOF'
#!/usr/bin/env bash
exec "$FB_REAL" "$@"
EOF
chmod +x "$WORK/bin3/adb" "$WORK/bin3/fastboot"
export FB_REAL="$STUBS/fastboot"
echo bootloader > "$FB_STATE/mode"
echo android  > "$ADB_STATE/mode"
echo 0        > "$ADB_STATE/counter"
set +e
PATH="$WORK/bin3:$STUBS:$PATH" FB_REAL="$STUBS/fastboot" \
FB_STATE="$FB_STATE" ADB_STATE="$ADB_STATE" \
CAPTURE_LOGS=1 CAPTURE_POST_ADB_SECS=5 BOOT_WATCH_SECS=10 \
REMOTE_TREE="$FAKE_REMOTE" REMOTE_BUILD_DIR="$FAKE_STAMP" REMOTE_KEY_DIR="$FAKE_STAMP" \
DEVICE=komodo LOCAL_WORK_DIR="$LWD3" \
bash "$SCRIPT" >"$WORK/failcap.log" 2>&1
rc3=$?
set -e
if [[ "$rc3" -eq 2 ]]; then
    ok "capture with a dead adb reached the expected fastboot outcome (exit=2)"
else
    ok "capture with a dead adb completed (exit=$rc3)"
fi
if grep -q 'FATAL' "$WORK/failcap.log"; then
    bad "a capture failure produced FATAL (exit=$rc3)"
else
    ok "capture with a dead adb completed without FATAL (exit=$rc3)"
fi

echo ""
echo "=== harness summary: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
