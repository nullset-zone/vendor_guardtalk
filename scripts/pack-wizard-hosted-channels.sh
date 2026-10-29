#!/usr/bin/env bash
# pack-wizard-hosted-channels.sh - THIN DELEGATION WRAPPER (parent layout only).
#
# The ONE implementation of the hosted-channel packing logic lives in the
# installer it belongs to:
#   <product>/web-installer/scripts/pack-wizard-hosted-channels.sh
#
# This path is kept so every pre-existing caller keeps working (docs,
# docs/qa verify gates, `npm run channels:pack` fallback). It contains NO
# packing logic: it `exec`s the in-repo copy, so the two paths cannot drift into
# divergent implementations. T-WEBINSTALL-PACKER-VENDOR.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(basename "${BASH_SOURCE[0]}")"
TARGET="${HERE}/../web-installer/scripts/${NAME}"

if [ ! -f "$TARGET" ]; then
    {
        echo "ERROR: ${NAME}: this is a thin wrapper, but its implementation is missing"
        echo "       target: ${TARGET}"
        echo "       fix: restore <product>/web-installer/scripts/${NAME} (single source of truth)"
    } >&2
    exit 2
fi

exec bash "$TARGET" "$@"
