# Q-EXCISE-VINTF-DMD — QA EVIDENCE (adversarial verification)

- **Card:** `Q-EXCISE-VINTF-DMD` (P0) · parent `T-EXCISE-VINTF-DMD` ✅ APPROVED (Architect 2026-09-25T21:30Z)
- **Agent:** QA Engineer (Panel 4) · **repository:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`
- **Generated:** 2026-09-25T17:40Z · **status:** REVIEW
- **Honesty:** `BOOT_VERIFIED=false` · `LIVE_FLASH_CLAIMED=false` · `FLASH_READY=false`
  · static analysis only · no build / stamp / flash / boot / device · no `git commit` / `git push`
- **Verdict:** ✅ **VERIFIED for the card's telephony scope** — with **one acceptance-precision
  finding** (the literal "0 telephony/**BT**" acceptance is NOT met; 5 BT refs remain, owned by
  other cards) and **one Law 7 correction to the "source not in tree" caveat** (it IS in tree).

Nothing below trusts a number stated by the lane or the Architect: every figure is re-derived
from the shipped-stamp extraction or from the real gate source.

---

## 1. The claim, and the falsification attempt

**Claim:** dropping the `adevtool_vintf_fragment_vendor_dmd.xml` module removes the
`vendor.samsung_slsi.telephony.hardware.oemservice` declaration, so the runtime-**merged** vendor
manifest carries **0** telephony declarations, **13/13**.

**Result: the claim survives.** The declaration is present **only** in the fragment
`manifest/dmd.xml` and **never** in the main `manifest.xml` on all 13 devices, so removing the
fragment module removes the declaration on the next build. Independently re-derived (not copied):

```
=== A) independent XML declaration scan (13/13)   [q_excise_vintf_dmd_decl_scan.py]
device  oemservice_files  oemservice_in_main  tel_decl_baseline  tel_decl_after_drop  bt_decl_baseline  bt_decl_after_drop
akita   manifest/dmd.xml  False               1                  0                    5                 5
blazer  manifest/dmd.xml  False               1                  0                    5                 5
caiman  manifest/dmd.xml  False               1                  0                    5                 5
comet   manifest/dmd.xml  False               1                  0                    5                 5
frankel manifest/dmd.xml  False               1                  0                    5                 5
husky   manifest/dmd.xml  False               1                  0                    5                 5
komodo  manifest/dmd.xml  False               1                  0                    5                 5
mustang manifest/dmd.xml  False               1                  0                    5                 5
rango   manifest/dmd.xml  False               1                  0                    5                 5
shiba   manifest/dmd.xml  False               1                  0                    5                 5
stallion manifest/dmd.xml False               1                  0                    5                 5
tegu    manifest/dmd.xml  False               1                  0                    5                 5
tokay   manifest/dmd.xml  False               1                  0                    5                 5

SUMMARY: oemservice in MAIN manifest = 0/13; oemservice in dmd.xml ONLY = 13/13;
         telephony declarations after dropping dmd.xml = 0 on 13/13
