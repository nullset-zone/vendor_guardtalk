# GuardTalkOS blazer — ensure init.insmod.blazer.cfg is installed on vendor_dlkm.
#
# Root cause (akita boot-logo hang precedent, T-PORT-KOMODO-LAYER; carried
# through the caiman layer): adevtool device-common.mk installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. trunk_staging sets
# RELEASE_KERNEL_BLAZER_DIR to
# device/google/laguna-kernels/6.6/trunk-14072179/muzel, and trunk-14072179 is
# a symlink → grapheneos/, so the cfg can be silently omitted from
# vendor_dlkm.img.
#
# Without it, init never modprobes:
#   bcmdhd4383, bcmdhd4390, syna_touch, focal_touch, fst2, cs40l26-i2c, …
# → Wi-Fi / touch / haptics missing at second-stage.
#
# Explicit copy from the symlink-free real path (make-resolved, not find) is
# fail-closed insurance.

LOCAL_PATH_GT_BLAZER_INSMOD := device/google/laguna-kernels/6.6/grapheneos/muzel

ifeq ($(wildcard $(LOCAL_PATH_GT_BLAZER_INSMOD)/init.insmod.blazer.cfg),)
$(error GuardTalk blazer: missing $(LOCAL_PATH_GT_BLAZER_INSMOD)/init.insmod.blazer.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_BLAZER_INSMOD)/init.insmod.blazer.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.blazer.cfg
