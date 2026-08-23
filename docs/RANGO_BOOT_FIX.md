# RANGO Boot FIX — Pixel 10 Pro Fold (`rango` / `laguna`)

| Field | Value |
|-------|--------|
| Task | `T-RANGO-BOOT-FIX` → … → APEXSET → **STOCKVENDOR** (`T-RANGO-BOOT-STOCKVENDOR`) |
| Date | 2026-08-01; **updated 2026-08-20** (061630 bflags + 0xfc; flag series CLOSED; next `gtsystemonstockfacsuper`) |
| Status | **REVIEW** (061630 `0xfc` AB `11111111`; next `MODE=gtsystemonstockfacsuper`; HOLD without adb) |
| Depends on | `T-RANGO-BOOT-RCA` ✅; SELINUX closed (044126 FAIL); APEXSET closed (130329 FAIL); STOCKVENDOR active |
| RCA | `vendor/guardtalk/docs/RANGO_BOOT_RCA.md` (§1.0 active; §1.0.1 vendor diff) |
| Flash path (binding) | `scripts/flash-from-remote.sh` / `vendor/guardtalk/scripts/flash-from-remote.sh` only — **zero** new `scripts/flash-*.sh` (GrapheneOS A/B+uart+dpm parity retained; auto-harvest built in) |
| Latest stamp | `rango-latest` → `rango-20260802-130756` (unchanged; **do not** promote stockhwasan / stockselinux / stockapexset / stockvendor until on-device PASS) |
| Bisect stamp | `MODE=stockvendor` → `rango-20260803-145117` → flash via `REMOTE_BUILD_DIR` only |
| On-device | `130329` **FAIL** `0xfc` ~18s (`AB 11111111`, harvest oem-dmesg bound) — bootstrap-set APEX-content-sole **falsified** (cross-bind 044126 × 130329); no invent PASS |
| Note | Do **not** flash `rango-20260802-130338` (debugfs write-order bug corrupted runtime; superseded) |

---

## 0. Active bind (2026-08-20) — `061630` closed; next `facsuper` only if real

`rango-20260820-061630` / `MODE=gtsystemonstockbflags`: flash OK / boot
`0xfc` ~18s `AB 11111111` (harvest `harvest-rango-20260820-102522`).
**build_flags-sole FALSIFIED.** Do not re-flash. Do not `--link-latest`.
Do not invent PASS.

Honor stage-script quote: remaining `/system/etc` DIFFs are zygote-late;
next class is flash-path/lpmake. Host lpdump: schema MATCH + same 1MiB
alignment; factory super cannot hold this GT `system.img`.

**Host bind (Engineer 2026-08-20, T-RANGO-BOOT-FACSUPER):** leftover
inventory is zygote-late; liblp fields MATCH factory (not size/offset;
96-vs-224 ignored). No proven early-boot leftover. **No new stamp. Do
not flash this turn.** Durable final recipe only after `adb`.

---

## 1. What changed

### 1.1 New staging helper (vendor path, not `scripts/`)

`vendor/guardtalk/scripts/stage-rango-release.sh` — consolidated, non-experimental
staging helper. Folds the sepolicy-graft technique from the archived
`.agent-comm/completed/rango-flash-mess-20260801/stage-rango-hybrid.sh`
(verbatim hard `cmp` gate) and adds two read-only diagnostic modes required
by the Architect's residual-gap binding. **This script never flashes
anything** — it only assembles `releases/desktop-flash/rango-*` bundles that
`flash-from-remote.sh` later consumes.

| Mode | Purpose | May relink `rango-latest`? |
|------|---------|------------------------------|
| `hybrid` (default) | Factory CP1A boot chain + factory vendor drivers/dlkm; GuardTalkOS `system`/`system_ext`/`product` from current OUT; GT `precompiled_sepolicy` grafted into vendor with a **hard `cmp` gate** (all three `.sha256` files must MATCH before anything is staged). RCA §5 proven interim direction. | **Yes**, only with `--link-latest` |
| `avbcontrol` | 100% factory content (super/system/vendor/boot/bootloader/radio, zero GuardTalkOS) + Flags:3 valid test-key vbmeta. Isolates "AVB path OK" from "GT `system*` content" per Architect residual-gap binding item 2. | No — refuses `--link-latest` |
| `fullgt` | Fully coherent OUT build: `system`/`system_ext`/`product`/`vendor`/`system_dlkm`/`vendor_dlkm`/boot chain **all** from the same current `m` run (no graft — hashes MATCH natively). Staged for RCA HOLD H3 (does ABL accept the GT test-key boot chain once `avb_custom_key` is flashed?). | No — refuses `--link-latest` |

Both `mte_strip_gate` (verifies `BoardConfig-excised-late.mk` MTE/`memtag_heap`
strips + `system/core/init/Android.bp` `memtag_heap: false` + scans
`system/bin/init` for a `.note.android.memtag` ELF note via `llvm-readelf`)
and `sepolicy_hash_gate` (hard `cmp`, fails closed) run before `hybrid` and
`fullgt` stage anything.

