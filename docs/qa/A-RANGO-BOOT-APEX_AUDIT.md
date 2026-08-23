# A-RANGO-BOOT-APEX — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-APEX` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T12:48:00Z |
| Depends on | `Q-RANGO-BOOT-APEX` ✅ APPROVED CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used `.windsurf/workflows/aegis-auditor(internal).md` + Architect Auditor conventions + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (DISPATCH authoritative) |
| Gate -1 | `ask_guardian` → compliant proceed (**Guardian Proxy fallback**); `gate_enforcer` Gate -1 **PASSED** |
| Mode | Read-only; no implementation edits; no git commit; no invent on-device PASS |
| Preserved | `TO_ARCHITECT_T-RANGO-BOOT-APEX.md`, `TO_ARCHITECT_Q-RANGO-BOOT-APEX.md`, `Q-RANGO-BOOT-APEX_EVIDENCE.md` (untouched) |

---

## 2. Challenge answers (independent disk)

### C1 — Staging composition of `123756` matches README (novirt + stock runtime/i18n)?

**YES.**

| Artifact | `123756` | `111004` (novirt FAIL) | Stock userspace |
|----------|----------|------------------------|-----------------|
| `com.android.virt.apex` | absent (`ext2_lookup`) | absent | absent |
| `com.android.runtime.apex` Size | **8814592** | 5222400 | **8814592** MATCH |
| `com.android.i18n.apex` Size | **37842944** | 20779008 | **37842944** MATCH |
| `com.android.tzdata.apex` Size | 962560 | 962560 | (GT kept; identical) |

Stamp README (`README-FLASH-DESKTOP.md`) claims: DROPPED virt; STOCK runtime+i18n; GT tzdata kept — **matches disk**.
mtime on runtime/i18n inodes (`2-Aug-2026 12:37`) aligns with staging window.

### C2 — Latest-policy / `--link-latest` refuse intact?

**YES.**

```text
readlink -f releases/desktop-flash/rango-latest
→ …/rango-20260802-111004
PASS_not_123756
PASS_not_fullgt

MODE=novirtstockapex ./vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
→ ERROR: MODE=novirtstockapex is a bisect stamp — refuse --link-latest …
REFUSE_EXIT=1
latest unchanged after refuse
```

Script case at ~1006–1008 dies before `stage_gtuserspace` when `LINK_LATEST=1`.
Bisect README uses `REMOTE_BUILD_DIR=…/rango-20260802-123756` (not `rango-latest`).

### C3 — Residual RC framing honest given `123756` unflashed?

**YES.**

- RCA/FIX/stamp README: `111004` on-device **FAIL** `0xfc` ~18s; virt-drop **insufficient**; `123756` staged with on-device **HOLD**.
- No agent claimed on-device PASS for `123756`.
- Residual after this bisect (if still `0xfc`) correctly named: GT `tzdata` / `apexd` itself.
- Auditor on-device re-check: `adb devices` empty; `~/rango-dmesg-apex.txt` **absent**.

### C4 — BLOCK making promote of `123756` unsafe *even after* operator PASS?

**NO BLOCK.** After live `adb` PASS on this stamp, folding stock runtime/i18n into durable `MODE=gtuserspace` + `--link-latest` is the designed path. Premature promote remains correctly refused.

---

## 3. Host integrity (spot)

| Check | Result |
|-------|--------|
| SHA256SUMS `123756` | **22/22 OK** EXIT=0 |
| Q E2E log (`/tmp/q-rango-boot-apex-e2e.log`) | 49 pass / 0 fail / 2 warn; DEVICE BOOT HOLD |
| `flash-from-remote.sh` bisect note | present (`keep REMOTE_BUILD_DIR`) |

E2E not re-run end-to-end this audit (targets `rango-latest`→`111004` by design); Q log consistent with prior APPROVED CONDITIONAL GO.

---

## 4. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | On-device sufficiency for residual `0xfc` after stock runtime/i18n graft is **HOLD** — `123756` unflashed; do not treat static composition as boot proof. |
| F2 | **MEDIUM** | GT `tzdata` (962560) still present on `123756` (= `111004`). Framing is honest, but if operator still sees `0xfc` after flash, next residual is live (tzdata / apexd) — not a promote-after-PASS blocker. |
| F3 | **LOW** | Host E2E exercises `rango-latest`→`111004`, not the bisect stamp path (documented; operator must use `REMOTE_BUILD_DIR`). |
| F4 | **LOW** | `virt.apex` absence alone is non-distinctive vs `111004`; load-bearing proof is runtime/i18n Size **MATCH stock**. |

**BLOCK: 0 · MEDIUM: 2 · LOW: 2**

---

## 5. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: novirtstockapex composition, latest policy, refuse `--link-latest`, honest residual RC — **independently confirmed**.
- On-device boot of `123756` — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Operator Mac flash `REMOTE_BUILD_DIR=…/rango-20260802-123756` + immediate `fastboot oem dmesg` → `~/rango-dmesg-apex.txt`.
2. On adb PASS: fold stock runtime/i18n into durable `gtuserspace` then `--link-latest` (Backend).
3. On still-`0xfc`: next residual = GT tzdata / apexd (do not promote).

---

## 6. Gate 5

| Source | Score |
|--------|-------|
| MCP `self_critique` | **97/100 PASS** |
| MCP `ultimate_critique` | **UNAVAILABLE** (`python: not found` — known from prior audits) |
| Manual Gate 5 | independence 10, no invent PASS 10, composition re-verify 10, latest/refuse 10, RC honesty 10, promote-after-PASS challenge 9, device gap 6, dual-queue discipline 9 → **94%** |

---

## 7. Commands re-executed

```bash
readlink -f releases/desktop-flash/rango-latest
debugfs -R "stat /system/apex/com.android.virt.apex" releases/desktop-flash/rango-20260802-123756/system.img
debugfs -R "stat /system/apex/com.android.runtime.apex" …/{123756,111004,rango-stock-userspace}/system.img
debugfs -R "stat /system/apex/com.android.i18n.apex" …/{123756,111004,rango-stock-userspace}/system.img
MODE=novirtstockapex bash vendor/guardtalk/scripts/stage-rango-release.sh --link-latest  # EXIT=1
(cd releases/desktop-flash/rango-20260802-123756 && sha256sum -c SHA256SUMS)  # 22/22 OK
adb devices  # empty
```
