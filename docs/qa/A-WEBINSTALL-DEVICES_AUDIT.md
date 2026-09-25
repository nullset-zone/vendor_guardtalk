# A-WEBINSTALL-DEVICES — Independent Audit (full)

- **Task:** A-WEBINSTALL-DEVICES (`audit_scope: full`)
- **Auditor:** AEGIS Independent Auditor (Panel 5). Read-only. No product / test / CSS / TS / packer / doctrine edits. No git commit/push. Never USB-flash. Never APPROVED.
- **Timestamp:** 2026-09-16T07:54:00Z (host `date -u` 2026-09-16T07:53:44Z).
- **Authority:** owner-root `TASK_QUEUE.md` (worktree `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`). `.agent-comm/TASK_QUEUE.md` is derived.
- **DEC:** DEC-WEBINSTALL-015 (Gate 0). Does not supersede rango RCA STOP, Pixel 9 CLI KEEP, DEC-009, or DEC-WEBINSTALL-012.
- **Depends on (queue text):** Q-WEBINSTALL-DEVICES-INVENTORY APPROVED, Q-WEBINSTALL-DEVICES-PICKER APPROVED. **Prior T/F/Q reports and Architect rematch notes were not trusted.** Product source, dist, stamps, packer, schema, docs, and tests were rematched this session. Tests and packer `--self-test` were **re-run here**.
- **Status:** **REVIEW only.** Auditor does not APPROVE.

## Gate -1 / Gate 5

- Guardian MCP / HTTP / `aegis-verifier`: **not called**.
- Local YAML readable: `.aegis/governance/gates/gate_neg1_guardian_first.yaml` plus **24** law YAML files and **11** gate YAML files under `.aegis/governance/`. AGENTS.md loaded.
- **In-process Gate -1 ACK:** scope = full static rematch of DEC-WEBINSTALL-015 advertise set vs image-ready desktop-flash stamps; rango selectable HOLD not boot-green; D-006 + `LIVE_FLASH_CLAIMED=false`; mismatch-before-write; DEC-012 custody spine. Forbidden: product edits, commit/push, USB flash, `routes:build`, fabricating Gate 5 scores, USB PASS / live-flash GO / boot-green claim.
- `ultimate_critique` **TOOL UNAVAILABLE**. Gate 5 **HUMAN SKIP** — **no numeric score fabricated**.

**GIP-0 VERIFIED: AEGIS audit workflow active.**

---

## Final audit verdict: **PASS (static) with residuals** — USB HOLD, overlay HOLD, DEC-009 HOLD, **not boot-green**

Advertised web set **equals** image-ready `*-latest` stamps with `SHA256SUMS`: **tokay, akita, komodo, rango**. Unstamped `shiba` / `husky` / `caiman` / `tegu` / `comet` have no `*-latest` and are rejected. `rango-latest` is still `rango-20260802-130756` (symlink inode **193110354**). Rango is **selectable** as experimental / boot HOLD on picker, `/install` table, allowlist, packer, schema, and channel docs. No silent rango **production-boot-green** claim on those surfaces.

| Severity | Count (this rematch) |
|----------|------:|
| BLOCK | 0 |
| CRITICAL | 0 |
| HIGH (new) | 0 |
| MEDIUM (residual; not this-wave FAIL) | 1 |
| LOW | 3 |
| INFO / HOLD | 6 |

Architect may **APPROVE this card as a static close of DEC-WEBINSTALL-015 advertise/picker honesty**. Do **not** convert REVIEW/APPROVE into USB GO, live-flash GO, or rango boot-green. Do **not** waive DEC-009. Do **not** retarget `rango-latest` off `130756`. **USB PASS is not claimed.** Overlay was not exercised.

---

## Independent rematch this session (do not trust T / F / Q / Architect)

Host shell **worked**. Commands below were executed here. Q evidence files were read only as pointers, then re-proven against product trees.

