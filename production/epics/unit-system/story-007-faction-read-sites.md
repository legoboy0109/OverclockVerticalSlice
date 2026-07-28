# Story 007: Faction Identity Read-Sites — effective_produce_cost / effective_move_cost

> **Epic**: Unit System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/unit-system.md`
**Requirement**: `TR-unit-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Faction identity modifier framework
**Secondary ADRs**: ADR-0007 (base cost fields).
**ADR Decision Summary**: Faction deltas fold into a closed set of domains at read-sites via `effective_X(state, ..., player)` functions; under the Neutral default every `effective_X == base_X` exactly; combat stats are identity-locked (not folded).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: "Under Neutral, `effective_X == base_X` must hold exactly for every domain (regression-pinned by a parametrized test)" — source: ADR-0012
- Required: "Every `effective_X` takes `player` as an explicit argument so the AI reads faction-correct values at the same call sites" — source: ADR-0012
- Required: "Faction delta lookup keyed by Resource-reference `type` identity, never string/enum" — source: ADR-0012

---

## Acceptance Criteria

- [ ] **GIVEN** the Neutral faction is active, **WHEN** `effective_produce_cost`/`effective_move_cost` are computed for any type, **THEN** they equal base exactly (no-op under Neutral) — parametrized across all 4 types.
- [ ] **GIVEN** a faction with a `FactionUnitDelta` for a type, **WHEN** the effective cost is computed, **THEN** `base + delta`, floored (`max(1, ...)` produce cost; `max(MIN_MOVE_COST, ...)` move cost) — never below floor even with a large negative delta.
- [ ] **GIVEN** combat stats (`attack`/`defense`/`attack_range`) are read for any unit, **THEN** they remain faction-identity-locked (unaffected by deltas) — only cost/mobility fold.

---

## Implementation Notes

*Derived from ADR-0012 guidelines:*

