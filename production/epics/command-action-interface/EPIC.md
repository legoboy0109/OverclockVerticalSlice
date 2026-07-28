# Epic: Command & Action Interface

> **Layer**: Presentation
> **GDD**: design/gdd/command-action-interface.md
> **Architecture Module**: Command & Action Interface (Presentation Layer)
> **Status**: Ready
> **Stories**: 9 stories (see `## Stories` below) — none implemented yet

## Overview

The Command & Action Interface is the Presentation-layer pre-commit action loop
between player input and every AP-costed action. On selection it queries the
owning system's side-effect-free previews (`reachable`, `legal_targets` / the
hypothetical-tile overload, `legal_build_tiles`, `can_afford`), renders on-board
overlays and exact numbers, and commits one atomic `apply_action` only on confirm
— so a preview is a guarantee, not an estimate (the Pass-Through Invariant: it
holds zero balance constants and re-derives no formula). Architecturally it is a
leaf Presentation node: a headless `CommandFSM` (`RefCounted`) driven by a
`CommandInterface` (`Node`), consuming all Core query APIs plus the Board Renderer
transform, routing every mutation through `apply_action` and emitting one
`selection_changed` signal to the HUD. Its four-tier recompute discipline
(entry / frontier-batch / O(1) hover / commit-time point-check) and the shared
commit-flash↔AP-tick event are the load-bearing correctness + performance items
the FSM ADR locks in.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0015: Command & Action Interface FSM | 7-state Command FSM (incl. terminal GAME_OVER); 4-tier preview-query caching; tile-change gating; Pass-Through Invariant; commit routing via `apply_action` | MEDIUM |
| ADR-0013: Isometric Board Rendering, Picking & Overlays | Grid→screen 2:1 dimetric transform; custom inverse screen→grid hit-test; depth-sort; iso overlay re-derivation; glyph anchoring | HIGH (spike CLEARED PASS 2026-07-25) |
| ADR-0014: Input & Focus Architecture | Dual-focus input model; `BoardCursor` (grid-space keyboard/gamepad nav); hover/cursor precedence; `INPUT_LOCK_MS`; full keyboard reachability | HIGH (spike CLEARED PASS 2026-07-25) |

## GDD Requirements

All 24 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0015 (FSM / previews / commit) | TR-cmdui-001, -002, -005, -006, -007, -008, -009, -010, -011, -012, -013, -014, -015, -023 | ✅ |
| ADR-0013 (iso picking / overlays) | TR-cmdui-003, -004, -016, -017 | ✅ |
| ADR-0014 (input / focus) | TR-cmdui-018, -019, -020, -021, -022, -024 | ✅ |

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/command-action-interface.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The preview→commit spine proves the Pass-Through Invariant end-to-end: a rendered preview (move range / targets / exact AP cost) matches the committed `apply_action` result byte-for-byte, and a commit-time rejection refreshes the preview while spending 0 AP

## Dependencies & Sequencing

- **Depends on (Complete):** Foundation (Grid, Game State, AP), Unit System, Movement, Combat Resolution — their `reachable`, `legal_targets`/hypothetical overload, `preview_damage`, `can_afford` queries are the live previews this epic consumes.
- **Depends on (Complete this session):** Base & Production — `legal_build_tiles`/`legal_deploy_tiles`/`production_cap` and the build/produce/cancel-build verbs back TR-cmdui-013's build/produce previews.
- **Isometric Board Renderer (ADR-0013):** provides `grid_to_screen`/`screen_to_grid`; the picking + overlay re-derivation math is the largest new surface. Its HIGH engine risk is retired — the ADR-0013 and ADR-0014 spikes both cleared PASS 2026-07-25.
- **Seam it produces for Game HUD (#10):** `selection_changed`, `projected_remaining_ap`, the `PREVIEW_BUILD` state cue, and the shared `action_applied` commit-flash↔AP-tick event. Sequence this epic's FSM/commit spine **before** the HUD stories that consume those seams.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | CommandFSM Core — States, Transitions, Menu Model, Pass-Through Enforcement | Logic | ✅ Complete | ADR-0015 |
| 002 | Four-Tier Recompute Discipline (Tier 1–4) | Logic | ✅ Complete | ADR-0015 |
| 003 | Dependency Consumption Contracts — Move/Combat/B&P/AP/Turn | Integration | ✅ Complete | ADR-0015 |
| 004 | Cancel-Build Destructive Gesture (Hold-to-Confirm) | Logic | ✅ Complete | ADR-0015 |
| 005 | BoardCursor Input Substrate — Grid-Axis Nav, Precedence | Logic | Ready | ADR-0014 |
| 006 | Isometric Picking & Overlay Integration | Integration | Ready | ADR-0013 |
| 007 | Commit Dispatch, INPUT_LOCK_MS & Commit-Flash↔AP-Tick Signal | Integration | Ready | ADR-0014, ADR-0015 |
| 008 | Post-Commit Re-Selection & GAME_OVER Convergence | Integration | Ready | ADR-0015 |
| 009 | Dual-Focus Reachability & Menu Keyboard Nav | UI | Ready | ADR-0014 |

**Implementation order**: 001 → 002 → 003, then {004, 005} in parallel, {006, 007}
after 003 (006 also needs the Board Renderer node), 008 after 007, 009 last.

> **✓ Cross-epic prerequisite (Story 006) — SATISFIED (2026-07-27)**: consumes
> `BoardRenderer.pick_at`/`grid_to_screen`/`set_overlay` from the **Isometric
> Board Renderer (ADR-0013)**, whose epic is now **COMPLETE** (br-001..005). Story
> 006 is **UNBLOCKED**. The same node backs the Game HUD on-board glyph layer.

## Next Step

Run `/story-readiness production/epics/command-action-interface/story-001-command-fsm-core.md`,
then `/dev-story` to begin. Work through stories in dependency order — each story's
`Depends on:` field states its prerequisite.
