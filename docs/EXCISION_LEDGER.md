# EXCISION LEDGER — per-device service excision (built artifacts only)

| Field | Value |
|---|---|
| task_id | `T-EXCISE-LEDGER` |
| role | Backend Engineer (Panel 2) · `aegis-backend-engineer` |
| program | `DEC-EXCISE-AIRGAP-001` — Extreme independent audit of the OS-level airgap claim |
| authority | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` § `EXTREME AUDIT — AIRGAP CLAIM` |
| repository_id | `grapheneos-worktree` |
| status | `REVIEW` (this card never sets `APPROVED`) |
| generated | 2026-09-24T16:30:00+04:00 |
| machine-readable companion | `vendor/guardtalk/docs/qa/excision_ledger.json` |

**Scope.** The machine-readable **per-device excision ledger (13 × service set)** for the 13
Gen 8/9/10 program devices, derived from **built artifacts only**:
`releases/desktop-flash/<dev>-*`, `out/target/product/<dev>/`, and the built variant /
blocklist files that actually ship in the image. No cell cites a build recipe file as
evidence; every cell cites a built output, a release stamp, or a built config/installed-files
manifest.

**Tier standard (adjudication is owned by the five `A-EXCISE-*` auditor lanes, not by this card):**

| Tier | Meaning | Acceptable for an "airgapped" claim? |
|---|---|---|
| **A — ABSENT** | Not present in the built artifacts at all | Yes |
| **B — DORMANT** | On disk but no transport/HAL/feature gate; not reachable at runtime | **Requires explicit operator waiver** |
| **C — REACHABLE** | Present and can become active | **No — audit FAIL** |

**Evidence kinds used in the JSON** (never a build-recipe kind): `built-output`, `stamp`,
`vintf-manifest`, `installed-files`, `kernel-module`, `build-prop`.

## 0. Honesty holds

- `LIVE_FLASH_CLAIMED = false` — no device was flashed or booted; no `adb`/`fastboot` was run.
- No boot-green result is claimed for any device (`rango` included).
- `Gate 5: HUMAN SKIP` — no critique score is invented.
- Zero assertions are copied from author-side suites; every claim below is re-derived from the
  artifact path shown in the JSON.
- `rango-latest` was **not** moved: it still resolves to `rango-20260802-130756`.
- No product/filter/flash/packer/doctrine/governance file was edited; nothing was rebuilt or
  re-stamped.

## 1. Gen 6 / Gen 7 — audited absence (recorded, not omitted)

`gen6_gen7_audited_absence.status = AUDITED_ABSENCE`.

No GuardTalk build exists for **Gen 6 (`gs101`)** or **Gen 7 (`gs201`)**:

- `device/google/gs101*` → 0 hits
- `device/google/gs201*` → 0 hits
- `releases/desktop-flash/*gs101*` → 0 hits
- `releases/desktop-flash/*gs201*` → 0 hits

These generations are out of program scope per `DEC-PORT-GEN8910-001` §7. They are an
**absence**, not a silent omission — they cannot be in a 13-device ledger that only audits
built Gen 8/9/10 images.

## 2. Device roster and baseband firmware

`modem.img` exists only in `out/target/product/<dev>/`; the release stamps carry `radio.img`
only (confirms Architect `E-7b`). All sizes are bytes (`ls -l` level; large `.img` is sized,
not hashed).

| codename | variant (built-artifact proof) | stamp | `radio.img` (out) | `modem.img` (out) | `radio.img` (stamp) |
|---|---|---|---:|---:|---:|
| shiba | `zuma_shusky` | shiba-20260923-094055 | 112,967,820 | 112,967,680 | 112,967,820 |
| husky | `zuma_shusky` | husky-20260923-095309 | 112,967,820 | 112,967,680 | 112,967,820 |
| akita | `zuma_akita` | akita-20260725-101434 | 115,355,788 | 115,355,648 | 115,355,788 |
| tokay | `zumapro_caimito` | tokay-20260725-102506 † | 136,634,508 | 136,634,368 | 136,634,508 |
| caiman | `zumapro_caimito` | caiman-20260922-090535 | 136,634,508 | 136,634,368 | 136,634,508 |
| komodo | `zumapro_caimito` | komodo-20260915-063833 | 136,634,508 | 136,634,368 | 136,634,508 |
| comet | `zumapro_comet` | comet-20260922-160129 | 136,634,508 | 136,634,368 | 136,634,508 |
| tegu | `zumapro_tegu` | tegu-20260922-164700 | 98,766,988 | 98,766,848 | 98,766,988 |
| stallion | `zumapro_stallion` | stallion-20260923-100618 | 191,426,700 | 191,426,560 | 191,426,700 |
| frankel | `laguna_muzel` | frankel-20260923-094457 | 191,426,700 | 191,426,560 | 191,426,700 |
| blazer | `laguna_muzel` | blazer-20260923-090842 | 191,426,700 | 191,426,560 | 191,426,700 |
| mustang | `laguna_muzel` | mustang-20260923-094541 | 191,426,700 | 191,426,560 | 191,426,700 |
| rango | `laguna_rango` | rango-20260802-130756 | 191,426,700 | 191,426,560 | 191,426,700 |

† **tokay has no `tokay-latest` pointer.** The only latest pointer for tokay is the global
`releases/desktop-flash/latest -> tokay-20260725-102506`. The card's premise that all 13
devices carry a per-device `*-latest` stamp is **false for tokay**; it is recorded as
`stamp_note` in the JSON.

**Variant proof.** Each device's `variant` is proven from a built artifact:

- the built `out/target/product/<dev>/vendor_dlkm/lib/modules/modules.blocklist` header
  (e.g. shiba: `canonical blocklist for excision variant 'zuma_shusky'`), and
- the built `out/target/product/<dev>/vendor/etc/vintf/manifest.xml` provenance header
  (e.g. `vendor/guardtalk/vintf/vendor_manifest_no_radio_<variant>.xml`).

Where the built blocklist header names a device/kernel family instead of the variant token
(`akita`, `tokay`, `caiman`, `komodo`, `rango`) the JSON carries the exact header line and the
resolved variant, plus the VINTF provenance header as a second built artifact. The registry
file is **not** used as the proof.

## 3. Service tier matrix (13 devices × 20 services)

Each cell is the worst (highest) tier observed for that device/service; the exact artifact rows
are in the JSON. `B` on some rows is a per-device split (noted in §4).

| service | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `baseband_firmware` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `cellular_ril_native` | A | A | A | A | A | A | A | A | A | A | A | A | A |
| `cellular_vendor_radioExternal_hal` | A | A | A | A | A | A | A | B | B | B | B | B | B |
| `cellular_framework_telephony` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `telephony_feature_declarations` | B | B | B | **A** | B | B | B | B | B | B | B | B | B |
| `bluetooth_userspace_hal` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `bluetooth_gki_modules` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `nitrous_module` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `location_gnss` | C | C | A | A | A | A | A | A | A | A | A | A | A |
| `location_gnss_kernel` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `nfc_userspace_hal` | A | A | A | A | A | A | A | A | A | A | A | A | A |
| `nfc_kernel_module` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `uwb_hal_service` | A | C | A | A | C | C | C | A | A | A | C | C | C |
| `uwb_kernel` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `apex_dormant_set` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `appsearch_apex` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `telemetry_profiling` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| `connectivity_wifi_tethering` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `sensors_camera_mic_privacy` | C | C | C | C | C | C | C | C | C | C | C | C | C |
| `variant_resolution` | B | B | B | B | B | B | B | B | B | B | B | B | B |

## 4. Service findings (with primary artifacts)

### 4.1 Baseband firmware — Tier B, 13/13
`out/target/product/<dev>/radio.img` + `modem.img` are present on all 13 devices, and every
release stamp carries `radio.img`. The baseband firmware is on disk and staged for flashing;
there is no artifact-level evidence it is inert. Confirms `E-1`. **Operator waiver required.**

### 4.2 Cellular native RIL / radio HAL — Tier A, 13/13
`installed-files-vendor.txt` contains **0** `rild` / `/hw/rild` / `android.hardware.radio`
entries on all 13 devices, and the built vendor `manifest.xml` provenance is the radio-free
manifest (`vendor_manifest_no_radio*`). Confirms the host-transport half of `E-6`.

### 4.3 Cellular vendor `radioExternal` HAL — B on 6, A on 7
`vendor/lib64/vendor.samsung_slsi.telephony.hardware.radioExternal-V1-ndk.so` is present in
the built vendor image on exactly **tegu, stallion, frankel, blazer, mustang, rango** (Tier B)
and absent on the other 7 (Tier A). Confirms `E-2` asymmetry. Because the device-side VINTF
manifest is radio-free, the library has no declared transport → Tier B, but it is a
**per-device residual** the auditors must adjudicate B vs C. SHA-256 for the tegu instance:
`6bf189a2ccbbf62bb52fee61c58a747f051ccf1802dd31870dd5cbf6c1abecc2`.

### 4.4 Cellular framework telephony — Tier B, 13/13 (correction to `E-6`)
`/system/framework/telephony-common.jar` **is present in the built system image on all 13
devices**. The `E-6` statement "0 rild/telephony in `system/`" is true for the native RIL
binaries but **not** for the framework telephony classes. Without a radio transport they are
dormant, but the excision is not total. Tier B.

### 4.5 Telephony feature declarations — B on 12, A on 1
`product/etc/permissions/android.hardware.telephony.euicc.xml` ships on 12/13 devices
(**tokay is the exception** — 0 eUICC entries in its built product installed-files manifest).
Tier B where present, Tier A on tokay.

### 4.6 Bluetooth userspace HAL — Tier B, 13/13 (adjudication required)
Every built vendor `manifest.xml` **declares** `android.hardware.bluetooth`,
`android.hardware.bluetooth.finder`, `android.hardware.bluetooth.ranging` and
`vendor.google.bluetooth_ext`. The Bluetooth-audio HAL implementation
`vendor/lib64/android.hardware.bluetooth.audio-impl.so` is present. No vendor
`android.hardware.bluetooth` service binary/library was found in `installed-files-vendor.txt`.
This is a **declared HAL with the main service implementation absent**; classified Tier B, but
the pairing is unusual enough that `A-EXCISE-BT` must adjudicate B vs C.

### 4.7 Bluetooth GKI kernel modules — Tier C, 13/13 (correction to `E-4`)
`system_dlkm/lib/modules/` contains `bluetooth.ko`, `hci_uart.ko`, `btbcm.ko`, `btqca.ko`,
`btsdio.ko`, `rfcomm.ko`, `hidp.ko`. Those modules are listed in `modules.load` and are
**not** blocklisted by `system_dlkm/lib/modules/modules.blocklist` (which is empty of Bluetooth
entries on 10 devices and blocks only `usbmon.ko` on frankel/blazer/mustang/rango). Modules in
`modules.load` and not blocklisted load at boot → **Tier C**, not Tier B as the `E-4` pre-finding
stated. `A-EXCISE-BT` must confirm or falsify.

### 4.8 `nitrous` — Tier B, 13/13
`vendor_dlkm/lib/modules/nitrous.ko` is present on disk, and the built
`vendor_dlkm/lib/modules/modules.blocklist` contains `blocklist nitrous`. Present but gated →
Tier B.

### 4.9 Location / GNSS — Tier C on shiba+husky, A on the other 11
The two Gen-8 `shusky` devices retain a **complete GNSS userspace stack**:
`vendor/bin/hw/gpsd`, `vendor/lib64/hw/gps.default.so`, `vendor/etc/gnss/gps.xml`, and
`vendor/etc/init/init.gps.rc`, whose `gpsd`/`lhd`/`scd`/`gnss_service` services are in
`class main`/`class hal` and start at boot. → **Tier C** on shiba and husky. The other 11
devices have none of these (`installed-files-vendor.txt` contains 0 GNSS entries) → Tier A.
GNSS kernel drivers (`gnssif.ko`, `gnss_spi.ko`) are present in `vendor_dlkm` but blocklisted →
Tier B (`location_gnss_kernel`). This is the single most important per-device asymmetry in the
ledger; the brief's 4-device reference set did not surface it.

### 4.10 NFC — userspace A, mainline APEX B, kernel C
No NFC HAL library/service is present (Tier A). `com.android.nfcservices.apex` ships on 13/13
(Tier B). `nfc.ko` is in `system_dlkm` `modules.load` and not blocklisted → Tier C.

### 4.11 UWB — HAL C on 7, A on 6; kernel C on 13
A UWB HAL service binary **with an init.rc** ships on **husky (qorvo), caiman, komodo, comet,
blazer, mustang, rango (samsung)** — e.g.
`vendor/bin/hw/android.hardware.qorvo.uwb-service` + `vendor/etc/init/android.hardware.qorvo.uwb-service.rc`
+ `uwb-calib.rc`; the services are started by init at boot → **Tier C** on those 7. The other 6
devices have no UWB service (Tier A). UWB kernel drivers `aoc_uwb_platform_drv.ko` /
`aoc_uwb_service_dev.ko` are in `vendor_dlkm` `modules.load` and **not** blocklisted → Tier C.
`com.android.uwb.apex` ships on 13/13 (Tier B). Note: the UWB service is not declared in the
vendor VINTF manifest; the reachability basis is the init.rc + service binary, which the
auditor lanes must weigh.

### 4.12 APEX dormant set — Tier B (per-device coverage)
Installed on all 13: `bt`, `nfcservices`, `adservices`, `healthfitness`,
`ondevicepersonalization`, `uwb`, `profiling`, `uprobestats`, `telephonycore`.
`devicelock` ships only on **akita, tokay, rango**. `cellbroadcast` ships on **none** (corrects
the `E-3` list, which named both as part of the set). All are Tier B (installed, stack dormant).

### 4.13 `com.android.appsearch` — Tier C by design
`system/apex/com.android.appsearch.apex` ships on 13/13. Deliberately active; recorded as
Tier C by design per the card.

### 4.14 Telemetry / profiling — Tier B
`adservices`, `uprobestats`, `profiling`, `healthfitness`, `ondevicepersonalization`,
`os.statsd` APEXes ship on 13/13 (Tier B, dormant mainline stacks).

### 4.15 Retained connectivity (Wi-Fi / tethering) — Tier C
`com.android.wifi.apex` and `com.android.tethering.apex` ship on 13/13 and are known-reachable
connectivity surfaces. They are **outside** the cellular/BT/location excision set; recorded as
Tier C so the headline "every other connectivity service is 100% removed" is not silently
overstated.

### 4.16 Sensors / camera / mic privacy surfaces — Tier C by design
`system/build.prop` carries `ro.guardtalk.sensor_privacy_when_locked=1`; the surfaces are local
(no remote transport) and privacy-gated. Recorded Tier C by design so the audit matrix covers
them explicitly.

## 5. Corrections to the Architect pre-findings (`E-1` … `E-8`)

| ID | Pre-finding | Ledger result |
|---|---|---|
| `E-1` | Baseband firmware present 13/13 | **Confirmed** → Tier B on 13/13, waiver required |
| `E-2` | `radioExternal` on 6, absent on 7 | **Confirmed** exactly (tegu, stallion, frankel, blazer, mustang, rango) |
| `E-3` | APEX set incl. `cellbroadcast`, `devicelock` | **Partially corrected**: `cellbroadcast` absent 13/13; `devicelock` only akita/tokay/rango |
| `E-4` | 3 GKI BT modules, Tier B | **Corrected to Tier C**: 7 BT/NFC modules are in `modules.load` and not blocklisted |
| `E-5` | BT/NFC/Location feature XMLs absent | **Confirmed** for those XMLs; note eUICC telephony XML present 12/13 (§4.5) |
| `E-6` | 0 `rild`/telephony in `system/` | **Corrected**: `telephony-common.jar` present 13/13 (§4.4) |
| `E-7` | Stamps carry `radio.img` only; `REGEN_HOOKS.md` path | **Confirmed**; **new**: tokay has no `tokay-latest` (§2 †) |
| `E-8` | Gen 6/7 absent | **Confirmed** (audited absence, §1) |

**New findings not in `E-1`…`E-8`:** GNSS userspace Tier C on shiba/husky (§4.9); UWB service
+ init.rc Tier C on 7 devices (§4.11); BT/NFC GKI modules Tier C (§4.7); Wi-Fi/tethering
retained (§4.15).

## 6. Residual register (operator-waiver surface)

**Tier C — audit-fail candidates (must be resolved or the "100% removed" claim is false):**

- `bluetooth_gki_modules` — **all 13**
- `nfc_kernel_module` — **all 13**
- `uwb_kernel` — **all 13**
- `location_gnss` — **shiba, husky**
- `uwb_hal_service` — **husky, caiman, komodo, comet, blazer, mustang, rango**
- `appsearch_apex` — all 13, **by design**
- `connectivity_wifi_tethering` — all 13, retained by design
- `sensors_camera_mic_privacy` — all 13, by design

**Tier B — dormant, explicit operator waiver required:**

- `baseband_firmware` (all 13), `cellular_framework_telephony` (all 13),
  `bluetooth_userspace_hal` (all 13), `nitrous_module` (all 13),
  `location_gnss_kernel` (all 13), `nfcservices`/mainline APEX set (all 13),
  `telemetry_profiling` (all 13)
- `cellular_vendor_radioExternal_hal` — tegu, stallion, frankel, blazer, mustang, rango
- `telephony_feature_declarations` — all except tokay

**Tier A — acceptable:** `cellular_ril_native` (13/13), `nfc_userspace_hal` (13/13),
`cellular_vendor_radioExternal_hal` (7/13), `location_gnss` (11/13),
`uwb_hal_service` (6/13), `telephony_feature_declarations` (tokay).

## 7. Reproduce / verify

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree

# 1. rebuild the ledger from built artifacts (read-only; no build performed)
python3 .agent-comm/evidence/T-EXCISE-LEDGER_collect.py

# 2. acceptance checks
jq '.devices | length' vendor/guardtalk/docs/qa/excision_ledger.json          # -> 13
jq '[.devices[].artifacts[] | select(.evidence_kind=="makefile")] | length' \
   vendor/guardtalk/docs/qa/excision_ledger.json                              # -> 0
jq -r '.gen6_gen7_audited_absence' vendor/guardtalk/docs/qa/excision_ledger.json
rg -c 'makefile|\.mk' vendor/guardtalk/docs/qa/excision_ledger.json           # -> 0

# 3. cited small-artifact checksums
sha256sum -c .agent-comm/evidence/T-EXCISE-LEDGER_SHA256SUMS                 # 472 OK

# 4. one-shot harness (all of the above + coverage)
bash -n .agent-comm/evidence/T-EXCISE-LEDGER_verify.sh                       # syntax
bash .agent-comm/evidence/T-EXCISE-LEDGER_verify.sh                          # -> RESULT: PASS
```

## 8. Non-claims

- This card does **not** adjudicate the headline airgap verdict, does **not** approve itself,
  and does **not** dispatch a remediation card. The five `A-EXCISE-*` auditor lanes own the
  per-service verdicts; `A-EXCISE-AIRGAP-MATRIX` owns the final headline.
- Tier assignments are evidence-driven but **reachability adjudication** (B vs C) for the
  Bluetooth userspace HAL and the UWB service is explicitly handed to the auditors.
