# Story 005: Death, Shared `destroy_entity()` Hook, HQ Win-Check & Structure-Attacker Polymorphism

> **Epic**: Combat Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4h
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-26

## Context

**GDD**: `design/gdd/combat-resolution.md`
**Requirement**: `TR-combat-007`, `TR-combat-008`, `TR-combat-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat Resolution & Shared Destruction/Win-Check
**ADR Decision Summary**: Death/removal is **not Combat-owned** — it is a single shared mutation-layer routine `GameState.destroy_entity(entity_id) -> Array[Event]`, called from inside `Combat.apply()` whenever a piece reaches 0 hp. It performs, in order: (a) the forward-declared Lab-revert hook (skipped in this story — no real Research Lab exists yet, see Implementation Notes), (b) `GridState.remove()` to clear occupancy, (c) drop from `entities_by_id`, (d) append `UnitDestroyedEvent` or `StructureDestroyedEvent{entity_id, is_hq}`. Because it runs inside the same `apply_action`, Grid removal and the destruction event are one atomic, same-step effect. This story also makes `attack()` **attacker-polymorphic**: the attacker may be a `UnitState` **or** a `StructureState` (the future Defensive Structure) — only the AP cost differs (`CombatConfig.attack_cost` for units, the Base-&-Production-owned `DEFENSIVE_ATTACK_COST` for a structure attacker, resolved by reading the attacker's runtime type).

**Secondary ADRs**: ADR-0001 (State Model — `entities_by_id`/`entity_at`; `destroy_entity()` lives on the mutation layer this ADR defines), ADR-0002 (`run_win_check` step 6 — already implemented by GS-004; this story supplies the *real* `StructureDestroyedEvent` producer that GS-004 currently only exercises via a throwaway test-double verb), ADR-0018 (Research — `on_lab_destroyed` forward-declared contract; not exercised in this story, see Out of Scope)

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) | **Risk**: LOW
**Engine Notes**: `entities_by_id.erase()` inside `destroy_entity()` is safe because it is only ever called from inside a verb handler's `apply()`, never mid-iteration over `entities_by_id` (godot-specialist-confirmed, ADR-0010 Engine Compatibility).

**Control Manifest Rules (this layer)**:
- Required: Death/removal must be a single shared `GameState.destroy_entity(entity_id) -> Array[Event]` mutation-layer method, called from inside `Combat.apply()` — source: ADR-0010
- Required: `destroy_entity()` must run, in order: (a) forward-declared `Research.on_lab_destroyed()` if the entity is a Lab with an active target (while still live), (b) `GridState.remove()`, (c) drop from `entities_by_id`, (d) append the destroyed event — all synchronously in the same `apply_action` — source: ADR-0010
- Required: `destroy_entity()` may only be called from inside a verb handler's `apply()`, never mid-iteration over `entities_by_id` — source: ADR-0010
- Required: `run_win_check(state, events)` must scan the commit's events for a `StructureDestroyedEvent` with `is_hq == true` — no separate HQ hp re-scan — source: ADR-0010 *(already implemented, GS-004 — this story is the real event producer)*
- Required: A single Combat pipeline must handle an attacker that is a `UnitState` OR a `StructureState`; only AP cost differs — source: ADR-0010, ADR-0017
- Forbidden: Never have Combat directly remove the piece while Research polls for reverts at start-of-turn — source: ADR-0010
- Forbidden: Never revert Research state via an `action_applied` signal subscriber — source: ADR-0010
- Forbidden: Never re-scan all HQ hp on every `apply_action` for the win-check — source: ADR-0010

---

## Acceptance Criteria

*From GDD `design/gdd/combat-resolution.md`, scoped to this story:*

- [ ] hp reaches exactly 0 → the piece is removed from Grid occupancy the same step and its tile is immediately empty/targetable
- [ ] If the defender is killed by the primary hit → removed that step (counterattack's absence in this scenario is Story 006's concern; this story just needs removal to happen synchronously)
- [ ] A `defense 2` structure defender (an HQ fixture) reduced to 0 hp → `destroy_entity()` fires, Grid clears, a `StructureDestroyedEvent{is_hq=true}` is appended
- [ ] A non-HQ structure reduced to 0 hp → `destroy_entity()` fires, Grid clears, a `StructureDestroyedEvent{is_hq=false}` is appended (no `GameOverEvent` — `run_win_check` already filters on `is_hq`, GS-004)
- [ ] A `UnitState` reduced to 0 hp → `destroy_entity()` fires, Grid clears, a `UnitDestroyedEvent` is appended
- [ ] A Defensive Structure fixture (`attack 4`, `attack_range 2`, DIRECT) fires at an enemy unit (`defense 0`, Plain) two tiles away on a clear cardinal line, resolved through `attack()` → damage = `max(1, 4 − 0 − 0) = 4` — the structure resolves through the *same* targeting + damage pipeline as a unit attacker; only the AP charged differs (`DEFENSIVE_ATTACK_COST`, not `attack_cost`)
- [ ] The same Defensive Structure attacker and a friendly piece on the cardinal line before the enemy → the shot is blocked (DIRECT line-of-fire holds identically for a structure attacker)
- [ ] An enemy HQ at hp = the attacker's damage, attacked → HQ hp reaches 0, `destroy_entity()`'s `StructureDestroyedEvent{is_hq=true}` is present in `apply()`'s returned events (full end-to-end GameOver wiring through `apply_action` is Story 008 — this story only needs the *event* to be correctly produced and returned from `Combat.apply()`)

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

- Add to `src/core/game_state/game_state.gd` (extends the existing class — do not create a second file):
  ```gdscript
  func destroy_entity(entity_id: int) -> Array[Event]:
      var e: EntityState = entities_by_id[entity_id]
      var evts: Array[Event] = []
      # (a) Lab-revert: forward-declared, skipped until Research/Base & Production land — see Out of Scope.
      grid.remove(e.position.x, e.position.y)     # (b)
      entities_by_id.erase(entity_id)              # (c)
      if e is StructureState:
          var evt := StructureDestroyedEvent.new()
          evt.entity_id = entity_id
          evt.is_hq = e.is_hq()
          evt.owner = e.owner
          evts.append(evt)
      else:
          evts.append(UnitDestroyedEvent.new(entity_id))
      return evts
  ```
  **Note the existing `StructureDestroyedEvent` (`src/core/event/structure_destroyed_event.gd`) already has `is_hq`/`owner` fields (GS-004) but no `entity_id` field** — add `@export var entity_id: int = -1` to it as part of this story (the file's own doc comment already flags this exact reconciliation: *"real destroy_entity() implementation constructs and appends the authoritative version of this event (adding entity_id if not already present here)"*). This is additive — GS-004's existing tests construct `StructureDestroyedEvent` without setting `entity_id`, which is fine (defaults to -1, unused by `run_win_check`'s `is_hq` filter).
  `grid.remove(x, y)` signature note: `GridState.remove` takes `(x: int, y: int)`, not a `Vector2i` — call it as `grid.remove(e.position.x, e.position.y)`.
  Create `UnitDestroyedEvent` (`src/core/event/unit_destroyed_event.gd`) as a new top-level `Event` subclass — it does not exist yet: `class_name UnitDestroyedEvent extends Event` with an `@export var entity_id: int = -1` field and a custom `func _init(id: int = -1) -> void: entity_id = id` so the `destroy_entity()` snippet's `UnitDestroyedEvent.new(entity_id)` call resolves (mirroring `Combat.TargetResult`'s `_init`-arg convention — **not** `StructureCompletedEvent`, which is deliberately field-less and demonstrates nothing about an id-carrying event). `StructureDestroyedEvent` uses `.new()` + property assignment because GS-004 authored it that way; keep the `destroy_entity()` snippet's two event constructions consistent with each event class's own `_init`.
- `e.is_hq()` — this is a method the real `StructureState` (ADR-0007, Base & Production epic — **not yet built in `src/`**) is expected to expose. Since only `tests/helpers/stubs/structure_state_stub.gd` exists today, **extend that stub** with an `is_hq() -> bool` method (backed by a settable `@export var is_hq_flag: bool = false` or similar test-controllable field) so this story's fixtures can express "this is an HQ" vs. "this is a regular structure" without waiting on Base & Production. Flag the stub extension in the same doc-comment style the stub already uses (temporary, delete-when-real-class-lands).
- In `Combat.apply()` (extending Story 004's version), add the primary death check immediately after the `Unit.apply_hp_delta(target, -dmg)` line:
  ```gdscript
  if target.current_hp <= 0:
      events.append_array(state.destroy_entity(target.entity_id))
  ```
  This is the exact insertion point Story 004's Implementation Notes flagged ("primary death check ... Story 005 adds that branch immediately after the Unit.apply_hp_delta line").
- **Structure-attacker polymorphism** — three concrete changes to Story 004's shipped `validate()`/`apply()`:
  - **(a) Remove the `TODO(Story 005)` guard.** Story 004's `validate()` contains `if not (attacker is UnitState): return Action.Reason.ILLEGAL_TARGET   # TODO(Story 005): structure-attacker polymorphism`, placed *before* the `can_attack` check. Delete that line and replace it with attacker-kind branching (a `StructureState` reaching this point is now legal, not rejected):
    ```gdscript
    if attacker is UnitState:
        if not Unit.can_attack(attacker):
            return Action.Reason.ILLEGAL_TARGET   # already attacked this turn
    elif attacker is StructureState:
        if attacker.has_attacked:
            return Action.Reason.ILLEGAL_TARGET   # Defensive Structure already fired this turn
    else:
        return Action.Reason.ILLEGAL_TARGET       # unknown entity kind — defensive
    ```
  - **(b) Widen the AP cost in BOTH `validate()` and `apply()`.** Story 004 hardcoded `CombatBalance.combat.attack_cost` in `apply()`'s `AP.spend` call and in `validate()`'s afford check. Both must become:
    ```gdscript
    var cost: int = BaseProduction.defensive_attack_cost() if attacker is StructureState else CombatBalance.combat.attack_cost
    ```
    — `validate()` uses it in `AP.can_afford(state, attacker.owner, cost)`; `apply()` uses it in `AP.spend(state, attacker.owner, cost)`. `apply()`'s existing generic `attacker.has_attacked = true` line already works for both kinds *once the stub has the field* (see (c)). `BaseProduction.defensive_attack_cost()` is a **forward-declared Base-&-Production-owned contract** — extend `tests/helpers/stubs/base_production_stub.gd` (already exists for the AP-income forward declaration) with a test-controllable `static func defensive_attack_cost() -> int` (default e.g. 1, settable via `set_defensive_attack_cost()`), mirroring the `Research.attack_tech_bonus()` forward-declaration pattern — never hardcode `1` inline in Combat.
  - **(c) Add `has_attacked` to the structure stub.** `tests/helpers/stubs/structure_state_stub.gd` today has only `@export var has_acted: bool = true` — there is **no** `has_attacked` field, so both the (a) branch and `apply()`'s `attacker.has_attacked = true` line would crash against a structure fixture. Add `@export var has_attacked: bool = false` to the stub, matching ADR-0007's real `StructureState.has_attacked` field name exactly. **Do NOT reuse or rename `has_acted`** — that's a separate GS-003/ADR-0008 per-turn-reset field consumed by `Structure.reset_turn_flags()` for a different test; the two are independent until the real `StructureState` reconciles them (Base & Production's job).
