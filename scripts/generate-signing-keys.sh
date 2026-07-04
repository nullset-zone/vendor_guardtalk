#!/bin/bash
#
# GuardTalkOS Signing Key Generator
#
# Generates the full GuardTalkOS signing key set on an OFFLINE, air-gapped
# machine. This script is TOOLING ONLY — it produces no keys when committed
# to the repo; keys are generated only when the operator runs this script
# on their secure offline machine.
#
# Source-of-truth: vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md
#   (A-SIGN-RESEARCH #1, 2026-07-02)
#
# Key set (verified against the report §1a):
#   - 9 package keys (releasekey, platform, shared, media, networkstack,
#     bluetooth, nfc, sdk_sandbox, gmscompat_lib) — RSA-4096 via make_key
#   - 1 AVB key (avb.pem) — RSA-4096 via openssl genrsa, SHA256_RSA4096
#   - AVB public-key blob (avb_pkmd.bin) via avbtool extract_public_key
#
# Law 4 (Security First): NO keys are committed to the repo. Output goes
#   to the operator-specified --output-dir (default ./keys/guardtalk/).
# Law 11 (Reversibility): Idempotent — refuses to overwrite existing keys
#   without explicit --force.
# Law 3 (Error Handling): set -euo pipefail; every step checked.
#
# Usage:
#   ./generate-signing-keys.sh --output-dir /mnt/secure/keys/guardtalk
#   ./generate-signing-keys.sh --output-dir ./keys/guardtalk --force
#   ./generate-signing-keys.sh --make-key /path/to/AOSP/development/tools/make_key \
#       --avbtool /path/to/AOSP/external/avb/avbtool.py \
#       --output-dir ./keys/guardtalk
#
# Prerequisites: see vendor/guardtalk/branding/signing-keys/RUNBOOK.md
#

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
OUTPUT_DIR="${OUTPUT_DIR:-./keys/guardtalk}"
MAKE_KEY=""
AVBTOOL=""
FORCE=0
SUBJECT_COUNTRY="US"
SUBJECT_STATE="California"
SUBJECT_LOCALITY="Mountain View"
SUBJECT_ORG="GuardTalkOS"
SUBJECT_OU="GuardTalkOS Release Engineering"
SUBJECT_CN_PREFIX="GuardTalkOS"
SUBJECT_EMAIL="release@guardtalk.invalid"
AVB_KEY_BITS=4096
AVB_ALGORITHM="SHA256_RSA4096"

# ── Help ────────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: generate-signing-keys.sh [OPTIONS]

Generates the GuardTalkOS signing key set on an OFFLINE machine.

REQUIRED:
  --output-dir DIR     Destination directory for generated keys.
                       Default: ./keys/guardtalk
                       Will be created if it does not exist.

TOOL LOCATORS (at least one of each pair required; the ANDROID_BUILD_TOP
fallback is tried first):
  --make-key PATH      Path to AOSP development/tools/make_key
  --avbtool PATH       Path to AOSP external/avb/avbtool.py

OPTIONAL:
  --force              Overwrite existing keys (DANGEROUS — see warnings).
  --subject-cn PREFIX  CN prefix for key subjects. Default: GuardTalkOS
                       Keys become CN=GuardTalkOS-releasekey, etc.
  --help, -h           Show this help and exit.

ENVIRONMENT:
  ANDROID_BUILD_TOP    If set, used to locate make_key and avbtool
                       automatically ($ANDROID_BUILD_TOP/development/tools/
                       make_key and $ANDROID_BUILD_TOP/external/avb/avbtool.py).

EXIT CODES:
  0  success
  1  generic failure
  2  usage error
  3  existing keys found (re-run with --force to overwrite)
EOF
}

# ── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            [[ $# -ge 2 ]] || { echo "ERROR: --output-dir requires a value" >&2; exit 2; }
            OUTPUT_DIR="$2"; shift 2 ;;
        --make-key)
            [[ $# -ge 2 ]] || { echo "ERROR: --make-key requires a value" >&2; exit 2; }
            MAKE_KEY="$2"; shift 2 ;;
        --avbtool)
            [[ $# -ge 2 ]] || { echo "ERROR: --avbtool requires a value" >&2; exit 2; }
            AVBTOOL="$2"; shift 2 ;;
        --force)
            FORCE=1; shift ;;
        --subject-cn)
            [[ $# -ge 2 ]] || { echo "ERROR: --subject-cn requires a value" >&2; exit 2; }
            SUBJECT_CN_PREFIX="$2"; shift 2 ;;
        --help|-h)
            usage; exit 0 ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage
            exit 2 ;;
    esac
done

# ── Tool resolution ─────────────────────────────────────────────────────────
resolve_make_key() {
    if [[ -n "$MAKE_KEY" ]]; then
        if [[ -x "$MAKE_KEY" ]]; then
            return 0
        fi
        echo "ERROR: --make-key '$MAKE_KEY' not executable or not found" >&2
        return 1
    fi
    if [[ -n "${ANDROID_BUILD_TOP:-}" ]]; then
        local cand="$ANDROID_BUILD_TOP/development/tools/make_key"
        if [[ -x "$cand" ]]; then
            MAKE_KEY="$cand"
            return 0
        fi
    fi
    echo "ERROR: cannot locate make_key." >&2
    echo "  Set ANDROID_BUILD_TOP or pass --make-key /path/to/make_key" >&2
    return 1
}

resolve_avbtool() {
    if [[ -n "$AVBTOOL" ]]; then
        if [[ -r "$AVBTOOL" ]]; then
            return 0
        fi
        echo "ERROR: --avbtool '$AVBTOOL' not readable or not found" >&2
        return 1
    fi
    if [[ -n "${ANDROID_BUILD_TOP:-}" ]]; then
        local cand="$ANDROID_BUILD_TOP/external/avb/avbtool.py"
        if [[ -r "$cand" ]]; then
            AVBTOOL="$cand"
            return 0
        fi
    fi
    echo "ERROR: cannot locate avbtool." >&2
    echo "  Set ANDROID_BUILD_TOP or pass --avbtool /path/to/avbtool.py" >&2
    return 1
}

# ── Preflight ───────────────────────────────────────────────────────────────
preflight() {
    command -v openssl >/dev/null || { echo "ERROR: openssl not found in PATH" >&2; exit 1; }
    command -v python3 >/dev/null || { echo "ERROR: python3 not found in PATH (avbtool requires it)" >&2; exit 1; }
    resolve_make_key
    resolve_avbtool
}

# ── Idempotency / overwrite guard ──────────────────────────────────────────
# The 9 package keys produce .pk8 + .x509.pem; AVB produces avb.pem +
# avb_pkmd.bin. Check for all of them.
check_existing() {
    local existing=()
    local k
    for k in releasekey platform shared media networkstack bluetooth nfc \
             sdk_sandbox gmscompat_lib; do
        [[ -e "$OUTPUT_DIR/$k.pk8"     ]] && existing+=("$k.pk8")
        [[ -e "$OUTPUT_DIR/$k.x509.pem" ]] && existing+=("$k.x509.pem")
    done
    [[ -e "$OUTPUT_DIR/avb.pem"     ]] && existing+=("avb.pem")
    [[ -e "$OUTPUT_DIR/avb_pkmd.bin" ]] && existing+=("avb_pkmd.bin")

    if [[ ${#existing[@]} -gt 0 ]]; then
        if [[ $FORCE -eq 0 ]]; then
            echo "ERROR: existing key material found in $OUTPUT_DIR:" >&2
            printf '  %s\n' "${existing[@]}" >&2
            echo "" >&2
            echo "Refusing to overwrite (Law 11 — Reversibility)." >&2
            echo "Re-run with --force to overwrite. BACK UP THE EXISTING KEYS FIRST." >&2
            exit 3
        else
            echo "WARN: --force specified; removing existing key material in $OUTPUT_DIR" >&2
            local f
            for f in "${existing[@]}"; do
                # shred if available, else rm
                if command -v shred >/dev/null 2>&1; then
                    shred -u "$OUTPUT_DIR/$f"
                else
                    rm -f "$OUTPUT_DIR/$f"
                fi
            done
        fi
    fi
}

# ── Brick warning ───────────────────────────────────────────────────────────
print_brick_warning() {
    cat >&2 <<'EOF'

╔══════════════════════════════════════════════════════════════════════╗
║                                                                        ║
║   ***  CRITICAL — PERMANENT BRICK WARNING  ***                          ║
║                                                                        ║
║   Once the bootloader is locked with these keys (specifically           ║
║   avb.pem flashed via avb_custom_key + fastboot flashing lock),         ║
║   LOSS of avb.pem is a PERMANENT BRICK of the device.                   ║
║                                                                        ║
║   There is NO recovery path without the AVB private key.                ║
║                                                                        ║
║   Store these keys in 3 offline encrypted backups.                     ║
║   See backup-signing-keys.sh and RUNBOOK.md.                           ║
║                                                                        ║
╚══════════════════════════════════════════════════════════════════════╝

EOF
}

# ── Subject builder ────────────────────────────────────────────────────────
# Returns a subject string suitable for `openssl req -subj` and make_key.
# Format: /C=US/ST=California/L=Mountain View/O=GuardTalkOS/OU=.../CN=.../emailAddress=...
subject_for() {
    local cn="$SUBJECT_CN_PREFIX-$1"
    printf '/C=%s/ST=%s/L=%s/O=%s/OU=%s/CN=%s/emailAddress=%s' \
        "$SUBJECT_COUNTRY" "$SUBJECT_STATE" "$SUBJECT_LOCALITY" \
        "$SUBJECT_ORG" "$SUBJECT_OU" "$cn" "$SUBJECT_EMAIL"
}

# ── Package key generation ────────────────────────────────────────────────
# make_key prompts for a password (blank = no encryption, otherwise scrypt).
# To keep this script non-interactive AND get scrypt-encrypted keys, we feed
# the password via a named pipe using expect-like here-string. However, the
# cleanest, dependency-free approach is to let make_key prompt interactively
# for each key's passphrase (the operator is present on the offline machine).
#
# make_key already refuses to overwrite (see development/tools/make_key:30-34),
# but we re-check above for a uniform --force UX.
#
# make_key uses named pipes with background processes (development/tools/make_key:53).
# When the reader finishes, `tee` gets SIGPIPE (exit 141) and `wait` (make_key:77)
# returns non-zero — even though both .pk8 and .x509.pem were created successfully.
# This is benign: we disable errexit around the make_key call and verify the output
# files instead of relying on the exit code.
generate_package_key() {
    local name="$1"
    local subject
    subject=$(subject_for "$name")
    echo "→ Generating package key: $name (RSA-4096, scrypt-encrypted PKCS#8)"
    # make_key writes <name>.pk8 and <name>.x509.pem in CWD — run in OUTPUT_DIR.
    # Temporarily disable errexit because make_key's named-pipe `wait` returns
    # non-zero (SIGPIPE on `tee`) even on success.
    set +e
    ( cd "$OUTPUT_DIR" && "$MAKE_KEY" "$name" "$subject" rsa )
    local rc=$?
    set -e
    # Verify the actual output files exist and are non-empty.
    if [[ ! -s "$OUTPUT_DIR/$name.pk8" ]] || [[ ! -s "$OUTPUT_DIR/$name.x509.pem" ]]; then
        echo "ERROR: make_key for '$name' exited rc=$rc and output files are missing/empty" >&2
        return 1
    fi
    echo "  ✓ $name.pk8 + $name.x509.pem created (make_key rc=$rc, ignored — named-pipe SIGPIPE)"
}

# ── AVB key generation ─────────────────────────────────────────────────────
generate_avb_key() {
    local avb_pem="$OUTPUT_DIR/avb.pem"
    echo "→ Generating AVB key: avb.pem (RSA-$AVB_KEY_BITS, $AVB_ALGORITHM)"
    # avb.pem is a plain RSA private key (PEM). The GrapheneOS pipeline does
    # NOT encrypt avb.pem at rest (the .pk8 package keys are scrypt-encrypted;
    # avb.pem is protected by filesystem permissions + the encrypted backup).
    # If you require an encrypted-at-rest AVB key, use:
    #   openssl genrsa -f4 $AVB_KEY_BITS | openssl rsa -aes256 -out avb.pem
    # (avbtool supports passphrase-protected AVB keys via --key-pass).
    openssl genrsa -f4 -out "$avb_pem" "$AVB_KEY_BITS"
    chmod 0600 "$avb_pem"
}

# ── AVB public-key blob extraction ────────────────────────────────────────
generate_avb_pkmd() {
    local avb_pem="$OUTPUT_DIR/avb.pem"
    local pkmd="$OUTPUT_DIR/avb_pkmd.bin"
    echo "→ Extracting AVB public-key blob: avb_pkmd.bin"
    # avbtool is a Python script; invoke it explicitly.
    python3 "$AVBTOOL" extract_public_key \
        --key "$avb_pem" \
        --output "$pkmd"
    # avb_pkmd.bin is a PUBLIC key blob — safe to distribute. Mode 0644 is
    # fine, but we set 0644 (world-readable) to match the report's note that
    # it is "safe to distribute". Use 0644 explicitly.
    chmod 0644 "$pkmd"
}

# ── Permissions ────────────────────────────────────────────────────────────
harden_permissions() {
    echo "→ Hardening permissions (0600 on private keys, 0700 on dir)"
    chmod 0700 "$OUTPUT_DIR"
    local f
    for f in "$OUTPUT_DIR"/*.pk8 "$OUTPUT_DIR"/*.x509.pem "$OUTPUT_DIR"/avb.pem; do
        [[ -e "$f" ]] && chmod 0600 "$f"
    done
    # avb_pkmd.bin stays 0644 (public)
}

# ── Summary table ──────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo " GuardTalkOS Signing Key Generation — Summary"
    echo "══════════════════════════════════════════════════════════════════════"
    printf " Output directory : %s\n" "$OUTPUT_DIR"
    printf " make_key         : %s\n" "$MAKE_KEY"
    printf " avbtool          : %s\n" "$AVBTOOL"
    printf " AVB algorithm    : %s\n" "$AVB_ALGORITHM"
    echo ""
    printf " %-18s %-40s %-8s %s\n" "KEY" "FILE" "BITS" "MODE"
    printf " %-18s %-40s %-8s %s\n" "------------------" \
        "----------------------------------------" "--------" "------"
    local k
    for k in releasekey platform shared media networkstack bluetooth nfc \
             sdk_sandbox gmscompat_lib; do
        local pk8="$OUTPUT_DIR/$k.pk8"
        local cert="$OUTPUT_DIR/$k.x509.pem"
        local mode="0600"
        local status="OK"
        [[ -e "$pk8"  ]] || status="MISSING pk8"
        [[ -e "$cert" ]] || status="MISSING x509.pem"
        printf " %-18s %-40s %-8s %s\n" "$k" "$k.pk8 + $k.x509.pem" "RSA-4096" "$mode ($status)"
    done
    printf " %-18s %-40s %-8s %s\n" "avb (private)" "avb.pem" "RSA-$AVB_KEY_BITS" "0600"
    printf " %-18s %-40s %-8s %s\n" "avb (public blob)" "avb_pkmd.bin" "—" "0644 (distributable)"
    echo "══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Create 3 encrypted backups (backup-signing-keys.sh)."
    echo "  2. Store backups in 3 geographically separate offline locations."
    echo "  3. Test restoration from ONE backup before trusting it."
    echo "  4. See vendor/guardtalk/branding/signing-keys/RUNBOOK.md for the"
    echo "     full bootloader-lock procedure."
    echo ""
    print_brick_warning
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo "GuardTalkOS Signing Key Generator"
    echo "Source-of-truth: vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md (A-SIGN-RESEARCH #1)"
    echo ""

    preflight

    # Create output dir with restrictive permissions
    mkdir -p "$OUTPUT_DIR"
    chmod 0700 "$OUTPUT_DIR"

    check_existing

    print_brick_warning

    echo "Generating GuardTalkOS signing key set into: $OUTPUT_DIR"
    echo "Subject CN prefix: $SUBJECT_CN_PREFIX"
    echo ""

    # 9 package keys (RSA-4096, scrypt-encrypted PKCS#8 + x509 PEM cert)
    # Order matches the report §1a / common.sh:136-146 (alphabetical).
    local keys=(
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
    local k
    for k in "${keys[@]}"; do
        generate_package_key "$k"
    done

    # AVB key (RSA-4096 PEM) + public-key blob
    generate_avb_key
    generate_avb_pkmd

    # Final permissions pass (belt-and-suspenders)
    harden_permissions

    print_summary
}

main "$@"
