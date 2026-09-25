# Caiman (Pixel 9 Pro) Port — desktop-flash stamp + build record

> **Task:** `T-PORT-CAIMAN` FLASH phase (LAYER + FLASH), program
> `DEC-PORT-GEN8910-001` / operator directive `DEC-PORT-GEN8910-002`, Wave A.
> **Date:** 2026-09-22
> **Depends on:** `T-PORT-CAIMAN` LAYER (`CAIMAN_PORT_LAYER.md`).
> **Status:** build + stamp complete → **REVIEW**. Not APPROVED.
> **No USB flash. No boot claim. No keys.** `FLASH_READY=false`,
> `LIVE_FLASH_CLAIMED=false`; on-device/boot is **HOLD** (no hardware attached).
> **Web installer:** this stamp does **not** advertise `caiman`
> (`F-PORT-CAIMAN-WEBINSTALL` is a separate card).

## Lunch / build target (confirmed)

Recipe says `caiman-trunk_staging-userdebug`; confirmed against the komodo
precedent rather than guessed:

- `vendor/guardtalk/docs/KOMODO_PORT_FLASH.md` §Lunch builds the approved komodo
  stamp with `lunch komodo-trunk_staging-userdebug`.
- `vendor/guardtalk/scripts/sign-build.sh:188` uses `<dev>-cur-user` for the
  **production signed** channel — which needs operator signing keys
  (`T-PORT-*-KEYS` are `HOLD`) and is out of scope here. The only available
  channel is the **userdebug debug sidecar**, so `trunk_staging-userdebug` is
  correct (and produces the same 22-file bundle shape as `komodo-latest`).
- `lunch caiman-trunk_staging-userdebug` → `LUNCH_EXIT=0`, `TARGET_PRODUCT=caiman`.

Exact command:

```bash
export PATH="$HOME/.local/toolchain/node/bin:$PATH"   # operator-provided node v24.21.0
source build/envsetup.sh
lunch caiman-trunk_staging-userdebug
m dist -j"$(nproc)"
```

## Build record

| Item | Value |
|------|--------|
| Target | `caiman-trunk_staging-userdebug` |
| Command | `lunch caiman-trunk_staging-userdebug && m dist -j96` |
| Stale soong cleanup | `rm -f out/soong/soong.caiman.variables out/soong/soong.caiman.extra.variables` (done pre-build) |
| `LUNCH_EXIT` | **0** |
| `BUILD_EXIT` | **0** — `#### build completed successfully (16:37 (mm:ss)) ####` |
| Build completed | **2026-09-22T08:59:21Z** |
| Log | `/tmp/t-port-caiman-flash-m-20260922T084237Z.log` |
| Fingerprint | `google/caiman/caiman:Baklava/BP4A.260205.002/eng.openst:userdebug/test-keys` |
| Cold build | yes — no prior `out/target/product/caiman/` |
| `adevtool` invoked? | **No** (only `git -C vendor/adevtool rev-parse HEAD` in `adevtool-version-check.mk`). No concurrent-`adevtool` race. |

## Acceptance smoke-test (recipe §8) — recorded verbatim

**1. `get_build_var GUARDTALK_RADIO_EXCISED` → `true`** ✅

**2. `get_build_var PRODUCT_MODEL` → `GuardTalk Pixel 9 Pro`** ✅

```text
GUARDTALK_RADIO_EXCISED                    = true
PRODUCT_MODEL                              = GuardTalk Pixel 9 Pro
GUARDTALK_PRODUCT_MODEL                    = GuardTalk Pixel 9 Pro
TARGET_PRODUCT                             = caiman
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE = vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
```

**3. `installed-files*.txt` radio/telephony residue** — ⚠ **5/6 tokens clean, 1 inert residual**

