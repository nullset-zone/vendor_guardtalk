# Q-REMEDIATE-B6-FLASH-SOP — QA Evidence (independent parity + capture rematch)

- **Task:** `Q-REMEDIATE-B6-FLASH-SOP` (QA pair for `T-REMEDIATE-B6-FLASH-SOP`, DEC-012)
- **Role:** AEGIS QA Engineer (Panel 4)
- **DEC:** `DEC-REMEDIATE-019`
- **Authority:** owner-root `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md`
- **Repository:** `grapheneos-worktree`
- **Date:** 2026-09-19
- **Scope:** host-static only. **No USB, no flash, no lock, no wipe.**
- **USB_GO:** false · **FLASH_READY:** false · **commit:** none
- **Status:** REVIEW only (never APPROVED).
- **Gate -1:** in-process. Loaded `.aegis/governance/` — 24 laws
  (`laws/law_00..law_23`) + 11 gates (`gates/gate_neg1_guardian_first.yaml` +
  `gate_00..gate_09`). No `aegis-verifier` / `ask_guardian` / `gate_enforcer`
  MCP call. `governance_loaded=true`, `scope_confirmed=true`,
  `authority_context_resolved=true`.
- **Artifacts re-verified (not dump-trusted):**
  `vendor/guardtalk/docs/qa/T-REMEDIATE-B6-FLASH-SOP_EVIDENCE.md`,
  `…_SUITE.out`, `verify_remediate_b6_flash_sop_host.sh`.

---

## 0. Current true `cmp -s` state (the "phantom divergence")

| Check | Command | Result |
|-------|---------|--------|
| byte-identity | `cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh` | **exit 0 → IDENTICAL** |
| sha256 (root) | `sha256sum scripts/flash-from-remote.sh` | `2749e61f15a15f6ab81e667abdb2feca591f487cb388c1cced3af80c67b88439` |
| sha256 (vendor) | `sha256sum vendor/guardtalk/scripts/flash-from-remote.sh` | `2749e61f15a15f6ab81e667abdb2feca591f487cb388c1cced3af80c67b88439` |
| syntax | `bash -n` both copies | exit 0, both clean |
| size | `stat` | both `65303` bytes |

**Verdict: IDENTICAL**, sha256 matches the Architect-recorded value and the
Backend claim. The `T-REMEDIATE-B6-FASTBOOT-RC` `cmp -s DIFFERENT` claim is
**FALSE / stale** (mid-write read while the SOP lane was editing); not chased.
mtime: root `16:03:00Z`, vendor `16:08:03Z` (vendor copy written later; bytes
equal).

`bash -u -c 'set -euo pipefail; f(){ echo "$#"; }; f'` → prints `0`, exit 0.

---

## 1. Independent GrapheneOS parity re-derivation

Sources read **first-hand** (not from the Backend table):

- **GOS-gen** = `device/common/generate-factory-images-common.sh` (the file that
  *writes* `flash-all.sh`).
- **GOS-rel** = `script/generate-release.sh` (per-device flags).
- `device/common/clear-factory-images-variables.sh` (flag defaults).

**komodo flag derivation (independent):** GOS-rel L61 `elif [[ $DEVICE ==
@(…|komodo|…) ]]` → L62 `BOOTLOADER=…`, L63 `[[ $DEVICE != tangorpro ]] &&
RADIO=…`, L64 `DISABLE_UART=true`, L65 `DISABLE_FIPS=true`, L66
`DISABLE_DPM=true`. `AVB_PKMD` is set at L71. `clear-factory-images-variables.sh`
unsets `UNLOCKBOOTLOADER`, `TWINBOOTLOADERS`, `XLOADER`, `CDMARADIO`,
`ERASE_APDP`, `ERASE_MSADP`; `ERASEALL` is never set → apdp/msadp/eraseall/
xloader/twin/cdma branches are all **not** emitted for komodo.

GuardTalk script = `scripts/flash-from-remote.sh` (also `set -euo pipefail`, L78).

