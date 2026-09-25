# QA Evidence — Q-WEBINSTALL-DEVICES-INVENTORY

**Task:** `Q-WEBINSTALL-DEVICES-INVENTORY` (independent rematch of stamp inventory + allowlist + packer + schema)  
**Date:** 2026-09-16T07:33:28Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-WEBINSTALL-DEVICES-INVENTORY` ✅ APPROVED (Architect 2026-09-16T07:20:00Z)  
**Verdict:** **PASS (static / host)** — USB flash **HOLD**. Overlay **HOLD**. **Not live-flash GO. Not boot-green.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend report and Architect rematch note were not trusted. Guardian MCP/HTTP **not called** (dispatch Gate -1 in-process). Product implementation was not edited. Closed PIXELFIX / RANGO-REMEDIATE evidence files were **not rewritten**. **Q-WEBINSTALL-DEVICES-PICKER was not rematched.** `routes:build` was **not** run.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Evidence PASS/FAIL/HOLD + raw command output | PASS | this file |
| 2 | Four latest stamps have SHA256SUMS; no extra advertised devices without stamps | PASS | tokay 19 / akita 20 / komodo 20 / rango 22 listed files exist; no `shiba/husky/caiman/tegu/comet-latest` |
| 3 | Packer/schema/allowlist match DEC-WEBINSTALL-015 | PASS | `ALLOWED_PRODUCTS` + schema enum + `ADVERTISED_DEVICES` = tokay,akita,komodo,rango; rango packs; shiba/husky/caiman reject |
| 4 | `rango-latest` still `130756` | PASS | `rango-20260802-130756` inode **193110354** |
| 5 | No live-flash PASS | **HOLD** (honesty) | `LIVE_FLASH_CLAIMED=false`; USB not executed |
| 6 | No boot-green PASS | **HOLD** (honesty) | copy chips experimental / boot HOLD; no positive boot-green claim |

## Static script (suite of record)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_webinstall_devices_inventory_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=50 HOLD_COUNT=6 FAIL=0 EXIT=0
# final rematch 2026-09-16T07:33:28Z
```

`pytest platform/tests` N/A (web-installer TypeScript / bash packer card).

## Independent rematch (do not trust engineer report)

### Stamp inventory

```text
$ readlink releases/desktop-flash/latest releases/desktop-flash/akita-latest \
    releases/desktop-flash/komodo-latest releases/desktop-flash/rango-latest
tokay-20260725-102506
akita-20260725-101434
komodo-20260915-063833
rango-20260802-130756
READLINK_EXIT=0

$ stat -c '%i %N' releases/desktop-flash/rango-latest
193110354 'releases/desktop-flash/rango-latest' -> 'rango-20260802-130756'

$ stat -c '%i %N' releases/desktop-flash/latest \
    releases/desktop-flash/akita-latest \
    releases/desktop-flash/komodo-latest \
    releases/desktop-flash/rango-latest
193110379 'releases/desktop-flash/latest' -> 'tokay-20260725-102506'
193110357 'releases/desktop-flash/akita-latest' -> 'akita-20260725-101434'
193110380 'releases/desktop-flash/komodo-latest' -> 'komodo-20260915-063833'
193110354 'releases/desktop-flash/rango-latest' -> 'rango-20260802-130756'

$ test -f releases/desktop-flash/rango-latest/SHA256SUMS   # SHA256SUMS_OK
$ test -f releases/desktop-flash/latest/SHA256SUMS         # SHA256SUMS_OK
$ test -f releases/desktop-flash/akita-latest/SHA256SUMS   # SHA256SUMS_OK
$ test -f releases/desktop-flash/komodo-latest/SHA256SUMS  # SHA256SUMS_OK
```

SHA256SUMS present on all four pointers. Listed files exist (not rehashed — multi-GiB; existence rematch only):

| Pointer | Resolves to | Inode | SHA256SUMS entries | Missing listed files |
|---------|-------------|-------|--------------------|----------------------|
| `latest` | `tokay-20260725-102506` | 193110379 | 19 | 0 |
| `akita-latest` | `akita-20260725-101434` | 193110357 | 20 | 0 |
| `komodo-latest` | `komodo-20260915-063833` | 193110380 | 20 | 0 |
| `rango-latest` | `rango-20260802-130756` | **193110354** | 22 | 0 |

`find … *-latest` = `latest`, `akita-latest`, `komodo-latest`, `rango-latest` only.  
`shiba-latest` / `husky-latest` / `caiman-latest` / `tegu-latest` / `comet-latest` **absent**.

### Allowlist / schema / packer

```text
$ grep -n 'ALLOWED_PRODUCTS' vendor/guardtalk/web-installer/src/types.ts
3:export const ALLOWED_PRODUCTS = ["tokay", "akita", "komodo", "rango"] as const;
4:export type AllowedProduct = (typeof ALLOWED_PRODUCTS)[number];

$ python3 -c "import json; s=json.load(open('vendor/guardtalk/web-installer/schema/channel-manifest.schema.json')); print(s['properties']['product']['enum']); print(s['properties']['advertisedDevices']['maxItems'])"
['tokay', 'akita', 'komodo', 'rango']
4

schema advertisedDevices.items.enum = ["tokay","akita","komodo","rango"]
reservedProducts.items.not.enum = same four

$ grep -n 'ADVERTISED_DEVICES=' vendor/guardtalk/scripts/pack-webinstall-channel.sh
27:readonly ADVERTISED_DEVICES=(tokay akita komodo rango)

hosted packer: pack_one rango …/rango-latest (L25)

$ grep -n 'LIVE_FLASH_CLAIMED' vendor/guardtalk/web-installer/src/types.ts
119:export const LIVE_FLASH_CLAIMED = false;
```

