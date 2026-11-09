# GuardTalkOS blazer — EROFS APEX payload type (T-BLAZER-PREPARE).
#
# WHY: measured from blazer's own existing stamp `blazer-20260928-060401`:
#   /system/apex                      238 MB, 33 APEXes
#   com.android.art.apex payload      20,488,192 bytes
#   file(1) on that payload           "EROFS filesystem, compat"
#
# But `lunch blazer-cur-userdebug` resolves
#   TARGET_PRODUCT=blazer  GT_VARIANT=laguna_muzel
#   TARGET_BUILD_VARIANT=userdebug
#   PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE=ext4     <-- does NOT match the stamp
#
# Root cause of the ext4 default: `build/make/core/product_config.mk:581-584`
# picks erofs only when `RELEASE_APEX_USE_EROFS_PREINSTALLED` is true, which is
# set for `trunk_staging` but NOT for this lunch target (its TARGET_RELEASE is
# empty). The same mismatch produced five failed Stallion boots: every natively
# built Stallion system image used ext4 while every image that device had ever
# booted used EROFS. Forcing erofs here is what made the Stallion image boot.
#
# A product-level default, not a module override, so it applies to every APEX in
# the image — which is what the inherited factory-derived stamp already had.
#
# LAW 11 (Reversibility): delete this file and its one-line include in
# vendor/google_devices/blazer/blazer.mk to restore ext4 behaviour exactly.
PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE := erofs
