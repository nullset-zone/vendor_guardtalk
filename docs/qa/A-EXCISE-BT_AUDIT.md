# A-EXCISE-BT — Independent Bluetooth Residue Audit (Panel 5, Auditor)

| Field | Value |
|---|---|
| task_id | A-EXCISE-BT |
| role | auditor (independent deep-tech) |
| repository_id | grapheneos-worktree |
| owner_repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| audit_scope | full (lane: Bluetooth across 5 layers) |
| status | IN_PROGRESS → REVIEW (set by dispatch; this report does not change statuses) |
| opened / run | 2026-09-24T16:30+04:00 |
| governance | in-process Gate -1 (24 laws / 11 gates loaded from `.aegis/governance/`); `governance_loaded=true`; no Guardian HTTP / aegis-verifier call |
| Gate 5 | **HUMAN SKIP** (no Gate 5 numeric score invented) |
| read-only | No product/test/filter/flash/packer/doctrine/queue-authoritative file edited. No USB/adb/fastboot. No device claimed. |
| authority | Claim card `DEC-EXCISE-AIRGAP-001` §A1/§A3 (`TASK_QUEUE.md:6939`), pre-findings §A2 (E-3, E-4) |
| transport | `generalPurpose` per standing operator decision `fire_general` (Program §8) |

## 0. Claim under audit

> *Every GuardTalkOS feature that is supposed to make the OS effectively airgapped — … Bluetooth
> … is 100% removed from the built image on **every** Pixel model GuardTalk builds.*

Adjudication standard (`DEC-EXCISE-AIRGAP-001` §A1):

| Tier | Meaning | Acceptable for the "removed" claim? |
|---|---|---|
| **A — ABSENT** | Not present in the built artifacts at all | Yes |
| **B — DORMANT** | On disk, no transport/HAL/feature gate; not reachable at runtime | **No — needs explicit operator waiver; must NOT be reported as a removal** |
| **C — REACHABLE** | Present and can become active | **No — audit FAIL** |

## 1. VERDICT

> ## BT VERDICT: **FALSE**
>
> Bluetooth is **not** 100% removed from the built images. The `-latest` stamp is the audited
> artifact (per §A1). On **13/13** devices there are Tier-B residuals the excision documentation
> reports as removed (VINTF HAL declarations, BT-audio HAL libraries, a BT feature XML), and on
> **4/13** devices (laguna: `frankel`, `blazer`, `mustang`, `rango`) the `-latest` `vendor_dlkm`
> does **not** carry the `blocklist nitrous` gate, so `nitrous.ko` (the BCM4390 BT power/rfkill
> driver) is present in `modules.load` and **is loaded** → a **Tier-C kernel/Power residual**.
>
> **Conditional downgrade:** if the Architect (a) rules the laguna `gtuserspace` hybrid `-latest`
> stamps out of scope for the "GuardTalk build" definition **and** (b) grants an explicit operator
> waiver for the Tier-B residuals, the label degrades to **TRUE-WITH-DORMANT-RESIDUALS**. It can
> never be **TRUE** ("100% removed") on the evidence below.

Sub-verdicts by layer (13-device view):

| BT layer | State | Tier |
|---|---|---|
| (1) userspace BT HAL service binary / `libbluetooth` daemon | Absent on 13/13 | **A** |
| (1b) BT-audio HAL libraries + `bluetooth_audio.xml` VINTF fragment | Present on 13/13, declared | **B** |
| (2) mainline `com.android.bt.apex` | Present 13/13; permission XML grants no feature | **B** |
| (3) GKI BT modules in `system_dlkm` (7 modules, in `modules.load`) | Present + scheduled to load 13/13 | **B** |
| (4) `nitrous` blocklist efficacy | Blocklisted 9/13; **NOT blocklisted on 4/13 laguna `-latest`** | **B / C** |
| (5) BT vendor-config copies | Absent 13/13 (excised) | **A** |
| (5b) per-variant blocklist correctness | Source correct; for 4/13 laguna `-latest` the built dlkm is factory (≠ variant) | **C** |
| (x) `android.hardware.bluetooth_le.channel_sounding` feature XML | Present 8/13 | **B** |

## 2. Severity summary

| Severity | Count | IDs |
|---|---|---|
| CRITICAL | 1 | F-001 |
| HIGH | 2 | F-002, F-003 |
| MEDIUM | 2 | F-004, F-005 |
| LOW | 2 | F-006, F-007 |
| INFO | 1 | F-008 |

