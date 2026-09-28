# EXCISION LEDGER R2 — per-device service excision (**shipped stamps only**)

| Field | Value |
|---|---|
| task_id | `T-EXCISE-LEDGER-R2` |
| supersedes | `T-EXCISE-LEDGER` (falsified by `Q-EXCISE-LEDGER` on 16/130 cells) |
| role | Backend Engineer (Panel 2) · `aegis-backend-engineer` |
| program | `DEC-EXCISE-AIRGAP-001` — Extreme independent audit of the OS-level airgap claim |
| authority | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` § `EXTREME AUDIT — AIRGAP CLAIM` |
| repository_id | `grapheneos-worktree` |
| status | `REVIEW` (this card never sets `APPROVED`) |
| generated | 2026-09-25T17:30:00+00:00 |
| machine-readable companion | `vendor/guardtalk/docs/qa/excision_ledger.json` (schema 1.2) |
| ledger sha256 | `cc362b3ad2ebd39e28be7a002470e49fcf9704f9a207f56fcf309d28dd29dc26` |

**Scope.** The machine-readable **per-device excision ledger** for the 13 Gen 8/9/10 program
devices, re-derived **from the shipped release stamps only** — `releases/desktop-flash/<stamp>/*.img`,
read read-only with `debugfs` and, for the `vendor_kernel_boot.img` vendor ramdisk, with a
`VNDRBOOT` v4 + legacy-LZ4 + `newc` cpio unpacker.

**Change vs R1.** R1 mixed shipped stamps with `out/target/product/<dev>/` **build-tree** artifacts
(652 of its 665 rows were build-tree). R2's `artifacts[]` array is **100 % `evidence_kind="stamp-image"`**
(273 rows). Build-tree artifacts are recorded separately in `devices[].build_tree_corroboration`
with `tier_contribution=false` and are **never** tier-bearing. **No cell cites a `.mk` or makefile.**

**Tier standard (adjudication is owned by the five `A-EXCISE-*` auditor lanes, not by this card):**

| Tier | Meaning | Acceptable for an "airgapped" claim? |
|---|---|---|
| **A — ABSENT** | Not present in the shipped artifacts at all | Yes |
| **B — DORMANT** | Shipped on disk, but no transport / blocklisted / no HAL / feature-gate off | **Requires explicit operator waiver** |
| **C — REACHABLE** | Shipped and can become active (in `modules.load` and unblocklisted, or a boot-started service) | **No — audit FAIL** |

## 0. Honesty holds

- `LIVE_FLASH_CLAIMED = false` — no device was flashed or booted; no `adb`/`fastboot` was run.
- `BOOT_VERIFIED = false`; no boot-green result is claimed for any device (`rango` included).
- `Gate 5: HUMAN SKIP` — no critique score is invented.
- `build_recipe_evidence_used = false` — verified structurally, not just by grep (§7).
- Every cell is re-derived from a shipped stamp image; the shipped stamp is **decisive**.
- `rango-latest` was **not** moved: it still resolves to `rango-20260802-130756`.
- No product / filter / flash / packer / doctrine / governance file was edited; nothing was rebuilt
  or re-stamped.
- **Dissent preserved (not absorbed):** where the shipped stamp disagrees with a prior audit that
  used the build tree, the disagreement is recorded, not hidden (`E-R2-1`, §5.4).

## 1. Gen 6 / Gen 7 — audited absence (recorded, not omitted)

`gen6_gen7_audited_absence.status = AUDITED_ABSENCE`. No shipped stamp exists for **Gen 6 (`gs101`)**
or **Gen 7 (`gs201`)**; the four globs (`device/google/gs101*`, `device/google/gs201*`,
`releases/desktop-flash/*gs101*`, `releases/desktop-flash/*gs201*`) all return 0 hits. Out of program
scope per `DEC-PORT-GEN8910-001` §7. An absence, not a silent omission.

### 1.1 Modem-kernel excision boundary — **13-device-scoped** (2026-09-26, `T-EXCISE-MODEM-KERNEL-LEGACY-SCOPE`)

`T-EXCISE-MODEM-KERNEL` excised `cpif` / `cpif_page` / `shm_ipc` on the **13 Gen-8/9/10 program
devices only**. This is **not** a fleet-wide excision. The three tokens **remain present** in the
module load lists of **5 legacy kernel trees that are outside the 13-device fleet** (recorded so a
future "we excised the modem kernel" claim cannot be read as global):

| Legacy kernel tree | Generation | Live file(s) carrying `cpif.ko` / `cpif_page.ko` / `shm_ipc.ko` |
|---|---|---|
| `device/google/raviole-kernels/6.1/grapheneos/` | Gen 6 (`gs101`, Pixel 6-gen) | `vendor_dlkm.modules.load` (+ parity `modules.load`) |
| `device/google/bluejay-kernels/6.1/grapheneos/` | Gen 6 (`gs101`, Pixel 6-gen) | `vendor_dlkm.modules.load` (+ parity `modules.load`) |
| `device/google/pantah-kernels/6.1/grapheneos/` | Gen 7 (`gs201`, Pixel 7-gen) | `vendor_kernel_boot.modules.load` (+ parity `modules.load`) |
| `device/google/lynx-kernels/6.1/grapheneos/` | Gen 7 (`gs201`, Pixel 7-gen) | `vendor_kernel_boot.modules.load` (+ parity `modules.load`) |
| `device/google/felix-kernels/6.1/grapheneos/` | Gen 7 (`gs201`, Pixel 7-gen) | `vendor_kernel_boot.modules.load` (+ parity `modules.load`) |

These trees are **out of program scope** per `DEC-PORT-GEN8910-001` §7 (the same reason §1 above
records Gen 6 / Gen 7 as an audited absence). They were **deliberately not touched** by
`T-EXCISE-MODEM-KERNEL`. Extending the excision to them ("option (b)") is **NOT** done here and
requires an explicit fleet decision; a **confirmed-nil** boundary statement is not a claim that these
trees are excised. Evidence: `.agent-comm/evidence/T-EXCISE-MODEM-KERNEL-LEGACY-SCOPE/`.

## 2. Device roster, stamp resolution and baseband firmware

`radio.img` is carried by every stamp; `modem.img` exists **only** in the build tree (`out/`), which
confirms Architect `E-7b`. The baseband tier is derived from the shipped `radio.img`; the build-tree
`modem.img` is corroboration only (§6 of the JSON).

| codename | variant (shipped header) | stamp | stamp note | shipped `radio.img` |
|---|---|---|---|---:|
| shiba | `zuma_shusky` | shiba-20260923-094055 | `shiba-latest` | 112,967,820 |
| husky | `zuma_shusky` | husky-20260923-095309 | `husky-latest` | 112,967,820 |
| akita | `zuma_akita` | akita-20260725-101434 | `akita-latest` | 115,355,788 |
| tokay | `zumapro_caimito` | tokay-20260725-102506 | **no `tokay-latest`; global `latest`** | 136,634,508 |
| caiman | `zumapro_caimito` | caiman-20260922-090535 | `caiman-latest` | 136,634,508 |
| komodo | `zumapro_caimito` | komodo-20260915-063833 | `komodo-latest` | 136,634,508 |
| comet | `zumapro_comet` | comet-20260922-160129 | `comet-latest` | 136,634,508 |
| tegu | `zumapro_tegu` | tegu-20260922-164700 | `tegu-latest` | 98,766,988 |
| stallion | `zumapro_stallion` | stallion-20260923-100618 | `stallion-latest` | 191,426,700 |
| frankel | `laguna_muzel` | frankel-20260923-094457 | `frankel-latest` | 191,426,700 |
| blazer | `laguna_muzel` | blazer-20260923-090842 | `blazer-latest` | 191,426,700 |
| mustang | `laguna_muzel` | mustang-20260923-094541 | `mustang-latest` | 191,426,700 |
| rango | `laguna_rango` | rango-20260802-130756 | `rango-latest` | 191,426,700 |

**† `tokay` has no `tokay-latest`.** The only latest pointer for tokay is the global
`releases/desktop-flash/latest -> tokay-20260725-102506`. Recorded as `stamp_note` in the JSON.

## 3. Service tier matrix (13 devices × 20 services) — from shipped stamps

Each cell is the worst (highest) tier observed for that device/service across the shipped artifact
rows. This matrix **matches the umbrella reconciled matrix on every mapped cell** (260/260) except
the single card-mandated `nfc_userspace_hal` fix on `rango` (`E-19`, §5.3).

| service | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `baseband_firmware` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `cellular_ril_native` | A | A | A | A | A | A | A | A | A | A | A | A | A |
| `cellular_vendor_radioExternal_hal` | A | A | A | A | A | A | A | B | B | B | B | B | B |
| `cellular_framework_telephony` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `telephony_feature_declarations` | B | B | B | **A** | B | B | B | B | B | B | B | B | B |
| `bluetooth_userspace_hal` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `bluetooth_gki_modules` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| **`nitrous_module`** | B | B | B | B | B | B | B | B | B | **C** | **C** | **C** | **C** |
| `location_gnss` | C | C | A | A | A | A | A | A | A | A | A | A | A |
| **`location_gnss_kernel`** | B | B | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** |
| **`nfc_userspace_hal`** | A | A | A | A | A | A | A | A | A | A | A | A | **B** |
| `nfc_kernel_module` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `uwb_hal_service` | A | C | A | A | C | C | C | A | A | A | C | C | C |
| `uwb_kernel` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `apex_dormant_set` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `appsearch_apex` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `telemetry_profiling` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `connectivity_wifi_tethering` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `sensors_camera_mic_privacy` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `variant_resolution` | B | B | B | B | B | B | B | B | B | B | B | B | B |

**Bolded cells** are the 16 R2 corrections + the 1 E-19 consistency fix (§5).

## 4. Service findings (primary shipped artifacts)

### 4.1 Baseband firmware — Tier B, 13/13
Every stamp carries `radio.img` (sizes in §2); the baseband firmware is staged for flashing and
there is no shipped-artifact evidence it is inert. Confirms `E-1`. **Operator waiver required.**

### 4.2 Cellular native RIL — Tier A, 13/13
The shipped vendor *main* `manifest.xml` is the radio-free manifest (`vendor_manifest_no_radio*`),
and no `rild` service exists in the shipped `/bin/hw`. **Law 7 correction (2026-09-26,
`T-EXCISE-CLAIM-HONESTY-RESIDUAL`):** only the *main* manifest is radio-free; a `dmd.xml` runtime
fragment re-declares a telephony `oemservice` HAL (`IOemService/dm0`,`dm1`) on **13/13** (`H-R2`;
`A-2`; RADIO `F-003`). `T-EXCISE-VINTF-DMD` now filters `dmd.xml` at source (pre-re-stamp). Confirms
only the host-transport half of `E-6`.

### 4.3 Cellular vendor `radioExternal` HAL — B on 6, A on 7
`vendor.samsung_slsi.telephony.hardware.radioExternal-V1-ndk.so` is present in the shipped
`vendor.img` on exactly **tegu, stallion, frankel, blazer, mustang, rango** (B), absent on the other
7 (A). Confirms `E-2`. Because the shipped *main* manifest is radio-free the library has no declared
transport → B, but the runtime-merged manifest still carries the `dmd.xml` telephony `oemservice`
fragment (`H-R2`), so it is a **per-device residual** the auditors must adjudicate B vs C.

### 4.4 Cellular framework telephony — Tier B, 13/13 (correction to `E-6`)
`telephony-common.jar` is present in the shipped `system.img` on all 13. `E-6`'s "0 telephony in
`system/`" holds for native RIL binaries, not for framework telephony classes. Tier B.

### 4.5 Telephony feature declarations — B on 12, A on 1
`product/etc/permissions/android.hardware.telephony.euicc.xml` ships on 12/13; **tokay is the
exception** (0 eUICC entries). Tier B where present, A on tokay.

### 4.6 Bluetooth userspace HAL — Tier B, 13/13 (adjudication required)
Every shipped vendor `manifest.xml` declares `android.hardware.bluetooth`,
`android.hardware.bluetooth.finder`, `android.hardware.bluetooth.ranging` and
`vendor.google.bluetooth_ext`; the BT-audio HAL impl ships. No vendor `android.hardware.bluetooth`
service binary was found in the shipped vendor image. Declared HAL, implementation absent → B, but
`A-EXCISE-BT` must adjudicate B vs C.

### 4.7 Bluetooth GKI kernel modules — Tier C, 13/13 (correction to `E-4`)
`system_dlkm/lib/modules/` ships `bluetooth.ko`, `hci_uart.ko`, `btbcm.ko`, `btqca.ko`, `btsdio.ko`,
`rfcomm.ko`, `hidp.ko` in `modules.load`, **not** blocklisted → **C** on 13/13.

### 4.8 `nitrous` — Tier C on 4 laguna, B on 9 (**R2 correction**)
Shipped `vendor_dlkm/lib/modules/`: `nitrous.ko` is in `modules.load` and there is **no**
`blocklist nitrous` line on **frankel, blazer, mustang, rango** → **C** (these stamps carry a stock
un-excised blocklist). On the other 9 devices `blocklist nitrous` is present → B. See §5.1.

### 4.9 Location / GNSS — userspace C on shiba+husky, kernel **C on 11** (**R2 correction**)
**Userspace:** shiba and husky ship a complete GNSS userspace stack in `vendor.img`
(`/bin/hw/gpsd`, `/lib64/hw/gps.default.so`, `/etc/gnss/*`, `/etc/init/init.gps.rc` with
`class main` daemons and no `disabled`) → **C**; the other 11 ship none → A.
**Kernel:** `gnssif.ko` / `gnss_spi.ko` are **unblocklisted** on **11/13** → **C**:
- `shiba`, `husky`: present in `vendor_dlkm` `modules.load` **and** `blocklist gnssif`/`gnss_spi`
  present → **B** (unchanged).
- `akita`, `tokay`, `caiman`, `komodo`, `comet`, `tegu`, `stallion`: absent from `vendor_dlkm`, but
  present in the **`vendor_kernel_boot.img` vendor ramdisk** `lib/modules/modules.load` with **0**
  ramdisk blocklist entries → **C**.
- `frankel`, `blazer`, `mustang`, `rango`: in `vendor_dlkm` `modules.load`, **no** gnss blocklist
  lines → **C**.
See §5.2.

### 4.10 NFC — userspace B on rango, A elsewhere; kernel C 13/13 (**R2 consistency fix**)
`nfc.ko` is in `system_dlkm` `modules.load` and unblocklisted → C 13/13. `com.android.nfcservices`
APEX ships 13/13 → B. **Userspace HAL:** no NFC service binary/lib on any device; but `rango`'s
shipped `vendor.img` carries `/overlay/NfcOverlayRangoGsi.apk` and `/etc/libnfc-hal-st_evt.conf`
(both in the ledger's own cited manifest) → **B on rango** (not A). See §5.3.

### 4.11 UWB — HAL C on 7, A on 6; kernel C 13/13
A boot-started UWB HAL service + `init.rc` ships on **husky, caiman, komodo, comet, blazer, mustang,
rango** → C on those 7; absent on the other 6 → A. `aoc_uwb_*` kernel modules are in `modules.load`
and unblocklisted → C 13/13. `com.android.uwb.apex` ships 13/13 → B.

### 4.12 APEX dormant set — Tier B (per-device coverage)
Shipped on all 13: `bt`, `nfcservices`, `adservices`, `healthfitness`,
`ondevicepersonalization`, `uwb`, `profiling`, `uprobestats`, `telephonycore`. `devicelock` ships
only on **akita, tokay, rango**. `cellbroadcast` ships on **none** (corrects the `E-3` list). All B.

### 4.13 `com.android.appsearch` — Tier C by design
`system/apex/com.android.appsearch.apex` ships 13/13. Deliberately active → Tier C by design.

### 4.14 Telemetry / profiling — Tier B
`adservices`, `uprobestats`, `profiling`, `healthfitness`, `ondevicepersonalization`, `os.statsd`
ship 13/13 (dormant mainline stacks) → B.

### 4.15 Retained connectivity (Wi-Fi / tethering) — Tier C by design
`com.android.wifi.apex` and `com.android.tethering.apex` ship 13/13 and are known-reachable. Outside
the excised set, recorded C so the headline is not overstated.

### 4.16 Sensors / camera / mic privacy surfaces — Tier C by design
`system/build.prop` carries `ro.guardtalk.sensor_privacy_when_locked=1`; local, privacy-gated
surfaces. Recorded C by design so the audit matrix covers them explicitly.

## 5. The 17 corrections

### 5.1 `nitrous_module` — 4 cells, `B → C`

| # | device | old | new | falsifying shipped evidence |
|---|---|:-:|:-:|---|
| 1 | frankel | B | **C** | `frankel-20260923-094457/vendor_dlkm.img` → `nitrous.ko` in `modules.load`; 0 `blocklist nitrous` lines |
| 2 | blazer | B | **C** | `blazer-20260923-090842/vendor_dlkm.img` → same |
| 3 | mustang | B | **C** | `mustang-20260923-094541/vendor_dlkm.img` → same |
| 4 | rango | B | **C** | `rango-20260802-130756/vendor_dlkm.img` → same |

Root cause: the R1 ledger derived this cell from the `out/` build tree; the four laguna stamps ship a
**stock, un-excised** blocklist.

### 5.2 `location_gnss_kernel` — 11 cells, `B → C`

| # | device | old | new | falsifying shipped evidence |
|---|---|:-:|:-:|---|
| 5 | akita | B | **C** | `akita-20260725-101434/vendor_kernel_boot.img` ramdisk `lib/modules/modules.load` = `gnssif.ko`,`gnss_spi.ko`; ramdisk blocklist empty |
| 6 | tokay | B | **C** | `tokay-20260725-102506/vendor_kernel_boot.img` ramdisk → same |
| 7 | caiman | B | **C** | `caiman-20260922-090535/vendor_kernel_boot.img` ramdisk → same |
| 8 | komodo | B | **C** | `komodo-20260915-063833/vendor_kernel_boot.img` ramdisk → same |
| 9 | comet | B | **C** | `comet-20260922-160129/vendor_kernel_boot.img` ramdisk → same |
| 10 | tegu | B | **C** | `tegu-20260922-164700/vendor_kernel_boot.img` ramdisk → same |
| 11 | stallion | B | **C** | `stallion-20260923-100618/vendor_kernel_boot.img` ramdisk → same |
| 12 | frankel | B | **C** | `frankel-20260923-094457/vendor_dlkm.img` → in `modules.load`, 0 gnss blocklist lines |
| 13 | blazer | B | **C** | `blazer-20260923-090842/vendor_dlkm.img` → same |
| 14 | mustang | B | **C** | `mustang-20260923-094541/vendor_dlkm.img` → same |
| 15 | rango | B | **C** | `rango-20260802-130756/vendor_dlkm.img` → same |

`shiba` / `husky` stay **B** (their shipped `vendor_dlkm` blocklists **do** contain
`blocklist gnssif` / `blocklist gnss_spi`).

### 5.3 `nfc_userspace_hal` on `rango` — 1 cell, `A → B` (self-consistency / `E-19`)

| # | device | old | new | falsifying shipped evidence |
|---|---|:-:|:-:|---|
| 16 | rango | A | **B** | `rango-20260802-130756/vendor.img` → `/overlay/NfcOverlayRangoGsi.apk` + `/etc/libnfc-hal-st_evt.conf` present (both already listed in the ledger's own cited `installed-files-vendor.txt`) |

No NFC **service binary/library** exists, so the correct tier is B (shipped on disk, no transport),
not C and not A. The R1 ledger contradicted its own cited manifest.

### 5.4 New finding `E-R2-1` (reported, not absorbed) — `telemetry_checkin` on `komodo`

Re-deriving the umbrella's two extra rows (below the ledger's 20-service schema) exposed one
shipped-vs-build-tree divergence:

| row | device | umbrella §2 | shipped-stamp derivation | evidence |
|---|---|:-:|:-:|---|
| `telemetry_checkin` | komodo | C\* | **A** | `komodo-20260915-063833/system_ext.img` `/priv-app` = `[EuiccSupportPixel-P23, GuardTalkConfig, GuardTalkValidator, Launcher3QuickStep, Multiuser, PixelDisplayService, Settings, SetupWizard2, SystemUI]` — **no** `GuardTalkCheckin` |

The build tree `out/target/product/komodo/system_ext/priv-app/GuardTalkCheckin` **does** exist, so the
umbrella recorded C\* from build-tree intent. Under the R2 shipped-stamp standard the shipped stamp
is decisive → **A**. `komodo-20260915-063833` predates the 2026-09-16 check-in wiring, consistent
with akita/tokay/rango. **This needs Architect / umbrella adjudication; this card does not edit the
umbrella doc.**

## 6. Umbrella cross-check and the two umbrella-only rows

The umbrella reconciled matrix (`A-EXCISE-AIRGAP-MATRIX_AUDIT.md` §2) has **22 service rows**; this
ledger's card-scoped schema is **20**. Re-derivation of all **260 mapped cells** matches the umbrella
on **259/260**; the single divergence is the card-mandated `E-19` fix (§5.3). Script:
`t_excise_ledger_r2_umbrella_crosscheck.py` → `RESULT: PASS`.

The two umbrella-only rows are **not** ledger verdicts (they belong to other lanes /
`T-EXCISE-MODEM-KERNEL`), but they are re-derived here from shipped stamps for cross-check and
recorded in `coverage_notes`:

| umbrella row | owner | shipped-stamp derivation | matches umbrella? |
|---|---|---|---|
| `cellular_modem_kernel_transport` (`cpif`/`cpif_page`/`shm_ipc`) | `T-EXCISE-MODEM-KERNEL` | **C** 10/13 (shiba,husky,akita,comet,tegu,stallion via `vendor_kernel_boot` ramdisk; frankel,blazer,mustang,rango via `vendor_dlkm`), **A** tokay,caiman,komodo | **13/13 ✅** |
| `telemetry_checkin` (`GuardTalkCheckin`) | SURFACES lane | **C\*** 9/13, **A** akita,tokay,komodo,rango | **12/13** — `komodo` diverges (`E-R2-1`, §5.4) |

> **Scope boundary (`T-EXCISE-MODEM-KERNEL-LEGACY-SCOPE`, 2026-09-26).** The
> `cellular_modem_kernel_transport` row above is **13-device-scoped** — the Gen-8/9/10 program fleet.
> It is **not** a fleet-wide statement: `cpif` / `cpif_page` / `shm_ipc` remain present in the live
> module load lists of **5 out-of-fleet legacy kernel trees** — Pixel 6-gen `raviole`, `bluejay` and
> Pixel 7-gen `pantah`, `lynx`, `felix` (see §1.1). Do **not** cite this row, or the
> `T-EXCISE-MODEM-KERNEL` excision, as evidence that the legacy trees are excised.

## 7. Reproduce / verify

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
E=.agent-comm/evidence/T-EXCISE-LEDGER-R2
L=vendor/guardtalk/docs/qa/excision_ledger.json

# 1. rebuild the ledger from shipped stamps only (read-only; no build, no flash)
python3 $E/t_excise_ledger_r2_collect.py

# 2. positive control (must exit 0): ledger == shipped-stamp re-derivation, 0 recipe evidence
python3 $E/t_excise_ledger_r2_verify.py --ledger $L

# 3. NEGATIVE CONTROL, non-vacuous (must exit NON-ZERO): the pre-R2 ledger
python3 $E/t_excise_ledger_r2_verify.py --ledger $E/excision_ledger.before.json   # -> 16 mismatches

# 4. umbrella cross-check (must exit 0): 260 mapped cells, 1 card-mandated E-19 divergence
python3 $E/t_excise_ledger_r2_umbrella_crosscheck.py

# 5. structural invariants
jq '.devices|length' $L                                                  # -> 13
jq '[.devices[].artifacts[]|select(.evidence_kind!="stamp-image")]|length' $L  # -> 0
jq '[.devices[].artifacts[]|select(.path|startswith("out/"))]|length' $L       # -> 0
jq '.coverage_notes.divergences_vs_umbrella' $L                          # -> 1 (E-R2-1 komodo)
```

**Real exit codes (this run):** positive `0`, negative `1` (16 mismatches), umbrella cross-check `0`.

## 8. Non-claims

- This card does **not** adjudicate the headline airgap verdict, does **not** approve itself, and
  does **not** dispatch a remediation card. The five `A-EXCISE-*` auditor lanes own the per-service
  verdicts; `A-EXCISE-AIRGAP-MATRIX` owns the final headline.
- Reachability adjudication (B vs C) for the Bluetooth userspace HAL and the UWB service is
  explicitly handed to the auditors.
- `E-R2-1` (§5.4) is **reported**, not remediated: `A-EXCISE-AIRGAP-MATRIX_AUDIT.md` is owned by
  another card and was **not** edited.
- The two umbrella-only rows in §6 are **cross-check evidence only** — they are not this ledger's
  tier verdicts and must not be quoted as such.
