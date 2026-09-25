# A-PORT-MATRIX-R2 — Independent Re-Audit (GuardTalkOS Gen 8/9/10 Port Program, QA-present)

| Field | Value |
|---|---|
| task_id | `A-PORT-MATRIX-R2` (P0, `audit_scope: full`) |
| role | AEGIS Independent Deep Tech Auditor (Panel 5) — **READ-ONLY** |
| owner repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id: grapheneos-worktree`) |
| authoritative task path | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` § `AUDIT WAVE DISPATCH` §B3 |
| depends_on | `Q-PORT-MATRIX-PREFLIGHT` ✅ APPROVED (2026-09-22) + `A-PORT-MATRIX` ✅ APPROVED (pre-gate) |
| status | **`REVIEW` only — this panel never sets `APPROVED`** |
| **Gate −1** | **IN-PROCESS** — `.aegis/governance/laws/*.yaml` (24) + `gates/*.yaml` (11) loaded from disk; `governance_loaded=true`. No `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP. |
| **Gate 5** | **`HUMAN SKIP`** — no numeric self-critique score is invented. |
| `LIVE_FLASH_CLAIMED` | **false** — no USB/adb/fastboot, no boot/device/flash result claimed for any device. |
| Date | 2026-09-24 (UTC) |

---

## 0. Why this re-audit exists, and non-claims

`A-PORT-MATRIX` was **approved pre-gate** with its **HIGH-1 = "QA had not yet landed."** QA has now
landed (`Q-PORT-MATRIX-PREFLIGHT` ✅ APPROVED 2026-09-22; 7/7 attacks defeated, negative control exit 1).
This card re-adjudicates the matrix **with QA present**, and — separately — tests whether the **claimed
remediation of the QA escalations** actually happened. `QA-W1`/`QA-W2` were accepted in the approval note
as *"docs corrected"* (`TASK_QUEUE.md:6387`).

**Non-claims.** Read-only. No product/test/filter/flash/packer/doctrine/queue file was edited; no
`TASK_QUEUE.md` hand-edit; `.agent-comm/inbox/TO_ARCHITECT.md` was **not** touched. No build, no
`generate-all`, no USB/adb/fastboot. Every value below carries an exact command or artifact anchor.

**Deliverable adjudicated (frozen hashes):**

| Artifact | sha256 |
|---|---|
| `vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md` | `e71d40060cda8e444eaf2f2ea447a40f149aa0b73a26d2b5b1a2e12da8ef3848` |
| `vendor/guardtalk/docs/KERNEL_MATRIX.md` | `35355da1a72bfe1880df43abae2c057cf44abdd17f8fc789ecd9c5e3f1b2f066` |
| `vendor/guardtalk/docs/EXCISION_MATRIX.md` | `20a82089e4fb94188b1c9cac1a6853ab1d077f64da2f7ad602dd63909744f84b` |
| `vendor/guardtalk/docs/qa/Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md` | `864fb91b7accb6dcf4443c85aa87e9a97d83380a6ce122088210986cc4636002` |
| `vendor/guardtalk/docs/qa/A-PORT-MATRIX_AUDIT.md` | `17417a72f95593f1b309d7e2e17665930ccd96cee55987a873461d43e935ceb2` |
| `vendor/guardtalk/docs/qa/A-EXCISE-AIRGAP-MATRIX_AUDIT.md` | `a835e9c1f0eefb5bb16022b1c88af64920a8b1dd6734c78fcac408f3124c9132` |
| `vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh` | `b8faed31495c18f443f71ac722a2aeff52263e0e2f3f6648cb0062893bc752d3` |
| `vendor/guardtalk/docs/qa/verify_port_kernel_matrix_static.sh` | `651a249149c8f0d44ba952716bc5f33fb59aadc35893026775b75520b92b7c10` |

Laws applied in-process: 0, 2, 4, 6, 7, 9, 10, 11, 12, 16, 19, 20.

---

## 1. Scope item 1 — re-derive the 13-GO / 0-NO-GO result (current tree)

**Ruling: `GENUINE GO` — not a rubber-stamp.** QA has since landed, all 13 devices have now been
**built and stamped**, and the load-bearing matrix fields re-derive exactly.

Re-derived from primary sources (commands in `raw_evidence.txt`):

```
$ for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    cfgOK $d  model=…  soc=platform/{zuma|zumapro|laguna}, idx=N
  done