## 3. Per-device × per-layer Tier table (audited `-latest` stamp of each device)

Legend for each cell: `A` absent · `B` dormant · `C` reachable. "L1 service" = vendor BT HAL
service binary `android.hardware.bluetooth-service.bcmbtlinux`; "L1 libs" = `/vendor/lib64`
BT-audio HAL libs; "L2" = `com.android.bt.apex`; "L3" = GKI BT modules; "L4" = `nitrous`
blocklist; "L5" = BT config copies.

| Device | Stamp (audited) | L1 service | L1 libs+audio HAL | L2 APEX | L3 GKI mods | L4 nitrous | L5 copies | L5b variant | BT overall |
|---|---|---|---|---|---|---|---|---|---|
| shiba | shiba-20260923-094055 | A | B | B | B | B (blocked) | A | correct (zuma_shusky) | **B** |
| husky | husky-20260923-095309 | A | B | B | B | B (blocked) | A | correct (zuma_shusky) | **B** |
| akita | akita-20260725-101434 | A | B | B | B | B (blocked) | A | correct (zuma_akita) | **B** |
| tokay | tokay-20260725-102506 | A | B | B | B | B (blocked) | A | correct (zumapro_caimito) | **B** |
| caiman | caiman-20260922-090535 | A | B | B | B | B (blocked) | A | correct (zumapro_caimito) | **B** |
| komodo | komodo-20260915-063833 | A | B | B | B | B (blocked) | A | correct (zumapro_caimito) | **B** |
| comet | comet-20260922-160129 | A | B | B | B | B (blocked) | A | correct (zumapro_comet) | **B** |
| tegu | tegu-20260922-164700 | A | B | B | B | B (blocked) | A | correct (zumapro_tegu) | **B** |
| stallion | stallion-20260923-100618 | A | B | B | B | B (blocked) | A | correct (zumapro_stallion) | **B** |
| frankel | frankel-20260923-094457 | A | B | B | B | **C (NOT blocked)** | A | **C (factory dlkm)** | **C** |
| blazer | blazer-20260923-090842 | A | B | B | B | **C (NOT blocked)** | A | **C (factory dlkm)** | **C** |
| mustang | mustang-20260923-094541 | A | B | B | B | **C (NOT blocked)** | A | **C (factory dlkm)** | **C** |
| rango | rango-20260802-130756 | A | B | B | B | **C (NOT blocked)** | A | **C (factory dlkm)** | **C** |

`channel_sounding` feature XML (L-extra, Tier B) is present on **8/13**: caiman, komodo, comet,
stallion, frankel, blazer, mustang, rango. Absent on shiba, husky, akita, tokay, tegu.

## 4. Findings

### F-001 — [CRITICAL] `nitrous` blocklist absent from the 4 laguna `-latest` `vendor_dlkm` → Tier-C kernel/Power BT residual

