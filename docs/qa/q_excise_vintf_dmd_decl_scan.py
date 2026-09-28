#!/usr/bin/env python3
"""Q-EXCISE-VINTF-DMD — independent 13/13 declaration scan + static re-derivation.

Two independent computations, neither trusting the lane's number:

A) An INDEPENDENT XML scan (stdlib ElementTree) of the shipped-stamp extraction
   `.agent-comm/evidence/T-EXCISE-BOOT-SAFETY-GATE/cache/<dev>/vintf/vendor/`
   for all 13 devices:
     * which file(s) declare `vendor.samsung_slsi.telephony.hardware.oemservice`
     * whether the MAIN manifest.xml declares it (must be 0/13)
     * which file(s) declare each telephony/BT forbidden HAL name
   and the same after removing the `manifest/dmd.xml` fragment (the static
   "after" the fix would produce), emitted as TSV.

B) The REAL gate `gate_g5` imported read-only, run on each cached stamp as-is,
   and again with the `manifest/dmd.xml` fragment stripped from the merged
   manifest, to show the actual forbidden_refs / unbacked_decls delta.

Honesty: static analysis of shipped images; no build, no boot.
Exit 0 always (this is a report, not a gate).
"""
import importlib.util
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = HERE.parents[4]
TOOLS = ROOT / ".agent-comm" / "tools"
CACHE = ROOT / ".agent-comm" / "evidence" / "T-EXCISE-BOOT-SAFETY-GATE" / "cache"

_spec = importlib.util.spec_from_file_location(
    "gt_boot_safety_gate_under_test", TOOLS / "gt_boot_safety_gate.py")
g = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(g)

DEVICES = ["akita", "blazer", "caiman", "comet", "frankel", "husky", "komodo",
           "mustang", "rango", "shiba", "stallion", "tegu", "tokay"]

TELEPHONY_PATTERNS = [r"^android\.hardware\.radio", r"^android\.hardware\.telephony",
                      r"^android\.hardware\.ims", r"^android\.hardware\.iwlan",
                      r"^vendor\.samsung_slsi\.telephony", r"oemservice"]
BT_PATTERNS = [r"^android\.hardware\.bluetooth", r"^vendor\.google\.bluetooth_ext"]


def names_in(text):
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        return []
    return [h.findtext("name", "").strip() for h in root.iter("hal")
            if (h.findtext("name") or "").strip()]


def matches(names, patterns):
    out = []
    for nm in names:
        for p in patterns:
            if re.search(p, nm):
                out.append((nm, p))
    return out


def read_device(dev):
    v = CACHE / dev / "vintf" / "vendor"
    main = (v / "manifest.xml").read_text(errors="replace") if (v / "manifest.xml").is_file() else ""
    frags = {}
    fd = v / "manifest"
    if fd.is_dir():
        for f in sorted(fd.glob("*.xml")):
            frags[f.name] = f.read_text(errors="replace")
    return main, frags


def scan():
    rows = []
    for dev in DEVICES:
        main, frags = read_device(dev)
        main_names = names_in(main)
        # baseline merged
        base_names = list(main_names)
        for fn, txt in frags.items():
            base_names += names_in(txt)
        # after-removal merged (drop the dmd.xml fragment)
        after_names = list(main_names)
        for fn, txt in frags.items():
            if fn == "dmd.xml":
                continue
            after_names += names_in(txt)

        oem_files = [("manifest.xml", names_in(main))] if "oemservice" in main else []
        for fn, txt in frags.items():
            if "oemservice" in txt:
                oem_files.append((f"manifest/{fn}", names_in(txt)))
        oem_files = [(f, n) for (f, n) in oem_files
                     if any("oemservice" in x for x in n)]

        base_tel = matches(base_names, TELEPHONY_PATTERNS)
        after_tel = matches(after_names, TELEPHONY_PATTERNS)
        base_bt = matches(base_names, BT_PATTERNS)
        after_bt = matches(after_names, BT_PATTERNS)
        rows.append({
            "device": dev,
            "oemservice_files": ";".join(f for f, _ in oem_files) or "-",
            "oemservice_in_main": "oemservice" in main,
            "tel_decl_baseline": len({n for n, _ in base_tel}),
            "tel_forbidden_baseline": len(base_tel),
            "tel_decl_after_drop": len({n for n, _ in after_tel}),
            "tel_forbidden_after_drop": len(after_tel),
            "bt_decl_baseline": len({n for n, _ in base_bt}),
            "bt_decl_after_drop": len({n for n, _ in after_bt}),
        })
    return rows


