#!/usr/bin/env python3
"""Stand runtime sprites on a patch of real terrain tiles, as the renderer places them.

    python3 tools/asset-pipeline/roster_board.py <out.png> levy knight ... [--zoom 2]

For art review when no display is available to run tools/CaptureRoster.tscn (e.g. the
machine sits at the login screen). Mirrors the renderer's rules: tiles are the 2x
`tile_plain_clean.png` at 0.5 (128x64 on screen), sprites at 0.5 anchored bottom-centre
on the tile centre (assets/art/README.md). Row 1 = rush (player 1), row 2 = boom
(player 2, facing w). Scaled with NEAREST, like pixel art must be. Units only.
"""
import argparse, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "assets/art")
p = argparse.ArgumentParser(); p.add_argument("out"); p.add_argument("ids", nargs="+")
p.add_argument("--zoom", type=int, default=2); a = p.parse_args()
tile = Image.open(f"{ART}/terrain/tile_plain_clean.png").convert("RGBA")
tile = tile.resize((tile.width // 2, tile.height // 2), Image.LANCZOS)
TW, TH = 128, 64
cols, rows = len(a.ids) * 2 + 1, 6
W = (cols + rows) * TW // 2 + TW; H = (cols + rows) * TH // 2 + 220
img = Image.new("RGBA", (W, H), (10, 14, 23, 255))
ox, oy = rows * TW // 2 + TW // 2, 180
def center(gx, gy): return ox + (gx - gy) * TW // 2, oy + (gx + gy) * TH // 2
for gy in range(rows):
    for gx in range(cols):
        cx, cy = center(gx, gy); img.alpha_composite(tile, (cx - TW // 2, cy - TH // 2))
sprites = []
for row, (hue, facing) in enumerate((("rush", "e"), ("boom", "w"))):
    for i, uid in enumerate(a.ids):
        s = Image.open(f"{ART}/units/unit_{uid}_{hue}_{facing}_idle_01.png").convert("RGBA")
        s = s.resize((s.width // 2, s.height // 2), Image.NEAREST)
        gx, gy = 1 + i * 2, 2 + row * 2
        sprites.append((gx + gy, gx, gy, s))
for _, gx, gy, s in sorted(sprites, key=lambda t: t[0]):  # y-sort back to front
    cx, cy = center(gx, gy); img.alpha_composite(s, (cx - s.width // 2, cy - s.height))
img = img.crop(img.getbbox())
img.resize((img.width * a.zoom // 2, img.height * a.zoom // 2), Image.NEAREST).save(a.out)
print(a.out, img.size)
