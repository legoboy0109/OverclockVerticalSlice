# Smoke Test: Critical Paths — OVERCLOCK

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New match can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic (update per sprint as systems land)

<!-- Add the primary mechanic for each sprint here as it is implemented. -->
<!-- OVERCLOCK is a turn-based tactics game — seed entries follow the Foundation ADRs. -->
4. [Turn loop — once ADR-0008 start-of-turn sequencing is implemented: a turn can be
   started, AP resets to the income snapshot, and End Turn passes to the other player]
5. [Movement — once ADR-0009 pathfinding lands: a unit can move within its reachable set
   and occupancy updates atomically]
6. [Combat — once ADR-0010 lands: an attack resolves, HP updates, and an HQ reaching 0 HP
   triggers a synchronous GameOver / win-check]

## Data Integrity

7. Save game completes without error (once save system is implemented — deferred per architecture)
8. Load game restores correct state (once load system is implemented — deferred)
9. AI `clone()` of GameState produces an independent state (no aliasing) — per ADR-0001/0007

## Performance

10. No visible frame rate drops on target hardware (60 FPS target)
11. No memory growth over 5 minutes of play (once core loop is implemented)
