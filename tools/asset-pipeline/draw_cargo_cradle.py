#!/usr/bin/env python3
"""Draw the Builder's open cargo cradle and seat it on an approved unit master.

    python3 tools/asset-pipeline/draw_cargo_cradle.py IN.png OUT.png [--cx 540] ...

WHY DRAWN AND NOT PROMPTED. Two full generation rounds (r7 "open skeletal frame
rails", r8 "a big separate box like a skip on a truck") failed to put a legible
cradle on this machine's back. Every attempt that described the cradle strongly
enough to appear also disturbed the body the user had already approved as
"shorter and bulkier" — bringing back cast shadows, orange dominance and long
legs, because prompt weight is finite and adding to one clause steals from
another. This is the same call ASSET-006/007 made for the terrain tiles: when a
requirement is *precise*, a generator cannot hit it and a draw can, by
construction.

WHY A CLOSED-ISH BOX AND NOT AN OPEN FRAME. The sprite ships 140 px wide. Frame
rails a few master-pixels thick are sub-pixel after the downscale and vanish; what
survives a resample is SILHOUETTE. So the cradle is a hard-edged mass that stands
proud of the hull line and breaks the top outline, with its opening read as a dark
interior rather than as thin geometry.

GEOMETRY. A 2:1 dimetric open-topped box: a rhombus rim, two visible outer side
faces extruded down, and a darker inner well so it reads as carrying nothing. The
canvas grows upward to make room, and the master is re-seated — the returned image
keeps the original ground-contact pivot at bottom-centre (art bible §8.4), so the
placement step downstream is unchanged.

VALUE. §4.1 differentiates faces in lightness only, so the three cradle faces are
one plating colour stepped down, never re-hued. The accent rim uses the rush hue;
`recolor.py` re-keys it for boom/neutral exactly as it does the rest of the sprite,
which is why the cradle must be painted in the SAME accent as the body rather than
in a bespoke colour.

Anti-aliasing: drawn at 4x and downsampled, matching draw_cover_tile.py.
"""

from __future__ import annotations

import argparse

from PIL import Image, ImageDraw

SS = 4  # supersample factor

# Unit palette (art bible §4.1 / the infantry family recipe).
# ⚠ Pulled toward the RENDERED hull's greys, not the spec swatches. The spec's
# #6E7C99 is what the generator was ASKED for; what it actually painted is a
# desaturated, slightly warmer grey, and a cradle mixed at the nominal value reads
# as a bluer bolt-on part sitting on a different machine.
# Sampled off THIS master's own plating rather than taken from the spec swatch:
# the render's greys are near-neutral (median rgb 110,111,111; lit panels 160,162,
# 162), while the spec's #6E7C99 is markedly blue. A cradle mixed at the nominal
# value reads as a bolt-on from a different machine. Measure the render, not the
# brief.
PLATE_LIT = (0x96, 0x98, 0x9A)   # lit top/rim   — just under the hull's lit panels
PLATE_MID = (0x70, 0x72, 0x76)   # base plating   — the hull's median
PLATE_DARK = (0x4A, 0x4C, 0x52)  # shadowed outer face
WELL_DARK = (0x24, 0x2C, 0x3E)   # inner well — reads as empty, not as a lid
ACCENT = (0xFF, 0x5A, 0x2E)      # rush accent; recolor.py re-keys this
INK = (0x22, 0x26, 0x30)         # outline