- **Evidence**
  - Packed `releases/desktop-flash/frankel-latest/vendor_dlkm.img` → `modules.blocklist` has **no**
    `nitrous` line (ends `blocklist iommu_map_benchmark.ko`); `modules.load` contains `nitrous.ko`
    (line 98). Same for `blazer-latest` (line 98), `mustang-latest` (line 98), `rango-latest`
    (line 101). Evidence: `.agent-comm/evidence/A-EXCISE-BT/10-vendor_dlkm-scan.txt`,
    `11-laguna-blocklist.txt`, `29-frankel-vendor_dlkm.txt`.
  - `nitrous.ko` is present in the image (`Size: 52000`, laguna) and in `modules.load`.
  - The source-of-truth variant file **does** carry the entry:
    `vendor/guardtalk/feature-excised/variants/laguna_muzel/vendor_dlkm.modules.blocklist:37`
    `blocklist nitrous.ko`; `vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist:37`
    `blocklist nitrous.ko`.
  - The **staging** build is correct and differs from the stamp:
    `sha256(out/target/product/frankel/vendor_dlkm.img)` = `9a1543e6…` (has `blocklist nitrous.ko`)
    vs `sha256(releases/desktop-flash/frankel-latest/vendor_dlkm.img)` = `ce550998…` (factory, no
    entry). `sha256(releases/desktop-flash/frankel-20260922-165726/vendor_dlkm.img)` = `9a1543e6…`
    — i.e. the **full-GuardTalk** laguna stamp is `frankel-20260922-165726`, but `frankel-latest`
    points at `frankel-20260923-094457`, a `gtuserspace` **hybrid** whose README states
    `vendor / vendor_dlkm / system_dlkm = Factory BP4A.260205.001`
    (`releases/desktop-flash/frankel-latest/README-FLASH-DESKTOP.md`).
  - `init.common.cfg` (built `/vendor/etc/init.common.cfg`) loads the vendor set with the blocklist
    honoured: `modprobe|vendor -b *`; `insmod.sh` maps that to
    `modprobe -a -d <vendor_modules_dir> -b --all=modules.load`. `system/core/libmodprobe/
    libmodprobe.cpp:142-152` `IsBlocklisted()` skips blocklisted modules; `CanonicalizeModulePath`
    (`utils.cpp:28`) strips `.ko`, so `nitrous` and `nitrous.ko` are equivalent tokens.
  - `nitrous.ko` strings confirm role: *"Nitrous Oxide Driver for Bluetooth"*, `rfkill_*`,
    `nitrous_rfkill_set_power`, `uart_tx_locked/unlocked`, `bt_host_wake`, `bluetooth-tx/rx`
    (`.agent-comm/evidence/A-EXCISE-BT/19-nitrous-strings.txt`).
- **Impact:** On the 4 laguna **advertised** (`-latest`) builds the BT silicon power/rfkill gate is
  not closed: the driver is present, in `modules.load`, and not blocklisted → it loads. This is a
  **Tier-C** residual at the kernel/Power layer. (The userspace BT service + framework feature gate
  remain off, so app-level Bluetooth is still gated — see §1 conditional.) `bt-excised.mk:19-20`
  and the blocklist headers ("harmless without nitrous") are **not true on these four `-latest`
  stamps**.
- **Recommendation:** Do not advertise a BT-excised posture for the laguna `-latest` stamps until
  either (a) the `-latest` pointer is moved to a stamp whose `vendor_dlkm` carries
  `blocklist nitrous` (e.g. the fullgt stamp `frankel-20260922-165726`), or (b) the hybrid recipe
  is re-stamped with the GuardTalk `vendor_dlkm` blocklist. Withheld card `T-EXCISE-GKI-BT-MODULES`
  (`TASK_QUEUE.md:7214`) is **confirmed** by this finding.

### F-002 — [HIGH] BT HALs still declared in the built/packed vendor VINTF manifest on 13/13; the intended `vendor_manifest_no_bt.xml` is never wired

- **Evidence**
  - `out/target/product/<dev>/vendor/etc/vintf/manifest.xml` (assembled, provenance
    `vendor/guardtalk/vintf/vendor_manifest_no_radio[_<dev>|_laguna_muzel].xml`) declares, on
    **13/13**:
    `android.hardware.bluetooth`/`IBluetoothHci/default`,
    `android.hardware.bluetooth.finder`/`IBluetoothFinder/default`,
    `android.hardware.bluetooth.ranging`/`IBluetoothChannelSounding/default`,
    `vendor.google.bluetooth_ext` v4 (`IBTChannelAvoidance`, `IBluetoothCcc`, `IBluetoothCco`,
    `IBluetoothEwp`, `IBluetoothExt`, `IBluetoothFinder`, `IBluetoothSar`). Evidence:
    `05-vintf.txt`, `06-manifest-bt.txt`, `12-vendor-img-scan.txt`; reproduced from the **packed**
    `vendor.img` with `debugfs cat /etc/vintf/manifest.xml` (`07-packed-vendor.txt`).
  - `bt-excised.mk:128-135` (Layer 3) states: *"… so libvintf compatibility checks no longer expect
    a Bluetooth HAL to be running. No `adevtool_vintf_fragment_vendor_*bluetooth*` fragment exists
    … so no `DEVICE_MANIFEST_FILE` filter is required here."* — **contradicted by the built image.**
  - `vendor/guardtalk/vintf/vendor_manifest_no_bt.xml` exists (2410 B, explicitly derived by
    "removing the four Bluetooth HAL entries") and its header says it *"Replaces
    vendor_manifest_no_radio.xml on DEVICE_MANIFEST_FILE when GUARDTALK_FEATURE_EXCISED_WAVE2 is
    set (swapped by feature-excised/bt-excised.mk …)"* — but **`bt-excised.mk` contains no such
    swap** and no `.mk`/`.sh` in `vendor/guardtalk/` references the file (only a comment at
    `loc-excised.mk:258`). `GUARDTALK_FEATURE_EXCISED_WAVE2 := true` on all 13 devices.
  - `radio-excised/vintf-excised.mk:60-78` is the only `DEVICE_MANIFEST_FILE` swap and it installs
    the **`no_radio`** variants, which retain the BT entries.
