# Story 002: Grid Mutation API — place/remove/move & Single-Occupant Invariant

> **Epic**: Grid & Terrain
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-25

## Context

**GDD**: `design/gdd/grid-terrain.md`
**Requirement**: `TR-grid-003`, `TR-grid-004`, `TR-grid-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Grid Representation & Map-Definition Format
**ADR Decision Summary**: `place`/`remove`/`move` are `GridState`'s only mutators, enforcing the single-occupant invariant against `occupancy: PackedInt32Array`. `occupancy` stores `entity_id` (int) or `-1`, never an `EntityState` reference, so a cloned `GameState` never aliases entity objects between the grid and `entities_by_id`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None beyond Story 001's — pure integer-array mutation, no post-cutoff API surface.

**Control Manifest Rules (this layer)**:
- Required: "`occupancy` must store `entity_id` (int) or `-1`, never an `EntityState` reference" — source: ADR-0005
- Required: "`place`/`remove`/`move` must be the grid's only mutators, called only from inside `apply_action` handlers" — source: ADR-0005
- Forbidden: "Never store an `EntityState` reference in grid occupancy" — source: ADR-0005
- Forbidden: "Never mutate `terrain`/`occupancy` directly outside `place`/`move`/`remove`" — source: ADR-0005
- Guardrail: `place`/`remove`/`move` are O(1) integer-array writes; no per-frame cost (turn-based sim, called only inside `apply_action` handlers) — source: ADR-0005 (TR-grid-007)

**Architectural discipline note**: the "called only from inside `apply_action` handlers" rule is enforced by the *caller side* (the Game State & Turn Manager epic's `apply_action` pipeline, ADR-0002), which does not yet exist when this story is implemented. This story only needs to implement `place`/`remove`/`move` as the grid's sole mutators — it does not implement or depend on `apply_action` itself. Do not add any guard/assertion inside `GridState` that checks call context; that discipline is a code-review/architecture concern, not a runtime check this story owns.

---

## Acceptance Criteria

*From GDD `design/gdd/grid-terrain.md`, scoped to this story:*

- [ ] **GIVEN** an empty passable tile, **WHEN** an entity is placed, **THEN** `occupant_at` returns that entity and `is_passable` for that tile becomes false.
- [ ] **GIVEN** an Occupied tile, **WHEN** a second `place` is attempted, **THEN** it is rejected and the original occupant is unchanged.
- [ ] **GIVEN** an Impassable tile, **WHEN** `place` or a movement destination targets it, **THEN** it is rejected / excluded from the passable set.
- [ ] **GIVEN** an Empty or Impassable tile, **WHEN** `remove` is called on it, **THEN** it is a no-op (idempotent) and returns failure/none.
- [ ] **GIVEN** an occupant moved from tile A to tile B, **WHEN** `move` completes, **THEN** it is atomic: A becomes empty and B holds the occupant in the same step, with no intermediate state observable.
- [ ] **GIVEN** two placements targeting the same Empty tile in the same resolution step, **WHEN** both are applied in deterministic call order, **THEN** the first succeeds and the second is rejected — no simultaneous co-occupancy is possible.

---

## Implementation Notes

*Derived from ADR-0005 Key Interfaces and Edge Cases:*

```gdscript
func place(entity_id: int, x: int, y: int) -> bool   # single-occupant invariant; false if occupied/impassable
func remove(x: int, y: int) -> bool                  # idempotent; false on empty/impassable
func move(from: Vector2i, to: Vector2i) -> bool      # atomic empty-old/occupy-new
```

- `place` fails (returns `false`, leaves state unchanged) if the target tile is already occupied, or if its terrain is `IMPASSABLE`. Callers are expected to check `is_passable`/`occupant_at` first, but `place` itself must not trust that — it re-validates.
- `remove` on an already-Empty or Impassable tile is a no-op returning `false` — never throws, never mutates.
- `move` must not leave the grid in a state where both tiles reflect the old occupant (no observable partial-move) — clear the source and set the destination as a single logical operation.
- No RNG, no floats, no engine-object references — pure integer array writes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: read query API (`in_bounds`, `terrain_at`, `is_cover`, `occupant_at`, `is_passable`, `neighbors`, `manhattan_distance`) — this story builds on top of it.
- Story 003: `build_grid()`'s use of `place` to seed HQs/starting entities at load.
- Story 004: Procedural Center terrain generation.

---

## QA Test Cases

*Test cases not yet defined — run `/qa-plan` to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/grid_mutation_api_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Story 003

---

## Completion Notes
**Completed**: 2026-07-25
**Criteria**: 6/6 passing (no deferred items)
**Deviations**: None. Advisory backlog (non-blocking): specialist W1 (add a comment to `test_remove_on_impassable_tile...` noting it can't isolate the terrain-branch from the empty-branch), W2 (doc-note the `remove`-on-impassable branch as defensive/currently-unreachable); qa gaps — strengthen 5 return-value-only rejection tests to also assert unchanged state, add remove-then-re-place & move-then-re-place-on-vacated-source round-trips, add `entity_id==0` placement test.
**Test Evidence**: Logic — `tests/unit/grid_mutation_api_test.gd` (22 mutation cases; 41 total suite; 0 failures; exit 0). Three code-review-added tests beyond the ACs: `test_place_on_cover_tile_succeeds`, `test_move_to_cover_destination_succeeds` (Cover-is-passable rule), `test_rectangular_grid_place_occupant_roundtrip` (non-square 10×6, catches index() width/height transposition).
**Code Review**: Complete — `/code-review` run 2026-07-25, verdict APPROVED WITH SUGGESTIONS (godot-gdscript-specialist confirmed `move` atomicity by trace + qa-tester); top-2 suggestions applied, remainder backlogged above.
