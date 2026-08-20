# Story 006: Entity Sprite Renderer & Live `GameState.entities()` → Board Feed

> **Epic**: Board Renderer
> **Status**: Not Started
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (2 days)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-19

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

*(to be filled by /story-done — integration test result + smoke check)*

## Dependencies

- **Blocks**: S5-02 (glow wiring), S5-03 (iso-legibility gate), S5-06, S5-07
- **Blocked by**: none — S4-02 art is complete

## Completion Notes

*(to be filled on completion)*
