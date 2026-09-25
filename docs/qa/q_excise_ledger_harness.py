#!/usr/bin/env python3
"""Q-EXCISE-LEDGER adversarial verification harness (READ-ONLY).

Task: Q-EXCISE-LEDGER (QA Engineer, Panel 4) -- adversarially re-derive the
`T-EXCISE-LEDGER` machine-readable excision ledger and try to falsify it.

This harness NEVER edits product code and NEVER writes to the tree. It only
reads built artifacts (`out/target/product/<dev>/`) and shipped release stamps
(`releases/desktop-flash/<dev>-latest/*.img` via read-only `debugfs`).

Modes
-----
  artifacts (default)  Re-derive a fixed cell set from PRIMARY artifacts and
                       compare each verdict to the harness's embedded ground
                       truth (EXPECTED). Exit 0 iff every cell matches.
                       This is the positive control / detector sanity check.
  ledger               Compare the embedded ground truth to the DELIVERABLE
                       UNDER TEST (`vendor/guardtalk/docs/qa/excision_ledger.json`).
                       Exit != 0 if the ledger disagrees with any re-derived cell
                       (that is the falsification signal).
  attacks              Run the required structural attacks (makefile-evidence
                       cells, stamp/-latest resolution, variant resolution) and
                       print per-attack results.

Negative control
----------------
`--fixture DIR` swaps the artifact root for a mirrored fixture. The bundled
`fixtures/un-excised/` mirror has a deliberately UN-EXCISED shiba blocklist
(nitrous/gnss not blocklisted while still in `modules.load`). Running
`artifacts --fixture .../un-excised` therefore exits NON-ZERO: a harness that
cannot fail is not evidence.

Usage
-----
  python3 vendor/guardtalk/docs/qa/q_excise_ledger_harness.py --mode artifacts
  python3 vendor/guardtalk/docs/qa/q_excise_ledger_harness.py --mode ledger
  python3 vendor/guardtalk/docs/qa/q_excise_ledger_harness.py --mode artifacts \
      --fixture vendor/guardtalk/docs/qa/fixtures/un-excised
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
LEDGER = os.path.join(REPO, "vendor/guardtalk/docs/qa/excision_ledger.json")

DEVICES = [
    "shiba", "husky", "akita", "tokay", "caiman", "komodo", "comet",
    "tegu", "stallion", "frankel", "blazer", "mustang", "rango",
]

# Authoritative stamps (tokay has NO tokay-latest; its stamp is the global
# `latest` alias -> tokay-20260725-102506).
STAMP = {
    "shiba": "shiba-latest",
    "husky": "husky-latest",
    "akita": "akita-latest",
    "tokay": "tokay-20260725-102506",
    "caiman": "caiman-latest",
    "komodo": "komodo-latest",
    "comet": "comet-latest",
    "tegu": "tegu-latest",
    "stallion": "stallion-latest",
    "frankel": "frankel-latest",
    "blazer": "blazer-latest",
    "mustang": "mustang-latest",
    "rango": "rango-latest",
}

BT_NFC_MODULES = [
    "hci_uart", "btsdio", "btbcm", "btqca", "bluetooth", "rfcomm", "hidp", "nfc",
]
GNSS_KERNEL_MODULES = ["gnssif", "gnss_spi"]

# ---------------------------------------------------------------------------
# Embedded ground truth: independently re-derived by the QA engineer from the
# primary artifacts (see Q-EXCISE-LEDGER_EVIDENCE.md for the exact commands).
# tier A = absent, B = dormant (blocked), C = reachable (loaded/unblocked).
#
# Compact per-service maps (default = every device not listed).
# ---------------------------------------------------------------------------
_GT = {
    # gpsd/lhd/scd + init.gps.rc present only on the two shusky Gen-8 devices
    "location_gnss": {"_default": "A", "shiba": "C", "husky": "C"},
    # gnssif/gnss_spi: blocked on shusky; absent on 7; loaded+UNBLOCKED on 4 laguna
    "location_gnss_kernel": {
        "_default": "A", "shiba": "B", "husky": "B",
        "frankel": "C", "blazer": "C", "mustang": "C", "rango": "C",
    },
    # nitrous.ko loaded everywhere; shipped blocklist blocks it except 4 laguna
    "nitrous_module": {
        "_default": "B",
        "frankel": "C", "blazer": "C", "mustang": "C", "rango": "C",
    },
    # 8 BT/NFC GKI modules in modules.load on 13/13, 0 blocklisted
    "bluetooth_gki_modules": {"_default": "C"},
    # nfc.ko is part of the same system_dlkm set
    "nfc_kernel_module": {"_default": "C"},
    # no NFC HAL service anywhere; rango still ships an NFC overlay + ST HAL config
    "nfc_userspace_hal": {"_default": "A", "rango": "B"},
    # eUICC feature XML ships 12/13; tokay is the exception
    "telephony_feature_declarations": {"_default": "B", "tokay": "A"},
    # qorvo/samsung UWB service + init.rc on exactly 7 devices
    "uwb_hal_service": {
        "_default": "A", "husky": "C", "caiman": "C", "komodo": "C",
        "comet": "C", "blazer": "C", "mustang": "C", "rango": "C",
    },
    # 0 rild/radio-HAL entries in installed-files-vendor.txt on 13/13
    "cellular_ril_native": {"_default": "A"},
    # radio.img + modem.img present in out/ on 13/13
    "baseband_firmware": {"_default": "B"},
}

EXPECTED = {}
for _svc, _m in _GT.items():
    for _dev in DEVICES:
        EXPECTED[(_dev, _svc)] = _m.get(_dev, _m["_default"])


class Artifacts:
    """Read-only access to primary artifacts (out/ tree + shipped stamp images)."""

    def __init__(self, fixture: str | None = None) -> None:
        self.fixture = fixture

    # -- out/ tree ---------------------------------------------------------
    def out_path(self, rel: str) -> str:
        base = self.fixture if self.fixture else REPO
        return os.path.join(base, rel)

    def out_exists(self, rel: str) -> bool:
        return os.path.exists(self.out_path(rel))

    def out_glob(self, rel: str) -> list[str]:
        return glob.glob(self.out_path(rel))

    def out_text(self, rel: str) -> str:
        p = self.out_path(rel)
        if not os.path.isfile(p):
            return ""
        with open(p, "r", errors="replace") as fh:
            return fh.read()

    # -- shipped stamp images ---------------------------------------------
    def _stamp_img(self, stamp: str, img: str) -> str:
        if self.fixture:
            # fixture layout: <fixture>/stamps/<stamp>/<img>/...
            return os.path.join(self.fixture, "stamps", stamp, img)
        return os.path.join(REPO, "releases/desktop-flash", stamp, img)

    def stamp_text(self, stamp: str, img: str, inner: str) -> str:
        if self.fixture:
            p = os.path.join(self._stamp_img(stamp, img), inner.lstrip("/"))
            if os.path.isfile(p):
                with open(p, "r", errors="replace") as fh:
                    return fh.read()
            return ""
        image = self._stamp_img(stamp, img)
        if not os.path.isfile(image):
            return ""
        try:
            out = subprocess.run(
                ["debugfs", "-R", f"cat {inner}", image],
                capture_output=True, text=True, timeout=300,
            )
        except Exception:
            return ""
        return out.stdout

    def stamp_exists(self, stamp: str, img: str, inner: str) -> bool:
        if self.fixture:
            return os.path.exists(
                os.path.join(self._stamp_img(stamp, img), inner.lstrip("/")))
        image = self._stamp_img(stamp, img)
        if not os.path.isfile(image):
            return False
        out = subprocess.run(["debugfs", "-R", f"stat {inner}", image],
                             capture_output=True, text=True, timeout=120)
        return "Inode:" in out.stdout


def _module_blocked(blocklist: str, mod: str) -> bool:
    """True if the blocklist has a `blocklist <mod>` line (with or without .ko)."""
    base = mod[:-3] if mod.endswith(".ko") else mod
    for line in blocklist.splitlines():
        line = line.strip()
        if not line.startswith("blocklist"):
            continue
        tok = line.split()[-1]
        tok = tok[:-3] if tok.endswith(".ko") else tok
        if tok == base:
            return True
    return False


def _load_has(load: str, mod: str) -> bool:
    base = mod if mod.endswith(".ko") else mod + ".ko"
    return any(os.path.basename(x.strip()) == base
               for x in load.replace(",", " ").split())


# ---------------------------------------------------------------------------
# Derivation rules (primary artifacts only)
# ---------------------------------------------------------------------------
def tier_bt_gki(art: Artifacts, dev: str) -> str:
    s = STAMP[dev]
    load = art.stamp_text(s, "system_dlkm.img", "/lib/modules/modules.load")
    blk = art.stamp_text(s, "system_dlkm.img", "/lib/modules/modules.blocklist")
    loaded = [m for m in BT_NFC_MODULES if _load_has(load, m)]
    if not loaded:
        return "A"
    if all(_module_blocked(blk, m) for m in loaded):
        return "B"
    return "C"


def tier_nitrous(art: Artifacts, dev: str) -> str:
    s = STAMP[dev]
    load = art.stamp_text(s, "vendor_dlkm.img", "/lib/modules/modules.load")
    blk = art.stamp_text(s, "vendor_dlkm.img", "/lib/modules/modules.blocklist")
    present = _load_has(load, "nitrous") or art.out_exists(
        f"out/target/product/{dev}/vendor_dlkm/lib/modules/nitrous.ko")
    if not present:
        return "A"
    return "B" if _module_blocked(blk, "nitrous") else "C"


def tier_gnss_kernel(art: Artifacts, dev: str) -> str:
    s = STAMP[dev]
    load = art.stamp_text(s, "vendor_dlkm.img", "/lib/modules/modules.load")
    blk = art.stamp_text(s, "vendor_dlkm.img", "/lib/modules/modules.blocklist")
    loaded = [m for m in GNSS_KERNEL_MODULES if _load_has(load, m)]
    ins = [m for m in GNSS_KERNEL_MODULES if art.out_exists(
        f"out/target/product/{dev}/vendor_dlkm/lib/modules/{m}.ko")]
    if not loaded and not ins:
        return "A"
    if loaded and all(_module_blocked(blk, m) for m in loaded):
        return "B"
    return "C"


def tier_gnss_userspace(art: Artifacts, dev: str) -> str:
    base = f"out/target/product/{dev}/vendor"
    for rel in ("bin/hw/gpsd", "bin/hw/lhd", "bin/hw/scd",
                "etc/init/init.gps.rc"):
        if art.out_exists(f"{base}/{rel}"):
            return "C"
    return "A"


def tier_nfc_userspace(art: Artifacts, dev: str) -> str:
    base = f"out/target/product/{dev}/vendor"
    if art.out_glob(f"{base}/bin/hw/*nfc*") or art.out_glob(f"{base}/lib64/*nfc*"):
        return "C"
    residual = (art.out_glob(f"{base}/overlay/*[Nn]fc*.apk")
                + art.out_glob(f"{base}/etc/libnfc*.conf")
                + art.out_glob(f"{base}/etc/*nfc*.conf"))
    if residual:
        return "B"
    return "A"


def tier_telephony_feature(art: Artifacts, dev: str) -> str:
    p = f"out/target/product/{dev}/product/etc/permissions/android.hardware.telephony.euicc.xml"
    return "B" if art.out_exists(p) else "A"


def tier_uwb(art: Artifacts, dev: str) -> str:
    base = f"out/target/product/{dev}/vendor"
    if art.out_glob(f"{base}/bin/hw/*uwb*"):
        return "C"
    return "A"


def tier_cellular_ril(art: Artifacts, dev: str) -> str:
    txt = art.out_text(f"out/target/product/{dev}/installed-files-vendor.txt")
    hits = [ln for ln in txt.splitlines()
            if ("rild" in ln.lower()) or ("android.hardware.radio" in ln.lower())]
    return "A" if not hits else "C"


def tier_baseband(art: Artifacts, dev: str) -> str:
    has = (art.out_exists(f"out/target/product/{dev}/radio.img")
           and art.out_exists(f"out/target/product/{dev}/modem.img"))
    return "B" if has else "A"


DERIVERS = {
    "location_gnss": tier_gnss_userspace,
    "location_gnss_kernel": tier_gnss_kernel,
    "nitrous_module": tier_nitrous,
    "bluetooth_gki_modules": tier_bt_gki,
    "nfc_kernel_module": tier_bt_gki,   # nfc.ko is in the same system_dlkm set
    "nfc_userspace_hal": tier_nfc_userspace,
    "telephony_feature_declarations": tier_telephony_feature,
    "uwb_hal_service": tier_uwb,
    "cellular_ril_native": tier_cellular_ril,
    "baseband_firmware": tier_baseband,
}


def derive(art: Artifacts) -> dict:
    out = {}
    for (dev, svc) in EXPECTED:
        out[(dev, svc)] = DERIVERS[svc](art, dev)
    return out


# ---------------------------------------------------------------------------
# Ledger access
# ---------------------------------------------------------------------------
def ledger_tier(dev: str, svc: str) -> str:
    with open(LEDGER) as fh:
        data = json.load(fh)
    for d in data["devices"]:
        if d["codename"] != dev:
            continue
        tiers = [a["tier"] for a in d["artifacts"] if a["service"] == svc]
        if not tiers:
            return "?"
        order = {"A": 0, "B": 1, "C": 2}
        return max(tiers, key=lambda t: order.get(t, -1))
    return "?"


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
def mode_artifacts(art: Artifacts) -> int:
    derived = derive(art)
    bad = 0
    print(f"{'device':<9} {'service':<32} {'derived':<8} {'expected':<9} result")
    print("-" * 70)
    for key in sorted(derived, key=lambda k: (k[0], k[1])):
        dev, svc = key
        got, want = derived[key], EXPECTED[key]
        ok = got == want
        bad += 0 if ok else 1
        print(f"{dev:<9} {svc:<32} {got:<8} {want:<9} "
              f"{'OK' if ok else 'MISMATCH'}")
    print("-" * 70)
    print(f"cells={len(derived)} mismatches={bad}")
    if bad:
        print("RESULT: FAIL (detector flagged an un-excised/inconsistent artifact)")
        return 1
    print("RESULT: PASS (all re-derived cells match embedded ground truth)")
    return 0


def mode_ledger() -> int:
    bad = 0
    print("=== LEDGER RE-DERIVATION DIFF (Q-EXCISE-LEDGER) ===")
    print(f"{'device':<9} {'service':<32} {'ground_truth':<13} {'ledger':<7} result")
    print("-" * 78)
    for key in sorted(EXPECTED, key=lambda k: (k[0], k[1])):
        dev, svc = key
        gt, lt = EXPECTED[key], ledger_tier(dev, svc)
        ok = gt == lt
        bad += 0 if ok else 1
        print(f"{dev:<9} {svc:<32} {gt:<13} {lt:<7} "
              f"{'agree' if ok else 'DISAGREE'}")
    print("-" * 78)
    print(f"cells={len(EXPECTED)} disagreements={bad}")
    if bad:
        print("RESULT: LEDGER DISAGREES with independently re-derived ground truth")
        return 1
    print("RESULT: ledger consistent with ground truth")
    return 0


def mode_attacks(art: Artifacts) -> int:
    rc = 0
    print("=== ATTACK A5: makefile-evidence cells in the ledger ===")
    with open(LEDGER) as fh:
        data = json.load(fh)
    mk_kind = sum(1 for d in data["devices"] for a in d["artifacts"]
                  if a.get("evidence_kind") in ("makefile", "build-recipe"))
    mk_path = sum(1 for d in data["devices"] for a in d["artifacts"]
                  if a["path"].endswith(".mk"))
    raw = open(LEDGER).read()
    substr = raw.count("makefile") + raw.count(".mk")
    print(f"  evidence_kind==makefile cells : {mk_kind} (expect 0)")
    print(f"  artifact paths ending '.mk'   : {mk_path} (expect 0)")
    print(f"  raw 'makefile'/'.mk' substrings: {substr} (expect 0)")
    if mk_kind or mk_path:
        rc = 1
    print(f"  A5 {'PASS' if rc == 0 else 'FAIL'}")

    print()
    print("=== ATTACK A8: stamp existence / dangling -latest ===")
    rel = os.path.join(REPO, "releases/desktop-flash")
    stamps = set(os.listdir(rel)) if os.path.isdir(rel) else set()
    for dev in DEVICES:
        s = STAMP[dev]
        if s in stamps or os.path.isdir(os.path.join(rel, s)):
            print(f"  {dev:<9} stamp {s:<26} EXISTS")
        else:
            print(f"  {dev:<9} stamp {s:<26} MISSING"); rc = 1
    for link in sorted(glob.glob(os.path.join(rel, "*-latest"))):
        tgt = os.readlink(link)
        ok = os.path.exists(os.path.join(rel, tgt))
        print(f"  symlink {os.path.basename(link):<24} -> {tgt:<30} "
              f"{'OK' if ok else 'DANGLING'}")
        if not ok:
            rc = 1
    has_tokay_latest = os.path.lexists(os.path.join(rel, "tokay-latest"))
    print(f"  tokay-latest present           : {has_tokay_latest} (expect False)")
    if has_tokay_latest:
        rc = 1
    latest = os.readlink(os.path.join(rel, "latest")) if os.path.islink(
        os.path.join(rel, "latest")) else ""
    print(f"  global latest -> {latest} (expect tokay-20260725-102506)")
    if latest != "tokay-20260725-102506":
        rc = 1
    rango = os.readlink(os.path.join(rel, "rango-latest")) if os.path.islink(
        os.path.join(rel, "rango-latest")) else ""
    print(f"  rango-latest -> {rango} (expect rango-20260802-130756)")
    if rango != "rango-20260802-130756":
        rc = 1
    print(f"  A8 {'PASS' if rc == 0 else 'FAIL'}")

    print()
    print("=== ATTACK A1: variant -> blocklist mapping (cross-family) ===")
    import hashlib
    expected_variant = {
        "shiba": "zuma_shusky", "husky": "zuma_shusky", "akita": "zuma_akita",
        "tokay": "zumapro_caimito", "caiman": "zumapro_caimito",
        "komodo": "zumapro_caimito", "comet": "zumapro_comet",
        "tegu": "zumapro_tegu", "stallion": "zumapro_stallion",
        "frankel": "laguna_muzel", "blazer": "laguna_muzel",
        "mustang": "laguna_muzel", "rango": "laguna_rango",
    }
    fam = {"zuma_shusky": "shusky", "zuma_akita": "akita",
           "zumapro_caimito": "caimito", "zumapro_comet": "comet",
           "zumapro_tegu": "tegu", "zumapro_stallion": "stallion",
           "laguna_muzel": "laguna", "laguna_rango": "rango"}
    hashes = {}
    for dev in DEVICES:
        p = os.path.join(REPO,
                         f"out/target/product/{dev}/vendor_dlkm/lib/modules/modules.blocklist")
        if not os.path.isfile(p):
            print(f"  {dev:<9} built blocklist MISSING"); rc = 1; continue
        h = hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]
        hashes[dev] = h
        first = open(p, errors="replace").readline().strip()
        token = expected_variant[dev]
        mislabel = f"'{token}'" not in first and token not in first
        print(f"  {dev:<9} variant={token:<17} header={first[:60]!r}")
        if mislabel:
            print(f"           NOTE: header does not name variant token "
                  f"(ledger allows device/kernel-family header)")
    # flag byte-identical blocklists across DIFFERENT family expectations
    by_hash = {}
    for dev, h in hashes.items():
        by_hash.setdefault(h, []).append(dev)
    for h, devs in by_hash.items():
        fams = {fam[expected_variant[d]] for d in devs}
        if len(devs) > 1 and len(fams) > 1:
            print(f"  CROSS-FAMILY SHARED BLOCKLIST {h}: {devs}"); rc = 1
    print(f"  A1 {'PASS (no cross-family resolution)' if rc == 0 else 'FAIL'}")
    return rc


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mode", choices=["artifacts", "ledger", "attacks"],
                    default="artifacts")
    ap.add_argument("--fixture", default=None,
                    help="artifact root override (negative-control fixture)")
    args = ap.parse_args()

    if args.mode == "ledger":
        return mode_ledger()
    art = Artifacts(args.fixture)
    if args.mode == "attacks":
        return mode_attacks(art)
    return mode_artifacts(art)


if __name__ == "__main__":
    sys.exit(main())
