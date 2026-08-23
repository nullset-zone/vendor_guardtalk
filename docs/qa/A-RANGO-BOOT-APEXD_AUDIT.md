# A-RANGO-BOOT-APEXD — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-APEXD` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T13:35:00Z |
| Depends on | `Q-RANGO-BOOT-APEXD` ✅ APPROVED CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used Architect Auditor conventions + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (`A-RANGO-BOOT-APEXD` DISPATCH authoritative) |
| Gate -1 | `ask_guardian` → compliant proceed (**Guardian Proxy fallback**); `gate_enforcer` Gate -1 **PASSED** |
| Mode | Read-only; no implementation edits; no git commit; no invent on-device PASS |
| Preserved | `TO_ARCHITECT_T-RANGO-BOOT-APEXD.md`, `TO_ARCHITECT_Q-RANGO-BOOT-APEXD.md`, `Q-RANGO-BOOT-APEXD_EVIDENCE.md` (untouched) |

---

## 2. Challenge answers (independent disk)

### C1 — Stock apexd graft correctly staged and not prematurely promoted?

**PASS — staged bisect; not promoted.**

| Check | Result |
|-------|--------|
| Stamp `rango-20260802-132759` | present + `system.img` + SHA256SUMS + README (`MODE=stockapexd`) |
| `debugfs dump` stamp `/system/bin/apexd` vs `rango-stock-userspace` | **`apexd_stock_MATCH`** size **1083368** (`cmp -s`) |
| stamp apexd vs `130756` | **DIFFERS** (1083368 ≠ 1030416) |
| `/system/etc/init/apexd.rc` stamp vs stock / vs `130756` | **MATCH** both (binary-only graft confirmed) |
| virt.apex on `132759` | `File not found by ext2_lookup`; no virt in `/system/apex` ls |
| `rango-latest` | → `rango-20260802-130756` (**not** `132759`, **not** fullgt) |
| `MODE=stockapexd … --link-latest` | refuse exit **1** |

Stock apexd is behind refuse-`--link-latest` bisect mode; durable `gtuserspace` latest unchanged until on-device PASS.

### C2 — Residual RC framing honest given `132759` unflashed?

**PASS — framing honest; sufficiency UNPROVEN.**

- Named residual after `130756` FAIL: GT `/system/bin/apexd` ≠ stock (sizes + `cmp`) — **disk-confirmed**.
- Cite `system/apex/apexd/apexd.rc:18` `reboot_on_failure reboot,bootloader,bootstrap-apexd-failed` — **live-confirmed**.
- RCA/FIX/stamp README correctly treat stock apexd as **host-staged bisect**, not proven cure.
- On-device for `132759`: **HOLD** (`adb devices` empty; `~/rango-dmesg-apexd.txt` absent). Do **not** invent PASS.
- If still `0xfc` after Mac flash: ordered next probes (hwasan / SELinux / `perform_apex_config` / user vs userdebug) remain open — docs match.

### C3 — No script sprawl / latest policy?

**PASS.**

```text
readlink -f releases/desktop-flash/rango-latest
→ …/rango-20260802-130756
latest_still_130756_PASS
PASS_not_132759_as_latest
PASS_not_fullgt
MODE=stockapexd --link-latest → exit 1
flash-*.sh → 5 KEEP only (no NEW)
SHA256SUMS 132759 → 22/22 OK
bash -n stage-rango-release.sh → PASS
Q E2E log → 49 pass / 0 fail / 2 warn; bundle=132759; DEVICE BOOT HOLD
akita-latest → akita-20260725-101434; tokay stamp + flash-tokay.sh OK
```

### C4 — DEC-012 intact?

**PASS (pairing); MEDIUM on dual-queue flash-block drift (see F2).**

```text
T-RANGO-BOOT-APEXD → Q-RANGO-BOOT-APEXD → A-RANGO-BOOT-APEXD
F = N/A
```

Both `.agent-comm/TASK_QUEUE.md` and root `TASK_QUEUE.md` carry the same T/Q/A chain; Architect APPROVED T (static HOLD) → APPROVED CONDITIONAL GO Q → dispatched A. Frontend N/A. Preserved T/Q reports left intact.

---

## 3. Host integrity (spot)

| Check | Result |
|-------|--------|
| SHA256SUMS `132759` | **22/22 OK** |
| Stock apexd `cmp` | **MATCH** 1083368 |
| apexd.rc `cmp` | MATCH stock + MATCH `130756` |
| Q E2E log (`/tmp/q-rango-boot-apexd-e2e.log`) | 49/0/2; DEVICE BOOT HOLD; bundle path `132759` |
| tokay/akita | non-regress OK |
| adb / dmesg-apexd | empty / absent → **HOLD** |

E2E not re-run end-to-end this audit (Q log + independent disk spot checks sufficient).

---

## 4. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | On-device sufficiency for `132759` is **HOLD** — unflashed on build host; residual “stock apexd cures `0xfc`” remains unproven. Do not treat host MATCH as boot PASS. |
| F2 | **MEDIUM** | Dual-queue operator flash drift: root `TASK_QUEUE.md` still `unset REMOTE_BUILD_DIR` (would flash durable FAIL `130756` via `rango-latest`). `.agent-comm/TASK_QUEUE.md` correctly pins `REMOTE_BUILD_DIR=…/132759`. Architect should sync root queue before Mac flash. |
| F3 | **LOW** | Stamp `README-FLASH-DESKTOP.md` tees `~/rango-dmesg-apex.txt`; dispatch/QA/operator path is `~/rango-dmesg-apexd.txt` (doc drift only). |
| F4 | **LOW** | E2E banner still says “rango-latest” when `BUNDLE` overrides — cosmetic; step-0 log shows `132759` correctly (QA LOW reproduced). |

**BLOCK: 0 · MEDIUM: 2 · LOW: 2**

---

## 5. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: stamp `132759` stock apexd graft (`cmp`), virt absent, latest stays `130756`, `--link-latest` refuse, SHA 22/22, no sprawl, residual RC honesty, DEC-012 T→Q→A — **independently confirmed**.
- On-device boot of `132759` — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Sync root `TASK_QUEUE.md` operator block to pin `REMOTE_BUILD_DIR=…/rango-20260802-132759` (match `.agent-comm`).
2. Operator Mac flash **only** via `REMOTE_BUILD_DIR=…/132759` + immediate `oem dmesg` → `~/rango-dmesg-apexd.txt`.
3. On adb PASS: fold stock apexd into durable `gtuserspace` + `--link-latest` (Architect-gated).
4. On still-`0xfc`: next probes per RCA (hwasan / SELinux / `perform_apex_config` / user vs userdebug) — do not invent PASS.

---

## 6. Gate 5

| Source | Score |
|--------|--------|
| `self_critique` MCP | **97/100 PASS** (1 WARN: long response citations) |
| `ultimate_critique` MCP | TOOL UNAVAILABLE (`python` not found) — manual Gate 5 |
| Manual Gate 5 | **94%** |

Manual deductions: device HOLD (expected), dual-queue flash drift MEDIUM (called out, not hidden), README/E2E LOWs.

---

## 7. STOP

Auditor deliverables complete. Status **REVIEW**. Architect closes sprint.
