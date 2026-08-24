#!/usr/bin/env python3
"""Composite a generated asset onto the iso board at true sprite scale.

The review view that matters. A 1024x1024 hero render flatters everything — judge
a candidate there and you approve greeble that turns to mush and trim that vanishes
once the sprite is ~256px on a 128x64 tile. This cuts the candidate out, trims it,
scales it to a target width and drops it on a flat iso lattice in the stage colour,
which is what the player actually sees (art-bible §5.2 legibility, §8.3 author-large-
then-downscale).

    python3 tools/asset-pipeline/board_preview.py <src.png> <dst.png> [--width 256]

Requires numpy + Pillow (scipy optional, for --largest-only). Preview only — it
never writes into assets/.

Sizing: one tile is 128x64 (ASSET-006). A structure spanning 2 tiles is ~256px wide;
an infantry sprite is far smaller, so pass --width for the asset being judged rather
than trusting the default.
"""
from __future__ import annotations

import argparse
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cutout import cutout, trim  # noqa: E402

TILE_W, TILE_H = 128, 64
STAGE = (35, 42, 56)      # #232A38, the plain terrain tile
GRID_LINE = (52, 62, 82)  # a value-step up, matching the tile's edge treatment


def iso_lattice(width: int, height: int, cols: int, rows: int,
                origin_y: int) -> Image.Image:
    bg = Image.new("RGBA", (width, height), STAGE + (255,))
    d = ImageDraw.Draw(bg)
    ox = width // 2
    for r in range(rows):
        for c in range(cols):
            cx = ox + (c - r) * TILE_W // 2
            cy = origin_y + (c + r) * TILE_H // 2
            d.polygon([(cx, cy - TILE_H // 2), (cx + TILE_W // 2, cy),
                       (cx, cy + TILE_H // 2), (cx - TILE_W // 2, cy)],
                      outline=GRID_LINE + (255,))
    return bg


def preview(src: str, dst: str, target_w: int = 256, cols: int = 6, rows: int = 6,
            canvas=(900, 620), largest_only: bool = True) -> None:
    # units enclose background between their legs; always key those pockets
    img, _ = cutout(src, largest_only=largest_only, pockets=True)
    img = trim(img)
    scale = target_w / img.width
    img = img.resize((target_w, max(1, round(img.height * scale))), Image.LANCZOS)

    w, h = canvas
    bg = iso_lattice(w, h, cols, rows, origin_y=80)
    # ground-contact pivot (§8.4): the sprite's base sits on a tile centre
    bg.alpha_composite(img, (w // 2 - img.width // 2, 300 - img.height))
    bg.convert("RGB").save(dst)
    print(f"{dst}: sprite {img.width}x{img.height} on {TILE_W}x{TILE_H} tiles")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--width", type=int, default=256,
                   help="sprite width in px at board scale (default 256 = 2 tiles)")
    p.add_argument("--keep-fragments", action="store_true",
                   help="do not drop detached blobs (shows shadows/props as-is)")
    args = p.parse_args()
    preview(args.src, args.dst, args.width, largest_only=not args.keep_fragments)


if __name__ == "__main__":
    main()
