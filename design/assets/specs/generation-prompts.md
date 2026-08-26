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

### ⛔ Structure-specific rule (2026-08-19, roster-completion session)

12. **The scaffold's NOUN outranks every shape adjective — including for structures.**
    Rule 9 established this for units; it applies just as hard here, and cost five wasted
    rounds. The shared structure scaffold opens `dark sci-fi bunker building`, and `bunker`
    means *squat and monolithic*. The Research Lab's whole §3.2 identity is "tall-thin
    vertical mast on a small base, the most delicate structure silhouette" — the exact
    opposite. Five rounds of `very tall`, `very thin`, `slender`, `needle-like`,
    `delicate`, `much taller than wide` never moved it off a squat box. Swapping the noun to
    `dark sci-fi antenna tower structure` produced the correct silhouette **on the next
    round**. If an asset's silhouette fights the scaffold's noun, change the noun; do not
    stack adjectives against it.

13. **`solar array` / `collector panels` summons a city block**, the same way `factory` does
    (rule 6) — 3/3 districts, compounds and rooftop farms. The Economy Outpost's §3.2
    "collector forms" read had to be expressed as part of one monolithic mass —
    `angled intake vanes tilted up from its roof` on a `bunker` — rather than as an array.

14. **Value-correct in post; do not chase it in the prompt.** Three of four new assets landed
    outside their family's luma band (structures at 0.25–0.29 against the shipped 0.215; the
    Sniper at 0.253 against the roster's 0.355 — the "actors light, stage dark" defect from
    rule 5, hit again). A single measured multiply per asset fixed all four exactly. The
    measurement that matters is **opaque-only mean luma**: measuring with transparent pixels
    included compares alpha coverage, not value, and will mislead you.

---

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

> ~~Known residual: a cast-shadow smudge fused to the base-plate's left side.~~
> ✅ **CLEANED 2026-08-19** — `cutout.py --deshadow --ink-ratio 0.50 --pockets --largest-only`.
> Master: `art-source/cleaned/hq_rush_r7_c2_clean.png`. Derive hue variants and damage states
> from the **cleaned master**, never from the raw generation.

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
Cut out with `--pockets --largest-only` (rule 10).

> ### ✅ Hue variants are TOOLED — do not generate them (2026-08-19)
> Only the **rush** master is generated. Boom and neutral are derived from it:
> ```
> python3 tools/asset-pipeline/recolor.py \
>     art-source/cleaned/<asset>_rush_<id>_clean.png \
>     art-source/cleaned/<asset>_boom_<id>_clean.png boom
> ```
> All 5 assets × 3 hues exist in `art-source/cleaned/`. The tool replaces hue outright but
> **scales** saturation and brightness by the target anchor's ratio, so the accent keeps its
> lit/shadow structure instead of flattening into a sticker. Run it on a **cleaned** master,
> never a raw.
>
> ★ **Brightness scales in LUMA, not HSV value** (`--scale luma`, the default). Value scaling makes
> the grayscale result depend on saturation — shaded and anti-aliased accent barely moves — which
> left rush and boom only ~18/255 apart in grayscale. Luma scaling moves every accent pixel's
> luminance by the same anchor ratio: **rush ≈98 → boom ≈133 (Δ34), neutral ≈165 (Δ67)**. It also
> makes boom read as proper neon rather than a muted teal. `--scale value` reproduces the old
> output and should not be used for new work.
>
> ★ **The hue window must wrap past 360°.** Accent pixels blending toward the ink outline drift to
> ~350°; a naive `hue <= 45` test misses every one, leaving a 1px **orange fringe around each cyan
> panel** — both locked hues on one unit. What protects the armour is the *hue* gate, not the
> saturation gate (slate `#6E7C99` sits at saturation 0.28 but reads blue at ~218°), so the
> saturation gate stays low at 0.25 to catch shaded and anti-aliased accent.

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

### ⚑⚑ ASSET-012 · Builder — SHIPPED (hunched four-legged carrier walker)

Body plan chosen by the user 2026-08-25: a **hunched carrier walker** — stooped, back-heavy,
cargo-cradle mass slung high, four short legs. It is the roster's only support unit, and the
silhouette has to say "not a soldier" before any colour is read. Sized by **width** (140px) like
the Scout, but shipped narrower so the two four-legged units stay tellable apart (§3.1).

**Shipped — seed 1510903717 → `art-source/generated/asset-012-builder/builder_rush_r6_c2.png`**
(supersedes r3_c2 seed 4134681416, which the user judged too tall and leggy on 2026-08-26)

