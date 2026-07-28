# Story 001: GameState Core — Data Model, Read API & clone()

> **Epic**: Game State & Turn Manager
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/game-state-turn-manager.md`
**Requirement**: `TR-gamestate-001`, `TR-gamestate-002`, `TR-gamestate-003`, `TR-gamestate-011`, `TR-gamestate-015`, `TR-gamestate-019`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: State Model Ownership & Lifecycle
**ADR Decision Summary**: `GameState extends Resource`, constructed only via `.new()` at runtime (never loaded from disk). `clone()` is `duplicate_deep()` cast to `GameState` — one call. No Autoload holds authoritative state (DI); `MatchService` is a thin, logic-free lookup pointer only. Entities are typed `Resource` subclasses in a container so one `duplicate_deep()` deep-copies the whole state.

**Secondary ADRs**:
- ADR-0003 (Determinism & RNG isolation): every field must be `int`/`enum`/`Vector2i`/typed-Resource — no float anywhere in state; enables byte-identical clone/determinism.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: `Resource.duplicate_deep()` (Godot 4.5, post-cutoff) default `DEEP_DUPLICATE_INTERNAL` mode recursively deep-copies nested arrays/dictionaries and path-less runtime `.new()` Resource instances — **confirmed against live 4.6 docs** (ADR-0001 Engine Compatibility). Residual risk (low): docs give no Dictionary-*value*-specific worked example, so the clone-isolation test below is the gate that de-risks it. Typed `Dictionary[int, EntityState]` is supported since Godot 4.4. **Every field must carry `@export` (storage usage) or it is silently excluded from `duplicate_deep()`.**

**Control Manifest Rules (this layer)**:
- Required: "`GameState` must extend `Resource` and be constructed only via `.new()` at runtime — never loaded from disk" — source: ADR-0001
- Required: "`clone()` must be implemented as `duplicate_deep()` cast to `GameState` — one call, no hand-written per-field copy" — source: ADR-0001
- Required: "Every field on `GameState`/`PlayerState`/`EntityState` must carry `@export` (storage usage)" — source: ADR-0001, ADR-0007
- Required: "Entities must be small typed `Resource` subclasses (`EntityState`), never bare Dictionaries" — source: ADR-0001
- Required: "No Autoload may hold authoritative `GameState`; the authoritative instance is created by a match-bootstrap script and passed by reference (DI)" — source: ADR-0001
- Required: "`MatchService` (Autoload) must stay a thin, logic-free lookup pointer: get/set current state only, no mutation/validation/signals" — source: ADR-0001
- Required: "`GameState` must expose a side-effect-free read API: `active_player`, `current_ap(player)`, `round_number`, `match_status`, `entities()`, `entity_at(tile)`, `grid`, `faction_of(player)`" — source: ADR-0001
- Required: "`entity_id` must be a single incrementing `int` field (`next_entity_id`) on `GameState`" — source: ADR-0001
- Required: "All state must be 100% integer — every field is `int`/`enum`/`Vector2i`, no float ever" — source: ADR-0003
- Required: "`entities()` iteration must be in `entity_id` order (stable)" — source: ADR-0007, ADR-0003
- Guardrail: "`GameState` reads are O(1) except `entities()`, which is O(n log n) per call (sorts by `entity_id`); acceptable at VS entity counts — the AI sorts owned ids once per turn (ADR-0011), never relying on `entities()` being O(1)" — source: ADR-0001, ADR-0003, ADR-0011
- Forbidden: "Never use an Autoload singleton holding full authority over `GameState`" — source: ADR-0001
- Forbidden: "Never use `RefCounted` + a hand-written `clone()`" — source: ADR-0001
- Forbidden: "Never represent entities as plain Dictionaries" — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-turn-manager.md`, scoped to this story:*