### 1.2 New coherent stamp + `rango-latest`

```text
readlink releases/desktop-flash/rango-latest
→ rango-20260801-071754   (was: rango-hybrid-20260731-060108)
```

Non-experimental name (`rango-YYYYMMDD-HHMMSS`, no `hybrid`/`memtagfix`
suffix) per exit criteria. Produced by:

```bash
MODE=hybrid vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
```

**Sepolicy hard-gate result (re-verified against the final shipped, sparse
`vendor.img` via `debugfs dump` + `cmp`, not just the intermediate raw
image):**

```text
OUT: plat_MATCH  system_ext_MATCH  product_MATCH
SHIPPED vendor.img (post-graft, post-img2simg): plat sepolicy MATCH ✓
SHIPPED vendor.img (post-graft, post-img2simg): product sepolicy MATCH ✓
```

### 1.3 Bug found and fixed: missing firmware images in the previous `rango-latest`

The previous `rango-latest` target (`rango-hybrid-20260731-060108`) was
**missing `bootloader.img` and `radio.img`**. `scripts/flash-from-remote.sh`
downloads both unconditionally (`FW_IMAGES`, not in its optional-file
exception list) — a real flash would have `die`d at step 1/9
("failed to download bootloader.img") before ever reaching the device. The
new staging script always copies `bootloader.img`/`radio.img` from
`releases/desktop-flash/rango-stock-control` (verified byte-identical
firmware across every prior rango stamp — factory firmware does not change
with GuardTalkOS content) and the new stamp was checked file-by-file against
every name `flash-from-remote.sh`'s `ALL_DOWNLOADS` requires:

```text
ALL required flash-from-remote.sh inputs present in rango-latest ✓
```

This is a genuine functional fix, not just a rename — the prior `rango-latest`
would not have completed a `flash-from-remote.sh` run at all.

### 1.4 MTE / `memtag_heap` — verified not regressed

- `vendor/guardtalk/device/rango/BoardConfig-excised-late.mk` — unchanged;
  still strips `MTE_FORCE_ON`/`kasan.fault=panic`, adds `kasan=off`, filters
  `memtag_heap` out of `SANITIZE_TARGET`/`SANITIZE_TARGET_DIAG` (lines 1–37,
  no edits made this task).
- `system/core/init/Android.bp` — unchanged; both `memtag_heap: false` sites
  (init variants + debug ramdisk `adb_debug.prop` installer) intact.
- `llvm-readelf -n` on the current OUT `system/bin/init`, `secilc`,
  `linker64`: **no `.note.android.memtag` note** on any of them (re-verified
  this task, matches RCA §2.5).
- `mte_strip_gate()` in the new staging script re-checks all of the above on
  every `hybrid`/`fullgt` run and fails closed if any check regresses.

### 1.5 Residual-gap diagnostics staged (Architect binding item 2)

Two new, fully self-contained, documented diagnostic bundles (not linked
from `rango-latest`):

| Stamp | Mode | Purpose |
|-------|------|---------|
| `releases/desktop-flash/rango-avbcontrol-20260801-072014` | `avbcontrol` | 100% stock content + Flags:3 vbmeta. If this boots to `adb`, the AVB/bootloader path is exonerated and the failure is isolated to GT `system*` content. If it does **not** boot, the AVB path itself is implicated. |
| `releases/desktop-flash/rango-fullgt-20260801-072051` | `fullgt` | Fully coherent GT boot+vendor+system (no factory substitution). For RCA HOLD H3 — does ABL accept the GT test-key boot chain once `avb_custom_key` is flashed? |

Each ships its own `README-FLASH-DESKTOP.md` with the exact
`REMOTE_BUILD_DIR`/`REMOTE_KEY_DIR` override commands to flash it via
**`flash-from-remote.sh` only** (no new script — the existing script already
supports directory overrides; this is not a code change).

The pre-existing, undocumented `releases/desktop-flash/rango-stocksuper-avbok`
and `rango-hybrid-081848-avbok` directories (left over from the pre-cleanup
sprint) are **superseded** by the new, complete, documented
`rango-avbcontrol-20260801-072014` bundle above. They were left in place
(not deleted) — deletion of release artifacts is out of scope for this task
(handled by `T-RANGO-SCRIPT-CLEANUP`, which only covered `scripts/`).

---

## 2. Residual gap — analysis and HOLD (no device available)

**Architect binding (verbatim):** *"A prior hybrid with MATCH hashes still
hit init `0x7f00`. Re-graft alone is NOT sufficient as the sole 'fix'."*

### 2.1 What this task could verify without a device

- The **primary root cause** (sepolicy hash mismatch → runtime `secilc` →
  `exec` failure → exit 127) is closed: the current OUT hashes MATCH
  natively, and the shipped `rango-latest` vendor image was re-verified
  post-graft, post-`img2simg` to still MATCH.
