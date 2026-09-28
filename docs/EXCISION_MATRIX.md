# EXCISION_MATRIX.md — GuardTalkOS shared excision variant matrix

> **Card:** `T-PORT-EXCISION-MATRIX` (P0) — `DEC-PORT-GEN8910-001` / `DEC-PORT-GEN8910-002`
> **Status:** implemented, static-verified (`vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh`)
> **Live device/flash evidence:** **none claimed** — `LIVE_FLASH_CLAIMED=false`
> **Selection ≠ runtime excision.** See the ⚠ **Correction register (2026-09-25)** below — this file
> describes which filters the core *selects*, not whether an excision took effect on a shipped image.
> **Unreconciled residuals `D-07`/`D-08` remain `OPEN` (2026-09-26)** — see the ⚠ **Residual** block in
> the correction register; they live in files this card does not own and are *not* resolved here.

This document is the authoritative description of **how the shared excision core decides
what to excise for a given Pixel codename**. It replaces the previous situation where
`zuma` / `zumapro` / `laguna` differences were closed by hand-editing per-device filter
logic — the approach that produced the silent no-op described at the end of this file.

### ⚠ Correction register — 2026-09-25 (`T-EXCISE-MATRIX-DOC-REMEDIATE`)

An earlier reading of this matrix — and the `Q-PORT-MATRIX-PREFLIGHT` approval note at
`TASK_QUEUE.md:6387`, which claimed the QA escalations were *"accepted → docs corrected"* — implied a
**clean, uniformly-applied** excision. The umbrella independent audit `A-EXCISE-AIRGAP-MATRIX`
(`DEC-EXCISE-AIRGAP-001`) **falsified** that implication: the airgap verdict is **`FALSE`** on every
service and every device, and the best honest reading is **`TRUE-WITH-DORMANT-RESIDUALS`** — never `TRUE`.
Sources: `vendor/guardtalk/docs/qa/A-EXCISE-AIRGAP-MATRIX_AUDIT.md` and
`vendor/guardtalk/docs/qa/AUDIT_RESULT_CONSOLIDATED_20260925.md` (36 residuals · 8 CRITICAL). Reachability
and per-cell **Tier** live only in the residual register (`vendor/guardtalk/docs/EXCISION_LEDGER.md` +
`docs/qa/excision_ledger.json`) — **never in this file**.

The six `matrix-vs-EXCISE` disagreement surfaces raised by `A-PORT-MATRIX-R2` §8 (D-01…D-06) are
reconciled **in place** below and recorded here as a dated note rather than deleted (Law 10 audit trail /
Law 11 reversibility). The remaining two of the eight surfaces — **`D-07`** (the `PORT_MATRIX` /
`KERNEL_MATRIX` docs) and **`D-08`** (the shipped `stallion` stamp README) — are carried as a dated
**`OPEN`** residual block below, because they live in files outside this card's exclusive ownership and
no resolution can be asserted from evidence. The D-01…D-06 reconciliation follows:

| # | Cell | Corrected reading | EXCISE anchor |
|---|---|---|---|
| D-01 | §2.1 `zuma` row | `shannon` is the radio excision **set id**, not proof of "full modem/telephony excision" | radio = **FALSE**; modem transport Tier C 10/13 (`C-R1`); baseband 13/13 (`H-R1`); `dmd.xml` 13/13 (`H-R2`) |
| D-02 | §2 / §2.1 radio column + §5 Step 2b | `RADIO_SET := shannon` is *selected* for all 13; **0/13 Tier A** on radio (per-device worst tier **C 9/13, B 4/13**) | `A-EXCISE-RADIO` |
| D-03 | §2 `laguna_muzel` blocklist cell | canonical blocklist **selected**, but factory `vendor_dlkm` in the `frankel`/`blazer`/`mustang` hybrids **defeats** `blocklist nitrous` ⇒ `nitrous` Tier C | `C-B2`, `H-X1` |
| D-04 | §2 `laguna_rango` blocklist cell | `rango-latest` is a hybrid ⇒ `nitrous` Tier C | `C-B2`, `H-X1` |
| D-05 | §6 zero-regression | `androidboot.radio.disabled=1` is **unchanged at board level**, but the flag is **absent from 4/13 laguna stamps** | `D2`, `M-R3` |
| D-06 | §2 blocklist columns | per-variant blocklists are **selected** uniformly, but BT/NFC GKI modules in `system_dlkm/modules.load` have **0 matching blocklist entries (13/13)** | `C-B1` |

