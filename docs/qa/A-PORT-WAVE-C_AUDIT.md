# A-PORT-WAVE-C — Independent Deep-Tech Audit (Panel 5, Auditor)

| Field | Value |
|---|---|
| task_id | `A-PORT-WAVE-C` |
| role | Auditor (Panel 5) — **READ-ONLY** |
| audit_scope | `full` |
| owner_repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id: grapheneos-worktree`) |
| authoritative task path | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` (§ `AUDIT WAVE DISPATCH` §B1–§B4; § `EXTREME AUDIT — AIRGAP CLAIM`) |
| depends_on (re-scoped §B2) | `T-PORT-BUILD-BATCH-B` + `Q-PORT-FLASH-CLI-9DEV` ✅ + `Q-EXCISE-13DEV-MATRIX` ✅ |
| status | **REVIEW** (auditor never sets `APPROVED`) |
| Gate -1 | **IN-PROCESS** — `.aegis/governance/laws/*.yaml` (24) + `.aegis/governance/gates/*.yaml` (11) parsed from disk; `governance_loaded=true`. No `aegis-verifier` / `ask_guardian` / `gate_enforcer` / Guardian HTTP call. |
| Gate 5 | **HUMAN SKIP** — no Gate 5 numeric score invented. |
| `LIVE_FLASH_CLAIMED` | **`false`** — no hardware attached; no USB / adb / fastboot executed; DEC-009 HOLD. |
| Device / boot results | **none claimed** (forbidden). |
| Timestamp | 2026-09-24T18:05:00+04:00 (host UTC 2026-09-24T14:xxZ) |

**Wave C devices (audited individually, never one blanket verdict):** `frankel`, `blazer`, `mustang` (`laguna_muzel`, QFP).

**Raw evidence:** `.agent-comm/evidence/A-PORT-WAVE-C/` (`01`–`09`).

---

## 1. Verdict

> **Bundle / flash / stamp integrity: PASS. Hybrid excision posture: FALSE. Disclosure: PARTIAL.**