| # | GuardTalk step (lines) | GrapheneOS source (lines) | QA verdict |
|---|------------------------|---------------------------|------------|
| 1 | `require_fastboot_min_version` (L144–160; called L570) | `MIN_FASTBOOT_VERSION_STR="35.0.1"` (GOS-gen L98–99); version gate (L150–158) | **PASS** |
| 2 | product fail-closed `detect_product_fastboot` + `FB_NORM != FLASH_DEVICE` die (L599–604) | `getvar product` must equal `$DEVICE` (GOS-gen L162–169) | **PASS** (stricter) |
| 3 | dual-slot bootloader `flash_bootloader_ab_both_slots` (L351–374) | `flash --slot=other` → `--set-active=other` → `reboot-bootloader` → … → repeat (GOS-gen L193–198) | **PASS** |
| 4 | `reboot-bootloader` after bootloader pass (L370–373) | GOS-gen L207–208 | **PASS** (poll replaces `sleep 5`) |
| 5 | radio + `reboot-bootloader` (L720–727) | GOS-gen L213–215 | **PASS** |
| 6 | `erase avb_custom_key` → `flash avb_custom_key avb_pkmd.bin` (L734–746) | GOS-gen L229–230 | **PASS (order)** — see finding **Q-B6-SOP-2** |
| 7 | `oem uart disable` (L393–394) | GOS-gen L236; enabled GOS-rel L64 | **PASS** |
| 8 | `erase fips` (L396) | GOS-gen L256; enabled GOS-rel L65 | **PASS** |
| 9 | `erase dpm_a` + `erase dpm_b` (L398–401) | GOS-gen L262–263; enabled GOS-rel L66 | **PASS** |
| 10 | (absent) apdp/msadp | GOS-gen L239–251 (not enabled for komodo) | **PASS** |
| 11 | wipe `erase userdata` (L763) + `erase metadata` (L766) | `fastboot -w --skip-reboot update …` (GOS-gen L267) | **PASS** (metadata additive/intentional) |
| 12 | fastbootd logical: `flash super` or `wipe-super`+6 logicals (L1129–1158) | `update` reboots to fastbootd internally (GOS-gen L267) | **PASS** (intentional: no factory zip) |
| 13 | boot chain `boot/init_boot/vendor_boot/vendor_kernel_boot/pvmfw` + `dtbo` (L1174–1182) | `update` writes the same images (GOS-gen L267) | **PASS** (intentional) |
| 14 | single vbmeta pass `--disable-verity --disable-verification` (L1190–1197) | `update` writes vbmeta without flags (GOS-gen L267) | **PASS for komodo** — see finding **Q-B6-SOP-1** |
| 15 | final `reboot` + boot watch (L1211–1216) | `reboot-bootloader` (GOS-gen L268–269) | **PASS** (intentional) |
| 16 | boot-watch gap patched (opt-in capture) | GOS `flash-all` has no boot verification | **PASS (patched)** |
| 17 | no bootloader re-lock | public CLI process re-locks | **PASS** (intentional; userdebug sidecar) |

**No step's PASS verdict is disputed.** No SOP command-order divergence was
found in the firmware/bootloader/key prefix. The parity table is *functionally*
correct; its **completeness** against the audit-routed divergences is where my
findings land (§4).

---

## 2. Capture flag: opt-in and death-proof

**Opt-in — every guard (Read-verified):**

- L103 `CAPTURE_LOGS="${CAPTURE_LOGS:-0}"` → default **0**.
- L106 `CAPTURE_POST_ADB_SECS="${CAPTURE_POST_ADB_SECS:-120}"` (only honoured
  under `CAPTURE_LOGS=1`).
- L1008 `capture_dir_init` → `[[ "${CAPTURE_LOGS:-0}" == "1" ]] || return 0`.
- L1038 `capture_fastboot_snapshot`, L1061 `capture_adb_snapshot` → same guard.
- L1218/L1220 watch extension only under `CAPTURE_LOGS=1`.
- L1236 post-adb snapshot only under `CAPTURE_LOGS=1`.
- L1245–1250 keep-watching only under `CAPTURE_LOGS=1` (else `break` at first
  adb — **default path unchanged**).
- L1275 fallback capture only under `CAPTURE_LOGS=1`.
- L1285 post-adb "no fallback" log only under `CAPTURE_LOGS=1`.
- L1309 / L1348 / L1361 capture banner / final snapshot / capture path print
  only under `CAPTURE_LOGS=1`.

> Note: the Architect cited guards at ~L1008/1038/1061/1218. I confirm those and
> found the **additional** guards L1236/1245/1275/1285/1309/1348/1361. Full set
> above.

**Default-path invariance (empirical):** case **C2** (`CAPTURE_LOGS` truly
**unset**) reaches `GuardTalkOS flash complete!`, exit 0, no capture dir, no
fallback, no `CAPTURE_LOGS=1` log line. Case **C3** (`CAPTURE_LOGS=0`) output is
identical after normalizing the work-dir path (the only diff is the
`LOCAL_WORK_DIR` string embedded in two log lines — not behaviour).

