#!/usr/bin/env bash
# Build and boot GuardTalkOS on the Goldfish emulator (emu64x x86_64 or emu64a arm64).
set -eo pipefail

TOP="${ANDROID_BUILD_TOP:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# x86_64 host without KVM cannot run arm64 QEMU; prefer emu64x unless overridden.
if [[ -z "${GUARDTALK_EMU_LUNCH:-}" ]] && [[ "$(uname -m)" == "x86_64" ]] \
    && { [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; }; then
  LUNCH="guardtalk_emu64x-trunk_staging-userdebug"
else
  LUNCH="${GUARDTALK_EMU_LUNCH:-guardtalk_emu64a-trunk_staging-userdebug}"
fi
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
WIPE="${WIPE:-0}"
HEADLESS="${HEADLESS:-0}"
ALLOW_NO_KVM="${ALLOW_NO_KVM:-0}"
EMU_LOG="${EMU_LOG:-/tmp/guardtalk-emulator.log}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$TOP/build/envsetup.sh" ]] || die "missing $TOP/build/envsetup.sh — run from GrapheneOS tree"

set +u
# shellcheck source=/dev/null
source "$TOP/build/envsetup.sh"
set -e
lunch "$LUNCH" || die "lunch failed for $LUNCH"

if [[ -n "${PRODUCT_OUT:-}" ]]; then
  OUT="$PRODUCT_OUT"
elif [[ -n "${TARGET_DEVICE:-}" ]]; then
  OUT="$TOP/out/target/product/$TARGET_DEVICE"
else
  case "${TARGET_PRODUCT:-}" in
    guardtalk_emu64x|sdk_phone64_x86_64) OUT="$TOP/out/target/product/emu64x" ;;
    guardtalk_emu64a|sdk_phone64_arm64)     OUT="$TOP/out/target/product/emu64a" ;;
    *) die "cannot derive PRODUCT_OUT from TARGET_PRODUCT=${TARGET_PRODUCT:-}" ;;
  esac
fi

export ANDROID_BUILD_TOP="$TOP"
export ANDROID_PRODUCT_OUT="$OUT"
export ANDROID_EMULATOR_PREBUILTS="$TOP/prebuilts/android-emulator/linux-x86_64"
export PATH="$ANDROID_EMULATOR_PREBUILTS:$PATH"

EMULATOR_DIR="$ANDROID_EMULATOR_PREBUILTS"

if [[ "${1:-}" == "--build-only" ]]; then
  echo "=== Building $LUNCH (jobs=$BUILD_JOBS) ==="
  m -j"$BUILD_JOBS"
  echo "Build done. Images: $OUT"
  exit 0
fi

if [[ "${1:-}" == "--check-kvm" ]]; then
  exec "$SCRIPT_DIR/check-kvm.sh"
fi

[[ -f "$OUT/system.img" ]] || {
  echo "=== No emulator images in $OUT — building $LUNCH ==="
  m -j"$BUILD_JOBS"
}
[[ -f "$OUT/system.img" ]] || die "missing $OUT/system.img after build"
command -v emulator >/dev/null || die "emulator not in PATH ($EMULATOR_DIR)"

has_kvm=0
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  has_kvm=1
fi

if [[ "$has_kvm" -eq 0 && "$ALLOW_NO_KVM" != "1" ]]; then
  echo ""
  echo "=== KVM required for reliable headless emulator boot ==="
  "$SCRIPT_DIR/check-kvm.sh" || true
  echo ""
  echo "KVM is installed on this host (kvm_intel module loaded) but your user"
  echo "is not in group 'kvm'. Fix once, then re-run this script:"
  echo "  sudo gpasswd -a \$USER kvm"
  echo "  # new SSH session, then:"
  echo "  vendor/guardtalk/scripts/check-kvm.sh"
  echo "  HEADLESS=1 vendor/guardtalk/scripts/run-emulator.sh"
  echo ""
  echo "To attempt a very slow uncached boot without KVM (not recommended):"
  echo "  ALLOW_NO_KVM=1 HEADLESS=1 vendor/guardtalk/scripts/run-emulator.sh"
  exit 1
fi

EMU_ARGS=(-writable-system -no-snapshot -no-metrics -no-boot-anim)
if [[ "$WIPE" == "1" ]]; then
  EMU_ARGS+=(-wipe-data)
fi
if [[ "$HEADLESS" == "1" ]]; then
  # Do NOT use -show-kernel in headless mode — it floods the terminal and looks broken.
  EMU_ARGS+=(-no-window -no-audio -gpu swiftshader_indirect)
  export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}"
  unset DISPLAY
else
  EMU_ARGS+=(-gpu swiftshader_indirect)
fi

if [[ "$has_kvm" -eq 1 ]]; then
  echo "KVM acceleration enabled"
else
  echo "WARN: no KVM — single-core software emulation (very slow)"
  EMU_ARGS+=(-no-accel)
  if ! grep -q '^hw\.cpu\.ncore = 1' "$OUT/config.ini" 2>/dev/null; then
    echo "hw.cpu.ncore = 1" >>"$OUT/config.ini"
  fi
fi

: >"$EMU_LOG"
echo "=== Starting GuardTalk emulator ($LUNCH) ==="
echo "ANDROID_PRODUCT_OUT=$OUT"
echo "Emulator log: $EMU_LOG"

emulator "${EMU_ARGS[@]}" >>"$EMU_LOG" 2>&1 &
EMU_PID=$!

ADB="${ANDROID_HOST_OUT:-$TOP/out/host/linux-x86}/bin/adb"
[[ -x "$ADB" ]] || ADB="$(command -v adb || true)"
[[ -n "$ADB" ]] || die "adb not found"

echo "Waiting for adb device..."
"$ADB" wait-for-device

boot_wait_secs=300
if [[ "$has_kvm" -eq 0 ]]; then
  boot_wait_secs=3600
fi
echo "Waiting for boot (up to ${boot_wait_secs}s)..."

booted=""
for i in $(seq 1 $((boot_wait_secs / 10))); do
  booted="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$booted" == "1" ]]; then
    break
  fi
  if (( i % 3 == 0 )); then
    zygote="$("$ADB" shell getprop init.svc.zygote 2>/dev/null | tr -d '\r' || true)"
    srv="$("$ADB" shell getprop init.svc.system_server 2>/dev/null | tr -d '\r' || true)"
    echo "  ... still booting (${i}0s) zygote=${zygote:-?} system_server=${srv:-?}"
  fi
  sleep 10
done

if [[ "$booted" != "1" ]]; then
  echo "ERROR: sys.boot_completed != 1 after ${boot_wait_secs}s"
  echo "Last 30 lines of emulator log ($EMU_LOG):"
  tail -30 "$EMU_LOG" 2>/dev/null || true
  echo "Stop with: kill $EMU_PID  or  adb emu kill"
  exit 1
fi

echo ""
echo "=== GuardTalk emulator boot OK ==="
"$ADB" shell getprop ro.product.brand 2>/dev/null | tr -d '\r' || true
"$ADB" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true
"$ADB" shell getprop | grep -E 'guardtalk' || true
echo ""
echo "Live checks:"
echo "  adb shell pm list packages | grep guardtalk"
echo "  OUT_DIR=$OUT vendor/guardtalk/scripts/verify-voice-filter.sh"
echo ""
echo "Stop emulator: adb emu kill  (pid $EMU_PID)"
