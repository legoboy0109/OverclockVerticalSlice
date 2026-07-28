# Epic: Game HUD

> **Layer**: Presentation
> **GDD**: design/gdd/game-hud.md
> **Architecture Module**: Game HUD (Presentation Layer)
> **Status**: ✅ In-slice Complete (2026-07-28) — 7/7 in-slice stories done (001–007); story 008 (audio dispatch) trimmed to Production per the Sprint 3 plan
> **Stories**: 8 stories (see `## Stories` below) — 7/7 in-slice Complete; 008 deferred

## Overview

The Game HUD is the persistent, always-on Presentation-layer information surface
— the *know* half of the know/act split with the Command & Action Interface. It
is a pure-read, event-driven render layer (never mutates state, holds zero balance
constants) that binds outward-in to seven upstream systems through a getters-only
`GameStateReader` facade and coalesces dirty state to ≤1 redraw/frame. It owns the
first-class-neon AP counter (a 4-state animation FSM: Committed-rest / Fill-flourish
/ Tick-down / Preview-echo, with opponent-AP muting), the turn/round indicator and
YOUR/ENEMY banners, the append-only action-log ring buffer, the on-board glyph layer
(hp pips, has-acted, tech/build/research markers), the detail info panel (content
follows #9's `selection_changed`, chrome owned here), the victory/defeat presentation,
and the placement + style of the Build and End-Turn controls (whose *interaction*
routes to #9 / the turn manager). Its AP-tick relies on #9's
`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` sequencing and must not build its own tick queue.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0016: Game HUD | `GameStateReader` getters-only facade; AP-counter animation FSM; action-log ring; single-owner audio dispatch + total priority order; 7-system read binding | MEDIUM |
| ADR-0013: Isometric Board Rendering, Picking & Overlays | On-board glyph layer anchored per-entity via `grid_to_screen`, reprojecting under the iso transform; fixed per-tile sub-positions + occlusion priority | HIGH (spike CLEARED PASS 2026-07-25) |
| ADR-0004: Event / signal architecture | HUD is a signal-subscribed pure-read layer; dirty-flag redraw coalescing; no per-`_process` polling | LOW |
| ADR-0006: AP Economy | Consumes pre-computed `ap_income_breakdown(player)` for the income readout (no local recompute) | LOW |

> The two headline ADRs are {0016, 0013}; four HUD TRs are primarily governed by
> ADR-0004 (TR-hud-001/002/023) and ADR-0006 (TR-hud-019). All four ADRs are
> Accepted, so the effective ADR set is {0016, 0013, 0004, 0006} — stated here so
> `/story-readiness` does not false-flag a missing ADR on those TRs.

## GDD Requirements

All 23 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0016 (facade / AP-FSM / log / audio) | TR-hud-003, -004, -005, -006, -007, -008, -009, -012, -013, -014, -015, -016, -017, -018, -020, -021 | ✅ |
| ADR-0013 (iso glyph layer) | TR-hud-010, -011 | ✅ |
| ADR-0004 (event-driven render) | TR-hud-001, -002, -023 | ✅ |
| ADR-0006 (income breakdown) | TR-hud-019 | ✅ |
| ADR-0014 (dual-focus reachability) | TR-hud-022 | ✅ |

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-hud.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The read-only invariant is enforced structurally: the HUD binds only through the getters-only `GameStateReader` facade (a mutating call does not compile), holds zero balance constants, and every displayed value is a live verbatim read (anim deltas exempt)

## Dependencies & Sequencing

- **Depends on (Complete):** Foundation (Game State, AP), Unit System, Movement, Combat Resolution, Base & Production — the seven upstream read sources the facade exposes.
- **Isometric Board Renderer (ADR-0013):** provides `grid_to_screen` for the on-board glyph layer (same HIGH-risk transform as the CAI epic; spike CLEARED PASS).
- **Bidirectional seam with Command & Action Interface (#9):** consumes #9's `selection_changed` (detail panel), `projected_remaining_ap` (inline AP echo), and the shared commit-flash↔AP-tick event. Sequence the HUD stories that bind those **after** CAI's FSM/commit spine lands. The rest (readouts, log, banners, audio, glyph layer) can proceed in parallel with CAI — no shared files.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | GameStateReader Facade + Event Binding + Dirty-Flag Coalescing | Logic | ✅ Complete | ADR-0016, ADR-0004 |
| 002 | HUDConfig Resource + Cross-Config Loader Guard | Logic | ✅ Complete | ADR-0016, ADR-0014 |
| 003 | ApCounterFsm — 4-State AP Counter Core (headless) | Logic | ✅ Complete | ADR-0016 |
| 004 | AP Counter Widget + Opponent Muting + Preview Echo + Turn/Round Banner | Integration | ✅ Complete | ADR-0016 |
| 005 | On-Board Glyph Layer — hp Pips/Numeric + Markers | Visual/Feel | ✅ Complete | ADR-0013, ADR-0016 |
| 006 | Detail Panel + Victory/Defeat GameOver Preemption | Integration | ✅ Complete | ADR-0016 |
| 007 | Action Log + Income Breakdown + Build/End-Turn + Turn-Scoping | Integration | ✅ Complete | ADR-0016, ADR-0006 |
| 008 | HudAudioDispatcher — Single-Owner play() + Priority Order | Integration | Ready | ADR-0016 |

**Implementation order**: {001, 002} first (parallel) → then {003→004}, {005}, {006},
{007} in parallel once their cross-epic gates clear → 008 last. Gates: 003/004 need
**CAI Story 007** (shared `action_applied` signal) + CAI Story 003; 005 needs **Board
Renderer Story 005** (`grid_to_screen`+`GLYPH_OFFSETS`); 006 needs **CAI `selection_changed`**.

> **⚠ Cross-epic seam flags**:
> - **Story 006** consumes CAI's `CommandInterface.selection_changed(target)` — ✅ **RESOLVED 2026-07-28**:
>   the forward-declared signal (ADR-0016 §6) is now implemented in the CAI epic as a cross-epic
>   addendum — `CommandInterface` emits `selection_changed(SelectionTarget{entity_id, pinned})` at all
>   selection points (pinned) + an `inspect(state, tile)` peek entry, de-duplicated, one-way outward-in.
>   `SelectionTarget` is `src/ui/command_action_interface/selection_target.gd`; tests in
>   `tests/unit/command-action-interface/selection_changed_test.gd` (9, pass). Story 006 is UNBLOCKED.
> - **Story 008** audio ducking (≥2 `AudioStreamPlayer`s) is the one under-spiked engine detail —
>   check against the live 4.6 audio bus API before starting.
> - **Story 002** owns the `InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms` config-loader
>   guard that CAI Story 007 explicitly deferred to this epic.

## Next Step

Run `/story-readiness production/epics/game-hud/story-001-game-state-reader-facade.md`,
then `/dev-story` to begin. Work through stories in dependency order — each story's
`Depends on:` field states its prerequisite (including cross-epic gates).
