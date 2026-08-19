# OVERCLOCK — Art Bible

*Created: 2026-07-23*
*Status: Complete (all 9 sections authored 2026-07-23)*
*Source Concept: design/gdd/game-concept.md*
*Visual Identity Anchor: Neon Retro-Future (game-concept.md §Visual Identity Anchor)*

> **Art Director Sign-Off (AD-ART-BIBLE): ✅ APPROVE** — recorded 2026-07-27 (Sprint 2 · S2-06; art-director gate).
>
> **Rationale:** All 9 sections are complete, internally consistent, and every color/mood/shape
> claim traces to a specific named mechanism rather than description — no contradictions found.
> The bible directly operationalizes the Pillar 3 isometric-legibility hard gate (§5.2's
> solid-black-silhouette validation test is the literal pass/fail mechanism for the VS playtest)
> and resolves both advisory notes carried from the concept-stage anchor (colorblind fallback via
> Mass Distribution Bias §4.2/§5.2; neutral-object palette bucket via the achromatic Neutral lock).
> Asset standards (§8) are achievable within platform budget, with the one real cost driver
> (3× faction-silhouette art, not palette-swaps) explicitly named and given a pre-registered
> fallback. Approved for asset production on already-specified content.
>
> **Non-blocking watch-items** (none block approval or production start):
> 1. `design/assets/entity-inventory.md` should be derived from this bible (§5/§6/§8) +
>    `design/registry/entities.yaml` before backlog planning is finalized. → **scheduled as S2-07.**
> 2. ~~`design/ux/hud.md` (per-screen HUD layout) missing — §7 defines HUD visual *language*, not
>    layout.~~ → **RESOLVED 2026-07-27 (S2-05): `design/ux/hud.md` authored + `/ux-review` APPROVED.**
> 3. ~~§4.2 hue-neighborhood watch-item: Boom's cyan sits near the Dark Stage family — run a
>    same-scene side-by-side prototype test (Boom units on max-elevation terrain) before final
>    hex lock.~~ → **RESOLVED 2026-07-29 (S4-01 de-risk spike): hexes LOCKED.** Boom `#22C7F0`
>    clears every legibility bar against all five stage tiles incl. the worst case (max-elevation
>    `#33405A`): ΔE2000 **51.8** (higher than Rush's 49.4 vs the same tile), WCAG **5.19:1**,
>    grayscale Δ **104/255**. See the §4.2 resolution note. Reproducible spike: `prototypes/s4-01-art-spike/`.
> 4. ~~§8.9 engine-verification watch-item: confirm per-instance shader uniform behavior in 2D and
>    that the 4.6 glow-pipeline rework is 3D/WorldEnvironment-only (does not affect the 2D
>    CanvasItem-shader approach) via a one-unit glow spike before committing the shader pipeline.~~
>    → **RESOLVED 2026-07-29 (S4-01 de-risk spike): 2D CanvasItem per-instance-uniform approach
>    CONFIRMED safe to commit** (engine-ref + headless smoke on Redot 26.2; one-unit windowed render
>    folded into S4-07). See the §8.9 resolution note.

> **Map projection decision (2026-07-23):** OVERCLOCK renders its tactical maps in
> **isometric 2D** (Final Fantasy Tactics lineage), a revision of the concept doc's
> "top-down" framing. This art bible is authored against the isometric projection.
> A `/propagate-design-change` pass is owed to reconcile the GDD corpus (grid-terrain,
> movement, combat, command-action-interface, game-hud) with the projection change.

> **Visual References:** Advance Wars (readable grid tactics, unit punchiness),
> TRON / synthwave (neon-on-dark palette), Final Fantasy Tactics (isometric projection,
> readable painterly environments), StarCraft / StarCraft 2 (faction color identity,
> tempo, silhouette clarity), XCOM (tactical readability, unit/terrain contrast),
> Command & Conquer (base-building language, bold faction hues, chunky sci-fi units),
> Front Mission (military/mech tone, gritty faction warfare).

---

## 1. Visual Identity Statement

**One-line visual rule:**

> *Every element reads as a bold, flat, neon-lit shape at a glance — clarity comes from silhouette and color, never from surface detail, and that reading holds even when the isometric camera stacks shapes in depth.*

This extends the brainstorm anchor's rule with an isometric qualifier: the original was written for top-down, where nothing occludes anything else. In iso ¾ view, tiles, units, and elevation overlap in screen space, so the rule now explicitly commits to silhouette/color clarity surviving that overlap.

**Supporting Principle 1 — Silhouette-First, Iso-Proofed** *(serves Pillar 3: Readable Board, Deep Decisions)*

Every unit and interactive board object must be identifiable by outline alone, in grayscale, from the actual isometric camera angle the game ships with — not from a flattened front or top reference. Isometric projection compresses vertical shape cues and can make two units read as similar blobs if their silhouettes were only checked from a top-down or straight-on view. **Design test:** when a silhouette is ambiguous at the shipping camera angle, redesign the silhouette at that angle — never patch the confusion with a color or detail change.

**Supporting Principle 2 — Ownership Legible Beyond Hue** *(serves Pillar 4: Factions Are Verbs, Not Skins)*

Faction hue is the primary ownership signal, but hue alone is not sufficient at isometric distances, under colorblind vision, or when multiple faction units overlap in depth on a diagonal tile stack. Every faction must carry a secondary, non-hue identity marker (a silhouette family trait, a trim/pattern, or an emblem shape) so ownership and faction identity are legible even if hue is degraded, occluded, or misread. **Design test:** when a faction's identity is ambiguous with hue removed, add a shape or pattern marker to that faction — never add a second hue.

**Supporting Principle 3 — Dark Stage Holds Under Depth** *(serves Pillar 3: Readable Board, Deep Decisions)*

The terrain/environment layer stays in restrained dark neutrals even as isometric elevation, shadow-casting, and tile-stacking add visual depth and occlusion the top-down version never had. Depth cues (elevation shading, drop shadows, foreground tile overlap) must read as *terrain information*, not compete with neon actors for attention. **Design test:** when an isometric depth/shadow effect makes a tile read as visually "loud" as a neon unit, dim or simplify the depth effect — never dim the unit.

**Isometric projection interaction:**

The shift to isometric (FFT lineage) adds spatial richness the anchor was not designed for — elevation, foreground/background tile overlap, and diagonal unit stacking all give the board more visual depth and let terrain features (cover, hazards, elevation advantage) read as tactical information rather than flat color-coding alone. The risk is that this same depth is what silhouette-first, dark-stage clarity depends on *not* happening: overlapping shapes and cast shadows are exactly the conditions that break flat-color legibility. The rule that keeps the identity intact: **elevation and occlusion are communicated through value and terrain shape, never through hue or silhouette distortion** — a tile that is "higher" or "in front" gets a lighter/darker neutral shade or a clean overlap edge, but a unit's silhouette and hue never bend, tint, or fragment to indicate depth. Depth is a stage property; silhouette and hue stay reserved for actors.

## 2. Mood & Atmosphere

Every state below is a variation on the same instrument: a dark, restrained stage and a disciplined neon layer. Mood shifts are authored primarily through **value** (how dark the stage gets, how much it's allowed to breathe) and **neon behavior** (steady vs. pulsing vs. sweeping vs. still) — not through new hues or decoration. If a state needs to feel different, the first question is "what does the dark stage do" and "what does the neon do," in that order. Adding color is the last lever, not the first. This section assumes the value/neon vocabulary from Section 1 (dark neutral stage, neon reserved for actors) — see Principle 3.

### 2.1 Planning / Your Turn (Idle Allocation)

- **Primary emotional target:** unhurried appraisal — a chess player's hand hovering over the board. Not calm-as-in-empty; calm-as-in-*loaded*. Every unit and structure is a held breath of potential energy.
- **Lighting character:** the baseline against which everything else is measured. Cool-neutral ambient on the dark stage, full but non-blown neon on actors at rest — steady-state brightness, no pulsing. Moderate-high contrast: enough to separate silhouettes cleanly from terrain, not so much that the board feels harsh. The "resting heart rate" state.
- **Atmospheric adjectives:** deliberate, coiled, legible, unhurried, weighty.
- **Energy level:** contemplative-but-charged.
- **Mood-carrying element:** units/structures with available AP show a slow, steady idle **glow-breathe** on their neon trim (long period, low amplitude — seconds per cycle, not a flicker). AP-exhausted actors have the breathe suppressed and trim clamped to steady-low. The player reads "who still has options" from glow behavior alone, before parsing the HUD.

### 2.2 Action Resolution

- **Primary emotional target:** the click of a well-oiled mechanism — a discrete, deliberate cause landing its effect. A punctuation mark, not a scene change: sharp, immediate, over quickly, back to 2.1's resting state.
- **Lighting character:** a brief, localized spike — not a global shift. The acting unit's neon flares above baseline for the action's duration (fast attack/decay, not a hold), with a tight falloff onto adjacent terrain. The dark stage elsewhere is untouched. Contrast peaks locally, decays to baseline within ~a second.
- **Atmospheric adjectives:** crisp, immediate, percussive, conclusive, discrete.
- **Energy level:** frenetic but brief — a spike, not a sustained state.
- **Mood-carrying element:** a fast neon **flare-and-decay** on the acting unit synced to the moment of impact/completion, paired with a single-frame-feeling terrain flash-lit halo under/around the action point that fades within the same beat. No screen-wide flash, no color shift — the "snap" stays local, which is what keeps five actions in a row satisfying instead of exhausting.

### 2.3 Opponent's Turn

- **Primary emotional target:** watchful unease — spectating an opponent's intentions in real time, aware tempo is being spent without your input. Not dread; alert attentiveness.
- **Lighting character:** the dark stage deepens very slightly (a consistent value drop, not a hue shift) reading subliminally as "the board doesn't belong to you right now." Opposing-faction neon stays at full identity brightness (Principle 2 — ownership never dims); *your* units' idle breathe is suppressed to steady-low for the duration.
- **Atmospheric adjectives:** watchful, ceded, alert, quiet, foreboding-but-not-hostile.
- **Energy level:** measured, externally paced — "waiting," not "resting."
- **Mood-carrying element:** a slow, subtle darkening **vignette** pull-in at the stage edges (value only) for the opponent's turn, released the instant control returns — marks "not your clock" without a HUD banner carrying the whole load.

### 2.4 The Swing / Pressure Moment (Zero Hour)

- **Primary emotional target:** white-knuckle clarity — the game has narrowed to a few decisions that matter enormously, and the player knows it. NOT excitement-with-hope-of-reversal; the sharpened focus of someone who knows how much rides on the next correct read. Because combat is deterministic, the mood communicates stakes without ever implying luck could save you — the tension is entirely in the player's own calculation.
- **Lighting character:** the sharpest contrast state in the game. The dark stage drops to its deepest value (never fully crushed — terrain silhouette stays legible per Principle 3) while contested actors' neon holds at full, **steady** brightness — no pulsing, no flare. Steadiness is the discipline: a pulsing glow would read as false urgency/hope-bait, which the design must not promise. The light feels *fixed*, because the outcome is a function of the player's decisions, not chance.
- **Atmospheric adjectives:** stark, fixed, narrow, exacting, unforgiving.
- **Energy level:** frenetic in stakes, measured in presentation.
- **Mood-carrying element:** contested/critical tiles get a tight, **static high-contrast rim-light** against the deepened stage — present the instant the pressure state is entered, held with zero animation, released cleanly (no fade flourish) when the swing resolves. The stillness of the light signals "this is real and it's on you," in contrast to genres that pulse/shake to manufacture false hope.

### 2.5 Victory

- **Primary emotional target:** earned exhale — quiet vindication that you out-tempo'd your opponent, not triumphant fireworks. The win was built turn by turn in 2.1; the ending is the payoff of that patience.
- **Lighting character:** baseline holds, then the dark stage gradually lifts in value (slow several-second fade, warmer-neutral) while your faction neon settles into a calm, full, un-pulsing glow across the board — the opposite gesture of 2.3's clamp-down, released slowly rather than snapped.
- **Atmospheric adjectives:** settled, warm, unhurried, quietly proud, resolved.
- **Energy level:** contemplative, decelerating.
- **Mood-carrying element:** a slow, board-wide **value lift** on the dark stage (never a hue shift, never a flash) synced to a single held (non-repeating) brightness bloom on the winning faction's core structure — one deliberate gesture, keeping victory legible as "tempo won," not "loot piñata."

### 2.6 Defeat

- **Primary emotional target:** a clear-eyed lesson, not a punishment — "I see where I lost tempo," dignity intact. Self-contained and instructive, never a shaming spectacle. No rubber-band, no near-miss theater — the mood must not suggest "you were robbed" or "next time the dice favor you," since there were no dice. The honest, deterministic conclusion of a read that didn't hold.
- **Lighting character:** the dark stage holds at (or just barely below) baseline — it does NOT crush to black or oversaturate red. Your faction neon desaturates toward its dimmest steady-low state (the same clamp used for AP-exhausted units in 2.1, held globally) while the opponent's neon stays at normal identity brightness — the story is "their tempo continued, yours stopped."
- **Atmospheric adjectives:** subdued, matter-of-fact, dignified, still, instructive.
- **Energy level:** measured, deceleration to a stop.
- **Mood-carrying element:** the steady-low **neon clamp** used for "out of AP" units in 2.1 is applied to your whole faction at once — a deliberate callback so the eye recognizes the "spent/out of options" grammar from earlier, reframing defeat as "you ran out of tempo" (the pillar's own vocabulary) rather than a new punitive language. No red wash, no cracked-screen, no alarm color.

### 2.7 Menus / Setup (Faction Pick, Mission Select)

- **Primary emotional target:** anticipatory clarity — an identity/strategy choice made off-board; a showroom, not combat. Composed, a little more expressive with color since no board-readability constraint competes here.
- **Lighting character:** the one place the dark-stage/restrained-neon ratio loosens deliberately — menus are explicitly *not* the tactical stage, so faction neon can run fuller and more saturated across more of the frame (hero shots) against the same dark neutral backing, without violating Principle 3 (which governs the board specifically). Cool-neutral, stable, gallery lighting rather than battlefield lighting.
- **Atmospheric adjectives:** composed, declarative, poised, showroom-clean, identity-forward.
- **Energy level:** measured-to-contemplative — unhurried browsing.
- **Mood-carrying element:** faction selection uses a steady full-brightness neon treatment on emblem/hero art with a slow **ambient drift** (slow-moving rim light or parallax layer) — a third glow behavior, distinct from the board's stillness-means-stakes (2.4) and breathe-means-potential (2.1), so a player never confuses "browsing" with "board state."

## 3. Shape Language

The shape system exists to make the board readable at a glance (Pillar 3) and to let each faction and unit role be identified before color is even processed (Section 1, P1/P2). The governing rule: **shape carries identity; neon carries state.** Silhouette tells you *what* a thing is; the glow behavior from Section 2 tells you what it's *doing*. Every shape decision below spends its complexity budget on the board's actors, never on chrome or terrain.

### 3.1 Unit Silhouette Philosophy

Units are the hero shapes of the game — the highest silhouette-detail objects on screen, and the only ones allowed complex outlines (§3.5). All four archetypes are designed as **grayscale-distinct at thumbnail size and at the shipping isometric angle** (P1, Iso-Proofed). **Trooper is the baseline** — the visual control group — and every other unit is authored as a legible deviation from it along one dominant axis. This makes the roster read as a *family with roles* rather than four unrelated shapes, reinforcing the rock-paper-scissors relationships (Pillar 2: the shapes teach the counters).

The two design axes that separate the roster:
- **Posture axis** (Scout ↔ Sniper): horizontal/low vs. vertical/tall — the primary thumbnail read.
- **Mass axis** (Trooper ↔ Heavy): medium/symmetrical vs. wide/scaled-up — the secondary read.

| Unit | Silhouette rule (the one-line artist reference) | Primary distinguishing trait | Reinforcing (up-close) trait | Emotional read |
|------|--------------------------------------------------|------------------------------|------------------------------|----------------|
| **Trooper** (baseline) | Upright, symmetrical, medium-everything. The control group all others deviate from. | Balanced vertical rectangle silhouette — no dominant protrusion, even mass top-to-bottom. | Paired symmetrical limbs/weapon at mid-height; nothing breaks the outline dramatically. | Reliable, neutral, "the standard soldier." |
| **Heavy** | Trooper scaled up and widened — same DNA, more mass. | Widest footprint and bulkiest mass; silhouette is broad and bottom-heavy, wider than it is tall. | Blocky shoulder/chassis mass, short thick limbs; reads as *armor* not *speed*. | Immovable, dominant, slow-threat. |
| **Scout** | Low, horizontal, forward-leaning — built to move. | **Posture: low + horizontal**, longest ground-footprint of the roster, leaning into its travel direction. | **Appendage: locomotion shapes** — visible legs/wheels/treads implying motion even at rest. | Quick, darting, fragile-fast. |
| **Sniper** | Tall, vertical, planted — built to anchor. | **Posture: tall + vertical**, narrowest footprint, planted/rooted stance. | **Appendage: a single dominant linear protrusion** (barrel/scope line) *longer than the unit is tall*, breaking the silhouette top. | Patient, precise, fragile-static. |

**Resolving the Scout/Sniper collision (A+B).** Both are low-mass, so "spindly = fragile" cannot separate them alone. They are placed at **opposite ends of the posture axis** and given **opposite appendage languages**, so the read is carried by two reinforcing signals:

- **Primary (thumbnail / grayscale):** Scout reads **low and horizontal** (wide forward-leaning stance); Sniper reads **tall and vertical** (planted, narrow). At blob-on-a-tile distance, the horizontal-vs-vertical aspect ratio alone tells them apart.
- **Secondary (up-close / confirmation):** Scout's outline is dominated by **locomotion** (legs/wheels/treads); Sniper's by **one long linear barrel** exceeding the body's height. The confirming details point opposite directions.
- **Iso-proofing:** because the two signals are *aspect ratio* + *dominant-line direction*, they survive isometric depth-stacking — neither depends on a detail that occlusion or foreground overlap would eat (P1).

This maps a gameplay truth onto the silhouette (Pillar 2): the shape that *moves* leans forward and rolls; the shape that *anchors* stands tall and reaches. The player learns the counter from the outline.

### 3.2 Structure Shape Language

Structures are read through a **footprint + base-plate grammar** that makes them unmistakably *buildings, not mobile units* — the single most important structural read, because confusing a structure for a unit would break board legibility (Pillar 3) and AP planning (Pillar 1).

**Family rules (what makes all five read as "structures"):**
- **Grounded base-plate:** every structure sits on a flat, tile-aligned footprint plate that fills or frames its isometric tile(s). Units never have this plate — they have a small contact shadow and negative space around their feet. Base-plate = "fixed to the board."
- **Footprint scale:** structures occupy their tile(s) edge-to-edge; units float within a tile with margin.
- **Static, architectural geometry:** structures are stacked/extruded rectilinear volumes (no limbs, no locomotion, no leaning). Stillness of form = "immobile" before the glow confirms it.
- **Vertical growth, not lean:** structures express role through *what they stack upward* on a shared base — a consistent silhouette anchor so the eye files them together.

| Structure | Silhouette identifier | Reads as | Emotional read |
|-----------|----------------------|----------|----------------|
| **HQ** | Largest footprint (multi-tile), tallest massed central spire on a broad base — the roster's visual keystone. | The heart / capital. | Authority, the thing you defend. |
| **Economy Outpost** | Small footprint, low and wide, open collector forms (dishes/panels/intake shapes) — horizontal emphasis. | Passive income node. | Quiet, productive, unglamorous. |
| **Production Outpost** | Medium footprint with a distinct open bay/aperture in the silhouette (where units emerge) — a "mouth." | The factory. | Active, generative, purposeful. |
| **Defensive Structure** | Compact, thick, symmetrical with a single dominant elevated hardpoint/emplacement breaking the top. | The turret / bulwark. | Braced, hostile, guarded. |
| **Research Lab** | Tall-thin vertical element (antenna/spire/data-mast) on a small base — the most "delicate" structure silhouette. | The tech node. | Cerebral, fragile-valuable. |

**Anti-collision guardrails:** the Research Lab's tall-thin spire could echo the Sniper's vertical barrel — the base-plate + tile-filling footprint keeps them apart (Lab is grounded and static; Sniper floats and leans). The Economy Outpost's low-wide form could echo the Scout — same resolution: plate vs. locomotion shapes. The base-plate grammar is the firewall that lets structures and units share the angular vocabulary without ever being confused.

### 3.3 Environment Geometry

Terrain is **angular and geometric, never organic** — faceted planes, hard tile edges, crystalline/constructed rock and architectural ruin rather than rolling hills or blobby foliage. This suits Neon Retro-Future (TRON-grid lineage) and keeps terrain in a **low-detail, low-value register** so it never competes with actors (P3, Dark Stage).

- **Terrain shapes are large, simple, and few-sided.** A cover tile is a clean faceted block, not a detailed sculpt.
- **Elevation and depth are expressed through faceted planes and value steps** (Section 1's rule) — a higher tile is a lighter-valued angular plane, not a hue change and not a busier shape. Iso depth reads as *terrain information* (cover, high ground) through clean geometric planes.
- **Straight tile-aligned edges dominate.** Diagonal/orthogonal cuts follow the iso grid; curves are rare and reserved (they'd pull the eye and read as "special"). Angularity communicates a *constructed, contested, engineered* warzone — fought-over infrastructure, not wilderness.
- **No terrain silhouette may out-mass a unit at the same distance.** If a terrain feature's outline competes for attention, it's flattened or darkened.

### 3.4 UI Shape Grammar — Distinct-but-Related

The HUD uses a **simple, rectilinear shape language deliberately distinct from the world's faceted-angular unit shapes** — clean panels, thin rules, straightforward rectangles and clear icon forms, with *no ornamental faceting, no hex/crystal motifs borrowed from the board.* The relationship to the world is carried entirely by **color and glow grammar** (Section 2), not by shape: HUD neon behaves exactly like board neon (breathe = has AP/available, flare = spend, clamp = spent/unavailable), so it reads as the same design family without borrowing silhouette complexity.

Why (Pillar 3): if HUD chrome adopted the same busy angular language as units, it would compete with unit silhouettes for the eye. Keeping HUD shapes quiet guarantees that **the most complex silhouettes on screen are always the units** — so the eye is drawn to the board first (Section 1's core promise). The HUD is a *quiet instrument panel* around a loud stage; its restraint is what makes the stage legible.

### 3.5 Hero Shapes vs. Supporting Shapes

An explicit silhouette-complexity hierarchy governs where detail lives. Detail is a spotlight — it goes only where attention should go (Pillar 3), and attention follows AP-relevant decisions (Pillars 1 & 2).

- **Hero shapes (highest silhouette complexity, own the eye):** Units, and the AP-relevant beats they perform. Units carry the most intricate, most individuated outlines on screen and are the only objects permitted role-expressive posture/appendages. Lit and glow-active per Section 2. *These are the things that matter, and they look like it.*
- **Mid shapes (identifiable but static):** Structures. Individuated silhouettes but architecturally simple and grounded (§3.2); they hold identity without demanding moment-to-moment attention, matching their passive/slow gameplay role.
- **Supporting shapes (recede):** Terrain, cover, elevation (§3.3) — large, simple, low-value; and the HUD (§3.4) — quiet and rectilinear. The stage and the instrument panel. Never allowed to out-silhouette an actor.

Rule of thumb for any new asset: **the more a shape matters to a tempo decision, the more silhouette complexity it earns.** A unit about to act is the most detailed, most lit, most glow-active thing on screen; the tile it stands on is the least. That gradient *is* the readable board (Pillar 3), and it points the player's eye at the choices that win the tempo duel (Pillar 2).

*Out of scope but noted:* exact color/hue assignments (§4), and per-faction silhouette-family traits satisfying P2's "secondary non-hue marker" (§5, Character Design).

## 4. Color System

Color is the game's fastest channel — read before shape, before the HUD, before the player consciously thinks. Sections 1–3 spent most of the game's *value* budget on the dark stage and its *shape* budget on units. This section spends the last and scarcest budget: **saturated hue**. Every rule below answers one question an artist will eventually ask: *"can I make this neon?"* — and ensures the answer is almost always no.

### 4.1 Primary Palette — The Stage and The Actors

Two families, matching Principle 3's dark-stage/neon-actor split. Values are HSL ranges (indicative, not final-pixel) so any artist can produce consistent output without matching hex-for-hex.

**A. Dark Stage family** (terrain, structure base-plates, space/sky, UI chrome) — restrained, low-saturation, cool-leaning neutrals. The visual "floor" everything stands on.

| Role | HSL range | Indicative hex | Notes |
|---|---|---|---|
| Void / background (space, sky) | H 220–250°, S 15–25%, L 4–8% | `#0A0E17` | Near-black, faint cool tint — never pure black |
| Terrain base (walkable tiles) | H 210–240°, S 10–20%, L 14–22% | `#232A38` | The default board value; everything is measured against it |
| Terrain elevated (high ground) | Same hue, L +8–12% | `#33405A` | Value-only lift (§1 P3 / §3.3) — never a hue shift |
| Terrain recessed / cover mass | Same hue, L −6–10% | `#171C27` | Value-only drop |
| Structure base-plate / chrome | H 220–240°, S 8–15%, L 10–16% | `#1B2130` | Slightly cooler/flatter than terrain — reads "built," not "ground" |

**B. Neon Actor family** (faction hues + the achromatic accent) — reserved, high-saturation, used only per §4.6's budget rule.

| Role | HSL range | Indicative hex | Notes |
|---|---|---|---|
| Faction A — Rush | H ~10–20° (hot orange-red), S 85–95%, L 55–62% | `#FF5A2E` | See §4.2 |
| Faction B — Boom | H ~190–200° (cyan-azure), S 85–95%, L 55–62% | `#22C7F0` | See §4.2 |
| Neutral / unaligned | Achromatic — S 0–10%, L 70–80% (near-white/silver) | `#C6CED8` | Hue-less by design — "the value-neutral default," not a third ideology (§4.2) |
| Achromatic cursor accent | S 0%, L 88–95% (near-white) | `#EAF0F7` | Hover/selection only — never ownership (§4.3) |

A **7-color functional system** (5 stage neutrals + 2 faction neons), plus the achromatic neutral/cursor accents and the semantic *behavior* layer (§4.3) — which is disciplined reuse of existing channels, not a third bucket of hues.

**Reasoning (Pillar 3):** the stage family is deliberately narrow-gamut and low-contrast *within itself* — all stage differentiation is done in L (lightness), never H or dramatic S swings, which is what makes elevation/cover read as terrain information rather than decoration (§3.3).

### 4.2 Faction Hue Assignments

**Faction A — Rush (aggressive tempo): Hot Orange-Red, ~H15°.** Warm, advancing hues are the oldest color-theory association with urgency, heat, and forward motion — they psychologically "come toward" the viewer against a cool/dark ground, matching Rush's identity (pressure, speed, spend-now). Warm = aggressor is a near-universal RTS/tactics convention (C&C's red faction, SC2's warm accents), so it costs the player zero learning time. Ties to Pillar 4: Rush's ideology reads as "burn bright now" — the hue does thematic work, not just labeling.

**Faction B — Boom (compounding economy): Cyan-Azure, ~H195°.** Cool, receding hues read as stable, technical, patient — the opposite psychological register from Rush (Pillar 4: factions are opposite verbs, their colors opposite too). Cyan's high-tech/networked connotation (data, energy grids) suits an economy/research faction. Cyan-vs-orange is the most reliable warm/cool near-complementary pair — both highly saturated, both legible against the same dark stage.

**Structural risk (flagged):** the Dark Stage family (§4.1) is itself in the 210–240° cool-blue range — the same hue neighborhood as Boom. This is intentional (a cool dark stage makes any saturated hue pop) but means Boom's cyan sits closer to the stage than Rush's orange does. Mitigation is **saturation + lightness distance, not hue distance**: stage tops out at S 25%/L 22%; Boom sits at S 85–95%/L 55–62%. Recommend a same-scene side-by-side prototype test (Boom units on max-elevation terrain) before locking final hex.

**→ RESOLVED 2026-07-29 (S4-01 de-risk spike — hexes LOCKED).** The side-by-side test (analytic + swatch, `prototypes/s4-01-art-spike/`) ran Boom `#22C7F0` against all five §4.1 stage tiles. The worst case is the max-elevation tile `#33405A`, and even there Boom clears every bar: **ΔE2000 51.8** (perceptually *further* than Rush's 49.4 vs the same tile), **WCAG contrast 5.19:1** (passes AA), **grayscale value Δ 104/255** (passes the §4.4 desaturation test). Boom is only **28°** from the stage hue (vs Rush's 150°) yet sits **60% S / 26% L** away — the saturation-plus-lightness-distance mitigation is validated numerically; **no hue adjustment needed.** *Doc reconciliation:* the "stage tops out at S 25%/L 22%" figure describes terrain *base* (`#232A38`, L 17.8%); the max-elevation tile `#33405A` actually reaches **S 27.7% / L 27.6%** — Boom was tested at (and passes at) that true brighter ceiling, so read the ceiling as ~L 28% at max elevation. A residual windowed eyeball is folded into S4-07.

**Colorblind-safety of the A/B pair:** orange-red (~H15°) vs. cyan-azure (~H195°) is ~180° apart and falls on opposite sides of the red-green confusion axis (protanopia/deuteranopia, ~8% of men). Neither is a red-green pair with the other — about as safe a two-faction assignment as exists. Tritanopia risk on Boom's cyan is addressed in §4.4.

**Neutral / unaligned faction (LOCKED — achromatic, Option N2):** Neutral is treated as **achromatic** (near-white/silver, S 0–10%, L 70–80%, no hue). This keeps the reserved-neon budget at exactly two hues (Rush, Boom), matches Neutral's design intent as *the value-neutral default* (the absence of a faction claim, not a third ideology — it is named "Neutral" in the registry roster), and is trivially colorblind-safe since it carries no hue information. Consequence: the **Neutral-vs-Neutral mirror match** (which the VS ships) leans entirely on the §1 P2 secondary non-hue markers (silhouette-family trait, trim pattern, emblem) to carry ownership — which must exist anyway for colorblind players in *any* matchup, so this is a forcing function, not a new cost. *(→ **S4-02 reconciliation, 2026-07-29:** the VS art authors all three hue variants (rush/boom/neutral), and the recommended VS wiring is **Rush-vs-Boom** so ownership reads by hue — matching scope §5's "ownership clear by hue" iso-legibility acceptance and the S4-01 hue validation. A true Neutral-vs-Neutral mirror would still need the per-owner non-hue markers named above. See `design/assets/specs/vs-entities-assets.md` § Scope Reconciliation.)*

**Reserved naming for Factions 3–6 (Full Vision):** hue slots assigned by **maximum pairwise hue-wheel distance** from all previously-assigned faction hues — theme is fit to the hue slot, not the reverse, so colorblind-safety is structural. Suggested order: Faction C ≈ H280–300° (violet-magenta), Faction D ≈ H60–75° (yellow-chartreuse). Factions E/F resolved only once C/D are validated — 5–6 simultaneous saturated hues on one board is a Pillar-3 legibility risk that may force the non-hue marker system to carry more weight than hue at that scale.

### 4.3 Semantic Color Vocabulary — and Why It Cannot Collide With Faction Hue

Beyond ownership, color/glow communicates: AP-available vs. spent, valid vs. invalid target, damage/lethal, cover/high-ground, selection/hover, go/no-go tiles. This is the **hardest problem in the system**: a tactics game's semantic layer is normally *also* built from saturated accents (green = go, red = danger), and Rush is already red-orange while a future faction reservation claims yellow. If semantic color reused faction-color logic, "valid target" and "Rush unit" would eventually collide — catastrophically, exactly in high-pressure combat (§2.4).

**The solution is structural: semantic state is carried by *value and glow behavior* (§2 vocabulary), never by introducing or reusing a hue.**

- **AP-available vs. spent** — the **breathe vs. clamp** glow-behavior pair (§2.1/§2.6) on a unit's *own faction-colored* trim. The hue never changes, so it can't be confused with "whose unit is this."
- **Valid / invalid target, hover, selection (board overlays, not actors)** — built from **outline weight, brightness pulse, and pattern (hatch/dither) on the dark-stage neutral family, not the neon family.** A valid-move tile is a *brighter, animated stage-neutral* (not a green tile); an invalid/excluded tile is *darker or hatched* stage-neutral. Neither borrows saturation from the reserved hues.
- **Damage / lethal** — flare-and-decay (§2.2) intensified on the *acting unit's own faction hue* — "more of this unit's identity color, urgently," not a universal red flash. Lethal gets the held/no-pulse "fixed" treatment (§2.4). (If lethal flashed red, every Rush action would look like a death-blow.)
- **Cover / high-ground** — pure value (§3.3/§4.1). Geography, not state — no hue, no glow.
- **Selection / hover** — the one earned non-faction accent: a thin **near-white, hue-less** ring on whatever is under the cursor. Outside both the stage-neutral range (too low-S for terrain) and the faction range (no hue) — it can only ever mean "your cursor is here."

**Why this is a system, not a patch:** every semantic signal is a *modifier on an existing channel* (value shift, glow-behavior swap, pattern, achromatic accent), never a new hue. There are exactly two hues in the reserved family (Rush, Boom) and they only ever mean "whose," never "what state." Everything non-ownership is colorblind-safe by construction. This names, once, what Combat Resolution and Command & Action Interface each invented independently (neon-free dead-zones, impassable tiles): **the Non-Hue Semantic Layer.** Future GDD Visual/Audio sections should cite this subsection rather than re-derive it.

### 4.4 Colorblind Safety

| Pair / element | Risk type | Backup (ties to §1 P2 / §3 shape system) |
|---|---|---|
| Rush (orange-red) vs. Boom (cyan-azure) | Low — near-opposite hues, cross the red-green axis | Still requires §1 P2's secondary non-hue marker per faction — never rely on hue alone, since lighting, calibration, and glow-blur degrade hue at distance |
| Rush vs. Neutral | None — Neutral is achromatic (no hue to confuse) | Neutral's §1 P2 emblem/pattern marker carries all ownership in the mirror match |
| Future Faction D (yellow ~H65°) vs. stage elevation highlights | Tritanopia — yellow can wash toward lifted-elevation neutral | Elevation lightness-steps (§3.3/§4.1) stay separated in *lightness*, never hue — holds for D too |
| Semantic "valid/invalid target" overlays | Any type — mitigated by design | Never hue-coded (value + pattern + behavior); confirmation, not a new risk |
| Lethal / critical damage flare | Any type | "Held, no-pulse, brightest" (§2.4) is a brightness+stillness signal, readable in full grayscale |

**General rule:** no game-state information may be encoded in hue alone anywhere except faction ownership — and even ownership carries a mandatory non-hue backup (§1 P2). The whole palette passes a grayscale-simulation test in principle: desaturate the screen and factions stay distinguishable by shape/pattern marker, and every semantic signal stays legible because none were hue-dependent.

### 4.5 UI Palette

Per §3.4, HUD shapes are plain/rectilinear (distinct from the world's faceted vocabulary) but its **color and glow grammar is identical to the board's**, so it reads as the same family without shape complexity.

- **HUD chrome** pulls from the Dark Stage family (§4.1) — recedes behind the board like terrain does ("the board is the star, the HUD is an instrument panel," §3.5).
- **HUD faction elements** (portrait frames, resource counters, turn-order indicator) use that player's exact faction hue and the *same* glow behavior as board units — breathe/flare/clamp. A player reads "do I have AP left" from HUD glow alone.
- **HUD semantic elements** (greyed buttons, warnings, disabled verbs) use the Non-Hue Semantic Layer (§4.3) — value dimming and pattern, never a new "UI red/green." Prevents the HUD from accumulating a parallel color language (the overclaim risk flagged in the Command & Action Interface review).
- **HUD achromatic accents** reuse the same near-white hover/selection accent — one accent color, one meaning, everywhere.

No new hues for UI. If a HUD screen seems to need a color the board lacks, that signals an undesigned semantic *class* (per §4.3), not a license to add a hue.

### 4.6 The Neon Budget Rule

**A saturated neon hue may be used only for: (1) faction ownership, and (2) semantic *behavior* riding on an actor's own already-established faction hue (breathe/flare/clamp/rim-light, §2). The cursor/selection accent is deliberately hue-less (near-white), not a third saturated color. A saturated hue may never be introduced for a new concept, a UI screen's "personality," a generic warning/success color, or a decorative flourish.**

Before adding any new saturated color, ask, in order:

1. **Is this ownership?** → Use the owning faction's assigned hue only. Never invent a hue for a sub-faction, squad color, or cosmetic variant — use the non-hue marker system (§1 P2).
2. **Is this a game-state signal on an existing actor?** → Express it as a *behavior change* (glow pulse rate, flare, clamp, rim-light) on that actor's *existing* hue — never a new hue.
3. **Is this board/UI info that isn't ownership or actor-state?** → It belongs in the Dark Stage family with value/pattern differentiation (§4.3), not the neon family — even if it feels like it "deserves" to pop.
4. **Is this a menu/showroom context (§2.7)?** → The ratio loosens (fuller, more saturated faction neon across more of the frame) but the hue set does not expand.

If none of the above justifies it, the answer is no — dim it, desaturate it, or express it through value and pattern. **This keeps "neon means this matters" true for the life of the project:** every unearned saturated pixel is a small tax on every earned one.

## 5. Character / Unit Design Direction

### 5.0 Register Decision — Infantry Now, Vehicles/Mechs Later

The Vertical-Slice roster (**Scout, Trooper, Heavy, Sniper**) is **infantry**: human soldiers in sealed, powered combat armor — XCOM / StarCraft-marine lineage, not mechs. This is a deliberate register lock, distinct from an earlier mech-first draft.

A later production phase (out of VS scope, its own production structure) is expected to add **piloted vehicles and/or mechs** via a piloting mechanic. Every rule in this section is written to be **body-plan-agnostic**: the faction-marker logic (§5.2) and the silhouette/LOD logic (§5.1, §5.5) must be expressible on a human-scale infantry silhouette *now* and extend without redesign to a much larger chassis silhouette *later*. Where a rule would only make sense for a bipedal humanoid, it is flagged as infantry-specific rather than left ambiguous. This section is the load-bearing forward-compatibility contract for that future roster tier — a vehicle/mech artist should be able to read this section and know exactly which rules still apply and which get more real estate.

### 5.1 Unit Register & Material Identity

**Spec: powered-armor sci-fi soldiers, sealed helmets, chunky readable-over-realistic proportions.**

- **Sealed helmet, no face.** Every infantry unit reads through armor plating and a fully enclosed helmet — no exposed skin, no facial acting, no visible eyes. This is a direct execution of §1's rule (*clarity from silhouette + color, never surface detail*): a face is the single most detail-hungry, most attention-grabbing surface a humanoid shape can carry, and it would compete with the neon-state layer (§2) for the eye exactly where Pillar 3 needs attention to go to AP-relevant reads instead. A sealed helmet also removes the entire "individual likeness" problem for a solo/small-team pipeline — one helmet silhouette per role, reused across factions with only the §5.2 kit markers changing.
- **Chunky, Advance-Wars-adjacent proportions, not anatomically realistic ones.** Infantry are drawn with **exaggerated mass ratios** — oversized shoulders/chest, shortened and thickened limbs, a compressed torso-to-limb ratio — rather than realistic human proportions. This is the direct answer to the stated stress case: **infantry are small at iso tactical zoom**, and a realistically-proportioned human (thin limbs, narrow torso) degrades into a grey smear of near-identical thin verticals at thumbnail size, exactly where §3.1's roster-family read (posture axis + mass axis) needs to survive. Chunky proportions push each role's silhouette rule (§3.1's table — Trooper's balanced rectangle, Heavy's wide bottom-heavy mass, Scout's low horizontal lean, Sniper's tall planted profile + long barrel) to survive being rendered at 24–40px effective height on a tile. Realism would only be legible at a zoom level this game does not ship at.
- **Material language:** matte, hard-surface armor plating in flat value blocks (§6.2's flat/painted terrain rule applies equally to units) — no specular highlight, no cloth-sim, no skin-texture reads. Trim, vents, and joint plating are large simple shapes, not greebled detail; per §3.5, units earn the *most* silhouette complexity on the board, but that budget is spent on **outline shape**, not on **surface micro-detail** — the two are not the same currency, and §1 forbids spending on the latter.
- **Actor value: units are LIGHTER than the stage (P3 — added 2026-08-19, production-validated).** Unit armour is **`#6E7C99`** (cool slate) with `#3E4860` shadowed facets — deliberately *above* every stage tile in lightness, where structures stay near-black `#1B2130`. This is the operational form of §3.5's hierarchy (units are the hero shapes that own the eye; no terrain silhouette may out-mass a unit) and of §1's iso-proofing rule. It exists because the first production pass specced unit armour in the `#232A38` family — **the exact value of the plain terrain tile** — and the units vanished into the board: at true sprite size only the accent trim survived, and in grayscale the silhouette was unreadable, failing §1's identifiable-by-outline-alone test outright. Measured separation: luma Δ82 vs terrain base `#232A38`, Δ60 vs the max-elevation tile `#33405A` (the worst case), and Δ82 below Neutral silver `#C6CED8` so slate never reads as a faction claim. **The stage is dark so the actors can be light** — the dark-stage identity lives in the terrain and the structures, not in the units standing on them.
- **Body plan is a legitimate role-separation axis (added 2026-08-19).** §3.1's role silhouettes may be expressed through **different body plans**, not only through proportion differences within one humanoid shape: the shipping roster uses a low four-legged walker (Scout — this is what actually delivers §3.1's "outline dominated by locomotion"), an upright biped (Trooper, the control group), and a squat wide-planted walker (Heavy). Production evidence: three humanoid variants differentiated only by proportion adjectives failed the §5.2 grayscale role test — they read as one shape at three widths — while the body-plan roster separates cleanly with no hue information. The sealed-helmet rule above is satisfied by the walkers having **no head at all**, which serves the same purpose (nothing competing with the neon-state layer) more strongly than a helmet does.
- **Forward-compat hook:** a later piloted-vehicle/mech tier is produced under the exact same three rules — sealed cockpit/no face-read, exaggerated (not realistic) mass proportions, flat hard-surface material language — just at a **larger silhouette budget** (§5.5). A mech is not a different design language from a soldier; it is the same language with more silhouette real estate, because it will occupy more of the tile and more of the screen. Nothing in this subsection is infantry-only.

### 5.2 Per-Faction Silhouette-Family Markers (P2 — Body-Plan-Agnostic)

> **VS scope note (S4-02, 2026-07-29):** the Vertical Slice ships **hue-only ownership with one
> shared silhouette per role** — the per-faction Mass Distribution Bias below is **deferred to Full
> Vision** with Pillar-4 faction asymmetry (recorded in `design/assets/entity-inventory.md` #1 and
> `design/assets/specs/vs-entities-assets.md`). Read this section as the full-vision target, not the
> VS backlog; VS hue variants (rush/boom/neutral) are re-hues of one silhouette per role.

This is the mechanism that satisfies §1 Principle 2 ("Ownership Legible Beyond Hue") for units specifically. A human body can't be "raked" or "swept" the way a vehicle chassis can — so faction identity on infantry lives in **kit and armor-profile silhouette**, not chassis geometry. The trick that makes this body-plan-agnostic: define each faction's marker as a **mass-distribution principle**, not a humanoid-specific shape, so the same principle re-renders correctly on a tank or mech later without redesign.

**Named principle: Mass Distribution Bias.** Every faction's non-hue marker is where a unit's *silhouette mass sits* relative to its direction of travel/action — forward-light vs. rear/body-loaded vs. neutral-even. This single continuum is expressible on any body plan: a soldier's kit-load silhouette, a vehicle's hull/turret-mass balance, a mech's chassis/backpack silhouette. Faction hue (§4.2) still carries primary ownership; Mass Distribution Bias is the secondary, hue-independent confirmation, exactly as §1 P2 requires.

| Faction | Named kit family | Infantry silhouette trait (now) | Vehicle/mech translation (later) | Emotional/thematic tie |
|---|---|---|---|---|
| **Rush** | **Light Kit** | Forward-light mass distribution: stripped-down chest/back profile, minimal pack silhouette, weapon/forearm mass reads as the *leading* edge of the outline. Lean, economical silhouette — nothing trails behind the unit's forward line. | Same forward-light bias on a chassis: low rear deck, minimal turret overhang, hull mass concentrated toward the front/leading face — a tank or mech that visually "leans into" its heading. | Mirrors Rush's mechanical identity (cheap, fast, spend-now, per faction-identity.md) — the silhouette *looks* like it costs less to move, before the player ever reads a hue. |
| **Boom** | **Heavy Kit** | Rear/body-loaded mass distribution: bulky backpack/reactor-pack silhouette, thickened rear plating, load-bearing frame visible behind the shoulder line — mass trails and stacks *behind* the unit's forward line. Loaded, provisioned silhouette. | Same rear-loaded bias on a chassis: oversized rear engine/reactor housing, turret bustle, stacked hull modules trailing the hull's front face — a tank or mech that reads as "carrying its own infrastructure." | Mirrors Boom's mechanical identity (compounding economy, invests now/pays later) — the silhouette *looks* provisioned for a long game, before hue confirms it. |
| **Neutral** | **Standard Kit** | Minimal/unarmored baseline: no forward or rear mass bias, no visible pack, cleanest and least-adorned silhouette of the three families — deliberately the "default," carrying zero kit-load storytelling. | Same even-baseline bias on a chassis: symmetric hull, no bustle, no forward overhang — the reference silhouette other chassis are judged against, same role §3.1 gives Trooper among unit roles. | Neutral is achromatic by design (§4.2) — it carries **all** ownership information through this marker family, since it has no hue to fall back on. Its silhouette must therefore be the most legible baseline of the three, not an afterthought. |

**Coexistence with per-role silhouettes (§3.1).** Mass Distribution Bias rides *on top of* the role silhouette, not instead of it — a Rush Scout and a Boom Scout must both still read as "Scout" first (low/horizontal posture + locomotion appendage, per §3.1's table), with the forward-light vs. rear-loaded kit bias as a secondary confirming read layered onto that same base silhouette. Practically: the role silhouette sets the *outline family* (posture + dominant appendage); the faction kit bias sets *where the mass sits within that outline*. Neither overrides the other — a Boom Heavy is still unmistakably a Heavy (widest, bottom-heavy mass) with its backpack/rear-plating bias layered on top, not a shape that stops reading as Heavy.

**Solid-black-silhouette validation test.** Render each of the 4 roles × 3 factions (12 combinations) as flat solid-black silhouettes with zero color, zero neon, at the shipping isometric camera angle and at actual in-game tile scale. Pass condition: (1) the **role** is identifiable from the outline alone in all 3 faction variants (§3.1's existing test, now run per-faction); (2) the **faction** is identifiable from the outline alone across all 4 roles — a viewer shown only silhouettes should be able to sort "which of these came from the same faction" correctly at a rate meaningfully better than chance. This is the P2 acceptance test made concrete for units, and it must be re-run for any future vehicle/mech silhouette using the same Mass Distribution Bias principle before that tier ships.

### 5.3 Distinguishing Ally / Enemy / Neutral at a Glance

No single signal is allowed to be a single point of failure (colorblind vision, grayscale broadcast capture, fog/overlay occlusion all must degrade gracefully). Signals are layered in priority order, each independently sufficient to *narrow* the read even if a higher-priority signal is unavailable:

1. **Hue (fastest, primary — §4.2).** Rush orange-red vs. Boom cyan-azure vs. Neutral achromatic. Read first, in normal play, at full color fidelity.
2. **Mass Distribution Bias (§5.2 — the mandatory non-hue backup).** Forward-light (Rush) vs. rear-loaded (Boom) vs. neutral-even (Neutral) silhouette. Survives colorblind vision and full desaturation, since it is a shape fact, not a color fact.
3. **Board position / turn-context convention.** Standard tactics-genre spatial conventions (each player's forces read from their controlled structures/deploy zone outward; the active player's units carry the §2.1 breathe/idle glow, the opponent's do not during the player's own planning phase) provide a tertiary, situational confirmation — useful exactly when a unit is small, partially occluded, or mid-animation and neither hue nor silhouette is fully legible in that instant.

Because hue and Mass Distribution Bias are independent channels (one chromatic, one geometric), losing either one in isolation (colorblindness removes reliable hue distinction; heavy occlusion or extreme zoom-out can blur silhouette nuance) still leaves a working signal from the other, with position/context as a fallback tiebreak. No degraded viewing condition is allowed to make faction identity fully unreadable — this is the same discipline §4.4's colorblind-safety table applies to the palette, extended to the shape layer.

### 5.4 Expression & Pose Register

- **Sealed-helmet, mechanical-but-human.** Units communicate readiness and intent through **posture and armor-plate geometry**, never facial expression (§5.1 — there is no face to read). A unit "looks" alert, spent, or resolute the way a suit of powered armor would: weight distribution, stance width, weapon-ready angle — not a raised eyebrow.
- **Idle state is carried by §2's neon-breathe, not body-language theatrics.** Whether a unit "has options" is communicated by the glow-breathe/clamp behavior on its trim (§2.1/§2.6), *not* by an idle animation acting out impatience, confidence, or fatigue through pose. This keeps the state channel disciplined to the one place it lives (Section 2's vocabulary) instead of splitting "is this unit ready" across two competing systems (glow AND pose-acting) that could disagree with each other.
- **Action poses are utilitarian, not theatrical.** Attack, move, and hit-reaction poses read as functional mechanical operation — a weapon-ready crouch, a directional lean into a move, a plating-absorbs-impact recoil — not exaggerated wind-up flourishes or victory-pose theater. This matches §2.2's "click of a well-oiled mechanism" emotional target for Action Resolution: the pose should feel like a discrete, efficient cause-effect, not a performance.
- **No cartoon visor-eyes.** A glowing visor slit, animated "eye" light, or expressive HUD-eye graphic on the helmet is explicitly disallowed — it would reintroduce exactly the surface-detail/facial-acting read §5.1 removes, smuggled back in through the one part of the helmet most tempting to animate. If a helmet needs a small functional light (e.g., a status LED), it follows the Non-Hue Semantic Layer (§4.3) or faction-hue rules like any other actor detail — it is never used to fake an expression.

### 5.5 LOD Philosophy

**Silhouette-first at small iso infantry scale**, with a strict detail-budget order — each tier below only earns pixels once the tier above is unambiguous:

1. **Silhouette (role + faction-family read) — highest priority, always legible.** The role outline (§3.1) and the faction Mass Distribution Bias (§5.2) must both read correctly at the actual shipping tile scale before anything else is added. If a unit fails the §5.2 solid-black test at shipping scale, the fix is silhouette redesign — never a color or detail patch (this is the same discipline §1 P1 enforces for terrain).
2. **Neon state (glow behavior) — second priority.** Once the silhouette reads, the §2 glow vocabulary (breathe/flare/clamp) is the next thing that must be legible — this is the "what is it doing" layer riding on top of "what is it."
3. **Faction-color blocking — third priority.** The hue itself (§4.2) is applied as large, simple color fields matching the silhouette's major masses (the Light Kit's forward plating, the Heavy Kit's rear pack) — confirmation of the family already established by shape, not a substitute for it.
4. **Disposable greeble — lowest priority, cut first under any budget pressure.** Panel lines, small vents, minor trim detail, cosmetic bolts/rivets — anything that doesn't change the silhouette outline or the color-block read. This tier is explicitly the first thing sacrificed for performance, art-pipeline time, or at distance/small-scale rendering, because losing it costs the player nothing readable.

**Forward-compat note:** the future vehicle/mech tier gets a **larger silhouette budget** (bigger hero shapes, more screen area, more tile footprint per §3.5's hero-shapes hierarchy) — but it obeys the exact same four-tier order. A mech is allowed more *silhouette* complexity than a soldier; it is never granted permission to skip straight to greeble or color before its own Mass Distribution Bias and role read are locked. Scale changes the budget size, never the priority order.

## 6. Environment Design Language

### 6.1 Architectural Style & World Fiction

OVERCLOCK's battlefields are **contested infrastructure, not wilderness**: fortified colony platforms, orbital docking arrays, industrial power/comms installations, and their ruins after multiple factions have fought over them. Every map answers "what was this *for*, before it became a battlefield?" — a refinery yard, a transit hub, a research annex — never an untouched biome. This extends the locked §3.3 rule (terrain is angular/geometric, architectural, never organic) into fiction: the world is built, not grown, because the factions fight over **territory, resources, and governing principles** (game-concept.md setting), and built things are what rival principles fight to control or deny each other.

This serves **Pillar 3** directly. Architectural forms — slabs, gantries, bulkheads, platforms — default to hard edges, right angles, and repeatable modules: exactly the large, simple, few-sided silhouettes the board needs at isometric tactical zoom. A ruined refinery reads as clean rectilinear masses with damage as *value/edge* variation (§6.2), never noisy organic rubble. Wilderness terrain would invite curved, high-frequency silhouettes that fight the "few-sided" rule and cost more shape-reading effort per tile.

Recommended register: **industrial-institutional sci-fi** — power stations, orbital elevator bases, colony administrative blocks, comms relays, cargo terminals — built at infrastructure scale, now repurposed as a battleground. Avoid pure "military base" (too generic, no ideology-of-place) and pure "ancient ruin" (implies nobody built it for a reason the factions care about). Infrastructure framing lets every map imply *why* it's contested without a single line of text (sets up §6.5).

### 6.2 Texture Philosophy

**Flat/painted, not PBR.** Terrain surfaces are large flat color fields differentiated by lightness steps (§4.1), with hand-placed hard-edge value blocks standing in for material change, damage, or grime — never specular highlights, normal-mapped bump detail, or photoreal material response. This is the direct execution of §1's rule: *clarity from silhouette + color, never surface detail*. A PBR pipeline would put visual information *into* the surface — where §1 forbids reading from — and would pull focus toward terrain, violating §2's "terrain must never compete with neon actors."

- **No baked micro-detail** (scratches, cracks, grime as texture noise). Damage/history is a **flat value patch or hard-edged silhouette notch** (a chunk missing from a slab, a dark scorch-block), not a decal or normal map.
- **Materials are communicated by flat color/value families, not shaders**: metal deck = one restrained neutral value band, ruined masonry = a slightly different band, energized/active infrastructure = the one terrain exception permitted a **dim, desaturated hint** of hue (never neon-intensity) to distinguish "still powered" from "dead" — kept well below actor-neon saturation/brightness.
- **Low per-tile budget by construction**: detail is banned by design, not just by budget — the cheapest possible pipeline for a solo/small team. Use a **tile-variant kit** (a handful of pre-painted flat variants per terrain type: clean / cracked / scorched / rubble-edge) swapped per-tile rather than procedural texture generation, keeping the "constructed installation" read hand-curated per §3.3's hand-crafted maps.

### 6.3 Tile & Cover Expression (Pillar 3 — unambiguous at a glance)

The hardest constraint here: **cover and plain must be distinguishable by silhouette/value alone, without hue, and never confusable with props or units.** Solution — a **floor-lifts-vs-floor-breaks convention**:

- **Plain tiles:** flat, flush terrain-base value (`#232A38`, §4.1), no silhouette break within the tile bounds. Reads only as "open."
- **Cover tiles:** a **low, tile-spanning geometric mass** — a knee/waist-high bulkhead segment, stacked crate-block, or barrier slab — rendered as a **lighter-value faceted plane** (same +L logic as elevation) but distinguished from true elevation by **footprint**: cover breaks the tile with a hard object-silhouette at knee-to-waist height in iso; elevation raises the *entire tile plane* uniformly. **Elevation lifts the floor; cover breaks the floor with an object silhouette.** A Gestalt figure-form distinction (not just brightness), so it survives a colorblind pass — resolving the Grid-Terrain "binary vs. degrees cover" open question by giving binary cover one non-negotiable silhouette.
- Cover's value sits **one lightness step above Terrain base** (same +L family as Elevated `#33405A`), disambiguated from elevation by the footprint/mass rule — never by a second hue or a third value bucket (§4.1's closed palette).
- **No pattern/hatch texture on cover** (would contradict §6.2's flat-surface rule and risk the "loud non-actor effect" problem). The silhouette *is* the signifier.

**Elevation** (per §3.3): a uniform, whole-tile lighter-valued faceted plane, one clean lightness step up, with a hard tile-aligned "step" edge (not a gradient). Never combine an elevation step and a cover mass on the same tile edge ambiguously — if a design needs "cover on high ground," the cover mass sits inset from the elevation edge so both silhouettes stay separately readable.

**Impassable** (out of the two-type VS scope, noted for consistency): the "wall" register — full-height, opaque, void-adjacent value (`#171C27` family or darker), per Grid-Terrain's Visual/Audio Requirements — the darkest, least-permeable end of the §4.1 value scale.

### 6.4 Prop Density Rules

**Sparse, disciplined by one rule: anything that isn't a gameplay-flagged tile (Plain/Cover/Impassable/Elevation) must be visually incapable of being mistaken for one.** (Pillar 3, from the brief.)

Props live off the tile-occupancy silhouette entirely:
- Decorative props (conduit runs, dead signage, support struts, small debris) are **thin, low-mass, or background-adjacent** — never a knee/waist tile-spanning mass (that silhouette is reserved for Cover, §6.3).
- Props are **value-recessive**: at or below Terrain-base lightness, never at the +L Cover/Elevation step. Brightness is reserved for gameplay-relevant terrain and actors.
- Props are **placed off primary movement/combat tiles** where possible — corners, edges, wall-adjacent — reading as backdrop dressing, not board furniture.
- **Density ceiling:** no more than one decorative prop per ~4–6 open tiles per region, and **never adjacent to a Cover tile** (which would create the "is that block cover or decoration?" ambiguity this rule prevents). Hand-authored maps make this enforceable per-map.
- Props never use the Cover/Elevation lightness step, never use hard tile-spanning geometry, and never carry hue — strictly within the flat dark-neutral Terrain family.

Per-prop test: *does this read heavier, lighter, or bigger than a Cover mass? If yes, cut it down until it doesn't.*

### 6.5 Environmental Storytelling

Contested-sector / competing-ideology fiction is told through **damage state and construction seams**, never text or lore-dump props. This section restates, as a named citable rule, the principle §4.3 formalized as the Non-Hue Semantic Layer: **non-actor board information never carries saturated / actor-intensity hue.**

- **Faction-neutral scarring, not faction-owned scarring.** A tile/structure that changed hands shows **generic combat wear** — scorch-block value patches (§6.2), a missing facet in an Impassable wall, a Cover mass with a sheared corner — using only the neutral dark-stage value family. It **never** picks up a faction hue to indicate "faction X held this"; a hue-tagged ruin would be a terrain silhouette competing with neon actors by another name (§1/§2/§4.3).
- **Tell "fought over" through asymmetry of wear, not color:** damage concentrated on one face (attack direction), a partially-collapsed gantry mid-span (cut off, not decorated), scorch clusters around a chokepoint (repeated engagements) — history read through composition and value at the same flat/no-detail fidelity as undamaged terrain.
- **Show competing principles through architecture typology, not color/iconography:** contrast an intact admin block's grid-regular orthogonal module language against an adjacent improvised/breached section (irregular gaps, salvaged infill at a slightly different value) in the *same* map — "seized and hastily repurposed" told purely through silhouette-language contrast, still angular/geometric on both sides (§3.3), just two geometric dialects (regular grid vs. broken/patched grid).
- **Ruin state is a value/silhouette fact, never a hue fact, and never denser than §6.4 allows.** A battle-scarred map still passes the "cover mass vs. decoration" and "terrain must recede" tests. Storytelling is a *modifier* on existing tile/prop categories (a Cover mass gets a chipped-corner variant; a prop gets a toppled variant), not a new visual channel — the §6.2 tile-variant kit is the single production mechanism for both variety and lore-through-wear.

## 7. UI / HUD Visual Direction

Authored jointly with a UX-alignment pass (verdict: SUPPORTS WITH CONCERNS — the three accessibility requirements it raised are folded in as §7.6). The HUD's north star (Pillar 1): the single AP pool is the central number of the game, and the HUD's first job is making AP allocation legible before commit.

### 7.1 Diegetic vs. Screen-Space HUD

**Screen-space HUD, zero diegetic information display.** A diegetic/in-world HUD would force game-state reads *through* the same iso depth, occlusion, and value variance §1 P3 / §3.3 work to keep out of readability — foreshortening, occlusion behind foreground tiles, legibility loss against a variable dark stage. Screen-space guarantees the AP counter and cost previews render at **fixed size, contrast, and position regardless of board state** — the meaning of §3.4's "a quiet instrument panel around a loud stage." The one in-world exception is the **board overlay layer** (reachable tiles, per-tile cost badges, target brackets), which is the board's job (system #9) governed by §4.3's Non-Hue Semantic Layer — §7 covers the persistent screen-space frame, not the overlay.

### 7.2 Typography

A **geometric sans** (circular bowls, even stroke weight, the readable half of a TRON interface) carrying tech character through proportion/spacing, not gimmick strokes or scanline treatments. One family, two disciplined roles: **Display/Numeric** (tabular figures, condensed, uppercase labels — for the AP counter and all cost numbers) and **Body/Label** (neutral width, mixed case — unit names, menu labels, log). A second unrelated typeface would be the text equivalent of borrowing the board's ornament into the HUD (§3.4).

**The AP counter is the largest numeral on the HUD, full stop** — no other HUD number may match or exceed its size (literal execution of Pillar 1). **Tabular figures only** so the counter's width never jitters as digits change. Per the game-hud GDD's `current → projected` convention (e.g. "9 → 4"), the committed value is the heaviest weight; the projected value is a lighter weight of the same size. Everything else is subordinate by ≥2 size steps — exactly one "read this first" numeral per screen. *(Typeface personality is specified; a specific face is deliberately left unlocked for later selection.)*

### 7.3 Iconography

**Flat, geometric, single-weight glyphs — never illustrated, rendered, or beveled** — recognizable in solid silhouette at 24–32px (§1's discipline at HUD scale). Unit/structure icons are a **compression of the existing §3 silhouette rule** (Sniper icon keeps the long top-breaking line; Heavy keeps the wide bottom-heavy mass), derived from the §3.1 table rather than freehand. Action icons (Move/Attack/Overwatch) are a **separate abstract glyph set** so "unit" iconography never reads as "action" iconography. Icons carry meaning via shape + the Non-Hue Semantic Layer, never a new hue: a disabled/unaffordable icon is value-dimmed and/or hatched, not recolored red; a faction frame may use faction hue as an accent, but the glyph itself stays achromatic. Simplicity ceiling: one shape family, one stroke weight, max two features per icon (icons are supporting shapes per §3.5).

### 7.4 Animation Feel

The AP counter is the HUD's own "actor" (Pillar 1) and uses the §2 glow vocabulary:
- **Breathe (AP available):** at turn start with AP unspent, the counter (or a rule beneath it) carries the slow low-amplitude glow-breathe of an actionable unit (§2.1) — "I still have options," readable from the HUD glance alone.
- **Flare (spend):** on a real commit the counter's value **snaps** to the new number (never tweens/counts up, per the game-hud rule) with a fast flare-and-decay riding on top — the "snappy AP-spend feedback" the concept calls for.
- **Clamp (exhausted):** at 0 AP the counter suppresses to the steady-low clamp state (§2.1/§2.6) — the same "spent" signature the board taught.
- **The `→ projected` echo uses NO glow** — it snaps in/out as inert weight-differentiated typography (§7.2), so a fast mouse-sweep across tiles never produces glow-chatter. Motion/glow = "this really happened"; static weight-shift = "this might happen."
- Panel/menu entry uses fast value-based fades/slides within the Dark Stage neutrals — chrome moving, never glow (only faction/AP elements are licensed for neon, §4.5).

### 7.5 Pre-Commit Cost Preview

Pillar 1's flagship affordance, built entirely on existing machinery. Hovering/selecting a valid destination updates the AP counter to `current → projected` in the *same* font, position, and family as the idle counter — never a separate color-coded "cost widget." Unaffordable actions show the current value + an "insufficient AP" state (never a negative number, never a red numeral) via value-dimming + hatch/strike on the arrow (§4.3/§4.5). Board-side, per-tile costs use in-cap (brighter animated stage-neutral) vs. over-cap/surcharged (hatched/darker stage-neutral) — the screen counter and board badges are the same system from two locations. **No cost preview ever uses a saturated hue to mean cheap/expensive** (§4.6 — cost is quantity, not ownership/state). The preview **snaps** on every hover-change with zero interpolation — the "what will this cost me" readout must never lag the mouse, or the perfect-information pre-commit promise breaks in feel.

### 7.6 UX & Accessibility Requirements (from the UX-alignment pass)

Three requirements the visual direction must honor — additive to the above, not in tension with it:

1. **Every glow-behavior state has a named static backup.** Glow/animation is never the *sole* carrier of a state (reduced-motion and low-vision safety). AP-available/spent is always *also* legible from the number, weight, and (where present) an icon/pip state — the glow is a reinforcing channel, not the only one. Any future HUD element that introduces a glow behavior must specify its static fallback in the same breath.
2. **The near-white hover/selection accent applies identically to mouse-hover and keyboard/board-cursor focus.** No read is hover-only (matches the platform rule: every core action reachable by click and, where practical, a keyboard shortcut). The cost preview and target/range display are reachable by click/keyboard, not hover alone.
3. **AP-cost and damage numbers are exempt from value-dimming.** They stay at full brightness and full type weight, with snap timing, so the Non-Hue Semantic Layer's dimming/pattern vocabulary (used for disabled/invalid states) never dims the single most decision-critical number. Dimming applies to *affordances* (buttons, verbs), never to the *quantities* a player must read to decide.

## 8. Asset Standards

Authored jointly by art-direction (§8.1–8.6 standards) and technical-art (§8.7–8.9 engine/perf hard-constraints), reconciled. Engine: Redot 26.2 / Godot 4.6-compatible, Forward+, GDScript. Budgets (technical-preferences.md): 60 FPS / 16.6 ms, <500 draw calls.

### 8.1 File Formats

- **Source:** layered lossless working files (`.kra`/`.aseprite`/`.psd`), one per asset family (all iso facings of a unit as layer groups in one file), kept in a source-art location outside `assets/` proper.
- **Runtime: PNG, 8-bit + alpha, for every sprite** (units, structures, tiles, props, UI, VFX). Flat-neon-on-dark art is large flat color fields with hard edges — PNG's lossless compression handles this with no edge artifacting or palette banding, and it's the native Godot `Texture2D` path.
- **No JPEG anywhere** in the shipping set (ringing on hard edges, no alpha).
- **Atlases packed at import**, not by hand: one atlas per unit archetype set, one per terrain tile-variant kit, one shared UI atlas, VFX as grid flipbook sheets. (Packing mechanics/budgets → §8.7.)

### 8.2 Naming Convention

Extends the project `snake_case` file convention. Base pattern: `[category]_[identifier]_[variant]_[facing/frame].png`.

| Category | Pattern | Examples |
|---|---|---|
| Units | `unit_[archetype]_[faction]_[facing]_[state]_[frame].png` | `unit_scout_rush_s_idle_01.png`, `unit_sniper_boom_n_attack_03.png` |
| Structures | `struct_[name]_[faction]_[state].png` | `struct_hq_rush_complete.png`, `struct_econ-outpost_boom_construction.png` |
| Terrain | `tile_[terrain-type]_[variant].png` | `tile_plain_clean.png`, `tile_cover_cracked.png` |
| Props | `prop_[name]_[variant].png` | `prop_conduit-run_clean.png` |
| UI | `ui_[element]_[state].png` | `ui_icon_ap-pip_full.png`, `ui_frame_portrait_rush.png` |
| VFX | `vfx_[effect]_[loop-or-once]_[size].png` | `vfx_flare-decay_once_small.png` |

Faction tokens are `rush` / `boom` / `neutral`, matching `design/registry/entities.yaml` exactly. Structures need no facings (§3.2 — static, non-directional). Build-state tokens (`_construction`, `_complete`) to be confirmed against Base & Production's construction-stage vocabulary.

### 8.3 Resolution & Sprite-Size Tiers

**Author flat-vector-style art at high resolution and downscale — not committed pixel-art.** §1's identity is flat vector/cel shapes (not pixel-art's dither/grid contract); hi-res-then-downscale gives one source asset that serves both 1080p and 1440p cleanly, is cheaper to future-proof for a solo pipeline, and lets the §2 glow layer keep soft falloff. Author at **~2–3× effective display size** (final multiple set by atlas budget, §8.7).

| Category | On-screen | Author-at | Notes |
|---|---|---|---|
| Infantry | ~24–40px height (§5.1) | ~72–120px | Per-facing; canvas tall enough for Sniper's barrel overhang |
| Future vehicle/mech | Larger (§5.5), TBD | scale later | Do not pre-author |
| Structures | multi-tile, several × infantry | per footprint | HQ tallest — biggest per-sprite atlas item |
| Terrain tiles | fixed tile footprint | ~2–3× tile | All variants share dimensions (drop-in swaps) |
| UI icons | small (§7) | ~2–3× | Final size after §7 layout |
| VFX | tight/local (§2.2 forbids screen-wide) | ~2–3× extent | Keep canvases tight |

### 8.4 Isometric Production Standards

- **2:1 dimetric projection** (FFT-lineage genre standard; whole-pixel scaling avoids seam/aliasing). One fixed tile width:height ratio (2:1) for the whole project — every tile-variant shares exact footprint so §6.2's kit swaps are drop-in.
- **4 facings, not 8.** The grid is 4-directional-orthogonal (`grid_adjacency_mode`, entities.yaml) — 8 facings would author unused information, and §3/§5 silhouette reads are coarse-grained (aspect ratio + dominant-line direction). Facings named by iso screen-direction: `n`/`s`/`e`/`w`. **Where a unit/structure is left/right symmetric, `w` is an engine horizontal-flip of `e`** (cutting authored facings toward ~2–3 unique paintovers) — but §5.2's Mass Distribution Bias is direction-relative, not left/right-specific, so it survives a flip; confirm no asymmetric kit detail breaks mirror-safety before committing a sprite to flip.
- **Depth-sort by grid position, not scene order.** Every unit/structure/prop sprite is authored with its **pivot at the ground-contact point (bottom-center of footprint)**, not the bbox center — this is the hard authoring rule that makes automatic Y-sort stack correctly (§8.8). Cheap to enforce up front, expensive to retrofit.

### 8.5 Animation Frame Standards

State set is tied to §2's mood vocabulary and §5.4's mechanical register — not a generic action set:

| State | Notes |
|---|---|
| **Idle (AP-available)** | Loop; near-static pose — the *glow layer* breathes (§2.1), not the body. Low frame count is correct, not a shortcut. |
| **Idle (AP-spent/clamped)** | Same base pose frames, glow-clamp state only (§2.6) — do not author a second body pose unless playtest requires. |
| **Move** | Utilitarian directional lean (§5.4); most-seen animation, must survive repetition. |
| **Attack** | Snappy, synced to the §2.2 flare spike; weapon-ready, not a flourish. |
| **Hit** | Brief plating-absorbs-impact recoil. |
| **Destroyed** | **Short "power-down/collapse" beat, 2–4 frames** (LOCKED) — functional shutdown matching §5.4's restraint; no gibs/explosions, keeping loss dignified per the concept's no-shaming stance. |

Frame counts are low/functional (indicative: idle 1–4, move 4–6, attack 3–5, hit 2–3, destroyed 2–4) — validate one archetype by prototype before locking numbers.

**Glow-state layer is authored as an isolated emission mask, never baked into the base color art.** Per unit/facing/frame the art deliverable is **one base-color pass** (matte plating + faction-color/marker blocking per §4/§5.2) **+ one greyscale glow-mask pass** (which pixels are neon trim). This lets a shader drive breathe/flare/clamp as runtime parameters on the *same* asset instead of baking a glowing variant per state (which would multiply asset count by every §2 mood state). The glow-mask is a fast derive-from-base pass (isolate the already-painted trim), not a second full paintover. (Implementation → §8.9.)

### 8.6 Export Settings Philosophy

Crispness over softness at 1080p and 1440p: prefer minimal-blur/nearest-adjacent filtering for hard-edged content (soft-filtered flat color reads as muddy, not "hi-fi"). **No lossy compression on any 2D sprite** — see §8.9 for the import-preset consequence. The requirement is the *outcome* (crisp hard edges, no compression artifacting on flat color or the glow-mask channel); the exact import checkboxes are technical-art's to set (§8.9).

---

### 8.7 Draw-Call & Atlas Budget (technical)

Target < 500 draw calls; the 14×16 board itself lands at **~5–10** (one `TileMapLayer` per terrain layer batches to 1–3 calls; all infantry from one shared atlas + shared material batch to 2–4; structures 1–2). Draw calls are *not* the tight constraint at VS scope — **atlas/memory discipline is.**

**Hard rules:**
1. One atlas per asset class; no loose per-sprite textures for anything appearing >1× on the board.
2. **A unique `ShaderMaterial` resource per unit breaks 2D batching** — vary per-unit glow (hue, pulse phase, AP-state) via `instance_shader_parameters` on **one shared material**, not per-unit material resources.
3. Faction variants must not force a texture-swap batch break — keep them within shared atlas pages.
4. Atlas page ceiling **2048×2048**; 4096 is an escalation, not a default.

**Faction-art reconciliation (LOCKED — accept distinct-silhouette art):** §5.2 makes faction identity a *silhouette* difference (Mass Distribution Bias: Rush forward-light / Boom rear-loaded / Neutral even), so faction units are **distinct art, not palette-swaps of one base** — 3 faction silhouettes × 4 roles. Unit art is therefore ~**3×** a single-faction estimate and spans a few atlas pages rather than one. This is accepted as the cost of the strongest Pillar-4 visual expression; it stays comfortably under the draw-call budget (all faction variants share one shader/material via per-instance uniforms), and Lossless VRAM footprint at single-digit 2048² page counts is trivial on any modern GPU. The shader still applies each faction's single hue + drives glow-state; it does not collapse the silhouettes. *(If art scope later needs cutting, the fallback is §5's rejected option — shared silhouette + a small per-faction emblem marker — which would require a §5 edit.)*

### 8.8 Iso Depth-Sort (technical)

Use Godot 4's `y_sort_enabled` on a shared parent `Node2D` holding all board occupants (units, structures, tall props) — auto-sorts draw order by global Y, the correct iso depth cue. The static `TileMapLayer` floor sits *outside* the Y-sort group. Any tile art with vertical overhang tall enough to occlude a unit on an adjacent row must be pulled out as a Y-sorted prop (confirm with art whether any Cover/Impassable tile has such overhang). This is what imposes §8.4's **ground-contact-pivot** authoring rule — the pivot *is* the sort key.

### 8.9 Glow Shader & Import (technical)

**Recommended: one CanvasItem `.gdshader` (`shader_type canvas_item`) on the unit sprite**, sampling base color normally and additively blending `emission_mask × faction_hue × pulse_intensity`, where `faction_hue` and `pulse_intensity` are **per-instance uniforms** (`set_instance_shader_parameter`) so all units share one material (batch-safe, §8.7 rule 2). Drive `pulse_intensity` from GDScript on state change (event-driven, not per-frame polling): breathe = slow sine, flare = decaying value on AP-spend, clamp = fixed override at 0 AP. **Pass an explicit `state_timer` uniform from GDScript rather than the shader `TIME` built-in**, so glow can freeze/scrub with the turn-based pause state.

**Import:** Lossless for all gameplay sprites (flat neon bands/blocks under VRAM/BC compression — worst-case content for it; and memory is a non-issue at this scope). Mipmaps likely off (fixed iso camera; mip-blur would soften hard edges). Screen-space AA (SMAA/FXAA) handles edges.

**⚠️ Engine-verify before this becomes load-bearing (post-4.3 cutoff):** confirm in the live Redot 26.2 / Godot 4.6 editor that (a) `set_instance_shader_parameter` / per-instance uniforms behave as expected in 2D, and (b) the 4.6 **glow-pipeline rework** (per `docs/engine-reference/godot/modules/rendering.md`) is understood — note that rework is the *3D/WorldEnvironment* post-process glow and does **not** affect the hand-authored 2D CanvasItem-shader emission approach above; but if the team also wants a soft `WorldEnvironment` 2D bloom halo on top, that 4.6 change *does* apply and should be spiked/screenshotted first. Run a one-unit glow spike to validate before committing the pipeline.

**→ RESOLVED 2026-07-29 (S4-01 de-risk spike — approach CONFIRMED, safe to commit).** (a) The Redot 26.2 engine reference (`docs/engine-reference/godot/modules/rendering.md`) confirms the 4.6 glow rework is the **WorldEnvironment/Compositor 3D post-process** path (glow now processes *before* tonemapping, screen-blend) — it does **not** touch the hand-authored 2D CanvasItem emission shader above. (b) A headless smoke on Redot 26.2 confirmed two `Sprite2D` (CanvasItem) nodes **sharing one `ShaderMaterial`** hold divergent per-instance `faction_hue` / `pulse_intensity` via `set_instance_shader_parameter` — the batch-safe §8.7-rule-2 pattern works in 2D. **Residual (windowed, advisory → S4-07):** render the one-unit spike (`prototypes/s4-01-art-spike/GlowSpike.tscn`) in the live rasterizer to confirm the `instance uniform` declaration compiles + the additive emission reads correctly (the dummy headless rasterizer can't render). And per the ⚠️ above, a *WorldEnvironment 2D bloom halo* — if ever layered on top — **is** governed by the 4.6 rework and must be spiked separately.

## 9. Reference Direction

Seven external references, each isolated to a single extractable technique — a tool pointed at a locked principle, with an explicit divergence so the borrowed element doesn't drag its source's full aesthetic in behind it.

### 9.1 Advance Wars (2 / GBA-era)
- **TAKE** — Chunky, oversized-readable unit proportions and pose-based silhouette punch: role and facing read at a glance at small scale. Direct proportional ancestor of the Trooper baseline (§5.1) and silhouette-first (§1 P1).
- **AVOID** — Its saturated, cheerful, fully-lit cartoon palette. Our stage is dark-neutral and value-recessive (§2.1); nothing sits at Advance Wars' brightness. Take the chunk, leave the sunshine.
- **Serves** — §5.1 infantry proportions, §1 P1 silhouette-first.

### 9.2 TRON / Synthwave
- **TAKE** — The optical behavior of neon-on-dark: light as information — thin emissive linework that glows/breathes/reads as active against a receding dark field. Source of neon-actors/dark-stage (§1) and the glow vocabulary (§2).
- **AVOID** — TRON's total-environment neon saturation (every surface lit like a circuit board). Neon is a rationed signal, not an environment style (§4.6 neon budget). Take the glow *language*, not the glow *coverage*.
- **Serves** — §1 dark stage/neon actors, §2 "neon means this matters."

### 9.3 Final Fantasy Tactics
- **TAKE** — The isometric 2D projection lineage: staging readable height, facing, and depth on a diagonal grid without breaking silhouette clarity. Precedent for iso-proofed shape (§1 P1) and elevation lifting a tile (§6.3).
- **AVOID** — FFT's painterly, high-detail, hand-shaded rendering (soft gradients, dithered shading, ornate costuming). We are flat and neon-lit, not painted (§6.2). Take the projection and elevation logic, not the brushwork.
- **Serves** — §1 P1 iso-proofed silhouette, §6.3 elevation lifts the floor.

### 9.4 StarCraft / StarCraft 2
- **TAKE** — Faction identity legible across an entire roster through shape/material family, independent of any single unit. Working precedent for Mass Distribution Bias (§5.2): Rush forward-light across every unit, Boom rear-loaded across every unit.
- **AVOID** — StarCraft leans on *hue* as the primary faction signal. Our hue is closed to Rush/Boom/Neutral across all factions (§4.1); ownership must be legible beyond hue (§1 P2, §5.2). Take the family-silhouette discipline, not the hue-shortcut.
- **Serves** — §5.2 Mass Distribution Bias, §1 P2 ownership beyond hue.

### 9.5 XCOM
- **TAKE** — Tactical-grid tension via terrain that visibly interrupts sightlines and movement — cover read at a glance as "this breaks the floor," creating stakes before a die is rolled. Source for cover-breaks-the-floor (§6.3) and unit/terrain contrast (§1/§6.1).
- **AVOID** — XCOM's muted, desaturated grim-military palette and heavy AO/PBR realism. Our terrain is flat/painted, no PBR (§6.2); our darkness is a neon-stage backdrop, not grimdark realism. Take the cover-tension read, not the realism.
- **Serves** — §6.3 cover/elevation grammar, §1 grid readability.

### 9.6 Command & Conquer
- **TAKE** — Bold, unambiguous faction-hue application at the *structure/base* scale — a base-plate reads as "whose" from across the map in one glance. Informs the structure base-plate grammar (§3.2) and validates saturated faction hue at macro scale.
- **AVOID** — C&C's fully-lit, cluttered base sprawls with dense competing surface detail. We keep props sparse and value-recessive (§6.4) so faction plating stays the visual event. Take the base-plate hue confidence, not the density.
- **Serves** — §3.2 structure base-plate grammar, §6.4 sparse props.

### 9.7 Front Mission
- **TAKE** — Grounded military-industrial mech tone: plating, joints, and hardpoints read as functional hardware with mass, not decorative filigree. Touchstone for the future vehicle/mech tier (§5.0/§5.5) — bigger silhouettes, same Mass Distribution Bias, scaled-up neon budget.
- **AVOID** — Front Mission's gritty, desaturated, war-worn palette (mud, rust, matte attrition). Our damage runs through value shifts and architectural typology, never added hue or grime (§6.5). Take the mechanical seriousness, not the palette or the grime.
- **Serves** — §5.5 vehicle/mech tier, §6.5 damage via value/typology.

### 9.8 How These Combine Without Becoming a Pastiche

Each reference is fenced to one layer of the pipeline: Advance Wars owns *proportion*, TRON owns *light behavior*, FFT owns *projection/elevation*, StarCraft owns *faction-family silhouette logic*, XCOM owns *cover/terrain tension*, C&C owns *macro-scale hue confidence*, Front Mission owns *mechanical seriousness at the future scale*. No two were selected for the same job, and each is cut off from its own default palette/rendering — because OVERCLOCK's palette (§4), rendering (flat-neon, no PBR, §6), and semantic system (Non-Hue layer, §1 P2/§4.3) belong to none of them individually. **The result must read as OVERCLOCK first: if any single reference is recognizable in the final art without prompting, that reference's AVOID clause has been violated and needs correction back to the locked principle it was meant to serve.**