13/13 cfg OK; PRODUCT_MODEL + SoC + build-index counts match the matrix §2 exactly
(shiba 58, husky 58, akita 46, tokay 47, caiman 46, komodo 46, comet 45, tegu 29,
 stallion 5, frankel 29, blazer 29, mustang 29, rango 24)
```

- **Every one of the 13 now has a `vendor/google_devices/<dev>/` module and a `*-latest` stamp**
  (`vendor/google_devices/` = 13 entries; `releases/desktop-flash/` carries `*-latest` for all 13
  plus `komodo-debug-latest`). At preflight time only 4 existed — the GO has been *consummated*, not
  merely asserted.
- **`stallion` is built and stamped:** `releases/desktop-flash/stallion-20260923-100618` +
  `stallion-latest -> stallion-20260923-100618`.
- **QA evidence present and non-vacuous:** `Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md` records 7/7 attacks
  defended and a **negative control exit 1** on a corrupted copy, which proves the harness is not
  vacuous. I re-ran the QA harness myself (§7).
- **Upstream spot-check (network live):** `https://releases.grapheneos.org/stallion-stable` → HTTP 200;
  `stallion-bd6a.251031.001.a4-factory-7420a527.zip` → HTTP 200.

**Caveat (disclosure, not a NO-GO):** the preflight's own §14 invariant
(`PORT_MATRIX_GEN8910_PREFLIGHT.md:390` — *"5 symlinks unchanged"*) and §4.2 *"absent on this host"* are
now **superseded by the build program**: 3 of the 4 `trunk_staging` absences were legitimately closed
(§3) and the 9 new devices were stamped. This is expected program progression, but the doc reads as if
the remedy had not been applied.

---

## 2. Scope item 2 — were the QA escalations `QA-W1` / `QA-W2` / `QI-1` applied?

**Ruling: `NOT APPLIED` to the deliverable. The approval note's "docs corrected" claim is not
substantiated by the artifacts.**

The decisive test is that QA recorded the exact sha256 of the deliverable it tested:

> `Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md` §8: *"the untouched `sha256 =
> e71d40060cda8e444eaf2f2ea447a40f149aa0b73a26d2b5b1a2e12da8ef3848` of the deliverable"*.

My re-read of the **current** file returns the **identical** hash. The matrix has **not changed since QA
tested it**; the escalations were therefore not applied to it:

```
$ sha256sum vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md
e71d40060cda8e444eaf2f2ea447a40f149aa0b73a26d2b5b1a2e12da8ef3848   ← byte-identical to QA's pre-remediation hash
$ grep -ncE 'QA-W|QI-1|16-QPR1|asymmetry' vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md
0
$ grep -nc 'mutable' vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md
0
```

`KERNEL_MATRIX.md` (edited 2026-09-21T15:34Z, *after* QA) also contains **no** `QA-W1`/`16-QPR1`/
`asymmetry` token. The only place the 16-QPR1 lag is named is the **Architect's** `TASK_QUEUE.md` §9.2
(`:6748`) and `stallion.yml` (source), not the audited deliverable.

| Escalation | Claimed | Verified in artifact |
|---|---|---|
| `QA-W1` (stallion understates 16-QPR1 lag) | accepted → docs corrected | **NO** — deliverable names only "5-entry index / stale pin (oldest)" (`PORT_MATRIX…:131`, `:216`); 0 hits for `16-QPR1` |
| `QA-W2` (`build_id` pin asymmetry undocumented) | accepted → docs corrected | **NO** — 0 hits for `asymmetry`; §7 lists resolved ids but never states that only 3 devices pin |
| `QI-1` (show-status present-set is mutable during download) | accepted → docs corrected | **NO** — 0 hits for `mutable` |

Both QA warnings still fire on a fresh harness run (§7), i.e. the QA suite itself still reports the
understatements — an independent corroboration that the docs were not corrected.

---

## 3. Scope item 3 — were the absorbed NO-GO triggers legitimate?

**Ruling: `LEGITIMATE ABSORPTION (with a disclosed semantic caveat)` — not excused away.**

The two triggers are `shusky` (`shiba`/`husky`) and `comet`/`tegu`: under `trunk_staging`,
`RELEASE_KERNEL_<DEV>_DIR` **is defined** and resolves to `device/google/<fam>-kernels/6.1/trunk-14096387`,
but the directory is **absent**. `KERNEL_MATRIX.md` §1 de-conflates exactly this from a true NO-GO:

- **UNRESOLVED** (variable empty — cannot be fixed on disk) ⇒ **NO-GO**.
- **ABSENT_DIR** (variable defined, dir missing) ⇒ **LAYER prerequisite, not NO-GO**
  (`KERNEL_MATRIX.md:91`).

Judged against primary evidence, the absorption is defensible because: (a) the *variable resolves*;
(b) the complete `grapheneos` tree is on disk for every family; (c) the identical gap was already closed
at LAYER for `akita`/`caimito`/`laguna` (symlinks dated 2026-07-24 / 2026-09-14 / 2026-07-25); (d) the
remedy is a **single-component relative symlink**, reversible by `rm` (`KERNEL_MATRIX.md:180-203`).

**The operator applied the remedy on 2026-09-22T15:11Z** — independently observed:

```
device/google/shusky-kernels/6.1/trunk-14096387 -> grapheneos  (mtime 2026-09-22 15:11)
device/google/comet-kernels/6.1/trunk-14096387  -> grapheneos  (mtime 2026-09-22 15:11)
device/google/tegu-kernels/6.1/trunk-14096387   -> grapheneos  (mtime 2026-09-22 15:11)
```

**Disclosed caveat (honest, not hidden):** the pin **aliases the `cur` kernel** — a `trunk_staging`
build then compiles the `grapheneos` (cur) modules, **not** a genuine `trunk-<buildid>` prebuilt
(`KERNEL_MATRIX.md:193`). That is the in-force program precedent, and it is stated. I concur: this is a
legitimate, documented, reversible LAYER absorption. Its direct consequence is that the two author
suites that assert the absences now go RED (§7) — staleness, not defect.

---

## 4. Scope item 4 — `stallion` conditional GO: honestly disclosed?

**Ruling: `PARTIALLY DISCLOSED`.** Fingerprint-thin-index and stale-pin facts are honest; the **16-QPR1
platform lag is material and understated** in the deliverable.

Honest and verified:

- `stallion` is a **Pixel 10a on `zumapro`** (not `laguna`) and has only **5** main-channel entries
  (`BD6A.251031.001.A4`, `CP1A.260305.018`, `CP1A.260405.005`, `CP1A.260505.005`, `CP1A.260505.005.A1`).
- The GO engages the "5-entry index / stale pin (oldest)" risk (`PORT_MATRIX…:131`, `:216`).
- **No `RELEASE_KERNEL_STALLION_DIR.textproto` in any channel** — independently confirmed
  (`ls build/release/flag_values/*/RELEASE_KERNEL_STALLION_DIR.textproto` → *No such file or directory*);
  the literal kernel path is by design.
- Now **built and stamped**: `stallion-20260923-100618` + `stallion-latest`; its README honestly records
  `FLASH_READY=false`, `userdebug`, `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`.

**The gap:** the pin `BD6A.251031.001.A4` is a **16-QPR1 image** (`stallion.yml` comment: *"BD6A.251031.001.A4
is a 16 QPR1 image, so Multiuser isn't in stock"*; 9 × `sdk_full = 36.0` exclusions; newest indexed build
`CP1A.260505.005.A1` is 4 images newer). The deliverable says only "stale pin (oldest)" and **never names
the 16-QPR1 platform lag** — precisely `QA-W1`, still open. → **F-004.**

---

## 5. Scope item 5 — `build_id` pin asymmetry: justified per device?

**Ruling: `PARTIALLY JUSTIFIED; asymmetry itself undocumented in the deliverable`.**

Independently re-derived pins (`grep -m1 '^  build_id:' vendor/adevtool/config/device/<dev>.yml`):

| Device | `build_id` pin | Inline rationale in source | Verdict |
|---|---|---|---|
| `rango` | `CP1A.260505.005` | **Yes** — *"Match proven on-device boot (deepspace-17.1 / stock CP1A prove-boot)"* | **Justified** |
| `stallion` | `BD6A.251031.001.A4` | **Yes** — 16-QPR1 / Multiuser workaround comment | **Justified** (same reason as F-004) |
| `tegu` | `BP4A.260205.001` | **No** — bare pin; 7 other devices resolve to the same id **without** an explicit pin | **Weakly justified / undocumented** |
| other 10 | *(unpinned)* | resolve via build-index | consistent |

The asymmetry is **real** (`{tegu,stallion,rango}` pin; the other 10 do not) and the deliverable never
states it (`QA-W2`, still open). `tegu`'s pin carries no stated reason and is not the newest of its 29
entries — it aligns `tegu` with the Gen-8/9 `BP4A.260205.001` group, which is plausible but unrecorded.
→ **F-005.**

---

## 6. Scope item 6 — Gen 6 (`gs101`) / Gen 7 (`gs201`) remain an audited absence

**Ruling: `PASS — AUDITED ABSENCE, no leakage.`**

```
$ ls -d device/google/gs101* device/google/gs201*        → 0 hits
$ ls releases/desktop-flash/ | grep -iE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro'  → NONE
$ ls vendor/google_devices/ | grep …gen7/6 codenames      → NONE
$ ls vendor/guardtalk/device/ | grep …gen7/6 codenames    → NONE
$ grep -rniE '<gen6/7 codenames>' vendor/guardtalk/web-installer/src/ \
      vendor/guardtalk/scripts/pack-webinstall-channel.sh → NONE
```

- **No wave, no GO/NO-GO verdict, no advertise entry, no stamp** for any Gen 6/7 codename.
- Advertise surface unchanged: `ALLOWED_PRODUCTS = ["tokay","akita","komodo","rango"]`
  (`web-installer/src/types.ts:3`); packer `ADVERTISED_DEVICES=(tokay akita komodo rango)`
  (`scripts/pack-webinstall-channel.sh:27`).
- Corroborated by `A-EXCISE-AIRGAP-MATRIX_AUDIT.md` §9 (`AUDITED_ABSENCE`) and
  `EXCISION_LEDGER.md` §1 (`gen6_gen7_audited_absence.status = AUDITED_ABSENCE`).
- Gen 6/7 **kernel trees** exist on disk (`raviole/bluejay/pantah/felix/lynx/tangorpro-kernels`) — that
  is upstream tooling content, not a wave/advertise surface.

**Residual (pre-existing, not program-introduced):** `vendor/guardtalk/scripts/sign-build.sh:198`'s
device allowlist still includes `felix|tangorpro|lynx|cheetah|panther|bluejay|raven|oriole` (and `:454`
special-cases `tangorpro`). It will accept a Gen 6/7 device name if invoked directly. This is the prior
audit's `L-6`, still open. → **F-009.**

---

## 7. Suite re-run — staleness vs product defect

I re-ran all three author/QA suites; raw transcripts under `.agent-comm/evidence/A-PORT-MATRIX-R2/`.

| Suite | Exit | Result |
|---|:--:|---|
| `verify_port_matrix_preflight_static.sh` | **1** | `RESULT: FAIL — at least one attack succeeded; 109 passed, 2 warnings` |
| `verify_port_kernel_matrix_static.sh` | **1** | `PASS_COUNT=203 HOLD_COUNT=3 FAIL=1 / ALL STATIC CHECKS FAILED` |
| `verify_port_excision_matrix_static.sh` | **0** | `PASS_COUNT=128 HOLD_COUNT=0 FAIL=0 / ALL STATIC CHECKS PASSED` |

**Failure cause (exact):**

```
preflight:  FAIL: vectorA: {shiba,husky,comet,tegu} trunk_staging dir unexpectedly PRESENT
            (device/google/{shusky,comet,tegu}-kernels/6.1/trunk-14096387) — re-derive the 4-absence claim
kernel:     FAIL: trunk_staging ABSENT_DIR set is [], expected [comet husky shiba tegu]
            FAIL: device/google/{shusky,comet,tegu}-kernels/6.1/trunk-14096387 exists —
                  this card documents the LAYER remedy, it does not apply it (KERNEL_MATRIX.md §4)
```

**Ruling: `POST-LAYER SUITE STALENESS — NOT a product defect.`**

Both suites encode the **pre-remedy invariant** (`ABSENT_DIR set == {shiba,husky,comet,tegu}`; the four
dirs "must be ABSENT because this card documents the remedy, it does not apply it"). The operator
**legitimately applied** the remedy on 2026-09-22T15:11Z (§3), which the product documentation itself
sanctions and which the `verify_port_excision_matrix_static.sh` suite (unaffected, 128/0) does not
contradict. The remedy does **not** disable any excision, enter the build, or alter a shipped artifact;
it only provisions a resolvable kernel path. Consequently both suites are **stale re-baselining debt**,
not a regression in the shipped product.

Minor harness note (recorded, not a finding): `verify_port_kernel_matrix_static.sh` prints **6** `FAIL:`
lines while its summary reports `FAIL=1` — the aggregator counts case-groups, not assertion lines. The
mismatch is cosmetic but makes the summary understate the failure surface.

Both suites still **WARN** on `QA-W1`/`QA-W2` (`deliverable does NOT state the pin asymmetry`;
`deliverable UNDERSTATES stallion … never names the 16 QPR1 image`), independently confirming §2.

---

## 8. MANDATORY cross-reference — matrix vs the EXCISE verdict (`DEC-EXCISE-AIRGAP-001`)

The umbrella `A-EXCISE-AIRGAP-MATRIX` returned **FALSE** on the literal airgap claim: **36 residuals
(8 CRITICAL)** — unblocklisted BT/NFC GKI modules 13/13 (`C-B1`); `nitrous` unblocked on the 4 laguna
hybrids (`C-B2`); live `gpsd`/`lhd`/`scd` `class main` location daemons on `shiba`/`husky` (`C-L1`);
modem transport `cpif`/`cpif_page`/`shm_ipc` loaded 10/13 (`C-R1`); baseband `radio.img` shipped and the
flasher writes `radio` 13/13 (`H-R1`); `dmd.xml` VINTF fragment defeats `no_radio` 13/13 (`H-R2`);
`GuardTalkCheckin` telemetry 10/13 (`C-S1`).

**Disagreement cells (8 surfaces).** `EXCISION_MATRIX.md` is the material offender; `PORT_MATRIX` has no
direct excision cell but inherits the premise through its wave-gate.

| # | Cell (file:line) | Matrix says | EXCISE verdict says | Severity |
|--|---|---|---|---|
| D-01 | `EXCISION_MATRIX.md:69` | `shannon` — **"full modem/telephony excision"** | radio = **FALSE**; modem kernel transport Tier C 10/13; baseband 13/13 (`H-R1`); `dmd.xml` 13/13 (`H-R2`) | **HIGH** |
| D-02 | `EXCISION_MATRIX.md:239` & §2 radio column (`:56-63`) | `RADIO_SET := shannon` "for all 13" | **0/13 Tier A** on radio; per-device worst tier **C 9/13, B 4/13** (`A-EXCISE-RADIO`) | HIGH |
| D-03 | `EXCISION_MATRIX.md:62` | `laguna_muzel` canonical blocklist (incl. `blocklist nitrous`) applies | factory `vendor_dlkm` in the `frankel`/`blazer`/`mustang` hybrids **defeats** the blocklist → `nitrous` Tier C (`C-B2`, `H-X1`) | MEDIUM |
| D-04 | `EXCISION_MATRIX.md:63` | `laguna_rango` canonical blocklist applies | `rango-latest` is a hybrid → `nitrous` Tier C (`C-B2`, `H-X1`) | MEDIUM |
| D-05 | `EXCISION_MATRIX.md:290` | `BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1` "**unchanged**" | flag **absent on 4/13** laguna stamps (`D2`, `M-R3`) | MEDIUM |
| D-06 | `EXCISION_MATRIX.md:56-63` (blocklist columns) | per-variant blocklists apply uniformly | BT/NFC GKI modules in `system_dlkm/modules.load` with **0 matching blocklist entries 13/13** (`C-B1`) | MEDIUM |
| D-07 | `PORT_MATRIX_GEN8910_PREFLIGHT.md:344` | Wave-A entry prerequisite: **`T-PORT-EXCISION-MATRIX` `APPROVED`** (treated as settled) | excision is **not** clean; the umbrella registers 8 CRITICALs — the GO is not conditioned on the excision claim, but the wave plan implies it is satisfied | MEDIUM |
| D-08 | `releases/desktop-flash/stallion-20260923-100618/README-FLASH-DESKTOP.md:10` | *"VINTF excised manifest (resolved in the built image): `vendor_manifest_no_radio_stallion.xml`"* | `dmd.xml` fragment re-declares `vendor.samsung_slsi.telephony.hardware.oemservice` (`H-R2`) | **HIGH** |

**D-08 independently reproduced by me** (not accepted from EXCISE): `debugfs` on the shipped
`stallion-20260923-100618/vendor.img` shows `/etc/vintf/manifest/dmd.xml` (328 B) declaring
`vendor.samsung_slsi.telephony.hardware.oemservice` with `IOemService/dm0`, `IOemService/dm1` — three
telephony hits. So the stamp's "no_radio" claim is **false as written** on the very stamp it describes.
Evidence: `.agent-comm/evidence/A-PORT-MATRIX-R2/stallion_dmd_vintf_fragment.xml`
(sha256 `9909ea142376d3763ca11269e789862b86570d316a5f99bd58a4518809d42014`).

**Net:** the matrices **do** imply a clean excision in `EXCISION_MATRIX.md` (the absolute *"full
modem/telephony excision"* and the uniform-blocklist columns) and in the shipped `stallion` README.
They must be re-worded to EXCISE's `FALSE` / `TRUE-WITH-DORMANT-RESIDUALS` posture before any wave
build cites them as a clean basis.

---

## 9. Findings

### HIGH

**F-001 — The approval note's "docs corrected" claim is not substantiated by the artifacts.**
- **Evidence:** `TASK_QUEUE.md:6387` asserts *"Escalations QA-W1/W2/I1 accepted → docs corrected."*
  The deliverable `PORT_MATRIX_GEN8910_PREFLIGHT.md` still hashes
  `e71d40060cda8e444eaf2f2ea447a40f149aa0b73a26d2b5b1a2e12da8ef3848` — **byte-identical** to the
  "untouched" hash QA recorded (`Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md` §8). `KERNEL_MATRIX.md`
  (`35355da1…`) carries no `QA-W1`/`16-QPR1`/`asymmetry` token either. `grep -cE 'QA-W|QI-1|16-QPR1|asymmetry'`
  on the deliverable = **0**.
- **Impact:** the specific remediation this re-audit was commissioned to verify did not occur; QA-W1/W2/I1
  remain open while the queue records them closed. Claim-integrity (Law 1/10).
- **Recommendation (Architect):** re-open `QA-W1`/`QA-W2`/`QI-1`, or record an explicit waiver; correct
  the approval note's "docs corrected" wording.

**F-002 — Shipped `stallion` stamp advertises a `no_radio` VINTF manifest that a `dmd.xml` fragment defeats.**
- **Evidence:** `releases/desktop-flash/stallion-20260923-100618/README-FLASH-DESKTOP.md:10` (sha256
  `f2b9e01a217226c00d92e6c5c60cf780118d5b28d8df69b1f68a8273fe1bc0a5`); independent `debugfs` read of
  `/etc/vintf/manifest/dmd.xml` on the same `vendor.img` shows 3 telephony `oemservice` fqnames.
  Matches `A-EXCISE-AIRGAP-MATRIX_AUDIT.md` `H-R2` + `D-08` above.
- **Impact:** a shipped artifact's own manifest claim is false; a reader may believe radio is VINTF-removed
  13/13 while the runtime manifest still advertises the modem HAL. This "must not imply a clean excision."
- **Recommendation:** drop the `dmd` fragment from packaged `vintf_fragments` (or empty it) and re-stamp;
  correct the README claim until then.

### MEDIUM

**F-003 — `EXCISION_MATRIX.md` implies a clean modem/telephony excision that EXCISE falsified.**
- **Evidence:** `EXCISION_MATRIX.md:69` *"`shannon` (full modem/telephony excision)"*; `:239`
  `RADIO_SET := shannon` for all 13; `:290` `androidboot.radio.disabled=1` "unchanged". EXCISE:
  radio **FALSE**; `cpif` Tier C 10/13; baseband 13/13; `dmd` 13/13; flag absent 4/13.
- **Impact:** the excision foundation that gates every wave (`PORT_MATRIX…:344`) reads as Tier-A-clean.
- **Recommendation:** scope the text to the *variant-selection* mechanism and cite the EXCISE residual
  register; never use "full … excision".

**F-004 — `stallion` 16-QPR1 platform lag remains understated (`QA-W1` open).**
- **Evidence:** deliverable `:131`/`:216` engage only "5-entry index / stale pin (oldest)"; `grep -c '16-QPR1'`
  on the deliverable = **0**; `stallion.yml` documents the 16-QPR1 gap + Multiuser workaround + 9×
  `sdk_full = 36.0` exclusions; `TASK_QUEUE.md:6748` names it only in the Architect's own section.
- **Impact:** the highest-risk device's GO rationale understates the divergence driving the risk.
- **Recommendation:** name the 16-QPR1 lag in the deliverable and carry it into `T-PORT-STALLION-PREFLIGHT`/`-FLASH`.

**F-005 — `build_id` pin asymmetry undocumented; `tegu` pin lacks a stated rationale (`QA-W2` open).**
- **Evidence:** pins = `{tegu BP4A.260205.001, stallion BD6A.251031.001.A4, rango CP1A.260505.005}`
  (`vendor/adevtool/config/device/*.yml`); deliverable has 0 hits for `asymmetry`; `rango`/`stallion`
  carry inline reasons, `tegu` does not.
- **Impact:** a reader cannot tell whether the asymmetry is deliberate or accidental; auditability gap.
- **Recommendation:** add a one-line per-device pin rationale to the deliverable; justify or drop `tegu`'s pin.

### LOW

**F-006 — Both author/QA suites go RED purely from the operator's legitimate LAYER symlinks.**
- **Evidence:** §7 exact commands/exit codes. Suites assert `ABSENT_DIR == {shiba,husky,comet,tegu}`;
  the dirs now exist via `trunk-14096387 -> grapheneos` (mtime 2026-09-22 15:11).
- **Impact:** two items are recorded RED though no product defect exists (matches `A-EXCISE` `M-X1`/`E-11`).
- **Recommendation:** re-baseline both suites (`T-EXCISE-GATE-REVALIDATION`); parameterise the expected
  absence set, or add a "post-remedy" mode. No product change required.

**F-007 — `KERNEL_MATRIX.md` / `PORT_MATRIX_GEN8910_PREFLIGHT.md` are stale vs the applied remedy and stamps.**
- **Evidence:** `KERNEL_MATRIX.md:113-120` still labels `shiba/husky/comet/tegu` `ABSENT_DIR` and
  `:207` says *"nothing pinned"*; `PORT_MATRIX…:390` says *"5 symlinks unchanged"* while 13 `*-latest`
  stamps now exist. Documentation drift only.
- **Impact:** operating references contradict the live tree; drives F-006.
- **Recommendation:** annotate both docs with the 2026-09-22 remedy application and the stamp roster.

**F-008 — `QI-1` (mutable `show-status` present-set) undocumented in the deliverable.**
- **Evidence:** `grep -c 'mutable' PORT_MATRIX…` = 0; `show-status` present-set moved 4 → 5 → 13 during
  the program (`raw_evidence.txt`).
- **Impact:** any future consumer asserting a fixed present-set will be flaky.
- **Recommendation:** record the present-set as mutable in §7/§10.

**F-009 — Pre-existing `sign-build.sh` allowlist admits Gen 6/7 codenames.**
- **Evidence:** `vendor/guardtalk/scripts/sign-build.sh:198` (allowlist) and `:454` (`tangorpro`).
  Not modified by the port program; prior audit `L-6`, still open.
- **Impact:** latent scope hole if the script is invoked directly with a Gen 6/7 device.
- **Recommendation (Architect):** decide whether to narrow the allowlist to the 13 in-scope devices.

---

## 10. Severity counts and the six item rulings

| Severity | Count | IDs |
|---|:--:|---|
| CRITICAL | **0** | — |
| HIGH | **2** | F-001, F-002 |
| MEDIUM | **3** | F-003, F-004, F-005 |
| LOW | **4** | F-006, F-007, F-008, F-009 |
| **Total** | **9** | |

| # | Scope item | Ruling |
|--:|---|---|
| 1 | Re-derive 13-GO / 0-NO-GO | **GENUINE GO** — re-derived 13/13; QA present + non-vacuous; all 13 now stamped. |
| 2 | QA escalations `QA-W1`/`QA-W2`/`QI-1` applied? | **NOT APPLIED** — deliverable byte-identical to QA's pre-remediation hash; "docs corrected" unsubstantiated (F-001). |
| 3 | Absorbed `shusky`/`comet`/`tegu` NO-GO triggers | **LEGITIMATE** — `ABSENT_DIR` ≠ `UNRESOLVED`; reversible LAYER symlink applied 2026-09-22; `cur`-alias caveat disclosed. |
| 4 | `stallion` conditional GO honesty | **PARTIALLY DISCLOSED** — thin-index/stale-pin honest; 16-QPR1 lag understated (F-004); now built/stamped `stallion-20260923-100618`. |
| 5 | `build_id` pin asymmetry justified | **PARTIALLY** — `rango`/`stallion` justified; `tegu` undocumented; asymmetry unstated in deliverable (F-005). |
| 6 | Gen 6/7 audited absence | **PASS** — no dir/wave/stamp/advertise leakage; residual `sign-build.sh` allowlist is pre-existing (F-009). |

**Matrix-vs-EXCISE disagreement count: 8 surfaces** (D-01…D-08; 6 in `EXCISION_MATRIX.md`, 1 in
`PORT_MATRIX_GEN8910_PREFLIGHT.md` via its wave-gate, 1 in the shipped `stallion` stamp README).

**Suite ruling:** both RED suites = **post-LAYER suite staleness, NOT a product defect** (§7).

---

## 11. What I could NOT verify (explicit gaps)

- **No build / no `generate-all` / no hardware.** I verified stamp *existence*, `SHA256SUMS` presence,
  and (for `stallion`) one VINTF fragment. I did **not** boot, flash, or run `adb`/`fastboot`, and make
  no boot-green claim for any device.
- **Full-stamp EXCISE re-derivation.** I did not re-unpack all 13 stamps; the EXCISE verdict is cited and
  I reproduced only `D-08` (`dmd.xml` on `stallion`) independently. The remaining disagreement cells cite
  `A-EXCISE-AIRGAP-MATRIX_AUDIT.md` + `.agent-comm/evidence/A-EXCISE-AIRGAP-MATRIX/`.
- **`tegu` pin intent.** No commit message / card text states why `tegu` pins; I inferred the grouping.
- **Git provenance.** The root is not a git repository (`.repo`-managed); "unchanged" is established by
  content rematch (sha256), not `git status`.

## 12. Artifacts written (this card)

- `vendor/guardtalk/docs/qa/A-PORT-MATRIX-R2_AUDIT.md` — **NEW** (this report).
- `.agent-comm/evidence/A-PORT-MATRIX-R2/` — `raw_evidence.txt`,
  `rerun_port_matrix_preflight_static.out`, `rerun_port_kernel_matrix_static.out`,
  `rerun_port_excision_matrix_static.out`, `stallion_dmd_vintf_fragment.xml`.
- `.agent-comm/history/2026-09-24T180500+0400-A-PORT-MATRIX-R2-audit.md` — durable event.
- `.agent-comm/signals/review-A-PORT-MATRIX-R2.json` — signal.

No product/test/filter/flash/packer/doctrine/queue file, no `TASK_QUEUE.md`, and no
`.agent-comm/inbox/TO_ARCHITECT.md` was modified. No commit.

---

*Produced by AEGIS Independent Deep Tech Auditor (Panel 5) for `A-PORT-MATRIX-R2`. Status `REVIEW`
only — `APPROVED` is the Architect's verdict, never this panel's. `Gate 5: HUMAN SKIP`.
`LIVE_FLASH_CLAIMED=false`. No boot/flash/device claim.*
