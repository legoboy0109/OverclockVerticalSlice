# Smoke Test: Critical Paths — OVERCLOCK

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New match can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic (update per sprint as systems land)

> ⚠ **De-bracketed 2026-08-25 (Sprint 6 close-out).** Entries 4–6 sat in
> `[once ADR-000X lands]` form for three sprints *after* those ADRs landed, so each read
> as pending while the system it describes was shipped, tested and playable. ★ **A
> placeholder whose release condition is another story's completion will not un-bracket
> itself** — the same failure mode as `game-hud.md` AC-22, which stayed marked "deferred
> until `MAX_ROUNDS` ships" through an entire sprint of `MAX_ROUNDS` shipping.

4. **Turn loop** (ADR-0008) — a turn starts, AP resets to the income snapshot, upkeep is
   charged, and End Turn passes to the other player.
5. **Movement** (ADR-0009) — a unit moves within its reachable set and occupancy updates
   atomically. "Boxed in" and "out of AP" are distinguishable to the player.
6. **Combat** (ADR-0010) — an attack resolves, HP updates, a counterattack fires, and an HQ
   reaching 0 HP triggers a synchronous GameOver / win-check.
7. **Economy** (S6-01/02) — income is `gross − upkeep = net`; a deficit locks
   produce/build/research and Disband is offered as the escape valve.
8. **Production and deployment** (S6-03/04/16) — build and produce respect per-structure
   maximums and the population cap; a unit deploys to a free tile within `deploy_radius` 2.
9. **The command interface** (S6-30) — selecting an entity opens a contextual verb menu;
   disabled verbs state their reason; Esc backs out one level and pauses only at the top.

## Screens (added 2026-08-25 — all four exist as of Sprint 6)

10. Main menu boots, New Skirmish starts a live match, Quit confirms.
11. Pause freezes the tree — including the AI's commit pacing — and un-pauses before any
    scene swap.
12. Settings persists to `user://`, stores overrides only, and reports a failed save.

## Data Integrity

13. Save game completes without error — **deferred per architecture, still out of scope.**
14. Load game restores correct state — **deferred.**
15. AI `clone()` of GameState produces an independent state (no aliasing) — per ADR-0001/0007.

## Performance

16. No visible frame rate drops on target hardware (60 FPS target).
17. No memory growth over 5 minutes of play.

> ⚠ Both performance entries are **unrunnable as written**: no target-hardware baseline
> exists (`technical-preferences.md` still reads `[TO BE CONFIGURED]` for the memory
> ceiling), so there is no threshold to pass or fail against. They have been reported as
> "not profiled" in every smoke report to date. **Either set the baseline or retire them** —
> a check that can only ever return "not measured" is noise in the gate.