- **Impact:** Tier-B residual on 13/13 (declarations, not a running service), plus a **documentation
  overstatement** in `bt-excised.mk`. A VINTF manifest that declares a vendor HAL that no service
  provides is an internal inconsistency independent of the BT claim.
- **Recommendation:** Wire the `vendor_manifest_no_bt.xml` swap in `bt-excised.mk` (or fold the BT
  removal into `vintf-excised.mk`), then re-verify with `check_vintf`. Correct `bt-excised.mk`
  Layer-3 text.

### F-003 — [HIGH] BT-audio HAL libraries + `bluetooth_audio.xml` VINTF fragment survive on 13/13 despite being in the excision drop list

- **Evidence** (packed `vendor.img` + `installed-files-vendor.txt`):
  - `/vendor/lib64/android.hardware.bluetooth.audio-impl.so` (371024 B, sha256
    `a6bae7a8…`), `android.hardware.bluetooth.audio-V5-ndk.so` (336704, `0f37e869…`),
    `android.hardware.bluetooth.audio@2.0.so` (268488, `0e73419f…`),
    `android.hardware.bluetooth.audio@2.1.so` (202560, `1ce4fb4c…`),
    `libbluetooth_audio_session_aidl.so` (1429616, `ea1cb662…`) — on **13/13**.
    Evidence: `04-vendor-bt-libs.txt`, `12-vendor-img-scan.txt`, `30-shas.txt`.
  - `/vendor/etc/vintf/manifest/bluetooth_audio.xml` present on **13/13**, declaring
    `android.hardware.bluetooth.audio` v5 `IBluetoothAudioProviderFactory/default`
    (source `hardware/interfaces/bluetooth/audio/aidl/default/bluetooth_audio.xml`).
    Evidence: `22-bt-audio-vintf.txt`, `26-bt-audio-vintf-13.txt`.
  - `bt-excised.mk:52-68` lists `android.hardware.bluetooth.audio-impl`,
    `android.hardware.bluetooth.audio@2.0.vendor`, `@2.1.vendor`, `-V5-ndk.vendor`, and
    `libbluetooth_audio_session_aidl` for removal from `PRODUCT_PACKAGES`. The built modules map
    shows these are still installed (`23-module-map.txt`; e.g. module
    `android.hardware.bluetooth.audio-impl` → `vendor/lib64/android.hardware.bluetooth.audio-impl.so`
    **and** `vendor/etc/vintf/manifest/bluetooth_audio.xml`). No BT-audio **service binary** is
    present (`/vendor/bin/hw` clean; `28-bt-service-13.txt`), so the HAL is not running.
- **Impact:** Tier-B residual on 13/13. The excision reports these packages as dropped, so this is a
  second **documentation overstatement** and an ineffective `PRODUCT_PACKAGES` filter for modules
  that are installed transitively (shared-lib/VINTF-fragment install), not via the filtered
  `PRODUCT_PACKAGES` name alone.
- **Recommendation:** Remove via the mechanism that actually installs them (module dependency
  exclusion / `PRODUCT_PACKAGES` of the audio VINTF fragment), or explicitly classify them as a
  waived Tier-B residual in the ledger. Correct `bt-excised.mk` Layer-1 text.

### F-004 — [MEDIUM] E-4 undercounts the GKI BT module set: 7 BT modules present AND in `system_dlkm/modules.load` on 13/13

- **Evidence:** packed `system_dlkm.img` `/lib/modules` + `modules.load` on 13/13 contains:
  `bluetooth.ko`, `hci_uart.ko`, `btbcm.ko`, `btqca.ko`, `btsdio.ko`, `hidp.ko`, `rfcomm.ko`
  (plus generic `rfkill.ko`). `system_dlkm/lib/modules/modules.blocklist` is empty.
  Evidence: `02-system_dlkm.txt`, `09-system_dlkm-packed.txt`, `10-vendor_dlkm-scan.txt`,
  `15-system_dlkm-blocklist.txt`. E-4 named only 3 (`bluetooth.ko`, `hci_uart.ko`, `btbcm.ko`).
