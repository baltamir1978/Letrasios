#!/usr/bin/env python3
"""Generate the Letras app icons (light/dark/tinted) in the flat-green style shared with
the sibling apps (AppPersonal / BirdApp / RadioApp).

Motif: a white pair of beamed eighth notes over three lines of lyrics; the middle line is
amber — the line being sung, which is what the app is about. Run:

    python3 Tools/generate_icon.py

Outputs the three 1024×1024 opaque PNGs into the AppIcon.appiconset.
"""
import os
from PIL import Image, ImageDraw

SS = 4                      # supersampling factor for smooth edges
N = 1024
S = N * SS
OUT = os.path.join(os.path.dirname(__file__), "..",
                   "Letrasios/Assets.xcassets/AppIcon.appiconset")

# (gradient_top, gradient_bottom, note, line, highlight) per variant
VARIANTS = {
    "AppIcon.png":        ((0x37, 0xD0, 0x94), (0x0B, 0x6F, 0x53),
                           (0xFF, 0xFF, 0xFF), (0xE4, 0xF7, 0xEF), (0xFF, 0xC5, 0x3D)),
    "AppIcon-dark.png":   ((0x0E, 0x3D, 0x2C), (0x06, 0x14, 0x0F),
                           (0xF2, 0xF5, 0xF3), (0x9C, 0xC9, 0xB6), (0xE8, 0xB2, 0x4A)),
    "AppIcon-tinted.png": ((0x0B, 0x0B, 0x0B), (0x1C, 0x1C, 0x1C),
                           (0xFF, 0xFF, 0xFF), (0x9A, 0x9A, 0x9A), (0xE6, 0xE6, 0xE6)),
}


def vgradient(top, bottom):
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (S, y)], fill=c)
    return img


def s(v):
    return int(v * SS)


def rrect(d, x0, y0, x1, y1, rad, fill):
    d.rounded_rectangle([s(x0), s(y0), s(x1), s(y1)], radius=s(rad), fill=fill)


def note_head(img, cx, cy, fill):
    """Tilted oval note head, drawn on its own layer and rotated like engraved notation."""
    w, h = 150, 108
    layer = Image.new("L", (s(w * 1.6), s(w * 1.6)), 0)
    ld = ImageDraw.Draw(layer)
    lw, lh = layer.size
    ld.ellipse([lw / 2 - s(w / 2), lh / 2 - s(h / 2), lw / 2 + s(w / 2), lh / 2 + s(h / 2)], fill=255)
    layer = layer.rotate(24, resample=Image.BICUBIC)
    img.paste(Image.new("RGB", layer.size, fill), (s(cx) - lw // 2, s(cy) - lh // 2), layer)


def beam(d, x0, y0, x1, y1, thickness, fill):
    d.polygon([(s(x0), s(y0)), (s(x1), s(y1)),
               (s(x1), s(y1 + thickness)), (s(x0), s(y0 + thickness))], fill=fill)


def build(top, bottom, note, line, highlight):
    img = vgradient(top, bottom)
    d = ImageDraw.Draw(img)

    # Beamed eighth notes (♫), upper half.
    stem_w = 30
    left_stem_x, right_stem_x = 410, 690
    left_head_y, right_head_y = 520, 470
    rrect(d, left_stem_x - stem_w, 205, left_stem_x, left_head_y, 8, note)
    rrect(d, right_stem_x - stem_w, 155, right_stem_x, right_head_y, 8, note)
    beam(d, left_stem_x - stem_w, 195, right_stem_x, 145, 78, note)
    note_head(img, left_stem_x - 62, left_head_y + 8, note)
    note_head(img, right_stem_x - 62, right_head_y + 8, note)
    d = ImageDraw.Draw(img)

    # Three lines of lyrics; the middle one is the line being sung.
    rrect(d, 232, 652, 792, 704, 26, line)
    rrect(d, 192, 746, 832, 810, 32, highlight)
    rrect(d, 272, 852, 752, 904, 26, line)

    return img.resize((N, N), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, colors in VARIANTS.items():
        out = os.path.join(OUT, name)
        build(*colors).save(out)
        print("wrote", os.path.relpath(out))


if __name__ == "__main__":
    main()
