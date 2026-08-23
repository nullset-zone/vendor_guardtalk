# A-RANGO-BOOT-HWASAN — Full Audit

| Field | Value |
|-------|--------|
| Task | `A-RANGO-BOOT-HWASAN` |
| Role | Auditor (read-only extreme) |
| Timestamp (UTC) | 2026-08-02T15:55:00Z |
| Depends on | `Q-RANGO-BOOT-HWASAN` ✅ APPROVED host/static CONDITIONAL GO (device HOLD) |
| audit_scope | full |
| Stamp | `rango-20260802-153335` (`MODE=stockhwasan`) |
| Verdict | **ACCEPTED CONDITIONAL GO** |
| Status | **REVIEW** (Architect ACCEPTs — Auditor does not self-ACCEPT closeout) |

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor.md` absent; used prior `A-RANGO-BOOT-*_AUDIT.md` pattern + Architect DISPATCH + `AGENTS.md` |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (`A-RANGO-BOOT-HWASAN` DISPATCH; `audit_scope: full`) |
| Gate -1 | MCP `ask_guardian` → compliant (Guardian Proxy fallback); `gate_enforcer` Gate -1 **PASSED** with evidence; Architect DISPATCH = Law 0 |
| Gate 5 | `self_critique` MCP (see §8) |
| Mode | Read-only; no implementation edits; no git commit; no invent on-device PASS; no stage new `MODE=` |
| Preserved | `TO_ARCHITECT_T-RANGO-BOOT-HWASAN.md`, `TO_ARCHITECT_Q-RANGO-BOOT-HWASAN.md`, `Q-RANGO-BOOT-HWASAN_EVIDENCE.md` (untouched) |

---

## 2. Residual RC after stock hwasan libc graft

### Composition under audit (`153335` / `MODE=stockhwasan`)

| Layer | Host evidence | Status |
|-------|---------------|--------|
| `/system/lib64/bootstrap/hwasan/libc.so` | `cmp` vs stock → **MATCH** size **1674080**; vs `150440` → **DIFFERS** (1674080 ≠ 1706096) | **bisect delta** |
| `/system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so` | `cmp` vs stock / `150440` → **MATCH** size **1248776** | retained (already stock on stockapexcfg) |
| `/system/bin/init` | `cmp` vs `150440` → **MATCH** size **2938144** (GT retained); vs stock → **DIFFERS** (≠ 2771368) | intentional |
| `/system/bin/apexd` | `cmp` vs stock → **MATCH** size **1083368** | stockapexd retained |
| `/system/etc/init/hw/init.rc` | `cmp` vs stock / `150440` → **MATCH** size **57115** | stockapexcfg retained |
| Named bootstrap apexes | runtime / i18n / tzdata present (durable gtuserspace fold) | unchanged |
| `com.android.virt.apex` | `File not found by ext2_lookup`; absent from `/system/apex` ls | dropped |

### Load-bearing RC cites (disk)

`system/apex/apexd/apexd.rc:18` (matches stamp `apexd.rc`):

```text
reboot_on_failure reboot,bootloader,bootstrap-apexd-failed
```

Stamp README + stage script document `requireNativeLibs` for runtime apex listing
`libclang_rt.hwasan-aarch64-android.so` on both stock and GT; the named residual
addressed by this MODE is **bootstrap `hwasan/libc.so`** (GT 1706096 → stock 1674080).

### Fail-class taxonomy (bound — do not invent)

| Class | Signal | Bound meaning | Exemplar |
|-------|--------|---------------|----------|
| `0xfc` | `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` ~18s | apexd-bootstrap `reboot_on_failure` | `130756`, `132759`, `150440` |
| `0x00000100` | KP `exitcode=0x00000100` / `0xbaba` / mode `0x0` ~61s | init exit status **1** | `141438` stockinit (**stock-init-sole FALSIFIED**) |
| `0x00007f00` | KP `exitcode=0x00007f00` | historical init/exec kill (status 127) | archival |

Flash script documents the same classes (`scripts/flash-from-remote.sh` warn block: `0x7f00` / `0x00000100` / `0xfc` / `0xbaba` + `set_active a`).

### Falsified sole causes (do not re-open)

| Stamp / claim | On-device result | Auditor stance |
|---------------|------------------|----------------|
| `130756` novirt + stock named apexes (tzdata-sole) | FAIL `0xfc` ~18s | **falsified** |
| `132759` stock apexd on that composition | FAIL `0xfc` ~18s | **falsified** |
| `141438` stock init binary | FAIL KP `0x00000100` ~61s | **falsified** (class change) |
| `150440` stock init.rc + GT init + stock apexd | FAIL `0xfc` ~18s | **falsified** (stockapexcfg-sole / stock-init.rc-sole) |
| `153335` stockapexcfg + stock bootstrap `hwasan/libc.so` | **unflashed** | sufficiency **UNPROVEN** |

### Residual RC framing (honest)

Host staging of **stock `/system/lib64/bootstrap/hwasan/libc.so`** onto the
stockapexcfg composition is the correct next bisect after `150440` FAIL `0xfc`
closed stock-init.rc-sole while `0xfc` still implicates early apex ActivatePackage
native deps. Disk confirms the only intentional delta vs `150440` for this probe
is **hwasan libc 1674080 vs 1706096** (plus retained GT init / stock apexd /
stock init.rc / stock hwasan-rt).

This does **not** prove that stock hwasan libc cures `apexd-bootstrap` non-zero
exit or avoids re-entering `0x100`.

If operator later flashes `153335` and still fails:

- **`0xfc` ~18s** → stock hwasan libc + stockapexcfg base is **insufficient**; residual moves past hwasan graft (see §6).
- **`0x00000100` ~61s** → same class as `141438`; hwasan graft changed class — do not re-attribute to stock-init-sole.
- **`0x00007f00`** → historical path returned; capture raw dmesg; do not invent class.

**Do not stage** next probes in this audit. Document only.

---

## 3. Flash-path integrity + GrapheneOS gap

### GuardTalk flash path (KEEP — no sprawl)

```text
flash-*.sh → 5 KEEP only (no NEW under scripts/ + vendor/guardtalk/scripts/):
  scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote-signed.sh
  vendor/guardtalk/scripts/flash-signed.sh
  vendor/guardtalk/scripts/flash-tokay.sh
