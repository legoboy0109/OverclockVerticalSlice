# Story 007: Determinism & Clone Isolation

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: Targeting, damage, counters, and removal are pure functions of the game state and the chosen action — stable iteration order, no RNG, computable on a `clone()` for AI look-ahead and headless tests. This story adds no new production code; it is a dedicated assertion pass proving the full `Combat.apply()` pipeline (Stories 004–006) already satisfies ADR-0003's determinism guarantee and never leaks a mutation back into a cloned source state.

**Secondary ADRs**: ADR-0003 (Deterministic Simulation & RNG Isolation — the governing cross-cutting policy this story validates Combat against), ADR-0001 (`GameState.clone()`/`duplicate_deep()` — the clone mechanism under test)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: No engine API surface — this story is pure test authorship against already-shipped `clone()`/`duplicate_deep()` behavior (confirmed engine-safe by ADR-0001/ADR-0007's godot-specialist review).
**Performance**: N/A — no new production code. This is a test-only assertion pass against already-shipped, already-budgeted `Combat.apply()`/`Combat.damage()`/`GameState.clone()` calls; their performance is covered by ADR-0010's and ADR-0001's Performance sections. The test fixtures build small hand-constructed `GameState`s (no large-map or per-frame path).

**Control Manifest Rules (this layer)**:
- Required: `reachable()`/`legal_targets()`/`attack()`-style pure functions must be computable identically on `clone()`d states — source: ADR-0003, ADR-0010 (no new rule; this story is validation of existing rules, not a new pattern)

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

**Cross-clone equal result** — given a state `S` and two independent clones (`A = clone(S)`, `B = clone(S)`), applying the identical `attack(attacker, target)` to `A` and to `B` yields equal returned `damage` ints **and** leaves `A` and `B` equal under the state-equality predicate (every affected entity's `current_hp`, `position`, `has_attacked`, presence/absence in `entities_by_id`, and the full `grid.occupancy` map all match — no RNG, stable iteration order):

- [ ] holds for a **non-lethal** primary hit (defender survives, no counter)
- [ ] holds for a **lethal** primary hit (defender reaches 0 hp → destroyed/removed this step)
- [ ] holds for a **counter-triggering** hit (defender survives, `can_counterattack` fires — both primary and counter hp changes present)

**Clone isolation from source** — given a state `S` and a clone `C = clone(S)`, applying `attack(...)` only to `C` leaves `C` reflecting the attack while **`S` is unchanged** under the same state-equality predicate (the resolution never mutates the source state, so AI look-ahead is side-effect-free):

- [ ] holds for a **non-lethal** hit
- [ ] holds for a **lethal** hit — the destroyed entity is still present (alive) in `S` and absent from `entities_by_id` only in `C`; `S.grid.occupancy` still shows the tile occupied while `C.grid.occupancy` shows it empty
- [ ] holds for a **counter-triggering** hit

*(Per the GDD: "State-equality is this field-wise comparison, not byte-level serialization — no hashing/serialization infrastructure is required or implied.")*

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- No new production code is anticipated for this story — if writing these tests surfaces a genuine determinism/clone-isolation bug in Stories 004–006's code (e.g. an accidental shared-reference mutation, or an order-dependent iteration), fix it as part of this story and note the fix in the story's commit, but do not pre-emptively add defensive code with no failing test driving it.
- Field-wise equality helper: write a small test-local comparison function (or check whether `tests/helpers/` already has a state-equality assertion helper from another epic's determinism tests, e.g. Movement's `movement_determinism_test.gd` — reuse its pattern/helper if one already exists there rather than writing a second one from scratch) that compares, for every entity present in both states: `current_hp`, `position`, `has_attacked`, and presence/absence in `entities_by_id` (a "destroyed" entity is simply absent — there is no separate boolean flag to compare beyond that), plus the full `grid.occupancy` `PackedInt32Array` equality.
- Test scenarios should exercise the full pipeline breadth already built by Stories 004–006: a plain non-lethal hit, a lethal primary hit (destruction), and a counter-triggering hit (both primary and counter hp changes) — each run through the two-clones-equal-result pattern and the clone-vs-source-isolation pattern. This is the pipeline-level determinism check the GDD's AC groups under "Death & determinism" (the last AC bucket in the Pure Logic gate) — it is deliberately the **last** story in the Logic sequence so it can exercise the complete pipeline rather than a partial one.
- Mirror `tests/integration/movement/movement_determinism_test.gd`'s structure/naming conventions where they transfer directly (it already solved "two clones, same action, compare state" for Movement) — Combat's version differs mainly in scenario content (attack fixtures instead of move fixtures), not in test architecture. Despite the name, this story's tests belong in `tests/unit/combat/` per the Test Evidence path below (they use fully injected/fixture-built `GameState`s, not the real end-to-end `apply_action` + Movement combination Story 008 covers) — do not follow Movement's `tests/integration/` placement here; that placement was specific to Movement's own story split.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: integration-level determinism concerns (if any arise) through the real `apply_action` dispatch path — this story tests `Combat.apply()`/`Combat.damage()` directly against fixture states, not through `GameState.apply_action()`

---

## QA Test Cases

- **AC-1 (cross-clone equal result)**: Given state `S` with a legal attacker/target pair, When `A = S.clone()`, `B = S.clone()`, and the identical attack is applied to both, Then the returned damage ints are equal and `A`/`B` are field-wise equal afterward (entity hp/position/has_attacked, Grid occupancy).
  Edge cases: repeat for a lethal hit (destruction) and for a counter-triggering hit — determinism must hold across all three pipeline shapes, not just the simplest non-lethal case.

- **AC-2 (clone isolation from source)**: Given state `S` and `C = S.clone()`, When the attack is applied only to `C`, Then `C` reflects the attack's effects and `S` remains field-wise identical to its pre-clone snapshot — the resolution never wrote back into the original.
  Edge cases: the lethal-hit case — confirm the destroyed entity is still present (alive) in `S` and absent from `entities_by_id` only in `C`, and that `S.grid.occupancy` still shows the entity's tile occupied while `C.grid.occupancy` shows it empty.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/determinism_test.gd` — must exist and pass

**Status**: [x] Created and passing (8 tests, full suite 335/335)

---

## Dependencies

- Depends on: Story 006 (exercises the complete `Combat.apply()` pipeline — primary damage, death, counter — as a whole)
- Unlocks: Story 008 (the Integration gate can now assume the underlying Logic pipeline is proven deterministic)

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 6/6 passing (all COVERED by tests, no deferrals)
**Deviations**: None — no new production code required; `Combat.apply()`/`clone()`/`destroy_entity()` already satisfied determinism and clone-isolation as designed
**Test Evidence**: Logic — `tests/unit/combat/determinism_test.gd` (8 test functions: 6 AC-covering + 2 negative sanity tests guarding the state-equality helper); full suite 335/335 passing
**Code Review**: Complete — `/code-review` initial verdict APPROVED WITH SUGGESTIONS; high-value suggestion (negative test proving `_states_equal()` detects inequality) applied and re-verified → final verdict APPROVED
