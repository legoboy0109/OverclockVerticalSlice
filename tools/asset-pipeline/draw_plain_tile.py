#!/usr/bin/env python3
"""Draw the ASSET-006 plain floor tile at any scale.

    python3 tools/asset-pipeline/draw_plain_tile.py out.png [--scale 2]

Replaces a script that was never committed: the original plain tile was drawn
procedurally (SDXL was rejected for flat tile geometry) but only its outputs
survived, so re-authoring at another resolution meant reverse-engineering the
raster. This tool is now the source of truth.

The tile is a single flat `#232A38` diamond -- no border, no gradient, no texture
(§6.2/§4.1). The approved 128x64 art was measured before writing this: alpha is
only ever 0 or 255, and row widths run 4, 8, 12 ... 128, then mirror.

**Edges are hard, never anti-aliased.** This is a `TileMapLayer` floor cell, so
tiles must interlock exactly; semi-transparent edge pixels on adjacent diamonds
blend against each other and leave visible seams or double-darkened joints. That
is why this rasterises row spans directly instead of drawing a polygon.

The raster rule is scale-independent, which is what makes a faithful 2x possible
rather than an approximation: for any 2:1 diamond each row's half-width grows by
W/H = 2px per side, so the full width grows by exactly 4px per row. At 2x that
gives rows of 4, 8 ... 256 and back -- the same diamond, twice the resolution.
"""

from __future__ import annotations

import argparse

from PIL import Image

TILE_W, TILE_H = 128, 64          # 1x footprint (the one true tile size)
FLOOR = (0x23, 0x2A, 0x38)        # §4.1 terrain base


def draw_plain(scale: int = 2, colour: tuple[int, int, int] = FLOOR) -> Image.Image:
    w, h = TILE_W * scale, TILE_H * scale
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        # rows 0..h/2-1 widen by 4 each; the lower half mirrors
        step = y if y < h // 2 else h - 1 - y
        width = 4 * (step + 1)
        x0 = (w - width) // 2
        for x in range(x0, x0 + width):
            px[x, y] = colour + (255,)
    return img


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("out")
    p.add_argument("--scale", type=int, default=2)
    args = p.parse_args()

    img = draw_plain(args.scale)
    img.save(args.out)
    opaque = sum(1 for a in img.getchannel('A').tobytes() if a)
    print(f"{args.out}: {img.width}x{img.height} ({args.scale}x tile), "
          f"{opaque} opaque px ({100 * opaque / (img.width * img.height):.1f}%)")


if __name__ == "__main__":
    main()
