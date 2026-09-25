# A-EXCISE-SURFACES — "All Other Surfaces" Independent Deep-Tech Audit

> **Task:** `A-EXCISE-SURFACES` (P0, Auditor / Panel 5, `audit_scope: full`)
> **Owner root:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` · `repository_id: grapheneos-worktree`
> **Program:** `DEC-EXCISE-AIRGAP-001` — "EXTREME AUDIT — AIRGAP CLAIM (Gen 8/9/10, 13 devices)"
> **Date:** 2026-09-24T16:30+04:00 · **Role:** read-only adversarial auditor
> **Governance:** `governance_loaded=true` — 24 laws (`law_00..law_23`) + 11 gates (`gate_neg1..gate_09`) loaded in-process from `.aegis/governance/{laws,gates}/*.yaml`. No aegis-verifier / ask_guardian / gate_enforcer / Guardian HTTP was used (Gate −1 in-process).
> **Gate status:** `Gate 5: HUMAN SKIP` (no self-score invented). **Never APPROVED.**
> **Device evidence:** none claimed (`LIVE_FLASH_CLAIMED=false`). This audit never touched USB/adb/fastboot.

---

## 0. Scope of this lane

This lane adjudicates the **"all other services"** surface of the headline claim:

> *…every other connectivity, telemetry and remote-surface service… is 100% removed from the built image on every Pixel model GuardTalk builds.*

Surfaces in scope: **NFC, UWB, telemetry/check-in, the APEX-dormant set (bluetooth, nfcservices, cellbroadcast, adservices, healthfitness, ondevicepersonalization, uwb, profiling, uprobestats, devicelock), `com.android.appsearch` (deliberately kept active), sensors/camera/mic privacy surfaces, and any remaining remote endpoint** (tethering, DNS-over-*, IPsec, WiFi, SE/OMAPI, eUICC).

Adjudication standard (from `TASK_QUEUE.md` §A1):

| Tier | Meaning | Acceptable for "airgapped"? |
|------|---------|------------------------------|
| **A — ABSENT** | Not in the built artifacts | Yes |
| **B — DORMANT** | on disk, no transport/HAL/feature gate; not reachable at runtime | **Requires operator waiver** |
| **C — REACHABLE** | present and can become active | **No — FAIL** |

### 0.1 Verdict (headline)

**Other-surfaces verdict: `FALSE`** — the literal universal claim *"every other connectivity, telemetry and remote-surface service … is 100% removed"* is **falsified**.

**Sub-verdict for the excision-target set: `TRUE-WITH-DORMANT-RESIDUALS`** — the deliberately-excised surfaces (NFC, UWB, Bluetooth APEX, cellbroadcast, the APEX-dormant set) are Tier A or Tier B; none of them is a live transport.

The falsification is **not** an excision implementation failure on the targeted set. It is driven by **Tier-C-by-design retained surfaces** that are present and can become active (documented, operator-visible), the most consequential being the deliberately-shipped **`GuardTalkCheckin` outbound telemetry client** and the retained **WiFi/tethering/IPsec** connectivity, plus stale **SE/OMAPI/MIFARE** and **eUICC** feature declarations.

### 0.2 Required call-out — `com.android.appsearch`

`com.android.appsearch` is **present and active on 13/13** → **Tier C by design**. Rationale is documented at `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk:127-129` ("SettingsIntelligence may depend on AppSearch for search indexing; excising it risks breaking the Settings search UI"). This is an **intentional, operator-visible exception** (it lives in the canonical excision makefile, not an undocumented default). It is a search index, not a connectivity/telemetry transport, so it does not by itself falsify the "connectivity/telemetry" clause — but it is Tier C and cannot be reported as "removed". The dependency rationale was **not independently verified** (no on-device `pm`/`dumpsys`) and is recorded as an author assertion (see F-009).

---

## 1. Audited build set (13 devices)

Read from **packed stamps** (`releases/desktop-flash/<dev>-<stamp>`) and **built trees** (`out/target/product/<dev>`), not from makefiles.

| Gen | Device | Stamp (`*-latest`) | Stamp date | Built-apex vintage |
|-----|--------|--------------------|-----------|-------------------|
| 8 | `shiba` | `shiba-20260923-094055` | 2026-09-23 | 2026-09-23 |
| 8 | `husky` | `husky-20260923-095309` | 2026-09-23 | 2026-09-23 |
| 8 | `akita` | `akita-20260725-101434` | 2026-07-25 | **2026-07-25 (older)** |
| 9 | `tokay` | **`latest` → `tokay-20260725-102506`** (no `tokay-latest` symlink) | 2026-07-25 | **2026-07-25 (older)** |
| 9 | `caiman` | `caiman-20260922-090535` | 2026-09-22 | 2026-09-22 |
| 9 | `komodo` | `komodo-20260915-063833` | 2026-09-15 | 2026-09-15 |
| 9 | `comet` | `comet-20260922-160129` | 2026-09-22 | 2026-09-22 |
| 9 | `tegu` | `tegu-20260922-164700` | 2026-09-22 | 2026-09-22 |
| 9 | `stallion` | `stallion-20260923-100618` | 2026-09-23 | 2026-09-23 |
| 10 | `frankel` | `frankel-20260923-094457` | 2026-09-23 | 2026-09-23 |
| 10 | `blazer` | `blazer-20260923-090842` | 2026-09-23 | 2026-09-23 |
| 10 | `mustang` | `mustang-20260923-094541` | 2026-09-23 | 2026-09-23 |
| 10 | `rango` | `rango-20260802-130756` | 2026-08-02 | **2026-08-20 (older)** |

**Vintage note (citation correction to the brief):** `tokay` has **no `tokay-latest` symlink**; the generic `latest` → `tokay-20260725-102506` is its stamp. `akita`, `tokay` and `rango` built trees **predate** the 2026-09-19 `devicelock-apex-excised.mk` wave (their `system/apex/` still ships `com.android.devicelock.apex`). `rango-latest` is **unchanged** at `rango-20260802-130756` (verified).

**Gen 6 (`gs101`) / Gen 7 (`gs201`) = AUDITED ABSENCE.** No GuardTalk build/stamp exists for these; `device/google/` contains no `gs101*`/`gs201*` directory. Recorded, not omitted.

---

## 2. Per-device × per-surface Tier matrix (from BUILT / PACKED artifacts)

Tier legend: **A** absent · **B** dormant · **C** reachable. `C*` = Tier C **by design** (documented, operator-visible exception). Cells are identical column-wise unless stated.

| Surface (artifact) | shiba | husky | akita | tokay | caiman | komodo | comet | tegu | stallion | frankel | blazer | mustang | rango |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| NFC — `com.android.nfcservices.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| UWB — `com.android.uwb.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| Bluetooth — `com.android.bt.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| Cell Broadcast — `com.android.cellbroadcast.apex` | **A** | A | A | A | A | A | A | A | A | A | A | A | A |
| AdServices — `com.android.adservices.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| HealthFitness — `com.android.healthfitness.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| OnDevicePersonalization APEX | B | B | B | B | B | B | B | B | B | B | B | B | B |
| Profiling — `com.android.profiling.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| UprobeStats — `com.android.uprobestats.apex` | B | B | B | B | B | B | B | B | B | B | B | B | B |
| DeviceLock — `com.android.devicelock.apex` | A | A | **B** | **B** | A | A | A | A | A | A | A | A | **B** |
| **`com.android.appsearch.apex`** | **C\*** | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| **Telemetry/check-in — `GuardTalkCheckin`** | **C\*** | C\* | A | A | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | A |
| Tethering — `com.android.tethering.apex` | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| IPsec — `com.android.ipsec.apex` | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| WiFi — `com.android.wifi.apex` | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| Sensors/Camera/Mic (retained, policy-gated) | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |
| SE/OMAPI eSE+UICC, MIFARE (feature declared, no HAL) | B | B | B | B | B | B | B | B | B | B | B | B | B |
| Debug/ADB (userdebug, `ro.debuggable=1`) | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* | C\* |

**Notes**
- All Tier-B APEX cells are backed by **files of non-trivial size** (never stub/zero) — e.g. `com.android.adservices.apex` 13,651,968 B, `com.android.ondevicepersonalization.apex` 10,158,080 B, `com.android.bt.apex` 15,364,096 B on `shiba` (packed `/system/apex`, `debugfs`).
- **Tier-A evidence:** `android.hardware.{bluetooth,bluetooth_le,nfc,uwb,location,location.network,gps}.xml` are **absent** from every partition's `etc/permissions` on 13/13; no `android.hardware.{nfc,uwb,radio,gnss,location}` entry exists in the built/packed vendor VINTF manifest on the 7 devices sampled (`shiba, husky, akita, tokay, rango, frankel, stallion`). BT entries **are** present on all 7 (F-003).
- **`com.android.cellbroadcast.apex`** is absent in all 13 built trees (and no packed artifact).
- **`devicelock`** present only where the built tree predates the 2026-09-19 excision.
- **`GuardTalkCheckin`** absent on `akita`/`tokay`/`rango` only because those trees predate its 2026-09-16 wiring.

---

## 3. Severity counts

| Severity | Count | IDs |
|----------|-------|-----|
| **HIGH** | 2 | F-001, F-002 |
| **MEDIUM** | 5 | F-003, F-004, F-005, F-006, F-008 |
| **LOW** | 3 | F-007, F-009, F-010 |
| **Total** | **10** | |

---

## 4. Findings

### F-001 — HIGH — `adservices`/`healthfitness`/`ondevicepersonalization` APEX present on 13/13, but the canonical makefile claims "the APEX itself is gone"

- **Evidence:** `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk:132-139` states the three APEX "are now **FULLY excised**, not just dormant … **the APEX itself is gone**". The implementing file `vendor/guardtalk/feature-excised/apex-bcp-excised.mk:56-78` states the three BCP filter stages are **DISABLED** (reverted 2026-07-04 after a Zygote `NoClassDefFoundError` boot-loop). Built + packed artifacts contain all three on **13/13** (`com.android.adservices.apex` 13,651,968 B; `com.android.healthfitness.apex` 8,486,912 B; `com.android.ondevicepersonalization.apex` 10,158,080 B). SHA-256 (`shiba`): `a82f2ac7…`, `55aded9c…`, `0d3d40ce…`. Evidence: `.agent-comm/evidence/A-EXCISE-SURFACES/makefile_vs_artifact.txt`, `apex_matrix.tsv`, `packed_images.txt`.
- **Impact:** A reader (or the umbrella audit / a claims surface) can conclude these three attack-surface stacks are removed when they ship in every image. Correct tier is **B (dormant)**, not Tier A. Claim-integrity violation (Law 1/7/19).
- **Recommendation:** Correct the stale comment in `guardtalk-feature-excised.mk` to state "kept dormant (BCP excision disabled)"; register them on the operator-waiver register. Do **not** re-enable BCP excision until `SystemServiceRegistry` is patched (per `apex-bcp-excised.mk`).

### F-002 — HIGH — `GuardTalkCheckin` is a shipped, active outbound telemetry client on 10/13

- **Evidence:** `GuardTalkCheckin.apk` present in built `system_ext/priv-app/` on 10/13 (`shiba husky caiman komodo comet tegu stallion frankel blazer mustang`); absent `akita/tokay/rango` (older trees). Packed `shiba` `system_ext.img /priv-app/GuardTalkCheckin` **confirmed**. `AndroidManifest.xml` holds `INTERNET`, `ACCESS_NETWORK_STATE`, `RECEIVE_BOOT_COMPLETED`, a `BOOT_COMPLETED` receiver, a `JobScheduler` service, and `usesCleartextTraffic="true"`. Config at `vendor/guardtalk/checkin/`, `SEIZURE_CHECKIN.md`.
- **Impact:** This is an **outbound remote-surface/telemetry service deliberately shipped**. It directly falsifies the literal claim "every telemetry … service 100% removed". It is **fail-closed by design** (no baked public C2; endpoint only from `Settings.Global[guardtalk_checkin_endpoint]`, allowlisted to v3‑onion-over-SOCKS or RFC1918/ULA/loopback; empty endpoint → `skipped_no_endpoint`). Tier = **C by design**, not a defect in the excision logic.
- **Recommendation:** Record as an explicit operator-visible Tier-C-by-design exception (like appsearch); ensure the claims surface states the check-in client is present. If a true "no outbound service" posture is required, this client must be excised or feature-gated by an operator flag.

### F-003 — MEDIUM — Bluetooth HAL is still declared in the built/packed vendor VINTF manifest (13/13)

- **Evidence:** `out/target/product/<dev>/vendor/etc/vintf/manifest.xml` (and packed `vendor.img /etc/vintf/manifest.xml`) declares `android.hardware.bluetooth` (`IBluetoothHci/default`), `android.hardware.bluetooth.finder`, `android.hardware.bluetooth.ranging`, and `vendor.google.bluetooth_ext` on every sampled device. The manifest provenance header cites GuardTalk's own `vendor/guardtalk/vintf/vendor_manifest_no_radio_*.xml`, which contain those BT entries. A `vendor_manifest_no_bt.xml` exists but is **not** the one wired in.
- **Impact:** `bt-excised.mk` Layer 3 claims dropping the HAL package removes the manifest declaration; the artifact shows the GuardTalk-curated manifests reintroduce it. The framework's VINTF will expect a BT HAL that is never served. Contributes to BT being Tier B-with-live-VINTF-residue rather than cleanly dormant. (Full BT lane: `A-EXCISE-BT`.)
- **Recommendation:** Wire `vendor_manifest_no_bt.xml` (or filter the BT `<hal>` blocks from the `no_radio_*` manifests) for all 13; re-derive with `A-EXCISE-BT`.

### F-004 — MEDIUM — `com.android.devicelock.apex` present on 3/13, absent on 10/13 (per-device inconsistency)

- **Evidence:** Present in `out/target/product/{akita,tokay,rango}/system/apex/com.android.devicelock.apex` (3,723,264 B) and in packed `rango`/`tokay` `/system/apex`; absent on the other 10 built trees and packed `shiba`/`frankel`. `devicelock-apex-excised.mk` (2026-09-19) postdates the `akita`/`tokay` (2026-07-25) and `rango` (2026-08-20) trees. The **author-side** `verify_remediate_b2_apex_host.sh` **FAILS on host (exit 1)** with `PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS missing com.android.devicelock:service-devicelock (SSR stripped — Zygote risk)` — agreeing that the DeviceLock excision/BCP handling is unresolved.
- **Impact:** The dormancy claim is not uniform across the 13; `/system/apex` provenance differs by build vintage. Law 8 (determinism) / Law 20 (cross-compat) exposure.
- **Recommendation:** Rebuild `akita`/`tokay`/`rango`, or explicitly waive the three as "legacy stamp, devicelock APEX retained"; resolve the b2_apex SSR/BCP question before any umbrella sign-off.

### F-005 — MEDIUM — GKI BT/NFC kernel modules are **loaded** (`modules.load`) on 13/13 — larger than the reported "3 modules"

- **Evidence:** `out/target/product/<dev>/system_dlkm/lib/modules/modules.load` loads **8** BT/NFC modules on **13/13**: `bluetooth.ko`, `hci_uart.ko`, `btbcm.ko`, `btqca.ko`, `btsdio.ko`, `rfcomm.ko`, `hidp.ko`, `nfc.ko`. `system_dlkm/lib/modules/modules.blocklist` is empty (shiba/husky) or contains only `usbmon` (rango/frankel); **no BT/NFC module is blocklisted**. `nitrous` (BCM BT power/rfkill) is blocklisted in `vendor_dlkm`, as claimed.
- **Impact:** Architect recon `E-4` ("3 GKI Bluetooth kernel modules remain") **undercounts**: 8 are present **and scheduled to load**, including `nfc.ko`. Tier B residual is real but broader than reported. `bt-excised.mk`'s "harmless without nitrous" rationale holds for transport (no HCI UART/rfkill power-on) but does not remove them.
- **Recommendation:** Either add the GKI BT/NFC modules to a blocklist (with a proven no-transport rationale) or register the residual explicitly for operator waiver. Re-derive with `A-EXCISE-BT`.

### F-006 — MEDIUM — Stale reachable feature declarations for NFC-SE and eUICC remain in packed images

- **Evidence (packed `shiba` `vendor.img /etc/permissions`):** `android.hardware.se.omapi.ese.prebuilt.xml` → `<feature name="android.hardware.se.omapi.ese"/>`, `android.hardware.se.omapi.uicc.prebuilt.xml` → `…uicc`, `com.nxp.mifare.prebuilt.xml` → `com.nxp.mifare`. **(packed `product.img /etc/permissions`):** `android.hardware.telephony.euicc.xml` → `<feature name="android.hardware.telephony.euicc"/>` (+ `.mep`). `EuiccSupportPixel-P23` is in packed `system_ext /priv-app`.
- **Impact:** `hasSystemFeature(FEATURE_NFC_ESE / eUICC)` is **true** while the NFC HAL and host radio stack are excised → the eSE/OMAPI and eUICC/eSIM capabilities are advertised but unbacked. This is the mirror-image of the NFC/BT dormancy mechanism (there the feature XMLs were dropped; here the NFC-adjacent SE/OMAPI and eUICC declarations were not). Advertised-but-unbacked features are a Tier-B/C residue and a correctness/claim-integrity issue.
- **Recommendation:** Decide and document whether `se.omapi.{ese,uicc}`, `com.nxp.mifare`, and `telephony.euicc*` are intentionally retained; if not, drop them in the same wave as the NFC/BT feature XMLs and remove/mark `EuiccSupportPixel`. Overlaps `A-EXCISE-RADIO`.

### F-007 — LOW — WiFi / tethering / IPsec are present and feature-declared (retained connectivity)

- **Evidence:** `com.android.wifi.apex`, `com.android.tethering.apex`, `com.android.ipsec.apex` present on 13/13. Declared features include `android.hardware.wifi(.aware/.direct/.passpoint/.rtt)` and `android.software.ipsec_tunnels` / `ipsec_tunnel_migration`.
- **Impact:** A literal reading of "every other **connectivity** … service 100% removed" is overbroad — WiFi/tethering/IPsec remain (evidently by design; `EXCISION_MATRIX.md` §2 explicitly preserves WiFi). Not a runtime defect; a claim-scope/honesty issue.
- **Recommendation:** Scope the claim to the intended excision set; or state WiFi/tethering/IPsec/VPN as intentionally retained.

### F-008 — MEDIUM — Shipped stamps are `userdebug` / `ro.debuggable=1`

- **Evidence (packed `/system/build.prop`):** `ro.build.type=userdebug`, `ro.debuggable=1`, `ro.secure=1` on sampled `shiba`, `frankel`, `rango`, `tokay`, `caiman`. No baked ADB key: `/adb_keys` is a symlink to `/product/etc/security/adb_keys`, which **does not exist** in the packed product image.
- **Impact:** A debuggable build is a remote/debug capability contingent on runtime ADB authorization. For an "airgapped" posture this should be an explicit, operator-visible decision. (Not a service-removal failure per se.)
- **Recommendation:** Confirm the shipping variant (`user` vs `userdebug`) with the operator; if the airgap claim is asserted for production, ship `user` (cf. `T-REMEDIATE-B1-USERBUILD`).

### F-009 — LOW — `com.android.appsearch` Tier-C-by-design (required call-out); dependency rationale unverified

- **Evidence:** `com.android.appsearch.apex` (2,875,392 B; SHA-256 `558f0bd9…`) present 13/13; `com.android.appsearch` priv-app + `service-appsearch.jar` staged. Rationale at `guardtalk-feature-excised.mk:127-129` (SettingsIntelligence dependency); `SettingsIntelligence` present in packed `product /priv-app`. No independent dependency proof was possible without a device.
- **Impact:** Intentional, operator-visible Tier-C exception. Correctly disclosed in-tree, but the "may depend" rationale is an assertion, not a proof.
- **Recommendation:** Keep the explicit disclosure; if a hard airgap is required, prove/replace the SettingsIntelligence–AppSearch dependency before excision.

### F-010 — LOW — Dangling telephony/RIL/IMS/IWLAN permission XMLs remain in packed `system_ext`

- **Evidence (packed `shiba` `system_ext.img /etc/permissions`):** `google-ril.xml`, `oemrilhook.xml` (references `/system_ext/framework/oemrilhook.jar`), `com.shannon.imsservice.xml`, `com.shannon.rcsservice.xml`, `com.samsung.slsi.telephony.oemril.xml`, `privapp-permlist_com.google.android.iwlan.xml`, `privapp-permissions-google-se.xml`, `com.google.euiccpixel.*`, `com.google.android.rilextension.xml`. Their backing jars/apps did not appear in the packed `system_ext /framework` / `/app` listings.
- **Impact:** Dangling config referencing absent RIL/IMS/IWLAN/eUICC components; confuses the excision ledger. (Primary adjudication: `A-EXCISE-RADIO`.)
- **Recommendation:** Reconcile with `A-EXCISE-RADIO`; remove the XMLs if their packages are excised.

---

## 5. Falsification log (adversarial attacks attempted)

| # | Attack | Method | Result |
|---|--------|--------|--------|
| 1 | A "Tier A" cell that is really present | `debugfs` the **packed** `system.img`/`vendor.img`/`product.img`/`system_ext.img` for `shiba`,`rango`,`tokay`,`frankel` — do not trust `out/` | **Succeeded as a check:** packed `/system/apex` matches the built set; caught the "APEX gone" false claim (F-001). |
| 2 | A feature XML the excision claims to drop but does not | Enumerate every `<feature name=…>` in all partitions + APEX staging on 13/13 | NFC/BT/UWB/Location/Telephony feature XMLs **are** absent (confirms dormancy); **but** `se.omapi.ese/uicc`, `com.nxp.mifare`, `telephony.euicc(.mep)` **remain** (F-006). |
| 3 | A blocklisted module still present | `modules.load` vs `modules.blocklist` per device | **Caught:** 8 BT/NFC modules are **loaded**, none blocklisted (F-005) — contrary to the "3 remain" recon. |
| 4 | An APEX "removal" that is actually presence | `ls`+`sha256sum` of `adservices`/`healthfitness`/`ondevicepersonalization` | **Caught the false "APEX itself is gone" comment** (F-001); all three present 13/13. |
| 5 | A cell that cites a makefile as evidence | Required every cell to cite built/packed artifact | Confirmed; no cell rests on a `.mk`. Makefile contradiction surfaced separately (F-001). |
| 6 | Silent no-op / per-device asymmetry | Compare dormant-apex matrix across 13 | **Caught:** `devicelock` present on 3/13, absent 10/13 (F-004); `GuardTalkCheckin` 10/13; build vintages differ. |
| 7 | Excision "removed" claimed for a surface that is by-design present | Read `guardtalk-feature-excised.mk`, `SEIZURE_CHECKIN.md` | **Caught:** appsearch (Tier C by design) and `GuardTalkCheckin` (Tier C by design) falsify the universal "100% removed" clause (F-002, F-009). |
| 8 | A BT VINTF declaration that excision claims removed | Inspect packed `vendor.img /etc/vintf/manifest.xml` | **Caught:** BT HAL still declared 13/13; `vendor_manifest_no_bt.xml` unused (F-003). |
| 9 | Trust the author-side suite blindly | Re-ran 3 author suites | `verify_port_excision_matrix_static.sh` PASS 128/0; `verify_remediate_b2_excise_host.sh` **PASS (host) 55/4-hold**; `verify_remediate_b2_apex_host.sh` **FAIL (host)** — agrees with F-004. See §6. |
| 10 | On-device truth | — | **FORBIDDEN / HOLD.** No USB/adb/fastboot; `verify-on-device.sh` is USB-based and not run. `Gate 5: HUMAN SKIP`. |

---

## 6. Agreement / disagreement with prior claims

| Prior claim | Source | Auditor result |
|-------------|--------|----------------|
| `E-3` — BT/NFC/telephonycore/UWB/adservices/healthfitness/ODP/profiling/uprobestats/devicelock/appsearch APEX on disk | Architect recon | **AGREE** (present 13/13), **except** `devicelock` is present on only 3/13 (architect statement was generic) and `cellbroadcast` is absent. |
| `E-5` — BT/NFC/Location feature XMLs = 0 in built `etc/permissions` | Architect recon | **AGREE** for BT/NFC/Location. **EXTEND:** NFC-adjacent `se.omapi.ese/uicc` + `mifare` and `telephony.euicc` remain declared (F-006). |
| `E-4` — 3 GKI BT modules remain, only `nitrous` blocklisted | Architect recon | **PARTIAL DISAGREE:** 8 BT/NFC modules are in `modules.load` 13/13; `nitrous` blocklist confirmed (F-005). |
| `verify_port_excision_matrix_static.sh` PASS 128/0 | author suite | **AGREE** (re-run, exit 0). It validates variant resolution, **not** APEX presence — it does not falsify F-001/F-004. |
| `verify_remediate_b2_excise_host.sh` PASS (host) 55 pass / 4 hold | author suite | **AGREE** (re-run, exit 0). |
| `verify_remediate_b2_apex_host.sh` FAIL (host) | author suite | **AGREE/REPRODUCE:** exit 1 — `SSR stripped (Zygote risk)`; consistent with F-004. |
| `verify-on-device.sh` | author suite | **NOT RUNNABLE / NOT TRUSTED:** requires `adb`; HOLD (forbidden). Never device-fixed. |
| Provisional headline `TRUE-WITH-DORMANT-RESIDUALS` for other surfaces | Architect §A2 | **SUPERSEDED:** excision set is A/B (agree), but the literal universal claim is **FALSE** due to Tier-C-by-design surfaces (F-002, F-006, F-007, F-009). |

---

## 7. Operator-waiver register (Tier B residual → needs explicit waiver)

1. `com.android.nfcservices` / `uwb` / `bt` / `adservices` / `healthfitness` / `ondevicepersonalization` / `profiling` / `uprobestats` APEX present (dormant) — 13/13.
2. `com.android.devicelock.apex` present on `akita`, `tokay`, `rango`.
3. GKI `bluetooth.ko`/`hci_uart.ko`/`btbcm.ko`/`btqca.ko`/`btsdio.ko`/`rfcomm.ko`/`hidp.ko`/`nfc.ko` in `modules.load` — 13/13.
4. Bluetooth HAL declared in vendor VINTF manifest — 13/13.
5. Stale `se.omapi.ese/uicc` + `com.nxp.mifare` + `telephony.euicc*(.mep)` feature declarations.
6. Dangling RIL/IMS/IWLAN permission XMLs in `system_ext`.

## 8. Tier-C-by-design register (intentional, operator-visible exceptions — must be stated, not called "removed")

1. **`com.android.appsearch`** — 13/13 (rationale in `guardtalk-feature-excised.mk:127-129`).
2. **`GuardTalkCheckin`** outbound telemetry/check-in client — 10/13 (fail-closed; `SEIZURE_CHECKIN.md`).
3. **WiFi** — 13/13 (`android.hardware.wifi*` declared).
4. **Tethering** — 13/13 (`com.android.tethering.apex`).
5. **IPsec/VPN** — 13/13 (`android.software.ipsec_tunnels` declared).
6. **Sensors/Camera/Mic** — 13/13 retained, runtime policy-gated (`SENSOR_PRIVACY_LOCKDOWN_POLICY.md`).
7. **Debug/ADB (userdebug, `ro.debuggable=1`)** — 13/13.

---

## 9. Evidence index (raw)

All under `.agent-comm/evidence/A-EXCISE-SURFACES/`:
- `apex_inventory.txt` — `ls -l` of `system/apex` for 13/13
- `apex_matrix.tsv` — per-device × per-surface A/B presence matrix + stamp
- `packed_images.txt` — `debugfs` listing of packed `/system/apex` + `/system/etc/permissions` for shiba/rango/tokay/frankel
- `feature_surface.txt` — full declared `<feature>` set + absence check per device
- `kernel_bt_nfc.txt` — `modules.load`/`modules.blocklist` per device + GuardTalk blocklist
- `checkin_appsearch.txt` — per-device `GuardTalkCheckin.apk` + `appsearch.apex` presence
- `makefile_vs_artifact.txt` — F-001 contradiction, verbatim
- `author_verify_port_excision_matrix_static.out`, `author_verify_b2_apex.out`, `author_verify_b2_excise.out` — re-run author suites

Representative SHA-256 (built `shiba` `system/apex`): `nfcservices` `5d20bad7…`, `uwb` `0299bc03…`, `bt` `5352fe81…`, `adservices` `a82f2ac7…`, `healthfitness` `55aded9c…`, `ondevicepersonalization` `0d3d40ce…`, `appsearch` `558f0bd9…`, `tethering` `9257f317…`, `ipsec` `34785666…`, `wifi` `6bce3790…`.

---

## 10. Compliance / holds

- **Read-only:** no product/test/filter/flash/packer/doctrine/queue file was edited. Only this report, `.agent-comm/evidence/A-EXCISE-SURFACES/*`, and the durable history event were written. `.agent-comm/inbox/TO_ARCHITECT.md` was **not** touched. No task status changed. No agent dispatched.
- `LIVE_FLASH_CLAIMED=false`; no USB/adb/fastboot; no device result claimed.
- `Gate 5: HUMAN SKIP` — no score invented. **Never APPROVED.**
- Gen 6/7 recorded as **audited absence**.

*Auditor Panel 5 — A-EXCISE-SURFACES — verdict: `FALSE` (universal claim) / `TRUE-WITH-DORMANT-RESIDUALS` (excision-target set).*
