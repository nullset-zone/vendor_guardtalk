# GuardTalkOS Gen 8 / 9 / 10 Port — Program-Gate Preflight (`T-PORT-MATRIX-PREFLIGHT`)

> **Task:** `T-PORT-MATRIX-PREFLIGHT` (PROGRAM GATE, P0)
> **Charter:** `DEC-PORT-GEN8910-001`
> **Owner root:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`
> **Repository:** `grapheneos-worktree`
> **Date:** 2026-09-21
> **Status:** `REVIEW` (Backend Engineer) — **never `APPROVED` by this task**
> **Scope:** prerequisites only. **No** device layer, **no** stamp, **no** advertise, **no** flash.

## 0. Explicit non-claims

- `LIVE_FLASH_CLAIMED=false`. No device was attached to this host; no on-device, boot, flash,
  or `fastboot` result is claimed anywhere in this document.
- This document contains **no** boot-green claim for any device (in particular `rango`).
- Nothing in `vendor/guardtalk/device/` was created, modified, or removed. All nine unported
  device layers remain **ABSENT**.
- Nothing in `releases/desktop-flash/` was touched. All five `*-latest` symlinks are unchanged.
- No commit was made (this worktree is **not** a git repository — no `.git` at root or parent —
  so there is no `git status` / `git diff` provenance; verification is by **content rematch**).
- No factory URL, blob, kernel prebuilt, or PASS was invented.

## Gate -1 record (in-process)

| Check | Result |
|-------|--------|
| `governance_loaded` | **true** — `.aegis/governance/laws/` = 24 YAML (`law_00_human_authority` … `law_23_observability`); `.aegis/governance/gates/` = 11 YAML (`gate_neg1_guardian_first` … `gate_09_rollback`). `.aegis` → `../aegis-global` (relative symlink). |
| `scope_confirmed` | **true** — prerequisites-only; target paths and forbidden paths as per the dispatch packet. |
| `authority_context_resolved` | **true** — owner root `TASK_QUEUE.md`; `repository_id=grapheneos-worktree`; `.aegis-config.json` `gate_minus1.mode: in_process`. |
| Remote governance calls | **NONE**. `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP were **not** called or discovered (`discover_remote_tools=false`, `call_verifier=false`, `call_guardian=false`). No deadlock possible. |

Laws applied in-process: 0, 2, 4, 6, 7, 9, 10, 11, 12, 16, 19, 20.

## 1. Method and sources

Every value below was **re-derived from primary sources in this worktree or from live
authoritative upstream endpoints** — never copied from the Architect's table. Each claim
carries a path/host anchor so it can be independently re-run.

| Prerequisite | Primary source (read-only) |
|---|---|
| adevtool device config | `vendor/adevtool/config/device/<dev>.yml` (+ `common/gen{8,9,10}pixel.yml` → `pixel.yml`) |
| `PRODUCT_MODEL` | `vendor/adevtool/vendor-skels/google_devices/<dev>/<dev>.mk` |
| SoC platform | `vendor/adevtool/config/mk/google_devices/device/<dev>/` (`platform/<soc>` refs) + `common/gen{8,9,10}pixel.yml` |
| adevtool cross-check (SoC grouping) | `vendor/adevtool/config/device/pixel-gen{8,9,10}.yml` (`all.yml` is the union list) |
| Kernel tree | `device/google/*-kernels/**` (on disk) |
| `TARGET_KERNEL_DIR` | `vendor/adevtool/config/mk/google_devices/device/<dev>/device.mk` |
| `RELEASE_KERNEL_<DEV>_DIR` | `build/release/flag_values/<channel>/RELEASE_KERNEL_<DEV>_DIR.textproto` |
| build-index (main channel) | `vendor/adevtool/config/build-index/build-index-main.yml` |
| Reference spec / state | `vendor/adevtool/vendor-specs/google_devices/<dev>.yml`, `vendor/state/<dev>.json` |
| Upstream support | `https://grapheneos.org/faq` (Device support) + `https://releases.grapheneos.org/<dev>-stable` |
| Factory image (stock) | `https://dl.google.com/dl/android/aosp/<dev>-<buildid>-factory-<hash8>.zip` (URL pattern per `vendor/adevtool/src/images/build-index.ts:31`) |
| Factory image (GrapheneOS) | `https://releases.grapheneos.org/<dev>-install-<releaseid>.zip` |
| Existing GuardTalk state | `vendor/google_devices/`, `vendor/guardtalk/device/`, `releases/desktop-flash/*-latest`, `vendor/guardtalk/web-installer/src/types.ts`, `vendor/guardtalk/scripts/pack-webinstall-channel.sh` |
| Precedents | `vendor/guardtalk/docs/AKITA_PORT_PREFLIGHT.md`, `KOMODO_PORT_PREFLIGHT.md`, `RANGO_PORT_PREFLIGHT.md` |

