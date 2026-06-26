# T-W2-I4-BT / T-BT-FULL — 5-layer graceful excision of the Bluetooth HAL.
#
# Scope: Broadcom BCM4390 Bluetooth HAL (android.hardware.bluetooth-service.bcmbtlinux),
# the Bluetooth audio HAL (android.hardware.bluetooth.audio-impl + NDK/HIDL stubs),
# the BT finder/ranging stubs, the two feature-permission prebuilt XMLs
# (android.hardware.bluetooth.prebuilt.xml + android.hardware.bluetooth_le.prebuilt.xml),
# the Google BT extension NDK stubs (vendor.google.bluetooth_ext-V1/V4-ndk),
# the channel-avoidance HIDL (hardware.google.bluetooth.bt_channel_avoidance@1.0),
# the BluetoothMidiService system app, the BT init .rc
# (android.hardware.bluetooth-service.bcmbtlinux.rc), and the BT-side vendor
# config copies (bluetooth_power_limits*.csv, bluetooth/*.conf, bluetooth/*.json,
# aoc/*bluetooth*.pb).
#
# Kernel layer: the nitrous BT power/rfkill driver (BCM4390) is blocked at the
# vendor_dlkm.modules.blocklist level — see
# vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist (which is wired
# via BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE override set in
# vendor/guardtalk/device/tokay/BoardConfig-excised-late.mk). The GKI
# bluetooth.ko / hci_uart.ko / btbcm.ko remain in system_dlkm but are harmless
# without nitrous (no rfkill power-on, no HCI transport).
#
# Pattern: same late product-config filter-out as apps-excised.mk, nfc-excised.mk,
# fp-excised.mk, and loc-excised.mk. Idempotent and order-independent. Runs after
# all inherit-product merges (via product-config-late.mk ->
# guardtalk-feature-excised.mk), so PRODUCT_PACKAGES / PRODUCT_COPY_FILES are
# fully populated.
#
# CRITICAL INVARIANT: The AOSP/mainline Bluetooth stack (com.android.bluetooth /
# com.google.android.bluetooth) is delivered via a mainline module (APEX,
# com.android.bt) and is therefore out of reach of a PRODUCT_PACKAGES filter.
# Grace is achieved by dropping the feature-permission prebuilts so
# hasSystemFeature(FEATURE_BLUETOOTH) / FEATURE_BLUETOOTH_LE return false. The
# mainline BT stack keys off these features and stays dormant; Settings and
# SystemUI hide all Bluetooth entry points at runtime. Verified gates:
#   - Settings: BluetoothdeviceKeywordController / BluetoothMasterSwitchController
#     check PackageManager.FEATURE_BLUETOOTH and return UNSUPPORTED_ON_DEVICE
#     when absent.
#   - SystemUI: BluetoothTile.isAvailable() returns false when
#     FEATURE_BLUETOOTH is absent.
#
# CRITICAL INVARIANT: ro.build.fingerprint (a build property) is UNRELATED to
# the Bluetooth HAL. No Bluetooth service lines need filtering from
# init.tokay.rc or init.zumapro.board.rc — the BT HAL service .rc
# (android.hardware.bluetooth-service.bcmbtlinux.rc) is delivered via
# PRODUCT_COPY_FILES (tokay.mk:1660) and is filtered in Layer 4 below.
#
# Out of scope (MUST NOT touch in this increment): NFC, Location, Fingerprint,
# Face biometrics.

