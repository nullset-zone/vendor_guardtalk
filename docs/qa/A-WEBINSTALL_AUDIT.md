# A-WEBINSTALL — Full Audit (GuardTalkOS web-installer wave, tokay)

| Field | Value |
|-------|--------|
| Task | `A-WEBINSTALL` |
| Role | Independent Deep Tech Auditor (not the Architect) |
| Timestamp (packet clock) | 2026-08-20T16:55:00Z |
| Host `date -u` at audit | 2026-08-20T16:26:18Z (skew vs Architect 16:45 dispatch stamps; not used as a finding) |
| Depends on | T-FACTORY-CHANNEL, T-FLASHCORE, F-WIZARD, Q-WIZARD — all Architect-APPROVED (host/mocked) |
| audit_scope | **full** (Architect-bound; no intensity prompt) |
| Verdict | **CONDITIONAL GO** (host/mocked) / **HOLD** (live-flash, browser E2E, CLI OS-path parity) |
| Status | **REVIEW** (Auditor does not APPROVE) |
| Live-flash GO? | **NO** |

---

## Independence statement

```text
INDEPENDENT AUDITOR ENGAGED
Firm: Deep Tech Audit (Big 4 equivalent)
Scope: full (packet A-WEBINSTALL; eight mandatory axes)
Independence: CONFIRMED — I am NOT the Architect. I audit the Architect.
Context loaded: aegis-auditor(internal).md, TO_AUDITOR.md, AGENTS.md,
  .memory-bank/{activeContext,progress,decisions,sessionHistory}.md,
  both TASK_QUEUE.md, DONE_LOG.md, PROTOCOL.md, ROLES.md,
  WEB_INSTALLER.md, WEB_INSTALLER_CHANNEL.md, pack-webinstall-channel.sh,
  web-installer/{src,wizard,test,NOTICE,package.json,package-lock.json},
  Q-WEBINSTALL-{GOS-ANALYSIS,FACTORY-CHANNEL,FLASHCORE,WIZARD}_EVIDENCE.md,
  scripts/flash-from-remote.sh (read-only), grapheneos.org/install/web (live fetch)
```

Packet is authoritative. Known exclusions **E1–E3** not flagged.

---

## 1. Governance

| Check | Result |
|-------|--------|
| Workflow | `.windsurf/workflows/aegis-auditor(internal).md` loaded |
| Inbox | `.agent-comm/inbox/TO_AUDITOR.md` (`A-WEBINSTALL` DISPATCH, `audit_scope: full`) |
| Gate -1 | `ask_guardian` fallback (`Guardian Proxy not available`, `governanceStatus=compliant`); `gate_enforcer` Gate -1 **PASSED** (session `ws_1787243006709`) |
| GIP-0 shield | `prompt_injection_shield` **SAFE** (risk 0%; 22 pattern checks; 0 threats) |
| Mode | Read-only of product/doctrine/flash scripts; writes only allowed audit artifacts; **no git commit** |
| Forbidden paths | Not written: `doctrine/`, `governance/laws|gates/`, AEGIS Control Center, `web-installer/src|wizard/`, both `flash-from-remote.sh`, secrets |

---

## 2. Independent host reproduction (do not trust Architect claims)

| Check | Architect / QA claim | Auditor observation | Result |
|-------|----------------------|---------------------|--------|
| `npm test` (tsc + tsx) | 34/34 | `# tests 34` `# pass 34` `# fail 0` Node **v22.12.0** (`/home/openstatestack/.local/node/bin/node`) | **PASS** |
| Disk `test()` count | 4+5+3+6+4+2+10 = 34 | Same split across 7 files | **PASS** |
| Wizard `tsc -p tsconfig.wizard.json --noEmit` | exit 0 | `WIZARD_TSC_EXIT=0` | **PASS** |
| Packer `--self-test` | `SELF_TEST_OK` | `SELF_TEST_OK` (tokay pack, rango reject, production fail-closed, PEM reject) | **PASS** |
| Pack `rango-latest` | reject | exit 1: `product 'rango' is not in the advertised allowlist (tokay only)` | **PASS** |
| `CHANNEL=production` pack | fail-closed without `.sig` | exit 1: `CHANNEL=production cannot pack: no in-tree public signer (fail closed)` | **PASS** |
| Both `flash-from-remote.sh` | IDENTICAL, 1135, SHA `d48a0c9d…d63c` | `cmp` silent; both 1135; SHA **identical** | **PASS** |
| `rango-latest` | stays `130756` | `rango-latest` → `rango-20260802-130756` | **PASS** |
| `LIVE_FLASH_CLAIMED` | false | `src/types.ts:110` `export const LIVE_FLASH_CLAIMED = false` | **PASS** |
| Evidence line counts | 198 / 275 / 245 / 257; ADR 416 | `wc -l` matches | **PASS** |