## 2. Independently re-derived 13-device matrix

**The set is exactly the 13 Gen 8/9/10 Pixels. Nothing else is in scope.**

| # | Gen | `PRODUCT` | `PRODUCT_MODEL` (from vendor-skel) | SoC | adevtool SoC list | kernel dir (resolved) | build-index `main` entries | live `vendor/google_devices/` | `*-latest` |
|--:|:--:|---|---|---|---|---|:--:|:--:|---|
| 1 | 8 | `shiba` | Pixel 8 | `zuma` | `pixel-gen8` | `shusky-kernels/6.1/grapheneos` | 58 | ✗ | — |
| 2 | 8 | `husky` | Pixel 8 Pro | `zuma` | `pixel-gen8` | `shusky-kernels/6.1/grapheneos` | 58 | ✗ | — |
| 3 | 8 | `akita` | Pixel 8a | `zuma` | `pixel-gen8` | `akita-kernels/6.1/grapheneos` | 46 | ✓ | `akita-latest`→`akita-20260725-101434` |
| 4 | 9 | `tokay` | Pixel 9 | `zumapro` | `pixel-gen9` | `caimito-kernels/6.1/grapheneos` | 47 | ✓ | `latest`→`tokay-20260725-102506` |
| 5 | 9 | `caiman` | Pixel 9 Pro | `zumapro` | `pixel-gen9` | `caimito-kernels/6.1/grapheneos` | 46 | ✗ | — |
| 6 | 9 | `komodo` | Pixel 9 Pro XL | `zumapro` | `pixel-gen9` | `caimito-kernels/6.1/grapheneos` | 46 | ✓ | `komodo-latest`→`komodo-20260915-063833` |
| 7 | 9 | `comet` | Pixel 9 Pro Fold | `zumapro` | `pixel-gen9` | `comet-kernels/6.1/grapheneos` | 45 | ✗ | — |
| 8 | 9 | `tegu` | Pixel 9a | `zumapro` | `pixel-gen9` | `tegu-kernels/6.1/grapheneos` | 29 | ✗ | — |
| 9 | 9 | `stallion` | **Pixel 10a** | **`zumapro`** | `pixel-gen9` | `stallion-kernels/6.1/grapheneos` (literal) | **5** | ✗ | — |
| 10 | 10 | `frankel` | Pixel 10 | `laguna` | `pixel-gen10` | `laguna-kernels/6.6/grapheneos/muzel` (literal) | 29 | ✗ | — |
| 11 | 10 | `blazer` | Pixel 10 Pro | `laguna` | `pixel-gen10` | `laguna-kernels/6.6/grapheneos/muzel` (literal) | 29 | ✗ | — |
| 12 | 10 | `mustang` | Pixel 10 Pro XL | `laguna` | `pixel-gen10` | `laguna-kernels/6.6/grapheneos/muzel` (literal) | 29 | ✗ | — |
| 13 | 10 | `rango` | Pixel 10 Pro Fold | `laguna` | `pixel-gen10` | `laguna-kernels/6.6/grapheneos/rango` (literal) | 24 | ✓ | `rango-latest`→`rango-20260802-130756` |

### 2.1 `stallion` trap — falsified by two independent sources

The two "trap" claims in the dispatch brief are **both confirmed**:

1. **`stallion` is a Pixel 10a on `zumapro`, not `laguna`.** Evidence (independent of the
   brief): `vendor/adevtool/config/mk/google_devices/device/stallion/` resolves to
   `platform/zumapro`; and adevtool's own device-list groups it under **`pixel-gen9.yml`**
   (the `zumapro` group), alongside `tokay,caiman,komodo,comet,tegu` — **not** `pixel-gen10.yml`.
   `PRODUCT_MODEL := Pixel 10a` in `vendor-skels/google_devices/stallion/stallion.mk`.
2. **`stallion` has only 5 main-channel build-index entries** — the thinnest of the 13
   (next thinnest: `rango` 24). See §5.

### 2.2 Already-supported devices — confirmed

`vendor/google_devices/` contains exactly four live modules: `akita`, `komodo`, `rango`,
`tokay`. Four live product `*-latest` symlinks exist: `latest` (tokay), `akita-latest`,
`komodo-latest`, `rango-latest`. The other nine devices have **neither**. This matches the
brief exactly.

## 3. Independent reconciliation vs the Architect's starting values

**Result: zero disagreements.** Every Architecture-verified starting value was reproduced
exactly from primary sources. Recorded here because the brief (Law 7 / Law 16) requires each
disagreement — or its absence — to be explicit.

