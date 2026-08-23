# DR-RANGO-10DAY-RCA — Deep Research Report

> Task: DR-RANGO-10DAY-RCA · Architect synthesis · started 2026-08-03
> Status: **COMPLETE** — RQ1 ✓ RQ2 ✓ RQ3 ✓ RQ4 ✓ RQ5 ✓
> Rules: evidence-cited claims only; never invent PASS; falsified list not re-litigated.

## 0. Bound facts (unchanged)

- rango (laguna), unlocked, PROD fuses. Dominant failure: ~18 s G→fastboot,
  `Reboot mode: 0xfc` / `reboot bootloader` / `AB Decisions: 11111111`
  = apexd-bootstrap `reboot_on_failure reboot,bootloader,bootstrap-apexd-failed`.
- One-time alternate: 141438 stockinit → ~61 s KP `exitcode=0x00000100` (`0xbaba`).
- Falsified as SOLE cause (on-device bound): tzdata (130756), stock apexd (132759),
  stock init (141438), stock init.rc (150440), stock hwasan/libc (153335),
  flash-parity (153335).
- `rango-avbcontrol-*` BOOTS AOSP. `rango-fullgt-*` ABL reject (`AB 11311112`).
- `rango-latest` = `rango-20260802-130756` (known FAIL).

---

## RQ1 — Flash-path equivalence ✓ (agent RQ1)

**`out/target/product/rango/fastboot-info.txt` EXISTS** (regenerated per build;
generator `build/make/core/Makefile:5952-6026`):

```
flash boot / init_boot / dtbo / vendor_kernel_boot / pvmfw / vendor_boot
flash --apply-vbmeta vbmeta
reboot fastboot
update-super
flash system / system_dlkm / system_ext / product / vendor / vendor_dlkm
if-wipe erase userdata
if-wipe erase metadata
```

Key semantics of `fastboot -w --skip-reboot update image.zip` (system/core/fastboot):
- android-info.txt requirement gate: board=rango, version-bootloader
  `deepspace-17.1-15016913`, version-baseband `g5400i-251201-260127-B-14784805`,
  partition-exists vendor_kernel_boot — hard fail on mismatch.
- set_active(current) once at start (clears retry counters); **cancels stale OTA
  merge snapshot** (bespoke never does).
- **Optimized super flash**: the `[reboot fastboot, update-super, flash system…]`
  block is pattern-matched and replaced by host-side super assembly from
  `super_empty.img` metadata + logical imgs, flashed **from the bootloader** —
  no fastbootd, no on-device boot chain mid-flow (`task.cpp:151-170,236-250`).
  Fallback `--disable-super-optimization` restores fastbootd path.
- `-w` = erase **+ format** userdata+metadata at END (bespoke: erase-only, BEFORE).
- vbmeta flashed **as-built** (`--apply-vbmeta` rewrites flags only if cmdline
  flags passed; official flash-all passes none).
- **Official never flashes vbmeta_system/vbmeta_vendor** (BOARD gates unset).

Remaining bespoke-only features: rescue boot chain (dead weight when staging
ships factory boot — current default), vbmeta_system/vendor flashes, metadata
erase, init.insmod cfg push, boot-watch/0xfc classification, remote download.

**Verdict RQ1:** hybrid — keep wrapper (steps 0-2 + boot-watch + insmod), replace
steps 3-7 with `fastboot -w --skip-reboot update image-rango-$STAMP.zip`.
Staging needs: copy `fastboot-info.txt` + `android-info.txt` into DEST, then
`zip -j image-rango-$STAMP.zip` with exactly the fastboot-info set
(android-info, fastboot-info, super_empty, boot, init_boot, dtbo,
vendor_kernel_boot, pvmfw, vendor_boot, vbmeta, system, system_dlkm, system_ext,
product, vendor, vendor_dlkm). **Exclude monolithic super.img** (~3.1 GB saved).
Untested residual flash deltas vs 0xfc: erase-only vs format userdata; stale
vbmeta_system/vendor; monolithic-super geometry vs super_empty metadata.

