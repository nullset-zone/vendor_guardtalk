# A-EXCISE-LOC — Independent Deep-Tech Audit (Location / GNSS residue)

| Field | Value |
|---|---|
| task_id | `A-EXCISE-LOC` |
| role | auditor (Panel 5, independent, READ-ONLY) |
| repository_id | `grapheneos-worktree` |
| owner root | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| program | `DEC-EXCISE-AIRGAP-001` — EXTREME AUDIT — AIRGAP CLAIM (Gen 8/9/10, 13 devices) |
| priority | P0 · `audit_scope: full` · `depends_on: —` |
| report | `vendor/guardtalk/docs/qa/A-EXCISE-LOC_AUDIT.md` |
| raw evidence | `.agent-comm/evidence/A-EXCISE-LOC/` |
| durable event | `.agent-comm/history/2026-09-24T163000+0400-A-EXCISE-LOC-audit.md` |
| Gate -1 | IN-PROCESS — `governance_loaded=true` (24 laws + 11 gates parsed from `.aegis/governance/`); no aegis-verifier / ask_guardian / gate_enforcer / Guardian HTTP used |
| Gate 5 | **HUMAN SKIP** (no numerical score invented) |
| Device results | none claimed (`LIVE_FLASH_CLAIMED=false`; no adb/fastboot/USB) |
| Task status | unchanged (auditor never sets status) |

> **Adjudication verdict (location/GNSS): `TRUE-WITH-DORMANT-RESIDUALS`.**
> No Tier C (REACHABLE) path was proven. **However, the audited claim as literally written —
> "Location/GNSS … is 100% removed from the built image on every Pixel model GuardTalk builds" —
> is FALSE**: dormant GNSS artifacts remain in the built image of **all 13** devices, and
> `shiba`/`husky` retain a near-complete GNSS userspace stack. Tier B is *"not a removal"*
> and requires an **explicit operator waiver**.

---

## 1. Scope, method, evidence discipline

**Claim under audit** (owner-root `TASK_QUEUE.md`, §A1): *"…Location/GNSS… is 100% removed from
the built image on every Pixel model GuardTalk builds."*

**Lane scope (A-EXCISE-LOC):** `FEATURE_LOCATION`, `FEATURE_LOCATION_NETWORK`, `FEATURE_LOCATION_GPS`,
the GPS feature-permission XML, the GNSS HAL/service + `.gnss-V3-ndk` + measurement_corrections /
visibility_control stubs, the vendor extension, `libcustomgnss`, the Lassen modem-bridge daemon
(`gnssd` / `gnss_test` / `lassen_dmd_constants`), GNSS VINTF fragments, GNSS init `.rc` files, the
NetworkLocation app, and GNSS-side vendor config copies (`vendor/etc/gnss/*`).

**Tier standard:** A = ABSENT · B = DORMANT (*on disk, needs explicit operator waiver; not a removal*)
· C = REACHABLE (= audit **FAIL**).

**Method.** Every cell was re-derived from **BUILT artifacts only**:
* packed stamps `releases/desktop-flash/<dev>-<stamp>/{system,vendor,system_ext,product,system_dlkm,vendor_dlkm,vendor_kernel_boot}.img`
  inspected with `debugfs` (`ls -l`, `cat`); and
* `out/target/product/<dev>/installed-files*.txt` + unpacked `system/` `vendor/` trees, and
  `sha256sum` of the referenced files.

The audited build set is the 13 program devices and their **authoritative `*-latest` stamp**
(`tokay` uses the bare `latest` symlink — see F-003). Note two pre-existing stamp-quality facts
that bound this audit: the `akita` (`20260725`), `tokay` (`20260725`), `rango` (`20260802`) and
`komodo` (`20260915`) stamps predate later service-excision work and are **not** rebuilt here.

**Re-runs of author-side suites** (required, not trusted — full logs in `.agent-comm/evidence/A-EXCISE-LOC/author_*`):

