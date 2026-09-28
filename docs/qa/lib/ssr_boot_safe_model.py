"""Boot-safe DeviceLock registration model for the B2-APEX host rematch.

Card: ``T-EXCISE-E20-SSR-MODEL-ADJUDICATE`` (adjudication of the residual SSR
structural finding in ``verify_remediate_b2_apex_host.sh``).

The pre-adjudication check asserted a **hard** compile-time reference::

    if "import android.devicelock.DeviceLockFrameworkInitializer;" in ssr:
        out("HOLD", "SSR still hard-imports DeviceLockFrameworkInitializer (BCP required)")
    else:
        out("FAIL", "SSR DeviceLockFrameworkInitializer import missing (BCP HOLD rationale gone)")

That premise is inverted.  A hard ``import``/static call puts a DEX
``CONSTANT_Class`` descriptor (``Landroid/devicelock/DeviceLockFrameworkInitializer;``)
into ``SystemServiceRegistry``.  ART resolves that descriptor during class
verification/linking, so when the DeviceLock APEX is excised the class fails to
link **regardless of any Java try/catch** — the revision that boot-looped Zygote
(``komodo-debug-20260918-180338``, "hard call, NO catch"; ``System zygote
died`` / ``init.svc.zygote=restarting``).  Interposing a bare
``try/catch (NoClassDefFoundError)`` (``komodo-debug-20260919-080101``) did
**not** remove the descriptor either — independently reproduced with
``strings -a``: descriptor count 1 in both packed stamps.

The boot-safe design instead uses a guarded reflective lookup, which leaves the
descriptor **absent** (``out/target/product/komodo/system.img``: descriptor count
0, ``registerDeviceLockServiceWrappersIfPresent`` present)::

    private static void registerDeviceLockServiceWrappersIfPresent() {
        try {
            Class<?> initializer = Class.forName(
                    "android.devicelock.DeviceLockFrameworkInitializer");
            initializer.getMethod("registerServiceWrappers").invoke(null);
        } catch (ClassNotFoundException | NoClassDefFoundError e) {
            Slog.w(TAG, "DeviceLock APEX absent — skip "
                    + "DeviceLockFrameworkInitializer.registerServiceWrappers()");
        } catch (ReflectiveOperationException e) {
            Slog.w(TAG, "DeviceLockFrameworkInitializer.registerServiceWrappers failed", e);
        }
    }

This module asserts the boot-safe contract.  It is deliberately **not** weaker
than the old check: it FAILs both when a hard reference is reintroduced (the
Zygote hazard) and when the reflective registration is genuinely missing or
never invoked (the feature regression the old check was trying to protect).

Evidence: ``.agent-comm/evidence/T-EXCISE-E20-SSR-MODEL-ADJUDICATE/``.
"""

import re

_DEVICELOCK = "DeviceLockFrameworkInitializer"

# A hard import is a compile-time type reference -> CONSTANT_Class.
_HARD_IMPORT = re.compile(
    r"^\s*import\s+android\.devicelock\.DeviceLockFrameworkInitializer\s*;", re.M)

# A hard static call / field access on the class is also a type reference.
# Matched only against comment-free, string-free Java so the reflective
# ``getMethod("registerServiceWrappers")`` call and the Slog string literals
# cannot be mistaken for it.
_HARD_CALL = re.compile(r"\bDeviceLockFrameworkInitializer\s*\.\s*\w+\s*\(")

# The boot-safe registration mechanism (needs the string literals intact).
_REFLECT_CLASS = re.compile(
    r"Class\.forName\(\s*\"android\.devicelock\.DeviceLockFrameworkInitializer\"\s*\)")
_REFLECT_METHOD = re.compile(r"getMethod\(\s*\"registerServiceWrappers\"\s*\)")
_REFLECT_CALLSITE = re.compile(
    r"registerDeviceLockServiceWrappersIfPresent\s*\(\s*\)\s*;")


