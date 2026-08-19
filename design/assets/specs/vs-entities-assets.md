# Asset Specs — Vertical Slice: Entities & Terrain

> **Source**: `design/assets/entity-inventory.md` (VS entity set) + `design/registry/entities.yaml` (stats)
> **Art Bible**: `design/art/art-bible.md` (hues LOCKED by the S4-01 de-risk spike)
> **Generated**: 2026-07-29 (Sprint 4 · S4-02; art-director + technical-artist, `/asset-spec` full mode)
> **Status**: 7 assets specced / 0 approved / 0 in production / 0 done

---

## Scope Reconciliation (READ FIRST)

Covers the 5 VS entities + 2 terrain tiles, spec'd against the S4-01-locked art direction. Two
merge-time conflicts were resolved; one cross-doc/engine inconsistency is flagged for follow-up.

1. **Ownership model — author ALL THREE hue variants (`rush` / `boom` / `neutral`); wire
   Rush-vs-Boom for the VS (recommended).** The sources conflict: the engine
   (`src/game/vertical_slice_root.gd:146-147`) pins both players to `Factions.NEUTRAL`; art-bible
   §4.2 describes a *Neutral-vs-Neutral mirror*; but `entity-inventory.md` #1 **and** scope §5's
   iso-legibility acceptance (*"ownership clear by hue"*) require two distinct hues. **Decision
   (2026-07-29):** author every unit/structure in all three hues so the VS can wire whichever model.
   **For ownership-by-hue play — what the S4-04 iso-legibility gate requires — the VS should wire
   `LOCAL_PLAYER → Rush`, `AI_PLAYER → Boom`** (a ~2-line engine change to the faction pins, folded
   into S4-03). The `neutral` variant covers menu/showroom + future use. NOTE: a *true*
   Neutral-vs-Neutral mirror (both achromatic) cannot distinguish ownership by hue and would
   additionally need per-owner non-hue markers (still deferred — see flag 3b).

2. **Shared silhouettes, hue-only (Mass Distribution Bias DEFERRED).** Per entity-inventory #1, VS
   units share one silhouette per role across factions; the per-faction §5.2 Mass-Distribution-Bias
   silhouettes (the 3× cost driver) defer with Pillar-4 faction asymmetry. **The three hue variants
   are RE-HUES of one silhouette per role, NOT distinct geometry** — structures likewise (§8.7's
   3×-silhouette driver is units-only; structures re-hue the same mesh/sprite).

3. **Documentation debt (flagged, non-blocking):**
   - (a) Art-bible §4.2's "Neutral-vs-Neutral mirror (which the VS ships)" is superseded by the
     Rush-vs-Boom wiring recommendation here + scope §5's hue-acceptance — reconcile via a §4.2/§5.2
     addendum (cross-ref note added this session).
   - (b) The engine faction pins (both `NEUTRAL`) are a stale Setup placeholder — update when art lands.
   - (c) Structure damage-tier counts + the HQ produce-beat frame count are extrapolations (§8.5's
     state table is unit-specific) — confirm against `base-production.md` before backlog estimation.

---

## Shared Conventions (all assets)

- Runtime **PNG 8-bit + alpha** (§8.1); source layered `.kra`/`.aseprite`/`.psd`, one per asset
  family (all facings/states as layer groups), kept outside `assets/`. No JPEG anywhere.
- **Author flat-vector hi-res, then downscale** (§8.3) — not committed pixel art; keeps the §2 glow
  falloff soft and serves 1080p + 1440p from one source.
- **2:1 dimetric iso.** Units = **4 facings** `n`/`s`/`e`/`w` (`w` = engine horizontal-flip of `e`
  where mirror-safe — confirm no asymmetric kit detail before flipping). Structures + tiles are
  static / non-directional (§8.4).
- **Y-sort pivot at ground-contact bottom-center** of the footprint (§8.4/§8.8), never bbox center.
- **Separate greyscale emission/glow-mask pass** alongside each base-color pass, feeding **one
  shared `canvas_item` `ShaderMaterial`** with per-instance uniforms (`faction_hue`, `pulse_intensity`
  via `set_instance_shader_parameter`) — **never a per-unit/structure material resource** (§8.7 rule
  2 / §8.9, confirmed by the S4-01 spike). Terrain carries no glow layer.