**Death-proof — every capture call path (traced, then executed):**

| Symbol | Lines | Fatal paths? |
|--------|-------|--------------|
| `capture_dir_init` | L1007–1020 | none; `mkdir` wrapped in `if`; always `return 0` |
| `capture_run` | L1022–1032 | `if { "$@" ; } >"$out" 2>&1; then return 0; fi` → failure goes to `warn` + `return 0` |
| `capture_fastboot_snapshot` | L1035–1053 | only `capture_run` → always `return 0` |
| `capture_adb_snapshot` | L1058–1090 | `if ! "$ADB" shell true; then warn; return 0; fi`; prop loop guarded with `|| true`; always `return 0` |

Grep census: there is **no `die` call** anywhere from the capture block
(L999) to end of file — the only occurrence of the string is the comment at
L1003 ("Nothing here may `die()`"). The nearest real `die` calls after L990 are
L1107–1182, inside the flash/rango path, not in any capture region. Zero `die`
calls in L999–1363 (verified: `grep -nE '(^|[^a-zA-Z_])die\b' … | awk '$1>=999'`
→ 0). Every capture helper and every call site is `die`-free by construction.

**Post-adb fallback recorded (the real failure mode):** L1236–1240 snapshot on
first adb (`capture_adb_snapshot "adb-online-${i}s"`), L1245–1250 keep watching,
L1268–1277 detect the return to fastboot after adb and emit
`POST-ADB FALLBACK RECORDED` + `capture_fastboot_snapshot "fallback-${i}s"`.
Case **C4** proves it end-to-end (exit 2, dual transport files present).

**Documentation:** flag is in the script header (L48–66) **and** in
`vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` §"DEC-REMEDIATE-019" (L212–273;
7 `CAPTURE_LOGS` mentions, default `0`, evidence-dir pattern, safety section).
Both doc sections survive the shared-doc collision (L212 SOP + L275 FASTBOOT-RC).

---

## 3. Negative matrix — executed independently

