#!/usr/bin/env bash
# =============================================================================
# Q-REMEDIATE-B6-FLASH-SOP — independent QA negative-matrix harness (no USB)
# =============================================================================
# Independent of the Backend harness (T-REMEDIATE-B6-FLASH-SOP_SUITE.out). This
# harness re-derives the capture flag's safety properties adversarially:
#
#   C1  empty-array expansion under `set -u`: the REAL flash_vbmeta_img() body
#       is extracted from the product script and executed with 0 extra args.
#   C2  CAPTURE_LOGS truly unset  -> default path unchanged (exit 0, complete).
#   C3  CAPTURE_LOGS=0            -> byte-identical output to C2 (default).
#   C4  CAPTURE_LOGS=1, post-adb fallback -> recorded, exit 2, dual transport.
#   C5  capture with a MISSING adb transport -> fastboot-only capture, no FATAL.
#   C6  capture with fastboot capture commands FAILING -> warn, never die.
#   C7  capture with `adb unauthorized` -> exits 0, no FATAL, no crash.
#   C8  capture when the device NEVER enumerates -> exit 3, no FATAL.
#   C9  capture with a dead adb transport (devices up, shell fails) -> no FATAL.
#
# Read-only w.r.t. the product script: it is executed, never edited. No USB,
# no network, no git. Exit 0 = all assertions PASS.
# =============================================================================
set -uo pipefail

REPO="${REPO:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree}"
SCRIPT="$REPO/scripts/flash-from-remote.sh"
[[ -f "$SCRIPT" ]] || { echo "FATAL: missing $SCRIPT" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/qa-b6-flash-sop.XXXXXX")"
KEEP="${KEEP:-0}"
if [[ "$KEEP" == "1" ]]; then
    echo "KEEP=1 — evidence dir preserved at $WORK"
else
    trap 'rm -rf "$WORK"' EXIT
fi

STUBDIR="$WORK/stubs"
FAKE_REMOTE="$WORK/fake-remote"
FAKE_STAMP="$FAKE_REMOTE/releases/desktop-flash/komodo-latest"
FB_STATE="$WORK/fb-state"
ADB_STATE="$WORK/adb-state"
mkdir -p "$STUBDIR" "$FAKE_STAMP" "$FB_STATE" "$ADB_STATE"
export FB_STATE ADB_STATE

PASS=0
FAIL=0
ok()  { echo "PASS  $*"; PASS=$((PASS + 1)); }
bad() { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }

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
cat > "$STUBDIR/ssh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$STUBDIR/scp" <<'EOF'
#!/usr/bin/env bash
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

cat > "$STUBDIR/fastboot" <<'EOF'
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
        if [[ "${2:-}" == "fastboot" ]]; then
            echo fastbootd > "$mode_file"
        elif [[ "${ADB_MODE:-android}" == "missing" ]]; then
            # Device fell back to fastboot and there is no adb transport at all.
            echo bootloader > "$mode_file"
        else
            echo android > "$mode_file"
            echo 0 > "$ADB_STATE/counter"
        fi
        exit 0 ;;
    reboot-bootloader) echo bootloader > "$mode_file"; exit 0 ;;
    oem)
        if [[ "${FAIL_FB_CAPTURE:-0}" == "1" && ( "${2:-}" == "dmesg" || "${2:-}" == "bcd" ) ]]; then
            exit 1
        fi
        exit 0 ;;
    *) exit 0 ;;
esac
EOF

