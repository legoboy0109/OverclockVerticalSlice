#!/usr/bin/env python3
"""Turn a shipped-scale sprite (or its glow mask) into HD-2D pixel art.

The HD-2D pivot (2026-09-29) keeps the generate -> cutout -> recolor pipeline and adds
this as the LAST step: a smooth render goes in, a sprite drawn on a coarse pixel grid
comes out, at the SAME file scale the renderer already loads.

    python3 tools/asset-pipeline/pixelize.py <src.png> <dst.png> [--factor 4] [--colors 12]
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
from PIL import Image, ImageFilter

# Outline ink: darker than every stage tile (void #0A0E17 excepted) so it reads as an
# edge on the lit floor without adding a hue. Near-black blue, matching the stage family.
OUTLINE_RGB = (12, 14, 22)


def _sat(rgb: np.ndarray) -> np.ndarray:
    rgb = rgb.astype(np.float64)
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-9), 0.0)


def _hue(rgb: np.ndarray) -> np.ndarray:
    r, g, b = [rgb[..., i].astype(np.float64) for i in range(3)]
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    d = np.where(mx - mn == 0, 1e-9, mx - mn)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4))
    return np.where(mx - mn == 0, 0.0, h * 60.0)


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


def pixelize(im: Image.Image, factor: int = 4, colors: int = 12,
             alpha_cut: float = 0.45, outline: bool = True, smooth: int = 7,
             keep_accent: float = 0.0) -> Image.Image:
    """Pixelize an RGBA sprite. See module doc for geometry guarantees.

    Method (chosen 2026-09-29 against area-average at 24 and 12 colours, and majority
    without pre-smoothing — comparison in .agent/notes.md): median-smooth the render,
    quantize it at FULL resolution to `colors`, then give each cell the MAJORITY
    palette colour of its pixels. Averaging invents in-between colours at every panel
    edge, which read as mud; majority keeps panels flat. The median pass removes the
    render's surface noise first, which otherwise wins majorities as speckle.
    """
    src = im.convert("RGBA")
    if smooth > 1:
        rgb = src.convert("RGB").filter(ImageFilter.MedianFilter(smooth))
        rgb.putalpha(src.getchannel("A"))
        src = rgb
    a = _canvas(np.asarray(src), factor)
    alpha = a[..., 3]
    opaque = alpha > 110
    h, w = alpha.shape
    gh, gw = h // factor, w // factor
    out = np.zeros((gh, gw, 4), dtype=np.uint8)
    if opaque.any():
        # Quantize ONLY opaque pixels — the keyed-out field would steal a palette slot.
        q = Image.fromarray(a[..., :3][opaque].reshape(1, -1, 3).astype(np.uint8), "RGB").quantize(
            colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        n = len(q.getpalette()) // 3
        pal = np.array(q.getpalette()[: n * 3], dtype=np.uint8).reshape(-1, 3)
        idx = np.full(alpha.shape, -1, dtype=np.int64)
        idx[opaque] = np.asarray(q).reshape(-1)
        cells = idx.reshape(gh, factor, gw, factor).transpose(0, 2, 1, 3).reshape(gh, gw, -1)
        # Per-cell majority via one-hot counts (vectorised; -1 = transparent, ignored).
        counts = np.stack([(cells == k).sum(axis=2) for k in range(len(pal))], axis=2)
        filled = counts.sum(axis=2) >= alpha_cut * factor * factor
        winner = counts.argmax(axis=2)
        if keep_accent > 0:
            # Thin neon trim (1-2 source px, e.g. structure edge lines) never wins a
            # majority and vanished entirely (Defensive Structure: 0% accent after
            # pixelize, 2026-09-30). A cell whose pixels are at least `keep_accent`
            # warm accent takes its most common ACCENT colour instead.
            ph = _hue(pal)
            acc = ((ph <= 45) | (ph >= 335)) & (_sat(pal) >= 0.25) & (pal.max(axis=1) >= 26)
            acc_counts = np.where(acc[None, None, :], counts, 0)
            share = acc_counts.sum(axis=2) / (factor * factor)
            take = filled & (share >= keep_accent)
            winner = np.where(take, acc_counts.argmax(axis=2), winner)
        out[filled, :3] = pal[winner[filled]]
        out[filled, 3] = 255
    solid = out[..., 3] > 0
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
    p.add_argument("--colors", type=int, default=12, help="palette size per sprite")
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
