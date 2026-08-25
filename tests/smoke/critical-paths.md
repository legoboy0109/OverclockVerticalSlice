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

> ✅ **Now runnable.** These returned "not profiled" in every smoke report up to 2026-08-25
> because no target hardware was named and the memory ceiling read `[TO BE CONFIGURED]`.
> The **Steam Deck floor** and the budgets in `technical-preferences.md` give them
> thresholds, so they pass or fail rather than abstain.

16. **Frame rate** — 60 FPS at 1280×800 with no visible drops during camera moves, menu
    transitions, and an AI turn playing out. Fail if sustained below 60.
17. **Peak resident memory** — under the **1 GB** ceiling; note it if it crosses the **700 MB**
    soft alert. Baseline to compare against: **145 MB** headless (2026-08-25), and headless
    holds no textures, so a rendered figure of ~400–600 MB is expected and fine.
18. **Idle cost** — the game must not render a static board at full rate while waiting on the
    player. ⛔ **Currently FAILS**: `low_processor_usage_mode` is unset. On the floor target
    that is battery and heat spent on nothing.

### How to measure without a Deck

Both 16 and 17 can be sampled on a desktop; neither is a substitute for the device.

```bash
# Peak resident memory of a real slice run, sampled from /proc.
( ./redot --headless --quit-after 600 res://scenes/vertical_slice.tscn >/dev/null 2>&1 & P=$!
  M=0; while kill -0 $P 2>/dev/null; do
    R=$(grep VmHWM /proc/$P/status 2>/dev/null | awk '{print $2}')
    [ -n "$R" ] && [ "$R" -gt "$M" ] && M=$R
  done; echo "peak RSS: $((M/1024)) MB" )
```

⚠ `/usr/bin/time -v` is **not installed on this machine** — use the loop above, not `time`.
⚠ Headless renders nothing, so this measures logic and resource loading only. A windowed
run is needed for the real figure, and the Deck for the real *answer*.

> ★ **Do not quote any of these on a store page until a Deck has run the build.** They are
> desktop measurements reasoned to a target, which is enough for a regression gate and not
> enough for a spec claim.
