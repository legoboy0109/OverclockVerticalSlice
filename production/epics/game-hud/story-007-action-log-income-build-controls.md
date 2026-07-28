# Story 007: Action Log Ring Buffer + Income Breakdown + Build Button + End Turn + Turn-Scoped Inert Controls

> **Epic**: Game HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (4–5h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-014`, `TR-hud-019`, `TR-hud-015`, `TR-hud-017` (Build/End-Turn inert half), `TR-hud-004` (always-present chrome), `TR-hud-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §5/§8); ADR-0006 (secondary — `ap_income_breakdown`); ADR-0014 (secondary — dual-focus for the two interactive controls)
**ADR Decision Summary**: The action log is an append-newest-on-top ring buffer (one entry per `result.events` element in append order); the income breakdown renders `ap_income_breakdown` fields verbatim; the Build button dims (never hides) when unaffordable and shows a pressed cue while CAI's `PREVIEW_BUILD` is live; Build/End-Turn are inert outside the local Action phase via `FOCUS_NONE`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: Dual-focus conventions (`grab_click_focus()`/`grab_focus()`, `FOCUS_NONE`) are ADR-0014-spike-cleared PASS 2026-07-25, so API risk is cleared; residual is wiring 4 focus-relevant elements per OQ-5's traversal-order sub-item.

**Control Manifest Rules (this layer)**:
- Required: The action log must be an append-newest-on-top ring buffer sized `HUDConfig.action_log_length`, appending one entry per `result.events` element in the events' fixed append order — source: ADR-0016
- Required: The Build button must read `can_afford` across structure types and dim (never hide) when none affordable, holding a pressed/active treatment while `PREVIEW_BUILD` is live — source: ADR-0016
- Required: The four interactive HUD controls must follow ADR-0014's dual-focus conventions (`grab_click_focus`/`grab_focus`, distinct StyleBoxes, `FOCUS_NONE` when inert) — source: ADR-0016/ADR-0014

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN a committed `apply_action`, THEN exactly one log entry is added newest-on-top (icon+text); GIVEN a single commit resolving multiple events (e.g. a kill), THEN each event gets its own entry in resolution order (AC-14)
- [ ] GIVEN more than `ACTION_LOG_LENGTH` committed actions, THEN only the newest `ACTION_LOG_LENGTH` are retained, oldest dropped first (AC-15)
- [ ] GIVEN the income breakdown revealed with n outposts and Economy-Tech state T, THEN it displays `BASE_INCOME(10)` + tiered-outpost + Economy-Tech contributions equal to `ap_income`'s literal decomposition, including the n=0 (base only) and Econ-Tech-with-0-outposts (0, not implied) cases (AC-8)
- [ ] GIVEN ≥1 vs 0 affordable structure types, THEN the Build button is enabled vs dimmed-but-present; activating it (either state) opens structure selection (AC-16)
- [ ] GIVEN the active player's Action phase from turn-start to End-Turn, THEN the AP counter, turn/round indicator, End Turn control, Build button, and action log are all continuously present regardless of selection/preview/actions taken (AC-24)
- [ ] GIVEN the opponent's turn, THEN Build and End Turn are visible but non-interactive (clicks/hotkeys no-op) while all readouts continue live (AC-18); GIVEN the `EndTurn(P)` transient, THEN both controls are likewise inert — no HUD commit accepted until the next local `PlayerTurn` (AC-27)

---

## Implementation Notes

*Derived from ADR-0016 §5/§8 + ADR-0006:*

- Action log: append-newest-on-top ring buffer sized `HUDConfig.action_log_length` (default 20), subscribing to `action_applied(result)` and appending **one entry per `result.events` element, in the events' append order** (ADR-0004's fixed resolution order) — deterministic because ordering is a property of `result.events`, not signal timing. Icon + short text per entry. The log itself is deliberately **silent** (the logged action already had its own commit sound).
- Income breakdown: on-demand popover (hover or click/press the AP counter; keyboard-toggleable) rendering `GameStateReader.income_breakdown(player)`'s pre-labeled fields (`base`, `outpost`, `econ_tech`) verbatim — never locally split/recompute. `HUDConfig.income_breakdown_default_expanded` sets initial state.
- Build button: reads `can_afford` across structure types via the facade, dimmed (never hidden) when none affordable; holds a pressed/active treatment while CAI's `PREVIEW_BUILD` state is live (subscribe outward-in, same direction as the detail-panel seam).
- Both interactive controls (Build, End Turn) + the income-breakdown toggle + action-log scroll follow ADR-0014's dual-focus conventions; `focus_mode = FOCUS_NONE` on inert controls (opponent turn, `EndTurn(P)` transient, `GameOver`) — do not hand-roll per-frame focus-ring suppression.
- Turn-scoped inertness: Build + End Turn are live only during the local Action phase; during opponent turn / `EndTurn(P)` transient / `GameOver` they render but are inert — closes the gap where CR-10's "Action phase" language leaves `EndTurn(P)` control-liveness undefined.
- The concrete keyboard-focus traversal order across the three IA zones is owed to a later `/ux-design` pass (OQ-5) — implement a reasonable default order and flag it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The AP counter itself — Stories 003/004
- Detail panel — Story 006
- Audio for log entries (deliberately none) or Build/completion cues — Story 008

