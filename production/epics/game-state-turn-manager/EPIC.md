# Epic: Game State & Turn Manager

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-turn-manager.md
> **Architecture Module**: Game State & Turn Manager (+ the Event/Signal bus — a cross-cutting
> module architecture.md identifies with no dedicated GDD; it fires from this module's
> `apply_action` step 7, so its one requirement, TR-gamestate-012, is scoped to this epic)
> **Status**: Ready
> **Stories**: 4 stories created — see table below

## Overview

Game State & Turn Manager is the authoritative, render-decoupled model of everything true about
a match — the grid, all entities, each player's per-turn state, whose turn it is, the round
number, and match status — plus the turn/phase loop that advances play and detects victory.
`GameState extends Resource` (never `Node`) exposes a side-effect-free read API and a single
mutation vector, `apply_action(action) -> ActionResult`, which validates, applies atomically,
and runs the win-check in one synchronous step. `clone()` (via `duplicate_deep()`) gives the AI
an independent deep-copy for lookahead with zero risk to authoritative state. This epic also
owns the canonical 4-step start-of-turn sequence (set active player → clear per-turn flags →
apply start-of-turn effects → reset AP to income snapshot) and the single unified
`action_applied` signal that decouples presentation from truth — the Event/Signal bus.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0001: State model ownership & lifecycle | `GameState extends Resource`, constructed only via `.new()`; `clone()` = `duplicate_deep()` cast to `GameState`; no Autoload holds authoritative state (DI, `MatchService` is a thin lookup pointer only); side-effect-free read API; `starting_player`/`faction_of`/tech-flag fields Setup-locked | MEDIUM (`duplicate_deep()`, Godot 4.5) |
| ADR-0002: Action / apply_action command model | Typed `Action` subclass per verb, verb-enum `Dictionary[int, Callable]` dispatch (never `get_class()`); `apply_action`'s fixed 7-step pipeline; atomicity by validate-before-mutate, no rollback; uniform `ActionResult`; idempotency by stateless re-validation | LOW |
| ADR-0003: Deterministic simulation & RNG isolation | No engine RNG in state transitions (global `randi`/`randf` banned project-wide); all state integer; stable iteration order (`entity_id` or tile index, never Dictionary hash order) | LOW |
| ADR-0004: Event/signal architecture | `GameState` emits its own single unified signal `action_applied(result)` — no separate EventBus Autoload; emitted once, synchronously, only on `result.ok` | LOW |
| ADR-0008: Shared start-of-turn sequencing | `GameState.start_turn(player) -> Array[Event]` runs the canonical 4-step sequence; `EndTurnAction.apply()` owns discard + round increment + calling `start_turn(next)` | LOW |
| ADR-0011: AI opponent decision loop | AI interacts with `GameState` only via `clone()` + the approved read API + `apply_action` — the same code path a human commits through, no privileged access | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gamestate-001 | Single authoritative data model (grid, entities, per-player, active_player, round_number, match_status) held independent of scene tree | ADR-0001 ✅ |
| TR-gamestate-002 | Instantiable/mutable/queryable with zero render nodes (headless); state is not a Node | ADR-0001 ✅ |
| TR-gamestate-003 | clone() deep-copy produces fully independent state; all fields plain copyable; enables AI lookahead | ADR-0001 ✅ |
| TR-gamestate-004 | All mutation flows through single apply_action(action): validates, applies atomically, deducts AP, runs win-check | ADR-0002 ✅ |
| TR-gamestate-005 | Illegal actions rejected with zero state change (incl. AP); validate-before-apply or transactional | ADR-0002 ✅ |
| TR-gamestate-006 | Turn/phase FSM: Setup->PlayerTurn(P)->EndTurn(P)->PlayerTurn(other)->...->GameOver with ordered entry actions | ADR-0008 ✅ |
| TR-gamestate-007 | Start-of-turn canonical 4-step order: set active -> clear per-turn flags -> apply start effects (build/research timers) -> reset AP to income snapshot | ADR-0008 ✅ |
| TR-gamestate-008 | Fully deterministic transitions: identical state+ordered actions -> byte-identical result; no RNG in turn advance | ADR-0003 ✅ |
| TR-gamestate-009 | No float-driven nondeterminism in transitions; AP/HP/positions/counters integer | ADR-0003 ✅ |
| TR-gamestate-010 | Win-check after every HQ-destroying mutation, synchronous -> GameOver, inside apply_action atomic step (also ADR-0010) | ADR-0002 ✅ |
| TR-gamestate-011 | Side-effect-free read API: active_player, current_ap(p), round_number, match_status, entities(), entity_at(tile), grid | ADR-0001 ✅ |
| TR-gamestate-012 | Renderer is a pure consumer observing change events/signals, never mutating truth; signal contract (unit_moved, turn_ended, game_over) | ADR-0004 ✅ |
| TR-gamestate-013 | AI interacts only via clone()+read API+apply_action, no privileged access; same code path as real play | ADR-0011 ✅ |
| TR-gamestate-014 | Store faction_of(player), apply starting_loadout at Setup; faction locked after Setup->PlayerTurn | ADR-0001 ✅ |
| TR-gamestate-015 | Every field a plain serializable value (no engine object refs) even though save/load deferred; pre-conditions future Persistence GDD | ADR-0001 ✅ |
| TR-gamestate-016 | Optional MAX_ROUNDS cap + TIEBREAK_METRIC forcing GameOver; tiebreak computable purely from state | ADR-0001 ✅ |
| TR-gamestate-017 | No softlock: player with zero legal actions can always end_turn(); end_turn() unconditionally legal | ADR-0001 ✅ |
| TR-gamestate-018 | Re-submission of an applied action safely re-validated + rejected, no double-apply; idempotency-by-revalidation | ADR-0002 ✅ |
| TR-gamestate-019 | State-model location (Autoload vs passed object vs event-bus) resolved by ADR before coding (was OPEN blocker) | ADR-0001 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | GameState Core — Data Model, Read API & clone() | Logic | Ready | ADR-0001 |
| 002 | Action Command Model, apply_action Pipeline & Event Signal | Logic | Ready | ADR-0002 |
| 003 | Turn FSM — start_match, start_turn 4-Step Sequence, EndTurnAction & Round Increment | Logic | Ready | ADR-0008 |
| 004 | Win-Check, GameOver & MAX_ROUNDS/Tiebreak Terminal Conditions | Logic | Ready | ADR-0002 |

> **Cross-epic implementation-order note:** Stories 003–004 call forward-declared contracts owned by
> not-yet-built systems (`AP.reset_turn`/`AP.discard` from AP Economy/ADR-0006; build/research timer
> advances; `Unit`/`Structure.reset_turn_flags`; entity HP for the win-check/ADR-0007). Per ADR-0008
> these are deliberate forward declarations, but GDScript can't compile a call to an absent `class_name`,
> so 003–004 need either the AP Economy epic (at least its `AP` class) implemented first or test-double
> stubs. Stories 001–002 are fully implementable standalone today.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-state-turn-manager.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/story-readiness production/epics/game-state-turn-manager/story-001-gamestate-core-model-read-clone.md` to begin implementation. Stories 001–002 are implementable now; 003–004 depend on AP Economy (see the cross-epic note above).
