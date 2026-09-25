#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B1-DURESS (pair of T-REMEDIATE-B1-DURESS item 6).
# Do not trust Backend/Architect reports. Host static + Binder-path truth-table only.
# Item 7 USB default-on remains HOLD (AVB). Device/wipe HOLD if adb empty.
# No USB wipe. No product edits. No commit.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_duress_binder_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

LSS="frameworks/base/services/core/java/com/android/server/locksettings/LockSettingsService.java"
HELPER="frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java"
USB="frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java"
ENGINE="frameworks/base/services/core/java/com/android/server/locksettings/SecureWipeEngine.java"
DURESS_WIPE="frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java"
TESTS="frameworks/base/services/tests/servicestests/src/com/android/server/locksettings/ProgrammaticDuressBinderTests.java"
AIDL="frameworks/base/core/java/com/android/internal/widget/ILockSettings.aidl"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

require_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

forbid_rg() {
  local pat="$1" path="$2" label="$3"
  if [[ -e "$path" ]] && rg -q -- "$pat" "$path" 2>/dev/null; then
    fail "$label (forbidden pattern present: $pat)"
  else
    pass "$label"
  fi
}

echo "=== Q-REMEDIATE-B1-DURESS independent rematch (item 6) ==="
echo "ROOT=$ROOT"
echo "ITEM7=HOLD (USB default-on blocked on AVB)"
echo

# --- Files ---
require_file "$LSS"
require_file "$HELPER"
require_file "$USB"
require_file "$ENGINE"
require_file "$DURESS_WIPE"
require_file "$TESTS"
require_file "$AIDL"

# --- Packet rg (raw symbols) ---
echo
echo "--- packet rg (Binder + helper) ---"
rg -n "onVerifyCredentialResult|doVerifyCredential|checkCredential|verifyCredential" \
  "$LSS" "$HELPER" || true
echo
echo "--- packet rg (USB duress flag) ---"
rg -n "usb_duress_wipe.enabled|isUsbDuressWipeEnabled" "$USB" || true
echo

require_rg "onVerifyCredentialResult" "$LSS" "LSS calls onVerifyCredentialResult"
require_rg "onVerifyCredentialResult" "$HELPER" "helper defines onVerifyCredentialResult"
require_rg "doVerifyCredential" "$LSS" "LSS defines/calls doVerifyCredential"
require_rg "public VerifyCredentialResponse checkCredential" "$LSS" "LSS Binder checkCredential"
require_rg "public VerifyCredentialResponse verifyCredential" "$LSS" "LSS Binder verifyCredential"
require_rg "SecureWipeEngine.Reason.DURESS" "$HELPER" "helper wipe reason is DURESS"
require_rg "usb_duress_wipe.enabled" "$USB" "USB flag prop name present"
require_rg "isUsbDuressWipeEnabled" "$USB" "USB enable gate present"

# --- Python structural rematch (do not trust comments) ---
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path

root = Path(sys.argv[1])
fail = 0
pass_n = 0
hold_n = 0

def out(kind, msg):
    global fail, pass_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail = 1
    else:
        hold_n += 1

def read(rel):
    p = root / rel
    if not p.is_file():
        out("FAIL", f"unreadable {rel}")
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

def extract_method(src, sig_re):
    m = re.search(sig_re, src)
    if not m:
        return None
    i = src.find("{", m.start())
    if i < 0:
        return None
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i : j + 1]
    return None

lss = read("frameworks/base/services/core/java/com/android/server/locksettings/LockSettingsService.java")
helper = read("frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java")
usb = read("frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java")
engine = read("frameworks/base/services/core/java/com/android/server/locksettings/SecureWipeEngine.java")
dwipe = read("frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java")
tests = read("frameworks/base/services/tests/servicestests/src/com/android/server/locksettings/ProgrammaticDuressBinderTests.java")
aidl = read("frameworks/base/core/java/com/android/internal/widget/ILockSettings.aidl")

# 1. checkCredential Binder funnels to doVerifyCredential, not unlockLskfBasedProtector
check = extract_method(
    lss,
    r"public VerifyCredentialResponse checkCredential\(\s*LockscreenCredential credential,",
)
if check is None:
    out("FAIL", "could not extract checkCredential body")
