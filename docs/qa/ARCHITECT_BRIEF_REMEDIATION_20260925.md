# AEGIS Architect Brief — Remediation Dispatch + Mandatory Build/Boot-Safety Validation

**Brief ID:** `BRIEF-REMEDIATE-20260925`
**Issued:** 2026-09-25T11:46+04:00 · **Issuer:** Human Operator (Law 0) · **Executor:** Architect (Agent 1)
**Source of truth:** `vendor/guardtalk/docs/qa/AUDIT_RESULT_CONSOLIDATED_20260925.md`
**Programme:** `DEC-EXCISE-AIRGAP-001` remediation + validation

---

## HOW TO USE THIS BRIEF

Run `/aegis-architect`, then hand the Architect this file. It is a **dispatch request**, not a report.

**Dispatch mode:** `inbox_manual` (per `.aegis-config.json`) → dispatch each task via Cursor
**Task → `generalPurpose`** carrying the AEGIS Dispatch Packet.

**Canonical packet template:** `.aegis/templates/DISPATCH_PACKET.md`.
⚠ `docs/adr/DISPATCH_PACKET.md` **does not exist** in this worktree — do not reference it.

The AEGIS-named subagent types (`aegis-backend-engineer` / `aegis-frontend-engineer` /
`aegis-qa-engineer` / `aegis-auditor`) are **not registered** in this environment; `generalPurpose` is the
transport (standing operator decision `fire_general`, Program §8).

---

# PART A — MANDATORY VALIDATION CONTRACT (read before PART C)

**Operator directive, verbatim intent:** *"in every big change it must validate the build and that the kernel
will not panic."* This is a **hard gate**, not a recommendation.

## A1. What is a "big change" — blast-radius classes

| Class | Definition | Examples in this programme | Required gate |
|---|---|---|---|
| **BIG** | Touches boot viability for **any** device, or touches **shared-core** files included by >1 product | `feature-excised/*.mk` · `excision-variant{,-select}.mk` · any `vendor_dlkm` / `system_dlkm` blocklist · `modules.load` / `init.insmod.*.cfg` · VINTF manifests + fragments · `apex-bcp-excised.mk` / `devicelock-apex-excised.mk` · `BoardConfig-excised-late.mk` / `product-config-late.mk` include / `guardtalk-radio-excised.mk` include · init `.rc` service definitions · SELinux contexts · bootloader / radio / vbmeta / pvmfw / dtbo composition | **G1–G8 (all)** |
| **SMALL** | Docs, READMEs, comments, claim-surface wording, queue files | `F-EXCISE-CLAIM-HONESTY`, `T-EXCISE-MATRIX-DOC-REMEDIATE`, stamp READMEs | **G1 only if a stamp is re-issued**; otherwise no build gate, but the honesty check applies |

**A BIG change carries a 13-device blast radius whenever it is shared-core.** A shared-core excision edit
cannot be validated on one device. **All 13 products must build.**

## A2. The eight gates

> **Honesty constraint that governs all of this.**
> "The kernel will not panic" **cannot be proven on this host — there is no hardware.**
> Therefore no card may *claim* boot safety. The provable obligations are:
> **(G1)** the build is proven · **(G2–G7)** a static boot-safety analysis is green and fail-closed ·
> **(G8)** the runtime claim is explicitly HOLD with a ready-to-run procedure.
>
> A card that reports "boot-safe" or "will not panic" **without a real device run** is an **honesty
> violation** and must be **rejected**. This is precisely the overstatement class the audit found 14
> instances of (7 outright false).

