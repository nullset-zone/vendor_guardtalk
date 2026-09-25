# A-EXCISE-RADIO — Independent Deep Tech Audit (Panel 5)

| Field | Value |
|---|---|
| task_id | `A-EXCISE-RADIO` |
| role | Auditor (Independent Deep Tech, Panel 5) |
| lane scope | Cellular / modem / RIL / IMS / IWLAN / CarrierConfig / Telecom / telephony-resource residue + `radio.img`/`modem.img` baseband-firmware question + per-device `radioExternal` HAL residue |
| owner repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id: grapheneos-worktree`) |
| audit_scope | `full` |
| status transition | READY → DISPATCHED → IN_PROGRESS → **REVIEW** |
| verdict authority | Advisory to Architect. Not `APPROVED`. |
| **Gate -1** | **IN-PROCESS** — `.aegis/governance/laws/*.yaml` (24) + `.aegis/governance/gates/*.yaml` (11) loaded. `governance_loaded=true`. No aegis-verifier / ask_guardian / gate_enforcer / Guardian HTTP was called. |
| **Gate 5** | **HUMAN SKIP** — no numeric self-critique score is invented. |
| `LIVE_FLASH_CLAIMED` | **false** — no hardware attached; no adb/fastboot executed. |
| Auditor write surface | This report + `.agent-comm/evidence/A-EXCISE-RADIO/*` + one `.agent-comm/history/` event. No product/test/filter/flash/packer/doctrine/queue-authoritative file was edited. `.agent-comm/inbox/TO_ARCHITECT.md` was **not** touched. |
| Timestamp | 2026-09-24T16:30+04:00 (host UTC 2026-09-24T12:xxZ) |

---

## 0. Claim under audit

> *Every GuardTalkOS feature that is supposed to make the OS effectively airgapped — cellular
> radio/modem/RIL/telephony, Bluetooth, Location/GNSS, and every other connectivity, telemetry
> and remote-surface service — is **100% removed** from the built image on **every** Pixel model
> GuardTalk builds.*

This lane adjudicates only the **cellular / baseband / telephony-host** slice.

### 0.1 Adjudication standard (Tier A / B / C — from `DEC-EXCISE-AIRGAP-001` §A1)

| Tier | Meaning | Acceptable for an "airgapped" claim? |
|---|---|---|
| **A — ABSENT** | Not present in the built artifacts at all | Yes |
| **B — DORMANT** | Code/firmware on disk, no transport/HAL/feature gate; not reachable at runtime | **Requires explicit operator waiver; must NOT be reported as a removal** |
| **C — REACHABLE** | Present **and can become active** | No — audit **FAIL** |

### 0.2 Audited build set

13 program devices. Gen 8 = `shiba`, `husky`, `akita`; Gen 9 = `tokay`, `caiman`, `komodo`,
`comet`, `tegu`, `stallion`; Gen 10 = `frankel`, `blazer`, `mustang`, `rango`.

The `*-latest` stamp is the provenance artifact. Note: there is **no `tokay-latest` symlink**;
`releases/desktop-flash/latest → tokay-20260725-102506` is tokay's stamp (verified
`readlink -f`).

**Gen 6 (`gs101`) / Gen 7 (`gs201`) — AUDITED ABSENCE.** No `device/google/gs101*` / `gs201*`
tree and no `gs101`/`gs201` stamp exists. This is recorded, not omitted. (Confirmed again here:
`ls device/google/` shows no gs101/gs201 family directory; `releases/desktop-flash/` has no
gs101/gs201 stamp.)

---

## 1. Radio verdict

# **FALSE**

The strict claim — *cellular radio/modem/RIL/telephony is 100% removed from the built image on
every device* — is **not supported and is falsified**, on two independent grounds:

1. **Tier C on 9/13 devices.** The kernel-side modem transport driver set — `cpif.ko`,
   `cpif_page.ko`, `shm_ipc.ko` (CP Interface / shared-memory IPC to the Communication
   Processor) — is present in the packed boot ramdisk **and listed in `modules.load`, i.e.
   loaded at boot**, on `shiba`, `husky`, `akita`, `comet`, `tegu`, `stallion`, `frankel`,
   `blazer`, `mustang`. The GuardTalk excision's *own* acceptance check #1
   (`scripts/verify-radio-excision.sh:34-35`) asserts these must be absent and **fails** here.
2. **Tier A is false on 13/13 (not merely Tier B).** The built `/vendor/etc/vintf/manifest.xml`
   is swapped to a hand-written "no-radio" file, but the runtime device manifest is
   *manifest + `/vendor/etc/vintf/manifest/` fragments*, and the surviving `vintf_fragment`
   `dmd.xml` re-declares a **telephony/modem HAL**
   (`vendor.samsung_slsi.telephony.hardware.oemservice`, `IOemService/dm0,dm1`) on **all 13**.
   The excision therefore never achieves "radio-free manifest" at runtime on any device.

**Sub-verdicts that are favourable (recorded honestly):**
- Host **RIL control plane** (`rild`, `rild_exynos`, `libril*`, `libsitril*`, `libsitril-ims`,
  `google-ril.jar`, `oemrilhook.jar`) is **genuinely Tier A** — 0/13 present in the built image
  and in the packed `vendor.img`.
- The `radio` disable feature gate `androidboot.radio.disabled=1` *is* built into the kernel
  boot config on 13/13 **in `out/`** — but it is **missing from the flashable release stamps of
  `frankel`, `blazer`, `mustang`, `rango`** (see F-005).

If the operator were to rule that a *loaded but never-opened* kernel driver plus an unpowered
modem counts as "dormant", and if the VINTF-fragment defect (F-003) and the stamp-skew defect
(F-005) were accepted as waived residuals, the verdict would degrade to
`TRUE-WITH-DORMANT-RESIDUALS`. On the standard as written it does not: Tier C is a FAIL, and the
absence claim is factually wrong.

### Severity counts

| Severity | Count | IDs |
|---|---|---|
| **CRITICAL** | **2** | F-001, F-002 |
| **HIGH** | **3** | F-003, F-004, F-005 |
| **MEDIUM** | **5** | F-006, F-007, F-008, F-009, F-010 |
| **LOW** | **2** | F-011, F-012 |
| INFO | 1 | F-013 |

---

## 2. Findings

### F-001 — CRITICAL — Kernel modem transport (`cpif`/`shm_ipc`) is present **and loaded** on 9/13 → Tier C

**Evidence (primary artifacts):**
- `out/target/product/tegu/vendor_kernel_ramdisk/lib/modules/cpif.ko` (603,793 B),
  `…/cpif_page.ko` (16,921 B), `…/shm_ipc.ko` (32,401 B) — `ls -l`.
- `out/target/product/tegu/vendor_kernel_ramdisk/lib/modules/modules.load:210-212` →
  `shm_ipc.ko`, `cpif_page.ko`, `cpif.ko` (explicit load list).
- Packed-set proof: `out/target/product/tegu/installed-files-vendor-kernel-ramdisk.txt`
  lists `/vendor_kernel_ramdisk/lib/modules/cpif.ko` etc. — i.e. these land in the packed
  `vendor_kernel_boot.img`.
- frankel/blazer/mustang carry the same three modules in `vendor_dlkm/lib/modules/` +
  `installed-files-vendor_dlkm.txt` (cpif.ko 608,609 B).
- Absent (Tier A) only on `tokay`, `caiman`, `komodo`, `rango` (no `cpif.ko`/`shm_ipc.ko`
  file anywhere under `out/target/product/<dev>/`, no `modules.load` entry, no
  `installed-files-vendor-kernel-ramdisk.txt` / `installed-files-vendor_dlkm.txt` entry).
- Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/04-kernel-cpif-modem.txt`.

**Impact.** `cpif` = Communication-Processor Interface, `shm_ipc` = shared-memory IPC to the
baseband; they are the kernel half of the modem transport. Being in `modules.load` means the
driver is active after boot, not a dormant file. Any residual userspace path (or a future
regression that re-adds one) would have a live transport. This makes 9/13 Tier C for the
cellular claim and breaks the "100% removed" wording outright.

**Recommendation.** `T-EXCISE-FW-RADIO`-class card: add `cpif.ko`, `cpif_page.ko`,
`shm_ipc.ko` (and the CPIF sysfs owner path) to the same excision mechanism that already
works on `tokay`/`caiman`/`komodo`/`rango`, then re-prove at the *packed* level
(`installed-files-*` + `debugfs` on the stamp `vendor_kernel_boot.img`/`vendor_dlkm.img`).
Until then, do not report the cellular surface as removed on the 9 affected devices.

---

### F-002 — CRITICAL — Baseband firmware `radio.img`/`modem.img` ships in every build and every stamp, and the flasher writes the `radio` partition → Tier B (waiver required), not Tier A

**Evidence (primary artifacts):**
- `out/target/product/<dev>/{radio.img,modem.img}` present for **13/13**; sizes
  98,766,988 B (`tegu`) … 191,426,700 B (`rango`). Full `ls -l` + `sha256sum` matrix:
  `.agent-comm/evidence/A-EXCISE-RADIO/01-e1-baseband-firmware.txt`.
  - `radio.img` sha256 by group: `db5a0c81…f80d` (`shiba`,`husky`); `2929f356…666f` (`akita`);
    `ca41313e…c77f` (`tokay`,`caiman`,`komodo`,`comet`); `3d11d809…4370` (`tegu`);
    `a9d1296f…7503` (`stallion`,`frankel`,`blazer`,`mustang`,`rango`).
- **Every** `releases/desktop-flash/<dev>-latest/SHA256SUMS` carries a `radio.img` line —
  13/13 (same hashes as above). No stamp contains `modem.img` (matches pre-finding E-7b).
- `vendor/guardtalk/scripts/flash-from-remote.sh:153` → `FW_IMAGES=(bootloader.img radio.img)`;
  `:937` → `"$FASTBOOT" flash radio "$LOCAL_WORK_DIR/radio.img"`. So the deployment procedure
  actively flashes baseband firmware to the `radio` partition.

**Adjudication of "is the baseband inert without its host stack?"** Not proven, and not provable
in this environment (`LIVE_FLASH_CLAIMED=false`, no hardware). What *is* proven: the firmware
image exists in every shipped bundle. The baseband is a separate processor with autonomous
firmware; the host stack (now excised) is the *control* plane, not the code that makes the
firmware exist. A flashed baseband is therefore at best **Tier B and requires an explicit
operator waiver**; to reach **Tier A** the approach must be **unflashed/erased** (do not flash
`radio`, and erase the `radio` partition as part of the deploy), which the current flasher does
not do — it does the opposite.

**Recommendation.** Operator decision is mandatory. If the airgap claim is to hold at Tier A,
`FW_IMAGES` must drop `radio.img` and the flow must erase/leave-unflashed the `radio` partition
(with an explicit fastboot `erase` and a fail-closed check), paired with a `Q-*` negative
control. If the operator waives, the waiver must name the baseband firmware explicitly.

---

### F-003 — HIGH — VINTF excision is defeated at runtime by the surviving `dmd.xml` fragment (all 13)

**Evidence (primary artifacts + upstream source):**
- Built `out/target/product/<dev>/vendor/etc/vintf/manifest.xml` header cites the hand-written
  `vendor_manifest_no_radio[_<dev>|_laguna_muzel].xml` on 13/13 — this part of pre-finding E-6
  is **CONFIRMED**.
- **But** `out/target/product/tegu/installed-files-vendor.txt:1521` installs
  `/vendor/etc/vintf/manifest/dmd.xml` (324 B), and that fragment declares:
  ```xml
  <hal format="aidl"><name>vendor.samsung_slsi.telephony.hardware.oemservice</name>
      <fqname>IOemService/dm0</fqname><fqname>IOemService/dm1</fqname></hal>
  ```
  (HIDL form `@1.0::IOemService/dm0,dm1` on `shiba`.) Present on **13/13**.
- `vendor/google_devices/tegu/tegu.mk:77` packages
  `adevtool_vintf_fragment_vendor_dmd.xml`; `vendor/google_devices/tegu/vintf/vendor/manifest/Android.bp:115`
  defines it as a `vintf_fragment` (`src: "dmd.xml"`). It is a first-class fragmented
  telephony/modem HAL declaration.
- Runtime semantics: `system/libvintf/VintfObject.cpp:282-292` (`fetchVendorHalFragments`,
  dir `kVendorManifestFragmentDir` = `/vendor/etc/vintf/manifest/`) and
  `:309-328` (`fetchDeviceHalManifest` = vendor manifest **+ vendor fragments**). Fragments are
  unioned into the runtime device manifest.
- `vendor/guardtalk/radio-excised/vintf-excised.mk` swaps `DEVICE_MANIFEST_FILE` to the
  no-radio file but **does not remove any `vintf_fragment`/`DEVICE_MANIFEST_DIR` fragment**.
- Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/05-vintf-fragment-runtime.txt`.

**Impact.** The excision's own thesis ("radio-free hand-written manifest via
`vintf-excised.mk`") is only true of the *main* file. On every device, the runtime device
manifest still advertises a Samsung telephony/modem HAL. It is not *served* (see F-004/F-007),
so this is not by itself Tier C — but the claim "0 telephony HAL on 13/13" is false, and a
framework client binding to `IOemService` would find a declared-but-missing HAL.

**Recommendation.** In `vintf-excised.mk` (or the shared core), drop the `dmd` fragment from the
packaged `vintf_fragments`/`DEVICE_MANIFEST_DIR` for all 13, or overwrite
`/vendor/etc/vintf/manifest/dmd.xml` with an empty manifest. Re-prove from the packed
`vendor.img` via `debugfs`/`grep -a` (as done here), not from a makefile.

---

### F-004 — HIGH — `radioExternal` HAL library present in the packed image on exactly 6/13 (per-device asymmetry confirmed)

**Evidence (primary artifacts):**
- Staging: `out/target/product/<dev>/vendor/lib64/vendor.samsung_slsi.telephony.hardware.radioExternal-V1-ndk.so`
  **present** for `tegu`, `stallion`, `frankel`, `blazer`, `mustang`, `rango`;
  **absent** for `shiba`, `husky`, `akita`, `tokay`, `caiman`, `komodo`, `comet`.
- Packed `vendor.img` (authoritative): `debugfs -R 'ls -l /lib64'` → present only on those 6.
  tegu entry: `101816 B`, sha256 `6bf189a2…ecc2` (`tegu`,`stallion`) /
  `325ff061…93cf5` (`frankel`,`blazer`,`mustang`,`rango`).
- Companion `vendor.samsung_slsi.telephony.hardware.oemservice-V1-ndk.so` (68,880 B) has the
  **same 6/13 asymmetry**.
- Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/02-e2-radioexternal-oemservice.txt`.

**Adjudication Tier B vs C (per device).**
- The library is a `libbinder_ndk` AIDL shared object (`readelf -d`: NEEDED `libbinder_ndk.so`;
  SONAME = itself).
- **No transport.** No binary in the built vendor has the soname in its `DT_NEEDED`, and no
  binary (including `dmd`) contains the soname string; there is no
  `…radioExternal…-service` executable and no `radioExternal` init `.rc`. The framework-side
  client (`rild`/`libsitril`) is absent. ⇒ **Tier B (orphaned dormant library)** on the 6;
  **Tier A** on the other 7.
- Consequence: the blanket "all 13 green" is falsified regardless of tier, and the 6 need an
  explicit waiver. Note the asymmetry does **not** track SoC family (`tegu`,`stallion` are
  zumapro; `stallion` is present while `caiman`/`comet`/`tokay` are absent), so it must be
  handled per device.

**Recommendation.** `T-EXCISE-RADIOEXT-HAL` card: add the two `.so` files to the vendor
package-excision filter on the 6 devices (or all 13 as a floor), prove absence in the packed
`vendor.img`, and pair with `Q-*`.

---

### F-005 — HIGH — Radio-disable feature gate missing from the flashable stamps of 4 devices (build/stamp skew)

**Evidence (primary artifacts):**
- `androidboot.radio.disabled=1` present in `out/target/product/<dev>/vendor_boot.img` for
  **13/13** (kernel boot-config string).
- Present in the **stamp** `vendor_boot.img` for only 9/13 —
  `shiba`, `husky`, `akita`, `tokay`, `caiman`, `komodo`, `comet`, `tegu`, `stallion`.
- **Absent** from the stamps for `frankel-20260923-094457`, `blazer-20260923-090842`,
  `mustang-20260923-094541`, `rango-20260802-130756`.
- `sha256(out/vendor_boot.img) != sha256(stamp/vendor_boot.img)` on those 4
  (e.g. frankel `b6de3f8f…` vs `f750795f…`; rango `ef6ba0bf…` vs `b2c736ca…`). The stamp is
  not a copy of the current `out/` build.
- Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/07-boot-cmdline-radio-disabled.txt`.
- Note: `vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh` case 4a asserts
  `BOARD_KERNEL_CMDLINE` contains the flag **in make** (and passes 128/0) — it never inspects
  the packed stamp, which is why this is invisible to the author suite.

**Impact.** The one feature gate this lane relies on to hold the modem in reset is present in
the build tree but **not in the artifact that would be flashed** for the four laguna devices
(and tokay's stamp is a Jul-25 build; see §0.2). For those devices the shipped image has no
radio-disable gate at all.

**Recommendation.** Re-stamp `frankel`/`blazer`/`mustang`/`rango` from the current `out/` and
add a stamp-time assertion that the packed `vendor_boot.img` boot-config contains
`androidboot.radio.disabled=1` (fail-closed), for all 13.

---

### F-006 — MEDIUM — Android telephony **framework** is present on 13/13 (dormant without RIL)

**Evidence:** per-device presence of `/system/framework/telephony-common.jar` (4,968,663 B),
`/system/framework/ims-common.jar`, `/system/framework/boot-telephony-common.{vdex,art,oat}`,
`/system/apex/com.android.telephonycore.apex` (393,216 B; payload contains
`framework-telephony.jar`, `TelephonyServiceManager`, `telephony_flags`), and
`/system_ext/framework/SatelliteClient.jar` (111,054 B) — all listed in `installed-files.txt`
(tegu lines 39, 267-268, 869, 1219, 1502, 1515). 13/13.
Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/03-userspace-telephony-residue.txt`.

**Impact.** Pre-finding E-6's "0 `rild`/`telephony` in `system/`" is **true for RIL binaries but
misleading for the framework**: the telephony/IMS/Satellite Java stacks are on disk. With the
RIL excised they are **Tier B (dormant)** — they cannot place a call or open a modem — but they
are not "removed", and a future transport re-introduction would give them a path.

**Recommendation.** Keep as an explicit Tier-B waiver line item; do not count the framework as
removed. Optional hardening: drop `SatelliteClient.jar` + the satellite sysconfig and
`ims-common.jar`.

---

### F-007 — MEDIUM — `dmd` modem daemon is packaged and started on 13/13; modem init residue remains

**Evidence:**
- `out/target/product/tegu/vendor/bin/dmd` (154,664 B) and `installed-files-vendor.txt:228`
  `/vendor/bin/dmd`; packed `vendor.img` `/bin/dmd` present on 13/13 (`debugfs stat`).
- `out/target/product/tegu/vendor/etc/init/dmd.rc`:
  `service DM-daemon /vendor/bin/dmd` + `class main` (started by init).
- `dmd` strings reference the modem: `/dev/umts_boot0`, `/dev/umts_dm0`, `ActiveModem`,
  `ModemStateMonitor`, `LibModemProxy`, and a `dlopen` of **`liboemservice.so`** — which does
  **not exist** anywhere in the built tree, so the daemon's oemservice path cannot initialise.
- `out/target/product/tegu/vendor/etc/init/hw/init.zumapro.board.rc` still creates modem dirs
  (`/data/vendor/rild`, `/data/vendor/radio/**`, `/mnt/vendor/modem_userdata/replay`), chowns
  `cp-tm1`/`cpif` sysfs, and runs `mount_all /vendor/etc/fstab.modem --early`; `fstab.modem` is
  **absent** from the built vendor (the mount is a no-op).
- `vendor/build.prop` carries `ro.radio.noril=1`, `ro.boot.radio.disabled=1`,
  `persist.radio.disabled=1` (gates present) but also `ro.vendor.cbd.modem_type=s5100sit`,
  `vendor.rild.libpath=libsitril.so`, `persist.vendor.ril.*` (stale).

**Impact.** A modem-status daemon with a main-class init service is a reachable *process*
(Tier B, because its telephony library is absent). Combined with F-001 this strengthens the
case that the modem surface is not fully excised.

**Recommendation.** Remove `dmd`/`dmd.rc` and the stale modem init block (or waive explicitly);
keep `ro.radio.noril`/`ro.boot.radio.disabled` as the gate.

---

### F-008 — MEDIUM — Telephony feature advertisement is a false positive on 12/13

**Evidence:** `product/etc/permissions/android.hardware.telephony.euicc.xml` and
`android.hardware.telephony.euicc.mep.xml` declare
`<feature name="android.hardware.telephony.euicc"/>` (+ `.mep`) on 12/13 (absent `tokay`).
Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/03-userspace-telephony-residue.txt`.

**Impact.** `PackageManager.hasSystemFeature("android.hardware.telephony.euicc")` returns true
on those devices, i.e. the OS *advertises* telephony capability it does not have. This is a
claim-honesty issue as much as a surface issue.

**Recommendation.** Drop the eUICC feature XMLs on the 12 devices (the `com.google.euiccpixel`
app is already absent, so the permission XMLs are the only remainder).

---

### F-009 — MEDIUM — SELinux still labels the excised radio services/binaries (13/13)

**Evidence (built `out/target/product/tegu/vendor/etc/selinux/`):**
- `vendor_service_contexts`:
  `vendor.samsung_slsi.telephony.hardware.radioExternal.IOemSlsiRadioExternal/default`,
  `vendor.samsung_slsi.telephony.hardware.oemservice.IOemService/dm0` and `/dm1`,
  `com.google.pixel.modem.logmasklibrary.ILiboemserviceProxy/default`.
- `vendor_hwservice_contexts`: `…oemservice::IOemService`, `…radioExternal::IOemSlsiRadioExternal`.
- `vendor_file_contexts`: `/vendor/bin/hw/rild`, `/vendor/bin/hw/rild_exynos`,
  `/data/vendor/rild(/.*)?`, `/vendor/bin/liboemservice_proxy_default`.
Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/02-e2-radioexternal-oemservice.txt` §E.

**Impact.** The policy still grants a domain/type to a service name that the excision removed;
if any process were to register those HAL names it would inherit a modem-logging/rild label.
Tier B residue (dead labels today), but a live hardening surface.

**Recommendation.** Strip the radio service/file contexts as part of the excision; keep the
removal in the same card as `T-EXCISE-RADIOEXT-HAL`.

---

### F-010 — MEDIUM — Author acceptance check #5 fails on 10/13; the author suite itself is red on 11/13

**Evidence:**
- `ro.guardtalk.radio.excised=1` is present only in `akita`, `tokay`, `rango`; **absent** on the
  other 10 (`shiba`, `husky`, `caiman`, `komodo`, `comet`, `tegu`, `stallion`, `frankel`,
  `blazer`, `mustang`).
- `PRODUCT_OUT=out/target/product/<dev> bash vendor/guardtalk/scripts/verify-radio-excision.sh`
  exits **non-zero on 11/13**:
  `shiba` 3, `husky` 3, `akita` 1, `tokay` 0, `caiman` 1, `komodo` 1, `comet` 3, `tegu` 2,
  `stallion` 2, `frankel` 2, `blazer` 2, `mustang` 2, `rango` 0.
- Raw evidence: `.agent-comm/evidence/A-EXCISE-RADIO/06-author-suite-agreement.txt`.

**Impact.** The author-side radio acceptance gate is not green on the built set; the excision
has drifted since the 4-device era, and `ro.guardtalk.radio.excised` is not a reliable
per-device termination signal.

**Recommendation.** Re-derive the acceptance checks from packed artifacts across all 13
(`Q-EXCISE-13DEV-MATRIX`) and make each device emit `ro.guardtalk.radio.excised=1` (or replace
the prop with the packed-artifact assertion).

---

### F-011 — LOW — Stale RIL permission surface (jars/apps already absent)

**Evidence:** `system_ext/etc/permissions/google-ril.xml` (declares library
`/system_ext/framework/google-ril.jar`), `oemrilhook.xml` (`/system_ext/framework/oemrilhook.jar`),
`com.google.android.rilextension.xml`, `com.google.euiccpixel[.permissions].xml` are present,
while *all four* referenced jars/apps are absent from the built tree (`find` and
`system_ext/framework` listing). `Tier B` residue.

**Recommendation.** Remove the orphan permission XMLs; keep `google-ril.jar`-absence as a
guarded assertion.

---

### F-012 — LOW — `vendor/build.prop` retains modem/RIL configuration keys

**Evidence:** `out/target/product/tegu/vendor/build.prop` still contains
`ro.vendor.cbd.modem_type=s5100sit`, `ro.vendor.cbd.modem_removable=1`,
`vendor.rild.libpath=libsitril.so`, `ro.telephony.default_network=27`,
`persist.vendor.ril.*` (10 keys), `ro.carrier=unknown`, `persist.vendor.radio.*` — while
`libsitril.so`/`cbd`/`rild` are absent.

**Impact.** Tier B config residue; also evidence that the `remove-packages.mk` list and the
property surface are not co-maintained.

**Recommendation.** Fold the RIL/modem property cleanup into the same excision card.

---

### F-013 — INFO — Gen 6 (`gs101`) / Gen 7 (`gs201`) audited absence

No `device/google/gs101*` / `gs201*` tree and no `gs101`/`gs201` stamp in
`releases/desktop-flash/`. Out of program scope; recorded, not omitted (matches E-8 and
`verify_port_excision_matrix_static.sh` case 8).

---

## 3. Per-device × per-artifact Tier A/B/C matrix (cellular lane)

Legend: **A** = absent · **B** = dormant (waiver required) · **C** = reachable/active · **—** = n/a.

| Artifact (cellular lane) | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RIL userspace (`rild`,`libril*`,`libsitril*`,`google-ril.jar`,`oemrilhook.jar`) | A | A | A | A | A | A | A | A | A | A | A | A | A |
| Main VINTF manifest (`vendor_manifest_no_radio*`) | A | A | A | A | A | A | A | A | A | A | A | A | A |
| **VINTF fragment `dmd.xml` (telephony HAL, runtime)** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** |
| `radioExternal` HAL lib (packed `vendor.img`) | A | A | A | A | A | A | A | **B** | **B** | **B** | **B** | **B** | **B** |
| `oemservice` HAL lib (packed `vendor.img`) | A | A | A | A | A | A | A | **B** | **B** | **B** | **B** | **B** | **B** |
| **Kernel modem transport `cpif`/`cpif_page`/`shm_ipc` (loaded)** | **C** | **C** | **C** | A | A | A | **C** | **C** | **C** | **C** | **C** | **C** | A |
| Baseband firmware `radio.img`/`modem.img` (`out/`) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `radio.img` in release stamp + flasher writes `radio` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `dmd` modem daemon (packaged + `class main`) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| Telephony framework (`telephony-common.jar`, `ims-common.jar`, `telephonycore.apex`, `SatelliteClient.jar`) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| eUICC telephony feature XML | B | B | B | A | B | B | B | B | B | B | B | B | B |
| SELinux radio service/file contexts | B | B | B | B | B | B | B | B | B | B | B | B | B |

**Per-device roll-up (worst tier in the cellular lane):**
`tegu`,`stallion`,`frankel`,`blazer`,`mustang` = **C** (worst: loaded `cpif`);
`shiba`,`husky`,`akita`,`comet` = **C** (loaded `cpif`);
`tokay`,`caiman`,`komodo`,`rango` = **B** (no Tier-C artifact found; multiple Tier-B residuals).

⇒ **No device is Tier A**, so **no device** supports the "100% removed" claim; 9/13 are Tier C.

### 3.1 Control / feature-gate table (mitigations, not residue)

| Control | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `androidboot.radio.disabled=1` in packed stamp `vendor_boot.img` | Y | Y | Y | Y | Y | Y | Y | Y | Y | **N** | **N** | **N** | **N** |
| `ro.radio.noril=1` + `ro.boot.radio.disabled=1` in packed `vendor/build.prop` | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |
| `ro.guardtalk.radio.excised=1` | N | N | Y | Y | N | N | N | N | N | N | N | N | Y |

---

## 4. Agreement / disagreement with pre-findings and prior suites

| Prior claim | Auditor result |
|---|---|
| **E-1** baseband FW present 13/13, every stamp carries `radio.img`, `flash-from-remote.sh:153,937` flashes `radio` | **CONFIRMED** (sizes/hashes re-derived; see F-002). Extra: `modem.img` exists in `out/` only, matching E-7b. |
| **E-2** `radioExternal` present on 6/13, absent 7/13 | **CONFIRMED** at both staging and packed `vendor.img` level; `oemservice` mirrors it; `dmd` + `dmd.xml` present on 13/13 (new). |
| **E-3** APEX-dormant set incl. `com.android.telephonycore.apex` | **CONFIRMED** for `com.android.telephonycore.apex` (13/13) + `com.android.bt.apex`/`nfcservices`/`uwb` (BT/NFC/UWB are other lanes). |
| **E-4/E-5** BT modules, feature XMLs | Not adjudicated here (BT/LOC lanes). |
| **E-6** "0 `rild`/`telephony` in `system/`; radio-free manifest 13/13" | **PARTIAL DISAGREE.** 0 `rild` binaries: true. But `/system/framework/telephony-common.jar`, `ims-common.jar`, `telephonycore.apex`, `SatelliteClient.jar` are present (F-006), and the runtime manifest is **not** radio-free because of the `dmd.xml` fragment (F-003). |
| **E-7** stamps carry `radio.img` only; `modem.img` in `out/` only | **CONFIRMED** (F-002). Regen-hook citation drift not re-checked (out of lane). |
| **E-8** Gen 6/7 absent | **CONFIRMED** (F-013). |
| `vendor/guardtalk/scripts/verify-radio-excision.sh` | **DISAGREE / RED.** Exits non-zero on 11/13 (F-001, F-010). |
| `vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh` | **AGREE but insufficient** — EXIT 0, 128 PASS / 0 FAIL, makefile-level only; never inspects packed stamps (F-005 hides here). |
| `vendor/guardtalk/docs/qa/verify_remediate_b2_excise_host.sh` | AGREE on its lane: EXIT 0, `bash_PASS=55 bash_HOLD=4`; `LIVE_DEVICE_CLAIMED=false`, device HOLD. |
| `vendor/guardtalk/docs/qa/verify_remediate_b2_apex_host.sh` | **RED (out of lane):** EXIT 1, 4 FAIL (DeviceLock SSR/BCP stripping). Noted for the Architect; not a radio finding. |
| `vendor/guardtalk/docs/qa/verify_remediate_b2_kernel_static.sh` | AGREE: EXIT 0, `PASS_COUNT=30 HOLD_COUNT=6 FAIL=0`; on-device `/proc/sys` HOLD. |
| `vendor/guardtalk/scripts/verify-on-device.sh` | **NOT RUN** — requires a device (`adb wait-for-device`); `LIVE_FLASH_CLAIMED=false`, DEC-009 HOLD. No on-device result is claimed anywhere in this report. |

---

## 5. Falsification log

Independent attacks attempted against the claim. "Succeeded" = attack broke the claim.

| # | Attack | Method | Result | Cost to the claim |
|---|---|---|---|---|
| 1 | Find a RIL binary in the built image | `find`/`ls` for `rild`, `rild_exynos`, `libril*`, `libsitril*`, `google-ril.jar` on 13/13 | **Failed** (nothing found) | None — control-plane excision genuinely holds (Tier A). |
| 2 | Find a radio HAL **service** binary | grep built `vendor/bin`, `vendor/bin/hw` for `android.hardware.radio*service`, `rild_exynos` | **Failed** | None — no served radio HAL. |
| 3 | Find radio HALs in the **main** VINTF manifest | parse `vendor/etc/vintf/manifest.xml` on 13/13 | **Failed** | None — main manifest is radio-free. |
| 4 | Find radio HALs merged at **runtime** via fragments | `grep` fragment dir + read `VintfObject.cpp` | **Succeeded** — `dmd.xml` re-declares `oemservice` on 13/13 | Falsifies "radio-free manifest"; F-003. |
| 5 | Find the vendor HAL libs **inside the packed** `vendor.img` | `debugfs` on 13 stamps | **Succeeded** — `radioExternal`+`oemservice` on 6/13 | Falsifies the blanket green; F-004. |
| 6 | Find a client/server **transport** for `radioExternal` | `readelf -d`, soname grep across all built binaries | **Failed** (orphan) | Caps F-004 at Tier B (per device). |
| 7 | Find modem **kernel transport** in the packed ramdisk and its load list | `find` + `modules.load` + `installed-files-vendor-kernel-ramdisk.txt` + `installed-files-vendor_dlkm.txt` | **Succeeded** — `cpif`/`cpif_page`/`shm_ipc` on 9/13 | **Tier C**; falsifies "removed"; F-001. |
| 8 | Find baseband firmware in the shipped bundle | `sha256sum` 13 `out/` images; `grep` all 13 stamps' `SHA256SUMS`; read flasher | **Succeeded** — 13/13, and flashed | Falsifies Tier A for baseband; needs waiver/erase; F-002. |
| 9 | Break the radio-disable gate on the **shipped** artifact | boot-config string in stamp `vendor_boot.img` vs `out/` | **Succeeded** — gate missing from 4 laguna stamps | F-005. |
| 10 | Find the excision marker on every device | `grep ro.guardtalk.radio.excised` in 13 `vendor/build.prop` | **Succeeded** — absent on 10/13 | F-010. |
| 11 | Re-run the author radio suite | `verify-radio-excision.sh` per device | **Succeeded** — non-zero on 11/13 | F-001, F-010. |
| 12 | Find telephony framework residue | `installed-files*.txt`, `ls` on 13 | **Succeeded** — jars + apex on 13/13 | F-006 (Tier B). |
| 13 | Confirm the baseband is **inert** (the strongest pro-claim attack) | analyse modem init/boot path (`dmd`, `fstab.modem`, `cbd`, `radio.disabled`) | **Inconclusive** — no `cbd` in built `vendor/bin`, `fstab.modem` absent, gate present, but no hardware to observe | Cannot upgrade F-002 to Tier A; claim stays unmet. |
| 14 | Find a device with no `dmd` service | `debugfs stat /bin/dmd` on stamps | **Failed** — present on 13/13 | F-007. |

**Net:** attacks 4, 5, 7, 8, 9, 10, 11, 12, 14 succeeded; 1, 2, 3, 6 failed (excision genuinely
holds there); 13 inconclusive. The claim's "100% removed" wording cannot survive attacks 4/7/8.

---

## 6. Residual register requiring operator decision

| ID | Residual | Tier | Devices | Minimal remediation |
|---|---|---|---|---|
| R-1 | Loaded kernel modem transport `cpif`/`cpif_page`/`shm_ipc` | C | 9 | extend the working excision to these 3 modules; re-prove in packed ramdisk |
| R-2 | Baseband firmware `radio.img`/`modem.img` shipped and flashed | B | 13 | **waiver OR** stop flashing + erase `radio` (fail-closed) |
| R-3 | Runtime VINTF fragment `dmd.xml` declares telephony `oemservice` HAL | B | 13 | drop the fragment from the packaged `vintf_fragments` |
| R-4 | `radioExternal` + `oemservice` HAL libs in packed `vendor.img` | B | 6 | add to vendor package-excision filter |
| R-5 | Radio-disable gate missing from the flashable stamp | B | 4 | re-stamp + stamp-time gate assertion |
| R-6 | Telephony framework jars/apex present | B | 13 | waiver (or drop SatelliteClient/ims-common) |
| R-7 | `dmd` daemon + modem init residue | B | 13 | remove `dmd`/rc + stale modem init block |
| R-8 | eUICC telephony feature advertised | B | 12 | drop the feature XMLs |
| R-9 | SELinux radio service/file contexts | B | 13 | strip contexts |

**Every Tier-B row above requires an explicit operator waiver before the cellular surface may be
called "removed".** R-1 is Tier C and is a defect to fix, not a waiver.

---

## 7. Withheld remediation cards that this audit unblocks

Per `DEC-EXCISE-AIRGAP-001` §A5 (Architect decides; this audit only supplies the trigger):

- **`T-EXCISE-FW-RADIO`** — trigger met (`E-1`/F-002): baseband firmware on disk + flashed is
  in scope for the claim.
- **`T-EXCISE-RADIOEXT-HAL`** — trigger met (`E-2`/F-004): `radioExternal` is Tier B on 6
  devices, plus a `dmd.xml`-fragment defect on 13.
- New candidate (not in §A5): **`T-EXCISE-MODEM-KERNEL`** for F-001 (Tier C `cpif` transport),
  and **`T-EXCISE-STAMP-GATE`** for F-005 (stamp/build skew) — both should be paired with `Q-*`
  per DEC-012.

---

## 8. Honesty holds

- `LIVE_FLASH_CLAIMED=false`; no `adb`/`fastboot`/USB; no hardware attached.
- No on-device or boot-green result is claimed. `Q-ONDEVICE=not started`.
- `Gate 5: HUMAN SKIP` (no invented score).
- Read-only: no `.py/.ts/.tsx/.js/.jsx/.css/.mk/.sh` product/test/filter/flash/packer file,
  no `doctrine/`, `governance/{laws,gates}/`, `.env`, credentials, `.git`, `keys/` touched.
- No task status changed; `.agent-comm/inbox/TO_ARCHITECT.md` not modified (parallel-auditor
  race avoided per `DEC-EXCISE-AIRGAP-001` §A7).
- Status is reported to the Architect as **REVIEW**; never `APPROVED`.

## 9. Raw evidence index

| File | Contents |
|---|---|
| `.agent-comm/evidence/A-EXCISE-RADIO/01-e1-baseband-firmware.txt` | 13 devices × {`radio.img`,`modem.img`} `ls -l` + `sha256sum`; stamp `SHA256SUMS` `radio.img` lines |
| `.agent-comm/evidence/A-EXCISE-RADIO/02-e2-radioexternal-oemservice.txt` | staging + packed (`debugfs`) library matrix; sha256s; transport-negative proof; SELinux labels |
| `.agent-comm/evidence/A-EXCISE-RADIO/03-userspace-telephony-residue.txt` | telephony framework/apex/satellite/euicc/ril-XML per-device matrix; RIL binary absence; `build.prop` residue; `ro.guardtalk.radio.excised` |
| `.agent-comm/evidence/A-EXCISE-RADIO/04-kernel-cpif-modem.txt` | `cpif`/`shm_ipc` file + `modules.load` + packed-manifest matrix; `dmd`; modem init residue |
| `.agent-comm/evidence/A-EXCISE-RADIO/05-vintf-fragment-runtime.txt` | manifest provenance headers; fragment dir install; `dmd.xml` content; `VintfObject.cpp` runtime-merge source; `vintf_fragment` module definition |
| `.agent-comm/evidence/A-EXCISE-RADIO/06-author-suite-agreement.txt` | author-suite re-run results per device/script |
| `.agent-comm/evidence/A-EXCISE-RADIO/07-boot-cmdline-radio-disabled.txt` | `androidboot.radio.disabled` out-vs-stamp + sha256; flasher lines |

*Auditor: AEGIS Independent Deep Tech Auditor (Panel 5) · task `A-EXCISE-RADIO` · read-only ·
REVIEW.*
