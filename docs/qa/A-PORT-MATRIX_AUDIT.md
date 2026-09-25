# A-PORT-MATRIX — Independent Audit (GuardTalkOS Gen 8/9/10 Port Program)

> **Card:** `A-PORT-MATRIX` (`audit_scope: full`, P0) · **Panel:** AEGIS Auditor (Panel 5)
> **Charter:** `DEC-PORT-GEN8910-001` · **Operator directive:** `DEC-PORT-GEN8910-002`
> **Owner root / authoritative path:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md`
> **Repository id:** `grapheneos-worktree` · **Date:** 2026-09-21 (UTC)
> **Status:** `REVIEW` only — never `APPROVED` by this panel. **Read-only** audit.
> **`LIVE_FLASH_CLAIMED=false`.** No commit. No boot / on-device / flash claim.

---

## 0. Non-claims (explicit)

- This audit ran **read-only**. No product code, test, config, `releases/desktop-flash/*`,
  `vendor/guardtalk/device/*`, `vendor/guardtalk/feature-excised/*`,
  `vendor/guardtalk/radio-excised/*`, `doctrine/`, `governance/{laws,gates}/`, or secret was
  modified. Only the three target paths in §11 were written.
- **No device was attached to this host.** No boot, fastboot, on-device, or flash result is
  claimed. I did not run a build or `adevtool download`/`generate-all`.
- I did **not** invent any URL, blob, or PASS. Every value below is accompanied by the exact
  command and its observed output.
- Worktree provenance: the **root has no `.git`** (so no `git status`/`git diff` at root), but
  the tree is `repo`-managed — `.repo/` exists and `vendor/guardtalk/.git` is a symlink to
  `../../.repo/projects/vendor/guardtalk.git`. Correctness below is established by **content
  rematch**, not git.

## 1. Gate −1 record (in-process, mandatory STEP 0)

| Check | Result |
|-------|--------|
| `governance_loaded` | **true** — `.aegis/governance/laws/` = **24** YAML (`law_00_human_authority` … `law_23_observability`); `.aegis/governance/gates/` = **11** YAML (`gate_neg1_guardian_first` … `gate_09_rollback`). `.aegis` → `../aegis-global` (relative symlink). |
| `scope_confirmed` | **true** — `audit_scope: full` (8 items §2); target paths limited to this report + `TASK_QUEUE.md` card status + `.agent-comm/inbox/TO_ARCHITECT.md` + `.agent-comm/history/`; forbidden paths confirmed. |
| `authority_context_resolved` | **true** — owner root `TASK_QUEUE.md`; `repository_id=grapheneos-worktree`; `.aegis-config.json` `gate_minus1.mode: in_process`, `discover_remote_tools=false`, `call_verifier=false`, `call_guardian=false`. |
| Remote governance calls | **NONE.** `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP were **not** called or discovered. No deadlock possible. |

Laws applied in-process: 0, 2, 4, 6, 7, 9, 10, 11, 12, 16, 19, 20.

## 2. Scope items, verdicts, and raw evidence

Summary: **8/8 items audited.** 6 PASS, 2 PASS-with-finding. See §3 for findings.

| # | Scope item | Verdict |
|---|-----------|:-------:|
| 1 | Matrix correctness & wave ordering | **PASS-with-finding** (matrix exactly correct; wave ordering SoC-cohort-based, not strictly risk-ordered) |
| 2 | Deliberate Gen 6/7 exclusion | **PASS** — no leak into any wave/card/verdict/advertise surface |
| 3 | DEC-012 pairing integrity | **PASS-with-finding** — 2 feature cards unpaired; all `Q-*` correctly blocked |
| 4 | No secret/key leakage into program files | **PASS** |
| 5 | No invented PASS | **PASS** — none found |
| 6 | Registry honesty | **PASS-with-finding** (one absolute phrase is literally false) |
| 7 | Operator directive conformance (§9) | **PASS-with-finding** (honest; stale header line) |
| 8 | Cross-check `adevtool show-status` ground truth | **PASS** — exact match |

---

### Item 1 — Matrix correctness & wave ordering

**Evidence — 13 device configs (command + observed output):**

```
$ for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    test -f vendor/adevtool/config/device/$d.yml && echo "cfg OK $d"; done
cfg OK shiba … cfg OK rango      # 13/13 OK
```

**Evidence — `PRODUCT_MODEL` re-read from the vendor-skel (13/13):**

```
$ for d in <13>; do grep -m1 'PRODUCT_MODEL' vendor/adevtool/vendor-skels/google_devices/$d/$d.mk; done
shiba    PRODUCT_MODEL := Pixel 8
husky    PRODUCT_MODEL := Pixel 8 Pro
akita    PRODUCT_MODEL := Pixel 8a
tokay    PRODUCT_MODEL := Pixel 9
caiman   PRODUCT_MODEL := Pixel 9 Pro
komodo   PRODUCT_MODEL := Pixel 9 Pro XL
comet    PRODUCT_MODEL := Pixel 9 Pro Fold
tegu     PRODUCT_MODEL := Pixel 9a
stallion PRODUCT_MODEL := Pixel 10a      <-- trap confirmed (Pixel 10a, Gen-9 silicon)
frankel  PRODUCT_MODEL := Pixel 10
blazer   PRODUCT_MODEL := Pixel 10 Pro
mustang  PRODUCT_MODEL := Pixel 10 Pro XL
rango    PRODUCT_MODEL := Pixel 10 Pro Fold
```

**Evidence — SoC platform derived from `config/mk/google_devices/device/<dev>/` (13/13):**

```
shiba zuma | husky zuma | akita zuma | tokay zumapro | caiman zumapro | komodo zumapro |
comet zumapro | tegu zumapro | stallion zumapro | frankel laguna | blazer laguna |
mustang laguna | rango laguna
```

`tegu` **and** `stallion` = `zumapro` — both traps confirmed (matches deliverable §2.1).

**Evidence — kernel dirs present (7 dirs):**

```
$ ls -d device/google/{shusky,akita,caimito,comet,tegu,stallion,laguna}-kernels
device/google/shusky-kernels  akita-kernels  caimito-kernels  comet-kernels
tegu-kernels  stallion-kernels  laguna-kernels      # all 7 exist
```

**Evidence — build-index `main` counts (exact match to §5):**

```
shiba 58 | husky 58 | akita 46 | tokay 47 | caiman 46 | komodo 46 | comet 45 |
tegu 29 | stallion 5 | frankel 29 | blazer 29 | mustang 29 | rango 24
```

`stallion` = **5** (thinnest) confirmed. **No disagreement** with the deliverable's §2 table.

**Wave ordering.** The ratified order is `Gate → A zumapro → B zuma → C laguna`. The
justification (lowest-divergence first: `zumapro` matches the `tokay` reference and `caiman`
shares `caimito-kernels`; `zuma` has the `akita` precedent; `laguna` is a new SoC on a 6.6
kernel with literal kernel paths and two foldables) is **evidence-borne, not arbitrary**.
It is however a **SoC-cohort** order, not a strictly risk-ordered one: `stallion` (highest
risk — 5-entry index, oldest pin, 16-QPR1 platform lag) sits inside Wave A, the
"lowest-divergence" wave, alongside `caiman` (lowest risk). → **Finding M-2.**

### Item 2 — Deliberate Gen 6/7 exclusion (leak check)

**Exact greps and results:**

```
# Program's own strict guard on the deliverable — expected empty:
$ grep -nE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro' \
    vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md | grep -v 'out of scope'
(no output)                                   # guard_rc=1  -> EMPTY  => NO LEAK

# All matches in the deliverable (3, all exclusion/guard text):
375:- Gen 6 codename-references `oriole`, `raven`, `bluejay` — **out of scope**.
376:- Gen 7 codename-references `panther`, `cheetah`, `lynx`, `felix`, `tangorpro` — **out of scope**.
410:grep -nE '…' … | grep -v 'out of scope'   # the guard command text itself
```

```
# TASK_QUEUE.md program section (§6259-END) — all matches are exclusions:
6479: "any Gen 6/7 codename (`oriole`…)"                 -> forbidden-path list
6497: "! grep -nE '…' … | grep -v 'out of scope'"       -> guard command text
6576-6577: QA attack-set "(6) any Gen 6/7 codename …"    -> falsification instruction
6639-6640: Gen 6 … | N/A | Out of program scope.          -> explicit exclusion
6640-6641: Gen 7 … | N/A | Out of program scope.          -> explicit exclusion
6745:      Gen 6/7 (…) | Out of program scope | N/A      -> explicit exclusion
```

**Conclusion:** the 8 codenames appear in the program **only** inside explicit out-of-scope /
forbidden / falsification-guard statements. **No wave, no card, no GO/NO-GO verdict, no
advertise surface** contains them. Advertise surfaces verified clean:
`ALLOWED_PRODUCTS = ["tokay","akita","komodo","rango"]` (`web-installer/src/types.ts:3`);
`ADVERTISED_DEVICES=(tokay akita komodo rango)` (`scripts/pack-webinstall-channel.sh:27`).

**Non-program occurrences (NOT leaks, disclosed/upstream/pre-existing):**
- `vendor/adevtool` tooling data: `vendor/state/<gen6/7>.json` fixtures and the adevtool
  device lists — the deliverable §13 explicitly discloses these as upstream tooling data.
- `vendor/guardtalk/docs/WEB_INSTALLER.md:114` — a pre-existing 21-name
  `supportedDevices` list (used by the preflight as *source*, not as an advertise surface).
- `vendor/guardtalk/scripts/sign-build.sh:198` — a pre-existing device **allowlist** that
  includes Gen 6/7 codenames (→ **Finding L-6**).
- `web-installer/test/*.test.ts` — `panther` used as a **negative** fixture (rejection test).
- `.agent-comm/` history/inbox from prior sprints (not the port program).

→ **No CRITICAL leak. Item 2 = PASS.**

### Item 3 — DEC-012 pairing integrity

**Inventory reconciled:** §4a **13** rows + §4b **9 devices × 7 = 63** rows = **76 cards**
(confirms the "76-card inventory").

**Feature cards audited: 52.** (§4a T-/F- features = 7; §4b features = 9 × 5 types
`PREFLIGHT`/`LAYER`/`FLASH`/`WEBINSTALL`/`KEYS` = 45.)

**Pairs found: 37 compliant + 1 family-placeholder** (see below).
**Violations: 11 feature cards with no paired `Q-*`** — 2 substantive + 9 keys-by-design.

| Feature card | Pair in §4a/§4b | Status |
|---|---|---|
| `T-PORT-MATRIX-PREFLIGHT` | `Q-PORT-MATRIX-PREFLIGHT` | ✅ (Q `READY` because pair `APPROVED` — correct) |
| `T-PORT-EXCISION-MATRIX` | `Q-PORT-MATRIX-NONREGRESSION` | ✅ (Q `BLOCKED`) |
| `T-PORT-KERNEL-MATRIX` | `Q-PORT-MATRIX-NONREGRESSION` | ✅ (Q `BLOCKED`) |
| `T-PORT-RANGO-PROMOTE` | `Q-PORT-RANGO-PROMOTE` | ✅ (both `HOLD`) |
| `F-PORT-MATRIX-WEBINSTALL` | `Q-PORT-<DEV>-WEBINSTALL` | ⚠ **family placeholder**, not one card → **L-2** |
| `F-PORT-FOLD-OVERLAYS` | — | ✗ **UNPAIRED** → **M-1** |
| `T-PORT-MATRIX-DOCS` | — | ✗ **UNPAIRED** → **M-1** |
| `T-PORT-<DEV>-PREFLIGHT/-LAYER/-FLASH` (9 each) | `Q-PORT-<DEV>` | ✅ (Q `BLOCKED`, DEC-012) |
| `F-PORT-<DEV>-WEBINSTALL` (9) | `Q-PORT-<DEV>-WEBINSTALL` | ✅ (Q `BLOCKED`) |
| `T-PORT-<DEV>-KEYS` (9) | — | ⚠ no pair (deliberate `HOLD`) → **L-1** |

**`Q-*` blocked on their pair — none found violated.** Every `Q-*` in §4b is `BLOCKED`
(DEC-012); `Q-PORT-MATRIX-NONREGRESSION` is `BLOCKED`; `Q-PORT-MATRIX-PREFLIGHT` is `READY`
because its paired `T-PORT-MATRIX-PREFLIGHT` is `APPROVED` (correct unblock, not a violation).
**No `Q-*` was found that is NOT blocked on its pair.**

**Concrete count: 52 features audited / 37 pairs found (+1 family placeholder) / 11 unpaired
(2 substantive, 9 keys-by-design).**

### Item 4 — No secret / key / credential leakage into program files

```
$ for pat in 'BEGIN .*PRIVATE KEY' '\.pk8' '\.pem' 'password' 'secret' 'api[_-]key' 'token' 'credential'; do
    grep -rIlE "$pat" vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md \
      .agent-comm/inbox/TO_ARCHITECT.md .agent-comm/inbox/TO_BACKEND_T-PORT-MATRIX-PREFLIGHT.md; done
BEGIN .*PRIVATE KEY -> 0 files
\.pk8 -> 0    \.pem -> 0    password -> 0    secret -> 0
api[_-]key -> 0    token -> 0
credential -> 1 file   # sole hit = a *prohibition* line: "`keys/`, any private key material,
                       #  `.env`, credentials"  (TO_BACKEND_T-PORT-MATRIX-PREFLIGHT.md:94)
```

`find vendor/guardtalk -name '*.pem' -o -name '*.pk8' -o -name '.env' -o -name '*.key'` →
**none**. No `.env` at repo root. **All 9 `T-PORT-<DEV>-KEYS` are `HOLD`** (program §7 and the
§4b default statuses) — verified. → **PASS.**

> Caveat (not a program leak): private key material **does** exist pre-existing at
> `keys/tokay/` (`avb.pem` is an OpenSSH *private* key; 9 × `*.pk8`). It predates the program
> (Jun 19) and is outside program scope (the program *forbids* touching `keys/`). But it makes
> the program's absolute phrase "`.pem`/`pk8` never in tree" literally false → **L-3**.

### Item 5 — No invented PASS

```
$ sed -n '6259,$p' TASK_QUEUE.md | grep -niE '\bPASS\b|booted|flash ready|verified on device'
15:  No on-device smoke is `PASS` without operator-supplied hardware + explicit authorisation.
20:  Never invent a URL, blob, kernel prebuilt, or PASS.
317,320: (preflight-PASS wording) — QA attack-set definitions, not claims.
337:  a synthetic device … must **fail**, not pass silently.
386:  | `DEBUG_FLASH_READY` / `FLASH_READY` | **false** | …
498:  Never invent a URL, blob, or PASS.
$ grep -niE 'LIVE_FLASH_CLAIMED' (program section)
14: LIVE_FLASH_CLAIMED=false; DEC-009 (live execute / lock HOLD) remains in force.
163: every `T-*-FLASH` inherits LIVE_FLASH_CLAIMED=false.  385: | LIVE_FLASH_CLAIMED | false |
```

**No invented PASS found.** Every PASS-adjacent string is a negation, a prohibition, or an
attack-set definition. `LIVE_FLASH_CLAIMED=false` holds throughout. `FLASH_READY` /
`DEBUG_FLASH_READY` = **false**. **DEC-009 (live execute/lock HOLD) is unwaived** (durable bind
`.agent-comm/inbox/TO_ARCHITECT_DEC-REMEDIATE-009.md`: `FLASH_READY false`, `adb devices -l`
empty). → **PASS.**

### Item 6 — Registry honesty

Direct inspection (command + output):

```
$ for d in tokay akita komodo rango; do printf "%s module=%s latest=%s\n" "$d" \
    "$(test -d vendor/google_devices/$d && echo yes || echo no)" \
    "$(test -L releases/desktop-flash/… -latest && echo yes || echo no)"; done
tokay  module=yes latest=yes | akita module=yes latest=yes
komodo module=yes latest=yes | rango module=yes latest=yes
```

The **9 unported** devices have **neither** a live `vendor/google_devices/` module **nor** a
`*-latest` stamp. `vendor/guardtalk/device/` = `akita, emu64a, komodo, rango, tokay` (caiman +
the other 8 **ABSENT**). All **5** `*-latest` symlinks are unchanged and match the deliverable:

```
latest -> tokay-20260725-102506        akita-latest  -> akita-20260725-101434
komodo-latest -> komodo-20260915-063833 komodo-debug-latest -> komodo-debug-20260921-041838
rango-latest -> rango-20260802-130756
```

The 4 devices labelled **SUPPORTED** are exactly the 4 with observable module + stamp;
`rango` is correctly labelled **experimental / boot HOLD**; the 9 are **not ported**. This is
honest and consistent with observable evidence. **The only blemish is the literal-false
absolute** "`.pem`/`pk8` never in tree" (§9.5) → **L-3**. → **PASS-with-finding.**

### Item 7 — Operator directive conformance (`TASK_QUEUE.md` §9, `DEC-PORT-GEN8910-002`)

- **What can/cannot be delivered** (§9.5): signed-**user** production builds (`HOLD`), on-device
  boot (`HOLD`), `rango` boot-green (`HOLD`), advertise beyond stamped devices (`fail-closed`),
  Gen 6/7 (`N/A`) — all correctly **not** promised.
- **"Builds are deliverable but boot-green is not"** — this claim is **honest**: §9.5 explicitly
  states "Build completion is **not** boot-green and **is not** a flash-readiness claim.
  `LIVE_FLASH_CLAIMED=false` remains true." Consistent with items 5/6.
- **No HOLD improperly waived:** §9 opening states "All real safety holds (§7) remain in force
  and are **not** waived." Verified: `T-PORT-<DEV>-KEYS` ×9 `HOLD`; on-device smoke `HOLD`;
  `T-PORT-RANGO-PROMOTE` `HOLD`; advertise `fail-closed`; `rango-latest` pinned. The directive
  supersedes **only** the "one wave at a time" *serialization*, not any safety hold.
- **Finding:** the program **header** (line 6264-6265) still says "Dispatch proceeds **one wave
  at a time** with a stop between waves," which §9 explicitly supersedes (and §9.4 dispatches
  Backend/QA/Frontend/Auditor concurrently). → **L-4** (stale header; documentation-only).

→ **PASS-with-finding.**

### Item 8 — Cross-check `adevtool show-status` ground truth

```
$ export PATH="$HOME/.local/toolchain/node/bin:$PATH"; node --version
v24.21.0
$ vendor/adevtool/bin/run show-status
Stock image:
  factory:
    present: rango komodo tokay akita           <-- EXACTLY the 4 supported
    known:   mustang blazer frankel stallion tegu comet caiman husky shiba
             felix tangorpro lynx cheetah panther bluejay raven oriole
Pinned build IDs: rango CP1A.260505.005 | mustang blazer frankel tegu akita husky shiba
  BP4A.260205.001 | stallion BD6A.251031.001.A4 | comet komodo caiman tokay BP4A.260205.002
Backports (Gen 8/9/10): CP1A.260505.005
```

**Match.** `present` = `rango komodo tokay akita` **exactly** the 4 supported devices; the
pinned build IDs match program §9.2 (`BP4A.260205.002` for `comet komodo caiman tokay`;
`BP4A.260205.001` for `mustang blazer frankel tegu akita husky shiba`; `CP1A.260505.005` for
`rango`; `BD6A.251031.001.A4` for `stallion` = oldest pin, confirming the 16-QPR1 lag); the
Gen 8/9/10 backport id is `CP1A.260505.005`. Gen 6/7 codenames appear in the **tool's** output
as upstream data — consistent with the program's disclosure. → **PASS.**

**Independent upstream spot-checks (network available):**

```
$ for d in <13>; do curl -s ".../releases.grapheneos.org/$d-stable"; done
13/13 -> HTTP 200, "2026091900 1789794102 <dev> stable"

$ curl -sI -o /dev/null -w '%{http_code}' <factory zip>
stallion-bd6a.251031.001.a4-factory-7420a527.zip  -> 200   (thin-margin pin is fetchable)
tokay-bp4a.260205.002-factory-45177450.zip         -> 200
shiba-bp4a.260205.001-factory-35b8480d.zip         -> 200
rango-cp1a.260505.005-factory-18bf79d9.zip         -> 200

$ curl -s https://grapheneos.org/faq | grep -oiE 'Pixel (10a|10 Pro Fold|9a|8a|8 Pro)[^<]{0,20}'
Pixel 10a (stallion) / Pixel 10 Pro Fold (rango) / Pixel 9a (tegu) / Pixel 8a (akita) / …
```

All independently reproduce the deliverable's upstream claims (§6/§7).

---

## 3. Findings by severity

**Count: CRITICAL 0 · HIGH 1 · MEDIUM 2 · LOW 6 (total 10).**

### HIGH

**H-1 — `A-PORT-MATRIX` was dispatched out of its declared dependency order.**
- **Evidence:** §4a row (line 6395): `A-PORT-MATRIX | Auditor | Gate | P0 | depends_on
  Q-PORT-MATRIX-PREFLIGHT | status BLOCKED`; §6 graph (line 6604): "`Q-PORT-MATRIX-PREFLIGHT`
  ─► `A-PORT-MATRIX` (P0, `audit_scope: full`, **goes last**)". Yet
  `.agent-comm/signals/dispatch-A-PORT-MATRIX.json` exists (`DISPATCHED`, 2026-09-21T18:55+04:00)
  while `vendor/guardtalk/docs/qa/Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md` is **ABSENT** and no
  `Q-PORT-MATRIX-PREFLIGHT` history entry exists.
- **Impact:** the audit's declared precondition (QA's adversarial matrix falsification) is
  unmet; the P0 foundation cards (`T-PORT-EXCISION-MATRIX`, `T-PORT-KERNEL-MATRIX`) have not
  produced outputs either. Coverage gap, recorded in §4.
- **Recommendation (Architect):** treat this audit as a **pre-gate** review; re-run `A-PORT-MATRIX`
  (or a scoped delta audit) after `Q-PORT-MATRIX-PREFLIGHT` returns.

### MEDIUM

**M-1 — DEC-012: two feature cards have no paired `Q-*`.**
`F-PORT-FOLD-OVERLAYS` (P1, `READY (held)`) and `T-PORT-MATRIX-DOCS` (P2, `BLOCKED`) carry
pair `—` in §4a (lines 6392, 6394). Operator directive §9.6.3 re-affirms "every feature card
keeps a `BLOCKED` `Q-*` pair." They are currently HOLD/BLOCKED so unexploitable **today**,
but a bare dispatch of either would leave the DEC-012 contract unmet.
**Recommendation:** add `Q-PORT-FOLD-OVERLAYS` (or pair to `Q-PORT-MATRIX-NONREGRESSION`) and
`Q-PORT-MATRIX-DOCS` (pair to a docs-verification `Q-*`), or record an explicit DEC-012 exemption.

**M-2 — Wave A is not risk-ordered; the highest-risk device is in the first wave.**
Wave A (`zumapro`: `caiman, comet, tegu, stallion`) is described as "**lowest divergence** from
`tokay`," yet contains `stallion` — only 5 build-index entries, the **oldest** pinned factory
(`BD6A.251031.001.A4`), a 16-QPR1 platform lag, and self-declared "thin-margin case." The order
is a legitimate **SoC-cohort** order, but it does not place the riskiest device last.
**Recommendation:** sequence `stallion` **last within Wave A** (after `caiman`/`comet`/`tegu`),
or defer it to a later wave; the deliverable's own reasoning supports this.

### LOW

- **L-1 — `T-PORT-<DEV>-KEYS` ×9 unpaired.** No `Q-*` pair. Mitigated by design (`HOLD`,
  never dispatched; consistent with the prior `T-PORT-AKITA-KEYS` precedent), but the DEC-012
  exemption is not stated in DEC-012 terms.
- **L-2 — `F-PORT-MATRIX-WEBINSTALL` pair is a family placeholder** (`Q-PORT-<DEV>-WEBINSTALL`),
  not a single `Q-*`; acceptable as an umbrella only if documented as such.
- **L-3 — Literal-false absolute claim.** §9.5 (line 6746): "No production signing keys;
  `.pem`/`pk8` never in tree." Production GuardTalk signing keys are indeed absent (DEC-009
  rematch: `vendor/guardtalk/branding/signing-keys/avb.pem` ABSENT), but `.pem`/`.pk8`
  **do** exist in the tree at `keys/tokay/`. Not program-introduced. **Recommend rewording to
  "no production signing keys; no key material added by this program."**
- **L-4 — Stale program header.** Line 6264-6265 "one wave at a time with a stop between waves"
  contradicts §9 (which supersedes that serialization). Documentation-only.
- **L-5 — `repo`-managed tree, not "no git".** `.repo/` exists and `vendor/guardtalk/.git` →
  `.repo/projects/vendor/guardtalk.git`. Root has no `.git`, so "no `git status` at root" is
  true, but sub-project provenance may be recoverable. The report correctly discloses content
  rematch; the blanket "not a git repo" phrasing is imprecise.
- **L-6 — Pre-existing `sign-build.sh` allowlist includes Gen 6/7 codenames**
  (`vendor/guardtalk/scripts/sign-build.sh:198`, also `:454` `tangorpro`). **Not a program
  surface** and not modified by the program, but the script *will accept* a Gen 6/7 device name
  if invoked directly. **Recommend** the Architect decide whether this is a latent scope hole.

## 4. What I could NOT verify (explicit gaps)

- **QA's adversarial falsification of the matrix** — `Q-PORT-MATRIX-PREFLIGHT_EVIDENCE.md` does
  **not exist** at audit time. I could not confirm that the 4 `trunk_staging` kernel-directory
  absences were independently challenged (the deliverable §16 itself calls that classification
  "arguable"). This is the single largest coverage gap.
- **Foundation deliverables** — `EXCISION_MATRIX.md` / `KERNEL_MATRIX.md` (and the
  `feature-excised/` / `radio-excised/` parameterization) were **not present**; I audited the
  program as chartered, not those outputs. (No Backend/QA in-flight artifacts were observed
  during my run — only `PORT_MATRIX_GEN8910_PREFLIGHT.md` was recently written under
  `vendor/guardtalk/`.)
- **No build / no `generate-all`** — I did not compile any device nor run `adevtool
  generate-all` (forbidden during the operator's Phase 0 download; also out of scope). So
  "builds are deliverable" is **not** independently proven here; I verified only the *static*
  prerequisites (config, model, SoC, kernel-tree presence, index coverage) plus live upstream
  URLs.
- **No hardware** — no boot / flash / on-device result can be (or is) claimed. `rango`
  boot-green remains unproven by design.
- **`keys/tokay/` key material** — I confirmed presence and `file(1)` type only; I did not
  attempt to validate, decrypt, or characterize the keys (read-only, and touching them is
  forbidden).
- **Operator Phase 0 download** — in-flight at audit time
  (`.agent-comm/evidence/operator-phase0-logs/download-20260921T145534Z.log`); I did not treat
  its partial state as evidence, to avoid a race.

## 5. Re-runnable check harness (copy-paste)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export PATH="$HOME/.local/toolchain/node/bin:$PATH"   # node only, for show-status

# --- Item 8: tool ground truth ---
vendor/adevtool/bin/run show-status | sed -n '/^Stock image:/,/^$/p'

# --- Item 1: matrix ---
for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
  test -f vendor/adevtool/config/device/$d.yml || echo "MISSING cfg $d"
  printf "%-9s %s\n" "$d" "$(grep -m1 'PRODUCT_MODEL' vendor/adevtool/vendor-skels/google_devices/$d/$d.mk)"
  printf "%-9s soc=%s idx=%s\n" "$d" \
    "$(grep -rhoE 'platform/(zuma|zumapro|laguna)' vendor/adevtool/config/mk/google_devices/device/$d/ | sort -u | tr '\n' ',')" \
    "$(grep -cE "^$d " vendor/adevtool/config/build-index/build-index-main.yml)"
done
ls -d device/google/{shusky,akita,caimito,comet,tegu,stallion,laguna}-kernels

# --- Item 2: Gen 6/7 leak guard (must be EMPTY) ---
grep -nE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro' \
  vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md | grep -v 'out of scope'
sed -n '6259,$p' TASK_QUEUE.md | grep -nE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro' \
  | grep -vE 'out of scope|Out of program scope|N/A|forbidden|attack|codename'

# --- Item 3: DEC-012 pairing (inventory + unpaired features) ---
sed -n '6380,6420p' TASK_QUEUE.md | grep -E '^\| `[TF]-PORT'          # feature rows + pair column

# --- Item 4/5: secrets & invented PASS ---
find vendor/guardtalk -name '*.pem' -o -name '*.pk8' -o -name '.env' -o -name '*.key'
sed -n '6259,$p' TASK_QUEUE.md | grep -niE 'LIVE_FLASH_CLAIMED|FLASH_READY|\bPASS\b' 

# --- Item 6: advertise surface ---
sed -n '1,5p' vendor/guardtalk/web-installer/src/types.ts        # ALLOWED_PRODUCTS
grep -n 'ADVERTISED_DEVICES' vendor/guardtalk/scripts/pack-webinstall-channel.sh
find releases/desktop-flash -maxdepth 1 -type l -printf '%f -> %l\n' | sort
```

## 6. Gate 5 — Ultimate Critique self-score

**Self-score: 82 / 100** (threshold 70; `HUMAN SKIP` not invoked).

| Dimension | Score | Note |
|---|:--:|---|
| Independent derivation (not copied) | 20/20 | Matrix, SoC, model, index, URLs all re-derived; `show-status` match. |
| Evidence discipline (Law 7) | 17/20 | Command+output for every claim; one gap — no build/`generate-all` run (declared). |
| Gen 6/7 exclusion verification | 15/15 | Strict guard empty; every non-program hit classified. |
| DEC-012 / directive conformance | 15/20 | Concrete counts; the "unpaired" call rests on the program's own DEC-012 wording, which could be read as not covering docs/keys cards. |
| Honesty of gaps | 10/10 | §4 enumerates what could not be verified. |
| Severity calibration | 5/15 | Wave-order (M-2) and sequencing (H-1) are judgment calls; reasonable reviewers could rank them lower/higher. |

**Known bias self-check.** Anchoring: I re-ran each command rather than trusting the
deliverable's tables. Confirmation: I deliberately spot-checked the **load-bearing** thin-margin
case (`stallion` pin, `stallion` upstream) with an independent `curl` rather than accepting the
program's URLs. Over-caution: I did **not** run `generate-all`/a build, so I explicitly do not
claim the port builds.

## 7. Recommendation

**Proceed — with two conditions.** The matrix is **correct**, waves are **evidence-justified**,
Gen 6/7 is **cleanly excluded**, no secrets or invented PASS exist, and the operator directive
is **honest**. But the program should (1) **close the DEC-012 pairing gaps** (M-1) and re-sequence
`stallion` **last within Wave A** (M-2), and (2) **re-audit after `Q-PORT-MATRIX-PREFLIGHT`
lands**, since this audit ran before its declared dependency (H-1). No CRITICAL blocker.

## 8. Artifacts written (this card)

- `vendor/guardtalk/docs/qa/A-PORT-MATRIX_AUDIT.md` — **NEW** (this report).
- `TASK_QUEUE.md` — `A-PORT-MATRIX` status only (`BLOCKED` → **`REVIEW`**).
- `.agent-comm/inbox/TO_ARCHITECT.md` — **REPLACED** with the audit report to the Architect.
- `.agent-comm/history/` — displaced message archived (md5 match
  `549389ef07c64c3fad5011f42bc5ebb8`) + lifecycle events (append-only).

No product code, test, config, `releases/desktop-flash/*`, `vendor/guardtalk/device/*`,
`vendor/guardtalk/feature-excised/*`, `vendor/guardtalk/radio-excised/*`, `doctrine/`,
`governance/{laws,gates}/`, secret, or audited file was modified. **No commit.**

---

*Produced by AEGIS Auditor (Panel 5) for `A-PORT-MATRIX`. Status `REVIEW` only —
`APPROVED` is the Architect's verdict. `LIVE_FLASH_CLAIMED=false`. No boot/flash claim.*
