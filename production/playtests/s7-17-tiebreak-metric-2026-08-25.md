# HQ damage dealt as the tiebreak metric — implemented, and it changes nothing

> **Follows**: `s7-16-first-turn-compensation-2026-08-25.md`
> **Date**: 2026-08-25 · **Story**: S7-17
> **Result**: ✅ shipped as the default · ⛔ **does not affect any outcome, and here is why**

---

## ⚠ First, a correction to S7-16

S7-16 recommended changing the tiebreak metric on the grounds that *"all ten second-mover wins
are unit-count tiebreaks"*. **That was wrong.** I repeated the stale note on `VS_MAX_ROUNDS` —
*"`TiebreakMetric.UNIT_COUNT` is the only implemented metric"* — instead of checking. The enum
itself flags that note as superseded on 2026-08-21.

**The shipped default was already `TOTAL_HQ_HP`**, and it was working correctly. In the capped
mirror games the winner is always the side with the healthier HQ:

```
game 1: hq0= 4  hq1=38  -> P1 wins      game 3: hq0=16  hq1=26  -> P1 wins
game 2: hq0=26  hq1=16  -> P0 wins      game 4: hq0=37  hq1= 8  -> P0 wins
```

## The change, and why it is still worth shipping

`HQ_DAMAGE_DEALT` scores each side by the damage **it dealt to the enemy HQ**, and is now the
default.

★ **It is mathematically identical to `TOTAL_HQ_HP` while both HQs share a max hp.** P0 wins
under damage-dealt iff `(max − hp₁) > (max − hp₀)` iff `hp₀ > hp₁` — which is exactly the
`TOTAL_HQ_HP` comparison. Verified rather than argued: the 12-opening mirror cell returns
**identical winners in 12 of 12 games**, and a unit test pins the ordering agreement across
seven damage configurations.

So why ship it?

1. **It stops being equivalent the moment the HQs differ.** `faction-identity` allows
   per-faction structure deltas. The instant one side's HQ has more hp than the other's,
   "whose HQ is healthier" starts rewarding **whoever was handed the bigger HQ**, while "who
   dealt more damage" keeps measuring play. The equivalence is a coincidence of today's roster,
   not a property of the design.
2. **It says what it means.** A capped game is decided by progress toward the win condition;
   this states that directly rather than via its complement.

⇒ **A correctness and future-proofing change, not a balance change.** Nothing about the current
game moves.

## ⛔ So the first-move disadvantage is real play, not a metric artifact

This eliminates S7-16's option 1. The second mover **genuinely deals more HQ damage** — it is
earning those wins under a metric that was already measuring the right thing.

Restating the position with that correction applied:

| | Status |
|---|---|
| Seat bias | ✅ **Fixed** (S7-13/14/15) — seats 7/7, material converts 14/14 |
| First-turn AP compensation | ⛔ **Inert** — AP was never scarce (S7-16) |
| Tiebreak metric | ⛔ **Was already correct** — this story only makes it robust |
| **First-move disadvantage** | ⚠ **Real, unaddressed** — second mover wins 10/12 in the mirror |

### What is left

- **Compensate in a binding currency.** `production_cooldown_turns` is the measured constraint
  (S7-10). Starting the first player one tick ahead is denominated in something that actually
  limits them — unlike AP, which they already discard every turn.
- **Accept it.** A perfectly symmetric deterministic mirror may simply favour the responder, and
  real matches are never perfectly symmetric: with any material asymmetry at all the seats are
  exactly 7/7 and material converts 14/14. ★ Note also that the two mirror games which
  **resolve on play** are both won by the *first* mover — the disadvantage only appears in games
  that time out.

## Verification

Suite **1262/1262** (+2), 0 orphans. Mirror cell identical 12/12. Gate re-run for regression.
