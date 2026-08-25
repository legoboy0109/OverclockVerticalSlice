# Fixing the tie-break, and re-validating everything downstream

> **Follows**: `s7-13-seat-bias-2026-08-25.md`, which root-caused the bias to BFS enumeration order
> **Date**: 2026-08-25 · **Story**: S7-14

---

## The fix

The AI's folds use `_is_better`, which requires **strictly** better to replace. So among
candidates tying on every scored criterion, the first one enumerated won — and
`Movement.reachable()` expands neighbours N→E→S→W, so "first enumerated" silently meant
"furthest East".

Replaced with a tie-break expressed in **each player's own frame**, applied everywhere a
destination is chosen (advance, siege, retreat, and the move+attack combo):

1. **Closer to the enemy HQ** — each seat measures toward its own opponent, so the comparison
   means the same thing on both sides of the board.
2. **Closer to the HQ-to-HQ axis** — prefer the lane over a flank drift.
3. **Smaller coordinate on the axis *perpendicular* to the HQ-to-HQ line.**

★ Step 3 is the subtle one. A total, deterministic order needs *some* coordinate key, but a
coordinate key is only harmful on the axis the two players are mirrored across. Taking it
perpendicular means both seats express the identical preference — **the bias becomes shared
rather than sided, and shared is fair.**

⛔ **Deliberately not done: reversing Movement's neighbour order.** That is a different arbitrary
direction which merely tests well on an east-west map and would bias the other way on a
north-south one. The order there is Movement's own determinism contract and was never the bug;
**treating enumeration order as a decision rule was.**

Retreat and the attack combo now fold into a **per-entity local best** before competing
globally, because a tile-versus-tile comparison across two different entities is meaningless.

---

## Re-run 1 — the S6-06 gate

| Condition | Before fix | **After fix** | |
|---|---:|---:|:--|
| **Seat split** | P0 6 / P1 16 | **P0 12 / P1 10** | ✅ essentially even |
| Material advantage converts | 15/18 | **16/18** | ✅ |
| Handicapped games resolving on play | — | **18/18** | ✅ |
| Resolve on play (all cells) | 20/22 | 18/22 | see below |
| Mean turns | 38.7 | 30.7 | ✅ shorter |

★ **Resolve-on-play falling 20 → 18 is correct, not a regression.** All four mirror games now
reach the round cap, where before two were won outright. With a fair tie-break a genuinely
symmetric, deterministic match *should* tiebreak — one side winning it was the bias, not play.
**Every handicapped game — all 18 — now finishes on play.**

## Re-run 2 — the skill-degradation sweep (+1 cell, n=14)

| Leader degraded | Underdog wins, before | **after** | Mean doubt, before → after |
|---:|---:|---:|---:|
| **0 %** | 0/14 | **2/14** | 3 % → **12 %** |
| 5 % | 1/14 | 4/14 | 16 % → 24 % |
| 10 % | 3/14 | 4/14 | 39 % → 32 % |
| 15 % | 6/14 | 4/14 | 51 % → 22 % |
| 20 % | 5/14 | 7/14 | 50 % → 56 % |
| 30 % | 9/14 | 9/14 | 50 % → 51 % |
| 40 % | 9/14 | 9/14 | 72 % → 64 % |
| 50 % | 11/14 | 12/14 | 62 % → 64 % |

★ **The 0 % row moved off zero**, and that matters. A one-unit lead at equal play now converts
**12 of 14** rather than 14 of 14. The old perfect determinism was partly the seat bias making
outcomes fixed; the game now has genuine variance at the top of the curve while still converting
"more often than not", which is what the gate actually asks for.

## Re-run 3 — the seat matrix

| Cell | Before fix | **After fix** |
|---|---:|---:|
| +0 mirror, P0 starts | P0 1 : P1 3 | **P0 3 : P1 1** |
| +0 mirror, P1 starts | P0 1 : P1 3 | **P0 1 : P1 3** |
| +1, P0 starts | P0 0 : P1 14 | **P0 9 : P1 5** |
| +1, P1 starts | P0 4 : P1 10 | **P0 8 : P1 6** |

### ★★ The mirror cell now shows a clean, symmetric FIRST-MOVER advantage

Before, P1 won 3/4 **regardless of who started** — a seat effect. Now **whoever moves first wins
3/4, from either seat.** The seat bias is gone, and what remains underneath it is an ordinary
turn-order advantage.

> ⇒ **This is where the first-turn AP reduction becomes the right tool.** It was the wrong
> remedy while the seat bias dominated — the data then showed turn order contributing nothing,
> and moving first was if anything a slight *disadvantage*. With the tie-break fixed, the
> residual asymmetry in a perfectly symmetric match is **exactly** a first-move advantage, which
> is the textbook case for exactly that fix.
>
> ⚠ n = 4 per mirror condition. Symmetric across both conditions, which is encouraging, but this
> wants more openings before a value is chosen. `MIRROR_OPENINGS` currently caps the cell at 4.

## ⚠ Residual, stated plainly

The **+1 cell still leans to P0 (west)** — 9/14 and 8/14, roughly 60/40 — where a fair result
would be 7/7. That is a large improvement on 14/0 but it is not zero.

Likely remaining sources, none yet measured:
- `BaseProduction.legal_deploy_tiles` also uses `_neighbors_in_fixed_order`, so **deploy-tile
  choice for produced units is still enumeration-ordered.**
- The map is 10 tiles tall with both HQs on rank 5 — 5 ranks north, 4 south — so the
  perpendicular tie-break's "prefer smaller y" has slightly more room to the north. Shared
  between the seats, but not neutral in absolute terms.

## Verification

Suite **1260/1260** (+7 new), 0 orphans. The new suite pins the property that was violated:
whatever a west-based unit prefers, an east-based unit must prefer the mirror image of it.

Raw batches: `s7-14-postfix-gate-raw.txt`, `s7-14-postfix-skill-sweep-raw.txt`,
`s7-14-postfix-seat-matrix-raw.txt`.
