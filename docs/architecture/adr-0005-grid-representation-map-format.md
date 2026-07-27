# ADR-0005: Grid Representation & Map-Definition Format

## Status
Accepted

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core / Data Model |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `deprecated-apis.md`, `current-best-practices.md`; godot-specialist review of ADR-0001 (2026-07-23) confirming `duplicate_deep()` recursively duplicates packed arrays |
| **Post-Cutoff APIs Used** | None. `PackedByteArray`/`PackedInt32Array`, `RandomNumberGenerator`, `Resource` are all stable pre-cutoff. |
| **Verification Required** | None. The one deep-copy concern (packed-array fields survive `duplicate_deep()`) was already confirmed in the ADR-0001 specialist review ("all nested arrays, dictionaries, and packed arrays are duplicated recursively"). The isometric `TileMapLayer` rendering seam is **out of scope here** — owned by ADR-0013 (Board Renderer). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GridState is a `Resource` field of `GameState`), ADR-0003 (integer-only storage; seeded RNG for gen; flat-array iteration) |
| **Enables** | ADR-0009 (Movement — `neighbors`/`is_passable`/`occupant_at`), ADR-0010 (Combat — `is_cover`/adjacency), ADR-0007 (structures placed via `place`), ADR-0013 (Board Renderer reads GridState to render) |
| **Blocks** | Epic "Foundation: Game State Core" — the spatial substrate every gameplay verb queries |
| **Ordering Note** | Foundation-layer. Movement, Combat, and Base & Production all query this API; their ADRs depend on the signatures pinned here |

## Context

### Problem Statement
ADR-0001 declared `GameState.grid: GridState` but stubbed `GridState`. This ADR defines the grid's
data model, its query/mutation API implementation, the map-definition asset format, and the load-time
validation — everything the grid-terrain GDD specifies as behavior, given a concrete representation.
It is the spatial substrate every gameplay verb is expressed in coordinates against, so its storage
layout and API shape are load-bearing for Movement search, Combat targeting, Base & Production
placement, and AI positional scoring. The isometric rendering of this grid is a *separate* concern
(ADR-0013); here the grid is pure logical-space data.

### Constraints
- Conform to registered stances: `game_state_base_class` (GridState is a `Resource`),
  `float_in_state` (integer storage), `nondeterministic_iteration_order` (flat-array indexing),
  `randomness` (seeded `RandomNumberGenerator` for gen only).
- Must `duplicate_deep()` cleanly as part of `GameState.clone()` (ADR-0001) — no field may alias
  another part of the state after a clone.
- Dimensions 8×8–24×24 (engine), VS pinned 14×16; per-map data, not compile-time constants (TR-grid-001, -011).
- Render-decoupled: every query works headless with no `TileMapLayer` present (TR-grid-005).

### Requirements
- O(1) queries except `neighbors` (O(4)); integer arithmetic only (TR-grid-007).
- Terrain `{Plain, Cover, Impassable}` static post-load; occupancy separate and mutable (TR-grid-002, -003).
- Single-occupant-per-tile invariant, enforced in `place`/`move` (TR-grid-003).
- Deterministic seeded procedural generation, byte-identical per seed+config (TR-grid-009).
- Load-time HQ-to-HQ reachability validator; Authored → reject, Procedural → self-correct (TR-grid-010).
- Map definition serializable/loadable standalone (TR-grid-013).
- Reject invalid configs (dims out of 8–24; unreachable HQs; over-dense) deterministically (TR-grid-012).

## Decision

**`GridState extends Resource`** and stores the board as two **flat packed arrays** plus dimensions:

- `width: int`, `height: int` — per-map, from the map definition.
- `terrain: PackedByteArray` — one byte per tile, value = `Terrain` enum `{PLAIN=0, COVER=1, IMPASSABLE=2}`; **static after load**.
- `occupancy: PackedInt32Array` — one int per tile, value = **`entity_id` or `-1` (empty)**; mutable.
- Index into both: `index(x, y) = y * width + x` (TR-grid, ADR-0003 Rule 3).

**Occupancy stores `entity_id` (int), never an `EntityState` reference.** The `EntityState` objects
live in exactly one place — `GameState.entities_by_id` (ADR-0001). `Grid.occupant_at(x,y)` returns
the id; `GameState.entity_at(tile)` resolves id→`EntityState`. This is a **`clone()`-correctness
requirement**, not a style choice: if the grid held `EntityState` references *and* `entities_by_id`
also held them, `duplicate_deep()` would deep-copy the same unit into two distinct objects, silently
breaking the invariant that a tile's occupant *is* the object in `entities_by_id`. Storing ids keeps
a single source of entity objects, so the clone stays internally consistent.

