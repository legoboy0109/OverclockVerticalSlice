# ADR-0010: Combat Resolution & Shared Destruction / Win-Check

## Status
Proposed

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Combat-logic (pure deterministic state mutation — NO engine physics) |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md` (to confirm irrelevance), `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — integer arithmetic, `Array`/`RefCounted` typed events, and plain control flow over the ADR-0001 state model. No `PhysicsServer2D`, no Jolt, no hit-testing: combat is a logical grid-and-integer resolution, not a physics interaction |
| **Verification Required** | None. **godot-specialist review 2026-07-24 (CONFIRMED, no blocking issues):** the static-utility `class_name Combat extends RefCounted` with nested `class TargetResult extends RefCounted` + `enum BlockedReason`, `GameState.destroy_entity()` doing `entities_by_id.erase()` + `grid.remove()` mid-`apply_action` (never mid-iteration, so no concurrent-modification risk), typed `Array[Event]` accumulation, `max()` on ints, and `is UnitState`/`is StructureState` runtime type checks are all idiomatic GDScript 4.6 with no 4.4–4.6 behavior change. `is` (script-class inheritance check) is explicitly the correct idiom and is distinct from the banned `get_class()` *string-dispatch* pattern |

Godot's 2D physics (and the 4.6 Jolt-default change) is **not used** — per `technical-preferences.md`,
grid tactics has no physics simulation. Combat "line of fire" is a tile walk over `GridState`, not a
raycast; "range" is integer `manhattan_distance` / cardinal step count, not a collision query. This is
called out explicitly so no future contributor reaches for `PhysicsServer2D` ray/shape queries here
(see forbidden-pattern candidate in the registry step).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState`/`EntityState`/`entities_by_id`/`entity_at`; `destroy_entity()` lives on the mutation layer this ADR defines), ADR-0002 (verb-handler contract — `Combat.validate()`/`apply()` are the `AttackAction` handlers; this ADR refines ADR-0002 step 6 `run_win_check`), ADR-0003 (determinism: integer-only damage, stable iteration, field-wise clone equality), ADR-0005 (`GridState.occupant_at()`/`is_cover()`/`manhattan_distance()`/`neighbors()`/`remove()`), ADR-0006 (`AP.can_afford()`/`spend()` for `attack_cost`), ADR-0007 (`UnitState`/`StructureState` schema — `attack_range`/`min_range`/`targeting_mode`/`defense`/`can_counterattack`/`has_attacked`/`current_hp`; supplies the forward-declared `effective_attack()`) |
| **Enables** | ADR-0011 (AI scores candidate attacks via `legal_targets()`/`preview_damage()` on cloned states), ADR-0015 (Command FSM renders the target overlay + damage preview + 3 blocked-shot states), ADR-0016 (HUD hp-drain/damage-number/death-burst driven by this ADR's Destroyed/GameOver events) |
| **Blocks** | Combat Resolution epic (`combat-001..009/012/014`); the Base & Production **Defensive-Structure-as-attacker** + **structure-damage/HQ-destruction** stories (`baseprod-010/011/012`); the Research **Lab-destruction-revert** story (`research-008`) — all ride this ADR's `attack()` pipeline and `destroy_entity()` hook |
| **Ordering Note** | Per the TD's 2026-07-23 sign-off, the ranged-combat balance spike is a **design/tuning** gate on the numbers, not on this ADR's structure — ADR-0010 may be Accepted before the spike (it ships the ranged model as OFF-by-default-tuned infrastructure). `min_range`/`targeting_mode`/`defense`/`can_counterattack` schema fields are owed by ADR-0007 (TR-combat-010/011) and must be Accepted alongside or before this ADR |

## Context

### Problem Statement

Combat must resolve every attack deterministically (no RNG) — targeting (two profiles: DIRECT
cardinal-line-first-blocker, and an optional AREA ring with a dead zone), a single integer damage
formula with cover + defense mitigation and a min-1 floor, an optional non-recursive counterattack, and
immediate same-step death/removal — all through the ADR-0002 `apply_action` pipeline so an illegal or
unaffordable attack is atomically rejected. Two other systems hang off combat's death step: **Grid**
occupancy must clear the tile in the same step, and **Research** must revert an in-progress tech to Not
Started when its Lab is destroyed — *synchronously, in the same `apply_action`* (research-tech.md Rule
6). And **HQ** destruction must trigger the Turn Manager's `GameOver` win-check within that same commit.
The architectural question is how to make destruction a single shared hook (so Combat is not the only
thing that can kill, and Research's revert is not bolted onto Combat) while keeping the whole thing one
atomic, deterministic, clone-safe step.

### Constraints

- No RNG anywhere; integer-only damage; results identical across `clone()`d states (ADR-0003).
- Every mutation flows through `apply_action` → `Combat.apply()`; `validate()` is pure and total
  (`mutation_in_validate` forbidden).
- Combat must never read Research state directly (GDD Dependencies) — the attack buff arrives folded
  into `effective_attack`.
- Structures are **cover-immune** (Rule 6) — the damage formula must branch on defender kind.
- Death/removal + Lab-revert + win-check must all be in the **same** `apply_action` as the killing
  damage (research-008, gamestate-010, combat-007/008).

### Requirements

- `Combat.legal_targets(state, unit)` and the hypothetical-origin overload
  `legal_targets(state, unit, from_tile)` — both pure/side-effect-free.
- `Combat.preview_damage(state, attacker, target) -> int` — pure, exactly equals committed damage.
- `Combat.validate()/apply()` for `AttackAction` (verb-handler contract), accepting a **unit or a
  Defensive Structure** as attacker.
- A shared `destroy_entity()` hook covering Grid removal + type-keyed on-destroy effects (Lab-revert).
- HQ destruction → `GameOver` via ADR-0002's `run_win_check`, same commit.
- Three queryable blocked-shot reasons (blocked-by-friendly / out-of-range / inside-dead-zone).

## Decision

**Combat is a static utility class** (`class_name Combat extends RefCounted`, no instance state),
mirroring ADR-0006's `AP` and ADR-0009's `Movement` (`movement_search_module_shape`). All entry points
take `state` explicitly, so the identical code runs on the authoritative state and any AI clone.

**1. Damage formula (integer, one function, structure-cover-immune):**

```
damage = max(MIN_DAMAGE, effective_attack(state, attacker) − cover_reduction(state, defender) − defense(defender))
cover_reduction = COVER_DR  iff defender is a UnitState on an is_cover tile ; else 0  (always 0 for StructureState)
```

`MIN_DAMAGE = 1` and `COVER_DR = 1` are **Combat-owned** constants living in a `CombatConfig` Resource
(the `gameplay_config_storage` pattern — a dedicated `.tres`, loaded by the thin `Balance`-style
Autoload, never on `GameState`, never deep-copied on the AI clone path). `defense` is read off the
entity schema (ADR-0007). `effective_attack(state, entity)` is a **forward-declared Unit-owned
contract** (base attack from `UnitTypeDef` + `RESEARCH_ATK_BONUS` when the owner has `has_attack_tech`)
— Combat calls it and never touches research state directly, exactly as ADR-0006 forward-declared
`completed_outpost_count()` for ADR-0007 to implement.

**2. Targeting (two profiles), all built on `GridState` (ADR-0005):**
- **DIRECT** (VS default): walk tiles outward along each of the 4 cardinals up to `attack_range`; the
  **first occupied or Impassable tile stops the walk**; if that first blocker is an enemy within range,
  it is the sole target that direction (nearest-only, no pierce). Cardinal-line distance.
- **AREA** (dormant infra): any enemy-occupied tile with `min_range ≤ manhattan_distance ≤ attack_range`
  is targetable; **ignores line-of-fire**; single-target. Schema invariant `min_range ≤ attack_range`
  is enforced by ADR-0007 (TR-combat-011); a violating unit yields an empty target set surfaced as a
  validation error, never a silent soft-lock.

`legal_targets(state, unit)` returns `Array[TargetResult]` (target entity_id + tile). The
`legal_targets(state, unit, from_tile)` overload evaluates the identical rules **as if the unit stood
on `from_tile`** — pure, moves nothing — backing the Command interface's honest "can attack after
moving here" preview; when `from_tile == unit.position` it is identical to the zero-arg form.
`preview_damage()` runs the damage formula without mutating. Blocked-shot reasons are returned as a
queryable `BlockedReason` enum per direction/tile so the UI renders the three distinct states.

**3. `attack()` pipeline (the `AttackAction` verb handler), attacker-polymorphic:**

`Combat.apply()` runs the fixed ordered pipeline (GDD States & Transitions) — primary damage → primary
death → conditional single counter → counter death — then returns typed events; `apply_action` (ADR-0002)
runs `run_win_check` at step 6. The attacker may be a `UnitState` **or** a `StructureState` (the
Defensive Structure); the only difference is the AP charged — units spend Combat's `attack_cost` (2 AP),
the Defensive Structure spends Base-&-Production-owned `DEFENSIVE_ATTACK_COST` (1 AP), resolved by the
verb handler reading the attacker kind. The counter step fires at most **once, non-recursively** (a
structural property of the straight-line pipeline — not a runtime guard flag) and only when the defender
survived, has `can_counterattack == true`, and the attacker is a legal target under the *defender's own*
profile/range. Counters are free (no AP, set no `has_attacked`).

**4. Shared `destroy_entity()` — the load-bearing cross-system hook.** Death/removal is **not**
Combat-owned. It is a single mutation-layer routine `GameState.destroy_entity(entity_id) -> Array[Event]`
(a `GameState` method, matching the ADR-0008 precedent of putting turn-boundary orchestration on
`GameState`), called from inside `Combat.apply()` whenever a piece reaches 0 hp. It performs, in order:
(a) if the entity is a `StructureState` that is a Research Lab with an active `current_research_target`,
call the **forward-declared** `Research.on_lab_destroyed(state, lab)` (which reverts that target to Not
Started, no refund — research-008); (b) `GridState.remove(position)` to clear occupancy; (c) drop the
entity from `entities_by_id` / mark destroyed; (d) append `UnitDestroyedEvent` or
`StructureDestroyedEvent{entity_id, is_hq}`. Because it runs inside the same `apply_action`, Grid
removal, Lab-revert, and the destruction event are all one atomic, synchronous, same-step effect — no
polling, no post-commit signal handler, no observer-order dependence. Any future killer (an AoE unit, a
hazard) reuses the identical hook; Research's revert lives with the Lab type via the forward-declared
contract, not inside Combat.

**5. HQ win-check (refines ADR-0002 step 6).** `run_win_check(state, events)` scans the commit's
`events` for a `StructureDestroyedEvent` with `is_hq == true` and, if found, sets
`match_status = GameOver(winner = opponent)` and appends a `GameOverEvent` (ADR-0004). Combat deals the
damage and emits the destruction event; the Turn Manager owns the win *rule* (GDD Rule 9). This pins the
detection mechanism ADR-0002 left unspecified ("HQ at 0 hp") to the event the destruction hook already
emits — no separate HQ hp re-scan. Non-HQ destruction emits no `GameOverEvent`.

### Architecture Diagram

```
  AttackAction ──apply_action (ADR-0002)──▶ Combat.validate() [PURE] ─ok─▶ Combat.apply()
                                                                              │
     ┌────────────────────────────────────────────────────────────────────────┤
     │ 3 spend attack_cost | DEFENSIVE_ATTACK_COST (AP, ADR-0006)               │
     │ 4 primary damage = max(1, effective_attack − cover − defense)  ──────────┤
     │ 5 if defender hp≤0 ─▶ GameState.destroy_entity(defender_id) ─────────────┤
     │ 6 conditional single counter (defender.can_counterattack & in-profile)   │
     │ 7 if attacker hp≤0 ─▶ GameState.destroy_entity(attacker_id) ─────────────┤
     └────────────────────────────────────────────────────────────────────────┘
                                             │  returns Array[Event]
   GameState.destroy_entity(id):             ▼
     (a) Lab? ─▶ Research.on_lab_destroyed()  run_win_check(state, events)  [ADR-0002 step 6]
     (b) GridState.remove(pos)                  └─ StructureDestroyedEvent{is_hq}? ─▶
     (c) drop from entities_by_id                   match_status = GameOver + GameOverEvent
     (d) emit Unit/StructureDestroyedEvent
                                             ▼
                        ActionResult{ok, events} ─action_applied signal (ADR-0004)─▶ HUD / Renderer
   legal_targets(state, unit[, from_tile]) / preview_damage(state, a, t)  ─▶ ADR-0015 UI · ADR-0011 AI
