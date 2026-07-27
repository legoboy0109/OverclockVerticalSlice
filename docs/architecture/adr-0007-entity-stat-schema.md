# ADR-0007: Unit & Structure Entity/Stat Schema

## Status
Accepted

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / State Management |
| **Knowledge Risk** | MEDIUM (was HIGH pre-verification; the one post-cutoff unknown — `duplicate_deep()` path-having behavior — is now CONFIRMED below) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; ADR-0001's godot-specialist-verified `duplicate_deep()` findings (2026-07-23) |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` (Godot 4.5) — specifically its treatment of disk-loaded (path-having) Resources, a case ADR-0001 did not need to exercise; typed `Array[UnitTypeDef]` / `Dictionary[int, EntityState]` (Godot 4.4) |
| **Verification Required** | **CONFIRMED (godot-specialist, 2026-07-23).** `duplicate_deep()`'s default `DEEP_DUPLICATE_INTERNAL` mode treats disk-loaded (`resource_path`-having) Resources as **shared references, not deep-copied** — verified against the official 4.6 class reference ("Only subresources without a path or with a scene-local path will be duplicated") and engine source `core/io/resource.cpp` `Resource::_duplicate_recursive()`, which gates the copy on `Resource::is_built_in()` (true only for path-less / `::` / `local://` resources — never for a `preload()`'d `.tres`). This is the exact complement to ADR-0001's verified path-less finding; together: **path-less sub-resources copy, path-having sub-resources share.** Legacy `duplicate(true)` shares the same code path. No open verification remains. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EntityState base class, Resource/`duplicate_deep()` cloning pattern — explicitly forward-declares this ADR), ADR-0002 (verb handlers for Build/Produce/Research actions dispatch against this schema), ADR-0005 (Grid occupancy indexes entities by `entity_id`, resolved via this schema's `EntityState`), ADR-0006 (forward-declared `completed_outpost_count()` / `economy_tech_income_bonus()` query contracts — this ADR supplies their concrete implementation) |
| **Enables** | ADR-0008 (start-of-turn sequencing resets `tiles_moved_this_turn`, `has_attacked`, `units_produced_this_turn`, and advances `build_turns_remaining`/`research_turns_remaining` — all fields this ADR defines) |
| **Blocks** | Epics: Unit System, Base & Production, Combat Resolution, Research/Tech — no implementation work in these can start until this ADR is Accepted |
| **Ordering Note** | None beyond Depends On |

## Context

### Problem Statement

