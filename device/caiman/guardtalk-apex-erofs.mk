# GuardTalkOS caiman — restore the EROFS APEX payload type (T-EXCISE-CAIMAN-CLEAN-REBUILD).
#
# Mirrors vendor/guardtalk/device/stallion/guardtalk-apex-erofs.mk:
# `build/make/core/product_config.mk` defaults PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE
# to ext4 when TARGET_RELEASE is empty (`lunch caiman-cur-userdebug`), whereas
# EROFS APEX payloads are required for apexd-bootstrap and compact /system/apex.
#
# LAW 11 (Reversibility): deleting this file and the one-line include in
# vendor/google_devices/caiman/caiman.mk restores ext4 behaviour exactly.
PRODUCT_DEFAULT_APEX_PAYLOAD_TYPE := erofs
