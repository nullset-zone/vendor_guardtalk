# B-EXCISE-G3-RT6160_REPORT — `rt6160-regulator` load/blocklist contradiction

| Field | Value |
|-------|-------|
| **task_id** | `T-EXCISE-G3-RT6160-REGULATOR` |
| **role** | backend_engineer |
| **status** | **`REVIEW`** (never `APPROVED`) |
| **priority** | P0 |
| **blast_radius** | BIG |
| **gates_required** | G2, G3, G7, G8 |
| **qa_pair** | `Q-EXCISE-G3-RT6160-REGULATOR` (unblocked for review) |
| **depends_on** | `T-EXCISE-BOOT-SAFETY-GATE` ✅ APPROVED |
| **owner_repository** | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| **authoritative_task_path** | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` |
| **gate_minus1** | `IN-PROCESS` (24 laws + 11 gates loaded from `.aegis/governance/`; no `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP used) |
| **Gate 5** | `HUMAN SKIP` |
| **LIVE_FLASH_CLAIMED** | `false` |
| **FLASH_READY** | `false` |
| **BOOT_VERIFIED** | `false` |
| **commit** | none |
| **timestamp** | 2026-09-25T13:25:00Z |

> **Honesty (Law 7 / Law 16).** This is **static analysis only**; there is no hardware attached to this
> host. Nothing below asserts that a kernel "will not panic", that an image is "boot-safe", or that a
> flash is ready. The deliverable is the G-table and the HOLD.

---

## 1. Verdict

**`rt6160-regulator` was NOT a real boot blocker on `shiba` / `husky`. It was a dormant inconsistency
in the G3 allowlist, not a defect in the shipped images.**

The `blocklist rt6160_regulator` line is **intentional, upstream-derived and correct** for
`zuma_shusky`: the Zuma/shushy board does not instantiate the Richtek RT6160 part at all. The G3
boot-critical allowlist asserted the module boot-critical on **every** device (no `families`
selector), which is false for the only two devices that lack the hardware. That over-broad assertion
produced the `blocklisted=1` G3 false positive.

**Fix applied at source:** `.agent-comm/tools/gt-boot-critical-allowlist.yaml` v2 → **v3** — the
`rt6160-regulator` entry is now scoped to `["zuma_akita", "zumapro_*", "laguna_*"]`, i.e. exactly the
families whose DTBO carries the part. The requirement is **unchanged** everywhere the part exists; it
is simply no longer asserted where the artifacts prove the part is absent.

**G3 is now green 13/13 and G2 remains green 13/13.** No product artifact was rebuilt, and none needed
to be — see §5 (and §12 for the alternative product-side resolution the Architect may prefer).

---

## 2. The finding under adjudication

The first real run of `T-EXCISE-BOOT-SAFETY-GATE` reported:

```
device    G3 miss/blk/notload
shiba     missing=0 blocklisted=1 not_loaded=0
husky     missing=0 blocklisted=1 not_loaded=0
```

`rt6160-regulator` appeared in **both** `vendor_dlkm.modules.load` **and**
`vendor_dlkm.modules.blocklist`, with no phase-2 override, on `shiba` and `husky` only. Because the
blocklist wins in phase 1, the regulator never binds.

---

## 3. Ground truth from the shipped artifacts

All of the following was read **from the shipped images**, not from makefiles (artifact-level evidence
preferred, as the card requires). Reproduction: `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/probe_rt6160.sh`
→ `probe-output.txt`.

### 3.1 Shipped `shiba` / `husky` module files (`debugfs` on `releases/desktop-flash/<dev>-latest/vendor_dlkm.img`)

```
[shiba-latest/vendor_dlkm.img]                       [husky-latest/vendor_dlkm.img]
modules.load:13       rt6160-regulator.ko             modules.load:13       rt6160-regulator.ko
modules.blocklist:25  blocklist rt6160_regulator      modules.blocklist:25  blocklist rt6160_regulator
modules.dep:97        /vendor/lib/modules/rt6160-regulator.ko:   (empty RHS)
```

