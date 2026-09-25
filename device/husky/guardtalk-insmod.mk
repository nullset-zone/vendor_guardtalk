# GuardTalkOS husky — ensure init.insmod.husky.cfg is installed on vendor_dlkm.
#
# Root cause (akita boot-logo hang precedent, T-PORT-KOMODO-LAYER): adevtool
# device-common.mk installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. trunk_staging sets
# RELEASE_KERNEL_HUSKY_DIR to .../trunk-14096387 which is a symlink →
# grapheneos/, so the cfg would be silently omitted from vendor_dlkm.img.
#
# Without it, init.husky.rc's insmod never modprobes:
#   bcmdhd4398, goodix_brl_touch, sec_touch, snd-soc-cs40l26, cs40l26-i2c,
#   rt6160-regulator
# → Wi‑Fi / touch / audio / haptics missing at second-stage.
#
# Explicit copy (path resolved by make, not find) is fail-closed insurance.
# T-PORT-BATCH-A: husky shares the shusky kernel family with shiba, so the path
# below is the symlink-free device/google/shusky-kernels/6.1/grapheneos
# directory (verified to exist and to hold init.insmod.husky.cfg).
LOCAL_PATH_GT_HUSKY_INSMOD := device/google/shusky-kernels/6.1/grapheneos

ifeq ($(wildcard $(LOCAL_PATH_GT_HUSKY_INSMOD)/init.insmod.husky.cfg),)
$(error GuardTalk husky: missing $(LOCAL_PATH_GT_HUSKY_INSMOD)/init.insmod.husky.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_HUSKY_INSMOD)/init.insmod.husky.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.husky.cfg