```

Operator bisect path: `flash-from-remote.sh` + REQUIRED `REMOTE_BUILD_DIR=…/153335`.
Path used: rescue boot → fastbootd logicals / super → GuardTalk boot + vbmeta with
`--disable-verity --disable-verification`. Fail-class messaging present.

### Residual flash-path gap vs GrapheneOS `flash-all` (document — do not invent causality)

GrapheneOS official factory `flash-all.sh` (generated from
`device/common/generate-factory-images-common.sh`; rango sets
`DISABLE_DPM=true` + `DISABLE_UART=true` in `script/generate-release.sh`) does:

1. Dual-slot bootloader dance: `fastboot flash --slot=other bootloader …` →
   `--set-active=other` → reboot-bootloader → repeat
2. `fastboot oem uart disable` (when `DISABLE_UART=true`)
3. `fastboot erase dpm_a` / `fastboot erase dpm_b` (when `DISABLE_DPM=true`)
4. `fastboot -w --skip-reboot update image-$PRODUCT-$VERSION.zip`

GuardTalk `scripts/flash-from-remote.sh` **omits** DPM erase, UART disable, and
the dual-slot bootloader dance; it uses the custom rescue→super→disable-vbmeta
path above. Independent `rg` on `flash-from-remote.sh`: **no** `dpm` / `uart` /
`slot=other` matches.

**Auditor stance (binding):** Document this as a **residual flash-path gap** and
a candidate parallel track for flash-script hardening. Do **not** claim that
missing DPM erase (or UART / dual-slot BL) **alone** explains historical `0xfc`
failures — those stamps were already composition-falsified on-device under the
same GuardTalk flash path, and `0xfc` remains bound to apexd-bootstrap
`reboot_on_failure` until proven otherwise. Flash-path gap and userspace residual
are **orthogonal** until an experiment isolates them.

---

## 4. Challenge answers (independent disk)

### C1 — Stockhwasan composition correctly staged; not prematurely promoted?

**PASS — staged bisect; not promoted.**

| Check | Result |
|-------|--------|
| Stamp `rango-20260802-153335` | present + `system.img` + SHA256SUMS + README (`MODE=stockhwasan`) |
| hwasan libc `cmp` vs stock | **MATCH** 1674080 |
| hwasan libc vs `150440` | **DIFFERS** (1674080 ≠ 1706096) |
| hwasan-rt vs stock | **MATCH** 1248776 |
| GT init `cmp` vs `150440` | **MATCH** 2938144 |
| init vs stock | **DIFFERS** |
| apexd vs stock | **MATCH** 1083368 |
| init.rc vs stock / `150440` | **MATCH** 57115 |
| virt.apex | absent |
| `rango-latest` | → `rango-20260802-130756` (**not** `153335`, **not** fullgt) |
| `MODE=stockhwasan … --link-latest` | refuse exit **1** |

### C2 — Residual RC framing honest given `153335` unflashed?

**PASS — framing honest; sufficiency UNPROVEN.**

- Named residual after `150440` FAIL: GT bootstrap `hwasan/libc.so` ≠ stock while
  hwasan-rt already stock — **disk-confirmed**.
- Stamp README + T/Q treat stockhwasan as **host-staged bisect**, not proven cure.
- On-device for `153335`: **HOLD** (`adb devices` empty; no `~/rango-dmesg-hwasan*.txt`). Do **not** invent PASS.
- Ordered next probes if later FAIL documented in §6 — not staged.
- Flash-path gap documented in §3 without inventing DPM→`0xfc` sole causality.

### C3 — Flash path integrity; fail-class taxonomy; latest policy?

**PASS** (with residual GrapheneOS gap as MEDIUM finding, not flash sprawl).

```text
readlink -f releases/desktop-flash/rango-latest
→ …/rango-20260802-130756
latest_still_130756_PASS
PASS_not_153335_as_latest
PASS_not_fullgt
MODE=stockhwasan --link-latest → refuse (bisect) exit 1

