# Story 007: Structure Destruction & HQ Win-Hook (Real-Schema Coverage)

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — Core Rule 9 (structure damage and destruction); Edge Cases "If an HQ's hp reaches 0", "If a Defensive Structure (or any structure) stands on a Cover tile"; the "Destruction & win-hook (Rule 9, pure slice)" ACs; the Shots-to-kill audit / cover-immunity paragraph (Formulas).
**Requirement**: `TR-baseprod-011`, `TR-baseprod-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Combat resolution (`destroy_entity`, `StructureDestroyedEvent`, win-check, structure cover-immunity)
**Secondary ADRs**: ADR-0007 (real `StructureState` schema — supersedes the stubs Combat's structure tests used).
**ADR Decision Summary**: Death/removal is the single shared `GameState.destroy_entity(entity_id) -> Array[Event]` mutation-layer method, called from inside `Combat.apply()`; it runs (a) forward Lab-revert if applicable, (b) `GridState.remove()`, (c) drop from `entities_by_id`, (d) append the destroyed event — all synchronously in the same `apply_action`. `run_win_check` scans the commit's events for a `StructureDestroyedEvent` with `is_hq == true` (no separate HQ hp re-scan). Structures are cover-immune: `cover_reduction` is always 0 for a `StructureState` defender.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `destroy_entity()` may only be called from inside a verb handler's `apply()`, never mid-iteration over `entities_by_id`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Death/removal must be a single shared `GameState.destroy_entity(entity_id) -> Array[Event]` mutation-layer method, called from inside `Combat.apply()`" — source: ADR-0010
- Required: "`destroy_entity()` must run, in order: (a) forward `Research.on_lab_destroyed()` if the entity is a Lab with an active target, (b) `GridState.remove()`, (c) drop from `entities_by_id`, (d) append the destroyed event — all synchronously in the same `apply_action`" — source: ADR-0010
- Required: "`run_win_check(state, events)` must scan the commit's events for a `StructureDestroyedEvent` with `is_hq == true` — no separate HQ hp re-scan" — source: ADR-0010
- Required: "Damage formula … with `cover_reduction` always 0 for `StructureState` (structures cover-immune)" — source: ADR-0010
- Forbidden: "Never re-scan all HQ hp on every `apply_action` for the win-check — key off the `StructureDestroyedEvent{is_hq}`" — source: ADR-0010

> **Coverage note**: `destroy_entity` and `StructureDestroyedEvent{is_hq}` are already shipped (Combat epic, Story 005). Combat's structure-destruction tests used the **stubs**. This story is **real-`StructureState` coverage** (Story 001 schema) — re-verify destruction, the HQ win-signal, and cover-immunity against the real schema. It does not re-implement `destroy_entity`.

---

## Acceptance Criteria

*Destruction & win-hook (Rule 9, pure slice):*
- [ ] **GIVEN** a real `StructureState`'s hp set to 0, **THEN** it → Destroyed and a Grid `remove` is invoked for its tile the same step (entity erased from `entities_by_id`, tile empties).
- [ ] **GIVEN** an **HQ** reaching 0 hp, **THEN** the resolution raises an **observable HQ-destroyed win-signal** — an `hq_destroyed` / `is_hq == true` outcome on the returned `Result` (pure slice), which a real Turn Manager turns into `match_status == GameOver` with `winner == opponent` (Story 010).
- [ ] **GIVEN** a **non-HQ** structure reaching 0 hp, **THEN** **no** win-signal is raised.
- [ ] **GIVEN** a structure defender on a Cover tile, **THEN** Cover confers **no** damage reduction (`cover_reduction == 0`) — structures are cover-immune; the structure mitigates only through its own `defense`.

---

## Implementation Notes

*Derived from ADR-0010 (already-shipped `destroy_entity`) applied to the real schema:*

- Structures flow through the already-shipped `GameState.destroy_entity` (ADR-0010, Combat Story 005) and `StructureDestroyedEvent{is_hq}`. This story does **not** re-write that path — it adds **real-`StructureState`** coverage (Combat's structure-destruction tests used `structure_state_stub.gd` / `structure_stub.gd`; re-verify with the real schema from Story 001).
- **hp 0 → Destroyed + Grid remove same step**: assert against the real `StructureState` that at hp 0 the entity is erased from `entities_by_id` and `GridState.remove(position)` runs in the same resolution step (tile empties at once). "Destroyed"/"Removed" are terminal erasure exits, not stored states (ADR-0017 D1).
- **HQ win-signal**: an HQ (`StructureTypes.HQ`) at 0 hp appends `StructureDestroyedEvent{is_hq == true}` — observable on the `Result` (pure slice; no test-double spy needed). A non-HQ structure appends a destroyed event **without** `is_hq`, raising no win-signal. `run_win_check` keys off the event, never a hp re-scan.
- **Cover-immunity** (Combat Rule 6 / `TR-combat-002`): confirm via Combat's damage formula that a `StructureState` defender's `cover_reduction` is always 0, whatever tile it stands on — so an HQ's mitigation is exactly its `defense 2`, never `defense + cover`. This closes the floor-lock trap by rule (cross-reference the shots-to-kill audit paragraph in the GDD Formulas section). Structures may still legally occupy Cover tiles; Cover simply confers no reduction.

---

## Out of Scope

- Re-implementing `destroy_entity` / `StructureDestroyedEvent` / `run_win_check` — shipped in the Combat epic; this story is real-schema coverage only.
- The real end-to-end HQ 0hp → `GameOver(winner=opponent)` + subsequent-action-rejection via the real Turn Manager — Story 010 (Integration). Here the pure slice asserts the observable `is_hq` signal on the Result.
- Under-construction-destroyed-no-refund end-to-end — Story 010 (the refund-not-called contrast is Story 005's pure slice).
- Combat's damage formula itself — Combat epic (Complete); cross-referenced for the cover-immunity confirmation.

---

## QA Test Cases

- **AC-destruction (Rule 9)**: Given a real `StructureState`'s hp set to 0 / Then Destroyed, `entities_by_id` erased, and a Grid `remove` invoked for its tile the same step (tile empties).
- **AC-hq-win-signal**: Given an HQ reaching 0 hp / Then an observable `is_hq == true` / `hq_destroyed` outcome on the Result (a real Turn Manager → `GameOver`, `winner == opponent` — Story 010).
- **AC-non-hq-no-signal**: Given a non-HQ structure reaching 0 hp / Then no win-signal.
- **AC-cover-immunity**: Given a structure defender on a Cover tile / Then `cover_reduction == 0` (structures cover-immune); mitigation is its own `defense` only. Edge: HQ (def 2) on Cover mitigates exactly 2, never 3 — floor-lock trap closed by rule.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/structure_destruction_hq_win_hook_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/base-production/structure_destruction_hq_win_hook_test.gd` (4 tests, passing)

