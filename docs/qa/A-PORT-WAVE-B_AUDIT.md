# A-PORT-WAVE-B — Independent Deep-Tech Audit (Panel 5, Auditor) — Wave B `shiba` / `husky`

| Field | Value |
|---|---|
| task_id | `A-PORT-WAVE-B` |
| role | auditor (Independent Deep Tech, Panel 5) |
| audit_scope | full |
| repository_id | `grapheneos-worktree` |
| owner_repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| authoritative_task_path | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` |
| program | `AUDIT WAVE DISPATCH` §B (`DEC-AUDIT-WAVE-RESCOPE`) |
| depends_on (re-scoped §B2) | `T-PORT-BUILD-BATCH-A` + `Q-PORT-FLASH-CLI-9DEV` ✅ + `Q-EXCISE-13DEV-MATRIX` ✅ |
| gate -1 | **IN-PROCESS** (`governance_loaded=true` — 24 laws + 11 gates from `.aegis/governance/`) |
| gate 5 | **HUMAN SKIP** (no score invented) |
| status | **REVIEW** (never APPROVED) |
| timestamp | 2026-09-24T18:05:00+04:00 |
| `LIVE_FLASH_CLAIMED` | **false** · DEC-009 HOLD · no USB/adb/fastboot · no device/boot result |

**Scope discipline.** READ-ONLY. Audited the **built and stamped** artifact for `shiba` and `husky`
(`zuma_shusky`). **Each device audited separately** — no blanket verdict. Cross-referenced
`A-EXCISE-13DEV-NONREGRESSION` (RESOLVER HOLDS), `A-EXCISE-LOC_AUDIT.md`,
`A-EXCISE-AIRGAP-MATRIX_AUDIT.md` (umbrella §D3) rather than re-deriving their resolver/excision
work. No product/test/filter/flash/packer/doctrine/queue file was modified.

---

## 1. Headline verdict (per device, never one blanket green)

> **The Wave-B bundles and stamps are intact and the `zuma_shusky` variant is correct (the
> `akita`-blocklist silent-no-op does NOT reproduce). But neither device may be reported as
> “excised”: both ship a live, init-started Lassen location daemon stack (Tier C) and 8
> unblocklisted BT/NFC GKI modules (Tier C).**

| Device | Bundle / stamp / flash integrity | Excision posture (literal) |
|---|---|---|
| `shiba` | **PASS** | **FALSE** — Tier C location userspace + Tier C BT/NFC kernel |
| `husky` | **PASS** | **FALSE** — Tier C location userspace + Tier C BT/NFC kernel |

Wave-B adjudication: **artifacts INTACT, excision posture FALSE on both** — consistent with the
EXCISE umbrella (`DEC-EXCISE-AIRGAP-001` final verdict **FALSE**).

## 2. Severity counts

| Severity | Count | IDs |
|---|---|---|
| CRITICAL | **0** | — |
| HIGH | **2** | F-001, F-002 |
| MEDIUM | **0** | — |
| LOW | **2** | F-003, F-004 |
| INFO | **3** | F-005, F-006, F-007 |

## 3. Per-device × scope-item table (2 rows, all 6 scope items)

| Device | Stamp (mtime) | 1 · Bundle completeness | 2 · Stamp identity | 3 · Variant from SHIPPED image | 4 · Flash-script coverage | 5 · Non-regression | 6 · Location daemon / BT residual |
|---|---|---|---|---|---|---|---|
| **shiba** | `shiba-20260923-094055` (`vendor.img` sha256 `146bc37b…`, packed 2026-09-23T09:40:55Z; symlink mtime 2026-09-23T09:41:17Z) | **PASS** — `sha256sum -c SHA256SUMS` exit **0** (20/20 OK); all required download-set images present; `super.img` omitted by design (`super_empty.img` present) | **PASS** — `shiba-latest → shiba-20260923-094055` (matches claim; link inode 193110388) | **PASS** — `zuma_shusky` blocklist header + `blocklist bcmdhd4398`; **NOT** akita's `bcmdhd4383`; VINTF header `vendor_manifest_no_radio_shiba.xml` | **PASS** — `DEVICE=shiba` resolves (L359-362); profile **UART+FIPS+DPM** (L524); `bash -n` exit **0** | **PASS** — incumbents unchanged (`latest`→tokay-20260725-102506, akita/komodo/rango inodes+mtime unchanged) | **REPRODUCES** — Tier C: `gpsd`/`lhd`/`scd` + `init.gps.rc` (class main, no `disabled`); 8 BT/NFC GKI modules loaded/unblocklisted |
| **husky** | `husky-20260923-095309` (`vendor.img` sha256 `65832923…`, packed 2026-09-23T09:53:09Z; symlink mtime 2026-09-23T09:53:31Z) | **PASS** — `sha256sum -c SHA256SUMS` exit **0** (20/20 OK); all required download-set images present | **PASS** — `husky-latest → husky-20260923-095309` (matches claim; link inode 193110389) | **PASS** — `zuma_shusky` blocklist header + `blocklist bcmdhd4398`; **NOT** akita's `bcmdhd4383`; VINTF header `vendor_manifest_no_radio_husky.xml` | **PASS** — `DEVICE=husky` resolves (L363-366); profile **UART+FIPS+DPM** (L524); `bash -n` exit **0** | **PASS** — incumbents unchanged (same as shiba) | **REPRODUCES** — Tier C: same location-daemon stack; 8 BT/NFC GKI modules loaded/unblocklisted |

## 4. Findings

### F-001 — **HIGH** — Live, init-started Lassen location/GNSS daemon stack ships on `shiba` **and** `husky` (Tier C)

**Evidence (shipped `vendor.img`, `debugfs`; both stamps identical set):**

- `/vendor/bin/hw/gpsd` (9,708,352 B), `/vendor/bin/hw/lhd` (328,064 B), `/vendor/bin/hw/scd` (447,200 B) — present.
- `/vendor/lib64/hw/gps.default.so` (269,656 B) — present.
- `/vendor/etc/init/init.gps.rc` (725 B, sha256 `3fcab670be16764ba46e1cf447c2fa40a0c6602fd3f4b169e1026b3817c55b27`) declares **3 services in `class main` with no `disabled`**:
  `service lhd … class main` · `service gpsd -c /vendor/etc/gnss/gps.xml class main` · `service scd … class main`.
- `/vendor/etc/gnss/{gps.cer,gps.xml,lhd.conf,scd.conf}` — 4 files present.
- SELinux: `/vendor/bin/hw/gpsd u:object_r:gpsd_exec:s0`, `lhd_exec`, `scd_exec` (in shipped `vendor/etc/selinux/vendor_file_contexts`).
- **No `disabled` keyword** ⇒ the `class main` services are auto-started by `init` at boot. This is the Tier-C (“REACHABLE”) definition, not dormancy.

**Negative control (13/13 re-measured from shipped `vendor.img`):** `shiba`=present, `husky`=present;
`akita,caiman,komodo,comet,tegu,stallion,frankel,blazer,mustang,rango` (and `tokay` via the global
`latest` alias) = **0** location daemons. Raw evidence:
`.agent-comm/evidence/A-PORT-WAVE-B/location-daemon-13dev-negative-control.txt`.

**Impact.** Falsifies the location half of the airgap claim on 2/13. The `T-EXCISE-LEDGER` collector
independently classified exactly these artifacts Tier C (`shiba: C=4`, `husky: C=4`). **These stamps
must not be reported as location-excised.**

**Recommendation.** (Not dispatched — Architect/operator decision.) Extend the `zuma_shusky` path of
`loc-excised.mk` to the `gps`/`lhd`/`scd`-named Lassen set (`gpsd`,`lhd`,`scd`,`gps.default.so`,
`init.gps.rc`,`vendor/etc/gnss/{gps.cer,gps.xml,lhd.conf,scd.conf}`), variant-parameterised with a
negative fixture; **or** obtain an explicit operator waiver. Do not mark excised until one is done.

**Cross-reference.** Reproduces `E-9`; umbrella `A-EXCISE-AIRGAP-MATRIX` §D3 ruling **Tier C upheld**
on the basis "`class main` services with no `disabled` are started at boot". This audit **concurs with D3**
and **disagrees with** `A-EXCISE-LOC_AUDIT` `F-001`'s *Tier B* framing — see §5.

### F-002 — **HIGH** — 8 BT/NFC GKI transport modules are loaded and **unblocklisted** on both devices (Tier C)

**Evidence (shipped `system_dlkm.img`):** `modules.load` lists all 8 —
`hci_uart.ko`, `btsdio.ko`, `btbcm.ko`, `btqca.ko`, `bluetooth.ko`, `rfcomm.ko`, `hidp.ko`, `nfc.ko` —
and `modules.blocklist` is **0 bytes** (empty) on **both** `shiba` and `husky`. A module in
`modules.load` and not blocklisted is loaded at boot ⇒ Tier C. Corroborated by the shipped VINTF
manifest still declaring BT HALs (3 `android.hardware.bluetooth*` entries) on both.
Raw: `.agent-comm/evidence/A-PORT-WAVE-B/system_dlkm-bt-nfc-gki.txt`, `…/vintf-hal-summary.txt`.

**Impact.** Falsifies the Bluetooth half of the claim on these 2 devices (program-wide `13/13`).
Independent of the `nitrous` question (which is blocklisted here). **Must not be reported as BT-excised.**

**Recommendation.** Accept as Tier C residual / operator waiver, or add the 8 modules to the
`zuma_shusky` `system_dlkm` blocklist variant and re-stamp. (Not dispatched.)

**Cross-reference.** Reproduces `E-14`; umbrella per-service **Bluetooth = FALSE**.

### F-003 — **LOW** — Shipped `zuma_shusky` blocklist provenance header names non-shusky devices as “in-force exemplars”

**Evidence.** The shipped `vendor_dlkm.img` blocklist header (both devices, sha256
`6907852cb6ffe1312a850a2cce922aac1e67c2945e952eb0b37276c2b6f13e23`) states:
`# In-force exemplars: vendor/guardtalk/device/{akita,komodo,rango}/vendor_dlkm.modules.blocklist.`
Yet the shipped blocklists of those three are **different variants**: `akita` =
`bcmdhd4383` (akita-kernels), `komodo` = `bcmdhd4390` (caimito-kernels), `rango` =
`bcmdhd4383.ko`/`bcmdhd4390.ko`. None uses the `zuma_shusky` (`bcmdhd4398`) set.

