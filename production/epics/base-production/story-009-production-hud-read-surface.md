# Story 009: Production HUD Read-Surface

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: UI
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — "UI Requirements" section (build menu, legal-build/deploy overlays, build-progress + production readouts, cancel affordance, structure hp).
**Requirement**: `TR-baseprod-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (read-only `GameStateReader` facade)
**Secondary ADRs**: ADR-0017 (the queries being surfaced: `legal_build_tiles`/`legal_deploy_tiles`/`production_cap`/cancel-refund), ADR-0006 (affordability).
**ADR Decision Summary**: The HUD is injected with a `GameStateReader` facade (getters only) — never the live mutable `GameState` — so a mutating call is structurally unreachable, not just review-forbidden. This story exposes the B&P read-surface through that facade: `legal_build_tiles`, `legal_deploy_tiles`, build-timer progress, remaining `production_cap`, affordability, cancel-refund preview, and structure hp — all read-only value snapshots, no mutation path.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: The facade returns value snapshots (no live `GameState` reference leaks). Mirror the just-shipped `src/core/game_state/game_state_reader.gd` `unit_info` pattern — a getters-only facade. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "The HUD must be injected with a `GameStateReader` facade (getters only) — never the live mutable `GameState` — so a mutating call is structurally unreachable" — source: ADR-0016
- Required: "Cancel refund must be returned on the `ActionResult` / read from the query, never re-derived in presentation" — source: ADR-0017
- Required: "`menu_model()` / presentation must reach cost/legality data only by calling an owning system's side-effect-free query — never hold or reference a balance constant by name (Pass-Through Invariant)" — source: ADR-0015/ADR-0016
- Forbidden: "Never let the HUD read the live mutable `GameState` directly" — source: ADR-0016

> **Facade contract**: this is a *read-surface* story — it exposes B&P queries through the getters-only `GameStateReader` (mirror the shipped `unit_info` snapshot). It adds no mutation path and re-derives no formula (affordability and cancel-refund come from the owning queries, not a local recompute).

---

## Acceptance Criteria

- [ ] **GIVEN** a selected buildable structure type and a player, **WHEN** the read-surface is queried, **THEN** it exposes `legal_build_tiles(player, type)` as a read-only value snapshot (no live `GameState` reference).
- [ ] **GIVEN** a selected producer and unit type, **THEN** the surface exposes `legal_deploy_tiles(producer, type)` read-only.
- [ ] **GIVEN** an Under-Construction structure, **THEN** the surface exposes its build-timer progress (turns remaining) read-only.
- [ ] **GIVEN** a producer, **THEN** the surface exposes its remaining `production_cap` this turn (`effective_production_cap − units_produced_this_turn`) read-only.
- [ ] **GIVEN** a buildable/producible action, **THEN** the surface exposes affordability (from `AP.can_afford` on `effective_build_cost` / `effective_produce_cost`) — never a locally re-derived cost.
- [ ] **GIVEN** an Under-Construction structure, **THEN** the surface exposes its cancel-refund preview (`floor(build_cost × 0.5)`), read from the owning query, not re-derived.
- [ ] **GIVEN** any structure, **THEN** the surface exposes its current/max hp read-only.
- [ ] **GIVEN** any read on the surface, **THEN** there is no reachable mutation path (the facade is getters-only; a mutating call does not compile / is structurally unreachable).

---

## Implementation Notes

*Derived from ADR-0016 (read-only facade):*

- Extend the shipped `src/core/game_state/game_state_reader.gd` (the getters-only facade) with B&P read accessors — mirror the existing `unit_info` value-snapshot pattern: each accessor returns a plain value / typed snapshot, never a live `GameState`/`StructureState` reference the HUD could mutate.
- **Queries surfaced** (all pass-through to the owning system, no local re-derivation): `legal_build_tiles`, `legal_deploy_tiles` (BaseProduction, Story 002/004); build-timer progress (`build_turns_remaining`); remaining `production_cap` (`effective_production_cap − units_produced_this_turn`); affordability (`AP.can_afford` on the `effective_*` cost, Story 002/004); cancel-refund preview (Story 005's refund query — read, not re-derived); structure hp (`current_hp` / `type.hp`).
- **Pass-Through Invariant** (ADR-0015/0016): the surface holds no balance constant by name and re-derives no formula — affordability and refund come from the owning queries. This keeps the HUD a pure consumer.

---

## Out of Scope

- The visual HUD widgets, overlays, and rendering (the iso overlay layer, build-progress glyphs, cancel affordance UI) — Presentation-layer Command & Action Interface / HUD epics. This story provides the *data surface* only.
- The queries themselves — Stories 002 (`legal_build_tiles`, `effective_build_cost`), 004 (`legal_deploy_tiles`, `effective_production_cap`), 005 (cancel refund). This story exposes them read-only.
- AP counter animation FSM, action log, audio dispatch — HUD epic.

---

## QA Test Cases (manual-verification / interaction-test specs)

- **Setup**: construct a `GameState` with a player owning one Under-Construction Economy Outpost (2 turns remaining), one Completed Production Outpost (counter 1 of cap 4), and a selectable Defensive Structure; wrap it in a `GameStateReader`.
  - **Verify** `legal_build_tiles(player, Economy Outpost)` returns the same tile set as the direct `BaseProduction` query, as a value snapshot. **Pass**: sets equal; the returned value cannot mutate `GameState`.
  - **Verify** `legal_deploy_tiles(Production Outpost, Trooper)` returns the producer's empty adjacent tiles read-only. **Pass**: matches the direct query.
  - **Verify** build-timer progress for the Economy Outpost reads 2 turns remaining. **Pass**: matches `build_turns_remaining`.
  - **Verify** remaining `production_cap` for the Production Outpost reads 3 (cap 4 − produced 1). **Pass**: matches `effective_production_cap − units_produced_this_turn`.
  - **Verify** affordability of a Trooper reflects `AP.can_afford(effective_produce_cost)`. **Pass**: matches the owning query; no locally-held cost constant.
  - **Verify** cancel-refund preview for the Under-Construction Economy Outpost reads 2. **Pass**: read from the refund query, not re-derived.
  - **Verify** structure hp reads current/max. **Pass**: matches `current_hp` / `type.hp`.
  - **Verify** no reachable mutation path from the facade. **Pass**: a mutating call is structurally unreachable (getters-only).

---

## Test Evidence

**Story Type**: UI (ADVISORY gate)
**Required evidence**:
- Interaction test at `tests/unit/base-production/production_read_surface_test.gd` — the chosen route (exercises the facade's read accessors; asserts value-snapshot semantics and no mutation path).

**Status**: [x] Created — `tests/unit/base-production/production_read_surface_test.gd` (19 tests, all passing)

---

## Dependencies

- **Depends on**: Stories 001–005 (the queries to expose: schema/config, `legal_build_tiles`/`effective_build_cost`, timer progress + `production_cap`, `legal_deploy_tiles`, cancel-refund). Uses the shipped `game_state_reader.gd` (`unit_info` pattern).
- **Unlocks**: The Presentation-layer Command & Action Interface / HUD epics (they consume this read-surface for build/deploy overlays and readouts).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 8/8 passing (all COVERED; see traceability). Full suite 494/494, exit 0.
**Deviations** (all ADVISORY): (1) cross-file allowlist update to `tests/unit/unit-system/unit_read_surface_test.gd` — the `["_init","unit_info"]` structural read-only allowlist was stale-by-design once this story extends the facade; grown to the 7 real getter methods, intent preserved. (2) BP-009 tech-debt: cancel-refund preview base-vs-effective indistinguishable under the Neutral roster (latent, not exploitable until a non-zero build-cost delta lands; owed to the Faction/Research epic). (3) story-readiness perf-budget advisory closed — accessors doc'd O(query), no simulation-hot-path.
**Test Evidence**: UI (ADVISORY gate) satisfied by automated interaction test `tests/unit/base-production/production_read_surface_test.gd` (19 tests). No separate evidence doc required.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist APPROVE; qa-tester TESTABLE; 1 advisory fixed in-review, BP-009 logged).