- The **MTE/`memtag_heap` contributing cause** is closed: device-layer
  strips are intact and binary-level `.note.android.memtag` scan is clean.
- `rango-latest` is coherent (one staging run, one `cmp`-gated graft, single
  timestamp) and now has every file `flash-from-remote.sh` requires
  (§1.3 fix).

None of this can prove a **live boot** — this build host has no `fastboot`
binary and no device attached (`adb devices` empty; verified this task). The
Architect's binding is explicit that a passing hash gate is not proof of a
working boot chain, and the RCA's own HOLD items (H1–H5) were never closed
with real device evidence — they were carried over unconfirmed from
per-sprint chat summaries. This task does not manufacture that evidence.

### 2.2 HOLD — exact commands for the next session with a device (H1–H5)

Run **in order**. `REMOTE_BUILD_DIR`/`REMOTE_KEY_DIR` point at whichever
bundle is being tested; `DEVICE=rango` is always set. All commands still go
through `flash-from-remote.sh` — no ad-hoc fastboot flashing.

```bash
# --- H1/H2: does the CURRENT rango-latest (hybrid) reach a live boot? ---
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-latest
export REMOTE_KEY_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-latest
DEVICE=rango bash scripts/flash-from-remote.sh
# If it lands in fastboot (exit code 2) or times out (exit code 3):
fastboot oem dmesg                      # H1: capture the exact kill-init line
# If adb is reachable via stock recovery instead:
adb shell cat /sys/fs/pstore/console-ramoops-0   # H2: secilc/linker/ENOEXEC evidence

# --- H3: does ABL accept the FULL-GT boot chain once avb_custom_key is set? ---
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-fullgt-20260801-072051
export REMOTE_KEY_DIR=$REMOTE_BUILD_DIR
DEVICE=rango bash scripts/flash-from-remote.sh
fastboot oem dmesg                      # H3: ABL decision code with GT boot + custom key

# --- AVB-path isolation control (Architect binding item 2) ---
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-avbcontrol-20260801-072014
export REMOTE_KEY_DIR=$REMOTE_BUILD_DIR
DEVICE=rango bash scripts/flash-from-remote.sh
adb devices                             # boots? → AVB path OK, isolates fault to GT system*

# --- H4: after ANY successful boot, prove userspace beyond init ---
adb shell getprop ro.build.fingerprint
adb shell am start -a android.intent.action.MAIN   # fold/UI smoke

# --- H5: compare factory vs GT vendor_dlkm module load on first boot ---
adb shell lsmod
```

### 2.3 Decision table for whoever runs H1–H5

| Outcome | Conclusion | Next action |
|---------|------------|--------------|
| `rango-latest` (hybrid) boots to `adb` | Fix is complete; residual gap was stale/sprint-summary evidence, not reproducible on the corrected graft | Close `Q-RANGO-BOOT` PASS |
| `rango-latest` fails, `avbcontrol` boots | AVB path OK; fault isolated to GT `system*` content vs factory vendor pairing | New root-cause task scoped to system/vendor ABI or SELinux domain mismatch (not sepolicy hash) |
| `rango-latest` fails, `avbcontrol` also fails | AVB/bootloader path itself implicated, independent of GuardTalkOS content | Escalate to bootloader/AVB config investigation before further userspace work |
| `rango-fullgt` reaches fastbootd/boots | ABL accepts GT test-key boot chain post-`avb_custom_key` — full-GT path viable, hybrid factory-boot workaround may be retired | Re-scope future rango tasks to full-GT build (simpler, no graft needed) |
| `rango-fullgt` is rejected by ABL (G-logo loop, never reaches fastbootd) | Confirms RCA §1 contributing cause; factory-boot hybrid remains the only viable interim path | No action — hybrid stays default |

No PASS is claimed for any of the above without live `adb`/`fastboot`
evidence, per the forbidden-actions list.

### 2.4 On-device evidence (2026-08-01 / 2026-08-02) — CLOSED for AVB control

| Probe | Result | Evidence |
|-------|--------|----------|
| H1 — `rango-latest` hybrid | **FAIL** — G → fastboot; `KP: Attempted to kill init! exitcode=0x00007f00`; `Last AVB: avb_ret=OK` | Mac flash log + `fastboot oem dmesg` (2026-08-01) |
| AVB control — `rango-avbcontrol-20260801-072014` | **PASS** — device booted stock AOSP / Android UI | Operator report 2026-08-02 (same Flags:3 + test-key + `avb_custom_key` flash path via `flash-from-remote.sh`) |

**Conclusion (decision table row 2):** AVB / bootloader / flash posture is **exonerated**. The residual `0x7f00` is isolated to **GuardTalkOS `system` / `system_ext` / `product` content** (or GT logical composition inside hybrid `super`), not sepolicy hash mismatch alone and not Flags:3 AVB.

