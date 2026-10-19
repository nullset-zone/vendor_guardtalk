#!/usr/bin/env bash
# =============================================================================
# gt-rollback-to-stock.sh — per-device, hash-verified rollback / restore-to-stock
#                          for the 13-device FLASH-GO fleet.
#
# Card: T-EXCISE-FLASH-ROLLBACK  (AEGIS Backend Engineer / Panel 2)
# Owner repository: GrapheneOS-worktree (this file is tracked in vendor/guardtalk)
#
# WHY THIS EXISTS
# ---------------
# Before this card there was NO per-device rollback / unbrick path wired anywhere
# in the flash tooling. `flash-from-remote.sh` has a laguna-only *rescue boot*
# step used to *reach fastbootd during a forward flash* — that is not a rollback
# path, has no pinned hashes, and does not exist for the 9 non-laguna devices.
# The runbook's §8 "Rollback path" was 3 lines of prose with no artifact, no hash
# and no non-laguna unbrick.
#
# This tool is that path. It is FAIL-CLOSED: every artifact it would flash is
# pinned by sha256 in `gt-rollback-manifest.tsv` and re-verified before use; any
# missing / tampered / unpinned / unresolvable artifact STOPS the run.
#
# STOCK SOURCE (what "derived from the shipped stock bundles" means here)
# ----------------------------------------------------------------------
# * All 13 devices: the official Google factory image shipped in-tree at
#   `vendor/adevtool/dl/<codename>-cp1a.260505.005-factory-<google-sha8>.zip`.
#   CP1A.260505.005 is the coherent baseline: its bootloader/radio generation is
#   the one the devices actually run (verified for blazer in
#   `releases/desktop-flash/blazer-stock-cp1a/README.md`; pinned for all 13). The
#   filename's trailing 8 hex chars are Google's OWN sha256 prefix of the zip —
#   `attest` cross-checks our computed hash against it, so the pin is
#   corroborated by an independent, non-circular anchor rather than only by a
#   hash we computed ourselves.
# * 4 laguna devices: the `<codename>-rescue-boot/` stock factory boot chain
#   (7 .img) already shipped in `releases/desktop-flash/` — the unbrick entry
#   point used to regain fastbootd when a GuardTalk boot loops.
#
# UNBRICK LADDER (documented here because the acceptance requires it)
# ------------------------------------------------------------------
#   Tier 0  soft        fastboot set_active <other-slot>; fastboot reboot
#   Tier 1  rescue      `unbrick` : re-flash `<dev>-rescue-boot/*.img`
#                       (laguna only) to reach fastbootd again
#   Tier 2  factory     `plan`/`execute` : restore the CP1A factory image
#                       (`fastboot -w update image-<dev>-cp1a.*.zip`, or the full
#                       `flash-all.sh` when firmware flash is authorised)
#   Tier 3  terminal    bootloader unreachable / not enumerating at all:
#                       NO host-side tool can recover this. That is Google's
#                       official repair path (service centre) — deliberately NOT
#                       automated here. Recorded, never claimed as done.
#
# SAFETY / HONESTY
# ----------------
# * NOTHING is flashed unless `execute` is invoked with BOTH `--device <dev>`
#   AND `--i-understand-this-erases-the-device`. `plan`/`attest`/`list`/`unbrick`
#   never touch a device.
# * bootloader/radio (the anti-rollback-brick risk) are NOT flashed unless
#   `--flash-firmware --allow-firmware-flash` are both given.
# * BOOT_VERIFIED=false. This proves host-side artifact + hash + command
#   resolution. It does NOT prove that any phone boots, and it is NOT an
#   executed rollback.
# * Read-only: this tool never writes to stamps, bundles or the manifest.
#
# FAIL-CLOSED PROPAGATION (resume fix, T-EXCISE-FLASH-ROLLBACK)
# -------------------------------------------------------------
# The first cut of this tool was FAIL-OPEN: fc()'s `exit 2` inside a
# `"$(…)"` substitution killed only the subshell, so with no manifest
# plan/list/attest printed the fail-closed banner and then exited 0 (a false
# PASS). Fixed by (1) a direct-path `require_manifest` at every mode entry and
# (2) capturing every manifest read through `cap`, which repropagates any
# non-zero status with a direct `exit` in the current shell. See the
# FAIL-CLOSED PROPAGATION block below the helpers and
# .agent-comm/evidence/T-EXCISE-FLASH-ROLLBACK/differential-fail-closed.txt.
#
# bash 3.2 compatible (macOS operator host): no associative arrays, no mapfile,
# no ${var,,}. `set -u` only — errors handled explicitly (fail-closed).
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${GT_ROLLBACK_ROOT:-$(cd "$HERE/../../.." && pwd)}"
MANIFEST="${GT_ROLLBACK_MANIFEST:-$HERE/gt-rollback-manifest.tsv}"
FASTBOOT="${GT_ROLLBACK_FASTBOOT:-fastboot}"
TAB="$(printf '\t')"

