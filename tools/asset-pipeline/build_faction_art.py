#!/usr/bin/env python3
"""Build a faction's runtime HD-2D sprites from its approved raw generations.

    python3 tools/asset-pipeline/build_faction_art.py art-source/factions/order/manifest.json
    python3 tools/asset-pipeline/build_faction_art.py <manifest> --only levy,knight --dry-run

The per-faction successor to the VS-era chain (cutout -> recolor -> glow_mask ->
state_variant -> make_facings -> place_runtime), which hard-codes the original roster.
One manifest per faction lists each asset once; this runs the whole chain and adds the
HD-2D step (pixelize.py) at the end.

Manifest (JSON):
    {"assets": [
      {"id": "levy",      "kind": "unit",   "raw": "art-source/generated/.../levy_3.png", "axis": "h", "px": 124},
      {"id": "seraph",    "kind": "air",    "raw": "...", "axis": "w", "px": 120},
      {"id": "cathedral", "kind": "struct", "raw": "...", "axis": "w", "px": 256}
    ]}
  id    = the art token: the vault note's `id` (EntitySpriteCatalog.type_token_for).
  axis  = which dimension `px` pins (h for upright infantry, w for long/low shapes).
  kind  = unit | air | struct. `air` is drawn high over a ground shadow, like the
          placeholders (make_placeholder_sprites.py): the renderer anchors bottom-centre,
          so the shadow is the ground contact and the gap above it is the height cue.
  promote = optional accent-coverage target (%) passed to promote_accent.py when the
          generated accent is too thin for tests/unit/art/accent_coverage_test.gd.

★ ORDER OF OPERATIONS matters and is not arbitrary:
  pixelize ONCE (rush), then recolor the pixel sprite — the majority method leaves no
    blended edge colours for recolor's hue gate to miss, and every hue then shares one
    grid exactly. Pixelizing each hue separately let quantization diverge: rush/boom
    coverage differed by up to 8 points, over the test's 3-point limit.
  destroyed AFTER pixelize — it is a pure per-pixel HSV transform, so running it on the
    pixel sprite keeps the palette count and the grid intact.
  glow from the SMOOTH rush sprite, then pixelize_mask — glow_mask.py's edge band is
    2 smooth px wide, which is what reads as "trim" once box-averaged onto the grid.

Writes: art-source/cleaned/<id>_rush_hd2d_clean.png (smooth master, for re-runs) and
assets/art/{units,structures}/ runtime files named per assets/art/README.md.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cutout import cutout, trim  # noqa: E402
from glow_mask import glow_mask  # noqa: E402
from pixelize import OUTLINE_RGB, pixelize, pixelize_mask  # noqa: E402
from recolor import (ACCENT_HUE_MAX, ACCENT_HUE_WRAP_MIN, ACCENT_SAT_MIN,  # noqa: E402
                     ACCENT_VAL_MIN, _from_hsv, _hsv, recolor)
from state_variant import destroyed  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLEANED = os.path.join(ROOT, "art-source", "cleaned")
UNITS = os.path.join(ROOT, "assets", "art", "units")
STRUCTS = os.path.join(ROOT, "assets", "art", "structures")
HUES = ("rush", "boom", "neutral")
FACTOR = 4

# Aircraft: art-px gap between the craft's lowest pixel and its shadow. ~8 art px = 16
# screen px, the same lift the placeholders gave (their craft sat ~32 file px up).
AIR_LIFT_ART_PX = 8
SHADOW_ALPHA = 90  # >40 so accent_coverage_test counts it as body, matching placeholders


# Palette lock targets (art bible §5.1): slate armour #6E7C99 is hue ~221, sat ~0.28;
# the rush accent as SHIPPED sits at hue ~20.
SLATE_HUE, SLATE_SAT = 221.0, 0.26
# Measured, not the anchor's nominal ~13: the shipped roster's accent median is 19-21
# (Trooper 20.8, Heavy 19.1). At 13 the Order read visibly redder beside them.
RUSH_HUE = 20.0


def palette_lock(im: Image.Image) -> Image.Image:
    """Force a raw render onto the house palette: slate armour, rush-orange accent.

    SDXL paints "slate grey" as warm brown-grey and "orange" anywhere from red-brown to
    gold, so after accent growth a unit read as one orange-brown mass with none of the
    Trooper's grey/orange split (Order pilot, 2026-09-29). Value is kept, so shading and
    panel structure survive; only hue/saturation are replaced. Uses recolor.py's accent
    gate so the lock and the later hue swap agree on what counts as accent.
    """
    a = np.asarray(im.convert("RGBA")).copy()
    rgb = a[..., :3].astype(np.float64) / 255.0
    h, s, v = _hsv(rgb)
    warm = (h <= ACCENT_HUE_MAX) | (h >= ACCENT_HUE_WRAP_MIN)
    accent = warm & (s >= ACCENT_SAT_MIN) & (v >= ACCENT_VAL_MIN)
    h2 = np.where(accent, RUSH_HUE, SLATE_HUE)
    s2 = np.where(accent, np.clip(s * 1.15, 0.65, 1.0), SLATE_SAT * np.clip(v * 1.4, 0.4, 1.0))
    # Lift accent value: renders shade the trim so dark that the anchor hue reads
    # red-brown, not the Trooper's orange. Armour value is untouched.
    v2 = np.where(accent, 0.55 + 0.45 * v, v)
    a[..., :3] = np.clip(_from_hsv(h2, s2, v2) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def coverage(im: Image.Image) -> float:
    """Accent coverage %, exactly as tests/unit/art/accent_coverage_test.gd measures it."""
    a = np.asarray(im.convert("RGBA")).astype(np.float64)
    body = a[..., 3] > 40
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-9), 0)
    acc = body & (sat > 0.45) & (mx > 60 / 255)
    return 100.0 * acc.sum() / max(body.sum(), 1)


def _fit(im: Image.Image, axis: str, px: int) -> Image.Image:
    w, h = im.size
    s = px / (h if axis == "h" else w)
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


def _tmp(im: Image.Image, d: str, name: str) -> str:
    p = os.path.join(d, name)
    im.save(p)
    return p


def _with_air_shadow(sprite: Image.Image, mask: bool = False) -> Image.Image:
    """Lift a pixelized craft and put a pixel ellipse shadow under it.

    Same geometry for sprite and mask (mask=True just omits the shadow), so they stay
    aligned. All offsets are whole art pixels, so the grid is preserved.
    """
    w, h = sprite.size
    lift = AIR_LIFT_ART_PX * FACTOR
    sh_h = 4 * FACTOR
    mode = "L" if mask else "RGBA"
    out = Image.new(mode, (w, h + lift + sh_h))
    out.paste(sprite, (0, 0))
    if not mask:
        # Ellipse on the art grid, ~60% of craft width.
        gw, gh = w // FACTOR, 4
        yy, xx = np.mgrid[0:gh, 0:gw]
        cx, cy = (gw - 1) / 2, (gh - 1) / 2
        rx, ry = gw * 0.30, gh / 2
        ell = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0
        sh = np.zeros((gh, gw, 4), np.uint8)
        sh[ell] = (0, 0, 0, SHADOW_ALPHA)
        sh = sh.repeat(FACTOR, 0).repeat(FACTOR, 1)
        layer = Image.new("RGBA", out.size)
        layer.paste(Image.fromarray(sh, "RGBA"), (0, h + lift))
        out = Image.alpha_composite(layer, out)
    return out


def build(asset: dict, dry: bool, tmp: str) -> list[str]:
    aid, kind = asset["id"], asset["kind"]
    raw = os.path.join(ROOT, asset["raw"])
    im, _ = cutout(raw, largest_only=True)
    master = palette_lock(_fit(trim(im), asset["axis"], asset["px"]))
    clean_path = os.path.join(CLEANED, f"{aid}_rush_hd2d_clean.png")
    if not dry:
        master.save(clean_path)
    src = _tmp(master, tmp, f"{aid}_rush.png")
    if asset.get("promote"):
        # The goal is coverage of the FINAL pixel sprite: the outline ring and edge
        # cells cost ~8-12 points versus the smooth master (Knight: 44% smooth -> 33%
        # pixel), so step the smooth target up until the pixelized result clears it.
        goal = float(asset["promote"])
        for smooth_target in range(int(goal), 76, 3):
            promoted = os.path.join(tmp, f"{aid}_rush_promoted_{smooth_target}.png")
            subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "promote_accent.py"),
                            src, promoted, "--target", str(smooth_target)], check=True,
                           stdout=subprocess.DEVNULL)
            cand = promoted if os.path.exists(promoted) else src  # no file = already above
            if coverage(pixelize(Image.open(cand), FACTOR)) >= goal:
                break
        src = cand
        master = Image.open(src).convert("RGBA")

    written: list[str] = []
    is_struct = kind == "struct"
    out_dir = STRUCTS if is_struct else UNITS
    report = []
    rush_px = pixelize(master, FACTOR)
    rush_px_path = _tmp(rush_px, tmp, f"{aid}_rushpx_raw.png")
    for hue in HUES:
        px = rush_px if hue == "rush" else recolor(rush_px_path, hue)[0]
        if kind == "air":
            px = _with_air_shadow(px)
        pxp = _tmp(px, tmp, f"{aid}_{hue}_px.png")
        dead = destroyed(pxp)
        report.append(f"{hue} {coverage(px):.1f}%")
        if is_struct:
            files = {f"struct_{aid}_{hue}_idle.png": px, f"struct_{aid}_{hue}_destroyed.png": dead}
        else:
            files = {}
            for facing, img in (("e", px), ("w", px.transpose(Image.FLIP_LEFT_RIGHT))):
                d = dead if facing == "e" else dead.transpose(Image.FLIP_LEFT_RIGHT)
                files[f"unit_{aid}_{hue}_{facing}_idle_01.png"] = img
                files[f"unit_{aid}_{hue}_{facing}_destroyed_01.png"] = d
        for name, img in files.items():
            written.append(name)
            if not dry:
                img.save(os.path.join(out_dir, name))

    glow = pixelize_mask(glow_mask(src)[0], FACTOR)
    if kind == "air":
        glow = _with_air_shadow(glow, mask=True)
    if is_struct:
        gfiles = {f"struct_{aid}_idle_glow.png": glow}
    else:
        gfiles = {f"unit_{aid}_e_idle_01_glow.png": glow,
                  f"unit_{aid}_w_idle_01_glow.png": glow.transpose(Image.FLIP_LEFT_RIGHT)}
    for name, img in gfiles.items():
        written.append(name)
        if not dry:
            img.save(os.path.join(out_dir, name))
    size = Image.open(pxp).size
    print(f"{aid:22s} {size[0]}x{size[1]}  coverage: {', '.join(report)}  ({len(written)} files)")
    return written


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("manifest")
    p.add_argument("--only", default="", help="comma-separated ids")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    assets = json.load(open(args.manifest))["assets"]
    only = {s for s in args.only.split(",") if s}
    with tempfile.TemporaryDirectory() as tmp:
        for a in assets:
            if not only or a["id"] in only:
                build(a, args.dry_run, tmp)


if __name__ == "__main__":
    main()
