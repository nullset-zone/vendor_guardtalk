# READER-C DIGEST

## 1. Verdict: site-tree existence

**NO os.guardtalk.io website tree exists in this repo. Zero Next.js/Astro sites anywhere.**

Checked with tight-rooted globs/greps (never crossed the Android tree):

| Location | Found |
|---|---|
| `apps/` | Only `"AEGIS CONTROL CENTER/frontend-v2"` — AEGIS governance dashboard (React/Vite, unrelated product; broken node_modules symlink) |
| `vendor/guardtalk/apps/` | 4 Android apps (`GuardTalkConfig/Face/Validator/Voice`) — no web code |
| `.aegis/nexus/assembled_projects/` | Unrelated demo projects (NexusBoard, TaskFlowPro + UUID dirs) with Vite configs only |
| Repo root | No docs/, no web tree; Android build system + logs |
| `next.config.*` / `astro.config.*` repo-wide (tight roots) | **0 files** |
| `status.json`, `lib/privacy.ts`, `lib/claims.ts` under vendor/guardtalk | **0 files** |
| `package.json` declaring `next`/`astro` deps (apps/ + vendor/guardtalk, excl. node_modules) | none |

The **only web code is `vendor/guardtalk/web-installer/`** (flashcore lib + single-page wizard). This matches the project's own record: `QUESTIONS_FOR_HUMAN.md` Q-02 states "No os.guardtalk.io site tree exists in this repo today."

## 2. Where `/install` should physically live

The prompt demands routes inside an os.guardtalk.io codebase that does not exist. Two options:

- **Option A — extend `vendor/guardtalk/web-installer/` into a statically-exported multi-route site.** Add a build step that emits `/install/index.html`, `/install/update`, `/install/recover`, `/install/verify-device` from the existing wizard modules, plus `status.json`, `lib/privacy.ts`, `lib/claims.ts`. Pros: reuses tested flashcore (orchestrator/plan/channel/hash), DEC log continuity, zero new toolchain beyond tsc; static export needs no framework. Cons: hand-rolled routing/CSP plumbing; diverges from prompt's assumed Next/Astro conventions.
- **Option B — scaffold fresh static-export app (e.g. `apps/os-guardtalk-site/` or `vendor/guardtalk/site/`) and port web-installer in as `/install`.** Pros: clean route-group layout matching the prompt's contract; room for tokens/status.json/lib conventions. Cons: duplicates or moves ~30 existing TS modules + tests; new dependency surface (violates Law 22 minimalism unless framework-free).

Recommendation signal for Phase 2: **A is lower-risk** given D-009 (identity sources absent) and the working no-framework toolchain; B only if human supplies the missing brand/build-prompt sources.

## 3. Inventory worth carrying forward

### Module graph
```
src/ (flashcore)                      wizard/
├─ types.ts      ChannelBundle, FastbootTransport,
│                PlanStep, FlashPlan, isDryRunTransport(),
│                LIVE_FLASH_CLAIMED=false        ├─ session.ts     InstallWizard state machine → orchestrator
├─ plan.ts       buildFlashPlan(channel)         ├─ adb-{bytes,packet,pipe,rsa,reboot,session,usb}.ts  WebUSB ADB stack
├─ channel.ts    manifest parse+verify           ├─ devices.ts     picker: tokay Pixel 9 / akita Pixel 8a only
├─ allowlist.ts  assertAllowedProduct            ├─ gating.ts      preview|dry-run|live flags
├─ hash.ts / sha256-portable.ts                  ├─ hosted-channel.ts  ../channels/<product>/ base URL
├─ store.ts / store-fs.ts (ArtifactStore)        ├─ http-store.ts  HttpArtifactStore (safe-name fetch)
├─ transport.ts  adaptAndroidFastboot()          ├─ quota.ts       storage estimate from real artifact sizes
│                (dryRun:false ⇒ live)           ├─ dry-run.ts     DryRunTransport (dryRun:true)
├─ orchestrator.ts  FlashOrchestrator:           └─ main.ts        DOM wiring
│   connect→assertProduct→unlock→executePlan→lock
├─ errors.ts     LiveExecuteHoldError etc.
└─ cli.ts        `npm run plan`
```
Supporting: `schema/channel-manifest.schema.json` + example; `channels/{tokay,akita}/` (manifest.json, SHA256SUMS, avb_pkmd.bin, packed dir); `dist/src` 60K, `dist/wizard` 76K (15 JS modules); `test/` = 10 test files incl. `adb-reboot.test.ts` (12K) and `wizard-gating.test.ts` (10K); scripts via `../../scripts/pack-wizard-hosted-channels.sh`.