`system_dlkm.img` carries **no** `rt6160` occurrence on either device. The device two-phase config
(`init.insmod.{shiba,husky}.cfg`, 18 lines each) contains **no** `rt6160` / `regulator` re-modprobe —
so **there is no phase-2 override** and the blocklist is final in phase 1. (Contrast: the documented
`bcmdhd4398` Wi-Fi two-phase load *does* re-modprobe in `init.insmod.<dev>.cfg`; that mechanism exists
and was checked — it simply does not apply here.)

### 3.2 Hardware truth — device-tree binding (`dtbo.img`, `dtc` decompile of every overlay, all 13 devices)

| device | family | overlays | parsed OK | overlays with `richtek,rt6160` | prop lines |
|--------|--------|---------:|----------:|------------------------------:|-----------:|
| **shiba** | zuma_shusky | 19 | 19 | **0** | **0** |
| **husky** | zuma_shusky | 19 | 19 | **0** | **0** |
| akita | zuma_akita | 19 | 19 | 19 | 57 |
| tokay | zumapro_caimito | 60 | 60 | 55 | 55 |
| caiman | zumapro_caimito | 60 | 60 | 55 | 55 |
| komodo | zumapro_caimito | 60 | 60 | 55 | 55 |
| comet | zumapro_comet | 15 | 15 | 14 | 42 |
| tegu | zumapro_tegu | 10 | 10 | 10 | 19 |
| stallion | zumapro_stallion | 10 | 10 | 9 | 9 |
| frankel | laguna_muzel | 34 | 34 | 27 | 27 |
| blazer | laguna_muzel | 34 | 34 | 27 | 27 |
| mustang | laguna_muzel | 34 | 34 | 27 | 27 |
| rango | laguna_rango | 11 | 11 | 11 | 11 |

The RT6160 node as it appears on `akita` (overlay 00) — the direct hardware binding:

```dts
rt6160@77 {
    compatible = "richtek,rt6160";
    reg = <0x77>;
    status = "ok";
    regulator-name = "rt6160-buckboost";
    ...
};
```

`shiba` / `husky` contain **zero** such nodes across all 19 overlays. The module's `of_match_table`
entry (`compatible = "richtek,rt6160"`) therefore never matches on `zuma_shusky`; the driver cannot
probe. **The part is not on the board.**

### 3.3 `modules.dep` — `rt6160-regulator` is a leaf (G2 impact = none)

```
shiba: /vendor/lib/modules/rt6160-regulator.ko:      dependents=0
husky: /vendor/lib/modules/rt6160-regulator.ko:      dependents=0
```

Nothing in the dependency graph depends on `rt6160-regulator.ko`. Blocklisting it therefore **cannot**
break G2 closure — and G2 is confirmed green 13/13 (§6). The card's escalation trigger ("if any loaded
module depends on `rt6160-regulator`, the blocklist is definitively wrong **and** that is a G2 closure
problem") **did not fire**.

### 3.4 The "load + blocklist overlap" is the standard Android pattern, not the defect

On shipped `shiba`/`husky` `vendor_dlkm`: **loaded = 62, blocklisted = 14, overlap = 14** — i.e. **every
one** of the 14 blocklisted modules also appears in `modules.load`:

```
aoc_unit_test_dev, bcmdhd4398, cs40l26_i2c, ftm5, gnss_spi, gnssif, goodix_brl_touch,
mali_kutf, mali_kutf_clk_rate_trace_test_portal, nitrous, rt6160_regulator,
sec_touch, sscoredump_sample_test, sscoredump_test
```

`modules.load` is the depmod-generated inventory of the partition, and `modules.blocklist` is the
phase-1 suppression list; a blocklisted module is normally also present in `modules.load`. The
`rt6160` overlap is therefore **not** "`rt6160`-specific incoherence" — it is the same shape as 13
other modules. The only discriminating question is whether the module is **genuinely boot-critical on
that board**, and for `zuma_shusky` the artifacts answer no.

### 3.5 Provenance — the blocklist line is intentional upstream policy

```
device/google/shusky-kernels/6.1/grapheneos/vendor_dlkm.modules.blocklist:13:blocklist rt6160_regulator
```

and the in-tree excision variant preserves it **verbatim**:

`vendor/guardtalk/feature-excised/variants/zuma_shusky/vendor_dlkm.modules.blocklist` states
*"Every upstream `blocklist` line is preserved verbatim and in order"* and carries
`blocklist rt6160_regulator`.