| Gate | Obligation | How it is proven | Exists today? |
|---|---|---|---|
| **G1 Build** | `lunch <dev>-trunk_staging-userdebug` **exit 0**; `m dist` → **`BUILD_EXIT=0`**; stamp produced; `sha256sum -c SHA256SUMS` **exit 0** | `.agent-comm/tools/gt-stamp-device.sh` pattern; **serialise on `flock out/.guardtalk-build.lock`** (all products share `out/`) | ✅ tooling exists |
| **G2 Module dependency closure** | For every module in every `modules.load` (`system_dlkm`, `vendor_dlkm`, `vendor_boot` / `vendor_kernel_boot` ramdisk), every dependency declared in `modules.dep` is **present and also loaded**. No newly-blocklisted module is a dependency of a loaded one. No load-order inversion (note the documented two-phase ordering for `bcmdhd4390`) | **new harness** — `modules.dep` + `modules.load` + `modules.blocklist` set algebra, per device, fail-closed | ❌ **DOES NOT EXIST** |
| **G3 Boot-critical allowlist** | An explicit allowlist of modules required before userspace (storage/UFS, display, regulator, pinctrl, PCIe, sched/thermal) must be **present and loadable on every device**. Gate fails if any is blocklisted, removed, or absent | **new harness** + a reviewed, versioned allowlist file | ❌ **DOES NOT EXIST** |
| **G4 APEX / BCP / SSR integrity** | The `apexd` **bootstrap** APEX set is unchanged unless the framework-side patch is present; any card touching APEX/BCP must pass the structural check `verify_remediate_b2_apex_host.sh`. **`E-20` (`devicelock-apex-excised.mk` strips SSR/BCP system-server jars — Zygote boot-loop class) must be resolved or explicitly waived BEFORE any such card is approved** | existing suite + **resolve `E-20`** | ⚠ partial — suite exists and currently **FAILS** |
| **G5 VINTF coherence** | Every HAL declared in the **runtime-merged** manifest (main `/etc/vintf/manifest.xml` **plus** every `/vendor/etc/vintf/manifest/*` fragment, per `VintfObject.cpp:282-328`) has a shipping service binary, and every shipping HAL service has a declaration. No unintended ref added or removed | **new harness**; `check_vintf`-equivalent | ❌ **DOES NOT EXIST** |
| **G6 init / sepolicy coherence** | Every service in an init `.rc` has its binary present (or is covered by a documented excision); every removed service has **no** dependent `wait_for` / `requires`; SELinux labels match the shipped service set. *(Wave B `F-004` found a `class hal` gnss service whose binary is not shipped → this check is needed now, not theoretically.)* | **new harness** | ❌ **DOES NOT EXIST** |
| **G7 Boot-chain diff** | `bootloader` / `radio` / `vbmeta*` / `pvmfw` / `dtbo` proven **unchanged** vs the last known composition, or the change flagged as **unverified boot-chain** (ABL-reject class — documented: fullgt laguna rejected `AB 11311112`) | `sha256sum` comparison against the previous stamp | ✅ method exists, not enforced |
| **G8 Runtime HOLD** | `BOOT_VERIFIED=false` unless actually run on hardware. The runtime procedure must be documented and ready to execute the moment hardware is attached | record `BOOT_VERIFIED=false`, `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false`; document the recovery path (`fastboot fetch metadata` pattern) | ✅ holds exist |

## A3. The gate is a PREREQUISITE, not a follow-up

`G2`, `G3`, `G5`, `G6` **do not exist in this repository.** Requiring them without building them would make
every remediation card unverifiable and would invite exactly the kind of "verified" claim the audit condemned.
Therefore:

> **`T-EXCISE-BOOT-SAFETY-GATE` is a hard prerequisite. It must be created, dispatched, and APPROVED
> BEFORE any BIG-class remediation card may be approved.** Remediation cards may be *dispatched* to prepare
> work, but their `REVIEW` acceptance requires the gate to exist and be green.

## A4. Evidence contract — every BIG-class card

Each BIG-class card's `REVIEW` submission must contain, **per device (13 rows, never one blanket line)**:

```
G1 build:        lunch=<exit>  m=<BUILD_EXIT>  stamp=<dir>  sha256sum -c=<exit>
G2 dep-closure:  unloaded-deps=<n>  load-order-inversions=<n>      (must be 0)
G3 allowlist:    boot-critical-missing=<list>                      (must be empty)
G4 apex/bcp:     bcp-structural=<PASS|FAIL|n/a>  E-20=<resolved|waived-why>
G5 vintf:        undeclared-services=<n>  unbacked-decls=<n>       (must be 0)
G6 init/sepol:   orphan-services=<n>  broken-wait_for=<n>          (must be 0)
G7 boot-chain:   bootloader/radio/vbmeta/pvmfw/dtbo = unchanged | CHANGED(flagged)
G8 runtime:      BOOT_VERIFIED=false (no hardware)  procedure=documented@<path>
```

