# A-RANGO-BOOT-DEEP — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-DEEP` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T11:35:00Z |
| Depends on | `Q-RANGO-BOOT-DEEP` ✅ APPROVED CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used `.aegis/templates/cursor-agents/aegis-auditor.md` + Architect Auditor conventions + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (DISPATCH authoritative) |
| Gate -1 | `ask_guardian` → compliant proceed (**Guardian Proxy fallback** — "Guardian unavailable - using local governance check"); `gate_enforcer` Gate -1 **PASSED** |
| Mode | Read-only; no implementation edits; no git commit/push; no invent on-device PASS |

---

## 2. Independent RC re-verify (apexd)

### 2.1 `apexd.rc`

```text
system/apex/apexd/apexd.rc:18
    reboot_on_failure reboot,bootloader,bootstrap-apexd-failed
```

Confirmed: service `apexd-bootstrap` (`/system/bin/apexd --bootstrap`) is the only early
`reboot_on_failure` target that specifies **bootloader** (matches `0xfc` /
`fastboot enter reason: reboot bootloader`). Repo-wide `reboot_on_failure.*bootloader`
hits only this line under `system/apex/apexd/apexd.rc`.

### 2.2 `apexd.cpp` EARLY_VM / `kBootstrapApexes`

```text
system/apex/apexd/apexd.cpp:168-176
  kBootstrapApexes includes "com.android.virt" under #ifdef RELEASE_AVF_ENABLE_EARLY_VM
```

`build/release/flag_values/trunk_staging/RELEASE_AVF_ENABLE_EARLY_VM.textproto`
→ `bool_value: true` (matches lunch `rango-trunk_staging-userdebug`).

### 2.3 OnBootstrap skip semantics (load-bearing)

`OnBootstrap()` (`apexd.cpp` ~2374–2386) walks **preinstalled** apexes and pushes
those for which `IsBootstrapApex()` is true. It does **not** hard-require every name
in `kBootstrapApexes` to exist. Staging comment
`missing ≠ hard-required` is **correct** — dropping
`/system/apex/com.android.virt.apex` removes it from the activation list.

---

## 3. Stamp / virt / latest / fullgt

| Check | Result |
|-------|--------|
| `readlink -f releases/desktop-flash/rango-latest` | `…/rango-20260802-111004` |
| Basename contains `fullgt` | **NO** |
| `rango-fullgt-20260801-072051` exists separately | YES (diagnostic only) |
| `debugfs` virt on `rango-latest` / `111004` | `File not found by ext2_lookup` |
| `debugfs` virt on `103641` | **PRESENT** (Size 61222912) |
| `debugfs` virt on `103554` | **PRESENT** |
| runtime / i18n / tzdata on `111004` and `103641` | all **PRESENT** on both |

**Composition delta 103641 → 111004 (apex set):** only `com.android.virt` removed.
README on `111004` matches disk (DROPPED virt + 0xfc class).

---

## 4. Staging link-latest policy (spot-check)

`vendor/guardtalk/scripts/stage-rango-release.sh`:

| MODE | `--link-latest` |
|------|-----------------|
| `gtuserspace` (default) | allowed |
| `stockbootstrap` / `stockbootapex` | **die** refuse |
| `hybrid` | **die** refuse |
| `fullgt` | **die** refuse |
| `avbcontrol` | **die** refuse |

Default MODE is `gtuserspace` (line 74), which applies `patch_drop_bootstrap_virt`.
**Never** links fullgt as latest by construction.

---

## 5. Host gates / Q evidence (independent)

```text
FASTBOOT=out/host/linux-x86/bin/fastboot bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
passes=49  fails=0  warns=2  E2E_EXIT=0
```

WARNs: optional `vendor_boot_diag.img` absent; no adb/fastboot device.
Log: `/tmp/a-rango-boot-deep-e2e.log`.

Negative matrix: only `scripts/flash-from-remote.sh`; classify messaging for
`0x7f00` vs `0xfc` present (~863–865). `adb devices` empty → on-device **HOLD**.

Q evidence file consistent with re-run: `vendor/guardtalk/docs/qa/Q-RANGO-BOOT-DEEP_EVIDENCE.md`.

---

## 6. Sufficiency challenge

### Q1 — Is virt-drop the only remaining *sufficient* explanation for intentional `reboot bootloader` / `0xfc` after stock-bootstrap bisect?

