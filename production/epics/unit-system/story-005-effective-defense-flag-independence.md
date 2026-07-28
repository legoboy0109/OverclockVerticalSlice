# Story 005: effective_defense + Two-Flag Independence Proof

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-006` (defense half), `TR-unit-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Data-driven entity/stat schema
**Secondary ADRs**: ADR-0010 (Combat's damage formula consumes `effective_defense`).
**ADR Decision Summary**: Same live-fold pattern as `effective_attack`; the Attack-Tech and Defense-Tech flags act **independently** — this story owns the regression guard that they never re-couple.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: "Defense-tech bonus read from Research config at call time, never hardcoded" — source: ADR-0007/0018
- Required: "Reads `state.per_player[owner].has_defense_tech`" — source: ADR-0001

---

## Acceptance Criteria

- [ ] **GIVEN** each type, **WHEN** `effective_defense` reads `base_defense`, **THEN** it is 0 (the un-researched branch input).
- [ ] **GIVEN** an owner without / with Defense Tech, **WHEN** `effective_defense` is computed, **THEN** `base_defense` (0) / `base_defense + DEFENSE_TECH_BONUS` respectively — bonus from Research config, not hardcoded.
- [ ] **GIVEN** `has_attack_tech = true` AND `has_defense_tech = false`, **WHEN** both are computed, **THEN** `effective_attack` bonused AND `effective_defense` base-only; **AND** with the flags reversed, `effective_defense` bonused AND `effective_attack` base-only — proving flag independence.
- [ ] **GIVEN** **both** flags true, **WHEN** both are computed, **THEN** both bonuses apply simultaneously — neither suppresses the other.
- [ ] **GIVEN** an instance created before research, **WHEN** the Defense-Tech flag flips true, **THEN** a later `effective_defense` returns `base_defense + DEFENSE_TECH_BONUS` (live).

---

## Implementation Notes

*Derived from ADR-0007 guidelines:*

- Formula: `effective_defense(unit) = unit.base_defense + (owner_has_defense_tech ? DEFENSE_TECH_BONUS : 0)`. `base_defense` = `UnitTypeDef.defense` (0 for all VS units).
- Reads `state.per_player[unit.owner].has_defense_tech` (ADR-0001).
- **This story owns the cross-flag independence AC** — the GDD calls it out: "a regression that re-couples the flags fails this AC." Test both flags in isolation AND combined — the highest-value regression guard in the formula pair.
- `DEFENSE_TECH_BONUS` from Research config, never hardcoded (mirror Story 004).
- Consumed by Combat's `damage_formula` `defense(defender)` term (ADR-0010) — no Combat change (term already generic).

---

## Out of Scope

- Story 004: `effective_attack`'s own base-case coverage (reused here only for the cross-check).
- Combat epic: the damage formula itself.

---

## QA Test Cases

- **AC-1 (base_defense input)**: smoke-confirm `UnitTypeDef.defense == 0` flows into the un-researched branch.
- **AC-2 (researched/un-researched)**: Given `has_defense_tech = false` → `0`; given `true` with injected `DEFENSE_TECH_BONUS` → `0 + bonus`. Edge: config-injection test as in Story 004 AC-2.
- **AC-3 (independence, attack-only)**: `has_attack_tech = true`, `has_defense_tech = false` → attack bonused, defense base.
- **AC-3b (independence, defense-only)**: reversed → defense bonused, attack base. Edge: **must run both directions** — the core regression guard.
- **AC-4 (both flags)**: both true → both bonuses apply, neither zeroes the other.
- **AC-5 (live flip)**: same live pattern as Story 004 AC-3, for the defense flag.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/effective_defense_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 004 (shares the live/config-injection pattern; independence AC needs both formulas present).
- Unlocks: Combat epic damage formula.

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 5/5 passing (8 tests)
**Deviations** (all ADVISORY):
- Reads `unit.type.defense` (the real ADR-0007 schema, 0 for all VS units) rather than the story's `base_defense` wording.
- Same forward-declared Research seam as Story 004: the Defense-Tech magnitude is read at call time via `Research.defense_tech_bonus()` (never hardcoded); the gate (`has_defense_tech`) read directly from `PlayerState`. The real Research epic implements the accessor later (ADR-0007/0018 TechDef-magnitude gap already logged as tech debt from Story 004 — no new entry).
- Typed `unit: UnitState`; structure-defense generality deferred to Combat wiring.
**Test Evidence**: Logic — `tests/unit/effective_defense_test.gd` (8 tests: base_defense=0 all types; un-researched/researched; tracks-injected-not-hardcoded; **flag independence both directions** with distinct magnitudes 2≠3 so cross-contamination is unambiguous; both-flags-true; live defense-flag flip). Full suite 246/246 PASS.
**Code Review**: Complete — `/code-review` APPROVED (godot-gdscript-specialist, CLEAN; flag independence verified at the CODE level — `_attack_tech_bonus`/`_defense_tech_bonus` are separate statics, folds read disjoint state, no aliasing; the both-directions tests confirmed non-trivially-passable against the classic re-coupling failure modes).

**Files delivered**:
- `src/core/unit/unit.gd` (appended `Unit.effective_defense`)
- `tests/helpers/stubs/research_stub.gd` (added forward-declared `defense_tech_bonus()` + setter + reset)
- `tests/unit/effective_defense_test.gd`
