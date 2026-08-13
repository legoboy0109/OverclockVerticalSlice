# OVERCLOCK — VS Asset Generation Prompts (paste-ready)

> **Generated**: 2026-07-29 (S4-02) from `design/assets/specs/vs-entities-assets.md` — hue tokens
> pre-resolved. This is a convenience extract; the full spec (visual descriptions, art-bible anchors,
> dimensions, naming, engine constraints) is the source of truth.
> **How to use**: paste **Prompt** into your image tool's prompt field and **Negative** into its
> negative field. Each block targets one look. Author large (per `§8.3` tiers in the spec) and
> downscale for runtime.

---

## ⚠️ Read first — 4 rules that keep the set consistent

1. **Same silhouette across a unit's 3 hues.** The VS uses **one shared silhouette per role**; the
   rush/boom/neutral variants differ **only in the accent hue**. Do **not** generate three
   independent images — generate the silhouette **once**, then make the hue variants by re-coloring
   (same seed, img2img, or a manual accent recolor). Three fresh generations will drift in shape and
   break the shared-silhouette requirement.
2. **Neutral is achromatic (menu/showroom + flexibility).** The board wires **Rush vs Boom** for
   ownership-by-hue — prioritize those two. Neutral's accent is near-white silver, so on a board it
   can't code ownership by itself (that's the deferred non-hue-marker work).
3. **These are the base look, not the full sheet.** Infantry need **4 facings** (`n/s/e/w`, `w` =
   h-flip of `e`) and a **state set** (idle / move / attack / hit / destroyed 2–4f); structures need
   idle / damaged / destroyed. Generate the reference look first, then derive facings/states (see the
   state tables in the full spec). Keep the pivot at the **ground-contact bottom-center** for Y-sort.
4. **Style is shared.** Every asset is flat-cel Neon-Retro-Future on a dark stage — the prompts carry
   it inline, but if your tool supports a style reference / preamble, reuse the same one across all
   assets for cohesion.

**Palette anchors** (LOCKED, S4-01): Rush `#FF5A2E` · Boom `#22C7F0` · Neutral `#C6CED8` · void
`#0A0E17` · terrain base `#232A38` · elevated/cover `#33405A` · structure plate `#1B2130`.

---

## ASSET-001 · HQ (structure) — 3 hue variants

### HQ · Rush (orange)
**Prompt:** `flat cel-shaded isometric sci-fi capital structure, 2:1 dimetric projection, massive stacked rectilinear tower on a wide flat base-plate, single dominant central spire, hard-surface matte plating, no PBR no specular, no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted upper facets, neon trim glow accent in hot orange-red #FF5A2E along spire edges and base-plate rim rendered as a thin emissive line, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, clean hard edges, orthographic dimetric camera`
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes, gradient sky, full-image bloom, saturated ground, face, character, text, watermark, 3/4 or top-down perspective, additional unlisted hues, rust/grime`

### HQ · Boom (cyan)
**Prompt:** `flat cel-shaded isometric sci-fi capital structure, 2:1 dimetric projection, massive stacked rectilinear tower on a wide flat base-plate, single dominant central spire, hard-surface matte plating, no PBR no specular, no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted upper facets, neon trim glow accent in cyan-azure #22C7F0 along spire edges and base-plate rim rendered as a thin emissive line, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, clean hard edges, orthographic dimetric camera`
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes, gradient sky, full-image bloom, saturated ground, face, character, text, watermark, 3/4 or top-down perspective, additional unlisted hues, rust/grime`

### HQ · Neutral (silver, achromatic)
**Prompt:** `flat cel-shaded isometric sci-fi capital structure, 2:1 dimetric projection, massive stacked rectilinear tower on a wide flat base-plate, single dominant central spire, hard-surface matte plating, no PBR no specular, no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted upper facets, neon trim glow accent in achromatic silver #C6CED8 along spire edges and base-plate rim rendered as a thin emissive line, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, clean hard edges, orthographic dimetric camera`
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes, gradient sky, full-image bloom, saturated ground, face, character, text, watermark, 3/4 or top-down perspective, additional unlisted hues, rust/grime`

### ⚑ HQ — PROVEN SDXL recipe (2026-08-12, /asset-generate round 5; base look approved from it)

The original block above drifts badly on local SDXL (paints city scenes, hue hijacks
the palette). 15-generation session converged on three required additions — **lead
with the subject-as-game-asset + dark-first color order + explicit framing**:

**Prompt (worked — seed 2408465881 → `art-source/generated/asset-001-hq/hq_rush_r5_c3.png`):**
`isometric game asset sprite of a dark sci-fi capital tower, entire structure fully visible in frame, wide empty black margin around the building, small centered building viewed from a distance, pure black void background, dark navy-black #1B2130 matte plating, single tall angular spire rising from a wide flat rectilinear base-plate, stacked rectangular tower segments, thin hot orange-red #FF5A2E emissive trim lines along spire edges and base-plate rim, flat cel shading, flat color fields, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game building asset`
**Negative:** `cropped, close-up, cut off at edge, partial view, filling the frame, dramatic angle, surrounding buildings, spires in background, courtyard, scenery, sky, moon, sun, horizon, terrain, ground plane, red background, orange background, bright background, grey background, white background, gradient background, 3D render, glossy, photoreal, PBR, specular, greebles, panel-line noise, organic shapes, bloom, face, character, text, watermark`

