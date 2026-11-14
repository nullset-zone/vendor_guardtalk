#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS — remote flash script (multi-device)
# Pulls images from the build server and flashes them via fastboot.
#
# Auto-detects the plugged device (fastboot `product` or adb `ro.product.device`)
# and selects the matching desktop-flash bundle on the build host:
#   tokay    (Pixel 9)           → releases/desktop-flash/tokay-latest
#   akita    (Pixel 8a)          → releases/desktop-flash/akita-latest
#   komodo   (Pixel 9 Pro XL)    → releases/desktop-flash/komodo-latest
#   rango    (Pixel 10 Pro Fold) → releases/desktop-flash/rango-latest
#   caiman   (Pixel 9 Pro)       → releases/desktop-flash/caiman-latest
#   comet    (Pixel 9 Pro Fold)  → releases/desktop-flash/comet-latest
#   tegu     (Pixel 9a)          → releases/desktop-flash/tegu-latest
#   stallion (Pixel 10a)         → releases/desktop-flash/stallion-latest
#   shiba    (Pixel 8)           → releases/desktop-flash/shiba-latest
#   husky    (Pixel 8 Pro)       → releases/desktop-flash/husky-latest
#   frankel  (Pixel 10)          → releases/desktop-flash/frankel-latest
#   blazer   (Pixel 10 Pro)      → releases/desktop-flash/blazer-latest
#   mustang  (Pixel 10 Pro XL)   → releases/desktop-flash/mustang-latest
#   tangorpro (Pixel Tablet)     → releases/desktop-flash/tangorpro-latest
#
# T-PORT-FLASH-CLI-9DEV (P0): the 9 devices above are the DEC-PORT-GEN8910 port
# program. Every device, including tokay, uses the `<codename>-latest` convention
# (T-EXCISE-TOKAY-LATEST-REPOINT retired the legacy generic `latest` alias).
#
# T-FLASH-REMOTE-TANGORPRO: `tangorpro` is registered here as a FOURTEENTH entry
# and it is NOT part of the DEC-PORT-GEN8910 13-device matrix. It carries two
# device-specific facts that the rest of the table does not have, and both are
# handled as ABSENT rather than as an error:
#
#   1. NO RADIO HARDWARE (DEC-PORT-TANGORPRO-003). There is no `radio.img` in
#      the bundle and no `require version-baseband=` in firmware/android-info.txt
#      (vendor/guardtalk/device/tangorpro/BoardConfig-excised-late.mk §2/§3 cites
#      both). So the step-2 baseband action is SKIPPED, and neither RADIO_MODE=flash
#      nor RADIO_MODE=erase has a subject — there is no `radio` partition to write
#      or erase. script/generate-release.sh:61-63 already encodes this
#      (`[[ $DEVICE != tangorpro ]] && RADIO=$(get_radio_image baseband)`).
#      tangorpro stays in the DISABLE_UART+DISABLE_FIPS+DISABLE_DPM cleanup arm,
#      which is that same file's `elif` branch — it is NOT inferred from the SoC.
#
#   2. NO vbmeta_system.img / NO vbmeta_vendor.img in the bundle. tangorpro's
#      single `vbmeta.img` is the whole AVB chain, so those two downloads and
#      their step-7 flashes are SKIPPED (not treated as "missing bundle files").
#
# It ALSO requires the two-phase fastboot/fastbootd split (see above, and header
# below), so it takes the stock-boot-chain arm of step 4 rather than the generic
# "reuse whatever chain is installed" arm.
#
# If the phone is booted into Android (adb state=device) — or recovery —
# the script reboots it into the bootloader (fastboot) automatically.
#
# Every device except tokay: also downloads init.insmod.<device>.cfg and pushes it
# to /vendor_dlkm/etc/ after reboot (fixes boot-logo hang if vendor_dlkm
# was built without that cfg).
#
# AVB / vbmeta (all devices, critical for rango):
#   Flashes ALL vbmeta* with BOTH --disable-verity and --disable-verification.
#
# Flash order (critical for rango / Pixel 10 Pro Fold):
#   bootloader (BOTH A/B slots) + radio → GrapheneOS firmware cleanup → wipe →
#   **fastbootd + logical** → THEN GuardTalk boot/vbmeta.
#   Entering fastbootd AFTER flashing GuardTalk boot caused G-logo reboot loops
#   (userspace fastbootd never starts → system/vendor never flashed).
#   On laguna (rango|frankel|blazer|mustang), a stock factory rescue boot
#   (releases/desktop-flash/<dev>-rescue-boot/) is ALWAYS flashed before the
#   first fastbootd attempt (prior GT boot often G-logo loops). Logical is
#   flashed, then GuardTalkOS boot replaces rescue.
#   T-PORT-LAGUNA-HYBRID: the FULL GuardTalk laguna boot chain (fullgt) was
#   ABL-rejected on-device, so GT_BOOT_CHAIN=hybrid keeps the step-4 stock
#   rescue boot chain and skips the step-6 GT boot flash. Default is 'gt'
#   (unchanged) — hybrid is operator opt-in and laguna-only.
#   On tangorpro the stock chain is likewise MANDATORY, not a rescue fallback:
#   GuardTalk's tangorpro boot chain has no on-device boot proof, and fastbootd
#   is the ONLY place the six logical partitions can be written. Source of the
#   ordering (releases/desktop-flash/*/flash-tangorpro.sh:260-300, the proven
#   flasher for this device):
#     stock boot chain -> `reboot fastboot` -> is-userspace=yes
#       -> wipe-super + logical -> `reboot bootloader`
#       -> GuardTalk boot chain -> erase/flash avb_custom_key -> vbmeta
#   Reaching fastbootd AFTER a GuardTalk boot flash is the exact failure this
#   order avoids; do not reorder it.
#
# GrapheneOS flash-all parity (script/generate-release.sh +
# device/common/generate-factory-images-common.sh):
#   ALL devices: dual-slot bootloader via --slot=other dance;
#     oem uart disable; erase dpm_a + dpm_b.
#   Official order after radio: erase avb_custom_key → flash avb_custom_key
#     avb_pkmd.bin → oem uart disable → erase dpm_a/dpm_b → update OS images.
#     tangorpro has no radio step, so its AVB key follows the bootloader pass.
#   rango|mustang|blazer|frankel (laguna/muzel + rango): NO fips erase.
#   Everyone else (tokay/akita/komodo/caiman/comet/tegu/stallion/shiba/husky,
#     and tangorpro): also erase fips (Pixel 8/9/10a + Tablet family). Grouping
#     is EXACTLY script/generate-release.sh — never inferred from SoC (blazer is
#     laguna yet erases no fips; tangorpro is gs201 yet is in the same `elif`
#     branch as tokay).
#   vbmeta is flashed ONCE, after the boot chain (official `update` writes it
#   with the image set). No duplicate mid-sequence vbmeta passes.
#
# Overrides (optional):
#   DEVICE=tokay|akita|komodo|rango|caiman|comet|tegu|stallion|shiba|husky|frankel|blazer|mustang|tangorpro
#   REMOTE_BUILD_DIR=...   REMOTE_KEY_DIR=...
#   A REMOTE_BUILD_DIR that is quarantined, marked FIRST-FLASH-RISK, or listed
#   under releases/desktop-flash/.quarantine/ is refused before any download
#   or fastboot write (T-EXCISE-STAMP-REMOTE-BUILD-DIR-QUARANTINE-BYPASS).
#   An unlisted path with any 8-digit run below the registry live_date_floor
#   is refused the same way, before step 0. Overlapping starts count
#   (T-EXCISE-QUARANTINE-FLOOR-HOLE, T-EXCISE-QUARANTINE-DATE-WINDOW).
#   A character whose Unicode digit value is 0-9 counts as ASCII 0-9 in that
#   scan, including category Nd (U+FF10-U+FF19 and mathematical monospace
#   U+1D7F6-U+1D7FF) and category No superscripts and subscripts (U+00B2 is
#   digit two; U+2080 is digit zero). A character whose numeric value is an
#   integer 0-9 counts the same way, including Khmer lek attak (U+17F0 is
#   zero) and Medefaidrin digits (U+16E80 is zero). A non-integer numeric
#   value, such as vulgar fraction one half, is not a digit.
#   While that scan walks the date, categories Mn, Mc, Me, Cf, Zs, Zl, Zp,
#   Cc, Cn, Co, and Cs are ignored so a mark, a format character, a space
#   separator, a line separator, a paragraph separator, a control character,
#   an unassigned character, a private-use character, or a surrogate cannot
#   split an eight-digit window. Twelve explicit
#   characters are ignored the same way: U+1806 MONGOLIAN TODO SOFT HYPHEN,
#   U+115F HANGUL CHOSEONG FILLER, U+1160 HANGUL JUNGSEONG FILLER,
#   U+3164 HANGUL FILLER, U+FFA0 HALFWIDTH HANGUL FILLER,
#   U+2800 BRAILLE PATTERN BLANK, U+13441 EGYPTIAN HIEROGLYPH FULL BLANK,
#   U+13442 EGYPTIAN HIEROGLYPH HALF BLANK, U+13443 EGYPTIAN HIEROGLYPH
#   LOST SIGN, U+13444 EGYPTIAN HIEROGLYPH HALF LOST SIGN,
#   U+13445 EGYPTIAN HIEROGLYPH TALL LOST SIGN, and U+13446 EGYPTIAN
#   HIEROGLYPH WIDE LOST SIGN. Category Lo is not omitted in general by
#   this change. Category Cs is omitted. Category Sk is not omitted.
#   Category Pd is not omitted in general. Category So is not omitted in
#   general. A hyphen-minus stays a separator
#   (T-EXCISE-QUARANTINE-FULLWIDTH-DATE, T-EXCISE-QUARANTINE-ND-DIGITS,
#   T-EXCISE-QUARANTINE-SUPERSCRIPT-DATE, T-EXCISE-QUARANTINE-KHMER-DATE,
#   T-EXCISE-QUARANTINE-MARK-DATE, T-EXCISE-QUARANTINE-SPACING-MARK-DATE,
#   T-EXCISE-QUARANTINE-LINE-SEPARATOR-DATE,
#   T-EXCISE-QUARANTINE-TODO-HYPHEN-DATE,
#   T-EXCISE-QUARANTINE-BRAILLE-BLANK-DATE,
#   T-EXCISE-QUARANTINE-HIEROGLYPH-BLANK-DATE,
#   T-EXCISE-QUARANTINE-HALF-BLANK-DATE,
#   T-EXCISE-QUARANTINE-UNASSIGNED-DATE,
#   T-EXCISE-QUARANTINE-PRIVATE-USE-DATE,
#   T-EXCISE-QUARANTINE-SURROGATE-DATE).
#   GT_STAMP_TREE  optional override for the stamp tree that holds the registry.
#   GT_FLASH_QUARANTINE_CHECK_ONLY=1  run only that refusal, then exit (no flash).
#   GT_FLASH_PLAN_ONLY=1   T-FLASH-REMOTE-TANGORPRO. Resolve DEVICE=<codename>
#                          through the device table, print the full plan (bundle
#                          path, download set, per-step ordering, device facts),
#                          then exit 0. Contacts NO device and NO build host: no
#                          ssh, no scp, no download, no fastboot, no adb. This is
#                          a TABLE RESOLUTION, not a flash and not boot evidence;
#                          the plan prints FLASH_READY=false / BOOT_VERIFIED=false
#                          and reports separately whether the readiness reporter
#                          would admit the codename on a live run.
#   GT_FLASH_ALLOW_HISTORICAL_BISECT=1
#                          allow an unlisted REMOTE_BUILD_DIR whose 8-digit run
#                          is below live_date_floor. Default OFF. Never auto-selected.
#                          Does not bypass a named quarantine registry entry,
#                          an on-disk marker, or FIRST-FLASH-RISK.
#                          UNSAFE — a historical bisect is not a current bundle.
#   REMOTE_HOST=...        REMOTE_TREE=...
#   ALLOW_AVB_KEY_FAIL=1   continue if avb_custom_key flash fails (default: die)
#   GT_BOOT_CHAIN=gt|hybrid  boot-chain mode. Default 'gt' = today's behaviour
#                          (GuardTalk A/B boot chain flashed at step 6).
#                          'hybrid' = laguna-only: keep the step-4 stock factory
#                          rescue boot chain, SKIP the step-6 GT boot flash, keep
#                          the step-7 vbmeta pass. Never auto-selected.
#   RADIO_MODE=flash|erase  baseband-firmware step (T-EXCISE-FW-RADIO).
#                          Default 'flash' = unchanged: install the shipped
#                          radio.img into the `radio` partition (today's path).
#                          'erase' = do NOT flash radio.img; instead
#                          `fastboot erase radio` so baseband firmware is NOT
#                          installed. Never auto-selected — operator opt-in.
#   SKIP_BT_BLOCKLIST_GUARD=1
#                          bypass the fail-closed laguna vendor_dlkm BT-blocklist
#                          guard (T-EXCISE-MUSTANG-LATEST-OWNER / defect E-10).
#                          Default OFF; never auto-selected. UNSAFE — an
#                          unblocked nitrous.ko BCM4390 BT power/rfkill path can
#                          then ship. Operator-only emergency override.
#   CAPTURE_LOGS=1         opt-in post-flash debug capture (fastboot + adb).
#                          DEFAULT OFF. Unset/0 leaves the flash path unchanged.
#                          Writes a timestamped evidence dir and prints its path.
#   CAPTURE_POST_ADB_SECS=N  seconds to keep watching AFTER adb first appears so
#                          a later fallback to fastboot is recorded (default 120).
#                          Only honoured when CAPTURE_LOGS=1.
#   GT_FLASH_SERIAL=<serial>   or `--serial <serial>`
#                          PIN this run to ONE physical handset. When set, EVERY
#                          fastboot and adb command below carries `-s <serial>`,
#                          and the transport enumerations (`fastboot devices`,
#                          `adb devices`) are filtered to that serial, so the
#                          wait loops and the boot watch cannot be satisfied by
#                          a second attached phone. Fail closed BEFORE any write:
#                          a serial that is not attached, a codename that cannot
#                          be read, or a codename that is not FLASH_DEVICE all
#                          die. `--serial` wins over the environment variable.
#                          UNSET (default) = unchanged behaviour, plus a warning
#                          that nothing is pinned
#                          (T-EXCISE-FLASH-SERIAL-PINNING).
#
# Readiness gate (T-EXCISE-FLASH-BUILDOK-REFUSAL) — BEFORE any download or write
# this script asks the readiness reporter (scripts/gt-ready-devices.sh --json)
# for its VERDICT on the target stamp and obeys it: READY and READY-ACK proceed;
# BUILD-OK, PENDING, HOLD, an unrecognised verdict, and a stamp the reporter does
# not name are all REFUSED. The clause logic is NOT reimplemented here — the
# reporter's `verdict` field is the single authority.
#   GT_ALLOW_BUILD_OK=<stamp-id>
#                          the ONLY way past a BUILD-OK refusal. It must equal
#                          the EXACT stamp id (e.g. blazer-20260928-060401), so
#                          it cannot be reused for another stamp; an empty value
#                          and the boolean-looking values 1/yes/true/y/on (and
#                          0/no/false/n/off) are refused. What is overridden —
#                          stamp, verdict, reason, report — is printed loudly, and
#                          BOOT_VERIFIED stays FALSE: the override changes what
#                          this script REFUSES, never what has been proven.
#                          Intended for a signed Law 0 experiment.
#   GT_READY_REPORT=<file> consume a readiness JSON captured earlier instead of
#                          running the reporter. EXPLICIT and LOUD: the path, its
#                          sha256, and its age are logged, and the run is told it
#                          is trusting the operator's saved measurement, not a
#                          fresh one. Still fail-closed: no verdict for the stamp
#                          is a refusal.
#   GT_READY_REPORTER=<path> reporter to execute (default: gt-ready-devices.sh
#                          next to this script). Missing, unreadable, non-zero
#                          exit, or empty/garbage output => REFUSE.
#   GT_READY_CHECK_ONLY=1  run ONLY the readiness gate (requires
#                          REMOTE_BUILD_DIR or DEVICE=), print the outcome, and
#                          exit. Never contacts a device.
#                          There is deliberately NO "skip the gate" switch: a skip
#                          would have to assume READY, and that assumption is the
#                          defect this gate closes.
#   The reporter is a read-only host scan and costs ~166 s on this host; that
#   cost is logged on both sides of the scan. It runs at most ONCE per process.
#
# Post-flash debug capture (CAPTURE_LOGS=1) — opt-in, best-effort, never fatal:
#   The boot watch stops at the FIRST adb enumeration (~30s) and reports
#   "flash complete"; a later G-logo → fastboot fallback is therefore missed.
#   With CAPTURE_LOGS=1 the script keeps watching CAPTURE_POST_ADB_SECS after
#   adb first appears, snapshots BOTH transports, and records the fallback.
#   fastboot/bootloader: oem dmesg, oem bcd read {command,status,recovery,stage},
#                        getvar slot-retry-count/slot-unbootable (a+b), getvar all.
#   adb/Android:         logcat -d (full + errors-only), getprop (key + full),
#                        dumpsys activity exit-info/lastanr + service list,
#                        /sys/fs/pstore/* where reachable.
#   Every capture step is best-effort: a failure logs a warning and never die()s.
#   Evidence dir: <LOCAL_WORK_DIR>/flash-capture-<device>-<YYYYmmdd-HHMMSS>/
#
# Bisect stamps: if REMOTE_BUILD_DIR is set and REMOTE_KEY_DIR is unset,
# KEY_DIR defaults to the same BUILD_DIR (avb_pkmd.bin stays with that stamp).
# Do not assume rango-latest for keys when flashing a REMOTE_BUILD_DIR override.
#
# Mac: re-sync this script from the build host after host-side edits (scp):
#   scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/flash-from-remote.sh \
#       ~/GuardTalk-flash/flash-from-remote.sh
#   chmod +x ~/GuardTalk-flash/flash-from-remote.sh
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REMOTE_HOST="${REMOTE_HOST:-oss-c1@192.168.2.220}"
REMOTE_TREE="${REMOTE_TREE:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree}"

# Empty = auto from plugged device (or DEVICE=). Explicit env wins.
REMOTE_BUILD_DIR="${REMOTE_BUILD_DIR:-}"
REMOTE_KEY_DIR="${REMOTE_KEY_DIR:-}"
DEVICE="${DEVICE:-}"   # optional: tokay|akita|komodo|rango|caiman|comet|tegu|stallion|shiba|husky|frankel|blazer|mustang|tangorpro

LOCAL_WORK_DIR="${LOCAL_WORK_DIR:-.}"

# The real binaries. GT_FASTBOOT_BIN / GT_ADB_BIN keep the operator's FASTBOOT=
# and ADB= overrides reachable after the wrappers take over the call-site names.
GT_FASTBOOT_BIN="${FASTBOOT:-fastboot}"
GT_ADB_BIN="${ADB:-adb}"
# Every existing call site invokes "$FASTBOOT" / "$ADB". Both names are rebound to
# the pinning wrappers in Helpers, so the pin cannot be bypassed by a call site
# that forgets it. The wrapper names are deliberately NOT "fastboot"/"adb": bash
# resolves a bare command word to a FUNCTION before PATH, so a wrapper called
# `fastboot` would recurse into itself when it re-execs GT_FASTBOOT_BIN=fastboot.
# With no serial pinned the wrappers exec the real binary with the original
# argument list, so behaviour is unchanged.
FASTBOOT="gt_pinned_fastboot"
ADB="gt_pinned_adb"

# Serial pinning (T-EXCISE-FLASH-SERIAL-PINNING). Empty GT_FLASH_SERIAL = no pin
# = today's behaviour, byte for byte. Set here from the environment; a --serial
# flag overwrites it during argument parsing below.
GT_FLASH_SERIAL="${GT_FLASH_SERIAL:-}"

# Readiness gate (T-EXCISE-FLASH-BUILDOK-REFUSAL). See the header block.
# The reporter is the single authority for the target stamp's verdict; this
# script consumes its JSON `verdict` and refuses BUILD-OK / PENDING / anything
# it cannot resolve. GT_ALLOW_BUILD_OK must equal the exact stamp id.
#
# Declared-but-empty is NOT the same as unset: `GT_ALLOW_BUILD_OK=` is an
# attempt to switch the check off, and the card requires it to be REFUSED rather
# than silently ignored. `+x` is the only way to tell the two apart in bash, so
# it is captured BEFORE the ${:-} defaulting below erases the distinction.
if [[ -n "${GT_ALLOW_BUILD_OK+x}" ]]; then
    GT_ALLOW_BUILD_OK_DECLARED=1
else
    GT_ALLOW_BUILD_OK_DECLARED=0
fi
GT_ALLOW_BUILD_OK="${GT_ALLOW_BUILD_OK:-}"
GT_READY_REPORT="${GT_READY_REPORT:-}"
GT_READY_REPORTER="${GT_READY_REPORTER:-}"
GT_READY_CHECK_ONLY="${GT_READY_CHECK_ONLY:-}"
# T-FLASH-REMOTE-TANGORPRO: plan mode. Resolves the device table for DEVICE= and
# prints the plan with no device, no ssh/scp, no download, no fastboot. Never a
# flash: FLASH_READY/BOOT_VERIFIED stay false and the plan says so.
GT_FLASH_PLAN_ONLY="${GT_FLASH_PLAN_ONLY:-0}"
# Cache of the reporter's JSON + the stamp it was resolved for, so one process
# runs the ~166 s scan at most once. Empty = not run yet. GT_READY_GATED=1 means
# the gate already PASSED for this run (a refusal dies, so it is never set on a
# refusal).
GT_READY_JSON=""
GT_READY_GATED=0
# Outcome of the last gate evaluation (read by the check-only PASS line).
GT_READY_VERDICT=""
GT_READY_STAMP=""
GT_READY_CODENAME=""
# READY-ACK binding facts re-computed IN THIS PROCESS (not read from the report):
# the sha256 of the stamp's SHA256SUMS manifest and the ack artifact that was
# actually checked. Empty until gt_ready_ack_revalidate has passed.
GT_READY_ACK_SUMS_VERIFIED=""
GT_READY_ACK_ARTIFACT_VERIFIED=""
# Seconds to wait after adb reboot bootloader before giving up
FASTBOOT_WAIT_SECS="${FASTBOOT_WAIT_SECS:-60}"
# Seconds to wait for adb after final reboot (non-tokay insmod cfg push)
ADB_WAIT_SECS="${ADB_WAIT_SECS:-180}"
# Seconds to wait for fastbootd (is-userspace=yes) after reboot fastboot
FASTBOOTD_WAIT_SECS="${FASTBOOTD_WAIT_SECS:-90}"

# Opt-in post-flash debug capture. Default OFF — when 0/unset the flash path,
# logs, and exit codes are unchanged. See the header for what is captured.
CAPTURE_LOGS="${CAPTURE_LOGS:-0}"
# Seconds to keep watching after adb first appears, so a later fallback to
# fastboot is recorded (capture mode only; ignored when CAPTURE_LOGS != 1).
CAPTURE_POST_ADB_SECS="${CAPTURE_POST_ADB_SECS:-120}"
# Timestamped evidence dir, created lazily by capture_dir_init when opted in.
CAPTURE_DIR=""

# Stock factory boot chain for the laguna family (rango|frankel|blazer|mustang)
# when the GuardTalk boot cannot reach fastbootd.
REMOTE_RESCUE_DIR="${REMOTE_RESCUE_DIR:-}"  # set after tree known / device=laguna
# Local dir + image list for the downloaded rescue chain (set by download_rescue_boot).
RESCUE_LOCAL=""

# Boot-chain mode (T-PORT-LAGUNA-HYBRID). 'gt' (default) = unchanged behaviour:
# install the GuardTalk A/B boot chain at step 6. 'hybrid' = keep the stock
# factory rescue boot chain installed at step 4, SKIP the step-6 GuardTalk
# boot-chain flash, keep the step-7 vbmeta pass. Only valid for the laguna
# family, whose shipped fullgt boot chain was ABL-rejected on-device
# (B-PORT-LAGUNA-STATE §3). Never auto-selected — the operator must opt in.
GT_BOOT_CHAIN="${GT_BOOT_CHAIN:-gt}"

# Baseband firmware mode (T-EXCISE-FW-RADIO).
# 'flash' (default) = unchanged behaviour: install the shipped radio.img into
# the `radio` partition at step 2. 'erase' = do NOT flash radio.img; instead
# erase the `radio` partition so the baseband firmware is NOT installed.
# The GuardTalk userspace radio stack is excised but the factory baseband blob
# is not (A-EXCISE-RADIO E-1: shipped + flashed 13/13); this opt-in path is the
# flash-lane half of the card's "unflashed/erased" choice. Never auto-selected.
RADIO_MODE="${RADIO_MODE:-flash}"

