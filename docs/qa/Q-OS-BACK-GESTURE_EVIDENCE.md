# QA Evidence — Q-OS-BACK-GESTURE

**Task:** `Q-OS-BACK-GESTURE` (independent rematch of `F-OS-BACK-GESTURE`)  
**DEC:** DEC-OS-UX-001  
**Date:** 2026-09-16T08:45:00Z  
**Agent:** QA_ENGINEER  
**Depends:** `F-OS-BACK-GESTURE` Architect-APPROVED (static) — **not trusted**  
**Verdict:** **PASS (static)** + **HOLD (adb / lunch / runtime)**  
**LIVE_DEVICE_CLAIMED:** false  
**USB/flash:** not run  

Do not treat Architect APPROVE or the Frontend completion report as evidence.
This rematch re-ran packet commands and a host suite against in-tree sources.

`pytest platform/tests` N/A (AOSP overlay / SystemUI card). No product Java edited.

## Suite

```bash
bash vendor/guardtalk/docs/qa/verify_os_back_gesture_static.sh
# Python SUITE_COUNTS PASS_COUNT=51 FAIL_COUNT=0 HOLD_COUNT=1 EXIT=0
# Wrapper adb HOLD +1
# Combined: 51 PASS / 0 FAIL / 2 HOLD
# LIVE_DEVICE_CLAIMED=false
# OVERALL: PASS (static) + HOLD (adb/lunch)
```

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| KEEP ∩ drop-list includes both nav-mode overlays | **PASS** | `NavigationBarModeGesturalOverlay` and `NavigationBarMode3ButtonOverlay` in `GUARDTALK_APPS_PACKAGES` **and** `GUARDTALK_OVERLAY_KEEP`; restore line after filter-out |
| Gestural overlay `config_backGestureInset=30dp` | **PASS** | `NavigationBarModeGesturalOverlay/res/values/config.xml` |
| 3-button overlay `config_navBarInteractionMode=0` and no 30dp | **PASS** | 3-button `config.xml` mode=0; no `config_backGestureInset` in that overlay tree |
| Framework `config_backGestureInset=0dp` | **PASS** | `frameworks/base/core/res/res/values/config.xml` |
| Observer / `EdgeBackGestureHandler` consume inset | **PASS** | `getUnscaledInset` → `config_backGestureInset`; handler `mEdgeWidth*` from observer; `isWithinTouchRegion` |
| `frameworks-base-overlays` still dropped | **PASS** | aggregator in drop list; **not** in KEEP; not `PRODUCT_PACKAGES +=` |
| `ro.boot.vendor.overlay.theme` already gestural | **PASS** | `aosp_product.mk` `navbar.gestural` |
| Negative: pager steal in 3-button mode | **PASS (static)** | framework 0dp; 3-button does not bake 30dp; handler requires `!mUsingThreeButtonNav` |
| Negative: KEEP restore missing | **PASS (refuted)** | both names in KEEP ∩ drop; restore `$(filter $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES))` present |
| Negative: cutout overlays re-enabled | **PASS (refuted)** | cutout / `TransparentNavigationBarOverlay` remain in drop; none in KEEP; aggregator not restored |
| Device swipe-from-edge / 3-button back | **HOLD** | `adb devices` empty; `dumpsys overlay` not run |
| lunch / `m SystemUI` | **HOLD** | `vendor/adevtool` HEAD unreadable (`dubious ownership`); pin not independently confirmed; `adevtool-version-check.mk` not edited; lunch not run |
| Device-fixed claim | **not claimed** | `LIVE_DEVICE_CLAIMED=false` |

## Claims rematch (Frontend not trusted)

| F claim | QA |
|---------|----|
| Wave D dropped nav-mode overlays; KEEP-restore re-adds those two RROs | **Confirmed** (drop + KEEP + restore line) |
| Gestural overlay 30dp | **Confirmed** |
| 3-button mode 0 and does not bake 30dp | **Confirmed** |
| Framework inset stays 0dp | **Confirmed** |
| `frameworks-base-overlays` still excised | **Confirmed** |
| `ro.boot.vendor.overlay.theme` already gestural | **Confirmed** |
| Horizontal pagers were not the bug | **Confirmed as static RCA** (0dp framework + 3-button no 30dp; pager steal in button mode not baked) |
| lunch dumpvars “tokay vendor module is outdated” | **HOLD** — QA did not re-run lunch; `git -C vendor/adevtool rev-parse HEAD` failed (dubious ownership). F SHA claim **not independently verified** |
| `adb devices` empty | **Confirmed** |