```

### Key Interfaces

```gdscript
class_name Combat extends RefCounted

enum BlockedReason { NONE, BLOCKED_BY_FRIENDLY, OUT_OF_RANGE, INSIDE_DEAD_ZONE }

class TargetResult extends RefCounted:
    var target_id: int
    var tile: Vector2i
    func _init(id: int, t: Vector2i) -> void: target_id = id; tile = t

# --- Pure queries (side-effect-free; callable on authoritative state or any clone) ---
static func legal_targets(state: GameState, attacker: EntityState) -> Array[TargetResult]
static func legal_targets_from(state: GameState, attacker: EntityState, from_tile: Vector2i) -> Array[TargetResult]  # hypothetical origin; == legal_targets when from_tile == attacker.position
static func preview_damage(state: GameState, attacker: EntityState, target: EntityState) -> int  # exactly == committed damage
static func blocked_reason(state: GameState, attacker: EntityState, dir_or_tile) -> BlockedReason  # UI classification

static func damage(state: GameState, attacker: EntityState, defender: EntityState) -> int:
    var cover := CombatConfig.COVER_DR if (defender is UnitState and state.grid.is_cover(defender.position.x, defender.position.y)) else 0
    return max(CombatConfig.MIN_DAMAGE, effective_attack(state, attacker) - cover - defender.defense)