- **Impact:** Tier-B residual broader than reported. Notably `btsdio.ko` (**SDIO transport**) and
  `btqca.ko` (Qualcomm UART) mean the excision's blanket *"no HCI transport"* wording is imprecise:
  the GKI transports are present and loaded; only the chip power/rfkill gate is held (by `nitrous`
  on 9/13). Tier depends entirely on `nitrous` (F-001).
- **Recommendation:** Update E-4/ledger to the 7-module set; correct the `bt-excised.mk` and
  blocklist-header "no HCI transport" wording to "transports present but chip unpowered".

### F-005 — [MEDIUM] `android.hardware.bluetooth_le.channel_sounding` BT feature XML shipped on 8/13

- **Evidence:** `/vendor/etc/permissions/android.hardware.bluetooth_le.channel_sounding.xml`
  (843 B, sha256 `1169ca58…`) present on caiman, komodo, comet, stallion, frankel, blazer, mustang,
  rango; absent on shiba, husky, akita, tokay, tegu. It declares
  `<feature name="android.hardware.bluetooth_le.channel_sounding" />`
  (source `frameworks/native/data/etc/android.hardware.bluetooth_le.channel_sounding.xml`).
  `bt-excised.mk:62-63` drops only `android.hardware.bluetooth.prebuilt.xml` and
  `android.hardware.bluetooth_le.prebuilt.xml`; the `channel_sounding` module is not covered.
  Evidence: `05-vintf.txt`, `12-vendor-img-scan.txt`, `13-system-apex.txt`, `30-shas.txt`.
- **Impact:** Tier-B residual (a Bluetooth sub-feature is advertised). It does **not** declare the
  master `android.hardware.bluetooth`/`_le` features, and the master feature gate is confirmed
  absent (see §5), so it does not by itself un-gate the BT stack.
- **Recommendation:** Add the `channel_sounding` prebuilt to `GUARDTALK_BT_PACKAGES`.

### F-006 — [LOW] E-3 re-proven: `com.android.bt.apex` present on 13/13, dormant (no feature declaration inside)

- **Evidence:** packed `/system/apex/com.android.bt.apex` present on 13/13
  (15,360,000–15,364,096 B; e.g. caiman 15,364,096, `13-system-apex.txt`, `27-apex-13.txt`).
  Extracted staging `apex/com.android.bt/etc/permissions/com.android.bluetooth.xml` is identical on
  13/13 (sha256 `56639441…`) and contains a `privapp-permissions` block only, **zero** `<feature>`
  lines — so the APEX grants `com.android.bluetooth` privileges but does **not** publish
  `FEATURE_BLUETOOTH`. The APEX app `Bluetooth.apk` is present inside the apex (module
  `Bluetooth.com.android.bt`) but gated. **Agrees with E-3's Tier-B call.**
- **Impact:** Tier B, correctly classified. No residual action beyond a ledger cell.

### F-007 — [LOW] The `nitrous`-absent "harmless" rationale is unproven for the SDIO transport

- **Evidence:** `btsdio.ko` (SDIO BT transport) is present and in `system_dlkm/modules.load` on
  13/13 (F-004). `bt-excised.mk:19-20` and `vendor_dlkm.modules.blocklist:39-40` assert the GKI
  modules are "*harmless without nitrous (no rfkill power-on, no HCI transport)*". `nitrous.ko`
  provides `rfkill_*`/`nitrous_rfkill_set_power` and UART TX gating
  (`19-nitrous-strings.txt`). No datasheet/schematic or on-device probe is available to prove the
  BCM4390 BT function cannot bind over SDIO independently of `nitrous` (device probe is HOLD).
- **Impact:** The "harmless" claim is *plausible for the UART path* (nitrous is the power gate) but
  is an unproven assumption for a second transport. Recorded as a residual uncertainty, not a
  proven Tier C — except where nitrous itself is not blocked (F-001).
- **Recommendation:** State it as an assumption to be closed by an on-device probe when hardware is
  authorised (DEC-009 HOLD).

### F-008 — [INFO] Provenance divergence on laguna `-latest` (hybrid vs fullgt)

