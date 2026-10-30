#!/usr/bin/env python3
"""Generate (and drift-check) the GuardTalk device-alignment matrix.

T-DEVICE-ALIGN-MATRIX-JSON (P1). Bounded card: one generator, one JSON artifact.

The population is *measured from the live tree*, not hand-maintained. This
script reads, for every `vendor/guardtalk/device/<dev>/` directory:

  * the device shape (`phone` / `tablet` / `product-namefile-shape`);
  * the `vendor/google_devices/<dev>/BoardConfig.mk` hook;
  * the *second* include surface: the guardtalk `.mk` files included from
    `vendor/google_devices/<dev>/<dev>.mk`;
  * the registry variant and the resolved vendor_dlkm blocklist path, plus
    whether it exists;
  * presence of the eight per-device overlay `.mk` files;
  * the resolved `GUARDTALK_VOICE_FILTER` declaration;
  * advertised membership from the `WIZARD_DEVICES` array ONLY.

Stdlib only (this tree has no pytest and no third-party dependency budget).

Snapshot semantics
------------------
The emitted JSON is a **point-in-time snapshot**, not a contract. Two other
cards were editing the tree while it was produced (`T-DEVICE-ALIGN-VOICE-FLAG-TRUTH`,
`T-DEVICE-ALIGN-TANGORPRO-CASE1`) and a third was in review
(`F-DEVICE-ALIGN-ADVERTISE`), so `--check` will legitimately report drift once
they land. Do **not** edit the tree to make `--check` pass: regenerate, review
the diff, and commit the new snapshot.

Exit codes
----------
  0  generated OK (default) / no drift (`--check`)
  1  drift between the live tree and the committed JSON (`--check`)
  2  usage / I/O / invariant error (fail loudly, never a silent `false`)

Usage
-----
    python3 vendor/guardtalk/scripts/gen-device-alignment-matrix.py
    python3 vendor/guardtalk/scripts/gen-device-alignment-matrix.py --check
"""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import sys
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths (resolved from this file, so the script runs from any cwd inside root)
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[3]
DEVICE_DIR = ROOT / "vendor/guardtalk/device"
GOOGLE_DEVICES = ROOT / "vendor/google_devices"
REGISTRY = ROOT / "vendor/guardtalk/feature-excised/excision-variants.mk"
OFFERED_DEVICES = ROOT / "vendor/guardtalk/web-installer/lib/ui/offered-devices.ts"
OUT_PATH = ROOT / "vendor/guardtalk/docs/device-alignment-matrix.json"

# ---------------------------------------------------------------------------
# Invariants asserted in-code (a zero-row loop must not pass vacuously)
# ---------------------------------------------------------------------------
EXPECTED_DEVICE_COUNT = 15
EXPECTED_ADVERTISED = {"akita", "komodo", "rango", "tokay"}

# Shape overrides. Everything else with a device dir is a phone.
SHAPE_OVERRIDES = {
    "emu64a": "product-namefile-shape",
    "tangorpro": "tablet",
}

# The eight overlay files the matrix records presence for.
OVERLAY_FILES = [
    "BoardConfig-excised-late.mk",
    "guardtalk-flags.mk",
    "guardtalk-insmod.mk",
    "guardtalk-product-props.mk",
    "guardtalk-production-hardening.mk",
    "guardtalk-theme.mk",
    "guardtalk-audio.mk",
    "guardtalk-camera.mk",
]

SCHEMA = "guardtalk.device-alignment-matrix/v1"
TASK_ID = "T-DEVICE-ALIGN-MATRIX-JSON"

# Cards touching the measured surfaces while this snapshot was taken.
IN_FLIGHT_CARDS = [
    {
        "task_id": "T-DEVICE-ALIGN-VOICE-FLAG-TRUTH",
        "status": "DISPATCHED 2026-10-30T13:38+04:00",
        "touches": "vendor/guardtalk/device/**/guardtalk-flags.mk",
        "effect_on_this_snapshot": "changes `voice_flag` on the 9 devices that "
        "declared true without a guardtalk-audio.mk overlay; those edits were "
        "observed landing in `device/**/guardtalk-flags.mk` during capture, so "
        "this snapshot may already show them as empty rather than true",
    },
    {
        "task_id": "T-DEVICE-ALIGN-TANGORPRO-CASE1",
        "status": "READY 2026-10-30T13:35+04:00",
        "touches": "vendor/guardtalk/device/tangorpro/**",
        "effect_on_this_snapshot": "may add `guardtalk-flags.mk`, flipping "
        "`presence['guardtalk-flags.mk']` and `voice_flag` for tangorpro",
    },
    {
        "task_id": "F-DEVICE-ALIGN-ADVERTISE",
        "status": "REVIEW",
        "touches": "vendor/guardtalk/web-installer/lib/ui/offered-devices.ts",
        "effect_on_this_snapshot": "may change the `WIZARD_DEVICES` advertised set",
    },
]

