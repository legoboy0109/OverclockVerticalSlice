# Story 006: `AITurnDriver` — Evaluate→Commit Loop, Termination, Rejection Handling, Per-Commit Streaming

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-001`, `TR-ai-002`, `TR-ai-003`, `TR-ai-005`, `TR-ai-009`, `TR-ai-010`, `TR-ai-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary, §3 `AITurnDriver`); ADR-0004 (secondary — `action_applied` streaming)
**ADR Decision Summary**: `AITurnDriver` is a small non-authoritative `Node` that runs the clone→enumerate→score→commit loop against the *real* state, handles commit rejection by re-looping, terminates on no-candidate/GameOver, and paces commits with an `await` timer so presentation streams each commit.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: The one new element (`await get_tree().create_timer(...).timeout`) is standard GDScript async, stable since 4.0, unaffected by 4.4–4.6 changes.

**Control Manifest Rules (this layer)**:
- Required: `AITurnDriver` must be a small `Node` (not Autoload, not authoritative) owning only real-time pacing between commits, holding zero authoritative state of its own — source: ADR-0011
- Required: On a rejected/stale action the driver must re-loop immediately (`if not result.ok: continue`) with no AP spent and no pacing delay — source: ADR-0011
- Required: If the AI's own commit ends the match, the driver must stop immediately and never enumerate again against a terminal state — source: ADR-0011
- Required: `PlayerState.is_ai_controlled: bool` must be set once at Setup, immutable after Setup→PlayerTurn — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] The AI acts only during its own Action phase — zero `apply_action()` calls during the human's Action phase or any resolution phase; begins only when `active_player` hands control and `PlayerState.is_ai_controlled == true` (AC-1/AC-2)
- [ ] Each iteration: `action = AI.choose_action(state, economy_investments)` → if `null`, break → `result = state.apply_action(action)` (real state, not clone) → if `not result.ok`, `continue` (re-loop, no AP spent, no pacing delay) → increment `economy_investments` if the committed action is Economy-Outpost-build or research-start → check `match_status == GAME_OVER` (return immediately) → `await get_tree().create_timer(AIConfig.commit_pacing_sec).timeout` → repeat (AC-3)
- [ ] Every candidate is affordability-gated (`AP.can_afford`) before being scored/returned by `choose_action` — never a discount, never a bypass (AC-5)
- [ ] The loop always terminates: reachable-starting-state fuzz never hangs; terminates on `choose_action` returning `null` OR `match_status == GAME_OVER` (AC-9)
- [ ] A candidate legal-at-evaluation but rejected at commit (simulated via injected state mutation between clone and commit) is discarded with zero AP spent, immediate re-loop from a fresh `clone()`, no crash (AC-24/AC-10)
- [ ] Each committed action fires `action_applied` (ADR-0004) synchronously before the pacing `await`, so presentation renders each commit incrementally (AC-13)
- [ ] Zero legal actions at TURN_START → transitions directly to calling End Turn with zero commits, no error/stall (AC-25)
- [ ] A produced unit / newly-built structure appears in the next iteration's candidate pool with no special-case code (automatic via re-`clone()` after every commit) (AC-26)
- [ ] The AI's own lethal commit setting `match_status = GAME_OVER` stops the loop immediately — the enumeration step is never run again against the terminal state (AC-35)

---

## Implementation Notes

*Derived from ADR-0011 §3:*

- File `src/gameplay/ai/ai_turn_driver.gd`, `class_name AITurnDriver extends Node` — NOT an Autoload, NOT authoritative, holds zero authoritative state (mirrors `MatchService`'s discipline).
- `economy_investments` is a turn-scoped **local variable**, never a field.
- Invoked by whatever observes `active_player` becoming AI-controlled after `start_turn()` (exact call site is a match-bootstrap detail, reconciled at implementation).
- This story also lands the new `PlayerState.is_ai_controlled: bool` field (ADR-0011 §4) — set once at Setup, immutable after Setup→PlayerTurn, same lock semantics/gate as `PlayerState.faction`. Per ADR-0011's Negative consequences this needs a follow-up note added to ADR-0001 (non-blocking, tracked).
- Verify `ai_turn_driver.gd` contains the `await` (the one file allowed to) while `ai.gd` (Stories 002–005) contains none.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The scoring formulas — Stories 003/004
- The tie-break comparator internals — Story 005 (already built)
- The AI-vs-human diff harness — Story 007; perf measurement — Story 008

---

## QA Test Cases

- **AC-1**: Given the human's Action phase, Then the AI commits zero `apply_action()` calls.
- **AC-2/26**: Given N legal candidates across ≥2 verbs, Then each iteration re-enumerates from a fresh post-commit clone; a mid-turn-produced unit appears next iteration with no special-casing.
- **AC-8**: Given more legal positive-scoring actions than a naive early-stop would suggest, Then the loop continues until nothing clears `PASS_THRESHOLD`.
- **AC-9**: Given any reachable starting state incl. zero-legal-actions, Then the loop terminates within a bounded iteration count and reaches TURN_END.
- **AC-24**: Given a candidate legal at evaluation but rejected at commit (injected mutation), Then zero AP spent, driver re-loops, no crash.
- **AC-25**: Given zero owned units/producers at TURN_START, Then the AI ends its turn immediately with zero commits.
- **AC-35**: Given the AI's own commit sets `match_status = GAME_OVER`, Then the loop stops immediately, no further enumeration.
- **AC-13 (streaming)**: Given a running `SceneTree` harness, Then `action_applied` fires once per commit with the configured `commit_pacing_sec` gap.
- **Edge**: two consecutive rejections (double stale-clone) — driver re-loops both times without accumulating error state.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ai-opponent/ai_turn_driver_loop_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001–005 (`AI.choose_action` must be fully functional)
- Unlocks: Story 007 (diff harness/fuzz drive full turns through this loop), Story 008 (perf test measures this loop)