| Field | Architect starting value | Independently derived | Status |
|---|---|---|---|
| 13-codename set | shiba husky akita / tokay caiman komodo comet tegu stallion / frankel blazer mustang rango | identical | **MATCH** |
| `PRODUCT_MODEL` (13) | Pixel 8 / 8 Pro / 8a / 9 / 9 Pro / 9 Pro XL / 9 Pro Fold / 9a / **10a** / 10 / 10 Pro / 10 Pro XL / 10 Pro Fold | identical (§2) | **MATCH** |
| SoC split | zuma ×3, zumapro ×6 (incl. `tegu`+`stallion`), laguna ×4 | identical | **MATCH** |
| kernel dirs | `shusky/akita/caimito/comet/tegu/stallion`-kernels, `laguna-kernels/6.6/grapheneos/{muzel,rango}` | identical (this is the `cur`-channel view, §4) | **MATCH** |
| build-index main counts | 58,58,46,47,46,46,45,29,**5**,29,29,29,24 | identical | **MATCH** |
| 4 supported devices | tokay, akita, komodo, rango | identical | **MATCH** |

### 3.1 Additional findings (not disagreements — new evidence)

These are **additions** to the starting table, not corrections of it:

- **F1 — trunk channel kernel prebuilts absent for 4 devices.** Under the *dev* lunch
  channel `trunk_staging`, `RELEASE_KERNEL_<DEV>_DIR` resolves to a `trunk-<buildid>` path
  that does **not exist on disk** for `shiba`, `husky`, `comet`, `tegu` (exact paths in §4.2).
  This is the **same class of gap** already documented and closed at LAYER for `akita`
  (`trunk-14096387 → grapheneos` symlink) and `rango`. It is a **named LAYER prerequisite**,
  not an unprovable one: the complete GrapheneOS kernel prebuilt tree for each device is
  present on disk (§4.3).
- **F2 — `RELEASE_KERNEL_<DEV>_DIR` is channel- and generation-dependent.** `tegu` has **no**
  `…_DIR` flag in `ap3a`, `ap4a`, `bp1a`, `bp2a` (it appears only from `bp3a` onward);
  `stallion` has **no** `…_DIR` flag in **any** channel (it uses a literal path by design).
  Recorded so `T-PORT-KERNEL-MATRIX` does not assume flag uniformity.
- **F3 — 5 literal-path devices confirmed.** `stallion`, `frankel`, `blazer`, `mustang`,
  `rango` use `TARGET_KERNEL_DIR := <literal>`; the other 8 use
  `TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_<DEV>_DIR)`. Count 5 / 8 matches the brief. Note that
  `RELEASE_KERNEL_{FRANKEL,BLAZER,MUSTANG,RANGO}_DIR` flags exist but are **unused** by those
  devices' `device.mk` (they resolve to an irrelevant `25Q4-…`/`trunk-…` path).
- **F4 — `stallion` pins the oldest of its 5 builds.** `stallion.yml` sets
  `build_id: BD6A.251031.001.A4`; the other four indexed builds are `CP1A.2603…`–`CP1A.2605…`.
  The pin is stale but currently fetchable (§7). See §5.
- **F5 — C4 two-part mechanism verified.** `trunk-14096387 → grapheneos` symlinks exist for
  `akita-kernels/6.1`, `caimito-kernels/6.1` (and `laguna-kernels/6.6/trunk-14072179 →
  grapheneos`) but **not** for `shusky-kernels/6.1`, `comet-kernels/6.1`, `tegu-kernels/6.1`.
  Confirmed by `readlink`.

## 4. Kernel-dir resolution (channel-dependent)

`TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_<DEV>_DIR)` for 8 devices; `:=` literal for 5.

### 4.1 `cur` channel — the production lunch (`<dev>-cur-*`)

`vendor/guardtalk/scripts/sign-build.sh:188` documents the release lunch as
`lunch $DEVICE-cur-user`; `lunch-tokay-cur-user.log` is a recorded `cur` lunch.
Under `cur`, **all 13 resolve to an existing, complete directory** (`muzel`/`rango` for laguna).

