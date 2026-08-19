# OVERCLOCK — VS Asset Generation Prompts (paste-ready)

> **Generated**: 2026-07-29 (S4-02) from `design/assets/specs/vs-entities-assets.md` — hue tokens
> pre-resolved. This is a convenience extract; the full spec (visual descriptions, art-bible anchors,
> dimensions, naming, engine constraints) is the source of truth.
> **How to use**: paste **Prompt** into your image tool's prompt field and **Negative** into its
> negative field. Each block targets one look. Author large (per `§8.3` tiers in the spec) and
> downscale for runtime.

---

## ⛔ Read first — render on a LIGHT background, never the void

**Every prompt block below says `dark void #0A0E17 background`. Do not use that literally.**
Our sprites are near-black (`#1B2130`). A dark-background render is **unkeyable** — the
background-removal step (`tools/asset-pipeline/cutout.py`) either stalls at the frame or floods
through the building and eats it. Both failure modes verified on the HQ, 2026-08-18.

Substitute in every prompt below:

| Instead of | Use |
|---|---|
| `dark void #0A0E17 background` | `plain flat solid light grey studio background` |
| *(add to negatives)* | `dark background, black background, gradient background, vignette, shadow, cast shadow, ground shadow` |

The dark stage colour is applied **in-engine**; baking it into a sprite is always wrong. The
originally-approved HQ (`hq_rush_r5_c3`) keyed cleanly only by luck — it happened to render on
light grey. Expect roughly **1 in 3** generations to honour the light-background instruction;
budget candidates accordingly. Review every candidate with
`tools/asset-pipeline/board_preview.py` at true sprite scale — a 1024px render flatters greeble
and trim that vanish at 256px on the board.

---

## ⚠️ Read first — rules that keep the set consistent

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

> ★ **Units do NOT use the structure plate value.** Unit armour is **`#6E7C99`** (cool slate),
> deliberately lighter than every stage tile. See the actor-value rule below.

### ⛔ Unit-specific rules (2026-08-19, 39-generation infantry session)

5. **Units must be LIGHTER than the stage, not darker.** The unit specs originally said base
   armour `#232A38`-family — *the exact colour of the plain terrain tile* — so units vanished
   into the board and only their accent trim survived at sprite size. Unit armour is now
   **`#6E7C99`**: grayscale luma Δ82 vs the base tile `#232A38`, Δ60 vs the worst case
   (max-elevation `#33405A`), and Δ82 below Neutral silver `#C6CED8` so it never reads as a
   faction claim. Structures stay near-black `#1B2130`. **Actors light, stage dark.**
6. **Character nouns carry worse baggage than structure nouns.** `soldier` / `infantry` summon a
   **concept-art model sheet** (multi-view turnarounds with callout panels) the way `factory`
   summons a district — 3/3 rejects, and no amount of anti-sheet negatives fixed it. `armored
   sentinel` produced 3/3 single isolated figures on the very next round. Swap the noun; don't
   stack negatives.
7. **A negative prompt cannot say "less" — only "none".** Negating `orange armor, mostly orange`
   to dial the accent back produced 3/3 **hue-less grey** units, killing the faction read
   outright. Control accent *coverage* on the positive side (`large solid #FF5A2E color blocks
   covering the whole chest plate and both shoulder pauldrons`), never by negating the hue.
8. **Never negate body proportions — it triggers pose sheets.** Adding `tall figure, long legs,
   standing at full height` to the negatives brought the multi-figure sheets straight back: told
   what body shape *not* to draw, the model explores body shapes. Proportion language is
   positive-side only.
