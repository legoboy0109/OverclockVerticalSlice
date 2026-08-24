#!/usr/bin/env python3
"""S5-03 legibility measurements — the mechanical half of the Pillar-3 gate.

Runs the art bible's OWN stated tests against the shipped art and the captured
frames, so the pass/fail is against this project's rules rather than a generic
accessibility heuristic:

  P1 (Silhouette First)  -- archetypes identifiable by outline alone, in grayscale,
                            at the shipping isometric angle.
  P2 (Ownership Beyond   -- ownership legible when hue is degraded or removed.
      Hue)
  §4.2 stage contrast    -- actors clear the stage at the values S4-01 locked.

Everything here is measurement. The naive-observer half of S5-03 is a human's job.
"""
import sys, glob, os, math
import numpy as np
from PIL import Image

ART = "assets/art/units"
FRAMES = "production/qa/evidence/s5-03-legibility"
ARCHETYPES = ["scout", "trooper", "heavy", "sniper"]
FACTIONS = ["rush", "boom"]

def load_rgba(p):
    return np.asarray(Image.open(p).convert("RGBA"), dtype=np.float64)

def srgb_to_lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def luminance(rgb):
    lin = srgb_to_lin(rgb)
    return 0.2126*lin[...,0] + 0.7152*lin[...,1] + 0.0722*lin[...,2]

def rgb_to_lab(rgb):
    lin = srgb_to_lin(np.asarray(rgb, dtype=np.float64))
    m = np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz = lin @ m.T
    white = np.array([0.95047,1.0,1.08883])
    t = xyz / white
    d = 6/29
    f = np.where(t > d**3, np.cbrt(t), t/(3*d*d) + 4/29)
    return np.stack([116*f[...,1]-16, 500*(f[...,0]-f[...,1]), 200*(f[...,1]-f[...,2])], axis=-1)

def delta_e76(a, b):
    return float(np.sqrt(((rgb_to_lab(a) - rgb_to_lab(b))**2).sum()))

def contrast_ratio(rgb_a, rgb_b):
    la, lb = float(luminance(np.array(rgb_a))), float(luminance(np.array(rgb_b)))
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

# ---------------------------------------------------------------- silhouettes
def silhouette(path, alpha_thresh=40):
    """Binary mask, trimmed to its bounding box and normalised to a common canvas
    -- the art bible's test is about SHAPE, so absolute canvas position must not
    influence the comparison."""
    img = load_rgba(path)
    mask = img[..., 3] > alpha_thresh
    if not mask.any():
        return None, (0, 0)
    ys, xs = np.where(mask)
    crop = mask[ys.min():ys.max()+1, xs.min():xs.max()+1]
    h, w = crop.shape
    return crop, (w, h)

def resize_mask(mask, size=(96, 96)):
    return np.asarray(Image.fromarray((mask*255).astype(np.uint8)).resize(size, Image.NEAREST)) > 127

def iou(a, b):
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return float(inter) / float(union) if union else 1.0

print("=" * 78)
print("S5-03 — ISO-LEGIBILITY GATE, MECHANICAL MEASUREMENTS")
print("=" * 78)

# --- TEST 1: archetype silhouette distinctness (art bible P1) ---------------
print("\n[TEST 1] P1 Silhouette First — archetypes distinct by OUTLINE ALONE")
print("         Method: alpha -> binary mask, bbox-trimmed, scale-normalised, IoU.")
print("         Lower IoU = more distinct. Shape-only: colour plays no part.\n")

sil, dims = {}, {}
for a in ARCHETYPES:
    p = f"{ART}/unit_{a}_neutral_e_idle_01.png"
    if not os.path.exists(p):
        print(f"  !! missing {p}"); continue
    m, (w, h) = silhouette(p)
    sil[a] = resize_mask(m)
    dims[a] = (w, h, m.sum())

