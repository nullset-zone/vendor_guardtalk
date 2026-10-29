#!/usr/bin/env bash
# Pack tokay + akita + komodo + rango desktop-flash stamps into THIS
# installer's channels/{product}/ for the hosted wizard.
# Images are symlinked (no multi-GiB copies).
# Rango source stamp: <store>/rango-latest (experimental / boot HOLD).
#
# This file is the ONE implementation (single source of truth). It is vendored
# into the installer so a standalone checkout / submodule can pack its own
# channels with no product repo beside it (T-WEBINSTALL-PACKER-VENDOR). The
# parent path `vendor/guardtalk/scripts/pack-wizard-hosted-channels.sh` is a
# thin `exec` wrapper around this file - never a second copy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# Last-resort default only: GUARDTALK_RELEASES_ROOT is authoritative (the
# release store is legitimately external, the scripts are not).
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
RELEASES_ROOT="${GUARDTALK_RELEASES_ROOT:-${REPO_ROOT}/releases/desktop-flash}"
PACK="${SCRIPT_DIR}/pack-webinstall-channel.sh"
# Self-relative: the channels/ tree of the installer this script lives in.
# Never a hardcoded <repo>/vendor/guardtalk/web-installer/channels, which only
# exists in the parent layout.
OUT_ROOT="${INSTALLER_ROOT}/channels"

# FAIL CLOSED on arguments (T-WEBINSTALL-PACKER-VENDOR incident, D-048).
# This script has no option parser and CLEARS + repacks channels/<product>/.
# Before this guard, `--help` / `--dry-run` were silently ignored and a live
# repack started - i.e. the most natural "just look at it" probe was
# destructive. Any argument is now refused before the first `rm -rf`.
if [ "$#" -gt 0 ]; then
    {
        echo "ERROR: pack-wizard-hosted-channels.sh takes no arguments (got: $*)"
        echo "       it CLEARS and repacks channels/<product>/ in this installer tree"
        echo "       for --help/--dry-run/--verify/--self-test use:"
        echo "         bash ${SCRIPT_DIR}/pack-webinstall-channel.sh <option>"
    } >&2
    exit 2
fi

pack_one() {
    local product="$1" stamp="$2"
    local dest="${OUT_ROOT}/${product}"
    rm -rf "$dest"
    mkdir -p "$dest"
    bash "$PACK" --stamp "$stamp" --out "$dest" --copy-images
    echo "HOSTED_OK  ${product}  ${dest}"
}

# tokay repointed off the RETIRED generic `latest` (quarantined 2026-10-01,
# T-EXCISE-STAMP-TREE-QUARANTINE) to the per-device `<codename>-latest` pointer.
# The generic `latest` alias must never be re-introduced.
pack_one tokay "${RELEASES_ROOT}/tokay-latest"
pack_one akita "${RELEASES_ROOT}/akita-latest"
pack_one komodo "${RELEASES_ROOT}/komodo-latest"
pack_one rango "${RELEASES_ROOT}/rango-latest"
echo "HOSTED_CHANNELS_OK  ${OUT_ROOT}"
