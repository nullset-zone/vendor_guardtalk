# GuardTalkOS product base — same as adevtool common minus telephony fragments.
# Optional for akita (zuma): adevtool device.mk inherits zuma/product-common.mk
# which only includes common/product-common.mk. Radio excision for packages /
# copy-files is handled by the late include of guardtalk-radio-excised.mk.
# Keep this file for parity with the tokay recipe / future adevtool config hook.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_vendor.mk)