print("  Raw silhouette geometry (before normalisation):")
print(f"    {'archetype':<10} {'w':>4} {'h':>4} {'aspect w/h':>11} {'filled px':>10}")
for a in ARCHETYPES:
    if a in dims:
        w, h, f = dims[a]
        print(f"    {a:<10} {w:>4} {h:>4} {w/h:>11.2f} {int(f):>10}")

print("\n  Pairwise IoU (shape overlap after scale-normalising):")
worst, worst_pair = 0.0, None
names = [a for a in ARCHETYPES if a in sil]
for i, a in enumerate(names):
    for b in names[i+1:]:
        v = iou(sil[a], sil[b])
        flag = "  <-- WORST" if v > worst else ""
        if v > worst: worst, worst_pair = v, (a, b)
        print(f"    {a:>8} vs {b:<8}  IoU {v:.3f}")
print(f"\n  Most-confusable pair: {worst_pair[0]} / {worst_pair[1]} at IoU {worst:.3f}")

# --- TEST 2: aspect-ratio separation (art bible's own stated primary read) ---
print("\n[TEST 2] The bible's stated primary read: Scout LOW+HORIZONTAL vs")
print("         Sniper TALL+VERTICAL — 'aspect ratio alone tells them apart'.\n")
if "scout" in dims and "sniper" in dims:
    sw, sh, _ = dims["scout"]; nw, nh, _ = dims["sniper"]
    print(f"    scout  aspect {sw/sh:.2f}  ({sw}x{sh})")
    print(f"    sniper aspect {nw/nh:.2f}  ({nw}x{nh})")
    ratio = (sw/sh) / (nw/nh)
    print(f"    separation factor: {ratio:.2f}x  ({'PASS' if ratio >= 1.25 or ratio <= 0.8 else 'WEAK'})")

# --- TEST 3: faction hue coverage per archetype (P2 exposure) ---------------
print("\n[TEST 3] P2 Ownership — how much of each archetype actually CARRIES hue.")
print("         Ownership is hue-only in shipped art (S5-08), so a unit with little")
print("         saturated area has little ownership signal, regardless of ΔE.\n")
print(f"    {'archetype':<10} {'faction':<7} {'body px':>9} {'saturated':>10} {'% of body':>10}")
cov = {}
for a in ARCHETYPES:
    for f in FACTIONS:
        p = f"{ART}/unit_{a}_{f}_e_idle_01.png"
        if not os.path.exists(p): continue
        img = load_rgba(p)
        body = img[..., 3] > 40
        rgb = img[..., :3]
        mx = rgb.max(axis=-1); mn = rgb.min(axis=-1)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-9), 0.0)
        strong = body & (sat > 0.45) & (mx > 60)
        pct = 100.0 * strong.sum() / max(body.sum(), 1)
        cov[(a, f)] = pct
        print(f"    {a:<10} {f:<7} {int(body.sum()):>9} {int(strong.sum()):>10} {pct:>9.1f}%")

print("\n    Per-archetype mean hue coverage (ownership signal strength):")
means = {a: np.mean([cov[(a,f)] for f in FACTIONS if (a,f) in cov]) for a in ARCHETYPES if any((a,f) in cov for f in FACTIONS)}
for a, v in sorted(means.items(), key=lambda kv: kv[1]):
    bar = "#" * int(v / 1.5)
    print(f"      {a:<10} {v:>5.1f}%  {bar}")
if means:
    lo = min(means, key=means.get); hi = max(means, key=means.get)
    print(f"\n    Spread: {lo} ({means[lo]:.1f}%) to {hi} ({means[hi]:.1f}%)"
          f" — {means[hi]/max(means[lo],1e-9):.1f}x difference in ownership signal.")

