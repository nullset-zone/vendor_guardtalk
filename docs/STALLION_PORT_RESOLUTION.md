# STALLION_PORT_RESOLUTION.md — how `stallion`'s kernel prebuilts resolve (and the fail-closed guard)

> **Card:** `T-PORT-STALLION-RESOLUTION-DOC` (P1, `E-24`) — GuardTalkOS Gen 8/9/10 port program
> (`DEC-PORT-GEN8910-001` / `DEC-PORT-GEN8910-002`).
> **Depends on:** `A-PORT-WAVE-A` `F-002` + `E-24`; complements `KERNEL_MATRIX.md` (`T-PORT-KERNEL-MATRIX`,
> which owns the 13-device resolution matrix) and `A-PORT-WAVE-A_AUDIT.md` §4 (the `HOLD` ruling).
> **QA pair:** `Q-PORT-STALLION-RESOLUTION-DOC`.
> **This document is documentation-only.** It does **not** edit product source, the build harness, or the
> shipped stamp README. Where the card's acceptance asks for a product change, §5 and §6 state exactly what
> is required and who owns it (Law 7 — report, do not silently expand scope).
> **Evidence:** `.agent-comm/evidence/T-PORT-STALLION-RESOLUTION-DOC/` (repro scripts + raw output).
> **Re-verified:** 2026-09-26 (all facts below re-checked against this worktree; hashes captured in the
> evidence index in §8).

---

## 1. Verdict

`stallion` is a **literal-path** device. Its kernel prebuilts are resolved by a hard-coded, immediate
assignment to the **real** directory `device/google/stallion-kernels/6.1/grapheneos` — **no release flag,
no `trunk-*` symlink, no fallback**. That mechanism is proven below from the **built/stamped artifact**, not
merely from reading the makefile. A future conversion of that assignment to a flag-driven/fallback form
would silently swap the prebuilts; §5 provides a **fail-closed** reference guard that rejects that change,
with a non-vacuous synthetic negative control.

| Question | Answer | Evidence |
|---|---|---|
| Which line resolves the kernel dir? | `TARGET_KERNEL_DIR := device/google/stallion-kernels/6.1/grapheneos` — `vendor/adevtool/config/mk/google_devices/device/stallion/device.mk:8` | `06-built-artifact-proof.out` §A |
| Any `RELEASE_KERNEL_STALLION_DIR` in any channel? | **No — 0 files** (11 channel dirs) | `01-flag-values.txt`, `06…out` §B |
| Any `*STALLION*` release flag at all? | **No — 0 files** | `01-flag-values.txt` |
| Is the resolved dir a symlink? | **No** — every path component is a real directory | `06…out` §C |
| Does the built artifact actually use it? | **Yes** — 213/213 built ramdisk `.ko` byte-identical; `vendor_dlkm.img` module byte-identical; `init.insmod.stallion.cfg` identical | `06…out` §D–H |
| Is there a fail-closed guard against a fallback swap today? | **No** — the shipped classification block checks existence, not identity (§5.1). A reference guard + proof is provided here. | `05-guard-synthetic-tests.out` |
| `HOLD-PORT-STALLION` context | Registered: `TASK_QUEUE.md:6936` — `BUILD_ID=BD6A.251031.001.A4` vs `BP4A.*` (16-QPR1 lag); no kernel-dir flag in any channel | §6 |

---

## 2. Claim ledger — every card/`E-24` claim re-verified (Law 7)

Each claim is labelled **VERIFIED**, **REFINED** (true only after a correction), or **UNVERIFIED** (not
substantiated as stated). Evidence paths are under
`.agent-comm/evidence/T-PORT-STALLION-RESOLUTION-DOC/`.

