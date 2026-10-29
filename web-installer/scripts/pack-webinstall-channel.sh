#!/usr/bin/env bash
# pack-webinstall-channel.sh
#
# Adapt an existing tokay, akita, komodo, or rango desktop-flash stamp into a
# GuardTalkOS web-install channel (manifest + SHA256SUMS + GOS-like pointer).
# Does not rebuild images.
#
# DEC-WEBINSTALL-015: advertised allowlist is tokay + akita + komodo + rango.
# Rango is image-ready / packable / experimental / boot HOLD, not
# production-boot-green. Unstamped shiba / husky / caiman / tegu / comet reject.
# DEC-WEBINSTALL-006: flashOrder is firmware → avb_custom_key → os.
# DEC-WEBINSTALL-007: this channel is labeled dev/unlocked. Not GOS-equivalent
#   locked verified boot. Do not generate or commit private keys.
#
# This file is the ONE implementation (single source of truth). It is vendored
# into the installer so a standalone checkout / submodule can pack its own
# channels with no product repo beside it (T-WEBINSTALL-PACKER-VENDOR). The
# parent path `vendor/guardtalk/scripts/pack-webinstall-channel.sh` is a thin
# `exec` wrapper around this file - never a second copy.
#
# Usage (run from the installer directory or with an absolute path):
#   scripts/pack-webinstall-channel.sh --help
#   scripts/pack-webinstall-channel.sh --dry-run
#   scripts/pack-webinstall-channel.sh --stamp DIR --out DIR
#   scripts/pack-webinstall-channel.sh --verify DIR
#   scripts/pack-webinstall-channel.sh --self-test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT is a LAST-RESORT default only; GUARDTALK_RELEASES_ROOT is
# authoritative. From <android-tree>/vendor/guardtalk/web-installer/scripts the
# fourth level up is that tree's root. In a standalone checkout the default
# simply points at a tree with no release store, so a missing stamp still fails
# closed instead of inventing one.
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
# Release store: overridable so this script works from a standalone checkout of
# the installer (GUARDTALK_RELEASES_ROOT, matching scripts/gen-flash-matrix.mjs).
# Default preserves the in-tree layout exactly.
RELEASES_ROOT="${GUARDTALK_RELEASES_ROOT:-${REPO_ROOT}/releases/desktop-flash}"

readonly ADVERTISED_DEVICES=(tokay akita komodo rango)
readonly CHANNEL_DEFAULT="dev"
readonly BOOT_STATE="unlocked"
readonly CHANNEL_LABEL="dev/unlocked"
readonly POINTER_FORMAT="{releaseId} {unixEpoch} {product} dev"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "$*"; }

usage() {
    cat <<'EOF'
pack-webinstall-channel.sh — tokay/akita/komodo/rango desktop-flash → web-install channel

Reads an existing tokay, akita, komodo, or rango stamp (default: latest).
Emits a GOS-like pointer, SHA256SUMS, public avb_pkmd.bin, and manifest.json.
Does not rebuild Android images. Does not write *.pem / *.pk8 / .env.

Rango is experimental / boot HOLD (DEC-WEBINSTALL-015, DEC-RANGO-REMEDIATE-002).
It is image-ready and packable, not production-boot-green.

This channel is DEV/UNLOCKED (DEC-WEBINSTALL-007). It is not a GrapheneOS-
equivalent locked verified-boot product.

USAGE
  pack-webinstall-channel.sh [options]

OPTIONS
  --stamp DIR       Desktop-flash stamp (dir or symlink). Default: latest.
  --out DIR         Write channel metadata here (created if missing).
  --channel NAME    Channel token. Default: dev. production fails closed
                    unless a public signature file is present.
  --copy-images     Also copy/symlink published images into --out.
                    Default is metadata + avb_pkmd.bin only (no multi-GiB copy).
  --dry-run         Validate + hash; write metadata if --out is set.
  --verify DIR      Fail-closed verify of a previously packed channel dir.
  --verify-stamp D  With --verify, check SHA256SUMS against this stamp
                    (use when --out is metadata-only and images stay in the stamp).
  --self-test       Tiny synthetic stamps (no phone). Exit 0 on pass.
  -h, --help        Show this help.

ENVIRONMENT
  CHANNEL           Same as --channel if the flag is omitted.

POINTER (GOS-like)
  {releaseId} {unixEpoch} {product} dev

FACTORY ZIP
  Not emitted this wave. Flashcore should consume the file list + SHA256SUMS.
  A full -install- zip is a follow-on (must not invert firmware → AVB → OS).
EOF
}

