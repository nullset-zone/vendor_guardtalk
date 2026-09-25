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

`BoardConfig-excised-late.mk` also sets user-only `BOARD_AVB_KEY_PATH` /
`BOARD_AVB_ALGORITHM` (T-REMEDIATE-B1-AVB). Re-apply the include after
adevtool regen; do not drop the AVB pointer. Keys stay out of git.

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
- **T-REMEDIATE-B2-EXCISE:** `proprietary/vendor/etc/init/pktrouter.rc` and
  `bipchmgr.rc` are emptied (no services). Late filter in
  `vendor/guardtalk/feature-excised/loc-excised.mk` also drops those copy-files
  plus `wfc-pkt-router` / `bipchmgr`. Re-empty after adevtool regen.
- **Kernels (trunk_staging):** `RELEASE_KERNEL_KOMODO_DIR` →
  `device/google/caimito-kernels/6.1/trunk-14096387`. On this tree that path
  is a symlink to `grapheneos/` (see
  `device/google/caimito-kernels/6.1/README.guardtalk-trunk-14096387.md`).
  Do not invent AOSP trunk blobs. `build/release` is not edited on this card.
- After filter changes: `rm -f out/soong/soong.komodo.variables out/soong/soong.komodo.extra.variables`

## Out-of-tree kernel YAMA (T-REMEDIATE-B2-YAMA)

`device/google/caimito-kernels/6.1/` ships GrapheneOS **prebuilts**. Komodo
Soong packages `grapheneos/Image.lz4`. There is **no** kernel source in this
AOSP tree, so a Makefile / Android.mk / Android.bp here is an unused orphan.
Do **not** add those files under `caimito-kernels/6.1/` (`Q-REMEDIATE-B2-KERNEL`
`verify_remediate_b2_kernel_static.sh` FAILs if any exist). Direct Make
`include` of a kconfig fragment does **not** rebuild the kernel.

Keep `CONFIG_SECURITY_YAMA=y` in
`device/google/caimito-kernels/6.1/guardtalk-security-yama.config`.

When replacing `Image.lz4` + `System.map` after an **out-of-tree** GrapheneOS
kernel rebuild (`kernel_pixel` / caimito source — **not** `m` in this tree),
pass that fragment to `scripts/kconfig/merge_config.sh` **last** so it wins:

```sh
# From the GrapheneOS kernel source root (out-of-tree of this AOSP tree):
ARCH=arm64 scripts/kconfig/merge_config.sh \
  .config \
  device/google/caimito-kernels/6.1/guardtalk-security-yama.config
```

Use the fragment path relative to this worktree (or an absolute path to the
same file). Then copy the rebuilt `Image.lz4` and `System.map` into
`device/google/caimito-kernels/6.1/grapheneos/` (the `trunk-14096387` symlink
already points there). Live `__lsm_yama` remains ABSENT until that replace.
Do not rewrite `Image.lz4` without a real rebuild. Do not run `m` for this
hook. `adevtool generate-all -d komodo` does not consume this fragment.

## sysprop/vendor.prop (T-REMEDIATE-B2-TELEMETRY)

adevtool restores Pixel defaults. After `generate-all -d komodo`, re-apply:

```
persist.vendor.camera.exif_reveal_make_model=false
persist.vendor.ril.log_mask=0
persist.vendor.sys.modem.logging.enable=false
persist.vendor.sys.silentlog.tcp=Off
```

Do **not** PRODUCT_PROPERTY_OVERRIDES those keys (duplicate sysprop error).
GuardTalk overlay: `vendor/guardtalk/device/komodo/guardtalk-telemetry.mk`
(logpersist.start / logcatd user filter + vendor init re-assert). Do not
re-enable RIL. Do not edit apps-excised.mk or init.guardtalk.hardening.rc.

## Messenger (T-REMEDIATE-B4-MESSENGER)

adevtool does **not** emit the Messenger APK. After regen, keep:

```
include vendor/guardtalk/device/komodo/guardtalk-messenger.mk
```

from `guardtalk-production-hardening.mk`. Soong module `GuardTalkMessenger`
(`com.guardtalk.messenger`) is the bake path. Do **not** restore AppStore /
TrichromeChrome. Gateway jamid SOP: `vendor/guardtalk/docs/GATEWAY_MESSENGER_PROVISION.md`.

## User defaults (T-REMEDIATE-B5-DEFAULTS)

`guardtalk-defaults.mk` + `init.guardtalk.defaults.rc` +
`GuardTalkSettingsProviderOverlay`. After adevtool regen this include stays
via `guardtalk-production-hardening.mk` (do not drop). Props:

```
ro.com.android.dataroaming=false
persist.sys.usb.config=none          # user only; not mtp
persist.sys.bug_report=0             # user only
```

Overlay: `def_lock_screen_show_notifications=0` (Settings.Secure
`lock_screen_show_notifications=0`). Do not rewrite USERBUILD su/SPL/AVB.
Do not re-enable RIL. Do not PRODUCT_PROPERTY_OVERRIDES persist.security.usb_mode.

## Wi-Fi overlay (T-REMEDIATE-B4-WIFI-GW)

adevtool restores Pixel `wpa_supplicant_overlay.conf` (HS20/interworking on,
no `filter_ssids`). After `generate-all -d komodo`, the late mk
`guardtalk-wifi-gateway.mk` must still filter-out the Pixel copy and
install:

- `vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf`
- `vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids` (fail-closed empty)
- `vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc`

Do **not** open Wi-Fi. Do not re-enable RIL/BT/NFC. Do not put PSKs in the
SSID list. Framework overlay restrictions live in
`vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay` (not regenerated
by adevtool).

## Lunch / git (uid oss-c1)

Session-only (do not write git config):

```bash
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
source build/envsetup.sh
# Production (T-REMEDIATE-B1-USERBUILD): user, not userdebug.
lunch komodo-trunk_staging-user
# Engineering-only root sidecar (not this product): komodo-trunk_staging-userdebug
# See vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md
```