Session learnings (apply to ALL structure prompts here):
1. **Isolation**: "single isolated building / one lone structure / game asset sprite" up front, or SDXL paints a city.
2. **Dark-first**: name the dark base color before any accent hue, or the accent hijacks the palette ("neon glow accent" early → whole image goes that hue).
3. **Framing**: "entire structure fully visible in frame, wide empty margin, viewed from a distance" or SDXL crops dramatically.
4. **Same-seed hue swap is unreliable** (verified — composition drifts): derive boom/neutral from the approved base by accent recolor, not fresh generation.

---

## ASSET-002 · Scout (infantry) — 3 hue variants

### Scout · Rush (orange)
**Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders short thick limbs compressed torso, low horizontal forward-leaning stance, visible leg/locomotion silhouette implying speed, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family shading, faction accent color-block in hot orange-red #FF5A2E on chest/limb plating only, thin neon emissive trim on armor edges, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso facing sheet`
**Negative:** `face, visible skin, eyes, glowing visor eyes, cartoon eye slit, photoreal, PBR, specular, greebles, realistic human proportions, thin limbs, tall vertical stance, sniper barrel, wide bottom-heavy mass, weapon longer than body, organic curves, cloth-sim, skin texture, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down perspective`

### Scout · Boom (cyan)
**Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders short thick limbs compressed torso, low horizontal forward-leaning stance, visible leg/locomotion silhouette implying speed, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family shading, faction accent color-block in cyan-azure #22C7F0 on chest/limb plating only, thin neon emissive trim on armor edges, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso facing sheet`
**Negative:** `face, visible skin, eyes, glowing visor eyes, cartoon eye slit, photoreal, PBR, specular, greebles, realistic human proportions, thin limbs, tall vertical stance, sniper barrel, wide bottom-heavy mass, weapon longer than body, organic curves, cloth-sim, skin texture, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down perspective`

### Scout · Neutral (silver, achromatic)
**Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders short thick limbs compressed torso, low horizontal forward-leaning stance, visible leg/locomotion silhouette implying speed, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family shading, faction accent color-block in achromatic silver #C6CED8 on chest/limb plating only, thin neon emissive trim on armor edges, dark void background #0A0E17, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso facing sheet`
**Negative:** `face, visible skin, eyes, glowing visor eyes, cartoon eye slit, photoreal, PBR, specular, greebles, realistic human proportions, thin limbs, tall vertical stance, sniper barrel, wide bottom-heavy mass, weapon longer than body, organic curves, cloth-sim, skin texture, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down perspective`

