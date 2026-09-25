#!/usr/bin/env python3
# Host-static verifier for T-REMEDIATE-B6-PROP-REACHABILITY (pair of
# Q-REMEDIATE-B6-PROP-REACHABILITY). Read-only. No product edits. No packing.
# No flashing. No commit.
#
# What it proves
#   1. PRE-FIX BASELINE (packed stamp, immutable): vendor/build.prop holds 35
#      ro.guardtalk.*, system/build.prop holds 0.
#   2. CONTRACT: prop-denials.txt is complete and byte-exact vs the packed image
#      (35 KEY=VALUE, 35 denial literals).
#   3. MK ROUTING (post-fix source): every ro.guardtalk.* key wired into the
#      komodo product is declared with PRODUCT_SYSTEM_PROPERTIES, and none is
#      declared with PRODUCT_PROPERTY_OVERRIDES.
#   4. SEPOLICY (post-fix source): the label + type exist so init can set the
#      keys (`ro.guardtalk.` -> guardtalk_prop, system_restricted_prop).
#
# Exit 0 = all PASS (HOLDs allowed and reported). Exit 1 = any FAIL.

import os
import re
import subprocess
import sys

PASS = 0
FAIL = 0
HOLD = 0


def ok(msg):
    global PASS
    PASS += 1
    print(f"PASS: {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"FAIL: {msg}")


def hold(msg):
    global HOLD
    HOLD += 1
    print(f"HOLD: {msg}")


ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
os.chdir(ROOT)

STAMP = os.environ.get("STAMP", "releases/desktop-flash/komodo-debug-20260919-080101")
CONTRACT = "vendor/guardtalk/docs/qa/prop-denials.txt"
WIRED = [
    "vendor/guardtalk/device/tokay/guardtalk-product-props.mk",
    "vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk",
    "vendor/guardtalk/device/komodo/guardtalk-telemetry.mk",
    "vendor/guardtalk/device/komodo/guardtalk-messenger.mk",
    "vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk",
]
# Declared only on TARGET_BUILD_VARIANT=user (production_profile marker). The
# debug stamp is userdebug, so it is not in the 35-key baseline. It is still a
# policy flag that must reach system/build.prop on a user build.
USER_ONLY = {"ro.guardtalk.production_profile"}

PROP_RE = re.compile(r"ro\.guardtalk\.[A-Za-z0-9_.]+")
ASSIGN_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(\+=|:=|=)")


def debugfs_count(path, pattern):
    """Return count of lines matching ^pattern in <image>/build.prop."""
    try:
        out = subprocess.run(
            ["debugfs", "-R", "cat /build.prop", path],
            capture_output=True, text=True, timeout=120,
        ).stdout
    except Exception as exc:  # noqa: BLE001
        bad(f"debugfs failed on {path}: {exc}")
        return -1
    return sum(1 for line in out.splitlines() if re.match(pattern, line))


def debugfs_pairs(path):
    """Return sorted KEY=VALUE lines for ro.guardtalk.* in <image>/build.prop."""
    out = subprocess.run(
        ["debugfs", "-R", "cat /build.prop", path],
        capture_output=True, text=True, timeout=120,
    ).stdout
    return sorted(
        line.strip() for line in out.splitlines()
        if line.startswith("ro.guardtalk.")
    )


def debugfs_cat(path, inner):
    """Return the text of `inner` inside ext4 `path`, or None if absent.

    B6 FIX (2026-09-21): the previous revision read `cat /build.prop` for BOTH
    partitions. That path only exists in vendor-style images, so on
    `system.img` debugfs reported "File not found" and the count came back 0 —
    which the caller asserted as "system/build.prop holds exactly 0". The check
    therefore PASSED vacuously, and could not distinguish "0 props" from
    "file missing". It reported PASS even on a stamp whose system/build.prop
    genuinely held 35 keys. Absence must be an error, never a zero.
    """
    res = subprocess.run(
        ["debugfs", "-R", f"cat {inner}", path],
        capture_output=True, text=True, timeout=120,
    )
    if "File not found" in res.stdout or "File not found" in res.stderr:
        return None
    return res.stdout


def guardtalk_lines(text):
    """Count ro.guardtalk.* lines in build.prop text (None -> 0)."""
    if text is None:
        return 0
    return sum(1 for ln in text.splitlines() if ln.startswith("ro.guardtalk."))


def parse_mk(path):
    """Return {var: [(lineno, key)]} for ro.guardtalk.* lines in a makefile."""
    found = {}
    with open(path, encoding="utf-8") as fh:
        cur = ""
        prev_cont = False
        for lineno, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            stripped = line.strip()
            m = ASSIGN_RE.match(line)
            if m:
                cur = m.group(1)
            elif not prev_cont:
                cur = ""
            if stripped.startswith("#"):
                prev_cont = line.rstrip().endswith("\\")
                continue
            km = PROP_RE.search(line)
            if km and cur:
                found.setdefault(cur, []).append((lineno, km.group(0)))
            prev_cont = line.rstrip().endswith("\\")
    return found


# --- 1. pre-fix baseline (immutable stamp) ---------------------------------
print(f"--- pre-fix baseline on {STAMP} ---")
ven = debugfs_count(f"{STAMP}/vendor.img", r"^ro\.guardtalk\.")
print(f"packed vendor ro.guardtalk count = {ven}")
(ok if ven == 35 else bad)(f"packed vendor/build.prop holds exactly 35 (got {ven})")

# B6 FIX (2026-09-21): read the real path. `/build.prop` does not exist in
# system.img, so the old check counted 0 and passed vacuously.
sys_text = debugfs_cat(f"{STAMP}/system.img", "/system/build.prop")
sysn = guardtalk_lines(sys_text)
print(f"packed system ro.guardtalk count = {sysn}")
if sys_text is None:
    bad("packed system/build.prop unreadable (/system/build.prop not found) — "
        "cannot assert the baseline; a missing file must never count as 0")
else:
    (ok if sysn == 0 else bad)(f"packed system/build.prop holds exactly 0 (got {sysn})")

# --- 2. contract -----------------------------------------------------------
print("--- contract (prop-denials.txt) ---")
with open(CONTRACT, encoding="utf-8") as fh:
    ctext = fh.read()
ckeys = sorted(set(
    line.split("=", 1)[0] for line in ctext.splitlines()
    if re.match(r"^ro\.guardtalk\.[A-Za-z0-9_.]+=", line)
))
clits = [l for l in ctext.splitlines()
         if l.startswith("Do not have permissions to set 'ro.guardtalk.")]
print(f"contract keys = {len(ckeys)}  contract literals = {len(clits)}")
(ok if len(ckeys) == 35 else bad)(f"contract lists exactly 35 flags (got {len(ckeys)})")
(ok if len(clits) == 35 else bad)(f"contract lists exactly 35 denial literals (got {len(clits)})")
pkeys = debugfs_pairs(f"{STAMP}/vendor.img")
c_kv = sorted(
    line.strip() for line in ctext.splitlines()
    if re.match(r"^ro\.guardtalk\.[A-Za-z0-9_.]+=", line)
)
(ok if c_kv == pkeys else bad)(
    "contract KEY=VALUE set is byte-identical to the packed image"
    + ("" if c_kv == pkeys else f" (only-in-contract={sorted(set(c_kv)-set(pkeys))}, "
                                 f"only-in-image={sorted(set(pkeys)-set(c_kv))})"))

# --- 3. make routing (post-fix source) -------------------------------------
print("--- mk routing (post-fix source) ---")
declared = set()
for path in WIRED:
    if not os.path.isfile(path):
        bad(f"wired makefile missing: {path}")
        continue
    blocks = parse_mk(path)
    over = blocks.get("PRODUCT_PROPERTY_OVERRIDES", [])
    syst = blocks.get("PRODUCT_SYSTEM_PROPERTIES", [])
    if over:
        bad(f"{path}: ro.guardtalk.* still in PRODUCT_PROPERTY_OVERRIDES "
            f"({len(over)}: {[k for _, k in over][:3]}...)")
    else:
        ok(f"{path}: no ro.guardtalk.* in PRODUCT_PROPERTY_OVERRIDES")
    if not syst:
        bad(f"{path}: no ro.guardtalk.* declared with PRODUCT_SYSTEM_PROPERTIES")
    declared.update(k for _, k in syst)
    print(f"  {path}: PRODUCT_SYSTEM_PROPERTIES ro.guardtalk keys = {len(set(k for _, k in syst))}")

missing = sorted(set(ckeys) - declared)
extra = sorted(declared - set(ckeys))
(ok if not missing else bad)(f"all 35 contract keys are declared with PRODUCT_SYSTEM_PROPERTIES"
                            + ("" if not missing else f" (missing={missing})"))
(ok if set(extra) <= USER_ONLY else bad)(
    f"no undeclared extras beyond the user-only markers (extra={extra})")
print(f"declared (post-fix) = {len(declared)} keys")

# --- 4. sepolicy (post-fix source) -----------------------------------------
print("--- sepolicy (post-fix source) ---")
pctx = "system/sepolicy/private/property_contexts"
pte = "system/sepolicy/private/property.te"
with open(pctx, encoding="utf-8") as fh:
    ctx = fh.read()
with open(pte, encoding="utf-8") as fh:
    te = fh.read()
labeled = re.search(r"^ro\.guardtalk\.\s+u:object_r:guardtalk_prop:s0", ctx, re.M)
(ok if labeled else bad)("property_contexts labels ro.guardtalk. -> guardtalk_prop")
typed = re.search(r"^system_restricted_prop\(guardtalk_prop\)", te, re.M)
(ok if typed else bad)("property.te defines system_restricted_prop(guardtalk_prop)")

# other property_contexts sources must not carry a shadowing label
shadow = []
for dirpath, dirnames, filenames in os.walk("."):
    dirnames[:] = [d for d in dirnames if d not in {".git", "out", "releases"}]
    for name in filenames:
        if "property_contexts" in name:
            p = os.path.join(dirpath, name)
            if p.lstrip("./") in {pctx}:
                continue
            try:
                with open(p, encoding="utf-8", errors="ignore") as fh:
                    if "guardtalk" in fh.read():
                        shadow.append(p)
            except OSError:
                pass
(ok if not shadow else bad)(f"no shadowing guardtalk label elsewhere (found={shadow})")

# --- 5. shipping artifact (the stamp the pointer actually serves) ----------
# B6 FIX (2026-09-21): everything above validates the IMMUTABLE PRE-FIX stamp
# (STAMP defaults to 080101), the source makefiles, and sepolicy. Nothing
# validated the artifact that is actually flashed. That is how a STALE
# vendor.img (its build.prop generated 2026-09-18, before the fix) shipped
# through 080101 -> 175743 -> 041838 while this verifier stayed green:
# the fix was in source and in system/build.prop, but `m systemimage` never
# regenerates vendor.img, so vendor_init kept loading the pre-fix prop file and
# was denied all 35 keys (it may not set a system_restricted_property_type).
# See .agent-comm/evidence/B6-PROP-DENIALS-STALE-VENDOR-IMG.md
print("--- shipping artifact (komodo-debug-latest pointer target) ---")
# Overridable so a specific stamp can be checked without moving the live
# pointer (e.g. SHIP_POINTER=releases/desktop-flash/<old-stamp> to prove the
# check catches a stale vendor.img).
POINTER = os.environ.get(
    "SHIP_POINTER", "releases/desktop-flash/komodo-debug-latest")
if not os.path.exists(POINTER):
    hold(f"pointer {POINTER} absent — cannot check the shipping artifact")
else:
    target = os.path.realpath(POINTER)
    print(f"resolved: {os.path.relpath(target, ROOT)}")
    sven_text = debugfs_cat(f"{target}/vendor.img", "/build.prop")
    ssys_text = debugfs_cat(f"{target}/system.img", "/system/build.prop")
    sven = guardtalk_lines(sven_text)
    ssys = guardtalk_lines(ssys_text)
    if sven_text is None or ssys_text is None:
        bad(f"shipping artifact unreadable (vendor={'ok' if sven_text else 'MISSING'}, "
            f"system={'ok' if ssys_text else 'MISSING'})")
    else:
        (ok if sven == 0 else bad)(
            f"shipping vendor/build.prop holds 0 ro.guardtalk (got {sven}) — "
            "nonzero means vendor.img is STALE: rebuild with `m vendorimage`")
        (ok if ssys == 35 else bad)(
            f"shipping system/build.prop holds 35 ro.guardtalk (got {ssys}) — "
            "this is where init (coredomain) can actually set them")
        ship_pairs = sorted(
            ln.strip() for ln in ssys_text.splitlines()
            if ln.strip().startswith("ro.guardtalk.")
        )
        if len(c_kv) == 35:
            missing = sorted(set(c_kv) - set(ship_pairs))
            extra = sorted(set(ship_pairs) - set(c_kv) - USER_ONLY)
            if missing or extra:
                bad(f"shipping system/build.prop != contract "
                    f"(missing={missing[:4]}, extra={extra[:4]})")
            else:
                ok("shipping system/build.prop KEY=VALUE set matches the contract")

# --- 6. HOLD ---------------------------------------------------------------
print("--- HOLD (not claimed) ---")
hold("on-device / rebuilt-image observation: `getprop` per contract key (rebuild+flash required)")
hold("35-vs-3 denial capture: re-read full kernel log on a rebuilt image (must be 0)")

print(f"--- RESULT: PASS={PASS} FAIL={FAIL} HOLD={HOLD} ---")
sys.exit(1 if FAIL else 0)