- **Lossless export, mipmaps off** (fixed iso camera) (§8.6/§8.9).
- **Destroyed = 2–4 frames (LOCKED)** — power-down/collapse, no gibs (§8.5).
- Naming per §8.2; faction tokens `rush` / `boom` / `neutral` (match `entities.yaml`).
- **Hue anchors (S4-01 LOCKED):** Rush `#FF5A2E`, Boom `#22C7F0`, Neutral `#C6CED8` (achromatic).
  Dark stage: void `#0A0E17`, terrain base `#232A38`, elevated/cover `#33405A`, recessed `#171C27`,
  structure base-plate `#1B2130`.

> **Generation-prompt hue token:** each unit/structure prompt below carries a
> `[faction accent: rush #FF5A2E | boom #22C7F0 | neutral #C6CED8]` slot — run the prompt once per
> hue variant, swapping only that token. For `neutral`, the accent is achromatic silver and ownership
> leans on the (deferred) non-hue markers, so use it for menu/showroom, not a two-Neutral board.

---

## ASSET-001 — HQ (`struct_hq`)

| Field | Value |
|-------|-------|
| Category | Structure (static, non-directional) |
| Dimensions | Multi-tile footprint, tallest structure — **the biggest per-sprite atlas item** (§8.3). Author to footprint (no fixed px tier for structures). |
| Format | PNG 8-bit+alpha; one layered source (states as layer groups); lossless; mipmaps off |
| Naming | `struct_hq_[faction]_[state].png` — e.g. `struct_hq_rush_idle.png`, `struct_hq_boom_produce-beat.png`, `struct_hq_neutral_destroyed_02.png` |
| Facings | N/A (static) |
| Hue variants | 3 (rush / boom / neutral) — re-hue, same geometry |

**Visual Description:** The tallest, largest-footprint structure — a multi-tile stacked/extruded
rectilinear volume rising to a single massed central spire on a broad base-plate, unmistakably the
board's visual keystone (§3.2). Static, flat hard-surface matte plating in the structure-base value
`#1B2130`, with `#33405A` value-lifted upper facets, a faction-hue accent band wrapping the
base-plate/lower mass, and a neon glow-trim riding the spire's upper edges. Ships complete (no
construction variant).

**Art-Bible Anchors:** §3.2 (structure grammar, HQ as keystone silhouette), §3.5 (mid-shape
complexity), §4.1/§4.2 (structure-plate hex + faction accent only), §6.2 (flat/painted, no PBR),
§8.4 (dimetric, ground-contact pivot), §2.1 (glow-breathe idle / production-ready cue).

**Generation Prompt:** `flat cel-shaded isometric sci-fi capital structure, 2:1 dimetric projection,
massive stacked rectilinear tower on a wide flat base-plate, single dominant central spire,
hard-surface matte plating, no PBR no specular, no greeble, large simple panel shapes, base color
#1B2130 with #33405A value-lifted upper facets, neon trim glow accent in [faction accent: rush
#FF5A2E | boom #22C7F0 | neutral #C6CED8] along spire edges and base-plate rim rendered as a thin
emissive line, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting,
clean hard edges, orthographic dimetric camera` — **Negative:** `photoreal, PBR, specular, greebles,
rivets, panel-line noise, organic/rounded shapes, gradient sky, full-image bloom, saturated ground,
face, character, text, watermark, 3/4 or top-down perspective, additional unlisted hues, rust/grime`

**States (§8.5):** idle (steady + faction-hue block + powered glow) · produce-beat (flare-and-decay
pulse tied to production, §2.2 — *frame count owed to base-production.md*) · damaged tiers (hp 40 →
multiple tiers, *count owed to base-production.md*) · destroyed 2–4f. Base + glow-mask each.

**Flags:** biggest single atlas item → the most likely 2048² page-ceiling pressure; if HQ + the rest
of the structure roster can't share one 2048² page at author-res, that's the **4096 escalation
trigger** (§8.7 rule 4) — surface to lead before assuming 4096. Structure state list (produce-beat,
damaged tiers) is an extrapolation from §3.2 — confirm before backlog estimation.

---

## ⛔ UNIT SPEC AMENDMENT — 2026-08-19 (read before generating any unit)

Three user-approved changes supersede the ASSET-002/003/004 fields below. They came out of a
39-generation infantry session; the evidence and the proven prompts are in
`design/assets/specs/generation-prompts.md`.

