# Story 004: AttackAction Verb Handler — AP Cost, Once-Per-Turn, Enemy-Only, Atomicity

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: `AttackAction` is a typed `Action` subclass (`src/core/action/attack_action.gd`) dispatched through `apply_action`'s verb-enum router. `Combat.validate(state, action) -> int` is pure and total: gates on `can_attack(attacker)` (not `has_attacked`), `AP.can_afford(state, attacker.owner, attack_cost)`, and the target being a legal enemy in `legal_targets(state, attacker)`. `Combat.apply(state, action) -> Array[Event]` assumes validation passed: spends `attack_cost`, sets `attacker.has_attacked = true`, applies primary damage via `Unit.apply_hp_delta`. This story stops **before** the death-check/counter/destroy_entity steps (Story 005/006) — it delivers the atomic AP-cost/once-per-turn/idempotency slice of the pipeline only, with primary damage landing on `current_hp` but no destruction handling yet.

**Secondary ADRs**: ADR-0002 (Apply-Action Command Model — the verb-handler contract, validate-before-mutate atomicity, `apply_action`'s 7-step pipeline this handler plugs into), ADR-0006 (AP Economy — `AP.can_afford`/`AP.spend`)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: Standard GDScript static dispatch, no post-cutoff API surface.

**Control Manifest Rules (this layer)**:
- Required: `Combat.apply()` must run the fixed pipeline: primary damage → primary death → conditional single counter → counter death, then return typed events — source: ADR-0010 *(this story implements only the "primary damage" step of that pipeline; death/counter arrive in Stories 005/006 — the fixed step order still constrains how this story's code must be shaped so later stories insert cleanly)*
- Required: `validate()` must be pure and total (check ALL failure conditions, including `AP.can_afford`); `apply()` must assume validation passed and never return failure — source: ADR-0002
- Required: Atomicity must be achieved via validate-before-mutate with no rollback — source: ADR-0002
- Required: Idempotency must be handled via stateless re-validation — no dedup IDs, no seen-set — source: ADR-0002
- Forbidden: Never mutate state inside `validate()`, or check a precondition only in `apply()` — source: ADR-0002
- Forbidden: Never embed `validate()`/`apply()` methods directly on an `Action` subclass — source: ADR-0002

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

- [ ] `has_attacked = false` and ≥ 2 AP → `can_attack()` is true and the attack is offered (i.e. `validate()` returns OK)
- [ ] `has_attacked = true`, a second attack is attempted → rejected before AP/target eval, no AP spent, no state change
- [ ] A successful attack → the attacker's `has_attacked` is set true whether or not the target died (death itself is Story 005 — this story only needs `has_attacked` to flip regardless of the resulting `current_hp`)
- [ ] < 2 AP, an attack is attempted → `can_afford` false → rejected, no AP spent, no `has_attacked` flip, no damage (atomicity)
- [ ] A legal attack is applied once, then the *same* attack action is submitted a second time against the now-updated state (attacker already `has_attacked = true`) → the second submission is re-validated and rejected — no second damage, no second AP deduction, no double-apply
- [ ] A target the attacker owns (unit or own HQ) → the attack is rejected
- [ ] Primary damage: attacking reduces the target's `current_hp` by `Combat.damage(state, attacker, target)` via `Unit.apply_hp_delta` (reuses Story 001's formula verbatim — no re-derivation)

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Create `src/core/action/attack_action.gd`, mirroring `move_action.gd`'s shape exactly:
  ```gdscript
  class_name AttackAction
  extends Action

  @export var attacker_tile: Vector2i
  @export var target_tile: Vector2i

  func _init() -> void:
      verb = Action.Verb.ATTACK
  ```
  Resolve `attacker`/`target` inside `validate()`/`apply()` via `state.entity_at(tile)`, exactly as `MoveAction`'s handler resolves the mover — do not carry entity references on the `Action` itself (it is a transient, per-input object, never part of cloned `GameState` data).
- Extend `src/core/combat/combat.gd` with:
  ```gdscript
  static func validate(state: GameState, action: AttackAction) -> int:
      var attacker: EntityState = state.entity_at(action.attacker_tile)
      var target: EntityState = state.entity_at(action.target_tile)
      if attacker == null or target == null:
          return Action.Reason.NO_SUCH_ENTITY
      if target.owner == attacker.owner:
          return Action.Reason.ILLEGAL_TARGET
      if not (attacker is UnitState):
          return Action.Reason.ILLEGAL_TARGET   # TODO(Story 005): structure-attacker (Defensive Structure) polymorphism
      if not Unit.can_attack(attacker):
          return Action.Reason.ILLEGAL_TARGET   # already-attacked this turn
      var cost: int = CombatBalance.combat.attack_cost   # structure cost branch is Story 005
      if not AP.can_afford(state, attacker.owner, cost):
          return Action.Reason.CANT_AFFORD
      var found := false
      for tr: TargetResult in legal_targets(state, attacker):
          if tr.target_id == target.entity_id:
              found = true
              break
      if not found:
          return Action.Reason.ILLEGAL_TARGET
      return Action.Reason.OK

  static func apply(state: GameState, action: AttackAction) -> Array[Event]:
      var attacker: EntityState = state.entity_at(action.attacker_tile)
      var target: EntityState = state.entity_at(action.target_tile)
      AP.spend(state, attacker.owner, CombatBalance.combat.attack_cost)
      attacker.has_attacked = true
      var events: Array[Event] = []
      var dmg: int = damage(state, attacker, target)
      _apply_damage_to(target, dmg)   # polymorphic: unit OR structure defender
      # primary death check, counter, destroy_entity: Story 005/006
      return events
  ```
  This is a **deliberately incomplete** `apply()` for this story's scope — it lands primary damage on `current_hp` but does not yet call `GameState.destroy_entity()` when `current_hp` reaches 0 (Story 005 adds that branch immediately after the `_apply_damage_to` line). Do not skip writing this shape now and redo it in Story 005 — extend it in place.
- **`target` may be an enemy unit OR an enemy structure** — Story 002's `legal_targets()` already returns enemy structures (HQ/outpost) as valid targets (GDD Rule 3), so `apply()` must damage either kind. `Unit.apply_hp_delta()` is typed to `UnitState` only, so route damage through a small polymorphic helper rather than calling it directly:
  ```gdscript
  static func _apply_damage_to(target: EntityState, dmg: int) -> void:
      if target is UnitState:
          Unit.apply_hp_delta(target, -dmg)   # unit-owned mutator (existing hp-clamp path)
      else: # StructureState — Base & Production owns structure hp; clamp inline until that epic lands
          target.current_hp = clampi(target.current_hp - dmg, 0, target.type.hp)  # TODO(base-production): structure hp mutator
  ```
  Extend `tests/helpers/stubs/structure_state_stub.gd` with a test-controllable `current_hp: int` field (minimal, mirroring the `type.defense` stub extension Story 001 added) so a structure-defender fixture can be damaged.
- Register the verb in `GameState._ensure_dispatch_registered()` (mirroring the existing `Action.Verb.MOVE` registration line): `register_verb(Action.Verb.ATTACK, Combat.validate, Combat.apply)`. **Caution**: `win_check_terminal_test.gd` (GS-004) uses `Action.Verb.ATTACK` as its own throwaway registered verb via `GameState.register_verb`/`unregister_verb` to simulate Combat's not-yet-built destruction pipeline, asserting `_validators.has(Action.Verb.ATTACK)` is `false` at the start of each test and unregistering in cleanup. Once this story registers `Action.Verb.ATTACK` for real inside `_ensure_dispatch_registered`, those GS-004 tests' `assert_bool(GameState._validators.has(Action.Verb.ATTACK)).is_false()` preconditions will fail (the slot is now always populated) — this is an **expected, intentional reconciliation**: update `tests/unit/win_check_terminal_test.gd` to no longer assert the slot is empty, and to save/restore the *real* Combat handler pair around its throwaway-verb tests instead of asserting emptiness (or, more simply, have those specific tests call `GameState.register_verb`/`unregister_verb` around a **different**, still-genuinely-unused verb, e.g. reuse `Action.Verb.BUILD`, to keep them decoupled from Combat's real registration going forward). Flag this reconciliation explicitly in the PR/commit — it is expected fallout from wiring Combat in, not a regression.
- **Attacker is unit-only in this story — reject non-units explicitly, don't silently skip.** The `if not (attacker is UnitState): return ILLEGAL_TARGET` guard is a deliberate *temporary rejection* (Story 005 removes it as its single-line entry point for structure-attacker polymorphism), not a "not-tested-yet" scope note. It must come *before* the `can_attack` check so `apply()`'s later `attacker.has_attacked = true` is only ever reached for a `UnitState` (whose `has_attacked` field exists — the current `structure_state_stub.gd` has `has_acted`, not `has_attacked`, so a structure attacker reaching `apply()` would crash). `can_attack(attacker)` then delegates to the already-shipped `Unit.can_attack(unit)` (Unit System Story 003).
- Idempotency: no dedup IDs, no seen-set (control-manifest, ADR-0002) — resubmitting the identical `AttackAction` after it already landed is caught naturally because `validate()` re-reads live state: `attacker.has_attacked` is already `true`, so the second call rejects at the `can_attack` check with zero special-casing.
- `AttackAction`'s test double note: because `Combat.validate`/`Combat.apply` are typed to accept `AttackAction` (widening `Action` per the verb-handler contract), and this story's Pure Logic gate fixtures inject Grid/AP directly (per the GDD's "fake/injected Grid + AP" framing) rather than going through a real `apply_action` dispatch, tests may call `Combat.validate(state, action)`/`Combat.apply(state, action)` directly against a hand-built `GameStateFactory`-produced state with real `AP`/`GridState` (not further faked) — `AP`/`GridState` are already real, lightweight, headless classes, so "fake/injected" here means real objects constructed as small test fixtures, not mock doubles.
- **Performance**: `validate()` is O(1) checks plus one `legal_targets()` call (already budgeted O(4·attack_range) DIRECT / O(ring area) AREA, Stories 002/003); `apply()` is O(1) (spend + flag + one `damage()` + one clamp). No new cost, no per-frame path — runs once per committed attack action (control-manifest Performance Guardrail).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: primary death check, `destroy_entity()`, structure-attacker cost branching (`DEFENSIVE_ATTACK_COST`)
- Story 006: counterattack step
- Story 007: determinism/clone-isolation assertions on the full `attack()` call
- Story 008: wiring through the real `apply_action`/`GameState.register_verb` path end-to-end with Movement combined (this story registers the verb but the Integration-gate ACs — move-then-attack, real Grid — belong to Story 008)

---

## QA Test Cases

- **AC-1 (offered when legal)**: Given `has_attacked = false` and `current_ap >= 2`, When `Combat.validate()` is called with a legal target, Then it returns `Action.Reason.OK`.

- **AC-2 (once-per-turn rejection)**: Given `has_attacked = true`, When `Combat.validate()` is called again, Then it returns a rejection reason before any AP/target evaluation, and a direct check of `state.per_player[owner].current_ap` and `target.current_hp` confirms neither changed.

- **AC-3 (has_attacked flips regardless of outcome)**: Given a successful `attack()` application, When inspected afterward, Then `attacker.has_attacked == true` — assert this on both a lethal-damage fixture and a non-lethal one (this story doesn't implement destruction, so "lethal" here just means `current_hp` clamped to 0 via `Unit.apply_hp_delta`'s existing floor).

- **AC-4 (unaffordable attack — full atomicity)**: Given `current_ap < 2`, When `Combat.validate()` is called, Then it returns `Action.Reason.CANT_AFFORD`; When `Combat.apply()` is never reached (caller respects validate's rejection), Then AP, `has_attacked`, and target `current_hp` are all unchanged.

- **AC-5 (double-submit idempotency)**: Given a legal attack applied once via `apply()`, When the identical `AttackAction` is re-validated against the now-updated state, Then `Combat.validate()` rejects it (attacker already `has_attacked`), and re-running `apply()` is never reached — no second AP deduction, no second damage.
  Edge cases: re-submit against a target that no longer exists (destroyed by some other means) — `validate()` rejects with `NO_SUCH_ENTITY` or `ILLEGAL_TARGET`, never crashes on a null dereference.

- **AC-6 (enemy-only)**: Given a target tile occupied by the attacker's own unit or own HQ fixture, When `Combat.validate()` is called, Then it returns `Action.Reason.ILLEGAL_TARGET`.

- **AC-7 (primary damage lands, unit or structure defender)**: Given a legal attack, When `Combat.apply()` runs, Then `target.current_hp` decreases by exactly `Combat.damage(state, attacker, target)` (computed once, before the mutation, to compare against). Test **both** a `UnitState` defender (damage via `Unit.apply_hp_delta`) **and** an enemy `StructureState` defender (damage via the inline clamp in `_apply_damage_to`) — proving `apply()` damages either kind through the shared Story-001 formula, never an inline re-derivation.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/attack_pipeline_ap_cost_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`Combat.damage()`), Story 002 (`Combat.legal_targets()`), `Unit.can_attack()`/`Unit.apply_hp_delta()` (Unit System, DONE), `AP.can_afford()`/`AP.spend()` (AP Economy, DONE)
- Unlocks: Story 005 (extends this story's `apply()` with the death/destroy_entity branch), Story 006 (extends `apply()` with the counter branch)

## Reconciliation Note

This story registers `Action.Verb.ATTACK` for real in `GameState._ensure_dispatch_registered()`. `tests/unit/win_check_terminal_test.gd` (GS-004) currently borrows that same verb slot as a throwaway stand-in for Combat's not-yet-built pipeline and asserts the slot is unregistered at the start of each of its tests. Update those specific assertions/tests as part of this story (see Implementation Notes) — this is expected, flagged fallout, not a regression to investigate separately.

**Amended at close (2026-07-26):** a *second* test file, `tests/unit/apply_action_pipeline_test.gd`, also borrowed `Action.Verb.ATTACK` as its known-unregistered-verb fixture and broke identically when ATTACK became real. It was reconciled the same way (→ `Action.Verb.RESEARCH`, confirmed unregistered project-wide). Both reconciliations now verb-squat on `BUILD`/`RESEARCH` respectively — see the tech-debt register entry for the forward-maintenance obligation when those epics land.

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 7/7 passing (0 deferred) — all covered by `tests/unit/combat/attack_pipeline_ap_cost_test.gd` (13 test functions), full suite 309/309 green.
**Deviations**:
- OUT OF SCOPE (valid/necessary): two test-file reconciliations for the real `Action.Verb.ATTACK` registration — `win_check_terminal_test.gd` (→ BUILD, named in the Reconciliation Note) and `apply_action_pipeline_test.gd` (→ RESEARCH, *not* named in the story but broke identically). Both verified green (16 / 14) after reconciliation; both touched files are outside the combat suite.
- Two code-review gap tests added before close: `test_structure_attacker_rejected_illegal_target` (covers the load-bearing `is UnitState` guard — previously 0% coverage) and `test_self_target_same_tile_rejected_illegal_target`.
- Structure-as-attacker + death/destroy_entity + counter all correctly deferred (Stories 005/006) per the ADR's incremental scope.
**Test Evidence**: Logic — `tests/unit/combat/attack_pipeline_ap_cost_test.gd` (BLOCKING gate satisfied).
**Code Review**: Complete — `/code-review` run this session, verdict APPROVED (godot-gdscript-specialist CLEAN incl. hand-traced atomicity/idempotency/polymorphic-damage; qa-tester TESTABLE; 0 required changes; both coverage gaps applied).
**Tech Debt**: verb-squat re-treatment logged in `docs/tech-debt-register.md`.
