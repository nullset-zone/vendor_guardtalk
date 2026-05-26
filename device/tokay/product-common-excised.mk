# GuardTalkOS product base — same as adevtool common minus telephony fragments.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_vendor.mk)
