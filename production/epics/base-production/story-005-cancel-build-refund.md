# Story 005: Cancel Build & Fixed-Point Refund

> **Epic**: Base & Production
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

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

---

## Out of Scope

- Combat destruction of structures (`destroy_entity`) — Story 007 (this story only asserts refund is *not* called on that path).
- Build placement — Story 002. Production — Story 004.
- The real end-to-end cancel via `apply_action` on the full stack — Story 010 covers the under-construction-destroyed-no-refund integration case; voluntary cancel's pure slice is here.
- Tuning the refund rate outside the default (30–60 range) — data-driven config, not a code change.

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

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`BaseProductionConfig.cancel_refund_pct`, `BuildStatus`), Story 002 (structures are placed Under-Construction, the only cancelable state).
- **Unlocks**: Story 008 (determinism covers `cancel`), Story 010 (integration exercises the under-construction-destroyed-no-refund contrast).
