# Q-PORT-MATRIX-PREFLIGHT — adversarial evidence (`REVIEW`)

> **Task:** `Q-PORT-MATRIX-PREFLIGHT` (PROGRAM GATE, P0) — QA Engineer (Panel 4)
> **Pair:** `T-PORT-MATRIX-PREFLIGHT` (Architect-approved 2026-09-21, 13 GO / 0 NO-GO, Gate 5 88/100)
> **Deliverable under test:** `vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md`
> **Status of this task:** **`REVIEW`** — never `APPROVED` by QA.
> **Date:** 2026-09-21 ~15:0x UTC
> **Harness:** `vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh`
> **Harness exit code (real inputs):** **0** — `113 checks passed, 2 warning(s)`
> **Harness exit code (negative control):** **1** — corrupt input correctly rejected
> **`LIVE_FLASH_CLAIMED=false`. No device attached. No on-device / boot / flash claim. No commit.**

---

## 0. Gate -1 (in-process) record — STEP 0

| Check | Result |
|-------|--------|
| `governance_loaded` | **true** — `.aegis/governance/laws/` = **24** YAML (`law_00_human_authority.yaml` … `law_23_observability.yaml`); `.aegis/governance/gates/` = **11** YAML (`gate_neg1_guardian_first.yaml` … `gate_09_rollback.yaml`). `.aegis` is a relative symlink to `../aegis-global`. |
| `scope_confirmed` | **true** — adversarially falsify the delivered 13-device matrix; write only the five target paths; touch no product code, no deliverable, no `doctrine/`, no `governance/{laws,gates}/`, no secrets. |
| `authority_context_resolved` | **true** — owner-root `TASK_QUEUE.md` (card block "PROGRAM: GuardTalkOS Gen 8/9/10 Port"); `repository_id=grapheneos-worktree`; `.aegis-config.json` `gate_minus1.mode: in_process`, `discover_remote_tools=false`, `call_verifier=false`, `call_guardian=false`. |
| Remote governance calls | **NONE.** `aegis-verifier`, `ask_guardian`, `gate_enforcer`, and Guardian HTTP were **not** called or discovered. |

Laws applied in-process: 0 (human authority), 2 (scope), 4 (security), 6 (minimal footprint),
7 (self-doubt), 9 (graceful degradation), 10 (audit), 11 (reversibility), 12 (doctrine
immutability), 16 (testing), 17 (privacy), 18 (performance), 19 (documentation), 20 (compat),
22 (dependency hygiene), 23 (observability).

**Authority note (no git):** this worktree has **no** `.git` at root or parent (confirmed by
`ls`). Correctness is by **content rematch**; no git provenance is claimed.

---

## 1. Method

QA never copies a value from the deliverable to "verify" it. Every row is re-derived from a
**primary source** and then compared to the deliverable's claim:

| Field | Independent source of truth |
|---|---|
| `PRODUCT_MODEL` | `vendor/adevtool/vendor-skels/google_devices/<dev>/<dev>.mk` |
| SoC | `vendor/adevtool/config/mk/google_devices/device/<dev>/` `platform/<soc>` refs |
| build-index coverage | `vendor/adevtool/config/build-index/build-index-main.yml` (`^<dev> ` block headers) |
| kernel dir (cur) | `build/release/flag_values/cur/RELEASE_KERNEL_<DEV>_DIR.textproto` (8) + literal `TARGET_KERNEL_DIR :=` (5) |
| upstream support | `https://releases.grapheneos.org/<dev>-stable` (live) |
| stock factory | `https://dl.google.com/dl/android/aosp/<zip>` (live HEAD), zip name from build-index |
| tool ground truth | `vendor/adevtool/bin/run show-status` (node v24.21.0) |
| advertise surface | `vendor/guardtalk/web-installer/src/types.ts`, `vendor/guardtalk/scripts/pack-webinstall-channel.sh` |

Harness: `bash vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh`
(`NETWORK=0` skips the live probes; `MATRIX_DOC=<path>` retargets the deliverable — used by the
negative control). It exits **non-zero** when any attack succeeds.

---

## 2. Attack results — summary

