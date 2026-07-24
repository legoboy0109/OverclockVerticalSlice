# ADR-0009: Reachable-Search / Pathfinding Strategy

## Status
Proposed

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Pathfinding (custom hand-rolled search — NOT Godot's Navigation module) |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/modules/navigation.md`, `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — `PackedInt32Array`, `RefCounted`, plain `Array`-backed queues are stable pre-cutoff GDScript. This ADR deliberately does **not** use `AStarGrid2D`/`AStar2D` or `NavigationAgent2D`/`NavigationServer2D` (see Alternatives) |
| **Verification Required** | None. **godot-specialist review 2026-07-24 (CONFIRMED):** `class_name Movement extends RefCounted` static-utility container, `PackedInt32Array.resize()` + `.fill(-1)` (stable since 4.0, no 4.4–4.6 change), `Array[Vector2i]` frontier layers, and a nested `class ReachableTile extends RefCounted` inside a `class_name`-registered outer class are all idiomatic, pre-cutoff-stable GDScript with no post-cutoff behavior changes. One code-sample bug (a non-chainable `.set()` constructor call) was found and fixed — `ReachableTile` now has an explicit `_init(t, c, surcharged)`. |

Godot's Navigation module (`docs/engine-reference/godot/modules/navigation.md`) is for continuous-space
agents over a baked navmesh (`NavigationAgent2D`/`3D`, RVO2 avoidance) — not applicable here. `AStarGrid2D`
is the closer built-in fit for a grid, but is explicitly rejected below: its `_compute_cost`/`_estimate_cost`
overrides receive only the two grid points, with no accumulated path-depth (`g_score`) parameter, so a
cost that depends on `tiles_moved_this_turn` + steps-so-far cannot be computed inside them without
smuggling in external mutable state — which breaks A*'s "a settled node's cost is final" closed-set
invariant (the same tile legitimately has different entry costs on different-depth paths).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`GameState`/`clone()` — search runs against a passed-in state, never the authoritative singleton, for AI lookahead safety), ADR-0002 (`apply_action`/verb-handler shape — `Movement.validate()`/`apply()` are the `MoveAction` handlers dispatched through the verb-enum table), ADR-0003 (determinism: flat-array visited/cost table not `Dictionary`; integer-only cost; fixed-point `SOFT_MOVE_PENALTY`), ADR-0005 (`GridState.neighbors()`/`is_passable()`/`occupant_at()`/`manhattan_distance()` — the exact query surface this search is built on), ADR-0006 (`AP.can_afford()`/`spend()`; this ADR mirrors ADR-0006's static-utility-class shape and its `gameplay_config_storage` pattern for the new `UnitConfig` resource), ADR-0007 (`UnitState.move_cost`/`soft_move_cap`/`tiles_moved_this_turn` fields; `entity_subclass_shape` — resolving an occupant via `GameState.entity_at()` to check `UnitState` vs `StructureState` and `owner`) |
| **Enables** | ADR-0011 (AI query-façade — `reachable()` is one of the AI's core side-effect-free queries, called from many cloned states per turn), ADR-0015 (Command FSM — renders the reachable set + per-tile path/cost preview this ADR produces) |
| **Blocks** | Movement System epic/stories (`movement-001`..`014`) cannot start implementation until this ADR is Accepted |
| **Ordering Note** | Per the Technical Director's 2026-07-23 sign-off condition, this ADR must not be **Accepted** until the QQ-05 perf spike (`reachable()` ms/call on 24×24, interactive + AI-repeat) is run by performance-analyst. Authoring/Proposing now is not blocked — only Accept is. |

## Context

### Problem Statement

Movement needs a deterministic `reachable(state, unit)` search that returns every tile a unit can legally
reach and stop on this turn, at exact AP cost, honoring: 4-directional traversal, friendly-unit
pass-through (structures always block, even friendly ones), and a **depth-dependent** edge cost — the
`soft_move_cap` surcharge, where the first `soft_move_cap` tiles entered *cumulatively this turn* cost
`move_cost` each, and every tile beyond costs a flat `ceil(move_cost × SOFT_MOVE_PENALTY)`. This cost
depends on cumulative path depth (`tiles_moved_this_turn` + steps taken along the candidate path), which
Godot's built-in grid pathfinder (`AStarGrid2D`) cannot express (see Engine Compatibility). The search must
also be callable many times per AI turn against cloned `GameState` instances (AI lookahead), so it must be
cheap, allocate predictably, and never touch the authoritative state.

### Constraints

- Cannot use `AStarGrid2D`/`AStar2D` (depth-dependent cost, see above) or Godot's Navigation module
  (continuous-space, not grid-native).
- Must produce bit-identical results across runs and across `clone()`d states (ADR-0003 determinism).
- Visited/cost bookkeeping must use flat arrays, never `Dictionary` (`nondeterministic_iteration_order`,
  already registered).
- `reachable()` is called with no cache, recomputed fresh every invocation (movement-system.md's explicit
  no-stale-cache rule) — so its per-call cost matters more than a one-shot pathfinder's would.
- All cost arithmetic must be integer (`float_in_state`, already registered); `SOFT_MOVE_PENALTY` cannot
  be stored as a bare float.

### Requirements

- `reachable(state, unit) -> Array[ReachableTile]` — side-effect-free, pure function of the passed state.
- `move_path_cost` computation shared identically between `reachable()`'s preview and `move()`'s billing
  (movement-system.md's reachable-vs-billed agreement invariant).
- `Movement.validate()`/`Movement.apply()` conform to ADR-0002's verb-handler contract for `MoveAction`.
- Deterministic tie-break: when multiple equal-length paths exist, the same tile sequence is chosen every
  time (stable neighbor-expansion order).

## Decision

**Movement is a static utility class** (`class_name Movement extends RefCounted`, no instance state),
mirroring ADR-0006's `AP` shape and ADR-0002's verb-handler pattern. All entry points take `state`
explicitly — never touch a global/Autoload state reference — so the exact same code runs against the
authoritative `GameState` and any AI-cloned copy.

**Search algorithm: plain BFS by depth, plus a closed-form length→cost conversion — not a priority-queue
Dijkstra.** Under the GDD's proven min-length ≡ min-cost property (cost is a pure function of path
*length* given a fixed starting `tiles_moved_this_turn`; see movement-system.md Formulas), the shortest
*path* to a tile is always its cheapest path. A tile therefore only needs to be visited once, at the
first (shallowest) BFS layer that reaches it — no `(tile, depth)` keys, no relaxation, no priority queue.
Each layer's cost is computed by the closed-form summation (`base_tiles × move_cost + overcap_tiles ×
surcharge`), which is monotonically non-decreasing in depth, so BFS expansion can stop the instant a
layer's cost exceeds `current_ap` — nothing beyond that layer is affordable.

**This shortcut is explicitly scoped to the current uniform-terrain ruleset.** The moment
difficult-terrain (variable per-tile move cost, an Alpha Open Question in movement-system.md) lands, cost
is no longer a pure function of length, and this ADR's algorithm must be revisited in favor of a true
`(tile, depth)`-keyed weighted search. This is called out here as a designed, temporary scope boundary,
not an oversight.

### Traversal Predicate

Two distinct predicates, both built on `GridState`'s existing query surface (ADR-0005) plus one
occupant-resolution step this ADR adds:

```gdscript
static func _is_traversable(state: GameState, x: int, y: int, mover_owner: int) -> bool:
    # Can a path CROSS this tile? (friendly units pass through; structures never do — GDD Rule 3)
    if not state.grid.in_bounds(x, y):
        return false
    if state.grid.terrain_at(x, y) == GridState.Terrain.IMPASSABLE:
        return false
    var occupant_id: int = state.grid.occupant_at(x, y)
    if occupant_id == -1:
        return true
    var occupant: EntityState = state.entity_at(Vector2i(x, y))
    return occupant is UnitState and occupant.owner == mover_owner
    # StructureState (any owner) and enemy UnitState both return false — hard blockers

static func _is_valid_destination(state: GameState, x: int, y: int) -> bool:
    # Can a path STOP here? Reuses Grid's existing is_passable() verbatim — no new logic needed:
    # is_passable() already means "terrain != IMPASSABLE and occupant is empty" (ADR-0005).
    return state.grid.is_passable(x, y)
```

`_is_traversable` is the BFS expansion predicate (what gets visited); `_is_valid_destination` filters the
final visited set down to the tiles actually returned as legal move targets (a friendly-occupied tile is
visited/traversable but excluded from the returned set, per GDD Rule 4/5).

### Key Interfaces

```gdscript
class_name Movement extends RefCounted

class ReachableTile extends RefCounted:
    var tile: Vector2i
    var min_cost: int
    var is_surcharged: bool
    func _init(t: Vector2i, c: int, surcharged: bool) -> void:
        tile = t
        min_cost = c
        is_surcharged = surcharged

# Pure, side-effect-free. Callable against the authoritative state or any clone().
static func reachable(state: GameState, unit: UnitState) -> Array[ReachableTile]:
    var grid: GridState = state.grid
    var w: int = grid.width
    var h: int = grid.height
    var visited_depth := PackedInt32Array()
    visited_depth.resize(w * h)
    visited_depth.fill(-1)                       # -1 = unvisited; flat array, index = y*w+x (ADR-0003)

    var start: Vector2i = unit.position
    visited_depth[grid.index(start.x, start.y)] = 0
    var frontier: Array[Vector2i] = [start]
    var results: Array[ReachableTile] = []
    var depth := 0

    while not frontier.is_empty():
        depth += 1
        var cost_at_depth := _cost_for_depth(unit, depth)
        if cost_at_depth > state.current_ap(unit.owner):
            break                                 # monotonic cost — nothing deeper is affordable
        var surcharged := _is_surcharged_at_depth(unit, depth)
        var next_frontier: Array[Vector2i] = []
        for pos in frontier:
            for n in _neighbors_in_fixed_order(grid, pos):   # explicit N→E→S→W, see Risks
                var idx := grid.index(n.x, n.y)
                if visited_depth[idx] != -1:
                    continue                       # already settled at an equal-or-shallower depth
                if not _is_traversable(state, n.x, n.y, unit.owner):
                    continue
                visited_depth[idx] = depth
                next_frontier.append(n)
                if _is_valid_destination(state, n.x, n.y):
                    results.append(ReachableTile.new(n, cost_at_depth, surcharged))
        frontier = next_frontier

    return results

# is_surcharged: does a min-length path of this depth cross the soft cap at all?
static func _is_surcharged_at_depth(unit: UnitState, depth: int) -> bool:
    return depth > max(0, unit.soft_move_cap - unit.tiles_moved_this_turn)

# Determinism: iterate neighbors in an explicit fixed order at the BFS call site so
# ADR-0009's tie-break does NOT depend on GridState.neighbors()'s unstated order.
# (See Risks — the cleaner long-term fix is ADR-0005 pinning the order in its own contract.)
static func _neighbors_in_fixed_order(grid: GridState, pos: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
        var n := pos + d
        if grid.in_bounds(n.x, n.y):
            out.append(n)
    return out

static func move_path_cost(unit: UnitState, tiles_entered: int) -> int:
    # Shared by reachable()'s per-depth cost and move()'s billing — the agreement invariant.
    return _cost_for_depth(unit, tiles_entered)

static func _cost_for_depth(unit: UnitState, tiles_entered: int) -> int:
    var c: int = unit.soft_move_cap
    var m: int = unit.tiles_moved_this_turn
    var t: int = tiles_entered
    var surcharge: int = UnitConfig.surcharge_for(unit.move_cost)   # ceil(move_cost * SOFT_MOVE_PENALTY)
    var base_tiles: int = max(0, min(t, c - m))
    var overcap_tiles: int = t - base_tiles
    return base_tiles * unit.move_cost + overcap_tiles * surcharge

# ADR-0002 verb-handler contract — dispatched via action.verb through Dictionary[int, Callable]
static func validate(state: GameState, action: MoveAction) -> int:            # -> Reason enum, PURE
    # ... in_bounds, destination is in reachable(state, unit), AP.can_afford(cost) ...
    return Reason.OK

static func apply(state: GameState, action: MoveAction) -> Array[Event]:      # assumes validated
    var unit: UnitState = state.entity_at(action.unit_position) as UnitState
    var cost: int = move_path_cost(unit, action.tiles_entered)
    AP.spend(state, unit.owner, cost)                 # ADR-0006 — sole AP deductor
    state.grid.move(action.from, action.to)           # ADR-0005 — sole occupancy mutator
    unit.position = action.to
    unit.tiles_moved_this_turn += action.tiles_entered
    return [UnitMovedEvent.new(unit.entity_id, action.from, action.to, cost)]
```

**New: `UnitConfig` resource.** `SOFT_MOVE_PENALTY` is a Unit-owned **global** constant (not per-type —
ADR-0007's `UnitTypeDef` is per-type and is the wrong home). This ADR adds a new `UnitConfig` resource
mirroring ADR-0006's `EconomyConfig`/`gameplay_config_storage` pattern exactly:

```gdscript
class_name UnitConfig extends Resource
@export var soft_move_penalty_x10: int = 20   # fixed-point: 20 = 2.0 (TR-movement-011)

static func surcharge_for(move_cost: int) -> int:
    return (move_cost * UnitConfig.soft_move_penalty_x10 + 9) / 10   # integer ceil-division
```

Loaded once by a thin logic-free loader (extends the existing `Balance`-style Autoload pattern from
ADR-0006, or a sibling `UnitBalance` Autoload if `Balance` is scoped per-system — reconciled at
implementation, not a blocking ambiguity for this ADR). `UnitConfig` is never stored on `GameState` — same
reasoning as `EconomyConfig`: it must never be touched by `duplicate_deep()`'s per-candidate-action AI
clone loop.

**Allocation strategy: fresh-per-call.** `visited_depth` (a `PackedInt32Array`) and `frontier`/`results`
(plain `Array`) are allocated new on every `reachable()` call. This is TR-movement-010's explicitly-flagged
open decision. A pooled-and-cleared array would be faster under the AI's repeated-call lookahead pattern,
but introduces a correctness risk this early: a pooled buffer must be provably cleared before every use to
avoid stale depth values leaking across different cloned `GameState`s evaluated in the same AI turn — a
subtle bug class not worth the premature optimization. Revisit if QQ-05's perf spike shows fresh-per-call
is the bottleneck; this decision is explicitly reversible without touching the algorithm.

### Architecture Diagram

```
  GameState.clone() ──▶ cloned GameState ──▶ Movement.reachable(cloned_state, unit)
       (AI lookahead,                              │
        many times/turn)                            ▼
                                          GridState.neighbors()/is_passable()/
                                          occupant_at() (ADR-0005, read-only)
                                                     │
                                                     ▼
                                    flat PackedInt32Array visited_depth[y*w+x]
                                    (fresh per call — no cross-call state)
                                                     │
                                                     ▼
                                    Array[ReachableTile] {tile, min_cost, is_surcharged}
                                          │                              │
                                          ▼                              ▼
                              Command & Action Interface        AI Opponent (candidate
                              (ADR-0015 — overlay + preview)     move scoring, CR-4)

  MoveAction ──apply_action (ADR-0002)──▶ Movement.validate() / Movement.apply()
                                                     │
                                     AP.spend() (ADR-0006) · GridState.move() (ADR-0005)
                                     · unit.tiles_moved_this_turn += (this ADR)
```

## Alternatives Considered

### Alternative 1: `AStarGrid2D` with `_compute_cost`/`_estimate_cost` overrides
- **Description**: Use Godot's built-in grid pathfinder, overriding its per-edge cost callbacks to apply
  the soft-cap surcharge.
- **Pros**: Engine-native, well-tested, no hand-rolled search to maintain.
- **Cons**: The cost callbacks receive only the two grid points (`from`, `to`) — no accumulated path
  depth / `g_score` parameter. A cost that depends on `tiles_moved_this_turn` + steps-so-far cannot be
  computed inside them without external mutable state, which breaks A*'s closed-set invariant (a settled
  node's cost must be final; here the same tile legitimately has different entry costs at different
  depths).
- **Rejection Reason**: Cannot express the depth-dependent edge cost at all — not a performance or
  ergonomics tradeoff, a hard correctness blocker. Confirmed by movement-system.md's own implementation
  note (2026-07-20/21 design review).

### Alternative 2: Full `(tile, depth)`-keyed weighted Dijkstra (priority queue)
- **Description**: The fully general correct algorithm for depth-dependent edge costs — key the
  settled-cost table by `(tile, depth)` instead of `tile` alone, using a priority queue.
- **Pros**: Correct even if per-tile cost were NOT a pure function of path length (e.g. once
  difficult-terrain lands and a shorter path can cost more than a longer one).
- **Cons**: A priority queue in GDScript is slower and more code than a plain BFS-by-depth for no
  benefit under the *current* uniform-terrain ruleset, where min-length ≡ min-cost is proven (see
  Decision).
- **Rejection Reason**: Overengineered for the Vertical Slice's ruleset. Explicitly flagged in the
  Decision as the correct fallback once difficult-terrain lands — not discarded, deferred.

### Alternative 3 (module shape): `reachable()`/`move_path_cost()` as instance methods on `GridState`
- **Description**: Add the search directly to `GridState` (ADR-0005) since it walks the grid.
- **Pros**: Co-locates grid-walking logic with the grid it walks.
- **Cons**: Couples `GridState` to Unit-owned fields (`move_cost`, `soft_move_cap`,
  `tiles_moved_this_turn`, `SOFT_MOVE_PENALTY`) it has no other reason to know about — `GridState`'s
  current API is entity-agnostic (works in terms of `entity_id`, never `UnitState`).
- **Rejection Reason**: Breaks the clean layering ADR-0005 established ("Grid never depends on
  Unit/Structure types" — Consequences: Positive).

### Alternative 4 (module shape): `reachable()`/`move_path_cost()` as instance methods on `GameState`
- **Description**: Add directly to `GameState` (ADR-0001).
- **Pros**: Simplest call site (`state.reachable(unit)`).
- **Cons**: `GameState` re-accretes every Core system's logic — exactly the pattern ADR-0006 explicitly
  rejected for AP Economy in favor of a static utility class.
- **Rejection Reason**: Inconsistent with the established `ap_economy_module_shape` precedent; no
  offsetting benefit.

## Consequences

### Positive
- Depth-dependent cost is correctly expressible without fighting the engine's built-in pathfinder.
- BFS-by-depth is simpler and cheaper than a priority-queue Dijkstra, exploiting a proven property of the
  current ruleset rather than assuming general-case weighted search up front.
- `Movement` mirrors `AP`'s established static-utility shape — consistent module conventions across Core
  systems, easier onboarding.
- Fresh-per-call allocation sidesteps an entire class of stale-state-across-clones bugs during the
  highest-risk early implementation window.

### Negative
- The BFS-by-depth shortcut is a scoped, temporary simplification — it must be revisited (algorithm
  change, not just tuning) the moment difficult-terrain lands. This is a known, flagged future cost.
- Introduces a new config resource (`UnitConfig`) and loader wiring not previously scoped by ADR-0007 —
  a small amount of additional Foundation-adjacent surface area this ADR is responsible for closing.
- Fresh-per-call allocation has a real (if currently unmeasured) GC/alloc cost under the AI's repeated
  per-candidate-action call pattern; deferred to the QQ-05 spike rather than solved preemptively.

### Risks
- **Grid neighbor-order is not pinned by ADR-0005 — this ADR does not depend on it.** ADR-0005's
  `neighbors()` docstring says "4-dir, in-bounds filtered, O(4)" but commits to no fixed iteration order.
  This ADR's determinism (TR-movement-007, the tie-break AC) *requires* one. **Resolution** (godot-specialist,
  2026-07-24): a likely `neighbors()` implementation would be order-stable in practice, but that is an
  implementation accident, not a contract — a future refactor of `neighbors()` could silently reorder
  tie-breaks with no signal at the regression point. So `Movement` does **not** call `neighbors()` in its
  BFS; it iterates its own explicit fixed offset order (`_neighbors_in_fixed_order`, N→E→S→W) at the call
  site, making ADR-0009's determinism self-contained. **Recommended follow-up (not blocking):** amend
  ADR-0005 to pin and document the order in `neighbors()`'s own contract (the guarantee belongs where the
  function is defined) — cheap to fold in while ADR-0005 is still `Proposed`. If done, `Movement` may drop
  its private helper and call `neighbors()` directly.
- **Nested-class reference friction.** `ReachableTile` is an inner class of `Movement`; referencing it from
  outside `movement.gd` (tests, ADR-0015's overlay) requires the `Movement.ReachableTile` prefix — inner
  classes are not auto-registered as global `class_name` symbols. Cheap, but noted so test authors and the
  ADR-0015 implementer aren't surprised.
- **QQ-05 perf budget is not yet a concrete number.** This ADR describes the algorithm and its
  complexity shape (`O(reachable-frontier-size)` per call) but does not pin an ms/call target — that is
  explicitly the performance-analyst spike's job per the TD's 2026-07-23 sign-off condition. **Mitigation**:
  this ADR cannot move to Accepted until that spike runs (see ADR Dependencies: Ordering Note).
- **`UnitConfig`/loader Autoload naming is provisional.** Whether the loader is a new Autoload or an
  extension of an existing one is left to implementation. **Mitigation**: low risk — either resolution is
  a mechanical rename, not a design change.

## GDD Requirements Addressed

| GDD | Requirement (TR-ID) | How This ADR Addresses It |
|-----|---------------------|---------------------------|
| movement-system.md | Grid exposes `neighbors()`/`is_passable()`/`occupant_at()` (TR-movement-001) | Consumed directly from ADR-0005's already-pinned `GridState` API; no new Grid surface needed |
| movement-system.md | Hand-rolled BFS/Dijkstra, not `AStarGrid2D`/`AStar2D` (TR-movement-002) | Decision + Alternative 1 (rejected with the specific `_compute_cost` depth-parameter gap) |
| movement-system.md | Length-based BFS shortcut under uniform terrain, upgrades to `(tile,depth)`-keyed search when difficult terrain lands (TR-movement-003) | Decision's BFS-by-depth algorithm; Alternative 2 names the upgrade path explicitly |
| movement-system.md | `reachable(state,unit)->set<{tile,min_cost,is_surcharged}>` side-effect-free (TR-movement-004) | `Movement.reachable()` Key Interface — pure function of the passed `state` |
| movement-system.md | `move(unit,dest)->Result` validates+bills atomically via `apply_action` (TR-movement-005) | `Movement.validate()`/`apply()` as the ADR-0002 verb-handler pair for `MoveAction` |
| movement-system.md | `reachable()` recomputed fresh every call, no caching (TR-movement-008) | No cache anywhere in the Key Interfaces; fresh `visited_depth` array every call |
| movement-system.md | Concrete `reachable()` perf budget owed to ADR/perf-analyst (TR-movement-009, QQ-05) | Algorithm complexity shape stated in Consequences; concrete number explicitly deferred to the spike gating Accept (Ordering Note) |
| movement-system.md | Visited-array allocation strategy explicitly decided (TR-movement-010) | Decision: fresh-per-call, with rationale and an explicit reversibility note |
| movement-system.md | `reachable()`/`move()` share one soft-cap cost-summation path (TR-movement-013) | Both call `_cost_for_depth()`/`move_path_cost()` — the single shared implementation |
| movement-system.md | Visited/cost table = flat array not `Dictionary` (TR-movement-006, governed by ADR-0003) | `PackedInt32Array visited_depth`, `index = y*w+x` — same convention as `GridState` |
| movement-system.md | Pinned reproducible neighbor-expansion order (TR-movement-007, governed by ADR-0003) | `_neighbors_in_fixed_order()` iterates an explicit N→E→S→W offset order at the BFS call site — determinism is self-contained, not dependent on `GridState.neighbors()`'s unstated order (see Risks; ADR-0005 amendment recommended as non-blocking follow-up) |
| movement-system.md | `SOFT_MOVE_PENALTY` as fixed-point int, integer ceil-div (TR-movement-011, governed by ADR-0003) | `UnitConfig.soft_move_penalty_x10` + `surcharge_for()`'s integer ceil-division |
| unit-system.md | Schema enforces `move_cost>=1`, `soft_move_cap>=0` at load (TR-movement-012, governed by ADR-0007) | Precondition this ADR's BFS shortcut relies on (min-length≡min-cost breaks at `move_cost=0`); enforcement itself lives in ADR-0007's schema, referenced here as a load-bearing dependency |
| movement-system.md | Integrate `apply_action` on clonable state (TR-movement-014, governed by ADR-0002) | `Movement.apply()` follows ADR-0002's verb-handler contract exactly |

## Performance Implications

- **CPU**: `reachable()` is `O(frontier size)` per call — bounded by the number of tiles within
  `current_ap`'s reach, not the full board. Called with no cache, many times per AI turn (once per
  candidate unit per cloned state) — the AI's evaluate-commit loop (ADR-0011, OQ-1) is the dominant
  caller, not the interactive player UI. Concrete budget owed to the QQ-05 spike.
- **Memory**: One `PackedInt32Array` of size `width × height` per call (fresh-per-call), plus a small
  `Array[ReachableTile]` for the result. `ReachableTile.new()` is allocated once per **result** tile
  (bounded by `results.size()`), not once per visited tile — a smaller footprint than `visited_depth`
  itself. No persistent allocation between calls.
- **Load Time**: None — no data loaded at match start beyond what ADR-0005/0007 already load.
- **Network**: N/A (no netcode in scope).

## Migration Plan

N/A — new system, no existing code to migrate.

## Validation Criteria

- Unit tests (`tests/unit/movement/`) covering every Acceptance Criterion in movement-system.md,
  including: the soft-cap boundary cases (Scout 4-tile reach at 5 AP, Heavy at-cap empty-set), friendly
  pass-through vs. friendly-structure-blocks (the two split ACs), the reachable-vs-billed agreement
  invariant, and determinism across repeated calls on the same cloned state.
- An integration test (`tests/integration/movement/`) asserting the no-stale-cache rule: compute
  `reachable()`, remove a blocker, compute again, assert the newly-opened tiles appear.
- An integration test asserting deterministic tie-break: two equal-cost paths to the same destination
  resolve to the identical tile sequence across repeated `move()` calls from the same starting state.
- QQ-05 perf spike result (ms/call on 24×24, interactive + AI-repeat) recorded before this ADR moves to
  Accepted.

## Related Decisions

- ADR-0001 (State Model Ownership & Lifecycle)
- ADR-0002 (Action / apply_action Command Model)
- ADR-0003 (Deterministic Simulation & RNG Isolation)
- ADR-0005 (Grid Representation & Map-Definition Format)
- ADR-0006 (AP Economy Data Model & Spend Contract)
- ADR-0007 (Unit & Structure Entity/Stat Schema)
- `design/gdd/movement-system.md`
- `design/gdd/unit-system.md`
