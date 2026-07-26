# Story 007: Faction Identity Read-Sites — effective_produce_cost / effective_move_cost

> **Epic**: Unit System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Faction identity modifier framework
**Secondary ADRs**: ADR-0007 (base cost fields).
**ADR Decision Summary**: Faction deltas fold into a closed set of domains at read-sites via `effective_X(state, ..., player)` functions; under the Neutral default every `effective_X == base_X` exactly; combat stats are identity-locked (not folded).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: "Under Neutral, `effective_X == base_X` must hold exactly for every domain (regression-pinned by a parametrized test)" — source: ADR-0012
- Required: "Every `effective_X` takes `player` as an explicit argument so the AI reads faction-correct values at the same call sites" — source: ADR-0012
- Required: "Faction delta lookup keyed by Resource-reference `type` identity, never string/enum" — source: ADR-0012

---

## Acceptance Criteria

- [ ] **GIVEN** the Neutral faction is active, **WHEN** `effective_produce_cost`/`effective_move_cost` are computed for any type, **THEN** they equal base exactly (no-op under Neutral) — parametrized across all 4 types.
- [ ] **GIVEN** a faction with a `FactionUnitDelta` for a type, **WHEN** the effective cost is computed, **THEN** `base + delta`, floored (`max(1, ...)` produce cost; `max(MIN_MOVE_COST, ...)` move cost) — never below floor even with a large negative delta.
- [ ] **GIVEN** combat stats (`attack`/`defense`/`attack_range`) are read for any unit, **THEN** they remain faction-identity-locked (unaffected by deltas) — only cost/mobility fold.

---

## Implementation Notes

*Derived from ADR-0012 guidelines:*

- `effective_produce_cost(state, unit_type, player) = max(1, base_produce_cost(type) + (d.cost_delta if d else 0))`; `effective_move_cost(state, unit_type, player) = max(MIN_MOVE_COST, base_move_cost(type) + (d.move_cost_delta if d else 0))`.
- `d = Faction.unit_delta(faction, type)` — linear scan over a roster-sized `Array[FactionUnitDelta]`, keyed by Resource-reference `type` identity (never string/enum).
- Reuse existing `MIN_MOVE_COST` floor (GDD Dependencies: "already Approved — no new floor owed").
- **No-op under Neutral is the load-bearing regression test** — parametrized across all 4 types × 2 domains.
- Combat stats explicitly NOT folded here (faction-identity.md CR-6).

---

## Out of Scope

- Faction Identity epic: `FactionDef` schema, `Factions` registry, `FactionUnitDelta` authoring, any tuned non-Neutral delta values (asymmetry prototype, deferred).

---

## QA Test Cases

- **AC-1 (Neutral no-op)**: Given `Factions.NEUTRAL` (empty deltas) / When computed for each of 4 types × 2 domains / Then equals base for all 8. Edge: parametrize across all types.
- **AC-2 (delta fold + floor)**: Given a test-built `FactionDef` with `FactionUnitDelta{type: Trooper, cost_delta: -10}` / When `effective_produce_cost(Trooper)` / Then `max(1, 4-10) == 1`, never ≤0. Edge: `cost_delta: +3` → `7`, no ceiling.
- **AC-3 (combat stats locked)**: Given a faction with (test-only) attempted combat deltas / When `effective_attack`/`effective_defense`/`attack_range` are read / Then unaffected — guards that no refactor routes combat stats through this story's functions.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/faction_read_sites_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`base_produce_cost`/`base_move_cost`); Faction Identity epic's `FactionDef`/`Factions` (cross-epic — write against a minimal Neutral-only stub if Faction lands later).
- Unlocks: Faction Identity asymmetry prototype; AI epic (reads `effective_X` at the same sites).