- `attack()`'s attacker-polymorphic damage read is **already implemented** — Story 001 pre-seeded `Combat._effective_attack_for(state, attacker)` with exactly the needed branch (`Unit.effective_attack(state, attacker) if attacker is UnitState else attacker.type.attack`), specifically so this story's structure-attacker path needs no change to `damage()`. **No action required here** beyond confirming `damage()` still calls `_effective_attack_for()` (it does, unconditionally) — this story is simply the first to exercise the `else` (structure) branch. The structure fixture's `type.attack` must be set (e.g. `attack 4` for the Defensive Structure AC).
- HQ win-check event shape: this story only needs `Combat.apply()` to *return* a correctly-populated `StructureDestroyedEvent{is_hq=true}` in its `Array[Event]` — wiring that through a real `apply_action()` call end-to-end (so `run_win_check` actually flips `match_status`) is exercised in Story 008's Integration gate. A unit-level test here can call `run_win_check` directly against `Combat.apply()`'s returned events (mirroring how `win_check_terminal_test.gd` already hand-builds an events array) to confirm the shape is correct without needing the full `apply_action` round-trip.
- **Performance**: `destroy_entity()` is O(1) — one `GridState.remove()`, one `entities_by_id.erase()`, one event append (no scan). The structure-attacker cost lookup and `has_attacked` branches are O(1) additions to already-O(1) `validate()`/`apply()`. No per-frame path; runs once per committed attack (control-manifest Performance Guardrail).

