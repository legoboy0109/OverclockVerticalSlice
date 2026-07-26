# Story 002: Committed Move (`Movement.move()` / `MoveAction`)

> **Epic**: Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/movement-system.md`
**Requirement**: `TR-movement-005`, `TR-movement-013`, `TR-movement-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Reachable-search / pathfinding strategy
**Secondary ADRs**: ADR-0002 (apply_action command model — `MoveAction`/`validate()`/`apply()` verb-handler shape), ADR-0006 (`AP.can_afford`/`AP.spend` — sole AP deductor)
**ADR Decision Summary**: `move(unit, dest)` is validated and applied through the same `apply_action` verb-enum dispatch pipeline every other command uses. `validate()` checks the destination is in `reachable(state, unit)` and the cost is affordable; `apply()` spends AP, mutates grid occupancy, updates the unit's position, and increments `tiles_moved_this_turn` — all inside one atomic commit, using the exact same cost function `reachable()` used (Story 001's `_cost_for_depth`), so the previewed cost and the billed cost can never diverge.

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: No post-cutoff API. Follows the same `Action` subclass shape as `EndTurnAction` (`src/core/action/end_turn_action.gd`) — verb set in `_init()`, validator/applier registered on `GameState` via `register_verb`, never methods on the `Action` subclass itself.

**Control Manifest Rules (this layer)**:
- Required: "`Movement` must be a static utility class (`class_name Movement extends RefCounted`, no instance state); all entry points take `state` explicitly" — source: ADR-0009
- Required: "`reachable()`'s per-depth cost and `move()`'s billing must share the identical cost function" — source: ADR-0009
- Required: "Occupancy predicate for movement: friendly units may be passed through; structures (any owner) and enemy units are always hard blockers" — source: ADR-0009
- Forbidden: "Never add `reachable()`/`move_path_cost()` as instance methods on `GridState` or `GameState`" — source: ADR-0009
- Guardrail: "`reachable()` memory: one `PackedInt32Array` of size `width × height` per call, plus a small `Array[ReachableTile]` sized to result count" — source: ADR-0009 (applies indirectly — `validate()` calls `reachable()` internally)

---

## Acceptance Criteria

*From GDD `design/gdd/movement-system.md`, scoped to this story:*

- [ ] **GIVEN** a fresh Trooper (`move_cost` 2, `tiles_moved_this_turn` 0) with 5 AP, **WHEN** it moves a 2-tile path, **THEN** exactly 4 AP are spent (1 remains).
- [ ] **GIVEN** a separate fresh Trooper (`tiles_moved_this_turn` 0, `soft_move_cap` 3) with 5 AP, **WHEN** a 3-tile path is considered, **THEN** its cost is exactly 6 AP and it is not offered by `reachable()` **and** rejected by `move()` if attempted directly (fails `can_afford`).
- [ ] **GIVEN** a unit with AP remaining after a move, **WHEN** it moves again, **THEN** the second move is allowed and charged normally (AP-gated only, no separate per-turn move limit).
- [ ] **GIVEN** a Heavy (`move_cost` 3, `soft_move_cap` 2, `tiles_moved_this_turn` 0, `SOFT_MOVE_PENALTY` 2.0) with sufficient AP, **WHEN** it moves a 3-tile path, **THEN** the total cost is exactly 12 AP (2 in-cap tiles × 3 + 1 over-cap tile × `ceil(3×2.0)` = 6 + 6).
- [ ] **GIVEN** a Scout (`move_cost` 1, `soft_move_cap` 4, `SOFT_MOVE_PENALTY` 2.0, `tiles_moved_this_turn` 0), **WHEN** it moves 6 tiles as one `move()` call vs. two calls of 3+3 (a split that crosses the cap), **THEN** both charge exactly 8 AP — the cumulative counter prevents chunking from resetting the cheap budget.
- [ ] **GIVEN** a destination tile T returned by `reachable(unit)` at reported cost X — including at least one case where X reflects one or more over-cap tiles — **WHEN** `move(unit, T)` is executed, **THEN** the AP actually spent equals X exactly. This must hold on the authoritative state and any `clone()`.

---

## Implementation Notes

*Derived from ADR-0009 Key Interfaces and ADR-0002's verb-handler contract:*

