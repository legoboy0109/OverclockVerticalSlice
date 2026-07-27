# Epic: Board Renderer

> **Layer**: Presentation
> **GDD**: (ADR-driven — no dedicated GDD; producer-side requirement is TR-grid-008 in design/gdd/grid-terrain.md)
> **Architecture Module**: Board Renderer (Presentation Layer)
> **Status**: Ready
> **Stories**: 5 stories (see `## Stories` below) — none implemented yet

## Overview

The Board Renderer is the Presentation-layer node that turns the logical
`GridState` into a visible, clickable 2:1 isometric (dimetric) board — and the
one place the grid→screen projection lives. It owns the `grid_to_screen` /
`screen_to_grid` transform, a custom inverse hit-test (`pick_at`) that avoids
Godot's buggy `local_to_map()` on isometric tiles (GH#89423), native Y-sort depth
ordering so tall sprites occlude correctly, an `OverlayTileMapLayer` with
`set_overlay()`/`clear_overlay()` for tile highlights, and the
`grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]` anchor convention every
on-board glyph uses. It never mutates `GridState` — it reads the grid's
side-effect-free query API and renders. It is a foundational Presentation
dependency: the Command & Action Interface consumes `pick_at`/`set_overlay` for
input routing and previews, and the Game HUD consumes `grid_to_screen` +
`GLYPH_OFFSETS` for its on-board glyph layer. Nothing in the interaction surface
of the Vertical Slice can be built without it.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0013: Isometric Board Rendering, Picking & Overlays | `grid_to_screen`/`screen_to_grid` 2:1 dimetric transform; custom inverse `pick_at()` (occupant-priority-then-diamond-fallback); native `y_sort_enabled` depth-sort; `OverlayTileMapLayer` + `set_overlay()`/`clear_overlay()`; `grid_to_screen(tile) + GLYPH_OFFSETS[]` glyph anchoring — all in `BoardRenderer`, never touching `GridState`'s logical fields | HIGH — pre-Accept engine spike **PASS 2026-07-25** (diamond tiling seamless, `y_sort_enabled` draw-order correct; `TileSet.TILE_SHAPE_ISOMETRIC` confirmed) |
| ADR-0005: Grid representation & map-definition | Reads the completed `GridState` read API (`terrain`, `occupancy`, `width`/`height`, `index(x,y)`) — the data this epic projects to screen | LOW (shared, Complete) |

## GDD Requirements

TR-grid-008 is this epic's primary (producer-side) requirement. This epic also
**delivers the mechanism** behind the ADR-0013 consumer TRs owned by the Command
& Action Interface and Game HUD epics (TR-cmdui-003/004/016/017, TR-hud-010/011)
— those stay owned by their consumer epics for the *usage*; this epic builds the
node they call. Full requirement text in `docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0013 (render-side projection layer) | TR-grid-008 (primary) | ✅ |
| ADR-0013 (mechanism consumed by CAI) | TR-cmdui-003, -004, -016, -017 *(owned by CAI epic; delivered here)* | ✅ |
| ADR-0013 (mechanism consumed by HUD) | TR-hud-010, -011 *(owned by HUD epic; delivered here)* | ✅ |

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- The `BoardRenderer` node exposes `grid_to_screen`/`screen_to_grid`/`pick_at`/`set_overlay`/`clear_overlay` and the `GLYPH_OFFSETS` anchor convention as its stable public API
- All Logic and Integration stories have passing test files in `tests/` (round-trip `grid_to_screen`∘`screen_to_grid` identity on every in-bounds tile; `pick_at` occupant-priority resolution; overlay tile alignment)
- All Visual/Feel stories have evidence docs with sign-off in `production/qa/evidence/` (seamless diamond tiling, correct Y-sort occlusion at 1080p/1440p)
- TR-grid-008 is satisfied end-to-end: the render-side projection layer reads `GridState` and never mutates it, and uses no engine `local_to_map()` on iso tiles

## Dependencies & Sequencing

- **Depends on (Complete):** grid-terrain (Foundation) — provides the `GridState` read API this epic projects. TR-grid-008 was explicitly deferred out of the grid-terrain epic as a Presentation concern ("implemented by the Board Renderer epic").
- **Unlocks (VS-critical):** Command & Action Interface **Story 006** (iso picking & overlay integration) is BLOCKED on this epic's `BoardRenderer` node; the Game HUD on-board glyph layer (TR-hud-010/011) likewise consumes `grid_to_screen` + `GLYPH_OFFSETS`. This epic is the root of the VS interaction surface — sequence it **first** among the Presentation epics.
- **Engine note:** ADR-0013's HIGH risk is retired by the 2026-07-25 spike PASS; residual work is confirming `TileSet.TILE_SHAPE_ISOMETRIC` / `Node2D.y_sort_enabled` in the live 4.6 editor (a godot-specialist pass, not a training-data gap).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Grid↔Screen Transform Pair — `grid_to_screen`/`screen_to_grid` | Logic | Ready | ADR-0013 |
| 002 | Y-Sort Depth Ordering & Scene-Tree Skeleton | Visual/Feel | Ready | ADR-0013 |
| 003 | Overlay TileMapLayer — `set_overlay()`/`clear_overlay()` | Integration | Ready | ADR-0013 |
| 004 | Occupant-Priority Picking — `pick_at()`/`PickResult` | Logic | Ready | ADR-0013 |
| 005 | On-Board Glyph Anchoring — `GLYPH_OFFSETS` | Logic | Ready | ADR-0013 |

**Implementation order**: 001 → 002, then {003, 004} in parallel, 005 anytime after
001. Critical path to unblock CAI Story 006: **001 → 002 → 004** (picking) alongside
003 (overlays); 005 unblocks the HUD glyph layer.

> **⚠ Open ownership gap (Story 004)**: ADR-0013 flags that *occupant clickable-region
> authoring* (the per-sprite `Rect2`/mask `pick_at` tests) has no owning epic — likely
> CAI or a unit/structure-scene-authoring story. Story 004 mocks it for unit tests, but
> real end-to-end picking needs an upstream owner. Also unowned: the live
> `GameState.entities()` → `BoardRenderer` feed (Story 002 stubs occupants).

## Next Step

Run `/story-readiness production/epics/board-renderer/story-001-grid-screen-transform-pair.md`,
then `/dev-story` to begin. Build this epic before (or alongside the early stories of)
the Command & Action Interface and Game HUD epics.