else:
    if "doVerifyCredential(" in check and "unlockLskfBasedProtector" not in check:
        out("PASS", "checkCredential body calls doVerifyCredential; no direct unlockLskfBasedProtector")
    else:
        out("FAIL", "checkCredential does not uniquely funnel through doVerifyCredential")
    if "onVerifyCredentialResult" in check:
        out("FAIL", "checkCredential calls helper directly (expected funnel via doVerifyCredential finally)")
    else:
        out("PASS", "checkCredential does not short-circuit helper (uses doVerifyCredential funnel)")

# 2. verifyCredential 4-arg Binder
verify = extract_method(
    lss,
    r"public VerifyCredentialResponse verifyCredential\(\s*LockscreenCredential credential,\s*LockDomain lockDomain,",
)
if verify is None:
    out("FAIL", "could not extract verifyCredential(LockDomain) body")
else:
    if "doVerifyCredential(" in verify and "unlockLskfBasedProtector" not in verify:
        out("PASS", "verifyCredential Binder body calls doVerifyCredential; no direct unlockLskfBasedProtector")
    else:
        out("FAIL", "verifyCredential Binder does not uniquely funnel through doVerifyCredential")

# 3. 3-arg verifyCredential delegates to Primary 4-arg
verify3 = extract_method(
    lss,
    r"public VerifyCredentialResponse verifyCredential\(\s*LockscreenCredential credential,\s*int userId,\s*int flags\)",
)
if verify3 is None:
    out("FAIL", "could not extract verifyCredential(userId, flags) body")
else:
    if re.search(r"return verifyCredential\(\s*credential,\s*Primary,", verify3):
        out("PASS", "3-arg verifyCredential delegates to Primary 4-arg Binder")
    else:
        out("FAIL", "3-arg verifyCredential does not delegate to Primary 4-arg")

# 4. doVerifyCredential finally always hits helper
dov = extract_method(
    lss,
    r"private VerifyCredentialResponse doVerifyCredential\(\s*LockscreenCredential credential,",
)
if dov is None:
    out("FAIL", "could not extract doVerifyCredential body")
else:
    if "finally" in dov and "duressPasswordHelper.onVerifyCredentialResult(res, credential)" in dov:
        out("PASS", "doVerifyCredential finally calls duressPasswordHelper.onVerifyCredentialResult(res, credential)")
    else:
        out("FAIL", "doVerifyCredential missing finally helper hook")
    if "doVerifyCredentialInner(" in dov:
        out("PASS", "doVerifyCredential delegates inner LSKF verify")
    else:
        out("FAIL", "doVerifyCredential does not call doVerifyCredentialInner")

# 5. verifyTiedProfileChallenge → doVerifyTiedProfileChallenge → doVerifyCredential
vtp = extract_method(
    lss,
    r"public VerifyCredentialResponse verifyTiedProfileChallenge\(",
)
dtv = extract_method(
    lss,
    r"private VerifyCredentialResponse doVerifyTiedProfileChallenge\(",
)
if vtp and "doVerifyTiedProfileChallenge(" in vtp:
    out("PASS", "verifyTiedProfileChallenge Binder calls doVerifyTiedProfileChallenge")
else:
    out("FAIL", "verifyTiedProfileChallenge Binder skip")
if dtv:
    n = dtv.count("doVerifyCredential(")
    if n >= 2:
        out("PASS", f"doVerifyTiedProfileChallenge calls doVerifyCredential {n} times (parent + profile)")
    else:
        out("FAIL", f"doVerifyTiedProfileChallenge doVerifyCredential count={n} expected>=2")
else:
    out("FAIL", "could not extract doVerifyTiedProfileChallenge")

# 6. setLockCredential enroll miss hook (sp == null)
sli = extract_method(
    lss,
    r"private boolean setLockCredentialInternal\(\s*LockscreenCredential credential,",
)
if sli is None:
    out("FAIL", "could not extract setLockCredentialInternal")
