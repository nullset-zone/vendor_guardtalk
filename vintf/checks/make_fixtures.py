#!/usr/bin/env python3
"""Generate the fixtures consumed by check_vintf_bt_absence.py --fixtures.

Committed + re-runnable so the fixture set is inspectable (the generated
*.xml / expected.json files are also committed). Each fixture is a minimal
/vendor/etc/vintf-shaped tree:

    <case>/manifest.xml            main device manifest
    <case>/manifest/<name>.xml     fragments (libvintf merges these at runtime)
    <case>/expected.json           {forbid, raw, raw_fails, expect, why}

HONESTY: fixtures are synthetic; they exercise the checker, not a real image.
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"


def hal(name: str, *fqnames: str, version: str | None = None) -> str:
    v = f"\n        <version>{version}</version>" if version else ""
    fqs = "".join(f"\n        <fqname>{f}</fqname>" for f in fqnames)
    return (f"    <hal format=\"aidl\">\n        <name>{name}</name>{v}{fqs}\n    </hal>\n")


def manifest(body: str = "", comment: str | None = None) -> str:
    head = ""
    if comment:
        head = f"<!--\n  {comment}\n-->\n"
    return (head + '<manifest version="9.0" type="device" target-level="8">\n'
            + body + "</manifest>\n")


CLEAN_BODY = (
    hal("android.hardware.boot", "IBootControl/default")
    + hal("android.hardware.security.keymint", "IRemotelyProvisionedComponent/strongbox", version="3")
)
CLEAN_MAIN = manifest(CLEAN_BODY)
CLEAN_WIFI = manifest(hal("android.hardware.wifi.supplicant", "ISupplicant/default"))

CASES: dict[str, dict] = {
    # positive control: no BT anywhere -> exit 0
    "clean": {
        "cfg": {"forbid": "bt", "raw": False, "expect": 0,
                "why": "control: no BT HAL declaration in main or fragment"},
        "files": {"manifest.xml": CLEAN_MAIN, "manifest/android.hardware.wifi.supplicant.xml": CLEAN_WIFI},
    },
    # negative: BT declared in the MAIN manifest
    "bt_in_main": {
        "cfg": {"forbid": "bt", "raw": False, "expect": 1,
                "why": "android.hardware.bluetooth declared in the main manifest"},
        "files": {"manifest.xml": manifest(
            hal("android.hardware.bluetooth", "IBluetoothHci/default") + CLEAN_BODY)},
    },
    # negative: BT declared ONLY in a fragment (the class a main-only check misses)
    "bt_in_fragment": {
        "cfg": {"forbid": "bt", "raw": False, "expect": 1,
                "why": "android.hardware.bluetooth.audio declared only in a fragment"},
        "files": {"manifest.xml": CLEAN_MAIN,
                  "manifest/bluetooth_audio.xml": manifest(
                      hal("android.hardware.bluetooth.audio", "IBluetoothAudioProviderFactory/default",
                          version="5"))},
    },
    # negative: the Google BT extension declared only in a fragment
    "bt_ext_in_fragment": {
        "cfg": {"forbid": "bt", "raw": False, "expect": 1,
                "why": "vendor.google.bluetooth_ext declared only in a fragment"},
        "files": {"manifest.xml": CLEAN_MAIN,
                  "manifest/vendor.google.bluetooth_ext.xml": manifest(
                      hal("vendor.google.bluetooth_ext", "IBluetoothCcc/default", "IBluetoothSar/default",
                          version="4"))},
    },
    # positive control: the string appears only in a comment -> exit 0
    "bt_comment_only": {
        "cfg": {"forbid": "bt", "raw": False, "expect": 0,
                "why": "Bluetooth named only in an XML comment; no declaration"},
        "files": {"manifest.xml": manifest(CLEAN_BODY,
                                           comment="GuardTalkOS - Bluetooth HALs removed (no_bt variant)")},
    },
    # positive control: the audio HAL's IModule/bluetooth fqname is NOT a BT HAL
    "audio_module_named_bluetooth": {
        "cfg": {"forbid": "bt", "raw": False, "expect": 0,
                "why": "android.hardware.audio.core / IModule/bluetooth is an audio module, not a BT HAL"},
        "files": {"manifest.xml": CLEAN_MAIN,
                  "manifest/android.hardware.audio.service-aidl.aoc.xml": manifest(
                      hal("android.hardware.audio.core", "IModule/bluetooth", "IModule/primary"))},
    },
    # stricter raw view of the same tree -> exit 1 (documents the literal grep)
    "raw_audio_module_named_bluetooth": {
        "cfg": {"forbid": "bt", "raw": True, "raw_fails": True, "expect": 1,
                "why": "raw case-insensitive scan flags IModule/bluetooth (informational)"},
        "files": {"manifest.xml": CLEAN_MAIN,
                  "manifest/android.hardware.audio.service-aidl.aoc.xml": manifest(
                      hal("android.hardware.audio.core", "IModule/bluetooth", "IModule/primary"))},
    },
    # negative for the sibling radio card: telephony HAL in a fragment (dmd class)
    "radio_in_fragment": {
        "cfg": {"forbid": "bt+radio", "raw": False, "expect": 1,
                "why": "dmd.xml-class fragment re-declares the telephony oemservice HAL"},
        "files": {"manifest.xml": CLEAN_MAIN,
                  "manifest/dmd.xml": manifest(
                      hal("vendor.samsung_slsi.telephony.hardware.oemservice", "IOemService/dm0"))},
    },
    # negative for the sibling radio card: radio HAL in the main manifest
    "radio_in_main": {
        "cfg": {"forbid": "bt+radio", "raw": False, "expect": 1,
                "why": "android.hardware.radio declared in the main manifest"},
        "files": {"manifest.xml": manifest(
            hal("android.hardware.radio", "IRadio/slot1") + CLEAN_BODY)},
    },
}


def main() -> int:
    for name, spec in CASES.items():
        d = FIXTURES / name
        (d / "manifest").mkdir(parents=True, exist_ok=True)
        for rel, text in spec["files"].items():
            (d / rel).write_text(text)
        (d / "expected.json").write_text(json.dumps(spec["cfg"], indent=2, sort_keys=True) + "\n")
        print(f"wrote {d.relative_to(HERE)} ({len(spec['files'])} manifest file(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