---

## RQ2 — Signing/AVB posture ✓ (agent RQ2)

**NEW DEFECT FOUND — stale recycled vbmeta:**

| Artifact | Evidence |
|---|---|
| All GT stamps ship the SAME vbmeta blob sha1 `886fe7c2…` (044126, 130756, fullgt-072051 identical) | avbtool + sha1sum |
| Signed by **public AOSP testkey** sha1 `2597c218aae470a130f61162feaae70afd97f011` = `external/avb/test/data/testkey_rsa4096.pem` (BOARD_AVB_KEY_PATH unset → `build/core/Makefile:4689-4690` default) | `avbtool extract_public_key` match |
| `avb_pkmd.bin` == `avb_pkmd_testkey.bin` (same testkey pkmd) | sha1/sha256 match |
| **vbmeta descriptors describe fullgt-20260801 boot chain, NOT the payload shipped with them** (boot digest `0ffc2daf…` verifies vs fullgt boot.img, NOT vs 044126/130756 boot.img) | digest check |
| `vbmeta_system.img`/`vbmeta_vendor.img` = **byte-identical dummy copies of vbmeta.img** (no system/vendor descriptors) | sha1 identical |
| `vbmeta_valid_flags3.img` = same blob again; recycled forward from rango-latest/memtagfix2/avbcontrol (`stage-rango-release.sh:933-946,1091-1094`) | staging code |
| Flags = **3** baked into the signed blob → flash-time `--disable-verity --disable-verification` is a **no-op** | avbtool info |
| Real GuardTalk key exists (`~/guardtalk-keys/guardtalk/avb_pkmd.bin` sha1 `7146d3b6…`) but is **never used for rango**; `sign-build.sh` supports rango (tokay-wired) | key inventory |

**Interpretation:** disable-flags aren't masking a bad signature — they're masking
**descriptor staleness + dummy chained vbmetas + world-public testkey trust**.
With flags 3, digests are not verified at boot, so this defect is NOT a plausible
sole cause of the userspace 0xfc class — but it is a real correctness/security
defect, and it invalidates any future flags-0 attempt until rebuilt.

**`AB Decisions: 11311112` decode** (no ABL source; evidence-based from 6 observed
codes + `.agent-comm/completed/rango-flash-mess-20260801/flash-stockboot-gtsystem.sh:4-7`):
nibble 1 = pass/handoff, 3 = reject/fail, 2 = terminal forced-fastboot.
`11311112` = early-stage reject of GT boot chain, retries drained → forced fastboot.
Same class as decoded `31112113` (GT boot → ABL rejects, kernel never starts) vs
`31111122` (stock boot → kernel RUNS). Positional ±1 stage uncertainty.

**Verified-boot-ON impact:** cannot affect userspace 0xfc (post-ABL-handoff).
Mechanically a no-op today (flags 3 already baked). True flags-0 requires rebuilt
vbmeta with correct digests + real chained vbmetas + real GuardTalk key — and
would convert silent boot-chain ambiguity into explicit attributable AVB errors
(evidence-quality win). Caveat: fullgt was ABL-rejected while unlocked, so this
ABL pin enforces something on GT chain regardless.

---

## RQ3 — Ten-day build delta ✓ (agent RQ3)

**HEADLINE: GuardTalkOS has NEVER booted on rango. Onset = port day 2026-07-25
(first stamp `133716`). This is a port-day-on failure, not a regression.**
Only zero-GT stock controls PASS: `rango-20260726-083005` (stock CP1A prove-boot)
and `rango-avbcontrol-20260801-072014` (stock AOSP UI). Port sprint closed
2026-07-25 with device E2E NO-GO/HOLD (`TASK_QUEUE.md:745`,
`docs/qa/Q-PORT-RANGO_EVIDENCE.md:20`).

**Failure-class eras (all 40 stamp dirs tabled in research transcript):**