★ **The r6 recipe differs from r3 in exactly two clauses**, and that restraint is the finding:
`four thick armored walking legs bent and folded in a deep crouch, crouching low stance` and
`massive heavy body hanging low slung between the four legs, belly close to the ground`.

**Prompt:** `flat cel-shaded isometric game asset sprite of a sci-fi four-legged engineering carrier walker, one lone figure alone in empty space, floating on a plain flat solid pale grey background, no ground, no floor, no surface beneath it, entire figure fully visible in frame, wide empty margin around the figure, small centered figure viewed from a distance, mostly mid slate-grey #6E7C99 matte armor plating over the whole machine, predominantly grey armor, cool neutral grey plating with darker #3E4860 shadowed facets, no head, four short thick armored walking legs planted under the body, hunched stooped posture with the back arched up high, large empty open box cargo cradle mounted high on its back, bulky rounded load-bearing hull, heavy back-loaded mass, compact stubby build, unarmed utility machine, a few large solid hot orange-red #FF5A2E accent color blocks on the cargo cradle frame and the shoulder plates only, small bold flat orange accent panels on grey armor, flat cel shading, flat color fields, no gradients, hand painted 2D illustration, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game character asset cut out on a blank background, one pose only, nothing else in the image`

**Negative:** the walker set, plus a hard anti-ground block leading it — `shadow, cast shadow, drop shadow, ground shadow, contact shadow, shadow under the feet, dark patch under the figure, ground plane, floor, floor line, horizon, horizon line, ground line, baseline, surface, standing on ground, rocks, rubble, dirt, terrain` — and three new guards learned this round: `orange body, fully orange machine, orange hull, mostly orange, orange dominant, all orange plating` · `scale reference figure, person for scale, human beside the machine, small figure beside it` · `weapon, gun, cannon, turret, rifle, missile pod, gun barrel`.

> #### ⚠⚠ Two dead ends, both measured — do not repeat them
>
> **1. "Orange blocks covering the whole hull" makes an ORANGE MACHINE.** Round 1's six candidates
> all came out orange-dominant and would have failed §5.2's grayscale role test. The family recipe
> says orange covers *the chest plate and both shoulder pauldrons* — a part, named. Say
> "predominantly grey armor" AND name the specific accent parts, and negate the failure directly.
>
> **2. This render CANNOT be de-shadowed, for the Heavy's reason — and here it is proven.**
> Round 2's winner sat on a cast-shadow slab. Measured over the bottom band: **feet luma median
> 104, shadow luma median 102** — the distributions are *identical*, so no ink/saturation/luma
> threshold separates them. `--deshadow` at every strength punched **42–45% of the hull** out
> (vs 1.2% without it). `--pockets` alone is safe on a dark-background render and destructive on a
> light one — it leaked 20% into the Builder's light plating.
>
> ★ **The fix was to re-roll shadow-free rather than to clean harder**, which is how the Trooper
> got there too. The anti-ground negative block above is what did it: of round 3's five candidates,
> **two scored zero on a ground-band detector**. ⚠ But note the cost — the "floating, no ground"
> wording pulls hard toward a hovering craft, and candidate 1 came out as a legless flying
> platform. Keep `four short thick armored walking legs planted under the body` doing the work.
>
> **Cutout that shipped (r3):** `8 --largest-only --trim` — no `--pockets`, no `--deshadow`.
> **Cutout that shipped (r6, current):** `8 --largest-only`, then the two shadow passes below.

