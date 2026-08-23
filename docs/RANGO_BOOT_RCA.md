# RANGO Boot RCA — Pixel 10 Pro Fold (`rango` / `laguna`)

| Field | Value |
|-------|--------|
| Task | `T-RANGO-BOOT-RCA` → inverted bisect (`T-RANGO-BOOT-GTSYSTEM`) |
| Date | 2026-08-01 (RCA); **updated 2026-08-20** (061630 bflags + 0xfc; flag series CLOSED) |
| Status | **REVIEW** (061630 `0xfc` ~18s AB `11111111`; build_flags-sole FALSIFIED; flag-dump series CLOSED; next `MODE=gtsystemonstockfacsuper`) |
| Device | Pixel 10 Pro Fold (`rango`), platform `laguna` |
| Lunch | `rango-trunk_staging-userdebug` |
| Flash path (binding) | `scripts/flash-from-remote.sh` / `vendor/guardtalk/scripts/flash-from-remote.sh` + `DEVICE=rango` → bisect via `REMOTE_BUILD_DIR` (latest still `130756`; never promote stockhwasan / stockselinux / stockapexset / stockvendor) |
| Fix scope | build / device / bundle staging — **no new flash scripts** |
| Fix status | See `RANGO_BOOT_FIX.md`; `rango-latest` → `130756`; bootstrap-set APEX content **falsified as sole cause** on `130329` (cross-bind with `044126`); next bisect `MODE=stockvendor` |

---

## 0. Active bind (2026-08-20) — `061630` / `MODE=gtsystemonstockbflags`

Operator flashed `rango-20260820-061630`. Flash SUCCESS (build+key
`…/061630`, super 28/28). Boot FAIL. Harvest
`harvest-rango-20260820-102522`: `Reboot mode: 0xfc`,
`fastboot enter: reboot bootloader`, `AB Decisions: 11111111`, ~18s.
KP `0x100` / `0xbaba` / mode `0x0` **absent**.

**`bflags + 0xfc` → leftover `build_flags.json` FALSIFIED as inverted
`0xfc` sole cause.** Flag-dump inverted series (aconfig / acflags /
bflags) is **CLOSED**. Do not re-flash `061630`. Do not stage another
`/system/etc` flag graft.

**RQ4 #2 host-narrowed (not closed):** factory vs `061630` `super.img`
share metadata v10, 3 slots, device `8531214336`, group
`google_dynamic_partitions` `8527020032`, same 12 names, first sector
2048. Both pack with **1MiB alignment**. Gap 96 vs 224 sectors is the
remainder after different `system_a` sizes (1796000 vs 2664224), not a
different alignment policy. Factory super + this GT `system.img` is
**impossible** (used ~946MiB > factory `system_a` ~877MiB). Reaching
apexd-bootstrap already proves first-stage mounted the lpmake super.

**Next class:** `MODE=gtsystemonstockfacsuper` only if liblp metadata
*fields* (not size/offset) differ, else one evidence-backed early-boot
leftover. No invented flag graft. `rango-latest` stays `130756`.

**Host bind (Engineer 2026-08-20, T-RANGO-BOOT-FACSUPER):** liblp fields
MATCH factory (header flags none; no virtual-ab; alignment 1MiB; no
alignment-offset; name-set/slots MATCH). Remaining `/system/etc` is
zygote-late; no proven init/apexd/loop/ueventd leftover. **No facsuper
stamp. Do not flash this turn.**

---

## 1. Executive root cause

### 1.0 Active failure (T-RANGO-BOOT-STOCKVENDOR, 2026-08-03) — APEX content FALSIFIED as sole cause; vendor/loop environment prime

**On-device bind (`rango-20260803-130329` / `MODE=stockapexset`):** Operator
flashed the wholesale stock-`/system/apex` stamp (36/36 stock `.apex` files
from the canonical donor, sha256-gated; `/system/apex` byte-identical to the
avbcontrol PASS composition). One-command auto-harvest captured the failed
boot's `oem dmesg` (`harvest-rango-20260803-183432/oem-dmesg.txt`):

