# QA Evidence — Q-WEBINSTALL-DEVICES-PICKER

**Task:** `Q-WEBINSTALL-DEVICES-PICKER` (independent rematch of picker / `/install` copy / product gate)  
**Date:** 2026-09-16T07:45:33Z  
**Agent:** QA_ENGINEER (Panel 4 / `aegis-qa-engineer`)  
**Depends:** `F-WEBINSTALL-DEVICES-PICKER` ✅ APPROVED (Architect 2026-09-16T07:42:00Z)  
**DEC:** DEC-WEBINSTALL-015  
**Verdict:** **PASS (static / host)** — Overlay **HOLD**. Hosted `channels/rango/` live pack **HOLD/INFO**. **Not live-flash GO. Not boot-green.** Status → **REVIEW** (never APPROVED).

Independent rematch. Frontend report and Architect rematch note were **not trusted**. Commands were re-run. Guardian MCP/HTTP **not called** (Gate -1 in-process). Product implementation was **not edited**. `routes:build` was **not** run. No USB. No Chromium installed. No new tests (existing coverage sufficient).

GIP-0 VERIFIED: Loaded `.memory-bank/`, `AGENTS.md`, `.aegis/governance/` (24 laws + 11 gates). Governance acknowledged.  
Gate 5: **HUMAN SKIP** (MCP absent; score not fabricated).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Picker offers **exactly** tokay, akita, komodo, rango (Pixel 9 / 8a / 9 Pro XL / 10 Pro Fold) | **PASS** | `lib/ui/offered-devices.ts` `WIZARD_DEVICES`; wizard re-export; dist copies; tests `picker offers tokay, akita, komodo, and rango` |
| 2 | Single source `lib/ui/offered-devices.ts` `WIZARD_DEVICES`; `wizard/devices.ts` re-exports | **PASS** | `wizard/devices.ts` imports `../lib/ui/offered-devices.js`; does not define its own array |
| 3 | Rango chip = **EXPERIMENTAL · BOOT HOLD** (not SUPPORTED-green) | **PASS** | `statusChipWord("experimental")` = that string; table uses `chipKind = caution` (`chip-caution` / `gl-badge--warning`), not `verified`/`gl-badge--success` |
| 4 | No “rango stays hidden” in product source or dist | **PASS** | `rg … wizard routes lib dist/site` → `NO hide-rango` |
| 5 | Product mismatch stops **before write** | **PASS** | `install-app.ts` `device-matched` dispatches `product-mismatch`; `flashNow` returns before `runFlashPlan`; orchestrator `assertProduct` on connect/executePlan throws `WrongProductError` (rango-on-tokay-channel test) |
| 6 | Unstamped shiba/husky/caiman/tegu/comet not offered | **PASS** | not in `WIZARD_DEVICES`; wizard `selectDevice` throws; hosted URL rejects |
| 7 | D-006 exact CSP; dist grep clean of remote CSS/fonts / design.guardtalk.io | **PASS** | `csp.ts True`; 6/6 `D006_OK`; `ZERO remote refs` |
| 8 | Suite green; `LIVE_FLASH_CLAIMED=false`; `?sim=1` still SIMULATION | **PASS** | tsc 0; priority **84/84**; full **328 pass / 1 skip / 0 fail**; `src/types.ts:119`; `SIM_LABEL = "SIMULATION"` |
| 9 | Overlay | **HOLD** | `DISPLAY` unset; no Chromium/Firefox; browser not installed; missing overlay is **not FAIL** |
| 10 | Hosted `channels/rango/` live pack | **HOLD/INFO** | directory absent; allowlist still accepts `hostedChannelBase("rango")` = `../channels/rango/` — not this card FAIL |
| 11 | No live-flash PASS / no boot-green PASS | **HOLD** (honesty) | `LIVE_FLASH_CLAIMED=false`; rango copy chips experimental / boot HOLD |

## Verification commands (raw)

Cwd: `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer`  
`PATH` prefixed with `/home/oss-c1/.cursor-server/bin/linux-x64/0c32194e3fb5ffaced9fb36430b860ec301e1fc0`  
`npx` **not used**. `routes:build` **not run**.