| Token | `installed-files.txt` | `-vendor` | `-product` | `-system_ext` |
|-------|:--:|:--:|:--:|:--:|
| `modem` | 0 | 0 | 0 | 0 |
| `rild` | 0 | 0 | 0 | 0 |
| `Iwlan` | 0 | 0 | 0 | 0 |
| `CarrierConfig2` | 0 | 0 | 0 | 0 |
| `ShannonIms` | 0 | 0 | 0 | 0 |
| `Telecom__caiman__auto_generated_rro_product` | 0 | 0 | **1** | 0 |

The single residual is
`/product/overlay/Telecom__caiman__auto_generated_rro_product.apk` (8542 B).
**Root cause:** the shared excision lists in
`vendor/guardtalk/radio-excised/remove-packages.mk` and
`vendor/guardtalk/feature-excised/apps-excised.mk` name these generated RROs
**tokay-literally** (`Telecom__tokay__auto_generated_rro_product`, …). The RRO
package name is device-suffixed, so `filter-out` never matches `caiman` (or
`komodo`) names. `Telecom__tokay__…` matches only tokay.
**Not caiman-specific and not a regression:** the approved reference stamp
`komodo-latest` ships the identical set — 7 `__komodo__auto_generated_rro_product`
overlays vs caiman's 7 (`Telecom`, `framework-res`, `SettingsGoogle`,
`SettingsProvider`, `SystemUIGoogle`, `PixelDisplayService`,
`SafetyRegulatoryInfo`), byte-for-byte the same sizes.
**Impact:** inert. The base `Telecom` app (`Telecom.apk`) is **not installed**
(absent from `installed-files.txt`), so the overlay has no target package.
**Root-cause fix belongs to the shared core** (`remove-packages.mk` /
`apps-excised.mk` should key on `$(PRODUCT_DEVICE)`/a wildcard, as
`gt-excision-*` already does for the blocklist) — out of this card's allowed paths.

**4. `vendor_manifest_no_radio.xml` present** ✅

- Source `vendor/guardtalk/vintf/vendor_manifest_no_radio.xml` present (2642 B).
- The built `out/target/product/caiman/vendor/etc/vintf/manifest.xml` references
  it as its input (`vendor_manifest_no_radio.xml`), i.e. caiman gets the excised
  manifest (there are **no** caiman-specific akita/rango variants in
  `vintf-excised.mk`).
- Radio/telephony HAL scan of the built vendor manifest = **0** hits.

## Stamp

| Item | Value |
|------|--------|
| Stamp dir | `releases/desktop-flash/caiman-20260922-090535/` |
| Layout | **22 files** — mirrors `releases/desktop-flash/komodo-latest/` exactly |
| Contents | `boot/init_boot/vendor_boot/vendor_kernel_boot/dtbo/pvmfw/bootloader/radio/vbmeta/vbmeta_system/vbmeta_vendor/system/system_ext/product/vendor/vendor_dlkm/system_dlkm/super_empty.img`, `avb_pkmd.bin`, `init.insmod.caiman.cfg`, `SHA256SUMS`, `README-FLASH-DESKTOP.md` |
| `SHA256SUMS` | 20 entries, `sha256sum -c` → **exit 0** (all `OK`) |
| Pointer | `releases/desktop-flash/caiman-latest` → `caiman-20260922-090535` (**created fresh**; did not exist before) |
| `super.img` | omitted (akita/komodo pattern; `super_empty.img` ships) |
| `vbmeta_system.img` / `vbmeta_vendor.img` | full copies of `vbmeta.img` |
| `avb_pkmd.bin` | public AOSP test AVB blob (`sha256 7728e30f…`), same as komodo/akita/tokay — **no private key** |
| Keys in stamp | `find releases/desktop-flash/caiman-20260922-090535 -name '*.pem' -o -name '*.pk8'` → **0** |

## Zero-regression assertion (inodes + targets, re-read after stamping)

| Symlink | Target | Result |
|---------|--------|--------|
| `latest` | `tokay-20260725-102506` | ✅ unchanged |
| `akita-latest` | `akita-20260725-101434` | ✅ unchanged |
| `komodo-latest` | `komodo-20260915-063833` | ✅ unchanged |
| `rango-latest` | `rango-20260802-130756` | ✅ unchanged |
| `komodo-debug-latest` | `komodo-debug-20260921-041838` | ✅ unchanged |

