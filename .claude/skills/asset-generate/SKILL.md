---
name: asset-generate
description: "Generate image assets through the local ComfyUI API from the project's asset specs and generation prompts, stage them in art-source/, and promote approved runtime-ready files into assets/art/ with manifest updates. Audio generation is stubbed until an audio model is installed. Run after /asset-spec has produced specs; validate results with /asset-audit."
argument-hint: "[ASSET-ID | asset-name | audio:<name>] [--variant rush|boom|neutral|all] [--seed N] [--count N] [--prompt \"...\"]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion
---

Generates images by driving `tools/asset-pipeline/comfyui_generate.py`, which talks
to the local ComfyUI server (auto-started if down; the machine's LACT "ai-compute"
GPU profile engages automatically — never touch GPU clocks/power from this skill).

## Phase 0: Parse Arguments

- `ASSET-ID` (e.g. `ASSET-001`) or asset name (e.g. `hq`) — the asset to generate.
- `audio:<name>` — **audio is stubbed**: see "Audio Stub" below; do not attempt generation.
- `--variant` — faction hue(s): `rush` (default first), `boom`, `neutral`, or `all`.
- `--seed N` — reuse a specific seed (for hue-variant consistency or reproduction).
- `--count N` — exploration mode: N generations with fresh seeds for one look.
- `--prompt "..."` — ad-hoc prompt override (concept exploration outside the spec set;
  output still goes to `art-source/generated/adhoc/`, never directly to `assets/`).

No arguments → read `design/assets/asset-manifest.md`, list assets with status
`Needed` or `In Progress`, and ask which to generate via `AskUserQuestion`.

## Phase 1: Gather Context (read before asking anything)

- `design/assets/asset-manifest.md` — the asset's status, category, spec file.
- `design/assets/specs/generation-prompts.md` — the asset's paste-ready
  **Prompt**/**Negative** blocks per hue. This is the preferred prompt source.
- The asset's spec file (e.g. `design/assets/specs/vs-entities-assets.md`) —
  dimensions, naming, art-bible anchors. Fall back to its Generation Prompt if the
  asset is missing from generation-prompts.md; if both are missing, offer to run
  `/asset-spec` first or accept a user-supplied prompt.
- `assets/art/README.md` — runtime placement + naming rules (§8.2 patterns).

## Phase 2: Plan and Confirm

Present a short plan: asset, hue variants, resolution (default 1024×1024 — SDXL
native; author-large-then-downscale per art-bible §8.3), seed policy, output paths.
Confirm via `AskUserQuestion` before generating.

**Seed policy (art-bible shared-silhouette rule):**
1. Generate the FIRST hue (rush unless told otherwise) with a random seed. The
   script prints `seed=N` — record it.
2. Additional hues reuse that seed with only the hue words changed.
3. **Known limitation (verified 2026-08-12):** same-seed txt2img hue swaps can still
   drift composition badly. After generating variants, compare silhouettes; if they
   drifted, tell the user and recommend the reliable path — approve ONE base look
   and derive hue variants by accent recolor in an editor (or img2img later). Do not
   present drifted variants as a matched set.

## Phase 3: Generate

For each planned generation, run from the project root:

```
python3 tools/asset-pipeline/comfyui_generate.py \
  --prompt "<Prompt block>" --negative "<Negative block>" \
  [--seed N] --out art-source/generated/<asset-id>-<slug>/ --name <slug>_<hue>_base
```

- Raw generations ALWAYS land in `art-source/generated/` (source art lives outside
  `assets/` — art-bible §8.1). The script never overwrites; repeats get `_2`, `_3`.
- First generation can take ~2–3 min extra if the server was cold (model load +
  ROCm kernel compile); subsequent images take ~20 s each.
- On script error, read its stderr — it distinguishes server-start failure
  (check `~/ComfyUI/.server.log`), timeout, and rejected workflow.

## Phase 4: Review

Read each generated PNG into the conversation so the user sees it. Expect
iteration — SDXL routinely drifts from spec (wrong composition, ignored negative
terms). Offer via `AskUserQuestion`:
- Accept a result (per hue)
- Regenerate with fresh seeds (`--count 3` exploration is often faster than
  one-at-a-time)
- Adjust the prompt (strengthen weak constraints, e.g. "single isolated building,
  centered, lone structure" when it paints a scene) — note manual prompt tweaks in
  the review summary so /asset-spec can fold improvements back into the spec file

## Phase 5: Promote Approved Assets

Raw approved images STAY in `art-source/generated/` as the base-look source.
Promotion into `assets/art/` happens only for **runtime-ready** files:

- Terrain tiles / UI elements with no alpha or post-work needs may be promoted
  directly: copy to `assets/art/<category>/` under the exact §8.2 name (e.g.
  `tile_plain_clean.png`), then run `./redot --headless --import` and remind the
  user to commit the PNG **and** its `.png.import` sidecar together.
- Units and structures normally need post-work first (background removal to
  8-bit+alpha PNG, downscale to §8.3 tier, facings/states derivation). Do NOT
  place non-alpha 1024px raws in `assets/art/` — say what post-work remains.
- Ask "May I write to [path]?" before every copy into `assets/` (collaboration
  protocol). Never delete or overwrite an existing runtime asset without approval.

## Phase 6: Update the Manifest

After any accepted generation, ask to update `design/assets/asset-manifest.md`:
- `Needed` → `In Progress`, with a note: `base look generated [date], seed N,
  art-source/generated/<dir>/` (seed recorded so variants stay reproducible).
- Only `/asset-audit` + user approval move an asset to `Done`/`Approved` — this
  skill never marks assets Done.

## Audio Stub

Audio generation is NOT yet available. If asked for audio, explain:
1. ComfyUI currently has only SDXL (images). Audio needs an audio model — e.g.
   Stable Audio Open (SFX/ambient, ~47 s clips, gated Hugging Face download
   requiring a free account) or ACE-Step (music, ungated) — placed in
   `~/ComfyUI/models/checkpoints/` plus an audio workflow graph in the bridge script.
2. The project has no audio specs yet (audio is non-gating for the VS; descriptions
   live in `design/gdd/game-hud.md` §Audio). Run `/asset-spec` for audio entries first.
3. Offer to set this up when the user wants — it is a deliberate later phase.

## Error Recovery

- **Server won't start**: read `~/ComfyUI/.server.log` tail; report, don't loop.
- **Generation extremely slow (>5 min/image warm)**: the LACT "ai-compute" GPU
  profile may not have engaged; check `head -3 /sys/bus/pci/devices/0000:03:00.0/pp_od_clk_voltage`
  expecting a 2000 MHz cap while ComfyUI runs. Report findings — do not change GPU
  settings from this skill.
- **ComfyUI rejects the workflow**: the API surface changed (update pulled a new
  ComfyUI). Surface the HTTP error body and stop.
- Always report partial results — N of M variants generated is still progress.

## Collaborative Protocol

**Plan → Confirm → Generate → Review → Approve → Place → Update manifest.**
Never generate without a confirmed plan, never promote into `assets/` without
per-file approval, never commit without user instruction.
