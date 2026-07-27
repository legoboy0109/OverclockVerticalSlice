# Story 008: Post-Commit Re-Selection, Destroyed-Actor Collapse & GAME_OVER Convergence

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-015` (terminal-state completion — the GAME_OVER-convergence behavior the requirement names; the query/commit-routing half is owned by Story 003, so this story validates against AC-32/33/34/35)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Command & Action Interface FSM (primary)
**ADR Decision Summary**: After a commit the interface re-selects the acting entity (menu re-filtered) or collapses to IDLE if it was destroyed / was a Build; `GAME_OVER` is absorbing and both player instances converge on it via the same shared `action_applied` signal.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure state-transition + signal-observation logic; reuses Story 001's `next_state`/absorbing-`GAME_OVER` and Story 003/007's `action_applied` subscription.

**Control Manifest Rules (this layer)**:
- Required: `GAME_OVER` must be absorbing: `next_state()` returns `GAME_OVER` for every trigger once entered — source: ADR-0015
- Required: The Node must enter `GAME_OVER` the moment it observes `match_status == GameOver` in its `action_applied` handler — both player instances converge via the same shared signal, no polling — source: ADR-0015
- Required: If `GameState` is reused across a match restart within one process, `CommandInterface` must `disconnect` from `action_applied` in `_exit_tree()` — source: ADR-0015

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] GIVEN an attacker that commits an attack on a Defensive Structure and dies to its counterattack, THEN `apply_action` fully resolves (attack, counter, win-check) and the interface auto-deselects to IDLE — no dangling selection on the destroyed attacker (AC-32)
- [ ] GIVEN a Build commit on a legal tile, THEN the interface lands in ENTITY_SELECTED on the newly-placed structure (or IDLE if it has no legal action), never on a prior selection (AC-33)
- [ ] GIVEN a commit whose win-check sets `match_status = GameOver`, THEN the interface fully resolves the atomic `apply_action`, then transitions to the terminal `GAME_OVER` state — no selection, menu, preview, inspection, or End Turn accepted for the remainder of the session (AC-34)
- [ ] GIVEN the non-committing player's interface instance (inert during the opponent's Action phase) is active when the opponent's commit sets `match_status = GameOver`, THEN that instance also transitions to `GAME_OVER` upon observing the change — even though this instance's own commit did not trigger the win-check (AC-35)
- [ ] GIVEN a unit that just committed a move and retains AP ≥ attack_cost with a target in range, WHEN the menu re-filters, THEN Attack appears enabled (move→attack = two atomic commits, one fluid sequence) (AC-25)

---

## Implementation Notes

*Derived from ADR-0015 Implementation Guidelines:*

- Post-commit re-selection: after a commit the interface returns to ENTITY_SELECTED for the *same* entity with its menu re-filtered against remaining AP/`has_attacked`/cumulative movement.
- If the acting entity is destroyed by its own commit (dies to a counterattack), there is no actor to return to — resolve the full atomic `apply_action` then auto-deselect to IDLE. A Build commit is the mirror case (no source actor going in) — it lands on the newly-placed structure.
- `GAME_OVER` is absorbing: the Node enters it the moment it observes `match_status == GameOver` in its `action_applied` handler — whether or not this instance's own commit caused the win-check. Both players' `CommandInterface` instances subscribe to the same `GameState.action_applied` and read the same shared `match_status`, so the non-committing instance converges on `GAME_OVER` on the same signal that carries the `GameOverEvent`. No polling; no "who won" bookkeeping.
- Signal-connection lifecycle: if `GameState` is reused across a match restart within one process, `CommandInterface` must `disconnect` from `action_applied` in `_exit_tree()`. If each match constructs a fresh `GameState` (the likely path per ADR-0001), no explicit disconnect is needed — confirm which path this project takes before adding a disconnect that may be dead code.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Game HUD's victory/defeat overlay rendering — separate epic (this story is only FSM-side terminal convergence)
- The win-check logic itself (`run_win_check`) — owned by Combat/ADR-0010

---

## QA Test Cases

- **AC-32**: Given an attacker dies to a Defensive Structure's counterattack on its own committed attack, When `apply_action` resolves, Then the interface state is IDLE with no selection referencing the destroyed entity's id.
- **AC-33**: Given a Build commit on a legal tile, When it resolves, Then `ENTITY_SELECTED` holds the newly-placed structure's entity id, never the prior selection.
- **AC-34**: Given a commit's win-check sets `match_status = GameOver`, When the committing instance's handler runs, Then the FSM becomes `GAME_OVER` and every subsequent trigger (select, menu pick, End Turn) is rejected/no-ops.
- **AC-35**: Given the non-committing player's instance is inert (opponent's turn), When the opponent's commit sets `match_status = GameOver` and `action_applied` fires, Then this instance also transitions to `GAME_OVER` on the same signal, without ever having called `apply_action` itself. (Test fixture constructs **two** `CommandInterface`-equivalents over one shared `GameState`.)
- **AC-25**: Given a unit commits a move retaining `current_ap ≥ attack_cost` with a target in range, When the menu re-filters post-commit, Then Attack shows `enabled=true`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/command-action-interface/post_commit_gameover_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 003, Story 007 (the `action_applied` subscription plumbing)
- Unlocks: None (terminal within this epic — Game HUD's victory/defeat overlay is a separate epic that also subscribes to `match_status`)