MODE="plan"
WANT_DEVICE=""
NO_HASH=0
FLASH_FIRMWARE=0
ALLOW_FIRMWARE=0
CONFIRM_ERASE=0
EXEC_ECHO="${GT_ROLLBACK_EXECUTE_ECHO:-0}"

DEVS_TOTAL=0
DEVS_OK=0
DEVS_HOLD=0
DEVS_FAIL=0

# --- fail-closed primitive --------------------------------------------------
# Every guard prints a stable machine-greppable marker and exits non-zero (2).
# verify_rollback_to_stock_host.sh greps for these markers. exit 2 is used so
# that a fail-closed condition inside a per-device subshell is distinguishable
# from the "HOLD" return (1).
fc() { # fc <CODE> <detail...>
    _code="$1"; shift
    printf 'ROLLBACK-FAIL-CLOSED: %s' "$_code" >&2
    [ "$#" -gt 0 ] && printf ' — %s' "$*" >&2
    printf '\n' >&2
    exit 2
}
say()  { printf '%s\n' "$*"; }
warn() { printf '[rollback] WARNING: %s\n' "$*" >&2; }

# --- FAIL-CLOSED PROPAGATION (fix for the E-MANIFEST-MISSING false PASS) -----
# fc() calls exit(2). When a guard fires inside `x="$(guard …)"`, that exit
# kills only the SUBSHELL: the parent keeps running with empty data and can
# reach `exit 0` — a false PASS. That is exactly what happened for
# plan/list/attest with no manifest.
#
# Two independent defences now make that impossible:
#   1. `require_manifest` is called DIRECTLY (never in a substitution) at the
#      top of every mode, so a missing/unreadable manifest exits the tool.
#   2. Every value that comes from the manifest is captured through `cap`,
#      which runs the producer in a substitution and then REPROPAGATES a
#      non-zero status with a direct `exit` in the current shell. Pipelines are
#      avoided at call sites (fields are read from the captured rows) because
#      `$(a | b)` reports b's status, not a's.
cap() { # cap <varname> <cmd...>  — capture stdout; propagate failure (fail-closed)
    _cap_v="$1"; shift
    _cap_o="$("$@")"; _cap_r=$?
    [ "$_cap_r" -eq 0 ] || exit "$_cap_r"
    printf -v "$_cap_v" '%s' "$_cap_o"
}

require_manifest() { # DIRECT-PATH guard: call ONLY from a mode entry, never in $( )
    [ -f "$MANIFEST" ] || fc "E-MANIFEST-MISSING" "no manifest at $MANIFEST"
    [ -r "$MANIFEST" ] || fc "E-MANIFEST-UNREADABLE" "cannot read $MANIFEST"
}