**Any non-zero / non-empty `G2`–`G6` value is a FAIL that blocks `REVIEW` acceptance.**
**`G8` is always HOLD.** "There is no hardware" is **never** a reason to skip `G1`–`G7` — it is the reason
`G8` exists.

---

# PART B — Scope

Source of truth: **`vendor/guardtalk/docs/qa/AUDIT_RESULT_CONSOLIDATED_20260925.md`**, backed by the 11 lane
reports in `vendor/guardtalk/docs/qa/` and the QA evidence (`Q-EXCISE-LEDGER`, `Q-EXCISE-13DEV-MATRIX`).

**Verdict on record: the airgap claim is `FALSE` per service and per device (all 13).** Best honest reading
`TRUE-WITH-DORMANT-RESIDUALS`; **never `TRUE`**.
**36 residuals · 8 CRITICAL · 17-item operator waiver list.**
Gen 6 (`gs101`) / Gen 7 (`gs201`) = audited absence.

The 13 port builds are **intact and non-regressed** (13/13 stamped, `sha256sum -c` valid, resolver holds, no
silent no-op) but **not excised**.

This brief commissions the remediation programme **and** the validation machinery that makes it safe to ship.

## Objectives

1. **Create `####` card blocks** for every card that exists only as a register row. **A register row is not a card.**
2. **Build the boot-safety gate first** (`T-EXCISE-BOOT-SAFETY-GATE`) — it blocks all BIG-class approvals.
3. **Dispatch** every card whose dependencies are met and whose scope is settled.
4. **Enforce PART A on every BIG-class change** — build validation + static boot-safety + runtime HOLD.
5. **Honour DEC-012** — every `T-*` / `F-*` gets ≥1 `Q-*` pair, `BLOCKED` until APPROVED.
6. **Commission the post-remediation verification audit** as the terminal node.

## Out of scope / constraints

- **No on-device verification.** No hardware. `LIVE_FLASH_CLAIMED=false`; DEC-009 HOLD. No `adb` / `fastboot`.
  **Never invent a device or boot result — and never claim "it will not panic" from static analysis alone.**
- **No signed-user production builds** — `T-PORT-<DEV>-KEYS` HOLD; no signing material in tree.
- **`rango-latest` must not move** off `rango-20260802-130756`; **no boot-green claim for `rango`.**
- **Gen 6/7 stay out of scope.**
- **Do not weaken any assertion** in `web-installer/test/devices-inventory.test.ts` or any QA harness to make
  a gate pass. **A failing/negative case is a finding, not an obstacle.**
- **Forbidden paths:** `doctrine/`, `governance/laws/`, `governance/gates/`, `.env`, credentials/secrets,
  `.git`, `keys/`.
- **Owner root is not a git repository** — "no commit" is vacuous; provenance is content rematch. Do not
  initialise a repo.
- **One writer per file.** Owner-root `TASK_QUEUE.md` is authoritative and **Architect-only**;
  `.agent-comm/TASK_QUEUE.md` is derived. Subagents must **not** hand-edit either, and must **not** modify
  `.agent-comm/inbox/TO_ARCHITECT.md` (parallel writers). Each writes its own report +
  `signals/review-{task_id}.json` + a durable `.agent-comm/history/` event.
  *(A lane violated this on 2026-09-24. Re-state the rule in every packet.)*
- **Do not conflate severity axes** — per-lane finding counts vs the umbrella's 36-residual / 8-CRITICAL register.

---

# PART C — Requested decomposition & dispatch

`owner_repository` = `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`
`authoritative_task_path` = its `TASK_QUEUE.md`
`repository_id` = `grapheneos-worktree`

## §0. GATING DECISION — take FIRST

**`T-EXCISE-HYBRID-SCOPE` (`E-18`) is AWAITING OPERATOR.** Do the four laguna `MODE=gtuserspace` hybrid
`-latest` stamps (`frankel`, `blazer`, `mustang`, `rango`) count as "the built image" for this claim?

**Corrected facts — do NOT repeat the Architect's earlier error:** the hybrid **`vendor.img` is GuardTalkOS and
byte-identical to the fullgt stamp** (`frankel` `de9233a2…`, `blazer` `c357e1e4…`, `mustang` `c70f5502…`);
**only `vendor_dlkm` / `system_dlkm` / `boot` are factory.** So only **`vendor_dlkm` / `system_dlkm`-resident**
excisions cannot apply on those four; **`vendor.img`-resident excisions do apply.**

