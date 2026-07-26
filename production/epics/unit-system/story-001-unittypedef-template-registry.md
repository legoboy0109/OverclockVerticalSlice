# Story 001: UnitTypeDef Template Resource + Registry (Roster Data)

> **Epic**: Unit System
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-001`, `TR-unit-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Data-driven entity/stat schema
**ADR Decision Summary**: Unit/structure/tech stats live as typed `Resource` templates (`.tres`), statically typed, injectable in tests, loaded once via a thin registry — never `load()`ed ad hoc at call sites.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: `Resource` subclasses; `.tres` authoring. No post-cutoff API — the MEDIUM risk (ADR-0007 `duplicate_deep()`) applies to the runtime `UnitState` (Story 002), not this template layer.

**Control Manifest Rules (this layer)**:
- Required: "Entity/stat templates are typed `Resource`s with `@export` fields; static typing throughout" — source: ADR-0007
- Forbidden: "Never `load()` unit `.tres` outside the registry — preload via the registry const-holder" — source: ADR-0007
- Forbidden: "No untyped `Variant`/Dictionary for stat data" — source: ADR-0003/0007

---

## Acceptance Criteria

*From GDD `design/gdd/unit-system.md`, scoped to this story:*

- [ ] **GIVEN** each unit type is instantiated, **WHEN** its stats are read, **THEN** they match the Rule 3 table exactly — Scout (hp 3, atk 2, range 1, move 1, cap 4, cost 2), Trooper (6, 3, 2, 2, 3, 4), Heavy (10, 5, 2, 3, 2, **7**), Sniper (3, 6, 3, 2, 3, 5).
- [ ] **GIVEN** each unit type, **WHEN** its `defense` field is read, **THEN** it is 0 for all four types.
- [ ] **GIVEN** a `UnitTypeDef` constructed in-memory in a test (injected, not loaded from disk) with `Trooper.hp = 99`, **WHEN** a unit is instantiated from it, **THEN** the read value is 99 — proving stats flow from injected external data.

---

## Implementation Notes

*Derived from ADR-0007 Key Interfaces:*

- `UnitTypeDef extends Resource` with `@export` fields: `display_name: String`, `hp: int`, `attack: int`, `attack_range: int`, `move_cost: int`, `soft_move_cap: int`, `produce_cost: int`, `defense: int = 0`, `targeting_mode: int = TargetingMode.DIRECT` (enum `{DIRECT, AREA}`), `min_range: int = 1`, `can_counterattack: bool = false`.
- Author four `.tres` (`res://data/units/{scout,trooper,heavy,sniper}.tres`) with the Rule 3 table values; the four combat-infra fields at roster-wide defaults (defense 0, DIRECT, min_range 1, can_counterattack false) per GDD Rule 3a.
- Registry: a `class_name UnitTypes` const-holder with `const SCOUT/TROOPER/HEAVY/SNIPER: UnitTypeDef = preload(...)` (mirrors the `Balance`/`EconomyConfig` pattern). **Never `load()` these `.tres` outside the registry** — the load-bearing forbidden rule.
- Static typing throughout (TR-unit-014) — every field typed, no `Variant`.
- Test-injection seam: tests construct `UnitTypeDef.new()` in-memory (never touching disk) to prove the data-driven contract — that is the AC's point, not file loading.

---

## Out of Scope

- Story 002: runtime `UnitState`.
- Combat epic: consumption of `defense`/`targeting_mode`/`min_range`/`can_counterattack`.
- Base & Production / Research epics: structure/tech templates.

---

## QA Test Cases

- **AC-1 (stat table)**: Given the 4 preloaded `UnitTypeDef` consts / When their fields are read / Then values exactly match the Rule 3 table. Edge case: verify `Heavy.produce_cost == 7` specifically (regression guard against the stale 6).
- **AC-2 (defense default)**: Given each of the 4 types / When `defense` is read / Then 0 for all four.
- **AC-3 (injection seam)**: Given a `UnitTypeDef.new()` built in-memory with `hp = 99` (no `preload`/`load`) / When read / Then 99. Edge case: confirm no test touches `res://data/units/*.tres` directly except via the registry.

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/unit-system/unit_typedef_test.gd` — must exist and pass (the injection-seam AC is Logic-testable; a smoke check covers the `.tres` values)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational).
- Unlocks: Story 002 (`UnitState.type: UnitTypeDef`), Stories 004/005 (read `base_attack`/`base_defense`), Base & Production (`producible_types: Array[UnitTypeDef]`).
