#!/usr/bin/env python3
"""Batch-generate a faction's assets from its prompts.json (see art-source/factions/*/).

    python3 tools/asset-pipeline/gen_batch.py art-source/factions/order/prompts.json --count 3 [--only levy,knight]

Each entry becomes `head + body + tail`, with the negative = the approved Trooper negative
(generation-prompts.md, the list that suppresses concept sheets) + `neg_extra`. The Trooper
negative is load-bearing: a shortened one produced multi-view concept sheets 5 times in 10
(2026-09-29). Output: art-source/generated/<faction>/<id>.png, _2, _3 ... (never overwrites).
Groups other than "units" (e.g. "vehicles", "air", "structs") may carry their own head/tail
as "<group>_head"/"<group>_tail".
"""
import argparse, json, os, re, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
p = argparse.ArgumentParser(); p.add_argument("prompts"); p.add_argument("--count", type=int, default=3)
p.add_argument("--only", default=""); a = p.parse_args()
cfg = json.load(open(a.prompts)); faction = os.path.basename(os.path.dirname(os.path.abspath(a.prompts)))
spec = open(os.path.join(ROOT, "design/assets/specs/generation-prompts.md")).read()
base_neg = re.search(r"ASSET-003.*?\*\*Negative:\*\* `([^`]+)`", spec, re.S).group(1)
only = {s for s in a.only.split(",") if s}
out = os.path.join(ROOT, "art-source/generated", faction)
for group in [g for g in cfg if isinstance(cfg[g], dict)]:
    head = cfg.get(f"{group}_head", cfg["head"]); tail = cfg.get(f"{group}_tail", cfg["tail"])
    neg = base_neg + ", " + cfg.get(f"{group}_neg_extra", cfg.get("neg_extra", ""))
    for uid, body in cfg[group].items():
        if only and uid not in only: continue
        # "model": "zimage" in prompts.json switches to Z-Image base (see comfyui_generate.py):
        # it needs no SDXL mega-negative, so only neg_extra is sent.
        zimage = cfg.get("model") == "zimage"
        extra = (["--model", "zimage", "--unet-dtype", "fp8_e4m3fn", "--steps", "30", "--cfg", "4",
                  "--sampler", "res_multistep", "--scheduler", "simple"] if zimage else [])
        negative = cfg.get(f"{group}_neg_extra", cfg.get("neg_extra", "")) if zimage else neg
        for _ in range(a.count):
            r = subprocess.run([sys.executable, os.path.join(ROOT, "tools/asset-pipeline/comfyui_generate.py"),
                "--prompt", f"{head} {body}, {tail}", "--negative", negative, "--out", out, "--name", uid,
                "--timeout", "1800" if zimage else "600"] + extra + cfg.get(f"{group}_size", cfg.get("size", [])),
                capture_output=True, text=True)
            print(uid, (r.stdout.strip().splitlines() or ["?"])[-1], r.stderr.strip()[-200:] if r.returncode else "", flush=True)
print("ALLDONE", flush=True)
