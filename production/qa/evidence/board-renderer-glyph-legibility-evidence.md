# Test Evidence: Board Renderer Story 005 — On-Board Glyph Anchoring Convention

> **Story**: `production/epics/board-renderer/story-005-glyph-anchoring-convention.md`
> **Story Type**: Logic (this evidence covers only its Visual/Feel-classified ACs)
> **Date**: 2026-07-27 (stub created; visual verification OWED)
> **Tester**: _pending — requires a windowed Redot session_
> **Build / Commit**: _pending_

---

## What Was Tested

The `GLYPH_OFFSETS` anchor mechanism (ADR-0013 §5): every on-board glyph anchors at
`grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, computed by `BoardRenderer.glyph_anchor()` and
authored as external data in `data/ui/glyph_offsets.tres` (`src/ui/board_renderer/glyph_offsets.gd`).
AC-1 (formula exactness) and AC-2 (data-driven, zero-code-change retuning) are **Logic** and are
fully automated — see `tests/unit/board-renderer/glyph_offset_anchor_test.gd`. AC-3 and AC-4 are
**Visual/Feel** (hp-pip-never-occluded under real rendering; all-12-classes legibility at target
resolutions) and cannot be verified headlessly.

**Acceptance criteria covered by this document**: AC-3, AC-4 (both **OWED**).
**Acceptance criteria covered by automated tests instead**: AC-1, AC-2 (both **PASS** — see
`tests/unit/board-renderer/glyph_offset_anchor_test.gd`, 11 test functions).

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | Anchor point equals exactly `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]` — no other computation path | **PASS (automated)** | `glyph_offset_anchor_test.gd` — formula tests (3 fns: known offset, different tile/class, zero-offset regression guard). |
| AC-2 | `GLYPH_OFFSETS` authored as external data; retuning needs no code change | **PASS (automated)** | `glyph_offset_anchor_test.gd` — data-driven tests (2 fns: mutate a field on the injected resource, swap the whole injected instance) + the on-disk `.tres` load-and-resolve regression guard. |
| AC-3 | hp pips never visually occluded by has-acted marker + AP-cost badge on one crowded tile, at 1080p and 1440p | **OWED — visual** | Cannot be verified headlessly. Requires a windowed Redot session rendering all three glyph classes on one tile at both target resolutions. |
| AC-4 | All 12 glyph classes, one per tile on a test board, are legible (non-overlapping or intentionally-layered per priority) at both target resolutions | **OWED — visual, requires art/UX reviewer sign-off** | The *mechanism* side (all 12 classes resolve to a defined, distinct offset) is automated (`test_all_twelve_glyph_classes_resolve_to_a_defined_offset`); actual on-screen legibility/positioning/no-off-board-clipping is not. |

---

## Screenshots / Video

_None captured yet — this is the owed work._ When the windowed session runs, store captures here:

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `board-renderer-glyph-legibility/ac3-hp-pip-priority-1080p.png` | One test unit with hp pips + has-acted marker + AP-cost badge, 1080p — hp pips fully unobstructed | AC-3 |
| 2 | `board-renderer-glyph-legibility/ac3-hp-pip-priority-1440p.png` | Same setup at 1440p | AC-3 |
| 3 | `board-renderer-glyph-legibility/ac4-all-twelve-classes-1080p.png` | Full 12-glyph-class taxonomy, one per tile (incl. edge tiles), 1080p | AC-4 |
| 4 | `board-renderer-glyph-legibility/ac4-all-twelve-classes-1440p.png` | Same board at 1440p | AC-4 |

---

## Test Conditions

- **Game state at start**: `BoardRenderer` instanced with the real `data/ui/glyph_offsets.tres`
  data (no injected overrides — this is a sign-off on the shipping authored values, not the
  mechanism, which the automated suite already covers).
- **Platform / hardware**: _pending — record at capture (target: Windows/Linux PC, 1080p and 1440p)._
- **Framerate during test**: _pending._
- **Any special setup required**: run a `BoardRenderer` scene in a windowed Redot 26.2 editor
  session with placeholder glyph art (or simple labeled markers) placed via `glyph_anchor()` for
  each of the 12 `BoardRenderer.GlyphClass` values; for AC-3, stack `HP_PIP` + `HAS_ACTED` +
  `AP_COST_BADGE` on one occupied tile.

> **hp-pip-priority is an authoring guarantee, not a runtime check (ADR-0013 §5):** if AC-3 fails
> at capture time, the fix is to retune `GlyphOffsets.hp_pip` / the conflicting class's offset in
> `data/ui/glyph_offsets.tres` (no code change) — this story deliberately does not build any
> runtime overlap-arbitration system, so a failure here is a data-authoring issue, not a bug in
> `glyph_anchor()`.

---

## Observations

- The Logic half of this story (AC-1/AC-2) is fully automated and green — this stub scopes only
  the two visual ACs a headless test cannot see.
- `GlyphOffsets`' 12 fields currently hold placeholder pixel values (see `glyph_offsets.gd` field
  doc comments and `data/ui/glyph_offsets.tres`) authored only to keep `hp_pip` at
  `Vector2.ZERO` (first claim) and spread the other 11 classes outward from there — real
  art/UX-reviewed positioning for AC-3/AC-4 sign-off is the owed work this stub tracks, not a
  guess that happens to already be correct.

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer (implemented) | godot-gdscript-specialist | 2026-07-27 | [x] Approved (mechanism; AC-1/AC-2) |
| Designer / Art Lead / UX Lead | | | [ ] Approved |
| QA Lead | | | [ ] Approved |

> **Visual sign-off DEFERRED — reason:** AC-3/AC-4 require a windowed Redot session with actual
> glyph art (owned by the HUD/CAI epics, out of this story's scope) placed via `glyph_anchor()`,
> which has not been run yet. This must be resolved before `br-005` advances past sprint review.
> The Logic half is complete and test-covered now; the story is **Complete-with-notes** pending the
> visual capture.

---

*Template: `.claude/docs/templates/test-evidence.md`*
