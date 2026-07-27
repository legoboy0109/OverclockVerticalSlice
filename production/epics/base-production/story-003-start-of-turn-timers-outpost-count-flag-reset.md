# Story 003: Start-of-Turn — Build-Timer Advance, `completed_outpost_count`, Flag Reset

> **Epic**: Base & Production
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/base-production.md` — Core Rule 6 (build completion at start-of-turn, before income snapshot); Rule 11 (`completed_outpost_count` contract); Rules 7 & 8 start-of-turn resets (`units_produced_this_turn` → 0, `has_attacked` → false); the "Completion advance", "`completed_outpost_count`", and start-of-turn reset ACs.
**Requirement**: `TR-baseprod-006`, `TR-baseprod-007`, `TR-baseprod-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Start-of-turn sequencing (canonical 4-step order; step 2 flag reset, step 3 timer advance) + ADR-0017 (D1 — the concrete transition bodies)
**Secondary ADRs**: ADR-0006 (`completed_outpost_count` is the AP-income contract; `AP.reset_turn` snapshot at step 4).
**ADR Decision Summary**: `advance_build_timers(state, player) -> Array[Event]` is the concrete body of ADR-0008's forward-declared step-3 contract: it decrements `build_turns_remaining` on the player's Under-Construction structures, flips those reaching 0 to `COMPLETED`, and appends one `StructureCompletedEvent` per completion. ADR-0008 owns WHEN it runs (step 3, before the step-4 income snapshot); this body owns the transition. `Structure.reset_turn_flags` is ADR-0008 step 2's body (B&P-owned semantics). Both must complete before step 4's income snapshot so a just-completed Economy Outpost counts that same turn. `completed_outpost_count(player)` returns alive, owned, Completed Economy Outposts only — return 0, never null.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `advance_build_timers`' body lives in this ADR-0017 slice while its *sequencing* lives in ADR-0008 — the two timer-advance calls within step 3 (build vs research) are order-independent and must stay commutative. `StructureCompletedEvent` flows through the existing `action_applied` signal — no new signal. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`advance_build_timers(state, player)` must decrement `build_turns_remaining` on the player's Under-Construction structures, flip those reaching 0 to `COMPLETED`, and append one `StructureCompletedEvent` per completion (sequenced by ADR-0008 step 3, before the income snapshot)" — source: ADR-0017
- Required: "Per-turn flag resets must be attributed to owning systems (`Structure.reset_turn_flags`) — `GameState` owns only the timing" — source: ADR-0008
- Required: "Steps 2 and 3 must both complete before step 4's income snapshot; the two timer-advance calls WITHIN step 3 (build vs research) are order-independent and must stay commutative" — source: ADR-0008
- Required: "New `Event` subclasses (`StructureCompletedEvent`) must flow through the existing `action_applied` signal — no new signal or polling path" — source: ADR-0008
- Required: "`completed_outpost_count(player)`: alive owned Completed Economy Outposts only, start-of-turn snapshot; return 0 not null; consumed by `ap_income`" — source: ADR-0006/ADR-0007
- Required: "Any order-sensitive pass over `entities_by_id` must iterate a list sorted by a stable key (`entity_id` or tile index)" — source: ADR-0003
- Forbidden: "Never reorder start_turn step 4 before step 3 — the income snapshot must observe structures that completed this same turn" — source: ADR-0008
- Forbidden: "Never use silent state transitions with no completion events (polling/diffing)" — source: ADR-0008

> **Codebase note**: This story's `completed_outpost_count` **replaces** the Sprint-1 `base_production_stub.gd` implementation that AP Economy's income formula currently calls against a stub.

---

## Acceptance Criteria

