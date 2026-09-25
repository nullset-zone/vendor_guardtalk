# GuardTalkOS shiba — ensure init.insmod.shiba.cfg is installed on vendor_dlkm.
#
# Root cause (akita boot-logo hang precedent, T-PORT-KOMODO-LAYER): adevtool
# device-common.mk installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. trunk_staging sets
# RELEASE_KERNEL_SHIBA_DIR to .../trunk-14096387 which is a symlink →
# grapheneos/, so the cfg would be silently omitted from vendor_dlkm.img.
#
# Without it, init.shiba.rc's insmod never modprobes:
#   bcmdhd4398, goodix_brl_touch, sec_touch, snd-soc-cs40l26, cs40l26-i2c,
#   rt6160-regulator
# → Wi‑Fi / touch / audio / haptics missing at second-stage.
#
# Explicit copy (path resolved by make, not find) is fail-closed insurance.
# T-PORT-BATCH-A: shiba shares the shusky kernel family, so the path below is
# the symlink-free device/google/shusky-kernels/6.1/grapheneos directory
# (verified to exist and to hold init.insmod.shiba.cfg).
LOCAL_PATH_GT_SHIBA_INSMOD := device/google/shusky-kernels/6.1/grapheneos

ifeq ($(wildcard $(LOCAL_PATH_GT_SHIBA_INSMOD)/init.insmod.shiba.cfg),)
$(error GuardTalk shiba: missing $(LOCAL_PATH_GT_SHIBA_INSMOD)/init.insmod.shiba.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_SHIBA_INSMOD)/init.insmod.shiba.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.shiba.cfg