| Device | `TARGET_KERNEL_DIR` (`cur`) | Exists? | `vendor_kernel_boot.modules.load` |
|---|---|---|---|
| shiba | `device/google/shusky-kernels/6.1/grapheneos` | ✅ | ✅ |
| husky | `device/google/shusky-kernels/6.1/grapheneos` | ✅ | ✅ |
| akita | `device/google/akita-kernels/6.1/grapheneos` | ✅ | ✅ |
| tokay | `device/google/caimito-kernels/6.1/grapheneos` | ✅ | ✅ |
| caiman | `device/google/caimito-kernels/6.1/grapheneos` | ✅ | ✅ |
| komodo | `device/google/caimito-kernels/6.1/grapheneos` | ✅ | ✅ |
| comet | `device/google/comet-kernels/6.1/grapheneos` | ✅ | ✅ |
| tegu | `device/google/tegu-kernels/6.1/grapheneos` | ✅ | ✅ |
| stallion | `device/google/stallion-kernels/6.1/grapheneos` (literal) | ✅ | ✅ |
| frankel | `device/google/laguna-kernels/6.6/grapheneos/muzel` (literal) | ✅ | ✅ |
| blazer | `device/google/laguna-kernels/6.6/grapheneos/muzel` (literal) | ✅ | ✅ |
| mustang | `device/google/laguna-kernels/6.6/grapheneos/muzel` (literal) | ✅ | ✅ |
| rango | `device/google/laguna-kernels/6.6/grapheneos/rango` (literal) | ✅ | ✅ |

### 4.2 `trunk_staging` channel — the dev/preflight lunch (`<dev>-trunk_staging-*`)

Used by the akita / komodo / rango preflights and by the caiman LAYER card
(`lunch caiman-trunk_staging-userdebug`). The flag **is defined** for every one of the 8
flag-driven devices, but the resolved directory is **absent on this host** for four:

| Device | `RELEASE_KERNEL_<DEV>_DIR` (`trunk_staging`) | Exists? | Exact missing path (if absent) |
|---|---|---|---|
| shiba | `device/google/shusky-kernels/6.1/trunk-14096387` | ❌ | `device/google/shusky-kernels/6.1/trunk-14096387` |
| husky | `device/google/shusky-kernels/6.1/trunk-14096387` | ❌ | `device/google/shusky-kernels/6.1/trunk-14096387` |
| akita | `device/google/akita-kernels/6.1/grapheneos` | ✅ | — |
| tokay | `device/google/caimito-kernels/6.1/grapheneos` | ✅ | — |
| caiman | `device/google/caimito-kernels/6.1/trunk-14096387` → `grapheneos` | ✅ | — |
| komodo | `device/google/caimito-kernels/6.1/trunk-14096387` → `grapheneos` | ✅ | — |
| comet | `device/google/comet-kernels/6.1/trunk-14096387` | ❌ | `device/google/comet-kernels/6.1/trunk-14096387` |
| tegu | `device/google/tegu-kernels/6.1/trunk-14096387` | ❌ | `device/google/tegu-kernels/6.1/trunk-14096387` |
| stallion | `device/google/stallion-kernels/6.1/grapheneos` (literal) | ✅ | — |
| frankel | `device/google/laguna-kernels/6.6/grapheneos/muzel` (literal) | ✅ | — |
| blazer | `device/google/laguna-kernels/6.6/grapheneos/muzel` (literal) | ✅ | — |
| mustang | `device/google/laguna-kernels/6.6/grapheneos/muzel` (literal) | ✅ | — |
| rango | `device/google/laguna-kernels/6.6/grapheneos/rango` (literal) | ✅ | — |

**No `RELEASE_KERNEL_<DEV>_DIR` flag is "unresolved"** for the intended lunches: every
flag-driven device has a defined value in both `cur` and `trunk_staging`. The four absences
above are **missing directories**, and the precedent fix (documented in-force for `akita` and
`rango`) is a `trunk-<buildid> → grapheneos` symlink created at **LAYER**, which the
`T-PORT-KERNEL-MATRIX` card will formalize. `stallion` has **no** `RELEASE_KERNEL_STALLION_DIR`
flag in any channel (the literal path is by design — see `stallion.yml`/`device.mk`).

### 4.3 Kernel trees are complete, not stubs

Every resolved `grapheneos` tree contains a full prebuilt set (`vendor_kernel_boot.modules.load`
present; 338–473 entries): shusky 344, akita 338, caimito 363, comet 355, tegu 340,
stallion 355, laguna/muzel 473, laguna/rango 446.

## 5. `build-index-main.yml` coverage (main channel)

Counts are block headers `^<dev> <BUILD_ID>:` in
`vendor/adevtool/config/build-index/build-index-main.yml`.

| Device | entries | Device | entries |
|---|:--:|---|:--:|
| shiba | 58 | stallion | **5** |
| husky | 58 | frankel | 29 |
| akita | 46 | blazer | 29 |
| tokay | 47 | mustang | 29 |
| caiman | 46 | rango | 24 |
| komodo | 46 | | |
| comet | 45 | | |
| tegu | 29 | | |

