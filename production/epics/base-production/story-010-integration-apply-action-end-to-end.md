# Story 010: Integration — apply_action End-to-End (Real Grid + AP + Turn Manager + Unit + Combat)

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — the "Integration gate (BLOCKING — real Grid + AP + Turn Manager + Unit + Combat)" ACs.
**Requirement**: `TR-baseprod-004` (the *real* apply_action commit — build atomically spends + places via one transaction; validated end-to-end here)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: apply_action command model + ADR-0017: Base & Production mechanics
**Secondary ADRs**: ADR-0008 (start-of-turn step-3-before-step-4 ordering — the income-timing proof), ADR-0010 (structure-as-attacker fire + counter + HQ win-check), ADR-0006 (real AP snapshot + income).
**ADR Decision Summary**: `apply_action` is the sole mutation vector; each verb's rules run as pure `validate`/`apply` in the owning system with validate-before-mutate atomicity. This story exercises the B&P verbs against the **real** stack (real Grid, AP, Turn Manager, Unit, Combat) — the BLOCKING Integration gate — proving the atomic commit, the Rule-6 income ordering, real unit production, real range-2 structure fire + counter, real HQ win, and live re-legalization.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `duplicate_deep()` copies a field's value at call time; instance-method dispatch is identical whether `GameState` came from `.new()` or `duplicate_deep()`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`apply_action(action) -> ActionResult` is the sole mutation vector for `GameState`" — source: ADR-0001/ADR-0002
- Required: "`apply_action`'s fixed 7-step pipeline must run in order: (1) GameOver gate, (2) active-player gate, (3) validate, (4) reject if not OK, (5) apply, (6) run_win_check, (7) return ActionResult" — source: ADR-0002
- Required: "Never reorder start_turn step 4 before step 3 — the income snapshot must observe structures that completed this same turn" — source: ADR-0008
- Required: "Illegal actions rejected with zero state change (incl. AP); validate-before-apply or transactional" — source: ADR-0002
- Required: "Re-submission of an applied action safely re-validated + rejected, no double-apply" — source: ADR-0002

> **Pattern note**: Mirror `tests/integration/combat/combat_apply_action_integration_test.gd`. This is the BLOCKING Integration gate for the epic — every AC exercises the **real** stack, not stubs/fixtures.

---

## Acceptance Criteria

*Integration gate (BLOCKING — real Grid + AP + Turn Manager + Unit + Combat):*
- [ ] **GIVEN** the real stack, **WHEN** a player builds an Economy Outpost with exactly `build_cost` AP, **THEN** `apply_action` atomically spends AP + places it Under-Construction; an unaffordable build leaves AP/Grid unchanged.
- [ ] **GIVEN** an Economy Outpost's timer reaching 0 at the owner's real start-of-turn, **THEN** that same turn's `ap_income` reflects it (2 completed → income X; a 3rd completes → income X + `OUTPOST_BONUS_TIER1` **this** turn, not next) — **the end-to-end proof of Rule 6 ordering (step 3 before step 4)**. **AND** two Economy Outposts completing the same start-of-turn both count that turn.
- [ ] **GIVEN** a real Production Outpost producing a Trooper, **THEN** the Trooper is a real Unit entity on the chosen tile, immediately Active and selectable that turn.
- [ ] **GIVEN** a real Defensive Structure firing via Combat's `attack()` (structure as attacker) at an enemy in range 2 on a real DIRECT line, **THEN** Combat's formula applies with the structure's `attack 4` as `effective_attack` and the target's hp drops accordingly.
- [ ] **GIVEN** a real `can_counterattack` Defensive Structure attacked by a unit within its range/profile, **THEN** a free counter fires through Combat's real counter step.
- [ ] **GIVEN** a real HQ reduced to 0 hp, **THEN** the real win-check fires `GameOver(winner = opponent)` in the same action and subsequent actions are rejected.
- [ ] **GIVEN** a real Under-Construction structure destroyed before completion, **THEN** it is removed from the real Grid that step, and **no AP is refunded**.
- [ ] **GIVEN** an enforcing enemy structure destroyed mid-game, **THEN** a later `legal_build_tiles` re-check makes previously-excluded nearby tiles legal (live, not cached).

---

## Implementation Notes

*Derived from ADR-0002 (real apply_action) + ADR-0017/0008/0010:*

