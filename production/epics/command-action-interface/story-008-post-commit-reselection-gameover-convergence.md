# Story 008: Post-Commit Re-Selection, Destroyed-Actor Collapse & GAME_OVER Convergence

> **Epic**: Command & Action Interface
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

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

**Status**: [x] Created & passing — `tests/integration/command-action-interface/post_commit_gameover_test.gd` (5/5 green)

---

## Dependencies

- Depends on: Story 001, Story 003, Story 007 (the `action_applied` subscription plumbing)
- Unlocks: None (terminal within this epic — Game HUD's victory/defeat overlay is a separate epic that also subscribes to `match_status`)

---

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: 5/5 ACs PASS. Full suite 704/704 — 0 failures, 0 orphans, 62/62 suites. ★ LAST in-slice CAI story — the Command & Action Interface epic is COMPLETE (8/8; cai-009 trimmed to Production).
**Implementation** (all Node-side on `command_interface.gd` — cai-001's pure `next_state` deliberately deferred these entity-aware refinements to here; NO `next_state`/`src/core` change): `_attached_state` (set by `attach_to_state`, so the shared handler can read `match_status`); `_on_action_applied` now converges on the absorbing `GAME_OVER` when `_attached_state.match_status == GAME_OVER` (AC-34/AC-35 — both instances observe the ONE shared signal); `commit()` does its own post-commit convergence directly from `state` (works without the subscription too): on a successful, non-terminal commit it calls `_reselect_after_commit` — a `BuildAction` lands on the newly-placed structure at `action.tile` (AC-33), every other verb re-selects `_selected_id`, staying ENTITY_SELECTED (menu re-filtered — AC-25's move→attack) iff the actor survives with a legal action, else auto-deselecting to IDLE (a destroyed actor, AC-32). `_enter_game_over` clears selection + overlays; `enter_preview` short-circuits in GAME_OVER; `_exit_tree` disconnects from `action_applied` (control-manifest lifecycle rule).
**Deviations**: None. The win-check logic itself is Combat/ADR-0010's (out of scope) — the GAME_OVER ACs drive the observation path this story owns (set `match_status` + emit `action_applied`).
**Test Evidence**: Integration — `tests/integration/command-action-interface/post_commit_gameover_test.gd` (5 test functions: AC-25 reselect+attack-enabled, AC-32 attacker-dies-to-counter→IDLE via the real Combat counter pipeline, AC-33 build→new-structure, AC-34 GameOver-terminal-and-inert, AC-35 two-instance convergence over one shared GameState).
**Code Review**: orchestrator implemented + verified directly (subtle multi-instance convergence + reselection edge cases). No `src/core` change; the pure `CommandFSM.next_state` table is untouched (its AC-32/AC-33 refinements are exactly what this Node-side story adds).
