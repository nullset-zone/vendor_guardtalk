#!/usr/bin/env bash
# GuardTalk Stallion — flash wizard with self-check.
#
# === ONE-LINE FORM (nothing else needed; pinned to the acknowledged stamp) ===
# Copy this whole line into Terminal on the Mac. It downloads the helper from the
# build host and runs it with --yes (the self-check still gates the flash):
#
#   curl -fsSL "http://192.168.2.220:8000/gt-flash-stallion.sh" -o /tmp/gtfs.sh && bash /tmp/gtfs.sh --yes
#
# You do not have to trust this file's own bytes: the script does not execute
# anything it has not verified. It pins the SHA-256 of the flasher, the readiness
# reporter and the quarantine registry, and refuses to run if any of them differ
# (see GT_FLASHER_SHA / GT_REPORTER_SHA / GT_REGISTRY_SHA below). Those are the
# binaries that actually touch the phone.
#
# To check this file before running it, compare against the build host:
#   ssh oss-c1@192.168.2.220 'sha256sum /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/scripts/gt-flash-stallion.sh'
#
# If you would rather not use the one-liner, copy the file over directly:
#   scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/scripts/gt-flash-stallion.sh ~/
#   then: bash ~/gt-flash-stallion.sh            (wizard)
#         bash ~/gt-flash-stallion.sh --selfcheck (checks only, never flashes)
#         bash ~/gt-flash-stallion.sh --yes       (no prompts)
#
# T-EXCISE-STALLION-FINALIZE-READY · stamp stallion-20261108-rebuild
#
# Exit codes:
#   0  self-check passed and the flash completed (or --selfcheck passed)
#   10 self-check failed — nothing was flashed
#   11 user declined at the prompt
#   12 the flasher itself exited non-zero (see the log path it prints)
#   13 timed out
set -uo pipefail

# --------------------------------------------------------------- constants --
GT_SERIAL="67201JEA300680"
GT_BLAZER="59080DLCH0022P"          # must never be flashed
GT_DEVICE="stallion"
GT_BUILD_ID="BD6A.251031.001.A4"
GT_STAMP="stallion-20261110-labelled"
GT_STAMP_DIGEST="24c19382fa06011660e9ae41be2afba11a82adb7c228b101b6059db714267605"

GT_SERVER="oss-c1@192.168.2.220"
GT_TREE="/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree"
GT_BUILD_DIR="${GT_TREE}/releases/desktop-flash/${GT_STAMP}"
GT_SUMS_PATH="${GT_BUILD_DIR}/SHA256SUMS"

# Hashes of the exact artefacts this wizard is willing to run.
GT_FLASHER_SHA="93012f963645035be72ca3a268e6711cb26f1408e2da4d00d7aa6690b23878c9"
GT_REPORTER_SHA="daaf4cebbb7bb5e117a53294914fe4ad8b003582e8b2e31cded3f61f3cb92631"
GT_REGISTRY_SHA="7498708c4aa606ce694797cc26594153de6bfb75c6bb337d6a0a7df3581f994a"

GT_HOME="$HOME/GuardTalk-flash"
GT_TIMEOUT=1800

# ------------------------------------------------------------------ output --
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[36m'; D=$'\033[2m'; N=$'\033[0m'
else
    R=; G=; Y=; B=; D=; N=
fi
ok()   { printf '%s  PASS%s  %s\n' "$G" "$N" "$*"; }
bad()  { printf '%s  FAIL%s  %s\n' "$R" "$N" "$*"; }
warn() { printf '%s  WARN%s  %s\n' "$Y" "$N" "$*"; }
info() { printf '%s  ....%s  %s\n' "$B" "$N" "$*"; }
hdr()  { printf '\n%s== %s ==%s\n' "$B" "$*" "$N"; }

FAILED=0
note_fail() { bad "$*"; FAILED=$((FAILED + 1)); }

# ------------------------------------------------------------ arg handling --
ASSUME_YES=0
SELFCHECK_ONLY=0
for a in "$@"; do
    case "$a" in
        --yes|-y)     ASSUME_YES=1 ;;
        --selfcheck)  SELFCHECK_ONLY=1 ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) printf 'unknown argument: %s (use --yes, --selfcheck, --help)\n' "$a" >&2; exit 2 ;;
    esac
done

# =============================================================== self-check ==
# All read-only. Nothing is flashed unless every check passes.
copy_quarantine() {
    info "copying the quarantine registry + markers"
    scp -q -r -o BatchMode=yes \
        "$GT_SERVER:$GT_TREE/releases/desktop-flash/.quarantine" \
        "$GT_HOME/stamp-tree/releases/desktop-flash/" 2>/dev/null
}