# --- Verb handler (ADR-0002 contract), attacker may be UnitState or Defensive StructureState ---
static func validate(state: GameState, action: AttackAction) -> int:   # -> Reason enum, PURE, total
    # can_attack (not has_attacked) · can_afford(cost) · target is a legal enemy in legal_targets(...)
    return Reason.OK

static func apply(state: GameState, action: AttackAction) -> Array[Event]:   # assumes validated
    var attacker := state.entity_at(action.attacker_tile)
    var defender := state.entity_at(action.target_tile)
    var cost := StructureTypes.DEFENSIVE_ATTACK_COST if attacker is StructureState else CombatConfig.ATTACK_COST
    AP.spend(state, attacker.owner, cost)                 # ADR-0006
    attacker.has_attacked = true
    var events: Array[Event] = []
    _apply_hit(state, attacker, defender, events)         # primary damage + primary destroy_entity
    if _defender_may_counter(state, attacker, defender):  # alive & can_counterattack & attacker in-profile
        _apply_hit(state, defender, attacker, events)     # single free counter; no AP, no has_attacked
    return events
# _apply_hit() and _defender_may_counter() are static (Combat is never instantiated).

# Forward-declared Unit-owned contract — implemented by the Unit/Research epic, NOT this ADR:
# effective_attack(state, entity) -> int  ==  base_attack(entity.type) + (RESEARCH_ATK_BONUS if owner has_attack_tech else 0)
static func effective_attack(state: GameState, attacker: EntityState) -> int   # forward-declared

