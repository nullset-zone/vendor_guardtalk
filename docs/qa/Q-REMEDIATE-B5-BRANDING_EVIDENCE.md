# QA Evidence — Q-REMEDIATE-B5-BRANDING

**Task:** `Q-REMEDIATE-B5-BRANDING` (independent rematch of `F-REMEDIATE-B5-BRANDING` items **22, 23**)  
**Date:** 2026-09-16T13:50:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `F-REMEDIATE-B5-BRANDING` Architect-APPROVED static (2026-09-16T13:42:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-002  
**Verdict:** **PASS (host static)** — `bootanimation.zip` **1080×2400 HOLD** (not FAIL). On-device Welcome + boot **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). PASS HOLD remains.

Independent rematch. Frontend completion report and Architect APPROVE dumps were **not trusted**. Product source was not edited. Zip was **not** rebuilt. No USB GO. No wipe. No commit. `Q-ONDEVICE` **not** started.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Boot PNG IHDR exactly 1008×2244 | **PASS** | `file(1)` + python zlib IHDR `w=1008 h=2244 color=2` |
| 2 | G chevron inside ~12% safe zone; **do not use luma-sum>30** | **PASS** | Canvas corners `(10,11,12)`. luma-sum>30 bbox = full canvas (decoder trap). luma-sum>80 bbox `(348,900)–(659,1219)` insets L/R 348 T 900 B 1024 (≥120 / ≥314 / ≥269) |
| 3 | SUW overlay PNG is RGBA (color type 6); corner alpha 0 | **PASS** | `file(1)` RGBA 1024×1024; python color=6; four corners `(0,0,0,0)` |
| 4 | `res/drawable/guardtalk_welcome_square.xml` ABSENT | **PASS** | `test ! -e`; drawable dir has no XML |
| 5 | `com.guardtalk.overlay.setupwizard` present | **PASS** | `AndroidManifest.xml` package + target `app.grapheneos.setupwizard` |
| 6 | `bootanimation.zip` still 1080×2400 | **HOLD** (not FAIL) | `desc.txt` first line `1080 2400 24`. USERBUILD not delayed. |
| 7 | No pem/pk8/.env under branding + overlay | **PASS** | `find` empty; `git ls-files` empty |
| 8 | adb empty → Welcome + boot HOLD; not device-fixed | **HOLD** | `adb devices` header only |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b5_branding_host.sh
# RESULT: PASS (host)  bash_PASS=18 bash_HOLD=2 PY_RC=0
# PY_COUNTS PASS_COUNT=14 FAIL_COUNT=0 HOLD_COUNT=1
# COMBINED: PASS_COUNT=32 HOLD_COUNT=3 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# ZIP=HOLD
# DEVICE=HOLD
# PASS_HOLD=remains
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B5-BRANDING_SUITE.out`

`pytest platform/tests` N/A (PNG / RRO assets, not AEGIS Python platform).

## Independent rematch (do not trust F / Architect dumps)

### Item 22 — boot logo

- Path: `vendor/guardtalk/branding/bootanimation/logo_1008x2244.png` (76 346 bytes)
- Brand-kit copy bytes **match**.
- Decoders: `file(1)` libmagic **and** stdlib zlib PNG (no PIL, no ImageMagick).
- IHDR: **1008×2244**, 8-bit, color type 2 (RGB), non-interlaced.
- Canvas corners all `(10, 11, 12)` — luma-sum>30 matches **every** pixel (n=2 261 952). Using that threshold would falsely report insets 0. **Not used for AC.**
- luma-sum>80 (R+G+B>80) bbox **exactly** `(348, 900)–(659, 1219)` n=40 581. Insets **L/R 348 T 900 B 1024**.
- Safe zone (12% L/R = 120.96, 14% T = 314.16, 12% B = 269.28): 348≥120, 900≥314, 1024≥269 → **PASS**.

Frontend report claimed bbox `(348,867)–(660,1220)` T 867. That does **not** match luma-sum>80. Independent decoder matches the Architect rematch numbers, not the Frontend dump. Asset still inside the safe zone either way; **not a product FAIL**.

### Item 23 — Setup Wizard overlay

- Path: `vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/res/drawable-nodpi/guardtalk_welcome_square.png`
- Brand-kit `guardtalk_welcome_square_transparent.png` bytes **match**.
- IHDR 1024×1024, color type **6** (RGBA).
- Corners alpha **0**. Center `(195, 255, 97, 255)` (branded lime). 70 699 nonzero-alpha pixels.
- `guardtalk_welcome_square.xml` **ABSENT**.
- Package `com.guardtalk.overlay.setupwizard`.

### Residuals (not FAIL)

- `bootanimation.zip` still plays **1080×2400**. Item-22 deliverable is the 1008×2244 PNG; zip rebuild would delay USERBUILD → **HOLD**.
- `identify` not installed → **HOLD** (python IHDR used).
- `adb devices` empty → on-device Welcome screen + boot animation **HOLD**. **Not device-fixed.** Do not lift PASS HOLD.

## Adversarial

| Probe | Expected | Actual | Status |
|-------|----------|--------|--------|
| luma-sum>30 as content detector | full-canvas trap | full canvas (0,0)–(1007,2243) | PASS (trap proven) |
| XML placeholder still present | ABSENT | ABSENT | PASS |
| Opaque RGB overlay (color type 2) | color type 6 | 6 | PASS |
| Corner alpha 255 | 0 | 0 | PASS |
| Empty transparent SUW | nonzero alpha | 70699 | PASS |
| pem/pk8/.env under branding+overlay | none | empty | PASS |
| Zip not 1008×2244 | HOLD not FAIL | 1080×2400 HOLD | HOLD |
| adb device-fixed claim | forbidden | empty list | HOLD |

## Bugs found

None on host static for items 22 and 23.

Frontend measurement drift (T=867 vs independent T=900) is a **report** discrepancy, not an asset defect under luma-sum>80.
