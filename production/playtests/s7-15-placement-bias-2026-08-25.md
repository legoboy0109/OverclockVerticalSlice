# The residual was placement — deploy and build tiles

> **Follows**: `s7-14-tiebreak-fix-2026-08-25.md`, which fixed movement but left a ~60/40 lean
> **Date**: 2026-08-25 · **Story**: S7-15
> **Status**: ✅ **Residual eliminated. The AI is now seat-fair.**

---

## The same bug, one layer down

`BaseProduction.legal_deploy_tiles` and `legal_build_tiles` both end with:

```gdscript
out.sort_custom(func(a, b): return grid.index(a.x, a.y) < grid.index(b.x, b.y))
```

Row-major order — **north first, then west-to-east within a rank.** And the AI consumed that
order as a decision:

- **Produce.** Every deploy tile for a given unit type shares the same AP cost and producer id,
  so tiles in the same reachability band tie on score, `_is_better` refuses to replace, and the
  **first enumerated wins** — the north-west-most tile.
- **Build.** Worse: it took `tiles[0]` outright. **Placement was purely list order.**

★ Not symmetric between the seats. For a west-based player the north-west-most tile is safely
**behind** their line; for an east-based player the identical rule places **toward the enemy**.
Structures cannot retreat, so that difference compounds for the rest of the match.

## The fix

Reused S7-14's `_tile_wins_tie`, with one addition: a `prefer_forward` flag.

| Decision | Direction | Why |
|---|---|---|
| Movement (advance / siege / retreat / combo) | **forward** | a unit is useful nearer the fight |
| **Build placement** | **away** | a structure is safer further from the enemy |

⚠ Both directions are equally mirror-invariant. **The property that matters is that each seat
applies the same rule in its own frame — not which way the rule points.**

Produce now folds into a per-producer local best before competing globally, for the same reason
S7-14 gave: a tile-versus-tile comparison across two different candidates is meaningless.

The sorts in `BaseProduction` are untouched. They are that class's determinism contract and were
never the bug — **treating their order as a decision was.**

## Result — the residual is gone

### Seat matrix

| Cell | S7-14 | **S7-15** |
|---|---:|---:|
| +1, P0 starts | P0 9 : P1 5 · converted 12/14 | **P0 7 : P1 7 · converted 14/14** |
| +1, P1 starts | P0 8 : P1 6 · converted 12/14 | **P0 7 : P1 7 · converted 14/14** |

★★ **Exactly even, from both seats, with material advantage converting perfectly.** That is the
fair result a symmetric board with a deterministic AI should produce.

### S6-06 gate

| Condition | Original | S7-14 | **S7-15** |
|---|---:|---:|---:|
| **Seat split** | P0 6 / P1 16 | P0 12 / P1 10 | **P0 11 / P1 11** |
| **Material converts** | 15/18 | 16/18 | **18/18** |
| Handicapped resolving on play | — | 18/18 | **18/18** |
| Resolve on play (all) | 20/22 | 18/22 | 18/22 |
| Mean turns | 38.7 | 30.7 | 28.9 |

The four unresolved games are the mirror cell reaching the cap, which is correct: a genuinely
symmetric deterministic match should tiebreak.

## ⛔⛔ This reverses the first-turn AP recommendation — again, and now on clean data

The mirror cell, with every known bias removed:

| Mirror cell | Result |
|---|---|
| P0 starts | **P0 0 : P1 4** |
| P1 starts | **P0 4 : P1 0** |

**Whoever moves SECOND wins all four, from either seat.** Perfectly symmetric, and far cleaner
than S7-14's 3/1 — which was measured while the placement bias was still present.

> ### ⚠ My earlier reading was wrong, and here is the correction
> After S7-14 I reported a **first-mover advantage** and said a first-turn AP reduction had
> become the right tool. **That reading contained the placement bias.** With it removed, the
> effect runs the other way and much more strongly: **the first player is at a disadvantage.**
>
> ⇒ **A first-turn AP reduction would make this worse.** The remedy pointing the right way is
> to **compensate the first player** — extra AP or an extra action on turn 1 — or equivalently
> to trim the *second* player's opening turn.
>
> ★ The mechanism is the one S5-04 guessed at from the very beginning: *"on a symmetric board
> the first player must commit into the open, and the second player answers with full
> information about that commitment."* With no fog and deterministic combat, moving second is
> genuinely better. Every measurement that pointed elsewhere was pointing at a bug.

⚠ **n = 4 per mirror condition** — but 4/0 in both directions is a much stronger signal than
3/1 was. `MIRROR_OPENINGS` caps that cell at 4; widen it before choosing a compensation value.

## Verification

Suite **1260/1260**, 0 orphans. Raw batches: `s7-15-gate-raw.txt`, `s7-15-seat-matrix-raw.txt`.
