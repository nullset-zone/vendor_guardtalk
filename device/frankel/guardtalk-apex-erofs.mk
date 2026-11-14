# GuardTalkOS frankel — EROFS APEX payload type (T-EXCISE-FRANKEL-BP4A-CP1A-BACKPORT-REBUILD).
#
# `lunch frankel-cur-userdebug` resolves:
#   TARGET_PRODUCT=frankel  GT_VARIANT=laguna_muzel
#   TARGET_BUILD_VARIANT=userdebug
#   PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE=ext4     <-- does NOT match factory EROFS APEXes
#
# Root cause of the ext4 default: `build/make/core/product_config.mk` picks erofs
# only when `RELEASE_APEX_USE_EROFS_PREINSTALLED` is true, which is set for
# `trunk_staging` but NOT for this lunch target (its TARGET_RELEASE is empty).
#
# A product-level default, not a module override, so it applies to every APEX in
# the image — matching blazer and rango parity.
#
# LAW 11 (Reversibility): delete this file and its one-line include in
# vendor/google_devices/frankel/frankel.mk to restore ext4 behaviour exactly.
PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE := erofs
