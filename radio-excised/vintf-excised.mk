# VINTF: swap full device vendor manifest for no-radio manifest
# (late include + product-config-late).
#
# T-PORT-AKITA-FLASH: tokay's excised manifest declares IGiaService (Pixel 9),
# which is absent from akita's product FCM and fails check_vintf. Select a
# per-device excised manifest.
#
# T-PORT-RANGO-FLASH: tokay's excised manifest inlines media.c2
# IComponentStore/default, but rango also packages
# adevtool_vintf_fragment_vendor_manifest_media_c2_cnm.xml with the same
# FqInstance → check_vintf conflict. Use a rango-derived excised manifest
# (no media.c2; CNM fragment owns default) and preserve foldable
# touchflow_outer.
#
# IMPORTANT: product-config-late.mk re-includes this file after restoring
# DEVICE_MANIFEST_FILE from PRODUCTS.*, but PRODUCT_DEVICE is often unset in
# that context. Fall back to TARGET_DEVICE / TARGET_PRODUCT / INTERNAL_PRODUCT
# so the late pass cannot silently re-apply the tokay excised manifest.
_gt_vintf_device := $(PRODUCT_DEVICE)
ifeq ($(_gt_vintf_device),)
  _gt_vintf_device := $(TARGET_DEVICE)
endif
ifeq ($(_gt_vintf_device),)
  _gt_vintf_device := $(TARGET_PRODUCT)
endif
ifeq ($(_gt_vintf_device),)
  _gt_vintf_device := $(INTERNAL_PRODUCT)
endif

ifneq ($(filter akita,$(_gt_vintf_device)),)
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_akita.xml
else ifneq ($(filter rango,$(_gt_vintf_device)),)
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_rango.xml
else ifneq ($(filter frankel blazer mustang,$(_gt_vintf_device)),)
  # T-PORT-BATCH-B: frankel/blazer/mustang are laguna muzel (non-foldable). The
  # shared tokay-derived excised manifest inlines media.c2 IComponentStore/default,
  # which collides with adevtool_vintf_fragment_vendor_manifest_media_c2_cnm.xml
  # (packaged by these devices) -> check_vintf Conflicting FqInstance. Use a
  # device-derived manifest (same fix as rango, T-PORT-RANGO-FLASH).
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_laguna_muzel.xml
else ifneq ($(filter stallion,$(_gt_vintf_device)),)
  # T-PORT-FINISH-WAVE: stallion is Pixel 10a / zumapro. The tokay-derived
  # excised manifest declares vendor.google.bluetooth_ext @4, which stallion's
  # target-level 202404 FCM does not cover -> check_vintf incompatibility.
  # Use a stallion-derived manifest (same class as T-PORT-AKITA-FLASH).
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_stallion.xml
else ifneq ($(filter shiba,$(_gt_vintf_device)),)
  # T-PORT-FINISH-WAVE: shiba is Pixel 8 / zuma. The tokay-derived excised
  # manifest declares com.google.input.gia.core/IGiaService (@2), absent from
  # shiba's FCM -> check_vintf incompatibility. Use a shiba-derived manifest.
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_shiba.xml
else ifneq ($(filter husky,$(_gt_vintf_device)),)
  # T-PORT-FINISH-WAVE: husky is Pixel 8 Pro / zuma. Same gia.core (@2)
  # incompatibility as shiba -> use a husky-derived manifest.
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_husky.xml
else
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio.xml
endif

