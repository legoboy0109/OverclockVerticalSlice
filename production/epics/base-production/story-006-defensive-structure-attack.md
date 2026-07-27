# Story 006: Defensive Structure Attack (AP / Flag / Immobility Slice)

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

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
- [ ] **GIVEN** an **Under-Construction** Defensive Structure (`has_attacked` false, ≥1 AP, a legal target in range), **WHEN** it attacks, **THEN** rejected, no AP spent, `has_attacked` stays false — only a **Completed** structure fires (closes the BP-002 attack-inertness tech-debt: a fresh U/C Defensive Structure is inert for ATTACK).
- [ ] **GIVEN** any Defensive Structure, **THEN** it has no legal move action ever (immobility is structural — no move verb exists for structures).

*Design-rule toggle:*
- [ ] **GIVEN** a Completed Defensive Structure whose owner has researched Attack Tech, **THEN** its `attack` used by Combat is **unmodified** (4, not 5) — structure attack is **not** research-buffed in the VS.

---

## Implementation Notes

*Derived from ADR-0010 (structure-as-attacker) and ADR-0017 (config):*

- Combat's `attack()` already accepts a `StructureState` attacker (shipped in the Combat epic against stubs). This story wires the **real** `StructureState` (Story 001 schema) as the attacker and verifies the B&P-owned cost/flag/immobility slice: `attack()` spends `defensive_attack_cost` (=1) from `BaseProductionConfig`, gated on `has_attacked == false`; on success `has_attacked → true`. The attacker branch uses `is StructureState` (never `get_class()`).
- **Under-Construction attack-inertness (BP-002 closure — REQUIRES a code fix, cross-epic):** `combat.gd`'s `validate` (the `elif attacker is StructureState:` branch, ≈ lines 424–426) today gates only on `has_attacked`, **not** on `build_status`. A crafted `AttackAction` with an Under-Construction Defensive Structure attacker would wrongly pass validation (AI candidate enumeration could reach this). Add a `build_status == COMPLETED` gate to that branch: `if attacker.build_status != StructureState.BuildStatus.COMPLETED: return Action.Reason.NOT_COMPLETED` (reuse the existing `NOT_COMPLETED` reason from produce), checked before/alongside the `has_attacked` check so a U/C structure is rejected with no AP spent and `has_attacked` untouched. **This edits `src/core/combat/combat.gd` — a Combat-epic file (Complete)** — a deliberate cross-epic gap-fill of the shared structure-attacker path; flag it in the dev-story summary and code-review. Do not re-implement Combat's targeting/counter, only add this one operational-status gate.
- **Targeting legality + the free uncosted counter are Combat's** (ADR-0010): the counter fires at most once, non-recursively, free (no AP, no `has_attacked`), only when the defender survived and has `can_counterattack == true`. Cross-reference Combat's structure-attacker Pure-Logic ACs — do not re-implement them here.
- **Immobility is structural**: no move verb exists for structures. The AC asserts there is no legal move action ever for a Defensive Structure — verify by the absence of a move path, not a runtime "reject move" guard.
- **Structure attack is not research-buffed** (Open Question, OFF in VS): the Defensive Structure's `attack` (4) is the `effective_attack` term Combat reads; Attack Tech buffs units only. The toggle AC guards that no refactor routes structure attack through the unit research-buff fold (`effective_attack` for a structure stays its flat `type.attack`).

---

## Out of Scope

- Combat's targeting legality (DIRECT range/line-of-fire) and damage formula — Combat epic (Complete); cross-referenced only.
- The free uncosted counter mechanics — Combat epic (Complete); this story does not test counter behavior (the AP/flag slice only).
- Structure destruction / HQ win-hook — Story 007.
- The real end-to-end range-2 DIRECT fire + real counter via `apply_action` — Story 010 (Integration).

**In scope (do not skip):** the one-line `build_status == COMPLETED` operational-status gate in `src/core/combat/combat.gd`'s structure-attacker `validate` branch (see Implementation Notes) — closes the BP-002 attack-inertness half. This is the only `combat.gd` change; do not otherwise modify the Combat pipeline.

**Performance:** no perf impact expected — the added gate is one O(1) `build_status` comparison in the existing `validate` path; the rest of the story is test-authoring against already-shipped O(1) combat logic.

---

## QA Test Cases

- **AC-fire-cost-flag (Rule 8)**: Given a Completed Defensive Structure (`has_attacked` false), ≥1 AP, a fixture legal target in range / When it fires / Then exactly **1** AP spent (not 2) and `has_attacked` → true. Edge: cost is `defensive_attack_cost` (1), strictly below unit `attack_cost` (2).
- **AC-already-attacked**: Given `has_attacked` true / When it attacks again / Then rejected, no AP spent.
- **AC-under-construction-inert (BP-002 attack half)**: Given an Under-Construction Defensive Structure (`has_attacked` false, ≥1 AP, legal target in range) / When it attacks / Then rejected (`NOT_COMPLETED`), no AP spent, `has_attacked` stays false — only a Completed structure fires.
- **AC-immobility**: Given any Defensive Structure / Then no legal move action ever (structural — no move verb).
- **AC-attack-tech-no-buff (toggle regression)**: Given a Completed Defensive Structure whose owner has Attack Tech / Then its Combat `attack` is unmodified (4, not 5) — structure attack not research-buffed in the VS.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/defensive_structure_attack_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/base-production/defensive_structure_attack_test.gd` (5 tests, passing)

---

## Dependencies

- **Depends on**: Story 001 (real `StructureState` + Defensive Structure template + `BaseProductionConfig.defensive_attack_cost`) + Combat epic (Complete — the structure-as-attacker `attack()` pipeline and counter; this story adds one `build_status` gate to its `validate`, a cross-epic gap-fill).
- **Unlocks**: Story 008 (determinism covers structure-attack), Story 010 (integration fires at real range 2 with a real counter).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 5/5 passing (4 story ACs + the added BP-002 U/C-attack-inertness AC; all COVERED)
**Deviations**: All ADVISORY / documented cross-epic — (1) modified `src/core/combat/combat.gd` (Combat epic, Complete) to add the `build_status == COMPLETED` gate to the structure-attacker `validate` branch (the in-scope cross-epic gap-fill that fixed a real latent bug: a U/C Defensive Structure could previously fire); (2) migrated 2 combat test files (`destroy_entity_test`/`counterattack_test` structure-attacker fixtures → `build_status = COMPLETED`), required by the gate, verified behavior-preserving; (3) reused the existing `NOT_COMPLETED` Reason.
**Test Evidence**: Logic — `tests/unit/base-production/defensive_structure_attack_test.gd` (5 tests). Full suite 456/456, exit 0.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist CLEAN, gate + fixture-migration verified; qa-tester found + I fixed one BLOCKING false-green in the attack-tech-no-buff test — pinned the Research bonus + added a differential UNIT control [unit buffed to 7, structure stays 4] + before/after_test isolation; hardened the immobility test to prove the structure occupies the tile).
**Tech debt**: BP-002 attack-inertness RESOLVED here (BP-002 now fully closed — production half by Story 004, attack half here). BP-006 logged (a U/C structure *defender* can still free-counter — no gate on the counter path; out of scope, owed a GDD/ADR clarification).