| # | Attack | Verdict | Note |
|--:|--------|:------:|------|
| 1 | Invented codename / codename-set tampering | **DEFENDED** | matrix = exactly 13, order preserved |
| 2 | Wrong `PRODUCT_MODEL` mapping | **DEFENDED** | 13/13 match source `.mk`; `stallion` = "Pixel 10a" |
| 3 | Supported device with no build-index entry | **DEFENDED** | all 13 ≥ 5 entries; counts reproduce exactly |
| 4 | Supported device with no upstream support | **DEFENDED** | 13/13 `<dev>-stable` HTTP 200, all `2026091900` |
| 5 | Claimed-PASS with no obtainable factory image | **DEFENDED** | 13/13 pinned factories HEAD 200; stallion pinned **and** newest 200 |
| 6 | Gen 6/7 codename leakage | **DEFENDED** | zero hits outside the explicit "out of scope" lines |
| 7 | `stallion` PASS ignoring its 5-entry index | **DEFENDED** | index/stale-pin risk engaged (§5/§9/§12) |
| a | 4 absorbed `trunk_staging` NO-GO triggers | **DEFENDED (precedent holds)** | `cur` resolves all 13; documented akita/rango precedent confirmed in-force |
| b | `build_id` pin asymmetry | **DEFENDED (source)**, **WARN (deliverable)** | only `stallion`/`tegu`/`rango` pin — confirmed; deliverable does not state it |
| c | `stallion` 16-QPR1 platform lag | **DEFENDED (source)**, **WARN (deliverable understates)** | lag real; deliverable never names it |
| d | `adevtool show-status` cross-check | **DEFENDED** | resolves a build id for all 13; present-set is mutable (download running) |

**No attack overturned a GO, and no P0 (Gen 6/7 leakage) was found.** Two genuine
**understatement** findings are raised (§7) — they are documentation gaps already captured by
the Architect, not GO-breakers. **QA does not recommend withdrawing any part of the approval.**

---

## 3. Attack-set evidence (raw command + output)

### Attack 1 — invented codename
Method: parse the section-2 matrix table; assert the device set is **exactly** the 13 expected
codenames in order.
```
$ bash vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh
--- attack 1: codename set is exactly the 13 (invented codename) ---
PASS: attack1: exactly 13 codenames, no invented/extra codename (order preserved)
```
Negative control (§6) appends a fake row `zephyr` → `FAIL: attack1: matrix has 14 device rows, expected 13`.

### Attack 2 — wrong `PRODUCT_MODEL` mapping
```
$ for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    grep -m1 'PRODUCT_MODEL' vendor/adevtool/vendor-skels/google_devices/$d/$d.mk; done
shiba    | PRODUCT_MODEL := Pixel 8
husky    | PRODUCT_MODEL := Pixel 8 Pro
akita    | PRODUCT_MODEL := Pixel 8a
tokay    | PRODUCT_MODEL := Pixel 9
caiman   | PRODUCT_MODEL := Pixel 9 Pro
komodo   | PRODUCT_MODEL := Pixel 9 Pro XL
comet    | PRODUCT_MODEL := Pixel 9 Pro Fold
tegu     | PRODUCT_MODEL := Pixel 9a
stallion | PRODUCT_MODEL := Pixel 10a          <-- trap confirmed
frankel  | PRODUCT_MODEL := Pixel 10
blazer   | PRODUCT_MODEL := Pixel 10 Pro
mustang  | PRODUCT_MODEL := Pixel 10 Pro XL
rango    | PRODUCT_MODEL := Pixel 10 Pro Fold
```
Verdict: **DEFENDED** — 13/13 match; `stallion` = "Pixel 10a" as the brief specifies.

### Attack 3 — build-index coverage
```
$ for d in <13>; do printf "%-9s %s\n" "$d" "$(grep -cE "^$d " vendor/adevtool/config/build-index/build-index-main.yml)"; done
shiba 58 | husky 58 | akita 46 | tokay 47 | caiman 46 | komodo 46 | comet 45 | tegu 29
stallion 5 | frankel 29 | blazer 29 | mustang 29 | rango 24
```
Verdict: **DEFENDED** — every device has ≥ 1 entry (min = `stallion` = 5); harness also asserts
each deliverable-stated count equals the recomputed count.