1. **Armour value: `#6E7C99` slate, NOT the `#232A38`-family.** The original text specified unit
   armour in the *same value family as the plain terrain tile* (`#232A38`, ASSET-006), so units
   disappeared into the board — at sprite size only the accent trim survived, and in grayscale they
   failed §3.5 (identifiable by outline alone) outright. `#6E7C99` clears every stage tile
   (luma Δ82 vs base, Δ60 vs max-elevation `#33405A`) and stays Δ82 below Neutral silver `#C6CED8`.
   **Structures stay near-black; actors are the light objects on a dark stage.**
2. **On-screen size: ~60–70px tall, not ~24–40px.** At the original size the silhouette was mush
   even at 1.5× spec. Sizing note per role: the **Scout is sized by WIDTH** (~74px — it is the long
   low one), Trooper ~65px tall, Heavy ~74px tall. Heavy remains the atlas-width driver.
3. **Role separation is by BODY PLAN, not by proportion adjectives.** Adjectives never moved the
   humanoid silhouette off upright — all three roles collapsed into one shape and failed the §5.2
   grayscale role test. The approved roster:
   - **Scout** → low **four-legged walker**, headless, long horizontal body, forward sensor block.
     This is what finally delivers §3.1's "outline dominated by locomotion."
   - **Trooper** → the upright **armored sentinel** biped (unchanged; the §3.1 control group).
   - **Heavy** → **squat siege walker**, no neck, slab shoulders, short piston legs planted wide.

   The art bible already permits this: §5.1 is explicitly body-plan-agnostic and §3.1 names
   "legs/wheels/treads" as the Scout's locomotion read. Verified: the three silhouettes separate in
   grayscale with no hue information.

> The "sealed helmet / no face" rule (§5.1) still binds the **Trooper**. The Scout and Heavy walkers
> are headless chassis, which satisfies the same underlying rule — no face to compete with the neon
> state layer — by having no head at all.

---

## ASSET-002 — Scout (`unit_scout`)

| Field | Value |
|-------|-------|
| Category | Infantry unit |
| Dimensions | **~74px on-screen WIDTH** (sized by width — the long low walker); author ~72–120px/facing (§8.3), canvas wide for the four-leg splay. *Amended 2026-08-19 — was ~24–40px height.* |
| Format | PNG 8-bit+alpha; layered source (4 facings as layer groups); lossless; mipmaps off |
| Naming | `unit_scout_[faction]_[facing]_[state]_[frame].png` — e.g. `unit_scout_rush_n_idle_01.png`, `unit_scout_boom_e_move_03.png` |
| Facings | 4 (`n/s/e/w`; `w`=flip(`e`) if symmetric — **confirm the lean/locomotion detail is mirror-safe**) |
| Hue variants | 3 (rush / boom / neutral) — re-hue of the shared Scout silhouette |

**Visual Description:** Sealed powered-armor infantry with a low, horizontal, forward-leaning
silhouette — the longest ground-footprint of the roster — with visible locomotion shapes implying
motion even at rest. Sealed helmet, no face, no visor-glow; chunky exaggerated mass proportions, the
*lowest/most horizontal* of the four archetypes. Matte flat-value hard-surface plating, large simple
trim shapes; faction hue is a flat color-block accent on plating only.

**☑ Approved base look (2026-08-19):** `art-source/generated/asset-002-scout/scout_rush_r9_c2.png`
(seed 1383706175). Low four-legged walker per the amendment above — supersedes the humanoid
"forward-leaning infantry" reading in the Visual Description. ✅ **Shadow cleaned 2026-08-19** —
derive everything from `art-source/cleaned/scout_rush_r9_c2_clean.png`
(`--deshadow --ink-ratio 0.62`; 0.50 eroded the feet).

**Art-Bible Anchors:** §5.1 (sealed helmet, chunky proportions, matte plating), §3.1 (Scout = low +
horizontal posture + locomotion appendage), §5.4 (no visor-eyes, utilitarian pose), §5.5
(silhouette→glow→color-block→detail LOD order), §8.4 (4 facings, ground-contact pivot). *§5.2
Mass-Distribution-Bias deferred — hue-only per VS scope.*

