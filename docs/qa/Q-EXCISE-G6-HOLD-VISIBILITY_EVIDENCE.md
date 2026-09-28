# Q-EXCISE-G6-HOLD-VISIBILITY — QA adversarial verification (Panel 4)

- **Task:** `Q-EXCISE-G6-HOLD-VISIBILITY` (P1) · parent `T-EXCISE-G6-HOLD-VISIBILITY` ✅ APPROVED
- **Verdict:** ✅ **VERIFIED** for the card's claim, **with 3 recorded residuals** (1 latent defect, 2 definition/scope gaps). Not a rubber stamp.
- **Date:** 2026-09-25T17:49Z · **Agent:** QA Engineer (Panel 4)
- **Static only:** `BOOT_VERIFIED=false` · `LIVE_FLASH_CLAIMED=false` · `FLASH_READY=false`
- **No commit / no push · no build / no flash / no boot · `TASK_QUEUE.md` NOT edited · harness NOT edited · shared `TO_ARCHITECT.md` NOT touched**

---

## 0. ★ Artifact identity — the approved harness is NO LONGER the live file (Law 7)

The card asks me to confirm the tested harness md5 is `8a4794ef9820ccc6759e5bfce2a95643`. **It is not — the
live harness was overwritten before this QA lane started**, by the wave-2 `T-EXCISE-BLOCKED-COVERAGE-AUDIT`
writer (released by the parent card):

| Position | Path | Size | md5 |
|---|---|---|---|
| **Approved artifact (what I verified)** | `.agent-comm/evidence/T-EXCISE-BLOCKED-COVERAGE-AUDIT/gt_boot_safety_gate.py.PRE-AUDIT` | 96291 | **`8a4794ef9820ccc6759e5bfce2a95643`** ✅ |
| **Live harness (NOT the approved bytes)** | `.agent-comm/tools/gt_boot_safety_gate.py` | 109301 | `7447e77dbd559a8c0de87a75da2cb4e9` |
| Pre-HOLD baseline | `.agent-comm/evidence/T-EXCISE-G6-HOLD-VISIBILITY/gt_boot_safety_gate.py.PRE-HOLD` | 89728 | `6d9083c164d1c6140930f5023ecd254b` |

The audit lane's own `PRE-AUDIT` backup **is byte-identical to the approved post-HOLD harness** (md5 match), so
the approved artifact is verifiable. **All results below were produced against the preserved `8a4794ef…`
bytes**, run read-only via the shell wrapper's `GT_BOOT_SAFETY_PY` override from a `/tmp` proxy root
(symlinks back to `releases/`, `.agent-comm/`, `vendor/`, `out/`) so the harness's
`ROOT = Path(__file__).resolve().parents[2]` resolves correctly and **no repo file was modified**.

**Cross-check on the live harness (drift note):** the live `7447e77…` bytes still reproduce the hold
behaviour — `hold-control` default **0**, `--strict-g6` **1**, 13-device hold total **14**. So the
concurrent edit did **not** regress HOLD visibility; the md5 simply no longer matches the approved bytes.

---

## 1. Independent re-derivation of the HOLD totals (own parser, not author's commands)

Fresh run of the approved artifact:
`GT_BOOT_SAFETY_PY=<approved> bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --skip-g4 --json --out qa-all-devices.approved.json`
→ **default exit = 1** (G3/G5 fail on other cards, as documented).

Re-parsed the raw JSON with `qa_rederive.py` (stdlib only, never calls a harness helper):

| Claim | Card | Re-derived | Match |
|---|---|---|---|
| `hold` total | 14 | **14** | ✅ |
| `rango` | 2 | **2** | ✅ |
| `comet` | 1 | **1** | ✅ |
| all other 11 devices | 1 | **1** | ✅ |
| `abox` devices | 13 | **13** (all) | ✅ |
| `init_thermal_config` devices | rango only | **1** (rango) | ✅ |
| top-level `hold_services_total` | 14 | **14** | ✅ |

Distribution: `{1:12, 2:1}`. `hold_list` per device carries `classification: unshipped_vendor_daemon`.

## 2. G6 integrity + default exit code unchanged (PRE-HOLD vs approved)

`qa_nonregress.py` diffed the approved JSON against a fresh **PRE-HOLD** (`6d9083c1…`) run:

- **G6 pass = 13/13**; `orphan_services = 0`, `missing_sepolicy_labels = 0` on all 13.
- **0 mismatches** across every device/gate for `orphan_services`, `broken_wait_for`, `broken_requires`,
  `missing_sepolicy_labels`, `pass`, `blocked`.
- The **only** new G6 JSON key is `hold_services` (+ top-level `hold_services_total`).
- **Default exit code unchanged:** PRE-HOLD **1** = approved **1**; `approved --strict-g6` also **1**.

G-table header now includes `hold` (`G6 orph/wf/req/lab/hold`); example rows:

```
rango     ... G6 orphan=0 broken_wait_for=0 broken_requires=0 missing_labels=0 hold=2 ...
shiba     ... G6 orphan=0 broken_wait_for=0 broken_requires=0 missing_labels=0 hold=1 ...
# clean device (fixture): clean-control  G6 ... hold=0
```

## 3. Decisive control — `hold-control` synthetic fixture

| Invocation (approved artifact) | Expected | Observed |
|---|---|---|
| `--fixture hold-control` | 0 | **0** |
| `--fixture hold-control --strict-g6` | 1 | **1** |
| `--fixture clean-control --strict-g6` | 0 | **0** |

`hold-control` reports `G6 ... hold=1` and `pass` (all gates clean). Architect's 0→1 reproduction confirmed.

---

## 4. ★ Adversarial falsification of the HOLD definition

The author defines a HOLD as **load-bearing**: `classification != airgap_excision` **AND** actually shielding a
**confirmed orphan** on that device. I drove the approved harness's `gate_g6()` directly in-memory
(`qa_hold_falsify.py`, imports the frozen module, no repo write) with synthetic datasets.

| # | Scenario | Result | Reading |
|---|---|---|---|
| A | absent `/vendor/bin` binary + `unshipped_vendor_daemon` | hold=1, orphan=0 | baseline HOLD ✅ |
| B | same orphan re-classified `airgap_excision` | hold=0, pass=true | excused, **not** held (non-aggregation) ✅ |
| **C** | **`classification:` key OMITTED** | **hold=0, pass=true** | **★ definitional gap** |
| C2 | unknown class (`totally_made_up`) | pass=false, config_error, orphan=1 | fail-closed ✅ |
| C3 | empty-string class | pass=false, config_error | fail-closed ✅ |
| **D** | absent binary, exec `/odm/bin/foo`, `unshipped_vendor_daemon` | **hold=0, orphan=0, pass=true** | **★ gap invisible** |
| **D2** | absent `root`-path exec | **hold=0, orphan=0** | **★ gap invisible** |
| **E** | partition not in inventory & no image → candidate `None` | **hold=0, orphan=0** | **★ gap invisible** |
| **F/G** | exec `/vendor/...` but binary present under `system:/vendor/...` | **hold=1** | **★ false HOLD (resolver off-by-one)** |
| H | rc contains `start foo`, excuse declares `expected_start_references: 0` | pass=false, orphan=1 | excuse rejected, fail-closed ✅ |
| I | non-airgap **label** excuse + held service | hold_services=1, hold_labels=1 | no double count ✅ |
| J | **airgap** label excuse | hold_labels=0 | non-aggregation ✅ |

**"Should be a HOLD but is not":** C/D/D2/E. The orphan predicate deliberately returns *not-orphan* when every
candidate is `apex|odm|root` or unverifiable, so a genuinely unshipped daemon on `/odm`, `/apex`, `/opt`, or a
partition not covered by inventory is **neither an orphan nor a hold** — invisible even under `--strict-g6`.
This is a **pre-existing orphan-detection boundary**, not introduced by this card, and it does **not** affect
the 13-device totals (abox & init_thermal_config are on `/vendor`).

**"Should NOT be a HOLD but is":** F/G is a real synthetic counterexample. Root cause is a **latent
off-by-one in `_resolve_exec()`** (present in both the approved and live harness):

```python
# approved + live, identical:
if p.startswith("/system/vendor/"):
    return [("vendor", p[len("/system/vendor"):]),
            ("system", p[len("/system") - 1:])]   # ← p[6:] == "m/vendor/...", not "/vendor/..."
```

