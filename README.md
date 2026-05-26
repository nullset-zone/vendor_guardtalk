# GuardTalkOS vendor layer

Product deltas for the GrapheneOS fork under [nullset-zone](https://github.com/nullset-zone).

## Modem excision (`GUARDTALK_RADIO_EXCISED`)

- **Profile:** `tokay-cur-user` with cellular stack removed (CPIF, modem firmware, RIL).
- **Product base:** `device/tokay/product-common-excised.mk` skips `telephony_*.mk` inherits.
- **Late filter:** `radio-excised/product-config-late.mk` hooked from `build/make/core/product_config.mk` (after inherit merge).
- **Do not edit** `vendor/google_devices/tokay/tokay.mk` or `BoardConfig.mk` directly — re-apply hooks after `adevtool generate-all -d tokay` (see `device/tokay/REGEN_HOOKS.md`).
- After filter changes: `rm -f out/soong/soong.$(TARGET_PRODUCT).variables out/soong/soong.$(TARGET_PRODUCT).extra.variables`

## Layout

```text
device/tokay/          Product and BoardConfig hooks
radio-excised/         Late product pass (packages, copy-files, product-config-late)
overlays/              Framework RRO (telephony features)
```

## Upstream

Merge GrapheneOS: `scripts/github/UPSTREAM_MERGE.md`