| # | Claim (source) | Verdict | What re-verification found |
|---|----|---|---|
| C1 | "`stallion` builds with ZERO release flags in ANY channel — `find build/release/flag_values -name '*STALLION*'` → 0 files across all 11 channels" (`E-24`; `TASK_QUEUE.md:7783`) | **VERIFIED** | `find build/release/flag_values -iname '*STALLION*'` → **0**. `build/release/flag_values/` holds exactly **11 channel dirs** (`ap2a ap3a ap4a bp1a bp2a bp3a bp4a cur eng trunk_staging userdebug`) plus an `OWNERS` file (not a channel). `RELEASE_KERNEL_STALLION_DIR.textproto` count = **0** (`01-flag-values.txt`). |
| C2 | "kernel resolves via the plain `grapheneos` real directory" (`E-24`) | **VERIFIED** | `device.mk:8` literal `:=`; `device/google/stallion-kernels/6.1/grapheneos` is a real dir, no symlink on any path component (`06…out` §A, §C). |
| C3 | "`stallion` is the **only** one of the 13 with **no `trunk-14096387` symlink**" (`E-24`) | **UNVERIFIED as stated → REFINED** | Measured across the six 6.1 families + `laguna` 6.6: `trunk-14096387` is indeed absent under `stallion-kernels/6.1`, **but it is also absent under `laguna-kernels/6.6`** (the family serving `frankel`/`blazer`/`mustang`/`rango`, which pin `trunk-14072179 → grapheneos` instead). So `stallion` is **not** the only one of the 13 lacking `trunk-14096387`. The substantiated form: **`stallion` is the only in-scope kernel family with no `trunk-*` symlink of any name** (`02-trunk-symlinks.txt`). |
| C4 | "a **FOURTH, undocumented** mechanism, distinct from (1) `cur` alias, (2) operator `trunk-<n>` symlink, (3) channel flags" (`E-24`) | **REFINED** | The *assignment style* claim is right: `stallion` is literal-path (`:=`) and consults no flag/symlink — a fourth resolution path. But "undocumented" is inaccurate: the literal style and `stallion`'s literal path were already published in `KERNEL_MATRIX.md` §1/§3b (file mtime 2026-09-21, pre-dating `E-24` at 2026-09-24T20:05), and the `device.mk:3-7` comment says so. What was silent was the **shipped stamp README**, not the internal doc. |
| C5 | "the stamp README is silent on both the `HOLD` **and** the mechanism" (`E-24`; `A-PORT-WAVE-A` `F-002`) | **VERIFIED** | `releases/desktop-flash/stallion-20260923-100618/README-FLASH-DESKTOP.md` states the `BD6A.251031.001.A4` fingerprint and the honesty flags, but says nothing about `HOLD-PORT-STALLION`, the 16-QPR1 baseline, or the kernel-dir resolution (§6.2). |
| C6 | "`stallion-latest → stallion-20260923-100618` exists and passed bundle/SHA256SUMS checks" (`E-24`) | **VERIFIED** (corroborated) | `stallion-latest → stallion-20260923-100618`; `A-PORT-WAVE-A_AUDIT.md` §5 records `sha256sum -c SHA256SUMS` exit 0, 20/20, and stamp→`out/` byte identity. This doc independently re-confirmed stamp→`out/` byte identity for `vendor_kernel_boot.img`, `vendor_dlkm.img`, `boot.img` (`06…out` §H). |
| C7 | "no `RELEASE_KERNEL_STALLION_DIR.textproto` in any channel" (`A-PORT-WAVE-A`; `HOLD` register `TASK_QUEUE.md:6936`) | **VERIFIED** | `01-flag-values.txt`. |
| C8 | `HOLD-PORT-STALLION`: `BUILD_ID=BD6A.251031.001.A4` vs `BP4A.*`, different QPR1 platform baseline | **VERIFIED** | `TASK_QUEUE.md:6936` (HOLD register); `out/target/product/{caiman,comet}/build_fingerprint-*.txt` = `BP4A.260205.002`, `tegu` = `BP4A.260205.001`, `stallion` = `BD6A.251031.001.A4`. |
| C9 | The five literal-path devices are `stallion frankel blazer mustang rango` (`KERNEL_MATRIX.md` §3b) | **VERIFIED** | All 13 `TARGET_KERNEL_DIR` assignments enumerated in `04-resolution-wiring.txt`; exactly 5 use `:=`. |

> **No claim here is asserted from memory.** Anything not directly reproduced in this worktree is called out
> as such (see §7). `E-24` claims C3 and C4 are corrected above rather than repeated.

---

## 3. The resolution mechanism, proven from the built artifact

### 3.1 Source wiring (what sets the value)

```make
# vendor/adevtool/config/mk/google_devices/device/stallion/device.mk
# ...
# There is NO RELEASE_KERNEL_STALLION_DIR flag in ANY release config (verified
# across build/release/flag_values/*) ...
TARGET_KERNEL_DIR := device/google/stallion-kernels/6.1/grapheneos
```

`TARGET_KERNEL_DIR` is then consumed by the shared adevtool makefiles:

