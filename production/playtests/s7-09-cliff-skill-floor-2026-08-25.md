# The One-Unit Cliff — is there a skill route back?

> **Follows**: `s5-04-one-unit-cliff-diagnosis-2026-08-24.md` (the latch, fixed in S6-16)
> **Date**: 2026-08-25 · **Story**: S7-09
> **Tool**: `tools/SimulateMatches.tscn --degrade-favoured=N --only-handicap=1 --variants=7`
> **Analysis**: `tools/analyse_swing.py`
> **Status**: ✅ **ANSWERED — a skill route back exists.** The "no recoverable middle"
> conclusion was an artifact of the measurement, not a property of the game.

---

## The question, and why the old answer was not an answer

S5-04 measured the +1 handicap cell at **zero lead changes** and read it as *the game has no
recoverable middle*. S6-16 fixed the deploy-tile latch underneath it, the losing player's
participation roughly doubled — and the zero did not move. That residue became the project's
biggest open design question: **should there be a skill route back from one unit down?**

★★ **But look at what the harness does.** `simulate_matches.gd` drives *both seats* with the
same `AI.choose_action`, the same weights, fully deterministically:

```gdscript
func _run_one_turn(state: GameState) -> void:
    ...
    var action: Action = AI.choose_action(state, economy_investments)
```

**There is no skill differential anywhere in it.** Neither side can play better or worse than
the other, because they are the same function.

> ⇒ **Equal play from a worse position losing every single time is arithmetic, not a design
> property.** A comeback requires the trailing player to *outplay* the leader, and the harness
> could not express that. **It was being asked a question it structurally could not answer**,
> and it returned a confident zero.

## Method

A play-strength dial was added to the harness, **applied to the favoured side only**:

> With probability `p` per turn, the favoured side commits **at most one action** that turn
> instead of playing its turn out.

That models *played a worse turn*, not *did not show up* — the leader still acts, never does
anything illegal, and never deliberately self-harms. Monotone in `p`.

- **Deterministic draw**, `hash(game, turn) % 100` — never `randi()`. ADR-0003 forbids unseeded
  RNG near a reproducible measurement, and a sweep whose rows cannot be re-derived is not
  evidence.
- **`p = 0` is byte-identical to the shipped batch.** Verified by `diff` against a pre-change
  run, so the S6-06 gate numbers stay comparable.
- Variant offsets became a table so the cell could be widened from n=6 to **n=14** without
  walking bonus units off the map. The first three entries reproduce the old arithmetic exactly.

★ **The first pass ran at n=6 and showed a non-monotone dip** that looked like a real threshold
effect. It was sample noise. n was raised before any conclusion was drawn — the dip shrank but
has not entirely gone (see 25% below), which is the honest read on how much precision 14 games buys.

## Result

Handicap **+1 Trooper**, 14 games per row.

| Leader degraded | Games with a lead change | Mean lead changes | Mean window of doubt | Games in doubt past halfway | **Underdog wins** |
|---:|---:|---:|---:|---:|---:|
| **0 %** | **0 / 14** | 0.00 | **3 %** | 0 / 14 | **0 / 14** |
| 5 % | 1 / 14 | 0.14 | 3 % | 0 / 14 | 0 / 14 |
| 10 % | 2 / 14 | 0.36 | 8 % | 1 / 14 | 1 / 14 |
| 15 % | 4 / 14 | 0.79 | 22 % | 3 / 14 | 1 / 14 |
| 20 % | 4 / 14 | 0.50 | 22 % | 3 / 14 | 1 / 14 |
| 25 % | 2 / 14 | 0.29 | 7 % | 1 / 14 | 0 / 14 |
| 30 % | 5 / 14 | 0.86 | 27 % | 4 / 14 | 1 / 14 |
| 35 % | 8 / 14 | 1.21 | 40 % | 6 / 14 | **4 / 14** |
| 40 % | 9 / 14 | 1.50 | 42 % | 6 / 14 | 2 / 14 |
| **50 %** | **12 / 14** | **3.79** | **66 %** | 10 / 14 | **6 / 14** |

## What this says

**1. ✅ A skill route back exists, and the cliff is not a rule.** At equal play the +1 advantage
converts every time; at *any* play gap it stops being certain. A single lead change appears at
5 %, and by 50 % the underdog wins 6 of 14 and most games are still in doubt past halfway.
**Nothing in the rules forbids a comeback — the old harness simply had no way to attempt one.**

**2. ⇒ No comeback mechanic is needed, and adding one would be a mistake.** `game-concept.md`
rejects rubber-banding explicitly, twice. That stance is not costing the game its drama; the
drama was there and unmeasurable. ★ **The correct fix for "the measurement says no recoverable
middle" turned out to be fixing the measurement.**

**3. The exchange rate is the thing actually worth a design opinion.** One Trooper is worth
roughly **30–35 % of decision quality** before the underdog wins about a third of the time.
Whether one unit of material *should* be that expensive to overcome is a tuning question — and
it is a live one, not settled by this document.

**4. S5-04's requirement 1 still passes, and passes more meaningfully.** "No decided game
reverses" held at 0 % because nothing was ever undecided. It now holds against games that
genuinely *are* in doubt, which is what the requirement was trying to assert.

## ⚠ What this does NOT establish

- **A one-action cap is a proxy for skill, not skill.** It makes a player *do less*, where a
  weaker human does the *wrong thing*. The two are not the same, and the second is likely worse.
- **n = 14 per row.** The 25 % dip is still visible; the ends of the sweep are trustworthy, the
  middle is directional.
- **Both sides remain the same greedy one-ply scorer.** A human differs from this AI *in kind*,
  not merely in quality. The sweep proves the game is **sensitive to play quality** — the thing
  that was genuinely in doubt — and does not quantify what a human would actually convert.
- **This does not replace S5-04's Analyses A/C/D.** Whether the swing *feels* alive to a person
  is still unmeasured, and remains the honest gap.

## ★ The transferable lesson

**Check that the instrument can express the answer before trusting the reading.** The zero was
real, reproducible, and correctly computed. It was also meaningless: a harness where both sides
share one deterministic policy cannot produce a comeback, so measuring "no comebacks" in it
confirms the setup, not the game. The finding sat as the project's top design question for two
days on the strength of a number that could only ever have been zero.

⇒ **The same question should be asked of the S6-06 gate**, which runs on the identical
same-AI-both-seats harness. Its four conditions are about *resolution*, not about relative skill,
so they are not obviously compromised — but "the material-advantaged side wins more often than
not" reads differently once you know the two sides play identically. **18/18 conversion is what a
symmetric-policy harness must produce; it is not evidence that the advantage is correctly sized.**
