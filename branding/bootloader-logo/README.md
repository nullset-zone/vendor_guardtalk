# GuardTalk bootloader logo gap + spec (T-BOOT-LOGO-002)

> **STATUS: PLACEHOLDER — gap documented, no auto-wireable hook exists on tokay.**
> No GuardTalk bootloader-logo asset has been delivered, and — unlike the boot
> animation — there is **no** AOSP/adevtool build variable that consumes a
> source-tree asset to replace the pre-bootanimation splash on the Pixel 9
> (`tokay`). This file documents the gap, the format the operator must meet if a
> flashable path is later approved, and the intentionally-no-op placeholder hook
> that records intent without touching the generated
> `vendor/google_devices/tokay/BoardConfig.mk`.

## What the "bootloader logo" is on tokay

On Pixel 9 the splash shown by the bootloader *before* `BootAnimation.cpp`
runs is **embedded inside the signed ABL (Android Bootloader) partition**.
Evidence from the generated device tree:

- `vendor/google_devices/tokay/BoardConfig.mk` declares `AB_OTA_PARTITIONS`
  that includes `abl`, `bl1`, `bl2`, `bl31`, `tzsw`, `pbl`, `ldfw`, `gsa`,
  `gsa_bl1`, `pvmfw` — i.e. the bootloader chain — but **no** `logo` partition
  and **no** `BOARD_BOOTLOADER_LOGO` / `BOARD_LOGO_IMAGE` / `logo.img` build
  variable.
- `grep -rin "logo"` across
  `vendor/adevtool/config/mk/google_devices/device/tokay/`,
  `vendor/adevtool/config/mk/google_devices/platform/zumapro/`,
  `vendor/google_devices/tokay/BoardConfig.mk`, and
  `vendor/google_devices/tokay/tokay.mk` returns **zero** bootloader-logo
  references (only regulatory-text "logo" strings inside localized HTML
  overlays, which are unrelated).
- Public reverse-engineering work (`0xAbby/pixel_loader`, XDA "Pixel BootLogo
  + Bootloader" threads) confirms modern Pixel boot logos are baked into the
  ABL ELF and there is no supported source-tree override; replacing the splash
  requires extracting, patching, and re-signing the ABL partition, which is
  device-bricking territory and out of scope for GuardTalk.

**Conclusion (Law 19 — document gaps honestly):** GuardTalk **cannot** wire a
bootloader-logo asset through `BoardConfig-excised*.mk` the way the boot
animation is wired through `guardtalk-theme.mk`. Any `BOARD_*` variable we
invented here would be silently ignored by the AOSP build, giving a false
"green" signal. The honest wiring is therefore a **gated no-op with a
build-time warning** that surfaces the gap whenever an operator drops an asset
into this directory, so the gap is visible at build time instead of hidden.

## Spec the operator must meet (if a flash path is later approved)

If the operator later obtains sign-off to flash a custom ABL on tokay, the
embedded splash is a **BMP** baked into the ABL FV image. The expected asset
shape for a GuardTalk bootloader logo is:

- **Container:** single `logo.img` blob (raw, no filesystem) containing the
  BMP payload expected by the tokay ABL splash routine. The exact internal
  header is not publicly documented for the Tensor G4 ABL; the operator must
  extract the stock splash from a factory `abl.img` (via ImjTool /
  `newandroidbook.com/tools/imjtool.html`) and produce a byte-compatible
  replacement.
- **Image dimensions:** **1080×2400** (matches tokay panel native resolution;
  same as the bootanimation frames).
- **Color depth:** 32-bit BGRA (Android `BootAnimation` / framebuffer splash
  convention on Pixel).
- **File format on disk:** `logo.img` (raw blob, *not* a BMP file — the BMP
  header is wrapped by the ABL splash container).
- **Content:** GuardTalk logo + wordmark only. Must NOT contain any Google /
  Pixel / GrapheneOS branding (Law 13 — ethical boundaries; trademark
  hygiene).
- **Deliverable name:** `vendor/guardtalk/branding/bootloader-logo/logo.img`.

Until `logo.img` lands here, the placeholder no-op hook in
`vendor/guardtalk/device/tokay/BoardConfig-excised.mk` stays inert and the
build uses the stock Pixel bootloader splash. **No GrapheneOS or Google splash
is introduced or modified by GuardTalk** — the bootloader splash is whatever
shipped on the device's stock ABL.

## Hook variable + gating

The placeholder hook (added in T-BOOT-LOGO-002 to
`vendor/guardtalk/device/tokay/BoardConfig-excised.mk`) is:

```makefile
# --- Bootloader logo (T-BOOT-LOGO-002) -------------------------------------
# On tokay the bootloader splash is embedded in the signed ABL partition; there
# is no BOARD_* override and no logo.img in AB_OTA_PARTITIONS. This hook is an
# INTENTIONAL NO-OP that prints a build-time warning if an operator drops a
# logo.img into vendor/guardtalk/branding/bootloader-logo/ without yet having
# an approved flash path, so the gap is visible instead of silently swallowed.
guardtalk_bl_logo := vendor/guardtalk/branding/bootloader-logo/logo.img
ifneq ($(wildcard $(guardtalk_bl_logo)),)
$(warning GuardTalk: $(guardtalk_bl_logo) present but tokay ABL splash is not \
  auto-wireable via the build. See vendor/guardtalk/branding/bootloader-logo/README.md \
  for the manual ABL flash path. Asset will NOT be packed into the OTA.)
endif
```

This mirrors the `ifneq ($(wildcard ...),)` gating pattern used by
`guardtalk-theme.mk` for `bootanimation.zip`, with the crucial difference
that, because no real consumer exists, the `then` branch emits a
`$(warning ...)` instead of a `PRODUCT_COPY_FILES` line. When a real
override mechanism is identified (e.g. a future AOSP `BOARD_BOOTLOADER_LOGO`
variable, or an approved custom-ABL flash flow), the `then` branch is the
single place to fill in.

## Relationship to T-BOOT-LOGO-001 (bootanimation)

T-BOOT-LOGO-001 wired the **post-kernel** animation (`BootAnimation.cpp`,
`/system/media/bootanimation.zip`) through
`vendor/guardtalk/device/tokay/guardtalk-theme.mk`. That is a userspace
artifact and is fully overrideable from the source tree.

T-BOOT-LOGO-002 (this increment) covers the **pre-kernel** bootloader splash,
which is *not* overrideable from the source tree on tokay. The two increments
are complementary: together they cover the full boot-visual chain GuardTalk
can reach without modifying signed bootloader binaries.

## Acceptance

This increment is **REVIEW** (not APPROVED) because:

1. No asset is delivered and no real wire is possible — the gap is structural
   to the tokay bootloader, not a GuardTalk oversight.
2. The placeholder README + gated no-op warning hook land so the gap is
   grep-able and build-visible.
3. `REGEN_HOOKS.md` records the new hook so `adevtool generate-all -d tokay`
   preserves it.
4. No generated device file (`vendor/google_devices/tokay/BoardConfig.mk`,
   `tokay.mk`) is hand-edited — only `vendor/guardtalk/` files are touched.

The increment lifts to FINAL when (a) the operator delivers a
byte-compatible `logo.img` extracted/patched from a stock tokay ABL, AND (b)
the Architect signs off on a custom-ABL flash procedure (currently out of
scope per dispatch constraints).