**Next work (new task, not this FIX):** root-cause GT userspace vs factory — init/linker/`secilc`/VINTF/property/ABI differences; bisect hybrid `super` (e.g. stock system* + GT product, or vice versa) still via `flash-from-remote.sh` + staging only. Do **not** re-open AVB as primary.

### 2.5 Fix candidate staged (2026-08-02) — `MODE=gtuserspace`

**Root cause refinement:** Offline `secilc` of GT plat CIL + **factory** vendor CIL fails
(`hal_audio_default` resolve). Hybrid graft loaded GT precompiled onto factory
vendor binaries — hashes MATCH but policy/binary pairing is incoherent → early
init death `0x7f00`.

**Fix attempt:** `MODE=gtuserspace` — factory CP1A **boot** + **all** GT logicals
from one OUT (no factory-vendor graft). `rango-latest` → `rango-20260802-060841`.

**On-device (2026-08-02):** `gtuserspace` still **FAIL** — same `0x7f00`, AVB OK.
Conclusion: failure is **not** limited to factory-vendor graft; GT
`system`/`system_ext`/`product` (and/or factory-boot + GT-userspace pairing)
still kills init.

**On-device (2026-08-02) — fullgt:** `rango-fullgt-20260801-072051` flash
completes; boot returns to fastboot (~31s). `fastboot oem dmesg` shows
`Slot A: … 0 retries left`, `A/B: force ABL into fastboot`,
`AB Decisions: 11311112` — **ABL rejects GT boot** (no kernel/`0x7f00` in that
dump). Decision-table row 5 confirmed. **Do not use fullgt as a fix path.**

**Follow-up staging (2026-08-02):** `MODE=gtuserspace` now pairs **factory
dlkm** with factory boot (GT dlkm vermagic `6.6.139+RANDSTRUCT` ≠ factory
kernel `6.6.102`), re-inserts stock `restorecon /metadata` before
`apexd-bootstrap`, strips `.note.android.memtag` from bpfloader/netd/ip*, and
adds `guardtalk-memtag.mk` (`PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS`).

**On-device (2026-08-02) — patched gtuserspace `rango-20260802-093541`:** still
**FAIL** — `KP: … exitcode=0x00007f00`, `Last AVB: avb_ret=OK`, factory kernel
`6.6.102`. So factory-dlkm + restorecon + memtag strip are **not sufficient**.

**Next bisect (`rango-latest` → `rango-20260802-103641`):** keep GT init + GT
logicals; replace **bootstrap linker64 + `/system/lib64/bootstrap/*`** with
stock factory copies (GT bootstrap `libc.so` is larger / GrapheneOS-hardened;
stock is what avbcontrol boots). Also drops GuardTalk/userdebug-only init
`.rc`s. Fallback stamp with stock init too: `rango-20260802-103554`.

**On-device (2026-08-02) — stock-bootstrap `rango-20260802-103641`:** escaped
`0x7f00` but failed ~18s with **`Reboot mode: 0xfc - bootloader`** /
`fastboot enter reason: reboot bootloader` / `AB Decisions: 13311111`.
**Named root cause:** service `apexd-bootstrap` (`/system/bin/apexd --bootstrap`)
`reboot_on_failure reboot,bootloader,bootstrap-apexd-failed` — the only early
service that reboots specifically to **bootloader**.

**Durable staging attempt (T-RANGO-BOOT-DEEP → `rango-20260802-111004`):**
`MODE=gtuserspace` applied stock bootstrap + drops `com.android.virt.apex`.
OUT builds `apexd` with `RELEASE_AVF_ENABLE_EARLY_VM=true` →
`kBootstrapApexes` includes `com.android.virt`.

**On-device (operator Mac, 2026-08-02T12:35Z) — `rango-20260802-111004`:**
still **FAIL** ~18s with `Reboot mode: 0xfc - bootloader` /
`fastboot enter reason: reboot bootloader` / `AB Decisions: 11111111` /
**no** `0x7f00`. **Virt-drop alone is insufficient.** Residual suspects:
GT bootstrap `runtime` / `i18n` / `tzdata` (or `apexd` itself).

**T-RANGO-BOOT-APEX stamp `rango-20260802-123756` (`MODE=novirtstockapex`):**
drop virt + stock runtime/i18n; GT tzdata kept (prior note assumed stock
tzdata6 package name differed — **corrected** below).

**On-device (operator Mac, 2026-08-02T13:01Z) — `rango-20260802-123756`:**
still **FAIL** ~18s with `Reboot mode: 0xfc - bootloader` /
`fastboot enter reason: reboot bootloader`. Logicals **were** flashed.
**Stock runtime/i18n insufficient.** Class same as `111004`/`103641`,
**not** `0x7f00`.

