#!/usr/bin/env python3
"""Downscale approved masters to shipping resolution and place them in assets/art/.

    python3 tools/asset-pipeline/place_runtime.py            # write the VS set
    python3 tools/asset-pipeline/place_runtime.py --dry-run  # list what would change

Masters live at ~800-1000px in art-source/. The runtime asset is NOT the
on-screen size: art bible S8.3 ships flat-vector art at **2-3x effective display
size** so one asset serves 1080p and 1440p and the S2 glow keeps its falloff.
We ship the conservative 2x end, because S8.7 already flags the HQ as the
atlas-escalation risk.

    asset     on-screen (S4-02 amendment)   shipped here
    Scout     ~74px wide                    148px wide
    Trooper   ~65px tall                    130px tall
    Heavy     ~74px tall                    148px tall
    HQ        ~256px wide (2 tiles)         512px wide
    Outpost   ~192px wide (1.5 tiles)       384px wide

On resampling and the alpha edge -- measured, because the intuitive fix is wrong.
`cutout.py` zeroes alpha but leaves the original light-grey background RGB
underneath, which looks like it should bleed a pale halo into every edge. The
textbook answer is to premultiply, resample, then un-premultiply. **That measured
WORSE here**: mean absolute error against ground truth 1.61 vs 0.28, with max
error 65, because un-premultiplying divides by a near-zero rim alpha and clips.
Alpha-bleeding the RGB outward first scored identically to doing nothing (0.28).

So we resample straight RGBA and keep it simple. Ground truth for that comparison
is "composite over the stage colour at full resolution, then downscale" -- what
the player actually sees. Straight resampling lands 0.28 mean / 10-20 max error
against it, which is well under a visible step. This holds because our keyed
background is a neutral light grey; re-measure if that ever changes.

Facings: only `e` and `w` are authored. `n` aliases `e` and `s` aliases `w` (see
make_facings.py); the renderer maps facing -> sprite rather than us shipping
duplicate bytes. That mapping is restated in assets/art/README.md, which is the
S4-03 renderer's contract.

State token is `idle` frame `01` for everything -- the approved base look IS the
idle pose. The S8.5 state sets (move/attack/hit/destroyed) are not authored yet,
so no other frame exists to ship.
"""

from __future__ import annotations

import argparse
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FACINGS = os.path.join(ROOT, "art-source", "facings")
CLEANED = os.path.join(ROOT, "art-source", "cleaned")
ART = os.path.join(ROOT, "assets", "art")

HUES = ("rush", "boom", "neutral")

# (archetype, which axis the shipped size pins, shipped px)
UNITS = (
    # ★ The Builder pins WIDTH like the Scout: it is a four-legged walker whose
    # read is the long hunched body, not its height. Shipped a touch narrower than
    # the Scout so the two are tellable apart at a glance despite both being
    # four-legged — §3.1's silhouette-separation rule.
    ("builder", "w", 140),
    ("scout",   "w", 148),
    ("trooper", "h", 130),
    ("heavy",   "h", 148),
    # Sniper pins HEIGHT and ships the tallest of the roster: §3.1 puts it at the
    # opposite end of the posture axis from the Scout (tall+vertical vs low+horizontal),
    # and that ratio is the primary thumbnail read.
    ("sniper",  "h", 156),
)
# (runtime name, master stem, axis, shipped px)
STRUCTURES = (
    ("hq",                 "hq_%s_r7_c2_clean.png",      "w", 512),
    # ★ Runtime name is BARRACKS (S6-03 rename); the master stem keeps its
    # original "outpost_" prefix because that is what the generation run produced.
    # The runtime name is the load-bearing half — EntitySpriteCatalog derives it
    # from StructureTypeDef.display_name, so a stale name here regenerates files
    # NOTHING READS.
    ("barracks",           "outpost_%s_r5_c3_clean.png", "w", 384),
    # The three one-tile structures ship at 256 = 2x the 128px on-screen tile width.
    # The renderer fits every structure to one tile anyway
    # (EntitySpriteFeed.STRUCTURE_TARGET_WIDTH_PX), so this only sets source detail.
    # ★ Runtime name is FACTORY (S6-03 rename). Same note as Barracks above.
    ("factory",            "econ_%s_r5_c2_clean.png",    "w", 256),
    ("defensive_structure","def_%s_r2_c2_clean.png",     "w", 256),
    ("research_lab",       "lab_%s_r6_c2_clean.png",     "w", 256),
)


def _resize(im: Image.Image, axis: str, target: int) -> Image.Image:
    """Downscale to `target` px on `axis`, preserving aspect. See the module note
    on why this is a straight RGBA resample and not a premultiplied one."""
    if axis == "w":
        w = target
        h = max(1, round(im.height * target / im.width))
    else:
        h = target
        w = max(1, round(im.width * target / im.height))
    return im.convert("RGBA").resize((w, h), Image.LANCZOS)


def _write(src_path: str, dst_path: str, axis: str, target: int,
           dry_run: bool) -> tuple[str, str]:
    im = Image.open(src_path)
    out = _resize(im, axis, target)
    rel = os.path.relpath(dst_path, ROOT)
    if not dry_run:
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        out.save(dst_path)
    return rel, f"{im.width}x{im.height} -> {out.width}x{out.height}"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    n = 0
    for archetype, axis, px in UNITS:
        for hue in HUES:
            for facing in ("e", "w"):
                src = os.path.join(FACINGS, f"unit_{archetype}_{hue}_{facing}.png")
                if not os.path.exists(src):
                    print(f"WARN missing master: {src}", file=sys.stderr)
                    continue
                dst = os.path.join(ART, "units",
                                   f"unit_{archetype}_{hue}_{facing}_idle_01.png")
                rel, size = _write(src, dst, axis, px, args.dry_run)
                print(f"{rel:58s} {size}")
                n += 1

    for name, stem, axis, px in STRUCTURES:
        for hue in HUES:
            src = os.path.join(CLEANED, stem % hue)
            if not os.path.exists(src):
                print(f"WARN missing master: {src}", file=sys.stderr)
                continue
            dst = os.path.join(ART, "structures", f"struct_{name}_{hue}_idle.png")
            rel, size = _write(src, dst, axis, px, args.dry_run)
            print(f"{rel:58s} {size}")
            n += 1

    print(f"\n{'would write' if args.dry_run else 'wrote'} {n} runtime sprites")


if __name__ == "__main__":
    main()
