#!/bin/bash
# vendor/guardtalk/scripts/stage-rango-release.sh
#
# T-RANGO-BOOT-FIX (2026-08-01) — consolidated GuardTalkOS rango
# (Pixel 10 Pro Fold / laguna) release-staging helper.
#
# This is a STAGING helper only. It never flashes anything. Flashing is
# always via scripts/flash-from-remote.sh or vendor/guardtalk/scripts/
# flash-from-remote.sh (Architect binding — no scripts/flash-*.sh here).
#
# Folds/supersedes the archived experimental
# .agent-comm/completed/rango-flash-mess-20260801/stage-rango-hybrid.sh
# (same sepolicy-graft technique, hard cmp gate preserved verbatim) and
# adds two read-only diagnostic staging modes required by the Architect's
# residual-gap binding (a prior MATCH-hash hybrid still hit init 0x7f00 —
# a graft alone is not proof of a working boot chain).
#
# Modes (MODE env var, default: gtuserspace):
#
#   gtuserspace  **DEFAULT / durable fix path (T-RANGO-BOOT-FINAL).**
#              Factory CP1A boot chain (ABL-proven) + GuardTalkOS
#              system/system_ext/product/vendor from the same OUT + factory
#              system_dlkm/vendor_dlkm (kernel 6.6.102 vermagic — GT dlkm is
#              6.6.139+RANDSTRUCT and must NOT pair with factory boot).
#              Staging patches:
#                - restorecon /metadata before apexd-bootstrap
#                - strip .note.android.memtag from early networking bins
#                - stock bootstrap linker64 + /system/lib64/bootstrap/*
#                - drop GuardTalk/userdebug-only init .rc files
#                - drop com.android.virt.apex (EARLY_VM bootstrap landmine
#                  with factory pvmfw; apexd was compiled with
#                  RELEASE_AVF_ENABLE_EARLY_VM=true → kBootstrapApexes
#                  includes com.android.virt → reboot_on_failure
#                  reboot,bootloader,bootstrap-apexd-failed → 0xfc)
#                - graft stock bootstrap apexes matching kBootstrapApexes:
#                  runtime + i18n + tzdata (stock file name
#                  com.google.android.tzdata6.apex; manifest name is still
#                  com.android.tzdata — deapexer-proven). 123756 FAIL 0xfc
#                  falsified stock runtime/i18n alone; GT tzdata was last
#                  named bootstrap apex still GT.
#              No factory-vendor sepolicy graft. GuardTalkOS product/system
#              content retained (not stock-only OS).
#              May repoint rango-latest with --link-latest.
#              fullgt ABL-rejected on-device 2026-08-02 (AB Decisions 11311112).
#
#   stockbootstrap  Bisect: same as gtuserspace but KEEPS virt.apex
#              (matches rango-20260802-103641 evidence: ~18s reboot
#              bootloader). --link-latest refused.
#
#   stockbootapex   LEGACY bisect: keep virt + stock com.android.runtime +
#              com.android.i18n (+ tzdata) apexes. On-device superseded:
#              111004 proved virt-drop alone insufficient; use gtuserspace.
#              --link-latest refused.
#
#   novirtstockapex LEGACY bisect (T-RANGO-BOOT-APEX): drop virt + stock
#              runtime/i18n/tzdata. On-device 123756 FAIL 0xfc proved
#              runtime/i18n alone insufficient; tzdata graft now folded into
#              durable gtuserspace. --link-latest refused.
#
#   stockapexd Bisect (T-RANGO-BOOT-APEXD): durable gtuserspace composition
#              (novirt + stock tzdata/runtime/i18n) PLUS stock
#              /system/bin/apexd. Operator 130756 FAIL 0xfc falsified
#              tzdata-sole RC; GT apexd size/bytes ≠ stock (1030416 vs
#              1083368). apexd.rc already MATCH stock. On-device 132759
#              FAIL 0xfc falsified stock-apexd-sole. Flash via
#              REMOTE_BUILD_DIR only. --link-latest refused until on-device
#              PASS + Architect promotes into MODE=gtuserspace.
#
#   stockinit  Bisect (T-RANGO-BOOT-INIT): stockapexd composition PLUS
#              stock /system/bin/init. Operator 132759 FAIL 0xfc with
#              apexd/apexd.rc MATCH stock; init DIFFERS (2938144 vs
#              2771368). Hard cmp gate after graft. On-device 141438 FAIL
#              ~61s KP exitcode=0x00000100 / reboot 0xbaba / mode 0x0
#              (NOT 0xfc) — stock-init-sole FALSIFIED; do not promote.
#              --link-latest refused.
#
#   stockapexcfg Bisect (T-RANGO-BOOT-POSTINIT): stockapexd composition
#              (stock apexd + GT /system/bin/init — NO stock init binary)
#              PLUS stock /system/etc/init/hw/init.rc (early
#              perform_apex_config / apexd-bootstrap script surface).
#              Operator 141438 stockinit FAIL changed class to init exit 1.
#              On-device 150440 FAIL 0xfc ~18s — stockapexcfg-sole FALSIFIED
#              (returned to apexd-bootstrap class; NOT KP 0x100). Hard cmp
#              after init.rc graft. --link-latest refused.
#
#   stockhwasan Bisect (T-RANGO-BOOT-HWASAN): stockapexcfg composition
#              (stockapexd + GT init + stock init.rc + stock runtime/i18n/
#              tzdata) PLUS stock hwasan native-deps for runtime
#              ActivatePackage. Disk on 150440: bootstrap
#              libclang_rt.hwasan MATCH stock (via patch_stock_bootstrap),
#              BUT /system/lib64/bootstrap/hwasan/libc.so still GT
#              (1706096 vs stock 1674080). Stock+GT runtime apex
#              requireNativeLibs both list libclang_rt.hwasan-*-android.so
#              — graft stock bootstrap/hwasan/libc.so (hard cmp). Keep GT
#              init; do not promote stockinit. On-device 153335 FAIL 0xfc
#              ~18s with GrapheneOS flash parity — stockhwasan-sole +
#              flash-parity-sole FALSIFIED. --link-latest refused.
#
#   stockselinux Bisect (T-RANGO-BOOT-SELINUX): stockhwasan composition
#              PLUS stock early-apex SELinux surface (domains / file
#              contexts / coherent precompiled). Host disk on 153335:
#              restorecon /metadata already present (stock init.rc);
#              GT plat_file_contexts MISSING
#              /dev/block/mapper/.*\.apex → apex_dm_device; GT
#              plat_sepolicy.cil has 0× apex_dm_device (stock 16×).
#              Grafts stock plat + system_ext + product sepolicy (+
#              mapping/sha256) and stock vendor precompiled (+ 3 sha256)
#              so hashes MATCH (plat-alone would force secilc → 0x7f00).
#              Hard cmp gates. GT init retained. --link-latest refused.
#              On-device 044126 FAIL 0xfc ~18s — stockselinux-sole
#              FALSIFIED (sepolicy as sole cause dead).
#
#   stockapexset Bisect (T-RANGO-BOOT-APEXSET): durable gtuserspace
#              composition (GT apexd / GT init / GT init.rc retained)
#              PLUS stock /system/apex WHOLESALE — every GT-repacked APEX
#              removed, ALL stock .apex files from the canonical stock
#              donor (releases/desktop-flash/rango-stock-userspace,
#              factory CP1A.260505.005 — same donor as every prior stock
#              graft in this script) grafted under stock filenames
#              (com.google.android.*, incl. tzdata6 + virt): /system/apex
#              becomes byte-identical to the avbcontrol PASS composition.
#              DR-RANGO-10DAY-RCA RQ4 candidate #2 (bootstrap-set APEX
#              content — art/adbd/conscrypt/… set never swapped in any
#              prior bisect). apexd bootstrap matches by MANIFEST name
#              (apexd.cpp:168-210), so stock filenames activate exactly
#              as on the PASS control. Hard gates: per-file sha256 re-dump
#              AFTER ALL writes + count gate (N stock present, 0 GT
#              remain). 130338 debugfs write-order bug class ROOT-CAUSED
#              2026-08-03: debugfs 1.47 write allocator fails under a
#              near-full/fragmented free pool ("Could not allocate block",
#              exit 0, silent truncation) — fixed by growing the work
#              system.img +384MiB before grafting (super group headroom
#              ~1.35GiB; packaging-only) + smallest-first write order +
#              e2fsck post-graft. --link-latest refused.
#              On-device 130329 FAIL 0xfc ~18s (AB 11111111) — combined
#              with 044126 (stock sepolicy + GT apexes FAIL), bootstrap-set
#              APEX content FALSIFIED as sole cause (RQ4 #2 closed).
#
#   stockvendor Bisect (T-RANGO-BOOT-STOCKVENDOR): durable gtuserspace
#              composition (GT apexd / GT init / GT init.rc retained; drop
#              virt + stock runtime/i18n/tzdata) PLUS factory vendor.img
#              WHOLESALE from the canonical stock donor
#              (releases/desktop-flash/rango-stock-userspace, factory
#              CP1A.260505.005 — same donor as APEXSET). RQ4 #1 (prime):
#              loop-device/ueventd coldboot handoff environment — vendor
#              carries ueventd.rc / fstab / init.*.rc / VINTF manifests and
#              was never swapped in the gtuserspace era. Vendor diff
#              analysis (RANGO_BOOT_RCA §1.0): ueventd.rc, fstab.laguna,
#              fstab.persist and ALL /etc/init/hw/*.rc are byte-identical
#              GT vs stock — static coldboot config is NOT the delta;
#              the probe isolates vendor binary/lib/firmware/VINTF content.
#              Hard gates: sha256 vs donor (work image + shipped image),
#              e2fsck rc<=2 on a throwaway copy (e2fsck writes the
#              superblock even on a clean rc=0 run — verified 2026-08-03 —
#              so the grafted image itself is never fsck'd, preserving
#              byte-identity). GT init retained. --link-latest refused.
#              Super geometry measured: stock vendor 1,009,041,408 vs GT
#              915,238,912 (+89.5MiB) — group headroom ~5.0GiB, no grow
#              needed (lpmake sizes follow the work image automatically).
#
#   hybrid     LEGACY diagnostic: factory boot + factory vendor + GT
#              system*/product + GT sepolicy graft. Confirmed on-device to
#              still hit init 0x7f00 (2026-08-01). Kept for bisect only.
#              --link-latest refused (must not become rango-latest again).
#
#   fullgt     Fully coherent OUT including GT boot chain (H3 ABL test).
#              NEVER linked to rango-latest by this script.
#
#   gtsystemonstock  INVERTED bisect (T-RANGO-BOOT-GTSYSTEM): start from
#              the known-good avbcontrol/stock composition (BOOTS AOSP)
#              and replace ONLY system.img with GT OUT system. Everything
#              else (vendor/system_ext/product/dlkm/boot/firmware) stays
#              factory CP1A. Tests whether GT system.img alone is sufficient
#              to reproduce 0xfc. --link-latest refused.
#              On-device 071115 FAIL ~58s KP 0x7f00 (GT plat + stock vendor
#              sepolicy mismatch) — did NOT reach apexd. Follow-up:
#              MODE=gtsystemonstockselinux.
#   gtsystemonstockselinux  INVERTED + coherent stock plat sepolicy on GT
#              system (ext/product/vendor already stock). Plat hash MATCH
#              stock vendor precompiled (8db80f2e). On-device 100054 still
#              FAIL KP 0x7f00 ~63s — hash mismatch FALSIFIED as sole cause.
#              --link-latest refused.
#   gtsystemonstockinitboot  INVERTED+selinux + stock /system/bin/init
#              + stock bootstrap linker/libc/hwasan. On-device 104334 FAIL
#              ~60s KP 0x00000100 (class change from inverted 0x7f00; same
#              class as 141438). Bootstrap MATCH; init NEEDED /system/lib64
#              still GT. Follow-up: MODE=gtsystemonstockinitlibs.
#              --link-latest refused.
#   gtsystemonstockinitlibs  initboot + stock transitive NEEDED /system/lib64
#              for /system/bin/init (27 libs; all DIFF on 104334; libfec_rs
#              ABSENT on GT). On-device 110531 FAIL 0xfc ~18s (AB 11111111,
#              reboot bootloader) — 0x7f00/0x100 CURED; inverted now reaches
#              apexd-bootstrap. Follow-up: MODE=gtsystemonstocknovirt.
#              --link-latest refused.
#   gtsystemonstocknovirt  initlibs + drop com.android.virt.apex (61MiB on
#              110531). On-device 112754 FAIL 0xfc ~17s — virt-sole
#              FALSIFIED on inverted. Follow-up: MODE=gtsystemonstockbootapex.
#              --link-latest refused.
#   gtsystemonstockbootapex  novirt + stock kBootstrapApexes remaining
#              (runtime/i18n/tzdata). On-device 114442 FAIL 0xfc ~18s
#              (AB 31111111) — bootstrap-apex-sole FALSIFIED. Follow-up:
#              MODE=gtsystemonstockapexd. --link-latest refused.
#   gtsystemonstockapexd  bootapex + stock /system/bin/apexd (apexd.rc
#              already MATCH stock on 114442). On-device 103210 FAIL 0xfc
#              ~18s AB 11111111 — apexd-sole FALSIFIED on inverted.
#              Follow-up: MODE=gtsystemonstockueventd. --link-latest refused.
#   gtsystemonstockueventd  apexd + stock /system/etc/ueventd.rc (stock
#              `/dev/block/mapper/*.apex` vs GT `/dev/block/dm-*`).
#              On-device 105952 FAIL 0xfc ~18s AB 11111111 — ueventd-sole
#              FALSIFIED on inverted. Follow-up: MODE=gtsystemonstockapexset.
#              --link-latest refused.
#   gtsystemonstockapexset  ueventd + stock /system/apex WHOLESALE (36
#              stock filenames incl. com.google.android.virt.apex +
#              tzdata6; 0 GT apexes). On-device 115437 FAIL 0xfc ~18s
#              AB 11111111 — leftover GT apex-set FALSIFIED on inverted.
#              Follow-up: MODE=gtsystemonstockprop. --link-latest refused.
#   gtsystemonstockprop  apexset + stock /system/build.prop (GT Baklava
#              userdebug / compressed_apex=false vs stock REL user /
#              compressed_apex=true). On-device 123449 FAIL 0xfc ~18s
#              AB 11111111 — build.prop-sole FALSIFIED on inverted.
#              Follow-up: MODE=gtsystemonstockapexdlibs. --link-latest refused.
#   gtsystemonstockapexdlibs  prop + stock apexd NEEDED lib64 DIFF closure
#              (6 libs: libbinder/libvintf/libziparchive/
#              apex_aidl_interface-cpp/libapexsupport/libtinyxml2).
#              On-device 064000 FAIL 0xfc ~18s AB 11111111 — apexd-libs-sole
#              FALSIFIED on inverted. Follow-up: MODE=gtsystemonstockpctx.
#              --link-latest refused.
#   gtsystemonstockpctx  apexdlibs + stock
#              /system/etc/selinux/plat_property_contexts (sepolicy graft
#              omitted this file). On-device 065959 FAIL 0xfc ~18s
#              AB 11111111 — pctx-sole FALSIFIED on inverted.
#              Follow-up: MODE=gtsystemonstockinitrc. --link-latest refused.
#   gtsystemonstockinitrc  pctx + stock /system/etc/init/hw/init.rc
#              (GT 58090 vs stock 57115). On-device 071944 FAIL 0xfc ~18s
#              AB 11111111 — initrc-sole FALSIFIED on inverted.
#              Follow-up: MODE=gtsystemonstockplatctx. --link-latest refused.
#   gtsystemonstockplatctx  initrc + remaining leftover plat contexts
#              (sepolicy graft omitted these). Host DIFF on 071944:
#              plat_service_contexts 43414→44820, plat_seapp_contexts
#              3617→4637, plat_mac_permissions.xml 16506→18378,
#              plat_keystore2_key_contexts 2184→1431,
#              plat_tee_service_contexts 1585→832.
#              plat_hwservice_contexts MATCH 8865 (not grafted).
#              On-device 073937 FAIL 0xfc ~18s AB 11111111 — platctx-sole
#              FALSIFIED on inverted. Follow-up: MODE=gtsystemonstockearlyinit.
#              --link-latest refused.
#   gtsystemonstockearlyinit  platctx + leftover early-init surface:
#              remaining DIFF /system/etc/init/*.rc (incl. aconfigd.rc
#              stock-only restorecon_recursive /metadata), stock-only
#              casefolding_remover.rc, DIFF hw usb/zygote, and early-init
#              bins aconfigd-system + prng_seeder. On-device 092118 FAIL
#              0xfc ~18s AB 11111111 — earlyinit-sole FALSIFIED on inverted.
#              Follow-up: MODE=gtsystemonstockprotobuf. --link-latest refused.
#   gtsystemonstockprotobuf  earlyinit + stock
#              /system/lib64/libprotobuf-cpp-full-6.33.1.so. Size MATCH
#              3387232 but cmp DIFF (sha256 GT ffae9472… vs stock
#              ba3c01bf…). On-device 094500 CLASS CHANGE: 0xfc → KP
#              0x00000100 ~61s AB 11111133 (0xbaba, mode 0x0). Not PASS.
#              Follow-up: MODE=gtsystemonstocklibcxx. --link-latest refused.
#   gtsystemonstocklibcxx  protobuf + stock /system/lib64/libc++.so.
#              Size MATCH 1152784 but cmp DIFF (sha256 GT 4e476154…
#              vs stock 5d3b39c9…). Sole leftover cmp-DIFF in
#              init+apexd+protobuf recursive NEEDED. On-device 062622
#              FAIL 0xfc ~18s AB 31111111 — stock libc++ re-opened
#              apexd-bootstrap (094500 had class-changed to KP 0x100).
#              libc++ is NOT a boot cure. Follow-up:
#              MODE=gtsystemonstockldandroid. --link-latest refused.
#   gtsystemonstockldandroid  libcxx + stock /system/lib64/ld-android.so.
#              Size MATCH 34256 but cmp DIFF (sha256 GT eb3c8339…
#              vs stock b7f2f786…). Same GT hash on 094500 and 062622.
#              After protobuf+libcxx, init+apexd+protobuf NEEDED is MATCH;
#              leftover cmp-DIFF is ld-android.so. linker.config.pb MATCH.
#              On-device 123801 FAIL 0xfc ~18s AB 11111111 — ld-android-sole
#              FALSIFIED (harvest-rango-20260819-170347). Follow-up:
#              MODE=gtsystemonstockapexdetc. --link-latest refused.
#   gtsystemonstockapexdetc  ldandroid + stock /system/etc/apexd/empty_erofs.img
#              (4096; stock-only dir ABSENT on inverted). Named leftover
#              after protobuf+libcxx+ld-android MATCH. On-device 135504
#              FAIL 0xfc ~17s AB 11111111 — empty_erofs-sole FALSIFIED
#              (harvest-rango-20260819-182144). Follow-up:
#              MODE=gtsystemonstocktaskprof. --link-latest refused.
#   gtsystemonstocktaskprof  apexdetc + stock /system/etc/task_profiles.json.
#              SIZE_DIFF 15069 vs 15365. /system/etc/cgroups.json already
#              MATCH. Stock init.rc + stock libprocessgroup already grafted;
#              leftover is the init cgroup-profile JSON. On-device 142515
#              FAIL 0xfc ~18s AB 11111111 — task_profiles-sole FALSIFIED
#              (harvest-rango-20260819-183508). Follow-up:
#              MODE=gtsystemonstockaconfig. --link-latest refused.
#   gtsystemonstockaconfig  taskprof + stock /system/etc/aconfig/{flag.info,
#              flag.map,flag.val,package.map}. Stock aconfigd.rc +
#              aconfigd-system already MATCH; leftover is the storage
#              aconfigd reads on early-init. On-device 144322 FAIL 0xfc
#              ~18s AB 11111111 — aconfig-storage-sole FALSIFIED
#              (harvest-rango-20260819-185333). Follow-up:
#              MODE=gtsystemonstockacflags. --link-latest refused.
#   gtsystemonstockacflags  aconfig + stock /system/etc/aconfig_flags.pb
#              (SIZE_DIFF 957155 vs 696328). DeviceConfig path leftover
#              after aconfig storage MATCH. On-device 150620 FAIL 0xfc
#              ~18s AB 11111111 — aconfig_flags-sole FALSIFIED
#              (harvest-rango-20260819-192554). Follow-up:
#              MODE=gtsystemonstockbflags. --link-latest refused.
#   gtsystemonstockbflags  acflags + stock /system/etc/build_flags.json
#              (SIZE_DIFF 157219 vs 124580). Last named leftover flag
#              dump after aconfig storage + aconfig_flags MATCH. If
#              still 0xfc: remaining /system/etc DIFFs are zygote-late;
#              next class is flash-path/lpmake. --link-latest refused.
#              On-device 061630 FAIL 0xfc ~18s AB 11111111 — bflags + 0xfc
#              (harvest-rango-20260820-102522): leftover /system/etc/
#              build_flags.json FALSIFIED as inverted 0xfc sole cause.
#              Flag-dump inverted series (aconfig / acflags / bflags)
#              CLOSED. Do not re-graft aconfig/build-flags. Host liblp
#              field-diff factory vs 061630: MATCH (v10, 3 slots, header
#              flags none, no virtual-ab, device 8531214336, group
#              google_dynamic_partitions 8527020032, same 12 names,
#              first sector 2048, alignment 1MiB, no alignment-offset).
#              96-vs-224 gap is the same 1MiB alignment after different
#              system_a sizes — NOT a MODE. No gtsystemonstockfacsuper
#              stamp (no metadata-field extras; no proven early-boot
#              leftover). Next class remains flash-path/lpmake.
#   avbcontrol Fully-stock super + Flags:3 vbmeta (AVB path control).
#              On-device PASS 2026-08-02 (stock AOSP boot). NEVER linked.
#
# Usage:
#   ./stage-rango-release.sh --link-latest          # MODE=gtuserspace (default)
#   MODE=stockbootstrap ./stage-rango-release.sh   # keep virt (103641-class)
#   MODE=stockbootapex ./stage-rango-release.sh    # legacy: keep virt + stock apex
#   MODE=novirtstockapex ./stage-rango-release.sh  # drop virt + stock runtime/i18n
#   MODE=stockapexd ./stage-rango-release.sh       # durable gtuserspace + stock apexd
#   MODE=stockinit ./stage-rango-release.sh        # stockapexd + stock /system/bin/init (FALSIFIED)
#   MODE=stockapexcfg ./stage-rango-release.sh     # stockapexd + GT init + stock init.rc (FALSIFIED)
#   MODE=stockhwasan ./stage-rango-release.sh      # stockapexcfg + stock bootstrap/hwasan libc (FALSIFIED)
#   MODE=stockselinux ./stage-rango-release.sh     # stockhwasan + stock early-apex SELinux (FALSIFIED)
#   MODE=stockapexset ./stage-rango-release.sh     # durable gtuserspace + stock /system/apex wholesale (FALSIFIED)
#   MODE=stockvendor ./stage-rango-release.sh      # durable gtuserspace + factory vendor.img wholesale
#   MODE=gtsystemonstockinitrc ./stage-rango-release.sh  # inverted + stock init.rc (FALSIFIED)
#   MODE=gtsystemonstockplatctx ./stage-rango-release.sh # inverted + leftover plat contexts (FALSIFIED)
#   MODE=gtsystemonstockearlyinit ./stage-rango-release.sh # inverted + leftover early-init rc/bins (FALSIFIED)
#   MODE=gtsystemonstockprotobuf ./stage-rango-release.sh # inverted + stock protobuf (class change 0x100)
#   MODE=gtsystemonstocklibcxx ./stage-rango-release.sh # inverted + stock libc++ (0xfc; not a cure)
#   MODE=gtsystemonstockldandroid ./stage-rango-release.sh # inverted + stock ld-android (0xfc)
#   MODE=gtsystemonstockapexdetc ./stage-rango-release.sh # inverted + stock /system/etc/apexd (0xfc)
#   MODE=gtsystemonstocktaskprof ./stage-rango-release.sh # inverted + stock task_profiles.json (0xfc)
#   MODE=gtsystemonstockaconfig ./stage-rango-release.sh # inverted + stock /system/etc/aconfig (0xfc)
#   MODE=gtsystemonstockacflags ./stage-rango-release.sh # inverted + stock aconfig_flags.pb (0xfc)
#   MODE=gtsystemonstockbflags ./stage-rango-release.sh # inverted + stock build_flags.json (061630 0xfc; series CLOSED)
#   MODE=hybrid ./stage-rango-release.sh            # legacy graft diagnostic
#   MODE=fullgt ./stage-rango-release.sh
#   MODE=avbcontrol ./stage-rango-release.sh
#
# Exit code: 0 on success. Non-zero + no rango-latest change on any gate
# failure (fail-closed, Law 3 / Law 9).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