- **Evidence:** `frankel-latest`, `blazer-latest`, `mustang-latest`, `rango-latest` point at
  `gtuserspace` **hybrid** stamps whose README documents factory `vendor/vendor_dlkm/system_dlkm`
  (BP4A.260205.001) with GuardTalk logicals. The full-GuardTalk laguna stamps (e.g.
  `frankel-20260922-165726`) **do** carry `blocklist nitrous.ko`. `mustang-latest` even points at an
  *earlier* build (`mustang-20260923-094541`) than the newer `mustang-20260923-101119` which has
  the nitrous entry. Evidence: `11-laguna-blocklist.txt`, `17-frankel-stamp.txt`, `29-…`, `30-shas.txt`.
- **Impact:** The "advertised" artifact for 4 devices is not the fully excised artifact. This is the
  root cause of F-001's Tier C; it is a stamping/pointer defect, not a `.mk` defect.
- **Recommendation:** Reconcile `*-latest` with the intended excision composition before any
  advertise/flash claim (this is the honesty surface `F-EXCISE-CLAIM-HONESTY` guards).

## 5. Re-proof of the dispatch pre-findings (agreement / disagreement)

| Ref | Architect pre-finding | Auditor result | Agreement |
|---|---|---|---|
| E-3 | built `system/apex/com.android.bt.apex` present on all 13, with `apex/com.android.bt/etc/permissions/com.android.bluetooth.xml`; Tier B | Confirmed on 13/13 (packed `system.img`); permission XML grants no feature. Tier B. | **AGREE** |
| E-4 | `bluetooth.ko`, `hci_uart.ko`, `btbcm.ko` remain in built `system_dlkm` on 13/13; only `nitrous` BT-blocklisted | The 3 are present 13/13 — **plus** `btqca.ko`, `btsdio.ko`, `hidp.ko`, `rfcomm.ko` (7 BT modules, all in `modules.load`). | **PARTIAL DISAGREE (undercount)** |
| — | `nitrous` blocklisted (`feature-excised/vendor_dlkm.modules.blocklist:62`) and reaches built `vendor_dlkm` per device | Reaches the built `vendor_dlkm` on **9/13**; **not** on the 4 laguna `-latest` stamps. | **PARTIAL DISAGREE** |
| — | per-variant blocklist is the correct one (8 variants; `akita`,`komodo`,`rango` device-local) | Source registry + 3 device pins resolve correctly (`bcmdhd4398`/`bcmdhd4383`/`bcmdhd4390` per family verified); `laguna_*` built `-latest` dlkm is factory, not the variant file. | **PARTIAL DISAGREE** |
| E-5 | BT/NFC/Location feature XMLs absent in built `etc/permissions` on sampled devices | `android.hardware.bluetooth(.le).prebuilt.xml` absent (`/system/etc/permissions` 0 BT files) — **but** `android.hardware.bluetooth_le.channel_sounding.xml` present in `/vendor/etc/permissions` on 8/13 (F-005). | **PARTIAL DISAGREE** |
| `bt-excised.mk:19-20` | GKI BT modules "harmless without nitrous (no rfkill power-on, no HCI transport)" | True by dependency on `nitrous` for UART power; "no HCI transport" wording false (7 transports/profiles loaded, incl. `btsdio` SDIO); unproven for SDIO. | **PARTIAL DISAGREE** |
| `bt-excised.mk:128-135` | "no `DEVICE_MANIFEST_FILE` filter is required" | False — the packed vendor manifest still declares 4 BT HALs; `vendor_manifest_no_bt.xml` exists but is unwired. | **DISAGREE** |
| `bt-excised.mk:50-68` | BT-audio HAL packages dropped | 5 libs + `bluetooth_audio.xml` present on 13/13. | **DISAGREE** |
| E-8 | Gen 6/7 audited absence | No `device/google/gs101*` / `gs201*`; no Gen6/7 stamps in `releases/desktop-flash/`. | **AGREE** |

## 6. Author-side suite re-runs (re-run, not trusted)