## Adversarial / negative matrix

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| KEEP ∩ drop empty (restore missing) | FAIL | both overlays in intersection | PASS (refuted) |
| Restore line missing / after-filter order inverted | FAIL | filter-out then KEEP `PRODUCT_PACKAGES +=` | PASS |
| 3-button overlay bakes 30dp | FAIL (pager steal) | no inset in any 3-button xml | PASS |
| Framework inset 30dp | FAIL | 0dp | PASS |
| GuardTalk overlays bake inset | FAIL | none | PASS |
| `EdgeBackGestureHandler` fires in 3-button | FAIL | `!mUsingThreeButtonNav` gate | PASS |
| Cutout / TransparentNav in KEEP | FAIL | absent from KEEP; still in drop | PASS |
| Aggregator `frameworks-base-overlays` in KEEP or PRODUCT_PACKAGES += | FAIL | drop only | PASS |
| Observer ignores `config_backGestureInset` | FAIL | `R.dimen.config_backGestureInset` in `getUnscaledInset` | PASS |
| Device swipe/3-button returns to previous in-app view | PASS only with adb | no device | HOLD |

## Raw command output

### Packet `rg` (re-run)

```text
vendor/guardtalk/feature-excised/apps-excised.mk
432:    NavigationBarMode3ButtonOverlay \
433:    NavigationBarModeGesturalOverlay \
458:    frameworks-base-overlays
489:GUARDTALK_OVERLAY_KEEP := \
501:    NavigationBarMode3ButtonOverlay \
502:    NavigationBarModeGesturalOverlay \
781:PRODUCT_PACKAGES += $(filter $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES))

frameworks/base/packages/overlays/NavigationBarMode3ButtonOverlay/res/values/config.xml:24:    <integer name="config_navBarInteractionMode">0</integer>
frameworks/base/packages/overlays/NavigationBarModeGesturalOverlay/res/values/config.xml:24:    <integer name="config_navBarInteractionMode">2</integer>
frameworks/base/packages/overlays/NavigationBarModeGesturalOverlay/res/values/config.xml:37:    <dimen name="config_backGestureInset">30dp</dimen>
frameworks/base/core/res/res/values/config.xml:4587:    <integer name="config_navBarInteractionMode">2</integer>
frameworks/base/core/res/res/values/config.xml:4604:    <dimen name="config_backGestureInset">0dp</dimen>

GestureNavigationSettingsObserver.java:176:                com.android.internal.R.dimen.config_backGestureInset) / dm.density;
EdgeBackGestureHandler.java:573-574: mEdgeWidthLeft/Right from observer getLeft/RightSensitivity
EdgeBackGestureHandler.java:1061: private boolean isWithinTouchRegion
EdgeBackGestureHandler.java:1218: && !mUsingThreeButtonNav && isWithinInsets && isWithinTouchRegion

build/make/target/product/aosp_product.mk:29:
    ro.boot.vendor.overlay.theme=com.android.internal.systemui.navbar.gestural
```

### `adb devices`

```text
List of devices attached

```

Empty. `adb shell dumpsys overlay | rg navbar.gestural|navbar.threebutton|NavigationBarMode` **not run**.

### Host suite (2026-09-16T08:45:00Z, EXIT=0)

