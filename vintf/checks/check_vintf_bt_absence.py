#!/usr/bin/env python3
"""Assert the RUNTIME-MERGED vendor VINTF manifest declares no Bluetooth HAL.

libvintf merges the main device manifest with EVERY fragment under
/vendor/etc/vintf/manifest/ at runtime
(system/libvintf/VintfObject.cpp:282-328), so a check that only reads
manifest.xml cannot see a BT HAL re-declared by a fragment. This checker reads
both and evaluates the union.

It is DECLARATION-level (it parses each <hal><name>), which is the semantically
correct "a BT HAL is declared" test and matches the boot-safety gate's G5 rule
in .agent-comm/tools/gt-vintf-expected-refs.yaml. It deliberately does NOT flag
mere occurrences of the string "bluetooth" (e.g. the audio HAL's
`<fqname>IModule/bluetooth</fqname>`, or an XML comment) -- those are not BT HAL
declarations. Use --raw to additionally report raw case-insensitive matches (an
informational, stricter view) when auditing the literal `grep -i bluetooth`.

Usage:
  # a vintf root: DIR/manifest.xml + DIR/manifest/*.xml
  check_vintf_bt_absence.py --vintf-root /path/to/vendor/etc/vintf

  # a device's already-extracted boot-safety-gate cache
  check_vintf_bt_absence.py --device-capture tokay

  # also fail on the radio fragment class (dmd.xml) -- proves fragment coverage
  check_vintf_bt_absence.py --vintf-root DIR --forbid bt+radio

  # run the committed fixtures and assert each expected exit code
  check_vintf_bt_absence.py --fixtures vendor/guardtalk/vintf/checks/fixtures

Exit codes: 0 = clean, 1 = forbidden HAL declared, 2 = usage / IO error.

HONESTY: static analysis only. No build, no stamp, no device.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Mirrors the BT entries of .agent-comm/tools/gt-vintf-expected-refs.yaml
# (forbidden_hal_name_patterns). Kept in sync by review; do NOT weaken.
BT_PATTERNS = [
    (r"^android\.hardware\.bluetooth(\..+)?$", "BT HAL must not be declared (R-3)"),
    (r"^vendor\.google\.bluetooth_ext$", "Google BT extension HAL residue (R-3)"),
]
RADIO_PATTERNS = [
    (r"^android\.hardware\.radio", "cellular radio HAL must not be declared (R-1)"),
    (r"^android\.hardware\.telephony", "framework telephony HAL must not be declared (R-5)"),
    (r"^android\.hardware\.ims", "IMS/VoLTE HAL must not be declared (R-1)"),
    (r"^android\.hardware\.iwlan", "IWLAN HAL must not be declared (R-1)"),
    (r"^vendor\.samsung_slsi\.telephony", "dmd.xml telephony oemservice defeats the radio-free manifest (R-5)"),
    (r"oemservice", "radioExternal/oemservice HAL residue"),
]
RAW_RX = re.compile(r"bluetooth", re.IGNORECASE)


def patterns_for(forbid: str):
    pats = list(BT_PATTERNS)
    if forbid == "bt+radio":
        pats += RADIO_PATTERNS
    return pats


def manifest_files(root: Path) -> dict[str, Path]:
    """Map a display source -> file path for the main manifest + fragments."""
    out: dict[str, Path] = {}
    main = root / "manifest.xml"
    if main.is_file():
        out[str(main)] = main
    frag_dir = root / "manifest"
    if frag_dir.is_dir():
        for f in sorted(frag_dir.glob("*.xml")):
            out[str(f)] = f
    return out


def declarations(path: Path):
    """Yield (name, fqname) for every <hal> in an XML manifest file."""
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        raise ValueError(f"{path}: not well-formed XML: {e}") from e
    for hal in root.iter("hal"):
        name = (hal.findtext("name") or "").strip()
        fqs = [(f.text or "").strip() for f in hal.findall("fqname") if (f.text or "").strip()]
        if name:
            yield name, ",".join(fqs)


def evaluate(files: dict[str, Path], forbid: str, raw: bool):
    pats = patterns_for(forbid)
    violations = []
    raw_hits = []
    scanned = 0
    for src, path in files.items():
        scanned += 1
        for name, fq in declarations(path):
            for rx, why in pats:
                if re.search(rx, name):
                    violations.append({"source": src, "name": name, "fqname": fq,
                                       "pattern": rx, "reason": why})
                    break
        if raw:
            text = path.read_text(errors="replace")
            for ln, line in enumerate(text.splitlines(), 1):
                if RAW_RX.search(line):
                    raw_hits.append({"source": src, "line": ln, "text": line.strip()})
    return {"scanned_files": scanned, "violations": violations, "raw_hits": raw_hits}


def _print_report(res: dict, forbid: str, raw: bool, root: str) -> None:
    print(f"vintf root : {root}")
    print(f"forbidden  : {forbid}")
    print(f"files      : {res['scanned_files']} (main manifest + fragments)")
    if res["violations"]:
        print(f"RESULT     : FAIL - {len(res['violations'])} forbidden HAL declaration(s)")
        for v in res["violations"]:
            print(f"  - {v['name']}  [{v['fqname']}]  {v['source']}  ({v['reason']})")
    else:
        print("RESULT     : PASS - 0 forbidden HAL declarations in the merged manifest")
    if raw:
        if res["raw_hits"]:
            print(f"raw tokens : {len(res['raw_hits'])} case-insensitive 'bluetooth' line(s) "
                  "(informational - may be non-HAL: audio IModule, comments)")
            for h in res["raw_hits"]:
                print(f"  ~ {h['source']}:{h['line']}: {h['text']}")
        else:
            print("raw tokens : 0 case-insensitive 'bluetooth' line(s)")


def run_fixtures(fixtures: Path) -> int:
    if not fixtures.is_dir():
        print(f"error: fixtures dir not found: {fixtures}", file=sys.stderr)
        return 2
    failures = 0
    print(f"{'fixture':28} {'forbid':9} {'raw':5} {'expect':7} {'got':4} verdict")
    for case in sorted(p for p in fixtures.iterdir() if p.is_dir()):
        cfg_path = case / "expected.json"
        if not cfg_path.is_file():
            print(f"  {case.name}: missing expected.json", file=sys.stderr)
            failures += 1
            continue
        cfg = json.loads(cfg_path.read_text())
        files = manifest_files(case)
        res = evaluate(files, cfg.get("forbid", "bt"), bool(cfg.get("raw", False)))
        got = 1 if res["violations"] else 0
        if cfg.get("raw") and cfg.get("raw_fails") and res["raw_hits"]:
            got = 1
        expect = int(cfg["expect"])
        ok = got == expect
        if not ok:
            failures += 1
        print(f"{case.name:28} {cfg.get('forbid','bt'):9} {str(bool(cfg.get('raw',False))):5} "
              f"{expect:<7} {got:<4} {'PASS' if ok else 'FAIL'}")
        if not ok:
            for v in res["violations"]:
                print(f"      got violation: {v['name']} @ {v['source']}")
    print()
    print(f"fixtures: {'ALL PASS' if not failures else str(failures) + ' FAILED'}")
    return 1 if failures else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--vintf-root", help="dir with manifest.xml + manifest/*.xml")
    src.add_argument("--device-capture", help="device codename in the boot-safety-gate cache")
    src.add_argument("--fixtures", help="fixtures dir; assert each expected exit code")
    ap.add_argument("--forbid", choices=["bt", "bt+radio"], default="bt")
    ap.add_argument("--raw", action="store_true",
                    help="also flag raw case-insensitive 'bluetooth' tokens (informational; "
                         "still exits 1 if any are found)")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a text report")
    args = ap.parse_args(argv)

    if args.fixtures:
        return run_fixtures(Path(args.fixtures))

    repo = Path(__file__).resolve().parents[4]
    if args.device_capture:
        root = (repo / ".agent-comm" / "evidence" / "T-EXCISE-BOOT-SAFETY-GATE"
                / "cache" / args.device_capture / "vintf" / "vendor")
    else:
        root = Path(args.vintf_root)
    if not root.is_dir():
        print(f"error: vintf root not found: {root}", file=sys.stderr)
        return 2
    files = manifest_files(root)
    if not files:
        print(f"error: no manifest.xml and no manifest/*.xml under {root}", file=sys.stderr)
        return 2
    try:
        res = evaluate(files, args.forbid, args.raw)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps({"root": str(root), "forbid": args.forbid, **res}, indent=2, sort_keys=True))
    else:
        _print_report(res, args.forbid, args.raw, str(root))

    if res["violations"]:
        return 1
    if args.raw and res["raw_hits"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
