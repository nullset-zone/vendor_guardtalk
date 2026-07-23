# Re-apply after `adevtool generate-all -d tokay`

> **T-PORT-SHARED-CORE (2026-07-04):** the device-agnostic add-a-device
> recipe now lives at `vendor/guardtalk/device/REGEN_HOOKS.md`. The steps
> below are the tokay-specific instance of that recipe — keep them in sync
> with the template when the shared recipe changes.

Add to **end** of `vendor/google_devices/tokay/BoardConfig.mk`:

```makefile
ifneq ($(GUARDTALK_RADIO_EXCISED),)
include vendor/guardtalk/device/tokay/BoardConfig-excised-late.mk
endif
```

Add to **end** of `vendor/google_devices/tokay/tokay.mk` (use `include`, not `inherit-product`):

```makefile
ifneq ($(GUARDTALK_RADIO_EXCISED),)
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
endif
```

After changing filters, delete stale Soong vars or vendor will keep modem blobs:

```bash
rm -f out/soong/soong.$(TARGET_PRODUCT).variables out/soong/soong.$(TARGET_PRODUCT).extra.variables
```

`device.mk` hook is in adevtool config and survives regen:

- Load `guardtalk-flags.mk` first
- Use `product-common-excised.mk` instead of zumapro `product-common.mk` when `GUARDTALK_RADIO_EXCISED` is set

`build/make/core/product_config.mk` includes `product-config-late.mk` (re-apply if AOSP updates overwrite).

## Wave 2 feature excision (`GUARDTALK_FEATURE_EXCISED_WAVE2`)

`product-config-late.mk` additionally includes
`vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk` when
`GUARDTALK_FEATURE_EXCISED_WAVE2` is set in `guardtalk-flags.mk`. The master
include dispatches to per-subsystem `<sub>-excised.mk` files. Current state:

- `apps-excised.mk` — T-W2-I1-UI-APPS: drops `TrichromeChrome` (Vanadium
  browser), `AppStore` (`app.grapheneos.apps`), and `Dialer`. **Keeps**
  `TrichromeWebView` / `TrichromeWebViewDualArch` (system WebView provider)
  and `TrichromeLibrary` (shared Trichrome lib).
- (future: `bt-excised.mk`, `nfc-excised.mk`, `fp-excised.mk`, `loc-excised.mk`,
  `feature-overlays.mk` — not yet wired.)

The Wave 2 pass runs **after** the radio-excised pass inside the same late
hook, so `PRODUCT_PACKAGES` filters compose correctly. No boot-chain files
(`init.rc`, VINTF, sepolicy, kernel modules) are touched by `apps-excised.mk`.

## Bootloader-logo gap hook (T-BOOT-LOGO-002)

`BoardConfig-excised.mk` (included from the `ifneq ($(GUARDTALK_RADIO_EXCISED),)`
block at the head of `vendor/google_devices/tokay/BoardConfig.mk`) carries a
gated no-op for the pre-bootanimation bootloader splash.

- **What it does:** declares `guardtalk_bl_logo :=
  vendor/guardtalk/branding/bootloader-logo/logo.img` and, when that file is
  present, emits a `$(warning ...)` explaining that tokay's ABL splash is not
  auto-wireable via the build. When the file is absent (current state) the
  hook is inert and emits nothing.
- **Why a no-op, not a real wire:** on the Pixel 9 (`tokay`) the bootloader
  splash is baked into the signed ABL partition. There is no `logo` partition
  in `AB_OTA_PARTITIONS`, no `BOARD_BOOTLOADER_LOGO` / `BOARD_LOGO_IMAGE`
  build variable, and no `PRODUCT_COPY_FILES` consumer — verified by
  `grep -rin "logo"` returning zero matches across
  `vendor/adevtool/config/mk/google_devices/device/tokay/`,
  `vendor/adevtool/config/mk/google_devices/platform/zumapro/`,
  `vendor/google_devices/tokay/BoardConfig.mk`, and
  `vendor/google_devices/tokay/tokay.mk` (only localized regulatory-text
  "logo" strings, which are unrelated). Inventing a `BOARD_*` variable here
  would be silently ignored by the AOSP build and give a false "green"
  signal — Law 19 forbids that. The honest wiring is a no-op + warning.
- **What survives regen:** the entire hook lives inside
  `vendor/guardtalk/device/tokay/BoardConfig-excised.mk`, which is re-included
  by the regenerated `vendor/google_devices/tokay/BoardConfig.mk` tail block
  documented above. `adevtool generate-all -d tokay` therefore preserves the
  no-op without re-touching generated files.
- **Operator deliverable to lift to FINAL:** a byte-compatible `logo.img`
  extracted/patched from a stock tokay ABL splash (see
  `vendor/guardtalk/branding/bootloader-logo/README.md`), plus Architect
  sign-off on a custom-ABL flash procedure. When that lands, the `$(warning)`
  branch is the single place to replace with the real (yet-TBD) consumer.
- **Companion increment:** T-BOOT-LOGO-001 wires the post-kernel
  `BootAnimation` (`/system/media/bootanimation.zip`) through
  `guardtalk-theme.mk` — that is the userspace boot visual and is fully
  source-tree overrideable. T-BOOT-LOGO-002 covers only the pre-kernel
  bootloader splash, which is not.
