#!/usr/bin/env bash
# pack-channels.sh — `npm run channels:pack` entry point.
#
# WHY THIS EXISTS (T-WEBINSTALL-PATH-COUPLING-SWEEP):
#   `package.json` used to call a packer through a two-level parent-relative
#   path, which resolves to `vendor/scripts/` - a directory that does not exist.
#   The documented first-run step was therefore BROKEN in the parent layout
#   (verified: `bash: .../pack-wizard-hosted-channels.sh: No such file
#   or directory`).
#
# SELF-SUFFICIENCY (T-WEBINSTALL-PACKER-VENDOR):
#   The hosted packer is now VENDORED at `scripts/pack-wizard-hosted-channels.sh`
#   (and the per-channel packer at `scripts/pack-webinstall-channel.sh`), so a
#   standalone checkout / submodule can produce `channels/` with its own scripts
#   and no product repo beside it. The parent product-repo path
#   (`<product>/scripts/pack-wizard-hosted-channels.sh`) is a thin `exec` wrapper
#   around that same file, so it is kept as a fallback and cannot drift.
#
#   Resolution is a candidate list: in-repo first, then the parent wrapper. It
#   runs exactly one implementation - never a forked packing rule - and fails
#   with an actionable message (exit 2) when neither is present.
#
# WARNING: the hosted packer CLEARS and repacks `channels/<product>/` in the
#   installer tree it resolves to. `channels/` is generated state (gitignored);
#   never run this against the live tree while a gate/test run is in flight, and
#   use a throwaway copy when drilling.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(dirname "$HERE")"
PRODUCT_ROOT="$(dirname "$INSTALLER_ROOT")"

# shellcheck source=lib/resolve.sh
. "$HERE/lib/resolve.sh"

PACKER_CANDIDATES=(
    "$HERE/pack-wizard-hosted-channels.sh"
    "$PRODUCT_ROOT/scripts/pack-wizard-hosted-channels.sh"
)

if ! PACKER="$(gt_resolve_file pack-wizard-hosted-channels.sh "${PACKER_CANDIDATES[@]}")"; then
    gt_missing_die \
        "channels:pack" \
        "the hosted-channel packer (pack-wizard-hosted-channels.sh)" \
        "restore the vendored packer at <installer>/scripts/pack-wizard-hosted-channels.sh, or pack one channel directly with the per-channel packer: GUARDTALK_RELEASES_ROOT=<store> bash <installer>/scripts/pack-webinstall-channel.sh --stamp <store>/<product>-latest --out channels/<product> --copy-images" \
        "${PACKER_CANDIDATES[@]}"
    exit 2
fi

echo "[channels:pack] packer: $PACKER"

# The hosted packer honours GUARDTALK_RELEASES_ROOT (per-device <p>-latest
# pointers under it); say which store is in effect instead of leaving it implicit.
if [ -n "${GUARDTALK_RELEASES_ROOT:-}" ]; then
    echo "[channels:pack] release store: GUARDTALK_RELEASES_ROOT=${GUARDTALK_RELEASES_ROOT}" \
        "(read by the hosted packer as <store>/<product>-latest)" >&2
else
    echo "[channels:pack] release store: <tree default>; export GUARDTALK_RELEASES_ROOT=<store>" \
        "to pack from an external store" >&2
fi

exec bash "$PACKER" "$@"
