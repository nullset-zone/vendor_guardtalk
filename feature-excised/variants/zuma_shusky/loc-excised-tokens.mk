# GuardTalkOS — zuma_shusky (zuma / shusky) variant-scoped LOCATION naming data.
#
# T-EXCISE-LOC-GPS-NAME-COVERAGE (P0).
#
# WHY THIS FILE EXISTS
# --------------------
# The shared loc-excised.mk Layer-1 filter is `gnss`-name-shaped: it targets the
# Lassen GNSS stack by its `gnss` tokens (gnssd, gnss_test, libcustomgnss,
# android.hardware.gnss*, init.gnss.rc, /etc/gnss/{ca.pem,gps.cfg,hash.bin}).
# The two zuma_shusky device trees ship a DIFFERENT, Broadcom-shaped location
# userspace stack whose names contain NO `gnss` substring, so the Layer-1 filter
# never matched it and it survived into the shipped vendor.img:
#
#   PRODUCT_PACKAGES    : gps.default   -> /vendor/lib64/hw/gps.default.so
#                         gpsd          -> /vendor/bin/hw/gpsd
#                         lhd           -> /vendor/bin/hw/lhd
#                         scd           -> /vendor/bin/hw/scd
#   PRODUCT_COPY_FILES  : .../etc/init/init.gps.rc
#                         .../etc/gnss/{gps.cer,gps.xml,lhd.conf,scd.conf}
#
# On `shiba` / `husky` this stack is init-started in `class main` (Architect
# recon E-9; A-EXCISE-LOC F-001/F-006), so it is a reachable-at-boot residual,
# not dry weight. This card excises it.
#
# WHY DATA, NOT A GLOBAL NAME GRAB
# --------------------------------
# A bare `gps*` / `scd*` / `lhd*` pattern would be over-broad: the in-tree module
# namespace contains non-location tokens that MUST be preserved, e.g.
#   * `libsitril-gps`     (telephony/RIL library; contains `gps` but neither
#                          `gpsd` nor `gps.default`)
#   * `libgps.utils`      (contains `gps.` but not `gps.default`)
#   * `cell_info_tdscdma` (contains `scd` as a substring of `tdscdma`; a bare
#                          `$(findstring scd,...)` WOULD have matched it)
# This file therefore lists EXACT Soong module names and EXACT PRODUCT_COPY_FILES
# destination paths, and the shared filter loads it ONLY for the `zuma_shusky`
# variant. The other 11 variants load no file, so their filter is a no-op and
# their build is byte-identical to before this card.
#
# Derivation (mechanical, no invented entries) — evidence anchors in the
# generated google_devices trees (which this card does NOT edit):
#   vendor/google_devices/shiba/shiba.mk:661,662,678,835      (PRODUCT_PACKAGES)
#   vendor/google_devices/shiba/shiba.mk:1590-1592,1642,3428  (PRODUCT_COPY_FILES)
#   vendor/google_devices/husky/husky.mk:665,666,683,842
#   vendor/google_devices/husky/husky.mk:1593-1595,1646,3437
#   vendor/google_devices/shiba/proprietary/Android.bp:1141,1174,1207,2140
#   vendor/google_devices/husky/proprietary/Android.bp:1171,1204,1237,2180
#
# Reversible (Law 11): delete this file (or its variant directory) and the
# loc-excised.mk variant hook becomes a no-op; remove the include block there to
# retire the mechanism entirely.

# Exact Soong module names to drop from PRODUCT_PACKAGES. Exactness IS the
# over-broad guard: `libsitril-gps` / `libgps.utils` are not in this list and
# cannot be matched by it. `gps.default` is the cc_prebuilt_library_shared that
# installs `/vendor/lib64/hw/gps.default.so`; `gpsd`/`lhd`/`scd` are the
# cc_prebuilt_binary daemons installed under `/vendor/bin/hw/`.
GT_VARIANT_LOC_DROP_PACKAGES := \
    gps.default \
    gpsd \
    lhd \
    scd

# PRODUCT_COPY_FILES destination-path substrings to drop. Each is an exact
# destination under /vendor/etc/{init,gnss}; every one is consumed only by the
# removed location daemons/HAL (`init.gps.rc` defines exactly lhd/gpsd/scd/
# gnss_service), so no non-location consumer exists.
GT_VARIANT_LOC_DROP_COPY_DESTS := \
    /etc/init/init.gps.rc \
    /etc/gnss/gps.cer \
    /etc/gnss/gps.xml \
    /etc/gnss/lhd.conf \
    /etc/gnss/scd.conf
