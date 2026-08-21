# Story 009: Faction Ownership Marker — the Non-Hue Channel, On the Tile

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel *(secondary: Logic — the shape geometry and the decal lifecycle are both automatable and are covered as blocking gates)*
> **Estimate**: M (0.75 day)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-20 (implemented)

## Context

**GDD**: `design/art/art-bible.md` §1 P2 (ownership legible beyond hue), §5.2 (Mass Distribution
Bias), §5.3 (ally/enemy/neutral at a glance), §4.6 (neon budget), §3.5 (visual hierarchy)
**Requirement**: sprint story **S5-08**, resolved as **option D3** (user decision, 2026-08-20)
**ADR Governing Implementation**: **ADR-0013, amended by this story** — a fourth render layer
**Evidence**: `production/qa/evidence/s5-08-colourblind-ownership-brief.md`

**Engine**: Redot 26.2 | **Risk**: LOW — one flat `Node2D` layer and procedurally drawn textures.

## Why this story exists

S5-08 was planned as a yes/no decision: build §5.2-style non-hue markers, or accept hue-only
ownership with a recorded rationale. Measuring the shipped art first turned up three things that
changed the question.

1. **The sprint's framing was inverted.** It carried "Δ34/255 — readable on structures, marginal on
   units". Δ34 is the *peak* on the brightest trim pixels. Units are in fact the strong case
   (26–82% accent coverage, ΔE 60–76 deuteranopia); **structures are the weak case** (5–22%).
2. **There was an ownership defect, not an accessibility one.** The Defensive Structure measures
   **ΔE 2.3 across its whole silhouette with entirely normal colour vision** — Rush and Boom look
   near-identical to *every* player. The runtime glow does not rescue it (ΔE 1.9 → 2.8 at peak
   breathe; the masks are 3.5% of the sprite).
3. **The declared non-hue backup did not exist.** All **26** Rush/Boom sprite pairs are
   pixel-identical in silhouette — faction variants are recolours of one master per entity, so
   §5.2's Mass Distribution Bias could never have differed. Three documents asserted otherwise.

The first attempt at a fix (option D as originally specified — "widen the recolour masks") turned
out not to be buildable: `recolor.py` finds the accent by **hue-gating the Rush master**, there are
no per-entity masks, and structure plating is 74–94% *cool*-hued, so relaxing the gate adds
0.2–1.0%. There simply is no more orange in those sprites. That is what led to D3.

## Acceptance Criteria

1. **Ownership reads with all colour discarded.** The three factions' decals differ as *geometry*,
   not only as hue.
