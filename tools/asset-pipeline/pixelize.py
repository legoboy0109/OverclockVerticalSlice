#!/usr/bin/env python3
"""Turn a shipped-scale sprite (or its glow mask) into HD-2D pixel art.

The HD-2D pivot (2026-09-29) keeps the generate -> cutout -> recolor pipeline and adds
this as the LAST step: a smooth render goes in, a sprite drawn on a coarse pixel grid
comes out, at the SAME file scale the renderer already loads.

    python3 tools/asset-pipeline/pixelize.py <src.png> <dst.png> [--factor 4] [--colors 24]
    python3 tools/asset-pipeline/pixelize.py <mask.png> <dst.png> --mask

★ Why the output is upscaled back instead of shipped tiny: sprites ship at 2x their
on-screen size and the renderer halves them (assets/art/README.md). With --factor 4,
one art pixel = 4 file px = exactly 2x2 screen px, so no renderer change is needed and
the "medium" density the user chose (art pixel = 2 screen px) falls out for free.

★ The sprite and its glow mask MUST be run with the same --factor. Geometry here is
deterministic from the input size alone (pad to a multiple of factor at the TOP and
split sideways, then a one-cell margin all round) and never trims, so a sprite and a
mask of the same input size land on identical canvases and stay aligned. Trimming
would crop the two differently and slide the glow off the armour.

Pivot: the bottom-centre stays the ground contact. The bottom margin cell is filled by
the outline under the feet, so contact moves down one art pixel (2 screen px) — within
the noise of the feet themselves.

Requires numpy + Pillow.
"""
from __future__ import annotations

import argparse

import numpy as np
from PIL import Image

# Outline ink: darker than every stage tile (void #0A0E17 excepted) so it reads as an
# edge on the lit floor without adding a hue. Near-black blue, matching the stage family.
OUTLINE_RGB = (12, 14, 22)


def _canvas(a: np.ndarray, factor: int) -> np.ndarray:
    """Pad to a multiple of factor (extra rows on top, columns split) plus one cell margin."""
    h, w = a.shape[:2]
    ph = (-h) % factor
    pw = (-w) % factor
    pad = ((ph + factor, factor), (pw // 2 + factor, pw - pw // 2 + factor))
    if a.ndim == 3:
        pad = pad + ((0, 0),)
    return np.pad(a, pad)


def _box_down(a: np.ndarray, factor: int) -> np.ndarray:
    h, w = a.shape[:2]
    return a.reshape(h // factor, factor, w // factor, factor, *a.shape[2:]).mean(axis=(1, 3))


def _up(a: np.ndarray, factor: int) -> np.ndarray:
    return a.repeat(factor, axis=0).repeat(factor, axis=1)


def pixelize(im: Image.Image, factor: int = 4, colors: int = 24,
             alpha_cut: float = 0.45, outline: bool = True) -> Image.Image:
    """Pixelize an RGBA sprite. See module doc for geometry guarantees."""
    a = _canvas(np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0, factor)
    alpha = a[..., 3:4]
    # Premultiply before averaging, or the transparent field's leftover RGB (the grey
    # studio background cutout.py keyed out) bleeds a light fringe into every edge.
    small_pm = _box_down(a[..., :3] * alpha, factor)
    small_a = _box_down(alpha, factor)
    solid = small_a[..., 0] >= alpha_cut
    rgb = np.where(small_a > 1e-6, small_pm / np.maximum(small_a, 1e-6), 0.0)
    rgb8 = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)

    # Quantize ONLY the opaque cells — letting the transparent field in wastes a
    # palette slot on it and drags edge colours toward it.
    if solid.any() and colors > 0:
        px = rgb8[solid].reshape(1, -1, 3)
        q = Image.fromarray(px, "RGB").quantize(
            colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        rgb8[solid] = np.asarray(q).reshape(-1, 3)

    out = np.zeros((*solid.shape, 4), dtype=np.uint8)
    out[..., :3] = rgb8
    out[..., 3] = np.where(solid, 255, 0)
    if outline:
        p = np.pad(solid, 1)
        ring = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]) & ~solid
        out[ring] = (*OUTLINE_RGB, 255)
    return Image.fromarray(_up(out, factor), "RGBA")


def pixelize_mask(im: Image.Image, factor: int = 4, levels: int = 4) -> Image.Image:
    """Pixelize a single-channel glow mask onto the same grid as its sprite.

    Kept soft-ish (a few grey levels, not binary) so the shader's pulse still has a
    ramp to breathe along; hard 0/1 cells made the breathe read as blinking.
    """
    src = im.convert("RGBA") if im.mode in ("RGBA", "LA") else im.convert("L")
    arr = np.asarray(src, dtype=np.float32) / 255.0
    if arr.ndim == 3:  # mask stored as RGBA: use luminance weighted by alpha
        arr = arr[..., :3].mean(axis=2) * arr[..., 3]
    small = _box_down(_canvas(arr, factor), factor)
    small = np.round(np.clip(small * 1.6, 0, 1) * (levels - 1)) / (levels - 1)
    return Image.fromarray((_up(small, factor) * 255 + 0.5).astype(np.uint8), "L")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--factor", type=int, default=4, help="file px per art px (default 4)")
    p.add_argument("--colors", type=int, default=24, help="palette size per sprite")
    p.add_argument("--mask", action="store_true", help="input is a glow mask")
    p.add_argument("--no-outline", action="store_true")
    args = p.parse_args()
    im = Image.open(args.src)
    if args.mask:
        out = pixelize_mask(im, args.factor)
    else:
        out = pixelize(im, args.factor, args.colors, outline=not args.no_outline)
    out.save(args.dst)
    print(f"{args.src} -> {args.dst} {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()