| Era | Stamps | Class | Exit |
|---|---|---|---|
| Jul 25 | 133716, 160051 | G→fastboot ~21 s boot-chain reject | pvmfw/SPL fix no effect |
| Jul 26 AM | 071147 → 075819, 081334 | bootanim hang (factory BP4A boot) | stock 083005 PASS |
| Jul 26 PM | 083805 | verity-restart G→fastboot | GT Flags:3 vbmeta fixes it |
| Jul 26 PM – Aug 2 AM | 111805, 132029, 145243, 081848, hybrid-060108, 071754, 060841, 093541 (+5 bisect-*, 2 test-*, 2 memtagfix* UNKNOWN) | **KP `0x7f00` ×9 recorded stamps** | — |
| Aug 1 | avbcontrol PASS (stock) / fullgt `072051` | **ABL reject `11311112`** | GT boot chain forbidden |
| Aug 2 PM | 103641 (stockbootstrap: escapes 0x7f00), 111004, 123756, 130756, 132759, 150440, 153335 | **`0xfc` apexd-bootstrap ×7** | survives all single-var grafts |
| Aug 2 | 141438 stockinit | KP `0x00000100` ~61 s (once) | not cured |
| Aug 3 | 044126 stockselinux | UNFLASHED — frontier | — |

**Class only ever CHANGED when stock early-boot components were grafted**
(stockbootstrap→0xfc; stockinit→KP 0x100). `0xfc` survived every single-variable
graft → points past individual binaries to the early-apex environment.

**Git/process finding:** the entire 10-day effort is **uncommitted tree state**.
`vendor/guardtalk` last commit `740f5eb` 2026-07-25 07:15Z ("WORKING VERSION");
all rango artifacts (stage-rango-release.sh, RCA/FIX docs, QA evidence) UNTRACKED;
`script` no commits since 07-04; `device/common` none since ≥07-15; `device/google`,
`build`, `vendor/google_devices`, `kernel` are not git repos here → **no git trail
exists for any rango change**; staging-script evolution reconstructable only from
stamp READMEs. MODE chain: hybrid/avbcontrol/fullgt (08-01) → gtuserspace durable
(08-02 06:08) → stockbootstrap → novirt → novirtstockapex → stock tzdata (durable)
→ stockapexd → stockinit → stockapexcfg → stockhwasan → stockselinux (08-03 04:41).

**130338 do-not-flash:** debugfs write-order bug corrupted runtime (superseded by 130756).

## RQ4 — apexd-bootstrap mechanism ✓ (agent RQ4)

**HEADLINE (changes the RCA): `mount_before_data` is compiled FALSE**
(`out/soong/.intermediates/system/apex/apexd/libapexd_flags/.../com_android_apex_flags.h:8-14`
`#define COM_ANDROID_APEX_FLAGS_MOUNT_BEFORE_DATA false`). Apexd-bootstrap runs the
**legacy path**: never touches `/metadata/apex`, never creates `.apex`-named dm
devices, never waits `cold_boot_done` inside `OnBootstrap`. → `/metadata` staleness
and the `apex_dm_device` file_contexts gap are on **unreachable code paths**.

**Failure path (cited):** `apexd.rc:13-19` (`reboot_on_failure
reboot,bootloader,bootstrap-apexd-failed`) → `exec_start apexd-bootstrap` in
`init.rc:80-86` → legacy `OnBootstrap()` (`apexd.cpp:2327`): scan `/system/apex`
(`AddPreinstalledData`, 2308-2325) + `ActivateApexPackages` (1483-1570,
no revert/fallback) → any single APEX failure = `exit(1)` →
`service.cpp:288-291` → `reboot.cpp:1082-1130` write BCB → bootloader (`0xfc`).
**There is NO init timer** — ~18 s is apexd-bootstrap's own runtime, dominated by
the **unbounded** `WaitForLoopDevice` poll that resets while `ro.cold_boot_done`
is false (`apexd_loop.cpp:450-482`; 20 s `/dev/loop-control` wait at `:304-355`).
→ signature points at the **loop-device/ueventd coldboot handoff**.

