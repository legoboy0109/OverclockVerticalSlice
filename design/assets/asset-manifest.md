# Asset Manifest

> Last updated: 2026-08-19 (infantry session — ASSET-002/003/004 base looks approved)
> Master index of every specced game asset. IDs are sequential across the whole project.

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 7 | 0 | 1 | 6 | 0 |

> **"Done (idle)"** = base look approved, cleaned, all 3 hues, facings, and placed in
> `assets/art/` with import sidecars — but **`idle` frame 01 only**; the §8.5 state sets
> (move/attack/hit/destroyed) and structure damage tiers are NOT authored.
> "Needed" = specced, awaiting art production. Each unit/structure ships in **3 hue variants**
> (rush / boom / neutral) and — for units — 4 facings × the §8.5 state set; terrain ships one
> faction-agnostic sprite per wear-variant. Production quantity ≫ the 7 spec entries.

## Assets by Context

### Vertical Slice: Entities & Terrain
Spec file: `design/assets/specs/vs-entities-assets.md` · Source: `design/assets/entity-inventory.md`
Paste-ready prompts (hues pre-expanded): `design/assets/specs/generation-prompts.md`

| Asset ID | Name | Category | Hue variants | Status | Notes |
|----------|------|----------|--------------|--------|-------|
| ASSET-001 | HQ | Structure | rush/boom/neutral | Done (idle) | Largest sprite; atlas anchor / 4096-escalation risk. **Base look approved 2026-08-18: `art-source/generated/asset-001-hq/hq_rush_r7_c2.png`** (seed 3566038092, round-7 light-background recipe in generation-prompts.md addendum). **Supersedes `hq_rush_r5_c3`** — that one rendered its base-plate as light off-palette pavement and carried 7 lamp-post props, both only visible once composited at board scale. Post-work: ✅ shadow cleaned (`art-source/cleaned/hq_rush_r7_c2_clean.png`); remaining: downscale, boom/neutral via accent recolor, damaged/destroyed states. bg→alpha is now tooled (`tools/asset-pipeline/cutout.py`) |
| ASSET-002 | Scout | Infantry (4 facings) | rush/boom/neutral | Done (idle) | ★ **Body plan changed to a low four-legged WALKER** (user-approved 2026-08-19) — humanoid proportions never produced §3.1's locomotion-led read. **Base look approved: `art-source/generated/asset-002-scout/scout_rush_r9_c2.png`** (seed 1383706175). Sized by **width** ~74px. ✅ shadow cleaned (`art-source/cleaned/scout_rush_r9_c2_clean.png`). Post-work: boom/neutral accent recolor, facings, states |
| ASSET-003 | Trooper | Infantry (4 facings) | rush/boom/neutral | Done (idle) | ★ **Authored FIRST as the family's control group** — Scout and Heavy body plans were derived from its recipe. **Baseline approved: `art-source/generated/asset-003-trooper/trooper_rush_r7_c1.png`** (seed 3049366272), shadow-free. Upright biped, ~65px tall |
| ASSET-004 | Heavy | Infantry (4 facings) | rush/boom/neutral | Done (idle) | ★ **Body plan changed to a squat siege WALKER** (user-approved 2026-08-19) — "Trooper scaled up" read too close to the Trooper to pass the §5.2 grayscale role test. **Base look approved: `art-source/generated/asset-004-heavy/heavy_rush_r9_c2.png`** (seed 1840110820). ~74px tall; still the atlas-width driver. ⚠ shadow not removable (overlaps its own plating) but **invisible at board scale** — accepted; master `art-source/cleaned/heavy_rush_r9_c2_clean.png`. Post-work: variants |
| ASSET-005 | Production Outpost | Structure | rush/boom/neutral | Done (idle) | **Base look approved 2026-08-18: `art-source/generated/asset-005-production-outpost/outpost_rush_r5_c3.png`** (seed 1143338806, round-5 recipe in generation-prompts.md). ★ **Bay is a glowing OPEN TOP, not a front-face mouth** — approved deviation from the spec's §3.2 reading (see the spec's Bay Aperture note). Verified against the HQ at board scale: distinct silhouettes in colour *and* grayscale. Post-work: downscale, boom/neutral via accent recolor, damaged/destroyed states |
| ASSET-006 | Plain terrain tile | Environment | faction-agnostic | In Progress | Flush `TileMapLayer` floor; no glow. `clean` variant in `assets/art/terrain/` — procedural draw (flat geometry; SDXL rejected). **Re-authored at 2× (256×128) 2026-08-19** to match units/structures/cover; the original draw script was never committed, so `tools/asset-pipeline/draw_plain_tile.py` is now the source of truth — it reproduces the approved 1× art **byte-identically**, which is what makes the 2× a faithful re-author rather than new art. Tessellation verified: **zero gaps**. Wear variants pending |
| ASSET-007 | Cover terrain tile | Environment | faction-agnostic | Done (clean) | **Drawn procedurally**, not generated — same call as ASSET-006, plus cover must sit on the plain tile's exact 2:1 footprint to stay drop-in composable, which a generator cannot hit. `assets/art/terrain/tile_cover_clean.png` (256×184 @2×) is the **cover-mass prop only**; §8.8's floor cell is `tile_plain_clean.png` reused. Faceted in **L only** (§4.1) — top face `#33405A`, side faces stepped down. Mass inset from the cell edge so it reads as an object breaking the floor, not a raised tile (§6.3). Y-sort occlusion verified against units on adjacent rows. Tool: `tools/asset-pipeline/draw_cover_tile.py`. Wear variants pending |