**Instruction:** obtain the ruling, or record a `scope_assumption:` on each affected card.
**Do not silently pick one.** Affected: `T-EXCISE-LAGUNA-BLOCKLIST-WIRING`, `T-EXCISE-MUSTANG-LATEST-OWNER`.
Either dispatch the scope-independent portion, or mark `BLOCKED (operator E-18)` with the reason.
**Report which you chose.**

## §0b. PREREQUISITE — build the gate (BIG, blocks everything)

| Card | Pair | Prio | Scope | Acceptance |
|---|---|---|---|---|
| `T-EXCISE-BOOT-SAFETY-GATE` | `Q-EXCISE-BOOT-SAFETY-GATE` | **P0 — blocks all BIG approvals** | Implement `G2` module-dependency closure, `G3` boot-critical allowlist, `G5` VINTF coherence, `G6` init/sepolicy coherence as **one fail-closed harness** over the **shipped** `*-latest` stamps, plus `G7` boot-chain diff. `G1` uses existing stamp tooling; `G4` calls `verify_remediate_b2_apex_host.sh`. **None of G2/G3/G5/G6 exists today — this card creates them.** | harness runs 13/13; **negative fixture exits non-zero**; the boot-critical allowlist is a reviewed, versioned file with a written rationale per entry; the harness is re-runnable by the Architect with a single command |

> **Do not approve any BIG-class card before this is APPROVED.**

## §1. Backend remediation → `aegis-backend-engineer` (`T-*`)

### Already carded — dispatch as-is (verify the `####` block + deps first)

| Card | Q pair | Prio | Note |
|---|---|---|---|
| `T-EXCISE-GKI-BT-MODULES` | `Q-EXCISE-GKI-BT-MODULES` | P0 | ✅ deps met · **BIG** — blocklisting modules ⇒ **G2+G3 mandatory** |
| `T-EXCISE-BT-VINTF-NOBT` | `Q-EXCISE-BT-VINTF-NOBT` | P0 | ✅ deps met · **BIG** — **G5 mandatory** |
| `T-EXCISE-LAGUNA-BLOCKLIST-WIRING` | `Q-EXCISE-LAGUNA-BLOCKLIST-WIRING` | P0 | ⚠ §0-gated · **BIG** — **G2+G3 mandatory** |
| `T-EXCISE-LOC-GPS-NAME-COVERAGE` | `Q-EXCISE-LOC-GPS-NAME-COVERAGE` | P0 | ✅ deps met · **BIG** — **G1+G6 mandatory** |
| `T-EXCISE-GATE-REVALIDATION` | `Q-EXCISE-GATE-REVALIDATION` | P1 | independent |
| `T-EXCISE-REGEN-GUARD` | `Q-EXCISE-REGEN-GUARD` | P1 | independent; protects the hooks a regen could silently drop |

### Create the card block, then dispatch (rows exist; **no `####` block**)

All are **BIG** unless noted.