**/metadata answer:** erased by flash AND unread on this path → DEAD as cause.
**SELinux:** GT policy lacks `apex_dm_device` (real delta) but the type is only
used by `CreateDmLinearForPayload` (`apexd.cpp:459-461` guard) — unreachable;
bootstrap needs `loop_control_device`/`loop_device`/`dm_device` (`apexd.te:39,41,61`,
all present). A sepolicy denial remains a plausible *mechanism class*, but not
via `apex_dm_device`. The `stockselinux` probe (044126) now tests "some other
sepolicy delta" — expectations reset.

**0xfc vs KP 0x100:** two DIFFERENT failures. GT init → apexd exit(1) →
reboot_on_failure (clean, ~18 s). Stock init → pid-1 clean `exit(1)` with **no
in-source path** in init → most plausibly Bionic linker `__linker_error` →
`_exit(1)` (`bionic/linker/linker_debug.cpp:98-105`) from stock-binary/GT-libs
(HWASAN-flavored) incompatibility, deferred to ~50-55 s into second stage (stock
binary linked and ran; first-stage identical). Asymmetry noted: GT userdebug
builds `-DREBOOT_BOOTLOADER_ON_PANIC=1` (`init/Android.bp:161`).

**Ranked remaining triggers (post-falsification, post-RQ4):**

| # | Candidate | Rank | Confirm/refute |
|---|---|---|---|
| 1 | Loop-device/ueventd coldboot handoff (loop node never ready) | HIGH | klog: `Coldboot took`, `Loop device N not ready`, `Failed to activate apexes` |
| 2 | Bootstrap-set APEX content defect (GT-repacked APEX — vndk/art/adbd set never swapped in bisects) | MED-HIGH | diff GT vs stock `/system/apex` (bootstrap list `apexd.cpp:168-187`); klog names failing pkg |
| 3 | Other sepolicy delta (NOT apex_dm_device) | MED | stockselinux 044126 flash; `avc: denied` on loop/dm in klog |
| 4 | APEX signing/manifest key mismatch | LOW-MED | verify each bootstrap APEX vs bundled pubkey |
| 5 | userdebug-only behaviors | LOW | no userdebug-only branch in bootstrap path |
| — | /metadata stale, ActivatePackage resume, pvmfw, dm-verity-on-super, /data loop backing | **DEAD** | RQ4 proofs |

**Discriminator (RQ4∩RQ5):** ONE kernel-log harvest separates candidates 1/2/3 —
look for `apexd-bootstrap`: `Failed to activate apexes: <pkg>` / `Loop device N
not ready` / `Coldboot took` / `avc: denied` on loop_device/dm_device.

## RQ5 — Evidence capture ✓ (agent RQ5)

**The failed boot's real logs ARE harvestable — kernel writes ramoops; apexd+init
log to kmsg; ABL has unexploited debug commands.**

Verified in-tree:
- rango kernel (grapheneos dir via `trunk-14072179` symlink):
  `CONFIG_PSTORE=y/PSTORE_RAM=y/PSTORE_CONSOLE=y/PSTORE_PMSG=y` (IKCFG from
  `device/google/laguna-kernels/6.6/grapheneos/rango/Image`); pstore/ramoops
  built-in (`modules.builtin:85-86`); DTB `ramoops@95200000` +
  `cdd_log_reserved@90700000` + `debug_kinfo_reserved@90714000` (lga-b0.dtb).
- `apexd_main.cpp:122` KernelLogger; init `first_stage_init.cpp:422`
  InitKernelLogging → apexd-bootstrap failure line IS in kernel console →
  PSTORE_CONSOLE captures it even for orderly `0xfc` reboots.
- **ABL debug commands** (strings from `out/target/product/rango/abl.img`; ABL is
  a closed blob — semantics must be confirmed on-device):
  `oem ramdump klog` (+ enable/storage/usb/stage_file), `oem bcd read/write
  <command|status|recovery|stage>` (fields match `struct bootloader_message`),
  `oem cmdline add/del/set/show`, `oem uart enable/list/mux`, `oem vdu *`
  (virtual UART), `oem watchdog`, `oem boottrace`, `oem gsa log`.
