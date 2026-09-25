# Komodo debug sidecar — flash-path honesty (DEC-REMEDIATE-011 + DEC-015 + DEC-017 + DEC-018)

**Task:** `F-REMEDIATE-DEBUG-ADVERTISE` (DEC-011); `F-REMEDIATE-DEBUG-PACK-HONESTY` (DEC-015 / DEC-017); `F-REMEDIATE-DEBUG-READY` (DEC-018)  
**Date:** 2026-09-19  
**Device:** Pixel 9 Pro XL (`komodo`)  
**DEC:** DEC-REMEDIATE-011; DEC-REMEDIATE-015; DEC-REMEDIATE-017; DEC-REMEDIATE-018  
**USB_GO:** false

> ## ⚠ SUPERSEDING STATUS (2026-09-21) — read before acting
>
> The live debug pointer is now
> **`releases/desktop-flash/komodo-debug-latest` → `komodo-debug-20260921-041838`**
> (was `komodo-debug-20260920-175743`, before that `komodo-debug-20260919-080101`).
>
> **Neither `080101` nor `175743` booted.** Their two failures are *different
> defects*, and the second one is the important one:
>
> - `080101` — `NullPointerException` in `ContextHubService.sendLocationSettingUpdate`
>   (`ContextHubService.java:1717`), aborting system_server at boot phase 500.
> - `175743` — carried the CHRE null-guard, and machine capture
>   (`flash-capture-komodo-20260920-222611`) **proves that guard executed on
>   device**: `I ContextHubService: LocationManager absent (location feature
>   excised) — reporting location disabled to the Context Hub` (×3, pids
>   1154/2959/3639). It could not have thrown. `Failed to boot service
>   com.android.server.ContextHubSystemService` is **absent** from that capture.
>   A *different* consumer, emitting the *same* NPE text, killed system_server.
>
> So the earlier "retargeted to `080101`" statements below are **historical**,
> and so is the claim that `175743` fixed boot. The real finding is that this is
> a **bug class**: `loc-excised.mk` removes `FusedLocation` + `FEATURE_LOCATION`,
> `SystemServer` therefore skipped `LocationManagerService` (and LMS could not
> have started anyway without a fused provider), so
> `getSystemService(LocationManager.class)` returned **null process-wide** and
> every unguarded consumer NPEs. Two flashes hit two different consumers.
>
> `komodo-debug-20260921-041838` differs from `175743` in **`system.img` and
> `vendor.img`** (2 of 20 artifacts) and restores the contract: LMS starts
> unconditionally, the fused-provider `checkState` is downgraded to a warning (a
> graceful path for a null fused provider already existed below it), and
> `ServiceConfigAccessorImpl` — the single consumer that captured
> `LocationManager` before LMS start — now resolves lazily. `FEATURE_LOCATION`
> remains `false`.
>
> It also corrects a **false claim** made below about the 35 `ro.guardtalk.*`
> property denials being "NOT fixed". They were fixed in source on 2026-09-19
> (label + `PRODUCT_SYSTEM_PROPERTIES`) and were present in `175743`; the denials
> actually came from a **stale `vendor.img`** (its `vendor/build.prop` was
> generated 2026-09-18, before the fix, and `m systemimage` never regenerates
> it). `vendor.img` was rebuilt for this stamp: `vendor/build.prop` now has 0
> `ro.guardtalk` keys, `system/build.prop` keeps all 35.
> Evidence: `.agent-comm/evidence/B6-PROP-DENIALS-STALE-VENDOR-IMG.md`.
>
> **It is unverified on device.** `DEBUG_FLASH_READY` stays **false** until a
> reflash shows `sys.boot_completed=1`. `FLASH_READY` stays **false**.
> `komodo-latest` is unchanged.
>
> Evidence: `.agent-comm/evidence/B6-CHRE-LOCATION-NPE-MACHINE-EVIDENCE.md`,
> `.agent-comm/evidence/B6-NULL-LOCATIONMANAGER-BUG-CLASS.md`,
> `.agent-comm/evidence/B6-LOCATIONMANAGER-CONSUMER-AUDIT.md`.
>
> **Never treat `adb devices` = `device` as a boot signal.** `adbd` starts
> before the framework; that false positive is what hid this bug for two
> stamps. Likewise, a fix string being present in `system.img` proves delivery,
> never execution — only an on-device log line does.

