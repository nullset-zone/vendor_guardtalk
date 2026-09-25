# QA Evidence — Q-PIXEL9-NONREGRESSION

**Task:** `Q-PIXEL9-NONREGRESSION` (independent rematch: Pixel 9 family unchanged after CLI harden + rango RCA STOP)  
**Date:** 2026-09-16T06:50:00Z  
**Host clock:** 2026-09-16T06:34:06Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-FLASH-CLI-HARDEN` ✅ APPROVED · `T-RANGO-BOOT-REMEDIATE` ✅ APPROVED (RCA STOP, not boot-green)  
**Verdict:** **PASS (static / host)** — USB flash **HOLD**. Overlay **HOLD**. **Not FLASH live GO.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend reports were not trusted. Product scripts and latest stamps were not edited. Stamps were not relinked.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `DEVICE=tokay` → `releases/desktop-flash/latest` (`tokay-20260725-102506`) | PASS | `readlink` + extracted `apply_remote_paths tokay` |
| 2 | `DEVICE=akita` → `akita-latest` (`akita-20260725-101434`) | PASS | `readlink` + `apply_remote_paths akita` |
| 3 | `DEVICE=komodo` → `komodo-latest` (`komodo-20260915-063833`) | PASS | `readlink` + `apply_remote_paths komodo` |
| 4 | Inodes unchanged vs Architect pins | PASS | latest **193110379**; akita-latest **193110357**; komodo-latest **193110380** |
| 5 | Firmware cleanup uart + erase fips + dpm for those three | PASS | fake-fastboot log: `oem uart disable`, `erase fips`, `erase dpm_a`, `erase dpm_b` |
| 6 | No `flash_rango_rescue` / rescue boot on those three | PASS | Pixel 9 else-branch has no `flash_rango_rescue_boot_chain`; production call L963 inside `FLASH_DEVICE == rango`; Pixel 9 does not set `REMOTE_RESCUE_DIR` |
| 7 | Wrong `DEVICE=` fail-closed | PASS | empty/unknown/caiman/shiba/husky/pixel9/mustang/blazer/frankel/PIXEL9 → empty; `apply_remote_paths caiman` dies |
| 8 | KEEP both `flash-from-remote.sh` copies identical | PASS | `cmp -s` EXIT=0; SHA `9d3b1e41c81bbccd15e0d2f17438e046afc682dcc64d391e19e26c9dba3ee8b6` |
| 9 | No rango advertise | PASS | `ALLOWED_PRODUCTS` source+dist = `tokay, akita, komodo`; no rango `SUPPORTED_TARGETS` row |
| 10 | USB | **HOLD** | `adb devices` header only; do not invent PASS |

## Static script (suite of record)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_pixel9_nonregression_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=64 HOLD_COUNT=2 FAIL=0 EXIT=0
```

Architect pin commands (independent of the suite):

```text
readlink latest / akita-latest / komodo-latest
  → tokay-20260725-102506
  → akita-20260725-101434
  → komodo-20260915-063833

stat -c '%i %n'
  → 193110379 releases/desktop-flash/latest
  → 193110357 releases/desktop-flash/akita-latest
  → 193110380 releases/desktop-flash/komodo-latest

grep -n 'erase fips' scripts/flash-from-remote.sh
  → 38 (comment), 361 (log), 364–365 (fastboot + die)

cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh
  → EXIT=0
```

Host extracted-function fake-fastboot / stub-ssh is the suite. `pytest platform/tests` N/A (AOSP flash CLI card, not AEGIS Python platform).

## Independent rematch (do not trust engineer report)

### Stamp pins (Architect)

| Symlink | Target | Inode | Match pin |
|---------|--------|-------|-----------|
| `latest` | `tokay-20260725-102506` | 193110379 | YES |
| `akita-latest` | `akita-20260725-101434` | 193110357 | YES |
| `komodo-latest` | `komodo-20260915-063833` | 193110380 | YES |
| `rango-latest` (cascade) | `rango-20260802-130756` | 193110354 | still 130756; not stolen |

### KEEP identity

```text
cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh  → EXIT=0
bash -n both copies                                                                → 0
SHA256 both = 9d3b1e41c81bbccd15e0d2f17438e046afc682dcc64d391e19e26c9dba3ee8b6
```

