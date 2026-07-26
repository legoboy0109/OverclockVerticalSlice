# Story 003: Turn FSM — start_match, start_turn 4-Step Sequence, EndTurnAction & Round Increment

> **Epic**: Game State & Turn Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/game-state-turn-manager.md`
**Requirement**: `TR-gamestate-006`, `TR-gamestate-007`, `TR-gamestate-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Shared Start-of-Turn Sequencing
**ADR Decision Summary**: `GameState.start_turn(player) -> Array[Event]` is a `GameState`-owned instance method running the canonical 4-step sequence in this exact order: (1) set active player, (2) reset per-turn flags for that player's entities, (3) advance build + research timers (completing structures/techs), (4) `AP.reset_turn()` income snapshot. `start_turn()` is called in exactly two places: `start_match()` (starting player) and `EndTurnAction.apply()` (next player). `EndTurnAction.apply()` discards outgoing AP, determines next player, increments `round_number` only if next == starting_player, then calls `start_turn(next)`.

**Secondary ADRs**:
- ADR-0002: `EndTurnAction` is dispatched through `apply_action` step 5 (its `apply()` is implemented here; its `validate()` = unconditionally-OK came in Story 002).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Instance-method dispatch is identical whether `GameState` came from `.new()` or `duplicate_deep()`; `duplicate_deep()` copies a field's value at call time (no lazy snapshot). No post-cutoff API risk in this story.

**Control Manifest Rules (this layer)**:
- Required: "`GameState.start_turn(player: int) -> Array[Event]` must be a `GameState`-owned instance method running the canonical 4-step sequence in this exact order: (1) set active player, (2) reset per-turn flags for that player's entities, (3) advance build + research timers, (4) `AP.reset_turn()` income snapshot" — source: ADR-0008
- Required: "Steps 2 and 3 must both complete before step 4's income snapshot; the two timer-advance calls WITHIN step 3 (build vs research) are order-independent and must stay commutative" — source: ADR-0008
- Required: "`start_turn()` must be called in exactly two places: `start_match()` for the starting player, and `EndTurnAction.apply()` for the next player" — source: ADR-0008
- Required: "`EndTurnAction.apply()` must, in order: discard the outgoing player's AP, determine next player, increment `round_number` only if `next_player == starting_player`, then call `start_turn(next_player)`" — source: ADR-0008
- Required: "`GameState` gains a `starting_player: int` field, set once by `start_match()`, never mutated after" — source: ADR-0008
- Required: "Per-turn flag resets must be attributed to owning systems (`Unit.reset_turn_flags`, `Structure.reset_turn_flags`) — `GameState` owns only the timing" — source: ADR-0008
- Required: "New `Event` subclasses (`StructureCompletedEvent`, `TechCompletedEvent`) must flow through the existing `action_applied` signal — no new signal or polling path" — source: ADR-0008
- Required: "`end_turn()` must be unconditionally legal for the active player — no softlock" — source: ADR-0001, ADR-0002
- Forbidden: "Never split turn-orchestration into a separate static `TurnManager` utility class" — source: ADR-0008
- Forbidden: "Never inline per-turn flag resets directly in `GameState.start_turn()`" — source: ADR-0008
- Forbidden: "Never reorder start_turn step 4 before step 3" — source: ADR-0008 (income snapshot must observe structures/techs completed this same turn)
- Forbidden: "Never use silent state transitions with no completion events (polling/diffing)" — source: ADR-0008

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-turn-manager.md`, scoped to this story:*

- [ ] **GIVEN** a new match, **WHEN** `start_match(map, starting_player)` runs, **THEN** `active_player` = starting player, `round_number` = 1, `match_status` = in-progress, and the starting player's AP = their income (start-of-turn ran once, no round increment).
- [ ] **GIVEN** the active player ends their turn, **WHEN** `EndTurnAction` resolves, **THEN** their unspent AP is discarded, `active_player` switches to the opponent, and the opponent's AP is reset to income.
- [ ] **GIVEN** both players have taken a turn in a round, **WHEN** the second player's turn ends (control returns to the starting player), **THEN** `round_number` increments by exactly 1 — and only then.
- [ ] **GIVEN** the canonical start-of-turn sequence, **WHEN** it runs, **THEN** steps execute in order 1→2→3→4, and the step-4 AP income snapshot observes structures/techs completed in step 3 this same turn (step 4 never precedes step 3).
- [ ] **GIVEN** the active player has zero legal actions at start of turn, **WHEN** the turn begins, **THEN** they can still `end_turn()` (no softlock; `EndTurnAction` unconditionally legal).

---

## Implementation Notes

*Derived from ADR-0008 Key Interfaces:*

```gdscript
# On GameState (adds to Story 001's class):
@export var starting_player: int = 0     # set once by start_match(), never mutated after

func start_turn(player: int) -> Array:   # Array[Event]; the canonical 4-step sequence
    active_player = player                                   # 1
    for e in entities():                                     # 2 — stable entity_id order
        if e.owner != player: continue
        if e is UnitState:        Unit.reset_turn_flags(e)
        elif e is StructureState: Structure.reset_turn_flags(e)
    var events: Array = []                                   # 3
    events.append_array(BaseProduction.advance_build_timers(self, player))
    events.append_array(Research.advance_research_timers(self, player))
    AP.reset_turn(self, player)                              # 4 — income snapshot AFTER step 3
    return events

