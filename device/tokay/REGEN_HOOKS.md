# Re-apply after `adevtool generate-all -d tokay`

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