---

## ASSET-003 · Trooper (infantry) — 3 hue variants

### Trooper · Rush (orange)
**Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders short thick limbs, upright balanced symmetrical rectangle silhouette, medium even mass top to bottom no dominant protrusion, weapon at mid-height, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in hot orange-red #FF5A2E on chest/shoulder plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet`
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic proportions, low horizontal lean, emphasized locomotion legs, wide bottom-heavy mass, long barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down`

### Trooper · Boom (cyan)
**Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders short thick limbs, upright balanced symmetrical rectangle silhouette, medium even mass top to bottom no dominant protrusion, weapon at mid-height, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in cyan-azure #22C7F0 on chest/shoulder plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet`
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic proportions, low horizontal lean, emphasized locomotion legs, wide bottom-heavy mass, long barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down`

### Trooper · Neutral (silver, achromatic)
**Prompt:** `flat cel-shaded isometric sci-fi infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions oversized shoulders short thick limbs, upright balanced symmetrical rectangle silhouette, medium even mass top to bottom no dominant protrusion, weapon at mid-height, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in achromatic silver #C6CED8 on chest/shoulder plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet`
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic proportions, low horizontal lean, emphasized locomotion legs, wide bottom-heavy mass, long barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down`

---

## ASSET-004 · Heavy (infantry) — 3 hue variants

### Heavy · Rush (orange)
**Prompt:** `flat cel-shaded isometric sci-fi heavy infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions scaled up and widened, widest bulkiest bottom-heavy silhouette broader than tall, blocky oversized shoulder and chassis mass, short thick stubby limbs, immovable anvil stance, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in hot orange-red #FF5A2E on chest/shoulder plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet`
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic proportions, thin limbs, low horizontal lean, tall narrow silhouette, long barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down`

### Heavy · Boom (cyan)
**Prompt:** `flat cel-shaded isometric sci-fi heavy infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions scaled up and widened, widest bulkiest bottom-heavy silhouette broader than tall, blocky oversized shoulder and chassis mass, short thick stubby limbs, immovable anvil stance, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in cyan-azure #22C7F0 on chest/shoulder plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet`
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic proportions, thin limbs, low horizontal lean, tall narrow silhouette, long barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down`

### Heavy · Neutral (silver, achromatic)
**Prompt:** `flat cel-shaded isometric sci-fi heavy infantry soldier, 2:1 dimetric projection, sealed powered armor helmet no face no visor glow, chunky exaggerated proportions scaled up and widened, widest bulkiest bottom-heavy silhouette broader than tall, blocky oversized shoulder and chassis mass, short thick stubby limbs, immovable anvil stance, matte hard-surface plating flat color blocks large simple trim no greeble, base armor dark neutral #232A38-family, faction accent color-block in achromatic silver #C6CED8 on chest/shoulder plating only, thin neon emissive trim, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera, single character full body, 4-directional iso sheet`
**Negative:** `face, skin, eyes, glowing visor, photoreal, PBR, specular, greebles, realistic proportions, thin limbs, low horizontal lean, tall narrow silhouette, long barrel, organic curves, cloth-sim, unlisted hues, gradient background, saturated terrain, text, watermark, 3/4 or top-down`

---

## ASSET-005 · Production Outpost (structure) — 3 hue variants

