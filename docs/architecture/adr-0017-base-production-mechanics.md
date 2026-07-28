# ADR-0017: Base & Production Mechanics — Placement, Production, and Structure Lifecycle

## Status
Accepted

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 / Redot 26.2 (Godot-4.x-compatible) |
| **Domain** | Core (game logic / state mutation) |
| **Knowledge Risk** | LOW — pure GDScript logic (static class, Dictionary/PackedInt32Array reads via Grid); no engine subsystem, no rendering, no post-cutoff API surface |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; established-pattern precedent ADRs `adr-0006` (AP static utility + config-as-Resource), `adr-0009` (Movement static utility + fixed-point config), `adr-0010` (Combat static utility + `destroy_entity` exit) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None engine-specific. `legal_build_tiles` per-call cost is bounded by design (friendly-frontier candidate set); no perf spike gate (unlike ADR-0009/0011 search budgets). |
| **Engine Review** | godot-specialist 2026-07-24 — NO BLOCKING issues. Confirmed: `RefCounted` static-utility shape, `Array[Vector2i]` typed returns, `sort_custom(Callable)` (not the deprecated string form), integer `/` truncation = floor for non-negative operands, Resource-ref `in`-membership on preload'd typed arrays, and `BaseProductionConfig`-via-logic-free-Autoload cross-read all idiomatic for 4.6 and consistent with ADR-0006/0009/0010. No deprecated/post-cutoff API referenced. One MINOR note folded into D3 + Risks (Dictionary-as-set determinism comment). TD-ADR strategic review skipped — Lean review mode. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameState/PlayerState, EntityState base, `duplicate_deep()` clone), ADR-0002 (apply_action verb dispatch, validate-before-mutate atomicity, stateless re-validation idempotency), ADR-0003 (determinism: integer state + fixed-point config + stable iteration order), ADR-0005 (GridState occupancy: `place`/`remove`/`occupant_at`/`is_passable`/`manhattan_distance`/`neighbors`), ADR-0006 (AP `can_afford`/`spend`, config-as-Resource via the `Balance`-style Autoload), ADR-0007 (StructureState/UnitState schema, `StructureState.BuildStatus` enum, `StructureTypeDef.producible_types`, preload'd type registry) |
| **Enables** | Closes the 4 forward-declared B&P mechanic contracts consumed by ADR-0011 (`legal_build_tiles`, `legal_deploy_tiles`) and ADR-0015 (`legal_build_tiles`/`legal_deploy_tiles`/`production_cap` for the Command FSM menu + overlays); unblocks the **Base & Production epic** implementation |
| **Blocks** | Base & Production epic (build/produce/cancel stories) cannot start implementation until this ADR is Accepted |
| **Ordering Note** | Coordinates-not-depends with ADR-0008 (this ADR supplies the concrete `BaseProduction.advance_build_timers` body that ADR-0008 forward-declared and *sequences* at start-of-turn step 3 — ADR-0008 owns WHEN, this ADR owns the transition), ADR-0010 (`GameState.destroy_entity` is the combat/terminal exit this ADR's lifecycle terminates into; `DEFENSIVE_ATTACK_COST` is B&P-owned config that Combat reads cross-system), and ADR-0012 (build/produce read through the faction `effective_build_cost`/`effective_build_time`/`effective_production_cap` folds — B&P-owned `effective_*` sites, == base under Neutral) |

## Context

### Problem Statement
The master architecture allocated 16 ADRs; the 2026-07-24 `/architecture-review` found that Base & Production has **no dedicated ADR** for its *mechanics*. Four technical requirements were mis-parked on ADR-0010 (Combat), which explicitly disclaims them:

- **TR-baseprod-002** — Structure instance FSM (Under-Construction→Completed→Destroyed→Removed) and its per-instance runtime transition rules.
- **TR-baseprod-003** — Structures occupy exactly 1 tile, hard-block movement + DIRECT line-of-fire, and are targetable while Under-Construction; atomic against Grid.
- **TR-baseprod-005** — `legal_build_tiles(player, structure_type)` placement/adjacency algorithm, live-recomputed (never cached).
- **TR-baseprod-008** — `produce(producer, unit_type, tile)` validation + the chosen deploy tile, needing `legal_deploy_tiles`.

The rest of Base & Production is already owned: structure *schema/fields* + `BuildStatus` enum (ADR-0007), Build/Produce verb *dispatch* + atomicity (ADR-0002), start-of-turn build-timer *sequencing* (ADR-0008), damage/destruction/`destroy_entity`/Defensive-attack (ADR-0010), `completed_outpost_count` (ADR-0006 declares / ADR-0007 implements), determinism policy (ADR-0003), faction `effective_*` framework (ADR-0012). This ADR owns exactly the mechanics gap and nothing already owned.

### Constraints
- **Determinism (ADR-0003)**: every function is a pure function of `GameState` + chosen action — no RNG, integer-only state, stable iteration order, computable on a `clone()` for AI look-ahead and headless tests (base-production.md Rule 13).
- **Single mutation vector (ADR-0002)**: all state change flows through `apply_action`; validate-before-mutate with no rollback; queries never mutate.
- **Single occupancy index (ADR-0005)**: Grid is the sole spatial authority; a structure is an occupant like any other.
- **No floats in the economy path (ADR-0003)**: the cancel refund must be integer-derived.

### Requirements
- Own the structure lifecycle transition rules over ADR-0007's `StructureState`.
- Own `legal_build_tiles` / `legal_deploy_tiles` placement and deploy queries (live, deterministic).
- Own `build` / `produce` / `cancel_build` validate+apply handler pairs dispatched by ADR-0002.
- Satisfy every base-production.md rule for placement (Rule 5), building (Rule 4), production (Rule 7), cancel (Rule 10), and occupancy (Rule 3) without re-owning damage (Rule 9 → ADR-0010) or timer sequencing (Rule 6 → ADR-0008).

## Decision

**`BaseProduction` is a static utility class** (`class_name BaseProduction extends RefCounted`, no instance state) exposing pure functions over `GameState`, exactly mirroring `AP` (ADR-0006), `Movement` (ADR-0009), and `Combat` (ADR-0010). The three player verbs — Build, Produce, CancelBuild — are typed `Action` subclasses (ADR-0002) whose `validate`/`apply` the `apply_action` verb-enum dispatcher routes to `BaseProduction.validate_*` / `apply_*`. No B&P instance ever lives on `GameState`, so the AI's per-candidate clone loop never copies it.

### D1 — Structure lifecycle FSM (TR-baseprod-002)

The **persisted** lifecycle is the 2-value `StructureState.BuildStatus { UNDER_CONSTRUCTION, COMPLETED }` enum already declared on `StructureState` by ADR-0007. "Destroyed" and "Removed" are **not stored states** — both are terminal exits that end in `entities_by_id.erase()` + `GridState.remove(position)`:

```
                 build() [apply]                 advance_build_timers()   [ADR-0008 step 3, body here]
   (no entity) ───────────────▶ UNDER_CONSTRUCTION ─────────────────────▶ COMPLETED
                                    │  │                                      │
              cancel_build() [refund]  │ destroy_entity() [ADR-0010, no refund]│ destroy_entity() [ADR-0010, no refund]
                                    ▼  ▼                                      ▼
                                 (erased from entities_by_id + Grid — terminal)
```

- `build()` creates a `StructureState` with `build_status = UNDER_CONSTRUCTION`, `build_turns_remaining = effective_build_time(...)`, and places it into Grid occupancy in the same atomic apply.
- `advance_build_timers(state, player) -> Array[Event]` (the concrete body of ADR-0008's forward-declared contract) decrements `build_turns_remaining` on the player's Under-Construction structures and flips any reaching 0 to `COMPLETED`, appending one `StructureCompletedEvent` (ADR-0004/0008 payload) per completion. **This ADR owns the transition; ADR-0008 owns that it runs at start-of-turn step 3, before the AP income snapshot.**
- Combat destruction and voluntary cancel both terminate the entity via erasure — no lingering `DESTROYED` record. Combat routes through `GameState.destroy_entity` (ADR-0010); cancel routes through this ADR's `cancel_build` (see D5). This keeps a single "structure exists ⇔ it is in `entities_by_id` and occupies a Grid tile" invariant with no dead terminal rows to filter.
- Per-instance runtime fields (`hp`, `build_turns_remaining`, `units_produced_this_turn`, `has_attacked`, `owner`) are **declared on `StructureState` by ADR-0007**; this ADR owns only the rules that transition them. Their per-turn reset (`units_produced_this_turn = 0`, `has_attacked = false`) is `Structure.reset_turn_flags` — forward-declared by ADR-0008 (step 2), B&P-owned semantics (registry `turn_flag_reset`); this ADR confirms that body.

### D2 — Status-agnostic occupancy (TR-baseprod-003)

`build()` inserts the structure into the Grid occupancy index (ADR-0005) **at placement time, regardless of `BuildStatus`**. There is **no intangible-under-construction carve-out anywhere**: because occupancy is a single index that Movement (ADR-0009 — any occupant is a hard blocker) and Combat (ADR-0010 — any structure occupant is a legal target and blocks DIRECT line-of-fire) already consult, an Under-Construction structure blocks and is targetable *by construction of the shared index*, satisfying Rule 3 with zero new branch. Atomicity vs Grid: `Grid.place` + `AP.spend` occur inside one `apply_action` (ADR-0002 validate-before-mutate), so a rejected/unaffordable build leaves both AP and Grid untouched.

### D3 — `legal_build_tiles` (TR-baseprod-005)

```gdscript
# Pure query. Live — never cached (Edge Case: a destroyed enemy structure frees
# formerly-excluded tiles on the very next call).
static func legal_build_tiles(state: GameState, player: int, structure_type: StructureTypeDef) -> Array[Vector2i]:
    var grid: GridState = state.grid
    var candidates: Dictionary = {}                      # Vector2i -> true, dedup ONLY.
    # NOTE (determinism): this Dictionary is a transient membership/dedup structure whose
    # iteration order is NEVER observed by any caller — the `sort_custom(_by_tile_index)`
    # below is what makes the RETURNED order canonical (ADR-0003). Do NOT copy this
    # Dictionary-as-set idiom into a context that returns/iterates it without a following
    # sort — that would trip the registered `nondeterministic_iteration_order` ban
    # (ADR-0009 deliberately avoided Dictionary for exactly this reason).
    # Candidate universe = passable, empty, in-bounds neighbours of the player's OWN entities.
    # (Rule 5 adjacency: manhattan==1 to a friendly unit OR structure — so the friendly
    #  frontier IS the exact candidate set; a full-board scan would test the same tiles.)
    for e: EntityState in _friendly_entities(state, player):
        for n: Vector2i in _neighbors_in_fixed_order(e.position, grid):   # N→E→S→W (ADR-0009 convention)
            if grid.in_bounds(n) and grid.is_passable(n) and grid.occupant_at(n) == -1:
                candidates[n] = true
    var out: Array[Vector2i] = []
    for t: Vector2i in candidates:
        if _clears_enemy_standoff(state, player, t):     # manhattan(t, e_struct) > 2 for EVERY enemy structure
            out.append(t)
    out.sort_custom(_by_tile_index)                      # canonical y*W+x ascending (ADR-0003 stable order)
    return out
```

- **HQ is never a candidate**: the HQ is setup-placed and is not a buildable `structure_type` offered to `legal_build_tiles` (Rule 2 / AC "HQ never in `legal_build_tiles`").
- **Adjacency counts friendly units AND friendly structures** (Rule 5 / AC).
- **Standoff is `> 2` (strict)**: a tile at manhattan exactly 2 from any enemy structure is excluded (AC).
- **Determinism**: returned in canonical tile-index order regardless of entity/neighbor scan order (ADR-0003). Cost ≈ `friendly_count × 4 × enemy_structure_count` — bounded and cheap; recomputed live each preview frame.
- `structure_type` does not change placement legality in the VS (all buildables share the same adjacency+standoff rule); it is passed for forward-compatibility (e.g. a future per-type placement constraint or a faction `faction_allows` gate) and to keep the signature aligned with ADR-0011's forward declaration.

### D4 — `produce` + `legal_deploy_tiles` (TR-baseprod-008)

```gdscript
static func legal_deploy_tiles(state: GameState, producer: StructureState, unit_type: UnitTypeDef) -> Array[Vector2i]:
    # Empty, passable, in-bounds tiles at manhattan==1 from the producer.
    var grid: GridState = state.grid
    var out: Array[Vector2i] = []
    for n: Vector2i in _neighbors_in_fixed_order(producer.position, grid):
        if grid.in_bounds(n) and grid.is_passable(n) and grid.occupant_at(n) == -1:
            out.append(n)
    out.sort_custom(_by_tile_index)
    return out

static func validate_produce(state, producer: StructureState, unit_type: UnitTypeDef, tile: Vector2i) -> ActionResult:
    # (1) producer Completed;  (2) unit_type in producer.type.producible_types (Resource-ref membership);
    # (3) producer.units_produced_this_turn < effective_production_cap(state, producer, owner)  [ADR-0012 fold];
    # (4) AP.can_afford(state, owner, Unit.effective_produce_cost(state, unit_type, owner))     [Unit-owned cost, ADR-0012 fold];
    # (5) tile in legal_deploy_tiles(state, producer, unit_type).
    # Any failure -> ActionResult{ ok=false, reason }. No mutation (ADR-0002).
```

`apply_produce` (only after `validate_produce` passes, same atomic action): `AP.spend(cost)`; create a `UnitState` via the Unit epic's factory (ADR-0007 schema) as **Active** on `tile` (units have no build time — Unit Rule 2); `Grid.place`; `producer.units_produced_this_turn += 1`; append the unit's spawn event. `producible_types` membership is Resource-reference identity against the preload'd registry (ADR-0007 `runtime_load_of_type_templates` forbidden), never a string/enum compare. Re-validation is idempotent at commit (ADR-0002): if the deploy tile or producer status changed between preview and commit, `apply` re-runs `validate_produce` and rejects with no spend.

### D5 — `cancel_build` + refund (part of TR-baseprod-002, Rule 10)

`cancel_build(structure)` validates: structure is owner's, `UNDER_CONSTRUCTION` (Completed structures cannot be cancelled — only combat-destroyed), and applies: **credit** `refund` AP to the owner's pool, `Grid.remove(position)`, `entities_by_id.erase(entity_id)`. Refund uses **integer fixed-point** (see D6), returned on the `ActionResult` so the Command FSM / HUD render it from the query rather than re-deriving it (registry `balance_constant_in_presentation_layer` forbidden). Combat destruction never calls `cancel_build`, so it never refunds (Rule 10 / AP Economy Rule 6).

### D6 — B&P-owned config (`BaseProductionConfig`)

B&P's non-template constants live in a dedicated `BaseProductionConfig` (`extends Resource`, `.tres`), loaded once via the existing `Balance`-style logic-free Autoload (ADR-0006 `gameplay_config_storage` pattern) — never on `GameState`, so it is not deep-copied by the AI clone loop.

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| `cancel_refund_pct` | int | 50 | **Fixed-point percent** (not a float rate). `refund = build_cost * cancel_refund_pct / 100` via integer division — floors toward the harsher side exactly as `floor(build_cost × 0.5)` (4→2, 9→4, 6→3, odd 5→2). Keeps the AP-refund path integer-only per ADR-0003; matches ADR-0009's `soft_move_penalty_x10` fixed-point precedent. |
| `defensive_attack_cost` | int | 1 | B&P-owned; **read cross-system by Combat** (ADR-0010) to price a Defensive Structure's fire (< unit `attack_cost` 2). Same cross-system-config-read pattern as EconomyConfig's tier threshold. |
| `max_outpost_count` | int | 10 | **Disabled** in the VS (0 or a sentinel = off). Documented tuning lever only; `completed_outpost_count` is not count-capped in the VS. |

> **GDD representation note (non-behavioral):** base-production.md states `CANCEL_REFUND_RATE = 0.5` (float). This ADR refines it to `cancel_refund_pct: int = 50` for ADR-0003 integer-path compliance. Numerically identical across the whole tunable range (0.3–0.6 → 30–60). A one-line GDD footnote is owed noting the fixed-point representation (no value/behavior change).

### Architecture Diagram

```
apply_action(action)                         [ADR-0002: sole mutation vector]
    │  verb-enum dispatch
    ├── BUILD        → BaseProduction.validate_build / apply_build
    ├── PRODUCE      → BaseProduction.validate_produce / apply_produce
    └── CANCEL_BUILD → BaseProduction.validate_cancel / apply_cancel
                            │
   reads ─────────────┬────┴─────────────┬───────────────────────┐
   AP.can_afford/spend│  Grid.place/remove│  StructureTypeDef      │  effective_* (ADR-0012)
   (ADR-0006)         │  occupant_at      │  .producible_types     │  effective_build_cost/
                      │  is_passable      │  (ADR-0007 registry)   │  _time/_production_cap
                      │  manhattan/neigh  │                        │  (== base under Neutral)
                      │  (ADR-0005)       │
   queries (pure, no mutation, live):
     legal_build_tiles(state, player, structure_type) -> Array[Vector2i]
     legal_deploy_tiles(state, producer, unit_type)   -> Array[Vector2i]
     advance_build_timers(state, player) -> Array[Event]   [body of ADR-0008 step 3 contract]
   terminal exits:
     cancel_build → erase + refund      (this ADR)
     destroy_entity (ADR-0010)          → erase, no refund
```

### Key Interfaces

```gdscript
class_name BaseProduction extends RefCounted   # static-only; never instantiated

# Queries (pure, live, deterministic order — ADR-0003)
static func legal_build_tiles(state: GameState, player: int, structure_type: StructureTypeDef) -> Array[Vector2i]
static func legal_deploy_tiles(state: GameState, producer: StructureState, unit_type: UnitTypeDef) -> Array[Vector2i]

# Verb validate/apply pairs (dispatched by apply_action — ADR-0002)
static func validate_build(state, player: int, structure_type: StructureTypeDef, tile: Vector2i) -> ActionResult
static func apply_build(state,   player: int, structure_type: StructureTypeDef, tile: Vector2i) -> Array[Event]
static func validate_produce(state, producer: StructureState, unit_type: UnitTypeDef, tile: Vector2i) -> ActionResult
static func apply_produce(state,   producer: StructureState, unit_type: UnitTypeDef, tile: Vector2i) -> Array[Event]
static func validate_cancel(state, structure: StructureState) -> ActionResult
static func apply_cancel(state,   structure: StructureState) -> Array[Event]   # credits refund

# Start-of-turn contract body (declared by ADR-0008; sequenced by it at step 3)
static func advance_build_timers(state: GameState, player: int) -> Array[Event]

# Effective (faction-folded) reads — B&P-owned effective_X sites per ADR-0012; == base under Neutral
static func effective_build_cost(state, structure_type: StructureTypeDef, player: int) -> int
static func effective_build_time(state, structure_type: StructureTypeDef, player: int) -> int
static func effective_production_cap(state, producer: StructureState, player: int) -> int   # TWO-SIDED: base==0 → 0; base>=1 → max(1, base+delta)
```

## Alternatives Considered

### Alternative 1: BaseProduction as a Node / Autoload with instance state
- **Description**: A `BaseProduction` Node holding build queues / caches as instance state.
- **Pros**: Could cache `legal_build_tiles`.
- **Cons**: Would be deep-copied (or need exclusion plumbing) on every AI `clone()`; caching live placement legality across a mutating board is a stale-cache bug magnet (the GDD explicitly requires live recompute); breaks the uniform static-utility shape shared by AP/Movement/Combat.
- **Rejection Reason**: Contradicts the corpus-wide static-utility pattern and the "live, never cached" requirement; adds clone cost for no gain (the frontier scan is already cheap).

### Alternative 2: Store all four GDD lifecycle states as a persisted enum
- **Description**: `BuildStatus { UNDER_CONSTRUCTION, COMPLETED, DESTROYED, REMOVED }` kept on `StructureState`.
- **Pros**: Mirrors the GDD's lifecycle table literally.
- **Cons**: Keeps dead terminal entities in `entities_by_id`, forcing every consumer (Grid, Combat, HUD, `completed_outpost_count`) to add an "is it actually alive?" filter; duplicates the erasure that Grid + ADR-0010 `destroy_entity` already own; two ways to represent "gone" (a DESTROYED row *and* absence) invite drift.
- **Rejection Reason**: The 2-value enum + terminal erasure keeps one alive-invariant ("in `entities_by_id` ⇔ alive") and no filtering; user-confirmed.

### Alternative 3: Float cancel-refund rate (as written in the GDD)
- **Description**: `CANCEL_REFUND_RATE: float = 0.5`, `refund = floori(build_cost * rate)`.
- **Pros**: Verbatim GDD match.
- **Cons**: Injects a float into the AP-refund path; ADR-0003 keeps the economy integer-only; ADR-0009 already set the scaled-int precedent.
- **Rejection Reason**: Fixed-point `cancel_refund_pct: int` is numerically identical and determinism-clean; user-confirmed.

## Consequences

### Positive
- Closes the last 4 B&P mechanic TRs; the 200-TR matrix reaches 197 covered (only ADR-0018's 3 Research TRs remain Partial).
- Concretely fulfills ADR-0011's and ADR-0015's forward-declared `legal_build_tiles`/`legal_deploy_tiles`/`production_cap` dependencies — those consumers now resolve as written.
- One structure-alive invariant (in `entities_by_id` ⇔ alive) — no dead-state filtering across consumers.
- Uniform with AP/Movement/Combat: same static-utility shape, same clone-free config pattern, same apply_action dispatch.

### Negative
- A few structure-lifecycle fields sit unused on non-producer / non-defensive structure types (`units_produced_this_turn` on the Economy Outpost, etc.) — an accepted cost already baked into ADR-0007's single-`StructureState` decision.
- `advance_build_timers`' body lives here while its *sequencing* lives in ADR-0008 — the split must be read across two ADRs (mitigated by the explicit cross-reference in both).

### Risks
- **Signature drift** vs ADR-0011/0015 forward declarations. *Mitigation*: signatures here are transcribed to match the registry's forward-declared shapes (`legal_build_tiles(state, player, structure_type)`, `legal_deploy_tiles(state, producer, unit_type)`); a `/architecture-review` after Accept re-checks.
- **`effective_production_cap` two-sided invariant** (ADR-0012 TR-faction-006): base cap 0 must stay 0 (a non-producer never becomes a producer via faction delta); base ≥ 1 → `max(1, base + delta)`. *Mitigation*: implemented as the two-branch form ADR-0012 specifies, not a single `max(0, …)` clamp; covered by the Neutral-inert regression test.
- **`cancel_refund_pct` fixed-point** must use integer division (`build_cost * pct / 100`), not float then floor, to stay determinism-clean. *Mitigation*: stated in D6; unit test asserts 4/9/6/5 → 2/4/3/2. (godot-specialist 2026-07-24 confirmed GDScript integer `/` truncates toward zero = `floor` for these non-negative operands.)
- **`Dictionary`-as-set in `legal_build_tiles`** could mislead a future maintainer into reusing the idiom where the trailing `sort_custom` is dropped, tripping `nondeterministic_iteration_order` (ADR-0003). *Mitigation*: the transient dedup Dictionary's iteration order is never observed (only membership); the canonical returned order comes solely from `sort_custom(_by_tile_index)`. Comment in D3 flags this explicitly (godot-specialist 2026-07-24 MINOR note). `_by_tile_index` is a `static func(a,b)->bool` comparator with no captured state (matches ADR-0009's `_neighbors_in_fixed_order`).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| base-production.md | Rule 3 — structures occupy 1 tile, block movement + DIRECT LoF, targetable while building (TR-baseprod-003) | D2 status-agnostic single-index occupancy; blocking/targeting inherited from the shared Grid index consulted by Movement/Combat — no carve-out |
| base-production.md | Rule 4 — build spends `build_cost`, places Under-Construction, occupies immediately | D1 `apply_build` + D2 atomic `AP.spend` + `Grid.place` in one `apply_action` |
| base-production.md | Rule 5 — placement: empty+passable, manhattan==1 to friendly, >2 from every enemy structure, live (TR-baseprod-005) | D3 `legal_build_tiles` friendly-frontier candidate set + strict-`>2` standoff filter, recomputed each call, HQ excluded |
| base-production.md | Rule 7 — produce: Completed producer, in `producible_types`, `production_cap`/turn, deploy adjacent empty (TR-baseprod-008) | D4 `validate_produce` 5-gate + `legal_deploy_tiles`; `apply_produce` spawns Active unit; Resource-ref membership |
| base-production.md | Rule 10 — voluntary cancel refunds `floor(build_cost × 0.5)`; combat destruction refunds nothing | D5 `cancel_build` integer refund (D6 fixed-point) + erase; combat path via `destroy_entity` (ADR-0010) never refunds |
| base-production.md | Lifecycle table — Under-Construction/Completed/Destroyed/Removed (TR-baseprod-002) | D1 2-value stored `BuildStatus` + two terminal erasure exits (cancel/destroy) |
| base-production.md | Rule 13 — deterministic, headless, clone-safe | Pure static functions over `GameState`; canonical tile-index ordering; no RNG (ADR-0003) |

## Performance Implications
- **CPU**: `legal_build_tiles` ≈ `friendly_count × 4 × enemy_structure_count` per call; `legal_deploy_tiles` ≈ 4 checks; both trivial on a 14×16 board, safe to recompute live during preview (no cache, no spike gate).
- **Memory**: zero persistent — static class, no instance state; config is a single shared `.tres` (not clone-copied).
- **Load Time**: one preload of `BaseProductionConfig` alongside the other configs.
- **Network**: N/A (no netcode).

## Migration Plan
No existing code. Greenfield: the Base & Production epic implements this ADR. `advance_build_timers` and `Structure.reset_turn_flags` bodies (forward-declared by ADR-0008) are implemented here at the same time.

## Validation Criteria
- Base-production.md Pure-Logic gate passes against injected Grid + AP fixtures: template inertness of Under-Construction structures; `legal_build_tiles` adjacency/standoff boundary cases (manhattan exactly 2 excluded, unit-or-structure adjacency, HQ excluded, empty when no legal tile); `produce` cap/type/deploy gates; `cancel_refund` = 2/4/3 (and 5→2); determinism under `clone()` (two clones of the same fixture, same action → field-wise equal; source unchanged).
- Integration gate (real Grid + AP + Turn Manager + Unit): build→income timing (Rule 6 ordering, owned by ADR-0008 but exercised end-to-end here), produce→real Unit entity, live re-legalization after an enemy structure is destroyed.
- A `/architecture-review` after Accept confirms the 4 TRs flip Covered and no signature drift vs ADR-0011/0015.

## Related Decisions
- ADR-0002 (apply_action command model) — verb dispatch + atomicity + idempotent re-validate
- ADR-0005 (grid representation) — occupancy/placement primitives
- ADR-0006 (AP economy) — cost gate + config-as-Resource pattern
- ADR-0007 (entity/stat schema) — `StructureState`, `BuildStatus`, `producible_types`, type registry
- ADR-0008 (start-of-turn sequencing) — sequences `advance_build_timers`/`reset_turn_flags` bodies defined here
- ADR-0010 (combat/destruction) — `destroy_entity` terminal exit; reads `defensive_attack_cost`
- ADR-0011 (AI loop) / ADR-0015 (command FSM) — consumers of `legal_build_tiles`/`legal_deploy_tiles`/`production_cap`
- ADR-0012 (faction framework) — `effective_build_cost`/`_time`/`_production_cap` folds
- ADR-0018 (Research mechanics, planned) — the Research Lab reuses this lifecycle wholesale (base-production.md Rule 2b)