| Suite | Result | Agreement |
|---|---|---|
| `verify_port_excision_matrix_static.sh` | exit 0 — **128 PASS / 0 FAIL / 0 HOLD** | AGREE (validates the resolver; it does **not** assert the LOC build result) |
| `verify_remediate_b2_excise_host.sh` | exit 0 — **55 PASS / 4 HOLD** on `komodo-trunk_staging-user` product config | PARTIAL — product config drops `FusedLocation`/`gnssd`/`NetworkLocation`; but the *shipped* `komodo-latest` stamp still contains `FusedLocation` (F-003) |
| `verify_remediate_b2_apex_host.sh` | **exit 1 — 33 PASS / 6 HOLD / 1 FAIL** (DeviceLock SSR/BCP jars) | DISAGREE — failure is DeviceLock/APEX, **not** location; out of LOC lane, recorded for `A-EXCISE-SURFACES` |
| `verify-on-device.sh` | **NOT RUN** | Forbidden — requires `adb`/USB/no-hardware (DEC-009) |

---

## 2. Severity counts

| Severity | Count |
|---|---|
| CRITICAL | 0 |
| HIGH | 2 |
| MEDIUM | 3 |
| LOW | 3 |
| INFO | 1 |
| **Total** | **9** |

**No Tier C (REACHABLE) path was proven; verdict is not FAIL.** The literal "100% removed" wording is nonetheless contradicted (Tier B present 13/13, no waiver on record).

---

## 3. Per-device × per-artifact Tier table

`A`=ABSENT · `B`=DORMANT · `C`=REACHABLE. Column keys in `.agent-comm/evidence/A-EXCISE-LOC/02_raw_matrix.txt`.

| device | stamp | FX | GP | VH | VC | IR | KM | NL | FL | IF | LP | LV | VM |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| shiba | shiba-20260923-094055 | A | A | **B** | **B** | **B** | **B** | A | A | B | B | B | A |
| husky | husky-20260923-095309 | A | A | **B** | **B** | **B** | **B** | A | A | B | B | B | A |
| akita | akita-20260725-101434 | A | A | A | A | A | **B** | A | **B** | B | B | B | A |
| tokay | tokay-20260725-102506 | A | A | A | A | A | **B** | A | **B** | B | B | B | A |
| caiman | caiman-20260922-090535 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| komodo | komodo-20260915-063833 | A | A | A | A | A | **B** | A | **B** | B | B | B | A |
| comet | comet-20260922-160129 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| tegu | tegu-20260922-164700 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| stallion | stallion-20260923-100618 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| frankel | frankel-20260923-094457 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| blazer | blazer-20260923-090842 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| mustang | mustang-20260923-094541 | A | A | A | A | A | **B** | A | A | B | B | B | A |
| rango | rango-20260802-130756 | A | A | A | A | A | **B** | A | **B** | B | B | B | A |

**Design-layer confirmation (what the author-side design *did* achieve):**
* `FX` — the installed `handheld_core_hardware.prebuilt.xml` is **byte-identical on all 13**
  (`sha256 316472429b589e9e335e82128e9c7ba826272da5a12b6ca3a1a2181e628dbf49`) and contains **no**
  `<feature name="android.hardware.location…">` element (a repo-wide `grep` over every built
  `etc/permissions` XML returns 0 hits). ⇒ `hasSystemFeature(FEATURE_LOCATION / _NETWORK / _GPS)` is false.
* `GP` — `android.hardware.location.gps.prebuilt.xml` is **absent** everywhere.
* `NL` — `NetworkLocation` is **absent** on 13/13 (built tree and every stamp).
* `VM` — the vendor `/etc/vintf/manifest.xml` contains **0** `gnss` / `android.hardware.location` lines on 13/13.
* The Lassen GNSS HAL for the zumapro/zuma/laguna families (`gnssd`, `gnss_test`, `lassen_dmd_constants`,
  `libcustomgnss`, `android.hardware.gnss*`, `init.gnss.rc`, `pixel-gnss-default.rc`,
  `/etc/gnss/{ca.pem,gps.cfg,hash.bin}`) **is** genuinely absent from the built image.

---

## 4. Findings

