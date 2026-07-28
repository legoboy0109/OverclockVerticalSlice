# Story 003: MapDefinition & Authored Build Pipeline

> **Epic**: Grid & Terrain
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/grid-terrain.md`
**Requirement**: `TR-grid-001`, `TR-grid-005`, `TR-grid-010` (Authored half), `TR-grid-011` (Authored mode), `TR-grid-012`, `TR-grid-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Grid Representation & Map-Definition Format
**ADR Decision Summary**: `MapDefinition extends Resource` (`.tres`) is the standalone-loadable map-authoring format. `build_grid(map_def) -> GridState` is the sole grid constructor, running a fixed pipeline: validate dims → lay terrain → validate HQ-to-HQ reachability (BFS) → init occupancy + place entities → return `GridState`. Authored maps that fail reachability are rejected at load (Procedural's self-correction is Story 004's scope).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `Resource` `.tres` loading/authoring is stable pre-cutoff. No post-cutoff verification needed.

**Control Manifest Rules (this layer)**:
- Required: "`MapDefinition` must extend `Resource` (`.tres`), loadable standalone, with a `mode` field (`AUTHORED`/`PROCEDURAL`)" — source: ADR-0005
- Required: "`build_grid(map_def) -> GridState` must be the sole grid constructor; the same definition must yield identical grids on every build" — source: ADR-0005
- Required: "`build_grid` must run in order: validate dims in [8,24]² → lay terrain → validate HQ-to-HQ reachability → init occupancy + place entities → return `GridState`" — source: ADR-0005
- Required: "Authored maps failing HQ-to-HQ reachability must be rejected at load; procedural maps must self-correct via seed-stable-order thinning (no re-roll), clamping density and logging if still unconnectable" — source: ADR-0005 *(this story implements only the Authored-reject half; Procedural self-correction is Story 004)*
- Required: "The reachability validator must be a pure, headless, deterministic BFS flood-fill over passable tiles" — source: ADR-0005
- Forbidden: "Never use JSON/text map files with a custom parser" — source: ADR-0005
- Guardrail: "BFS reachability validator O(W·H), run once at load" — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/grid-terrain.md`, scoped to this story:*

- [ ] **GIVEN** the same map definition, **WHEN** the grid is built twice, **THEN** both instances are identical (occupancy + terrain byte-for-byte).
- [ ] **GIVEN** a map that walls off one HQ from the other, **WHEN** the map is loaded, **THEN** load-time validation rejects it (HQs must be mutually reachable).
- [ ] **GIVEN** a map definition with `GRID_WIDTH` or `GRID_HEIGHT` outside `[8, 24]`, **WHEN** `build_grid` is called, **THEN** the map is rejected at load.
- [ ] **GIVEN** a headless test run with no rendering node, **WHEN** `build_grid` is called on an Authored `MapDefinition`, **THEN** it succeeds and the resulting `GridState` answers all Story 001/002 queries correctly (render-decoupled, extends the Story 001 headless AC to the full load pipeline).

---

## Implementation Notes

*Derived from ADR-0005 Decision and Key Interfaces:*

```gdscript
class_name MapDefinition extends Resource
enum Mode { AUTHORED, PROCEDURAL }
@export var width: int
@export var height: int
@export var mode: int                       # Mode
@export var authored_terrain: PackedByteArray   # used iff AUTHORED
@export var hq_tiles: Array[Vector2i]
@export var deploy_tiles: Array[Vector2i]
# proc_* fields (proc_seed, proc_band_width, proc_density_x100, proc_feature_mix_x100,
# proc_symmetric) are declared on MapDefinition here but only consumed starting Story 004.

static func build_grid(map_def: MapDefinition) -> GridState
```

**`build_grid` pipeline (this story implements the AUTHORED branch only):**
```
build_grid(map_def):
    1. validate dims in [8,24]²             else reject (TR-grid-012)
    2. lay terrain:
         AUTHORED    → copy authored_terrain
         PROCEDURAL  → Story 004
    3. validate HQ-to-HQ reachability (BFS flood-fill over passable tiles):
         AUTHORED    → fail ⇒ reject at load
         PROCEDURAL  → Story 004
    4. init occupancy to all -1; place HQs/starting entities (via Story 002's place())
    5. return GridState
```

- The BFS reachability validator walks from one HQ tile via `neighbors()` over tiles where `is_passable` would hold if empty (i.e. terrain ≠ Impassable); reachable iff the other HQ tile is visited. Implement it as a standalone pure function so Story 004 can reuse it unchanged for the Procedural self-correction loop.
- "Reject at load" means `build_grid` returns a failure signal (null / `Result`-style — pick whatever this codebase's established failure convention is once `ActionResult`-style patterns exist; until then, a `GridState` return of `null` plus a logged reason is acceptable) rather than raising an engine exception.
- Determinism: building the same `MapDefinition` twice must produce byte-identical `terrain` and `occupancy` — no per-call incidental state (e.g. no reliance on dictionary iteration order, no RNG in the Authored path at all).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `generate_procedural`, `proc_*` param consumption, symmetric mirroring, thinning self-correction, density clamp-and-log.

---

## QA Test Cases

*Test cases not yet defined — run `/qa-plan` to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/grid_build_authored_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002 must be DONE
- Unlocks: Story 004

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 4/4 passing (no deferred items)
**Deviations**: None. Advisory backlog (non-blocking):
- **W2 (carry into GameState-wiring story)**: `build_grid` places HQs with placeholder entity ids `0`/`1`; a future `GameState.next_entity_id` allocator will likely start at 0 and collide. Resolution: move HQ placement out of `build_grid` into `GameState.start_match()` (which passes real ids), per ADR-0005 step 4's "place HQs/starting entities (via GameState setup)" wording. Add a `# TODO` near map_definition.gd's placement when that story starts.
- **I2**: the manual terrain-copy loop could be `authored_terrain.duplicate()` (style/perf nit).
- **qa gaps**: HQs-adjacent BFS early-exit test; Cover-terrain-copy-fidelity test; AC1 could also assert width/height equality across builds.
**Test Evidence**: Logic — `tests/unit/grid_build_authored_test.gd` (18 build cases; 59 total suite; 0 failures; exit 0). Code-review-added beyond ACs: distinct-HQ reject (a real logic hardening added to `build_grid`), reachable-only-through-Cover (proves BFS treats Cover as passable), reachable-via-narrow-gap (proves BFS traverses obstacles), inclusive-boundary (8/24) success.
**Code Review**: Complete — `/code-review` run 2026-07-25, APPROVED WITH SUGGESTIONS (godot-gdscript-specialist confirmed pipeline/BFS/determinism by trace + qa-tester surfaced the distinct-HQ gap). Top set (1-4) applied, remainder backlogged above.
