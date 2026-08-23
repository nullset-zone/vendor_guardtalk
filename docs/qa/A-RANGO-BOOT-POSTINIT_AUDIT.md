# A-RANGO-BOOT-POSTINIT — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-POSTINIT` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T15:12:34Z |
| Depends on | `Q-RANGO-BOOT-POSTINIT` ✅ APPROVED host/static CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Stamp | `rango-20260802-150440` (`MODE=stockapexcfg`) |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used prior `A-RANGO-BOOT-*_AUDIT.md` pattern + Architect DISPATCH + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (`A-RANGO-BOOT-POSTINIT` DISPATCH; `audit_scope: full`) |
| Gate -1 | MCP `ask_guardian` → compliant (Guardian Proxy fallback); `gate_enforcer` Gate -1 **PASSED** with evidence; Architect DISPATCH = Law 0 |
| Gate 5 | `self_critique` MCP (see §8) |
| Mode | Read-only; no implementation edits; no git commit; no invent on-device PASS; no stage new `MODE=` |
| Preserved | `TO_ARCHITECT_T-RANGO-BOOT-POSTINIT.md`, `TO_ARCHITECT_Q-RANGO-BOOT-POSTINIT.md`, `Q-RANGO-BOOT-POSTINIT_EVIDENCE.md` (untouched) |

---

## 2. Residual RC after stockapexd + GT init + stock init.rc

### Composition under audit (`150440` / `MODE=stockapexcfg`)

| Layer | Host evidence | Status |
|-------|---------------|--------|
| `/system/bin/init` | `cmp` vs `132759` / `130756` → **MATCH** size **2938144** (GT retained) | intentional |
| `/system/bin/init` vs stock / `141438` | **DIFFERS** (2938144 ≠ 2771368) | stock-init-sole FALSIFIED — not re-grafted |
| `/system/bin/apexd` | `cmp` vs stock / `132759` / `141438` → **MATCH** size **1083368** | stockapexd retained |
| `/system/etc/init/hw/init.rc` | `cmp` vs stock → **MATCH** size **57115**; vs GT stamps `58090` → **DIFFERS** | **bisect delta** |
| `/system/etc/init/apexd.rc` | `cmp` vs stock → **MATCH** size **1322** | retained |
| Named bootstrap apexes | runtime / i18n / tzdata stock sizes (durable gtuserspace fold) | unchanged |
| `com.android.virt.apex` | `File not found by ext2_lookup`; absent from `/system/apex` ls | dropped |

### Load-bearing RC cites (disk)

Stamp `init.rc` contains early bootstrap path:

```text
exec_start apexd-bootstrap
perform_apex_config
```

`system/apex/apexd/apexd.rc:18` (matches stamp `apexd.rc`):

```text
reboot_on_failure reboot,bootloader,bootstrap-apexd-failed
```

### Fail-class taxonomy (bound — do not invent)

| Class | Signal | Bound meaning | Exemplar |
|-------|--------|---------------|----------|
| `0xfc` | `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` ~18s | apexd-bootstrap `reboot_on_failure` | `130756`, `132759` |
| `0x00000100` | KP `exitcode=0x00000100` / `0xbaba` / mode `0x0` ~61s | init exit status **1** | `141438` stockinit (**stock-init-sole FALSIFIED**) |
| `0x00007f00` | KP `exitcode=0x00007f00` | historical init/exec kill (status 127) | archival |

Flash script documents the same classes (`scripts/flash-from-remote.sh` warn block: `0x7f00` / `0x00000100` / `0xfc` / `0xbaba` + `set_active a`).

### Falsified sole causes (do not re-open)

| Stamp / claim | On-device result | Auditor stance |
|---------------|------------------|----------------|
| `130756` novirt + stock named apexes (tzdata-sole) | FAIL `0xfc` ~18s | **falsified** |
| `132759` stock apexd on that composition | FAIL `0xfc` ~18s | **falsified** |
| `141438` stock init binary | FAIL KP `0x00000100` ~61s | **falsified** (class change) |
| `150440` stock init.rc + GT init + stock apexd | **unflashed** | sufficiency **UNPROVEN** |

### Residual RC framing (honest)

Host staging of **stock `/system/etc/init/hw/init.rc`** onto the stockapexd + GT-init composition is the correct next bisect after `141438` KP `0x100` falsified stock-init-sole while `0xfc` history still implicates early apex config. Disk confirms the only intentional delta vs `132759` for this probe is **init.rc 57115 vs 58090** (plus retained GT init / stock apexd).

