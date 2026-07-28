# Story 008: Lifecycle States + Edge-Case Guards (Summoning Sickness, Destroy-on-0, AP Gating)

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Data-driven entity/stat schema
**Secondary ADRs**: ADR-0010 (destroy-on-hp-0 via shared `GameState.destroy_entity`).
**ADR Decision Summary**: Lifecycle is Produced (presentation-only transient) → Active → Destroyed; there is no summoning sickness; destruction is the single shared `destroy_entity()` mutation-layer method, called from Combat's `apply()`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW (this story is integration-guard tests over Stories 002/003 mechanics)
**Engine Notes**: None post-cutoff. Integration tests use a fake/stub Grid.

**Control Manifest Rules (this layer)**:
- Required: "Death/removal is a single shared `GameState.destroy_entity(entity_id) -> Array[Event]`, called from inside a verb handler's `apply()`" — source: ADR-0010
- Forbidden: "Never add a `state` enum field for 'Produced' — a unit IS Active on creation" — source: ADR-0007 (over-engineering guard)

---

## Acceptance Criteria

- [ ] **GIVEN** a unit at `current_hp` 0, **WHEN** resolution completes, **THEN** it transitions to Destroyed, is removed from Grid occupancy that step, and its tile reads empty (Unit + fake Grid).
- [ ] **GIVEN** a unit produced this turn with sufficient AP, **WHEN** a move/attack is issued for it the same turn, **THEN** it succeeds (no summoning sickness, end-to-end).
- [ ] **GIVEN** a unit with `has_attacked == true` and sufficient AP, **WHEN** a move is issued, **THEN** it succeeds and position changes (movement never gated by the attack flag).
- [ ] **GIVEN** an owner with less AP than a candidate move's surcharged total, **WHEN** the move is attempted, **THEN** rejected, no AP spent, position unchanged.

---

## Implementation Notes

*Derived from GDD States & Transitions + ADR-0010:*

- Lifecycle: **Produced** is a presentation-only transient (no field observes it — a unit *is* Active on creation). Do NOT add a `state` enum for "Produced".
- "No summoning sickness" (TR-unit-012): a fresh `UnitState` has `has_attacked = false`, `tiles_moved_this_turn = 0` from birth (Story 002 defaults) — this story proves it **end-to-end** through a real move/attack action, not just field defaults.
- Destroy-on-0: `GameState.destroy_entity(entity_id)` is the single shared method (ADR-0010) — Unit System does not implement its own destroy path; this story's Integration test uses a fake Grid to verify the contract (hp 0 → destroyed → `Grid.remove` called → tile empty) without the full Combat pipeline.
- hp-ceiling clamp: already Story 003's `apply_hp_delta` AC — confirm the reserved-headroom framing is doc-commented, no new mechanic.
- AP-gating ("never move on credit"): Unit supplies correct costs (Story 006); the `can_afford`/rejection flow is AP/Movement's, tested here at the integration seam only.

---

## Out of Scope

- Combat epic: the full pipeline / `destroy_entity()` implementation (ADR-0010).
- Movement epic: the `move()` verb handler. This story's Integration tests use fakes/stubs for Grid/Combat/Movement.

---

## QA Test Cases

- **AC-1 (destroy-on-0, integration)**: Given a `UnitState` at `current_hp = 0` on a fake `GridState` / When `GameState.destroy_entity(unit.entity_id)` / Then removed from `entities_by_id`, `Grid.remove()` called, tile empty. Edge: same resolution step (no deferred removal).
- **AC-2 (no summoning sickness, integration)**: Given a unit created this turn with sufficient AP / When a move then an attack are issued same turn / Then both succeed. Edge: reversed order also succeeds.
- **AC-3 (attack flag doesn't gate movement)**: Given `has_attacked = true` + sufficient AP / When a move is issued / Then succeeds, position changes. Edge: a *second* attack is separately rejected by `can_attack` (Story 003) — flags independent.
- **AC-4 (AP-gated rejection, no credit)**: Given AP strictly < a candidate move's surcharged total / When attempted / Then rejected, AP unchanged, position unchanged. Edge: AP == cost succeeds; AP == cost-1 fails (boundary).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/unit_lifecycle_test.gd` — must exist and pass (integration-style, fakes for Grid/Combat/Movement)

**Status**: [x] Created and passing (9 tests, full suite 352/352)

---

## Dependencies

- Depends on: Story 002, Story 003 (`apply_hp_delta`), Story 006 (AP cost values); Combat epic (`destroy_entity`, ADR-0010, Accepted), AP Economy (landed).
- Unlocks: GS-004 win-check (reads the Destroyed transition).

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 4/4 passing (all COVERED by tests, no deferrals)
**Deviations**: None — no new production code required; no "Produced" state enum added (ADR-0007 forbidden-pattern respected)
**Test Evidence**: Logic — `tests/unit/unit-system/unit_lifecycle_test.gd` (9 test functions covering AC-1..4); full suite 352/352 passing
**Code Review**: Complete — `/code-review` initial verdict APPROVED WITH SUGGESTIONS; the one item both reviewers raised (AC-4's two failure tests were byte-identical AP=0 fixtures on a cost-1 Scout) was fixed by switching the boundary trio to Trooper (`move_cost 2`, distinct AP values 0/2/1), re-verified → final verdict APPROVED. Optional suggestions (frame-await synchronicity probe; mirrored move-doesn't-gate-attack test) declined as low-value.
