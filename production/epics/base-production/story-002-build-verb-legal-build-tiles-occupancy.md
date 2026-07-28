# Story 002: BaseProduction Lands — Build Verb, `legal_build_tiles`, Occupancy + Start-of-Turn Timers, `completed_outpost_count` & Flag Reset

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 7 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

> **⚠️ Merged story (2026-07-27):** absorbs former Story 003 (start-of-turn timers,
> `completed_outpost_count`, flag reset). Reason: the real `class_name BaseProduction`
> collides with `tests/helpers/stubs/base_production_stub.gd` (also `class_name
> BaseProduction`), whose `completed_outpost_count` (AP income, `ap.gd:46`) and
> `advance_build_timers` (start-of-turn, `game_state.gd:291`) are load-bearing. The
> stub cannot survive the real class, so those two members must land here alongside
> `build`. Former Story 003 is superseded — see `story-003-...` (Status: Superseded).

## Context

**GDD**: `design/gdd/base-production.md` — Core Rules 3 (occupancy), 4 (building), 5 (placement), 6 (completion advance at start-of-turn), 11 (`completed_outpost_count`), and the Rules 7/8 start-of-turn resets; the Design-rule toggle ACs (parallel construction; Economy Tech does NOT discount `build_cost`).
**Requirement**: `TR-baseprod-003`, `TR-baseprod-004`, `TR-baseprod-005`, `TR-baseprod-006`, `TR-baseprod-007`, `TR-baseprod-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0017 (D1 lifecycle transitions; D2 status-agnostic occupancy; D3 `legal_build_tiles`) + ADR-0008 (start-of-turn: step 2 flag reset, step 3 timer advance — before the step-4 income snapshot)
**Secondary ADRs**: ADR-0002 (build verb dispatch, validate-before-mutate atomicity, idempotent re-validation), ADR-0005 (Grid `place`/`occupant_at`/`is_passable`/`in_bounds`/`manhattan_distance`), ADR-0006 (AP `can_afford`/`spend`; `completed_outpost_count` is the AP-income contract), ADR-0012 (`effective_build_cost`/`effective_build_time` B&P-owned folds, == base under Neutral).
**ADR Decision Summary**: `BaseProduction` is a static utility class (`class_name BaseProduction extends RefCounted`). `build` is a typed `Action` subclass routed by `apply_action`'s verb-enum dispatcher. `legal_build_tiles` is a pure, live query (never cached): candidate set = passable/empty/in-bounds friendly-frontier tiles (manhattan==1 of the player's own units AND structures, scanned N→E→S→W), filtered by strict `>2` manhattan standoff from every enemy structure, returned in canonical `sort_custom` tile-index order. `build()` inserts into the single Grid occupancy index at placement time regardless of `BuildStatus` (no intangible carve-out); `Grid.place` + `AP.spend` occur in one `apply_action`. `advance_build_timers(state, player) -> Array[Event]` is the body of ADR-0008 step-3: decrement `build_turns_remaining`, flip 0→`COMPLETED`, append one `StructureCompletedEvent` per completion — before step-4 income. `Structure.reset_turn_flags` is ADR-0008 step-2's body (`units_produced_this_turn=0`, `has_attacked=false`). `completed_outpost_count(state, player)` returns alive, owned, Completed Economy Outposts only — 0, never null.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `sort_custom(Callable)` (not the deprecated string form) is the 4.6 API. A transient dedup `Dictionary` in `legal_build_tiles` must never have its iteration order observed — only the trailing `sort_custom(_by_tile_index)` makes the returned order canonical (ADR-0003 `nondeterministic_iteration_order` ban). **Grid API note:** `GridState.in_bounds`/`is_passable`/`occupant_at`/`place`/`remove` take `(x: int, y: int)` — unpack a `Vector2i n` as `n.x, n.y` (the ADR-0017 D3 pseudocode's `grid.in_bounds(n)` is shorthand); `manhattan_distance` takes `Vector2i`. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`BaseProduction` must be a static utility class (`class_name BaseProduction extends RefCounted`, no instance state), mirroring `AP`/`Movement`/`Combat`" — source: ADR-0017
- Required: "Build/Produce/CancelBuild must be typed `Action` subclasses routed by `apply_action`'s verb-enum dispatcher" — source: ADR-0017
- Required: "`build()` must insert the structure into Grid occupancy at placement time regardless of `BuildStatus` — no intangible-under-construction carve-out" — source: ADR-0017
- Required: "`Grid.place` + `AP.spend` must occur inside one `apply_action` (validate-before-mutate) so a rejected/unaffordable build leaves both untouched" — source: ADR-0017
- Required: "`legal_build_tiles()` must be a pure, live query, never cached; candidate = passable/empty/in-bounds friendly-frontier tiles (manhattan==1 of own units AND structures, N→E→S→W), filtered by strict `>2` standoff from every enemy structure, canonical `sort_custom` tile-index order" — source: ADR-0017
- Required: "The HQ must never be a candidate in `legal_build_tiles`" — source: ADR-0017
- Required: "A transient Dictionary used purely for membership/dedup must never have its iteration order observed — only a trailing `sort_custom` makes returned order canonical" — source: ADR-0017/ADR-0003
- Required: "`advance_build_timers(state, player)` must decrement `build_turns_remaining` on the player's Under-Construction structures, flip those reaching 0 to `COMPLETED`, and append one `StructureCompletedEvent` per completion (sequenced by ADR-0008 step 3, before the income snapshot); it reads no income state (commutative with `advance_research_timers`)" — source: ADR-0017/ADR-0008
- Required: "`Structure.reset_turn_flags` (ADR-0008 step 2 body) sets `units_produced_this_turn=0` and `has_attacked=false`; `GameState` owns only the timing" — source: ADR-0008
- Required: "`completed_outpost_count(state, player)`: alive owned Completed Economy Outposts only; return 0 not null; consumed by `ap_income`" — source: ADR-0006/ADR-0007
- Required: "Any order-sensitive pass over `entities_by_id` must iterate a list sorted by a stable key (`entity_id` or tile index)" — source: ADR-0003
- Required: "Faction deltas must fold in at each owning system's read site via `effective_X(...)`; base registry values never rewritten; == base under Neutral" — source: ADR-0012
- Forbidden: "Never reorder start_turn step 4 before step 3 — income must observe same-turn completions" — source: ADR-0008

---

## Acceptance Criteria

*Occupancy (Rule 3):*
- [ ] **GIVEN** an Under-Construction structure on tile T, **THEN** T reports movement-blocked **and** stops a DIRECT LoF walk **and** is a legal target (status-agnostic occupancy, no carve-out).
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
- [ ] **GIVEN** sufficient AP for two builds in one turn, **THEN** both `build()` calls succeed the same turn (parallel construction allowed, AP-gated).
- [ ] **GIVEN** a player who has researched Economy Tech, **WHEN** they build an Economy Outpost, **THEN** `effective_build_cost` is unmodified (flat **4** AP) — Economy Tech affects `ap_income` only; the removed `economy_outpost_discount` hook must not reappear. Under Neutral, `effective_build_cost == base` exactly.

*Completion advance (Rule 6, pure slice):*
- [ ] **GIVEN** an Under-Construction structure with 2 remaining build-turns, **WHEN** `advance_build_timers` runs once, **THEN** it decrements to 1 and stays Under-Construction.
- [ ] **GIVEN** one with 1 remaining, **WHEN** advance runs, **THEN** it becomes Completed and a `StructureCompletedEvent` is appended; the advance function reads no income state.
- [ ] **GIVEN** two structures both reaching 0 in the same advance call, **THEN** both Complete in that one call (batch), each appending its own completion event.

*`completed_outpost_count` (Rule 11):*
- [ ] **GIVEN** {2 Completed Economy Outposts, 1 Under-Construction Economy Outpost, 1 Completed Production Outpost, 1 HQ}, all one player's, **THEN** the query returns exactly **2**.
- [ ] **GIVEN** an opponent-owned Completed Economy Outpost, **THEN** excluded for this player.
- [ ] **GIVEN** a Completed Economy Outpost destroyed this step, **THEN** excluded (alive-only). **GIVEN** none qualify, **THEN** returns **0** (not null).
- [ ] **GIVEN** a Completed **Research Lab** and a Completed **Defensive Structure** owned by the player, **THEN** both excluded — only Economy Outposts count.

*Start-of-turn flag reset (Rules 7, 8):*
- [ ] **GIVEN** start-of-turn reset for a player, **THEN** `units_produced_this_turn` → 0 for that owner's producers (Rule 7).
- [ ] **GIVEN** start-of-turn reset for a player, **THEN** `has_attacked` → false for that owner's Defensive Structures (Rule 8).

---

## Implementation Notes

*Derived from ADR-0017 (D1/D2/D3) and ADR-0008:*

- **`BaseProduction` static class** (`src/core/base_production/base_production.gd`, `class_name BaseProduction extends RefCounted`) — mirror `src/core/combat/combat.gd`. This story creates the real class with: `legal_build_tiles`, `validate_build`, `apply_build`, `effective_build_cost`, `effective_build_time`, `advance_build_timers`, `completed_outpost_count`. It also carries `defensive_attack_cost()` reading `StructureBalance.base_production.defensive_attack_cost` (Story 001's config) for Combat's existing consumer.
- **`legal_build_tiles(state, player, structure_type) -> Array[Vector2i]`** per ADR-0017 D3: candidate universe = passable/empty/in-bounds N→E→S→W neighbours of the player's OWN entities (units AND structures); filter each by `_clears_enemy_standoff` (`manhattan(t, enemy_struct) > 2` for EVERY enemy structure); dedup via a transient membership `Dictionary` whose iteration order is never observed; `out.sort_custom(_by_tile_index)` for canonical `y*W+x` order. Live, never cached. HQ never offered. Remember the `(x,y)`-int Grid API (unpack `Vector2i`).
- **Build verb**: a typed `BuildAction` subclass (ADR-0002; `verb` set in `_init()`). `validate_build` is pure/total (`AP.can_afford(effective_build_cost)` AND `tile in legal_build_tiles`); `apply_build` (post-validate, atomic): `AP.spend`, create `StructureState{UNDER_CONSTRUCTION, build_turns_remaining = effective_build_time}`, `Grid.place` at build time regardless of status (D2), append placement event; idempotent re-validation at commit.
- **`effective_build_cost`/`effective_build_time`** (ADR-0012, B&P-owned, take `player`): `max(base + delta, floor)`. **Under Neutral, == base exactly.** Economy Tech does NOT route through `effective_build_cost` (that hook was removed; the flat-4 AC guards against its return).
- **`advance_build_timers(state, player) -> Array[Event]`** (ADR-0008 step-3 body): iterate the player's Under-Construction structures in stable `entity_id` order; decrement `build_turns_remaining`; flip 0→`COMPLETED` appending one `StructureCompletedEvent` each; batch-safe. Reads no income state (stays commutative with `advance_research_timers`). ADR-0008 owns that `game_state.start_turn` calls it at step 3 before the step-4 income snapshot — the call site `game_state.gd:291` already exists (against the stub); this replaces the stub body.
- **`Structure.reset_turn_flags(structure)`** (ADR-0008 step-2 body): `units_produced_this_turn = 0`, `has_attacked = false`. The `structure_stub.gd` (`class_name Structure`) already provides a `reset_turn_flags` that Story 001 pointed at the real `has_attacked`; this story confirms/extends it to also reset `units_produced_this_turn` (or moves it to a real `Structure` class — implementer's call, but `class_name Structure` collision means if a real `Structure` is created the stub must go too; simplest is to keep `structure_stub.gd`'s `Structure.reset_turn_flags` as the real body for now and add `units_produced_this_turn=0`).
- **`completed_outpost_count(state, player) -> int`** (ADR-0006 contract): count structures where `type == StructureTypes.ECONOMY_OUTPOST` AND `build_status == COMPLETED` AND alive/owned. Excludes U/C econ, opponent, destroyed, HQ, Production Outpost, Defensive Structure, Research Lab. **0, never null.** Replaces `base_production_stub.gd`.
- **Occupancy is status-agnostic (D2)** — Under-Construction structures block/target by construction of the shared Grid index; no per-status carve-out.

### Stub migration (approved — `class_name BaseProduction` collision)

The real `BaseProduction` collides with `tests/helpers/stubs/base_production_stub.gd` (`class_name BaseProduction`). This story:
1. **DELETES** `base_production_stub.gd` — the real class supersedes it (`completed_outpost_count`, `advance_build_timers`, `defensive_attack_cost` all land real).
2. **MIGRATES `tests/unit/ap_reset_discard_test.gd`** — it currently injects fake outpost counts via the stub's `set_completed_outpost_count(player, n)` setter (~15 call sites). The real `completed_outpost_count` derives from actual structures, so these tests must place **real Completed Economy Outposts** in `entities_by_id` (owned, `build_status = COMPLETED`) to exercise the same income tiers. Preserve every income assertion's intent (0/4/7 outposts → the same income values).
3. **RE-TREATS `tests/unit/win_check_terminal_test.gd`** — it squats `Action.Verb.BUILD` as a "known-unregistered verb"; this story registers `BUILD` for real, so swap that fixture to a still-unregistered verb (or a dedicated never-registered test sentinel). Keep the win-check assertions identical.
4. Combat's `defensive_attack_cost()` consumer keeps working (real `BaseProduction.defensive_attack_cost()` → `StructureBalance` config).

---

## Out of Scope

- Production / deploy tiles — Story 004.
- Cancel + refund — Story 005.
- The real end-to-end `apply_action` integration + the step-3-before-step-4 income-ordering proof (real Grid + AP + Turn Manager) — Story 010 (Integration). This story tests the pure transitions/queries against injected Grid + AP fixtures.
- `advance_research_timers` — ADR-0018 / Research epic (only the commutativity requirement noted here).
- Non-Neutral faction delta *values* — Faction epic; here `effective_*` == base under Neutral only.

---

## QA Test Cases

*Build / placement / occupancy (Rules 3–5):*
- **AC-occupancy (Rule 3)**: Under-Construction structure on T → T movement-blocked AND stops a DIRECT LoF walk AND legal target. Impassable/occupied tile → `build()` rejected and never in `legal_build_tiles`.
- **AC-building (Rule 4)**: ≥ build_cost AP + legal tile → `build(Economy Outpost)` → AP −4, placed Under-Construction, blocks/targets. Fresh Under-Construction → inert for count/production/attack.
- **AC-unaffordable**: AP < build_cost → rejected, AP unchanged, Grid unchanged (atomicity).
- **AC-commit re-validation**: build tile occupied between preview and commit → rejected, no AP, no structure.
- **AC-placement legal / adjacency-structure / no-adjacency / empty-set**: per Rule 5 ACs.
- **AC-standoff boundary (Edge)**: tile at manhattan **exactly 2** from an enemy structure → **excluded** (`>2` strict — boundary is the point).
- **AC-HQ excluded (Edge)**: HQ never in `legal_build_tiles`.
- **AC-post-placement stability**: structure placed adjacent to a unit that later moves away → remains.
- **AC-parallel construction**: AP for two builds → both succeed same turn.
- **AC-economy-tech no-discount (regression guard)**: Economy-Tech player builds Economy Outpost → `effective_build_cost == 4`; under Neutral `== base` exactly.

*Timers / count / reset (Rules 6, 11, 7/8):*
- **AC-decrement / AC-complete-at-0 / AC-batch-complete**: per Rule 6 ACs (decrement, complete + one `StructureCompletedEvent`, batch = two events).
- **AC-count-basic / opponent / alive-only+zero / exclusions**: per Rule 11 ACs (the {2 Completed Econ, 1 U/C, 1 Prod, 1 HQ} → 2 fixture; opponent excluded; destroyed excluded; 0 not null; Lab + Defensive excluded).
- **AC-reset-produced / AC-reset-attacked**: start-of-turn reset → `units_produced_this_turn` → 0, `has_attacked` → false.

*Migration (keep green):*
- **AC-ap-income-migration**: `ap_reset_discard_test` still proves the same income tiers, now via real Completed Economy Outposts instead of the stub setter.

---

## Test Evidence

**Story Type**: Logic
**Required evidence** (two test files, both must exist and pass):
- `tests/unit/base-production/build_verb_legal_build_tiles_occupancy_test.gd` — build verb, `legal_build_tiles`, occupancy, placement, design-toggles.
- `tests/unit/base-production/start_of_turn_timers_outpost_count_flag_reset_test.gd` — `advance_build_timers`, `completed_outpost_count`, `reset_turn_flags`.
- Plus the migrated `tests/unit/ap_reset_discard_test.gd` (real structures) and re-treated `tests/unit/win_check_terminal_test.gd` (non-BUILD sentinel verb) staying green.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (`StructureTypeDef`/`StructureState`/`StructureTypes`/`BaseProductionConfig`). Uses the already-shipped Grid + AP (Foundation, Complete).
- **Unlocks**: Story 004 (produce needs Completed producers + `legal_deploy_tiles` alongside build), Story 005 (cancel needs Under-Construction structures), Story 010 (integration exercises build atomicity + the step-3-before-step-4 income ordering end-to-end). Supersedes `base_production_stub.gd` for AP Economy.

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: All merged ACs passing (build/occupancy/placement/design-toggles/completion-advance/completed_outpost_count/reset). Covers TR-baseprod-003/004/005/006/007/009.
**Deviations** (all ADVISORY, code-review-confirmed):
- Merged former Story 003 (class_name BaseProduction collision forced completed_outpost_count/advance_build_timers to land with the build verb). Story 003 → Superseded.
- Stub migration (user-approved): deleted `base_production_stub.gd`; migrated `ap_income_test`/`ap_reset_discard_test`/`turn_sequencing_test`/combat `counterattack`+`destroy_entity` tests to real structures (qa-tester verified semantics-preserving, income tiers preserved); re-treated `Verb.BUILD` squatters in `win_check_terminal`+`apply_action_pipeline` → `CANCEL_BUILD`.
- Int-reason dispatch contract (`(state, action) -> int`) used, matching the real codebase (not the ADR's `ActionResult` phrasing).
- Added `structure_placed_event.gd`; **populated `StructureCompletedEvent` fields** (entity_id/structure_type/owner/tile) during code review — resolves the GS-003 completion-event reconciliation.
- Code-review fixes applied: `StructureCompletedEvent` payload (above); `apply_build` asserts `Grid.place` success (dev tripwire vs silent half-commit); `completed_outpost_count` uses `state.entities()` for convention consistency.
- **Production/attack-inertness AC** for a fresh Under-Construction structure is tested only for the count dimension here — production inertness is Story 004's scope (logged to tech-debt).
**Test Evidence**: Logic — `tests/unit/base-production/build_verb_legal_build_tiles_occupancy_test.gd` (19) + `start_of_turn_timers_outpost_count_flag_reset_test.gd` (14); full suite 419/419, exit 0.
**Code Review**: Complete — `/code-review` APPROVED (gdscript 2 BLOCKING + 1 MINOR all fixed; qa-tester TESTABLE, no false-greens).
