# Story 006: Isometric Picking & Overlay Integration (Move/Attack/Build Overlays, Glyph Anchors)

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-003`, `TR-cmdui-004`, `TR-cmdui-016`, `TR-cmdui-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays (primary); ADR-0015 (secondary — the `CommandInterface` Node that calls `pick_at`/`set_overlay`)
**ADR Decision Summary**: A dedicated Board Renderer owns the grid→screen 2:1 dimetric transform, the custom inverse hit-test (`pick_at`), depth-sort, and overlay/glyph placement; the Command interface *consumes* that public API rather than reimplementing the transform.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: ADR-0013's HIGH-risk items (iso picking, `y_sort_enabled` draw order) are already spiked PASS 2026-07-25. Residual risk is *this story's* correct consumption of `pick_at()`/`set_overlay()`, not the underlying transform math.

**Control Manifest Rules (this layer)**:
- Required: Command & Action Interface must call `BoardRenderer.set_overlay(tiles, class_id)`/`clear_overlay()` — never touch `grid_to_screen`/pixel math itself for overlay placement — source: ADR-0013
- Required: Command & Action Interface must consume `pick_at()` as its one click-routing entry point — never call `screen_to_grid` directly for routing — source: ADR-0013
- Required: Every on-board glyph must anchor at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]` — source: ADR-0013

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] The custom inverse screen→grid hit-test resolves clicks correctly for 2:1 dimetric tiles (TR-cmdui-003) — verified via `pick_at()` round-trip consumption, not re-derivation
- [ ] Hit-test ambiguity from stacked/occluded iso tiles is resolved via occupant-priority-then-diamond-fallback — a click on a tall sprite's visually-overlapping silhouette resolves to the occupant, not the geometrically-underlying tile (TR-cmdui-004)
- [ ] GIVEN an attack preview with blocked-by-friendly, out-of-range, and AREA-dead-zone all present, THEN each is identifiable with color removed via distinct shape/pattern alone (AC-28, wiring portion)
- [ ] GIVEN a Move preview with both in-cap and over-cap tiles, THEN the two sets are distinguishable via hatch/pattern alone, each tile's per-tile AP cost shown (AC-29, wiring portion)
- [ ] GIVEN a unit with `tiles_moved_this_turn > 0` reselected, WHEN Move preview reopens, THEN the in-cap tile set is recomputed against current `tiles_moved_this_turn` and is a strict subset of the full-AP in-cap set (AC-30)
- [ ] Every on-board glyph anchors at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, with hp-pip-never-occluded priority preserved via authoring discipline (TR-cmdui-017)

---

## Implementation Notes

*Derived from ADR-0013 Implementation Guidelines:*

- Command & Action Interface calls `BoardRenderer.set_overlay(tiles: Array[Vector2i], class_id: int)` / `clear_overlay()` — it never touches `grid_to_screen`/pixel math for overlay placement, only for genuinely off-grid needs.
- Command & Action Interface consumes `pick_at()` as its **one** click-routing entry point — it does not call `screen_to_grid` directly for routing, only `grid_to_screen` for its own overlay/preview positioning.
- The 9-class overlay taxonomy (in-cap fill, over-cap hatch, target ring, blocked-by-friendly, out-of-range dim, AREA dead-zone, build/deploy go-tile, cancel-refund, D-3 echo) renders as one atlas entry per class on `OverlayTileMapLayer`, sharing the floor's exact `TileSet` iso config — alignment guaranteed by construction, not a second hand-verified transform.
- D-3's echo glyph anchors on the reachable tile using a shrunk/dimmed version of the attack-target bracket-corners glyph — distinct from both the in-cap "go-tile" fill and the live target-lock ring (exact visual params are Story 009/art-bible's).
- `GLYPH_OFFSETS[glyph_class]` is authored data (art/UX), not hardcoded literals — this story wires the anchor-point convention (`grid_to_screen(tile) + GLYPH_OFFSETS[...]`), not the specific offset numbers.
- **Cross-epic prerequisite:** this story is blocked on the Isometric Board Renderer node (`BoardRenderer` with `pick_at`/`grid_to_screen`/`set_overlay`) existing as an implemented scene — ADR-0013 is Accepted and its engine spike cleared, but the concrete `.gd`/`.tscn` is owned by a not-yet-scoped Board Renderer epic. Confirm it has landed at `/story-readiness` time for this story (see Dependencies).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Board Renderer's own transform math / `TileSet` authoring / Y-sort scene structure — owned entirely by the Isometric Board Renderer epic (this story consumes its public API)
- The specific pixel values of hatch angles / glyph shapes — art bible
- D-3's Formula logic itself — Story 003 wires the boolean; this story renders its echo

---

## QA Test Cases

- **AC (occupant priority)**: Setup: a scene with a floor + overlay TileMapLayer, a tall occluding prop, and a unit whose sprite visually overlaps an adjacent tile's diamond. Verify: click within the overlap region. Pass condition: `pick_at()` returns the occupant entity, not the underlying empty tile.
- **AC-29**: Setup: a Move preview with in-cap and over-cap tiles rendered. Verify: screenshot in greyscale/colorblind simulation. Pass condition: in-cap and over-cap remain distinguishable via hatch pattern alone.
- **AC-30**: Setup: a partially-moved unit (`tiles_moved_this_turn > 0`) reselected. Verify: compare the rendered in-cap overlay set against the full-AP in-cap set at 0 moved tiles. Pass condition: the reselected set is a strict subset — the cheap zone visibly shrinks.
- **AC-28**: Setup: an attack preview with all three blocked-shot states present. Verify: screenshot with color desaturated. Pass condition: blocked-by-friendly, out-of-range, and AREA dead-zone each read as distinct via shape/pattern alone.
- **AC-017**: Setup: an on-board glyph (AP-cost badge) on a tile also carrying an hp-pip glyph. Verify: render both. Pass condition: hp pip is never occluded by the AP badge (offset-table authoring discipline holds).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/command-action-interface/iso_picking_overlay_test.gd` (round-trip/occupant-priority assertions) + `production/qa/evidence/iso-overlay-legibility-evidence.md` (colorblind/greyscale screenshot walkthrough — Visual/Feel advisory portion)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (held Tier-1/2 sets to render), Story 003 (real `reachable`/`legal_targets`/`legal_build_tiles` data), **and the Isometric Board Renderer node (ADR-0013) — a separate, not-yet-scoped epic this story consumes but does not implement. If that node has not landed, this story is BLOCKED, not merely at-risk.**
- Unlocks: Story 009 (CR-9 legibility/colorblind polish builds on these overlay classes)
