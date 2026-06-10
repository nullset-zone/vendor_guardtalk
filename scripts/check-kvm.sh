#!/usr/bin/env bash
# Quick KVM readiness check for the Android emulator on Linux.
set -eo pipefail

ok=0
if [[ ! -e /dev/kvm ]]; then
  echo "FAIL: /dev/kvm missing — install KVM kernel modules (see vendor/guardtalk/docs/KVM.md)"
  exit 1
fi
if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
  echo "FAIL: /dev/kvm exists but user $(id -un) cannot read/write it."
  echo "      Run: sudo gpasswd -a \$USER kvm"
  echo "      Then log out and back in (new SSH session)."
  echo "      Docs: vendor/guardtalk/docs/KVM.md"
  exit 1
fi
if ! lsmod | grep -q '^kvm'; then
  echo "WARN: kvm module not loaded — try: sudo modprobe kvm && sudo modprobe kvm_intel"
fi
echo "OK: KVM accessible for $(id -un)"
exit 0