**Impact.** Documentation-only — the shipped **content** is correct (`bcmdhd4398` + `nitrous`), so
functionality is not affected. But the header points at the *exact* wrong-variant source that the
audited silent-no-op class (`T-PORT-SHARED-CORE-FIX`) is about; it is a maintenance trap.

**Recommendation.** Correct the “in-force exemplars” line to `zuma_shusky` devices (`shiba`,`husky`).

### F-004 — **LOW** — `init.gps.rc` declares a `class hal` GNSS service whose binary is not shipped

**Evidence.** `init.gps.rc` declares `service gnss_service /vendor/bin/hw/android.hardware.gnss@2.1-service-brcm`
(`class hal`), but `ls /bin/hw` on the shipped `vendor.img` shows **0** occurrences of that binary
(absent on both devices). The HAL binary and its VINTF declaration were excised, but the `.rc`
fragment survived.

**Impact.** `init` will attempt and fail to start a declared service whose executable is missing
(log noise; a dangling declaration). Does not create reachability by itself, but it is the same
partial-by-name excision mechanism that produced F-001.

**Recommendation.** Fold the `init.gps.rc` service block into the `zuma_shusky` location excision
(F-001) so the vendor `.rc` no longer declares dead services.

### F-005 — **INFO** — `SHA256SUMS` does not cover `README-FLASH-DESKTOP.md`

