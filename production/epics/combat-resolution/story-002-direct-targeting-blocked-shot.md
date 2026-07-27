# Story 002: DIRECT Targeting & Blocked-Shot Reasons

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-003` (DIRECT half), `TR-combat-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: DIRECT targeting walks tiles outward along each of the 4 cardinals up to `attack_range`; the **first occupied or Impassable tile stops the walk**; if that first blocker is an enemy within range, it is the sole legal target that direction (nearest-only, no pierce). `legal_targets(state, attacker) -> Array[TargetResult]` is a pure, side-effect-free query. The three blocked-shot reasons (`blocked-by-friendly`, `out-of-range`, `inside-dead-zone`) are exposed as a queryable `BlockedReason` enum via `blocked_reason()`.

**Secondary ADRs**: ADR-0005 (Grid Representation — `GridState.occupant_at()`/`neighbors()`/terrain query surface this story reads), ADR-0003 (stable iteration — the 4 cardinal directions must be walked in a fixed order)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: Pure tile-walk over `GridState` — not a raycast, not `PhysicsServer2D`. No post-cutoff API surface.

**Control Manifest Rules (this layer)**:
- Required: DIRECT targeting must walk tiles outward along each cardinal up to `attack_range`; the first occupied/Impassable tile stops the walk (nearest-only, no pierce) — source: ADR-0010
- Required: The three blocked-shot reasons must be exposed as a queryable `BlockedReason` enum — source: ADR-0010
- Forbidden: Never use the physics engine (`PhysicsServer2D` ray/shape queries, `Area2D`/`RayCast2D`, Jolt) for combat targeting, line-of-fire, or range — source: ADR-0010
- Forbidden: Never add `legal_targets`/`attack` as instance methods on `GameState` — re-accretes Core logic onto `GameState` — source: ADR-0009, ADR-0010

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