is_secret_name() {
    local base="$1"
    [[ "$base" == ".env" || "$base" == *.pem || "$base" == *.pk8 ]]
}

phase_for() {
    local name="$1"
    case "$name" in
        bootloader.img|radio.img) echo firmware ;;
        avb_pkmd.bin) echo avb ;;
        *.img) echo os ;;
        *) echo "" ;;
    esac
}

resolve_stamp() {
    local raw="$1"
    local resolved
    [[ -e "$raw" ]] || die "stamp not found: $raw"
    resolved="$(readlink -f "$raw")"
    [[ -d "$resolved" ]] || die "stamp is not a directory: $raw -> $resolved"
    echo "$resolved"
}

parse_stamp_identity() {
    local stamp_base="$1"
    if [[ ! "$stamp_base" =~ ^([a-z0-9]+)-([0-9]{8})-([0-9]{6})$ ]]; then
        die "stamp name must be {product}-YYYYMMDD-HHMMSS, got: $stamp_base"
    fi
    PRODUCT="${BASH_REMATCH[1]}"
    RELEASE_ID="${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    local y="${BASH_REMATCH[2]:0:4}" m="${BASH_REMATCH[2]:4:2}" d="${BASH_REMATCH[2]:6:2}"
    local H="${BASH_REMATCH[3]:0:2}" M="${BASH_REMATCH[3]:2:2}" S="${BASH_REMATCH[3]:4:2}"
    UNIX_EPOCH="$(date -u -d "${y}-${m}-${d} ${H}:${M}:${S}" +%s)" \
        || die "cannot parse stamp timestamp: $stamp_base"
}

assert_advertised_product() {
    local product="$1"
    local allowed
    for allowed in "${ADVERTISED_DEVICES[@]}"; do
        [[ "$product" == "$allowed" ]] && return 0
    done
    die "product '$product' is not in the advertised allowlist (tokay, akita, komodo, rango)"
}

assert_public_avb() {
    local stamp="$1"
    local pkmd="${stamp}/avb_pkmd.bin"
    [[ -f "$pkmd" ]] || die "public avb_pkmd.bin missing in $stamp (fail closed)"
    if grep -qE 'BEGIN (RSA |EC |OPENSSH )?PRIVATE' "$pkmd"; then
        die "avb_pkmd.bin looks like a private key (fail closed)"
    fi
}

