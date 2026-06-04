#!/usr/bin/env bash
# Q-GT-RADIO-010: Modem excision acceptance checks (tokay build tree)
set -euo pipefail

PRODUCT_OUT="${PRODUCT_OUT:-out/target/product/tokay}"
FAIL=0

check_absent() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label"
  fi
}

check_present() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== GuardTalk radio excision matrix ==="
echo "PRODUCT_OUT=$PRODUCT_OUT"

# 1. CPIF absent from kernel module lists in out/
check_absent "cpif/shm_ipc in out module loads" \
  grep -rqE 'cpif\.ko|shm_ipc\.ko' "$PRODUCT_OUT" --include='*.load' 2>/dev/null

# 2. No rild on vendor
check_absent "rild_exynos on vendor" \
  test -f "$PRODUCT_OUT/vendor/bin/hw/rild_exynos"

# 3. No ntn_modem firmware
check_absent "ntn_modem firmware" \
  test -d "$PRODUCT_OUT/vendor/firmware/ntn_modem"

# 4. WiFi present (bcmdhd firmware on vendor)
check_present "WiFi bcmdhd firmware" \
  test -f "$PRODUCT_OUT/vendor/firmware/fw_bcmdhd.bin"

# 4b. No radio HAL services on vendor (VINTF manifest excised)
check_absent "radio.config HAL service" \
  test -f "$PRODUCT_OUT/vendor/bin/hw/android.hardware.radio.config@1.0-service"
check_absent "radio compat HAL service" \
  test -f "$PRODUCT_OUT/vendor/bin/hw/android.hardware.radio-service.compat"

# 5. guardtalk props
check_present "ro.guardtalk.radio.excised" \
  grep -q 'ro.guardtalk.radio.excised=1' "$PRODUCT_OUT/vendor/build.prop"

# 6. modem not in OTA partitions
check_absent "modem OTA partition" \
  grep -qE '(^|,)modem(,|$)' "$PRODUCT_OUT/vendor/build.prop"

# 7. No google-ril jar on system_ext
check_absent "google-ril.jar" \
  test -f "$PRODUCT_OUT/system_ext/framework/google-ril.jar"

# 8. No orphan RIL / legacy radio HAL libs on vendor (dead code without services)
for lib in \
  libril.so librilutils.so libreference-ril.so \
  android.hardware.radio@1.0.so android.hardware.radio@1.1.so \
  libgooglerilaudio.so libgooglerilmemmonitor.so libgril_oem-google.so; do
  check_absent "vendor/lib64/$lib" \
    test -f "$PRODUCT_OUT/vendor/lib64/$lib"
done

echo "=== Summary: $FAIL failure(s) ==="
exit "$FAIL"
