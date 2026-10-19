# EXCISION LEDGER — per-device service excision (**2026-09-28 shipped stamps**)

| Field | Value |
|---|---|
| task_id | `T-EXCISE-LEDGER-REBIND` (rebind of `T-EXCISE-LEDGER-R2`) |
| supersedes | `T-EXCISE-LEDGER-R2` (whose stamps predate the 2026-09-28 rebuild/re-stamp) |
| prehistory | `T-EXCISE-LEDGER` (falsified by `Q-EXCISE-LEDGER` on 16/130 cells) |
| role | Backend Engineer (Panel 2) · `aegis-backend-engineer` |
| program | `DEC-EXCISE-AIRGAP-001` — Extreme independent audit of the OS-level airgap claim |
| authority | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` § `EXTREME AUDIT — AIRGAP CLAIM` |
| repository_id | `grapheneos-worktree` |
| status | `REVIEW` (this card never sets `APPROVED`) |
| generated | 2026-09-30T14:10:00+04:00 |
| machine-readable companion | `vendor/guardtalk/docs/qa/excision_ledger.json` (schema 1.3) |
| ledger sha256 | `e01f191f2bf482627dbcafc725533a4e6219eceee3022ca33e5bc5414d54f2e6` |
| checksum manifest | `.agent-comm/evidence/T-EXCISE-LEDGER_SHA256SUMS` (stamp-relative, 0 `out/` paths, 78 rows) |
| manifest sha256 | `c8a3d128ce6683014a38f04b69d4430a113e287aa63d7b38c17a8ba3b188f558` |

> **REBIND (2026-09-30, `T-EXCISE-LEDGER-REBIND`).** R2 was generated 2026-09-25, **before** the
> 2026-09-28 rebuild + re-stamp re-pointed every `<dev>-latest`. Re-running the **same APPROVED R2
> derivation engine** against the 2026-09-28 stamps yields **43 changed cells, all in the
> *more-excised* direction** (see §0.1) — the Sep-28 stamps implemented the GKI BT/NFC module
> blocklists, the BT-free VINTF swap, the `radioExternal` HAL removal, the GNSS-userspace removal and
> the laguna `nitrous` blocklist. **One derivation fix** was required (radio-free detection, §0.1) —
> it is a **strengthening**, not a relaxation; both readings are preserved. The checksum manifest is
> re-bound to stamp-relative paths so no `out/` rebuild can invalidate it.

**Scope.** The machine-readable **per-device excision ledger** for the 13 Gen 8/9/10 program
devices, re-derived **from the shipped release stamps only** — `releases/desktop-flash/<stamp>/*.img`,
read read-only with `debugfs` and, for the `vendor_kernel_boot.img` vendor ramdisk, with a
`VNDRBOOT` v4 + legacy-LZ4 + `newc` cpio unpacker.

**Change vs R1.** R1 mixed shipped stamps with `out/target/product/<dev>/` **build-tree** artifacts
(652 of its 665 rows were build-tree). R2's `artifacts[]` array is **100 % `evidence_kind="stamp-image"`**
(273 rows). Build-tree artifacts are recorded separately in `devices[].build_tree_corroboration`
with `tier_contribution=false` and are **never** tier-bearing. **No cell cites a build-recipe artifact.**

**Change vs R2 (rebind).** Same stamp-image-only schema (**273** `stamp-image` rows, 0 build-tree
tier-bearing rows) but re-derived from the **2026-09-28** stamps; **43 cells changed** (§0.1). The
checksum manifest is now **stamp-relative** (0 `out/` paths) so a rebuild of `out/` cannot invalidate it.

**Tier standard (adjudication is owned by the five `A-EXCISE-*` auditor lanes, not by this card):**

| Tier | Meaning | Acceptable for an "airgapped" claim? |
|---|---|---|
| **A — ABSENT** | Not present in the shipped artifacts at all | Yes |
| **B — DORMANT** | Shipped on disk, but no transport / blocklisted / no HAL / feature-gate off | **Requires explicit operator waiver** |
| **C — REACHABLE** | Shipped and can become active (in `modules.load` and unblocklisted, or a boot-started service) | **No — audit FAIL** |

## 0. Honesty holds

- `LIVE_FLASH_CLAIMED = false` — no device was flashed or booted; no `adb`/`fastboot` was run.
- `BOOT_VERIFIED = false`; no boot-green result is claimed for any device (`rango` included).
- `Gate -1: IN-PROCESS` — local governance YAML loaded; **no** `aegis-verifier` / `ask_guardian` /
  `gate_enforcer` / Guardian HTTP call was made (all absent or `rc=124` in this environment).
- `Gate 5: IN-PROCESS self-critique, 88/100` — the MCP `ultimate_critique` endpoint is unavailable here,
  so **no external score is invented or claimed**; the self-critique and its findings live in the
  completion report `.agent-comm/inbox/TO_ARCHITECT_T-EXCISE-LEDGER-REBIND.md`.
- `build_recipe_evidence_used = false` — verified structurally, not just by grep (§7).
- Every cell is re-derived from a shipped stamp image; the shipped stamp is **decisive**.
- `rango-latest` now resolves to `rango-20260928-081134` (the 2026-09-28 re-stamp); **this card moved
  no `<dev>-latest` pointer and no flash pointer** — the only files it edits are the ledger doc, the
  ledger JSON, and its checksum manifest.
- No product / filter / flash / packer / doctrine / governance file was edited; nothing was rebuilt
  or re-stamped by this card.
- **Dissent preserved (not absorbed):** where the shipped stamp disagrees with a prior audit that
  used the build tree, the disagreement is recorded, not hidden (`E-R2-1`, §5.4).
- **Declared pinning gap:** the checksum manifest pins the **six ext4 images** per stamp. `vendor_kernel_boot.img`
  is a **VNDRBOOT** (non-ext4) container and is **not** byte-pinned; the first-stage `modules.load` /
  `modules.blocklist` it supplies are tier-bearing for the kernel rows and are recorded per-row
  (`vkb ramdisk load=…`), reproducible from the named stamp path but **not** hash-anchored
  (`coverage_notes.hash_pinning_gap`).

### 0.1 REBIND vs R2 (2026-09-30) — 43 cells changed, all more-excised; 1 derivation fix

R2 resolved the **pre-2026-09-28** stamps. The 2026-09-28 clean rebuild + re-stamp changed the shipped
bytes, so the rebind re-derives from the current `<dev>-latest` stamps. **43 of 260 cells changed; every
change lowers a tier** (no cell became *less* excised). Grouped:

| service | cells | R2 | rebind | shipped-stamp cause |
|---|---|:-:|:-:|---|
| `bluetooth_userspace_hal` | 13 (all) | B | **A** | vendor VINTF manifest is now `vendor_manifest_no_bt_*.xml`: **0** `android.hardware.bluetooth` declarations |
| `bluetooth_gki_modules` | 9 | C | **B** | the 8 GKI BT/NFC modules are now `blocklist`-ed in `system_dlkm` (T-EXCISE-GKI-BT-MODULES, `E-14`) — **residual C on the 4 laguna stamps** (below) |
| `nfc_kernel_module` | 9 | C | **B** | `blocklist nfc.ko` in `system_dlkm` — **residual C on the 4 laguna stamps** |
| `cellular_vendor_radioExternal_hal` | 6 | B | **A** | the `…radioExternal-V1-ndk.so` no longer ships in `vendor.img` `/lib64` |
| `nitrous_module` | 4 (laguna) | C | **B** | `blocklist nitrous` is now present in the laguna `vendor_dlkm` blocklist |
| `location_gnss` | 2 (shiba, husky) | C | **A** | the GNSS userspace stack (`/bin/hw/gpsd`, `/etc/gnss`, `init.gps.rc`) no longer ships |

**Residual (not hidden).** `bluetooth_gki_modules` / `nfc_kernel_module` remain **C on the 4 `laguna`
stamps** (frankel, blazer, mustang, rango): their `system_dlkm` `modules.load` still lists the 8 BT/NFC
modules with **no** matching `blocklist` line. Reported here, not remediated by this card.

**Derivation fix (strengthening).** `cellular_ril_native` is **A on 13/13**. The R2 engine tested
radio-free via the substring `no_radio` in the manifest *provenance filename*; the Sep-28 swap renamed
that manifest to `vendor_manifest_no_bt_*.xml`, whose own in-file comment documents it as the `no_radio`
manifest **minus the four Bluetooth HAL declarations**. The filename test therefore produced a **false
"radio reachable" (C)** on a manifest with **0** `android.hardware.radio` HALs and **no** `rild` in
`/bin/hw`. The rebind measures the shipped bytes (0 radio decls) — **strictly stronger** than the
filename token — and preserves both readings (`derivation_fixes` in the JSON). This is **not** a
relaxation.

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
| shiba | `zuma_shusky` | shiba-20260928-040745 | `symlink shiba-latest` | 112,967,820 |
| husky | `zuma_shusky` | husky-20260928-042016 | `symlink husky-latest` | 112,967,820 |
| akita | `zuma_akita` | akita-20260928-083403 | `symlink akita-latest` | 115,355,788 |
| tokay | `zumapro_caimito` | tokay-20260928-084839 | `symlink tokay-latest` | 136,634,508 |
| caiman | `zumapro_caimito` | caiman-20260928-052519 | `symlink caiman-latest` | 136,634,508 |
| komodo | `zumapro_caimito` | komodo-20260928-052609 | `symlink komodo-latest` | 136,634,508 |
| comet | `zumapro_comet` | comet-20260928-050352 | `symlink comet-latest` | 136,634,508 |
| tegu | `zumapro_tegu` | tegu-20260928-051613 | `symlink tegu-latest` | 98,766,988 |
| stallion | `zumapro_stallion` | stallion-20260928-052826 | `symlink stallion-latest` | 191,426,700 |
| frankel | `laguna_muzel` | frankel-20260928-055107 | `symlink frankel-latest` | 191,426,700 |
| blazer | `laguna_muzel` | blazer-20260928-060401 | `symlink blazer-latest` | 191,426,700 |
| mustang | `laguna_muzel` | mustang-20260928-061721 | `symlink mustang-latest` | 191,426,700 |
| rango | `laguna_rango` | rango-20260928-081134 | `symlink rango-latest` | 191,426,700 |

**† `tokay-latest` now exists** — the 2026-09-28 re-stamp created it (`tokay-latest ->
tokay-20260928-084839`). This ledger resolves every device (tokay included) via `<dev>-latest`. **⚠ The
global `releases/desktop-flash/latest` symlink still points at the July `tokay-20260725-102506`**, so the
*flash path* would still ship the July tokay bundle; that pointer defect is owned by
`T-EXCISE-TOKAY-LATEST-REPOINT` and is **not** changed here. The divergence is recorded, not hidden.

## 3. Service tier matrix (13 devices × 20 services) — from shipped stamps

Each cell is the worst (highest) tier observed for that device/service across the shipped artifact
rows. **Bolded cells are the 43 rebind deltas vs R2** (§0.1). The 2026-09-28 stamps are **more excised**
than the umbrella's pre-Sep-28 baseline, so the matrix now diverges from `A-EXCISE-AIRGAP-MATRIX_AUDIT.md`
§2 on exactly those cells — that doc is owned by another lane and is **not** edited here. The R2-era
`nfc_userspace_hal`/`rango` fix (`E-19`, §5.3) remains.

| service | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `baseband_firmware` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `cellular_ril_native` | A | A | A | A | A | A | A | A | A | A | A | A | A |
| `cellular_vendor_radioExternal_hal` | A | A | A | A | A | A | A | **A** | **A** | **A** | **A** | **A** | **A** |
| `cellular_framework_telephony` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `telephony_feature_declarations` | B | B | B | A | B | B | B | B | B | B | B | B | B |
| `bluetooth_userspace_hal` | **A** | **A** | **A** | **A** | **A** | **A** | **A** | **A** | **A** | **A** | **A** | **A** | **A** |
| `bluetooth_gki_modules` | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | C | C | C | C |
| `nitrous_module` | B | B | B | B | B | B | B | B | B | **B** | **B** | **B** | **B** |
| `location_gnss` | **A** | **A** | A | A | A | A | A | A | A | A | A | A | A |
| `location_gnss_kernel` | B | B | C | C | C | C | C | C | C | C | C | C | C |
| `nfc_userspace_hal` | A | A | A | A | A | A | A | A | A | A | A | A | **B** |
| `nfc_kernel_module` | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | **B** | C | C | C | C |
| `uwb_hal_service` | A | C | A | A | C | C | C | A | A | A | C | C | C |
| `uwb_kernel` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `apex_dormant_set` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `appsearch_apex` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `telemetry_profiling` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `connectivity_wifi_tethering` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `sensors_camera_mic_privacy` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `variant_resolution` | B | B | B | B | B | B | B | B | B | B | B | B | B |

## 4. Service findings (primary shipped artifacts)

### 4.1 Baseband firmware — Tier B, 13/13
Every stamp carries `radio.img` (sizes in §2); the baseband firmware is staged for flashing and
there is no shipped-artifact evidence it is inert. Confirms `E-1`. **Operator waiver required.**

### 4.2 Cellular native RIL — Tier A, 13/13
The shipped vendor *main* `manifest.xml` is the radio-free `vendor_manifest_no_bt*` variant (the
2026-09-28 swap; its in-file comment documents it as the `no_radio` manifest **minus the four
Bluetooth HAL declarations**) with **0** `android.hardware.radio` declarations, and no `rild` service
exists in the shipped `/bin/hw` → **A**. **Law 7 correction (2026-09-26,
`T-EXCISE-CLAIM-HONESTY-RESIDUAL`):** only the *main* manifest is radio-free; historically a `dmd.xml`
runtime fragment re-declared a telephony `oemservice` HAL (`IOemService/dm0`,`dm1`) on **13/13**
(`H-R2`; `A-2`; RADIO `F-003`). `T-EXCISE-VINTF-DMD` filtered `dmd.xml` at source, and **no
2026-09-28 stamp ships a `dmd` fragment** (verified 0/13). Confirms the host-transport half of `E-6`.

### 4.3 Cellular vendor `radioExternal` HAL — Tier A, 13/13 (REBIND: was B on 6)
The `vendor.samsung_slsi.telephony.hardware.radioExternal-V1-ndk.so` **no longer ships** in `vendor.img`
`/lib64` on any of the 13 2026-09-28 stamps (it did on tegu, stallion, frankel, blazer, mustang, rango
in the pre-Sep-28 stamps) → **A on 13/13** (§0.1). Confirms `E-2` and records its removal.

### 4.4 Cellular framework telephony — Tier B, 13/13 (correction to `E-6`)
`telephony-common.jar` is present in the shipped `system.img` on all 13. `E-6`'s "0 telephony in
`system/`" holds for native RIL binaries, not for framework telephony classes. Tier B.

### 4.5 Telephony feature declarations — B on 12, A on 1
`product/etc/permissions/android.hardware.telephony.euicc.xml` ships on 12/13; **tokay is the
exception** (0 eUICC entries). Tier B where present, A on tokay.

### 4.6 Bluetooth userspace HAL — Tier A, 13/13 (REBIND: was B on 13)
Every 2026-09-28 vendor `manifest.xml` is now the **BT-free** `vendor_manifest_no_bt_*.xml` with **0**
`android.hardware.bluetooth*` declarations, and no BT-audio HAL impl ships in `/lib64` → **A** (§0.1).
The pre-Sep-28 stamps declared the four BT HALs → B; the Sep-28 VINTF swap removed them.

### 4.7 Bluetooth GKI kernel modules — Tier B on 9, C on 4 laguna (REBIND)
`system_dlkm/lib/modules/modules.load` still lists `bluetooth.ko`, `hci_uart.ko`, `btbcm.ko`, `btqca.ko`,
`btsdio.ko`, `rfcomm.ko`, `hidp.ko` on all 13, but on **9** stamps they are now `blocklist`-ed
(T-EXCISE-GKI-BT-MODULES, `E-14`) → **B**. **Residual: C on the 4 `laguna` stamps** (frankel, blazer,
mustang, rango), which ship **no** matching `blocklist` line (§0.1). Reported, not remediated here.

### 4.8 `nitrous` — Tier B, 13/13 (REBIND: laguna C → B)
Shipped `vendor_dlkm/lib/modules/`: `nitrous.ko` is in `modules.load` on all 13, and `blocklist nitrous`
is now present on **all 13**, including the 4 `laguna` stamps → **B** (§0.1). The pre-Sep-28 laguna
stamps carried a stock un-excised blocklist (R2 §5.1); the Sep-28 rebuild added the line.

### 4.9 Location / GNSS — userspace **A on 13**, kernel **C on 11** (REBIND)
**Userspace:** no 2026-09-28 stamp ships a GNSS userspace stack; `shiba`/`husky` (the R2 `C` cells) now
ship **none** of `/bin/hw/gpsd`, `/lib64/hw/gps.default.so`, `/etc/gnss/*`, `/etc/init/init.gps.rc`
→ **A on 13/13** (§0.1).
**Kernel:** `gnssif.ko` / `gnss_spi.ko` are **unblocklisted** on **11/13** → **C**:
- `shiba`, `husky`: present in `vendor_dlkm` `modules.load` **and** `blocklist gnssif`/`gnss_spi`
  present → **B** (unchanged).
- `akita`, `tokay`, `caiman`, `komodo`, `comet`, `tegu`, `stallion`: absent from `vendor_dlkm`, but
  present in the **`vendor_kernel_boot.img` vendor ramdisk** `lib/modules/modules.load` with **0**
  ramdisk blocklist entries → **C**.
- `frankel`, `blazer`, `mustang`, `rango`: in `vendor_dlkm` `modules.load`, **no** gnss blocklist
  lines → **C**.
See §5.2.

### 4.10 NFC — userspace B on rango, A elsewhere; kernel B on 9, C on 4 laguna (REBIND)
`nfc.ko` is in `system_dlkm` `modules.load` on 13/13, but is now **`blocklist`-ed on 9** → **B**;
**residual C on the 4 laguna stamps** (§0.1). `com.android.nfcservices` APEX ships 13/13 → B.
**Userspace HAL:** no NFC service binary/lib on any device; but `rango`'s shipped `vendor.img` carries
`/overlay/NfcOverlayRangoGsi.apk` and `/etc/libnfc-hal-st_evt.conf` → **B on rango** (not A). See §5.3.

### 4.11 UWB — HAL C on 7, A on 6; kernel C 13/13
A boot-started UWB HAL service + `init.rc` ships on **husky, caiman, komodo, comet, blazer, mustang,
rango** → C on those 7; absent on the other 6 → A. `aoc_uwb_*` kernel modules are in `modules.load`
and unblocklisted → C 13/13. `com.android.uwb.apex` ships 13/13 → B.

### 4.12 APEX dormant set — Tier B (per-device coverage)
Shipped on all 13: `bt`, `nfcservices`, `adservices`, `healthfitness`,
`ondevicepersonalization`, `uwb`, `profiling`, `uprobestats`, `telephonycore`. **`devicelock` now ships
on none of the 13** — it shipped on akita, tokay, rango in the pre-Sep-28 stamps; the 2026-09-28 rebuild
dropped `com.android.devicelock.apex` (verified) (§0.1). `cellbroadcast` ships on **none** (corrects the
`E-3` list). All B.

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

## 5. The 17 R2 corrections (historical baseline)

> **Superseded where they differ.** §5 records R2's corrections against the **pre-2026-09-28** stamps
> (their falsifying evidence names those stamps). The **rebind deltas vs R2 are in §0.1 and §3**; where
> a cell here disagrees with §3, **§3 governs**. `nitrous_module` (5.1) and `location_gnss_kernel`
> (5.2) largely survive; `location_gnss` userspace (5.2 precursor) is now A on 13.

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

> **REBIND update (2026-09-30).** On the 2026-09-28 stamps this **reverses**: `komodo-20260928-052609`
> **does** ship `GuardTalkCheckin`, so `komodo` now matches the umbrella (`C*`); the divergences move to
> **akita, tokay, rango** (see §6). `E-R2-1` is therefore closed by the re-stamp, not by an edit.

## 6. Umbrella cross-check and the two umbrella-only rows

The umbrella reconciled matrix (`A-EXCISE-AIRGAP-MATRIX_AUDIT.md` §2) has **22 service rows**; this
ledger's card-scoped schema is **20**. **⚠ REBIND:** the R2-era claim ("260 mapped cells match 259/260")
was against the **pre-Sep-28** stamps. The 2026-09-28 stamps are more excised, so the main matrix now
diverges from the umbrella on the **43 rebind cells** (§0.1). That umbrella doc is owned by another lane
and is **not** edited here; the divergence is reported for its owner to re-derive. The R2 cross-check
script (`t_excise_ledger_r2_umbrella_crosscheck.py`) encodes the **pre-Sep-28** expectations and is
**not** re-run as a pass/fail gate by this card.

The two umbrella-only rows are **not** ledger verdicts (they belong to other lanes /
`T-EXCISE-MODEM-KERNEL`), but they are re-derived here from the 2026-09-28 shipped stamps for
cross-check and recorded in `coverage_notes`:

| umbrella row | owner | 2026-09-28 shipped-stamp derivation | vs umbrella |
|---|---|---|---|
| `cellular_modem_kernel_transport` (`cpif`/`cpif_page`/`shm_ipc`) | `T-EXCISE-MODEM-KERNEL` | **A** 9/13 (shiba, husky, akita, tokay, caiman, komodo, comet, tegu, stallion), **B** 4/13 (frankel, blazer, mustang, rango) | **diverges on 10** (umbrella recorded C 10 / A 3) — the Sep-28 stamps excise further; owner to re-derive |
| `telemetry_checkin` (`GuardTalkCheckin`) | SURFACES lane | **C\*** 13/13 (every stamp now ships `GuardTalkCheckin` in `system_ext` `/priv-app`) | **diverges on 3** (akita, tokay, rango; umbrella recorded A) — reverses the R2 `komodo` finding (§5.4) |

> These two rows are **cross-check evidence only** — they are not this ledger's 20-service verdicts and
> must not be quoted as such.

> **Scope boundary (`T-EXCISE-MODEM-KERNEL-LEGACY-SCOPE`, 2026-09-26).** The
> `cellular_modem_kernel_transport` row above is **13-device-scoped** — the Gen-8/9/10 program fleet.
> It is **not** a fleet-wide statement: `cpif` / `cpif_page` / `shm_ipc` remain present in the live
> module load lists of **5 out-of-fleet legacy kernel trees** — Pixel 6-gen `raviole`, `bluejay` and
> Pixel 7-gen `pantah`, `lynx`, `felix` (see §1.1). Do **not** cite this row, or the
> `T-EXCISE-MODEM-KERNEL` excision, as evidence that the legacy trees are excised.

## 7. Reproduce / verify

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
E=.agent-comm/evidence/T-EXCISE-LEDGER-REBIND
L=vendor/guardtalk/docs/qa/excision_ledger.json
M=.agent-comm/evidence/T-EXCISE-LEDGER_SHA256SUMS

# 1. re-derive the ledger from the 2026-09-28 shipped stamps (read-only; no build, no flash)
python3 $E/rebind_collect.py

# 2. the card verifier (structural invariants + stamp-bound manifest) -> RESULT: PASS
bash .agent-comm/evidence/T-EXCISE-LEDGER_verify.sh

# 2b. stamp-bound manifest: rc=0, 0 FAILED, 0 missing, 0 out/ paths
sha256sum -c $M

# 3. positive control (must exit 0): ledger == 2026-09-28 stamp re-derivation
python3 $E/rebind_verify.py --ledger $L

# 4. NEGATIVE CONTROL, non-vacuous (must exit NON-ZERO): the pre-rebind R2 ledger
python3 $E/rebind_verify.py --ledger $E/before/excision_ledger.json      # -> 43 mismatches

# 5. manifest negative control: a tampered hash must FAIL
sha256sum -c /tmp/ledgerneg/manifest_tampered.sha256                     # -> FAILED, rc=1

# 6. structural invariants
jq '.devices|length' $L                                                  # -> 13
jq '[.devices[].artifacts[]|select(.evidence_kind!="stamp-image")]|length' $L  # -> 0
jq '[.devices[].artifacts[]|select(.path|startswith("out/"))]|length' $L       # -> 0
rg -c 'makefile|\.mk' $L                                                 # -> rc=1 (0 matches)
grep -c ' out/' $M                                                       # -> 0
```

**Real exit codes (this run):** positive `0` (0/260 mismatches), negative `1` (43 mismatches), tampered
manifest `1`; card verifier `RESULT: PASS`; `sha256sum -c` `rc=0` with **78 OK / 0 FAILED**.

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