| Layer | Assessment |
|-------|------------|
| **Mechanism uniqueness** | **YES** — only `apexd-bootstrap` → bootloader. Intentional `0xfc` class is correctly named. |
| **Virt as *the* failing apex** | **LEADING, not sole-proven** — fail stamp `103641` has virt; candidate `111004` drops only virt among bootstrap apexes; activation of GT virt on factory `pvmfw` is the best-supported *leading* cause. |
| **Sufficiency closed?** | **NO (on-device)** — `111004` never flashed; residual apexd-bootstrap failures from GT `runtime`/`i18n`/`tzdata` (still present) remain **live** until operator `oem dmesg` after `111004` flash. |
| **Staging fix correctness** | Dropping virt is a *valid* minimal intervention given OnBootstrap skip semantics; durable follow-up still needs `RELEASE_AVF_ENABLE_EARLY_VM=false` on rebuild (Backend note — not audited as implemented). |

**Auditor position:** Virt-drop is the **only remaining sufficient *staging* lever** that distinguishes the known-fail bisect from the durable candidate **on disk**. It is **not** yet a sufficient *proof* that apexd-bootstrap will exit 0 on device.

### Q2 — memtag / dlkm / bootstrap-only hypotheses

| Hypothesis | Status for *current* `0xfc` class |
|------------|-----------------------------------|
| MTE / `.note.android.memtag` → ENOEXEC → `0x7f00` | **Correctly closed** for intentional bootloader reboot. Still gated in E2E §7. Do not re-open without new evidence. |
| dlkm vermagic / second-stage modules | **Correctly closed** as explanation for ~18s `0xfc`. H5 remains HOLD for *post*-apexd hangs only. |
| Bootstrap-only (stock linker as sole fix) | **Correctly closed** as sole cause — `103641` (stock bootstrap + virt kept) still hit `0xfc`. Stock bootstrap remains part of `111004` composition (necessary for escaping historical `0x7f00`, not sufficient alone). |

---

## 7. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | Bisect READMEs `rango-20260802-103641` / `103554` omit virt/0xfc composition; still narrate 0x7f00 bootstrap-libc hypothesis. Disk virt **present** matches Backend claim, but README ≠ RCA §1.0. |
| F2 | **MEDIUM** | `RANGO_BOOT_FIX.md` §1.1 still lists `hybrid` as default and may-relink-latest; script default is `MODE=gtuserspace`. §1.2 still shows stale `rango-20260801-071754` as latest. |
| F3 | **MEDIUM** | Root-cause *sufficiency* for virt as sole apexd-bootstrap failer is **on-device HOLD** — do not treat static naming as live boot proof. |
| F4 | **LOW** | `RANGO_BOOT_RCA.md` §2.1 still shows `rango-latest` → `rango-hybrid-20260731-060108` (stale measurement block); §1.0 header is current. |
| F5 | **LOW** | MCP `ultimate_critique` unavailable (`python: not found` on verifier host) — Gate 5 scored manually below. |

**BLOCK: 0 · MEDIUM: 3 · LOW: 2**

---

## 8. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: RC mechanism, stamp composition, not-fullgt latest, staging refuse policy, host E2E — **independently confirmed**.
- On-device boot + sole-cause virt proof — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Operator flash `rango-latest` (`111004`) + immediate `fastboot oem dmesg`; classify residual `0xfc` vs later fail vs adb PASS.
2. Doc hygiene: refresh `103641`/`103554` READMEs + FIX §1.1/§1.2 + RCA §2.1 to match disk (Backend or Architect-owned doc task).

---

## 9. Gate 5

| Source | Score |
|--------|-------|
| MCP `ultimate_critique` | **UNAVAILABLE** (`python: not found`) |
| Manual Gate 5 (0–10 × 10) | acceptance 10, independence 10, scope 10, no invent PASS 10, RC disk re-verify 10, stamp/latest checks 10, sufficiency challenge honesty 9, docs drift caught 8, audit trail 9, residual device gap 6 → **92%** |

---

## 10. Commands re-executed

```bash
readlink -f releases/desktop-flash/rango-latest
debugfs -R "stat /system/apex/com.android.virt.apex" releases/desktop-flash/rango-latest/system.img
rg -n "bootstrap-apexd-failed|kBootstrapApexes|EARLY_VM|com.android.virt" system/apex/apexd/apexd.rc system/apex/apexd/apexd.cpp
rg -n "patch_drop_bootstrap_virt|stockbootstrap|link-latest|fullgt" vendor/guardtalk/scripts/stage-rango-release.sh | head -40
FASTBOOT=out/host/linux-x86/bin/fastboot bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
```