# -----------------------------------------------------------------------------
# Images to download
# -----------------------------------------------------------------------------
FW_IMAGES=(bootloader.img radio.img)
AB_IMAGES=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img)
NOAB_IMAGES=(dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img)
LOGICAL_IMAGES=(system.img system_ext.img product.img vendor.img vendor_dlkm.img system_dlkm.img)
SUPER_IMAGE=(super.img)
EXTRA_FILES=(super_empty.img avb_pkmd.bin)
# NOTE: vendor_boot_diag.img (diagnostic: factory vendor_boot + init_fatal_panic)
# is downloaded via RANGO_EXTRA_FILES, not flashed by the script. Flash manually
# to capture init's FATAL line via "fastboot oem dmesg".
# Appended after device detect (see apply_device_extra_downloads)
AKITA_EXTRA_FILES=(init.insmod.akita.cfg)
KOMODO_EXTRA_FILES=(init.insmod.komodo.cfg)
RANGO_EXTRA_FILES=(init.insmod.rango.cfg vendor_boot_diag.img)
# T-PORT-FLASH-CLI-9DEV: the 9 DEC-PORT-GEN8910 devices each ship their own
# init.insmod.<codename>.cfg (one entry per device; no shared cfg).
CAIMAN_EXTRA_FILES=(init.insmod.caiman.cfg)
COMET_EXTRA_FILES=(init.insmod.comet.cfg)
TEGU_EXTRA_FILES=(init.insmod.tegu.cfg)
STALLION_EXTRA_FILES=(init.insmod.stallion.cfg)
SHIBA_EXTRA_FILES=(init.insmod.shiba.cfg)
HUSKY_EXTRA_FILES=(init.insmod.husky.cfg)
FRANKEL_EXTRA_FILES=(init.insmod.frankel.cfg)
BLAZER_EXTRA_FILES=(init.insmod.blazer.cfg)
MUSTANG_EXTRA_FILES=(init.insmod.mustang.cfg)
TANGORPRO_EXTRA_FILES=(init.insmod.tangorpro.cfg)
# Rescue chain image set — identical filenames for every laguna device.
RESCUE_IMGS=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img vbmeta.img pvmfw.img)

# T-FLASH-REMOTE-TANGORPRO: images that EXIST for the 13-device matrix but have
# NO SUBJECT on tangorpro. They are removed from ALL_DOWNLOADS for that codename
# only, so "absent" is a property of the device table rather than a bundle
# defect that the download/verify loops would die on:
#   radio.img          — no modem/radio HARDWARE (DEC-PORT-TANGORPRO-003); the
#                        bundle ships no radio.img and android-info.txt carries
#                        no `require version-baseband=`.
#   vbmeta_system.img  — tangorpro ships ONE vbmeta.img covering the chain; the
#   vbmeta_vendor.img    bundle has no chained vbmeta partitions.
TANGORPRO_ABSENT_IMAGES=(radio.img vbmeta_system.img vbmeta_vendor.img)

ALL_DOWNLOADS=("${FW_IMAGES[@]}" "${AB_IMAGES[@]}" "${NOAB_IMAGES[@]}" "${LOGICAL_IMAGES[@]}" "${SUPER_IMAGE[@]}" "${EXTRA_FILES[@]}")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
# Logs go to stderr so command substitutions (e.g. dest="$(download_...)")
# never capture "[flash] ..." lines into path variables.
log()  { echo "[flash] $*" >&2; }
warn() { echo "[flash] WARNING: $*" >&2; }
die()  { echo "[flash] FATAL: $*" >&2; exit 1; }
step() { echo "" >&2; echo "=== $* ===" >&2; }

# -----------------------------------------------------------------------------
# Serial pinning (T-EXCISE-FLASH-SERIAL-PINNING)
# -----------------------------------------------------------------------------
# Every fastboot and adb execution in this script goes through "$FASTBOOT" /
# "$ADB". Those two names are bound to the shell functions below, so the pin is
# enforced at ONE choke point instead of at 100+ call sites: with a serial set,
# each invocation gains `-s <serial>` before its subcommand.
#
# `devices` is the exception. It enumerates every attached transport and adb
# rejects `-s` on it, so it is filtered to the pinned serial instead. That keeps
# the wait loops (wait_for_fastboot, wait_for_fastbootd, the boot watch) from
# being satisfied by a second handset that happens to be plugged in.
gt_serial_pinned() { [[ -n "${GT_FLASH_SERIAL:-}" ]]; }

# Keep only rows whose first field is the pinned serial. An adb header row is
# preserved because callers skip NR==1 (`adb_first_transport`, the boot watch).
gt_serial_filter() {
    awk -v want="$GT_FLASH_SERIAL" '
        NR == 1 && $1 == "List" { print; next }
        $1 == want             { print }
    '
}

# True only when the pinned serial is present as a real transport row. Unlike
# gt_serial_filter this never counts the adb header, so it cannot report a
# match for an attached-nothing bus. Args: fastboot|adb
gt_serial_attached() {
    local kind="$1" out
    case "$kind" in
        fastboot) out="$("$GT_FASTBOOT_BIN" devices 2>/dev/null || true)" ;;
        adb)      out="$("$GT_ADB_BIN" devices 2>/dev/null || true)" ;;
        *)        return 1 ;;
    esac
    [[ -n "$out" ]] || return 1
    printf '%s\n' "$out" | awk -v want="$GT_FLASH_SERIAL" '
        $1 == "List" { next }
        $1 == want   { found = 1 }
        END          { exit !found }
    '
}

# Refuse a pin that cannot be a serial: leading '-' would be parsed as an option
# by fastboot/adb, and whitespace or shell metacharacters have no business in a
# serial. Runs before any device contact.
gt_serial_validate() {
    gt_serial_pinned || return 0
    [[ "$GT_FLASH_SERIAL" != -* ]] \
        || die "GT_FLASH_SERIAL='$GT_FLASH_SERIAL' starts with '-' and would be read as a fastboot/adb option. Give the bare serial from 'fastboot devices'. Nothing was flashed."
    [[ "$GT_FLASH_SERIAL" =~ ^[A-Za-z0-9._:]+$ ]] \
        || die "GT_FLASH_SERIAL='$GT_FLASH_SERIAL' is not a usable serial (expected the device serial from 'fastboot devices', e.g. 59080DLCH0022P). Nothing was flashed."
    return 0
}

# Die before any write unless the pinned serial is actually attached.
gt_pin_preflight() {
    gt_serial_pinned || return 0
    local seen=""
    if gt_serial_attached fastboot; then
        seen="fastboot"
    elif command -v "$GT_ADB_BIN" >/dev/null 2>&1 && gt_serial_attached adb; then
        seen="adb"
    fi
    [[ -n "$seen" ]] \
        || die "GT_FLASH_SERIAL='$GT_FLASH_SERIAL' is pinned but that serial is NOT attached (no match in 'fastboot devices' or 'adb devices'). Nothing was flashed, rebooted, or downloaded. Attach that handset, or unset GT_FLASH_SERIAL / drop --serial to use the un-pinned behaviour."
    log "serial pin: $GT_FLASH_SERIAL (attached via $seen) — every fastboot and adb command in this run targets ONLY this serial"
    return 0
}

# gt_pinned_fastboot / gt_pinned_adb are what "$FASTBOOT" / "$ADB" resolve to at
# every call site. The names must not shadow the real binaries: bash prefers a
# function over PATH for a bare command word, so a wrapper named `fastboot` would
# re-enter itself when it execs GT_FASTBOOT_BIN=fastboot.
gt_pinned_fastboot() {
    if ! gt_serial_pinned; then
        "$GT_FASTBOOT_BIN" "$@"
        return
    fi
    case "${1:-}" in
        # Enumerates all transports; -s is not a selector for it.
        devices)
            "$GT_FASTBOOT_BIN" devices 2>/dev/null | gt_serial_filter
            return
            ;;
        # Contact no device.
        --version|-h|--help|"")
            "$GT_FASTBOOT_BIN" "$@"
            return
            ;;
    esac
    "$GT_FASTBOOT_BIN" -s "$GT_FLASH_SERIAL" "$@"
}

gt_pinned_adb() {
    if ! gt_serial_pinned; then
        "$GT_ADB_BIN" "$@"
        return
    fi
    case "${1:-}" in
        # Enumerates all transports; adb rejects -s on this subcommand.
        devices)
            "$GT_ADB_BIN" devices 2>/dev/null | gt_serial_filter
            return
            ;;
        # Server/version commands contact no device and take no -s.
        start-server|kill-server|version|--version|-h|--help|"")
            "$GT_ADB_BIN" "$@"
            return
            ;;
    esac
    "$GT_ADB_BIN" -s "$GT_FLASH_SERIAL" "$@"
}

# -----------------------------------------------------------------------------
# Readiness gate (T-EXCISE-FLASH-BUILDOK-REFUSAL)
# -----------------------------------------------------------------------------
# The defect this closes: this script's ONLY first-flash test is the README
# regex 'FIRST-FLASH RISK.*UNRESOLVED'. blazer's live stamp carries that warning
# in prose (README lines 20, 30, 35) and matches the regex ZERO times, so a
# bundle the readiness reporter calls BUILD-OK — a bundle that has never booted
# — passed this flasher's only gate and drove fastboot. The flasher could not
# refuse what it could not name: 'BUILD-OK' appeared zero times in this file.
#
# The fix is NOT a second copy of the clause logic. scripts/gt-ready-devices.sh
# already computes the verdict from the stamp's bytes plus the host gate
# clauses plus the operator-ack tier. This gate EXECUTES that reporter and obeys
# its `verdict` field:
#     READY, READY-ACK          -> proceed
#     BUILD-OK, PENDING, HOLD   -> refuse (HOLD only ever becomes READY-ACK via
#                                  a valid stamp-bound ack, which the reporter
#                                  applies; an unacknowledged HOLD is a refusal)
#     anything else / no entry  -> refuse (never assume READY)
# The ONE way past a BUILD-OK refusal is GT_ALLOW_BUILD_OK naming that exact
# stamp (see the header). There is no blanket skip.
#
# Cost: the reporter is a read-only host scan (~166 s on the build host: it runs
# `sha256sum -c` over the whole bundle). That is acceptable for a fail-closed
# pre-flight, so it runs at most ONCE per process and both ends of the scan are
# logged. GT_READY_REPORT=<json> reuses an operator-captured report instead —
# explicit and loudly labelled, never silent.
# -----------------------------------------------------------------------------

# Repo root of THIS script (…/scripts/flash-from-remote.sh -> …). Used only to
# locate the reporter and to tell whether the local tree owns the bundles.
gt_repo_root() {
    local self_dir
    self_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return 1
    (cd -- "$self_dir/.." && pwd) || return 1
}

