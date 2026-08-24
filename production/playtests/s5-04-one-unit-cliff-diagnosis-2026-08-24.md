# The One-Unit Cliff — diagnosis

> **Follows**: `s5-04-swing-back-2026-08-24.md` §3
> **Tool**: `tools/DiagnoseCliff.tscn` · **Trace**: `production/qa/evidence/s5-04-cliff-trace.txt`
> **Date**: 2026-08-24
> **Status**: ✅ **Root cause found and FIXED (option A, S6-16).** The latch is gone; the cliff is
> narrower but not eliminated — see the outcome section at the end.

---

## The question

S5-04 measured a cliff with no gradient:

| Starting advantage | Lead changes per game |
|---|---:|
| None (mirror) | **6.75** |
| **One Trooper** | **0.00** |
| Two | 0.00 |
| Three | 0.00 |

A single extra unit takes the game from "changes hands seven times" to "never changes hands." The
obvious explanations — deterministic combat compounding, attrition snowball, Lanchester's square law
— are all plausible and **all wrong**.

## What actually happens

Tracing a +1 game first showed the advantage *compounding*: the unit gap runs 1 → 2 → 3 → 4 by turn
15, then plateaus. But the flow figures do not describe a fight:

```
favoured   produced 3   lost 0   net +3
underdog   produced 2   lost 2   net  0
```

**The favoured side never loses a single unit.** And the underdog stops producing entirely while its
Credits climb past 6,500 on an empty board. That is not attrition. Something is stopping it from
spending.

### The trace

`tools/DiagnoseCliff.tscn` replays the match and breaks the underdog's produce eligibility into its
individual gates every turn, including who is standing on the HQ's four spawn tiles:

```
turn | u:units cred    AP  def | can_field | deploy | validate_produce             | ring
   2 | u:0    1000    30    no | YES       |      3 | OK                           | free/free/free/ENEMY
   8 | u:0    1400    45    no | YES       |      2 | OK                           | free/ENEMY/free/ENEMY
  12 | u:0    1400    45    no | YES       |      1 | REJECT PRODUCER_ON_COOLDOWN  | ENEMY/ENEMY/free/ENEMY
  14 | u:0    1500    45    no | YES       |      0 | REJECT NOT_LEGAL_DEPLOY_TILE | ENEMY/ENEMY/ENEMY/ENEMY
  20 | u:0    4500    45    no | YES       |      0 | REJECT NOT_LEGAL_DEPLOY_TILE | ENEMY/ENEMY/ENEMY/ENEMY
  24 | u:0    6500    45    no | YES       |      0 | REJECT NOT_LEGAL_DEPLOY_TILE | ENEMY/ENEMY/ENEMY/ENEMY
```

Every other gate is green the whole way down. Credits: plenty. AP: full. Deficit: no. Population
headroom: yes. **The only thing wrong is that there is nowhere to put the unit.**

## Root cause — one rule

`BaseProduction.legal_deploy_tiles` returns the producer's **four orthogonal neighbours**, filtered
by `is_passable`, which is false for *any* occupied tile:

```gdscript
for n: Vector2i in _neighbors_in_fixed_order(producer.position):
    if grid.in_bounds(n.x, n.y) and grid.is_passable(n.x, n.y):
        out.append(n)
```

**A producer has at most four spawn tiles, and four enemy units standing on them end that player's
game permanently.** No amount of economy, tempo or skill recovers from it, because production is the
only route back onto the board and it is closed.

### Why this makes the cliff exactly one unit wide

The chain is mechanical, and every link is forced:

| | |
|---|---|
| 1 | **Any** advantage wins the first skirmish — it needn't be large, only non-zero |
| 2 | The winner's surviving units advance on the loser's HQ |
| 3 | Four of them occupy the spawn ring |
| 4 | The loser can never produce again |
| 5 | The loser's remaining units die; the HQ follows |

Step 1 is why one Trooper is enough. Nothing in steps 2–5 scales with the *size* of the advantage —
they only require winning the opening exchange. **That is the cliff: not a snowball, a latch.**

## Why this was invisible until now

- Until S6-06 the AI never pushed toward the enemy HQ, so nothing ever camped a spawn ring. **The
  fix that made matches resolve is what exposed this.**
- The GDD does consider permanent lockout, but in a different context: `base-production.md`'s
  `PROD_OUTPOST_BUILD_TIME` knob warns that *"'permanently locked out of roster' feels unfair if
  sniped"* — about losing your Barracks, not about your HQ being surrounded.
- Nothing in any GDD anticipates spawn-camping. It is an unforeseen interaction between the deploy
  rule and an AI that now advances.

## ★ This is not a balance problem