**Withdrawal of the unsubstantiated claim.** The `Q-PORT-MATRIX-PREFLIGHT` approval-note wording
*"Escalations QA-W1/W2/I1 accepted → docs corrected"* at `TASK_QUEUE.md:6387` is **withdrawn as
unsubstantiated** (`A-PORT-MATRIX-R2` F-001: the QA deliverable `PORT_MATRIX_GEN8910_PREFLIGHT.md`
still hashes `e71d4006…`, byte-identical to the *pre*-remediation hash QA recorded, and
`grep -cE 'QA-W|QI-1|16-QPR1|asymmetry'` on it = **0**). `QA-W1`/`QA-W2`/`QI-1` therefore stand
**OPEN**, not closed. This dated note preserves the audit trail; the queue line itself is corrected
by the Architect, who is the sole writer of `TASK_QUEUE.md` this wave.

#### ⚠ Residual — `D-07` / `D-08` annotated **OPEN** (2026-09-26, `T-EXCISE-MATRIX-DOC-RESIDUAL`)

`T-EXCISE-MATRIX-DOC-REMEDIATE` reconciled the six surfaces that live in **this** file (D-01…D-06).
Two of the eight surfaces from `A-PORT-MATRIX-R2` §8 are **still unreconciled** because neither carrier
is in this card's exclusive ownership. They are recorded here as **OPEN**, each with a date and a
reason, rather than silently resolved or dropped (Law 7 — no unverified claim; Law 10 audit trail;
Law 11 reversibility). **No prior text has been deleted.**

| # | Carrier (file:line) | Disagreement — matrix says vs EXCISE says | Status | Reason it is NOT resolved here |
|---|---|---|---|---|
| **D-07** | `vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md:344` (wave-A entry prerequisite) + `vendor/guardtalk/docs/KERNEL_MATRIX.md` | `PORT_MATRIX` lists `T-PORT-EXCISION-MATRIX` **`APPROVED`** as a settled wave-A prerequisite, while the umbrella audit registers **8 CRITICALs** and a **`FALSE`** airgap verdict; `QA-W1` (stallion 16-QPR1 lag), `QA-W2` (`build_id` pin asymmetry + undocumented `tegu` pin) and `QI-1` are still unaddressed in both docs. | **OPEN** | Both carrier files are **outside this card's exclusive ownership** (`EXCISION_MATRIX.md` only), so remediation was **not performed**. Evidence the gap persists: `PORT_MATRIX_GEN8910_PREFLIGHT.md` sha256 `e71d40060cda8e44…` (**byte-identical** to QA's pre-remediation hash) and `KERNEL_MATRIX.md` sha256 `35355da1a72bfe18…`; a grep for the tokens `QA-W`, `QI-1`, `16-QPR1`, `asymmetry` returns **0** on both. **Do not read the wave plan as evidence that excision is clean.** |
| **D-08** | `releases/desktop-flash/stallion-20260923-100618/README-FLASH-DESKTOP.md:10` (shipped stamp) | README advertises *"VINTF excised manifest (resolved in the built image): `vendor_manifest_no_radio_stallion.xml`"*, but the shipped `vendor.img` carries `/etc/vintf/manifest/dmd.xml`, which re-declares `vendor.samsung_slsi.telephony.hardware.oemservice` (`IOemService/dm0`, `dm1`) — the "no_radio" claim is **false as written on that stamp**. | **OPEN** | The shipped stamp README is **outside this card's exclusive ownership** (stamp README lane / `F-EXCISE-CLAIM-HONESTY`) and is immutable output of stamp `stallion-20260923-100618`; editing it would tamper with the stamp and re-stamping is out of scope. README sha256 `f2b9e01a217226c0…`; fragment `dmd.xml` sha256 `9909ea142376d376…`. **Do not cite the stamp README as a clean-basis artifact.** |

