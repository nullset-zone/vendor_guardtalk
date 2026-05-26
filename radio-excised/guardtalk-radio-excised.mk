# Late product pass — must be `include`d from tokay.mk (not inherit-product).
# inherit-product clears PRODUCT_* in the child node, so filters would see empty lists.
GUARDTALK_RADIO_EXCISED := true
include vendor/guardtalk/radio-excised/remove-packages.mk
include vendor/guardtalk/radio-excised/filter-copy-files.mk
include vendor/guardtalk/radio-excised/vintf-excised.mk

PRODUCT_PROPERTY_OVERRIDES += \
    persist.radio.disabled=1
