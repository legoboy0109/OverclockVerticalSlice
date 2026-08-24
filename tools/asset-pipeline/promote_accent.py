#!/usr/bin/env python3
"""Raise a unit's faction-accent coverage by GROWING its existing accent regions.

    python3 tools/asset-pipeline/promote_accent.py <src.png> <dst.png> --target 45
    python3 tools/asset-pipeline/promote_accent.py <src.png> --measure

WHY THIS EXISTS
---------------
S5-03 (the Pillar-3 iso-legibility gate) measured ownership as unreadable on the
Sniper: 13.3% of its body carried faction hue against a roster mean of 50.1%,
giving a faction separation of dE76 12.9 -- below the point where two colours are
reliably told apart, before distance or colourblindness are considered.

The cause is not hue choice; every unit uses the same locked anchors. The cause is
COVERAGE. The same gate measured that a unit's neon accent clears the contrast bar
(4.26-7.17:1) while its dark chassis never does (1.80-2.46:1), so the accent does
100% of the legibility work and its AREA is the unit's legibility. Heavy 69%,
Scout 52%, Trooper 45%, Sniper 15%.

THE APPROACH, AND TWO THAT FAILED FIRST
---------------------------------------
This grows the accent OUTWARD from where it already is, by repeated dilation
constrained to adjacent plate, until the coverage target is met.

That choice matters more than it looks. Two earlier attempts produced measurably
correct coverage and unusable art:

  1. Brightest-N pixels. Selecting plate pixels by value until the target was hit
     cut ACROSS panels -- taking the lit half of many and leaving the shadowed
     half -- and read as orange speckle scattered over grey armour.

  2. Value-banded connected components. Quantising value before labelling split
     smoothly-shaded panels into stripes, and promoting some stripes and not
     others produced a corduroy artefact.

Growth works because it does not invent a composition. The artist already decided
WHERE this unit's accent belongs; dilation only decides HOW FAR it extends, so the
result reads as a bolder version of the same design rather than a different one.
It also cannot speckle: every added pixel is adjacent to accent already there.

RULES INHERITED FROM recolor.py, BOTH LEARNED THE HARD WAY
-----------------------------------------------------------
1. Scale, never flat-fill. The grown region's value range is REMAPPED onto the
   accent's working band, so the plate's existing light direction and form survive.
   A flat fill reads as a sticker at board scale (recolor.py note 24).
2. Operate on the rush master ONLY. boom and neutral are DERIVED by recolor.py,
   so editing them directly desynchronises the faction set. Run this first, then
   re-derive, then re-place, then regenerate glow and destroyed variants.
"""
import argparse
import colorsys
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

# Matches recolor.py's accent window exactly, so "coverage" means one thing across
# the pipeline and across the S5-03 measurement.
ACCENT_HUE_MAX = 45.0
ACCENT_HUE_WRAP_MIN = 335.0
ACCENT_SAT_MIN = 0.25
ACCENT_VAL_MIN = 0.10

ALPHA_BODY = 40

# Growth may only enter near-neutral plate above the shadow band. The darkest
# plate is left alone deliberately: on every unit that reads correctly the
# non-accent pixels are the shadow band (mean value 0.27-0.32), and keeping it
# intact is what preserves the unit's form instead of flattening it to one colour.
SHADOW_CEILING = 0.22

# Tone for grown area. Chosen by rendering muted/mid/vivid candidates at the real
# shipping size (99x156) on the real stage colour and comparing -- not at master
# resolution, where every option looks fine. Mid keeps the grey structural
# contrast that gives the silhouette its internal form; vivid starts to flatten
# the unit into a single orange mass.
GROWN_SAT = 0.72
GROWN_VAL_LO = 0.42
GROWN_VAL_HI = 0.86

MAX_ITERATIONS = 400


def _hsv_arrays(rgb):
    out = np.array([colorsys.rgb_to_hsv(*(c / 255.0)) for c in rgb])
    return out[:, 0] * 360.0, out[:, 1], out[:, 2]


