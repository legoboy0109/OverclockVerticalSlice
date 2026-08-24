# ADR-0002: Action / apply_action Command Model

## Status
Accepted

> **Revised 2026-08-05 (economy pivot).** Updated for the two-budget model (ADR-0006): economic verbs are
> dual-cost — `validate()` checks BOTH `Credits.can_afford` and `AP.can_afford`, and `apply()` spends BOTH
> (both-or-neither, made safe by this ADR's validate-before-mutate atomicity — no rollback needed); added
> `CANT_AFFORD_CREDITS` to the `Reason` enum so the binding pool is nameable; `EndTurnAction` no longer
> discards AP (it carries over, capped). The command-model architecture (typed Actions, verb-keyed
> dispatch, validate-before-mutate) is unchanged.

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md`, `deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — pure GDScript control flow over the ADR-0001 `Resource` model |
| **Verification Required** | None (no post-cutoff API). Dispatch mechanism pinned to a verb-enum `Dictionary[int, Callable]` per godot-specialist review (2026-07-23): `get_class()` returns the base engine class for script types and must never be used for verb dispatch. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (State model ownership & lifecycle — defines `GameState`, the object `apply_action` mutates) |
| **Enables** | ADR-0008 (start-of-turn sequencing — invoked by `EndTurnAction`), ADR-0009 (Movement — supplies `MoveAction` validate/apply), ADR-0010 (Combat — supplies `AttackAction`), and the Base&Prod/Research verb handlers |
| **Blocks** | Epic "Foundation: Game State Core" — the mutation pipeline every Core verb commits through |
| **Ordering Note** | Second ADR. Every Core gameplay ADR (Movement, Combat, Base&Prod, Research) plugs a verb handler into the contract defined here; those ADRs depend on this one |

## Context

### Problem Statement
ADR-0001 declared `apply_action(action) -> ActionResult` the **sole mutation vector** for `GameState`
and registered `direct_game_state_field_write` as a forbidden pattern — but stubbed the method's body.
This ADR defines the full contract: how an `Action` is represented, the validate→apply→win-check
pipeline, how atomicity is guaranteed (an illegal action leaves the state — including AP —
completely unchanged, per GDD Core Rule 8), how duplicate submissions are handled (GDD Edge Case),
and what `apply_action` returns. Every Core gameplay system (Movement, Combat, Base & Production,
Research) commits its verb through this one path, so the contract here is the spine of all gameplay
mutation.

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- Must uphold the registered stances from ADR-0001: `authoritative_game_state` mutated via
  `apply_action` only; `direct_game_state_field_write` forbidden; `entity_id` assigned by
  `apply_action` on entity creation.
- Must preserve determinism (ADR-0003, forthcoming): no RNG, stable ordering — so the pipeline
  cannot introduce nondeterministic iteration.
- Single-threaded (turn-based; no simulation deadline) — atomicity does not need lock/thread safety.

### Requirements
- **Atomicity**: illegal action → zero state change, including **both** AP and Credits (GDD Core Rule 8, Edge Cases; TR-gamestate-005). For a dual-cost economic action this is **both-or-neither**: never spend Credits then fail the AP-surcharge leg (or vice versa).
- **Validation**: enough AP **and** Credits (economic verbs are dual-cost — the resource gate + the AP-surcharge tempo gate), legal target, correct active player (GDD Core Rule 8, ap-economy.md Rule 11).
- **Pool deduction** (AP and/or Credits) happens inside the pipeline via AP & Credits Economy's `AP.spend()` / `Credits.spend()` (ADR-0006), never by direct write. Move/Attack spend AP only; Produce/Build/Research spend Credits (main) + an AP surcharge, both in the one `apply()`.
- **Win-check** runs after every mutation that could destroy an HQ, synchronously → `GameOver`
  (GDD Core Rule 5; TR-gamestate-010).
- **Idempotency-by-revalidation**: a resubmitted action is re-validated against current state and
  typically rejected; no double-apply (GDD Edge Case; TR-gamestate-018).
- **No softlock**: `end_turn()` (as `EndTurnAction`) is unconditionally legal for the active player
  (TR-gamestate-017).
- **Post-GameOver lockout**: once `match_status == GameOver`, every subsequent action is rejected
  (GDD Core Rule 5; TR-gamestate-010).
- **Faction lock**: faction is set at Setup and immutable after Setup→PlayerTurn; `apply_action`
  rejects re-assignment (TR-gamestate-014).

## Decision

**An `Action` is a typed subclass, one per verb** (`MoveAction`, `AttackAction`, `BuildAction`,
`ProduceAction`, `ResearchAction`, `CancelBuildAction`, `EndTurnAction`), extending a small
`Action` base (`RefCounted` — transient command objects, created per input, applied, discarded;
not part of cloned state). **Each subclass is its own top-level file with a `class_name`** (not a
nested inner class) and sets a `verb: Verb` enum field in `_init()`. Each carries statically-typed
params (e.g. `MoveAction.unit_id`, `MoveAction.dest`).

**Dispatch is by the `verb` enum, via a `Dictionary[int, Callable]` built once**, never by runtime
type inspection. Specifically: **`get_class()` MUST NOT be used for verb dispatch** — for a
GDScript-defined class it returns the base *engine* class name (`"RefCounted"`), not `"MoveAction"`,
so `match action.get_class()` is a silent-wrong bug. `apply_action` looks up the owning system's
`validate`/`apply` `Callable`s in a verb-keyed table. This is both the idiomatic and the more
performant choice (no linear `is`-chain that grows with verb count).

**`apply_action` is a thin orchestrator, not a god-method.** Each verb's *rules* live in its owning
Core system as two functions: a **pure** `validate(state, action) -> Reason` (no mutation) and an
`apply(state, action) -> Array[Event]` that assumes validation passed. `apply_action` owns only the
fixed pipeline skeleton:

```
apply_action(action):
    1. if match_status == GameOver:          return fail(GAME_OVER)          # post-GameOver lockout
    2. if action.player != active_player:    return fail(NOT_ACTIVE_PLAYER)  # (EndTurnAction: active player only)
    3. reason = _validators[action.verb].call(state, action)  # PURE, total — checks AP+Credits, target, legality, faction-lock
    4. if reason != OK:                      return fail(reason)             # ATOMIC: nothing mutated yet
    5. events = _appliers[action.verb].call(state, action)    # mutates; spends AP and/or Credits (dual-cost: both-or-neither); MAY NOT fail
    6. run_win_check(state, events)          # HQ at 0 hp → match_status = GameOver(winner = opponent)
    7. return ok(events)
```

**Atomicity is achieved by validate-before-mutate, with no rollback** (Alternative 1). Because the
simulation is single-threaded and `validate()` is *total* (it checks every precondition, including
`AP.can_afford` **and**, for economic verbs, `Credits.can_afford` — both pools before either is
spent), step 5's `apply()` cannot fail after step 4 passes — so there is never a partial mutation to
roll back, and the dual-cost both-or-neither guarantee falls out of this same property (validating
both pools first means neither `spend()` leg can fail after the gate). This is a hard invariant on
every verb handler:

> **Handler invariant:** `validate()` is pure and checks ALL failure conditions (for economic verbs,
> BOTH `Credits.can_afford` and `AP.can_afford`). `apply()` never returns a failure and never
> encounters a rejected `AP.spend()` / `Credits.spend()` — if it does, that is a contract-violation
> bug (assert), not a normal control-flow path. An economic `apply()` spends **both** pools (Credits
> main + AP surcharge); spending only one is an atomicity bug.

**`apply_action` returns a uniform `ActionResult`** — `{ok: bool, reason: int, events: Array[Event]}`.
On rejection, `ok=false` and `reason` names the cause (`NOT_ACTIVE_PLAYER`, `CANT_AFFORD` [insufficient
AP], `CANT_AFFORD_CREDITS` [insufficient Credits — so the Command interface can name the binding pool],
`ILLEGAL_TARGET`, `OUT_OF_RANGE`, `TILE_OCCUPIED`, `GAME_OVER`, `FACTION_LOCKED`, …). On success,
`events` carries what happened (verb-specific detail like damage dealt, plus `hq_destroyed` for the
win-check and the entries the HUD action-log consumes, TR-hud-014). One uniform call site for UI and AI.

**Idempotency is stateless re-validation** — no dedup IDs, no seen-set. A resubmitted action re-runs
the full pipeline against now-current state and naturally fails (AP already spent / target gone /
unit already moved), returning `ok=false`. This matches the GDD Edge Case and adds nothing to the
`clone()`/determinism surface.

`EndTurnAction` is the one verb exempt from an affordability/legality check: it is unconditionally
legal for the active player (no softlock). Its `apply()` runs the end-of-turn → start-of-turn
sequence for the next player — the *ordering* of which is owned by ADR-0008; `apply_action` only
invokes it. (There is **no AP discard** anymore: unspent AP carries over capped, and Credits bank —
ADR-0008/ADR-0006's pivot removed the old end-of-turn AP-discard step.)

### Architecture Diagram

```
   caller (Command&Action / AI)
        │  builds a typed Action (MoveAction, AttackAction, …)
        ▼
   GameState.apply_action(action) ── fixed pipeline ──┐
        │ 1 GameOver gate                             │
        │ 2 active-player gate                        │
        │ 3 validate() ── dispatch by action.verb ───▶│  owning Core system
        │ 4 reject if !OK  (ATOMIC — no mutation)     │   Movement.validate/apply
        │ 5 apply()   ── dispatch by action.verb ────▶│   Combat.validate/apply
        │      └─ AP.spend() / Credits.spend()         │   Base&Prod.validate/apply
        │         (ADR-0006, sole pool deductors;      │
        │          economic verbs spend both)          │
        │ 6 run_win_check()  (turn manager owns)      │   Research.validate/apply
        │ 7 return ActionResult{ok, reason, events}   │
        └─────────────────────────────────────────────┘
                            │ events
                            ▼  (emitted on the Event bus — ADR-0004)
                   HUD / Board Renderer
```

### Key Interfaces

```gdscript
# action.gd — top-level file, class_name Action
class_name Action extends RefCounted           # transient; NOT part of cloned state
enum Verb { MOVE, ATTACK, BUILD, PRODUCE, RESEARCH, CANCEL_BUILD, END_TURN }
var verb: int                                  # Verb enum; set in each subclass _init() — dispatch key
var player: int                                # the acting player (validated == active_player)

# move_action.gd — top-level file, class_name MoveAction (one file per verb)
class_name MoveAction extends Action
var unit_id: int
var dest: Vector2i
func _init() -> void: verb = Verb.MOVE
# attack_action.gd: class_name AttackAction extends Action; var attacker_id/target_id; verb = Verb.ATTACK
# end_turn_action.gd: class_name EndTurnAction extends Action; verb = Verb.END_TURN  (unconditionally legal)

enum Reason { OK, NOT_ACTIVE_PLAYER, CANT_AFFORD, CANT_AFFORD_CREDITS, ILLEGAL_TARGET, OUT_OF_RANGE,
              TILE_OCCUPIED, NOT_LEGAL_BUILD_TILE, PRODUCTION_CAP_REACHED,
              GAME_OVER, FACTION_LOCKED, NO_SUCH_ENTITY }
# CANT_AFFORD = insufficient AP (tactical). CANT_AFFORD_CREDITS = insufficient Credits (economic).
# An economic verb's validate() returns whichever pool binds, so the Command interface can grey the
# action against the correct pool (ap-economy.md dual-cost). Appending mid-enum is safe — verb
# dispatch is by Verb, not Reason ordinal, and Reason is compared by name, never by int value.

class ActionResult extends RefCounted:
    var ok: bool
    var reason: int          # Reason enum, typed as int (GDScript enums are ints at the signature level)
    var events: Array        # Array[Event] — heterogeneous; consumers use `if e is DamageEvent:` not match

# Verb-keyed dispatch table, built once (NOT get_class(), NOT a linear is-chain):
#   var _validators: Dictionary = { Verb.MOVE: Movement.validate, Verb.ATTACK: Combat.validate, ... }
#   var _appliers:   Dictionary = { Verb.MOVE: Movement.apply,    Verb.ATTACK: Combat.apply,    ... }
# Contract every Core verb handler implements (owned by its own system/GDD/ADR):
#   func validate(state: GameState, action: Action) -> int      # returns Reason; PURE, total
#   func apply(state: GameState, action: Action) -> Array        # returns events; assumes validated; may not fail

# On GameState:
func apply_action(action: Action) -> ActionResult   # the fixed 7-step pipeline; dispatch via action.verb
func end_turn() -> ActionResult                      # sugar: apply_action(EndTurnAction for active_player)
```

## Alternatives Considered

### Alternative 1 (atomicity): Validate-fully-before-mutate, no rollback — CHOSEN
- **Description**: Total pure `validate()` gate; `apply()` cannot fail after it passes.
- **Pros**: Zero rollback machinery; no clone/snapshot cost per action; trivially atomic in a
  single-threaded sim; the pure `validate()` doubles as the legality query the UI/AI already need
  for previews.
- **Cons**: Discipline burden — every handler must keep `validate()` exhaustive; a precondition
  checked only in `apply()` is a latent atomicity bug.
- **Rejection Reason**: n/a (chosen). The discipline is enforceable by the handler invariant + tests.

### Alternative 2 (atomicity): Snapshot-and-rollback
- **Description**: `clone()` the state before applying; on any failure inside `apply()`, restore the snapshot.
- **Pros**: `apply()` may fail freely mid-way; no "validate must be total" discipline.
- **Cons**: Pays a full `clone()` cost on **every** committed action (and `clone()` is already the
  AI's per-evaluation hot path — doubling its use is expensive); more code and a second correctness
  surface (restore must be perfect).
- **Rejection Reason**: Buys rollback we don't need — validation in a deterministic single-threaded
  sim can always be made total, at far lower cost.

### Alternative 3 (atomicity): Per-command transaction objects with embedded validate/apply
- **Description**: Each `Action` subclass *itself* carries `validate()`/`apply()` methods (command
  pattern), instead of the owning system holding them.
- **Pros**: Verb logic fully encapsulated in one class.
- **Cons**: Pulls each verb's rules *out* of its owning Core system into the Action object, which
  fights the module-ownership map (Movement owns move rules, Combat owns attack rules) and would
  make an Action class depend on Grid/AP/Unit internals. Splits ownership awkwardly.
- **Rejection Reason**: The chosen split (typed Action = data; owning system = logic) keeps rules
  where the ownership map and GDDs put them, while still getting typed verbs.

### Alternative 4 (representation): Tagged Dictionary action (`{verb, params}`)
- **Description**: One `Action` = `{verb: enum, params: Dictionary}`.
- **Pros**: Serializes for replay trivially; one type.
- **Cons**: Untyped params (every access a dict lookup, no autocomplete, no compile-time check),
  and validation collapses into one large `match` — against the static-typing convention and
  harder to keep exhaustive.
- **Rejection Reason**: Typed subclasses give compile-time safety on params, which matter in the
  AI's hot enumerate-legal-actions loop; replay (deferred to Alpha) can add serialization later.

### Alternative 5 (result): Per-verb Result subtypes
- **Description**: Each verb returns its own `MoveResult`/`AttackResult`/… as the architecture.md
  sketch first showed.
- **Pros**: Richer per-verb static typing on the result.
- **Cons**: Every caller must switch on verb to read a result, and `apply_action`'s single signature
  needs a common supertype anyway — so the uniform `ActionResult` with verb detail in `events` is a
  simpler call site for both UI and AI.
- **Rejection Reason**: Uniform result chosen for a single call site; verb-specific detail rides in `events`.

## Consequences

### Positive
- One mutation pipeline to read, test, and reason about; every verb goes through the same 7 steps.
- The pure `validate()` each handler must supply *is* the legality/affordability query the UI
  (pre-commit preview) and AI (enumerate-legal-actions) already need — one function, three consumers,
  guaranteeing preview matches commit legality.
- Atomicity with no rollback cost keeps `clone()` reserved for AI lookahead, not spent on every commit.
- Uniform `ActionResult` gives UI and AI a single call/inspect shape.
- Determinism-friendly: the pipeline has no iteration of its own; ordering lives in the handlers +
  ADR-0003 rules.

### Negative
- **Handler discipline**: every verb's `validate()` must remain total; a precondition checked only
  in `apply()` is an atomicity bug. Mitigated by the handler invariant + a per-verb "reject leaves
  state unchanged" test.
- Adds a small class-per-verb surface (7 Action subclasses) — cheap, but more files than a tagged dict.
- `events` is a semi-structured `Array[Event]` (not per-verb-typed); consumers parse by event type.

### Risks
- **A handler that mutates inside `validate()`** would break atomicity silently. Mitigation: code
  review + a test asserting `validate()` leaves state field-wise-unchanged for a sample of each verb.
- **A precondition split** (checked in `apply()` not `validate()`) surfaces only as a rare partial
  mutation. Mitigation: the "rejected action → zero state change" AC is run per verb, including the
  boundary cases (exactly-not-enough AP, target just out of range) and — for economic verbs — the
  **dual-cost both-or-neither** cases: affordable in Credits but not the AP surcharge (and vice
  versa) must leave BOTH pools unchanged.
- **Dispatch on `get_class()`** is a tempting-but-wrong bug: for a GDScript class it returns the base
  engine class (`"RefCounted"`), so a verb `match` on it silently never matches. Mitigation: dispatch
  is pinned to the `verb` enum table (Decision); flag `get_class()`-based verb routing in code review.
- **Minor GDScript-idiom notes** (godot-specialist, 2026-07-23): (a) `events` is a typed
  `Array[Event]` of a base class — consumers must use `for e in events: if e is DamageEvent:`, not a
  `match`; covariant Object-subclass array typing is supported in 4.6. (b) `validate()`'s return is
  typed `-> int` (not `-> Reason`) deliberately — GDScript enums are `int` at the signature level and
  give no extra compile-time safety; do not "fix" it to `-> Reason`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-state-turn-manager.md | TR-gamestate-004: single `apply_action` entry, validates+applies atomically, deducts AP and/or Credits, runs win-check | The fixed 7-step pipeline; economic verbs deduct both pools in step 5 |
| game-state-turn-manager.md | TR-gamestate-005: illegal action → zero state change incl. AP and Credits (dual-cost both-or-neither) | Validate-before-mutate (steps 3–4); nothing mutates before validation passes; economic verbs validate both pools first |
| game-state-turn-manager.md | TR-gamestate-010: win-check after every HQ-destroying mutation, synchronous | Step 6 runs inside the same call, before returning |
| game-state-turn-manager.md | TR-gamestate-017: `end_turn()` never softlocks | `EndTurnAction` exempt from affordability/legality gate |
| game-state-turn-manager.md | TR-gamestate-018: resubmitted action re-validated, no double-apply | Stateless re-validation (full pipeline re-run) |
| game-state-turn-manager.md | TR-gamestate-014: faction locked after Setup | `validate()` returns `FACTION_LOCKED` on post-Setup re-assignment |
| combat-resolution.md | TR-combat-005/008: `attack()` atomic, wired into win-check | `AttackAction` handler; win-check in step 6 |
| movement-system.md | TR-movement-005/014: `move()` atomic (path+afford → spend+occupy) | `MoveAction` handler under the pipeline |
| base-production.md | TR-baseprod-004/008/012: build/produce atomic; HQ-destroy win-signal | Base&Prod handlers; `hq_destroyed` event → step 6 |
| research-tech.md | TR-research-006: start/cancel research atomic via apply_action | Research handlers under the pipeline |

## Performance Implications
- **CPU**: One `validate()` + one `apply()` dispatch per committed action — negligible for turn-based
  play. The AI calls `validate()` many times per turn during enumeration (not `apply()`), so
  `validate()` being pure and allocation-light matters; handlers should avoid per-call allocation
  where hot (owed to each verb's ADR, e.g. Movement's ADR-0009 reachable budget).
- **Memory**: Transient `Action` + `ActionResult` objects are short-lived `RefCounted`; `events` is a
  small array per commit.
- **Load Time**: N/A.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Atomicity per verb**: for each verb, submit an illegal action (insufficient AP, illegal target,
  wrong active player) and assert the state — every field, including AP and Grid occupancy — is
  field-wise-unchanged and `ok == false` with the correct `reason`.
- **Win-check timing**: an attack that brings an HQ to 0 hp returns with `match_status == GameOver`
  in the same call; a subsequent `apply_action` returns `fail(GAME_OVER)`.
- **Idempotency**: apply a valid action, then resubmit the identical action; the second returns
  `ok == false` and the state reflects exactly one application.
- **No softlock**: with a player who can afford nothing, `EndTurnAction` succeeds.
- **validate() purity**: for a sample action of each verb, calling `validate()` leaves the state
  field-wise-unchanged (guards the atomicity invariant).

## Related Decisions
- ADR-0001: State model ownership & lifecycle (the `GameState` this pipeline mutates; registered the
  `apply_action`-only and `direct_game_state_field_write`-forbidden stances this ADR fulfills)
- ADR-0003: Deterministic simulation & RNG isolation (the pipeline must stay RNG-free and
  stable-ordered)
- ADR-0004: Event/signal architecture (how `events` reach HUD/renderer)
- ADR-0006: AP economy & spend contract (`AP.spend()` called inside `apply()`)
- ADR-0008: Start-of-turn sequencing (invoked by `EndTurnAction.apply()`)
- ADR-0009 (Movement), ADR-0010 (Combat), plus Base&Prod/Research verb handlers plug into this contract
- `docs/architecture/architecture.md` — its API-Boundaries **sketch** showed per-verb result types
  (`MoveResult`, `AttackResult`, `BuildResult`, …). This ADR supersedes that with a **uniform
  `ActionResult`** (verb-specific detail rides in `events`); refine the sketch once this ADR is Accepted.
  Note also: `game-state-turn-manager.md`'s `apply_action(action) -> Result` uses `Result` as a generic
  placeholder — the concrete type is `ActionResult`; compatible, no GDD edit required.
