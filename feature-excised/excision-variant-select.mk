# GuardTalkOS — shared excision VARIANT RESOLVER + VALIDATOR.
#
# T-PORT-EXCISION-MATRIX (P0, DEC-PORT-GEN8910-001/002).
#
# Reads the data-only registry (excision-variants.mk) and resolves a product to
# exactly ONE excision variant. It FAILS LOUDLY — never silently no-ops — in
# every ambiguous/unknown case:
#
#   * no device identity at all ...................... $(error)
#   * device not registered and SoC unknown .......... $(error), names the SoC
#   * device not registered and SoC ambiguous ........ $(error), lists candidates
#   * explicit variant name not in the registry ...... $(error)
#   * pinned per-device blocklist != variant file .... $(error)
#   * pinned per-device blocklist tokens != variant .. $(error)  (drift guard)
#   * registry-derived FP union narrower than baseline $(error)
#
# Included by:
#   * vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk  (board)
#   * vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk       (product)
#   * vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk   (product)
#
# Include order note: the resolver is a no-op when already resolved with the
# same device, so including it from several hooks is safe and cheap.

include vendor/guardtalk/feature-excised/excision-variants.mk

# ---------------------------------------------------------------------------
# 0. Re-entry guard (T-PORT-FLASH-CLI-9DEV / A5).
#
# This resolver is included from several hooks:
#   * vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk  (board)
#   * vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk       (product)
#   * vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk   (product)
# and radio-excised/product-config-late.mk re-enters the last two. The include
# order note at the top of this file has always promised that a re-include for
# the same device is a no-op; this is that guard.
#
# GT_EXCISION_RESOLVED records the device resolved by an earlier include. A
# later include is a no-op when it either:
#   (a) names the SAME device, or
#   (b) sees no device identity at all — the late product hook runs after
#       PRODUCT_DEVICE/TARGET_DEVICE are cleared, and one make invocation only
#       ever resolves a single device.
# An include that explicitly names a DIFFERENT device is NOT swallowed: it
# falls through to the resolution below, where the fail-loud checks abort. The
# guard therefore never weakens the $(error) contract; it only stops a redundant
# second pass from re-firing identity checks with already-consumed state.
# ---------------------------------------------------------------------------
GT_EXCISION_CANDIDATE_DEVICE := $(strip $(or $(GUARDTALK_DEVICE),$(PRODUCT_DEVICE),$(TARGET_DEVICE)))
GT_EXCISION_REENTRY := $(strip $(if $(GT_EXCISION_RESOLVED),\
    $(if $(GT_EXCISION_CANDIDATE_DEVICE),\
        $(filter $(GT_EXCISION_CANDIDATE_DEVICE),$(GT_EXCISION_RESOLVED)),\
        1)))

ifeq ($(GT_EXCISION_REENTRY),)

# ---------------------------------------------------------------------------
# 1. Device identity. BoardConfig hooks set GUARDTALK_DEVICE explicitly
#    (PRODUCT_DEVICE is not guaranteed to be defined at board-config time);
#    product-side hooks rely on PRODUCT_DEVICE.
# ---------------------------------------------------------------------------
GT_EXCISION_DEVICE := $(GT_EXCISION_CANDIDATE_DEVICE)

ifeq ($(GT_EXCISION_DEVICE),)
$(error T-PORT-EXCISION-MATRIX: cannot resolve an excision variant — no known device identity (GUARDTALK_DEVICE / PRODUCT_DEVICE / TARGET_DEVICE all empty). Register the device in vendor/guardtalk/feature-excised/excision-variants.mk.)
endif

# ---------------------------------------------------------------------------
# 2. Variant resolution, in priority order:
#      (a) explicit GUARDTALK_EXCISION_VARIANT (per-device data override)
#      (b) GT_DEVICE_VARIANT_<device>           (registry, the normal path)
#      (c) unique variant whose SOC matches TARGET_BOARD_PLATFORM
#    (c) exists only as a convenience for product-config time; because zuma has
#    2 variants and zumapro has 4, an unregistered device is REJECTED as
#    ambiguous rather than silently picking the first match.
# ---------------------------------------------------------------------------
GT_EXCISION_VARIANT := $(strip $(GUARDTALK_EXCISION_VARIANT))

