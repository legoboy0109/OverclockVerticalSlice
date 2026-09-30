# Image-model research for UntitledTBT sprite pipeline (as of 2026-09-30)

Scope: what could replace or supplement bare SDXL 1.0 in the ComfyUI → cutout → palette-lock → pixelize pipeline, judged against the five problems (concept sheets, weak prompt adherence, no consistent new angles/frames, cutout failures, medieval drift), on an RX 6900 XT (16 GB, RDNA2, ROCm 7.2, 30 GB RAM, ~58 GB free disk), for a **commercial** Steam game.

Labels: **VERIFIED** = read on a primary source (official model card, vendor docs, licence file). **COMMUNITY** = forum/blog/aggregator reports. **UNVERIFIED** = could not confirm; treat as a lead only.

---

## 0. Two hardware facts that shape everything

1. **The 6900 XT cannot do fp8 fast.** AMD's ROCm 7.2 precision table lists no fp8 matrix support for RDNA2 (gfx1030); fp8 acceleration arrives with RDNA4/CDNA3. Many "fp8" ComfyUI checkpoints still *load*, but give up the speed and memory benefit they were made for. **VERIFIED** — [ROCm 7.2 precision support](https://rocm.docs.amd.com/en/docs-7.2.2/reference/precision-support.html). The practical route on this card is **bf16/fp16 for models that fit, GGUF quantized files for models that don't** (GGUF expands weights to fp16 while running, so it does not depend on fp8 hardware — COMMUNITY/reasoned, consistent with reports of GGUF working on AMD).
2. **The RX 6900 XT is not on ROCm 7.2's official support list.** Only the workstation cards on the same chip (PRO W6800, V620) are. It works through the long-standing `HSA_OVERRIDE_GFX_VERSION=10.3.0` workaround, which can break on a ROCm update. **VERIFIED** (support list) — [ROCm 7.2 system requirements](https://rocm.docs.amd.com/projects/install-on-linux/en/docs-7.2.2/reference/system-requirements.html). One improvement: ComfyUI's 2026 "Dynamic VRAM" memory manager streams/offloads models more gracefully than the old `--lowvram` flags (COMMUNITY — [eastondev](https://eastondev.com/blog/en/posts/ai/20260721-comfyui-low-vram-acceleration/)).

Also relevant: 30 GB system RAM matters for the bigger models, because their text encoders (7–9 GB) are often parked in system RAM while the main model sits on the GPU.

---

## A. Text-to-image models (replacing SDXL)

| Model | Size | Fits 16 GB RDNA2? | Disk | Licence (model / outputs) | Verdict |
|---|---|---|---|---|---|
| **Z-Image (base) / Z-Image-Turbo** (Alibaba Tongyi, base released 27 Jan 2026) | 6B | **Yes, at full bf16** (12.3 GB checkpoint) | ~19 GB incl. text encoder | **Apache 2.0 — commercial OK** | **Top pick** |
| **Qwen-Image** (original, Aug 2025) | 20B | Only as GGUF Q4/Q5 (~12–15 GB) + encoder in system RAM | ~13–15 GB (Q4–Q5) + ~9 GB encoder | **Apache 2.0 — commercial OK** | Strong second |
| **FLUX.2 [klein] 4B** (BFL, Jan 2026) | 4B | Yes (~13 GB stated) | ~8–13 GB | **4B: Apache 2.0 — commercial OK.** ⚠ **9B: non-commercial** | Worth a test; pick the **4B only** |
| **Chroma1-HD** (FLUX-derived) | 8.9B | Probably, via GGUF (not confirmed) | not confirmed | **Apache 2.0** | Maybe; unconfirmed fit |
| **SD 3.5 Large / Medium** | 8B / 2.5B | Large: no at fp16 (~24 GB); Medium: yes | 5–16 GB | Stability Community Licence: free **under $1M/yr revenue**, paid licence above | Weak reason to pick it now |
| **HiDream-I1** | 17B + 4 text encoders | Borderline/no | 30 GB+ | **MIT — best licence** | Too heavy for this card |
| **FLUX.1 [dev]** | 12B | GGUF only | ~7–12 GB | ⛔ **Non-commercial** without a paid BFL licence | **Ruled out (licence)** |
| **FLUX.1 [schnell]** | 12B | GGUF only | ~7–12 GB | Apache 2.0 | OK licence, but superseded by klein 4B / Z-Image |
| **FLUX.2 [dev]** | 32B | No (Q4 ≈ 19 GB) | 19 GB+ | ⛔ Non-commercial without paid licence | **Ruled out** |
| **HunyuanImage 3.0** | 80B MoE | No (Q4 ≈ 41 GB) | huge | Tencent community licence | **Ruled out (size)** |
| **Qwen-Image 2.0 / 2.1** (2026) | 7B | — | — | 2.0: **weights not released**. 2.1: ⛔ reported switch to a **non-commercial research licence** | **Not usable** |

Sources and notes:
- Z-Image: base model release and 16 GB fit — [ComfyUI wiki, 2026-01-28](https://comfyui-wiki.com/en/news/2026-01-28-alibaba-z-image-base-release); Apache 2.0 and Turbo/base differences — [invideo overview](https://invideo.io/blog/z-image-ai-image-generator/). Its reputation for strong prompt following and a wide style range (illustration included) is **COMMUNITY**; the "#1 open model on Artificial Analysis (Dec 2025)" claim is repeated but **UNVERIFIED** here. **Z-Image-Edit has not been released** (still "to be released" as of Aug 2026 — COMMUNITY, [localaimaster](https://localaimaster.com/blog/z-image-base-edit-guide)). Turbo = fast, few steps, no negative prompt; **base = slower (30–50 steps) but accepts CFG/negative prompts**, which matters for suppressing concept sheets.
- Qwen-Image: Apache 2.0 **VERIFIED** on the Qwen model cards ([Qwen-Image-Edit-2511 card states "Qwen-Image is licensed under Apache 2.0"](https://huggingface.co/Qwen/Qwen-Image-Edit-2511)); ComfyUI guide — [comfyui-wiki](https://comfyui-wiki.com/en/tutorial/advanced/image/qwen/qwen-image). Known for the best prompt adherence and text rendering among Apache-licensed models (COMMUNITY).
- FLUX.2 klein licence split (4B Apache, 9B non-commercial) — **VERIFIED** on [BFL's klein page](https://bfl.ai/models/flux-2-klein) / [BFL blog](https://bfl.ai/blog/flux2-klein-towards-interactive-visual-intelligence). VRAM figures vary between sources (8–13 GB) — COMMUNITY.
- FLUX.1 [dev] non-commercial — **VERIFIED**, [BFL licence terms](https://bfl.ai/legal/self-hosted-commercial-license-terms). There is long-running forum argument about whether *outputs* are free to use commercially. The licence text itself (**VERIFIED** today, [LICENSE.md](https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md)) says both: "You may use Output for any purpose (including for commercial purposes)", **and** that using the model "for revenue-generating activity" or with "impact on end users" is *not* a permitted non-commercial purpose. Making art for a game on sale falls in that second clause, so the safe reading is **don't, unless you buy the licence**. FLUX.2 [dev] VRAM — [RunPod guide](https://www.runpod.io/articles/guides/deploying-flux-2).
- SD 3.5 licence threshold — **VERIFIED**, [stability.ai](https://stability.ai/membership); fp16 VRAM — [Comfy blog](https://blog.comfy.org/sd3-5-comfyui/).
- HiDream-I1 MIT — [RunPod guide](https://www.runpod.io/articles/guides/comfyui-hidream-runpod) (COMMUNITY).
- HunyuanImage 3.0 size — [Spheron](https://www.spheron.network/tools/gpu-recommender/tencent/HunyuanImage-3.0) (COMMUNITY).
- Qwen-Image 2.0 closed weights / 2.1 licence change — [invideo licence matrix](https://invideo.io/blog/open-source-image-models-licenses/), [aiweekly](https://aiweekly.co/alerts/alibaba-ships-qwen-image-21-7b-dit-with-native-2048x2048-and-rgba-drops-apache) (COMMUNITY — re-check before relying on it). Note 2.1 reportedly outputs **RGBA (transparent backgrounds)** natively, which would have been perfect for problem 4 — but the licence rules it out.

**How the newer models help the five problems**
- Problems 1, 2, 5 (concept sheets, ignored weapons/halos/shapes, medieval drift): all of Z-Image, Qwen-Image and FLUX.2-klein use a modern language model as the text reader instead of SDXL's CLIP. That is the single biggest reason they follow long, specific prompts ("shoulder-mounted rocket launcher", "halo", "rounded capsule body") far better. This is the widely-reported step change (COMMUNITY), but **none of it has been tested against *your* prompts** — expect a real improvement, not perfection.
- Problem 3 (angles/frames): base models do not solve this. See B.
- Problem 4 (cutout): not solved by the model; see D. You can, however, prompt the new models far more reliably for "plain flat mid-grey background, no shadow", which helps flood-fill too.

**Disk:** with ~58 GB free, you can hold roughly two of these families at once (e.g. Z-Image ~19 GB + Qwen-Image-Edit Q4 ~13 GB + shared/other encoders ~9 GB). Free space before installing a third.

---

## B. Editing / reference models (re-angle, re-pose, fix a detail)

**Qwen-Image-Edit-2511** (Dec 2025) — **the most useful thing found for problem 3.**
- Apache 2.0 — **VERIFIED** ([model card](https://huggingface.co/Qwen/Qwen-Image-Edit-2511)). 20B.
- The card states character consistency was "significantly improved" and that "generating new viewpoints can now be done directly with the base model"; it accepts **multiple reference images** at once (VERIFIED — vendor claim, not independently tested).
- A dedicated **Multiple-Angles LoRA** by fal.ai: 96 camera positions (8 around × 4 heights × 3 distances), trained on 3,000+ 3D renders, Apache 2.0, with ComfyUI nodes that give a camera dial (VERIFIED — [LoRA card](https://huggingface.co/fal/Qwen-Image-Edit-2511-Multiple-Angles-LoRA); [Comfy supported-models page](https://comfy.org/p/supported-models/qwen-image-edit-2511-multiple-angles-lora.md); walkthrough — [stable-diffusion-art](https://stable-diffusion-art.com/qwen-image-edit-multiple-angle-lora/)). This maps directly onto "give me this approved Knight from the other isometric facing".
- Fit on the 6900 XT: GGUF files from [unsloth](https://huggingface.co/unsloth/Qwen-Image-Edit-2511-GGUF) — Q4_K_M 13.2 GB, Q5_K_M 15.0 GB, Q8 21.8 GB (VERIFIED file sizes). **Q4_K_M is the realistic choice on 16 GB**, with the ~9 GB text encoder offloaded to system RAM (30 GB RAM is at the low end — community guides call 32 GB a floor, [localaimaster](https://localaimaster.com/blog/qwen-image-edit-local-guide)). Expect it to be **slow** on RDNA2 (tens of seconds to minutes per edit — UNVERIFIED estimate).
- Also good at the **"fix one detail"** job (add the missing rocket launcher / halo while keeping the rest) — that is what instruction-editing models are built for.
- **Honest limits:** reports and the LoRA card itself point to clean, single, well-lit subjects working best. Identity is preserved well for *broad* design (silhouette, colours, major parts); small details (insignia, exact weapon shape) drift between angles. Nobody has published results on 35-px isometric sprites specifically — **UNVERIFIED for your use case**. Treat it as "gets you a strong first draft of the new facing that the pixelizer and palette-lock then normalise", not as a push-button turnaround.

**FLUX.1 Kontext [dev]** — editing model with good identity preservation, but ⛔ **non-commercial licence** (same as FLUX.1 dev) unless a commercial licence is bought from BFL. Outputs made through BFL's paid API are commercially usable. **VERIFIED** — [HF discussion](https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev/discussions/6), [invideo licence summary](https://invideo.io/blog/flux-ai-image-generator/). **Avoid locally.**

**FLUX.2 [klein] 4B** — BFL says klein does both generation and multi-reference editing in one model (Apache for the 4B) — worth testing as a lighter editor than Qwen-Edit ([BFL](https://bfl.ai/models/flux-2-klein)). Editing quality vs Qwen-Edit-2511: **UNVERIFIED**.

**Z-Image-Edit** — announced, **not released** (see A). Watch for it: a 6B Apache editor would fit the 6900 XT far better than Qwen-Edit.

**Qwen-Image 2.0/2.1** — unified generate+edit, but closed weights / non-commercial (see A).

Older options (OmniGen2, Step1X-Edit, ICEdit, HiDream-E1, UNO) were superseded in community use by Qwen-Edit-2511 and Kontext; not re-researched in depth.

**Bottom line on problem 3:** as of late 2026 this is **meaningfully better but not solved**. Re-angling with Qwen-Edit-2511 + the multi-angle LoRA is the first open, commercially-usable tool that directly targets "same character, new camera angle", and at 35 px many small inconsistencies vanish in pixelization. **Walk cycles / animation frames remain the hard part**: editing each frame from the reference with a pose guide is possible but frame-to-frame jitter is likely — no strong evidence it works reliably for sprite animation (UNVERIFIED).

---

## C. Consistency tooling

1. **ControlNet (pose / depth / lineart).** For SDXL, the standard is **xinsir's ControlNet Union / ProMax** — one file covering OpenPose, depth, lineart, canny, etc., **Apache 2.0** ([model](https://huggingface.co/xinsir/controlnet-union-sdxl-1.0), [ControlNet++](https://docsearch.algolia.com/mcp/docs/repo/xinsir6/controlnetplus) — COMMUNITY-confirmed licence). Cheap to run on the 6900 XT. Useful for *pose* (e.g. hold the rifle upright, walk-cycle keyframes from stick figures) and *silhouette* control, but it does **not** carry a design across angles by itself. Qwen-Image and Z-Image also have ControlNet/"union" support in ComfyUI (COMMUNITY, not verified per-model).
2. **IP-Adapter / reference conditioning.** Still the classic SDXL tool (h94 IP-Adapter, Apache 2.0 — from prior knowledge, not re-verified this pass). It transfers *style and rough look* well but is weak at keeping exact design details — in 2026 community practice it has largely been replaced for character consistency by the edit models in B (multi-reference input). FLUX IP-adapters inherit FLUX.1-dev's non-commercial licence (UNVERIFIED).
3. **LoRA training on your own approved sprites.** This is the most reliable way to lock the *art style* and faction look (fixes problem 5 durably) and helps per-character consistency when you have 10–30 good images of a unit.
   - Tools: **kohya_ss/sd-scripts, OneTrainer, ai-toolkit** (ai-toolkit supports SDXL, FLUX, and newer models) — [vrlatech 2026 requirements](https://vrlatech.com/stable-diffusion-lora-training-hardware-requirements/).
   - VRAM: SDXL LoRA ~10–12 GB (fits 16 GB); FLUX-class ~24 GB (does not) — COMMUNITY.
   - **AMD reality: works but is the rough edge.** Confirmed reports exist for RDNA3 (7900 XT, ROCm 7.2) and RDNA4 (9060 XT) — [aiweekly](https://aiweekly.co/alerts/amd-rx-9060-xt-confirmed-viable-for-lora-training). **No confirmed RDNA2 + ROCm 7.2 report found.** 8-bit optimisers (bitsandbytes) have ROCm builds ([AMD blog](https://rocm.blogs.amd.com/artificial-intelligence/bnb-8bit/README.html)) but are a common failure point. Verdict: **SDXL LoRA training on the 6900 XT is plausible but UNVERIFIED; LoRA training for the newer 6B–20B models is realistically a cloud-GPU job** (a few dollars per LoRA on a rented 4090/5090).
4. **Pre-made pixel-art / isometric LoRAs.**
   - **Pixel Art XL** (nerijs, SDXL) — isometric and non-isometric pixel art; **CreativeML OpenRAIL-M** (commercial use allowed with use-based restrictions) — [promptlayer](https://www.promptlayer.com/models/pixel-art-xl) (COMMUNITY summary of the HF card).
   - **Z-Image-Turbo pixel-art LoRAs** exist (e.g. [elusarca](https://huggingface.co/reverentelusarca/elusarca-pixel-art-style-lora-zimage-turbo)); licences vary per upload — **check each**.
   - ⚠ **Civitai LoRAs**: each carries its own permission flags (e.g. "no selling images", "no commercial use", or inherits FLUX-dev's non-commercial terms if trained on FLUX-dev). Read the permissions panel on every one before shipping art made with it, and prefer LoRAs whose base model is Apache/MIT.
   - Note: since your pipeline pixelizes *after* generation, a pixel-art LoRA is optional — a **style LoRA trained on your own finished sprites** is more valuable.

---

## D. Background removal (problem 4)

| Model | Licence | Notes |
|---|---|---|
| **BiRefNet** (general / HR / matting checkpoints) | **MIT** — VERIFIED ([repo](https://github.com/ZhengPeng7/BiRefNet)) | Top-tier edges; the **matting** checkpoint gives soft alpha (good for contact shadows and anti-aliased edges); ~3.5 GB VRAM; **built into ComfyUI core** ([Comfy docs](https://docs.comfy.org/tutorials/utility/remove-background-birefnet)). ⚠ Avoid any checkpoint labelled as trained on/derived from RMBG-2.0. |
| **BEN2** (base) | **MIT** — VERIFIED ([HF](https://huggingface.co/PramaLLC/BEN2)) | "Confidence-guided matting" targets uncertain pixels — exactly the white-on-light case. ComfyUI node exists. (Paid refiner tier is separate.) |
| **InSPyReNet** | **MIT** | Solid, fast, batch-friendly ComfyUI node ([node](https://github.com/john-mnz/ComfyUI-Inspyrenet-Rembg)); less nuanced alpha than BiRefNet-matting. |
| **RMBG-2.0 / 1.4** (BRIA) | ⛔ **CC BY-NC 4.0 — non-commercial.** "Commercial use is subject to a commercial agreement with BRIA." **VERIFIED today** ([model card](https://huggingface.co/briaai/RMBG-2.0)) | BRIA pricing: API ~$0.018/image, or ~$700/month plan (COMMUNITY — [bria.ai/pricing](https://bria.ai/pricing)). **Do not use.** ⛔ **The `rembg` Python tool now uses this model by default** (`bria-rmbg` is listed as "the default"; its README says RMBG-2.0 "requires a paid agreement for commercial use") — **VERIFIED** ([rembg README](https://github.com/danielgatis/rembg)). If rembg is ever used, always pass `-m birefnet-general` (or another MIT model). Many rembg-style ComfyUI nodes likewise default to RMBG — check which model a node loads. |
| **BiRefNet ToonOut** (fine-tune for anime/stylised characters) | MIT (inherits BiRefNet) — COMMUNITY | Claimed 95.3% → 99.5% accuracy on stylised character art vs base BiRefNet (single source — [paper](https://arxiv.org/html/2509.06839v1), [HF](https://huggingface.co/joelseytre/toonout)); UNVERIFIED on your art but a cheap A/B against BiRefNet-matting. |
| **Qwen-Image-Layered** (Dec 2025) | **Apache 2.0** — COMMUNITY ([comfyui-wiki](https://comfyui-wiki.com/en/news/2025-12-19-qwen-image-layered-release)) | Splits one image into RGBA layers (background / subject / extras) with true transparency; native ComfyUI support. Interesting for hard cases, but **very heavy** (~45 GB peak reported; fills a 24 GB 4090) — a cloud-only tool, not a daily cutout step. |
| **SAM 3** (Meta, Nov 2025) + matting add-ons | Meta SAM licence — read before shipping (UNVERIFIED) | Prompt-driven ("keep the knight"), more integration work; not a drop-in batch remover. |

**Recommendation:** replace flood-fill with **BiRefNet (matting checkpoint)**, keep flood-fill only as a fallback, and try **BEN2** on the white-armour cases. Both run easily on the 6900 XT (no CUDA-only parts). Bonus: ask the new generator for a **flat, saturated, non-palette background colour** (e.g. a chroma green or mid-grey that no faction palette uses) — belt and braces.

Ground shadows: a learned matte will usually *include* a soft contact shadow as semi-transparent pixels. Decide by design whether you want shadows baked into sprites or drawn by the engine (for isometric tactics the engine usually draws them); if engine-drawn, threshold the alpha to drop low-opacity shadow pixels.

---

## E. The 3D route (image → 3D → render 4 facings → pixelize)

| Model | Licence | VRAM | AMD/ROCm |
|---|---|---|---|
| **TRELLIS.2** (Microsoft, Dec 2025) | MIT for the model — VERIFIED ([comfyui-wiki](https://comfyui-wiki.com/en/models/trellis/trellis-2)). ⚠ But it depends on NVIDIA's **nvdiffrast**, whose NVIDIA Source Code Licence limits it to non-commercial/research use — a grey zone for a paid game (COMMUNITY; read the nvdiffrast licence before relying on it). Disk: ≥14.5 GB weights, ~40 GB recommended for a full setup. | 24 GB stated; ~12 GB with fp16 tweaks | ⛔ **Broken out of the box.** A first-hand AMD port needed several weeks: nvdiffrast "doesn't build on ROCm", plus silently-wrong `grid_sample_3d`, missing Flash Attention, and more ([lloyd.io](https://lloyd.io/ai-on-alien-tech)) |
| **Hunyuan3D 2.1** (Tencent) | Tencent Hunyuan 3D Community Licence — free commercial use for products under 1M monthly users; ⚠ **excludes the EU, UK and South Korea** in Tencent's community licences (from prior knowledge — **re-verify the licence file before use**) | ~8 GB (shape); texture ("Paint") stage reported at 20 GB+ | AMD publishes an official **Hunyuan3D-in-ComfyUI ROCm guide** ([AMD docs 26.04](https://rocm.docs.amd.com/projects/comfyui/en/docs-26.04/how-to/hunyuan3d-workflow.html)) — a better sign than TRELLIS — but it names no GPUs, and the texture stage uses a custom CUDA rasterizer. Shape-only on RDNA2 is plausible; textures UNVERIFIED. Licence note: the MAU cap and EU/UK/South-Korea exclusion were confirmed via licence databases ([scancode](https://scancode-licensedb.aboutcode.org/tencent-hunyuan-3d-2.0-cla.html)); the user appears to be in the US (machine clock is MDT), so the regional exclusion likely does not apply — confirm. |
| **Hunyuan3D 3.0** | ⚠ Reported **non-commercial** for the Pro model — UNVERIFIED (licence file not reachable) | — | — |
| **SAM 3D Objects** (Meta) | SAM licence — UNVERIFIED | — | CUDA-first; unknown |
| **Stable Fast 3D** (Stability) | Free under $1M/yr revenue | small | unknown |
| **InstantMesh** | Apache 2.0 | ~16 GB+ | CUDA-first rendering — unknown/risky |
| **Meshy, Rodin, Tripo** | Closed, paid cloud services | n/a | n/a (runs on their servers) |

**Would it solve facings/animation?** In principle yes — a 3D model rendered from four fixed isometric cameras is perfectly consistent, and a rigged model gives consistent walk cycles. In practice for you: (1) every local option leans on NVIDIA-only rendering code and does not run on the 6900 XT without weeks of porting; (2) generated meshes of detailed sci-fi-gothic characters are usually messy (merged limbs, baked lighting in textures) and would need **rigging** (auto-riggers like Mixamo help, but only for humanoids — not tanks, walkers or aircraft) and a render setup; (3) it adds a whole new art discipline. **Verdict: park it.** Revisit only if the 2D edit route (B) fails, and then via a paid service (Meshy/Tripo) or a rented NVIDIA GPU, not the local AMD card. One exception worth a cheap test later: **vehicles and buildings** (rigid, no skeleton) are the best fit for 3D-render-then-pixelize if their facings become a need.

---

## F. Hardware: keep, buy, or rent

**What the 6900 XT can realistically do well now**
- Z-Image (base + Turbo) at full precision — yes.
- FLUX.2 klein 4B — yes.
- Qwen-Image / Qwen-Image-Edit-2511 at GGUF Q4 — yes but slow, RAM-tight.
- BiRefNet / BEN2 / InSPyReNet — easily.
- SDXL + ControlNet Union — easily. SDXL LoRA training — plausible, unverified.
- Not realistic: anything fp8-dependent at full speed, FLUX.2 dev, HunyuanImage 3, TRELLIS/3D pipelines, LoRA training of the big new models.

**What a bigger NVIDIA card unlocks:** Qwen-Image-Edit at Q8/full quality (24–32 GB), fp8 speed, the whole CUDA-only ecosystem (3D, most training scripts "just work"), and several times the speed.

**Prices (Sept 2026 — prices are inflated right now):**
- RTX 5090 (32 GB): MSRP $1,999; **Sept 2026 street average ~$5,400, range ~$3,700–6,000** — [gpupoet, Sept 2026](https://gpupoet.com/gpu/learn/price/september-2026/nvidia-geforce-rtx-5090) (COMMUNITY aggregator). A second pass the same day found a lower used/eBay average of ~$4,200 and the **cheapest new listing at ~$5,000**. Plan on **$4,200–5,300**. Power: **575 W** (vs ~300 W for the 6900 XT), so check PSU headroom.
- RTX 4090 (24 GB): discontinued new; **used ~$2,500** (sold-listing average through 29 Aug 2026) — [gpupoet](https://gpupoet.com/gpu/learn/price/september-2026/nvidia-geforce-rtx-4090) (COMMUNITY aggregator). Live September figures ran higher (~$2,800–3,200). Plan on **$2,500–3,200 used**. 450 W.
- Why prices are high: a 2026 GPU/memory shortage driven by AI-datacentre demand ([Electropages](https://www.electropages.com/blog/2026/03/fusion-worldwide-gpu-shortage-and-price-increases-2026)). An RTX 50 "Super" refresh (5080 Super reportedly 20–24 GB) was rumoured for around Q3 2026. **UNVERIFIED** whether it has shipped. It could become the saner 24 GB-class buy once supply normalises.
- AMD's newest (RX 9070 XT, RDNA4) is still **16 GB** — gains fp8, not VRAM ([Wikipedia](https://en.wikipedia.org/wiki/Radeon_RX_9000_series)).

**Cloud rental (on-demand, per hour):**
- **RunPod** (pricing page, updated 27 Sep 2026): RTX 4090 **$0.34** community / $0.74 secure; RTX 5090 **$0.69** / $0.99; A100 80 GB $1.19–1.59; H100 $1.99–3.49. Persistent storage volume $0.07/GB/month. One-click ComfyUI templates exist. **VERIFIED** — [runpod.io/pricing](https://www.runpod.io/gpu-cloud/pricing), [storage docs](https://docs.runpod.io/pods/pricing).
- **Vast.ai**: RTX 4090 ~$0.25–0.40/h on-demand, cheaper interruptible; setup more manual (COMMUNITY — [computeprices](https://computeprices.com/providers/vast/gpus/rtx4090)).
- Lambda/Paperspace pricier for this use; TensorDock has reported reliability problems (COMMUNITY).

**Break-even (own estimate):** a used 4090 (~$2,500) equals ~7,400 hours of RunPod 4090 time; a 5090 at street price equals ~7,800 hours of RunPod 5090 time. At ~10 hours/week of sprite sessions, that is **over a decade**. Even with storage (~$3–7/month for a 50–100 GB model volume) rental wins by a wide margin at your usage. Trade-offs: a few minutes of startup per session, uploading your pipeline scripts, and your data living on someone else's server (fine for sprite art).

**Recommendation:** don't buy now. Rent first to find out which models actually fix your problems, and only reconsider a purchase if you end up renting 20+ hours a week for months, or if 5090 prices fall back toward MSRP.

---

## Ranked recommendations

**1. Best moves on the current hardware (in order)**
1. **Swap flood-fill for BiRefNet (matting)** — cheap, MIT, directly fixes problem 4. Keep BEN2 as the white-armour fallback.
2. **Add Z-Image (base for quality with negative prompts; Turbo for fast drafts)** as the generator — Apache 2.0, fits at full precision, expected to fix much of problems 1, 2 and 5. Test it head-to-head against SDXL on your hardest prompts (rocket launcher, lance, upright rifle, halo, capsule shapes, sci-fi gothic).
3. **Add Qwen-Image-Edit-2511 (GGUF Q4_K_M) + the fal Multiple-Angles LoRA** for re-angling approved units and fixing single missing details. Slow on this card, but it's the first commercially-usable tool aimed at problem 3.
4. Later: an SDXL or Z-Image **style LoRA** trained on your own finished sprites (possibly in the cloud) to lock the faction look.

**2. New GPU or cloud?** Rent first (RunPod RTX 4090 at ~$0.34/h or 5090 at ~$0.69/h). A $5–20 test weekend answers whether Qwen-Edit at full quality and the bigger models are worth it. Buying at today's inflated prices (4090 ~$2,500 used, 5090 ~$3,700–6,000) makes no financial sense at a few hours a week.

**3. Licence red flags**
- ⛔ **FLUX.1 [dev], FLUX.1 Kontext [dev], FLUX.2 [dev], FLUX.2 [klein] 9B** — non-commercial without a paid BFL licence. (klein **4B** and FLUX.1 schnell are Apache 2.0 — fine.)
- ⛔ **RMBG-2.0 / 1.4** — CC BY-NC; many background-removal nodes use it by default, and so does the **`rembg` tool** unless you pick another model.
- ⚠ **TRELLIS.2** — model is MIT, but its nvdiffrast dependency is NVIDIA non-commercial.
- ⛔ **Qwen-Image 2.1** — reportedly moved to a non-commercial research licence (older Qwen-Image and Qwen-Image-Edit-2511 remain Apache 2.0).
- ⚠ **SD 3.5, Stable Fast 3D** — free only under $1M/yr revenue.
- ⚠ **Tencent Hunyuan licences** — MAU caps and regional exclusions; Hunyuan3D 3.0 reportedly non-commercial.
- ⚠ **Civitai LoRAs** — per-model permissions; check each, and never use one trained on a non-commercial base.
- ⚠ General: keep a simple record of which model/LoRA/licence produced each shipped asset (Steam's AI-content disclosure also asks what was AI-generated).

**Unverified items to confirm before committing:** actual speed of Qwen-Edit-2511 on the 6900 XT; how well it preserves detailed designs at isometric angles; SDXL LoRA training on RDNA2 + ROCm 7.2; Chroma's VRAM fit; Hunyuan3D licence details; Qwen-Image 2.1 licence change.