### F-001 — HIGH — `shiba`/`husky` retain a near-complete GNSS userspace stack
**Evidence.** In the *packed* stamps `shiba-20260923-094055/vendor.img` and `husky-20260923-095309/vendor.img`:
```text
/vendor/bin/hw/gpsd            9708352 B   (sha256 483758d408199ddf2b8efe4c5ef49f69d18374debdb3807bbe155198f1f24f59)
/vendor/bin/hw/lhd              328064 B   (sha256 05aa8ee90d07e42c82d5afe6fed73c8d731159df19778909aab11012e2ac25b6)
/vendor/bin/hw/scd              447200 B   (sha256 3b1b756c9e774d1186d0478a819776570856c92c0febe7636a28957809ad2d69)
/vendor/lib64/hw/gps.default.so 269656 B   (ELF aarch64; sha256 11ff5c147e4c8795270948d4f7310221bb6ca2876052f1f39d278e3958e0f0d5)
/vendor/etc/gnss/{gps.cer,gps.xml,lhd.conf,scd.conf}
/vendor/etc/init/init.gps.rc (sha256 3fcab670be16764ba46e1cf447c2fa40a0c6602fd3f4b169e1026b3817c55b27)
```
`init.gps.rc` defines four services, including
`service gpsd /vendor/bin/hw/gpsd -c /vendor/etc/gnss/gps.xml` (class main ⇒ **starts at boot**) and
`service gnss_service /vendor/bin/hw/android.hardware.gnss@2.1-service-brcm`.

**Impact.** `loc-excised.mk`'s drop tokens are tokay/Lassen-specific (`gnssd`, `gnss_test`,
`lassen_dmd_constants`, `libcustomgnss`, `init.gnss.rc`, `pixel-gnss-default.rc`,
`/etc/gnss/{ca.pem,gps.cfg,hash.bin}`) and **never matched the Broadcom/shusky GNSS stack**
(`gpsd`/`lhd`/`scd`, `gps.default.so`, `init.gps.rc`, `gps.cer/gps.xml/lhd.conf/scd.conf`).
The framework-facing HAL service binary `android.hardware.gnss@2.1-service-brcm` is absent and no
vendor binary exports an `android.hardware.gnss` interface (verified: a repo-wide scan finds the
string only in `init.gps.rc`), which is why this is adjudicated **Tier B, not C** — but the GNSS
daemons and the CHIP-facing HAL library are present and the daemons are configured to run.
**Tier-C risk cannot be excluded statically** (no hardware; DEC-009) and must be confirmed or refuted on-device.

**Recommendation.** Extend the LOC excision (or a new `loc-excised-shusky` data set) to drop
`gpsd`/`lhd`/`scd`/`gps.default.so`/`init.gps.rc`/`vendor/etc/gnss/*` for the `zuma_shusky` variant,
**or** obtain an explicit operator waiver for `shiba`/`husky` naming these artifacts.

---

### F-002 — HIGH — GNSS kernel drivers are present **and in the load list** on all 13 devices
**Evidence.** `gnssif.ko` + `gnss_spi.ko` are in the packed images and in `modules.load`:
```text
vendor_kernel_ramdisk/lib/modules/modules.load : akita tokay caiman komodo comet tegu stallion
vendor_dlkm/lib/modules/modules.load          : shiba husky frankel blazer mustang rango
e.g. out/target/product/caiman/vendor_kernel_ramdisk/lib/modules/modules.load → "gnss_spi.ko gnssif.ko"
     out/target/product/shiba/vendor_dlkm/lib/modules/modules.load          → "gnss_spi.ko gnssif.ko"
sha256 (examples): caiman gnssif.ko 05736a46b9943f61892bef29d98e5dbc4239e9fdaafc31cc535699e8810ad9eb
                   shiba  gnssif.ko d1d1ed3d2ccb8f6b5f88ab8372b0f6c49ee84fab483547d175ffbd56ee733621
```
On `shiba`/`husky` the modules are additionally `blocklist`ed in `modules.blocklist` (on-demand,
loaded by the GNSS HAL); on the laguna/gemini variants there is **no** blocklist entry and no
GuardTalk blocklist token for gnss (`vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist`
contains no `gnss` line). The LOC excision never touches kernel modules.

**Impact.** The kernel GNSS driver is loaded at boot on all 13 ⇒ the GNSS chip is not "removed"
at the kernel layer. Location is not reachable through the framework (no userspace HAL), so this is
Tier B — but it is a real, uniform residual that a strict "100% removed" claim cannot survive.

