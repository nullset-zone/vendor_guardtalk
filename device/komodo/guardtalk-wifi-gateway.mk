# GuardTalkOS komodo gateway-only Wi-Fi (T-REMEDIATE-B4-WIFI-GW, item 21).
#
# LIVE: included from vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk
# (late radio-excised pass). Fail-closed SSID whitelist + device overlay.
# Procedure (SOP / QR-only lockdown) is not this mechanism.
#
# Layers:
#   1. Framework RRO (GuardTalkFrameworksBaseOverlay): first-user restrictions
#      no_add_wifi_config / no_wifi_tethering / no_wifi_direct. Settings cannot
#      add or tap-connect non-saved SSIDs. Privileged SUW/GuardTalkConfig may
#      still add the signed GMP SSID (WifiServiceImpl privileged bypass of
#      DISALLOW_ADD_WIFI_CONFIG only).
#   2. Vendor wpa_supplicant overlay: filter_ssids=1; HS20/interworking off.
#   3. Vendor SSID list: empty = fail-closed (no matching user networks).
#
# Do not open Wi-Fi. Do not re-enable RIL/BT/NFC. No secrets in this tree.
# Not device-fixed; PASS HOLD remains.

ifeq ($(GUARDTALK_WIFI_GATEWAY_MK),)
GUARDTALK_WIFI_GATEWAY_MK := true

# Drop Pixel overlay so this dest is unique (p2p_supplicant_overlay.conf kept).
PRODUCT_COPY_FILES := $(filter-out \
    vendor/google_devices/komodo/proprietary/vendor/etc/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf, \
    $(PRODUCT_COPY_FILES))

PRODUCT_COPY_FILES += \
    vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    vendor/guardtalk/device/komodo/wifi/guardtalk_gateway_ssids:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/guardtalk_gateway_ssids \
    vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.guardtalk.wifi-gateway.rc

# T-REMEDIATE-B6-PROP-REACHABILITY: ro.* policy flags -> system/build.prop.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.guardtalk.wifi.gateway_only=1 \
    ro.guardtalk.wifi.fail_closed=1 \
    ro.guardtalk.wifi.ssid_allowlist_path=/vendor/etc/wifi/guardtalk_gateway_ssids

endif
