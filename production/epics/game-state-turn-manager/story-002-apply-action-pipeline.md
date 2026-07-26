# Story 002: Action Command Model, apply_action Pipeline & Event Signal

> **Epic**: Game State & Turn Manager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/game-state-turn-manager.md`
**Requirement**: `TR-gamestate-004`, `TR-gamestate-005`, `TR-gamestate-008`, `TR-gamestate-009`, `TR-gamestate-012`, `TR-gamestate-014`, `TR-gamestate-018`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Action / apply_action Command Model
**ADR Decision Summary**: `apply_action(action) -> ActionResult` is the sole mutation vector. Each verb is a typed `Action` subclass (own top-level file, `class_name`, sets `verb` in `_init()`). Dispatch is by the `verb` enum via a `Dictionary[int, Callable]` built once — never `get_class()`. `apply_action` is a thin 7-step orchestrator; each verb's rules live in the owning system as pure `validate(state, action) -> int` and `apply(state, action) -> Array[Event]`. Atomicity by validate-before-mutate, no rollback. Uniform `ActionResult`. Idempotency by stateless re-validation.

**Secondary ADRs**:
- ADR-0004 (Event/signal): `GameState` declares and emits its own single `signal action_applied(result: ActionResult)` — no EventBus autoload; emitted exactly once, synchronously, at pipeline end, only when `result.ok == true`. `Event` is a top-level `class_name Event extends RefCounted`; append order = resolution order; subscribers must never mutate state from the handler.
- ADR-0001 (faction lock): faction (and `is_ai_controlled`) is Setup-locked — `apply_action` rejects re-assignment after Setup→PlayerTurn.
- ADR-0003 (determinism): identical state + ordered actions → byte-identical result; no RNG; stable iteration.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `get_class()` on a GDScript-defined class returns the base engine class name (e.g. `"RefCounted"`), NOT the script's `class_name` — so `match action.get_class()` silently never matches; use the `verb` enum + `Dictionary[int, Callable]`. Covariant `Array[Event]` holding subclass instances is supported in 4.6. A cloned `Resource` carries zero signal connections (no `DUPLICATE_SIGNALS` opt-in) — fine, since `Action` objects are transient `RefCounted`, not part of cloned state.

**Control Manifest Rules (this layer)**:
- Required: "`apply_action(action) -> ActionResult` is the sole mutation vector for `GameState`" — source: ADR-0001, ADR-0002
- Required: "Each `Action` must be a typed subclass, one per verb, in its own top-level file with `class_name` (never a nested inner class), setting `verb: Verb` in `_init()`" — source: ADR-0002
- Required: "Dispatch must be by the `verb` enum via a `Dictionary[int, Callable]` built once — never by runtime type inspection" — source: ADR-0002
- Required: "`apply_action` must be a thin orchestrator; each verb's rules live in the owning Core system as pure `validate(state, action) -> int` and `apply(state, action) -> Array[Event]`" — source: ADR-0002
- Required: "`validate()` must be pure and total; `apply()` must assume validation passed and never return failure" — source: ADR-0002
- Required: "Atomicity must be achieved via validate-before-mutate with no rollback" — source: ADR-0002
- Required: "`apply_action` must return a uniform `ActionResult` `{ok, reason, events}` for every verb" — source: ADR-0002
- Required: "Idempotency must be handled via stateless re-validation — no dedup IDs, no seen-set" — source: ADR-0002
- Required: "`EndTurnAction` must be exempt from all affordability/legality checks — unconditionally legal for the active player" — source: ADR-0002
- Required: "`apply_action`'s fixed 7-step pipeline must run in order: (1) GameOver gate, (2) active-player gate, (3) validate, (4) reject if not OK, (5) apply, (6) run_win_check, (7) return ActionResult" — source: ADR-0002
- Required: "`validate()`'s return type must stay `-> int` (a Reason code) — do not 'fix' it to a `Reason` object" — source: ADR-0002
- Required: "`GameState` must declare and emit its own signal directly: `signal action_applied(result: ActionResult)` — no separate Event-bus Autoload" — source: ADR-0004
- Required: "`action_applied` must be emitted exactly once, synchronously, at the end of `apply_action`'s pipeline, and only when `result.ok == true`" — source: ADR-0004
- Required: "`Event` must be a top-level `class_name Event extends RefCounted`; append to `events` in the order effects happened" — source: ADR-0004
- Required: "`PlayerState.faction` / `is_ai_controlled` must be Setup-locked, immutable after Setup→PlayerTurn" — source: ADR-0001, ADR-0011, ADR-0012
- Forbidden: "Never dispatch a verb via `Object.get_class()`" — source: ADR-0002
- Forbidden: "Never use snapshot-and-rollback for atomicity" — source: ADR-0002
- Forbidden: "Never embed `validate()`/`apply()` methods directly on `Action` subclasses (command pattern)" — source: ADR-0002
- Forbidden: "Never represent an Action as a tagged Dictionary `{verb, params}`" — source: ADR-0002
- Forbidden: "Never give each verb its own Result subtype" — source: ADR-0002
- Forbidden: "Never mutate state inside `validate()`, or check a precondition only in `apply()`" — source: ADR-0002
- Forbidden: "Never route `action_applied` through a dedicated `EventBus` Autoload" — source: ADR-0004
- Forbidden: "Never emit `action_applied` unconditionally with subscribers filtering on `result.ok`" — source: ADR-0004
- Forbidden: "A subscriber must never mutate state from inside its `action_applied` handler" — source: ADR-0004

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-turn-manager.md`, scoped to this story:*

