# Story 006: Counterattack Resolution

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: After the primary hit and its death check, a **single** conditional counter fires iff the defender is still alive (`current_hp > 0`), the defender's type has `can_counterattack == true`, and the attacker is a legal target under the **defender's own** targeting profile/range (using `legal_targets`/the DIRECT-or-AREA rules exactly as if the defender were attacking). The counter deals the defender's own `damage()` (roles swapped) to the attacker, is **free** (no AP, does not set `has_attacked` on either side), and **never chains** — this is a structural property of the straight-line pipeline (one counter step per `apply()` call), not a runtime guard flag. If the counter kills the attacker, `destroy_entity()` fires for the attacker too.

**Secondary ADRs**: ADR-0007 (`can_counterattack` field, already present on `UnitTypeDef`/`StructureTypeDef`, default `false`)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: No post-cutoff API surface — plain conditional control flow.

**Control Manifest Rules (this layer)**:
- Required: The counter step must fire at most once, non-recursively (a structural property of the straight-line pipeline, not a runtime guard), only when the defender survived and has `can_counterattack == true`; counters are free (no AP, no `has_attacked`) — source: ADR-0010

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

- [ ] Each of the 4 VS units survives a hit → no counter fires (`can_counterattack` defaults false roster-wide)
- [ ] A `can_counterattack = true` defender survives and the attacker is within the defender's **own** range/profile → one free counter fires (no AP, sets neither unit's `has_attacked`)
- [ ] A `can_counterattack = true` defender is killed by the primary hit → it is removed before the counter step and **no counter fires**
- [ ] A `can_counterattack = true` defender survives but the attacker is **outside** its own range/profile (range-1 defender struck from range 3) → no counter
- [ ] A counter kills the attacker → the attacker is removed and **no counter-to-the-counter** occurs (structurally one counter step per `apply_action`)

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Extend `Combat.apply()` (Story 004/005's version) immediately after the primary death-check block:
  ```gdscript
  if target.current_hp > 0 and target.type.can_counterattack and _in_defenders_profile(state, target, attacker):
      var counter_dmg: int = damage(state, target, attacker)   # roles swapped
      _apply_damage_to(attacker, counter_dmg)                  # polymorphic — the attacker may be a StructureState (Story 005)
      if attacker.current_hp <= 0:
          events.append_array(state.destroy_entity(attacker.entity_id))
  ```
  This is the exact insertion point — after the primary death check, before `return events`. No `has_attacked` write and no `AP.spend` call anywhere in this block (free, per Rule 7). **Route the counter damage through `_apply_damage_to(attacker, counter_dmg)`, NOT `Unit.apply_hp_delta` directly** — Story 005 made the original attacker attacker-polymorphic (a Defensive Structure can attack), so when a counter swaps roles the *attacker* being damaged may be a `StructureState`; `Unit.apply_hp_delta` is typed to `UnitState` only and would crash on it. `_apply_damage_to` (Story 004's helper) already branches unit-vs-structure correctly — reuse it, exactly as the primary hit does.
- `_in_defenders_profile(state, defender, would_be_target) -> bool`: reuses `legal_targets(state, defender)` (Story 002/003's already-shipped query) and checks whether `would_be_target.entity_id` appears in that result set — i.e. "is the original attacker a legal target *for the defender*, evaluated from the defender's actual current position and its own `targeting_mode`/`attack_range`/`min_range`". This reuses the exact same targeting rules a defender's own attack would use — do not write a second, parallel range-check formula. Note the defender's position at counter-time is unchanged from when it was struck (no movement happens mid-`apply()`), so `legal_targets(state, target)` (no hypothetical-tile overload needed here) is sufficient.
- Non-recursion is structural: this block runs exactly once per `Combat.apply()` call, unconditionally after the primary hit's resolution — there is no loop, no recursive call back into `apply()`, and nothing re-invokes this same counter block for the counter's own damage. This satisfies "never chains" by the shape of the code, not by a boolean flag.
- `target.type.can_counterattack` — read directly off the defender's immutable template (`UnitTypeDef`/`StructureTypeDef`), never off a per-instance mutable field (no VS unit or structure ever flips this at runtime).
- **Performance**: the counter check is O(1) (three boolean conditions) plus one `legal_targets(state, target)` call (already budgeted O(4·attack_range) DIRECT / O(ring area) AREA, Stories 002/003) and, when it fires, one extra `damage()` computation + one `_apply_damage_to` + at most one `destroy_entity()`. No new cost class, no per-frame path — runs at most once per committed attack (control-manifest Performance Guardrail).
- Test fixtures: since every VS unit ships `can_counterattack = false`, the "counter fires" tests need a throwaway `UnitTypeDef.new()` with `can_counterattack = true` set directly (a fresh `Resource.new()`, not a `load()`d `.tres` — the same pattern Story 003 used for AREA fixtures). **Extend `tests/helpers/stubs/structure_state_stub.gd`'s `TypeStub` with `var can_counterattack: bool = false`** (additive, mirrors the `attack`/`attack_range`/`targeting_mode`/`min_range` fields Story 005 already added to that stub for the structure-attacker path) — `TypeStub` currently has no such field, and the GDD names the Defensive Structure as the first entity with `can_counterattack = true`, so a structure counter fixture is in scope. Include:
  - at least one test where a **`StructureState` defender** (`can_counterattack = true`) counters an in-profile attacker (the Defensive Structure's retaliation — the GDD's first live counter case); and
  - at least one test where a **`StructureState` attacker** (a Defensive Structure) is the one *countered* and killed by it — this is the test that actually exercises the polymorphic-damage fix above (a countered structure attacker routed through `_apply_damage_to`, not `Unit.apply_hp_delta`); without it, a future refactor could silently revert to `Unit.apply_hp_delta` and every other counter fixture (all unit-attacker) would still pass.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: determinism/clone-isolation of the full pipeline including counter scenarios
- Story 008: end-to-end integration proving both primary and counter hp changes are present after a real `apply_action` call

---

## QA Test Cases

- **AC-1 (no counter, VS default)**: Given each of the 4 VS unit types as a defender surviving a hit, When `Combat.apply()` resolves, Then the attacker's `current_hp` is unchanged (no counter damage applied).

- **AC-2 (counter fires when in-profile)**: Given a `can_counterattack = true` defender that survives, with the attacker within the defender's own DIRECT range, When `Combat.apply()` resolves, Then the attacker's `current_hp` decreases by the defender's `damage()` value, and neither entity's `has_attacked` changes from the counter step, and no AP is deducted for the counter.

- **AC-3 (dead defenders never counter)**: Given a `can_counterattack = true` defender reduced to 0 hp by the primary hit, When `Combat.apply()` resolves, Then the attacker's `current_hp` is unchanged (no counter) — proving the death check runs strictly before the counter check.

- **AC-4 (out-of-profile defender never counters)**: Given a `can_counterattack = true`, range-1 DIRECT defender struck by an attacker at range 3 (with the same GDD's example: a Sniper), When `Combat.apply()` resolves, Then no counter damage is applied — the range-gate makes kiting real.
  Edge cases: an AREA defender whose attacker sits outside its `[min_range, attack_range]` ring — same result, no counter.

- **AC-5 (counter-kills-attacker, no counter-to-counter)**: Given a counter that reduces the attacker to 0 hp, When `Combat.apply()` resolves, Then the attacker is destroyed (Grid cleared, removed from `entities_by_id`, a `UnitDestroyedEvent`/`StructureDestroyedEvent` present) and no further damage is applied to the (already-destroyed) defender — the pipeline terminates after one counter step.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/counterattack_test.gd` — must exist and pass

**Status**: [x] Created and passing (11 tests, full suite 327/327)

---

## Dependencies

- Depends on: Story 005 (primary death check + `destroy_entity()` must already be in place for the counter's own death check to reuse it)
- Unlocks: Story 007, Story 008

---

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 5/5 passing (all COVERED by tests, no deferrals)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/combat/counterattack_test.gd` (11 test functions); full suite 327/327 passing
**Code Review**: Complete — `/code-review` verdict APPROVED WITH SUGGESTIONS (no required changes; optional coverage suggestions logged, non-blocking)
