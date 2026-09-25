#!/usr/bin/env bash
# Host-static verifier wrapper for T-REMEDIATE-B6-PROP-REACHABILITY.
# Pair of Q-REMEDIATE-B6-PROP-REACHABILITY. Read-only: no product edits, no
# packing, no flashing, no commit. Never claims on-device verification.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b6_prop_host.sh
# Optional:
#   STAMP=releases/desktop-flash/<other-stamp> bash .../verify_remediate_b6_prop_host.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

PY="vendor/guardtalk/docs/qa/verify_remediate_b6_prop_host.py"
STAMP="${STAMP:-releases/desktop-flash/komodo-debug-20260919-080101}"
export STAMP

echo "=== T-REMEDIATE-B6-PROP-REACHABILITY host verifier ==="
echo "root  = $ROOT"
echo "stamp = $STAMP"

command -v debugfs >/dev/null 2>&1 || { echo "FAIL: debugfs not found"; exit 1; }
[[ -f "$STAMP/vendor.img" ]] || { echo "FAIL: missing $STAMP/vendor.img"; exit 1; }
[[ -f "$STAMP/system.img" ]] || { echo "FAIL: missing $STAMP/system.img"; exit 1; }
[[ -f "$PY" ]] || { echo "FAIL: missing $PY"; exit 1; }

python3 "$PY" "$ROOT"
PY_RC=$?

echo "--- device state (must NOT be claimed) ---"
if command -v adb >/dev/null 2>&1; then
  DEV="$(adb devices 2>/dev/null | sed -n '2,$p' | grep -c 'device$' || true)"
  echo "adb_devices=$DEV"
  if [[ "$DEV" -gt 0 ]]; then
    echo "HOLD: a device is attached; this card does not flash or claim on-device"
    echo "      evidence. Rebuild+flash is required for the getprop contract."
  else
    echo "HOLD: no device attached; on-device getprop contract not exercised."
  fi
else
  echo "HOLD: adb not found; on-device getprop contract not exercised."
fi
echo "LIVE_DEVICE_CLAIMED=false"
echo "PACKED_OUT=false"
echo "FLASH_READY=false"
echo "USB_GO=false"
echo "PY_RC=$PY_RC"
exit "$PY_RC"