- [ ] **GIVEN** an action costing more AP than the active player has, **WHEN** `apply_action` is called, **THEN** it returns `ok=false` with a reason and the state (AP + entities) is unchanged.
- [ ] **GIVEN** an illegal action (wrong active player, illegal target), **WHEN** `apply_action` is called, **THEN** it is rejected with zero state change (validate-before-mutate atomicity).
- [ ] **GIVEN** the same initial state and the same ordered action sequence, **WHEN** applied in two separate runs, **THEN** the two resulting states are identical (determinism; no RNG, no float-driven nondeterminism).
- [ ] **GIVEN** an action already applied, **WHEN** the identical action is submitted again, **THEN** it is re-validated against current state and rejected — no double-apply (idempotency-by-revalidation).
- [ ] **GIVEN** a successful `apply_action`, **WHEN** the pipeline completes, **THEN** `action_applied(result)` is emitted exactly once, synchronously, carrying the `events`; **AND GIVEN** a rejected action, **THEN** `action_applied` is NOT emitted.
- [ ] **GIVEN** a verb dispatch, **WHEN** `apply_action` routes it, **THEN** it dispatches via the `verb` enum through the `Dictionary[int, Callable]` table (never `get_class()`).
- [ ] **GIVEN** faction (or `is_ai_controlled`) is set at Setup, **WHEN** an action attempts to re-assign it after Setup→PlayerTurn, **THEN** `apply_action` rejects it (`FACTION_LOCKED`).

---

## Implementation Notes

*Derived from ADR-0002 Decision + Key Interfaces:*

```gdscript
# action.gd — class_name Action extends RefCounted (transient; NOT part of cloned state)
enum Verb { MOVE, ATTACK, BUILD, PRODUCE, RESEARCH, CANCEL_BUILD, END_TURN }
var verb: int      # set in each subclass _init()
var player: int    # validated == active_player

# end_turn_action.gd — class_name EndTurnAction extends Action; func _init(): verb = Verb.END_TURN
#   validate() is unconditionally OK for the active player (apply() is Story 003).

enum Reason { OK, NOT_ACTIVE_PLAYER, CANT_AFFORD, ILLEGAL_TARGET, OUT_OF_RANGE,
              TILE_OCCUPIED, NOT_LEGAL_BUILD_TILE, PRODUCTION_CAP_REACHED,
              GAME_OVER, FACTION_LOCKED, NO_SUCH_ENTITY }

class ActionResult extends RefCounted:
    var ok: bool
    var reason: int          # Reason enum (typed int)
    var events: Array        # Array[Event]; consumers use `if e is DamageEvent:` not match

# On GameState:
func apply_action(action: Action) -> ActionResult
signal action_applied(result: ActionResult)
# event.gd — class_name Event extends RefCounted (base; owning systems define subclasses)
```

