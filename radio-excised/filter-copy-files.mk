# Strip modem firmware, init scripts, VINTF fragments, and radio_ext blobs.
# Must run via `include` from tokay.mk so PRODUCT_COPY_FILES is fully populated.
define _gt-copy-file-drop
$(or \
  $(findstring /modem/,$(1)), \
  $(findstring ntn_modem,$(1)), \
  $(findstring init.modem,$(1)), \
  $(findstring init.shared_modem,$(1)), \
  $(findstring init.radio,$(1)), \
  $(findstring rild_exynos.rc,$(1)), \
  $(findstring init.vendor_telephony.rc,$(1)), \
  $(findstring radio_ext,$(1)), \
  $(findstring radioext,$(1)), \
  $(findstring manifest_radio,$(1)), \
  $(findstring shared_modem,$(1)), \
  $(findstring modem_ml,$(1)), \
  $(findstring fstab.modem,$(1)), \
  $(findstring liboemservice,$(1)), \
  $(findstring modem_stat,$(1)), \
  $(findstring cbd,$(1)), \
  $(findstring rfsd,$(1)))
endef

_gt_filtered_product_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-copy-file-drop,$(cf)),,\
    $(eval _gt_filtered_product_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_filtered_product_copy_files))
