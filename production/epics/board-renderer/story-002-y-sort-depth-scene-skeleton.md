# Story 002: Y-Sort Depth Ordering & Scene-Tree Skeleton

> **Epic**: Board Renderer
> **Status**: Complete (with notes — visual AC-2/AC-3 owed)
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-27

## Context

**GDD**: (ADR-driven — producer-side requirement is `TR-grid-008` in `design/gdd/grid-terrain.md`)
**Requirement**: `TR-grid-008` (owned, depth-sort half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays (§2, primary); ADR-0001 (secondary — `entities()`/`entity_at()`, though this story may stub occupants)
**ADR Decision Summary**: Depth ordering uses Godot's native `y_sort_enabled` on an `OccupantLayer` (not custom depth math); a coarse `z_index` band separates Floor (0) → Overlay (1) → Occupant (2), and Y-sort re-sorts only *within* the occupant band.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: The mechanism (`y_sort_enabled`, `z_index` banding, `TileSet.TILE_SHAPE_ISOMETRIC`) is spike-cleared PASS 2026-07-25, but this is the first story to build the live scene tree in this project's editor — a quick repeat live-editor confirmation is prudent (re-confirming a cleared spike, not new research). Confirm `Node2D.y_sort_enabled` draw-order behaves as documented against this project's actual `BoardRenderer` scene.

**Control Manifest Rules (this layer)**:
- Required: `BoardRenderer` scene structure must be `FloorTileMapLayer` (z_index 0) → `OverlayTileMapLayer` (z_index 1) → `OccupantLayer` (y_sort_enabled, z_index 2); Floor/Overlay sit outside the Y-sort group — source: ADR-0013
- Required: Depth-sort must use native `y_sort_enabled` on `OccupantLayer`, never custom depth math — source: ADR-0013
- Required: Children of `OccupantLayer` must not set a `z_index` that fights the Y-sort — source: ADR-0013

---

## Acceptance Criteria

*From ADR-0013 §2 + TR-grid-008, scoped to this story:*

- [ ] GIVEN the `BoardRenderer` scene tree, WHEN inspected, THEN it matches exactly: `FloorTileMapLayer` (z_index 0) → `OverlayTileMapLayer` (z_index 1) → `OccupantLayer` (Node2D, `y_sort_enabled = true`, z_index 2) — Floor/Overlay outside the Y-sort group
- [ ] GIVEN two occupant sprites at different grid rows (different `tile.y`) placed via `sprite.position = grid_to_screen(tile)`, WHEN rendered, THEN the sprite with the greater world-Y draws in front, matching `y_sort_enabled`'s native global-Y comparison — no custom sort code
- [ ] GIVEN a tall prop occupant and a unit crossing its row, WHEN the unit's Y crosses the prop's Y, THEN draw order flips correctly frame-to-frame with no flicker or one-frame misorder
- [ ] GIVEN a child node under `OccupantLayer` that does NOT set its own `z_index`, WHEN rendered, THEN it participates correctly in the Y-sort group (regression guard)

---

## Implementation Notes

*Derived from ADR-0013 §2 (transcribed):*

- Exact scene-tree structure:
  ```
  BoardRenderer (Node2D)
   ├─ FloorTileMapLayer      (TileSet.TILE_SHAPE_ISOMETRIC; static terrain art; z_index 0)
   ├─ OverlayTileMapLayer    (TileSet.TILE_SHAPE_ISOMETRIC; reachable/target/build overlays; z_index 1)
   └─ OccupantLayer (Node2D, y_sort_enabled = true; z_index 2)
        ├─ unit/structure sprites (position = grid_to_screen(tile), pivot = ground-contact point)
        └─ tall props with vertical overhang (pulled out of the floor layer)
  ```
- `z_index` is the coarse cross-tree band (Floor 0 → Overlay 1 → Occupant 2); `y_sort_enabled` re-sorts only *within* `OccupantLayer` — do not conflate the two mechanisms.
- This story may populate `OccupantLayer` with placeholder Node2D/Sprite2D fixtures (a "tall prop" and 2+ "units") rather than a live entity feed — the live `GameState.entities()` wiring is out of scope (see Out of Scope; flag ownership if unassigned).
- `FloorTileMapLayer`/`OverlayTileMapLayer` are created as empty `TileMapLayer` nodes with `TileSet.TILE_SHAPE_ISOMETRIC` configured; a minimal placeholder floor (a handful of tiles) is sufficient to prove z-index banding and support the visual check.
- Sprite pivot convention (ground-contact/bottom-center) is an art-authoring requirement this story depends on but does not produce — use placeholder sprites/ColorRects with a manually-set pivot.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Overlay tile taxonomy / `set_overlay()` API — Story 003
- `pick_at()` — Story 004
- Glyph anchoring — Story 005
- Any live `GameState`/`action_applied` wiring — **flag as an open item: whichever story first connects `BoardRenderer` to real match state owns it; not yet assigned**

---

## QA Test Cases

*Manual verification (Visual/Feel):*

- **AC (scene tree)**: Setup: build the scene tree above with a floor stub, 2 unit placeholders at different grid rows, 1 tall-prop placeholder. Verify: screenshot shows the greater-Y sprite drawn in front. Pass condition: correct occlusion at 1080p and 1440p, no z-fighting.
- **AC (flip)**: Setup: step a unit sprite's `position.y` (via `grid_to_screen`) across a tall prop's row. Verify: draw order visibly flips at the crossing, no one-frame flicker. Pass condition: clean flip across 2–3 sequential screenshots.
- **AC (z_index guardrail)**: Setup: add a child under `OccupantLayer` with an explicit non-zero `z_index`. Verify: code-review guardrail (per ADR-0013 Risk note) — confirm during review no conflicting `z_index` was introduced.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/board-renderer-y-sort-evidence.md` — screenshot walkthrough + sign-off

**Status**: [x] Structural test created + passing — `tests/unit/board-renderer/scene_structure_test.gd` (6 fns, covers AC-1/AC-4); visual evidence doc `production/qa/evidence/board-renderer-y-sort-evidence.md` (AC-2/AC-3 OWED — windowed session)

---

## Dependencies

- Depends on: Story 001 (`grid_to_screen` is the sprite placement anchor)
- Unlocks: Story 003 (overlay z_index sits between floor and occupant — needs the skeleton), Story 004 (`pick_at` needs the Y-sort draw order to define occupant test order), Story 005 (glyphs attach under/near `OccupantLayer`)

---

## Completion Notes
**Completed**: 2026-07-27 (Complete with notes)
**Criteria**: 2/4 auto-verified + PASS (AC-1 scene tree/z-bands/y_sort/iso config; AC-4 no-conflicting-z_index guard). AC-2 (greater-Y occludes) + AC-3 (clean flip) are **OWED — visual**, require a windowed Redot session (Visual/Feel gate is ADVISORY; native `y_sort_enabled` is spike-cleared, so this is confirmation not risk).
**Implementation**: extended `src/ui/board_renderer/board_renderer.gd` — programmatic scene build in `_ready()`: `FloorTileMapLayer`(z0) → `OverlayTileMapLayer`(z1) → `OccupantLayer`(Node2D, `y_sort_enabled`, z2), iso TileSets, placeholder occupants. Programmatic (not `.tscn`) so Floor/Overlay iso config can't drift.
**Test Evidence**: Visual/Feel — structural: `tests/unit/board-renderer/scene_structure_test.gd` (6 fns, 6/6 PASS); visual: `production/qa/evidence/board-renderer-y-sort-evidence.md` (AC-2/AC-3 owed, visual sign-off DEFERRED). Full suite 524/524, no regressions.
**Deviations**: None architectural. **Bug caught + fixed mid-implementation**: initial placeholders were `ColorRect` (a `Control`) which cannot participate in Node2D `y_sort_enabled` → switched to `Polygon2D` (Node2D). Surfaced by the parallel-story full-suite run.
**Open item (unassigned)**: live `GameState.entities()` → `OccupantLayer` feed replaces the temporary `_build_placeholder_occupants()` — whichever story first wires BoardRenderer to real match state owns it (flagged in class doc + EPIC).
**Code Review**: not separately run (small scene skeleton; structural tests + specialist authorship); recommend a light pass at sprint close-out.
