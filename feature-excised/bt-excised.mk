# T-W2-I4-BT / T-BT-FULL — 5-layer graceful excision of the Bluetooth HAL.
#
# T-EXCISE-BT-SOCKET-LIB-KEEP (2026-11-07, P0) — TWO CORRECTIONS TO THIS FILE.
# The Stallion handset boot-looped on the GuardTalk animation because this file
# removed libraries that HALs the excision KEEPS link against. Both are fixed
# below; the measured detail is in
# .agent-comm/evidence/T-EXCISE-BT-SOCKET-LIB-KEEP/.
#
#   (1) OVER-MATCH: the Layer-1 defence-in-depth macro used
#       `$(findstring android.hardware.bluetooth,$(1))`. `findstring` is a
#       SUBSTRING test, so it also matched `android.hardware.bluetooth.socket-V1-ndk`
#       — the AIDL glue library for the CHRE context-hub socket API, not a
#       Bluetooth feature. `android.hardware.contexthub-service.generic` (which
#       this excision KEEPS, and still declares in
#       vendor/etc/vintf/manifest/android.hardware.contexthub-service.generic.xml)
#       has `NEEDED android.hardware.bluetooth.socket-V1-ndk.so`. With the .so
#       gone the contexthub HAL could not link, never published
#       `android.frameworks.sensorservice.ISensorManager`, so `system_server`
#       blocked in SystemSensorManager.nativeCreate and Watchdog killed it. The
#       macro is now exact-module matching plus a fail-closed keep-list guard.
#
#   (2) REVERSAL: the BT-audio libraries are NOT excised any more. The *kept*
#       vendor audio HAL is a prebuilt binary whose DT_NEEDED includes them, so
#       dropping them made `vendor.audio-hal-aidl` crash-loop too ([restarting]
#       28x on device). See the T-EXCISE-BT-SOCKET-LIB-KEEP note in Layer 1.
#
# Scope: Broadcom BCM4390 Bluetooth HAL (android.hardware.bluetooth-service.bcmbtlinux),
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
# vendor/guardtalk/device/tokay/BoardConfig-excised-late.mk).
#
# LAW 7 CORRECTION (T-EXCISE-CLAIM-HONESTY-RESIDUAL, 2026-09-26): the former
# statement here — "the GKI bluetooth.ko / hci_uart.ko / btbcm.ko remain in
# system_dlkm but are harmless without nitrous" — is NOT supported. The shipped
# stamps carry 8 BT/NFC GKI modules (bluetooth.ko, hci_uart.ko, btbcm.ko,
# btqca.ko, btsdio.ko, rfcomm.ko, hidp.ko, nfc.ko) in system_dlkm `modules.load`
# with 0 matching `modules.blocklist` entries, so they LOAD AT BOOT — Tier C
# 13/13 (C-B1; E-14; A-EXCISE-AIRGAP-MATRIX). The vendor_dlkm nitrous blocklist
# does not cover system_dlkm. T-EXCISE-GKI-BT-MODULES has since added those 8
# system_dlkm blocklist entries at source level (13/13), but no re-stamp has run:
# the shipped `-latest` stamps are unchanged.
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
# NOTE (T-EXCISE-BT-SOCKET-LIB-KEEP): the BT-**audio** module names are NOT in
# this list any more. They were, and that broke a HAL this excision keeps.
#
# The shipped vendor audio HAL is the prebuilt
#   vendor/google_devices/stallion/proprietary/vendor/bin/hw/
#       android.hardware.audio.service-aidl.aoc
# and its ELF DT_NEEDED (readelf -d, measured) includes all four:
#   android.hardware.bluetooth.audio-V5-ndk.so
#   android.hardware.bluetooth.audio-impl.so
#   libbluetooth_audio_session_aidl.so
#   libaudioserviceexampleimpl.so
# plus android.hardware.bluetooth.audio@2.0/@2.1, which
# libbluetooth_audio_session_aidl links in turn. DT_NEEDED is resolved by the
# dynamic linker at process start, before any code runs, so removing them does
# not disable BT audio — it makes the *whole* audio HAL fail to exec:
#   F linker : CANNOT LINK EXECUTABLE ".../android.hardware.audio.service-aidl.aoc":
#              library "libbluetooth_audio_session_aidl.so" not found: needed by
#              main executable
# On the Stallion handset `vendor.audio-hal-aidl` sat in [restarting] and
# retried 28 times. Audio is not a BT feature: the voice filter, the mic path
# and every non-BT stream go through this same HAL.
#
# Decision on record (T-EXCISE-BT-SOCKET-LIB-KEEP): restore the libs and keep
# the audio HAL working (option (a)). The BT air-gap does not depend on them —
# it is enforced by the feature-permission prebuilts below (hasSystemFeature
# returns false), the BT HAL .rc drop, the BT-free VINTF manifest, and the
# nitrous/GKI module blocklists. These libraries are inert glue with no BT radio
# behind them. The prior T-EXCISE-BT-AUDIO-HAL removal is therefore REVERSED;
# its evidence (A-EXCISE-BT F-003) is preserved in
# .agent-comm/evidence/T-EXCISE-BT-SOCKET-LIB-KEEP/.
#
# Residual (Law 7, stated not hidden): installing `android.hardware.bluetooth.audio-impl`
# re-installs its `vintf_fragments: ["bluetooth_audio.xml"]`, which declares
# android.hardware.bluetooth.audio v5 IBluetoothAudioProviderFactory/default.
# That declaration is now *accurate* (the audio HAL registers that factory from
# ModuleBluetooth's constructor), but it is a `android.hardware.bluetooth.*` name
# and the BT VINTF gate forbids that class. See the report for the follow-up.
GUARDTALK_BT_PACKAGES := \
    android.hardware.bluetooth-V1-ndk.vendor \
    android.hardware.bluetooth.finder-V1-ndk.vendor \
    android.hardware.bluetooth.ranging-V1-ndk.vendor \
    android.hardware.bluetooth.prebuilt.xml \
    android.hardware.bluetooth_le.prebuilt.xml \
    android.hardware.bluetooth-service.bcmbtlinux \
    hardware.google.bluetooth.bt_channel_avoidance@1.0 \
    vendor.google.bluetooth_ext-V1-ndk \
    vendor.google.bluetooth_ext-V4-ndk \
    BluetoothMidiService

