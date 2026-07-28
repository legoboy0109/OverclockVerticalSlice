# Story 003: `ApCounterFsm` — 4-State AP Counter Animation Core (Headless)

> **Epic**: Game HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-005`, `TR-hud-006`, `TR-hud-007`, `TR-hud-008` (tick-serialization consumption half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §2/§3)
**ADR Decision Summary**: The AP counter is a headless 4-state animation FSM (`COMMITTED`/`FILL_FLOURISH`/`TICK_DOWN`/`PREVIEW_ECHO`) split from its rendering widget (mirroring `CommandFSM`/`CommandInterface`); preview echo snaps (no tween), a turn transition force-clears the echo before the incoming fill, and a `GameOver`-triggering commit snaps any in-flight tick to final.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure `RefCounted` state machine, headless — no engine API surface (mirrors `CommandFSM`). No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `ApCounterFsm` (pure `RefCounted` core: `next_state`) must be split from the rendering widget, mirroring the `CommandFSM`/`CommandInterface` split — source: ADR-0016
- Required: On any `PlayerTurn`/`EndTurn` transition, the widget must tear down the preview echo synchronously as the first step, before evaluating the incoming fill trigger — source: ADR-0016
- Required: A commit triggering `GameOver` must force any in-flight tick-down to complete instantly — source: ADR-0016

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN start-of-turn AP reset to income I, THEN the counter's committed value equals I and the fill-flourish trigger fires exactly once (AC-3a)
- [ ] GIVEN a hover, cancel, illegal click, or selection with no commit, THEN the AP counter's committed value does not animate (AC-4)
- [ ] GIVEN an action commits spending N AP, THEN the counter's committed value steps down by exactly N, and a second commit's tick does not start until the first resolves (AC-5a)
- [ ] GIVEN no active preview (including immediately after a preview cancels or commits), THEN the counter shows the plain committed value with no `→` and no leftover projected number (AC-25)
- [ ] GIVEN a `PlayerTurn`/`EndTurn` transition, THEN the preview echo is force-cleared synchronously as the first step, before the incoming fill-flourish trigger is evaluated (TR-hud-006)
- [ ] GIVEN a commit that also triggers `GameOver`, THEN any in-flight tick-down snaps to its final post-spend value within the transition (TR-hud-007); the opponent-AP reachable-state restriction holds: only `COMMITTED` (+ optionally `FILL_FLOURISH`/`TICK_DOWN`) is reachable for opponent AP, never `PREVIEW_ECHO`
- [ ] `next_state()` is exhaustively table-tested — every (state, trigger) pair returns the ADR-0016 §2 target; `GAME_OVER`-triggered resolves to `COMMITTED` with a snap-to-final flag

---

## Implementation Notes

*Derived from ADR-0016 §2/§3:*

- `ap_counter_fsm.gd` — `class_name ApCounterFsm extends RefCounted`, `enum State { COMMITTED, FILL_FLOURISH, TICK_DOWN, PREVIEW_ECHO }`, `enum Trigger { TURN_START_FILL, COMMIT_SPEND, PREVIEW_OPEN, PREVIEW_CLOSE, TURN_TRANSITION, GAME_OVER }`. `static func next_state(current, trigger) -> State` — pure.
- Four states: `COMMITTED` (static "trust" state — no motion means the value is real), `FILL_FLOURISH` (start-of-turn, once), `TICK_DOWN` (steps down by exactly N on commit), `PREVIEW_ECHO` (committed value frozen, `→ projected` renders beside it, SNAPS — no tween).
- Turn-transition echo force-clear: tear down `PREVIEW_ECHO` synchronously as the first step of handling a `PlayerTurn`/`EndTurn` transition, before evaluating the incoming `TURN_START_FILL` — closes the one-frame race between CAI's exit-to-IDLE and the HUD's fill.
- `GameOver` tick-snap: a commit triggering `GameOver` forces `next_state` to resolve to `COMMITTED` with a snap-to-final flag. The hp-pip drain is a *different* element (Story 005) and is NOT this FSM's concern — note only that it is exempt from truncation/gating.
- AP-tick serialization (TR-hud-008): this FSM does NOT build its own tick queue. It consumes CAI's `input_locked`/`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` guarantee (Story 002's guard makes this numerically true) — one tick fully resolves before the next commit's `action_applied` arrives.
- This story does NOT build the rendering widget (Story 004) or wire real `GameStateReader` values — it is the pure transition-table core only, using the corpus's stub convention.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The `Control` widget/rendering — Story 004
- Opponent `OPPONENT`-label visual treatment — Story 004
- hp-pip drain animation — Story 005
- Income breakdown popover — Story 007

---

## QA Test Cases

- **AC (next_state totality)**: Given the full `State × Trigger` cross-product (4×6), When `next_state()` is invoked per pair, Then the result matches ADR-0016 §2's table exactly. Edge cases: `GAME_OVER` trigger from any state → `COMMITTED` + snap flag.
- **AC (echo clear order)**: Given `PREVIEW_ECHO` active and `TURN_TRANSITION` fires, When `next_state` is called, Then the echo is cleared before any `TURN_START_FILL` evaluation — order asserted via a sequenced call log.
- **AC (opponent restriction)**: Given the opponent-AP context flag set, When `PREVIEW_OPEN` is triggered, Then `next_state` refuses the transition (stays in current reachable state) since `PREVIEW_ECHO` is unreachable over opponent AP.
- **AC (serialization invariant)**: Given `COMMIT_SPEND` mid-`TICK_DOWN`, Then assert this cannot occur given upstream serialization — the test documents the invariant rather than handling it defensively.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/game-hud/ap_counter_fsm_test.gd` — must exist and pass

**Status**: [x] Created and passing — 12 tests, all green (2026-07-28)

---

## Dependencies

- Depends on: Story 002 (`HUDConfig.ap_tick_duration_ms`/`ap_fill_flourish_ms`), and cross-epic **CAI Story 007** (the shared `action_applied` signal both the commit-flash and AP-tick subscribe to)
- Unlocks: Story 004 (the widget wraps this FSM), Story 007 (opponent-muting reads this FSM's reachable-state restriction)

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: 7/7 covered — AC-3a (fill), AC-4 (no committed-value animation on preview events), AC-5a (commit→tick + documented serialization invariant), AC-25 (no leftover echo), TR-hud-006 (echo force-clear before fill), TR-hud-007 (GameOver snap-to-final) + opponent PREVIEW_ECHO-unreachable restriction, and the exhaustive next_state table.
**Deviations**: None blocking. INFO — `next_state` takes an `is_opponent` param and adds `snaps_to_final` + `is_reachable_for_opponent` companions beyond ADR-0016 §2's illustrative 2-arg skeleton. Justified: the ADR §2 code block is a skeleton (`: ...`), its prose mandates the opponent-AP restriction be *structural* (mirroring §1's GameStateReader pattern), the story's own AC block requires it, and `is_reachable_for_opponent` is named as the mechanism Story 007 consumes. No ADR-conformance issue (independent godot-gdscript review confirmed).
**Test Evidence**: Logic — `tests/unit/game-hud/ap_counter_fsm_test.gd` (12 tests, PASS). Full suite 742/742 green.
**Code Review**: Complete — APPROVED (independent godot-gdscript read-only pass + coordinator review; ADR-0016 §2/§3 compliant, pure/total/statically-typed).