`_resolve_exec("/system/vendor/bin/wfc-pkt-router")` → `[('vendor','/bin/wfc-pkt-router'),
('system','m/vendor/bin/wfc-pkt-router')]`. When the vendor candidate is present (the real 13-device case:
pktrouter's binary ships in `vendor.img`) this is harmless — which is why it passed. On a **non-vendorimage**
stamp whose vendor binary lives only in `system.img` at `/system/vendor/…`, the corrupted `system` candidate
is never found → **false orphan**, and if excused as `unshipped_vendor_daemon` → **false HOLD**. Not observed
on the 13 stamps; recorded for the tool owner.

**`comet`'s `init_thermal_config` reasoning — verified, could NOT break it (debugfs):**

| device | `init_thermal_config` exec | existence probe | confirmed orphan | held? |
|---|---|---|---|---|
| **comet** | `/vendor/bin/init_thermal_config` | **inventory hit TRUE** (`debugfs stat` → Inode 173, regular, 0755) | **false** | **no** ✅ |
| **rango** | `/vendor/bin/rango_init_thermal_config` | `debugfs` absent | **true** | **yes** ✅ |
| comet/rango `abox` | `/vendor/bin/main_abox` | `debugfs` absent | **true** | **yes** ✅ |

`comet` holds only `abox`; `rango` holds `abox` + `init_thermal_config`. The author's claim is correct.

## 5. Non-aggregation proof — `airgap_excision` never enters `hold_list`

- All 13 real devices: **0** `airgap_excision` entries in any `hold_list` (`qa_rederive.py`).
- All 12 synthetic scenarios (A–J): **0**.
- End-to-end re-classification via `--excisions-file`: `abox` marked `airgap_excision` on the
  `hold-control` fixture → **hold=0**, `pass`, strict exit **0**.
- Code-path proof: `hold_list` is appended only inside `if cls != "airgap_excision"`.

## 6. `--strict-g6` — load-bearing, never over-fires

| Case | strict exit | Meaning |
|---|---|---|
| `hold-control` (holds + otherwise-clean gates) | **1** | strict fires on real holds |
| `clean-control` (genuinely hold-free) | **0** | strict does not fire |
| reclassified `airgap_excision` | **0** | airgap never a hold |
| `hold-control` with omitted `classification:` | **0** | ★ **over-fire would not catch this (residual C)** |
| 13 real devices | 1 (= default 1) | non-decisive here (G5 already red) |

## 7. Tool-closure BLOCKED tri-state — no regression

- `--fixture tool-missing` → **exit 1**; `G2/G3/G6 BLOCKED: required tool unresolved: lz4; unpack_bootimg`
  — BLOCKED never `pass`.
- `--selftest-g4` **0**, `--selftest-excisions` **0**, `--selftest-tools` **0**, `--selftest-blocked` **0**.
- G4 synthetic (`--g4-only --g4-output synthetic-clean-g4.txt`) → **0**; real `--g4-only` → **1**
  (`structural=13 env=HOLD:5`, E-20 UNRESOLVED). Verified twice each; approved and live agree.

## 8. Harness md5 tested

- **Tested (approved):** `.agent-comm/evidence/T-EXCISE-BLOCKED-COVERAGE-AUDIT/gt_boot_safety_gate.py.PRE-AUDIT`
  → md5 **`8a4794ef9820ccc6759e5bfce2a95643`** ✅ (matches the card).
- Live `.agent-comm/tools/gt_boot_safety_gate.py` → `7447e77dbd559a8c0de87a75da2cb4e9` (drift; see §0).

---

## 9. Honesty section (Law 7) — what I could NOT verify

- **The card's md5 does not describe the live harness.** I verified the preserved approved bytes; the live
  file was already replaced by the concurrent audit lane. Behaviour is unregressed on the live bytes, but the
  approval's digest is now historical only.
- **No hardware/build/flash/boot.** All conclusions are static; no device was booted; the non-boot-critical
  assertion for the held daemons was **not** observed on a device.
- **`hold-control` is synthetic** — it proves the counting/strict logic, not a real stamp.
- **Residuals found (none block the card):**
  1. **Latent resolver off-by-one** (§4) — can manufacture a false orphan/HOLD on non-vendorimage stamps;
     harmless on the 13 stamps. Owned by the harness owner.
  2. **Definitional gap C** — an excuse with `classification:` omitted defaults to `airgap_excision` and is
     silently absorbed with **no HOLD and no orphan**, even under `--strict-g6`. A one-line hardening would be
     to require the key explicitly (or fail-closed when absent), but that is a **policy change**, not part of
     this visibility card.
  3. **Orphan boundary D/D2/E** — `/odm`, `/apex`, root and unverifiable partitions are outside orphan/hold
     coverage. Pre-existing.
- **I did NOT run the chmod-based integration control**
  `.agent-comm/tools/gt-tool-missing-fixture.sh` (it hard-codes the **live** harness and temporarily
  `chmod 000`s shared tool binaries — a race risk with the concurrent harness writer). The required
  `--fixture tool-missing` + 4 selftests were run instead and all passed.
- **G4 real-run structural count drifted** from the parent signal (`6/4` → observed `13/5`); exit code 1
  reproduced. The delegated G4 suite is not hermetic (reads the live tree). Not this card's scope.
- **Proxy caveat:** the approved bytes were executed from a `/tmp` proxy root (symlinks) because
  `ROOT = parents[2]`. Both `--selftest-tools` (4/4 resolved) and the real 13-device run confirm the root was
  correct; results match the author's `AFTER` JSON.

## Raw evidence (`.agent-comm/evidence/Q-EXCISE-G6-HOLD-VISIBILITY/`)

`qa-all-devices.approved.json/.txt`, `qa-all-devices.prehold.json/.txt`, `qa-all-devices.approved.strict.*`,
`qa-rederive.txt`, `qa_rederive.py`, `qa-nonregress.txt`, `qa_nonregress.py`,
`qa-hold-falsify.txt`, `qa-hold-falsify.json`, `qa_hold_falsify.py`,
`qa-comet-reason.txt`, `qa_comet_reason.py`,
`fixture-hold-control*.txt`, `fixture-clean-control-strict.txt`, `fixture-tool-missing.txt`,
`selftest-*.txt`, `g4-synthetic.txt`, `g4-real*.txt`, `e2e-*.txt`, `exc-abox-*.yaml`,
`qa-json-excerpt.txt`, `qa-md5-summary.txt`, `qa-exit-codes.txt`, `live-*`.