```

- Scanned `.agent-comm/evidence/T-EXCISE-BOOT-SAFETY-GATE/cache/<dev>/vintf/vendor/` for all 13.
- A raw `rg` over the same tree independently returns the declaration in **exactly 13** files,
  all `manifest/dmd.xml` (main `manifest.xml` hit-count = 0 on every device). The only
  "telephony"-looking substring in some main manifests is the *comment* line
  `Input: vendor/guardtalk/vintf/vendor_manifest_no_radio.xml` — not a declaration.
- Cache identity was checked: each `<dev>/meta.json` names the real `<dev>-latest` stamp
  (e.g. comet → `comet-20260922-160129`, tokay → `tokay-20260725-102506`).

**No second install path.** The fragment is delivered **only** by the `vintf_fragment` module —
there is **no** `PRODUCT_COPY_FILES` entry for `manifest/dmd.xml` and **no** other module
`required:`-ing it (grep over `*.mk`/`*.bp`). So dropping the module is sufficient; a
"copy-files side door" would have falsified the claim and does not exist.

## 2. Module name + wiring proof

| Check | Result |
|---|---|
| `vintf_fragment` module name in `Android.bp` | **13/13** `vintf_fragment { name: "adevtool_vintf_fragment_vendor_dmd.xml", src: "dmd.xml", soc_specific: true }` |
| `<device>.mk` `PRODUCT_PACKAGES` entry | **13/13** (akita:77, blazer:78, caiman:78, comet:79, frankel:77, husky:73, komodo:78, mustang:78, rango:80, shiba:72, stallion:76, tegu:77, tokay:77) |
| filter-out is in `vintf-excised.mk` | lines 100–101 `PRODUCT_PACKAGES := $(filter-out adevtool_vintf_fragment_vendor_dmd.xml, $(PRODUCT_PACKAGES))` |
| **wired** at `guardtalk-radio-excised.mk:26` | confirmed: `include vendor/guardtalk/radio-excised/vintf-excised.mk` |
| `guardtalk-radio-excised.mk` reached from each device | **13/13** direct `include` at the tail of `<device>.mk` (3453–4819) |
| late pass actually runs | `build/make/core/product_config.mk:269` → `-include vendor/guardtalk/radio-excised/product-config-late.mk`; that file rehydrates `PRODUCT_PACKAGES` from `PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES` and re-includes `guardtalk-radio-excised.mk` |

The filter therefore runs **after** the merged list is restored and removes the module on every
GuardTalk product. (`vintf-excised.mk` is the card's exclusive file — `remove-packages.mk:112,128,129`
drop the *sibling* telephony fragments and correctly do **not** own `dmd.xml`.)

## 3. Comet FPC fold — exact-target verification

`gate_g5` on the shipped comet stamp reports the G5 `unbacked` item:

```
{"unit": "vendor.google.bluetooth_ext",   "source": "/vendor/etc/vintf/manifest.xml"}
{"unit": "fingerprint-fpc42_fw49", "names": ["android.hardware.biometrics.fingerprint"],
 "source": "/vendor/etc/vintf/manifest/fingerprint-fpc42_fw49.xml"}