9. **Role silhouettes come from the BODY PLAN, not from adjectives.** `squat`, `pitched forward`,
   `broader than tall` never moved the `sentinel` noun off its upright stance — six Scout rounds
   and one Heavy round all converged on the same biped, failing the §5.2 grayscale role test.
   Changing the **noun's body plan** fixed it in one round each: Scout = `four-legged walker
   drone`, Heavy = `squat heavy siege walker`, Trooper = the upright `armored sentinel`. The art
   bible permits this — §5.1 is explicitly body-plan-agnostic and §3.1 wants the Scout's outline
   dominated by locomotion.
10. **Infantry cutouts need `--pockets`.** A figure encloses background between its legs and under
    its arms; the border flood-fill cannot reach those, so the sprite ships with a pale slab
    between its knees. `python3 tools/asset-pipeline/cutout.py … --pockets` keys them (87k px on
    the Scout). Structures rarely enclose anything, which is why ASSET-001/005 never hit this.
11. **Judge units in GRAYSCALE, not just at board scale.** Colour hides everything: the dark-armour
    units looked acceptable in colour and were invisible in grayscale. Grayscale is the art bible's
    actual bar (§3.5 identifiable by outline alone) and it is the test that caught both the value
    defect and the role-separation failure.

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

### ⚑⚑ HQ — CURRENT approved recipe (2026-08-18, round 7 — use THIS one)

Round 5 below produced a good-looking image but an unusable asset (light off-palette
base-plate, 7 lamp-post props, and a background that only keyed by luck). Round 7 keeps
round 5's structure, forces the base-plate dark, negates the props, and renders on a
**light** background so the sprite can actually be cut out.

**Prompt (approved — seed 3566038092 → `art-source/generated/asset-001-hq/hq_rush_r7_c2.png`):**
`isometric game asset sprite of a dark sci-fi capital tower, entire structure fully visible in frame, wide empty margin around the building, small centered building viewed from a distance, plain flat solid light grey studio background, dark navy-black #1B2130 matte plating, single tall angular spire rising from a wide flat rectilinear base-plate, the base-plate is dark navy-black matte metal, stacked rectangular tower segments, thin hot orange-red #FF5A2E emissive trim lines along spire edges and base-plate rim, flat cel shading, flat color fields, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game building asset, nothing else in the image`
**Negative:** `shadow, cast shadow, drop shadow, ground shadow, contact shadow, ambient occlusion, dark background, black background, gradient background, vignette, cyan, blue accent, red accent, magenta, pink, purple, multiple accent colours, lamp post, street light, poles, signpost, street furniture, pavement, paving slabs, plaza, courtyard, city square, scattered props, small objects on the ground, surrounding buildings, spires in background, scenery, sky, horizon, terrain, cropped, close-up, cut off at edge, filling the frame, dramatic angle, 3D render, glossy, photoreal, PBR, specular, greebles, rivets, panel-line noise, organic shapes, bloom, face, character, text, watermark`

> Known residual on the approved image: a cast-shadow smudge fused to the base-plate's
> left side. It is *connected* to the subject, so `--largest-only` will not remove it —
> clean it before deriving hue variants or damage states, or it bakes into all of them.

---

### ⚑ HQ — superseded round-5 recipe (2026-08-12; kept for reference only)

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

Added 2026-08-18 (21-generation session on ASSET-005 + HQ re-roll):

5. **Transfer a proven scaffold; do not free-style a new prompt.** Nine Outpost images written
   "fresh around the subject" were all rejects. Take a prompt that has *worked* on another asset
   and change **only the shape words** — swapping the HQ's spire clause for a bay-doorway clause
   was the first thing to yield single isolated buildings.
6. **Subject nouns carry scene baggage.** `factory` and `industrial` paint a whole **district**
   (roads, vehicles, neighbouring plants) no matter how many isolation clauses you stack;
   `capital tower` doesn't, because it is inherently singular and monumental. `hangar` is weakly
   singular. **Never name what emerges** — "open bay where *vehicles* emerge" populated the scene
   with little trucks. Describe the aperture, never its purpose.
7. **Pin the accent or the model invents its own.** Under-specified rush prompts came back with
   fire-engine red *plus cyan panels* — cyan being Boom's LOCKED hue, which would break
   ownership-by-hue on the board. Add `cyan, blue accent, red accent, magenta, pink, purple,
   multiple accent colours` to the negatives of every single-hue prompt.
8. **Cast shadows need explicit negatives** (`shadow, cast shadow, drop shadow, ground shadow,
   contact shadow, ambient occlusion`). A shadow *touching* the base-plate is connected to the
   subject, so it survives `--largest-only` cleanup and bakes into every downstream hue variant
   and damage state. Re-roll; do not attempt mask surgery.

