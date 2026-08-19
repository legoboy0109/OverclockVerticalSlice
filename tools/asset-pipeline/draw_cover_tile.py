#!/usr/bin/env python3
"""Draw the ASSET-007 cover-mass prop procedurally (not generated).

    python3 tools/asset-pipeline/draw_cover_tile.py out.png [--faceted|--flat]

Why drawn and not prompted: ASSET-006 (plain tile) already rejected SDXL for flat
tile geometry, and cover is the same problem plus a hard constraint the generator
cannot honour -- the mass must sit on *exactly* the plain tile's 2:1 footprint so
the two are drop-in composable. A drawn tile hits that by construction.

What this outputs is the **prop only**, not a whole tile. Art bible §8.8 ships
cover as two composited layers: a flush floor cell (which is just
`tile_plain_clean.png`, reused) plus a Y-sorted cover mass with its own
ground-contact pivot, so it correctly occludes and is occluded by units on
adjacent rows. The canvas therefore extends *above* the tile plane, and the
bottom-centre of the canvas is the ground-contact pivot -- the same rule the unit
sprites follow.

Geometry: a low barrier slab inset inside the tile diamond, knee-to-waist against
a ~65px unit. §6.3's rule is that elevation lifts the whole floor plane while
cover *breaks* the floor with an object silhouette, so the slab is deliberately
inset -- a mass that filled the cell edge-to-edge would read as a raised tile.

Value: §6.3 puts cover one lightness step above the floor at `#33405A`, with zero
hue and zero pattern. `--faceted` (default) keeps that value on the lit top face
and steps the two visible side faces down in **lightness only**, which is how
§4.1 says the whole stage family differentiates. `--flat` paints every face the
one value, which is the most literal reading of the spec but reads as a sticker
rather than an object.

Anti-aliasing: drawn at 4x and downsampled, which keeps the edges hard (§3.3
angular, few-sided) without leaving them jagged.
"""

from __future__ import annotations

import argparse
import colorsys

from PIL import Image, ImageDraw

TILE_W, TILE_H = 128, 64          # the one true tile footprint (ASSET-006)
AUTHOR_SCALE = 3                  # matches the plain tile's 384x192 author file
SS = 4                            # supersampling factor

COVER = (0x33, 0x40, 0x5A)        # §4.1 elevated/cover value
INSET = 0.16                      # keeps the mass off the cell edge (§6.3)
HEIGHT_TILES = 0.44               # slab height as a fraction of tile height*scale


def _step(rgb: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    """Move a colour in LIGHTNESS only -- §4.1 forbids hue/saturation drift."""
    r, g, b = (c / 255.0 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r2, g2, b2 = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l * factor)), s)
    return (round(r2 * 255), round(g2 * 255), round(b2 * 255))


def draw_cover(faceted: bool = True, scale: int = AUTHOR_SCALE) -> Image.Image:
    w, h = TILE_W * scale, TILE_H * scale
    mass_h = round(h * HEIGHT_TILES)
    canvas_h = h + mass_h

    W, H, MH = w * SS, canvas_h * SS, mass_h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    tw, th = w * SS, h * SS

    def screen(x: float, y: float, lift: float = 0.0) -> tuple[float, float]:
        """Tile-space (0..1, 0..1) -> canvas pixels, `lift` raises off the plane."""
        sx = tw / 2 + (x - y) * (tw / 2)
        sy = MH + (x + y) * (th / 2) - lift
        return sx, sy

    a, b = INSET, 1.0 - INSET
    base = {k: screen(*p) for k, p in
            {"n": (a, a), "e": (b, a), "s": (b, b), "w": (a, b)}.items()}
    top = {k: screen(*p, lift=MH) for k, p in
           {"n": (a, a), "e": (b, a), "s": (b, b), "w": (a, b)}.items()}

    if faceted:
        top_c = COVER
        left_c = _step(COVER, 0.74)
        right_c = _step(COVER, 0.88)
    else:
        top_c = left_c = right_c = COVER

    # left-front and right-front faces, then the lit top face over them
    d.polygon([base["w"], base["s"], top["s"], top["w"]], fill=left_c + (255,))
    d.polygon([base["s"], base["e"], top["e"], top["s"]], fill=right_c + (255,))
    d.polygon([top["n"], top["e"], top["s"], top["w"]], fill=top_c + (255,))

    return img.resize((w, canvas_h), Image.LANCZOS)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("out")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--faceted", action="store_true", default=True)
    g.add_argument("--flat", dest="faceted", action="store_false")
    p.add_argument("--scale", type=int, default=AUTHOR_SCALE)
    args = p.parse_args()

    img = draw_cover(args.faceted, args.scale)
    img.save(args.out)
    print(f"{args.out}: {img.width}x{img.height} "
          f"({'faceted' if args.faceted else 'flat'}, {args.scale}x tile)")


if __name__ == "__main__":
    main()
