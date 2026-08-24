# Story 006: Entity Sprite Renderer & Live `GameState.entities()` → Board Feed

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (2 days)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-19 (implemented)

## Context

**GDD**: `design/assets/specs/vs-entities-assets.md` (asset contract) · `design/gdd/grid-terrain.md`
**Requirement**: closes scope §8 build-seam c (live entities feed); sprint story **S5-01**
**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays
**ADR Decision Summary**: Floor and Overlay are `TileMapLayer`s outside the Y-sort group;
occupants live on `OccupantLayer` with native `y_sort_enabled`; sprite pivots are authored at the
ground-contact point so `grid_to_screen(tile)` doubles as the placement anchor with no extra offset.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM

Replaces the placeholder diamonds baked by `_build_diamond_texture` with the real art, which landed
2026-08-19 (62 runtime PNGs in `assets/art/`, all with import sidecars).

> **Read `assets/art/README.md` before implementing.** It is the load contract and it carries three
> things that will silently break this story if missed — 2× textures, the facing map, and cover's
> two-layer composition.

## Acceptance Criteria

1. One sprite node per live entity on `OccupantLayer`, fed from `GameState.entities()`; removing an
   entity frees its node (no orphans).
2. Textures resolve by the §8.2 convention: `unit_[archetype]_[faction]_[facing]_idle_01.png` and
   `struct_[name]_[faction]_idle.png`.
3. **Facing map** — only `e` and `w` are authored: `n→e`, `e→e`, `s→w`, `w→w`, picked by the sign of
   screen-x travel.
4. Depth order comes from native `y_sort_enabled` on the ground-contact row. Children of
   `OccupantLayer` must **not** set a `z_index` that fights the Y-sort.
5. Floor and Overlay layers remain **outside** the Y-sort group (regression: `scene_structure_test`).
6. **Cover renders as TWO nodes** — a floor cell on `FloorTileMapLayer` plus a separate Y-sorted
   prop. "One PNG = one TileMapLayer cell" **breaks** for cover.
7. **2× textures**: `FloorTileMapLayer.tile_set.tile_size == Vector2i(256, 128)` with the layer
   scaled `0.5`. `TILE_WIDTH_PX`/`TILE_HEIGHT_PX` (128×64) remain the **on-screen** cell size and
   are unchanged.
8. `grid_to_screen` / `screen_to_grid` round-trip is unaffected by the tile_size change
   (regression: `transform_round_trip_test`).
9. A sprite's **bottom-centre** lands exactly on `grid_to_screen(tile)` with no extra offset.
10. A destroyed entity swaps to its `destroyed_01` / `_destroyed` texture.
11. Boot + integration tests green; full suite still 860/860 or better.

## Implementation Notes

- Faction pins Rush/Boom already landed as a precondition — ownership reads by hue.
- Sprites are **trimmed to their opaque bounds**, so sizes differ per asset. Anchor per-texture;
  do not assume a common frame.
- Textures ship at 2× on-screen size (§8.3, so one asset serves 1080p and 1440p). Scale down at
  draw time; do not blit 1:1.
- `assets/art/` is **generated** by `tools/asset-pipeline/place_runtime.py`. Never hand-edit it —
  edit the master in `art-source/` and re-run, or the change is lost.

## Out of Scope

- Glow / emission (→ **S5-02**), and move/attack/hit transforms (→ **S5-06**).
- Structure `damaged` tier art (→ S5-10) — only `idle` and `destroyed` exist today.
- Multi-frame animation: **only frame `01` exists** for every state.

## QA Test Cases

**Test file**: `tests/integration/board-renderer/entity_sprite_feed_test.gd`

- one sprite node per entity; entity removed → node freed, no orphan
- texture path resolves by naming convention for units and structures
- facing map: `n→e`, `e→e`, `s→w`, `w→w`
- Y-sort: two occupants on adjacent rows draw in ground-contact-row order
- no child of `OccupantLayer` sets a conflicting `z_index`
- Floor/Overlay remain outside the Y-sort group
- cover paints a floor cell **and** a distinct Y-sorted prop node
- `tile_set.tile_size == (256,128)` and layer scale `0.5`; on-screen cell still 128×64
- `grid_to_screen` round-trip unchanged (regression)
- sprite bottom-centre == `grid_to_screen(tile)`, no offset
- destroyed entity swaps texture