# --- Shared destruction hook: GameState method (mutation layer), NOT Combat-owned ---
# class_name GameState (ADR-0001) — added by this ADR. Called only from inside a verb
# handler's apply() (never mid-iteration over entities_by_id), so the erase() below is
# concurrent-modification-safe.
func destroy_entity(entity_id: int) -> Array[Event]:
    var e: EntityState = entities_by_id[entity_id]        # entities_by_id is Dictionary[int, EntityState] (ADR-0001)
    var evts: Array[Event] = []
    # ORDERING (load-bearing): the Lab-revert runs while the Lab is STILL live in Grid +
    # entities_by_id — on_lab_destroyed may read lab.position/owner/fields; removal is (b)/(c) below.
    if e is StructureState and e.is_research_lab() and e.current_research_target != null:
        Research.on_lab_destroyed(self, e)                # forward-declared; reverts target -> Not Started, no refund
    grid.remove(e.position)                               # (b) ADR-0005 occupancy clear, same step
    entities_by_id.erase(entity_id)                       # (c)
    if e is StructureState:
        evts.append(StructureDestroyedEvent.new(entity_id, e.is_hq()))
    else:
        evts.append(UnitDestroyedEvent.new(entity_id))
    return evts

# New Event subclasses (ADR-0004 contract: class_name X extends Event) + reused GameOverEvent:
# class_name UnitDestroyedEvent extends Event      { entity_id }
# class_name StructureDestroyedEvent extends Event { entity_id, is_hq }
# run_win_check (ADR-0002 step 6) sets GameOver + appends GameOverEvent iff any StructureDestroyedEvent.is_hq
```

`CombatConfig` (`.tres`): `ATTACK_COST = 2`, `COVER_DR = 1`, `MIN_DAMAGE = 1` — Combat-owned tuning,
`gameplay_config_storage` pattern. `DEFENSIVE_ATTACK_COST` is Base-&-Production-owned (read via the
structure-type registry), not a `CombatConfig` field.

## Alternatives Considered

### Alternative 1 (destruction): Combat directly removes the piece; Research polls for reverts
- **Description**: `Combat.apply()` does `grid.remove` + destroyed flag itself; Research detects a
  vanished in-progress Lab by diffing state at start-of-turn.
- **Pros**: Fewer moving parts inside Combat; no shared routine.
- **Cons**: The Lab-revert is no longer same-step/synchronous — it violates research-008's "within the
  same `apply_action`" requirement, and couples Research's correctness to combat timing / a polling pass.
- **Rejection Reason**: Breaks the atomicity the GDD explicitly requires; makes a future non-combat
  killer re-implement removal.

### Alternative 2 (destruction): Combat emits a DestroyedEvent; a Research signal handler reverts reactively
- **Description**: Revert happens in an `action_applied` subscriber (ADR-0004) after the commit.
- **Pros**: Maximally decoupled; Research never called from the mutation path.
- **Cons**: The signal fires at `apply_action` step 7, *after* the commit — the revert is post-commit
  and observer-order-dependent, not part of the atomic step. A clone evaluated by the AI (which has zero
  signal subscribers, ADR-0004) would never revert at all — breaking clone parity.
- **Rejection Reason**: Same-step atomicity + clone-safety are non-negotiable; a signal handler is
  neither. **CHOSEN: the central `GameState.destroy_entity()` routine** — synchronous, in-commit,
  clone-safe, reused by any killer, with Research's semantics kept in Research via a forward-declared
  `on_lab_destroyed` contract.

### Alternative 3 (win-check): `run_win_check` re-scans all HQ hp each commit
- **Description**: Iterate `entities_by_id` every `apply_action`, flag any HQ at hp ≤ 0.
- **Pros**: Robust to a missed event.
- **Cons**: A full-entity scan every commit, duplicating the detection `destroy_entity()` already did.
- **Rejection Reason**: The destruction hook is the single point an HQ can reach 0; keying
  `run_win_check` off its `StructureDestroyedEvent{is_hq}` is O(events) not O(entities) and has one
  detection site. **CHOSEN: event-driven win-check.**

### Alternative 4 (module shape): instance methods on `GameState`
- **Description**: Put `legal_targets`/`attack` on `GameState`.
- **Cons**: Re-accretes Core logic onto `GameState` — the pattern ADR-0006/0009 rejected.
- **Rejection Reason**: Inconsistent with the established static-utility precedent. (Note: `destroy_entity`
  *is* a `GameState` method — deliberately, because it is generic mutation-layer state surgery reused by
  many systems, not combat-specific rules; the combat *rules* stay in the static `Combat` class.)

## Consequences

### Positive
- One shared, synchronous, clone-safe destruction hook — Grid removal, Lab-revert, and win-check are one
  atomic step, and any future killer reuses it.
- Combat stays a pure static-utility verb handler consistent with `AP`/`Movement`; the AI evaluates
  attacks on clones with zero side effects.
- Research and Base & Production semantics stay in their own systems via forward-declared contracts
  (`effective_attack`, `on_lab_destroyed`, `DEFENSIVE_ATTACK_COST`) — Combat depends on shapes, not
  internals.
- Attacker-polymorphism (unit or Defensive Structure) through one pipeline — no parallel structure-attack
  code path.

### Negative
- Adds two `GameState`-adjacent surfaces (`destroy_entity()` method; a forward-declared
  `Research.on_lab_destroyed`) that the Research/B&P epics must implement — coordination cost, mitigated
  by the same forward-declaration precedent ADR-0006/0008 used.
- `legal_targets_from()` (hypothetical-origin) is called once per reachable-frontier tile in the Move
  preview and AI lookahead — its cost is `reachable`-sized, compounding ADR-0011's per-turn budget.

### Risks
- **Ranged model is UNVALIDATED (spike-gated).** DIRECT `range>1`, the Sniper no-counter dynamic, AREA,
  `defense`, and `can_counterattack` were never in the (melee-only) prototype. **Mitigation**: they ship
  as tuned-OFF-by-default *infrastructure* (`can_counterattack=false`, `defense=0`, DIRECT everywhere);
  this ADR fixes the *structure*, and the balance spike tunes numbers without a structural change. Any
  fix, if the spike finds degenerate kiting, is a positioning/`defense`/`COVER_DR` lever — not a change
  to this pipeline.
- **AREA path is dormant** — no VS unit exercises it, so its ACs are forward-proofing until an AREA unit
  ships. **Mitigation**: the `min_range ≤ attack_range` schema assertion (ADR-0007) and the inclusive
  ring-boundary ACs guard it now so it doesn't rot.
- **`effective_attack`/`on_lab_destroyed`/`is_hq()`/`is_research_lab()` are forward-declared** — this ADR
  assumes shapes the Unit/Research epics must supply. **Mitigation**: registered as interface contracts
  (registry step) so `/architecture-review` tracks them as owed, exactly like ADR-0006's forward
  declarations. The forward-declared `Research.on_lab_destroyed(state, lab)` **runs while the dying Lab is
  still live in Grid + `entities_by_id`** (before removal steps b/c) — the Research epic may read the
  Lab's live fields (`position`, `owner`, `current_research_target`) but must not assume it is already
  gone. Stated so research-008's implementer isn't surprised by the ordering.

## GDD Requirements Addressed

| GDD | Requirement (TR-ID) | How This ADR Addresses It |
|-----|---------------------|---------------------------|
| combat-resolution.md | Deterministic `max(MIN_DAMAGE, effective_attack − cover − defense)`, no RNG (TR-combat-001) | `Combat.damage()` — integer, min-1 floor, `CombatConfig` constants |
| combat-resolution.md | Structures cover-immune (TR-combat-002) | `cover_reduction` branches `defender is UnitState`; always 0 for `StructureState` |
| combat-resolution.md | `legal_targets(unit)` side-effect-free, DIRECT/AREA/LoF (TR-combat-003) | `Combat.legal_targets()` pure query over `GridState` |
| combat-resolution.md | `legal_targets(unit, from_tile)` hypothetical overload (TR-combat-004) | `Combat.legal_targets_from()` — pure, `== ` zero-arg when `from_tile == position` |
| combat-resolution.md | `attack()` atomic pipeline, idempotent vs double-submit (TR-combat-005) | `Combat.validate()/apply()` verb handler; re-validation on re-submit rejects (ADR-0002 atomicity) |
| combat-resolution.md | `preview_damage()` pure, == committed (TR-combat-006) | `Combat.preview_damage()` shares `damage()` with `apply()` |
| combat-resolution.md | Immediate same-step death + Grid removal + Lab-revert hook (TR-combat-007) | `GameState.destroy_entity()` — Grid remove + forward-declared `on_lab_destroyed`, one step |
| combat-resolution.md | HQ-destruction wired to win-check, same commit, post-GameOver lockout (TR-combat-008) | `StructureDestroyedEvent{is_hq}` → ADR-0002 `run_win_check` → `GameOver`; ADR-0002 step 1 lockout |
| combat-resolution.md | Counterattack data-driven bool, single non-recursive (TR-combat-009) | `_defender_may_counter()` gate; one straight-line counter step, structurally non-recursive |
| combat-resolution.md | `attack()` accepts structure attacker, AP from `DEFENSIVE_ATTACK_COST` (TR-combat-012) | Attacker-polymorphic `apply()`; cost branches on `attacker is StructureState` |
| combat-resolution.md | Three blocked-shot classifications as queryable data (TR-combat-014) | `BlockedReason` enum via `Combat.blocked_reason()` |
| base-production.md | Defensive Structure attack via `attack()`, `DEFENSIVE_ATTACK_COST`, free counter (TR-baseprod-010) | Same attacker-polymorphic pipeline; B&P owns the cost/stat, Combat owns resolution |
| base-production.md | Structure damage via Combat formula, cover-immune, hp 0→removed same step (TR-baseprod-011) | `damage()` structure branch + `destroy_entity()` |
| base-production.md | HQ destruction raises observable signal → GameOver; non-HQ raises none (TR-baseprod-012) | `StructureDestroyedEvent{is_hq}`; only `is_hq` triggers `GameOverEvent` |
| research-tech.md | Lab destruction → synchronous same-step tech-revert, shared trigger with Combat (TR-research-008) | `destroy_entity()` calls forward-declared `Research.on_lab_destroyed()` before Grid removal, same `apply_action` |
| game-state-turn-manager.md | Win-check after every HQ-destroying mutation, synchronous, in `apply_action` (TR-gamestate-010; primary ADR-0002) | This ADR pins ADR-0002 step 6 `run_win_check` to the destruction event |

## Performance Implications

- **CPU**: `damage()`/`attack()` are O(1) integer work plus one tile-walk (DIRECT, ≤ `attack_range`
  steps) or one ring scan (AREA). `legal_targets()` is O(4 · attack_range) DIRECT / O(ring area) AREA.
  `legal_targets_from()` over the reachable frontier is `reachable`-sized — the dominant caller is
  ADR-0011's AI lookahead (its QQ-06 budget accounts for it). `destroy_entity()` is O(1) + the forward
  Lab-revert.
- **Memory**: Small typed `Array[Event]` / `Array[TargetResult]` per call; no persistent allocation.
  `CombatConfig` is one shared `.tres`, never on `GameState`, never cloned.
- **Load Time / Network**: None / N/A.

## Migration Plan

N/A — new system. `destroy_entity()` and the `run_win_check` event-keying refine ADR-0002's still-Proposed
skeleton; no shipped code to migrate.

## Validation Criteria

- The full combat-resolution.md Pure-Logic gate as `tests/unit/combat/` (damage incl. structure
  cover-immunity + attacker-on-cover + preview==committed; AP/once-per-turn atomicity + idempotency;
  DIRECT targeting incl. LoF/nearest-only/out-of-range/non-cardinal; AREA inclusive ring + dead zone +
  `min_range≤attack_range` error; enemy-only; structure-as-attacker; counter cases; death + clone
  determinism/isolation).
- Integration gate (`tests/integration/combat/`): atomic attack via real `apply_action`; move-then-attack
  both orders; **HQ at hp = damage → GameOver in the same action, subsequent actions rejected**; real-Grid
  LoF; `can_counterattack` primary+counter both present after `apply_action`.
- A destruction-hook integration test: destroying an in-progress Research Lab reverts its tech to Not
  Started in the **same** commit (asserts `on_lab_destroyed` ran synchronously, not post-signal).

## Related Decisions

- ADR-0001, ADR-0002 (refined: `run_win_check` event-keying), ADR-0003, ADR-0005, ADR-0006, ADR-0007
- ADR-0009 (module-shape precedent), ADR-0011/0015/0016 (consumers)
- `design/gdd/combat-resolution.md`, `design/gdd/base-production.md`, `design/gdd/research-tech.md`,
  `design/gdd/game-state-turn-manager.md`
