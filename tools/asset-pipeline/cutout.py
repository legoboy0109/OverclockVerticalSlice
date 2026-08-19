#!/usr/bin/env python3
"""Cut a generated image out of its background into an 8-bit+alpha PNG.

Post-work step between /asset-generate and placement under assets/art/ — art-bible
§8.1 keeps raws in art-source/, and units/structures must reach the runtime with a
real alpha channel (spec Format: "PNG 8-bit+alpha").

    python3 tools/asset-pipeline/cutout.py <src.png> <dst.png> [tol]

Requires numpy + Pillow (unlike comfyui_generate.py, which is stdlib-only).

How it works: flood-fills inward from the image border through pixels within `tol`
of the border colour. Deliberately NOT a global colour key — the fill is
connectivity-limited, so greys *inside* the subject (plating, panels, glass)
survive while only the surrounding field goes transparent.

★ THE BACKGROUND MUST CONTRAST WITH THE SUBJECT. Our structures are near-black
(#1B2130). A "pure black void background" render — which the art bible's stage
colour tempts you into prompting — is UNKEYABLE: subject and field share a value,
so the fill either stalls at the frame or floods through the building and eats it
(both verified on the HQ, 2026-08-18). Prompt a flat light-grey studio background
plus negatives `dark background, gradient background, vignette`; the dark stage
colour is applied in-engine and must never be baked into a sprite.

Gradient backgrounds also defeat this: a single-colour tolerance cannot cross one.
Neighbour-relative region growing walks gradients but then eats the dark subject —
force a FLAT background at generation time instead of post-processing around it.

Detached leftovers (cast shadows, stray props) can be dropped with
--largest-only; a shadow *touching* the subject is connected to it and will
survive, so re-roll the generation rather than attempting mask surgery.
"""
from __future__ import annotations

import argparse
import sys
from collections import deque

import numpy as np
from PIL import Image

# a keyable render's border field is a large fraction of the frame; below this the
# background probably does not contrast with the subject
MIN_BORDER_FRACTION = 0.15


def cutout(path: str, tol: int = 22, largest_only: bool = False,
           pockets: bool = False):
    """Return (RGBA image, background mask). Background pixels get alpha 0."""
    im = Image.open(path).convert("RGB")
    a = np.array(im).astype(np.int16)
    h, w, _ = a.shape

    ring = np.concatenate([a[0:6].reshape(-1, 3), a[-6:].reshape(-1, 3),
                           a[:, 0:6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    near = np.abs(a - bg).max(axis=2) <= tol

    if near.mean() < MIN_BORDER_FRACTION:
        print(f"WARN {path}: only {near.mean() * 100:.0f}% of the frame matches the "
              f"border colour — the background may not contrast with the subject; "
              f"re-generate on a flat light background", file=sys.stderr)

    seen = np.zeros((h, w), bool)
    dq: deque = deque()

    def seed(y: int, x: int) -> None:
        if near[y, x] and not seen[y, x]:
            seen[y, x] = True
            dq.append((y, x))

    for x in range(w):
        seed(0, x)
        seed(h - 1, x)
    for y in range(h):
        seed(y, 0)
        seed(y, w - 1)

    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                dq.append((ny, nx))

    if pockets:
        seen |= _enclosed_pockets(near, seen)

    alpha = np.where(seen, 0, 255).astype(np.uint8)
    rgba = np.dstack([a.astype(np.uint8), alpha])

    if largest_only:
        rgba = _keep_largest(rgba)

    return Image.fromarray(rgba, "RGBA"), seen


def _enclosed_pockets(near: np.ndarray, seen: np.ndarray,
                      min_area: int = 24) -> np.ndarray:
    """Background-coloured regions the border fill could not reach.

    An infantry sprite encloses background between its legs and under its arms.
    Those pockets match the background colour but touch no frame edge, so the
    connectivity-limited border fill leaves them opaque — the sprite ships with a
    pale slab between its knees (verified on the first Trooper candidate,
    2026-08-19). Structures rarely enclose anything, which is why this went
    unnoticed through ASSET-001/005.

    Opt-in (`--pockets`), because the test is colour-only: a genuinely
    background-coloured area *inside* the subject is indistinguishable from a
    pocket. Safe for our units (mid-slate armour against a light-grey field);
    keep it off for anything with large pale interior panels.
    """
    pocket = near & ~seen
    if not pocket.any():
        return np.zeros_like(seen)
    try:
        from scipy import ndimage
        lab, n = ndimage.label(pocket)
        if not n:
            return np.zeros_like(seen)
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = {i + 1 for i, sz in enumerate(sizes) if sz >= min_area}
        out = np.isin(lab, list(keep)) if keep else np.zeros_like(seen)
    except ImportError:
        out = _label_pockets_bfs(pocket, min_area)
    if out.any():
        print(f"cleared {out.sum()} px of enclosed background pocket(s)")
    return out


def _label_pockets_bfs(pocket: np.ndarray, min_area: int) -> np.ndarray:
    """scipy-free fallback for _enclosed_pockets."""
    h, w = pocket.shape
    out = np.zeros_like(pocket)
    visited = np.zeros_like(pocket)
    for sy in range(h):
        for sx in range(w):
            if not pocket[sy, sx] or visited[sy, sx]:
                continue
            comp, dq = [], deque([(sy, sx)])
            visited[sy, sx] = True
            while dq:
                y, x = dq.popleft()
                comp.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if (0 <= ny < h and 0 <= nx < w and pocket[ny, nx]
                            and not visited[ny, nx]):
                        visited[ny, nx] = True
                        dq.append((ny, nx))
            if len(comp) >= min_area:
                for y, x in comp:
                    out[y, x] = True
    return out


def _keep_largest(rgba: np.ndarray) -> np.ndarray:
    """Drop every opaque blob but the biggest — kills detached shadows/props."""
    try:
        from scipy import ndimage
    except ImportError:
        print("WARN --largest-only needs scipy; skipping", file=sys.stderr)
        return rgba
    lab, n = ndimage.label(rgba[:, :, 3] > 0)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        main = int(np.argmax(sizes)) + 1
        rgba[:, :, 3] = np.where(lab == main, rgba[:, :, 3], 0)
        print(f"dropped {n - 1} detached fragment(s)")
    return rgba


def trim(img: Image.Image) -> Image.Image:
    """Crop to the opaque bounding box (sprite sheets want no dead margin)."""
    a = np.array(img)
    ys, xs = np.where(a[:, :, 3] > 0)
    if not len(ys):
        return img
    return img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("tol", nargs="?", type=int, default=22,
                   help="border-colour tolerance, default 22")
    p.add_argument("--largest-only", action="store_true",
                   help="keep only the largest opaque blob")
    p.add_argument("--pockets", action="store_true",
                   help="also key background-coloured regions the border fill "
                        "cannot reach (between an infantry sprite's legs/arms)")
    p.add_argument("--trim", action="store_true", help="crop to the opaque bounds")
    args = p.parse_args()

    img, seen = cutout(args.src, args.tol, args.largest_only, args.pockets)
    if args.trim:
        img = trim(img)
    img.save(args.dst)
    print(f"removed {seen.mean() * 100:.1f}% -> {args.dst} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
