# Story 004: effective_attack — Live Research-Tech Fold

> **Epic**: Unit System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-006` (attack half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Data-driven entity/stat schema
**Secondary ADRs**: ADR-0012 (read-site fold pattern), ADR-0010 (Combat consumes `effective_attack`).
**ADR Decision Summary**: Effective stats are computed **live** at read sites from base template + owner tech flags; the bonus constant is owned by Research config, never hardcoded in Unit code.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff — integer read/compute.

**Control Manifest Rules (this layer)**:
- Required: "`effective_attack(state, entity) -> int` is a Unit-owned contract Combat calls and never re-implements" — source: ADR-0010
- Required: "Tech-bonus constants are read from Research config at call time, never hardcoded in Unit code" — source: ADR-0007/0018
- Required: "Reads `state.per_player[owner].has_attack_tech` (ADR-0001 field, sole-writer Research)" — source: ADR-0001

---

## Acceptance Criteria

- [ ] **GIVEN** an un-researched owner, **WHEN** `effective_attack` is computed per type, **THEN** base (Scout 2, Trooper 3, Heavy 5, Sniper 6).
- [ ] **GIVEN** an owner with Attack Tech, **WHEN** `effective_attack` is computed, **THEN** `base + RESEARCH_ATK_BONUS`, where the bonus is read from Research config, not hardcoded.
- [ ] **GIVEN** an instance created before its owner researches, **WHEN** the owner's Attack-Tech flag flips to true (same instance), **THEN** a later `effective_attack` call returns `base + RESEARCH_ATK_BONUS` — proving live computation, not baked at construction.

---

## Implementation Notes

*Derived from ADR-0007 / ADR-0010 guidelines:*

- Formula: `effective_attack(unit) = unit.base_attack + (owner_has_attack_tech ? RESEARCH_ATK_BONUS : 0)`.
- Signature `effective_attack(state: GameState, entity) -> int` (ADR-0010 forward-declaration) — reads `state.per_player[unit.owner].has_attack_tech`.
- `RESEARCH_ATK_BONUS` **read from Research config at call time**, never hardcoded — the load-bearing AC. If Research's config isn't landed, inject a bonus-source test double (do NOT hardcode `+1`).
- Computed **live** every call — no caching/baking (AC-3's point).
- Home it on the `Unit` utility (Story 003 shape) or the ADR-0010-canonical location — confirm during Combat-epic wiring.

---

## Out of Scope

- Story 005: `effective_defense` + two-flag independence.
- Story 007: faction cost folds (`effective_produce_cost`/`effective_move_cost`).

---

## QA Test Cases

- **AC-1 (un-researched base)**: Given owner `has_attack_tech = false` / When computed for Scout/Trooper/Heavy/Sniper / Then 2/3/5/6.
- **AC-2 (researched, config-sourced)**: Given `has_attack_tech = true` and an injected `RESEARCH_ATK_BONUS` test double (not `+1`) / When computed / Then `base + injected_bonus`. Edge: re-run with a different injected value (e.g. +3) — output must track it (catches hardcoding).
- **AC-3 (live flip)**: Given one instance created while `has_attack_tech = false` (recorded as base) / When the owner's flag flips true (no new unit) / Then a second call on the **same instance** returns `base + bonus`. Edge: note (comment) why no revert-test exists (Research flags permanent, ADR-0018).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/effective_attack_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`base_attack`), Story 002 (`UnitState.owner`); ADR-0001 `PlayerState.has_attack_tech` (landed); Research epic for the real `RESEARCH_ATK_BONUS` (test double until then).
- Unlocks: Combat epic damage formula (ADR-0010 consumes this).