| Consumer | File:line | Use |
|---|---|---|
| `LOCAL_KERNEL := $(TARGET_KERNEL_DIR)/Image.lz4` | `vendor/adevtool/config/mk/google_devices/common/device-common.mk:13` | kernel image in the boot chain |
| `$(call find-copy-subdir-files,init.insmod.*.cfg,$(TARGET_KERNEL_DIR),…)` | `…/device-common.mk:27` | `init.insmod.<dev>.cfg` → `vendor_dlkm/etc` |
| `BOARD_PREBUILT_DTBIMAGE_DIR := $(TARGET_KERNEL_DIR)` | `…/common/BoardConfig-common.mk:24` | DTB image dir |
| `KERNEL_MODULE_DIR := $(TARGET_KERNEL_DIR)` | `…/common/BoardConfig-common.mk:41` | kernel module dir |

### 3.2 Built-artifact proof (not just a makefile read)

Reproduce with `bash .agent-comm/evidence/T-PORT-STALLION-RESOLUTION-DOC/prove-mechanism.sh`; raw output in
`06-built-artifact-proof.out`.

| Probe | Result |
|---|---|
| **(A)** resolved assignment | `device.mk:8 → TARGET_KERNEL_DIR := device/google/stallion-kernels/6.1/grapheneos` |
| **(B)** flag existence | `RELEASE_KERNEL_STALLION_DIR.textproto` = **0**; `*STALLION*` files = **0** |
| **(C)** path type | every component of the canonical path is a real directory; **no symlink** |
| **(D)** built ramdisk `modules.load` vs source manifest (basenames) | built = **213** entries; source manifest = **210**; the **only** delta is `{cpif.ko, cpif_page.ko, shm_ipc.ko}` **present in the build, absent from the source manifest** — the source manifest was edited **2026-09-25T17:15:25Z** (post-build, by the `T-EXCISE-MODEM-KERNEL` wave) to drop exactly those 3 |
| **(E)** built ramdisk `*.ko` byte-identity | **213/213 match**, 0 diff, 0 not-in-src |
| **(F)** `vendor_dlkm.img` module byte-identity (`debugfs`) | `bcmdhd4383.ko` sha256 `8cbbbb5c8dab1166…` in **both** the built `vendor_dlkm.img` and the literal dir |
| **(G)** `init.insmod.stallion.cfg` | sha256 `f40b37de5a9a812b…` **identical** in the literal dir, `out/…/vendor_dlkm/etc/`, and the stamp |
| **(H)** stamp ↔ build output | `vendor_kernel_boot.img`, `vendor_dlkm.img`, `boot.img` byte-identical (`791cff3c…`, `329f6937…`, `2e748170…`) |

Probe **(D)** is the sharpest provenance link: the *build-time* ramdisk manifest equals the literal dir's
current manifest **plus exactly the three modem modules the Sep-25 excision later removed**. Taken together
with the byte-identity probes (E)–(H) against the literal dir, this ties the built artifact to
`device/google/stallion-kernels/6.1/grapheneos`.

> **Honesty caveat (Law 7):** the built artifact (`out/`, stamp `2026-09-23`) **predates** the
> `2026-09-25` source-manifest edit. The stamp's ramdisk therefore still contains `cpif/cpif_page/shm_ipc`;
> that is the pre-excision state, not a current-source discrepancy. No rebuild/re-stamp was performed by
> this card (`RESTAMP_PERFORMED=false`).

---

## 4. The `trunk-*` symlink picture (correcting the `E-24` wording)

Reproduce: `02-trunk-symlinks.txt`.

| In-scope kernel family | Devices served | `trunk-14096387`? | any other `trunk-*`? |
|---|---|---|---|
| `shusky-kernels/6.1` | `shiba`, `husky` | yes → `grapheneos` | — |
| `akita-kernels/6.1` | `akita` | yes → `grapheneos` | — |
| `caimito-kernels/6.1` | `tokay`, `caiman`, `komodo` | yes → `grapheneos` | — |
| `comet-kernels/6.1` | `comet` | yes → `grapheneos` | — |
| `tegu-kernels/6.1` | `tegu` | yes → `grapheneos` | — |
| **`stallion-kernels/6.1`** | **`stallion`** | **no** | **none** |
| `laguna-kernels/6.6` | `frankel`, `blazer`, `mustang`, `rango` | **no** | `trunk-14072179` → `grapheneos` |

**Corrected statement:** `stallion` is the **only in-scope kernel family with no `trunk-*` symlink at all**.
It is **not** the only device lacking `trunk-14096387` — the four `laguna` devices also lack it (they pin a
different build id). This does not change the security/robustness conclusion: `stallion`'s resolution does
not transit any symlink, which is *stronger* than the `trunk-<n> → grapheneos` aliases used elsewhere.

---

## 5. Fail-closed guard (design + reference implementation + negative control)

### 5.1 The gap this closes

