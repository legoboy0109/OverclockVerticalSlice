# Story 004: Occupant-Priority Picking — `pick_at()` / `PickResult`

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: (ADR-driven — producer-side requirement is `TR-grid-008` in `design/gdd/grid-terrain.md`)
**Requirement**: `TR-grid-008` (owned); delivers `TR-cmdui-003` (screen→grid inverse), `TR-cmdui-004` (occupant/stacked-tile ambiguity resolution)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays (§4, primary)
**ADR Decision Summary**: Picking is occupant-priority then diamond fallback — `pick_at()` tests occupant sprite regions front-to-back in Y-sort order first, returning the occupant's own state-tracked tile; only an empty-region click falls through to `screen_to_grid`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Priority-resolution logic is testable scene-tree-free by mocking occupant regions as `{rect: Rect2, entity_id, tile}` — no rendering dependency. The only engine-adjacent piece (iterating real sprite regions in Y-sort order) is validated by Story 002's cleared y-sort mechanism. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: Picking must be occupant-priority then diamond fallback — `pick_at(screen_pos)` tests occupant sprites front-to-back in Y-sort draw order first (each clickable region an authored sprite `Rect2`/mask, not derived from `grid_to_screen`), falling back to plain `screen_to_grid` for empty-tile clicks — source: ADR-0013
- Required: Command & Action Interface must consume `pick_at()` as its one click-routing entry point — never call `screen_to_grid` directly for routing — source: ADR-0013
- Forbidden: Never resolve clicks via pure diamond math (`screen_to_grid` alone) with no occupant-priority layer — source: ADR-0013

---

## Acceptance Criteria

*From ADR-0013 §4 Validation Criteria + TR-grid-008, scoped to this story:*