**Decisive tzdata bisect (T-RANGO-BOOT-FINAL):** stock file
`com.google.android.tzdata6.apex` has manifest name **`com.android.tzdata`**
(`deapexer info` on factory system.img). Graft stock bytes →
`/system/apex/com.android.tzdata.apex`. OnBootstrap drop is skip-safe but
unused (keep timezone content). No VNDK apexes; no manifest
`bootstrap()`/`vendorbootstrap()` flags on `123756` scan.

**Durable fold:** `MODE=gtuserspace` now permanently drops virt **and** grafts
stock tzdata → runtime → i18n (debugfs write **order matters**: tzdata after
runtime/i18n corrupts earlier apex payloads — hard `cmp` gate after graft).
GuardTalkOS system*/product/vendor retained. Staged + linked:
`rango-latest` → `rango-20260802-130756`. Host gates PASS.

**On-device (operator Mac, 2026-08-02T13:25Z) — `rango-20260802-130756`:**
still **FAIL** ~18s with `Reboot mode: 0xfc - bootloader` /
`fastboot enter reason: reboot bootloader` / `AB Decisions: 11111111` /
**not** `0x7f00`. Flash OK through step 8; step 9 → fastboot.
**FINAL hypothesis CLOSED/FALSIFIED:** GT tzdata was **not** the sole
remaining named-bootstrap cause (all named `kBootstrapApexes` were stocked).

**T-RANGO-BOOT-APEXD bisect (`MODE=stockapexd` →
`rango-20260802-132759`):** durable gtuserspace composition + graft stock
`/system/bin/apexd` (hard `cmp` vs `rango-stock-userspace` →
`apexd_stock_MATCH`, size 1083368). Disk: GT apexd on `130756` was 1030416
≠ stock; `apexd.rc` MATCH; 34-apex deapexer scan had **zero**
`bootstrap:true`. `--link-latest` **refused** (exit 1). Host E2E **49/0**.
`rango-latest` **unchanged** → `130756`. Flash via `REMOTE_BUILD_DIR` only.

**On-device (operator Mac, 2026-08-02T14:12Z) — `rango-20260802-132759`:**
build dir confirmed in log; still **FAIL** ~18s with `Reboot mode: 0xfc -
bootloader` / `fastboot enter reason: reboot bootloader` /
`AB Decisions: 11111111` / **not** `0x7f00`. **Stock-apexd-sole FALSIFIED.**
Architect disk binding on stamp: `apexd` MATCH stock; `apexd.rc` MATCH;
`/system/bin/init` DIFFERS (2938144 vs 2771368).

**T-RANGO-BOOT-INIT bisect (`MODE=stockinit` →
`rango-20260802-141438`):** stockapexd composition + graft stock
`/system/bin/init` (hard `cmp` vs `rango-stock-userspace` →
`init_stock_MATCH`, size 2771368). Stamp also keeps `apexd_stock_MATCH`
(1083368) and `apexd.rc` MATCH; virt absent. `--link-latest` **refused**
(exit 1). Host E2E **49/0**. `rango-latest` **unchanged** → `130756`.

**On-device (operator Mac, 2026-08-02T15:01Z) — `rango-20260802-141438`:**
build+key dirs both `…/141438` confirmed; flash 1–8 OK; **FAIL ~61s** with
`KP: Attempted to kill init! exitcode=0x00000100` / `Reboot reason: 0xbaba`
Kernel PANIC / `Reboot mode: 0x0` (NOT `0xfc`) / `AB Decisions: 11111133` /
fastboot enter `DBL request`. **Stock-init-sole FALSIFIED** — graft changed
failure class (did not cure). Do **not** promote stockinit as latest.

**T-RANGO-BOOT-POSTINIT bisect (`MODE=stockapexcfg` →
`rango-20260802-150440`):** stockapexd composition with **GT
`/system/bin/init` retained** (no stock init binary) + graft stock
`/system/etc/init/hw/init.rc` (early `perform_apex_config` /
`apexd-bootstrap` script surface; hard `cmp` vs `rango-stock-userspace` →
`initrc_stock_MATCH`, size 57115). Stamp keeps `apexd_stock_MATCH`
(1083368); virt absent; init size 2938144 (= `132759` GT init, ≠ stock /
`141438`). `--link-latest` **refused** (exit 1). Host E2E **49/0**.
`rango-latest` **unchanged** → `130756`.

**On-device (operator Mac, 2026-08-02T15:26Z) — `rango-20260802-150440`:**
build+key dirs both `…/150440` confirmed; flash 1–8 OK; **FAIL ~18s** with
`Reboot mode: 0xfc - bootloader` / `fastboot enter reason: reboot bootloader`
/ `AB Decisions: 13311111` / **not** KP `0x00000100` / **not** `0xbaba`.
**Stockapexcfg-sole (stock init.rc graft) FALSIFIED** — returned to
apexd-bootstrap `0xfc` class. Do **not** promote stockapexcfg as latest.

