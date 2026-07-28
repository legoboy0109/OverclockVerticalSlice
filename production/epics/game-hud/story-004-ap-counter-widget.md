# Story 004: AP Counter Widget — Rendering, Opponent Muting, Preview Echo, Fill/Tick Wiring

> **Epic**: Game HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L (4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-005` (rendering half), `TR-hud-006` (rendering half), `TR-hud-007` (rendering half), `TR-hud-009` (turn/round indicator + banner)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §2/§8); ADR-0014 (secondary — dual-focus N/A here, this widget is non-interactive display)
**ADR Decision Summary**: The AP counter widget wraps `ApCounterFsm` and renders per-state (static committed / glow-fill / discrete tick / snapping echo), reads opponent AP under a persistent muted `OPPONENT` label, and shares the top-center spine with the turn/round indicator + YOUR/ENEMY banner.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Reactive `Control` rendering off `queue_redraw()`; no new engine API. Control-redraw/`AudioStreamPlayer` stability at 4.6 confirmed in ADR-0016 Engine Compatibility.

**Control Manifest Rules (this layer)**:
- Required: The AP counter FSM must have exactly 4 states; only the local player's counter reaches all four; the opponent's reaches only `COMMITTED` — source: ADR-0016
- Required: Preview echo must snap (no tween); the committed value moves only on a real commit — source: ADR-0016
- Required: Every displayed value is a live verbatim read; the widget never computes/infers a value locally (Pass-Through) — source: ADR-0016

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN the AC-3a trigger, THEN the fill visually reads as a glow-fill over `AP_FILL_FLOURISH_MS` (not an instant snap) (AC-3b, advisory)
- [ ] GIVEN AC-5a, THEN the step-down reads as a discrete/chunky tick over `AP_TICK_DURATION_MS`, never a smooth slide (AC-5b, advisory)
- [ ] GIVEN #9 previews an affordable action costing C at current_ap A, THEN the counter shows `A → A−C` (= CAI's `projected_remaining_ap` verbatim); on cancel it reverts to A with no state change (AC-6)
- [ ] GIVEN #9 previews an unaffordable action, THEN the counter shows current value + "insufficient AP," never a negative or `→` negative number (AC-7)
- [ ] GIVEN a `PlayerTurn` transition, THEN the indicator reflects `active_player` + `round_number` and the banner's hold-timer value equals `TURN_BANNER_DURATION_MS` (AC-9a); the banner visibly displays and reads correctly for its hold duration (AC-9b, advisory)
- [ ] GIVEN `SHOW_OPPONENT_AP = on` during the opponent's turn, THEN the counter shows the opponent's live `current_ap` under a persistent `OPPONENT` label + muted treatment for the whole opponent turn, not only during the transient banner (AC-19, AC-28)

---

## Implementation Notes

*Derived from ADR-0016 §2/§8:*

- The widget wraps `ApCounterFsm` (Story 003) and renders per-state: `COMMITTED` static number; `FILL_FLOURISH` glow-fill over `HUDConfig.ap_fill_flourish_ms`; `TICK_DOWN` discrete/chunky step over `HUDConfig.ap_tick_duration_ms`; `PREVIEW_ECHO` renders `current → projected` inline, SNAPPING (no tween) on open/change/close.
- Subscribes to `GameState.action_applied(result)` for the tick (the shared signal CAI Story 007 establishes) — the HUD does NOT independently trigger anything off a value-change; it reads `GameStateReader.current_ap(player)` and CAI's `projected_remaining_ap` (read, not owned).
- Opponent-AP muting (CR-3b): persistent `OPPONENT` label + muted/desaturated treatment for the *entire* opponent turn, distinct from the transient turn banner. The accessible committed-vs-projected channel is the `→` arrow + explicit numerals (`9 → 3`) — **not** the desaturated-echo hue alone (Accessibility E).
- Turn/round indicator + YOUR/ENEMY banner share the top-center spine; banner is neutral-static text + directional slide-in (load-bearing non-hue channel) with supplementary-only audio.
- `Insufficient AP` indicator on an unaffordable preview: read CAI's blocked/insufficient state, never compute or infer negativity locally (Pass-Through).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Victory/defeat one-frame preemption of the banner — Story 006 (the `GameOver` cross-cutting story)
- hp pips — Story 005
- Income breakdown — Story 007
- Audio dispatch itself — Story 008 (this widget only *renders*, silent)

---

## QA Test Cases

*Integration assertions on displayed values (blocking) + Visual/Feel manual (advisory):*

- **AC-6 (Integration)**: Given a preview of an affordable action costing 6 at current_ap 9, When the echo renders, Then the displayed projected number equals CAI's `projected_remaining_ap` (3) verbatim; on Cancel it reverts to 9 with no state change.
- **AC-7 (Integration)**: Given an unaffordable preview, When the counter renders, Then it shows current value + "insufficient AP," never a negative or `→` negative.
- **AC-19/28 (Integration)**: Given `SHOW_OPPONENT_AP=on` mid-opponent-turn, When the counter renders, Then it shows opponent `current_ap` under a persistent `OPPONENT` label + muted treatment (asserted at both turn-start and mid-turn).
- **AC-3b/5b/9b (Visual/Feel)**: Setup: trigger fill (income 8), a 6-AP commit, and a turn transition. Verify: fill reads as glow (~400ms), step reads as chunky ticks (~120ms), banner displays for its hold. Pass condition: reviewer sign-off.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/game-hud/ap_counter_widget_test.gd` (blocking — AC-6/7/9a/19/28 value assertions) + advisory `production/qa/evidence/ap-counter-widget-evidence.md` (Visual/Feel motion quality)

**Status**: [x] Blocking Integration test created and passing — 10 tests, all green (2026-07-28). [ ] Advisory Visual/Feel sign-off OWED (`production/qa/evidence/ap-counter-widget-evidence.md`, needs a windowed session)

---

## Dependencies

- Depends on: Story 001 (`GameStateReader`), Story 003 (`ApCounterFsm`), Story 002 (`HUDConfig`), and cross-epic **CAI Story 007** (shared commit-flash↔AP-tick signal) + **CAI Story 003** (`projected_remaining_ap`)
- Unlocks: Story 007 (income breakdown popover anchors off this counter)

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: Blocking Integration ACs 6/7/9a/19/28 all covered (10 tests). Advisory Visual/Feel AC-3b/5b/9b OWED (windowed sign-off).
**Deliverables**: `src/ui/game_hud/ap_counter_widget.gd` (ApCounterWidget — committed/echo/fill/tick, opponent muting, testable display-model getters); `src/ui/game_hud/turn_banner_widget.gd` (TurnBannerWidget — turn/round indicator + YOUR/ENEMY banner + hold self-clear). Both extend HudReactiveControl; Pass-Through (no local AP derivation — projections handed in from CAI's projected_remaining_ap verbatim).
**Deviations**: None blocking.
- INFO: preview echo driven by explicit `open_preview`/`close_preview` entry points (scene glue wires CAI preview→widget, mirroring route_click/inspect; CAI exposes no preview signal). Scene-side wiring = integration glue, not this story.
- Code review WARNINGs FIXED (not deferred): (1) `_refresh_committed` now detects turn transitions explicitly (active_player/round) and routes through TURN_TRANSITION before a gated start-of-turn fill — a mid-turn AP increase (Cancel-Build refund credit) no longer misfires FILL_FLOURISH; (2) `show_opponent_fill_flourish` now honored (opponent fill gated). Both covered by 4 added tests.
**Test Evidence**: Integration — `tests/integration/game-hud/ap_counter_widget_test.gd` (10 tests, PASS). Full suite 752/752 green. Advisory Visual/Feel — `production/qa/evidence/ap-counter-widget-evidence.md` (sign-off OWED).
**Code Review**: APPROVED (independent godot-gdscript read-only pass + coordinator; 2 WARNINGs fixed + regression-tested; Pass-Through/opponent-echo-unreachability/timer-safety/static-typing/layer-direction all confirmed).