**Recommendation.** Either blocklist + remove `gnssif.ko`/`gnss_spi.ko` via the variant blocklist
mechanism, or waive explicitly. Adding them to the existing per-variant blocklists is the minimal,
reversible, already-wired path.

---

### F-003 — MEDIUM — `FusedLocation` is still shipped in 4 of the 13 authoritative stamps
**Evidence.** `/system/priv-app/FusedLocation` exists in these stamps:
`akita-20260725-101434`, `tokay-20260725-102506`, `komodo-20260915-063833`, `rango-20260802-130756`
(`debugfs -R "ls -l /system/priv-app" …`). It is **absent** from the other 9 stamps. The *current*
product config does drop it — `verify_remediate_b2_excise_host.sh` re-run PASSes
`FusedLocation ABSENT` / `PRODUCT_SYSTEM_SERVER_APPS: FusedLocation ABSENT` — so this is a
**stale-stamp / claim-drift** defect, not a live makefile defect.

**Impact.** The 13-device claim is evaluated on the `*-latest` stamps; 4 of them predate the
`T-REMEDIATE-B2-EXCISE` item-8 drop. A user flashing `komodo-latest`/`akita-latest`/`tokay`(`latest`)/
`rango-latest` would get a location-provider apk that the current tree no longer builds.
`vendor/guardtalk/docs/ATTACK_SURFACE_REPORT.md:407` still states `FusedLocation` is
*"intentionally KEPT"* — that statement is **stale and wrong** vs. the current `loc-excised.mk`
and vs. 9/13 built stamps.

**Recommendation.** Re-stamp akita/tokay/komodo/rango before any claim of a uniform image, or scope
the claim per stamp; correct `ATTACK_SURFACE_REPORT.md:407`.

---

### F-004 — MEDIUM — Framework GNSS interface libraries remain in `/system/lib64` on all 13
**Evidence.** In every stamp `system.img` at `/system/lib64/`: `android.hardware.gnss@1.0.so`,
`1.1`, `2.0`, `2.1`, `android.hardware.gnss-V7-cpp.so`,
`android.hardware.gnss.measurement_corrections@1.0/@1.1.so`,
`android.hardware.gnss.visibility_control@1.0.so`, `libservices.core-gnss.so`
(9 files, identical set/sizes on 13/13; e.g. caiman `system.img` sha256
`5e01bd90a887f7d9054657d5fb629183f8aac2d682caf1400fb208690dd3517b`).

**Impact.** These are the framework-side client/interface stubs, not a GNSS HAL implementation.
They are inert without a vendor HAL, so Tier B — but they are GNSS residue that the claim's
"100% removed" wording does not admit.

**Recommendation.** Accept as Tier B and document, or (higher-effort) prove no framework consumer
loads them when `FEATURE_LOCATION=false`. Removing them is out-of-scope per the design's Law 6 stance.

---

### F-005 — MEDIUM — Framework location surface declared on all 13 (`altitude` AIDL + provider permission)
**Evidence.** Every stamp `system.img` carries
`/system/etc/permissions/com.android.location.provider.xml`
(sha256 `4ec4ab50c51a27a1be9d2dbe9209f35e86a0af73716aef89ff48158c5a6e338d`) and
`/system/etc/vintf/manifest/manifest_services_android.frameworks.location.xml` declaring
`android.frameworks.location.altitude` `IAltitudeService/default`
(sha256 `fd47c69a3f5298243fcfc21ff33dbf6cc24a68cd28eb219ddf75c3123323ece9`), plus
`framework-location-compat-config.xml`.

**Impact.** Tier B dormant framework location surface; `IAltitudeService` is a geoid/altitude helper
(not a coordinate provider) and `com.android.location.provider` is a library grant with no provider
package present. Consistent with the design's deliberate decision to keep `LocationManagerService`
running (boot-loop fix) — recorded so the umbrella audit does not mistake it for Tier A.

**Recommendation.** Document under the operator-waiver register as intentional framework retention.

---