**Evidence.** Each `SHA256SUMS` lists 20 flashed artifacts; `README-FLASH-DESKTOP.md` is present in
the stamp but not listed. No integrity gap for flashed images (README is documentation only).

**Recommendation.** Optional: include the README hash for full-bundle attestation, or document the exclusion.

### F-006 — **INFO** — `radio.img` ships in both bundles (baseband Tier B residual)

**Evidence.** Both stamps carry `radio.img` (112,967,820 B, sha256 `db5a0c81…`, identical in both)
and it is listed in `SHA256SUMS`; the flasher writes `radio` (`FW_IMAGES=(bootloader.img radio.img)`,
`flash-from-remote.sh:153`). Expected per program (partition-layout parity; `GUARDTALK_RADIO_EXCISED=true`).

**Impact.** Baseband Tier B residual, no waiver on record. **Not** a Wave-B regression — recorded for
the residual register. **Cross-reference:** `E-1`; umbrella `baseband_firmware` = **B 13**.

### F-007 — **INFO** — Shipped VINTF manifest declares BT HALs; independent BT-HAL tally is 3, not the umbrella’s 4

**Evidence.** Shipped `vendor.img` `/etc/vintf/manifest.xml` on both devices declares
`android.hardware.bluetooth`, `.bluetooth.finder`, `.bluetooth.ranging` (3 entries); radio = 0,
nfc = 0, gnss/location = 0. Umbrella `A-EXCISE-AIRGAP-MATRIX` §D4 records **4** BT HALs.