**Packed arrays are the storage** because they are contiguous, integer-only, O(1)-indexed, and
`duplicate_deep()` copies them recursively (confirmed, ADR-0001 review) — so a cloned `GridState` is
a fully independent board with no aliasing back to the original.

**The map definition is a `MapDefinition extends Resource`** (`.tres`), loadable standalone:
dimensions, `mode` (`AUTHORED`/`PROCEDURAL`), `authored_terrain: PackedByteArray` (Authored) or the
proc params (`proc_seed`, `proc_band_width`, `proc_density_x100`, `proc_feature_mix_x100`,
`proc_symmetric`), and `hq_tiles`/`deploy_tiles`. (Fractional proc params are **scaled integers** per
ADR-0003 Rule 2: `proc_density_x100 = 30` for 0.30.) `build_grid(map_def) -> GridState` is the sole
constructor; building the same definition twice yields identical grids.

**`build_grid` pipeline:**
```
build_grid(map_def):
    1. validate dims in [8,24]²             else reject (TR-grid-012)
    2. lay terrain:
         AUTHORED    → copy authored_terrain
         PROCEDURAL  → generate_procedural(map_def)   # seeded, ADR-0003 Rule 1
    3. validate HQ-to-HQ reachability (BFS flood-fill over passable tiles):
         AUTHORED    → fail ⇒ reject at load
         PROCEDURAL  → handled inside generate_procedural's self-correction
    4. init occupancy to all -1; place HQs/starting entities (via GameState setup)
    5. return GridState
```

**`generate_procedural` (seeded, deterministic):** consume a dedicated `RandomNumberGenerator` seeded
with `proc_seed` (ADR-0003 Rule 1); place features only in a central band of `proc_band_width`
perpendicular to the HQ-to-HQ axis, excluding HQ/deploy tiles; `proc_density_x100` sets feature
fraction, `proc_feature_mix_x100` the Cover:Impassable split; if `proc_symmetric`, mirror across
board center. Then the **reachability self-correction**: run the BFS validator; on failure, remove
Impassable features from the band in a **fixed seed-stable order** (thinning) and re-test, repeating
until reachable — and if even a fully-thinned band can't connect, **clamp density to the max that
stays connected and log the clamp** (TR-grid-012). No re-roll: the correction is a pure function of
the failed layout, so seed+config always yields the same corrected map.

**Reachability validator = BFS flood-fill** over passable tiles from one HQ via `neighbors()`;
reachable iff the other HQ is visited. Pure, headless, deterministic.

### Architecture Diagram

```
  MapDefinition (Resource, .tres)  ──build_grid()──▶  GridState (Resource, field of GameState)
    dims · mode · authored_terrain                     width,height:int
        or proc params (scaled ints)                   terrain:  PackedByteArray  (enum, static)
    hq_tiles · deploy_tiles                             occupancy:PackedInt32Array (entity_id | -1)
                                                        index(x,y)=y*width+x
   generate_procedural (PROCEDURAL mode):                     │
     seeded RNG (ADR-0003) → band placement →                │ query/mutation API
     symmetric mirror → BFS reachability →                    ▼
     deterministic thin-on-fail + density clamp        Movement / Combat / Base&Prod / AI
                                                        (occupant_at returns entity_id;
                                                         GameState.entity_at resolves → EntityState)
```

### Key Interfaces

```gdscript
class_name GridState extends Resource
enum Terrain { PLAIN = 0, COVER = 1, IMPASSABLE = 2 }
@export var width: int
@export var height: int
@export var terrain: PackedByteArray       # value = Terrain enum; static after load
@export var occupancy: PackedInt32Array    # value = entity_id, or -1 for empty; mutable

func index(x: int, y: int) -> int:         return y * width + x
func in_bounds(x: int, y: int) -> bool:    return x >= 0 and x < width and y >= 0 and y < height
func terrain_at(x: int, y: int) -> int             # Terrain enum; IMPASSABLE-sentinel if OOB
func is_cover(x: int, y: int) -> bool
func is_passable(x: int, y: int) -> bool           # terrain != IMPASSABLE and occupant is empty
func occupant_at(x: int, y: int) -> int            # entity_id, or -1; GameState.entity_at resolves it
func neighbors(x: int, y: int) -> Array[Vector2i]  # 4-dir, in-bounds filtered, O(4)
func manhattan_distance(a: Vector2i, b: Vector2i) -> int
func place(entity_id: int, x: int, y: int) -> bool   # single-occupant invariant; false if occupied/impassable
func remove(x: int, y: int) -> bool                  # idempotent; false on empty/impassable
func move(from: Vector2i, to: Vector2i) -> bool      # atomic empty-old/occupy-new
# (place/remove/move are called only from inside apply_action handlers — direct_game_state_field_write stance)

class_name MapDefinition extends Resource
enum Mode { AUTHORED, PROCEDURAL }
@export var width: int
@export var height: int
@export var mode: int                       # Mode
@export var authored_terrain: PackedByteArray   # used iff AUTHORED
@export var proc_seed: int
@export var proc_band_width: int
@export var proc_density_x100: int          # scaled int (30 = 0.30)
@export var proc_feature_mix_x100: int      # scaled int (70 = 0.70 Cover share)
@export var proc_symmetric: bool = true
@export var hq_tiles: Array[Vector2i]
@export var deploy_tiles: Array[Vector2i]

static func build_grid(map_def: MapDefinition) -> GridState   # the pipeline above; sole constructor
```