# Modules that LOOK like Bluetooth but must NEVER be dropped: they are
# dependencies of HALs this excision keeps. Checked before every pattern in
# _gt-bt-package-drop, so a future edit cannot silently re-drop them.
#
#   android.hardware.bluetooth.socket-V1-ndk.vendor
#       AIDL glue for the CHRE context-hub socket API
#       (hardware/interfaces/bluetooth/socket/aidl/Android.bp, `frozen: true`,
#       imports android.hardware.contexthub-V4). NOT a Bluetooth feature.
#       `android.hardware.contexthub-service.generic` — kept, and still declared
#       in vendor/etc/vintf/manifest/android.hardware.contexthub-service.generic.xml
#       — has `NEEDED android.hardware.bluetooth.socket-V1-ndk.so`. Dropping it
#       stopped contexthub from exec'ing, so ISensorManager never published,
#       system_server blocked in SystemSensorManager.nativeCreate, and Watchdog
#       killed the system process at 67 s → zygote exit → boot loop.
#   android.hardware.bluetooth.audio-*, libbluetooth_audio_session_aidl,
#   libaudioserviceexampleimpl
#       DT_NEEDED of the kept vendor audio HAL (see the note above).
GUARDTALK_BT_KEEP := \
    android.hardware.bluetooth.socket-V1-ndk.vendor \
    android.hardware.bluetooth.audio-V5-ndk.vendor \
    android.hardware.bluetooth.audio-impl \
    android.hardware.bluetooth.audio@2.0.vendor \
    android.hardware.bluetooth.audio@2.1.vendor \
    libbluetooth_audio_session_aidl \
    libaudioserviceexampleimpl

# Defence-in-depth: catch any other Bluetooth-named packages that a future
# adevtool regen might slide into PRODUCT_PACKAGES.
#
# T-EXCISE-BT-SOCKET-LIB-KEEP (P0): this macro used to be
#     $(or $(findstring android.hardware.bluetooth,$(1)), ...)
# and `findstring` is a SUBSTRING test, so the single token
# `android.hardware.bluetooth` also matched
# `android.hardware.bluetooth.socket-V1-ndk`. That is how a non-Bluetooth
# library got excised and the device stopped booting. `findstring` on a family
# prefix cannot express "this family, but not these members", so the patterns
# are now EXACT module names / exact prefixes, and the keep-list above is
# removed first and short-circuits.
#
# The genuine BT feature set this still excises (measured across
# vendor/google_devices/*/*.mk):
#   android.hardware.bluetooth-V1-ndk[.vendor]      <- the BT AIDL interface
#   android.hardware.bluetooth@1.0/@1.1[.vendor]    <- HIDL BT interfaces
#   android.hardware.bluetooth@1.1-service.synabtlinux (synabt linux BT HAL)
#   android.hardware.bluetooth.finder-V1-ndk[.vendor]
#   android.hardware.bluetooth.ranging-V{1,2}-ndk[.vendor]
#   android.hardware.bluetooth.prebuilt.xml, android.hardware.bluetooth_le.prebuilt.xml
#   android.hardware.bluetooth-service.bcmbtlinux   <- BCM4390 BT HAL binary
#   hardware.google.bluetooth.{bt_channel_avoidance,sar}@*
#   vendor.google.bluetooth_ext-V{1,3,4}-ndk
#   BluetoothMidiService
#   libbluetooth_audio_session                      <- HIDL-era session lib (no kept consumer)
# Note `android.hardware.bluetooth.audio@2.0` is deliberately NOT matched by the
# `android.hardware.bluetooth@%` pattern — the `.audio` segment differs — and
# `libbluetooth_audio_session` is an EXACT filter, so it does not catch
# `libbluetooth_audio_session_aidl`.
#
# MECHANISM NOTE: this is a LIST + $(filter), not $(or) of $(filter)s. Each line
# of a `define` block that uses backslash continuation contributes a leading
# space to the value, so an `$(or <ws>$(filter ...), <ws>$(filter ...))` chain
# degenerates and matches every input — i.e. that pattern form silently turns
# into "drop everything". The list form has no such failure mode, and the
# fail-closed checks below prove it stays correct.
GT_BT_DROP_PATTERNS := \
    android.hardware.bluetooth-V1-ndk% \
    android.hardware.bluetooth@% \
    android.hardware.bluetooth.finder-% \
    android.hardware.bluetooth.ranging-% \
    android.hardware.bluetooth.prebuilt.xml \
    android.hardware.bluetooth_le.prebuilt.xml \
    android.hardware.bluetooth-service.% \
    vendor.google.bluetooth_ext-% \
    hardware.google.bluetooth.% \
    BluetoothMidiService \
    libbluetooth_audio_session

