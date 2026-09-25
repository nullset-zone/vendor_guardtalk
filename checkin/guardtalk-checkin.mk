# T-REMEDIATE-B4-CHECKIN (item 20): 12 h seizure check-in client.
#
# Ships GuardTalkCheckin as a platform-signed system_ext priv-app. The
# PRODUCT_SOONG_NAMESPACES entry is required because vendor/guardtalk/apps/
# is not a default Soong namespace (same contract as GuardTalkValidator).
#
# Included from radio-excised/product-config-late.mk so the package lands on
# every GuardTalkOS product (GUARDTALK_RADIO_EXCISED). No secrets, no onion
# address, and no public C2 URL are baked here.

PRODUCT_PACKAGES += GuardTalkCheckin
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/apps/GuardTalkCheckin