This is **not** a live USB flash. No Chromium/Playwright E2E. No phone attached.

---

## 3. Mandatory axes

### Axis 1 — License / copyright (DEC-005)

**PASS with LOW NOTICE gap.**

| Check | Evidence |
|-------|----------|
| Reimplement, not GOS fork | Wizard title/eyebrow/footer = **GuardTalkOS**; dark copper theme (`wizard/styles.css` `--copper: #d4a054`). Live GOS `/install/web` opens “This is the WebUSB-based installer for GrapheneOS…” — **not present** in product HTML/CSS/TS. |
| Distinctive GOS paste | `rg` of product tree (excl. tests/docs) for `The web installer is the easiest method` / GOS recommended-approach lede = empty. Test `wizard-gating.test.ts` **rejects** that paste. |
| NOTICE | `vendor/guardtalk/web-installer/NOTICE` attributes flashcore as original; lists pinned `typescript` (Apache-2.0), `tsx` (MIT), `@types/node` (MIT); documents **intended** MIT `android-fastboot` pin `ffe7e270` **not installed**. |
| Operational overlap | fwupd / Incognito / OEM-unlock *facts* appear because any Pixel WebUSB installer must say them. Wording is original (e.g. “Private / Incognito windows are not a supported path” ≠ GOS “Do not use Incognito…”). |

FIPS SHA-256 constants in `sha256-portable.ts` are public algorithm material, not GrapheneOS copy.

### Axis 2 — Secret leakage

**PASS.**

| Check | Evidence |
|-------|----------|
| Named secrets | `find` of `vendor/guardtalk/{web-installer,scripts,docs}` (prune `node_modules`) for `*.pem` `*.pk8` `.env` = **empty** |
| PEM text | `BEGIN … PRIVATE` appears only in packer **self-test fixture** and QA evidence quoting it — not shipped keys |
| Packer | Fails closed on private-looking `avb_pkmd.bin`, stamp PEM headers, `CHANNEL=production` without public `.sig` + `allowed_signers`; never writes `*.pem`/`*.pk8`/`.env` |
| Channel | Public `avb_pkmd.bin` only; `verifiedBootClaim=none`; signature `hash-only` on `CHANNEL=dev` |

### Axis 3 — Pairing quality

**PASS.**

| Rule | Evidence |
|------|----------|
| T/Q (and F/Q) pairs | GOS-ANALYSIS, FACTORY-CHANNEL, FLASHCORE, WIZARD all paired in **both** queues |
| Dual-queue | Root `TASK_QUEUE.md` and `.agent-comm/TASK_QUEUE.md` carry the same cards and Architect APPROVED statuses |
| Architect-only APPROVED | Engineers left REVIEW; `DONE_LOG.md` T15:20–Q16:45 entries are Architect approvals with file `wc`, test re-runs, security notes |
| Q after T | DONE_LOG timestamps: T then Q per pair; FLASHCORE Q not dispatched until T APPROVED; WIZARD Q after F APPROVED |
| Evidence vs claims | QA evidence matrices match disk (34 `test()`, script SHA, rango reject). Auditor re-ran the same commands. |

Nit (not a pairing break): `A-WEBINSTALL` `depends_on` lists factory/flashcore **T** + wizard T/Q, not Q-FACTORY or Q-FLASHCORE. Those Q cards were already APPROVED before dispatch.

### Axis 4 — Flash-order fidelity vs CLI (DEC-006 / DEC-008)

**PASS on GOS *phase* order. HIGH gap on GT CLI *OS mechanics*. Honestly labeled as not dual-slot parity; under-labeled as not fastbootd/verity/wipe parity.**

