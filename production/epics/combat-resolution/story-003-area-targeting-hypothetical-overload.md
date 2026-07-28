# Story 003: AREA Targeting, Ring Invariant & Hypothetical-Tile Overload

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-003` (AREA half), `TR-combat-004`, `TR-combat-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: AREA targeting (dormant infrastructure — no VS unit uses it) selects any enemy-occupied tile with `min_range ≤ manhattan_distance ≤ attack_range`; it **ignores line-of-fire** entirely and remains single-target. The schema invariant `min_range ≤ attack_range` is enforced (a violating unit yields an empty target set surfaced as a validation error, never a silent soft-lock). The **hypothetical-tile overload** `legal_targets_from(state, attacker, from_tile) -> Array[TargetResult]` evaluates the identical targeting rules (DIRECT or AREA, whichever the attacker uses) as if the attacker stood on `from_tile` — pure, moves nothing — and must equal the zero-arg `legal_targets()` form when `from_tile == attacker.position`. This overload is a **blocking** contract (not advisory like the AREA ring itself) — it backs the Command & Action Interface's after-move attack preview for every unit, DIRECT or AREA.

**Secondary ADRs**: ADR-0007 (Entity/Stat Schema — `min_range`/`attack_range`/`targeting_mode` fields, already present on `UnitTypeDef`), ADR-0011 (AI Opponent — `legal_targets_from` is also the dominant caller of this overload for lookahead, `reachable`-sized cost), ADR-0003 (Deterministic Simulation — the AREA ring scan is an order-sensitive iteration; its traversal order must be stable, Rule 3)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: Pure ring-scan/manhattan-distance arithmetic — no post-cutoff API surface. AREA ACs are infrastructure/forward-proofing per the GDD ("BLOCKING once an AREA unit ships, advisory while the VS roster is pure-DIRECT") — implement and test fully now regardless, since this epic's Definition of Done requires all ACs verified.

**Control Manifest Rules (this layer)**:
- Required: AREA targeting (dormant) must ignore line-of-fire and select any enemy tile with `min_range ≤ manhattan_distance ≤ attack_range`; enforce the `min_range ≤ attack_range` schema invariant (violation ⇒ empty target set as a validation error, never a silent soft-lock) — source: ADR-0010
- Required: `legal_targets(state, unit, from_tile)` must evaluate identical rules as if the unit stood on `from_tile`, purely, moving nothing (must equal the zero-arg form when `from_tile == unit.position`) — source: ADR-0010

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

