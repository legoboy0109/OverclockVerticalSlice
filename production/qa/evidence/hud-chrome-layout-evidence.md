# UI Evidence — HUD Chrome Layout (hud-007)

> **Story**: production/epics/game-hud/story-007-action-log-income-build-controls.md
> **Type**: UI / Visual (ADVISORY gate)
> **Status**: ⏳ OWED — pending a windowed (non-headless) session for sign-off

## Scope

The BLOCKING slices are covered by automated tests (pass):
`tests/unit/game-hud/action_log_income_breakdown_test.gd` (log ring buffer +
income breakdown) and `tests/integration/game-hud/build_endturn_turn_scoping_test.gd`
(Build affordability + turn-scoped inertness + PREVIEW_BUILD cue). This doc
covers the **advisory** layout/interaction criteria needing a windowed build.

## Criteria to verify (reviewer sign-off)

| AC | Setup | Pass condition | Verdict |
|----|-------|----------------|---------|
| **AC-24** | Local Action phase, various selections/previews | AP counter, turn/round indicator, End Turn, Build, action log all **continuously present** regardless of selection/preview/actions | ☐ |
| **Dual-focus** | Tab/click Build & End Turn (keyboard + mouse) at 1080p/1440p | `grab_click_focus`/`grab_focus` both work; distinct focus vs hover StyleBoxes; inert controls carry `FOCUS_NONE` (no focus ring) | ☐ |
| **Build dim** | 0 affordable structure types | Build is **dimmed but present** (never hidden); pressed/active treatment shows while `PREVIEW_BUILD` is live | ☐ |
| **Log readability** | A busy multi-event commit (kill + HQ-destroy) | Newest-on-top, one row per event, icon+text legible at both resolutions; log stays silent | ☐ |
| **Income popover** | Toggle income breakdown (hover/click/keyboard) | Shows `base / +outpost / +econ-tech` labeled fields; toggles cleanly | ☐ |

## Known follow-ups (owed, not blocking)

- **Keyboard-focus traversal order** across the three IA zones (OQ-5) — a
  reasonable default is implemented (`controls_focus_mode` FOCUS_ALL/FOCUS_NONE);
  the concrete traversal order is owed to a `/ux-design` pass.
- **HUD-scene assembly**: instantiating + wiring all HUD widgets (this story's
  three + Stories 003–006) into a live `CanvasLayer` is deferred integration glue
  (vertical-slice build), not in the in-slice story set.

## Sign-off

| Role | Name | Verdict | Date |
|------|------|---------|------|
| Lead / reviewer | | [ ] Approved | |
