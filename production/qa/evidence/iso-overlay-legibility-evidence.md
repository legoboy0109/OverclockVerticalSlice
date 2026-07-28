# Test Evidence: Command & Action Interface Story 006 — Iso Overlay Legibility (Color-Removed Distinctness)

> **Story**: `production/epics/command-action-interface/story-006-iso-picking-overlay-integration.md`
> **Story Type**: Integration (automated portion) + Visual/Feel (this advisory portion)
> **Date**: 2026-07-28 (stub created; visual verification OWED)
> **Tester**: _pending — requires a windowed Redot session_
> **Build / Commit**: _pending_

---

## What Was Tested

The Command & Action Interface's overlay wiring (ADR-0013 §3): `CommandInterface._render_overlays`
maps the held Tier-1/2 sets to `BoardRenderer.set_overlays(...)` — Move paints `MOVE_IN_CAP` +
`MOVE_OVER_CAP` (+ `AFTER_MOVE_ECHO`) together; Attack paints `ATTACK_TARGET`; picking routes
through `pick_at` (occupant priority); glyphs anchor via `glyph_anchor`.

**Acceptance criteria coverage:**
- **Automated (BLOCKING, PASS)** — TR-cmdui-003 (pick_at round-trip), TR-cmdui-004 (occupant priority),
  TR-cmdui-016 wiring + AC-30 (in-cap shrinks to a strict subset on reselection), TR-cmdui-017
  (glyph-anchor delegation): all covered by `tests/integration/command-action-interface/iso_picking_overlay_test.gd` (7 tests, PASS).
- **Visual/Feel (ADVISORY, OWED)** — AC-28 and AC-29 below require a windowed greyscale/colorblind
  screenshot walkthrough (color removed → distinctness must survive on shape/pattern alone). Cannot
  be verified headlessly; sign-off DEFERRED, same as the Board Renderer br-002/003/005 visual owes.

> **Note on placeholder art:** `BoardRenderer.OVERLAY_TINTS` currently bakes ONE flat color per
> `OverlayClass` (a mechanism placeholder). The real hatch/pattern/outline/shape authoring per
> `command-action-interface.md §B` is technical-art's later pass (Story 009 / art bible). AC-28/AC-29
> distinctness-with-color-removed CANNOT truly pass until that pattern authoring lands — so this
> evidence remains OWED against the real art, not just against a windowed session of the placeholders.

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| TR-cmdui-003 | Inverse hit-test resolves clicks via `pick_at()` round-trip consumption | **PASS (automated)** | `test_route_click_no_occupant_resolves_tile_via_fallback_no_selection`. |
| TR-cmdui-004 | Occupant-priority: click on an overlapping silhouette resolves to the occupant, not the underlying tile | **PASS (automated)** | `test_route_click_resolves_to_occupant_and_selects_own_unit_not_underlying_tile`. |
| AC-30 | Reselected partially-moved unit's in-cap set is a strict subset of the full-AP set | **PASS (automated)** | `test_reselect_after_moving_shrinks_in_cap_overlay_to_a_strict_subset`. |
| TR-cmdui-017 | Every on-board glyph anchors at `grid_to_screen(tile) + GLYPH_OFFSETS[class]` | **PASS (automated)** | `test_glyph_anchor_delegates_to_board_renderer_convention` (pure delegation). |
| AC-29 | Move preview in-cap vs over-cap distinguishable via **hatch/pattern alone** (color removed) | **OWED — visual** | Wiring PASS (`test_move_preview_paints_in_cap_and_over_cap_together...`); the color-removed distinctness needs a windowed greyscale screenshot + real pattern art. |
| AC-28 | Attack preview's blocked-by-friendly / out-of-range / AREA-dead-zone each distinct via **shape/pattern alone** | **OWED — visual** | Only a single `ATTACK_TARGET` class is wired in this story (the finer 3-way split is art/Story-009). Requires a desaturated screenshot once those classes + patterns exist. |
| TR-cmdui-017 (hp-pip priority) | hp pip never occluded by a co-located AP-cost badge | **OWED — visual** | Offset-table authoring discipline (`GlyphOffsets`); needs a windowed render of both glyphs on one tile. |

---

## Sign-Off

| Role | Name | Verdict | Date |
|------|------|---------|------|
| QA / Visual reviewer | _pending_ | [ ] Approved | _pending — windowed session + real pattern art required_ |

**Status: DEFERRED.** The automated (BLOCKING) portion of Story 006 is complete and green; the
Visual/Feel (ADVISORY) AC-28/AC-29/hp-pip-priority checks are owed against a windowed Redot session
and the real hatch/pattern art, tracked alongside the Board Renderer visual owes.
