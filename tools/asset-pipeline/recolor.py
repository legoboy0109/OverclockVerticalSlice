#!/usr/bin/env python3
"""Derive a faction hue variant from an approved base sprite.

The VS ships **one shared silhouette per role** in three hues (rush / boom /
neutral). Generating the three independently drifts the shape and breaks that
requirement -- generation-prompts.md rule 1, and verified: same-seed hue swaps do
not hold composition. So boom and neutral are produced here, by recoloring the
approved rush master's accent.

    python3 tools/asset-pipeline/recolor.py <src_clean.png> <dst.png> boom

Run it on files from `art-source/cleaned/`, never on a raw generation -- a raw
still carries whatever the cutout/deshadow pass removed.

How the accent is found: the rush accent (#FF5A2E) is the only saturated warm
thing in our palette. What protects everything else is the HUE gate, not the
saturation gate -- slate unit armour (#6E7C99) sits at saturation 0.28 but reads
blue at ~218 deg, and the near-black structure plate and ink outline fall under
the saturation floor. So the saturation gate can stay low (0.25) to catch the
accent's shaded and anti-aliased pixels without endangering the armour.

The one thing it does catch that is not accent is the Heavy's residual warm
ground streak (saturation 0.41), which gets recolored along with everything else.
That is accepted: the streak was already verified invisible at board scale, so a
recolored invisible streak is still invisible -- and the alternative, raising the
gate above it, leaves an orange fringe on a cyan unit, which is a palette
violation you *can* see.

How the remap works: hue is replaced outright, while saturation and brightness
are *scaled* by the target anchor's ratio to the rush anchor rather than being set
flat. That preserves the accent's internal shading -- lit faces, shadowed faces,
the emissive hot spots -- instead of flattening it into one dead colour. A flat
fill reads as a sticker at board scale.

Brightness is scaled in LUMA, not in HSV value (`--scale`, default `luma`).
Scaling value made the grayscale result depend on saturation, so shaded and
anti-aliased accent barely moved and the two armies ended up only ~18/255 apart
in grayscale -- indistinguishable. Scaling luma moves every accent pixel's
luminance by the same anchor ratio and roughly doubles that separation to ~34.
That is a real improvement but NOT a solution to the colourblind ownership gap:
at unit size the remaining difference is still subtle, and the non-hue ownership
markers the art bible defers are what actually fix it.

Neutral is achromatic by design (art bible: the reserved-neon budget is exactly
two hues), so its variant lands as light silver and carries no hue information at
all. That is intentional: a Neutral-vs-Neutral board must lean on the non-hue
ownership markers, which is a stated consequence, not a bug here.
"""

from __future__ import annotations

import argparse
import sys

try:
    import numpy as np
except ImportError:
    sys.exit("ERROR: recolor.py needs numpy + Pillow "
             "(unlike comfyui_generate.py, which is stdlib-only)")

from PIL import Image

# LOCKED palette anchors (art bible S4.2, validated S4-01). Do not retune these
# to taste -- Boom's separation from every stage tile was verified numerically.
ANCHORS = {
    "rush":    (0xFF, 0x5A, 0x2E),
    "boom":    (0x22, 0xC7, 0xF0),
    "neutral": (0xC6, 0xCE, 0xD8),
}

# The warm band the rush accent occupies. The window WRAPS past 360: accent
# pixels that blend toward the ink outline drift to ~350 deg, and a naive
# `hue <= 45` test silently misses every one of them -- which left a 1px orange
# fringe around each cyan panel, i.e. both locked hues on one unit.
ACCENT_HUE_MAX = 45.0
ACCENT_HUE_WRAP_MIN = 335.0
ACCENT_SAT_MIN = 0.25
ACCENT_VAL_MIN = 0.10


def _hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Vectorised RGB->HSV on a float array in 0..1. Hue in degrees."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    i = m & (mx == r)
    h[i] = ((g - b)[i] / d[i]) % 6
    i = m & (mx == g)
    h[i] = ((b - r)[i] / d[i]) + 2
    i = m & (mx == b)
    h[i] = ((r - g)[i] / d[i]) + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return h * 60.0, s, mx


