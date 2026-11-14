# GuardTalkOS rango — EROFS APEX payload type (T-EXCISE-RANGO-PREPARE-CP1A).
#
# WHY: measured from rango's existing stamp `rango-20260928-081134`:
#   com.android.art.apex payload      20,488,192 bytes
#   file(1) on that payload           "EROFS filesystem, compat"
#
# `lunch rango-cur-userdebug` resolves:
#   TARGET_PRODUCT=rango  GT_VARIANT=laguna_rango
#   TARGET_BUILD_VARIANT=userdebug
#   PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE=ext4     <-- does NOT match EROFS
#
# Root cause of the ext4 default: `build/make/core/product_config.mk:581-584`
# picks erofs only when `RELEASE_APEX_USE_EROFS_PREINSTALLED` is true, which is
# set for `trunk_staging` but NOT for `cur` (its TARGET_RELEASE is empty).
# Mirroring `vendor/guardtalk/device/blazer/guardtalk-apex-erofs.mk`, force
# product-wide EROFS APEX payloads so every APEX in `/system/apex` (including
# `com.android.art.apex` and `com.android.virt.apex`) matches Laguna's boot path.
#
# LAW 11 (Reversibility): delete this file and its include in
# vendor/google_devices/rango/rango.mk to restore ext4 behaviour.
PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE := erofs