- fastbootd is a dead end: no dmesg cmd (`fastboot_device.cpp:93-112`);
  `fetch` userdebug-enabled but vendor_boot-only (`commands.cpp:897-901`);
  `oem *` → Pixel HAL blob with no dmesg; fastbootd = recovery-ramdisk boot the
  GT chain never reaches.
- `init_fatal_panic` does NOT cover the `0xfc` class (orderly `DoReboot` path,
  `service.cpp:288-291`, `reboot.cpp:834`); vendor_boot_diag only helps the old
  `0x7f00` class. No apexd debug properties exist in `system/apex`.
- Kernel cmdline already debug-maximal: `earlycon=uart8250,mmio32,0xdb62000
  console=ttyS0,115200n8 printk.devkmsg=on` (DTB bootargs) + `loglevel=8`
  (`vendor/google_devices/rango/BoardConfig.mk:39-44`); extras injectable live
  via `oem cmdline add`.

**Ranked capture plan (next Mac flash):**

| # | Method | Cost | Verdict |
|---|---|---|---|
| 1 | `fastboot oem ramdump klog` + `oem bcd read *` + `oem dmesg` in bootloader, immediately post-failure | $0 / 1 min | Do first, always (wired into flash script failure guidance 2026-08-03) |
| 2 | ramoops via stock-recovery adb: re-flash rescue chain → recovery (`oem bcd write command boot-recovery` or button combo) → `adb shell cat /sys/fs/pstore/console-ramoops-0` | $0 / 5 min | Best info/$ — full failed-boot console incl. apexd line; both classes |
| 3 | `fastboot oem uart enable` + USB-serial (or `oem vdu`) | cable ~$20–50 | Gold-standard fallback if ramoops empty (prior: "pstore often empty from fastboot", `RANGO_BOOT_RCA.md:295`) |
| 4 | `oem cmdline add androidboot.init_fatal_panic=true` / vendor_boot_diag | $0 | Only if class flips back to init-kill (`0x7f00`) |
| 5 | Engineered debug boot chain | rebuild | Not justified |
| 6 | Breadcrumbs only (status quo) | $0 | Insufficient |

Caveats: `ramdump klog` semantics (streamed vs staged; CDD vs ramoops source)
inferred from blob strings — confirm on-device; ramoops survival across the
orderly `0xfc` + ABL handoff unproven; panic-class capture more reliable
(CDD/scan2mem writers in `vendor_kernel_boot.modules.load:47,70,78`).

---

## RCA table (final)