# T-EXCISE-BT-VINTF-NOBT (A-EXCISE-BT F-002 / umbrella D4) — swap the selected
# radio-free manifest for its Bluetooth-free counterpart.
#
# The four Bluetooth HAL declarations
#   android.hardware.bluetooth        IBluetoothHci/default
#   android.hardware.bluetooth.finder IBluetoothFinder/default
#   android.hardware.bluetooth.ranging IBluetoothChannelSounding/default
#   vendor.google.bluetooth_ext       IBTChannelAvoidance + IBluetooth{Ccc,Cco,Ewp,Ext,Finder,Sar}/default
# live in the MAIN device manifest selected above, so the radio swap alone left
# them in the shipped /vendor/etc/vintf/manifest.xml on 13/13. The pre-existing
# vendor/guardtalk/vintf/vendor_manifest_no_bt.xml was wired to NO build file.
#
# Each no_bt variant is mechanically the matching no_radio variant minus exactly
# those four <hal> blocks (derivation + proof:
# .agent-comm/evidence/T-EXCISE-BT-VINTF-NOBT/derive_no_bt_manifests.py), so the
# per-device target-level / FCM workarounds above (target-level 202404 on
# stallion, no media.c2 on rango/laguna, no gia.core on akita, ...) are preserved:
#   vendor_manifest_no_radio[_<dev>].xml -> vendor_manifest_no_bt[_<dev>].xml
#
# Gated on the same wave-2 feature-excision flag as feature-excised/bt-excised.mk
# (true on 13/13 via guardtalk-flags.mk) so the manifest swap and the BT package
# drop stay atomic. The $(wildcard) guard fails the build loudly (Law 3) if a
# future radio variant is added without its no_bt counterpart. Reversible
# (Law 11): delete this block to fall back to the radio-only manifest.
ifeq ($(GUARDTALK_FEATURE_EXCISED_WAVE2),true)
  GUARDTALK_VENDOR_MANIFEST_EXCISED := $(strip $(subst \
      vendor_manifest_no_radio,vendor_manifest_no_bt,\
      $(GUARDTALK_VENDOR_MANIFEST_EXCISED)))
  ifeq ($(wildcard $(GUARDTALK_VENDOR_MANIFEST_EXCISED)),)
    $(error T-EXCISE-BT-VINTF-NOBT: BT-free manifest not found: \
        "$(GUARDTALK_VENDOR_MANIFEST_EXCISED)")
  endif
endif

DEVICE_MANIFEST_FILE := $(filter-out \
    vendor/google_devices/tokay/vintf/vendor/manifest.xml \
    vendor/google_devices/akita/vintf/vendor/manifest.xml \
    vendor/google_devices/rango/vintf/vendor/manifest.xml \
    vendor/google_devices/frankel/vintf/vendor/manifest.xml \
    vendor/google_devices/blazer/vintf/vendor/manifest.xml \
    vendor/google_devices/mustang/vintf/vendor/manifest.xml \
    vendor/google_devices/stallion/vintf/vendor/manifest.xml \
    vendor/google_devices/shiba/vintf/vendor/manifest.xml \
    vendor/google_devices/husky/vintf/vendor/manifest.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_akita.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_rango.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_laguna_muzel.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_stallion.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_shiba.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_husky.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt_akita.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt_rango.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt_laguna_muzel.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt_stallion.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt_shiba.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_bt_husky.xml \
    ,$(DEVICE_MANIFEST_FILE))
DEVICE_MANIFEST_FILE += $(GUARDTALK_VENDOR_MANIFEST_EXCISED)

# T-EXCISE-VINTF-DMD (CRIT R-5) — neutralise the surviving `dmd.xml` fragment.
#
# The excised *main* manifest selected above IS wired, but libvintf merges the
# main manifest with EVERY /vendor/etc/vintf/manifest/*.xml fragment at runtime
# (system/libvintf/VintfObject.cpp:282-328). The device-local `dmd.xml` fragment
# (Soong module `adevtool_vintf_fragment_vendor_dmd.xml`, source
# vendor/google_devices/<dev>/vintf/vendor/manifest/dmd.xml) re-declares the
# Samsung telephony HAL `vendor.samsung_slsi.telephony.hardware.oemservice`
# (fqname IOemService/dm0, IOemService/dm1). Merged at runtime it therefore
# re-adds cellular HALs on all 13 devices and DEFEATS the radio-free main
# manifest — the exact "wired but defeated" defect recorded on this card.
#
# Drop the fragment module from PRODUCT_PACKAGES so the fragment is never
# installed and cannot be merged. filter-out is idempotent and
# device-agnostic (mirrors the radio fragments already dropped in
# radio-excised/remove-packages.mk:112,128,129 and the fp-excised.mk Layer-3
# fragment filter): a package not present on the building device is simply not
# matched. Reversible (Law 11). This lives here — not in remove-packages.mk —
# because that file's drop lists are owned by the concurrently-running
# T-EXCISE-RADIOEXT-HAL lane (wave-1 exclusive-file split).
PRODUCT_PACKAGES := $(filter-out \
    adevtool_vintf_fragment_vendor_dmd.xml,$(PRODUCT_PACKAGES))

PRODUCT_VENDOR_PROPERTIES += \
    ro.boot.radio.disabled=1 \
    ro.radio.noril=1
