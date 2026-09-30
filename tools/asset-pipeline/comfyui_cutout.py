#!/usr/bin/env python3
"""Cut an image out of its background with BiRefNet, via the local ComfyUI server.

    python3 tools/asset-pipeline/comfyui_cutout.py <src.png> <dst.png>

The AI alternative to cutout.py's colour flood-fill. The flood-fill keys on the
BORDER COLOUR, so it fails exactly where SDXL renders are messy: gradient/vignette
backgrounds, ground-shadow slabs, and light subjects on light backgrounds (Mandate
white shells). BiRefNet segments the SUBJECT instead (MIT licence; Comfy-Org's
repackaged birefnet.safetensors in ~/ComfyUI/models/background_removal/).

Mirrors ComfyUI's blueprint "Remove Background (BiRefNet)": RemoveBackground emits a
mask that is inverted before JoinImageWithAlpha. The result keeps the model's soft
edge; pixelize.py's alpha cut turns it hard later.

⚠ Do NOT substitute RMBG-2.0 here: non-commercial licence (design/art/image-model-options-2026-09.md).

Stdlib + comfyui_generate.py only.
"""
from __future__ import annotations

import json
import os
import sys
import uuid
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comfyui_generate import ensure_server, run_workflow  # noqa: E402

SERVER = "127.0.0.1:8188"
MODEL = "birefnet.safetensors"


def _upload(path: str) -> str:
    """POST the file to /upload/image (multipart); return the name ComfyUI stored it as."""
    boundary = uuid.uuid4().hex
    name = f"cutout_{uuid.uuid4().hex[:8]}_{os.path.basename(path)}"
    with open(path, "rb") as f:
        data = f.read()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; "
            f"filename=\"{name}\"\r\nContent-Type: image/png\r\n\r\n").encode() + data + \
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue" \
        f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"http://{SERVER}/upload/image", data=body,
                                 headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["name"]


def cutout_bytes(src: str, timeout: int = 300) -> bytes:
    """Return PNG bytes of `src` with the background made transparent."""
    ensure_server(SERVER)
    stored = _upload(src)
    wf = {
        "1": {"class_type": "LoadImage", "inputs": {"image": stored}},
        "2": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": MODEL}},
        "3": {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["2", 0], "image": ["1", 0]}},
        "4": {"class_type": "InvertMask", "inputs": {"mask": ["3", 0]}},
        "5": {"class_type": "JoinImageWithAlpha", "inputs": {"image": ["1", 0], "alpha": ["4", 0]}},
        "6": {"class_type": "SaveImage", "inputs": {"filename_prefix": "cutout", "images": ["5", 0]}},
    }
    return run_workflow(SERVER, wf, timeout)[0]


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    data = cutout_bytes(sys.argv[1])
    with open(sys.argv[2], "wb") as f:
        f.write(data)
    print(f"{sys.argv[1]} -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