- All three `-latest` resolve exactly as claimed; `sha256sum -c SHA256SUMS` exits **0** on all three (22/22 files each); the expected flash image set is present in full.
- Flash-script coverage is correct: `DEVICE=<dev>` auto-maps to `<dev>-latest`, the laguna **NO-FIPS** grouping (`UART`+`DPM`, no `erase fips`) is applied to all three (and differs from Wave A's `zumapro` FIPS grouping), and `bash -n` is clean.
- Non-regression holds: the incumbent `latest` (tokay alias), `akita-latest`, `komodo-latest`, `rango-latest` are unmoved (targets + inodes + mtimes corroborated against recorded baselines).
- **But** the hybrid composition is not what the program text (`E-18` / the stamp README "value-as-shipped" table) says: `vendor.img` is **GuardTalkOS (radio-excised GT)**, not factory. And the hybrid inherits the **factory `vendor_dlkm`**, so `nitrous.ko` is **loaded unblocked** (Tier C) — reproducing `A-EXCISE-BT` `F-001` on all three — while `androidboot.radio.disabled` is **absent** — reproducing `A-EXCISE-RADIO` `F-005`.

### Severity counts

| Severity | Count | IDs |
|---|---|---|
| Critical | **1** | `F-001` |
| High | **1** | `F-002` |
| Medium | **2** | `F-003`, `F-004` |
| Low | **1** | `F-005` |
| Info / disagreement | **1** | `F-006` |

---

## 2. What was audited (lane scope)

Audited the **built and stamped** artifact (per §B4 "prefer shipped artifacts over makefiles"):

1. `releases/desktop-flash/{frankel,blazer,mustang}-latest` → run dirs, file set, `SHA256SUMS`.
2. Each stamp's shipped `vendor.img`, `vendor_dlkm.img`, `system_dlkm.img`, `boot.img`, `vendor_boot.img`.
3. Factory references `releases/desktop-flash/{dev}-stock-userspace/` (documented verbatim `BP4A.260205.001` donor) and the full-GT references (`frankel-20260922-165726`, `blazer-20260923-034646`, `mustang-20260923-101119`).
4. `script/generate-release.sh`, `scripts/flash-from-remote.sh` (== `vendor/guardtalk/scripts/flash-from-remote.sh`), `gt-flash-blazer/flash-from-remote.sh`.
5. `vendor/guardtalk/feature-excised/{excision-variants.mk,fp-excised.mk}`, `vendor/guardtalk/scripts/stage-laguna-release.sh`.
6. Cross-reference (not re-derived): `A-EXCISE-13DEV-NONREGRESSION` (RESOLVER HOLDS), `A-EXCISE-AIRGAP-MATRIX` (verdict **FALSE**, 36 residuals / 8 CRITICAL), `A-EXCISE-BT` (FALSE), `A-EXCISE-RADIO` (F-005).

---

## 3. Per-device table — all 7 scope items

Legend: ✅ pass · ⚠️ pass-with-finding · ❌ fail.

| # | Scope item | `frankel` (`frankel-20260923-094457`) | `blazer` (`blazer-20260923-090842`) | `mustang` (`mustang-20260923-094541`) |
|---|---|---|---|---|
| 1 | **Bundle completeness** (`sha256sum -c`, expected set) | ✅ 22/22 OK, exit 0, expected set complete | ✅ 22/22 OK, exit 0, expected set complete | ✅ 22/22 OK, exit 0, expected set complete |
| 2 | **Stamp identity** (`-latest` → target + mtime) | ✅ `frankel-latest` → `frankel-20260923-094457` (dir mtime 2026-09-23 10:17:56Z, inode 206804772) | ✅ `blazer-latest` → `blazer-20260923-090842` (dir mtime 2026-09-23 10:17:56Z, inode 194290039) | ✅ `mustang-latest` → `mustang-20260923-094541` (dir mtime 2026-09-23 10:17:56Z, inode 206804850) |
| 3 | **Variant from shipped `vendor.img`** | ✅ VINTF provenance `vendor_manifest_no_radio_laguna_muzel.xml`; QFP stack (`libqfp-service.so`, `libqfpsuez.so`) — **not** rango's Goodix | ✅ `vendor_manifest_no_radio_laguna_muzel.xml`; QFP stack — **not** Goodix | ✅ `vendor_manifest_no_radio_laguna_muzel.xml`; QFP stack — **not** Goodix |
| 4 | **Flash-script coverage** (`DEVICE=`, `bash -n`, grouping) | ✅ auto-map to `frankel-latest`; **NO-FIPS** (UART+DPM); `bash -n` OK | ✅ auto-map to `blazer-latest`; **NO-FIPS** (UART+DPM); `bash -n` OK | ✅ auto-map to `mustang-latest`; **NO-FIPS** (UART+DPM); `bash -n` OK |
| 5 | **Non-regression** (incumbent `-latest`) | ✅ `latest`→tokay-20260725-102506, `akita-latest`, `komodo-latest`, `rango-latest` unmoved | ✅ same (shared symlinks unmoved) | ✅ same (shared symlinks unmoved) |
| 6 | **E-18 hybrid composition + F-001/F-005** | ⚠️ `vendor_dlkm`+`system_dlkm`+`boot` = factory; **`vendor.img` = GT** (radio-excised); **`F-001❌ nitrous loaded unblocked`**; **`F-005❌ radio.disabled absent`**; README line 17 misstates vendor | ⚠️ same; **`F-001❌`**, **`F-005❌`** | ⚠️ same; **`F-001❌`**, **`F-005❌`**; plus `-latest` pointer conflict (F-002) |
| 7 | **`rango` promotion (read-only)** | ✅ (shared) `rango-latest` unmoved; no promotion implied | ✅ (shared) same | ✅ (shared) same |

---

## 4. Findings

### F-001 — CRITICAL — `nitrous.ko` (BCM4390 BT power/rfkill) is **loaded unblocked** on all three Wave C `-latest` (Tier C)

**Reproduces** `A-EXCISE-BT` `F-001` (CRITICAL) independently, from the shipped artifact.

- **Evidence:** `debugfs` on each `-latest` `vendor_dlkm.img` — `modules.blocklist` is the **stock 16-line** list with **0** `nitrous` entries, while `nitrous.ko` is present **and** listed in `modules.load`.
  - `frankel-20260923-094457/vendor_dlkm.img` sha256 `ce550998acbb86d7…` (37,572,608 B) — blocklist 16 lines / 0 nitrous / present / in `modules.load`.
  - `blazer-20260923-090842/vendor_dlkm.img` sha256 `283334773278ddb7…` (37,572,608 B) — same.
  - `mustang-20260923-094541/vendor_dlkm.img` sha256 `b47862d5226b394f…` (37,572,608 B) — same.
  - Contrast: `mustang-20260923-101119` (`7e748bdd395b9b74…`, 49,147,904 B) and `frankel-20260922-165726` (`9a1543e60531771b…`) carry **2** `nitrous` lines / 33 lines.
  - Raw: `.agent-comm/evidence/A-PORT-WAVE-C/03-nitrous-blocklist.txt`.
- **Impact:** the `bt-excised.mk:19-20` safety invariant ("GKI BT modules are harmless without `nitrous`") is **false** on these stamps — the rfkill power-on path is live, and `bluetooth.ko`/`hci_uart.ko`/`btbcm.ko` are present in `system_dlkm` ⇒ **Tier C** (can become active). Bluetooth = **FALSE** on all three.
- **Root cause (hybrid-specific):** the hybrid ships the **factory `vendor_dlkm`** (see F-003), and the variant `blocklist nitrous` lives in `vendor_dlkm`; it therefore cannot reach the image. This is **not** an authoring regression — it is the structural consequence of `MODE=gtuserspace`.
- **Recommendation (Architect/operator decision):** either accept a documented waiver for the laguna hybrids, or apply the BT blocklist via the parts of the composition that *are* GT (a `system`/`vendor.img`-side gate), or withhold the BT "removed" claim for the laguna hybrids. Re-build + re-verify with `debugfs` before any re-stamp.

### F-002 — HIGH — `mustang-latest` pointer serves the blocklist-missing hybrid while the blocklist-correct artifact is a boot-risky fullgt

- **Evidence:** `mustang-latest → mustang-20260923-094541` (hybrid, 0 `nitrous`), whereas `mustang-20260923-101119` (2 `nitrous`) is a **fullgt** composition (`virt.apex` present / `Flags:0`) that `DEC-PORT-GEN8910-WAVE3-OPERATOR` §D1 classed as **ABL-rejected on-device (AB 11311112)** and deliberately repointed away from.
- **Impact:** the "correct blocklist" and "bootable composition" requirements are in direct conflict for `mustang`; the shipped pointer resolves to the composition with the live BT power path. Repointing to `101119` would restore the blocklist but serve a composition known to be ABL-rejected.
- **Recommendation:** resolve the `mustang-latest` ownership conflict explicitly (operator/Architect); do not repoint unilaterally (matches `E-10` §127).

### F-003 — MEDIUM — Hybrid composition is mis-disclosed; `vendor.img` is **GT**, not factory (README internal contradiction; `E-18` wording partially refuted)

- **Evidence (artifact, decisive):** comparing each shipped image against the documented factory donor (`<dev>-stock-userspace/`, verbatim `BP4A.260205.001`) and the fullgt reference:
  - `vendor.img`: hybrid == **fullgt** (GT), **≠** factory stock, on all three.
    - `frankel` hybrid `de9233a2970c28d5…` == fullgt `de9233a2970c28d5…`; stock `bb8f3462cf02672b…`.
    - `blazer` hybrid `c357e1e49edbd5c4…` == fullgt `c357e1e49edbd5c4…`; stock `426ec4cdd630f7ad…`.
    - `mustang` hybrid `c70f550235df81a3…` == fullgt `c70f550235df81a3…`; stock `f528439268baa25c…`.
  - `boot.img` / `vendor_dlkm.img` / `system_dlkm.img`: hybrid == **factory stock**, ≠ fullgt (all three).
  - Raw: `.agent-comm/evidence/A-PORT-WAVE-C/02-hybrid-composition.txt`.
  - The shipped GT `vendor.img` carries the **radio-excised** VINTF provenance header `vendor/guardtalk/vintf/vendor_manifest_no_radio_laguna_muzel.xml` (11 HAL entries, 0 radio/telephony).
  - `stage-laguna-release.sh:15-16`, `:2398-2399` state the intended composition verbatim: *"factory boot chain + factory system_dlkm/vendor_dlkm + GuardTalkOS system/system_ext/product/vendor"* and *"the boot chain + dlkm are factory but vendor.img is GT"*.
- **Contradiction:** each README line **17** says `vendor / vendor_dlkm / system_dlkm | Factory BP4A.260205.001`, while the **same** README lines **47**, **61** and **86** say vendor is GuardTalkOS (GT). `TASK_QUEUE.md` `E-18` repeats the "factory vendor" wording.
- **Impact:** (a) a reader relying on the as-shipped table would conclude **no** vendor-side excision applied, when in fact the GT radio-excised `vendor.img` **is** shipped; (b) `E-18`'s blanket claim that "vendor-side excisions cannot apply" is **imprecise** — only the `vendor_dlkm`/`system_dlkm`-resident excisions (e.g. the `nitrous` blocklist) cannot apply; `vendor.img`-resident excisions **do** apply. The specific `F-001` consequence still holds.
- **Ruling (hybrid disclosure):** the READMEs are **substantially honest** — they disclose the hybrid `MODE=gtuserspace`, factory boot chain + dlkm, `BOOT_VERIFIED = false`, "no hardware attached" and the first-flash risk — but line **17** is internally contradictory and wrong. Disclose `vendor` as GuardTalkOS, not factory.
- **Recommendation:** correct README line 17 (and the `E-18` wording) to `system / system_ext / product / vendor = GuardTalkOS OUT`; keep `system_dlkm / vendor_dlkm / boot* = Factory`.

### F-004 — MEDIUM — `androidboot.radio.disabled` is **absent** on all three hybrids (reproduces `A-EXCISE-RADIO` `F-005`)

- **Evidence:** `grep -a -c androidboot.radio.disabled` = 0 in `boot.img` **and** `vendor_boot.img` for `frankel`/`blazer`/`mustang` (and `rango`), versus **1** in `vendor_boot.img` for `shiba`/`akita`/`komodo`/`tokay`. Raw: `.agent-comm/evidence/A-PORT-WAVE-C/06-radio-disabled.txt`.
- **Impact:** confirms the per-device asymmetry (present 9/13, absent 4/13 laguna). Root cause is the same composition: the hybrid installs the **factory boot chain** (`boot.img` bus hash-identical to the factory donor), so no GuardTalk bootconfig property is present.
- **Recommendation:** record as a hybrid residual in the residual register; do not claim the radio-disable bootconfig on the laguna hybrids.

### F-005 — LOW — QFP fingerprint libraries remain in the shipped `laguna_muzel` `vendor.img` (Tier B)

- **Evidence:** `debugfs` on each hybrid `vendor.img` lists `/vendor/lib64/libqfp-service.so` (763,360 B) and `/vendor/lib64/libqfpsuez.so` (118,112 B). No fingerprint HAL is declared in the shipped VINTF manifest and there is no `qfp`/`fingerprint` init `.rc` under `/vendor/etc/init` ⇒ **Tier B** (dormant). Raw: `.agent-comm/evidence/A-PORT-WAVE-C/07-variant-provenance.txt`.
- **Impact:** the name-based FP drop patterns (`fp-excised.mk` / `GT_EXCISION_FP_TOKENS_QFP` = `vendor.qti.hardware.fingerprint`, `dump_fingerprint`, `qfp-daemon`) do **not** match `libqfp-service` / `libqfpsuez`, so the QFP userspace libraries survive. Fingerprint is outside the airgap service set, so this is not an airgap FAIL, but it contradicts an implicit "FP fully removed" reading.
- **Recommendation:** extend the QFP drop patterns (or add a `libqfp*` token) in the EXCISE lane; re-verify with `debugfs`.

### F-006 — INFO / disagreement — Author-side suite staleness (reproduced by re-run)

Re-ran the author suites (§B4: re-run, do not trust). Raw: `.agent-comm/evidence/A-PORT-WAVE-C/08-author-suite-rematch.txt`.

- `verify_port_excision_matrix_static.sh` → **EXIT 0** (PASS_COUNT=128, FAIL=0) — **agrees**.
- `verify_excise_13dev_matrix_static.sh` → **EXIT 0** (PASS=65 / RESIDUAL=15 / FAIL=0) — **agrees**.
- `verify_flash_cli_harden_static.sh` → **EXIT 1**: `FAIL: rango production rescue call missing` / `flash_rango_rescue_boot_chain vanished`. The current script generalised the rango-only rescue to the whole laguna family (`flash_rescue_boot_chain`, used for `rango|frankel|blazer|mustang`); the suite still asserts the old rango-only symbol. **Suite staleness, not a Wave C regression** (same class as `E-11`).
- `verify_port_rango_static.sh` → **EXIT 1**: stale `rango-latest` expectation (`rango-20260725-133716`); the actual `rango-20260802-130756` is the **documented unmoved target**. **Suite staleness.**
- `verify_rango_boot_remediate_static.sh` — long-running; not conclusively captured (noted, not adjudicated).

---

## 5. Detail — scope items

### 5.1 Bundle completeness (item 1)
Each stamp holds **22** `SHA256SUMS` entries; `sha256sum -c` exits **0** for all three. The flash script's expected set (`FW_IMAGES` + `AB_IMAGES` + `NOAB_IMAGES` + `LOGICAL_IMAGES` + `SUPER_IMAGE` + `EXTRA_FILES` + per-device `init.insmod.<dev>.cfg`) is present in full, plus `avb_pkmd_testkey.bin`, `vbmeta_valid_flags3.img`, `README-FLASH-DESKTOP.md`. Evidence `01-bundle-sha256.txt`.

### 5.2 Stamp identity (item 2)
All three `-latest` targets match the claimed stamps exactly; `README-FLASH-DESKTOP.md` `Staged (UTC)` matches the contained image mtimes. Evidence `04-nonregression-links.txt`.

### 5.3 Variant from the shipped image (item 3)
VINTF provenance = `vendor_manifest_no_radio_laguna_muzel.xml` on all three (rango = `…_rango.xml`). Registry `excision-variants.mk:71-74` maps `frankel/blazer/mustang → laguna_muzel`, `rango → laguna_rango`; `:146/:155` — `laguna_muzel_FP_STACK := qfp`, `laguna_rango_FP_STACK := goodix`; `:148/:157` — different BLOCKLIST paths. The two laguna variants differ **only** in FP stack + blocklist, **confirmed**; the three do **not** mirror rango's Goodix handling.

### 5.4 Flash-script coverage (item 4)
`DEVICE=frankel|blazer|mustang` auto-maps to the matching `-latest`; the cleanup profile `rango|mustang|blazer|frankel` = `oem uart disable` + `erase dpm_a/b` (**NO** `erase fips`) — **differs from Wave A** (`tokay|akita|komodo|caiman|comet|tegu|stallion|shiba|husky` = `+ erase fips`). `script/generate-release.sh:57-61` matches. `bash -n` OK for `script/generate-release.sh`, `scripts/flash-from-remote.sh`, `vendor/guardtalk/scripts/flash-from-remote.sh`, `vendor/guardtalk/scripts/flash-from-remote-signed.sh`, `gt-flash-blazer/flash-from-remote.sh`; `scripts/ == vendor/guardtalk/scripts/` (byte-identical). Evidence `05-flash-coverage.txt`.

### 5.5 Non-regression (item 5)
`latest → tokay-20260725-102506` (inode 193110379, mtime 2026-07-25), `akita-latest → akita-20260725-101434` (193110357), `komodo-latest → komodo-20260915-063833` (193110380), `rango-latest → rango-20260802-130756` (193110354). Identical to the recorded baseline in `.agent-comm/evidence/A-PORT-WAVE-B/nonregression-latest-links.txt` and `vendor/guardtalk/docs/RANGO_BOOT_REMEDIATE.md:42` (rango symlink inode 193110354 → target inode 199431966). **Untouched.** Evidence `04-nonregression-links.txt`.

### 5.6 `rango` promotion — read-only assessment (item 7)
- **Unmoved:** `rango-latest → rango-20260802-130756`; symlink inode 193110354, target inode 199431966 — matches the documented record. No retarget.
- **No boot-green:** the tree explicitly keeps the HOLD (`RANGO_BOOT_FIX.md:11` "unchanged; **do not** promote … until on-device PASS"; `DR-RANGO-10DAY-RCA.md:17` "`rango-latest` = `rango-20260802-130756` (known FAIL)"; `WEB_INSTALLER.md` "do not add rango to the web allowlist until Architect re-binds boot-green").
- **Assessment:** no promotion has been earned, and none is implied by the incumbent state. One over-broad sentence does appear in the three Wave C hybrid READMEs — *"the only laguna composition with any on-device boot evidence, and that evidence is for `rango` only"* — but it is immediately bounded by `BOOT_VERIFIED = false` and "No hardware is attached", and `rango-latest` itself is classed as a known FAIL. **Ruling: no boot-green claim; no promotion implied; hold stands.**

---

## 6. Cross-references (not re-derived)

- `A-EXCISE-13DEV-NONREGRESSION` — **RESOLVER HOLDS** (13/13), incumbents unchanged — consistent with §5.5.
- `A-EXCISE-AIRGAP-MATRIX` — umbrella verdict **FALSE** (36 residuals / 8 CRITICAL). This lane adds no contradictory result.
- `A-EXCISE-BT` — **FALSE**; `F-001` (nitrous) reproduced here on the three Wave C stamps.
- `A-EXCISE-RADIO` — `F-005` (bootconfig) reproduced here.

## 7. Holds & compliance

Read-only. No product/test/filter/flash/packer/doctrine/queue-authoritative file edited. `.agent-comm/inbox/TO_ARCHITECT.md` **not** touched. No `TASK_QUEUE.md` hand-edit. No USB/adb/fastboot; no device/boot result claimed. `LIVE_FLASH_CLAIMED=false`; DEC-009 HOLD. `Gate 5: HUMAN SKIP`. Status **REVIEW**; **never** `APPROVED`.
