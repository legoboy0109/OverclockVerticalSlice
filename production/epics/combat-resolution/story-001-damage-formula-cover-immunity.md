# Story 001: Damage Formula, Structure Cover-Immunity & Damage Preview

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-001`, `TR-combat-002`, `TR-combat-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: `Combat` is a static utility class (`class_name Combat extends RefCounted`, no instance state). The one damage formula is `damage = max(MIN_DAMAGE, effective_attack(state, attacker) − cover_reduction(state, defender) − defense(defender))`, where `cover_reduction` is `COVER_DR` only when the defender is a `UnitState` on an `is_cover` tile — **always 0 for a `StructureState` defender** (structures are cover-immune). `MIN_DAMAGE`/`COVER_DR`/`ATTACK_COST` live in a dedicated `CombatConfig` Resource (`gameplay_config_storage` pattern, mirroring `EconomyConfig`/`UnitConfig`), loaded once via a thin Balance-style Autoload — never on `GameState`, never GDScript `const`s. `preview_damage()` shares this exact function with `apply()` — it is not a separate formula.

**Secondary ADRs**: ADR-0007 (Entity/Stat Schema — supplies `defense` on `UnitTypeDef`/`StructureTypeDef` and the `UnitState`/`StructureState` type distinction the `cover_reduction` branch keys on), ADR-0003 (Deterministic Simulation — integer-only math, no float, no RNG)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: Pure integer arithmetic and `RefCounted` static-utility class — no post-cutoff API surface (ADR-0010 Engine Compatibility: godot-specialist-confirmed, no blocking issues). No physics/raycast APIs are used or should ever be reached for here (control-manifest forbidden pattern: never use `PhysicsServer2D`/`Area2D`/`RayCast2D`/Jolt for combat).

**Control Manifest Rules (this layer)**:
- Required: `Combat` must be a static utility class (`class_name Combat extends RefCounted`, no instance state); all entry points take `state` explicitly — source: ADR-0010
- Required: Damage formula must be `max(MIN_DAMAGE, effective_attack(state, attacker) - cover_reduction(state, defender) - defense(defender))`, with `cover_reduction` always 0 for `StructureState` — source: ADR-0010
- Required: `MIN_DAMAGE`/`COVER_DR` must live in a `CombatConfig` Resource, never on `GameState` — source: ADR-0010
- Required: `effective_attack(state, entity)` must be a forward-declared Unit-owned contract; Combat must call it and never touch Research state directly — source: ADR-0010
- Forbidden: Never use the physics engine for combat targeting/damage — combat is deterministic integer/grid logic — source: ADR-0010
- Forbidden: Never hardcode tuning constants as GDScript `const`s — source: ADR-0006 (same discipline applies to `CombatConfig`)

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

