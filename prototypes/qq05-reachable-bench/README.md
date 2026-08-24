# QQ-05: `reachable()` Performance Spike (ADR-0009)

## Hypothesis

ADR-0009 (reachable-search pathfinding) proposes a plain BFS-by-depth
algorithm, allocated fresh on every call (no caching, no pooling), called
both interactively (once per player unit-selection) and repeatedly by the
AI (many times per turn across cloned `GameState`s, per ADR-0011). The ADR
pins no concrete performance budget — it defers that number to this spike.

**Hypothesis under test:** fresh-per-call BFS-by-depth on a 24x24 grid (the
ADR's stated worst-case board size) is fast enough that (a) an interactive
selection is imperceptible to a player, and (b) the AI can call it hundreds
to thousands of times per turn within a reasonable turn-resolution budget,
given turn-based tactics has no hard per-frame deadline.

## How to Run

```
./redot --headless --script prototypes/qq05-reachable-bench/qq05_reachable_bench.gd
```

No GdUnit4 dependency — this is a `SceneTree` script, not a test suite.
Output is printed directly (min/mean/p50/p95/p99/max microseconds per call,
plus calls-per-16.6ms-frame, per scenario).

## Method

The benchmark is a self-contained, faithful port of ADR-0009's algorithm
shape — `src/` has no `GridState`/`GameState`/`UnitState` yet (the Movement
System epic is blocked pending this ADR's Accept), so minimal stand-in
structures (`GridStub`, `UnitStub`) were used. The algorithm itself is
copied from the ADR's pseudocode verbatim: fresh `PackedInt32Array
visited_depth` per call, `Array[Vector2i]` frontier-by-depth expansion,
fixed N->E->S->W neighbor order, closed-form `_cost_for_depth` (soft-cap
surcharge), and the monotonic early-exit the instant a depth's cost exceeds
`current_ap`. No caching, no pooling, no algorithmic shortcuts beyond what
the ADR itself describes.

Board: 24x24 (576 tiles) — the ADR's stated upper board-size range.

Scenarios: the four GDD-tuned archetypes (Scout mc1/cap4, Trooper mc2/cap3,
Heavy mc3/cap2, Sniper mc2/cap3) at 10 AP, crossed with 0% and 20% obstacle
density, plus a 9th worst-case row — a Scout at 99 AP on an open board,
which saturates nearly the entire 24x24 board (the true upper bound on
frontier size, and the number ADR-0009 most needs to cite).

Each scenario: 200 warmup calls (discarded), then 10,000 individually-timed
calls via `Time.get_ticks_usec()`.

## Status

Concluded — 2026-07-25.

## Findings

Two runs were taken to confirm stability; both agreed within noise.

| Scenario | Tiles Returned | Min (us) | Mean (us) | p95 (us) | Calls/16.6ms frame |
|---|---|---|---|---|---|
| Scout, 10 AP, 0% obstacles | 112 | 316 | 337 | 346 | 49.2 |
| Scout, 10 AP, 20% obstacles | 88 | 263 | 281 | 286 | 59.2 |
| Trooper, 10 AP, 0% obstacles | 40 | 105 | 112 | 116 | 147.8 |
| Trooper, 10 AP, 20% obstacles | 32 | 88 | 94 | 97 | 175.8 |
| Heavy, 10 AP, 0% obstacles | 12 | 28 | 30 | 31 | 552.8 |
| Heavy, 10 AP, 20% obstacles | 10 | 24 | 25 | 26 | 663.9 |
| Sniper, 10 AP, 0% obstacles | 40 | 106 | 113 | 115 | 147.0 |
| Sniper, 10 AP, 20% obstacles | 32 | 89 | 95 | 97 | 175.2 |
| **WORST-CASE**: Scout, 99 AP, 0% obstacles (full-board saturation) | 575 / 576 | 1768–1785 | ~1970–1990 | ~1985–2006 | **8.4–8.5** |

**Headline number for ADR-0009: ~2.0ms per call in the worst realistic case**
(near-full-board saturation, 24x24, fresh-per-call, no caching). Typical
in-game calls (10 AP archetypes) are 25-340us — 6-80x cheaper than the
saturated worst case, because real units rarely have enough AP to reach
the entire board.

**Verdict: PASS.** Both interactive and AI-repeat call patterns are well
within a turn-based tactics budget:
- **Interactive (player selects a unit):** worst case ~2ms is far below
  human perception of "instant" (~100ms). Even stacking several selections
  in one input frame costs single-digit milliseconds.
- **AI-repeat (many calls per turn):** turn-based has no 16.6ms hard
  deadline, but even holding it to that bar as a *stretch* ceiling, ~8
  calls/frame-equivalent at worst case is not the constraint — turn
  resolution windows in tactics games are typically hundreds of
  milliseconds to a few seconds, giving headroom for **hundreds to
  low-thousands of `reachable()` calls per AI turn** (e.g. 500 calls x
  ~2ms worst-case = ~1s; realistic mixed-archetype calls average far
  below 2ms, so 1,000+ calls/turn is comfortably under 1s even in the
  worst case, and under ~200ms for realistic archetype/AP mixes).

**Practical ceiling to cite:** *"reachable() worst-case (full-board
saturation, 24x24) costs ~2.0ms/call fresh-per-call. At 500 AI candidate
evaluations per turn — a generous estimate for the VS's roster/board size —
worst-case total cost is ~1.0s; realistic-mix cost is under ~150ms. Both
are acceptable for a turn-resolution window, not a frame budget."*

No caching/pooling optimization is warranted at this scale — the ADR's own
noted risk (fresh-per-call GC/alloc cost) does not materialize as a
bottleneck at 24x24. Revisit only if AI candidate-evaluation counts grow
by an order of magnitude (e.g. deep multi-turn lookahead) or board sizes
grow well past 24x24.

## Caveats

- This is a stand-in implementation, not the real `Movement.reachable()` —
  once ADR-0009 is implemented against real `GridState`/`GameState`/
  `UnitState`, a follow-up spike (or a perf regression test) should
  re-measure against the actual classes to confirm no unexpected overhead
  (e.g. from `GameState.clone()`-produced state, occupant resolution via
  `entity_at()`, etc. — this spike used trivial stand-ins for those).
- Difficult terrain (variable per-tile move cost) is explicitly out of
  scope for both the ADR and this spike — uniform-cost only.
- Obstacle placement is random (seeded, deterministic within a run) --
  not adversarially constructed to maximize/minimize frontier size beyond
  the density knob. The 0%-obstacle worst-case row is the actual adversarial
  bound (nothing blocks expansion).