### DEVICE= mapping (extracted `apply_remote_paths`; stub ssh; no USB body)

| DEVICE | REMOTE_BUILD_DIR suffix | REMOTE_RESCUE_DIR |
|--------|-------------------------|-------------------|
| tokay | `.../releases/desktop-flash/latest` | unset |
| akita | `.../releases/desktop-flash/akita-latest` | unset |
| komodo | `.../releases/desktop-flash/komodo-latest` | unset |

### Firmware cleanup (extracted `apply_grapheneos_firmware_cleanup`)

tokay / akita / komodo each emit, in order:

```text
oem uart disable
erase fips
erase dpm_a
erase dpm_b
```

Source case remains `tokay|akita|komodo` at `scripts/flash-from-remote.sh` L360–370.

### Rescue isolation

| Site | Line | Pixel 9? |
|------|------|----------|
| `flash_rango_rescue_boot_chain()` definition | 806 | definition only |
| harvest pstore reflash | 884 | gated `akita\|rango`; tokay/komodo absent from ramoops case |
| production fastbootd entry | 963 | inside `FLASH_DEVICE == rango` (L958); else-branch uses on-device boot chain |

### Advertise (DEC-PORT-KOMODO-004)

```text
vendor/guardtalk/web-installer/src/types.ts
  ALLOWED_PRODUCTS = ["tokay", "akita", "komodo"]
vendor/guardtalk/web-installer/dist/src/types.js  same
SUPPORTED_TARGETS source: tokay + akita + komodo supported; no rango row
```

CLI still accepts `DEVICE=rango` (other card). Production advertise set was not expanded.

### Adversarial

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| empty DEVICE | `""` | fail-closed | empty normalize | PASS |
| unknown | `unknown` | fail-closed | empty | PASS |
| sibling Pixel | `caiman` `shiba` `husky` | fail-closed | empty; `apply_remote_paths caiman` dies | PASS |
| Pixel 10 family | `mustang` `blazer` `frankel` | fail-closed | empty | PASS |
| junk | `pixel9` `PIXEL9` | fail-closed | empty | PASS |
| casefold | `Tokay` | tokay (existing) | tokay | PASS (documented fallback) |
| substring | `komodo-xl` | komodo via `*"komodo"*` | komodo | PASS (documented gap, not a FAIL this card) |

### USB / overlay

```text
adb devices → header only (no device)
fastboot not used against hardware (PATH stub only)
overlay HOLD — no host browser this card
```

**Do not invent USB PASS.**

## Coverage gaps

- No live USB flash (dispatch: USB HOLD). Firmware-cleanup PASS is host-extracted, not on-device.
- `auto_harvest_on_failure` still allows `akita|rango` for pstore pull (L865). Production fastbootd rescue remains rango-only (L958–963). Not a Pixel 9 non-regression FAIL.
- `normalize_device` substring fallback maps `komodo-xl` → `komodo` (and similarly tokay/akita/rango substrings). Wrong exact codenames still fail-closed. Documented; out of this card’s product-edit scope.
- Web-installer overlay not exercised (HOLD).

## Bugs found

None that fail this card’s acceptance. Pixel 9 latest inodes and firmware profile are unchanged after both T cards.

## Regression status

- tokay `latest` still `tokay-20260725-102506` inode **193110379**
- `akita-latest` still inode **193110357**
- `komodo-latest` still inode **193110380**
- tokay\|akita\|komodo still `erase fips` + uart + dpm
- no rescue boot on those three
- KEEP copies identical (SHA `9d3b1e41…`)
- rango not added to `ALLOWED_PRODUCTS`
- Tests modified/deleted: **NONE** (host suite **added**)
- Product implementation: **not edited**
- Latest stamps: **not relinked**

## Governance

GIP-0 VERIFIED: Loaded `.memory-bank/activeContext.md`, `progress.md` (tail), `decisions.md` (DEC-RANGO-REMEDIATE-001/002, DEC-PORT-KOMODO-004), `systemPatterns.md`, Gate -1 YAML, `AGENTS.md` laws/gates, `.agent-comm/PROTOCOL.md` + `ROLES.md` Agent 4. Governance acknowledged. Guardian MCP / HTTP: **not called** (Gate -1 in-process; dispatch no USB).
