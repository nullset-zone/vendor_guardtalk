#!/usr/bin/env python3
"""Render F-REMEDIATE-B5-BRANDING assets (items 22, 23).

Item 22: komodo boot logo PNG exactly 1008x2244 with a safe zone so the
GuardTalk chevron (the "G") is not cropped. Today's bootanimation frames are
1080x2400; covering that onto the Pixel 9 Pro XL 75% canvas (1008x2244) or
placing the full-bleed 1024 mark without inset crops the chevron tips.

Item 23: Setup Wizard welcome drawable as a branded RGBA PNG (transparent
ground) for com.guardtalk.overlay.setupwizard, replacing the opaque RGB
square placeholder.

Uses existing brand-kit rasters + cairo. No new dependencies. No secrets.
"""

from __future__ import annotations

import os
import sys
import zipfile

import cairo

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
if not os.path.isdir(os.path.join(ROOT, "vendor", "guardtalk", "branding")):
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

BRAND = os.path.join(ROOT, "vendor", "guardtalk", "branding")
SRC_PORTRAIT = os.path.join(
    BRAND,
    "GuardTalkOS_Brand_Assets",
    "07_setup_wizard",
    "guardtalk_welcome_1080x2400.png",
)
SRC_SQUARE = os.path.join(
    BRAND,
    "GuardTalkOS_Brand_Assets",
    "07_setup_wizard",
    "guardtalk_welcome_square_1024.png",
)

BOOT_W, BOOT_H = 1008, 2244
# Pixel 9 Pro XL (komodo) 75% bootanimation canvas. Insets keep the mark
# inside the punch-hole / rounded-corner safe zone (adaptive-icon analogue:
# content well inside the canvas, never flush to an edge).
SAFE_INSET_X = 121  # ~12% of 1008
SAFE_INSET_TOP = 314  # ~14% of 2244 (front camera / status)
SAFE_INSET_BOTTOM = 269  # ~12% of 2244
OBS_R, OBS_G, OBS_B = 0x0A / 255.0, 0x0B / 255.0, 0x0C / 255.0
LIME = (0xC3 / 255.0, 0xFF / 255.0, 0x61 / 255.0)
OBS_RGB = (0x0A, 0x0B, 0x0C)
LIME_RGB = (0xC3, 0xFF, 0x61)


def _argb32_view(surface: cairo.ImageSurface):
    """Return (mv, width, height, stride) for ARGB32 little-endian BGRA bytes."""
    surface.flush()
    return surface.get_data(), surface.get_width(), surface.get_height(), surface.get_stride()


def content_bbox(surface: cairo.ImageSurface, alpha_min: int = 12, rgb_delta: int = 18):
    """Bounding box of non-obsidian / non-transparent pixels. None if empty."""
    buf, w, h, stride = _argb32_view(surface)
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        row = y * stride
        for x in range(w):
            i = row + x * 4
            b, g, r, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
            if a < alpha_min:
                continue
            if (
                abs(r - OBS_RGB[0]) <= rgb_delta
                and abs(g - OBS_RGB[1]) <= rgb_delta
                and abs(b - OBS_RGB[2]) <= rgb_delta
            ):
                continue
            if x < min_x:
                min_x = x
            if y < min_y:
                min_y = y
            if x > max_x:
                max_x = x
            if y > max_y:
                max_y = y
    if max_x < 0:
        return None
    return min_x, min_y, max_x + 1, max_y + 1


def render_boot_logo(src_path: str, dest_path: str) -> dict:
    src = cairo.ImageSurface.create_from_png(src_path)
    sw, sh = src.get_width(), src.get_height()
    inner_w = BOOT_W - 2 * SAFE_INSET_X
    inner_h = BOOT_H - SAFE_INSET_TOP - SAFE_INSET_BOTTOM
    scale = min(inner_w / sw, inner_h / sh)
    dw, dh = sw * scale, sh * scale
    ox = SAFE_INSET_X + (inner_w - dw) / 2.0
    oy = SAFE_INSET_TOP + (inner_h - dh) / 2.0

    out = cairo.ImageSurface(cairo.FORMAT_ARGB32, BOOT_W, BOOT_H)
    cr = cairo.Context(out)
    cr.set_source_rgb(OBS_R, OBS_G, OBS_B)
    cr.paint()
    cr.save()
    cr.translate(ox, oy)
    cr.scale(scale, scale)
    cr.set_source_surface(src, 0, 0)
    cr.paint()
    cr.restore()
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    out.write_to_png(dest_path)

    bbox = content_bbox(out)
    assert bbox is not None, "boot logo has no content"
    l, t, r, b = bbox
    insets = {
        "left": l,
        "top": t,
        "right": BOOT_W - r,
        "bottom": BOOT_H - b,
        "bbox": bbox,
        "size": (BOOT_W, BOOT_H),
        "scale": scale,
    }
    # G (chevron + wordmark) must sit inside the safe zone, not flush to canvas.
    assert l >= SAFE_INSET_X - 2, insets
    assert BOOT_W - r >= SAFE_INSET_X - 2, insets
    assert t >= SAFE_INSET_TOP - 2, insets
    assert BOOT_H - b >= SAFE_INSET_BOTTOM - 2, insets
    return insets


