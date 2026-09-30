#!/usr/bin/env python3
"""Tile raw generations into one labelled contact sheet for review.

    python3 tools/asset-pipeline/contact_sheet.py <out.png> <img>... [--cols 6] [--size 220]
"""
import argparse, os
from PIL import Image, ImageDraw
p = argparse.ArgumentParser(); p.add_argument("out"); p.add_argument("imgs", nargs="+")
p.add_argument("--cols", type=int, default=6); p.add_argument("--size", type=int, default=220); a = p.parse_args()
S, C = a.size, a.cols; rows = (len(a.imgs) + C - 1) // C
sheet = Image.new("RGB", (S * C, S * rows), (30, 30, 36)); d = ImageDraw.Draw(sheet)
for i, f in enumerate(a.imgs):
    x, y = (i % C) * S, (i // C) * S
    sheet.paste(Image.open(f).convert("RGB").resize((S, S)), (x, y))
    d.rectangle((x, y, x + S - 1, y + 14), fill=(0, 0, 0)); d.text((x + 3, y + 1), os.path.basename(f)[:-4], fill=(255, 255, 255))
sheet.save(a.out)