```

`feature-excised/fp-excised.mk`:
- Layer 3 (`:163-166`) filters `adevtool_vintf_fragment_vendor_fingerprint-fpc42_fw49.xml`
  (real `Android.bp` module at `vendor/google_devices/comet/vintf/vendor/manifest/Android.bp:124`,
  `src: fingerprint-fpc42_fw49.xml`; packaged at `comet.mk:80`).
- Layer 4 (`:195-207`) drops the `fingerprint-fpc42_fw49.rc` copy-file (source `comet.mk:1717`);
  the service binary `android.hardware.biometrics.fingerprint-service.fpc42_fw49`
  (`comet.mk:584`) is already dropped by Layer 1's wildcard.

→ **Exact target match.** Wiring: `fp-excised.mk` is included by
`feature-excised/guardtalk-feature-excised.mk:50`, which is included by
`radio-excised/product-config-late.mk:27` (the same late pass). The FPC `unit` on comet is the
only fingerprint `unbacked` item and would move `unbacked` 2 → 1.

## 4. ★ G5 ADJUDICATION — static re-derivation vs gate result (Law 7 core)

**Ran the real gate myself:**

```
$ bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --skip-g4 --json
gate exit code = 1
device  forbidden=7  unbacked  undeclared=0   (13/13, G5 pass=FAIL)
```

`forbidden_refs = 7` on **13/13**, and `forbidden_list` is identical per device:

| # | name | matching pattern |
|---|---|---|
| 1 | `vendor.samsung_slsi.telephony.hardware.oemservice` | `^vendor\.samsung_slsi\.telephony` |
| 2 | `vendor.samsung_slsi.telephony.hardware.oemservice` | `oemservice` |
| 3 | `android.hardware.bluetooth` | `^android\.hardware\.bluetooth` |
| 4 | `android.hardware.bluetooth.audio` | `^android\.hardware\.bluetooth` |
| 5 | `android.hardware.bluetooth.finder` | `^android\.hardware\.bluetooth` |
| 6 | `android.hardware.bluetooth.ranging` | `^android\.hardware\.bluetooth` |
| 7 | `vendor.google.bluetooth_ext` | `^vendor\.google\.bluetooth_ext` |

**Adjudication: the "1 → 0" is a LEGITIMATE STATIC RE-DERIVATION, NOT a gate result — and the
Architect's correction is accurate.** Reasoning:

1. `gate_g5` is a **debugfs consumer** — it reads the *shipped* `vendor.img`/`system.img` of the
   current stamps (pre-fix). Its verdict therefore **still contains** `oemservice` (2 pattern
   matches = 1 declaration) and `forbidden_refs = 7`. It does **not** show 0.
2. The lane's derivation reused the **same `gate_g5` function** on a **projected** merged
   manifest (fragment removed from source) — a *source projection*, not a run over rebuilt
   images. I reproduced that projection exactly:

```
=== B) REAL gate_g5 replay on shipped stamps   [q_excise_vintf_dmd_decl_scan.py]
device  forbidden_baseline  forbidden_after_drop  oem_matches_baseline  oem_matches_after_drop
13/13   7                   5                     2                     0
```

3. Counting conventions are consistent, not contradictory: the lane's **1** counts the one
   *declaration*; the gate's **2** counts that same declaration against **two** forbidden
   regexes (`^vendor\.samsung_slsi\.telephony` and `oemservice`). After the drop both go to 0.

**Conclusion:** the phrase *"statically re-proving gate G5 shows … drop 1 → 0"* is **not an
overstated gate result** — it is correctly a **static re-derivation from source**, but it must
**never** be read as "the gate reports 0". The gate still reports **7 (incl. 2× oemservice)**
until a rebuild lands. The underlying fact (declaration removed on next build) is verified in §1.

**Bonus Law 7 correction (record improved):** the Architect's carried caveat says
"`VintfObject.cpp:282-328` runtime-merge citation … still not independently verified (libvintf
source is not in this tree)". **That is factually wrong — the source IS in this tree** at
`system/libvintf/VintfObject.cpp` (1471 lines). The cited merge semantics are **verified**:
- `:285-287` `fetchVendorHalFragments` seeds `kVendorManifestFragmentDir`
  (`/vendor/etc/vintf/manifest/`) and unions each fragment (`addDirectoryManifests` → `addAll`, `:258`);
- `:314` "A + B means **unioning** `<hal>` tags from A and B";
- `:315-328` `fetchDeviceHalManifest` = vendor manifest + vendor fragments + odm (+ odm fragments).
This **strengthens** the card: the "fragments are merged at runtime" premise is now source-proven,
not assumed. (Still device-runtime-unverified: no boot.)

## 5. ★ Negative fixture — telephony HAL injected into a FRAGMENT

Harness: `vendor/guardtalk/docs/qa/q_excise_vintf_dmd_negative_fixture.py`. It imports the real
gate module **read-only** (nothing in `.agent-comm/tools/` is edited), reuses the gate's own
`build_fixture("clean-control")` as a clean baseline, injects the telephony HAL into a
**fragment only**, and drives the real CLI `main(["--fixture", ...])`.

```
$ python3 vendor/guardtalk/docs/qa/q_excise_vintf_dmd_negative_fixture.py   # HARNESS_EXIT=0
--- clean-control:          process_exit=0 G5.pass=True  forbidden_refs=0 oemservice_hits=0 in_main=False in_fragment=False
--- telephony-in-fragment:  process_exit=1 G5.pass=False forbidden_refs=2 oemservice_hits=2 in_main=False in_fragment=True
      oemservice via '^vendor\.samsung_slsi\.telephony'
      oemservice via 'oemservice'
--- telephony-in-main:      process_exit=1 G5.pass=False forbidden_refs=2 oemservice_hits=2 in_main=True  in_fragment=False

PROOF: oemservice exists ONLY in the fragment (main manifest clean) yet G5 still flags it
       -> the check MERGES fragments, it does not read the main manifest alone.
