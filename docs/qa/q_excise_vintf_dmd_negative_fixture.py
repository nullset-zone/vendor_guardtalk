#!/usr/bin/env python3
"""Q-EXCISE-VINTF-DMD — adversarial NEGATIVE FIXTURE.

Claim under test (T-EXCISE-VINTF-DMD): dropping the `dmd.xml` VINTF fragment
module removes the `vendor.samsung_slsi.telephony.hardware.oemservice`
declaration.  A naive check that only reads the MAIN vendor manifest would be
FALSE-PASS-prone, because libvintf merges the main manifest with every
/vendor/etc/vintf/manifest/*.xml fragment at runtime
(system/libvintf/VintfObject.cpp:282-328).

This harness therefore injects a telephony HAL into a FRAGMENT (dmd.xml) — NOT
into the main manifest — and proves the REAL `gate_g5` (imported read-only from
`.agent-comm/tools/gt_boot_safety_gate.py`) still detects it and that the real
CLI entrypoint (`main(["--fixture", ...])`) exits NON-ZERO.

Nothing in the gate tool is edited.  The fixture trees are synthesized in a
tempdir by reusing the gate's own `build_fixture("clean-control")` baseline and
then re-pointing the module globals (`FIXTURES`, `build_fixture`,
`FIXTURE_EXPECT_GATE`) for the duration of the run.  Honesty: static only.

Exit 0 = the negative fixture was detected by G5 with a non-zero process exit
AND the clean control exited 0.  Any other outcome = exit 1.
"""
import contextlib
import importlib.util
import io
import json
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = HERE.parents[4]
TOOLS = ROOT / ".agent-comm" / "tools"

_spec = importlib.util.spec_from_file_location(
    "gt_boot_safety_gate_under_test", TOOLS / "gt_boot_safety_gate.py")
g = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(g)

_OEMSERVICE = """<manifest version="9.0" type="device">
    <hal format="hidl">
        <name>vendor.samsung_slsi.telephony.hardware.oemservice</name>
        <transport>hwbinder</transport>
        <fqname>@1.0::IOemService/dm0</fqname>
        <fqname>@1.0::IOemService/dm1</fqname>
    </hal>
</manifest>
"""
_MAIN_WITH_TELEPHONY = """<manifest version="9.0" type="device">
  <hal format="aidl"><name>android.hardware.health</name><fqname>IHealth/default</fqname></hal>
  <hal format="aidl"><name>android.hardware.power</name><fqname>IPower/default</fqname></hal>
  <hal format="hidl">
    <name>vendor.samsung_slsi.telephony.hardware.oemservice</name>
    <transport>hwbinder</transport>
    <fqname>@1.0::IOemService/dm0</fqname>
  </hal>
</manifest>
"""

KINDS = ("clean-control", "telephony-in-fragment", "telephony-in-main")


def _prepare(tmp: Path):
    """Build the three fixture trees from the gate's OWN clean baseline."""
    base_root = tmp / "_basebuild"
    base_root.mkdir(parents=True, exist_ok=True)
    g.FIXTURES = base_root                            # real builder, clean tree
    base = g.build_fixture("clean-control")
    g.FIXTURES = tmp
    prepared = {}
    for kind in ("clean-control", "telephony-in-fragment", "telephony-in-main"):
        d = tmp / kind
        shutil.rmtree(d, ignore_errors=True)
        shutil.copytree(base, d)
        meta = json.loads((d / "meta.json").read_text())
        meta["fixture"] = kind
        meta["stamp_name"] = f"fixture-{kind}"
        meta["stamp"] = f"fixture-{kind}"
        (d / "meta.json").write_text(json.dumps(meta, indent=2))
        if kind == "telephony-in-fragment":
            (d / "vintf" / "vendor" / "manifest" / "dmd.xml").write_text(_OEMSERVICE)
        elif kind == "telephony-in-main":
            (d / "vintf" / "vendor" / "manifest.xml").write_text(_MAIN_WITH_TELEPHONY)
        prepared[kind] = d
    shutil.rmtree(base_root, ignore_errors=True)
    return prepared


