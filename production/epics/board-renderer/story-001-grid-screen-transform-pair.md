# Story 001: Grid↔Screen Transform Pair — `grid_to_screen` / `screen_to_grid`

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S (2–3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: (ADR-driven — no dedicated GDD; producer-side requirement is `TR-grid-008` in `design/gdd/grid-terrain.md`)
**Requirement**: `TR-grid-008` (owned, transform half); delivers `TR-cmdui-003` (exact inverse consumed by CAI)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays (§1, primary)
**ADR Decision Summary**: The grid→screen projection is one shared, hand-rolled, closed-form linear transform pair (2:1 dimetric shear+scale) with an exact algebraic inverse — never engine `local_to_map`/`map_to_local` (GH#89423 iso bug).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure closed-form arithmetic — no engine API surface (no `TileMapLayer`, no `local_to_map`). Boundary tie-break and tile-dimension independence already numerically verified (godot-specialist, 2026-07-24). No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `grid_to_screen(tile)`/`screen_to_grid(px)` must be one shared hand-rolled exact closed-form linear transform pair (2:1 dimetric shear+scale), never engine `local_to_map`/`map_to_local` — source: ADR-0013
- Required: The forward/inverse transforms must be exact mathematical inverses, verified by round-trip identity — source: ADR-0013
- Required: `screen_to_grid` must use `floori()` on the exact algebraic inverse so boundary ties resolve deterministically toward the lower-index tile — source: ADR-0013

---

## Acceptance Criteria

*From ADR-0013 §1 Validation Criteria + TR-grid-008, scoped to this story:*

- [ ] GIVEN every tile `t` in `[0, GRID_WIDTH) × [0, GRID_HEIGHT)` on a 14×16 board, WHEN `screen_to_grid(grid_to_screen(t))` is computed, THEN the result equals `t` exactly for all 224 tiles (round-trip identity)
- [ ] GIVEN a screen point exactly on a shared diamond edge/vertex (e.g. equidistant between tiles `(0,0)/(1,0)/(0,1)/(1,1)`), WHEN `screen_to_grid` resolves it, THEN it deterministically returns the same tile on every call (no NaN, no alternating result) — the tie always breaks toward the lower-index tile via `floori()`
- [ ] GIVEN two tile-dimension configurations (a power-of-two pair e.g. 128×64, and a non-power-of-two pair e.g. 127×63), WHEN the round-trip test runs against each, THEN both pass identically — exactness is independent of `TILE_WIDTH_PX`/`TILE_HEIGHT_PX`
- [ ] GIVEN `origin_offset_px` set to a non-zero `Vector2`, WHEN the transforms are exercised, THEN the round-trip identity still holds (offset applied/removed symmetrically)

---

## Implementation Notes

*Derived from ADR-0013 §1 (transcribed):*

- Create `BoardRenderer` (`class_name BoardRenderer extends Node2D`) as `board_renderer.gd` — this story adds only the transform pair and the consts/export; later stories extend the same file/scene.
- Constants exactly as §1: `const TILE_WIDTH_PX: float = 128.0`, `const TILE_HEIGHT_PX: float = 64.0`, `@export var origin_offset_px: Vector2 = Vector2.ZERO`. (Exact pixel values are technical-art's eventual call — 128/64 is a placeholder satisfying the 2:1 ratio, not art-locked.)
- `grid_to_screen(tile: Vector2i) -> Vector2`: `origin_offset_px + Vector2((tile.x - tile.y) * TILE_WIDTH_PX * 0.5, (tile.x + tile.y) * TILE_HEIGHT_PX * 0.5)`.
- `screen_to_grid(px: Vector2) -> Vector2i`: subtract `origin_offset_px`, then `u = local.x/TILE_WIDTH_PX + local.y/TILE_HEIGHT_PX`, `v = local.y/TILE_HEIGHT_PX - local.x/TILE_WIDTH_PX`, return `Vector2i(floori(u), floori(v))`.
- Never call `TileMapLayer.local_to_map()`/`map_to_local()` for this math (GH#89423 — confirmed bug).
- `grid_to_screen(tile)` is *also* the sprite placement anchor convention (`sprite.position = grid_to_screen(tile)`) — note it in a doc comment; Story 002 depends on that exact contract.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `TileMapLayer` nodes / scene-tree structure — Story 002/003
- `pick_at` — Story 004
- glyph offsets — Story 005
- Any `GridState` reads — this story is pure math on `Vector2i`/`Vector2`

---

## QA Test Cases

- **AC (round-trip)**: Given every in-bounds tile on a 14×16 board, When round-tripped through `grid_to_screen`→`screen_to_grid`, Then output == input for all 224 tiles. Edge cases: all four corners `(0,0)`, `(13,0)`, `(0,15)`, `(13,15)`; center tile.
- **AC (boundary determinism)**: Given a screen point exactly on the shared boundary of 4 tiles, When `screen_to_grid` is called 100 times, Then it returns the identical tile every call (no float jitter).
- **AC (dimension independence)**: Given non-power-of-two tile dimensions (127×63) substituted for the consts, When the round-trip suite runs, Then it still passes.
- **AC (offset)**: Given a non-zero `origin_offset_px`, When round-tripped, Then identity still holds.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/board-renderer/transform_round_trip_test.gd` — must exist and pass

**Status**: [x] Created + passing — `tests/unit/board-renderer/transform_round_trip_test.gd` (8 test fns, 8/8 PASS)

---

## Dependencies

- Depends on: None (first story — the root of the epic)
- Unlocks: Story 002 (sprite placement anchor), Story 003 (overlay reuses config), Story 004 (`pick_at` diamond fallback calls `screen_to_grid`), Story 005 (glyph anchor calls `grid_to_screen`). **Also the hard unlock for CAI Story 006 and the HUD glyph layer.**

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 4/4 passing (0 deferred) — all covered by automated tests
**Implementation**: `src/ui/board_renderer/board_renderer.gd` (NEW — `class_name BoardRenderer extends Node2D`; `grid_to_screen`/`screen_to_grid` + shared static `_project`/`_unproject` helpers, consts `TILE_WIDTH_PX`/`TILE_HEIGHT_PX`, `@export origin_offset_px`). First Presentation-layer file → sets `src/ui/` as the Presentation bucket (CAI/HUD follow).
**Test Evidence**: Logic — `tests/unit/board-renderer/transform_round_trip_test.gd` (8 test fns, 8/8 PASS; full suite 512/512, no regressions).
**Deviations**: None. AC-3 (variable tile dims) resolved via the shared static `_project`/`_unproject` (single ADR-0013 §1 formula; instance methods use the consts, tests pass 127×63) — instance API identical to spec, no forbidden pattern.
**Code Review**: Complete — APPROVED (2026-07-27; one non-blocking suggestion to tighten the AC-2 boundary-test comment on a future pass).