So neither the shipped image nor the excision variant introduced this line — Google/GrapheneOS did, on
purpose, for a board without the part.

---

## 4. Adjudication — which side is intended

| Candidate hypothesis | Artifact verdict |
|---|---|
| "`rt6160-regulator` is genuinely required before userspace on `shiba`/`husky` ⇒ the blocklist is wrong" | **FALSE.** 0/19 DTBO overlays carry `richtek,rt6160`; the driver cannot bind; 0 modules depend on it. |
| "The `blocklist` entry was copied from a family that does not carry RT6160" | **FALSE (inverted).** It is the *allowlist* entry that was over-broad. The blocklist is correct *for this board*; every other family **does** carry the part and **does** load it unblocked. |
| "`shiba`/`husky` get RT6160 via a phase-2 `modprobe`" | **FALSE.** `init.insmod.{shiba,husky}.cfg` contains no `rt6160`/`regulator` re-modprobe. |
| "Blocklisting it breaks a dependency" | **FALSE.** Leaf module, 0 dependents; G2 green 13/13. |
| "The shipped images are incoherent" | **FALSE.** The images faithfully implement the intended blocklist policy; the false claim was in the *gate's assertion about boot-criticality*. |

**Conclusion:** the artifacts say the part is absent, upstream policy says block it, and the dependency
graph says it is not needed. The only incorrect statement in the stack was the G3 allowlist's
un-scoped assertion that the module must load on **all 13** devices.

**Verdict on boot-blocker status: NOT a real boot blocker — dormant inconsistency** (harmless in the
current artifacts because the driver can never bind, but a genuine gate false positive that would have
masked real G3 signal on `shiba`/`husky` and blocked the QA pair).

---

## 5. Fix at source

**File:** `.agent-comm/tools/gt-boot-critical-allowlist.yaml` (the reviewed, versioned G3 allowlist).

```diff
-version: 2
+version: 3
-reviewed_by: "T-EXCISE-BOOT-SAFETY-GATE (backend engineer, on behalf of Architect)"
+reviewed_by: "T-EXCISE-BOOT-SAFETY-GATE (v2); T-EXCISE-G3-RT6160-REGULATOR (v3) — backend engineer, on behalf of Architect"
 reviewed_at: "2026-09-25"
@@
   - module: rt6160-regulator
     category: regulator
-    rationale: "Richtek buck-boost regulator used for always-on rails; pre-userspace power sequencing"
+    families: ["zuma_akita", "zumapro_*", "laguna_*"]
+    rationale: "Richtek RT6160 buck-boost regulator for always-on rails (DT node richtek,rt6160 @ I2C 0x77).
+      Present on akita/zumapro/laguna DTBO; scoped away from zuma_shusky which has 0 rt6160 DT nodes and
+      whose stock shusky-kernels blocklists rt6160_regulator (v3 correction)."
```

plus a `v3` changelog block in the file header recording the evidence and stating explicitly that this
is a **correction, not a relaxation**.

**Why this is the correct source fix and not "weakening a gate to make it pass":**

- The entry still asserts the identical requirement for the 11 devices that carry the part; the gate
  is not weakened there. `akita` (19/19 overlays, 57 nodes) still has to load it unblocked — and does.
- The gate's own semantics already support exactly this mechanism (`families` globs), and its header
  rationale already states the principle: *"Law 7: do not assert a claim the artifacts contradict."*
  v2 violated that principle for `rt6160-regulator`.
- The `regulator` subsystem **coverage assertion** still holds for `zuma_shusky`: 3 applicable
  regulator entries cover it (`max77779_pmic`, `slg51002-regulator`, `spmi_bit_bang`) — verified in
  the G3 JSON (`covered_subsystems.regulator = 3`), so the coverage guard did not have to be relaxed.