- [ ] **GIVEN** a headless instantiation with no rendering node, **WHEN** a `GameState` is constructed via `.new()` and queried, **THEN** all reads function correctly (render-decoupled, not a `Node`).
- [ ] **GIVEN** a `GameState` with entities and per-player state, **WHEN** `clone()` is called and an entity's `position` and a `PlayerState.current_ap` are mutated on the clone, **THEN** the original is unchanged and vice versa (the clone-isolation test — ADR-0001's most critical test).
- [ ] **GIVEN** the same unmodified state, **WHEN** `clone()` is called twice, **THEN** the two clones are field-wise equal with no shared object identity between them (determinism of clone).
- [ ] **GIVEN** a `GameState`, **WHEN** the read API is queried (`active_player`, `current_ap(player)`, `round_number`, `match_status`, `entities()`, `entity_at(tile)`, `grid`, `faction_of(player)`), **THEN** each returns the correct value and mutates nothing (side-effect-free).
- [ ] **GIVEN** `entities()` is called, **THEN** entities are returned in stable `entity_id` order.
- [ ] **GIVEN** the state model, **WHEN** every field is inspected, **THEN** all are plain serializable values (`int`/`enum`/`Vector2i`/typed-Resource) — no `Node`/`RID`/float references.

---

## Implementation Notes

*Derived from ADR-0001 Key Interfaces:*

```gdscript
class_name GameState extends Resource
@export var grid: GridState                       # ADR-0005 (Grid epic — DONE)
@export var per_player: Array[PlayerState] = []
@export var entities_by_id: Dictionary = {}       # int entity_id -> EntityState (typed dict OK, 4.4+)
@export var next_entity_id: int = 0
@export var active_player: int = 0
@export var round_number: int = 1
@export var match_status: int = MatchStatus.IN_PROGRESS
enum MatchStatus { IN_PROGRESS, GAME_OVER }

func current_ap(player: int) -> int
func entities() -> Array[EntityState]             # stable entity_id order
func entity_at(tile: Vector2i) -> EntityState     # null if empty; delegates to grid.occupant_at + entities_by_id
func faction_of(player: int) -> FactionDef
func clone() -> GameState: return duplicate_deep() as GameState

class PlayerState extends Resource:
    @export var faction: FactionDef
    @export var current_ap: int = 0
    @export var income_this_turn: int = 0
    @export var has_attack_tech: bool = false
    @export var has_defense_tech: bool = false
    @export var has_economy_tech: bool = false
    # is_ai_controlled (ADR-0011) + faction lock semantics: the FIELD is declared here;
    # the Setup->PlayerTurn LOCK enforcement lives in apply_action (Story 002).
    @export var is_ai_controlled: bool = false

class EntityState extends Resource:                # base; ADR-0007 later specializes into Unit/Structure
    @export var entity_id: int
    @export var owner: int
    @export var position: Vector2i
```

```gdscript
# MatchService — Autoload, logic-free lookup only:
extends Node
var current: GameState = null
func get_current() -> GameState: return current
func set_current(state: GameState) -> void: current = state
# No other methods. No validation, no mutation, no signals.
```

