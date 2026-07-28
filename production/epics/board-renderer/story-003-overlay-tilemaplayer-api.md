# Story 003: Overlay TileMapLayer — `set_overlay()` / `clear_overlay()` API

> **Epic**: Board Renderer
> **Status**: Complete (with notes — visual AC-4/AC-5 owed)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: (ADR-driven — producer-side requirement is `TR-grid-008` in `design/gdd/grid-terrain.md`)
**Requirement**: `TR-grid-008` (owned); delivers `TR-cmdui-016` (CAI's 9-class overlay taxonomy)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays (§3, primary)
**ADR Decision Summary**: Overlays are a second iso `TileMapLayer` sharing the floor's exact `TileSet` config (so alignment is structural, not hand-verified), exposed as `set_overlay(tiles, class_id)`/`clear_overlay()`; consumers never touch pixel math.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: `TileSet.TILE_SHAPE_ISOMETRIC` config-sharing between two `TileMapLayer`s is spike-cleared PASS 2026-07-25, but this is the first story to author the 9-class atlas source in this project's live editor — confirm atlas-entry-per-class authoring behaves as expected (live-editor pass, not a training-data gap). `TileMapLayer` (not legacy `TileMap`) is the current 4.6 node.

**Control Manifest Rules (this layer)**:
- Required: `OverlayTileMapLayer` must share the floor's exact `TileSet` iso config (same tile dims + `TILE_SHAPE_ISOMETRIC`), with one atlas entry per the 9-class overlay taxonomy — source: ADR-0013
- Required: Command & Action Interface must call `BoardRenderer.set_overlay(tiles, class_id)`/`clear_overlay()` — never touch `grid_to_screen`/pixel math itself for overlay placement — source: ADR-0013
- Guardrail: Board rendering (floor + overlay) targets ~5–10 draw calls for the whole 14×16 board — source: ADR-0013

---

## Acceptance Criteria

*From ADR-0013 §3 + TR-grid-008, scoped to this story:*

- [ ] GIVEN `set_overlay(tiles: Array[Vector2i], class_id: int)` is called with a tile list and one of the 9 taxonomy class IDs, WHEN the overlay layer is inspected, THEN exactly those tiles are populated with the corresponding atlas entry and no others (assertable programmatically via the `TileMapLayer`'s cell data — no rendering needed)
- [ ] GIVEN an overlay is set, WHEN `clear_overlay()` is called, THEN the overlay layer has zero populated cells
- [ ] GIVEN `set_overlay()` is called a second time (hover moves to a new tile set), WHEN inspected, THEN the previous overlay's tiles are fully replaced, not accumulated (no stale leftover cells)
- [ ] GIVEN a floor tile and an overlay tile at the same grid coordinate, WHEN both are rendered, THEN their screen-space diamonds coincide exactly (same `TileSet` config) — Visual/Feel check
- [ ] GIVEN the whole 14×16 board with floor + overlay populated, WHEN draw calls are profiled, THEN the combined total stays within the ~5–10 draw-call budget

---

## Implementation Notes

*Derived from ADR-0013 §3 (transcribed):*

- `OverlayTileMapLayer` shares the floor's exact `TileSet` iso configuration (same `TILE_WIDTH_PX`/`TILE_HEIGHT_PX`, same `TILE_SHAPE_ISOMETRIC`) — do not hand-author a second, independently-tuned `TileSet`; shared config is what makes alignment structural rather than hand-verified.
- Dedicated tile-source with one atlas entry per member of the existing 9-class taxonomy (in-cap fill, over-cap hatch, target ring, blocked-by-friendly, out-of-range dim, AREA dead-zone, build/deploy go-tile, cancel-refund, D-3 echo — per `command-action-interface.md` Visual/Audio B), drawn as 2:1 diamonds.
- API signatures (exact): `func set_overlay(tiles: Array[Vector2i], class_id: int) -> void`, `func clear_overlay() -> void`.
- Consumers (CAI, any future) must call these — never touch `grid_to_screen`/pixel math for overlay placement (the structural boundary this story enforces).
- This story does not need `pick_at()` (Story 004) — it is pure overlay-population API plus one visual-alignment check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `pick_at()` — Story 004
- Glyph anchoring — Story 005
- The CAI-side logic of *which* tiles get which `class_id` — the consumer epic's job (this story only proves the API mechanism)

---

## QA Test Cases

- **AC (set_overlay)**: Given a list of 5 tiles and `class_id = TARGET_RING`, When `set_overlay()` is called, Then querying the `OverlayTileMapLayer`'s cell data at those 5 coordinates returns the target-ring atlas source id, and all other cells are empty.
- **AC (replace)**: Given an overlay already set, When `set_overlay()` is called with a different tile set, Then old tiles are cleared and only the new tiles are populated. Edge cases: calling with an empty `Array[Vector2i]` clears everything, equivalent to `clear_overlay()`.
- **AC (clear no-op)**: Given `clear_overlay()` is called with no prior `set_overlay()`, Then it is a no-op, no error.
- **AC (alignment — Visual/Feel)**: Setup: render floor + overlay at identical coordinates across the 14×16 board. Verify: screenshot at 1080p and 1440p shows no seam/offset between floor and overlay diamond edges. Pass condition: pixel-aligned, zero-gap tiling.
- **AC (draw calls — Visual/Feel)**: Setup: profile draw calls with floor + overlay both fully populated. Verify: profiler reports total within budget. Pass condition: ≤10 draw calls for both layers combined.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/board-renderer/overlay_api_test.gd` — must exist and pass (blocking); plus advisory `production/qa/evidence/board-renderer-overlay-alignment-evidence.md` (Visual/Feel alignment + draw-call check)

**Status**: [x] Integration test created + passing — `tests/integration/board-renderer/overlay_api_test.gd` (7 fns, covers AC-1/2/3 cell-data, BLOCKING); advisory visual evidence `production/qa/evidence/board-renderer-overlay-alignment-evidence.md` (AC-4/AC-5 OWED — windowed session)

---

## Dependencies

- Depends on: Story 002 (scene skeleton must exist — the `OverlayTileMapLayer` node)
- Unlocks: CAI overlay rendering (TR-cmdui-016) — CAI Story 006 cannot render any highlight until this lands

---

## Completion Notes
**Completed**: 2026-07-27 (Complete with notes)
**Criteria**: AC-1/AC-2/AC-3 (cell-data: set populates exactly those cells, clear empties, second set replaces + empty-array clears, clear no-op) auto-verified + PASS (BLOCKING integration test). AC-4 (floor↔overlay diamond alignment) + AC-5 (≤10 draw-call budget) are **OWED — visual** (advisory; alignment is structurally de-risked by the shared iso TileSet asserted in `scene_structure_test.gd`).
**Implementation**: extended `src/ui/board_renderer/board_renderer.gd` — `OverlayTileMapLayer` given a tile-source with one atlas entry per the 9-class `OverlayClass` enum (placeholder flat-tinted diamonds via `_build_diamond_texture`, `OVERLAY_TINTS`), sharing the floor's exact iso TileSet config. `set_overlay(tiles, class_id)` (clears-then-populates, so replace never accumulates; empty ⇒ clear) + `clear_overlay()`. Story 001/002 code (transforms, scene tree, occupants) untouched.
**Test Evidence**: Integration — `tests/integration/board-renderer/overlay_api_test.gd` (7 fns, 7/7 PASS); advisory visual `production/qa/evidence/board-renderer-overlay-alignment-evidence.md` (AC-4/AC-5 owed, sign-off DEFERRED). Full suite 540/540, no regressions.
**Deviations**: None.
**Code Review**: not separately run (specialist-authored, integration-test-covered); recommend a light pass at sprint close-out.