### Production Outpost · Rush (orange)
**Prompt:** `flat cel-shaded isometric sci-fi factory structure, 2:1 dimetric projection, medium stacked rectilinear structure smaller than a capital building, distinct open bay aperture cut into the silhouette like a mouth where units emerge, flat tile-aligned base-plate, hard-surface matte plating no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted facets, neon trim glow accent in hot orange-red #FF5A2E outlining the bay aperture and base-plate rim as a thin emissive line, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera`
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes, tall central spire (reserved for HQ), gradient sky, saturated ground, face, character, text, watermark, 3/4 or top-down, unlisted hues, rust/grime`

### Production Outpost · Boom (cyan)
**Prompt:** `flat cel-shaded isometric sci-fi factory structure, 2:1 dimetric projection, medium stacked rectilinear structure smaller than a capital building, distinct open bay aperture cut into the silhouette like a mouth where units emerge, flat tile-aligned base-plate, hard-surface matte plating no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted facets, neon trim glow accent in cyan-azure #22C7F0 outlining the bay aperture and base-plate rim as a thin emissive line, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera`
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes, tall central spire (reserved for HQ), gradient sky, saturated ground, face, character, text, watermark, 3/4 or top-down, unlisted hues, rust/grime`

### Production Outpost · Neutral (silver, achromatic)
**Prompt:** `flat cel-shaded isometric sci-fi factory structure, 2:1 dimetric projection, medium stacked rectilinear structure smaller than a capital building, distinct open bay aperture cut into the silhouette like a mouth where units emerge, flat tile-aligned base-plate, hard-surface matte plating no greeble, large simple panel shapes, base color #1B2130 with #33405A value-lifted facets, neon trim glow accent in achromatic silver #C6CED8 outlining the bay aperture and base-plate rim as a thin emissive line, dark void #0A0E17 background, flat painted illustration, TRON synthwave lighting, hard edges, orthographic dimetric camera`
**Negative:** `photoreal, PBR, specular, greebles, rivets, panel-line noise, organic/rounded shapes, tall central spire (reserved for HQ), gradient sky, saturated ground, face, character, text, watermark, 3/4 or top-down, unlisted hues, rust/grime`

---

## ASSET-006 · Plain Terrain Tile (faction-agnostic — one pass)

**Prompt:** `flat painted isometric floor tile, 2:1 dimetric projection, single flush open ground tile, completely flat single color value #232A38, no hue, no gradient, no texture, no pattern, no hatch, hard clean tile-aligned edges matching iso grid, minimalist geometric flat design, restrained cool-neutral value, dark stage aesthetic, single isolated tile asset on void #0A0E17 background, orthographic dimetric camera, no shading beyond flat fill`
**Negative:** `texture noise, grunge, dirt, cracks/damage, gradient, specular, PBR, bump/normal map, hue tint, saturated color, organic/curved edges, 3D bevel, prop, debris, character, unit, structure, cover object, raised geometry, elevation step, text, watermark, photoreal`

> Wear variants (`clean` / `cracked` / `scorched`) share the exact tile footprint — add the wear
> word and a "flat value-patch scorch/crack, no texture noise" clause; keep it drop-in swappable.

---

## ASSET-007 · Cover Terrain Tile (faction-agnostic — one pass)

**Prompt:** `flat painted isometric floor tile with cover object, 2:1 dimetric projection, low knee-to-waist-high geometric bulkhead/crate-block/barrier slab spanning the tile, hard object silhouette breaking the flat floor plane, faceted rectilinear angular block shapes straight edges only, flat single lightness-step-up color value #33405A, no hue no gradient no texture no hatch, minimalist geometric flat design, dark stage cool-neutral aesthetic, single isolated tile asset on void #0A0E17 background, orthographic dimetric camera, no shading beyond flat fill`
**Negative:** `texture noise, grunge, cracks, gradient, specular, PBR, bump/normal map, hue tint, saturated color, neon glow, faction color, organic/rounded shapes, character, unit, decorative prop, full-height wall, impassable void block, whole-tile elevation lift, text, watermark, photoreal`

> Cover ships as **two composited layers** at build time — a flush floor cell + a **Y-sorted prop**
> for the raised mass (§8.8). Generate the cover mass with clear space around its base so it can be
> cut from the floor cleanly.