def _rhombus(cx: float, cy: float, w: float) -> list[tuple[float, float]]:
    """2:1 dimetric rhombus centred on (cx, cy), `w` wide and w/2 tall."""
    hw, hh = w / 2.0, w / 4.0
    return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def draw_cradle(canvas: Image.Image, cx: float, cy: float, width: float,
                height: float, wall: float) -> None:
    """Paint an open-topped iso box whose RIM centre is (cx, cy)."""
    d = ImageDraw.Draw(canvas)
    outer = _rhombus(cx, cy, width)
    inner = _rhombus(cx, cy, width - wall * 2)

    n, e, s, w = outer
    _, ie, is_, iw = inner

    # --- inner well: floor + the two far inner walls, so the opening has depth --
    floor_depth = height * 0.55
    floor = _rhombus(cx, cy + floor_depth, width - wall * 2)
    d.polygon([iw, (iw[0], iw[1] + floor_depth), (floor[2][0], floor[2][1]),
               is_], fill=WELL_DARK)
    d.polygon([ie, (ie[0], ie[1] + floor_depth), (floor[2][0], floor[2][1]),
               is_], fill=WELL_DARK)
    d.polygon(floor, fill=WELL_DARK)
    # the near inner faces (behind the rim) — darkest, they never catch light
    d.polygon([iw, inner[0], ie, (ie[0], ie[1] + floor_depth * 0.5),
               (cx, cy - _rhombus(0, 0, width - wall * 2)[0][1] * -1 + floor_depth * 0.5),
               (iw[0], iw[1] + floor_depth * 0.5)], fill=WELL_DARK)

    # --- outer side faces, extruded straight down --------------------------
    d.polygon([w, s, (s[0], s[1] + height), (w[0], w[1] + height)],
              fill=PLATE_MID, outline=INK)
    d.polygon([s, e, (e[0], e[1] + height), (s[0], s[1] + height)],
              fill=PLATE_DARK, outline=INK)

    # --- rim: the band between outer and inner rhombus ---------------------
    for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
        d.polygon([outer[a], outer[b], inner[b], inner[a]],
                  fill=PLATE_LIT, outline=INK)

    # --- accent: the two rim edges facing the camera ------------------------
    band = max(wall * 0.45, 2.0)
    for a, b in ((3, 2), (2, 1)):          # W->S and S->E, the near edges
        ax, ay = outer[a]
        bx, by = outer[b]
        d.polygon([(ax, ay), (bx, by), (bx, by + band), (ax, ay + band)],
                  fill=ACCENT)

    d.line([*outer, outer[0]], fill=INK, width=max(1, int(SS * 0.9)))
    d.line([*inner, inner[0]], fill=INK, width=max(1, int(SS * 0.7)))


def _shade_contact(base: Image.Image, cradle: Image.Image, cx: float, cy: float,
                   width: float, height: float, drop: float = 0.30,
                   strength: float = 0.62) -> None:
    """Multiply the hull under the cradle's footprint, so it sits IN the machine."""
    band = int(height * drop)
    x0, x1 = int(cx - width / 2), int(cx + width / 2)
    y0 = int(cy + height * 0.45)
    px = base.load()
    cp = cradle.load()
    for y in range(max(0, y0), min(base.height, y0 + band)):
        # fade the shade out with depth so the band has no hard lower edge
        t = 1.0 - (y - y0) / max(band, 1)
        k = 1.0 - (1.0 - strength) * t
        for x in range(max(0, x0), min(base.width, x1)):
            if cp[x, y][3] > 0:      # never darken the cradle itself
                continue
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src", help="approved master from art-source/cleaned/")
    p.add_argument("dst")
    p.add_argument("--cx", type=float, default=0.56,
                   help="rim centre X as a fraction of master width")
    p.add_argument("--cy", type=float, default=0.055,
                   help="rim centre Y as a fraction of master height (from the top "
                        "of the GROWN canvas)")
    p.add_argument("--width", type=float, default=0.46,
                   help="cradle width as a fraction of master width")
    p.add_argument("--height", type=float, default=0.13,
                   help="extrusion height as a fraction of master height")
    p.add_argument("--wall", type=float, default=0.030,
                   help="rim thickness as a fraction of master width")
    p.add_argument("--grow", type=float, default=0.16,
                   help="extra canvas above the master, fraction of its height")
    args = p.parse_args()

    master = Image.open(args.src).convert("RGBA")
    mw, mh = master.size
    pad = int(mh * args.grow)

    # Grow upward and re-seat the master, keeping bottom-centre as the pivot.
    canvas = Image.new("RGBA", (mw, mh + pad), (0, 0, 0, 0))
    canvas.alpha_composite(master, (0, pad))

    big = canvas.resize((canvas.width * SS, canvas.height * SS), Image.NEAREST)
    layer = Image.new("RGBA", big.size, (0, 0, 0, 0))
    draw_cradle(
        layer,
        cx=args.cx * mw * SS,
        cy=args.cy * (mh + pad) * SS,
        width=args.width * mw * SS,
        height=args.height * mh * SS,
        wall=args.wall * mw * SS,
    )
    # ★ Contact shading BEFORE the cradle goes down: darken the hull in a band
    # under the cradle's footprint. Without it the box reads as pasted on — a
    # flat-shaded object with no occlusion anywhere it meets the body looks like a
    # sticker, which is exactly what the first draft looked like.
    _shade_contact(big, layer,
                   cx=args.cx * mw * SS,
                   cy=args.cy * (mh + pad) * SS,
                   width=args.width * mw * SS,
                   height=args.height * mh * SS)
    big.alpha_composite(layer)
    out = big.resize(canvas.size, Image.LANCZOS)
    out = out.crop(out.getbbox())
    out.save(args.dst)
    print(f"{args.dst}: {out.width}x{out.height} (master was {mw}x{mh})")


if __name__ == "__main__":
    main()