# Refuse a GT_ALLOW_BUILD_OK that cannot name a stamp. An empty value, a
# boolean-looking value (1/0/yes/no/true/false/y/n/on/off — the shapes an
# operator types when they mean "turn the check off"), and anything that is not
# a plain stamp id are all refused: a bypass that does not name the exact stamp
# could be carried to another stamp, which is the abuse this must prevent.
gt_ready_override_validate() {
    # Unset = no override attempted.
    [[ "${GT_ALLOW_BUILD_OK_DECLARED:-0}" == "1" ]] || return 0
    # Declared but empty: refused outright. Bash cannot distinguish this from
    # unset unless the declaration was captured above, and the card requires
    # "empty" to be refused rather than quietly treated as "no override".
    if [[ -z "${GT_ALLOW_BUILD_OK:-}" ]]; then
        die "GT_ALLOW_BUILD_OK is SET BUT EMPTY — an empty value is not a stamp id and is refused (it is the shape an operator types when they mean 'turn this check off'). The override must NAME the exact stamp it applies to (e.g. GT_ALLOW_BUILD_OK=blazer-20260928-060401), so it cannot be reused for a different stamp. Unset it entirely to run with the gate in force. Nothing was flashed."
    fi
    local want_lc
    want_lc="$(printf '%s' "$GT_ALLOW_BUILD_OK" | tr '[:upper:]' '[:lower:]')"
    case "$want_lc" in
        1|0|yes|no|true|false|y|n|on|off)
            die "GT_ALLOW_BUILD_OK='$GT_ALLOW_BUILD_OK' is not a stamp id — it is a boolean-looking value. The override must NAME the exact stamp it applies to (e.g. GT_ALLOW_BUILD_OK=blazer-20260928-060401) so it cannot be reused for a different stamp. Nothing was flashed."
            ;;
    esac
    if [[ ! "$GT_ALLOW_BUILD_OK" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        die "GT_ALLOW_BUILD_OK='$GT_ALLOW_BUILD_OK' is not a usable stamp id (expected the stamp directory name, e.g. blazer-20260928-060401). Nothing was flashed."
    fi
    return 0
}

# Load the readiness report into GT_READY_JSON. Sources, in order:
#   1. GT_READY_REPORT  — a JSON file the operator captured earlier (explicit).
#   2. the local reporter, when this host owns the release tree.
#   3. the reporter on REMOTE_HOST in REMOTE_TREE (the build host owns it when
#      this script runs on the operator's laptop).
# Every failure path REFUSES: the gate never falls back to "assume READY".
gt_ready_report_load() {
    if [[ -n "${GT_READY_JSON:-}" ]]; then
        return 0
    fi

    local root rel t0 elapsed out rc report_size report_sha report_age
    root="$(gt_repo_root)" || die "REFUSING to flash: cannot resolve this script's directory, so the readiness reporter cannot be located. Nothing was flashed."
    rel="${GT_READY_REL:-releases/desktop-flash}"

    # --- 1. operator-captured report (explicit + loud) -----------------------
    if [[ -n "${GT_READY_REPORT:-}" ]]; then
        [[ -f "$GT_READY_REPORT" && -r "$GT_READY_REPORT" ]] \
            || die "REFUSING to flash: GT_READY_REPORT='$GT_READY_REPORT' does not exist or is not readable. The readiness verdict for this stamp cannot be established, and it is never assumed READY. Nothing was flashed."
        report_size="$(wc -c < "$GT_READY_REPORT" 2>/dev/null | tr -d ' ' || echo 0)"
        [[ "${report_size:-0}" -gt 0 ]] \
            || die "REFUSING to flash: GT_READY_REPORT='$GT_READY_REPORT' is EMPTY, so it carries no verdict for any stamp. Nothing was flashed."
        # Portable digest + mtime: GNU coreutils on Linux, BSD on macOS. Both
        # are best-effort LABELLING here — neither decides the verdict — so an
        # unavailable tool prints <unreadable>/unknown rather than failing.
        report_sha="$(sha256sum -- "$GT_READY_REPORT" 2>/dev/null | cut -d' ' -f1 || true)"
        if [[ -z "$report_sha" ]]; then
            report_sha="$(shasum -a 256 -- "$GT_READY_REPORT" 2>/dev/null | cut -d' ' -f1 || true)"
        fi
        report_age="$(stat -c '%y' -- "$GT_READY_REPORT" 2>/dev/null || true)"
        if [[ -z "$report_age" ]]; then
            report_age="$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' -- "$GT_READY_REPORT" 2>/dev/null || true)"
        fi
        [[ -n "$report_age" ]] || report_age="unknown"
        warn "READINESS REPORT REUSED — NOT freshly measured. GT_READY_REPORT='$GT_READY_REPORT' (${report_size} bytes, sha256 ${report_sha:-<unreadable>}, mtime ${report_age}). This run trusts that saved measurement: the reporter was NOT re-run, so a stamp that changed since it was captured is NOT detected here. Nothing about boot is proven either way (BOOT_VERIFIED=false)."
        GT_READY_JSON="$(cat -- "$GT_READY_REPORT")" \
            || die "REFUSING to flash: GT_READY_REPORT='$GT_READY_REPORT' could not be read. Nothing was flashed."
        return 0
    fi

    # --- 2. local reporter, when this host owns the release tree ------------
    local reporter="${GT_READY_REPORTER:-$root/scripts/gt-ready-devices.sh}"
    if [[ -z "${GT_READY_REPORTER:-}" && ! -f "$reporter" ]]; then
        die "REFUSING to flash: the readiness reporter is missing at '$reporter', so the target stamp's verdict cannot be established. The verdict is NEVER assumed READY. Restore scripts/gt-ready-devices.sh, or pass GT_READY_REPORTER=<path>/GT_READY_REPORT=<json>. Nothing was flashed."
    fi
    [[ -f "$reporter" && -r "$reporter" ]] \
        || die "REFUSING to flash: the readiness reporter '$reporter' does not exist or is not readable, so the target stamp's verdict cannot be established. The verdict is NEVER assumed READY. Nothing was flashed."

    # Run it HERE only when this host is also the tree the flash will read: a
    # local reporter can only describe a local release tree. A REMOTE_TREE that
    # is not this script's repo root, or an absent local tree, means the report
    # must come from the host that owns the bundles.
    local use_remote=0
    [[ "${REMOTE_TREE%/}" == "$root" ]] || use_remote=1
    [[ -d "$root/$rel" ]] || use_remote=1

    t0="$SECONDS"
    if [[ "$use_remote" = 0 ]]; then
        log "readiness gate: running the reporter on THIS host ($reporter) over '$rel' — a read-only scan, allow ~166 s (it runs 'sha256sum -c' over the whole bundle). This cost IS the fail-closed pre-flight; there is no silent skip."
        out="$(bash "$reporter" --json 2>/dev/null)" && rc=0 || rc=$?
        elapsed=$((SECONDS - t0))
        if [[ "$rc" -ne 0 ]]; then
            die "REFUSING to flash: the readiness reporter exited $rc, so the target stamp's verdict cannot be established. A reporter that cannot run is a refusal, not a permission (never assume READY). Command: bash '$reporter' --json   [${elapsed}s]. Nothing was flashed."
        fi
        log "readiness gate: reporter finished in ${elapsed}s"
    else
        # The bundle tree is not this host's: run the reporter where it lives.
        local remote_cmd remote_env=""
        case "${REMOTE_TREE:-}" in
            ""|*"'"*|*'"'*|*'$'*|*'\'*|*$'\n'*)
                die "REFUSING to flash: the release tree '$root/$rel' is not usable here and REMOTE_TREE='${REMOTE_TREE:-}' cannot be quoted safely for the remote reporter run. Pass GT_READY_REPORT=<json captured on the build host>. Nothing was flashed."
                ;;
        esac
        case "$rel" in
            *"'"*|*'"'*|*'$'*|*'\'*|*$'\n'*)
                die "REFUSING to flash: GT_READY_REL='$rel' cannot be quoted safely for the remote reporter run. Nothing was flashed."
                ;;
        esac
        remote_env="GT_READY_REL='$rel'"
        if [[ -n "${GT_READY_ACK_DIR:-}" ]]; then
            case "$GT_READY_ACK_DIR" in
                *"'"*|*'"'*|*'$'*|*'\'*|*$'\n'*)
                    die "REFUSING to flash: GT_READY_ACK_DIR cannot be quoted safely for the remote reporter run. Nothing was flashed."
                    ;;
            esac
            remote_env="$remote_env GT_READY_ACK_DIR='$GT_READY_ACK_DIR'"
        fi
        remote_cmd="cd '$REMOTE_TREE' && $remote_env bash scripts/gt-ready-devices.sh --json"
        warn "readiness gate: the release tree '$root/$rel' is not readable here, so the reporter runs on the host that owns the bundles: $REMOTE_HOST \"$remote_cmd\" (read-only, allow ~166 s)."
        out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" "$remote_cmd" 2>/dev/null)" && rc=0 || rc=$?
        elapsed=$((SECONDS - t0))
        if [[ "$rc" -ne 0 ]]; then
            die "REFUSING to flash: the readiness reporter could not run on $REMOTE_HOST (ssh exit $rc), so the target stamp's verdict cannot be established. A reporter that cannot be reached is a refusal, not a permission (never assume READY). Command: ssh '$REMOTE_HOST' \"$remote_cmd\"   [${elapsed}s]. Nothing was flashed."
        fi
        log "readiness gate: remote reporter finished in ${elapsed}s"
    fi

    [[ -n "${out//[[:space:]]/}" ]] \
        || die "REFUSING to flash: the readiness reporter produced NO OUTPUT, so the target stamp's verdict cannot be established. Never assume READY. Nothing was flashed."
    GT_READY_JSON="$out"
    return 0
}

# Look one device row up in the report. Args: <stamp|-> <codename|->
# The report JSON arrives on stdin (never in argv: it is tens of KB).
# Prints one TSV row: verdict, codename, stamp, host_classification,
# acknowledged, reason, then the acknowledgement binding facts
# (T-EXCISE-READY-ACK-BINDING-REVALIDATE): ack_status, ack_applies, ack_stamp,
# ack_sums, ack_artifact, ack_residual, and finally ack_keys — the ack object's
# own key names, sorted, so THIS script (not the extractor) can enforce
# "exactly these fields, nothing missing, nothing extra".
# The first six columns and their order are unchanged; the ack columns are
# appended so the READY-ACK arm can re-validate the binding in this process
# instead of trusting the report's self-supplied `acknowledged` boolean.
# Exit: 0 ok, 2 unparseable JSON / no devices, 3 no row for the
# stamp/codename, 4 ambiguous (several rows).
gt_ready_lookup() {
    command -v python3 >/dev/null 2>&1 \
        || die "REFUSING to flash: python3 is required to read the readiness report and is not installed, so the target stamp's verdict cannot be established. Nothing was flashed."
    python3 -c '
import json
import sys

want_stamp = sys.argv[1] if len(sys.argv) > 1 else "-"
want_dev = sys.argv[2] if len(sys.argv) > 2 else "-"

try:
    doc = json.loads(sys.stdin.read())
except Exception:
    sys.exit(2)
if not isinstance(doc, dict):
    sys.exit(2)
devices = doc.get("devices")
if not isinstance(devices, list) or not devices:
    sys.exit(3)

def clean(value):
    # JSON booleans must survive as JSON spelling. str(True) is "True", which
    # would silently defeat any `== "true"` comparison downstream (found by case
    # N, which refused a perfectly valid READY-ACK row because of it).
    # NOTE: this block is single-quoted for the shell, so no apostrophes here.
    # US (0x1F) is the field separator below, so it is stripped here too: no
    # value may smuggle a separator and shift the columns.
    if isinstance(value, bool):
        return "true" if value else "false"
    text = "" if value is None else str(value)
    return (text.replace("\x1f", " ").replace("\t", " ")
                .replace("\r", " ").replace("\n", " "))

rows = [d for d in devices if isinstance(d, dict)]
if want_dev not in ("", "-"):
    rows = [d for d in rows if d.get("codename") == want_dev]
if want_stamp not in ("", "-"):
    rows = [d for d in rows if d.get("stamp") == want_stamp]
if not rows:
    sys.exit(3)
# A stamp must identify exactly one device row; anything else is ambiguous and
# must not be guessed. (The reporter emits one row per device.)
if len(rows) > 1:
    sys.exit(4)

row = rows[0]

# The acknowledgement object, as DATA the gate can check. It is deliberately
# emitted field-by-field rather than as embedded JSON so the shell never has to
# parse JSON, and each value is cleaned the same way as the six columns above.
ack = row.get("ack")
if isinstance(ack, dict):
    ack_keys = ",".join(sorted(clean(k) for k in ack.keys()))
else:
    # Distinguish "no ack at all" from "an ack of the wrong TYPE": both refuse,
    # but the refusal must name what was actually there.
    ack_keys = "" if ack is None else "<not-an-object>"
    ack = {}

def ackfield(name):
    return clean(ack.get(name))

# Fields are separated by US (0x1F), NOT by tab. Tab is IFS *whitespace*, so a
# tab-separated read collapses runs of empty fields and would silently SHIFT the
# ack columns whenever one of them is empty (exactly the shape of a forged row
# that carries a status but no stamp). US is a non-whitespace IFS character, so
# empty fields are preserved and a misaligned record cannot pass for an aligned
# one. Every value above has US stripped by clean().
print("\x1f".join([
    clean(row.get("verdict")),
    clean(row.get("codename")),
    clean(row.get("stamp")),
    clean(row.get("host_classification")),
    clean(row.get("acknowledged")),
    clean(row.get("reason")),
    ackfield("status"),
    ackfield("applies"),
    ackfield("stamp"),
    ackfield("sha256sums_sha256"),
    ackfield("artifact"),
    ackfield("residual"),
    ackfield("ruling_id"),
    ackfield("operator"),
    ackfield("evidence"),
    ack_keys,
]))
' "$1" "$2"
}

# Portable sha256 of one file: GNU coreutils, then BSD shasum. Empty on failure.
gt_sha256_file() {
    local f="$1" out
    out="$(sha256sum -- "$f" 2>/dev/null | cut -d' ' -f1 || true)"
    if [[ -z "$out" ]]; then
        out="$(shasum -a 256 -- "$f" 2>/dev/null | cut -d' ' -f1 || true)"
    fi
    [[ "$out" =~ ^[0-9a-f]{64}$ ]] || return 1
    printf '%s\n' "$out"
}

# sha256 of the SHA256SUMS manifest belonging to <stamp>, RECOMPUTED from the
# manifest's bytes on this run — never taken from the readiness report.
# (T-EXCISE-READY-ACK-BINDING-REVALIDATE.) Resolution: this repo's release tree,
# then REMOTE_TREE, then — when neither is readable here — the manifest is
# fetched over ssh and hashed LOCALLY from the bytes received (so the digest is
# still computed in this process, not reported by the remote). Any failure is a
# refusal upstream: the caller must fail closed.
gt_ready_stamp_manifest_sha() {
    local stamp="$1" rel root_local root cand sha tmp rc=0 path
    rel="${GT_READY_REL:-releases/desktop-flash}"

    root_local="$(gt_repo_root 2>/dev/null)" || root_local=""
    for root in "$root_local" "${REMOTE_TREE:-}"; do
        [[ -n "$root" ]] || continue
        cand="${root%/}/$rel/$stamp/SHA256SUMS"
        [[ -f "$cand" && -r "$cand" ]] || continue
        sha="$(gt_sha256_file "$cand")" || return 1
        printf '%s\n' "$sha"
        return 0
    done

    # Not readable here: the tree lives on the host that owns the bundles. The
    # manifest is CAT-ed over and hashed locally; a failed/empty fetch is a
    # refusal, never an empty-input digest.
    [[ -n "${REMOTE_HOST:-}" ]] || return 1
    path="${REMOTE_TREE:-}/$rel/$stamp/SHA256SUMS"
    case "$path" in
        ""|*"'"*|*'"'*|*'$'*|*'\'*|*$'\n'*|*'`'*)
            return 1
            ;;
    esac
    tmp="$(mktemp 2>/dev/null)" || return 1
    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" "cat '$path'" \
            >"$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 1
    fi
    if [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        return 1
    fi
    sha="$(gt_sha256_file "$tmp")" || rc=1
    rm -f "$tmp"
    [[ "$rc" -eq 0 ]] || return 1
    printf '%s\n' "$sha"
    return 0
}

# The acknowledgement keys the reporter (scripts/gt-ready-devices.sh, ack_probe)
# emits. EXACTLY this set: a key outside it, or a missing one, is a refusal —
# the report is data this gate validates, not a schema it negotiates.
GT_READY_ACK_KEYS_EXPECTED="applies,artifact,evidence,operator,residual,ruling_id,sha256sums_sha256,stamp,status"

# Re-validate, IN THIS PROCESS, the operator acknowledgement a READY-ACK row
# claims, against the row actually about to be flashed.
# Args: <stamp> <dev> <status> <applies> <ack_stamp> <ack_sums> <artifact>
#       <residual> <ruling_id> <operator> <evidence> <ack_keys>
# Dies on ANY failure. On return 0 the binding was checked here and
# GT_READY_ACK_SUMS_VERIFIED holds the digest this process recomputed.
gt_ready_ack_revalidate() {
    local stamp="$1" dev="$2" st="$3" applies="$4" ack_stamp="$5" ack_sums="$6"
    local artifact="$7" residual="$8" ruling="$9"
    local operator="${10}" evidence="${11}" keys="${12}"
    local rel want_artifact want_artifact2="" actual sums_actual

    # The row must identify itself before its ack can be compared to anything:
    # an empty stamp or codename would make the equality checks below vacuous.
    [[ -n "$stamp" ]] \
        || die "REFUSING to flash: a READY-ACK row in the readiness report carries an EMPTY stamp, so there is no stamp for its acknowledgement to bind to. Never assume READY. Nothing was flashed."
    [[ -n "$dev" ]] \
        || die "REFUSING to flash: a READY-ACK row in the readiness report carries an EMPTY codename, so the ack artifact it should match cannot be named. Never assume READY. Nothing was flashed."

    if [[ -z "$keys" ]]; then
        die "REFUSING to flash: the readiness report says stamp '$stamp' ($dev) is READY-ACK, but its row carries NO acknowledgement object at all (ack=null), so there is nothing binding the acknowledgement to this stamp. A boolean 'acknowledged' with no ack object behind it is not evidence. Never assume READY. Nothing was flashed."
    fi
    if [[ "$keys" == "<not-an-object>" ]]; then
        die "REFUSING to flash: the readiness report says stamp '$stamp' ($dev) is READY-ACK, but its row's ack field is not a JSON object, so its binding to this stamp cannot be read. Never assume READY. Nothing was flashed."
    fi
    if [[ "$keys" != "$GT_READY_ACK_KEYS_EXPECTED" ]]; then
        die "$(printf 'REFUSING to flash: the acknowledgement in the readiness report for stamp '\''%s'\'' (%s) carries the key set {%s}, which is not the expected {%s}. A missing or extra field means this is not the ack object this gate knows how to validate, so it is refused rather than half-read. Nothing was flashed.' \
            "$stamp" "$dev" "$keys" "$GT_READY_ACK_KEYS_EXPECTED")"
    fi

    [[ "$st" == "valid" ]] \
        || die "REFUSING to flash: the readiness report says stamp '$stamp' ($dev) is READY-ACK, but the acknowledgement it carries has status '${st}' — not 'valid'. An acknowledgement the reporter itself rejected cannot mark this stamp flashable. Nothing was flashed."
    case "$applies" in
        1|true) : ;;
        *) die "REFUSING to flash: the readiness report says stamp '$stamp' ($dev) is READY-ACK, but the acknowledgement reports applies='${applies}' — an ack that does not apply to this host classification grants nothing. Nothing was flashed." ;;
    esac
    [[ "$ack_stamp" == "$stamp" ]] \
        || die "REFUSING to flash: the acknowledgement in the readiness report does not bind to the stamp being flashed. The row is stamp '$stamp' ($dev) but its ack names stamp '${ack_stamp:-<empty>}'. An acknowledgement is bound to ONE stamp id: replayed or transplanted ack objects are exactly what this check exists to refuse (the report is a file an operator controls, so its own 'acknowledged' boolean proves nothing). Nothing was flashed."

    rel="${GT_READY_REL:-releases/desktop-flash}"
    want_artifact="$rel/acks/$dev.ack"
    if [[ -n "${GT_READY_ACK_DIR:-}" ]]; then
        want_artifact2="${GT_READY_ACK_DIR%/}/$dev.ack"
    fi
    if [[ "$artifact" != "$want_artifact" ]]; then
        if [[ -z "$want_artifact2" || "$artifact" != "$want_artifact2" ]]; then
            die "$(printf 'REFUSING to flash: the acknowledgement for stamp '\''%s'\'' (%s) names artifact '\''%s'\'', which is not this device'\''s ack file (expected '\''%s'\''%s). An ack that points at another device'\''s file is a transplant. Nothing was flashed.' \
                "$stamp" "$dev" "$artifact" "$want_artifact" "${want_artifact2:+ or '$want_artifact2'}")"
        fi
    fi
    [[ -n "$residual" ]] \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) carries an EMPTY residual. A READY-ACK proceeds precisely because an operator accepted a NAMED residual; an empty one names nothing, so there is nothing to have accepted. Nothing was flashed."
    [[ -n "$ruling" ]] \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) carries an EMPTY ruling_id. An acknowledgement must name the ruling under which it was taken (Law 0 leaves a record), so an anonymous one is refused. Nothing was flashed."
    [[ -n "$operator" ]] \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) carries an EMPTY operator. An acknowledgement with no named human is not an operator acknowledgement. Nothing was flashed."
    [[ -n "$evidence" ]] \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) carries EMPTY evidence. Nothing was flashed."
    [[ "$ack_sums" =~ ^[0-9a-f]{64}$ ]] \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) carries sha256sums_sha256='${ack_sums:-<empty>}', which is not a 64-character lowercase hex digest, so it cannot bind the stamp's SHA256SUMS. Nothing was flashed."

    actual="$(gt_ready_stamp_manifest_sha "$stamp")" \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) claims SHA256SUMS sha256 '$ack_sums', but that stamp's SHA256SUMS manifest could not be read here, so the claim cannot be re-computed in this process. An unverifiable binding is a refusal, not a pass (an ack is valid only for the exact bytes it was written against). Nothing was flashed."

    sums_actual="$actual"
    [[ "$sums_actual" == "$ack_sums" ]] \
        || die "REFUSING to flash: the acknowledgement for stamp '$stamp' ($dev) binds SHA256SUMS sha256 '$ack_sums', but the manifest on disk hashes to '$sums_actual' when recomputed here. The stamp's manifest changed since the acknowledgement was written, so the ack does not cover the bytes this flash would write. Nothing was flashed."

    GT_READY_ACK_SUMS_VERIFIED="$sums_actual"
    GT_READY_ACK_ARTIFACT_VERIFIED="$artifact"
    return 0
}

# The gate. Args: <codename or empty>. Dies on refusal, returns 0 on proceed.
# Sets GT_READY_GATED=1, GT_READY_VERDICT, GT_READY_STAMP, GT_READY_CODENAME.
gt_readiness_gate() {
    local codename="${1:-}"
    local want_stamp="" rc=0 row="" verdict="" row_dev="" row_stamp="" row_host=""
    local row_acked="" row_reason=""

    # Idempotent: the gate dies on refusal, so reaching here with GATED=1 means
    # an earlier invocation already PASSED for this run. The reporter's ~166 s
    # scan is therefore paid at most once per process.
    if [[ "${GT_READY_GATED:-0}" == "1" ]]; then
        return 0
    fi
    GT_READY_GATED=0

    # python3 reads the report. Checked HERE, in this shell, so a missing
    # interpreter is one clean refusal instead of an empty lookup.
    command -v python3 >/dev/null 2>&1 \
        || die "REFUSING to flash: python3 is required to read the readiness report and is not installed, so the target stamp's verdict cannot be established. The verdict is NEVER assumed READY. Nothing was flashed."

    gt_ready_override_validate
    gt_ready_report_load

    # Target stamp. An explicit REMOTE_BUILD_DIR names the stamp outright (it
    # may be a bisect stamp that is NOT <codename>-latest); otherwise the
    # reporter's own resolution for this codename is the stamp under test — the
    # pointer is resolved once, by the reporter, not re-derived here.
    if [[ -n "${REMOTE_BUILD_DIR:-}" ]]; then
        want_stamp="$(basename -- "${REMOTE_BUILD_DIR%/}")"
        if [[ "$want_stamp" == *-latest ]]; then
            # A POINTER name, not a stamp id: the reporter resolves <dev>-latest
            # itself, so ask by codename and let it name the stamp. (Keeps an
            # explicit REMOTE_BUILD_DIR=.../blazer-latest working.)
            [[ -n "$codename" ]] || codename="${want_stamp%-latest}"
            want_stamp=""
            if [[ ! "$codename" =~ ^[a-z0-9_]+$ ]]; then
                die "REFUSING to flash: REMOTE_BUILD_DIR='$REMOTE_BUILD_DIR' names no stamp id and no usable codename, so there is nothing to look a readiness verdict up for. Never assume READY. Nothing was flashed."
            fi
        fi
    fi
    if [[ -z "$want_stamp" && -z "$codename" ]]; then
        die "REFUSING to flash: neither a codename nor REMOTE_BUILD_DIR is known, so there is no stamp to look a readiness verdict up for. Never assume READY. Nothing was flashed."
    fi

    if [[ -n "$want_stamp" && -n "$codename" ]]; then
        row="$(printf '%s' "$GT_READY_JSON" | gt_ready_lookup "$want_stamp" "$codename")" || rc=$?
    elif [[ -n "$want_stamp" ]]; then
        row="$(printf '%s' "$GT_READY_JSON" | gt_ready_lookup "$want_stamp" "-")" || rc=$?
    else
        row="$(printf '%s' "$GT_READY_JSON" | gt_ready_lookup "-" "$codename")" || rc=$?
    fi

    case "$rc" in
        0) : ;;
        2) die "REFUSING to flash: the readiness report is not parseable JSON, so the target stamp's verdict cannot be established (never assume READY). Nothing was flashed." ;;
        4) die "REFUSING to flash: the readiness report carries more than one row for stamp '${want_stamp:-<codename $codename>}', so its verdict is ambiguous. Never assume READY. Nothing was flashed." ;;
        *)
            if [[ -n "$want_stamp" ]]; then
                die "REFUSING to flash: the readiness report carries NO verdict for the stamp '$want_stamp'${codename:+ (device $codename)}, so this script cannot establish that it is flashable. A stamp the reporter does not name is a refusal, never a permission. Nothing was flashed."
            fi
            die "REFUSING to flash: the readiness report carries NO verdict for device '$codename', so this script cannot establish that its stamp is flashable. Nothing was flashed."
            ;;
    esac

    IFS=$'\x1f' read -r verdict row_dev row_stamp row_host row_acked row_reason \
        row_ack_status row_ack_applies row_ack_stamp row_ack_sums row_ack_artifact \
        row_ack_residual row_ack_ruling row_ack_operator row_ack_evidence \
        row_ack_keys <<<"$row"

    GT_READY_VERDICT="$verdict"
    GT_READY_STAMP="$row_stamp"
    GT_READY_CODENAME="$row_dev"

    case "$verdict" in
        READY)
            log "readiness gate: PASS — stamp '$row_stamp' ($row_dev) verdict READY (stamp-conferred). This is NOT boot evidence: BOOT_VERIFIED=false."
            ;;
        READY-ACK)
            # A READY-ACK row that does not itself report the acknowledgement as
            # applied is self-contradictory; refuse rather than take the more
            # permissive half of the pair.
            [[ "$row_acked" == "true" ]] \
                || die "REFUSING to flash: the readiness report says stamp '$row_stamp' ($row_dev) is READY-ACK but also reports acknowledged='$row_acked'. That combination is self-contradictory, and a READY-ACK with no applied acknowledgement is just HOLD. Never assume READY. Nothing was flashed."
            # 'acknowledged' is a boolean the report supplies about itself, so it
            # is NOT evidence (T-EXCISE-READY-ACK-BINDING-REVALIDATE). Re-check the
            # acknowledgement's BINDING here, against the row about to be flashed:
            # ack.status/applies, ack.stamp == this stamp, the ack file is this
            # device's, and the SHA256SUMS digest is recomputed from the manifest.
            gt_ready_ack_revalidate "$row_stamp" "$row_dev" \
                "$row_ack_status" "$row_ack_applies" "$row_ack_stamp" "$row_ack_sums" \
                "$row_ack_artifact" "$row_ack_residual" "$row_ack_ruling" \
                "$row_ack_operator" "$row_ack_evidence" "$row_ack_keys"
            log "readiness gate: PASS — stamp '$row_stamp' ($row_dev) verdict READY-ACK: host clauses pass, readiness is NOT stamp-conferred, and this process re-verified the operator acknowledgement's binding (status=valid, applies to this host classification, ack names THIS stamp, ack artifact is this device's ack file, and the stamp's SHA256SUMS sha256 was RECOMPUTED here as $GT_READY_ACK_SUMS_VERIFIED). The accepted residual was deliberately taken by that acknowledgement; it is NOT boot evidence: BOOT_VERIFIED=false."
            ;;
        BUILD-OK)
            gt_readiness_refuse_build_ok "$row_stamp" "$row_dev" "$row_reason"
            ;;
        PENDING)
            die "$(printf 'REFUSING to flash: stamp '\''%s'\'' (%s) is PENDING — a host gate clause FAILED (bundle incomplete, tampered, not radio-excised, or no release pointer). Reason: %s. A PENDING bundle is never a flash target. Nothing was flashed.' \
                "$row_stamp" "$row_dev" "$row_reason")"
            ;;
        HOLD)
            die "$(printf 'REFUSING to flash: stamp '\''%s'\'' (%s) is HOLD — host clauses pass but readiness is NOT-STAMP-VERIFIED and no valid, stamp-bound operator acknowledgement accepts that residual. Reason: %s. Either add a per-stamp boot artifact or record an explicit acknowledgement for THIS exact device + stamp + SHA256SUMS digest in releases/desktop-flash/acks/. Nothing was flashed.' \
                "$row_stamp" "$row_dev" "$row_reason")"
            ;;
        "")
            die "REFUSING to flash: the readiness report returned an EMPTY verdict for stamp '$row_stamp' ($row_dev). An empty verdict is not READY and is never treated as one. Nothing was flashed."
            ;;
        *)
            die "$(printf 'REFUSING to flash: the readiness report returned the UNRECOGNISED verdict '\''%s'\'' for stamp '\''%s'\'' (%s). This script refuses any verdict it does not positively understand (never assume READY). Reason: %s. Nothing was flashed.' \
                "$verdict" "$row_stamp" "$row_dev" "$row_reason")"
            ;;
    esac

    GT_READY_GATED=1
    return 0
}

# BUILD-OK refusal, with the ONE sanctioned way past it. Deliberately narrow:
# the override covers BUILD-OK only. PENDING (a failed host gate) and HOLD (no
# acknowledgement) stay refused — they are different facts, and a Law 0
# experiment over a never-booted build does not make a broken bundle whole.
gt_readiness_refuse_build_ok() {
    local stamp="$1" dev="$2" reason="$3"

    if [[ -n "${GT_ALLOW_BUILD_OK:-}" && "${GT_ALLOW_BUILD_OK}" == "$stamp" ]]; then
        warn "============================================================================="
        warn "BUILD-OK OVERRIDE — LAW 0 EXPERIMENT — PROCEEDING WITHOUT STAMP READINESS"
        warn "============================================================================="
        warn "  override variable : GT_ALLOW_BUILD_OK=$GT_ALLOW_BUILD_OK"
        warn "  stamp being forced : $stamp"
        warn "  device             : $dev"
        warn "  verdict being overridden : BUILD-OK (the build is NOT boot-verified; it has never booted on this platform)"
        warn "  reporter reason    : $reason"
        warn "  binding            : this override names '$stamp' ONLY and is inert for every other stamp"
        warn "  BOOT_VERIFIED      : FALSE — the override changes what this script REFUSES,"
        warn "                       never what has been PROVEN. Nothing here is boot evidence."
        warn "  FLASH_READY        : NOT negated by this run. A flash is not a boot."
        warn "============================================================================="
        log "readiness gate: OVERRIDDEN for stamp '$stamp' by GT_ALLOW_BUILD_OK (BUILD-OK). BOOT_VERIFIED=false."
        return 0
    fi

    if [[ -n "${GT_ALLOW_BUILD_OK:-}" ]]; then
        die "$(printf 'REFUSING to flash: stamp '\''%s'\'' (%s) is BUILD-OK — the build is intact on the host but is NOT boot-verified: %s. GT_ALLOW_BUILD_OK='\''%s'\'' was set but names a DIFFERENT stamp, so it does not apply here: the override is stamp-SPECIFIC and cannot be carried to another stamp. To force THIS stamp under a signed Law 0 experiment, set GT_ALLOW_BUILD_OK=%s exactly (BOOT_VERIFIED stays false). Nothing was flashed.' \
            "$stamp" "$dev" "$reason" "$GT_ALLOW_BUILD_OK" "$stamp")"
    fi

    die "$(printf 'REFUSING to flash: stamp '\''%s'\'' (%s) is BUILD-OK — not a flash target. %s. This script used to accept it: its only first-flash test was the README regex '\''FIRST-FLASH RISK.*UNRESOLVED'\'', which a stamp carrying that warning in prose does not match. The readiness reporter resolves the stamp from its bytes and calls it BUILD-OK; this script now obeys that verdict. Remedy: resolve the FIRST-FLASH RISK block for '%s', or run a signed Law 0 experiment with GT_ALLOW_BUILD_OK=%s (stamp-specific; BOOT_VERIFIED stays false). Nothing was flashed.' \
        "$stamp" "$dev" "$reason" "$stamp" "$stamp")"
}

# laguna platform family (Pixel 10 generation). Single source of truth for the
# hybrid boot-chain gate and the recovery-harvest default.
is_laguna_device() {
    case "${1:-}" in
        rango|frankel|blazer|mustang) return 0 ;;
        *) return 1 ;;
    esac
}

# tangorpro device facts (T-FLASH-REMOTE-TANGORPRO). Centralised so the branches
# below read from ONE definition instead of repeating the codename.
#
# has_radio_hardware: does this device have a `radio` partition / baseband image?
#   FALSE for tangorpro (DEC-PORT-TANGORPRO-003: no modem hardware, no radio.img,
#   no `require version-baseband=`). Every other device in the table is TRUE, so
#   the answer is expressed as an ABSENCE list rather than a presence list — a
#   newly registered device keeps today's behaviour unless it is named here.
has_radio_hardware() {
    case "${1:-}" in
        tangorpro) return 1 ;;
        *)         return 0 ;;
    esac
}

# is_tangorpro: needs the mandatory stock-boot/fastbootd two-phase split.
is_tangorpro() {
    [[ "${1:-}" == "tangorpro" ]]
}

# grapheneos.org/install/cli: fastboot must be at least 35.0.1
require_fastboot_min_version() {
    local ver_line major=0 minor=0 patch=0 packed required_packed
    ver_line="$("$FASTBOOT" --version 2>&1 | head -1 || true)"
    log "fastboot: $ver_line"
    if [[ "$ver_line" =~ ([0-9]+)\.([0-9]+)(\.([0-9]+))? ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[4]:-0}"
    else
        die "could not parse fastboot version from '$ver_line' (need ≥ 35.0.1; grapheneos.org/install/cli)"
    fi
    packed=$((10#$major * 10000 + 10#$minor * 100 + 10#$patch))
    required_packed=$((35 * 10000 + 0 * 100 + 1))
    if (( packed < required_packed )); then
        die "fastboot ${major}.${minor}.${patch} is older than 35.0.1 (grapheneos.org/install/cli). Upgrade Android platform-tools."
    fi
}

# Flash vbmeta* with both disable flags. Args: <part> <image> [extra fastboot args...]
# Do not use an empty bash array here: macOS bash 3.2 + `set -u` dies on
# "${extra[@]}" (unbound variable) when vbmeta_system/vbmeta_vendor have no
# extra args. GrapheneOS flash-all uses `fastboot update` (no arrays / no -u).
flash_vbmeta_img() {
    local part="$1"
    local img="$2"
    shift 2
    log "  flash $part (--disable-verity --disable-verification${*:+ $*}) ← $(basename "$img")"
    if [[ $# -gt 0 ]]; then
        "$FASTBOOT" --disable-verity --disable-verification "$@" \
            flash "$part" "$img" \
            || die "failed to flash $part with --disable-verity --disable-verification"
    else
        "$FASTBOOT" --disable-verity --disable-verification \
            flash "$part" "$img" \
            || die "failed to flash $part with --disable-verity --disable-verification"
    fi
}

# Convenience: flash from LOCAL_WORK_DIR/vbmeta*.img.
# Maps partition name to the correct image file.
flash_vbmeta_partition() {
    local part="$1"
    shift
    local img="$LOCAL_WORK_DIR/vbmeta.img"
    case "$part" in
        vbmeta_system) img="$LOCAL_WORK_DIR/vbmeta_system.img" ;;
        vbmeta_vendor) img="$LOCAL_WORK_DIR/vbmeta_vendor.img" ;;
    esac
    flash_vbmeta_img "$part" "$img" "$@"
}

# Normalize fastboot/adb product string → GuardTalk flash codename.
# Accepts exact codenames and common variant strings returned by fastboot/adb.
# T-PORT-FLASH-CLI-9DEV: all 13 DEC-PORT-GEN8910 codenames are known here.
normalize_device() {
    local raw="${1:-}"
    raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '\r')"
    # Strip leading/trailing whitespace
    raw="$(echo "$raw" | xargs)"
    case "$raw" in
        # --- Pixel 8 family ---
        shiba)   echo "shiba" ;;      # Pixel 8
        husky)   echo "husky" ;;      # Pixel 8 Pro
        akita)   echo "akita" ;;      # Pixel 8a
        # --- Pixel 9 family ---
        tokay)   echo "tokay" ;;      # Pixel 9
        caiman)  echo "caiman" ;;     # Pixel 9 Pro
        komodo)  echo "komodo" ;;     # Pixel 9 Pro XL
        tegu)    echo "tegu" ;;       # Pixel 9a
        comet)   echo "comet" ;;      # Pixel 9 Pro Fold
        # --- Pixel 10 family ---
        frankel) echo "frankel" ;;    # Pixel 10
        blazer)  echo "blazer" ;;     # Pixel 10 Pro
        mustang) echo "mustang" ;;    # Pixel 10 Pro XL
        stallion) echo "stallion" ;;  # Pixel 10a
        rango)   echo "rango" ;;      # Pixel 10 Pro Fold
        # --- Pixel Tablet (T-FLASH-REMOTE-TANGORPRO) ---
        tangorpro) echo "tangorpro" ;; # Pixel Tablet
        # Fallback: match on substring for robustness (model-name variants).
        # No codename is a substring of another, so arm order is not significant.
        *)
            case "$raw" in
                *shiba*)   echo "shiba" ;;
                *husky*)   echo "husky" ;;
                *akita*)   echo "akita" ;;
                *tokay*)   echo "tokay" ;;
                *caiman*)  echo "caiman" ;;
                *komodo*)  echo "komodo" ;;
                *tegu*)    echo "tegu" ;;
                *comet*)   echo "comet" ;;
                *frankel*) echo "frankel" ;;
                *blazer*)  echo "blazer" ;;
                *mustang*) echo "mustang" ;;
                *stallion*) echo "stallion" ;;
                *rango*)   echo "rango" ;;
                *tangorpro*) echo "tangorpro" ;;
                *)         echo "" ;;
            esac
            ;;
    esac
}

device_pretty() {
    case "$1" in
        shiba)   echo "Pixel 8 (shiba)" ;;
        husky)   echo "Pixel 8 Pro (husky)" ;;
        akita)   echo "Pixel 8a (akita)" ;;
        tokay)   echo "Pixel 9 (tokay)" ;;
        caiman)  echo "Pixel 9 Pro (caiman)" ;;
        komodo)  echo "Pixel 9 Pro XL (komodo)" ;;
        tegu)    echo "Pixel 9a (tegu)" ;;
        comet)   echo "Pixel 9 Pro Fold (comet)" ;;
        frankel) echo "Pixel 10 (frankel)" ;;
        blazer)  echo "Pixel 10 Pro (blazer)" ;;
        mustang) echo "Pixel 10 Pro XL (mustang)" ;;
        stallion) echo "Pixel 10a (stallion)" ;;
        rango)   echo "Pixel 10 Pro Fold (rango)" ;;
        tangorpro) echo "Pixel Tablet (tangorpro)" ;;
        *) echo "$1" ;;
    esac
}

# -----------------------------------------------------------------------------
# Quarantine gate — explicit REMOTE_BUILD_DIR must fail closed
# -----------------------------------------------------------------------------
# T-EXCISE-STAMP-REMOTE-BUILD-DIR-QUARANTINE-BYPASS. The stamp resolver already
# refuses a quarantined / FIRST-FLASH-RISK bundle, but an explicit
# REMOTE_BUILD_DIR never consulted that registry. This gate reads
# releases/desktop-flash/.quarantine/registry.json (and the on-disk markers)
# and dies before ssh, scp, or fastboot. A path that is not listed, not marked,
# and not under .quarantine/ is allowed when it has no 8 consecutive digits,
# or when every 8-digit run is at or above the registry live_date_floor, so
# the override is not disabled wholesale.
# T-EXCISE-QUARANTINE-FLOOR-HOLE / T-EXCISE-QUARANTINE-DATE-WINDOW: every
# 8-digit run in a path component is compared, including overlapping starts.
# One run below live_date_floor refuses the path before step 0. The floor is
# the registry value, applied even when the path is not a registry hit. A
# historical bisect requires GT_FLASH_ALLOW_HISTORICAL_BISECT=1 (default off).
# T-EXCISE-QUARANTINE-FULLWIDTH-DATE / T-EXCISE-QUARANTINE-ND-DIGITS /
# T-EXCISE-QUARANTINE-SUPERSCRIPT-DATE / T-EXCISE-QUARANTINE-KHMER-DATE:
# before that walk, every character whose Unicode digit value is 0-9, and
# every character whose numeric value is an integer 0-9, is folded to ASCII.
# That includes category No superscripts and subscripts, Khmer lek attak, and
# Medefaidrin digits. A non-integer numeric value is not a digit, so a vulgar
# fraction stays in the leaf. A fullwidth, mathematical-monospace, superscript,
# subscript, Khmer, or Medefaidrin below-floor run dies the same way.
# T-EXCISE-QUARANTINE-MARK-DATE / T-EXCISE-QUARANTINE-SPACING-MARK-DATE /
# T-EXCISE-QUARANTINE-LINE-SEPARATOR-DATE /
# T-EXCISE-QUARANTINE-TODO-HYPHEN-DATE /
# T-EXCISE-QUARANTINE-BRAILLE-BLANK-DATE /
# T-EXCISE-QUARANTINE-HIEROGLYPH-BLANK-DATE /
# T-EXCISE-QUARANTINE-HALF-BLANK-DATE /
# T-EXCISE-QUARANTINE-UNASSIGNED-DATE /
# T-EXCISE-QUARANTINE-PRIVATE-USE-DATE /
# T-EXCISE-QUARANTINE-SURROGATE-DATE:
# categories Mn, Mc, Me, Cf, Zs, Zl, Zp, Cc, Cn, Co, and Cs are omitted on
# that walk, so a mark, a format character, a space separator, a line
# separator, a paragraph separator, a control character, an unassigned
# character, a private-use character, or a surrogate cannot split an
# eight-digit window. U+1806, U+115F,
# U+1160, U+3164, U+FFA0, U+2800, and U+13441 are omitted too, and so are
# U+13442 EGYPTIAN HIEROGLYPH HALF BLANK, U+13443 EGYPTIAN HIEROGLYPH LOST
# SIGN, U+13444 EGYPTIAN HIEROGLYPH HALF LOST SIGN, U+13445 EGYPTIAN
# HIEROGLYPH TALL LOST SIGN, and U+13446 EGYPTIAN HIEROGLYPH WIDE LOST SIGN.
# Category Lo is not omitted in general by this change. Category Cs is
# omitted. Category Sk is not omitted. Category Pd is not omitted in
# general. Category So is not omitted in general. A hyphen-minus stays a
# separator.
# Named registry stamps still die. The floor is also cited when a matched
# entry is below it.
# Locate order: GT_STAMP_TREE, REMOTE_TREE, then walk up from this script.
# No ssh. If the registry cannot be read, refuse (cannot prove the path is safe).

_gt_locate_quarantine_registry() {
    local candidate stamp_tree dir i
    if [[ -n "${GT_STAMP_TREE:-}" ]]; then
        stamp_tree="${GT_STAMP_TREE%/}"
        for candidate in \
            "$stamp_tree/.quarantine/registry.json" \
            "$stamp_tree/releases/desktop-flash/.quarantine/registry.json"
        do
            if [[ -f "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
        echo "[flash] GT_STAMP_TREE has no quarantine registry: $stamp_tree" >&2
        return 1
    fi
    if [[ -n "${REMOTE_TREE:-}" ]]; then
        candidate="${REMOTE_TREE%/}/releases/desktop-flash/.quarantine/registry.json"
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for i in 1 2 3 4 5 6 7 8; do
        candidate="$dir/releases/desktop-flash/.quarantine/registry.json"
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        [[ "$dir" == "/" ]] && break
        dir="$(cd "$(dirname "$dir")" && pwd)"
    done
    return 1
}

# Print one US-separated record if any path component is in registry.json.
# kind, entry, class, reason, marker_rel, floor. Empty stdout = no JSON match.
# Exit 2 = registry unreadable (caller must fail closed).
_gt_registry_match() {
    python3 - "$1" "$2" <<'PY'
import json, sys
reg_path, path = sys.argv[1], sys.argv[2]
US = "\x1f"
try:
    with open(reg_path, encoding="utf-8") as fh:
        reg = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    sys.stderr.write("registry unreadable: %s\n" % exc)
    sys.exit(2)
floor = str(reg.get("live_date_floor") or "")
stamps = {}
for row in reg.get("quarantined_stamps") or []:
    name = row.get("stamp")
    if name:
        stamps[name] = row
pointers = [row for row in (reg.get("quarantined_pointers") or []) if row.get("pointer")]

def candidates(part):
    out = [part]
    suffix = ".quarantined"
    if part.endswith(suffix):
        out.append(part[: -len(suffix)])
    token = ".quarantined-"
    if token in part:
        out.append(part.split(token, 1)[0])
    seen = set()
    uniq = []
    for item in out:
        if item and item not in seen:
            seen.add(item)
            uniq.append(item)
    return uniq

def emit(kind, entry, cls, reason, marker):
    dated = ""
    digits = ""
    for ch in entry:
        if ch.isdigit():
            digits += ch
            if len(digits) == 8:
                break
        else:
            if len(digits) != 8:
                digits = ""
    if len(digits) == 8 and floor.isdigit() and int(digits) < int(floor):
        dated = " (dated %s, below live_date_floor %s)" % (digits, floor)
    sys.stdout.write(US.join([
        kind, entry, cls or "", (reason or "") + dated, marker or "", floor,
    ]) + "\n")
    sys.exit(0)

parts = [part for part in path.split("/") if part]
for part in reversed(parts):
    for cand in candidates(part):
        stamp = stamps.get(cand)
        if stamp:
            emit(
                "stamp",
                stamp.get("stamp", cand),
                stamp.get("class", ""),
                stamp.get("reason", ""),
                "stamps/%s.quarantined" % stamp.get("stamp", cand),
            )
        for ptr in pointers:
            name = ptr.get("pointer") or ""
            target = ptr.get("original_target") or ""
            if cand == name or (target and cand == target):
                emit(
                    "pointer",
                    name,
                    ptr.get("class", ""),
                    ptr.get("reason", ""),
                    "pointers/%s.quarantined" % name,
                )
sys.exit(0)
PY
}

# Print the registry live_date_floor. Exit 2 if it is missing or not YYYYMMDD.
# A dated path cannot be proven current without that value.
_gt_registry_live_date_floor() {
    python3 - "$1" <<'PY'
import json, sys
reg_path = sys.argv[1]
try:
    with open(reg_path, encoding="utf-8") as fh:
        reg = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    sys.stderr.write("registry unreadable: %s\n" % exc)
    sys.exit(2)
floor = str(reg.get("live_date_floor") or "")
if len(floor) != 8 or not floor.isdigit():
    sys.stderr.write("live_date_floor missing or not YYYYMMDD\n")
    sys.exit(2)
sys.stdout.write(floor + "\n")
PY
}

# Month 01-12 and day 01-31. This only chooses which below-floor run the
# fatal line names. Every 8-digit window is still compared.
_gt_yyyymmdd_plausible() {
    [[ "$1" =~ ^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$ ]]
}

# Map every character whose Unicode digit value is 0-9, and every character
# whose numeric value is an integer 0-9, onto ASCII 0-9. That includes
# category Nd (U+FF10-U+FF19, mathematical monospace U+1D7F6-U+1D7FF),
# category No superscripts and subscripts, Khmer lek attak (U+17F0 is zero),
# and Medefaidrin digits (U+16E80 is zero). unicodedata.digit is tried first.
# unicodedata.numeric is used only when digit() has no value and the numeric
# value is an integer 0-9. A non-integer, such as vulgar fraction one half
# (U+00BD, numeric 1/2), stays a non-digit. An integer outside 0-9 stays
# unchanged, so a value such as ten is not split into two digits. LC_ALL=C
# counts bytes, so the overlapping walk must see one byte per digit.
# Characters with neither value are left unchanged, except category Nd, which
# dies (it cannot be proven), and categories Mn, Mc, Me, Cf, Zs, Zl, Zp, Cc,
# Cn, Co, and Cs, which are omitted so they cannot split an eight-digit
# window.
# U+1806, U+115F, U+1160, U+3164, U+FFA0, U+2800, and U+13441 are omitted the
# same way, and so are U+13442 EGYPTIAN HIEROGLYPH HALF BLANK, U+13443
# EGYPTIAN HIEROGLYPH LOST SIGN, U+13444 EGYPTIAN HIEROGLYPH HALF LOST SIGN,
# U+13445 EGYPTIAN HIEROGLYPH TALL LOST SIGN, and U+13446 EGYPTIAN
# HIEROGLYPH WIDE LOST SIGN. Category Lo is not omitted in general by this
# change. Category Cs is omitted. Category Sk is not omitted. Category Pd
# is not omitted in general. Category So is not omitted in general. A
# hyphen-minus is U+002D and stays.
# The bytes are passed through the environment so a C locale cannot decode
# the leaf as ASCII and skip the fold.
_gt_fold_digit_values() {
    GT_FOLD_PART="$1" python3 - <<'PY'
import os, sys, unicodedata
raw = os.environb[b"GT_FOLD_PART"]
text = raw.decode("utf-8", "surrogateescape")
out = []
for ch in text:
    value = None
    try:
        value = unicodedata.digit(ch)
    except (TypeError, ValueError):
        value = None
    if value is None:
        try:
            num = unicodedata.numeric(ch)
        except (TypeError, ValueError):
            num = None
        if type(num) is int or (type(num) is float and num.is_integer()):
            ivalue = int(num)
            if 0 <= ivalue <= 9:
                value = ivalue
    if value is None:
        cat = unicodedata.category(ch)
        if cat == "Nd":
            sys.stderr.write("Nd character has no digit value\n")
            sys.exit(2)
        # Mn, Mc, and Me (marks), Cf (format), Zs (space separator),
        # Zl (line separator), Zp (paragraph separator), Cc (control),
        # Cn (unassigned), Co (private use), and Cs (surrogate) must not
        # split an 8-digit window. U+1806, U+115F, U+1160, U+3164, U+FFA0,
        # U+2800, and U+13441 are omitted too, and so are U+13442 EGYPTIAN
        # HIEROGLYPH HALF BLANK, U+13443 EGYPTIAN HIEROGLYPH LOST SIGN,
        # U+13444 EGYPTIAN HIEROGLYPH HALF LOST SIGN, U+13445 EGYPTIAN
        # HIEROGLYPH TALL LOST SIGN, and U+13446 EGYPTIAN HIEROGLYPH WIDE
        # LOST SIGN. Category Lo is not omitted in general by this change.
        # Category Cs is omitted. Category Sk is not omitted. Category Pd
        # stays in general. Category So is not omitted in general.
        # Hyphen-minus (U+002D) is kept. Category Cs is in this tuple.
        # Category Sk is not in this tuple.
        if cat in ("Mn", "Cf", "Mc", "Me", "Zs", "Zl", "Zp", "Cc", "Cn", "Co", "Cs"):
            continue
        if ord(ch) in (0x1806, 0x115F, 0x1160, 0x3164, 0xFFA0, 0x2800, 0x13441, 0x13442, 0x13443, 0x13444, 0x13445, 0x13446):
            continue
        out.append(ch)
        continue
    if type(value) is int and 0 <= value <= 9:
        out.append(chr(48 + value))
        continue
    sys.stderr.write("digit value out of range\n")
    sys.exit(2)
sys.stdout.buffer.write("".join(out).encode("utf-8", "surrogateescape"))
PY
}

# Refuse an unlisted path component when any 8-digit run is below the floor,
# including overlapping starts. Call only after registry and marker checks: a
# named stamp must already have died, and this opt-in must not resurrect it.
# No 8 consecutive digits means a non-stamp path, which stays allowed.
# Equal to the floor is allowed. The fatal line names the first plausible
# YYYYMMDD below the floor when one exists, otherwise the first below-floor run.
# The cited date is ASCII. Characters with a digit value 0-9, and characters
# whose numeric value is an integer 0-9, are folded before the walk.
# Categories Mn, Mc, Me, Cf, Zs, Zl, Zp, Cc, Cn, Co, and Cs are omitted on
# that walk.
# U+1806, U+115F, U+1160, U+3164, U+FFA0, U+2800, and U+13441 are omitted
# too, and so are U+13442 EGYPTIAN HIEROGLYPH HALF BLANK, U+13443 EGYPTIAN
# HIEROGLYPH LOST SIGN, U+13444 EGYPTIAN HIEROGLYPH HALF LOST SIGN,
# U+13445 EGYPTIAN HIEROGLYPH TALL LOST SIGN, and U+13446 EGYPTIAN
# HIEROGLYPH WIDE LOST SIGN. Category Lo is not omitted in general by this
# change. Category Cs is omitted. Category Sk is not omitted. Category Pd
# is not omitted in general. Category So is not omitted in general. A
# hyphen-minus is kept.
_gt_refuse_unlisted_below_floor() {
    local path="$1"
    local registry="$2"
    local probe part folded dt floor="" i len window below="" named=""

    probe="${path%/}"
    while [[ -n "$probe" && "$probe" != "/" ]]; do
        part="$(basename "$probe")"
        folded="$(_gt_fold_digit_values "$part")" || die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: path component '\''%s'\'' could not be folded to ASCII digits, so it cannot be proven at or above the floor. Path: %s' \
            "$part" "$path")"
        len=${#folded}
        below=""
        named=""
        i=0
        while (( i + 8 <= len )); do
            window="${folded:i:8}"
            if [[ "$window" =~ ^[0-9]{8}$ ]]; then
                if [[ -z "$floor" ]]; then
                    floor="$(_gt_registry_live_date_floor "$registry")" || die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: quarantine registry '\''%s'\'' has no YYYYMMDD live_date_floor, so '\''%s'\'' cannot be proven at or above the floor. Path: %s' \
                        "$registry" "$part" "$path")"
                    [[ "$floor" =~ ^[0-9]{8}$ ]] || die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: quarantine registry '\''%s'\'' has no YYYYMMDD live_date_floor, so '\''%s'\'' cannot be proven at or above the floor. Path: %s' \
                        "$registry" "$part" "$path")"
                fi
                if [[ "10#$window" -lt "10#$floor" ]]; then
                    if [[ -z "$below" ]]; then
                        below="$window"
                    fi
                    if [[ -z "$named" ]] && _gt_yyyymmdd_plausible "$window"; then
                        named="$window"
                    fi
                fi
            fi
            i=$((i + 1))
        done
        if [[ -n "$below" ]]; then
            dt="$below"
            if [[ -n "$named" ]]; then
                dt="$named"
            fi
            if [[ "${GT_FLASH_ALLOW_HISTORICAL_BISECT:-}" == "1" ]]; then
                warn "GT_FLASH_ALLOW_HISTORICAL_BISECT=1 — allowing unlisted stamp '$part' dated $dt below live_date_floor $floor (UNSAFE: historical bisect is not a current bundle). Path: $path"
                return 0
            fi
            die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: unlisted stamp '\''%s'\'' dated %s is below live_date_floor %s (registry %s). Reason: historical bundle is not a current flash target. Set GT_FLASH_ALLOW_HISTORICAL_BISECT=1 to opt in. Path: %s' \
                "$part" "$dt" "$floor" "$registry" "$path")"
        fi
        probe="$(dirname "$probe")"
    done
}

_gt_die_quarantine() {
    # $1 entry, $2 class, $3 marker path, $4 registry, $5 floor, $6 reason, $7 path
    die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: quarantined registry entry '\''%s'\'' (class %s, marker %s, registry %s, live_date_floor %s). Reason: %s. Path: %s' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7")"
}

_gt_refuse_build_dir_against_registry() {
    local path="$1"
    local registry="$2"
    local quar hit kind entry class reason marker_rel floor
    local part cand probe f marker_path readme note

    path="${path%/}"
    [[ -n "$path" ]] || die "REMOTE_BUILD_DIR is empty — refusing before download or fastboot"
    quar="$(dirname "$registry")"

    case "$path" in
        */releases/desktop-flash/.quarantine|*/releases/desktop-flash/.quarantine/*)
            die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: path is listed under releases/desktop-flash/.quarantine/ (registry entry '\''%s'\'', registry %s). Reason: quarantine evidence is not a flashable bundle. Path: %s' \
                "$(basename "$path")" "$registry" "$path")"
            ;;
    esac

    if ! command -v python3 >/dev/null 2>&1; then
        die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: quarantine registry '\''%s'\'' could not be parsed. Reason: python3 is required to read registry.json and is not installed. Path: %s' \
            "$registry" "$path")"
    fi
    hit="$(_gt_registry_match "$registry" "$path")" || die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: quarantine registry '\''%s'\'' could not be parsed. Reason: registry unreadable. Path: %s' \
        "$registry" "$path")"
    if [[ -n "$hit" ]]; then
        IFS=$'\x1f' read -r kind entry class reason marker_rel floor <<<"$hit"
        marker_path="$quar/${marker_rel}"
        _gt_die_quarantine "$entry" "${class:-UNCLASSIFIED}" "$marker_path" "$registry" "${floor:-unknown}" "${reason:-quarantined}" "$path"
    fi

    # Marker files are part of the registry. A row that exists only on disk
    # still refuses, so a JSON miss cannot fail open.
    probe="$path"
    while [[ -n "$probe" && "$probe" != "/" ]]; do
        part="$(basename "$probe")"
        cand="$part"
        [[ "$cand" == *.quarantined ]] && cand="${cand%.quarantined}"
        if [[ "$cand" == *".quarantined-"* ]]; then
            cand="${cand%%.quarantined-*}"
        fi
        if [[ -f "$quar/stamps/$cand.quarantined" ]]; then
            class="$(sed -n 's/^class=//p' "$quar/stamps/$cand.quarantined" | head -1)"
            reason="$(sed -n 's/^reason=//p' "$quar/stamps/$cand.quarantined" | head -1)"
            _gt_die_quarantine "$cand" "${class:-UNCLASSIFIED}" "$quar/stamps/$cand.quarantined" "$registry" "unknown" "${reason:-quarantine marker}" "$path"
        fi
        if [[ -f "$quar/pointers/$cand.quarantined" ]]; then
            class="$(sed -n 's/^class=//p' "$quar/pointers/$cand.quarantined" | head -1)"
            reason="$(sed -n 's/^reason=//p' "$quar/pointers/$cand.quarantined" | head -1)"
            [[ -n "$reason" ]] || reason="$(sed -n 's/^action=//p' "$quar/pointers/$cand.quarantined" | head -1)"
            _gt_die_quarantine "$cand" "${class:-UNCLASSIFIED}" "$quar/pointers/$cand.quarantined" "$registry" "unknown" "${reason:-quarantined pointer}" "$path"
        fi
        f="$(grep -l -F "original_target=$cand" "$quar"/pointers/*.quarantined 2>/dev/null | head -1 || true)"
        if [[ -n "$f" ]]; then
            entry="$(basename "$f" .quarantined)"
            class="$(sed -n 's/^class=//p' "$f" | head -1)"
            reason="$(sed -n 's/^action=//p' "$f" | head -1)"
            _gt_die_quarantine "$entry" "${class:-UNCLASSIFIED}" "$f" "$registry" "unknown" "${reason:-quarantined pointer original_target} (original_target $cand)" "$path"
        fi
        probe="$(dirname "$probe")"
    done

    if [[ -d "$path" && ! -L "$path" ]]; then
        if [[ -f "$path/QUARANTINE-NOT-CURRENT.md" ]]; then
            note="$(grep -m1 -i -E 'FIRST-FLASH|Class:' "$path/QUARANTINE-NOT-CURRENT.md" | sed 's/^[*[:space:]-]*//' || true)"
            _gt_die_quarantine "$path/QUARANTINE-NOT-CURRENT.md" "FIRST_FLASH_RISK" "$path/QUARANTINE-NOT-CURRENT.md" "$registry" "unknown" "${note:-in-tree quarantine marker QUARANTINE-NOT-CURRENT.md}" "$path"
        fi
        readme="$path/README-FLASH-DESKTOP.md"
        if [[ -f "$readme" ]] && grep -qiE 'FIRST-FLASH RISK.*UNRESOLVED' "$readme"; then
            _gt_die_quarantine "$readme" "FIRST_FLASH_RISK" "$readme" "$registry" "unknown" "unresolved FIRST-FLASH RISK block in README-FLASH-DESKTOP.md" "$path"
        fi
    fi

    # Registry hits and on-disk markers already died above. What remains is an
    # unlisted path: refuse a YYYYMMDD below the registry floor before step 0.
    _gt_refuse_unlisted_below_floor "$path" "$registry"
}

refuse_quarantined_remote_build_dir() {
    local path="$1"
    local registry resolved

    if [[ "$path" == *$'\n'* || "$path" == *$'\r'* ]]; then
        die "REMOTE_BUILD_DIR contains a newline — refusing before quarantine lookup, download, or fastboot"
    fi
    if [[ "${path//[\'\"\$\\]/}" != "$path" ]]; then
        die "REMOTE_BUILD_DIR contains shell metacharacters (' \" \$ \\) — refusing before quarantine lookup, download, or fastboot"
    fi

    registry="$(_gt_locate_quarantine_registry)" || die "$(printf 'REFUSING REMOTE_BUILD_DIR before any download or fastboot: quarantine registry unreadable, so '\''%s'\'' cannot be proven non-quarantined. Reason: no releases/desktop-flash/.quarantine/registry.json under GT_STAMP_TREE, REMOTE_TREE, or this script'\''s parent directories. Path: %s' \
        "$path" "$path")"
    _gt_refuse_build_dir_against_registry "$path" "$registry"
    if [[ -e "$path" || -L "$path" ]]; then
        resolved="$(readlink -f -- "$path" 2>/dev/null || true)"
        if [[ -n "$resolved" && "$resolved" != "${path%/}" ]]; then
            _gt_refuse_build_dir_against_registry "$resolved" "$registry"
        fi
    fi
    log "quarantine check: not quarantined: $path"
}

# Set REMOTE_BUILD_DIR / REMOTE_KEY_DIR from codename unless already set.
apply_remote_paths() {
    local codename="$1"
    local auto_build auto_key
    local build_overridden=0
    case "$codename" in
        tokay)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/tokay-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/tokay-latest"
            ;;
        akita)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/akita-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/akita-latest"
            ;;
        komodo)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/komodo-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/komodo-latest"
            ;;
        rango)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/rango-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/rango-latest"
            ;;
        # T-PORT-FLASH-CLI-9DEV: DEC-PORT-GEN8910 devices.
        caiman)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/caiman-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/caiman-latest"
            ;;
        comet)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/comet-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/comet-latest"
            ;;
        tegu)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/tegu-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/tegu-latest"
            ;;
        stallion)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/stallion-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/stallion-latest"
            ;;
        shiba)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/shiba-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/shiba-latest"
            ;;
        husky)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/husky-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/husky-latest"
            ;;
        frankel)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/frankel-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/frankel-latest"
            ;;
        blazer)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/blazer-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/blazer-latest"
            ;;
        mustang)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/mustang-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/mustang-latest"
            ;;
        # T-FLASH-REMOTE-TANGORPRO: Pixel Tablet. NOT in the DEC-PORT-GEN8910
        # matrix. Uses the same `<codename>-latest` convention as every other
        # device (releases/desktop-flash/tangorpro-latest -> tangorpro-20261108-115310).
        tangorpro)
            auto_build="${REMOTE_TREE}/releases/desktop-flash/tangorpro-latest"
            auto_key="${REMOTE_TREE}/releases/desktop-flash/tangorpro-latest"
            ;;
        *)
            die "Unsupported device codename '$codename' (supported: tokay, akita, komodo, rango, caiman, comet, tegu, stallion, shiba, husky, frankel, blazer, mustang, tangorpro)"
            ;;
    esac
    if [[ -z "$REMOTE_BUILD_DIR" ]]; then
        REMOTE_BUILD_DIR="$auto_build"
    else
        build_overridden=1
        log "REMOTE_BUILD_DIR override in effect: $REMOTE_BUILD_DIR"
    fi
    if [[ -z "$REMOTE_KEY_DIR" ]]; then
        # Bisect: keep avb_pkmd.bin with the stamp images (not silent *-latest).
        if [[ "$build_overridden" -eq 1 ]]; then
            REMOTE_KEY_DIR="$REMOTE_BUILD_DIR"
            log "REMOTE_KEY_DIR defaulted to BUILD_DIR override: $REMOTE_KEY_DIR"
        else
            REMOTE_KEY_DIR="$auto_key"
        fi
    else
        log "REMOTE_KEY_DIR override in effect: $REMOTE_KEY_DIR"
    fi
    # Stock rescue boot (laguna family: rango|frankel|blazer|mustang) — used if
    # the GuardTalk boot cannot reach fastbootd. They are the same laguna
    # platform and loop identically without it (B-PORT-LAGUNA-RESCUE-GAP).
    # The -z guard preserves the operator REMOTE_RESCUE_DIR override.
    case "$codename" in
        rango|frankel|blazer|mustang)
            if [[ -z "$REMOTE_RESCUE_DIR" ]]; then
                REMOTE_RESCUE_DIR="${REMOTE_TREE}/releases/desktop-flash/${codename}-rescue-boot"
            fi
            ;;
    esac
    # T-FLASH-REMOTE-TANGORPRO: tangorpro's stock chain is NOT a rescue fallback
    # — it is the mandatory FIRST phase (see the step-4 arm). Its own directory,
    # laid out as releases/desktop-flash/tangorpro-stock-boot (README-STOCK-BOOT.md).
    # It ships six images and NO vbmeta.img, so the rescue download path cannot be
    # reused verbatim: see download_tangorpro_stock_boot.
    if is_tangorpro "$codename"; then
        if [[ -z "${REMOTE_STOCK_BOOT_DIR:-}" ]]; then
            REMOTE_STOCK_BOOT_DIR="${REMOTE_TREE}/releases/desktop-flash/tangorpro-stock-boot"
        fi
        TANGORPRO_STOCK_LOCAL=""
    fi
    # Catch the bash pitfall: `export REMOTE_TREE=... REMOTE_BUILD_DIR=$REMOTE_TREE/...`
    # expands $REMOTE_TREE from the *previous* environment (often empty) →
    # `/releases/desktop-flash/...` and scp dies. Require an absolute path that
    # exists on the remote *before* downloading 3 GB of images.
    [[ "$REMOTE_BUILD_DIR" == /* ]] \
        || die "REMOTE_BUILD_DIR must be an absolute path (got '$REMOTE_BUILD_DIR'). Do not use \$REMOTE_TREE on the same export line — write the full path."
    # MEDIUM-4: path is interpolated into a single-quoted ssh remote command.
    # Reject quote / dollar / backslash / newline before ssh.
    if [[ "$REMOTE_BUILD_DIR" == *$'\n'* || "$REMOTE_BUILD_DIR" == *$'\r'* ]]; then
        die "REMOTE_BUILD_DIR contains a newline — refusing ssh interpolation"
    fi
    if [[ "${REMOTE_BUILD_DIR//[\'\"\$\\]/}" != "$REMOTE_BUILD_DIR" ]]; then
        die "REMOTE_BUILD_DIR contains shell metacharacters (' \" \$ \\) — refusing ssh interpolation"
    fi
    # Quarantine registry / FIRST-FLASH-RISK / .quarantine/ — before ssh or download.
    # Explicit overrides are also refused earlier, before any fastboot invocation.
    if [[ "${GT_QUARANTINE_CHECKED_PATH:-}" != "$REMOTE_BUILD_DIR" ]]; then
        refuse_quarantined_remote_build_dir "$REMOTE_BUILD_DIR"
        GT_QUARANTINE_CHECKED_PATH="$REMOTE_BUILD_DIR"
    fi
    if [[ "$REMOTE_BUILD_DIR" != "${REMOTE_TREE}"/* && "$REMOTE_BUILD_DIR" != "$REMOTE_TREE" ]]; then
        warn "REMOTE_BUILD_DIR is not under REMOTE_TREE ($REMOTE_TREE) — check you did not lose the tree prefix"
    fi
    # GT_FLASH_PLAN_ONLY=1 resolves the table and prints the plan WITHOUT a
    # device and WITHOUT contacting the build host (T-FLASH-REMOTE-TANGORPRO
    # acceptance: a plan path that needs no reachable handset). The existence
    # probe is the only ssh in this function, so it is the only thing skipped —
    # every local refusal above (absolute path, metacharacters, quarantine
    # registry) still runs, and the plan says the live run re-checks this.
    if [[ "${GT_FLASH_PLAN_ONLY:-0}" == "1" ]]; then
        log "plan mode: skipping remote existence probe for $REMOTE_BUILD_DIR (live run re-checks it)"
        return 0
    fi
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" "test -d '$REMOTE_BUILD_DIR' && test -f '$REMOTE_BUILD_DIR/bootloader.img'" \
        || die "remote missing $REMOTE_HOST:$REMOTE_BUILD_DIR/bootloader.img — fix REMOTE_BUILD_DIR (full path, not \$REMOTE_TREE on the same export line)"
}

# -----------------------------------------------------------------------------
# Fail-closed bundle guard — a laguna vendor_dlkm must blocklist nitrous.ko (E-10)
# -----------------------------------------------------------------------------
# Defect E-10: the four laguna hybrid bundles ship a FACTORY vendor_dlkm.img
# whose modules.blocklist OMITS `nitrous.ko` (the BCM4390 BT power/rfkill
# driver) while nitrous.ko is present and listed in modules.load — so the BT
# power path is LIVE and bt-excised.mk's invariant ("harmless without nitrous")
# is false. `mustang-latest` auto-resolves exactly such a bundle: the bootable
# hybrid lacks the blocklist, while the blocklist-correct artifact
# (mustang-20260923-101119) is an ABL-rejected fullgt
# (DEC-PORT-GEN8910-WAVE3-OPERATOR §D3) — this is the mustang-latest ownership
# conflict. The bundle fix is owned by T-EXCISE-LAGUNA-STAGER-BLOCKLIST
# (re-stamp + re-link <dev>-latest) — NOT by this script. This guard is the
# flash-side half: it REFUSES to flash a laguna bundle whose vendor_dlkm does
# not blocklist nitrous (Law 3 — fail loudly; never silently ship the unblocked
# BT power path). The read runs on REMOTE_HOST (debugfs) so the script stays
# runnable from the Operator's macOS laptop, which has no debugfs.
# Override: SKIP_BT_BLOCKLIST_GUARD=1 (loud, operator-only, never auto-set).
verify_bt_blocklist_guard() {
    local codename="${1:-}"
    is_laguna_device "$codename" || return 0
    if [[ "${SKIP_BT_BLOCKLIST_GUARD:-0}" == "1" ]]; then
        warn "SKIP_BT_BLOCKLIST_GUARD=1 — bypassing the laguna vendor_dlkm BT-blocklist guard for '$codename' (UNSAFE: an unblocked nitrous.ko BT power path can ship)"
        return 0
    fi
    local img="$REMOTE_BUILD_DIR/vendor_dlkm.img"
    local load blocklist
    load="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        "debugfs -R 'cat /lib/modules/modules.load' '$img' 2>/dev/null" || true)"
    if [[ -z "$load" ]]; then
        die "REFUSING to flash $codename: could not read modules.load from $REMOTE_HOST:$img (missing image or no debugfs on the build host) — refusing rather than risk shipping the unblocked BCM4390 BT power path (E-10)"
    fi
    if ! grep -q 'nitrous\.ko' <<<"$load"; then
        log "bundle guard: $codename vendor_dlkm does not load nitrous.ko — nothing to blocklist"
        return 0
    fi
    blocklist="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE_HOST" \
        "debugfs -R 'cat /lib/modules/modules.blocklist' '$img' 2>/dev/null" || true)"
    if [[ -z "$blocklist" ]]; then
        die "REFUSING to flash $codename: could not read modules.blocklist from $REMOTE_HOST:$img — refusing rather than risk shipping the unblocked BCM4390 BT power path (E-10)"
    fi
    if grep -qE '^[[:space:]]*blocklist[[:space:]]+nitrous' <<<"$blocklist"; then
        log "bundle guard: $codename vendor_dlkm blocklists nitrous.ko ✓"
        return 0
    fi
    die "REFUSING to flash $codename: the resolved bundle's vendor_dlkm does NOT blocklist nitrous.ko.
  Bundle: $REMOTE_HOST:$REMOTE_BUILD_DIR
  nitrous.ko (BCM4390 BT power/rfkill driver) is present and in modules.load, so flashing this
  bundle would ship the BT power path LIVE (defect E-10; falsifies the bt-excised.mk invariant).
  Ownership: the bootable hybrid lacks the blocklist while the blocklist-correct artifact is an
  ABL-rejected fullgt — the bundle fix is owned by T-EXCISE-LAGUNA-STAGER-BLOCKLIST (re-stamp +
  re-link <dev>-latest), NOT by this script. No partition was flashed."
}

# Read product from fastboot (stderr: "product: tokay") or adb.
detect_product_fastboot() {
    "$FASTBOOT" getvar product 2>&1 | grep -m1 '^product:' | awk '{print $2}' | tr -d '\r' || true
}

detect_product_adb() {
    if ! command -v "$GT_ADB_BIN" >/dev/null 2>&1; then
        return 0
    fi
    "$ADB" shell getprop ro.product.device 2>/dev/null | tr -d '\r' || true
}

# First line from `adb devices` that looks like a transport (skip header/empty).
# Prints: "<serial>\t<state>" or empty.
adb_first_transport() {
    if ! command -v "$GT_ADB_BIN" >/dev/null 2>&1; then
        return 0
    fi
    "$ADB" devices 2>/dev/null \
        | awk 'NR>1 && $1 != "" { print $1 "\t" $2; exit }' \
        || true
}

# Wait until `fastboot devices` is non-empty. Args: label seconds
wait_for_fastboot() {
    local label="${1:-fastboot}"
    local max_secs="${2:-$FASTBOOT_WAIT_SECS}"
    local attempts=$(( (max_secs + 1) / 2 ))
    local i
    for i in $(seq 1 "$attempts"); do
        sleep 2
        DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
        if [[ -n "$DEVICES" ]]; then
            log "device entered fastboot after ${i} attempts ($(( i * 2 ))s) [$label]"
            return 0
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastboot... (${i}/${attempts})"
    done
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    [[ -n "$DEVICES" ]]
}

# GrapheneOS flash-all.sh bootloader sequence (both A/B slots):
#   flash --slot=other → set-active=other → reboot-bootloader → repeat.
# Cite: device/common/generate-factory-images-common.sh
flash_bootloader_ab_both_slots() {
    local img="$LOCAL_WORK_DIR/bootloader.img"
    [[ -f "$img" ]] || die "bootloader.img missing at $img"

    log "Flashing bootloader to BOTH slots (GrapheneOS --slot=other dance)..."
    log "  flash bootloader --slot=other (pass 1)"
    "$FASTBOOT" flash --slot=other bootloader "$img" \
        || die "bootloader flash --slot=other failed (pass 1)"
    "$FASTBOOT" --set-active=other \
        || die "set-active=other failed (pass 1)"
    "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    wait_for_fastboot "bootloader pass 1" "$FASTBOOT_WAIT_SECS" \
        || die "device lost after bootloader pass 1"

    log "  flash bootloader --slot=other (pass 2 — covers former active slot)"
    "$FASTBOOT" flash --slot=other bootloader "$img" \
        || die "bootloader flash --slot=other failed (pass 2)"
    "$FASTBOOT" --set-active=other \
        || die "set-active=other failed (pass 2)"
    "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    wait_for_fastboot "bootloader pass 2" "$FASTBOOT_WAIT_SECS" \
        || die "device lost after bootloader pass 2"
    log "Bootloader flashed on both slots ✓"
}

# Device firmware cleanup matching GrapheneOS script/generate-release.sh flags.
# AUTHORITY: script/generate-release.sh (READ-ONLY). Exactly two profiles:
#   rango|mustang|blazer|frankel : DISABLE_UART + DISABLE_DPM          (NO fips)
#   every other program device   : DISABLE_UART + DISABLE_FIPS + DISABLE_DPM
# Never infer this from the SoC: blazer is laguna but must NOT erase fips, while
# stallion is zumapro and MUST. A missing profile is a parity regression, so the
# catch-all arm dies — it must never warn-and-continue (Law 3, fail loudly).
apply_grapheneos_firmware_cleanup() {
    local codename="${FLASH_DEVICE:-}"
    case "$codename" in
        # laguna/muzel (Pixel 10 / 10 Pro / 10 Pro XL) + rango: NO fips erase.
        rango|mustang|blazer|frankel)
            log "$codename: GrapheneOS cleanup (uart disable + erase dpm_a/dpm_b — NO fips)..."
            "$FASTBOOT" oem uart disable \
                || die "oem uart disable failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase dpm_a \
                || die "erase dpm_a failed (required for $codename — clears stale debugpolicy / err -7)"
            "$FASTBOOT" erase dpm_b \
                || die "erase dpm_b failed (required for $codename — clears stale debugpolicy / err -7)"
            log "$codename firmware cleanup ✓"
            ;;
        # Everything else in the program: UART + FIPS + DPM. tangorpro is in
        # script/generate-release.sh's `elif` branch (:61) alongside the Pixel
        # 8/9/10a family, so it takes the SAME three erases — including
        # `erase fips`, which it does not inherit by being gs201.
        tokay|akita|komodo|caiman|comet|tegu|stallion|shiba|husky|tangorpro)
            log "$codename: GrapheneOS cleanup (uart + erase fips + erase dpm_a/dpm_b)..."
            "$FASTBOOT" oem uart disable \
                || die "oem uart disable failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase fips \
                || die "erase fips failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase dpm_a \
                || die "erase dpm_a failed (required for $codename GrapheneOS parity)"
            "$FASTBOOT" erase dpm_b \
                || die "erase dpm_b failed (required for $codename GrapheneOS parity)"
            log "$codename firmware cleanup ✓"
            ;;
        # T-PORT-FLASH-CLI-9DEV / A3: a missing profile is a parity regression,
        # not a warning. Never flash a device without GrapheneOS cleanup parity.
        *)
            die "No GrapheneOS firmware-cleanup profile for '$codename' — add it to BOTH this case and script/generate-release.sh"
            ;;
    esac
}

# After FLASH_DEVICE is known, append device-specific downloads.
# Every program device except tokay has an init.insmod.<codename>.cfg.
apply_device_extra_downloads() {
    case "${FLASH_DEVICE:-}" in
        akita)
            for f in "${AKITA_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "akita extras: ${AKITA_EXTRA_FILES[*]}"
            ;;
        komodo)
            for f in "${KOMODO_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "komodo extras: ${KOMODO_EXTRA_FILES[*]}"
            ;;
        rango)
            for f in "${RANGO_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "rango extras: ${RANGO_EXTRA_FILES[*]}"
            ;;
        # T-PORT-FLASH-CLI-9DEV: DEC-PORT-GEN8910 devices (own insmod cfg each).
        caiman)
            for f in "${CAIMAN_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "caiman extras: ${CAIMAN_EXTRA_FILES[*]}"
            ;;
        comet)
            for f in "${COMET_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "comet extras: ${COMET_EXTRA_FILES[*]}"
            ;;
        tegu)
            for f in "${TEGU_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "tegu extras: ${TEGU_EXTRA_FILES[*]}"
            ;;
        stallion)
            for f in "${STALLION_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "stallion extras: ${STALLION_EXTRA_FILES[*]}"
            ;;
        shiba)
            for f in "${SHIBA_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "shiba extras: ${SHIBA_EXTRA_FILES[*]}"
            ;;
        husky)
            for f in "${HUSKY_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "husky extras: ${HUSKY_EXTRA_FILES[*]}"
            ;;
        frankel)
            for f in "${FRANKEL_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "frankel extras: ${FRANKEL_EXTRA_FILES[*]}"
            ;;
        blazer)
            for f in "${BLAZER_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "blazer extras: ${BLAZER_EXTRA_FILES[*]}"
            ;;
        mustang)
            for f in "${MUSTANG_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "mustang extras: ${MUSTANG_EXTRA_FILES[*]}"
            ;;
        # T-FLASH-REMOTE-TANGORPRO: Pixel Tablet. Own insmod cfg, same as the
        # rest of the table; it is NOT the tokay "no cfg" exception.
        tangorpro)
            for f in "${TANGORPRO_EXTRA_FILES[@]}"; do
                ALL_DOWNLOADS+=("$f")
            done
            log "tangorpro extras: ${TANGORPRO_EXTRA_FILES[*]}"
            ;;
    esac
    # T-FLASH-REMOTE-TANGORPRO: drop the images that have NO SUBJECT on this
    # device, so the download loop and the post-download "must exist" loop do
    # not die on a file the device does not have (no radio partition; no chained
    # vbmeta). Loud, because a silently shorter list is how a device table lies.
    local _absent _kept
    for _absent in "${TANGORPRO_ABSENT_IMAGES[@]}"; do
        is_tangorpro "${FLASH_DEVICE:-}" || break
        _kept=()
        for f in "${ALL_DOWNLOADS[@]}"; do
            [[ "$f" == "$_absent" ]] || _kept+=("$f")
        done
        if [[ "${#_kept[@]}" -eq "${#ALL_DOWNLOADS[@]}" ]]; then
            continue    # already absent from the base list
        fi
        ALL_DOWNLOADS=("${_kept[@]}")
        log "tangorpro: '$_absent' has no subject on this device — removed from the download set"
    done
}

# Insurance only: GrapheneOS flash-all never adb-pushes this file. It is baked
# into vendor_dlkm.img (guardtalk-insmod.mk). Safe no-op unless FLASH_DEVICE is
# one of the devices with an init.insmod.<device>.cfg (all program devices but
# tokay). Push only if an older vendor_dlkm.img omitted it
# (boot-logo hang / missing Wi‑Fi touch haptics). Never FATAL after Android
# already reached — vendor_dlkm is often EROFS and remount-rw fails.
install_insmod_cfg_via_adb() {
    local codename="${FLASH_DEVICE:-}"
    local cfg_name=""
    case "$codename" in
        akita) cfg_name="init.insmod.akita.cfg" ;;
        komodo) cfg_name="init.insmod.komodo.cfg" ;;
        rango) cfg_name="init.insmod.rango.cfg" ;;
        # T-PORT-FLASH-CLI-9DEV: DEC-PORT-GEN8910 devices.
        caiman) cfg_name="init.insmod.caiman.cfg" ;;
        comet) cfg_name="init.insmod.comet.cfg" ;;
        tegu) cfg_name="init.insmod.tegu.cfg" ;;
        stallion) cfg_name="init.insmod.stallion.cfg" ;;
        shiba) cfg_name="init.insmod.shiba.cfg" ;;
        husky) cfg_name="init.insmod.husky.cfg" ;;
        frankel) cfg_name="init.insmod.frankel.cfg" ;;
        blazer) cfg_name="init.insmod.blazer.cfg" ;;
        mustang) cfg_name="init.insmod.mustang.cfg" ;;
        tangorpro) cfg_name="init.insmod.tangorpro.cfg" ;;
        *) return 0 ;;
    esac
    local cfg="$LOCAL_WORK_DIR/$cfg_name"
    [[ -f "$cfg" ]] || die "$cfg_name missing locally after download"

    if ! command -v "$GT_ADB_BIN" >/dev/null 2>&1; then
        warn "adb not found — cannot push $cfg_name (vendor_dlkm.img should already contain it)"
        return 0
    fi

    log "Waiting for adb to check $cfg_name (up to ${ADB_WAIT_SECS}s)..."
    local waited=0
    while [[ "$waited" -lt "$ADB_WAIT_SECS" ]]; do
        if "$ADB" wait-for-device shell true >/dev/null 2>&1; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
        [[ $((waited % 20)) -eq 0 ]] && log "  still waiting for adb... (${waited}/${ADB_WAIT_SECS}s)"
    done

    if ! "$ADB" shell true >/dev/null 2>&1; then
        warn "adb not ready after ${ADB_WAIT_SECS}s — skip cfg push. If stuck on boot logo, re-run with phone booted/adb, or reflash (fixed vendor_dlkm.img)."
        return 0
    fi

    if "$ADB" shell "test -f /vendor_dlkm/etc/$cfg_name" >/dev/null 2>&1; then
        log "$cfg_name already on vendor_dlkm (from image) — skip insurance push"
        return 0
    fi

    log "vendor_dlkm missing $cfg_name — insurance push (adb root + remount)..."
    "$ADB" root >/dev/null 2>&1 || true
    sleep 2
    "$ADB" wait-for-device >/dev/null 2>&1 || true
    if ! "$ADB" remount >/dev/null 2>&1; then
        if ! "$ADB" shell mount -o remount,rw /vendor_dlkm >/dev/null 2>&1; then
            warn "could not remount vendor_dlkm rw (often EROFS). Skip insurance push — phone already reached Android."
            return 0
        fi
    fi

    log "Pushing $cfg_name → /vendor_dlkm/etc/..."
    if ! "$ADB" push "$cfg" "/vendor_dlkm/etc/$cfg_name"; then
        warn "adb push $cfg_name failed (vendor_dlkm read-only). Phone already reached Android; this file is optional insurance."
        return 0
    fi
    if "$ADB" shell "test -f /vendor_dlkm/etc/$cfg_name" >/dev/null 2>&1; then
        log "$cfg_name installed on device ✓"
        log "Rebooting so second-stage modules (audio/haptics/touch) can load..."
        "$ADB" reboot >/dev/null 2>&1 || warn "adb reboot failed (reboot manually)"
    else
        warn "$cfg_name not visible after push — continuing (boot already succeeded)"
    fi
}

# Backward-compatible alias (akita callers / docs).
install_akita_insmod_cfg_via_adb() {
    install_insmod_cfg_via_adb
}

# If phone is in Android (or recovery) via adb, reboot into bootloader.
# Leaves DEVICES set to `fastboot devices` output when ready.
ensure_device_in_fastboot() {
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" ]]; then
        log "Device already in fastboot"
        return 0
    fi

    local transport serial state
    transport="$(adb_first_transport)"
    if [[ -z "$transport" ]]; then
        if ! command -v "$GT_ADB_BIN" >/dev/null 2>&1; then
            die "No device in fastboot, and adb is not installed. Install platform-tools, or boot into fastboot manually (vol-down + power)."
        fi
        die "No device in fastboot or adb. Boot into Android with USB debugging enabled, or hold vol-down + power for fastboot, then retry."
    fi

    serial="$(printf '%s' "$transport" | awk -F'\t' '{print $1}')"
    state="$(printf '%s' "$transport" | awk -F'\t' '{print $2}')"

    case "$state" in
        device)
            DETECTED_RAW="$(detect_product_adb)"
            log "Phone is booted into Android (adb serial=$serial, product=${DETECTED_RAW:-unknown})"
            log "Rebooting into fastboot (bootloader) automatically..."
            ;;
        recovery)
            DETECTED_RAW="$(detect_product_adb)"
            log "Phone is in recovery (adb serial=$serial, product=${DETECTED_RAW:-unknown})"
            log "Rebooting into fastboot (bootloader) automatically..."
            ;;
        sideload)
            log "Phone is in sideload mode (adb serial=$serial)"
            log "Rebooting into fastboot (bootloader) automatically..."
            ;;
        unauthorized)
            die "adb device is unauthorized. Unlock the phone, accept the RSA fingerprint prompt, then re-run."
            ;;
        offline)
            die "adb device is offline (serial=$serial). Unplug/replug USB, toggle USB debugging, then re-run."
            ;;
        *)
            die "adb device state='$state' (serial=$serial) cannot auto-enter fastboot. Boot into fastboot manually (vol-down + power)."
            ;;
    esac

    "$ADB" reboot bootloader \
        || die "adb reboot bootloader failed. Boot into fastboot manually (vol-down + power) and retry."

    wait_for_fastboot "adb reboot bootloader" "$FASTBOOT_WAIT_SECS" \
        || die "Device did not enter fastboot after adb reboot bootloader (waited ${FASTBOOT_WAIT_SECS}s). Manual: vol-down + power, then re-run."
}

# -----------------------------------------------------------------------------
# Argument parsing (T-EXCISE-FLASH-SERIAL-PINNING)
# -----------------------------------------------------------------------------
# Runs here, after die()/log() exist and before the quarantine gate and Step 0,
# so a malformed --serial is refused before any SSH, download, or write.
# --serial is the only flag. Positional arguments are still accepted and ignored
# on purpose, so a launcher that appends an argument keeps working unchanged.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --serial|-s)
            if [[ $# -lt 2 || -z "${2:-}" ]]; then
                die "--serial requires a value (the serial shown by 'fastboot devices', e.g. 59080DLCH0022P). Nothing was flashed."
            fi
            GT_FLASH_SERIAL="$2"
            shift 2
            ;;
        --serial=*)
            GT_FLASH_SERIAL="${1#--serial=}"
            [[ -n "$GT_FLASH_SERIAL" ]] \
                || die "--serial= requires a value (the serial shown by 'fastboot devices'). Nothing was flashed."
            shift
            ;;
        --help|-h)
            echo "usage: $(basename "$0") [--serial <serial>]" >&2
            echo "  --serial <serial>   pin this run to ONE handset (same as GT_FLASH_SERIAL=<serial>)" >&2
            echo "                      unset = unchanged behaviour, with a warning that nothing is pinned" >&2
            exit 0
            ;;
        *)
            # Unknown or positional argument: ignored on purpose (backwards compatible).
            shift
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Quarantine gate before device detect. An explicit REMOTE_BUILD_DIR is known
# now; refusing here is before fastboot, ssh, and scp. Auto <dev>-latest is
# checked inside apply_remote_paths, still before download or a fastboot write.
# GT_FLASH_QUARANTINE_CHECK_ONLY=1 stops after the check so a harness never
# reaches a handset.
# -----------------------------------------------------------------------------
if [[ -n "${REMOTE_BUILD_DIR:-}" ]]; then
    refuse_quarantined_remote_build_dir "$REMOTE_BUILD_DIR"
    GT_QUARANTINE_CHECKED_PATH="$REMOTE_BUILD_DIR"
fi
if [[ "${GT_FLASH_QUARANTINE_CHECK_ONLY:-}" == "1" ]]; then
    [[ -n "${REMOTE_BUILD_DIR:-}" ]] || die "GT_FLASH_QUARANTINE_CHECK_ONLY=1 requires REMOTE_BUILD_DIR (refusing to continue into fastboot)"
    echo "PASS: REMOTE_BUILD_DIR is not refused by the quarantine check: $REMOTE_BUILD_DIR"
    exit 0
fi

# -----------------------------------------------------------------------------
# Plan mode (GT_FLASH_PLAN_ONLY=1) — T-FLASH-REMOTE-TANGORPRO
# -----------------------------------------------------------------------------
# Resolves the DEVICE TABLE and prints the exact plan for one codename, then
# exits. No device, no ssh/scp, no download, no fastboot. This is the only way
# to demonstrate a resolved plan for a codename whose handset is not reachable,
# and it is the acceptance mechanism for a newly registered device.
#
# It deliberately runs BEFORE the readiness gate, because that gate refuses any
# codename the reporter does not name — which is itself a fact the plan must
# REPORT rather than hide. `readiness_reporter_knows` below measures it locally
# from the reporter's DEVICES block, so the plan states whether a live run would
# be admitted instead of implying that it would.
gt_plan_readiness_membership() {
    local codename="$1" reporter
    reporter="${GT_READY_REPORTER:-$(dirname "$0")/gt-ready-devices.sh}"
    if [[ ! -f "$reporter" || ! -r "$reporter" ]]; then
        printf 'UNKNOWN (reporter not readable: %s)\n' "$reporter"
        return 0
    fi
    # Read ONLY the reporter's DEVICES block, the same block its main loop
    # iterates, so this is a measurement of the real authority.
    if awk '
        $0 ~ /^DEVICES="/ { p=1; next }
        p && $0 ~ /^"$/ { exit }
        p && index($0, "|") == 0 { next }
        p { line=$0; sub(/\r$/, "", line); sub(/^[[:space:]]+/, "", line)
            split(line, a, "|"); if (a[1] != "") print a[1] }
    ' "$reporter" | grep -qx -- "$codename"; then
        printf 'YES — reporter names %s; a live run consults its verdict\n' "$codename"
    else
        printf 'NO — reporter DEVICES has no %s row, so a LIVE run is REFUSED before any write\n' "$codename"
    fi
}

gt_plan_print() {
    local codename="$1"
    local f
    printf 'FLASH-PLAN (no device contacted, nothing flashed)\n'
    printf '  FLASH_READY=false\n'
    printf '  BOOT_VERIFIED=false\n'
    printf '  LIVE_FLASH_CLAIMED=false\n'
    printf '  NOT_A_FLASH=true\n'
    printf '\n'
    printf 'resolved\n'
    printf '  codename            : %s\n' "$codename"
    printf '  model               : %s\n' "$(device_pretty "$codename")"
    printf '  remote_host         : %s\n' "$REMOTE_HOST"
    printf '  remote_tree         : %s\n' "$REMOTE_TREE"
    printf '  remote_build_dir    : %s\n' "$REMOTE_BUILD_DIR"
    printf '  remote_key_dir      : %s\n' "$REMOTE_KEY_DIR"
    if is_tangorpro "$codename"; then
        printf '  remote_stock_boot   : %s\n' "$REMOTE_STOCK_BOOT_DIR"
    fi
    if [[ -n "${REMOTE_RESCUE_DIR:-}" ]]; then
        printf '  remote_rescue_dir   : %s\n' "$REMOTE_RESCUE_DIR"
    fi
    printf '\n'
    printf 'device_facts\n'
    if has_radio_hardware "$codename"; then
        printf '  radio_hardware      : yes — step 2 flashes radio.img (RADIO_MODE=%s)\n' "$RADIO_MODE"
    else
        printf '  radio_hardware      : NO — no radio partition, no radio.img; step 2 baseband step SKIPPED\n'
        printf '                        (DEC-PORT-TANGORPRO-003; RADIO_MODE has no subject here)\n'
    fi
    printf '  firmware_cleanup    : '
    case "$codename" in
        rango|mustang|blazer|frankel) printf 'oem uart disable + erase dpm_a + erase dpm_b (NO fips)\n' ;;
        tokay|akita|komodo|caiman|comet|tegu|stallion|shiba|husky|tangorpro) printf 'oem uart disable + erase fips + erase dpm_a + erase dpm_b\n' ;;
        *) printf 'NONE — no profile, a live run DIES here (parity regression)\n' ;;
    esac
    printf '  fastbootd_phase1    : '
    case "$codename" in
        tangorpro) printf 'STOCK boot chain FIRST, then wipe-super, then reboot fastboot (mandatory)\n' ;;
        rango|frankel|blazer|mustang) printf 'stock factory RESCUE boot chain first (avoids G-logo loop)\n' ;;
        *) printf 'reuse the boot chain currently on the device\n' ;;
    esac
    printf '\n'
    printf 'download_set (%d files)\n' "${#ALL_DOWNLOADS[@]}"
    for f in "${ALL_DOWNLOADS[@]}"; do
        printf '  %s\n' "$f"
    done
    if is_tangorpro "$codename"; then
        printf '  [stock boot chain, separate dir]\n'
        for f in "${TANGORPRO_STOCK_IMGS[@]}"; do
            printf '  %s/%s\n' "$REMOTE_STOCK_BOOT_DIR" "$f"
        done
    fi
    printf '\n'
    printf 'flash_sequence\n'
    printf '  2/8  bootloader — BOTH A/B slots (--slot=other dance)\n'
    if has_radio_hardware "$codename"; then
        printf '  2/8  radio  — flash radio.img (RADIO_MODE=%s) + reboot to bootloader\n' "$RADIO_MODE"
    else
        printf '  2/8  radio  — SKIPPED (no radio hardware on this device) + reboot to bootloader\n'
    fi
    printf '  2/8  avb_custom_key — erase, then flash avb_pkmd.bin (BEFORE any vbmeta)\n'
    printf '  2/8  firmware cleanup — see device_facts above\n'
    printf '  3/8  erase userdata + metadata, set-active\n'
    case "$codename" in
        tangorpro)
        printf '  4/8  PHASE 1: flash STOCK boot chain (boot, init_boot, vendor_boot, vendor_kernel_boot)\n'
        printf '       wipe-super super_empty.img\n'
        printf '       reboot fastboot -> require is-userspace=yes\n'
        ;;
        rango|frankel|blazer|mustang)
        printf '  4/8  flash STOCK rescue boot chain, then reboot fastboot -> require is-userspace=yes\n'
        ;;
        *)
        printf '  4/8  reboot fastboot with the current chain -> require is-userspace=yes\n'
        ;;
    esac
    printf '  5/8  fastbootd: logical partitions\n'
    if is_tangorpro "$codename"; then
        printf '       super.img is NOT in this bundle -> wipe-super already done in 4/8,\n'
        printf '       then per-partition flash of the six logical images\n'
    else
        printf '       super.img if present, else wipe-super + per-partition logical flash\n'
    fi
    for f in "${LOGICAL_IMAGES[@]}"; do
        printf '       %s\n' "${f%.img}"
    done
    printf '  5/8  reboot-bootloader (return from fastbootd)\n'
    printf '  6/8  GuardTalk boot chain (slot current)\n'
    for f in "${AB_IMAGES[@]}"; do
        printf '       %s\n' "${f%.img}"
    done
    printf '       dtbo\n'
    printf '  7/8  vbmeta pass (single, after the boot chain)\n'
    printf '       vbmeta            (--disable-verity --disable-verification)\n'
    if is_tangorpro "$codename"; then
        printf '       vbmeta_system     SKIPPED — no vbmeta_system.img (single-vbmeta device)\n'
        printf '       vbmeta_vendor     SKIPPED — no vbmeta_vendor.img (single-vbmeta device)\n'
    else
        printf '       vbmeta_system\n'
        printf '       vbmeta_vendor\n'
    fi
    printf '  8/8  reboot, watch for adb / fastboot fallback\n'
    printf '  8b   adb push '
    case "$codename" in
        tokay) printf 'SKIPPED (tokay ships no init.insmod cfg)\n' ;;
        *) printf 'init.insmod.%s.cfg (insurance only; baked into vendor_dlkm.img)\n' "$codename" ;;
    esac
    printf '\n'
    printf 'readiness_gate\n'
    printf '  reporter_device_row : %s\n' "$(gt_plan_readiness_membership "$codename")"
    printf '  BOOT_VERIFIED=false — this plan is a table resolution, never boot evidence.\n'
}

# -----------------------------------------------------------------------------
# Plan mode dispatch (GT_FLASH_PLAN_ONLY=1) — T-FLASH-REMOTE-TANGORPRO
# -----------------------------------------------------------------------------
# Requires DEVICE= so the target is unambiguous, resolves the table through the
# SAME functions the live path uses, prints the plan, and exits. It never reaches
# device detect, ssh/scp, download, or fastboot.
#
# This runs BEFORE the readiness gate ON PURPOSE. That gate refuses any codename
# the reporter does not name, so putting it first would make the plan path
# unreachable for exactly the device the plan exists to demonstrate. The plan
# does not dodge the gate — it MEASURES it: gt_plan_readiness_membership reads
# the reporter's own DEVICES block and prints whether a live run would be
# admitted. So the plan cannot be mistaken for a green light it has not earned.
if [[ "${GT_FLASH_PLAN_ONLY:-0}" == "1" ]]; then
    [[ -n "${DEVICE:-}" ]] \
        || die "GT_FLASH_PLAN_ONLY=1 requires DEVICE=<codename> — a plan with no target is not a plan"
    PLAN_DEVICE="$(normalize_device "$DEVICE")"
    [[ -n "$PLAN_DEVICE" ]] \
        || die "DEVICE='$DEVICE' is not a codename this table knows, so there is no plan to print (supported: tokay, akita, komodo, rango, caiman, comet, tegu, stallion, shiba, husky, frankel, blazer, mustang, tangorpro)"
    FLASH_DEVICE="$PLAN_DEVICE"
    ALL_DOWNLOADS=("${FW_IMAGES[@]}" "${AB_IMAGES[@]}" "${NOAB_IMAGES[@]}" "${LOGICAL_IMAGES[@]}" "${SUPER_IMAGE[@]}" "${EXTRA_FILES[@]}")
    apply_remote_paths "$FLASH_DEVICE"
    apply_device_extra_downloads
    gt_plan_print "$FLASH_DEVICE"
    exit 0
fi

# -----------------------------------------------------------------------------
# Readiness gate, first opportunity (T-EXCISE-FLASH-BUILDOK-REFUSAL)
# -----------------------------------------------------------------------------
# Runs here — before Step 0, before SSH, before any download, and before any
# fastboot/adb command — WHENEVER the target is already known from the
# environment (REMOTE_BUILD_DIR names a stamp, or DEVICE= names a codename).
# That is the operator's explicit-override path and the harness path. On the
# fully auto-detected path the codename is only knowable after device detect, so
# the gate runs immediately after FLASH_DEVICE is resolved instead (still before
# any download or write). The gate is idempotent: a second call is a no-op.
GT_READY_TARGET_CODENAME=""
if [[ -n "${DEVICE:-}" ]]; then
    GT_READY_TARGET_CODENAME="$(normalize_device "$DEVICE")"
fi
if [[ -n "${REMOTE_BUILD_DIR:-}" || -n "$GT_READY_TARGET_CODENAME" ]]; then
    gt_readiness_gate "$GT_READY_TARGET_CODENAME"
fi
if [[ "${GT_READY_CHECK_ONLY:-}" == "1" ]]; then
    [[ "$GT_READY_GATED" == "1" ]] \
        || die "GT_READY_CHECK_ONLY=1 requires REMOTE_BUILD_DIR or DEVICE= so there is a stamp to check (refusing to continue into device detect or fastboot)"
    echo "PASS: readiness gate did not refuse stamp '$GT_READY_STAMP' ($GT_READY_CODENAME): verdict $GT_READY_VERDICT. BOOT_VERIFIED=false."
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 0 — Sanity checks + device detect
# -----------------------------------------------------------------------------
step "0/8  Sanity checks + device detect"

command -v "$GT_FASTBOOT_BIN" >/dev/null 2>&1 || die "fastboot not found in PATH"
command -v scp >/dev/null 2>&1 || die "scp not found in PATH"
command -v ssh >/dev/null 2>&1 || die "ssh not found in PATH"

# Serial pin: refuse a malformed serial, then refuse a pin whose serial is not
# attached. Both run before SSH, download, and every fastboot/adb write.
gt_serial_validate
gt_pin_preflight
if ! gt_serial_pinned; then
    warn "NO SERIAL PINNED — this run will operate on whatever enumerates first. With more than one handset attached the wrong device can be flashed. Pin it: --serial <serial> or GT_FLASH_SERIAL=<serial>."
fi

require_fastboot_min_version
log "remote:   $REMOTE_HOST"
log "tree:     $REMOTE_TREE"
log "local work: $LOCAL_WORK_DIR"

DETECTED_RAW=""
ensure_device_in_fastboot
log "device: $DEVICES"

# Resolve codename: DEVICE= override > adb detect > fastboot product
if [[ -n "$DEVICE" ]]; then
    FLASH_DEVICE="$(normalize_device "$DEVICE")"
    [[ -n "$FLASH_DEVICE" ]] || die "DEVICE='$DEVICE' not supported (use tokay, akita, komodo, rango, caiman, comet, tegu, stallion, shiba, husky, frankel, blazer, or mustang)"
    log "DEVICE override: $FLASH_DEVICE ($(device_pretty "$FLASH_DEVICE"))"
else
    if [[ -z "$DETECTED_RAW" ]]; then
        DETECTED_RAW="$(detect_product_fastboot)"
    fi
    # If still empty, try fastboot anyway (adb path may have missed prop)
    if [[ -z "$DETECTED_RAW" ]]; then
        DETECTED_RAW="$(detect_product_fastboot)"
    fi
    FLASH_DEVICE="$(normalize_device "$DETECTED_RAW")"
    if [[ -z "$FLASH_DEVICE" ]]; then
        die "Could not map product '${DETECTED_RAW:-unknown}' to a flash bundle. Set DEVICE=tokay, DEVICE=akita, DEVICE=komodo, DEVICE=rango, DEVICE=caiman, DEVICE=comet, DEVICE=tegu, DEVICE=stallion, DEVICE=shiba, DEVICE=husky, DEVICE=frankel, DEVICE=blazer, or DEVICE=mustang explicitly."
    fi
    log "Detected product='$DETECTED_RAW' → $(device_pretty "$FLASH_DEVICE")"
fi

# Fail closed if fastboot product disagrees with DEVICE override
FB_PRODUCT="$(detect_product_fastboot)"
FB_NORM="$(normalize_device "$FB_PRODUCT")"
if [[ -n "$FB_NORM" && "$FB_NORM" != "$FLASH_DEVICE" ]]; then
    # T-EXCISE-FLASH-SERIAL-PINNING: when pinned, name the serial in the refusal so
    # the operator can see WHICH handset was rejected. Same condition, same exit.
    if gt_serial_pinned; then
        die "GT_FLASH_SERIAL='$GT_FLASH_SERIAL' resolves to '$FB_NORM' but the flash target is '$FLASH_DEVICE'. Refusing to flash the wrong handset. Nothing was flashed."
    fi
    die "Plugged device is '$FB_PRODUCT' but flash target is '$FLASH_DEVICE'. Unplug the other phone or set DEVICE=$FB_NORM."
fi
# T-EXCISE-FLASH-SERIAL-PINNING: the guard above passes silently when the product
# cannot be read. For a pinned run that would mean writing to a device we could
# not identify, so a pin turns an unreadable codename into a refusal.
if gt_serial_pinned; then
    [[ -n "$FB_NORM" ]] \
        || die "GT_FLASH_SERIAL='$GT_FLASH_SERIAL' is pinned but its codename could not be read (fastboot reported product='${FB_PRODUCT:-<empty>}'). Refusing to write to a device that cannot be identified as '$FLASH_DEVICE'. Nothing was flashed."
    log "serial pin verified: $GT_FLASH_SERIAL → $FB_NORM ($(device_pretty "$FB_NORM")) matches the flash target"
fi

# Readiness gate, second opportunity (T-EXCISE-FLASH-BUILDOK-REFUSAL).
# Reached only on the AUTO-DETECTED path (no DEVICE=, no REMOTE_BUILD_DIR): the
# codename is known now, so the stamp can be resolved — by the reporter itself,
# from the same <dev>-latest pointer this script will later read. That is why it
# runs HERE, before apply_remote_paths (SSH), before the download loop, and
# before every fastboot/adb write. A no-op when the gate already ran at the
# first opportunity.
gt_readiness_gate "$FLASH_DEVICE"

# Validate GT_BOOT_CHAIN now that the target device is known (T-PORT-LAGUNA-HYBRID).
case "$GT_BOOT_CHAIN" in
    gt|hybrid) : ;;
    *) die "GT_BOOT_CHAIN='$GT_BOOT_CHAIN' is invalid (expected 'gt' (default) or 'hybrid')" ;;
esac
if [[ "$GT_BOOT_CHAIN" == "hybrid" ]] && ! is_laguna_device "$FLASH_DEVICE"; then
    die "GT_BOOT_CHAIN=hybrid is only valid for the laguna family (rango|frankel|blazer|mustang). '$FLASH_DEVICE' is not laguna — use the default GT_BOOT_CHAIN=gt."
fi
if [[ "$GT_BOOT_CHAIN" == "hybrid" ]]; then
    log "boot chain: GT_BOOT_CHAIN=hybrid — stock factory rescue boot stays installed; step-6 GT A/B boot flash WILL BE SKIPPED (laguna fullgt boot is ABL-rejected on-device)"
else
    log "boot chain: GT_BOOT_CHAIN=gt (default) — GuardTalk A/B boot chain is flashed at step 6 (unchanged)"
fi

# Validate RADIO_MODE now that the target device is known (T-EXCISE-FW-RADIO).
case "$RADIO_MODE" in
    flash|erase) : ;;
    *) die "RADIO_MODE='$RADIO_MODE' is invalid (expected 'flash' (default) or 'erase')" ;;
esac
if [[ "$RADIO_MODE" == "erase" ]]; then
    log "baseband: RADIO_MODE=erase — radio.img WILL NOT be flashed; the 'radio' partition is erased at step 2 (baseband firmware NOT installed)"
else
    log "baseband: RADIO_MODE=flash (default) — radio.img is flashed to the 'radio' partition at step 2 (unchanged)"
fi

apply_remote_paths "$FLASH_DEVICE"
apply_device_extra_downloads
# Fail closed BEFORE any download/flash: a laguna bundle whose vendor_dlkm does
# not blocklist nitrous.ko (E-10 / mustang-latest ownership conflict) is refused.
verify_bt_blocklist_guard "$FLASH_DEVICE"
log "build dir: $REMOTE_BUILD_DIR"
log "key dir:   $REMOTE_KEY_DIR"

# Get current slot
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# Fail closed if bootloader is locked (flash will fail with a cryptic remote error).
UNLOCKED="$("$FASTBOOT" getvar unlocked 2>&1 | grep -m1 '^unlocked:' | awk '{print $2}' | tr -d '\r' || true)"
UNLOCKED_LC="$(printf '%s' "$UNLOCKED" | tr '[:upper:]' '[:lower:]')"
log "unlocked: ${UNLOCKED:-unknown}"
if [[ "$UNLOCKED_LC" != "yes" ]]; then
    die "Bootloader is LOCKED (unlocked=${UNLOCKED:-unknown}). Unlock first:
  1) Boot Android → Developer options → enable OEM unlocking
  2) Reboot to fastboot:  adb reboot bootloader
  3) Unlock (THIS WIPES THE PHONE):  fastboot flashing unlock
  4) Confirm Unlock on the device screen, wait for wipe + reboot
  5) Re-enter fastboot and re-run this script"
fi

# Flash to current slot
TARGET_SLOT="$CURRENT_SLOT"

# -----------------------------------------------------------------------------
# Step 0b — Offer to purge stale cached images
# -----------------------------------------------------------------------------
echo ""
echo "[flash] Local work dir: $LOCAL_WORK_DIR"
STALE_COUNT=$(find "$LOCAL_WORK_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.bin' \) 2>/dev/null | wc -l | tr -d ' ')
if [[ "$STALE_COUNT" -gt 0 ]]; then
    log "Found $STALE_COUNT cached .img/.bin file(s) in $LOCAL_WORK_DIR"
    read -r -p "[flash] Delete all local .img and .bin files before downloading fresh copies? [Y/n] " ans
    case "${ans:-Y}" in
        [Yy]*|"")
            log "Purging stale .img and .bin files..."
            find "$LOCAL_WORK_DIR" -maxdepth 1 -type f \( -name '*.img' -o -name '*.bin' \) -delete
            log "Purged ✓"
            ;;
        *)
            warn "Keeping cached files (force-re-download still applies to logical/boot/vbmeta images)"
            ;;
    esac
else
    log "No cached .img/.bin files found — will download fresh."
fi

# -----------------------------------------------------------------------------
# Step 1 — Download images from build server
# -----------------------------------------------------------------------------
step "1/8  Download images from build server"

for f in "${ALL_DOWNLOADS[@]}"; do
    # Force re-download vbmeta_system and vbmeta_vendor (they may be stale
    # 256-byte empty copies from a previous attempt; we now use the full
    # 8192-byte root vbmeta for all three partitions).
    if [[ "$f" == "vbmeta_system.img" || "$f" == "vbmeta_vendor.img" ]]; then
        log "  force re-downloading $f (vbmeta fix)..."
        rm -f "$LOCAL_WORK_DIR/$f"
    fi
    # Force re-download logical partition images (system/product/system_ext/vendor/
    # vendor_dlkm/system_dlkm). These are rebuilt on every code change and the local
    # cache from a prior flash will be STALE, causing the old (broken) system image to
    # be flashed. Bootloader/radio/boot images are large and rarely change, so keep
    # caching for those.
    case "$f" in
        # Always refresh full boot chain + logicals + super + AVB key. Skipping
        # vendor_kernel_boot / dtbo / pvmfw after "keep cache" left rango with
        # mismatched companions vs freshly downloaded boot/vendor_boot
        # (G → fastboot). Skipping super.img left a prior stamp's metadata
        # while system*.img were refreshed (bisect mismatch).
        system.img|system_ext.img|product.img|vendor.img|vendor_dlkm.img|system_dlkm.img|super.img|super_empty.img|vbmeta.img|boot.img|init_boot.img|vendor_boot.img|vendor_kernel_boot.img|dtbo.img|pvmfw.img|avb_pkmd.bin|init.insmod.akita.cfg|init.insmod.komodo.cfg|init.insmod.rango.cfg|init.insmod.caiman.cfg|init.insmod.comet.cfg|init.insmod.tegu.cfg|init.insmod.stallion.cfg|init.insmod.shiba.cfg|init.insmod.husky.cfg|init.insmod.frankel.cfg|init.insmod.blazer.cfg|init.insmod.mustang.cfg|init.insmod.tangorpro.cfg)
            log "  force re-downloading $f (logical/boot/vbmeta/super/insmod — always fresh)..."
            rm -f "$LOCAL_WORK_DIR/$f"
            ;;
    esac
    if [[ -f "$LOCAL_WORK_DIR/$f" ]]; then
        log "  $f already present, skipping download"
        continue
    fi
    log "  downloading $f..."
    # Optional images may be legitimately absent from a given bundle (e.g. the
    # stock-control bundle ships no super.img / no vendor_boot_diag.img). Warn
    # and skip rather than die so the flash can proceed with what's present.
    if [[ "$f" == "super.img" || "$f" == "vendor_boot_diag.img" ]]; then
        scp -q "$REMOTE_HOST:$REMOTE_BUILD_DIR/$f" "$LOCAL_WORK_DIR/$f" 2>/dev/null \
            || { warn "optional $f not on server — skipping"; continue; }
    elif [[ "$f" == "avb_pkmd.bin" ]]; then
        scp -q "$REMOTE_HOST:$REMOTE_KEY_DIR/$f" "$LOCAL_WORK_DIR/$f" \
            || die "failed to download $f from $REMOTE_KEY_DIR"
    else
        scp -q "$REMOTE_HOST:$REMOTE_BUILD_DIR/$f" "$LOCAL_WORK_DIR/$f" \
            || die "failed to download $f"
    fi
done
log "All images downloaded ✓"

# Verify all files exist (skip optional ones that may be intentionally absent)
for f in "${ALL_DOWNLOADS[@]}"; do
    if [[ "$f" == "super.img" || "$f" == "vendor_boot_diag.img" ]]; then
        [[ -f "$LOCAL_WORK_DIR/$f" ]] || warn "optional $f absent — continuing without it"
        continue
    fi
    [[ -f "$LOCAL_WORK_DIR/$f" ]] || die "$f missing after download!"
done

# -----------------------------------------------------------------------------
# Step 2 — Flash bootloader (both slots) + radio + GrapheneOS firmware cleanup
# -----------------------------------------------------------------------------
step "2/8  Flash bootloader (A/B) + radio + AVB key + firmware cleanup"

# Dual-slot bootloader (GrapheneOS flash-all) — required for tokay/akita/rango.
flash_bootloader_ab_both_slots

# T-FLASH-REMOTE-TANGORPRO: tangorpro has NO radio hardware, so there is no
# baseband step at all — neither RADIO_MODE=flash nor RADIO_MODE=erase has a
# subject. This is an ABSENCE, not a failure: the device is not being asked to
# do something it cannot do, the step simply does not apply. Announced loudly so
# the missing step in the log is explained rather than looking like a skip bug.
if ! has_radio_hardware "${FLASH_DEVICE:-}"; then
    log "${FLASH_DEVICE}: NO radio hardware (DEC-PORT-TANGORPRO-003) — baseband step SKIPPED."
    log "  no radio.img in the bundle; no 'radio' partition to flash or erase."
    if [[ "$RADIO_MODE" == "erase" ]]; then
        log "  RADIO_MODE=erase is a no-op here: baseband firmware is never installed on this device."
    fi
    log "Rebooting to fastboot after bootloader step (no radio step on this device)..."
    "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    wait_for_fastboot "after bootloader" "$FASTBOOT_WAIT_SECS" \
        || die "device lost after bootloader step"
else

# T-EXCISE-FW-RADIO: baseband firmware step. Default 'flash' is byte-identical
# to the pre-card path; 'erase' skips radio.img and clears the `radio`
# partition instead (baseband firmware NOT installed). The reboot + wait below
# is unchanged in BOTH modes so the boot-chain sequence (G7) is preserved.
case "$RADIO_MODE" in
    flash)
        log "Flashing radio..."
        "$FASTBOOT" flash radio "$LOCAL_WORK_DIR/radio.img" \
            || die "failed to flash radio"
        ;;
    erase)
        log "RADIO_MODE=erase — NOT flashing radio.img; erasing baseband firmware (radio partition)..."
        "$FASTBOOT" erase radio \
            || die "failed to erase radio (RADIO_MODE=erase)"
        log "radio partition erased ✓ (baseband firmware NOT installed)"
        ;;
esac
log "Rebooting to fastboot after radio step (GrapheneOS flash-all)..."
"$FASTBOOT" reboot-bootloader 2>/dev/null || true
wait_for_fastboot "after radio" "$FASTBOOT_WAIT_SECS" \
    || die "device lost after radio step"

fi

# AVB custom key — official position: immediately after radio, BEFORE OS
# images (generate-factory-images-common.sh: erase avb_custom_key → flash
# avb_custom_key avb_pkmd.bin). Loud on failure: without it verified boot
# cannot trust GuardTalkOS keys (vbmeta disable flags are still applied).
[[ -f "$LOCAL_WORK_DIR/avb_pkmd.bin" ]] || die "avb_pkmd.bin missing at $LOCAL_WORK_DIR"
log "Erase + flash avb_custom_key (GrapheneOS official position — before OS images)..."
"$FASTBOOT" erase avb_custom_key \
    || warn "erase avb_custom_key failed (non-fatal — may not exist on some bootloaders)"
if "$FASTBOOT" flash avb_custom_key "$LOCAL_WORK_DIR/avb_pkmd.bin"; then
    log "avb_custom_key flashed ✓"
else
    if [[ "${ALLOW_AVB_KEY_FAIL:-0}" == "1" ]]; then
        warn "avb_custom_key flash FAILED — ALLOW_AVB_KEY_FAIL=1; continuing (vbmeta disable flags still applied)"
    else
        die "avb_custom_key flash FAILED — GuardTalkOS AVB key NOT trusted. Set ALLOW_AVB_KEY_FAIL=1 to continue anyway."
    fi
fi

# UART / FIPS / DPM — cite script/generate-release.sh device flags.
apply_grapheneos_firmware_cleanup

# Re-query slot (A/B dance + radio reboot may have changed it)
CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
TARGET_SLOT="$CURRENT_SLOT"
log "current-slot after bootloader/radio/cleanup: ${CURRENT_SLOT:-unknown}"

# -----------------------------------------------------------------------------
# Step 3 — Wipe userdata + metadata
# -----------------------------------------------------------------------------
step "3/8  Wipe userdata + metadata"

# CRITICAL: userdata wipe is REQUIRED for first-boot defaults (launcher
# workspace, setup wizard) to apply. Without it, the old launcher database
# persists and the new home-layout overlay never takes effect.
log "Wiping userdata..."
"$FASTBOOT" erase userdata \
    || die "userdata erase failed. The launcher home-layout overlay will NOT apply without a clean wipe. Manual fix: fastboot -w"
log "Wiping metadata..."
"$FASTBOOT" erase metadata \
    || warn "metadata erase failed (may not be present on all devices — non-fatal)"

if [[ -n "${CURRENT_SLOT:-}" ]]; then
    log "Resetting active slot to $CURRENT_SLOT (restores slot-retry-count)..."
    "$FASTBOOT" --set-active="$CURRENT_SLOT" 2>/dev/null \
        || warn "set-active failed (continuing)"
fi

# -----------------------------------------------------------------------------
# Step 4 — Enter fastbootd (BEFORE flashing GuardTalk boot images)
# -----------------------------------------------------------------------------
step "4/8  Enter fastbootd (userspace) — before GuardTalk boot flash"

# fastbootd is REQUIRED to wipe-super + flash logical partitions. It is a
# userspace binary reached via `fastboot reboot fastboot`, which boots the
# *currently installed* boot/init_boot/vendor_boot chain. If we flash
# GuardTalk boot first and that chain dies at the Google G logo (laguna),
# fastbootd never starts and system/vendor are never updated → permanent loop.
#
# Order fix: enter fastbootd with the boot chain already on the device (or
# stock rescue on laguna), flash logical, THEN flash GuardTalk boot + vbmeta.

wait_for_fastbootd() {
    local label="${1:-fastbootd}"
    local max_secs="${2:-$FASTBOOTD_WAIT_SECS}"
    local attempts=$(( (max_secs + 1) / 2 ))
    local i FB_MODE
    log "Waiting for fastbootd [$label] (up to ${max_secs}s)..."
    for i in $(seq 1 "$attempts"); do
        sleep 2
        FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
        DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
        if [[ -n "$DEVICES" && "$FB_MODE" == "yes" ]]; then
            log "fastbootd ready after ${i} attempts (is-userspace=yes) [$label]"
            return 0
        fi
        # If device fell back to bootloader (G-logo reboot), stop waiting early.
        if [[ -n "$DEVICES" && "$FB_MODE" == "no" && "$i" -ge 5 ]]; then
            warn "Device back in bootloader (is-userspace=no) — fastbootd boot failed [$label]"
            return 1
        fi
        [[ $((i % 5)) -eq 0 ]] && log "  still waiting for fastbootd... (${i}/${attempts}) [is-userspace=${FB_MODE:-unknown}]"
    done
    return 1
}

ensure_in_bootloader() {
    local FB_MODE
    FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
    DEVICES="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES" && "$FB_MODE" != "yes" ]]; then
        return 0
    fi
    # Device missing or stuck in fastbootd — try reboot-bootloader / wait.
    if [[ -n "$DEVICES" && "$FB_MODE" == "yes" ]]; then
        log "Currently in fastbootd — rebooting to bootloader..."
        "$FASTBOOT" reboot-bootloader 2>/dev/null || true
    fi
    wait_for_fastboot "ensure bootloader" 60 \
        || die "Could not get device into bootloader. Hold vol-down + power, then re-run."
}

# Downloads stock rescue imgs into LOCAL_WORK_DIR/<device>-rescue.
# Sets RESCUE_LOCAL (does not print the path — logs are on stderr).
download_rescue_boot() {
    local dest="$LOCAL_WORK_DIR/${FLASH_DEVICE:-device}-rescue"
    local f
    [[ -n "${REMOTE_RESCUE_DIR:-}" ]] \
        || die "REMOTE_RESCUE_DIR unset — cannot download stock rescue boot for '${FLASH_DEVICE:-unknown}'"
    mkdir -p "$dest"
    log "Downloading stock factory rescue boot for ${FLASH_DEVICE:-device} from $REMOTE_RESCUE_DIR ..."
    for f in "${RESCUE_IMGS[@]}"; do
        log "  rescue: $f"
        scp -q "$REMOTE_HOST:$REMOTE_RESCUE_DIR/$f" "$dest/$f" \
            || die "failed to download rescue $f from $REMOTE_RESCUE_DIR"
        [[ -f "$dest/$f" ]] || die "rescue file missing after scp: $dest/$f"
    done
    RESCUE_LOCAL="$dest"
    log "Rescue imgs ready in $RESCUE_LOCAL"
}

# T-FLASH-REMOTE-TANGORPRO: download tangorpro's stock boot chain.
# releases/desktop-flash/tangorpro-stock-boot ships SIX images and NO vbmeta.img
# (README-STOCK-BOOT.md), so download_rescue_boot's RESCUE_IMGS list cannot be
# reused — it would die on a missing vbmeta.img. Only the four boot-chain images
# the proven flasher (flash-tangorpro.sh §4b) actually writes are fetched.
TANGORPRO_STOCK_IMGS=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img)
download_tangorpro_stock_boot() {
    local dest="$LOCAL_WORK_DIR/${FLASH_DEVICE:-tangorpro}-stock-boot"
    local f
    [[ -n "${REMOTE_STOCK_BOOT_DIR:-}" ]] \
        || die "REMOTE_STOCK_BOOT_DIR unset — cannot download the stock boot chain needed to reach fastbootd on '${FLASH_DEVICE:-tangorpro}'"
    mkdir -p "$dest"
    log "Downloading STOCK boot chain for ${FLASH_DEVICE:-tangorpro} from $REMOTE_STOCK_BOOT_DIR ..."
    for f in "${TANGORPRO_STOCK_IMGS[@]}"; do
        log "  stock: $f"
        scp -q "$REMOTE_HOST:$REMOTE_STOCK_BOOT_DIR/$f" "$dest/$f" \
            || die "failed to download stock $f from $REMOTE_STOCK_BOOT_DIR"
        [[ -f "$dest/$f" ]] || die "stock file missing after scp: $dest/$f"
    done
    TANGORPRO_STOCK_LOCAL="$dest"
    log "Stock boot chain ready in $TANGORPRO_STOCK_LOCAL"
}

# Flash the stock chain so `reboot fastboot` can start fastbootd.
# Order is the proven one (flash-tangorpro.sh §4b): the four boot-chain images,
# no vbmeta — the stock chain is only a vehicle to reach fastbootd and is
# REPLACED by the GuardTalk chain at step 6, so its AVB state is irrelevant
# here (verification is already disabled by then on an unlocked device).
flash_tangorpro_stock_boot_chain() {
    local dest slot f part
    download_tangorpro_stock_boot
    dest="${TANGORPRO_STOCK_LOCAL:?tangorpro stock dir unset}"
    slot="${CURRENT_SLOT:-a}"
    log "Flashing STOCK boot chain (slot $slot) so fastbootd can start..."
    for f in "${TANGORPRO_STOCK_IMGS[@]}"; do
        part="${f%.img}"
        [[ -f "$dest/$f" ]] || die "stock image missing: $dest/$f"
        log "  stock flash $part (slot $slot) ← $dest/$f"
        "$FASTBOOT" --slot "$slot" flash "$part" "$dest/$f" \
            || die "stock flash $part failed"
    done
    "$FASTBOOT" --set-active="$slot" 2>/dev/null || true
    log "Stock boot chain ready ✓ (fastbootd will start from it)"
}

# Temporarily flash stock factory boot so `reboot fastboot` can reach fastbootd.
flash_rescue_boot_chain() {
    local dest slot f part
    download_rescue_boot
    dest="${RESCUE_LOCAL:?rescue local dir unset}"
    slot="${CURRENT_SLOT:-a}"
    log "Flashing STOCK rescue boot chain (slot $slot) to enter fastbootd..."
    for f in boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img; do
        part="${f%.img}"
        [[ -f "$dest/$f" ]] || die "rescue image missing: $dest/$f"
        log "  rescue flash $part (slot $slot) ← $dest/$f"
        "$FASTBOOT" --slot "$slot" flash "$part" "$dest/$f" \
            || die "rescue flash $part failed"
    done
    log "  rescue flash dtbo ← $dest/dtbo.img"
    "$FASTBOOT" flash dtbo "$dest/dtbo.img" || die "rescue flash dtbo failed"
    # Disable verity/verification so rescue boot is not rejected on unlocked GT keys.
    flash_vbmeta_img vbmeta "$dest/vbmeta.img" --slot "$slot"
    flash_vbmeta_img vbmeta_system "$dest/vbmeta.img"
    flash_vbmeta_img vbmeta_vendor "$dest/vbmeta.img"
    "$FASTBOOT" --set-active="$slot" 2>/dev/null || true
    log "Rescue boot chain ready ✓"
}

# Automatic boot-failure harvest (RQ5 one-click): breadcrumbs while still in the
# bootloader, then reflash the stock rescue chain, boot recovery, pull the failed
# boot's console from pstore (ramoops), and print the discriminator lines that
# name the failing component. Ends with the device back in the bootloader, ready
# for the next flash. Disable with AUTO_HARVEST=0 (recovery part: AUTO_RECOVERY_HARVEST=0).
auto_harvest_on_failure() {
    if [[ "${AUTO_HARVEST:-1}" != "1" ]]; then
        log "AUTO_HARVEST=0 — skipping automatic harvest"
        return 0
    fi
    HARVEST_DIR="$LOCAL_WORK_DIR/harvest-${FLASH_DEVICE:-device}-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$HARVEST_DIR"
    log "Auto-harvest → $HARVEST_DIR"

    # 1. Bootloader-resident captures (device is already in fastboot; RAM intact).
    "$FASTBOOT" oem dmesg > "$HARVEST_DIR/oem-dmesg.txt" 2>&1 || true
    "$FASTBOOT" oem ramdump klog > "$HARVEST_DIR/oem-ramdump-klog.txt" 2>&1 || true
    local f
    for f in command status recovery stage; do
        "$FASTBOOT" oem bcd read "$f" > "$HARVEST_DIR/bcd-$f.txt" 2>&1 || true
    done
    log "  breadcrumbs captured (oem dmesg / ramdump klog / bcd ×4)"

    # Print oem-dmesg discriminator immediately — this is the useful signal.
    if [[ -s "$HARVEST_DIR/oem-dmesg.txt" ]]; then
        grep -E 'Reboot mode|AB Decisions|exitcode|0xbaba|fastboot enter|0xfc|0x7f00|0x00000100|Attempted to kill' \
            "$HARVEST_DIR/oem-dmesg.txt" > "$HARVEST_DIR/oem-discriminator.txt" 2>/dev/null || true
        if [[ -s "$HARVEST_DIR/oem-discriminator.txt" ]]; then
            warn "=== OEM-DMESG DISCRIMINATOR ==="
            while IFS= read -r line; do warn "  $line"; done < "$HARVEST_DIR/oem-discriminator.txt"
            warn "=== end (full: $HARVEST_DIR/oem-dmesg.txt) ==="
        fi
    fi

    # 1b. Best-effort upload of the harvest to the build host (T-PORT-HARVEST-UPLOAD).
    # Rationale: the one-line discriminator above is only actionable if the FULL
    # log is readable where the build tree lives. Without this, every failure
    # forces a manual scp round-trip from the Operator's laptop before any agent
    # can analyse it. Never fatal — a failed upload must not abort the summary.
    if [[ -n "${REMOTE_HOST:-}" && -n "${REMOTE_TREE:-}" ]]; then
        local _hup_dest="${REMOTE_TREE}/runtime/harvests"
        if ssh -n "$REMOTE_HOST" "mkdir -p '$_hup_dest'" >/dev/null 2>&1 \
           && scp -q -r "$HARVEST_DIR" "$REMOTE_HOST:$_hup_dest/" >/dev/null 2>&1; then
            log "  harvest uploaded → $REMOTE_HOST:$_hup_dest/$(basename "$HARVEST_DIR")"
        else
            warn "  harvest upload failed — logs are local only at $HARVEST_DIR"
        fi
    fi

    # 2. Ramoops needs a kernel boot that extracts pstore — stock recovery via
    # the rescue chain is the reliable vehicle (fastbootd has no dmesg/pstore path).
    # Laguna family widened in T-PORT-LAGUNA-HYBRID (R4): a failed laguna boot
    # previously yielded no kernel log at all. akita keeps its pre-existing arm.
    case "${FLASH_DEVICE:-}" in
        akita|rango|frankel|blazer|mustang) : ;;
        # T-FLASH-STALLION-RESCUE-PROFILE: stallion was absent from this arm, so a
        # failed boot yielded only bootloader-side `oem dmesg` and no kernel log.
        # The 2026-11-09 stallion boot failure (Reboot mode 0xfc, is-userspace=no,
        # AB Decisions 11111111 = apexd-bootstrap reboot_on_failure) could not be
        # diagnosed for exactly that reason. stallion is zumapro, NOT laguna, so
        # the is_laguna_device/AUTO_RECOVERY_HARVEST default below does not
        # suppress it — verified against is_laguna_device() at ~line 1091, whose
        # arm is rango|frankel|blazer|mustang only.
        stallion) : ;;
        *)
            warn "no rescue profile for '${FLASH_DEVICE:-unknown}' — skipping pstore harvest"
            return 0
            ;;
    esac
    # laguna production ABL (rango|frankel|blazer|mustang): oem bcd write is
    # accepted but NOT honored. Recovery harvest parks the phone on "No command"
    # until Power+VolUp. oem-dmesg already classifies 0xfc / 0x7f00 / 0x100.
    # Default skip for the WHOLE laguna platform (widening the harvest without
    # this guard would trade one bad state for another). Opt in:
    # AUTO_RECOVERY_HARVEST=1
    if is_laguna_device "${FLASH_DEVICE:-}"; then
        AUTO_RECOVERY_HARVEST="${AUTO_RECOVERY_HARVEST:-0}"
    fi
    if [[ "${AUTO_RECOVERY_HARVEST:-1}" != "1" ]]; then
        log "AUTO_RECOVERY_HARVEST=0 — skipping recovery pstore pull (device stays in fastboot)"
        return 0
    fi
    # Subshell: a die inside the rescue flash must not abort the harvest summary.
    if ! ( flash_rescue_boot_chain ) >>"$HARVEST_DIR/rescue-reflash.log" 2>&1; then
        warn "rescue reflash failed (see $HARVEST_DIR/rescue-reflash.log) — skipping pstore"
        return 1
    fi
    log "  rescue chain reflashed — booting recovery for pstore pull"
    "$FASTBOOT" oem bcd write command boot-recovery >>"$HARVEST_DIR/bcd-write.log" 2>&1 || true
    "$FASTBOOT" reboot >>"$HARVEST_DIR/reboot.log" 2>&1 || true

    # 3. Wait for recovery adbd (no USB-debugging authorization needed in recovery).
    local i secs="${RECOVERY_ADB_WAIT_SECS:-120}"
    local got_adb=""
    for ((i=1; i<=secs; i++)); do
        sleep 1
        if "$ADB" devices 2>/dev/null | grep -Eq '[[:space:]](device|recovery|sideload)$'; then
            got_adb=1
            break
        fi
        # Rescue chain + GT super may itself 0xfc back to the bootloader — stop early.
        if [[ -n "$("$FASTBOOT" devices 2>/dev/null)" ]]; then
            local fb_mode
            fb_mode="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
            if [[ "$fb_mode" == "no" && $i -ge 20 ]]; then
                warn "rescue boot returned to bootloader — BCB recovery entry not honored."
                warn "MANUAL: buttons → Recovery mode → 'No command' → Power+VolUp, then:"
                warn "  $ADB shell 'cat /sys/fs/pstore/console-ramoops-0' | tee $HARVEST_DIR/console-ramoops-0.txt"
                return 1
            fi
        fi
        [[ $((i % 20)) -eq 0 ]] && log "  still waiting for recovery adb... (${i}/${secs}s)"
    done
    if [[ -z "$got_adb" ]]; then
        warn "no recovery adb within ${secs}s. MANUAL: Recovery mode (buttons), then:"
        warn "  $ADB shell 'cat /sys/fs/pstore/console-ramoops-0' | tee $HARVEST_DIR/console-ramoops-0.txt"
        return 1
    fi

    # 4. Pull pstore (recovery adbd is root on userdebug; `adb root` is a no-op otherwise).
    "$ADB" root >/dev/null 2>&1 || true
    sleep 2
    "$ADB" wait-for-device >/dev/null 2>&1 || true
    "$ADB" shell 'ls -la /sys/fs/pstore/' > "$HARVEST_DIR/pstore-ls.txt" 2>&1 || true
    "$ADB" shell 'cat /sys/fs/pstore/console-ramoops-0 2>/dev/null' > "$HARVEST_DIR/console-ramoops-0.txt"
    "$ADB" shell 'cat /sys/fs/pstore/dmesg-ramoops-0 2>/dev/null' > "$HARVEST_DIR/dmesg-ramoops-0.txt"
    "$ADB" shell 'cat /sys/fs/pstore/pmsg-ramoops-0 2>/dev/null' > "$HARVEST_DIR/pmsg-ramoops-0.txt"
    "$ADB" shell 'mkdir -p /m && mount -t ext4 /dev/block/bootdevice/by-name/metadata /m 2>/dev/null && ls -laR /m/apex 2>/dev/null' \
        > "$HARVEST_DIR/metadata-apex.txt" 2>&1 || true
    log "  pstore pulled → $HARVEST_DIR"

    # 5. Discriminator scan (RQ4): name the failing component if the console has it.
    if [[ -s "$HARVEST_DIR/console-ramoops-0.txt" ]]; then
        grep -Ei 'Failed to activate|Loop device|loop-control|Coldboot|cold_boot|avc: denied|apexd|panic|Attempted to kill init|reboot_on_failure|bootstrap-apexd' \
            "$HARVEST_DIR/console-ramoops-0.txt" > "$HARVEST_DIR/discriminator.txt" 2>/dev/null || true
        if [[ -s "$HARVEST_DIR/discriminator.txt" ]]; then
            warn "=== DISCRIMINATOR LINES (failed boot console) ==="
            while IFS= read -r line; do warn "  $line"; done < "$HARVEST_DIR/discriminator.txt"
            warn "=== end discriminator (full console: $HARVEST_DIR/console-ramoops-0.txt) ==="
        else
            warn "console captured; no apexd/loop/avc lines matched — inspect $HARVEST_DIR/console-ramoops-0.txt"
        fi
    else
        warn "console-ramoops-0 EMPTY — ramoops did not survive the ABL handoff."
        warn "Next evidence path: UART — fastboot oem uart enable + USB-serial (115200 8N1)."
    fi

    # 6. Leave the device in the bootloader, ready for the next one-command flash.
    "$ADB" reboot bootloader >/dev/null 2>&1 || true
    sleep 5
    return 0
}

# -----------------------------------------------------------------------------
# Opt-in post-flash debug capture (CAPTURE_LOGS=1) — best-effort, never fatal.
# -----------------------------------------------------------------------------
# Mirrors auto_harvest_on_failure's timestamped-dir pattern, but is also safe to
# run on a boot that briefly succeeds (the observed failure is: adb appears,
# then the device falls back to fastboot seconds later). Nothing here may die()
# — a failed capture step logs a warning and continues (Law 3 / Law 9). Callers
# guard on CAPTURE_LOGS, and capture_dir_init is a no-op when not opted in, so
# the default flash path never invokes capture.
capture_dir_init() {
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0
    [[ -n "${CAPTURE_DIR:-}" ]] && return 0
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)"
    CAPTURE_DIR="$LOCAL_WORK_DIR/flash-capture-${FLASH_DEVICE:-device}-${stamp}"
    if mkdir -p "$CAPTURE_DIR" 2>/dev/null; then
        log "CAPTURE_LOGS=1 — post-flash debug evidence → $CAPTURE_DIR"
    else
        warn "could not create capture dir '$CAPTURE_DIR' — capture disabled for this run"
        CAPTURE_DIR=""
    fi
    return 0
}

# capture_run <outfile> <cmd...>: run one capture step; never fatal.
capture_run() {
    local outfile="$1"
    shift
    [[ -n "${CAPTURE_DIR:-}" ]] || return 0
    if { "$@" ; } >"$outfile" 2>&1; then
        return 0
    fi
    warn "capture: '$*' failed (non-fatal; partial output in $(basename "$outfile"))"
    return 0
}

# Bootloader transport: oem dmesg, BCB reads, slot retry/unbootable, getvar all.
capture_fastboot_snapshot() {
    local label="${1:-fastboot}"
    local f
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0
    capture_dir_init
    [[ -n "${CAPTURE_DIR:-}" ]] || return 0
    log "  capture[$label]: fastboot/bootloader transport"
    capture_run "$CAPTURE_DIR/fastboot-$label-oem-dmesg.txt" "$FASTBOOT" oem dmesg
    for f in command status recovery stage; do
        capture_run "$CAPTURE_DIR/fastboot-$label-bcd-$f.txt" "$FASTBOOT" oem bcd read "$f"
    done
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-retry-count-a.txt" "$FASTBOOT" getvar slot-retry-count:a
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-unbootable-a.txt" "$FASTBOOT" getvar slot-unbootable:a
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-retry-count-b.txt" "$FASTBOOT" getvar slot-retry-count:b
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-slot-unbootable-b.txt" "$FASTBOOT" getvar slot-unbootable:b
    capture_run "$CAPTURE_DIR/fastboot-$label-getvar-all.txt" "$FASTBOOT" getvar all
    capture_run "$CAPTURE_DIR/fastboot-$label-devices.txt" "$FASTBOOT" devices
    log "  capture[$label]: fastboot snapshot done"
    return 0
}

# Android transport: logcat, props, dumpsys, pstore. Logcat is captured first
# so a subsequent adbd reset cannot lose the interesting window.
capture_adb_snapshot() {
    local label="${1:-adb}"
    local prop f
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0
    capture_dir_init
    [[ -n "${CAPTURE_DIR:-}" ]] || return 0
    if ! "$ADB" shell true >/dev/null 2>&1; then
        warn "  capture[$label]: adb not reachable — skipping adb snapshot"
        return 0
    fi
    log "  capture[$label]: adb/Android transport"
    capture_run "$CAPTURE_DIR/adb-$label-logcat-d.txt" "$ADB" logcat -d
    capture_run "$CAPTURE_DIR/adb-$label-logcat-errors.txt" "$ADB" logcat -d '*:E'
    : >"$CAPTURE_DIR/adb-$label-getprop-key.txt" 2>/dev/null || true
    for prop in \
        ro.build.type ro.build.tags ro.debuggable ro.boot.verifiedbootstate \
        ro.boot.slot_suffix ro.boot.bootreason ro.product.device \
        ro.guardtalk.build ro.guardtalk.version; do
        {
            echo "### $prop"
            "$ADB" shell getprop "$prop" 2>&1 || true
        } >>"$CAPTURE_DIR/adb-$label-getprop-key.txt" 2>&1 || true
    done
    capture_run "$CAPTURE_DIR/adb-$label-getprop-all.txt" "$ADB" shell getprop
    capture_run "$CAPTURE_DIR/adb-$label-dumpsys-exit-info.txt" "$ADB" shell dumpsys activity exit-info
    capture_run "$CAPTURE_DIR/adb-$label-dumpsys-lastanr.txt" "$ADB" shell dumpsys activity lastanr
    capture_run "$CAPTURE_DIR/adb-$label-dumpsys-services.txt" "$ADB" shell dumpsys -l
    capture_run "$CAPTURE_DIR/adb-$label-pstore-ls.txt" "$ADB" shell ls -la /sys/fs/pstore/
    for f in console-ramoops-0 dmesg-ramoops-0 pmsg-ramoops-0; do
        capture_run "$CAPTURE_DIR/adb-$label-$f.txt" "$ADB" shell cat "/sys/fs/pstore/$f"
    done
    log "  capture[$label]: adb snapshot done"
    return 0
}

# laguna (rango|frankel|blazer|mustang): NEVER try the on-device boot chain
# first. After a failed GuardTalk flash it is often a G-logo reboot loop;
# `reboot fastboot` just restarts that loop and the script appears stuck.
# Always install stock factory rescue boot first, then enter fastbootd, flash
# logical, and only then install GuardTalk boot.
case "${FLASH_DEVICE:-}" in
    rango|frankel|blazer|mustang)
    log "${FLASH_DEVICE}: flashing STOCK rescue boot BEFORE fastbootd (avoids G-logo loop from prior GT boot)..."
    ensure_in_bootloader
    CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
    TARGET_SLOT="$CURRENT_SLOT"
    flash_rescue_boot_chain
    log "Rebooting to fastbootd with stock rescue boot..."
    log "(Screen may show Google G briefly — should land in fastbootd, not loop.)"
    "$FASTBOOT" reboot fastboot 2>/dev/null || true
    wait_for_fastbootd "${FLASH_DEVICE}-rescue" "$FASTBOOTD_WAIT_SECS" \
        || die "FAILED to enter fastbootd with stock rescue boot.
Hold vol-down+power for bootloader, then:
  scp $REMOTE_HOST:$REMOTE_RESCUE_DIR/{boot,init_boot,vendor_boot,vendor_kernel_boot,dtbo,vbmeta,pvmfw}.img .
  fastboot --slot a flash boot boot.img
  fastboot --slot a flash init_boot init_boot.img
  fastboot --slot a flash vendor_boot vendor_boot.img
  fastboot --slot a flash vendor_kernel_boot vendor_kernel_boot.img
  fastboot --disable-verity --disable-verification --slot a flash vbmeta vbmeta.img
  fastboot reboot fastboot
  # when is-userspace=yes, re-run this script"
    ;;
    # T-FLASH-REMOTE-TANGORPRO: tangorpro takes the SAME "stock chain first" shape
    # as laguna, but for a different and stronger reason — it is not a rescue from
    # a bad prior flash, it is the mandatory first phase every time. Fastbootd is
    # a USERSPACE binary reached by `fastboot reboot fastboot`, which boots the
    # CURRENTLY INSTALLED chain; the six logical partitions exist ONLY in
    # fastbootd. GuardTalk's tangorpro boot chain has no on-device boot proof, so
    # installing it before fastbootd is the exact failure this arm avoids.
    # Proven ordering (releases/desktop-flash/*/flash-tangorpro.sh:260-300):
    #   stock boot chain -> wipe-super -> reboot fastboot -> is-userspace=yes
    #     -> logical -> reboot bootloader -> GuardTalk boot -> avb key -> vbmeta.
    # The wipe-super is done here (step 4), before `reboot fastboot`, exactly as
    # the proven script does; step 5 then writes the logicals.
    tangorpro)
    log "${FLASH_DEVICE}: PHASE 1 — install STOCK boot chain, then reach fastbootd."
    log "  (mandatory: the logical partitions can only be written in fastbootd,"
    log "   and fastbootd boots the chain already on the device)"
    log "  NOTE: avb_custom_key was installed at step 2 (GrapheneOS official position,"
    log "        shared with every other device), i.e. BEFORE this stock chain. The"
    log "        proven flasher installs it after; on an unlocked bootloader with"
    log "        verification disabled both orders boot, and step 7 vbmeta is still"
    log "        the last AVB write. Do not read this as a re-ordering of 4b->4c->4e."
    ensure_in_bootloader
    CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
    TARGET_SLOT="$CURRENT_SLOT"
    flash_tangorpro_stock_boot_chain
    log "Resetting super metadata so the logical partitions exist at the right sizes..."
    [[ -f "$LOCAL_WORK_DIR/super_empty.img" ]] \
        || die "super_empty.img missing at $LOCAL_WORK_DIR — required for dynamic partitions on ${FLASH_DEVICE}"
    "$FASTBOOT" wipe-super "$LOCAL_WORK_DIR/super_empty.img" \
        || die "wipe-super failed on ${FLASH_DEVICE}. Ensure the device is in the BOOTLOADER (not fastbootd), then re-run."
    SUPER_WIPED_IN_PHASE1=1
    log "Rebooting to fastbootd (userspace) from the stock chain..."
    log "(Screen may show Google G briefly — should land in fastbootd, not loop.)"
    "$FASTBOOT" reboot fastboot 2>/dev/null || true
    wait_for_fastbootd "${FLASH_DEVICE}-stock" "$FASTBOOTD_WAIT_SECS" \
        || die "FAILED to enter fastbootd with the STOCK boot chain on ${FLASH_DEVICE}.
The logical partitions (system/system_ext/product/vendor/vendor_dlkm/system_dlkm)
CANNOT be written from the bootloader, so this run cannot continue.
Recover the stock chain by hand, then re-run:
  scp $REMOTE_HOST:$REMOTE_STOCK_BOOT_DIR/{boot,init_boot,vendor_boot,vendor_kernel_boot}.img .
  fastboot --slot a flash boot boot.img
  fastboot --slot a flash init_boot init_boot.img
  fastboot --slot a flash vendor_boot vendor_boot.img
  fastboot --slot a flash vendor_kernel_boot vendor_kernel_boot.img
  fastboot wipe-super super_empty.img
  fastboot reboot fastboot
  fastboot getvar is-userspace          # must be: yes
Nothing after this point was flashed."
    log "PHASE 1 complete — in fastbootd; step 5 writes the logical partitions."
    ;;
    *)
    log "Rebooting to fastbootd (using boot chain currently on device)..."
    "$FASTBOOT" reboot fastboot 2>/dev/null || true
    if ! wait_for_fastbootd "current-boot" "$FASTBOOTD_WAIT_SECS"; then
        die "FAILED to enter fastbootd. Logical partitions cannot be flashed in bootloader mode.
Device may be boot-looping. Get to bootloader (vol-down+power) and re-run.
Restore a working boot image first if needed."
    fi
    ;;
esac

# -----------------------------------------------------------------------------
# Step 5 — Flash logical partitions (super) via fastbootd
# -----------------------------------------------------------------------------
step "5/8  Flash logical partitions (super) via fastbootd"

FB_MODE="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
[[ "$FB_MODE" == "yes" ]] || die "Not in fastbootd (is-userspace=${FB_MODE:-unknown}) — aborting logical flash"

# Preferred: flash the canonical super.img built by lpmake. Its metadata table
# exactly matches the GT logical images, so first-stage init's liblp can build
# the dm-linear devices and mount /system. Flashing 6 logical partitions
# individually after wipe-super leaves fastbootd-generated metadata that the
# (factory) first-stage init could not resolve -> /system never mounted ->
# execv(/system/bin/init) failed with ENOENT -> "kill init! exitcode=0x7f00".
if [[ -f "$LOCAL_WORK_DIR/super.img" ]]; then
    log "Flashing canonical super.img (lpmake metadata matches GT logical images)..."
    "$FASTBOOT" flash super "$LOCAL_WORK_DIR/super.img" \
        || die "failed to flash super.img"
    log "super.img flashed ✓"
else
    warn "super.img not found in bundle — falling back to wipe-super + per-partition flash"
    # T-FLASH-REMOTE-TANGORPRO: tangorpro wipes super in the BOOTLOADER during
    # phase 1 (step 4), before `reboot fastboot`, exactly as the proven flasher
    # does (flash-tangorpro.sh:305). Re-issuing it here would be a second,
    # redundant metadata reset from userspace. The wipe is not skipped — it has
    # already happened, which is why this is a distinct branch rather than a
    # silent reuse of the generic one. Scoped to the codename (not just the flag)
    # so no other device can ever take this arm.
    if is_tangorpro "${FLASH_DEVICE:-}" && [[ "${SUPER_WIPED_IN_PHASE1:-0}" == "1" ]]; then
        log "super metadata already reset in step 4 (bootloader) — not wiping again in fastbootd"
    else
        log "Wiping super partition..."
        "$FASTBOOT" wipe-super "$LOCAL_WORK_DIR/super_empty.img" \
            || die "wipe-super failed. Ensure fastbootd (is-userspace=yes), then: fastboot wipe-super super_empty.img"
    fi

    for img in "${LOGICAL_IMAGES[@]}"; do
        part="${img%.img}"
        log "  flash $part (logical)"
        "$FASTBOOT" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part"
    done
    log "Logical partitions flashed ✓"
fi

log "Rebooting back to fastboot (bootloader)..."
"$FASTBOOT" reboot-bootloader 2>/dev/null || true
wait_for_fastboot "after logical" 60 \
    || die "device lost when returning to bootloader after logical flash"

CURRENT_SLOT="$("$FASTBOOT" getvar current-slot 2>&1 | grep -m1 '^current-slot:' | awk '{print $2}' || true)"
TARGET_SLOT="$CURRENT_SLOT"
log "current-slot: ${CURRENT_SLOT:-unknown}"

# -----------------------------------------------------------------------------
# Step 6 — Flash GuardTalk physical A/B + dtbo
# -----------------------------------------------------------------------------
step "6/8  Flash GuardTalk boot chain (slot ${TARGET_SLOT:-a}) + dtbo"

if [[ "$GT_BOOT_CHAIN" == "hybrid" ]]; then
    log "GT_BOOT_CHAIN=hybrid — SKIPPING GuardTalk A/B boot-chain flash (step 6)."
    log "  Stock factory rescue boot chain from step 4 stays installed:"
    log "  boot/init_boot/vendor_boot/vendor_kernel_boot/pvmfw/dtbo already on device."
    log "  Hybrid logical set from step 5 is retained; step-7 vbmeta pass still runs."
else
    for img in "${AB_IMAGES[@]}"; do
        part="${img%.img}"
        log "  flash $part (slot ${TARGET_SLOT:-a})"
        "$FASTBOOT" --slot "${TARGET_SLOT:-a}" flash "$part" "$LOCAL_WORK_DIR/$img" \
            || die "failed to flash $part"
    done
    log "  flash dtbo"
    "$FASTBOOT" flash dtbo "$LOCAL_WORK_DIR/dtbo.img" || die "failed to flash dtbo"
    log "GuardTalk boot chain flashed ✓"
fi

# -----------------------------------------------------------------------------
# Step 7 — Single vbmeta pass + set-active
# -----------------------------------------------------------------------------
step "7/8  vbmeta pass (single, after boot chain) + set-active"

log "Flashing vbmeta/vbmeta_system/vbmeta_vendor once (--disable-verity --disable-verification)..."
if [[ -n "${CURRENT_SLOT:-}" ]]; then
    flash_vbmeta_partition vbmeta --slot "$CURRENT_SLOT"
else
    flash_vbmeta_partition vbmeta
fi
# T-FLASH-REMOTE-TANGORPRO: tangorpro's bundle carries ONE vbmeta.img that
# covers the whole chain and has no vbmeta_system/vbmeta_vendor. Those two passes
# are skipped for THAT DEVICE ONLY. Every other device still runs both
# unconditionally, exactly as before — the check is on the codename, not on the
# file's existence, so a 13-device bundle that somehow lost vbmeta_system.img
# still dies at flash_vbmeta_partition instead of silently skipping a chained
# vbmeta pass (that would be a real fail-open).
if is_tangorpro "${FLASH_DEVICE:-}"; then
    for _vpart in vbmeta_system vbmeta_vendor; do
        log "  ${_vpart}: no ${_vpart}.img on ${FLASH_DEVICE} (single-vbmeta device) — chained pass SKIPPED"
    done
    unset _vpart
else
    flash_vbmeta_partition vbmeta_system
    flash_vbmeta_partition vbmeta_vendor
fi

if [[ -n "${CURRENT_SLOT:-}" ]]; then
    log "Setting active slot to $CURRENT_SLOT (resets slot-retry-count)..."
    "$FASTBOOT" --set-active="$CURRENT_SLOT" 2>/dev/null \
        || warn "set-active failed (manual: fastboot --set-active=$CURRENT_SLOT)"
fi

# -----------------------------------------------------------------------------
# Step 8 — Reboot (+ optional insmod push)
# -----------------------------------------------------------------------------
step "8/8  Reboot"

log "Rebooting device..."
"$FASTBOOT" reboot || warn "reboot returned non-zero (device may still be rebooting)"

# Poll for adb (boot OK), unauthorized adb, or return to bootloader (G→fastboot).
# Never fall through into a blind 180s adb wait when the device never enumerates.
BOOT_WATCH_SECS="${BOOT_WATCH_SECS:-120}"
log "Watching boot for up to ${BOOT_WATCH_SECS}s (adb=OK, unauthorized=prompt, fastboot=fail)..."
WATCH_ITERS="$BOOT_WATCH_SECS"
if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
    # Ensure the post-adb fallback window is fully covered even if adb appears late.
    WATCH_ITERS=$((BOOT_WATCH_SECS + CAPTURE_POST_ADB_SECS))
    capture_dir_init
    log "CAPTURE_LOGS=1 — will keep watching up to ${CAPTURE_POST_ADB_SECS}s after adb first appears (fallback capture)"
fi
boot_outcome=""
post_adb_seen=0
post_adb_start=0
post_adb_fallback=0
for i in $(seq 1 "$WATCH_ITERS"); do
    sleep 1
    if command -v "$GT_ADB_BIN" >/dev/null 2>&1; then
        adb_list="$("$ADB" devices 2>/dev/null || true)"
        if echo "$adb_list" | awk 'NR>1 && $2=="device" {found=1} END{exit !found}'; then
            if [[ "$boot_outcome" != "adb" ]]; then
                boot_outcome="adb"
                log "adb online after ${i}s — Android reached"
                if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
                    post_adb_seen=1
                    post_adb_start="$i"
                    capture_adb_snapshot "adb-online-${i}s"
                    log "  CAPTURE_LOGS=1 — watching ${CAPTURE_POST_ADB_SECS}s more for a fallback to fastboot..."
                fi
            fi
            # Default path: exit at first adb (unchanged). Capture mode: keep
            # watching so a later adb → fastboot fallback is recorded.
            if [[ "${CAPTURE_LOGS:-0}" == "1" && "$post_adb_seen" == "1" \
                  && $((i - post_adb_start)) -lt "$CAPTURE_POST_ADB_SECS" ]]; then
                :
            else
                break
            fi
        fi
        if echo "$adb_list" | awk 'NR>1 && $2=="unauthorized" {found=1} END{exit !found}'; then
            boot_outcome="unauthorized"
            log "adb unauthorized after ${i}s — Android up; accept RSA prompt on device"
            break
        fi
        if echo "$adb_list" | awk 'NR>1 && $2=="recovery" {found=1} END{exit !found}'; then
            boot_outcome="recovery"
            log "device in adb recovery after ${i}s"
            break
        fi
    fi
    DEVICES_AFTER="$("$FASTBOOT" devices 2>/dev/null || true)"
    if [[ -n "$DEVICES_AFTER" ]]; then
        FB_MODE_AFTER="$("$FASTBOOT" getvar is-userspace 2>&1 | grep -m1 '^is-userspace:' | awk '{print $2}' || true)"
        if [[ "${FB_MODE_AFTER:-}" != "yes" ]]; then
            sleep 1
            if [[ -n "$("$FASTBOOT" devices 2>/dev/null || true)" ]]; then
                boot_outcome="fastboot"
                log "Device back in fastboot after ${i}s (is-userspace=${FB_MODE_AFTER:-unknown})"
                if [[ "$post_adb_seen" == "1" ]]; then
                    post_adb_fallback=1
                    warn "POST-ADB FALLBACK RECORDED: adb was online at ${post_adb_start}s, device returned to fastboot at ${i}s"
                fi
                if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
                    capture_fastboot_snapshot "fallback-${i}s"
                fi
                break
            fi
        fi
    fi
    [[ $((i % 10)) -eq 0 ]] && log "  still watching boot... (${i}/${WATCH_ITERS}s)"
done

if [[ "${CAPTURE_LOGS:-0}" == "1" && "$post_adb_seen" == "1" \
      && "$post_adb_fallback" == "0" && "$boot_outcome" == "adb" ]]; then
    log "CAPTURE_LOGS=1 — adb stayed up for the ${CAPTURE_POST_ADB_SECS}s post-adb window (no fallback observed)"
fi

if [[ "$boot_outcome" == "fastboot" ]]; then
    warn "Boot failed (G logo → fastboot). Logical partitions ARE flashed."
    warn "Skipping adb init.insmod push — no Android yet."
    warn "IMMEDIATE: restoring slot retries, then AUTOMATIC harvest (rescue → recovery → pstore)..."
    "$FASTBOOT" --set-active=a 2>/dev/null || true
    # One-click harvest: breadcrumbs + failed-boot console via ramoops + verdict lines.
    auto_harvest_on_failure || true
    warn "Classify from oem dmesg (do not invent PASS):"
    warn "  exitcode=0x00007f00     → init/exec kill (status 127; historical)"
    warn "  exitcode=0x00000100     → init exit status 1 (KP; 141438 stockinit class)"
    warn "  Reboot mode: 0xfc       → apexd-bootstrap reboot_on_failure (~18s)"
    warn "  Reboot mode: 0x0 + 0xbaba → Kernel PANIC (normal mode; not bootloader 0xfc)"
    warn "Bisect stamps: keep REMOTE_BUILD_DIR set (do not assume rango-latest)."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS flash INCOMPLETE — boot failure after G"
    echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
    echo "  Remote:   $REMOTE_BUILD_DIR"
    echo "  Harvest:  ${HARVEST_DIR:-<none>} (console-ramoops-0.txt = failed boot)"
    [[ "${CAPTURE_LOGS:-0}" == "1" ]] && echo "  Capture:  ${CAPTURE_DIR:-<none>} (CAPTURE_LOGS=1)"
    echo "  Classes:  0x7f00 | 0x00000100 | 0xfc | 0xbaba/mode 0x0"
    echo "============================================================"
    exit 2
fi

if [[ "$boot_outcome" == "unauthorized" ]]; then
    warn "Android reached but adb unauthorized — accept the prompt, then re-run insmod push or enable USB debugging."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS flash OK (adb unauthorized)"
    echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
    echo "  Remote:   $REMOTE_BUILD_DIR"
    echo "============================================================"
    exit 0
fi

if [[ "$boot_outcome" != "adb" ]]; then
    warn "Neither adb nor fastboot within ${BOOT_WATCH_SECS}s."
    warn "Likely stuck at G/bootanimation (not a script hang). Check the phone screen."
    warn "Skipping adb init.insmod push — will not wait ${ADB_WAIT_SECS}s blindly."
    echo ""
    echo "============================================================"
    echo "  GuardTalkOS flash INCOMPLETE — no adb after reboot"
    echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
    echo "  Remote:   $REMOTE_BUILD_DIR"
    echo "  Tip:      if screen shows Android/SUW, enable USB debugging / accept adb"
    echo "============================================================"
    exit 3
fi

case "${FLASH_DEVICE:-}" in
    akita|komodo|rango|caiman|comet|tegu|stallion|shiba|husky|frankel|blazer|mustang|tangorpro)
        step "8b/8  Install init.insmod.${FLASH_DEVICE}.cfg via adb"
        install_insmod_cfg_via_adb
        ;;
esac

# Final best-effort adb snapshot (capture mode only; never fatal, never pushes).
if [[ "${CAPTURE_LOGS:-0}" == "1" ]]; then
    capture_adb_snapshot "final"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  GuardTalkOS flash complete!"
echo "  Device:   $(device_pretty "$FLASH_DEVICE")"
echo "  Remote:   $REMOTE_BUILD_DIR"
echo "  Work dir: $LOCAL_WORK_DIR"
[[ "${CAPTURE_LOGS:-0}" == "1" ]] && echo "  Capture:  ${CAPTURE_DIR:-<none>} (CAPTURE_LOGS=1)"
echo "  First boot may take a few minutes."
echo "============================================================"