### F-006 — LOW — `shiba`/`husky` GNSS vendor configs survive the copy-file filter
**Evidence.** `/vendor/etc/gnss/{gps.cer, gps.xml, lhd.conf, scd.conf}` present in the shiba/husky
stamps. `loc-excised.mk`'s `_gt-loc-copy-file-drop` only matches
`/etc/gnss/{ca.pem,gps.cfg,hash.bin}` (Lassen). No consumer exists (HAL absent) ⇒ Tier B.

**Recommendation.** Fold into F-001 remediation (variant-aware `/etc/gnss/*` drop).

---

### F-007 — LOW — SELinux GNSS labelling remains on all 13
**Evidence.** Built policy files still contain `gnss` types/labels on 13/13, e.g.
`system/etc/selinux/plat_service_contexts`, `plat_hwservice_contexts`, `plat_file_contexts`,
`plat_sepolicy.cil`, `vendor/etc/selinux/vendor_service_contexts`, `vendor_file_contexts`.
**Impact.** Dormant labels only; no bound service exists to be labelled. Tier B.
**Recommendation.** No action required for the LOC claim; covered by the waiver register.

---

### F-008 — LOW / INFO — Framework compatibility matrix lists `android.hardware.gnss` while the device manifest omits it
**Evidence.** `out/target/product/caiman/system/etc/vintf/compatibility_matrix.8.xml`
(`<compatibility-matrix type="framework" level="8">`) lists `android.hardware.gnss` (aidl)
with **no `optional` attribute** (the file contains zero `optional` attributes, and the same is
true for `bluetooth`, `nfc`, `radio*`, `uwb`, `ir`). The device (vendor) manifest declares no gnss
on 13/13. Static evidence cannot settle whether absence of a non-optional FCM HAL is enforced as a
boot-time VINTF failure in this configuration; the sibling `A-EXCISE-RADIO`/`-BT` lanes own the
corresponding BT/radio cases.
**Impact.** Not a location *transport*; no reachability created. Flagged for the umbrella audit so
the FCM/HAL-parity question is adjudicated once, not per lane.
**Recommendation.** Umbrella audit to determine FCM enforcement semantics for excised optional-hardware HALs.

---

### F-009 — INFO — `com.android.appsearch.apex` (kept active) has no location transport
**Evidence.** `/system/apex/` on 13/13 contains `com.android.appsearch.apex` (deliberately active).
No location/GNSS-bearing APEX exists (`com.android.location.*`/`gnss` APEX absent). `appsearch`
exposes no coordinates or GNSS interface.
**Impact.** Tier C-by-design for `appsearch` per the program, but it does **not** bear on the LOC claim.
**Recommendation.** None for LOC; `A-EXCISE-SURFACES` owns the appsearch adjudication.

---

## 5. Falsification log

| # | Attack attempted | Method | Outcome |
|---|---|---|---|
| 1 | A feature XML still declares `android.hardware.location` | `grep -rE '<feature name="android\.hardware\.location'` over every built `etc/permissions` (± `sha256` of the installed XML) | **FALSIFIED** — 0 hits; XML identical 13/13 ⇒ `FEATURE_LOCATION*` false |
| 2 | A GPS feature prebuilt still ships | `find out/target/product/*/ -name 'android.hardware.location*'` (excl. `obj/`) | **FALSIFIED** — absent everywhere |
| 3 | The vendor manifest still declares a GNSS HAL | `debugfs cat /etc/vintf/manifest.xml` × 13 | **FALSIFIED** — 0 gnss/location lines 13/13 |
| 4 | A cargo-cult `out/` tree hides real residue in the shipped stamp | debugfs direct on `releases/…/*.img`, not `out/` | **SURVIVED (negative control)** — that is exactly how F-001/F-003 were found |
| 5 | `komodo-latest` is as clean as the current product config | debugfs `/system/priv-app` on `komodo-20260915-063833` vs. re-run `verify_remediate_b2_excise_host.sh` | **FALSIFIED (author claim)** — stamp still contains `FusedLocation`; product config does not |
| 6 | Kernel GNSS drivers are gone | `modules.load`/`modules*.ko` across partitions + `debugfs` | **FALSIFIED** — present + load-listed 13/13 |
| 7 | The shiba/husky GNSS stack is excised like tokay | `find` + `ls` on built `vendor/`; `init.gps.rc` read | **FALSIFIED** — `gpsd`/`lhd`/`scd`/`gps.default.so`/`init.gps.rc` present |
| 8 | `gpsd` or `gps.default.so` secretly implements the AIDL GNSS HAL (⇒ Tier C) | `grep -a 'android\.hardware\.gnss'` on the binaries | **SURVIVED (dormancy)** — only `init.gps.rc` matches; no binary exports the HAL ⇒ remains Tier B |
| 9 | GNSS vendor configs are fully dropped | `/etc/gnss` listing in each stamp | **FALSIFIED** — shiba/husky retain 4 config files |
| 10 | NetworkLocation ships somewhere unexpected | debugfs `/system/{app,priv-app}` × 13 + installed-files | **FALSIFIED** — absent 13/13 |
| 11 | A location-bearing APEX exists | `ls /system/apex` + apex scan | **FALSIFIED** — none; only `appsearch`/`telephonycore` are location-adjacent and expose no GNSS transport |
| 12 | The author-side suites prove the LOC claim | re-ran all; `verify-on-device.sh` blocked by no-hardware | **FALSIFIED as proof** — the two re-runnable suites test product config/resolver, not the shipped LOC image; the APEX suite FAILs (non-LOC) |