- [ ] A Sniper (range 3) with an enemy exactly 3 tiles away cardinally and nothing intervening → that enemy is a legal target
- [ ] A friendly unit or Impassable tile between attacker and enemy on the line → the enemy is **not** targetable (LoF blocked by any occupant or Impassable)
- [ ] Two enemies stacked on the same cardinal line in range → only the nearest is targetable (no pierce)
- [ ] An enemy on the line but beyond `attack_range` (Trooper range 2, enemy at 3, no closer blocker) → no target that direction
- [ ] An attempt to target a diagonal/non-cardinal direction → rejected (DIRECT recognizes only the 4 cardinals; DIRECT range is cardinal-line distance, not general manhattan)
- [ ] Blocked-by-friendly, out-of-range, and inside-dead-zone are three visually/programmatically distinct `BlockedReason` values, never one generic "blocked" (dead-zone itself is Story 003's AREA concern — this story's `BlockedReason` enum must still reserve the value so Story 003 doesn't need a schema change)

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Extend `src/core/combat/combat.gd` (created in Story 001) with:
  ```gdscript
  enum BlockedReason { NONE, BLOCKED_BY_FRIENDLY, OUT_OF_RANGE, INSIDE_DEAD_ZONE }

  class TargetResult extends RefCounted:
      var target_id: int
      var tile: Vector2i
      func _init(id: int, t: Vector2i) -> void: target_id = id; tile = t

  static func legal_targets(state: GameState, attacker: EntityState) -> Array[TargetResult]
  static func blocked_reason(state: GameState, attacker: EntityState, direction: Vector2i) -> BlockedReason
  ```
  `TargetResult` is a nested class inside `Combat` (control-manifest: inner classes are not auto-registered as global `class_name` symbols — external callers reference it as `Combat.TargetResult`, mirroring `Movement.ReachableTile`'s established precedent).
- DIRECT walk: for each of the 4 cardinal directions (fixed N→E→S→W enumeration order, matching `GridState.neighbors()`'s and Movement's established fixed-offset-order convention — never rely on `GridState.neighbors()`'s own iteration order, which ADR-0009 explicitly leaves unpinned), step outward tile-by-tile from `attacker.position` up to `attacker.type.attack_range` (read the max range off the attacker's `UnitTypeDef`/`StructureTypeDef` template). At each step:
  1. If the tile is Impassable (`state.grid.terrain_at(x,y) == GridState.Terrain.IMPASSABLE`) — stop the walk this direction, no target.
  2. Else if the tile is occupied (`state.grid.occupant_at(x,y) != GridState.EMPTY_OCCUPANT`) — this is the first blocker, whatever it is. **Ownership alone decides legality; occupant kind (unit vs. structure) never does:**
     - If the occupant is an **enemy** (`entity.owner != attacker.owner`) — whether a unit **or** a structure (HQ/outpost/Defensive Structure) — it is the (only) legal target this direction: append a `TargetResult` and stop. Enemy structures are valid targets (GDD Rule 3), and destroying an enemy HQ is the win condition Stories 005/008 depend on — never exempt a structure from being a target.
     - If the occupant is **friendly** (`entity.owner == attacker.owner`) — again whether a unit or a structure — it blocks the line with no target this direction (the *blocked-by-friendly* case, GDD Rule 4). A friendly structure blocking reads identically to a friendly unit blocking.
  3. Else (empty, passable tile) — continue to the next step outward.
  If the walk exhausts `attack_range` steps with no blocker found, no target that direction (out-of-range case — the tile walk simply ends).
- `blocked_reason(state, attacker, direction: Vector2i)` — `direction` is a **unit cardinal offset**, one of the four fixed vectors `Vector2i(0, -1)` (N), `Vector2i(1, 0)` (E), `Vector2i(0, 1)` (S), `Vector2i(-1, 0)` (W) — the same N→E→S→W offsets the DIRECT walk iterates, not an arbitrary target-tile coordinate. It re-runs the DIRECT walk in that one direction and reports why it stopped: `BLOCKED_BY_FRIENDLY` (first blocker was a friendly piece), `OUT_OF_RANGE` (walk exhausted `attack_range` steps with no blocker / no enemy found), or `NONE` (an enemy is targetable that direction). A caller passing a non-cardinal vector is a programming error — assert or return `NONE`; the Command interface only ever passes the four cardinals. (`INSIDE_DEAD_ZONE` is never returned by DIRECT — reserved for Story 003's AREA profile.) Compute it by re-running the same walk and reporting why it stopped, rather than maintaining a second parallel algorithm — a single source of truth for "why is this direction not targetable."
- Diagonal/non-cardinal rejection: `legal_targets`/`blocked_reason` only ever iterate the 4 cardinal offsets — there is no code path that could produce a diagonal result. The AC is satisfied by construction (test asserts that a target set query never contains a diagonal tile, and that directly probing a diagonal via `blocked_reason` — if the query shape accepts an arbitrary tile — reports it as never-targetable).
- `INSIDE_DEAD_ZONE` is reserved in this story's enum but never *produced* by DIRECT's own logic (DIRECT has no dead zone) — Story 003 (AREA) is the sole producer of that value. Do not implement any dead-zone logic here.
- Enemy-only: "enemy" means `occupant.owner != attacker.owner` — this already excludes the attacker's own HQ/units by construction; there is no separate "reject own-target" branch needed in `legal_targets` itself (Story 004's `validate()` re-checks this defensively at the `attack()` call site, but `legal_targets`'s own walk never returns a friendly as a target to begin with).
- Use `tests/helpers/stubs/structure_state_stub.gd`/`structure_stub.gd` (already exist) for structure-as-blocker fixtures (a structure sitting on the cardinal line). Real HQ/structure entities aren't needed yet — a stub occupying a grid tile is sufficient to exercise the "structure blocks the line" rule. Note the fixtures must also cover an **enemy** structure as a legal *target* (not just a friendly structure as a blocker), per the corrected step-2 walk rule above — a test where an enemy HQ stub on the cardinal line is returned in `legal_targets()`.
- **Performance**: `legal_targets()` is O(4 · `attack_range`) worst case — four cardinal walks, each ≤ `attack_range` steps, each step O(1) grid/entity lookups; `blocked_reason()` is O(`attack_range`) (one direction). No nested iteration beyond that, no allocation beyond the small `Array[TargetResult]` result (≤ 4 entries). This is the AI-lookahead hot path (control-manifest: "`legal_targets()`: O(4·attack_range) DIRECT… dominant caller = AI lookahead"), and the bound above is within that documented guardrail — no budget concern.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `damage()`/`preview_damage()` — already implemented, this story only adds targeting
- Story 003: AREA profile, `min_range`/dead-zone logic, `legal_targets_from()` hypothetical-tile overload
- Story 004+: `attack()` pipeline, AP spend, validation dispatch

---

## QA Test Cases

- **AC-1 (in-range clean shot)**: Given a Sniper (range 3) with an enemy exactly 3 tiles away cardinally, nothing intervening, When `legal_targets()` is queried, Then the enemy's `TargetResult` is present.
  Edge cases: enemy at exactly range 1 (adjacent) — the minimum DIRECT range — also targetable.

- **AC-2 (LoF blocked by friendly)**: Given a friendly unit between attacker and enemy on the cardinal line, When `legal_targets()` is queried, Then the enemy is absent from the result set, and `blocked_reason()` for that direction reports `BLOCKED_BY_FRIENDLY`.
  Edge cases: the blocker is a friendly **structure** instead of a unit — same result.

- **AC-3 (LoF blocked by Impassable)**: Given an Impassable tile between attacker and enemy, When `legal_targets()` is queried, Then the enemy is absent, tiles beyond the Impassable tile are never targetable that direction.

- **AC-4 (nearest-only, no pierce)**: Given two enemies stacked on the same cardinal line within range, When `legal_targets()` is queried, Then only the nearer enemy's `TargetResult` is present — the farther one is never returned.

- **AC-5 (out-of-range)**: Given an enemy on the line beyond `attack_range` (Trooper range 2, enemy at distance 3, no closer blocker), When `legal_targets()` is queried, Then no target that direction, and `blocked_reason()` reports `OUT_OF_RANGE`.

- **AC-6 (non-cardinal rejection)**: Given an enemy at a diagonal offset from the attacker, When `legal_targets()` is queried, Then the enemy never appears in the result set (DIRECT recognizes only the 4 cardinals).
  Edge cases: an enemy at a tile that is both non-cardinal AND within `manhattan_distance <= attack_range` — still never targetable, proving DIRECT range is cardinal-line distance, not manhattan.

- **AC-7 (three distinct blocked reasons)**: Given three separate fixture directions — one blocked by a friendly, one exhausted at `attack_range` with nothing found, one with no enemy present at all — When `blocked_reason()` is queried for each, Then each returns a distinct enum value (`BLOCKED_BY_FRIENDLY`, `OUT_OF_RANGE`, or `NONE`/no-target) — never the same generic value for different causes.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/direct_targeting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`combat.gd` file must exist; this story extends it — no functional dependency on `damage()` itself)
- Unlocks: Story 004 (`attack()`'s `validate()` calls `legal_targets()` to check target legality)

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 6/6 passing (0 deferred) — all covered by `tests/unit/combat/direct_targeting_test.gd` (16 test functions), full suite 277/277 green.
**Deviations**: None. All three `/code-review` suggestions were applied before closing: (1) refreshed the stale "Story 001 scope only" class-level doc comment in `combat.gd` to reflect Story 002 landing; (2) typed `_WalkResult.reason`/`_init` param as `BlockedReason` (was `int` + comment), dropping the now-redundant `as BlockedReason` cast; (3) added `test_legal_targets_and_blocked_reason_do_not_mutate_state` (purity/no-mutation guard). Re-verified 277/277 after the fixes.
**Design note**: an Impassable-terrain blocker reports `BlockedReason.OUT_OF_RANGE` — the GDD's three-state blocked model (`blocked-by-friendly`/`out-of-range`/`inside-dead-zone`) has no distinct "wall" state, so folding Impassable into `OUT_OF_RANGE` is within spec.
**Test Evidence**: Logic — `tests/unit/combat/direct_targeting_test.gd` (BLOCKING gate satisfied).
**Code Review**: Complete — `/code-review` run this session, verdict APPROVED (godot-gdscript-specialist CLEAN, qa-tester TESTABLE, 0 required changes; all 3 suggestions applied).
