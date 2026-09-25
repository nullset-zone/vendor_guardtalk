# Engineering-only root sidecar (userdebug)

**Task:** `T-REMEDIATE-B1-USERBUILD` (items 1, 2, 3, 5)  
**Date:** 2026-09-16  
**Device:** Pixel 9 Pro XL (`komodo`)  
**DEC:** DEC-REMEDIATE-001

## Rule

Production GuardTalkOS for komodo is **`komodo-trunk_staging-user`**.

Engineering root (`su`, `overlay_remounter`, `ro.debuggable=1`) is a
**sidecar userdebug image**. It is **not** wired into the production product
makefile. Do not add `su` or `overlay_remounter` to
`vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk`.

| Image | Lunch | `ro.debuggable` | `su` / `overlay_remounter` | Intended use |
|-------|-------|-----------------|------------------------------|--------------|
| **Production** | `komodo-trunk_staging-user` | `0` (AOSP user mapping) | Absent (not in PRODUCT_PACKAGES; late filter-out) | Release / audit device |
| **Sidecar eng-root** | `komodo-trunk_staging-userdebug` | `1` (AOSP userdebug mapping) | AOSP `PRODUCT_PACKAGES_DEBUG` | Lab bring-up only |

AOSP maps `user` → `ro.debuggable=0` and `ro.adb.secure=1` in
`build/soong/scripts/gen_build_prop.py`. Do **not** PRODUCT-override
`ro.debuggable` on userdebug — that lies about the image.

`debug_ramdisk` / `adb_debug.prop` may still contain `ro.adb.secure=0`. That
is **not** product truth for the user image.

## What production mk must not contain

- `PRODUCT_PACKAGES += su`
- `PRODUCT_PACKAGES += overlay_remounter`
- `ro.debuggable=0` forced via `PRODUCT_PROPERTY_OVERRIDES` (variant does this)
- AVB private keys (`*.pem`, `*.pk8`)

## Sidecar build (engineering host only)

```bash
source build/envsetup.sh
lunch komodo-trunk_staging-userdebug
```

If lunch fails on adevtool pin, HOLD that command. Do not flash the sidecar
to production-custody hardware. Serial under audit (`54111FDAS000GN`) stays
**PASS HOLD** until a signed **user** image is rematched on-device
(Q-REMEDIATE-B1-ONDEVICE).

DEC-011 / DEC-018 debug-channel honesty (`DEBUG_FLASH_READY=true` for
sidecar stamp `komodo-debug-20260918-180338` / `komodo-debug-latest`;
`USB_GO=false`; `FLASH_READY=false`; DEC-017 leftover SHA HOLD residual;
do not retarget `komodo-latest`): `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`.

## Rollback

Remove `vendor/guardtalk/feature-excised/userbuild-excised.mk` include from
`product-config-late.mk` and revert komodo `guardtalk-production-hardening.mk`.
No irreversible state.