def _masks(img):
    """Returns (body, accent, plate, hue_median) as 2-D masks."""
    body = img[..., 3] > ALPHA_BODY
    rgb = img[..., :3]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    val = mx / 255.0
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-9), 0.0)

    hue = np.zeros(body.shape)
    ys, xs = np.where(body)
    hue[ys, xs] = _hsv_arrays(rgb[ys, xs])[0]

    accent = body & (sat >= ACCENT_SAT_MIN) & (val >= ACCENT_VAL_MIN) & \
             ((hue <= ACCENT_HUE_MAX) | (hue >= ACCENT_HUE_WRAP_MIN))
    plate = body & (~accent) & (val > SHADOW_CEILING) & (sat < ACCENT_SAT_MIN)
    hue_med = float(np.median(hue[accent])) if accent.any() else 20.0
    return body, accent, plate, hue_med, val, sat


def measure(path):
    img = np.asarray(Image.open(path).convert("RGBA"), dtype=float)
    body, accent, _, hue_med, _, sat = _masks(img)
    return {
        "body": int(body.sum()),
        "accent": int(accent.sum()),
        "coverage": 100.0 * accent.sum() / max(body.sum(), 1),
        "hue": hue_med,
        "sat": float(sat[accent].mean()) if accent.any() else 0.0,
    }


def promote(src, dst, target_pct, dry_run=False):
    img = np.asarray(Image.open(src).convert("RGBA"), dtype=float).copy()
    body, accent, plate, hue_med, val, sat = _masks(img)

    n_body = int(body.sum())
    target = target_pct / 100.0 * n_body
    print(f"  body {n_body} px · accent {int(accent.sum())} "
          f"({100*accent.sum()/n_body:.1f}%) · target {target_pct:.0f}%")

    if accent.sum() >= target:
        print("  already at or above target — nothing to do.")
        return False
    if not plate.any():
        print("  !! no promotable plate adjacent to accent", file=sys.stderr)
        return False

    grown = accent.copy()
    iterations = 0
    structure = np.ones((3, 3), dtype=bool)
    while grown.sum() < target and iterations < MAX_ITERATIONS:
        nxt = grown | (ndimage.binary_dilation(grown, structure=structure) & plate)
        if nxt.sum() == grown.sum():
            print(f"  growth exhausted at {100*grown.sum()/n_body:.1f}% "
                  f"— no plate left adjacent to accent")
            break
        grown = nxt
        iterations += 1

    added = grown & ~accent
    coverage = 100.0 * grown.sum() / n_body
    print(f"  grew {iterations} rings, +{int(added.sum())} px → {coverage:.1f}%")

    if dry_run:
        print("  [dry-run] not written")
        return False

    # Remap the grown band's value range onto the accent working band (rule 1),
    # then recolour to the unit's own median accent hue -- read from the sprite,
    # never hardcoded, so this stays correct if the palette anchor ever moves.
    ys, xs = np.where(added)
    tv = val[ys, xs]
    lo, hi = float(tv.min()), float(tv.max())
    span = max(hi - lo, 1e-6)
    new_v = GROWN_VAL_LO + (tv - lo) / span * (GROWN_VAL_HI - GROWN_VAL_LO)
    ts = sat[ys, xs]
    new_s = np.clip(GROWN_SAT + (ts - ts.mean()) * 0.5, 0.35, 0.97)

    img[ys, xs, :3] = np.array([
        colorsys.hsv_to_rgb(hue_med / 360.0, float(a), float(b))
        for a, b in zip(new_s, new_v)
    ]) * 255.0

    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    Image.fromarray(img.astype(np.uint8), "RGBA").save(dst)
    after = measure(dst)
    print(f"  wrote {dst} — coverage {after['coverage']:.1f}%, "
          f"hue {after['hue']:.0f}°, sat {after['sat']:.2f}")
    return True


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--target", type=float, default=45.0,
                    help="accent coverage %% to reach (default 45 — the Trooper, "
                         "which the art bible names as the roster's baseline)")
    ap.add_argument("--measure", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    if a.measure:
        m = measure(a.src)
        print(f"{os.path.basename(a.src)}: {m['coverage']:.1f}% accent "
              f"({m['accent']}/{m['body']} px), hue {m['hue']:.0f}°, sat {m['sat']:.2f}")
        return
    if not a.dst:
        ap.error("dst required unless --measure")
    promote(a.src, a.dst, a.target, a.dry_run)


if __name__ == "__main__":
    main()