**Why the product was deliberately NOT changed:** the only "product-side" way to make the shipped
`shiba`/`husky` images stop listing `rt6160-regulator` under both `modules.load` and `modules.blocklist`
would be to delete the upstream `blocklist rt6160_regulator` line. That would (a) violate the excision
variant's own stated invariant *"Every upstream `blocklist` line is preserved verbatim and in order"*,
(b) force an I²C driver for absent hardware to register on a board that does not have it (Law 6,
minimal footprint), and (c) is not required for coherence, because the overlap is the standard
Android phase-1 pattern (§3.4). **No product artifact was modified, so no rebuild was required and no
build lock (`flock out/.guardtalk-build.lock`) was taken.**

---

## 6. Verification results

### 6.1 `bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --json --skip-g4`

**AFTER (allowlist v3) — 13 rows:**

| device | G2 unloaded/inv/miss | G3 miss/blk/notload | G5 forb/unback/undecl | G6 orph/wf/req/lab | G7 |
|---|---|---|---|---|---|
| shiba | unloaded=0 inv=0 missing=0 | **missing=0 blocklisted=0 not_loaded=0** | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| husky | unloaded=0 inv=0 missing=0 | **missing=0 blocklisted=0 not_loaded=0** | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| akita | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| tokay | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| caiman | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| komodo | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| comet | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=2 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| tegu | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| stallion | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| frankel | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| blazer | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| mustang | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| rango | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=4 wf=0 req=0 lab=2 | unchanged |

```
devices=13  gate-fail=13
G4: SKIPPED(--skip-g4)  E-20: not evaluated this run
```

**Totals: G2 fail 0/13 · G3 fail 0/13 · G3 allowlist_version=3.**

> **Exit-code note (honest reporting).** `--all-devices` still exits **1**. That is **not** a G3
> regression: `total_fail` counts any device failing any of G2/G3/G5/G6/G7, and **G5 (13/13) and G6
> (13/13) were already failing before this card** — the predecessor report
> `B-EXCISE-BOOT-SAFETY-GATE_REPORT.md:110` records *"devices=13, gate-fail=13 (G5 and G6 fail on all
> 13; G3 fails on 2)"*. This run removes the G3 component: the same line now reads **"G5 and G6 fail on
> all 13; G3 fails on 0"**. G5/G6 remain open on their own cards and are out of this card's scope.

### 6.2 BEFORE (allowlist v2), same command — for the delta

| device | G2 | G3 miss/blk/notload | G5 | G6 | G7 |
|---|---|---|---|---|---|
| shiba | unloaded=0 inv=0 missing=0 | missing=0 **blocklisted=1** not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| husky | unloaded=0 inv=0 missing=0 | missing=0 **blocklisted=1** not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| akita | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| tokay | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| caiman | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| komodo | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| comet | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=2 undeclared=0 | orphan=3 wf=0 req=0 lab=2 | unchanged |
| tegu | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| stallion | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| frankel | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| blazer | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| mustang | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=2 wf=0 req=0 lab=2 | unchanged |
| rango | unloaded=0 inv=0 missing=0 | missing=0 blocklisted=0 not_loaded=0 | forbidden=7 unbacked=1 undeclared=0 | orphan=4 wf=0 req=0 lab=2 | unchanged |

Delta: **only** `shiba`/`husky` G3 `blocklisted` 1 → 0. Nothing else moved on any device.

### 6.3 Per-device (card-mandated)

```
bash .agent-comm/tools/gt-boot-safety-gate.sh --device shiba --json   → G2 0/0/0 · G3 0/0/0 · exit 1 (G5/G6 only)
bash .agent-comm/tools/gt-boot-safety-gate.sh --device husky --json   → G2 0/0/0 · G3 0/0/0 · exit 1 (G5/G6 only)
```

### 6.4 Negative fixtures (must exit non-zero)

```
bash .agent-comm/tools/gt-boot-safety-gate.sh --fixture blocklisted-boot-critical
```
```
=== FIXTURE blocklisted-boot-critical ===
G2 unloaded_deps=1 inversions=0 missing=0
G3 missing=0 blocklisted=1 uncovered=0
G5 forbidden=0 unbacked=0 undeclared=0
G6 orphan=0 broken_wait_for=0 broken_requires=0 missing_labels=0
NEGATIVE FIXTURE DEFECT DETECTED (G3 failed) — exit 1
```

