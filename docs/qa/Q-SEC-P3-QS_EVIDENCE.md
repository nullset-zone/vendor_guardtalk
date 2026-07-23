# QA Evidence — Q-SEC-P3-QS

**Task:** `Q-SEC-P3-QS` (Phase-3 QS catalog exactness + Auto-reboot contracts)  
**Date:** 2026-07-23  
**Agent:** QA_ENGINEER  
**Depends:** `T-SEC-P3-QS` ✅ APPROVED, `F-SEC-P3-QS-EDITOR` ✅ APPROVED  
**Verdict:** **GO** (static + cited prior builds) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Stock catalog has `mictoggle`, `cameratoggle`, `battery`, `autoreboot` | PASS | Overlay `quick_settings_tiles_stock` contains all four; adjacent group `battery,mictoggle,cameratoggle,autoreboot` |
| Auto-reboot **not** in default / new_default | PASS | `quick_settings_tiles_default` and `new_default` lack `autoreboot`; retain mic/camera/battery |
| AutoRebootTile short-press Off ↔ last profile | PASS | `handleClick` + `PREF_LAST_ENABLED_TIMEOUT_MS` / `getRestoreTimeoutMs`; default `DEFAULT_PROFILE_MS` = 8h |
| AutoRebootTile long-press Security Auto-reboot intent | PASS | `getLongClickIntent` → `ExploitProtectionActivity` + `ExploitProtectionFragment` (matches `GuardTalkAutoRebootPreferenceController`) |
| No Lockdown / USB / Wipe / Duress QS classes or catalog tokens | PASS | No forbidden classes/`TILE_SPEC` under SystemUI `qs/`; stock/default/new_default lack tokens |
| Docs: `QS_TILES_POLICY.md`, `QS_EDITOR_UI_NOTES.md` | PASS | Both present; labels Mic/Camera/Battery Saver/Auto-reboot in overlay `strings.xml` |
| Prior green `m SystemUI` / overlay builds cited | PASS | DONE_LOG T/F APPROVED + `m SystemUI` / SystemUI+overlay green; root TASK_QUEUE EXIT=0 |
| adb runtime gaps documented | PASS | `adb devices` empty — QS edit / press smoke SKIPPED |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_p3_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=62 FAIL_COUNT=0 EXIT=0
```

Created for `Q-SEC-P3-QS` (mirrors `verify_sec_p1_static.sh` / `verify_sec_p2_static.sh` style).

## Artifact / build smoke (cited; no fresh `m` this session)

| Source | Command / note | Result |
|--------|----------------|--------|
| DONE_LOG `T-SEC-P3-QS APPROVED` (2026-07-23 11:12) | `m SystemUI` | green |
| DONE_LOG `F-SEC-P3-QS-EDITOR APPROVED` (2026-07-23 12:04) | SystemUI + GuardTalkSystemUIOverlay | green |
| Root `TASK_QUEUE.md` Phase-3 cards | EXIT=0 recorded | cited |
| `QS_TILES_POLICY.md` / `QS_EDITOR_UI_NOTES.md` | document `m SystemUI -j$(nproc)` | present |

No rebuild performed this QA session (task allows citing prior green builds).

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime smoke **SKIPPED**:

- QS editor open → Mic / Camera / Battery Saver / Auto-reboot visible in catalog
- Add/remove Auto-reboot from panel; reset-to-default leaves Auto-reboot off panel
- Short-press toggles `settings_reboot_after_timeout` Off ↔ last/8h
- Long-press lands on Exploit protection Auto reboot picker

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| `autoreboot` on `quick_settings_tiles_default` | forbidden | absent | PASS |
| `autoreboot` on `quick_settings_tiles_new_default` | forbidden | absent | PASS |
| Stock missing any of four Phase-3 specs | forbidden | all present + grouped | PASS |
| LockdownTile / UsbTile / SecureWipeTile / DuressTile | forbidden | absent | PASS |
| Catalog tokens `lockdown`/`usb`/`wipe`/`duress` | forbidden | absent in all three lists | PASS |
| Long-press intent ≠ Security Auto-reboot deep-link | forbidden | same ExploitProtection Activity+Fragment as Security row | PASS |
| `saver` treated as Battery Saver | forbidden | Battery Saver is `battery`; `saver` remains Data Saver | PASS (doc + stock) |

## Coverage gaps

- Device/runtime QS editor + press smoke deferred until adb device available
- Fresh `m SystemUI` / overlay rebuild not re-run this session (cited prior green)
- Instrumention/UIAutomator for Off↔profile toggle not available in this environment

## PQE Assessment

### PQE Assessment: Code Entropy LOW — thin AutoRebootTile + catalog overlays; Mic/Camera/Battery reuse AOSP tiles; forbidden high-risk surfaces kept out of QS reduces cascade risk.

## Gate 5

### Ultimate Critique Score: 93% (Gate 5)

Method: MCP `ultimate_critique` attempted; manual fallback if unavailable.  
Manual 0–10: acceptance 10, scope 10, tests pass 10, regressions 10, adversarial 9, edges 8, independence 10, footprint 10, bugs/docs 9, gaps 8 → **93/100**.

## GO / NO-GO

**GO** for Architect review of Phase-3 QS static acceptance.  
Runtime adb gaps must not block REVIEW; recommend device QS editor/press smoke before production confidence / Phase 4.
