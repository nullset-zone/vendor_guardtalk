# T-REMEDIATE-B2-APEX (DEC-REMEDIATE-005 item 13 residual)
#
# Filter-out the DeviceLock mainline APEX from GuardTalkOS PRODUCT_PACKAGES.
# DeviceLockController / DeviceLockControllerDebug APK *names* are already
# dropped in apps-excised.mk. The APEX (base_system.mk) still nested the
# controller APK; lunch `komodo-trunk_staging-user` must not list
# `com.android.devicelock`.
#
# Dedicated file (do not fold into the GmsCompat drop stanza). HTMLViewer /
# UniversalMediaPlayer KEEP and Gallery2 excision are untouched.
#
# BCP PRODUCT_APEX_BOOT_JARS com.android.devicelock:framework-devicelock is
# intentionally NOT stripped at make time (apex-bcp-excised.mk 2026-07-04:
# dropping that BCP *entry* while the Java hard-call remained boot-looped
# Zygote). Runtime BCP only includes the jar if the APEX is installed.
# SystemServiceRegistry now catch-skips DeviceLockFrameworkInitializer when
# the class is absent (NoClassDefFoundError). Without that catch, an
# excised APEX + leftover hard-call is a zygote death loop
# (komodo-debug-20260918-180338 on-device).
# DEC-REMEDIATE-013: lockstep-filter the standalone SSR jar so
# dex_preopt_check does not require oat/vdex for an excised APEX.
# Sibling T-REMEDIATE-B2-LMS owns SystemServer.java — not this file.
# Reversible (Law 11): delete the include in guardtalk-feature-excised.mk.
# Idempotent (Law 8).

GUARDTALK_DEVICELOCK_APEX_DROP := \
    com.android.devicelock \
    com.android.devicelock-debug

PRODUCT_PACKAGES := $(filter-out $(GUARDTALK_DEVICELOCK_APEX_DROP),$(PRODUCT_PACKAGES))
PRODUCT_PACKAGES_DEBUG := $(filter-out $(GUARDTALK_DEVICELOCK_APEX_DROP),$(PRODUCT_PACKAGES_DEBUG))

# T-REMEDIATE-B1-DEBUG-M / DEC-013 — orphaned dexpreopt lockstep.
# Load from the product snapshot: product-config-late.mk rehydrates
# PRODUCT_PACKAGES but not this list.
$(eval PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS))
PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS := $(filter-out \
    com.android.devicelock:service-devicelock \
    ,$(PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS))
$(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS := $(PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS))