**Hand-off (open items, 2026-09-26):** closing `D-07` requires the owners of
`PORT_MATRIX_GEN8910_PREFLIGHT.md` / `KERNEL_MATRIX.md`; closing `D-08` requires the stamp/README lane.
Both remain **unresolved**; this note asserts no resolution. No file outside this card's ownership was
touched, and `TASK_QUEUE.md` was not edited (Architect-owned — see
`.agent-comm/evidence/E-TASK-QUEUE-CONCURRENT-WRITER.md`).

---

## 1. The two files that own the decision

| File | Role |
|---|---|
| `vendor/guardtalk/feature-excised/excision-variants.mk` | **Pure data.** Device → variant map, plus per-variant SoC / kernel family / Wi-Fi / touch / fingerprint / radio / canonical `vendor_dlkm.modules.blocklist`. Defines no filter behaviour. |
| `vendor/guardtalk/feature-excised/excision-variant-select.mk` | **Resolver + validator.** Reads the registry, resolves exactly one variant for the product being built, exports `GT_VARIANT_*`, and `$(error)`s on every unknown/ambiguous/drifting case. |

Nothing else in the shared core is allowed to branch on SoC or codename.
`fp-excised.mk`, `radio-excised/guardtalk-radio-excised.mk` and
`feature-excised/guardtalk-feature-excised.mk` **consume** the resolved data.

### Include order

```text
device/google_devices/<codename>/<codename>.mk   (adevtool-generated, sets PRODUCT_DEVICE)
        │
        └── include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
                    └── include feature-excised/excision-variant-select.mk   ← product-time resolve

vendor/google_devices/<codename>/BoardConfig.mk  (late hook)
        │
        └── include vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk
                    └── include feature-excised/excision-variant-select.mk   ← board-time resolve

build/make/core/product_config.mk:269
        └── include vendor/guardtalk/radio-excised/product-config-late.mk
                    ├── include radio-excised/guardtalk-radio-excised.mk       (late pass)
                    └── include feature-excised/guardtalk-feature-excised.mk
```

The resolver is **idempotent**: re-including it recomputes the same values, so being pulled
in from several hooks is safe and cheap.

---

## 2. Variant matrix (the published table)

`GT_VARIANT` is the key. Variants are keyed on the **kernel family**, not on the SoC alone —
see §3 for why.

| Variant | SoC | Kernel family (`device/google/<f>-kernels/`) | Devices | Wi-Fi module(s) | Touch driver(s) | Fingerprint stack | Radio excision set | Canonical `vendor_dlkm.modules.blocklist` |
|---|---|---|---|---|---|---|---|---|
| `zuma_shusky` | `zuma` | `shusky` | `shiba`, `husky` | `bcmdhd4398` | `goodix_brl_touch`, `sec_touch` | **Goodix** | `shannon` | `feature-excised/variants/zuma_shusky/…` |
| `zuma_akita` | `zuma` | `akita` | `akita` | `bcmdhd4383` | `goodix_brl_touch` | **Goodix** | `shannon` | `device/akita/vendor_dlkm.modules.blocklist` |
| `zumapro_caimito` | `zumapro` | `caimito` | `tokay`, `caiman`, `komodo` | `bcmdhd4390` | `syna_touch`, `sec_touch` | **QFP** | `shannon` | `feature-excised/vendor_dlkm.modules.blocklist` |
| `zumapro_comet` | `zumapro` | `comet` | `comet` | `bcmdhd4390` | `goodix_brl_touch`, `syna_touch`, `sec_touch` | **Goodix** | `shannon` | `feature-excised/variants/zumapro_comet/…` |
| `zumapro_tegu` | `zumapro` | `tegu` | `tegu` | `bcmdhd4383` | `syna_touch` | **Goodix** | `shannon` | `feature-excised/variants/zumapro_tegu/…` |
| `zumapro_stallion` | `zumapro` | `stallion` | `stallion` | `bcmdhd4383` | `focal_touch` | **Goodix** | `shannon` | `feature-excised/variants/zumapro_stallion/…` |
| `laguna_muzel` | `laguna` | `laguna` (`…/grapheneos/muzel`) | `frankel`, `blazer`, `mustang` | `bcmdhd4383` + `bcmdhd4390` | `syna_touch`, `focal_touch`, `fst2` | **QFP** | `shannon` | `feature-excised/variants/laguna_muzel/…` |
| `laguna_rango` | `laguna` | `laguna` (`…/grapheneos/rango`) | `rango` | `bcmdhd4383` + `bcmdhd4390` | `syna_touch`, `focal_touch`, `fst2` | **Goodix** | `shannon` | `device/rango/vendor_dlkm.modules.blocklist` |

