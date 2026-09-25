# T-REMEDIATE-B6-FASTBOOT-RC — host evidence & operator capture

**Task:** `T-REMEDIATE-B6-FASTBOOT-RC` (Backend, Panel 2)
**DEC:** DEC-REMEDIATE-019 · **Sprint:** B6 — komodo boot-logo → fastboot remediation
**Device:** Pixel 9 Pro XL `komodo`, serial `54111FDAS000GN`, unlocked, `userdebug`, `ro.boot.verifiedbootstate=orange`
**Flashed stamp:** `releases/desktop-flash/komodo-debug-20260919-080101` (`komodo-debug-latest` → that stamp)
**Status:** `REVIEW` (never `APPROVED`) · **PASS HOLD remains** · **No commit** · **No USB from build host**
**Gate -1:** in-process from `.aegis/governance/` (24 laws + 11 gates). No `aegis-verifier` / `ask_guardian` / `gate_enforcer` MCP.
**Date:** 2026-09-19T16:08:39Z

> Scope note: this file is **host-side analysis + operator procedure**. The build
> host has no USB and cannot see the device. Nothing here is claimed as an
> on-device PASS. All "confirm" commands below are for the operator.

---

## 0. What is already bound (not re-litigated)

- DeviceLock zygote death loop is **RESOLVED** on the flashed stamp. Captured on-device line:
  `W SystemServiceRegistry: DeviceLock APEX absent — skip DeviceLockFrameworkInitializer.registerServiceWrappers()`
  and **no** `System zygote died` line. DeviceLock is **excluded** (see §4).
- The remaining fault is **later** and unclassified.
- A **reflection**-based `SystemServiceRegistry` fix is built in `out/`
  (`BUILD_EXIT=0` 2026-09-19T09:36:37Z, `komodo`/`userdebug`) but **NOT packed**.
  Packaging is **DEFERRED** by the Architect. **I did not pack it.**
- `super.img` is legitimately absent from the debug stamp (`wipe-super` + per-partition
  logical flash). `Invalid sparse file format at header magic` on logical images is a
  known harmless fastboot notice.
- `komodo-latest` → `komodo-20260915-063833` and **must stay untouched**.
  No `FLASH_READY=true`. No retarget. No `avb.pem` handling.

---

## 1. The three `ro.guardtalk.*` SELinux property denials — classification

### 1.1 The properties are baked (verbatim)

`out/target/product/komodo/vendor/build.prop` (the build source of stamp
`komodo-debug-20260919-080101`, whose `vendor.img` mtime is 2026-09-19 07:28):

```
282:ro.guardtalk.password_only_lock=1
283:ro.guardtalk.lock_after_reboot=1
288:ro.guardtalk.auto_reboot_profiles=1
289:ro.guardtalk.auto_reboot_default_ms=28800000
```

`rg -c 'ro\.guardtalk' out/target/product/komodo/vendor/build.prop` → **35**.

Only ten lines away: `out/.../vendor/build.prop:100` etc. are irrelevant; the full
set is the contiguous GuardTalk block (lines 279–316). Source of those overrides for
**komodo** is `vendor/guardtalk/device/tokay/guardtalk-product-props.mk`, which
`vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk` includes unconditionally
(device-agnostic bridge). Definitions:

```
vendor/guardtalk/device/tokay/guardtalk-product-props.mk:17:    ro.guardtalk.lock_after_reboot=1 \
vendor/guardtalk/device/tokay/guardtalk-product-props.mk:22:    ro.guardtalk.auto_reboot_profiles=1 \
vendor/guardtalk/device/tokay/guardtalk-product-props.mk:23:    ro.guardtalk.auto_reboot_default_ms=28800000 \
```

### 1.2 There is NO SELinux label for `ro.guardtalk.*` (independently re-confirmed)

Source tree (excluding `out/`):

```
$ find . -name '*property_contexts*' -not -path './out/*' -print0 | xargs -0 grep -l 'guardtalk'
<none>
$ grep -n 'guardtalk' system/sepolicy/private/property_contexts
exit=1
```