static func start_match(map: MapDefinition, starting_player: int) -> GameState:
    var state := GameState.new()
    # ... grid/entity construction (ADR-0001/0005) ...
    state.starting_player = starting_player
    state.round_number = 1
    state.start_turn(starting_player)                        # first start-of-turn; NO round increment
    return state

# end_turn_action.gd — EndTurnAction.apply() (the verb handler apply_action dispatches to):
static func apply(state: GameState, action: Action) -> Array:   # assumes validated
    var outgoing: int = state.active_player
    AP.discard(state, outgoing)
    var next_player: int = 1 - outgoing                     # 2-player VS strict alternation
    if next_player == state.starting_player:
        state.round_number += 1                             # Rule 4
    return state.start_turn(next_player)
```

- **⚠️ Cross-epic forward-declared seam (read before implementing):** step 3 (`BaseProduction.advance_build_timers`, `Research.advance_research_timers`), step 2 (`Unit.reset_turn_flags`, `Structure.reset_turn_flags`), and step 4 (`AP.reset_turn`, `AP.discard`) reference classes/functions owned by systems **not yet built** (AP Economy / ADR-0006, Base & Production, Research, Unit System). Per ADR-0008 these are deliberately forward-declared contracts. In GDScript a static call to a not-yet-defined `class_name` will not parse — so this story is **implementation-blocked until at least the `AP` class (AP Economy epic / ADR-0006) exists**, and the build/research/flag calls need either their owning systems present or test-double stubs injected. **Options for the implementer:** (a) implement the AP Economy epic first (recommended — it is the other Foundation dependency and provides `AP.reset_turn`/`AP.discard`); (b) implement `start_turn`/`EndTurnAction.apply` against thin stubs for the not-yet-present systems and swap them for real calls as each lands (differential-test the swap). Surface this at `/story-readiness` — do not silently invent the missing systems.
- **Carry-forward W2 (from Grid epic):** `MapDefinition.build_grid` currently places HQs with placeholder entity ids `0`/`1`. `start_match`'s entity construction is the correct home for real `next_entity_id`-allocated HQ placement — resolve W2 here by having `start_match` (not `build_grid`) place HQs with ids drawn from `GameState.next_entity_id`, or reconcile the two so ids never collide. See Grid Story 003/004 Completion Notes.
- The two timer-advance calls in step 3 must stay commutative (order between build vs research must not matter). Steps 2 and 3 must both finish before step 4's snapshot.
- `StructureCompletedEvent`/`TechCompletedEvent` are appended by the step-3 advances and flow through the existing `action_applied` signal (Story 002) — no new signal.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the `apply_action` pipeline, `EndTurnAction` class + `validate()`, `action_applied` signal, `Event` base (this story adds `EndTurnAction.apply()` + the two completion-event subclasses).
- Story 004: `run_win_check`, `MAX_ROUNDS`/`TIEBREAK_METRIC` (the round cap is checked at the round boundary this story establishes, but the terminal logic is Story 004).
- The actual `AP`/`BaseProduction`/`Research`/`Unit` implementations (their own epics) — this story only calls their forward-declared contracts.

---

## QA Test Cases

**Test file**: `tests/unit/turn_sequencing_test.gd` (~9 unit tests)
**Requires shared fixtures**: `BaseProduction`/`Research` stubs — see
`production/qa/qa-plan-sprint-1-2026-07-26.md` "Shared Test Fixtures Required". These must be
defined **once** under `tests/helpers/stubs/` and reused, not redeclared per test file
(`class_name` is project-global — a second declaration collides).

- `start_match(map, starting_player)` → `active_player` = starting player, `round_number` = 1,
  `match_status` = in-progress, starting player's AP = their income (one start-of-turn run, no
  round increment).
- `EndTurnAction` resolution → outgoing player's unspent AP discarded, `active_player` switches,
  opponent's AP reset to income.
- Round increment fires **only** when control returns to the starting player (test both: first
  mover ending turn → no increment; second mover ending turn → `round_number += 1` exactly once).
- Step order 1→2→3→4: step 4's AP income snapshot observes a structure/tech completed in step 3
  the same turn (complete an outpost via the stub mid-step-3, assert income reflects it).
- Steps 2 and 3 are commutative internally (build-timer vs research-timer order doesn't matter)
  but both must complete before step 4.
- Zero-legal-actions player can still call `end_turn()` (no softlock).
- **Carry-forward W2**: `start_match`'s entity construction allocates HQ ids from
  `GameState.next_entity_id` (not the Grid epic's placeholder `0`/`1`) — regression test that HQ
  ids never collide with subsequently-created entities.

Edge cases: `starting_player` set once by `start_match`, never mutated afterward;
`StructureCompletedEvent`/`TechCompletedEvent` flow through the existing `action_applied` signal,
not a new one.

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/turn_sequencing_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002 must be DONE. **Soft cross-epic dependency**: AP Economy epic (ADR-0006 `AP` class) for `AP.reset_turn`/`AP.discard`; Base & Production / Research / Unit System for their forward-declared start-of-turn contracts (or test stubs). See the cross-epic seam note above.
- Unlocks: Story 004