**Coverage is uneven (5 – 58).** `stallion` is the thin-margin case: only **5** main-channel
builds, and the device config pins the **oldest** of them (`BD6A.251031.001.A4`). The pin
resolves to a real, currently-downloadable stock factory image (§7), so `generate-all` is
provable **today** — but a device with 5 indexed builds has a much smaller margin if the
pinned build is ever withdrawn by Google. This is recorded as the explicit stallion
risk, not hidden.

## 6. Upstream GrapheneOS support (per device) — authoritative citation

**Citation A — `https://grapheneos.org/faq` → "Device support" section** (fetched 2026-09-21,
HTTP 200, 113,970 bytes). It lists **all 13**:

`Pixel 10a (stallion)`, `Pixel 10 Pro Fold (rango)`, `Pixel 10 Pro XL (mustang)`,
`Pixel 10 Pro (blazer)`, `Pixel 10 (frankel)`, `Pixel 9a (tegu)`, `Pixel 9 Pro Fold (comet)`,
`Pixel 9 Pro XL (komodo)`, `Pixel 9 Pro (caiman)`, `Pixel 9 (tokay)`, `Pixel 8a (akita)`,
`Pixel 8 Pro (husky)`, `Pixel 8 (shiba)`.

**Citation B — `https://releases.grapheneos.org/<dev>-stable`** (probed 2026-09-21). All 13
returned **HTTP 200** with a live stable pointer:

```
<dev> 2026091900 1789794102 <dev> stable     # identical release id for all 13
```

**Citation C — in-tree corroboration:** `vendor/guardtalk/docs/WEB_INSTALLER.md:114`
`supportedDevices` list — its Gen 8/9/10 subset is **exactly** these 13 codenames; and each
device has ≥1 main-channel `build-index` entry (§5).

Verifying all three sources agree, and that they agree with the adevtool device configs, is
what makes upstream support **proven** rather than assumed for every device.

## 7. `generate-all` capability and factory-image obtainability

`generate-all` needs: an adevtool device config, a resolvable `build_id`, an indexed stock
build, and a fetchable **stock** factory zip. All four are proven for all 13.

| Device | resolved `build_id` (→ build-index) | Google stock factory URL probe | GrapheneOS `-install-` probe |
|---|---|---|---|
| shiba | `BP4A.260205.001` | `shiba-bp4a.260205.001-factory-35b8480d.zip` → **200** | **206** |
| husky | `BP4A.260205.001` | `husky-bp4a.260205.001-factory-61e86561.zip` → **200** | **206** |
| akita | `BP4A.260205.001` | `akita-bp4a.260205.001-factory-661cb49b.zip` → **200** | **206** |
| tokay | `BP4A.260205.002` | `tokay-bp4a.260205.002-factory-45177450.zip` → **200** | **206** |
| caiman | `BP4A.260205.002` | `caiman-bp4a.260205.002-factory-df6fb7c7.zip` → **200** | **206** |
| komodo | `BP4A.260205.002` | `komodo-bp4a.260205.002-factory-aaec4834.zip` → **200** | **206** |
| comet | `BP4A.260205.002` | `comet-bp4a.260205.002-factory-f5d0eeaf.zip` → **200** | **206** |
| tegu | `BP4A.260205.001` | `tegu-bp4a.260205.001-factory-1c69f00a.zip` → **200** | **206** |
| stallion | `BD6A.251031.001.A4` | `stallion-bd6a.251031.001.a4-factory-7420a527.zip` → **200** | **206** |
| frankel | `BP4A.260205.001` | `frankel-bp4a.260205.001-factory-679ee187.zip` → **200** | **206** |
| blazer | `BP4A.260205.001` | `blazer-bp4a.260205.001-factory-44af5c18.zip` → **200** | **206** |
| mustang | `BP4A.260205.001` | `mustang-bp4a.260205.001-factory-b22707a4.zip` → **200** | **206** |
| rango | `CP1A.260505.005` | `rango-cp1a.260505.005-factory-18bf79d9.zip` → **200** | **206** |

Base URL: `https://dl.google.com/dl/android/aosp/`
(`vendor/adevtool/src/images/build-index.ts:31`). In-tree cached stock zips already exist for
the 4 supported devices under `vendor/adevtool/dl/` (akita, komodo, rango, tokay — primary +
backport). All 13 have a `vendor-specs/google_devices/<dev>.yml` reference spec and a
`vendor/state/<dev>.json` state file, so `generate-all` can both generate **and** verify.

## 8. `T-PORT-CAIMAN` HOLD — re-confirmed as cleared

- Prior hold reason: *"Launcher+Security sprint takes precedence 2026-07-22"* — **closed by
  the Architect** (that sprint completed) and superseded by `DEC-PORT-GEN8910-001`.