| Card | Q pair | Prio | Scope | Critical acceptance |
|---|---|---|---|---|
| `T-EXCISE-MODEM-KERNEL` | `Q-EXCISE-MODEM-KERNEL` | **P0 (CRIT R-2)** | Remove/block `cpif` / `cpif_page` / `shm_ipc` on the **10/13** carrying them: **6** in the `vendor_kernel_boot` ramdisk (`shiba`,`husky`,`akita`,`comet`,`tegu`,`stallion`) + **4** in laguna `vendor_dlkm` (`frankel`,`blazer`,`mustang`,`rango`). Tier A = `tokay`,`caiman`,`komodo`. **⚠ These are modem-transport modules — they must not be a dependency of any boot-critical module (G3).** | 13-row table: none of the three load; **G2+G3 green**; negative fixture exits non-zero |
| `T-EXCISE-FW-RADIO` | `Q-EXCISE-FW-RADIO` | **P0 (CRIT R-1)** | Baseband `radio.img` / `modem.img` shipped 13/13; `radio` flashed by `flash-from-remote.sh:153,937`. Choose **erase/unflash** or a documented inertness argument. `androidboot.radio.disabled` present on only **9/13** — re-derive. | either an erase/unflash path **or** inertness + explicit operator waiver; **G7 boot-chain diff mandatory** |
| `T-EXCISE-RADIOEXT-HAL` | `Q-EXCISE-RADIOEXT-HAL` | **P0 (HIGH)** | `radioExternal` (+`oemservice`) libs in the **packed** `vendor.img` on exactly **6/13** (`tegu`,`stallion`,`frankel`,`blazer`,`mustang`,`rango`). | removed per variant **or** proven orphaned (VINTF + init + service); **G5 mandatory** |
| `T-EXCISE-VINTF-DMD` | `Q-EXCISE-VINTF-DMD` | **P0 (CRIT R-5)** | The surviving `dmd.xml` fragment re-declares `vendor.samsung_slsi.telephony.hardware.oemservice` and is merged at runtime, defeating `vendor_manifest_no_radio*.xml`. **Contrast:** the radio manifest **is wired** (`radio-excised/vintf-excised.mk:31,33,40,46,51,55,57`) but defeated; the BT one is **unwired**. | **G5**: 0 telephony/BT refs in the **runtime-merged** manifest, 13/13, per `VintfObject.cpp:282-328` |
| `T-EXCISE-STAMP-GATE` | `Q-EXCISE-STAMP-GATE` | **P0 (HIGH)** | `radio.disabled` present in `out/` but **absent from the flashable stamps** of `frankel`,`blazer`,`mustang`,`rango` — build/stamp skew. | fail-closed gate: refuse to stamp when any in-scope mitigation flag in `out/` is missing from the stamp |
| `T-EXCISE-LEDGER-R2` | `Q-EXCISE-LEDGER-R2` | **P0** | Re-derive `excision_ledger.json` from **shipped stamps** — QA falsified **16/130 cells (12.3%)**, all under-reporting reachability. Also fix the **self-inconsistent** `nfc_userspace_hal` cell: `rango-latest/vendor.img` carries `NfcOverlayRangoGsi.apk` + `libnfc-hal-st_evt.conf` (`E-19`), both in the ledger's **own** cited list. | re-derived ledger matches the umbrella matrix on every cell; 0 makefile-evidence cells; negative control non-vacuous |
| `T-EXCISE-APEX-DORMANCY` | `Q-EXCISE-APEX-DORMANCY` | P0 | The APEX-dormant set is Tier B; **`com.android.appsearch` is deliberately ACTIVE = Tier C by design** and must be *stated*, never "removed". BCP excision is **deliberately disabled** (`apex-bcp-excised.mk:52-78`, 2026-07-04 tokay Zygote boot-loop). | per-APEX remove-vs-waive recorded; **G4 mandatory — resolve `E-20` first** |
| `T-EXCISE-MATRIX-DOC-REMEDIATE` | `Q-EXCISE-MATRIX-DOC-REMEDIATE` | **P0 (`E-22`)** | **An Architect approval note claimed a remediation that never happened.** Apply `QA-W1` (stallion 16-QPR1 lag), `QA-W2` (pin asymmetry + `tegu`), `QI-1`, **or** withdraw the claim at `TASK_QUEUE.md:6387`. Reconcile the **8 matrix-vs-EXCISE disagreements** (6 × `EXCISION_MATRIX.md`, 1 × `PORT_MATRIX…:344`, 1 × stallion README). | `PORT_MATRIX_GEN8910_PREFLIGHT.md` sha256 **differs** from `e71d4006…`; 0 disagreements remain · **SMALL (docs)** |
| `T-EXCISE-MUSTANG-LATEST-OWNER` | `Q-EXCISE-MUSTANG-LATEST-OWNER` | **P0 (CRIT R-8)** | `mustang-latest` → `mustang-20260923-094541` (`nitrous` blocklist lines = **0**) while the blocklist-correct `mustang-20260923-101119` is an ABL-rejected fullgt. **`flash-from-remote.sh:376-377` auto-resolves `mustang-latest`** ⇒ **a flash would ship the unblocked BCM4390 BT power/rfkill driver.** Coordinate with `T-PORT-FINISH-STAMPS` ADDENDUM-5. | `DEVICE=mustang` resolves to a bundle whose `vendor_dlkm` carries `blocklist nitrous`; proven by `bash -n` + stubbed-fastboot trace with **0 real fastboot calls**; **G2+G7 mandatory** |
| `T-LAGUNA-KLOG-DUMP` (retro-card) | `Q-LAGUNA-KLOG-DUMP` | **P0 (`E-23`)** | **Uncarded in-flight work.** `stage-laguna-release.sh` modified 2026-09-24 14:11:38 UTC (206,988 → 217,888 B; untracked ⇒ no diff baseline) + new 25-file bundle `blazer-20260924-141223-klog/` (*"DIAGNOSTIC — EXPECTED TO FAIL TO BOOT — DO NOT PROMOTE"*). Document `GT_KLOD_DUMP`, the expected `apexd-bootstrap` failure, the `fastboot fetch metadata` recovery. | stager edit reviewed; `blazer-latest` **proven never repointed**; card + queue entry exist · **BIG** |
| `T-PORT-STALLION-RESOLUTION-DOC` | `Q-PORT-STALLION-RESOLUTION-DOC` | P1 (`E-24`) | `stallion` builds with **ZERO release flags in ANY channel** via a **fourth, undocumented** mechanism: real dir + the **only** one of 13 with **no `trunk-14096387` symlink**. | prove *which* code path resolves it; add a **fail-closed** guard so a future fallback change cannot silently swap kernel prebuilts; state `HOLD-PORT-STALLION` (`BD6A.251031.001.A4`) in the stamp README |
| `T-EXCISE-BT-AUDIO-HAL` | `Q-EXCISE-BT-AUDIO-HAL` | P1 | 5 BT-audio HAL libs + `bluetooth_audio.xml` survive 13/13 despite being in `bt-excised.mk`'s drop list. | absent 13/13 by `debugfs` / `unzip -l`; **G1+G5 mandatory** |