def _install_patches(prepared):
    g.build_fixture = lambda name: prepared[name]          # no rebuild/rmtree
    g.FIXTURE_EXPECT_CLEAN = set(g.FIXTURE_EXPECT_CLEAN)
    g.FIXTURE_EXPECT_GATE = dict(g.FIXTURE_EXPECT_GATE)
    g.FIXTURE_EXPECT_GATE["telephony-in-fragment"] = "G5"
    g.FIXTURE_EXPECT_GATE["telephony-in-main"] = "G5"


def _run_cli(name):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = g.main(["--fixture", name])
    return rc, buf.getvalue()


def _forbidden_sources(ds):
    r = g.gate_g5(ds)
    oem_hits = [f for f in r["details"]["forbidden_list"]
                if "oemservice" in f["name"]]
    v = ds["vintf"]
    main_has = "oemservice" in v["vendor_main"]
    frag_has = any("oemservice" in t for t in v["vendor_fragments"].values())
    return r, oem_hits, main_has, frag_has


def main() -> int:
    failures = []
    with tempfile.TemporaryDirectory(prefix="q_vintf_dmd_neg_") as td:
        tmp = Path(td)
        prepared = _prepare(tmp)
        _install_patches(prepared)

        results = {}
        for kind in KINDS:
            rc, out = _run_cli(kind)
            ds = g.load_fixture(kind, refresh=True)
            g5, oem_hits, main_has, frag_has = _forbidden_sources(ds)
            results[kind] = {"exit": rc, "g5_pass": g5["pass"],
                             "forbidden_refs": g5["forbidden_refs"],
                             "oemservice_hits": oem_hits,
                             "oemservice_in_main": main_has,
                             "oemservice_in_fragment": frag_has,
                             "stdout_tail": out}
            print(f"--- {kind}: process_exit={rc} G5.pass={g5['pass']} "
                  f"forbidden_refs={g5['forbidden_refs']} "
                  f"oemservice_hits={len(oem_hits)} "
                  f"in_main={main_has} in_fragment={frag_has}")
            for h in oem_hits:
                print(f"      oemservice via {h['pattern']!r}")

        # (1) positive control: clean tree must exit 0
        if results["clean-control"]["exit"] != 0:
            failures.append("clean-control did not exit 0")
        if not results["clean-control"]["g5_pass"]:
            failures.append("clean-control G5 did not pass")

        # (2) THE adversarial case: telephony in a FRAGMENT -> non-zero + G5 FAIL
        frag = results["telephony-in-fragment"]
        if frag["exit"] == 0:
            failures.append("telephony-in-fragment exited 0 (NOT DETECTED)")
        if frag["g5_pass"]:
            failures.append("telephony-in-fragment G5 passed (NOT DETECTED)")
        if not frag["oemservice_hits"]:
            failures.append("telephony-in-fragment: no oemservice forbidden hit")
        if frag["oemservice_in_main"]:
            failures.append("telephony-in-fragment: oemservice leaked into main "
                            "(fixture is not adversarially fragment-only)")
        if not frag["oemservice_in_fragment"]:
            failures.append("telephony-in-fragment: fixture fragment missing")
        if frag["oemservice_in_fragment"] and not frag["oemservice_in_main"] \
                and frag["oemservice_hits"]:
            print("\nPROOF: oemservice exists ONLY in the fragment "
                  "(main manifest clean) yet G5 still flags it -> the check "
                  "MERGES fragments, it does not read the main manifest alone.")

        # (3) main-manifest control (naive check would catch this; must too)
        m = results["telephony-in-main"]
        if m["exit"] == 0 or m["g5_pass"] or not m["oemservice_hits"]:
            failures.append("telephony-in-main not detected")

    print()
    print(json.dumps({k: {kk: vv for kk, vv in v.items() if kk != "stdout_tail"}
                      for k, v in results.items()}, indent=2))
    if failures:
        print("\nNEGATIVE FIXTURE HARNESS: FAIL")
        for f in failures:
            print(f"  - {f}")
        print("exit 1")
        return 1
    print("\nNEGATIVE FIXTURE HARNESS: PASS — telephony-in-fragment detected by "
          "G5 with non-zero process exit; clean control exit 0")
    print("exit 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
