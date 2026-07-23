# GuardTalkOS — production hardening props (T-SEC-P5-HARDEN).
#
# LIVE: included from vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
# so PRODUCT_PROPERTY_OVERRIDES reach vendor/build.prop.
#
# Design:
# - Always emit GuardTalk hardening markers / policy knobs (engineering + prod).
# - Production *profile* marker (ro.guardtalk.production_profile=1) only on
#   TARGET_BUILD_VARIANT=user. Do NOT force ro.debuggable=0 via PRODUCT_* —
#   AOSP sets that from the lunch variant (user → 0, userdebug → 1).
# - Kernel sysctl hardening is applied by init.guardtalk.hardening.rc
#   (PRODUCT_PACKAGES in guardtalk-feature-excised.mk).
# - Release keys / AVB: wiring docs only — no private keys in-tree
#   (see vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md +
#    branding/signing-keys/RUNBOOK.md).

PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.production_hardening=1 \
    ro.guardtalk.block_unknown_sources=1 \
    ro.guardtalk.restrict_accessibility_services=1 \
    ro.guardtalk.restrict_display_overlays=1 \
    ro.guardtalk.restrict_dynamic_code=1 \
    ro.guardtalk.selinux_enforcing_required=1 \
    ro.guardtalk.verified_boot_required=1 \
    ro.guardtalk.keymint_required=1 \
    ro.guardtalk.sysctl_hardening=1

# Production lunch profile marker. Engineering userdebug keeps this unset/0 so
# status UI can distinguish staging vs production images.
ifeq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.production_profile=1
endif