Official GOS / DEC-006 order implemented in flashcore:

```13:19:vendor/guardtalk/web-installer/src/plan.ts
/** Build a deterministic plan: firmware → avb_custom_key → OS (DEC-006). */
export function buildFlashPlan(channel: ChannelBundle): FlashPlan {
  const steps: PlanStep[] = [];
  appendFirmwareSteps(channel, steps);
  appendAvbSteps(channel, steps);
  appendTokayHousekeeping(steps);
  appendOsSteps(channel, steps);
```

Independent suite: ok 19–22 (firmware → avb → OS; bootloader/radio then key; reconnect before AVB). Tokay housekeeping (`oem uart disable`, erase `fips`/`dpm_*`) sits after AVB, before OS — matches CLI cleanup placement after `avb_custom_key`.

CLI (`scripts/flash-from-remote.sh`, read-only) then does **more**, which flashcore **does not**:

| CLI step | Flashcore v1 | Documented? |
|----------|--------------|-------------|
| Dual-slot bootloader `--slot=other` dance (2 passes) | Firmware artifacts flashed **once**; `orchestrator.flashVerified` never passes `slot` | **Yes** — DEC-008 + wizard `data-dec="008"` banner |
| `erase userdata` + `erase metadata` | Absent (`rg` of `web-installer/` = no matches) | ADR gap table only |
| Enter **fastbootd** before logical / super | Absent; OS `*.img` mapped to partition names and flashed in bootloader | ADR gap table only (“do not invent a third order”) |
| `vbmeta*` with `--disable-verity --disable-verification` | `transport.flash(partition, data)` with no flags | ADR “open follow-on”; DEC-007 banner covers *lock claim*, not the missing flags |
| CLI does **not** lock | Wizard **offers Lock** after `planComplete`, with DEC-007 warning | Product UX matches GOS-like final step, not GT CLI |

DEC-008 is honored as a **claim**: wizard/README say this is not a substitute for `flash-from-remote.sh` and does not replay the dual-slot dance. Adapter `partitionName(..., slot: "other")` exists but is unused by the orchestrator — scaffolding, not a parity claim.

### Axis 5 — JS supply chain

**PASS.**

| Check | Evidence |
|-------|----------|
| Runtime deps | `package.json` `dependencies` = **none** |
| Pins | `@types/node` **22.10.5**, `tsx` **4.19.3**, `typescript` **5.7.3** (no `^`/`~`) |
| `android-fastboot` | Not in `package.json` or `package-lock.json`; wizard logs that live USB needs a provided `window.FastbootDevice` |
| Lockfile transitives | Expected **dev** graph of tsx: `esbuild`, `get-tsconfig`, `resolve-pkg-maps`, `fsevents` (optional), `undici-types` via `@types/node`. No unexpected runtime package. |

### Axis 6 — Rango not oversold

**PASS.** This wave is **not** a boot fix.

| Check | Evidence |
|-------|----------|
| MVP tokay | `ALLOWED_PRODUCT = "tokay"`; picker `WIZARD_DEVICES` length 1 |
| Hidden / rejected | Allowlist, channel load, connect, packer, `selectDevice('rango')` all fail closed |
| `rango-latest` | Still `130756` |
| Docs | ADR + queues: “Not a rango boot fix” |

### Axis 7 — Architect review quality

**Not a rubber-stamp of tests. Incomplete challenge of CLI OS-path.**

DONE_LOG shows Architect cited live fetches (GOS analysis), `--self-test` + live pack/verify (factory), **22/22** then **34/34** (flashcore/wizard), script `cmp`, and honesty HOLDs. Auditor **independently reproduced 34/34** and the packer/rango/production/script/`130756` checks. That is real review, not generic “LGTM”.

What Architect did **not** bind: ADR said flashcore must trace to **tokay CLI order** and “do not invent a third order.” Implementation invented a simplified OS dump (bootloader-mode partition flashes). Architect bound **DEC-008** for dual-slot only, then APPROVED flashcore/wizard as matching DEC-006 phase order. Test re-runs cannot catch a missing fastbootd step that no test asserts.