No Tier C (REACHABLE) cell was producible from static built evidence. Tier C is **not excluded**
for shiba/husky `gpsd` (boot-time daemon + chip-facing HAL library) and requires on-device
confirmation, which this lane is forbidden from performing.

---

## 6. Agreement / disagreement with prior claims

| Prior claim | Source | Auditor position |
|---|---|---|
| Feature-permission XMLs for Location absent in built `etc/permissions` | Architect §A2 `E-5` | **AGREE** (0 files; `sha256`-stable) |
| Location is `TRUE-WITH-DORMANT-RESIDUALS` (not `TRUE`) | Architect §A2 provisional | **AGREE on the tier**; **DISAGREE that the wording "100% removed" survives** |
| `FusedLocation` "intentionally KEPT" | `docs/ATTACK_SURFACE_REPORT.md:407` | **DISAGREE** — current `loc-excised.mk` drops it; 9/13 stamps confirm; 4/13 stale stamps retain it |
| Product config drops `FusedLocation`/`gnssd`/`NetworkLocation` (`verify_remediate_b2_excise_host.sh`) | author-side suite | **AGREE** for product config; **DISAGREE** that this proves the shipped `komodo` stamp clean |
| `verify_remediate_b2_apex_host.sh` passes | author-side suite | **DISAGREE** — re-run exits 1 (DeviceLock SSR/BCP); non-LOC, for `A-EXCISE-SURFACES` |
| `verify_port_excision_matrix_static.sh` passes | author-side suite | **AGREE** (128/0) — resolver only, no LOC assertion |

---

## 7. Operator-waiver surface (Tier B items to waive or excise)

1. GNSS kernel modules `gnssif.ko`/`gnss_spi.ko` in `modules.load` (13/13) — F-002.
2. `shiba`/`husky` GNSS userspace daemons + `gps.default.so` + `init.gps.rc` + `/etc/gnss/*` — F-001/F-006.
3. `FusedLocation` in the 4 stale stamps (akita/tokay/komodo/rango) — F-003.
4. Framework GNSS interface libs + `com.android.location.provider.xml` + `manifest_services_android.frameworks.location.xml` (13/13) — F-004/F-005.
5. SELinux GNSS labels (13/13) — F-007.

---

## 8. Constraints honoured

READ-ONLY: no product/test/filter/flash/packer/doctrine/queue-authoritative file was edited.
No task status was changed; nothing was APPROVED/REJECTED; no agent was dispatched.
`Gate 5: HUMAN SKIP` recorded (no invented score). No USB/adb/fastboot. No device result claimed.
`.agent-comm/inbox/TO_ARCHITECT.md` was **not** touched (parallel auditors). Only
`vendor/guardtalk/docs/qa/A-EXCISE-LOC_AUDIT.md`, `.agent-comm/evidence/A-EXCISE-LOC/*`, and the
durable history event were written.

*Auditor: AEGIS Panel 5 (independent). Generated 2026-09-24T16:30:00+04:00.*