MODE="${MODE:-gtuserspace}"
LINK_LATEST=0
for arg in "$@"; do
  case "$arg" in
    --link-latest) LINK_LATEST=1 ;;
    *) echo "[stage] unknown arg: $arg" >&2; exit 2 ;;
  esac
done

OUT="$ROOT/out/target/product/rango"
STOCK="$ROOT/releases/desktop-flash/rango-stock-userspace"
STOCKCTL="$ROOT/releases/desktop-flash/rango-stock-control"
RESCUE="$ROOT/releases/desktop-flash/rango-rescue-boot"
HOST_BIN="$ROOT/out/host/linux-x86/bin"
WORK="${STAGE_WORK:-/tmp/rango-stage-$MODE}"
STAMP="${STAMP:-rango-$(date -u +%Y%m%d-%H%M%S)}"
DEST="$ROOT/releases/desktop-flash/$STAMP"

log() { echo "[stage:$MODE] $*"; }
die() { echo "[stage:$MODE] ERROR: $*" >&2; exit 1; }
need() { [ -e "$1" ] || die "missing required input: $1"; }

unsparse_if_needed() {
  local src="$1" dst="$2"
  if file "$src" | grep -qi 'sparse'; then
    "$HOST_BIN/simg2img" "$src" "$dst"
  else
    cp -f "$src" "$dst"
  fi
}

sz() { stat -c%s "$1"; }

# ---------------------------------------------------------------------------
# Gate: OUT sepolicy hashes MUST match before anything is staged/shipped.
# Identical logic to the archived stage-rango-hybrid.sh gate (RCA §2.2/§5).
# ---------------------------------------------------------------------------
sepolicy_hash_gate() {
  log "Gate: OUT sepolicy hashes must MATCH (hard cmp, no soft-pass)"
  need "$OUT/system/etc/selinux/plat_sepolicy_and_mapping.sha256"
  need "$OUT/vendor/etc/selinux/precompiled_sepolicy.plat_sepolicy_and_mapping.sha256"
  cmp "$OUT/system/etc/selinux/plat_sepolicy_and_mapping.sha256" \
      "$OUT/vendor/etc/selinux/precompiled_sepolicy.plat_sepolicy_and_mapping.sha256" \
    || die "plat sepolicy hash MISMATCH in OUT — refusing to stage (RCA primary root cause)"
  cmp "$OUT/system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256" \
      "$OUT/vendor/etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256" \
    || die "system_ext sepolicy hash MISMATCH in OUT — refusing to stage"
  cmp "$OUT/product/etc/selinux/product_sepolicy_and_mapping.sha256" \
      "$OUT/vendor/etc/selinux/precompiled_sepolicy.product_sepolicy_and_mapping.sha256" \
    || die "product sepolicy hash MISMATCH in OUT — refusing to stage"
  log "  OUT hashes MATCH (plat/system_ext/product) ✓"
}

# ---------------------------------------------------------------------------
# Gate: MTE / memtag_heap strips must not have regressed (Architect binding).
# ---------------------------------------------------------------------------
mte_strip_gate() {
  log "Gate: MTE/memtag_heap device-layer strips must be present (no regress)"
  local bc="$ROOT/vendor/guardtalk/device/rango/BoardConfig-excised-late.mk"
  need "$bc"
  grep -q 'MTE_FORCE_ON' "$bc" || die "BoardConfig-excised-late.mk no longer strips MTE_FORCE_ON — MTE regression"
  grep -q 'memtag_heap' "$bc" || die "BoardConfig-excised-late.mk no longer strips memtag_heap — MTE regression"
  local memtag_mk="$ROOT/vendor/guardtalk/device/rango/guardtalk-memtag.mk"
  need "$memtag_mk"
  grep -q 'PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS' "$memtag_mk" \
    || die "guardtalk-memtag.mk missing PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS"
  local init_bp="$ROOT/system/core/init/Android.bp"
  if [ -f "$init_bp" ]; then
    grep -q 'memtag_heap: false' "$init_bp" \
      || die "system/core/init/Android.bp memtag_heap: false missing — MTE regression"
  fi
  local llvm
  llvm="$(ls -1 "$ROOT"/prebuilts/clang/host/linux-x86/clang-*/bin/llvm-readelf 2>/dev/null | tail -1 || true)"
  if [ -n "$llvm" ] && [ -f "$OUT/system/bin/init" ]; then
    if "$llvm" -n "$OUT/system/bin/init" 2>/dev/null | grep -qi memtag; then
      die "OUT system/bin/init carries a MEMTAG note — MTE strip ineffective, would reproduce 0x7f00"
    fi
    log "  system/bin/init has no MEMTAG note ✓"
  else
    log "  WARN: llvm-readelf or OUT init not found — skipping binary MEMTAG scan (non-fatal)"
  fi
  log "  MTE strips intact ✓"
}

# Patch GT system.img for factory-boot pairing:
#   1) Re-insert stock `restorecon /metadata` before apexd-bootstrap (GOS removed it)
#   2) Strip .note.android.memtag from early networking bins (stock parity)
patch_system_img_for_factory_boot() {
  local img="$1"
  need "$img"
  local llvm objcopy
  llvm="$(ls -1 "$ROOT"/prebuilts/clang/host/linux-x86/clang-*/bin/llvm-readelf 2>/dev/null | tail -1 || true)"
  objcopy="$(ls -1 "$ROOT"/prebuilts/clang/host/linux-x86/clang-*/bin/llvm-objcopy 2>/dev/null | tail -1 || true)"
  [ -n "$llvm" ] || die "llvm-readelf not found"
  [ -n "$objcopy" ] || die "llvm-objcopy not found"
  command -v debugfs >/dev/null || die "debugfs required for system.img patch"

  local tmp
  tmp="$(mktemp -d /tmp/rango-syspatch.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  log "Patching system.img for factory-boot: restorecon /metadata + memtag note strip..."
  debugfs -R "dump /system/etc/init/hw/init.rc $tmp/init.rc" "$img" 2>/dev/null \
    || die "debugfs dump init.rc failed"
  if grep -q 'restorecon /metadata' "$tmp/init.rc"; then
    log "  init.rc already has restorecon /metadata ✓"
  else
    python3 - "$tmp/init.rc" <<'PY' || die "init.rc restorecon patch failed"
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
needle = "    exec_start init_dev_config\n\n    # Run apexd-bootstrap"
insert = (
    "    exec_start init_dev_config\n\n"
    "    # Fix permissions before apexd reads /metadata (stock parity; GOS omitted)\n"
    "    restorecon /metadata\n\n"
    "    # Run apexd-bootstrap"
)
if needle not in text:
    raise SystemExit("init.rc anchor not found for restorecon insert")
p.write_text(text.replace(needle, insert, 1))
PY
    # debugfs cannot safely overwrite in-place with a larger file via `dump` reverse;
    # use rm + write.
    {
      echo "cd /system/etc/init/hw"
      echo "rm init.rc"
      echo "write $tmp/init.rc init.rc"
      echo "set_inode_field init.rc mode 0x81a4"   # 0100644
      echo "set_inode_field init.rc uid 0"
      echo "set_inode_field init.rc gid 0"
    } >"$tmp/dfs.cmd"
    debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
      || die "debugfs write init.rc failed"
    log "  restored restorecon /metadata before apexd-bootstrap ✓"
  fi

  local bin
  for bin in bpfloader netd ip iptables tc ss ndc; do
    debugfs -R "dump /system/bin/$bin $tmp/$bin" "$img" 2>/dev/null || continue
    if ! "$llvm" -n "$tmp/$bin" 2>/dev/null | grep -qi 'android.memtag\|MEMTAG'; then
      continue
    fi
    "$objcopy" --remove-section=.note.android.memtag "$tmp/$bin" "$tmp/$bin.stripped" \
      || die "objcopy strip failed for $bin"
    if "$llvm" -n "$tmp/$bin.stripped" 2>/dev/null | grep -qi 'android.memtag\|MEMTAG'; then
      die "memtag note still present after strip: $bin"
    fi
    {
      echo "cd /system/bin"
      echo "rm $bin"
      echo "write $tmp/$bin.stripped $bin"
      echo "set_inode_field $bin mode 0x81ed"   # 0100755
      echo "set_inode_field $bin uid 0"
      echo "set_inode_field $bin gid 2000"
    } >"$tmp/dfs.cmd"
    debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
      || die "debugfs write $bin failed"
    log "  stripped memtag note from system/bin/$bin ✓"
  done
}

# Replace GT bootstrap linker/libs with stock factory copies and drop
# GuardTalk/userdebug-only init .rc files (rango-20260802-103641 recipe).
# Escapes historical init 0x7f00 far enough to reach apexd-bootstrap.
patch_stock_bootstrap() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock bootstrap patch"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockboot.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  log "Patching system.img: stock bootstrap linker/libs + drop GT-only init .rc..."
  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  debugfs -R "dump /system/bin/bootstrap/linker64 $tmp/linker64" "$stock_img" 2>/dev/null \
    || die "dump stock bootstrap linker64 failed"
  {
    echo "cd /system/bin/bootstrap"
    echo "rm linker64"
    echo "write $tmp/linker64 linker64"
    echo "set_inode_field linker64 mode 0x81ed"
    echo "set_inode_field linker64 uid 0"
    echo "set_inode_field linker64 gid 2000"
  } >"$tmp/dfs.cmd"
  debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
    || die "debugfs write stock linker64 failed"
  log "  stock /system/bin/bootstrap/linker64 ✓"

  local lib
  for lib in libc.so libm.so libdl.so libdl_android.so libclang_rt.hwasan-aarch64-android.so; do
    debugfs -R "dump /system/lib64/bootstrap/$lib $tmp/$lib" "$stock_img" 2>/dev/null || {
      # Stock may lack hwasan — remove GT hwasan bootstrap lib if present.
      if [ "$lib" = "libclang_rt.hwasan-aarch64-android.so" ]; then
        debugfs -w -R "rm /system/lib64/bootstrap/$lib" "$img" >/dev/null 2>&1 || true
        log "  removed GT bootstrap $lib (absent on stock) ✓"
        continue
      fi
      die "dump stock bootstrap $lib failed"
    }
    {
      echo "cd /system/lib64/bootstrap"
      echo "rm $lib"
      echo "write $tmp/$lib $lib"
      echo "set_inode_field $lib mode 0x81ed"
      echo "set_inode_field $lib uid 0"
      echo "set_inode_field $lib gid 2000"
    } >"$tmp/dfs.cmd"
    debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
      || die "debugfs write stock bootstrap $lib failed"
    log "  stock /system/lib64/bootstrap/$lib ✓"
  done

  # Drop GT/userdebug-only init .rc files stock lacks (103641 inventory).
  local rc
  for rc in \
    atrace_userdebug.rc \
    bootstat-debug.rc \
    clean_scratch_files.rc \
    init-debug.rc \
    init.guardtalk.hardening.rc \
    init.guardtalk.privacy_tmpfs.rc \
    llkd-debuggable.rc \
    logcatd.rc \
    logtagd.rc \
    profcollectd.rc
  do
    if debugfs -R "stat /system/etc/init/$rc" "$img" >/dev/null 2>&1; then
      debugfs -w -R "rm /system/etc/init/$rc" "$img" >/dev/null 2>&1 \
        || die "failed to remove /system/etc/init/$rc"
      log "  removed init/$rc ✓"
    fi
  done
}

# EARLY_VM compiles com.android.virt into apexd kBootstrapApexes. With factory
# pvmfw + factory kernel, activating GT virt during apexd-bootstrap is the
# leading cause of reboot_on_failure → bootloader (0xfc). Drop the preinstalled
# apex so OnBootstrap skips it (missing ≠ hard-required).
patch_drop_bootstrap_virt() {
  local img="$1"
  need "$img"
  command -v debugfs >/dev/null || die "debugfs required to drop virt apex"

  if debugfs -R "stat /system/apex/com.android.virt.apex" "$img" >/dev/null 2>&1; then
    debugfs -w -R "rm /system/apex/com.android.virt.apex" "$img" >/dev/null 2>&1 \
      || die "failed to remove com.android.virt.apex"
    log "  dropped /system/apex/com.android.virt.apex (EARLY_VM bootstrap bisect/fix) ✓"
  else
    log "  com.android.virt.apex already absent ✓"
  fi
}

# Replace GT kBootstrapApexes that have stock equivalents.
# Stock ships tzdata as com.google.android.tzdata6.apex but deapexer info
# reports manifest name "com.android.tzdata" (same as GT) — graft by writing
# stock bytes to /system/apex/com.android.tzdata.apex (package-name bridge).
# OnBootstrap skip-safe alternative (drop) left unused: missing ≠ hard-required
# in apexd.cpp OnBootstrap, but product needs timezone data content.
# VNDK: neither stock nor GT OUT ship com.android.vndk.v* preinstalled apexes
# (ro.vndk.version empty) — no VNDK graft. No manifest bootstrap()/vendorbootstrap()
# flags found on 123756 scan; only hardcoded kBootstrapApexes apply.
patch_stock_bootstrap_apexes() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock bootstrap apex graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockapex.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock tzdata + runtime + i18n bootstrap apexes..."
  # Order matters: debugfs 1.47 write of tzdata AFTER runtime/i18n corrupts the
  # earlier apex payload (bad zip CRC; reproduced 2026-08-02). Safe order is
  # tzdata → runtime → i18n. Hard cmp gate after all writes (fail-closed).
  local apex
  # Filename differs on stock; manifest name is com.android.tzdata.
  debugfs -R "dump /system/apex/com.google.android.tzdata6.apex $tmp/com.android.tzdata.apex" \
    "$stock_img" 2>/dev/null \
    || die "dump stock com.google.android.tzdata6.apex failed"
  for apex in com.android.runtime.apex com.android.i18n.apex; do
    debugfs -R "dump /system/apex/$apex $tmp/$apex" "$stock_img" 2>/dev/null \
      || die "dump stock $apex failed"
  done

  for apex in com.android.tzdata.apex com.android.runtime.apex com.android.i18n.apex; do
    {
      echo "cd /system/apex"
      echo "rm $apex"
      echo "write $tmp/$apex $apex"
      echo "set_inode_field $apex mode 0x81a4"
      echo "set_inode_field $apex uid 0"
      echo "set_inode_field $apex gid 0"
    } >"$tmp/dfs.cmd"
    debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
      || die "debugfs write stock $apex failed"
    if [ "$apex" = "com.android.tzdata.apex" ]; then
      log "  stock /system/apex/$apex ← com.google.android.tzdata6.apex ✓"
    else
      log "  stock /system/apex/$apex ✓"
    fi
  done

  for apex in com.android.tzdata.apex com.android.runtime.apex com.android.i18n.apex; do
    debugfs -R "dump /system/apex/$apex $tmp/verify-$apex" "$img" 2>/dev/null \
      || die "verify dump $apex failed"
    cmp -s "$tmp/$apex" "$tmp/verify-$apex" \
      || die "stock apex graft corrupt after debugfs write: $apex (cmp mismatch)"
    log "  verify cmp $apex ✓"
  done
}

# Graft stock /system/bin/apexd onto GT system.img (T-RANGO-BOOT-APEXD).
# GT apexd differs from stock (sizes 1030416 vs 1083368; cmp differs).
# apexd.rc already MATCH stock on 130756 — only the binary is grafted.
# Interpreter is /system/bin/bootstrap/linker64 (already stock via
# patch_stock_bootstrap). Hard cmp gate after write (fail-closed).
patch_stock_apexd() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock apexd graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockapexd.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/bin/apexd..."
  debugfs -R "dump /system/bin/apexd $tmp/apexd" "$stock_img" 2>/dev/null \
    || die "dump stock /system/bin/apexd failed"
  {
    echo "cd /system/bin"
    echo "rm apexd"
    echo "write $tmp/apexd apexd"
    echo "set_inode_field apexd mode 0x81ed"
    echo "set_inode_field apexd uid 0"
    echo "set_inode_field apexd gid 2000"
  } >"$tmp/dfs.cmd"
  debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
    || die "debugfs write stock apexd failed"
  debugfs -R "dump /system/bin/apexd $tmp/verify-apexd" "$img" 2>/dev/null \
    || die "verify dump apexd failed"
  cmp -s "$tmp/apexd" "$tmp/verify-apexd" \
    || die "stock apexd graft corrupt after debugfs write (cmp mismatch)"
  log "  stock /system/bin/apexd ($(stat -c%s "$tmp/apexd") bytes) verify cmp ✓"
}

# Graft stock /system/etc/ueventd.rc (T-RANGO-BOOT-UEVENTD).
# 103210: stock apexd + stock bootstrap apexes still 0xfc ~18s.
# Host: stock has `/dev/block/mapper/*.apex 0644 root system`;
# GT has `/dev/block/dm-* 0640 root system` instead. plat_file_contexts
# already names mapper/*.apex → apex_dm_device, but ueventd never creates
# those nodes on GT. Hard cmp + named-line gate.
patch_stock_ueventd_rc() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock ueventd.rc graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-ueventd.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/ueventd.rc..."
  debugfs -R "dump /system/etc/ueventd.rc $tmp/ueventd.rc" "$stock_img" >/dev/null 2>&1 \
    || die "dump stock /system/etc/ueventd.rc failed"
  grep -q '/dev/block/mapper/\*\.apex' "$tmp/ueventd.rc" \
    || die "stock ueventd.rc missing /dev/block/mapper/*.apex rule"
  _debugfs_graft_file "$img" "/system/etc/ueventd.rc" "$tmp/ueventd.rc" 0x81a4 0 0
  log "  stock /system/etc/ueventd.rc ($(stat -c%s "$tmp/ueventd.rc") bytes) verify cmp ✓"
}

# Graft stock /system/build.prop (T-RANGO-BOOT-PROP).
# 115437: wholesale stock /system/apex still 0xfc. Remaining named
# non-apex surface: GT build.prop (Baklava/userdebug, preview_sdk=1,
# apexd.config.compressed_apex=false) vs stock (REL/user, compressed_apex=true).
# Hard cmp + named-line gate.
patch_stock_build_prop() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock build.prop graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-buildprop.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/build.prop..."
  debugfs -R "dump /system/build.prop $tmp/build.prop" "$stock_img" >/dev/null 2>&1 \
    || die "dump stock /system/build.prop failed"
  grep -q 'apexd.config.compressed_apex=true' "$tmp/build.prop" \
    || die "stock build.prop missing apexd.config.compressed_apex=true"
  grep -q 'ro.build.version.codename=REL' "$tmp/build.prop" \
    || die "stock build.prop missing ro.build.version.codename=REL"
  _debugfs_graft_file "$img" "/system/build.prop" "$tmp/build.prop" 0x81a4 0 0
  log "  stock /system/build.prop ($(stat -c%s "$tmp/build.prop") bytes) verify cmp ✓"
}

# Graft stock apexd NEEDED /system/lib64 files that still DIFF on 123449
# (T-RANGO-BOOT-APEXDLIBS). Host walk: apexd closure 27 libs; 21 MATCH
# (initlibs overlap); 6 DIFF. apexd launches (0xfc not 0x7f00) so these
# load, but leftover GT binder/vintf/zip can fail ActivateApexPackages.
# Hard cmp per file.
patch_stock_apexd_needed_libs() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock apexd-libs graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-apexdlibs.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock apexd NEEDED DIFF /system/lib64 (6 libs)..."
  local lib
  for lib in \
      apex_aidl_interface-cpp.so \
      libbinder.so \
      libvintf.so \
      libziparchive.so \
      libapexsupport.so \
      libtinyxml2.so; do
    debugfs -R "dump /system/lib64/$lib $tmp/$lib" "$stock_img" >/dev/null 2>&1 \
      || die "dump stock /system/lib64/$lib failed"
    _debugfs_graft_file "$img" "/system/lib64/$lib" "$tmp/$lib" 0x81a4 0 0
    log "  stock /system/lib64/$lib ($(stat -c%s "$tmp/$lib") bytes) verify cmp ✓"
  done
}

# Graft stock plat_property_contexts (T-RANGO-BOOT-PCTX).
# 064000: stock apexd + stock apexd NEEDED libs still 0xfc. sepolicy graft
# covered plat_file_contexts + plat_sepolicy.cil but NOT
# plat_property_contexts (init loads it at property_service.cpp).
# Stock has apexd.config.runtime.erofs_file_backed_mount; GT ABSENT.
# Hard cmp + named-line gate.
patch_stock_plat_property_contexts() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock plat_property_contexts graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-pctx.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/selinux/plat_property_contexts..."
  debugfs -R "dump /system/etc/selinux/plat_property_contexts $tmp/pctx" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock plat_property_contexts failed"
  grep -q 'apexd.config.runtime.erofs_file_backed_mount' "$tmp/pctx" \
    || die "stock plat_property_contexts missing erofs_file_backed_mount"
  grep -q 'ro.cold_boot_done' "$tmp/pctx" \
    || die "stock plat_property_contexts missing ro.cold_boot_done"
  _debugfs_graft_file "$img" "/system/etc/selinux/plat_property_contexts" \
    "$tmp/pctx" 0x81a4 0 0
  log "  stock plat_property_contexts ($(stat -c%s "$tmp/pctx") bytes) verify cmp ✓"
}

# Graft leftover plat context files omitted by the sepolicy graft
# (T-RANGO-BOOT-PLATCTX). 071944: stock init.rc still 0xfc. Host DIFF:
# service/seapp/mac + keystore2 + tee. plat_hwservice MATCH — skip.
# Hard cmp per file.
patch_stock_remaining_plat_contexts() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for leftover plat-context graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-platctx.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: leftover stock plat contexts (5 files)..."
  local f
  for f in \
      plat_service_contexts \
      plat_seapp_contexts \
      plat_mac_permissions.xml \
      plat_keystore2_key_contexts \
      plat_tee_service_contexts; do
    debugfs -R "dump /system/etc/selinux/$f $tmp/$f" "$stock_img" >/dev/null 2>&1 \
      || die "dump stock /system/etc/selinux/$f failed"
    _debugfs_graft_file "$img" "/system/etc/selinux/$f" "$tmp/$f" 0x81a4 0 0
    log "  stock /system/etc/selinux/$f ($(stat -c%s "$tmp/$f") bytes) verify cmp ✓"
  done
}

# Graft leftover early-init surface (T-RANGO-BOOT-EARLYINIT).
# 073937: leftover plat contexts still 0xfc. Host: aconfigd.rc runs on
# early-init and stock has restorecon_recursive /metadata (GT ABSENT).
# Also graft remaining DIFF init/*.rc + hw usb/zygote + early-init bins.
patch_stock_early_init_surface() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for early-init graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-earlyinit.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: leftover early-init rc + bins..."
  local f
  for f in \
      aconfigd.rc \
      android.system.suspend-service.rc \
      logd.rc \
      mmd.rc \
      netbpfload.rc \
      perfetto.rc \
      prefetch.rc \
      casefolding_remover.rc; do
    debugfs -R "dump /system/etc/init/$f $tmp/$f" "$stock_img" >/dev/null 2>&1 \
      || die "dump stock /system/etc/init/$f failed"
    if debugfs -R "stat /system/etc/init/$f" "$img" 2>&1 | grep -q 'File not found'; then
      {
        echo "cd /system/etc/init"
        echo "write $tmp/$f $f"
        echo "set_inode_field $f mode 0x81a4"
        echo "set_inode_field $f uid 0"
        echo "set_inode_field $f gid 0"
      } >"$tmp/dfs-new.cmd"
      debugfs -w -f "$tmp/dfs-new.cmd" "$img" >/dev/null 2>&1 \
        || die "debugfs write new /system/etc/init/$f failed"
      debugfs -R "dump /system/etc/init/$f $tmp/verify-$f" "$img" >/dev/null 2>&1 \
        || die "verify dump new /system/etc/init/$f failed"
      cmp -s "$tmp/$f" "$tmp/verify-$f" \
        || die "new /system/etc/init/$f graft corrupt (cmp mismatch)"
    else
      _debugfs_graft_file "$img" "/system/etc/init/$f" "$tmp/$f" 0x81a4 0 0
    fi
    log "  stock /system/etc/init/$f ($(stat -c%s "$tmp/$f") bytes) verify cmp ✓"
  done
  grep -q 'restorecon_recursive /metadata' "$tmp/aconfigd.rc" \
    || die "stock aconfigd.rc missing restorecon_recursive /metadata"

  for f in init.usb.rc init.zygote32.rc init.zygote64.rc init.zygote64_32.rc; do
    debugfs -R "dump /system/etc/init/hw/$f $tmp/$f" "$stock_img" >/dev/null 2>&1 \
      || die "dump stock /system/etc/init/hw/$f failed"
    _debugfs_graft_file "$img" "/system/etc/init/hw/$f" "$tmp/$f" 0x81a4 0 0
    log "  stock /system/etc/init/hw/$f ($(stat -c%s "$tmp/$f") bytes) verify cmp ✓"
  done

  for f in aconfigd-system prng_seeder; do
    debugfs -R "dump /system/bin/$f $tmp/$f" "$stock_img" >/dev/null 2>&1 \
      || die "dump stock /system/bin/$f failed"
    _debugfs_graft_file "$img" "/system/bin/$f" "$tmp/$f" 0x81ed 0 2000
    log "  stock /system/bin/$f ($(stat -c%s "$tmp/$f") bytes) verify cmp ✓"
  done
}