---

## Out of Scope

*Handled by neighbouring stories, other epics, or explicitly deferred:*

- Story 006: the counter step (which also calls `destroy_entity()` on a counter-killed attacker) — this story's death-check covers only the *primary* hit
- Story 008: full end-to-end `apply_action` → `run_win_check` → `GameOver` composition
- **Lab-revert (`Research.on_lab_destroyed`)**: the real Research epic does not exist yet (no stories created — see `production/epics/research-tech/EPIC.md`). `destroy_entity()`'s step (a) is a no-op in this story (skip the `is_research_lab()`/`current_research_target` check entirely rather than half-implementing it against a stub with no research-timer semantics) — leave a `# TODO(research-tech epic): Lab-revert hook, ADR-0010 step (a)` comment at the exact insertion point so the Research epic's implementer finds it immediately. Do not invent a `Research.on_lab_destroyed` stub for this story; it has no consumer yet and no test needs it.
- Base & Production's real `StructureState`/`StructureTypeDef`/`is_hq()`/`is_research_lab()` (that whole epic is not yet built) — this story works entirely against the extended test stub, exactly as Unit System's early stories worked against `research_stub.gd`/`base_production_stub.gd` before those epics existed.

---

## QA Test Cases

- **AC-1 (same-step removal)**: Given a unit at 0 hp after a primary hit, When `Combat.apply()` returns, Then `state.grid.occupant_at(x,y)` is `GridState.EMPTY_OCCUPANT` and `state.entities_by_id` no longer contains the entity's id.

