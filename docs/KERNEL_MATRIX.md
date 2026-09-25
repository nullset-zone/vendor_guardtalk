# KERNEL_MATRIX.md — per-device `TARGET_KERNEL_DIR` resolution (13-device Pixel matrix)

> **Card:** `T-PORT-KERNEL-MATRIX` (P0) — GuardTalkOS Gen 8/9/10 port program
> (`DEC-PORT-GEN8910-001` / `DEC-PORT-GEN8910-002`).
> **Replaces:** the ad-hoc `trunk-<buildid> → grapheneos` symlink trick that had
> to be re-discovered per device from a scratch README.
> **Machine-readable enforcement:** `vendor/adevtool/config/mk/google_devices/device/*/device.mk`
> (every one of the 13 devices carries the validated-resolution block) and
> `vendor/guardtalk/docs/qa/verify_port_kernel_matrix_static.sh`.
> **Scope:** Gen 8 `zuma`, Gen 9 `zumapro`, Gen 10 `laguna`. Gen 6 (`gs101`) and
> Gen 7 (`gs201`) are **out of scope and forbidden** — see "Out of scope" below.

---

## 1. The problem this card closes

`TARGET_KERNEL_DIR` was resolved two different ways, only one of which was
documented, and neither of which failed loudly:

| Style | Devices | Mechanism |
|---|---|---|
| **flag-driven** | 8 | `TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_<DEV>_DIR)`, value read from `build/release/flag_values/<release_config>/RELEASE_KERNEL_<DEV>_DIR.textproto` (upstream, **read-only**) |
| **literal** | 5 | `TARGET_KERNEL_DIR := device/google/<family>-kernels/<ver>/grapheneos[/<variant>]` — no flag consulted |

The failure mode was silent: if the flag had no value, `TARGET_KERNEL_DIR`
became the **empty string**, `$(wildcard $(TARGET_KERNEL_DIR))` was empty, and
the error that surfaced much later was
`BoardConfig-common-gs201-plus.mk: NN: error: vendor_kernel_boot.modules.load not found or empty`
— which does not name the variable, the device, or the two genuinely different
causes. `KOMODO_PORT_PREFLIGHT.md` (~line 95) is the historical record of
exactly that lunch failure.

Two causes were being **conflated**:

* **(i) variable unresolved** — no `RELEASE_KERNEL_<DEV>_DIR` value in this
  release config. Nothing on disk can fix it: the tree cannot know which kernel
  to build. This is a **NO-GO** for that device on that channel.
* **(ii) directory absent** — the variable *is* defined and resolves to a path,
  but the path does not exist in this checkout (an unpinned `trunk-<buildid>`
  kernel prebuilt). This is a **LAYER prerequisite**, **NOT a NO-GO**: it is
  fixed by provisioning the prebuilt tree, which the program does by pinning
  `trunk-<buildid> → grapheneos` for that family.

De-conflating (i) and (ii) is the core deliverable. They must never be reported
as the same thing.

---

## 2. The resolution method (what ships)

Every one of the 13 `device.mk` files now ends with a validated-resolution
block. It **never overrides** `TARGET_KERNEL_DIR` (the upstream assignment is
left byte-identical above it); it only *classifies* the outcome:

```make
# (flag-driven devices, e.g. akita)
ifeq ($(strip $(RELEASE_KERNEL_AKITA_DIR)),)
$(error T-PORT-KERNEL-MATRIX: UNRESOLVED. RELEASE_KERNEL_AKITA_DIR has no value ...)
endif
ifneq ($(wildcard $(TARGET_KERNEL_DIR)),)
ifneq ($(wildcard $(TARGET_KERNEL_DIR)/vendor_kernel_boot.modules.load),)
GUARDTALK_KERNEL_RESOLUTION := OK
else
$(error T-PORT-KERNEL-MATRIX: STUB. 'akita' resolved TARGET_KERNEL_DIR='$(TARGET_KERNEL_DIR)' but vendor_kernel_boot.modules.load is missing or empty there. ...)
endif
else
GUARDTALK_KERNEL_RESOLUTION := ABSENT_DIR
ifneq ($(GUARDTALK_KERNEL_RESOLUTION_QUIET),true)
$(warning T-PORT-KERNEL-MATRIX: ABSENT_DIR. 'akita' resolved TARGET_KERNEL_DIR='$(TARGET_KERNEL_DIR)' which does not exist in this tree. LAYER prerequisite, NOT a NO-GO. ...)
endif
endif
```

