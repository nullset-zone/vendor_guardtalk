# GuardTalkOS mustang — kill path-based memtag_heap defaults.
#
# BoardConfig-excised-late.mk already clears SANITIZE_TARGET memtag_heap and
# strips bootloader.pixel.MTE_FORCE_ON (laguna boot-parity with rango). That is
# NOT enough: memtag-common.mk still injects
# PRODUCT_MEMTAG_HEAP_ASYNC_DEFAULT_INCLUDE_PATHS (system/bpf, system/netd,
# iproute2, iptables, …) into Soong via soong_config.mk, so bpfloader/netd/ip
# ship with .note.android.memtag while stock factory builds of those same bins
# do not.
#
# Include from mustang.mk (product makefile). Requires soong reconfig + rebuild
# of the affected modules to take effect in OUT.
PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS := true
PRODUCT_MEMTAG_HEAP_ASYNC_INCLUDE_PATHS :=
PRODUCT_MEMTAG_HEAP_SYNC_INCLUDE_PATHS :=
