# Story 004: Win-Check, GameOver & MAX_ROUNDS/Tiebreak Terminal Conditions

> **Epic**: Game State & Turn Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/game-state-turn-manager.md`
**Requirement**: `TR-gamestate-010`, `TR-gamestate-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Action / apply_action Command Model (win-check is pipeline step 6)
**ADR Decision Summary**: `run_win_check(state, events)` runs as step 6 of `apply_action`, after `apply()` — if a player's HQ reaches 0 hp, `match_status` becomes `GameOver(winner = opponent)`, synchronously, inside the same atomic step. Once `GameOver`, every subsequent action is rejected (step 1 lockout, built in Story 002).

**Secondary ADRs**:
- ADR-0001 (MAX_ROUNDS): `GameState` supports an optional `MAX_ROUNDS` cap + `TIEBREAK_METRIC` anti-drag terminal predicate; the tiebreak must be computable purely from state.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff. Pure integer/enum state logic.

**Control Manifest Rules (this layer)**:
- Required: "`GameState` must support an optional `MAX_ROUNDS` cap + `TIEBREAK_METRIC` anti-drag terminal predicate" — source: ADR-0001
- Required: "`apply_action`'s pipeline step 6 is `run_win_check`" — source: ADR-0002
- Required: "All state must be 100% integer; fractional coefficients as scaled ints" — source: ADR-0003 (tiebreak metrics computed in integer arithmetic)
- Required: "Any order-sensitive pass over `entities_by_id` must iterate a stable-key-sorted list (`entity_id`), never Dictionary hash order" — source: ADR-0003 (win-check / tiebreak entity scans)
- Guardrail: "`run_win_check` runs once per committed action; O(entity count) HQ scan — negligible for turn-based play" — source: ADR-0002

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-turn-manager.md`, scoped to this story:*

- [ ] **GIVEN** an HQ reaches 0 hp, **WHEN** the win-check runs (pipeline step 6), **THEN** `match_status` becomes `GameOver(winner = opponent)` synchronously, and any subsequent `apply_action` is rejected (`GAME_OVER`).
- [ ] **GIVEN** a win-condition is met mid-turn, **WHEN** `GameOver` is set, **THEN** it happens immediately in the same resolution step — remaining AP and queued actions are ignored; no further input accepted.
- [ ] **GIVEN** two HQs would be destroyed in the same resolution step (future AoE), **WHEN** the win-check resolves, **THEN** the **non-active** player wins (an attacker cannot win by an action that also destroys their own HQ) — documented deterministic rule, no undefined draw.
- [ ] **GIVEN** `MAX_ROUNDS` is set and reached with no HQ destroyed, **WHEN** the cap is hit, **THEN** the `TIEBREAK_METRIC` decides the winner and `match_status` → `GameOver`; the tiebreak is computed purely from state.
- [ ] **GIVEN** `MAX_ROUNDS` is unset (VS default), **WHEN** rounds advance, **THEN** no round-cap terminal ever triggers (the cap is opt-in).

---

## Implementation Notes

*Derived from ADR-0002 (win-check) + ADR-0001 (MAX_ROUNDS):*

- `run_win_check(state, events)` scans for any HQ structure at 0 hp (or consumes an `hq_destroyed`/`GameOverEvent` signal already present in `events` — prefer reacting to the events the mutating `apply()` appended over re-scanning, per ADR-0004's event-order-is-resolution-order rule). On detection, set `match_status = MatchStatus.GAME_OVER` and record the winner (opponent of the destroyed HQ's owner).
- **Simultaneous-HQ rule**: if both HQs are destroyed in one step, the **non-active player** wins. Implement as an explicit deterministic branch, not incidental ordering.
- This story **replaces** the minimal/no-op `run_win_check` that Story 002 left as a pipeline call site — do not add a second call site; fill in the existing step-6 hook.
- **Post-GameOver lockout** (pipeline step 1) already rejects actions once `match_status == GameOver` — that gate is Story 002; this story provides what *sets* `GameOver`. Add a test that the two compose (win-check sets GameOver → next `apply_action` returns `GAME_OVER`).
- **MAX_ROUNDS/tiebreak**: add optional `max_rounds` + `tiebreak_metric` config (off by default). Evaluate the round-cap terminal predicate at the round boundary established by Story 003 (`EndTurnAction.apply` after `round_number` increments). `TIEBREAK_METRIC` options: total HQ hp / tiles controlled / unit count — compute purely from `GameState` in integer arithmetic. On cap reached with no HQ destroyed, set `GameOver` with the tiebreak winner.
- **⚠️ Cross-epic forward-declared seam:** HQ-hp detection and "is this entity an HQ" depend on the entity stat schema (ADR-0007 — `StructureState` with `hp`, HQ type identity), not yet built. For this story, the win-check operates on whatever HQ/hp representation the entity schema provides; until it exists, implement against the `EntityState` base + test doubles that stand in for an HQ-at-0-hp, and wire to the real schema when it lands. Surface at `/story-readiness`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the pipeline itself, the GameOver-lockout *gate* (step 1), the `Event` base (this story may add a `GameOverEvent` subclass if not already present).
- Story 003: `start_turn`, `EndTurnAction.apply`, round increment (this story reads `round_number` for the MAX_ROUNDS check but does not own the increment).
- The entity stat schema (ADR-0007) that defines HQ hp / structure types — a later epic; this story consumes it via forward-declared contract.

---

## QA Test Cases

**Test file**: `tests/unit/win_check_terminal_test.gd` (~8 unit tests)
**Requires shared fixtures**: HQ-at-0-hp test double — see
`production/qa/qa-plan-sprint-1-2026-07-26.md` "Shared Test Fixtures Required".

- HQ reaches 0 hp → `run_win_check` (pipeline step 6) sets `match_status = GameOver(winner =
  opponent)` synchronously; a subsequent `apply_action` is rejected `GAME_OVER`.
- Win condition met mid-turn → GameOver set immediately in the same resolution step; remaining AP
  and any queued actions are ignored.
- Simultaneous double-HQ-destruction (test-only scenario; no real trigger exists in VS combat yet)
  → **non-active player wins** (explicit deterministic branch, not incidental ordering).
- `MAX_ROUNDS` set and reached with no HQ destroyed → `TIEBREAK_METRIC` decides the winner,
  `match_status → GameOver`, computed purely from state.
- `MAX_ROUNDS` unset (VS default) → no round-cap terminal ever triggers.
- **Composition test**: win-check sets GameOver → the very next `apply_action` call returns
  `GAME_OVER` (Story 002's step-1 gate + this story's step-6 setter working together).

⚠️ **Gap flagged during QA planning (unresolved by the GDD) — resolve with game-designer before
writing these two edge cases, do not silently invent a rule:**
- Tiebreak-vs-HQ-destruction precedence: `MAX_ROUNDS` reached the exact round the second HQ would
  also be destroyed — which terminal condition wins?
- Tied-tiebreak-metric: `TIEBREAK_METRIC` computed from a state with equal metrics for both
  players — no resolution specified.

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/win_check_terminal_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (pipeline step 6 call site + step 1 lockout), Story 003 (round increment for the MAX_ROUNDS boundary) must be DONE. **Soft cross-epic dependency**: entity stat schema (ADR-0007) for HQ-hp detection, or test doubles. See the cross-epic seam note above.
- Unlocks: None (last story in this epic)