> #### ⚠⚠⚠ A third dead end: you cannot make this walker squat by SHRINKING its legs
>
> Asked for "shorter and bulkier", the obvious edit is to shrink the legs. **Every wording that
> does so makes SDXL delete them.** Two full rounds proved it:
> - `four VERY SHORT stubby stump legs, tiny legs dwarfed by the huge body` → a **legless sled**
>   and a **tracked barge**. The model resolves "four legs, but tiny" by dropping the legs.
> - Piling on bulk words (`enormous`, `massive`, `filling the silhouette`) **displaces** the
>   grey-dominance and four-leg clauses through sheer prompt length — round 4 came back
>   orange-dominant, two-legged, and treaded, i.e. every earlier fix undone at once.
>
> ★ **The lever that works is CROUCH, not scale.** Keep the legs described at full size and bend
> them: `bent and folded in a deep crouch` + `body hanging low slung between the four legs, belly
> close to the ground`. The legs survive because nothing asked them to be small.
>
> ⚠⚠ **And do not trust a bounding-box aspect ratio as the "squatness" score.** It ranked the
> legless sled top (aspect 1.24 vs the leggy original's 0.95) because deleting the legs is the
> cheapest way to get wider-than-tall. The shipped r6_c2 scores **0.97 — statistically
> indistinguishable from the version it replaced** — while looking dramatically bulkier, because
> what actually changed is the BODY-TO-LEG RATIO, which that metric cannot see. Look at the
> sprites.


> #### ⚑ The cargo cradle is DRAWN, not generated (2026-08-26)
>
> User asked for the cradle to read clearly on the back. Two more rounds tried:
> **r7** described it as open skeletal frame rails, **r8** as "a big separate box like a skip on a
> truck". Neither landed. The failure is structural, not bad luck: **prompt weight is finite**, so
> describing the cradle strongly enough to appear steals weight from the clauses holding the body
> together — every promising r7/r8 candidate came back with the cast shadow, the orange dominance
> or the long legs restored, i.e. undoing the very fixes of rounds 1–6.
>
> ★ So the cradle is authored geometry: `tools/asset-pipeline/draw_cargo_cradle.py`, composited
> onto the approved r6_c2 master. Same call `ASSET-006`/`007` made for the terrain tiles — **when
> the requirement is precise, a draw hits it by construction and a generator cannot.**
>
> Three things that decided the shape:
> - **A box, not an open frame.** At the shipped 140 px, rails a few master-pixels thick are
>   sub-pixel and vanish. What survives a resample is SILHOUETTE, so the cradle is a hard mass that
>   breaks the top outline, with its opening read as a dark interior rather than as thin geometry.
> - **Palette sampled off the render, not the spec.** The brief's `#6E7C99` is markedly blue; what
>   the generator actually painted is near-neutral (median rgb 110,111,111, lit panels 160,162,162).
>   A cradle mixed at the nominal value reads as a bolt-on from a different machine.
> - **Contact shading is not optional.** A flat-shaded box with no occlusion where it meets the
>   hull reads as a sticker. `_shade_contact()` multiplies the hull under the cradle footprint.
>
> ⚠ **The rim must be painted in the shared `ACCENT` constant**, because that is what `recolor.py`
> keys on — it is why the cradle turns cyan/silver with the rest of the body instead of staying
> orange in every faction.
>
> ⚠ **Cost: the sprite grew 145 → 157 px tall.** A cradle standing proud of the back necessarily
> gives back some of the "shorter" from round 6; it is sunk as deep as it can go while still
> reading as carried. That tension is inherent — a visible cradle and a minimal silhouette are
> opposed, and this is the chosen point on that trade.

> #### Shadow removal on r6_c2 — the opposite case to r2, and worth contrasting
>
> This render's shadow **is** liftable, and the measurement is why: machine median luma **99**,
> shadow median **117**, background **163**. The shadow occupies a band *above* the machine and
> *below* the background, so a border-seeded flood restricted to that band and to the lower frame
> lifts it with **0.0% hull loss**. (On r2 the same measurement gave feet 104 / shadow 102 —
> identical — and nothing could separate them.) **Always measure before deciding it is hopeless.**
>
> Two passes, both in `.agent/` scratch tooling rather than shipped, because they are per-render:
> a border flood at `luma 104..205, sat<=0.16, y>=0.50`, then an enclosed-pocket clear at
> `luma 138..205, sat<=0.16, y>=0.42` for the patch walled in by the legs, which no border-seeded
> flood can reach at any threshold.
>
> ⚠ **`board_preview.py` re-runs `cutout(pockets=True)` on whatever you hand it**, so it can show
> artifacts that are not in your master — it was showing a shadow slab under a master that was
> already clean. To judge a finished sprite, resample the master to its shipped width and
> composite it on the stage colour directly; that is what the game actually does.



> ### Shadow cleanup (2026-08-19) — always derive from `art-source/cleaned/`
>
> | Asset | Setting | Result |
> |---|---|---|
> | HQ | `--deshadow --ink-ratio 0.50` | ✅ clean — the fused base-plate smudge is gone |
> | Outpost | `--deshadow --ink-ratio 0.50` | ✅ clean |
> | Scout | `--deshadow --ink-ratio 0.62` | ✅ clean — **0.50 chewed the light tops off the feet**, 0.62 keeps them |
> | Trooper | *(none needed)* | ✅ was generated shadow-free |
> | Heavy | *(none possible)* | ⚠ see below |
>
> **The Heavy cannot be de-shadowed automatically and does not need to be.** Its render sits on an
> unusually dark background (luma 103 vs the others' 140–169) and its residue is a thin **warm**
> ground streak — rgb ≈ (105, 74, 62) — whose luma overlaps the Heavy's own grey plating (42–78).
> No ink/saturation threshold separates them: every setting aggressive enough to lift the streak also
> ate the hands and joint plating. **Verified invisible at board scale (74px)** — the cleaned and
> uncleaned versions are indistinguishable on the lattice. Only revisit if the Heavy is ever shown
> large (portrait, codex, UI), where a re-roll on this same recipe is the cheaper fix than mask surgery.

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

---

## ASSET-008..011 · Roster completion (2026-08-19) — ⚑⚑ APPROVED RECIPES

These four were the last VS types with no art. They were generated after the S5-01 renderer
made their absence visible on the board as magenta placeholders.

**Shared structure scaffold** (unchanged from the Production Outpost round-5 recipe — only the
shape words differ, per rule 12's warning about the noun):

`isometric game asset sprite of a dark sci-fi <NOUN>, entire structure fully visible in frame, wide empty margin around the building, small centered building viewed from a distance, plain flat solid light grey studio background, dark navy-black #1B2130 matte plating, <SHAPE>, standing on a wide flat rectilinear base-plate, the base-plate is dark navy-black matte metal, stacked rectangular blocks, thin hot orange-red #FF5A2E emissive trim lines along the structure edges and base-plate rim, flat cel shading, flat color fields, 2:1 dimetric projection, large simple panel shapes, hard clean edges, minimalist geometric design, TRON aesthetic, single isolated game building asset, nothing else in the image`

### ⚑⚑ ASSET-009 · Economy Outpost — APPROVED (seed 2305656182, r5_c2)
- **NOUN:** `bunker building`
- **SHAPE:** `a single very low wide flat armored bunker, one solid monolithic mass much wider than tall, two large flat angled intake vanes tilted up from its roof like wedge fins, very low flat profile, strong horizontal emphasis`
- **Extra negatives:** `tall spire, tower, antenna, mast, gun, turret, cannon, open roof, city district, solar farm, panel farm, trees, grass, green ground, stairs, ramp`
- 5 rounds. See rule 13.

### ⚑⚑ ASSET-010 · Defensive Structure — APPROVED (seed 3933358768, r2_c2)
- **NOUN:** `bunker building`
- **SHAPE:** `a compact thick squat symmetrical armored bunker with heavy sloped walls, one single large gun turret mounted on the centre of the roof, the turret has one long thick cannon barrel pointing outward and upward, the turret clearly breaks the flat roofline, braced and fortified`
- **Extra negatives:** `tall central spire, tower, antenna, mast, collector panel, solar panel, dish, unarmed building, plain roof, empty roof`
- 2 rounds — the cleanest convergence of the four. The `bunker` noun and this silhouette agree.

### ⚑⚑ ASSET-011 · Research Lab — APPROVED (seed 4290549827, r6_c2)
- **NOUN:** ⚠ `antenna tower structure` — **NOT `bunker`**. This is rule 12's whole point.
- **SHAPE:** `one single very tall very thin vertical mast rising high above a very small square base, slender needle-like silhouette, much taller than it is wide, delicate and lightweight, thin narrow profile`
- **Extra negatives:** `gun, turret, cannon, collector panel, solar panel, wide building, bulky mass, white building, walled compound, blueprint, linework, sketch lines, trees, grass, green ground, squat, bunker, compound, multiple buildings`
- 6 rounds, 5 of them wasted fighting the noun.

### ⚑⚑ ASSET-008 · Sniper — APPROVED (seed 1599279841, r6_c1)
Uses the infantry scaffold with one addition to the head — `grey arms and grey legs and grey
helmet` — because early rounds went near-fully orange, and rule 7 forbids fixing that by
negating the hue. Accent coverage is bounded on the positive side instead.

- **SHAPE:** `very tall and very narrow armored body, thin slab torso, narrow shoulders, long thin legs planted and braced, tall thin vertical silhouette much taller than wide, one single extremely long thin rail cannon barrel mounted vertically on its back rising far above its head, the barrel is the tallest part of the silhouette`
- **Extra negatives:** the infantry set plus `two figures, pair, front view and back view, bulky mech, mecha, heavy armor, wide shoulders, broad chest, squat build, orange legs, orange arms, orange helmet`
- **⚠ "figure" reintroduces model sheets.** R1 used `tall narrow upright figure` and produced
  3/3 two-view turnarounds despite the full anti-sheet negative block. Dropping the word and
  describing the body plan directly (`very tall and very narrow armored body`) fixed it — the
  same shape as rule 6's `soldier` → `armored sentinel` finding.
