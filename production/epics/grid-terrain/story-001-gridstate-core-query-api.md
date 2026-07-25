# Story 001: GridState Core Data Model & Read Query API

> **Epic**: Grid & Terrain
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/grid-terrain.md`
**Requirement**: `TR-grid-001`, `TR-grid-002`, `TR-grid-004`, `TR-grid-005`, `TR-grid-006`, `TR-grid-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Grid Representation & Map-Definition Format
**ADR Decision Summary**: `GridState extends Resource`, storing the board as two flat packed arrays (`terrain: PackedByteArray`, `occupancy: PackedInt32Array`) plus `width`/`height`, indexed `y*width+x`. Exposes a typed, O(1) (O(4) for `neighbors`) read query API. Terrain is static after load; occupancy is the only mutable field (mutation itself is Story 002's scope).

**Secondary ADRs**:
- ADR-0001 (State Model Ownership & Lifecycle): `GridState` must be a plain `Resource`, never a `Node`, with no dependency on frame timing or `TileMapLayer` — this is what makes it decoupled from render and safe to hold as a field on `GameState`.
- ADR-0003 (Deterministic Simulation & RNG Isolation): all storage and arithmetic must be pure integers; spatial iteration uses the flat index `y*GRID_WIDTH+x`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `PackedByteArray`/`PackedInt32Array` are stable pre-cutoff APIs (per ADR-0005 Engine Compatibility) — no post-cutoff verification needed for this story. `duplicate_deep()` clone correctness (Godot 4.5, MEDIUM risk under ADR-0001) is **not** this story's concern — it is exercised when `GridState` is nested inside `GameState.clone()`, owned by the Game State & Turn Manager epic. This story only needs every field to carry `@export` (storage usage) so it is clone-ready when that epic wires it in.

**Control Manifest Rules (this layer)**:
- Required: "`GridState` must extend `Resource`, storing the board as two flat packed arrays (`terrain: PackedByteArray`, `occupancy: PackedInt32Array`) plus `width`/`height`" — source: ADR-0005
- Required: "Index into both grid arrays via `index(x, y) = y * width + x`" — source: ADR-0005
- Required: "`terrain` must be static after load; `occupancy` is the only mutable part of grid data" — source: ADR-0005
- Required: "Every field on `GameState`/`PlayerState`/`EntityState` must carry `@export` (storage usage) or it is silently excluded from `duplicate_deep()`" — source: ADR-0001, ADR-0007 (applies here by extension: `GridState` fields must be `@export`-flagged for future clone-readiness)
- Forbidden: "Never store the grid as an Array of per-tile `Tile` objects" — source: ADR-0005
- Forbidden: "Never store the grid as a `Dictionary` keyed by `Vector2i`" — source: ADR-0005
- Guardrail: "Grid queries: O(1) integer index; `neighbors` O(4)" — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/grid-terrain.md`, scoped to this story:*

- [ ] **GIVEN** an 8×8 grid, **WHEN** `in_bounds` is queried for `(0,0)` and `(7,7)`, **THEN** both return true; `(−1,0)` and `(8,0)` return false.
- [ ] **GIVEN** a tile authored as Cover, **WHEN** `terrain_at`/`is_cover` is queried, **THEN** it returns Cover / true — identically on every run (determinism).
- [ ] **GIVEN** an interior tile not on an edge, **WHEN** `neighbors` is requested, **THEN** exactly the 4 orthogonal in-bounds tiles are returned; a corner tile returns exactly 2, and no result is ever out of bounds.
- [ ] **GIVEN** tiles `(0,0)` and `(2,3)`, **WHEN** `manhattan_distance` is computed, **THEN** it returns 5; adjacent tiles return 1.
- [ ] **GIVEN** a headless test run with no rendering node, **WHEN** a `GridState` is constructed directly and its read queries are called, **THEN** all queries function correctly (render-decoupled). *(Mutation-side headlessness is verified in Story 002.)*
- [ ] **GIVEN** an out-of-bounds coordinate, **WHEN** any query is called, **THEN** `in_bounds` returns false, `terrain_at`/`occupant_at` return a sentinel (not a crash), and `neighbors` never includes it.

---

## Implementation Notes

*Derived from ADR-0005 Key Interfaces:*

```gdscript
class_name GridState extends Resource
enum Terrain { PLAIN = 0, COVER = 1, IMPASSABLE = 2 }
@export var width: int
@export var height: int
@export var terrain: PackedByteArray       # value = Terrain enum; static after load
@export var occupancy: PackedInt32Array    # value = entity_id, or -1 for empty; mutable (Story 002)

func index(x: int, y: int) -> int:         return y * width + x
func in_bounds(x: int, y: int) -> bool:    return x >= 0 and x < width and y >= 0 and y < height
func terrain_at(x: int, y: int) -> int             # Terrain enum; IMPASSABLE-sentinel if OOB
func is_cover(x: int, y: int) -> bool
func is_passable(x: int, y: int) -> bool           # terrain != IMPASSABLE and occupant is empty
func occupant_at(x: int, y: int) -> int            # entity_id, or -1; -1 sentinel if OOB
func neighbors(x: int, y: int) -> Array[Vector2i]  # 4-dir, in-bounds filtered, O(4)
func manhattan_distance(a: Vector2i, b: Vector2i) -> int
```

For this story, construct `GridState` directly with `width`/`height`/`terrain`/`occupancy` set by hand in tests (no `MapDefinition`/`build_grid` yet — that is Story 003). `occupancy` can be manually initialized to all `-1` for read-API tests; wiring it into a real load pipeline is out of scope here.

Adjacency is strictly 4-directional (orthogonal); diagonals are never neighbors (GDD Detailed Rules #3).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `place`/`remove`/`move` mutators and the single-occupant invariant.
- Story 003: `MapDefinition`, `build_grid()`, dims validation, HQ-reachability BFS validator.
- Story 004: Procedural Center terrain generation.

---

## QA Test Cases

*Test cases not yet defined — run `/qa-plan` to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/grid_query_api_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002, Story 003

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 6/6 passing (no deferred items)
**Deviations**: None. Advisory backlog (non-blocking, not deviations): specialist W1 (add `terrain.size()==width*height` invariant guard before Story 003's loader lands), W2 (narrow `terrain_at() -> Terrain`); qa gaps G2 (manhattan symmetry/zero-distance), G4 (in-bounds-Impassable vs OOB-sentinel separation), G5 (`neighbors` N/E/S/W order untested — note ADR-0009 says the order is NOT a pinned contract, so either test it or soften the doc claim).
**Test Evidence**: Logic — `tests/unit/grid_query_api_test.gd` (16 grid cases; 19 total suite; 0 failures; exit 0). Two code-review-added tests beyond the ACs: `test_is_passable_cover_terrain_no_occupant_returns_true` (G3), `test_rectangular_14x16_grid_index_inbounds_neighbors` (G1).
**Code Review**: Complete — `/code-review` run 2026-07-25, verdict APPROVED WITH SUGGESTIONS (godot-gdscript-specialist + qa-tester); G1+G3 suggestions applied, remainder backlogged above.
