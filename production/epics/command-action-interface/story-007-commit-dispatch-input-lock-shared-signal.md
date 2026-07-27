# Story 007: Commit Dispatch, INPUT_LOCK_MS Debounce & Commit-Flash↔AP-Tick Shared Signal

> **Epic**: Command & Action Interface
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/command-action-interface.md`
**Requirement**: `TR-cmdui-022`, `TR-cmdui-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: Input & Focus Architecture (INPUT_LOCK_MS mechanism); ADR-0015: Command & Action Interface FSM (shared-signal wiring) — co-primary (both TRs are tightly coupled; this is the epic's single highest-named risk)
**ADR Decision Summary**: `INPUT_LOCK_MS` is a UX debounce (flag + timer) gating only new commit dispatch; the commit-flash (this system) and the AP-tick (Game HUD) both subscribe to the single `GameState.action_applied(result)` signal — neither polls an AP delta nor reacts to the other, so they start on the same frame by construction.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Reuses the `await get_tree().create_timer(...).timeout` idiom confirmed correct for 4.6 (including `process_always` defaulting true) by ADR-0011's precedent.

**Control Manifest Rules (this layer)**:
- Required: `INPUT_LOCK_MS` must be a UX debounce timer only (flag + `await get_tree().create_timer(...).timeout`) gating only new commit dispatch — hover, cursor movement, and menu focus traversal must remain live during the lock window — source: ADR-0014
- Required: Commit-flash (ADR-0015) and AP-tick (ADR-0016) must both subscribe to the single `GameState.action_applied(result)` signal — neither polls for an AP delta, neither reacts to the other — source: ADR-0015
- Required: Attack commits must fire no interface audio from `CommandInterface` — Combat triggers its own cue off the same `action_applied` event — source: ADR-0015

---

## Acceptance Criteria

*From GDD `design/gdd/command-action-interface.md`, scoped to this story:*

- [ ] GIVEN two commit inputs in rapid succession (double-click), THEN exactly one commit fires and the resource change applies exactly once; the second input inert (AC-27)
- [ ] `input_locked` gates only new commit dispatch — hover, board-cursor movement, and menu focus traversal remain fully live during the lock window (TR-cmdui-022's structural clarification)
- [ ] The commit flash (this system) and the AP-counter tick-down (Game HUD) both subscribe to the single `GameState.action_applied(result)` signal — neither polls for an AP delta, neither reacts to the other (TR-cmdui-023)
- [ ] Because `action_applied` fires exactly once per commit, synchronously, both animations start on the same frame by construction
- [ ] Attack commits fire no interface audio from this system — Combat triggers its own cue off the same `action_applied` event, so exactly one system calls `play()`

---

## Implementation Notes

*Derived from ADR-0014 / ADR-0015 Implementation Guidelines:*

- `input_locked: bool` flag on the `CommandInterface` Node; `_dispatch_commit(action)` checks it first (no-op if locked), sets it true, calls `state.apply_action(action)`, then `await get_tree().create_timer(InputConfig.input_lock_ms / 1000.0).timeout` before releasing.
- This is a **UX debounce, not the correctness mechanism** — true single-commit safety is already structurally guaranteed by synchronous single-threaded input dispatch + the FSM's immediate state transition (ADR-0002/CR-6). Do not build a second safety mechanism on top of this timer.
- `InputConfig.input_lock_ms: int = 120` (already on ADR-0014's `InputConfig`) — do not fold into a new config Resource.
- Commit-flash: on `action_applied` with `result.ok`, `CommandInterface` fires the tile/target confirm-flash. This ADR owns the flash; Game HUD (separate epic) owns the AP-tick off the same signal — this story's job is only to fire the flash correctly on the shared signal, not to build or test the HUD's tick.
- The cross-system invariant `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` is enforced by the config loader Autoload (per control-manifest) — that loader-level guard is **Game HUD epic's responsibility** to add (since `HUDConfig` doesn't exist until then); this story only needs `InputConfig.input_lock_ms` to default to 120 correctly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Game HUD's own AP-tick animation FSM (`ApCounterFsm`) — separate epic
- The load-time cross-config assert itself — Game HUD epic, once `HUDConfig` exists (flag as a dependency, do not stub here)

---

## QA Test Cases

- **AC-27**: Given a legal, affordable action previewed, When two rapid left-clicks land on the same option within one frame, Then exactly one `apply_action` call occurs and the AP/HP delta applies exactly once.
- **AC (lock scope)**: Given a commit just dispatched and `input_locked = true`, When the mouse hovers a new tile or the board cursor steps, Then the hover/cursor state updates live (not blocked by the lock).
- **AC-023 (same frame)**: Given a commit resolves with `result.ok = true`, When `action_applied` fires, Then the commit-flash begins on the same frame the signal is received (assert via a scripted single-frame check, not a tolerance window).
- **AC (audio ownership)**: Given an attack commits, When `action_applied` fires, Then `CommandInterface` calls no `AudioStreamPlayer.play()` of its own (assert its audio call count is 0 for this event).
- **AC (lock timing)**: Given `input_lock_ms = 120`, When a commit dispatches, Then `input_locked` remains true for at least 120ms and releases automatically afterward with no manual reset.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/command-action-interface/commit_dispatch_lock_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (real `apply_action` commit path must exist)
- Unlocks: Game HUD epic's AP-tick story (external — this story's shared `action_applied` subscription is the seam Game HUD consumes; sequence this story **before** any Game HUD story that renders the tick)
