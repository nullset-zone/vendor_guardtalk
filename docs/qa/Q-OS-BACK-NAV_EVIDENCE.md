# QA Evidence — Q-OS-BACK-NAV

**Task:** `Q-OS-BACK-NAV` (independent rematch of `T-OS-BACK-NAV`)  
**DEC:** DEC-OS-UX-001  
**Date:** 2026-09-16T09:00:00Z  
**Agent:** QA_ENGINEER  
**Depends:** `T-OS-BACK-NAV` Architect-APPROVED (static) — **not trusted**  
**Verdict:** **PASS (static)** + **HOLD (adb / lunch / runtime)**  
**LIVE_DEVICE_CLAIMED:** false  
**USB/flash:** not run  

Do not treat Architect APPROVE or the Backend completion report as evidence.
This rematch re-ran packet commands and a host suite against in-tree sources.

`pytest platform/tests` N/A (AOSP WM / Activity card). No product Java edited.
SystemUI / Launcher3 not edited (Frontend; git porcelain clean).

## Suite

```bash
bash vendor/guardtalk/docs/qa/verify_os_back_nav_static.sh
# Python SUITE_COUNTS PASS_COUNT=25 FAIL_COUNT=0 HOLD_COUNT=2 EXIT=0
# bash file-present +3 PASS
# Combined: 28 PASS / 0 FAIL / 2 HOLD
# LIVE_DEVICE_CLAIMED=false
# OVERALL: PASS (static) + HOLD (adb/lunch)
```

Full raw transcript: `vendor/guardtalk/docs/qa/Q-OS-BACK-NAV_SUITE.out`

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| System callback is `this::onBackPressed` | **PASS** | `Activity.java:1939` `mDefaultBackCallback = this::onBackPressed`; registered via `registerSystemOnBackInvokedCallback` |
| `onBackPressed()` pops then `onBackInvoked()` | **PASS** | `popBackStackImmediate` then `onBackInvoked()`; ActionBar collapse still first |
| Wrapper still invokes when `OnBackAnimationCallback && !isInProgress` | **PASS** | that `if` logs only; no `return`; always reaches `WindowOnBackInvokedDispatcher.this.onBackInvoked(callback)` |
| `skip onBackInvoked` string absent | **PASS** | targeted `rg` has no match |
| `shouldMoveTaskToBack` last-in-task (not HOME+MAIN-only) | **PASS** | root/relative-root + top-in-TF then `return true`; no `ACTION_MAIN` / `CATEGORY_HOME` |
| ACC `onBackPressed` order: organizer → move → else finish | **PASS** | `handleInterceptBackPressedOnTaskRoot` returns first; then `shouldMoveTaskToBack` → `moveActivityTaskToBack`; else `requestCallbackFinish` |
| No GuardTalk `KEYCODE_BACK` overlay | **PASS** | `rg` under `vendor/guardtalk` excl. qa: empty |
| Did not edit SystemUI / Launcher3 | **PASS** | `git status --porcelain` clean for those trees |
| Negatives refuted (skip / HOME+MAIN-only / fragment skip) | **PASS (static)** | see adversarial matrix |
| Device back stack Settings / Files / multi-activity | **HOLD** | `adb devices` empty |
| lunch / `m` | **HOLD** | not run; `adevtool-version-check.mk` not edited |
| Device-fixed claim | **not claimed** | `LIVE_DEVICE_CLAIMED=false` |

## Claims rematch (Backend not trusted)

| T claim | QA |
|---------|----|
| System callback is `this::onBackPressed` (fragment pop then `onBackInvoked`) | **Confirmed** |
| Wrapper still dispatches when ProgressAnimator idle; `skip onBackInvoked` gone | **Confirmed** |
| `shouldMoveTaskToBack` true for last-in-task after root/relative-root + top-in-TF | **Confirmed** |
| Organizer intercept still first | **Confirmed** |
| No vendor/guardtalk `KEYCODE_BACK` overlay | **Confirmed** |
| Did not change SystemUI / Launcher3 | **Confirmed** (porcelain clean) |
| lunch HOLD | **Confirmed** (QA did not run lunch) |
| `adb devices` empty | **Confirmed** |