### 2.1 Per-SoC roll-up (the view the dispatch card asked for)

| SoC | Gen | Wi-Fi module | Touch driver | Fingerprint stack | Radio excision set |
|---|---|---|---|---|---|
| `zuma` | 8 | `bcmdhd4398` (`shusky`) / `bcmdhd4383` (`akita`) | `goodix_brl_touch` (+ `sec_touch` on `shusky`) | **Goodix** (both families) | `shannon` — radio excision **set id only**; runtime radio verdict = **FALSE** (correction register D-01) |
| `zumapro` | 9 | `bcmdhd4390` (`caimito`, `comet`) / `bcmdhd4383` (`tegu`, `stallion`) | `syna_touch`+`sec_touch` (`caimito`), `goodix_brl_touch`+`syna_touch`+`sec_touch` (`comet`), `syna_touch` (`tegu`), `focal_touch` (`stallion`) | **QFP** (`caimito`) / **Goodix** (`comet`, `tegu`, `stallion`) | `shannon` |
| `laguna` | 10 | `bcmdhd4383` **and** `bcmdhd4390` (two-phase load) | `syna_touch`, `focal_touch`, `fst2` | **QFP** (`muzel`) / **Goodix** (`rango`) | `shannon` |

> **Read the per-SoC row as a summary, never as the selector.** Every value that differs
> *within* a SoC is a real, current difference between kernel families (§3).
>
> **Radio excision set (correction register D-01/D-02).** The value in this column is the
> **provisioning set id** (`RADIO_SET := shannon`) that the excision core *selects*. It is **not** a
> reachability verdict: EXCISE found radio **FALSE**, with **0/13 devices at Tier A** (per-device worst
> tier **C 9/13, B 4/13**).
>
> **Canonical blocklist column (correction register D-03/D-04/D-06).** The path is the blocklist file the
> build *selects*. It does **not** assert that every entry takes effect: on the `laguna` hybrids the
> factory `vendor_dlkm` defeats `blocklist nitrous` (`nitrous` Tier C), and BT/NFC GKI modules in
> `system_dlkm/modules.load` have **0 matching blocklist entries (13/13)**. Reachability/Tier lives only
> in the residual register, never here.

---

## 3. Why variants are keyed on kernel family and not on SoC

The dispatch card assumed "per SoC" would be enough. Direct inspection of the upstream
kernel trees proves it is not — the Wi-Fi module and the touch driver differ **inside** a
single SoC, because each device family ships its own kernel tree:

| SoC | Kernel family | Wi-Fi token in the upstream tree blocklist | Touch tokens |
|---|---|---|---|
| `zuma` | `akita` | `bcmdhd4383` | `goodix_brl_touch` |
| `zuma` | `shusky` | `bcmdhd4398` | `goodix_brl_touch`, `sec_touch` |
| `zumapro` | `caimito` | `bcmdhd4390` | `syna_touch`, `sec_touch` |
| `zumapro` | `comet` | `bcmdhd4390` | `goodix_brl_touch`, `syna_touch`, `sec_touch` |
| `zumapro` | `tegu` | `bcmdhd4383` | `syna_touch` |
| `zumapro` | `stallion` | `bcmdhd4383` | `focal_touch` |
| `laguna` | `laguna/muzel` | `bcmdhd4383` + `bcmdhd4390` | `syna_touch`, `focal_touch`, `fst2` |
| `laguna` | `laguna/rango` | `bcmdhd4383` + `bcmdhd4390` | `syna_touch`, `focal_touch`, `fst2` |