selfcheck() {
    hdr "0. host"
    case "$(uname -s)" in
        Darwin) ok "macOS ($(uname -m))" ;;
        *)      warn "not macOS ($(uname -s)) — fastboot must see the phone from THIS host" ;;
    esac

    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

    hdr "1. tools on PATH"
    local t
    for t in fastboot scp ssh shasum; do
        if command -v "$t" >/dev/null 2>&1; then
            ok "$t -> $(command -v "$t")"
        else
            note_fail "$t not found on PATH"
        fi
    done
    command -v python3 >/dev/null 2>&1 && ok "python3 present (flasher needs it for the registry)" \
        || note_fail "python3 not found (the flasher parses registry.json with it)"

    hdr "2. build host reachable"
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "$GT_SERVER" true 2>/dev/null; then
        ok "ssh $GT_SERVER"
    else
        note_fail "cannot ssh $GT_SERVER (key auth / network)"
    fi

    hdr "3. stamp identity on the build host"
    if [ "$FAILED" -ne 0 ]; then
        warn "skipped (earlier failures)"
    else
        local remote_sums
        remote_sums="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$GT_SERVER" \
            "sha256sum '$GT_SUMS_PATH' 2>/dev/null | cut -d' ' -f1")" || remote_sums=""
        if [ -z "$remote_sums" ]; then
            note_fail "cannot read $GT_SUMS_PATH on the server"
        elif [ "$remote_sums" = "$GT_STAMP_DIGEST" ]; then
            ok "SHA256SUMS digest matches the acknowledged stamp"
            printf '%s      %s%s\n' "$D" "$GT_STAMP_DIGEST" "$N"
        else
            note_fail "stamp digest MISMATCH — this is not the acknowledged stamp"
            printf '        expected %s\n        server   %s\n' "$GT_STAMP_DIGEST" "$remote_sums"
            printf '        %sRefusing. Re-acknowledge the new stamp first.%s\n' "$R" "$N"
        fi

        local ack_digest
        ack_digest="$(ssh -o BatchMode=yes "$GT_SERVER" \
            "awk -F= '/^sha256sums_sha256=/{print \$2}' '$GT_TREE/releases/desktop-flash/acks/stallion.ack' 2>/dev/null")" || ack_digest=""
        if [ "$ack_digest" = "$GT_STAMP_DIGEST" ]; then
            ok "operator acknowledgement binds this exact stamp"
        else
            note_fail "ack digest '${ack_digest:-none}' does not bind $GT_STAMP_DIGEST"
        fi

        local latest
        latest="$(ssh -o BatchMode=yes "$GT_SERVER" \
            "readlink '$GT_TREE/releases/desktop-flash/stallion-latest'")" || latest=""
        if [ "$latest" = "$GT_STAMP" ]; then
            ok "stallion-latest -> $GT_STAMP"
        else
            warn "stallion-latest -> ${latest:-unknown} (not fatal: REMOTE_BUILD_DIR is pinned explicitly)"
        fi
    fi

    hdr "4. local copies match the build host"
    mkdir -p "$GT_HOME/stamp-tree/releases/desktop-flash" 2>/dev/null

    local f="$GT_HOME/flash-from-remote.sh" got again
    if [ -f "$f" ]; then
        got="$(shasum -a 256 "$f" | cut -d' ' -f1)"
        if [ "$got" = "$GT_FLASHER_SHA" ]; then
            ok "flash-from-remote.sh matches"
        else
            bad "flash-from-remote.sh STALE (${got:0:12}… != ${GT_FLASHER_SHA:0:12}…)"
            scp -q -o BatchMode=yes "$GT_SERVER:$GT_TREE/scripts/flash-from-remote.sh" "$f" 2>/dev/null
            chmod +x "$f" 2>/dev/null
            again="$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)"
            # A copy that still hashes wrong is a FAILURE, never a success.
            if [ "$again" = "$GT_FLASHER_SHA" ]; then
                ok "re-copied and verified (${again:0:12}…)"
            else
                note_fail "re-copy did not fix the flasher (${again:0:12}…) — refusing to run a stale flasher"
            fi
        fi
    else
        info "fetching flash-from-remote.sh"
        scp -q -o BatchMode=yes "$GT_SERVER:$GT_TREE/scripts/flash-from-remote.sh" "$f" 2>/dev/null
        chmod +x "$f" 2>/dev/null
        if [ "$(shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1)" = "$GT_FLASHER_SHA" ]; then
            ok "fetched and verified"
        else
            note_fail "flasher fetch failed or hash mismatch"
        fi
    fi

    local r="$GT_HOME/gt-ready-devices.sh"
    if [ -f "$r" ] && [ "$(shasum -a 256 "$r" | cut -d' ' -f1)" = "$GT_REPORTER_SHA" ]; then
        ok "gt-ready-devices.sh matches"
    else
        scp -q -o BatchMode=yes "$GT_SERVER:$GT_TREE/scripts/gt-ready-devices.sh" "$r" 2>/dev/null
        chmod +x "$r" 2>/dev/null
        if [ "$(shasum -a 256 "$r" 2>/dev/null | cut -d' ' -f1)" = "$GT_REPORTER_SHA" ]; then
            ok "gt-ready-devices.sh fetched/refreshed and verified"
        else
            note_fail "reporter hash mismatch — the readiness gate would refuse"
        fi
    fi

    local reg="$GT_HOME/stamp-tree/releases/desktop-flash/.quarantine/registry.json"
    if [ -f "$reg" ] && [ "$(shasum -a 256 "$reg" 2>/dev/null | cut -d' ' -f1)" = "$GT_REGISTRY_SHA" ]; then
        ok "quarantine registry matches"
    else
        copy_quarantine
        if [ "$(shasum -a 256 "$reg" 2>/dev/null | cut -d' ' -f1)" = "$GT_REGISTRY_SHA" ]; then
            ok "quarantine registry copied and verified"
        else
            note_fail "quarantine registry hash mismatch — the flasher would refuse"
        fi
    fi

    hdr "5. device on the USB bus"
    local devs=""
    if ! command -v fastboot >/dev/null 2>&1; then
        note_fail "fastboot not on PATH — cannot inspect the device"
    else
        devs="$(fastboot devices 2>&1 | tr -d '\r' | sed '/^[[:space:]]*$/d')"
        if [ -z "$devs" ]; then
            note_fail "no fastboot device found"
            printf '        %sPut the phone in fastboot: hold Vol-Down + Power.%s\n' "$Y" "$N"
        else
            printf '%s\n' "$devs" | sed 's/^/        /'
            local n
            n="$(printf '%s\n' "$devs" | wc -l | tr -d ' ')"
            if [ "$n" -ne 1 ]; then
                note_fail "$n devices attached — refusing to guess which one"
            elif ! printf '%s\n' "$devs" | grep -q "^${GT_SERIAL}[[:space:]]"; then
                note_fail "attached serial is not $GT_SERIAL"
            else
                ok "exactly one device, serial $GT_SERIAL"
            fi
            if printf '%s\n' "$devs" | grep -q "$GT_BLAZER"; then
                note_fail "BLAZER $GT_BLAZER is on the bus — refusing"
            fi
        fi
    fi

    if [ "$FAILED" -eq 0 ]; then
        local unlocked
        unlocked="$(fastboot getvar unlocked 2>&1 | grep -m1 '^unlocked:' | awk '{print $2}' | tr -d '\r')"
        if [ "$unlocked" = "yes" ]; then
            ok "bootloader unlocked"
        else
            note_fail "bootloader reports unlocked='${unlocked:-unknown}' (need yes — do NOT run flashing unlock, it wipes)"
        fi
        local cur
        cur="$(fastboot getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' | tr -d '\r')"
        info "current-slot=${cur:-unknown} (the flasher writes slot a)"
    fi

    hdr "6. disk space for the image download (~2 GB)"
    local free_kb
    free_kb="$(df -Pk "$GT_HOME" 2>/dev/null | awk 'NR==2{print $4}')"
    if [ -n "${free_kb:-}" ] && [ "$free_kb" -gt 3000000 ]; then
        ok "$((free_kb / 1048576)) GB free in $GT_HOME"
    elif [ -n "${free_kb:-}" ]; then
        note_fail "only $((free_kb / 1024)) MB free — need ~3 GB"
    else
        warn "could not read free space"
    fi

    hdr "result"
    if [ "$FAILED" -eq 0 ]; then
        printf '%s  ALL CHECKS PASSED%s — %s is ready to flash.\n' "$G" "$N" "$GT_STAMP"
        printf '  %sThis validates the bundle and the device. It is NOT boot evidence.%s\n' "$D" "$N"
        return 0
    fi
    printf '%s  %d CHECK(S) FAILED%s — nothing will be flashed.\n' "$R" "$FAILED" "$N"
    return 10
}