### Attack 4 — upstream GrapheneOS support (independent, live)
```
$ for d in <13>; do curl -s -o /tmp/s -w "$d %{http_code} " https://releases.grapheneos.org/$d-stable; cat /tmp/s; done
shiba     HTTP 200  2026091900 1789794102 shiba stable
husky     HTTP 200  2026091900 1789794102 husky stable
akita     HTTP 200  2026091900 1789794102 akita stable
tokay     HTTP 200  2026091900 1789794102 tokay stable
caiman    HTTP 200  2026091900 1789794102 caiman stable
komodo    HTTP 200  2026091900 1789794102 komodo stable
comet     HTTP 200  2026091900 1789794102 comet stable
tegu      HTTP 200  2026091900 1789794102 tegu stable
stallion  HTTP 200  2026091900 1789794102 stallion stable
frankel   HTTP 200  2026091900 1789794102 frankel stable
blazer    HTTP 200  2026091900 1789794102 blazer stable
mustang   HTTP 200  2026091900 1789794102 mustang stable
rango     HTTP 200  2026091900 1789794102 rango stable
```
Verdict: **DEFENDED** — no device failed; all 13 agree on release id `2026091900`.

### Attack 5 — stock factory obtainability
```
$ # build id from adevtool show-status; zip name from build-index; HEAD dl.google.com
PASS: attack5: shiba    BP4A.260205.001     factory HEAD 200 (shiba-bp4a.260205.001-factory-35b8480d.zip)
PASS: attack5: husky    BP4A.260205.001     factory HEAD 200 (husky-bp4a.260205.001-factory-61e86561.zip)
PASS: attack5: akita    BP4A.260205.001     factory HEAD 200 (akita-bp4a.260205.001-factory-661cb49b.zip)
PASS: attack5: tokay    BP4A.260205.002     factory HEAD 200 (tokay-bp4a.260205.002-factory-45177450.zip)
PASS: attack5: caiman   BP4A.260205.002     factory HEAD 200 (caiman-bp4a.260205.002-factory-df6fb7c7.zip)
PASS: attack5: komodo   BP4A.260205.002     factory HEAD 200 (komodo-bp4a.260205.002-factory-aaec4834.zip)
PASS: attack5: comet    BP4A.260205.002     factory HEAD 200 (comet-bp4a.260205.002-factory-f5d0eeaf.zip)
PASS: attack5: tegu     BP4A.260205.001     factory HEAD 200 (tegu-bp4a.260205.001-factory-1c69f00a.zip)
PASS: attack5: stallion BD6A.251031.001.A4  factory HEAD 200 (stallion-bd6a.251031.001.a4-factory-7420a527.zip)  [PINNED]
PASS: attack5: frankel  BP4A.260205.001     factory HEAD 200 (frankel-bp4a.260205.001-factory-679ee187.zip)
PASS: attack5: blazer   BP4A.260205.001     factory HEAD 200 (blazer-bp4a.260205.001-factory-44af5c18.zip)
PASS: attack5: mustang  BP4A.260205.001     factory HEAD 200 (mustang-bp4a.260205.001-factory-b22707a4.zip)
PASS: attack5: rango    CP1A.260505.005     factory HEAD 200 (rango-cp1a.260505.005-factory-18bf79d9.zip)
PASS: attack5: stallion extra factory HEAD 200 (stallion-bd6a.251031.001.a4-factory-7420a527.zip)   # pinned
PASS: attack5: stallion extra factory HEAD 200 (stallion-cp1a.260505.005.a1-factory-5ccba036.zip)    # newest
```
Verdict: **DEFENDED** — nothing fails to fetch. `stallion`'s pinned **and** newest images both 200.

### Attack 6 — Gen 6/7 leakage (P0)
```
$ grep -nE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro' PORT_MATRIX_GEN8910_PREFLIGHT.md | grep -v 'out of scope'
(no output)
```
Verdict: **DEFENDED** — the only occurrences are the explicit §13 out-of-scope statement
(lines 375–376) and the guard command itself (line 410, which literally contains
`'out of scope'`). No Gen 6/7 codename appears in the wave plan, any verdict, or any advertise
surface. `ALLOWED_PRODUCTS = ["tokay","akita","komodo","rango"]` and
`ADVERTISED_DEVICES=(tokay akita komodo rango)` are unchanged.