**The fixed 7-step pipeline (verbatim order):**
```
apply_action(action):
    1. if match_status == GameOver:        return fail(GAME_OVER)
    2. if action.player != active_player:  return fail(NOT_ACTIVE_PLAYER)   # EndTurnAction: active player only
    3. reason = _validators[action.verb].call(state, action)  # PURE, total
    4. if reason != OK:                    return fail(reason)              # ATOMIC: nothing mutated
    5. events = _appliers[action.verb].call(state, action)    # mutates; may not fail
    6. run_win_check(state, events)        # Story 004 owns the logic; call site is here
    7. emit action_applied(ok(events)); return ok(events)     # emit only on ok (ADR-0004)
```

- Build `_validators`/`_appliers` as `Dictionary[int, Callable]` keyed by `Verb`, populated once. For this story only `EndTurnAction`'s handlers are provided by this epic (validate = OK; apply = Story 003). Other verbs' handlers are **forward-declared** — registered by their own systems (Movement/Combat/Base&Production/Research epics) when those land. The dispatch table + registration mechanism is what this story builds; it does not implement other verbs' rules.
- **Handler invariant**: `validate()` is pure and total (checks ALL failure conditions incl. `AP.can_afford`); `apply()` assumes validation passed and cannot fail. No rollback exists because nothing mutates before step 4 passes.
- **run_win_check** (step 6): call site only here; the logic (HQ-at-0 → GameOver) is Story 004. For this story, `run_win_check` may be a minimal no-op/pass-through so the pipeline is testable — Story 004 replaces it with the full check. Do not duplicate the logic.
- Faction lock: enforce in the pipeline (or a Setup→PlayerTurn transition gate) — once the match has left Setup, an action re-assigning `faction`/`is_ai_controlled` returns `FACTION_LOCKED`. Same gate locks both fields.
- Determinism: no RNG anywhere in the pipeline; iterate entities in `entity_id` order for any order-sensitive pass.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `GameState` class, fields, read API, `clone()` (this story builds on them).
- Story 003: `EndTurnAction.apply()` end-of-turn logic, `start_turn`, `start_match`, round increment.
- Story 004: `run_win_check` logic, GameOver-setting, `MAX_ROUNDS`/tiebreak (step 1's GameOver *gate* is here; what *sets* GameOver is Story 004).
- The concrete verb handlers for MOVE/ATTACK/BUILD/PRODUCE/RESEARCH/CANCEL_BUILD — owned by their respective Core epics; this story provides only the dispatch/registration mechanism + `EndTurnAction`.

---

## QA Test Cases

**Test file**: `tests/unit/apply_action_pipeline_test.gd` (~11 unit tests)

- Insufficient-AP action → `ok=false` + reason, AP and entities unchanged.
- Illegal action (wrong active player / illegal target) → rejected, zero state change.
- Determinism: same initial state + same ordered action sequence, two separate runs → identical
  resulting states.
- Idempotency-by-revalidation: submit an already-applied action again → re-validated against
  current state, rejected, no double-apply.
- `action_applied(result)` emitted exactly once, synchronously, on success, carrying `events`;
  NOT emitted on rejection.
- Dispatch via the `verb` enum through `Dictionary[int, Callable]` — regression guard that
  dispatch never relies on `get_class()` (which returns `"RefCounted"`, not the `class_name`).
- Faction lock: after Setup→PlayerTurn, an action re-assigning `faction`/`is_ai_controlled`
  → rejected `FACTION_LOCKED`.
- `EndTurnAction` is unconditionally legal for the active player (no affordability/legality gate).
- Full 7-step pipeline order test (GameOver gate → active-player gate → validate → reject-if-not-OK
  → apply → run_win_check → emit).

Edge cases: `EndTurnAction` with zero other legal actions available; action submitted after
`match_status == GameOver` (manually-constructed GameOver state) → rejected `GAME_OVER` (step 1
gate — full GameOver-setting logic is Story 004, but this story's step-1 gate must be tested here).

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/apply_action_pipeline_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Story 003, Story 004
