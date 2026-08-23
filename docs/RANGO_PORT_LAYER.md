# Rango (Pixel 10 Pro Fold) Port — GuardTalk Device Layer

> **Task:** `T-PORT-RANGO-LAYER`  
> **Date:** 2026-07-25  
> **Depends on:** `T-PORT-RANGO-PREFLIGHT` ✅ APPROVED GO  
> **Binding delta:** `vendor/guardtalk/docs/RANGO_PORT_PREFLIGHT.md`

## Results

| Item | Result |
|------|--------|
| Device layer | `vendor/guardtalk/device/rango/` |
| REGEN_HOOKS | Applied to `vendor/google_devices/rango/{rango.mk,BoardConfig.mk}` |
| Shared recipe SoC note | Fixed: rango = **laguna** (was wrongly labeled zumapro) |
| `lunch rango-trunk_staging-userdebug` | **OK** (EXIT=0) |
| Platform | `laguna` |
| Fingerprint HAL | Goodix (shared `fp-excised.mk`) |
| Blocklist | `vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist` (laguna upstream + nitrous.ko) |
| Full `m` image | Not run (FLASH task) |
| F-PORT-RANGO-FOLD | **N/A** — no invented Frontend fold overlays |

## Kernel resolution method

Historical `RELEASE_KERNEL_RANGO_DIR` (trunk_staging) required
`device/google/laguna-kernels/6.6/trunk-14072179/rango`.

**Method (dual, akita-style durable):**

1. **Aconfig (durable):** `build/release/flag_values/trunk_staging/RELEASE_KERNEL_RANGO_DIR.textproto`
   → `device/google/laguna-kernels/6.6/grapheneos/rango`  
   Same class of fix as akita → `…/akita-kernels/6.1/grapheneos` (real dir, not symlink).
2. **Symlink (compatibility):** `device/google/laguna-kernels/6.6/trunk-14072179` → `grapheneos/`  
   so `…/trunk-14072179/rango` still resolves for any leftover tooling.

**Why not AOSP trunk blobs:** GrapheneOS laguna-kernels ship only `grapheneos/`. No invented binaries.

**Insmod insurance:** `vendor/guardtalk/device/rango/guardtalk-insmod.mk` copies
`init.insmod.rango.cfg` from the real grapheneos/rango path (GNU find does not
traverse symlink start paths — akita boot-logo hang precedent).

See `device/google/laguna-kernels/6.6/README.guardtalk-trunk-14072179.md`.

## Layer files

| File | Role |
|------|------|
| `guardtalk-flags.mk` | Radio/wave2/voice; `GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 10 Pro Fold`; face empty |
| `BoardConfig-excised-late.mk` | Modem OTA filter, radio cmdline, rango blocklist override |
| `vendor_dlkm.modules.blocklist` | Upstream laguna/rango baseline + `blocklist nitrous.ko` |
| `guardtalk-insmod.mk` | Explicit `init.insmod.rango.cfg` install |
| `guardtalk-theme.mk` | Thin wrapper → shared branding mk |
| `guardtalk-audio.mk` / `guardtalk-camera.mk` | Voice/face filters (face gated off) |
| `product-common-excised.mk` | Tokay/akita recipe parity (optional) |
| `REGEN_HOOKS.md` | Re-apply after adevtool generate-all |

## Excision filters used (shared core — no silent no-op)

Engaged when `rango.mk` includes `guardtalk-radio-excised.mk` and flags set
`GUARDTALK_RADIO_EXCISED` + `GUARDTALK_FEATURE_EXCISED_WAVE2`:

| Filter | Path | Rango relevance |
|--------|------|-----------------|
| Radio / modem | `vendor/guardtalk/radio-excised/*` | Packages + copy-files + VINTF |
| Apps / overlays | `feature-excised/apps-excised.mk`, overlays | Shared UI hides |
| **Goodix FP** | `feature-excised/fp-excised.mk` | Tokens already include rango Goodix family |
| NFC | `feature-excised/nfc-excised.mk` | ST stack |
| BT userspace | `feature-excised/bt-excised.mk` | + nitrous.ko in device blocklist |
| Location | `feature-excised/loc-excised.mk` | GNSS / gnssd |
| Theme | `device/rango/guardtalk-theme.mk` via feature bridge | Bootanimation / wallpaper |

**Not used:** tokay `feature-excised/vendor_dlkm.modules.blocklist` (caimito-oriented).

## Foldable preserve list (evidence — not stripped)

| Asset | Evidence |
|-------|----------|
| Hinge angle | `rango.mk` → `android.hardware.sensor.hinge_angle.prebuilt.xml` |
| Device state / fold states | `proprietary/.../devicestate/device_state_configuration.xml`; product RRO `config_foldedDeviceStates` |
| Unfold transitions | vendor RRO `config_unfoldTransitionEnabled` / `config_unfoldTransitionHingeAngle` = true |
| Dual display | `display_port_0.xml` + `display_port_1.xml`; rgea/rgeb panel colordata / panel_config |
| Hall / foldable touch | `hall_sensor.ko` in modules.load; `syna_touch` in `init.insmod.rango.cfg` (blocklisted then re-modprobe) |
| Twoshay | `twoshay` package + `twoshay.rc` + `twoshay_config.json` |
| Concurrent foldable camera | `sysconfig/.../com.google.pixel.camera.concurrent_foldable_dual_front.xml` |
| Unfold SystemUI resources | adevtool `overlay_inclusions` / generated `rango_unfolded_*` (vendor overlays) |

Excision stays radio/BT/NFC/fp/loc — fold policy paths above are untouched.

## Lunch verification (captured 2026-07-25)

```text
LUNCH_EXIT=0
TARGET_PRODUCT=rango
TARGET_BOARD_PLATFORM=laguna
GUARDTALK_RADIO_EXCISED=true
GUARDTALK_FEATURE_EXCISED_WAVE2=true
PRODUCT_MODEL=GuardTalk Pixel 10 Pro Fold
GUARDTALK_PRODUCT_MODEL=GuardTalk Pixel 10 Pro Fold
RELEASE_KERNEL_RANGO_DIR=device/google/laguna-kernels/6.6/grapheneos/rango
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE=vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist
```

## Tokay / akita

GuardTalk tokay and akita layers and their `vendor/google_devices/{tokay,akita}/`
trees intentionally untouched (only rango hooks + shared REGEN_HOOKS.md SoC note).
