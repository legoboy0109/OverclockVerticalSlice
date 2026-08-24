# QQ-06: AI Decision-Loop Performance Spike (ADR-0011)

> Throwaway `SceneTree` bench — **not** part of the shipping game and **not** a
> GdUnit4 suite. Kept only as the reproducible source behind the number cited in
> ADR-0011's Status block. See `qq06_ai_loop_bench.gd`'s file header for the
> line-by-line fidelity notes.

## Hypothesis

ADR-0011 (AI opponent) proposes a streaming enumerate→commit decision loop
(TR-ai-012): for each friendly unit, `choose_action()` scans every reachable
tile (ADR-0009 BFS-by-depth) and every legal attack target, scores candidates
with a running-best comparator (no candidate array materialized), then commits
one action and re-enumerates on the shrunken board. The ADR pins the *strategy*
but defers the concrete per-pass millisecond ceiling to this spike.

**Hypothesis under test:** a full `choose_action()` enumeration pass over
N ≤ 24 friendly units on the pinned **14×16** board is cheap enough that a
whole AI turn (several commits, each re-enumerating) resolves well inside a
turn-based tactics turn-resolution window — so the ADR's noted
incremental-invalidation fallback is *not* needed at VS scale.

## How to Run

```
./redot --headless --script prototypes/spikes/qq06_ai_loop_bench.gd
```

No GdUnit4 dependency — a `SceneTree` script that prints its own timing
(min / mean / median / p95 / max ms per full pass, plus a streaming
re-enumeration series across 5 simulated commits).

## Method

A self-contained, faithful port of the ADR-0011 enumeration *shape* — the real
`AI` / `Movement` / `Combat` / `GameState` classes did not yet exist when this
spike ran (all three systems were still in ADR/design phase). Minimal stand-ins
(`BenchUnit`, `BenchState`) carry just the fields the enumeration touches. The
loop is faithful to:

- **ADR-0009** `reachable()`: flat `PackedInt32Array` visited-depth, fixed
  N→E→S→W neighbor order, monotonic per-depth cost cutoff, soft-move-cap
  surcharge.
- **ADR-0011 SS2** streaming max-scan: entity-id-ascending iteration, running
  best via comparator (no candidate array), legal-attack scan over every
  reachable tile, cheap float scoring, one `GameState`-clone stand-in per unit
  (the ADR flags clone cost explicitly).
- Never calls `apply_action()` during enumeration — pure scoring; commit is a
  separate, unmodeled step.

Board: **14×16** (the ADR Status block's pinned worst case), N_FRIENDLY = 24,
N_ENEMY = 8, deliberately upward-biased AP so the reachable frontier is larger
than typical play. 200 timed passes after warmup, then a 5-commit streaming
series (one unit removed per commit).

## Status

Concluded — 2026-07-25 (**PASS**). Figure recorded in ADR-0011's Status block;
this folder is the reproducible source.

## Findings

**Headline (as cited in ADR-0011):** ~**3.7 ms p95 / ~3.68 ms mean** per full
`choose_action()` pass (≈845 candidates scored per pass) at N ≤ 24 units on the
14×16 board, under an upward-biased AP setting.

**Verdict: PASS.** Turn-based tactics has no 16.6 ms frame deadline; a turn
resolves in a hundreds-of-ms-to-seconds window. At ~3.7 ms per pass, even a full
multi-commit AI turn (each commit re-enumerating a slightly smaller board) stays
comfortably inside that window. The ADR's incremental-invalidation fallback is
**not warranted** at this scale.

## Caveats

- Stand-in implementation, **not** the real `AI.choose_action()`. ADR-0011's
  Status lists the two follow-ups this obligates once the real systems land:
  (a) replace the `[PLACEHOLDER]` budget in the ADR with the measured ~3.7 ms;
  (b) re-run against the real `AI`/`Movement`/`Combat` to confirm no unexpected
  overhead (real `GameState.clone()`, occupant resolution, etc.).
- Uniform terrain cost only (difficult terrain is out of scope for both the ADR
  and this spike).
- Enemy/target population and AP are representative worst-case stand-ins, not
  adversarially maximized beyond the pinned knobs.
