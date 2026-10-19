#!/usr/bin/env bash
# check-channel-integrity.sh — fail closed if any shipped channel's bytes stop
# matching its own SHA256SUMS.
#
# WHY THIS EXISTS (INCIDENT 2026-10-18T12:13):
#   `vendor/guardtalk/web-installer/channels/` is GITIGNORED. A lane drilled a
#   forged-AVB-anchor test against the LIVE tree instead of a temp copy and
#   overwrote three of the four real `avb_pkmd.bin` trust anchors with random
#   bytes. `git status` reported the channels as CLEAN, because git does not
#   track them. The corruption was invisible to every git-based check.
#
# This script is the missing tripwire. Run it:
#   - before any test/bench that touches a channel
#   - before packing
#   - in the readiness gate or CI
#
# EXIT CODES
#   0  every channel's bytes match its SHA256SUMS
#   1  at least one channel's bytes do NOT match (TAMPERED) — fail closed
#   2  a channel directory or its SHA256SUMS is missing — cannot verify
#
# HONESTY: matching bytes means "self-consistent with this channel's own sums",
# not "authentic". Authenticity needs the out-of-band pin (expected-anchors).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNELS_DIR="${1:-$HERE/../channels}"

if [[ ! -d "$CHANNELS_DIR" ]]; then
  echo "INTEGRITY: ERROR — channels dir not found: $CHANNELS_DIR" >&2
  exit 2
fi

fail=0
error=0
checked=0

shopt -s nullglob
for dir in "$CHANNELS_DIR"/*/; do
  name="$(basename "$dir")"
  sums="$dir/SHA256SUMS"
  if [[ ! -f "$sums" ]]; then
    echo "INTEGRITY: ERROR  $name — no SHA256SUMS (cannot verify)"
    error=1
    continue
  fi

  checked=$((checked + 1))
  # Only verify files that are actually present; missing blobs are a separate
  # (packer --verify) concern, not an integrity concern.
  ( cd "$dir" && sha256sum -c --quiet SHA256SUMS 2>&1 ) > /tmp/.gt-integrity.$$ 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "INTEGRITY: ok     $name"
  else
    echo "INTEGRITY: TAMPERED $name"
    sed 's/^/           /' /tmp/.gt-integrity.$$
    fail=1
  fi
  rm -f /tmp/.gt-integrity.$$
done
shopt -u nullglob

if [[ $checked -eq 0 ]]; then
  echo "INTEGRITY: ERROR — no channel dirs found under $CHANNELS_DIR" >&2
  exit 2
fi
if [[ $error -ne 0 ]]; then
  echo "INTEGRITY: FAIL (exit 2) — $checked channel(s) checked, unverifiable channel(s) present"
  exit 2
fi
if [[ $fail -ne 0 ]]; then
  echo "INTEGRITY: FAIL (exit 1) — $checked channel(s) checked, TAMPERED bytes present"
  echo "           DO NOT flash, pack, or cite readiness. Restore from the source stamp."
  exit 1
fi

echo "INTEGRITY: PASS (exit 0) — $checked channel(s) match their SHA256SUMS"
exit 0