else:
    if "unlockLskfBasedProtector" in sli and "duressPasswordHelper.onVerifyCredentialResult(response, savedCredential)" in sli:
        out("PASS", "setLockCredentialInternal miss path calls helper with (response, savedCredential)")
    else:
        out("FAIL", "setLockCredentialInternal miss path does not hook helper")
    # miss hook must be on the enroll-fail branch, not success
    miss = re.search(
        r"if \(sp == null\) \{(?P<body>.*?)^\s{16}\}",
        sli,
        re.S | re.M,
    )
    if miss and "onVerifyCredentialResult(response, savedCredential)" in miss.group("body"):
        out("PASS", "helper hook is inside setLockCredentialInternal sp==null miss branch")
    else:
        # fallback: require helper appears before 'return false' after Failed to enroll
        idx = sli.find("Failed to enroll: incorrect credential.")
        hook = sli.find("duressPasswordHelper.onVerifyCredentialResult(response, savedCredential)")
        retf = sli.find("return false;", hook) if hook >= 0 else -1
        if idx >= 0 and hook > idx and retf > hook:
            out("PASS", "helper hook sits on enroll-fail return (fallback span check)")
        else:
            out("FAIL", "could not prove helper hook is on enroll miss, not success")

# public Binder setLockCredential 4-arg must call setLockCredentialInternal
slc = extract_method(
    lss,
    r"public boolean setLockCredential\(\s*LockscreenCredential credential,\s*LockscreenCredential savedCredential,\s*LockDomain lockDomain,",
)
if slc and "setLockCredentialInternal(" in slc:
    out("PASS", "Binder setLockCredential calls setLockCredentialInternal")
else:
    out("FAIL", "Binder setLockCredential does not call setLockCredentialInternal")

# 7. getHashFactor miss hook
ghf = extract_method(
    lss,
    r"public byte\[\] getHashFactor\(\s*LockscreenCredential currentCredential,",
)
if ghf is None:
    out("FAIL", "could not extract getHashFactor")
else:
    if "getHashFactorInternal(" in ghf and "onVerifyCredentialResult" in ghf:
        out("PASS", "Binder getHashFactor miss path calls helper")
    else:
        out("FAIL", "Binder getHashFactor does not hook helper on miss")
    if 'if (factor == null)' in ghf and "onVerifyCredentialResult" in ghf:
        out("PASS", "getHashFactor helper runs only when factor == null (miss)")
    else:
        out("FAIL", "getHashFactor helper not gated on factor == null")

# 8. verifyGatekeeperPasswordHandle is NOT LSKF — helper must be absent
vgk = extract_method(
    lss,
    r"public VerifyCredentialResponse verifyGatekeeperPasswordHandle\(",
)
if vgk is None:
    out("FAIL", "could not extract verifyGatekeeperPasswordHandle")
else:
    if "onVerifyCredentialResult" in vgk or "doVerifyCredential(" in vgk:
        out("FAIL", "verifyGatekeeperPasswordHandle unexpectedly hooks duress (not an LSKF path)")
    else:
        out("PASS", "verifyGatekeeperPasswordHandle does not invoke helper (handle, not LSKF)")

# 9. Helper wipe reason not rewritten
ovc = extract_method(
    helper,
    r"protected void onVerifyCredentialResult\(",
)
if ovc is None:
    out("FAIL", "could not extract onVerifyCredentialResult")
else:
    if "SecureWipeEngine.run" in ovc and "SecureWipeEngine.Reason.DURESS" in ovc:
        out("PASS", "onVerifyCredentialResult lockscreen wipe is SecureWipeEngine.Reason.DURESS")
    else:
        out("FAIL", "onVerifyCredentialResult wipe reason rewritten or missing")
    if "Reason.ANTI_BRUTEFORCE" in ovc or "Reason.USER_REQUESTED" in ovc:
        out("FAIL", "onVerifyCredentialResult uses a non-DURESS wipe reason")
    else:
        out("PASS", "onVerifyCredentialResult does not use ANTI_BRUTEFORCE/USER_REQUESTED")
    if "isMatched()" in ovc and "isDuressCredential" in ovc:
        out("PASS", "helper no-ops on match; wipe only after isDuressCredential")
    else:
        out("FAIL", "helper missing match short-circuit or isDuressCredential gate")

# Engine enum still has DURESS distinct from other reasons
if re.search(r"enum Reason \{[^}]*DURESS,", engine, re.S):
    out("PASS", "SecureWipeEngine.Reason still lists DURESS")
else:
    out("FAIL", "SecureWipeEngine.Reason.DURESS missing")