The literal-path devices carry the same three-way classification but their
UNRESOLVED guard tests `TARGET_KERNEL_DIR` directly (there is no flag to name):

```make
ifeq ($(strip $(TARGET_KERNEL_DIR)),)
$(error T-PORT-KERNEL-MATRIX: UNRESOLVED. TARGET_KERNEL_DIR is empty for 'stallion'. ...)
endif
```

Exported observable: **`GUARDTALK_KERNEL_RESOLUTION` = `OK` | `ABSENT_DIR`**.
`ABSENT_DIR` warnings can be silenced for a whole build with
`GUARDTALK_KERNEL_RESOLUTION_QUIET := true` — the hard errors are not
suppressible.

| Outcome | Meaning | Action |
|---|---|---|
| **UNRESOLVED** | `RELEASE_KERNEL_<DEV>_DIR` empty (or literal `TARGET_KERNEL_DIR` empty) | **NO-GO.** Hard `$(error)` naming the exact variable. Fix upstream `build/release/flag_values/<release_config>/RELEASE_KERNEL_<DEV>_DIR.textproto` (read-only for us) or drop that device from the matrix. |
| **ABSENT_DIR** | flag defined, resolved dir missing here | **LAYER prerequisite, NOT a NO-GO.** Loud `$(warning)` + `GUARDTALK_KERNEL_RESOLUTION=ABSENT_DIR`. Apply the LAYER recipe in §4. |
| **STUB** | dir exists, `vendor_kernel_boot.modules.load` absent/empty | Hard `$(error)`. A partly-downloaded prebuilt tree must never build. |
| **OK** | dir exists and carries a non-empty `vendor_kernel_boot.modules.load` | Build may proceed. |

This layer is **complementary, not redundant**, with the upstream check at
`vendor/adevtool/config/mk/google_devices/common/BoardConfig-common-gs201-plus.mk`
(lines ~29-32): that check runs later, only looks at the file, and cannot tell
(i) from (ii). Ours runs at device-config time, names the variable, and
separates the two.

---

## 3. Published matrix

`cur` is the **production / FLASH channel** (`vendor/guardtalk/scripts/sign-build.sh:188`).
`trunk_staging` is the development channel. Both were resolved from the
`*.textproto` values actually present in this worktree (not from memory).

### 3a. Flag-driven devices (8)