- [ ] An AREA attacker (`min_range 2`, `attack_range 4`) with an enemy at distance 3 and a friendly directly between → the enemy **is** targetable (ignores LoF)
- [ ] The same attacker and an enemy at distance 1 (inside `min_range`) → not targetable (dead zone); at distance 5 (beyond max) → not targetable
- [ ] The same attacker (`min_range 2`, `attack_range 4`) and an enemy at **exactly distance 2** (`== min_range`) → targetable; and at **exactly distance 4** (`== attack_range`) → targetable — ring bounds are **inclusive** on both ends
- [ ] An AREA unit fixture with `min_range > attack_range` (an illegal schema state) → its legal-target set is empty, surfaced as a **validation/schema error**, not a silent soft-lock
- [ ] Two enemies in the ring, one declared → only that single target takes damage (single-target; this story only needs to prove `legal_targets` returns both as independently-targetable candidates — the "only one takes damage" half is Story 004's `attack()` concern)
- [ ] `legal_targets(unit, from_tile)` — for a DIRECT unit standing hypothetically on `from_tile` — returns the identical result `legal_targets(unit)` would return if the unit's `position` were actually `from_tile`; and when `from_tile == unit.position`, `legal_targets_from()` returns exactly what `legal_targets()` returns (zero-arg parity)
- [ ] `legal_targets_from()` never mutates `state` or the attacker's actual `position` field

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Extend `src/core/combat/combat.gd` with:
  ```gdscript
  static func legal_targets_from(state: GameState, attacker: EntityState, from_tile: Vector2i) -> Array[TargetResult]
  ```
  **Concrete refactor of the shipped Story 002 code** (do not re-derive from scratch): Story 002's `_walk_direction(state, attacker, direction)` currently reads its origin internally as `var origin: Vector2i = attacker.position`. Change its signature to take the origin explicitly — `_walk_direction(state, attacker, origin: Vector2i, direction: Vector2i) -> _WalkResult` — reading `origin` instead of `attacker.position`. Update both existing call sites (`legal_targets()` and `blocked_reason()`) to pass `attacker.position` explicitly. Then:
    - `legal_targets(state, attacker)` becomes a one-line delegation: `return legal_targets_from(state, attacker, attacker.position)`.
    - `legal_targets_from()` dispatches on `attacker.type.targeting_mode`: DIRECT → the 4-cardinal walk (Story 002's logic, now origin-parameterized) from `from_tile`; AREA → the ring scan below, also from `from_tile`.
  This guarantees the "identical rules as if it stood on `from_tile`" requirement by construction — one implementation, parameterized by origin, never two parallel copies.
- AREA scan: for `attacker.type.targeting_mode == UnitTypeDef.TargetingMode.AREA`, scan tiles in the bounding box `[from_tile − attack_range, from_tile + attack_range]²`, in **fixed row-major order** (`y` outer, `x` inner — matching `GridState.index(x,y) = y*width + x`'s own convention), selecting each enemy-occupied tile `t` where `min_range <= state.grid.manhattan_distance(from_tile, t) <= attack_range` (both bounds **inclusive** — the off-by-one guard the AC calls out). Row-major traversal — never `state.entities()` order or an unspecified nested-loop direction — keeps `legal_targets()`'s returned `Array[TargetResult]` ordering reproducible across identical calls and clones (ADR-0003 Rule 3, the same stable-order discipline Story 002's N→E→S→W DIRECT walk follows). This is a tile scan over the bounding box, not a walk — LoF/Impassable are never consulted (AREA "arcs over" intervening pieces and terrain, per GDD Rule 5).
- Schema invariant (`min_range ≤ attack_range`): expose it as a pure, directly-testable predicate rather than a bare `push_error()` (a `push_error` alone is untestable — a violating unit's ring is empty *by construction*, so an "is the result empty?" assertion can't tell a schema violation from a legitimately-empty ring). Add:
  ```gdscript
  static func has_valid_targeting_schema(entity: EntityState) -> bool:
      return entity.type.min_range <= entity.type.attack_range
  ```
  `legal_targets_from()`'s AREA branch checks this first: if it returns `false`, call `push_error("AREA unit has min_range > attack_range: <id>")` (developer visibility) **and** return an empty `Array[TargetResult]`. AC-4's test asserts **both** `Combat.has_valid_targeting_schema(bad_unit) == false` **and** `legal_targets(...)` empty — the predicate is what distinguishes a schema violation from AC-2's ordinary empty-ring case. No new `Action.Reason` enum member (no caller branches on it yet — consistent with the GDD's note), and no runtime error-capture harness needed. DIRECT units always satisfy the invariant (`min_range` defaults to 1 ≤ any `attack_range ≥ 1`), so the predicate is a no-op guard for the whole VS roster.
- `legal_targets_from` must route through the *same* per-profile branch `legal_targets` uses (DIRECT walk vs AREA scan) — it is not AREA-only. A DIRECT unit's hypothetical-tile query walks the 4 cardinals from `from_tile` exactly as Story 002 describes, just with a different origin.
- Purity: `legal_targets_from` must never write to `attacker.position`, `state.grid`, or any entity — it only *reads* `from_tile` as a local origin for the walk/scan math. This is straightforward if the refactor in the first bullet is done correctly (the origin is a plain local parameter, never assigned back to the entity).
- Test fixtures: reuse Story 002's structure/unit stub patterns. For the AREA fixtures, a `UnitState` whose `type` is a throwaway `UnitTypeDef.new()` instance (not one of the real `UnitTypes.*` registry consts, since no VS unit is AREA) with `targeting_mode = UnitTypeDef.TargetingMode.AREA`, `min_range = 2`, `attack_range = 4` set directly — this is a legitimate test-only construction (not a `load()` of a `.tres`, so it doesn't trip the "never `load()` a template outside the registry" forbidden pattern; it's a fresh `Resource.new()`, matching how `effective_attack_test.gd`-style tests already construct throwaway fixtures).
- **Performance**: the AREA ring scan is O(ring area) — bounded by `(2·attack_range + 1)²` tile checks, each O(1) (`manhattan_distance` + `occupant_at`). `legal_targets_from()` over a full reachable frontier is `reachable`-sized — that's the AI-lookahead-dominant cost already budgeted by ADR-0011 (QQ-06), not a new budget this story introduces. No per-frame path; no concern beyond what ADR-0011 accounts for.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: DIRECT profile, `BlockedReason` enum definition (this story only adds the `INSIDE_DEAD_ZONE`-producing logic; the enum member itself was reserved in Story 002)
- Story 004+: `attack()`, single-target damage application, AP

---

## QA Test Cases

- **AC-1 (AREA ignores LoF)**: Given an AREA attacker (`min_range 2`, `attack_range 4`) with an enemy at distance 3 and a friendly directly between attacker and target, When `legal_targets()` is queried, Then the enemy is present (unaffected by the intervening friendly).
  Edge cases: an Impassable tile between attacker and target instead of a friendly — same result, still targetable.

- **AC-2 (dead zone + beyond-max)**: Given the same attacker, an enemy at distance 1 (< min_range) and another at distance 5 (> attack_range), When `legal_targets()` is queried, Then neither is present.

- **AC-3 (inclusive ring boundaries)**: Given the same attacker, enemies at exactly distance 2 and exactly distance 4, When `legal_targets()` is queried, Then both are present — the off-by-one guard (distances 1 and 5 excluded, 2 and 4 included).

- **AC-4 (illegal schema invariant)**: Given a unit fixture with `min_range 5, attack_range 3` (min > max), When `legal_targets()` is queried against any enemy placement, Then the result is empty and a validation error is surfaced (not silently empty for an ordinary no-target reason).
  Edge cases: distinguish this from AC-2's "legitimately empty ring" case in the test comments/assertions so a future reader doesn't conflate the two.

- **AC-5 (hypothetical-tile parity)**: Given a DIRECT unit at its real position with a known `legal_targets()` result, When `legal_targets_from(unit, unit.position)` is called, Then it returns the identical result set.
  Edge cases: repeat for an AREA unit — parity must hold for both profiles.

- **AC-6 (hypothetical-tile actually hypothetical)**: Given a unit whose real position has no legal target, but a different candidate tile *would* yield one, When `legal_targets_from(unit, candidate_tile)` is called, Then the target from that hypothetical origin is returned, and the unit's actual `position` field is unchanged after the call.

- **AC-7 (purity/no mutation)**: Given any attacker/from_tile pair, When `legal_targets_from()` is called, Then no field on `state`, `state.grid`, or the attacker entity differs before vs. after the call.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/area_targeting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (refactors `legal_targets()`'s internals to route through a shared `from_tile`-parameterized implementation)
- Unlocks: Story 004 (attack validation), the Command & Action Interface epic's after-move attack preview (downstream, out of this epic)

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 7/7 passing (0 deferred) — all covered by `tests/unit/combat/area_targeting_test.gd` (19 test functions), full suite 296/296 green.
**Deviations**: None. The `_walk_direction()` origin-parameterization refactor left Stories 001/002 tests unchanged and green (48/48 across all three combat test files). Two `/code-review` gap tests were added before closing: `test_enemy_structure_inside_ring_is_legal_area_target` (mirrors Story 002's enemy-structure-as-DIRECT-target coverage for the AREA path) and `test_degenerate_ring_min_equals_max_only_exact_distance_targetable` (the `min_range == attack_range` single-radius boundary).
**Design note**: introduced one small new public predicate `has_valid_targeting_schema(entity) -> bool` beyond ADR-0010's Key Interfaces sketch — a deliberate, minimal testability seam (agreed at readiness review) so the `min_range ≤ attack_range` invariant (TR-combat-011) is assertable rather than only surfaced via an unobservable `push_error`.
**Test Evidence**: Logic — `tests/unit/combat/area_targeting_test.gd` (BLOCKING gate satisfied).
**Code Review**: Complete — `/code-review` run this session, verdict APPROVED (godot-gdscript-specialist CLEAN incl. hand-traced refactor + AREA scan + both AC-6 hypothetical cases; qa-tester TESTABLE; 0 required changes; both coverage gaps applied).