---

## ASSET-002/003/004 · Units — ⚑⚑ PROVEN RECIPES (2026-08-19)

The per-hue blocks that used to live here were **stale and actively harmful**: they specified
`dark void background #0A0E17` (unkeyable — see the light-background rule at the top) and asked for
a `4-directional iso facing sheet` (a contact sheet, which every working recipe negates). They have
been replaced by the recipes below, all validated at board scale in colour *and* grayscale.

**Shared across all three:** armour `#6E7C99` slate with `#3E4860` shadowed facets, accent as large
solid `#FF5A2E` colour blocks (not thin trim), flat light-grey studio background, one lone figure.
Derive **boom / neutral by accent recolor** of the approved base — never by fresh generation (rule 1).
Cut out with `--pockets --largest-only` (rule 10).

### ⚑⚑ ASSET-003 · Trooper — APPROVED BASELINE (the family's control group)

Authored **first** on purpose: the art bible makes Trooper the visual control group every other
role deviates from, and the upright biped is what the model produces naturally.

**Approved — seed 3049366272 → `art-source/generated/asset-003-trooper/trooper_rush_r7_c1.png`**
(shadow-free; superseded `r6_c2`, seed 3228806907, which had a cast shadow fused to the feet)

**Prompt:** `flat cel-shaded isometric game asset sprite of a sci-fi armored sentinel, one lone figure alone in empty space, entire figure fully visible in frame, wide empty margin around the figure, small centered figure viewed from a distance, plain flat solid light grey studio background, mid slate-grey #6E7C99 matte armor plating, medium grey armor, cool neutral grey plating with darker #3E4860 shadowed facets, sealed featureless helmet with no visor, squat stocky build broad and low, head sunk down between huge shoulders, oversized blocky shoulder pauldrons, very short thick stubby legs, long low body, crouched forward-leaning ready stance, wide horizontal silhouette, large solid hot orange-red #FF5A2E color blocks covering the whole chest plate and both shoulder pauldrons, bold flat orange panels, flat cel shading, flat color fields, no gradients, hand painted 2D illustration, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game character asset, one pose only, nothing else in the image`
**Negative:** `3D render, CGI, octane render, unreal engine render, raytracing, soft shading, smooth gradient shading, ambient occlusion, subsurface, glossy, specular highlight, reflective metal, chrome, photoreal, PBR, white panels, blown out highlights, pure white, sticker, badge, rounded rectangle backdrop, white shape behind the figure, backdrop panel, spotlight pool, reflection, puddle, mirror floor, ground plane lines, floor grid, concept art sheet, design sheet, model sheet, reference sheet, turnaround sheet, character sheet, contact sheet, orthographic views, multiple angles, front and back view, side view panel, callout panels, annotation, labels, diagram, blueprint, schematic, exploded diagram, multiple views, four views, side by side poses, multiple characters, crowd, squad, duplicate figure, cream, ivory, near-black armor, pitch black armor, shadow, cast shadow, drop shadow, ground shadow, contact shadow, dark background, black background, gradient background, vignette, cyan, blue accent, red accent, magenta, pink, purple, multiple accent colours, face, facial features, skin, eyes, glowing visor, visor glow, helmet lights, mouth, nose, hair, realistic human proportions, cape, cloak, cloth, fabric, flag, banner, antenna, aerial, scattered props, crates, weapons on the ground, pedestal, display stand, base ring, ground plane, floor, terrain, sky, horizon, surrounding buildings, scenery, border, picture frame, cropped, close-up, cut off at edge, filling the frame, dramatic angle, greebles, rivets, panel-line noise, organic rounded shapes, bloom, text, watermark`

### ⚑⚑ ASSET-002 · Scout — APPROVED (low four-legged walker)

Body plan changed from humanoid to a **low headless walker** (rule 9, user-approved 2026-08-19) —
this is what finally delivered the §3.1 "outline dominated by locomotion" read. Size the Scout by
**width**, not height: it is the long low one.