**T-RANGO-BOOT-HWASAN bisect (`MODE=stockhwasan` →
`rango-20260802-153335`):** stockapexcfg base (stock apexd + GT init +
stock init.rc + stock runtime/i18n/tzdata) + graft stock
`/system/lib64/bootstrap/hwasan/libc.so` (hard `cmp` →
`hwasan_libc_stock_MATCH`, size 1674080) and verify bootstrap
`libclang_rt.hwasan-aarch64-android.so` MATCH stock (1248776). Host disk on
`150440`: runtime apex `requireNativeLibs` already includes
`libclang_rt.hwasan-*` (stock==GT list); bootstrap hwasan-rt already stock;
**named gap** was GT `bootstrap/hwasan/libc.so` (1706096 vs 1674080).
`--link-latest` **refused** (exit 1). Host E2E **49/0**. `rango-latest`
**unchanged** → `130756`. Flash via `REMOTE_BUILD_DIR` only. Never `fullgt`
as latest.

**On-device (operator Mac, 2026-08-03) — `rango-20260802-153335`:**
GrapheneOS-parity flash confirmed (dual-slot BL, `oem uart disable`,
`erase dpm_a`/`dpm_b`); Slot B `fastboot ok`. **FAIL ~18s** with
`Reboot mode: 0xfc` / `fastboot enter reason: reboot bootloader` /
`AB Decisions: 11111111` / **not** KP `0x00000100`. DPM `err -7` still
logged (empty SBDP after erase — not sole RC).
**Stockhwasan-sole FALSIFIED. GrapheneOS flash-parity-sole FALSIFIED.**
Do **not** promote stockhwasan as latest.

**T-RANGO-BOOT-SELINUX bisect (`MODE=stockselinux` →
`rango-20260803-044126`):** stockhwasan base +
coherent stock early-apex SELinux graft:
- stock `plat_file_contexts` (named: `/dev/block/mapper/.*\.apex` →
  `apex_dm_device` — ABSENT on GT `153335`)
- stock `plat_sepolicy.cil` + mapping + sha256 (named: type
  `apex_dm_device` ABSENT on GT — 0 vs 16 refs)
- stock `system_ext` / `product` sepolicy.cil + file_contexts + mapping +
  sha256
- stock vendor `precompiled_sepolicy` + 3 sha256 (hard hash MATCH vs
  grafted partitions — plat-alone would force secilc → `0x7f00`)
- `restorecon /metadata` retained (already on stock init.rc)
- GT `/system/bin/init` retained; `--link-latest` **refused**

**On-device (operator Mac, 2026-08-03) — `rango-20260803-044126`:**
official-aligned script confirmed (`avb_custom_key` erase→flash at official
position ✓, single vbmeta pass ✓; GrapheneOS A/B+uart+dpm parity retained).
**FAIL ~18s** with `Reboot mode: 0xfc` / `fastboot enter reason: reboot
bootloader` / `AB Decisions: 11111111` / **not** KP `0x00000100`.
**Stockselinux-sole FALSIFIED** — the whole stock sepolicy stack is not the
`0xfc` cause (matches DR-RANGO-10DAY-RCA RQ4: `apex_dm_device` unreachable
with `mount_before_data=false`). Harvest: `oem ramdump klog` → `Google
internal device only.` (gated, dead on production); `oem bcd read *` →
empty; ramoops-via-recovery pending by operator. Do **not** promote
stockselinux as latest.

**T-RANGO-BOOT-APEXSET bisect (`MODE=stockapexset`):** durable gtuserspace
composition (factory boot/dlkm + GT system*/product/vendor + restorecon
/metadata + memtag strips + stock bootstrap linker/libs + GT-only rc drop;
GT `apexd` / GT `init` / GT `init.rc` retained) PLUS **stock `/system/apex`
wholesale** — every GT-repacked APEX removed, ALL stock `.apex` files from
the canonical stock donor `releases/desktop-flash/rango-stock-userspace`
(factory CP1A.260505.005; same donor used by every prior stock graft in
`stage-rango-release.sh`) grafted under their stock filenames
(`com.google.android.*`, incl. `com.google.android.tzdata6.apex` whose
manifest name is `com.android.tzdata`, and `com.google.android.virt.apex` —
making `/system/apex` byte-identical to the `avbcontrol` PASS composition;
apexd bootstrap matches by **manifest name**, `apexd.cpp:168-210`, so stock
filenames activate exactly as on the PASS control). Hard gates: per-file
sha256 vs stock source re-dumped **after all writes** (debugfs write-order
bug class that corrupted `130338` — writes issued smallest-first, the order
proven safe on `130756`); count gate (N stock apexes present, 0 GT apexes
remain); `--link-latest` **refused** (exit 1). `rango-latest` **unchanged**
→ `130756`. Flash via `REMOTE_BUILD_DIR` only.

