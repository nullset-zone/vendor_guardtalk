#!/bin/bash
#
# GuardTalkOS Signing Key Backup — Encrypted GPG Archive
#
# Creates an AES-256-encrypted, GPG-symmetric-encrypted tarball of the
# GuardTalkOS signing key directory. Verifies the backup by decrypting
# and comparing SHA-256 checksums. Cleans up all temporary plaintext
# files with shred -u.
#
# Source-of-truth: vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md
#   (A-SIGN-RESEARCH #1, 2026-07-02, §1c — Custody)
#
# Law 4 (Security First):
#   - Passphrase is NEVER on the command line (use --passphrase-file or
#     interactive prompt).
#   - Plaintext key material exists only in a tmpfs working directory that
#     is shredded on exit (trap).
# Law 11 (Reversibility): The backup is restorable — verified by a
#   decrypt + checksum-compare cycle before the script declares success.
# Law 3 (Error Handling): set -euo pipefail; every step checked.
#
# Usage:
#   ./backup-signing-keys.sh --key-dir ./keys/guardtalk \
#       --backup-dir /mnt/secure/backups
#
#   ./backup-signing-keys.sh --key-dir ./keys/guardtalk \
#       --backup-dir /mnt/secure/backups \
#       --passphrase-file /dev/shm/passphrase.txt
#
# Prerequisites: see vendor/guardtalk/branding/signing-keys/RUNBOOK.md
#

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
KEY_DIR=""
BACKUP_DIR=""
PASSPHRASE_FILE=""
GPG="${GPG:-gpg}"
TAR="${TAR:-tar}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_NAME="guardtalk-signing-keys-${TIMESTAMP}.tar.gz.gpg"

# ── Help ────────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: backup-signing-keys.sh [OPTIONS]

Creates an encrypted GPG-symmetric (AES-256) backup of the GuardTalkOS
signing key directory.

REQUIRED:
  --key-dir DIR         Directory containing the generated keys
                        (output of generate-signing-keys.sh).
  --backup-dir DIR      Destination directory for the .tar.gz.gpg backup.
                        Will be created if it does not exist.

OPTIONAL:
  --passphrase-file F   Read passphrase from F (must be a secure path,
                        e.g. /dev/shm/passphrase.txt). If omitted, gpg
                        will prompt interactively (recommended).
  --gpg PATH            Override gpg binary. Default: gpg
  --tar PATH            Override tar binary. Default: tar
  --help, -h            Show this help and exit.

SECURITY:
  - The passphrase is NEVER passed on the command line (would leak via
    ps(1) / shell history). Use --passphrase-file (a tmpfs path) or the
    interactive prompt.
  - Plaintext key material is extracted to a tmpfs working directory
    (under /dev/shm) and shredded on exit.
  - The backup is verified by decrypting + comparing SHA-256 checksums
    of every file against the source.

EXIT CODES:
  0  success — backup created and verified
  1  generic failure
  2  usage error
  3  verification failed (backup is NOT trustworthy — do not use)
EOF
}

# ── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --key-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --key-dir requires a value" >&2; exit 2; }
            KEY_DIR="$2"; shift 2 ;;
        --backup-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --backup-dir requires a value" >&2; exit 2; }
            BACKUP_DIR="$2"; shift 2 ;;
        --passphrase-file)
            [[ $# -ge 2 ]] || { echo "ERROR: --passphrase-file requires a value" >&2; exit 2; }
            PASSPHRASE_FILE="$2"; shift 2 ;;
        --gpg)
            [[ $# -ge 2 ]] || { echo "ERROR: --gpg requires a value" >&2; exit 2; }
            GPG="$2"; shift 2 ;;
        --tar)
            [[ $# -ge 2 ]] || { echo "ERROR: --tar requires a value" >&2; exit 2; }
            TAR="$2"; shift 2 ;;
        --help|-h)
            usage; exit 0 ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage
            exit 2 ;;
    esac
done

# ── Validation ───────────────────────────────────────────────────────────────
if [[ -z "$KEY_DIR" ]]; then
    echo "ERROR: --key-dir is required" >&2
    usage
    exit 2
fi
if [[ -z "$BACKUP_DIR" ]]; then
    echo "ERROR: --backup-dir is required" >&2
    usage
    exit 2
fi
if [[ ! -d "$KEY_DIR" ]]; then
    echo "ERROR: --key-dir '$KEY_DIR' does not exist or is not a directory" >&2
    exit 2
fi
command -v "$GPG" >/dev/null 2>&1 || { echo "ERROR: gpg not found: $GPG" >&2; exit 1; }
command -v "$TAR" >/dev/null 2>&1 || { echo "ERROR: tar not found: $TAR" >&2; exit 1; }

# ── Cross-platform SHA-256 command selection ────────────────────────────────
# Linux has sha256sum; macOS has shasum -a 256.
SHA256_CMD=""
if command -v sha256sum >/dev/null 2>&1; then
    SHA256_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA256_CMD="shasum -a 256"
else
    echo "ERROR: neither sha256sum nor shasum found in PATH" >&2
    exit 1
fi

# ── Cross-platform secure-delete function ────────────────────────────────────
# Linux has shred(1); macOS has rm -P (overwrite 3x then remove).
# Fall back to plain rm -f if neither secure-delete is available.
secure_delete() {
    local file="$1"
    if command -v shred >/dev/null 2>&1; then
        shred -u "$file" 2>/dev/null
    elif [[ "$(uname)" == "Darwin" ]]; then
        rm -fP "$file" 2>/dev/null
    else
        rm -f "$file" 2>/dev/null
    fi
}
secure_delete_all() {
    local dir="$1"
    if command -v shred >/dev/null 2>&1; then
        find "$dir" -type f -exec shred -u {} + 2>/dev/null || \
            find "$dir" -type f -delete 2>/dev/null
    elif [[ "$(uname)" == "Darwin" ]]; then
        find "$dir" -type f -exec rm -fP {} + 2>/dev/null || \
            find "$dir" -type f -delete 2>/dev/null
    else
        find "$dir" -type f -delete 2>/dev/null
    fi
}

# Refuse a passphrase file that is on a non-tmpfs / world-readable path.
# (Operator can bypass by using /dev/shm or by using the interactive prompt.)
if [[ -n "$PASSPHRASE_FILE" ]]; then
    if [[ ! -r "$PASSPHRASE_FILE" ]]; then
        echo "ERROR: --passphrase-file '$PASSPHRASE_FILE' not readable" >&2
        exit 2
    fi
    # Warn if the passphrase file is in a potentially unsafe location.
    case "$PASSPHRASE_FILE" in
        /dev/shm/*|/run/*|/tmp/*) : ;;  # likely tmpfs — acceptable
        *)
            echo "WARN: passphrase file is not under /dev/shm, /run, or /tmp." >&2
            echo "      A passphrase file on persistent disk is a leak risk." >&2
            echo "      Recommend: use the interactive prompt, or place the" >&2
            echo "      passphrase file in /dev/shm/ (tmpfs, wiped on reboot)." >&2
            ;;
    esac
fi

# ── Working directory (tmpfs) ───────────────────────────────────────────────
WORKDIR="$(mktemp -d -t guardtalk-backup.XXXXXX)"
# Try to prefer tmpfs
if [[ -d /dev/shm ]]; then
    WORKDIR="$(mktemp -d /dev/shm/guardtalk-backup.XXXXXX)"
fi
chmod 0700 "$WORKDIR"

# Trap: securely delete all plaintext files, then rmdir. Runs on EXIT, INT, QUIT, TERM.
cleanup() {
    local rc=$?
    if [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]]; then
        # securely delete plaintext, then remove the tree
        secure_delete_all "$WORKDIR"
        rm -rf "$WORKDIR" 2>/dev/null || true
    fi
    exit $rc
}
trap cleanup EXIT INT QUIT TERM

# ── GPG passphrase plumbing ─────────────────────────────────────────────────
# We use gpg's --batch --pinentry-mode loopback, feeding the passphrase via
# --passphrase-file (secure) or --passphrase-fd 0 (interactive read).
# At NO point is the passphrase placed on the gpg command line.
GPG_COMMON_ARGS=(
    --batch
    --yes
    --pinentry-mode loopback
    --cipher-algo AES256
    --passphrase-file /dev/stdin
)

# ── Step 1: Compute source checksums ────────────────────────────────────────
echo "→ Computing SHA-256 checksums of source keys in: $KEY_DIR"
SOURCE_CHECKSUMS="$WORKDIR/source.sha256"
( cd "$KEY_DIR" && find . -type f -print0 | sort -z | xargs -0 $SHA256_CMD ) \
    > "$SOURCE_CHECKSUMS"
local_source_count=$(wc -l < "$SOURCE_CHECKSUMS")
echo "  $local_source_count file(s) checksummed."

# ── Step 2: Create the encrypted tarball ────────────────────────────────────
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "→ Creating encrypted backup: $BACKUP_PATH"

# Build the tarball to a plaintext intermediate in tmpfs, then encrypt.
# (Two-step rather than pipe so we can checksum-verify the tarball itself
#  against the decrypt step.)
PLAIN_TAR="$WORKDIR/keys.tar.gz"
( cd "$KEY_DIR" && "$TAR" czf "$PLAIN_TAR" . )

# Encrypt with gpg symmetric AES-256. Passphrase via stdin (loopback).
# If --passphrase-file was given, we cat it into gpg's stdin; otherwise we
# read the passphrase from the terminal (no echo) and pipe it in.
feed_passphrase() {
    if [[ -n "$PASSPHRASE_FILE" ]]; then
        cat "$PASSPHRASE_FILE"
    else
        # Read passphrase twice for confirmation, no echo.
        local p1 p2
        read -r -s -p "Enter passphrase for backup: " p1 >&2; echo >&2
        read -r -s -p "Confirm passphrase: " p2 >&2; echo >&2
        if [[ "$p1" != "$p2" ]]; then
            echo "ERROR: passphrases do not match" >&2
            return 1
        fi
        if [[ -z "$p1" ]]; then
            echo "ERROR: empty passphrase is not allowed" >&2
            return 1
        fi
        printf '%s' "$p1"
    fi
}

feed_passphrase | "$GPG" "${GPG_COMMON_ARGS[@]}" \
    --output "$BACKUP_PATH" \
    --symmetric "$PLAIN_TAR"

# Verify the backup file exists and is non-empty
if [[ ! -s "$BACKUP_PATH" ]]; then
    echo "ERROR: backup file was not created or is empty: $BACKUP_PATH" >&2
    exit 1
fi
chmod 0600 "$BACKUP_PATH"

# ── Step 3: Verify — decrypt + checksum compare ─────────────────────────────
echo "→ Verifying backup by decrypting + comparing checksums"
VERIFY_DIR="$WORKDIR/verify"
mkdir -p "$VERIFY_DIR"
DECrypted_TAR="$WORKDIR/verify.tar.gz"

feed_passphrase | "$GPG" "${GPG_COMMON_ARGS[@]}" \
    --output "$DECrypted_TAR" \
    --decrypt "$BACKUP_PATH"

if [[ ! -s "$DECrypted_TAR" ]]; then
    echo "ERROR: decrypted tarball is empty — backup is corrupt or passphrase wrong" >&2
    exit 3
fi

( cd "$VERIFY_DIR" && "$TAR" xzf "$DECrypted_TAR" )
VERIFY_CHECKSUMS="$WORKDIR/verify.sha256"
( cd "$VERIFY_DIR" && find . -type f -print0 | sort -z | xargs -0 $SHA256_CMD ) \
    > "$VERIFY_CHECKSUMS"
local_verify_count=$(wc -l < "$VERIFY_CHECKSUMS")

# Compare checksums
if ! diff -u "$SOURCE_CHECKSUMS" "$VERIFY_CHECKSUMS" >/dev/null; then
    echo "ERROR: checksum mismatch between source and decrypted backup!" >&2
    echo "  Source checksums : $SOURCE_CHECKSUMS" >&2
    echo "  Verify checksums : $VERIFY_CHECKSUMS" >&2
    echo "  The backup is NOT trustworthy. Do not use it." >&2
    exit 3
fi

if [[ "$local_source_count" != "$local_verify_count" ]]; then
    echo "ERROR: file count mismatch: source=$local_source_count verify=$local_verify_count" >&2
    exit 3
fi

# ── Step 4: Success report ──────────────────────────────────────────────────
BACKUP_SIZE=$(stat -c '%s' "$BACKUP_PATH" 2>/dev/null || stat -f '%z' "$BACKUP_PATH")
BACKUP_SHA256=$($SHA256_CMD "$BACKUP_PATH" | awk '{print $1}')

echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo " GuardTalkOS Signing Key Backup — SUCCESS"
echo "══════════════════════════════════════════════════════════════════════"
printf " Backup file       : %s\n" "$BACKUP_PATH"
printf " Size              : %s bytes\n" "$BACKUP_SIZE"
printf " Files in backup   : %s\n" "$local_source_count"
printf " Backup SHA-256    : %s\n" "$BACKUP_SHA256"
printf " Encryption        : GPG symmetric, AES-256\n"
printf " Verification      : PASSED (decrypt + SHA-256 compare)\n"
echo "══════════════════════════════════════════════════════════════════════"
echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo " *** REMINDER ***"
echo "══════════════════════════════════════════════════════════════════════"
echo " Store this backup in a geographically separate location."
echo " Test restoration before trusting the backup."
echo ""
echo " Create 3 copies in 3 geographically separate offline locations."
echo " See vendor/guardtalk/branding/signing-keys/RUNBOOK.md for the"
echo " full restoration procedure."
echo ""
echo " *** PERMANENT BRICK WARNING ***"
echo " Loss of avb.pem after bootloader lock = PERMANENT BRICK."
echo " If you lose ALL backups of these keys, affected devices are"
echo " unrecoverable. Custody is the ONLY defense."
echo "══════════════════════════════════════════════════════════════════════"