This note describes the **engineering userdebug sidecar** flash channel.
It is **not** a signed-user FLASH_READY claim.

## Gate flags (this DEC)

| Flag | Value | Meaning |
|------|-------|---------|
| `DEBUG_FLASH_READY` | **false** for `180338`; **retargeted to `komodo-debug-20260919-080101`** | **CORRECTED by DEC-REMEDIATE-019 / `T-REMEDIATE-B6-STAMP-HONESTY`.** The DEC-018 binding to `komodo-debug-20260918-180338` is **withdrawn**: that stamp is the catch-less revision, proven non-bootable (Zygote death loop). Never USB GO, never signed-user `FLASH_READY`. |
| `FLASH_READY` | **false** | Signed **user** image is **not** flash-ready (pem ABSENT; `T-REMEDIATE-B1-M` HOLD CONFIRMED) |
| `LIVE_FLASH_CLAIMED` | **false** | No live WebUSB / CLI flash was performed or claimed |

> **CORRECTION (DEC-REMEDIATE-019 / `T-REMEDIATE-B6-STAMP-HONESTY`, 2026-09-19).**
> The DEC-018 binding below is **withdrawn**. Stamp
> `komodo-debug-20260918-180338` carries the **catch-less** DeviceLock revision
> (independent `strings -a`: `DeviceLock APEX absent` count **0**, DEX
> descriptor present). It produced the on-device Zygote death loop and
> **cannot boot past the GuardTalk logo**. It is retained as evidence only
> (Law 11) and must not be flashed. The debug-sidecar readiness flag is
> **retargeted to `komodo-debug-20260919-080101`**.

`DEBUG_FLASH_READY` was set **true** by DEC-018 for sidecar stamp
`komodo-debug-20260918-180338` because **all** of the following were
Architect-**APPROVED**:

1. `T-REMEDIATE-B1-DEBUG-M` (`T-DEBUG-M`) — fresh `lunch` + `m`
2. `Q-REMEDIATE-B1-DEBUG-M` (`Q-DEBUG-M`) — independent rematch of that `out/`
3. `T-REMEDIATE-B1-DEBUG-PACK` (debug pack) — `komodo-debug-<UTCSTAMP>` + pointer
4. `Q-REMEDIATE-B1-DEBUG-PACK` (`Q-DEBUG-PACK`) — independent rematch of that pack

Items 1–4 are APPROVED, but they validated **packaging**, not bootability. The
DEC-018 readiness binding is superseded (see correction above). This is **not**
signed-user `FLASH_READY`. `USB_GO` stays **false**. `LIVE_FLASH_CLAIMED` stays
**false**. Do **not** retarget `komodo-latest`.

**Fix-variant honesty (audit MEDIUM-2).** The packed `080101` image carries the
**try/catch-only** guard. It was observed to complete **one** on-device boot
session; it is **not** provably safe across all ART verify/link modes (a
verify/link-time failure other than `NoClassDefFoundError` escapes the single
catch). The strictly-more-correct **reflection** revision (`Class.forName`,
built in `out/`, `system.img` sha256 `d36336c7…`) is **not** packed. Do **not**
describe the DeviceLock fix as "proven working".

~~T-DEBUG-PACK HOLD CONFIRMED~~ — struck. T-DEBUG-PACK is APPROVED
2026-09-18T18:52:00Z (DEC-017 honesty). Q-DEBUG-PACK is APPROVED
2026-09-19T04:14:00Z (DEC-018).

