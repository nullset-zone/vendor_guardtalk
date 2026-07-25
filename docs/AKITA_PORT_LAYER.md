# Akita (Pixel 8a) Port — GuardTalk Device Layer

> **Task:** `T-PORT-AKITA-LAYER`  
> **Date:** 2026-07-24  
> **Depends on:** `T-PORT-AKITA-PREFLIGHT` ✅ APPROVED

## Results

| Item | Result |
|------|--------|
| Device layer | `vendor/guardtalk/device/akita/` |
| REGEN_HOOKS | Applied to `vendor/google_devices/akita/{akita.mk,BoardConfig.mk}` |
| `lunch akita-trunk_staging-userdebug` | **OK** (EXIT=0) |
| Platform | `zuma` |
| Blocklist | `vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist` (akita-kernels + nitrous) |
| Full `m` image | Not run (FLASH task) |

## Kernel resolution method

`RELEASE_KERNEL_AKITA_DIR` (trunk_staging) requires
`device/google/akita-kernels/6.1/trunk-14096387`.

**Method:** symlink `trunk-14096387` → `grapheneos/` (existing GrapheneOS
channel prebuilts in this tree).

**Why not AOSP trunk blobs:** GrapheneOS kernel repo only ships `grapheneos/`;
AOSP `main` has older trunks only (`trunk-12398767`, `trunk-12730958`,
`25Q1-…`) — no `trunk-14096387`. No invented binaries.

**Precedent:** tokay `trunk_staging` already redirects
`RELEASE_KERNEL_TOKAY_DIR` → `…/caimito-kernels/6.1/grapheneos`
(`build/release` commit “WORKING VERSION”). Akita uses the filesystem-side
equivalent because `build/release` was outside LAYER allowed paths.

See `device/google/akita-kernels/6.1/README.guardtalk-trunk-14096387.md`.

## Lunch verification (sample)

```text
TARGET_PRODUCT=akita
GUARDTALK_RADIO_EXCISED=true
PRODUCT_MODEL=GuardTalk Pixel 8a
RELEASE_KERNEL_AKITA_DIR=device/google/akita-kernels/6.1/trunk-14096387
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE=vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist
TARGET_BOARD_PLATFORM=zuma
```

## Tokay

GuardTalk tokay layer and `vendor/google_devices/tokay/` intentionally
untouched. Pre-existing tokay `adevtool-version-check.mk` pin drift remains.