ADR-0001 defined `EntityState` as a bare base (`entity_id`, `owner`, `position`) and explicitly forward-declared that "ADR-0007 defines Unit/Structure specializations." Four GDDs now depend on that specialization existing: Unit System needs four unit types with per-instance runtime state; Base & Production needs five structure types (including the Research Lab, which reuses Base & Production's generic mechanics) with a build lifecycle; Research/Tech needs per-Lab research state and three tech templates; Combat Resolution needs `defense`/`targeting_mode`/`min_range`/`can_counterattack` fields already referenced in `design/registry/entities.yaml` but not yet formalized in `unit-system.md`'s own schema language. ADR-0006 additionally forward-declared two query contracts — `completed_outpost_count(player)` and `economy_tech_income_bonus(player)` — that only make sense once this ADR's entity schema exists to query.

The decision must also satisfy a performance constraint ADR-0001 and ADR-0006 both already established: `GameState.clone()` (`duplicate_deep()`) runs once per candidate action in the AI's lookahead loop, so anything reachable from `GameState` that does **not** need per-clone independence (immutable stat templates, exactly like ADR-0006 kept `EconomyConfig` off `GameState`) must not be paid for on every clone.

### Constraints
- Must extend `EntityState` (ADR-0001) without changing its existing fields.
- Must not introduce float fields on any state class (ADR-0003 `float_in_state` ban).
- Must not store entity references inside spatial indexes — Grid occupancy already stores `entity_id` only (ADR-0005 `entity_ref_in_spatial_index` ban); this schema is what those ids resolve to via `GameState.entity_at()`.
- Must keep template data off the deep-copy hot path the same way `EconomyConfig`/`MapDefinition` already are (`api_decisions: gameplay_config_storage`, `game_state_deep_copy`).
- Must satisfy `coding-standards.md`: gameplay values are data-driven (external config), never hardcoded.
- Iteration over entities for order-sensitive logic must be stable (ADR-0003 `nondeterministic_iteration_order` ban) — relevant because `GameState.entities()` (ADR-0001) is the schema's primary iteration surface.

### Requirements
- Four unit types (Scout, Trooper, Heavy, Sniper) and five structure types (HQ, Economy Outpost, Production Outpost, Defensive Structure, Research Lab) each need an immutable stat template plus a concrete per-instance state class.
- Research's three techs (Attack, Defense, Economy) need an immutable template; per-Lab research progress needs a home.
- `completed_outpost_count(state, player)` and `economy_tech_income_bonus(state, player)` must be concretely defined against this schema.
- Design tooling (economy-designer, systems-designer) must be able to retune stat values without touching code.

## Decision

`EntityState` (ADR-0001) is specialized into exactly two concrete subclasses — `UnitState` and `StructureState` — no further subclassing (the Research Lab is a `StructureState`, not a third subclass; see Alternatives). Each carries a `type` reference to an immutable stat-template `Resource` (`UnitTypeDef` / `StructureTypeDef`), loaded once from `.tres` files and shared **by reference** across every entity instance and every `GameState.clone()`. A third template `Resource`, `TechDef`, backs Research's three techs and is referenced by `StructureState.current_research_target` for Labs.

Template resources are loaded exactly once via `preload()` into thin, logic-free registry **constants** — never via runtime `load()` — so "which type is this" can be answered by **Resource-reference identity** (`structure.type == StructureTypes.ECONOMY_OUTPOST`), with no parallel enum to keep in sync. `preload()`'s compile-time resolution guarantees a single shared instance per template and removes any load-order hazard. This follows ADR-0006's `Balance`-loader precedent (config-as-Resource in a thin Autoload) but **deliberately strengthens it** from that ADR's `var` to `const`: these templates must never be reassigned or mutated at runtime, and compiler-enforced `const` immutability closes the mutation hole a `var` would leave open (consistent with the `config_resource_runtime_mutation` ban ADR-0006 registered).

Both `unit-system.md` Rule 2 ("a `type` reference to its immutable template") and `research-tech.md` Rule 2 ("[the Research Lab is] built through Base & Production's existing structure mechanics unchanged") already describe exactly this shape; this ADR formalizes it in code and resolves the two open design questions (Lab field placement, type-identity mechanism) the GDDs left implicit.

### Architecture Diagram

```
EntityState (ADR-0001: entity_id, owner, position)
    │
    ├── UnitState
    │     @export var type: UnitTypeDef          # shared template ref (preload'd, not cloned)
    │     @export var current_hp: int
    │     @export var has_attacked: bool = false
    │     @export var tiles_moved_this_turn: int = 0
    │
    └── StructureState
          @export var type: StructureTypeDef     # shared template ref (preload'd, not cloned)
          @export var current_hp: int
          @export var build_status: int = BuildStatus.UNDER_CONSTRUCTION
          @export var build_turns_remaining: int = 0
          @export var units_produced_this_turn: int = 0     # producers only; 0/unused elsewhere
          @export var has_attacked: bool = false             # Defensive Structure only; unused elsewhere
          @export var current_research_target: TechDef = null   # Research Lab only; null elsewhere
          @export var research_turns_remaining: int = 0         # Research Lab only; unused elsewhere

Template layer (Resource, .tres, preloaded once, NOT on the clone-cost path):

  UnitTypeDef              StructureTypeDef            TechDef
  ├─ display_name          ├─ display_name             ├─ display_name
  ├─ hp                    ├─ hp                       ├─ research_cost
  ├─ attack                ├─ build_cost                ├─ research_time
  ├─ attack_range          ├─ build_time                └─ effect: TechEffect (ATTACK|DEFENSE|ECONOMY)
  ├─ move_cost             ├─ production_cap: int = 0
  ├─ soft_move_cap         ├─ producible_types: Array[UnitTypeDef] = []
  ├─ produce_cost          ├─ attack: int = 0
  ├─ defense: int = 0      ├─ attack_range: int = 0
  ├─ targeting_mode        ├─ defense: int = 0
  ├─ min_range: int = 1    └─ can_counterattack: bool = false
  └─ can_counterattack: bool = false

Registries (Autoload consts, preload()-populated at compile time — no runtime load()):
  UnitTypes.SCOUT / .TROOPER / .HEAVY / .SNIPER            : UnitTypeDef
  StructureTypes.HQ / .ECONOMY_OUTPOST / .PRODUCTION_OUTPOST
                / .DEFENSIVE_STRUCTURE / .RESEARCH_LAB      : StructureTypeDef
  Techs.ATTACK_TECH / .DEFENSE_TECH / .ECONOMY_TECH          : TechDef
```

### Key Interfaces

```gdscript
class_name UnitState
extends EntityState

@export var type: UnitTypeDef
@export var current_hp: int
@export var has_attacked: bool = false
@export var tiles_moved_this_turn: int = 0

class_name StructureState
extends EntityState

enum BuildStatus { UNDER_CONSTRUCTION, COMPLETED }

@export var type: StructureTypeDef
@export var current_hp: int
@export var build_status: int = BuildStatus.UNDER_CONSTRUCTION
@export var build_turns_remaining: int = 0
@export var units_produced_this_turn: int = 0
@export var has_attacked: bool = false
@export var current_research_target: TechDef = null
@export var research_turns_remaining: int = 0
```

```gdscript
class_name UnitTypeDef
extends Resource

enum TargetingMode { DIRECT, AREA }

@export var display_name: String
@export var hp: int
@export var attack: int
@export var attack_range: int
@export var move_cost: int
@export var soft_move_cap: int
@export var produce_cost: int
@export var defense: int = 0
@export var targeting_mode: int = TargetingMode.DIRECT
@export var min_range: int = 1
@export var can_counterattack: bool = false

class_name StructureTypeDef
extends Resource

@export var display_name: String
@export var hp: int
@export var build_cost: int
@export var build_time: int
@export var production_cap: int = 0
@export var producible_types: Array[UnitTypeDef] = []
@export var attack: int = 0
@export var attack_range: int = 0
@export var defense: int = 0
@export var can_counterattack: bool = false

class_name TechDef
extends Resource

enum TechEffect { ATTACK, DEFENSE, ECONOMY }

@export var display_name: String
@export var research_cost: int
@export var research_time: int
@export var effect: int   # TechEffect
```

```gdscript
# Registries — Autoload, logic-free, preload()-populated (never load() at runtime)
extends Node
# class_name UnitTypes
const SCOUT: UnitTypeDef = preload("res://data/units/scout.tres")
const TROOPER: UnitTypeDef = preload("res://data/units/trooper.tres")
const HEAVY: UnitTypeDef = preload("res://data/units/heavy.tres")
const SNIPER: UnitTypeDef = preload("res://data/units/sniper.tres")

# class_name StructureTypes
const HQ: StructureTypeDef = preload("res://data/structures/hq.tres")
const ECONOMY_OUTPOST: StructureTypeDef = preload("res://data/structures/economy_outpost.tres")
const PRODUCTION_OUTPOST: StructureTypeDef = preload("res://data/structures/production_outpost.tres")
const DEFENSIVE_STRUCTURE: StructureTypeDef = preload("res://data/structures/defensive_structure.tres")
const RESEARCH_LAB: StructureTypeDef = preload("res://data/structures/research_lab.tres")

# class_name Techs
const ATTACK_TECH: TechDef = preload("res://data/tech/attack_tech.tres")
const DEFENSE_TECH: TechDef = preload("res://data/tech/defense_tech.tres")
const ECONOMY_TECH: TechDef = preload("res://data/tech/economy_tech.tres")
```

```gdscript
# Concrete implementations of ADR-0006's forward-declared contracts.
# entities() (ADR-0001) iterates entities_by_id in entity_id order — stable,
# satisfying ADR-0003 Rule 3 (nondeterministic_iteration_order ban).
static func completed_outpost_count(state: GameState, player: int) -> int:
    var n := 0
    for e in state.entities():
        if e is StructureState and e.owner == player \
           and e.type == StructureTypes.ECONOMY_OUTPOST \
           and e.build_status == StructureState.BuildStatus.COMPLETED:
            n += 1
    return n

static func economy_tech_income_bonus(state: GameState, player: int) -> int:
    # Returns the FULLY-CAPPED Economy-Tech term (research-tech.md line 263). AP.income()
    # (ADR-0006) adds this verbatim and does NOT re-apply the cap. Constant ownership per GDDs:
    #   ECONOMY_TECH_INCOME_BONUS (=1)   — Research-owned (this system's tech-effect value)
    #   ECONOMY_TECH_TIER_THRESHOLD (=6) — AP-Economy-owned brake, read cross-system from
    #                                      EconomyConfig (Balance.economy.economy_tech_tier_threshold)
    if not state.per_player[player].has_economy_tech:
        return 0
    return ECONOMY_TECH_INCOME_BONUS * min(
        completed_outpost_count(state, player),
        ECONOMY_TECH_TIER_THRESHOLD
    )
```

## Alternatives Considered

### Alternative 1: GDScript enum + static const Dictionary (no Resource template layer)
- **Description**: Stats live as a `const Dictionary` keyed by an enum, e.g. `const UNIT_STATS = {UnitKind.SCOUT: {"hp": 3, "attack": 2, ...}}`.
- **Pros**: Zero indirection, no `.tres` authoring step, marginally faster lookup (no Resource overhead).
- **Cons**: Every balance tweak requires a code change and redeploy; no inspector editing for economy-designer/systems-designer; untyped Dictionary access loses static-type checking the coding standard otherwise mandates.
- **Rejection Reason**: Directly violates `coding-standards.md`'s "gameplay values must be data-driven (external config), never hardcoded" rule. Also breaks precedent set by every prior ADR's config decisions (`EconomyConfig`, `MapDefinition`).

### Alternative 2: Dedicated `ResearchLabState` subclass of `StructureState`
- **Description**: `StructureState` stays lean (only fields every structure has); a third subclass adds `current_research_target`/`research_turns_remaining` for Labs only.
- **Pros**: No wasted fields; per-type field ownership is explicit at the type level.
- **Cons**: A third concrete entity subclass; any code that walks `entities_by_id` needing research-timer state must `is ResearchLabState`-check rather than trusting `StructureState` uniformly — in tension with `research-tech.md` Rule 2's explicit framing that the Lab uses "exactly the generic structure mechanics this system defines... no new mechanics here."
- **Rejection Reason**: User-directed choice (session decision, 2026-07-23) — folding onto generic `StructureState` was preferred as the simpler shape consistent with the GDD's own "no new mechanics" framing; the wasted-field cost (two `int`/one `Resource` field, unused on 4 of 5 structure types) was judged worth avoiding a third subclass.

### Alternative 3: Parallel `StructureKind`/`UnitKind` enum discriminator
- **Description**: Store an enum alongside the `type` Resource reference (`structure.kind == StructureKind.ECONOMY_OUTPOST`) instead of comparing the Resource reference itself.
- **Pros**: Reads slightly cleaner in `match` statements; easier to serialize stably for a future save/load format (enums are trivially portable; Resource references are not without a path-based re-resolution step).
- **Cons**: Two fields (`type` Resource ref + `kind` enum) must always agree — a second failure mode (constructing a `StructureState` with a mismatched pair) that pure Resource-identity comparison cannot have.
- **Rejection Reason**: User-directed choice (session decision, 2026-07-23) — Resource-reference identity was preferred to avoid the sync-hazard, at the cost of slightly more verbose comparisons (`StructureTypes.ECONOMY_OUTPOST` instead of a bare enum literal).

### Alternative 4: Data-oriented parallel arrays (mirroring `GridState`'s `PackedByteArray`/`PackedInt32Array` shape)
- **Description**: Store unit/structure stats as columns of packed arrays indexed by a slot id, matching ADR-0005's `grid_storage` decision.
- **Pros**: Cache-friendly; consistent with the one other place this project chose a data-oriented layout.
- **Cons**: Entity count is a few dozen per match (not the thousands of tiles Grid has) — the cache-locality win is negligible at this scale. Both GDDs already assume per-instance method calls (`can_attack(unit)`, `reset_turn_flags(unit)`, `duplicate(unit)`) that read naturally against object identity, not array indices; retrofitting those onto parallel arrays adds real complexity for no measurable win.
- **Rejection Reason**: Scale mismatch with Grid's justification for the same pattern (ADR-0005's `grid_storage` reasoning explicitly cites tile-count cache-friendliness, which doesn't transfer to entity counts this small).

## Consequences

### Positive
- Every current and future structure type (including the Research Lab, and any Faction Identity #12 variant) is a `StructureState` — no growing subclass hierarchy as the roster expands.
- Stat templates are fully data-driven `.tres` resources, editable in the inspector without code changes, satisfying `coding-standards.md` directly.
- `preload()`-based registries give zero per-clone cost for templates (CONFIRMED, Engine Compatibility) — `GameState.clone()`'s cost scales with live entity count only, not template count. Because the shared-reference check happens *before* any recursion into a sub-resource's fields, `StructureTypeDef.producible_types: Array[UnitTypeDef]` is never even walked during a clone — the whole template subgraph (including nested template arrays) is skipped, not just the top-level reference.
- `completed_outpost_count()` / `economy_tech_income_bonus()`, forward-declared by ADR-0006, now have concrete implementations, unblocking AP Economy's and Research's downstream work.
- Adding a 6th structure type or 5th unit type is a new `.tres` + one registry constant — no schema or enum changes.

### Negative
- `StructureState` carries fields unused by most instances (`has_attacked` wasted on 4 of 5 structure types; `current_research_target`/`research_turns_remaining` wasted on 4 of 5) — an explicit, accepted waste-for-simplicity tradeoff (Alternative 2).
- Type-identity checks depend on comparing against registry singletons (`StructureTypes.ECONOMY_OUTPOST`) rather than a self-describing enum value on the instance itself.
- Faction Identity (#12, not yet designed) may need per-faction stat variants; this ADR does not decide whether that means per-faction `*TypeDef` resources or a modifier layer on top of the shared ones — deferred.

### Risks
- **`duplicate_deep()` path-having-Resource behavior — RESOLVED** (godot-specialist, 2026-07-23, CONFIRMED against `core/io/resource.cpp` `_duplicate_recursive()`, gated on `Resource::is_built_in()`; see Engine Compatibility). Disk-loaded (`preload()`'d) templates are shared, not deep-copied, so no per-clone template cost exists. Residual: a clone-isolation assertion is still included in Validation Criteria as a regression guard, not because the behavior is in doubt.
- **Registry singleton identity depends on `preload()` discipline.** If any future code calls `load("res://data/units/scout.tres")` directly instead of going through `UnitTypes.SCOUT`, Godot returns a *second* Resource instance with the same content but different identity — `==` reference comparisons would then silently fail. **Mitigation**: `load()` of these template `.tres` files outside the registry Autoloads is added to the forbidden-patterns registry (see Step 6); only the registry Autoloads may load them, and only via `preload()`.
- **Research Lab field waste could mislead a future contributor** into thinking `current_research_target` applies to non-Lab structures. **Mitigation**: doc-comment on the fields in `StructureState` noting their Lab-only scope (this is the one case where a comment earns its keep — the constraint is non-obvious from the field alone).
- **`@export` storage-flag discipline** (ADR-0001's Consequences) applies identically to every field on `UnitState`/`StructureState`/`UnitTypeDef`/`StructureTypeDef`/`TechDef` — a field missing `@export` is silently excluded from `duplicate_deep()`. All fields in this ADR carry `@export`; this is a cross-reference to ADR-0001's existing rule, not a new one.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| unit-system.md | Rule 1: unit type template fields (`hp`, `attack`, `attack_range`, `move_cost`, `soft_move_cap`, `produce_cost`) | `UnitTypeDef` Resource fields |
| unit-system.md | Rule 2: runtime instance state (`entity_id`, `type` reference, `owner`, `current_hp`, `position`, `has_attacked`, `tiles_moved_this_turn`) | `UnitState` fields + inherited `EntityState` fields |
| unit-system.md | Rule 9 / combat-resolution.md handoff: `defense`, `targeting_mode`, `min_range`, `can_counterattack` per-unit-type fields (currently only in `design/registry/entities.yaml`, flagged "Unit GDD revision pending") | Formalized on `UnitTypeDef` — closes the registry/GDD gap at the schema level (GDD prose still needs its own revision pass, tracked separately) |
| base-production.md | Rule 1: structure template fields (`hp`, `build_cost`, `build_time`, `production_cap`, `producible_types`) + Defensive Structure's `attack`/`attack_range`/`defense`/`can_counterattack` | `StructureTypeDef` fields |
| base-production.md | States and Transitions: Under-Construction → Completed → Destroyed; `units_produced_this_turn`; `has_attacked` | `StructureState.build_status` (`BuildStatus` enum) + runtime fields |
| base-production.md | Rule 11: `completed_outpost_count(player)` contract | Concrete `completed_outpost_count()` implementation, fulfilling ADR-0006's forward declaration |
| research-tech.md | Rule 1: tech template (`research_cost`, `research_time`, `effect`) | `TechDef` Resource |
| research-tech.md | Rule 2: Research Lab reuses Base & Production's generic structure mechanics, no new mechanics | Research Lab is a `StructureState` with `type == StructureTypes.RESEARCH_LAB` — no new subclass |
| research-tech.md | Per-Lab state (Rule 4/States table): `current_research_target`, `research_turns_remaining` | Folded onto generic `StructureState` per this ADR's decision (Alternative 2) |
| research-tech.md | Economy Tech income bonus (Rule 8, Formulas) | Concrete `economy_tech_income_bonus()` implementation, fulfilling ADR-0006's forward declaration |
| combat-resolution.md | `defense`/`targeting_mode`/`min_range`/`can_counterattack` as shared Unit- **and** structure-owned fields | Present on both `UnitTypeDef` and `StructureTypeDef` |
| movement-system.md | `tiles_moved_this_turn` (Unit-owned counter, Movement-written) | `UnitState.tiles_moved_this_turn` |
| coding-standards.md | Gameplay values must be data-driven (external config), never hardcoded | `UnitTypeDef`/`StructureTypeDef`/`TechDef` as `.tres` resources, not enums/consts |

## Performance Implications
- **CPU**: Negligible added simulation cost. Template field reads are O(1) reference dereferences. `completed_outpost_count()` is O(entity count), called once per player per start-of-turn (not per-frame). No new per-frame cost.
- **Memory**: 12 template resources total (4 unit types + 5 structure types + 3 techs), each a few dozen bytes of typed fields, loaded once at boot and shared by reference — negligible, and explicitly NOT duplicated per entity instance or per clone (pending verification).
- **Load Time**: Templates resolve via `preload()` at compile time — zero additional runtime load cost during a match.
- **Network**: N/A — no networking in the Vertical Slice.

## Migration Plan
None — this is new schema with no prior implementation to migrate. It fulfills the specialization ADR-0001 already forward-declared, and the contracts ADR-0006 already forward-declared.

## Validation Criteria
- Unit test: `GameState.clone()` over a state including a Production Outpost (a `StructureTypeDef` with **non-empty** `producible_types`, to exercise the nested-template-array non-recursion path) plus at least one entity of every other unit and structure type asserts that `current_hp`/`position`/`build_status`/etc. mutate independently between clone and original (runtime fields are deep-copied), while `unit.type`/`structure.type` (and `structure.type.producible_types` and its elements) on the clone are the **same objects** (`===`) as on the original — the load-bearing perf assumption, made assertable rather than just claimed.
- Unit test: `completed_outpost_count()` returns the correct count across Under-Construction, Completed, Destroyed, and enemy-owned Economy Outposts (all non-counted cases return 0 contribution), matching `base-production.md` Rule 11 exactly.
- Unit test: `economy_tech_income_bonus()` returns 0 without `has_economy_tech`, and the tiered/capped value with it, matching `research-tech.md`'s worked examples (including the `k > ECONOMY_TECH_TIER_THRESHOLD` cap case).
- Determinism test: `GameState.entities()` iteration order is stable and independent of entity creation/removal history (ADR-0003 Rule 3).

## Related Decisions
- ADR-0001: State Model Ownership & Lifecycle (defines `EntityState`, forward-declares this ADR)
- ADR-0002: Apply-Action Command Model (verb handlers dispatch against this schema)
- ADR-0005: Grid Representation & Map Format (entity_id resolution via this schema)
- ADR-0006: AP Economy Data Model & Spend Contract (forward-declares the two query contracts this ADR implements)
- ADR-0008: Shared Start-of-Turn Sequencing (planned — consumes the per-turn reset fields this ADR defines)
- `design/gdd/unit-system.md`, `design/gdd/base-production.md`, `design/gdd/research-tech.md`, `design/gdd/combat-resolution.md`, `design/gdd/movement-system.md`
