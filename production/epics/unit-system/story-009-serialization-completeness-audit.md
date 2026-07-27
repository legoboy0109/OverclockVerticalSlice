# Story 009: duplicate() / Serialization Completeness for Save + AI Snapshot

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-015` (also touches `TR-unit-003`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: State model / ownership / lifecycle
**Secondary ADRs**: ADR-0007 (schema), ADR-0003 (no floats/nondeterminism).
**ADR Decision Summary**: Every state field is a plain serializable value (no `Node`/`RID`, no float), `@export`ed so `duplicate_deep()` reconstructs it exactly — the basis for save/load and AI snapshotting.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: Same `duplicate_deep()` clone-safety class as Story 003, but this story's job is the whole-`UnitState` serializability/no-nondeterministic-fields guarantee (no engine object references, no float, all `@export`).

**Control Manifest Rules (this layer)**:
- Required: "Every state field is a plain serializable value — no engine object references (`Node`, `RID`)" — source: ADR-0001
- Required: "State is 100% integer — no float ever; fractional coefficients as scaled ints" — source: ADR-0003
- Required: "Every field carries `@export` (a missing one is silently dropped by `duplicate_deep()`)" — source: ADR-0007

---

## Acceptance Criteria

- [ ] **GIVEN** a `UnitState` with all fields set to non-default values, **WHEN** it is `duplicate_deep()`'d and read back, **THEN** every field round-trips exactly (no silent field loss) — a full-field audit beyond Story 003's four-field check.
- [ ] **GIVEN** a `UnitState`, **WHEN** its fields are enumerated, **THEN** none is an engine object reference (`Node`, `RID`) and none is a float.
- [ ] **GIVEN** a `UnitState`, **WHEN** every field is checked for `@export`, **THEN** all are present.

---

## Implementation Notes

- This is largely a **verification/audit** story layered on Stories 002–003, not new production code — but TR-unit-015 is a distinct requirement ("fully serializable/reconstructable for save + AI snapshot via `duplicate()`, no nondeterministic fields") that deserves its own dedicated regression test file rather than being folded silently into Story 003.
- Cross-reference ADR-0003's float-in-state ban and ADR-0001's "no engine object references" Foundation rule directly.
- Document (test-file header comment) that a future save/load system builds on exactly this suite.

---

## Out of Scope

- An actual save/load implementation (out of VS scope — no save system exists yet).
- AI's actual lookahead consumption of `duplicate()` (AI epic, ADR-0011).

---

## QA Test Cases

- **AC-1 (full round-trip)**: Given a `UnitState` with every field a distinct non-default test value / When `duplicate_deep()` then field-by-field compared / Then every field matches (mutable by value, `type` by reference). Edge: `position = Vector2i(-1,-1)` round-trips (no field-specific special-casing).
- **AC-2 (no engine refs / no floats)**: Given the `UnitState` class definition / When its field list is enumerated in the test / Then no field's declared type is `Node`, `RID`, or `float`. Edge: write as an explicit type-list assertion that fails loudly if a future contributor adds a float field.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/unit_serialization_test.gd` — must exist and pass

**Status**: [x] Created and passing (7 tests, full suite 359/359)

---

## Dependencies

- Depends on: Story 002, Story 003.
- Unlocks: any future save/load epic (documented foundation, not implemented now); AI epic lookahead correctness.

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 3/3 passing (all COVERED by tests, no deferrals)
**Deviations**: None — no new production code required; all 7 `UnitState` fields already correctly `@export`'d, non-float, non-engine-ref
**Test Evidence**: Logic — `tests/unit/unit-system/unit_serialization_test.gd` (7 test functions; first reflection-based test in the codebase, `get_property_list()` semantics independently verified against live Godot 4.6 docs); full suite 359/359 passing
**Code Review**: Complete — `/code-review` initial verdict APPROVED WITH SUGGESTIONS; a real logic gap (a tautological "no unexpected field" test) was found and fixed — replaced with a genuine schema-drift guard deriving the Resource-builtin allowlist at runtime — re-verified → final verdict APPROVED