def _from_hsv(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Vectorised HSV->RGB, returning a float array in 0..1."""
    c = v * s
    hp = (h % 360.0) / 60.0
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(c)
    idx = hp.astype(int) % 6
    opts = np.stack([
        np.stack([c, x, z], -1), np.stack([x, c, z], -1),
        np.stack([z, c, x], -1), np.stack([z, x, c], -1),
        np.stack([x, z, c], -1), np.stack([c, z, x], -1),
    ])
    rgb = np.take_along_axis(opts, idx[None, ..., None], 0)[0]
    return rgb + (v - c)[..., None]


def _luma(rgb: np.ndarray) -> np.ndarray:
    """Rec.709 relative luminance of a float RGB array in 0..1."""
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def recolor(path: str, target: str, sat_min: float = ACCENT_SAT_MIN,
            scale: str = "luma"):
    """Return (RGBA image, accent pixel count) with the accent moved to `target`."""
    if target not in ANCHORS:
        raise ValueError(f"unknown faction {target!r}; expected {sorted(ANCHORS)}")
    if scale not in ("luma", "value"):
        raise ValueError(f"unknown scale mode {scale!r}; expected luma or value")

    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    rgb = a[:, :, :3].astype(np.float64) / 255.0
    alpha = a[:, :, 3]

    h, s, v = _hsv(rgb)
    warm = (h <= ACCENT_HUE_MAX) | (h >= ACCENT_HUE_WRAP_MIN)
    mask = (alpha > 0) & warm & (s >= sat_min) & (v >= ACCENT_VAL_MIN)
    if not mask.any():
        return im, 0

    src_h, src_s, src_v = _hsv(np.array(ANCHORS["rush"], float).reshape(1, 1, 3) / 255.0)
    dst_h, dst_s, dst_v = _hsv(np.array(ANCHORS[target], float).reshape(1, 1, 3) / 255.0)

    # scale, do not flatten: the accent's own light/shadow structure survives
    new_h = np.full_like(h, float(dst_h[0, 0]))
    new_s = np.clip(s * (float(dst_s[0, 0]) / float(src_s[0, 0])), 0.0, 1.0)

    if scale == "value":
        new_v = np.clip(v * (float(dst_v[0, 0]) / float(src_v[0, 0])), 0.0, 1.0)
    else:
        # Scaling VALUE makes the grayscale result depend on saturation: at full
        # saturation cyan-over-orange lifts luma x1.45, but shaded and
        # anti-aliased accent sits near neutral where the ratio collapses toward
        # 1. Averaged over a real sprite that left rush and boom only ~18/255
        # apart -- the two armies were indistinguishable in grayscale.
        #
        # So scale LUMA directly instead: every accent pixel's luminance moves by
        # the same anchor ratio regardless of its saturation. V is then solved
        # per pixel from the luma we want and the luma the new hue/sat carries at
        # V=1. Ownership survives desaturation; the accent's internal shading
        # still scales proportionally, so nothing flattens.
        ratio = _luma(np.array(ANCHORS[target], float) / 255.0) / \
            _luma(np.array(ANCHORS["rush"], float) / 255.0)
        unit = _from_hsv(new_h, new_s, np.ones_like(v))
        new_v = np.clip(_luma(rgb) * ratio / np.maximum(_luma(unit), 1e-6), 0.0, 1.0)

    out = _from_hsv(np.where(mask, new_h, h),
                    np.where(mask, new_s, s),
                    np.where(mask, new_v, v))
    res = a.copy()
    res[:, :, :3] = np.where(mask[..., None],
                             np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8),
                             a[:, :, :3])
    return Image.fromarray(res, "RGBA"), int(mask.sum())


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src", help="an approved master from art-source/cleaned/")
    p.add_argument("dst")
    p.add_argument("faction", choices=sorted(ANCHORS))
    p.add_argument("--scale", choices=("luma", "value"), default="luma",
                   help="how the accent's brightness is remapped. 'luma' (default) "
                        "moves every accent pixel's luminance by the anchor ratio, "
                        "so the factions stay apart in grayscale. 'value' scales "
                        "HSV value instead, which collapses that separation on "
                        "shaded pixels — kept only for reproducing older output")
    p.add_argument("--sat-min", type=float, default=ACCENT_SAT_MIN,
                   help="accent saturation gate (default 0.25). The hue window "
                        "is what protects the armour, so this can stay low; "
                        "raise it only if a sprite has warm non-accent detail")
    args = p.parse_args()

    img, n = recolor(args.src, args.faction, args.sat_min, args.scale)
    if not n:
        print(f"WARN {args.src}: no accent pixels matched — nothing recolored",
              file=sys.stderr)
    img.save(args.dst)
    total = (np.array(img)[:, :, 3] > 0).sum()
    print(f"{args.dst}: recolored {n} px ({100 * n / max(total, 1):.1f}% of sprite) "
          f"-> {args.faction}")


if __name__ == "__main__":
    main()