SNAPSHOT_NOTE = (
    "Point-in-time snapshot of the GuardTalk device-alignment matrix, derived "
    "from the live tree. It is NOT a contract: the in-flight cards listed in "
    "`snapshot.in_flight_cards` were editing these surfaces during capture, so "
    "`--check` will legitimately report drift once they land. Regenerate and "
    "review the diff; do not edit the tree to make `--check` pass."
)


class MatrixError(RuntimeError):
    """A required input is missing/unreadable or an in-code invariant failed."""


# ---------------------------------------------------------------------------
# Filesystem helpers: absent is False, unreadable is an ERROR (never silent)
# ---------------------------------------------------------------------------
def rel(path: Path) -> str:
    """Repo-relative POSIX path for messages and JSON."""
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def file_presence(path: Path) -> bool:
    """True if a regular file exists at `path`.

    Absent (no directory entry) -> False. A broken symlink, a non-regular file,
    or a file this process cannot read -> MatrixError, because those must not
    be silently recorded as `false`.
    """
    if not os.path.lexists(path):
        return False
    try:
        st = os.stat(path)
    except OSError as exc:
        raise MatrixError(f"broken symlink or unreadable path: {rel(path)} ({exc})") from exc
    if not stat.S_ISREG(st.st_mode):
        raise MatrixError(f"expected a regular file, found another file type: {rel(path)}")
    if not os.access(path, os.R_OK):
        raise MatrixError(f"file exists but is unreadable (permission denied): {rel(path)}")
    return True