## Adversarial / negative matrix

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| System callback `this::onBackInvoked` (fragment stack skipped) | FAIL | assignment is `this::onBackPressed` | PASS (refuted) |
| Wrapper skip restored (`return` in anim&&!isInProgress or `skip onBackInvoked`) | FAIL | log-only; invoke still reached; string absent | PASS (refuted) |
| HOME+MAIN-only restore (last-in-task Settings/Files would finish/kill) | FAIL | no ACTION_MAIN/CATEGORY_HOME; final `return true` | PASS (refuted) |
| Non-root / non-top-in-TF still move-to-back | FAIL (too aggressive) | two `return false` remain | PASS |
| Organizer intercept fall-through | FAIL | early `return` after `handleInterceptBackPressedOnTaskRoot` | PASS |
| GuardTalk KEYCODE_BACK overlay under `vendor/guardtalk` | FAIL | none (excl. this qa tree) | PASS |
| Device Settings → sub-screen → back | PASS only with adb | no device | HOLD |
| Device Files → folder → back | PASS only with adb | no device | HOLD |
| Device multi-activity stack then empty-stack home/recents | PASS only with adb | no device | HOLD |

## Host truth-tables (independent reimplementation)

### `shouldMoveTaskToBack`

| Case | root | rel-root | top-in-TF | Expected | Actual |
|------|------|----------|-----------|----------|--------|
| last-in-task not HOME+MAIN | T | F | T | True | True |
| last-in-task HOME+MAIN still true | T | F | T | True | True |
| relative-root top | F | T | T | True | True |
| not root not rel | F | F | T | False | False |
| root not top-in-TF | T | F | F | False | False |
| rel-root not top | F | T | F | False | False |

### Wrapper `onBackInvoked`

| Case | anim | in-progress | null | IME consume | Expected invoke | Actual |
|------|------|-------------|------|-------------|-----------------|--------|
| KEYCODE_BACK / 3-button idle | T | F | F | F | True | True |
| anim in progress | T | T | F | F | True | True |
| plain callback | F | F | F | F | True | True |
| null callback | T | F | T | F | False | False |
| IME onKeyPreIme consume | T | F | F | T | False | False |

## Raw command output

### Packet `rg this::onBackPressed|skip onBackInvoked|shouldMoveTaskToBack` (re-run)

```text
frameworks/base/services/core/java/com/android/server/wm/ActivityClientController.java:1883:                if (shouldMoveTaskToBack(r, root)) {
frameworks/base/services/core/java/com/android/server/wm/ActivityClientController.java:1896:    static boolean shouldMoveTaskToBack(ActivityRecord r, ActivityRecord rootActivity) {
frameworks/base/core/java/android/app/Activity.java:1939:            mDefaultBackCallback = this::onBackPressed;
```

`skip onBackInvoked` has **zero** matches. Wrapper file is not listed.

### Packet `rg` KEYCODE_BACK|onBackInvoked|BackAnimation|handleBack|predictiveBack

Broad WM + `android/window` listing (174 lines). Full dump in `Q-OS-BACK-NAV_SUITE.out`. Targeted wrapper hit:

```text
WindowOnBackInvokedDispatcher.java:711:        public void onBackInvoked() throws RemoteException {
WindowOnBackInvokedDispatcher.java:715:                boolean isInProgress = mProgressAnimator.isBackAnimationInProgress();
WindowOnBackInvokedDispatcher.java:722:                if (callback instanceof OnBackAnimationCallback && !isInProgress) {
WindowOnBackInvokedDispatcher.java:726:                    Log.w(TAG, "ProgressAnimator was not in progress, "
WindowOnBackInvokedDispatcher.java:727:                            + "dispatching onBackInvoked without animation.");
```

### vendor/guardtalk KEYCODE_BACK / OnBackInvoked (excl. qa)

```text
(empty)
```

### `adb devices`

```text
List of devices attached

```

Empty. Device back-stack **HOLD**. Not device-fixed.

## Coverage gaps

- No adb: Settings hierarchy, Files folder stack, multi-activity then empty-stack `moveTaskToBack` unproven on hardware.
- lunch / `m` not run (adevtool pin; mk not edited).
- IME `consumedByOnKeyPreIme` still swallows wrapper invoke (pre-existing; not this bug).
- App-registered DEFAULT+ `OnBackInvokedCallback` still wins over system `onBackPressed` (AOSP contract; not a FAIL).

## Bugs found

None that FAIL T-OS-BACK-NAV static acceptance. Device behavior remains **HOLD**.
