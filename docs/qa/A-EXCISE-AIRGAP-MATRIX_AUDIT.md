# A-EXCISE-AIRGAP-MATRIX — Airgap Claim Umbrella Adjudication (Panel 5, Auditor)

| Field | Value |
|---|---|
| task_id | `A-EXCISE-AIRGAP-MATRIX` |
| role | Auditor — Independent Deep Tech (Panel 5), **umbrella adjudicator** |
| owner repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id: grapheneos-worktree`) |
| audit_scope | `full` (adjudicates the five P0 service lanes + backend ledger) |
| status transition | BLOCKED → **REVIEW** (this auditor never sets `APPROVED`) |
| verdict authority | Owns the **final verdict** on the airgap claim and the residual register; reports as **REVIEW** to the Architect |
| **Gate -1** | **IN-PROCESS** — `.aegis/governance/laws/*.yaml` (24) + `.aegis/governance/gates/*.yaml` (11) loaded from disk. `governance_loaded=true`. No aegis-verifier / `ask_guardian` / `gate_enforcer` / Guardian HTTP call was made. |
| **Gate 5** | **HUMAN SKIP** — no numeric self-critique score is invented. |
| `LIVE_FLASH_CLAIMED` | **false** — no hardware, no USB/adb/fastboot; no boot result claimed for any device (`rango` included). |
| Timestamp | 2026-09-24T17:09:00+04:00 |
| Write surface | This report + `.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/*` + one `.agent-comm/history/` event + `.agent-comm/signals/review-A-EXCISE-AIRGAP-MATRIX.json`. No product/test/filter/flash/packer/doctrine/queue file edited. `.agent-comm/inbox/TO_ARCHITECT.md` was **NOT** touched. |

---

## 0. Claim under adjudication and standard

> *Every GuardTalkOS feature that is supposed to make the OS effectively airgapped — cellular
> radio/modem/RIL/telephony, Bluetooth, Location/GNSS, and every other connectivity, telemetry
> and remote-surface service — is **100% removed** from the built image on **every** Pixel model
> GuardTalk builds.*

**Standard (from `TASK_QUEUE.md` §A1):**

| Tier | Meaning | Acceptable for an "airgapped" claim? |
|------|---------|--------------------------------------|
| **A — ABSENT** | Not present in the built artifacts at all | Yes |
| **B — DORMANT** | Code/firmware on disk, no transport/HAL/feature gate; not reachable at runtime | **Requires explicit operator waiver; must NEVER be reported as a removal** |
| **C — REACHABLE** | Present and can become active | **No — audit FAIL** |

**Operative kernel rule used uniformly by this adjudication** (the same rule the ledger and the
BT lane already applied to `bluetooth_gki_modules`): **a module listed in a shipped `modules.load`
and not matched by `modules.blocklist` is loaded at boot ⇒ Tier C**; a module present but
blocklisted (or absent from `modules.load`) ⇒ Tier B/A. `CanonicalizeModulePath` strips `.ko`, so
`nitrous` ≡ `nitrous.ko`.

**Audited build set = the 13 Gen 8/9/10 program devices** and their **advertised `*-latest` stamp**
(`tokay` has **no `tokay-latest`**; its stamp is the global `latest → tokay-20260725-102506`).
**Gen 6 (`gs101`) / Gen 7 (`gs201`) = AUDITED ABSENCE** (§10).

---

## 1. HEADLINE VERDICT (per service and per device — never one blanket green)

### 1.1 Per service (literal "100% removed" claim)

| Service | Verdict | Decisive falsifier |
|---|---|---|
| **Cellular / radio / modem / RIL / telephony** | **FALSE** | Loaded kernel modem transport (`cpif`/`cpif_page`/`shm_ipc`) on **10/13** (Tier C); runtime VINTF still advertises a telephony/modem HAL (`dmd.xml`) on **13/13**; baseband firmware shipped **and flashed** on **13/13** (Tier B, no waiver). |
| **Bluetooth** | **FALSE** | 8 BT/NFC GKI transport modules in `system_dlkm/modules.load` and **0 blocklisted on 13/13** (Tier C); `nitrous.ko` in `modules.load` and **not blocklisted on 4/13** laguna `-latest` (Tier C); 4 BT HALs still declared in the shipped vendor VINTF manifest on **13/13**; BT-audio HAL libs + `bluetooth_audio.xml` on **13/13**. |
| **Location / GNSS** | **FALSE** | `shiba`/`husky` ship `gpsd`/`lhd`/`scd` in **`class main` with no `disabled`** → init-started at boot, plus `gps.default.so` + `/etc/gnss/*` (Tier C); GNSS kernel modules in `modules.load` unblocklisted on **11/13** (Tier C). |
| **Other connectivity / telemetry / remote surfaces** | **FALSE** | `GuardTalkCheckin` outbound telemetry client shipped on **10/13** (Tier C by design); WiFi/tethering/IPsec retained on **13/13** (Tier C by design); UWB HAL service init-started on **7/13**; UWB + NFC kernel modules loaded **13/13**. |
| **Overall (literal universal claim)** | **FALSE** | The claim cannot be sustained on any of the four service families. It is **never `TRUE`**. The most waiver-generous outcome achievable — after Tier-C remediation and operator waivers — is **`TRUE-WITH-DORMANT-RESIDUALS`**, and only if the 4 hybrid stamps are repointed or explicitly excluded (§5). |

### 1.2 Per device (worst tier in the connectivity/excision set)

**Every one of the 13 devices is Tier C somewhere ⇒ per-device verdict `FALSE` for the literal
claim. No device is `TRUE`; no device is even `TRUE-WITH-DORMANT-RESIDUALS`-only.**

| Device | Gen | Worst tier | Tier-C driver(s) | Per-device verdict |
|---|---|---|---|---|
| `shiba` | 8 | **C** | modem transport loaded; GNSS userspace init-started; BT/NFC GKI; GNSS kernel loaded (blocklisted, B); UWB kernel | **FALSE** |
| `husky` | 8 | **C** | same as `shiba` (+ UWB HAL service) | **FALSE** |
| `akita` | 8 | **C** | modem transport loaded; BT/NFC GKI; GNSS kernel loaded; UWB kernel | **FALSE** |
| `tokay` | 9 | **C** | BT/NFC GKI; GNSS kernel loaded; UWB kernel | **FALSE** |
| `caiman` | 9 | **C** | BT/NFC GKI; GNSS kernel loaded; UWB kernel + HAL service | **FALSE** |
| `komodo` | 9 | **C** | BT/NFC GKI; GNSS kernel loaded; UWB kernel + HAL service | **FALSE** |
| `comet` | 9 | **C** | modem transport loaded; BT/NFC GKI; GNSS kernel loaded; UWB kernel + HAL service | **FALSE** |
| `tegu` | 9 | **C** | modem transport loaded; BT/NFC GKI; GNSS kernel loaded; UWB kernel | **FALSE** |
| `stallion` | 9 | **C** | modem transport loaded; BT/NFC GKI; GNSS kernel loaded; UWB kernel | **FALSE** |
| `frankel` | 10 | **C** | modem transport loaded (dlkm); **nitrous unblocked**; BT/NFC GKI; GNSS kernel loaded; UWB kernel | **FALSE** |
| `blazer` | 10 | **C** | same as `frankel` (+ UWB HAL service) | **FALSE** |
| `mustang` | 10 | **C** | same as `frankel` (+ UWB HAL service) | **FALSE** |
| `rango` | 10 | **C** | modem transport loaded (dlkm); **nitrous unblocked**; BT/NFC GKI; GNSS kernel loaded; UWB kernel + HAL service | **FALSE** |

---

## 2. Reconciled 13 × service Tier A/B/C ledger

Legend: **A** absent · **B** dormant (waiver required) · **C** reachable (FAIL) · **C\*** Tier C
**by design** (documented, operator-visible exception) · `—` n/a.
This is the single reconciled table (five lanes + backend ledger + umbrella re-derivation).
Bolded cells are where this adjudication **differs** from the backend ledger.

| service (artifact) | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `baseband_firmware` (`radio.img`/`modem.img` + stamp) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `cellular_ril_native` (rild/libril/sitril) | A | A | A | A | A | A | A | A | A | A | A | A | A |
| **`cellular_modem_kernel_transport`** (`cpif`/`cpif_page`/`shm_ipc`) — **new row** | **C** | **C** | **C** | A | A | A | **C** | **C** | **C** | **C** | **C** | **C** | **C** |
| `cellular_vendor_radioExternal_hal` | A | A | A | A | A | A | A | B | B | B | B | B | B |
| `cellular_framework_telephony` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `telephony_feature_declarations` (euicc) | B | B | B | A | B | B | B | B | B | B | B | B | B |
| `bluetooth_userspace_hal` (VINTF decl + audio libs) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `bluetooth_gki_modules` (8 BT/NFC) | C | C | C | C | C | C | C | C | C | C | C | C | C |
| **`nitrous_module`** | B | B | B | B | B | B | B | B | B | **C** | **C** | **C** | **C** |
| `location_gnss_userspace` (gpsd/lhd/scd/init.gps.rc) | **C** | **C** | A | A | A | A | A | A | A | A | A | A | A |
| **`location_gnss_kernel`** (`gnssif`/`gnss_spi`) | **B** | **B** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** | **C** |
| `nfc_userspace_hal` | A | A | A | A | A | A | A | A | A | A | A | A | A |
| `nfc_kernel_module` (`nfc.ko`) | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `uwb_hal_service` | A | C | A | A | C | C | C | A | A | A | C | C | C |
| `uwb_kernel` (`aoc_uwb_*`) | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `apex_dormant_set` (bt/nfcservices/uwb/adservices/…) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `appsearch_apex` | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| **`telemetry_checkin`** (`GuardTalkCheckin`) — **new row** | **C\*** | **C\*** | A | A | **C\*** | **C\*** | **C\*** | **C\*** | **C\*** | **C\*** | **C\*** | **C\*** | A |
| `telemetry_profiling` (adservices/uprobestats/…) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `connectivity_wifi_tethering` (WiFi/IPsec/tethering) | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| `sensors_camera_mic_privacy` | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| `variant_resolution` (excision resolver) | B | B | B | B | B | B | B | B | B | B | B | B | B |

**Counts (reconciled, 22 service rows × 13 = 286 cells):** Tier A = **57** · Tier B = **107** ·
Tier C = **73** · Tier C\* = **49**. (The backend ledger's own 665-cell set is a finer-grained
per-artifact expansion; the tier *verdicts* that differ are enumerated in §5.)

**Structural gaps corrected in this table:** the backend ledger had **no row** for the
`cpif`/`shm_ipc` modem kernel transport and **no row** for the shipped `GuardTalkCheckin` client —
the two most consequential falsifiers of the radio and "telemetry" clauses respectively.

---

## 3. D1–D4 — artifact-level disputes adjudicated from primary artifacts

All four were re-derived directly (not accepted from either side). Raw evidence under
`.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/`.

### D1 — RADIO F-001 (`cpif`/`cpif_page`/`shm_ipc`) — TRUE PER-DEVICE SET = **10/13**, loaded

**Method.** `vendor_kernel_boot.img` is a **VNDRBOOT** image, not ext4 — `debugfs` cannot read it.
I unpacked the header, **LZ4-decompressed the vendor ramdisk, and read the real CPIO** (§
`vndrboot_unpack.py`, `d1_check.sh`), then read `modules.load`; separately I read each stamp's
`vendor_dlkm.img` via `debugfs`.

**Result — the true set (present + in `modules.load`):**

| Partition carrying the 3 modules | Devices | Count |
|---|---|---|
| `vendor_kernel_boot.img` ramdisk (`lib/modules/*.ko` + `modules.load`) | `shiba`, `husky`, `akita`, `comet`, `tegu`, `stallion` | 6 |
| `vendor_dlkm.img` (`/lib/modules/*.ko` + `modules.load`) | `frankel`, `blazer`, `mustang`, `rango` | 4 |
| **Tier A (absent everywhere)** | `tokay`, `caiman`, `komodo` | 3 |
| **Tier C total** | | **10** |

- **Ruling:** true per-device set = **10/13** and the modules **are in `modules.load`** (explicit
  load list) — so **Tier C**, not dormant. Evidence:
  `.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/D1-modem-transport.txt`.
- **The RADIO lane (9/13) undercounted by `rango`** — it listed `frankel`/`blazer`/`mustang` but not
  `rango`, whose shipped `vendor_dlkm.img` carries the same three modules in `modules.load`.
- **The Architect's raw-grep (6/13) is a partition error:** the four laguna hybrids carry `cpif`
  in **`vendor_dlkm`**, not `vendor_kernel_boot` (raw `grep -c cpif` on `rango` stamp:
  `vendor_kernel_boot=0`, `vendor_dlkm=715`). Raw-grep on the LZ4-compressed ramdisk is also
  unreliable. The Architect's "0 on `rango`" is falsified.
- **Correction to F-001:** F-001 is **correct but incomplete** (9 → 10 devices, add `rango`).

### D2 — RADIO F-005 vs retracted `E-12` (`androidboot.radio.disabled` in `vendor_boot.img`)

**Method.** Parsed the VNDRBOOT v4 header and inspected both the **header `cmdline` field** and
the **trailing `bootconfig` section** per stamp (no shell `-n`/`|| echo 0` construct).

**Result:** present in the header cmdline of **9/13**: `shiba`, `husky`, `akita`, `tokay`,
`caiman`, `komodo`, `comet`, `tegu`, `stallion`; **absent on 4/13**: `frankel`, `blazer`,
`mustang`, `rango`. Evidence: `.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/D2-radio-disabled-stamps.txt`.

- **Ruling:** the **RADIO lane F-005 is CORRECT** ("present 9/13, absent on the 4 laguna stamps").
- **The Architect's retraction of `E-12` is itself wrong on one device:** it claims present **8/13**
  and absent on `tokay`; `tokay`'s shipped `vendor_boot.img` **does** contain
  `androidboot.radio.disabled=1`. `E-12` must be amended to **9/13 present / 4 absent**, not 8/5.
- The earlier "13/13" was indeed a `-n`-test false positive (as retracted), but the replacement
  8/13 figure is a second, smaller measurement error. Neither the 13/13 nor the 8/13 figure may be
  quoted; **9/13 is the re-derived value.**

### D3 — LOC B vs C for `shiba`/`husky` GNSS — **Tier C (Architect upheld)**

**Method.** Read the shipped `vendor.img` `/vendor/etc/init/init.gps.rc` and the `/bin/hw`,
`/lib64/hw`, `/etc/gnss` listings on all 13 stamps.

**Result (shipped `vendor.img`, `shiba` + `husky`):**
```
service lhd /vendor/bin/hw/lhd /vendor/etc/gnss/lhd.conf      → class main   (no disabled)
service gpsd /vendor/bin/hw/gpsd -c /vendor/etc/gnss/gps.xml → class main   (no disabled)
service scd /vendor/bin/hw/scd /vendor/etc/gnss/scd.conf     → class main   (no disabled)
service gnss_service /vendor/bin/hw/android.hardware.gnss@2.1-service-brcm → class hal  (binary ABSENT)
```
- `/vendor/bin/hw/{gpsd,lhd,scd}` present, mode 0755; `/lib64/hw/gps.default.so` present
  (269,656 B); `/etc/gnss/{gps.cer,gps.xml,lhd.conf,scd.conf}` present; `init.gps.rc` 725 B.
- `android.hardware.gnss@2.1-service-brcm` is **absent on all 13** (including `shiba`/`husky`).
- The other 11 stamps have **0** of these artifacts.

- **Ruling:** **Tier C on `shiba`/`husky`.** `class main` services with no `disabled` keyword are
  started by `init` at boot, and `gpsd`/`lhd`/`scd` are standalone Lassen/Broadcom GNSS daemons
  (not the framework HAL). The LOC lane's Tier-B basis — that the framework HAL binary
  `android.hardware.gnss@2.1-service-brcm` is absent — is **factually true but insufficient**: it
  establishes only that the *framework-facing HIDL/AIDL HAL service* is missing, not that the
  chip-facing daemon stack is dormant. A boot-started daemon plus the chip-facing
  `gps.default.so` library is reachable by the standard's own definition. The LOC lane's Tier B is
  preserved as a recorded **dissent**, but overruled. **Runtime proof remains HOLD** (no hardware);
  no device/boot result is claimed either way.
- **Consequence:** `location_gnss_userspace` = **C** on 2/13 (the backend ledger agrees; the LOC
  lane does not).

### D4 — BT F-002 scope (4 BT HALs in the shipped vendor VINTF manifest)

**Method.** `debugfs`-read `/vendor/etc/vintf/manifest.xml` from each of the 13 **shipped
`vendor.img`** stamps and counted the BT declarations.

**Result:** **13/13** devices declare `android.hardware.bluetooth` (`IBluetoothHci/default`),
`android.hardware.bluetooth.finder`, `android.hardware.bluetooth.ranging`, and
`vendor.google.bluetooth_ext`; the `bluetooth_audio.xml` fragment is present on **13/13**.
`tokay` is **not** an exception. Evidence:
`.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/D3-D4-BT-LOC.txt`.

- **Ruling:** true set = **13/13**. The BT lane's F-002 is correct; the **Architect's sample is
  wrong on `tokay`** (its shipped manifest is the shared `vendor_manifest_no_radio.xml`, which
  carries the same 4 BT entries; the "0 on tokay" observation does not reproduce).

---

## 4. CRITICAL CONTEXT — ruling on the four laguna `MODE=gtuserspace` hybrid stamps

Stamps `frankel-20260923-094457`, `blazer-20260923-090842`, `mustang-20260923-094541`,
`rango-20260802-130756` are laguna **hybrid bring-up** stamps (per each stamp's README): **factory
`BP4A.260205.001` boot chain + factory `vendor`/`vendor_dlkm`/`system_dlkm`** + GuardTalkOS
logicals.

### 4.1 Ruling — hybrids **DO** count as "the built image"

The claim under audit is about *"the built image on every Pixel model GuardTalk builds."* The
artifact a user actually obtains and would flash for these four devices is the **advertised
`*-latest` stamp** (`frankel-latest`, `blazer-latest`, `mustang-latest`, `rango-latest`), i.e.
the hybrid. The GuardTalkOS logical partitions in it are genuinely GuardTalk-built; only the
boot chain + dlkm are factory. Therefore the hybrid **is** the shipped/built image for the claim's
purposes.

**Consequences of this ruling (each stated, not papered over):**

- **(a) BT `nitrous` blocklisting cannot apply** on all four: the blocklist lives in
  `vendor_dlkm`, which is factory here → `nitrous.ko` is in `modules.load` and unblocked
  (**Tier C**). Confirmed on the shipped stamps (`BT-nitrous-gki.txt`).
- **(a′) The same engine hides other Tier-C residues:** factory `vendor_dlkm` also leaves
  `cpif`/`cpif_page`/`shm_ipc` loaded (D1) and `gnssif`/`gnss_spi` loaded unblocked (11/13 row).
- **(b) `vendor_dlkm` sha differs from the full-GuardTalk stamp:** the fullgt stamp
  `frankel-20260922-165726` **does** carry `blocklist nitrous` and the excised dlkm; `frankel-latest`
  points at the hybrid `frankel-20260923-094457` instead. So a compliant artifact exists but is
  **not advertised**.
- **(c) `rango-latest` is the MVP** (`rango-20260802-130756`) and is protected by the program's
  zero-regression rule; it may not be moved without explicit operator authorisation. It is also
  **not boot-verified** (`BOOT_VERIFIED=false`); the fullgt laguna boot chain is ABL-rejected
  (`AB 11311112`).

**Consequence for the headline verdict:** with the hybrids counted (as they must be), the 4 laguna
devices are **Tier C** on `nitrous_module`, `cellular_modem_kernel_transport`, and
`location_gnss_kernel` (plus the program-wide BT/NFC/UWB kernel cells). Even under the alternative
ruling — operator waives the 4 hybrids out of scope — the remaining 9 devices are still Tier C on
`bluetooth_gki_modules` (8 modules loaded), `nfc_kernel_module`, `uwb_kernel`, and (7 of them)
`location_gnss_kernel`, and `shiba`/`husky` remain Tier C on `location_gnss_userspace`. **Therefore
the claim is FALSE under either ruling; the hybrid question changes only *which devices* carry the
Tier-C cells, not the verdict.**

### 4.2 Operator decision required first

The single most important operator decision is **(c)/(b): does "the built image" for the 4 laguna
devices mean the advertised hybrid `-latest`, or the full-GUARDTALK laguna stamp?** Everything else
in the residual register is downstream of it. If the answer is "the fullgt stamp", then
`*-latest` must be repointed (and `rango-latest` re-authorised) so the advertised artifact carries
the excised `vendor_dlkm` blocklists; that single change closes D1/F-001/F-008 and the
`nitrous`/`gnss` kernel cells on those 4 devices.

---

## 5. Backend-ledger ↔ lane tier reconciliation (every differing cell)

Cells where the backend ledger's tier differs from a lane, from another artifact lane, or from this
adjudication. (The paired `Q-EXCISE-LEDGER` falsification signal independently reported three of
these; §13 cites it.)

| Cell | Backend ledger | Lane / independent evidence | **Umbrella ruling** | Basis |
|---|---|---|---|---|
| `cellular_modem_kernel_transport` (`cpif`/`shm_ipc`) — **row absent** | *(no row)* | RADIO F-001: **C, 9/13** | **C, 10/13** (add `rango`) | D1 primary re-derivation (CPIO + dlkm). |
| `nitrous_module` on `frankel`/`blazer`/`mustang`/`rango` | B (all 13) | BT F-001 + `Q-EXCISE-LEDGER`: **C on 4** | **C on 4**, B on the other 9 | D1-adjacent shipped `vendor_dlkm` re-read. |
| `location_gnss_userspace` on `shiba`/`husky` | C | LOC lane: **B** (HAL absent) | **C** (Architect upheld) | D3 `init.gps.rc` = `class main`, no `disabled`. |
| `location_gnss_kernel` | B (all 13) | LOC F-002: present+loaded 13/13; `Q-EXCISE-LEDGER`: A on 7 gemini, C on 4 laguna | **C on 11/13**, B on `shiba`/`husky` | Shipped `vendor_kernel_boot` ramdisk **and** `vendor_dlkm` both re-read. |
| `bluetooth_gki_modules` | C 13/13 | BT lane listed 7, called B; SURFACES F-005 called C | **C 13/13** (8 incl. `nfc.ko`) | Shipped `system_dlkm` `modules.load` re-read. |
| `nfc_userspace_hal` on `rango` | A | `Q-EXCISE-LEDGER`: should be B | **A** (dissent not reproduced) | Shipped `rango` `vendor.img` `/bin/hw`, `/lib64`, `/etc/init` → 0 NFC. |
| `telemetry_checkin` (`GuardTalkCheckin`) — **row absent** | *(no row)* | SURFACES F-002: **C\*, 10/13** | **C\* 10/13** (new row) | Lane + Architect `debugfs` corroboration. |
| `apex_dormant_set` / "APEX is gone" | B | SURFACES F-001: makefile claims Tier A | **B** (claim-integrity defect) | Artifacts present 13/13. |
| `uwb_kernel` | C 13/13 | *(no lane covered UWB kernel)* | **C 13/13** confirmed | 9 in `vendor_dlkm` + 4 in `vendor_kernel_boot` ramdisk. |
| `cellular_vendor_radioExternal_hal` | B on 6 | RADIO F-004: B on 6 | **B on 6** confirmed | Lane + ledger agree. |
| `baseband_firmware` | B 13 | RADIO F-002: B 13 | **B 13** confirmed | `radio.img` in 13/13 `SHA256SUMS`; flasher writes `radio`. |

**No other cell differs.** `variant_resolution` (B13), `cellular_framework_telephony` (B13),
`telephony_feature_declarations` (B12/A1), `nfc_kernel_module` (C13), `uwb_hal_service` (C7/A6),
`appsearch_apex` (C\*13), `telemetry_profiling` (B13), `connectivity_wifi_tethering` (C\*13),
`sensors_camera_mic_privacy` (C\*13) reconcile cleanly across ledger and lanes.

---

## 6. Residual register (severity + minimal remediation)

### CRITICAL (Tier C — reachable; falsifies "100% removed")

| ID | Residual | Devices | Minimal remediation |
|---|---|---|---|
| **C-R1** | Loaded kernel modem transport `cpif`/`cpif_page`/`shm_ipc` (in `modules.load`) | 10 (`shiba`,`husky`,`akita`,`comet`,`tegu`,`stallion` via vkb ramdisk; `frankel`,`blazer`,`mustang`,`rango` via dlkm) | Extend the working excision (already effective on `tokay`,`caiman`,`komodo`) to these 3 modules; re-prove in the **packed** ramdisk/dlkm. |
| **C-B1** | 8 BT/NFC GKI transport modules in `system_dlkm/modules.load`, 0 blocklisted | 13 | Add `bluetooth,hci_uart,btbcm,btqca,btsdio,rfcomm,hidp,nfc` to the shipped `system_dlkm` blocklist (or remove); prove in packed `system_dlkm.img`. |
| **C-B2** | `nitrous.ko` in `modules.load` and **not blocklisted** | 4 (`frankel`,`blazer`,`mustang`,`rango`) | Repoint/rebuild the 4 `-latest` to a dlkm carrying `blocklist nitrous` (fullgt stamp exists for `frankel`); resolve `mustang-latest` ownership; `rango-latest` only on operator authorisation. |
| **C-L1** | GNSS daemons `gpsd`/`lhd`/`scd` `class main` no `disabled` + `gps.default.so` + `/etc/gnss/*` | 2 (`shiba`,`husky`) | Extend `loc-excised.mk` to the `zuma_shusky` name set (`gpsd`,`lhd`,`scd`,`gps.default.so`,`init.gps.rc`,`/etc/gnss/*`); re-stamp. |
| **C-L2** | GNSS kernel modules in `modules.load`, unblocklisted | 11 | Add `gnssif`/`gnss_spi` to the per-variant blocklist (already blocklisted on `shiba`/`husky`). |
| **C-S1** | `GuardTalkCheckin` outbound telemetry client shipped (fail-closed, no baked C2) | 10 | Operator decision: excise/feature-gate, or record explicit Tier-C-by-design exception on the claim surface. |
| **C-S2** | WiFi / tethering / IPsec retained (Tier C by design) | 13 | Scope the claim to the intended excision set; state these as intentionally retained. |
| **C-S3** | UWB HAL service + init.rc init-started on 7; UWB kernel loaded 13 | 7 / 13 | Remove/blocklist; or waive. |

### HIGH

| ID | Residual | Devices | Minimal remediation |
|---|---|---|---|
| H-R1 | Baseband firmware `radio.img`/`modem.img` shipped and the flasher writes the `radio` partition | 13 | Waiver, **or** drop `radio.img` from `FW_IMAGES` and erase/leave-unflashed `radio` with a fail-closed check. |
| H-R2 | Runtime VINTF `dmd.xml` fragment re-declares telephony `oemservice` HAL | 13 | Drop the `dmd` fragment from packaged `vintf_fragments` / empty the file; re-prove from packed `vendor.img`. |
| H-R3 | `radioExternal` + `oemservice` HAL libs in packed `vendor.img` (orphaned, no transport) | 6 (`tegu`,`stallion`,`frankel`,`blazer`,`mustang`,`rango`) | Add to vendor package-excision filter. |
| H-B1 | 4 BT HALs declared in shipped vendor VINTF manifest (D4: 13/13) | 13 | Wire the existing `vendor_manifest_no_bt.xml` swap (or filter the BT `<hal>` blocks). |
| H-B2 | BT-audio HAL libs + `bluetooth_audio.xml` fragment | 13 | Remove via the module path that installs them; correct the `bt-excised.mk` text. |
| H-L1 | Framework GNSS surface (`/system/lib64` GNSS IF libs, `com.android.location.provider.xml`, altitude fragment) | 13 | Document as Tier-B framework retention or prove no consumer loads them. |
| H-X1 | **Hybrid `-latest` composition** (factory dlkm defeats BT/radio/GNSS excision) | 4 | Operator ruling (§4) + repoint `-latest` to excised dlkm. |
| H-X2 | Claims overstatement: `guardtalk-feature-excised.mk` asserts the BCP APEX "is gone" while `apex-bcp-excised.mk` documents the excision **disabled**; BT "no HCI transport"/"removed" wording | 13 | Correct the claim/manifest text; route to `A-EXCISE-HONESTY` / `F-EXCISE-CLAIM-HONESTY`. |

### MEDIUM

| ID | Residual | Devices | Minimal remediation |
|---|---|---|---|
| M-R1 | Telephony framework (`telephony-common.jar`, `ims-common.jar`, `telephonycore.apex`, `SatelliteClient.jar`) | 13 | Waiver; optionally drop SatelliteClient/ims-common. |
| M-R2 | `dmd` daemon + stale modem init block | 13 | Remove `dmd`/rc + modem init residue. |
| M-R3 | Build/stamp skew: `androidboot.radio.disabled` absent from the 4 laguna stamps (D2) | 4 | Re-stamp + stamp-time gate assertion. |
| M-R4 | eUICC telephony feature XMLs advertised | 12 (all but `tokay`) | Drop the feature XMLs, or document. |
| M-B1 | `channel_sounding` BT feature XML | 8 | Add to the BT drop list. |
| M-L1 | `FusedLocation` still shipped in stale stamps | 4 (`akita`,`tokay`,`komodo`,`rango`) | Re-stamp, or scope per stamp; correct `ATTACK_SURFACE_REPORT.md:407`. |
| M-S1 | Stale `se.omapi.ese/uicc` + `com.nxp.mifare` + `telephony.euicc` feature declarations | ~13 | Decide+document; drop if unintentional. |
| M-S2 | `com.android.devicelock.apex` present on legacy stamps | 3 (`akita`,`tokay`,`rango`) | Rebuild, or waive as legacy stamp. |
| M-S3 | Shipped stamps are `userdebug` / `ro.debuggable=1` | 13 | Confirm shipping variant; ship `user` if production airgap is asserted. |
| M-X1 | Author suites RED: `verify_port_kernel_matrix_static.sh` (5 FAIL) + `verify_port_matrix_preflight_static.sh` (4 FAIL) | — | `T-EXCISE-GATE-REVALIDATION`. |
| M-X2 | Ledger structural + tier defects (D1 row absent; `nitrous`, `location_gnss_kernel` tiers; `checkin` row absent) | — | Fix the ledger before it is quoted as the source of truth. |
| M-X3 | `REGEN_HOOKS.md` per-device coverage 4/13 | 9 | `T-EXCISE-REGEN-GUARD`. |

### LOW

| ID | Residual | Devices | Minimal remediation |
|---|---|---|---|
| L-1 | Resolver silent re-entry (different registered device) | latent | `$(error)` on candidate≠resolved; correct the false comment. |
| L-2 | Explicit `GUARDTALK_EXCISION_VARIANT` bypasses cross-family check | latent | Reject contradicting override. |
| L-3 | Sibling VINTF resolver silent tokay default | latent | Add `$(error)` else / allowlist. |
| L-4 | 4 device stamps lack a post-resolver built artifact in `out/` | 4 | Rebuild or record explicitly. |
| L-5 | Shared excision core untracked in git | — | Commit respecting the APPROVED gate. |
| L-6 | Stale RIL/IMS/IWLAN permission XMLs; SELinux radio/GNSS labels | 13 | Clean up in the same wave. |

---

## 7. Explicit WAIVER LIST (everything Tier B that must be waived for any airgap claim to stand)

No airgap claim may be made until the operator either **waives** each item below explicitly or
remediates it. Tier-B is **not** a removal.

1. **Baseband firmware** `radio.img` (13/13 stamps) + `modem.img` (13/13 `out/`) shipped and the
   `radio` partition flashed (`flash-from-remote.sh:153,937`) — 13 devices.
2. **Cellular framework telephony** (`telephony-common.jar`, `ims-common.jar`,
   `com.android.telephonycore.apex`, `SatelliteClient.jar`) — 13.
3. **`cellular_vendor_radioExternal_hal`** + `oemservice` libs — `tegu`,`stallion`,`frankel`,
   `blazer`,`mustang`,`rango` (6).
4. **`telephony_feature_declarations`** (eUICC `.xml`) — all but `tokay` (12).
5. **`bluetooth_userspace_hal`** (4 VINTF HAL declarations + 5 BT-audio libs +
   `bluetooth_audio.xml`) — 13.
6. **`nitrous_module`** present-but-blocklisted — the 9 non-laguna devices.
7. **`location_gnss_kernel`** present-but-blocklisted — `shiba`,`husky` (2).
8. **`apex_dormant_set`** (`com.android.bt`, `nfcservices`, `uwb`, `adservices`, `healthfitness`,
   `ondevicepersonalization`, `profiling`, `uprobestats`, `telephonycore`; `devicelock` on 3) — 13.
9. **`telemetry_profiling`** mainline stacks — 13.
10. **`variant_resolution`** resolver residual (7 Low silent paths, all unreachable in a
    single-product build) — 13.
11. **Runtime VINTF `dmd.xml` telephony fragment** — 13.
12. **`dmd` modem daemon + modem init residue** — 13.
13. **eUICC / `se.omapi.ese` / `se.omapi.uicc` / `com.nxp.mifare` feature declarations** — ~13.
14. **SELinux radio/GNSS service/file contexts** — 13.
15. **`FusedLocation`** in the 4 stale stamps — `akita`,`tokay`,`komodo`,`rango`.
16. **`com.android.devicelock.apex`** on legacy stamps — `akita`,`tokay`,`rango`.
17. **Legacy build vintage**: `akita` (2026-07-25), `tokay` (2026-07-25), `komodo` (2026-09-15),
    `rango` (2026-08-02) stamps predate later excision work — the 13-device set is **not** one
    coherent build generation.

**Tier-C-by-design register (intentional, operator-visible — must be *stated*, never called
"removed"):** `com.android.appsearch` (13); `GuardTalkCheckin` (10); WiFi/tethering/IPsec (13);
sensors/camera/mic (13); `userdebug`/`ro.debuggable=1` (13).

### 7.1 Can any Tier-B residual become Tier C? (reachability argument)

**Yes — several already have, and the mechanism is uniform.** A Tier-B "dormant" item becomes Tier C
the moment a *transport* exists or a *loader* picks it up:

- `nitrous_module` was recorded B (blocklisted) but is **already C** on the 4 hybrids where the
  blocklist does not reach the shipped dlkm (C-B2).
- `location_gnss_kernel` was recorded B but is **already C** on 11 devices where the modules are in
  `modules.load` unblocklisted (C-L2).
- `cellular_modem_kernel_transport` is **already C** on 10 devices (C-R1).
- `bluetooth_userspace_hal` (B today: declared, not served) becomes C the moment any BT HAL service
  binary or a `btsdio`/`hci_uart` userspace binder is re-introduced — the VINTF declaration is
  already in place on 13/13, so **the declaration is a latent transport**. This is the residual the
  operator most needs to rule on **second**.
- `baseband_firmware` (B) becomes C if the modem is left powered and a userspace path is restored;
  the flasher currently *does* write the `radio` partition, so the firmware is live on the silicon
  even though the host stack is absent.

**Which the operator most needs to rule on first:** the **hybrid `-latest` scope ruling (§4)** —
it decides whether the 4 laguna devices are counted, and it is the precondition for
C-B2/C-R1/C-L2 on those devices. Immediately after that, the **`GuardTalkCheckin` telemetry
exception (C-S1)** — it is the only Tier-C item that is an *outbound remote service* rather than a
dormant stack, and it directly falsifies the "telemetry" clause.

---

## 8. Falsification log (program-level)

Attacks attempted across the program that **succeeded** (broke the claim) and **failed** (claim
held). This umbrella adds four attacks of its own (D1–D4).

### 8.1 Attacks that SUCCEEDED (each cost the claim)

| # | Attack | Where | Cost to the claim |
|---|---|---|---|
| A-1 | Find the modem **kernel transport** in the packed image and its load list | D1 / RADIO F-001 | **Tier C on 10/13**; "modem removed" falsified. |
| A-2 | Find a **telephony HAL** merged at **runtime** via a VINTF fragment | RADIO F-003 | "radio-free manifest" falsified 13/13. |
| A-3 | Find vendor radio HAL **libs inside the packed** `vendor.img` | RADIO F-004 | blanket green falsified on 6. |
| A-4 | Find baseband firmware in the shipped bundle **and** the flasher writing `radio` | RADIO F-002 | Tier A for baseband falsified 13/13. |
| A-5 | Break the radio-disable gate on the **shipped** artifact (build/stamp skew) | RADIO F-005 / **D2** | gate absent on 4 laguna stamps (9/13 present). |
| A-6 | Find **BT/NFC GKI transport** modules loaded, unblocklisted | BT F-004 / SURFACES F-005 | **Tier C 13/13**; "no HCI transport" falsified. |
| A-7 | Make `nitrous` reachable via the shipped dlkm | BT F-001 / **D1-adjacent** | **Tier C on 4**. |
| A-8 | Find BT HAL declarations after "the drop is sufficient" | BT F-002 / **D4** | 4 BT HALs declared 13/13; `vendor_manifest_no_bt.xml` unwired. |
| A-9 | Find BT-audio HAL libs/fragment despite the drop list | BT F-003 | Tier B 13/13 + doc overstatement. |
| A-10 | Find the shiba/husky GNSS userspace stack behind boot `class main` services | LOC F-001 / **D3** | **Tier C on 2**; `loc-excised.mk` name-coverage gap. |
| A-11 | Find GNSS kernel drivers loaded | LOC F-002 / **umbrella** | **Tier C on 11**. |
| A-12 | Find an APEX the makefile says "is gone" | SURFACES F-001 | claim-integrity violation (Tier B). |
| A-13 | Find a shipped outbound telemetry client | SURFACES F-002 | "telemetry removed" falsified on 10. |
| A-14 | Find retained WiFi/tethering/IPsec | SURFACES F-007 | "every other connectivity removed" falsified 13/13. |
| A-15 | Find stale reachable feature declarations (SE/OMAPI/eUICC) | SURFACES F-006 | advertised-but-unbacked features. |
| A-16 | Re-run author suites | GATE-REVALIDATION / 13DEV F-009 | two APPROVED invariants now RED. |
| A-17 | Trust the `out/` tree instead of the shipped stamp (the "author claim" attack) | LOC F-003 / ledger | stale stamps retain `FusedLocation`; blocked modules load. |
| A-18 | Trust a shell `-n` test for a boot-config flag | Architect `E-12` retraction | "13/13" was a false positive. |

### 8.2 Attacks that FAILED (the excision genuinely holds)

| # | Attack | Result |
|---|---|---|
| B-1 | Find a RIL binary (`rild`/`libril*`/`libsitril*`/`google-ril.jar`) | 0/13 — Tier A. |
| B-2 | Find a served radio HAL service binary | 0/13. |
| B-3 | Find radio HALs in the **main** VINTF manifest | 0/13 (main file radio-free; only the fragment defeats it). |
| B-4 | Find a client/transport for `radioExternal` | none (orphan) → caps F-004 at B. |
| B-5 | Find a BT HAL **service** binary / `libbluetooth` daemon | 0/13. |
| B-6 | Find a BT `FEATURE_BLUETOOTH` master declaration | not found (dormancy gate holds). |
| B-7 | Find a GNSS HAL binary that implements the framework interface | 0/13 (`gnss@2.1-service-brcm` absent) — but daemons still run (D3). |
| B-8 | Find a Location feature XML / `NetworkLocation` | 0/13 — Tier A. |
| B-9 | Make the excision resolver silently no-op / mis-excise | 14 attacks upheld fail-loud; 3 pathological silent paths remain (Low, unreachable). |
| B-10 | Make a `blocklist nitrous` token-form fail (`.ko` vs bare) | not a defect (`CanonicalizeModulePath`). |

### 8.3 Umbrella-specific traps this adjudication had to disarm

- **Partition trap (D1):** a raw `grep` on `vendor_kernel_boot.img` cannot see modules that ship in
  `vendor_dlkm`, and cannot read the LZ4 CPIO ramdisk at all. The 6/13 figure was a partition
  error, not a removal.
- **Shell-test trap (D2):** `|| echo 0` made a `-n` test always pass → the original 13/13 was
  false; the replacement 8/13 dropped `tokay` (9/13 is correct).
- **HAL-absence fallacy (D3):** absence of the *framework* HAL binary does not make the
  *chip-facing* boot-started daemon stack dormant.
- **Sample error (D4):** a 3-device sample missed that `tokay`'s shipped manifest carries the same
  4 BT declarations as everyone else.

---

## 9. Gen 6 / Gen 7 — AUDITED ABSENCE (stated, not omitted)

No `device/google/gs101*` or `device/google/gs201*` directory exists, and there is no `gs101` /
`gs201` stamp under `releases/desktop-flash/`. Per `DEC-PORT-GEN8910-001` §7 these generations are
**out of program scope**; no GuardTalk build exists, so no claim is made or adjudicated for them.
They are an **absence**, not a silence. (Re-confirmed by the backend ledger and every lane.)

---

## 10. Severity counts (umbrella, reconciled)

| Severity | Count | IDs |
|---|---|---|
| **CRITICAL** | 8 | C-R1, C-B1, C-B2, C-L1, C-L2, C-S1, C-S2, C-S3 |
| **HIGH** | 8 | H-R1, H-R2, H-R3, H-B1, H-B2, H-L1, H-X1, H-X2 |
| **MEDIUM** | 12 | M-R1…M-X3 |
| **LOW** | 6 | L-1…L-6 |
| **INFO** | 2 | Gen 6/7 audited absence; `tokay` has no `tokay-latest` |
| **Total** | **36** | |

Note: the counts above are the umbrella register. The five lanes reported non-overlapping
per-lane counts (RADIO 2C/3H/5M/2L/1I; BT 1C/2H/2M/2L/1I; LOC 0C/2H/3M/3L/1I; SURFACES
2H/5M/3L; 13DEV 0C/0H/0M/7L/2I); this table is their deduplicated union plus the umbrella's own
reconciliations.

---

## 11. Honesty holds

- `LIVE_FLASH_CLAIMED = false`; `FLASH_READY = false`; `BOOT_VERIFIED = false`. No USB/adb/fastboot.
  **No device, boot, or runtime result is claimed for any device.** `rango-latest` was not moved
  (still `rango-20260802-130756`).
- `Gate -1`: in-process; `governance_loaded=true`. No aegis-verifier / `ask_guardian` /
  `gate_enforcer` / Guardian HTTP.
- `Gate 5: HUMAN SKIP` — no score invented.
- Read-only: no `.py/.ts/.tsx/.js/.jsx/.css/.mk/.sh` product/test/filter/flash/packer file, no
  `doctrine/`, `governance/{laws,gates}/`, `.env`, credentials, `.git`, `keys/` touched. Task
  statuses were not changed. No agent dispatched. `.agent-comm/inbox/TO_ARCHITECT.md` was **not**
  modified; `.agent-comm/TASK_QUEUE.md` was **not** hand-edited.
- Status reported to the Architect as **REVIEW**; **never `APPROVED`**.

---

## 12. Evidence index (raw, reproducible)

All under `.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/`:

| File | Contents |
|---|---|
| `vndrboot_unpack.py` | VNDRBOOT v3/v4 parser (ramdisk + bootconfig extractor). |
| `d1_check.sh` | D1: per-device `cpif`/`cpif_page`/`shm_ipc` in **unpacked** vkb ramdisk + `vendor_dlkm` + `out/`. |
| `D1-modem-transport.txt` | D1 raw matrix (the 10/13 result). |
| `d2_check.py` / `D2-radio-disabled-stamps.txt` | D2: header-cmdline vs bootconfig, per stamp (9/13). |
| `d34_check.sh` / `D3-D4-BT-LOC.txt` | D4 BT VINTF declarations (13/13) + D3 `init.gps.rc` + GNSS listings. |
| `bt_nitrous_gki_check.sh` / `BT-nitrous-gki.txt` | `nitrous` blocklist (9/13 vs 4/13), GKI BT/NFC (8 loaded/0 blocked 13/13), BT-audio libs (5 ×13). |
| `ledger_tier_matrix.tsv` | Backend ledger per-device × service tier extraction (reconciliation input). |

**Commands (reproduce):**
```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
python3 .agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/d2_check.py
bash    .agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/d1_check.sh
bash    .agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/d34_check.sh
bash    .agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/bt_nitrous_gki_check.sh
```

**Lane inputs adjudicated:** `vendor/guardtalk/docs/qa/{A-EXCISE-RADIO,A-EXCISE-BT,A-EXCISE-LOC,A-EXCISE-SURFACES,A-EXCISE-13DEV-NONREGRESSION}_AUDIT.md`,
`vendor/guardtalk/docs/EXCISION_LEDGER.md`, `vendor/guardtalk/docs/qa/excision_ledger.json`,
and the paired falsification signal `.agent-comm/signals/review-Q-EXCISE-LEDGER.json`.

---

## 13. Remediation triggers this adjudication supplies (§A5 — Architect decides)

- **`T-EXCISE-GKI-BT-MODULES`** — trigger **confirmed** (C-B1): 8 modules × 13.
- **`T-EXCISE-LAGUNA-BLOCKLIST-WIRING`** — trigger **confirmed** (C-B2): `nitrous` on 4.
- **`T-EXCISE-LOC-GPS-NAME-COVERAGE`** — trigger **confirmed** (C-L1): `shiba`/`husky`.
- **New candidates (not in §A5):**
  - `T-EXCISE-MODEM-KERNEL` — C-R1 (`cpif`/`cpif_page`/`shm_ipc`, 10/13).
  - `T-EXCISE-GNSS-KERNEL-WIRING` — C-L2 (`gnssif`/`gnss_spi`, 11/13).
  - `T-EXCISE-HYBRID-DLKM` — H-X1 (repoint/rebuild the 4 laguna `-latest`).
  - `T-EXCISE-CHECKIN-DECISION` — C-S1 (telemetry client; excise/gate or waive).
- **`A-EXCISE-HONESTY` / `F-EXCISE-CLAIM-HONESTY`** — trigger **confirmed** (H-X2).

---

*Auditor: AEGIS Independent Deep Tech Auditor (Panel 5) · task `A-EXCISE-AIRGAP-MATRIX` ·
read-only · **REVIEW** · `Gate 5: HUMAN SKIP` · `LIVE_FLASH_CLAIMED=false` · never APPROVED.*