**Impact.** Minor cross-reference disagreement on a count only; it does **not** change the BT verdict
(BT is FALSE regardless — F-002). Recorded for the Architect’s reconciliation; the manifest is
radio-free and location-HAL-free as claimed (Tier A at the VINTF layer).

**Recommendation.** Reconcile the 3-vs-4 BT-HAL count in the umbrella when consolidating.

## 5. Location-daemon ruling (explicit — MANDATORY per dispatch)

> **REPRODUCED.** The umbrella’s D3 claim — that `shiba` and `husky` ship a **live, init-started
> Lassen location daemon stack** — **independently reproduces from the shipped `vendor.img`.** Their
> location/GNSS posture is **Tier C (REACHABLE)**, not excised. The other 11/13 stamps carry none of it.

Basis, all from the shipped artifacts (not makefiles): the 3 `class main` services with **no
`disabled`** (auto-start at boot), the present `gpsd`/`lhd`/`scd` executables, `gps.default.so`, the
`/vendor/etc/gnss/*` configs, and the `gpsd_exec`/`lhd_exec`/`scd_exec` SELinux labels.

**Disagreement noted (Law 7).** `A-EXCISE-LOC_AUDIT` `F-001` adjudicated the userspace daemons
**Tier B**, on the basis that the framework AIDL/HIDL GNSS HAL binary is absent. This audit **agrees
the HAL binary is absent** (F-004) but **disagrees with the Tier-B conclusion**: the tier standard
classifies *init-started, reachable* vendor daemons as Tier C regardless of the framework HAL binary.
This is the umbrella’s own §D3 ruling (Architect upheld C); this audit **concurs with D3**.

## 6. Akita-blocklist attack (explicit — the named `T-PORT-SHARED-CORE-FIX` failure mode)

> **DOES NOT REPRODUCE.** `shiba`/`husky` do **not** inherit akita’s blocklist. The shipped
> `zuma_shusky` blocklist carries `blocklist bcmdhd4398` (shusky WiFi) — **not** akita’s
> `bcmdhd4383` — and both devices’ `init.insmod.{shiba,husky}.cfg` `modprobe|bcmdhd4398.ko`,
> so the blocklist token matches the shipped module. `blocklist nitrous` is present.

Contrast proven from shipped `vendor_dlkm.img`:

| Artifact (shipped) | WiFi token | Kernel family (header) |
|---|---|---|
| `shiba-20260923-094055` | **`bcmdhd4398`** | `zuma_shusky (zuma / shusky)` |
| `husky-20260923-095309` | **`bcmdhd4398`** | `zuma_shusky (zuma / shusky)` |
| `akita-20260725-101434` | `bcmdhd4383` | `akita (zuma / akita-kernels)` |
| `komodo-20260915-063833` | `bcmdhd4390` | `komodo (zumapro / caimito-kernels)` |
| `rango-20260802-130756` | `bcmdhd4383.ko`/`bcmdhd4390.ko` | laguna |

Evidence: `.agent-comm/evidence/A-PORT-WAVE-B/vendor_dlkm-blocklist.txt`,
`…/akita-blocklist-attack.txt`. **Result: PASS — variant/blocklist resolution is correct for both.**
(Contrast with `A-EXCISE-LOC-GPS-NAME-COVERAGE_architect-recon.md`: the *location* excision, by
contrast, is name-shaped and **does** miss — F-001.)

## 7. Non-regression (incumbents untouched)

All incumbent `*-latest` symlinks and their target directories are unchanged; `rango-latest` is
**unmoved** (`rango-20260802-130756`, link inode 193110354, mtime 2026-08-02T13:08:30Z — the program
HOLD). No incumbent target or inode was touched by the Wave-B stamps.

| Link | Target | Link inode | Link mtime (UTC) |
|---|---|---|---|
| `latest` (tokay alias) | `tokay-20260725-102506` | 193110379 | 2026-07-25T10:25:28Z |
| `akita-latest` | `akita-20260725-101434` | 193110357 | 2026-07-25T10:14:56Z |
| `komodo-latest` | `komodo-20260915-063833` | 193110380 | 2026-09-15T06:39:03Z |
| `rango-latest` | `rango-20260802-130756` | 193110354 | 2026-08-02T13:08:30Z |

Evidence: `.agent-comm/evidence/A-PORT-WAVE-B/nonregression-latest-links.txt`.
**Cross-reference (not re-derived):** `A-EXCISE-13DEV-NONREGRESSION` — verdict **RESOLVER HOLDS**,
incumbent `*-latest` targets unchanged, `rango-latest` still `rango-20260802-130756`.

## 8. Method

Primary shipped artifacts only (`debugfs` against `releases/desktop-flash/<stamp>/*.img`), plus
`sha256sum -c` on the stamps and `bash -n` on the flasher. No `fastboot`/`adb`/USB; no device/boot
claim. Author-side suites were not trusted; where the umbrella/lane documents were used they are
**cited**, not re-derived. Governance loaded in-process (Gate -1); no aegis-verifier / ask_guardian /
gate_enforcer / Guardian HTTP call.

## 9. Holds & constraints honoured

- Read-only: no product/test/filter/flash/packer/doctrine/queue file modified.
- `.agent-comm/inbox/TO_ARCHITECT.md` **not** modified (parallel lanes); durable event + signal written instead.
- `TASK_QUEUE.md` **not** hand-edited.
- `Gate 5: HUMAN SKIP` — no score invented. Status **REVIEW** — never `APPROVED`.
- `LIVE_FLASH_CLAIMED=false`; DEC-009 on-device HOLD; no boot/flash result claimed for any device.

## 10. Evidence index

Raw evidence: `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/.agent-comm/evidence/A-PORT-WAVE-B/`
(`bundle-filelist.txt`, `shiba-sha256sum-c.txt`, `husky-sha256sum-c.txt`,
`vintf-manifest-provenance.txt`, `vintf-hal-summary.txt`, `vendor_dlkm-blocklist.txt`,
`akita-blocklist-attack.txt`, `system_dlkm-bt-nfc-gki.txt`, `location-daemon-init.gps.rc.txt`,
`location-daemon-13dev-negative-control.txt`, `nonregression-latest-links.txt`,
`flash-script-coverage.txt`, and `SHA256SUMS_EVIDENCE.txt`).

Durable event: `.agent-comm/history/2026-09-24T180500+0400-A-PORT-WAVE-B-audit.md`.
Signal: `.agent-comm/signals/review-A-PORT-WAVE-B.json`.

*Auditor (Panel 5) — independent; no approval authority.*