# Graft stock libprotobuf-cpp-full (T-RANGO-BOOT-PROTOBUF).
# 092118: apexd NEEDED all size-MATCH; only protobuf is cmp DIFF at
# same size 3387232. apexd has no dlopen — this is the leftover
# parser lib for apex manifests. Hard cmp (size gates are insufficient).
patch_stock_protobuf() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for protobuf graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-protobuf.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock libprotobuf-cpp-full-6.33.1.so..."
  debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $tmp/pb.so" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock libprotobuf-cpp-full-6.33.1.so failed"
  [ "$(stat -c%s "$tmp/pb.so")" = "3387232" ] \
    || die "stock protobuf unexpected size $(stat -c%s "$tmp/pb.so")"
  _debugfs_graft_file "$img" "/system/lib64/libprotobuf-cpp-full-6.33.1.so" \
    "$tmp/pb.so" 0x81a4 0 0
  log "  stock libprotobuf-cpp-full-6.33.1.so (3387232 bytes) verify cmp ✓"
}

# Graft stock libc++.so (T-RANGO-BOOT-LIBCXX).
# 094500: protobuf graft changed 0xfc → KP 0x00000100 ~61s.
# init+apexd+protobuf recursive NEEDED: only libc++.so is still
# size-MATCH cmp-DIFF (1152784). Hard cmp (size gates hid this).
patch_stock_libcxx() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for libc++ graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-libcxx.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/lib64/libc++.so..."
  debugfs -R "dump /system/lib64/libc++.so $tmp/libcxx.so" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock libc++.so failed"
  [ "$(stat -c%s "$tmp/libcxx.so")" = "1152784" ] \
    || die "stock libc++ unexpected size $(stat -c%s "$tmp/libcxx.so")"
  _unshare_ext4_blocks "$img"
  _debugfs_graft_file "$img" "/system/lib64/libc++.so" \
    "$tmp/libcxx.so" 0x81a4 0 0
  log "  stock /system/lib64/libc++.so (1152784 bytes) verify cmp ✓"

  debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $tmp/pb-after.so" \
    "$img" >/dev/null 2>&1 \
    || die "dump protobuf after libc++ graft failed"
  debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $tmp/pb-stock.so" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock protobuf after libc++ graft failed"
  if ! cmp -s "$tmp/pb-after.so" "$tmp/pb-stock.so"; then
    log "  protobuf stomped after libc++ — re-grafting protobuf (shared_blocks should be gone)..."
    patch_stock_protobuf "$img"
    debugfs -R "dump /system/lib64/libc++.so $tmp/cxx-after.so" \
      "$img" >/dev/null 2>&1 \
      || die "dump libc++ after protobuf re-graft failed"
    cmp -s "$tmp/libcxx.so" "$tmp/cxx-after.so" \
      || die "libc++ stomped by protobuf re-graft after unshare"
    log "  protobuf re-grafted; libc++ still MATCH ✓"
  fi
}

# Graft stock ld-android.so (T-RANGO-BOOT-LDANDROID).
# 062622: stock libc++ re-opened 0xfc ~18s AB 31111111 (NOT a boot
# cure). After protobuf+libcxx, init+apexd+protobuf NEEDED is MATCH.
# Leftover cmp-DIFF: /system/lib64/ld-android.so size MATCH 34256
# (sha256 GT eb3c8339… vs stock b7f2f786…; same GT hash on 094500).
# Hard cmp (size gates hid this). Unshare shared_blocks before write.
patch_stock_ldandroid() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for ld-android graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-ldandroid.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/lib64/ld-android.so..."
  debugfs -R "dump /system/lib64/ld-android.so $tmp/ld-android.so" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock ld-android.so failed"
  [ "$(stat -c%s "$tmp/ld-android.so")" = "34256" ] \
    || die "stock ld-android unexpected size $(stat -c%s "$tmp/ld-android.so")"
  _unshare_ext4_blocks "$img"
  _debugfs_graft_file "$img" "/system/lib64/ld-android.so" \
    "$tmp/ld-android.so" 0x81a4 0 0
  log "  stock /system/lib64/ld-android.so (34256 bytes) verify cmp ✓"

  debugfs -R "dump /system/lib64/libc++.so $tmp/cxx-after.so" \
    "$img" >/dev/null 2>&1 \
    || die "dump libc++ after ld-android graft failed"
  debugfs -R "dump /system/lib64/libc++.so $tmp/cxx-stock.so" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock libc++ after ld-android graft failed"
  if ! cmp -s "$tmp/cxx-after.so" "$tmp/cxx-stock.so"; then
    log "  libc++ stomped after ld-android — re-grafting libc++ (shared_blocks should be gone)..."
    patch_stock_libcxx "$img"
    debugfs -R "dump /system/lib64/ld-android.so $tmp/ld-after.so" \
      "$img" >/dev/null 2>&1 \
      || die "dump ld-android after libc++ re-graft failed"
    cmp -s "$tmp/ld-android.so" "$tmp/ld-after.so" \
      || die "ld-android stomped by libc++ re-graft after unshare"
    log "  libc++ re-grafted; ld-android still MATCH ✓"
  fi

  debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $tmp/pb-after.so" \
    "$img" >/dev/null 2>&1 \
    || die "dump protobuf after ld-android graft failed"
  debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $tmp/pb-stock.so" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock protobuf after ld-android graft failed"
  if ! cmp -s "$tmp/pb-after.so" "$tmp/pb-stock.so"; then
    log "  protobuf stomped after ld-android — re-grafting protobuf..."
    patch_stock_protobuf "$img"
    debugfs -R "dump /system/lib64/ld-android.so $tmp/ld-after-pb.so" \
      "$img" >/dev/null 2>&1 \
      || die "dump ld-android after protobuf re-graft failed"
    cmp -s "$tmp/ld-android.so" "$tmp/ld-after-pb.so" \
      || die "ld-android stomped by protobuf re-graft after unshare"
    debugfs -R "dump /system/lib64/libc++.so $tmp/cxx-after-pb.so" \
      "$img" >/dev/null 2>&1 \
      || die "dump libc++ after protobuf re-graft failed"
    cmp -s "$tmp/cxx-stock.so" "$tmp/cxx-after-pb.so" \
      || die "libc++ stomped by protobuf re-graft after unshare"
    log "  protobuf re-grafted; ld-android + libc++ still MATCH ✓"
  fi
}

# Graft stock /system/etc/apexd/empty_erofs.img (T-RANGO-BOOT-APEXDETC).
# 123801: stock ld-android still 0xfc ~18s AB 11111111. After
# protobuf+libcxx+ld-android MATCH, leftover is stock-only
# /system/etc/apexd/empty_erofs.img (4096; dir ABSENT on inverted).
# Hard cmp. Unshare before mkdir/write.
patch_stock_apexdetc() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for apexd etc graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-apexdetc.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/apexd/empty_erofs.img..."
  debugfs -R "dump /system/etc/apexd/empty_erofs.img $tmp/empty_erofs.img" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock /system/etc/apexd/empty_erofs.img failed"
  [ "$(stat -c%s "$tmp/empty_erofs.img")" = "4096" ] \
    || die "stock empty_erofs.img unexpected size $(stat -c%s "$tmp/empty_erofs.img")"
  _unshare_ext4_blocks "$img"
  if debugfs -R "stat /system/etc/apexd" "$img" 2>&1 | grep -q 'File not found'; then
    {
      echo "cd /system/etc"
      echo "mkdir apexd"
    } >"$tmp/dfs-mkdir.cmd"
    debugfs -w -f "$tmp/dfs-mkdir.cmd" "$img" >/dev/null 2>&1 \
      || die "debugfs mkdir /system/etc/apexd failed"
  fi
  {
    echo "cd /system/etc/apexd"
    echo "rm empty_erofs.img"
    echo "write $tmp/empty_erofs.img empty_erofs.img"
    echo "set_inode_field empty_erofs.img mode 0x81a4"
    echo "set_inode_field empty_erofs.img uid 0"
    echo "set_inode_field empty_erofs.img gid 0"
  } >"$tmp/dfs-erofs.cmd"
  debugfs -w -f "$tmp/dfs-erofs.cmd" "$img" >/dev/null 2>&1 \
    || die "debugfs write /system/etc/apexd/empty_erofs.img failed"
  debugfs -R "dump /system/etc/apexd/empty_erofs.img $tmp/verify-erofs.img" \
    "$img" >/dev/null 2>&1 \
    || die "verify dump empty_erofs.img failed"
  cmp -s "$tmp/empty_erofs.img" "$tmp/verify-erofs.img" \
    || die "empty_erofs.img graft corrupt (cmp mismatch)"
  log "  stock /system/etc/apexd/empty_erofs.img (4096 bytes) verify cmp ✓"
}

# Graft stock /system/etc/task_profiles.json (T-RANGO-BOOT-TASKPROF).
# 135504: empty_erofs still 0xfc ~17s AB 11111111. After
# protobuf+libcxx+ld-android+empty_erofs MATCH, leftover on the
# stock-init path is task_profiles.json (cgroups.json already MATCH).
# Hard cmp. Unshare before write. Re-check empty_erofs sibling.
patch_stock_taskprof() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for task_profiles graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-taskprof.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/task_profiles.json..."
  debugfs -R "dump /system/etc/task_profiles.json $tmp/task_profiles.json" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock /system/etc/task_profiles.json failed"
  [ "$(stat -c%s "$tmp/task_profiles.json")" = "15365" ] \
    || die "stock task_profiles.json unexpected size $(stat -c%s "$tmp/task_profiles.json")"
  _unshare_ext4_blocks "$img"
  _debugfs_graft_file "$img" "/system/etc/task_profiles.json" \
    "$tmp/task_profiles.json" 0x81a4 0 0
  log "  stock /system/etc/task_profiles.json (15365 bytes) verify cmp ✓"

  debugfs -R "dump /system/etc/apexd/empty_erofs.img $tmp/erofs-after.img" \
    "$img" >/dev/null 2>&1 \
    || die "dump empty_erofs after task_profiles graft failed"
  debugfs -R "dump /system/etc/apexd/empty_erofs.img $tmp/erofs-stock.img" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock empty_erofs after task_profiles graft failed"
  cmp -s "$tmp/erofs-after.img" "$tmp/erofs-stock.img" \
    || die "empty_erofs.img stomped by task_profiles graft"
  debugfs -R "dump /system/etc/cgroups.json $tmp/cg-after.json" \
    "$img" >/dev/null 2>&1 \
    || die "dump cgroups.json after task_profiles graft failed"
  debugfs -R "dump /system/etc/cgroups.json $tmp/cg-stock.json" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock cgroups.json after task_profiles graft failed"
  cmp -s "$tmp/cg-after.json" "$tmp/cg-stock.json" \
    || die "cgroups.json stomped by task_profiles graft"
  log "  empty_erofs + cgroups.json still MATCH after task_profiles ✓"
}

# Graft stock /system/etc/aconfig storage (T-RANGO-BOOT-ACONFIG).
# 142515: task_profiles still 0xfc ~18s AB 11111111. After
# task_profiles MATCH, leftover aconfigd reads on early-init is
# /system/etc/aconfig/{flag.info,flag.map,flag.val,package.map}.
# aconfigd.rc + aconfigd-system already stock. Hard cmp. Unshare.
# Re-check task_profiles sibling.
patch_stock_aconfig() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for aconfig graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-aconfig.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/aconfig storage (4 files)..."
  local f expected
  for f in flag.info:1673 flag.map:100550 flag.val:1673 package.map:9725; do
    local name="${f%%:*}"
    expected="${f##*:}"
    debugfs -R "dump /system/etc/aconfig/$name $tmp/$name" \
      "$stock_img" >/dev/null 2>&1 \
      || die "dump stock /system/etc/aconfig/$name failed"
    [ "$(stat -c%s "$tmp/$name")" = "$expected" ] \
      || die "stock aconfig/$name unexpected size $(stat -c%s "$tmp/$name")"
  done
  _unshare_ext4_blocks "$img"
  for f in flag.info flag.map flag.val package.map; do
    _debugfs_graft_file "$img" "/system/etc/aconfig/$f" \
      "$tmp/$f" 0x81a4 0 0
    log "  stock /system/etc/aconfig/$f ($(stat -c%s "$tmp/$f") bytes) verify cmp ✓"
  done

  debugfs -R "dump /system/etc/task_profiles.json $tmp/tp-after.json" \
    "$img" >/dev/null 2>&1 \
    || die "dump task_profiles after aconfig graft failed"
  debugfs -R "dump /system/etc/task_profiles.json $tmp/tp-stock.json" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock task_profiles after aconfig graft failed"
  cmp -s "$tmp/tp-after.json" "$tmp/tp-stock.json" \
    || die "task_profiles.json stomped by aconfig graft"
  log "  task_profiles.json still MATCH after aconfig ✓"
}

# Graft stock /system/etc/aconfig_flags.pb (T-RANGO-BOOT-ACFLAGS).
# 144322: aconfig storage still 0xfc ~18s AB 11111111. After
# /system/etc/aconfig MATCH, leftover DeviceConfig proto is
# aconfig_flags.pb (957155 vs stock 696328). Hard cmp. Unshare.
# Re-check aconfig/flag.map sibling.
patch_stock_acflags() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for aconfig_flags graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-acflags.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/aconfig_flags.pb..."
  debugfs -R "dump /system/etc/aconfig_flags.pb $tmp/aconfig_flags.pb" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock /system/etc/aconfig_flags.pb failed"
  [ "$(stat -c%s "$tmp/aconfig_flags.pb")" = "696328" ] \
    || die "stock aconfig_flags.pb unexpected size $(stat -c%s "$tmp/aconfig_flags.pb")"
  _unshare_ext4_blocks "$img"
  _debugfs_graft_file "$img" "/system/etc/aconfig_flags.pb" \
    "$tmp/aconfig_flags.pb" 0x81a4 0 0
  log "  stock /system/etc/aconfig_flags.pb (696328 bytes) verify cmp ✓"

  debugfs -R "dump /system/etc/aconfig/flag.map $tmp/fmap-after" \
    "$img" >/dev/null 2>&1 \
    || die "dump flag.map after aconfig_flags graft failed"
  debugfs -R "dump /system/etc/aconfig/flag.map $tmp/fmap-stock" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock flag.map after aconfig_flags graft failed"
  cmp -s "$tmp/fmap-after" "$tmp/fmap-stock" \
    || die "aconfig/flag.map stomped by aconfig_flags graft"
  log "  aconfig/flag.map still MATCH after aconfig_flags ✓"
}

# Graft stock /system/etc/build_flags.json (T-RANGO-BOOT-BFLAGS).
# 150620: aconfig_flags still 0xfc ~18s AB 11111111. After
# aconfig_flags.pb MATCH, leftover named flag dump is
# build_flags.json (157219 vs stock 124580). Hard cmp. Unshare.
# Re-check aconfig_flags sibling.
patch_stock_bflags() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for build_flags graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-bflags.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/build_flags.json..."
  debugfs -R "dump /system/etc/build_flags.json $tmp/build_flags.json" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock /system/etc/build_flags.json failed"
  [ "$(stat -c%s "$tmp/build_flags.json")" = "124580" ] \
    || die "stock build_flags.json unexpected size $(stat -c%s "$tmp/build_flags.json")"
  _unshare_ext4_blocks "$img"
  _debugfs_graft_file "$img" "/system/etc/build_flags.json" \
    "$tmp/build_flags.json" 0x81a4 0 0
  log "  stock /system/etc/build_flags.json (124580 bytes) verify cmp ✓"

  debugfs -R "dump /system/etc/aconfig_flags.pb $tmp/ac-after.pb" \
    "$img" >/dev/null 2>&1 \
    || die "dump aconfig_flags after build_flags graft failed"
  debugfs -R "dump /system/etc/aconfig_flags.pb $tmp/ac-stock.pb" \
    "$stock_img" >/dev/null 2>&1 \
    || die "dump stock aconfig_flags after build_flags graft failed"
  cmp -s "$tmp/ac-after.pb" "$tmp/ac-stock.pb" \
    || die "aconfig_flags.pb stomped by build_flags graft"
  log "  aconfig_flags.pb still MATCH after build_flags ✓"
}

# Graft stock /system/bin/init onto GT system.img (T-RANGO-BOOT-INIT).
# On 132759 (stockapexd): apexd/apexd.rc MATCH stock; init DIFFERS
# (GT 2938144 vs stock 2771368). Hard cmp gate after write (fail-closed).
# Mode bits match stock: 0755 uid0 gid2000 (init_exec).
patch_stock_init() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock init graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockinit.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/bin/init..."
  debugfs -R "dump /system/bin/init $tmp/init" "$stock_img" 2>/dev/null \
    || die "dump stock /system/bin/init failed"
  {
    echo "cd /system/bin"
    echo "rm init"
    echo "write $tmp/init init"
    echo "set_inode_field init mode 0x81ed"
    echo "set_inode_field init uid 0"
    echo "set_inode_field init gid 2000"
  } >"$tmp/dfs.cmd"
  debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
    || die "debugfs write stock init failed"
  debugfs -R "dump /system/bin/init $tmp/verify-init" "$img" 2>/dev/null \
    || die "verify dump init failed"
  cmp -s "$tmp/init" "$tmp/verify-init" \
    || die "stock init graft corrupt after debugfs write (cmp mismatch)"
  log "  stock /system/bin/init ($(stat -c%s "$tmp/init") bytes) verify cmp ✓"
}

# Graft stock /system/lib64 transitive NEEDED by stock /system/bin/init
# (T-RANGO-BOOT-INITLIBS / MODE=gtsystemonstockinitlibs).
# 104334: stock init + stock bootstrap MATCH, still KP 0x00000100 ~60s.
# Host: 27 /system/lib64 deps all DIFF vs stock; libfec_rs.so ABSENT on GT.
# Bionic (libc/libm/libdl*) stay on the bootstrap graft. Hard cmp gates.
patch_stock_init_needed_libs() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock init-lib graft"
  command -v python3 >/dev/null || die "python3 required for init NEEDED walk"
  local llvm
  llvm="$(ls -1 "$ROOT"/prebuilts/clang/host/linux-x86/clang-*/bin/llvm-readelf 2>/dev/null | tail -1 || true)"
  [ -n "$llvm" ] || die "llvm-readelf not found"

  local tmp
  tmp="$(mktemp -d /tmp/rango-initlibs.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  debugfs -R "dump /system/bin/init $tmp/stock-init" "$stock_img" >/dev/null 2>&1 \
    || die "dump stock init for NEEDED walk failed"

  log "Patching system.img: stock init NEEDED /system/lib64 closure..."
  INITLIBS_LLVM="$llvm" INITLIBS_STOCK="$stock_img" INITLIBS_TMP="$tmp" \
    python3 - <<'PY' || die "init NEEDED walk failed"
import os, subprocess
llvm = os.environ["INITLIBS_LLVM"]
stock = os.environ["INITLIBS_STOCK"]
tmp = os.environ["INITLIBS_TMP"]
bionic = {
    "libc.so", "libm.so", "libdl.so", "libdl_android.so",
    "libclang_rt.hwasan-aarch64-android.so",
}

def dump(src, dest):
    subprocess.run(["debugfs", "-R", f"dump {src} {dest}", stock],
                   capture_output=True, check=False)
    return os.path.exists(dest) and os.path.getsize(dest) > 0

def needed(elf):
    r = subprocess.run([llvm, "-d", elf], capture_output=True, text=True)
    libs = []
    for ln in r.stdout.splitlines():
        if "NEEDED" in ln and "[" in ln:
            libs.append(ln.split("[")[1].split("]")[0])
    return libs

queue = needed(os.path.join(tmp, "stock-init"))
seen = set()
closure = []
while queue:
    lib = queue.pop(0)
    if lib in seen:
        continue
    if lib in bionic:
        seen.add(lib)
        continue
    seen.add(lib)
    dest = os.path.join(tmp, f"st-{lib}")
    if not dump(f"/system/lib64/{lib}", dest):
        raise SystemExit(f"stock missing /system/lib64/{lib}")
    closure.append(lib)
    for n in needed(dest):
        if n not in seen:
            queue.append(n)
if not closure:
    raise SystemExit("empty init NEEDED closure")
with open(os.path.join(tmp, "closure.list"), "w") as f:
    f.write("\n".join(closure) + "\n")
print(f"  init NEEDED closure: {len(closure)} libs")
PY

  # Small allocator headroom for stock-larger libs (libc++ / libcrypto / libfec_rs).
  command -v resize2fs >/dev/null || die "resize2fs required for initlibs headroom"
  command -v e2fsck >/dev/null || die "e2fsck required for initlibs headroom"
  local cur_size new_size fsck_rc=0
  cur_size="$(stat -c%s "$img")"
  new_size=$((cur_size + 16777216))
  e2fsck -fy "$img" >/dev/null 2>&1 || fsck_rc=$?
  [ "$fsck_rc" -le 2 ] || die "e2fsck pre-grow FAILED (rc=$fsck_rc) on $img"
  truncate -s "$new_size" "$img" || die "truncate grow failed on $img"
  resize2fs "$img" >/dev/null 2>&1 || die "resize2fs grow failed on $img"
  log "  grew system.img $cur_size -> $new_size (+16MiB initlibs headroom) ✓"

  local n=0 lib
  while IFS= read -r lib; do
    [ -n "$lib" ] || continue
    [ -s "$tmp/st-$lib" ] || die "stock dump missing for $lib"
    if ! debugfs -R "stat /system/lib64/$lib" "$img" >/dev/null 2>&1; then
      {
        echo "cd /system/lib64"
        echo "write $tmp/st-$lib $lib"
        echo "set_inode_field $lib mode 0x81a4"
        echo "set_inode_field $lib uid 0"
        echo "set_inode_field $lib gid 0"
      } >"$tmp/dfs.cmd"
      debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
        || die "debugfs write new $lib failed"
      debugfs -R "dump /system/lib64/$lib $tmp/verify-$lib" "$img" >/dev/null 2>&1 \
        || die "verify dump new $lib failed"
      cmp -s "$tmp/st-$lib" "$tmp/verify-$lib" \
        || die "new graft corrupt: $lib"
    else
      _debugfs_graft_file "$img" "/system/lib64/$lib" "$tmp/st-$lib" 0x81a4 0 0
    fi
    n=$((n + 1))
    log "  stock /system/lib64/$lib ($(stat -c%s "$tmp/st-$lib") bytes) verify cmp ✓"
  done <"$tmp/closure.list"
  [ "$n" -ge 20 ] || die "initlibs grafted $n libs (expected >=20)"
  log "  stock init NEEDED closure grafted ($n libs) ✓"
}

# Graft stock /system/etc/init/hw/init.rc onto stockapexd+GT-init composition
# (T-RANGO-BOOT-POSTINIT / MODE=stockapexcfg). perform_apex_config is an init
# builtin (system/core/init/builtins.cpp); this grafts the early init.rc
# script surface that runs exec_start apexd-bootstrap + perform_apex_config.
# Keeps GT /system/bin/init (stock init binary falsified on 141438).
# Hard cmp gate after write (fail-closed). Mode 0644 uid0 gid0.
patch_stock_init_rc() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock init.rc graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockapexcfg.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/etc/init/hw/init.rc..."
  debugfs -R "dump /system/etc/init/hw/init.rc $tmp/init.rc" "$stock_img" 2>/dev/null \
    || die "dump stock /system/etc/init/hw/init.rc failed"
  grep -q 'perform_apex_config' "$tmp/init.rc" \
    || die "stock init.rc missing perform_apex_config (unexpected)"
  grep -q 'exec_start apexd-bootstrap' "$tmp/init.rc" \
    || die "stock init.rc missing exec_start apexd-bootstrap (unexpected)"
  {
    echo "cd /system/etc/init/hw"
    echo "rm init.rc"
    echo "write $tmp/init.rc init.rc"
    echo "set_inode_field init.rc mode 0x81a4"   # 0100644
    echo "set_inode_field init.rc uid 0"
    echo "set_inode_field init.rc gid 0"
  } >"$tmp/dfs.cmd"
  debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
    || die "debugfs write stock init.rc failed"
  debugfs -R "dump /system/etc/init/hw/init.rc $tmp/verify-init.rc" "$img" 2>/dev/null \
    || die "verify dump init.rc failed"
  cmp -s "$tmp/init.rc" "$tmp/verify-init.rc" \
    || die "stock init.rc graft corrupt after debugfs write (cmp mismatch)"
  log "  stock /system/etc/init/hw/init.rc ($(stat -c%s "$tmp/init.rc") bytes) verify cmp ✓"
}

