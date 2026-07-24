# ADR-0001: State Model Ownership & Lifecycle

## Status
Proposed

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / State Management |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; live Godot 4.6 `Resource` + GDScript-exports docs (via godot-specialist, 2026-07-23) |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` (Godot 4.5); typed `Dictionary[int, EntityState]` (Godot 4.4) |
| **Verification Required** | **Largely resolved (godot-specialist review, 2026-07-23, against live 4.6 docs):** `duplicate_deep()`'s default `DEEP_DUPLICATE_INTERNAL` mode recursively deep-copies nested arrays/dictionaries *and* path-less (runtime `.new()`) Resource instances inside them — confirmed. Residual (low): the docs give no Dictionary-*value*-specific example, so the clone-isolation test in Validation Criteria still gates other Foundation ADRs building on `clone()`. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (first ADR) |
| **Enables** | ADR-0002 (apply_action command model), ADR-0003 (determinism & RNG isolation), ADR-0004 (event/signal architecture), ADR-0007 (data-driven entity schema), ADR-0012 (Faction Identity fold — needs `PlayerState.faction` storage) |
| **Blocks** | Epic "Foundation: Game State Core" — no Foundation or Core-layer code can be written until this is Accepted |
| **Ordering Note** | This is the first ADR in dependency order; every other Foundation/Core ADR assumes the class shape defined here exists |

## Context

### Problem Statement
`design/gdd/game-state-turn-manager.md` fully specifies GameState's *behavioral* contract
(the turn FSM, `apply_action`, the read API, `clone()` for AI lookahead) but explicitly defers
its *structural* home to architecture: *"Is the state model an Autoload, a passed object, or an
event-bus core? → ADR (architecture phase)"* (GDD Open Questions, line 256). This ADR answers
that question and, in doing so, must also settle four load-bearing implementation details the
GDD assumes but does not specify: the base class, the `clone()` mechanism, how entities are
represented so `clone()` is actually correct, and how the deterministic `entity_id` is generated.

Getting this wrong is expensive in a specific way: every downstream system (AI, tests, all five
Core gameplay systems, both Presentation systems) is built against whatever shape this ADR picks.
A wrong choice here (e.g. an Autoload holding sole authority) would make the AI's `clone()`-based
lookahead and the project's headless-test requirement structurally awkward to retrofit later.

### Constraints
- Must satisfy `.claude/docs/technical-preferences.md`: static GDScript typing, no `Node` dependency
  for game logic.
- Must satisfy `.claude/docs/coding-standards.md`: "dependency injection over singletons" — the
  state model itself must not become an Autoload-coupled singleton that resists unit testing.
- Must run under Redot 26.2 (Godot 4.6-compatible); any post-cutoff API must be flagged and
  verified (see Engine Compatibility).
- No existing ADRs or registry entries to reconcile with — `docs/registry/architecture.yaml` is
  empty (verified Step 3a).

### Requirements
- Must be instantiable, mutable, and queryable with **zero rendering nodes present** (TR-gamestate-002).
- Must support `clone() -> GameState` yielding a **fully independent deep copy** (TR-gamestate-003).
- Every field must be a **plain, serializable value** — no engine object references that would
  break a future save/load pass (TR-gamestate-015).
- Must expose a side-effect-free read API: `active_player`, `current_ap(player)`, `round_number`,
  `match_status`, `entities()`, `entity_at(tile)`, `grid`, `faction_of(player)` (TR-gamestate-011, -014).
- Must store `faction_of(player)` and apply `starting_loadout` once at Setup, locked thereafter
  (TR-gamestate-014).
- Must support an optional `MAX_ROUNDS` cap + `TIEBREAK_METRIC` for the anti-drag terminal predicate
  (TR-gamestate-016).
- `end_turn()` must be unconditionally legal — no softlock (TR-gamestate-017).
- Grid must be held by (owned inside) this state, decoupled from any render node (TR-grid-005, -006).

## Decision

**GameState extends `Resource`, constructed only at runtime via `.new()` — never loaded from
disk — so none of Resource's on-disk resource-caching/sharing pitfalls apply.** `clone()` is
implemented as `duplicate_deep()` cast to `GameState`; every field that must survive cloning is
declared with storage usage (`@export` or equivalent `PROPERTY_USAGE_STORAGE`) so `duplicate_deep()`
walks it. Entities are themselves small typed `Resource` subclasses (`EntityState`, later
specialized by ADR-0007 into unit/structure variants) held in a container on `GameState`, so the
same single `duplicate_deep()` call recursively deep-copies the entire entity set for free — there
is exactly one deep-copy mechanism in the whole state model, not one per nesting level.

There is **no Autoload holding authority**. The authoritative `GameState` instance is created by a
match-bootstrap script (whatever scene starts a match) and handed by reference to whoever needs
it — Presentation nodes, the AI, tests. A minimal, logic-free Autoload (`MatchService`) exists
purely as a lookup convenience: it holds a reference to *the current live match's* `GameState` so
Presentation nodes can fetch it once at `_ready()` without threading it through every scene-tree
branch. `MatchService` has no methods beyond get/set-current-state; it never mutates, validates,
or interprets state. Unit tests and the AI never touch it — they construct or receive a
`GameState` directly, which is what makes them independent of any global.

The deterministic `entity_id` is a single `int` field (`next_entity_id`) living directly on
`GameState`, incremented whenever `apply_action` creates an entity. Being a plain field, it is
automatically included in every `clone()` with no separate object to keep in sync.

### Architecture Diagram

```
                    ┌───────────────────────────────┐
                    │   MatchService (Autoload)      │   ← thin, logic-free
                    │   var current: GameState       │      lookup pointer only
                    └───────────────┬───────────────┘
                                    │ (read-only lookup)
                                    ▼
        match-bootstrap ──creates──▶  GameState  extends Resource
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        │ grid: GridState (Resource, ADR-0005 owns internals)    │
        │ per_player: Array[PlayerState]                         │
        │   PlayerState: current_ap, income_this_turn, faction,  │
        │                tech flags (write-owner = Research/AP)  │
        │ entities_by_id: Dictionary  # int entity_id->EntityState│
        │ next_entity_id: int                                    │
        │ active_player: int                                     │
        │ round_number: int                                      │
        │ match_status: enum { InProgress, GameOver }            │
        └───────────────────────────┬───────────────────────────┘
                                    │  (read API / apply_action / clone / end_turn)
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
      Core systems            AI Opponent           Presentation
      (Unit/Movement/         (clone() + read API,   (HUD, Command Iface,
       Combat/Base&Prod/       commits via            Board Renderer —
       Research)                apply_action)          read-only + apply_action)

    clone() ≡ (self as Resource).duplicate_deep() cast to GameState
    — ONE call, deep-copies grid + per_player + entities in one shot.