No other device's `*-latest` was created or moved. `vendor/guardtalk/device/{tokay,akita,komodo,rango}/`
and `vendor/google_devices/{tokay,akita,komodo,rango}/` were not touched.

## Blocker carried from LAYER (read this)

The build only succeeded because of a **device-local pin** that works around a
**pre-existing shared-core regression** introduced by `T-PORT-EXCISION-MATRIX`
(Sep 21, uncommitted). Full analysis in `CAIMAN_PORT_LAYER.md`
§"Shared-core blocker found". Summary:

- `guardtalk-radio-excised.mk` includes `excision-variant-select.mk`; that file is
  re-entered from `product-config-late.mk` where `PRODUCT_DEVICE`/`TARGET_DEVICE`
  are empty → the resolver `$(error)`s "no known device identity".
- **`lunch komodo-trunk_staging-userdebug` fails identically** — so this breaks
  every GuardTalk product, not just caiman, and the `T-PORT-EXCISION-MATRIX`
  static harness never ran `lunch` to catch it.
- caiman unblocks via `GUARDTALK_DEVICE := caiman` in
  `vendor/guardtalk/device/caiman/guardtalk-flags.mk` (allowed path, additive,
  reversible). The real fix (a re-include guard in the resolver) is the
  Architect's call and is out of this card's scope.

## Reusable FLASH recipe (for the 7 remaining devices)

1. `source build/envsetup.sh && lunch <dev>-trunk_staging-userdebug`; assert
   `TARGET_PRODUCT=<dev>`, `TARGET_BOARD_PLATFORM=<soc>`,
   `GUARDTALK_RADIO_EXCISED=true`, `PRODUCT_MODEL=GuardTalk <model>`,
   `BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE` = **the variant's** canonical file.
2. `rm -f out/soong/soong.<dev>.variables out/soong/soong.<dev>.extra.variables`.
3. `m dist -j"$(nproc)"` (matches the komodo precedent shape; `cur-user` needs
   keys and is HOLD). Run detached and poll — a cold build is ~15–40 min.
4. Smoke-test the four checks above; keep the raw numbers (Law 16).
5. `mkdir releases/desktop-flash/<dev>-<UTCstamp>/`, copy the same 16 images +
   `init.insmod.<dev>.cfg` + public `avb_pkmd.bin`; copy `vbmeta.img` to
   `vbmeta_system.img`/`vbmeta_vendor.img`; generate `SHA256SUMS` in the komodo
   order; write `README-FLASH-DESKTOP.md` (honesty block incl. `FLASH_READY=false`);
   `ln -s <dev>-<UTCstamp> <dev>-latest` **only if it does not exist**.
6. `sha256sum -c SHA256SUMS` (expect exit 0) and re-assert every other
   `*-latest` target is unchanged.

The only per-device deltas are the codename, the insmod cfg name, and the
variant the registry already resolves — everything else is byte-identical work.

## Stamp record

| Item | Value |
|------|--------|
| `LUNCH_EXIT` | **0** |
| `BUILD_EXIT` | **0** |
| Build log | `/tmp/t-port-caiman-flash-m-20260922T084237Z.log` |
| Stamp dir | `releases/desktop-flash/caiman-20260922-090535/` |
| Symlink | `releases/desktop-flash/caiman-latest` → `caiman-20260922-090535` (fresh) |
| `SHA256SUMS` | 20 files, `sha256sum -c` exit 0 |
| `super.img` | omitted (akita/komodo pattern) |
| Tokay `latest` | **193110379** unchanged |
| `akita-latest` | **193110357** unchanged |
| `komodo-latest` | **193110380** unchanged |
| `rango-latest` | **193110354** unchanged |
| On-device/boot | **HOLD** (no hardware) |
| `LIVE_FLASH_CLAIMED` | **false** |
