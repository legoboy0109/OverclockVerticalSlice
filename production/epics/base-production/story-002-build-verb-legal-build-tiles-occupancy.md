# Story 002: Build Verb, `legal_build_tiles` & Status-Agnostic Occupancy

> **Epic**: Base & Production
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/base-production.md` — Core Rules 3 (occupancy), 4 (building), 5 (placement); Edge Cases "Building & placement"; the Design-rule toggle ACs (parallel construction; Economy Tech does NOT discount `build_cost`).
**Requirement**: `TR-baseprod-003`, `TR-baseprod-004`, `TR-baseprod-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0017: Base & Production mechanics (D2 status-agnostic occupancy; D3 `legal_build_tiles`)
**Secondary ADRs**: ADR-0002 (build verb dispatch, validate-before-mutate atomicity, idempotent re-validation), ADR-0005 (Grid occupancy `place`/`occupant_at`/`is_passable`/`manhattan_distance`/`neighbors`), ADR-0006 (AP `can_afford`/`spend`), ADR-0012 (`effective_build_cost`/`effective_build_time` B&P-owned folds, == base under Neutral).
**ADR Decision Summary**: `BaseProduction` is a static utility class; `build` is a typed `Action` subclass routed by `apply_action`'s verb-enum dispatcher. `legal_build_tiles` is a pure, live query (never cached): candidate set = passable/empty/in-bounds friendly-frontier tiles (manhattan==1 of the player's own units AND structures, scanned N→E→S→W), filtered by strict `>2` manhattan standoff from every enemy structure, returned in canonical `sort_custom` tile-index order. `build()` inserts the structure into the single Grid occupancy index at placement time regardless of `BuildStatus` — no intangible-under-construction carve-out. `Grid.place` + `AP.spend` occur inside one `apply_action` so a rejected/unaffordable build leaves both untouched.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `sort_custom(Callable)` (not the deprecated string form) is the 4.6 custom-sort API. A transient dedup `Dictionary` in `legal_build_tiles` must never have its iteration order observed — only the trailing `sort_custom(_by_tile_index)` makes the returned order canonical (ADR-0003 `nondeterministic_iteration_order` ban). No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`BaseProduction` must be a static utility class (`class_name BaseProduction extends RefCounted`, no instance state), mirroring `AP`/`Movement`/`Combat`" — source: ADR-0017
- Required: "Build/Produce/CancelBuild must be typed `Action` subclasses routed by `apply_action`'s verb-enum dispatcher" — source: ADR-0017
- Required: "`build()` must insert the structure into Grid occupancy at placement time regardless of `BuildStatus` — no intangible-under-construction carve-out (Under-Construction structures block movement and are targetable)" — source: ADR-0017
- Required: "`Grid.place` + `AP.spend` must occur inside one `apply_action` (validate-before-mutate) so a rejected/unaffordable build leaves both untouched" — source: ADR-0017
- Required: "`legal_build_tiles()` must be a pure, live query, never cached; candidate set = passable/empty/in-bounds friendly-frontier tiles (manhattan==1 of the player's own units AND structures, scanned N→E→S→W), filtered by strict `>2` manhattan standoff from every enemy structure, returned in canonical `sort_custom` tile-index order" — source: ADR-0017
- Required: "The HQ must never be a candidate in `legal_build_tiles` (it is setup-placed, not a buildable type)" — source: ADR-0017
- Required: "A transient Dictionary used purely for membership/dedup must never have its iteration order observed — only a trailing `sort_custom` makes returned order canonical" — source: ADR-0017
- Required: "Faction deltas must fold in at each owning system's read site via `effective_X(...)`; base registry values must never be rewritten; == base under Neutral" — source: ADR-0012

---

## Acceptance Criteria

*Occupancy (Rule 3):*
- [ ] **GIVEN** an Under-Construction structure on tile T, **THEN** T reports movement-blocked **and** stops a DIRECT LoF walk **and** is a legal target (occupancy is status-agnostic — inherited from the shared Grid index, no carve-out).
- [ ] **GIVEN** an Impassable or occupied tile, **THEN** `build()` there is rejected / that tile is never in `legal_build_tiles`.