This does **not** prove that stock `init.rc` cures `apexd-bootstrap` non-zero exit or avoids re-entering `0x100`.

If operator later flashes `150440` and still fails:

- **`0xfc` ~18s** → stock init.rc + GT init + stock apexd + named stock bootstrap apexes + novirt is **insufficient**; residual moves past init.rc graft (see §6).
- **`0x00000100` ~61s** → same class as `141438`; init.rc graft did not change class — do not re-attribute to stock-init-sole.
- **`0x00007f00`** → historical path returned; capture raw dmesg; do not invent class.

**Do not stage** next probes in this audit. Document only.

---

## 3. Challenge answers (independent disk)

### C1 — Stockapexcfg composition correctly staged; not prematurely promoted?

**PASS — staged bisect; not promoted.**

| Check | Result |
|-------|--------|
| Stamp `rango-20260802-150440` | present + `system.img` + SHA256SUMS + README (`MODE=stockapexcfg`) |
| GT init `cmp` vs `132759` | **MATCH** 2938144 |
| init vs stock / `141438` | **DIFFERS** |
| apexd vs stock | **MATCH** 1083368 |
| init.rc vs stock | **MATCH** 57115 |
| init.rc vs `132759`/`141438`/`130756` | **DIFFERS** (57115 ≠ 58090) |
| apexd.rc vs stock | **MATCH** 1322 |
| virt.apex | absent |
| `rango-latest` | → `rango-20260802-130756` (**not** `150440`, **not** fullgt, **not** stockinit) |
| `MODE=stockapexcfg … --link-latest` | refuse exit **1** (stage script lines 1257–1258) |

### C2 — Residual RC framing honest given `150440` unflashed?

**PASS — framing honest; sufficiency UNPROVEN.**

- Named residual after `141438` FAIL: GT `init.rc` ≠ stock while GT init must be retained — **disk-confirmed**.
- Stamp README + T/Q treat stockapexcfg as **host-staged bisect**, not proven cure.
- On-device for `150440`: **HOLD** (`adb devices` empty; no `~/rango-dmesg-apexcfg*.txt`). Do **not** invent PASS.
- Ordered next probes if later FAIL documented in §6 — not staged.

### C3 — Flash path integrity; fail-class taxonomy; latest policy?

**PASS.**

```text
readlink -f releases/desktop-flash/rango-latest
→ …/rango-20260802-130756
latest_still_130756_PASS
PASS_not_150440_as_latest
PASS_not_fullgt
MODE=stockapexcfg --link-latest → refuse (bisect) exit 1

flash-*.sh → 5 KEEP only (no NEW under scripts/ + vendor/guardtalk/scripts/):
  scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote-signed.sh
  vendor/guardtalk/scripts/flash-signed.sh
  vendor/guardtalk/scripts/flash-tokay.sh

Operator bisect path: flash-from-remote.sh + REQUIRED REMOTE_BUILD_DIR=…/150440
SHA256SUMS 150440 → 22/22 OK
Q E2E log → 49 pass / 0 fail / 2 warn; bundle=150440; DEVICE BOOT HOLD
Fail-class messaging present: 0x7f00 | 0x00000100 | 0xfc | 0xbaba/mode 0x0 + set_active a
akita-latest → akita-20260725-101434; tokay stamp + flash-tokay.sh OK
```

### C4 — DEC-012 / pairing intact?

**PASS.**

```text
T-RANGO-BOOT-POSTINIT → Q-RANGO-BOOT-POSTINIT → A-RANGO-BOOT-POSTINIT
F = N/A
```

Both `.agent-comm/TASK_QUEUE.md` and root `TASK_QUEUE.md` carry the same T/Q/A chain; Architect APPROVED T (static HOLD) → APPROVED Q host/static → dispatched A. Frontend N/A. Preserved T/Q reports left intact. Operator flash blocks pin `REMOTE_BUILD_DIR=…/150440` + `fastboot set_active a` (slot A drained after `141438`).

---

## 4. Host integrity (spot)

