# A-PORT-WAVE-A — Independent Deep-Tech Audit (Panel 5)

| Field | Value |
|---|---|
| task_id | `A-PORT-WAVE-A` |
| role | Auditor — Independent Deep Tech (Panel 5), **READ-ONLY** |
| audit_scope | `full` |
| owner_repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id: grapheneos-worktree`) |
| authoritative_task_path | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` |
| program | `AUDIT WAVE DISPATCH` §B3 — cards `A-PORT-MATRIX-R2` / `A-PORT-WAVE-A/B/C` (`DEC-AUDIT-WAVE-RESCOPE`) |
| depends_on (re-scoped per §B2) | `T-PORT-BUILD-BATCH-A` + `Q-PORT-FLASH-CLI-9DEV` ✅ (APPROVE WITH FINDINGS 0C/0H/0M/2L) + `Q-EXCISE-13DEV-MATRIX` ✅ (REVIEW ACCEPTED) |
| status | DISPATCHED → **REVIEW** (this auditor never sets `APPROVED`) |
| **Gate -1** | **IN-PROCESS** — `.aegis/governance/laws/*.yaml` (24) + `.aegis/governance/gates/*.yaml` (11) loaded from disk. `governance_loaded=true`. **No** `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP call. |
| **Gate 5** | **HUMAN SKIP** — no numeric self-critique score is invented. |
| `LIVE_FLASH_CLAIMED` | **false** — no hardware; no USB/adb/fastboot; no device/boot/flash result claimed (DEC-009 HOLD). |
| Timestamp | 2026-09-24T18:05:00+04:00 |
| Write surface | this report + `.agent-comm/evidence/A-PORT-WAVE-A/*` + one `.agent-comm/history/` event + `.agent-comm/signals/review-A-PORT-WAVE-A.json`. **No** product/test/filter/flash/packer/doctrine/queue file edited. `.agent-comm/inbox/TO_ARCHITECT.md` was **NOT** touched. |

---

## 1. Scope and method

**Wave A = `caiman`, `comet`, `tegu`, `stallion`** (all `zumapro`). Per the dispatch packet, this lane audits the
**built and stamped** artifact per device, on the six surfaces the packet names — and **cross-references** the EXCISE
program rather than re-deriving its excision/variant verdicts:

1. Bundle completeness + `SHA256SUMS` validity + expected image set.
2. Stamp identity (`<dev>-latest` → concrete directory; target + mtime).
3. **Resolved variant from the SHIPPED image** (VINTF manifest provenance header and `vendor_dlkm` blocklist header/content).
4. Flash-script coverage (`DEVICE=<dev>` resolves; correct firmware grouping vs `script/generate-release.sh`; `bash -n`).
5. **Non-regression** of the incumbent `*-latest` links (`tokay`/global `latest`, `akita`, `komodo`, `rango`).
6. `stallion` `HOLD-PORT-STALLION` ruling.

**Method / discipline.** Primary artifacts only (`releases/desktop-flash/<stamp>/*` and `out/target/product/<dev>/*`);
read inside opaque `.img`s with `debugfs` on the **shipped** stamp images (never `system_dlkm`/`vendor_dlkm` source
makefiles); independently drove `apply_grapheneos_firmware_cleanup` with a **stubbed `fastboot`** that logs calls and
never touches a device. Author-side suites re-run but not trusted; `verify-on-device.sh` **not** run (needs `adb`).
Cite-only, no re-derivation of the EXCISE excision result.

---

## 2. HEADLINE VERDICT

> ### ✅ **WAVE A BUILT/STAMPED ARTIFACTS ARE INTACT — 4/4 devices PASS the six scope items, with 3 Low + 4 Info.**
> No Critical / High / Medium finding. Bundle integrity, stamp identity, flash-script coverage and incumbent-link
> non-regression all hold for `caiman`, `comet`, `tegu`, `stallion`.
> **`stallion` ruling:** its stamp is **complete, valid and honestly self-labelled** (BD6A fingerprint stated verbatim,
> `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false`, `BOOT_VERIFIED=false`) but **silent** on the `HOLD-PORT-STALLION`
> context (16-QPR1 platform lag; no `RELEASE_KERNEL_STALLION_DIR.textproto` in any channel). **Honest-as-stated,
> under-disclosed → F-002 (Low).** `rango-latest` **not** moved; **no** boot-green claim for any device.

### 2.1 Severity counts

| Severity | Count | IDs |
|---|---|---|
| **CRITICAL** | **0** | — |
| **HIGH** | **0** | — |
| **MEDIUM** | **0** | — |
| **LOW** | **3** | F-001, F-002, F-003 |
| **INFO / observation** | **4** | F-004, F-005, F-006, F-007 |
| **Total** | **7** | |

### 2.2 Per-device table (all six scope items)

| Device | (1) Bundle + `SHA256SUMS` | (2) `-latest` → target (mtime) | (3) Variant resolved from **shipped** image | (4) Flash coverage | (5) Non-regression | (6) HOLD |
|---|---|---|---|---|---|---|
| `caiman` | **PASS** — 20/20 files, `sha256sum -c` **exit 0**; all images present (`super.img`→`super_empty.img`, disclosed) | `caiman-latest` → **`caiman-20260922-090535`** ✅ (claimed value; mtime 2026-09-22 09:06) | `zumapro_caimito` — blocklist token-group `bcmdhd4390`+`syna_touch`+`sec_touch`+`nitrous` = canonical `zumapro_caimito`; VINTF prov. `vendor_manifest_no_radio.xml`. ⚠ header names `tokay` (**F-001**) | **PASS** — `DEVICE=caiman`→`caiman-latest`; UART+FIPS+DPM; `bash -n` 0 | **PASS** | n/a |
| `comet` | **PASS** — 20/20, exit 0 | `comet-latest` → `comet-20260922-160129` (mtime 2026-09-22 16:01) | `zumapro_comet` — `bcmdhd4390`+`goodix_brl_touch`+`syna_touch`+`sec_touch`+`nitrous`; header `zumapro_comet` ✅; VINTF prov. `vendor_manifest_no_radio.xml` | **PASS** — UART+FIPS+DPM; `bash -n` 0 | **PASS** | n/a |
| `tegu` | **PASS** — 20/20, exit 0 | `tegu-latest` → `tegu-20260922-164700` (mtime 2026-09-22 16:47) | `zumapro_tegu` — `bcmdhd4383`+`syna_touch`+`nitrous`; header `zumapro_tegu` ✅; VINTF prov. `vendor_manifest_no_radio.xml` | **PASS** — UART+FIPS+DPM; `bash -n` 0 | **PASS** | n/a |
| `stallion` | **PASS** — 20/20, exit 0 | `stallion-latest` → `stallion-20260923-100618` (mtime 2026-09-23 10:06) | `zumapro_stallion` — `bcmdhd4383`+`focal_touch.ko`+`nitrous`; header `zumapro_stallion` ✅; VINTF prov. `vendor_manifest_no_radio_stallion.xml` ✅ (matches README) | **PASS** — UART+FIPS+DPM; `bash -n` 0 | **PASS** | **HOLD (partial disclosure — F-002)** |

**Per-device verdict (wave scope, not the airgap claim): `caiman` PASS · `comet` PASS · `tegu` PASS · `stallion` PASS-WITH-HOLD-NOTE.**

---

## 3. Findings

### F-001 — Low — Shipped `caiman` `vendor_dlkm` blocklist provenance header mislabels the variant as `tokay`
- **Evidence.** `debugfs -R "cat /lib/modules/modules.blocklist" releases/desktop-flash/caiman-20260922-090535/vendor_dlkm.img` → first line
  `# GuardTalkOS — tokay (caimito-kernels) vendor_dlkm modules blocklist.` (`vendor_dlkm.img` sha256 `833a7a8b446282048c44c931b79e26f05aad4bd5018771c2ce598c295a018b0c`).
  The token content is **correct** for `caiman`'s registry variant `zumapro_caimito`
  (`vendor/guardtalk/feature-excised/excision-variants.mk:87` `GT_DEVICE_VARIANT_caiman := zumapro_caimito`;
  `:106` `GT_VARIANT_zumapro_caimito_BLOCKLIST := vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist`),
  and the shipped file is substantively byte-identical to that source (only blank lines normalized — see F-007).
  The header itself is inherited verbatim from the shared `zumapro_caimito` source file
  (`vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist`, sha256 `53994a7b…`), whose title names `tokay`
  because `tokay`/`caiman`/`komodo` deliberately share it.
- **Impact.** Forensically misleading: an operator reading only the shipped image can conclude `caiman` carries
  `tokay`'s blocklist. No functional effect (content verified correct; EXCISE `A-EXCISE-13DEV-NONREGRESSION` independently
  found `tokay/caiman/komodo → zumapro_caimito` and the caimito token-group distinct/correct). Transparency/auditability
  gap only (Law 1 / Law 19).
- **Recommendation.** Give the shared caimito blocklist a variant-neutral header (`GuardTalkOS — zumapro_caimito …`), or
  add a provenance line naming the consuming device(s). Non-blocking; no rebuild required for correctness.

### F-002 — Low — `stallion` stamp README is silent on `HOLD-PORT-STALLION` (does not overclaim)
- **Evidence.** `releases/desktop-flash/stallion-20260923-100618/README-FLASH-DESKTOP.md` states the variant
  (`stallion-trunk_staging-userdebug`), the fingerprint (`google/stallion/stallion:Baklava/BD6A.251031.001.A4/eng.openst:userdebug/test-keys`),
  `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false`, `BOOT_VERIFIED=false`, the excision variant `zumapro_stallion`,
  and the VINTF excised manifest `vendor_manifest_no_radio_stallion.xml` (all **verified true** against the shipped
  `vendor.img`). It **does not** mention: (a) `BUILD_ID=BD6A.251031.001.A4` being a **different (16-QPR1) platform
  baseline** vs the `BP4A.*` baseline of the other three Wave A stamps; (b) that **no** `RELEASE_KERNEL_STALLION_DIR.textproto`
  exists in **any** channel (`build/release/flag_declarations/`, `build/release/flag_values/{ap2a,ap3a,ap4a,bp1a,bp2a,bp3a,bp4a,cur,trunk_staging}` — verified absent;
  `device/google/stallion-kernels/6.1/grapheneos` present, literal-path resolution).
  **No false statement is made** — the `BD6A.251031.001.A4` value is disclosed verbatim in the fingerprint, so a reader
  who knows the baseline sees it; the known risk context is simply omitted.
- **Impact.** A first-flasher cannot learn from the stamp alone that `stallion` is the flagged platform-lag /
  no-kernel-dir-flag device (`TASK_QUEUE.md:6933` `HOLD-PORT-STALLION`; the `A-PORT-MATRIX-R2` audit's §4 `stallion =
  PARTIALLY DISCLOSED`, QA-W1 open). Documentation completeness (Law 19), not a build defect.
- **Recommendation.** Add the HOLD id + the 16-QPR1 baseline note + the "kernel dir is a literal path (no
  `RELEASE_KERNEL_STALLION_DIR` flag)" line to the `stallion` README template. Keep `FLASH_READY=false`.

### F-003 — Low — Stamp README disclosure is inconsistent across the four Wave A devices
- **Evidence.** `comet-20260922-160129/README-FLASH-DESKTOP.md:7-8` and `tegu-20260922-164700/README-FLASH-DESKTOP.md:7-8`
  ship **empty** metadata fields (`**Fingerprint:** ``` `, `**ro.product.model:** ``` `), whereas `caiman` and `stallion`
  populate them. Separately, only `stallion`'s README names the **excision variant** (`zumapro_stallion`) and the VINTF
  manifest provenance; `caiman`/`comet`/`tegu` do not (their VINTF provenance cites the generic
  `vendor_manifest_no_radio.xml`). The real values are derivable (`out/target/product/<dev>/build_fingerprint-<dev>.txt`,
  e.g. `google/comet/comet:Baklava/BP4A.260205.002/eng.openst:userdebug/test-keys`).
- **Impact.** Inconsistent per-device provenance on the shipped, advertised artifact; weakens artifact-identity
  forensics (Law 1 / Law 19). No functional effect.
- **Recommendation.** Normalize the stamp-README template across `script/`/stamp generation so every device records
  fingerprint, `ro.product.model`, the excision variant and the VINTF manifest provenance.

### F-004 — Info — `super.img` omitted from all four bundles; `super_empty.img` shipped (disclosed + handled)
- **Evidence.** Neither the stamps nor `out/target/product/<dev>/` contain `super.img`; all four ship `super_empty.img`
  (5184 B, sha256 `34cbe5c5…`, identical on all four). Each README states the omission explicitly (e.g.
  `caiman-…/README-FLASH-DESKTOP.md:69` "`super.img` is **omitted** … the flash script lists it as optional and uses
  `super_empty.img`"). `vendor/guardtalk/scripts/flash-from-remote.sh:906-908,919-922` treat `super.img` as optional
  (`warn "optional $f not on server — skipping"`) and `:1379-1388` fall back to `wipe-super super_empty.img` + per-partition
  logical flash when absent.
- **Impact.** None. Documented deviation from a literal reading of the packet's "expected image set"; the flash path is
  correct and is the established akita/komodo pattern. **Not a finding against the artifact.**

### F-005 — Info — `caiman` and `comet` ship byte-identical `bootloader.img` and `radio.img` (explained)
- **Evidence.** `bootloader.img` sha256 `822b1c33…` and `radio.img` sha256 `ca41313e…` are **identical** for
  `caiman-20260922-090535` and `comet-20260922-160129`. `out/target/product/{caiman,comet}/android-info.txt` both
  require `version-bootloader=ripcurrentpro-16.4-14791556` and `version-baseband=g5400c-251201-260127-B-14784805`
  — i.e. the two devices genuinely share the same bootloader/baseband build (`tegu`/`stallion` differ).
- **Impact.** None; consistent with the required version strings, not a stamp mis-copy. Recorded so the identity is not
  mistaken for cross-device contamination in a later review.

### F-006 — Info (positive) — The four Wave A stamps are **not** `MODE=gtuserspace` hybrids
- **Evidence.** Contrast with the laguna hybrids: `frankel/blazer/mustang/rango` `vendor_dlkm.img` ships a **factory
  stock** blocklist (15–16 lines, `.ko`-suffixed, **0** `nitrous`) and their READMEs document `MODE=gtuserspace`,
  "factory `BP4A.260205.001` boot chain + dlkm", "NOT boot-verified". The four Wave A `vendor_dlkm.img` files ship the
  **GuardTalk excision-variant** blocklist (token-identical to the variant canonical, `nitrous` present) and their
  READMEs document a full build (`BUILD_EXIT=0`, `Variant = <dev>-trunk_staging-userdebug`) with no factory/dlkm/hybrid
  language. The four Wave A `boot/init_boot/vendor_boot/vendor_kernel_boot/dtbo/pvmfw/system/system_ext/product/vendor/vendor_dlkm/system_dlkm`
  images are byte-identical to `out/target/product/<dev>/` (see §5). **Hybrid status = NO — confirmed.**

### F-007 — Info — Shipped blocklists are blank-line-normalized vs source; no `tokay-latest` alias (both by design)
- **Evidence.** `diff` of the extracted shipped `modules.blocklist` vs the canonical source shows only **blank lines**
  removed (e.g. caiman: source has 3 interior blank lines, shipped has none); all `blocklist …` lines and comments
  match. `verify_port_*`/`A-EXCISE-13DEV-NONREGRESSION` §6 independently record that **no `tokay-latest`** symlink
  exists — `tokay`'s authoritative stamp is the legacy global `latest → tokay-20260725-102506`.
- **Impact.** None. Benign normalization; the `tokay` alias shape is deliberate and unchanged.

---

## 4. `stallion` `HOLD-PORT-STALLION` ruling

**Ruling: the stamp is structurally sound and does not overclaim; the README under-discloses the HOLD → F-002 (Low).**

- **The artifact exists, validates and is complete.** `stallion-20260923-100618` — 20 files, `sha256sum -c SHA256SUMS`
  **exit 0**, all expected images present, every image byte-identical to `out/target/product/stallion/`. The build did
  **not** fail on kernel prebuilts (`device/google/stallion-kernels/6.1/grapheneos` present), so the conditional HOLD
  (`TASK_QUEUE.md:6933` "records a precise HOLD **if the build fails** on kernel prebuilts") did **not** trigger.
- **`BUILD_ID` divergence is real and correctly recorded in the artifact.** `stallion` fingerprint =
  `…Baklava/BD6A.251031.001.A4…` vs `caiman/comet` = `BP4A.260205.002`, `tegu` = `BP4A.260205.001`
  (`out/target/product/<dev>/build_fingerprint-<dev>.txt`). The README prints the BD6A fingerprint verbatim — the
  divergence is **not concealed**.
- **No `RELEASE_KERNEL_STALLION_DIR.textproto` in any channel.** Verified absent under
  `build/release/flag_declarations/` and every `build/release/flag_values/<channel>/`; `stallion` resolves its kernel
  dir by a literal path (as `T-PORT-MATRIX-PREFLIGHT` documented). This is a **structural asymmetry** the README does
  not mention.
- **Honesty assessment.** The stamp README **does not paper over** the situation with any false claim: it declares
  `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false`, `BOOT_VERIFIED=false`, the `trunk_staging-userdebug` variant, the
  `zumapro_stallion` excision variant and the `vendor_manifest_no_radio_stallion.xml` manifest — **all independently
  verified true**. It is **silent**, not dishonest, on the platform-lag/baseline and the missing kernel-dir flag.
  Therefore: **honest-as-stated, under-disclosed** — Low finding, no rebuild or status change implied.

---

## 5. Bundle completeness, integrity and stamp→out identity (per device)

**1. Stamp identity** — `releases/desktop-flash/<dev>-latest` resolves as claimed:

| Link | Target (readlink) | inode | mtime |
|---|---|---|---|
| `caiman-latest` | **`caiman-20260922-090535`** ✅ (packet-claimed) | 193110382 | 2026-09-22 09:06:16 |
| `comet-latest` | `comet-20260922-160129` | 193110383 | 2026-09-22 16:01:42 |
| `tegu-latest` | `tegu-20260922-164700` | 193110384 | 2026-09-22 16:47:14 |
| `stallion-latest` | `stallion-20260923-100618` | 193110390 | 2026-09-23 10:06:41 |

**2. `SHA256SUMS`** — `sha256sum -c SHA256SUMS` → **exit 0** on all four (20 entries each; e.g. `caiman`
`554f5ae3b3ece63612f3f807d765fde4b7eecfaf7acd7aafe526281414682482`). Transcripts:
`.agent-comm/evidence/A-PORT-WAVE-A/sha256-<stamp>.txt`.

**3. Expected image set present** — for all four: `boot`, `init_boot`, `vendor_boot`, `vendor_kernel_boot`, `dtbo`,
`pvmfw`, `vbmeta`/`vbmeta_system`/`vbmeta_vendor` (identical 65536 B AVB images; hashes in `SHA256SUMS` confirm the
"copy of `vbmeta.img`" claim), `system`, `system_ext`, `product`, `vendor`, `vendor_dlkm`, `system_dlkm`, `radio`,
`bootloader`, `super_empty` + `avb_pkmd.bin` + `init.insmod.<dev>.cfg` + `README-FLASH-DESKTOP.md` + `SHA256SUMS`.
`super.img` omitted (F-004).

**4. Stamp == built output (byte-identical).** Every stamp image present in `out/target/product/<dev>/` hashes
**equal** to the stamp's `SHA256SUMS` entry (20/20 across the four; the only "misses" are `vbmeta_system`/`vbmeta_vendor`,
which exist only as stamp copies of `vbmeta.img`, and `avb_pkmd.bin`/`init.insmod.<dev>.cfg`, which live under
`out/target/product/<dev>/vendor_dlkm/etc/`). Transcripts: `.agent-comm/evidence/A-PORT-WAVE-A/stamp-vs-out-<dev>.txt`.
`init.insmod.<dev>.cfg` stamp↔`out/…/vendor_dlkm/etc/` sha256 **equal** for all four (caiman `3f4cee38…`, comet
`71fa85d9…`, tegu `2cf7248e…`, stallion `f40b37de…`).

---

## 6. Flash-script coverage (independent re-run)

`vendor/guardtalk/scripts/flash-from-remote.sh` and `scripts/flash-from-remote.sh` are **byte-identical**
(`sha256 e3d0fc534eb95ba5b68367fbe374b7fd41571ec1ffe9c4a746549b50efec0a19`, `diff` clean); `bash -n` → **exit 0** on both.
`script/generate-release.sh` → `bash -n` **exit 0**.

**Device resolution.** `normalize_device` (`:257-298`) maps `caiman/comet/tegu/stallion`; `apply_remote_paths`
(`:321-381`) maps each to `releases/desktop-flash/<dev>-latest`; an unknown codename `die`s. `apply_device_extra_downloads`
adds `init.insmod.<dev>.cfg` for all four, and step 8b (`:1585-1590`) covers all non-`tokay` devices.

**Firmware grouping — independent stub re-run** (stub `fastboot` logs calls, never contacts a device;
transcript `.agent-comm/evidence/A-PORT-WAVE-A/firmware-cleanup-callset.txt`):

| Device | calls issued | `erase fips` | matches `script/generate-release.sh` |
|---|---|---|---|
| `caiman` | `oem uart disable` + `erase fips` + `erase dpm_a` + `erase dpm_b` | **YES** | ✅ FIPS arm (`:61`) |
| `comet` | same | **YES** | ✅ |
| `tegu` | same | **YES** | ✅ |
| `stallion` | same | **YES** | ✅ |
| `blazer`/`frankel`/`mustang`/`rango` | `oem uart disable` + `erase dpm_a` + `erase dpm_b` | **no** | ✅ NO-FIPS arm (`:56`) |
| `tokay`/`akita`/`komodo`/`shiba`/`husky` | UART+FIPS+DPM | **YES** | ✅ |

**Negative control:** `FLASH_DEVICE=PixelFoo` → `die "No GrapheneOS firmware-cleanup profile…"`, **0** fastboot calls.
The `*)` arm is `die`, never `warn`-and-continue. **The four Wave A devices get UART+FIPS+DPM; the NO-FIPS set is
exactly `blazer frankel mustang rango`.** Agreement with `Q-PORT-FLASH-CLI-9DEV` (its A2/A3/A5 upheld) — **no
disagreement found**.

---

## 7. Non-regression of the incumbent `*-latest` links

**Result: PASS — no incumbent link moved.** Targets and inodes are **identical** to those independently recorded by
`A-EXCISE-13DEV-NONREGRESSION_AUDIT.md` §6, and every incumbent mtime predates the Wave A stamps:

| Link | Target | inode | mtime | Verdict |
|---|---|---|---|---|
| `latest` (global `tokay` alias) | `tokay-20260725-102506` | 193110379 | 2026-07-25 10:25 | **unchanged** ✅ |
| `tokay-latest` | **ABSENT** (by design — `tokay` uses the global `latest`) | — | — | **unchanged** ✅ |
| `akita-latest` | `akita-20260725-101434` | 193110357 | 2026-07-25 10:14 | **unchanged** ✅ (inode matches EXCISE §6) |
| `komodo-latest` | `komodo-20260915-063833` | 193110380 | 2026-09-15 06:39 | **unchanged** ✅ |
| `rango-latest` | **`rango-20260802-130756`** | 193110354 | 2026-08-02 13:08 | **required target held** ✅ |

Transcript: `.agent-comm/evidence/A-PORT-WAVE-A/nonregression-latest-links.txt`. No boot-green/flash claim is made for
`rango` or any device.

---

## 8. Resolved variant from the SHIPPED image (per device)

| Device | Expected variant (`excision-variants.mk`) | `vendor_dlkm` blocklist header (shipped) | Blocklist token-group (shipped) | VINTF provenance (`vendor.img`) | Verdict |
|---|---|---|---|---|---|
| `caiman` | `zumapro_caimito` | `# GuardTalkOS — tokay (caimito-kernels)…` ⚠ | `bcmdhd4390`,`syna_touch`,`sec_touch`,`nitrous` (= canonical) | `vendor_manifest_no_radio.xml` | **matches** variant content; header label ambiguous (**F-001**) |
| `comet` | `zumapro_comet` | `# GuardTalkOS — zumapro_comet (zumapro / comet)…` | `bcmdhd4390`,`goodix_brl_touch`,`syna_touch`,`sec_touch`,`nitrous` | `vendor_manifest_no_radio.xml` | **matches** ✅ |
| `tegu` | `zumapro_tegu` | `# GuardTalkOS — zumapro_tegu (zumapro / tegu)…` | `bcmdhd4383`,`syna_touch`,`nitrous` | `vendor_manifest_no_radio.xml` | **matches** ✅ |
| `stallion` | `zumapro_stallion` | `# GuardTalkOS — zumapro_stallion (zumapro / stallion)…` | `bcmdhd4383`,`focal_touch.ko`,`sts4x_ambient_i2c`,`nitrous` | `vendor_manifest_no_radio_stallion.xml` | **matches** ✅ (README claim confirmed) |

Raw extracted blocklists: `.agent-comm/evidence/A-PORT-WAVE-A/blocklist-<dev>.txt`; provenance headers:
`vintf-and-blocklist-headers.txt`. `vendor.img` sha256 — caiman `9883db8e…`, comet `8c188495…`, tegu `ab9bf5cc…`,
stallion `1a7e1dc0…`. This **agrees** with `A-EXCISE-13DEV-NONREGRESSION` (RESOLVER HOLDS); **no contradiction**.

---

## 9. EXCISE cross-reference (cited, not re-derived)

- **`A-EXCISE-13DEV-NONREGRESSION`** — verdict **✅ RESOLVER HOLDS**: 13/13 resolve to the expected variant; per-device
  built `vendor_dlkm` token-groups distinct/correct (`tokay/caiman/komodo` = `zumapro_caimito`; `comet` = `zumapro_comet`;
  `tegu` = `zumapro_tegu`; `stallion` = `zumapro_stallion`); 0 Critical/High/Medium, 7 Low, 2 Info. This lane's
  independent shipped-image re-derivation **agrees**.
- **`A-EXCISE-AIRGAP-MATRIX`** — airgap verdict **FALSE** (36 residuals; 8 CRITICAL: C-R1, C-B1, C-B2, C-L1, C-L2,
  C-S1, C-S2, C-S3; HIGH 8 / MEDIUM 12 / LOW 6 / INFO 2). **Nothing in this Wave A report may be read as an airgap
  clearance.** In particular, the four stamps carrying `nitrous` in `vendor_dlkm.modules.blocklist` does **not** mean
  BT is excised: EXCISE `E-14`/`F-005` proved **8** BT/NFC GKI modules remain in `system_dlkm/modules.load` and **0**
  are blocklisted **13/13** (Tier C). Bundle integrity ≠ excision.
- **Known-good context verified, not trusted:** `frankel/blazer/mustang/rango` are `MODE=gtuserspace` hybrids carrying
  **factory `vendor_dlkm`** (see F-006). The four Wave A devices are **not** hybrids — proven by their shipped
  GuardTalk-variant `vendor_dlkm` blocklists vs the hybrids' factory stock blocklists.

---

## 10. Author-side suite re-run

- `verify_port_excision_matrix_static.sh`, `verify_port_matrix_preflight_static.sh`, `verify_port_kernel_matrix_static.sh`,
  `verify_remediate_b2_apex_host.sh`, `verify_remediate_b2_excise_host.sh` — **not** the subject of this card. Their
  current pass/fail state is recorded by `A-EXCISE-AIRGAP-MATRIX` / `A-PORT-MATRIX-R2` (`kernel_matrix`/`preflight` RED =
  LAYER suite staleness; `b2_apex` source-structural = `E-20`, routed to the B2 lane). **No re-run performed here** —
  the Wave A surfaces are bundle/flash/stamp/non-regression, covered by the primary-artifact checks above.
- The one author-adjacent suite that **is** in scope (the flash CLI behaviour) was **independently re-driven** with a
  stubbed `fastboot` (§6) and **agrees** with `Q-PORT-FLASH-CLI-9DEV`.

---

## 11. Honesty / residual

- **No** device, `adb`, `fastboot`, flash, boot or runtime result is claimed. `LIVE_FLASH_CLAIMED=false`, `FLASH_READY=false`,
  DEC-009 HOLD; `rango-latest` left at `rango-20260802-130756`; **no** boot-green claim for any device.
- Gate -1 **in-process** (`governance_loaded=true`); Gate 5 **HUMAN SKIP** — no score invented.
- No product/test/filter/flash/packer/doctrine file edited; `TASK_QUEUE.md` **not** hand-edited;
  `.agent-comm/inbox/TO_ARCHITECT.md` **not** touched; no agent dispatched; no task status changed. Status = **REVIEW**.
- **Residual uncertainty:** the excision-tier and airgap adjudication are **out of scope** here and remain governed by
  `A-EXCISE-AIRGAP-MATRIX` (**FALSE**). This lane proves only that the four Wave A builds are complete, stamped,
  variant-consistent, flash-covered and non-regressing.

---

## 12. Evidence index (`.agent-comm/evidence/A-PORT-WAVE-A/`)

| File | Content |
|---|---|
| `sha256-<stamp>.txt` | `sha256sum -c SHA256SUMS` transcript (exit 0) per device |
| `stamp-vs-out-<dev>.txt` | stamp image hashes vs `out/target/product/<dev>/` (byte-identical) |
| `blocklist-<dev>.txt` | `modules.blocklist` extracted from the shipped `vendor_dlkm.img` |
| `vintf-and-blocklist-headers.txt` | shipped VINTF manifest provenance header + blocklist header, 4 devices |
| `firmware-cleanup-callset.txt` | stubbed-`fastboot` call set per codename + negative control |
| `nonregression-latest-links.txt` | incumbent `*-latest` targets/inodes/mtimes |
| `artifact-sha256.txt` | flash script (both copies), canonical blocklists, stamp `SHA256SUMS` hashes |

### Deliverables written
- `vendor/guardtalk/docs/qa/A-PORT-WAVE-A_AUDIT.md` (this report)
- `.agent-comm/evidence/A-PORT-WAVE-A/*` (above)
- `.agent-comm/history/2026-09-24T180500+0400-A-PORT-WAVE-A-audit.md`
- `.agent-comm/signals/review-A-PORT-WAVE-A.json`
