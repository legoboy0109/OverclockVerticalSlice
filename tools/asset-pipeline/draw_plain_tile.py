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

from PIL import Image, ImageDraw

TILE_W, TILE_H = 128, 64          # 1x footprint (the one true tile size)
FLOOR = (0x23, 0x2A, 0x38)        # §4.1 terrain base

# Wear values are DARKER than the floor, never lighter. §6.4 makes non-gameplay
# terrain detail value-recessive -- "at or below Terrain-base lightness, never at
# the +L Cover/Elevation step" -- because +L is reserved to mean cover/elevation.
# A lighter scorch would read as a cover mass, which is a Pillar-3 failure.
# Tuned against the two anchors either side, not by eye: floor #232A38 is luma 41
# and void #0A0E17 is luma 13. A patch that drops below their midpoint (~27) stops
# reading as "marked floor" and starts reading as a HOLE -- i.e. an Impassable
# void tile, exactly the confusion §6.4 exists to prevent ("anything that isn't a
# gameplay-flagged tile must be visually incapable of being mistaken for one").
# First pass used luma 26 for scorch and read as a pit on the board.
CRACKED = (0x1F, 0x26, 0x32)      # luma ~37, one soft step under the floor
SCORCHED = (0x1B, 0x21, 0x2C)     # luma ~32, clearly floor, clearly not void

# Patches are hand-specified, not random: §6.2 bans texture noise and calls
# damage "a flat value patch or hard-edged silhouette notch", and the tile-variant
# kit is meant to read as hand-curated. Fixed geometry also makes regeneration
# reproducible. Coordinates are fractions of the tile bounding box, and edges run
# along the 2:1 iso diagonals so wear reads as tile-aligned plating, not spatter.
# Placement is deliberately off-centre -- §6.5 tells "fought over" through
# asymmetry of wear rather than colour.
PATCHES = {
    "cracked": [
        (CRACKED, [(0.30, 0.36), (0.52, 0.25), (0.60, 0.29), (0.38, 0.40)]),
        (CRACKED, [(0.40, 0.55), (0.62, 0.44), (0.66, 0.46), (0.44, 0.57)]),
        (CRACKED, [(0.63, 0.63), (0.78, 0.55), (0.82, 0.57), (0.67, 0.65)]),
    ],
    "scorched": [
        (SCORCHED, [(0.38, 0.46), (0.53, 0.38), (0.67, 0.46), (0.63, 0.60),
                    (0.49, 0.67), (0.38, 0.58)]),
        (SCORCHED, [(0.72, 0.34), (0.80, 0.30), (0.86, 0.33), (0.78, 0.38)]),
    ],
}


def draw_plain(scale: int = 2, variant: str = "clean",
               colour: tuple[int, int, int] = FLOOR) -> Image.Image:
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

    if variant != "clean":
        if variant not in PATCHES:
            raise ValueError(f"unknown variant {variant!r}; "
                             f"expected clean or {sorted(PATCHES)}")
        # Draw on an overlay and mask by the tile's own alpha, so the diamond
        # edge stays exactly the raster above -- wear must not alter the
        # footprint (§6.3: no silhouette break within the tile bounds; the
        # variants stay drop-in swappable).
        overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(overlay)
        for patch_colour, poly in PATCHES[variant]:
            d.polygon([(fx * w, fy * h) for fx, fy in poly],
                      fill=patch_colour + (255,))
        overlay.putalpha(Image.composite(
            overlay.getchannel("A"), Image.new("L", (w, h), 0),
            img.getchannel("A")))
        img.alpha_composite(overlay)

    return img


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("out")
    p.add_argument("--scale", type=int, default=2)
    p.add_argument("--variant", default="clean",
                   choices=["clean", *sorted(PATCHES)])
    args = p.parse_args()

    img = draw_plain(args.scale, args.variant)
    img.save(args.out)
    opaque = sum(1 for a in img.getchannel('A').tobytes() if a)
    print(f"{args.out}: {img.width}x{img.height} ({args.scale}x tile), "
          f"{args.variant}, {opaque} opaque px ({100 * opaque / (img.width * img.height):.1f}%)")


if __name__ == "__main__":
    main()
