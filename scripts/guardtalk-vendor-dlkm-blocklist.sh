#!/bin/bash
# vendor/guardtalk/scripts/guardtalk-vendor-dlkm-blocklist.sh
#
# T-EXCISE-STAGE-RANGO-BLOCKLIST (2026-09-26) — shared vendor_dlkm blocklist
# graft helper.
#
# Single source of truth for grafting the registry-resolved GuardTalk
# `modules.blocklist` into a factory `vendor_dlkm` ext2 image. The four
# function bodies below are extracted VERBATIM from stage-laguna-release.sh
# (sha256 `04803bf6c69dacae60717a0b4debbacd9058235749623d2c6de351724510aeaa`,
# functions `gt_blocklist_registry:2500` .. `stage_vendor_dlkm_with_blocklist:2548`)
# so stage-rango-release.sh reuses the exact same implementation rather than
# forking a second, divergent one.
#
# RESIDUAL (recorded, not silently resolved): stage-laguna-release.sh still
# carries an inline copy of these functions, because `T-EXCISE-STAMP-GATE` owns
# that file and it must not be edited by this lane. When that lock releases,
# laguna should source this file too so the two callers cannot drift. Until
# then the lane's harness asserts the extracted bodies stay byte-identical to
# laguna's inline copies (see evidence dir).
#
# Contract — the sourcing script MUST provide before calling any function:
#   * bash with `set -euo pipefail`
#   * ROOT, HOST_BIN, STOCK and DEV variables set
#   * functions `need()`, `die()`, `log()`, `unsparse_if_needed()` defined
# Fail-closed: a missing registry row, a missing blocklist file, a source
# without `blocklist nitrous`, a debugfs write failure, or a read-back that
# does not byte-match the source aborts the calling stamp.
# ===========================================================================

gt_blocklist_registry() { echo "$ROOT/vendor/guardtalk/feature-excised/excision-variants.mk"; }

gt_resolve_blocklist_source() {
  # $1 = device codename. Echoes the absolute registry-resolved blocklist path.
  local dev="$1" reg variant rel
  reg="$(gt_blocklist_registry)"
  need "$reg"
  variant="$(sed -n "s/^GT_DEVICE_VARIANT_${dev}[[:space:]]*:=[[:space:]]*//p" "$reg" | tr -d '[:space:]')"
  [ -n "$variant" ] \
    || die "no GT_DEVICE_VARIANT_${dev} row in $reg — refusing to guess a blocklist (mirrors excision-variant-select.mk \$(error))"
  rel="$(sed -n "s/^GT_DEVICE_BLOCKLIST_${dev}[[:space:]]*:=[[:space:]]*//p" "$reg" | tr -d '[:space:]')"
  if [ -z "$rel" ]; then
    rel="$(sed -n "s/^GT_VARIANT_${variant}_BLOCKLIST[[:space:]]*:=[[:space:]]*//p" "$reg" | tr -d '[:space:]')"
  fi
  [ -n "$rel" ] \
    || die "variant '$variant' (device '$dev') has no ..._BLOCKLIST row in $reg"
  echo "$ROOT/$rel"
}

graft_vendor_dlkm_blocklist() {
  # $1 = raw vendor_dlkm ext2 image (already unsparsed), $2 = blocklist source.
  # Replaces /lib/modules/modules.blocklist and verifies it byte-for-byte.
  local img="$1" src="$2" dbg="$HOST_BIN/debugfs" rb rc=0
  need "$img"; need "$src"
  [ -x "$dbg" ] || die "debugfs missing at $dbg — required for the vendor_dlkm blocklist graft"
  grep -qE '^[[:space:]]*blocklist[[:space:]]+nitrous' "$src" \
    || die "blocklist source '$src' has no 'blocklist nitrous' directive — refusing to ship an un-excised vendor_dlkm"

  "$dbg" -w -R "rm /lib/modules/modules.blocklist" "$img" >/dev/null 2>&1 || true
  "$dbg" -w -R "write $src /lib/modules/modules.blocklist" "$img" >/dev/null \
    || die "debugfs write of $src -> $img:/lib/modules/modules.blocklist failed"

  rb="$(mktemp "/tmp/$(basename "$img").blocklist.XXXXXX")"
  "$dbg" -R "dump /lib/modules/modules.blocklist $rb" "$img" >/dev/null 2>&1 \
    || { rm -f "$rb"; die "debugfs read-back of the grafted blocklist failed for $img"; }
  if ! cmp -s "$rb" "$src"; then
    rm -f "$rb"
    die "grafted modules.blocklist in $img does not byte-match '$src' — refusing to ship"
  fi
  rm -f "$rb"

  if command -v e2fsck >/dev/null 2>&1; then
    e2fsck -fn "$img" >/dev/null 2>&1 || rc=$?
    [ "$rc" -le 2 ] || die "post-graft e2fsck FAILED (rc=$rc) on $img — filesystem left inconsistent"
  fi
  log "  vendor_dlkm blocklist grafted from $(basename "$src") ($(grep -cE '^[[:space:]]*blocklist' "$src" || true) directives, read-back byte-identical) ✓"
}

stage_vendor_dlkm_with_blocklist() {
  # $1 = destination raw image path. Unsparses the factory donor into $1 and
  # grafts the registry-resolved per-device blocklist.
  unsparse_if_needed "$STOCK/vendor_dlkm.img" "$1"
  graft_vendor_dlkm_blocklist "$1" "$(gt_resolve_blocklist_source "$DEV")"
}