**On-device (operator Mac, 2026-08-03) — `rango-20260803-130329`:**
one-command auto-harvest captured the failed boot's `oem dmesg`
(`harvest-rango-20260803-183432/oem-dmesg.txt`). **FAIL ~18s** with
`Reboot mode: 0xfc` / `fastboot enter reason: reboot bootloader` /
`AB Decisions: 11111111` / **not** KP `0x00000100`. **Cross-bind:**
`044126` (stock sepolicy + GT apexes) FAIL × `130329` (GT sepolicy + stock
apexes wholesale) FAIL → **bootstrap-set APEX content FALSIFIED as sole
cause** (RQ4 #2 closed). The `0xfc` trigger is not in `/system/apex`
content and not in the sepolicy stack. Do **not** promote stockapexset as
latest. Auto-harvest v1 learnings: BCB write accepted but NOT honored (bcd
unreliable on this ABL); rescue boot + GT super also `0xfc` → recovery via
**BUTTON COMBO** (script prints it); ramdump klog gated. Operator recovery-
adb console harvest in progress (may refine, does not invalidate the
stockvendor probe).

**T-RANGO-BOOT-STOCKVENDOR bisect (`MODE=stockvendor` →
`rango-20260803-145117`):** durable gtuserspace composition (factory
boot/dlkm + GT system*/product + restorecon /metadata + memtag strips +
stock bootstrap linker/libs + GT-only rc drop + drop virt + stock
runtime/i18n/tzdata; GT `apexd` / GT `init` / GT `init.rc` retained) PLUS
**factory `vendor.img` WHOLESALE** from the canonical stock donor
(`releases/desktop-flash/rango-stock-userspace`, factory CP1A.260505.005 —
same donor as APEXSET) — RQ4 #1 (prime): loop-device/ueventd coldboot
handoff **environment** (vendor carries `ueventd.rc` / `fstab` /
`init.*.rc` / VINTF; never swapped in the gtuserspace era). Hard gates:
**sha256 vs donor** on the work image AND on the shipped `vendor.img`
(`d8184b2b…` == donor; `vendor_a` extracted from the shipped `super.img`
independently re-hashed == donor); **e2fsck rc≤2** on a throwaway copy
(e2fsck rewrites the superblock even on a clean rc=0 run — measured
2026-08-03 — so the grafted image itself is never fsck'd, preserving
byte-identity); `--link-latest` **refused** (exit 1). Super geometry
measured: stock vendor 1,009,041,408 B vs GT 915,238,912 B (+89.5 MiB);
group total 3,243,409,408 B vs group_size 8,527,020,032 B → ~5.0 GiB
headroom, so the stockapexset +384MiB grow/resize fix is **not** needed;
lpmake partition sizes follow the work image (`vendor_a` =
1,009,041,408 B). `rango-latest` **unchanged** → `130756`. Flash via
`REMOTE_BUILD_DIR` only. Vendor diff analysis (ueventd.rc / fstab /
init rc / VINTF / loop-dm lines): **RCA §1.0.1** — headline: all static
coldboot config **byte-identical** GT vs stock; the probe isolates vendor
binary/lib/firmware content. **Composition risk (documented):** stock
vendor precompiled sha256 ≠ GT system* sha256 → on-device policy-compile
fallback (GT plat CIL + factory vendor CIL fails offline secilc,
`hal_audio_default`) — a FAST `0x7f00`/KP failure (not ~18s `0xfc`) means
the sepolicy incoherence fired, not the loop/ueventd test. Sufficiency
**UNPROVEN** until Mac flash.

**Ordered next probes (after `stockapexset` on-device bind):**
1. ~~`perform_apex_config` / early `init.rc`~~ → **falsified** (`150440`)
2. ~~hwasan deps for runtime ActivatePackage~~ → **falsified** (`153335`)
3. ~~SELinux early-apex / whole sepolicy stack~~ → **falsified** (`044126`)
4. ~~named bootstrap apexes (runtime/i18n/tzdata)~~ → **falsified** (`130756`)
5. ~~Bootstrap-set APEX content (wholesale `/system/apex`)~~ → **falsified** (`130329`)
6. Loop-device/ueventd coldboot handoff **environment** (RQ4 #1) →
   **staging now** (`MODE=stockvendor` → `145117`); needs klog/ramoops
   discriminator: `Loop device N not ready` / `Coldboot took` /
   `Failed to activate apexes: <pkg>`
7. GT-built monolithic super geometry (common artifact; isolated next if
   stockvendor FAILs `0xfc`)
8. `user` vs `userdebug`; APEX signing/manifest keys

DPM `err -7` non-primary (empty SBDP after erase).

**Device recovery if stuck in forced fastboot:**
`fastboot set_active a` then flash — flashing only `vendor_boot` is not enough.

### 2.6 Decision table — `0x7f00` vs `0x00000100` vs reboot-bootloader (`0xfc`)

| Evidence | Meaning | Next |
|----------|---------|------|
| `KP … exitcode=0x00007f00` | init/exec death (historical hybrid / unpatched gtuserspace) | stock bootstrap path |
| `Reboot mode: 0xfc` + `reboot bootloader` on `103641` | **`apexd-bootstrap` intentional reboot** | drop virt |
| `111004` novirt still `0xfc` ~18s (`AB 11111111`) | virt-drop **insufficient** | stock runtime/i18n |
| `123756` novirt+stock runtime/i18n still `0xfc` ~18s | runtime/i18n **insufficient** | stock tzdata graft |
| `130756` gtuserspace (novirt+stock tzdata/runtime/i18n) still `0xfc` ~18s | **tzdata-sole FALSIFIED** | stock `apexd` (`MODE=stockapexd`) |
| `132759` stockapexd still `0xfc` ~18s (`AB 11111111`) | **stock-apexd-sole FALSIFIED** | stock `init` (`MODE=stockinit`) |
| `141438` stockinit KP `0x00000100` ~61s (`0xbaba`, mode `0x0`) | **stock-init-sole FALSIFIED** (class changed) | stock `init.rc` (`MODE=stockapexcfg`) |
| `150440` stockapexcfg still `0xfc` ~18s (`AB 13311111`) | **stockapexcfg-sole FALSIFIED** | hwasan native deps (`MODE=stockhwasan`) |
| `153335` stockhwasan + GrapheneOS flash parity still `0xfc` ~18s (`AB 11111111`) | **stockhwasan-sole + flash-parity-sole FALSIFIED** | SELinux early-apex (`MODE=stockselinux`) |
| `044126` stockselinux (whole stock sepolicy stack) still `0xfc` ~18s (`AB 11111111`) | **stockselinux-sole FALSIFIED** — sepolicy as sole cause dead | stock `/system/apex` wholesale (`MODE=stockapexset`) |
| `130329` stockapexset (stock `/system/apex` wholesale) still `0xfc` ~18s (`AB 11111111`, harvest oem-dmesg) | **APEX-content-sole FALSIFIED** (044126 × 130329 cross-bind) | factory `vendor.img` wholesale (`MODE=stockvendor`) |
| `stockvendor` stamp `145117` (REMOTE_BUILD_DIR) | host-staged bisect (vendor sha256 == donor, super `vendor_a` == donor) | **Mac flash** → adb or HOLD+dmesg/ramoops; FAST `0x7f00`/KP = documented sepolicy-compile incoherence, NOT the loop/ueventd result |
| `AB Decisions: 11311112` + no KP | ABL rejected GT boot (fullgt) | never `rango-latest`→fullgt |
| avbcontrol reaches UI | AVB/Flags:3/`avb_pkmd` OK | do not re-open AVB |
| New stamp reaches `adb` | stock vendor environment validated as `0xfc` trigger | fold into `gtuserspace` + `--link-latest` (Architect) |

---

## 3. Acceptance criteria checklist

- [x] Staging recipe/helper under `vendor/guardtalk/` with hard sepolicy `cmp` gate — `vendor/guardtalk/scripts/stage-rango-release.sh`
- [x] Coherent `rango-<stamp>` + `rango-latest` symlink — `rango-20260801-071754`
- [x] Residual gap addressed — control (`avbcontrol`) + full-GT (`fullgt`) diagnostic stamps staged and documented; exact HOLD commands for H1–H5 above
- [x] Flash path = `flash-from-remote.sh` only — zero new `scripts/flash-*.sh`; both kept copies (`scripts/` and `vendor/guardtalk/scripts/`) untouched except this doc's usage examples
- [x] MTE/`memtag_heap` strips not regressed — verified + gated in staging script
- [x] On-device boot evidence — H1 FAIL (`rango-latest` → `0x7f00`); AVB control PASS (stock AOSP boot 2026-08-02); see §2.4

## 4. Gate 5 (self-critique)

| Criterion | Score | Note |
|-----------|-------|------|
| Sepolicy gate re-verified on shipped artifact (not just intermediate) | 95 | `debugfs dump` + `cmp` against final sparse `vendor.img` |
| MTE non-regression verified | 95 | Source strips + binary ELF-note scan, both automated in the gate function |
| Residual-gap diagnostics | 90 | Two complete, documented, flashable control bundles staged; cannot close H1–H5 without hardware (disclosed, not hidden) |
| Flash-path integrity | 95 | Found and fixed a real missing-firmware bug in the previous `rango-latest`; file-by-file checked against `flash-from-remote.sh`'s own download list |
| Scope discipline (no new `scripts/flash-*.sh`, no doctrine edits, no commits) | 100 | Verified |
| Naming / exit criteria | 95 | `rango-latest` → `rango-YYYYMMDD-HHMMSS`, no experimental suffix |

**Gate 5 aggregate: 95%** — **REVIEW** (Architect approves).

---

*T-RANGO-BOOT-FIX — Backend Engineer — 2026-08-01*
