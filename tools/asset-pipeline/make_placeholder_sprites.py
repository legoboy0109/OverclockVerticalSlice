#!/usr/bin/env python3
"""make_placeholder_sprites.py — clearly-placeholder art for units/structures that have none.

⚠ PLACEHOLDER ART. Flat geometric silhouettes, one distinct shape per type, in each side's
colour, so a new unit is playable and readable before real art exists. Replace by running
the normal asset pipeline (/asset-generate) — this script never overwrites a file unless
--force is given, so real art is safe.

Meets the rules the art tests enforce (tests/unit/art/accent_coverage_test.gd):
  • owned-faction sprites carry ~40-50% saturated accent (floor 30%, ceiling 75%),
  • neutral carries none (achromatic), and rush/boom agree per type,
  • every type has e/w idle + destroyed per faction, and a greyscale glow mask.

Aircraft are drawn HIGH on the canvas with a ground shadow at the bottom: the renderer
anchors every sprite at bottom-centre (ADR-0013), so the shadow is the ground-contact point
and the gap above it is the height cue (unit-classes.md UCOQ-1), with no renderer change.

Usage: python3 tools/asset-pipeline/make_placeholder_sprites.py [--force] [ids...]
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
UNITS = ROOT / "assets/art/units"
STRUCTS = ROOT / "assets/art/structures"

BODY = (58, 63, 72, 255)          # desaturated slate — never counts as accent
BODY_DARK = (38, 41, 47, 255)
SHADOW = (0, 0, 0, 90)            # alpha > 40, so it counts as body, not transparent
ACCENT = {"rush": (255, 90, 46, 255), "boom": (34, 199, 240, 255), "neutral": (150, 150, 150, 255)}

U_W, U_H = 128, 136
S_W, S_H = 256, 229


def poly(d: ImageDraw.ImageDraw, pts, fill):
    d.polygon([(round(x), round(y)) for x, y in pts], fill=fill)


# --- Unit shapes: each draws BODY parts and ACCENT parts, facing east ----------------------

def tank(d, a):
    poly(d, [(14, 104), (100, 104), (116, 88), (30, 88)], BODY_DARK)           # tracks
    poly(d, [(18, 92), (104, 92), (116, 72), (30, 72)], a)                     # hull top
    d.ellipse((44, 50, 88, 80), fill=a)                                        # turret
    d.line((80, 62, 124, 52), fill=BODY, width=8)                              # barrel
    d.ellipse((58, 58, 74, 70), fill=BODY)


def artillery(d, a):
    poly(d, [(14, 108), (96, 108), (110, 94), (28, 94)], BODY_DARK)
    poly(d, [(20, 96), (98, 96), (110, 78), (32, 78)], a)
    poly(d, [(50, 82), (66, 78), (124, 24), (114, 16)], BODY)                  # long gun, high angle
    d.ellipse((40, 66, 70, 90), fill=a)


def _air_shadow(d, cx=64, w=70):
    d.ellipse((cx - w // 2, 118, cx + w // 2, 132), fill=SHADOW)


def fighter(d, a):
    _air_shadow(d, w=64)
    poly(d, [(10, 50), (122, 38), (40, 22)], a)                                # upper wing
    poly(d, [(10, 50), (122, 38), (40, 72)], a)                                # lower wing
    poly(d, [(8, 46), (124, 38), (8, 54)], BODY)                               # fuselage
    poly(d, [(8, 46), (22, 30), (26, 46)], BODY_DARK)                          # tail fin


def bomber(d, a):
    _air_shadow(d, w=84)
    poly(d, [(4, 44), (120, 36), (4, 70)], a)                                  # broad flying wing
    poly(d, [(16, 26), (72, 38), (16, 88)], a)
    poly(d, [(4, 48), (122, 38), (4, 60)], BODY)
    for x in (30, 50):
        d.rectangle((x, 60, x + 10, 68), fill=BODY_DARK)                      # bomb bays


def helicopter(d, a):
    _air_shadow(d, w=56)
    d.ellipse((48, 34, 104, 70), fill=a)                                       # cabin
    poly(d, [(8, 48), (56, 44), (56, 56), (8, 54)], BODY)                      # tail boom
    poly(d, [(4, 40), (14, 40), (14, 56), (4, 56)], BODY_DARK)                 # tail rotor
    d.line((20, 28, 124, 22), fill=BODY_DARK, width=4)                         # main rotor
    d.rectangle((72, 22, 78, 36), fill=BODY)
    d.ellipse((86, 42, 100, 56), fill=BODY)                                    # canopy


def transport(d, a):
    poly(d, [(10, 106), (104, 106), (118, 90), (24, 90)], BODY_DARK)
    poly(d, [(14, 94), (106, 94), (118, 60), (26, 60)], a)                     # tall box body
    poly(d, [(84, 60), (118, 60), (118, 78), (96, 84)], BODY)                  # cab window
    for x in (36, 56):
        d.rectangle((x, 70, x + 12, 80), fill=BODY)                           # side hatches


UNIT_SHAPES = {"transport": transport, "tank": tank, "artillery": artillery, "fighter": fighter, "bomber": bomber,
               "helicopter": helicopter}


def airfield(d, a):
    # Isometric pad (bottom 2/3 of the canvas), runway stripe, control tower.
    cx, top, bottom = S_W / 2, 80, 226
    mid = (top + bottom) / 2
    poly(d, [(cx, top), (S_W - 4, mid), (cx, bottom), (4, mid)], BODY)
    poly(d, [(cx - 70, top + 36), (cx + 40, mid - 20), (cx + 70, mid + 6), (cx - 40, top + 62)], a)   # runway
    poly(d, [(cx + 60, mid + 20), (cx + 100, mid + 2), (cx + 110, mid + 40), (cx + 70, mid + 58)], a)  # apron
    d.rectangle((cx - 104, 36, cx - 70, mid + 10), fill=BODY_DARK)                                   # tower
    d.rectangle((cx - 112, 22, cx - 62, 46), fill=a)                                                 # tower cab


STRUCT_SHAPES = {"airfield": airfield}


# --- Rendering ----------------------------------------------------------------------------

def render(shape, size, faction: str) -> Image.Image:
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    shape(ImageDraw.Draw(im), ACCENT[faction])
    return im


def destroyed(im: Image.Image) -> Image.Image:
    grey = im.convert("LA").convert("RGBA")
    out = Image.new("RGBA", im.size)
    for x in range(im.width):
        for y in range(im.height):
            r, g, b, al = grey.getpixel((x, y))
            out.putpixel((x, y), (int(r * 0.4), int(g * 0.4), int(b * 0.42), al))
    return out


def glow_mask(shape, size) -> Image.Image:
    # Where the pulse shader lights: the accent area, eroded so the edge stays unlit.
    probe = render(shape, size, "rush")
    mask = Image.new("L", size, 0)
    for x in range(size[0]):
        for y in range(size[1]):
            r, g, b, al = probe.getpixel((x, y))
            if al > 40 and (r, g, b) == ACCENT["rush"][:3]:
                mask.putpixel((x, y), 200)
    return mask.filter(ImageFilter.MinFilter(3))


def save(im: Image.Image, path: Path, force: bool) -> bool:
    if path.exists() and not force:
        return False
    im.save(path)
    return True


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="overwrite existing files (real art!)")
    ap.add_argument("ids", nargs="*")
    args = ap.parse_args()
    wanted = set(args.ids) or set(UNIT_SHAPES) | set(STRUCT_SHAPES)
    written = 0
    for uid, shape in UNIT_SHAPES.items():
        if uid not in wanted:
            continue
        for faction in ACCENT:
            east = render(shape, (U_W, U_H), faction)
            west = east.transpose(Image.FLIP_LEFT_RIGHT)
            for facing, im in (("e", east), ("w", west)):
                written += save(im, UNITS / f"unit_{uid}_{faction}_{facing}_idle_01.png", args.force)
                written += save(destroyed(im), UNITS / f"unit_{uid}_{faction}_{facing}_destroyed_01.png", args.force)
        g = glow_mask(shape, (U_W, U_H))
        written += save(g, UNITS / f"unit_{uid}_e_idle_01_glow.png", args.force)
        written += save(g.transpose(Image.FLIP_LEFT_RIGHT), UNITS / f"unit_{uid}_w_idle_01_glow.png", args.force)
    for sid, shape in STRUCT_SHAPES.items():
        if sid not in wanted:
            continue
        for faction in ACCENT:
            im = render(shape, (S_W, S_H), faction)
            written += save(im, STRUCTS / f"struct_{sid}_{faction}_idle.png", args.force)
            written += save(destroyed(im), STRUCTS / f"struct_{sid}_{faction}_destroyed.png", args.force)
        written += save(glow_mask(shape, (S_W, S_H)), STRUCTS / f"struct_{sid}_idle_glow.png", args.force)
    print(f"Wrote {written} placeholder files.")


if __name__ == "__main__":
    main()
