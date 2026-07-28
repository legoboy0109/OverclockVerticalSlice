# Test Evidence: Board Renderer Story 002 — Y-Sort Depth Ordering & Scene-Tree Skeleton

> **Story**: `production/epics/board-renderer/story-002-y-sort-depth-scene-skeleton.md`
> **Story Type**: Visual/Feel
> **Date**: 2026-07-27 (stub created; visual verification OWED)
> **Tester**: _pending — requires a windowed Redot session_
> **Build / Commit**: _pending_

---

## What Was Tested

The `BoardRenderer` scene-tree skeleton (ADR-0013 §2): `FloorTileMapLayer` (z_index 0) →
`OverlayTileMapLayer` (z_index 1) → `OccupantLayer` (Node2D, `y_sort_enabled = true`, z_index 2),
with placeholder occupant fixtures (2 units at different grid rows + 1 tall prop) so the native
Y-sort has something to order. Depth ordering uses Godot's native `y_sort_enabled`, never custom
depth math.

**Acceptance criteria covered**: AC-1 + AC-4 (structural — **automated**, PASS); AC-2 + AC-3
(visual occlusion/flip — **OWED**, require a windowed session).

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | Scene tree matches Floor(z0) → Overlay(z1) → OccupantLayer(Node2D, y_sort on, z2); Floor/Overlay outside the y-sort group | **PASS (automated)** | Covered by `tests/unit/board-renderer/scene_structure_test.gd` (4 tests: tree shape, z-bands, y_sort flags, iso TileSet + matching dims). |
| AC-2 | Two occupants at different `tile.y` → greater world-Y draws in front (native `y_sort_enabled`, no custom sort) | **OWED — visual** | Cannot be verified headlessly. Requires a windowed Redot session + screenshot. |
| AC-3 | Unit crossing a tall prop's row → draw order flips correctly frame-to-frame, no flicker / one-frame misorder | **OWED — visual** | Requires 2–3 sequential screenshots across the crossing. |
| AC-4 | Child under OccupantLayer with no explicit z_index participates in the y-sort group (regression guard) | **PASS (automated)** | Covered by `scene_structure_test.gd` (`test_occupant_layer_children_do_not_set_conflicting_z_index` + fixture-minimum guard). |

---

## Screenshots / Video

_None captured yet — this is the owed work._ When the windowed session runs, store captures here:

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `board-renderer-y-sort/ac2-occlusion.png` | Greater-Y placeholder occludes the lesser-Y one at the shipping iso camera; readable at 1080p and 1440p, no z-fighting | AC-2 |
| 2 | `board-renderer-y-sort/ac3-flip-a.png` | Unit before crossing the tall-prop row | AC-3 |
| 3 | `board-renderer-y-sort/ac3-flip-b.png` | Unit after crossing — draw order flipped, no misorder | AC-3 |

---

## Test Conditions

- **Game state at start**: `BoardRenderer` scene instanced with its placeholder floor + 3 placeholder occupants (built by the temporary `_build_placeholder_occupants()`).
- **Platform / hardware**: _pending — record at capture (target: Windows/Linux PC, 1080p and 1440p)._
- **Framerate during test**: _pending._
- **Any special setup required**: run the `BoardRenderer` scene in a windowed Redot 26.2 editor session; step a placeholder unit's `position.y` (via `grid_to_screen`) across the tall prop's row for the AC-3 flip capture.

> **Engine re-confirmation note (ADR-0013 MEDIUM risk):** the `y_sort_enabled` / `z_index` /
> `TILE_SHAPE_ISOMETRIC` mechanism was spike-cleared PASS 2026-07-25, but this is the first live
> scene tree in the project — the windowed session should re-confirm `Node2D.y_sort_enabled`
> draw-order behaves as documented against this actual scene before AC-2/AC-3 are signed off.

---

## Observations

- Structural ACs (AC-1/AC-4) are fully automated and green — the visual sign-off below is scoped
  only to the occlusion (AC-2) and flip (AC-3) behaviors that a test cannot see.
- The placeholder occupants are `Polygon2D`s (Node2D-based, not `Control`-based — required for
  `y_sort_enabled` to compare their position.y at all) with ground-contact (bottom-center) pivots:
  each polygon's local points extend upward from its own origin, so `position = grid_to_screen(tile)`
  directly is the ground-contact point — the same anchor contract real sprites will use. An earlier
  draft used `ColorRect` (a `Control`), which silently would not have participated in the Y-sort;
  caught and corrected before sign-off (see `src/ui/board_renderer/board_renderer.gd`).

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer (implemented) | godot-specialist | 2026-07-27 | [x] Approved (structural; AC-1/AC-4) |
| Designer / Art Lead / UX Lead | | | [ ] Approved |
| QA Lead | | | [ ] Approved |

> **Visual sign-off DEFERRED — reason:** AC-2/AC-3 require a windowed Redot session that has not
> been run yet. This must be resolved before `br-002` advances past sprint review. The structural
> half is complete and test-covered now; the story is **Complete-with-notes** pending the visual
> capture.

---

*Template: `.claude/docs/templates/test-evidence.md`*