- **Build atomicity**: submit a `BuildAction` through the real `GameState.apply_action`; assert AP spent + structure placed Under-Construction on success, and AP/Grid unchanged on an unaffordable build (validate-before-mutate, no rollback).
- **Rule-6 income ordering (the headline proof)**: drive a real start-of-turn (`start_turn` / `EndTurnAction.apply` path) with an Economy Outpost timer reaching 0; assert the **same** turn's income reflects the just-completed outpost — step 3 (`advance_build_timers`) runs before step 4 (`AP.reset_turn` income snapshot). Also assert two outposts completing the same start-of-turn both count that turn (batch).
- **Real production**: a real Completed Production Outpost `produce(Trooper, tile)` → assert a real `UnitState` entity exists on the tile, is Active, and is selectable that turn.
- **Real structure fire + counter**: a real Defensive Structure fires via Combat's `attack()` at an enemy at range 2 on a real DIRECT line → assert the target hp drops per Combat's formula with `attack 4`. A real `can_counterattack` Defensive Structure attacked in range → assert a free counter through Combat's real counter step.
- **Real HQ win**: reduce a real HQ to 0 hp → assert the real `run_win_check` fires `GameOver(winner = opponent)` in the same action, and subsequent actions are rejected (GameOver gate, step 1).
- **Under-construction destroyed, no refund**: destroy a real Under-Construction structure → assert Grid-removed that step and **no AP refunded** (contrast with Story 005's voluntary-cancel refund).
- **Live re-legalization**: destroy an enemy structure that was enforcing the >2 standoff → a later `legal_build_tiles` makes previously-excluded nearby tiles legal (live, never cached — the D3 guarantee end-to-end).

---

## Out of Scope

- The pure-slice logic of each verb — Stories 002–007 (this story is the real-stack Integration gate over them).
- The Advisory closeout-drag playtest ACs (AC-CLOSEOUT-A/B) — those are a *tuning* target (documented playtest with fixture CF-1), not a correctness gate, and are not automated here.
- HUD read-surface — Story 009.

---

## QA Test Cases

- **AC-build-atomic**: Given the real stack, exactly `build_cost` AP / When `build(Economy Outpost)` via `apply_action` / Then AP spent + placed Under-Construction; an unaffordable build leaves AP/Grid unchanged.
- **AC-income-ordering (Rule 6 end-to-end)**: Given an Economy Outpost timer reaching 0 at the real start-of-turn / Then that same turn's `ap_income` reflects it (2→X, 3rd completes→X + `OUTPOST_BONUS_TIER1` this turn). AND two completing the same start-of-turn both count (batch). Edge: proves step 3 before step 4.
- **AC-real-production**: Given a real Production Outpost / When `produce(Trooper, tile)` / Then a real Active, selectable Unit entity on the tile that turn.
- **AC-real-structure-fire**: Given a real Defensive Structure firing at an enemy at range 2 on a real DIRECT line / Then Combat's formula applies with `attack 4`, target hp drops.
- **AC-real-counter**: Given a real `can_counterattack` Defensive Structure attacked within range / Then a free counter fires through Combat's real counter step.
- **AC-real-hq-win**: Given a real HQ reduced to 0 hp / Then real win-check fires `GameOver(winner = opponent)` same action; subsequent actions rejected.
- **AC-uc-destroyed-no-refund**: Given a real Under-Construction structure destroyed before completion / Then Grid-removed that step, no AP refunded.
- **AC-live-relegalization**: Given an enforcing enemy structure destroyed mid-game / Then a later `legal_build_tiles` makes previously-excluded nearby tiles legal (live, not cached).

---

## Test Evidence

**Story Type**: Integration (BLOCKING gate)
**Required evidence**:
- `tests/integration/base-production/integration_apply_action_end_to_end_test.gd` — must exist and pass

**Status**: [x] Created — `tests/integration/base-production/integration_apply_action_end_to_end_test.gd` (10 tests, all passing)

---

## Dependencies

- **Depends on**: Stories 001–007 (ALL) — schema/config, build + `legal_build_tiles`, start-of-turn timers + `completed_outpost_count`, produce, cancel, defensive attack, and structure destruction / HQ win-hook. Uses the real Grid, AP, Turn Manager (Foundation, Complete), Unit + Combat (Core, Complete).
- **Unlocks**: Epic Definition-of-Done (the BLOCKING Integration gate) and the AP-income / start-of-turn regression against the real `BaseProduction` (replacing the Sprint-1 stub).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 8/8 passing (all COVERED by the 10-test integration suite; Rule-6 income-ordering proof hand-verified load-bearing by qa-tester — income_at_n2=14 vs n3=16). Full suite 504/504, exit 0.
**Deviations**: None. No `src/` change — every AC composed correctly through the real `apply_action`/`start_turn`/`destroy_entity` stack (the gate's positive result: Stories 001–007 wire together with no composition bug). Review-time hardening (added `StructurePlacedEvent`/`StructureCompletedEvent` assertions to AC-1/AC-2 for event-stream symmetry with AC-7; cleaned a stale AC-8 comment) was in-scope test tightening.
**Test Evidence**: Integration (BLOCKING) satisfied by `tests/integration/base-production/integration_apply_action_end_to_end_test.gd` (10 tests).
**Code Review**: Complete — APPROVED (godot-gdscript-specialist APPROVE-WITH-SUGGESTIONS traced every claim vs real code incl. start_turn step-3-before-4; qa-tester TESTABLE, no must-fix, hand-proved AC-2 ordering; 2 advisories fixed in-review).
