#!/usr/bin/env python3
"""Pack F-REMEDIATE-B5-BOOTZIP: bootanimation.zip at 1008x2244.

Rebuilds AOSP-format zips from the existing komodo safe-zone PNG
(logo_1008x2244.png). Does not crop or re-encode the G. Does not run `m`.
Frames are STORED (ZIP_STORED) per AOSP bootanimation FORMAT.md.

Usage:
  python3 vendor/guardtalk/branding/scripts/pack_f_remediate_b5_bootzip.py
"""

from __future__ import annotations

import os
import struct
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
if not os.path.isdir(os.path.join(ROOT, "vendor", "guardtalk", "branding")):
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

BRAND = os.path.join(ROOT, "vendor", "guardtalk", "branding")
BOOT_DIR = os.path.join(BRAND, "bootanimation")
KIT_DIR = os.path.join(BRAND, "GuardTalkOS_Brand_Assets", "01_boot_animation")
LOGO = os.path.join(BOOT_DIR, "logo_1008x2244.png")
DESC_TEXT = "1008 2244 24\np 1 0 part0\np 0 0 part1\n"
WIDTH, HEIGHT = 1008, 2244


def png_ihdr(data: bytes) -> tuple[int, int, int]:
    """Return (width, height, color_type) from PNG bytes."""
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    length = struct.unpack(">I", data[8:12])[0]
    if data[12:16] != b"IHDR" or length < 13:
        raise ValueError("missing IHDR")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


def pack_zip(dest: str, logo: bytes) -> None:
    """Write STORED bootanimation.zip with desc + one frame per part."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_STORED) as zf:
        zf.writestr("desc.txt", DESC_TEXT)
        zf.writestr("part0/000.png", logo)
        zf.writestr("part1/000.png", logo)


def verify_zip(path: str, logo: bytes) -> None:
    """Assert desc first line and every PNG is 1008x2244 STORED."""
    with zipfile.ZipFile(path, "r") as zf:
        desc = zf.read("desc.txt").decode("ascii")
        first = desc.splitlines()[0]
        if not first.startswith("1008 2244"):
            raise AssertionError(f"desc first line {first!r}")
        infos = {i.filename: i for i in zf.infolist()}
        for name in ("part0/000.png", "part1/000.png"):
            info = infos[name]
            if info.compress_type != zipfile.ZIP_STORED:
                raise AssertionError(f"{name} not STORED")
            frame = zf.read(name)
            if frame != logo:
                raise AssertionError(f"{name} bytes differ from logo PNG")
            w, h, _ct = png_ihdr(frame)
            if (w, h) != (WIDTH, HEIGHT):
                raise AssertionError(f"{name} IHDR {w}x{h}")


def main() -> int:
    with open(LOGO, "rb") as fh:
        logo = fh.read()
    w, h, _ct = png_ihdr(logo)
    if (w, h) != (WIDTH, HEIGHT):
        raise SystemExit(f"logo IHDR {w}x{h}, expected {WIDTH}x{HEIGHT}")

    product_zip = os.path.join(BOOT_DIR, "bootanimation.zip")
    kit_zip = os.path.join(KIT_DIR, "bootanimation.zip")
    kit_desc = os.path.join(KIT_DIR, "desc.txt")

    pack_zip(product_zip, logo)
    pack_zip(kit_zip, logo)
    with open(kit_desc, "w", encoding="ascii", newline="\n") as fh:
        fh.write(DESC_TEXT)

    verify_zip(product_zip, logo)
    verify_zip(kit_zip, logo)

    # Confirm source PNG bytes were not rewritten.
    with open(LOGO, "rb") as fh:
        if fh.read() != logo:
            raise SystemExit("logo_1008x2244.png mutated")

    print("packed", product_zip)
    print("packed", kit_zip)
    print("desc", repr(DESC_TEXT.strip()))
    print("frames 1008x2244 STORED identical to logo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
