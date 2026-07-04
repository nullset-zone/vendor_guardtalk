# GuardTalkOS APEX-BCP Excision Wave (Cat 3, 2026-07-02)
#
# Source: vendor/guardtalk/docs/ATTACK_SURFACE_REPORT.md (Cat 3, items 1-3).
# T-APEX-BCP-WAVE — Remove 3 Category-3 Mainline APEX via Lockstep BCP Edit.
#
# Three mainline APEX modules ship dormant in the GuardTalkOS image but
# constitute documented attack surface (see apps-excised.mk:253-322 for the
# Wave C investigation that established the BCP blocker):
#   - com.android.adservices            (Privacy/ads ML stack; bundles SdkSandbox)
#   - com.android.healthfitness         (Health Connect + federated ML)
#   - com.android.ondevicepersonalization (On-device personalization / FederatedCompute)
#
# Each is blocked by dexpreopt because a `service-*` / `framework-*` jar is
# registered in PRODUCT_APEX_BOOT_JARS / PRODUCT_APEX_SYSTEM_SERVER_JARS by
# build/make/target/product/default_art_config.mk. A naive `PRODUCT_PACKAGES`
# filter-out (as attempted by Wave C) leaves the BCP entries orphaned, and
# dex_preopt_check.mk hard-fails the build because the corresponding
# apex@<apex>@javalib@<jar>.jar@classes.{odex,vdex} artifacts are missing.
#
# STRATEGY (per Architect scope-lock T-APEX-BCP-WAVE):
# Do NOT edit build/make/target/product/default_art_config.mk or
# base_system.mk directly — those are AOSP upstream files and direct edits
# create merge-conflict liability and violate Law 11 (Reversibility). Instead,
# this overlay runs a 3-stage filter-out AFTER the upstream files are
# inherited, so the BCP lists and PRODUCT_PACKAGES are filtered in lockstep
# and no orphaned dexpreopt entry remains. Same late-filter pattern as
# apps-excised.mk:686 / :725.
#
# REVERSIBILITY (Law 11): to revert, delete this file's inclusion line in
# guardtalk-feature-excised.mk. No upstream build/make/ files are touched.
# Idempotent (Law 8): re-applying the filter-out is a harmless no-op.
#
# RISK: com.android.adservices removal also drops the bundled SdkSandbox
# (out/target/product/tokay/apex/com.android.adservices/app/SdkSandbox@*).
# com.android.healthfitness removal also drops HealthConnect controller.
# com.android.ondevicepersonalization removal also drops FederatedCompute.
# Runtime smoke test MANDATORY post-flash (Q-APEX-BCP) per Architect brief:
# verify boot completes, system_server does not crash on missing service
# jars, and no Settings/SystemUI entry point references the removed features.
#
# Investigation (2026-07-02):
#   - Verified the 3 APEX are NOT in PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS
#     (that list contains only bt, devicelock, statsd, scheduling, tethering,
#      uwb, wifi, profiling, ranging, uprobestats — see default_art_config.mk
#      :218-225). No filter required for that list.
#   - Verified NO dexpreopt.cfg / dexpreopt*.mk files exist in build/make/
#     (only default_art_config.mk + runtime_libart.mk reference ART config).
#   - Verified the 3 APEX appear ONLY in:
#       build/make/target/product/default_art_config.mk:65,66,72,80,175,176,
#       180,182
#       build/make/target/product/base_system.mk:54,61,68
#     No other build/make/ references exist.

# ---------------------------------------------------------------------------
# BOOT-LOOP INCIDENT (2026-07-04, tokay userdebug) — BCP excision DISABLED.
# ---------------------------------------------------------------------------
# The three filter-out stages below were neutralized because removing the
# framework-* / service-* jars from the boot classpath caused a fatal
# java.lang.NoClassDefFoundError in android.app.SystemServiceRegistry during
# Zygote preload. SystemServiceRegistry.java has hard imports of
#   android.adservices.AdServicesFrameworkInitializer
#   android.app.sdksandbox.SdkSandboxManagerFrameworkInitializer
#   android.ondevicepersonalization.OnDevicePersonalizationFrameworkInitializer
# and calls SdkSandboxManagerFrameworkInitializer.registerServiceWrappers().
# Those classes live in the very framework-*.jar files the filter removed,
# so Zygote died on preload → init restarted zygote → boot loop.
# Secondary symptoms (android.frameworks.stats.IStats/default not found,
# pktrouter crashes) were noise from system_server never coming up.
#
# The original (working) design documented in guardtalk-feature-excised.mk
# keeps these three APEX *dormant* by removing only the feature-permission
# XMLs, leaving the BCP entries intact. Reverting to that design.
#
# To re-enable full BCP excision, you MUST first patch
# frameworks/base/core/java/android/app/SystemServiceRegistry.java (and any
# other framework references to AdServicesFrameworkInitializer /
# SdkSandboxManagerFrameworkInitializer / OnDevicePersonalizationFrameworkInitializer)
# to be absent or optional, then re-enable the three stages below.
# ---------------------------------------------------------------------------

# 1. Remove framework-* jars from PRODUCT_APEX_BOOT_JARS.  [DISABLED — see note above]
# $(eval PRODUCT_APEX_BOOT_JARS := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_APEX_BOOT_JARS))
# PRODUCT_APEX_BOOT_JARS := $(filter-out \
#     com.android.adservices:framework-adservices \
#     com.android.adservices:framework-sdksandbox \
#     com.android.healthfitness:framework-healthfitness \
#     com.android.ondevicepersonalization:framework-ondevicepersonalization \
#     ,$(PRODUCT_APEX_BOOT_JARS))
# $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_APEX_BOOT_JARS := $(PRODUCT_APEX_BOOT_JARS))

# 2. Remove service-* jars from PRODUCT_APEX_SYSTEM_SERVER_JARS.  [DISABLED — see note above]
# $(eval PRODUCT_APEX_SYSTEM_SERVER_JARS := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_APEX_SYSTEM_SERVER_JARS))
# PRODUCT_APEX_SYSTEM_SERVER_JARS := $(filter-out \
#     com.android.adservices:service-adservices \
#     com.android.adservices:service-sdksandbox \
#     com.android.healthfitness:service-healthfitness \
#     com.android.ondevicepersonalization:service-ondevicepersonalization \
#     ,$(PRODUCT_APEX_SYSTEM_SERVER_JARS))
# $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_APEX_SYSTEM_SERVER_JARS := $(PRODUCT_APEX_SYSTEM_SERVER_JARS))

# 3. Remove the APEX modules themselves from PRODUCT_PACKAGES.  [DISABLED — see note above]
#    Keeping the APEX in PRODUCT_PACKAGES so their framework-*/service-* jars
#    ship on the boot classpath (required by SystemServiceRegistry).
# PRODUCT_PACKAGES := $(filter-out \
#     com.android.adservices \
#     com.android.healthfitness \
#     com.android.ondevicepersonalization \
#     ,$(PRODUCT_PACKAGES))