- `static func move_path_cost(unit: UnitState, tiles_entered: int) -> int`: `return _cost_for_depth(unit, tiles_entered)` — the exact private helper Story 001's `reachable()` uses. Do not duplicate the summation; this call is the load-bearing part of the reachable-vs-billed agreement invariant.
- `static func validate(state: GameState, action: MoveAction) -> int`: pure, total, returns an `Action.Reason`-style enum value. Confirm the action's destination tile is present in `reachable(state, unit)` (reuse the search rather than re-deriving legality by hand) and that `AP.can_afford(state, unit.owner, cost)` holds for the reported cost. Return `Reason.OK` only when both hold.
- `static func apply(state: GameState, action: MoveAction) -> Array[Event]`: assumes validation passed, may not fail. Resolve the mover via `state.entity_at(action.from)`, compute `cost := move_path_cost(unit, action.tiles_entered)`, then in order: `AP.spend(state, unit.owner, cost)` (ADR-0006 — sole AP deductor), `state.grid.move(action.from, action.to)` (ADR-0005 — sole occupancy mutator), `unit.position = action.to`, `unit.tiles_moved_this_turn += action.tiles_entered`. Return `[UnitMovedEvent.new(unit.entity_id, action.from, action.to, cost)]`.
- `MoveAction extends Action`, mirroring `EndTurnAction`'s shape (`src/core/action/end_turn_action.gd`): `_init()` sets `verb = Action.Verb.MOVE` (extend the `Verb` enum on `Action`); carries `from: Vector2i`, `to: Vector2i`, `tiles_entered: int` (or the full path, if the path itself is needed for the move-feedback animation later — confirm at implementation whether `tiles_entered` alone suffices or the path array is needed downstream by Presentation; either is compatible with this story's cost/AP contract since cost is a pure function of *length*, not path identity, per the GDD's "same-length ⇒ same-cost" invariant).
- Register `validate`/`apply` via `GameState.register_verb(Action.Verb.MOVE, Movement.validate, Movement.apply)` — same pattern as the existing `_validate_end_turn`/`_apply_end_turn` registration in `game_state.gd`, but living as static methods on `Movement`, not on `GameState` (the forbidden-pattern list explicitly bars adding move logic as `GameState` instance methods).
- **tiles_entered accounting for split moves**: the AC's 6-tile-in-two-calls case is not special-cased — it falls out naturally because `_cost_for_depth` reads `unit.tiles_moved_this_turn` (already incremented by the first `move()` call) as its `m` term. No extra bookkeeping needed in this story beyond correctly incrementing the counter in `apply()`.

---

## Out of Scope

- Story 001: the `reachable()` search itself and its cost/surcharge model — this story only consumes it.
- Story 003: dedicated tie-break-determinism and no-stale-cache integration tests (this story's own ACs cover cost correctness, not path-identity or cache-freshness).
- Command & Action Interface epic: the move/step animation and input flow that constructs `MoveAction` from player input.

---

## QA Test Cases

- **AC-1 (in-cap billing)**: Given a fresh Trooper (move_cost 2) with 5 AP / When it moves a 2-tile path / Then exactly 4 AP is spent and 1 AP remains. Edge case: assert `AP.current_ap` reflects the deduction, not just the returned event's cost field.
- **AC-2 (unaffordable path rejected)**: Given a fresh Trooper (cap 3) with 5 AP considering a 3-tile path (cost 6) / When `move()` is invoked directly with that destination / Then it is rejected (`can_afford` fails) and no AP is spent, no position change occurs. Edge case: confirm the same destination is absent from `reachable()`'s result set (cross-check against Story 001, not re-derived here).
- **AC-3 (repeat move allowed)**: Given a unit with AP remaining after a first move / When a second `move()` is issued to a new reachable destination / Then it succeeds and is billed via the same `move_path_cost` formula, continuing from the updated `tiles_moved_this_turn`.
- **AC-4 (Heavy over-cap billing)**: Given a Heavy (move_cost 3, cap 2) with enough AP / When it moves a 3-tile path / Then exactly 12 AP is spent (6 in-cap + 6 over-cap). Edge case: assert the split is 2 base-cost tiles + 1 surcharged tile, not a uniform per-tile average.
- **AC-5 (split-move cumulative counter)**: Given a Scout (move_cost 1, cap 4) with `tiles_moved_this_turn` 0 / When run as (a) one `move()` of 6 tiles and (b) two `move()` calls of 3+3 from equivalent starting states / Then both total exactly 8 AP spent. Edge case: after the first 3-tile call in scenario (b), assert `tiles_moved_this_turn == 3` before the second call fires, proving the counter carries over rather than resetting.
- **AC-6 (reachable-vs-billed agreement)**: Given a destination T with reported `min_cost` X from `reachable()`, where X includes at least one over-cap tile / When `move(unit, T)` executes / Then the AP actually spent equals X exactly. Edge case: repeat on a `clone()`'d state to confirm the invariant holds identically post-clone, not just on the authoritative state.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/movement/move_action_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`Movement.reachable()`, `_cost_for_depth`), Foundation `apply_action`/`register_verb` pipeline (Game State & Turn Manager epic — Complete), `AP.can_afford`/`AP.spend` (AP Economy epic — Complete), `GridState.move()` (Grid & Terrain epic — Complete).
- Unlocks: Story 003 (integration tests exercise `move()` for the tie-break/no-stale-cache proofs); Combat Resolution epic (a unit may move then attack in the same turn); Command & Action Interface epic (constructs `MoveAction` from player input).