**Edge cases**: zero entities (no crash) · entities at (0,0) and (max,max) · neutral faction
resolves `neutral` textures · **missing texture errors explicitly, never renders blank**

## Test Evidence

**Automated** — `tests/integration/board-renderer/entity_sprite_feed_test.gd`, 29 tests, all
passing. Full suite **888/888, 0 failures, 0 orphans** (was 860 before this story; +28 net).

**Windowed visual confirmation** (the headless dummy rasteriser cannot render):
- Board boots clean, zero errors in the log; floor renders as a correct 12×10 iso diamond with both
  HQs registered on it.
- Rush HQ (orange) and Boom HQ (cyan) resolve their faction hues correctly.
- A produced Scout renders in Rush orange at correct ground contact and Y-sorts **in front of** the
  HQ from a nearer row. AP 10→9 and Credits 10→8 on the same commit — the dual cost reads correctly
  alongside the new art.

Screenshots are not yet filed as formal evidence docs — that is S5-07's advisory sign-off pass.

## Dependencies

- **Blocks**: S5-02 (glow wiring), S5-03 (iso-legibility gate), S5-06, S5-07
- **Blocked by**: none — S4-02 art is complete

## Completion Notes

**All 11 acceptance criteria met**, with two findings recorded rather than absorbed.

### Shipped
- `src/ui/board_renderer/entity_sprite_catalog.gd` — pure §8.2 path resolver (faction/type/facing/
  state tokens). Faction is compared **by reference** against the `Factions` registry because
  `FactionDef` is still ADR-0012's stub and carries no id field.
- `src/ui/board_renderer/entity_sprite_feed.gd` — the live feed. Owns one `Sprite2D` per entity,
  reconciles against each snapshot, tracks facing (presentation-only state with no home in
  `EntityState`), and authors pick regions from real sprite bounds.
- `board_renderer.gd` — 2× tile sizing, real terrain painting (floor cells + Y-sorted Cover props),
  `cell_for()`; Story 002's placeholder fixtures deleted.
- `vertical_slice_root.gd` — placeholder `_draw` marker diamonds deleted; wired to the feed.
- `project.godot` — clear colour set to the void anchor `#0A0E17`, since Impassable tiles are
  deliberately left unpainted and the background IS the void art.

### Finding 1 — engine iso cells are not grid tiles (fixed, ADR amended)
`set_cell(tile)` drew the board **up to 1408px** away from the sprites: Redot's isometric cell
layout uses a different basis than the hand-rolled dimetric transform. This was latent since Story
003 — it hit the overlay layer too, and that layer's alignment evidence doc was owed and never
filed. Fixed with `BoardRenderer.cell_for()`; ADR-0013 carries an amendment and the control
manifest has three new rules. Regression cover asserts all 120 tiles at 0.0px error.

### Finding 2 — AC-10 is only half-real until S5-06
`GameState.destroy_entity()` erases the entity in the same frame its hp hits zero, so a destroyed
entity never reaches a feed snapshot. The resolver returns the correct `destroyed_01`/`_destroyed`
path (AC-10 met at the resolver level and tested), but **nothing puts destroyed art on screen**
until S5-06 adds the death-echo hold for §8.5's 2–4 frame beat. S5-06 is therefore load-bearing for
AC-10, not the polish item the sprint plan treats it as.

### Also closed
The ADR-0013 §4 occupant-clickable-region authoring gap (vertical-slice build-seam S3-05) — regions
now come from real sprite bounds **merged with the tile footprint**. The merge is required: a sprite
is anchored at its ground-contact point so its rect sits entirely above it, and `Rect2.has_point`
excludes the bottom edge, which would have made a unit's own tile unclickable.

### Known gaps (not defects)
- **Art exists for only 5 of 9 entity types.** Sniper, Defensive Structure, Economy Outpost and
  Research Lab have none; any reaching the board gets a `push_error` plus a loud magenta placeholder
  rather than a silent blank.
- **New-unit default facing is `e`**, an arbitrary pick — a unit produced onto the board has no
  travel to take a sign from. Whether a fresh unit should face the opponent instead is a feel call
  for S5-03, not a correctness one.