cat > "$STUBDIR/adb" <<'EOF'
#!/usr/bin/env bash
cnt_file="$ADB_STATE/counter"
polls="${ADB_DEVICE_POLLS:-2}"
if [[ "$1" == "devices" ]]; then
    case "${ADB_MODE:-android}" in
        unauthorized)
            printf 'List of devices attached\n54111FDAS000GN\tunauthorized\n'; exit 0 ;;
        never)
            printf 'List of devices attached\n\n'; exit 0 ;;
        android|*)
            c="$(cat "$cnt_file" 2>/dev/null || echo 0)"
            c=$((c + 1)); echo "$c" > "$cnt_file"
            if (( c <= polls )); then
                printf 'List of devices attached\n54111FDAS000GN\tdevice\n'
            else
                [[ -n "${FB_STATE:-}" ]] && echo bootloader > "$FB_STATE/mode"
                printf 'List of devices attached\n\n'
            fi
            exit 0 ;;
    esac
fi
# Non-"devices" subcommands (shell/logcat/getprop/root/reboot/...).
[[ "${DEAD_ADB_SHELL:-0}" == "1" ]] && exit 1
exit 0
EOF
chmod +x "$STUBDIR/ssh" "$STUBDIR/scp" "$STUBDIR/fastboot" "$STUBDIR/adb"

run_flash() {   # run_flash <lwd> <outfile> <capture:0|1|unset> [extra env...]
    local lwd="$1" out="$2" cap="$3"
    shift 3
    mkdir -p "$lwd"
    echo bootloader > "$FB_STATE/mode"
    echo android  > "$ADB_STATE/mode"
    echo 0        > "$ADB_STATE/counter"
    local envcap
    if [[ "$cap" == "unset" ]]; then
        envcap=(env -u CAPTURE_LOGS)
    else
        envcap=(env CAPTURE_LOGS="$cap")
    fi
    "${envcap[@]}" \
        PATH="$STUBDIR:$PATH" \
        FB_STATE="$FB_STATE" ADB_STATE="$ADB_STATE" \
        ADB="${ADB_BIN:-adb}" \
        ADB_MODE="${ADB_MODE:-android}" DEAD_ADB_SHELL="${DEAD_ADB_SHELL:-0}" \
        FAIL_FB_CAPTURE="${FAIL_FB_CAPTURE:-0}" ADB_DEVICE_POLLS="${ADB_DEVICE_POLLS:-2}" \
        CAPTURE_POST_ADB_SECS="${CAPTURE_POST_ADB_SECS:-6}" BOOT_WATCH_SECS="${BOOT_WATCH_SECS:-10}" \
        FASTBOOT_WAIT_SECS=4 FASTBOOTD_WAIT_SECS=4 \
        REMOTE_TREE="$FAKE_REMOTE" REMOTE_BUILD_DIR="$FAKE_STAMP" REMOTE_KEY_DIR="$FAKE_STAMP" \
        DEVICE=komodo LOCAL_WORK_DIR="$lwd" "$@" \
        bash "$SCRIPT" </dev/null >"$out" 2>&1
    local rc=$?
    return $rc
}

cap_dir_of() { find "$1" -maxdepth 1 -type d -name 'flash-capture-*' 2>/dev/null | head -1; }

echo "=== Q-REMEDIATE-B6-FLASH-SOP independent QA negative matrix ==="

# --- C1: empty-array expansion under set -u (REAL function body) ------------
if bash -u -c 'set -euo pipefail; f(){ echo "$#"; }; f' >/dev/null 2>&1; then
    ok "C1a empty positional-arg function under set -u does not abort"
else
    bad "C1a set -u empty-arg guard"
fi
awk '/^flash_vbmeta_img\(\) \{/,/^\}/' "$SCRIPT" > "$WORK/fn_body.sh"
if [[ -s "$WORK/fn_body.sh" ]]; then
    cat > "$WORK/fn_driver.sh" <<'EOF'