**★ Unit spec amendment (2026-08-19, user-approved):** unit armour is **`#6E7C99` slate**, not the
`#232A38` terrain-tile family the specs originally named — units were invisible against the board and
failed the art bible's grayscale outline test. On-screen size raised from ~24–40px to ~60–74px. Role
separation is by **body plan**, not proportion adjectives. Full rationale in
`design/assets/specs/vs-entities-assets.md` (Unit Spec Amendment) and the art bible §5.1.

**★ Hue variants complete (2026-08-19):** all 5 approved assets now exist in **rush / boom /
neutral** in `art-source/cleaned/` (15 masters). Only rush is generated; boom and neutral are
derived with `tools/asset-pipeline/recolor.py`, preserving the shared silhouette per rule 1.
**Brightness is remapped in luma, not HSV value** (`recolor.py --scale luma`, the default): value
scaling made the grayscale result depend on saturation, so shaded accent barely moved and the armies
sat only ~18/255 apart. Luma scaling roughly doubles it — rush ≈98 vs boom ≈133 (**Δ~34**), neutral
≈165 (Δ~67 vs rush).
⚠ **Residual accessibility gap:** Δ34/255 (13%) is a real improvement but **not a fix**. Grayscale
ownership now reads on *structures* (large trim area) and is still **marginal on units** at 65–74px.
Role silhouettes separate fine without hue; army ownership does not. The art bible's deferred
**non-hue ownership markers** (trim pattern / emblem / silhouette-family trait) remain the actual
fix — this is the measured number for that work.

**★ ASSET-007 cover (2026-08-19):** ships as **two layers**, not one tile — "one PNG = one
`TileMapLayer` cell" **breaks for cover**, which the spec says to flag to S4-03. Floor = the plain
tile reused; mass = a Y-sorted prop with a bottom-centre ground-contact pivot. Composition rule is
in `assets/art/README.md`.

**★ RUNTIME SET PLACED (2026-08-19):** 24 sprites live in `assets/art/` with Godot `.import`
sidecars generated (`./redot --headless --import`; mipmaps off, lossless, as the spec requires).
Written by `tools/asset-pipeline/place_runtime.py` — **re-runnable, so never hand-edit files under
`assets/art/`**; edit the master and re-run. Shipped at **2× on-screen size** per §8.3 (units
116–148px, HQ 512px, Outpost 384px). Only `e`/`w` facings and only `idle` frame `01` exist — the
renderer contract, including the facing→sprite mapping and the bottom-centre pivot rule, is written
into `assets/art/README.md`, which S4-03 should read first.
⚠ Flagged, not fixed: `tile_plain_clean.png` is 128×64 (**1×**) while everything else ships 2× —
reconcile when ASSET-007 lands.

**★ Facings (2026-08-19, user-approved):** units ship **2 authored sprites, not 4** —
`art-source/facings/unit_<archetype>_<faction>_<e|w>.png` (18 files: 3 units × 3 hues × 2). `n`
aliases `e` and `s` aliases `w`; the renderer picks by sign of screen-x travel. Bare SDXL cannot
rotate a specific design (verified — "side profile" prompts return front views, back views drift
into a different machine), and **nothing in the game reads facing**: no facing/flanking/rear combat
modifier, no registry field, and neither S4-03 nor the S4-04 gate requires it. Cue strength: Scout
clear, Heavy noticeable, Trooper near-symmetric so nearly a no-op. True authored n/e facings are
deferred post-VS. Full rationale + the mapping table in `vs-entities-assets.md`.

**★ Cleaned masters (2026-08-19):** every approved base look now has a cut-out, shadow-cleaned
master in **`art-source/cleaned/`** (tracked in git — unlike the raw generations). **All downstream
work — hue variants, facings, damage states, downscales — derives from the cleaned master, never
from the raw generation.** Settings and the one exception (Heavy) are in the shadow-cleanup table in
`design/assets/specs/generation-prompts.md`.

**Cross-cutting notes:** all actors share ONE `ShaderMaterial` (per-instance uniforms for hue/glow,
§8.7/§8.9, S4-01-confirmed). Ownership-by-hue VS wiring (Rush vs Boom) + engine faction-pin change is
the S4-03 follow-up (see the spec's Scope Reconciliation). Mass-Distribution-Bias silhouettes deferred
to Full Vision — VS variants are re-hues of one silhouette per role.