def read_text(path: Path) -> str:
    """Read a required file. Missing or unreadable is an error, not ''."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise MatrixError(f"required file is missing: {rel(path)}") from exc
    except PermissionError as exc:
        raise MatrixError(f"required file is unreadable (permission denied): {rel(path)}") from exc
    except OSError as exc:
        raise MatrixError(f"required file is unreadable ({exc}): {rel(path)}") from exc


# ---------------------------------------------------------------------------
# Registry (single source of truth for variant + blocklist)
# ---------------------------------------------------------------------------
RE_DEVICE_VARIANT = re.compile(r"^GT_DEVICE_VARIANT_(\w+)\s*:=\s*(\S+)\s*$")
RE_VARIANT_BLOCKLIST = re.compile(r"^GT_VARIANT_(\w+)_BLOCKLIST\s*:=\s*(\S+)\s*$")
RE_DEVICE_BLOCKLIST = re.compile(r"^GT_DEVICE_BLOCKLIST_(\w+)\s*:=\s*(\S+)\s*$")


def parse_registry() -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    """Return (device -> variant, variant -> blocklist, device -> pinned blocklist)."""
    text = read_text(REGISTRY)
    device_variant: dict[str, str] = {}
    variant_blocklist: dict[str, str] = {}
    device_pin: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if m := RE_DEVICE_VARIANT.match(stripped):
            device_variant[m.group(1)] = m.group(2)
        elif m := RE_VARIANT_BLOCKLIST.match(stripped):
            variant_blocklist[m.group(1)] = m.group(2)
        elif m := RE_DEVICE_BLOCKLIST.match(stripped):
            device_pin[m.group(1)] = m.group(2)
    if not device_variant or not variant_blocklist:
        raise MatrixError(
            f"registry parse produced nothing ({len(device_variant)} device rows, "
            f"{len(variant_blocklist)} variant blocklist rows) in {rel(REGISTRY)}"
        )
    return device_variant, variant_blocklist, device_pin


def blocklist_convention(path: str | None) -> str | None:
    """Classify a registry blocklist path by its LOCATION convention."""
    if not path:
        return None
    if path.startswith("vendor/guardtalk/feature-excised/variants/"):
        return "variants-dir"
    if path == "vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist":
        return "flat"
    if path.startswith("vendor/guardtalk/device/"):
        return "device-local"
    return "unrecognised"


# ---------------------------------------------------------------------------
# Advertised set: WIZARD_DEVICES array ONLY (never the withheld map)
# ---------------------------------------------------------------------------
RE_WIZARD_ARRAY = re.compile(
    r"export\s+const\s+WIZARD_DEVICES\b[^=]*=\s*\[(?P<body>.*?)\n\];", re.S
)
RE_WIZARD_ID = re.compile(r'id:\s*"([a-z0-9_]+)"')


def parse_advertised() -> tuple[list[str], int]:
    """Return (sorted WIZARD_DEVICES ids, 1-based line number of the array).

    Deliberately scoped to the array literal. Scanning the whole file matches
    `WITHHELD_REASONS` (line ~507) and returns all 14 codenames -- the false
    result `DEC-DEVICE-ALIGN-007`/`-012` warn about.
    """
    text = read_text(OFFERED_DEVICES)
    match = RE_WIZARD_ARRAY.search(text)
    if not match:
        raise MatrixError(
            f"could not locate the WIZARD_DEVICES array literal in {rel(OFFERED_DEVICES)}"
        )
    body = match.group("body")
    if "WITHHELD_REASONS" in body:
        raise MatrixError(
            "WIZARD_DEVICES extraction overran into WITHHELD_REASONS -- refusing "
            "to publish the whole-file (14-device) false result"
        )
    ids = RE_WIZARD_ID.findall(body)
    if not ids:
        raise MatrixError("WIZARD_DEVICES array parsed zero ids -- the parse is broken")
    if len(ids) != len(set(ids)):
        raise MatrixError(f"WIZARD_DEVICES array declares duplicate ids: {ids}")
    line = text[: match.start()].count("\n") + 1
    return sorted(ids), line


# ---------------------------------------------------------------------------
# Per-device derivation
# ---------------------------------------------------------------------------
RE_INCLUDE_LINE = re.compile(
    r"^[ \t]*-?include[ \t]+(vendor/guardtalk/[A-Za-z0-9_./-]+\.mk)[ \t]*$", re.M
)
RE_MENTIONED_MK = re.compile(r"vendor/guardtalk/[A-Za-z0-9_./-]+\.mk")
RE_BOARDCONFIG_INCLUDE = re.compile(
    r"^[ \t]*include[ \t]+(vendor/guardtalk/device/[A-Za-z0-9_]+/BoardConfig-excised-late\.mk)[ \t]*$",
    re.M,
)
RE_VOICE_FLAG = re.compile(r"^[ \t]*GUARDTALK_VOICE_FILTER[ \t]*:=[ \t]*(.*?)[ \t]*$", re.M)


def shape_of(device: str) -> str:
    return SHAPE_OVERRIDES.get(device, "phone")


def boardconfig_hook(device: str, shape: str) -> tuple[bool, str | None]:
    path = GOOGLE_DEVICES / device / "BoardConfig.mk"
    if not file_presence(path):
        if shape == "product-namefile-shape":
            return False, None
        raise MatrixError(
            f"{device}: no {rel(path)} -- a {shape} overlay dir with no BoardConfig "
            "hook is a dead layer, not an absent one"
        )
    text = read_text(path)
    match = RE_BOARDCONFIG_INCLUDE.search(text)
    if not match:
        if shape == "product-namefile-shape":
            return False, None
        raise MatrixError(
            f"{device}: {rel(path)} exists but does not include "
            f"vendor/guardtalk/device/{device}/BoardConfig-excised-late.mk"
        )
    return True, match.group(1)


def dev_mk_surface(device: str) -> tuple[str | None, list[str], list[str]]:
    """Return (<dev>.mk repo path or None, guardtalk .mk includes, missing ones)."""
    path = GOOGLE_DEVICES / device / f"{device}.mk"
    if not file_presence(path):
        if shape_of(device) == "product-namefile-shape":
            return None, [], []
        raise MatrixError(f"{device}: expected {rel(path)} but it is absent")
    text = read_text(path)
    includes = sorted(set(RE_INCLUDE_LINE.findall(text)))
    # Fail loudly on a guardtalk `.mk` path that is mentioned but not a plain
    # include (e.g. a commented-out include): silently dropping it would make
    # the second surface look cleaner than it is.
    mentioned = set(RE_MENTIONED_MK.findall(text))
    unparsed = sorted(mentioned - set(includes))
    if unparsed:
        raise MatrixError(
            f"{device}: {rel(path)} mentions guardtalk .mk path(s) that are not "
            f"parsed include lines: {unparsed}"
        )
    missing = [inc for inc in includes if not file_presence(ROOT / inc)]
    return rel(path), includes, missing


def voice_flag(device: str) -> tuple[str | None, str | None]:
    """Return (resolved value or None, raw declared value or None).

    `raw` is None when there is no flags file / no declaration, and "" for an
    explicit empty assignment (`:=`), which the Make gate treats as disabled.
    """
    path = DEVICE_DIR / device / "guardtalk-flags.mk"
    if not file_presence(path):
        return None, None
    matches = RE_VOICE_FLAG.findall(read_text(path))
    if not matches:
        return None, None
    raw = matches[-1].strip()
    return (raw or None), raw


def derive_device(
    device: str,
    device_variant: dict[str, str],
    variant_blocklist: dict[str, str],
    device_pin: dict[str, str],
    advertised: set[str],
) -> dict:
    shape = shape_of(device)
    hooked, include_line = boardconfig_hook(device, shape)
    dev_mk_path, dev_mk_includes, dev_mk_missing = dev_mk_surface(device)

    variant = device_variant.get(device)
    if variant is None and shape != "product-namefile-shape":
        raise MatrixError(
            f"{device}: no GT_DEVICE_VARIANT_{device} row in {rel(REGISTRY)} -- "
            "refusing to record the absence as a null (the resolver would $(error))"
        )

    canonical = variant_blocklist.get(variant) if variant else None
    if variant is not None and canonical is None:
        raise MatrixError(
            f"{device}: variant '{variant}' has no GT_VARIANT_{variant}_BLOCKLIST row"
        )
    pin = device_pin.get(device)

    resolved = pin or canonical
    resolved_exists = file_presence(ROOT / resolved) if resolved else False
    canonical_exists = file_presence(ROOT / canonical) if canonical else False

    presence = {name: file_presence(DEVICE_DIR / device / name) for name in OVERLAY_FILES}
    voice_resolved, voice_raw = voice_flag(device)

    return {
        "device": device,
        "shape": shape,
        "boardconfig_hooked": hooked,
        "boardconfig_include": include_line,
        "dev_mk_path": dev_mk_path,
        "dev_mk_includes": dev_mk_includes,
        "dev_mk_includes_missing": dev_mk_missing,
        "registry_variant": variant,
        "variant_canonical_blocklist_path": canonical,
        "variant_canonical_blocklist_exists": canonical_exists,
        "variant_canonical_blocklist_convention": blocklist_convention(canonical),
        "device_pin": pin,
        "variant_blocklist_path": resolved,
        "variant_blocklist_exists": resolved_exists,
        "variant_blocklist_convention": blocklist_convention(resolved),
        "presence": presence,
        "advertised": device in advertised,
        "voice_flag": voice_resolved,
        "voice_flag_raw": voice_raw,
    }


# ---------------------------------------------------------------------------
# Document assembly + in-code invariants
# ---------------------------------------------------------------------------
def build_document() -> dict:
    if not DEVICE_DIR.is_dir():
        raise MatrixError(f"device overlay directory is missing: {rel(DEVICE_DIR)}")
    devices = sorted(
        entry.name
        for entry in DEVICE_DIR.iterdir()
        if entry.is_dir() and not entry.name.startswith(".")
    )
    if not devices:
        raise MatrixError(f"no device overlay directories found under {rel(DEVICE_DIR)}")

    advertised_ids, advertised_line = parse_advertised()
    advertised = set(advertised_ids)
    unknown = advertised - set(devices)
    if unknown:
        raise MatrixError(
            f"WIZARD_DEVICES advertises devices with no overlay dir: {sorted(unknown)}"
        )

    device_variant, variant_blocklist, device_pin = parse_registry()

    rows = [
        derive_device(dev, device_variant, variant_blocklist, device_pin, advertised)
        for dev in devices
    ]

    document = {
        "schema": SCHEMA,
        "task_id": TASK_ID,
        "advertised_extraction": {
            "source": rel(OFFERED_DEVICES),
            "scope": "export const WIZARD_DEVICES array literal only "
            "(NOT the whole file; WITHHELD_REASONS lists all 14 codenames)",
            "array_start_line": advertised_line,
            "ids": advertised_ids,
        },
        "advertised_devices": advertised_ids,
        "advertised_count": len(advertised_ids),
        "device_count": len(rows),
        "overlay_files_tracked": OVERLAY_FILES,
        "devices": rows,
        "summary": summarize(rows),
        "snapshot": {
            "kind": "point-in-time",
            "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "note": SNAPSHOT_NOTE,
            "in_flight_cards": IN_FLIGHT_CARDS,
        },
    }

    assert_invariants(document)
    return document


def summarize(rows: list[dict]) -> dict:
    voice_true = [r["device"] for r in rows if r["voice_flag"] == "true"]
    voice_empty = [r["device"] for r in rows if r["voice_flag_raw"] == ""]
    audio = {r["device"] for r in rows if r["presence"]["guardtalk-audio.mk"]}
    return {
        "by_shape": {
            shape: sorted(r["device"] for r in rows if r["shape"] == shape)
            for shape in sorted({r["shape"] for r in rows})
        },
        "boardconfig_hooked_count": sum(1 for r in rows if r["boardconfig_hooked"]),
        "registry_variant_count": sum(1 for r in rows if r["registry_variant"]),
        "device_pin_count": sum(1 for r in rows if r["device_pin"]),
        "blocklist_missing": sorted(
            r["device"]
            for r in rows
            if r["variant_blocklist_path"] and not r["variant_blocklist_exists"]
        ),
        "dev_mk_include_missing": sorted(
            r["device"] for r in rows if r["dev_mk_includes_missing"]
        ),
        "voice_true_count": len(voice_true),
        "voice_true_without_audio_overlay": sorted(set(voice_true) - audio),
        "voice_true_without_audio_overlay_count": len(set(voice_true) - audio),
        "voice_flag_empty_declared": sorted(voice_empty),
        "voice_flag_empty_declared_count": len(voice_empty),
    }


def assert_invariants(document: dict) -> None:
    """Fail loudly on a vacuous or drifted population (DEC-DEVICE-ALIGN-012/-017)."""
    rows = document["devices"]
    if len(rows) != EXPECTED_DEVICE_COUNT:
        raise MatrixError(
            f"expected {EXPECTED_DEVICE_COUNT} device overlay dirs, measured {len(rows)}: "
            f"{[r['device'] for r in rows]}"
        )
    if len({r["device"] for r in rows}) != len(rows):
        raise MatrixError("duplicate device rows -- the population is not a set")
    advertised = {r["device"] for r in rows if r["advertised"]}
    if advertised != EXPECTED_ADVERTISED:
        raise MatrixError(
            f"advertised set drift: expected {sorted(EXPECTED_ADVERTISED)}, "
            f"derived {sorted(advertised)}"
        )
    if document["advertised_count"] != len(EXPECTED_ADVERTISED):
        raise MatrixError(
            f"advertised_count {document['advertised_count']} != "
            f"{len(EXPECTED_ADVERTISED)}"
        )
    if document["device_count"] != EXPECTED_DEVICE_COUNT:
        raise MatrixError("device_count does not match the row count")
    if not any(r["boardconfig_hooked"] for r in rows):
        raise MatrixError("zero BoardConfig hooks detected -- the scan is vacuous")
    if not any(r["dev_mk_includes"] for r in rows):
        raise MatrixError("zero <dev>.mk includes detected -- the scan is vacuous")
    if not any(r["voice_flag"] for r in rows):
        raise MatrixError("zero GUARDTALK_VOICE_FILTER declarations -- the parse is vacuous")
    if not any(r["registry_variant"] for r in rows):
        raise MatrixError("zero registry variants -- the parse is vacuous")
    if sum(1 for r in rows if r["presence"]["BoardConfig-excised-late.mk"]) < 2:
        raise MatrixError("fewer than two late-pass overlays detected -- the scan is vacuous")


# ---------------------------------------------------------------------------
# Drift comparison
# ---------------------------------------------------------------------------
VOLATILE_KEYS = ("generated_at_utc",)


def strip_volatile(document: dict) -> dict:
    clone = json.loads(json.dumps(document))
    snapshot = clone.get("snapshot")
    if isinstance(snapshot, dict):
        for key in VOLATILE_KEYS:
            snapshot.pop(key, None)
    return clone


def walk_diff(prefix: str, committed, derived, out: list[str], depth: int = 0) -> None:
    if isinstance(committed, dict) and isinstance(derived, dict):
        if depth >= 3:
            if committed != derived:
                out.append(f"{prefix}: committed={committed!r} derived={derived!r}")
            return
        for key in sorted(set(committed) | set(derived)):
            child = f"{prefix}.{key}" if prefix else key
            if key not in committed:
                out.append(f"{child}: only in derived -> {derived[key]!r}")
            elif key not in derived:
                out.append(f"{child}: only in committed -> {committed[key]!r}")
            else:
                walk_diff(child, committed[key], derived[key], out, depth + 1)
        return
    if committed != derived:
        out.append(f"{prefix}: committed={committed!r} derived={derived!r}")


def compare(committed: dict, derived: dict) -> list[str]:
    """Human-readable drift lines, keyed per device (never one giant list dump)."""
    diffs: list[str] = []
    left = strip_volatile(committed)
    right = strip_volatile(derived)

    for key in sorted(set(left) | set(right)):
        if key == "devices":
            continue
        if key not in left:
            diffs.append(f"{key}: only in derived -> {right[key]!r}")
        elif key not in right:
            diffs.append(f"{key}: only in committed -> {left[key]!r}")
        else:
            walk_diff(key, left[key], right[key], diffs)

    committed_rows = {row["device"]: row for row in left.get("devices", [])}
    derived_rows = {row["device"]: row for row in right.get("devices", [])}
    for device in sorted(set(committed_rows) | set(derived_rows)):
        if device not in committed_rows:
            diffs.append(f"devices[{device}]: only in derived (new overlay dir)")
        elif device not in derived_rows:
            diffs.append(f"devices[{device}]: only in committed (overlay dir removed)")
        else:
            walk_diff(f"devices[{device}]", committed_rows[device], derived_rows[device], diffs)
    return diffs


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def write_document(document: dict) -> None:
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(document, indent=2, sort_keys=False) + "\n"
    tmp = OUT_PATH.with_suffix(OUT_PATH.suffix + ".tmp")
    tmp.write_text(payload, encoding="utf-8")
    os.replace(tmp, OUT_PATH)


def run_check(document: dict) -> int:
    if not OUT_PATH.exists():
        print(f"CHECK ERROR: committed artifact is missing: {rel(OUT_PATH)}", file=sys.stderr)
        return 2
    try:
        committed = json.loads(read_text(OUT_PATH))
    except json.JSONDecodeError as exc:
        print(f"CHECK ERROR: committed artifact is not valid JSON: {rel(OUT_PATH)}: {exc}",
              file=sys.stderr)
        return 2
    diffs = compare(committed, document)
    if diffs:
        print(
            f"CHECK FAIL: {len(diffs)} drift(s) between the live tree and {rel(OUT_PATH)}:",
            file=sys.stderr,
        )
        for line in diffs:
            print(f"  - {line}", file=sys.stderr)
        print(
            "CHECK FAIL: regenerate with `python3 "
            "vendor/guardtalk/scripts/gen-device-alignment-matrix.py` and review the diff.",
            file=sys.stderr,
        )
        return 1
    print(
        f"CHECK PASS: live tree matches {rel(OUT_PATH)} "
        f"({document['device_count']} devices, {document['advertised_count']} advertised)."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate or drift-check the GuardTalk device-alignment matrix."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="re-derive from the live tree and compare against the committed JSON; "
        "exit non-zero on drift (nothing is written)",
    )
    args = parser.parse_args(argv)

    try:
        document = build_document()
    except MatrixError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if args.check:
        return run_check(document)

    write_document(document)
    print(
        f"WROTE {rel(OUT_PATH)}: {document['device_count']} devices, "
        f"{document['advertised_count']} advertised "
        f"({', '.join(document['advertised_devices'])})."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