*Completion advance (Rule 6, pure slice):*
- [ ] **GIVEN** an Under-Construction structure with 2 remaining build-turns, **WHEN** the advance step runs once, **THEN** it decrements to 1 and stays Under-Construction.
- [ ] **GIVEN** one with 1 remaining, **WHEN** advance runs, **THEN** it becomes Completed and a `StructureCompletedEvent` is appended; the advance function reads no income state (ordering is the caller's responsibility — the observable ordering is an Integration AC in Story 010).
- [ ] **GIVEN** two structures both reaching 0 in the same advance call, **THEN** both Complete in that one call (batch), each appending its own completion event.

*`completed_outpost_count` (Rule 11):*
- [ ] **GIVEN** {2 Completed Economy Outposts, 1 Under-Construction Economy Outpost, 1 Completed Production Outpost, 1 HQ}, all one player's, **THEN** the query returns exactly **2**.
- [ ] **GIVEN** an opponent-owned Completed Economy Outpost, **THEN** excluded for this player.
- [ ] **GIVEN** a Completed Economy Outpost destroyed this step, **THEN** excluded (alive-only). **GIVEN** none qualify, **THEN** returns **0** (not null).
- [ ] **GIVEN** a Completed **Research Lab** (Rule 2b) and a Completed **Defensive Structure** owned by the player, **THEN** both are excluded — only Economy Outposts count (the Lab is not an income structure, `production_cap 0`, and never feeds the count).

*Start-of-turn flag reset (Rules 7, 8):*
- [ ] **GIVEN** start-of-turn reset for a player, **THEN** `units_produced_this_turn` → 0 for that owner's producers (Rule 7).
- [ ] **GIVEN** start-of-turn reset for a player, **THEN** `has_attacked` → false for that owner's Defensive Structures (Rule 8).

---

## Implementation Notes

*Derived from ADR-0017 (D1) and ADR-0008:*

- **`advance_build_timers(state, player) -> Array[Event]`** (`BaseProduction`): iterate the player's Under-Construction structures in stable `entity_id` order (ADR-0003); decrement `build_turns_remaining`; any reaching 0 flip to `COMPLETED` and append one `StructureCompletedEvent` (ADR-0004/0008 payload). This is the body of ADR-0008's step-3 contract — **ADR-0008 owns that it runs before the step-4 AP income snapshot; this body owns the transition**. It reads NO income state (the pure-slice AC), so it stays commutative with `advance_research_timers` within step 3.
- **`Structure.reset_turn_flags(structure)`** — the body of ADR-0008 step 2 (B&P-owned semantics, registry `turn_flag_reset`): sets `units_produced_this_turn = 0` and `has_attacked = false`. Attributed to this system; `GameState.start_turn` owns only the timing (calls it at step 2). Mirror `Unit.reset_turn_flags`.
- **`completed_outpost_count(state, player) -> int`** (`BaseProduction`): count the player's structures where `type == StructureTypes.ECONOMY_OUTPOST` AND `build_status == COMPLETED` AND still alive/owned. Excludes Under-Construction Economy Outposts, opponent-owned, destroyed-this-step, HQ, Production Outpost, Defensive Structure, and Research Lab. **Returns 0, never null.** This is the exact query `ap_income` consumes (ADR-0006), sampled at the owner's start-of-turn snapshot after Rule-6 completions. It supersedes `base_production_stub.gd`.
- The observable *ordering proof* (a just-completed Economy Outpost counts that same turn) is an Integration AC — **Story 010**, not here. This story asserts the pure transition and the pure count against injected fixtures.

---

## Out of Scope

- The end-to-end ordering proof that a just-completed Economy Outpost raises `ap_income` **this** turn (real Turn Manager + AP snapshot) — Story 010 (Integration).
- `advance_research_timers` — ADR-0018 / Research epic (only the commutativity requirement is noted here).
- Build placement — Story 002. Production — Story 004. Cancel — Story 005.

---

## QA Test Cases

- **AC-decrement**: Given an Under-Construction structure with 2 remaining / When advance runs once / Then 1 remaining, still Under-Construction.
- **AC-complete-at-0**: Given 1 remaining / When advance runs / Then Completed + one `StructureCompletedEvent` appended; the function reads no income state.
- **AC-batch-complete**: Given two structures both reaching 0 in the same call / Then both Complete in that one call, two completion events (Edge: batch boundary).
- **AC-count-basic (Rule 11)**: Given {2 Completed Econ, 1 U/C Econ, 1 Completed Prod, 1 HQ} one player's / Then returns **2**.
- **AC-count-opponent**: Given an opponent-owned Completed Economy Outpost / Then excluded for this player.
- **AC-count-alive-only + zero (Edge)**: Given a Completed Economy Outpost destroyed this step / Then excluded; Given none qualify / Then **0** (not null).
- **AC-count-exclusions**: Given a Completed Research Lab and a Completed Defensive Structure owned by the player / Then both excluded (only Economy Outposts count).
- **AC-reset-produced (Rule 7)**: Given start-of-turn reset / Then `units_produced_this_turn` → 0 for that owner's producers.
- **AC-reset-attacked (Rule 8)**: Given start-of-turn reset / Then `has_attacked` → false for that owner's Defensive Structures.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/start_of_turn_timers_outpost_count_flag_reset_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (schema/registry — `BuildStatus`, `StructureTypes.ECONOMY_OUTPOST`), Story 002 (structures are placed Under-Construction by `build`, which this advances/counts).
- **Unlocks**: Story 010 (integration exercises the step-3-before-step-4 ordering end-to-end). Supersedes `base_production_stub.gd`'s `completed_outpost_count` for AP Economy regression.