### Attack 7 — `stallion` thin-margin engagement
```
$ grep -n 'stallion' PORT_MATRIX_GEN8910_PREFLIGHT.md
131:- **F4 — `stallion` pins the oldest of its 5 builds.** ...
217:builds, and the device config pins the **oldest** ... (`BD6A.251031.001.A4`). ...
308:| 9 | `stallion` | **GO** | Thin index: 5 main builds, stale pin (oldest) ... if the pin is withdrawn, stallion becomes **NO-GO**. |
361:| `stallion` stale pin / 5-entry index | **watch** | Documented §5/§9; re-check before FLASH. |
```
Verdict: **DEFENDED** — the deliverable names the 5-entry index, the stale pinned build, the
withdrawal contingency, and registers it in the HOLDS/watch register. *See vector (c) for the
part of the stallion risk the deliverable does **not** state.*

---

## 4. Architect-supplied vectors (a)–(d)

### Vector (a) — the four absorbed NO-GO triggers (`shiba`/`husky`/`comet`/`tegu`)
Challenge attempted: is "defined variable but **absent directory**" really a LAYER prerequisite
rather than a NO-GO?

Evidence (live):
```
trunk_staging flag values (defined) and resolved dir existence:
shiba    -> device/google/shusky-kernels/6.1/trunk-14096387   ABSENT
husky    -> device/google/shusky-kernels/6.1/trunk-14096387   ABSENT
comet    -> device/google/comet-kernels/6.1/trunk-14096387    ABSENT
tegu     -> device/google/tegu-kernels/6.1/trunk-14096387     ABSENT
akita    -> device/google/akita-kernels/6.1/grapheneos        EXISTS (dir)
caiman   -> device/google/caimito-kernels/6.1/trunk-14096387  EXISTS (symlink -> grapheneos)
komodo   -> device/google/caimito-kernels/6.1/trunk-14096387  EXISTS (symlink -> grapheneos)
cur channel: all 13 resolve to an existing dir (no symlink needed).
```
Precedent confirmed on disk **and** in the in-force docs:
```
device/google/akita-kernels/6.1/trunk-14096387 -> grapheneos   (symlink exists)
device/google/caimito-kernels/6.1/trunk-14096387 -> grapheneos (symlink exists)
device/google/laguna-kernels/6.6/trunk-14072179 -> grapheneos  (symlink exists)
AKITA_PORT_PREFLIGHT.md:46  "lunch akita-trunk_staging-userdebug FAIL ... missing ...trunk-14096387..."
AKITA_PORT_PREFLIGHT.md:120 "akita-kernels/6.1/trunk-14096387 -> grapheneos/"
RANGO_PORT_PREFLIGHT.md:31  "RELEASE_KERNEL_RANGO_DIR ... trunk-14072179/rango — directory absent (same class of gap as akita trunk-14096387; LAYER resolves via symlink)"
```
**Judgement: the precedent covers the four.** The failure is an *absent directory under a
defined flag*, not an *unresolved variable*; the identical gap was closed at LAYER for akita,
and rango's preflight documents the same "absent directory, LAYER symlink" class. Decisively,
the **`cur` production lunch resolves for all 13 with no symlink**, so the GO does not depend on
the LAYER fix. **QA does not escalate this to a NO-GO.**

*Citation nuance (informational, not a defect):* akita's and rango's `trunk_staging` flags have
since been updated upstream to point directly at `grapheneos`, so today the *currently exercised*
`trunk-<buildid>` symlink precedent is the **caimito** one (caiman/komodo). The akita/rango
symlinks now exist but are not exercised by the current flag values. This does not change the
classification.

### Vector (b) — `build_id` pin asymmetry
```
$ for d in <13>; do grep -E 'build_id' vendor/adevtool/config/device/$d.yml; done
tegu      build_id: BP4A.260205.001
stallion  build_id: BD6A.251031.001.A4
rango     build_id: CP1A.260505.005
   (the other 10: no build_id line)
```
Claim tested: *the other 10 need no pin.* **Confirmed** — `adevtool show-status` resolves a build
id for all 10 (BP4A.260205.001/002). **WARN:** the deliverable does **not** state this asymmetry
(it is an Architect addition only). Recorded, not a GO-breaker.

