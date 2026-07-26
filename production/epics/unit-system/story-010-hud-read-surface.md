# Story 010: HUD / Command-Interface Read-Surface (Unit Data Exposure)

> **Epic**: Unit System
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD
**Secondary ADRs**: ADR-0007 (unit fields), ADR-0010 (`BlockedReason` enum).
**ADR Decision Summary**: The HUD is injected a read-only `GameStateReader` facade, never the live mutable state; a stray mutating call from a HUD script is structurally impossible because it is never handed a write path.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW (contract confirmation; no rendering)
**Engine Notes**: None post-cutoff for this story — the HIGH-risk HUD surfaces (dual-focus) are the HUD epic's, not this read-contract.

**Control Manifest Rules (this layer)**:
- Required: "The HUD reads via a `GameStateReader`-equivalent facade, never the live mutable `GameState`/`UnitState`" — source: ADR-0016
- Forbidden: "Never expose a mutation path (setter / `apply_action`) through the read facade" — source: ADR-0016

---

## Acceptance Criteria

- [ ] **GIVEN** a unit is selected/hovered, **WHEN** the HUD read facade queries it, **THEN** it can obtain `type` (name/silhouette id), `current_hp`/`hp` (max), `effective_attack` (Story 004), `move_cost`, and `has_attacked` — through read-only accessors, with zero mutation path exposed.
- [ ] **GIVEN** the facade is handed a `UnitState`, **WHEN** any accessor is called, **THEN** no `apply_action` or setter is reachable from the object it holds — structurally enforced, not review-enforced.
- [ ] **GIVEN** a blocked shot (Combat's `BlockedReason`, ADR-0010), **WHEN** the HUD queries the reason, **THEN** it receives one of the three classifications — Unit System's job is only to expose its own fields (`attack_range`, `has_attacked`) as inputs; the enum + classification is Combat-owned.

---

## Implementation Notes

*Derived from ADR-0016 guidelines:*

- The HUD is injected a `GameStateReader` (read facade), never the live mutable state. Unit System's contribution: ensure `UnitState`'s relevant fields are reachable through the facade's getters — a `unit_info(entity_id)`-shaped accessor surfacing `type`, `current_hp`, `hp` (= `type.hp`), `effective_attack` (Story 004), `move_cost` (= `type.move_cost`), `has_attacked`.
- No new mutation surface, no new `UnitState` fields — pure plumbing/contract confirmation, the smallest footprint of the epic.
- `has-acted` dimming and hp pips are HUD-owned presentation (game-hud.md) — Unit supplies the boolean/int values only.

---

## Out of Scope

- Game HUD epic: all actual HUD rendering (Control nodes, dimming, hp pips).
- Combat epic: the `BlockedReason` enum + classification logic (ADR-0010).
- Command & Action Interface epic: action-legality presentation.

---

## QA Test Cases

*(UI-classified — manual verification via a facade test double; the underlying data path is Logic-tested in Stories 001–006.)*

- **AC-1/2 (read surface + read-only)**: Setup — construct a `GameStateReader` (or facade stub) over a `GameState` with one Trooper (`has_attacked = true`, `current_hp = 4`). Verify — the unit-info accessor returns `type.display_name == "Trooper"`, `current_hp == 4`, `hp == 6`, `effective_attack == 3` (un-researched Trooper), `move_cost == 2`, `has_attacked == true`. Pass — all five correct AND no method on the returned object permits mutation (no exposed setter / value-copy or read-only wrapper).
- **AC-2 (structural read-only)**: Setup — attempt (in a test, not production) to call a mutating method through the facade. Verify — no such method exists / compile error. Pass — confirms read-only is structural, not convention.

**Evidence doc**: `production/qa/evidence/unit-hud-read-surface-evidence.md` (walkthrough + sign-off), per UI story type.

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/unit-hud-read-surface-evidence.md` — walkthrough doc OR an interaction test at `tests/unit/unit-system/unit_read_surface_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 004 (`effective_attack`); ADR-0016's `GameStateReader` facade (Game HUD epic — define the contract now, implement against a local test double until the facade exists).
- Unlocks: Game HUD epic, Command & Action Interface epic.