| Check | Result |
|-------|--------|
| `latest` → `tokay-20260725-102506` inode **193110379** + `SHA256SUMS` | **PASS** |
| `akita-latest` → `akita-20260725-101434` inode **193110357** + `SHA256SUMS` | **PASS** |
| `komodo-latest` → `komodo-20260915-063833` inode **193110380** + `SHA256SUMS` | **PASS** |
| `rango-latest` → `rango-20260802-130756` inode **193110354** + `SHA256SUMS` | **PASS** (not retargeted) |
| `shiba-latest` / `husky-latest` / `caiman-latest` / `tegu-latest` / `comet-latest` | **ABSENT** |
| Source `ALLOWED_PRODUCTS` | `["tokay", "akita", "komodo", "rango"]` (`src/types.ts:3`) |
| Dist `ALLOWED_PRODUCTS` (`dist/src/types.js`, `dist/site/src/types.js`) | same four; **not** the stale three-item array Q-INVENTORY recorded |
| Schema `product` / `advertisedDevices` enum + `maxItems` 4 | **PASS** |
| Packer `ADVERTISED_DEVICES=(tokay akita komodo rango)` | **PASS** |
| `WIZARD_DEVICES` / `SUPPORTED_TARGETS` / `TARGET_PRODUCTS` | tokay+akita+komodo **supported**; rango **experimental** |
| Hosted URL `hostedChannelBase("rango")` | `../channels/rango/` (allowlist accepts) |
| Live pack `web-installer/channels/rango/` | **ABSENT** → **HOLD/INFO** |
| Live pack `web-installer/channels/komodo/` | **ABSENT** → **HOLD/INFO** (tokay+akita packs present, 2026-08-20) |
| Hide-rango string `rango stays hidden` in wizard/routes/lib/src/dist | **absent** |
| Positive rango boot-green claim (not the documented negation) | **absent** on picker/table/allowlist/packer/`WEB_INSTALLER_CHANNEL.md` |
| `assertAllowedProduct("rango")` passes; shiba/husky/caiman/tegu/comet throw `WrongProductError` | **PASS** (re-run tests) |
| rango-on-tokay-channel | `WrongProductError` on `connect()` (`test/orchestrator.test.ts`) — mismatch, not hide-rango |
| `/install` `flashNow` mismatch | stops **before** `runFlashPlan` (`install-app.ts:462-465`) |
| `device-matched` mismatch | `stop` / `product-mismatch` (`install-app.ts:398-400`) |
| `expected:` from `session.selectedProduct` (not hardcoded `"tokay"` in product apps) | **PASS** (`install-app.ts:165`, `update-app.ts:21`) |
| D-006 exact CSP | **PASS** 5/5 route `page.html` + 6/6 `dist/site` HTML |
| `dist/site` remote CSS/fonts / `design.guardtalk.io` | **ZERO** |
| `LIVE_FLASH_CLAIMED` | `false` (`src/types.ts:119`, dist JS L11) |
| DEC-009 `executePlan`/`lock` | dry-run only (`orchestrator.ts:98-101`); live tests HOLD |
| `FLASH_ORDER` | `["firmware", "avb_custom_key", "os"]` (`types.ts:7`) |
| `proveVbmetaUserSigned` | present (`user-anchor.ts:16-33`; `flash-runner.ts:189`; `update-route.ts:558`) |
| `tsc --noEmit` | **0** |
| `tsx --test test/*.test.ts` | **329 tests / 328 pass / 1 skip / 0 fail** |
| Packer `bash -n` + `--self-test` | **SELF_TEST_OK** (rango packs; shiba/husky/caiman reject) |
| Overlay / `:8080` | **HOLD** (port not listening; no browser) |
| USB / `adb` / live flash | **HOLD**. **Not invented PASS** |
| Git history of custody files | **HOLD** (`fatal: not a git repository` at this mount). Spine rematched by content, not `git log` |

`pytest platform/tests`: N/A (web-installer / stamp card, not AEGIS Python platform). `routes:build` **not** run.

---

## 1. Advertise set vs image-ready stamps

Fail-closed rule: advertise only products with a desktop-flash `*-latest` (or `latest`) stamp **and** `SHA256SUMS`.

```text
releases/desktop-flash/latest        -> tokay-20260725-102506   inode=193110379  SHA256SUMS=YES
releases/desktop-flash/akita-latest  -> akita-20260725-101434    inode=193110357  SHA256SUMS=YES
releases/desktop-flash/komodo-latest -> komodo-20260915-063833  inode=193110380  SHA256SUMS=YES
releases/desktop-flash/rango-latest  -> rango-20260802-130756  inode=193110354  SHA256SUMS=YES
```

