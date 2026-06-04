# Flash GuardTalkOS (tokay, radio-excised)

Build target: `tokay-cur-user` (Pixel 9).

## Build

```bash
cd "$ANDROID_BUILD_TOP"
source build/envsetup.sh
lunch tokay-cur-user
m -j"$(nproc)"
```

After changing `radio-excised/*.mk` package filters:

```bash
rm -f out/soong/soong.tokay.variables out/soong/soong.tokay.extra.variables
m vendorimage systemextimage bootimage -j"$(nproc)"
```

## Verify (host, before flash)

```bash
source build/envsetup.sh && lunch tokay-cur-user
vendor/guardtalk/scripts/verify-radio-excision.sh
```

## Flash

Use the same fastboot / GrapheneOS installer flow as upstream tokay, with images from `out/target/product/tokay/`.

Typical developer path (unlocked bootloader, USB debugging):

```bash
# Example — adjust to your installer script / bundle layout
fastboot flash boot out/target/product/tokay/boot.img
fastboot flash vendor out/target/product/tokay/vendor.img
fastboot flash system out/target/product/tokay/system.img
fastboot flash system_ext out/target/product/tokay/system_ext.img
fastboot flash product out/target/product/tokay/product.img
fastboot reboot
```

Prefer the project’s official GrapheneOS factory image / CLI installer when available; partition names and slots must match your device state.

## On-device checks

- Boot completes without CPIF / modem driver crashes (`logcat -b all | grep -iE 'cpif|modem|rild'` should be quiet).
- WiFi associates (`bcmdhd` firmware present on vendor).
- No mobile network / SIM UI (Settings overlay).
- `getprop ro.guardtalk.radio.excised` → `1`

## Regenerate device trees

After `adevtool generate-all -d tokay`, re-apply hooks in `device/tokay/REGEN_HOOKS.md`.
