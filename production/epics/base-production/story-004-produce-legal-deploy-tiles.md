# Story 004: Produce Verb & `legal_deploy_tiles`

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — Core Rule 7 (producing a unit); Edge Cases "Production & deploy"; the "Production (Rule 7)" ACs (minus the start-of-turn reset, which was implemented in Story 002 — the merged 002+003 scope).
**Requirement**: `TR-baseprod-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0017: Base & Production mechanics (D4 — `produce` + `legal_deploy_tiles`)
**Secondary ADRs**: ADR-0006 (`AP.can_afford`/`spend` for `produce_cost`), ADR-0007 (`producible_types` Resource-ref membership; Unit factory creates the deployed unit; units are instant/Active), ADR-0012 (`effective_produce_cost` Unit-owned fold + `effective_production_cap` two-sided invariant, == base under Neutral).
**ADR Decision Summary**: `legal_deploy_tiles(state, producer, unit_type)` returns empty/passable/in-bounds tiles at manhattan==1 from the producer, in canonical tile-index order. `validate_produce` gates, in order: producer Completed; `unit_type in producible_types` (Resource-ref identity, never string/enum); `units_produced_this_turn < effective_production_cap`; `AP.can_afford(effective_produce_cost)`; `tile in legal_deploy_tiles`. `apply_produce` (after validate) spends AP, creates a `UnitState` as **Active** on the tile (units have no build time — Unit Rule 2), `Grid.place`, increments the producer's counter, and re-runs `validate_produce` at commit (idempotent — rejects with no spend if preview-time conditions changed).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Resource-ref `in`-membership on the preload'd `producible_types: Array[UnitTypeDef]` is idiomatic and confirmed for 4.6. `sort_custom(Callable)` for canonical order. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`legal_deploy_tiles()` must return empty/passable/in-bounds tiles at manhattan==1 from the producer, in canonical tile-index order" — source: ADR-0017
- Required: "`validate_produce()` must gate on, in order: producer Completed; `unit_type in producible_types` (Resource-ref identity, never string/enum compare); `units_produced_this_turn < effective_production_cap`; `AP.can_afford`; tile in `legal_deploy_tiles`" — source: ADR-0017
- Required: "`apply_produce()` must re-run `validate_produce` at commit (idempotent re-validation) and reject with no spend if preview-time conditions changed" — source: ADR-0017
- Required: "`effective_production_cap` must use the two-sided invariant: base cap 0 stays 0 (a non-producer never becomes a producer via faction delta); base ≥ 1 → `max(1, base + delta)` — never a single symmetric clamp" — source: ADR-0017/ADR-0012
- Required: "Type identity must be answered by Resource-reference identity, never a parallel enum discriminator" — source: ADR-0007
- Required: "Build/Produce/CancelBuild must be typed `Action` subclasses routed by `apply_action`'s verb-enum dispatcher" — source: ADR-0017

---

## Acceptance Criteria

*Production (Rule 7):*
- [ ] **GIVEN** a Completed Production Outpost (`units_produced_this_turn` 0) with ≥ `produce_cost` AP, **WHEN** `produce(Trooper, empty adjacent tile)`, **THEN** AP spent, a Trooper created on the tile (immediately Active), counter → 1.
- [ ] **GIVEN** the HQ, **WHEN** `produce(Heavy, …)`, **THEN** rejected (Heavy not in `producible_types` — HQ makes only Scouts).
- [ ] **GIVEN** a producer at `production_cap`, **WHEN** another `produce()` with AP to spare, **THEN** rejected (cap gates **independently of AP**).
- [ ] **GIVEN** no empty adjacent tile, **THEN** production blocked, no AP spent (unit has nowhere to stand).
- [ ] **GIVEN** an Under-Construction producer, **WHEN** `produce()`, **THEN** rejected (production requires Completed status).
- [ ] **GIVEN** a producer destroyed or no longer Completed between preview and commit, **WHEN** `produce()` commits, **THEN** rejected — no unit, no AP spent (mirrors the deploy-tile commit re-validation).
- [ ] **GIVEN** a producer's `effective_production_cap` with base cap 0 (e.g. Economy Outpost), **THEN** it stays 0 (no faction delta can make it a producer); with base ≥ 1, `effective_production_cap == max(1, base + delta)`; under Neutral `== base` exactly.
- [ ] **GIVEN** the chosen deploy tile is occupied/off-board/Impassable at commit, **THEN** `produce()` re-validates and rejects — no unit, no AP spent.

---

## Implementation Notes

*Derived from ADR-0017 (D4):*

- **`legal_deploy_tiles(state, producer, unit_type) -> Array[Vector2i]`** (`BaseProduction`): empty/passable/in-bounds N→E→S→W neighbours of the producer at manhattan==1; `sort_custom(_by_tile_index)` for canonical order. Mirror `legal_build_tiles`' ordering discipline.
- **Produce verb**: a typed `ProduceAction` subclass (ADR-0002). `validate_produce(state, producer, unit_type, tile)` applies the 5 gates in the stated order (all pure, no mutation): (1) producer `build_status == COMPLETED`; (2) `unit_type in producer.type.producible_types` — **Resource-ref membership** against the preload'd registry, never a string/enum compare; (3) `producer.units_produced_this_turn < effective_production_cap(state, producer, owner)`; (4) `AP.can_afford(state, owner, Unit.effective_produce_cost(state, unit_type, owner))` — Unit-owned cost, ADR-0012 fold; (5) `tile in legal_deploy_tiles(state, producer, unit_type)`. Any failure → `ActionResult{ok=false, reason}`.
- **`apply_produce`** (only after validate passes, same atomic action): `AP.spend(cost)`; create a `UnitState` via the Unit epic's factory (ADR-0007 schema) as **Active** on `tile` (no build time — Unit Rule 2); `Grid.place`; `producer.units_produced_this_turn += 1`; append the unit's spawn event. Re-validation at commit is idempotent (ADR-0002): if the deploy tile or producer status changed between preview and commit, `apply` re-runs `validate_produce` and rejects with no spend.
- **`effective_production_cap(state, producer, player) -> int`** — the **two-sided** invariant (ADR-0012/ADR-0017 Risk): base cap 0 → 0 (a non-producer never becomes a producer via faction delta); base ≥ 1 → `max(1, base + delta)`. Never a single symmetric `max(0, …)` clamp. Under Neutral == base. The cap gate (3) is checked before AP (4), so an at-cap producer is rejected even with AP to spare.
- **Start-of-turn reset of `units_produced_this_turn`** was implemented in **Story 002** (the merged 002+003 `reset_turn_flags`, `TR-baseprod-009`) — not here. This story assumes the counter is whatever state passes in.
- **Performance**: no perf impact expected — `legal_deploy_tiles` is a 4-neighbour (manhattan==1) scan; `validate_produce` is O(`producible_types`). No hot-loop or per-frame cost.

---

## Out of Scope

- Start-of-turn reset of `units_produced_this_turn` (→ 0) — already implemented in Story 002 (merged 002+003, Rule 7 reset half).
- The real Unit-entity integration end-to-end (real Production Outpost produces a real Active, selectable Unit on the board) — Story 010 (Integration). Here, pure tests fabricate a Completed producer against injected Grid + AP fixtures; the Unit factory is exercised at unit-of-code level.
- Non-Neutral faction cap/cost delta *values* — Faction epic; here `effective_*` == base under Neutral.
- Build placement — Story 002. Cancel — Story 005. Defensive attack — Story 006.

---

## QA Test Cases

- **AC-produce-basic (Rule 7)**: Given a Completed Production Outpost (counter 0), ≥ produce_cost AP / When `produce(Trooper, empty adjacent tile)` / Then AP spent, Trooper created Active on the tile, counter → 1.
- **AC-producible-membership**: Given the HQ / When `produce(Heavy, …)` / Then rejected (Heavy not in HQ's `producible_types`).
- **AC-cap-gates-independently-of-AP (Edge)**: Given a producer at `production_cap` with AP to spare / When `produce()` / Then rejected — cap gate fires before/independently of AP.
- **AC-no-empty-tile**: Given no empty adjacent tile / Then production blocked, no AP spent.
- **AC-under-construction-producer**: Given an Under-Construction producer / When `produce()` / Then rejected (requires Completed).
- **AC-commit-revalidation (producer)**: Given the producer destroyed / no longer Completed between preview and commit / When commit / Then rejected, no unit, no AP spent.
- **AC-commit-revalidation (deploy tile)**: Given the deploy tile occupied/off-board/Impassable at commit / Then rejected, no unit, no AP spent.
- **AC-effective-cap two-sided**: Given base cap 0 producer / Then `effective_production_cap == 0`; given base ≥ 1 / Then `max(1, base+delta)`; under Neutral == base.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/produce_legal_deploy_tiles_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/base-production/produce_legal_deploy_tiles_test.gd` (13 tests, passing)