- `entity_at(tile)` resolves via `grid.occupant_at(tile)` → `entities_by_id[id]` (the id-based occupancy from ADR-0005 keeps `clone()` sound — never store `EntityState` refs in the grid).
- `entities()` must sort by `entity_id` ascending for stable iteration (ADR-0003 forbids relying on Dictionary hash/insertion order).
- **Read-API complexity (performance contract).** All reads are side-effect-free with these bounds, in entity count `n`:
    - `active_player`, `round_number`, `match_status`, `grid` — field access, **O(1)**.
    - `current_ap(player)`, `faction_of(player)` — `per_player[player]` array index, **O(1)**.
    - `entity_at(tile)` — `grid.occupant_at(tile)` (O(1), ADR-0005) → `entities_by_id[id]` Dictionary lookup (O(1)) = **O(1)**.
    - `entities()` — snapshots `entities_by_id.values()` and sorts ascending by `entity_id` = **O(n log n) per call** (the sort is mandated by ADR-0003's ban on Dictionary hash/insertion order; it is not cached, so each call re-sorts).
  `entities()` is the only non-constant read. This is acceptable at Vertical-Slice entity counts (a turn-based match holds ~dozens of entities on a 14×16 board), and turn-based play has no per-frame simulation deadline. **The AI does not rely on `entities()` being O(1):** per ADR-0011 (§ "Entity iteration order"), `choose_action` collects the active player's owned entity ids and sorts them **once per turn**, not per query — and ADR-0011's flagged dominant cost (OQ-1, candidate-move enumeration) is downstream of this method, not in it. If profiling ever shows the per-call sort is hot, the fix is to maintain an incrementally-sorted id list on insert/remove (O(1) amortized reads) — deferred until measured, not pre-optimized here.
- `FactionDef` is a template Resource (ADR-0007/0012). If the type isn't available yet, declare the field typed and note the forward-declared dependency — but the field must exist for `faction_of` to return it.
- `apply_action`/`end_turn`/`start_match`/`start_turn` are declared in later stories — do NOT implement them here (stub or omit; this story is the data model + read + clone only).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `apply_action` pipeline, `Action`/`ActionResult` types, faction Setup-lock *enforcement*, `action_applied` signal.
- Story 003: `start_match`, `start_turn` 4-step sequence, `EndTurnAction.apply`, round increment.
- Story 004: `run_win_check`, `MAX_ROUNDS`/`TIEBREAK_METRIC` terminal conditions.
- ADR-0007's `UnitState`/`StructureState` specializations of `EntityState` (a later entity-schema epic) — only the `EntityState` base belongs here.

---

## QA Test Cases

**Test file**: `tests/unit/game_state_core_test.gd` (~10 unit tests)

- Headless construction via `.new()` (not a `Node`) — all reads function with no scene tree.
- **Clone-isolation** (the critical ADR-0001 test): clone an entity's `position` and a
  `PlayerState.current_ap` on the clone; assert the original is unchanged, and vice versa.
- **Clone-determinism**: clone the same unmodified state twice; assert field-wise equality with
  no shared object identity (`!=` on object refs, `==` on values).
- Read API side-effect-freedom: `active_player`, `current_ap(player)`, `round_number`,
  `match_status`, `entities()`, `entity_at(tile)`, `grid`, `faction_of(player)` each return the
  correct value and mutate nothing observable.
- `entities()` returns entities in stable `entity_id` ascending order (not Dictionary insertion/hash order).
- Every field on `GameState`/`PlayerState`/`EntityState` is a plain serializable value
  (`int`/`enum`/`Vector2i`/typed-Resource) — no `Node`/`RID`/float.

Edge cases: empty `GameState` (no entities) — `entities()` returns `[]`, `entity_at()` returns
null; `clone()` on a zero-entity state; `entity_at(tile)` for an out-of-bounds/unoccupied tile.

Full plan: `production/qa/qa-plan-sprint-1-2026-07-26.md`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/game_state_core_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/unit/game_state_core_test.gd` (12 tests, 87/87 suite green)

---

## Dependencies

- Depends on: Grid & Terrain Story 001 (`GridState`) — **DONE** (`GameState` holds `grid: GridState`)
- Unlocks: Story 002

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 6/6 passing (0 deferred, 0 untested)
**Deviations**: None blocking. Three advisory items surfaced by `/code-review`, all Story-002 forward-looking (logged to `docs/tech-debt-register.md`): (1) `current_ap`/`faction_of` throw on out-of-range player index — undocumented contract; (2) `entities_by_id` could be tightened to typed `Dictionary[int, EntityState]`; (3) occupancy/entities desync path in `entity_at` degrades safely to null but is untested. Class-per-file structure (vs ADR-0001's illustrative nested inner classes) is a deliberate convention matching ADR-0002/0007 — not a deviation.
**Test Evidence**: Logic — `tests/unit/game_state_core_test.gd` (12 tests; full suite 87/87, exit 0).
**Code Review**: Complete — `/code-review` verdict APPROVED WITH SUGGESTIONS (godot-gdscript-specialist: CLEAN; qa-tester: complete AC + QA-case coverage). No blocking findings.
**Files**: `src/core/game_state/{game_state,player_state,entity_state,match_service}.gd`, `src/core/faction/faction_def.gd`, `tests/unit/game_state_core_test.gd`.