No `shiba-latest`, `husky-latest`, `caiman-latest`, `tegu-latest`, or `comet-latest`. Historical rango dated stamps exist (including later than 130756); **none** of those retarget `rango-latest`. DEC-WEBINSTALL-015 bind holds.

Product sources independently rematched to the same four ids:

| Surface | Path | Set | Rango posture |
|---------|------|-----|---------------|
| Allowlist | `src/types.ts:3` | tokay, akita, komodo, rango | comment L1: experimental / boot HOLD, not production-boot-green |
| Dist allowlist | `dist/src/types.js:2`, `dist/site/src/types.js:2` | same | same |
| Schema enum | `schema/channel-manifest.schema.json:32,39` | same; `maxItems` 4 | description: image-ready, not production-boot-green |
| Packer | `pack-webinstall-channel.sh:27` | `ADVERTISED_DEVICES=(tokay akita komodo rango)` | header L8-10 HOLD |
| Hosted packer | `pack-wizard-hosted-channels.sh:25` | packs rango from `rango-latest` | comment L5 HOLD |
| Picker | `lib/ui/offered-devices.ts:20-29` | four ids | `status: "experimental"`; label includes `experimental / boot HOLD` |
| Dist picker | `dist/lib/ui/offered-devices.js`, `dist/site/lib/ui/offered-devices.js` | same | `statusChipWord` → `EXPERIMENTAL · BOOT HOLD` |
| `/install` table | `routes/install/early-steps.ts:79-83,177-195` | `SUPPORTED_TARGETS` mapped from `WIZARD_DEVICES` | rango chip `caution`, not SUPPORTED |
| Late-step gate | `routes/install/late-steps.ts:47` | `TARGET_PRODUCTS = offeredProductIds()` | match vs selected, not hardcoded tokay |
| Hosted URL | `wizard/hosted-channel.ts:7-11` | `../channels/${product}/` iff `isAllowedProduct` | rango URL accepted; live dir may be missing |
| Channel docs | `docs/WEB_INSTALLER_CHANNEL.md:27-36` | four products | boot-green **no** |

**Verdict:** advertise set **matches** stamps. No extra advertised device without a SHA256SUMS stamp.

---

## 2. Rango honesty (selectable HOLD, not production-boot-green)

Rango **is** offered. That is the DEC-WEBINSTALL-015 change vs DEC-PORT-KOMODO-004 / DEC-RANGO-REMEDIATE-001 hide-rango.

Hold copy is present, not a silent SUPPORTED-green. `lib/ui/offered-devices.ts:24-29` rango `status: "experimental"`; label includes `experimental / boot HOLD`. `/install` table (`early-steps.ts:177-195`): rango row `data-status="experimental"`, chip `EXPERIMENTAL · BOOT HOLD`, `chip-caution`. Wizard chrome (`wizard/index.html:16-17,46,98,173`) names rango with HOLD. `wizard/main.ts:119-121` logs a warn when the loaded channel is experimental. Packer (`pack-webinstall-channel.sh:44-45`): image-ready and packable, not production-boot-green.

`grep` for `rango stays hidden` under `wizard/`, `routes/`, `lib/`, `src/`, `dist/`: **no hits**. Q-INVENTORY leftover-dist claim is **stale vs this rematch** — dist now matches source.

Historical QA scripts still pin hide-rango (INFO-3). That is **not** this wave’s silent lie.

**Verdict:** no silent rango production-boot claim on picker / table / allowlist / packer / `WEB_INSTALLER_CHANNEL.md`. Residuals in older ADR / `status.json` documented below (LOW), not production UI.

---

## 3. D-006 + DEC-009 / `LIVE_FLASH_CLAIMED=false`

D-006 canonical (`lib/claims/csp.ts:3-4`):

```text
default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'
```

Exact string present in all 5 route `page.html` files and all 6 `dist/site` HTML pages. `rg` for `design.guardtalk.io`, Google Fonts, `@import url` under `dist/site`: **empty**.

`LIVE_FLASH_CLAIMED = false` at `src/types.ts:119` and compiled dist. `status.json` `flashCapability.liveFlashClaimed` is `false`. Orchestrator `assertDryRunOnly` still throws `LiveExecuteHoldError`. Wizard HTML DEC-009 banner unchanged in meaning.

