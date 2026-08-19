#!/usr/bin/env python3
"""Derive the §8.9 emission mask (glow layer) from an approved sprite.

    python3 tools/asset-pipeline/glow_mask.py            # write the VS set
    python3 tools/asset-pipeline/glow_mask.py --dry-run

Art bible §8.9 drives every glow state from one CanvasItem shader that blends
`emission_mask × faction_hue × pulse_intensity`, with hue and intensity as
per-instance uniforms so all units share one material (§8.7 rule 2). §8.5 line 529
calls the mask "a fast derive-from-base pass (isolate the already-painted trim),
not a second full paintover" -- which is exactly what this does, using the same
accent detection `recolor.py` uses.

This is what completes the two idle states without any new body art. §8.5 is
explicit that Idle (AP-spent) is the "same base pose frames, glow-clamp state
only -- do not author a second body pose", and that idle's breathe is "the *glow
layer*, not the body". Both idles are therefore the shipped `idle_01` sprite plus
this mask, with the shader doing breathe (slow sine) vs clamp (fixed override).

ONE MASK SERVES ALL THREE HUES. The mask is greyscale "which pixels are trim",
and the faction hue arrives as a shader uniform -- so the rush/boom/neutral
sprites of the same asset and facing share a single mask. That is why masks are
named without a faction token. Derivation reads the RUSH sprite specifically,
because its warm accent is the detectable one; neutral's silver accent is by
design too close to the plating to key.

The mask is the accent's EDGE BAND, not the whole accent block (`--mode`, default
`trim`). Our units carry deliberately large accent colour blocks -- widened for
board legibility -- and 40-62% of a unit is accent. Emitting all of it blows the
panels out at high pulse and destroys their shape reading. §5.1 asks for "thin
neon emissive trim on armor edges" as the emissive layer, distinct from the
faction accent *colour-block* on plating, so the mask keeps the rim of each
accent region and drops its interior. Verified by rendering both at pulse 0.35
and 0.9. `--mode block` emits the full accent if that is ever wanted.

The mask is graded, not binary: value tracks how bright the accent pixel is, so
the hottest trim glows hardest and the §2 falloff stays soft. Output is an 8-bit
greyscale PNG the shader samples as a single channel.
"""

from __future__ import annotations

import argparse
import os
import sys

try:
    import numpy as np
except ImportError:
    sys.exit("ERROR: glow_mask.py needs numpy + Pillow")

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recolor import (_hsv, ACCENT_HUE_MAX, ACCENT_HUE_WRAP_MIN,  # noqa: E402
                     ACCENT_SAT_MIN, ACCENT_VAL_MIN)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "assets", "art")

# (subdir, rush filename, mask filename) -- one mask per asset+facing, hue-agnostic
TARGETS = [
    ("units", f"unit_{a}_rush_{f}_idle_01.png", f"unit_{a}_{f}_idle_01_glow.png")
    for a in ("scout", "trooper", "heavy") for f in ("e", "w")
] + [
    ("structures", f"struct_{n}_rush_idle.png", f"struct_{n}_idle_glow.png")
    for n in ("hq", "production_outpost")
]


def _edge_band(mask: np.ndarray, px: int = 2) -> np.ndarray:
    """Keep the rim of each emissive region, drop its interior (§5.1 thin trim)."""
    solid = mask > 0.15
    eroded = solid.copy()
    for _ in range(px):
        e = eroded.copy()
        e[1:] &= eroded[:-1]
        e[:-1] &= eroded[1:]
        e[:, 1:] &= eroded[:, :-1]
        e[:, :-1] &= eroded[:, 1:]
        eroded = e
    return mask * (solid & ~eroded)


def glow_mask(path: str, mode: str = "trim") -> tuple[Image.Image, float]:
    """Return (greyscale emission mask, fraction of the sprite that emits)."""
    a = np.array(Image.open(path).convert("RGBA"))
    rgb = a[:, :, :3].astype(np.float64) / 255.0
    alpha = a[:, :, 3]

    h, s, v = _hsv(rgb)
    warm = (h <= ACCENT_HUE_MAX) | (h >= ACCENT_HUE_WRAP_MIN)
    accent = (alpha > 0) & warm & (s >= ACCENT_SAT_MIN) & (v >= ACCENT_VAL_MIN)

    mask = np.zeros(alpha.shape, np.float64)
    if accent.any():
        lum = 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]
        peak = float(lum[accent].max())
        # graded: hottest trim emits hardest, shadowed accent falls off
        mask[accent] = np.clip(lum[accent] / max(peak, 1e-6), 0.0, 1.0)
        # never emit through a transparent pixel
        mask *= (alpha / 255.0)
        if mode == "trim":
            mask = _edge_band(mask)

    img = Image.fromarray(np.clip(mask * 255.0 + 0.5, 0, 255).astype(np.uint8), "L")
    emit = float((mask > 0.05).sum())
    return img, emit / max(int((alpha > 0).sum()), 1)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--mode", choices=("trim", "block"), default="trim",
                   help="trim (default) emits only the rim of each accent "
                        "region per S5.1; block emits the whole accent")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    n = 0
    for subdir, src_name, dst_name in TARGETS:
        src = os.path.join(ART, subdir, src_name)
        if not os.path.exists(src):
            print(f"WARN missing sprite: {src}", file=sys.stderr)
            continue
        img, frac = glow_mask(src, args.mode)
        dst = os.path.join(ART, subdir, dst_name)
        if not args.dry_run:
            img.save(dst)
        print(f"{os.path.relpath(dst, ROOT):56s} {img.width}x{img.height}  "
              f"emits {100 * frac:4.1f}% of sprite")
        n += 1
    print(f"\n{'would write' if args.dry_run else 'wrote'} {n} glow masks")


if __name__ == "__main__":
    main()