| Device | SoC | Kernel family | Variable | `cur` → resolved `TARGET_KERNEL_DIR` | exists | `trunk_staging` → resolved | resolution |
|---|---|---|---|---|---|---|---|
| `shiba` | zuma | `shusky-kernels/6.1` | `RELEASE_KERNEL_SHIBA_DIR` | `device/google/shusky-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/trunk-14096387` | ⚠️ **ABSENT_DIR** — LAYER prerequisite (§4) |
| `husky` | zuma | `shusky-kernels/6.1` | `RELEASE_KERNEL_HUSKY_DIR` | `device/google/shusky-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/trunk-14096387` | ⚠️ **ABSENT_DIR** — LAYER prerequisite (§4) |
| `akita` | zuma | `akita-kernels/6.1` | `RELEASE_KERNEL_AKITA_DIR` | `device/google/akita-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/grapheneos` | ✅ directly (no symlink) |
| `tokay` | zumapro | `caimito-kernels/6.1` | `RELEASE_KERNEL_TOKAY_DIR` | `device/google/caimito-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/grapheneos` | ✅ directly (no symlink) |
| `caiman` | zumapro | `caimito-kernels/6.1` | `RELEASE_KERNEL_CAIMAN_DIR` | `device/google/caimito-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/trunk-14096387` | ✅ via pre-existing symlink |
| `komodo` | zumapro | `caimito-kernels/6.1` | `RELEASE_KERNEL_KOMODO_DIR` | `device/google/caimito-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/trunk-14096387` | ✅ via pre-existing symlink |
| `comet` | zumapro | `comet-kernels/6.1` | `RELEASE_KERNEL_COMET_DIR` | `device/google/comet-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/trunk-14096387` | ⚠️ **ABSENT_DIR** — LAYER prerequisite (§4) |
| `tegu` | zumapro | `tegu-kernels/6.1` | `RELEASE_KERNEL_TEGU_DIR` | `device/google/tegu-kernels/6.1/grapheneos` | ✅ real dir | `…/6.1/trunk-14096387` | ⚠️ **ABSENT_DIR** — LAYER prerequisite (§4) |

**`cur` result: 13/13 in-scope devices resolve, the 8 above all on real
directories (`grapheneos`), with no symlink anywhere on the path.** This is the
channel that matters for FLASH and it needs no LAYER work at all.

**`trunk_staging` result:** 9/13 resolve directly; the 4 in the table marked
`ABSENT_DIR` (`shiba`, `husky`, `comet`, `tegu`) are the **LAYER prerequisite**.
None of the 13 is `UNRESOLVED` on this channel — every one of them has a defined
variable. That is the distinction this card exists to preserve.

### 3b. Literal-path devices (5)

| Device | SoC | Literal `TARGET_KERNEL_DIR` | exists | `RELEASE_KERNEL_<DEV>_DIR` |
|---|---|---|---|---|
| `stallion` | zumapro | `device/google/stallion-kernels/6.1/grapheneos` | ✅ | **absent in ALL 9 release configs** — literal by design |
| `frankel` | laguna | `device/google/laguna-kernels/6.6/grapheneos/muzel` | ✅ | exists in `bp4a`, `trunk_staging` — **UNUSED** by `device.mk` |
| `blazer` | laguna | `device/google/laguna-kernels/6.6/grapheneos/muzel` | ✅ | exists in `bp4a`, `trunk_staging` — **UNUSED** |
| `mustang` | laguna | `device/google/laguna-kernels/6.6/grapheneos/muzel` | ✅ | exists in `bp4a`, `trunk_staging` — **UNUSED** |
| `rango` | laguna | `device/google/laguna-kernels/6.6/grapheneos/rango` | ✅ | exists in `bp4a`, `trunk_staging` — **UNUSED** |

`stallion` is the only device in the matrix with **no `RELEASE_KERNEL_STALLION_DIR`
in any channel**, and that is deliberate, not an oversight: its `TARGET_KERNEL_DIR`
is a literal. `rango` is the only device whose literal path has a per-device
sub-directory (`grapheneos/rango` rather than `grapheneos/muzel`); it is
literal-path by design even though the `RELEASE_KERNEL_RANGO_DIR` flag does
exist.

The flag existence per release config, for the record:

| Device | `RELEASE_KERNEL_<DEV>_DIR` present in |
|---|---|
| `shiba` `husky` `akita` `tokay` `caiman` `komodo` `comet` | `ap3a` `ap4a` `bp1a` `bp2a` `bp3a` `bp4a` `cur` `trunk_staging` (8) |
| `tegu` | `bp3a` `bp4a` `cur` `trunk_staging` (4) |
| `frankel` `blazer` `mustang` `rango` | `bp4a` `trunk_staging` (2) — **unused** |
| `stallion` | — (none) |
| *Gen 6/7 devices* | `ap2a` … `bp2a` — **out of scope** |