- [ ] GIVEN a screen point with no occupant sprite region containing it, WHEN `pick_at(screen_pos)` is called, THEN it returns `PickResult{tile: screen_to_grid(screen_pos), occupant_entity_id: -1}` (diamond fallback)
- [ ] GIVEN a tall prop/unit whose sprite visually overlaps an adjacent tile's diamond, WHEN a click lands within that overlap region, THEN `pick_at()` returns the occupant (its own grid tile, read from state — not re-derived geometrically), NOT the geometrically-underlying empty tile
- [ ] GIVEN two occupants whose clickable regions overlap in screen space (one drawn in front per Y-sort), WHEN a click lands in the overlap, THEN `pick_at()` resolves to the front-most (closest-to-camera) occupant, tested in reverse of Y-sort paint order
- [ ] GIVEN a click resolves to an occupant, WHEN `PickResult.tile` is inspected, THEN it equals that occupant's own tracked grid tile (from game state), not a `screen_to_grid` re-derivation of the click position
- [ ] GIVEN `PickResult.occupant_entity_id`, WHEN no occupant was hit, THEN it is exactly `-1` (matching the grid's own `-1`-for-empty convention)

---

## Implementation Notes

*Derived from ADR-0013 §4 (transcribed):*

- `PickResult` class exactly as §4: `class PickResult extends RefCounted: var tile: Vector2i; var occupant_entity_id: int  # -1 if none`.
- `pick_at(screen_pos: Vector2) -> PickResult` algorithm:
  1. Test occupant sprites front-to-back in Y-sort draw order (closest-to-camera first — reverse of the engine's paint order, since a later-drawn/"in front" sprite must win the click).
  2. Each occupant's clickable region is its own sprite's visual rect (or a per-sprite `Rect2`/mask authored alongside the art — not derived from `grid_to_screen` alone).
  3. If an occupant's region contains `screen_pos`, return `{tile: that occupant's own grid tile (read from GameState, not re-derived), occupant_entity_id: its id}`.
  4. Otherwise, fall through to plain `screen_to_grid(screen_pos)` — an empty-tile click — `occupant_entity_id = -1`.
- For this story's unit tests, mock occupant regions as an injectable list of `{rect: Rect2, entity_id: int, tile: Vector2i}` — do not require a live rendered scene to exercise the priority branch (this is what makes it Logic-typed).
- CAI consumes `pick_at()` as its one click-routing entry point — it must never call `screen_to_grid` directly for routing (only for its own overlay/preview positioning). Note this boundary in the function's doc comment.
- **⚠ Ownership flag (per ADR-0013 Consequences/Risks):** "occupant clickable-region authoring" (the per-sprite `Rect2`/mask `pick_at` needs) has no confirmed owning epic yet — likely ADR-0014/CAI or a unit/structure-scene-authoring story. This story consumes region data via mocks for its unit tests, but something upstream must define how real occupant scenes produce that `Rect2`/mask data before `pick_at` can be exercised end-to-end against real sprites. Surface this gap to the CAI epic owner rather than improvising a convention.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Actual occupant sprite scenes / authoring of clickable-region data — flagged above; confirm ownership before/during this story (likely CAI/unit-scene scope)
- Glyph anchoring — Story 005

---

## QA Test Cases

- **AC (fallback)**: Given a mock occupancy with zero occupant regions, When `pick_at(p)` is called for any `p`, Then result equals `{tile: screen_to_grid(p), occupant_entity_id: -1}`.
- **AC (occupant priority)**: Given one mock occupant whose `Rect2` overlaps an adjacent tile's diamond area, When a point inside that overlap (geometrically over the adjacent tile) is picked, Then `pick_at()` returns that occupant's own tile/id, not the adjacent tile.
- **AC (front-most)**: Given two overlapping mock occupant regions with a defined front/back Y-sort order, When a point in the overlap is picked, Then the front occupant wins. Edge cases: swap which is "front" and confirm the result flips (proves order is respected, not hardcoded).
- **AC (OOB)**: Given a point outside every occupant region and outside `in_bounds`, When `pick_at()` is called, Then it degrades gracefully to `screen_to_grid`'s out-of-bounds behavior (no crash; sentinel/negative tile matches Grid's OOB convention).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/board-renderer/pick_at_occupant_priority_test.gd` — must exist and pass

**Status**: [x] Created + passing — `tests/unit/board-renderer/pick_at_occupant_priority_test.gd` (7 fns, 7/7 PASS)

---

## Dependencies

- Depends on: Story 001 (`screen_to_grid` fallback path), Story 002 (Y-sort draw order defines occupant test order)
- Unlocks: CAI's one click-routing entry point (TR-cmdui-004) — CAI Story 006 is explicitly blocked on this

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 5/5 covered by 7 automated tests — diamond fallback (`{screen_to_grid(p), -1}`); occupant region wins over the geometrically-underlying tile; front-most occupant wins on overlap **+ the front/back swap test proving order is respected, not hardcoded**; `PickResult.tile` = occupant's own tracked tile (not a re-derived click); `occupant_entity_id = -1` when no hit; plus OOB graceful fallback + just-outside-rect no-match.
**Implementation**: extended `src/ui/board_renderer/board_renderer.gd` — `class PickResult extends RefCounted {tile, occupant_entity_id}` + `pick_at(screen_pos)` (occupant-priority front-to-back in Y-sort order, then `screen_to_grid` fallback). Story 001/002/003 code untouched.
**Test Evidence**: Logic — `tests/unit/board-renderer/pick_at_occupant_priority_test.gd` (7 fns, 7/7 PASS; full suite 547/547, no regressions).
**Deviations**: None. **Key seam**: occupant clickable-region source is an **injectable** `occupant_pick_regions` list (`{rect, entity_id, tile}`) — real per-sprite Rect2/mask authoring is deliberately NOT invented here; it stays **build-seam S3-05** (scope.md §8b, unassigned). Tests inject mocks; the real live feed plugs in later. Documented in the function's doc comment.
**Code Review**: not separately run (specialist-authored, fully test-covered); recommend a light pass at sprint close-out.
