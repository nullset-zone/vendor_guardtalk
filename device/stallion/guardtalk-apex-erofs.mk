# GuardTalkOS stallion — restor the EROFS APEX payload type (T-FLASH-STALLION-APEX-PAYLOAD).
#
# WHY THIS EXISTS
#
# The 2026-11-09 flash of `stallion-20261108-camera` failed to boot with
#   Reboot mode: 0xfc  (apexd-bootstrap reboot_on_failure)
#   is-userspace=no, AB Decisions: 11111111
#
# Investigation found the failing `system.img` was the FIRST `user`-variant
# GuardTalk system image ever flashed to this handset — every earlier stamp
# carried an inherited `userdebug` image built 2026-07-02 (`eng.openst`).
#
# The material difference is not the camera APK. It is the APEX payload
# filesystem:
#
#   inherited image  : /system/apex/*.apex payloads are **EROFS** (compressed)
#   our build        : the same payloads are **ext4** (uncompressed)
#
# Measured on com.android.art.apex, identical 29 libs in both:
#   old payload  20,488,192 B  EROFS
#   new payload  35,188,736 B  ext4
# and across the whole image: /system/apex 276 MB -> 463 MB (+187 MB), with
# 32 of 34 APEXes growing uniformly. Uniform growth across every mainline
# module is a build-configuration signature, not a feature change.
#
# Root cause: `build/make/core/product_config.mk:581-584` defaults the APEX
# payload type to ext4 and only selects erofs when
# `RELEASE_APEX_USE_EROFS_PREINSTALLED` is true. That flag is set true for the
# `trunk_staging` release (build/release/flag_values/trunk_staging/
# RELEASE_APEX_USE_EROFS_PREINSTALLED.textproto) but `lunch stallion-cur-user`
# carries **no TARGET_RELEASE at all** (verified: TARGET_RELEASE empty,
# PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE=ext4). So the release flag never applied
# and every APEX was built uncompressed.
#
# WHY IT MATTERS BEYOND SIZE: the device has only ever activated an EROFS
# APEX set. apexd-bootstrap is what reboots on APEX activation failure, and
# 0xfc is its signature. This is the leading hypothesis for the boot failure
# and is cheap to eliminate.
#
# LAW 11 (Reversibility): deleting this file and the one-line include in
# vendor/google_devices/stallion/stallion.mk restores ext4 behaviour exactly.
#
# This is a product-level default, not a module override, so it applies to
# every APEX in the image — which is what the inherited image had.
PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE := erofs
