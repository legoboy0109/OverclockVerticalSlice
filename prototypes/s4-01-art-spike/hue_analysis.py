#!/usr/bin/env python3
"""S4-01 hue de-risk — analytic side-by-side for art-bible §4.2.

Boom's cyan (#22C7F0) sits in the same cool-blue hue neighborhood as the Dark Stage
family (§4.1), so the risk is that Boom units fail to "pop" against the board — worst
case on the LIGHTEST terrain tile (max-elevation #33405A). §4.2's claimed mitigation is
saturation + lightness distance, not hue distance. This script measures it.

Metrics per (actor, stage-tile) pair:
  - dHue / dS / dL   — HSL deltas (confirms hue-neighborhood vs S/L-distance mitigation)
  - contrast         — WCAG 2.x relative-luminance contrast ratio (bar: >= 4.5:1 = AA)
  - grayΔ            — perceptual-luma delta 0..255 (the §4.4 grayscale desaturation test)
  - ΔE2000           — CIEDE2000 perceptual distance (>10 = clearly distinct; >50 = far)

Run: python3 hue_analysis.py   (stdlib only)
"""
import colorsys
import math


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hsl(rgb):
    r, g, b = [c / 255 for c in rgb]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return (h * 360, s * 100, l * 100)


def _lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def rel_lum(rgb):
    r, g, b = rgb
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def gray(rgb):
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def rgb2lab(rgb):
    r, g, b = [_lin(c) for c in rgb]
    X = r * 0.4124 + g * 0.3576 + b * 0.1805
    Y = r * 0.2126 + g * 0.7152 + b * 0.0722
    Z = r * 0.0193 + g * 0.1192 + b * 0.9505
    X /= 0.95047
    Z /= 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(X), f(Y), f(Z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def ciede2000(l1, l2):
    L1, a1, b1 = l1
    L2, a2, b2 = l2
    avgLp = (L1 + L2) / 2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    avgC = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(avgC ** 7 / (avgC ** 7 + 25 ** 7))) if avgC > 0 else 0
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    avgCp = (C1p + C2p) / 2

    def hp(ap, b):
        if ap == 0 and b == 0:
            return 0
        h = math.degrees(math.atan2(b, ap))
        return h + 360 if h < 0 else h

    h1p, h2p = hp(a1p, b1), hp(a2p, b2)
    dLp, dCp = L2 - L1, C2p - C1p
    dhp = h2p - h1p
    if C1p * C2p == 0:
        dhp = 0
    elif dhp > 180:
        dhp -= 360
    elif dhp < -180:
        dhp += 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dhp / 2))
    if C1p * C2p != 0:
        if abs(h1p - h2p) > 180:
            avghp = (h1p + h2p + 360) / 2 if (h1p + h2p) < 360 else (h1p + h2p - 360) / 2
        else:
            avghp = (h1p + h2p) / 2
    else:
        avghp = h1p + h2p
    T = (1 - 0.17 * math.cos(math.radians(avghp - 30))
         + 0.24 * math.cos(math.radians(2 * avghp))
         + 0.32 * math.cos(math.radians(3 * avghp + 6))
         - 0.20 * math.cos(math.radians(4 * avghp - 63)))
    dtheta = 30 * math.exp(-((avghp - 275) / 25) ** 2)
    Rc = 2 * math.sqrt(avgCp ** 7 / (avgCp ** 7 + 25 ** 7))
    Sl = 1 + (0.015 * (avgLp - 50) ** 2) / math.sqrt(20 + (avgLp - 50) ** 2)
    Sc = 1 + 0.045 * avgCp
    Sh = 1 + 0.015 * avgCp * T
    Rt = -math.sin(math.radians(2 * dtheta)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2
                     + Rt * (dCp / Sc) * (dHp / Sh))


ACTORS = {"Boom cyan": "#22C7F0", "Rush orange": "#FF5A2E", "Neutral silver": "#C6CED8"}
STAGE = {
    "Void bg": "#0A0E17", "Terrain base": "#232A38",
    "Terrain ELEVATED(max)": "#33405A", "Terrain recessed": "#171C27",
    "Structure plate": "#1B2130",
}

if __name__ == "__main__":
    print("=== HSL of each color ===")
    for name, h in {**ACTORS, **STAGE}.items():
        H, S, L = hsl(hx(h))
        print(f"  {name:24} {h}  H{H:6.1f}  S{S:5.1f}%  L{L:5.1f}%")

    print("\n=== actor vs each stage tile (worst case = ELEVATED, the lightest tile) ===")
    print(f"{'actor':14} {'stage tile':22} {'dHue':>6} {'dS%':>6} {'dL%':>6} "
          f"{'contrast':>9} {'grayΔ':>7} {'ΔE2000':>7}")
    for an, ah in ACTORS.items():
        ar = hx(ah)
        aH, aS, aL = hsl(ar)
        alab = rgb2lab(ar)
        for sn, sh in STAGE.items():
            sr = hx(sh)
            sH, sS, sL = hsl(sr)
            dh = abs(aH - sH)
            dh = min(dh, 360 - dh)
            print(f"{an:14} {sn:22} {dh:6.0f} {aS - sS:6.0f} {aL - sL:6.0f} "
                  f"{contrast(ar, sr):8.2f}:1 {gray(ar) - gray(sr):7.0f} "
                  f"{ciede2000(alab, rgb2lab(sr)):7.1f}")
        print()
