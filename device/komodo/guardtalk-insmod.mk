# GuardTalkOS komodo — ensure init.insmod.komodo.cfg is installed on vendor_dlkm.
#
# Root cause (akita boot-logo hang precedent): adevtool device-common.mk installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. trunk_staging sets
# RELEASE_KERNEL_KOMODO_DIR to .../trunk-14096387 which is a symlink →
# grapheneos/, so the cfg would be silently omitted from vendor_dlkm.img.
#
# Without it, init.komodo.rc's insmod never modprobes:
#   bcmdhd4390, snd-soc-cs35l41-i2c, syna_touch, cs40l26-i2c, snd-soc-cs40l26,
#   rt6160-regulator
# → Wi‑Fi / audio / haptics / touch missing at second-stage.
#
# Explicit copy (path resolved by make, not find) is fail-closed insurance.
# T-PORT-KOMODO-LAYER does not run full `m`; this is FLASH-time insurance.

LOCAL_PATH_GT_KOMODO_INSMOD := device/google/caimito-kernels/6.1/grapheneos

ifeq ($(wildcard $(LOCAL_PATH_GT_KOMODO_INSMOD)/init.insmod.komodo.cfg),)
$(error GuardTalk komodo: missing $(LOCAL_PATH_GT_KOMODO_INSMOD)/init.insmod.komodo.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_KOMODO_INSMOD)/init.insmod.komodo.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.komodo.cfg