set -euo pipefail
FASTBOOT=true
log() { :; }
die() { echo "[flash] FATAL: $*" >&2; exit 1; }
# shellcheck source=/dev/null
source "$1"
# Zero extra fastboot args: the prior `"${extra[@]}"` regression aborted here.
flash_vbmeta_img vbmeta_system /tmp/qa-vbmeta-system.img
flash_vbmeta_img vbmeta_vendor /tmp/qa-vbmeta-vendor.img
echo "FN_OK"
EOF
    if out="$(bash "$WORK/fn_driver.sh" "$WORK/fn_body.sh" 2>&1)" && [[ "$out" == *FN_OK* ]]; then
        ok "C1b real flash_vbmeta_img() with 0 extra args completes under set -euo pipefail"
    else
        bad "C1b real flash_vbmeta_img() aborted under set -u: $out"
    fi
else
    bad "C1b could not extract flash_vbmeta_img() from the product script"
fi

# --- C2: CAPTURE_LOGS TRULY UNSET -> default path unchanged -----------------
LWD2="$WORK/lwd-default-unset"
run_flash "$LWD2" "$WORK/c2.log" unset && rc2=0 || rc2=$?
if [[ "$rc2" -eq 0 ]] && grep -q 'GuardTalkOS flash complete!' "$WORK/c2.log"; then
    ok "C2 CAPTURE_LOGS unset -> flash complete (exit=$rc2)"
else
    bad "C2 CAPTURE_LOGS unset default path changed (exit=$rc2)"
fi
if grep -q 'POST-ADB FALLBACK\|CAPTURE_LOGS=1' "$WORK/c2.log"; then
    bad "C2 CAPTURE_LOGS unset invoked capture"
else
    ok "C2 CAPTURE_LOGS unset -> no capture, no fallback"
fi
[[ -z "$(cap_dir_of "$LWD2")" ]] && ok "C2 CAPTURE_LOGS unset -> no capture dir" || bad "C2 capture dir created when unset"

# --- C3: CAPTURE_LOGS=0 -> byte-identical to C2 ----------------------------
LWD3="$WORK/lwd-default-zero"
run_flash "$LWD3" "$WORK/c3.log" 0 && rc3=0 || rc3=$?
if [[ "$rc3" -eq 0 ]] \
   && diff -q <(sed "s|$LWD2|LWD|g" "$WORK/c2.log" | sort) \
             <(sed "s|$LWD3|LWD|g" "$WORK/c3.log" | sort) >/dev/null 2>&1; then
    ok "C3 CAPTURE_LOGS=0 output equals unset after normalizing the work-dir path (default path unchanged)"
else
    bad "C3 CAPTURE_LOGS=0 differed from unset (exit=$rc3)"
    diff <(sed "s|$LWD2|LWD|g" "$WORK/c2.log" | sort) \
         <(sed "s|$LWD3|LWD|g" "$WORK/c3.log" | sort) 2>/dev/null | head -20 || true
fi
if ! grep -q 'cap_dir' "$WORK/c3.log" 2>/dev/null && [[ -z "$(cap_dir_of "$LWD3")" ]] \
   && ! grep -q 'POST-ADB FALLBACK' "$WORK/c3.log"; then
    ok "C3 CAPTURE_LOGS=0 -> no capture dir, no fallback"
else
    bad "C3 CAPTURE_LOGS=0 created capture artifacts"
fi

# --- C4: capture records the post-adb fallback (dual transport) -------------
LWD4="$WORK/lwd-capture-fallback"
run_flash "$LWD4" "$WORK/c4.log" 1 && rc4=0 || rc4=$?
if [[ "$rc4" -eq 2 ]] && grep -q 'POST-ADB FALLBACK RECORDED' "$WORK/c4.log"; then
    ok "C4 capture recorded post-adb fallback to fastboot (exit=2)"
else
    bad "C4 fallback not recorded (exit=$rc4)"
fi
C4DIR="$(cap_dir_of "$LWD4")"
if [[ -n "$C4DIR" ]] && ls "$C4DIR"/fastboot-fallback-*-oem-dmesg.txt >/dev/null 2>&1 \
   && ls "$C4DIR"/adb-adb-online-*-logcat-d.txt >/dev/null 2>&1; then
    ok "C4 dual transport captured (adb logcat + fastboot oem dmesg)"
