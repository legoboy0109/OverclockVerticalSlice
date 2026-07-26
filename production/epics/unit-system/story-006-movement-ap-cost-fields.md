# Story 006: Movement & AP Cost Fields (Unit-Owned Values, Consumed Cross-System)

> **Epic**: Unit System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-008`, `TR-unit-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Reachable search / pathfinding
**Secondary ADRs**: ADR-0006 (AP spend for costs), ADR-0007 (cost fields on `UnitTypeDef`), ADR-0003 (integer-only).
**ADR Decision Summary**: `SOFT_MOVE_PENALTY` is a Unit-owned fixed-point int in a `UnitConfig` Resource (never on `GameState`); the per-tile surcharge is integer ceil-division; Movement's summation consumes these values but Unit owns them.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff. Integer ceil-division (`(a + 9) / 10` for /10 fixed point).

**Control Manifest Rules (this layer)**:
- Required: "`SOFT_MOVE_PENALTY` is a Unit-owned fixed-point int (`soft_move_penalty_x10`) in `UnitConfig`, never on `GameState`" — source: ADR-0009
- Required: "All AP is integer; fractional coefficients as scaled ints, computed via integer ceil/floor" — source: ADR-0003
- Forbidden: "Never put `income()`/`spend()`/`can_afford()` directly on `GameState`/`PlayerState`" — source: ADR-0006

---

## Acceptance Criteria

- [ ] **GIVEN** the ladder constants, **WHEN** Heavy `produce_cost` (7) + one-tile move (`move_cost` 3) + Combat `attack_cost` (2) are summed, **THEN** the total (12) exceeds floor income (10) — a pure-arithmetic regression guard.
- [ ] **GIVEN** a unit's `move_cost` and the default penalty, **WHEN** `UnitConfig.surcharge_for(move_cost)` is called, **THEN** it returns the integer-ceil surcharge matching the GDD worked examples (Scout `ceil(1×2.0)=2`, Heavy `ceil(3×2.0)=6`).

*(Full surcharge-summation + AP-gated-rejection flow are Movement's suite — this story exposes correct, correctly-typed `move_cost`/`soft_move_cap`/`tiles_moved_this_turn` and the `SOFT_MOVE_PENALTY` constant Movement consumes.)*

---

## Implementation Notes

*Derived from ADR-0009 guidelines:*

- `UnitConfig extends Resource` with `@export var soft_move_penalty_x10: int = 20` (2.0 default), authored as a `.tres`, loaded via the same thin-Autoload pattern as `EconomyConfig`/`Balance` — **never on `GameState`**.
- `UnitConfig.surcharge_for(move_cost) -> int`: `return (move_cost * soft_move_penalty_x10 + 9) / 10` (integer ceil). This per-tile primitive is Unit-owned (operates purely on Unit-owned inputs); the escalation **summation** is Movement's — confirm the boundary during Movement-epic wiring.
- `move_cost`/`soft_move_cap` are `UnitTypeDef` fields (Story 001) — this story asserts they're read correctly, not re-defines them.
- `tiles_moved_this_turn` is `UnitState`'s counter (Story 002) — Movement is the sole writer; Unit owns the field + its reset (Story 003).
- `produce_cost` (TR-unit-009): confirm `AP.can_afford`/`AP.spend` gate on the unit-owned cost without Unit reaching into AP internals.

---

## Out of Scope

- Movement epic (ADR-0009): the soft-cap surcharge **summation**, `move_path_cost`, the reachable-search BFS, and the over-budget-move rejection integration test.
- Combat epic: `attack_cost` (2 AP) — this story only uses it as an arithmetic operand.

---

## QA Test Cases

- **AC-1 (Heavy investment regression guard)**: Given `Heavy.produce_cost == 7`, `Heavy.move_cost == 3`, injected `attack_cost == 2` / When summed with a 1-tile move (under Heavy's cap of 2, no surcharge) / Then `7 + 3 + 2 == 12 > 10`. Edge: pure arithmetic trip-wire if anyone retunes any of the three costs.
- **Config smoke-check**: Given `UnitConfig.soft_move_penalty_x10` loaded from `.tres` (default 20) / When `surcharge_for(move_cost)` for each VS unit / Then matches the Edge-Cases worked examples (Scout 2, Heavy 6).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/unit_cost_fields_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`move_cost`/`soft_move_cap`), Story 002 (`tiles_moved_this_turn`), Story 003 (`reset_turn_flags` zeroes the counter).
- Unlocks: Movement epic (hard dep: reads `move_cost`+`soft_move_cap`+`SOFT_MOVE_PENALTY`+`tiles_moved_this_turn`); AP Economy integration.