---

## Dependencies

- **Depends on**: Story 001 (real `StructureState` + HQ template) + Combat epic (Complete — `destroy_entity`, `StructureDestroyedEvent{is_hq}`, `run_win_check`, damage formula / cover-immunity).
- **Unlocks**: Story 010 (integration exercises the real HQ 0hp → `GameOver` + subsequent-reject path).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 4/4 passing (all COVERED; HQ-win-signal and cover-immunity mutation-verified load-bearing)
**Deviations**: None — no `src/` change. `destroy_entity`/`StructureDestroyedEvent{is_hq}`/`run_win_check`/cover-immunity were all shipped and correct for the real schema (Combat epic Story 005); this story is real-`StructureState`-schema coverage in the B&P suite. Intentional (documented) overlap with `tests/unit/combat/destroy_entity_test.gd`.
**Test Evidence**: Logic — `tests/unit/base-production/structure_destruction_hq_win_hook_test.gd` (4 tests). Full suite 460/460, exit 0.
**Code Review**: Complete — APPROVED (godot-gdscript-specialist CLEAN — verified static typing, `Combat.damage`-purity on un-placed entities, cover math, `run_win_check` winner logic, `Research.reset()` isolation; qa-tester TESTABLE with live mutation testing — forcing `is_hq=false` → 3 hard failures, setting `cover_dr=0` → the differential control fails, proving both are load-bearing not decorative; no must-fix). Advisory (not blocking): add an `is_hq`-false mutation-style assertion to the non-HQ test for evidence parity with the HQ test.
**Tech debt**: None new.
