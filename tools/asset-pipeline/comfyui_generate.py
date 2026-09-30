#!/usr/bin/env python3
"""Generate an image via the local ComfyUI API and save it to a target path.

The bridge between this project's asset pipeline (/asset-generate skill) and the
ComfyUI server at ~/ComfyUI. Stdlib only — run with any Python 3.

    python3 tools/asset-pipeline/comfyui_generate.py \
        --prompt "..." --negative "..." \
        --out art-source/generated/asset-001-hq --name hq_rush

Key behaviors the skill relies on:
- If the ComfyUI server is not running it is started automatically (via
  ~/ComfyUI/run.sh) and waited for. The machine's LACT "ai-compute" GPU profile
  engages on its own when the server process appears — no thermal handling here.
- The seed used is always printed as `seed=N`. Faction hue variants of one asset
  MUST reuse the first variant's seed (art-bible shared-silhouette rule) — parse
  it from stdout and pass it back via --seed on the next call.
- Output filename is <name>.png inside --out (created if missing). If that file
  exists, _2, _3... is appended — existing files are never overwritten.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

COMFY_DIR = os.path.expanduser("~/ComfyUI")
SERVER_STARTUP_TIMEOUT_S = 180


def build_workflow(args: argparse.Namespace, seed: int) -> dict:
    """Text-to-image graph in ComfyUI API format. ["4", 1] = node 4, slot 1."""
    if args.model == "zimage":
        return _zimage_workflow(args, seed)
    return {
        "4": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": args.ckpt}},
        "5": {"class_type": "EmptyLatentImage",
              "inputs": {"width": args.width, "height": args.height, "batch_size": 1}},
        "6": {"class_type": "CLIPTextEncode",
              "inputs": {"text": args.prompt, "clip": ["4", 1]}},
        "7": {"class_type": "CLIPTextEncode",
              "inputs": {"text": args.negative, "clip": ["4", 1]}},
        "3": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": args.steps, "cfg": args.cfg,
                         "sampler_name": args.sampler, "scheduler": args.scheduler,
                         "denoise": 1.0, "model": ["4", 0],
                         "positive": ["6", 0], "negative": ["7", 0],
                         "latent_image": ["5", 0]}},
        "8": {"class_type": "VAEDecode",
              "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage",
              "inputs": {"filename_prefix": "asset_gen", "images": ["8", 0]}},
    }


# Z-Image base (Alibaba Tongyi, Apache 2.0) — mirrors ComfyUI's own blueprint
# "Text to Image (Z-Image-Base)": separate UNET / Qwen3-4B text encoder ("lumina2"
# loader type) / Flux VAE, AuraFlow sampling shift 3, res_multistep. The BASE model
# (not Turbo) because only base honours CFG and so a negative prompt — which is what
# kept SDXL from drawing concept sheets. Blueprint guidance: 30-50 steps, cfg 3-5.
# ★ 16 GB card (RX 6900 XT): with the 7.5 GB Qwen3-4B text encoder left on the GPU the
# 12.3 GB UNET only half-fits (3.3 GB streamed from RAM every step: 8.2 s/step, ~4 min
# per image). --te-device cpu encodes on the CPU once per image and frees the card.
ZIMAGE_FILES = {"unet": "z_image_bf16.safetensors", "te": "qwen_3_4b.safetensors",
                "vae": "ae.safetensors"}


def _zimage_workflow(args: argparse.Namespace, seed: int) -> dict:
    return {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": ZIMAGE_FILES["unet"], "weight_dtype": args.unet_dtype}},
        "2": {"class_type": "CLIPLoader",
              "inputs": {"clip_name": ZIMAGE_FILES["te"], "type": "lumina2", "device": args.te_device}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": ZIMAGE_FILES["vae"]}},
        "4": {"class_type": "ModelSamplingAuraFlow", "inputs": {"shift": 3, "model": ["1", 0]}},
        "5": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": args.width, "height": args.height, "batch_size": 1}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": args.prompt, "clip": ["2", 0]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": args.negative, "clip": ["2", 0]}},
        "8": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": args.steps, "cfg": args.cfg,
                         "sampler_name": args.sampler, "scheduler": args.scheduler,
                         "denoise": 1.0, "model": ["4", 0], "positive": ["6", 0],
                         "negative": ["7", 0], "latent_image": ["5", 0]}},
        "9": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveImage", "inputs": {"filename_prefix": "asset_gen", "images": ["9", 0]}},
    }

def _get_json(server: str, path: str) -> dict:
    with urllib.request.urlopen(f"http://{server}{path}", timeout=15) as r:
        return json.load(r)


def _post(server: str, path: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"http://{server}{path}", data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def server_alive(server: str) -> bool:
    try:
        urllib.request.urlopen(f"http://{server}/", timeout=3)
        return True
    except (urllib.error.URLError, OSError):
        return False


def ensure_server(server: str) -> None:
    """Start ComfyUI via run.sh if it is not already answering."""
    if server_alive(server):
        return
    run_sh = os.path.join(COMFY_DIR, "run.sh")
    if not os.path.exists(run_sh):
        sys.exit(f"ERROR: ComfyUI server is down and {run_sh} not found.")
    print(f"[server] not running — starting {run_sh} ...")
    log = open(os.path.join(COMFY_DIR, ".server.log"), "a")
    subprocess.Popen([run_sh], cwd=COMFY_DIR, stdout=log, stderr=log,
                     start_new_session=True)
    deadline = time.monotonic() + SERVER_STARTUP_TIMEOUT_S
    while time.monotonic() < deadline:
        if server_alive(server):
            print("[server] up")
            return
        time.sleep(2)  # startup is typically 10-25 s
    sys.exit(f"ERROR: server did not come up within {SERVER_STARTUP_TIMEOUT_S}s "
             f"— check {COMFY_DIR}/.server.log")


def run_workflow(server: str, workflow: dict, timeout: int) -> list[bytes]:
    """Queue an API-format workflow, wait for it, and return every saved image's bytes.

    Raises RuntimeError with a readable message on rejection, failure or timeout.
    Shared by comfyui_generate.py and comfyui_cutout.py.
    """
    try:
        resp = _post(server, "/prompt",
                     {"prompt": workflow, "client_id": f"asset-gen-{random.randint(0, 2**31)}"})
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"ComfyUI rejected the prompt (HTTP {e.code}): "
                           f"{e.read().decode(errors='replace')[:500]}") from e
    prompt_id = resp["prompt_id"]
    deadline = time.monotonic() + timeout
    record = None
    while time.monotonic() < deadline:
        hist = _get_json(server, f"/history/{prompt_id}")
        if prompt_id in hist:
            record = hist[prompt_id]
            break
        time.sleep(1)
    if record is None:
        raise RuntimeError(f"timed out after {timeout}s. The queue may still be working "
                           f"— check http://{server} before resubmitting.")
    status = record.get("status", {})
    if status.get("status_str") == "error":
        msgs = "\n".join(str(m) for m in status.get("messages", []))
        raise RuntimeError(f"generation failed:\n{msgs[:800]}")
    out: list[bytes] = []
    for node_out in record.get("outputs", {}).values():
        for img in node_out.get("images", []):
            q = urllib.parse.urlencode({"filename": img["filename"],
                                        "subfolder": img.get("subfolder", ""),
                                        "type": img.get("type", "output")})
            with urllib.request.urlopen(f"http://{server}/view?{q}") as r:
                out.append(r.read())
    if not out:
        raise RuntimeError("job finished but produced no images — check the ComfyUI log.")
    return out


def unique_path(out_dir: str, name: str) -> str:
    """<out>/<name>.png, appending _2, _3... rather than overwriting."""
    path = os.path.join(out_dir, f"{name}.png")
    n = 2
    while os.path.exists(path):
        path = os.path.join(out_dir, f"{name}_{n}.png")
        n += 1
    return path


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate an image via ComfyUI.")
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--negative", default="text, watermark, blurry, low quality")
    ap.add_argument("--width", type=int, default=1024)
    ap.add_argument("--height", type=int, default=1024)
    ap.add_argument("--steps", type=int, default=25)
    ap.add_argument("--cfg", type=float, default=7.0)
    ap.add_argument("--seed", type=int, default=-1, help="-1 = random; printed as seed=N")
    ap.add_argument("--sampler", default="euler")
    ap.add_argument("--scheduler", default="normal")
    ap.add_argument("--ckpt", default="sd_xl_base_1.0.safetensors")
    ap.add_argument("--unet-dtype", choices=("default", "fp8_e4m3fn"), default="default",
                    help="zimage UNET weight storage; fp8 halves its VRAM (compute is upcast)")
    ap.add_argument("--te-device", choices=("default", "cpu"), default="cpu",
                    help="zimage text-encoder device; cpu keeps the UNET fully on a 16 GB card")
    ap.add_argument("--model", choices=("sdxl", "zimage"), default="sdxl",
                    help="zimage = Z-Image base (set --steps 30-50 --cfg 3-5 --sampler "
                         "res_multistep --scheduler simple)")
    ap.add_argument("--server", default="127.0.0.1:8188")
    ap.add_argument("--out", required=True, help="output directory (created if missing)")
    ap.add_argument("--name", required=True, help="output filename base, no extension")
    ap.add_argument("--timeout", type=int, default=600, help="max seconds to wait for the job")
    args = ap.parse_args()

    ensure_server(args.server)

    seed = args.seed if args.seed >= 0 else random.randint(0, 2**32 - 1)
    print(f"seed={seed}")
    print(f"[submit] {args.width}x{args.height} steps={args.steps} cfg={args.cfg} "
          f"sampler={args.sampler} model={args.model}")

    try:
        images = run_workflow(args.server, build_workflow(args, seed), args.timeout)
    except RuntimeError as e:
        sys.exit(f"ERROR: {e}")
    os.makedirs(args.out, exist_ok=True)
    saved = []
    for data in images:
        path = unique_path(args.out, args.name)
        with open(path, "wb") as f:
            f.write(data)
        saved.append(path)

    for p in saved:
        print(f"saved={p}")


if __name__ == "__main__":
    main()