- **AC-2 (HQ destruction event)**: Given an HQ fixture (`is_hq_flag = true`) reduced to 0 hp, When `Combat.apply()` runs, Then its returned events contain a `StructureDestroyedEvent` with `is_hq == true` and `entity_id` matching the destroyed HQ.

- **AC-3 (non-HQ structure — no false GameOver)**: Given a non-HQ structure fixture reduced to 0 hp, When `Combat.apply()` runs, Then its returned events contain a `StructureDestroyedEvent` with `is_hq == false`; When those events are passed to `run_win_check`, Then `match_status` stays `IN_PROGRESS`.

- **AC-4 (unit destruction event)**: Given a `UnitState` reduced to 0 hp, When `Combat.apply()` runs, Then its returned events contain a `UnitDestroyedEvent` with the matching `entity_id`.

- **AC-5 (structure-as-attacker, same pipeline)**: Given a Defensive Structure fixture (`attack 4`, range 2, DIRECT) firing at an enemy unit (`defense 0`) 2 tiles away on a clear line, When resolved through `Combat.apply()`, Then damage dealt = 4, and the AP deducted from the structure's owner equals `BaseProduction.defensive_attack_cost()`, not `CombatConfig.attack_cost`.
  Edge cases: same structure attacker with a friendly piece blocking the line → `Combat.validate()` rejects (DIRECT LoF holds identically for a structure attacker).

- **AC-6 (HQ-at-exact-damage → correct event shape)**: Given an enemy HQ fixture at `current_hp` exactly equal to the attacker's computed damage, When `Combat.apply()` resolves the attack, Then the returned events include `StructureDestroyedEvent{is_hq=true}`, and passing those events to `GameState.run_win_check()` directly sets `match_status = GAME_OVER` with the correct winner (reusing GS-004's existing `run_win_check` — this test proves Combat's event is the real producer GS-004 was always designed to consume).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/combat/destroy_entity_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (extends `Combat.apply()`'s primary-hit branch with the death check)
- Unlocks: Story 006 (counter step also calls `destroy_entity()`), Story 008 (full end-to-end HQ-destruction → GameOver integration test)

## Completion Notes
**Completed**: 2026-07-26
**Criteria**: 8/8 passing (0 deferred) — all covered by `tests/unit/combat/destroy_entity_test.gd` (8 test functions, incl. a bonus structure once-per-turn test), full suite 316/316 green.
**Deviations**:
- OUT OF SCOPE (valid): removed the now-obsolete `attack_pipeline_ap_cost_test.gd::test_structure_attacker_rejected_illegal_target` — it pinned Story 004's `TODO(Story 005)` guard, which this story removes by design; the corrected opposite behaviour (structure attacker accepted, routed through the shared pipeline) is re-covered by `destroy_entity_test.gd`'s AC-5 tests. Documented in that file's header.
- OUT OF SCOPE (valid): extended `structure_state_stub.gd`'s `TypeStub` with `attack`/`attack_range`/`targeting_mode`/`min_range` — necessary plumbing so a `StructureState` attacker routes through the same `legal_targets`/`_walk_direction`/`_effective_attack_for` pipeline; additive, DIRECT-safe defaults, test-only.
- Code-review polish applied before close: extracted `Combat._attack_cost_for(attacker)` so `validate()` and `apply()` share one cost-lookup (removes a latent drift risk), mirroring the file's `_effective_attack_for` pattern; added a precondition comment to `GameState.destroy_entity()` (bad id throws by design, only called with a validated id) and a "won't-test" note to the test header (Lab-revert no-op + defensive `else` branch). All behaviour-preserving (316/316 unchanged).
**Forward seam**: `destroy_entity()`'s Lab-revert step (a) is a `TODO(research-tech epic)` no-op — the Research epic wires `Research.on_lab_destroyed()` there. The `StructureDestroyedEvent.entity_id` addition reconciles the GS-004 forward-declared event (its real producer now exists).
**Test Evidence**: Logic — `tests/unit/combat/destroy_entity_test.gd` (BLOCKING gate satisfied).
**Code Review**: Complete — `/code-review` run this session, verdict APPROVED (godot-gdscript-specialist CLEAN incl. hand-traced destroy_entity ordering / erase-after-read safety / AP boundary; qa-tester TESTABLE; 0 required changes; suggestion #1 + doc clarifications applied).
