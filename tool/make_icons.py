"""Regenerates every launcher icon from one script, so the art stays in sync
with the app's palette instead of drifting in a binary nobody can diff.

    python tool/make_icons.py

Writes assets/icon/icon.png (the master, for stores and the README) and every
Android mipmap: legacy square icons plus the adaptive foreground/background
pair used from API 26 on.
"""

from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw, ImageFont

# lib/design/tokens.dart holds cards at the real 2.5 by 3.5 ratio.
kCARD_ASPECT = 0.70

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
ASSETS = os.path.join(ROOT, "assets", "icon")
DISPLAY_FONT = os.path.join(ROOT, "assets", "fonts", "BigShouldersDisplay.ttf")

# Straight from lib/design/tokens.dart.
FELT_HI = (0x2B, 0x33, 0x57)
FELT_MID = (0x1B, 0x21, 0x40)
FELT_LO = (0x0A, 0x0D, 0x18)
BONE = (0xED, 0xE6, 0xD4)
BONE_MID = (0xBC, 0xB6, 0xA6)
AMBER = (0xF0, 0xB4, 0x29)
INK = (0x14, 0x16, 0x1F)

# Every raster is drawn at this multiple of its final size, then box-filtered
# down. Cheaper than writing an antialiaser, and the edges come out clean.
SS = 4


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def felt(size: int) -> Image.Image:
    """The table under an overhead light: warm in the middle, dark at the rail."""
    small = 256
    grad = Image.new("RGB", (small, small))
    px = grad.load()
    cx, cy = small * 0.5, small * 0.42
    far = math.hypot(small * 0.5, small * 0.58)
    for y in range(small):
        for x in range(small):
            t = min(1.0, math.hypot(x - cx, y - cy) / far)
            px[x, y] = lerp(FELT_HI, FELT_MID, t) if t < 0.55 else lerp(FELT_MID, FELT_LO, (t - 0.55) / 0.45)
    return grad.resize((size, size), Image.LANCZOS).convert("RGBA")


def rounded_mask(size: int, radius: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def spade(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float, colour) -> None:
    """A spade pip built from two lobes, a cap and a flared stem."""
    h = w * 1.16
    top = cy - h * 0.52
    lobe_r = w * 0.29
    lobe_y = cy + h * 0.02
    draw.polygon(
        [(cx, top), (cx - w * 0.52, lobe_y + lobe_r * 0.25), (cx + w * 0.52, lobe_y + lobe_r * 0.25)],
        fill=colour,
    )
    for sign in (-1, 1):
        lx = cx + sign * w * 0.23
        draw.ellipse([lx - lobe_r, lobe_y - lobe_r, lx + lobe_r, lobe_y + lobe_r], fill=colour)
    # The stem is a flared trapezoid capped by a flat lozenge; a round cap here
    # reads as a lump rather than a foot.
    stem_top = cy + h * 0.08
    stem_bot = cy + h * 0.47
    foot_w = w * 0.30
    draw.polygon(
        [
            (cx - w * 0.055, stem_top),
            (cx + w * 0.055, stem_top),
            (cx + foot_w, stem_bot),
            (cx - foot_w, stem_bot),
        ],
        fill=colour,
    )
    draw.rounded_rectangle(
        [cx - foot_w, stem_bot - w * 0.055, cx + foot_w, stem_bot + w * 0.055],
        radius=w * 0.055,
        fill=colour,
    )


def chip(size: int, d: float) -> Image.Image:
    """A single amber chip. The edge spots are cut as wedges rather than dots so
    they still read as a chip rim once the icon is 48px wide."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = size / 2
    r = d / 2
    dr.ellipse([c - r, c - r, c + r, c + r], fill=AMBER)
    for i in range(6):
        a = i * 60
        dr.pieslice([c - r, c - r, c + r, c + r], a - 9, a + 9, fill=BONE)
    inset = r * 0.78
    dr.ellipse([c - inset, c - inset, c + inset, c + inset], fill=AMBER)
    ring = r * 0.60
    dr.ellipse([c - ring, c - ring, c + ring, c + ring], fill=(0xC0, 0x8B, 0x1A, 255))
    core = r * 0.46
    dr.ellipse([c - core, c - core, c + core, c + core], fill=AMBER)
    return img


def card(size: int, w: float, h: float) -> Image.Image:
    """The ace itself: bone stock, a centred pip and a corner index."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    x0, y0 = (size - w) / 2, (size - h) / 2
    radius = w * 0.09

    dr.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=radius, fill=BONE)
    dr.rounded_rectangle(
        [x0 + w * 0.045, y0 + h * 0.033, x0 + w - w * 0.045, y0 + h - h * 0.033],
        radius=radius * 0.72,
        outline=BONE_MID,
        width=max(1, int(w * 0.012)),
    )

    spade(dr, size / 2, size / 2 + h * 0.055, w * 0.50, INK)

    index = int(w * 0.26)
    font = None
    if index > 0:
        try:
            font = ImageFont.truetype(DISPLAY_FONT, index)
            # BigShoulders ships as a variable font; without this PIL renders the
            # thinnest master, which vanishes at launcher sizes.
            font.set_variation_by_axes([700])
        except (OSError, AttributeError):
            pass
    if font is not None:
        dr.text((x0 + w * 0.145, y0 + h * 0.075), "A", font=font, fill=INK, anchor="lt")
    return img


def compose(size: int, *, bleed: float, background: bool, rounded: bool) -> Image.Image:
    """`bleed` is how much of the canvas the art is allowed to fill. Adaptive
    foregrounds keep to the 66/108 safe zone; legacy icons spread out."""
    s = size * SS
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    if background:
        bg = felt(s)
        out.paste(bg, (0, 0), rounded_mask(s, s * 0.22) if rounded else None)

    if bleed <= 0:
        return out.resize((size, size), Image.LANCZOS)

    art = s * bleed
    card_w = art * 0.58
    card_h = card_w / kCARD_ASPECT

    # Chip up and left, card down and right, then the pair is nudged back to the
    # optical centre so the group sits square in the mask.
    disc = chip(s, art * 0.50)
    out.alpha_composite(disc, (int(-art * 0.175), int(-art * 0.205)))
    face = card(s, card_w, card_h).rotate(-11, resample=Image.BICUBIC)
    out.alpha_composite(face, (int(art * 0.065), int(art * 0.055)))
    return out.resize((size, size), Image.LANCZOS)


# Legacy launcher icon: 48dp baseline. Adaptive layers: 108dp baseline.
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def main() -> None:
    save(compose(1024, bleed=0.86, background=True, rounded=True), os.path.join(ASSETS, "icon.png"))

    for bucket, px in LEGACY.items():
        d = os.path.join(RES, f"mipmap-{bucket}")
        save(compose(px, bleed=0.86, background=True, rounded=True), os.path.join(d, "ic_launcher.png"))

    for bucket, px in ADAPTIVE.items():
        d = os.path.join(RES, f"mipmap-{bucket}")
        # 66/108 of the adaptive canvas survives every mask shape.
        save(compose(px, bleed=0.55, background=False, rounded=False),
             os.path.join(d, "ic_launcher_foreground.png"))
        save(compose(px, bleed=0.0, background=True, rounded=False),
             os.path.join(d, "ic_launcher_background.png"))


if __name__ == "__main__":
    main()
