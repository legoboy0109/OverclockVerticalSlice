# ADR-0008: Shared Start-of-Turn Sequencing

## Status
Accepted

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / State Management |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None — this ADR is pure game-state orchestration logic (method calls, field writes, `Array[Event]` composition); no new engine API surface beyond what ADR-0001/0002/0004/0006/0007 already established and verified |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`active_player`/`round_number`/`match_status`, `end_turn()` sugar), ADR-0002 (`EndTurnAction` verb dispatch — this ADR defines its `apply()` body), ADR-0004 (`Event` base class / `action_applied` signal contract — this ADR's new event types must fit it), ADR-0006 (`AP.reset_turn()`/`AP.discard()`, which already forward-reference "invoked by ADR-0008's start-of-turn sequence"), ADR-0007 (`UnitState`/`StructureState` fields this ADR resets and advances) |
| **Enables** | Unblocks implementation of the Unit System, Base & Production, Research/Tech, and Combat Resolution epics (all depend on a defined turn-boundary reset/advance sequence); ADR-0011 (AI headless decision loop — needs a fully defined turn loop to simulate `clone()`-based lookahead against) |
| **Blocks** | Epic "Foundation: Game State Core" completion — this is the last of the 8 Foundation ADRs; no Core-layer verb handler can be correctness-tested end-to-end (build completing, tech completing, AP resetting) until this is Accepted |
| **Ordering Note** | This is the final Foundation ADR in the dependency chain (0001 → {0002, 0003} → 0005 → {0004, 0006} → 0007 → 0008) |

## Context

### Problem Statement

`game-state-turn-manager.md` Rule 3 already specifies, in prose, the canonical 4-step start-of-turn order (set active player → clear per-turn flags → apply start-of-turn effects [build-timer + research-timer advance] → reset AP to income), and both `base-production.md` and `research-tech.md` explicitly defer to "the Turn Manager's canonical sequence" for their own completion timing rather than defining an order themselves. ADR-0002 already forward-references this ADR twice — "the *ordering* of which is owned by ADR-0008; `apply_action` only invokes it" and "ADR-0008: Start-of-turn sequencing (invoked by `EndTurnAction.apply()`)" — without defining what `EndTurnAction.apply()` concretely calls.

Two further gaps prevent that prose from being implementable as-is:
1. **`round_number` increment timing** (Rule 4: "increments... each time control returns to the starting player") requires knowing who the starting player *was*, a fact ADR-0001's `GameState` schema never captured.
2. **Two forward-declared per-system contracts are needed** — a build-timer advance and a research-timer advance — because neither Base & Production nor Research/Tech has (or is planned to have, per `architecture.md`'s 16-ADR list) its own Foundation-tier ADR to define them. Exactly the same situation ADR-0006 was in with `completed_outpost_count()`/`economy_tech_income_bonus()`, which ADR-0007 then implemented.

### Constraints
- Must preserve the exact 4-step order `game-state-turn-manager.md` Rule 3 specifies — reordering silently breaks the "just-completed Economy Outpost counts toward income this same turn" guarantee both `base-production.md` Rule 6 and `research-tech.md` Rule 5 depend on.
- Must route through the existing `apply_action` mutation vector (ADR-0002) — no direct external field writes to `GameState` (`direct_game_state_field_write` ban). `start_turn()` is a `GameState`-owned method invoked from within `EndTurnAction.apply()` (itself dispatched by `apply_action`'s step 5), the same way `run_win_check()` is a `GameState`-owned step at pipeline step 6 — not a system "reaching in."
- Must be deterministic and headless (ADR-0003): no RNG, stable iteration order over entities.
- Must produce typed `Event`s through the existing `Event`/`action_applied` contract (ADR-0004), not a new signal or polling mechanism.
- Must not introduce a win-check gap: timer-advance effects can complete structures/techs but cannot destroy an HQ, so no new win-check call is needed inside `start_turn()` — the existing `apply_action` step 6 already covers all HQ-destroying paths (combat damage, resolved during the Action phase).

### Requirements
- `EndTurnAction.apply()` must: discard the outgoing player's AP, determine the next player, increment `round_number` at the correct point, and run the canonical start-of-turn sequence for the next player.
- `start_match()` must also run the start-of-turn sequence for the starting player (per the `Setup → PlayerTurn(starting)` transition in `game-state-turn-manager.md`'s state table).
- Per-unit and per-structure flag resets (`has_attacked`, `tiles_moved_this_turn`, `units_produced_this_turn`) must be attributed to their owning systems' semantics (Unit System / Base & Production), with only the *timing* owned here — per the GDD's own framing.
- Build-timer and research-timer advances must run before the AP income snapshot, and both must complete before that snapshot is taken if both reach 0 the same turn (`research-tech.md`'s explicit joint-completion requirement).

## Decision

`GameState.start_turn(player: int) -> Array[Event]` is the concrete orchestrator for the canonical 4-step sequence, implemented as a `GameState`-owned instance method (matching how `apply_action`/`end_turn`/`clone`/`start_match` are already `GameState`'s own methods, not a separate static utility class). It is called in exactly two places: once by `start_match()` for the starting player, and once per turn by `EndTurnAction.apply()` for the next player.

`EndTurnAction.apply()` additionally owns the end-of-turn half (AP discard) and the `round_number` increment, using a new `starting_player: int` field this ADR adds to `GameState` (immutable after `start_match()`, closing the gap ADR-0001 left open).

Two contracts are forward-declared for Unit System and Base & Production to implement when those systems are coded (no dedicated ADR is planned for either, mirroring how ADR-0006 forward-declared `completed_outpost_count()` for ADR-0007 to implement): `Unit.reset_turn_flags(unit)`, `Structure.reset_turn_flags(structure)`, `BaseProduction.advance_build_timers(state, player)`, and `Research.advance_research_timers(state, player)`. `start_turn()` calls all four plus the already-concrete `AP.reset_turn()` (ADR-0006), in GDD Rule 3's exact order.

Two new `Event` subclasses join `GameOverEvent` (ADR-0004): `StructureCompletedEvent` and `TechCompletedEvent`, appended by the two advance calls and flowing through the existing `action_applied(result)` signal — no new signal or polling path.

### Architecture Diagram

```
start_match(map, starting_player)
   │  builds grid/entities, sets round_number=1, active_player=starting_player
   │  state.starting_player = starting_player          # NEW field, set once, immutable after
   └─▶ state.start_turn(starting_player)                # first Start-of-turn, no round increment

EndTurnAction.apply(state, action) -> Array[Event]:      # dispatched via apply_action step 5 (ADR-0002)
    1. AP.discard(state, state.active_player)            # end-of-turn: unspent AP gone, no banking
    2. next_player := opponent(state.active_player)       # 2-player VS: 1 - active_player
    3. if next_player == state.starting_player:
           state.round_number += 1                        # Rule 4: control returned to the starter
    4. events := state.start_turn(next_player)
    5. return events

GameState.start_turn(player: int) -> Array[Event]:        # the canonical 4-step sequence (Rule 3)
    events := []
    1. active_player = player
    2. for e in entities() where e.owner == player:        # stable order (ADR-0003 Rule 3)
           if e is UnitState:      Unit.reset_turn_flags(e)         # forward-declared, Unit-owned
           elif e is StructureState: Structure.reset_turn_flags(e)  # forward-declared, B&P-owned
    3. events += BaseProduction.advance_build_timers(self, player)   # forward-declared
       events += Research.advance_research_timers(self, player)      # forward-declared
       # (3a) both complete fully before step 4 — no snapshot is taken until both have run
    4. AP.reset_turn(self, player)                          # ADR-0006, concrete — snapshot + set current_ap
    return events
```

### Key Interfaces

```gdscript
# On GameState (adds to ADR-0001's class; new field + new method):
@export var starting_player: int = 0    # set once by start_match(), never mutated after

func start_turn(player: int) -> Array:                 # Array[Event]; the canonical 4-step sequence
    active_player = player
    for e in entities():
        if e.owner != player:
            continue
        if e is UnitState:
            Unit.reset_turn_flags(e)
        elif e is StructureState:
            Structure.reset_turn_flags(e)
    var events: Array = []
    events.append_array(BaseProduction.advance_build_timers(self, player))
    events.append_array(Research.advance_research_timers(self, player))
    AP.reset_turn(self, player)
    return events

static func start_match(map: MapDefinition, starting_player: int) -> GameState:
    var state := GameState.new()
    # ... grid/entity construction (ADR-0001/0005) ...
    state.starting_player = starting_player
    state.round_number = 1
    state.start_turn(starting_player)                   # first Start-of-turn; no round increment
    return state
```

```gdscript
# end_turn_action.gd — EndTurnAction's apply() (the verb handler ADR-0002 dispatches to)
static func apply(state: GameState, action: Action) -> Array:   # Array[Event]; assumes validated
    var outgoing: int = state.active_player
    AP.discard(state, outgoing)
    var next_player: int = 1 - outgoing                 # 2-player VS: strict alternation
    if next_player == state.starting_player:
        state.round_number += 1                          # Rule 4
    return state.start_turn(next_player)
# EndTurnAction.validate() is unchanged from ADR-0002 — unconditionally OK for the active player;
# it does not gate on anything this ADR introduces.
```

```gdscript
# Forward-declared contracts this ADR depends on — implemented when Unit System /
# Base & Production / Research are coded (no dedicated ADR defines them):
#   static func Unit.reset_turn_flags(unit: UnitState) -> void
#       # sets unit.has_attacked = false, unit.tiles_moved_this_turn = 0 (unit-system.md Rule 2a)
#   static func Structure.reset_turn_flags(structure: StructureState) -> void
#       # sets structure.units_produced_this_turn = 0, structure.has_attacked = false
#       # (base-production.md States and Transitions; no-op fields for non-producer/non-Defensive
#       # structure types are harmlessly reset to their already-unused default)
#   static func BaseProduction.advance_build_timers(state: GameState, player: int) -> Array
#       # decrements build_turns_remaining on player's Under-Construction structures;
#       # transitions to StructureState.BuildStatus.COMPLETED at 0, appending a
#       # StructureCompletedEvent per completion (base-production.md Rule 6)
#   static func Research.advance_research_timers(state: GameState, player: int) -> Array
#       # decrements research_turns_remaining on player's Labs with a non-null
#       # current_research_target; on reaching 0, sets the corresponding PlayerState tech flag
#       # (has_attack_tech / has_defense_tech / has_economy_tech), clears the Lab's
#       # current_research_target, and appends a TechCompletedEvent (research-tech.md Rule 5)
```

```gdscript
# New Event subclasses (ADR-0004's contract: class_name X extends Event, appended to
# result.events in resolution order; consumed via `if e is StructureCompletedEvent:`)
class_name StructureCompletedEvent extends Event
var structure_id: int
var structure_type: StructureTypeDef        # ADR-0007

class_name TechCompletedEvent extends Event
var player: int
var tech: TechDef                            # ADR-0007
```

## Alternatives Considered

### Alternative 1: `GameState.start_turn()` as the single orchestrator — CHOSEN
- **Description**: A `GameState`-owned instance method runs the 4-step sequence; `EndTurnAction.apply()` (Turn-Manager's own verb handler, dispatched normally through `apply_action`) calls it after the end-of-turn discard.
- **Pros**: Matches the precedent `apply_action`/`end_turn`/`clone`/`start_match` already set — `GameState` *is* the turn manager (per `game-state-turn-manager.md`'s own framing), so its own orchestration living on itself is not a new pattern. No new class to reason about; `start_turn()` is trivially reachable from both call sites (`start_match`, `EndTurnAction.apply()`).
- **Cons**: `GameState` accumulates one more method beyond pure state-container behavior.
- **Rejection Reason**: N/A — chosen.

### Alternative 2: A separate static `TurnManager` utility class (mirroring `AP`/`Movement`/`Combat`)
- **Description**: `TurnManager.start_turn(state, player) -> Array[Event]`, a stateless static class alongside `AP`/`Movement`/`Combat`.
- **Pros**: Consistent with the static-utility shape every *other* Core system uses (ADR-0002's verb handlers, ADR-0006's `AP`).
- **Cons**: `GameState` already owns `apply_action`, `end_turn()`, `clone()`, and `start_match()` directly — none of those were split into a parallel `GameStateManager` utility. Splitting turn-orchestration into a second owner while state-mutation-orchestration (`apply_action`) stays on `GameState` itself creates two homes for closely related sequencing logic, for no behavioral difference (a static class taking `state` explicitly is functionally identical to an instance method).
- **Rejection Reason**: Inconsistent with the precedent `GameState` itself already set for its own orchestration methods; no benefit beyond stylistic uniformity with unrelated systems whose reason for being static (no instance identity, shared across every clone) doesn't apply to `GameState`'s own methods.

### Alternative 3: Leave Base & Production's/Research's timer-advance contracts undefined until those systems get their own ADR
- **Description**: This ADR calls generic "apply start-of-turn effects" without naming `advance_build_timers()`/`advance_research_timers()`, deferring the concrete contract to whenever those systems are implemented.
- **Pros**: Keeps this ADR narrowly scoped to `GameState`'s own sequencing.
- **Cons**: `architecture.md`'s 16-ADR plan does not include a dedicated Base & Production or Research/Tech ADR — nothing would ever formally define these contracts, leaving `dev-story` implementers to invent the shape ad hoc with no architectural review, exactly the gap ADR-0006→ADR-0007's forward-declaration pattern was designed to close.
- **Rejection Reason**: Would leave a real implementation contract permanently undefined; the forward-declaration pattern already has one successful precedent (ADR-0006/ADR-0007) to follow.

### Alternative 4: Inline per-turn flag resets directly in `GameState.start_turn()` (no `Unit.reset_turn_flags()`/`Structure.reset_turn_flags()`)
- **Description**: `start_turn()` directly writes `unit.has_attacked = false`, `structure.units_produced_this_turn = 0`, etc., rather than calling forward-declared owning-system methods.
- **Pros**: One fewer indirection layer for a handful of trivial field writes.
- **Cons**: Couples the Foundation layer (`GameState`) to the exact set of per-turn flags every Core system will ever define. A future unit type or structure type adding a new per-turn flag would require editing `GameState` (Foundation) rather than only its owning system — the opposite of the ownership boundary `unit-system.md` Rule 2a explicitly draws ("Unit-owned pure operations... Turn Manager owns *when* they run").
- **Rejection Reason**: User-directed choice (session decision, 2026-07-23) — forward-declaring keeps flag *semantics* owned by Unit System/Base & Production while `GameState` owns only *timing*, consistent with the GDD's own ownership split and with how `AP.reset_turn()`/`AP.discard()` are already forward-declared-and-implemented rather than inlined.

### Alternative 5: No completion events — silent state transition
- **Description**: `advance_build_timers()`/`advance_research_timers()` mutate state and return an empty `Array[Event]`; HUD detects completions by polling/diffing `build_status`/`current_research_target` each frame.
- **Pros**: Slightly less code (`Array[Event]` is empty).
- **Cons**: Reintroduces exactly the polling ADR-0004 was written to eliminate ("Never dispatch/route... via a generic diff"-adjacent problem, one level up: polling instead of a diff, same root issue); contradicts `game-state-turn-manager.md`'s own framing of this as "the turn manager's *events*."
- **Rejection Reason**: User-directed choice (session decision, 2026-07-23) — `StructureCompletedEvent`/`TechCompletedEvent` were added to keep every state change event-driven, matching ADR-0004's contract uniformly rather than carving out a polling exception for turn-boundary effects specifically.

## Consequences

### Positive
- The 4-step order is now a single, testable method (`start_turn()`) rather than prose distributed across three GDDs — a determinism/golden-replay test can assert the exact call order directly.
- `starting_player` closes a real gap: `round_number` incrementing is now correctly defined for either player starting the match, not just an implicit "player 0 always starts" assumption.
- The forward-declaration pattern (Alternative 3) gives Base & Production's and Research's timer-advance logic an architectural home despite neither system having its own ADR — matching the ADR-0006/ADR-0007 precedent exactly.
- `StructureCompletedEvent`/`TechCompletedEvent` keep the HUD fully event-driven with zero new signal/polling infrastructure — they ride the exact same `action_applied(result)` signal every other event already uses, because `EndTurnAction` dispatches through the same `apply_action` pipeline as every other verb.
- No new win-check call is needed: timer advances can only complete (not destroy), so the existing `apply_action` step 6 fully covers HQ-destruction detection.

### Negative
- `GameState` now has one more method (`start_turn()`) and one more field (`starting_player`) beyond ADR-0001's original shape — a small, justified schema/behavior growth on the Foundation class.
- Four forward-declared contracts (`Unit.reset_turn_flags`, `Structure.reset_turn_flags`, `BaseProduction.advance_build_timers`, `Research.advance_research_timers`) exist only as signatures until their owning systems are implemented — same latency risk ADR-0006's forward declarations had, resolved there when ADR-0007 landed.
- `EndTurnAction.apply()` is now less trivial than a typical verb handler (it owns discard + round-increment + start_turn dispatch) — still a single, linear, five-line sequence, but it is the one verb handler with more than "spend AP and mutate one thing" inside it.

### Risks
- **A future N-player mode would break the `next_player := 1 - active_player` alternation.** Out of scope for the Vertical Slice (2-player only, per `technical-preferences.md`), but any future multiplayer-beyond-2 expansion must revisit this line specifically, not assume it generalizes. **Mitigation**: flagged here explicitly so a future ADR touching player count finds this comment.
- **Joint-completion ordering (build timer and research timer completing the same turn) is resolved by research-tech.md's own explicit rule** ("this does NOT mean the research-timer and build-timer advances are dependent on each other... both complete... no matter which one's timer advance ran first within step 3") — meaning `start_turn()`'s internal order between `BaseProduction.advance_build_timers()` and `Research.advance_research_timers()` must not matter for correctness. **Mitigation**: Validation Criteria includes a test asserting both orderings produce identical resulting state (commutative within step 3), not just testing one fixed order.
- **`Structure.reset_turn_flags()` resets fields that are meaningless for most structure types** (`has_attacked` is only meaningful for a Defensive Structure; `units_produced_this_turn` only for producers) — this is the same accepted waste-for-simplicity tradeoff ADR-0007 already made for `StructureState`'s shape; no new risk, just inherited from that ADR.
- **`start_turn()` invoked on a `duplicate_deep()` clone — confirmed a non-issue** (godot-specialist, 2026-07-23). Instance-method dispatch is identical whether a `GameState` came from `.new()` or `duplicate_deep()` (standard `Object` behavior, unaffected by 4.4–4.6); and `starting_player`'s once-early mutation in `start_match()` is snapshotted correctly by every later `clone()` because `duplicate_deep()` copies the field's value at call time (no lazy/deferred snapshot) — the same `@export`-field clone behavior ADR-0001's Validation Criteria already covers. Noted for completeness, not as an open risk.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-state-turn-manager.md | Rule 3: canonical 4-step start-of-turn order (active player → clear flags → start-of-turn effects → AP reset) | `GameState.start_turn()` implements the exact 4 steps in exact order |
| game-state-turn-manager.md | Rule 4: `round_number` increments when control returns to the starting player | New `starting_player` field + `EndTurnAction.apply()`'s increment check |
| game-state-turn-manager.md | States and Transitions: `Setup → PlayerTurn(starting)` fires Start-of-turn; `EndTurn(P) → PlayerTurn(other)` fires Start-of-turn for the other player | `start_match()` calls `start_turn(starting_player)`; `EndTurnAction.apply()` calls `start_turn(next_player)` |
| ap-economy.md | Rule 5: income is a frozen start-of-turn snapshot, evaluated after the build-timer advance | `AP.reset_turn()` (ADR-0006, concrete) is called last, step 4, after step 3's timer advances |
| base-production.md | Rule 6: build completion is a start-of-turn effect, processed before the income snapshot; batch completions same-turn | `BaseProduction.advance_build_timers()` forward-declared, called at step 3; loop completes all of a player's structures before step 4 runs |
| research-tech.md | Rule 5: research-timer advance ordered like the build-timer advance, same-turn joint completion with no ordering dependency | `Research.advance_research_timers()` forward-declared, called at step 3 alongside the build-timer advance; Validation Criteria asserts order-independence |
| unit-system.md | Rule 2a: `reset_turn_flags(unit)` is Unit-owned; Turn Manager owns *when* it runs | `Unit.reset_turn_flags()` forward-declared, called at step 2, filtered to the active player's entities |
| base-production.md | States and Transitions: per-turn structure flags (`units_produced_this_turn`, `has_attacked`) reset alongside unit flag reset | `Structure.reset_turn_flags()` forward-declared, called at step 2 alongside `Unit.reset_turn_flags()` |
| coding-standards.md / ADR-0003 | Deterministic, headless, stable iteration order | `entities()` (ADR-0001, entity_id-ordered) is the iteration surface for step 2; no RNG anywhere in this sequence |

## Performance Implications
- **CPU**: Negligible. `start_turn()` runs once per player per turn (not per-frame): one filtered pass over `entities()` (O(entity count)) plus two forward-declared per-system passes over the same player's structures (also O(entity count), bounded by a few dozen entities per match).
- **Memory**: No new persistent allocations beyond the two new lightweight `Event` subclasses, which are transient (appended to a turn's `events` array, consumed by presentation, then discarded like every other event).
- **Load Time**: N/A — no load-time cost; `start_turn()` is pure runtime orchestration.
- **Network**: N/A — no networking in the Vertical Slice.

## Migration Plan
None — this is new orchestration logic completing what ADR-0001/0002/0006/0007 already forward-declared or left implicit. `starting_player` is a new field on an as-yet-unimplemented class (`GameState` is still `Proposed`), not a migration of existing running code.

## Validation Criteria
- Unit test: a full `start_match()` → several `EndTurnAction`s asserts `round_number` increments exactly when control returns to `starting_player`, for **both** `starting_player = 0` and `starting_player = 1` (catching the gap this ADR closes).
- Unit test: a start-of-turn where a Production Outpost's `build_turns_remaining` reaches 0 **and** an Economy Outpost is already Completed asserts `AP.income()` (sampled after step 4) reflects the newly-Completed outpost the same turn (the "just-completed counts this turn" guarantee).
- Unit test: order-independence — running `start_turn()` with `BaseProduction.advance_build_timers()` and `Research.advance_research_timers()` swapped (test-only harness) produces an identical resulting `GameState` (deep-equality) when both a structure and a tech complete the same turn, per `research-tech.md`'s explicit joint-completion rule.
- Unit test: `Unit.reset_turn_flags()`/`Structure.reset_turn_flags()` are called for the incoming active player's entities only — an opponent's `has_attacked`/`tiles_moved_this_turn` are untouched across the boundary.
- Determinism test: two identical `GameState`s driven through an identical action sequence (including multiple `EndTurnAction`s) produce byte-identical `round_number`/`active_player`/`entities()` iteration order at every turn boundary (ADR-0003 golden-replay pattern).

## Related Decisions
- ADR-0001: State Model Ownership & Lifecycle (`GameState` base, `end_turn()` sugar, `start_match()`)
- ADR-0002: Apply-Action Command Model (`EndTurnAction` verb dispatch — this ADR defines its `apply()` body)
- ADR-0004: Event/Signal Architecture (`Event` base class, `action_applied` signal — this ADR's two new event types)
- ADR-0006: AP Economy Data Model & Spend Contract (`AP.reset_turn()`/`AP.discard()`, already forward-referencing this ADR)
- ADR-0007: Unit & Structure Entity/Stat Schema (`UnitState`/`StructureState` fields this ADR resets and advances)
- `design/gdd/game-state-turn-manager.md`, `design/gdd/ap-economy.md`, `design/gdd/base-production.md`, `design/gdd/research-tech.md`, `design/gdd/unit-system.md`
