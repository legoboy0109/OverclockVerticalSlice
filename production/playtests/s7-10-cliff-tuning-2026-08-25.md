# Making a one-unit lead less punishing — five levers, one that worked

> **Follows**: `s7-09-cliff-skill-floor-2026-08-25.md` (a skill route back exists; the exchange
> rate is the live question)
> **Date**: 2026-08-25 · **Story**: S7-10
> **Tool**: `tools/SimulateMatches.tscn --degrade-favoured=N --only-handicap=1 --variants=7`
> **Brief**: *"adjust it to make it slightly less punishing, then run another batch"*

---

## The target

S7-09 measured the exchange rate: **one Trooper of material ≈ 30–35 % of decision quality**
before the trailing player starts winning a meaningful share. The brief was to reduce that
without touching the thing the design deliberately protects — *no decided game reverses* — and
without breaking the S6-06 resolution gate.

**The 0 % row is the one that must not move.** If equal play from behind starts producing
comebacks, that is a rubber band, and `game-concept.md` rejects those twice.

## What was tried

| # | Lever | Result |
|---|---|---|
| 1 | **Trooper HP 6 → 7** (removes the Sniper's one-shot) | ⛔ **Worse.** Underdog wins fell 6/14 → 1/14 at 50 % |
| 2 | **Trooper HP 6 → 5** (adds a Heavy one-shot) | ◐ **Inert.** Identical to shipped at 0/5/10 % |
| 3 | **Cover on the map**, 12 % and 20 % density | ◐ **Completely inert.** Byte-identical rows |
| 4 | **Unit counterattacks enabled** | ⛔ **Neutral to worse.** 2 % doubt vs 3 % shipped |
| 5 | ✅ **HQ production cooldown 3 → 2** | ✅ **Worked.** See below |

### ★★ Why the first four failed, and it is one reason

**Every symmetric combat change is applied more times by the side with more units.** Tougher
units, more lethal units, cover, counterattacks — each is a rule both players use, so each is
worth more to whoever has more bodies to use it with. Lever 1 is the clearest case: making units
harder to kill *lengthens* engagements, and a longer engagement lets a numerical advantage
compound further (Lanchester's square law is not a metaphor here — it is what the batch measured).

> ⇒ **You cannot damp a numerical advantage with a rule that scales with unit count.**

### ★ Lever 3 failed for a second, separate reason worth its own line

**The AI has no terrain awareness at all** — `ai.gd` never calls `is_cover`, and nothing in its
scoring references terrain. It stands on cover only by accident. So cover cannot register in any
AI-vs-AI measurement, whatever the density.

⚠ And the finding underneath that one: **cover has never been used by anything.** Both this
harness and `VerticalSliceRoot._build_match` fill their maps with `Terrain.PLAIN`. A `cover_dr`
constant, `GridState.is_cover`, and shipped `tile_cover` art all exist, and **no map in the
project places a single cover tile.** The game's whole positional dimension is built and switched
off — which is also why "unit count dominates" is true almost by construction.

## What actually worked: army size, not combat

The diagnosis came from looking at the board rather than the rules:

```
mean units on board, both sides combined : 3.22      (≈1.6 per player)
peak units on board, mean across games   : 5.0
peak banked Credits                      : 3,200     (income 1,000–2,500/turn)
```

★ **Armies average about 1.6 units per side.** At that size **one extra Trooper is a ~60 % force
advantage**, and no combat-math tweak can make a 60 % advantage anything other than decisive.
Money is not the constraint — both sides bank a surplus. **Production *rate* is**, and that is the
HQ's `production_cooldown_turns`.

⚠ **Which is precisely the lever that fixed the S6-06 gate.** S6-07's per-producer cooldown was
one of the two changes that made matches resolve at all. Softening it trades directly against the
sprint that earned resolution — so this was measured against **both** metrics, not just the one
the brief asked about.

## Result — HQ cooldown 3 → 2 (+1 handicap, n=14 per row)

**Underdog wins**, which is the metric that matters most — the others move with it:

| Leader degraded | Shipped (cd 3) | Tuned (cd 2) |
|---:|---:|---:|
| **0 %** | **0 / 14** | **0 / 14** |
| 5 % | 0 / 14 | 1 / 14 |
| 10 % | 1 / 14 | 3 / 14 |
| 15 % | 1 / 14 | **6 / 14** |
| 20 % | 1 / 14 | 5 / 14 |
| 25 % | 0 / 14 | 6 / 14 |
| 30 % | 1 / 14 | 9 / 14 |
| 35 % | 4 / 14 | 8 / 14 |
| 40 % | 2 / 14 | 9 / 14 |
| 50 % | **6 / 14** | 11 / 14 |

Games with at least one lead change, and mean window of doubt, move the same way:

| Leader degraded | Lead changes, shipped → tuned | Doubt, shipped → tuned |
|---:|---:|---:|
| 0 % | 0/14 → **0/14** | 3 % → **3 %** |
| 10 % | 2/14 → 7/14 | 8 % → 39 % |
| 15 % | 4/14 → 8/14 | 22 % → 51 % |
| 30 % | 5/14 → 9/14 | 27 % → 50 % |
| 50 % | 12/14 → 14/14 | 66 % → 62 % |

★ **The exchange rate falls from roughly 50 % to roughly 15 %.** Shipped needs a 50 % play
advantage to give the trailing player 6 wins in 14; tuned reaches the same at **15 %** — about a
**3.3× reduction** in how much better you have to play to overturn one unit of material.

★★ **And the 0 % row does not move at all** — 0/14 lead changes, 3 % doubt, 0 wins, identical to
shipped. Equal play from one unit down still converts every single time.

> ⇒ **This is a skill amplifier, not a rubber band**, which is exactly the distinction
> `game-concept.md` cares about. S5-04's requirement 1 — *no decided game reverses* — is
> preserved by construction: nothing was given to the losing player, the leader simply stopped
> being able to out-produce a mistake.

⚠ **It is arguably more than "slightly".** 3.3× is a large move, and because the cooldown is an
integer, **3 → 2 is the smallest step this lever has.** There is no gentler version of it. If
that overshoots, the next-smallest adjustments are on a different lever (Barracks cooldown, or
`cap_per_barracks`), not this one.

## ✅ The trade, measured — the S6-06 gate holds, and marginally improves

The whole risk of this lever is that faster reinforcement undoes the sprint that earned
resolution. It does not:

| Gate condition | Shipped (cd 3) | Tuned (cd 2) | |
|---|---:|---:|:--|
| Resolve on play, not the round cap | 18/22 | **19/22** | ✅ better |
| Material advantage converts | 18/18 | **18/18** | ✅ unchanged |
| Not seat-determined | P0 10 / P1 12 | **P0 9 / P1 13** | ✅ both seats |
| Mean turns (resolved games) | 28.9 | **34.3** | ⚠ ~19 % longer |

★ One mirror game that previously ran to the 60-turn cap now resolves at turn 54 — with more
units on the board, a dead-even deterministic match is likelier to break than to stall.

> ### ⚠ The headroom cost, which is the real thing to watch
> The +1 handicap games moved from **31–34 turns to 30–47 turns** against a 60-turn round cap.
> Headroom fell from ~26 turns to ~13. **A further softening of this lever would start pushing
> +1 games into round-cap territory**, at which point "resolve on play" begins to erode. This is
> the step that fits; the next one probably does not.

Full suite green after the change: **1236/1236, 107 suites, 0 orphans.**

## ⚠ Honest limits

- **The same caveats as S7-09 apply**: a one-action cap is a proxy for skill, not skill; n=14, so
  the middle of the sweep is directional; both sides remain the same greedy one-ply scorer.
- **Longer games.** Bigger armies mean longer engagements — the sweep took several times as long
  to run, which is a direct read on match length. That is the cost side of the trade.
- **Nothing here was tested by a human.** The exchange rate is measured between two identical
  AIs. What a person converts is still unknown, and `S5-04`'s Analyses A/C/D remain the gap.