# Graft stock hwasan native deps for runtime ActivatePackage
# (T-RANGO-BOOT-HWASAN / MODE=stockhwasan).
#
# Evidence (150440 / stockapexcfg host disk):
#   - com.android.runtime (stock-grafted) requireNativeLibs includes
#     libclang_rt.hwasan-aarch64-android.so (same list as GT runtime).
#   - /system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so
#     already MATCH stock via patch_stock_bootstrap (1248776).
#   - /system/lib64/bootstrap/hwasan/libc.so still GT (1706096) vs stock
#     (1674080) — hwasan-instrumented bootstrap libc NOT covered by the
#     flat bootstrap lib loop. Mixed stock hwasan-rt + GT hwasan-libc is
#     the named residual for ActivatePackage on stockapexcfg base.
# Hard cmp gates (fail-closed). Does NOT touch GT /system/bin/init.
patch_stock_hwasan_native_deps() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock hwasan native-deps graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockhwasan.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock hwasan native deps (bootstrap/hwasan + verify rt)..."

  # Gate: bootstrap libclang_rt.hwasan must already be stock (from
  # patch_stock_bootstrap). Re-verify; re-graft if somehow drifted.
  debugfs -R "dump /system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so $tmp/stock-hwasan-rt.so" \
    "$stock_img" 2>/dev/null \
    || die "dump stock bootstrap libclang_rt.hwasan failed"
  debugfs -R "dump /system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so $tmp/img-hwasan-rt.so" \
    "$img" 2>/dev/null \
    || die "dump image bootstrap libclang_rt.hwasan failed"
  if ! cmp -s "$tmp/stock-hwasan-rt.so" "$tmp/img-hwasan-rt.so"; then
    {
      echo "cd /system/lib64/bootstrap"
      echo "rm libclang_rt.hwasan-aarch64-android.so"
      echo "write $tmp/stock-hwasan-rt.so libclang_rt.hwasan-aarch64-android.so"
      echo "set_inode_field libclang_rt.hwasan-aarch64-android.so mode 0x81ed"
      echo "set_inode_field libclang_rt.hwasan-aarch64-android.so uid 0"
      echo "set_inode_field libclang_rt.hwasan-aarch64-android.so gid 2000"
    } >"$tmp/dfs.cmd"
    debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
      || die "debugfs write stock bootstrap libclang_rt.hwasan failed"
    debugfs -R "dump /system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so $tmp/verify-hwasan-rt.so" \
      "$img" 2>/dev/null \
      || die "verify dump bootstrap libclang_rt.hwasan failed"
    cmp -s "$tmp/stock-hwasan-rt.so" "$tmp/verify-hwasan-rt.so" \
      || die "stock bootstrap libclang_rt.hwasan graft corrupt (cmp mismatch)"
    log "  stock /system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so ($(stat -c%s "$tmp/stock-hwasan-rt.so") bytes) re-grafted ✓"
  else
    log "  bootstrap libclang_rt.hwasan-aarch64-android.so already stock MATCH ($(stat -c%s "$tmp/stock-hwasan-rt.so") bytes) ✓"
  fi

  # Named delta vs stockapexcfg: hwasan-instrumented bootstrap libc.
  debugfs -R "dump /system/lib64/bootstrap/hwasan/libc.so $tmp/stock-hwasan-libc.so" \
    "$stock_img" 2>/dev/null \
    || die "dump stock /system/lib64/bootstrap/hwasan/libc.so failed"
  {
    echo "cd /system/lib64/bootstrap/hwasan"
    echo "rm libc.so"
    echo "write $tmp/stock-hwasan-libc.so libc.so"
    echo "set_inode_field libc.so mode 0x81ed"
    echo "set_inode_field libc.so uid 0"
    echo "set_inode_field libc.so gid 2000"
  } >"$tmp/dfs.cmd"
  debugfs -w -f "$tmp/dfs.cmd" "$img" >/dev/null 2>&1 \
    || die "debugfs write stock bootstrap/hwasan/libc.so failed"
  debugfs -R "dump /system/lib64/bootstrap/hwasan/libc.so $tmp/verify-hwasan-libc.so" \
    "$img" 2>/dev/null \
    || die "verify dump bootstrap/hwasan/libc.so failed"
  cmp -s "$tmp/stock-hwasan-libc.so" "$tmp/verify-hwasan-libc.so" \
    || die "stock bootstrap/hwasan/libc.so graft corrupt (cmp mismatch)"
  log "  stock /system/lib64/bootstrap/hwasan/libc.so ($(stat -c%s "$tmp/stock-hwasan-libc.so") bytes) verify cmp ✓"
}

# Graft one file into an ext4 image via debugfs (fail-closed cmp).
# Args: img abs_path_in_image local_src mode_hex uid gid
_debugfs_graft_file() {
  local img="$1" path="$2" src="$3" mode="$4" uid="$5" gid="$6"
  local dir base dfs verify
  [ -f "$src" ] || die "graft source missing: $src (for $path)"
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  dfs="$(mktemp /tmp/rango-dfs.XXXXXX)"
  verify="$(mktemp /tmp/rango-verify.XXXXXX)"
  {
    echo "cd $dir"
    echo "rm $base"
    echo "write $src $base"
    echo "set_inode_field $base mode $mode"
    echo "set_inode_field $base uid $uid"
    echo "set_inode_field $base gid $gid"
  } >"$dfs"
  debugfs -w -f "$dfs" "$img" >/dev/null 2>&1 \
    || { rm -f "$dfs" "$verify"; die "debugfs write failed for $path"; }
  debugfs -R "dump $path $verify" "$img" >/dev/null 2>&1 \
    || { rm -f "$dfs" "$verify"; die "verify dump failed for $path"; }
  [ -f "$verify" ] || { rm -f "$dfs" "$verify"; die "verify dump produced no file for $path"; }
  cmp -s "$src" "$verify" \
    || { rm -f "$dfs" "$verify"; die "graft corrupt after write: $path (cmp mismatch)"; }
  rm -f "$dfs" "$verify"
}

# Android system.img often has ext4 shared_blocks. debugfs write then
# overwrites a sibling file's shared 4K page (libc++ ↔ protobuf ping-pong).
_unshare_ext4_blocks() {
  local img="$1"
  [ -f "$img" ] || die "unshare: image missing $img"
  command -v e2fsck >/dev/null || die "e2fsck required to unshare_blocks"
  if tune2fs -l "$img" 2>/dev/null | grep -q 'shared_blocks'; then
    log "  unsharing ext4 shared_blocks (debugfs write otherwise stomps siblings)..."
    e2fsck -fy -E unshare_blocks "$img" >/dev/null 2>&1 \
      || die "e2fsck unshare_blocks failed on $img"
    tune2fs -l "$img" 2>/dev/null | grep -q 'shared_blocks' \
      && die "shared_blocks still set after unshare on $img"
    log "  shared_blocks cleared ✓"
  fi
}

# Graft stock early-apex SELinux surface onto stockhwasan composition
# (T-RANGO-BOOT-SELINUX / MODE=stockselinux).
#
# Evidence (153335 / stockhwasan host disk):
#   - restorecon /metadata already present (stock init.rc graft)
#   - plat_file_contexts DIFFERS: stock has
#     /dev/block/mapper/.*\.apex → apex_dm_device; GT ABSENT that line
#   - plat_sepolicy.cil: type apex_dm_device ABSENT on GT (0 refs vs 16)
# Grafting plat sepolicy alone would break vendor precompiled hash MATCH
# → on-device secilc → historical 0x7f00. Therefore graft coherent stock
# plat + system_ext + product sepolicy (+ mapping/sha256) AND stock vendor
# precompiled_sepolicy (+ 3 sha256). Hard cmp gates. GT init untouched.
patch_stock_selinux_early_apex() {
  local sys_img="$1" se_img="$2" pr_img="$3" ven_img="$4"
  need "$sys_img"; need "$se_img"; need "$pr_img"; need "$ven_img"
  need "$STOCK/system.img"; need "$STOCK/system_ext.img"
  need "$STOCK/product.img"; need "$STOCK/vendor.img"
  command -v debugfs >/dev/null || die "debugfs required for stock SELinux graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockselinux.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_sys="$STOCK/system.img" stock_se="$STOCK/system_ext.img"
  local stock_pr="$STOCK/product.img" stock_ven="$STOCK/vendor.img"
  if file "$stock_sys" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_sys" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_sys="$tmp/stock-system.raw"
  fi
  if file "$stock_se" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_se" "$tmp/stock-se.raw" \
      || die "simg2img stock system_ext.img failed"
    stock_se="$tmp/stock-se.raw"
  fi
  if file "$stock_pr" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_pr" "$tmp/stock-pr.raw" \
      || die "simg2img stock product.img failed"
    stock_pr="$tmp/stock-pr.raw"
  fi
  if file "$stock_ven" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_ven" "$tmp/stock-ven.raw" \
      || die "simg2img stock vendor.img failed"
    stock_ven="$tmp/stock-ven.raw"
  fi

  log "Patching system*/vendor: stock early-apex SELinux (file_contexts + domains + precompiled)..."

  # --- system plat (file contexts + policy + mapping + sha256) ---
  local f
  for f in \
    plat_file_contexts \
    plat_sepolicy.cil \
    plat_sepolicy_and_mapping.sha256 \
    plat_sepolicy_genfs_202504.cil \
    plat_sepolicy_genfs_202604.cil
  do
    debugfs -R "dump /system/etc/selinux/$f $tmp/stock-$f" "$stock_sys" >/dev/null 2>&1 \
      || die "dump stock /system/etc/selinux/$f failed"
    _debugfs_graft_file "$sys_img" "/system/etc/selinux/$f" "$tmp/stock-$f" 0x81a4 0 0
    log "  stock /system/etc/selinux/$f ($(stat -c%s "$tmp/stock-$f") bytes) verify cmp ✓"
  done

  # Named early-apex file_contexts residual must be present.
  grep -E '/dev/block/mapper/.*\.apex' "$tmp/stock-plat_file_contexts" \
    | grep -q 'apex_dm_device' \
    || die "stock plat_file_contexts missing apex mapper → apex_dm_device (unexpected)"
  grep -q 'apex_dm_device' "$tmp/stock-plat_sepolicy.cil" \
    || die "stock plat_sepolicy.cil missing type apex_dm_device (unexpected)"

  # mapping/*.cil — list from stock, graft each (skip . / ..)
  debugfs -R "ls /system/etc/selinux/mapping" "$stock_sys" 2>/dev/null \
    | tr -s ' ' '\n' | grep -E '\.cil$' >"$tmp/plat-mapping.list" \
    || die "list stock plat mapping failed"
  while IFS= read -r mf; do
    [ -n "$mf" ] || continue
    debugfs -R "dump /system/etc/selinux/mapping/$mf $tmp/map-$mf" "$stock_sys" >/dev/null 2>&1 \
      || die "dump stock mapping/$mf failed"
    _debugfs_graft_file "$sys_img" "/system/etc/selinux/mapping/$mf" "$tmp/map-$mf" 0x81a4 0 0
  done <"$tmp/plat-mapping.list"
  log "  stock plat mapping/*.cil grafted ($(wc -l <"$tmp/plat-mapping.list") files) ✓"

  # --- system_ext (partition root → /etc/selinux, not /system_ext/etc/...) ---
  for f in \
    system_ext_file_contexts \
    system_ext_sepolicy.cil \
    system_ext_sepolicy_and_mapping.sha256
  do
    debugfs -R "dump /etc/selinux/$f $tmp/stock-$f" "$stock_se" >/dev/null 2>&1 \
      || die "dump stock /etc/selinux/$f (system_ext.img) failed"
    [ -s "$tmp/stock-$f" ] || [ "$(stat -c%s "$tmp/stock-$f")" = "0" ] || true
    # Skip empty file_contexts (0-byte) — debugfs write of empty is unreliable;
    # still graft non-empty policy/sha256.
    if [ ! -s "$tmp/stock-$f" ] && [[ "$f" == *file_contexts ]]; then
      log "  stock /etc/selinux/$f is empty — skip graft (system_ext)"
      continue
    fi
    _debugfs_graft_file "$se_img" "/etc/selinux/$f" "$tmp/stock-$f" 0x81a4 0 0
    log "  stock system_ext:/etc/selinux/$f ($(stat -c%s "$tmp/stock-$f") bytes) verify cmp ✓"
  done
  debugfs -R "ls /etc/selinux/mapping" "$stock_se" 2>/dev/null \
    | tr -s ' ' '\n' | grep -E '\.cil$' >"$tmp/se-mapping.list" || true
  while IFS= read -r mf; do
    [ -n "$mf" ] || continue
    debugfs -R "dump /etc/selinux/mapping/$mf $tmp/semap-$mf" "$stock_se" >/dev/null 2>&1 \
      || die "dump stock system_ext mapping/$mf failed"
    _debugfs_graft_file "$se_img" "/etc/selinux/mapping/$mf" "$tmp/semap-$mf" 0x81a4 0 0
  done <"$tmp/se-mapping.list"

  # --- product (partition root → /etc/selinux) ---
  for f in \
    product_file_contexts \
    product_sepolicy.cil \
    product_sepolicy_and_mapping.sha256
  do
    debugfs -R "dump /etc/selinux/$f $tmp/stock-$f" "$stock_pr" >/dev/null 2>&1 \
      || die "dump stock /etc/selinux/$f (product.img) failed"
    if [ ! -s "$tmp/stock-$f" ] && [[ "$f" == *file_contexts ]]; then
      log "  stock /etc/selinux/$f is empty — skip graft (product)"
      continue
    fi
    _debugfs_graft_file "$pr_img" "/etc/selinux/$f" "$tmp/stock-$f" 0x81a4 0 0
    log "  stock product:/etc/selinux/$f ($(stat -c%s "$tmp/stock-$f") bytes) verify cmp ✓"
  done
  debugfs -R "ls /etc/selinux/mapping" "$stock_pr" 2>/dev/null \
    | tr -s ' ' '\n' | grep -E '\.cil$' >"$tmp/pr-mapping.list" || true
  while IFS= read -r mf; do
    [ -n "$mf" ] || continue
    debugfs -R "dump /etc/selinux/mapping/$mf $tmp/prmap-$mf" "$stock_pr" >/dev/null 2>&1 \
      || die "dump stock product mapping/$mf failed"
    _debugfs_graft_file "$pr_img" "/etc/selinux/mapping/$mf" "$tmp/prmap-$mf" 0x81a4 0 0
  done <"$tmp/pr-mapping.list"

  # --- vendor precompiled (must MATCH grafted partition sha256 files) ---
  for f in \
    precompiled_sepolicy \
    precompiled_sepolicy.plat_sepolicy_and_mapping.sha256 \
    precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256 \
    precompiled_sepolicy.product_sepolicy_and_mapping.sha256
  do
    debugfs -R "dump /etc/selinux/$f $tmp/stock-$f" "$stock_ven" >/dev/null 2>&1 \
      || die "dump stock /etc/selinux/$f failed"
    _debugfs_graft_file "$ven_img" "/etc/selinux/$f" "$tmp/stock-$f" 0x81a4 0 0
    log "  stock /etc/selinux/$f ($(stat -c%s "$tmp/stock-$f") bytes) verify cmp ✓"
  done

  # Hard gates: vendor precompiled sha256 == grafted partition sha256 == stock
  debugfs -R "dump /system/etc/selinux/plat_sepolicy_and_mapping.sha256 $tmp/v-plat.sha" \
    "$sys_img" >/dev/null 2>&1 || die "re-dump grafted plat sha failed"
  debugfs -R "dump /etc/selinux/system_ext_sepolicy_and_mapping.sha256 $tmp/v-se.sha" \
    "$se_img" >/dev/null 2>&1 || die "re-dump grafted system_ext sha failed"
  debugfs -R "dump /etc/selinux/product_sepolicy_and_mapping.sha256 $tmp/v-pr.sha" \
    "$pr_img" >/dev/null 2>&1 || die "re-dump grafted product sha failed"
  cmp -s "$tmp/v-plat.sha" \
    "$tmp/stock-precompiled_sepolicy.plat_sepolicy_and_mapping.sha256" \
    || die "plat sepolicy hash MISMATCH after stockselinux graft (system vs vendor)"
  cmp -s "$tmp/v-se.sha" \
    "$tmp/stock-precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256" \
    || die "system_ext sepolicy hash MISMATCH after stockselinux graft"
  cmp -s "$tmp/v-pr.sha" \
    "$tmp/stock-precompiled_sepolicy.product_sepolicy_and_mapping.sha256" \
    || die "product sepolicy hash MISMATCH after stockselinux graft"
  # Named residual: apex_dm_device present on grafted system
  debugfs -R "dump /system/etc/selinux/plat_sepolicy.cil $tmp/verify-cil" \
    "$sys_img" >/dev/null 2>&1 || die "re-dump grafted plat_sepolicy.cil failed"
  grep -q 'apex_dm_device' "$tmp/verify-cil" \
    || die "grafted plat_sepolicy.cil still missing apex_dm_device"
  debugfs -R "dump /system/etc/selinux/plat_file_contexts $tmp/verify-fc" \
    "$sys_img" >/dev/null 2>&1 || die "re-dump grafted plat_file_contexts failed"
  grep -E '/dev/block/mapper/.*\.apex' "$tmp/verify-fc" | grep -q 'apex_dm_device' \
    || die "grafted plat_file_contexts still missing apex mapper line"
  # restorecon /metadata retained (stock init.rc on stockhwasan base)
  debugfs -R "dump /system/etc/init/hw/init.rc $tmp/verify-init.rc" \
    "$sys_img" >/dev/null 2>&1 || die "dump init.rc for restorecon gate failed"
  grep -q 'restorecon /metadata' "$tmp/verify-init.rc" \
    || die "init.rc missing restorecon /metadata after stockselinux (unexpected)"
  log "  stockselinux hard gates: fc+apex_dm_device+hash MATCH+restorecon ✓"
}

# Graft stock /system/apex WHOLESALE onto the durable gtuserspace composition
# (T-RANGO-BOOT-APEXSET / MODE=stockapexset).
#
# DR-RANGO-10DAY-RCA RQ4 candidate #2 (HIGH): bootstrap-set APEX content
# defect — GT-repacked APEXes in /system/apex (art/adbd/conscrypt/… set)
# were never swapped in any prior bisect (only runtime/i18n/tzdata/apexd/
# init/init.rc/hwasan/sepolicy were). This removes EVERY GT .apex and writes
# ALL stock .apex files from the canonical stock donor ($STOCK =
# releases/desktop-flash/rango-stock-userspace, factory CP1A.260505.005 —
# the same donor used by every prior stock graft in this script), keeping
# stock filenames (com.google.android.*). apexd bootstrap matches packages
# by MANIFEST name (system/apex/apexd/apexd.cpp:168-210), so stock filenames
# activate exactly as on the avbcontrol PASS control;
# com.google.android.tzdata6.apex carries manifest name com.android.tzdata
# (deapexer-proven on 130756). com.google.android.virt.apex is INCLUDED:
# /system/apex becomes byte-identical to the avbcontrol PASS composition
# (stock virt + factory pvmfw is the known-good pairing).
#
# 130338 debugfs write-order bug class (tzdata written AFTER runtime/i18n
# corrupted the earlier apex payloads): writes are issued SMALLEST-FIRST
# (the order proven safe on 130756) and EVERY apex is re-dumped and
# sha256-compared against the stock source AFTER ALL writes complete, so a
# later write corrupting an earlier file is caught fail-closed. Count gate:
# exactly N stock apexes present and 0 GT apexes remain.
patch_stock_apexset_wholesale() {
  local img="$1"
  need "$img"
  need "$STOCK/system.img"
  command -v debugfs >/dev/null || die "debugfs required for stock apexset graft"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockapexset.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  local stock_img="$STOCK/system.img"
  if file "$stock_img" | grep -qi sparse; then
    "$HOST_BIN/simg2img" "$stock_img" "$tmp/stock-system.raw" \
      || die "simg2img stock system.img failed"
    stock_img="$tmp/stock-system.raw"
  fi

  log "Patching system.img: stock /system/apex WHOLESALE (all stock apexes; 0 GT remain)..."

  # Inventory canonical stock donor /system/apex and dump every apex.
  debugfs -R "ls /system/apex" "$stock_img" 2>/dev/null \
    | tr -s ' ' '\n' | grep -E '^[^[:space:]/]+\.apex$' >"$tmp/stock.list" \
    || die "list stock /system/apex failed"
  local n_stock
  n_stock="$(grep -c '\.apex$' "$tmp/stock.list" || true)"
  [ "$n_stock" -gt 0 ] || die "no stock .apex files found in $STOCK/system.img"

  local apex
  while IFS= read -r apex; do
    [ -n "$apex" ] || continue
    debugfs -R "dump /system/apex/$apex $tmp/stock-$apex" "$stock_img" 2>/dev/null \
      || die "dump stock /system/apex/$apex failed"
    [ -s "$tmp/stock-$apex" ] || die "dump stock /system/apex/$apex is empty"
  done <"$tmp/stock.list"
  log "  donor: $STOCK/system.img (factory CP1A.260505.005) — $n_stock stock apexes dumped ✓"

  # Remove EVERY GT .apex from the target image.
  debugfs -R "ls /system/apex" "$img" 2>/dev/null \
    | tr -s ' ' '\n' | grep -E '^[^[:space:]/]+\.apex$' >"$tmp/gt.list" \
    || die "list target /system/apex failed"
  local n_gt=0
  n_gt="$(grep -c '\.apex$' "$tmp/gt.list" || true)"
  while IFS= read -r apex; do
    [ -n "$apex" ] || continue
    debugfs -w -R "rm /system/apex/$apex" "$img" >/dev/null 2>&1 \
      || die "failed to remove GT /system/apex/$apex"
  done <"$tmp/gt.list"
  log "  removed $n_gt GT apexes ✓"

  # debugfs block-allocator headroom (ROOT of the 130338 write-order bug
  # class): the stock apex set totals ~276MiB and com.google.android.virt.
  # apex alone is ~94MiB; the GT image free pool is too small/fragmented for
  # the debugfs 1.47 write allocator — observed live 2026-08-03:
  # "write: Could not allocate block in ext2 filesystem" truncated virt at
  # ~80MiB (20136/23970 blocks) with 23MiB still free, debugfs exit 0.
  # Grow the work image +384MiB (fresh contiguous blocks) BEFORE any apex
  # write. Super group headroom is ~1.35GiB (lpmake group 8527020032 vs
  # ~6.6GiB used), so the grown image still fits; lpmake + shipped
  # DEST/system.img use the grown size coherently. Packaging-only change —
  # no content delta beyond /system/apex.
  command -v resize2fs >/dev/null || die "resize2fs required for apexset headroom grow"
  command -v e2fsck >/dev/null || die "e2fsck required for apexset headroom grow"
  local cur_size new_size fsck_rc=0
  cur_size="$(stat -c%s "$img")"
  new_size=$(( cur_size + 402653184 ))
  # e2fsck exit 0/1/2 = clean/fixed/fixed-notify (>=4 = uncorrected);
  # debugfs rm leaves minor inconsistencies that -fy fixes (rc=1) — not fatal.
  e2fsck -fy "$img" >/dev/null 2>&1 || fsck_rc=$?
  [ "$fsck_rc" -le 2 ] || die "e2fsck pre-grow FAILED (rc=$fsck_rc) on $img"
  truncate -s "$new_size" "$img" || die "truncate grow failed on $img"
  resize2fs "$img" >/dev/null 2>&1 || die "resize2fs grow failed on $img"
  [ "$(stat -c%s "$img")" = "$new_size" ] || die "resize2fs size drift on $img"
  log "  grew system.img $cur_size -> $new_size (+384MiB allocator headroom) ✓"

  # Write order: smallest-first (defensive vs the 130338 debugfs
  # write-order corruption class; headroom grow above is the root fix).
  : >"$tmp/write-order.list"
  while IFS= read -r apex; do
    [ -n "$apex" ] || continue
    printf '%s %s\n' "$(stat -c%s "$tmp/stock-$apex")" "$apex" >>"$tmp/write-order.list"
  done <"$tmp/stock.list"
  sort -n -o "$tmp/write-order.list" "$tmp/write-order.list"

  local wrote=0
  while read -r _sz apex; do
    [ -n "$apex" ] || continue
    _debugfs_graft_file "$img" "/system/apex/$apex" "$tmp/stock-$apex" 0x81a4 0 0
    wrote=$((wrote + 1))
  done <"$tmp/write-order.list"
  [ "$wrote" = "$n_stock" ] || die "wrote $wrote stock apexes, expected $n_stock"
  log "  wrote $wrote stock apexes (smallest-first) ✓"

  # fs consistency after 36 debugfs writes, BEFORE the readback gates
  # (e2fsck exit 0/1/2 = clean/fixed/fixed-notify; >=4 = uncorrected).
  local fsck_rc=0
  e2fsck -fy "$img" >/dev/null 2>&1 || fsck_rc=$?
  [ "$fsck_rc" -le 2 ] || die "e2fsck post-graft FAILED (rc=$fsck_rc) on $img"
  log "  e2fsck post-graft rc=$fsck_rc (<=2 acceptable) ✓"

  # HARD GATE (runs AFTER ALL writes — catches later-write-corrupts-earlier-
  # file): every stock apex must re-dump sha256-identical to the stock source.
  local mismatches=""
  while IFS= read -r apex; do
    [ -n "$apex" ] || continue
    debugfs -R "dump /system/apex/$apex $tmp/verify-$apex" "$img" 2>/dev/null \
      || die "verify dump /system/apex/$apex failed"
    local sha_src sha_dst
    sha_src="$(sha256sum "$tmp/stock-$apex" | awk '{print $1}')"
    sha_dst="$(sha256sum "$tmp/verify-$apex" | awk '{print $1}')"
    if [ "$sha_src" != "$sha_dst" ]; then
      echo "[stage:$MODE] ERROR: sha256 MISMATCH after write: /system/apex/$apex (src $sha_src != img $sha_dst)" >&2
      mismatches="$mismatches $apex"
    fi
  done <"$tmp/stock.list"
  [ -z "$mismatches" ] \
    || die "stock apexset graft corrupt after debugfs writes (sha256 mismatch:$mismatches) — write-order bug class, refusing to ship"
  log "  sha256 readback MATCH all $n_stock stock apexes ✓"

  # HARD COUNT GATE: exactly N stock apexes present; 0 GT apexes remain.
  debugfs -R "ls /system/apex" "$img" 2>/dev/null \
    | tr -s ' ' '\n' | grep -E '^[^[:space:]/]+\.apex$' >"$tmp/final.list" \
    || die "list final /system/apex failed"
  local n_final n_stray
  n_final="$(grep -c '\.apex$' "$tmp/final.list" || true)"
  [ "$n_final" = "$n_stock" ] \
    || die "count gate FAILED: $n_final apexes present, expected $n_stock (stock)"
  n_stray="$(grep -Fvx -f "$tmp/stock.list" "$tmp/final.list" | grep -c '\.apex$' || true)"
  [ "$n_stray" = "0" ] \
    || die "count gate FAILED: $n_stray non-stock (GT) apexes remain: $(grep -Fvx -f "$tmp/stock.list" "$tmp/final.list" | tr '\n' ' ')"
  log "  count gate: $n_stock stock apexes present, 0 GT apexes remain ✓"
}

