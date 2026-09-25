# T-REMEDIATE-B1-USERBUILD — drop setuid su and overlay_remounter from
# production user images.
#
# AOSP ships both via PRODUCT_PACKAGES_DEBUG in
# build/make/target/product/base_system.mk (do not edit that file). Current
# komodo userdebug out still installs /system/xbin/{su,overlay_remounter}.
# user lunch does not install PRODUCT_PACKAGES_DEBUG; this late filter-out is
# defence-in-depth if either name also lands on PRODUCT_PACKAGES.
#
# overlay_remounter is additionally a Soong `required:` of the init phony when
# product_variable("debuggable") is true (system/core/init/Android.bp). On
# user (debuggable=false) init does not require it.
#
# Engineering-only root remains the sidecar userdebug image — not this
# production product. See vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md.
# Reversible (filter-out only; Law 11). Idempotent (Law 8).

ifeq ($(TARGET_BUILD_VARIANT),user)
GUARDTALK_USERBUILD_DROP := su overlay_remounter
PRODUCT_PACKAGES := $(filter-out $(GUARDTALK_USERBUILD_DROP),$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES_DEBUG := $(filter-out $(GUARDTALK_USERBUILD_DROP),$(PRODUCT_PACKAGES_DEBUG))
endif