## Alternatives Considered

### Alternative 1 (storage): Flat packed arrays indexed y*W+x — CHOSEN
- **Pros**: O(1) index; integer-only; deterministic linear iteration (ADR-0003 Rule 3); `duplicate_deep()`
  copies packed arrays recursively so a clone is fully independent; contiguous/cache-friendly for the
  AI's read-heavy scoring.
- **Cons**: Two parallel arrays to keep index-consistent; a raw `PackedByteArray` is less
  self-documenting than a `Tile` object (mitigated by the typed query API wrapping it).
- **Rejection Reason**: n/a (chosen).

### Alternative 2 (storage): Array of per-tile `Tile` objects
- **Description**: `Array[Tile]` where each `Tile` is a small object holding terrain + occupant.
- **Pros**: Self-documenting; one object per tile.
- **Cons**: Object-per-tile allocation overhead (224 objects on a 14×16, more on 24×24); every clone
  deep-copies all of them; and a `Tile` holding an occupant *reference* reintroduces the clone-aliasing
  bug the id-based occupancy avoids.
- **Rejection Reason**: Heavier to allocate and clone for zero gain over typed accessors on packed arrays.

### Alternative 3 (storage): `Dictionary` keyed by `Vector2i`
- **Description**: `{Vector2i: TileData}`.
- **Pros**: Sparse-friendly; natural `Vector2i` keys.
- **Cons**: Hash lookups instead of O(1) index; `Vector2i` key allocation on every access in hot
  loops; and iteration order is hash/insertion-based — exactly what `nondeterministic_iteration_order`
  forbids.
- **Rejection Reason**: Violates the determinism stance and is slower in the AI's hot query path; the
  board is dense (every tile exists), so sparsity buys nothing.

### Alternative 4 (occupancy): Store `EntityState` reference in occupancy
- **Description**: `occupancy` holds `EntityState` refs; `occupant_at` returns the object directly.
- **Pros**: No second lookup to resolve an occupant.
- **Cons**: Under `clone()`/`duplicate_deep()`, the same `EntityState` is referenced from both the grid
  and `entities_by_id`, so it is deep-copied into **two divergent objects** — the tile's "occupant" is
  no longer the same object as the one in `entities_by_id`. A silent, severe aliasing bug in the
  project's most safety-critical operation.
- **Rejection Reason**: Breaks clone integrity. Storing `entity_id` keeps a single source of entity objects.

### Alternative 5 (map format): JSON/text map files + custom parser
- **Description**: Maps as external JSON/text parsed at load.
- **Pros**: Engine-agnostic, git-diff-friendly.
- **Cons**: Needs a hand-written parser + validation layer; loses typed fields and inspector editing
  that `.tres` gives free; the future map-editor would have to emit and re-parse text.
- **Rejection Reason**: `MapDefinition` as a `Resource` gets typed fields, inspector authoring, and
  standalone loading for free; JSON can be an *export* format later if diffing matters.

## Consequences

### Positive
- O(1) integer queries with a clone-safe representation — the grid adds no aliasing risk to `clone()`.
- Deterministic by construction (flat iteration, seeded gen, integer storage) — conforms to ADR-0003 with no extra work.
- `MapDefinition` `.tres` files are the authoring format *and* the future map-editor's output; standalone-loadable for tests.
- Grid knows only `entity_id`s, not entity objects — clean layering (Grid never depends on Unit/Structure types).