DEC-015 named the four A/B leftovers that a pack must not copy from
2026-09-15. DEC-017 supersedes the later “this-session mtime = rebuild”
reading: SHA-identical A/B after a packaging restamp is **not** a kernel
rebuild, and it does **not** require a fake new hash. That leftover SHA
HOLD residual **remains** under DEC-018.

## Two channels (do not conflate)

| Channel | Lunch | Keys / root | Desktop pointer | Ready flag |
|---------|-------|-------------|-----------------|------------|
| **Signed user** (production) | `komodo-trunk_staging-user` | release-keys; `su` / `overlay_remounter` absent | `releases/desktop-flash/komodo-latest` (after `T-REMEDIATE-B1-PACK`) | `FLASH_READY` — **false** (pem ABSENT) |
| **Debug sidecar** (lab only) | `komodo-trunk_staging-userdebug` | test-keys and `su` **allowed on this sidecar only** | `releases/desktop-flash/komodo-debug-latest` → **`komodo-debug-20260921-041838`** | `DEBUG_FLASH_READY` — **false** (unverified on device). The `080101` retarget below is historical (DEC-018/019) |

Production rules in `ENGINEERING_SIDECAR_USERDEBUG.md` are unchanged:
test-keys / `su` stay off the **user** product. They are allowed here only
because this path is the documented sidecar.

## Lunch (sidecar)

```bash
source build/envsetup.sh
lunch komodo-trunk_staging-userdebug
```

Do **not** use `lunch komodo-trunk_staging-user` for this gate. That is the
signed-user path (`T-REMEDIATE-B1-M`), still HOLD on missing `*.pem`.

## Stale Sept 15 stamp is not this gate

`releases/desktop-flash/komodo-20260915-063833` (today’s `komodo-latest`
target) is a **2026-09-15** userdebug / test-keys stamp from
`T-PORT-KOMODO-FLASH`. DEC-010 already denies it as signed-user
`FLASH_READY`.

**Do not treat `komodo-20260915-063833` as the DEC-011 / DEC-018 debug flash gate.**
It is stale. Advertising `komodo` on `/install/` does not make that stamp
`DEBUG_FLASH_READY`. DEC-017 / DEC-018: do **not** retarget `komodo-latest`
away from this name.

## DEC-015 — four A/B leftovers must not be copied as a “new” pack (historical)

**Task:** `F-REMEDIATE-DEBUG-PACK-HONESTY`  
**DEC:** DEC-REMEDIATE-015  
**USB_GO:** false

DEC-011 advertised the debug sidecar. It did **not** make a pack.
T-DEBUG-M + Q-DEBUG-M are APPROVED for r3 `m` (`system.img` /
`vbmeta.img` / `vendor.img` mtime 2026-09-18). That rematch does **not**
make the A/B leftovers flash-ready.

At the DEC-015 rematch (2026-09-18T14:49:00Z) these four files under
`out/target/product/komodo/` were still dated **2026-09-15**.
`flash-from-remote.sh` flashes this A/B set. A pack that **copies** those
Sept 15 leftovers is not a valid debug pack.

| File | DEC-015 rematch mtime (UTC, 2026-09-18T14:49:00Z) |
|------|--------------------------------------------------|
| `boot.img` | 2026-09-15 04:59:09Z |
| `vendor_kernel_boot.img` | 2026-09-15 04:59:28Z |
| `pvmfw.img` | 2026-09-15 04:59:09Z |
| `dtbo.img` | 2026-09-15 04:59:12Z |

DEC-015 required a rebuild of that set before pack. **DEC-017 below
supersedes the later reading that this-session mtime alone proves that
rebuild.** Do not treat DEC-015 as a demand for a fake new SHA.

## DEC-017 — SHA-identical A/B after packaging restamp is not a kernel rebuild

**Task:** `F-REMEDIATE-DEBUG-PACK-HONESTY`  
**DEC:** DEC-REMEDIATE-017  
**USB_GO:** false  
**Rematch:** 2026-09-18T18:24:00Z (Frontend; Architect dumps not trusted)

Live rematch of the pointers:

| Pointer | Target |
|---------|--------|
| `releases/desktop-flash/komodo-debug-latest` | **exists** → `komodo-debug-20260919-080101` (DEC-017 rematch saw `180338`; pointer since moved) |
| `releases/desktop-flash/komodo-latest` | **unchanged** → `komodo-20260915-063833` |

The debug pointer **exists**. Existence alone was **not**
`DEBUG_FLASH_READY=true` under DEC-017. ~~T-DEBUG-PACK HOLD CONFIRMED
(not APPROVED)~~ — struck. T-DEBUG-PACK is APPROVED 2026-09-18T18:52:00Z
(DEC-017 honesty). `Q-REMEDIATE-B1-DEBUG-PACK` is APPROVED
2026-09-19T04:14:00Z. DEC-018 (below) bound `DEBUG_FLASH_READY=true` to this
stamp — **since withdrawn** (see correction at top). This note does **not**
invent a stamp, SKU, or symlink.

The A/B four now have this-session **mtime** on `out/` and on stamp
`komodo-debug-20260918-180338`. That mtime is a **packaging restamp**.
It is **not** a kernel / dtbo / pvmfw rebuild.

Live SHA-256 rematch: `out/target/product/komodo/`, stamp
`komodo-debug-20260918-180338`, and Sept 15 leftovers
`komodo-20260915-063833` are **byte-identical** on the A/B four. Those
digests are the DEC-017 STALE_BAK leftovers. **Do not require a fake new
hash** (Law 8). SHA-equal after packaging-only ninja is HOLD-documented,
not a rebuild claim. **DEC-018 does not erase this HOLD residual.**

| File | SHA-256 (out/ = stamp 180338 = `komodo-20260915-063833`) |
|------|---------------------------------------------------------|
| `boot.img` | `449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc` |
| `vendor_kernel_boot.img` | `a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8` |
| `pvmfw.img` | `f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8` |
| `dtbo.img` | `742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433` |

This honesty note does **not**:

- invent a new stamp, symlink, or SKU
- retarget `komodo-latest` (still `komodo-20260915-063833`)
- require SHA ≠ STALE_BAK / a dirty `BUILD_DATETIME` just to mint a new hash
- set `FLASH_READY=true` or `LIVE_FLASH_CLAIMED=true`
- USB GO

DEC-017 itself did **not** set `DEBUG_FLASH_READY=true`. Writing the
DEC-017 section was not a pack. DEC-018 (below) was the advertise sync
that bound the flag after Q-DEBUG-PACK APPROVED — since withdrawn.

## DEC-018 — DEBUG_FLASH_READY=true for stamp 180338 (binding WITHDRAWN; superseded by DEC-REMEDIATE-019)

**Task:** `F-REMEDIATE-DEBUG-READY`  
**DEC:** DEC-REMEDIATE-018  
**USB_GO:** false  
**Rematch:** 2026-09-19T04:15:40Z (Frontend; Architect dumps not trusted)

Q-DEBUG-PACK is APPROVED. DEC-018 historically bound `DEBUG_FLASH_READY=true`
for the stamp below. **That binding is withdrawn**: `180338` is proven
non-bootable (catch-less DeviceLock revision). The debug-sidecar readiness flag
is retargeted to `komodo-debug-20260919-080101`.

| Pointer | Target |
|---------|--------|
| `releases/desktop-flash/komodo-debug-latest` | `komodo-debug-20260919-080101` (**not** `180338`; `180338` retained as evidence, do not flash) |
| `releases/desktop-flash/komodo-latest` | **unchanged** → `komodo-20260915-063833` |

This bind applied to the **debug sidecar** only. Signed-user `FLASH_READY` stays
**false**. `LIVE_FLASH_CLAIMED` stays **false**. `USB_GO` stays **false**.
No new stamp was invented. `komodo-latest` was not retargeted.

SHA==Sept 15 leftover HOLD residual (DEC-017) is **kept**: the A/B four
remain byte-identical to `komodo-20260915-063833`. That is documented, not
erased. It is **not** a kernel rebuild.

