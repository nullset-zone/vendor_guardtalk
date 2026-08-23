# A-RANGO-BOOT-FINAL — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-FINAL` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T13:17:18Z |
| Depends on | `Q-RANGO-BOOT-FINAL` ✅ APPROVED CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used Architect Auditor conventions + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (`A-RANGO-BOOT-FINAL` DISPATCH authoritative) |
| Gate -1 | `ask_guardian` → compliant proceed (**Guardian Proxy fallback**); `gate_enforcer` Gate -1 **PASSED** |
| Mode | Read-only; no implementation edits; no git commit; no invent on-device PASS |
| Preserved | `TO_ARCHITECT_T-RANGO-BOOT-FINAL.md`, `TO_ARCHITECT_Q-RANGO-BOOT-FINAL.md`, `Q-RANGO-BOOT-FINAL_EVIDENCE.md` (untouched) |

---

## 2. Challenge answers (independent disk)

### C1 — Is tzdata graft + durable `gtuserspace` permanent enough, or still a factory-boot workaround?

**Staging-permanent YES; build-tree permanent NO; boot sufficiency UNPROVEN.**

| Layer | Assessment |
|-------|------------|
| Release staging | **Durable.** Default `MODE=gtuserspace` folds drop-virt + stock tzdata→runtime→i18n; `--link-latest` allowed; `rango-latest` → `130756`. Bisect modes refuse `--link-latest`. |
| GT build products | **Still workaround.** Bootstrap apexes are debugfs grafts from `rango-stock-userspace`; virt removed by `rm` on `system.img`, not by flipping `RELEASE_AVF_ENABLE_EARLY_VM` (still `true` in `trunk_staging`). |
| On-device proof | **HOLD.** Composition is the correct next fold after `123756` FAIL; it does **not** prove Android/adb. |

Honest framing in RCA/FIX/stamp README matches this: host-gated durable candidate; on-device PASS HOLD; next probes (stock `apexd` / bootstrap re-scan / user vs userdebug / VNDK) if still `0xfc`.

### C2 — Cite quality (`apexd.rc` / `kBootstrapApexes`) vs speculation?

**PASS — load-bearing cites verified in-tree.**

| Claim | Live cite | Auditor check |
|-------|-----------|---------------|
| `apexd-bootstrap` → bootloader | `system/apex/apexd/apexd.rc:18` `reboot_on_failure reboot,bootloader,bootstrap-apexd-failed` | Confirmed |
| `kBootstrapApexes` set | `system/apex/apexd/apexd.cpp:168–176` = i18n, runtime, tzdata, (+virt if `RELEASE_AVF_ENABLE_EARLY_VM`) | Confirmed |
| After `123756`, last named GT bootstrap | virt absent; runtime/i18n stock sizes; GT tzdata Size `962560` on `123756` | Confirmed by Size + history |
| Stock tzdata6 → manifest `com.android.tzdata` | `deapexer info` on grafted apex | `name: com.android.tzdata` v`361157000` MATCH stock tzdata6 |
| Graft bytes | `cmp` vs `rango-stock-userspace` | tzdata/runtime/i18n **PASS cmp** |

Named RC = GT tzdata as last *named* bootstrap still GT after `123756` is **reasoned host bisect**, not on-device-proven sole cause. Docs correctly leave residual probes if `130756` still `0xfc`.

### C3 — No script sprawl; latest policy; DONE honesty?

**PASS.**

```text
readlink -f releases/desktop-flash/rango-latest
→ …/rango-20260802-130756
PASS_not_fullgt
PASS_not_130338 (superseded dir exists; not linked)
virt.apex → File not found by ext2_lookup
tzdata Size 130756=921600 ≠ 123756=962560
runtime/i18n Size MATCH stock (8814592 / 37842944)
SHA256SUMS 22/22 OK
flash-*.sh → 5 KEEP only (no NEW)
adb devices → empty; ~/rango-dmesg-final.txt ABSENT → HOLD
```

Backend/QA status honesty: host DONE / device HOLD — **reproduced**. No invent PASS.

### C4 — DEC-012 pairing intact?

**PASS.**

```text
T-RANGO-BOOT-FINAL → Q-RANGO-BOOT-FINAL → A-RANGO-BOOT-FINAL
F = N/A
```

Both `.agent-comm/TASK_QUEUE.md` and root `TASK_QUEUE.md` carry the same T/Q/A chain; Architect APPROVED T (static HOLD) → APPROVED CONDITIONAL GO Q → dispatched A. Frontend N/A documented. Preserved T/Q reports left intact.

---

## 3. Host integrity (spot)

| Check | Result |
|-------|--------|
| SHA256SUMS `130756` | **22/22 OK** |
| Stock apex `cmp` | tzdata←tzdata6 / runtime / i18n **MATCH** |
| Q E2E log (`/tmp/q-rango-boot-final-e2e.log`) | 49 pass / 0 fail / 2 warn; DEVICE BOOT HOLD |
| tokay/akita | `akita-latest` OK; tokay stamp+SHA; `flash-tokay.sh` present |
| `RELEASE_AVF_ENABLE_EARLY_VM` (`trunk_staging`) | still `bool_value: true` (staging virt-drop only) |

E2E not re-run end-to-end this audit (Q log + disk spot checks sufficient; targets `rango-latest`→`130756`).

---

## 4. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | On-device sufficiency for `130756` is **HOLD** — unflashed on build host; do not treat durable staging as boot PASS. |
| F2 | **MEDIUM** | “Permanent” holds for **release staging** only. Factory-boot + stock bootstrap grafts remain a composition workaround until live adb PASS (and ideally GT rebuild: EARLY_VM off / compatible bootstrap apexes). Framing in RCA/FIX is honest; Architect should not close sprint as device DONE. |
| F3 | **LOW** | Stamp `README-FLASH-DESKTOP.md` still tees `~/rango-dmesg-deep.txt`; dispatch/operator path is `~/rango-dmesg-final.txt` (doc drift only). |

**BLOCK: 0 · MEDIUM: 2 · LOW: 1**

---

## 5. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: latest→`130756`, virt absent, stock bootstrap apex graft (cmp), durable `gtuserspace` fold, cites, no sprawl, DONE honesty, DEC-012 — **independently confirmed**.
- On-device boot of `130756` — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Operator Mac flash `rango-latest` (`130756`) via `flash-from-remote.sh` (unset `REMOTE_BUILD_DIR`) + immediate `oem dmesg` → `~/rango-dmesg-final.txt`.
2. On adb PASS: Architect may mark device DONE; consider `RELEASE_AVF_ENABLE_EARLY_VM=false` on next rebuild (DEC note).
3. On still-`0xfc`: residual beyond tzdata — stock `apexd` / bootstrap re-scan / user vs userdebug / VNDK (do not invent PASS).

---

## 6. Gate 5

| Source | Score |
|--------|--------|
| `self_critique` MCP | **97/100 PASS** (1 WARN: long response citations) |
| `ultimate_critique` MCP | TOOL often UNAVAILABLE (`python` missing) — manual Gate 5 |
| Manual Gate 5 | **94%** |

Manual deductions: device HOLD (expected), composition-vs-build permanence nuance (called out as MEDIUM, not hidden), README dmesg path LOW.

---

## 7. STOP

Auditor deliverables complete. Status **REVIEW**. Architect closes sprint.