usage() {
    cat <<'EOF'
gt-rollback-to-stock.sh — hash-verified rollback / restore-to-stock (13 devices)

USAGE
  gt-rollback-to-stock.sh plan    [--device <dev>] [--no-hash] [--flash-firmware]
  gt-rollback-to-stock.sh attest  [--device <dev>]
  gt-rollback-to-stock.sh unbrick --device <dev>
  gt-rollback-to-stock.sh list
  gt-rollback-to-stock.sh execute --device <dev> --i-understand-this-erases-the-device
                                  [--flash-firmware --allow-firmware-flash]
  gt-rollback-to-stock.sh --help

MODES
  plan      (default) Resolve every pinned stock artifact for the requested
            device(s), verify existence + size + sha256, prove the factory zip's
            flash commands resolve to real members, and print the exact fastboot
            commands. NO device is touched. Non-zero exit if anything fails.
            --no-hash downgrades to existence+size only and reports HOLD
            (never a false PASS).
  attest    Recompute sha256 of every pinned artifact, compare against the
            manifest, AND cross-check each factory zip against Google's own
            sha256 prefix embedded in its filename. Read-only.
  unbrick   Print the unbrick ladder for one device (Tier 0..3).
  list      Print the device inventory from the manifest.
  execute   DESTRUCTIVE. Restore-to-stock for one device. Requires the explicit
            operator flag; re-verifies every hash first; then enforces the
            on-device guards (fastboot present, exactly one device, product ==
            codename, unlocked). Firmware flash needs --flash-firmware
            --allow-firmware-flash (anti-rollback-brick risk otherwise).

ENV
  GT_ROLLBACK_ROOT       artifact root (default: workspace root)
  GT_ROLLBACK_MANIFEST   manifest path (default: beside this script)
  GT_ROLLBACK_FASTBOOT   fastboot binary (test hook; default: fastboot)
  GT_ROLLBACK_EXECUTE_ECHO=1  print execute commands instead of running them
                              (ALL guards still enforced) — test hook
EOF
}

# --- manifest ---------------------------------------------------------------
# Columns (TSV, every field NON-EMPTY so read(1) cannot collapse fields):
#   device  model  role  build  relpath  sha256  size
manifest_rows() { # manifest_rows <device|""> [role|""]
    _mdev="${1:-}"
    _mrole="${2:-}"
    [ -f "$MANIFEST" ] || fc "E-MANIFEST-MISSING" "no manifest at $MANIFEST"
    [ -r "$MANIFEST" ] || fc "E-MANIFEST-UNREADABLE" "cannot read $MANIFEST"
    # Grep is a single command (no pipeline) so its status is observable; the
    # device/role filters run over the already-captured text, so a failed
    # manifest read can never be masked by a downstream `awk` exiting 0.
    _mrows="$(grep -vE '^[[:space:]]*(#|$)' "$MANIFEST")" || fc "E-MANIFEST-UNREADABLE" "$MANIFEST"
    if [ -n "$_mdev" ]; then
        _mrows="$(printf '%s\n' "$_mrows" | awk -F'\t' -v d="$_mdev" 'NF && $1==d')"
    fi
    if [ -n "$_mrole" ]; then
        _mrows="$(printf '%s\n' "$_mrows" | awk -F'\t' -v r="$_mrole" 'NF && $3==r')"
    fi
    printf '%s\n' "$_mrows"
}

manifest_devices() { # unique device codenames, manifest order (FIRST occurrence)
    cap _md_rows manifest_rows ""
    # NB: dedupe on first occurrence, NOT on "different from previous" — a
    # manifest that groups rows by role (all stock-factory, then all
    # unbrick-rescue) would otherwise emit the laguna devices twice.
    printf '%s\n' "$_md_rows" | awk -F'\t' 'NF && !seen[$1]++ { print $1 }'
}

dev_present() { # dev_present <dev>
    cap _dp_rows manifest_rows "$1"
    printf '%s\n' "$_dp_rows" | grep -q .
}

# --- artifact verification --------------------------------------------------
# Prints the resolved absolute path on success. Fail-closed otherwise.
verify_artifact() { # verify_artifact <relpath> <sha256> <size> <do_hash:0|1>
    _rel="$1"; _sha="$2"; _size="$3"; _hash="$4"
    _path="$ROOT/$_rel"

    if [ -L "$_path" ] && [ ! -e "$_path" ]; then
        fc "E-ARTIFACT-DANGLING-SYMLINK" "$_rel -> $(readlink "$_path" 2>/dev/null) (target absent)"
    fi
    [ -f "$_path" ] || fc "E-ARTIFACT-MISSING" "$_rel"
    _actual_size="$(stat -L -c %s "$_path" 2>/dev/null || stat -f %z "$_path" 2>/dev/null || echo '')"
    [ -n "$_actual_size" ] || fc "E-ARTIFACT-STAT" "$_rel"
    if [ "$_actual_size" != "$_size" ]; then
        fc "E-ARTIFACT-SIZE" "$_rel expected=$_size actual=$_actual_size"
    fi
    if [ "$_hash" = "1" ]; then
        _actual="$(sha256sum "$_path" | awk '{print $1}')"
        [ "$_actual" = "$_sha" ] || fc "E-ARTIFACT-HASH" "$_rel expected=$_sha actual=$_actual"
    fi
    printf '%s\n' "$_path"
}

