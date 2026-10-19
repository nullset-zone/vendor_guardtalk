# Flash matrix — device × channel × flash phase (GENERATED)

> DO NOT EDIT BY HAND. Regenerate: `node scripts/gen-flash-matrix.mjs`
> Generated at `2026-10-16T19:09:13.965Z`; derived from revision `7f6916c08ea24cc7e1136fa92f4b2102eb8422ca`.
> HONESTY: `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`. This records what is packed; it proves no image boots.

## Counts

| Metric | Value |
|--------|-------|
| ALLOWED_PRODUCTS | 4 |
| status.json routes.targets | 2 |
| status.json experimentalTargets | 1 |
| packed channels on disk | 4 |
| advertised-but-not-packed | 0 |

## Advertised vs packed (divergence ledger)

| Product | Verdict | Packed sourceStamp | Advertised current stamp | Advertised by | Reason |
|---------|---------|--------------------|--------------------------|---------------|--------|
| akita | PACKED-CURRENT | akita-20260928-083403 | akita-20260928-083403 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (experimentalTargets) | packed channel matches the advertised current stamp |
| komodo | PACKED-CURRENT | komodo-20260928-052609 | komodo-20260928-052609 | src/types.ts:3 (ALLOWED_PRODUCTS) | packed channel matches the advertised current stamp |
| rango | PACKED-CURRENT | rango-20260928-081134 | rango-20260928-081134 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| tokay | PACKED-CURRENT | tokay-20260928-084839 | tokay-20260928-084839 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |

## Device × channel × phase

Every artifact is mapped to flash step `§6 Flash` via its phase (firmware / avb / os); flash order firmware → avb_custom_key → os.

### akita — PACKED

- advertised by: allowlist, experimental
- current stamp on disk: akita-20260928-083403
- channel `dev/unlocked` sourceStamp `akita-20260928-083403` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 19220088 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 715530240 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 115355788 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 953065472 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 368717824 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 705380352 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 31084544 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### komodo — PACKED (absent from product facts)

- advertised by: allowlist
- current stamp on disk: komodo-20260928-052609
- channel `dev/unlocked` sourceStamp `komodo-20260928-052609` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 725594112 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 953065472 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 368812032 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 808267776 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32141312 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### rango — PACKED

- advertised by: allowlist, targets
- current stamp on disk: rango-20260928-081134
- channel `dev/unlocked` sourceStamp `rango-20260928-081134` (CURRENT); artifacts 21 (2 firmware / 1 avb / 18 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 782233600 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 3168557384 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 969293824 | yes |
| system_dlkm.img | os | os | os | 11452416 | yes |
| system_ext.img | os | os | os | 467542016 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_valid_flags3.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 910831616 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37666816 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### tokay — PACKED

- advertised by: allowlist, targets
- current stamp on disk: tokay-20260928-084839
- channel `dev/unlocked` sourceStamp `tokay-20260928-084839` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 706691072 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 953065472 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 368766976 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 801120256 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