---

## QA Test Cases

- **AC-14 (Logic)**: Given a commit resolving 2 events (kill + HQ-destroy), When the log updates, Then 2 new entries appear, newest-on-top, in the events' append order.
- **AC-15 (Logic)**: Given 25 commits with `action_log_length=20`, When the 21st commits, Then the oldest entry is dropped and 20 remain.
- **AC-8 (Logic)**: Given `income_breakdown(player)` stubbed to `{base:10, outpost:0, econ_tech:0}`, When the breakdown renders, Then it shows exactly those 3 values, never a phantom non-zero.
- **AC-16 (Integration)**: Given 0 affordable structure types, When the Build button is clicked, Then structure selection opens with all types shown disabled (never hidden).
- **AC-18/27 (Integration)**: Given the opponent's turn, When Build/End Turn are clicked or hotkeys pressed, Then no `apply_action` fires and no visual state changes.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/game-hud/action_log_income_breakdown_test.gd` (Logic) + `tests/integration/game-hud/build_endturn_turn_scoping_test.gd` (Integration, blocking) + advisory `production/qa/evidence/hud-chrome-layout-evidence.md` (UI layout)

**Status**: [x] Logic (5) + Integration (5) tests created and passing — all green (2026-07-28). [ ] Advisory UI layout / dual-focus sign-off OWED (`production/qa/evidence/hud-chrome-layout-evidence.md`, windowed session)

---

## Dependencies

- Depends on: Story 001 (`GameStateReader`), Story 002 (`HUDConfig.action_log_length`), and cross-epic **CAI's `PREVIEW_BUILD` state** (ADR-0015, shipped) for the Build-button pressed cue. Independent of Stories 003–006 (no shared files).
- Unlocks: None (feeds Story 008 only via the `action_applied` events it renders — no code dependency)

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: Blocking — AC-14 (log one-entry-per-event, append order, newest-on-top), AC-15 (ring-drop at action_log_length), AC-8 (income base/outpost/econ_tech verbatim, 0-outpost literal 0), AC-16 (Build affordable-vs-dimmed, activation opens selection either state), AC-18/27 (Build/End-Turn inert on opponent-turn/EndTurn-transient/GameOver: FOCUS_NONE + request-gate no-op) — all covered (5 Logic + 5 Integration tests). Advisory — AC-24 always-present chrome + dual-focus StyleBoxes + keyboard traversal order OWED (windowed sign-off).
**Deliverables**: `src/ui/game_hud/action_log_widget.gd` (ActionLogWidget — append-newest-on-top Array[Event] ring buffer, silent, deterministic per result.events order); `src/ui/game_hud/income_breakdown_widget.gd` (IncomeBreakdownWidget — income_breakdown(player) base/outpost/econ_tech verbatim, toggle popover); `src/ui/game_hud/hud_controls_widget.gd` (HudControlsWidget — controls_live/build_affordable/build_pressed_cue/controls_focus_mode + gated request_build/request_end_turn no-op when inert; duck-typed _cmd for PREVIEW_BUILD cue).
**Deviations**: None blocking.
- The actual Build/End-Turn Button chrome + dual-focus StyleBoxes are advisory UI (ADR-0014 dual-focus spike cleared); the widget models the testable state + activation gate. Keyboard-focus traversal order (OQ-5) owed to /ux-design (a reasonable FOCUS_ALL/FOCUS_NONE default implemented).
- PREVIEW_BUILD pressed cue via a duck-typed `_cmd.fsm_state()` seam (CAI has no public path to drive _fsm_state to PREVIEW_BUILD; stub-testable, mirrors the glyph layer's anchor-source seam).
- Review WARNING ADDRESSED: `_entries`/`entries()`/`entries_newest_first()` typed `Array[Event]` (was bare Array).
**Test Evidence**: Logic — `tests/unit/game-hud/action_log_income_breakdown_test.gd` (5, PASS). Integration (blocking) — `tests/integration/game-hud/build_endturn_turn_scoping_test.gd` (5, PASS). Full suite 775/775 green. Advisory UI — `production/qa/evidence/hud-chrome-layout-evidence.md` (sign-off OWED).
**Code Review**: APPROVED-WITH-SUGGESTIONS → suggestion addressed (independent godot-gdscript read-only pass + coordinator; ring-buffer/Pass-Through/turn-scoping/dual-focus/lifecycle/typing all confirmed).