ifeq ($(GT_EXCISION_VARIANT),)
GT_EXCISION_VARIANT := $(strip $(GT_DEVICE_VARIANT_$(GT_EXCISION_DEVICE)))
endif

ifeq ($(GT_EXCISION_VARIANT),)
GT_EXCISION_SOC_MATCHES := $(strip $(foreach _gt_v,$(GUARDTALK_EXCISION_VARIANTS),\
  $(if $(filter $(TARGET_BOARD_PLATFORM),$(GT_VARIANT_$(_gt_v)_SOC)),$(_gt_v))))
ifneq ($(TARGET_BOARD_PLATFORM),)
ifneq ($(words $(GT_EXCISION_SOC_MATCHES)),1)
$(error T-PORT-EXCISION-MATRIX: device '$(GT_EXCISION_DEVICE)' is not registered in vendor/guardtalk/feature-excised/excision-variants.mk and SoC '$(TARGET_BOARD_PLATFORM)' is $(if $(GT_EXCISION_SOC_MATCHES),AMBIGUOUS (candidates: $(GT_EXCISION_SOC_MATCHES)),UNKNOWN). Add a GT_DEVICE_VARIANT_$(GT_EXCISION_DEVICE) row naming the exact kernel family. Refusing to guess — a wrong variant silently mis-excises the image.)
endif
GT_EXCISION_VARIANT := $(GT_EXCISION_SOC_MATCHES)
else
$(error T-PORT-EXCISION-MATRIX: device '$(GT_EXCISION_DEVICE)' has NO excision variant entry — refusing to build. Add a GT_DEVICE_VARIANT_$(GT_EXCISION_DEVICE) row to vendor/guardtalk/feature-excised/excision-variants.mk and map it to an existing variant (or add the new variant + its blocklist data).)
endif
endif

ifeq ($(filter $(GT_EXCISION_VARIANT),$(GUARDTALK_EXCISION_VARIANTS)),)
$(error T-PORT-EXCISION-MATRIX: unknown excision variant '$(GT_EXCISION_VARIANT)' for device '$(GT_EXCISION_DEVICE)'. Known variants: $(GUARDTALK_EXCISION_VARIANTS).)
endif

# ---------------------------------------------------------------------------
# 3. Export the resolved variant's data (read-only for consumers).
# ---------------------------------------------------------------------------
GT_VARIANT               := $(GT_EXCISION_VARIANT)
GT_VARIANT_SOC           := $(GT_VARIANT_$(GT_VARIANT)_SOC)
GT_VARIANT_KERNEL_FAMILY := $(GT_VARIANT_$(GT_VARIANT)_KERNEL_FAMILY)
GT_VARIANT_WIFI_MODULES  := $(GT_VARIANT_$(GT_VARIANT)_WIFI_MODULES)
GT_VARIANT_TOUCH_MODULES := $(GT_VARIANT_$(GT_VARIANT)_TOUCH_MODULES)
GT_VARIANT_FP_STACK      := $(GT_VARIANT_$(GT_VARIANT)_FP_STACK)
GT_VARIANT_RADIO_SET     := $(GT_VARIANT_$(GT_VARIANT)_RADIO_SET)
GT_VARIANT_BLOCKLIST     := $(GT_VARIANT_$(GT_VARIANT)_BLOCKLIST)

# Per-device override (if any) wins; otherwise the variant's canonical file.
GT_EXCISION_BLOCKLIST_FILE := $(strip $(or \
    $(GT_DEVICE_BLOCKLIST_$(GT_EXCISION_DEVICE)),\
    $(GT_VARIANT_BLOCKLIST)))

# ---------------------------------------------------------------------------
# 4. FP union guard: the registry must cover the frozen baseline pattern set.
#    (fp-excised.mk consumes GT_EXCISION_FP_DROP_PATTERNS.)
# ---------------------------------------------------------------------------
GT_EXCISION_FP_BASELINE_MISSING := $(sort $(filter-out \
    $(GT_EXCISION_FP_DROP_PATTERNS),$(GT_EXCISION_FP_DROP_BASELINE)))