| Signal | Value |
|--------|--------|
| Reboot mode | `0xfc` — **bootloader** |
| fastboot enter | `reboot bootloader` |
| AB Decisions | `11111111` |
| KP / `0x00000100` | **absent** (NOT KP `0x100`) |
| `0xbaba` | **absent** |

**Cross-bind falsification (the decisive one):**

| Stamp | sepolicy | `/system/apex` content | Result |
|-------|----------|------------------------|--------|
| `044126` (stockselinux) | **stock** (whole stack) | **GT** (durable set) | FAIL `0xfc` |
| `130329` (stockapexset) | **GT** (OUT-coherent) | **stock** (wholesale 36/36) | FAIL `0xfc` |

Both fail identically → **bootstrap-set APEX content is FALSIFIED as sole
cause** (RQ4 #2 CLOSED), and sepolicy was already falsified on `044126`.
The `0xfc` trigger is therefore **not** in `/system/apex` content and **not**
in the sepolicy stack — the two largest system-side surfaces are now
eliminated.

**Re-ranked remaining candidates (DR-RANGO-10DAY-RCA RQ4, post-130329):**
1. **Loop-device/ueventd coldboot handoff ENVIRONMENT** (PRIME) —
   `OnBootstrap` runs the legacy path (`mount_before_data=false`); the ~18s
   signature is dominated by the **unbounded** `WaitForLoopDevice` poll that
   resets while `ro.cold_boot_done` is false
   (`system/apex/apexd/apexd_loop.cpp:450-482`). In the durable gtuserspace
   composition the boot chain + dlkm are factory, but **`vendor.img` is GT**
   — and vendor carries `ueventd.rc` (device-node rules incl. loop/dm
   timing), `fstab`, `init.*.rc`, VINTF manifests. It has **never been
   swapped** in the gtuserspace era. → **prime bisect `MODE=stockvendor`**
   (staged as `rango-20260803-145117`; see §1.0.1).
2. **GT-built monolithic super geometry** (HIGH) — the other artifact common
   to every FAIL: all failing stamps ship an lpmake-regenerated super from
   GT OUT logicals, while the PASS control ships the factory super. Not
   isolated yet (stockvendor keeps lpmake super; a PASS on stockvendor
   exonerates super geometry, a FAIL keeps it in play).
3. APEX signing/manifest key mismatch (LOW-MED); userdebug-only behavior
   (LOW).

**Harvest state (RQ5):** auto-harvest is built into `flash-from-remote.sh`
(breadcrumbs → rescue reflash → BCB recovery boot → adb pstore pull →
DISCRIMINATOR grep). Auto-harvest v1 learnings: BCB write accepted but NOT
honored (bcd read/write unreliable on this ABL); rescue boot + GT super also
`0xfc` → recovery must be entered via **BUTTON COMBO** (script prints it);
ramdump klog gated (`Google internal device only.`). Operator is harvesting
the failed boot's console via recovery adb (button-combo path); it may
further specify loop/coldboot/mapper — the stockvendor probe is valid
regardless (harvest refines, does not invalidate).

#### 1.0.1 Vendor diff analysis (T-RANGO-BOOT-STOCKVENDOR deliverable) — GT `vendor.img` vs stock donor

Host-side diff of GT `out/target/product/rango/vendor.img` vs the canonical
stock donor `releases/desktop-flash/rango-stock-userspace/vendor.img`
(factory CP1A.260505.005), focused on coldboot/loop/dm relevance
(debugfs dump + diff/cmp, 2026-08-03):

| Surface | Result | loop/dm/coldboot relevance |
|---------|--------|----------------------------|
| `/vendor/etc/ueventd.rc` | **byte-identical** (11,269 B) | No explicit loop/dm rules in EITHER image — loop device nodes fall back to ueventd defaults identically |
| `/vendor/etc/fstab.laguna` | **byte-identical** (4,407 B) | No loop/dm/mapper/super lines at all (logical partitions via first-stage ramdisk fstab, already factory) |
| `/vendor/etc/fstab.persist` | **byte-identical** (343 B) | none |
| `/vendor/etc/init/hw/*.rc` (init.efs / init.laguna / init.laguna.usb / init.persist / init.rango) | **ALL byte-identical** | Zero loop/dm/apex/coldboot/ueventd lines in `init.laguna.rc` |
| `/vendor/etc/init/` file list | GT **+2** (`init.laguna.grapheneos.rc` USB port-security, `init.pixel.grapheneos.rc` SE-erase — both property-triggered, post-fs or later); GT **−15** (modem/radio/gnss/nfc/fingerprint HAL rc's — consistent with modem + Goodix excision) | Only loop hit in the entire stock-only set: `storage.intelligence.rc` mounts `loop@/dev/block/by-name/userdata_exp.ai` — a **data-stage** loop mount, unrelated to apexd-bootstrap's early loop devices |
| `/vendor/etc/vintf/manifest.xml` | 101 diff lines — all radio/modem/SE-SIM HAL entries (stock-only) | none (HAL declarations, post-apexd) |
| `/vendor/etc/vintf/compatibility_matrix.xml` | 18 diff lines | none |
| `/vendor/etc/selinux/precompiled_sepolicy*.sha256` | **DIFFER** — GT plat `e7d305f7…` (== GT OUT) vs stock `8db80f2e…` | see composition risk below |
| `/vendor/build.prop` | GT `userdebug`/`test-keys`/`Baklava` vs stock `user`/`release-keys`/`16`; GT adds dalvik/audio props | none direct |
| fstab inventory | stock-only extra: `fstab.modem` | modem excision artifact, unrelated |

**Sharpening conclusion:** the vendor-side **static** coldboot/loop/dm
configuration (ueventd.rc device rules, fstab, ALL hw init scripts) is
**byte-identical** to the PASS control's vendor. So if RQ4 #1 is the cause,
the delta is NOT in static vendor config files — it must be in vendor
**binary/lib/firmware content** (e.g. drivers/firmware the loop/dm stack
touches), VINTF-driven service behavior, or runtime-environmental effects —
or the hypothesis shifts to candidate #2 (GT-built monolithic super
geometry). `MODE=stockvendor` tests the whole partition at once; the diff
bounds what a PASS/FAIL means either way.

**Composition risk (documented, accepted by design):** stock vendor ships
stock `precompiled_sepolicy` whose sha256 files **differ** from the GT
system*/product sepolicy sha256 (GT plat `e7d305f7…` vs stock `8db80f2e…`).
Per AOSP SELinux build docs (§4 #3), init then ignores the precompiled
policy and compiles on-device from CIL — and FIX §2.5 measured GT plat CIL +
factory vendor CIL **failing** offline `secilc` (`hal_audio_default`
resolve). Therefore, if the stockvendor stamp fails **FAST as `0x7f00`/KP
instead of ~18s `0xfc`**, that is the known sepolicy incoherence, **not** a
loop/ueventd result — the coherent follow-up (stock system-side sepolicy +
stock vendor, i.e. stockvendor layered on the falsified stockselinux grafts)
is an Architect decision. A ~18s `0xfc` outcome keeps RQ4 #1 open →
candidate #2 (super geometry). Reaching adb → vendor environment was the
`0xfc` trigger.

**Closed bisects:**

| Stamp / probe | Outcome | Closed hypothesis |
|---------------|---------|-------------------|
| `rango-avbcontrol-*` | PASS (stock UI) | AVB/bootloader OK |
| `rango-fullgt-*` | ABL reject `AB 11311112` | GT boot forbidden as latest |
| hybrid / early gtuserspace | `0x7f00` (~61s) | init kill (pre-apexd) — historical |
| `rango-20260802-103641` stock bootstrap (virt kept) | **FAIL** `0xfc` ~18s | apexd-bootstrap class named |
| `rango-20260802-111004` novirt | **FAIL** `0xfc` ~18s (`AB 11111111`) | virt-drop **insufficient** |
| `rango-20260802-123756` novirt+stock runtime/i18n | **FAIL** `0xfc` ~18s | stock runtime/i18n **insufficient** |
| `rango-20260802-130756` novirt+stock tzdata/runtime/i18n | **FAIL** `0xfc` ~18s (`AB 11111111`) | **GT tzdata as sole named-bootstrap cause FALSIFIED** |
| `rango-20260802-132759` stockapexd (stock apexd + durable set) | **FAIL** `0xfc` ~18s (`AB 11111111`) | **stock-apexd-sole FALSIFIED** |
| `rango-20260802-141438` stockinit (stockapexd + stock init) | **FAIL** KP `0x00000100` ~61s (`0xbaba`, mode `0x0`, `AB 11111133`) | **stock-init-sole FALSIFIED** (class changed ≠ cured) |
| `rango-20260802-150440` stockapexcfg (stockapexd + GT init + stock init.rc) | **FAIL** `0xfc` ~18s (`AB 13311111`) | **stockapexcfg-sole / stock-init.rc-sole FALSIFIED** |
| `rango-20260802-153335` stockhwasan (+ GrapheneOS flash parity) | **FAIL** `0xfc` ~18s (`AB 11111111`) | **stockhwasan-sole + flash-parity-sole FALSIFIED** |
| `rango-20260803-044126` stockselinux (whole stock sepolicy stack) | **FAIL** `0xfc` ~18s (`AB 11111111`) | **stockselinux-sole FALSIFIED** — sepolicy as sole cause dead |
| `rango-20260803-130329` stockapexset (stock `/system/apex` wholesale 36/36) | **FAIL** `0xfc` ~18s (`AB 11111111`, harvest oem-dmesg bound) | **bootstrap-set APEX-content-sole FALSIFIED** (RQ4 #2 closed via 044126 × 130329 cross-bind) |

**Durable composition (still linked as latest; on-device FAIL):**
`MODE=gtuserspace` = factory boot/dlkm + GT system*/product/vendor + drop
virt + stock runtime/i18n/tzdata. Not stock-only OS. Never `fullgt` as
`rango-latest`. Stock `apexd` / stock `init` / stock `init.rc` / stock
hwasan / stock early-apex SELinux / stock `/system/apex` set / stock
`vendor.img` **not** folded into durable until on-device PASS.

DPM `err -7` remains **non-primary** (empty SBDP after erase). Operator
should `fastboot set_active a` before next flash.

### 1.0-hist Historical bind (T-RANGO-BOOT-SELINUX, 2026-08-03) — `044126` detail

**On-device bind (`rango-20260803-044126` / `MODE=stockselinux`):** Operator
flashed with the official-aligned script — `avb_custom_key` erase→flash at
the official position ✓, single vbmeta pass ✓ (GrapheneOS parity retained:
dual-slot bootloader, `oem uart disable`, `erase dpm_a`/`dpm_b`). The stamp
carried the **whole stock sepolicy stack**: stock `plat_file_contexts` +
`plat_sepolicy.cil` + mapping + system_ext/product sepolicy + stock vendor
`precompiled_sepolicy` (hashes MATCH, hard-gated at staging).
**FAIL ~18s** — same apexd-bootstrap class (`0xfc` / `reboot bootloader` /
`AB 11111111`; NOT KP `0x100`; `0xbaba` absent; DPM `err -7` still logged —
expected, not sole RC).

**Closed by this bind:** the **whole stock sepolicy stack** as cure for
`0xfc` — **FALSIFIED**. Consistent with DR-RANGO-10DAY-RCA RQ4: GT's missing
`apex_dm_device` type is **unreachable** on this build
(`mount_before_data=false` → legacy `OnBootstrap` never creates
`.apex`-named dm devices), so the sepolicy delta could not have been the
`0xfc` trigger.

**Harvest attempts (RQ5, that flash):** `fastboot oem ramdump klog` →
`Google internal device only.` (**gated — dead on production units**);
`fastboot oem bcd read *` → empty. Ramoops-via-recovery adb remains the
critical-path log source (operator pending).

**Prior named class (reconfirmed on `044126` and `130329`):**
`apexd-bootstrap` → `reboot_on_failure reboot,bootloader,bootstrap-apexd-failed`
→ `Reboot mode: 0xfc`. Cite AOSP `system/apex/apexd/apexd.rc`.

### 1.1 Historical primary (init `exitcode=0x00007f00`)

**Primary (init `exitcode=0x00007f00`):** GuardTalkOS `system` / `system_ext` / `product` were paired with a `vendor` image whose `precompiled_sepolicy.*.sha256` hashes did **not** match the GT platform policy hashes. Android init then falls back to on-device `secilc` compilation; that path failed (in-tree evidence: dangling libc / failed early exec), so PID 1 exited status **127** → kernel panic `Attempted to kill init! exitcode=0x00007f00`.

**Contributing (why “full GT” never became the flash target):**

1. **ABL / AVB boot-chain mismatch** — GT `boot` / `init_boot` / `vendor_boot` signed with the AOSP **test key** are rejected or unstable on this bootloader pin unless `avb_custom_key` is loaded with the matching public key; experimental notes record ABL accept for stock CP1A boot (`AB 31111122`) vs reject for GT boot (`AB 31112113`). Proven interim userspace path keeps **factory CP1A boot chain** + GT logical partitions.
2. **MTE / `memtag_heap` vs cmdline** — GrapheneOS enables hardware MTE aggressively; GuardTalk strips `bootloader.pixel.MTE_FORCE_ON` for laguna early-boot safety. If userspace binaries still carry `.note.android.memtag`, `execve` fails with **ENOEXEC** → same `0x7f00`. Mitigations are already in `BoardConfig-excised-late.mk` and `system/core/init/Android.bp` (`memtag_heap: false`).
3. **Bundle drift** — `rango-latest` still points at an experimental **hybrid** stamp, not a clean full-GT OUT stage, so the desktop flash path does not represent a single coherent build artifact.

---

## 2. In-tree measurements (re-run 2026-08-01)

### 2.1 Symlink / stamps

```text
readlink -f releases/desktop-flash/rango-latest
→ …/releases/desktop-flash/rango-hybrid-20260731-060108
```

| Stamp | Role |
|-------|------|
| `rango-hybrid-20260731-060108` (**current `rango-latest`**) | Factory CP1A boot + GT `system*` + factory vendor **with GT sepolicy graft** |
| `rango-20260727-081848` | Earlier hybrid README: documents sepolicy-hash → secilc → `0x7f00` fix |
| `rango-memtagfix2-20260728-101648` | Full-GT-style images (`boot` sha ≠ factory); MTE cmdline strip experiment |
| `rango-rescue-boot` / `rango-stock-*` | Factory CP1A boot control / rescue for fastbootd entry |
| `rango-bisect-*`, `rango-test-*` | Partition bisects (vendor / init / selinux) |

### 2.2 Sepolicy hash match (OUT)

```text
OUT=out/target/product/rango
plat_MATCH
system_ext_MATCH
product_MATCH
plat sha256 = e7d305f74e5d48e2b6b122ff247c291f91249272d93f5fd9c5207787d430e168
```

**Interpretation:** A **coherent full-GT OUT** (GT system* + GT vendor built together) has matching precompiled hashes today. The historical `0x7f00` path is **not** “GT system vs GT vendor from the same `m`”, but **GT system\* vs stock/factory vendor (or any vendor whose grafted hashes were wrong / missing)**.

Hybrid staging (archived `stage-rango-hybrid.sh`) explicitly grafts:

- `precompiled_sepolicy`
- `precompiled_sepolicy.plat_sepolicy_and_mapping.sha256`
- `precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256`
- `precompiled_sepolicy.product_sepolicy_and_mapping.sha256`

from OUT into factory `vendor.img`, then lpmake’s `super.img`.

### 2.3 Image SHA cross-check (boot vs system)

| Artifact | `boot.img` sha256 (prefix) | Notes |
|----------|----------------------------|--------|
| hybrid / rescue / several `rango-20260728-*` | `33e5b156…` | Factory CP1A boot |
| `rango-memtagfix2` / current OUT | `0fa6cf28…` | GT-built boot |
| hybrid `system.img` | `708d5481…` | **Identical** to current OUT `system.img` |
| hybrid `vendor.img` | `08e4c4fa…` | **≠** OUT vendor `c736b2ea…` (factory drivers + graft) |

### 2.4 AVB / keys

| Item | Measurement |
|------|-------------|
| `vbmeta.img` Flags | **3** (= `HASHTREE_DISABLED` \| `VERIFICATION_DISABLED`) |
| vbmeta public key (sha1) | `2597c218aae470a130f61162feaae70afd97f011` (AOSP testkey) |
| Bundle `avb_pkmd.bin` | sha256 `7728e30f…` — **byte-identical** to `avbtool extract_public_key` of `external/avb/test/data/testkey_rsa4096.pem` |
| `BOARD_AVB_KEY_PATH` | Not set in rango BoardConfig (defaults → test-keys / eng signing) |

### 2.5 Boot cmdline / MTE (vendor_boot binary scan)

| Image | `MTE_FORCE_ON` | `kasan=off` | `androidboot.radio.disabled=1` |
|-------|----------------|-------------|-------------------------------|
| hybrid (factory) vendor_boot | 0 | 1 | 0 |
| memtagfix2 / OUT vendor_boot | 0 | 1 | 1 |

`llvm-readelf -n` on OUT `system/bin/init`, `secilc`, `logd`, runtime `linker64`: **no `MEMTAG` notes** (MTE strip effective for these critical bins).

### 2.6 Device layer facts

- `vendor/google_devices/rango/BoardConfig.mk:100` includes `vendor/guardtalk/device/rango/BoardConfig-excised-late.mk`
- Excised-late: modem out of `AB_OTA_PARTITIONS`, `androidboot.radio.disabled=1`, strip `MTE_FORCE_ON` / `kasan.fault=panic`, add `kasan=off`, strip `memtag_heap` from `SANITIZE_TARGET`, laguna blocklist override
- `fstab.laguna` (vendor_ramdisk): first-stage mounts for `boot`/`init_boot`/`vbmeta` + logical `system`/`system_ext`/`product`/`vendor` with AVB names — foldable-capable stock layout; no GuardTalk fstab rewrite required for this RCA
- Fold preserve list: hinge / dual display / hall / syna_touch insmod — see `RANGO_PORT_LAYER.md` (not implicated in early init kill)

### 2.7 Documented hybrid recipe (coherent) vs broken full-GT super

| Layer | Coherent hybrid (proven direction) | Broken / rejected paths |
|-------|------------------------------------|-------------------------|
| boot / init_boot / vendor_boot / vendor_kernel_boot / dtbo / pvmfw | Factory CP1A | Raw GT boot without accepted ABL path |
| system / system_ext / product | GuardTalkOS OUT | — |
| vendor | Factory drivers + **GT precompiled_sepolicy + matching sha256** | Factory vendor **without** graft; or GT system + stock sepolicy hashes |
| system_dlkm / vendor_dlkm | Factory CP1A (hybrid) | Mixed without module/insmod parity |
| vbmeta* | Flags:3, **valid** test-key signature (not rewritten) | Rewritten/invalid vbmeta → AVB ERROR even with Flags |
| avb_custom_key | Erase + flash `avb_pkmd_testkey.bin` | Missing custom key → ABL distrust of test-key images |

---

## 3. Failure chain (ordered)

```text
Flash GT system* + mismatched vendor sepolicy hashes
        │
        ▼
init: precompiled hash compare FAIL
        │
        ▼
LoadSplitPolicy → exec secilc / early helpers
        │
        ▼
exec fails (ENOEXEC / missing lib) → init exits 127 (0x7f00)
        │
        ▼
Kernel panic: Attempted to kill init!
```

Parallel AVB branch (before or instead of userspace):

```text
GT boot/vbmeta (test-key) without avb_custom_key
        │
        ▼
ABL rejects or AVB ERROR (experiments: AB 31112113)
        │
        ▼
G-logo loop / return to fastboot (may never reach init)
```

After AVB OK with stock boot + GT super **without** sepolicy graft → still `0x7f00` (SPRINT evidence seed; hybrid README).

---

## 4. Internet sources (mandatory citations)

| # | Title | URL | What it supports |
|---|-------|-----|------------------|
| 1 | GrapheneOS FAQ — supported devices | https://grapheneos.org/faq | Official production support lists **Pixel 10 Pro Fold (`rango`)** — device is real/supported upstream; failure is GuardTalkOS image composition, not “unsupported codename”. |
| 2 | GrapheneOS Releases | https://grapheneos.org/releases | Release notes for Pixel 10 Pro Fold; kernel notes on **hardware memory tagging** catching DisplayPort / Wi‑Fi bugs on Pixel 10 family — corroborates why laguna MTE is hot and why GuardTalk strips forced MTE for early bring-up. |
| 3 | AOSP — Build SELinux policy (precompiled hashes) | https://source.android.com/docs/security/features/selinux/build | Documents that init compares `plat` / `system_ext` / `product` sha256 files to vendor `precompiled_sepolicy.*.sha256` and **compiles on device** if they differ — exact mechanism behind the primary RCA. |
| 4 | AOSP — Device state / `avb_custom_key` | https://source.android.com/docs/security/features/verifiedboot/device-state | Unlocked devices may still use verification; `avb_custom_key` is the user-settable root of trust (`avbtool extract_public_key` → `fastboot flash avb_custom_key`) — matches bundle pkmd / flash-from-remote needs. |
| 5 | Android Verified Boot 2.0 README | https://android.googlesource.com/platform/external/avb/+/master/README.md | vbmeta flags / verification-disabled behavior; custom key yellow-state semantics — explains Flags:3 + unlocked + custom key combo used in experiments. |
| 6 | AOSP fastboot README (`update-super`, flashall) | https://android.googlesource.com/platform/system/core/+/master/fastboot/README.md | Documents `reboot fastboot` → `update-super` → logical `flash` and host-side super optimization — validates why rango flash order must reach **fastbootd** for logical partitions (also encoded in `flash-from-remote.sh`). |
| 7 | AOSP — MTE bootloader support | https://source.android.com/docs/security/test/memory-safety/bootloader-support | Bootloader/kernel MTE enablement ABI — background for `MTE_FORCE_ON` / memtag policy mismatch class of failures. |
| 8 | Unix.SE — init `exitcode=0x00007f00` | https://unix.stackexchange.com/questions/691923/error-message-here-end-kernel-panic-not-syncing-attempted-to-kill-init-exitc | Confirms `0x7f00` ⇒ exit status **127** (exec/library failure of PID 1), not a distinct “Android-only” magic code. |

**Citation count: 8** (requirement ≥ 3).

---

## 5. Single proposed minimal fix path (`T-RANGO-BOOT-FIX`)

**Goal:** One coherent `releases/desktop-flash/rango-<UTC>/` stamp + `rango-latest` symlink that `flash-from-remote.sh` already consumes. No new `scripts/flash-*.sh`.

### Path (ordered — do not fork into script sprawl)

1. **Keep device-layer MTE safety (already present — verify, do not regress)**  
   - `vendor/guardtalk/device/rango/BoardConfig-excised-late.mk` strips `MTE_FORCE_ON` / `memtag_heap` / sets `kasan=off`.  
   - Keep `system/core/init` `memtag_heap: false` for rango (already commented for `0x7f00`).

2. **Build-host staging recipe (single helper under `vendor/guardtalk/` or existing stage path — not Mac flash scripts)** that produces:
   - **Boot chain:** factory CP1A from `rango-rescue-boot` / stock pin **until** on-device ABL accepts GT boot (HOLD below).  
   - **Userspace logical:** GT `system` / `system_ext` / `product` from OUT.  
   - **Vendor:** start from factory vendor **or** GT vendor; **hard gate:**  
     `cmp` all three `precompiled_sepolicy.*.sha256` against GT `system*` hashes before shipping.  
     If using factory vendor drivers: **graft** GT `precompiled_sepolicy` + three sha256 files (logic already proven in archived `stage-rango-hybrid.sh` — fold into staging, do not resurrect flash wrappers).  
   - **dlkm:** factory or GT consistently with insmod cfg (`init.insmod.rango.cfg` already in flash-from-remote).  
   - **vbmeta:** ship **valid** Flags:3 test-key `vbmeta.img` (no post-hoc rewrite).  
   - **Public** `avb_pkmd.bin` (= testkey pkmd).  
   - Point `rango-latest` at that stamp only after staging gates pass.

3. **Flash remains `flash-from-remote.sh` only**  
   - Ensure it continues: rescue boot → fastbootd logical → GT/hybrid boot+vbmeta; flash `avb_custom_key` when pkmd present (script already documents rango order).  
   - Do **not** add hybrid flash scripts.

4. **Exit criteria for FIX**  
   - Staging gate: sepolicy `plat`/`system_ext`/`product` MATCH.  
   - `rango-latest` → non-experimental name (`rango-YYYYMMDD-HHMMSS`) with README describing partition sources.  
   - Q-RANGO-BOOT: boot to adb **or** HOLD with `fastboot oem dmesg` / console-ramoops showing no `0x7f00`.

### Explicitly out of scope for FIX

- New flash scripts; deleting scripts (CLEANUP).  
- Re-enabling forced MTE on laguna without kernel/DTB verification.  
- Doctrine / private keys.

---

## 6. Non-causes (ruled out)

| Hypothesis | Why ruled out |
|------------|----------------|
| “rango unsupported by GrapheneOS” | FAQ + releases list Pixel 10 Pro Fold / rango as supported. |
| “OUT sepolicy always mismatched” | Re-run: OUT `plat`/`system_ext`/`product` **MATCH** vendor precompiled hashes. |
| “vbmeta Flags:3 alone broken” | Flags:3 is intentional for unlocked/dev; failures were invalid rewrite / missing `avb_custom_key`, not the flag value itself. |
| “Foldable fstab missing hinge mounts” | `fstab.laguna` is stock first-stage; fold policy preserved in port layer; panic is pre-UI init kill. |
| “Modem excision uniquely kills init” | Radio disabled cmdline present on GT vendor_boot; hybrid with factory vendor_boot (no radio flag) was the sepolicy-fix path — modem not required for primary `0x7f00`. |
| “Wrong product symlink (`latest`/`akita-latest`)” | `rango-latest` correctly maps in flash-from-remote; issue is **stamp content**, not wrong device symlink name. |
| “Need more Mac hybrid flash scripts” | Architect DEC: flash-from-remote only; hybrid composition belongs in **bundle staging**. |

---

## 7. HOLD — needs on-device logs

| ID | Need | Why |
|----|------|-----|
| H1 | `fastboot oem dmesg` / RAMDUMP after failed boot | Confirm current `rango-latest` hybrid still hits `0x7f00` vs AVB-only fail |
| H2 | `console-ramoops-0` via stock recovery after GT boot attempt | Capture secilc/linker/ENOEXEC lines (pstore often empty from fastboot) |
| H3 | ABL decision codes with GT boot + `avb_custom_key` erased vs flashed | Confirm whether full-GT boot is viable post-key inject |
| H4 | After FIX stamp: adb `getprop ro.build.fingerprint` + fold smoke | Prove userspace beyond init |
| H5 | Compare factory vs GT `vendor_dlkm` module load on first boot | Rule out second-stage module hangs (insmod cfg already pushed) |

---

## 8. Acceptance checklist (this task)

- [x] `vendor/guardtalk/docs/RANGO_BOOT_RCA.md` with root cause + citations + minimal fix design  
- [x] ≥ 3 distinct public URLs with relevance  
- [x] In-tree measurements re-run (hashes, symlink, BoardConfig/AVB facts)  
- [x] No new flash scripts  
- [x] Status → **REVIEW** + completion pointer for Architect  

---

## 9. Gate 5 (self-critique)

| Criterion | Score | Note |
|-----------|-------|------|
| Evidence re-verified (not chat-only) | 95 | Symlink, cmp hashes, vbmeta Flags, pkmd=testkey, image SHAs |
| Citations | 95 | 8 URLs spanning GOS, SELinux, AVB, fastboot, MTE, exit 127 |
| Single fix path clarity | 92 | Staging + device keep; flash-from-remote only |
| Non-causes / HOLDs | 90 | Explicit |
| Scope discipline (no FIX impl) | 100 | Docs + queue status only |

**Gate 5 aggregate: 94%** — **REVIEW** (not self-APPROVED).

---

*T-RANGO-BOOT-RCA — Backend Engineer — 2026-08-01*
