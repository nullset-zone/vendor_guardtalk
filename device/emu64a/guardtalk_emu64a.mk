#
# GuardTalkOS — ARM64 Goldfish emulator product.
# Inherits sdk_phone64_arm64 (same ABI as tokay) plus GuardTalk apps/overlays/native libs.
# Does NOT replace tokay device images — use to validate userspace boot and GuardTalk packages.
#
$(call inherit-product, device/generic/goldfish/64bitonly/product/sdk_phone64_arm64.mk)
$(call inherit-product, vendor/guardtalk/device/emu64a/guardtalk-emu-layer.mk)

PRODUCT_NAME := guardtalk_emu64a
PRODUCT_DEVICE := emu64a
PRODUCT_BRAND := GuardTalk
PRODUCT_MODEL := GuardTalk Emulator (arm64)