**Not a live-flash GO.**

---

## 4. DEC-WEBINSTALL-012 custody spine (content rematch)

Git is **not** a repository at this mount, so “unchanged this wave” cannot be proven by `git log`. Content rematch:

| Invariant | Evidence this session |
|----------|----------------------|
| Flash order | `FLASH_ORDER = ["firmware", "avb_custom_key", "os"]` (`types.ts:7`); schema prefixItems same; packer header DEC-WEBINSTALL-006 |
| `proveVbmetaUserSigned` | `lib/verify/user-anchor.ts:16-33` — enrolled pkmd, never GuardTalk release key; called from `flash-runner.ts:189` and `update-route.ts:558` **before write** |
| Install-state mismatch | `STOP_REASONS.PRODUCT_MISMATCH`; `machine.ts` maps `product-mismatch`; `/install` `flashNow` returns before write |
| DEC-009 | `orchestrator.ts:75-101` live execute/lock HOLD |

`/install` `flash-runner.ts` still uses its own `FIRMWARE_ORDER` / `OS_ORDER` (enrol → firmware → OS → user vbmeta). That split vs flashcore `FLASH_ORDER` is **pre-existing**. DEC-012 forbade changing it this wave.

---

## 5. Product mismatch still stops before write

Flashcore (`src/orchestrator.ts:110-115`): `getVar("product")` then `assertAllowedProduct`; if product ≠ channel manifest product → `WrongProductError`. Re-run: `mismatched product (rango on tokay channel) is rejected on connect` **PASS**. That is mismatch, not hide-rango.

`/install` (`install-app.ts:462-465`): if `deviceProduct !== selectedProduct`, notice *"Flash stopped before any write"* and return before `runFlashPlan`. `expected` is `session.selectedProduct` (`install-app.ts:165`). `update-app.ts:21` uses `deviceFromSearch`. Hardcoded `expected: "tokay"` remains only in **tests**.

---

## 6. Tests / packer this session (independent)

```text
tsc --noEmit                                          # exit 0
tsx --test test/*.test.ts                             # 328 pass / 1 skip / 0 fail
bash -n pack-webinstall-channel.sh && pack-wizard-hosted-channels.sh
bash pack-webinstall-channel.sh --self-test           # SELF_TEST_OK
```

Priority rematch (allowlist + channel + hosted-channel + orchestrator + devices-inventory + wizard-gating + route-install-early): **80/80**. Skip remains the Node `pagehide` hook (no `window`).

---

## Findings

### MEDIUM-1 — flashcore housekeeping still erases `fips` for rango (DEC-012 residual)

- **Path:** `vendor/guardtalk/web-installer/src/plan.ts:84-89`
- **Snippet:** `appendPixelHousekeeping` always queues `oem uart disable` then `erase fips` / `dpm_a` / `dpm_b`. Comment says “tokay + akita + komodo share UART/FIPS/DPM cleanup”.
- **Why wrong:** CLI `flash-from-remote.sh` erases `fips` on tokay/akita/komodo only; **rango does not**. Function is unconditional, so a rango flashcore plan (now selectable) still queues `erase fips`.
- **Why not this-card FAIL:** DEC-WEBINSTALL-012 forbade changing flash order this wave; DEC-009 live execute remains HOLD. Not a silent boot-green claim.
- **Suggested fix (recommendation only):** follow-on — branch housekeeping on product when Architect binds a flashcore/DEC-009 lift.

### LOW-1 — `status.json` still lists rango as a production `target`

- **Path:** `vendor/guardtalk/web-installer/status.json:23-24`
- **Snippet:** `"targets": ["tokay", "rango"]`, `"experimentalTargets": ["akita"]`
- **Why wrong:** DEC-015 set is tokay+akita+komodo supported, rango experimental. File puts rango in `targets` (no HOLD), akita as experimental, komodo missing.
- **Mitigation:** `posture.ts` uses only `installer` / `release_state`. `liveFlashClaimed` is still `false`.
- **Suggested fix:** align unused target fields with `WIZARD_DEVICES`.

### LOW-2 — historical ADR still says hide-rango until boot-green