flash-*.sh → 5 KEEP only (no NEW)
Operator bisect path: flash-from-remote.sh + REQUIRED REMOTE_BUILD_DIR=…/153335
SHA256SUMS 153335 → 22/22 OK
Q E2E log → 49 pass / 0 fail / 2 warn; bundle=153335; DEVICE BOOT HOLD
Fail-class messaging present: 0x7f00 | 0x00000100 | 0xfc | 0xbaba/mode 0x0 + set_active a
akita-latest → akita-20260725-101434; tokay stamp + flash-tokay.sh OK
GrapheneOS gap: DPM erase / UART / dual-slot BL / update.zip omitted (see §3)
```

### C4 — DEC-012 / pairing intact?

**PASS.**

```text
T-RANGO-BOOT-HWASAN → Q-RANGO-BOOT-HWASAN → A-RANGO-BOOT-HWASAN
F = N/A
```

Both `.agent-comm/TASK_QUEUE.md` and root `TASK_QUEUE.md` carry the same T/Q/A
chain; Architect APPROVED T (static HOLD) → APPROVED Q host/static → dispatched A.
Frontend N/A. Preserved T/Q reports left intact. Operator flash blocks pin
`REMOTE_BUILD_DIR=…/153335` + `fastboot set_active a`.

---

## 5. Host integrity (spot)

| Check | Result |
|-------|--------|
| SHA256SUMS `153335` | **22/22 OK** |
| hwasan libc stock `cmp` | **MATCH** 1674080 |
| hwasan libc vs `150440` | **DIFFERS** |
| hwasan-rt stock `cmp` | **MATCH** 1248776 |
| GT init `cmp` vs `150440` | **MATCH** 2938144 |
| Stock apexd `cmp` | **MATCH** 1083368 |
| Stock init.rc `cmp` | **MATCH** 57115 |
| virt | absent |
| Q E2E log (`/tmp/q-rango-boot-hwasan-e2e.log`) | 49/0/2; DEVICE BOOT HOLD; bundle path `153335` |
| tokay/akita | non-regress OK |
| adb / dmesg-hwasan | empty / absent → **HOLD** |

E2E not re-run end-to-end this audit (Q log + independent disk `cmp` / SHA /
latest / refuse / virt / flash-gap spot checks sufficient). Dump artifacts in
Auditor tmpdir `/tmp/a-hwasan-0GFANR`.

---

## 6. Findings

| ID | Severity | Finding |
|----|----------|---------|
| F1 | **MEDIUM** | On-device sufficiency for `153335` is **HOLD** — unflashed on build host; residual “stock hwasan libc cures boot” remains unproven. Do not treat host MATCH as boot PASS. |
| F2 | **MEDIUM** | If `153335` later FAIL `0xfc` or `0x100`, sole-cause space for init binary / apexd binary / named-bootstrap / tzdata / virt / init.rc / **hwasan libc** is exhausted — Architect must open a **new** probe sprint (do not silently fold into durable `gtuserspace`). |
| F3 | **MEDIUM** | Residual flash-path gap: GuardTalk `flash-from-remote.sh` omits GrapheneOS `flash-all` dual-slot bootloader dance, `oem uart disable`, `erase dpm_a`/`dpm_b`, and `fastboot -w --skip-reboot update image.zip`. Documented only — **do not** claim DPM alone explains `0xfc`. Separate flash-script track (Architect-noted). |
| F4 | **LOW** | E2E RESULT banner still says “rango-latest” when `BUNDLE` overrides — cosmetic; step-0/bundle path shows `153335` (QA WARN class). |

**BLOCK: 0 · MEDIUM: 3 · LOW: 1**

---

## 7. Ordered next probes (if `153335` later FAIL)

Document only — **do not stage** in this audit:

| Order | Probe | Why |
|------:|-------|-----|
| 1 | SELinux early-apex (domains, restorecon `/metadata`, file contexts) | Stamp restores `/metadata` before apexd-bootstrap; residual policy still open after hwasan graft |
| 2 | ActivatePackage / apex mount path beyond `perform_apex_config` + native-lib text | init.rc + hwasan libc now stock; activation internals / other `requireNativeLibs` may still diverge |
| 3 | VNDK / `user` vs `userdebug` product surface | GT userspace vs factory kernel/dlkm pairing |
| 4 | Broader early userspace (remaining GT `com.android.*` apex set vs stock Google apexes; other init `.rc` surface) | Beyond grafted init / apexd / init.rc / hwasan |
| 5 | Flash-path parity experiment (optional parallel): add DPM erase + UART disable + dual-slot BL steps to a **named** flash probe without changing userspace composition | Isolates flash-path gap from composition residual — **must not** be used to invent that DPM alone caused prior `0xfc` |

Capture: `fastboot oem dmesg | tee ~/rango-dmesg-hwasan-153335.txt` immediately on FAIL. Classify per §2 taxonomy before opening next sprint.

---

## 8. Verdict

**ACCEPTED CONDITIONAL GO**

- Static / host path: stamp `153335` stockhwasan (stockapexcfg + stock bootstrap
  `hwasan/libc.so` `cmp`), GT init retained, virt absent, latest stays `130756`,
  `--link-latest` refuse, SHA 22/22, flash path = `flash-from-remote.sh` only
  (no sprawl), fail-class taxonomy bound, residual RC honesty, GrapheneOS
  flash-path gap documented without false DPM causality, DEC-012 T→Q→A —
  **independently confirmed**.
- On-device boot of `153335` — **HOLD** (no USB device; do not invent PASS).
- Architect must ACCEPT (or REJECT) — Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks)

1. Operator Mac flash `153335` via `flash-from-remote.sh` with **pinned**
   `REMOTE_BUILD_DIR=…/153335` and **`fastboot set_active a` first** (do **not**
   unset `REMOTE_BUILD_DIR` — that flashes durable FAIL `130756` via `rango-latest`)
   + immediate `oem dmesg` → `~/rango-dmesg-hwasan-153335.txt`.
2. On adb PASS: Architect may promote composition into durable `gtuserspace` /
   reconsider `rango-latest` (human decision).
3. On still-FAIL: open next probe sprint per §7 — do not invent PASS; do not
   re-attribute to stock-apexd-sole, tzdata-sole, stock-init-sole, stockapexcfg-sole,
   or stock-hwasan-sole until re-bound.
4. Separate track: flash-script parity with GrapheneOS `flash-all` (DPM/UART/dual-slot)
   — residual gap only; not a substitute for userspace bisect.

---

## 9. Gate 5

| Source | Score |
|--------|--------|
| `self_critique` MCP | **97/100 PASS** (1 WARN: long response citations) |
| Manual Gate 5 | **94%** |
| `gate_enforcer` Gate 5 | blocked by prior gate order (session) — content critique satisfied via `self_critique` |

Manual deductions: device HOLD (expected), flash-path gap called out as MEDIUM without inventing DPM→`0xfc`, residual-probe openness not hidden.

---

## 10. STOP

Auditor deliverables complete. Status **REVIEW**. Architect closes sprint.
