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
  tol   = cutout.py background tolerance (default 22); raise for soft ground shadows.
  accent_sat = palette-lock accent saturation gate (default 0.25); raise to stop browns
          turning orange.
  flatten = true to remove a gradient/vignette background before cutout.
  clean = true when raw is already a cut-out sprite at shipped size (converting approved
          smooth art); skips cutout and resize.
  smooth = median pre-filter size (default 7); lower (3) keeps thin frames, e.g. Sniper.
  keep_accent = cell share of accent (e.g. 0.25) that keeps thin neon trim in pixelize.
  lock  = false to skip palette_lock (art already on the house palette).
  touches = hand-placed pixel details on the finished sprite — see apply_touches().
  crop  = optional fraction trimmed off every edge of the raw before cutout (frames).
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


def palette_lock(im: Image.Image, structure: bool = False,
                 accent_sat: float = ACCENT_SAT_MIN) -> Image.Image:
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
    # accent_sat: raise it (manifest `accent_sat`, e.g. 0.5) when a render's browns and
    # rust shadows are being promoted to faction orange — at recolor's 0.25 they are,
    # and the unit floods orange with no grey/orange split (Order Knight, 2026-09-30).
    accent = warm & (s >= accent_sat) & (v >= ACCENT_VAL_MIN)
    h2 = np.where(accent, RUSH_HUE, SLATE_HUE)
    s2 = np.where(accent, np.clip(s * 1.15, 0.65, 1.0), SLATE_SAT * np.clip(v * 1.4, 0.4, 1.0))
    # Lift accent value: renders shade the trim so dark that the anchor hue reads
    # red-brown, not the Trooper's orange. Armour value is untouched.
    v2 = np.where(accent, 0.55 + 0.45 * v, v)
    if structure:
        # Art bible §5.1: "the stage is dark so the actors can be light" — structures
        # stay near-black #1B2130 (v .19) with facets lifted to #33405A (v .35). SDXL
        # paints gothic stone pale, so compress plating value into that band.
        v2 = np.where(accent, v2, 0.12 + 0.26 * v)
    a[..., :3] = np.clip(_from_hsv(h2, s2, v2) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def flatten_background(path: str, out: str, band: float = 0.03) -> str:
    """Remove a smooth background gradient so cutout.py's single-tolerance fill can key it.

    cutout.py warns that gradient backgrounds defeat it, and SDXL paints them often
    (vignettes, light-to-dark studio sweeps — Aegis Walker 2026-09-29 kept its whole
    backdrop). Fits a quadratic surface per channel to the border band, rejecting
    outliers twice (the subject may touch the edge), then subtracts the surface and adds
    back its mean: the field becomes one flat colour, the subject shifts by the same
    small smooth amount and is otherwise untouched.
    """
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    x, y = xx / w - 0.5, yy / h - 0.5
    basis = np.stack([np.ones_like(x), x, y, x * x, y * y, x * y], axis=-1)
    b = max(2, int(min(h, w) * band))
    edge = np.zeros((h, w), bool)
    edge[:b], edge[-b:], edge[:, :b], edge[:, -b:] = True, True, True, True
    out_img = a.copy()
    for ch in range(3):
        keep = edge.copy()
        for _ in range(3):
            coef, *_ = np.linalg.lstsq(basis[keep], a[..., ch][keep], rcond=None)
            fit = basis @ coef
            resid = np.abs(a[..., ch] - fit)
            keep = edge & (resid < max(6.0, 2.0 * resid[keep].std()))
        out_img[..., ch] = a[..., ch] - fit + fit[edge].mean()
    Image.fromarray(np.clip(out_img + 0.5, 0, 255).astype(np.uint8)).save(out)
    return out


# Pixel touches: rush accent at full brightness (hue matches RUSH_HUE) and a bone white
# that sits under recolor's saturation gate, so it survives every hue unchanged.
TOUCH_ACCENT = (255, 110, 38)
TOUCH_BONE = (222, 214, 196)
GROUND_RGB = (46, 54, 72)  # dark slate: reads as shadow on the #232A38 floor


def apply_touches(px: Image.Image, touches: dict | None, mask: bool = False,
                  ref: Image.Image | None = None) -> Image.Image:
    """Paint hand-placed details onto a FINISHED pixel sprite, on the art grid.

    Why: at ~35 art px tall, ornament in the render (engraving, sigils) averages away in
    pixelize — ornate prompts were tried and lost (2026-09-30). Pixel art is authored at
    the grid, so detail that must read is placed there, per pixel. Coordinates are art
    pixels on the final canvas (print the grid to pick them). This is NOT the rejected
    "composite geometry onto the smooth render" approach (.agent/notes.md): nothing is
    scaled after placement, so a 1-px feature stays exactly 1 px.

    touches = {"headroom": n,                   # empty art rows added on top (room for a halo)
               "halo": [cx, cy, rx, ry],        # accent ring, only on EMPTY cells = behind
               "bone": [[x, y], ...],           # pale detail pixels, drawn over the body
               "accent": [[x, y], ...],         # extra faction-colour pixels
               "ground_rows": [y, ...]}         # warm cells in these rows -> shadow
    mask=True paints the halo/accent cells into a glow mask (they emit); pass the
    untouched sprite as `ref` so "empty" is judged on the sprite, not on the mask.
    """
    if not touches:
        return px
    head = int(touches.get("headroom", 0)) * FACTOR
    if head:
        # Empty rows added on TOP only, so bottom-centre (the ground contact) is unmoved.
        # Sprite, mask and ref all get the same rows, so the halo coordinates below are
        # on the padded grid for all three.
        def _pad(im: Image.Image) -> Image.Image:
            out = Image.new(im.mode, (im.width, im.height + head))
            out.paste(im, (0, head))
            return out
        px = _pad(px)
        ref = _pad(ref) if ref is not None else None
    sprite = np.asarray(ref if ref is not None else px)
    empty = sprite[::FACTOR, ::FACTOR, 3] == 0
    grid = np.asarray(px)[::FACTOR, ::FACTOR].copy()
    gh, gw = empty.shape
    cells: list[tuple[int, int, tuple]] = []
    if "halo" in touches:
        cx, cy, rx, ry = touches["halo"]
        yy, xx = np.mgrid[0:gh, 0:gw]
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        inner = (1 - 1.0 / max(rx, ry)) ** 2 * 0.72  # ~1-cell-thick ring
        for y, x in zip(*np.nonzero((d <= 1.0) & (d >= inner) & empty)):
            cells.append((int(x), int(y), TOUCH_ACCENT))
    cells += [(x, y, TOUCH_ACCENT) for x, y in touches.get("accent", [])]
    if not mask:
        cells += [(x, y, TOUCH_BONE) for x, y in touches.get("bone", [])]
    for x, y, col in cells:
        if 0 <= x < gw and 0 <= y < gh:
            grid[y, x] = 255 if mask else (*col, 255)
    # ground_rows: a render's ground shadow tinted warm gets read as trim and becomes a
    # faction-coloured puddle under the feet (Inquisitor, 2026-09-30). Rows are on the
    # final (post-headroom) grid; their warm cells turn dark slate and stop emitting.
    rows = [r for r in touches.get("ground_rows", []) if 0 <= r < gh]
    if rows:
        s = sprite[::FACTOR, ::FACTOR].astype(int)
        warm = (s[..., 0] > 150) & (s[..., 0] > s[..., 2] + 60) & (s[..., 3] > 0)
        for r in rows:
            for x in np.nonzero(warm[r])[0]:
                grid[r, x] = 0 if mask else (*GROUND_RGB, 255)
    return Image.fromarray(grid.repeat(FACTOR, 0).repeat(FACTOR, 1), px.mode)

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
    if asset.get("crop"):
        # SDXL sometimes draws a picture frame / inset panel round the subject. The
        # border flood fill then stops at the frame line and keys nothing. Cropping a
        # fraction off every edge removes the frame so the fill starts on the panel.
        c = float(asset["crop"])
        r = Image.open(raw)
        w, h = r.size
        raw = _tmp(r.crop((int(w * c), int(h * c), int(w * (1 - c)), int(h * (1 - c)))),
                   tmp, f"{aid}_cropped.png")
    if asset.get("flatten"):
        raw = flatten_background(raw, os.path.join(tmp, f"{aid}_flat.png"))
    if asset.get("clean"):
        # Already an approved RGBA cutout at shipped size (the pre-pivot smooth art):
        # no keying, no resize — re-keying a transparent image eats dark armour.
        im = Image.open(raw).convert("RGBA")
    else:
        im, _ = cutout(raw, tol=int(asset.get("tol", 22)), largest_only=True)
        im = _fit(trim(im), asset["axis"], asset["px"])
    master = im if asset.get("lock") is False else palette_lock(
        im, structure=asset["kind"] == "struct",
        accent_sat=float(asset.get("accent_sat", ACCENT_SAT_MIN)))
    clean_path = os.path.join(CLEANED, f"{aid}_rush_hd2d_clean.png")
    if not dry:
        master.save(clean_path)
    src = _tmp(master, tmp, f"{aid}_rush.png")
    touches = asset.get("touches")
    px_opts = {"keep_accent": float(asset.get("keep_accent", 0)), "smooth": int(asset.get("smooth", 7))}
    relock = asset.get("lock") is not False
    accent_sat = float(asset.get("accent_sat", ACCENT_SAT_MIN))

    def _pixel(img: Image.Image) -> Image.Image:
        # Re-lock AFTER pixelize: median-cut palette entries can average orange with
        # grey into faint warm colours (sat .25-.45) that the test does not count as
        # accent in rush but that recolor lifts over the line in boom — bomber rush
        # 32.6% vs boom 36.6%, over the 3-point limit (2026-09-30). Per-pixel, so the
        # grid is untouched; value is kept (structure=False: no second darkening).
        out = pixelize(img, FACTOR, **px_opts)
        if not relock:
            return out
        # Keep the outline ink exact: the lock re-hues it to (20,20,22), which is
        # invisible but breaks anything that looks for OUTLINE_RGB (grid printers).
        a = np.asarray(out)
        ink = np.all(a[..., :3] == OUTLINE_RGB, axis=-1) & (a[..., 3] > 0)
        locked = np.asarray(palette_lock(out, accent_sat=accent_sat)).copy()
        locked[ink] = (*OUTLINE_RGB, 255)
        return Image.fromarray(locked, "RGBA")
    if asset.get("promote"):
        # The goal is coverage of the FINAL pixel sprite: the outline ring and edge
        # cells cost ~8-12 points versus the smooth master (Knight: 44% smooth -> 33%
        # pixel), so step the smooth target up until the pixelized result clears it.
        goal = float(asset["promote"])
        for smooth_target in range(int(goal) - 8, 76, 1):
            promoted = os.path.join(tmp, f"{aid}_rush_promoted_{smooth_target}.png")
            subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "promote_accent.py"),
                            src, promoted, "--target", str(smooth_target)], check=True,
                           stdout=subprocess.DEVNULL)
            cand = promoted if os.path.exists(promoted) else src  # no file = already above
            final = apply_touches(_pixel(Image.open(cand)), touches)
            if kind == "air":  # the shadow counts as body in the test, so measure with it
                final = _with_air_shadow(final)
            if coverage(final) >= goal:
                break
        src = cand
        master = Image.open(src).convert("RGBA")

    written: list[str] = []
    is_struct = kind == "struct"
    out_dir = STRUCTS if is_struct else UNITS
    report = []
    bare_px = _pixel(master)
    rush_px = apply_touches(bare_px, touches)
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

    glow = apply_touches(pixelize_mask(glow_mask(src)[0], FACTOR), touches, mask=True, ref=bare_px)
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
