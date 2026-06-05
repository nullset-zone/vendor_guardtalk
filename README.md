# GuardTalkOS vendor layer

Product deltas for the GrapheneOS fork under [nullset-zone](https://github.com/nullset-zone).

## Modem excision (`GUARDTALK_RADIO_EXCISED`)

- **Profile:** `tokay-cur-user` with cellular stack removed (CPIF, modem firmware, RIL).
- **Product base:** `device/tokay/product-common-excised.mk` skips `telephony_*.mk` inherits.
- **Late filter:** `radio-excised/product-config-late.mk` hooked from `build/make/core/product_config.mk` (after inherit merge).
- **Do not edit** `vendor/google_devices/tokay/tokay.mk` or `BoardConfig.mk` directly — re-apply hooks after `adevtool generate-all -d tokay` (see `device/tokay/REGEN_HOOKS.md`).
- After filter changes: `rm -f out/soong/soong.$(TARGET_PRODUCT).variables out/soong/soong.$(TARGET_PRODUCT).extra.variables`

## Face persona filter (`DEC-GT-004`)

- **Pipeline:** `libguardtalkface_jni.so` + Camera2 Beauty extension override
- **Control:** `GuardTalkFace` priv-app + `persist.vendor.guardtalk.face.*`
- **Docs:** `docs/FACE_FILTER.md`

```bash
vendor/guardtalk/scripts/verify-face-filter.sh
```

## Mic voice filter (`DEC-GT-003`)

- **Effect:** `libguardtalkvoicesw.so` (AIDL preprocessing, C++ DSP)
- **Control:** `GuardTalkVoice` priv-app + `persist.vendor.guardtalk.voice.*` properties
- **Docs:** `docs/VOICE_FILTER.md`

```bash
vendor/guardtalk/scripts/verify-voice-filter.sh
```

## QA and flash

```bash
source build/envsetup.sh && lunch tokay-cur-user
vendor/guardtalk/scripts/verify-radio-excision.sh
vendor/guardtalk/scripts/verify-voice-filter.sh
vendor/guardtalk/scripts/verify-face-filter.sh
```

See `docs/FLASH.md` for rebuild, flash, and on-device checks.

## Layout

```text
device/tokay/          Product and BoardConfig hooks
audio/                 Mic DSP + AIDL effect + effects config
camera/                Face persona pipeline + Camera2 extension
apps/GuardTalkVoice/   Voice filter Settings priv-app
apps/GuardTalkFace/    Face persona Settings priv-app
radio-excised/         Late product pass (packages, copy-files, product-config-late)
overlays/              Framework RRO (telephony features)
scripts/               Host-side acceptance checks
docs/                  Flash and validation notes
```

## Upstream

Merge GrapheneOS: `scripts/github/UPSTREAM_MERGE.md`