Consequence, intentionally loud: `ap2a` carries **no** Gen 8/9/10 kernel flag,
so a Gen 8/9/10 flag-driven device lunched against `ap2a` now stops with
`UNRESOLVED` naming the exact variable. That config × device combination is not
supported by that release config; previously it silently produced an empty
`TARGET_KERNEL_DIR`. This is the documented behavioural diff of this card.

---

## 4. LAYER recipe — satisfying an **ABSENT_DIR** (NOT a NO-GO)

> **This card documents the remedy; it does not apply it.** Provisioning is a
> LAYER act. The four affected paths are deliberately left unpinned so that the
> `ABSENT_DIR` classification stays observable and the preflight's 4-absence
> invariant (`verify_port_matrix_preflight_static.sh`, vectorA) stays true.
> Applying the pin is a one-line, fully reversible LAYER step.

When the resolver reports `ABSENT_DIR`, provision the missing prebuilt tree with
a family-level pin. The target is *always* the same single-component relative
symlink:

```sh
cd device/google
ln -s grapheneos <family>-kernels/<ver>/trunk-<buildid>
```

For today's four: `shusky-kernels/6.1/trunk-14096387` (`shiba`, `husky`),
`comet-kernels/6.1/trunk-14096387` (`comet`), `tegu-kernels/6.1/trunk-14096387`
(`tegu`) — all `→ grapheneos`.

Rules:

1. **Symlink only.** Never invent or copy kernel blobs; `device/google/*-kernels/`
   is prebuilt content owned by another layer.
2. **Relative target, single component** (`grapheneos`) — keeps the pin valid
   across worktrees and `.repo` checkouts.
3. **The pin aliases the `cur` kernel.** `trunk-<buildid> → grapheneos` means a
   `trunk_staging` build compiles the kernel modules of the `grapheneos` (cur)
   tree, *not* a real trunk build. That is the in-force, program-approved
   precedent. Re-point or remove the symlink the moment a genuine
   `trunk-<buildid>` prebuilt lands.
4. **Reversible** (Law 11): `rm device/google/<family>-kernels/<ver>/trunk-<buildid>`
   restores the prior state exactly — nothing else is touched, and the resolver
   goes back to reporting `ABSENT_DIR` loudly.
5. **In-scope families only.** Do **not** pin `bluejay`, `raviole`, `pantah`,
   `felix`, `lynx`, `tangorpro` — Gen 6/7, out of scope (see §7).
6. `build/release/flag_values/` is **upstream and read-only** for this program.
   An `ABSENT_DIR` is never fixed by editing a `*.textproto`.

State after this card — **unchanged from the pre-card state** (nothing pinned,
nothing moved):

| Symlink | Covers | Provenance |
|---|---|---|
| `device/google/akita-kernels/6.1/trunk-14096387 → grapheneos` | (unused by trunk_staging; `akita` resolves directly) | pre-existing |
| `device/google/caimito-kernels/6.1/trunk-14096387 → grapheneos` | `caiman`, `komodo` | pre-existing |
| `device/google/laguna-kernels/6.6/trunk-14072179 → grapheneos` | (unused; laguna devices are literal-path) | pre-existing |

Classification of `trunk_staging`, as of this card: **9 resolve directly, 4 are
`ABSENT_DIR`** (`shiba`, `husky`, `comet`, `tegu`), **0 are `UNRESOLVED`**. The
`caiman`/`komodo` cases are covered by the pre-existing `caimito` pin; applying
the §4 recipe to the remaining four would take `trunk_staging` to 13/13 without
touching a single file.

---

## 5. Completeness — proving a tree is not a stub

`vendor_kernel_boot.modules.load` is the canary used by both the resolver's
`STUB` mode and the upstream `BoardConfig-common-gs201-plus.mk` check. The QA
script additionally asserts the full manifest set per resolved tree:

| Resolved tree | `vendor_kernel_boot.modules.load` | `vendor_dlkm.modules.load` | `system_dlkm.modules.load` | `*.ko` on disk |
|---|---|---|---|---|
| `shusky-kernels/6.1/grapheneos` | 209 | 62 | 57 | 327 |
| `akita-kernels/6.1/grapheneos` | 211 | 56 | 57 | 323 |
| `caimito-kernels/6.1/grapheneos` | 211 | 65 | 57 | 337 |
| `comet-kernels/6.1/grapheneos` | 215 | 65 | 57 | 336 |
| `tegu-kernels/6.1/grapheneos` | 214 | 55 | 57 | 325 |
| `stallion-kernels/6.1/grapheneos` | 213 | 57 | 57 | 326 |
| `laguna-kernels/6.6/grapheneos/muzel` | 203 | 113 | 74 | 401 |
| `laguna-kernels/6.6/grapheneos/rango` | 195 | 110 | 74 | 397 |

All eight trees are present, non-empty, and carry `vendor_kernel_boot.modules.load`
plus the `vendor_dlkm`/`system_dlkm` manifests. **None is a stub.**

> **HOLD (Law 7 — report, do not assert):** the gate note anticipated
> **338–473 entries** for `vendor_kernel_boot.modules.load`. In this worktree
> that field measures **195–215** per tree (323–401 `*.ko`, 324–390 total load
> entries). The gate figure is **not reproducible** for that field here, and it
> plausibly described the full upstream trunk-kernel trees rather than the
> `grapheneos` (cur) trees these devices actually resolve to. Recorded as a HOLD
> rather than silently accepting either number.

---

## 6. `KOMODO_PORT_PREFLIGHT.md` lunch-FAIL re-check

The preflight recorded (line ~95, and again at ~203):

> `lunch komodo-trunk_staging-userdebug` | **FAIL** | Exact missing path:
> `device/google/caimito-kernels/6.1/trunk-14096387/vendor_kernel_boot.modules.load`
> (`RELEASE_KERNEL_KOMODO_DIR` for `trunk_staging`). Make error:
> `…/BoardConfig-common-gs201-plus.mk:32: error: vendor_kernel_boot.modules.load
> not found or empty.`

Re-check against the new method:

| Check | Result |
|---|---|
| `test -d device/google/caimito-kernels/6.1/trunk-14096387` | **PASS** — resolves via `→ grapheneos` |
| `test -f …/trunk-14096387/vendor_kernel_boot.modules.load` | **PASS** — 211 entries |
| `RELEASE_KERNEL_KOMODO_DIR` (`trunk_staging`) defined? | **PASS** — `device/google/caimito-kernels/6.1/trunk-14096387` |
| Resolver classification for `komodo` / `trunk_staging` | **OK** (not `ABSENT_DIR`, not `STUB`) |

The preflight's exact failure path is therefore **no longer reproducible**. The
preflight document is **left unmodified** — it is the historical record of a
real failure, and rewriting history is not a fix.

> **HOLD:** the full `lunch komodo-trunk_staging-userdebug` was **not** re-run.
> A full `lunch`/`dumpvars` is heavy and the Operator's `download` was in flight
> into `vendor/adevtool/dl/`. What was verified is the exact path and variable
> named in the failure record, which is the whole content of the failure.
> **No lunch PASS is claimed.**

---

## 7. Add-a-device recipe

To add a Gen 8/9/10 Pixel device to the matrix:

1. **Determine the kernel family.** The family dir is `device/google/<family>-kernels/`;
   siblings share one tree (`shusky` serves `shiba`+`husky`; `caimito` serves
   `tokay`+`caiman`+`komodo`; `laguna` serves `frankel`+`blazer`+`mustang`+`rango`).
   If a tree for the new device does not exist, that is a **LAYER prerequisite**
   — stop and escalate; do **not** invent blobs.
2. **Decide flag-driven vs literal.** Check the release configs:
   `ls build/release/flag_values/*/RELEASE_KERNEL_<DEV>_DIR.textproto`.
   * flag present in the channels you need → **flag-driven**:
     `TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_<DEV>_DIR)`
   * no flag in any channel → **literal-path**, like `stallion`:
     `TARGET_KERNEL_DIR := device/google/<family>-kernels/<ver>/grapheneos[/<variant>]`