### Do NOT create

- **`T-EXCISE-WAVE-BT-HAL-COUNT` — MOOT.** `E-21` was a counting convention, not a discrepancy: the shipped
  manifest has exactly **4** `<name>` lines including `vendor.google.bluetooth_ext` (Wave B counted 3, the
  umbrella `D4` counted 4). Fold the four-line assertion into `Q-EXCISE-BT-VINTF-NOBT`.

### Fold, don't duplicate

- **`T-EXCISE-LOC-STAMP-HONESTY`** → merge into `F-EXCISE-CLAIM-HONESTY` (same failure mode: the
  `shiba` / `husky` stamps must not present those images as location-excised).

### Pre-existing outstanding — adjudicate, do not duplicate

- `T-PORT-FINISH-STAMPS` ADDENDUM-5 (final owner of `mustang-latest`).
- The archived prior inbox batch: `T-PORT-CAIMAN`, `T-PORT-FLASH-CLI-9DEV`, `Q-PORT-FLASH-CLI-9DEV`.

## §2. Frontend remediation → `aegis-frontend-engineer` (`F-*`)

| Card | Pair | Prio | Note |
|---|---|---|---|
| `F-EXCISE-CLAIM-HONESTY` | `Q-EXCISE-CLAIM-HONESTY` | P1 | **Already carded, READY, NOT a no-op.** Fix the **14 overstatements (7 outright false)** — `guardtalk-feature-excised.mk:133,138` · `bt-excised.mk:19-20,170-172` · `bt-excised.mk:131-132` · `README.md:7` · `loc-excised.mk:269-270` · `RUNBOOK.md:25` · `OEM_DEVICE_SPECIFICATION.md:19,34,38` · 15 stamp READMEs · `ATTACK_SURFACE_REPORT.md:407` · `SEIZURE_CHECKIN.md:54-55`. Absorb `T-EXCISE-LOC-STAMP-HONESTY`. Add per-device Tier A/B/C language. **Add the PART A honesty rule:** no doc may say "will not panic" / "boot-safe" without a device run. · **SMALL** |

**Constraint:** the two `air-gapped` strings are **installer/signing-host** claims
(`routes/install/early-steps.ts:217`, `test/claims.test.ts:39`) and are **CORRECT** — **do not weaken them.**
No OS-level airgap claim exists to remove. Reuse the `lib/claims` pattern; no new SPA.
**Do not delete or weaken assertions** in `devices-inventory.test.ts`.

## §3. QA → `aegis-qa-engineer` (`Q-*`, paired + BLOCKED)