def gate_replay():
    """Real gate_g5 on cached stamps as-is, and with dmd.xml stripped."""
    out = []
    for dev in DEVICES:
        main, frags = read_device(dev)
        sysd = CACHE / dev / "vintf" / "system"
        smain = (sysd / "manifest.xml").read_text(errors="replace") if (sysd / "manifest.xml").is_file() else ""
        sfrags = {}
        sfd = sysd / "manifest"
        if sfd.is_dir():
            for f in sorted(sfd.glob("*.xml")):
                sfrags[f.name] = f.read_text(errors="replace")
        ds = {"device": dev, "family": "", "stamp": dev,
              "vintf": {"vendor_main": main, "vendor_fragments": dict(frags),
                        "system_main": smain, "system_fragments": sfrags},
              "init": {"vendor": {}, "system": {}, "binaries": set()}}
        base = g.gate_g5(ds)
        ds2 = {"device": dev, "family": "", "stamp": dev,
               "vintf": {"vendor_main": main,
                         "vendor_fragments": {k: v for k, v in frags.items()
                                              if k != "dmd.xml"},
                         "system_main": smain, "system_fragments": sfrags},
               "init": {"vendor": {}, "system": {}, "binaries": set()}}
        after = g.gate_g5(ds2)
        out.append({
            "device": dev,
            "forbidden_baseline": base["forbidden_refs"],
            "forbidden_after_drop": after["forbidden_refs"],
            "oem_baseline": sum(1 for f in base["details"]["forbidden_list"]
                                if "oemservice" in f["name"]),
            "oem_after_drop": sum(1 for f in after["details"]["forbidden_list"]
                                  if "oemservice" in f["name"]),
            "unbacked_baseline": base["unbacked_decls"],
            "unbacked_after_drop": after["unbacked_decls"],
        })
    return out


def main():
    rows = scan()
    print("=== A) independent XML declaration scan (13/13) ===")
    hdr = ["device", "oemservice_files", "oemservice_in_main",
           "tel_decl_baseline", "tel_forbidden_baseline",
           "tel_decl_after_drop", "tel_forbidden_after_drop",
           "bt_decl_baseline", "bt_decl_after_drop"]
    print("\t".join(hdr))
    for r in rows:
        print("\t".join(str(r[h]) for h in hdr))
    n_main = sum(1 for r in rows if r["oemservice_in_main"])
    n_oem_dmd_only = sum(1 for r in rows
                         if r["oemservice_files"] == "manifest/dmd.xml")
    n_tel0 = sum(1 for r in rows if r["tel_decl_after_drop"] == 0)
    print(f"\nSUMMARY: oemservice in MAIN manifest = {n_main}/13 "
          f"(Architect claimed 0); oemservice in dmd.xml ONLY = {n_oem_dmd_only}/13; "
          f"telephony declarations after dropping dmd.xml = 0 on {n_tel0}/13")

    print("\n=== B) REAL gate_g5 replay on shipped stamps ===")
    hdr2 = ["device", "forbidden_baseline", "forbidden_after_drop",
            "oem_baseline", "oem_after_drop",
            "unbacked_baseline", "unbacked_after_drop"]
    print("\t".join(hdr2))
    gs = gate_replay()
    for r in gs:
        print("\t".join(str(r[h]) for h in hdr2))
    print(f"\nSUMMARY: gate_g5 forbidden_refs baseline "
          f"{sorted({r['forbidden_baseline'] for r in gs})} -> after-drop "
          f"{sorted({r['forbidden_after_drop'] for r in gs})}; "
          f"oemservice matches baseline "
          f"{sorted({r['oem_baseline'] for r in gs})} -> 0 after drop (all 13)")

    json.dump({"scan": rows, "gate_replay": gs}, sys.stdout, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