if "USER_REQUESTED" in engine and "ANTI_BRUTEFORCE" in engine:
    out("PASS", "USER_REQUESTED and ANTI_BRUTEFORCE remain distinct reasons (not collapsed into DURESS)")
else:
    out("FAIL", "wipe reason enum collapsed")

# LSS must still use ANTI_BRUTEFORCE and USER_REQUESTED on their own paths
if "SecureWipeEngine.Reason.ANTI_BRUTEFORCE" in lss:
    out("PASS", "anti-bruteforce path still Reason.ANTI_BRUTEFORCE (not rewritten to DURESS)")
else:
    out("FAIL", "ANTI_BRUTEFORCE wipe path missing from LSS")
if "SecureWipeEngine.Reason.USER_REQUESTED" in lss:
    out("PASS", "requestSecureWipe still Reason.USER_REQUESTED (not rewritten to DURESS)")
else:
    out("FAIL", "USER_REQUESTED wipe path missing from LSS")

# DuressWipe USB/legacy entry still DURESS
if "SecureWipeEngine.run(context, SecureWipeEngine.Reason.DURESS)" in dwipe:
    out("PASS", "DuressWipe.run still Reason.DURESS")
else:
    out("FAIL", "DuressWipe.run reason rewritten")

# 10. USB still opt-in default 0 (item 7 HOLD — must NOT be flipped on)
if 'SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0")' in usb:
    out("PASS", 'isUsbDuressWipeEnabled defaults SystemProperties.get(..., "0")')
else:
    out("FAIL", "USB duress default is not opt-in 0")
if re.search(r'SystemProperties\.get\(\s*USB_DURESS_WIPE_ENABLED_PROP,\s*"1"\s*\)', usb):
    out("FAIL", "USB duress default flipped to 1 on this stamp")
else:
    out("PASS", "USB duress default not flipped to 1")
if 'if (!isUsbDuressWipeEnabled())' in usb:
    out("PASS", "maybeTriggerUsbDuressWipe returns early unless flag enabled")
else:
    out("FAIL", "USB wipe gate missing isUsbDuressWipeEnabled early return")
if "isVerifiedBootGreen()" in usb:
    out("PASS", "USB wipe still requires verifiedbootstate=green")
else:
    out("FAIL", "USB green-boot gate missing")

# No product mk / overlay sets the flag on
prop_hits = []
for p in (root / "vendor/guardtalk").rglob("*"):
    if not p.is_file():
        continue
    if p.suffix.lower() not in {".mk", ".prop", ".rc", ".xml", ".bp", ".java"}:
        continue
    try:
        txt = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if "usb_duress_wipe.enabled" in txt and p.name != "UsbPortSecurityHooks.java":
        prop_hits.append(str(p.relative_to(root)))
docs_ok = True
code_hits = [h for h in prop_hits if "/docs/" not in h.replace("\\", "/")]
if not code_hits:
    out("PASS", "no vendor/guardtalk product mk/prop sets usb_duress_wipe.enabled (item 7 still HOLD)")
else:
    # fail if any non-doc file assigns =1
    assigned = []
    for h in code_hits:
        t = (root / h).read_text(encoding="utf-8", errors="replace")
        if re.search(r"usb_duress_wipe\.enabled\s*[=:]\s*1", t) or "usb_duress_wipe.enabled=1" in t:
            assigned.append(h)
    if assigned:
        out("FAIL", "USB default-on assigned in product files: " + ", ".join(assigned))
    else:
        out("PASS", "vendor/guardtalk non-doc usb_duress_wipe mentions do not assign =1")

# 11. AIDL Binder surface for LSKF
for name in (
    "checkCredential",
    "verifyCredential",
    "verifyTiedProfileChallenge",
    "setLockCredential",
    "getHashFactor",
    "verifyGatekeeperPasswordHandle",
):
    if name in aidl:
        out("PASS", f"ILockSettings.aidl still declares {name}")
    else:
        out("FAIL", f"ILockSettings.aidl missing {name}")