# Raw pattern test, WITHOUT the keep-list bypass. Exists so the guard below can
# ask "would the patterns alone drop a module we must keep?" — that question
# cannot be asked of _gt-bt-package-drop, which subtracts the keep-list first.
define _gt-bt-pattern-hit
$(strip $(filter $(GT_BT_DROP_PATTERNS),$(1)))
endef

define _gt-bt-package-drop
$(call _gt-bt-pattern-hit,$(filter-out $(GUARDTALK_BT_KEEP),$(1)))
endef

# Fail-closed (Law 3). The keep-list and the drop patterns are two halves of one
# rule: a future edit that widens a pattern over a keep-listed module would bring
# the contexthub boot loop back, silently. Refuse to configure instead. Both
# checks are static — they do not depend on what the product happens to list.
#
# (a) no keep-listed name may appear in the explicit drop list;
_gt_bt_keep_dropped := $(filter $(GUARDTALK_BT_KEEP),$(GUARDTALK_BT_PACKAGES))
ifneq ($(_gt_bt_keep_dropped),)
  $(error T-EXCISE-BT-SOCKET-LIB-KEEP: GUARDTALK_BT_PACKAGES contains a \
    keep-listed module ($(_gt_bt_keep_dropped)); its HAL is kept and would \
    fail to link)
endif
#
# (b) no drop pattern may match a keep-listed name. Uses the RAW pattern test, so
# the keep-list cannot hide a regression here.
_gt_bt_keep_pattern_hits := $(strip $(foreach k,$(GUARDTALK_BT_KEEP),\
    $(call _gt-bt-pattern-hit,$(k))))
ifneq ($(_gt_bt_keep_pattern_hits),)
  $(error T-EXCISE-BT-SOCKET-LIB-KEEP: GT_BT_DROP_PATTERNS matches keep-listed \
    module(s) ($(_gt_bt_keep_pattern_hits)); tighten the pattern — this library \
    is linked by a HAL the excision keeps)
endif

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
# package. Dropping that package (Layer 1 above) removes that *fragment*
# declaration only.
#
# LAW 7 CORRECTION (T-EXCISE-CLAIM-HONESTY-RESIDUAL, 2026-09-26): the former
# claim here — "Dropping that package … removes the HAL declaration so libvintf
# compatibility checks no longer expect a Bluetooth HAL to be running … so no
# DEVICE_MANIFEST_FILE filter is required" — was FALSE. The 4 BT HALs
# (android.hardware.bluetooth IBluetoothHci/default, android.hardware.bluetooth.finder,
# android.hardware.bluetooth.ranging, vendor.google.bluetooth_ext) were declared
# INLINE in the shipped *main* vendor manifest on 13/13, not only via the package
# fragment; dropping the package does not remove them (H-B1; D4; A-EXCISE-BT). A
# DEVICE_MANIFEST_FILE swap IS required. `vintf/vendor_manifest_no_bt*.xml` was
# unwired at the time; T-EXCISE-BT-VINTF-NOBT has since wired it via
# radio-excised/vintf-excised.mk at source level, so a re-stamp would carry a
# BT-free main manifest. Shipped stamps are unchanged (pre-re-stamp).

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
# With nitrous blocked, the nitrous driver does not load in the common bulk
# modprobe pass (init.common.cfg: `modprobe|vendor -b *` honors the blocklist),
# and nitrous is NOT in init.insmod.tokay.cfg, so the device-specific
# no-blocklist pass does not load it either.
#
# LAW 7 CORRECTION (T-EXCISE-CLAIM-HONESTY-RESIDUAL, 2026-09-26): blocking
# nitrous does NOT make the GKI transport modules harmless. They live in
# system_dlkm, a DIFFERENT blocklist file (SystemKernelBlocklistFile), which on
# the shipped stamps carries 0/8 matching entries, so bluetooth.ko/hci_uart.ko/
# btbcm.ko (+ btqca, btsdio, rfcomm, hidp, nfc) LOAD AT BOOT — Tier C 13/13
# (C-B1; E-14). T-EXCISE-GKI-BT-MODULES adds the system_dlkm blocklist at source
# level; pre-re-stamp only.
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