- **Path:** `vendor/guardtalk/docs/WEB_INSTALLER.md:11` and `:390`
- **Snippet:** *"`rango` hidden / experimental — not production-bootable."* … *"Do not add rango to the web allowlist until Architect re-binds boot-green."*
- **Why wrong:** DEC-WEBINSTALL-015 added rango to the allowlist as experimental / boot HOLD.
- **Suggested fix:** stamp ADR superseded-by DEC-015 for the allowlist clause; keep not-boot-green.

### LOW-3 — wizard rejected-device sentence omits tegu/comet

- **Path:** `vendor/guardtalk/web-installer/wizard/index.html:98`
- **Snippet:** *"Pixel 8 (shiba), Pixel 8 Pro (husky), and caiman are rejected."*
- **Why wrong:** `/install` note lists tegu and comet; allowlist rejects them. Wizard prose is one clause short. Devices are still not selectable.
- **Suggested fix:** add tegu/comet to the wizard note.

### INFO-1 — hosted live packs: `channels/rango/` and `channels/komodo/` ABSENT

- **Path:** `vendor/guardtalk/web-installer/channels/` (tokay + akita only, 2026-08-20); `wizard/hosted-channel.ts:7-11`; `pack-wizard-hosted-channels.sh:22-25`
- **Why:** allowlist accepts `../channels/rango/` and `../channels/komodo/`. Live trees are not packed. Channel docs say do not run hosted packer against live multi-GiB stamps unless an operator asks.
- **Disposition:** **HOLD/INFO** as dispatched for rango. Same HOLD for **komodo** (advertised `supported`, pack missing). Fetch would fail; not silent boot-green.

### INFO-2 — overlay HOLD

- `:8080` not listening. No browser overlay. Static HTML + unit tests rematched; visual HOLD.

### INFO-3 — historical hide-rango QA scripts are superseded residuals

- **Paths:** `docs/qa/verify_rango_boot_remediate_static.sh:300-339`; `verify_pixel9_nonregression_static.sh:398-422`
- **Why not this-wave lie:** those cards closed under hide-rango DECs. Current product source advertises rango with HOLD. Re-running those scripts today would FAIL for the wrong reason.
- **Suggested fix:** mark superseded, or pin “rango experimental, not `status: supported`”.

### INFO-4 — packer `--self-test` unstamped loop is shiba/husky/caiman only

- **Path:** `pack-webinstall-channel.sh:459`
- **Mitigation:** `assert_advertised_product` still rejects tegu/comet; TS tests cover them.

### INFO-5 — `dist/wizard/index.html` absent

- Compiled wizard JS exists. Wizard HTML is `wizard/index.html` (source). Not hide-rango.

### INFO-6 — USB / live-flash / boot-green HOLD

- No USB. `LIVE_FLASH_CLAIMED=false`. Rango RCA `0xfc` not waived. **Do not invent USB PASS.**

---

## Secrets / anti-patterns (scoped)

Packer self-test writes a synthetic `BEGIN PRIVATE KEY` blob then **fails closed**. No live `.pem`/`.pk8`/`.env` added on advertise surfaces.

---

## Governance / queue

- Owner-root A card was `DISPATCHED` at audit start. This report moves it to **REVIEW** only.
- Doctrine / `governance/laws` / `governance/gates` **not edited**.
- Gate 6 Delivery: human Architect approval still required. Auditor must not APPROVE.

---

## Manual Gate 5 (HUMAN SKIP — no score)

Advertise set == stamps: yes. Rango selectable HOLD, not boot-green on product UI/packer/schema: yes. Dist matches source: yes. D-006 exact; `LIVE_FLASH_CLAIMED=false`: yes. Mismatch-before-write + rango-on-tokay `WrongProductError`: yes. Hosted rango/komodo packs: documented HOLD. Overlay: HOLD. Flashcore `fips` on rango: residual MEDIUM, not silent boot-green. `status.json` / `WEB_INSTALLER.md`: LOW docs. No USB PASS invented.

---

## Acceptance criteria (auditor rematch)

- [x] Written audit; advertise set matches stamps (residuals documented)
- [x] No silent rango production-boot claim on picker / table / allowlist / packer / channel docs
- [x] D-006 exact + `LIVE_FLASH_CLAIMED=false`

---

*AEGIS Independent Auditor (Panel 5). Read-only. No commit. No USB. Not APPROVED.*
