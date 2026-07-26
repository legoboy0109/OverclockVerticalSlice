# Story 001: Reachable-Tile Search (`Movement.reachable()`)

> **Epic**: Movement
> **Status**: Blocked — Unit System Stories 001/002/006 (UnitTypeDef/UnitState/UnitConfig) are Ready but not yet implemented in `src/`; Movement's code reads their fields directly
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/movement-system.md`
**Requirement**: `TR-movement-001`, `TR-movement-002`, `TR-movement-003`, `TR-movement-004`, `TR-movement-006`, `TR-movement-007`, `TR-movement-008`, `TR-movement-010`, `TR-movement-011`, `TR-movement-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Reachable-search / pathfinding strategy
**Secondary ADRs**: ADR-0003 (deterministic simulation — flat-array visited table, fixed-point penalty), ADR-0005 (Grid query surface this search is built on), ADR-0007 (`UnitTypeDef.move_cost`/`soft_move_cap` fields Unit System owns)
**ADR Decision Summary**: A hand-rolled BFS-by-depth search (not `AStarGrid2D`) over a fresh-per-call flat `PackedInt32Array` visited table, expanding neighbors in an explicit fixed N→E→S→W order the search owns itself (not `GridState.neighbors()`, whose order is unpinned). Per-depth cost is soft-cap-aware from the start — the same `_cost_for_depth` the search uses is later shared verbatim by `move()`'s billing (Story 002).

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: `PackedInt32Array.resize()`+`.fill(-1)`, `Array[Vector2i]` frontier layers, and a nested `class` inside a `class_name`-registered outer class are all idiomatic pre-cutoff-stable GDScript per ADR-0009's Engine Compatibility (godot-specialist CONFIRMED 2026-07-24). One thing to remember: `Movement.ReachableTile` is **not** auto-registered as a global `class_name` — external references (tests, later the HUD overlay) need the `Movement.ReachableTile` prefix.

**Control Manifest Rules (this layer)**:
- Required: "`Movement` must be a static utility class (`class_name Movement extends RefCounted`, no instance state); all entry points take `state` explicitly" — source: ADR-0009
- Required: "The reachable-tile search must use plain BFS by depth plus a closed-form length→cost conversion — not a priority-queue Dijkstra" — source: ADR-0009
- Required: "BFS expansion must stop the instant a layer's cost exceeds `current_ap`" — source: ADR-0009
- Required: "Visited/cost bookkeeping must use flat `PackedInt32Array`, never `Dictionary`" — source: ADR-0009
- Required: "`reachable()` must be recomputed fresh every invocation — no caching, fresh-per-call allocation" — source: ADR-0009
- Required: "`Movement` must NOT call `GridState.neighbors()` for BFS traversal (order unpinned); it must iterate its own explicit fixed offset order (N→E→S→W)" — source: ADR-0009
- Required: "Occupancy predicate for movement: friendly units may be passed through; structures (any owner) and enemy units are always hard blockers" — source: ADR-0009
- Required: "`SOFT_MOVE_PENALTY` must be a Unit-owned fixed-point int in a `UnitConfig` Resource (`soft_move_penalty_x10`), never on `GameState`" — source: ADR-0009
- Forbidden: "Never use `AStarGrid2D`/`AStar2D`/`NavigationServer2D`/`NavigationAgent2D` for the reachable-search" — source: ADR-0009
- Forbidden: "Never implement a full `(tile, depth)`-keyed weighted Dijkstra under the current uniform-terrain ruleset" — source: ADR-0009
- Forbidden: "Never add `reachable()`/`move_path_cost()` as instance methods on `GridState` or `GameState`" — source: ADR-0009
- Guardrail: "`reachable()`: O(frontier size) per call; measured ~2.0 ms/call worst-case (24×24 near-full saturation), 25–340 µs typical (QQ-05, PASS)" — source: ADR-0009

---

## Acceptance Criteria

*From GDD `design/gdd/movement-system.md`, scoped to this story:*

