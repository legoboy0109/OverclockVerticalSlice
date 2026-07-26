# Story 003: Movement Determinism & No-Stale-Cache Guarantees

> **Epic**: Movement
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/movement-system.md`
**Requirement**: `TR-movement-007`, `TR-movement-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Reachable-search / pathfinding strategy
**Secondary ADRs**: ADR-0003 (deterministic simulation — pinned neighbor-expansion order, no engine RNG)
**ADR Decision Summary**: Determinism is not incidental — `Movement` deliberately does not rely on `GridState.neighbors()`'s unpinned iteration order, instead walking its own explicit N→E→S→W offset order at the BFS call site, so tie-break path selection is self-contained and reproducible. `reachable()` is recomputed fresh on every call with no cache of any kind, so a board change between two calls (e.g. a blocker destroyed in combat) is reflected immediately. Both properties are called out in the GDD as their own **Integration**-type acceptance criteria (`tests/integration/movement/`), distinct from the per-call correctness already covered by Stories 001–002 — this story is where those two properties get their own dedicated proof.

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: `GridState.neighbors()`'s iteration order is explicitly *not* pinned by ADR-0005's contract (control-manifest Engine API Constraints) — this story's tie-break test must exercise `Movement`'s own internal fixed order, not assume anything about `GridState.neighbors()`.

**Control Manifest Rules (this layer)**:
- Required: "The reachable-tile search must use plain BFS by depth... under the min-length ≡ min-cost property for uniform terrain" — source: ADR-0009
- Required: "`Movement` must NOT call `GridState.neighbors()` for BFS traversal (order unpinned); it must iterate its own explicit fixed offset order (N→E→S→W)" — source: ADR-0009
- Required: "`reachable()` must be recomputed fresh every invocation — no caching, fresh-per-call allocation" — source: ADR-0009
- Engine constraint: "`GridState.neighbors()`'s iteration order is not pinned by ADR-0005's contract — do not assume it is stable" — source: ADR-0009

---

## Acceptance Criteria

*From GDD `design/gdd/movement-system.md`, scoped to this story:*

- [ ] **GIVEN** a grid state with two or more equal-cost paths to the same destination tile T, **WHEN** `move(unit, T)` is executed twice from the identical starting state, **THEN** the identical tile sequence is chosen both times (tie-break path selection is deterministic — pins the "stable iteration order" rule for replay/animation/AI-clone parity).
- [ ] **GIVEN** a unit for which `reachable()` has been computed with a blocking enemy/structure in the way, **AND** that blocker is subsequently removed from the grid with no other state change, **WHEN** `reachable()` is computed again, **THEN** the newly-opened tiles are included — proving reachability is recomputed fresh from current state each time (no stale cache).

---

## Implementation Notes

*Derived from ADR-0009's Risks and Architecture Diagram sections:*

- **Tie-break test construction**: build a grid where at least two distinct 2-tile (or longer) paths reach the same destination at identical cost (e.g. a unit with an open tile directly to its north-then-east and another directly east-then-north). Call `move(unit, T)` from the identical starting `GameState` (or two independently-cloned copies of it) twice, and assert the *sequence of tiles entered* — not just the destination or the cost — is byte-identical both times. This is the direct behavioral proof of `_neighbors_in_fixed_order`'s N→E→S→W pin (Story 001) actually driving path selection, since nothing about *which* equal-cost path is chosen is exposed by `reachable()`'s own return shape (`{tile, min_cost, is_surcharged}` says nothing about the path taken to get there).
- **No-stale-cache test construction**: compute `reachable(state, unit)` once with a blocker (enemy unit or structure) positioned in the only route to some tile T; assert T is absent. Remove the blocker from the grid (e.g. via `GridState.remove()` or by simulating its destruction), with no other change to `state`. Compute `reachable(state, unit)` again on the *same* `state` object (not a fresh one) and assert T is now present. This guards specifically against a caching bug — memoizing on `(unit, state)` identity or similar — that the "recomputed fresh every call" rule exists to prevent.
- Both tests exercise the search from Story 001 and (for the tie-break case) the commit path from Story 002 — no new production code is expected from this story; it is a verification-only story unless the tie-break/no-cache proofs surface a latent bug in either, in which case the fix belongs to the story that owns the offending code (001 or 002), not here.
- Per the Testing Standards `tests/README.md` isolation rule, each test must construct its own grid/unit fixtures — do not depend on fixture state left over from another test in the same file or suite.

---

## Out of Scope

- Story 001/002: any new algorithm or billing logic — this story only adds tests proving properties those stories already implement.
- Command & Action Interface epic: any UI-visible replay/animation behavior that consumes path identity (this story only proves the underlying data is deterministic).

---

## QA Test Cases

- **AC-1 (tie-break determinism)**: Given a grid with two equal-length, equal-cost paths from a unit's position to the same destination T / When `move(unit, T)` is run twice from the identical starting `GameState` / Then the exact ordered tile sequence entered is identical both runs. Edge case: construct the two candidate paths so a naive `Dictionary`-keyed or insertion-order-dependent implementation would plausibly diverge (i.e. the two paths' first diverging step must sit at a point where N→E→S→W ordering is the only thing disambiguating them) — a scenario with only one possible equal-cost path proves nothing.
- **AC-2 (no stale cache)**: Given `reachable()` computed once with tile T unreachable due to a blocker / When the blocker is removed with no other change and `reachable()` is computed again on the same state / Then T (and any tile reachable only through the now-open route) appears in the second result but not the first. Edge case: confirm no other previously-reachable tile's `min_cost`/`is_surcharged` value changed as a side effect of the blocker removal — only the newly-opened region should differ.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/movement/movement_determinism_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`Movement.reachable()`), Story 002 (`Movement.move()`) — both must be implemented for this story's tests to have anything to exercise.
- Unlocks: None within Movement — closes the epic's determinism/no-cache TR-IDs. Downstream consumers (AI Opponent epic's clone-parity requirements, Command & Action Interface's replay/animation) rely on these guarantees but are not blocked by this story specifically (they depend on Stories 001–002 directly).
