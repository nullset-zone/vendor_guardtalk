# GuardTalkOS emulator testing

Tokay (Pixel 9) images **cannot** be flashed or booted on the Android emulator. The emulator uses Goldfish kernel/HALs; tokay uses Google Tensor/zumapro vendor images, AVB keys, and partition layouts that only match physical hardware.

Use the emulator to validate **GuardTalk userspace** (apps, overlays, native libs, `ro.guardtalk.*` props, boot to Android) while debugging device boot loops separately.

## Quick start

```bash
cd /path/to/GrapheneOS-worktree
source build/envsetup.sh
lunch guardtalk_emu64a-trunk_staging-userdebug

# Check KVM first (required on headless Linux)
vendor/guardtalk/scripts/check-kvm.sh

# Build + boot headless (needs KVM — see docs/KVM.md)
HEADLESS=1 vendor/guardtalk/scripts/run-emulator.sh

# Build only
vendor/guardtalk/scripts/run-emulator.sh --build-only
```

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `WIPE=1` | `0` | Pass `-wipe-data` to emulator |
| `HEADLESS=1` | `0` | `-no-window` for CI/SSH |
| `BUILD_JOBS` | `nproc` | Parallel `m -j` jobs |

## What the emulator tests

| Covered | Not covered |
|---------|-------------|
| GuardTalk apps (Voice, Face settings) | Pixel bootloader / `BL1 requested` fastboot loop |
| Overlays (Frameworks, Settings) | Radio-excised vendor manifest / modem stripping |
| `libguardtalkvoicesw`, camera extensions | Tokay `vendor_dlkm` kernel modules |
| Android boot + `adb` | Stock vs GuardTalk AVB on device |

## Device isolation (stock GrapheneOS tokay)

If **stock** GrapheneOS tokay boots but **GuardTalk** tokay does not:

1. Hardware and firmware are fine — the bug is in the GuardTalk build (vendor excision, props, or partition content).
2. Flash stock from [GrapheneOS releases](https://releases.grapheneos.org/tokay-factory-*.zip) with the factory script.
3. Compare `getprop` and partition hashes between stock and GuardTalk builds.

If **both** fail to boot, suspect USB/cable, slot state, or firmware mismatch (`firmware/android-info.txt` bootloader/baseband versions).

## Baseline comparison

Boot stock emulator (no GuardTalk) for A/B:

```bash
lunch sdk_phone64_arm64-trunk_staging-userdebug
m -j$(nproc)
emulator -writable-system
```

Then build `guardtalk_emu64a` and diff:

```bash
adb shell getprop | grep guardtalk
adb shell pm list packages | grep guardtalk
```

## Verify scripts

After emulator boot:

```bash
vendor/guardtalk/scripts/verify-voice-filter.sh
vendor/guardtalk/scripts/verify-face-filter.sh
```

These check installed packages and props; they do not replace on-device HAL tests.
