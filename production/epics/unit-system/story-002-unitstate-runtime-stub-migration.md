# Story 002: UnitState Runtime Schema + Stub Migration (Sprint-1 Seam Closure)

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-002`, `TR-unit-003`, `TR-unit-014`, `TR-unit-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Data-driven entity/stat schema
**Secondary ADRs**: ADR-0001 (state/ownership — `EntityState` subclassing, `next_entity_id`), ADR-0008 (start-of-turn consumes the flags).
**ADR Decision Summary**: Per-unit runtime state is a typed `EntityState` subclass carrying only serializable value fields, `@export`ed so `duplicate_deep()` never silently drops one; the shared template is referenced, not copied.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: This is the ADR-0007 `duplicate_deep()` clone-safety schema. `UnitState.type: UnitTypeDef` (a path-having preload'd Resource) must be **shared** (`===`) across a clone, while mutable fields must be **independent**. A field missing `@export` is silently excluded from `duplicate_deep()` (ADR-0001/0007 Risks) — the concrete failure mode to guard.

**Control Manifest Rules (this layer)**:
- Required: "Per-unit runtime state extends `EntityState`; every field `@export`ed and statically typed" — source: ADR-0007/0001
- Required: "`entity_id` is driven by `GameState.next_entity_id` (single incrementing int, bumped via `apply_action`)" — source: ADR-0001
- Forbidden: "Never build a separate injectable `EntityIdAllocator`" — source: ADR-0001

---

## Acceptance Criteria

- [ ] **GIVEN** a freshly constructed unit, **WHEN** `has_attacked` and `tiles_moved_this_turn` are read, **THEN** they are `false` and `0` (no summoning sickness at the data level).
- [ ] **GIVEN** N units instantiated in one game state, **WHEN** their `entity_id`s are compared, **THEN** all N are pairwise distinct (uniqueness scoped to a single game state).
- [ ] **GIVEN** the real `UnitState`/`Unit` classes exist in `src/`, **WHEN** the project loads, **THEN** no duplicate `class_name` registration occurs (the Sprint-1 stubs are physically deleted) and GS-003 tests that referenced `stub.has_acted` now assert the real `has_attacked` and still pass.

---

## Implementation Notes

*Derived from ADR-0007 Key Interfaces:*

- `class_name UnitState extends EntityState` with `@export var type: UnitTypeDef`, `@export var current_hp: int`, `@export var has_attacked: bool = false`, `@export var tiles_moved_this_turn: int = 0`. Inherit `entity_id`/`owner`/`position` from `EntityState` — do not redeclare.
- `entity_id` from `GameState.next_entity_id` (bumped via `apply_action`), test-injectable only by constructing a fresh `GameState` (DI, not global).
- **Stub migration (the epic's seam-closure requirement)**: delete `tests/helpers/stubs/unit_state_stub.gd` (stub `class_name UnitState` with `has_acted`) and `tests/helpers/stubs/unit_stub.gd` (stub `class_name Unit`). GDScript `class_name` is project-global — the real `src/` classes collide with the stubs the moment both exist. Update every GS-003 test using `stub.has_acted` → real `has_attacked`.
- All fields `@export` (storage-flag discipline) — the concrete code-review checklist item.
- Static typing throughout (TR-unit-014).

---

## Out of Scope

- Story 003: `can_attack`/`reset_turn_flags`/`duplicate`/`apply_hp_delta`.
- Stories 004/005: effective attack/defense.

---

## QA Test Cases

- **AC-1 (fresh-instance defaults)**: Given `UnitState.new()` with an injected `type` / When read immediately after construction / Then `has_attacked == false`, `tiles_moved_this_turn == 0`. Edge case: defaults hold without caller setting them.
- **AC-2 (entity_id uniqueness)**: Given a `GameState` with `next_entity_id == 0` / When 5 entities are created / Then all 5 ids are pairwise distinct. Edge case: a unit and a structure interleaved still get distinct ids (shared counter).
- **AC-3 / regression (stub migration)**: Given the real `UnitState` exists / When the project loads / Then no duplicate-`class_name` error (stub deleted) and GS-003 tests re-pointed to `has_attacked` still pass.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/unit_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`UnitTypeDef`); ADR-0001 `EntityState`/`GameState.next_entity_id` (landed via GS-003/GS-004).
- Unlocks: Story 003; Stories 004–008; GS-004 win-check + Combat epic (read `UnitState.hp`/schema); Base & Production (instantiates `UnitState`).

---

## Completion Notes
**Completed**: 2026-07-26 (implemented jointly with Story 003 — the `class_name` stub migration only compiles when both land together)
**Criteria**: 3/3 passing
**Deviations**: None specific to this story. (See Story 003 for the shared `duplicate`→`clone` rename.)
**Test Evidence**: Logic — `tests/unit/unit_state_test.gd` (fresh-defaults + entity_id uniqueness); stub deletion + `turn_sequencing_test.gd` migration (`has_acted`→`has_attacked`). Full suite 198/198 PASS.
**Code Review**: Complete — `/code-review` APPROVED (godot-gdscript-specialist, CLEAN, clone-safety contract verified in production code).

**Files delivered**:
- `src/core/unit/unit_state.gd` (`UnitState extends EntityState`, all fields `@export`)
- Deleted `tests/helpers/stubs/unit_state_stub.gd` + `unit_stub.gd`
- Migrated `tests/unit/turn_sequencing_test.gd` (`has_acted`→`has_attacked`, now exercises the real `Unit.reset_turn_flags`)
- `tests/unit/unit_state_test.gd`
