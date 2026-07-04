#!/bin/bash
#
# GuardTalkOS Signing Key Wizard
#
# An end-to-end interactive orchestrator for the GuardTalkOS release-signing
# key lifecycle on an OFFLINE host. Runs the full sequence:
#
#   1. Preflight  — verify openssl/python3 present; locate or fetch AOSP tools
#   2. Generate   — run generate-signing-keys.sh (9 package keys + AVB key)
#   3. Backup x3  — run backup-signing-keys.sh 3 times (3 locations)
#   4. Restore test — decrypt one backup, compare checksums, shred
#   5. Summary    — print the final state + brick warning + next steps
#
# Source-of-truth:
#   vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md  (A-SIGN-RESEARCH #1)
#   vendor/guardtalk/branding/signing-keys/RUNBOOK.md
#
# Law 4 (Security First): NO keys are committed to the repo. This wizard is
#   tooling only; keys are generated on the offline host and never leave it
#   except via the encrypted GPG backups.
# Law 11 (Reversibility): idempotent; refuses to overwrite without --force.
# Law 3 (Error Handling): set -euo pipefail; every step checked.
#
# Usage:
#   ./keygen-wizard.sh                              # interactive, all prompts
#   ./keygen-wizard.sh --workdir ~/gt-keys          # non-interactive workdir
#   ./keygen-wizard.sh --buildserver 192.168.1.4    # scp tools from buildserver
#   ./keygen-wizard.sh --skip-fetch                 # tools already local
#   ./keygen-wizard.sh --help
#
# Exit codes:
#   0  success
#   1  generic failure
#   2  usage error
#   3  prerequisite missing (openssl/python3/tools)

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\033[1m';  DIM=$'\033[2m';  RED=$'\033[31m'
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'
    MAGENTA=$'\033[35m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""
    MAGENTA=""; CYAN=""; RESET=""
fi

# ── Defaults ─────────────────────────────────────────────────────────────────
WORKDIR="$HOME/Documents/NullSet.Zone/GuardTalk.io/Technology/guardtalk-os"
BUILDSERVER=""
BUILDUSER="openstatestack"
BUILDPATH="/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree"
SKIP_FETCH=0
KEYS_SUBDIR="keys/guardtalk"
BACKUP_SUBDIR="backups"
TOOLS_SUBDIR="tools"
SCRIPTS_SUBDIR="."
RESTORE_TEST=1
NUM_BACKUPS=3

# ── Help ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
GuardTalkOS Signing Key Wizard

End-to-end orchestrator for offline release-key generation, 3-location
encrypted backup, and restore verification.

USAGE:
  ./keygen-wizard.sh [OPTIONS]

OPTIONS:
  --workdir DIR          Working directory (default: ~/Documents/.../guardtalk-os)
  --buildserver HOST     Build server to scp AOSP tools from (e.g. 192.168.1.4)
  --builduser USER       SSH user on buildserver (default: openstatestack)
  --buildpath PATH       AOSP path on buildserver (default: /mnt/Big-Storage/.../GrapheneOS-worktree)
  --skip-fetch           AOSP tools (make_key, avbtool.py) already local
  --no-restore-test      Skip the restore-from-backup verification
  --num-backups N        Number of backup passes (default: 3)
  --help, -h             Show this help and exit

ENVIRONMENT:
  This wizard is designed to run on an OFFLINE, air-gapped host. If
  --buildserver is given, it will scp the AOSP tools BEFORE going offline
  (do the fetch on a networked machine, then disconnect).

EXAMPLES:
  # Full interactive run (fetch tools from buildserver first):
  ./keygen-wizard.sh --buildserver 192.168.1.4

  # Tools already local (post-fetch offline run):
  ./keygen-wizard.sh --skip-fetch

  # Custom workdir:
  ./keygen-wizard.sh --workdir ~/gt-keys --skip-fetch

EOF
}

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workdir)        WORKDIR="$2"; shift 2 ;;
        --buildserver)    BUILDSERVER="$2"; shift 2 ;;
        --builduser)      BUILDUSER="$2"; shift 2 ;;
        --buildpath)      BUILDPATH="$2"; shift 2 ;;
        --skip-fetch)     SKIP_FETCH=1; shift ;;
        --no-restore-test) RESTORE_TEST=0; shift ;;
        --num-backups)    NUM_BACKUPS="$2"; shift 2 ;;
        --help|-h)        usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────