### Negative
- Two parallel packed arrays must stay index-consistent (encapsulated behind the typed API, so callers never touch raw arrays).
- `occupant_at` returning an id means callers wanting the object go through `GameState.entity_at` — one extra hop (trivial, and it's the correct layering).
- Procedural generation's self-correction/thinning is non-trivial code to get deterministic; covered by tests.

### Risks
- **A caller mutating `terrain`/`occupancy` directly** would bypass the invariant + determinism guarantees.
  Mitigation: `place`/`move`/`remove` are the only mutators and are invoked only inside `apply_action`
  handlers (`direct_game_state_field_write` forbidden stance); raw arrays are private-by-convention behind the API.
- **Procedural gen nondeterminism** if any global RNG slips in. Mitigation: `global_rng` forbidden
  stance + the seeded-instance-only rule; the byte-identical-per-seed AC guards it.
- **Density clamp edge** (a config that can't connect even fully thinned). Mitigation: the clamp-and-log
  path has its own AC (TR-grid-012) — never emit an unplayable map.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| grid-terrain.md | TR-grid-001: fixed 2D grid, integer (x,y), dims 8–24 | `width`/`height` + `index(x,y)=y*width+x`; dims validated at build |
| grid-terrain.md | TR-grid-002: one terrain type/tile, static post-load | `terrain: PackedByteArray` of the `Terrain` enum, never mutated after build |
| grid-terrain.md | TR-grid-003: occupancy separate, single-occupant | `occupancy: PackedInt32Array`; `place`/`move` enforce the invariant |
| grid-terrain.md | TR-grid-004/007: deterministic O(1) render-decoupled API | Typed methods on packed arrays; integer arithmetic; no render dependency |
| grid-terrain.md | TR-grid-009: seeded procedural gen, byte-identical | `generate_procedural` with `proc_seed` via the sanctioned RNG |
| grid-terrain.md | TR-grid-010: load-time HQ-reachability validator | BFS flood-fill; Authored reject / Procedural self-correct |
| grid-terrain.md | TR-grid-011: Authored vs Procedural modes, band params | `MapDefinition.mode` + proc params (scaled ints) |
| grid-terrain.md | TR-grid-012: reject/guard invalid configs deterministically | dim check + reachability + density clamp-and-log |
| grid-terrain.md | TR-grid-013: map definition serializable/standalone | `MapDefinition extends Resource` (`.tres`), loadable independently |
| grid-terrain.md | TR-grid-005/006: grid decoupled + owned by Game State | `GridState` is a `Resource` field of `GameState` (ADR-0001) |

## Performance Implications
- **CPU**: O(1) integer index for every query; `neighbors` O(4); BFS validator O(W·H) once at load.
  Contiguous packed arrays are cache-friendly for the AI's read-heavy scoring passes.
- **Memory**: `terrain` = W·H bytes; `occupancy` = W·H × 4 bytes. On 24×24 (max): 576 B + 2.3 KB per
  `GridState` — cheap even when cloned many times in an AI turn.
- **Load Time**: Procedural gen + reachability runs once at map load; negligible for 8–24² boards.
- **Network**: N/A.

## Migration Plan
N/A — greenfield.

## Validation Criteria
- **Query correctness** (GDD ACs): `in_bounds`, `neighbors` (2 at corner, 4 interior, never OOB),
  `manhattan_distance`, `terrain_at`/`is_cover`, single-occupant `place` rejection, Impassable rejection.
- **Determinism**: building the same `MapDefinition` twice yields byte-identical `terrain` + `occupancy`.
- **Seeded gen**: a Procedural map with fixed `proc_seed`+config generates byte-identically twice; with
  `proc_symmetric` the layout is mirror-symmetric and both HQs remain reachable.
- **Reachability**: an Authored map walling off an HQ is rejected at load; a Procedural config that
  would wall off HQs clamps density and still connects them.
- **Clone integrity** (with ADR-0001): after `GameState.clone()`, mutating the clone's `occupancy`
  leaves the original grid unchanged; an occupant id in the clone's grid resolves to the clone's
  `entities_by_id`, not the original's.
- **Headless**: all queries function with no `TileMapLayer` / rendering node present.

## Related Decisions
- ADR-0001: State model (GridState is a `Resource` field of `GameState`; the id-based occupancy keeps `clone()` sound)
- ADR-0003: Determinism (integer storage, flat iteration, seeded gen sanctioned here)
- ADR-0009: Movement (consumes `neighbors`/`is_passable`/`occupant_at`)
- ADR-0010: Combat (consumes `is_cover`/adjacency)
- ADR-0007: Data-driven entity/stat schema (structures placed via `place`; entity ids resolved via `entities_by_id`)
- ADR-0013: Isometric board rendering (Board Renderer reads this `GridState` to render — the view seam, out of scope here)
- `docs/architecture/change-impact-2026-07-23-isometric-projection.md` (the projection concerns ADR-0013 absorbs)
