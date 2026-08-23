# A-RANGO-BOOT-INIT — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-INIT` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T14:50:00Z |
| Depends on | `Q-RANGO-BOOT-INIT` ✅ APPROVED CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Stamp | `rango-20260802-141438` (`MODE=stockinit`) |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used Architect Auditor conventions + prior `A-RANGO-BOOT-*_AUDIT.md` pattern + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (`A-RANGO-BOOT-INIT` DISPATCH; `audit_scope: full`) |
| Gate -1 | MCP `ask_guardian` initially disconnected → **Guardian HTTP proxy fallback** (`curl` exit 0; aegis `score:100`, `blocked:false`); `gate_enforcer` Gate -1 **PASSED** with evidence; Architect DISPATCH = Law 0 |
| Gate 5 | `self_critique` MCP **97/100 PASS** (session `gate_enforcer` Gate 5 blocked by prior gate order — content critique satisfied) |
| Mode | Read-only; no implementation edits; no git commit; no invent on-device PASS; no stage new `MODE=` |
| Preserved | `TO_ARCHITECT_T-RANGO-BOOT-INIT.md`, `TO_ARCHITECT_Q-RANGO-BOOT-INIT.md`, `Q-RANGO-BOOT-INIT_EVIDENCE.md` (untouched) |

---

## 2. Residual RC after stock init + stock apexd + named bootstrap apexes

### Composition under audit (`141438` / `MODE=stockinit`)

| Layer | Host evidence | Status |
|-------|---------------|--------|
| `/system/bin/init` | `cmp` vs `rango-stock-userspace` → **MATCH** size **2771368** | grafted |
| `/system/bin/apexd` | `cmp` vs stock → **MATCH** size **1083368**; `cmp` vs `132759` → **MATCH** | retained from stockapexd |
| `/system/bin/init` vs prior GT | vs `132759`/`130756` → **DIFFERS** (2771368 ≠ 2938144) | bisect delta confirmed |
| Named bootstrap apexes | runtime **8814592** / i18n **37842944** / tzdata **921600** (stock sizes on stamp) | durable gtuserspace fold |
| `com.android.virt.apex` | `File not found by ext2_lookup`; absent from `/system/apex` ls | dropped |
| Failure class (historical) | `apexd-bootstrap` → `reboot_on_failure reboot,bootloader,bootstrap-apexd-failed` → `0xfc` | cite live |

**Cite (load-bearing):** `system/apex/apexd/apexd.rc:18` —

```text
reboot_on_failure reboot,bootloader,bootstrap-apexd-failed
```

`kBootstrapApexes` defined at `system/apex/apexd/apexd.cpp:168`.

### Falsified sole causes (do not re-open)

| Stamp / claim | On-device result | Auditor stance |
|---------------|------------------|----------------|
| `130756` novirt + stock named apexes (tzdata-sole) | FAIL `0xfc` ~18s | **falsified** |
| `132759` stock apexd on that composition | FAIL `0xfc` ~18s | **falsified** |
| `141438` stock init + stock apexd + same composition | **unflashed** | sufficiency **UNPROVEN** |

### Residual RC framing (honest)

Host staging of stock **init** onto the stockapexd composition is the correct next bisect after `132759` FAIL (disk: GT init ≠ stock while apexd MATCH). This does **not** prove that stock init cures `apexd-bootstrap` non-zero exit.

If operator later flashes `141438` and still sees `0xfc` / `reboot bootloader` ~18s, then **binary init + binary apexd + named stock bootstrap apexes + novirt is insufficient**. Residual moves past those binaries into:

1. **`perform_apex_config` / ActivatePackage path** inside bootstrap
2. **hwasan / native deps** (e.g. `libclang_rt.hwasan-*` for runtime)
3. **SELinux** early-apex / restorecon / domain transitions
4. **VNDK / `user` vs `userdebug`** product mismatch
5. **Early userspace beyond grafted binaries** (remaining GT apex set `com.android.*` vs stock `com.google.*`, init `.rc` surface already partially stripped per stamp README)

**Do not stage** those probes in this audit. Document only.

---

## 3. Challenge answers (independent disk)

### C1 — Stock init graft correctly staged; not prematurely promoted?

**PASS — staged bisect; not promoted.**

| Check | Result |
|-------|--------|
| Stamp `rango-20260802-141438` | present + `system.img` + SHA256SUMS + README (`MODE=stockinit`) |
| `debugfs dump` + `cmp` init vs stock | **`init_stock_MATCH`** 2771368 |
| `cmp` apexd vs stock / vs `132759` | **MATCH** 1083368 |
| `cmp` init vs `132759` | **DIFFERS** (2771368 ≠ 2938144) |
| virt.apex | absent |
| `rango-latest` | → `rango-20260802-130756` (**not** `141438`, **not** fullgt) |
| `MODE=stockinit … --link-latest` | refuse exit **1** (QA + stage script lines 1180–1181) |

### C2 — Residual RC framing honest given `141438` unflashed?

**PASS — framing honest; sufficiency UNPROVEN.**

- Named residual after `132759` FAIL: GT `/system/bin/init` ≠ stock — **disk-confirmed** (`init_vs_132759_DIFF`).
- RCA/FIX/stamp README treat stock init as **host-staged bisect**, not proven cure.
- On-device for `141438`: **HOLD** (`adb devices` empty; no live `~/rango-dmesg-init*.txt` with flash evidence). Do **not** invent PASS.
- Ordered next probes if still `0xfc` documented in §2 / §6 — not staged.