2. **Rush and Boom are inverses** across the visible arc — whichever end one owns, the other does
   not. Neutral is even (the absence of a bias, §4.2's stated intent).
3. **Hue comes from the locked anchors** via `EntityGlow.hue_for` — one palette, never a second.
4. **The decal belongs to the tile**, not the body: it does not lean, lunge or recoil with the
   §8.5 motion transforms, and it is positioned at the tile centre.
5. **Draw order**: above the overlay (ownership stays legible through a range highlight), below the
   occupants (an actor standing on the tile occludes its own decal).
6. **No decal sets a `z_index`** — the layer carries the band (ADR-0013 §2).
7. **Adjacent decals never touch**, so a run of owned tiles cannot fuse into a line that reads as
   terrain.
8. **Scope is a knob**, not a hardcode — `ALL` / `STRUCTURES_ONLY` / `NONE`.
   Default: **`STRUCTURES_ONLY`** (decided 2026-08-21, see Completion Notes).

## Implementation Notes

- **A layer, not a child sprite.** Two independent reasons, both in the ADR amendment: a child
  inherits Story 008's motion transforms, so the decal would lean and lunge with its entity; and a
  child must draw *under* its parent, which needs a child `z_index` that ADR-0013 forbids.
  `MarkerLayer` takes `z_index 2` and pushes `OccupantLayer` to 3.
- **Not Y-sorted.** Flat decals at tile centres cannot meaningfully occlude one another. The band
  alone gives the only depth relationship that exists here.
- **Geometry reuses the renderer's own diamond metric** (`d = |dx|/half_w + |dy|/half_h`), so the
  decal is guaranteed to sit on the tile the renderer thinks it does rather than on a second,
  independently-derived diamond. Verified against the real floor art.
- **Three textures for the whole board**, built once and cached. Procedural, because the shapes are
  flat geometric primitives a generator would only make less exact.
- The decal **fades with the death echo** — a dead entity owns no tile, and a marker left at full
  strength under a fading corpse would read as "something is still standing here".

## Recorded deviation from §5.2

§5.2 frames the bias as forward-light / rear-loaded / neutral-even. **A ground decal cannot use the
rear of the tile**: the entity stands at the tile centre and its body occludes the whole far half.
The bias is therefore expressed within the visible near half — front-concentrated (Rush) vs
flank-split (Boom) vs even (Neutral) — which keeps the asymmetry-of-mass principle while staying
visible under a fixed iso camera. The test that matters is unchanged and is enforced: the three
read apart with hue removed.

This satisfies P2 **as a channel**. It does not build the *silhouette* form of Mass Distribution
Bias, which stays Full Vision work; the sprites are still pixel-identical between factions.

## Out of Scope

- Per-faction **body** silhouettes (Full Vision — see §5.2's implementation-status note).
- Raising structure accent coverage in the art itself. D3 makes it unnecessary at VS scope; if a
  later art pass wants it anyway, it is independent of this layer.
- Any change to the locked hue anchors.

## QA Test Cases

**Test files**:
- `tests/unit/board-renderer/ownership_marker_test.gd` — Logic, **blocking**
- `tests/integration/board-renderer/ownership_marker_feed_test.gd` — Integration, **blocking**

Covered: the three shapes genuinely differ by alpha coverage and in the specific way each faction's
bias describes · Rush's mass is at the near vertex, Boom's has a gap there, and they are inverses ·
Neutral is even · hue equals the locked anchor · the band stays inside the tile · textures are
cached · one decal per entity carrying its **owner's** texture · placed at the tile centre and
follows a move · a sibling in `MarkerLayer`, never a child of the body · no decal sets a `z_index` ·
layer order overlay < marker < occupant · all three policy values · decals freed with their entity.

*Not automatable: whether the decals read at playing distance and whether a full board of them is
too busy. That is S5-03 / S5-07.*

## Test Evidence

**Automated** — 18 new tests, all passing. Full suite **954/954, 0 failures, 0 orphans** (was 936).
The default-policy test asserts the shipped value *without setting it*, so a silent change to the
default fails the suite rather than quietly altering the board.
Slice boots clean, exit 0.

**Rendered** — the three markers were exported from the live `OwnershipMarker` code and composited
over the real floor and entity art. Grayscale row confirms AC-1 by eye: chevron vs split-flanks vs
even ring, unmistakable with zero colour information. Alignment against the real
`tile_plain_clean.png` diamond grid is exact and adjacent markers do not touch.

**Windowed** — owed under S5-07, like every other Visual/Feel item this sprint.

## Dependencies

- **Blocked by**: S5-01 (sprites), S5-06 (the death-echo hook the decal fades on)
- **Blocks**: nothing. Feeds S5-03 and S5-07.

## Completion Notes

**All 8 acceptance criteria met**, with the "does it read at playing distance" half owed to S5-07.

### Shipped
- `src/ui/board_renderer/ownership_marker.gd` — the shapes, the numbers, the three cached textures.
- `src/ui/board_renderer/board_renderer.gd` — `MarkerLayer` + the re-banded z-indices.
- `src/ui/board_renderer/entity_sprite_feed.gd` — one decal per entity, the policy knob, and the
  death-echo fade.
- `docs/architecture/adr-0013-isometric-board-rendering.md` — amended for the fourth layer.
- Art bible §5.2/§5.3/§8.7 and `accessibility-requirements.md` — corrected, then updated again once
  the channel existed.

### ✅ Policy decided 2026-08-21 — `STRUCTURES_ONLY`
Shipped initially as `ALL` with the scope left open. The user settled it off the render sheet
(`production/qa/evidence/s5-08-marker-render/marker-policy-all-vs-structures-only.png`): six
entities on a small patch was enough to show that under `ALL` the decals sit directly beneath the
units' own feet and compete with them, which §3.5 forbids — and units were never the problem, at
26–82% accent coverage and ΔE 60–76 deuteranopia on their own. `STRUCTURES_ONLY` puts the decal
exactly where the measurement found the weakness and leaves the rest of the board clean.

**Accepted consequence, recorded:** under this policy a unit-only read is hue-carried and does not
survive full desaturation. §1 P2's non-hue channel exists on the board — on the structures that
anchor every position, and on the Neutral mirror's own anchors — but not under every actor on it.
`ALL` restores it board-wide and is one assignment away if a monochromacy claim is ever made in
earnest.

AC-8 (scope is a knob, not a hardcode) is what made this a one-line decision rather than a rework.