| Suite | Exit | PASS/FAIL/HOLD | BT relevance |
|---|---|---|---|
| `verify_port_excision_matrix_static.sh` | 0 | 128/0/0 | **Blind spot:** asserts only the incumbent 4 devices (akita/tokay/komodo/rango) + source blocklists; no assertion over the 4 laguna `-latest` **built** dlkm and no `nitrous`-in-built check. It passes while F-001 is true. |
| `verify_remediate_b2_excise_host.sh` | 0 | 86/0/7 | Holds `HOLD: BT start is FEATURE_BLUETOOTH-gated` — consistent with Tier B for the framework/app layer. |
| `verify_remediate_b2_kernel_static.sh` | 0 | 30/0/6 | Not BT-specific (yama/hardening). |
| `verify_remediate_b2_apex_host.sh` | **1** | 45/5/7 | FAILs are **DeviceLock/BCP** related (unrelated to BT); recorded for completeness. |
| `verify-on-device.sh` | **NOT RUN** | — | USB/adb/fastboot is forbidden; on-device probe is DEC-009 HOLD. |

Full outputs: `.agent-comm/evidence/A-EXCISE-BT/16-author-suites.txt`.

Cross-lane note: `vendor/guardtalk/docs/qa/A-EXCISE-SURFACES_AUDIT.md` (parallel lane) states
nitrous "is blocklisted in `vendor_dlkm`, as claimed" — that observation is true for the **out/
staging** and the 9 non-laguna devices, but does **not** hold for the 4 laguna `-latest` **packed**
stamps. Flagged for Architect reconciliation (see F-001/F-008).

## 7. Falsification log (attacks attempted)

| # | Attack | Method | Outcome |
|---|---|---|---|
| 1 | Find a BT HAL **service** binary in built/packed images | `debugfs ls /bin /bin/hw` on packed `vendor.img` (13) | 0 hits — excision effective (Tier A). |
| 2 | Find BT-audio HAL **libs** despite the drop list | `debugfs ls /lib64` (13) + `installed-files-vendor.txt` | 5 libs present 13/13 → **falsified the "removed" claim** (F-003). |
| 3 | Find a BT `FEATURE_BLUETOOTH` declaration | `ls`/`cat` of every partition `etc/permissions` (packed) + APEX permission XML + GuardTalk `handheld_core_hardware.prebuilt.xml` (sha-matched to shipped) | No master BT feature found → dormancy gate holds; but `channel_sounding` sub-feature found 8/13 (F-005). |
| 4 | Find BT VINTF declarations after the "PRODUCT_PACKAGES drop is sufficient" claim | `debugfs cat /etc/vintf/manifest.xml` + `ls /etc/vintf/manifest` (packed) | 4 BT HALs + `bluetooth_audio.xml` on 13/13 → **falsified Layer-3 claim** (F-002/F-003). |
| 5 | Make `nitrous` reachable / find a device where the blocklist fails | compare source variant file vs packed `modules.blocklist` for all 13 `-latest` stamps | 4 laguna stamps lack the entry while `modules.load` includes `nitrous.ko` → **Tier C** (F-001). |
| 6 | Second transport without nitrous | enumerate `system_dlkm/modules.load`; `strings nitrous.ko` | `hci_uart`, `btbcm`, `btqca`, `btsdio` (SDIO), `rfcomm`, `hidp`, `bluetooth` all loaded; chip power gate is `nitrous` (`rfkill`/power) → plausibly harmless on UART, unproven for SDIO (F-004/F-007). |
| 7 | BT vendor-config copies survive | `ls /etc`, `/etc/bluetooth`, `/etc/permissions` on packed `vendor.img` (13) | No `bluetooth_power_limits*`, no `bluetooth/*.conf|json`, no `aoc/*bluetooth*.pb`, no BT `.rc` → excision effective (Tier A). |
| 8 | Device→variant mis-resolution (wrong Wi-Fi/touch blocklist) | verify built blocklist bcmdhd token per device vs registry | shiba/husky=4398, akita=4383, tokay/caiman/komodo=4390, comet=4390, tegu=4383, stallion=4383, laguna=4383+4390 — all match registry; **no mis-variant** (the laguna defect is composition, not resolution). |
| 9 | `blocklist nitrous` token form (`.ko` vs bare) defeats matching | read `system/core/libmodprobe/utils.cpp` `CanonicalizeModulePath` | `.ko` stripped + `-`→`_`; `nitrous` ≡ `nitrous.ko` → token form is **not** a defect. |
| 10 | Stale/other stamp has the gate (so maybe fine) | sha-compare `frankel-latest` vs `out/` vs `frankel-20260922-165726` `vendor_dlkm.img` | `-latest` (ce550998…) ≠ out/fullgt (9a1543e6…) → confirms the defect is in the advertised stamp (F-008). |

