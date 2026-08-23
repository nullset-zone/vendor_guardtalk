# GuardTalkOS product base — same as adevtool common minus telephony fragments.
# Optional for rango (laguna): adevtool device.mk inherits laguna/product-common
# which includes common/product-common.mk. Radio excision for packages /
# copy-files is handled by the late include of guardtalk-radio-excised.mk.
# Keep this file for parity with the tokay/akita recipe / future adevtool hook.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_vendor.mk)