```text
===== WHICH NODE/TSC/TSX =====
/home/oss-c1/.cursor-server/bin/linux-x64/0c32194e3fb5ffaced9fb36430b860ec301e1fc0/node
./node_modules/.bin/tsc
./node_modules/.bin/tsx
v24.18.1
NPX_NOT_USED

===== TSC --noEmit =====
TSC_EXIT=0

===== PRIORITY SUITE =====
./node_modules/.bin/tsx --test test/wizard-gating.test.ts test/route-install-early.test.ts test/route-install-late.test.ts test/hosted-channel.test.ts test/orchestrator.test.ts
ℹ tests 84
ℹ suites 0
ℹ pass 84
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 4222.132767
PRIORITY_EXIT=0

===== FULL SUITE test/*.test.ts =====
./node_modules/.bin/tsx --test test/*.test.ts
ℹ tests 329
ℹ suites 0
ℹ pass 328
ℹ fail 0
ℹ cancelled 0
ℹ skipped 1
ℹ todo 0
ℹ duration_ms 8092.092435
FULL_EXIT=0
# skip: pagehide hook: installs and uninstalls cleanly when window exists  # SKIP (Node, no window)

===== LIVE_FLASH_CLAIMED =====
119:export const LIVE_FLASH_CLAIMED = false;

===== D-006 =====
csp.ts True
D006_OK index.html
D006_OK install/index.html
D006_OK install/update/index.html
D006_OK install/verify-device/index.html
D006_OK install/recover/index.html
D006_OK threat-model/index.html

===== hide-rango grep =====
NO hide-rango

===== remote refs grep =====
ZERO remote refs
```

D-006 string (exact): `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`

Priority named tests of record for this card:

- `picker offers tokay, akita, komodo, and rango` — PASS
- `step 0 renders posture pill, targets table…` (HOLD copy + no hide-rango) — PASS
- `product gate: mismatch stops BEFORE any write — zero flash commands in transcript` — PASS
- `mismatched product (rango on tokay channel) is rejected on connect` — PASS
- `hosted channel URL is per advertised product` (`../channels/rango/`) — PASS
- `sim mode: ?sim=1 and env switch both activate` — PASS
- `suite does not claim a live-flash PASS` — PASS

`pytest platform/tests` N/A (web-installer TypeScript card).

## Independent rematch (do not trust Frontend)

### Picker IDs (single source)

`lib/ui/offered-devices.ts` `WIZARD_DEVICES`:

| id | deviceName | status | chip word |
|----|------------|--------|-----------|
| tokay | Pixel 9 | supported | SUPPORTED |
| akita | Pixel 8a | supported | SUPPORTED |
| komodo | Pixel 9 Pro XL | supported | SUPPORTED |
| rango | Pixel 10 Pro Fold | experimental | EXPERIMENTAL · BOOT HOLD |

Rango picker label: `Pixel 10 Pro Fold (rango) — experimental / boot HOLD`.

`wizard/devices.ts` re-exports `WIZARD_DEVICES` from `../lib/ui/offered-devices.js` (no second array). Dist mirrors:

- `dist/lib/ui/offered-devices.js` — same four ids
- `dist/site/lib/ui/offered-devices.js` — same four ids
- `dist/wizard/devices.js` — re-export only
- `dist/site/install/early-steps.js` `SUPPORTED_TARGETS = WIZARD_DEVICES.map(...)`
- `dist/site/install/late-steps.js` `TARGET_PRODUCTS = offeredProductIds()`
- `dist/site/src/types.js` `ALLOWED_PRODUCTS = ["tokay", "akita", "komodo", "rango"]`

Unstamped `shiba` / `husky` / `caiman` / `tegu` / `comet` are **not** in `WIZARD_DEVICES`.

### Rango HOLD copy (not SUPPORTED-green)

```text
statusChipWord: return status === "supported" ? "SUPPORTED" : "EXPERIMENTAL · BOOT HOLD"
targetTableHtml: chipKind = target.status === "supported" ? "neutral" : "caution"
makeChip(..., "caution") → class chip-caution gl-badge--warning  (not chip-verified / gl-badge--success)
advertisedNote: "rango is advertised as experimental / boot HOLD — not production-boot-green. caiman, shiba, husky, tegu, and comet stay unstamped and are not offered."
```

No `rango stays hidden` in `wizard/`, `routes/`, `lib/`, or `dist/site/`.

### Product mismatch stops before write