## Pointers — do not invent, do not retarget

- **`komodo-debug-latest`** is the **debug** channel name. It **exists**
  (live: → `komodo-debug-20260919-080101`). DEC-018 bound
  `DEBUG_FLASH_READY=true` to `180338` when that was the pointer; the binding is
  **withdrawn** and retargeted to the current live target. DEC-011 / DEC-015 /
  DEC-017 honesty notes did **not** create that directory or symlink.
  This DEC-018 note did **not** invent a new stamp.
- **`komodo-latest` must not be retargeted** by the debug path. It remains
  `komodo-20260915-063833` until the **signed-user** pack
  (`T-REMEDIATE-B1-PACK`) is APPROVED. Debug images never steal that name.

## Web installer / USB

DEC-011, DEC-015, DEC-017, and DEC-018 have **no USB GO**.
`LIVE_FLASH_CLAIMED` remains **false**. `FLASH_READY` remains **false**.
`DEBUG_FLASH_READY` is **false** for `180338`; for the debug sidecar it is
retargeted to `komodo-debug-20260919-080101` only.

The installer may keep listing the komodo SKU (tokay + akita + komodo [+
rango experimental]). That listing is **not**:

- a new debug SKU
- a `komodo-debug-latest` stamp invented by this note
- `FLASH_READY=true`
- `LIVE_FLASH_CLAIMED=true`
- USB GO

See `vendor/guardtalk/web-installer/README.md` (DEC-010 + DEC-011 notes).

## Rollback

Restore `DEBUG_FLASH_READY=false` and the pre-DEC-018 “stays false until
pack APPROVED” wording. Restore the struck ~~T-DEBUG-PACK HOLD CONFIRMED~~
sentence only if Architect reverts T-DEBUG-PACK / Q-DEBUG-PACK. No stamp
inode, symlink, or installer SKU was created by this advertise sync.
`komodo-latest` was not retargeted. `FLASH_READY` and `LIVE_FLASH_CLAIMED`
were not flipped. SHA leftover HOLD residual stays documented.

**DEC-REMEDIATE-019 readiness correction is documentation-only and reversible:** no
stamp, pointer, inode, or `SHA256SUMS` was touched (`180338` is retained on
purpose, Law 11). Reverting means restoring the DEC-018 binding text — but that
re-asserts a false readiness claim for a proven non-bootable stamp, so it is not
recommended.

## DEC-REMEDIATE-019 — opt-in post-flash debug capture (`CAPTURE_LOGS=1`)

**Task:** `T-REMEDIATE-B6-FLASH-SOP`
**DEC:** DEC-REMEDIATE-019
**USB_GO:** false · **FLASH_READY:** false · **LIVE_FLASH_CLAIMED:** false
**Scripts:** `scripts/flash-from-remote.sh` + `vendor/guardtalk/scripts/flash-from-remote.sh` (byte-identical)

The observed komodo failure is: the device reaches the GuardTalk boot logo,
then returns to fastboot. The flash script used to `break` at the **first adb
enumeration** (~30s) and print `flash complete`, so the later fallback was
never seen. The script now supports an **opt-in** post-flash debug capture
that closes that gap.

### Flag

| Env var | Default | Meaning |
|---------|---------|---------|
| `CAPTURE_LOGS` | **`0` (off)** | `1` enables post-flash debug capture (fastboot **and** adb) |
| `CAPTURE_POST_ADB_SECS` | `120` | Seconds to keep watching **after** adb first appears, so a later fallback to fastboot is recorded. Only honoured when `CAPTURE_LOGS=1`. |

**Default `CAPTURE_LOGS` unset/`0` leaves the flash path, logs, and exit codes
unchanged.** Capture is a GuardTalk host-side diagnostic, not a GrapheneOS SOP
step, and it does not retarget `komodo-latest` or any stamp.

### Usage