def lime_on_obsidian_to_rgba(
    src: cairo.ImageSurface, min_aa: float = 0.45
) -> cairo.ImageSurface:
    """Recover solid lime mark as premultiplied ARGB (transparent ground).

    Drops the full-bleed 10% glow and 7% grid (those made an opaque-looking
    disc on light SetupWizard surfaces). Compact glow is painted separately.
    """
    src.flush()
    sw, sh = src.get_width(), src.get_height()
    sbuf, _, _, sstride = _argb32_view(src)
    out = cairo.ImageSurface(cairo.FORMAT_ARGB32, sw, sh)
    obuf, _, _, ostride = _argb32_view(out)
    bg_g = OBS_RGB[1]
    lime_r, lime_g, lime_b = LIME_RGB
    denom = float(lime_g - bg_g)
    for y in range(sh):
        srow = y * sstride
        orow = y * ostride
        for x in range(sw):
            si = srow + x * 4
            oi = orow + x * 4
            b, g, r, _a = sbuf[si], sbuf[si + 1], sbuf[si + 2], sbuf[si + 3]
            # Lime-tinted only (drops steel grid: G is not dominant there).
            if g <= r or g <= b:
                continue
            aa = (g - bg_g) / denom
            if aa < min_aa:
                continue
            if aa > 1.0:
                aa = 1.0
            obuf[oi] = int(lime_b * aa)
            obuf[oi + 1] = int(lime_g * aa)
            obuf[oi + 2] = int(lime_r * aa)
            obuf[oi + 3] = int(aa * 255)
    out.mark_dirty()
    return out


def render_welcome_transparent(src_path: str, dest_path: str) -> dict:
    src = cairo.ImageSurface.create_from_png(src_path)
    mark = lime_on_obsidian_to_rgba(src, min_aa=0.45)
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    mark.write_to_png(dest_path)

    w, h = mark.get_width(), mark.get_height()
    bbox = content_bbox(mark, alpha_min=32, rgb_delta=0)
    assert bbox is not None, "welcome PNG has no content"
    l, t, r, b = bbox
    buf, _, _, stride = _argb32_view(mark)
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for x, y in corners:
        a = buf[y * stride + x * 4 + 3]
        assert a == 0, f"corner ({x},{y}) alpha={a} — still a square"
    insets = {
        "left": l,
        "top": t,
        "right": w - r,
        "bottom": h - b,
        "bbox": bbox,
        "size": (w, h),
        "mode": "RGBA",
    }
    return insets


def png_ihdr(path: str) -> tuple[int, int, int]:
    import struct

    with open(path, "rb") as fh:
        sig = fh.read(8)
        assert sig == b"\x89PNG\r\n\x1a\n", path
        _ln, typ = struct.unpack(">I4s", fh.read(8))
        assert typ == b"IHDR", path
        w, h, bit, color = struct.unpack(">IIBB", fh.read(10))
    return w, h, color  # color 2=RGB 6=RGBA


def main() -> int:
    boot_dest = os.path.join(BRAND, "bootanimation", "logo_1008x2244.png")
    boot_kit = os.path.join(
        BRAND, "GuardTalkOS_Brand_Assets", "01_boot_animation", "logo_1008x2244.png"
    )
    welcome_kit = os.path.join(
        BRAND,
        "GuardTalkOS_Brand_Assets",
        "07_setup_wizard",
        "guardtalk_welcome_square_transparent.png",
    )
    overlay_png = os.path.join(
        ROOT,
        "vendor",
        "guardtalk",
        "overlays",
        "GuardTalkSetupWizardOverlay",
        "res",
        "drawable-nodpi",
        "guardtalk_welcome_square.png",
    )

    boot = render_boot_logo(SRC_PORTRAIT, boot_dest)
    # Same bytes for the brand-kit copy (Law 6: one render).
    import shutil

    os.makedirs(os.path.dirname(boot_kit), exist_ok=True)
    shutil.copy2(boot_dest, boot_kit)

    welcome = render_welcome_transparent(SRC_SQUARE, welcome_kit)
    os.makedirs(os.path.dirname(overlay_png), exist_ok=True)
    shutil.copy2(welcome_kit, overlay_png)

    bw, bh, bc = png_ihdr(boot_dest)
    ww, wh, wc = png_ihdr(overlay_png)
    print("boot", boot_dest, bw, bh, "color", bc, "insets", boot)
    print("boot_kit", boot_kit)
    print("welcome", overlay_png, ww, wh, "color", wc, "insets", welcome)
    print("welcome_kit", welcome_kit)
    assert (bw, bh) == (BOOT_W, BOOT_H), (bw, bh)
    assert bc in (2, 6)
    assert wc == 6, "overlay PNG must be RGBA (color type 6)"
    # Do not touch bootanimation.zip (USERBUILD/lunch not delayed).
    zpath = os.path.join(BRAND, "bootanimation", "bootanimation.zip")
    if os.path.isfile(zpath):
        with zipfile.ZipFile(zpath) as zf:
            desc = zf.read("desc.txt").decode()
        print("bootanimation.zip desc.txt unchanged:", repr(desc.strip()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