**Exit code = 1.** The negative control is intact: it is still `G3` (the expected gate) that catches it,
and it is caught by `blocklisted=1` — the same signal that previously (correctly) fired on `shiba`/`husky`
and now correctly does not, because the fixture's synthetic family is `laguna_muzel` (RT6160-bearing)
while `shiba`/`husky` are not.

### 6.5 G7 — boot chain

**Unchanged on all 13 devices.** No product artifact was rebuilt (§5), so the boot chain cannot have
moved; `gate_g7` compared against the recorded baseline and reported `unchanged` for every device in
both the before and after runs. `--update-baseline` was **not** used.

### 6.6 G8 — Runtime HOLD (always HOLD)

```
LIVE_FLASH_CLAIMED = false
FLASH_READY        = false
BOOT_VERIFIED      = false
```

No hardware is attached to this host. **G8 is HOLD and is not waivable by this card.** "There is no
hardware" is the reason G8 exists, not a reason to skip G1–G7. Nothing in this report asserts that a
kernel will not panic, that an image is boot-safe, or that a flash is ready.

**Ready-to-run runtime procedure (execute the moment hardware is attached; do not run blind):**

```bash
# 0. preconditions — device unlocked on a known-good baseline; keep a rollback stamp handy
fastboot fetch metadata                                     # recovery/rollback metadata (ABL pattern)

# 1. boot the candidate stamp installed from releases/desktop-flash/<dev>-latest/
adb wait-for-device
adb shell getprop sys.boot_completed                        # expect: 1

# 2. the negative assertion this card rests on — the driver must NOT be bound on zuma_shusky
adb shell 'lsmod | grep -i rt6160 || echo NO_RT6160'        # expect NO_RT6160 on shiba/husky
adb shell 'find /proc/device-tree -iname "*rt6160*" 2>/dev/null | head'   # expect empty on shiba/husky
adb shell 'dmesg | grep -i rt6160 || echo NO_RT6160_PROBE'  # expect NO_RT6160_PROBE on shiba/husky

# 3. the positive control — the same checks on an RT6160-bearing device (e.g. akita)
adb shell 'find /proc/device-tree -iname "*rt6160*" 2>/dev/null | head'   # expect rt6160@77

# 4. contradiction check — no load/blocklist surprise at runtime
adb shell 'lsmod | grep -i rt6160' ; adb shell 'dmesg | grep -iE "blocklist|unknown symbol"'
```

Pass condition: `sys.boot_completed=1` **and** steps 2 empty **and** step 3 non-empty. A non-empty
step 2 (driver bound on `shiba`/`husky`) would falsify §3.2 and must reopen this card. This procedure is
documented, not executed.

---

## 7. Acceptance criteria — status

| # | Criterion | Status |
|---|---|---|
| 1 | Contradiction resolved at source; shipped `shiba`/`husky` images coherent | ✅ resolved at the true source (the over-broad G3 assertion). Images verified coherent (§3.4/§3.5): the blocklist line is correct upstream policy; `modules.load`/`modules.blocklist` overlap is the standard phase-1 pattern (14/14), and the module is a leaf. |
| 2 | G3 green 13/13 and G2 still green 13/13 on `--all-devices` | ✅ G3 fail 0/13, G2 fail 0/13 (§6.1) |
| 3 | 13-row result table, never one blanket line | ✅ §6.1 (and §6.2 before-table) |
| 4 | Negative fixtures exit non-zero (≥ `blocklisted-boot-critical`) | ✅ exit 1, G3 caught it (§6.4) |
| 5 | G7 boot-chain status reported for anything rebuilt | ✅ nothing rebuilt ⇒ `unchanged` 13/13 (§6.5) |
| 6 | Explicit verdict + artifact evidence | ✅ §1/§4 — **not a boot blocker**; 0/19 DTBO nodes, 0 dependents, upstream blocklist, no phase-2 override |
| 7 | G8 runtime HOLD stated with a ready-to-run procedure | ✅ §6.6 — `BOOT_VERIFIED=false`, `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false`, procedure documented |

---

## 8. What could NOT be verified, and why

- **Runtime behaviour.** There is no hardware on this host. The claim "the driver cannot bind because
  the compatible string is absent from the DT" is a *static inference from the shipped DTBO and the
  shipped `of_match_table`-bearing module*; it was **not** observed on a booted device.
  `BOOT_VERIFIED=false`.