### Vector (c) — `stallion` platform lag (16 QPR1)
```
$ grep -n '16 QPR1\|Multiuser' vendor/adevtool/config/device/stallion.yml
  # BD6A.251031.001.A4 is a 16 QPR1 image, so Multiuser isn't in stock.
  # TODO: Remove when stallion is not using 16 QPR1 image
  - Multiuser
$ grep -c 'sdk_full = 36.0' vendor/adevtool/config/device/stallion.yml
9
$ grep -E '^stallion ' build-index-main.yml | tail -1
stallion CP1A.260505.005.A1:     # newest, newer than the pinned BD6A.251031.001.A4
```
Assessment: the lag is **real and material** — the pin is the oldest of 5, is a 16-QPR1 image
requiring a `Multiuser` extra-package workaround and 9 `sdk_full` 36.0 exclusions, while 4 newer
images exist. **The deliverable understates this**: it says only "stale pin (oldest)" and never
names the 16-QPR1 platform gap. **GO remains defensible** because the *pinned* build is
downloadable today (HEAD 200) and `generate-all` is provable now; the risk is a *future
withdrawal*, which the deliverable does register as a FLASH-time re-check. **WARN + escalate.**

### Vector (d) — `adevtool show-status` cross-check
```
$ export PATH="$HOME/.local/toolchain/node/bin:$PATH"; vendor/adevtool/bin/run show-status
Tag | Build ID:
[no tag] | CP1A.260505.005: rango
[no tag] | BP4A.260205.001: mustang blazer frankel tegu akita husky shiba felix tangorpro lynx
[no tag] | BD6A.251031.001.A4: stallion
[no tag] | BP4A.260205.002: comet komodo caiman tokay
[no tag] | BP4A.251205.006: cheetah panther bluejay raven oriole
...
Stock image:
  factory:
    present: rango comet komodo caiman tokay akita
    known:   mustang blazer frankel stallion tegu comet husky shiba felix tangorpro lynx ...
```
Findings:
- The tool resolves a build id for **all 13** — matches the deliverable's §7 exactly.
- **The Architect-supplied "present = exactly `rango,komodo,tokay,akita`" (4) is now 5 (+`caiman`,
  and `comet` mid-download).** This is **not** a deliverable defect: the Operator is running
  `adevtool download` concurrently (confirmed: `caiman-*.zip` complete 14:57, `comet-*.zip.tmp`
  growing 14:59). The present-set is **mutable** and must not be treated as a fixed invariant.
  The deliverable's "4 cached" statement was true when written.

---

## 5. Full harness run (real inputs) — exit 0