- **Nothing else blocks `caiman`.** Device-specific prerequisites all pass: adevtool config +
  skel + `platform/zumapro`; `PRODUCT_MODEL := Pixel 9 Pro`; kernel dir
  `device/google/caimito-kernels/6.1/grapheneos` present **and** the `trunk_staging` path
  `caimito-kernels/6.1/trunk-14096387 → grapheneos` symlink present; 46 main-index entries;
  `build_id BP4A.260205.002` indexed with a downloadable stock factory; upstream support
  cited (§6).
- The only remaining dependencies are **program-wide**: `T-PORT-MATRIX-PREFLIGHT` (this card)
  and `T-PORT-EXCISION-MATRIX` — both apply to every Wave A device equally.
- `vendor/guardtalk/device/caiman/` remains **ABSENT** (verified) — the LAYER card
  (`T-PORT-CAIMAN`) owns creating it.

## 9. Per-device GO / NO-GO verdict

Fail-closed rule applied: a device is **NO-GO** if upstream support, a factory image, or
`generate-all` capability cannot be **proven**. All three are proven for all 13 (§6, §7);
adevtool config, `PRODUCT_MODEL`, SoC, kernel tree, and build-index coverage are also proven.

> **Result: 13 GO, 0 NO-GO.** No device is forced through; each GO below carries its named
> mandatory LAYER/lunch prerequisite.

| # | Device | Verdict | Named prerequisite before LAYER/lunch (all are within the program's own cards) |
|--:|---|:--:|---|
| 1 | `shiba` | **GO** | `trunk_staging` lunch needs `device/google/shusky-kernels/6.1/trunk-14096387 → grapheneos` symlink (absent today); `cur` resolves now. |
| 2 | `husky` | **GO** | same as `shiba` (`shusky-kernels/6.1/trunk-14096387`). |
| 3 | `akita` | **GO** | supported reference; no new prerequisite. |
| 4 | `tokay` | **GO** | reference device (`latest`); no new prerequisite. |
| 5 | `caiman` | **GO** | HOLD cleared (§8); `T-PORT-EXCISION-MATRIX` (program-wide) before LAYER. |
| 6 | `komodo` | **GO** | supported; komodo debug sidecar remains unverified (**not** part of this matrix). |
| 7 | `comet` | **GO** | `trunk_staging`: `device/google/comet-kernels/6.1/trunk-14096387` absent → symlink at LAYER; `cur` resolves now. Foldable overlays tracked by `F-PORT-FOLD-OVERLAYS`. |
| 8 | `tegu` | **GO** | `trunk_staging`: `device/google/tegu-kernels/6.1/trunk-14096387` absent → symlink at LAYER; `cur` resolves now. |
| 9 | `stallion` | **GO** | Thin index: 5 main builds, stale pin (oldest). Stock factory fetchable today (§7). Must be re-checked before FLASH; if the pin is withdrawn, stallion becomes **NO-GO**. |
| 10 | `frankel` | **GO** | laguna literal kernel path present. No new prerequisite. |
| 11 | `blazer` | **GO** | laguna literal kernel path present. No new prerequisite. |
| 12 | `mustang` | **GO** | laguna literal kernel path present. No new prerequisite. |
| 13 | `rango` | **GO** (port prerequisites) | Already ported (`rango-latest`). **Promotion is `HOLD`**: requires independently proven boot-green (no hardware) — `T-PORT-RANGO-PROMOTE`. `rango-latest` must **not** be retargeted off `rango-20260802-130756`. |

## 10. Per-device prerequisite ledger

Legend: ✅ present/proven · ⚠ present with a named condition · ➖ not applicable.

| Device | adevtool cfg | skel | `platform` | kernel tree | `trunk_staging` kernel | build-index | spec+state | stock factory | upstream | vendor module | GuardTalk layer | Verdict |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| shiba | ✅ | ✅ | zuma | ✅ | ⚠ symlink needed | ✅ 58 | ✅ | ✅ | ✅ | ✗ (expected) | ✗ (expected) | GO |
| husky | ✅ | ✅ | zuma | ✅ | ⚠ symlink needed | ✅ 58 | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| akita | ✅ | ✅ | zuma | ✅ | ✅ | ✅ 46 | ✅ | ✅ | ✅ | ✅ | ✅ | GO |
| tokay | ✅ | ✅ | zumapro | ✅ | ✅ | ✅ 47 | ✅ | ✅ | ✅ | ✅ | ✅ | GO |
| caiman | ✅ | ✅ | zumapro | ✅ | ✅ (`trunk-14096387`) | ✅ 46 | ✅ | ✅ | ✅ | ✗ (regen at LAYER) | ✗ (LAYER) | GO |
| komodo | ✅ | ✅ | zumapro | ✅ | ✅ (`trunk-14096387`) | ✅ 46 | ✅ | ✅ | ✅ | ✅ | ✅ | GO |
| comet | ✅ | ✅ | zumapro | ✅ | ⚠ symlink needed | ✅ 45 | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| tegu | ✅ | ✅ | zumapro | ✅ | ⚠ symlink needed | ✅ 29 | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| stallion | ✅ | ✅ | zumapro | ✅ (literal) | ✅ (literal) | ⚠ **5**, stale pin | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| frankel | ✅ | ✅ | laguna | ✅ (literal) | ✅ (literal) | ✅ 29 | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| blazer | ✅ | ✅ | laguna | ✅ (literal) | ✅ (literal) | ✅ 29 | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| mustang | ✅ | ✅ | laguna | ✅ (literal) | ✅ (literal) | ✅ 29 | ✅ | ✅ | ✅ | ✗ | ✗ | GO |
| rango | ✅ | ✅ | laguna | ✅ (literal) | ✅ (literal) | ✅ 24 | ✅ | ✅ | ✅ | ✅ | ✅ | GO (promote HOLD) |

