# Test Evidence: Board Renderer Story 003 — Overlay Alignment & Draw-Call Budget

> **Story**: `production/epics/board-renderer/story-003-overlay-tilemaplayer-api.md`
> **Story Type**: Integration (this doc covers the ADVISORY Visual/Feel ACs only)
> **Date**: 2026-07-27 (stub created; visual verification OWED)
> **Tester**: _pending — requires a windowed Redot session_
> **Build / Commit**: _pending_

---

## What Was Tested

The `OverlayTileMapLayer` `set_overlay(tiles, class_id)` / `clear_overlay()` API (ADR-0013 §3),
a second iso `TileMapLayer` sharing the floor's exact `TileSet` config with one atlas entry per
the 9-class overlay taxonomy. **The cell-data ACs (AC-1/AC-2/AC-3 — set populates exactly those
cells, clear empties, second set replaces) are BLOCKING and are covered by the automated
integration test** — this evidence doc records only the two ADVISORY Visual/Feel ACs that a
headless test cannot see.

**Acceptance criteria covered here**: AC-4 (floor↔overlay diamond alignment) + AC-5 (draw-call
budget). AC-1/AC-2/AC-3 are automated — see `tests/integration/board-renderer/overlay_api_test.gd`.

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | `set_overlay()` populates exactly the given tiles with the class atlas entry, no others | **PASS (automated)** | `overlay_api_test.gd` — cell-data assertion via `get_used_cells()`/`get_cell_source_id()`. |
| AC-2 | `clear_overlay()` → zero populated cells | **PASS (automated)** | `overlay_api_test.gd`. |
| AC-3 | Second `set_overlay()` fully replaces (no stale cells); empty array clears | **PASS (automated)** | `overlay_api_test.gd`. |
| AC-4 | Floor tile + overlay tile at same grid coord → screen diamonds coincide exactly (shared TileSet) | **OWED — visual** | Structurally guaranteed by shared TileSet config (asserted in `scene_structure_test.gd`: floor/overlay `tile_size` + `TILE_SHAPE_ISOMETRIC` match), but the pixel-level seam/offset check needs a windowed screenshot at 1080p + 1440p. |
| AC-5 | Whole 14×16 floor + overlay populated → combined draw calls within the ~5–10 budget | **OWED — visual** | Requires the in-editor/profiler draw-call count with both layers fully populated. |

---

## Screenshots / Video

_None captured yet._ When the windowed session runs, store captures here:

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `board-renderer-overlay/ac4-alignment.png` | Floor + overlay diamonds at identical coords — no seam/offset, zero-gap tiling, at 1080p and 1440p | AC-4 |
| 2 | `board-renderer-overlay/ac5-drawcalls.png` | Profiler with floor + overlay fully populated across 14×16 — combined draw calls ≤ 10 | AC-5 |

---

## Test Conditions

- **Game state at start**: `BoardRenderer` instanced; `FloorTileMapLayer` filled across a 14×16
  board and `set_overlay()` called for the whole board with one taxonomy class.
- **Platform / hardware**: _pending — record at capture._
- **Framerate during test**: _pending._
- **Any special setup required**: windowed Redot 26.2 editor session; enable the visible-draw-call
  overlay / monitor for AC-5.

> **Engine re-confirmation note (ADR-0013 MEDIUM risk):** first story to author the 9-class atlas
> source — the windowed session should confirm the atlas-entry-per-class renders as expected and
> the shared-`TileSet` alignment holds visually before AC-4/AC-5 sign-off.

---

## Observations

- The alignment AC (AC-4) is de-risked at the structural level: floor and overlay share one iso
  `TileSet` config (same tile dims + `TILE_SHAPE_ISOMETRIC`), asserted by an automated test — the
  windowed check is confirmation of pixel-perfect tiling, not a discovery of whether it aligns at all.
- Overlay art is placeholder (flat-tinted solid diamonds, one per taxonomy class); real overlay art
  is a later technical-art pass.

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer (implemented) | godot-specialist | 2026-07-27 | [x] Approved (API + cell-data ACs; automated) |
| Designer / Art Lead / UX Lead | | | [ ] Approved |
| QA Lead | | | [ ] Approved |

> **Visual sign-off DEFERRED — reason:** AC-4/AC-5 require a windowed Redot session (not yet run).
> The blocking API/cell-data half (AC-1/AC-2/AC-3) is complete and test-covered now; the story is
> **Complete-with-notes** pending the visual alignment + draw-call capture.

---

*Template: `.claude/docs/templates/test-evidence.md`*