```text
routes/install/install-app.ts
398:    if (session.deviceProduct !== session.selectedProduct) {
399:      dispatch({ type: "stop", step: 5, condition: "product-mismatch" });
462:  if (session.deviceProduct !== session.selectedProduct) {
463:    session.notice = "Device product does not match the selected channel. Flash stopped before any write.";
# flashNow returns here — runFlashPlan is not called

src/orchestrator.ts
57:  async connect(): Promise<void> {
60:    await this.assertProduct();
75:  async executePlan(...): Promise<void> {
78:    await this.assertProduct();
110:  private async assertProduct(): Promise<void> {
114:      throw new WrongProductError(product);
```

`expected` / `targetProduct` in product **source** (`routes/`, `lib/`, `wizard/`) is not hardcoded `"tokay"`; route session uses `session.selectedProduct`. Test fixtures may still use tokay as a sample product.

Test: `product gate: mismatch stops BEFORE any write — zero flash commands in transcript` — PASS (panther vs tokay; `flashCommands(log.lines).length === 0`).  
Test: `mismatched product (rango on tokay channel) is rejected on connect` — PASS (`WrongProductError`).

### Overlay / hosted pack / honesty

```text
DISPLAY=<unset>
WAYLAND_DISPLAY=<unset>
no chromium / chromium-browser / google-chrome / firefox / playwright-cli
tty=not a tty

CHANNELS_RANGO_DIR=no
DIST_CHANNELS_RANGO=no
DIST_SITE_CHANNELS_RANGO=no
```

Overlay missing is **HOLD**, not FAIL. Hosted rango URL allowlist accepts rango; live pack on disk is operator follow-on.

`LIVE_FLASH_CLAIMED = false` (`src/types.ts:119`). `SIM_LABEL = "SIMULATION"`; `isSimMode("?sim=1")` true. **No live-flash PASS. No boot-green PASS. No USB.**

## Tests

No new test files this session. Existing tests already pin picker IDs, HOLD copy, hide-rango absence, mismatch-before-write, rango-on-tokay `WrongProductError`, hosted rango URL, D-006, and `LIVE_FLASH_CLAIMED`.

- Pre-existing full suite: 329 tests / 328 pass / 1 skip (pagehide, Node)
- Post-session: same counts (no tests added/deleted)
- Tests modified/deleted: **NONE**

## Security (Gate 3)

- No hardcoded credentials/secrets in picker/copy/product-gate sources reviewed
- CSP D-006 `connect-src 'none'` on 6/6 dist HTML pages
- Zero remote CSS/font/`design.guardtalk.io` refs in `dist/site`
- Product mismatch fail-closed before any flash write

## Honesty

- Overlay HOLD (no browser). Hosted `channels/rango/` pack HOLD/INFO.
- Not live-flash GO. Not rango boot-green.
- This QA panel never APPROVED. No git commit. No USB.
- Architect rematch-APPROVED the owner Q card at 2026-09-16T07:48:00Z (recorded here as fact, not issued by this panel).

## Independent rematch (2026-09-16T07:48:29Z)

Second QA session rematched the parent packet without trusting this file or the Frontend report. Product code still untouched. `routes:build` still not run.

```text
TSC_EXIT=0
parent packet tsx wizard-gating + route-install-early: tests 46 / pass 46 / fail 0
priority 5-file: tests 84 / pass 84 / fail 0 / PRIORITY_EXIT=0
full test/*.test.ts: tests 329 / pass 328 / fail 0 / skipped 1 / FULL_EXIT=0
skip: pagehide hook: installs and uninstalls cleanly when window exists  # SKIP
LIVE_FLASH_CLAIMED = false  (src/types.ts:119)
csp.ts True; D006_OK ×6
NO hide-rango (wizard/routes/lib/dist/wizard/dist/site/dist/lib)
ZERO remote refs (dist/site)
DISPLAY unset; no host Chromium/Firefox; overlay HOLD
CHANNELS_RANGO_DIR=no  (HOLD/INFO)
flashNow mismatch_idx < runFlashPlan_idx  (before_write True)
```

Parent `grep EXPERIMENTAL dist/lib/ui/offered-devices.js dist/site/install/early-steps.js`:
- `dist/lib/ui/offered-devices.js:33` `EXPERIMENTAL · BOOT HOLD` (also `dist/site/lib/ui/offered-devices.js:33`)
- `dist/site/install/early-steps.js` has **no** literal `EXPERIMENTAL` token — it imports `statusChipWord` and carries copy `experimental / boot HOLD` at lines 57 and 135. Not a FAIL: HOLD chip word is the catalog function.

Dist `WIZARD_DEVICES` ids: tokay, akita, komodo, rango (rango `status: "experimental"`).