- [ ] **GIVEN** a Scout (`move_cost` 1, `soft_move_cap` 4, `SOFT_MOVE_PENALTY` 2.0) with 5 AP on open terrain, **WHEN** `reachable` is computed, **THEN** exactly the empty passable tiles within a 4-step path are returned (tiles 1–4 at 1 AP each, in-cap); no 5-step-only tile is included (the 5th tile would cost `ceil(1×2.0)`=2 AP, exceeding the remaining 1 AP).
- [ ] **GIVEN** a friendly unit between the mover and an empty tile, **WHEN** `reachable` is computed, **THEN** the empty tile beyond is reachable (the mover paths through the friendly).
- [ ] **GIVEN** an enemy unit between the mover and a tile, **WHEN** `reachable` is computed, **THEN** the path is blocked there and tiles reachable only through it are excluded.
- [ ] **GIVEN** a friendly structure (HQ/outpost, mover's own owner) between the mover and a tile, **WHEN** `reachable` is computed, **THEN** it blocks (proving friendly pass-through applies to units only, never friendly structures).
- [ ] **GIVEN** a friendly-occupied tile, **WHEN** it is considered as a destination, **THEN** it is not in the returned set; an Impassable tile is likewise never a valid stop.
- [ ] **GIVEN** a unit adjacent to an enemy, **WHEN** it moves past/around the enemy, **THEN** it is not stopped or slowed (no zone of control in the VS).
- [ ] **GIVEN** a unit whose `move_cost` exceeds `current_ap`, **WHEN** `reachable` is computed, **THEN** it returns the empty set.
- [ ] **GIVEN** a Heavy already at/past its cap (`tiles_moved_this_turn` ≥ `soft_move_cap` 2) with `current_ap` 4, **WHEN** `reachable` is computed, **THEN** it returns the empty set — the next tile costs `ceil(3×2.0)`=6 AP > 4, even though the base `move_cost` 3 alone would be affordable.
- [ ] **GIVEN** a Scout (`move_cost` 1) at `SOFT_MOVE_PENALTY` 1.5 with `tiles_moved_this_turn` ≥ `soft_move_cap`, **WHEN** the next tile is costed, **THEN** the charge is `ceil(1×1.5)`=2 AP (not 1.5, not 1) and every reported `min_cost` stays an integer.
- [ ] **GIVEN** any tile returned by `reachable()`, **WHEN** its `is_surcharged` flag is inspected, **THEN** it is `true` iff `min_cost` includes at least one over-cap step (per-depth, not inferred from `min_cost` alone).
- [ ] **GIVEN** the same grid state and unit — including a mid-turn clone where `tiles_moved_this_turn` > 0 — **WHEN** `reachable` is computed twice, **THEN** the results are identical (determinism, headless-computable).

---

## Implementation Notes

*Derived from ADR-0009 Key Interfaces:*

- `class_name Movement extends RefCounted`, no instance state — mirrors `AP`'s static-utility shape.
- Inner class `ReachableTile extends RefCounted` with `tile: Vector2i`, `min_cost: int`, `is_surcharged: bool`, set via an explicit `_init(t, c, surcharged)`.
- `static func reachable(state: GameState, unit: UnitState) -> Array[ReachableTile]`: BFS-by-depth from `unit.position`. Allocate `visited_depth := PackedInt32Array()`, `.resize(w*h)`, `.fill(-1)` (fresh every call — no pooling; this is TR-movement-010's explicitly-decided, explicitly-reversible tradeoff). Seed `visited_depth[grid.index(start.x, start.y)] = 0` and `frontier = [start]`. Loop: increment `depth`, compute `cost_at_depth := _cost_for_depth(unit, depth)`, break the instant `cost_at_depth > state.current_ap(unit.owner)` (monotonic — nothing deeper is affordable). For each tile in the current frontier, expand neighbors via `_neighbors_in_fixed_order` (below) — skip if already visited (`visited_depth[idx] != -1`), skip if not `_is_traversable`; otherwise mark visited at this depth, add to `next_frontier`, and if `_is_valid_destination` append a `ReachableTile`.
- `_is_traversable(state, x, y, mover_owner) -> bool`: false if out of bounds or terrain is Impassable; if the tile is empty, true; if occupied, true only when the occupant `is UnitState` (via `is`, not `get_class()`) and `occupant.owner == mover_owner` — everything else (any `StructureState`, any enemy `UnitState`) is a hard blocker. This is the BFS *expansion* predicate.
- `_is_valid_destination(state, x, y) -> bool`: reuse `GridState.is_passable(x, y)` verbatim — it already means "terrain != Impassable and occupant is empty." This is the *destination-filter* predicate, applied only when deciding whether to emit a result, not when deciding whether to expand through the tile.
- `_neighbors_in_fixed_order(grid, pos) -> Array[Vector2i]`: iterate `[Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]` explicitly, filtering by `grid.in_bounds`. Do **not** call `GridState.neighbors()` — its iteration order is not part of its contract (control-manifest Engine API Constraints).
- `_cost_for_depth(unit, tiles_entered) -> int`: `c := unit.soft_move_cap`, `m := unit.tiles_moved_this_turn`, `t := tiles_entered`, `surcharge := UnitConfig.surcharge_for(unit.move_cost)` (Unit System Story 006 — do not reimplement `surcharge_for`, consume it), `base_tiles := max(0, min(t, c - m))`, `overcap_tiles := t - base_tiles`, return `base_tiles * unit.move_cost + overcap_tiles * surcharge`. This exact function is reused verbatim by `move_path_cost()` in Story 002 — the reachable-vs-billed agreement invariant depends on there being exactly one implementation.
- `_is_surcharged_at_depth(unit, depth) -> bool`: `return depth > max(0, unit.soft_move_cap - unit.tiles_moved_this_turn)`.
- `UnitConfig.surcharge_for()` already exists per Unit System Story 006 (`(move_cost * soft_move_penalty_x10 + 9) / 10`, integer ceil) — this story consumes it, does not redefine it.

---

## Out of Scope

- Story 002: `move()`/`MoveAction`/`apply_action` wiring, AP spend, grid occupancy mutation, `tiles_moved_this_turn` write.
- Story 003: dedicated integration tests for tie-break path-selection determinism and mid-turn board-change recompute (this story's own determinism AC only covers repeated `reachable()` calls returning the same *result set*, not path-identity across `move()` calls).
- Command & Action Interface epic: rendering the overlay from `is_surcharged`/`min_cost`.

---

## QA Test Cases

- **AC-1 (Scout soft-cap boundary)**: Given a Scout (move_cost 1, cap 4, penalty 2.0) with 5 AP on an open board / When `reachable()` runs / Then exactly the 4-step-reachable tiles are returned at cost 1 AP each; assert no tile at path-length 5 appears. Edge case: assert the 4th-tile cost is exactly 4 (not yet surcharged) and confirm no tile beyond is present even though a 5th tile's *base* cost (1) would fit the remaining 1 AP.
- **AC-2 (friendly pass-through)**: Given a friendly unit directly between the mover and an empty tile two steps away / When `reachable()` runs / Then the tile beyond is present in the result with `min_cost` reflecting both tiles entered.
- **AC-3 (enemy blocks)**: Given an enemy unit in the only path to a tile / When `reachable()` runs / Then that tile and everything reachable only through it are absent.
- **AC-4 (friendly structure blocks)**: Given a friendly-owned structure (not a unit) in the only path / When `reachable()` runs / Then it blocks identically to an enemy — the pass-through exception is unit-only. Edge case: same scenario with a friendly *unit* in the identical tile position must NOT block (regression pair with AC-2).
- **AC-5 (invalid destinations)**: Given a friendly-occupied tile and an Impassable tile both within traversal range / When `reachable()` runs / Then neither appears in the returned set, even if traversable-through.
- **AC-6 (no ZoC)**: Given a unit adjacent to an enemy with an open tile past it / When `reachable()` runs / Then the path around the enemy is unaffected — no cost penalty or block from mere adjacency.
- **AC-7 (unaffordable base cost)**: Given `unit.move_cost > current_ap` / When `reachable()` runs / Then the empty set is returned. Edge case: `current_ap == move_cost - 1` exactly.
- **AC-8 (surcharge-driven empty set)**: Given a Heavy at/past cap with 4 AP remaining (base move_cost 3 fits, surcharge 6 does not) / When `reachable()` runs / Then the empty set is returned — distinguishes this from AC-7's base-cost case.
- **AC-9 (fixed-point rounding)**: Given `SOFT_MOVE_PENALTY` 1.5 (not the VS default 2.0) and a unit at/past cap / When one further tile is costed / Then the charge is exactly 2 (integer), never 1 or a float remainder. Edge case: assert the type/value is a whole `int`, not a `float` compared for near-equality.
- **AC-10 (is_surcharged accuracy)**: Given a path that crosses the soft cap partway through / When the resulting `ReachableTile.is_surcharged` is inspected / Then true; given a wholly in-cap path / Then false. Edge case: a tile at exactly `depth == soft_move_cap` (the boundary tile itself, not yet over) must read `is_surcharged == false`.
- **AC-11 (determinism)**: Given an identical `GameState` (including a `clone()` with `tiles_moved_this_turn` > 0) / When `reachable()` is called twice / Then the returned tile sets (tile, min_cost, is_surcharged for every entry) are identical.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/movement/reachable_search_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Unit System Story 001 (`UnitTypeDef.move_cost`/`soft_move_cap`), Story 002 (`UnitState.position`/`owner`/`tiles_moved_this_turn`), Story 006 (`UnitConfig.surcharge_for()`); Grid & Terrain epic (`GridState.in_bounds`/`terrain_at`/`is_passable`/`occupant_at`/`index` — Complete).
- Unlocks: Story 002 (`move()` shares `_cost_for_depth`), Story 003 (determinism/no-cache integration tests exercise this search).