*Building (Rule 4):*
- [ ] **GIVEN** ≥ `build_cost` AP and a legal tile, **WHEN** `build(Economy Outpost, tile)`, **THEN** AP −4, structure placed Under-Construction, blocks/targets immediately (single atomic `apply_action`).
- [ ] **GIVEN** a fresh Under-Construction structure, **THEN** `completed_outpost_count`, production, and attack all treat it as inert (0 contribution).
- [ ] **GIVEN** the player cannot afford `build_cost`, **WHEN** `build()`, **THEN** rejected — no AP spent, no structure placed (AP unchanged, Grid unchanged).
- [ ] **GIVEN** the chosen build tile becomes occupied/illegal between preview and commit, **WHEN** `build()` commits, **THEN** re-validates and rejects — no AP spent, no structure placed.

*Placement (Rule 5):*
- [ ] **GIVEN** an empty passable tile at manhattan 1 from a friendly unit and manhattan 3 from the nearest enemy structure, **THEN** it is in `legal_build_tiles`.
- [ ] **GIVEN** manhattan 1 from a friendly **structure** (not unit) and >2 from all enemy structures, **THEN** legal (unit **or** structure satisfies adjacency).
- [ ] **GIVEN** a tile at manhattan **exactly 2** from an enemy structure, **THEN** excluded (`>2` strict required).
- [ ] **GIVEN** a tile >2 from all enemy structures but not adjacent to any friendly, **THEN** excluded.
- [ ] **GIVEN** no tile satisfies both conditions, **THEN** `legal_build_tiles` is empty (build unavailable).
- [ ] **GIVEN** the HQ during play, **THEN** it is never in `legal_build_tiles` (setup-placed, exempt).
- [ ] **GIVEN** a structure legally placed adjacent to a friendly unit that **later moves away**, **THEN** it remains in place — no post-placement re-validation.

*Design-rule toggles:*
- [ ] **GIVEN** sufficient AP for two builds in one turn, **THEN** both `build()` calls succeed the same turn (parallel construction allowed, AP-gated — no per-turn build-order cap in the VS).
- [ ] **GIVEN** a player who has researched Economy Tech, **WHEN** they build an Economy Outpost, **THEN** `effective_build_cost` is unmodified (flat **4** AP) — Economy Tech affects `ap_income` only, not `build_cost`; the removed `economy_outpost_discount` hook must not be reintroduced. Under Neutral, `effective_build_cost == base` exactly.

---

## Implementation Notes

*Derived from ADR-0017 (D2, D3):*

- **`BaseProduction` static class** (`src/core/base_production/base_production.gd`, `class_name BaseProduction extends RefCounted`) — mirror the shape of `src/core/combat/combat.gd`. This story creates the class file and its first members: `legal_build_tiles`, `validate_build`, `apply_build`, `effective_build_cost`, `effective_build_time`.
- **`legal_build_tiles(state, player, structure_type) -> Array[Vector2i]`** per ADR-0017 D3: candidate universe = passable/empty/in-bounds N→E→S→W neighbours of the player's OWN entities (units AND structures — the friendly frontier IS the exact adjacency==1 candidate set); filter each by `_clears_enemy_standoff` (`manhattan(t, enemy_struct) > 2` for EVERY enemy structure); dedup via a transient membership `Dictionary` whose iteration order is never observed; `out.sort_custom(_by_tile_index)` for canonical `y*W+x` ascending order. Live — never cached. HQ is never offered as a `structure_type`. `structure_type` does not change placement legality in the VS (forward-compat / signature-alignment param).
- **Build verb**: a typed `BuildAction` subclass (ADR-0002, one file, `class_name`, `verb` set in `_init()`). `validate_build(state, player, structure_type, tile)` is pure/total: checks `AP.can_afford(effective_build_cost)` AND `tile in legal_build_tiles`. `apply_build` (only after validate passes, same atomic action): `AP.spend(effective_build_cost)`; create a `StructureState` `build_status = UNDER_CONSTRUCTION`, `build_turns_remaining = effective_build_time(...)`; `Grid.place` into occupancy **at build time regardless of status** (D2 — no intangible carve-out); append the placement event. Idempotent re-validation at commit (ADR-0002).
- **`effective_build_cost`/`effective_build_time`** are B&P-owned `effective_X` sites (ADR-0012): `max(base_cost + delta, floor)` / `max(base_time + delta, MIN_BUILD_TIME)`, taking `player` explicitly. **Under Neutral, `== base` exactly.** Economy Tech does NOT route through `effective_build_cost` — its benefit is entirely AP Economy's `ap_income` (the `economy_outpost_discount` hook was removed 2026-07-21); the "flat 4 AP" AC is a regression guard against that hook reappearing.
- **Occupancy is status-agnostic (D2)**: because occupancy is the single Grid index that Movement (any occupant is a hard blocker) and Combat (any structure occupant is a legal target and blocks DIRECT LoF) already consult, an Under-Construction structure blocks and is targetable *by construction* — no new branch. The Rule-3 ACs verify this against the shared index; do not add a per-status carve-out.