| Hypothesis | Evidence | Verdict |
|---|---|---|
| Build regression ("worked 10 days ago") | RQ3: no GOOD GT boot ever recorded; onset = port day 2026-07-25 | **FALSIFIED — never booted** |
| tzdata sole | 130756 on-device | FALSIFIED |
| stock apexd sole | 132759 on-device | FALSIFIED |
| stock init sole | 141438 on-device (class change to KP 0x100 = linker `_exit(1)`, RQ4) | FALSIFIED |
| stock init.rc sole | 150440 on-device | FALSIFIED |
| stock hwasan/libc sole | 153335 on-device | FALSIFIED |
| flash-parity sole | 153335 w/ A/B+uart+dpm confirmed | FALSIFIED |
| stale recycled vbmeta (describes fullgt-072051, not payload) | RQ2 avbtool | **PROVEN DEFECT** (not 0xfc-plausible: flags 3 baked) |
| testkey-only signing + dummy vbmeta_system/vendor | RQ2 key/descriptor match | **PROVEN DEFECT** (security/correctness; blocks flags-0) |
| stale `/metadata/apex` | RQ4: flag off → path unread; flash erases metadata | DEAD |
| ActivatePackage/session resume | RQ4: gated by mount_before_data | DEAD |
| pvmfw/VM payload | RQ4: VM-mode-only; virt dropped | DEAD |
| dm-verity on super (disable flags) | RQ4: bootstrap mounts `mount_on_verity=false` | DEAD |
| loop backing on /data | RQ4: bootstrap apexes on /system/apex | DEAD |
| apex_dm_device/mapper file_contexts | RQ4: type unreachable (dm-linear path compiled out) | DEAD as named cause |
| **whole-stack sepolicy swap (stockselinux)** | 044126 on-device: FAIL 0xfc ~18s, AB 11111111 (2026-08-03) | **FALSIFIED as sole cause** |
| **bootstrap-set APEX content (stockapexset, 36/36 stock)** | 130329 on-device: FAIL 0xfc, AB 11111111 (2026-08-03) | **FALSIFIED as sole cause** |
| **loop-device/ueventd coldboot handoff env (GT vendor.img: ueventd.rc/fstab/init)** | RQ4 #1; vendor never swapped in gtuserspace era; common to ALL fails | **OPEN — PRIME** (stockvendor probe next) |
| **GT monolithic super geometry vs super_empty metadata** | RQ1 diff; GT-built super common to ALL fails | **OPEN — PRIME** (fastboot-update path probe) |
| other sepolicy delta | 044126 whole-stack swap failed | FALSIFIED |
| APEX signing/manifest key mismatch | 130329 wholesale stock apexes failed | FALSIFIED |
| userdebug-only behavior | RQ4 #5 | OPEN — LOW |
| erase-only vs format userdata | RQ1 diff (untested) | OPEN — LOW (folded into update-path adoption) |
| monolithic-super geometry | RQ1 diff (untested) | OPEN — LOW (folded into update-path adoption) |

## Next-3 actions (ranked; DEC-RANGO-DR-001)

1. ~~FLASH 044126~~ **DONE 2026-08-03: FAIL 0xfc ~18s — stockselinux FALSIFIED**
   (whole sepolicy stack). Harvest attempted: `oem ramdump klog` gated
   (`Google internal device only.`), `oem bcd read *` empty → Method 1 dead on
   production. **Ramoops-via-recovery harvest PENDING (operator, immediate).**
2. **NEW MODE=stockapexset** (Backend DISPATCHED): stock `/system/apex` wholesale
   graft (vndk/art/adbd bootstrap set never swapped); hard cmp/hash gates;
   refuse `--link-latest`. Tests candidate 2 (HIGH).
3. **Log-driven #3:** ramoops console → if loop/coldboot stall: `MODE=stockueventd`
   (stock ueventd.rc/vendor loop config); if named APEX: single-package stock swap;
   if `avc: denied` (unexpected post-044126): targeted delta extraction.

## Flash-path proposal (DEC-RANGO-DR-002)

**Adopt the hybrid `fastboot update` path (RQ1 verdict), sequenced AFTER boot RCA
closes** (flash semantics cannot be the cure — 153335 falsified flash-parity-sole;
adopting mid-bisect would contaminate variables):

- Backend: `stage-rango-release.sh` ships `fastboot-info.txt` + `android-info.txt`
  + `image-rango-$STAMP.zip` (fastboot-info set, no monolithic super.img → −3.1 GB
  download); `flash-from-remote.sh` gains official mode: steps 0-2 unchanged →
  `fastboot -w --skip-reboot update image-rango-$STAMP.zip` → keep boot-watch +
  insmod push; rescue-boot/fastbootd machinery retained behind
  `--disable-super-optimization` fallback for MODE=fullgt bundles.
- **RQ2 defect remediation (post-boot, security-blocking):** rebuild vbmeta from
  the actual payload per stamp (stop recycling `886fe7c2…`), generate REAL
  vbmeta_system/vbmeta_vendor, wire `sign-build.sh` for rango with the real
  GuardTalk key (`7146d3b6…`), flash that pkmd to avb_custom_key, then evaluate
  flags-0 verified boot as an evidence-quality upgrade.
- **Process remediation:** commit the untracked rango tree state
  (stage-rango-release.sh, docs, QA evidence) — Law 11 reversibility; the 10-day
  effort currently has zero git trail.
