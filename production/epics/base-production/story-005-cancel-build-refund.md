# Story 005: Cancel Build & Fixed-Point Refund

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — Core Rule 10 (voluntary cancel); the `cancel_refund` formula (Formulas); Edge Cases "Cancel & destruction"; the "Cancel (Rule 10)" and "Formulas & determinism" refund ACs.
**Requirement**: `TR-baseprod-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0017: Base & Production mechanics (D5 — `cancel_build` + refund; D6 — `cancel_refund_pct` fixed-point config)
**Secondary ADRs**: ADR-0002 (cancel verb dispatch, atomicity), ADR-0006 (AP credit), ADR-0003 (integer-only economy path).
**ADR Decision Summary**: `cancel_build(structure)` validates the structure is the owner's and `UNDER_CONSTRUCTION` (Completed structures cannot be cancelled — only combat-destroyed), then credits refund AP to the owner's pool, `Grid.remove(position)`, and erases the entity from `entities_by_id`. Refund uses **fixed-point integer percent**: `refund = build_cost * cancel_refund_pct / 100` via integer division (floors), never a float rate. The refund is returned on the `ActionResult` so the FSM/HUD render it from the query, never re-derive it. Combat destruction never calls `cancel_build`, so it never refunds.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: GDScript integer `/` truncation equals floor for the non-negative `cancel_refund_pct` operands (confirmed 4.6) — so `build_cost * 50 / 100` yields exactly `floor(build_cost × 0.5)` for 4/9/6/5 → 2/4/3/2. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`cancel_build()` must validate the structure is the owner's and `UNDER_CONSTRUCTION` (Completed structures cannot be cancelled, only combat-destroyed), then credit refund AP, `Grid.remove`, and erase the entity" — source: ADR-0017
- Required: "Cancel refund must be returned on the `ActionResult` so the FSM/HUD render it from the query, never re-derive it" — source: ADR-0017
- Required: "Cancel refund must use fixed-point integer percent: `refund = build_cost * cancel_refund_pct / 100` via integer division (floors), never a float rate" — source: ADR-0017
- Required: "Fractional gameplay coefficients must be stored as scaled integers and computed via integer ceil/floor-division" — source: ADR-0003
- Forbidden: "Never use a float cancel-refund rate (`CANCEL_REFUND_RATE: float = 0.5`) as literally written in the GDD — injects a float into the AP-refund path; the economy is integer-only" — source: ADR-0017

---

## Acceptance Criteria

*Cancel (Rule 10):*
- [ ] **GIVEN** an Under-Construction Economy Outpost / Production Outpost / Defensive Structure, **WHEN** cancelled, **THEN** `floor(cost×0.5)` = **2 / 4 / 3** AP credited, structure removed, tile empties.
- [ ] **GIVEN** a Completed structure, **WHEN** cancel attempted, **THEN** rejected (no refund, unchanged).
- [ ] **GIVEN** a structure destroyed in combat, **THEN** the refund function is never called (0 refunded — combat destruction never routes through `cancel_build`).
- [ ] **GIVEN** the refund is credited, **THEN** the returned `ActionResult` carries the refund amount (FSM/HUD read it from the result, not re-derived).

*Formula (fixed-point floor):*
- [ ] **GIVEN** `build_cost` 4 / 9 / 6, **THEN** `refund = build_cost * cancel_refund_pct / 100` = 2 / 4 / 3; **GIVEN** an odd fixture cost 5, **THEN** `5 * 50 / 100 = 2` (integer division floors, not rounds).

---

## Implementation Notes

*Derived from ADR-0017 (D5, D6):*

- **Cancel verb**: a typed `CancelBuildAction` subclass (ADR-0002). `validate_cancel(state, structure)` is pure/total: structure is owner's AND `build_status == UNDER_CONSTRUCTION`. A Completed structure → reject (only combat-destroyed). `apply_cancel` (only after validate): compute `refund = structure.type.build_cost * config.cancel_refund_pct / 100` (integer division = floor); **credit** `refund` AP to the owner's pool (via the AP credit path); `Grid.remove(structure.position)`; `entities_by_id.erase(structure.entity_id)`; append the cancel event and put `refund` on the `ActionResult` so presentation reads it (registry `balance_constant_in_presentation_layer` forbidden).
- **Refund math is integer fixed-point** (D6): `cancel_refund_pct = 50` (Story 001's config). `build_cost * 50 / 100` truncates toward zero = floor for non-negative operands: 4→2, 9→4, 6→3, 5→2. No float, no `floori(float × 0.5)`.
- **Combat destruction never refunds** (Rule 10 / AP Economy Rule 6): the terminal exit for a combat-destroyed structure is `GameState.destroy_entity` (ADR-0010, Story 007), which never calls `cancel_build`. This story's AC verifies the refund function is not on the destruction path.
- **Test migration — `CANCEL_BUILD` unregistered-sentinel re-treatment (mandatory):** registering the real `CANCEL_BUILD` handler in `GameState._ensure_dispatch_registered` flips `GameState._validators.has(Action.Verb.CANCEL_BUILD)` from `false`→`true`, which **breaks two existing tests** that currently borrow `CANCEL_BUILD` as a *guaranteed-unregistered* sentinel verb (the same way Story 002 forced BUILD→CANCEL_BUILD):
  - `tests/unit/win_check_terminal_test.gd` — `.is_false()` assertions (≈ lines 88/119/132) + a temporary register/unregister round-trip.
  - `tests/unit/apply_action_pipeline_test.gd` — `.is_false()` assertion (≈ line 73); its `unregister_verb(CANCEL_BUILD)` (≈ line 94) would now **erase the real handler**, corrupting later tests via the static `_dispatch_registered` guard.

  **Constraint:** after this story, `RESEARCH` is the **only** verb still unregistered (Research epic pending), and `apply_action_pipeline_test` already uses `RESEARCH` for its unknown-verb test (≈ line 108) — so these tests cannot simply rename `CANCEL_BUILD`→`RESEARCH`. Re-treat by pointing the "stays-unregistered" assertions at `RESEARCH`, and for the *borrow-a-temp-verb* round-trips use a **save-and-restore of an already-registered verb** (register a stub, assert, then re-register the real handler in teardown) rather than relying on a second free unregistered slot. Verify the full suite is green after migration — no test may leave `CANCEL_BUILD` unregistered in the shared dispatch table.

---

## Out of Scope

- Combat destruction of structures (`destroy_entity`) — Story 007 (this story only asserts refund is *not* called on that path).
- Build placement — Story 002. Production — Story 004.
- The real end-to-end cancel via `apply_action` on the full stack — Story 010 covers the under-construction-destroyed-no-refund integration case; voluntary cancel's pure slice is here.
- Tuning the refund rate outside the default (30–60 range) — data-driven config, not a code change.

**In scope (do not skip):** the `CANCEL_BUILD` unregistered-sentinel re-treatment in `tests/unit/win_check_terminal_test.gd` and `tests/unit/apply_action_pipeline_test.gd` (see Implementation Notes) — registering the real handler forces it.

**Performance:** no perf impact expected — `apply_cancel` is O(1): one integer refund (`build_cost * pct / 100`), one AP credit, one `Grid.remove`, one `entities_by_id.erase`. No hot-loop or per-frame cost.

---

## QA Test Cases

- **AC-cancel-refund (Rule 10)**: Given an Under-Construction Economy Outpost / When cancelled / Then 2 AP credited, removed, tile empties. Given Production Outpost / Then 4 AP. Given Defensive Structure / Then 3 AP.
- **AC-cancel-completed-rejected**: Given a Completed structure / When cancel attempted / Then rejected, no refund, unchanged.
- **AC-combat-no-refund**: Given a structure destroyed in combat / Then the refund function is never called (0 refunded).
- **AC-refund-on-result**: Given a successful cancel / Then the refund amount is on the returned `ActionResult` (presentation reads it, does not re-derive).
- **AC-refund-formula (Edge — boundary values are the point)**: Given build_cost 4/9/6 / Then `cost*50/100` = 2/4/3; Given odd cost 5 / Then `5*50/100 = 2` (floor via integer division, not round).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/cancel_build_refund_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/base-production/cancel_build_refund_test.gd` (10 tests, passing)

