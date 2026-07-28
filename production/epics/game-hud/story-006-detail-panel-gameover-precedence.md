# Story 006: Detail Panel (Selection/Inspection Seam) + Victory/Defeat One-Frame Preemption

> **Epic**: Game HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-013`, `TR-hud-016`, `TR-hud-004` (always-present chrome tie-in), `TR-hud-017` (turn-scoped inert controls tie-in for the GameOver freeze)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §6/§8)
**ADR Decision Summary**: The HUD owns the detail panel and subscribes outward-in to CAI's `selection_changed` (CAI never calls in); on `match_status = GameOver(winner)` the victory/defeat overlay appears within one frame, truncating any in-flight/pending turn banner.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Reactive `Control` subscribing outward-in to a signal; no new engine surface. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: The detail panel's data-flow must be outward-in: the HUD subscribes to `CommandInterface.selection_changed` — `CommandInterface` must never call into a HUD-owned node — source: ADR-0016
- Required: On `match_status = GameOver(winner)` the victory/defeat overlay must appear within one frame, truncating any in-flight or pending turn banner — source: ADR-0016
- Guardrail: The killing commit's hp-pip drain plays unclipped, non-gating (coordinate with Story 005) — source: ADR-0016

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN #9 selects entity E / nothing selected / E destroyed while shown, THEN the detail panel shows E's stats / is empty / clears, respectively (AC-13)
- [ ] The panel carries a distinct visual state for pinned (selected, persistent) vs peek (inspecting, transient) — solid accent edge vs dashed/dimmed edge, distinguishable by more than content alone (CR-6, Accessibility E)
- [ ] GIVEN `match_status = GameOver(winner)`, THEN a victory/defeat screen naming the winner shows; GIVEN a turn transition coincides (incl. a banner already mid-flight), THEN the victory/defeat presentation appears within one frame of the `GameOver` transition and no turn banner shows/persists (AC-17)
- [ ] GIVEN the same commit that triggers `GameOver` was mid AP-tick-down, THEN the AP counter is snapped to its final post-spend value within that one-frame bound, while the killing commit's hp-pip drain still plays (AC-17, cross-references Story 003/005)
- [ ] The panel's data-flow is outward-in only: the HUD subscribes to `CommandInterface.selection_changed` — CAI never calls into a HUD-owned node (structural leaf-claim check)

---

## Implementation Notes

*Derived from ADR-0016 §6/§8:*

- Detail panel: HUD **owns** the panel `Control` scene + theme; content follows CAI's `selection_changed(target: SelectionTarget)` signal (`{entity_id: int, pinned: bool}`) — subscribe, never let CAI call in. Empty/hidden when nothing is selected. Clears when the shown entity is destroyed (its selection is cleared upstream).
- Pinned vs peek: distinct edge treatment (solid vs dashed/dimmed), not content-alone — protects against faction-hue-accent being the only differentiator.
- Victory/defeat: on `match_status = GameOver(winner)`, the overlay appears within one frame, **truncating any in-flight or pending turn banner** — the cross-cutting `GameOver` transition that also snaps Story 003's `ApCounterFsm` to `COMMITTED`+final-value. Coordinate with Stories 003/004 (same transition) and Story 005 (killing commit's hp-pip drain plays unclipped).
- If `MAX_ROUNDS` is enabled and reached (off in VS), the presentation reflects `TIEBREAK_METRIC` — this is AC-22, explicitly a backlog stub with zero active coverage; do NOT treat CR-9 as fully verified while `MAX_ROUNDS` is off (state this in Definition-of-Done language).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `MAX_ROUNDS`/`TIEBREAK_METRIC` presentation logic (AC-22, backlog — activate when `MAX_ROUNDS` ships)
- The audio victory/defeat *cue* — Story 008 owns `play()`
- Build/End Turn control inertness during `GameOver` — Story 007 owns the controls

---

## QA Test Cases

- **AC-13 (Integration)**: Given CAI emits `selection_changed({entity_id: 5, pinned: true})`, When received, Then the panel renders entity 5's stats with the pinned (solid-edge) treatment. Edge cases: `pinned: false` → dashed/dimmed, same content.
- **AC-13 (destroyed)**: Given the panel shows entity E and E is destroyed (its `action_applied` event fires), When the frame updates, Then the panel clears (empty, not stale).
- **AC-17 (banner preemption)**: Given a turn banner mid-flight (200ms of 1000ms elapsed) and a `GameOver`-triggering commit lands, When it resolves, Then the victory/defeat overlay is visible within one frame and the banner is not visible in any subsequent frame.
- **AC-17 (tick snap)**: Given the killing commit was mid-AP-tick (9→3), When `GameOver` resolves, Then the AP counter displays 3 within the same one-frame bound, not a frozen intermediate (6).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/game-hud/detail_panel_gameover_precedence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`GameStateReader` ✅ Complete), and cross-epic **CAI's `CommandInterface.selection_changed(target)` signal** (ADR-0016 §6, owed back to ADR-0015). ✅ **RESOLVED 2026-07-28**: the signal is now implemented in the CAI epic (cross-epic addendum). `CommandInterface` emits `selection_changed(SelectionTarget{entity_id, pinned})` — pinned on select/switch/reselect/game-over-clear, peek via `inspect(state, tile)` — de-duplicated and one-way outward-in (CAI never calls into a HUD node). Type: `src/ui/command_action_interface/selection_target.gd`; tests: `tests/unit/command-action-interface/selection_changed_test.gd` (9, pass). This story is no longer blocked.
- Unlocks: Story 008 (audio `GameOver` cue hooks off the same transition this story renders)