```bash
CAPTURE_LOGS=1 DEVICE=komodo ./scripts/flash-from-remote.sh
```

### What is captured

- **fastboot / bootloader:** `oem dmesg`; `oem bcd read {command,status,recovery,stage}`;
  `getvar slot-retry-count:a` / `slot-unbootable:a` (and `:b`); `getvar all`.
- **adb / Android:** `logcat -d` (full, plus errors-only); `getprop` (key
  subset + full); `dumpsys activity exit-info` / `lastanr` / `dumpsys -l`;
  `/sys/fs/pstore/*` when reachable.

### Evidence directory

Each capture run writes a timestamped local directory and prints its path:

```
<LOCAL_WORK_DIR>/flash-capture-<device>-<YYYYmmdd-HHMMSS>/
```

### Safety

- Every capture step is **best-effort**: a failure logs a warning and never
  aborts the flash (`die` is never called from capture).
- Under capture mode only, the script keeps watching for
  `CAPTURE_POST_ADB_SECS` after adb first appears; if the device then returns
  to fastboot it records `POST-ADB FALLBACK RECORDED` and reports the boot
  failure (exit 2) instead of a false `flash complete`.

### Rollback

Unset `CAPTURE_LOGS` (or set it to `0`). No stamp, symlink, or installer SKU is
created by capture. The two script copies must stay byte-identical after any
edit (`cmp -s`).

---

## Operator-run B6 boot-failure capture (T-REMEDIATE-B6-FASTBOOT-RC)

**Task:** `T-REMEDIATE-B6-FASTBOOT-RC` (DEC-REMEDIATE-019) · **PASS HOLD** remains
**Full analysis:** `vendor/guardtalk/docs/qa/T-REMEDIATE-B6-FASTBOOT-RC_EVIDENCE.md`

Symptom under investigation: flashed stamp `komodo-debug-20260919-080101` reaches the
GuardTalk boot logo, `adbd` comes up ~30 s, then the device returns to the
fastboot/bootloader screen (`slot-retry-count:a: 1`, ABL
`decrement active slot boot retry & force ABL into fastboot`,
`fastboot enter reason: BL1 requested`). This section is the **manual** capture for the
device that is already flashed. The opt-in `CAPTURE_LOGS=1` path (flash script, owned by
`T-REMEDIATE-B6-FLASH-SOP`) automates the same captures on the *next* flash.

### 1. Bootloader side (device in fastboot)

```bash
CAP=~/guardtalk-b6-$(date +%Y%m%d-%H%M%S); mkdir -p "$CAP"; cd ~/GuardTalk-flash || cd .

fastboot devices -l                     2>&1 | tee "$CAP/fastboot-devices.txt"
fastboot getvar current-slot            2>&1 | tee "$CAP/getvar-current-slot.txt"
fastboot getvar slot-retry-count:a      2>&1 | tee "$CAP/getvar-slot-retry-count-a.txt"
fastboot getvar slot-unbootable:a       2>&1 | tee "$CAP/getvar-slot-unbootable-a.txt"
fastboot getvar slot-retry-count:b      2>&1 | tee "$CAP/getvar-slot-retry-count-b.txt"
fastboot getvar slot-unbootable:b       2>&1 | tee "$CAP/getvar-slot-unbootable-b.txt"
fastboot getvar all                     2>&1 | tee "$CAP/getvar-all.txt"

fastboot oem dmesg                      2>&1 | tee "$CAP/oem-dmesg.txt"
fastboot oem ramdump klog               2>&1 | tee "$CAP/oem-ramdump-klog.txt"
for f in command status recovery stage; do
  fastboot oem bcd read "$f"            2>&1 | tee "$CAP/bcd-$f.txt"
done

# Discriminator: userspace reboot => "Reboot mode: 0xfc"; ABL-forced fastboot => no 0xfc.
grep -E 'Reboot mode|AB Decisions|exitcode|0xbaba|0xfc|0x7f00|0x00000100|Attempted to kill|fastboot enter|BL1|decrement|slot' \
  "$CAP/oem-dmesg.txt" | tee "$CAP/discriminator.txt"
echo "evidence dir: $CAP"
```