---

## Dependencies

- **Depends on**: Story 001 (`BaseProductionConfig.cancel_refund_pct`, `BuildStatus`), Story 002 (structures are placed Under-Construction, the only cancelable state; also established the BUILD→CANCEL_BUILD sentinel-migration precedent this story repeats for CANCEL_BUILD→RESEARCH).
- **Unlocks**: Story 008 (determinism covers `cancel`), Story 010 (integration exercises the under-construction-destroyed-no-refund contrast).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 5/5 passing (all COVERED; AC-combat-no-refund honestly scope-narrowed — full destroy_entity-vs-cancel contrast owed to Story 007/010, documented in-test)
**Deviations**: All ADVISORY — (1) `AP.credit` new Foundation refund writer (additive, review-validated correct + active-player-gated like `spend`); (2) `NOT_UNDER_CONSTRUCTION` Reason + `StructureCancelledEvent` (additive); (3) `int`-reason dispatch vs ADR D5's `ActionResult` sketch (matches real dispatch); (4) `apply_cancel` `Grid.remove` desync tripwire added during review (consistency with `apply_build`/`apply_produce`); (5) two test files migrated `CANCEL_BUILD`→`RESEARCH` (the story's in-scope re-treatment).
**Test Evidence**: Logic — `tests/unit/base-production/cancel_build_refund_test.gd` (10 tests) + 5 `AP.credit` tests in `tests/unit/ap_spend_test.gd`. Full suite 451/451, exit 0.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist CLEAN, both focal points [AP.credit + shared-RESEARCH migration] validated; qa-tester gaps GAP-1..6 all fixed: AP.credit gate tests, Grid.remove tripwire, per-type removal parity, 0-cost boundary, not-owned AP-unchanged, next_entity_id).
**Tech debt**: BP-005 (control-manifest "sole AP mutator" wording, docs-only) logged → `/create-control-manifest`.