# Graft factory vendor.img WHOLESALE onto the durable gtuserspace composition
# (T-RANGO-BOOT-STOCKVENDOR / MODE=stockvendor).
#
# DR-RANGO-10DAY-RCA RQ4 candidate #1 (prime after 130329 closed #2):
# loop-device/ueventd coldboot handoff environment. In the durable
# gtuserspace composition the boot chain + dlkm are factory but vendor.img
# is GT — and vendor carries ueventd.rc (device-node rules incl. loop/dm
# timing), fstab, init.*.rc and VINTF manifests. It has never been swapped
# in the gtuserspace era. This replaces the work vendor.img with the
# canonical stock donor's ($STOCK = releases/desktop-flash/
# rango-stock-userspace, factory CP1A.260505.005 — same donor as APEXSET).
#
# Hard gates (fail-closed):
#   1. e2fsck rc<=2 on a THROWAWAY copy of the donor image. e2fsck -fy
#      rewrites the superblock (last-check) even on a clean rc=0 run —
#      measured 2026-08-03 (sha256 changed with zero errors) — so the
#      grafted image itself is NEVER fsck'd; byte-identity is preserved.
#   2. sha256 of the grafted work image MUST equal the donor's (raw
#      unsparse is deterministic; this catches copy/truncation defects).
# The shipped DEST/vendor.img is a byte copy of the donor file with its own
# sha256 gate at the call site.
#
# Super geometry: stock vendor raw 1,009,041,408 B vs GT 915,238,912 B
# (+89.5 MiB). Measured group total with stock vendor = 3,243,409,408 B vs
# group_size 8,527,020,032 B → ~5.0 GiB headroom, so the stockapexset
# +384MiB grow/resize headroom fix is NOT needed here; lpmake partition
# sizes follow the work image automatically (ven_sz).
patch_stock_vendor_wholesale() {
  local work_vendor="$1"
  need "$work_vendor"
  need "$STOCK/vendor.img"
  command -v e2fsck >/dev/null || die "e2fsck required for stock vendor gate"

  local tmp
  tmp="$(mktemp -d /tmp/rango-stockvendor.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  log "Replacing work vendor.img with factory donor (wholesale, byte-identical)..."

  # Donor ships raw ext4 (file(1)-verified); unsparse path kept for safety.
  unsparse_if_needed "$STOCK/vendor.img" "$tmp/vendor.raw"
  local donor_sha
  donor_sha="$(sha256sum "$tmp/vendor.raw" | awk '{print $1}')"

  # Gate 1: fs integrity on a throwaway copy (e2fsck writes even when clean).
  cp -f "$tmp/vendor.raw" "$tmp/vendor.fsck"
  local fsck_rc=0
  e2fsck -fy "$tmp/vendor.fsck" >/dev/null 2>&1 || fsck_rc=$?
  [ "$fsck_rc" -le 2 ] \
    || die "e2fsck donor vendor.img FAILED (rc=$fsck_rc) — donor fs corrupt, refusing"
  log "  e2fsck donor vendor.img rc=$fsck_rc (<=2; throwaway copy) ✓"

  # Gate 2: graft + sha256 vs donor (byte-identity).
  cp -f "$tmp/vendor.raw" "$work_vendor"
  local work_sha
  work_sha="$(sha256sum "$work_vendor" | awk '{print $1}')"
  [ "$work_sha" = "$donor_sha" ] \
    || die "stock vendor graft sha256 MISMATCH vs donor ($work_sha != $donor_sha)"
  log "  factory vendor.img grafted ($(stat -c%s "$work_vendor") bytes) sha256 MATCH donor ✓"
  log "  NOTE: stock vendor precompiled_sepolicy sha256 != GT system* sha256"
  log "        (on-device policy-compile fallback; see RANGO_BOOT_RCA §1.0)"
}

write_sha256sums() {
  ( cd "$DEST" && sha256sum -- *.img *.bin 2>/dev/null > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS ) || true
}

link_latest_if_requested() {
  if [ "$LINK_LATEST" = "1" ]; then
    ln -sfn "$STAMP" "$ROOT/releases/desktop-flash/rango-latest"
    log "rango-latest -> $STAMP"
  else
    log "NOT relinking rango-latest (pass --link-latest to do so). Stamp staged at: $DEST"
  fi
}

# ===========================================================================
# MODE: gtuserspace — factory boot + coherent GT logicals (preferred fix).
# Only mode allowed to relink rango-latest (as of 2026-08-02).
# ===========================================================================
stage_gtuserspace() {
  need "$OUT/system.img"; need "$OUT/system_ext.img"; need "$OUT/product.img"
  need "$OUT/vendor.img"
  need "$STOCK/system_dlkm.img"; need "$STOCK/vendor_dlkm.img"
  need "$STOCKCTL/bootloader.img"; need "$STOCKCTL/radio.img"
  need "$HOST_BIN/lpmake"; need "$HOST_BIN/img2simg"; need "$HOST_BIN/simg2img"

  local boot_src="$RESCUE"
  [ -f "$boot_src/boot.img" ] || boot_src="$STOCK"
  need "$boot_src/boot.img"
  need "$boot_src/init_boot.img"
  need "$boot_src/vendor_boot.img"
  need "$boot_src/vendor_kernel_boot.img"
  need "$boot_src/dtbo.img"
  need "$boot_src/pvmfw.img"

  local vbmeta_flags3="" pkmd=""
  for c in \
    "$ROOT/releases/desktop-flash/rango-latest/vbmeta_valid_flags3.img" \
    "$ROOT/releases/desktop-flash/rango-memtagfix2-20260728-101648/vbmeta_valid_flags3.img" \
    "$ROOT/releases/desktop-flash/rango-avbcontrol-20260801-072014/vbmeta_valid_flags3.img"
  do [ -f "$c" ] && vbmeta_flags3="$c" && break; done
  [ -n "$vbmeta_flags3" ] || die "vbmeta_valid_flags3.img not found"
  for c in \
    "$ROOT/releases/desktop-flash/rango-latest/avb_pkmd_testkey.bin" \
    "$ROOT/releases/desktop-flash/rango-latest/avb_pkmd.bin" \
    "$ROOT/releases/desktop-flash/rango-memtagfix2-20260728-101648/avb_pkmd_testkey.bin" \
    "$ROOT/releases/desktop-flash/rango-avbcontrol-20260801-072014/avb_pkmd.bin"
  do [ -f "$c" ] && pkmd="$c" && break; done
  [ -n "$pkmd" ] || die "avb_pkmd testkey not found"

  sepolicy_hash_gate
  mte_strip_gate

  rm -rf "$WORK"; mkdir -p "$WORK" "$DEST"

  log "Preparing GT system*/vendor + factory dlkm (factory kernel 6.6.102)..."
  unsparse_if_needed "$OUT/system.img" "$WORK/system.img"
  patch_system_img_for_factory_boot "$WORK/system.img"
  patch_stock_bootstrap "$WORK/system.img"
  case "$MODE" in
    gtuserspace)
      # Durable factory-boot path (T-RANGO-BOOT-FINAL): drop EARLY_VM virt +
      # graft stock kBootstrapApexes (runtime/i18n/tzdata). 123756 FAIL 0xfc
      # closed prior bisect (stock runtime/i18n alone insufficient).
      # NOTE: 130756 on-device FAIL 0xfc falsified tzdata-sole; stock apexd
      # bisect is MODE=stockapexd (not folded into durable until on-device PASS).
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      ;;
    stockapexd)
      # T-RANGO-BOOT-APEXD: durable gtuserspace apex set + stock apexd binary.
      # On-device 132759 FAIL 0xfc falsified stock-apexd-sole — see MODE=stockinit.
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      patch_stock_apexd "$WORK/system.img"
      ;;
    stockinit)
      # T-RANGO-BOOT-INIT: stockapexd composition + stock /system/bin/init.
      # 132759: apexd MATCH stock; init DIFFERS (2938144 vs 2771368).
      # On-device 141438 FAIL KP 0x00000100 — stock-init-sole FALSIFIED.
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      patch_stock_apexd "$WORK/system.img"
      patch_stock_init "$WORK/system.img"
      ;;
    stockapexcfg)
      # T-RANGO-BOOT-POSTINIT: stockapexd + GT init + stock early init.rc.
      # On-device 150440 FAIL 0xfc — stockapexcfg-sole FALSIFIED.
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      patch_stock_apexd "$WORK/system.img"
      patch_stock_init_rc "$WORK/system.img"
      ;;
    stockhwasan)
      # T-RANGO-BOOT-HWASAN: stockapexcfg base + stock hwasan native deps.
      # 150440: bootstrap libclang_rt.hwasan MATCH stock, but
      # bootstrap/hwasan/libc.so still GT — ActivatePackage residual.
      # On-device 153335 FAIL 0xfc — stockhwasan-sole FALSIFIED.
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      patch_stock_apexd "$WORK/system.img"
      patch_stock_init_rc "$WORK/system.img"
      patch_stock_hwasan_native_deps "$WORK/system.img"
      ;;
    stockselinux)
      # T-RANGO-BOOT-SELINUX: stockhwasan base + stock early-apex SELinux.
      # 153335: apex_dm_device ABSENT on GT; mapper.apex file_contexts
      # ABSENT; restorecon /metadata already present. SELinux patch runs
      # after system_ext/product/vendor unsparse (see below).
      # On-device 044126 FAIL 0xfc — stockselinux-sole FALSIFIED.
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      patch_stock_apexd "$WORK/system.img"
      patch_stock_init_rc "$WORK/system.img"
      patch_stock_hwasan_native_deps "$WORK/system.img"
      ;;
    stockapexset)
      # T-RANGO-BOOT-APEXSET: durable gtuserspace base (GT apexd / GT init /
      # GT init.rc retained) + stock /system/apex WHOLESALE. Subsumes the
      # virt-drop and named bootstrap-apex grafts: the wholesale function
      # removes every GT apex (incl. GT virt) and writes ALL stock apexes
      # (incl. com.google.android.virt.apex) — /system/apex byte-identical
      # to the avbcontrol PASS composition.
      # On-device 130329 FAIL 0xfc — with 044126, APEX-content-sole FALSIFIED.
      patch_stock_apexset_wholesale "$WORK/system.img"
      ;;
    stockvendor)
      # T-RANGO-BOOT-STOCKVENDOR: durable gtuserspace base (GT apexd /
      # GT init / GT init.rc retained; drop virt + stock runtime/i18n/
      # tzdata) + factory vendor.img WHOLESALE (swapped after unsparse
      # below — RQ4 #1 loop/ueventd coldboot environment probe).
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      ;;
    stockbootstrap)
      log "MODE=stockbootstrap: keeping com.android.virt.apex (103641-class bisect)"
      ;;
    stockbootapex)
      log "MODE=stockbootapex: LEGACY keeping virt + grafting stock runtime/i18n/tzdata"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      ;;
    novirtstockapex)
      log "MODE=novirtstockapex: drop virt + graft stock runtime/i18n/tzdata"
      patch_drop_bootstrap_virt "$WORK/system.img"
      patch_stock_bootstrap_apexes "$WORK/system.img"
      ;;
  esac
  unsparse_if_needed "$OUT/system_ext.img" "$WORK/system_ext.img"
  unsparse_if_needed "$OUT/product.img" "$WORK/product.img"
  unsparse_if_needed "$OUT/vendor.img" "$WORK/vendor.img"
  if [ "$MODE" = "stockselinux" ]; then
    # Coherent stock early-apex SELinux across system*/vendor (after unsparse).
    patch_stock_selinux_early_apex \
      "$WORK/system.img" "$WORK/system_ext.img" "$WORK/product.img" "$WORK/vendor.img"
  fi
  if [ "$MODE" = "stockvendor" ]; then
    # Factory vendor.img wholesale (byte-identical to donor; hard gates).
    patch_stock_vendor_wholesale "$WORK/vendor.img"
  fi
  # Factory dlkm MUST match factory boot vermagic (GT dlkm is 6.6.139+RANDSTRUCT).
  unsparse_if_needed "$STOCK/system_dlkm.img" "$WORK/system_dlkm.img"
  unsparse_if_needed "$STOCK/vendor_dlkm.img" "$WORK/vendor_dlkm.img"

  local sys_sz se_sz pr_sz ven_sz sdlkm_sz vdlkm_sz
  sys_sz=$(sz "$WORK/system.img"); se_sz=$(sz "$WORK/system_ext.img")
  pr_sz=$(sz "$WORK/product.img"); ven_sz=$(sz "$WORK/vendor.img")
  sdlkm_sz=$(sz "$WORK/system_dlkm.img"); vdlkm_sz=$(sz "$WORK/vendor_dlkm.img")

  local super_size=8531214336 group_size=8527020032
  log "lpmake super.img (gtuserspace)..."
  "$HOST_BIN/lpmake" \
    --metadata-size 65536 --super-name super --metadata-slots 3 \
    --device super:"$super_size" \
    --group google_dynamic_partitions:"$group_size" \
    --partition system_a:readonly:"$sys_sz":google_dynamic_partitions --image system_a="$WORK/system.img" \
    --partition system_b:readonly:0:google_dynamic_partitions \
    --partition system_ext_a:readonly:"$se_sz":google_dynamic_partitions --image system_ext_a="$WORK/system_ext.img" \
    --partition system_ext_b:readonly:0:google_dynamic_partitions \
    --partition product_a:readonly:"$pr_sz":google_dynamic_partitions --image product_a="$WORK/product.img" \
    --partition product_b:readonly:0:google_dynamic_partitions \
    --partition vendor_a:readonly:"$ven_sz":google_dynamic_partitions --image vendor_a="$WORK/vendor.img" \
    --partition vendor_b:readonly:0:google_dynamic_partitions \
    --partition system_dlkm_a:readonly:"$sdlkm_sz":google_dynamic_partitions --image system_dlkm_a="$WORK/system_dlkm.img" \
    --partition system_dlkm_b:readonly:0:google_dynamic_partitions \
    --partition vendor_dlkm_a:readonly:"$vdlkm_sz":google_dynamic_partitions --image vendor_dlkm_a="$WORK/vendor_dlkm.img" \
    --partition vendor_dlkm_b:readonly:0:google_dynamic_partitions \
    --sparse --output "$WORK/super.img" \
    || die "lpmake failed"

  log "Stage bundle -> $DEST"
  cp -f "$WORK/super.img" "$DEST/super.img"
  # Ship PATCHED images (not raw OUT) so flash-from-remote downloads match super.
  cp -f "$WORK/system.img" "$DEST/system.img"
  if [ "$MODE" = "stockselinux" ]; then
    cp -f "$WORK/system_ext.img" "$DEST/system_ext.img"
    cp -f "$WORK/product.img" "$DEST/product.img"
    cp -f "$WORK/vendor.img" "$DEST/vendor.img"
  elif [ "$MODE" = "stockvendor" ]; then
    cp -f "$OUT/system_ext.img" "$DEST/system_ext.img"
    cp -f "$OUT/product.img" "$DEST/product.img"
    # Ship the donor vendor.img byte-identical (matches super content);
    # hard sha256 gate vs donor on the shipped artifact.
    cp -f "$STOCK/vendor.img" "$DEST/vendor.img"
    local vsha_src vsha_dst
    vsha_src="$(sha256sum "$STOCK/vendor.img" | awk '{print $1}')"
    vsha_dst="$(sha256sum "$DEST/vendor.img" | awk '{print $1}')"
    [ "$vsha_src" = "$vsha_dst" ] \
      || die "shipped DEST/vendor.img sha256 MISMATCH vs donor ($vsha_dst != $vsha_src)"
    log "  shipped vendor.img sha256 MATCH donor ($vsha_src) ✓"
  else
    cp -f "$OUT/system_ext.img" "$DEST/system_ext.img"
    cp -f "$OUT/product.img" "$DEST/product.img"
    cp -f "$OUT/vendor.img" "$DEST/vendor.img"
  fi
  cp -f "$STOCK/system_dlkm.img" "$DEST/system_dlkm.img"
  cp -f "$STOCK/vendor_dlkm.img" "$DEST/vendor_dlkm.img"
  if [ -f "$STOCK/super_empty.img" ]; then
    cp -f "$STOCK/super_empty.img" "$DEST/super_empty.img"
  elif [ -f "$STOCKCTL/super_empty.img" ]; then
    cp -f "$STOCKCTL/super_empty.img" "$DEST/super_empty.img"
  fi
  cp -f "$STOCKCTL/bootloader.img" "$DEST/bootloader.img"
  cp -f "$STOCKCTL/radio.img" "$DEST/radio.img"

  for img in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img pvmfw.img; do
    cp -f "$boot_src/$img" "$DEST/$img"
  done

  cp -f "$vbmeta_flags3" "$DEST/vbmeta.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_system.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_vendor.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_valid_flags3.img"
  cp -f "$pkmd" "$DEST/avb_pkmd.bin"
  cp -f "$pkmd" "$DEST/avb_pkmd_testkey.bin"

  # Prefer factory init.insmod with factory dlkm.
  if [ -f "$STOCKCTL/init.insmod.rango.cfg" ]; then
    cp -f "$STOCKCTL/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  elif [ -f "$STOCK/init.insmod.rango.cfg" ]; then
    cp -f "$STOCK/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  elif [ -f "$ROOT/vendor/guardtalk/device/rango/init.insmod.rango.cfg" ]; then
    cp -f "$ROOT/vendor/guardtalk/device/rango/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  fi

  local mode_blurb virt_blurb apex_blurb apexd_blurb init_blurb initrc_blurb hwasan_blurb selinux_blurb vendor_blurb vendor_table_blurb composition_blurb
  mode_blurb="MODE=$MODE"
  composition_blurb="Factory CP1A **boot + dlkm** + GuardTalkOS **system/system_ext/product/vendor** (same OUT)."
  apexd_blurb="GT /system/bin/apexd (not stock-grafted)"
  init_blurb="GT /system/bin/init (not stock-grafted)"
  initrc_blurb="GT /system/etc/init/hw/init.rc (restorecon patch only)"
  hwasan_blurb="bootstrap libclang_rt.hwasan via stock bootstrap patch; bootstrap/hwasan/libc.so still GT unless MODE=stockhwasan|stockselinux"
  selinux_blurb="GT plat/system_ext/product sepolicy (OUT-coherent); early-apex stock graft only in MODE=stockselinux"
  vendor_blurb="GT vendor.img (GuardTalkOS OUT)"
  vendor_table_blurb="GuardTalkOS OUT"
  case "$MODE" in
    gtuserspace)
      virt_blurb="DROPPED com.android.virt.apex (EARLY_VM bootstrap → bootloader 0xfc fix)"
      apex_blurb="STOCK runtime+i18n+tzdata (tzdata6→com.android.tzdata.apex); virt dropped — durable after 123756 FAIL; 130756 on-device FAIL falsified tzdata-sole"
      ;;
    stockapexd)
      virt_blurb="DROPPED com.android.virt.apex"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace)"
      apexd_blurb="STOCK /system/bin/apexd grafted (T-RANGO-BOOT-APEXD bisect; 132759 FAIL falsified apexd-sole)"
      ;;
    stockinit)
      virt_blurb="DROPPED com.android.virt.apex"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace)"
      apexd_blurb="STOCK /system/bin/apexd grafted (stockapexd composition)"
      init_blurb="STOCK /system/bin/init grafted (T-RANGO-BOOT-INIT; 141438 FAIL KP 0x00000100 — FALSIFIED as cure)"
      ;;
    stockapexcfg)
      virt_blurb="DROPPED com.android.virt.apex"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace)"
      apexd_blurb="STOCK /system/bin/apexd grafted (stockapexd composition)"
      init_blurb="GT /system/bin/init retained (stock init binary FALSIFIED on 141438)"
      initrc_blurb="STOCK /system/etc/init/hw/init.rc grafted (150440 FAIL 0xfc — stockapexcfg-sole FALSIFIED)"
      ;;
    stockhwasan)
      virt_blurb="DROPPED com.android.virt.apex"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace; requireNativeLibs includes libclang_rt.hwasan)"
      apexd_blurb="STOCK /system/bin/apexd grafted (stockapexd composition)"
      init_blurb="GT /system/bin/init retained (stock init binary FALSIFIED on 141438)"
      initrc_blurb="STOCK /system/etc/init/hw/init.rc grafted (stockapexcfg base; 150440 FAIL falsified init.rc-sole)"
      hwasan_blurb="STOCK bootstrap/hwasan/libc.so + verified stock bootstrap libclang_rt.hwasan (153335 FAIL 0xfc — stockhwasan-sole FALSIFIED)"
      ;;
    stockselinux)
      virt_blurb="DROPPED com.android.virt.apex"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace; requireNativeLibs includes libclang_rt.hwasan)"
      apexd_blurb="STOCK /system/bin/apexd grafted (stockapexd composition)"
      init_blurb="GT /system/bin/init retained (stock init binary FALSIFIED on 141438)"
      initrc_blurb="STOCK /system/etc/init/hw/init.rc grafted (restorecon /metadata retained)"
      hwasan_blurb="STOCK bootstrap/hwasan/libc.so + verified stock bootstrap libclang_rt.hwasan (stockhwasan base)"
      selinux_blurb="STOCK early-apex SELinux: plat_file_contexts (apex_dm_device mapper) + plat/system_ext/product sepolicy.cil+mapping+sha256 + vendor precompiled (hash MATCH); 044126 FAIL 0xfc — stockselinux-sole FALSIFIED"
      ;;
    stockapexset)
      virt_blurb="STOCK com.google.android.virt.apex PRESENT (wholesale /system/apex = avbcontrol PASS composition)"
      apex_blurb="STOCK /system/apex WHOLESALE — ALL 36 stock .apex files from rango-stock-userspace (factory CP1A.260505.005) under stock com.google.android.* filenames (incl. tzdata6 + virt); 0 GT apexes remain; per-file sha256-after-all-writes + count hard gates; system.img grown +384MiB host-side for debugfs allocator headroom (packaging-only; 130338 bug-class root fix) (T-RANGO-BOOT-APEXSET; 044126 falsified sepolicy-sole; 130329 FAIL 0xfc — APEX-content-sole FALSIFIED)"
      apexd_blurb="GT /system/bin/apexd (not stock-grafted; stock-apexd-sole FALSIFIED on 132759)"
      init_blurb="GT /system/bin/init retained (stock init binary FALSIFIED on 141438)"
      initrc_blurb="GT /system/etc/init/hw/init.rc (restorecon patch only; stock init.rc FALSIFIED on 150440)"
      hwasan_blurb="bootstrap libclang_rt.hwasan via stock bootstrap patch; bootstrap/hwasan/libc.so still GT (stockhwasan-sole FALSIFIED on 153335)"
      selinux_blurb="GT plat/system_ext/product sepolicy (OUT-coherent; whole stock sepolicy stack FALSIFIED on 044126)"
      ;;
    stockvendor)
      virt_blurb="DROPPED com.android.virt.apex (durable gtuserspace base)"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace; wholesale /system/apex FALSIFIED on 130329)"
      apexd_blurb="GT /system/bin/apexd (not stock-grafted; stock-apexd-sole FALSIFIED on 132759)"
      init_blurb="GT /system/bin/init retained (stock init binary FALSIFIED on 141438)"
      initrc_blurb="GT /system/etc/init/hw/init.rc (restorecon patch only; stock init.rc FALSIFIED on 150440)"
      hwasan_blurb="bootstrap libclang_rt.hwasan via stock bootstrap patch; bootstrap/hwasan/libc.so still GT (stockhwasan-sole FALSIFIED on 153335)"
      selinux_blurb="GT plat/system_ext/product sepolicy (OUT-coherent; whole stock sepolicy stack FALSIFIED on 044126). NOTE: stock vendor precompiled_sepolicy sha256 != GT system* sha256 → init on-device policy-compile fallback (GT plat CIL + stock vendor CIL failed offline secilc on 2026-08-02, hal_audio_default) — if this stamp fails FAST as 0x7f00/KP instead of ~18s 0xfc, that is the sepolicy incoherence, not the loop/ueventd test"
      vendor_blurb="STOCK factory vendor.img WHOLESALE (byte-identical, sha256-gated vs rango-stock-userspace donor; e2fsck rc<=2 on throwaway copy; RQ4 #1 loop/ueventd coldboot environment probe — T-RANGO-BOOT-STOCKVENDOR)"
      vendor_table_blurb="Factory CP1A (\`rango-stock-userspace\`, byte-identical, sha256-gated)"
      composition_blurb="Factory CP1A **boot + dlkm + vendor** (vendor byte-identical to \`rango-stock-userspace\`) + GuardTalkOS **system/system_ext/product** (same OUT)."
      ;;
    stockbootstrap)
      virt_blurb="KEPT com.android.virt.apex (103641-class bisect — expect reboot bootloader if virt is culprit)"
      apex_blurb="GT bootstrap apexes including virt"
      ;;
    stockbootapex)
      virt_blurb="KEPT com.android.virt.apex (LEGACY bisect)"
      apex_blurb="STOCK runtime+i18n+tzdata; GT virt kept"
      ;;
    novirtstockapex)
      virt_blurb="DROPPED com.android.virt.apex"
      apex_blurb="STOCK runtime+i18n+tzdata (same as durable gtuserspace apex set)"
      ;;
  esac

  # Bisect modes must flash via REMOTE_BUILD_DIR (never promote as rango-latest).
  local use_remote_build_dir=0
  case "$MODE" in
    novirtstockapex|stockbootstrap|stockbootapex|stockapexd|stockinit|stockapexcfg|stockhwasan|stockselinux|stockapexset|stockvendor) use_remote_build_dir=1 ;;
  esac

  cat > "$DEST/README-FLASH-DESKTOP.md" <<EOF
