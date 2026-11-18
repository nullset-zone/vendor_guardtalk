# Flash matrix — device × channel × flash phase (GENERATED)

> DO NOT EDIT BY HAND. Regenerate: `node scripts/gen-flash-matrix.mjs`
> Generated at `2026-11-18T11:07:50.737Z`; derived from revision `7389aa5e2b52c37d0c1cc14329b89e38e3f895e9`.
> HONESTY: `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`. This records what is packed; it proves no image boots.

## Counts

| Metric | Value |
|--------|-------|
| ALLOWED_PRODUCTS | 4 |
| status.json routes.targets | 13 |
| status.json experimentalTargets | 1 |
| packed channels on disk | 14 |
| advertised-but-not-packed | 0 |

## Advertised vs packed (divergence ledger)

| Product | Verdict | Packed sourceStamp | Advertised current stamp | Advertised by | Reason |
|---------|---------|--------------------|--------------------------|---------------|--------|
| akita | PACKED-CURRENT | akita-20261117-171727 | akita-20261117-171727 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (experimentalTargets) | packed channel matches the advertised current stamp |
| blazer | PACKED-CURRENT | blazer-20261117-190458 | blazer-20261117-190458 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| caiman | PACKED-CURRENT | caiman-20261117-164109 | caiman-20261117-164109 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| comet | PACKED-CURRENT | comet-20261117-172717 | comet-20261117-172717 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| frankel | PACKED-CURRENT | frankel-20261117-190933 | frankel-20261117-190933 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| husky | PACKED-CURRENT | husky-20261117-173656 | husky-20261117-173656 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| komodo | PACKED-CURRENT | komodo-20261117-165012 | komodo-20261117-165012 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| mustang | PACKED-CURRENT | mustang-20261117-190232 | mustang-20261117-190232 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| rango | PACKED-CURRENT | rango-20261117-190715 | rango-20261117-190715 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| shiba | PACKED-CURRENT | shiba-20261117-174553 | shiba-20261117-174553 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| stallion | PACKED-CURRENT | stallion-20261117-165909 | stallion-20261117-165909 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| tangorpro | PACKED-CURRENT | tangorpro-20261117-181013 | tangorpro-20261117-181013 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| tegu | PACKED-CURRENT | tegu-20261117-175443 | tegu-20261117-175443 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| tokay | PACKED-CURRENT | tokay-20261117-170816 | tokay-20261117-170816 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |

## Device × channel × phase

Every artifact is mapped to flash step `§6 Flash` via its phase (firmware / avb / os); flash order firmware → avb_custom_key → os.

### akita — PACKED

- advertised by: allowlist, experimental
- current stamp on disk: akita-20261117-171727
- channel `dev/unlocked` sourceStamp `akita-20261117-171727` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 19220088 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 709316608 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 115355788 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092481024 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352178176 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 707354624 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 31084544 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### blazer — PACKED

- advertised by: targets
- current stamp on disk: blazer-20261117-190458
- channel `dev/unlocked` sourceStamp `blazer-20261117-190458` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 723763200 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2928847084 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1004466176 | yes |
| system_dlkm.img | os | os | os | 11456512 | yes |
| system_ext.img | os | os | os | 350511104 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 894623744 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37572608 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### caiman — PACKED

- advertised by: targets
- current stamp on disk: caiman-20261117-164109
- channel `dev/unlocked` sourceStamp `caiman-20261117-164109` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 717144064 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 920760320 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 350461952 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 810586112 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### comet — PACKED

- advertised by: targets
- current stamp on disk: comet-20261117-172717
- channel `dev/unlocked` sourceStamp `comet-20261117-172717` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 731455488 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1101631488 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352448512 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 785408000 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32530432 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### frankel — PACKED

- advertised by: targets
- current stamp on disk: frankel-20261117-190933
- channel `dev/unlocked` sourceStamp `frankel-20261117-190933` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 721137664 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2947565804 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1004466176 | yes |
| system_dlkm.img | os | os | os | 11456512 | yes |
| system_ext.img | os | os | os | 350507008 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 916025344 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37572608 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### husky — PACKED

- advertised by: targets
- current stamp on disk: husky-20261117-173656
- channel `dev/unlocked` sourceStamp `husky-20261117-173656` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 19203704 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 714997760 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 112967820 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092481024 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352292864 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 728797184 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 31375360 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### komodo — PACKED

- advertised by: allowlist, targets
- current stamp on disk: komodo-20261117-165012
- channel `dev/unlocked` sourceStamp `komodo-20261117-165012` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 719372288 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092751360 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352268288 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 809836544 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### mustang — PACKED

- advertised by: targets
- current stamp on disk: mustang-20261117-190232
- channel `dev/unlocked` sourceStamp `mustang-20261117-190232` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 726769664 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092689920 | yes |
| system_dlkm.img | os | os | os | 10977280 | yes |
| system_ext.img | os | os | os | 352317440 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 894410752 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 48463872 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### rango — PACKED

- advertised by: allowlist, targets
- current stamp on disk: rango-20261117-190715
- channel `dev/unlocked` sourceStamp `rango-20261117-190715` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 736292864 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2972784888 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1013624832 | yes |
| system_dlkm.img | os | os | os | 11452416 | yes |
| system_ext.img | os | os | os | 350679040 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 916754432 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37666816 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### shiba — PACKED

- advertised by: targets
- current stamp on disk: shiba-20261117-174553
- channel `dev/unlocked` sourceStamp `shiba-20261117-174553` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 19203704 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 708718592 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 112967820 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092481024 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352268288 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 719073280 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 31375360 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### stallion — PACKED

- advertised by: targets
- current stamp on disk: stallion-20261117-165909
- channel `dev/unlocked` sourceStamp `stallion-20261117-165909` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 711712768 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 922083328 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 351637504 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 829820928 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 30900224 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### tangorpro — PACKED

- advertised by: targets
- current stamp on disk: tangorpro-20261117-181013
- channel `dev/unlocked` sourceStamp `tangorpro-20261117-181013` (CURRENT); artifacts 16 (1 firmware / 1 avb / 14 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 14388488 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 694996992 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1090953216 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 340488192 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 587829248 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 27840512 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### tegu — PACKED

- advertised by: targets
- current stamp on disk: tegu-20261117-175443
- channel `dev/unlocked` sourceStamp `tegu-20261117-175443` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 716611584 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 98766988 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092481024 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352210944 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 736014336 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 30908416 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### tokay — PACKED

- advertised by: allowlist, targets
- current stamp on disk: tokay-20261117-170816
- channel `dev/unlocked` sourceStamp `tokay-20261117-170816` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 700493824 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092767744 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352227328 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 803102720 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