## 8. Residual register / operator-waiver surface (BT)

| Residual | Devices | Tier | Minimal remediation (withheld cards per §A5) |
|---|---|---|---|
| `nitrous` not blocklisted in `-latest` dlkm | frankel, blazer, mustang, rango | **C** | re-stamp / repoint `-latest` to a dlkm carrying `blocklist nitrous` (`T-EXCISE-GKI-BT-MODULES`) |
| BT HALs in vendor VINTF manifest | 13/13 | B | wire `vendor_manifest_no_bt.xml` swap |
| BT-audio HAL libs + `bluetooth_audio.xml` | 13/13 | B | fix the module install path; re-verify |
| GKI BT modules in `system_dlkm` | 13/13 | B | remove or document as waived |
| `com.android.bt.apex` | 13/13 | B | remove or document as waived (`T-EXCISE-APEX-DORMANCY`) |
| `channel_sounding` feature XML | 8/13 | B | add to drop list |
| `nitrous.ko` on disk (blocked) | 9/13 | B | remove or documented waiver |

Each item requires an **explicit operator waiver** before any "removed" wording may be used
(`DEC-EXCISE-AIRGAP-001` §A1/§A5).

## 9. Gen 6 / Gen 7 — audited absence (stated, not omitted)

No `device/google/gs101*` or `device/google/gs201*` directory exists; no `gs101`/`gs201` stamps in
`releases/desktop-flash/`. Gen 6 (`gs101`) and Gen 7 (`gs201`) are recorded as **AUDITED ABSENCE**
(§7 of `DEC-PORT-GEN8910-001`) — no GuardTalk build exists, so no BT claim is made or adjudicated.

## 10. Limitations / HOLDs

- **No on-device verification.** No Pixel hardware, no USB/adb/fastboot (DEC-009 HOLD). Every cell
  is a **static** adjudication of built artifacts. No device result is claimed.
- **Tier-C at the kernel layer vs app-level reachability.** F-001 is Tier C because the BT
  power/rfkill driver is present, in `modules.load`, and **loads** on the 4 laguna `-latest` stamps
  (kernel/Power layer active). The userspace BT HAL service is absent and `FEATURE_BLUETOOTH` is not
  declared, so app-level Bluetooth remains gated. This split is stated explicitly in §1/§3 for the
  Architect's final ruling.
- **`Gate 5: HUMAN SKIP`** — no numeric Gate 5 score invented.
- This auditor did **not** edit `.agent-comm/inbox/TO_ARCHITECT.md` (parallel auditors) and did
  **not** change any task status.

## 11. Evidence index (raw, reproducible)

All under `.agent-comm/evidence/A-EXCISE-BT/`:

`01-apex.txt`, `02-system_dlkm.txt`, `03-apex-content.txt`, `04-vendor-bt-libs.txt`,
`05-vintf.txt`, `06-manifest-bt.txt`, `07-packed-vendor.txt`, `08-insmod.txt`,
`09-system_dlkm-packed.txt`, `10-vendor_dlkm-scan.txt`, `11-laguna-blocklist.txt`,
`12-vendor-img-scan.txt`, `13-system-apex.txt`, `14-feature-xmls.txt`,
`15-system_dlkm-blocklist.txt`, `16-author-suites.txt`, `17-frankel-stamp.txt`,
`18-system-libs.txt`, `19-nitrous-strings.txt`, `20-vendor-bins.txt`, `21-installed-vendor.txt`,
`22-bt-audio-vintf.txt`, `23-module-map.txt`, `24-system-apps.txt`, `25-system-apps2.txt`,
`26-bt-audio-vintf-13.txt`, `27-apex-13.txt`, `28-bt-service-13.txt`, `29-frankel-vendor_dlkm.txt`,
`30-shas.txt`, `raw/nitrous.caiman.ko`, `raw/handheld.packed.xml`.

Primary tools: `debugfs`, `sha256sum`, `unzip -l`, `strings`, `sed`/`grep` over packed
`releases/desktop-flash/<dev>-*/*.img` and resolved `out/target/product/<dev>/` staging.

*Auditor, Panel 5 — A-EXCISE-BT. Independently derived; supersedes no other lane. Gate 5: HUMAN SKIP.*