**Approved — seed 1383706175 → `art-source/generated/asset-002-scout/scout_rush_r9_c2.png`**

**Prompt:** `flat cel-shaded isometric game asset sprite of a sci-fi four-legged walker drone, one lone figure alone in empty space, entire figure fully visible in frame, wide empty margin around the figure, small centered figure viewed from a distance, plain flat solid light grey studio background, mid slate-grey #6E7C99 matte armor plating, medium grey armor, cool neutral grey plating with darker #3E4860 shadowed facets, sealed featureless helmet with no visor, four articulated insectlike walking legs splayed wide, small low armored body slung between the legs, no head, low flat wide chassis close to the ground, long horizontal silhouette much wider than tall, sensor block at the front, large solid hot orange-red #FF5A2E color blocks covering the whole chest plate and both shoulder pauldrons, bold flat orange panels, flat cel shading, flat color fields, no gradients, hand painted 2D illustration, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game character asset, one pose only, nothing else in the image`
**Negative:** `3D render, CGI, octane render, unreal engine render, raytracing, soft shading, smooth gradient shading, ambient occlusion, subsurface, glossy, specular highlight, reflective metal, chrome, photoreal, PBR, white panels, blown out highlights, pure white, sticker, badge, rounded rectangle backdrop, white shape behind the figure, backdrop panel, spotlight pool, reflection, puddle, mirror floor, ground plane lines, floor grid, concept art sheet, design sheet, model sheet, reference sheet, turnaround sheet, character sheet, contact sheet, orthographic views, multiple angles, front and back view, side view panel, callout panels, annotation, labels, diagram, blueprint, schematic, exploded diagram, multiple views, four views, side by side poses, multiple characters, crowd, squad, duplicate figure, cream, ivory, near-black armor, pitch black armor, shadow, cast shadow, drop shadow, ground shadow, contact shadow, dark background, black background, gradient background, vignette, cyan, blue accent, red accent, magenta, pink, purple, multiple accent colours, face, facial features, skin, eyes, glowing visor, visor glow, helmet lights, mouth, nose, hair, realistic human proportions, cape, cloak, cloth, fabric, flag, banner, antenna, aerial, scattered props, crates, weapons on the ground, pedestal, display stand, base ring, ground plane, floor, terrain, sky, horizon, surrounding buildings, scenery, border, picture frame, cropped, close-up, cut off at edge, filling the frame, dramatic angle, greebles, rivets, panel-line noise, organic rounded shapes, animal, dog, horse, insect, spider, creature, fur, tail, claws, biological, humanoid figure, standing man, upright biped, bloom, text, watermark`

### ⚑⚑ ASSET-004 · Heavy — APPROVED (squat siege walker)

**Approved — seed 1840110820 → `art-source/generated/asset-004-heavy/heavy_rush_r9_c2.png`**

**Prompt:** `flat cel-shaded isometric game asset sprite of a sci-fi squat heavy siege walker, one lone figure alone in empty space, entire figure fully visible in frame, wide empty margin around the figure, small centered figure viewed from a distance, plain flat solid light grey studio background, mid slate-grey #6E7C99 matte armor plating, medium grey armor, cool neutral grey plating with darker #3E4860 shadowed facets, sealed featureless helmet with no visor, enormous squat armored bunker-like body, no neck, two very short thick piston legs planted wide apart, massive slab shoulders far wider than the body, bottom-heavy anvil mass, wide flared base, dense blocky silhouette broader than tall, large solid hot orange-red #FF5A2E color blocks covering the whole chest plate and both shoulder pauldrons, bold flat orange panels, flat cel shading, flat color fields, no gradients, hand painted 2D illustration, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game character asset, one pose only, nothing else in the image`
**Negative:** `3D render, CGI, octane render, unreal engine render, raytracing, soft shading, smooth gradient shading, ambient occlusion, subsurface, glossy, specular highlight, reflective metal, chrome, photoreal, PBR, white panels, blown out highlights, pure white, sticker, badge, rounded rectangle backdrop, white shape behind the figure, backdrop panel, spotlight pool, reflection, puddle, mirror floor, ground plane lines, floor grid, concept art sheet, design sheet, model sheet, reference sheet, turnaround sheet, character sheet, contact sheet, orthographic views, multiple angles, front and back view, side view panel, callout panels, annotation, labels, diagram, blueprint, schematic, exploded diagram, multiple views, four views, side by side poses, multiple characters, crowd, squad, duplicate figure, cream, ivory, near-black armor, pitch black armor, shadow, cast shadow, drop shadow, ground shadow, contact shadow, dark background, black background, gradient background, vignette, cyan, blue accent, red accent, magenta, pink, purple, multiple accent colours, face, facial features, skin, eyes, glowing visor, visor glow, helmet lights, mouth, nose, hair, realistic human proportions, cape, cloak, cloth, fabric, flag, banner, antenna, aerial, scattered props, crates, weapons on the ground, pedestal, display stand, base ring, ground plane, floor, terrain, sky, horizon, surrounding buildings, scenery, border, picture frame, cropped, close-up, cut off at edge, filling the frame, dramatic angle, greebles, rivets, panel-line noise, organic rounded shapes, animal, dog, horse, insect, spider, creature, fur, tail, claws, biological, humanoid figure, standing man, upright biped, bloom, text, watermark`