### Axis 8 — Honesty HOLDs

**PASS** for the claims the packet named. Residual product risk on live buttons: see F1.

| Claim | Evidence |
|-------|----------|
| No live-flash PASS | `LIVE_FLASH_CLAIMED=false`; no device this session; QA evidence C20 HOLD |
| No browser E2E | No Playwright/Chromium run; reconnect dialog is markup-only HOLD |
| Not CLI dual-slot parity | DEC-008 banner + README |
| Shipped live USB | `android-fastboot` **not bundled**; Connect throws unless dry-run or injected `FastbootDevice` — reduces accidental brick, does **not** make `executePlan()` CLI-safe |

---

## 4. Findings

```
FINDING: F1 — Flashcore OS path is a third order vs GT CLI
SEVERITY: HIGH
EVIDENCE: orchestrator.ts flashVerified → transport.flash(partition, data) with no slot, no --disable-verity;
  plan.ts maps every OS *.img to a bootloader partition; rg of web-installer has zero fastbootd / userdata / disable-verity.
  CLI flash-from-remote.sh: dual-slot (L277–302), avb then wipe (L667–676), fastbootd-first logicals (L688–699), vbmeta disable flags (L112–125).
  ADR WEB_INSTALLER.md L369: “Do not invent a third order.”
IMPACT: If an operator injects android-fastboot and clicks Flash/Lock, tokay will not be installed the way the approved CLI path installs it. Logical flashes in bootloader and locking without disable-verity are device-risk.
RECOMMENDATION: Bind DEC-WEBINSTALL-009 listing OS-path non-goals (fastbootd, super/logical, userdata wipe, vbmeta flags). Keep live Flash/Lock disabled until a card implements them — or keep dry-run as the only shipped execute path. Do not treat this REVIEW as a live-flash GO.
OWNER: Architect (decision) / Backend (follow-on T) / Frontend (gate live buttons)
EFFORT: Decision = short; implementation = separate wave
```

```
FINDING: F2 — Architect verified 22/22 then 34/34 but equated phase-order with CLI fidelity
SEVERITY: MEDIUM
EVIDENCE: DONE_LOG T-FLASHCORE / F-WIZARD approval reasoning cites plan order, rango, lock-before-complete, DEC-008; does not mention fastbootd, userdata, or vbmeta flags as accepted v1 omissions beyond dual-slot.
IMPACT: Future cards may assume “flashcore is the tokay flash plan” and skip CLI-critical steps.
RECOMMENDATION: When ACCEPTing this REVIEW, write the OS-path HOLD into decisions.md (DEC-009). Do not rewrite history of the 34/34 re-run — that part was real.
OWNER: Architect
EFFORT: Short
```

```
FINDING: F3 — NOTICE does not list tsx transitives
SEVERITY: LOW
EVIDENCE: NOTICE names typescript / tsx / @types/node; lockfile also ships esbuild (MIT), get-tsconfig, resolve-pkg-maps, undici-types (all dev).
IMPACT: Attribution incomplete for Apache/MIT tools actually installed.
RECOMMENDATION: Extend NOTICE on the next web-installer docs touch. Not blocking for host/mocked ACCEPT.
OWNER: Backend
EFFORT: Minutes
```

```
FINDING: F4 — Stale T-GOS-ANALYSIS acceptance text still lists avb-after-OS
SEVERITY: LOW
EVIDENCE: Root TASK_QUEUE.md T-WEBINSTALL-GOS-ANALYSIS checkbox: “unlock → firmware → reconnect → OS → avb_custom_key → lock” marked [x] after DEC-006 bound the opposite zip order. ADR body (L167, L416) is correct.
IMPACT: Queue hygiene / Law 1; does not revert the code plan.
RECOMMENDATION: Architect edit that checkbox to the DEC-006 order when touching queues.
OWNER: Architect
EFFORT: Minutes
```

```
FINDING: F5 — CHANNEL.md illustrative epoch nit (already QA WARN)
SEVERITY: LOW
EVIDENCE: WEB_INSTALLER_CHANNEL.md L60 `1753439106` vs live stamp epoch `1784975106` (manifest.example.json). Labeled illustrative.
IMPACT: Copy-paste confusion only.
RECOMMENDATION: Align example or keep the “illustrative” label louder.
OWNER: Backend
EFFORT: Minutes
```