3. **Append the validated-resolution block** to
   `vendor/adevtool/config/mk/google_devices/device/<dev>/device.mk`, using the
   flag-driven or literal form from §2 verbatim (only the device name and the
   variable change). Leave the upstream `TARGET_KERNEL_DIR` assignment
   byte-identical; the block must only *classify*, never *override*.
4. **Resolve both channels** and record the table row:
   for each channel, read the `string_value` from the `*.textproto` (or the
   literal), then `test -d` it and `test -s` its
   `vendor_kernel_boot.modules.load`.
   * absent dir → apply the §4 LAYER recipe (family pin `trunk-<buildid> → grapheneos`)
   * variable with no value in **any** channel → that device is **NO-GO**; name
     the exact variable. Do not paper over it with a symlink.
5. **Register in the excision matrix too** if the device has an excision variant
   — see `EXCISION_MATRIX.md`; the SoC/kernel-family profile is keyed there.
6. **Prove it, don't assert it.** Extend and run:
   ```sh
   bash vendor/guardtalk/docs/qa/verify_port_kernel_matrix_static.sh
   ```
   Add the device to `DEVICES`/`FLAG_DEVICES`/`LITERAL_DEVICES`, add its engine
   name to the expected `cur` and `trunk_staging` sets, and add its
   `vendor_kernel_boot.modules.load` tree to case 6. Zero regression on
   `tokay`/`akita`/`komodo`/`rango` and their `*-latest` symlinks is mandatory.

---

## 8. Out of scope — Gen 6 (`gs101`) / Gen 7 (`gs201`)

`oriole`, `raven` (`raviole-kernels`), `bluejay` (`bluejay-kernels`), `cheetah`,
`panther` (`pantah-kernels`), `felix` (`felix-kernels`), `lynx` (`lynx-kernels`),
`tangorpro` (`tangorpro-kernels`) are **out of scope and forbidden** for this
program. They are not in the 13-device matrix, their `device.mk` files are not
touched, and **no LAYER symlink is created for them**. They currently show
`DIR_MISSING` under `trunk_staging` (and `ap2a` carries their flags) — that is
expected, unrelated to this card, and must not be "fixed" here. If a future card
brings them in scope, they follow §7 from scratch.

---

## 9. Verification

```sh
bash vendor/guardtalk/docs/qa/verify_port_kernel_matrix_static.sh
```

Covers: block presence in all 13 `device.mk` (and the exact variable named in
each `UNRESOLVED` error); `cur` 13/13 with no symlink component, each with a
non-empty `vendor_kernel_boot.modules.load`; `trunk_staging` classification —
`ABSENT_DIR` set exactly `{shiba,husky,comet,tegu}`, resolved set exactly the
other 9, **0 `UNRESOLVED`**, and the four LAYER remedy paths named in §4 with the
four remaining deliberately unpinned; a **synthetic three-mode harness driven by
the real shipped block** extracted from `akita/device.mk` — `UNRESOLVED` → hard
error naming the variable, `ABSENT_DIR` → loud warning +
`GUARDTALK_KERNEL_RESOLUTION=ABSENT_DIR` + exit 0, `STUB` → hard error; per-tree
manifest completeness over the 8 in-scope trees only; the komodo lunch path;
zero regression on the `*-latest` release symlinks and the three pre-existing
kernel pins.

Reversibility: every change is a new file or an appended classification block —
no kernel blob, no `build/release/flag_values/` edit, and **no new symlink**.
Removing the appended block restores each `device.mk` exactly. `git status`
provenance cannot be produced (this worktree is not a git repository) — state is
established by content rematch.

*Generated by the AEGIS Backend Engineer (Panel 2) for `T-PORT-KERNEL-MATRIX`.*
