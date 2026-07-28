# Story 004: effective_attack — Live Research-Tech Fold

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

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

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 3/3 passing (4 tests)
**Deviations** (all ADVISORY):
- Reads `unit.type.attack` (the real ADR-0007 schema) rather than the story's `unit.base_attack` Implementation-Notes wording.
- **Bonus source seam** (user-approved 2026-07-26): `RESEARCH_ATK_BONUS` magnitude read at call time via the forward-declared `Research.attack_tech_bonus()` accessor (mirrors the existing `Research.economy_tech_income_bonus` pattern; the `Research` test stub was extended with it). The gate (`has_attack_tech`) is read directly from `PlayerState` by `effective_attack`, per the control-manifest. Never hardcoded — the real Research epic implements the accessor (reading the TechDef magnitude) later.
- Typed `unit: UnitState` for the VS roster; widening to `EntityState` for a Defensive Structure's attack is deferred to Combat-epic wiring (no structure uses Attack Tech in the VS).
- **Cross-ADR gap logged** (`docs/tech-debt-register.md`): ADR-0018 says tech-effect magnitudes live on `TechDef`, but ADR-0007's `TechDef` has no magnitude field — Research epic must reconcile.
**Test Evidence**: Logic — `tests/unit/effective_attack_test.gd` (4 tests: un-researched base w/ injected-but-ungated bonus, researched base+bonus, tracks-injected-value-not-hardcoded, live flag-flip on same instance). Full suite 238/238 PASS.
**Code Review**: Complete — `/code-review` APPROVED (godot-gdscript-specialist, CLEAN; formula matches ADR-0010, forward-declaration seam sound + cleanly upgradable, not-hardcoded + live-computation genuinely proven by the tests, shared-stub extension non-disruptive).

**Files delivered**:
- `src/core/unit/unit.gd` (appended `Unit.effective_attack`)
- `tests/helpers/stubs/research_stub.gd` (added forward-declared `attack_tech_bonus()` + setter + reset)
- `tests/unit/effective_attack_test.gd`
