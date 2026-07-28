# Visual/Feel Evidence — On-Board Glyph Layer (hud-005)

> **Story**: production/epics/game-hud/story-005-on-board-glyph-layer.md
> **Type**: Visual/Feel (ADVISORY gate)
> **Status**: ⏳ OWED — pending a windowed (non-headless) session for sign-off

## Scope

The BLOCKING Logic sub-slice (AC-10, the hp pip-vs-numeric branch + marker
derivation) is covered by `tests/unit/game-hud/hp_pip_numeric_branch_test.gd`
(pass). This document covers the **advisory** legibility/shape criteria, which
require a human viewing a real windowed build at target resolutions.

## Criteria to verify (reviewer sign-off)

| AC | Setup | Pass condition | Verdict |
|----|-------|----------------|---------|
| **AC-11** | A unit with hp pips + has-acted marker on one tile, at 1080p and 1440p | hp pips fully **unobstructed** at both resolutions — no marker overlaps the pip region (hp-pip-never-occluded) | ☐ |
| **AC-26** | Two Research Labs (same owner) mid-research | Each shows its **own** research marker, not one shared/global indicator | ☐ (blocked — see stub) |
| **Shape distinctness** | has-acted / tech / normal rendered at minimum supported UI scale + 1440p | Shapes remain **distinguishable by shape** (non-hue-redundant), not colour alone | ☐ |
| **Pip feel** | A unit takes damage | Pips drain **one at a time**, chunky/neutral, no smooth bar; faction hue never touches hp | ☐ |
| **Anchoring** | Glyphs on several tiles across the board | Every glyph sits at `grid_to_screen(tile) + GLYPH_OFFSETS[class]` and reprojects correctly under the iso transform | ☐ |

## Known stubs (data not yet implemented — NOT rendered)

- **TECH_MARKER** (owner-has-researched): needs a player tech-flag read the
  `GameStateReader` facade does not yet expose. `OnBoardGlyphLayer.active_markers_for`
  is the single attach point once that read exists.
- **RESEARCH_MARKER** (per-Research-Lab in-progress, AC-12/AC-26): needs the
  Research/Tech epic (not implemented — same stub the AI epic carries). AC-26
  cannot be signed off until Research exists.

Both stubs are asserted-absent by `test_tech_and_research_markers_are_stubbed`,
so wiring them later is a deliberate change, never a silent gap.

## Follow-up (owed, not blocking this story)

- **Visual/Audio D — board-scale glyph-density/legibility playtest**: the
  epic-mandated late-game density check (many entities + markers on-screen). This
  story *feeds* it but does not satisfy it; schedule it as a separate
  `production/qa/` task.

## Sign-off

| Role | Name | Verdict | Date |
|------|------|---------|------|
| Lead / reviewer | | [ ] Approved | |
