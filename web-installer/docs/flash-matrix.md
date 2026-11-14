# Flash matrix — device × channel × flash phase (GENERATED)

> DO NOT EDIT BY HAND. Regenerate: `node scripts/gen-flash-matrix.mjs`
> Generated at `2026-11-14T11:07:46.924Z`; derived from revision `ae57e44297b081ffccf502bc43ecde97de0ef864`.
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
| akita | PACKED-CURRENT | akita-20261114-100809 | akita-20261114-100809 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (experimentalTargets) | packed channel matches the advertised current stamp |
| blazer | PACKED-CURRENT | blazer-20261114-092102 | blazer-20261114-092102 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| caiman | PACKED-CURRENT | caiman-20261114-084610 | caiman-20261114-084610 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| frankel | PACKED-CURRENT | frankel-20261114-090341 | frankel-20261114-090341 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| komodo | PACKED-CURRENT | komodo-20261114-093819 | komodo-20261114-093819 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| rango | PACKED-CURRENT | rango-20261114-091159 | rango-20261114-091159 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |
| stallion | PACKED-CURRENT | stallion-20261114-094654 | stallion-20261114-094654 | status.json (routes.targets) | packed channel matches the advertised current stamp |
| tokay | PACKED-CURRENT | tokay-20261114-095740 | tokay-20261114-095740 | src/types.ts:3 (ALLOWED_PRODUCTS); status.json (routes.targets) | packed channel matches the advertised current stamp |

## Device × channel × phase

Every artifact is mapped to flash step `§6 Flash` via its phase (firmware / avb / os); flash order firmware → avb_custom_key → os.

### akita — PACKED

- advertised by: allowlist, experimental
- current stamp on disk: akita-20261114-100809
- channel `dev/unlocked` sourceStamp `akita-20261114-100809` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 19220088 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 709320704 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 115355788 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1112690688 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352432128 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 709574656 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 31084544 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### blazer — PACKED

- advertised by: targets
- current stamp on disk: blazer-20261114-092102
- channel `dev/unlocked` sourceStamp `blazer-20261114-092102` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 723767296 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2951600280 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 940371968 | yes |
| system_dlkm.img | os | os | os | 11452416 | yes |
| system_ext.img | os | os | os | 350760960 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 897179648 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37761024 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### caiman — PACKED

- advertised by: targets
- current stamp on disk: caiman-20261114-084610
- channel `dev/unlocked` sourceStamp `caiman-20261114-084610` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 717148160 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 940765184 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 350703616 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 813195264 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### frankel — PACKED

- advertised by: targets
- current stamp on disk: frankel-20261114-090341
- channel `dev/unlocked` sourceStamp `frankel-20261114-090341` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 21915024 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 721141760 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super.img | os | os | os | 2969766040 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 940371968 | yes |
| system_dlkm.img | os | os | os | 11452416 | yes |
| system_ext.img | os | os | os | 350756864 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 918024192 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37761024 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### komodo — PACKED

- advertised by: allowlist, targets
- current stamp on disk: komodo-20261114-093819
- channel `dev/unlocked` sourceStamp `komodo-20261114-093819` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 719376384 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1112981504 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352522240 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 812462080 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### rango — PACKED

- advertised by: allowlist, targets
- current stamp on disk: rango-20261114-091159
- channel `dev/unlocked` sourceStamp `rango-20261114-091159` (CURRENT); artifacts 20 (2 firmware / 1 avb / 17 os)

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
| super.img | os | os | os | 2995316928 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 949526528 | yes |
| system_dlkm.img | os | os | os | 11452416 | yes |
| system_ext.img | os | os | os | 350928896 | yes |
| vbmeta.img | os | os | os | 16384 | yes |
| vbmeta_system.img | os | os | os | 16384 | yes |
| vbmeta_vendor.img | os | os | os | 16384 | yes |
| vendor.img | os | os | os | 919396352 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 37588992 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### stallion — PACKED

- advertised by: targets
- current stamp on disk: stallion-20261114-094654
- channel `dev/unlocked` sourceStamp `stallion-20261114-094654` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 711716864 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 191426700 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 942116864 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 351883264 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 831889408 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 30900224 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

### tokay — PACKED

- advertised by: allowlist, targets
- current stamp on disk: tokay-20261114-095740
- channel `dev/unlocked` sourceStamp `tokay-20261114-095740` (CURRENT); artifacts 19 (2 firmware / 1 avb / 16 os)

| Artifact | files.txt phase | declared phase | flash order | size | mapped |
|----------|-----------------|----------------|-------------|------|--------|
| avb_pkmd.bin | avb | avb | avb_custom_key | 1032 | yes |
| boot.img | os | os | os | 67108864 | yes |
| bootloader.img | firmware | firmware | firmware | 18896828 | yes |
| dtbo.img | os | os | os | 16777216 | yes |
| init_boot.img | os | os | os | 8388608 | yes |
| product.img | os | os | os | 700489728 | yes |
| pvmfw.img | os | os | os | 1048576 | yes |
| radio.img | firmware | firmware | firmware | 136634508 | yes |
| super_empty.img | os | os | os | 5184 | yes |
| system.img | os | os | os | 1112981504 | yes |
| system_dlkm.img | os | os | os | 11055104 | yes |
| system_ext.img | os | os | os | 352481280 | yes |
| vbmeta.img | os | os | os | 65536 | yes |
| vbmeta_system.img | os | os | os | 65536 | yes |
| vbmeta_vendor.img | os | os | os | 65536 | yes |
| vendor.img | os | os | os | 805302272 | yes |
| vendor_boot.img | os | os | os | 67108864 | yes |
| vendor_dlkm.img | os | os | os | 32174080 | yes |
| vendor_kernel_boot.img | os | os | os | 67108864 | yes |