### C3 — Flash path integrity; no script sprawl; latest policy?

**PASS.**

```text
readlink -f releases/desktop-flash/rango-latest
→ …/rango-20260802-130756
latest_still_130756_PASS
PASS_not_141438_as_latest
PASS_not_fullgt
MODE=stockinit --link-latest → refuse (bisect)

flash-*.sh → 5 KEEP only (no NEW):
  scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote-signed.sh
  vendor/guardtalk/scripts/flash-signed.sh
  vendor/guardtalk/scripts/flash-tokay.sh

Operator bisect path: flash-from-remote.sh + REQUIRED REMOTE_BUILD_DIR=…/141438
SHA256SUMS 141438 → 22/22 OK
Q E2E log → 49 pass / 0 fail / 2 warn; bundle=141438; DEVICE BOOT HOLD
akita-latest → akita-20260725-101434; tokay stamp + flash-tokay.sh OK
```

### C4 — DEC-012 / pairing intact?

**PASS.**

```text
T-RANGO-BOOT-INIT → Q-RANGO-BOOT-INIT → A-RANGO-BOOT-INIT
F = N/A
```

Both `.agent-comm/TASK_QUEUE.md` and root `TASK_QUEUE.md` carry the same T/Q/A chain; Architect APPROVED T (static HOLD) → APPROVED CONDITIONAL GO Q → dispatched A. Frontend N/A. Preserved T/Q reports left intact. Operator flash blocks both pin `REMOTE_BUILD_DIR=…/141438`.

---

## 4. Host integrity (spot)

| Check | Result |
|-------|--------|
| SHA256SUMS `141438` | **22/22 OK** |
| Stock init `cmp` | **MATCH** 2771368 |
| Stock apexd `cmp` | **MATCH** 1083368 |
| virt | absent |
| Q E2E log (`/tmp/q-rango-boot-init-e2e.log`) | 49/0/2; DEVICE BOOT HOLD; bundle path `141438` |
| tokay/akita | non-regress OK |
| adb / dmesg-init | empty / no flash evidence → **HOLD** |

E2E not re-run end-to-end this audit (Q log + independent disk `cmp` / SHA / latest spot checks sufficient).

---

## 5. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | On-device sufficiency for `141438` is **HOLD** — unflashed on build host; residual “stock init cures `0xfc`” remains unproven. Do not treat host MATCH as boot PASS. |
| F2 | **MEDIUM** | If `141438` later FAIL `0xfc`, sole-cause space for init/apexd/named-bootstrap/tzdata/virt is exhausted — Architect must open a **new** probe sprint (do not silently fold into durable `gtuserspace`). |
| F3 | **LOW** | Stamp `README-FLASH-DESKTOP.md` tees `~/rango-dmesg-apex.txt`; queue/operator path is `~/rango-dmesg-init.txt` (doc drift only). |
| F4 | **LOW** | E2E RESULT banner still says “rango-latest” when `BUNDLE` overrides — cosmetic; step-0/bundle path shows `141438` (QA WARN class). |

**BLOCK: 0 · MEDIUM: 2 · LOW: 2**

---

## 6. Ordered next probes (if `141438` later FAIL `0xfc`)

Document only — **do not stage** in this audit:

| Order | Probe | Why |
|------:|-------|-----|
| 1 | `perform_apex_config` / ActivatePackage bootstrap path | Binary apexd MATCH stock but config/activation may still fail |
| 2 | hwasan / `libclang_rt.hwasan-*` native deps | Prior APEXD DEC noted runtime hwasan dependency risk |
| 3 | SELinux early-apex (domains, restorecon `/metadata`, file contexts) | Stamp already restores `/metadata` before apexd-bootstrap; residual policy still open |
| 4 | VNDK / `user` vs `userdebug` product surface | GT userspace vs factory kernel/dlkm pairing |
| 5 | Broader early userspace (remaining GT `com.android.*` apex set vs stock Google apexes; init.rc surface) | Beyond grafted init/apexd binaries |

Capture: `fastboot oem dmesg | tee ~/rango-dmesg-init-141438.txt` immediately on FAIL.

---

## 7. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: stamp `141438` stock init + stock apexd graft (`cmp`), virt absent, latest stays `130756`, `--link-latest` refuse, SHA 22/22, flash path = `flash-from-remote.sh` only (no sprawl), residual RC honesty, DEC-012 T→Q→A — **independently confirmed**.
- On-device boot of `141438` — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Operator Mac flash `141438` via `flash-from-remote.sh` with **pinned** `REMOTE_BUILD_DIR=…/141438` (do **not** unset — that flashes durable FAIL `130756` via `rango-latest`) + immediate `oem dmesg` → `~/rango-dmesg-init-141438.txt`.
2. On adb PASS: Architect may promote composition into durable `gtuserspace` / reconsider `rango-latest` (human decision).
3. On still-`0xfc`: open next probe sprint per §6 — do not invent PASS; do not re-attribute to stock-apexd-sole or tzdata-sole.

---

## 8. Gate 5

| Source | Score |
|--------|--------|
| `self_critique` MCP | **97/100 PASS** (1 WARN: long response citations) |
| Manual Gate 5 | **94%** |

Manual deductions: device HOLD (expected), residual-probe openness called out as MEDIUM not hidden, README dmesg path LOW.

---

## 9. STOP

Auditor deliverables complete. Status **REVIEW**. Architect closes sprint.
