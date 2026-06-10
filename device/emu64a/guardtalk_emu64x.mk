#
# GuardTalkOS — x86_64 Goldfish emulator (headless Linux servers without KVM/arm64).
# Same GuardTalk userspace as guardtalk_emu64a; runs natively on amd64 hosts.
#
$(call inherit-product, device/generic/goldfish/64bitonly/product/sdk_phone64_x86_64.mk)
$(call inherit-product, vendor/guardtalk/device/emu64a/guardtalk-emu-layer.mk)

PRODUCT_NAME := guardtalk_emu64x
PRODUCT_DEVICE := emu64x
PRODUCT_BRAND := GuardTalk
PRODUCT_MODEL := GuardTalk Emulator (x86_64)
