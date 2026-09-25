#!/usr/bin/env bash
# Pack tokay + akita + komodo + rango desktop-flash stamps into
# web-installer/channels/{product}/ for the hosted wizard.
# Images are symlinked (no multi-GiB copies).
# Rango source stamp: releases/desktop-flash/rango-latest (experimental / boot HOLD).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PACK="${SCRIPT_DIR}/pack-webinstall-channel.sh"
OUT_ROOT="${REPO_ROOT}/vendor/guardtalk/web-installer/channels"

pack_one() {
    local product="$1" stamp="$2"
    local dest="${OUT_ROOT}/${product}"
    rm -rf "$dest"
    mkdir -p "$dest"
    "$PACK" --stamp "$stamp" --out "$dest" --copy-images
    echo "HOSTED_OK  ${product}  ${dest}"
}

pack_one tokay "${REPO_ROOT}/releases/desktop-flash/latest"
pack_one akita "${REPO_ROOT}/releases/desktop-flash/akita-latest"
pack_one komodo "${REPO_ROOT}/releases/desktop-flash/komodo-latest"
pack_one rango "${REPO_ROOT}/releases/desktop-flash/rango-latest"
echo "HOSTED_CHANNELS_OK  ${OUT_ROOT}"