Built (packed) contexts — **all zero**:

| Built file | `grep -c guardtalk` |
|---|---|
| `out/target/product/komodo/system/etc/selinux/plat_property_contexts` | **0** |
| `out/target/product/komodo/vendor/etc/selinux/vendor_property_contexts` | **0** |
| `out/target/product/komodo/product/etc/selinux/product_property_contexts` | **0** |
| `out/target/product/komodo/system_ext/etc/selinux/system_ext_property_contexts` | **0** |
| `out/target/product/komodo/vendor/odm/etc/selinux/odm_property_contexts` | **0** |

Prefix check: **no** entry in the built contexts is a prefix of
`ro.guardtalk.lock_after_reboot` (the only broad rule present is
`vendor.  u:object_r:vendor_default_prop:s0`, which does not match `ro.*`).
Therefore `PropertyInfoArea::GetPropertyInfo()` returns `context == nullptr`.

**Wider result (host-derived):** of the **292** properties in the built
`vendor/build.prop`, **36 are unlabeled**: the **35** `ro.guardtalk.*` entries **plus**
`ro.build.device_family`. So the 3 named denials are the *observed subset* of a
35-property class, not three isolated properties.

> Falsifier for the operator: if the captured boot log shows **exactly three**
> `Do not have permissions to set … '/vendor/build.prop'` lines and no more, this
> "all-unlabeled" model is wrong and the label analysis must be redone. Command in §3.C.

### 1.3 Why init refuses to set them (source-cited)

`system/core/init/property_service.cpp`:

```c
// LoadProperties() picks the SELinux *source* context by partition:
const char* context = kInitContext;                 // line 846
if (SelinuxGetVendorAndroidVersion() >= __ANDROID_API_P__) {
    for (const auto& vendor_path_prefix : kVendorPathPrefixes) {   // "/vendor", "/odm", ...
        if (StartsWith(filename, vendor_path_prefix)) {
            context = kVendorContext;               // line 850  (/vendor/build.prop)
        }
    }
}
...
if (CheckPermissions(key, value, context, cr, &error) == PROP_SUCCESS) {   // line 920
    (*properties)[key] = value;
} else {
    LOG(ERROR) << "Do not have permissions to set '" << key << "' to '" << value
               << "' in property file '" << filename << "': " << error;    // lines 930-931
}
```

```c
// CheckPermissions() -> CheckMacPerms()
const char* target_context = nullptr;
property_info_area->GetPropertyInfo(name.c_str(), &target_context, &type);   // line 516-517
if (!CheckMacPerms(name, target_context, source_context.c_str(), cr)) {
    *error = "SELinux permission check failed";                              // line 520
    return PROP_ERROR_PERMISSION_DENIED;
}
```

```c
static bool CheckMacPerms(const std::string& name, const char* target_context,
                          const char* source_context, const ucred& cr) {
    if (!target_context || !source_context) {
        return false;                                    // property_service.cpp:163-165
    }
    ...
}
```

`system/core/init/subcontext.h:33-34`:

```c
static constexpr const char kInitContext[]   = "u:r:init:s0";
static constexpr const char kVendorContext[] = "u:r:vendor_init:s0";
```

`system/core/property_service/libpropertyinfoparser/property_info_parser.cpp:174-190`
(`GetPropertyInfo`) sets `*context = nullptr` when `context_index == ~0u` (no match).

**Chain:** no label → `target_context == nullptr` → `CheckMacPerms()` returns `false`
→ `PROP_ERROR_PERMISSION_DENIED` with `error == "SELinux permission check failed"`
(exactly the operator-observed message) → the key is **not** inserted into the map →
it is **never** passed to `PropertySetNoSocket()` (the loop at
`property_service.cpp:1334`). Init logs and **continues** — this is a log-and-skip,
never a boot failure.

### 1.4 Verdict per denial