**BLOCK: 0 · HIGH: 1 · MEDIUM: 1 · LOW: 3**

QA leftover WARN (omitted-`avb_pkmd.bin` fail-closed in code but not a named `test()`) is confirmed; not re-filed as new (already in Q-FLASHCORE evidence).

---

## 5. Decision quality (DEC-WEBINSTALL-001..008)

| DEC | Context | Alternatives | Evidence | Laws | Reversibility | Rating (1–5) |
|-----|---------|--------------|----------|------|---------------|--------------|
| 001 tokay MVP | Yes (rango 0xfc HOLD) | akita-first / multi-device rejected | FLASH.md path + rango HOLD | 0, 2, 6 | Yes | 5 |
| 002 path | Yes | Control Center rejected | Packet | 2, 6 | Yes | 5 |
| 003 wave-1 docs only | Yes | Big-bang rejected | Dispatch log | 6 | Yes | 5 |
| 004 KEEP CLI scripts | Yes | Replace CLI rejected | cmp IDENTICAL | 11 | Yes | 5 |
| 005 reimplement | Yes | Copy GOS rejected | Axis 1 | 4, 12-adj | Yes | 5 |
| 006 avb-before-OS | Yes (corrected dispatch sketch) | Legacy factory.ts after-OS rejected | ADR W11/W12 + plan.ts | 7, 16 | Yes | 5 |
| 007 dev/unlocked | Yes (CLI verity flags) | Advertise locked GOS-equiv rejected | manifest + banners | 1, 7 | Yes | 5 |
| 008 no dual-slot v1 | Partial — dual-slot only | Full CLI parity deferred | banners + unused slot helper | 1, 7 | Yes | **3** (scope too narrow vs actual v1 omissions) |

---

## 6. Commendations

- DEC-006 was a real Architect correction, not a silent rubber-stamp of the original dispatch sketch.
- DEC-007 / DEC-008 banners are in the shipped HTML (`data-dec="007"|"008"`), not only in YAML.
- Rango is rejected in packer, allowlist, channel, orchestrator, and picker — and `rango-latest` was not relinked.
- Dual-queue + T/Q pairing held for the whole wave; QA evidence files are adversarial and match disk.
- Production channel **fail-closed** without inventing keys (Law 4).
- `LIVE_FLASH_CLAIMED=false` is a constant, not a comment.

---

## 7. Verdict

**CONDITIONAL GO** for the host/mocked wave.

- Analysis ADR, factory channel packer, flashcore, wizard, and four Q evidence files are **independently confirmed** on this host.
- **HOLD:** live USB flash, browser E2E, `flash-from-remote.sh` dual-slot **and** fastbootd/verity/wipe parity.
- **Not** a live-flash GO. **Not** a rango boot fix. `rango-latest` stays `130756`.

Architect must ACCEPT or REJECT. Auditor stops at **REVIEW**.

### Recommended Architect follow-ups (do not create tasks here)

1. Bind **DEC-WEBINSTALL-009**: flashcore v1 OS path is not GT CLI (no fastbootd, no userdata wipe, no vbmeta disable flags). Dual-slot remains DEC-008.
2. Do not dispatch a live-flash Q/T until that DEC exists and the wizard cannot call `executePlan()` / `lock()` against a real device without an explicit later card.
3. Optional nits: NOTICE transitives, T-GOS-ANALYSIS checkbox text, CHANNEL.md epoch.

---

## 8. Gate 5

| Source | Score |
|--------|--------|
| `prompt_injection_shield` | SAFE (0%) |
| `ultimate_critique` MCP | **UNAVAILABLE** (`python` not on PATH) — same as prior A- audits |
| Manual Gate 5 | **93%** |

Manual deductions: F1 HIGH is in-scope honesty about CLI fidelity (not hidden); F2 is review-quality not a product secret; LOW nits. Live-flash HOLD is required by the packet.

---

## 9. STOP

Deliverables: this file, `.agent-comm/inbox/TO_ARCHITECT.md` REPLACE, both queues `A-WEBINSTALL` → **REVIEW** only. No git commit.