## 11. Risk-ordered wave plan (ratified)

Ratified as produced — the ordering is evidence-driven: Wave A takes the **lowest-divergence**
targets (same `zumapro` SoC as the `tokay` reference; `caiman` shares the `caimito-kernels`
family), Wave B is `zuma` (one SoC generation of HAL/module-name divergence), Wave C is
`laguna` (6.6 kernel, new SoC, literal kernel paths, two foldables).

| Wave | SoC | Devices | Entry prerequisite (all must hold) | Priority |
|------|-----|---------|-----------------------------------|:---:|
| **Gate** | all | — | `T-PORT-MATRIX-PREFLIGHT` → `APPROVED` (Architect). | **P0** |
| **A** | `zumapro` | `caiman`, `comet`, `tegu`, `stallion` | Gate ✅; `T-PORT-EXCISION-MATRIX` `APPROVED`; per-device kernel symlink (comet/tegu); stallion pin re-check. | **P0** |
| **B** | `zuma` | `shiba`, `husky` | Wave A closed; `T-PORT-KERNEL-MATRIX` resolution method for the `shusky` kernel symlink; fold-overlays N/A. | P1 |
| **C** | `laguna` | `frankel`, `blazer`, `mustang` (+ promote `rango`) | Wave B closed; laguna literal kernel paths already documented; `rango` promotion gated on independent boot-green. | P1 |
| **Close** | all | — | All waves + `T-PORT-MATRIX-DOCS` + `*-KEYS` HOLD register. | P2 |

Stop-between-waves is mandatory. `T-PORT-EXCISION-MATRIX` + `T-PORT-KERNEL-MATRIX` are the
cross-cutting P0 foundation and gate every wave.

## 12. Blockers / HOLDS register (no silent claims)

| Item | Status | Reason |
|------|--------|--------|
| `T-PORT-<DEV>-KEYS` (9) + existing `{AKITA,KOMODO,RANGO}-KEYS` | **HOLD** | Production signing gate; keys never in-tree. |
| On-device smoke for all 13 | **HOLD** | No operator hardware / no authorisation. DEC-009 in force. No phone attached to this host. |
| `T-PORT-RANGO-PROMOTE` + `rango-latest` retarget | **HOLD** | Needs independently proven boot-green; not claimed. |
| Per-device web-install advertise | **fail-closed** | Device enters `ALLOWED_PRODUCTS` / `WIZARD_DEVICES` / schema enum / `ADVERTISED_DEVICES` only with a `*-latest` stamp + `SHA256SUMS`. |
| `komodo` debug sidecar (`komodo-debug-*`) | **unverified** | Separate B6 program; not part of this matrix. |
| `stallion` stale pin / 5-entry index | **watch** | Documented §5/§9; re-check before FLASH. |
| `LIVE_FLASH_CLAIMED` | **false** | Program-wide. |
| On-device boot for `rango` | **not claimed** | — |

Current advert surface (verified, unchanged by this task): `ALLOWED_PRODUCTS` =
`["tokay","akita","komodo","rango"]` (`vendor/guardtalk/web-installer/src/types.ts:3`);
packer `ADVERTISED_DEVICES=(tokay akita komodo rango)`
(`vendor/guardtalk/scripts/pack-webinstall-channel.sh:27`). **This preflight does not grow it.**

## 13. Out of scope — explicit statement

Gen 6 (`gs101`) and Gen 7 (`gs201`) devices are **out of scope** for this program. The following
codenames are named **only** to state the exclusion, and are **out of scope**:

- Gen 6 codename-references `oriole`, `raven`, `bluejay` — **out of scope**.
- Gen 7 codename-references `panther`, `cheetah`, `lynx`, `felix`, `tangorpro` — **out of scope**.