# ---------------------------------------------------------------------------
# Layer 1 — Package layer: Bluetooth HAL packages, stubs, apps, and overlays.
# ---------------------------------------------------------------------------
GUARDTALK_BT_PACKAGES := \
    android.hardware.bluetooth-V1-ndk.vendor \
    android.hardware.bluetooth.audio-V5-ndk.vendor \
    android.hardware.bluetooth.audio-impl \
    android.hardware.bluetooth.audio@2.0.vendor \
    android.hardware.bluetooth.audio@2.1.vendor \
    android.hardware.bluetooth.finder-V1-ndk.vendor \
    android.hardware.bluetooth.ranging-V1-ndk.vendor \
    android.hardware.bluetooth.prebuilt.xml \
    android.hardware.bluetooth_le.prebuilt.xml \
    android.hardware.bluetooth-service.bcmbtlinux \
    hardware.google.bluetooth.bt_channel_avoidance@1.0 \
    vendor.google.bluetooth_ext-V1-ndk \
    vendor.google.bluetooth_ext-V4-ndk \
    BluetoothMidiService \
    libbluetooth_audio_session_aidl

# Defence-in-depth: catch any other Bluetooth-named packages that a future
# adevtool regen might slide into PRODUCT_PACKAGES. Scoped to BT-only tokens
# so it cannot accidentally hit unrelated packages.
define _gt-bt-package-drop
$(or \
  $(findstring android.hardware.bluetooth,$(1)), \
  $(findstring vendor.google.bluetooth_ext,$(1)), \
  $(findstring hardware.google.bluetooth,$(1)), \
  $(findstring bluetooth-service,$(1)), \
  $(findstring .bluetooth.prebuilt.xml,$(1)), \
  $(findstring BluetoothMidiService,$(1)), \
  $(findstring libbluetooth_audio,$(1)))
endef

_gt_bt_filtered_product_packages :=
$(foreach p,$(filter-out $(GUARDTALK_BT_PACKAGES),$(PRODUCT_PACKAGES)),\
  $(if $(call _gt-bt-package-drop,$(p)),,\
    $(eval _gt_bt_filtered_product_packages += $(p))))
PRODUCT_PACKAGES := $(strip $(_gt_bt_filtered_product_packages))

# Defence-in-depth: strip Bluetooth-related config copies from
# PRODUCT_COPY_FILES. These feed only the removed Broadcom BT HAL:
#   - bluetooth_power_limits*.csv (regulatory power tables)
#   - bluetooth/*.conf, bluetooth/*.json (HAL-side configs)
#   - aoc/*bluetooth*.pb (audio offload config for BT headsets)
#   - init/android.hardware.bluetooth-service.bcmbtlinux.rc (HAL service .rc)
define _gt-bt-copy-file-drop
$(or \
  $(findstring bluetooth_power_limits,$(1)), \
  $(findstring /bluetooth/,$(1)), \
  $(findstring bluetooth-service.bcmbtlinux.rc,$(1)), \
  $(findstring downlink_bluetooth_headset_config.pb,$(1)), \
  $(findstring uplink_bluetooth_headset_aec_off_config.pb,$(1)), \
  $(findstring uplink_bluetooth_headset_aec_on_config.pb,$(1)), \
  $(findstring BLUETOOTH.dat,$(1)))
endef

_gt_bt_filtered_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-bt-copy-file-drop,$(cf)),,\
    $(eval _gt_bt_filtered_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_bt_filtered_copy_files))

# ---------------------------------------------------------------------------
# Layer 2 — Feature XML layer: Bluetooth feature declarations.
# ---------------------------------------------------------------------------
# The two android.hardware.bluetooth*.prebuilt.xml modules are the
# feature-permission prebuilts that declare PackageManager.FEATURE_BLUETOOTH
# and FEATURE_BLUETOOTH_LE to the framework. Removing them from
# PRODUCT_PACKAGES (Layer 1 above) causes hasSystemFeature() to return false
# for both Bluetooth features, which is what gracefully hides Bluetooth UI in
# Settings, SystemUI, and the mainline Bluetooth app. No separate copy-files
# filter is needed because these prebuilts are delivered as PRODUCT_PACKAGES
# modules, not PRODUCT_COPY_FILES entries.