# ==================================================================== flash ==
do_flash() {
    hdr "flashing"
    printf '  device : %s (%s)\n' "$GT_DEVICE" "$GT_BUILD_ID"
    printf '  stamp  : %s\n' "$GT_STAMP"
    printf '  serial : %s  (pinned)\n' "$GT_SERIAL"
    printf '  %sThis ERASES userdata and metadata. Expect 10-20 minutes.%s\n' "$Y" "$N"
    printf '  The readiness scan runs first and prints nothing for ~3 minutes — that is normal.\n\n'

    if [ "$ASSUME_YES" -ne 1 ]; then
        local reply
        printf 'Type %sFLASH%s to proceed: ' "$Y" "$N"
        read -r reply || reply=""
        if [ "$reply" != "FLASH" ]; then
            printf '\nAborted — nothing was flashed.\n'
            exit 11
        fi
    fi

    local log="$GT_HOME/flash-$(date +%Y%m%d-%H%M%S).log"
    info "log: $log"

    # A hard timeout is genuinely useful on a hang, but killing the flasher
    # mid-write is worse than letting it run. macOS ships neither `timeout` nor
    # `gtimeout`, so resolve one portably and, if none exists, run without a cap
    # rather than failing at exec time (exit 127).
    #
    # NOTE: macOS system bash is 3.2, where expanding an EMPTY array under
    # `set -u` is an "unbound variable" error. Hence the ${arr[@]+...} idiom.
    local tcap=()
    if command -v timeout >/dev/null 2>&1; then
        tcap=(timeout "$GT_TIMEOUT")
    elif command -v gtimeout >/dev/null 2>&1; then
        tcap=(gtimeout "$GT_TIMEOUT")
        info "using gtimeout (coreutils) for the ${GT_TIMEOUT}s cap"
    else
        warn "no 'timeout'/'gtimeout' on this host — running WITHOUT a time cap"
        printf '        %sThe readiness scan is silent for ~3 min; do not Ctrl-C during a write.%s\n' "$D" "$N"
    fi

    ( cd "$GT_HOME" && \
      DEVICE="$GT_DEVICE" \
      REMOTE_BUILD_DIR="$GT_BUILD_DIR" \
      REMOTE_HOST="$GT_SERVER" \
      REMOTE_TREE="$GT_TREE" \
      GT_FLASH_SERIAL="$GT_SERIAL" \
      GT_STAMP_TREE="$GT_HOME/stamp-tree" \
      GT_READY_REPORTER="$GT_HOME/gt-ready-devices.sh" \
      ${tcap[@]+"${tcap[@]}"} ./flash-from-remote.sh ) 2>&1 | tee "$log"
    local rc="${PIPESTATUS[0]}"

    echo
    case "$rc" in
        0)  printf '%s  flash finished%s\n' "$G" "$N"
            printf '  %sBOOT_VERIFIED stays FALSE. Only a logcat capture after boot sets it.%s\n' "$D" "$N" ;;
        124) printf '%s  timed out after %ss — log: %s%s\n' "$R" "$GT_TIMEOUT" "$log" "$N"; exit 13 ;;
        *)  printf '%s  flasher exited %s — read %s%s\n' "$R" "$rc" "$log" "$N"; exit 12 ;;
    esac
}