| Check | Result |
|-------|--------|
| SHA256SUMS `150440` | **22/22 OK** |
| GT init `cmp` vs `132759` | **MATCH** 2938144 |
| Stock apexd `cmp` | **MATCH** 1083368 |
| Stock init.rc `cmp` | **MATCH** 57115 |
| Stock apexd.rc `cmp` | **MATCH** 1322 |
| virt | absent |
| Q E2E log (`/tmp/q-rango-boot-postinit-e2e.log`) | 49/0/2; DEVICE BOOT HOLD; bundle path `150440` |
| tokay/akita | non-regress OK |
| adb / dmesg-apexcfg | empty / absent → **HOLD** |

E2E not re-run end-to-end this audit (Q log + independent disk `cmp` / SHA / latest / refuse / virt spot checks sufficient). Dump artifacts reused from QA tmpdir `/tmp/q-rango-boot-postinit.cLB0Z4` (Auditor re-`cmp`).

---

## 5. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | On-device sufficiency for `150440` is **HOLD** — unflashed on build host; residual “stock init.rc cures boot” remains unproven. Do not treat host MATCH as boot PASS. |
| F2 | **MEDIUM** | If `150440` later FAIL `0xfc` or `0x100`, sole-cause space for init binary / apexd binary / named-bootstrap / tzdata / virt / **init.rc** is exhausted — Architect must open a **new** probe sprint (do not silently fold into durable `gtuserspace`). |
| F3 | **LOW** | Stamp README tees `~/rango-dmesg-apex.txt`; queue/operator path is `~/rango-dmesg-apexcfg-150440.txt` (doc drift only). |
| F4 | **LOW** | E2E RESULT banner still says “rango-latest” when `BUNDLE` overrides — cosmetic; step-0/bundle path shows `150440` (QA WARN class). |

**BLOCK: 0 · MEDIUM: 2 · LOW: 2**

---

## 6. Ordered next probes (if `150440` later FAIL)

Document only — **do not stage** in this audit:

| Order | Probe | Why |
|------:|-------|-----|
| 1 | hwasan / `libclang_rt.hwasan-*` native deps for runtime | Binary apexd + stock init.rc MATCH but native deps may still fail bootstrap |
| 2 | SELinux early-apex (domains, restorecon `/metadata`, file contexts) | Stamp restores `/metadata` before apexd-bootstrap; residual policy still open |
| 3 | ActivatePackage / apex mount path beyond `perform_apex_config` text | init.rc now stock; activation internals may still diverge |
| 4 | VNDK / `user` vs `userdebug` product surface | GT userspace vs factory kernel/dlkm pairing |
| 5 | Broader early userspace (remaining GT `com.android.*` apex set vs stock Google apexes; other init `.rc` surface already partially stripped) | Beyond grafted init binary / apexd / init.rc |

Capture: `fastboot oem dmesg | tee ~/rango-dmesg-apexcfg-150440.txt` immediately on FAIL. Classify per §2 taxonomy before opening next sprint.

---

## 7. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: stamp `150440` stockapexcfg (GT init + stock apexd + stock init.rc `cmp`), virt absent, latest stays `130756`, `--link-latest` refuse, SHA 22/22, flash path = `flash-from-remote.sh` only (no sprawl), fail-class taxonomy bound, residual RC honesty, DEC-012 T→Q→A — **independently confirmed**.
- On-device boot of `150440` — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Operator Mac flash `150440` via `flash-from-remote.sh` with **pinned** `REMOTE_BUILD_DIR=…/150440` and **`fastboot set_active a` first** (do **not** unset `REMOTE_BUILD_DIR` — that flashes durable FAIL `130756` via `rango-latest`) + immediate `oem dmesg` → `~/rango-dmesg-apexcfg-150440.txt`.
2. On adb PASS: Architect may promote composition into durable `gtuserspace` / reconsider `rango-latest` (human decision).
3. On still-FAIL: open next probe sprint per §6 — do not invent PASS; do not re-attribute to stock-apexd-sole, tzdata-sole, or stock-init-sole.

---

## 8. Gate 5

| Source | Score |
|--------|--------|
| `self_critique` MCP | **97/100 PASS** (1 WARN: long response citations) |
| Manual Gate 5 | **94%** |
| `gate_enforcer` Gate 5 | blocked by prior gate order (session) — content critique satisfied via `self_critique` |

Manual deductions: device HOLD (expected), residual-probe openness called out as MEDIUM not hidden, README dmesg path LOW.

---

## 9. STOP

Auditor deliverables complete. Status **REVIEW**. Architect closes sprint.