# ---------------------------------------------------------------------------
# Layer 3 — VINTF fragment layer: remove Bluetooth HAL from vendor manifest.
# ---------------------------------------------------------------------------
# The Broadcom BT HAL declares android.hardware.bluetooth IBluetooth/default
# to the vendor manifest via its VINTF fragment. The fragment is wired as
# vintf_fragment_modules on the android.hardware.bluetooth-service.bcmbtlinux
# package. Dropping that package (Layer 1 above) removes the HAL declaration
# so libvintf compatibility checks no longer expect a Bluetooth HAL to be
# running. No adevtool_vintf_fragment_vendor_*bluetooth* fragment exists in
# vendor/google_devices/tokay/vintf/vendor/manifest/ (verified), so no
# DEVICE_MANIFEST_FILE filter is required here.

# ---------------------------------------------------------------------------
# Layer 4 — init .rc layer: remove Bluetooth service init lines.
# ---------------------------------------------------------------------------
# The BT HAL service is started by
# android.hardware.bluetooth-service.bcmbtlinux.rc:
#     service bluetooth_hal /vendor/bin/hw/android.hardware.bluetooth-service.bcmbtlinux
#         class hal
#         user bluetooth
#         group bluetooth
# This .rc is delivered via PRODUCT_COPY_FILES (tokay.mk:1660) and is filtered
# from PRODUCT_COPY_FILES in Layer 1 above (the _gt-bt-copy-file-drop macro
# matches "bluetooth-service.bcmbtlinux.rc"). With the .rc gone, init never
# loads the Bluetooth service definition, so the HAL never starts.
#
# NOTE: init.tokay.rc and init.zumapro.board.rc contain no Bluetooth HAL
# service definitions (verified at baseline). No filtered copies of these init
# files are required (Law 6: Minimal Footprint).

# ---------------------------------------------------------------------------
# Layer 5 — Kernel module layer: block nitrous (BT power/rfkill driver).
# ---------------------------------------------------------------------------
# The BCM4390 BT power/rfkill kernel driver (nitrous.ko) is blocked at the
# vendor_dlkm.modules.blocklist level. The GuardTalk blocklist
# (vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist) adds
# `blocklist nitrous` to the upstream baseline and is wired into the build via
# the BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE override set in
# vendor/guardtalk/device/tokay/BoardConfig-excised-late.mk (which runs AFTER
# vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk:45
# re-sets the makevar, so the override sticks).
#
# With nitrous blocked, the BT driver never loads in the common bulk modprobe
# pass (init.common.cfg: `modprobe|vendor -b *` honors the blocklist). nitrous
# is NOT in init.insmod.tokay.cfg, so the device-specific no-blocklist pass
# never loads it either. The GKI bluetooth.ko / hci_uart.ko / btbcm.ko remain
# in system_dlkm but are harmless without nitrous (no rfkill power-on, no HCI
# transport, no UART device).
#
# No PRODUCT_PACKAGES / PRODUCT_COPY_FILES action is needed in this layer —
# the blocklist file and its BoardConfig wiring are the mechanism. This
# section documents the kernel-side half of the BT excision for completeness.

# ---------------------------------------------------------------------------
# Layer 6 — Framework grace layer: Settings + SystemUI overlays.
# ---------------------------------------------------------------------------
# Wired in guardtalk-feature-excised.mk -> feature-overlays.mk. The Settings +
# FrameworksBase overlays (wired via radio-excised/telephony-features.mk) and
# the SystemUI overlay (wired via feature-overlays.mk) provide defence-in-depth
# so that even if a stale feature flag lingers, Settings and SystemUI treat
# Bluetooth as unsupported. The real hiding is the runtime
# hasSystemFeature() check (Layer 2):
#   - Settings: Bluetooth-related controllers gate on
#     PackageManager.FEATURE_BLUETOOTH and return UNSUPPORTED_ON_DEVICE when
#     absent.
#   - SystemUI: BluetoothTile.isAvailable() returns false when
#     FEATURE_BLUETOOTH is absent; the QS tile stock list also strips the
#     `bt` token via the GuardTalk SystemUI overlay.