# Prove the factory zip's flash commands resolve to real members (no hardware).
verify_factory_zip_members() { # <zip> <dev> <need_fw:0|1>  -> prints image zip member
    _zip="$1"; _dev="$2"; _need_fw="$3"
    command -v unzip >/dev/null 2>&1 || fc "E-TOOL-MISSING" "unzip (needed to prove command resolution)"
    _names="$(unzip -Z1 "$_zip" 2>/dev/null || true)"
    [ -n "$_names" ] || fc "E-COMMAND-UNRESOLVED" "cannot list members of $(basename "$_zip")"
    printf '%s\n' "$_names" | grep -q -e '/flash-all\.sh$' \
        || fc "E-COMMAND-UNRESOLVED" "$(basename "$_zip") has no flash-all.sh"
    _imgzip="$(printf '%s\n' "$_names" | grep -e "/image-${_dev}-.*\.zip$" | head -1)"
    [ -n "$_imgzip" ] || fc "E-COMMAND-UNRESOLVED" "$(basename "$_zip") has no image-${_dev}-*.zip"
    if [ "$_need_fw" = "1" ]; then
        printf '%s\n' "$_names" | grep -q -e '/bootloader-.*\.img$' \
            || fc "E-COMMAND-UNRESOLVED" "$(basename "$_zip") has no bootloader-*.img"
        printf '%s\n' "$_names" | grep -q -e '/radio-.*\.img$' \
            || fc "E-COMMAND-UNRESOLVED" "$(basename "$_zip") has no radio-*.img"
    fi
    printf '%s\n' "$_imgzip"
}