---

## Dependencies

- **Depends on**: Story 001 (schema/registry — `producible_types`, `BuildStatus.COMPLETED`, `StructureTypes`) and Story 002 (merged 002+003 — build + `advance_build_timers` + `reset_turn_flags`). Realistic fixtures reach a Completed producer via Story 002 (build then advance); pure tests may fabricate a Completed producer directly.
- **Unlocks**: Story 008 (determinism covers `produce`), Story 010 (integration produces a real Unit).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 8/8 passing (all COVERED; no deferred items)
**Deviations**: All ADVISORY — (1) `action.gd` +3 additive `Reason` members (`NOT_COMPLETED`/`NOT_PRODUCIBLE`/`NOT_LEGAL_DEPLOY_TILE`); (2) new `UnitDeployedEvent`; (3) `int`-reason contract vs ADR D4's `ActionResult` sketch (matches real dispatch, per Story 002); (4) `validate_produce` adds `NO_SUCH_ENTITY`/`ILLEGAL_TARGET` producer-resolution preconditions before the 5 ADR gates; (5) `effective_production_cap` faction delta deferred to Faction epic (mirrors `effective_build_cost`/`_time`).
**Test Evidence**: Logic — `tests/unit/base-production/produce_legal_deploy_tiles_test.gd` (17 tests). Full suite 436/436, exit 0.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist CLEAN; qa-tester test-hardening applied: isolated `legal_deploy_tiles` exclusion tests, apply-time rejection parity, `evt.owner`/`next_entity_id` assertions, zero-`producible_types` + high-edge cases).
**Tech debt**: BP-002 (production-inertness AC) RESOLVED by AC-5. BP-004 (cap `max(1,…)` floor unexercised under Neutral) logged → Faction epic. Attack-inertness half of BP-002 remains Combat/Story 006.
