# Flash matrix — device × channel × flash phase (GENERATED)

> DO NOT EDIT BY HAND. Regenerate: `node scripts/gen-flash-matrix.mjs`
> Generated at `2026-11-16T17:09:45.214Z`; derived from revision `6b0f93cea079402f01999266f6612f08c3dbe17f`.
> HONESTY: `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`. This records what is packed; it proves no image boots.

## Counts

| Metric | Value |
|--------|-------|
| ALLOWED_PRODUCTS | 4 |
| status.json routes.targets | 7 |
| status.json experimentalTargets | 1 |
| packed channels on disk | 8 |
| advertised-but-not-packed | 0 |

## Advertised vs packed (divergence ledger)

| Product | Verdict | Packed sourceStamp | Advertised current stamp | Advertised by | Reason |
|---------|---------|--------------------|--------------------------|---------------|--------|
| akita | PACKED-CURRENT | akita-20261116-145007 | akita-20261116-145007 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (experimentalTargets) | packed channel matches the advertised current stamp |
| blazer | PACKED-CURRENT | blazer-20261116-170315 | blazer-20261116-170315 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| caiman | PACKED-CURRENT | caiman-20261116-140234 | caiman-20261116-140234 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| frankel | PACKED-CURRENT | frankel-20261116-165727 | frankel-20261116-165727 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| komodo | PACKED-CURRENT | komodo-20261116-141702 | komodo-20261116-141702 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| rango | PACKED-CURRENT | rango-20261116-170059 | rango-20261116-170059 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| stallion | PACKED-CURRENT | stallion-20261116-142801 | stallion-20261116-142801 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| tokay | PACKED-CURRENT | tokay-20261116-143907 | tokay-20261116-143907 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |

## Device × channel × phase

Every artifact is mapped to flash step `§6 Flash` via its phase (firmware / avb / os); flash order firmware → avb_custom_key → os.

### akita — PACKED

- advertised by: allowlist, experimental
- current stamp on disk: akita-20261116-145007
- channel `dev/unlocked` sourceStamp `akita-20261116-145007` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 19220088 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 709324800 | yes |
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
- current stamp on disk: blazer-20261116-170315
- channel `dev/unlocked` sourceStamp `blazer-20261116-170315` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 723771392 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2928859372 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1004466176 | yes |
| system_dlkm.img | os | os | os | 11456512 | yes |
| system_ext.img | os | os | os | 350511104 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 894627840 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37572608 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### caiman — PACKED

- advertised by: targets
- current stamp on disk: caiman-20261116-140234
- channel `dev/unlocked` sourceStamp `caiman-20261116-140234` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 717152256 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 920760320 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 350461952 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 810590208 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### frankel — PACKED

- advertised by: targets
- current stamp on disk: frankel-20261116-165727
- channel `dev/unlocked` sourceStamp `frankel-20261116-165727` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 721145856 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2947573996 | yes |
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

### komodo — PACKED

- advertised by: allowlist, targets
- current stamp on disk: komodo-20261116-141702
- channel `dev/unlocked` sourceStamp `komodo-20261116-141702` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 719380480 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1092751360 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352268288 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 809840640 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### rango — PACKED

- advertised by: allowlist, targets
- current stamp on disk: rango-20261116-170059
- channel `dev/unlocked` sourceStamp `rango-20261116-170059` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 736301056 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2972797204 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1013624832 | yes |
| system_dlkm.img | os | os | os | 11452416 | yes |
| system_ext.img | os | os | os | 350679040 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 916758528 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37666816 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### stallion — PACKED

- advertised by: targets
- current stamp on disk: stallion-20261116-142801
- channel `dev/unlocked` sourceStamp `stallion-20261116-142801` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 711720960 | yes |
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

### tokay — PACKED

- advertised by: allowlist, targets
- current stamp on disk: tokay-20261116-143907
- channel `dev/unlocked` sourceStamp `tokay-20261116-143907` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

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