- **`tokay` shipped stamp is not `*-latest`.** `releases/desktop-flash/tokay-latest` does not exist; the
  DTBO scan used `tokay-20260725-102506` (the newest `tokay-2026*` stamp present). The gate itself reads
  `tokay` from its own extracted cache, so G2/G3 for `tokay` are unaffected — but the DTBO row for
  `tokay` is from that explicit stamp, not from a `-latest` symlink.
- **Whether `rt6160` is *functionally load-bearing* on `akita`/`zumapro`/`laguna`.** This card only had
  to adjudicate `zuma_shusky`. The scoped entry still asserts boot-criticality on the RT6160-bearing
  families **as v2 did**; that pre-existing assertion was not re-litigated here.
- **G5 / G6.** Still failing 13/13; they are pre-existing and belong to other cards. Not touched, not
  suppressed.

---

## 9. Authority, scope and forbidden paths

- Authority confirmed: `owner_repository` = `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`,
  `authoritative_task_path` = `<repo>/TASK_QUEUE.md`. All work is inside the owner repository.
- Implemented within backend scope: `.agent-comm/tools/gt-boot-critical-allowlist.yaml` (the G3 gate
  artifact this card exists to correct), plus evidence/report/signal/history under
  `.agent-comm/evidence/`, `vendor/guardtalk/docs/qa/` and `.agent-comm/{signals,history}/`.
- **Not touched:** `doctrine/`, `governance/laws/`, `governance/gates/`, `.aegis/**`, `.env`,
  credentials/secrets, `keys/`, `.git`.
- **`TASK_QUEUE.md` NOT hand-edited** (Architect owns it).
- **`.agent-comm/inbox/TO_ARCHITECT.md` NOT modified** (operator brief wins over the dispatch template).
  This report is the outbound artifact instead.
- No `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP call was made (contract item 2).
- No commit.

---

## 10. Alternative resolution (for the Architect's decision, not applied)

If the Architect prefers the **product-side** resolution instead — i.e. `zuma_shusky` ships
`rt6160-regulator` loaded (un-blocklisted) so that the artifact has no `modules.load`/`modules.blocklist`
overlap for this module — that is a **one-line deletion** in

```
vendor/guardtalk/feature-excised/variants/zuma_shusky/vendor_dlkm.modules.blocklist
- blocklist rt6160_regulator
```

followed by a `generate-all`-class rebuild + restamp of `shiba`/`husky` under
`flock out/.guardtalk-build.lock`, which would then be reported as a G7 boot-chain **change**.

It was **not** taken because: (a) it deletes an upstream line the variant file documents as preserved
*verbatim and in order*; (b) it forces a driver for absent hardware to register (Law 6); (c) the DTBO
proves the part is absent, so it buys no boot capability; and (d) coherence is already satisfied
without it. **This is the Architect's call** — say the word and the one-line product change + rebuild
can be executed and re-verified.

---

## 11. Artifacts

| Path | Contents |
|---|---|
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/probe_rt6160.sh` | deterministic, read-only ground-truth probe |
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/probe-output.txt` | probe output (DTBO scan, module files, dependents, overlap, provenance) |
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/gt-boot-safety-gate-BEFORE.json` | full gate JSON, allowlist v2 |
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/gt-boot-safety-gate-AFTER.json` | full gate JSON, allowlist v3 |
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/console-all-devices-{BEFORE,AFTER}.txt` | 13-row console tables |
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/console-device-{shiba,husky}-AFTER.txt` | per-device runs |
| `.agent-comm/evidence/T-EXCISE-G3-RT6160-REGULATOR/fixture-blocklisted-boot-critical-AFTER.txt` | negative control |
| `.agent-comm/tools/gt-boot-critical-allowlist.yaml` | v3 (the fix) |
| `.agent-comm/signals/review-T-EXCISE-G3-RT6160-REGULATOR.json` | REVIEW signal |
| `.agent-comm/history/2026-09-25T132500+0000-T-EXCISE-G3-RT6160-REGULATOR-review.md` | durable event |

---

**— AEGIS Backend Engineer (Panel 2) · `T-EXCISE-G3-RT6160-REGULATOR` · status `REVIEW`**