---

## Out of Scope

- Build-timer advance / completion transition — Story 003 (`advance_build_timers`). This story places structures Under-Construction; they do not complete here.
- Production / deploy tiles — Story 004.
- Cancel + refund — Story 005.
- The real end-to-end `apply_action` integration against the full stack (real Grid + AP + Turn Manager) — Story 010. This story tests against injected Grid + AP fixtures (Pure-Logic gate).
- Non-Neutral faction delta *values* (the asymmetry prototype) — Faction epic; here `effective_*` == base under Neutral only.

---

## QA Test Cases

- **AC-occupancy (Rule 3)**: Given an Under-Construction structure on T / Then T movement-blocked AND stops a DIRECT LoF walk AND is a legal target. Given Impassable/occupied tile / Then `build()` rejected and never in `legal_build_tiles`.
- **AC-building (Rule 4)**: Given ≥ build_cost AP + legal tile / When `build(Economy Outpost, tile)` / Then AP −4, placed Under-Construction, blocks/targets immediately. Given a fresh Under-Construction structure / Then inert for count/production/attack (0 contribution).
- **AC-unaffordable**: Given AP < build_cost / When `build()` / Then rejected, AP unchanged, Grid unchanged (atomicity).
- **AC-commit re-validation**: Given the build tile occupied between preview and commit / When `build()` commits / Then rejected, no AP spent, no structure.
- **AC-placement legal**: Given empty passable tile at manhattan 1 from a friendly unit and manhattan 3 from nearest enemy structure / Then in `legal_build_tiles`.
- **AC-placement adjacency (structure)**: Given manhattan 1 from a friendly structure, >2 from all enemy structures / Then legal.
- **AC-standoff boundary (Edge)**: Given a tile at manhattan **exactly 2** from an enemy structure / Then **excluded** (`>2` strict — boundary value is the point).
- **AC-no-adjacency**: Given >2 from all enemy structures but not adjacent to any friendly / Then excluded.
- **AC-empty set**: Given no tile satisfies both conditions / Then `legal_build_tiles` empty (build unavailable).
- **AC-HQ excluded (Edge)**: Given the HQ during play / Then never in `legal_build_tiles`.
- **AC-post-placement stability**: Given a structure placed adjacent to a friendly unit that later moves away / Then it remains in place (no re-validation).
- **AC-parallel construction**: Given AP for two builds in one turn / Then both `build()` succeed the same turn.
- **AC-economy-tech no-discount (regression guard)**: Given a player with Economy Tech / When they build an Economy Outpost / Then `effective_build_cost == 4` (unmodified); under Neutral `effective_build_cost == base` exactly.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/build_verb_legal_build_tiles_occupancy_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`StructureTypeDef`/`StructureState`/`StructureTypes`/`BaseProductionConfig`). Uses the already-shipped Grid (Foundation, Complete) and AP (Foundation, Complete).
- **Unlocks**: Story 003 (timer advance over placed structures), Story 004 (produce needs Completed producers), Story 005 (cancel needs Under-Construction structures), Story 010 (integration).
