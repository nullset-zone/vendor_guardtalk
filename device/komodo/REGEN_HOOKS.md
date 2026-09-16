# Re-apply after `adevtool generate-all -d komodo`

> Instance of `vendor/guardtalk/device/REGEN_HOOKS.md` for **komodo**
> (zumapro / caimito-kernels 6.1 / QFP). Keep in sync with the shared
> recipe. **komodo is zumapro — same family as tokay. Not zuma (akita)
> and not Goodix.**

## BoardConfig.mk (end of file)

```makefile
# GuardTalkOS komodo: strip modem partition after AB_OTA list is defined
include vendor/guardtalk/device/komodo/BoardConfig-excised-late.mk
```

## komodo.mk (end of file)

```makefile
# Late pass: remove RIL/modem packages and copy-files (must include, not inherit-product)
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk

# GuardTalkOS komodo: install init.insmod.komodo.cfg (symlink TARGET_KERNEL_DIR breaks find-copy)
include vendor/guardtalk/device/komodo/guardtalk-insmod.mk
```

## device.mk

adevtool does **not** emit `vendor/google_devices/komodo/device.mk`.
`komodo.mk` inherits `vendor/adevtool/config/mk/google_devices/device/komodo/device.mk`
(stock zumapro `product-common.mk` + `RELEASE_KERNEL_KOMODO_DIR`). Live tokay
leaves that config file unmodified. Flags load via
`-include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk`
inside `guardtalk-radio-excised.mk`. Theme wires via `PRODUCT_DEVICE` in
`guardtalk-feature-excised.mk`. Optional `product-common-excised.mk` is
kept for recipe parity / a future adevtool swap — not hooked in the live
config (same as tokay).

## Per-device notes

- **SoC:** zumapro (Pixel 9 Pro XL). Same as tokay. Not zuma, not laguna.
- **Fingerprint:** QFP (`qfp-daemon` / `libqfp-service` / `libqfpsuez`). Shared
  `vendor/guardtalk/feature-excised/fp-excised.mk` filters QFP + Goodix;
  komodo only ships QFP. Do not copy akita Goodix-only wiring.
- **Blocklist:** `vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist`
  (caimito grapheneos baseline + `blocklist nitrous`). Do **not** reuse
  `vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist`.
- **Kernels (trunk_staging):** `RELEASE_KERNEL_KOMODO_DIR` →
  `device/google/caimito-kernels/6.1/trunk-14096387`. On this tree that path
  is a symlink to `grapheneos/` (see
  `device/google/caimito-kernels/6.1/README.guardtalk-trunk-14096387.md`).
  Do not invent AOSP trunk blobs. `build/release` is not edited on this card.
- After filter changes: `rm -f out/soong/soong.komodo.variables out/soong/soong.komodo.extra.variables`

## Lunch / git (uid oss-c1)

Session-only (do not write git config):

```bash
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
source build/envsetup.sh
lunch komodo-trunk_staging-userdebug
```
