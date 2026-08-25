# Widening the mirror cell, and a compensation that does not work

> **Follows**: `s7-15-placement-bias-2026-08-25.md`
> **Date**: 2026-08-25 · **Story**: S7-16
> **Result**: ✅ mirror cell widened 4 → 12 · ⛔ **first-turn AP compensation measured as inert**

---

## 1. The mirror cell, widened 4 → 12

The mirror is the only cell that can measure a turn-order effect — every handicap cell starts
with a material asymmetry that swamps it — and at n=4 it could not support tuning a value.
`MIRROR_OPENINGS` now carries 12 symmetric openings. **The first four are unchanged and in
their original order**, so every batch recorded before S7-16 stays comparable.

### The result is far cleaner than n=4 suggested

```
var0  start=P0  winner=P1  80 turns (cap)      var6   start=P0  winner=P1  80 (cap)
var1  start=P1  winner=P0  80 turns (cap)      var7   start=P1  winner=P0  80 (cap)
var2  start=P0  winner=P1  80 turns (cap)      var8   start=P0  winner=P0  43 ← RESOLVED
var3  start=P1  winner=P0  80 turns (cap)      var9   start=P1  winner=P1  43 ← RESOLVED
var4  start=P0  winner=P1  80 turns (cap)      var10  start=P0  winner=P1  80 (cap)
var5  start=P1  winner=P0  80 turns (cap)      var11  start=P1  winner=P0  80 (cap)
```

Seats split **P0 6 / P1 6** — the S7-15 fairness result holds at triple the sample.

★★ **But look at the shape, which n=4 could not show.** The second mover wins **10 of 12** — and
**every one of those ten is a round-cap tiebreak on unit count.** The only two games that
resolve on play are won by the **first** mover.

> ⇒ **The "second-mover advantage" may not be a play advantage at all.** In a dead-even
> deterministic mirror neither side can break through, the game times out, and whoever is
> marginally ahead on units takes it. The first player, having committed first, is marginally
> behind at timeout. **That is a property of the tiebreak metric, not of the play.**

## 2. First-turn AP compensation — ⛔ measured, and it does nothing

Implemented as `EconomyConfig.first_turn_ap_bonus`, applied by `GameState.start_turn` on round 1
to the starting player only. Swept against the widened cell:

| Bonus | First-mover wins | Resolved on play | Mean turns |
|---:|---:|---:|---:|
| 0 | 2/12 | 2/12 | 73.8 |
| 5 | 2/12 | 2/12 | 73.8 |
| 10 | 2/12 | 2/12 | 73.8 |
| 15 | 2/12 | 2/12 | 73.8 |
| 20 | 2/12 | 2/12 | 73.8 |
| **30** | **2/12** | **2/12** | **73.8** |

**Not one game changed, at any value — including one that doubles the opening turn.**

⚠ **This is a real negative, not another silent no-op.** The bonus verifiably lands: the batch
rows show turn-1 AP reading **30 → 60**. It was checked precisely because a flat result had
already turned out to be a no-op twice this sprint.

### ★★ Why it cannot work: AP was never the scarce resource

```
turn 1 (P0 acts):  ap 30 -> 19    11 spent of 30
turn 3 (P0 acts):  ap 45 -> 39     6 spent of 45   ← carryover cap saturated
```

**The first player already discards AP every turn.** `ap_carryover_cap` is pinned at its
maximum by turn 3. Handing them more is handing them more of something they are throwing away.

★ And the advantage being compensated is **informational, not economic** — the second mover
answers a commitment it can already see. No amount of a non-binding currency addresses that.

> ★ **The same shape as two earlier findings this sprint.** S7-10: "money is not the constraint,
> production rate is." S7-11: cover could not register because the AI cannot use it.
> ⇒ **Before compensating with a resource, check that the resource is actually binding.**

## 3. What would work — three options, all design calls

1. **Change the tiebreak metric.** All ten second-mover wins are unit-count tiebreaks. Deciding
   a capped game on *HQ damage dealt* instead would likely favour the player who pressed first.
   Cheapest change, and it targets what is actually deciding these games.
2. **Compensate in a binding currency.** `production_cooldown_turns` is the measured constraint
   (S7-10) — starting the first player one cooldown tick ahead is denominated in something that
   actually limits them.
3. **Accept it.** A perfectly symmetric deterministic mirror arguably *should* be a draw, and
   the tiebreak is arbitrary by nature. Real matches are never perfectly symmetric — note that
   with any material asymmetry at all (the +1 cell) the seats are exactly 7/7 and material
   converts 14/14.

★ **Recommendation: option 1**, then re-measure. It is the smallest change and it addresses the
mechanism the data actually points at.

## Verification

Suite **1260/1260**, 0 orphans. `first_turn_ap_bonus` ships at **0** — kept rather than deleted
so the idea is not re-tried from scratch, with the negative result recorded beside it.
Raw: `production/qa/evidence/s7-16-first-turn-ap-sweep-raw.txt`.
