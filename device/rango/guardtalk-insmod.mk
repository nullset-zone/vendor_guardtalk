# GuardTalkOS rango — ensure init.insmod.rango.cfg is installed on vendor_dlkm.
#
# Root cause (boot logo hang on akita precedent): adevtool device-common.mk
# installs
#   $(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),...)
# GNU find does NOT traverse a symlink start path. If trunk_staging still
# resolves TARGET_KERNEL_DIR through trunk-14072179 → grapheneos/, the cfg
# can be silently omitted from vendor_dlkm.img.
#
# Without it, init never modprobes:
#   bcmdhd4390, cs40l26-i2c, fst2, snd-soc-cs40l26, syna_touch
# → Wi‑Fi / haptics / foldable touch path broken.
#
# Explicit copy from the real grapheneos/rango path (make-resolved, not find)
# is fail-closed insurance. Durable aconfig also points RELEASE_KERNEL_RANGO_DIR
# at …/grapheneos/rango so find-copy works when that flag is used.

LOCAL_PATH_GT_RANGO_INSMOD := device/google/laguna-kernels/6.6/grapheneos/rango

ifeq ($(wildcard $(LOCAL_PATH_GT_RANGO_INSMOD)/init.insmod.rango.cfg),)
$(error GuardTalk rango: missing $(LOCAL_PATH_GT_RANGO_INSMOD)/init.insmod.rango.cfg)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH_GT_RANGO_INSMOD)/init.insmod.rango.cfg:$(TARGET_COPY_OUT_VENDOR_DLKM)/etc/init.insmod.rango.cfg
