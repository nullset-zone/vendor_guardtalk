# QA Evidence — Q-REMEDIATE-B1-DURESS

**Task:** `Q-REMEDIATE-B1-DURESS` (independent rematch of `T-REMEDIATE-B1-DURESS` **item 6 only**)  
**Date:** 2026-09-16T09:51:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B1-DURESS` Architect-APPROVED item 6 (2026-09-16T09:38:44Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-001  
**Verdict:** **PASS (static / host)** — device/wipe **HOLD**. Item **7 HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. No USB wipe. No commit.

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns, GUARDIAN_MANDATORY) and `AGENTS.md` / workflow. Gate -1 in-process. Guardian MCP/HTTP not called (TOOL UNAVAILABLE).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent rg/host suite for Binder paths + `Reason.DURESS` | **PASS** | `verify_os_duress_binder_static.sh` + this file |
| 2 | `checkCredential` / `verifyCredential` hit `DuressPasswordHelper.onVerifyCredentialResult` | **PASS** | both Binder methods return `doVerifyCredential`; helper in `finally` |
| 3 | Rematch `setLockCredential` enroll miss + `getHashFactor` miss | **PASS** | miss hooks at LSS ~2144 and ~3678 |
| 4 | Lockscreen wipe still `SecureWipeEngine.Reason.DURESS` | **PASS** | helper `SecureWipeEngine.run(..., Reason.DURESS)` |
| 5 | Item 7 still HOLD (USB default `0`) | **PASS / HOLD** | `SystemProperties.get(..., "0")`; no product `=1`; default-on not done |
| 6 | Negative: lockscreen wipe rewritten | **PASS (not rewritten)** | helper DURESS; LSS still ANTI_BRUTEFORCE + USER_REQUESTED |
| 7 | Negative: helper skipped on Binder LSKF | **PASS (not skipped)** | check/verify/tied/tryUnlock/unlockChild funnel |
| 8 | Negative: USB default flipped on this stamp | **PASS (not flipped)** | default still `"0"`; no vendor mk assign |
| 9 | Evidence under `vendor/guardtalk/docs/qa/` | **PASS** | this file + suite out + verify script |
| 10 | Device/wipe HOLD if adb empty — never device-fixed | **HOLD** | `adb devices` empty list |
| 11 | Status REVIEW only | **PASS** | never APPROVED; no commit |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_os_duress_binder_static.sh
# RESULT: PASS (static)  bash_PASS=15 bash_HOLD=4 PY_RC=0
# PY_COUNTS PASS_COUNT=45 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=60 HOLD_COUNT=4 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# ITEM7=HOLD (USB default still 0)
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-DURESS_SUITE.out`

`pytest platform/tests` N/A (AOSP framework locksettings card, not AEGIS Python platform).  
`atest FrameworksServicesTests:ProgrammaticDuressBinderTests` **HOLD** (not run this host).

## Independent rematch (do not trust T report)

### Binder LSKF funnel

`ILockSettings.aidl` still declares `checkCredential`, `verifyCredential`, `verifyTiedProfileChallenge`, `setLockCredential`, `getHashFactor`, `verifyGatekeeperPasswordHandle`.

| Binder | LSKF? | Helper path |
|--------|-------|-------------|
| `checkCredential` | yes | body returns `doVerifyCredential` (~2493); **no** direct `unlockLskfBasedProtector` |
| `verifyCredential` (4-arg) | yes | body returns `doVerifyCredential` (~2518) |
| `verifyCredential` (3-arg) | yes | delegates `Primary` 4-arg (~2503) |
| `verifyTiedProfileChallenge` | yes | `doVerifyTiedProfileChallenge` → `doVerifyCredential` ×2 (parent + profile) |
| `tryUnlockWithCachedUnifiedChallenge` | cached LSKF | `doVerifyCredential` |
| `unlockChildProfile` | internal | `doVerifyCredential` |
| `setLockCredential` | enroll LSKF | `setLockCredentialInternal`; **miss** (`sp == null`) calls helper (~2144) |
| `getHashFactor` | enroll/hash LSKF | `getHashFactorInternal`; **miss** (`factor == null`) calls helper (~3678) |
| `verifyGatekeeperPasswordHandle` | **no** (handle) | helper **absent** (correct) |
| `setLockCredentialWithToken` | token, not guess | helper **absent** (correct) |
| `requestSecureWipe` | yes via check | funnel then `Reason.USER_REQUESTED` (not DURESS rewrite) |

`doVerifyCredential` (~2576–2586):

1. `res = doVerifyCredentialInner(...)`
2. `finally { duressPasswordHelper.onVerifyCredentialResult(res, credential); }`

Tied-profile parent verify inside public `setLockCredential` (~2016) also uses `doVerifyCredential`, so the helper `finally` runs there too.

### Lockscreen wipe reason

`DuressPasswordHelper.onVerifyCredentialResult`:

- return immediately if `res != null && res.isMatched()`
- return if `credential == null`
- else background `isDuressCredential` → `SecureWipeEngine.run(ctx, SecureWipeEngine.Reason.DURESS)`

`SecureWipeEngine.Reason` still has distinct `USER_REQUESTED`, `DURESS`, `ANTI_BRUTEFORCE`. LSS anti-bruteforce still `Reason.ANTI_BRUTEFORCE`; secure-wipe UI still `Reason.USER_REQUESTED`. `DuressWipe.run` still `Reason.DURESS`.

**Negative (lockscreen wipe rewritten):** not observed.

### Item 7 USB (must stay HOLD / opt-in)

`UsbPortSecurityHooks.isUsbDuressWipeEnabled`:

```java
return "1".equals(SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0"));
```

`maybeTriggerUsbDuressWipe` returns early unless that flag is on, then still requires keyguard dismissed-once, keyguard showing, DEVICE data-role, duress armed, `verifiedbootstate=green`. No `vendor/guardtalk` product mk/prop assigns `usb_duress_wipe.enabled=1`.

**Negative (USB default flipped on this stamp):** not observed. Item 7 remains **HOLD**.

### Host tests (presence only)

`ProgrammaticDuressBinderTests.java` contains:

- `checkCredential_wrongGuess_invokesDuressHelper`
- `checkCredential_correctGuess_stillInvokesDuressHelper`
- `verifyCredential_wrongGuess_invokesDuressHelper`
- `verifyTiedProfileChallenge_wrongParent_invokesDuressHelper`
- `verifyGatekeeperPasswordHandle_doesNotInvokeDuressHelper`
- `setLockCredential_wrongSaved_invokesDuressHelper`
- `getHashFactor_wrongCredential_invokesDuressHelper`

Comment: tests do not exercise `SecureWipeEngine` (wipe stays `Reason.DURESS`). **atest not executed.**

### adb

```
List of devices attached
```

Empty. Device PASS forbidden. Wipe e2e forbidden. **Never device-fixed.**

## Adversarial / negatives

| Test | Input / claim | Expected | Actual | Status |
|------|----------------|----------|--------|--------|
| helper skip on `checkCredential` | Binder body uses `unlockLskfBasedProtector` | fail | funnels `doVerifyCredential` | PASS |
| helper skip on `verifyCredential` | same | fail | funnels `doVerifyCredential` | PASS |
| helper skip on tied profile | no `doVerifyCredential` | fail | 2 calls | PASS |
| GK handle treated as LSKF | helper invoked | must not | helper absent | PASS |
| wipe reason rewrite | helper `ANTI_BRUTEFORCE` / `USER_REQUESTED` | fail | still `DURESS` | PASS |
| USB default-on this stamp | `get(..., "1")` or mk `=1` | fail / item-7 leak | still `"0"`, no mk | PASS |
| empty adb → device-fixed | claim live wipe | forbidden | HOLD | PASS (HOLD) |
| `getHashFactor` miss | `factor == null` | helper | helper + `OTHER_ERROR` | PASS (see gap) |

## Coverage gaps

- **atest HOLD** — methods present; runtime mock verify not executed.
- **`getHashFactor` miss** synthesizes `VerifyCredentialResponse.OTHER_ERROR` instead of the `unlockLskfBasedProtector` `auth.response`. Current helper only short-circuits `isMatched()` then checks `isDuressCredential`, so wipe behavior is still fail-closed. Flag if helper later keys off timeout vs other.
- **Success-path miss-only hooks:** `setLockCredential` success and `getHashFactor` success do **not** call the helper (unlike `doVerifyCredential` `finally`). Matches “enroll/hash **miss**” scope; not a Binder check/verify skip.
- No host test for `verifyCredential` **correct** guess (checkCredential correct-guess is present).
- `validateRemoteLockscreen` encrypted blob is not an LSKF Binder guess; not rematched as item 6.
- **Device/wipe e2e HOLD** until adb + operator + designated test unit. Item 7 HOLD until AVB.

## Bugs found

None that fail item 6 static AC. INFO gap: `getHashFactor` miss uses synthetic `OTHER_ERROR` (above). Not a REVIEW blocker.

## Regression status

- Product files: **not edited** by QA.
- Pre-existing `ProgrammaticDuressBinderTests`: **not modified**.
- USB default: still opt-in `0`.
- Wipe reasons: not collapsed.

## PQE Assessment

Code entropy **REDUCED** — Binder LSKF check/verify share one `finally` helper; enroll/hash misses are explicit; USB remains gated opt-in. Residual entropy: synthetic `OTHER_ERROR` on hash miss; atest/device unproven.

## Gate 5

MCP `ultimate_critique` / `hallucination_guard` **unavailable**. **HUMAN SKIP** — score not fabricated from MCP. Manual 10-axis (0–10): AC 9, scope 10, tests 8 (atest HOLD), regressions 9, adversarial 9, edges 8, independence 10, footprint 10, bugs 9, gaps 8. **Manual total 90/100.** Confidence 8/10 (device/atest HOLD).