The shipped `T-PORT-KERNEL-MATRIX` block in `stallion/device.mk` classifies the **resolved** value as
`UNRESOLVED` / `ABSENT_DIR` / `STUB`. It does **not** pin *identity*. Likewise the shipped harness
`vendor/guardtalk/docs/qa/verify_port_kernel_matrix_static.sh` asserts the literal assignment exists
(case 1) and that whatever it resolves to exists with a non-empty
`vendor_kernel_boot.modules.load` (case 2) — but a future edit to
`TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_STALLION_DIR)` with any valid value would resolve a **different real
tree** and still pass both checks (cases 1–2). That is exactly
`E-24`'s latent risk: a future "fix" of the missing flag silently swaps the prebuilts.

*(The harness-gap statement is from reading the shipped script; the harness was not modified or executed
against a mutant under this documentation-only card. The guard's own make-level control in §5.4 does
execute the swap semantics.)*

### 5.2 Reference guard (in the evidence dir, not wired into product/harness)

`stallion_kernel_dir_guard.sh` fails closed (exit 1) unless **all** hold:

1. exactly **one** `TARGET_KERNEL_DIR` assignment, an immediate `:=` (rejects `?=` and `+=`);
2. the RHS is the exact literal `device/google/stallion-kernels/6.1/grapheneos` and contains **no** `$(…)`
   variable indirection;
3. every path component is an existing **real** directory (rejects a `trunk-* → grapheneos` pin);
4. `vendor_kernel_boot.modules.load` exists and is non-empty (not a stub).

### 5.3 Synthetic negative control — the guard is non-vacuous

`run-guard-synthetic-tests.sh` (raw output `05-guard-synthetic-tests.out`):

| Fixture | Guard exit | Expected |
|---|---|---|
| shipped `device.mk` | **0** | 0 |
| `TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_STALLION_DIR)` (a future "flag fix") | **1** (`OPERATOR`) | non-zero |
| `TARGET_KERNEL_DIR := device/google/comet-kernels/6.1/grapheneos` (a real tree swap) | **1** (`DRIFT`) | non-zero |
| `TARGET_KERNEL_DIR := $(GT_STALLION_KERNEL_DIR)` (indirection) | **1** (`INDIRECTION`) | non-zero |
| two `TARGET_KERNEL_DIR` assignments | **1** (`COUNT`) | non-zero |

Result: `SELFTEST-PASS: guard non-vacuous; fails closed on every synthetic fallback/swap`.

### 5.4 The hazard is real (make-level proof)

The same control resolves the fallback form with real `make`:

```make
TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_STALLION_DIR)
RELEASE_KERNEL_STALLION_DIR := device/google/comet-kernels/6.1/grapheneos
# effective TARGET_KERNEL_DIR = device/google/comet-kernels/6.1/grapheneos
```

i.e. a fallback flag would silently point `stallion`'s kernel at `comet`'s tree. The guard above blocks it.

### 5.5 Recommended production wiring (OUT OF SCOPE for this documentation-only card)

One or both, owned by a follow-up code card (product source + harness owners, not this doc):

- Append to `vendor/adevtool/config/mk/google_devices/device/stallion/device.mk` a hard
  `$(if $(filter-out device/google/stallion-kernels/6.1/grapheneos,$(TARGET_KERNEL_DIR)),$(error …))`
  so a fallback/flag-driven value is a **build-time hard error**, not a silent swap.
- Add the static assertions (1)–(4) of §5.2 to `verify_port_kernel_matrix_static.sh` as a new case, with
  the synthetic negative control kept non-vacuous.

Neither was applied here: editing product source or the harness is outside this card's exclusive
ownership and would require its own gates.

---

## 6. `HOLD-PORT-STALLION` context for the stamp README

### 6.1 Authoritative HOLD record

`TASK_QUEUE.md:6936` (HOLD register):

> `HOLD-PORT-STALLION` | stallion | **No `RELEASE_KERNEL_STALLION_DIR.textproto` in any channel**
> (`ap2a…bp4a, cur, eng, trunk_staging, userdebug`); **`BUILD_ID=BD6A.251031.001.A4`** vs `BP4A.*` →
> different QPR1 platform baseline | Batch A records a precise HOLD if the build fails on kernel prebuilts.
> Never fabricate a stamp; never invent blobs.