NEGATIVE FIXTURE HARNESS: PASS — telephony-in-fragment detected by G5 with non-zero process exit; clean control exit 0
```

- **Negative (fragment):** process **exit 1**, G5 **FAIL**, `forbidden_refs=2` — detected.
- **Positive control (clean):** process **exit 0**, G5 PASS.
- **Control (main manifest):** process **exit 1** — a naive main-only check would also catch this,
  which is exactly why the *fragment* case is the decisive adversarial case.
- Raw output: `_q_excise_vintf_dmd/negative_fixture.out`.

This is non-vacuous: it proves the G5 forbidden scan consumes the runtime-merged fragment set, so
the *absence* of `oemservice` in the shipped main manifest is not why the card is passing — the
fragment really is the (only) carrier, and the check really would catch a surviving fragment.

## 6. BT residual — belongs to other cards (NOT `dmd.xml`)

Independent scan: the **5** residual BT `<name>`s are declared in the **main `manifest.xml`**
(`android.hardware.bluetooth`, `.finder`, `.ranging`, `vendor.google.bluetooth_ext`) and in
**`manifest/bluetooth_audio.xml`** (`android.hardware.bluetooth.audio`) — **never** in
`dmd.xml`, and the count is **5 → 5** when `dmd.xml` is dropped. Ownership:

- `android.hardware.bluetooth{,.finder,.ranging}` + `vendor.google.bluetooth_ext` (main manifest)
  → **`T-EXCISE-BT-VINTF-NOBT`** (`TASK_QUEUE.md:7233`, `:7424`, `:7480` — "4 BT HALs declared;
  `vendor_manifest_no_bt.xml` unwired").
- `android.hardware.bluetooth.audio` (`bluetooth_audio.xml`) → **`T-EXCISE-BT-AUDIO-HAL`**
  (`TASK_QUEUE.md:8013`, `:7425`, `:8797`).

`vendor.google.bluetooth_ext` is the remaining comet G5 `unbacked` item and is explicitly outside
this card's exclusive scope. Confirmed: not caused by, and not removable by, this card.

## 7. Acceptance-precision finding (the one thing a reader must not miss)

The card's acceptance text reads "**0 telephony/BT refs** in the runtime-merged manifest, 13/13".
Literally, that is **not met**: after this card the merged manifest still carries **5 BT refs**
(§6) — the telephony share is 0/13 but the *BT* share is 0/13 **not achieved**. The APPROVED
status therefore rests on a **scope narrowing** (telephony only) that the Architect recorded.
This is not a defect in the fix; it is a **precision risk in the record**. QA flags it so no
downstream reader treats the card as having delivered "0 telephony/BT".

## 8. Law 7 — what I could NOT verify

- **No rebuild / re-stamp / flash / boot.** The "after" (0 telephony, 13/13) is what the **next
  build would carry**, computed statically; it is **not** an observed rebuilt `vendor.img` and
  **not** `BOOT_VERIFIED`. `LIVE_FLASH_CLAIMED=false`.
- **Runtime merge not device-verified.** The premise is source-verified
  (`system/libvintf/VintfObject.cpp`, §4), but no device ran `VintfObject` against this image.
- **No `odm.img` in the stamps.** The gate models vendor main+fragments and system main+fragments;
  the stamps ship no separate `odm.img`, so the odm merge path in `fetchDeviceHalManifest` is not
  separately exercised. No evidence of an odm copy of `dmd.xml` exists.
- **`--skip-g4`** was used as instructed; G4 was not evaluated by this run.
- The lane's new finding (no G5 forbidden pattern for `vendor.google.radioext`; not in shipped
  stamps) was **not** re-audited here — out of this card's scope, flagged for the gate owner.

## 9. Hygiene / scope

- Edited **only** under `vendor/guardtalk/docs/qa/**` (this evidence, two QA harness scripts,
  `_q_excise_vintf_dmd/` raw outputs) and `.agent-comm/` (per-task inbox, signal, history).
- **No product code edited** (no `.mk`, `.bp`, tool, or YAML). `TASK_QUEUE.md` **not** edited.
  Shared `.agent-comm/inbox/TO_ARCHITECT.md` **not** touched (per-task file only).
- No `git commit` / `git push`.
- Negative fixture harness monkeypatches the gate module **in memory only**; the tool file on
  disk is byte-unchanged.

## 10. Raw outputs (`vendor/guardtalk/docs/qa/_q_excise_vintf_dmd/`)

| file | what |
|---|---|
| `gate_all_devices_skip_g4.json` | full `--all-devices --skip-g4 --json` run (human table + JSON) |
| `gate_exit_code.txt` | `gate_exit_code=1` |
| `g5_forbidden_summary.tsv` | per-device `forbidden_refs / oemservice / bluetooth / unbacked / pass` |
| `decl_scan.out` | independent XML scan + real-`gate_g5` static replay (JSON) |
| `negative_fixture.out` | negative-fixture harness output + exit code |

Harnesses: `vendor/guardtalk/docs/qa/q_excise_vintf_dmd_decl_scan.py`,
`vendor/guardtalk/docs/qa/q_excise_vintf_dmd_negative_fixture.py`.
