#!/usr/bin/env python3
"""Derive a unit's facing set from one approved master.

    python3 tools/asset-pipeline/make_facings.py \\
        art-source/cleaned/trooper_rush_r7_c1_clean.png \\
        art-source/facings unit_trooper_rush

Why only two sprites come out of this
-------------------------------------
Art bible S8.4 asks for 4 facings (n/s/e/w) but explicitly expects only
**2-3 unique paintovers**, with `w` an engine horizontal-flip of `e` wherever the
subject is left/right symmetric. We ship the minimum end of that: two sprites,
mirrored, with n/s aliased onto them.

The reason we do not author real n and e views is worth recording. The local
ComfyUI install is bare SDXL base -- no ControlNet, no IPAdapter -- and
text-to-image cannot rotate a *specific* design. Tested 2026-08-19 on the
Trooper: three "strict side profile" attempts returned front views (one with a
cyan visor, which is Boom's locked hue on a Rush unit), and the back-view
attempts drifted into a different machine. A unit whose design changes when it
turns is worse for Pillar-3 legibility than a unit that does not turn at all.

This is affordable because **nothing in the game reads facing**: combat resolves
along cardinal directions with no facing/flanking/rear modifier, the entity
registry has no facing field, and neither S4-03's acceptance criteria nor
S4-04's Pillar-3 gate mention it. Facing here is cosmetic travel feedback only.

Facing -> sprite mapping
------------------------
On a 2:1 dimetric board the four grid directions split cleanly by screen-x:

    n  (up-right)    -> e sprite     s  (down-left)  -> w sprite
    e  (down-right)  -> e sprite     w  (up-left)    -> w sprite

So the renderer picks the sprite by the *sign of screen-x travel*, and the unit
appears to turn when it reverses along that axis. Because the masters are
near-frontal three-quarter views, the cue is subtle -- deliberate and accepted,
not an oversight.

Mirror-safety (S8.4 requires confirming this before committing a sprite to flip):
our units carry no text, insignia, or asymmetric faction kit -- the S5.2
Mass-Distribution-Bias markers are deferred with Pillar-4 faction asymmetry -- so
there is nothing that reads wrong reversed. Re-confirm if kit markers are added.
"""

from __future__ import annotations

import argparse
import os
import sys

from PIL import Image

# grid facing -> which authored sprite serves it (see module docstring)
FACING_ALIASES = {"n": "e", "e": "e", "s": "w", "w": "w"}


def make_facings(src: str, out_dir: str, stem: str) -> list[str]:
    """Write the `e` master and its mirrored `w` twin. Returns the paths."""
    im = Image.open(src).convert("RGBA")
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for facing, img in (("e", im),
                        ("w", im.transpose(Image.FLIP_LEFT_RIGHT))):
        path = os.path.join(out_dir, f"{stem}_{facing}.png")
        img.save(path)
        written.append(path)
    return written


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src", help="an approved master from art-source/cleaned/")
    p.add_argument("out_dir")
    p.add_argument("stem", help="output basename, e.g. unit_trooper_rush")
    args = p.parse_args()

    if not os.path.exists(args.src):
        sys.exit(f"ERROR: no such master: {args.src}")
    for path in make_facings(args.src, args.out_dir, args.stem):
        print(f"wrote {path}")
    print("aliases: " + ", ".join(f"{k}->{v}" for k, v in FACING_ALIASES.items()))


if __name__ == "__main__":
    main()
