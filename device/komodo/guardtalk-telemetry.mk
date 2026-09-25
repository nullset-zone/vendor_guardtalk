# GuardTalkOS komodo telemetry kill (T-REMEDIATE-B2-TELEMETRY).
#
# LIVE: included from vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk
# (late radio-excised pass). Do not PRODUCT_PROPERTY_OVERRIDES keys that already
# exist in vendor/google_devices/komodo/sysprop/vendor.prop — post_process_props.py
# errors on duplicate assignments with different values. Those defaults are
# patched in vendor.prop (REGEN_HOOKS) and re-asserted by
# init.guardtalk.telemetry.rc (vendor_init, post-fs-data).
#
# logd.logpersistd.enable is NOT in vendor.prop, so PRODUCT_PROPERTY_OVERRIDES
# is safe. persist.logd.logpersistd is cleared in init.guardtalk.telemetry.rc
# (empty PRODUCT_PROPERTY_OVERRIDES values are fragile). logpersist.start /
# logcatd are Pixel PRODUCT_PACKAGES on every variant; drop them on production
# user only (sidecar may keep the tools).
#
# Does not re-enable RIL. Does not touch apps-excised.mk or
# init.guardtalk.hardening.rc.

PRODUCT_COPY_FILES += \
    vendor/guardtalk/device/komodo/init.guardtalk.telemetry.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.guardtalk.telemetry.rc

PRODUCT_PROPERTY_OVERRIDES += \
    logd.logpersistd.enable=false

# T-REMEDIATE-B6-PROP-REACHABILITY: ro.* policy flag -> system/build.prop
# (PRODUCT_PROPERTY_OVERRIDES would land it in vendor/build.prop unlabelled).
PRODUCT_SYSTEM_PROPERTIES += \
    ro.guardtalk.telemetry_persist_disabled=1

ifeq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_PACKAGES := $(filter-out logpersist.start logcatd,$(PRODUCT_PACKAGES))
endif