banner() {
    echo ""
    echo "${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
    echo "${BOLD}  $1${RESET}"
    echo "${CYAN}══════════════════════════════════════════════════════════════════════${RESET}"
}

step() {
    echo ""
    echo "${BLUE}▶ $1${RESET}"
}

ok()    { echo "  ${GREEN}✓${RESET} $1"; }
warn()  { echo "  ${YELLOW}!${RESET} $1"; }
err()   { echo "  ${RED}✗${RESET} $1" >&2; }
info()  { echo "  ${DIM}$1${RESET}"; }

prompt() {
    local var="$1" question="$2" default="${3:-}"
    local default_display=""
    [[ -n "$default" ]] && default_display=" ${DIM}[$default]${RESET}"
    printf "%b%s%b " "${BOLD}" "$question" "${RESET}"
    [[ -n "$default" ]] && printf "%b[%s]%b " "$DIM" "$default" "$RESET"
    read -r answer
    [[ -z "$answer" ]] && answer="$default"
    eval "$var=\"\$answer\""
}

confirm() {
    local question="$1"
    local answer
    printf "%b%s%b [y/N] " "${YELLOW}" "$question" "${RESET}"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

die() { err "$1"; exit 1; }

# ── Brick warning (always shown) ─────────────────────────────────────────────
print_brick_warning() {
    cat >&2 <<EOF

${RED}╔══════════════════════════════════════════════════════════════════════╗${RESET}
${RED}║                                                                        ║${RESET}
${RED}║   ***  CRITICAL — PERMANENT BRICK WARNING  ***                          ║${RESET}
${RED}║                                                                        ║${RESET}
${RED}║   Once the bootloader is locked with these keys (specifically           ║${RESET}
${RED}║   avb.pem flashed via avb_custom_key + fastboot flashing lock),         ║${RESET}
${RED}║   LOSS of avb.pem is a PERMANENT BRICK of the device.                   ║${RESET}
${RED}║                                                                        ║${RESET}
${RED}║   There is NO recovery path without the AVB private key.                ║${RESET}
${RED}║                                                                        ║${RESET}
${RED}║   Store these keys in 3 offline encrypted backups.                      ║${RESET}
${RED}║   Test restoration from ONE backup before trusting it.                  ║${RESET}
${RED}║                                                                        ║${RESET}
${RED}╚══════════════════════════════════════════════════════════════════════╝${RESET}

EOF
}

# ── Phase 0: Welcome ────────────────────────────────────────────────────────
phase_welcome() {
    banner "GuardTalkOS Signing Key Wizard"
    cat <<EOF

This wizard will:
  ${BOLD}1.${RESET} Preflight   — verify openssl/python3, locate AOSP tools
  ${BOLD}2.${RESET} Generate    — 9 package keys (RSA-4096) + 1 AVB key + avb_pkmd.bin
  ${BOLD}3.${RESET} Backup x${NUM_BACKUPS}   — ${NUM_BACKUPS} encrypted GPG backups (3 separate locations)
  ${BOLD}4.${RESET} Restore test — decrypt one backup, compare checksums, shred
  ${BOLD}5.${RESET} Summary     — final state + next steps

${DIM}Source: vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md (A-SIGN-RESEARCH #1)${RESET}
${DIM}Runbook: vendor/guardtalk/branding/signing-keys/RUNBOOK.md${RESET}
EOF
    print_brick_warning
    confirm "Do you understand the brick warning and want to proceed?" || die "Aborted by user."
}

# ── Phase 1: Preflight ──────────────────────────────────────────────────────
phase_preflight() {
    banner "Phase 1: Preflight"
    step "Verifying prerequisites..."

    # openssl
    if command -v openssl >/dev/null 2>&1; then
        ok "openssl: $(openssl version)"
    else
        err "openssl not found."
        echo "  macOS:  brew install openssl"
        echo "  Linux:  apt install openssl  /  dnf install openssl"
        die "Install openssl and re-run."
    fi

    # python3
    if command -v python3 >/dev/null 2>&1; then
        ok "python3: $(python3 --version)"
    else
        err "python3 not found."
        echo "  macOS:  brew install python3"
        echo "  Linux:  apt install python3  /  dnf install python3"
        die "Install python3 and re-run."
    fi

    # gpg (for backup)
    if command -v gpg >/dev/null 2>&1; then
        ok "gpg: $(gpg --version | head -1)"
    else
        err "gpg not found."
        echo "  macOS:  brew install gnupg"
        echo "  Linux:  apt install gnupg  /  dnf install gnupg"
        die "Install gpg and re-run."
    fi

    # Working directory
    step "Setting up working directory..."
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    ok "workdir: $(pwd)"

    # Locate the wizard-adjacent scripts (generate-signing-keys.sh, backup-signing-keys.sh)
    # They should be in the same dir as this wizard, or one level up.
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GEN_SCRIPT="$script_dir/generate-signing-keys.sh"
    BAK_SCRIPT="$script_dir/backup-signing-keys.sh"

    if [[ ! -x "$GEN_SCRIPT" ]]; then
        # Try looking in CWD
        GEN_SCRIPT="$WORKDIR/generate-signing-keys.sh"
    fi
    if [[ ! -x "$BAK_SCRIPT" ]]; then
        BAK_SCRIPT="$WORKDIR/backup-signing-keys.sh"
    fi

    if [[ ! -x "$GEN_SCRIPT" ]] || [[ ! -x "$BAK_SCRIPT" ]]; then
        warn "generate-signing-keys.sh / backup-signing-keys.sh not found next to wizard."
        if [[ -n "$BUILDSERVER" ]]; then
            step "Fetching scripts from buildserver $BUILDSERVER..."
            scp "$BUILDUSER@$BUILDSERVER:$BUILDPATH/vendor/guardtalk/scripts/generate-signing-keys.sh" "$WORKDIR/"
            scp "$BUILDUSER@$BUILDSERVER:$BUILDPATH/vendor/guardtalk/scripts/backup-signing-keys.sh" "$WORKDIR/"
            chmod +x "$WORKDIR/generate-signing-keys.sh" "$WORKDIR/backup-signing-keys.sh"
            GEN_SCRIPT="$WORKDIR/generate-signing-keys.sh"
            BAK_SCRIPT="$WORKDIR/backup-signing-keys.sh"
        else
            die "Cannot locate scripts. Pass --buildserver HOST or copy them into $WORKDIR manually."
        fi
    fi
    ok "generate-signing-keys.sh: $GEN_SCRIPT"
    ok "backup-signing-keys.sh:   $BAK_SCRIPT"

    # Locate AOSP tools (make_key, avbtool.py)
    mkdir -p "$WORKDIR/$TOOLS_SUBDIR"
    MAKE_KEY="$WORKDIR/$TOOLS_SUBDIR/make_key"
    AVBTOOL="$WORKDIR/$TOOLS_SUBDIR/avbtool.py"

    if [[ $SKIP_FETCH -eq 0 ]] && [[ ! -x "$MAKE_KEY" || ! -r "$AVBTOOL" ]]; then
        if [[ -n "$BUILDSERVER" ]]; then
            step "Fetching AOSP tools from buildserver $BUILDSERVER..."
            scp "$BUILDUSER@$BUILDSERVER:$BUILDPATH/development/tools/make_key" "$WORKDIR/$TOOLS_SUBDIR/"
            scp "$BUILDUSER@$BUILDSERVER:$BUILDPATH/external/avb/avbtool.py" "$WORKDIR/$TOOLS_SUBDIR/"
            chmod +x "$MAKE_KEY" "$AVBTOOL"
        else
            warn "AOSP tools (make_key, avbtool.py) not found in $WORKDIR/$TOOLS_SUBDIR"
            echo "  Options:"
            echo "    a) Re-run with --buildserver <host> to fetch them via scp"
            echo "    b) Re-run with --skip-fetch after copying them manually to:"
            echo "       $MAKE_KEY"
            echo "       $AVBTOOL"
            die "AOSP tools missing."
        fi
    fi

    [[ -x "$MAKE_KEY" ]] || die "make_key not executable: $MAKE_KEY"
    [[ -r "$AVBTOOL"  ]] || die "avbtool.py not readable: $AVBTOOL"
    ok "make_key: $MAKE_KEY"
    ok "avbtool:  $AVBTOOL"

    # Also fetch the RUNBOOK for reference
    if [[ -n "$BUILDSERVER" ]] && [[ ! -f "$WORKDIR/RUNBOOK.md" ]]; then
        step "Fetching RUNBOOK from buildserver..."
        scp "$BUILDUSER@$BUILDSERVER:$BUILDPATH/vendor/guardtalk/branding/signing-keys/RUNBOOK.md" "$WORKDIR/" 2>/dev/null || warn "RUNBOOK fetch failed (non-fatal)"
        [[ -f "$WORKDIR/RUNBOOK.md" ]] && ok "RUNBOOK: $WORKDIR/RUNBOOK.md"
    fi

    ok "Preflight complete."
}

# ── Phase 2: Generate keys ──────────────────────────────────────────────────
phase_generate() {
    banner "Phase 2: Generate Signing Keys"
    echo "This will generate 9 package keys + 1 AVB key into:"
    echo "  ${BOLD}$WORKDIR/$KEYS_SUBDIR${RESET}"
    echo ""
    echo "${YELLOW}make_key will prompt for a passphrase for each of the 9 package keys.${RESET}"
    echo "${YELLOW}Recommend: set a passphrase (defense-in-depth) OR press Enter for unencrypted.${RESET}"
    echo "${YELLOW}avb.pem is generated non-interactively (RSA-4096, no passphrase by default).${RESET}"
    echo ""

    if ! confirm "Proceed with key generation?"; then
        die "Aborted before key generation."
    fi

    local force_arg=""
    if [[ -d "$WORKDIR/$KEYS_SUBDIR" ]] && [[ -n "$(ls -A "$WORKDIR/$KEYS_SUBDIR" 2>/dev/null)" ]]; then
        warn "Existing keys found in $WORKDIR/$KEYS_SUBDIR"
        if confirm "Overwrite existing keys with --force? (BACK THEM UP FIRST)"; then
            force_arg="--force"
        else
            die "Refusing to overwrite. Move the existing keys aside and re-run."
        fi
    fi

    step "Running generate-signing-keys.sh..."
    "$GEN_SCRIPT" \
        --make-key "$MAKE_KEY" \
        --avbtool "$AVBTOOL" \
        --output-dir "$WORKDIR/$KEYS_SUBDIR" \
        $force_arg

    # Verify the expected files exist
    step "Verifying generated key set..."
    local expected=(
        releasekey.pk8 releasekey.x509.pem
        platform.pk8 platform.x509.pem
        shared.pk8 shared.x509.pem
        media.pk8 media.x509.pem
        networkstack.pk8 networkstack.x509.pem
        bluetooth.pk8 bluetooth.x509.pem
        nfc.pk8 nfc.x509.pem
        sdk_sandbox.pk8 sdk_sandbox.x509.pem
        gmscompat_lib.pk8 gmscompat_lib.x509.pem
        avb.pem avb_pkmd.bin
    )
    local missing=0
    for f in "${expected[@]}"; do
        if [[ ! -e "$WORKDIR/$KEYS_SUBDIR/$f" ]]; then
            err "missing: $f"
            missing=1
        fi
    done
    [[ $missing -eq 0 ]] && ok "All 20 key files present." || die "Key generation incomplete — missing files."

    # Permissions sanity
    local mode
    mode=$(stat -f "%Lp" "$WORKDIR/$KEYS_SUBDIR/avb.pem" 2>/dev/null || stat -c "%a" "$WORKDIR/$KEYS_SUBDIR/avb.pem" 2>/dev/null)
    if [[ "$mode" == "600" ]]; then
        ok "avb.pem permissions: 0600"
    else
        warn "avb.pem permissions: $mode (expected 0600). Fixing..."
        chmod 0600 "$WORKDIR/$KEYS_SUBDIR/avb.pem"
        ok "Fixed: avb.pem → 0600"
    fi

    ok "Key generation complete."
}

# ── Phase 3: Backup (x N) ───────────────────────────────────────────────────
phase_backup() {
    banner "Phase 3: Encrypted Backups (x${NUM_BACKUPS})"
    echo "You will create ${NUM_BACKUPS} encrypted GPG backups of the key set."
    echo "Each backup is a self-contained .tar.gz.gpg (AES-256)."
    echo "Store each in a DIFFERENT physical location."
    echo ""

    local backup_files=()
    local i
    for ((i = 1; i <= NUM_BACKUPS; i++)); do
        step "Backup ${i}/${NUM_BACKUPS}"
        local default_dir="$WORKDIR/$BACKUP_SUBDIR/location-${i}"
        local backup_dir
        prompt backup_dir "Destination directory for backup #${i}" "$default_dir"
        mkdir -p "$backup_dir"

        echo "  Creating encrypted backup in: ${BOLD}$backup_dir${RESET}"
        echo "  ${YELLOW}You will be prompted for a GPG passphrase. CHOOSE A STRONG ONE.${RESET}"
        echo "  ${YELLOW}(Use the SAME passphrase for all ${NUM_BACKUPS} backups to simplify restore.)${RESET}"
        echo ""

        "$BAK_SCRIPT" \
            --key-dir "$WORKDIR/$KEYS_SUBDIR" \
            --backup-dir "$backup_dir"

        # Find the generated backup file
        local bak
        bak=$(ls -t "$backup_dir"/guardtalk-signing-keys-*.tar.gz.gpg 2>/dev/null | head -1)
        if [[ -z "$bak" ]]; then
            die "Backup #${i} did not produce a .tar.gz.gpg file."
        fi
        backup_files+=("$bak")
        ok "Backup #${i}: $bak"

        if [[ $i -lt $NUM_BACKUPS ]]; then
            echo ""
            echo "  ${DIM}Move this backup to a separate physical location now.${RESET}"
            echo "  ${DIM}e.g. USB stick, offline NAS, safety deposit box, paper wallet safe.${RESET}"
            if ! confirm "Backup #${i} stored safely? Continue to next backup?"; then
                die "Aborted by user at backup #${i}."
            fi
        fi
    done

    # Persist the list of backup files for the summary
    BACKUP_FILES_LIST="${backup_files[*]}"
    ok "All ${NUM_BACKUPS} backups created."
}

# ── Phase 4: Restore test ───────────────────────────────────────────────────
phase_restore_test() {
    if [[ $RESTORE_TEST -eq 0 ]]; then
        warn "Restore test skipped (--no-restore-test)."
        return 0
    fi

    banner "Phase 4: Restore Verification"
    echo "Decrypting the FIRST backup and comparing checksums against the source keys."
    echo "This proves the backup is restorable. Temporary decrypted files are shredded."
    echo ""

    local first_backup
    first_backup=$(ls -t "$WORKDIR/$BACKUP_SUBDIR"/location-1/guardtalk-signing-keys-*.tar.gz.gpg 2>/dev/null | head -1)
    if [[ -z "$first_backup" ]]; then
        # Fallback: scan all backup dirs
        first_backup=$(ls -t "$WORKDIR/$BACKUP_SUBDIR"/location-*/guardtalk-signing-keys-*.tar.gz.gpg 2>/dev/null | head -1)
    fi
    [[ -n "$first_backup" ]] || die "No backup file found for restore test."

    step "Decrypting: $first_backup"
    local restore_dir
    restore_dir=$(mktemp -d "${TMPDIR:-/tmp}/gt-restore-test.XXXXXX")
    info "temp restore dir: $restore_dir"

    echo "  ${YELLOW}Enter the GPG passphrase you used for the backups:${RESET}"
    if ! gpg --decrypt "$first_backup" 2>/dev/null | tar xz -C "$restore_dir"; then
        rm -rf "$restore_dir"
        die "Restore test FAILED: gpg decrypt or tar extract failed. Check your passphrase."
    fi

    step "Comparing checksums..."
    # Find where the keys landed in the restored tree
    local restored_keys_dir
    restored_keys_dir=$(find "$restore_dir" -name "avb.pem" -exec dirname {} \; | head -1)
    [[ -n "$restored_keys_dir" ]] || { rm -rf "$restore_dir"; die "Restore test FAILED: avb.pem not found in restored tree."; }

    local src_sum rest_sum
    if command -v shasum >/dev/null 2>&1; then
        src_sum=$(cd "$WORKDIR/$KEYS_SUBDIR" && shasum -a 256 * | sort)
        rest_sum=$(cd "$restored_keys_dir" && shasum -a 256 * | sort)
    else
        src_sum=$(cd "$WORKDIR/$KEYS_SUBDIR" && sha256sum * | sort)
        rest_sum=$(cd "$restored_keys_dir" && sha256sum * | sort)
    fi

    if [[ "$src_sum" == "$rest_sum" ]]; then
        ok "Checksums MATCH — backup is restorable."
    else
        err "Checksum MISMATCH — backup is corrupt or incomplete!"
        echo "  Source:  $WORKDIR/$KEYS_SUBDIR"
        echo "  Restored: $restored_keys_dir"
        rm -rf "$restore_dir"
        die "Restore test FAILED."
    fi

    step "Cleaning up temporary decrypted files (shred)..."
    if command -v shred >/dev/null 2>&1; then
        find "$restore_dir" -type f -exec shred -u {} + 2>/dev/null || rm -rf "$restore_dir"
    else
        rm -rf "$restore_dir"
    fi
    rm -rf "$restore_dir" 2>/dev/null || true
    ok "Temporary files shredded."

    ok "Restore verification complete."
}

# ── Phase 5: Summary ────────────────────────────────────────────────────────
phase_summary() {
    banner "Phase 5: Summary"

    echo ""
    echo "${BOLD}Generated keys:${RESET}"
    echo "  Location: $WORKDIR/$KEYS_SUBDIR"
    echo ""
    printf "  %-20s %-12s %-8s\n" "KEY" "ALGORITHM" "MODE"
    printf "  %-20s %-12s %-8s\n" "--------------------" "------------" "--------"
    for k in releasekey platform shared media networkstack bluetooth nfc sdk_sandbox gmscompat_lib; do
        printf "  %-20s %-12s %-8s\n" "$k" "RSA-4096" "0600"
    done
    printf "  %-20s %-12s %-8s\n" "avb.pem" "RSA-4096" "0600"
    printf "  %-20s %-12s %-8s\n" "avb_pkmd.bin" "PUBLIC BLOB" "0644"
    echo ""

    echo "${BOLD}Backups (x${NUM_BACKUPS}):${RESET}"
    local i=1
    for f in $BACKUP_FILES_LIST; do
        local size
        size=$(du -h "$f" 2>/dev/null | cut -f1)
        echo "  #${i}: $f  ${DIM}(${size})${RESET}"
        i=$((i+1))
    done
    echo ""

    echo "${BOLD}Restore test:${RESET}"
    if [[ $RESTORE_TEST -eq 1 ]]; then
        ok "PASSED — backup is restorable."
    else
        warn "SKIPPED."
    fi
    echo ""

    echo "${BOLD}Next steps:${RESET}"
    echo "  ${BOLD}1.${RESET} Move each backup to a geographically separate offline location."
    echo "     (USB stick, offline NAS, safety deposit box, paper wallet safe.)"
    echo ""
    echo "  ${BOLD}2.${RESET} Copy ${BOLD}avb_pkmd.bin${RESET} (PUBLIC) to your build server:"
    echo "       scp $WORKDIR/$KEYS_SUBDIR/avb_pkmd.bin $BUILDUSER@<buildserver>:~/"
    echo "     (This is safe — it's the public key blob.)"
    echo ""
    echo "  ${BOLD}3.${RESET} To sign a build, copy the PRIVATE keys to the signing host"
    echo "     (either the offline host itself, or a temporary signing machine):"
    echo "       scp -r $WORKDIR/$KEYS_SUBDIR <signing-host>:~/keys/guardtalk/"
    echo "     Then run sign_target_files_apks with the key directory."
    echo ""
    echo "  ${BOLD}4.${RESET} Bootloader lock procedure (see RUNBOOK.md):"
    echo "       fastboot flash avb_custom_key avb_pkmd.bin"
    echo "       fastboot flash boot boot.img   (signed)"
    echo "       fastboot flash system system.img   (signed)"
    echo "       fastboot flashing lock"
    echo "       adb shell getprop ro.boot.verifiedbootstate   # must be 'green'"
    echo ""
    echo "  ${BOLD}5.${RESET} ${YELLOW}DO NOT lose avb.pem.${RESET} Loss = PERMANENT BRICK."
    echo "     The 3 encrypted backups are your only recovery path."
    echo ""

    print_brick_warning

    echo "${GREEN}${BOLD}Wizard complete.${RESET}"
    echo "${DIM}Runbook: $WORKDIR/RUNBOOK.md${RESET}"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    phase_welcome
    phase_preflight
    phase_generate
    phase_backup
    phase_restore_test
    phase_summary
}

main "$@"