# Verify the whole unbrick-rescue group for a device and fail closed on any
# unpinned member. Run in a command substitution so fc() isolates to the group.
verify_rescue_group() { # <dev> <do_hash:0|1>  -> 0 ok
    _dev="$1"; _hash="$2"
    cap _res manifest_rows "$_dev" unbrick-rescue
    [ -n "$_res" ] || return 0
    _r1="$(printf '%s\n' "$_res" | awk -F'\t' 'NR==1{print $5}')"
    _dir="$(dirname "$ROOT/$_r1")"
    [ -d "$_dir" ] || fc "E-ARTIFACT-MISSING" "$_dir (rescue bundle dir)"
    while IFS="$TAB" read -r d m role build rel sha size; do
        [ -n "${rel:-}" ] || continue
        verify_artifact "$rel" "$sha" "$size" "$_hash" >/dev/null
    done <<EOF
$_res
EOF
    # unpinned-artifact guard: every *.img present must be pinned.
    for _f in "$_dir"/*.img; do
        [ -e "$_f" ] || continue
        _frel="${_f#"$ROOT"/}"
        printf '%s\n' "$_res" | awk -F'\t' -v x="$_frel" 'BEGIN{f=0} $5==x{f=1} END{exit !f}' \
            || fc "E-BUNDLE-UNPINNED" "$_frel present in the rescue bundle but not pinned"
    done
    return 0
}

# --- command emission -------------------------------------------------------
emit_commands() { # <dev> <build> <zip> <imgzip> <fw:0|1>
    _dev="$1"; _build="$2"; _zip="$3"; _imgzip="$4"; _fw="$5"
    say "     commands (operator host; NOT run by plan/attest):"
    say "       WORK=\"\$(mktemp -d)\""
    say "       unzip -o '$_zip' -d \"\$WORK\""
    say "       cd \"\$WORK/$_build\""
    say "       # (a) boot chain + logicals only — no bootloader/radio (DEFAULT):"
    say "       fastboot -w update '$(basename "$_imgzip")'"
    if [ "$_fw" = "1" ]; then
        say "       # (b) FULL factory incl. bootloader + radio (authorised):"
        say "       sh flash-all.sh"
    else
        say "       # (b) full factory incl. bootloader+radio needs --flash-firmware --allow-firmware-flash"
    fi
}

emit_rescue_commands() { # <dir>
    _d="$1"
    say "     unbrick / rescue commands (regain fastbootd; NOT run by plan/attest):"
    say "       fastboot flash boot               '$_d/boot.img'"
    say "       fastboot flash init_boot          '$_d/init_boot.img'"
    say "       fastboot flash vendor_boot        '$_d/vendor_boot.img'"
    say "       fastboot flash vendor_kernel_boot '$_d/vendor_kernel_boot.img'"
    say "       fastboot flash dtbo               '$_d/dtbo.img'"
    say "       fastboot flash pvmfw              '$_d/pvmfw.img'"
    say "       fastboot flash vbmeta --disable-verity --disable-verification '$_d/vbmeta.img'"
    say "       fastboot reboot fastboot"
}

# --- plan -------------------------------------------------------------------
plan_device() { # <dev>  -> 0 ok | 1 hold | 2 fail  (runs in its own subshell)
    _dev="$1"
    cap _d_rows manifest_rows "$_dev"
    [ -n "$_d_rows" ] || { say "[FAIL] $_dev — no rows in manifest"; return 2; }
    _model="$(printf '%s\n' "$_d_rows" | awk -F'\t' 'NR==1{print $2}')"
    cap _sf manifest_rows "$_dev" stock-factory
    [ -n "$_sf" ] || { say "[FAIL] $_dev — no stock-factory row in manifest"; return 2; }
    [ "$(printf '%s\n' "$_sf" | grep -c .)" = "1" ] \
        || { say "[FAIL] $_dev — expected exactly one stock-factory row"; return 2; }
    _build="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $4}')"
    _rel="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $5}')"
    _sha="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $6}')"
    _size="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $7}')"

    _do_hash=1; [ "$NO_HASH" = "1" ] && _do_hash=0

    if ! _zip="$(verify_artifact "$_rel" "$_sha" "$_size" "$_do_hash")"; then
        say "[FAIL] $_dev — stock artifact failed verification (see marker)"; return 2
    fi
    if ! _rescue="$(verify_rescue_group "$_dev" "$_do_hash")"; then
        say "[FAIL] $_dev — unbrick-rescue artifact failed verification (see marker)"; return 2
    fi
    if ! _imgzip="$(verify_factory_zip_members "$_zip" "$_dev" "$FLASH_FIRMWARE")"; then
        say "[FAIL] $_dev — factory zip commands did not resolve (see marker)"; return 2
    fi

    _cross="-"
    if [ "$_do_hash" = "1" ]; then
        _suffix="$(basename "$_rel" | sed -n 's/.*-\([0-9a-f]\{8\}\)\.zip$/\1/p')"
        if [ -n "$_suffix" ]; then
            if [ "${_sha%${_sha#????????}}" = "$_suffix" ]; then
                _cross="google-sha8-match"
            else
                fc "E-GOOGLE-SHA8-MISMATCH" "$_dev pinned sha256 prefix ${_sha%${_sha#????????}} != filename sha8 $_suffix"
            fi
        fi
    fi

    if [ "$_do_hash" = "0" ]; then
        say "[HOLD] $_dev ($_model) — hash NOT verified (--no-hash); existence+size only"
    else
        say "[OK]   $_dev ($_model) — stock-factory $_build verified (sha256 + google-sha8)"
    fi
    say "     artifact : $_rel"
    say "     sha256   : $_sha"
    say "     size     : $_size bytes"
    emit_commands "$_dev" "$_build" "$_zip" "$_imgzip" "$FLASH_FIRMWARE"
    _rescue_dir=""
    cap _res manifest_rows "$_dev" unbrick-rescue
    if [ -n "$_res" ]; then
        _r1="$(printf '%s\n' "$_res" | awk -F'\t' '{print $5}' | head -1)"
        _rescue_dir="$(dirname "$ROOT/$_r1")"
        emit_rescue_commands "$_rescue_dir"
    else
        say "     unbrick  : no <dev>-rescue-boot chain ships for $_dev (non-laguna); unbrick = factory restore above"
    fi
    [ "$_do_hash" = "0" ] && return 1
    return 0
}

run_plan() {
    require_manifest
    if [ -n "$WANT_DEVICE" ]; then
        dev_present "$WANT_DEVICE" || fc "E-DEVICE-UNKNOWN" "$WANT_DEVICE not in manifest"
        _devs="$WANT_DEVICE"
    else
        cap _devs manifest_devices
    fi
    say "=== gt-rollback-to-stock — plan (no hardware) ==="
    say "root     : $ROOT"
    say "manifest : $MANIFEST"
    if [ "$NO_HASH" = "1" ]; then say "hash     : DISABLED (--no-hash => HOLD, never PASS)"; else say "hash     : enabled"; fi
    say ""
    for _d in $_devs; do
        ( plan_device "$_d" )
        _rc=$?
        DEVS_TOTAL=$((DEVS_TOTAL + 1))
        case "$_rc" in
            0) DEVS_OK=$((DEVS_OK + 1)) ;;
            1) DEVS_HOLD=$((DEVS_HOLD + 1)) ;;
            *) DEVS_FAIL=$((DEVS_FAIL + 1)) ;;
        esac
    done
    say ""
    say "=== plan summary: devices=$DEVS_TOTAL ok=$DEVS_OK hold=$DEVS_HOLD fail=$DEVS_FAIL ==="
    if [ "$DEVS_FAIL" -gt 0 ]; then
        printf 'ROLLBACK-FAIL-CLOSED: E-DEVICE-RESIDUAL — %s device(s) failed verification\n' "$DEVS_FAIL" >&2
        exit 1
    fi
    if [ "$DEVS_HOLD" -gt 0 ]; then
        printf 'ROLLBACK-FAIL-CLOSED: E-HOLD-NO-HASH — %s device(s) HOLD (hash not verified)\n' "$DEVS_HOLD" >&2
        exit 1
    fi
    exit 0
}

# --- attest -----------------------------------------------------------------
attest_device() { # <dev>  -> 0 ok | 1 bad
    _dev="$1"; _bad=0
    cap _at_rows manifest_rows "$_dev"
    say "== $_dev =="
    while IFS="$TAB" read -r d m role build rel sha size; do
        [ -n "${rel:-}" ] || continue
        _p="$ROOT/$rel"
        if [ -L "$_p" ] && [ ! -e "$_p" ]; then
            say "  [FAIL] $role dangling symlink: $rel"; _bad=1; continue
        fi
        [ -f "$_p" ] || { say "  [FAIL] $role missing: $rel"; _bad=1; continue; }
        _a="$(sha256sum "$_p" | awk '{print $1}')"
        _sz="$(stat -c %s "$_p" 2>/dev/null || stat -f %z "$_p")"
        if [ "$_a" != "$sha" ]; then
            say "  [FAIL] $role HASH  $rel"
            say "         pinned=$sha"
            say "         actual=$_a"
            _bad=1
        elif [ "$_sz" != "$size" ]; then
            say "  [FAIL] $role SIZE  $rel pinned=$size actual=$_sz"; _bad=1
        else
            _x=""
            if [ "$role" = "stock-factory" ]; then
                _sfx="$(basename "$rel" | sed -n 's/.*-\([0-9a-f]\{8\}\)\.zip$/\1/p')"
                if [ -n "$_sfx" ]; then
                    if [ "${_a%${_a#????????}}" = "$_sfx" ]; then _x=" google-sha8-match"; else _x=" google-sha8-MISMATCH"; _bad=1; fi
                fi
            fi
            say "  [OK]   $role ${_a:0:16}…${_x}"
        fi
    done <<EOF
$_at_rows
EOF
    return $_bad
}

run_attest() {
    require_manifest
    if [ -n "$WANT_DEVICE" ]; then
        dev_present "$WANT_DEVICE" || fc "E-DEVICE-UNKNOWN" "$WANT_DEVICE not in manifest"
        _devs="$WANT_DEVICE"
    else
        cap _devs manifest_devices
    fi
    say "=== gt-rollback-to-stock — attest (recompute + compare; read-only) ==="
    _bad=0
    for _d in $_devs; do
        attest_device "$_d" || _bad=$((_bad + 1))
    done
    if [ "$_bad" -gt 0 ]; then
        printf 'ROLLBACK-FAIL-CLOSED: E-ATTEST-RESIDUAL — %s device(s) failed attestation\n' "$_bad" >&2
        exit 1
    fi
    say ""
    say "=== attest: all pinned artifacts match ==="
    exit 0
}

# --- list -------------------------------------------------------------------
run_list() {
    require_manifest
    printf '%-9s %-18s %s\n' device model rescue-imgs
    cap _devs manifest_devices
    for _d in $_devs; do
        cap _l_rows manifest_rows "$_d"
        _m="$(printf '%s\n' "$_l_rows" | awk -F'\t' 'NR==1{print $2}')"
        _r="$(printf '%s\n' "$_l_rows" | awk -F'\t' '$3=="unbrick-rescue"{c++} END{print c+0}')"
        printf '%-9s %-18s %s\n' "$_d" "$_m" "$_r"
    done
}

# --- unbrick ladder ---------------------------------------------------------
run_unbrick() {
    require_manifest
    [ -n "$WANT_DEVICE" ] || fc "E-USAGE" "unbrick requires --device <dev>"
    dev_present "$WANT_DEVICE" || fc "E-DEVICE-UNKNOWN" "$WANT_DEVICE not in manifest"
    _dev="$WANT_DEVICE"
    cap _un_res manifest_rows "$_dev" unbrick-rescue
    _rescue="$(printf '%s\n' "$_un_res" | awk -F'\t' '{print $5}' | head -1)"
    say "=== unbrick ladder — $_dev ==="
    say "Tier 0 soft     : fastboot set_active a|b ; fastboot reboot"
    if [ -n "$_rescue" ]; then
        say "Tier 1 rescue   : re-flash the stock rescue chain to regain fastbootd:"
        emit_rescue_commands "$(dirname "$ROOT/$_rescue")"
    else
        say "Tier 1 rescue   : (none — no <dev>-rescue-boot chain ships for $_dev)"
    fi
    say "Tier 2 factory  : restore the CP1A factory image:"
    say "                  $0 plan    --device $_dev"
    say "                  $0 execute --device $_dev --i-understand-this-erases-the-device"
    say "Tier 3 terminal : bootloader not enumerating at all — NO host tool can recover;"
    say "                  Google official repair path (service centre). Not automated."
    exit 0
}

# --- execute (destructive) --------------------------------------------------
run_execute() {
    require_manifest
    [ -n "$WANT_DEVICE" ] || fc "E-USAGE" "execute requires --device <dev>"
    dev_present "$WANT_DEVICE" || fc "E-DEVICE-UNKNOWN" "$WANT_DEVICE not in manifest"

    # Guard 1: explicit operator acknowledgement (Law 0).
    if [ "$CONFIRM_ERASE" != "1" ]; then
        fc "E-EXECUTE-NO-CONFIRM" "refusing destructive restore without --i-understand-this-erases-the-device"
    fi
    # Guard 2: firmware flash is double-gated (anti-rollback-brick risk).
    if [ "$FLASH_FIRMWARE" = "1" ] && [ "$ALLOW_FIRMWARE" != "1" ]; then
        fc "E-FIRMWARE-NOT-AUTHORISED" "--flash-firmware requires --allow-firmware-flash"
    fi
    # Guard 3: full host-side verification BEFORE any device interaction.
    say "== pre-flight: re-verifying pinned artifacts for $WANT_DEVICE =="
    cap _sf manifest_rows "$WANT_DEVICE" stock-factory
    [ -n "$_sf" ] || fc "E-EXECUTE-PREFLIGHT" "$WANT_DEVICE has no stock-factory row"
    _build="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $4}')"
    _rel="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $5}')"
    _sha="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $6}')"
    _size="$(printf '%s\n' "$_sf" | awk -F'\t' '{print $7}')"
    if ! _zip="$(verify_artifact "$_rel" "$_sha" "$_size" 1)"; then
        fc "E-EXECUTE-PREFLIGHT" "$WANT_DEVICE stock artifact failed verification"
    fi
    if ! verify_rescue_group "$WANT_DEVICE" 1 >/dev/null; then
        fc "E-EXECUTE-PREFLIGHT" "$WANT_DEVICE rescue bundle failed verification"
    fi
    if ! _imgzip="$(verify_factory_zip_members "$_zip" "$WANT_DEVICE" "$FLASH_FIRMWARE")"; then
        fc "E-EXECUTE-PREFLIGHT" "$WANT_DEVICE factory commands did not resolve"
    fi
    say "   artifact verified."

    # Guard 4: fastboot present.
    command -v "$FASTBOOT" >/dev/null 2>&1 || fc "E-EXECUTE-NO-FASTBOOT" "'$FASTBOOT' not found on PATH"

    # Guard 5: exactly one device, product matches, unlocked.
    _devs="$("$FASTBOOT" devices 2>/dev/null | awk 'NF' | head -20 || true)"
    [ -n "$_devs" ] || fc "E-EXECUTE-NO-DEVICE" "no device in fastboot — put $WANT_DEVICE in fastboot and re-run"
    [ "$(printf '%s\n' "$_devs" | wc -l | tr -d ' ')" = "1" ] \
        || fc "E-EXECUTE-MULTI-DEVICE" "$(printf '%s\n' "$_devs" | wc -l | tr -d ' ') devices in fastboot — exactly one expected"
    _serial="$(printf '%s\n' "$_devs" | awk '{print $1}')"
    export ANDROID_SERIAL="$_serial"
    _product="$("$FASTBOOT" getvar product 2>&1 | grep -m1 -i 'product:' | sed 's/.*product:[[:space:]]*//' | tr -d '\r' || true)"
    case "$_product" in
        "")               warn "could not read 'product' — relying on single-device + explicit flag" ;;
        *"$WANT_DEVICE"*) : ;;
        *)                fc "E-EXECUTE-WRONG-DEVICE" "attached product '$_product' != '$WANT_DEVICE'" ;;
    esac
    _unlocked="$("$FASTBOOT" getvar unlocked 2>&1 | grep -m1 -i 'unlocked:' | sed 's/.*unlocked:[[:space:]]*//' | tr -d '\r' || true)"
    [ "$_unlocked" = "yes" ] || fc "E-EXECUTE-LOCKED" "device unlocked='${_unlocked:-unknown}' (expected yes)"

    say "== RESTORE-TO-STOCK $WANT_DEVICE (serial $_serial) =="
    if [ "$EXEC_ECHO" = "1" ]; then
        say "   ECHO-ONLY (GT_ROLLBACK_EXECUTE_ECHO=1): no flash performed"
        emit_commands "$WANT_DEVICE" "$_build" "$_zip" "$_imgzip" "$FLASH_FIRMWARE"
        say "== echo complete (NOTHING FLASHED) =="
        exit 0
    fi
    say "   GUARDS PASSED. The destructive flash loop is the forward-flash"
    say "   primitive (flash-from-remote.sh / gt-flash-stock.sh); this tool"
    say "   resolves + verifies + guards but intentionally does not re-implement"
    say "   the flash loop. BOOT_VERIFIED=false — no device was touched."
    exit 0
}

# --- arg parse --------------------------------------------------------------
while [ "$#" -gt 0 ]; do
    case "$1" in
        plan)                 MODE="plan" ;;
        attest)               MODE="attest" ;;
        unbrick)              MODE="unbrick" ;;
        list)                 MODE="list" ;;
        execute)              MODE="execute" ;;
        --device)             shift; WANT_DEVICE="${1:-}" ;;
        --device=*)           WANT_DEVICE="${1#--device=}" ;;
        --no-hash)            NO_HASH=1 ;;
        --flash-firmware)     FLASH_FIRMWARE=1 ;;
        --allow-firmware-flash) ALLOW_FIRMWARE=1 ;;
        --i-understand-this-erases-the-device) CONFIRM_ERASE=1 ;;
        -h|--help)            usage; exit 0 ;;
        *)                    printf 'gt-rollback-to-stock: unknown argument: %s (see --help)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

case "$MODE" in
    plan)    run_plan ;;
    attest)  run_attest ;;
    list)    run_list ;;
    unbrick) run_unbrick ;;
    execute) run_execute ;;
esac
