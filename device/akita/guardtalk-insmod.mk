# GuardTalkOS akita — ensure init.insmod.akita.cfg is installed on vendor_dlkm.
#
# Root cause (boot logo hang): adevtool device-common.mk installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. trunk_staging sets
# RELEASE_KERNEL_AKITA_DIR to .../trunk-14096387 which is a symlink →
# grapheneos/, so the cfg is silently omitted from vendor_dlkm.img.
#
# Without it, init.akita.rc's insmod_sh_akita never modprobes:
#   snd-soc-cs35l41-i2c, cs40l26-i2c, snd-soc-cs40l26, bcmdhd4383, goodix_brl_touch
# → Audio HAL spins on "sound card open retry", vibrator HAL missing,
# → stuck on GuardTalk bootanimation.
#
# Explicit copy (path resolved by make, not find) is fail-closed insurance.

LOCAL_PATH_GT_AKITA_INSMOD := device/google/akita-kernels/6.1/grapheneos

ifeq ($(wildcard $(LOCAL_PATH_GT_AKITA_INSMOD)/init.insmod.akita.cfg),)
$(error GuardTalk akita: missing $(LOCAL_PATH_GT_AKITA_INSMOD)/init.insmod.akita.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_AKITA_INSMOD)/init.insmod.akita.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.akita.cfg