Retuning costs, upkeep or unit stats will not touch it. Whatever the numbers, four units on four
tiles closes production. The fix has to change the deploy **rule**, and that is a design decision.

---

## Options

Listed with real trade-offs. Each is a different answer to *"what does a player who is losing the
board still get to do?"*

### A — Widen the deploy ring (radius 2)
Deploy to any free passable tile within 2 tiles of the producer: **up to 12 tiles instead of 4.**

- **For**: smallest change (one function), no new concepts, no new player-facing rules, and it makes
  a lock require ~12 units instead of 4 — practically impossible under a population cap of 10.
- **Against**: units can appear two tiles from the HQ, which is a small reach increase for the
  defender. Reinforcements arrive slightly further forward than the fiction implies.
- **Note**: leaves camping *possible* in principle, just not achievable. That may be the right
  shape — surrounding a base should be strong, not instantly terminal.

### B — Guaranteed deploy with displacement
The HQ can always produce; deploying onto an occupied tile shoves the occupant back one tile.

- **For**: makes an HQ genuinely unsiegeable, which is a strong, readable promise.
- **Against**: introduces forced movement, which nothing else in the game has. It interacts with
  cover, zones of control and future abilities, and every one of those interactions needs designing.
  Largest blast radius of the three.

### C — Enemies cannot end their turn adjacent to an enemy HQ
A no-camp zone around the HQ.

- **For**: directly forbids the exact behaviour.
- **Against**: an invisible rule that stops a legal-looking move, which Pillar 3 dislikes. It also
  makes an HQ *harder* to attack, which fights the win condition — you must destroy the HQ, but you
  may not stand next to it.

### D — Accept it as a legitimate siege tactic
Do nothing to the rule; treat spawn-locking as skilled play.

- **For**: it is a real tactic, and the design already rejects comeback mechanics.
- **Against**: the measurement says it converts a **one-unit** edge into a guaranteed win with no
  counterplay, and it is executed by an AI that is not trying to do it. It is not a tactic anyone has
  to earn.

---

## Recommendation

**Option A.** It is the smallest change that removes the latch, it needs no new player-facing
concept, and it preserves the design's stance that an advantage should hold. It does not manufacture
a comeback mechanic — the leader still wins — it just stops one unit of advantage from being
*terminal by rule* rather than by play.

**★ This is a design-direction call, not a technical one, so it is yours.** Whichever way it goes,
re-run `tools/SimulateMatches.tscn` and `tools/analyse_swing.py` afterwards: if the +1 cell starts
showing lead changes above zero, the latch is gone. That is the measurable test for the fix.


---

## ✅ Outcome — option A implemented, 2026-08-24 (S6-16)

`BaseProductionConfig.deploy_radius = 2`; `legal_deploy_tiles` scans a manhattan radius instead of
the four cardinal neighbours. Up to 12 candidate tiles, so a lock would need more units than
`cap_hard_ceiling` permits.

**The latch is gone.** Re-running the same trace, with all four inner-ring tiles enemy-occupied from
turn 22, the underdog still has 8 deploy tiles and keeps producing:

```
turn 22 | deploy 8 | ... | ring ENEMY/ENEMY/ENEMY/ENEMY
turn 26 | deploy 8 | OK  | ring ENEMY/ENEMY/ENEMY/ENEMY
turn 28 | u:1      |     | ring ENEMY/ENEMY/ENEMY/ENEMY   ← back on the board
```

### Measured effect (+1 handicap cell, 6 games)

| | Before | After |
|---|---:|---:|
| Losing player has units on the board | 10.3 % of turns | **23.1 %** |
| Units the losing player produced | 18 | **33** |
| Dead banked Credits (peak) | 7,500 | **3,200** |
| Mean game length | 29.2 turns | 32.5 turns |
| Peak banked Credits, whole batch | 9,400 | **3,500** |

The S6-06 gate is unaffected: 18/22 resolve by HQ destruction, 18/18 material advantage converts,
both seats win.

### ⚠️ What it did NOT fix — stated plainly

**The +1 cell still shows zero lead changes.** I named that as the measurable test for this fix, and
it did not move.

The honest reading: **the latch and the cliff were not the same thing.** The latch was a defect — a
player unable to act at all while holding 6,500 Credits, with no counterplay at any price. That is
fixed, and the losing player's ability to participate roughly doubled. But being *able* to play is
not the same as being able to *come back*, and one Trooper of advantage still converts every time.

That residue is arguably the design working as intended — `game-concept.md` rejects comeback
mechanics explicitly, and S5-04's requirement 1 (no decided game reverses) is *supposed* to pass.
Whether a **skill** route back from one unit down should exist is a live design question, and it is
now separable from the bug that was masking it.