**Generation Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection,
sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders
short thick limbs compressed torso, low horizontal forward-leaning stance, visible leg/locomotion
silhouette implying speed, matte hard-surface plating flat color blocks large simple trim no greeble,
base armor dark neutral #232A38-family shading, faction accent color-block in [faction accent: rush
#FF5A2E | boom #22C7F0 | neutral #C6CED8] on chest/limb plating only, thin neon emissive trim on
armor edges, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, hard
edges, orthographic dimetric camera, single character full body, 4-directional iso facing sheet` —
**Negative:** `face, visible skin, eyes, glowing visor eyes, cartoon eye slit, photoreal, PBR,
specular, greebles, realistic human proportions, thin limbs, tall vertical stance, sniper barrel,
wide bottom-heavy mass, weapon longer than body, organic curves, cloth-sim, skin texture, unlisted
hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down perspective`

**States (§8.5, validate by prototype):** idle-AP (loop ~1–4f, glow-breathe, near-static pose) ·
idle-spent (**same pose**, glow-clamp only) · move (~4–6f — most-played move anim; must survive
repetition) · attack (~3–5f, flare-synced) · hit (~2–3f recoil) · destroyed 2–4f. × 4 facings ×
base+glow-mask × 3 hues.

---

## ASSET-003 — Trooper (`unit_trooper`)

| Field | Value |
|-------|-------|
| Category | Infantry unit |
| Dimensions | **~65px on-screen height** (mid-tier baseline); author ~72–120px/facing (least canvas-overhang of the three). *Amended 2026-08-19 — was ~24–40px.* |
| Format | PNG 8-bit+alpha; layered source; lossless; mipmaps off |
| Naming | `unit_trooper_[faction]_[facing]_[state]_[frame].png` — e.g. `unit_trooper_rush_n_idle_01.png` |
| Facings | 4 (`n/s/e/w`; **best mirror-flip candidate** — even mass, no dominant protrusion) |
| Hue variants | 3 (rush / boom / neutral) |

**Visual Description:** Sealed powered-armor infantry with the balanced, symmetrical, upright
rectangle silhouette that is the roster's control-group baseline — even mass top-to-bottom, no
dominant protrusion, paired symmetrical limbs/weapon at mid-height. Sealed helmet, no face; chunky
medium build (neither Scout-horizontal nor Heavy-wide). Matte flat-value plating; faction hue a flat
accent block only.

**☑ APPROVED BASELINE (2026-08-19):** `art-source/generated/asset-003-trooper/trooper_rush_r7_c1.png`
(seed 3049366272). Authored **first** as the family's control group per §3.1 — the Scout and Heavy
body plans were derived from this recipe by swapping only the shape/noun words. Shadow-free as
generated. Master: `art-source/cleaned/trooper_rush_r7_c1_clean.png`.
Supersedes `r6_c2` (seed 3228806907), which had a cast shadow fused to the feet.

**Art-Bible Anchors:** §5.1, §3.1 (Trooper = balanced-rectangle baseline; the reference silhouette
others are judged against), §5.4, §5.5, §8.4. *§5.2 deferred — hue-only.*

**Generation Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection,
sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders
short thick limbs, upright balanced symmetrical rectangle silhouette, medium even mass top to bottom
no dominant protrusion, weapon at mid-height, matte hard-surface plating flat color blocks large
simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in
[faction accent: rush #FF5A2E | boom #22C7F0 | neutral #C6CED8] on chest/shoulder plating only, thin
neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting,
hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet` —
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic
proportions, low horizontal lean, emphasized locomotion legs, wide bottom-heavy mass, long barrel,
organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark,
3/4 or top-down`

**States (§8.5):** as Scout (idle-AP / idle-spent-same-pose / move ~4–6f / attack ~3–5f / hit / dead
2–4f). × 4 facings × base+glow-mask × 3 hues. Trooper is the reference case for the §5.2 solid-black
silhouette validation test.

---

## ASSET-004 — Heavy (`unit_heavy`)

| Field | Value |
|-------|-------|
| Category | Infantry unit |
| Dimensions | **~74px on-screen height**; **width, not height, is the atlas driver** — author ~72–120px, canvas closer to square for the widest footprint (§8.3). *Amended 2026-08-19 — was ~24–40px.* |
| Format | PNG 8-bit+alpha; layered source; lossless; mipmaps off |
| Naming | `unit_heavy_[faction]_[facing]_[state]_[frame].png` — e.g. `unit_heavy_boom_w_attack_01.png` |
| Facings | 4 (`n/s/e/w`; confirm shoulder/weapon-mount symmetry before flipping `w`) |
| Hue variants | 3 (rush / boom / neutral) |

**Visual Description:** Sealed powered-armor infantry scaled up and widened from the Trooper baseline
— same DNA, more mass — with the widest footprint and bulkiest, bottom-heavy silhouette, broader
than tall. Sealed helmet, no face; blocky shoulder/chassis mass and short thick limbs read as armor,
not speed. Matte flat-value plating in large simple shapes; faction hue a flat accent block only.

**☑ Approved base look (2026-08-19):** `art-source/generated/asset-004-heavy/heavy_rush_r9_c2.png`
(seed 1840110820). Squat headless siege walker per the amendment above — supersedes the "infantry
scaled up and widened" reading in the Visual Description, which produced a silhouette too close to
the Trooper to pass the §5.2 grayscale role test. ⚠ **Shadow NOT removable** — a warm ground streak
whose luma overlaps this asset's own grey plating; every setting that lifted it ate the hands.
**Verified invisible at board scale (74px)**, so it is accepted. Master:
`art-source/cleaned/heavy_rush_r9_c2_clean.png` (pockets + largest-only, no deshadow).
See the shadow-cleanup table in `generation-prompts.md`.

**Art-Bible Anchors:** §5.1, §3.1 (Heavy = Trooper scaled up/widened, widest bottom-heavy mass, the
anvil), §5.4, §5.5, §8.4. *§5.2 deferred — hue-only.*

**Generation Prompt:** `flat cel-shaded isometric sci-fi heavy infantry soldier, 2:1 dimetric
projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions scaled
up and widened, widest bulkiest bottom-heavy silhouette broader than tall, blocky oversized shoulder
and chassis mass, short thick stubby limbs, immovable anvil stance, matte hard-surface plating flat
color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent
color-block in [faction accent: rush #FF5A2E | boom #22C7F0 | neutral #C6CED8] on chest/shoulder
plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON
synthwave lighting, hard edges, orthographic dimetric camera, single character full body,
4-directional iso sheet` — **Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular,
greebles, realistic proportions, thin limbs, low horizontal lean, tall narrow silhouette, long
barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text,
watermark, 3/4 or top-down`

**States (§8.5):** as Scout; Heavy's move timing reads "weighty" via posture/timing (§5.4), not a
frame-count exception. × 4 facings × base+glow-mask × 3 hues.

**Flags:** widest canvas → largest per-sprite atlas rect of the infantry set; with Scout/Trooper/
(Sniper, deferred) this is a 4096-escalation candidate alongside the HQ — factor into infantry-atlas
page planning. Confirm the ground-contact pivot sits at the true base center of the wide mass, not
the visual center (Y-sort accuracy).

---

## ASSET-005 — Production Outpost (`struct_production_outpost`)

| Field | Value |
|-------|-------|
| Category | Structure (static, non-directional) |
| Dimensions | Multi-tile, medium footprint (smaller than HQ); author to footprint. **No construction canvas** (pre-placed) |
| Format | PNG 8-bit+alpha; layered source; lossless; mipmaps off |
| Naming | `struct_production_outpost_[faction]_[state].png` — e.g. `struct_production_outpost_rush_idle.png` |
| Facings | N/A (static) |
| Hue variants | 3 (rush / boom / neutral) — re-hue, same geometry |

**Visual Description:** A smaller-footprint static structure than the HQ, from the same
stacked/extruded rectilinear family, distinguished by a distinct **open bay/aperture** where units
emerge — "the factory," an opening in the mass rather than a spire. Flat tile-aligned base-plate in
the structure dark-neutral value, matte hard-surface plating, a faction-hue accent band, and a
glow-state trim (idle-breathe vs clamp / production-ready cue). Pre-placed complete — no
construction sprite.

> ### ★ Bay Aperture — approved deviation (2026-08-18)
> This entry originally called for the bay as a **mouth cut into the front face**. The approved base
> look (`outpost_rush_r5_c3`) instead reads the bay as a **glowing open top**: a solid boxy mass whose
> roof opens onto a hot faction-hue interior.
>
> **Why this is better here, not just easier:** the board camera is fixed 2:1 dimetric and looks *down*
> into the mass, so an open top is visible from every approach, while a front-wall doorway is occluded
> whenever the structure faces away — and this asset has **no facings** (static, non-directional), so
> there is no rotation to bring a hidden mouth back into view. The production cue must read from one
> fixed angle, and the open top is the reading that does.
>
> **Legibility verified** at board scale (192px on 128x64 tiles) against the HQ, in colour *and*
> grayscale: tall spired vertical mass vs low cube — §5.2 role-silhouette separation holds without hue.
>
> Six generation rounds failed to produce a front-face version that held the locked palette (they
> drifted to roofless compounds, or dropped the faction hue entirely). Full detail in
> `generation-prompts.md`.

**Art-Bible Anchors:** §3.2 (Production Outpost = open-bay "mouth," smaller than HQ), §3.5,
§4.1/§4.2 (plate hex + faction accent), §6.2 (flat/painted), §8.4 (dimetric, no facings), §2
(glow-state = production-ready cue).

**Generation Prompt:** `flat cel-shaded isometric sci-fi factory structure, 2:1 dimetric projection,
medium stacked rectilinear structure smaller than a capital building, distinct open bay aperture cut
into the silhouette like a mouth where units emerge, flat tile-aligned base-plate, hard-surface matte
plating no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted facets,
neon trim glow accent in [faction accent: rush #FF5A2E | boom #22C7F0 | neutral #C6CED8] outlining
the bay aperture and base-plate rim as a thin emissive line, dark void #0A0E17 background, flat
painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera` —
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes,
tall central spire (reserved for HQ), gradient sky, saturated ground, face, character, text,
watermark, 3/4 or top-down, unlisted hues, rust/grime`

**States (§8.5):** idle (powered) · damaged (hp 14 → likely a single tier, *confirm vs
base-production.md*) · destroyed 2–4f. Base + glow-mask each. **No `_construction`/`_complete`
build-state sprites** (pre-placed override of §8.2's build-token note).

**Flags:** construction-sprite exemption applies to this asset only. Damage-tier count (single here
vs HQ's multiple) is an extrapolation — confirm vs base-production.md.

---

## ASSET-006 — Plain Terrain Tile (`tile_plain`)

| Field | Value |
|-------|-------|
| Category | Environment / terrain (static `TileMapLayer` floor) |
| Dimensions | Fixed tile footprint (2:1 dimetric) — the one true fixed size; **all tile variants share it** (drop-in swaps). Author ~2–3× tile (§8.3) |
| Format | PNG 8-bit+alpha; part of the terrain tile-variant-kit layered source; lossless; mipmaps off |
| Naming | `tile_plain_[variant].png` — e.g. `tile_plain_clean.png`, `tile_plain_cracked.png`, `tile_plain_scorched.png` |
| Facings | N/A · Hue variants | **None — terrain is faction-agnostic** (dark-stage neutral, §4.3/§6.2) |

**Visual Description:** A flat, flush open-ground tile with no silhouette break within the tile
bounds — reads only as "open" — at terrain-base value `#232A38`, zero hue, zero surface texture, hard
tile-aligned edges on the 2:1 grid. Carries no gameplay info beyond "walkable, no cover, no
elevation." Wear variety (clean/cracked/scorched) is the §6.2 tile-variant kit, not animation.

**Art-Bible Anchors:** §6.3 (plain = flat/flush terrain-base, no silhouette break), §4.1 (`#232A38`),
§3.3 (large simple few-sided angular geometry, no hue), §6.2 (flat/painted, no micro-detail), §8.4
(shared tile footprint).

**Generation Prompt:** `flat painted isometric floor tile, 2:1 dimetric projection, single flush open
ground tile, completely flat single color value #232A38, no hue, no gradient, no texture, no pattern,
no hatch, hard clean tile-aligned edges matching iso grid, minimalist geometric flat design,
restrained cool-neutral value, dark stage aesthetic, single isolated tile asset on void #0A0E17
background, orthographic dimetric camera, no shading beyond flat fill` — **Negative:** `texture noise,
grunge, dirt, cracks/damage (unless the wear variant), gradient, specular, PBR, bump/normal map, hue
tint, saturated color, organic/curved edges, 3D bevel, prop, debris, character, unit, structure,
cover object, raised geometry, elevation step, text, watermark, photoreal`

**Engine constraints:** static `TileMapLayer` cell, **outside** the Y-sort group (§8.8); no
`ShaderMaterial`/glow (terrain carries no actor-state grammar — §4.3). Atlas: one shared
terrain-variant-kit atlas with Cover (§8.1 / §6.2 kit-swap). No animation states — "states" = the
wear-variant kit.

---

## ASSET-007 — Cover Terrain Tile (`tile_cover`)

| Field | Value |
|-------|-------|
| Category | Environment / terrain — **hybrid: flush floor base (`TileMapLayer`) + Y-sorted cover-mass prop** |
| Dimensions | **Identical tile footprint to Plain** (drop-in), but canvas extends *above* the tile plane for the knee/waist mass overhang (like Sniper's barrel canvas). Author ~2–3× tile |
| Format | PNG 8-bit+alpha; terrain-variant-kit layered source; lossless; mipmaps off |
| Naming | `tile_cover_[variant].png` — e.g. `tile_cover_clean.png`, `tile_cover_chipped-corner.png` (§6.5 wear) |
| Facings | N/A · Hue variants | **None — faction-agnostic** |

**Visual Description:** A low, tile-spanning knee-to-waist-high geometric mass (bulkhead segment /
stacked crate-block / barrier slab) that **breaks the tile floor with a hard object-silhouette** —
distinct from elevation (which lifts the *whole* tile plane). Rendered as a lighter-valued faceted
plane one lightness step above base (~`#33405A`), flat/painted, hard edges, zero hue, zero
pattern/hatch — the silhouette alone signifies "cover." Rule: **elevation lifts the floor; cover
breaks the floor with an object silhouette** (§6.3).

**Art-Bible Anchors:** §6.3 (floor-lifts-vs-floor-breaks; cover = low object-silhouette at +L,
never a second hue or pattern), §4.1 (`#33405A`), §3.3 (angular geometric, few-sided), §6.2
(flat/painted, no hatch), §8.4/§8.8 (Y-sort — see below).

**Generation Prompt:** `flat painted isometric floor tile with cover object, 2:1 dimetric projection,
low knee-to-waist-high geometric bulkhead/crate-block/barrier slab spanning the tile, hard object
silhouette breaking the flat floor plane, faceted rectilinear angular block shapes straight edges
only, flat single lightness-step-up color value #33405A, no hue no gradient no texture no hatch,
minimalist geometric flat design, dark stage cool-neutral aesthetic, single isolated tile asset on
void #0A0E17 background, orthographic dimetric camera, no shading beyond flat fill` — **Negative:**
`texture noise, grunge, cracks (unless wear variant), gradient, specular, PBR, bump/normal map, hue
tint, saturated color, neon glow, faction color, organic/rounded shapes, character, unit, decorative
prop, full-height wall, impassable void block, whole-tile elevation lift, text, watermark, photoreal`

**Engine constraints — CRITICAL (§8.8):** the cover mass has occlusion-relevant vertical overhang, so
it **must NOT be a plain `TileMapLayer` cell** like Plain. Ship it as **two composited layers**: a
flush floor base (`TileMapLayer`, same footprint as Plain) **+ a Y-sorted cover-mass prop** with its
own ground-contact pivot (§8.4), so it correctly occludes / is occluded by units on adjacent rows.
The `tile_cover_[variant].png` filename is the delivered art; the runtime scene composition is *not*
a single tile — **flag this to the S4-03 board-renderer work** ("one PNG = one TileMapLayer cell"
breaks for Cover). No glow/hue. Shares the terrain-variant-kit atlas with Plain.

---

## Open Confirmations (owed, non-blocking for art start)

1. **Engine faction pins** — to enable ownership-by-hue (S4-04 gate), wire
   `vertical_slice_root.gd` `LOCAL_PLAYER → Factions.RUSH`, `AI_PLAYER → Factions.BOOM` (~2 lines).
   Fold into S4-03. (Or keep Neutral-mirror + add per-owner markers — see Scope Reconciliation #1.)
2. **Structure state counts** — HQ produce-beat frame count + HQ/Outpost damage-tier counts vs
   `base-production.md` (§8.5's state table is unit-specific).
3. **Mirror-safety per unit** — confirm no asymmetric kit detail before committing `w`=flip(`e`)
   (Scout lean/locomotion + Heavy weapon-mount are the risk cases).
4. **Atlas budget** — HQ + Heavy are the 2048²-ceiling pressure points; decide 2048² vs 4096
   escalation once author-res is fixed (§8.7 rule 4).
