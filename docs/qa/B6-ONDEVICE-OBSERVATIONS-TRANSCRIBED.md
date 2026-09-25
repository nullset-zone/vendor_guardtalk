# B6 on-device observations — operator-transcribed (raw)

**Provenance: OPERATOR-TRANSCRIBED FROM TERMINAL SESSIONS — NOT machine-captured.**

**Why this file exists:** a repo-wide search during Sprint B6 found **no** persisted
artifact containing `System zygote died`, no `logcat*`/`dmesg*`/`pstore*` file, and
**no** file containing the init denial string `Do not have permissions to set`
(search returned empty). Every on-device claim in this sprint therefore rested on
log text pasted into the chat transcript and was **unanchored to any durable
artifact in-tree** — a Law 10 (audit trail) gap. This file closes that gap
partially and **honestly labels** the provenance.

Capture on device was **not** performed with `CAPTURE_LOGS=1`. Read this file as
an operator record, not as machine evidence. Independent re-derivation requires a
fresh capture (see `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`).

Device: `komodo` / Pixel 9 Pro XL, serial `54111FDAS000GN`, `userdebug`,
`ro.boot.verifiedbootstate=orange`.

---

## 1. Repo-wide search that motivated this file (Architect, 2026-09-19T16:16Z)

```
$ grep -rln 'Do not have permissions to set' . | grep -v '^./out/'
   (empty)
$ find . -maxdepth 4 \( -name '*logcat*' -o -name '*dmesg*' -o -name '*pstore*' -o -name '*boot-log*' \)
   (empty — no raw log artifact)
$ grep -rln 'System zygote died' .agent-comm vendor/guardtalk runtime .memory-bank releases
   (empty)
```

## 2. Boot state during the adb window

```
adb devices                         → 54111FDAS000GN   device
adb shell getprop sys.boot_completed → 0
adb shell getprop service.bootanim.exit
adb shell getprop init.svc.bootanim  → running
adb shell getprop ro.boot.verifiedbootstate → orange
```

Logcat (errors-only cut):

```
E hwc-display: VrrController: the first vendor present timeout is negative
E hwc-display: VrrController: the first vendor present timeout is negative
```

## 3. Zygote crash loop (the FIRST failure — since resolved for DeviceLock)

```
adb shell getprop init.svc.zygote → restarting
```

```
W Zygote : Class not found for preloading:
    android.app.ApplicationPackageManager$HasSystemFeatureQuery$$ExternalSyntheticRecord1
```

> Note: this `HasSystemFeatureQuery$$ExternalSyntheticRecord1` warning is a
> **preload miss, not proof of a crash**. The authoritative crash signal was the
> `System zygote died` line logged elsewhere in the same session.

## 4. DeviceLock skip (proof the DeviceLock excise fix took effect)

```
W SystemServiceRegistry: DeviceLock APEX absent — skip
    DeviceLockFrameworkInitializer.registerServiceWrappers()
```

No `System zygote died` appeared in the post-fix session. This is the **single**
on-device observation backing the DeviceLock fix, taken on the **try/catch**
revision — see audit MEDIUM-2: **not** provably safe across ART verify/link modes.

> **CORRECTION 2026-09-20 — this observation was FALSIFIED by machine capture.**
> `System zygote died` *was* present in the post-fix session; it simply happened
> **after** the ~30s point where the default flash script exits at the first adb
> enumeration. The DeviceLock `NoClassDefFoundError` was replaced by a
> *different* fatal — a `NullPointerException` in `ContextHubService` — which the
> DeviceLock guard had been masking. The try/catch guard itself does work
> (boot now reaches `startOtherServices`), but the conclusion "no zygote died"
> was a capture-window artifact, not a clean boot.
>
> Authoritative machine evidence:
> `.agent-comm/evidence/B6-CHRE-LOCATION-NPE-MACHINE-EVIDENCE.md`
>
> **Rule adopted:** never infer "no crash" from a default (non-`CAPTURE_LOGS`)
> run. `sys.boot_completed=1` is the only trustworthy boot signal.

## 5. The three SELinux property denials (as reported by init)

```
Do not have permissions to set ro.guardtalk.lock_after_reboot in property file
    '/vendor/build.prop': SELinux permission check failed
Do not have permissions to set ro.guardtalk.auto_reboot_profiles in property file
    '/vendor/build.prop': SELinux permission check failed
Do not have permissions to set ro.guardtalk.auto_reboot_default_ms in property file
    '/vendor/build.prop': SELinux permission check failed
```

**Adjudicated (BL-B6-1): the affected set is 35, not 3.** These three are the ones
that happened to appear in the captured window and are exactly the three names
quoted in the original dispatch narrative. Architect-verified on the packed stamp:
35 `ro.guardtalk.*` in `vendor.img` `build.prop`; **0** `guardtalk` entries across
all four packed `property_contexts`. See
`.agent-comm/evidence/B6-RO-GUARDTALK-VENDOR-INIT-LEAD.md`.

## 6. Bootloader / ABL evidence

```
slot-retry-count:a: 1
slot-unbootable:a: no
ABL: decrement active slot boot retry & force ABL into fastboot
fastboot enter reason: BL1 requested
```

Corroborated in firmware (Architect, packed `bootloader.img`, `strings` counts):
`decrement active slot boot retry`=**2**, `fastboot enter reason`=**1**,
`BL1 requested`=**1**, `slot-retry-count`=**1**, `slot-unbootable`=**1**,
`active slot boot ok`=**1**. These strings are **present in the image** — that does
not establish they were the trigger; causality still needs `oem dmesg` + BCD.

## 7. What is still MISSING (the actual falsifiers)

1. `fastboot oem dmesg` — does the reboot show `Reboot mode: 0xfc` (userspace reboot) or not (ABL-forced)?
2. `fastboot oem bcd read {command,status,recovery,stage}`
3. A full `prop-denials.txt` proving **35** denials (falsifier for BL-B6-1).
4. `dumpsys activity exit-info` / `lastanr` in the adb window.
5. `/sys/fs/pstore/*` (console-ramoops / dmesg-ramoops).

Items 1–5 are exactly what `CAPTURE_LOGS=1` now harvests. **No verdict on H1–H4
may be promoted past HOLD until at least items 1 and 3 exist.**
