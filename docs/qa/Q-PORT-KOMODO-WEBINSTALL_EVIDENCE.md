# QA Evidence — Q-PORT-KOMODO-WEBINSTALL (re-dispatch)

**Task:** `Q-PORT-KOMODO-WEBINSTALL`
**Date:** 2026-09-15T08:50:00Z
**Agent:** QA_ENGINEER (Panel 4)
**Depends:** `F-PORT-KOMODO-WEBINSTALL` Architect-APPROVED 2026-09-15T08:48:00Z
**Status:** **REVIEW** (never APPROVED). **No USB.** DEC-009 HOLD. Overlay **HOLD**.
**Overall:** **PASS** on independent served-dist pin. Prior 08:18 FAIL (stale 2026-08-23 `/install/` JS) is closed by emit mtime **2026-09-15 08:42 UTC**. **Not live-flash GO.** A-PORT-KOMODO stays **BLOCKED**.

Do not trust F. Commands from `vendor/guardtalk/web-installer` unless noted.

```text
NODE=/home/oss-c1/.cursor-server/bin/linux-x64/0c32194e3fb5ffaced9fb36430b860ec301e1fc0/node
$NODE ./node_modules/typescript/bin/tsc --noEmit
# TSC_EXIT=0  (08:49:00Z)

$NODE ./node_modules/tsx/dist/cli.mjs --test --test-timeout=60000 test/*.test.ts
# tests 314 / pass 313 / fail 0 / skipped 1 / TSX_EXIT=0
# skip: pagehide hook (Node, no window)

# repo root:
bash vendor/guardtalk/scripts/pack-webinstall-channel.sh --dry-run \
  --stamp /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/komodo-latest
# DRY-RUN product=komodo  releaseId=20260915-063833  EXIT=0
```

## Pin matrix (served dist)

| # | Check | Result |
|---|--------|--------|
| 1 | `dist/site/install/early-steps.js` `SUPPORTED_TARGETS` tokay+akita+komodo `status: "supported"` | **PASS** (lines 57–61). rango **not** a member; no rango `status: "supported"`. Residual: Q-06 placeholder comment + copy that rango/caiman/shiba/husky are not advertised. |
| 2 | `dist/site/install/late-steps.js` `TARGET_PRODUCTS=["tokay", "akita", "komodo"]` | **PASS** (line 35) |
| 3 | `dist/wizard/devices.js` includes komodo | **PASS** ids tokay, akita, komodo |
| 4 | `dist/src/types.js` `ALLOWED_PRODUCTS` same; `LIVE_FLASH_CLAIMED=false` | **PASS** |
| 5 | D-006 exact CSP `connect-src 'none'` 6/6 dist HTML | **PASS** |
| 6 | tsc `--noEmit` | **PASS** 0 |
| 7 | tsx suite | **PASS** 313 / skip 1 / fail 0 |
| 8 | packer dry-run `komodo-latest` | **PASS** `product=komodo` |
| 9 | Overlay / host browser | **HOLD** — DISPLAY unset, session tty, no Chrome/Firefox binary. No invented visual PASS. |

Extra (adversarial, not in pin list): `dist/routes-js/routes/install/*` matches site lists. Dist mtimes 2026-09-15 08:42 (not 2026-08-23).

## D-006 (exact 6/6)

`default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'` in:

- dist/site/index.html
- dist/site/install/index.html
- dist/site/install/update/index.html
- dist/site/install/verify-device/index.html
- dist/site/install/recover/index.html
- dist/site/threat-model/index.html

## Honesty

- No USB. No live-flash PASS. PIXELFIX not restyled. `flash-from-remote.sh` not edited.
- A-PORT-KOMODO remains BLOCKED. DEC-009 not waived.
- pytest N/A (TS installer card). `channels:pack` not run (multi-GiB); dry-run covers stamp product.
