# Story 006: Defensive Structure Attack (AP / Flag / Immobility Slice)

> **Epic**: Base & Production
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/base-production.md` — Core Rule 8 (Defensive Structure attack); Edge Cases "Defensive Structure"; the "Defensive Structure (Rule 8, pure slice)" ACs; the design-rule toggle AC that Attack Tech does NOT buff structure attack.
**Requirement**: `TR-baseprod-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat resolution (structure-as-attacker path) + ADR-0017 (`defensive_attack_cost` B&P-owned config)
**Secondary ADRs**: ADR-0006 (`AP.spend`), ADR-0007 (structure `attack`/`attack_range`/`can_counterattack` fields).
**ADR Decision Summary**: A single Combat pipeline handles an attacker that is a `UnitState` OR a `StructureState` (Defensive Structure); only AP cost differs — `defensive_attack_cost` is B&P-owned config (=1, < unit `attack_cost` 2) read cross-system by Combat. The Defensive Structure fires through Combat's `attack()`, gated on `has_attacked == false`, spending exactly `defensive_attack_cost`. It is immobile (no move action exists for structures). Targeting legality, the damage formula, and the free uncosted counter are **Combat's** — cross-referenced, not duplicated here. Structure attack is not research-buffed in the VS.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `is` (script-class inheritance check) is the correct idiom for the `StructureState`-vs-`UnitState` attacker branch (distinct from the banned `get_class()` string dispatch). No physics for targeting/range — deterministic integer/grid logic. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A single Combat pipeline must handle an attacker that is a `UnitState` OR a `StructureState` (Defensive Structure); only AP cost differs (`defensive_attack_cost` is B&P-owned config read cross-system by Combat)" — source: ADR-0010/ADR-0017
- Required: "The counter step must fire at most once, non-recursively … only when the defender survived and has `can_counterattack == true`; counters are free (no AP, no `has_attacked`)" — source: ADR-0010
- Required: "`effective_attack(state, entity)` must be a forward-declared Unit-owned contract; Combat must call it and never touch Research state directly" — source: ADR-0010
- Forbidden: "Never use the physics engine … for combat targeting, line-of-fire, or range" — source: ADR-0010
- Guardrail: "`defensive_attack_cost` is B&P-owned; read cross-system by Combat to price a Defensive Structure's fire (< unit `attack_cost` 2)" — source: ADR-0017 D6

> **Cross-reference note**: Targeting legality (DIRECT range/line-of-fire) and the free uncosted counter are **Combat's** Pure-Logic ACs — see `design/gdd/combat-resolution.md`'s "Structure as attacker (Defensive Structure)" ACs and the shipped Combat epic (Story 005/006). This story covers only the B&P-owned slice: AP cost, `has_attacked` flag, and structural immobility. Do NOT duplicate Combat's targeting/counter tests.

---

## Acceptance Criteria

*Defensive Structure (Rule 8, pure slice — AP/flag/immobility only):*
- [ ] **GIVEN** a Completed Defensive Structure (`has_attacked` false) with ≥1 AP firing at a fixture legal target in range, **THEN** exactly **1** AP spent (not 2) and `has_attacked` → true.
- [ ] **GIVEN** `has_attacked` true, **WHEN** it attacks again, **THEN** rejected, no AP spent.
- [ ] **GIVEN** any Defensive Structure, **THEN** it has no legal move action ever (immobility is structural — no move verb exists for structures).

*Design-rule toggle:*
- [ ] **GIVEN** a Completed Defensive Structure whose owner has researched Attack Tech, **THEN** its `attack` used by Combat is **unmodified** (4, not 5) — structure attack is **not** research-buffed in the VS.

---

## Implementation Notes

*Derived from ADR-0010 (structure-as-attacker) and ADR-0017 (config):*

- Combat's `attack()` already accepts a `StructureState` attacker (shipped in the Combat epic against stubs). This story wires the **real** `StructureState` (Story 001 schema) as the attacker and verifies the B&P-owned cost/flag/immobility slice: `attack()` spends `defensive_attack_cost` (=1) from `BaseProductionConfig`, gated on `has_attacked == false`; on success `has_attacked → true`. The attacker branch uses `is StructureState` (never `get_class()`).
- **Targeting legality + the free uncosted counter are Combat's** (ADR-0010): the counter fires at most once, non-recursively, free (no AP, no `has_attacked`), only when the defender survived and has `can_counterattack == true`. Cross-reference Combat's structure-attacker Pure-Logic ACs — do not re-implement them here.
- **Immobility is structural**: no move verb exists for structures. The AC asserts there is no legal move action ever for a Defensive Structure — verify by the absence of a move path, not a runtime "reject move" guard.
- **Structure attack is not research-buffed** (Open Question, OFF in VS): the Defensive Structure's `attack` (4) is the `effective_attack` term Combat reads; Attack Tech buffs units only. The toggle AC guards that no refactor routes structure attack through the unit research-buff fold (`effective_attack` for a structure stays its flat `type.attack`).

---

## Out of Scope

- Combat's targeting legality (DIRECT range/line-of-fire) and damage formula — Combat epic (Complete); cross-referenced only.
- The free uncosted counter mechanics — Combat epic (Complete); this story does not test counter behavior (the AP/flag slice only).
- Structure destruction / HQ win-hook — Story 007.
- The real end-to-end range-2 DIRECT fire + real counter via `apply_action` — Story 010 (Integration).

---

## QA Test Cases

- **AC-fire-cost-flag (Rule 8)**: Given a Completed Defensive Structure (`has_attacked` false), ≥1 AP, a fixture legal target in range / When it fires / Then exactly **1** AP spent (not 2) and `has_attacked` → true. Edge: cost is `defensive_attack_cost` (1), strictly below unit `attack_cost` (2).
- **AC-already-attacked**: Given `has_attacked` true / When it attacks again / Then rejected, no AP spent.
- **AC-immobility**: Given any Defensive Structure / Then no legal move action ever (structural — no move verb).
- **AC-attack-tech-no-buff (toggle regression)**: Given a Completed Defensive Structure whose owner has Attack Tech / Then its Combat `attack` is unmodified (4, not 5) — structure attack not research-buffed in the VS.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/defensive_structure_attack_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (real `StructureState` + Defensive Structure template + `BaseProductionConfig.defensive_attack_cost`) + Combat epic (Complete — the structure-as-attacker `attack()` pipeline and counter).
- **Unlocks**: Story 008 (determinism covers structure-attack), Story 010 (integration fires at real range 2 with a real counter).
