#!/usr/bin/env python3
"""Derive the `destroyed` (powered-down) texture from an approved sprite.

    python3 tools/asset-pipeline/state_variant.py            # write the VS set
    python3 tools/asset-pipeline/state_variant.py --dry-run

§8.5 LOCKS destroyed as a "short power-down/collapse beat, 2-4 frames --
functional shutdown matching §5.4's restraint; no gibs/explosions, keeping loss
dignified". A shutdown is a *lighting* change, not a new body pose: the machine
stops emitting and its faction colour goes cold. So the end-state texture is
derivable from the live sprite, and the 2-4 frames are a cross-fade from live to
this, with the §8.9 `pulse_intensity` uniform driven to zero over the same beat.

What the transform does, and why:
  - Faction accent is desaturated toward neutral but NOT to zero. A wreck should
    still read as *whose* wreck it was -- that is board information during the
    turn it sits there -- and killing the hue entirely would also collide with
    the achromatic Neutral faction.
  - The whole sprite is darkened. Powered-down plating on a dark stage should
    recede toward the terrain, which is the visual opposite of §3.5's "units are
    the hero shapes that own the eye" -- correct, because a wreck is no longer an
    actor the player must attend to.
  - The glow mask is untouched and simply unused: the shader holds
    `pulse_intensity` at 0 for a destroyed unit. No separate dark mask is needed.

Deliberately NOT done here: collapse geometry (a slump or fall). That is a
transform the renderer applies, not a texture -- and our generator cannot author
a consistent second pose anyway (see the Facings note in the spec).
"""

from __future__ import annotations

import argparse
import os
import sys

try:
    import numpy as np
except ImportError:
    sys.exit("ERROR: state_variant.py needs numpy + Pillow")

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recolor import _from_hsv, _hsv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "assets", "art")

SAT_KEEP = 0.30   # how much faction hue survives on a wreck
DARKEN = 0.55     # powered-down plating recedes toward the stage


def destroyed(path: str, sat_keep: float = SAT_KEEP,
              darken: float = DARKEN) -> Image.Image:
    a = np.array(Image.open(path).convert("RGBA"))
    rgb = a[:, :, :3].astype(np.float64) / 255.0
    h, s, v = _hsv(rgb)
    out = _from_hsv(h, s * sat_keep, v * darken)
    res = a.copy()
    res[:, :, :3] = np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def _targets() -> list[tuple[str, str]]:
    jobs = []
    for a in ("builder", "scout", "trooper", "heavy", "sniper"):
        for hue in ("rush", "boom", "neutral"):
            for f in ("e", "w"):
                jobs.append((os.path.join(ART, "units",
                                          f"unit_{a}_{hue}_{f}_idle_01.png"),
                             os.path.join(ART, "units",
                                          f"unit_{a}_{hue}_{f}_destroyed_01.png")))
    for n in ("hq", "barracks", "factory", "defensive_structure", "research_lab"):
        for hue in ("rush", "boom", "neutral"):
            jobs.append((os.path.join(ART, "structures", f"struct_{n}_{hue}_idle.png"),
                         os.path.join(ART, "structures",
                                      f"struct_{n}_{hue}_destroyed.png")))
    return jobs


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    n = 0
    for src, dst in _targets():
        if not os.path.exists(src):
            print(f"WARN missing sprite: {src}", file=sys.stderr)
            continue
        img = destroyed(src)
        if not args.dry_run:
            img.save(dst)
        print(f"{os.path.relpath(dst, ROOT)}")
        n += 1
    print(f"\n{'would write' if args.dry_run else 'wrote'} {n} destroyed-state textures")


if __name__ == "__main__":
    main()
