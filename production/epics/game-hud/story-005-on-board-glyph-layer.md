# Story 005: On-Board Glyph Layer — hp Pips/Numeric Branch, Has-Acted/Tech/Build/Research Markers

> **Epic**: Game HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L (4–5h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-010`, `TR-hud-011`, `TR-hud-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering (primary, §5 — glyph anchoring); ADR-0016: Game HUD (secondary — pip/numeric branch, `HUDConfig.pip_max_hp`)
**ADR Decision Summary**: On-board glyphs anchor at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]` (Board Renderer's convention); hp renders as discrete pips below `pip_max_hp` and numeric at/above it; hp-pip-never-occluded is guaranteed by offset-table authoring discipline.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: HIGH
**Engine Notes**: Inherits ADR-0013's glyph-anchor transform (spike CLEARED PASS 2026-07-25). The anchoring math is LOW-risk pure arithmetic; the multi-glyph-legibility surface is the epic's named late-game density risk (Visual/Audio D).

**Control Manifest Rules (this layer)**:
- Required: Every on-board glyph must anchor at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, with `GLYPH_OFFSETS` authored as data, not hardcoded literals; hp legibility wins any offset conflict — source: ADR-0013
- Required: The hp display must branch on `HUDConfig.pip_max_hp`: `max_hp < pip_max_hp` → discrete pips; `max_hp >= pip_max_hp` → numeric current/max — source: ADR-0016
- Forbidden: Never derive glyph anchors independently of `grid_to_screen` — source: ADR-0013

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN an entity with `max_hp < PIP_MAX_HP` vs `max_hp >= PIP_MAX_HP`, THEN hp renders as discrete drain-on-damage pips vs numeric current/max (never a smooth bar), respectively — including the boundary case `max_hp == PIP_MAX_HP` → numeric (AC-10)
- [ ] GIVEN a unit that has acted / whose owner has researched, THEN the has-acted/tech marker shows without occluding the hp pips, including when both markers + low-hp pips coexist (AC-11)
- [ ] GIVEN an under-construction structure with T turns remaining / a working Research Lab, THEN the turns-remaining badge shows T / the research-in-progress marker shows, each sourced verbatim (AC-12)
- [ ] GIVEN two or more Research Labs owned by the same player working simultaneously, THEN each shows its own independent research-in-progress marker, not a single shared/global indicator (AC-26)
- [ ] Every glyph anchors at exactly `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]` (Board Renderer Story 005's contract) — no HUD-local anchor math

---

## Implementation Notes

*Derived from ADR-0013 §5 + ADR-0016:*

- Consume `BoardRenderer.grid_to_screen(tile)` + the `GLYPH_OFFSETS` data table (Board Renderer Story 005) for every glyph anchor — do not write HUD-local pixel-offset math.
- hp pip-vs-numeric branch: `max_hp < HUDConfig.pip_max_hp` → discrete drain-on-damage pips (chunky square, neutral white/grey, drain one at a time, no tween — hp is state, not an actor; faction hue never touches hp); `max_hp >= HUDConfig.pip_max_hp` → numeric `current/max` stepping in whole integers, never a smooth bar. The `>=` boundary is load-bearing.
- hp-pip-never-occluded (TR-hud-011) is enforced by Board Renderer Story 005's offset-table *authoring discipline* — this story does NOT build runtime z-ordering/arbitration; it authors the `GLYPH_OFFSETS` entries so hp pips get first claim on non-overlapping space.
- Three non-hue-redundant glyph classes (has-acted, tech marker, normal) must be distinct **shapes** at fixed tile sub-positions, shape-distinguishable at minimum supported UI scale and at 1440p (Accessibility E) — never color alone.
- Each Research Lab's research-in-progress marker is independent per-instance — read per-structure from `GameStateReader`.
- This story feeds — but does not satisfy — the epic's mandated glyph-density/legibility playtest (Visual/Audio D); flag that playtest as a follow-up `production/qa/` deliverable, not blocking this story's Done.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The camera-model decision (OQ-8, deferred by Board Renderer Story 005)
- Any runtime glyph-overlap arbitration system (authoring discipline suffices)
- Detail panel — Story 006; AP counter — Stories 003/004

---

## QA Test Cases

- **AC-10 (Logic sub-slice, blocking)**: Given `max_hp=14` and `PIP_MAX_HP=10`, When hp render mode is queried, Then it returns numeric. Edge cases: `max_hp=10` exactly at threshold → numeric (the `>=` boundary); `max_hp=9` → pips.
- **AC-11 (Visual/Feel)**: Setup: unit with hp pips + has-acted + tech marker on one tile at 1080p and 1440p. Verify: hp pips fully unobstructed at both resolutions. Pass condition: reviewer sign-off, no overlap onto the pip region.
- **AC-26 (Visual/Feel)**: Setup: two Research Labs (same owner) mid-research. Verify: each shows its own marker. Pass condition: screenshot shows two markers, not one.
- **AC (shape distinctness — Visual/Feel)**: Setup: render has-acted/tech/normal at minimum supported UI scale. Verify: shapes remain distinguishable. Pass condition: reviewer sign-off at minimum scale + 1440p.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `tests/unit/game-hud/hp_pip_numeric_branch_test.gd` (Logic sub-slice, blocking) + `production/qa/evidence/on-board-glyph-layer-evidence.md` (Visual/Feel legibility, advisory + sign-off)

**Status**: [x] Blocking Logic test created and passing — 6 tests, all green (2026-07-28). [ ] Advisory Visual/Feel sign-off OWED (`production/qa/evidence/on-board-glyph-layer-evidence.md`, windowed session; AC-26 also blocked on the Research/Tech epic)

---

## Dependencies

- Depends on: **Board Renderer Story 005** (`grid_to_screen` + `GLYPH_OFFSETS` anchor convention — hard cross-epic gate), Story 001 (`GameStateReader` for hp/status/build-timer/research reads)
- Unlocks: nothing further within this epic; prerequisite for the mandated board-scale legibility playtest (Visual/Audio D)

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: Blocking Logic AC-10 (hp pip/numeric `>=` branch) covered (6 tests). Advisory Visual/Feel AC-11 + shape-distinctness OWED (windowed sign-off). AC-12/AC-26 research half + tech marker STUBBED (see below).
**Deliverables**: `src/ui/game_hud/on_board_glyph_layer.gd` (OnBoardGlyphLayer extends Node2D — every glyph anchored via `BoardRenderer.glyph_anchor(tile, glyph_class)`, NO HUD-local anchor math; hp pip/numeric branch; has-acted + build-timer markers from GameStateReader verbatim). Pure static `hp_render_mode` + `hp_mode_for`/`active_markers_for` testable model; `_draw` renders it (advisory).
**Deviations**: None blocking.
- STUBBED (data not implemented): TECH_MARKER needs a player-tech read the facade doesn't expose; RESEARCH_MARKER + AC-26 need the Research/Tech epic (not built — same stub the AI epic carries). `active_markers_for`/`_markers_from` is the single attach point; `test_tech_and_research_markers_are_stubbed` asserts both absent so future wiring is deliberate.
- "Has acted" = `unit_info.has_attacked` (the available signal via the facade); a broader movement-exhausted definition can extend later.
- Review suggestion ADDRESSED: shared the `unit_info`/`structure_info` fetch between the redraw path and the marker accessor (`_markers_from`) — no double-query per entity per redraw.
- Follow-up OWED (not blocking): the epic's Visual/Audio D board-scale glyph-density/legibility playtest (separate production/qa task).
**Test Evidence**: Logic (blocking) — `tests/unit/game-hud/hp_pip_numeric_branch_test.gd` (6 tests, PASS). Full suite 758/758 green. Advisory Visual/Feel — `production/qa/evidence/on-board-glyph-layer-evidence.md` (sign-off OWED).
**Code Review**: APPROVED-WITH-SUGGESTIONS → suggestion addressed (independent godot-gdscript read-only pass + coordinator; ADR-0013 anchoring / hp-branch / Pass-Through / stub contract / lifecycle / static typing all confirmed).