- [ ] Heavy (atk 5) attacks a Sniper (hp 3, defense 0) on Plain → damage = 5, Sniper destroyed (destruction itself is out of scope — Story 005 — but the damage int must be correct and ≥ hp)
- [ ] Scout (atk 2, no cover/defense) attacks a Trooper (hp 6) → damage = 2
- [ ] Mitigation ≥ attack (Scout atk 2 vs a `defense 2` **unit** defender on Cover, `COVER_DR 1`) → damage clamps to `MIN_DAMAGE = 1`, never 0/negative
- [ ] Trooper (atk 3) vs a `defense 0` unit defender on Cover → damage = 2; the same Trooper vs the same unit defender off Cover → damage = 3
- [ ] atk 5 vs a `defense 2` unit defender, no cover → damage = 3; Sniper atk 6 vs a `defense 2` unit defender on Cover → damage = `6 − 1 − 2 = 3` (cover + defense stack additively for units)
- [ ] A researched Trooper (`effective_attack` fixture = 4) → damage = 4, not base 3
- [ ] A `defense 2` **structure** defender (HQ fixture) on a Cover tile attacked by atk 5 → damage = `max(1, 5 − 0 − 2) = 3` — cover contributes 0 for a structure, identical result on Cover or Plain
- [ ] The same `defense 2` structure on Cover attacked by atk 2 → damage = `max(1, 2 − 0 − 2) = 1` (floor), **not** `max(1, 2 − 1 − 2)` — proving the structure never reaches 3 mitigation
- [ ] An attacker standing on a Cover tile attacks a `defense 0` unit defender on Plain → damage equals the plain result — the attacker's own Cover tile has no effect on damage it deals
- [ ] For any legal attacker/target pair, `preview_damage(attacker, target)` queried before `attack()` is resolved returns an int that **exactly equals** the hp actually removed (post-cover, post-defense, post-research, min-1) — `preview_damage` is pure and never diverges from committed damage

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Create `src/core/combat/combat.gd` — `class_name Combat extends RefCounted`, no instance fields. This file will grow across Stories 002–007; this story lays down `damage()`/`preview_damage()` and the `CombatConfig` plumbing only. Do not add `legal_targets`/`attack` yet — those are later stories' scope.
- `damage(state: GameState, attacker: EntityState, defender: EntityState) -> int` — branches on **defender kind** for the cover term and the defense term, and on **attacker kind** for the attack term:
  ```gdscript
  static func damage(state: GameState, attacker: EntityState, defender: EntityState) -> int:
      var cover: int = CombatBalance.combat.cover_dr if (defender is UnitState and state.grid.is_cover(defender.position.x, defender.position.y)) else 0
      var def: int = Unit.effective_defense(state, defender) if defender is UnitState else defender.type.defense
      return max(CombatBalance.combat.min_damage, _effective_attack_for(state, attacker) - cover - def)

  # Attacker-kind branch, isolated in one private helper so Story 005 extends it in place
  # rather than re-opening damage(). This story's fixtures are unit-attacker-only; the
  # StructureState branch is defined now but only exercised once Story 005 lands.
  static func _effective_attack_for(state: GameState, attacker: EntityState) -> int:
      return Unit.effective_attack(state, attacker) if attacker is UnitState else attacker.type.attack
  ```
  - **Cover term** (TR-combat-002): `COVER_DR` only when the defender is a `UnitState` on an `is_cover` tile — **always 0 for a `StructureState` defender** (structures are cover-immune), enforced by the `defender is UnitState` guard. The `structure_state_stub.gd` test double, being a `StructureState`, correctly contributes `cover = 0` regardless of tile.
  - **Defense term**: read via `Unit.effective_defense(state, defender)` for a `UnitState` defender (this folds in the live Defense-Tech bonus, mirroring `effective_attack`'s Research seam — Unit System Story 005, already shipped). For a `StructureState` defender, read `defender.type.defense` directly (no Defense-Tech fold applies to structures). **Never read a bare `defender.defense`** — `defense` is a *template* field on `UnitTypeDef`/`StructureTypeDef` (ADR-0007), not a field on the entity itself; a bare read will not compile.
  - **Attack term**: `Unit.effective_attack(state, attacker)` (the forward-declared Unit-owned contract, already shipped at `src/core/unit/unit.gd`, Unit System Story 004) for a `UnitState` attacker; `attacker.type.attack` directly for a `StructureState` attacker. Isolated in `_effective_attack_for()` so Story 005's structure-attacker work is a no-op extension rather than a re-edit of `damage()`. `damage()`'s parameters stay typed to `EntityState` (not `UnitState`) so no signature change is needed when Story 005 exercises the structure branch.
- `preview_damage(state, attacker, target) -> int` is a one-line pass-through to `damage()` — it must call the exact same function `apply()` will later call (Story 004), never a re-derived/parallel formula. This is what makes the preview a guarantee, not an estimate (TR-combat-006).
- **`CombatConfig`** (`src/core/combat/combat_config.gd`): a dedicated `Resource` mirroring `EconomyConfig`/`UnitConfig` exactly:
  ```gdscript
  class_name CombatConfig
  extends Resource
  @export var min_damage: int = 1
  @export var cover_dr: int = 1
  @export var attack_cost: int = 2
  ```
  Load it via a new thin, logic-free Autoload (e.g. `CombatBalance`, mirroring `UnitBalance`/`Balance`) — do not add these fields onto `EconomyConfig`/`UnitConfig` (control-manifest: "never use one shared config Resource for all systems' tuning constants"). `attack_cost` is included in this Resource now even though it isn't consumed until Story 004, since it's Combat-owned tuning per ADR-0010's Key Interfaces (`CombatConfig: ATTACK_COST = 2, COVER_DR = 1, MIN_DAMAGE = 1`) and belongs in one place.
- Test fixtures: per the GDD's "Test doubles" note, inject `effective_attack` as a raw fixture value in this story's pure suite rather than re-deriving it from base + `RESEARCH_ATK_BONUS` — use `tests/helpers/stubs/research_stub.gd`'s existing `set_attack_tech_bonus`/`set_defense_tech_bonus` hooks (already shipped) to control the live-research fold deterministically, exactly as `effective_attack_test.gd`/`effective_defense_test.gd` already do.
- Structure fixtures: use `tests/helpers/stubs/structure_state_stub.gd` (already exists) — extend it with a `defense: int` field and a `type` stand-in if the stub doesn't already expose enough shape for a `defense 2` HQ fixture on a Cover tile. If extending the stub, keep the extension minimal (this story needs only `defense` and `position`) — do not add unrelated Base & Production fields (build_status, production, etc.) that belong to that epic.
- **Performance**: `damage()`/`preview_damage()` are O(1) integer arithmetic — a handful of comparisons, two forward-declared O(1) stat reads, and one `max()`. No loop, no allocation, no per-frame path (control-manifest Performance Guardrails: "`damage()`/`attack()` are O(1) integer work plus one tile-walk" — this story is the pure O(1) formula, with the tile-walk arriving in Story 002). No performance budget concern.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002/003: `legal_targets()`, `legal_targets_from()`, `blocked_reason()` — targeting is not this story's concern
- Story 004: `attack()`/`validate()`/`apply()`, AP spend, `has_attacked`
- Story 005: death/removal, `destroy_entity()`, structure-as-attacker cost branching
- Story 006: counterattack
- Story 007: determinism/clone-isolation assertions specific to the full pipeline (this story's own fixture-level determinism — same inputs, same output — is implicit in a pure function and needs no dedicated test)

---

## QA Test Cases

*Given/When/Then specs drafted directly from the GDD's Acceptance Criteria (lean review mode — qa-lead spawn skipped per `production/review-mode.txt`).*

- **AC-1 (base formula)**: Given a Heavy (atk 5 fixture) and a Sniper (defense 0), When `damage()` resolves, Then result = 5.
  Edge cases: attacker/defender types swapped (Scout atk 2 vs Trooper) → damage = 2.

- **AC-2 (min-damage floor)**: Given mitigation ≥ attack (atk 2, unit defender `defense 2` on Cover `COVER_DR 1`), When `damage()` resolves, Then result clamps to 1, never 0 or negative.
  Edge cases: mitigation exactly equal to attack (0 result before floor); mitigation far exceeding attack (large negative before floor) — both must clamp to exactly 1.

- **AC-3 (cover reduces unit damage)**: Given a Trooper (atk 3) vs a `defense 0` unit defender, When on Cover vs off Cover, Then damage = 2 (Cover) vs 3 (Plain).
  Edge cases: none — this is the binary Cover on/off case.

- **AC-4 (cover + defense stack for units)**: Given atk 5 vs `defense 2` unit defender no cover → damage 3; Given Sniper atk 6 vs `defense 2` unit defender on Cover → damage 3 (`6-1-2`).
  Edge cases: verify additive stacking, not a max/min of the two terms.

- **AC-5 (live research fold)**: Given a researched Trooper (`effective_attack` fixture = 4, via `Research.set_attack_tech_bonus`), When `damage()` resolves against a defense-0 unit, Then damage = 4, not base 3.
  Edge cases: fixture must come from the injected `effective_attack` value, never re-derived from base+bonus inside the test.

- **AC-6 (structure cover-immunity)**: Given a `defense 2` structure defender (HQ fixture) on a Cover tile attacked by atk 5, When `damage()` resolves, Then damage = `max(1, 5-0-2) = 3` — identical to the same structure on Plain.
  Edge cases: attacked by a LOW-attack piece (atk 2) on Cover → damage = 1 (floor), proving the structure never reaches 3 mitigation (would be `max(1, 2-1-2)=1` too by coincidence at this floor — the distinguishing assertion is that a mid-attack piece, e.g. atk 4, yields `max(1,4-0-2)=2` on both Cover and Plain, never `max(1,4-1-2)=1` on Cover).

- **AC-7 (attacker-on-cover no offensive bonus)**: Given an attacker standing on a Cover tile attacks a `defense 0` unit defender on Plain, When `damage()` resolves, Then result equals the plain-vs-plain damage — the attacker's tile never affects `damage()`.
  Edge cases: verify by asserting the attacker's own `position`/cover status is never read by `damage()` — only the defender's tile matters.

- **AC-8 (preview_damage == committed damage)**: Given any legal attacker/target pair fixture, When `preview_damage(attacker, target)` is called, Then it returns the exact same int as a direct `Combat.damage(state, attacker, target)` call on the same inputs — proving `preview_damage` is a pure pass-through, not a parallel formula.
  Edge cases: call `preview_damage` twice in a row with no state mutation between calls → identical result both times (purity).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/damage_formula_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Unit System Stories 004/005 (`Unit.effective_attack`/`Unit.effective_defense`, DONE), ADR-0007 schema fields (DONE — confirmed present on `UnitTypeDef`)
- Unlocks: Story 002, Story 003, Story 004 (all read `Combat.damage()`/`preview_damage()` or extend `combat.gd`)

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 10/10 passing (0 deferred) — all covered by `tests/unit/combat/damage_formula_test.gd` (15 test functions), full suite 261/261 green.
**Deviations**: One ADVISORY, documented, not a defect — `damage()` reads `Unit.effective_defense()` / `defender.type.defense` rather than ADR-0010's pseudocode `defender.defense`, which is correct conformance to ADR-0007 (defense is a template field, not an entity field). Confirmed by godot-gdscript-specialist + qa-tester.
**Optional coverage notes (non-blocking, not logged as tech debt)**: AC-8 purity test verifies output determinism, not full state-snapshot statelessness (implementation is trivially side-effect-free — no assignment statements); no explicit zero-attack (`max(1,0-0-0)`) boundary test; the `_effective_attack_for()` `StructureState`-attacker branch is implemented but uncovered — coverage deferred to Story 005 by design (structure-as-attacker is that story's scope).
**Test Evidence**: Logic — `tests/unit/combat/damage_formula_test.gd` (BLOCKING gate satisfied).
**Code Review**: Complete — `/code-review` run this session, verdict APPROVED (godot-gdscript-specialist CLEAN, qa-tester TESTABLE, 0 required changes).
