# GuardTalkOS — Add-a-Device Recipe (Device-Agnostic)

> T-PORT-SHARED-CORE (2026-07-04). Generalized from
> `vendor/guardtalk/device/tokay/REGEN_HOOKS.md` so a new device is a small,
> repeatable recipe. Substitute `<codename>` everywhere (e.g. `caiman`,
> `akita`, `rango`). The tokay layer is the reference implementation — copy
> it, rename, and adjust the per-device values.

This recipe wires the shared, device-agnostic GuardTalk core
(`vendor/guardtalk/feature-excised/`, `radio-excised/`, `overlays/`,
`vendor/guardtalk/radio-excised/product-config-late.mk`) into a new Pixel
codename. The shared core is gated on `GUARDTALK_RADIO_EXCISED` (set by
`guardtalk-radio-excised.mk`), so it fires ONLY for products whose
`<codename>.mk` includes that file — no per-device registration list to
maintain.

## 0. Prerequisites

- A working AOSP+GrapheneOS source tree (this worktree).
- `adevtool` built and on PATH: `m adevtool` (or use the prebuilt).
- The factory image for `<codename>` (zip + the matching `.list`/OTA blob
  set) staged somewhere adevtool can read.

## 1. adevtool factory-image download

```bash
# From the source tree root. Replace <factory_zip> with the stock Pixel
# factory image zip for <codename> (e.g. pixel_9_pro_xxx-xxxxx.zip).
adevtool download -s <device-spi-id> -f <factory_zip>
# Or, if the image is already on disk, skip the network fetch and point
# adevtool at the local archive in the next step.
```

The exact adevtool subcommand for fetching a factory image varies by
adevtool version; `adevtool --help` lists the current `download` /
`fetch` verbs. The output lands under `vendor/adevtool/dl/`.

## 2. adevtool generate-all -d <codename>

```bash
adevtool generate-all -d <codename>
```

This regenerates `vendor/google_devices/<codename>/` (including
`<codename>.mk`, `BoardConfig.mk`, `device.mk`, the proprietary blobs
list, VINTF manifests, etc.) from the upstream factory image. **After
this step the generated files are stock GrapheneOS — the GuardTalk hooks
below must be re-applied by hand because adevtool does not know about
them.**

## 3. BoardConfig-late hook

Add to the **end** of `vendor/google_devices/<codename>/BoardConfig.mk`
(after `AB_OTA_PARTITIONS` is set by the upstream `BoardConfig-common.mk`
include):

```makefile
ifneq ($(GUARDTALK_RADIO_EXCISED),)
include vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk
endif
```

Create `vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk`
(copy from `vendor/guardtalk/device/tokay/BoardConfig-excised-late.mk`
and adjust):

```makefile
# Late board pass — include at end of
# vendor/google_devices/<codename>/BoardConfig.mk (runs AFTER
# vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk:45
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).
AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-BT-FULL (FR-3): override the upstream vendor_dlkm.modules.blocklist with
# the GuardTalk version that adds `blocklist nitrous` (BCM4390 BT power/rfkill
# driver). Verify the upstream blocklist path for <codename> — SoC families
# differ (see SoC note below). Prefer a per-device blocklist under
# vendor/guardtalk/device/<codename>/ when the shared feature-excised file
# is not an exact upstream mirror (akita/zuma, rango/laguna).
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/device/<codename>/vendor_dlkm.modules.blocklist
```

> **SoC note (zuma / zumapro / laguna):**
> - **tokay / caiman** = `zumapro` (caimito-kernels 6.1). Shared
>   `vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist` is the
>   caimito baseline + nitrous.
> - **akita** = `zuma` (akita-kernels 6.1). Uses
>   `vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist`.
> - **rango** = `laguna` (laguna-kernels 6.6). Uses
>   `vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist`
>   (upstream grapheneos/rango baseline + `nitrous.ko`). **Do not** label
>   rango as zumapro — that REGEN_HOOKS debt caused wrong blocklist advice.
>
> Before building a new SoC, diff the upstream
> `device/google/<family>-kernels/.../vendor_dlkm.modules.blocklist` and
> reconcile so no upstream-blocklisted module is accidentally re-enabled.
> Document the delta in
> `vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk`.

## 4. device.mk / <codename>.mk hooks

Add to the **end** of `vendor/google_devices/<codename>/<codename>.mk`
(use `include`, not `inherit-product`):

```makefile
# Late pass: remove RIL/modem packages and copy-files (must include, not
# inherit-product). This include also pulls
# vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk so per-device
# GuardTalk flags (GUARDTALK_PRODUCT_MODEL, GUARDTALK_VOICE_FILTER, etc.) are
# visible to the shared late pass.
ifneq ($(GUARDTALK_RADIO_EXCISED),)
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
endif
```

(`GUARDTALK_RADIO_EXCISED` is set inside `guardtalk-radio-excised.mk`, so
the guard is belt-and-braces — it lets you disable the late pass by
unsetting the flag in `guardtalk-flags.mk` without editing the generated
file again.)

