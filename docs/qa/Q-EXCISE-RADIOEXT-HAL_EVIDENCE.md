# Q-EXCISE-RADIOEXT-HAL — Evidence

**Task:** `Q-EXCISE-RADIOEXT-HAL` (P0, HIGH, BIG) · **Program:** `DEC-EXCISE-AIRGAP-001`
**Role:** QA Engineer (Panel 4) · **Status:** `REVIEW` (never `APPROVED`)
**Authority:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md`
**depends_on:** `T-EXCISE-RADIOEXT-HAL` ✅ APPROVED (Architect 2026-09-25T21:30Z)
**Run date:** 2026-09-25 ~17:30–17:40 UTC · **Host:** `oss-compute-1`
**Gate -1:** in-process (owner-local `.aegis/governance`; 24 laws + 11 gates) · **Gate 5:** `HUMAN SKIP`
**Honesty:** `BOOT_VERIFIED=false` · `LIVE_FLASH_CLAIMED=false` · `FLASH_READY=false` · no build / stamp / USB / adb / fastboot / commit
**Evidence root:** `.agent-comm/evidence/Q-EXCISE-RADIOEXT-HAL/`
**Harness (QA-authored):** `.agent-comm/evidence/Q-EXCISE-RADIOEXT-HAL/q_radioext_hal_harness.sh`

---

## Headline verdict

> **PASS on all five checks, with one Law-7 precision correction.** The `-V1-ndk` root cause is
> reproduced from the workspace root (exactly 6 device `.mk` vs 13 for the HIDL `@1.0` names), the
> shipped-artifact claim is reproduced by an independent `debugfs` scan (2 sonames present on the
> same 6, absent on the other 7 incl. `tokay` via the global `latest` alias), the fix genuinely
> drops both modules by GNU-make evaluation, and `gate_g5` is proven at code level to read the
> debugfs-extracted merged manifest (never `/vendor/lib64`), so a library-only edit cannot move it.
> **Correction:** the pre-existing finding is *"there is no `tokay-latest`"* — **not** *"`tokay-latest`
> is a dangling symlink"*. The alias does not exist at all; its absence is deliberate (the global
> `latest` alias is tokay's authoritative stamp). No current card's evidence is affected.

| Check | Result | Independently reproduced |
|---|---|---|
| 1. `-V1-ndk` root cause (6 vs 13) | **CONFIRMED** | own count from repo root |
| 2. Shipped `vendor.img` (2 sonames: 6 present / 7 absent) | **CONFIRMED** | own `debugfs` scan of 13 stamps |
| 3. Fix drops both modules, no over-drop | **CONFIRMED** | own make-eval harness, 5 fixtures |
| 4. G5 attribution (manifest, not `/lib64`) | **CONFIRMED** | code trace + own gate run |
| 5. `tokay-latest` finding | **ADJUDICATED — mis-stated, not a tokay defect** | alias inventory + resolver code |
| Negative control (must fail loudly) | **exit 1** (pre-fix fixture) | see Check 3 |
| Over-drop control (must fail loudly) | **exit 1** (keeper over-dropped fixture) | see Check 3 |

---

## Check 1 — root cause: distinct AIDL/NDK modules on exactly 6 device `.mk`

Own count, run from the **workspace root** (`vendor/google_devices/<dev>/<dev>.mk`):

```
device          oem-V1ndk      rex-V1ndk     HIDL@1.0
akita                   0              0     yes(2/2)
blazer                  1              1     yes(2/1)
caiman                  0              0     yes(2/2)
comet                   0              0     yes(2/2)
frankel                 1              1     yes(2/1)
husky                   0              0     yes(2/2)
komodo                  0              0     yes(2/2)
mustang                 1              1     yes(2/1)
rango                   1              1     yes(2/1)
shiba                   0              0     yes(2/2)
stallion                1              1     yes(2/1)
tegu                    1              1     yes(2/1)
tokay                   0              0     yes(2/2)