| Property | Label found? | Runtime value | Why | User-visible impact |
|---|---|---|---|---|
| `ro.guardtalk.lock_after_reboot` | **NO** (source + built) | **genuinely MISSING** (`getprop` empty) — the baked `=1` is **not** carried into the property area | init denies at `/vendor/build.prop` load; value never enters the map | `GuardTalkLockPolicy.isLockAfterRebootEnabled()` (lines 69–78) takes the `.isEmpty()` branch → returns `isPasswordOnlyLockEnabled()`; but `ro.guardtalk.password_only_lock` (line 282) is **also unlabeled/denied** → `getBoolean(...,false)` → **false**. Net: "strong auth after reboot" is **silently OFF / fail-open**, contradicting the policy's own "fail-closed with password-only" comment. Security-relevant. |
| `ro.guardtalk.auto_reboot_profiles` | **NO** | **genuinely MISSING** | same | `GuardTalkAutoRebootPolicy.isProfilesEnabled()` (lines 79–81) → **false** → `getEffectiveTimeoutMillis()` returns the raw value unchanged, `clampToProfileMillis()` unused, `isInExclusionWindow()` returns false. GuardTalk auto-reboot **profile clamp + exclusion windows are silently OFF**. |
| `ro.guardtalk.auto_reboot_default_ms` | **NO** | **genuinely MISSING** | same | `clampToProfileMillis()` (lines 104–113) would fall back to `DEFAULT_PROFILE_MS` (8 h) — but this path is only reached when profiles are enabled, so with `auto_reboot_profiles` denied it is **inert**. No independent user-visible effect. |

Additional consequence: `vendor/guardtalk/init/init.guardtalk.hardening.rc:31` is
`on property:ro.guardtalk.sysctl_hardening=1 && property:sys.boot_completed=1`.
`ro.guardtalk.sysctl_hardening` is one of the 35 unlabeled props → the re-assert
stanza **never fires**. The `on late-init` sysctl block still runs (fail-soft), so no
boot impact; the post-boot re-assert-by-design is inert.

### 1.5 Fix decision — **sepolicy NOT edited in this task**