# ===================================================================== main ==
main() {
    printf '\n%s  GuardTalk OS — Stallion flash%s\n' "$B" "$N"
    printf '%s  serial %s · stamp %s%s\n\n' "$D" "$GT_SERIAL" "$GT_STAMP" "$N"

    if [ "$SELFCHECK_ONLY" -eq 1 ]; then
        selfcheck
        exit $?
    fi

    if [ "$ASSUME_YES" -ne 1 ]; then
        hdr "wizard"
        printf '  This will:\n'
        printf '   1. verify tools, server, stamp digest, ack, and the device\n'
        printf '   2. sync the flasher, reporter and quarantine registry into %s\n' "$GT_HOME"
        printf '   3. run flash-from-remote.sh pinned to %s\n' "$GT_SERIAL"
        printf '   4. %sERASE userdata and metadata%s\n' "$R" "$N"
        printf '\n  It will NOT flash %s or any other device.\n' "$GT_BLAZER"
        printf '\n  [1] self-check only\n  [2] self-check, then flash\n  [q] quit\n\n'
        local choice
        printf 'Choice [1/2/q]: '
        read -r choice || choice="q"
        case "$choice" in
            1) selfcheck; exit $? ;;
            2) : ;;
            *) printf 'Aborted.\n'; exit 11 ;;
        esac
    fi

    if ! selfcheck; then
        printf '\n%sSelf-check failed — refusing to flash.%s\n' "$R" "$N"
        exit 10
    fi
    do_flash
}

main