### 2. Reset `slot-retry-count` safely (BEFORE booting again)

```bash
fastboot getvar slot-retry-count:a   # observed: 1
fastboot getvar slot-unbootable:a    # observed: no
fastboot --set-active=a              # re-select the SAME slot: resets retry + unbootable
fastboot getvar slot-retry-count:a   # verify back to max
```

**HAZARD.** At `slot-retry-count:a: 1` one more counted failure drives the counter to 0;
ABL then marks slot `a` unbootable and falls through to slot `b`, which holds the
**stale** `komodo-20260915-063833` (or straight to fastboot if neither slot is bootable).
So: do **not** boot again while the counter is 1; reset with `--set-active=a` (same
slot) first; never use `--set-active=b` to "escape" a failing slot `a`.

### 3. Short adb window (start the watcher BEFORE rebooting)

`adbd` is observed ~30 s before the drop — enough for a full-buffer logcat.

```bash
CAP=~/guardtalk-b6-adb-$(date +%Y%m%d-%H%M%S); mkdir -p "$CAP"
( adb wait-for-device
  adb root >/dev/null 2>&1 || true; sleep 1
  ( adb logcat -b all -v threadtime > "$CAP/logcat-stream.txt" 2>&1 & echo $! > "$CAP/logcat.pid" )
  adb shell dmesg                       > "$CAP/dmesg.txt"       2>&1 || true
  adb shell getprop                     > "$CAP/getprop-all.txt" 2>&1 || true
  adb shell dumpsys activity exit-info  > "$CAP/exit-info.txt"   2>&1 || true
  adb shell dumpsys activity lastanr    > "$CAP/lastanr.txt"     2>&1 || true
  adb shell ls -la /sys/fs/pstore/      > "$CAP/pstore-ls.txt"   2>&1 || true
  for f in console-ramoops-0 dmesg-ramoops-0 pmsg-ramoops-0; do
    adb shell cat "/sys/fs/pstore/$f" > "$CAP/$f.txt" 2>&1 || true; done
  grep -nE 'Do not have permissions to set|SELinux permission check failed' "$CAP/logcat-stream.txt" \
      > "$CAP/prop-denials.txt" 2>&1 || true
  grep -nE 'FATAL EXCEPTION|System server|RuntimeInit|reboot_on_failure|Watchdog|NoClassDefFoundError|ClassNotFoundException|System zygote died' \
      "$CAP/logcat-stream.txt" > "$CAP/crash-discriminator.txt" 2>&1 || true
  echo "adb evidence dir: $CAP" ) &
```

Then boot normally; when the device drops to fastboot, repeat §1 immediately.
`prop-denials.txt` is the falsifier for the property-label analysis: host analysis
predicts **35** denied `ro.guardtalk.*` props, the operator observed **3**.

### 4. pstore when the adb window is missed

Buttons → **Recovery mode** → "No command" → **Power + VolUp**, then:

```bash
adb root && adb wait-for-device
adb shell 'ls -la /sys/fs/pstore/'               | tee "$CAP/pstore-ls-recovery.txt"
adb shell 'cat /sys/fs/pstore/console-ramoops-0' | tee "$CAP/console-ramoops-0.txt"
adb shell 'cat /sys/fs/pstore/dmesg-ramoops-0'   | tee "$CAP/dmesg-ramoops-0.txt"
adb shell 'cat /sys/fs/pstore/pmsg-ramoops-0'    | tee "$CAP/pmsg-ramoops-0.txt"
```

If `console-ramoops-0` is empty, ramoops did not survive the ABL handoff; escalate to
`fastboot oem uart enable` + USB-serial (115200 8N1).

This note adds **no** USB GO, does **not** retarget `komodo-latest`, does **not** flip
`FLASH_READY` / `LIVE_FLASH_CLAIMED`, and does **not** edit the flash script.