**One `Q-*` per new `T-*` / `F-*` (DEC-012)**, each `BLOCKED` until its feature is APPROVED.

**Mandatory for every remediation `Q-*`:**

- a **negative control that exits NON-ZERO** on a deliberately un-remediated fixture —
  *a harness that cannot fail is not evidence*; paste **both** exit codes;
- **per-device (13-row) results**, never one blanket verdict;
- for BIG-class cards: independently re-run **G1–G7** and confirm the card's own G-table —
  **do not accept the card's claim**. Report agreement/disagreement per gate.
- `Q-EXCISE-BOOT-SAFETY-GATE` must additionally prove the gate **fails** when handed:
  (a) a blocklisted boot-critical module; (b) a loaded module with an unloaded dependency;
  (c) a HAL declared with no binary; (d) an init service with no binary.

**Already carded — dispatch when unblocked:** `Q-EXCISE-REGEN-GUARD`, `Q-EXCISE-GATE-REVALIDATION`,
`Q-EXCISE-LEDGER` (findings feed `T-EXCISE-LEDGER-R2`), `Q-EXCISE-13DEV-MATRIX` (extend its 13-device harness
to cover each remediation surface).

## §4. Post-remediation verification → `aegis-auditor` (`A-*`, read-only)

| Card | `audit_scope` | Prio | Scope |
|---|---|---|---|
| `A-EXCISE-REMEDIATE-VERIFY` | `full` | **P0** | **Create + dispatch after the remediation batch reaches REVIEW.** Independently re-derive the 8 CRITICAL residuals from **shipped artifacts**; adjudicate each as Tier A/B/C; re-issue the per-service **and** per-device verdict. **Independently re-prove G1–G7** — do not accept any card's G-table. Re-check `*-latest` integrity and `rango-latest`. Confirm **no card claimed boot safety without a device run** (the PART A honesty rule), and flag any that did. |

**Do NOT dispatch:**

- `A-PORT-PARITY-CAIMAN` — its dependency `Q-PORT-CAIMAN` is `BLOCKED` on `T-PORT-CAIMAN` **APPROVED**, and
  that card is `REVIEW`. **Fail-closed.**
- `A-PORT-PARITY-AKITA` / `A-PORT-PARITY-RANGO` — `SUPERSEDED`.
- All other audit cards are already ✅ REVIEW ACCEPTED — **do not re-dispatch them.**

---

# PART D — Per-task expectations

Every packet must carry:

`task_id` · `role` · `subagent` · `owner_repository` · `authoritative_task_path` · `coordination_root` ·
`repository_id` · `status_transition` (`READY → DISPATCHED → IN_PROGRESS → REVIEW`) · `priority` ·
`depends_on` · `qa_pair` · **`blast_radius` (BIG|SMALL)** · **`gates_required`** · Scope · Target paths ·
Forbidden paths · Acceptance criteria · exact Verification commands.

## Card-authoring rules — enforce before reporting anything created

- **A register row is not a card.** `grep -n '^#### <ID>$' TASK_QUEUE.md` must return the block **before** you
  report it created. *This exact overstatement has happened twice in this programme.*
- Never `APPROVED` / `DISPATCHED` for unworked cards — use `READY` / `BLOCKED`.
- Every BIG-class card's acceptance criteria must **include its G-table** and explicitly state the `G8` HOLD.
- Acceptance criteria must be **independently re-runnable** by the Architect: `sha256sum -c` · `cmp` ·
  `debugfs` against the shipped stamp · `bash -n` · harness exit codes.
  **Prefer artifact-level evidence over makefile-level evidence wherever both are possible.**
- Update **root `TASK_QUEUE.md` first**, then the derived index. Never the reverse.

## Transport, per dispatch

- `Task → generalPurpose`, packet in `prompt`, `run_in_background: true`.
- Write `.agent-comm/signals/dispatch-{task_id}.json`.
- Append the durable dispatch event to `.agent-comm/history/`.

## Subagent contract — state in every packet

- **Gate -1 in-process** — load `.aegis/governance/{laws,gates}/*.yaml`. **Never call** `aegis-verifier`,
  `ask_guardian`, `gate_enforcer`, or Guardian HTTP.