Confirmed independently in this worktree: `stallion` fingerprint
`google/stallion/stallion:Baklava/BD6A.251031.001.A4/eng.openst:userdebug/test-keys` vs `caiman`/`comet`
`BP4A.260205.002`, `tegu` `BP4A.260205.001`. The HOLD did not trigger (`device/google/stallion-kernels/6.1/grapheneos`
exists, so the build did not fail on kernel prebuilts) — hence a stamp exists (`A-PORT-WAVE-A_AUDIT.md` §4).

### 6.2 Current stamp README state

`releases/desktop-flash/stallion-20260923-100618/README-FLASH-DESKTOP.md` **already states** the
`BD6A.251031.001.A4` fingerprint, `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false`, `BOOT_VERIFIED=false`, the
`stallion-trunk_staging-userdebug` variant and the `zumapro_stallion` excision variant. It is **silent**
on: `HOLD-PORT-STALLION`; the 16-QPR1 platform lag vs `BP4A.*`; and the literal-path kernel resolution
(no `RELEASE_KERNEL_STALLION_DIR`). This is `A-PORT-WAVE-A` `F-002` (Low) — **honest-as-stated,
under-disclosed**, not a false claim.

### 6.3 Required text (not applied — see ownership)

A README note equivalent to:

> **Kernel resolution / `HOLD-PORT-STALLION`: this device is a literal-path device — `TARGET_KERNEL_DIR :=
> device/google/stallion-kernels/6.1/grapheneos`; there is no `RELEASE_KERNEL_STALLION_DIR` flag in any
> channel and no `trunk-*` symlink. `BUILD_ID=BD6A.251031.001.A4` is a **16-QPR1** platform baseline,
> different from the `BP4A.*` baseline of the other Wave A stamps. Keep `FLASH_READY=false`.**

### 6.4 Ownership note (why this doc does not edit it)

The **shipped `stallion` README is item D-08 of `T-EXCISE-MATRIX-DOC-RESIDUAL`** (`TASK_QUEUE.md:8832`
"D-08 — the shipped `stallion` README"). Editing it is that lane's exclusive scope; this documentation-only
card therefore specifies the text and the source of truth rather than editing a file owned elsewhere.

---

## 7. What is NOT claimed (Law 7)

- **No rebuild, re-stamp, flash, or boot.** `RESTAMP_PERFORMED=false`, `LIVE_FLASH_CLAIMED=false`,
  `BOOT_VERIFIED=false`. The built artifact is the Sep-23 stamp.
- **The production guard is not installed.** §5 provides a reference guard + non-vacuous synthetic control
  only; product source and the shipped harness are unmodified by this card.
- **The shipped README is not edited** (§6.4, owned by `T-EXCISE-MATRIX-DOC-RESIDUAL` D-08).
- **`E-24` C3/C4 are corrected, not repeated**: `stallion` is the only family with **no `trunk-*` symlink**,
  not the only device lacking `trunk-14096387`; the literal mechanism was already documented in
  `KERNEL_MATRIX.md` (only the stamp README was silent).
- **This worktree is not a git repository** at the root; state is established by content rematch, not by
  `git status` provenance.

---

## 8. Evidence index

`.agent-comm/evidence/T-PORT-STALLION-RESOLUTION-DOC/`

| File | Contents |
|---|---|
| `01-flag-values.txt` | 11 channel dirs; `*STALLION*` = 0; per-channel `RELEASE_KERNEL_*_DIR` inventory |
| `02-trunk-symlinks.txt` | all `trunk-*` symlinks in the in-scope families; exact-name `trunk-14096387` check |
| `03-identity-and-cur.txt` | `cur`/`trunk_staging` dir type; the literal assignment; manifest sha256s + line/`.ko` counts; symlink check |
| `04-resolution-wiring.txt` | all 13 `TARGET_KERNEL_DIR` assignments; `RELEASE_KERNEL_STALLION` occurrences; consumer wiring |
| `05-guard-synthetic-tests.out` | reference guard on the shipped literal + 4 synthetic mutants (`SELFTEST-PASS`) |
| `06-built-artifact-proof.out` | probes (A)–(H): assignment, flag absence, no-symlink, manifest delta, 213/213 `.ko`, `vendor_dlkm` module, `init.insmod` cfg, stamp↔`out` |
| `prove-mechanism.sh` | reproducible driver for `06…out` |
| `stallion_kernel_dir_guard.sh` | reference fail-closed guard |
| `run-guard-synthetic-tests.sh` | non-vacuous synthetic control for the guard |
| `README.md` | evidence-dir index |

*Authored by the AEGIS Backend Engineer (Panel 2) for `T-PORT-STALLION-RESOLUTION-DOC`. Documentation-only;
no product source, harness, stamp README, or `TASK_QUEUE.md` edits.*