# 12. Host tests present (atest HOLD — presence only)
needed_tests = [
    "checkCredential_wrongGuess_invokesDuressHelper",
    "checkCredential_correctGuess_stillInvokesDuressHelper",
    "verifyCredential_wrongGuess_invokesDuressHelper",
    "verifyTiedProfileChallenge_wrongParent_invokesDuressHelper",
    "verifyGatekeeperPasswordHandle_doesNotInvokeDuressHelper",
    "setLockCredential_wrongSaved_invokesDuressHelper",
    "getHashFactor_wrongCredential_invokesDuressHelper",
]
for t in needed_tests:
    if f"public void {t}(" in tests:
        out("PASS", f"atest method present: {t}")
    else:
        out("FAIL", f"atest method missing: {t}")
if "Does not exercise" in tests and "Reason.DURESS" in tests:
    out("PASS", "ProgrammaticDuressBinderTests documents wipe engine not exercised (Reason.DURESS stays)")
else:
    out("FAIL", "tests lost DURESS non-exercise comment")

# 13. Adversarial: helper skipped if doVerifyCredential callers drop
callers = [
    "checkCredential",
    "verifyCredential",
    "doVerifyTiedProfileChallenge",
    "tryUnlockWithCachedUnifiedChallenge",
    "unlockChildProfile",
]
# already checked check/verify/tied. tryUnlock + unlockChild:
tuc = extract_method(lss, r"public boolean tryUnlockWithCachedUnifiedChallenge\(")
if tuc and "doVerifyCredential(" in tuc:
    out("PASS", "tryUnlockWithCachedUnifiedChallenge uses doVerifyCredential funnel")
else:
    out("FAIL", "tryUnlockWithCachedUnifiedChallenge skips doVerifyCredential")
ucp = extract_method(lss, r"private void unlockChildProfile\(")
if ucp and "doVerifyCredential(" in ucp:
    out("PASS", "unlockChildProfile uses doVerifyCredential funnel")
else:
    out("FAIL", "unlockChildProfile skips doVerifyCredential")

# 14. setLockCredentialWithToken is token, not LSKF guess — must not be required helper
# (absence is OK). If helper is present, that would be extra, not item-6 miss.
slt = extract_method(
    lss,
    r"private boolean setLockCredentialWithTokenInternalLocked\(",
)
if slt is None:
    out("HOLD", "setLockCredentialWithTokenInternalLocked body not extracted")
elif "onVerifyCredentialResult" in slt:
    out("PASS", "token enroll unexpectedly hooks helper (extra, not a skip)")
else:
    out("PASS", "token enroll does not hook helper (token is not Binder LSKF guess)")

# 15. requestSecureWipe still goes through checkCredential (helper via funnel) then USER_REQUESTED
rsw = extract_method(lss, r"public void requestSecureWipe\(")
if rsw and "checkCredential(" in rsw and "Reason.USER_REQUESTED" in rsw:
    out("PASS", "requestSecureWipe verifies via checkCredential then USER_REQUESTED (not DURESS rewrite)")
else:
    out("FAIL", "requestSecureWipe path rewritten")

print()
print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -ne 0 ]]; then
  FAIL=1
fi

# --- adb / device / wipe HOLD ---
echo
echo "--- adb devices ---"
ADB_OUT="$(adb devices 2>&1 || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | rg -q $'^[[:alnum:].:_-]+[[:space:]]+device$'; then
  hold "adb device listed — programmatic duress wipe e2e NOT run; not device-fixed"
else
  hold "adb devices empty — device/wipe HOLD; never device-fixed"
fi
hold "atest FrameworksServicesTests:ProgrammaticDuressBinderTests not run this host (no lunch/atest)"
hold "item 7 USB duress default-on HOLD until T-REMEDIATE-B1-AVB APPROVED"
hold "destructive lockscreen/USB wipe e2e HOLD (no operator + test unit this stamp)"

echo
if [[ "$FAIL" -ne 0 || "$PY_RC" -ne 0 ]]; then
  echo "RESULT: FAIL  bash_PASS=$PASS_N bash_HOLD=$HOLD_N FAIL=1 PY_RC=$PY_RC"
  echo "LIVE_DEVICE_CLAIMED=false"
  echo "ITEM7=HOLD"
  exit 1
fi
echo "RESULT: PASS (static)  bash_PASS=$PASS_N bash_HOLD=$HOLD_N PY_RC=$PY_RC"
echo "LIVE_DEVICE_CLAIMED=false"
echo "ITEM7=HOLD (USB default still 0)"
exit 0