```

### Key Interfaces

```gdscript
class_name GameState
extends Resource

@export var grid: GridState                    # ADR-0005 owns GridState's internals
@export var per_player: Array[PlayerState] = []
@export var entities_by_id: Dictionary = {}     # int entity_id -> EntityState (typed dict OK, 4.4+)
@export var next_entity_id: int = 0
@export var active_player: int = 0
@export var round_number: int = 1
@export var match_status: int = MatchStatus.IN_PROGRESS   # enum

enum MatchStatus { IN_PROGRESS, GAME_OVER }

# --- read (side-effect-free) — names match game-state-turn-manager.md public interface exactly ---
func current_ap(player: int) -> int
func entities() -> Array[EntityState]                     # public accessor over entities_by_id (matches GDD)
func entity_at(tile: Vector2i) -> EntityState             # null if empty; delegates to grid.occupant_at
func faction_of(player: int) -> FactionDef

# --- simulate ---
func clone() -> GameState:
    return duplicate_deep() as GameState                   # deep-copy confirmed (see Engine Compatibility)

# --- mutate (sole vector — full contract defined in ADR-0002) ---
func apply_action(action: Action) -> ActionResult
func end_turn() -> ActionResult                            # unconditionally legal, no softlock

# --- control ---
static func start_match(map: MapDefinition, starting_player: int) -> GameState

class PlayerState extends Resource:
    @export var faction: FactionDef
    @export var current_ap: int = 0                        # sole writer: AP Economy.spend() + turn-reset
    @export var income_this_turn: int = 0                  # sole writer: AP Economy start-of-turn snapshot
    @export var has_attack_tech: bool = false               # sole writer: Research
    @export var has_defense_tech: bool = false
    @export var has_economy_tech: bool = false

class EntityState extends Resource:                        # base; ADR-0007 defines Unit/Structure specializations
    @export var entity_id: int
    @export var owner: int
    @export var position: Vector2i