ifneq ($(GT_EXCISION_FP_BASELINE_MISSING),)
$(error T-PORT-EXCISION-MATRIX: variant registry drops fingerprint drop-pattern(s) [$(GT_EXCISION_FP_BASELINE_MISSING)] that fp-excised.mk shipped before this card. Refusing to narrow the fingerprint excision silently — add the tokens back to excision-variants.mk.)
endif

# ---------------------------------------------------------------------------
# 5. Consumers.
# ---------------------------------------------------------------------------
GT_EXCISION_BLOCKLIST_TOKENS = $(sort $(shell sed -n 's/^[[:space:]]*blocklist[[:space:]]*//p' $(1) 2>/dev/null))

# Validate that the device's effective blocklist really is its variant's data.
# Call AFTER BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE is assigned, e.g.
#   $(call gt-excision-validate-device-blocklist)
# Errors (never warns) on any mismatch — this is the "no silent no-op" guard.
#
# The reference set is ALWAYS the variant's canonical blocklist
# (GT_VARIANT_BLOCKLIST), never the device's own pin. A registered pin may
# therefore never drift off its variant without the build aborting.
define gt-excision-validate-device-blocklist
$(if $(wildcard $(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)),,\
  $(error T-PORT-EXCISION-MATRIX: device '$(GT_EXCISION_DEVICE)' (variant $(GT_VARIANT)) points BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE at '$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)' which does not exist.))
$(if $(filter $(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE),$(GT_VARIANT_BLOCKLIST) $(GT_DEVICE_BLOCKLIST_$(GT_EXCISION_DEVICE))),,\
  $(error T-PORT-EXCISION-MATRIX: device '$(GT_EXCISION_DEVICE)' pins blocklist '$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)' but variant $(GT_VARIANT) resolves to '$(GT_VARIANT_BLOCKLIST)'. Register the pin as GT_DEVICE_BLOCKLIST_$(GT_EXCISION_DEVICE) after proving token equality with the variant file.))
$(if $(filter-out $(call GT_EXCISION_BLOCKLIST_TOKENS,$(GT_VARIANT_BLOCKLIST)),$(call GT_EXCISION_BLOCKLIST_TOKENS,$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE))),\
  $(error T-PORT-EXCISION-MATRIX: device '$(GT_EXCISION_DEVICE)' blocklist '$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)' has extra tokens [$(filter-out $(call GT_EXCISION_BLOCKLIST_TOKENS,$(GT_VARIANT_BLOCKLIST)),$(call GT_EXCISION_BLOCKLIST_TOKENS,$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)))] not in variant $(GT_VARIANT).),)
$(if $(filter-out $(call GT_EXCISION_BLOCKLIST_TOKENS,$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)),$(call GT_EXCISION_BLOCKLIST_TOKENS,$(GT_VARIANT_BLOCKLIST))),\
  $(error T-PORT-EXCISION-MATRIX: device '$(GT_EXCISION_DEVICE)' blocklist '$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)' is MISSING tokens [$(filter-out $(call GT_EXCISION_BLOCKLIST_TOKENS,$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)),$(call GT_EXCISION_BLOCKLIST_TOKENS,$(GT_VARIANT_BLOCKLIST)))] required by variant $(GT_VARIANT).),)
endef

# Record the resolution so section 0's re-entry guard treats any later include
# for this same device as a no-op.
GT_EXCISION_RESOLVED := $(GT_EXCISION_DEVICE)

ifneq ($(GT_EXCISION_VERBOSE),)
$(info GT-EXCISION[$(GT_EXCISION_DEVICE)]: variant=$(GT_VARIANT) soc=$(GT_VARIANT_SOC) kernel=$(GT_VARIANT_KERNEL_FAMILY) wifi=[$(GT_VARIANT_WIFI_MODULES)] touch=[$(GT_VARIANT_TOUCH_MODULES)] fp=$(GT_VARIANT_FP_STACK) radio=$(GT_VARIANT_RADIO_SET) blocklist=$(GT_EXCISION_BLOCKLIST_FILE))
endif

else
# A5 re-entry: '$(GT_EXCISION_RESOLVED)' is already resolved — skip re-resolving
# so a late product hook cannot re-fire identity checks with consumed state.
endif