def _java_clean(src, drop_strings):
    """Return Java source with ``//`` and ``/* */`` comments removed.

    When ``drop_strings`` is True, ``"..."`` / ``'...'`` literals are blanked
    as well (length preserved via spaces) so identifier scans cannot match
    inside a string.  A small hand-rolled scanner is used because the input is
    a single trusted source file and a regex cannot correctly model escapes.
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in ('"', "'"):
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c:
                    j += 1
                    break
                j += 1
            out.append(" " * (j - i) if drop_strings else src[i:j])
            i = j
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            j = i + 2
            while j < n and src[j] != "\n":
                j += 1
            out.append(" " * (j - i))
            i = j
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            j = i + 2
            while j + 1 < n and not (src[j] == "*" and src[j + 1] == "/"):
                j += 1
            j = min(n, j + 2)
            out.append(" " * (j - i))
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


def check_ssr_boot_safe(ssr):
    """Return ``[(kind, message), ...]`` for the boot-safe DeviceLock contract.

    ``kind`` is ``"PASS"`` or ``"FAIL"``.  Both failure directions are covered:
    a reintroduced hard reference (boot hazard) and an absent/uninvoked
    reflective registration (genuinely missing initializer).
    """
    code_no_strings = _java_clean(ssr, drop_strings=True)
    code_with_strings = _java_clean(ssr, drop_strings=False)
    findings = []

    if _HARD_IMPORT.search(code_with_strings):
        findings.append(("FAIL",
                         "SSR boot-safe: hard import of DeviceLockFrameworkInitializer "
                         "reintroduced (CONSTANT_Class / Zygote death-loop class)"))
    else:
        findings.append(("PASS",
                         "SSR boot-safe: no hard import of DeviceLockFrameworkInitializer"))

    if _HARD_CALL.search(code_no_strings):
        findings.append(("FAIL",
                         "SSR boot-safe: hard DeviceLockFrameworkInitializer call "
                         "reintroduced (CONSTANT_Class / Zygote death-loop class)"))
    else:
        findings.append(("PASS",
                         "SSR boot-safe: no hard DeviceLockFrameworkInitializer call"))

    guarded = ("ClassNotFoundException" in code_with_strings
               and "NoClassDefFoundError" in code_with_strings)
    if (_REFLECT_CLASS.search(code_with_strings)
            and _REFLECT_METHOD.search(code_with_strings)
            and guarded):
        findings.append(("PASS",
                         "SSR boot-safe: guarded reflective DeviceLock registration present"))
    else:
        findings.append(("FAIL",
                         "SSR boot-safe: DeviceLock initializer registration genuinely "
                         "missing (no guarded reflection)"))

    if _REFLECT_CALLSITE.search(code_with_strings):
        findings.append(("PASS",
                         "SSR boot-safe: reflective registration invoked from "
                         "registerServiceWrappers()"))
    else:
        findings.append(("FAIL",
                         "SSR boot-safe: reflective DeviceLock registration is dead code "
                         "(never invoked)"))

    return findings


def selftest_ssr_model(real_source):
    """Non-vacuity control: real source PASSes, every mutant FAILs.

    Returns 0 on success, 1 otherwise.  Mutants are derived from the real
    source so the control tracks the shipped text; a mutant that fails to
    construct simply leaves the source unchanged and is reported as a miss.
    """
    results = []

    def run(name, src, expect_fail):
        failed = [m for k, m in check_ssr_boot_safe(src) if k == "FAIL"]
        ok = bool(failed) == expect_fail
        results.append((name, ok, expect_fail, failed))
        return ok

    # 1. the real shipped source must pass.
    run("real-source", real_source, expect_fail=False)

    # 2. hard import reintroduced (the 180338 hazard class).
    run("mutant-hard-import",
        "import android.devicelock.DeviceLockFrameworkInitializer;\n" + real_source,
        expect_fail=True)

    # 3. hard static call reintroduced (reflection replaced by a direct invoke).
    hard_call = real_source.replace(
        'initializer.getMethod("registerServiceWrappers").invoke(null);',
        "DeviceLockFrameworkInitializer.registerServiceWrappers();")
    run("mutant-hard-call", hard_call, expect_fail=True)

    # 4. genuinely missing initializer (reflective lookup removed).
    missing = re.sub(
        r'Class<\?> initializer = Class\.forName\('
        r'\s*"android\.devicelock\.DeviceLockFrameworkInitializer"\);\s*\n',
        "", real_source, count=1)
    run("mutant-missing-initializer", missing, expect_fail=True)

    # 5. reflection no longer guarded (catch loses the linkage/boot errors).
    unguarded = real_source.replace(
        "ClassNotFoundException | NoClassDefFoundError e", "RuntimeException e")
    run("mutant-unguarded-reflection", unguarded, expect_fail=True)

    # 6. registration is dead code (call site removed).
    dead = real_source.replace(
        "            registerDeviceLockServiceWrappersIfPresent();\n", "", 1)
    run("mutant-dead-code", dead, expect_fail=True)

    ok_all = True
    print("SSR boot-safe model selftest:")
    for name, ok, expect_fail, failed in results:
        print("  %s: %s (expected_fail=%s)" % (
            "PASS" if ok else "FAIL", name, str(expect_fail).lower()))
        if not ok:
            if failed:
                for m in failed:
                    print("      FAIL: " + m)
            else:
                print("      no FAIL raised (mutant did not construct or did not bite)")
        ok_all = ok_all and ok
    print("SSR MODEL SELFTEST: " + ("PASS (exit 0)" if ok_all else "FAIL (exit 1)"))
    return 0 if ok_all else 1