The missing label is a **proven functional defect** (deterministic from source:
all 35 `ro.guardtalk.*` flags read absent at runtime). It is **not** the cause of the
reboot-to-fastboot: §1.3 shows init only logs and skips; a denied build.prop property
cannot reboot the device. Per the dispatch ("fix the missing property label **only if
proven** to be the cause"; "Otherwise document the finding and **do not** edit
sepolicy"), I did **not** edit sepolicy, because:

1. It is **not** the reboot cause (a log-and-skip path).
2. The dispatch's sepolicy target is `vendor/guardtalk/sepolicy/`, but that directory
   **does not exist** and is **not wired into the build** (`ls -ld
   vendor/guardtalk/sepolicy` → ABSENT). A label added there would be a silent no-op
   — worse than documenting (Law 3: never fail silently). The established GuardTalk
   sepolicy pattern is direct edits to `system/sepolicy/private/` (e.g.
   `service_contexts` + `service.te` for `guardtalk_config_gate`), which is **outside
   this task's target paths**.
3. A correct fix is a product-contract change (new `property_type`, `vendor_init
   property_service set` allow, 35-prop label scope) and belongs in the Architect's
   batched rebuild (DEC-REMEDIATE-019 decision 4), not in a side-effect patch.
4. On-device confirmation of the exact denial set is still pending (operator saw 3 of
   a predicted 35); patching 35 labels on an unconfirmed premise would over-fit.

**Proposed, UNAPPLIED diff (for Architect approval only — do not apply blind):**

```diff
--- a/system/sepolicy/private/property_contexts
+++ b/system/sepolicy/private/property_contexts
@@
+# GuardTalkOS product feature flags (set from /vendor/build.prop by vendor_init).
+# Without a label, init refuses them: "SELinux permission check failed".
+ro.guardtalk.                        u:object_r:guardtalk_prop:s0
+
--- a/system/sepolicy/private/property.te        (new/existing plat property type file)
+++ b/system/sepolicy/private/property.te
@@
+type guardtalk_prop, property_type;
+
--- a/system/sepolicy/private/vendor_init.te
+++ b/system/sepolicy/private/vendor_init.te
@@
+allow vendor_init guardtalk_prop:property_service set;
```

(Exact file placement and whether a dedicated type is required vs. reusing an existing
vendor property type must be validated against `neverallow` rules before build.)

### 1.6 Cross-task observation (NOT my edit)

`cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh`
currently reports **DIFFERENT** (both still `bash -n` clean). Keeping the two copies
byte-identical is owned by `T-REMEDIATE-B6-FLASH-SOP`. I did not touch either copy;
flagging so the parity task does not ship divergent copies.

---

## 2. Ranked hypotheses for boot-logo → fastboot

Observed facts (from the dispatch, bound): device reaches the GuardTalk boot logo,
`adbd` comes up ~30 s before the drop, then it returns to the fastboot/bootloader
screen; bootloader shows `slot-retry-count:a: 1`, `slot-unbootable:a: no`, ABL
`decrement active slot boot retry & force ABL into fastboot`, and
`fastboot enter reason: BL1 requested`.

The flashed `bootloader.img` (stamp `komodo-debug-20260919-080101`) literally contains
the strings `decrement active slot boot retry & force ABL into fastboot`,
`fastboot enter reason: %s`, `BL1 requested`, `slot-retry-count:`, `slot-unbootable:`,
`active slot boot ok` — i.e. the observed messages are ABL (bootloader) messages,
**not** kernel/userspace `Reboot mode` breadcrumbs.

| # | Hypothesis | Evidence **for** | Exact confirm | Exact refute |
|---|---|---|---|---|
| **H1** | **(a) Genuine userspace critical-service / `system_server` crash after `boot`** | The device reaches the logo and `adbd` (⇒ kernel + first stage + zygote + `adbd` are up). The previous failure class on this stamp line was exactly a userspace crash (DeviceLock). Excisions leave other PRODUCT-excised components (nfc/bt/fp/loc/adservices/healthfitness/ondevicepersonalization/devicelock) that could still have hard references. | `adb logcat -b all -d \| grep -nE 'FATAL EXCEPTION\|\*\*\* FATAL EXCEPTION IN SYSTEM PROCESS\|RuntimeInit\|has .reboot_on_failure. option and failed\|Watchdog\|Shutting down VM\|NoClassDefFoundError\|ClassNotFoundException'`; `fastboot oem dmesg \| grep -E 'Reboot mode\|AB Decisions'` — a userspace `reboot,*` shows **`Reboot mode: 0xfc`** and `fastboot enter reason: reboot bootloader`. | If `oem dmesg` shows **no** `Reboot mode: 0xfc` and pstore/console has no userspace `FATAL`, userspace-initiated reboot is refuted. |
| **H2** | **(b) ABL retry exhaustion / forced fastboot from a previously-counted failed boot** | `slot-retry-count:a: 1` (one left), `slot-unbootable:a: no`, ABL string `decrement active slot boot retry & force ABL into fastboot`, and `fastboot enter reason: BL1 requested`. Each failed boot decrements the counter; `--set-active` resets it. | `fastboot getvar slot-retry-count:a` (=1), `slot-unbootable:a` (=no), `fastboot oem dmesg` for the `decrement …` line, `fastboot oem bcd read command`. | If a fresh `fastboot --set-active=a` restores the count to max and the device **still** drops to fastboot immediately, exhaustion is a *presentation artifact*, not the trigger (H1/H3 remain). |
| **H3** | **(c) Wiped `userdata`/`metadata` first-boot side effect** | Flash step 3 erases `userdata` (hard `die` on failure) **and** `metadata` (warn). A `metadata` wipe discards apexd session / loop-device / checkpoint state — the rango platform's dominant `0xfc` was `bootstrap-apexd-failed`. | `adb logcat -b all -d \| grep -iE 'apexd\|vold\|fs_mgr\|Couldn.t mount /metadata\|Coldboot\|checkpoint'`; `fastboot oem dmesg \| grep -iE 'bootstrap-apexd\|apexd'`. | `adbd` being up implies `post-fs-data` completed, and `apexd-bootstrap`'s `reboot_on_failure` is a **pre-adbd** path — so H3 is **disfavoured as the primary trigger**; a later `/metadata`-dependent service crash remains possible. |
| **H4** | **Sub-case of H1 — residual hard reference to another PRODUCT-excised component** | `vendor/guardtalk/feature-excised/` excises devicelock APEX, NFC, BT, fingerprint, location, several mainline APEXes and UI apps. The DeviceLock zygote defect was exactly this class. Provenance note: the **packed** stamp's try/catch `SystemServiceRegistry` still carries the DEX constant-pool descriptor `Landroid/devicelock/DeviceLockFrameworkInitializer;` — the reflection build (unpacked `out/`) removes it, but is **not packed** (DEC). | `adb logcat -b all -d \| grep -nE 'NoClassDefFoundError\|ClassNotFound\|Failed to start service\|SystemServiceRegistry'`; `adb shell dumpsys activity exit-info`. | A clean full-buffer log with none of these patterns refutes H4. |
| **H5** | AVB / vbmeta rejection | — | — | **Already refuted:** the device reaches kernel + userspace + `adbd`, so the boot chain was accepted. `--disable-verity --disable-verification` was applied. Not a candidate. |
| **H6** | `vendor_dlkm` modules missing (`init.insmod.komodo.cfg`) → boot-logo hang | — | — | **Refuted:** the symptom is a **drop** (adbd up → fastboot), not a hang; `adbd` came up. |

**Ranking:** H1 (with H4 as its most likely concrete mechanism) → H2 (presentation /
retry accounting; may be a *consequence* of H1) → H3 (contributory at most). H1 and H2
are not mutually exclusive: a userspace crash (H1) is counted as a failed boot, and ABL
then presents fastboot via retry handling (H2). **No verdict is invented**; only the
operator capture in §3 can settle it.

---

## 3. Operator-run evidence capture (bootloader + short adb + pstore)

Device is currently in fastboot/bootloader. Run this **before** any further boot
attempt so the retry counter is captured and reset safely.

### 3.A Bootloader side (device in fastboot)

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

# The discriminator: a userspace reboot shows "Reboot mode: 0xfc";
# an ABL-forced fastboot shows the decrement/BL1 lines and NO 0xfc.
grep -E 'Reboot mode|AB Decisions|exitcode|0xbaba|0xfc|0x7f00|0x00000100|Attempted to kill|fastboot enter|BL1|decrement|slot' \
  "$CAP/oem-dmesg.txt" | tee "$CAP/discriminator.txt"
echo "evidence dir: $CAP"
```

### 3.B Reset `slot-retry-count` safely (do this BEFORE booting again)

```bash
# 1) read
fastboot getvar slot-retry-count:a           # observed: 1
fastboot getvar slot-unbootable:a            # observed: no
# 2) reset by re-selecting the SAME active slot (resets retry + unbootable for slot a)
fastboot --set-active=a
# 3) verify it is back to max
fastboot getvar slot-retry-count:a
```

**HAZARD — `fastboot --set-active` and the retry counter.** At
`slot-retry-count:a: 1`, **one more counted failure** drives the active slot to `0`.
ABL then marks slot `a` unbootable and falls through to slot `b`, which holds the
**stale** `komodo-20260915-063833` (or, if neither slot is bootable, straight to
fastboot). So:

- **Do not** reboot the device again while the counter is at 1.
- **Do** run `fastboot --set-active=a` (same slot) first — it is the safe reset.
- **Never** `fastboot --set-active=b` to "escape" a failing slot `a`: that boots the
  stale stamp and changes the evidence you are trying to capture.
- After reset, re-read `slot-retry-count:a` and only then power on.

### 3.C Short adb window (start the watcher BEFORE rebooting)

`adbd` is observed ~30 s before the drop, which is enough to grab a full-buffer
logcat. Pre-arm the watcher, then reboot to boot:

```bash
CAP=~/guardtalk-b6-adb-$(date +%Y%m%d-%H%M%S); mkdir -p "$CAP"

# fire the instant adbd appears; keep it running (streaming) so the crash is caught
( adb wait-for-device
  adb root >/dev/null 2>&1 || true
  sleep 1
  # 1) stream first (survives the drop); 2) then snapshot
  ( adb logcat -b all -v threadtime > "$CAP/logcat-stream.txt" 2>&1 & echo $! > "$CAP/logcat.pid" )
  adb shell dmesg                                   > "$CAP/dmesg.txt"         2>&1 || true
  adb shell getprop                                 > "$CAP/getprop-all.txt"   2>&1 || true
  for p in ro.build.type ro.build.tags ro.debuggable ro.boot.verifiedbootstate \
           ro.boot.slot_suffix ro.boot.bootreason ro.guardtalk.lock_after_reboot \
           ro.guardtalk.auto_reboot_profiles ro.guardtalk.auto_reboot_default_ms; do
    echo "### $p"; adb shell getprop "$p"; done   > "$CAP/getprop-key.txt"   2>&1 || true
  adb shell dumpsys activity exit-info               > "$CAP/exit-info.txt"     2>&1 || true
  adb shell dumpsys activity lastanr                 > "$CAP/lastanr.txt"       2>&1 || true
  adb shell ls -la /sys/fs/pstore/                   > "$CAP/pstore-ls.txt"     2>&1 || true
  for f in console-ramoops-0 dmesg-ramoops-0 pmsg-ramoops-0; do
    adb shell cat "/sys/fs/pstore/$f" > "$CAP/$f.txt" 2>&1 || true; done
  # 3) classification greps
  grep -nE 'Do not have permissions to set|SELinux permission check failed' "$CAP/logcat-stream.txt" \
      > "$CAP/prop-denials.txt" 2>&1 || true
  grep -nE 'FATAL EXCEPTION|System server|RuntimeInit|reboot_on_failure|Watchdog|NoClassDefFoundError|ClassNotFoundException|System zygote died' \
      "$CAP/logcat-stream.txt" > "$CAP/crash-discriminator.txt" 2>&1 || true
  echo "adb evidence dir: $CAP" ) &
```

Then boot normally. When the device drops to fastboot, run §3.A again immediately.

The **key denial re-count** (falsifier for §1.2 / §1.4) is
`"$CAP"/prop-denials.txt`: count the
`Do not have permissions to set 'ro.guardtalk…' … '/vendor/build.prop'` lines.
Host analysis predicts **35** (all `ro.guardtalk.*`); the dispatch observed **3**.

### 3.D pstore when the adb window is missed

If adbd is gone before the watcher fires, the failed boot's console lives in ramoops:

1. Buttons → **Recovery mode** → "No command" → **Power + VolUp** (userdebug recovery
   `adbd` is root).
2. Then:
   ```bash
   adb root && adb wait-for-device
   adb shell 'ls -la /sys/fs/pstore/'                 | tee "$CAP/pstore-ls-recovery.txt"
   adb shell 'cat /sys/fs/pstore/console-ramoops-0'   | tee "$CAP/console-ramoops-0.txt"
   adb shell 'cat /sys/fs/pstore/dmesg-ramoops-0'     | tee "$CAP/dmesg-ramoops-0.txt"
   adb shell 'cat /sys/fs/pstore/pmsg-ramoops-0'      | tee "$CAP/pmsg-ramoops-0.txt"
   ```
   If `console-ramoops-0` is empty, ramoops did not survive the ABL handoff; escalate to
   `fastboot oem uart enable` + USB-serial (115200 8N1) as the last resort.

> Note: the opt-in `CAPTURE_LOGS=1` path in `flash-from-remote.sh` (owned by
> `T-REMEDIATE-B6-FLASH-SOP`) automates §3.A/§3.C on the *next* flash. This §3
> procedure is for the device that is already flashed.

### 3.E How to read the result (do not invent a verdict)

| Discriminator line | Conclusion |
|---|---|
| `Reboot mode: 0xfc` in `oem dmesg` | userspace asked for `reboot,bootloader` → **H1/H4** |
| `exitcode=0x00000100` / `Attempted to kill init` | init killed → **H1** (init-stage) |
| `0xbaba` + `Reboot mode: 0x0` | kernel panic → **H1** (kernel) |
| `exitcode=0x00007f00` | init exec/`/system` mount failure → H3/H6 variant |
| `bootstrap-apexd-failed` / `apexd` | **H3** |
| only `decrement active slot boot retry` + `fastboot enter reason: BL1 requested`, **no** `0xfc` | **H2** (ABL-forced fastboot) — and if there is no userspace FATAL, re-rank |
| clean full-buffer log + `adb` shows `sys.boot_completed` never set | service hang, not crash — re-scope |

---

## 4. Explicit exclusions

- **DeviceLock zygote death loop — EXCLUDED.** The captured
  `W SystemServiceRegistry: DeviceLock APEX absent — skip DeviceLockFrameworkInitializer.registerServiceWrappers()`
  proves the DeviceLock initializer path was *reached and gracefully skipped*;
  and the captured log has **no** `System zygote died`. So `NoClassDefFoundError` in
  `SystemServiceRegistry` at zygote is **not** the current fault on the packed stamp.
  *Caveat:* the exclusion is only as strong as the capture buffer. `logcat -d`
  defaults to the main buffer and can evict the earliest lines; §3.C therefore captures
  `logcat -b all -d` (and streams). If the operator's original capture was
  main-buffer-only, re-confirm with `-b all`.
- **AVB / vbmeta rejection — EXCLUDED.** Kernel + userspace + `adbd` came up.
- **`vendor_dlkm` insmod hang — EXCLUDED.** Symptom is a drop, not a hang.
- **The three property denials — EXCLUDED as a reboot cause.** §1.3 shows a
  log-and-skip path. (They are a real, separate functional defect; §1.4/§1.5.)

---

## 5. Gate 5 — Ultimate Critique (self-score, manual)

`mcp1_ultimate_critique` / hallucination-guard MCP is absent; per dispatch Gate -1 is
in-process YAML only. Score is a manual self-assessment, not an MCP score.

**Gate 5: 90%.**

| Dimension | Assessment |
|---|---|
| Correctness / honesty | All load-bearing claims are re-executed host-side and cited (line numbers, grep counts, source constants). No on-device PASS invented. PASS HOLD intact. |
| Completeness | Ranked hypotheses with confirm **and** refute commands; explicit exclusions; per-denial classification with impact; operator capture (bootloader + adb + pstore); retry hazard; unapplied fix diff. |
| Minimal footprint (Law 6) | Only `vendor/guardtalk/docs/qa/T-REMEDIATE-B6-FASTBOOT-RC_EVIDENCE.md` (new) and an append to `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`. No source/sepolicy/script edits. |
| Reversibility (Law 11) | New/append-only files; trivially revertible. |
| Testing (Law 16) | Host verification greps re-run; `bash -n` sanity on the script (read-only). No product test suite applies (AOSP host analysis). |
| Self-doubt (Law 7) | The "all 35 denied" model is explicitly falsifiable and the falsifier is handed to the operator. The ABL `BL1 requested` semantics are **not** over-claimed. |

Deductions: the exact ABL `BL1 requested` trigger is not decoded from firmware (no
matching source in-tree); the deny-set size (35 vs 3) is host-predicted, not
on-device-confirmed.

---

## 6. Verification commands (re-run by QA)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
rg -n 'guardtalk' out/target/product/komodo/vendor/build.prop | head -40           # 35 entries
grep -c 'ro\.guardtalk' out/target/product/komodo/vendor/build.prop               # 35
find . -name '*property_contexts*' -not -path './out/*' -print0 \
  | xargs -0 grep -l guardtalk ; echo "exit=$?"                                   # none
for f in out/target/product/komodo/{system,vendor,product,system_ext}/etc/selinux/*property_contexts; do
  printf '%s: ' "$f"; grep -c guardtalk "$f"; done                                # all 0
grep -n 'target_context\|CheckMacPerms\|SELinux permission check failed' \
  system/core/init/property_service.cpp | head
grep -n 'kInitContext\|kVendorContext' system/core/init/subcontext.h
bash -n scripts/flash-from-remote.sh ; bash -n vendor/guardtalk/scripts/flash-from-remote.sh
```

*No commit. Status `REVIEW`. PASS HOLD remains.*

---

## 7. Follow-up — reader inventory (post-filing confirmation, 2026-09-19T16:13Z)

Independent reader/writer sweep run **after** the report was filed. It **confirms** the
§1 classification and **refines** the impact wording; it does **not** change any
hypothesis, exclusion, or the no-sepolicy-edit decision.

**Writers — none fall back.** The only `setprop` writers of `guardtalk` props in any
`*.rc` are persistent **Wi-Fi** props:

```
vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc:8:  setprop persist.vendor.wifi.guardtalk_gateway_only 1
vendor/guardtalk/device/komodo/init.guardtalk.wifi-gateway.rc:11: setprop persist.vendor.wifi.guardtalk_gateway_only 1
```

There is **no `setprop` for any of the three `ro.guardtalk.*` props** anywhere. Their
sole source is the baked `vendor/build.prop` line that init refuses to load — so the
"genuinely missing" verdict in §1 stands, with no `init.rc` fallback that could mask it.

**Readers — server enforcement vs. Settings UI diverge.**

| Prop | Server-side reader (authoritative) | Reads prop? | Result when denied |
|---|---|---|---|
| `ro.guardtalk.auto_reboot_profiles` | `GuardTalkAutoRebootPolicy.isProfilesEnabled()` L79-80 (prop only) | **yes, only** | **false** → `clampToProfileMillis()` / exclusion windows skipped (L123, L135) |
| `ro.guardtalk.auto_reboot_default_ms` | `GuardTalkAutoRebootPolicy.clampToProfileMillis()` L101-102 | yes | never reached (profiles false) → **inert**, as stated |
| `ro.guardtalk.lock_after_reboot` | `GuardTalkLockPolicy.isLockAfterRebootEnabled()` L70-76 | yes | empty ⇒ `isPasswordOnlyLockEnabled()` → `ro.guardtalk.password_only_lock` also denied ⇒ **false** (fail-open) |

**Refinement (settings surface).** `GuardTalkAutoRebootHelper.isProfilesEnabled()`
(`packages/apps/Settings/.../GuardTalkAutoRebootHelper.java` L44-51) is an
**overlay-bool OR prop OR policy** chain, and the GuardTalk Settings overlay *does*
set the bool:

```
vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml:342:  <bool name="config_guardtalk_auto_reboot_profiles">true</bool>
vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml:317:  <bool name="config_guardtalk_password_only_lock">true</bool>
packages/apps/Settings/res/values/config.xml:576:                             <bool name="config_guardtalk_auto_reboot_profiles">false</bool>
packages/apps/Settings/res/values/config.xml:567:                             <bool name="config_guardtalk_password_only_lock">false</bool>
```

So the **Settings UI reports Auto-reboot profiles / password-only lock as available**
(overlay bool `= true`) while the **server-side policy that performs the actual clamping
and lock enforcement reads the denied prop and stays off**. Net user-visible effect is a
**UI/enforcement divergence** for both features, not merely "off in the UI". This
strengthens the §1 impact column; it does **not** change the reboot verdict (§2–§4) or
the "do not patch sepolicy" decision (§1.5) — the divergence is a *functional defect*,
still not a *boot* cause.

**Verification re-run:** `grep -rn 'config_guardtalk_auto_reboot_profiles' --include='*.xml' .`
(excluding `out/`) returns exactly the two definitions above; `GuardTalkAutoRebootPolicy`
L79-80 and `GuardTalkLockPolicy` L65-76 contain no overlay/resource fallback.