A per-SoC-only table would have handed `shiba`/`husky` the `akita` blocklist (wrong Wi-Fi
driver: `bcmdhd4383` instead of `bcmdhd4398`) and `tegu`/`stallion` the `caimito`
blocklist. Keying on the kernel family closes that hole, and the SoC is carried as a
*column* so the per-SoC view above is still published.

### 3.1 Fingerprint divergence, cross-checked independently

The `FP_STACK` column is not an assumption. It is cross-checked against the adevtool vendor
skeleton for each device (`vendor/adevtool/vendor-skels/google_devices/<dev>/<dev>.mk`),
which is the upstream source of truth for which fingerprint HAL a device ships:

| Fingerprint stack | Devices (vendor-skel evidence) |
|---|---|
| **QFP** (`fingerprint-ext-V2-ndk`, no `…-service.goodix`) | `tokay`, `caiman`, `komodo`, `frankel`, `blazer`, `mustang` |
| **Goodix** (`…fingerprint-service.goodix`, or `goodix` provider) | `shiba`, `husky`, `akita`, `comet`, `tegu`, `stallion`, `rango` |

The `verify_port_excision_matrix_static.sh` case 3 asserts this cross-check, so the column
cannot silently drift.

### 3.2 Fingerprint excision token set (data-driven)

`vendordlkm`/fingerprint excision no longer hand-maintains a token list. The resolver builds
the drop set as:

```text
GT_EXCISION_FP_DROP_PATTERNS := sort( COMMON ∪ ⋃variant FP_TOKENS )
```

and `fp-excised.mk` consumes `GT_EXCISION_FP_DROP_PATTERNS` via `findstring` per pattern
(idempotent, so a superset is safe). Adding a variant therefore **automatically** extends
the filter.

Two guards make narrowing impossible:

1. **Registry guard** — the derived union must cover
   `GT_EXCISION_FP_DROP_BASELINE` (the 13 tokens `fp-excised.mk` shipped before this card).
   Missing tokens ⇒ `$(error)`.
2. **`fp-excised.mk` guard** — if the registry was not loaded (standalone include), the
   frozen baseline is used and the file itself re-checks that it is never narrowed.

The union is currently **13 / 13** tokens, i.e. exactly the pre-card behaviour — zero
regression, proven in the QA script.

---

## 4. The loud-failure contract (no silent no-op)

`T-PORT-SHARED-CORE-FIX` was motivated by a device with no variant entry **silently passing
with no excision applied**. Every such path now aborts the build with a named cause:

| Situation | Behaviour | Message names |
|---|---|---|
| No device identity at all (`GUARDTALK_DEVICE` / `PRODUCT_DEVICE` / `TARGET_DEVICE` empty) | `$(error)` | all three variables |
| Device not in `GT_DEVICE_VARIANT_*` and `TARGET_BOARD_PLATFORM` unknown | `$(error)` | the device + the SoC |
| Device not in `GT_DEVICE_VARIANT_*` and `TARGET_BOARD_PLATFORM` matches >1 variant | `$(error)` | the device + the candidate variant list |
| `GUARDTALK_EXCISION_VARIANT` names something not in `GUARDTALK_EXCISION_VARIANTS` | `$(error)` | the bad name + the known variant list |
| `BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE` points at a non-existent file | `$(error)` | the device, the variant, the path |
| Per-device blocklist pin ≠ the variant's canonical file | `$(error)` | both paths + how to register the pin |
| Per-device blocklist pin has extra / missing tokens vs the variant file | `$(error)` | the exact drifting tokens |
| Registry-derived FP token union narrower than the frozen baseline | `$(error)` | the missing tokens |

The resolver **intentionally refuses to guess**. `zuma` has 2 variants and `zumapro` has 4,
so a unique-SoC fallback would be actively dangerous — an unregistered device is rejected as
**ambiguous**, never silently mapped to the first match.

### 4.1 Per-device blocklist pins

A device may pin its **own** blocklist file instead of the variant's canonical one (legacy
QA-anchored paths, or a verified device-local delta). Such a pin is only accepted when it is
*token-identical* to the variant's canonical blocklist. Registered pins today:

| Device | Pin | Why |
|---|---|---|
| `komodo` | `vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist` | device-local copy so `REGEN_HOOKS` stays device-local; token-identical to `zumapro_caimito` canonical (14/14) |

`akita`, `tokay` and `rango` resolve straight to their variant's canonical file — no pin
needed, so no drift surface.

---

## 5. Add a device (recipe)

Follow this in order. Steps 1–3 are the only ones that should ever be necessary.

### Step 1 — prove the variant does not already exist

Check whether the new codename's kernel family is already in `GUARDTALK_EXCISION_VARIANTS`.
Most new devices are rebadges of an existing family:

```bash
rg -n 'GT_VARIANT_|GT_DEVICE_VARIANT_' \
  vendor/guardtalk/feature-excised/excision-variants.mk
```

### Step 2a — the variant already exists (the common case)

Add **one data line** and nothing else:

```makefile
GT_DEVICE_VARIANT_<newcodename> := <existing_variant>
```

That is the whole change. The resolver picks it up, the FP filter is extended automatically
if the variant is new, and the blocklist resolves to the variant's canonical file.

### Step 2b — the variant is new

Add a row to `GUARDTALK_EXCISION_VARIANTS`, a `GT_DEVICE_VARIANT_<dev>` row, and the
per-variant data columns:

```makefile
GUARDTALK_EXCISION_VARIANTS += laguna_newthing
GT_DEVICE_VARIANT_newcodename := laguna_newthing

GT_VARIANT_laguna_newthing_SOC           := laguna
GT_VARIANT_laguna_newthing_KERNEL_FAMILY := laguna
GT_VARIANT_laguna_newthing_WIFI_MODULES  := bcmdhd4383 bcmdhd4390
GT_VARIANT_laguna_newthing_TOUCH_MODULES := syna_touch
GT_VARIANT_laguna_newthing_FP_STACK      := qfp
GT_VARIANT_laguna_newthing_RADIO_SET     := shannon
GT_VARIANT_laguna_newthing_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/laguna_newthing/vendor_dlkm.modules.blocklist
GT_VARIANT_laguna_newthing_FP_TOKENS     := $(GT_EXCISION_FP_TOKENS_QFP)
```

Then create the canonical blocklist by **copying the upstream tree file verbatim and
appending the GuardTalk entries** — never invent entries:

```bash
mkdir -p vendor/guardtalk/feature-excised/variants/laguna_newthing
{ echo '# GuardTalkOS — laguna_newthing canonical blocklist.'
  echo '# Derivation: device/google/laguna-kernels/<ver>/grapheneos/<name>/vendor_dlkm.modules.blocklist'
  echo '#              + blocklist nitrous (T-BT-FULL FR-3). Upstream lines verbatim.'
  cat device/google/laguna-kernels/<ver>/grapheneos/<name>/vendor_dlkm.modules.blocklist
  echo 'blocklist nitrous'
} > vendor/guardtalk/feature-excised/variants/laguna_newthing/vendor_dlkm.modules.blocklist
```

Derive each column from evidence, not from the SoC:

| Column | Evidence source |
|---|---|
| `KERNEL_FAMILY` | `device/google/<family>-kernels/` tree the device's `TARGET_KERNEL_DIR` resolves into (see `KERNEL_MATRIX.md`) |
| `WIFI_MODULES`, `TOUCH_MODULES` | the `blocklist …` lines in that tree's `vendor_dlkm.modules.blocklist` |
| `FP_STACK` | `vendor/adevtool/vendor-skels/google_devices/<dev>/<dev>.mk` (Goodix vs QFP tokens) |
| `RADIO_SET` | the device's modem/telephony stack; the **set id** `shannon` is selected for all 13 — *selection only*, not proof of effective excision (0/13 Tier A; correction register D-02) |
| `BLOCKLIST` | the tree file above + GuardTalk additions |

### Step 3 — add the board hook

Create `vendor/guardtalk/device/<codename>/BoardConfig-excised-late.mk`, modelled on an
existing device, and make sure it:

1. sets `GUARDTALK_DEVICE := <codename>` (board-time `PRODUCT_DEVICE` is not guaranteed),
2. includes `vendor/guardtalk/feature-excised/excision-variant-select.mk`,
3. assigns `BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)`
   (or a registered pin under the same name),
4. ends with `$(call gt-excision-validate-device-blocklist)`.

Then include it from the late hook at the end of
`vendor/google_devices/<codename>/BoardConfig.mk` and record the hook in that device's
`REGEN_HOOKS.md` so `adevtool generate-all` does not lose it.

### Step 4 — wire the product hook

Add `include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk` to the generated
`vendor/google_devices/<codename>/<codename>.mk` after `PRODUCT_DEVICE` is set, and record it
in `REGEN_HOOKS.md`.

### Step 5 — verify

```bash
bash vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh
```

The script's case 2 table is the machine-readable form of §2 — **add the new device's row
there too**, otherwise the matrix and the QA script disagree.

> **If you forget Step 2, the build fails loudly** naming `GT_DEVICE_VARIANT_<codename>` — it
> does not silently produce an unexeced image.

---

## 6. Zero-regression statement for the 4 in-force devices

`tokay`, `akita`, `komodo` and `rango` must be **byte-identical in behaviour** after this
card. Verified by content rematch (this worktree is not a git repository):

| Device | `BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE` before | after | Result |
|---|---|---|---|
| `akita` | `device/akita/vendor_dlkm.modules.blocklist` | same path (variant canonical) | identical |
| `tokay` | `feature-excised/vendor_dlkm.modules.blocklist` | same path (variant canonical) | identical |
| `komodo` | `device/komodo/vendor_dlkm.modules.blocklist` | same path (registered pin, 14/14 tokens) | identical |
| `rango` | `device/rango/vendor_dlkm.modules.blocklist` | same path (variant canonical) | identical |

Also unchanged at board level: `AB_OTA_PARTITIONS` modem filtering, `BOARD_KERNEL_CMDLINE +=
androidboot.radio.disabled=1`, and the fingerprint drop set (13/13 tokens). No
`releases/desktop-flash/*-latest` symlink was touched.

> **Correction (correction register D-05) — "unchanged" is a board-level statement, not a stamp-level
> one.** The `androidboot.radio.disabled=1` flag is **absent from 4/13 laguna stamps**
> (`frankel`, `blazer`, `mustang`, `rango`) — a documented build/stamp skew (`D2`, `M-R3`). Do **not**
> read this row as evidence that the mitigation is present in every shipped image.

---

## 7. Evidence anchors

Everything in this document is re-derivable:

```bash
# upstream kernel-tree truth for Wi-Fi / touch tokens
for f in device/google/{shusky,akita,caimito,comet,tegu,stallion,laguna}-kernels/*/grapheneos*/vendor_dlkm.modules.blocklist; do
  echo "--- $f"; sed -n 's/^blocklist //p' "$f"
done

# fingerprint stack per device
rg -o 'qfp|goodix|biometrics\.fingerprint-service\.\S+' \
  vendor/adevtool/vendor-skels/google_devices/{shiba,husky,akita,tokay,caiman,komodo,comet,tegu,stallion,frankel,blazer,mustang,rango}/*.mk

# registry and resolver
rg -n 'GT_VARIANT_|GT_DEVICE_VARIANT_|GUARDTALK_EXCISION_VARIANTS' \
  vendor/guardtalk/feature-excised/excision-variants.mk

# full static verification (positive + 7 negative cases)
bash vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh
```

---

## 8. The defect this card closes

Before `T-PORT-EXCISION-MATRIX`, the shared core branched on codename/SoC with per-device
filter files, and a device that had no branch **passed silently with no excision applied** —
the image built green while still shipping the excised features. `T-PORT-SHARED-CORE-FIX`
identified that class of silent no-op; this card removes it structurally by making the
selection **data-driven** and by making every unknown/ambiguous/drifting case a build
`$(error)` (§4).

---

*T-PORT-EXCISION-MATRIX — GuardTalkOS Gen 8/9/10 port program.*