Rango copy chips **experimental / boot HOLD, not production-boot-green** in `types.ts`, `allowlist.ts`, schema, packer, `WEB_INSTALLER_CHANNEL.md`. No positive boot-green claim in those inventory sources.

WrongProductError joins `ALLOWED_PRODUCTS` (`src/errors.ts`).

### Dispatch verification (raw)

Packet `tsx` + packer (2026-09-16T07:26:09Z):

```text
export PATH="/home/oss-c1/.cursor-server/bin/linux-x64/0c32194e3fb5ffaced9fb36430b860ec301e1fc0:$PATH"
cd vendor/guardtalk/web-installer
./node_modules/.bin/tsx --test test/allowlist.test.ts test/channel.test.ts test/hosted-channel.test.ts
# tests 16 / pass 16 / fail 0 / skipped 0 / TSX_PACKET_EXIT=0

./node_modules/.bin/tsx --test test/devices-inventory.test.ts
# tests 9 / pass 9 / fail 0 / skipped 0 / TSX_INVENTORY_EXIT=0

bash -n ../scripts/pack-webinstall-channel.sh          # EXIT=0
bash -n ../scripts/pack-wizard-hosted-channels.sh      # EXIT=0
bash ../scripts/pack-webinstall-channel.sh --self-test
PACK_OK … tokay / akita / komodo / rango-dev
VERIFY_OK … rango dev  files=3
WARN: ignoring secret-shaped file in stamp (will not publish): evil.pk8
SELF_TEST_OK
PACKER_SELF_TEST_EXIT=0
```

Packer `--self-test` packed synthetic **rango** (`rango-dev` present) and rejected **shiba / husky / caiman** (fail-closed allowlist text; silent unless `die`). Synthetic fixture only — not USB, not boot-green.

Hosted URL: `hostedChannelBase("rango")` → `../channels/rango/`; shiba/husky/caiman/tegu/comet throw `WizardGateError`.

### tsc (final PASS; mid-session F race is HOLD/INFO)

Final rematch 2026-09-16T07:33:28Z: `./node_modules/.bin/tsc --noEmit` **EXIT=0**. Inventory `src/` / schema paths had **no** tsc errors in any sample.

Mid-session samples during parallel `F-WEBINSTALL-DEVICES-PICKER` edits — **out of this card**, not T FAIL:

| Time (UTC) | Command | Result | Classification |
|------------|---------|--------|----------------|
| 07:26:09Z | packet `tsc --noEmit` | EXIT=2 unused imports in `routes/install/install-app.ts` (`FastbootClient`, `deviceFromSearch`, `isOfferedDevice`, `parseOfferedDevice`) | HOLD/INFO picker race |
| 07:29:22Z | rematch `tsc --noEmit` | EXIT=2 `test/route-install-late.test.ts:242` TS1128 (syntax; F mid-edit) | HOLD/INFO picker race |
| 07:33:28Z | final `tsc --noEmit` | EXIT=0 | PASS |

Do **not** treat picker-route tsc flicker as this inventory card FAIL. Allowlist/packer/schema already include rango.

## HOLD (honesty)

| HOLD | Why |
|------|-----|
| USB | `adb devices` attached list empty. No live flash executed. |
| Overlay | `DISPLAY` unset. Picker UI is **Q-WEBINSTALL-DEVICES-PICKER**. |
| No live-flash PASS | DEC-009. `LIVE_FLASH_CLAIMED=false`. |
| No boot-green PASS | DEC-WEBINSTALL-015 / DEC-RANGO-REMEDIATE-002. Rango is advertised experimental / boot HOLD. |
| Historical closed-Q verifiers | `verify_rango_boot_remediate_static.sh` case6 “rango not advertised” and `verify_pixel9_nonregression_static.sh` case7 “no rango advertise” still pin pre-DEC-015 hide-rango (DEC-PORT-KOMODO-004). **Superseded residual. Not this card FAIL.** Closed Q evidence files not rewritten. |
| Dist / served picker | `dist/src/types.js` still `ALLOWED_PRODUCTS = ["tokay", "akita", "komodo"]`. `dist/wizard/devices.js` still “Rango / shiba / husky / caiman are not offered.” `dist/site/install/early-steps.js` leftover “rango stays hidden.” **F / Q-PICKER**, not inventory FAIL. Source `wizard/devices.ts` already lists rango as experimental / boot HOLD — UI rematch still belongs to the picker card. |
| tsc mid-session | Picker-route unused-import / syntax flicker while F is IN_PROGRESS. Final tsc 0. |

## Honesty

- No USB. No live-flash PASS. No boot-green PASS.
- Product `web-installer/src/` not edited by this QA session. Packer/schema not edited by QA.
- Hosted packer **not** run against live multi-GiB stamps.
- SHA256SUMS were **not** rehashed (`sha256sum -c` of desktop-flash blobs). Existence of listed files rematched.
- Gate 5: **HUMAN SKIP** (MCP absent; score not fabricated).
- Guardian MCP/HTTP: **not called**.
- `.agent-comm/inbox/TO_ARCHITECT.md` **not replaced** by this session (Frontend is parallel). A prior QA instance did write that shared inbox; Architect should treat `TO_ARCHITECT_Q-WEBINSTALL-DEVICES-INVENTORY.md` as this card’s durable report.
- A-WEBINSTALL-DEVICES stays **BLOCKED** until this card and Q-PICKER are Architect-APPROVED.
