# QA Evidence — Q-REMEDIATE-B5-SWEEP

**Task:** `Q-REMEDIATE-B5-SWEEP` (pin `EXPECTED_MD5` to product 1008×2244 `bootanimation.zip`)  
**Date:** 2026-09-16T15:43:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `F-REMEDIATE-B5-BOOTZIP` Architect-APPROVED static — **not trusted**  
**DEC:** DEC-REMEDIATE-006  
**Verdict:** **PASS (host static)** — sweep `EXPECTED_MD5` is independent product zip md5 `c9e027553e2d09bd401f63c8bc1a4070`. Dark zip **1080 OK** (not product FAIL). Script **EXIT 0**, **FAIL=0**, HOLD-only for stale `out/` + empty adb. **Not device-fixed.** Status → **REVIEW** (never APPROVED). PASS HOLD remains.

Independent rematch. Frontend completion dumps and prior QA-BOOTZIP numbers were **recomputed**, not trusted a priori. Product zip/PNG were **not** rewritten. No USB GO. No `m`. No flash. `Q-ONDEVICE` **not** restarted.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent md5 of product `bootanimation.zip` | **PASS** | python hashlib + `md5sum` → `c9e027553e2d09bd401f63c8bc1a4070` |
| 2 | `EXPECTED_MD5` pins that product hash (not old 1080 / dark) | **PASS** | script pin == product; pin ≠ dark `7ba676c5…` |
| 3 | Product zip `desc.txt` first line `1008 2244 24` | **PASS** | `unzip -p` / `od -c` |
| 4 | Dark zip may stay 1080; never FAIL product | **PASS** | dark desc `1080 2400 24`; md5 `7ba676c5704c6e6ab962fb34cc6590ef`; script PASS-OK not FAIL |
| 5 | Sweep script EXIT 0; FAIL=0 | **PASS** | PASS_COUNT=18 HOLD_COUNT=3 FAIL=0 |
| 6 | Stale `out/*/product/media/bootanimation.zip` | **HOLD** | tokay/akita/komodo still `7ba676c5…`; did not `m` |
| 7 | `adb devices -l` empty → device boot HOLD | **HOLD** | header only; not device-fixed |
| 8 | Product zip/PNG bytes unchanged by this card | **PASS** | product md5 + PNG `65ab3a35…` after script edit |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_brand_sweep_static.sh
# PASS_COUNT=18 HOLD_COUNT=3 FAIL=0
# ALL STATIC CHECKS PASSED
# EXIT=0
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B5-SWEEP_SUITE.out`

`pytest platform/tests` N/A (AOSP branding QA bash, not AEGIS Python platform).

## Independent rematch (do not trust F / Architect dumps)

### Product zip (pin source)

- Path: `vendor/guardtalk/branding/bootanimation/bootanimation.zip` (153 047 bytes)
- Independent md5 **c9e027553e2d09bd401f63c8bc1a4070**
- `desc.txt` first line **`1008 2244 24`**
- Members STORED: `desc.txt`, `part0/000.png`, `part1/000.png`

### Brand-kit copy

- Path: `vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip`
- Independent md5 identical to product (not the pin path; PRODUCT_COPY uses branding/bootanimation)

### Dark zip (OK, not FAIL)

- Still **1080×2400**, md5 **7ba676c5704c6e6ab962fb34cc6590ef**
- Not PRODUCT_COPY (`guardtalk-theme.mk` filter)
- Sweep treats inequality vs product pin as **PASS** (1080 OK), never FAIL product

### Source PNG (not rewritten)

- `logo_1008x2244.png` md5 **65ab3a358806ad87c2e1ed8fe6b9f958**

### Residuals (not FAIL)

- Stale `out/{komodo,tokay,akita}/product/media/bootanimation.zip` still 1080 hash → **HOLD** (no `m`)
- `adb devices -l` empty → on-device boot **HOLD**. **Not device-fixed.** Do not lift PASS HOLD.

## Adversarial

| Probe | Expected | Actual | Status |
|-------|----------|--------|--------|
| Pin equals old 1080 / dark hash | must not | pin = product `c9e02755…`; ≠ `7ba676c5…` | PASS |
| Dark zip 1080 FAILs product | never FAIL | PASS-OK 1080 | PASS |
| Product zip rewritten by QA | unchanged | md5 stable after script edit | PASS |
| Stale out FAILs product | HOLD | HOLD tokay/akita | PASS |
| pem/pk8/.env under branding | none | empty find | PASS |
| adb / on-device boot | HOLD | empty | HOLD |

## Coverage gaps

- On-device boot animation (stale `out/` + empty adb; `m` forbidden this card)
- Sweep `out/` loop covers tokay+akita only; komodo stale 1080 confirmed independently (HOLD, not FAIL)

## Bugs found

None on host static for the sweep pin.

## Regression status

- Tests modified: `verify_brand_sweep_static.sh` (`EXPECTED_MD5` + dark-zip OK path)
- Product zip/PNG modified by QA: **NONE**
- `verify_remediate_b5_bootzip_host.sh`: untouched
- Derived `.agent-comm/TASK_QUEUE.md`: **not** edited
- Memory-bank: **not** edited