# --- TEST 4: faction separation + full desaturation (P2's actual claim) -----
print("\n[TEST 4] P2 — does ownership survive FULL DESATURATION?")
print("         The art bible mandates a non-hue backup. S5-08 measured it absent.")
print("         Method: mean body colour per faction, then the same in grayscale.\n")
for a in ARCHETYPES:
    cols = {}
    for f in FACTIONS:
        p = f"{ART}/unit_{a}_{f}_e_idle_01.png"
        if not os.path.exists(p): continue
        img = load_rgba(p)
        body = img[..., 3] > 40
        cols[f] = img[..., :3][body].mean(axis=0)
    if len(cols) == 2:
        r, b = cols["rush"], cols["boom"]
        de = delta_e76(r, b)
        gr = 0.2126*r[0] + 0.7152*r[1] + 0.0722*r[2]
        gb = 0.2126*b[0] + 0.7152*b[1] + 0.0722*b[2]
        gray_delta = abs(gr - gb)
        verdict = "PASS" if gray_delta >= 26 else ("MARGINAL" if gray_delta >= 13 else "FAIL")
        print(f"    {a:<10} colour ΔE76 {de:>6.1f}   |  grayscale Δ {gray_delta:>5.1f}/255  -> {verdict}")
print("\n    (Grayscale Δ thresholds: >=26 distinguishable, 13-26 marginal, <13 indistinguishable.)")

# --- TEST 5: actor vs stage contrast in the CAPTURED frames ----------------
print("\n[TEST 5] §4.2 stage contrast — measured in the real captured frames,")
print("         not from swatches. Stage = modal background; actors = saturated px.\n")
for fp in sorted(glob.glob(f"{FRAMES}/*.png")):
    img = np.asarray(Image.open(fp).convert("RGB"), dtype=np.float64)
    flat = img.reshape(-1, 3)
    mx = flat.max(axis=1); mn = flat.min(axis=1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-9), 0.0)
    actors = flat[(sat > 0.45) & (mx > 60)]
    stage = flat[(sat < 0.30) & (mx < 120)]
    if len(actors) == 0 or len(stage) == 0:
        print(f"    {os.path.basename(fp):<34} (insufficient sample)"); continue
    a_mean = actors.mean(axis=0); s_mean = stage.mean(axis=0)
    cr = contrast_ratio(a_mean, s_mean)
    de = delta_e76(a_mean, s_mean)
    ga = 0.2126*a_mean[0]+0.7152*a_mean[1]+0.0722*a_mean[2]
    gs = 0.2126*s_mean[0]+0.7152*s_mean[1]+0.0722*s_mean[2]
    pct_actor = 100.0 * len(actors) / len(flat)
    print(f"    {os.path.basename(fp):<34} contrast {cr:>5.2f}:1  ΔE {de:>5.1f}  "
          f"grayΔ {abs(ga-gs):>5.1f}  actors {pct_actor:>4.1f}% of frame")
print("\n    (WCAG AA large-text bar is 3.0:1; S4-01 locked the stage at 5.19:1 worst case.)")

# --- TEST 6: act-state separation under crowding ---------------------------
print("\n[TEST 6] Pillar-1 read under crowding — actionable vs spent, measured on")
print("         the dense board rather than an isolated pair.\n")
pairs = [("01-dense-all-actionable", "03-dense-all-spent")]
for a_name, b_name in pairs:
    pa, pb = f"{FRAMES}/{a_name}.png", f"{FRAMES}/{b_name}.png"
    if not (os.path.exists(pa) and os.path.exists(pb)): continue
    ia = np.asarray(Image.open(pa).convert("RGB"), dtype=np.float64)
    ib = np.asarray(Image.open(pb).convert("RGB"), dtype=np.float64)
    diff = np.abs(ia - ib).mean(axis=2)
    changed = diff > 8
    la, lb = luminance(ia), luminance(ib)
    print(f"    pixels visibly changed : {100.0*changed.sum()/changed.size:>5.2f}% of frame")
    if changed.any():
        print(f"    mean luminance (changed px): actionable {la[changed].mean():.4f} -> spent {lb[changed].mean():.4f}")
        ratio = (la[changed].mean() + 0.05) / (lb[changed].mean() + 0.05)
        print(f"    act-state luminance ratio  : {ratio:.2f}:1")
print()
print("=" * 78)