scan_stamp_secrets() {
    local stamp="$1"
    local f base
    shopt -s nullglob dotglob
    for f in "$stamp"/* "$stamp"/.*; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        [[ "$base" == "." || "$base" == ".." ]] && continue
        if is_secret_name "$base"; then
            log "WARN: ignoring secret-shaped file in stamp (will not publish): $base"
            if grep -qE 'BEGIN (RSA |EC |OPENSSH )?PRIVATE' "$f"; then
                die "private key material in stamp: $base (fail closed)"
            fi
        fi
    done
    shopt -u nullglob dotglob
}

list_publish_names() {
    local stamp="$1"
    local f base phase
    shopt -s nullglob
    for f in "$stamp"/*; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        is_secret_name "$base" && continue
        phase="$(phase_for "$base")"
        [[ -n "$phase" ]] || continue
        printf '%s\n' "$base"
    done | LC_ALL=C sort
    shopt -u nullglob
}

hash_artifacts() {
    local stamp="$1" tsv="$2"
    local name path phase digest size
    : >"$tsv"
    while IFS= read -r name; do
        path="${stamp}/${name}"
        [[ -f "$path" ]] || die "missing published artifact: $name"
        phase="$(phase_for "$name")"
        digest="$(sha256sum -- "$path" | awk '{print $1}')"
        size="$(stat -c '%s' -- "$path")"
        printf '%s\t%s\t%s\t%s\n' "$name" "$phase" "$digest" "$size" >>"$tsv"
    done
}

write_sha256sums() {
    local tsv="$1" dest="$2"
    : >"$dest"
    while IFS=$'\t' read -r name _phase digest _size; do
        printf '%s  %s\n' "$digest" "$name" >>"$dest"
    done <"$tsv"
}

write_file_list() {
    local tsv="$1" dest="$2"
    {
        echo "# GuardTalkOS web-install file list (${PRODUCT}, ${CHANNEL_LABEL})"
        echo "# flashOrder: firmware → avb_custom_key → os (DEC-WEBINSTALL-006)"
        echo "# No factory zip this wave. Flashcore consumes this list + SHA256SUMS."
        echo "#"
        echo "# name  phase  size"
        while IFS=$'\t' read -r name phase _digest size; do
            printf '%s  %s  %s\n' "$name" "$phase" "$size"
        done <"$tsv"
    } >"$dest"
}

write_pointer() {
    local dest="$1"
    printf '%s %s %s %s\n' "$RELEASE_ID" "$UNIX_EPOCH" "$PRODUCT" "$CHANNEL_TOKEN" >"$dest"
}

write_manifest() {
    local tsv="$1" dest="$2" stamp_base="$3" sig_mode="$4" sig_required="$5"
    python3 - "$tsv" "$dest" <<PY
import json, sys
tsv, dest = sys.argv[1], sys.argv[2]
artifacts = []
avb = None
with open(tsv, encoding="utf-8") as fh:
    for line in fh:
        name, phase, digest, size = line.rstrip("\\n").split("\\t")
        row = {"name": name, "phase": phase, "sha256": digest, "size": int(size)}
        artifacts.append(row)
        if name == "avb_pkmd.bin":
            avb = {"publicKeyFile": name, "sha256": digest, "size": int(size)}
if avb is None:
    raise SystemExit("avb_pkmd.bin missing from artifact TSV")
doc = {
    "schemaVersion": 1,
    "product": "${PRODUCT}",
    "advertisedDevices": ["${PRODUCT}"],
    "reservedProducts": [],
    "channel": "dev",
    "bootState": "unlocked",
    "channelLabel": "dev/unlocked",
    "verifiedBootClaim": "none",
    "releaseId": "${RELEASE_ID}",
    "unixEpoch": int("${UNIX_EPOCH}"),
    "sourceStamp": "${stamp_base}",
    "flashOrder": ["firmware", "avb_custom_key", "os"],
    "factoryZip": None,
    "factoryZipFollowOn": (
        "Not packed this wave: a full -install- zip would be multi-GiB and "
        "must not invent flash order. Flashcore consumes files.txt + SHA256SUMS. "
        "Any later zip MUST keep firmware → avb_custom_key → os (DEC-006)."
    ),
    "avb": avb,
    "artifacts": artifacts,
    "signature": {
        "required": json.loads("${sig_required}"),
        "mode": "${sig_mode}",
        "file": None,
        "allowedSigners": None,
        "note": (
            "No in-tree public channel signer. CHANNEL=dev is hash-only. "
            "CHANNEL=production fails closed when a signature is missing. "
            "Do not generate or commit private keys."
        ),
    },
}
with open(dest, "w", encoding="utf-8") as out:
    json.dump(doc, out, indent=2)
    out.write("\\n")
PY
}

copy_public_key() {
    local stamp="$1" out="$2"
    cp -p -- "${stamp}/avb_pkmd.bin" "${out}/avb_pkmd.bin"
}

maybe_copy_images() {
    local stamp="$1" out="$2" tsv="$3"
    local name
    while IFS=$'\t' read -r name _p _d _s; do
        [[ "$name" == "avb_pkmd.bin" ]] && continue
        ln -sfn -- "${stamp}/${name}" "${out}/${name}"
    done <"$tsv"
}

find_signature() {
    local dir="$1"
    local cand
    # T-WEBINSTALL-SIGNED-CHANNEL-ROOT: `channel-root.txt.sig` is the signed
    # CHANNEL ROOT — a statement binding manifest.json + SHA256SUMS — and it is
    # preferred over a single-file signature. The full check (that the signed
    # statement still describes the bytes on disk, against an OUT-OF-BAND trust
    # list) lives in `scripts/channel-signature.mjs`; this shell function keeps
    # the packer's own single-file/`allowed_signers` convention working.
    for cand in \
        "${dir}/channel-root.txt.sig" \
        "${dir}/manifest.json.sig" \
        "${dir}/tokay-dev.sig" \
        "${dir}/akita-dev.sig" \
        "${dir}/komodo-dev.sig" \
        "${dir}/rango-dev.sig" \
        "${dir}/SHA256SUMS.sig"; do
        [[ -f "$cand" ]] && { echo "$cand"; return 0; }
    done
    return 1
}

verify_production_sig() {
    local dir="$1"
    local sig signers
    sig="$(find_signature "$dir" || true)"
    [[ -n "$sig" ]] || die "CHANNEL=production requires a public .sig (fail closed)"
    signers="${dir}/allowed_signers"
    [[ -f "$signers" ]] || die "CHANNEL=production requires allowed_signers (fail closed)"
    command -v ssh-keygen >/dev/null 2>&1 \
        || die "ssh-keygen missing; cannot verify CHANNEL=production signature"
    local payload="${sig%.sig}"
    [[ -f "$payload" ]] || die "signature payload missing: $payload"
    ssh-keygen -Y verify -f "$signers" -I guardtalk-channel \
        -n "factory images" -s "$sig" <"$payload" \
        || die "CHANNEL=production signature verify failed"
}

verify_sums_against() {
    local sums="$1" root="$2"
    local digest name path actual checked=0
    while read -r digest name; do
        [[ -n "$digest" && -n "$name" ]] || continue
        path="${root}/${name}"
        if [[ ! -f "$path" ]]; then
            if [[ "$name" == "avb_pkmd.bin" ]]; then
                die "avb_pkmd.bin listed in SHA256SUMS but missing under $root"
            fi
            log "verify: hash recorded, blob not staged: $name"
            continue
        fi
        actual="$(sha256sum -- "$path" | awk '{print $1}')"
        [[ "$actual" == "$digest" ]] || die "SHA256 mismatch: $name"
        checked=$((checked + 1))
    done <"$sums"
    [[ "$checked" -ge 1 ]] || die "SHA256SUMS verified zero files under $root"
}

# Cross-check manifest.json against SHA256SUMS (T-WEBINSTALL-VERIFY-MANIFEST-
# SUMS-CROSSCHECK). Existence is not verification: before this, the token
# `manifest` was only ever tested with -f, so a channel whose manifest.json
# described DIFFERENT bytes than SHA256SUMS verified green — the manifest is the
# machine-readable contract a consumer reads (QA experiment A7, DECISION_LOG
# D-019). Fail closed on: missing/unparseable manifest, a differing artifact SET
# on either side, a per-artifact sha256 or size disagreement, and an
# avb.sha256 that does not match the anchor row.
verify_manifest_against() {
    local manifest="$1" sums="$2" files="$3" blob_root="$4"
    python3 - "$manifest" "$sums" "$files" "$blob_root" <<'PY'
import json, os, re, sys

manifest_path, sums_path, files_path, blob_root = sys.argv[1:5]


def fail(message):
    sys.stderr.write("ERROR: manifest.json disagrees with SHA256SUMS: %s\n" % message)
    raise SystemExit(1)


def sha_rows(path):
    rows = {}
    try:
        handle = open(path, encoding="utf-8")
    except OSError as exc:
        fail("cannot read %s (fail closed): %s" % (path, exc))
    with handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            match = re.match(r"^([0-9a-fA-F]{64}) [ *](.+)$", line)
            if match is None:
                fail("unparseable SHA256SUMS row %r" % line)
            rows[match.group(2).strip()] = match.group(1).lower()
    return rows


sums = sha_rows(sums_path)
if not sums:
    fail("SHA256SUMS lists no files (fail closed)")

try:
    with open(manifest_path, encoding="utf-8") as handle:
        doc = json.load(handle)
except FileNotFoundError:
    fail("manifest.json is missing (fail closed)")
except OSError as exc:
    fail("manifest.json is unreadable (fail closed): %s" % exc)
except ValueError as exc:
    fail("manifest.json is unparseable (fail closed): %s" % exc)

if not isinstance(doc, dict):
    fail("manifest.json is not a JSON object (fail closed)")

artifacts = doc.get("artifacts")
if not isinstance(artifacts, list) or not artifacts:
    fail("manifest.json declares no artifacts array (fail closed)")

declared = {}
for index, row in enumerate(artifacts):
    if not isinstance(row, dict):
        fail("artifacts[%d] is not an object (fail closed)" % index)
    name = row.get("name")
    digest = row.get("sha256")
    size = row.get("size")
    if not isinstance(name, str) or not name:
        fail("artifacts[%d] has no name (fail closed)" % index)
    if name in declared:
        fail("manifest.json lists %s twice (fail closed)" % name)
    if not isinstance(digest, str) or re.fullmatch(r"[0-9a-fA-F]{64}", digest) is None:
        fail("%s: manifest sha256 is missing or malformed (fail closed)" % name)
    if not isinstance(size, int) or isinstance(size, bool) or size < 0:
        fail("%s: manifest size is missing or not a non-negative integer (fail closed)" % name)
    declared[name] = {"sha256": digest.lower(), "size": size}

# The artifact SET must be identical on both sides — no orphan either way.
invented = sorted(set(declared) - set(sums))
omitted = sorted(set(sums) - set(declared))
if invented:
    fail("artifact(s) in manifest.json but not in SHA256SUMS: %s" % ", ".join(invented))
if omitted:
    fail("artifact(s) in SHA256SUMS but not in manifest.json: %s" % ", ".join(omitted))

file_sizes = {}
if os.path.exists(files_path):
    with open(files_path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) == 3 and parts[2].isdigit():
                file_sizes[parts[0]] = int(parts[2])

for name in sorted(declared):
    row = declared[name]
    if row["sha256"] != sums[name]:
        fail("%s: manifest sha256 %s != SHA256SUMS %s" % (name, row["sha256"], sums[name]))
    if name in file_sizes and file_sizes[name] != row["size"]:
        fail("%s: manifest size %d != files.txt %d" % (name, row["size"], file_sizes[name]))
    blob = os.path.join(blob_root, name)
    if os.path.isfile(blob):
        actual = os.path.getsize(blob)
        if actual != row["size"]:
            fail("%s: manifest size %d != %d bytes on disk" % (name, row["size"], actual))

# The public AVB anchor must match the anchor row it is published beside.
avb = doc.get("avb")
if not isinstance(avb, dict):
    fail("manifest.json declares no avb block (fail closed)")
key_file = avb.get("publicKeyFile")
if not isinstance(key_file, str) or not key_file:
    fail("avb.publicKeyFile is missing (fail closed)")
if key_file not in sums:
    fail("avb.publicKeyFile %s has no SHA256SUMS row (fail closed)" % key_file)
avb_digest = avb.get("sha256")
if not isinstance(avb_digest, str) or avb_digest.lower() != sums[key_file]:
    fail("avb.sha256 %s != SHA256SUMS anchor row %s" % (avb_digest, sums[key_file]))
if key_file in declared and declared[key_file]["sha256"] != avb_digest.lower():
    fail("avb.sha256 disagrees with its own artifacts[] row (%s)" % key_file)

print("verify: manifest.json cross-checks SHA256SUMS (%d artifacts)" % len(declared))
PY
}

verify_channel_dir() {
    local dir="$1"
    local hash_root="${2:-$dir}"
    local pointer="" cand
    shopt -s nullglob
    for cand in "$dir"/tokay-dev "$dir"/akita-dev "$dir"/komodo-dev "$dir"/rango-dev; do
        [[ -f "$cand" ]] && pointer="$cand"
    done
    shopt -u nullglob
    local sums="${dir}/SHA256SUMS"
    local manifest="${dir}/manifest.json"
    [[ -n "$pointer" && -f "$pointer" ]] || die "missing channel pointer: tokay-dev, akita-dev, komodo-dev, or rango-dev"
    [[ -f "$sums" ]] || die "missing SHA256SUMS"
    [[ -f "$manifest" ]] || die "missing manifest.json"
    [[ -f "${dir}/avb_pkmd.bin" ]] || die "missing public avb_pkmd.bin"
    local body
    body="$(tr -d '\r' <"$pointer")"
    [[ "$body" =~ ^[A-Za-z0-9._-]+[[:space:]]+[0-9]+[[:space:]]+(tokay|akita|komodo|rango)[[:space:]]+(dev|unlocked)$ ]] \
        || die "pointer must be: ${POINTER_FORMAT} (or unlocked)"
    local product
    product="$(awk '{print $3}' <<<"$body")"
    assert_advertised_product "$product"
    local f base
    shopt -s nullglob
    for f in "$dir"/*; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        [[ "$base" == *.img ]] && continue
        if grep -qE 'BEGIN (RSA |EC |OPENSSH )?PRIVATE' "$f"; then
            die "private key material in channel dir: $base"
        fi
    done
    for f in "$dir"/*.pem "$dir"/*.pk8 "$dir"/.env; do
        [[ -e "$f" ]] && die "secret-shaped file in channel dir: $(basename "$f")"
    done
    shopt -u nullglob
    verify_sums_against "$sums" "$hash_root"
    # manifest.json is the consumer's contract: it must describe the SAME bytes
    # and the SAME artifact set SHA256SUMS pins (fail closed, no silent pass).
    verify_manifest_against "$manifest" "$sums" "${dir}/files.txt" "$hash_root" \
        || die "manifest.json cross-check failed (fail closed)"
    if [[ "$CHANNEL_TOKEN" == "production" ]]; then
        verify_production_sig "$dir"
    else
        log "verify: CHANNEL=${CHANNEL_TOKEN} hash-only (signature not required)"
    fi
    log "VERIFY_OK  pointer=$(cat "$pointer")  files=$(wc -l <"$sums")"
}

pack_channel() {
    local stamp="$1" out="$2"
    local stamp_base tsv
    stamp_base="$(basename "$stamp")"
    parse_stamp_identity "$stamp_base"
    assert_advertised_product "$PRODUCT"
    assert_public_avb "$stamp"
    scan_stamp_secrets "$stamp"
    if [[ "$CHANNEL_TOKEN" == "production" ]]; then
        die "CHANNEL=production cannot pack: no in-tree public signer (fail closed)"
    fi
    mapfile -t PUBLISH < <(list_publish_names "$stamp")
    [[ ${#PUBLISH[@]} -gt 0 ]] || die "no publishable artifacts in $stamp"
    printf '%s\n' "${PUBLISH[@]}" | grep -qx bootloader.img \
        || die "stamp missing bootloader.img"
    printf '%s\n' "${PUBLISH[@]}" | grep -qx avb_pkmd.bin \
        || die "stamp missing public avb_pkmd.bin"
    tsv="$(mktemp)"
    hash_artifacts "$stamp" "$tsv" < <(printf '%s\n' "${PUBLISH[@]}")
    local sig_mode="hash-only" sig_required="false"
    if [[ "$DRY_RUN" -eq 1 && -z "$out" ]]; then
        log "DRY-RUN product=${PRODUCT} releaseId=${RELEASE_ID} epoch=${UNIX_EPOCH}"
        log "DRY-RUN pointer: ${RELEASE_ID} ${UNIX_EPOCH} ${PRODUCT} ${CHANNEL_TOKEN}"
        log "DRY-RUN channelLabel=${CHANNEL_LABEL} verifiedBootClaim=none"
        log "DRY-RUN advertisedDevices=${PRODUCT}"
        log "DRY-RUN factoryZip=null (follow-on; do not invent flash order)"
        write_sha256sums "$tsv" "${tsv}.sums"
        cat "${tsv}.sums"
        rm -f "$tsv" "${tsv}.sums"
        return 0
    fi
    [[ -n "$out" ]] || die "--out is required unless --dry-run without output"
    mkdir -p "$out"
    write_pointer "${out}/${PRODUCT}-dev"
    write_sha256sums "$tsv" "${out}/SHA256SUMS"
    write_file_list "$tsv" "${out}/files.txt"
    write_manifest "$tsv" "${out}/manifest.json" "$stamp_base" \
        "$sig_mode" "$sig_required"
    copy_public_key "$stamp" "$out"
    if [[ "$COPY_IMAGES" -eq 1 ]]; then
        maybe_copy_images "$stamp" "$out" "$tsv"
    fi
    rm -f "$tsv"
    log "PACK_OK  pointer=$(cat "${out}/${PRODUCT}-dev")"
    log "PACK_OK  out=${out}  copies_images=${COPY_IMAGES}  dry_run=${DRY_RUN}"
    log "PACK_OK  ${CHANNEL_LABEL}  verifiedBootClaim=none  factoryZip=null"
}

self_test() {
    local tmp tokay_stamp akita_stamp komodo_stamp rango_stamp out
    tmp="$(mktemp -d)"
    tokay_stamp="${tmp}/tokay-20990101-000000"
    akita_stamp="${tmp}/akita-20990101-000000"
    komodo_stamp="${tmp}/komodo-20990101-000000"
    rango_stamp="${tmp}/rango-20990101-000000"
    mkdir -p "$tokay_stamp" "$akita_stamp" "$komodo_stamp" "$rango_stamp"
    printf 'public-avb-blob\n' >"${tokay_stamp}/avb_pkmd.bin"
    printf 'fw\n' >"${tokay_stamp}/bootloader.img"
    printf 'os\n' >"${tokay_stamp}/boot.img"
    cp -p -- "${tokay_stamp}/avb_pkmd.bin" "${akita_stamp}/avb_pkmd.bin"
    printf 'fw\n' >"${akita_stamp}/bootloader.img"
    printf 'os\n' >"${akita_stamp}/boot.img"
    cp -p -- "${tokay_stamp}/avb_pkmd.bin" "${komodo_stamp}/avb_pkmd.bin"
    printf 'fw\n' >"${komodo_stamp}/bootloader.img"
    printf 'os\n' >"${komodo_stamp}/boot.img"
    cp -p -- "${tokay_stamp}/avb_pkmd.bin" "${rango_stamp}/avb_pkmd.bin"
    printf 'fw\n' >"${rango_stamp}/bootloader.img"
    printf 'os\n' >"${rango_stamp}/boot.img"
    out="${tmp}/out-tokay"
    CHANNEL_TOKEN="dev" DRY_RUN=0 COPY_IMAGES=0 \
        pack_channel "$tokay_stamp" "$out"
    CHANNEL_TOKEN="dev" verify_channel_dir "$out"
    # T-WEBINSTALL-VERIFY-MANIFEST-SUMS-CROSSCHECK: a manifest that describes
    # different bytes than SHA256SUMS (and a manifest that omits or invents an
    # artifact) must NOT verify green. Each tamper is applied to a pristine copy
    # of the genuine channel, so only the manifest changes.
    local tamper kind
    for kind in digest omit invent; do
        tamper="${tmp}/out-tamper-${kind}"
        cp -R -- "$out" "$tamper"
        python3 - "$tamper/manifest.json" "$kind" <<'PY'
import json, sys

path, kind = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    doc = json.load(fh)
if kind == "digest":
    doc["artifacts"][0]["sha256"] = "0" * 64
elif kind == "omit":
    doc["artifacts"] = doc["artifacts"][1:]
elif kind == "invent":
    doc["artifacts"].append({"name": "ghost.img", "phase": "os", "sha256": "1" * 64, "size": 7})
with open(path, "w", encoding="utf-8") as out:
    json.dump(doc, out, indent=2)
PY
        if ( CHANNEL_TOKEN="dev" verify_channel_dir "$tamper" ) 2>"${tmp}/tamper-${kind}.err"; then
            die "self-test: tampered manifest (${kind}) must fail --verify"
        fi
        grep -q "manifest.json disagrees with SHA256SUMS" "${tmp}/tamper-${kind}.err" \
            || die "self-test: manifest mismatch error text missing (${kind})"
    done
    CHANNEL_TOKEN="dev" DRY_RUN=0 COPY_IMAGES=0 \
        pack_channel "$akita_stamp" "${tmp}/out-akita"
    CHANNEL_TOKEN="dev" verify_channel_dir "${tmp}/out-akita"
    CHANNEL_TOKEN="dev" DRY_RUN=0 COPY_IMAGES=0 \
        pack_channel "$komodo_stamp" "${tmp}/out-komodo"
    CHANNEL_TOKEN="dev" verify_channel_dir "${tmp}/out-komodo"
    [[ -f "${tmp}/out-komodo/komodo-dev" ]] \
        || die "self-test: komodo-dev pointer missing"
    CHANNEL_TOKEN="dev" DRY_RUN=0 COPY_IMAGES=0 \
        pack_channel "$rango_stamp" "${tmp}/out-rango"
    CHANNEL_TOKEN="dev" verify_channel_dir "${tmp}/out-rango"
    [[ -f "${tmp}/out-rango/rango-dev" ]] \
        || die "self-test: rango-dev pointer missing"
    local unstamped stamp
    for unstamped in shiba husky caiman; do
        stamp="${tmp}/${unstamped}-20990101-000000"
        mkdir -p "$stamp"
        printf 'public-avb-blob\n' >"${stamp}/avb_pkmd.bin"
        printf 'fw\n' >"${stamp}/bootloader.img"
        printf 'os\n' >"${stamp}/boot.img"
        if ( CHANNEL_TOKEN="dev" DRY_RUN=0 COPY_IMAGES=0 \
            pack_channel "$stamp" "${tmp}/out-${unstamped}" ) 2>"${tmp}/${unstamped}.err"; then
            die "self-test: ${unstamped} stamp must be rejected"
        fi
        grep -q "not in the advertised allowlist" "${tmp}/${unstamped}.err" \
            || die "self-test: ${unstamped} error text missing"
    done
    if ( CHANNEL_TOKEN="production" DRY_RUN=1 COPY_IMAGES=0 \
        pack_channel "$tokay_stamp" "" ) 2>"${tmp}/prod.err"; then
        die "self-test: CHANNEL=production without sig must fail"
    fi
    grep -q "fail closed" "${tmp}/prod.err" \
        || die "self-test: production fail-closed text missing"
    local pem_stamp="${tmp}/tokay-20990101-000001"
    mkdir -p "$pem_stamp"
    printf 'public-avb-blob\n' >"${pem_stamp}/avb_pkmd.bin"
    printf 'fw\n' >"${pem_stamp}/bootloader.img"
    printf '%s\n' '-----BEGIN PRIVATE KEY-----' 'AAAA' '-----END PRIVATE KEY-----' \
        >"${pem_stamp}/evil.pk8"
    if ( CHANNEL_TOKEN="dev" DRY_RUN=0 COPY_IMAGES=0 \
        pack_channel "$pem_stamp" "${tmp}/out-pem" ) 2>"${tmp}/pem.err"; then
        die "self-test: private key in stamp must fail"
    fi
    rm -rf "$tmp"
    log "SELF_TEST_OK"
}

main() {
    local stamp="${RELEASES_ROOT}/latest"
    local out="" mode="pack"
    CHANNEL_TOKEN="${CHANNEL:-$CHANNEL_DEFAULT}"
    DRY_RUN=0
    COPY_IMAGES=0
    VERIFY_STAMP=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stamp) stamp="$2"; shift 2 ;;
            --out) out="$2"; shift 2 ;;
            --channel) CHANNEL_TOKEN="$2"; shift 2 ;;
            --copy-images) COPY_IMAGES=1; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            --verify) mode="verify"; out="$2"; shift 2 ;;
            --verify-stamp) VERIFY_STAMP="$2"; shift 2 ;;
            --self-test) mode="self-test"; shift ;;
            -h|--help) usage; return 0 ;;
            *) die "unknown argument: $1 (try --help)" ;;
        esac
    done
    case "$CHANNEL_TOKEN" in
        dev|unlocked|production) ;;
        *) die "unsupported CHANNEL='$CHANNEL_TOKEN' (dev|unlocked|production)" ;;
    esac
    [[ "$CHANNEL_TOKEN" == "unlocked" ]] && CHANNEL_TOKEN="dev"
    case "$mode" in
        self-test) self_test; return 0 ;;
        verify)
            [[ -n "$out" ]] || die "--verify requires a directory"
            local hash_root
            hash_root="$(resolve_stamp "$out")"
            if [[ -n "${VERIFY_STAMP:-}" ]]; then
                verify_channel_dir "$hash_root" "$(resolve_stamp "$VERIFY_STAMP")"
            else
                verify_channel_dir "$hash_root"
            fi
            return 0
            ;;
    esac
    if [[ ! -e "$stamp" ]]; then
        die "HOLD: stamp missing at $stamp (ship script+schema; no live pack)"
    fi
    stamp="$(resolve_stamp "$stamp")"
    pack_channel "$stamp" "$out"
}

main "$@"