Consequences: they have **no** wave, **no** GO verdict, **no** advertise entry, and receive no
card in `DEC-PORT-GEN8910-001`. They must never enter the wave plan, a GO verdict, or any
advertise surface. (Their presence in read-only upstream inputs — `vendor/adevtool/config/device/all.yml`
and the `vendor/adevtool/dl/`/`vendor/state/` fixtures — is upstream tooling data and is
neither a wave nor an advertise surface.)

## 14. GuardTalk state invariants (verified untouched)

```
vendor/guardtalk/device/       → akita, emu64a, komodo, rango, tokay   (caiman + 8 others ABSENT) ✅
vendor/google_devices/         → akita, komodo, rango, tokay           (9 others ABSENT) ✅
releases/desktop-flash/*-latest→ latest, akita-latest, komodo-latest,
                                 komodo-debug-latest, rango-latest      (5 symlinks unchanged) ✅
```

No file under `vendor/guardtalk/device/`, `releases/desktop-flash/`,
`vendor/guardtalk/web-installer/`, `keys/`, `doctrine/`, `governance/laws/`,
`governance/gates/` was modified.

## 15. Verification commands (executed; all pass)

```bash
ls -d device/google/{shusky,akita,caimito,comet,tegu,stallion,laguna}-kernels        # all exist
for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
  grep -m1 'PRODUCT_MODEL' vendor/adevtool/vendor-skels/google_devices/$d/$d.mk       # 13/13 match
done
for d in <13>; do grep -rhoE 'platform/(zuma|zumapro|laguna)' \
  vendor/adevtool/config/mk/google_devices/device/$d/ | sort -u; done                # 13/13 resolve
for d in <13>; do grep -cE "^$d " vendor/adevtool/config/build-index/build-index-main.yml; done  # 13/13 ≥ 5
test ! -d vendor/guardtalk/device/caiman                                             # absent ✅
test -d device/google/laguna-kernels/6.6/grapheneos/{muzel,rango}                    # present ✅
# Gen 6/7 "out of scope" codename guard — every match must be on an out of scope line:
grep -nE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro' vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md | grep -v 'out of scope'   # out of scope guard: expect no output
```

Provenance note: this worktree has **no** `.git` at root or parent, so no `git status` /
`git diff` is available. Correctness was verified by **content rematch** (re-running each
derivation and diffing the outputs), not by git.

## 16. Gate 5 — Ultimate Critique self-score

**Self-score: 88 / 100** (threshold 70; `HUMAN SKIP` not invoked).

| Dimension | Score | Note |
|---|:--:|---|
| Matrix independently derived | 20/20 | Every field re-read from primary sources; two traps falsified by ≥2 independent sources each. |
| GO/NO-GO evidence | 18/20 | 13 GO with fail-closed reasoning stated; residual risk is that the 4 `trunk_staging` absences are classified as LAYER prerequisites rather than NO-GO — justified by the akita/rango precedent but arguable. |
| Citation discipline (Law 7.2) | 18/20 | Live citations for support/factory; the `faq` anchor is the page, not a line anchor. |
| Wave-plan justification | 9/10 | SoC/divergence ordering justified; wave sizes not optimized. |
| Non-claims / honesty | 10/10 | `LIVE_FLASH_CLAIMED=false`; no boot/flash claim; provenance limitation disclosed. |
| Residual uncertainty declared | 8/10 | `stallion` margin, `rango` promotion, and `komodo` debug sidecar explicitly flagged. |

**Alternatives considered.** (a) Marking `shiba`/`husky`/`comet`/`tegu` **NO-GO** because the
`trunk_staging` kernel directory is absent — rejected: the *variable* resolves, the complete
`grapheneos` tree is on disk, and the identical gap was closed at LAYER for `akita`/`rango`;
marking them NO-GO would contradict in-force precedent. (b) Marking `stallion` **NO-GO** on
its 5-entry index — rejected: its pinned build is proven present and fetchable *today*;
fail-closed applies to *unprovable* prerequisites, and stallion's is provable-with-caveat.
(c) Using the `cur` channel only — rejected in favour of documenting both channels, because
the caiman LAYER card and the akita/komodo/rango preflights use `trunk_staging`.

**Known bias self-check.** Anchoring: scores were derived after re-running every command, not
from the first read. Confirmation: the two "traps" were deliberately re-derived from an
independent source (adevtool `pixel-gen9.yml`) rather than only re-reading the same files.

---

*Produced by AEGIS Backend Engineer (Panel 2) for `T-PORT-MATRIX-PREFLIGHT`. Status `REVIEW`
only — `APPROVED` is the Architect's verdict. No commit. `LIVE_FLASH_CLAIMED=false`.*