- `effective_produce_cost(state, unit_type, player) = max(1, base_produce_cost(type) + (d.cost_delta if d else 0))`; `effective_move_cost(state, unit_type, player) = max(MIN_MOVE_COST, base_move_cost(type) + (d.move_cost_delta if d else 0))`.
- `d = Faction.unit_delta(faction, type)` — linear scan over a roster-sized `Array[FactionUnitDelta]`, keyed by Resource-reference `type` identity (never string/enum).
- **Move-cost floor = `1`.** ADR-0012 §3 and unit-system.md both state *"`MIN_MOVE_COST` already exists (Movement's Approved `move_cost ≥ 1`)"* — but that floor was only ever a **conceptual** rule; a grep confirms **no named `MIN_MOVE_COST` symbol exists in `src/`**. This story materializes it as a Unit-owned constant `const MIN_MOVE_COST := 1` on `Unit` (`src/core/unit/unit.gd`, alongside the `effective_*` functions), so AC-2's `max(MIN_MOVE_COST, …)` binds to a real symbol rather than a magic literal. The produce-cost floor stays the literal `max(1, …)` per ADR-0012 §3's formula — both floors are value 1; only the move floor gets a named const (it's the one the ADR names).
- **No-op under Neutral is the load-bearing regression test** — parametrized across all 4 types × 2 domains.
- Combat stats explicitly NOT folded here (faction-identity.md CR-6).

### Stubs this story creates (minimal forward-declares; ADR-0012 §1 is the schema authority)

The full `FactionDef` schema, `Factions` registry, and tuned delta values are the Faction Identity epic's (Out of Scope). But this story's two `effective_X` functions can't compile or be Neutral-tested without minimal faction *types* — so, exactly as `src/core/faction/faction_def.gd` is already a documented stub ("*replaced by the Faction Identity epic — do not add fields beyond what this story's tests require*"), Story 007 creates these **minimal** forward-stubs, each a strict subset of ADR-0012 §1 so the Faction epic supersedes them with zero rework:

1. **`FactionUnitDelta`** (`src/core/faction/faction_unit_delta.gd`, `class_name FactionUnitDelta extends Resource`) — only the two fields this story folds: `@export var type: UnitTypeDef = null` and `@export var cost_delta: int = 0`, `@export var move_cost_delta: int = 0`. (`soft_move_cap_delta`/`combat_delta` from ADR-0012 §1 are out of this story's two-domain scope — the Faction epic adds them.)
2. **`FactionDef`** — extend the existing stub with `@export var unit_deltas: Array[FactionUnitDelta] = []` (ADR-0012 §1 field name, exact).
3. **`Factions.NEUTRAL`** — a `data/factions/neutral.tres` (a `FactionDef` with empty `unit_deltas`) preloaded as `const NEUTRAL := preload("res://data/factions/neutral.tres")` on a minimal `Factions` registry (`class_name Factions`), matching ADR-0012 line 139 exactly (Resource-ref identity, so AC-1's Neutral no-op is a genuine registry read, not a fresh `.new()`).
4. **`Faction.unit_delta(f, type)`** (`class_name Faction extends RefCounted`, static utility mirroring `AP`/`Movement`/`Combat`/`BaseProduction`) — the exact linear scan from ADR-0012 (line 171): returns the matching `FactionUnitDelta` by Resource-ref `type` identity, or `null`.
5. **`Unit.effective_produce_cost`/`Unit.effective_move_cost`** — this story's actual production code, on `Unit` (`src/core/unit/unit.gd`), mirroring the existing `Unit.effective_attack`/`effective_defense` (Story 004) placement and signature shape `effective_X(state, unit_type, player)`.

`base_produce_cost(type)`/`base_move_cost(type)` in the pseudocode are just `type.produce_cost`/`type.move_cost` (the `UnitTypeDef` fields from Story 001) — no separate accessor is owed.

---

## Out of Scope

- Faction Identity epic: the **full** `FactionDef` schema (all 6 domains — this story stubs only `unit_deltas`), the **populated** `Factions` registry (this story ships only an empty-delta `NEUTRAL`), `FactionUnitDelta`'s remaining fields (`soft_move_cap_delta`/`combat_delta`), and **any tuned non-Neutral delta values** (the asymmetry prototype — deferred; every delta here is identity under Neutral). The minimal stubs this story *does* create are enumerated in Implementation Notes above.

---

## QA Test Cases

- **AC-1 (Neutral no-op)**: Given `Factions.NEUTRAL` (empty deltas) / When computed for each of 4 types × 2 domains / Then equals base for all 8. Edge: parametrize across all types.
- **AC-2 (delta fold + floor)**: Given a test-built `FactionDef` with `FactionUnitDelta{type: Trooper, cost_delta: -10}` / When `effective_produce_cost(Trooper)` / Then `max(1, 4-10) == 1`, never ≤0. Edge: `cost_delta: +3` → `7`, no ceiling.
- **AC-3 (combat stats locked)**: Given a faction with (test-only) attempted combat deltas / When `effective_attack`/`effective_defense`/`attack_range` are read / Then unaffected — guards that no refactor routes combat stats through this story's functions.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/unit-system/faction_read_sites_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`base_produce_cost`/`base_move_cost`); Faction Identity epic's `FactionDef`/`Factions` (cross-epic — write against a minimal Neutral-only stub if Faction lands later).
- Unlocks: Faction Identity asymmetry prototype; AI epic (reads `effective_X` at the same sites).

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 3/3 passing (no deferred items)
**Deviations**: None. `PlayerState.faction` + `GameState.faction_of(player)` already existed, so `effective_X` reads faction directly — no ADR-0001/`PlayerState`/`GameState` edit needed, and `Faction` ships only `unit_delta`. `Factions` is `class_name` + `const` (not an autoload), so no `project.godot` change.
**Test Evidence**: Logic — `tests/unit/unit-system/faction_read_sites_test.gd` (11 tests; full suite 370/370, exit 0). Coverage strengthened during code review: relabeled a vacuous `attack_range` assertion to an honest by-design note; added per-player-isolation and non-matching-type-miss-path tests.
**Code Review**: Complete — `/code-review` APPROVED (gdscript-specialist CLEAN; qa-tester TESTABLE, gaps applied).
**Note (CI-relevant)**: adding new `class_name` scripts required a one-time `./redot --headless --quit --editor` rescan to regenerate `.godot/global_script_class_cache.cfg` before `gdunit4_runner.gd` compiled. Flagged for CI — future stories adding `class_name` scripts may need a project rescan step.
