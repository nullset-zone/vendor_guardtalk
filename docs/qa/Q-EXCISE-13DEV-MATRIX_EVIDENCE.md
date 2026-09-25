# Q-EXCISE-13DEV-MATRIX — Evidence

**Task:** `Q-EXCISE-13DEV-MATRIX` (P0) · **Program:** `DEC-EXCISE-AIRGAP-001` — Extreme audit of the OS-level airgap claim
**Role:** QA Engineer (Panel 4) · **Status:** `REVIEW` (never `APPROVED`)
**Authority:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md`, `EXTREME AUDIT — AIRGAP CLAIM (Gen 8/9/10, 13 devices)`
**depends_on:** `T-EXCISE-LEDGER` (✅ APPROVED 2026-09-24T17:05+04:00) · **Repository:** `grapheneos-worktree`
**Run date:** 2026-09-24 · **Gate -1:** in-process (24 laws + 11 gates loaded) · **Gate 5:** `HUMAN SKIP` (no score invented)
**Evidence root:** `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/` · **Harness:** `vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh`

---

## Headline verdict

> **The 13-device matrix is re-derived and its invariant set HOLDS on 13/13 — but the literal
> universal airgap claim is NOT proven.** Every device still carries documented Tier B/C
> residuals (baseband firmware, 8 unblocklisted BT/NFC GKI modules, `nitrous.ko`, and — on
> `shiba`/`husky` — an init-started location daemon stack). The verdict is
> **`TRUE-WITH-DORMANT-RESIDUALS` at best, FALSE for the literal "100% removed" claim**, in
> agreement with the auditor lanes. **This harness proves the matrix, not the absence of the
> residuals.**

| Check | Result |
|---|---|
| Harness on real inputs (13 shipped stamps) | **exit 0** — PASS=65 / RESIDUAL=15 / FAIL=0 |
| Negative control (deliberately un-excised fixture) | **exit 1 (non-zero)** — INV-1/2/3/4 violated + undocumented residual |
| Invariants INV-1…INV-5 | **13/13 PASS** |
| Documented residuals | present on every device (register below) |
| `Gate 5` | `HUMAN SKIP` |
| Device/boot result | **none** — `LIVE_FLASH_CLAIMED=false`, DEC-009 on-device HOLD |

## What the harness checks (from BUILT artifacts only)

Primary input = the **shipped `releases/desktop-flash/<dev>-latest` stamp**, read with `debugfs`
(the built image the claim is about). `out/target/product/<dev>/` is used only for the baseband
`modem.img` residual (E-7b) and to expose out/-vs-stamp divergence. No makefile evidence.

- **INV-1 variant resolution — from a BUILT artifact.** Prefer the GuardTalk `vendor_dlkm`
  `modules.blocklist` header; when absent (the 4 `laguna` stamps) use the vendor VINTF manifest
  provenance header. Resolved token must equal the registered expected variant.
- **INV-2** vendor VINTF is the radio-free manifest (provenance cites `vendor_manifest_no_radio*`
  **and** 0 `android.hardware.{radio,telephony,ims,iwlan}` HALs).
- **INV-3** no userspace `rild`/`rild_external` residue in `vendor`/`system`/`system_ext`.
- **INV-4** feature-permission XMLs absent for BT/NFC/Location
  (`android.hardware.{bluetooth,nfc,location,location.network,location.gps}{,.prebuilt}.xml`).
- **INV-5** stamp identity: `<dev>-latest → <expected stamp>`; **`tokay` has NO `tokay-latest`** —
  its authoritative stamp is the global `latest` alias.
- **Residuals (reported, never "removal"):** baseband `radio.img`/`modem.img`; the 8 GKI BT/NFC
  modules in `system_dlkm/lib/modules/modules.load` and their blocklist state; `nitrous.ko`
  presence + blocklist state; location `gpsd`/`lhd`/`scd` + `init.gps.rc` (`disabled`?) +
  `gps.default.so` + `/etc/gnss/*`.
- **Regression guard:** a residual on a device *outside* the documented set is a FAIL.

## 13-row per-device table (shipped stamps)

Legend: `V`=INV-1 variant, `R`=INV-2 radio-free VINTF, `r`=INV-3 no rild, `F`=INV-4 feature XMLs absent, `S`=INV-5 stamp. All rows `PASS` on every invariant.

| # | device | variant (expected) | variant resolved (source) | V | R | r | F | S | stamp |
|---|--------|--------------------|---------------------------|---|---|---|---|---|-------|
| 1 | shiba | zuma_shusky | zuma_shusky (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `shiba-20260923-094055` |
| 2 | husky | zuma_shusky | zuma_shusky (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `husky-20260923-095309` |
| 3 | akita | zuma_akita | zuma_akita (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `akita-20260725-101434` |
| 4 | tokay | zumapro_caimito | zumapro_caimito (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | global `latest` → `tokay-20260725-102506` (**no `tokay-latest`**) |
| 5 | caiman | zumapro_caimito | zumapro_caimito (blocklist hdr, cites `tokay`) | ✅ | ✅ | ✅ | ✅ | ✅ | `caiman-20260922-090535` |
| 6 | komodo | zumapro_caimito | zumapro_caimito (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `komodo-20260915-063833` |
| 7 | comet | zumapro_comet | zumapro_comet (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `comet-20260922-160129` |
| 8 | tegu | zumapro_tegu | zumapro_tegu (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `tegu-20260922-164700` |
| 9 | stallion | zumapro_stallion | zumapro_stallion (blocklist hdr) | ✅ | ✅ | ✅ | ✅ | ✅ | `stallion-20260923-100618` |
| 10 | frankel | laguna_muzel | laguna_muzel (VINTF provenance; stock blocklist) | ✅ | ✅ | ✅ | ✅ | ✅ | `frankel-20260923-094457` |
| 11 | blazer | laguna_muzel | laguna_muzel (VINTF provenance; stock blocklist) | ✅ | ✅ | ✅ | ✅ | ✅ | `blazer-20260923-090842` |
| 12 | mustang | laguna_muzel | laguna_muzel (VINTF provenance; stock blocklist) | ✅ | ✅ | ✅ | ✅ | ✅ | `mustang-20260923-094541` |
| 13 | rango | laguna_rango | laguna_rango (VINTF provenance; stock blocklist) | ✅ | ✅ | ✅ | ✅ | ✅ | `rango-20260802-130756` |

### Residual columns (per device; reported, never counted as removal)

| device | BT GKI modules loaded / blocklisted | nitrous.ko loaded / blocklisted | loc daemons | init.gps.rc (`disabled`) | radio.img (stamp) | modem.img (out/) | `androidboot.radio.disabled` (stamp vendor_boot) |
|--------|-----------------------------------|--------------------------------|-------------|--------------------------|-------------------|------------------|--------------------------------------------------|
| shiba | 8 / **0** | 1 / 1 | gpsd,lhd,scd | yes (**d=0**) | 112,967,820 B | 112,967,680 B | yes |
| husky | 8 / **0** | 1 / 1 | gpsd,lhd,scd | yes (**d=0**) | 112,967,820 B | 112,967,680 B | yes |
| akita | 8 / **0** | 1 / 1 | none | no | 115,355,788 B | 115,355,648 B | yes |
| tokay | 8 / **0** | 1 / 1 | none | no | 136,634,508 B | 136,634,368 B | yes |
| caiman | 8 / **0** | 1 / 1 | none | no | 136,634,508 B | 136,634,368 B | yes |
| komodo | 8 / **0** | 1 / 1 | none | no | 136,634,508 B | 136,634,368 B | yes |
| comet | 8 / **0** | 1 / 1 | none | no | 136,634,508 B | 136,634,368 B | yes |
| tegu | 8 / **0** | 1 / 1 | none | no | 98,766,988 B | 98,766,848 B | yes |
| stallion | 8 / **0** | 1 / 1 | none | no | 191,426,700 B | 191,426,560 B | yes |
| frankel | 8 / **0** | 1 / **0** | none | no | 191,426,700 B | 191,426,560 B | **no** |
| blazer | 8 / **0** | 1 / **0** | none | no | 191,426,700 B | 191,426,560 B | **no** |
| mustang | 8 / **0** | 1 / **0** | none | no | 191,426,700 B | 191,426,560 B | **no** |
| rango | 8 / **0** | 1 / **0** | none | no | 191,426,700 B | 191,426,560 B | **no** |

Raw: `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/matrix_real.tsv`, `harness_real.out`.

## Mandatory negative control — proof the harness can fail

A harness that cannot fail is not evidence. The harness synthesizes an **un-excised fixture**
(`--build-negative-fixture`) and runs the identical check functions against it.

| Run | Command | Exit |
|---|---|---|
| Real inputs (13 shipped stamps) | `bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh` | **0** |
| Negative control | `GTQ_MX_MODE=fixture GTQ_MX_FIXTURE=/tmp/gtq-mx-neg GTQ_MX_DEVICES=shiba bash …` | **1** |

Negative-control output (`.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/harness_negative.out`):

```
FAIL: shiba variant resolved 'laguna_muzel' (vendor_dlkm-blocklist-header) -> 'laguna_muzel' but expected zuma_shusky
FAIL: shiba vendor VINTF not radio-free (provenance='NONE', radio HALs=1)
FAIL: shiba userspace RIL residue present (1 hit(s))
FAIL: shiba 2 feature-permission XML(s) present for BT/NFC/Location
FAIL: shiba UNEXPECTED nitrous.ko loaded+unblocklisted — outside documented set [frankel blazer mustang rango]
RESULT: FAIL — at least one invariant violated or undocumented residual   (exit 1)
```

## Author suites — re-run and rematch (do not trust)

All re-runs from the repo root on 2026-09-24; raw output in `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/suite_*.out`.

| Suite | Exit | Result | Agreement / verdict |
|---|---|---|---|
| `verify_port_excision_matrix_static.sh` | **0** | 128 PASS / 0 HOLD / 0 FAIL (+ its own neg control exit 2) | **AGREE** — excision core (variant data-driven resolver, no silent no-op) intact. **Caveat:** it never exercises the blocklist *shipment* or location paths, so it does not detect the stamp-level defects below (`F-001/2/3` class). |
| `verify_port_kernel_matrix_static.sh` | **1** | 203 PASS / 3 HOLD / **5 FAIL** | **SUITE STALENESS, not a product defect.** All 5 FAILs are the operator's LAYER remedy (`device/google/{comet,tegu,shusky}-kernels/6.1/trunk-14096387`, symlinks created **2026-09-22 15:11**), which the suite asserts must be ABSENT. The excision product is green (`excision_matrix` 128/0). |
| `verify_port_matrix_preflight_static.sh` | **1** | RESULT: FAIL — "at least one attack succeeded"; 109 passed / 2 warnings | **SUITE STALENESS, same root cause** — the "4-absence" invariant is contradicted by the same LAYER symlinks. Not a product defect. |
| `verify_remediate_b2_excise_host.sh` | **0** | host PASS (55 pass / 4 HOLD) | **AGREE** — corroborates `E-13` (location lifecycle not FEATURE-gated; LMS start HOLD). |
| `verify_remediate_b2_apex_host.sh` | **1** | bash_PASS=33 / HOLD=6 / **PY_RC=1** | **REPRODUCED RED — attribution disputed.** The FAILs are **source-structural** (`devicelock-apex-excised.mk` filters `com.android.devicelock:service-devicelock` out of `PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS` → "SSR stripped — Zygote risk"), **not** an out/ staleness artefact. `E-11`'s "stale out/ precondition" reading is **not supported** by this run; escalate to `T-EXCISE-GATE-REVALIDATION` / `A-EXCISE-SURFACES`. |
| `vendor/guardtalk/scripts/verify-on-device.sh` | **HOLD** | not run | **HOLD — no adb/USB** (DEC-009). Script calls `adb wait-for-device`; running it without a device hangs. No on-device result claimed. |

## Findings (independent re-derivation, Law 7)

- **Q13-1 (HIGH) — `out/`-vs-stamp divergence on the 4 `laguna` devices.** The shipped
  `frankel`/`blazer`/`mustang`/`rango` stamps carry a **stock** `vendor_dlkm/lib/modules/modules.blocklist`
  (16/16/16/18 lines, **0** `nitrous`, **no** GuardTalk header), while the current
  `out/target/product/<dev>/vendor_dlkm/lib/modules/modules.blocklist` carries the **correct**
  variant blocklist (33 lines, header `laguna_muzel`, `blocklist nitrous` present). The same
  divergence holds for the radio-disable cmdline. Evidence: `out_vs_stamp_divergence.txt`
  (e.g. frankel out/ sha256 `ff1c568e…` vs stamp sha256 `110550f9…`). This **corroborates `E-10`**
  and shows the shipped stamps are not built from the currently-correct `out/` tree.
- **Q13-2 (MEDIUM) — `E-12` not reproduced at stamp level.** `androidboot.radio.disabled` is present
  in **9/13** shipped `vendor_boot.img` and **absent on `frankel`/`blazer`/`mustang`/`rango`**, while
  the corresponding `out/target/product/<dev>/vendor_boot.img` **do** contain it. `E-12`'s
  "13/13" holds only against `out/`, not against the shipped stamps. (Reported as a divergence,
  not a mitigation reversal.)
- **Q13-3 (INFO/refine) — `E-14` is 13/13, not 12/13.** The 8 GKI BT/NFC modules are in
  `system_dlkm/lib/modules/modules.load` with **0** matching blocklist entries on **all 13**
  stamps — including `tokay`, read from its authoritative global-`latest` stamp. Tier C/`FALSE`
  for BT is confirmed rather than softened.
- **Q13-4 (INFO) — `E-9` confirmed on stamps 13/13.** Location daemon stack present only on
  `shiba`/`husky`: `/bin/hw/{gpsd,lhd,scd}`, `init.gps.rc` services in `class main` with **no
  `disabled`**, `lib64/hw/gps.default.so`, `/etc/gnss/{gps.cer,gps.xml,lhd.conf,scd.conf}`.
- **Q13-5 (INFO) — `E-5` confirmed 13/13.** Zero BT/NFC/Location feature-permission XMLs in
  `product`/`system`/`vendor` `/etc/permissions/`.

## Residual register (operator-waiver surface — not "removed")

| Residual | Devices | Tier | Note |
|----------|---------|------|------|
| baseband firmware `radio.img`+`modem.img` present | 13/13 | B | `radio.img` in every stamp; `modem.img` in `out/` only (E-7b) |
| 8 GKI BT/NFC modules loaded, unblocklisted | 13/13 | C | `bluetooth/hci_uart/btbcm/btqca/btsdio/rfcomm/hidp/nfc` |
| `nitrous.ko` loaded, **unblocklisted** | 4/13 (`frankel`,`blazer`,`mustang`,`rango`) | C | E-10; blocklisted on the other 9 |
| location daemon stack (init-started) | 2/13 (`shiba`,`husky`) | C | E-9 |
| BT HAL still declared in vendor VINTF | 13/13 | B | F-003 |

## Honesty / holds

`LIVE_FLASH_CLAIMED=false`; no boot-green claim; DEC-009 on-device **HOLD**; `rango-latest`
untouched (`rango-20260802-130756`); no rebuild, no re-stamp, no commit; no production signing
material. **No product/flash/doctrine/governance file modified; no existing assertion weakened or
deleted; no USB/adb/fastboot.** `.agent-comm/inbox/TO_ARCHITECT.md` and the derived
`.agent-comm/TASK_QUEUE.md` were **not** touched. `Gate 5: HUMAN SKIP`.

## Artifacts written

| Artifact | Path |
|---|---|
| This report | `vendor/guardtalk/docs/qa/Q-EXCISE-13DEV-MATRIX_EVIDENCE.md` |
| Re-runnable harness | `vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh` |
| Real run output / matrix | `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/harness_real.out`, `matrix_real.tsv` |
| Negative-control output / matrix | `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/harness_negative.out`, `matrix_negative.tsv` |
| out/-vs-stamp divergence | `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/out_vs_stamp_divergence.txt` |
| Author-suite raw outputs | `.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX/suite_{excision_matrix,kernel_matrix,preflight,b2_excise,b2_apex}.out` |
| Durable event | `.agent-comm/history/2026-09-24T170500+0400-Q-EXCISE-13DEV-MATRIX.md` |
| Review signal | `.agent-comm/signals/review-Q-EXCISE-13DEV-MATRIX.json` |

Reproduce:

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh; echo "real exit=$?"
bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh --build-negative-fixture /tmp/gtq-mx-neg
GTQ_MX_MODE=fixture GTQ_MX_FIXTURE=/tmp/gtq-mx-neg GTQ_MX_DEVICES=shiba \
  bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh; echo "negative exit=$?"
```
