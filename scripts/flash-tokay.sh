#!/usr/bin/env bash
# Flash GuardTalkOS (tokay) from a local build tree.
# Requires: unlocked bootloader, USB, compatible bootloader/baseband (see firmware/android-info.txt).
set -euo pipefail

TOP="${ANDROID_BUILD_TOP:-$(cd "$(dirname "$0")/../../.." && pwd)}"
OUT="${PRODUCT_OUT:-$TOP/out/target/product/tokay}"
FASTBOOT="${FASTBOOT:-$TOP/out/host/linux-x86/bin/fastboot}"
command -v "$FASTBOOT" >/dev/null 2>&1 || FASTBOOT="$(command -v fastboot || true)"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$OUT" ]] || die "missing $OUT — build first (m -j\$(nproc))"
[[ -x "$FASTBOOT" || -n "$(command -v fastboot)" ]] || die "fastboot not found"

for img in boot vendor_boot vendor_dlkm vendor_kernel_boot init_boot vbmeta dtbo \
           system system_ext product vendor; do
  [[ -f "$OUT/${img}.img" ]] || die "missing ${img}.img"
done

echo "=== GuardTalk tokay flash ==="
echo "Images: $OUT"
echo ""

if ! "$FASTBOOT" devices | grep -qE 'fastboot|fastbootd'; then
  die "no device in fastboot/fastbootd. On the phone: Power+VolDown → Fastboot, connect USB."
fi

if [[ "$("$FASTBOOT" getvar is-userspace 2>&1 | tail -1 || true)" != "is-userspace: yes" ]]; then
  echo "Rebooting to fastbootd for dynamic partitions..."
  "$FASTBOOT" reboot fastboot
  for _ in $(seq 1 60); do
    sleep 2
    [[ "$("$FASTBOOT" getvar is-userspace 2>&1 | tail -1 || true)" == "is-userspace: yes" ]] && break
  done
fi

[[ "$("$FASTBOOT" getvar is-userspace 2>&1 | tail -1 || true)" == "is-userspace: yes" ]] \
  || die "could not enter fastbootd"

read -r -p "This will WIPE userdata (fastboot -w). Continue? [y/N] " ans
[[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || exit 0

"$FASTBOOT" -w
for part in boot init_boot vendor_boot vendor_dlkm vendor_kernel_boot dtbo vbmeta \
            system system_ext product vendor; do
  echo "Flashing $part"
  "$FASTBOOT" flash "$part" "$OUT/${part}.img"
done

echo "Rebooting..."
"$FASTBOOT" reboot
