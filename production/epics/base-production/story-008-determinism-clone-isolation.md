# Story 008: Determinism & Clone Isolation

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — Core Rule 13 (deterministic and headless); the "Formulas & determinism (Rules 10, 13)" clone ACs (field-wise state-equality predicate + clone isolation).
**Requirement**: `TR-baseprod-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Deterministic simulation & RNG isolation
**Secondary ADRs**: ADR-0001 (`clone()` == `duplicate_deep()`), ADR-0017 (the B&P verbs under test).
**ADR Decision Summary**: Every B&P function is a pure function of `GameState` + chosen action — no RNG, integer-only state, stable iteration order, computable on a `clone()` for AI look-ahead and headless tests. State-equality is a **field-wise comparison** (not byte-level serialization — no hashing/serialization infrastructure). Any order-sensitive pass over `entities_by_id` iterates a list sorted by a stable key.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `clone()` is `duplicate_deep()` cast to `GameState`; preload'd (path-having) `StructureTypeDef`/`UnitTypeDef` templates stay SHARED references under clone (not deep-copied) — comparing `type` by reference identity is correct and clone-stable. Global `randi()`/`randf()`/etc. are banned project-wide (CI greps). No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Pure game-logic classes (`BaseProduction`, …) must be headless-testable with zero scene tree — no `Node` dependency" — source: ADR-0001/ADR-0017
- Required: "Any order-sensitive pass over `entities_by_id` must iterate a list sorted by a stable key (`entity_id` or tile index) — never rely on Dictionary hash/insertion order" — source: ADR-0003
- Required: "`clone()` must be implemented as `duplicate_deep()` cast to `GameState` — one call, no hand-written per-field copy" — source: ADR-0001
- Forbidden: "Never call global `randi()`/`randf()`/`randi_range()`/`randf_range()`/`randomize()`/`seed()` anywhere in the project" — source: ADR-0003
- Cross-cutting: "No float in any state field, ever — all state is `int`/`enum`/`Vector2i`" — source: ADR-0003

> **Pattern note**: Mirror the Combat epic's determinism story — `tests/unit/combat/determinism_test.gd` (`design/gdd/combat-resolution.md`'s determinism predicate is the same field-wise one this story reuses). This is a **test-only** story — no new production code; it verifies the purity of the verbs shipped in Stories 002/004/005/006.

---

## Acceptance Criteria

*Formulas & determinism (Rules 10, 13):*
- [ ] **GIVEN** a fixture `S` and two independent clones (`A = clone(S)`, `B = clone(S)`), **WHEN** the same action (build / produce / cancel / structure-attack) is applied to `A` and to `B`, **THEN** `A` and `B` are equal under the **defined field-wise state-equality predicate** — every affected structure's `build_status` (Under-Construction/Completed), remaining build-turns, `hp`, `units_produced_this_turn`, `has_attacked`, both players' AP pools, and the Grid occupancy map all match (no RNG, stable iteration order).
- [ ] **GIVEN** a fixture `S` and a clone `C = clone(S)`, **WHEN** an action is applied to `C`, **THEN** `C` reflects the action and **`S` is unchanged** under the same predicate (clone isolation — resolution never mutates the source, so AI look-ahead is side-effect-free).

---

## Implementation Notes

*Derived from ADR-0003 and the Combat determinism precedent:*

- **Field-wise state-equality predicate** (not byte-level): compare, for every affected structure, `build_status`, `build_turns_remaining`, `hp` (`current_hp`), `units_produced_this_turn`, `has_attacked`; both players' AP pools; and the full Grid occupancy map. Reuse the same field-wise predicate `combat-resolution.md` / `tests/unit/combat/determinism_test.gd` defines — no hashing or serialization infrastructure is required or implied.
- **Two-clone parity**: `A = clone(S)`, `B = clone(S)`; apply the identical action to each; assert `A ≡ B` field-wise. Run for each of the four B&P actions: **build**, **produce**, **cancel**, **structure-attack**.
- **Clone isolation**: `C = clone(S)`; apply an action to `C`; assert `C` changed **and** `S` is unchanged (the source is never mutated — AI look-ahead safety).
- **No RNG, stable order**: the verbs already use `sort_custom`/`entity_id`-ordered iteration (Stories 002/004). This story is the regression pin that a future change doesn't introduce Dictionary-order dependence or a stray `randi()`.
- **Test-only**: no production code. If a determinism failure surfaces, the fix belongs in the owning verb's story (002/004/005/006), not here.

---

## Out of Scope

- The verb implementations themselves — Stories 002 (build), 004 (produce), 005 (cancel), 006 (structure-attack). This story only pins their determinism.
- Cross-platform bit-determinism / fixed-point AI scoring — explicitly out (ADR-0003 rejects full bit-determinism).
- Integration-level determinism against the real Turn Manager — the Integration gate (Story 010) exercises real stack behavior; clone parity is the pure-slice concern here.

---

## QA Test Cases

- **AC-clone-parity (build)**: Given `A = clone(S)`, `B = clone(S)` / When `build(...)` applied to each / Then `A ≡ B` field-wise (build_status, build-turns, hp, counters, both AP pools, Grid occupancy).
- **AC-clone-parity (produce)**: same predicate, action = `produce(...)`.
- **AC-clone-parity (cancel)**: same predicate, action = `cancel_build(...)` (AP-pool + occupancy-removal parity).
- **AC-clone-parity (structure-attack)**: same predicate, action = structure `attack(...)` (`has_attacked` + AP + target hp parity).
- **AC-clone-isolation**: Given `C = clone(S)` / When an action applied to `C` / Then `C` reflects it and `S` is unchanged under the same predicate (no source mutation).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/determinism_clone_isolation_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/base-production/determinism_clone_isolation_test.gd` (15 tests, passing)

---

## Dependencies

- **Depends on**: Story 002 (build), Story 004 (produce), Story 005 (cancel), Story 006 (structure-attack) — the four actions under determinism test. Uses the already-shipped `GameState.clone()` (Foundation, Complete).
- **Unlocks**: Confidence for the AI epic's clone-based look-ahead over B&P actions (Feature layer).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 2/2 passing (AC-1 parity decomposed into 4 per-verb tests; AC-2 isolation into 3; all COVERED). Predicate load-bearing-ness proven by 8 single-field negative controls.
**Deviations**: None — test-only, no `src/` change. Pins the determinism/purity of the verbs shipped in Stories 002/004/005/006. During code-review, added a `position` negative control so the field-wise predicate is 100% negative-control-covered (was the one advisory gap).
**Test Evidence**: Logic — `tests/unit/base-production/determinism_clone_isolation_test.gd` (15 tests). Full suite 475/475, exit 0.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist CLEAN, traced every fixture against production code — parity non-vacuous, isolation proves no leak-back, negative controls isolate single fields, no missed mutable field; qa-tester TESTABLE, no must-fix — confirmed all parity/isolation/negative-control tests genuinely load-bearing; the path-less dummy-enemy type is inert since the predicate never compares `.type`).
**Tech debt**: None.
