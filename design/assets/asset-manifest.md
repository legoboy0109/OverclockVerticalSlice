# Asset Manifest

> Last updated: 2026-08-19 (roster-completion session — ASSET-008..011 authored and shipped)
> Master index of every specced game asset. IDs are sequential across the whole project.

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 12 | 0 | 1 | 11 | 0 |

> ✅ **The VS roster has NO missing art** (re-verified 2026-08-25 after the Builder landed). Every
> buildable structure and producible unit resolves a real texture in all three hues plus a
> destroyed state and a glow mask. Regression guards live in `entity_sprite_feed_test.gd`
> (`test_every_vs_type_now_has_shipped_art`) and `glow_uniform_state_test.gd`
> (`test_every_vs_type_now_has_a_shipped_glow_mask`).
>
> ⚠⚠ **That guarantee was FALSE between 2026-08-19 and 2026-08-25, and the guards did not catch
> it.** Both tests carried their own hand-written list of the nine types, so they only ever
> guarded what somebody had remembered to transcribe into them. The **Builder** shipped as a
> playable unit with no art at all, the board drew a magenta placeholder, and the suite stayed
> green — the exact failure the sentence above claimed was impossible. Both guards now enumerate
> `UnitTypes.ALL` / `StructureTypes.ALL`, so adding a `.tres` extends the guard by itself. ★ The
> lesson generalises: **a coverage check that keeps its own copy of the thing it covers is not a
> coverage check.**

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
| ASSET-005 | Barracks *(was Production Outpost)* | Structure | rush/boom/neutral | Done (idle) | **Base look approved 2026-08-18: `art-source/generated/asset-005-production-outpost/outpost_rush_r5_c3.png`** (seed 1143338806, round-5 recipe in generation-prompts.md). ★ **Bay is a glowing OPEN TOP, not a front-face mouth** — approved deviation from the spec's §3.2 reading (see the spec's Bay Aperture note). Verified against the HQ at board scale: distinct silhouettes in colour *and* grayscale. Post-work: downscale, boom/neutral via accent recolor, damaged/destroyed states |
| ASSET-006 | Plain terrain tile | Environment | faction-agnostic | In Progress | Flush `TileMapLayer` floor; no glow. `clean` variant in `assets/art/terrain/` — procedural draw (flat geometry; SDXL rejected). **Re-authored at 2× (256×128) 2026-08-19** to match units/structures/cover; the original draw script was never committed, so `tools/asset-pipeline/draw_plain_tile.py` is now the source of truth — it reproduces the approved 1× art **byte-identically**, which is what makes the 2× a faithful re-author rather than new art. Tessellation verified: **zero gaps**. ✅ **Wear variants done 2026-08-19** — `cracked` + `scorched`, identical 16640-px footprint (drop-in swappable), values darker than the floor per §6.4 |
| ASSET-007 | Cover terrain tile | Environment | faction-agnostic | Done (clean) | **Drawn procedurally**, not generated — same call as ASSET-006, plus cover must sit on the plain tile's exact 2:1 footprint to stay drop-in composable, which a generator cannot hit. `assets/art/terrain/tile_cover_clean.png` (256×184 @2×) is the **cover-mass prop only**; §8.8's floor cell is `tile_plain_clean.png` reused. Faceted in **L only** (§4.1) — top face `#33405A`, side faces stepped down. Mass inset from the cell edge so it reads as an object breaking the floor, not a raised tile (§6.3). Y-sort occlusion verified against units on adjacent rows. Tool: `tools/asset-pipeline/draw_cover_tile.py`. ✅ **Wear variant done 2026-08-19** — `chipped-corner`, a real sheared-corner **silhouette notch** (§6.2/§6.5), reads in colour *and* grayscale |

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

| ASSET-012 | Builder | Infantry (4 facings) | rush/boom/neutral | Done (idle) | ★ **Squat four-legged CARRIER walker** — body plan chosen by user 2026-08-25; **re-proportioned shorter and bulkier at user request 2026-08-26** (`builder_rush_r6_c2.png`, seed 1510903717, superseding r3_c2 which read too tall and leggy). The body now dominates the silhouette and the legs are short and crouched. ⚠ The overall sprite aspect barely moved (0.95 → 0.97) — what changed is the **body-to-leg ratio**, which no bounding-box metric detects; judge it by eye. ⚠ Three rounds to get there: shrinking the legs makes SDXL **delete** them (legless sled, tracked barge), and piling on bulk words displaced the grey/four-leg clauses entirely. **Crouching the legs is the lever, not scaling them.** ★ **Cargo cradle DRAWN and composited 2026-08-26** (`tools/asset-pipeline/draw_cargo_cradle.py`) after two further generation rounds could not put a legible one on its back without undoing the body — prompt weight is finite, so strengthening the cradle clause restored the shadow/orange/long-leg failures. Sprite grew 145 → 157 px tall as a result; a visible cradle and a minimal silhouette are opposed and this is the chosen point on that trade. Its cast shadow WAS liftable (machine luma 99 vs shadow 117 — unlike r2, where they measured identical), via a border flood plus an enclosed-pocket clear for the patch walled in by the legs. The roster's only support unit; defenceless and consumed by the structure it raises, so the silhouette must read "not a soldier". Sized by **width** at 140px — narrower than the Scout's 148 so the two four-legged units stay tellable apart. ⚠ **Base look was NOT user-approved**; it was selected by the session and then re-proportioned on user feedback. Full post-mortem — including round 1's orange-dominance and round 2's genuinely unremovable shadow — in `generation-prompts.md` |
| ASSET-008 | Sniper | Unit | rush/boom/neutral | Done (idle) | **Base look approved 2026-08-19: `art-source/generated/asset-008-sniper/sniper_rush_r6_c1.png`** (seed 1599279841). Was "deferred" in the spec until the renderer made its absence visible. Ships at **h=156**, the tallest infantry — §3.1 puts it opposite the Scout on the posture axis, and that ratio is the primary thumbnail read. ⚠ Value-corrected in post: the raw generation came out at luma 0.253 against the roster's 0.355, i.e. the "units must be LIGHTER than the stage" defect the infantry session documented, hit again |
| ASSET-009 | Factory *(was Economy Outpost)* | Structure | rush/boom/neutral | Done (idle) | **Base look approved 2026-08-19: `econ_rush_r5_c2.png`** (seed 2305656182). §3.2 identifier: low + wide, horizontal emphasis, collector forms. Took **5 rounds** — "solar array / collector panels" reliably summons a whole city block (the same failure `factory` has); the singular `bunker` noun plus angled intake vanes is what converged |
| ASSET-010 | Defensive Structure | Structure | rush/boom/neutral | Done (idle) | **Base look approved 2026-08-19: `def_rush_r2_c2.png`** (seed 3933358768). §3.2 identifier: compact/thick/symmetrical with one dominant elevated emplacement breaking the top. Cleanest convergence of the four — **2 rounds** |
| ASSET-011 | Research Lab | Structure | rush/boom/neutral | Done (idle) | **Base look approved 2026-08-19: `lab_rush_r6_c2.png`** (seed 4290549827). §3.2 identifier: tall-thin mast on a small base, the most delicate silhouette. Took **6 rounds** — and the fix was a NOUN swap, not adjectives: the shared scaffold says `bunker`, which is squat and monolithic by definition and beat every "tall thin delicate" adjective for five rounds. `antenna tower structure` converged on the next round. See generation-prompts.md rule 12 |

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