```text
PASS: present: vendor/guardtalk/feature-excised/apps-excised.mk
PASS: present: frameworks/base/core/res/res/values/config.xml
PASS: present: .../NavigationBarModeGesturalOverlay/res/values/config.xml
PASS: present: .../NavigationBarMode3ButtonOverlay/res/values/config.xml
PASS: present: gestural + 3-button AndroidManifest.xml
PASS: present: frameworks/base/packages/overlays/Android.bp
PASS: present: GestureNavigationSettingsObserver.java
PASS: present: EdgeBackGestureHandler.java
PASS: present: aosp_product.mk
PASS: present: KeyButtonView.java
PASS: NavigationBarModeGesturalOverlay still listed in drop list
PASS: NavigationBarMode3ButtonOverlay still listed in drop list
PASS: NavigationBarModeGesturalOverlay in GUARDTALK_OVERLAY_KEEP
PASS: NavigationBarMode3ButtonOverlay in GUARDTALK_OVERLAY_KEEP
PASS: KEEP ∩ drop-list restores both
PASS: PRODUCT_PACKAGES += $(filter $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES)) present
PASS: filter-out precedes KEEP restore
PASS: frameworks-base-overlays still in drop list
PASS: frameworks-base-overlays not in KEEP
PASS: frameworks-base-overlays not in PRODUCT_PACKAGES += tokens
PASS: cutout / TransparentNavigationBarOverlay not in KEEP
PASS: all cutout / TransparentNavigationBarOverlay names remain in drop list
PASS: negative KEEP-missing: intersection non-empty
PASS: gestural overlay config_backGestureInset=30dp
PASS: gestural overlay config_navBarInteractionMode=2
PASS: 3-button overlay config_navBarInteractionMode=0
PASS: 3-button overlay does not bake config_backGestureInset
PASS: 3-button overlay tree has no config_backGestureInset in any xml
PASS: framework config_backGestureInset=0dp
PASS: GuardTalk overlays do not override config_backGestureInset
PASS: gestural package com.android.internal.systemui.navbar.gestural
PASS: gestural exclusive category navigation_bar_mode
PASS: 3-button package com.android.internal.systemui.navbar.threebutton
PASS: 3-button exclusive category navigation_bar_mode
PASS: aosp_product.mk overlay.theme=navbar.gestural
PASS: aggregator phony still defined; required still lists nav-mode + cutout names
PASS: observer reads config_backGestureInset; DeviceConfig only if defaultInset > 0
PASS: EdgeBackGestureHandler mEdgeWidth + isWithinTouchRegion + !mUsingThreeButtonNav
PASS: KeyButtonView KEYCODE_BACK present
PASS: residual config_show_gesture_settings=false
HOLD: vendor/adevtool HEAD unreadable (dubious ownership)
HOLD: adb devices empty — swipe-from-edge and 3-button back not proven; not device-fixed
SUITE_COUNTS PASS_COUNT=51 FAIL_COUNT=0 HOLD_COUNT=1
LIVE_DEVICE_CLAIMED=false
RESULT: PASS (static)
```

## Residuals (not F FAILs of this pair)

1. Settings **Gestures** page still hidden (`config_show_gesture_settings=false`, F-SYS-HIDE-GESTURE-BACKUP). Boot default is gestural via `ro.boot.vendor.overlay.theme`. Users cannot toggle nav mode from Settings. 3-button APK is installed for OverlayManager/`adb overlay`.
2. **T-OS-BACK-NAV** (WM/input) is a separate pair. This rematch did not require T APPROVED and did not edit WM/SystemUI Java.
3. Device swipe-from-edge and 3-button back returning to previous in-app view is **HOLD** until adb.
4. lunch / `m SystemUI` **HOLD**. QA did not independently confirm the adevtool SHA pin (git ownership). Did not edit `adevtool-version-check.mk`.

## Coverage gaps

- No device: overlay enablement (`dumpsys overlay`), edge-swipe in Settings, 3-button KEYCODE_BACK, pager swipe in button vs gestural mode.
- No `m SystemUI` / lunch.
- Settings gesture picker remains hidden — cannot user-toggle 3-button without overlay debug.
- WM predictive-back / fragment pop is **T-OS-BACK-NAV / Q-OS-BACK-NAV**, not this card.

## PQE Assessment

### PQE Assessment: Code Entropy REDUCED

KEEP ∩ drop restores only the two exclusive-category nav-mode RROs. Framework inset stays 0dp so 3-button mode does not bake a 30dp edge. Aggregator still excised (cutout / transparent-nav stay out). Residual entropy: hidden Settings picker; device/lunch unverified; T-OS-BACK-NAV still owns in-app stack dispatch.

## Gate 5

### Ultimate Critique Score: Gate 5 HUMAN SKIP (MCP absent; score not fabricated)

Manual self-check (not MCP): acceptance 8 (device HOLD), scope 10, static tests 9, independence 10, adversarial 9, edges 8, footprint 10, bug documentation 8, gaps 7, reversibility 10. Informal only.

## GO / NO-GO

**GO for Architect REVIEW** of F-OS-BACK-GESTURE static KEEP-restore claims.  
**Not device-fixed.** Recommend adb smoke (`dumpsys overlay` navbar.gestural/threebutton; swipe-from-edge; 3-button back) before treating OS UX gesture-back as production-closed.