DEVICES WITH -V1-ndk (6): [blazer, frankel, mustang, rango, stallion, tegu]
DEVICES WITH HIDL @1.0 (13): [all 13]
```

- Count of device `.mk` listing `-V1-ndk` = **6** (tegu, stallion, frankel, blazer, mustang, rango).
- Count of device `.mk` listing HIDL `vendor...oemservice@1.0` **and** `...radioExternal@1.0` = **13/13**.
- **Distinct-module mechanism verified in the Soong source.** `vendor/google_devices/tegu/proprietary/Android.bp`
  defines them as separate `cc_prebuilt_library_shared` modules:
  `…oemservice@1.0` (L3899), `…oemservice-V1-ndk` (L3884), `…radioExternal-V1-ndk` (L3912),
  each `soc_specific: true`, `prefer: true`, `strip: { none: true }`, with **no `required:` consumer**.
- The drop list is wired into every device: `vendor/google_devices/<dev>/<dev>.mk` `include`s
  `vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk` (13/13), which `include`s
  `remove-packages.mk`. In the 6 affected devices the `include` line is **after** the
  `-V1-ndk` `PRODUCT_PACKAGES` entries (e.g. tegu: V1-ndk @L902, include @L3462), so the filter
  executes after the modules are listed.
- Raw: `01`…`04` below.

> The Architect's self-corrected grep error (run from inside `vendor/guardtalk`, where
> `vendor/google_devices` is absent) is **not** present in the current tree and is not reproduced here.

## Check 2 — shipped artifact: 2 sonames present on 6, absent on 7

Own scan — `debugfs -R 'ls -l /lib64' <stamp>/vendor.img | grep -E 'radioExternal|oemservice'`:

| device | alias used | hits | sonames |
|---|---|---|---|
| tegu | `tegu-latest` | **2** | `…oemservice-V1-ndk.so`, `…radioExternal-V1-ndk.so` |
| stallion | `stallion-latest` | **2** | both |
| frankel | `frankel-latest` | **2** | both |
| blazer | `blazer-latest` | **2** | both |
| mustang | `mustang-latest` | **2** | both |
| rango | `rango-latest` | **2** | both |
| shiba | `shiba-latest` | 0 | — |
| husky | `husky-latest` | 0 | — |
| akita | `akita-latest` | 0 | — |
| **tokay** | **global `latest`** | 0 | — |
| caiman | `caiman-latest` | 0 | — |
| komodo | `komodo-latest` | 0 | — |
| comet | `comet-latest` | 0 | — |

- Image is **not sparse**: `file vendor.img` → `Linux rev 1.0 ext2 filesystem data … volume name "vendor"`.
  The image root is the `/vendor` mountpoint (`bin`, `etc`, `lib`, `lib64`, … at `/`), so vendor HAL
  libraries live at `/lib64` — the card's path is correct.
- **Method controls** (prove the scan is non-vacuous): `libbase.so` and
  `android.hardware.boot@1.0.so` = **1 on all 13**; a nonexistent soname = **0 on all 13**
  → `CONTROLS_OK`. (A first pass mistakenly used `libbinder_ndk.so`, a *system* lib absent from
  `/vendor/lib64`; the control failed, was corrected, and the miss is recorded — Law 7.)
- Raw: `01-qa-debugfs-scan.txt`, `09-qa-debugfs-method-controls.txt`.

## Check 3 — the fix genuinely drops both modules (make-eval) and cannot over-drop

Harness `q_radioext_hal_harness.sh` evaluates a drop list under GNU make with a synthetic product
holding the 2 targets, the 2 HIDL names, `liboemservice`, and 5 non-radio keepers
(`GuardTalkValidator`, `GuardTalkConfig`, `GuardTalkMessenger`, `some.unrelated.keep.module`,
`com.android.settings`). It exits 0 iff targets **and** HIDL names are gone **and** every keeper
survives; otherwise it exits non-zero.

| fixture | what it is | exit |
|---|---|---|
| `remove-packages.POSTFIX-SNAPSHOT.mk` | working-tree fix | **0** (PASS) |
| `remove-packages.PREFIX-AUTHORITATIVE.mk` | **authoritative pre-fix** = `git show HEAD:radio-excised/remove-packages.mk` | **1** (2 targets survive) |
| `remove-packages.OVERDROP-FIXTURE.mk` | post-fix with a keeper forced into the drop list | **1** (keeper over-dropped) |
| `remove-packages.WILDCARD-ONLY.mk` | post-fix minus the 2 explicit module names (wildcards only) | **0** |
| `remove-packages.EXPLICIT-ONLY.mk` | post-fix minus the 2 `findstring` tokens (explicit only) | **0** |

- The pre-fix fixture is **authoritative, not reconstructed**: the working tree differs from git
  `HEAD` by exactly the 4 intended additions (`git diff` reproduced in `06`).
- Each arm (explicit module names / wildcard tokens) **independently** removes both targets —
  the hardening is genuine defence-in-depth, not redundant decoration.
- **Over-drop audit:** the two new wildcard tokens (`radioExternal`, `hardware.oemservice`) were
  matched against the full pre-filter module universe (`out/target/product/<dev>/all_modules.txt`)
  for **all 13** devices. Every hit is an intended Samsung SLIS radio HAL module; no non-radio
  module matches (`06-qa-overdrop-audit.txt`).
- **Independent orphan spot-check (string-level):** grepping the built `vendor/{bin,lib64}` of
  `tegu`, `frankel`, `rango` (3 of the 6) for either soname yields **0 consumers** (excluding the
  `.so` themselves) — corroborates the author's orphan proof on a subset
  (`10-qa-orphan-spotcheck.txt`).
- Raw: `02-qa-make-eval.txt`, `03-qa-make-eval-arms.txt`, `06-qa-overdrop-audit.txt`, `06-remove-packages.diff`.

## Check 4 — G5 attribution CONFIRMED (library-only edit cannot move G5)

`gate_g5(ds, …)` consumes only `ds["vintf"]` and `ds["init"]`:

- `forbidden` is built from `all_names` = names parsed out of the **merged manifest XML**
  (`manifest.xml` + `manifest/*.xml` fragments) — `.agent-comm/tools/gt_boot_safety_gate.py:978‑1031`.
- The binary inventory (`bins`) is built only from `/bin`, `/bin/hw`, `/lib64/hw`
  (L490‑500) — **`/lib64` is never read**; grep of the whole tool for `lib64` returns only the four
  `/lib64/hw` lines.
- An independent QA gate run on `frankel` reproduces the baseline: **G5 FAIL, `forbidden=7`,
  `unbacked=1`, `undeclared=0`**, and every forbidden entry is a manifest HAL `<name>`
  (`…hardware.oemservice` ×2 patterns, `android.hardware.bluetooth{,.audio,.finder,.ranging}`,
  `vendor.google.bluetooth_ext`) — **no `.so` or `/lib64` entry**.
- Therefore removing `…-V1-ndk.so` from `/vendor/lib64` cannot change any G5 counter. The lane's
  statement is **correct**. G5 remains RED for reasons owned by other cards
  (`T-EXCISE-VINTF-DMD` oemservice; `T-EXCISE-BT-*` bluetooth).
- Raw: `07-qa-g5-attribution.txt`, `05-qa-g5-frankel.json` / `.stdout.txt`.

## Check 5 — `tokay-latest` adjudication

**Adjudication: the finding is mis-stated. There is no `tokay-latest` symlink at all — dangling or
otherwise — and tokay's lack of a `<dev>-latest` alias is intentional, not a packaging defect.**

- `releases/desktop-flash/tokay-latest` does **not** exist (`test -e` = NOTEXIST; `test -L` = no).
  `find . -name tokay-latest` (excluding `.repo`) → nothing.
- The 12 other program devices each have a valid `<dev>-latest`; tokay's authoritative stamp is the
  global `latest -> tokay-20260725-102506` (resolves OK).
- This is **by design**: `scripts/flash-from-remote.sh:8,23‑24,326‑328` documents and implements
  *"tokay keeps its legacy `latest` bundle alias; every other device uses the `<codename>-latest`
  convention"* and special-cases `tokay) auto_build=…/latest`.
- The gate resolver `.agent-comm/tools/gt_boot_safety_gate.py:222‑229` tries `<dev>-latest` **then**
  the global `latest`, so tokay resolves correctly; tokay appears in the gate's 13-row output with
  its stamp resolved.
- Prior independent work already recorded the accurate statement:
  `EXCISION_LEDGER.md:65,76` (*"no `tokay-latest`; global `latest`"*),
  `Q-EXCISE-13DEV-MATRIX_EVIDENCE.md:45,62`, and
  `A-EXCISE-13DEV-NONREGRESSION_AUDIT.md:268` (*"(ABSENT) … legacy alias, deliberate"*).

**Does it affect any other card's evidence?** No — the ledger, the 13-device matrix and the
non-regression audit all use the global `latest` for tokay and explicitly annotate the absence.
The `T-EXCISE-RADIOEXT-HAL` lane also scanned tokay's `tokay-20260725-102506` stamp directly.

**Latent hazard reported (not this card's defect, no current impact):** the gate resolver's fallback
`STAMPS / "latest"` is **not scoped to tokay**. If any *other* device's `<dev>-latest` were ever
absent, `stamp_dir()` would silently resolve to tokay's stamp and could emit mislabeled evidence.
(Conversely, if a `<dev>-latest` is a *dangling* symlink, `stamp_dir()` returns the broken path
because `is_symlink()` short-circuits — it would fail extraction rather than fall back.) Currently
all 12 `-latest` aliases resolve OK, so there is no live impact. Suggest scoping the fallback to
`dev == "tokay"` in a follow-up gate-tooling card.

- Raw: `08-qa-tokay-adjudication.txt`.

---

## Negative controls (verdict-critical)

| control | fixture | expected | observed |
|---|---|---|---|
| Un-remediated drop list → targets survive | `git HEAD` version | **non-zero** | **exit 1** ✅ |
| Over-drop → keeper removed | post-fix + keeper in drop list | **non-zero** | **exit 1** ✅ |
| debugfs scan non-vacuous | 2 positive + 1 negative soname | positives 1, negative 0 | **CONTROLS_OK** ✅ |

The primary negative control (pre-fix fixture) **fails loudly** with a clear
`ASSERT FAIL: target survived: …` line — a harness that cannot fail is not evidence.

---

## Honesty / Law 7 — what I could NOT verify

- **No rebuild / re-stamp.** The "after" absence is a **source-level** make-eval guarantee. The
  shipped `vendor.img` on the 6 still contains both `.so` until a post-fix build + stamp is produced
  and re-scanned. This card's acceptance item "(d) after a re-stamp, the sonames are absent 13/13"
  is **NOT yet observable** and is stated as an open QA residual.
- **No hardware / USB / adb / fastboot / boot.** `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`.
- **G1 `--verify-sums` not run** by me (presence only in the author's run); not load-bearing here.
- **G5 re-run was single-device (`frankel`)**, not all 13 — the code trace plus the author's 13-row
  capture agree, but I did not re-run the full 13× gate myself.
- **Over-drop audit** covered the built module universes available in `out/target/product/<dev>/`
  (all 13 present) — a static upper bound, not a full build.
- **Orphan proof not fully independently re-derived.** The author's ELF-level proof (0 `DT_NEEDED`
  consumers, no init `.rc` refs, `dmd` dlopens only the already-excised `liboemservice.so`) was not
  re-run in its ELF form; my independent corroboration is a **string-level** consumer scan on
  **3 of the 6** (`tegu`, `frankel`, `rango`) → 0 consumers. Removal is the chosen acceptance path,
  so this is non-load-bearing, but it is a partial, not full, re-derivation.
- The gate-resolver fallback hazard (Check 5) is **reported, not proven exploitable today**.

## Files written (QA artifacts only)

- Evidence doc: `vendor/guardtalk/docs/qa/Q-EXCISE-RADIOEXT-HAL_EVIDENCE.md` (this file)
- Harness: `.agent-comm/evidence/Q-EXCISE-RADIOEXT-HAL/q_radioext_hal_harness.sh`
- Raw: `01-qa-debugfs-scan.txt`, `02-qa-make-eval.txt`, `03-qa-make-eval-arms.txt`,
  `04-qa-device-mk-counts.txt`, `05-qa-g5-frankel.json/.stdout.txt`, `06-qa-overdrop-audit.txt`,
  `07-qa-g5-attribution.txt`, `08-qa-tokay-adjudication.txt`, `09-qa-debugfs-method-controls.txt`,
  `10-qa-orphan-spotcheck.txt`,
  `remove-packages.{PREFIX-AUTHORITATIVE,POSTFIX-SNAPSHOT,WILDCARD-ONLY,EXPLICIT-ONLY,OVERDROP-FIXTURE}.mk`
- Report: `.agent-comm/inbox/TO_ARCHITECT_Q-EXCISE-RADIOEXT-HAL.md`
- Signal: `.agent-comm/signals/review-Q-EXCISE-RADIOEXT-HAL.json`
- History: `.agent-comm/history/2026-09-25T174000+0000-Q-EXCISE-RADIOEXT-HAL.md`

**No product code edited. `TASK_QUEUE.md` NOT edited. Shared `TO_ARCHITECT.md` NOT touched. No commit.**
