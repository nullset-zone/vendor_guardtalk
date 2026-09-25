# A-EXCISE-13DEV-NONREGRESSION — Independent Deep-Tech Audit (Panel 5)

| Field | Value |
|---|---|
| task_id | `A-EXCISE-13DEV-NONREGRESSION` |
| role | Auditor (Panel 5) — READ-ONLY |
| audit_scope | `code-review` |
| owner_root | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| program | `EXTREME AUDIT — AIRGAP CLAIM (Gen 8/9/10, 13 devices)` — `DEC-EXCISE-AIRGAP-001` |
| status | **REVIEW** (never `APPROVED`; auditor does not change task status) |
| Gate -1 | `in_process` — `governance_loaded=true` (24 laws, 11 gates under `.aegis/governance/`); no `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP call |
| Gate 5 | **HUMAN SKIP** (no score invented) |
| `LIVE_FLASH_CLAIMED` | `false` |
| `FLASH_READY` | `false` |
| Device / `adb` / `fastboot` results | **none claimed** (forbidden) |
| Timestamp | 2026-09-24T16:30:00+04:00 |

---

## 1. Verdict

> ## ✅ **RESOLVER HOLDS**

Tested against the `T-PORT-SHARED-CORE-FIX` silent-no-op failure mode and against
cross-device mis-excision, **the shared excision resolver and its parameterization hold**:

- **13/13** devices resolve to the **expected** variant (8 variants, kernel-family keyed) — proven
  by `make` resolution **and** the per-device built `vendor_dlkm` blocklist.
- **No device silently no-ops** on any normal path: no-identity, unregistered-device, unknown-SoC,
  ambiguous-SoC, unknown-explicit-variant, missing-blocklist-file and blocklist-path/token drift
  **all abort with `$(error)`** (each driven, `exit 2`; falsification log §5).
- **No device picks another device's blocklist** on the real path: the 8 built
  `modules.blocklist` token-groups are distinct and correct (`shiba`/`husky` = `shusky`
  `bcmdhd4398`; `akita` = `bcmdhd4383`; `komodo` is token-identical to the `zumapro_caimito`
  canonical; `frankel`/`blazer`/`mustang` = `laguna_muzel`; `rango` = `laguna_rango`).
- The incumbent `*-latest` targets are unchanged (`rango-latest` still points at
  `rango-20260802-130756`; see §6).
- All 13 generated trees still carry both hooks (product `guardtalk-radio-excised.mk` include and
  the `BoardConfig-excised-late.mk` late include) — no `adevtool` regeneration reverted them.

**Two Low-severity silent paths were reproduced** and **do not** change the verdict because both
are unreachable in a single-product build (see §4). Neither regresses an in-force device.

### Severity counts

| Severity | Count | IDs |
|---|---|---|
| Critical | **0** | — |
| High | **0** | — |
| Medium | **0** | — |
| Low | **7** | F-001 … F-007 |
| Info / disagreement | **2** | F-008, F-009 |

---

## 2. What was audited (lane scope)

1. `vendor/guardtalk/feature-excised/excision-variants.mk` (data registry) and
   `excision-variant-select.mk` (resolver) — read in full.
2. `vendor/guardtalk/docs/EXCISION_MATRIX.md` (8 variants, kernel-family keyed).
3. Per-device variant + blocklist resolution for all 13 program devices, from **built artifacts**.
4. Resolver attacks (unknown codename, ambiguous SoC, inherited pin, default fallthrough, second
   include naming a different registered device, explicit wrong-family override).
5. `adevtool` regen hook survival (`BoardConfig-excised-late.mk`, the product include, the
   `guardtalk-radio-excised.mk` include) and the `REGEN_HOOKS.md` coverage gap.
6. Incumbent `*-latest` symlink targets and inodes.

**Method / evidence discipline:** BUILT artifacts preferred over makefiles. No product/test/filter/
flash/packer/doctrine/queue-authoritative file was edited; all experiments ran from `/tmp/gt-audit/`.
`make` harnesses ran in-repo (the resolver does a relative `include`), writing only to `/tmp`.
Author-side suites were re-run but not trusted (§7); `verify-on-device.sh` was **not** run (needs
`adb`, forbidden).

---

## 3. Per-device resolved-variant proof (13 rows)

`RESOLVED` = `make -s` with `GT_EXCISION_DEVICE`/`GUARDTALK_DEVICE=<dev>` against the real resolver
(evidence: `per_device_resolution.txt`). `BUILT` = `out/target/product/<dev>/vendor_dlkm/lib/modules/modules.blocklist`,
the file the build actually ships (evidence: `built_blocklists.txt`). `SRC` = the registry-selected
canonical blocklist.

| # | Device | Expected variant | Resolver → variant (SoC / FP) | Resolver → blocklist (SRC) | BUILT blocklist sha256 (16) | Token group | BUILT post-resolver? | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | `shiba` | `zuma_shusky` | `zuma_shusky` (zuma / goodix) | `…/variants/zuma_shusky/vendor_dlkm.modules.blocklist` | `6907852cb6ffe131` | `4a094be11007b18d` | ✅ 2026-09-22 17:01 | **HOLDS** |
| 2 | `husky` | `zuma_shusky` | `zuma_shusky` (zuma / goodix) | `…/variants/zuma_shusky/vendor_dlkm.modules.blocklist` | `6907852cb6ffe131` | `4a094be11007b18d` | ✅ 2026-09-22 17:42 | **HOLDS** |
| 3 | `akita` | `zuma_akita` | `zuma_akita` (zuma / goodix) | `…/device/akita/vendor_dlkm.modules.blocklist` | `e21a2ee127fd2d11` | `54996074f061981e` | ⚠ 2026-07-24 (pre-resolver) | HOLDS (make+content) |
| 4 | `tokay` | `zumapro_caimito` | `zumapro_caimito` (zumapro / qfp) | `…/feature-excised/vendor_dlkm.modules.blocklist` | `80a90c1c606eb6e7` | `4b404489a8e5c17d` | ⚠ 2026-07-23 (pre-resolver) | HOLDS (make+content) |
| 5 | `caiman` | `zumapro_caimito` | `zumapro_caimito` (zumapro / qfp) | `…/feature-excised/vendor_dlkm.modules.blocklist` | `80a90c1c606eb6e7` | `4b404489a8e5c17d` | ✅ 2026-09-22 08:48 | **HOLDS** |
| 6 | `komodo` | `zumapro_caimito` | `zumapro_caimito` (zumapro / qfp) | `…/device/komodo/vendor_dlkm.modules.blocklist` (pin) | `c2fad0658e9f6acc` | `4b404489a8e5c17d` | ⚠ 2026-09-15 (pre-resolver) | HOLDS (pin ≡ canonical) |
| 7 | `comet` | `zumapro_comet` | `zumapro_comet` (zumapro / goodix) | `…/variants/zumapro_comet/vendor_dlkm.modules.blocklist` | `eb4e16c0874fcdf5` | `4952c0760a647148` | ✅ 2026-09-22 15:52 | **HOLDS** |
| 8 | `tegu` | `zumapro_tegu` | `zumapro_tegu` (zumapro / goodix) | `…/variants/zumapro_tegu/vendor_dlkm.modules.blocklist` | `e9270c6d7902254e` | `944dbdadc0a8e768` | ✅ 2026-09-22 16:38 | **HOLDS** |
| 9 | `stallion` | `zumapro_stallion` | `zumapro_stallion` (zumapro / goodix) | `…/variants/zumapro_stallion/vendor_dlkm.modules.blocklist` | `7bae22bd1bc848bd` | `9d4d1b302b61bd63` | ✅ 2026-09-22 16:53 | **HOLDS** |
| 10 | `frankel` | `laguna_muzel` | `laguna_muzel` (laguna / qfp) | `…/variants/laguna_muzel/vendor_dlkm.modules.blocklist` | `ff1c568e4d94ecea` | `fa6e97ae9e2e4ebe` | ✅ 2026-09-22 15:34 | **HOLDS** |
| 11 | `blazer` | `laguna_muzel` | `laguna_muzel` (laguna / qfp) | `…/variants/laguna_muzel/vendor_dlkm.modules.blocklist` | `ff1c568e4d94ecea` | `fa6e97ae9e2e4ebe` | ✅ 2026-09-22 17:18 | **HOLDS** |
| 12 | `mustang` | `laguna_muzel` | `laguna_muzel` (laguna / qfp) | `…/variants/laguna_muzel/vendor_dlkm.modules.blocklist` | `ff1c568e4d94ecea` | `fa6e97ae9e2e4ebe` | ✅ 2026-09-23 09:10 | **HOLDS** |
| 13 | `rango` | `laguna_rango` | `laguna_rango` (laguna / goodix) | `…/device/rango/vendor_dlkm.modules.blocklist` | `61a2d0fd8274d0fb` | `fa6e97ae9e2e4ebe` | ⚠ 2026-08-20 (pre-resolver) | HOLDS (make+content) |

**Built-artifact proofs of the four mis-excision traps named in the packet:**

| Trap | Built evidence | Result |
|---|---|---|
| `shiba`/`husky` must **not** inherit `akita`'s blocklist | `shiba`/`husky` BUILT contain `blocklist bcmdhd4398`; `akita` BUILT contains `blocklist bcmdhd4383`. Token groups differ (`4a09…` vs `5499…`). | ✅ correct |
| `laguna_muzel` is QFP vs `laguna_rango` Goodix | `frankel`/`blazer`/`mustang` BUILT `vendor/lib64/libqfp-service.so` + `libqfpsuez.so` (QFP); `rango` has neither (Goodix). Registry FP column matches. | ✅ correct |
| `komodo` uses a device-local blocklist copy | BUILT SRC = `device/komodo/…`; token group `4b404489a8e5c17d` **identical** to `tokay`/`caiman` (caimito canonical). | ✅ correct |
| Blocklist file is the resolver's output | Board hooks assign `BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)` (12/13; `akita` uses the literal registry-canonical path). BUILT content == SRC tokens. | ✅ correct |

> **Byte note:** BUILT blocklists are **token-identical** to SRC but **not byte-identical** — the
> build strips blank lines (e.g. `shiba` differs only by 2 blank lines). Byte-equality claims must
> therefore be made at token level. `komodo` pin ≡ canonical is token-level (14/14), as documented.

### 3.1 VINTF manifest provenance (built)

`out/target/product/<dev>/vendor/etc/vintf/manifest.xml` header, all 13 present and radio-free:

| Device | manifest `Input:` |
|---|---|
| shiba | `vendor_manifest_no_radio_shiba.xml` |
| husky | `vendor_manifest_no_radio_husky.xml` |
| akita | `vendor_manifest_no_radio_akita.xml` |
| tokay, caiman, komodo, comet, tegu | `vendor_manifest_no_radio.xml` |
| stallion | `vendor_manifest_no_radio_stallion.xml` |
| frankel, blazer, mustang | `vendor_manifest_no_radio_laguna_muzel.xml` |
| rango | `vendor_manifest_no_radio_rango.xml` |

Corroboration (surfaces lane): the BUILT laguna manifests (`frankel`/`blazer`/`mustang`/`rango`)
carry **0** `android.hardware.media.c2` name lines (the `media.c2` collision fix landed in the
current `out/`); the other 9 carry 2.

---

## 4. Findings

### F-001 — Low — Re-entry guard silently re-resolves a different registered device; the in-file claim that the fail-loud checks abort is **false**
- **Evidence.** `excision-variant-select.mk:38-52`. Attack **G** (`resolver_attacks.txt`):
  resolve `shiba` (→ `zuma_shusky`), then a second `include` with `GUARDTALK_DEVICE := tokay`
  re-resolves **silently, `exit 0`**, variant flips to `zumapro_caimito`. The comment at
  `:43-46` states *"An include that explicitly names a DIFFERENT device is NOT swallowed: it falls
  through to the resolution below, where the fail-loud checks abort."* — it does **not** abort for a
  **registered** different device. (It does abort for an **unregistered** different device.)
- **Impact.** Defense-in-depth only. In a single-product `make` run the board hook and product hook
  name the same codename (or the late hook sees identity cleared → no-op), so this is unreachable in
  practice. This reproduces prior **Q-PORT-FLASH-CLI-9DEV L-1** exactly; the comment was not corrected.
- **Recommendation.** Either `$(error)` when `GT_EXCISION_CANDIDATE_DEVICE` is non-empty and differs
  from `GT_EXCISION_RESOLVED`, or delete the false sentence and state the real behaviour.

### F-002 — Low — Explicit `GUARDTALK_EXCISION_VARIANT` override bypasses the kernel-family cross-check (latent mis-excise)
- **Evidence.** Attack **N**: `GUARDTALK_DEVICE := shiba` + `GUARDTALK_EXCISION_VARIANT := zuma_akita`
  → `exit 0`, `shiba` is handed `vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist`
  (`bcmdhd4383`, the wrong Wi-Fi driver). The token-drift guard passes because it compares the built
  blocklist against the **overridden** variant's canonical file, not against the device's real family.
- **Impact.** A stale/erroneous per-device override would silently mis-excise the exact class this
  card claims to close. **No device sets `GUARDTALK_EXCISION_VARIANT` today** (verified), so it is
  latent, not live.
- **Recommendation.** Reject an explicit override whose variant `SOC`/`KERNEL_FAMILY` contradicts the
  device's registered row, or drop the override path entirely.

### F-003 — Low — Sibling VINTF device-resolver has a silent default (tokay manifest)
- **Evidence.** `radio-excised/vintf-excised.mk:30-58`. Probe (`vintf_provenance_and_default.txt`):
  `PRODUCT_DEVICE=unknowndev` and `PRODUCT_DEVICE=''` both silently select
  `vendor_guardtalk/vintf/vendor_manifest_no_radio.xml` at `exit 0` — no `$(error)`.
- **Impact.** The variant resolver is fail-loud by design, but the adjacent per-device manifest
  selector is not: any future/unrecognised device silently ships the tokay-derived manifest
  (a `check_vintf` failure at best, a wrong manifest at worst).
- **Recommendation.** Add an explicit `else` that `$(error)`s, or an allowlist of the 5 devices that
  legitimately share `vendor_manifest_no_radio.xml` (`tokay`,`caiman`,`komodo`,`comet`,`tegu`).

### F-004 — Low — 4/13 devices have no **post-resolver** built artifact in `out/`
- **Evidence.** Resolver files mtime **2026-09-21/22**; built blocklists for `akita` (2026-07-24),
  `tokay` (2026-07-23), `komodo` (2026-09-15) and `rango` (2026-08-20) **predate** it. Their
  stamps are equally old (`akita-latest` 07-25, `tokay` 07-25, `komodo` 09-15, `rango` 08-02).
- **Impact.** The acceptance criterion *"per-device resolved-variant proof from a BUILT artifact"* is
  met for **9/13** from `out/`; for the other 4 (ironically the in-force reference devices) the
  proof is make-level resolution + pre-resolver token-identical content, not a rebuilt image. The
  `EXCISION_MATRIX.md §6` "zero-regression by content rematch" is asserted, not re-built.
- **Recommendation.** Record the gap explicitly in the umbrella audit, or rebuild/re-stamp the 4
  (out of this lane's authority — no rebuild/re-stamp permitted here).

### F-005 — Low — `REGEN_HOOKS.md` per-device coverage is 4/13 (documented gap, matches `E-7a`)
- **Evidence.** `find vendor/guardtalk/device -name REGEN_HOOKS.md` → `komodo`, `rango`, `tokay`,
  `akita` + one shared `device/REGEN_HOOKS.md`. **9/13** (`shiba`,`husky`,`caiman`,`comet`,`tegu`,
  `stallion`,`frankel`,`blazer`,`mustang`) have no per-device regen doc.
- **Impact.** An `adevtool generate-all` on those 9 has no device-local record of the hooks to
  re-apply. (Hooks are currently present 13/13, so no live regression.)
- **Recommendation.** Deliver `T-EXCISE-REGEN-GUARD` with a fail-closed check enumerating 13/13;
  state the 4/13 → 13/13 gap as a finding, as the card already requires.

### F-006 — Low — The entire shared excision core is untracked in git
- **Evidence.** `git -C vendor/guardtalk status --short` → `?? feature-excised/excision-variant-select.mk`,
  `?? feature-excised/excision-variants.mk`, `?? feature-excised/variants/…` (5 files). The registry,
  resolver and 5 canonical blocklists are working-tree only (HEAD `314714a`, 2026-09-16).
- **Impact.** No git safety net / no reversibility guarantee for the core that closes the silent-no-op
  class; an `adevtool` or worktree operation could lose it.
- **Recommendation.** Commit the shared core with the hooks (respecting the APPROVED gate), or add it
  to a tracked overlay.

### F-007 — Low — The documented Wave-2 master gate is force-set true, overriding per-device flags
- **Evidence.** `guardtalk-feature-excised.mk:31` sets `GUARDTALK_FEATURE_EXCISED_WAVE2 := true`
  **unconditionally**, before the `ifeq (…,true)` body (line 33) — despite the file's own doc and
  `guardtalk-flags.mk` describing that flag as the master gate.
- **Impact.** A device that set the flag `false` would still get Wave-2 excision (the gate is inert).
  It **cannot** cause a silent no-op (it forces excision *on*), so it is a parameterization-truthfulness
  defect, not a regression. All 13 currently set `true`, so no live effect.
- **Recommendation.** Remove the self-set now that `guardtalk-radio-excised.mk:15` loads
  `guardtalk-flags.mk`, or document the override as intentional.

### F-008 — Info — Inherited `GUARDTALK_DEVICE` can hijack resolution for 4 devices
- **Evidence.** Attack **J**: `env GUARDTALK_DEVICE=tokay PRODUCT_DEVICE=akita make …` → resolves
  `zumapro_caimito` (`exit 0`); control (`PRODUCT_DEVICE=akita` alone) → `zuma_akita`. The resolver's
  `$(or $(GUARDTALK_DEVICE),…)` gives an inherited pin priority over `PRODUCT_DEVICE`.
  `guardtalk-flags.mk` pins `GUARDTALK_DEVICE` for **9** devices but **not** for
  `akita`,`tokay`,`komodo`,`rango`.
- **Impact.** Requires an operator shell with a stale **exported** `GUARDTALK_DEVICE` — the tree never
  exports it, and the board hook re-pins it later — so exploitability is low. `akita`/`tokay`/`komodo`/
  `rango` are the only exposed set.
- **Recommendation.** Add `GUARDTALK_DEVICE := <dev>` to those 4 `guardtalk-flags.mk` (mirroring the
  other 9).

### F-009 — Info / disagreement — two prior author suites are RED at audit time
- `verify_port_kernel_matrix_static.sh` → `exit 1` (203 pass / 3 hold / **5 FAIL**): `trunk_staging`
  absence/`resolved` sets disagree with expectation for `shiba`/`husky`/`comet`/`tegu`; three
  `device/google/*-kernels/6.1/trunk-14096387` dirs exist that the card says it only documents.
- `verify_port_matrix_preflight_static.sh` → `exit 1` (109 pass / **4 FAIL**, "at least one attack
  succeeded"): same `trunk_staging` presence for `shiba`/`husky`/`comet`/`tegu` (`vectorA`).
- **Impact.** The prior `T-PORT-KERNEL-MATRIX` / `T-PORT-MATRIX-PREFLIGHT` claims are **not**
  reproducible green in this worktree. These are kernel-tree layering issues, not the variant resolver,
  but they contradict the "static-verified" status presented for those cards.
- **Recommendation.** Reconcile the kernel-tree state (or re-derive the 4-absence claim) before the
  umbrella audit signs off. Do not read these as resolver defects.

---

## 5. Falsification log

Harness: `/tmp/gt-audit/run_attacks.sh` (real GNU `make 4.3`, repo root, `-f` scratch makefiles) —
raw output in `.agent-comm/evidence/A-EXCISE-13DEV-NONREGRESSION/resolver_attacks.txt`.

| ID | Attack | Expected | Observed | Outcome |
|---|---|---|---|---|
| A | Registered device control (`shiba`) | resolve `zuma_shusky` | `exit 0`, `zuma_shusky` | **HOLDS** |
| B | Unknown codename, no SoC | `$(error)` | `exit 2` "has NO excision variant entry" | **HOLDS** |
| C | Unknown codename + SoC `zuma` | `$(error)` ambiguous | `exit 2` "AMBIGUOUS (candidates: zuma_shusky zuma_akita)" | **HOLDS** |
| D | Unknown codename + SoC `zumapro` | `$(error)` ambiguous | `exit 2` 4 candidates listed | **HOLDS** |
| E | Explicit unknown variant | `$(error)` | `exit 2` "unknown excision variant" | **HOLDS** |
| F | No identity at all | `$(error)` | `exit 2` "no known device identity" | **HOLDS** |
| G | Second include, **different registered** device | (comment claims abort) | `exit 0`, `shiba → tokay` silently | **DRIFT → F-001** |
| H | Second include, **same** device | no-op | `exit 0`, unchanged | **HOLDS** |
| I | Second include, identity cleared | no-op | `exit 0`, unchanged | **HOLDS** |
| J | Inherited `GUARDTALK_DEVICE` env pin | (should not override device) | `akita`→`zumapro_caimito` (`exit 0`) | **DRIFT → F-008** |
| J′ | Control: `PRODUCT_DEVICE=akita` only | `zuma_akita` | `exit 0`, `zuma_akita` | HOLDS |
| J″ | Control: `PRODUCT_DEVICE=rango` only | `laguna_rango` | `exit 0`, `laguna_rango` | HOLDS |
| K | `shiba` pinned to `akita` blocklist | `$(error)` | `exit 2` "pins blocklist … resolves to" | **HOLDS** |
| L | Blocklist file missing | `$(error)` | `exit 2` "which does not exist" | **HOLDS** |
| M | `shiba` pinned to `komodo` blocklist | `$(error)` | `exit 2` path-mismatch | **HOLDS** |
| N | Explicit `zuma_akita` variant for `shiba` | (should reject cross-family) | `exit 0`, `shiba` gets akita blocklist | **DRIFT → F-002** |
| O | Sibling VINTF resolver, unknown/empty device | (should error) | `exit 0`, silent tokay manifest | **DRIFT → F-003** |
| P | `shusky` ⊃ `husky` substring (prior L-2) | — | not re-derived here (flash CLI frozen/APPROVED, out of lane) | **Not tested** |

**Net: 14 attacks upheld fail-loud / no-op; 3 silent paths reproduced (F-001, F-008, F-002) plus 1
sibling-resolver default (F-003) — all Low, none reachable in a single-product build.**

---

## 6. Incumbent `*-latest` symlinks

| Link | Target | inode | mtime | Note |
|---|---|---|---|---|
| `tokay-latest` | **(ABSENT)** | — | — | only `latest → tokay-20260725-102506` exists (legacy alias, deliberate) |
| `akita-latest` | `akita-20260725-101434` | 193110357 | 2026-07-25 10:14 | unchanged |
| `komodo-latest` | `komodo-20260915-063833` | 193110380 | 2026-09-15 06:39 | unchanged |
| `rango-latest` | `rango-20260802-130756` | 193110354 | 2026-08-02 13:08 | **required target held** |
| `caiman-latest` | `caiman-20260922-090535` | 193110382 | 2026-09-22 09:06 | current caiman port stamp |
| `latest` | `tokay-20260725-102506` | — | — | unchanged |

No link target changed under this feature's mtimes (resolver 09-21/22). The `tokay` **`-latest`**
symlink does **not** exist — the packet's "tokay `*-latest`" is satisfied by the legacy `latest`
alias. A strict before/after inode comparison is not possible from this lane (no baseline snapshot
was captured by the auditor before the program; current inodes recorded above for the umbrella lane).

---

## 7. Agreement / disagreement with prior claims

| Prior claim | Independent result | Agreement |
|---|---|---|
| `T-PORT-EXCISION-MATRIX` — 13/13 resolve from data; fail-loud on unknown/ambiguous/drift | 13/13 resolve as expected; every unknown/ambiguous/drift attack aborts `exit 2` | **AGREE** |
| `T-PORT-EXCISION-MATRIX` — `verify_port_excision_matrix_static.sh` all green | re-ran: `PASS_COUNT=128 HOLD=0 FAIL=0`, exit 0 | **AGREE** (but the suite does **not** test attack G/N/J/O — coverage gap) |
| `T-PORT-SHARED-CORE-FIX` — silent no-op removed | no silent no-op on any normal path; 3 pathological silent paths remain (Low, unreachable) | **AGREE (with F-001/F-002/F-008)** |
| `T-PORT-KERNEL-MATRIX` — static-verified | re-ran `verify_port_kernel_matrix_static.sh`: **exit 1**, 5 FAIL | **DISAGREE → F-009** |
| `T-PORT-MATRIX-PREFLIGHT` — static-verified | re-ran `verify_port_matrix_preflight_static.sh`: **exit 1**, 4 FAIL | **DISAGREE → F-009** |
| `verify_remediate_b2_excise_host.sh` | re-ran: **exit 0**, `RESULT: PASS (host) 55/4/0` | **AGREE** |
| `verify-on-device.sh` | **NOT RUN** (requires `adb`; forbidden) | n/a |
| `A-PORT-MATRIX-R2` prior Low (resolver re-entry comment overstates) | reproduced verbatim on current code (F-001) | **CONFIRMED** |

---

## 8. Evidence inventory (raw)

All under `.agent-comm/evidence/A-EXCISE-13DEV-NONREGRESSION/`:

| File | Contents |
|---|---|
| `built_blocklists.txt` | sha256 + line count + mtime for 13 built `modules.blocklist`; token-group hashes |
| `per_device_resolution.txt` | per-device resolver output (variant/SoC/FP/blocklist) |
| `resolver_attacks.txt` | full attack harness transcript (A–N) |
| `vintf_provenance_and_default.txt` | built manifest headers ×13; VINTF default-fallthrough probe |
| `symlinks_and_regen_hooks.txt` | incumbent symlink targets/inodes; `REGEN_HOOKS.md` coverage |
| `author_verifiers.txt` | author-side suite summary lines (re-run) |

---

## 9. Honesty / residual

- **No** device, `adb`, `fastboot`, flash, boot or runtime result is claimed. `LIVE_FLASH_CLAIMED=false`,
  `FLASH_READY=false`. `rango-latest` left at `rango-20260802-130756`.
- Gate 5: **HUMAN SKIP** — no self-critique score invented.
- No product / test / filter / flash / packer / doctrine / queue-authoritative file was modified;
  **`.agent-comm/inbox/TO_ARCHITECT.md` was NOT touched** (parallel auditors); no task status changed.
- Experiments were confined to `/tmp/gt-audit/`; generated `vendor/google_devices/*` trees were read
  only.
- Not re-derived in this lane (other auditors' scope): `A-EXCISE-RADIO`/`BT`/`LOC`/`SURFACES` residue,
  the flash-CLI `normalize_device` substring issue (prior L-2), and the `media.c2` stamp-time question.

*Auditor (Panel 5) — read-only. Never APPROVED.*