```

```gdscript
# MatchService — Autoload, logic-free lookup only
extends Node
var current: GameState = null
func get_current() -> GameState: return current
func set_current(state: GameState) -> void: current = state
# No other methods. No validation, no mutation, no signals of its own — Presentation
# reads `current` once at _ready() and otherwise talks to the GameState instance directly.
```

## Alternatives Considered

### Alternative 1: Autoload singleton holding full authority
- **Description**: A global Autoload (e.g. `Game`) both stores and mutates the one true match state.
- **Pros**: Idiomatic quick-and-easy Godot global access; zero reference-passing anywhere.
- **Cons**: A singleton models exactly one live instance well, but this project needs *many*
  simultaneous independent instances (the AI's `clone()` for lookahead, and every unit test) —
  fighting a singleton to hold "the other" instances is awkward. Also directly conflicts with the
  coding standard against Autoload-coupled singletons.
- **Rejection Reason**: Structurally hostile to `clone()`-based AI lookahead and headless testing,
  the project's two hardest technical requirements.

### Alternative 2: RefCounted + hand-written clone()
- **Description**: `GameState extends RefCounted`; `clone()` is a manually written method copying
  every field.
- **Pros**: No Resource semantics to reason about at all (no `@export`/storage-flag discipline).
- **Cons**: `RefCounted` has no built-in deep-copy — every field addition requires remembering to
  update the hand-written `clone()`, and a forgotten field fails *silently* (the AI or a test simply
  doesn't see it, rather than erroring).
- **Rejection Reason**: Manual-sync regression risk on the single most safety-critical operation in
  the codebase. `Resource.duplicate_deep()` gives the same deep copy for the cost of one storage
  flag per field — a much cheaper discipline than a hand-maintained method, and the failure mode
  (forgotten `@export`) is far more test-visible (state-equality tests will fail cleanly for a
  missing field, since it silently reverts to the class default rather than silently keeping the
  old value).

### Alternative 3: Event-bus-core (a global bus IS the singleton; state is data attached to it)
- **Description**: A global signal-bus Autoload owns both the change-notification channel and the
  GameState instance together as one construct.
- **Pros**: Unifies "where state lives" and "how changes propagate" into one answer.
- **Cons**: Conflates two genuinely separate concerns — state *ownership* (this ADR) and *event
  propagation* (ADR-0004). It also drags a global-bus dependency into every unit test that just
  wants to construct a bare `GameState` and call `apply_action` on it.
- **Rejection Reason**: Violates single-responsibility; makes the state model harder to instantiate
  standalone in tests for no compensating benefit. Event architecture is designed separately in
  ADR-0004, which can freely choose typed signals emitted directly by `GameState` — no bus object
  required to be the state's owner.

### Alternative 4: Entities as plain Dictionaries (no Resource wrapper)
- **Description**: Each entity is a bare `Dictionary` of fields rather than a typed class.
- **Pros**: `Dictionary.duplicate(true)` is a native deep copy, so this works fine even under
  Alternative 2's hand-written clone.
- **Cons**: Loses static typing and autocomplete on every entity field access — this fights the
  project's static-GDScript-typing convention directly, and entity fields are read in the AI's
  hottest per-turn loops (TR-unit-014 explicitly calls out static typing for these hot paths).
- **Rejection Reason**: Typed `Resource` entities cost nothing extra once `duplicate_deep()` is
  already the chosen clone mechanism, and preserve type safety where it matters most.

### Alternative 5: Separate injectable EntityIdAllocator
- **Description**: A standalone allocator object generates `entity_id`s, passed into `GameState`.
- **Pros**: More isolatable in a unit test that wants to fake ID generation.
- **Cons**: A second object that must itself be included in `clone()` and kept perfectly in sync —
  disproportionate machinery for a single incrementing integer.
- **Rejection Reason**: The counter is trivially part of `GameState`'s own state; making it a
  separate object buys negligible testability for real synchronization risk.

## Consequences

### Positive
- Full headless testability: `GameState.new()` requires no scene tree, no Autoload, no rendering.
- `clone()` is one line, engine-native, and automatically covers every future field — no
  clone-maintenance debt as the state model grows across 12 systems.
- No Autoload holds authority, satisfying the DI-over-singletons coding standard for the piece of
  state every other system depends on.
- Static typing preserved throughout, including in AI hot-loop entity reads.
- Serializability (a save/load precondition) falls out for free — `Resource` fields are already
  storage-flagged for `duplicate_deep()`, which is most of the work a future `.tres`/save format needs.

### Negative
- Every field on `GameState`, `PlayerState`, and `EntityState` **must** be declared with storage
  usage (`@export` or equivalent) or it is silently excluded from `duplicate_deep()` — a discipline
  burden, though one a state-equality unit test catches immediately (see Validation Criteria).
- `Resource` carries marginally more overhead than bare `RefCounted` (negligible for a turn-based,
  not-per-frame-critical simulation).
- `MatchService`, even though intentionally inert, is still global mutable state (a reference
  holder) — the team must resist ever adding logic to it; that discipline is a process risk, not
  a technical one.

### Risks
- **`duplicate_deep()` nested-in-container behavior — CONFIRMED** (godot-specialist, 2026-07-23,
  against live 4.6 docs): the default `DEEP_DUPLICATE_INTERNAL` mode recursively duplicates nested
  arrays/dictionaries and the path-less runtime Resource instances inside them. Residual (low): docs
  give no Dictionary-*value*-specific worked example. Mitigation unchanged — the clone-isolation unit
  test (Validation Criteria) runs *before* any other Foundation ADR builds on `clone()`; if it ever
  failed, the entity container would be restructured to an `Array[EntityState]` or wrapper Resource.
- **Typed Dictionaries (`Dictionary[int, EntityState]`) — RESOLVED** (godot-specialist, 2026-07-23):
  confirmed supported since Godot 4.4, so the entity container may be typed directly. The untyped-
  `Dictionary`-behind-typed-accessors fallback (`entities()`, `entity_at()`) remains available but is
  no longer forced. Either way, the public read API stays statically typed.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-state-turn-manager.md | TR-gamestate-001: single authoritative model held independent of scene tree | `GameState extends Resource`, constructed via `.new()`, never a `Node` |
| game-state-turn-manager.md | TR-gamestate-002: headless instantiable/mutable/queryable | No rendering dependency anywhere in the class |
| game-state-turn-manager.md | TR-gamestate-003: `clone()` deep-copy | `duplicate_deep()` cast to `GameState`, one call |
| game-state-turn-manager.md | TR-gamestate-011: side-effect-free read API | Read methods listed in Key Interfaces are pure getters |
| game-state-turn-manager.md | TR-gamestate-014: `faction_of`/`starting_loadout` at Setup, locked | `PlayerState.faction` field; lock enforced by ADR-0002's `apply_action` validation (Setup→PlayerTurn transition rejects re-assignment) |
| game-state-turn-manager.md | TR-gamestate-015: every field plain/serializable, no engine object refs | All fields are `int`/`enum`/`Vector2i`/typed-Resource — no `Node`/`RID` anywhere |
| game-state-turn-manager.md | TR-gamestate-016: optional `MAX_ROUNDS`/`TIEBREAK_METRIC` | `round_number` field + terminal-predicate hook (logic in ADR-0002) |
| game-state-turn-manager.md | TR-gamestate-017: `end_turn()` never softlocks | Declared unconditionally legal in the Key Interfaces contract |
| game-state-turn-manager.md | TR-gamestate-019: state-model location open question | **Resolved by this ADR**: no Autoload authority; plain injected `Resource` + thin lookup Autoload |
| grid-terrain.md | TR-grid-005: grid decoupled from render node | `GridState` held as a field on `GameState`, itself a non-Node `Resource` |
| grid-terrain.md | TR-grid-006: grid owned by Game State & Turn Manager | `grid: GridState` field on `GameState` |

## Performance Implications
- **CPU**: `clone()` cost scales with entity count and per-Resource duplication overhead;
  `duplicate_deep()` walks every storage-flagged field recursively. The exact per-clone cost and its
  effect on the AI's evaluate→commit loop budget (QQ-06) is measured, not set, by ADR-0011 — this
  ADR only establishes the mechanism.
- **Memory**: Each `clone()` is a fully independent copy of grid + all entities + all per-player
  state. For an AI loop that clones once per candidate-action evaluation, this can add up across a
  turn; ADR-0011's perf spike must account for it.
- **Load Time**: Negligible — no disk I/O at runtime; the only disk load is the map definition,
  owned by Grid & Terrain (ADR-0005).
- **Network**: N/A — no multiplayer in scope.

## Migration Plan
N/A — greenfield decision, no existing code to migrate.

## Validation Criteria
- **Clone-isolation test**: construct a `GameState`, `clone()` it, mutate an entity's `position`
  and a `PlayerState.current_ap` on the clone — assert the original is unchanged and vice versa.
  This is the single most important test in the project; it must pass before any other Foundation
  ADR's code is built on `clone()`.
- **Determinism test**: two `clone()` calls on the same unmodified state produce field-wise-equal
  results (no accidental shared object identity between clones).
- **Headless test**: `GameState.new()` runs `apply_action()` successfully with zero `Node`/scene
  tree present in the test process.
- **Engine spike** (resolves the residual in Verification Required): confirm `duplicate_deep()`
  recursively deep-copies `Resource` instances stored as *Dictionary values*, not only direct
  exported `Resource`-typed properties, on the pinned Redot 26.2 build.

## Related Decisions
- ADR-0002: Action / `apply_action` command model (defines the mutation logic this ADR's method
  signature stubs out)
- ADR-0003: Deterministic simulation & RNG isolation
- ADR-0004: Event/signal architecture (what `MatchService`/`GameState` emit on mutation)
- ADR-0005: Grid representation & map-definition format (`GridState` internals)
- ADR-0007: Data-driven entity/stat schema (specializes `EntityState` into Unit/Structure)
- ADR-0012: Faction Identity cross-cutting fold (`PlayerState.faction` storage + lock semantics)
- `docs/architecture/architecture.md` — Module Ownership section should be refined from
  "RefCounted, NOT Node" to "Resource (extends RefCounted), NOT Node" once this ADR is Accepted