```
$ bash vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh
===================================================================
Q-PORT-MATRIX-PREFLIGHT adversarial harness
ROOT      : /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
MATRIX_DOC: /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md
NETWORK   : 1
===================================================================
--- attack 1: codename set is exactly the 13 (invented codename) ---
PASS: attack1: exactly 13 codenames, no invented/extra codename (order preserved)
--- attack 2: PRODUCT_MODEL vs vendor-skels ---
PASS: attack2: shiba -> 'Pixel 8' ... (13/13 PASS)
--- attack 3: build-index-main.yml coverage ---
PASS: attack3: shiba has 58 ... stallion has 5 ... rango has 24   (13/13 PASS)
--- attack 2c: SoC platform + cur-channel kernel dir existence ---
PASS: attack2c: <dev> SoC '<soc>' (deliverable agrees)   (13/13 PASS)
PASS: attack2c: <dev> cur-channel kernel dir exists ...   (13/13 PASS)
--- attack 4: upstream releases.grapheneos.org/<dev>-stable ---
PASS: attack4: <dev>-stable HTTP 200 build id 2026091900  (13/13 PASS)
PASS: attack4: all 13 -stable endpoints agree on release id: 2026091900
--- attack 5: stock factory obtainability (HEAD dl.google.com) ---
PASS: attack5: <dev> <buildid> factory HEAD 200 ...        (13/13 PASS)
PASS: attack5: stallion extra factory HEAD 200 (pinned + newest)
--- attack 6: Gen 6/7 codename leakage ---
PASS: attack6: no Gen 6/7 codename outside an explicit out-of-scope line
PASS: attack6: advertise surfaces name no Gen 6/7 codename
PASS: attack6: ALLOWED_PRODUCTS unchanged (tokay akita komodo rango)
--- attack 7: stallion thin-margin engagement ---
PASS: attack7: stallion 5-entry index + stale-pin risk engaged (§5/§9/§12)
--- vector a: trunk_staging dir absence classification ---
PASS: vectorA: shiba/husky/comet/tegu flag DEFINED but dir absent -> LAYER prerequisite, not NO-GO
PASS: vectorA: precedent symlink present: akita / caimito / laguna
PASS: vectorA: cur channel resolves for all 13 (GO is safe under the production lunch)
PASS: vectorA: deliverable classifies the absences as a LAYER prerequisite
--- vector b: build_id pin asymmetry ---
PASS: vectorB: exactly {rango stallion tegu} pin a build_id; the other 10 resolve with no pin
WARN: vectorB: deliverable does NOT state the pin asymmetry (Architect addition only; ...)
--- vector c: stallion 16-QPR1 platform lag ---
PASS: vectorC: stallion.yml documents the 16 QPR1 stock gap
PASS: vectorC: stallion.yml carries the Multiuser extra-package workaround
PASS: vectorC: stallion.yml carries 9 'sdk_full = 36.0' exclusions
PASS: vectorC: newest index entry CP1A.260505.005.A1 is newer than the pinned BD6A.251031.001.A4
WARN: vectorC: deliverable UNDERSTATES stallion ...
--- vector d: stock factory present-set (informational) ---
INFO: show-status factory present: rango comet komodo caiman tokay akita
INFO: (this set is MUTABLE while 'adevtool download' runs; do not treat as a fixed invariant)
===================================================================
RESULT: PASS — all attacks failed; 113 checks passed, 2 warning(s).
===================================================================
```
(The full raw transcript is 140 lines; the above elides only repeated per-device PASS lines,
which are enumerated 13× each in the live run.)

---

## 6. Negative control — proving the harness is NOT vacuous

The protected deliverable was **never edited**. A corrupted **copy** was made and the harness
was pointed at it with `MATRIX_DOC=`:
```
$ cp PORT_MATRIX_GEN8910_PREFLIGHT.md /tmp/qmatrix_negctl/corrupted.md
# corruptions: (1) shiba PRODUCT_MODEL Pixel 8 -> Pixel 9
#              (2) append invented row `zephyr` (14th device)
#              (3) append line "Wave Z covers panther immediately."
$ MATRIX_DOC=/tmp/qmatrix_negctl/corrupted.md NETWORK=0 bash verify_port_matrix_preflight_static.sh
FAIL: attack1: matrix has 14 device rows, expected 13
FAIL: attack2: shiba deliverable model 'Pixel 9' != expected 'Pixel 8'
FAIL: attack6: 'panther' leaked outside an out-of-scope line: 449:Wave Z covers panther immediately.
RESULT: FAIL — at least one attack succeeded; 81 passed, 2 warning(s).
NEGCTL_EXIT=1
```
Then re-running against the **real** deliverable returns `RESULT: PASS ... EXIT=0`. The harness
is therefore **non-vacuous**: it fails on an invented codename, a wrong model mapping, and a
Gen 6/7 leak, and passes only on the genuine artifact. The corrupted copy lives in `/tmp` only;
nothing under the worktree was modified.

---

## 7. Findings raised (falsifications / escalations)

**No GO was overturned. No P0 was found. QA does NOT recommend withdrawing any part of the
13 GO / 0 NO-GO approval.** Two understatement warnings are escalated:

- **QA-W1 (vector c, MEDIUM — documentation):** the deliverable's `stallion` GO engages only the
  "5-entry index / stale pin (oldest)". It does **not** name the underlying **16-QPR1 platform
  lag** (`stallion.yml`'s `Multiuser` workaround + 9 `sdk_full = 36.0` exclusions) while 4 newer
  images exist. This is exactly the risk the Architect folded into `T-PORT-STALLION-PREFLIGHT`.
  **Recommendation:** Architect confirm `T-PORT-STALLION-PREFLIGHT` explicitly carries the
  16-QPR1 lag (TASK_QUEUE §4b already does), and that `T-PORT-STALLION-FLASH` re-verifies the
  pin. No approval withdrawal required.
- **QA-W2 (vector b, LOW — documentation):** the deliverable does not state the `build_id` pin
  asymmetry (only `stallion`/`tegu`/`rango` pin). Architect addition only. No GO-breaker.

Additional informational note:
- **QA-I1 (vector d):** the "stock factory present" set from `adevtool show-status` is **mutable**
  while the Operator's `adevtool download` is running (observed 5 present, `comet` mid-download,
  vs the Architect's 4). Any task that asserts a fixed present-set will be flaky while downloads
  are in flight.

---

## 8. What QA could NOT verify (and why)

1. **No git provenance.** The worktree is not a git repository (no `.git` at root or parent), so
   "nothing was modified" is asserted by **content rematch** and by the untouched
   `sha256 = e71d40060cda8e444eaf2f2ea447a40f149aa0b73a26d2b5b1a2e12da8ef3848` of the deliverable
   — not by `git status`.
2. **No on-device / boot / flash verification.** No phone is attached to this host
   (`DEC-009`, `LIVE_FLASH_CLAIMED=false`). The `rango` promotion and every on-device smoke remain
   `HOLD`. QA makes no boot-green claim.
3. **No `generate-all` execution.** The Operator is running `adevtool download` into
   `vendor/adevtool/dl/`; QA deliberately did **not** run `download`/`generate-all` (per the
   dispatch) to avoid interfering. Factory **obtainability** is proven by live HEAD only, not by
   generation.
4. **`komodo` debug sidecar** remains unverified (separate B6 program) — out of scope here.
5. **The `adevtool show-status` present-set** is not a stable invariant while downloads run (QA-I1).
6. **No hardware/HAL runtime behaviour** for any of the 13 (no device) — the matrix is
   prerequisites-only, as scoped.

---

## 9. Files written by this task

```
vendor/guardtalk/docs/qa/Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md   (NEW — this file)
vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh (NEW — harness; +x)
TASK_QUEUE.md                                                  (card status -> REVIEW)
.agent-comm/inbox/TO_ARCHITECT.md                              (REPLACED — report)
.agent-comm/history/                                           (append-only entries)
```
Nothing else was written. No product code, no `vendor/guardtalk/device/*`, no
`feature-excised/*`, no `releases/desktop-flash/*`, and **not** the deliverable under test
(read-only) were modified. No commit.

---

## 10. Gate 5 — Ultimate Critique self-score

**Self-score: 90 / 100** (threshold 70; `HUMAN SKIP` not invoked).

| Dimension | Score | Note |
|---|:--:|---|
| Independent re-derivation | 20/20 | All 13 rows re-derived from primary sources + live upstream; none copied. |
| Adversarial rigour | 19/20 | All 7 attacks + vectors (a)–(d) attempted; negative control proves non-vacuity. |
| Evidence discipline (Law 7.2) | 18/20 | Raw command+output per attack; two WARNs traced to source lines. |
| Honesty / non-claims | 10/10 | No flash/boot claim; git limitation and download interference disclosed. |
| Residual-risk escalation | 9/10 | QA-W1/W2 escalated with no GO withdrawal; precise recommendation. |
| Re-runnability | 14/20 | Harness is deterministic except the live network + mutable show-status present-set; `NETWORK=0` mode provided but the present-set note is informational only. |

**Alternatives considered.** (a) Marking the four `trunk_staging` absences a NO-GO — rejected:
the variable resolves, `cur` resolves for all 13, and the akita/rango precedent is documented
in-force. (b) Failing the harness on the `stallion` 16-QPR1 understatement — rejected: the source
risk is real but the pinned build is fetchable today and the Architect already folded the
finding into `T-PORT-STALLION-PREFLIGHT`; a WARN + escalation is the honest severity, and the GO
is not overturned. (c) Trusting the Architect's `show-status` present-set — rejected in favour of
re-running the tool, which revealed the set is mutable.

**Known-bias self-check.** Anchoring: every claim was re-derived before reading the Architect's
verdict, and two Architect-supplied numbers were found stale (vector d present-set 4→5). Authority:
no PASS was inherited from the deliverable; the harness re-tests sources.

---

*Produced by AEGIS QA Engineer (Panel 4) for `Q-PORT-MATRIX-PREFLIGHT`. Status `REVIEW` only.
No commit. `LIVE_FLASH_CLAIMED=false`.*