### DEC-009 dry-run enforcement points
1. `types.ts:84` — `FastbootTransport.dryRun?: boolean` ("Missing or false means live: execute/lock HOLD")
2. `types.ts:96-98` — `isDryRunTransport()` strict `=== true`
3. `orchestrator.ts:76,87` + `98-102` — `executePlan()`/`lock()` call `assertDryRunOnly()` → throws `LiveExecuteHoldError`
4. `types.ts:119` — `LIVE_FLASH_CLAIMED = false` constant (no false claims)
5. `wizard/dry-run.ts` — `DryRunTransport` "must not be reported as a live flash"
6. Tests: `Q-WEBINSTALL-DRYRUN-ONLY_EVIDENCE.md` + gating tests assert holds fire on non-dry-run transports

### Design tokens (`wizard/styles.css` :root)
Dark scheme: surfaces `--bg #12151a`, `--bg-elev #1b2129`, `--bg-rail #161b21`; ink `--ink #e8edf2`, `--muted #9aa6b2`; borders `--line #2c3640`, `--line-strong #6b7887` (WCAG 1.4.11 ≥3:1 noted); copper accent set `--copper #d4a054 / -ink / -hover #c08d43 / -active #a87c39`; status `--ok #8fd0a4`, `--warn #e6c36a`, `--danger #f0a0a0`, filled danger pair `--danger-strong(-hover)` + `--danger-ink`; focus `--focus #f2d19a`. Also reusable: skip-link, banner variants (dev/warn, parity/copper, hold/danger), sticky steps rail, dialog styling, focus-visible outline, 800px breakpoint.

## 4. Tooling constraints

- `/home/openstatestack/.local/node/bin`: **node v22.12.0**, npm 10.9.2; global packages only corepack+npm.
- In `web-installer`: `npx tsc` → TypeScript **5.7.3**, `npx tsx` → **4.19.3** — both confirmed working (local devDeps). `npm test` = `tsc --noEmit && tsx --test`.
- **No Next.js or Astro CLI installed anywhere obvious** (global npm empty of frameworks; no framework package.json in apps/ or vendor/guardtalk).
- Wizard serve is plain `python3 -m http.server 4173`; wizard build is bare `tsc -p tsconfig.wizard.json`.

## 5. Contradictions & gaps vs the new build prompt

| Item | Existing tree says | New prompt wants | Flag |
|---|---|---|---|
| **Live flash** | DEC-009: dry-run-only HOLD (`LiveExecuteHoldError` on execute/lock for non-dry-run transports); `LIVE_FLASH_CLAIMED=false` | Installer performs real flashing flows | ⚠️ Direct conflict — lifting requires explicit decision superseding DEC-009 + evidence-doc update (`docs/qa/Q-WEBINSTALL-DRYRUN-ONLY_EVIDENCE.md`) |
| Site codebase | None exists; Q-02/D-009 record absence | os.guardtalk.io codebase with routes/tokens/status.json/lib/lint/onion target | Prompt's referenced sources (`GuardTalkOS_Web_Brief_v1_0.md`, build prompt v1_0, brand_book.html) are absent — BLOCKING per QUESTIONS_FOR_HUMAN Q-01..Q-03 |
| Device matrix | Allowlist = tokay, akita only (rango hidden/experimental per WEB_INSTALLER.md ADR) | Executive Summary also grounds rango | Minor — extend allowlist deliberately |
| CSP posture | Single-page wizard served over python http.server; D-006 defines zero-runtime-network CSP for the future page | Same CSP demanded | Aligned, not yet implemented as CI no-connect gate |
| Docs to reuse | `FLASH.md` convention: H1 title w/ parenthetical scope → bold context lines → `## Build / Verify / Flash / On-device checks` sections, fenced bash, terse bullets. Playbook-style kin: `RANGO_FLASH.md` (**Device/Lunch/Bundle/Script header table**, `## Distinct…`, `## Build + stage`, warnings in bold). QA evidence lives in `docs/qa/Q-*_EVIDENCE.md` / `A-*_AUDIT.md` pairs | playbook-installer-release.md, playbook-key-custody.md | Follow FLASH/RANGO_FLASH heading pattern; place playbooks under `vendor/guardtalk/docs/`; note there is **no repo-root `docs/`** |

Also relevant governance context: `DECISION_LOG.md` D-001..D-010 pre-taken decisions (D-004 no OTA while alpha; D-006 CSP; D-007 key custody) and `QUESTIONS_FOR_HUMAN.md` Q-04..Q-12 placeholders (`// confirm` fingerprint, onion address, codename matrix, partition chains) are already tracked — Phase 2 should inherit rather than re-ask.