- Status → **`REVIEW` only**; **never `APPROVED`**.
- **Do not modify `.agent-comm/inbox/TO_ARCHITECT.md`**; **do not hand-edit any `TASK_QUEUE.md`**.
- **Builds serialise on `flock out/.guardtalk-build.lock`** — all products share `out/`.
  **Never run two builds concurrently.**
- **Read-only for auditors.** No USB / adb / fastboot. No commits.
- `Gate 5: HUMAN SKIP` rather than inventing a critique score.
- `LIVE_FLASH_CLAIMED=false`, `FLASH_READY=false`, **`BOOT_VERIFIED=false`** — always, without hardware.
- **Never claim "the kernel will not panic" or "boot-safe" from static analysis.** Report the G-table and the HOLD.

---

# PART E — Deliverable back to the operator

1. **Card inventory:** every `####` block created (ID, lane, prio, Q pair, deps, `blast_radius`,
   `gates_required`), with the `grep` proof per card — plus an explicit list of cards **not** created and why.
2. **Dispatch plan:** dispatched vs held, with the `scope_assumption` recorded for each `E-18`-gated card.
3. **The `E-18` decision:** ruling obtained, or explicit assumption recorded.
4. **Gate status:** whether `T-EXCISE-BOOT-SAFETY-GATE` is created/dispatched, and confirmation that
   **no BIG-class card will be approved before it is green**.
5. **Confirmations:** no product code modified · `rango-latest` unmoved · Gen 6/7 out ·
   **no boot-safety claim made anywhere**.
6. **Dependency / pairing graph** for the remediation programme, with `T-EXCISE-BOOT-SAFETY-GATE` as the gate
   on all BIG-class approvals and `A-EXCISE-REMEDIATE-VERIFY` as the terminal node.

---

## APPENDIX — Evidence anchors

| Anchor | Path |
|---|---|
| Consolidated audit result | `vendor/guardtalk/docs/qa/AUDIT_RESULT_CONSOLIDATED_20260925.md` |
| Umbrella verdict | `vendor/guardtalk/docs/qa/A-EXCISE-AIRGAP-MATRIX_AUDIT.md` |
| Per-service audits | `vendor/guardtalk/docs/qa/A-EXCISE-{RADIO,BT,LOC,SURFACES,13DEV-NONREGRESSION}_AUDIT.md` |
| Claims audit | `vendor/guardtalk/docs/qa/A-EXCISE-HONESTY_AUDIT.md` |
| Port wave audits | `vendor/guardtalk/docs/qa/A-PORT-{MATRIX-R2,WAVE-A,WAVE-B,WAVE-C}_AUDIT.md` |
| QA ledger falsification | `vendor/guardtalk/docs/qa/Q-EXCISE-LEDGER_EVIDENCE.md` |
| QA 13-device harness | `vendor/guardtalk/docs/qa/Q-EXCISE-13DEV-MATRIX_EVIDENCE.md` |
| Ledger (demoted) | `vendor/guardtalk/docs/EXCISION_LEDGER.md` + `docs/qa/excision_ledger.json` |
| `E-9` location recon | `.agent-comm/evidence/A-EXCISE-LOC-GPS-NAME-COVERAGE_architect-recon.md` |
| `E-10` nitrous recon | `.agent-comm/evidence/E10-LAGUNA-BLOCKLIST-NITROUS-NOT-APPLIED.md` |
| `E-11`–`E-13` suite rematch | `.agent-comm/evidence/E11-E13-AUTHOR-SUITE-REMATCH.md` |
| `E-20` apex/SSR | `verify_remediate_b2_apex_host.sh` output (source-structural FAIL) |
| `E-23` uncarded work | `vendor/guardtalk/scripts/stage-laguna-release.sh` + `releases/desktop-flash/blazer-20260924-141223-klog/README-FLASH-DESKTOP.md` |
| Earliest boot-loop incident | `vendor/guardtalk/feature-excised/apex-bcp-excised.mk:52-78` |
| Dead-flag incident | `.agent-comm/evidence/B-PORT-LAGUNA-EARLY-VM-INERT-FLAG.md` |
| Dispatch packet template | `.aegis/templates/DISPATCH_PACKET.md` |
| Build/stamp tooling | `.agent-comm/tools/gt-stamp-device.sh`, `gt-build-one.sh`, `gt-batch-a-driver.sh` |
