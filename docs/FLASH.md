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

## Desktop-flash CLI — Pixel 9 Pro XL (`DEVICE=komodo`)

Desktop CLI (`DEVICE=komodo`). The web installer **does** advertise `komodo`
(DEC-PORT-KOMODO-004: tokay + akita + komodo; `F-PORT-KOMODO-WEBINSTALL` APPROVED).
Do not run `flash-from-remote.sh` against a phone until the operator says flash.

| Item | Value |
|------|--------|
| Lunch | `komodo-trunk_staging-userdebug` |
| Stamp | `releases/desktop-flash/komodo-<UTCSTAMP>/` |
| Symlink | `releases/desktop-flash/komodo-latest` |
| Script | `scripts/flash-from-remote.sh` (KEEP identical to `vendor/guardtalk/scripts/flash-from-remote.sh`) |
| Firmware cleanup | Pixel 9 family: uart + **erase fips** + dpm (same as tokay/akita; not rango) |
| Extra | `init.insmod.komodo.cfg` |

```bash
export REMOTE_HOST=oss-c1@192.168.2.220
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/komodo-latest
export REMOTE_KEY_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/komodo-latest
# Or: DEVICE=komodo
bash /path/to/scripts/flash-from-remote.sh
```

Leave tokay `releases/desktop-flash/latest` and `akita-latest` untouched.
See `vendor/guardtalk/docs/KOMODO_PORT_FLASH.md`.
