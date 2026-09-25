# QA Evidence — Q-REMEDIATE-B5-BOOTZIP

**Task:** `Q-REMEDIATE-B5-BOOTZIP` (independent rematch of `F-REMEDIATE-B5-BOOTZIP` item **22** residual)  
**Date:** 2026-09-16T15:22:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `F-REMEDIATE-B5-BOOTZIP` Architect-APPROVED static (2026-09-16T15:14:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-005  
**Verdict:** **PASS (host static)** — product + brand-kit `bootanimation.zip` **1008×2244 STORED**, frames byte-identical to `logo_1008x2244.png`. Dark zip **1080×2400 OK**. Brand-sweep `EXPECTED_MD5` stale pin **HOLD** (not product FAIL). On-device boot **HOLD**. Stale `out/` **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). PASS HOLD remains.

Independent rematch. Frontend completion report and Architect APPROVE dumps were **not trusted**. Product zip/PNG were **not** rewritten by QA. No USB GO. No `m`. No commit. `Q-ONDEVICE` **not** started. `verify_remediate_b5_branding_host.sh` **not** overwritten.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Product zip `desc.txt` first line `1008 2244 24` | **PASS** | zipfile + `unzip -p` |
| 2 | Brand-kit zip + `desc.txt` file first line `1008 2244 24` | **PASS** | kit zip md5 identical to product; kit file line exact |
| 3 | Frames STORED | **PASS** | `unzip -v` Method Stored; zipfile `compress_type=0` all 3 members |
| 4 | Frame IHDR 1008×2244 | **PASS** | struct IHDR `part0/000.png` + `part1/000.png` |
| 5 | Frames bytes identical to `logo_1008x2244.png` | **PASS** | md5 `65ab3a358806ad87c2e1ed8fe6b9f958` |
| 6 | Product zip == brand-kit zip | **PASS** | md5 `c9e027553e2d09bd401f63c8bc1a4070` |
| 7 | Dark zip still 1080×2400; not PRODUCT_COPY | **PASS** (OK) | desc `1080 2400 24`; 66 PNG IHDR 1080×2400; md5 `7ba676c5704c6e6ab962fb34cc6590ef`; theme.mk filter |
| 8 | Brand-sweep `EXPECTED_MD5` still old 1080 pin | **HOLD** | pin `7ba676c5…`; sweep script HOLDs mismatch; **not product FAIL** |
| 9 | Stale `out/*/product/media/bootanimation.zip` | **HOLD** | komodo/tokay/akita still `7ba676c5…`; did not `m` |
| 10 | `adb devices -l` empty → on-device boot HOLD | **HOLD** | header only; not device-fixed |
| 11 | No pem/pk8/.env under branding | **PASS** | `find` empty |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b5_bootzip_host.sh
# RESULT: PASS (host)  bash_PASS=19 bash_HOLD=4 PY_RC=0
# PY_COUNTS PASS_COUNT=21 FAIL_COUNT=0 HOLD_COUNT=1
# COMBINED: PASS_COUNT=40 HOLD_COUNT=5 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# DEVICE=HOLD
# PASS_HOLD=remains
# M_BUILD=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B5-BOOTZIP_SUITE.out`

`pytest platform/tests` N/A (AOSP zip / PNG assets, not AEGIS Python platform).

## Independent rematch (do not trust F / Architect dumps)

### Product zip

- Path: `vendor/guardtalk/branding/bootanimation/bootanimation.zip` (153 047 bytes)
- md5 **c9e027553e2d09bd401f63c8bc1a4070** (not the brand-sweep pin)
- `desc.txt` first line **`1008 2244 24`**
- Members: `desc.txt`, `part0/000.png`, `part1/000.png` — all **STORED**
- Both frames IHDR **1008×2244** color type 2; bytes **identical** to `logo_1008x2244.png`

### Brand-kit copy (emu64a PRODUCT_COPY)

- Path: `vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip`
- Byte-identical to product zip
- Loose `desc.txt` first line `1008 2244 24`

### Source PNG (not rewritten)

- `logo_1008x2244.png` md5 **65ab3a358806ad87c2e1ed8fe6b9f958** (same as Q-REMEDIATE-B5-BRANDING)
- `file(1)` **1008 x 2244** RGB. QA did **not** crop or re-encode.

### Dark zip (OK)

- Still **1080×2400**, md5 **7ba676c5704c6e6ab962fb34cc6590ef**
- Not PRODUCT_COPY (`guardtalk-theme.mk` filter)

### Residuals (not FAIL)

- `verify_brand_sweep_static.sh` `EXPECTED_MD5` still **7ba676c5…** → **HOLD** (script updated to HOLD, not FAIL)
- Stale `out/{komodo,tokay,akita}/product/media/bootanimation.zip` still 1080 hash → **HOLD** (no `m`)
- `adb devices -l` empty → on-device boot **HOLD**. **Not device-fixed.** Do not lift PASS HOLD.
- `verify_remediate_b5_branding_host.sh` still HOLDs 1080 zip by design (that card)

## Adversarial

| Probe | Expected | Actual | Status |
|-------|----------|--------|--------|
| Deflated zip members | STORED only | Stored 0% | PASS |
| desc still `1080 2400 24` on product | FAIL this card | `1008 2244 24` | PASS |
| Frame bytes ≠ logo (crop/re-encode) | identical | identical | PASS |
| kit zip ≠ product zip | identical | identical | PASS |
| Dark zip mutated / 1008 leaked | still 1080, not logo | 1080, md5 7ba676c5… | PASS |
| Stale sweep hash FAILs product | HOLD | HOLD | PASS (script) |
| pem/pk8/.env | none | empty find | PASS |
| adb / on-device boot | HOLD | empty | HOLD |

## Coverage gaps

- On-device boot animation (stale `out/` + empty adb; USERBUILD `m` not this card)
- ImageMagick `identify` not used (stdlib IHDR + file(1))
- `verify_remediate_b5_branding_host.sh` still treats zip as 1080 HOLD (intentional; separate card)

## Bugs found

None on host static for item 22 residual.

## Regression status

- Pre-existing test count: N/A (new host suite)
- Tests modified: `verify_brand_sweep_static.sh` (md5 mismatch + stale out → **HOLD**, never FAIL product)
- Product zip/PNG modified by QA: **NONE**