> The walker negatives add `animal, dog, horse, insect, spider, creature, fur, tail, claws,
> biological, humanoid figure, standing man, upright biped` on top of the biped set — a four-legged
> noun pulls toward animals, and the Heavy's noun pulls back toward the Trooper's biped.

> ⚠ **Residual on both walkers:** a soft cast shadow near the feet. Clean it **before** deriving hue
> variants, facings or damage states, or it bakes into every one of them (same debt as the HQ's).

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

### ⚑⚑ Production Outpost — approved recipe (2026-08-18, round 5)

The blocks above drift badly: `factory` / `industrial` paint a whole district (rule 6), and
free-styled rewrites never converged (rule 5). What worked was the **HQ round-7 scaffold with only
the shape words swapped** — and describing the aperture without naming what comes out of it.

**Prompt (approved — seed 1143338806 → `art-source/generated/asset-005-production-outpost/outpost_rush_r5_c3.png`):**
`isometric game asset sprite of a dark sci-fi bunker building, entire structure fully visible in frame, wide empty margin around the building, small centered building viewed from a distance, plain flat solid light grey studio background, dark navy-black #1B2130 matte plating, a single low wide rectangular building, one large open bay doorway cut into the front face, flat roof, no spire, standing on a wide flat rectilinear base-plate, the base-plate is dark navy-black matte metal, stacked rectangular blocks, thin hot orange-red #FF5A2E emissive trim lines along the bay doorway edges and base-plate rim, flat cel shading, flat color fields, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game building asset, nothing else in the image`
**Negative:** `shadow, cast shadow, drop shadow, ground shadow, contact shadow, ambient occlusion, dark background, black background, gradient background, vignette, cyan, blue accent, red accent, magenta, pink, purple, multiple accent colours, tall central spire, tower, industrial complex, factory district, city grid, streets, roads, pavement, plaza, courtyard, walled compound, open-top box, hollow roofless building, multiple buildings, surrounding structures, scattered props, crates, containers, vehicles, machinery, pipes, catwalks, ladders, antennas, lamp post, street light, poles, greebles, rivets, panel-line noise, exploded diagram, contact sheet, multiple views, border, picture frame, cropped, close-up, cut off at edge, filling the frame, dramatic angle, sky, horizon, terrain, white building, blown out highlights, 3D render, glossy, photoreal, PBR, specular, organic rounded shapes, face, character, text, watermark`

> **`bunker` is doing the work** — it is singular and monolithic where `factory` is not. Note the
> prompt still *asks* for a front-face doorway; the model delivered a glowing **open top** instead,
> which was reviewed and approved as the better isometric reading (see the spec's Bay Aperture note).
> A follow-up round that pushed harder for a front wall opening (`no open roof` + roofless negatives)
> was **0/3** — it produced roofless compounds and hue-less grey buildings. Don't re-litigate it.

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
