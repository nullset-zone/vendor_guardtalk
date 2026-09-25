# QA Evidence — Q-RANGO-BOOT-REMEDIATE

**Task:** `Q-RANGO-BOOT-REMEDIATE` (independent rematch of T-RANGO-BOOT-REMEDIATE)  
**Date:** 2026-09-16T06:50:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-RANGO-BOOT-REMEDIATE` ✅ APPROVED as **RCA STOP (not boot-green)** (Architect 2026-09-16T06:40:00Z)  
**Verdict:** **PASS (static / host)** — USB flash **HOLD**. **Not boot-green. Do not invent boot PASS.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend report was not trusted. Product flash scripts were not edited. `rango-latest` was not relinked.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent stamp / SHA / CLI `DEVICE=rango` mapping | PASS | suite case1+3+5; `DEVICE=rango` → `rango-latest` → `rango-20260802-130756` |
| 2 | `rango-latest` still `130756` (not retargeted) | PASS | `readlink` → `rango-20260802-130756`; inode **193110354** |
| 3 | tokay/akita/komodo latest inodes unchanged | PASS | **193110379** / **193110357** / **193110380** |
| 4 | SHA256SUMS for `130756` (and `145117` if present) | PASS | both **22/22 OK**, `sha256sum -c` EXIT=0 |
| 5 | next USB candidate `rango-20260803-145117` exists, **not** linked as latest | PASS | dir present; no `*-latest` symlink targets it |
| 6 | USB HOLD if no phone; do not invent boot PASS | **HOLD** | `adb devices` empty; `fastboot` missing |
| 7 | rango not in `ALLOWED_PRODUCTS` / wizard production set | PASS | source + dist: tokay+akita+komodo only |

## Static script (suite of record)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_rango_boot_remediate_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=52 HOLD_COUNT=2 FAIL=0 EXIT=0
```

Host SHA / inode / extracted `normalize_device` is the suite. `pytest platform/tests` N/A (AOSP stamp + CLI mapping card, not AEGIS Python platform).

## Independent rematch (do not trust engineer report)

### Stamp pin

```text
readlink releases/desktop-flash/rango-latest
  → rango-20260802-130756
stat -c '%i %N' releases/desktop-flash/rango-latest
  → 193110354 'releases/desktop-flash/rango-latest' -> 'rango-20260802-130756'
```

`rango-latest` is **not** `rango-20260803-145117`. Not retargeted this wave.

### Pixel 9 latest inodes (unchanged vs T-RANGO Architect rematch)

```text
193110379  releases/desktop-flash/latest        → tokay-20260725-102506
193110357  releases/desktop-flash/akita-latest  → akita-20260725-101434
193110380  releases/desktop-flash/komodo-latest → komodo-20260915-063833
```

### SHA256SUMS (independent `sha256sum -c`)

| Stamp | Files OK | EXIT |
|-------|----------|------|
| `rango-20260802-130756` | 22/22 | 0 |
| `rango-20260803-145117` | 22/22 | 0 |

No `.pem` / `.pk8` in either stamp.

### Next USB candidate (host only)

| Check | Result |
|-------|--------|
| `releases/desktop-flash/rango-20260803-145117` exists | PASS |
| `bootloader.img` / `vendor.img` present | PASS |
| any `desktop-flash` symlink → `145117` | none |
| `cmp` `145117/vendor.img` vs `rango-stock-userspace/vendor.img` | IDENTICAL (extra rematch of Backend claim) |

Historical “never flashed” is a Backend/docs claim. This session has **no phone**. QA does **not** certify flash history and does **not** invent boot PASS.

### CLI `DEVICE=rango` mapping (extracted helpers; flash body not executed)

| Hook | Result |
|-------|--------|
| header L11 | `rango (Pixel 10 Pro Fold) → releases/desktop-flash/rango-latest` |
| `apply_remote_paths` L225–226 | `auto_build` / `auto_key` = `…/rango-latest` |
| `normalize_device rango` | `rango` |
| `normalize_device RANGO` | `rango` |
| `device_pretty rango` | `Pixel 10 Pro Fold (rango)` |
| mapped dir `rango-latest/bootloader.img` | present |
| mapped symlink target | `rango-20260802-130756` |
| `DEVICE=` override die | L538 fail-closed present |
| tokay / akita / komodo | stay themselves (do not steal rango-latest) |

`ssh` inside production `apply_remote_paths` was **not** invoked (no USB, no remote side-effect).

### Advertise pin (DEC-PORT-KOMODO-004)

| Surface | Production set | rango |
|---------|----------------|-------|
| `vendor/guardtalk/web-installer/src/types.ts` L3 | `ALLOWED_PRODUCTS = ["tokay", "akita", "komodo"]` | absent |
| `wizard/devices.ts` `WIZARD_DEVICES` | tokay / akita / komodo | not offered |
| `routes/install/late-steps.ts` `TARGET_PRODUCTS` | tokay / akita / komodo | absent |
| `routes/install/early-steps.ts` `SUPPORTED_TARGETS` | tokay / akita / komodo `supported` | no `codename: "rango"` |
| dist `src/types.js` / wizard / late / early | same pin | rango not production |

Dist `SUPPORTED_TARGETS` mentions rango only as **not** a production advertised device.

### Adversarial

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| retarget | `rango-latest` → 145117 | must not | still 130756 | PASS |
| latest symlink set | any `*-latest` → 145117 | none | none | PASS |
| `DEVICE=RANGO` | uppercase | `rango` | `rango` | PASS |
| `DEVICE=caiman` / empty / unknown | unsupported | empty / die | fail-closed | PASS |
| Pixel 9 DEVICE | tokay/akita/komodo | not rango-latest | themselves | PASS |
| `ALLOWED_PRODUCTS` contains rango | production array | absent | absent | PASS |
| WIZARD / TARGET / SUPPORTED rango product | production | absent | absent | PASS |
| pem/pk8 in stamps | secrets | none | 0 | PASS |
| USB boot | no phone | HOLD not PASS | HOLD | HOLD |

### USB / overlay

```text
adb devices → header only (no device)
fastboot missing
overlay not in scope this card
LIVE_BOOT_CLAIMED=false
```

## Coverage gaps

- No live USB flash (dispatch: USB HOLD). Do not invent PASS.
- Backend “never flashed” for `145117` is **host-unverified** (no device, no flash log required this card).
- `061630` leftover debugfs / OUT sepolicy leftover checks from T-RANGO were **not** re-run here (out of Q stamp/SHA/CLI/advertise scope).
- Overlay HOLD.
- `pytest platform/tests` N/A.

## Bugs found

None that fail this card’s acceptance. Architect-APPROVED T card remains **RCA STOP, not boot-green** — independently confirmed: `rango-latest` still `130756`; no USB PASS.

## Regression status

- tokay `latest` inode **193110379** unchanged
- `akita-latest` inode **193110357** unchanged
- `komodo-latest` inode **193110380** unchanged
- `rango-latest` still `130756` (inode **193110354**)
- rango still not in production advertise set
- Tests modified/deleted: **NONE** (host suite **added**)
- Product implementation: **not edited**

## Governance

GIP-0 VERIFIED: Loaded `.memory-bank/activeContext.md`, `progress.md` (tail), `decisions.md` (DEC-RANGO-REMEDIATE-001/002), `systemPatterns.md`, Gate -1 YAML, `AGENTS.md` laws/gates, `.agent-comm/PROTOCOL.md` + `ROLES.md` Agent 4. Governance acknowledged. Guardian MCP / HTTP: **not called** (Gate -1 in-process; dispatch no USB).
