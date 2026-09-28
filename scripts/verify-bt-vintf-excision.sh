#!/usr/bin/env bash
# T-EXCISE-BT-VINTF-NOBT — assert the RUNTIME-MERGED vendor VINTF manifest
# declares no Bluetooth HAL, on the main manifest AND every
# /vendor/etc/vintf/manifest/*.xml fragment (libvintf merges both at runtime,
# VintfObject.cpp:282-328). R-3.
#
# The real work is done by
#   vendor/guardtalk/vintf/checks/check_vintf_bt_absence.py
# (declaration-level: it parses <hal><name>, so comments and the audio HAL's
# `IModule/bluetooth` fqname are not false positives).
#
# Usage:
#   verify-bt-vintf-excision.sh                     # fixture self-test only
#   verify-bt-vintf-excision.sh --capture DIR       # DIR = extracted .../vendor/etc/vintf
#   verify-bt-vintf-excision.sh --device tokay      # a device's gate cache
#   verify-bt-vintf-excision.sh --forbid bt+radio   # also fail on the dmd/radio class
#
# Exit 0 only when the fixture self-test passes AND any supplied target has 0
# forbidden declarations.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
CHK="$REPO/vendor/guardtalk/vintf/checks/check_vintf_bt_absence.py"
FIXTURES="$REPO/vendor/guardtalk/vintf/checks/fixtures"

FORBID="bt"
TARGETS=()   # check arguments

while [ $# -gt 0 ]; do
  case "$1" in
    --capture) shift; TARGETS+=(--vintf-root "$1") ;;
    --device)  shift; TARGETS+=(--device-capture "$1") ;;
    --forbid)  shift; FORBID="$1" ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -f "$CHK" ]; then
  echo "error: checker not found: $CHK" >&2
  exit 2
fi

RC=0

echo "=== fixture self-test (positive + negative fixtures) ==="
python3 "$CHK" --fixtures "$FIXTURES" || RC=1

if [ "${#TARGETS[@]}" -gt 0 ]; then
  echo
  echo "=== target check ($FORBID) ==="
  python3 "$CHK" "${TARGETS[@]}" --forbid "$FORBID" || RC=1
fi

echo
if [ "$RC" -eq 0 ]; then
  echo "VERDICT: PASS"
else
  echo "VERDICT: FAIL"
fi
exit "$RC"
