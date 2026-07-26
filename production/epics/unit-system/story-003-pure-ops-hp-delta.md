# Story 003: Unit-Owned Pure Operations — can_attack, reset_turn_flags, duplicate, apply_hp_delta

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-004`, `TR-unit-005`, `TR-unit-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Data-driven entity/stat schema
**Secondary ADRs**: ADR-0001 (`duplicate_deep()` clone pattern), ADR-0010 (Combat reads `can_attack`/`apply_hp_delta`), ADR-0008 (start-of-turn calls `reset_turn_flags`).
**ADR Decision Summary**: Unit-owned operations are pure static functions taking the entity explicitly; `duplicate()` uses `duplicate_deep()` (never hand-written copy); hp mutates only through one clamped entry point.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: Directly exercises ADR-0007's confirmed-but-guarded `duplicate_deep()`: `type` clones as a **shared reference** (`===`); `current_hp`/`position`/`has_attacked`/`tiles_moved_this_turn` clone **independently**. ADR-0007 Validation Criteria names this "the load-bearing perf assumption, made assertable" — the assertion lives here.

**Control Manifest Rules (this layer)**:
- Required: "Unit-owned ops are pure static functions on a `class_name Unit extends RefCounted` utility (mirrors `AP`/`Movement`/`Combat`)" — source: ADR-0007
- Required: "`apply_hp_delta` is the sole hp mutator; clamp `0 <= current_hp <= hp`" — source: ADR-0007 (TR-unit-005)
- Forbidden: "Never assign `unit.current_hp` directly outside `apply_hp_delta`" — source: ADR-0007
- Required: "`duplicate()` uses `duplicate_deep()`, never hand-written per-field copy" — source: ADR-0001

---

## Acceptance Criteria

- [ ] **GIVEN** a unit with `has_attacked == true`, **WHEN** `can_attack(unit)`, **THEN** `false`; **AND** with `has_attacked == false`, **THEN** `true`.
- [ ] **GIVEN** a unit with `has_attacked == true` and `tiles_moved_this_turn == 3`, **WHEN** `reset_turn_flags(unit)` is called on the bare instance, **THEN** `has_attacked` → `false` and `tiles_moved_this_turn` → `0` (pure per-instance; no Turn Manager object required).
- [ ] **GIVEN** unit A, **WHEN** `duplicate(A)` produces B and A's `current_hp`/`position`/`has_attacked`/`tiles_moved_this_turn` are each mutated, **THEN** B's are unchanged (and vice-versa, bidirectional). `owner`/`entity_id`/`type` compare equal across the clone (`type` shared by identity).
- [ ] **GIVEN** a unit at `current_hp == hp`, **WHEN** `apply_hp_delta(unit, +N)` (`N > 0`), **THEN** `current_hp` clamps at `hp` and never exceeds it.

---

## Implementation Notes

*Derived from ADR-0007 / ADR-0001 guidelines:*

- `can_attack(unit) -> bool`: pure, `return not unit.has_attacked`. Combat reads it (ADR-0010) but Unit owns/tests it (GDD Rule 2a).
- `reset_turn_flags(unit)`: `has_attacked = false`, `tiles_moved_this_turn = 0`. **Replaces** the stub `Unit.reset_turn_flags` that `GameState.start_turn()` step 2 (ADR-0008) already calls — same signature, so the call site needs zero change.
- `duplicate(unit) -> UnitState`: `duplicate_deep()` per ADR-0001/0007 (never hand-rolled). `type` stays shared (path-having preload'd Resource); mutable fields deep-copy independently (path-less `.new()` instances).
- `apply_hp_delta(unit, N)`: sole hp mutator (TR-unit-005), clamps `0 <= current_hp <= hp`. Implement the floor symmetrically (Combat depends on the `0` clamp) even though the AC only names the ceiling.
- All four are static functions on `class_name Unit extends RefCounted` — this also formally replaces the stub `Unit` utility (class_name collision, same as Story 002).

---

## Out of Scope

- Combat epic: hp-reaching-0 destruction / Grid removal (Story 008 tests the contract with a fake Grid).
- Stories 004/005: effective attack/defense.
- Movement epic: the `tiles_moved_this_turn` **writer** (this story owns only the reset).

---

## QA Test Cases

- **AC-1 (can_attack)**: Given `has_attacked = true` → `false`; given `false` → `true`. Edge: fresh unit returns `true`.
- **AC-2 (reset_turn_flags)**: Given a bare `UnitState` (no GameState) with `has_attacked = true`, `tiles_moved_this_turn = 3` / When `reset_turn_flags` / Then both reset. Edge: idempotent on an already-reset unit.
- **AC-3 (duplicate independence)**: Given A / When `B = duplicate(A)`, mutate A's four mutable fields / Then B unchanged; repeat mutating B / Then A unchanged. Assert `A.type === B.type`, `A.owner == B.owner`, `A.entity_id == B.entity_id`. Edge: independently mutate `position` and the flags on each side, no cross-talk.
- **AC-4 (apply_hp_delta clamp)**: Given `current_hp == hp` / When `apply_hp_delta(unit, +5)` / Then unchanged (ceiling). Edge: `apply_hp_delta(unit, -hp-10)` clamps at 0, never negative.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/unit_pure_ops_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`UnitState` schema).
- Unlocks: GS-003 `start_turn()` step-2 real-call migration; Combat epic (`can_attack`, `apply_hp_delta`, ADR-0010); AI epic (`clone` backs lookahead, ADR-0011).

---

## Completion Notes
**Completed**: 2026-07-26 (implemented jointly with Story 002)
**Criteria**: 4/4 passing
**Deviations** (ADVISORY — engine-forced, user-approved 2026-07-26):
- **`duplicate` → `clone`**: GDD Rule 2a and the TR-unit-003/004 registry text name the op `duplicate(unit)`, but GDScript reserves that name — a `class_name` script is itself a `Resource` with a built-in `Resource.duplicate(bool)`, so `Unit.duplicate(x)` resolves to the built-in and rejects the `UnitState` arg (confirmed at runtime). Renamed to `Unit.clone(unit)`, matching `GameState.clone()`. **Reconciliation owed**: update `design/gdd/unit-system.md` Rule 2a + TR-unit-003/004 registry text to say `clone` (logged in `docs/tech-debt-register.md`).
**Test Evidence**: Logic — `tests/unit/unit_ops_test.gd` (can_attack, reset_turn_flags, clone independence + shared `type` via a real `preload`d template, apply_hp_delta clamp). Full suite 198/198 PASS.
**Code Review**: Complete — `/code-review` APPROVED (godot-gdscript-specialist, CLEAN).

**Files delivered**:
- `src/core/unit/unit.gd` (`Unit extends RefCounted`: `can_attack`/`reset_turn_flags`/`clone`/`apply_hp_delta` static ops)
- `tests/unit/unit_ops_test.gd`