> The original tokay recipe wired `BoardConfig-excised.mk` from the **head**
> of `BoardConfig.mk` and `product-common-excised.mk` from `device.mk`. Those
> are optional tokay-era patterns; the minimal recipe above (BoardConfig-late
> + `<codename>.mk` tail include) is sufficient for a new device. Add the
> head-of-BoardConfig and device.mk hooks only if the new device needs the
> early BoardConfig override or the zumapro `product-common.mk` swap.

## 5. GuardTalk device layer files to create

Create `vendor/guardtalk/device/<codename>/` with:

- **`guardtalk-flags.mk`** — per-device GuardTalk flags. Minimum contents:

  ```makefile
  # Per-device GuardTalk flags. Loaded by
  # vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk via
  # -include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk
  # (see product-config-late.mk for the consumers).
  GUARDTALK_RADIO_EXCISED := true
  GUARDTALK_FEATURE_EXCISED_WAVE2 := true
  GUARDTALK_VOICE_FILTER := true
  GUARDTALK_FACE_FILTER :=
  # T-BRAND-PROPS (minimal rebrand). Only Build.MODEL is overridden;
  # *_FOR_ATTESTATION variants stay upstream so Play Integrity / keymint
  # attestation still matches the signed vendor image.
  GUARDTALK_PRODUCT_MODEL := GuardTalk <UpstreamModel>
  ```

  Substitute `<UpstreamModel>` with the value `<codename>.mk` sets for
  `PRODUCT_MODEL` (e.g. `Pixel 9 Pro` for caiman, `Pixel 8a` for akita,
  `Pixel 10 Pro Fold` for rango / laguna). The rebrand step in
  `product-config-late.mk` is skipped when `GUARDTALK_PRODUCT_MODEL` is
  unset, so a new device still builds before its brand string is chosen
  (Law 9).

- **`BoardConfig-excised-late.mk`** — see step 3.

- **`guardtalk-audio.mk`** (optional) — copy from tokay if the device
  ships the GuardTalk voice-filter DSP stack. Gated on
  `GUARDTALK_VOICE_FILTER`.

- **`guardtalk-camera.mk`** (optional) — copy from tokay if the device
  ships the GuardTalk face-persona camera extension. Gated on
  `GUARDTALK_FACE_FILTER`.

- **`guardtalk-theme.mk`** (optional) — copy from tokay. Self-gated on
  the existence of brand assets in `vendor/guardtalk/branding/`. Safe to
  copy verbatim; it no-ops until the operator delivers the brand kit.

- **`product-common-excised.mk`** (optional) — copy from tokay only if
  the device needs the zumapro `product-common.mk` swap (i.e. it would
  otherwise inherit the upstream telephony product fragments). zuma
  (akita) may or may not need this — verify by inspecting
  `vendor/adevtool/config/mk/google_devices/device/<codename>/device.mk`
  after `adevtool generate-all`.

> The shared core already parameterizes the late pass on
> `GUARDTALK_RADIO_EXCISED`, so the moment the new device's
> `<codename>.mk` includes `guardtalk-radio-excised.mk`, the entire
> shared excision stack (radio + Wave 2 apps/nfc/fp/bt/loc + overlays +
> GT Info / GT Config apps + brand rebrand) fires for that product. No
> shared-core edit is needed per device.

## 6. Stale-soong-var cleanup

After changing filters (or after the first build of a new device), delete
stale Soong variables or the vendor will keep modem blobs:

```bash
rm -f out/soong/soong.$(TARGET_PRODUCT).variables \
      out/soong/soong.$(TARGET_PRODUCT).extra.variables
# For <codename>:
rm -f out/soong/soong.<codename>.variables \
      out/soong/soong.<codename>.extra.variables
```

`build/make/core/product_config.mk` includes
`vendor/guardtalk/radio-excised/product-config-late.mk`, which is the
single late hook (re-apply if AOSP updates overwrite that line).

## 7. Build command

```bash
source build/envsetup.sh
lunch <codename>-trunk_staging-userdebug
m dist -j32
```

## 8. Acceptance smoke-test for the new device

- `get_build_var GUARDTALK_RADIO_EXCISED` prints `true`.
- `get_build_var PRODUCT_MODEL` prints `GuardTalk <UpstreamModel>`.
- `out/target/product/<codename>/installed-files*.txt` contains no
  `modem`, `rild`, `Iwlan`, `CarrierConfig2`, `ShannonIms`,
  `Telecom__<codename>__auto_generated_rro_product` entries.
- The built `vendor_manifest_no_radio.xml` is in the VINTF manifest set.

## Reverse / Rollback

Every step is reversible (Law 11):

- Remove the `include` line from `<codename>.mk` and `BoardConfig.mk` →
  shared core stops firing for that product (the `GUARDTALK_RADIO_EXCISED`
  gate stays false).
- `rm -rf vendor/guardtalk/device/<codename>/` removes the device layer.
- `adevtool generate-all -d <codename>` regenerates the stock
  `vendor/google_devices/<codename>/` files; the GuardTalk hooks above
  are the only manual re-application needed.

No shared-core file is device-specific (each device is a self-contained
`vendor/guardtalk/device/<codename>/` directory + two `include` lines in
generated files), so adding a device never edits the shared core.
