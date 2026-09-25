# GuardTalkOS comet — ensure init.insmod.comet.cfg is installed on vendor_dlkm.
#
# Root cause (akita boot-logo hang precedent, T-PORT-KOMODO-LAYER): adevtool
# device-common.mk installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. trunk_staging may set
# RELEASE_KERNEL_COMET_DIR to a trunk-* → grapheneos/ symlink, so the cfg would
# be silently omitted from vendor_dlkm.img.
#
# Without it, init.comet.rc's insmod never modprobes:
#   bcmdhd4390, snd-soc-cs35l41-i2c, goodix_brl_touch, syna_touch,
#   cs40l26-i2c, snd-soc-cs40l26, rt6160-regulator
# → Wi‑Fi / audio / haptics / touch missing at second-stage.
#
# Explicit copy (path resolved by make, not find) is fail-closed insurance.
# The path below is the symlink-free grapheneos/ directory (verified to exist).

LOCAL_PATH_GT_COMET_INSMOD := device/google/comet-kernels/6.1/grapheneos

ifeq ($(wildcard $(LOCAL_PATH_GT_COMET_INSMOD)/init.insmod.comet.cfg),)
$(error GuardTalk comet: missing $(LOCAL_PATH_GT_COMET_INSMOD)/init.insmod.comet.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_COMET_INSMOD)/init.insmod.comet.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.comet.cfg