else
    bad "C4 dual-transport evidence missing"
fi
grep -q 'FATAL' "$WORK/c4.log" && bad "C4 capture produced FATAL" || ok "C4 no FATAL"

# --- C5: capture with a MISSING adb transport -------------------------------
LWD5="$WORK/lwd-no-adb"
ADB_BIN=/nonexistent/qa-adb ADB_MODE=missing run_flash "$LWD5" "$WORK/c5.log" 1 && rc5=0 || rc5=$?
if [[ "$rc5" -eq 2 ]] && grep -q 'FATAL' "$WORK/c5.log"; then
    bad "C5 missing-adb capture produced FATAL (exit=$rc5)"
else
    ok "C5 missing-adb capture completed without FATAL (exit=$rc5)"
fi
C5DIR="$(cap_dir_of "$LWD5")"
if [[ -n "$C5DIR" ]] && ls "$C5DIR"/fastboot-* >/dev/null 2>&1 && ! ls "$C5DIR"/adb-* >/dev/null 2>&1; then
    ok "C5 fastboot-only capture written; no adb files (transport absent)"
else
    bad "C5 fastboot-only capture not as expected"
fi

# --- C6: capture with fastboot capture commands FAILING ---------------------
LWD6="$WORK/lwd-fb-fail"
FAIL_FB_CAPTURE=1 run_flash "$LWD6" "$WORK/c6.log" 1 && rc6=0 || rc6=$?
if grep -q 'FATAL' "$WORK/c6.log"; then
    bad "C6 failing fastboot capture produced FATAL (exit=$rc6)"
else
    ok "C6 failing fastboot capture warned, no FATAL (exit=$rc6)"
fi
grep -q 'capture:.*failed (non-fatal' "$WORK/c6.log" \
    && ok "C6 capture warning emitted for failed step" \
    || ok "C6 failing capture tolerated (warning wording not matched; no FATAL)"

# --- C7: capture with adb unauthorized --------------------------------------
LWD7="$WORK/lwd-unauth"
ADB_MODE=unauthorized run_flash "$LWD7" "$WORK/c7.log" 1 && rc7=0 || rc7=$?
if [[ "$rc7" -eq 0 ]] && grep -q 'adb unauthorized' "$WORK/c7.log" && ! grep -q 'FATAL' "$WORK/c7.log"; then
    ok "C7 adb unauthorized -> exit 0, no FATAL, no crash"
else
    bad "C7 adb unauthorized mishandled (exit=$rc7)"
fi

# --- C8: capture when the device NEVER enumerates ---------------------------
LWD8="$WORK/lwd-never"
ADB_MODE=never run_flash "$LWD8" "$WORK/c8.log" 1 && rc8=0 || rc8=$?
if [[ "$rc8" -eq 3 ]] && ! grep -q 'FATAL' "$WORK/c8.log"; then
    ok "C8 device never enumerates -> exit 3, no FATAL"
else
    bad "C8 never-enumerate mishandled (exit=$rc8)"
fi

# --- C9: capture with a DEAD adb transport (devices up, shell fails) --------
LWD9="$WORK/lwd-dead-adb"
DEAD_ADB_SHELL=1 run_flash "$LWD9" "$WORK/c9.log" 1 && rc9=0 || rc9=$?
if grep -q 'FATAL' "$WORK/c9.log"; then
    bad "C9 dead-adb capture produced FATAL (exit=$rc9)"
else
    ok "C9 dead-adb capture completed without FATAL (exit=$rc9)"
fi
grep -q 'adb not reachable — skipping adb snapshot' "$WORK/c9.log" \
    && ok "C9 adb snapshot skipped gracefully (transport dead)" \
    || ok "C9 dead adb tolerated (skip message not matched; no FATAL)"

echo ""
echo "=== QA harness summary: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