# rango ${MODE} release — $STAMP

${composition_blurb} ${mode_blurb}.

Staging patches:
- \`restorecon /metadata\` before apexd-bootstrap
- strip \`.note.android.memtag\` from bpfloader/netd/ip*
- **stock** bootstrap \`linker64\` + \`/system/lib64/bootstrap/*\`
- drop GuardTalk/userdebug-only init \`.rc\` files
- ${virt_blurb}
- apex set: ${apex_blurb}
- apexd binary: ${apexd_blurb}
- init binary: ${init_blurb}
- init.rc: ${initrc_blurb}
- hwasan native deps: ${hwasan_blurb}
- SELinux early-apex: ${selinux_blurb}
- vendor: ${vendor_blurb}

**Failure classes (bound):**
- \`0xfc\` / \`reboot bootloader\` (~18s): \`apexd-bootstrap\`
  \`reboot_on_failure\` (stamps \`103641\`…\`130329\`; stockhwasan-sole +
  flash-parity-sole **FALSIFIED** on \`153335\`; stockselinux-sole
  **FALSIFIED** on \`044126\`; bootstrap-set APEX-content-sole **FALSIFIED**
  on \`130329\`).
- \`0x00000100\` / Kernel PANIC \`0xbaba\` / mode \`0x0\` (~61s): init exit
  status **1** — \`141438\` stockinit (**stock-init-sole FALSIFIED**).
- \`0x00007f00\`: historical init/exec kill (status 127).

On-device PASS **HOLD** — flash this bisect via \`REMOTE_BUILD_DIR\`
(do **not** promote as \`rango-latest\` / do **not** promote stockinit).

**No** factory-vendor sepolicy graft (except MODE=stockvendor, which swaps
the whole vendor partition byte-identical to factory — see vendor bullet).
**Do not flash fullgt** — ABL rejects GT boot (AB 11311112).

| Partition | Source |
|-----------|--------|
| bootloader / radio | Factory CP1A |
| boot / init_boot / vendor_boot / vendor_kernel_boot / dtbo / pvmfw | Factory CP1A |
| system_dlkm / vendor_dlkm | Factory CP1A (matches factory kernel 6.6.102) |
| system / system_ext / product | GuardTalkOS OUT (patched system.img) |
| vendor | ${vendor_table_blurb} |
| vbmeta* | Flags:3 valid test-key |
| avb_custom_key | \`avb_pkmd.bin\` |

\`\`\`bash
# On Mac — recover slot retries first if stuck in forced fastboot:
fastboot set_active a
cd ~/GuardTalk-flash
unset REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
EOF
  if [ "$use_remote_build_dir" = "1" ]; then
    cat >> "$DEST/README-FLASH-DESKTOP.md" <<EOF
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/$STAMP
DEVICE=rango ./flash-from-remote.sh
# On fail IMMEDIATELY (before retries drain):
fastboot oem dmesg | tee ~/rango-dmesg-apex.txt
# Classify: KP 0x00007f00 vs KP 0x00000100 vs Reboot mode 0xfc
\`\`\`

BUILD_ID: CP1A.260505.005
Staged (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  else
    cat >> "$DEST/README-FLASH-DESKTOP.md" <<EOF
unset REMOTE_BUILD_DIR
DEVICE=rango ./flash-from-remote.sh
# On fail IMMEDIATELY (before retries drain):
fastboot oem dmesg | tee ~/rango-dmesg-deep.txt
# Classify: KP 0x00007f00 vs KP 0x00000100 vs Reboot mode 0xfc
\`\`\`

BUILD_ID: CP1A.260505.005
Staged (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  fi

  write_sha256sums
  log "DONE ($MODE): $DEST"
}

# ===========================================================================
# MODE: hybrid — LEGACY factory-vendor graft (on-device FAIL 0x7f00). Bisect only.
# ===========================================================================
stage_hybrid() {
  need "$OUT/system.img"
  need "$OUT/system_ext.img"
  need "$OUT/product.img"
  need "$OUT/vendor/etc/selinux/precompiled_sepolicy"
  need "$STOCK/vendor.img"
  need "$STOCK/system_dlkm.img"
  need "$STOCK/vendor_dlkm.img"
  need "$STOCKCTL/bootloader.img"
  need "$STOCKCTL/radio.img"
  need "$HOST_BIN/lpmake"
  need "$HOST_BIN/debugfs"
  need "$HOST_BIN/img2simg"
  need "$HOST_BIN/simg2img"

  local boot_src="$RESCUE"
  [ -f "$boot_src/boot.img" ] || boot_src="$STOCK"
  need "$boot_src/boot.img"
  need "$boot_src/init_boot.img"
  need "$boot_src/vendor_boot.img"

  local vbmeta_flags3="" pkmd=""
  for c in \
    "$ROOT/releases/desktop-flash/rango-latest/vbmeta_valid_flags3.img" \
    "$ROOT/releases/desktop-flash/rango-memtagfix2-20260728-101648/vbmeta_valid_flags3.img"
  do [ -f "$c" ] && vbmeta_flags3="$c" && break; done
  [ -n "$vbmeta_flags3" ] || die "vbmeta_valid_flags3.img not found in any known source"
  for c in \
    "$ROOT/releases/desktop-flash/rango-latest/avb_pkmd_testkey.bin" \
    "$ROOT/releases/desktop-flash/rango-memtagfix2-20260728-101648/avb_pkmd_testkey.bin"
  do [ -f "$c" ] && pkmd="$c" && break; done
  [ -n "$pkmd" ] || die "avb_pkmd_testkey.bin not found in any known source"

  sepolicy_hash_gate
  mte_strip_gate

  rm -rf "$WORK"; mkdir -p "$WORK" "$DEST"

  log "Copy factory vendor -> graft GT precompiled_sepolicy..."
  cp -f "$STOCK/vendor.img" "$WORK/vendor.img"
  if file "$WORK/vendor.img" | grep -qi 'sparse'; then
    "$HOST_BIN/simg2img" "$WORK/vendor.img" "$WORK/vendor.raw"
    mv "$WORK/vendor.raw" "$WORK/vendor.img"
  fi

  local dbg="$HOST_BIN/debugfs" sedir="$OUT/vendor/etc/selinux"
  for f in \
    precompiled_sepolicy \
    precompiled_sepolicy.plat_sepolicy_and_mapping.sha256 \
    precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256 \
    precompiled_sepolicy.product_sepolicy_and_mapping.sha256
  do
    log "  write $f"
    "$dbg" -w -R "rm etc/selinux/$f" "$WORK/vendor.img" >/dev/null 2>&1 || true
    "$dbg" -w -R "write $sedir/$f etc/selinux/$f" "$WORK/vendor.img" >/dev/null \
      || die "debugfs write failed for $f"
  done

  "$dbg" -R "dump etc/selinux/precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256 $WORK/v.se" \
    "$WORK/vendor.img" >/dev/null
  cmp "$WORK/v.se" "$OUT/system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256" \
    || die "post-graft verify FAILED (system_ext) — refusing to ship"
  log "  graft verified against staged vendor image ✓"

  log "Prepare partition images..."
  unsparse_if_needed "$OUT/system.img" "$WORK/system.img"
  unsparse_if_needed "$OUT/system_ext.img" "$WORK/system_ext.img"
  unsparse_if_needed "$OUT/product.img" "$WORK/product.img"
  unsparse_if_needed "$STOCK/system_dlkm.img" "$WORK/system_dlkm.img"
  unsparse_if_needed "$STOCK/vendor_dlkm.img" "$WORK/vendor_dlkm.img"
  cp -f "$WORK/vendor.img" "$WORK/vendor_raw.img"

  local sys_sz se_sz pr_sz sdlkm_sz ven_sz vdlkm_sz
  sys_sz=$(sz "$WORK/system.img"); se_sz=$(sz "$WORK/system_ext.img")
  pr_sz=$(sz "$WORK/product.img"); sdlkm_sz=$(sz "$WORK/system_dlkm.img")
  ven_sz=$(sz "$WORK/vendor_raw.img"); vdlkm_sz=$(sz "$WORK/vendor_dlkm.img")

  local super_size=8531214336 group_size=8527020032
  log "lpmake super.img..."
  "$HOST_BIN/lpmake" \
    --metadata-size 65536 --super-name super --metadata-slots 3 \
    --device super:"$super_size" \
    --group google_dynamic_partitions:"$group_size" \
    --partition system_a:readonly:"$sys_sz":google_dynamic_partitions --image system_a="$WORK/system.img" \
    --partition system_b:readonly:0:google_dynamic_partitions \
    --partition system_ext_a:readonly:"$se_sz":google_dynamic_partitions --image system_ext_a="$WORK/system_ext.img" \
    --partition system_ext_b:readonly:0:google_dynamic_partitions \
    --partition product_a:readonly:"$pr_sz":google_dynamic_partitions --image product_a="$WORK/product.img" \
    --partition product_b:readonly:0:google_dynamic_partitions \
    --partition vendor_a:readonly:"$ven_sz":google_dynamic_partitions --image vendor_a="$WORK/vendor_raw.img" \
    --partition vendor_b:readonly:0:google_dynamic_partitions \
    --partition system_dlkm_a:readonly:"$sdlkm_sz":google_dynamic_partitions --image system_dlkm_a="$WORK/system_dlkm.img" \
    --partition system_dlkm_b:readonly:0:google_dynamic_partitions \
    --partition vendor_dlkm_a:readonly:"$vdlkm_sz":google_dynamic_partitions --image vendor_dlkm_a="$WORK/vendor_dlkm.img" \
    --partition vendor_dlkm_b:readonly:0:google_dynamic_partitions \
    --sparse --output "$WORK/super.img" \
    || die "lpmake failed"

  log "Stage bundle -> $DEST"
  cp -f "$WORK/super.img" "$DEST/super.img"
  "$HOST_BIN/img2simg" "$WORK/vendor_raw.img" "$DEST/vendor.img"
  cp -f "$OUT/system.img" "$DEST/system.img"
  cp -f "$OUT/system_ext.img" "$DEST/system_ext.img"
  cp -f "$OUT/product.img" "$DEST/product.img"
  cp -f "$STOCK/system_dlkm.img" "$DEST/system_dlkm.img"
  cp -f "$STOCK/vendor_dlkm.img" "$DEST/vendor_dlkm.img"
  [ -f "$STOCK/super_empty.img" ] && cp -f "$STOCK/super_empty.img" "$DEST/super_empty.img"
  cp -f "$STOCKCTL/bootloader.img" "$DEST/bootloader.img"
  cp -f "$STOCKCTL/radio.img" "$DEST/radio.img"

  for img in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img pvmfw.img; do
    cp -f "$boot_src/$img" "$DEST/$img"
  done
  [ -f "$STOCKCTL/vendor_boot_diag.img" ] && cp -f "$STOCKCTL/vendor_boot_diag.img" "$DEST/vendor_boot_diag.img"

  cp -f "$vbmeta_flags3" "$DEST/vbmeta.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_system.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_vendor.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_valid_flags3.img"
  cp -f "$pkmd" "$DEST/avb_pkmd.bin"
  cp -f "$pkmd" "$DEST/avb_pkmd_testkey.bin"

  if [ -f "$OUT/vendor_dlkm/etc/init.insmod.rango.cfg" ]; then
    cp -f "$OUT/vendor_dlkm/etc/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  elif [ -f "$ROOT/vendor/guardtalk/device/rango/init.insmod.rango.cfg" ]; then
    cp -f "$ROOT/vendor/guardtalk/device/rango/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  fi

  cat > "$DEST/README-FLASH-DESKTOP.md" <<EOF
# rango hybrid release — $STAMP

Factory CP1A boot + GuardTalkOS userspace + GT sepolicy graft (RCA §5 proven
interim direction). Produced by \`vendor/guardtalk/scripts/stage-rango-release.sh\`
(MODE=hybrid) — supersedes the archived one-off \`stage-rango-hybrid.sh\`.

| Partition | Source |
|-----------|--------|
| bootloader / radio | Factory CP1A (\`rango-stock-control\`) |
| boot / init_boot / vendor_boot / vendor_kernel_boot / dtbo / pvmfw | Factory CP1A rescue boot (proven to reach fastbootd) |
| system / system_ext / product | GuardTalkOS (current \`out/target/product/rango\`) |
| vendor | Factory CP1A drivers + **GT precompiled_sepolicy** (hashes verified MATCH, hard gate) |
| system_dlkm / vendor_dlkm | Factory CP1A |
| vbmeta / vbmeta_system / vbmeta_vendor | Flags:3 valid test-key (\`vbmeta_valid_flags3.img\`) |
| avb_custom_key | \`avb_pkmd.bin\` (public testkey pkmd; erase then flash) |
| super | lpmake (this script) |

## Residual gap (Architect binding, RCA §7 H1/H2)

A prior stamp with MATCHing sepolicy hashes reportedly still hit init
\`exitcode=0x00007f00\` in earlier sprint evidence. Sepolicy hash MATCH rules
out the *primary* root cause but is not itself proof of a full successful
boot. See \`vendor/guardtalk/docs/RANGO_BOOT_FIX.md\` for the HOLD diagnostic
plan (H1–H5) and the parallel \`rango-avbcontrol-*\` / \`rango-fullgt-*\`
staged control bundles used to further isolate the failure surface.

## Flash (desktop) — canonical entrypoint only

Do **not** use any archived experimental flash wrapper
(\`.agent-comm/completed/rango-flash-mess-20260801/\`).

\`\`\`bash
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_BUILD_DIR=$ROOT/releases/desktop-flash/rango-latest
export REMOTE_KEY_DIR=$ROOT/releases/desktop-flash/rango-latest
DEVICE=rango bash scripts/flash-from-remote.sh
# (vendor/guardtalk/scripts/flash-from-remote.sh also KEPT — either works)
\`\`\`

BUILD_ID: CP1A.260505.005
Staged (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  write_sha256sums
  log "DONE: $DEST"
}

# ===========================================================================
# MODE: fullgt — fully coherent OUT build, for RCA HOLD H3. Never linked.
# ===========================================================================
stage_fullgt() {
  need "$OUT/system.img"; need "$OUT/system_ext.img"; need "$OUT/product.img"
  need "$OUT/vendor.img"; need "$OUT/system_dlkm.img"; need "$OUT/vendor_dlkm.img"
  need "$OUT/boot.img"; need "$OUT/init_boot.img"; need "$OUT/vendor_boot.img"
  need "$OUT/vendor_kernel_boot.img"; need "$OUT/dtbo.img"; need "$OUT/pvmfw.img"
  need "$STOCKCTL/bootloader.img"; need "$STOCKCTL/radio.img"
  need "$HOST_BIN/lpmake"; need "$HOST_BIN/img2simg"

  sepolicy_hash_gate
  mte_strip_gate

  rm -rf "$WORK"; mkdir -p "$WORK" "$DEST"

  log "Preparing fully-coherent OUT partition images (no graft — native MATCH)..."
  unsparse_if_needed "$OUT/system.img" "$WORK/system.img"
  unsparse_if_needed "$OUT/system_ext.img" "$WORK/system_ext.img"
  unsparse_if_needed "$OUT/product.img" "$WORK/product.img"
  unsparse_if_needed "$OUT/vendor.img" "$WORK/vendor.img"
  unsparse_if_needed "$OUT/system_dlkm.img" "$WORK/system_dlkm.img"
  unsparse_if_needed "$OUT/vendor_dlkm.img" "$WORK/vendor_dlkm.img"

  local sys_sz se_sz pr_sz ven_sz sdlkm_sz vdlkm_sz
  sys_sz=$(sz "$WORK/system.img"); se_sz=$(sz "$WORK/system_ext.img")
  pr_sz=$(sz "$WORK/product.img"); ven_sz=$(sz "$WORK/vendor.img")
  sdlkm_sz=$(sz "$WORK/system_dlkm.img"); vdlkm_sz=$(sz "$WORK/vendor_dlkm.img")

  local super_size=8531214336 group_size=8527020032
  log "lpmake super.img (full-GT)..."
  "$HOST_BIN/lpmake" \
    --metadata-size 65536 --super-name super --metadata-slots 3 \
    --device super:"$super_size" \
    --group google_dynamic_partitions:"$group_size" \
    --partition system_a:readonly:"$sys_sz":google_dynamic_partitions --image system_a="$WORK/system.img" \
    --partition system_b:readonly:0:google_dynamic_partitions \
    --partition system_ext_a:readonly:"$se_sz":google_dynamic_partitions --image system_ext_a="$WORK/system_ext.img" \
    --partition system_ext_b:readonly:0:google_dynamic_partitions \
    --partition product_a:readonly:"$pr_sz":google_dynamic_partitions --image product_a="$WORK/product.img" \
    --partition product_b:readonly:0:google_dynamic_partitions \
    --partition vendor_a:readonly:"$ven_sz":google_dynamic_partitions --image vendor_a="$WORK/vendor.img" \
    --partition vendor_b:readonly:0:google_dynamic_partitions \
    --partition system_dlkm_a:readonly:"$sdlkm_sz":google_dynamic_partitions --image system_dlkm_a="$WORK/system_dlkm.img" \
    --partition system_dlkm_b:readonly:0:google_dynamic_partitions \
    --partition vendor_dlkm_a:readonly:"$vdlkm_sz":google_dynamic_partitions --image vendor_dlkm_a="$WORK/vendor_dlkm.img" \
    --partition vendor_dlkm_b:readonly:0:google_dynamic_partitions \
    --sparse --output "$WORK/super.img" \
    || die "lpmake failed"

  cp -f "$WORK/super.img" "$DEST/super.img"
  cp -f "$STOCKCTL/bootloader.img" "$DEST/bootloader.img"
  cp -f "$STOCKCTL/radio.img" "$DEST/radio.img"
  for img in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img pvmfw.img; do
    cp -f "$OUT/$img" "$DEST/$img"
  done
  cp -f "$OUT/vbmeta.img" "$DEST/vbmeta.img" 2>/dev/null || true
  cp -f "$OUT/vbmeta_system.img" "$DEST/vbmeta_system.img" 2>/dev/null || true
  cp -f "$OUT/vbmeta_vendor.img" "$DEST/vbmeta_vendor.img" 2>/dev/null || true

  local pkmd=""
  for c in "$ROOT/releases/desktop-flash/rango-latest/avb_pkmd_testkey.bin" \
           "$ROOT/releases/desktop-flash/rango-memtagfix2-20260728-101648/avb_pkmd_testkey.bin"; do
    [ -f "$c" ] && pkmd="$c" && break
  done
  [ -n "$pkmd" ] && cp -f "$pkmd" "$DEST/avb_pkmd.bin"

  cat > "$DEST/README-FLASH-DESKTOP.md" <<EOF
# rango FULL-GT diagnostic build — $STAMP (NOT rango-latest)

**Purpose (RCA HOLD H3):** GT boot/init_boot/vendor_boot chain + GT vendor +
GT system\* + GT dlkm, ALL from ONE current \`out/target/product/rango\` build
(no factory graft, no factory boot substitution — the sepolicy hashes MATCH
natively because everything came from the same \`m\` run).

The RCA (\`vendor/guardtalk/docs/RANGO_BOOT_RCA.md\` §1/§2.4) documents that
raw GT test-key boot images were previously rejected or unstable at this
bootloader pin (ABL \`AB 31112113\` reject vs stock CP1A \`AB 31111122\`
accept) unless \`avb_custom_key\` is loaded with the matching public key.
This bundle is the exact artifact needed to test that hypothesis once a
device is available — flash \`avb_custom_key\` from \`avb_pkmd.bin\` FIRST,
then flash this bundle, and capture \`fastboot oem dmesg\` / ABL decision
codes (H3).

**Do not point \`rango-latest\` at this bundle** — GT boot-chain ABL
acceptance is unverified (HOLD). Use only for manual H3 diagnosis via
\`REMOTE_BUILD_DIR\`/\`REMOTE_KEY_DIR\` overrides to \`flash-from-remote.sh\`:

\`\`\`bash
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_BUILD_DIR=$DEST
export REMOTE_KEY_DIR=$DEST
DEVICE=rango bash scripts/flash-from-remote.sh
\`\`\`

Staged (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  write_sha256sums
  log "DONE (diagnostic only, not linked): $DEST"
}

# ===========================================================================
# MODE: avbcontrol — 100% stock content + Flags:3 vbmeta. Never linked.
# ===========================================================================
stage_avbcontrol() {
  local src_super="$ROOT/releases/desktop-flash/rango-stocksuper-avbok/super.img"
  need "$src_super"
  need "$STOCKCTL/bootloader.img"; need "$STOCKCTL/radio.img"

  local boot_src="$ROOT/releases/desktop-flash/rango-stocksuper-avbok"
  need "$boot_src/boot.img"; need "$boot_src/init_boot.img"
  need "$boot_src/vendor_boot.img"; need "$boot_src/vendor_kernel_boot.img"
  need "$boot_src/dtbo.img"; need "$boot_src/pvmfw.img"
  need "$boot_src/vbmeta_valid_flags3.img"
  need "$boot_src/avb_pkmd_testkey.bin"

  # flash-from-remote.sh always downloads LOGICAL_IMAGES even when super.img
  # is present (super is preferred at flash time; download list is still hard).
  # Populate factory logicals from rango-stock-userspace / stock-control.
  local stock_userspace="$ROOT/releases/desktop-flash/rango-stock-userspace"
  need "$stock_userspace/system.img"
  need "$stock_userspace/system_ext.img"
  need "$stock_userspace/product.img"
  need "$stock_userspace/vendor.img"
  need "$stock_userspace/vendor_dlkm.img"
  need "$stock_userspace/system_dlkm.img"

  mkdir -p "$DEST"
  cp -f "$src_super" "$DEST/super.img"
  cp -f "$STOCKCTL/bootloader.img" "$DEST/bootloader.img"
  cp -f "$STOCKCTL/radio.img" "$DEST/radio.img"
  for img in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img pvmfw.img; do
    cp -f "$boot_src/$img" "$DEST/$img"
  done
  for img in system.img system_ext.img product.img vendor.img vendor_dlkm.img system_dlkm.img; do
    cp -f "$stock_userspace/$img" "$DEST/$img"
  done
  if [ -f "$stock_userspace/super_empty.img" ]; then
    cp -f "$stock_userspace/super_empty.img" "$DEST/super_empty.img"
  else
    need "$STOCKCTL/super_empty.img"
    cp -f "$STOCKCTL/super_empty.img" "$DEST/super_empty.img"
  fi
  if [ -f "$STOCKCTL/init.insmod.rango.cfg" ]; then
    cp -f "$STOCKCTL/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  fi
  cp -f "$boot_src/vbmeta_valid_flags3.img" "$DEST/vbmeta.img"
  cp -f "$boot_src/vbmeta_valid_flags3.img" "$DEST/vbmeta_system.img"
  cp -f "$boot_src/vbmeta_valid_flags3.img" "$DEST/vbmeta_vendor.img"
  cp -f "$boot_src/vbmeta_valid_flags3.img" "$DEST/vbmeta_valid_flags3.img"
  cp -f "$boot_src/avb_pkmd_testkey.bin" "$DEST/avb_pkmd.bin"
  cp -f "$boot_src/avb_pkmd_testkey.bin" "$DEST/avb_pkmd_testkey.bin"
  [ -f "$boot_src/vendor_boot_diag.img" ] && cp -f "$boot_src/vendor_boot_diag.img" "$DEST/vendor_boot_diag.img"

  cat > "$DEST/README-FLASH-DESKTOP.md" <<EOF
# rango STOCK + AVB Flags:3 control build — $STAMP (NOT rango-latest)

**Purpose (Architect residual-gap binding item 2):** ZERO GuardTalkOS
content. 100% factory CP1A super/system/vendor/boot + Flags:3 valid
test-key vbmeta (same AVB unlock posture as the GuardTalkOS hybrid). If this
bundle boots cleanly to \`adb\` (or to stock Android UI), it proves the
**AVB path itself is OK** with Flags:3 + test-key + \`avb_custom_key\`, which
isolates the earlier \`0x7f00\` reports to **GT system\* content**, not the
verified-boot chain. If it does NOT boot, the AVB/bootloader path itself is
implicated and GuardTalkOS system content is exonerated as sole cause.

| Partition | Source |
|-----------|--------|
| bootloader / radio | Factory CP1A |
| boot / init_boot / vendor_boot / vendor_kernel_boot / dtbo / pvmfw | Factory CP1A |
| super (system/system_ext/product/vendor/system_dlkm/vendor_dlkm) | Factory CP1A, unmodified |
| vbmeta* | Flags:3 valid test-key (\`vbmeta_valid_flags3.img\`) |
| avb_custom_key | \`avb_pkmd.bin\` (public testkey pkmd) |

**Do not point \`rango-latest\` at this bundle.**

\`\`\`bash
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_BUILD_DIR=$DEST
export REMOTE_KEY_DIR=$DEST
DEVICE=rango bash scripts/flash-from-remote.sh
# Evidence to capture: adb devices (boot OK?) and/or
# fastboot oem dmesg (if it falls back to bootloader)
\`\`\`

Staged (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  write_sha256sums
  log "DONE (diagnostic control only, not linked): $DEST"
}

# ===========================================================================
# MODE: gtsystemonstock — INVERTED bisect. Stock everything + GT system.img.
# The 10-day campaign subtracted stock pieces from GT and exhausted those
# surfaces. This starts from the known-good avbcontrol composition and adds
# ONE GT partition. PASS → GT system is not sufficient to cause 0xfc (next:
# add system_ext). FAIL 0xfc → GT system.img contains the trigger.
# ===========================================================================
stage_gtsystemonstock() {
  need "$OUT/system.img"
  need "$STOCK/system_ext.img"; need "$STOCK/product.img"; need "$STOCK/vendor.img"
  need "$STOCK/system_dlkm.img"; need "$STOCK/vendor_dlkm.img"
  need "$STOCKCTL/bootloader.img"; need "$STOCKCTL/radio.img"
  need "$HOST_BIN/lpmake"; need "$HOST_BIN/img2simg"; need "$HOST_BIN/simg2img"

  local boot_src="$RESCUE"
  [ -f "$boot_src/boot.img" ] || boot_src="$STOCK"
  need "$boot_src/boot.img"
  need "$boot_src/init_boot.img"
  need "$boot_src/vendor_boot.img"
  need "$boot_src/vendor_kernel_boot.img"
  need "$boot_src/dtbo.img"
  need "$boot_src/pvmfw.img"

  local vbmeta_flags3="" pkmd=""
  for c in \
    "$ROOT/releases/desktop-flash/rango-avbcontrol-20260801-072014/vbmeta_valid_flags3.img" \
    "$ROOT/releases/desktop-flash/rango-latest/vbmeta_valid_flags3.img"
  do [ -f "$c" ] && vbmeta_flags3="$c" && break; done
  [ -n "$vbmeta_flags3" ] || die "vbmeta_valid_flags3.img not found"
  for c in \
    "$ROOT/releases/desktop-flash/rango-avbcontrol-20260801-072014/avb_pkmd.bin" \
    "$ROOT/releases/desktop-flash/rango-latest/avb_pkmd.bin"
  do [ -f "$c" ] && pkmd="$c" && break; done
  [ -n "$pkmd" ] || die "avb_pkmd not found"

  rm -rf "$WORK"; mkdir -p "$WORK" "$DEST"

  log "INVERTED: stock userspace + GT system.img only (no stock grafts on system)"
  unsparse_if_needed "$OUT/system.img" "$WORK/system.img"
  # Factory-boot compatibility only (restorecon /metadata, drop GT-only rc
  # that cannot run on factory kernel). No stock binary/apex/sepolicy grafts
  # unless MODE=gtsystemonstockselinux|gtsystemonstockinitboot.
  patch_system_img_for_factory_boot "$WORK/system.img"
  unsparse_if_needed "$STOCK/system_ext.img" "$WORK/system_ext.img"
  unsparse_if_needed "$STOCK/product.img" "$WORK/product.img"
  unsparse_if_needed "$STOCK/vendor.img" "$WORK/vendor.img"
  unsparse_if_needed "$STOCK/system_dlkm.img" "$WORK/system_dlkm.img"
  unsparse_if_needed "$STOCK/vendor_dlkm.img" "$WORK/vendor_dlkm.img"

  if [ "$MODE" = "gtsystemonstockselinux" ] || [ "$MODE" = "gtsystemonstockinitboot" ] \
     || [ "$MODE" = "gtsystemonstockinitlibs" ] || [ "$MODE" = "gtsystemonstocknovirt" ] \
     || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    # 071115: GT plat + stock vendor → KP 0x7f00. Graft stock plat (+
    # ext/product which are already stock) so hashes MATCH vendor precompiled.
    # 100054: hashes MATCH and still 0x7f00 — keep the graft so this
    # follow-up does not re-introduce the known mismatch.
    log "Coherent stock sepolicy on inverted composition (071115/100054 follow-up)..."
    patch_stock_selinux_early_apex \
      "$WORK/system.img" "$WORK/system_ext.img" "$WORK/product.img" "$WORK/vendor.img"
  fi

  if [ "$MODE" = "gtsystemonstockinitboot" ] || [ "$MODE" = "gtsystemonstockinitlibs" ] \
     || [ "$MODE" = "gtsystemonstocknovirt" ] || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    # 100054: matching plat hashes still KP 0x7f00. GT init (2938144) +
    # GT bootstrap linker/libc remain. stockinit-alone on GT userspace
    # was 0x100; bootstrap-alone was 0xfc; the pair was never flashed.
    # 104334: pair flashed → KP 0x100 (bootstrap MATCH; lib64 NEEDED still GT).
    log "Stock init + bootstrap/hwasan on inverted+selinux (100054/104334 follow-up)..."
    patch_stock_bootstrap "$WORK/system.img"
    patch_stock_hwasan_native_deps "$WORK/system.img"
    patch_stock_init "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockinitlibs" ] || [ "$MODE" = "gtsystemonstocknovirt" ] \
     || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock init NEEDED /system/lib64 closure (104334 0x100 follow-up)..."
    patch_stock_init_needed_libs "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstocknovirt" ] || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ]; then
    # 110531: inverted initlibs reached apexd-bootstrap 0xfc ~18s.
    # 112754: drop virt still 0xfc — virt-sole FALSIFIED.
    log "Drop GT com.android.virt.apex (110531/112754 0xfc follow-up)..."
    patch_drop_bootstrap_virt "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ]; then
    # Stock runtime/i18n are larger than GT (8.8/37.8 vs 5.2/20.8 MiB).
    # Grow before debugfs write (130338 allocator class).
    log "Stock kBootstrapApexes runtime/i18n/tzdata (112754 0xfc follow-up)..."
    local cur_size new_size fsck_rc=0
    cur_size="$(stat -c%s "$WORK/system.img")"
    new_size=$((cur_size + 67108864))
    e2fsck -fy "$WORK/system.img" >/dev/null 2>&1 || fsck_rc=$?
    [ "$fsck_rc" -le 2 ] || die "e2fsck pre-bootapex-grow FAILED (rc=$fsck_rc)"
    truncate -s "$new_size" "$WORK/system.img" || die "truncate bootapex grow failed"
    resize2fs "$WORK/system.img" >/dev/null 2>&1 || die "resize2fs bootapex grow failed"
    log "  grew system.img $cur_size -> $new_size (+64MiB bootapex headroom) ✓"
    patch_stock_bootstrap_apexes "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    # 114442: stock runtime/i18n/tzdata + no virt still 0xfc. apexd.rc
    # MATCH stock; GT /system/bin/apexd (1030416) remains.
    log "Stock /system/bin/apexd (114442 0xfc follow-up)..."
    patch_stock_apexd "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/etc/ueventd.rc (103210 0xfc follow-up)..."
    patch_stock_ueventd_rc "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    # 105952: stock ueventd.rc still 0xfc. Early init.rc apexd-bootstrap
    # path already MATCH stock. Remaining named variable: leftover GT
    # /system/apex (com.android.* vs stock com.google.android.* set).
    log "Stock /system/apex WHOLESALE (105952 0xfc follow-up)..."
    patch_stock_apexset_wholesale "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/build.prop (115437 0xfc follow-up)..."
    patch_stock_build_prop "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock apexd NEEDED DIFF libs (123449 0xfc follow-up)..."
    patch_stock_apexd_needed_libs "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock plat_property_contexts (064000 0xfc follow-up)..."
    patch_stock_plat_property_contexts "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock init.rc (065959 0xfc follow-up)..."
    patch_stock_init_rc "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock remaining plat contexts (071944 0xfc follow-up)..."
    patch_stock_remaining_plat_contexts "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock leftover early-init surface (073937 0xfc follow-up)..."
    patch_stock_early_init_surface "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock libprotobuf-cpp-full (092118 0xfc follow-up; size-MATCH cmp-DIFF)..."
    patch_stock_protobuf "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock libc++.so (094500 0x100 follow-up; size-MATCH cmp-DIFF)..."
    patch_stock_libcxx "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock ld-android.so (062622 0xfc follow-up; size-MATCH cmp-DIFF)..."
    patch_stock_ldandroid "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/etc/apexd/empty_erofs.img (123801 0xfc follow-up)..."
    patch_stock_apexdetc "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/etc/task_profiles.json (135504 0xfc follow-up)..."
    patch_stock_taskprof "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/etc/aconfig (142515 0xfc follow-up)..."
    patch_stock_aconfig "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/etc/aconfig_flags.pb (144322 0xfc follow-up)..."
    patch_stock_acflags "$WORK/system.img"
  fi

  if [ "$MODE" = "gtsystemonstockbflags" ]; then
    log "Stock /system/etc/build_flags.json (150620 0xfc follow-up)..."
    patch_stock_bflags "$WORK/system.img"
  fi

  # Hard gates: stock partitions stay stock; system stays GT unless
  # initboot grafts stock init/bootstrap. selinux/initboot rewrite
  # sepolicy via debugfs — skip byte-cmp on system_ext/product/vendor;
  # dlkm is untouched either way.
  local h
  local gate_imgs="system_ext product vendor system_dlkm vendor_dlkm"
  if [ "$MODE" = "gtsystemonstockselinux" ] || [ "$MODE" = "gtsystemonstockinitboot" ] \
     || [ "$MODE" = "gtsystemonstockinitlibs" ] || [ "$MODE" = "gtsystemonstocknovirt" ] \
     || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    gate_imgs="system_dlkm vendor_dlkm"
    log "  skipping system_ext/product/vendor byte-cmp (sepolicy graft rewrites fs)"
  fi
  for img in $gate_imgs; do
    h="$(sha256sum "$STOCK/${img}.img" | awk '{print $1}')"
    # compare unsparsed work copies against unsparsed stock
    local stock_raw="$WORK/_gate_${img}.img"
    unsparse_if_needed "$STOCK/${img}.img" "$stock_raw"
    cmp -s "$WORK/${img}.img" "$stock_raw" \
      || die "$img work copy DIFFERS from stock donor — inverted bisect contaminated"
    rm -f "$stock_raw"
    log "  $img MATCH stock donor ✓"
  done
  local gt_init_sz linker_sz libc_sz
  # debugfs prints "User: N ... Size: BYTES" on one line — do not awk $2 (that is uid).
  _dfs_size() { debugfs -R "stat $1" "$2" 2>/dev/null | sed -n 's/.* Size: \([0-9][0-9]*\).*/\1/p' | head -1; }
  gt_init_sz="$(_dfs_size /system/bin/init "$WORK/system.img")"
  [ -n "$gt_init_sz" ] || gt_init_sz=0
  if [ "$MODE" = "gtsystemonstockinitboot" ] || [ "$MODE" = "gtsystemonstockinitlibs" ] \
     || [ "$MODE" = "gtsystemonstocknovirt" ] || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
    [ "$gt_init_sz" = "2771368" ] \
      || die "initboot expected stock init 2771368 bytes, got $gt_init_sz"
    linker_sz="$(_dfs_size /system/bin/bootstrap/linker64 "$WORK/system.img")"
    libc_sz="$(_dfs_size /system/lib64/bootstrap/libc.so "$WORK/system.img")"
    [ "$linker_sz" = "2433440" ] \
      || die "initboot expected stock linker64 2433440 bytes, got $linker_sz"
    [ "$libc_sz" = "1285800" ] \
      || die "initboot expected stock bootstrap libc 1285800 bytes, got $libc_sz"
    if [ "$MODE" = "gtsystemonstockinitlibs" ] || [ "$MODE" = "gtsystemonstocknovirt" ] \
       || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ] || [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
      local fsmgr_sz cxx_sz fecrs_sz
      fsmgr_sz="$(_dfs_size /system/lib64/libfs_mgr.so "$WORK/system.img")"
      cxx_sz="$(_dfs_size /system/lib64/libc++.so "$WORK/system.img")"
      fecrs_sz="$(_dfs_size /system/lib64/libfec_rs.so "$WORK/system.img")"
      [ "$fsmgr_sz" = "581272" ] || die "initlibs expected stock libfs_mgr 581272, got $fsmgr_sz"
      [ "$cxx_sz" = "1152784" ] || die "initlibs expected stock libc++ 1152784, got $cxx_sz"
      [ "$fecrs_sz" = "51768" ] || die "initlibs expected stock libfec_rs 51768, got $fecrs_sz"
      if [ "$MODE" = "gtsystemonstockapexset" ] || [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
        local apexd_sz uev_sz rt_sz i18n_sz tz6_sz virt_sz n_apex
        apexd_sz="$(_dfs_size /system/bin/apexd "$WORK/system.img")"
        [ "$apexd_sz" = "1083368" ] || die "apexset expected stock apexd 1083368, got $apexd_sz"
        uev_sz="$(_dfs_size /system/etc/ueventd.rc "$WORK/system.img")"
        [ "$uev_sz" = "3785" ] || die "apexset expected stock ueventd.rc 3785, got $uev_sz"
        rt_sz="$(_dfs_size /system/apex/com.android.runtime.apex "$WORK/system.img")"
        i18n_sz="$(_dfs_size /system/apex/com.android.i18n.apex "$WORK/system.img")"
        tz6_sz="$(_dfs_size /system/apex/com.google.android.tzdata6.apex "$WORK/system.img")"
        virt_sz="$(_dfs_size /system/apex/com.google.android.virt.apex "$WORK/system.img")"
        [ "$rt_sz" = "8814592" ] || die "apexset expected stock runtime 8814592, got $rt_sz"
        [ "$i18n_sz" = "37842944" ] || die "apexset expected stock i18n 37842944, got $i18n_sz"
        [ "$tz6_sz" = "921600" ] || die "apexset expected stock tzdata6 921600, got $tz6_sz"
        [ "$virt_sz" = "98181120" ] || die "apexset expected stock virt 98181120, got $virt_sz"
        if ! debugfs -R "stat /system/apex/com.android.virt.apex" "$WORK/system.img" 2>&1 \
             | grep -q 'File not found'; then
          die "apexset expected GT com.android.virt.apex ABSENT (stock name is com.google.android.virt.apex)"
        fi
        n_apex="$(debugfs -R 'ls /system/apex' "$WORK/system.img" 2>/dev/null \
          | tr -s ' ' '\n' | grep -cE '^[^[:space:]/]+\.apex$' || true)"
        [ "$n_apex" = "36" ] || die "apexset expected 36 stock apexes, got $n_apex"
        if [ "$MODE" = "gtsystemonstockprop" ] || [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
          local prop_sz
          prop_sz="$(_dfs_size /system/build.prop "$WORK/system.img")"
          [ "$prop_sz" = "5330" ] || die "prop expected stock build.prop 5330, got $prop_sz"
          debugfs -R "dump /system/build.prop $WORK/_build.prop" \
            "$WORK/system.img" >/dev/null 2>&1 \
            || die "dump grafted build.prop failed"
          grep -q 'apexd.config.compressed_apex=true' "$WORK/_build.prop" \
            || die "grafted build.prop missing compressed_apex=true"
          grep -q 'ro.build.version.codename=REL' "$WORK/_build.prop" \
            || die "grafted build.prop missing codename=REL"
          rm -f "$WORK/_build.prop"
          if [ "$MODE" = "gtsystemonstockapexdlibs" ] || [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
            local binder_sz vintf_sz zip_sz aidl_sz support_sz xml_sz
            binder_sz="$(_dfs_size /system/lib64/libbinder.so "$WORK/system.img")"
            vintf_sz="$(_dfs_size /system/lib64/libvintf.so "$WORK/system.img")"
            zip_sz="$(_dfs_size /system/lib64/libziparchive.so "$WORK/system.img")"
            aidl_sz="$(_dfs_size /system/lib64/apex_aidl_interface-cpp.so "$WORK/system.img")"
            support_sz="$(_dfs_size /system/lib64/libapexsupport.so "$WORK/system.img")"
            xml_sz="$(_dfs_size /system/lib64/libtinyxml2.so "$WORK/system.img")"
            [ "$binder_sz" = "953640" ] || die "apexdlibs expected stock libbinder 953640, got $binder_sz"
            [ "$vintf_sz" = "671912" ] || die "apexdlibs expected stock libvintf 671912, got $vintf_sz"
            [ "$zip_sz" = "119416" ] || die "apexdlibs expected stock libziparchive 119416, got $zip_sz"
            [ "$aidl_sz" = "85272" ] || die "apexdlibs expected stock apex_aidl 85272, got $aidl_sz"
            [ "$support_sz" = "186136" ] || die "apexdlibs expected stock libapexsupport 186136, got $support_sz"
            [ "$xml_sz" = "150944" ] || die "apexdlibs expected stock libtinyxml2 150944, got $xml_sz"
            if [ "$MODE" = "gtsystemonstockpctx" ] || [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
              local pctx_sz
              pctx_sz="$(_dfs_size /system/etc/selinux/plat_property_contexts "$WORK/system.img")"
              [ "$pctx_sz" = "125247" ] || die "pctx expected stock 125247, got $pctx_sz"
              debugfs -R "dump /system/etc/selinux/plat_property_contexts $WORK/_pctx" \
                "$WORK/system.img" >/dev/null 2>&1 \
                || die "dump grafted plat_property_contexts failed"
              grep -q 'apexd.config.runtime.erofs_file_backed_mount' "$WORK/_pctx" \
                || die "grafted plat_property_contexts missing erofs_file_backed_mount"
              rm -f "$WORK/_pctx"
              if [ "$MODE" = "gtsystemonstockinitrc" ] || [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                local initrc_sz
                initrc_sz="$(_dfs_size /system/etc/init/hw/init.rc "$WORK/system.img")"
                [ "$initrc_sz" = "57115" ] || die "initrc expected stock 57115, got $initrc_sz"
                debugfs -R "dump /system/etc/init/hw/init.rc $WORK/_initrc" \
                  "$WORK/system.img" >/dev/null 2>&1 \
                  || die "dump grafted init.rc failed"
                grep -q 'perform_apex_config' "$WORK/_initrc" \
                  || die "grafted init.rc missing perform_apex_config"
                grep -q 'exec_start apexd-bootstrap' "$WORK/_initrc" \
                  || die "grafted init.rc missing exec_start apexd-bootstrap"
                rm -f "$WORK/_initrc"
                if [ "$MODE" = "gtsystemonstockplatctx" ] || [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                  local svc_sz seapp_sz mac_sz ks_sz tee_sz
                  svc_sz="$(_dfs_size /system/etc/selinux/plat_service_contexts "$WORK/system.img")"
                  seapp_sz="$(_dfs_size /system/etc/selinux/plat_seapp_contexts "$WORK/system.img")"
                  mac_sz="$(_dfs_size /system/etc/selinux/plat_mac_permissions.xml "$WORK/system.img")"
                  ks_sz="$(_dfs_size /system/etc/selinux/plat_keystore2_key_contexts "$WORK/system.img")"
                  tee_sz="$(_dfs_size /system/etc/selinux/plat_tee_service_contexts "$WORK/system.img")"
                  [ "$svc_sz" = "44820" ] || die "platctx expected stock service 44820, got $svc_sz"
                  [ "$seapp_sz" = "4637" ] || die "platctx expected stock seapp 4637, got $seapp_sz"
                  [ "$mac_sz" = "18378" ] || die "platctx expected stock mac 18378, got $mac_sz"
                  [ "$ks_sz" = "1431" ] || die "platctx expected stock keystore2 1431, got $ks_sz"
                  [ "$tee_sz" = "832" ] || die "platctx expected stock tee 832, got $tee_sz"
                  if [ "$MODE" = "gtsystemonstockearlyinit" ] || [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                    local acfg_sz acfgbin_sz prng_sz cf_sz
                    acfg_sz="$(_dfs_size /system/etc/init/aconfigd.rc "$WORK/system.img")"
                    acfgbin_sz="$(_dfs_size /system/bin/aconfigd-system "$WORK/system.img")"
                    prng_sz="$(_dfs_size /system/bin/prng_seeder "$WORK/system.img")"
                    cf_sz="$(_dfs_size /system/etc/init/casefolding_remover.rc "$WORK/system.img")"
                    [ "$acfg_sz" = "1249" ] || die "earlyinit expected stock aconfigd.rc 1249, got $acfg_sz"
                    [ "$acfgbin_sz" = "86336" ] || die "earlyinit expected stock aconfigd-system 86336, got $acfgbin_sz"
                    [ "$prng_sz" = "137664" ] || die "earlyinit expected stock prng_seeder 137664, got $prng_sz"
                    [ "$cf_sz" = "173" ] || die "earlyinit expected stock casefolding_remover.rc 173, got $cf_sz"
                    debugfs -R "dump /system/etc/init/aconfigd.rc $WORK/_aconfigd.rc" \
                      "$WORK/system.img" >/dev/null 2>&1 \
                      || die "dump grafted aconfigd.rc failed"
                    grep -q 'restorecon_recursive /metadata' "$WORK/_aconfigd.rc" \
                      || die "grafted aconfigd.rc missing restorecon_recursive /metadata"
                    rm -f "$WORK/_aconfigd.rc"
                    if [ "$MODE" = "gtsystemonstockprotobuf" ] || [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                      local pb_sz
                      pb_sz="$(_dfs_size /system/lib64/libprotobuf-cpp-full-6.33.1.so "$WORK/system.img")"
                      [ "$pb_sz" = "3387232" ] || die "protobuf expected size 3387232, got $pb_sz"
                      debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $WORK/_pb.so" \
                        "$WORK/system.img" >/dev/null 2>&1 \
                        || die "dump grafted protobuf failed"
                      debugfs -R "dump /system/lib64/libprotobuf-cpp-full-6.33.1.so $WORK/_pb-stock.so" \
                        "$STOCK/system.img" >/dev/null 2>&1 \
                        || die "dump stock protobuf for cmp failed"
                      cmp -s "$WORK/_pb.so" "$WORK/_pb-stock.so" \
                        || die "grafted protobuf cmp DIFF vs stock (size gate insufficient)"
                      rm -f "$WORK/_pb.so" "$WORK/_pb-stock.so"
                      if [ "$MODE" = "gtsystemonstocklibcxx" ] || [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                        local cxx_sz
                        cxx_sz="$(_dfs_size /system/lib64/libc++.so "$WORK/system.img")"
                        [ "$cxx_sz" = "1152784" ] || die "libcxx expected size 1152784, got $cxx_sz"
                        debugfs -R "dump /system/lib64/libc++.so $WORK/_cxx.so" \
                          "$WORK/system.img" >/dev/null 2>&1 \
                          || die "dump grafted libc++ failed"
                        debugfs -R "dump /system/lib64/libc++.so $WORK/_cxx-stock.so" \
                          "$STOCK/system.img" >/dev/null 2>&1 \
                          || die "dump stock libc++ for cmp failed"
                        cmp -s "$WORK/_cxx.so" "$WORK/_cxx-stock.so" \
                          || die "grafted libc++ cmp DIFF vs stock (size gate insufficient)"
                        rm -f "$WORK/_cxx.so" "$WORK/_cxx-stock.so"
                        if [ "$MODE" = "gtsystemonstockldandroid" ] || [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                          local ld_sz
                          ld_sz="$(_dfs_size /system/lib64/ld-android.so "$WORK/system.img")"
                          [ "$ld_sz" = "34256" ] || die "ldandroid expected size 34256, got $ld_sz"
                          debugfs -R "dump /system/lib64/ld-android.so $WORK/_ld.so" \
                            "$WORK/system.img" >/dev/null 2>&1 \
                            || die "dump grafted ld-android failed"
                          debugfs -R "dump /system/lib64/ld-android.so $WORK/_ld-stock.so" \
                            "$STOCK/system.img" >/dev/null 2>&1 \
                            || die "dump stock ld-android for cmp failed"
                          cmp -s "$WORK/_ld.so" "$WORK/_ld-stock.so" \
                            || die "grafted ld-android cmp DIFF vs stock (size gate insufficient)"
                          rm -f "$WORK/_ld.so" "$WORK/_ld-stock.so"
                          if [ "$MODE" = "gtsystemonstockapexdetc" ] || [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                            local erofs_sz
                            erofs_sz="$(_dfs_size /system/etc/apexd/empty_erofs.img "$WORK/system.img")"
                            [ "$erofs_sz" = "4096" ] || die "empty_erofs expected size 4096, got $erofs_sz"
                            debugfs -R "dump /system/etc/apexd/empty_erofs.img $WORK/_erofs.img" \
                              "$WORK/system.img" >/dev/null 2>&1 \
                              || die "dump grafted empty_erofs.img failed"
                            debugfs -R "dump /system/etc/apexd/empty_erofs.img $WORK/_erofs-stock.img" \
                              "$STOCK/system.img" >/dev/null 2>&1 \
                              || die "dump stock empty_erofs.img for cmp failed"
                            cmp -s "$WORK/_erofs.img" "$WORK/_erofs-stock.img" \
                              || die "grafted empty_erofs.img cmp DIFF vs stock"
                            rm -f "$WORK/_erofs.img" "$WORK/_erofs-stock.img"
                            if [ "$MODE" = "gtsystemonstocktaskprof" ] || [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                              local tp_sz
                              tp_sz="$(_dfs_size /system/etc/task_profiles.json "$WORK/system.img")"
                              [ "$tp_sz" = "15365" ] || die "task_profiles expected size 15365, got $tp_sz"
                              debugfs -R "dump /system/etc/task_profiles.json $WORK/_tp.json" \
                                "$WORK/system.img" >/dev/null 2>&1 \
                                || die "dump grafted task_profiles.json failed"
                              debugfs -R "dump /system/etc/task_profiles.json $WORK/_tp-stock.json" \
                                "$STOCK/system.img" >/dev/null 2>&1 \
                                || die "dump stock task_profiles.json for cmp failed"
                              cmp -s "$WORK/_tp.json" "$WORK/_tp-stock.json" \
                                || die "grafted task_profiles.json cmp DIFF vs stock"
                              rm -f "$WORK/_tp.json" "$WORK/_tp-stock.json"
                              if [ "$MODE" = "gtsystemonstockaconfig" ] || [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                                local af_sz
                                for af_sz in flag.info:1673 flag.map:100550 flag.val:1673 package.map:9725; do
                                  local af_name="${af_sz%%:*}"
                                  local af_expect="${af_sz##*:}"
                                  local got
                                  got="$(_dfs_size /system/etc/aconfig/$af_name "$WORK/system.img")"
                                  [ "$got" = "$af_expect" ] \
                                    || die "aconfig/$af_name expected size $af_expect, got $got"
                                  debugfs -R "dump /system/etc/aconfig/$af_name $WORK/_af.$af_name" \
                                    "$WORK/system.img" >/dev/null 2>&1 \
                                    || die "dump grafted aconfig/$af_name failed"
                                  debugfs -R "dump /system/etc/aconfig/$af_name $WORK/_af-stock.$af_name" \
                                    "$STOCK/system.img" >/dev/null 2>&1 \
                                    || die "dump stock aconfig/$af_name for cmp failed"
                                  cmp -s "$WORK/_af.$af_name" "$WORK/_af-stock.$af_name" \
                                    || die "grafted aconfig/$af_name cmp DIFF vs stock"
                                  rm -f "$WORK/_af.$af_name" "$WORK/_af-stock.$af_name"
                                done
                                if [ "$MODE" = "gtsystemonstockacflags" ] || [ "$MODE" = "gtsystemonstockbflags" ]; then
                                  local flags_sz
                                  flags_sz="$(_dfs_size /system/etc/aconfig_flags.pb "$WORK/system.img")"
                                  [ "$flags_sz" = "696328" ] \
                                    || die "aconfig_flags.pb expected size 696328, got $flags_sz"
                                  debugfs -R "dump /system/etc/aconfig_flags.pb $WORK/_acflags.pb" \
                                    "$WORK/system.img" >/dev/null 2>&1 \
                                    || die "dump grafted aconfig_flags.pb failed"
                                  debugfs -R "dump /system/etc/aconfig_flags.pb $WORK/_acflags-stock.pb" \
                                    "$STOCK/system.img" >/dev/null 2>&1 \
                                    || die "dump stock aconfig_flags.pb for cmp failed"
                                  cmp -s "$WORK/_acflags.pb" "$WORK/_acflags-stock.pb" \
                                    || die "grafted aconfig_flags.pb cmp DIFF vs stock"
                                  rm -f "$WORK/_acflags.pb" "$WORK/_acflags-stock.pb"
                                  if [ "$MODE" = "gtsystemonstockbflags" ]; then
                                    local bf_sz
                                    bf_sz="$(_dfs_size /system/etc/build_flags.json "$WORK/system.img")"
                                    [ "$bf_sz" = "124580" ] \
                                      || die "build_flags.json expected size 124580, got $bf_sz"
                                    debugfs -R "dump /system/etc/build_flags.json $WORK/_bflags.json" \
                                      "$WORK/system.img" >/dev/null 2>&1 \
                                      || die "dump grafted build_flags.json failed"
                                    debugfs -R "dump /system/etc/build_flags.json $WORK/_bflags-stock.json" \
                                      "$STOCK/system.img" >/dev/null 2>&1 \
                                      || die "dump stock build_flags.json for cmp failed"
                                    cmp -s "$WORK/_bflags.json" "$WORK/_bflags-stock.json" \
                                      || die "grafted build_flags.json cmp DIFF vs stock"
                                    rm -f "$WORK/_bflags.json" "$WORK/_bflags-stock.json"
                                    log "  system.img is GT + prior grafts + stock aconfig_flags + stock build_flags.json cmp ✓"
                                  else
                                    log "  system.img is GT + prior grafts + stock aconfig + stock aconfig_flags.pb cmp ✓"
                                  fi
                                else
                                  log "  system.img is GT + prior grafts + stock task_profiles + stock aconfig storage cmp ✓"
                                fi
                              else
                                log "  system.img is GT + prior grafts + stock empty_erofs + stock task_profiles.json cmp ✓"
                              fi
                            else
                              log "  system.img is GT + prior grafts + stock ld-android + stock empty_erofs.img cmp ✓"
                            fi
                          else
                            log "  system.img is GT + prior grafts + stock protobuf + stock libc++ + stock ld-android cmp ✓"
                          fi
                        else
                          log "  system.img is GT + prior grafts + stock protobuf + stock libc++ cmp ✓"
                        fi
                      else
                        log "  system.img is GT + prior grafts + stock protobuf cmp ✓"
                      fi
                    else
                      log "  system.img is GT + prior grafts + leftover early-init rc/bins ✓"
                    fi
                  else
                    log "  system.img is GT + stock init/libs/apexd/ueventd/apexset/prop/apexdlibs/pctx/init.rc + leftover plat contexts ✓"
                  fi
                else
                  log "  system.img is GT + stock init/libs/apexd/ueventd/apexset/prop/apexdlibs/pctx + stock init.rc $initrc_sz ✓"
                fi
              else
                log "  system.img is GT + stock init/libs/apexd/ueventd/apexset/prop/apexdlibs + stock plat_property_contexts $pctx_sz ✓"
              fi
            else
              log "  system.img is GT + stock init/libs/apexd/ueventd/apexset/prop + stock apexd DIFF libs ✓"
            fi
          else
            log "  system.img is GT + stock init/libs/apexd/ueventd/apexset + stock build.prop $prop_sz ✓"
          fi
        else
          log "  system.img is GT + stock init/libs/apexd/ueventd + stock /system/apex ($n_apex files, virt $virt_sz) ✓"
        fi
      elif [ "$MODE" = "gtsystemonstocknovirt" ] || [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ]; then
        if ! debugfs -R "stat /system/apex/com.android.virt.apex" "$WORK/system.img" 2>&1 \
             | grep -q 'File not found'; then
          die "novirt expected com.android.virt.apex ABSENT"
        fi
        if [ "$MODE" = "gtsystemonstockbootapex" ] || [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ]; then
          local rt_sz i18n_sz tz_sz
          rt_sz="$(_dfs_size /system/apex/com.android.runtime.apex "$WORK/system.img")"
          i18n_sz="$(_dfs_size /system/apex/com.android.i18n.apex "$WORK/system.img")"
          tz_sz="$(_dfs_size /system/apex/com.android.tzdata.apex "$WORK/system.img")"
          [ "$rt_sz" = "8814592" ] || die "bootapex expected stock runtime 8814592, got $rt_sz"
          [ "$i18n_sz" = "37842944" ] || die "bootapex expected stock i18n 37842944, got $i18n_sz"
          [ "$tz_sz" = "921600" ] || die "bootapex expected stock tzdata 921600, got $tz_sz"
          if [ "$MODE" = "gtsystemonstockapexd" ] || [ "$MODE" = "gtsystemonstockueventd" ]; then
            local apexd_sz
            apexd_sz="$(_dfs_size /system/bin/apexd "$WORK/system.img")"
            [ "$apexd_sz" = "1083368" ] || die "apexd expected stock 1083368, got $apexd_sz"
            if [ "$MODE" = "gtsystemonstockueventd" ]; then
              local uev_sz
              uev_sz="$(_dfs_size /system/etc/ueventd.rc "$WORK/system.img")"
              [ "$uev_sz" = "3785" ] || die "ueventd expected stock 3785, got $uev_sz"
              debugfs -R "dump /system/etc/ueventd.rc $WORK/_ueventd.rc" \
                "$WORK/system.img" >/dev/null 2>&1 \
                || die "dump grafted ueventd.rc failed"
              grep -q '/dev/block/mapper/\*\.apex' "$WORK/_ueventd.rc" \
                || die "grafted ueventd.rc missing /dev/block/mapper/*.apex"
              rm -f "$WORK/_ueventd.rc"
              log "  system.img is GT + stock init/libs/bootapex/apexd + stock ueventd.rc $uev_sz, virt ABSENT ✓"
            else
              log "  system.img is GT + stock init/libs/bootapex + stock apexd $apexd_sz, virt ABSENT ✓"
            fi
          else
            log "  system.img is GT + stock init/libs + stock bootstrap apexes, virt ABSENT ✓"
          fi
        else
          log "  system.img is GT + stock init/libs, virt.apex ABSENT ✓"
        fi
      else
        log "  system.img is GT + stock init/bootstrap/lib64 (init $gt_init_sz, libfs_mgr $fsmgr_sz, libc++ $cxx_sz, libfec_rs $fecrs_sz) ✓"
      fi
    else
      log "  system.img is GT + stock init/bootstrap (init $gt_init_sz, linker $linker_sz, libc $libc_sz) ✓"
    fi
  else
    [ "$gt_init_sz" = "2938144" ] \
      || log "  WARN: GT system init size is $gt_init_sz (expected 2938144) — still shipping"
    log "  system.img is GT (init size $gt_init_sz) ✓"
  fi

  local sys_sz se_sz pr_sz ven_sz sdlkm_sz vdlkm_sz
  sys_sz=$(sz "$WORK/system.img"); se_sz=$(sz "$WORK/system_ext.img")
  pr_sz=$(sz "$WORK/product.img"); ven_sz=$(sz "$WORK/vendor.img")
  sdlkm_sz=$(sz "$WORK/system_dlkm.img"); vdlkm_sz=$(sz "$WORK/vendor_dlkm.img")

  local super_size=8531214336 group_size=8527020032
  log "lpmake super.img (gtsystemonstock: GT system + stock everything else)..."
  "$HOST_BIN/lpmake" \
    --metadata-size 65536 --super-name super --metadata-slots 3 \
    --device super:"$super_size" \
    --group google_dynamic_partitions:"$group_size" \
    --partition system_a:readonly:"$sys_sz":google_dynamic_partitions --image system_a="$WORK/system.img" \
    --partition system_b:readonly:0:google_dynamic_partitions \
    --partition system_ext_a:readonly:"$se_sz":google_dynamic_partitions --image system_ext_a="$WORK/system_ext.img" \
    --partition system_ext_b:readonly:0:google_dynamic_partitions \
    --partition product_a:readonly:"$pr_sz":google_dynamic_partitions --image product_a="$WORK/product.img" \
    --partition product_b:readonly:0:google_dynamic_partitions \
    --partition vendor_a:readonly:"$ven_sz":google_dynamic_partitions --image vendor_a="$WORK/vendor.img" \
    --partition vendor_b:readonly:0:google_dynamic_partitions \
    --partition system_dlkm_a:readonly:"$sdlkm_sz":google_dynamic_partitions --image system_dlkm_a="$WORK/system_dlkm.img" \
    --partition system_dlkm_b:readonly:0:google_dynamic_partitions \
    --partition vendor_dlkm_a:readonly:"$vdlkm_sz":google_dynamic_partitions --image vendor_dlkm_a="$WORK/vendor_dlkm.img" \
    --partition vendor_dlkm_b:readonly:0:google_dynamic_partitions \
    --sparse --output "$WORK/super.img" \
    || die "lpmake failed"

  log "Stage bundle -> $DEST"
  cp -f "$WORK/super.img" "$DEST/super.img"
  cp -f "$WORK/system.img" "$DEST/system.img"
  cp -f "$STOCK/system_ext.img" "$DEST/system_ext.img"
  cp -f "$STOCK/product.img" "$DEST/product.img"
  cp -f "$STOCK/vendor.img" "$DEST/vendor.img"
  cp -f "$STOCK/system_dlkm.img" "$DEST/system_dlkm.img"
  cp -f "$STOCK/vendor_dlkm.img" "$DEST/vendor_dlkm.img"
  cp -f "$STOCKCTL/bootloader.img" "$DEST/bootloader.img"
  cp -f "$STOCKCTL/radio.img" "$DEST/radio.img"
  for img in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img pvmfw.img; do
    cp -f "$boot_src/$img" "$DEST/$img"
  done
  if [ -f "$STOCK/super_empty.img" ]; then
    cp -f "$STOCK/super_empty.img" "$DEST/super_empty.img"
  elif [ -f "$STOCKCTL/super_empty.img" ]; then
    cp -f "$STOCKCTL/super_empty.img" "$DEST/super_empty.img"
  fi
  [ -f "$STOCKCTL/init.insmod.rango.cfg" ] && cp -f "$STOCKCTL/init.insmod.rango.cfg" "$DEST/init.insmod.rango.cfg"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_system.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_vendor.img"
  cp -f "$vbmeta_flags3" "$DEST/vbmeta_valid_flags3.img"
  cp -f "$pkmd" "$DEST/avb_pkmd.bin"
  cp -f "$pkmd" "$DEST/avb_pkmd_testkey.bin"

  cat > "$DEST/README-FLASH-DESKTOP.md" <<EOF
# rango INVERTED bisect — GT system.img on stock everything — $STAMP
# MODE=$MODE

**MODE=$MODE.** Starts from the avbcontrol PASS composition and
replaces system.img with GuardTalkOS (plus mode-specific grafts).

| Partition | Source |
|-----------|--------|
| system | GT OUT + factory-boot patch; selinux/initboot/initlibs add stock plat sepolicy; initboot+ add stock init/bootstrap; initlibs adds stock init NEEDED lib64 |
| system_ext / product / vendor / dlkm | Factory CP1A (stock donor, sha256-gated) |
| boot chain / bootloader / radio | Factory CP1A |
| vbmeta* | Flags:3 test-key (same as avbcontrol) |

Discriminator:
- adb → this graft set is not sufficient to break boot
- 0xfc → reached apexd-bootstrap (init/exec-127 and 0x100 cured)
- 0x7f00/KP → remaining GT /system content still exec-127
- 0x100/KP → leftover GT libs/config beyond the init NEEDED closure
- novirt + adb → GT virt.apex was the inverted 0xfc trigger
- novirt + 0xfc → virt-sole FALSIFIED on inverted; leftover GT apex/apexd/init.rc
- ueventd + 0xfc → mapper/*.apex rule FALSIFIED as inverted 0xfc sole cause
- apexset + 0xfc → leftover GT non-apex /system is sufficient for 0xfc
- prop + 0xfc → leftover GT /system/build.prop FALSIFIED as inverted 0xfc sole cause
- apexdlibs + 0xfc → leftover GT apexd NEEDED libs FALSIFIED as inverted 0xfc sole cause
- pctx + 0xfc → leftover GT plat_property_contexts FALSIFIED as inverted 0xfc sole cause
- initrc + 0xfc → leftover GT /system/etc/init/hw/init.rc FALSIFIED as inverted 0xfc sole cause
- platctx + 0xfc → leftover plat service/seapp/mac/keystore2/tee FALSIFIED as inverted 0xfc sole cause
- earlyinit + 0xfc → leftover early-init rc/bins FALSIFIED as inverted 0xfc sole cause
- protobuf + 0xfc → leftover GT libprotobuf-cpp-full FALSIFIED as inverted 0xfc sole cause
- protobuf + 0x100 → class change (cleared apexd-bootstrap; leftover libc++ next)
- libcxx + adb → leftover GT libc++ was the 0x100 trigger
- libcxx + 0x100 → leftover GT libc++ FALSIFIED as inverted 0x100 sole cause
- libcxx + 0xfc → libc++ graft re-introduced apexd-bootstrap failure
- ldandroid + adb → leftover GT ld-android was the 0xfc trigger after stock libc++
- ldandroid + 0xfc → leftover ld-android FALSIFIED as inverted 0xfc sole cause
- ldandroid + 0x100 → class change past apexd-bootstrap (like protobuf)
- ldandroid + 0x7f00 → unexpected regression; stop
- apexdetc + adb → leftover empty_erofs.img was the inverted 0xfc trigger
- apexdetc + 0xfc → leftover empty_erofs.img FALSIFIED as inverted 0xfc sole cause
- apexdetc + 0x100 → class change past apexd-bootstrap
- apexdetc + 0x7f00 → unexpected regression; stop
- taskprof + adb → leftover task_profiles.json was the inverted 0xfc trigger
- taskprof + 0xfc → leftover task_profiles.json FALSIFIED as inverted 0xfc sole cause
- taskprof + 0x100 → class change past apexd-bootstrap
- taskprof + 0x7f00 → unexpected regression; stop
- aconfig + adb → leftover /system/etc/aconfig storage was the inverted 0xfc trigger
- aconfig + 0xfc → leftover /system/etc/aconfig storage FALSIFIED as inverted 0xfc sole cause
- aconfig + 0x100 → class change past apexd-bootstrap
- aconfig + 0x7f00 → unexpected regression; stop
- acflags + adb → leftover aconfig_flags.pb was the inverted 0xfc trigger
- acflags + 0xfc → leftover aconfig_flags.pb FALSIFIED as inverted 0xfc sole cause
- acflags + 0x100 → class change past apexd-bootstrap
- acflags + 0x7f00 → unexpected regression; stop
- bflags + adb → leftover build_flags.json was the inverted 0xfc trigger
- bflags + 0xfc → leftover build_flags.json FALSIFIED as inverted 0xfc sole cause
- bflags + 0x100 → class change past apexd-bootstrap
- bflags + 0x7f00 → unexpected regression; stop

Do not point rango-latest at this bundle.

\`\`\`bash
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_BUILD_DIR=$DEST
export REMOTE_KEY_DIR=$DEST
DEVICE=rango bash scripts/flash-from-remote.sh
\`\`\`

Staged (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  write_sha256sums
  log "DONE (inverted bisect, not linked): $DEST"
}

case "$MODE" in
  gtuserspace)
    stage_gtuserspace
    link_latest_if_requested
    ;;
  stockbootstrap|stockbootapex|novirtstockapex|stockapexd|stockinit|stockapexcfg|stockhwasan|stockselinux|stockapexset|stockvendor)
    [ "$LINK_LATEST" = "1" ] && die "MODE=$MODE is a bisect stamp — refuse --link-latest (fold into MODE=gtuserspace only after on-device PASS)"
    stage_gtuserspace
    ;;
  hybrid)
    [ "$LINK_LATEST" = "1" ] && die "MODE=hybrid must not use --link-latest (on-device FAIL 0x7f00; use gtuserspace)"
    stage_hybrid
    ;;
  fullgt)
    [ "$LINK_LATEST" = "1" ] && die "MODE=fullgt must never be used with --link-latest (diagnostic only)"
    stage_fullgt
    ;;
  avbcontrol)
    [ "$LINK_LATEST" = "1" ] && die "MODE=avbcontrol must never be used with --link-latest (diagnostic only)"
    stage_avbcontrol
    ;;
  gtsystemonstock|gtsystemonstockselinux|gtsystemonstockinitboot|gtsystemonstockinitlibs|gtsystemonstocknovirt|gtsystemonstockbootapex|gtsystemonstockapexd|gtsystemonstockueventd|gtsystemonstockapexset|gtsystemonstockprop|gtsystemonstockapexdlibs|gtsystemonstockpctx|gtsystemonstockinitrc|gtsystemonstockplatctx|gtsystemonstockearlyinit|gtsystemonstockprotobuf|gtsystemonstocklibcxx|gtsystemonstockldandroid|gtsystemonstockapexdetc|gtsystemonstocktaskprof|gtsystemonstockaconfig|gtsystemonstockacflags|gtsystemonstockbflags)
    [ "$LINK_LATEST" = "1" ] && die "MODE=$MODE is a bisect stamp — refuse --link-latest"
    stage_gtsystemonstock
    ;;
  *)
    die "unknown MODE='$MODE' (expected gtuserspace|stockbootstrap|stockbootapex|novirtstockapex|stockapexd|stockinit|stockapexcfg|stockhwasan|stockselinux|stockapexset|stockvendor|gtsystemonstock|gtsystemonstockselinux|gtsystemonstockinitboot|gtsystemonstockinitlibs|gtsystemonstocknovirt|gtsystemonstockbootapex|gtsystemonstockapexd|gtsystemonstockueventd|gtsystemonstockapexset|gtsystemonstockprop|gtsystemonstockapexdlibs|gtsystemonstockpctx|gtsystemonstockinitrc|gtsystemonstockplatctx|gtsystemonstockearlyinit|gtsystemonstockprotobuf|gtsystemonstocklibcxx|gtsystemonstockldandroid|gtsystemonstockapexdetc|gtsystemonstocktaskprof|gtsystemonstockaconfig|gtsystemonstockacflags|gtsystemonstockbflags|hybrid|fullgt|avbcontrol)"
    ;;
esac

log "Bundle: $DEST"
ls -lah "$DEST" | head -40