Harness authored for this task:
`vendor/guardtalk/docs/qa/verify_remediate_b6_flash_sop_qa.sh`
(raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B6-FLASH-SOP_SUITE.out`).
It stubs `fastboot`/`adb`/`ssh`/`scp` and drives the **real** product script;
the product script is executed, never edited.

**Result: PASS=18 FAIL=0, exit 0.**

| Case | What it proves | Result |
|------|----------------|--------|
| C1a | empty positional-arg function under `set -u` does not abort | PASS |
| C1b | **the real `flash_vbmeta_img()` body**, extracted from the script with `awk`, executed under `set -euo pipefail` with **0 extra args** for `vbmeta_system`/`vbmeta_vendor` — no `unbound variable` | PASS |
| C2 | `CAPTURE_LOGS` **unset** → `flash complete`, exit 0, no capture dir, no fallback | PASS |
| C3 | `CAPTURE_LOGS=0` output == unset (normalized work-dir path); no capture dir/fallback | PASS |
| C4 | `CAPTURE_LOGS=1` post-adb fallback recorded, exit 2, **dual transport** (adb logcat + fastboot `oem dmesg`), no FATAL | PASS |
| C5 | capture with **missing adb transport** (`ADB=/nonexistent`): fastboot-only evidence written, no adb files, exit 2, no FATAL | PASS |
| C6 | capture with **fastboot capture commands failing** (`oem dmesg`/`oem bcd` exit 1): warning emitted, exit 2, **no FATAL** | PASS |
| C7 | capture with **`adb unauthorized`**: exit 0, `adb unauthorized` handled, no FATAL, no crash | PASS |
| C8 | capture when the device **never enumerates**: exit 3, no FATAL | PASS |
| C9 | capture with a **dead adb transport** (devices up, `shell` fails): adb snapshot skipped gracefully, fastboot fallback still captured, no FATAL | PASS |

**Independent re-run of the Backend harness** (`verify_remediate_b6_flash_sop_host.sh`):
`bash -n` clean; execution → **PASS=16 FAIL=0, exit 0** (matches the Backend
`SUITE.out`). Host bash is GNU bash 5.2.21; the `set -u` guard was additionally
proven against the *real* function body (C1b), not only by grep.

---

## 4. Findings (report-only; scope forbids patching the script here)

| ID | Sev | Finding |
|----|-----|---------|
| **Q-B6-SOP-1** | **MEDIUM** | Script header L40–41 still claims *"vbmeta is flashed ONCE … No duplicate mid-sequence vbmeta passes."* This is **false for the rango rescue path**, which flashes `vbmeta`/`vbmeta_system`/`vbmeta_vendor` mid-sequence at L866–868 before Step 7 (L1190–1197). Audit `A-REMEDIATE-B6-INCIDENT` explicitly required this to appear in the parity table; the table's row 14 is scoped to komodo and the divergence list mentions the rango rescue boot but **not** the false header claim. Documentation-honesty gap (Law 1 / Law 7). |
| **Q-B6-SOP-2** | LOW | The audit's divergence *"non-fatal `erase avb_custom_key`"* is still in the code (L735–736: `erase avb_custom_key \|\| warn …`) — GrapheneOS `flash-all.sh` runs under `set -e` (GOS-gen L148), so a failing erase aborts there. Table row 6 labelled PASS with basis "Same order", but did **not** record the leniency as an intentional divergence. Behaviour is safe (more permissive, not a regression); the table is incomplete. |
| **Q-B6-SOP-3** | LOW | Audit **MEDIUM-3** (`vbmeta_system.img`/`vbmeta_vendor.img` = copy-of-root-`vbmeta.img` aliasing — "decide/document **before the next signed-user pack**") is **not addressed** in the parity table. `flash_vbmeta_partition` (L184–192) correctly maps per-partition files, but whether the packed bundle aliases them is a stamp/build question the table never states. Open routing item — do not lose. |
| **Q-B6-SOP-4** | INFO | Confirmed Backend nit: Step 0b (L636) `STALE_COUNT=$(find "$LOCAL_WORK_DIR" … \| wc -l \| tr -d ' ')` aborts (exit 1, **no** `FATAL` line) under `set -euo pipefail` when `LOCAL_WORK_DIR` does not exist. I reproduced it directly: the `find` non-zero status + `pipefail` fails the assignment before the next line. **Not** a GrapheneOS SOP divergence — it is GuardTalk host pre-flight only, `LOCAL_WORK_DIR` defaults to `.` (L90) which exists, and the abort is **fail-safe** (before any flash command). Law 6 → do not patch. |
| **Q-B6-SOP-5** | INFO | Stale comment L660–663 ("use the full 8192-byte root vbmeta for all three partitions") contradicts the per-partition mapping in `flash_vbmeta_partition` (L184–192). Cosmetic; Backend flagged it; confirmed. |

No CRITICAL, no HIGH. No invented PASS; `FLASH_READY=false`, `komodo-latest`
untouched, no retarget, no `avb.pem`, no USB.

**Contradiction with the Backend lane:** none on `cmp`/`bash -n`/opt-in/death-proof
(all independently reproduced). The only disagreement is **completeness**: the
Backend parity table omits Q-B6-SOP-1/2/3, which the audit had routed to it.

---

## 5. HOLD (cannot be closed from this host)

- **On-device run** of the capture path: stubs prove control flow only; a real
  komodo flash (operator USB) is required to confirm `adb → fastboot` fallback
  capture against real `oem dmesg`/BCB/ramoops output. **HOLD.**
- **PASS HOLD remains**; `FLASH_READY=false`; no packing; no USB GO.
- Q-B6-SOP-1/2/3 documentation completeness and Q-B6-SOP-4 nit remain open
  (not patched in this task by scope).

---

## 6. Gate 5 (Ultimate Critique) — self-score

**Score: 92/100.**

| Dimension | Assessment |
|-----------|------------|
| Acceptance coverage | All QA acceptance items executed: independent GOS re-derivation (16 cited steps), `cmp`/`sha256`/`bash -n`, opt-in proof with full guard census, death-proof by trace + execution, negative matrix (all required cases, 18/18). |
| Independence | Re-derived from in-tree sources, not the Backend table; re-ran the Backend harness; wrote my own adversarial harness with the *real* `flash_vbmeta_img` body. |
| Honesty (Law 1/7) | Reported the current true `cmp` state and refused the phantom divergence; documented the table's completeness gaps rather than rubber-stamping; `FLASH_READY=false` stated. |
| Deductions | (**-4**) host-static only — no on-device confirmation is possible; (**-2**) my C3 equality is path-normalized (raw streams differ only by the embedded work-dir path, verified by diff); (**-2**) findings are report-only by scope, so the documentation gaps remain open for the Architect to route. |

Host-static, no commit, status **REVIEW** only.
