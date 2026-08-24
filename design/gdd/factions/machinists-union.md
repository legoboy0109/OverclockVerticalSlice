# Faction — Machinist's Union

> **Status**: **DRAFT** (2026-08-24) — Tier 2 of the faction corpus v2.
> **Name**: ★ TBD. Flavour: mech/vehicle-based industrial collective.
> **Author**: user (direction) + agents · **Baseline**: `factions/democratic-alliance.md` (CR-10)
>
> ★ **Separation from the Galactic Protectorate is a design requirement, not a nicety** (POQ-5).
> Both are vehicle-forward and few-and-strong. The distinction held here: **the Protectorate is
> *bimodal*** — disposable robots screening elite human specialists, cheapest and most expensive
> units in the game with nothing between — **while the Union is *uniform*.** Every Union vehicle is
> excellent, its infantry exist to drive them, and there is no disposable tier at all. See § "Held
> apart from the Protectorate" for the full check.

---

## Overview

The **Machinist's Union** fields the best machines in the game and almost no soldiers. Its infantry
are **crew** — weak, cheap, and built to sit inside something. Its vehicles are the most varied and
most powerful roster in the corpus: five ground platforms and two aircraft, none of them mediocre.

It starts **poor**. Its base income is the lowest of any faction that isn't the Independents, and
its opening turns are spent surviving rather than expanding. What it has instead is the strongest
static defence in the game and an economy that **compounds harder than anyone's** — by the time all
three economy tiers land, the Union is the richest faction on the board.

Its thesis: **outlast the early game, then out-machine everyone.** It is the only faction in the
corpus whose power curve genuinely inverts over a match, and the only one that would rather the game
went long.

★ Its population cap is spent almost entirely on **pilots**. With a ceiling of 8 and every vehicle
requiring a crew, the Union's real constraint is not Credits or slots in isolation — it is that
**every machine it fields costs a body it cannot spare for the line.**

## Player Fantasy

**The feeling: "survive the storm, then roll over them."**

- **★ A curve you can feel.** The early game is anxious and defensive; the late game is a procession.
  No other faction changes character over a match this way, and the moment the curve crosses should
  be legible to both players.
- **Machines with weight.** A Siege Mech is the toughest thing in the game. Committing one is an
  event, losing one is a catastrophe, and it should *feel* slow and enormous rather than merely
  statistically large.
- **Crew as investment, not chaff.** A Union Machinist inside a mech makes it hit harder and move
  further (`crew_bonus`). These are not warm bodies — they are the reason the machine is good.
- **Turtling that is earned, not passive.** The strongest defensive structures in the game exist so
  the Union can *choose* to be slow. Holding the line is the faction playing correctly, not stalling.

**The failure mode to avoid:** an unwinnable early game. A faction that must survive to turn 15 is
only interesting if surviving is *achievable*. If a competent rush simply kills the Union before its
curve arrives, the faction has one matchup and it loses it. The defences and the Guard exist for
exactly this, and it is the first thing to measure.

## Detailed Design

### Roster — Infantry

★ **Three units, and two of them are essentially crew.** *"Relatively weak on their own"* is taken
literally: the Union's infantry lose every straight fight in the game.

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `move` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| ★ **Machinist** | Crew, and the line by default | **300** | 4 | 2 | 1 | 2 | **150** | ★ `can_pilot` ✔ · `crew_bonus: attack +1, move_cost −1` |
| **Foreman** | Keep the machines running | **400** | 4 | 1 | 1 | 2 | **200** | `REPAIR` · `can_pilot` ✔ (no bonus) |
| **Guard** | Hold the early game | **350** | **6** | 3 | 2 | 2 | **200** | `FORTIFY` · `can_pilot` ✘ |

> ### ★★ The Machinist's `crew_bonus` is the faction's central mechanic
>
> `attack +1, move_cost −1`. The second half is the important one and it is unique in the corpus:
> **a crewed Union vehicle moves as if it were a lighter machine.** A Siege Mech at `move_cost` 3
> crews down to 2, which on a 30-AP turn is the difference between four tiles and six.
>
> This is what makes Union vehicles *good* rather than merely *large*, and it is why the faction's
> weak infantry are not a weakness — a Machinist's value is almost entirely realised while it is
> inside something. ★ It also means **an uncrewed Union vehicle is markedly worse than a crewed
> one**, which makes the faction unusually exposed to the Independents' Pirate (see Edge Cases).
>
> **Within TP-5d's bound** of ≤ +1 per stat, applied to two stats. The `move_cost` reduction is
> floored at `MIN_MOVE_COST` 1 like any other movement value.

> **The Guard is the anti-rush answer**, and the only Union infantry that cannot pilot. 6 hp is the
> toughest infantry body outside an Alliance Heavy, and `FORTIFY` takes it to +2 defense while it
> holds. It exists because the faction's whole plan requires reaching turn 15.

### Roster — Ground Vehicles

★ **Five platforms, none of them filler** — the direction's *"varied and powerful"*. All
`requires_pilot = true`, `counts_toward_cap = false` (crew consumes a slot, PC-8),
`resistances {EMF: −2}` (DT-9b default).

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `move` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| **Walker** | Light mech, the workhorse | **1,000** | 18 | 5 | 2 | 2 | **400** | |
| ★ **Siege Mech** | The heaviest thing in the game | **1,800** | ★ **28** | **8** | 2 | 3 *(2 crewed)* | **700** | |
| **Hauler** | Logistics | **1,100** | 18 | — | — | 2 | **400** | `capacity` 4, accepts `{INFANTRY}`. Unarmed |
| **Lancer** | Anti-armour | **1,500** | 22 | 7 | 2 | 2 | **500** | `EMF` |
| **Battery** | Indirect fire | **1,700** | 16 | 8 | **5** | 3 *(2 crewed)* | **600** | `min_range` 2 · `area_shape = BURST` |

> **The Siege Mech at 28 hp is the toughest unit in the corpus** — an Alliance Tank is 22, a
> Protectorate tank 22. Against a 6–8 attack band it takes four to five clean hits. At 1,800 Credits
> and 700 upkeep plus a crew, a Union player fields perhaps two in a whole match, and each one is a
> position the opponent must answer specifically.
>
> ★ **Note the `move_cost` 3 on the Siege Mech and Battery.** This is the corpus rule from
> `factions/solar-federation.md` being used deliberately: *a faction whose identity is few-and-
> powerful has AP to spare, so its units can afford to cost 3 AP a move.* A Union player with three
> vehicles on a 30-AP turn is never AP-constrained — which is exactly why the Union can carry the
> heaviest movement costs in the game at no real cost, and why Solar could not.

### Roster — Air

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `upkeep` | `can_target` |
|---|---|---:|---:|---:|---:|---:|---|
| **Skyworks Gunship** | Ground attack | **1,400** | **9** | 6 | 2 | **500** | `{INFANTRY, GROUND_VEHICLE}` |
| **Skyworks Interceptor** | Air superiority | **1,400** | **9** | 7 | 2 | **500** | ★ `{AIR}` **only** |

★ Both sit at the **top of the air hp band (9)** — Union aircraft are the sturdiest in the game, in
keeping with the faction's identity, and both are crewed like everything else.

### Structures and economy

| Structure | Produces | Max | `cost` | `build_time` | `hp` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| **HQ** | Machinist | 1 | — | — | 40 | **0** | |
| **Barracks** | `{INFANTRY}` | **2** | 600 | 2 | 12 | **100** | +2 cap each |
| ★ **Factory** | `{GROUND_VEHICLE}` | ★ **3** | 1,000 | 3 | **16** | **200** | ★ Most in the game, and the toughest |
| **Airfield** | `{AIR}` | 1 | 1,200 | 3 | 12 | **200** | |
| **Research Lab** | — | 1 | 800 | 2 | 10 | **200** | |
| ★ **Bulwark** *(Defensive Structure)* | — | ★ **4** | **600** | 2 | ★ **14** | **200** | ★ `attack` **5**, `range` 2, `can_counterattack`, `requires_pilot` **false** |

**★ The Bulwark is the strongest defensive structure in the game** — attack 5 and 14 hp against the
Alliance's 4 and 10, four of them allowed, and **crewless**, so it costs no population. It is the
direction's *"good defense options to protect against early game rushes"*, and it is deliberately
the *opposite* pole from Solar's Autonomous Defence Node on the same axis:

| | Solar Node | Union Bulwark |
|---|---:|---:|
| Cost | 300 | **600** |
| Build time | 1 turn | 2 turns |
| `attack` / `hp` | 2 / 8 | ★ **5 / 14** |
| Max | 5 | 4 |
| Anti-air | ✔ | ✘ |

> Cheap-weak-many versus expensive-strong-few, on the identical mechanic. ★ **That is the framework
> working**: one structure type, two factions, genuinely different strategies, zero special cases.

### ★★ Economy — the compounding arc

| | Union | Alliance | Δ |
|---|---:|---:|---|
| `BASE_INCOME` | ★ **700** | 1,000 | ★ **−300** (intercept) |
| Economy tier bonus | ★ **+700** | +500 | ★ **+200** (slope) |
| Tier costs | 1,000 / 2,000 / 3,500 | same | — |
| Income at turn 1 | ★ **700** | 1,000 | **−30%** |
| After Tier I | 1,400 | 1,500 | −7% |
| After Tier II | 2,100 | 2,000 | **+5%** |
| **After Tier III** | ★ **2,800** | 2,500 | ★ **+12%, the highest in the game** |

> ★ **This is the intercept/slope distinction from `faction-identity.md` D4 doing exactly the job it
> was named for.** A low **intercept** makes the Union poor from turn 1; a high **slope** makes each
> economy tier worth more to them than to anyone else. The result is a curve that *crosses* the
> baseline around Tier II — a genuine arc rather than a flat modifier.
>
> ★★ **A flat income delta could not produce this at any value**, which is precisely the shape fact
> the framework flagged when the two levers were split. **The Union is the corpus's proof that the
> distinction was worth naming.**
>
> **The strategic consequence:** the Union wants to reach Tier III and the opponent wants to kill it
> before then. Its Research Lab is worth more to it than to anyone else, and is correspondingly the
> best thing to attack.

| | Union | Alliance |
|---|---:|---:|
| `base_infantry_cap` | **4** | 4 |
| `max_barracks` | **2** | 3 |
| **Infantry ceiling** | ★ **8** | 10 |

★ **Eight bodies, and most of them are inside machines.** Three crewed vehicles plus a Foreman
leaves four slots. The Union's line is thin by construction.

## ★ Held apart from the Protectorate

POQ-5 required this check. Both factions are vehicle-forward and field ~5 board entities.

| | Galactic Protectorate | Machinist's Union |
|---|---|---|
| **Shape** | ★ **Bimodal** — 200-Credit robots and 700-Credit specialists, nothing between | ★ **Uniform** — every vehicle 1,000–1,800, no disposable tier at all |
| Infantry role | Elite specialists who *decide fights* | Crew who *enable machines* |
| Disposable units | ★ yes (Servitors) | ★ **none** |
| Cap exemption | ★ yes (robots) | no |
| Economy | flat baseline | ★ **compounding arc** |
| Power curve | flat | ★ **inverts over the match** |
| Weakness | ★ universal EMF vulnerability | ★ the early game |
| Vehicles need crew | until autonomy tech | ★ **always** |
| Answer to being outnumbered | field more robots | ★ Bulwarks and better machines |

**Verdict: genuinely distinct.** They share "vehicles are good" and nothing else. The Protectorate
can always put a body on the board and is bounded by upkeep; the Union cannot and is bounded by
time. ★ The clearest test: **the Protectorate never loses to a rush** (it can always buy Servitors);
**the Union nearly does** — and that is its defining vulnerability.

## Formulas

No new formulas. `FactionDef` deltas:

```
Δ_base_income      = −300        ★ intercept: poor early
Δ_econ_tier_bonus  = +200        ★ slope: compounds late — the arc
Δ_max_barracks     = −1          (ceiling 8)
Δ_max_factories    = +1          (3)
Δ_max_defensive    = +1          (4)
Δ_upkeep_rate      =  0
```

### CR-10 comparison sheet — Union vs the Democratic Alliance

*Two columns, because a single row would hide the faction. Early = turn ~1–8, no economy tech. Late
= full research. Realistic build (2 Barracks, 2 Factory, 1 Lab = 800 upkeep).*

| Axis | Alliance | Union **early** | Union **late** | Winner |
|---|---:|---:|---:|---|
| Income | 1,000 → 2,500 | ★ **700** | ★ **2,800** | **split** |
| Credits for army | 1,900 | ~300 | **2,000** | **split** |
| **Sustainable board units** | ~9 | ★ **~2** | ~3 vehicles + crew | **Alliance on count** |
| Toughest single unit | Tank 22 hp | Walker 18 | ★ **Siege Mech 28** | ★ **Union** |
| Peak attack | Artillery 8 | 5 | Siege 8 / Battery 8 | tie |
| Line infantry quality | 3 atk / 6 hp | ★ 2 atk / 4 hp | same | ★ **Alliance, decisively** |
| Static defence | 4 atk / 10 hp ×3, manned | ★ **5 atk / 14 hp ×4, crewless** | same | ★ **Union, decisively** |
| Vehicle variety | 3 | ★ **5** | ★ **5** | **Union** |
| Air durability | 6–9 hp | ★ 9 hp | 9 hp | **Union** |
| **Vulnerability to a rush** | low | ★★ **high** | low | ★ **Alliance, decisively** |
| Vulnerability to crew-killing | moderate | ★★ **highest in the corpus** | same | ★ **Alliance** |
| Anti-armour | Tank 7 | Lancer 7 **EMF (effective 9)** | same | **Union** |

**Verdict against CR-10.2: PASS.** The Union loses the early game, the infantry comparison, and both
vulnerability axes decisively; it wins durability, variety, static defence and the late economy. ★
**It cannot win the comparison at any single moment in time** — early it is behind on almost
everything, late it is ahead on machines but still fields the fewest bodies.

> ⚠ **The axis that cannot be settled on paper: whether the early game is survivable.** Every other
> row is a number. This one is a question about whether an opponent who understands the matchup can
> simply end it before turn 12. **This is the Union's equivalent of the Independents' variance
> problem** and it must be measured, not argued.

## Edge Cases

- **★ Union vehicle crew killed by an Independents Pirate:** the vehicle loses `attack +1` and `move_cost −1` *and* becomes inert — a Union machine degrades further on losing its crew than anyone else's, because more of its value lives in the crew. ★ **The Union is the Pirate's best target in the game.**
- **Union at cap with vehicles wanting crew:** it must disband, lose infantry, or leave a machine idle. A frequent and deliberate squeeze.
- **A Siege Mech with no crew:** 28 hp of immobile obstacle. Still blocks, still absorbs, still a prize.
- **Guard cannot pilot:** deliberate. Building Guards trades future vehicle capacity for present survival — the faction's core early decision.
- **Bulwark against an early rush:** crewless, so it costs no cap at exactly the moment the Union has no bodies to spare. ★ This is the design intent, not an accident.
- **Union that never reaches Tier II:** strictly worse than the baseline in every respect. Its whole design is a bet on time.
- **Research Lab destroyed pre-Tier-III:** ★ costs the Union more than any other faction — its slope means each tier is worth 700 rather than 500. The best single attack available against them.
- **Hauler carrying 4 Machinists, destroyed:** four crew die at once (TP-4), potentially stranding every vehicle on the board. ★ The most punishing transport loss in the corpus.
- **Foreman repairing a Siege Mech:** 4 hp of a 28 hp body — proportionally weak. ★ `REPAIR_AMOUNT` was tuned against infantry; against the Union's machines it may be nearly pointless (MUOQ-4).
- **Union mirror:** two slow economies and two sets of Bulwarks. ★ Likely the slowest matchup in the game and a real risk of hitting the round cap — worth measuring against the PIVOT's terminating-condition problem specifically.

## Dependencies

| System | What this faction needs | Wave |
|---|---|---|
| **Unit Upkeep** (#15) | High vehicle upkeep is its main limiter | Sprint 6 |
| **Population Cap** (#16) | Ceiling 8, and PC-8's crew-consumes-a-slot rule | Wave 1 |
| **Research** (#8 rev) | ★ The slope lever — its whole identity | Wave 1 |
| **Unit Classes** (#17) | ★★ **Hard blocker** — it is a vehicle faction | Wave 2 |
| **Transport & Pilots** (#20) | ★★ **Hard blocker** — `crew_bonus`, `requires_pilot` on everything | Wave 2 |
| **Unit Abilities** (#19) | `REPAIR`, `FORTIFY`, `EMBARK`/`DISEMBARK` | Wave 2 |
| **Damage Types** (#18) | `EMF` on the Lancer, `BURST` on the Battery | Wave 3 |
| **Promotion** (#21) | none | — |

★ **No meaningful wave-1 form.** Strip vehicles and the Union is three weak infantry and a good
turret. Wave 2 at the earliest, wave 3 to be complete.

## Tuning Knobs

| Knob | Default | Guidance |
|---|---|---|
| ★ `Δ_base_income` | **−300** | ★★ **The survivability dial.** It sets how bad the early game is. If the Union proves unable to reach its curve, raise this *before* touching the slope — the arc is the identity, the poverty is just its price |
| ★ `Δ_econ_tier_bonus` | **+700 total** | The other half of the arc. Raising it makes the late game more dominant and the crossover later |
| Machinist `crew_bonus` | attack +1, `move_cost` −1 | ★ The faction's central mechanic. Removing the movement half makes every Union vehicle feel like a brick |
| Siege Mech `hp` | **28** | Toughest in the game. Above ~32 it stops being answerable by massed infantry |
| Bulwark `attack` / `max` | 5 / 4 | ★ The anti-rush guarantee. Weaken it only if the Union proves too hard to pressure early |
| Guard `hp` | 6 | The early-game body. It is the difference between surviving a rush and not |
| Infantry ceiling | 8 | Every point is a vehicle that can or cannot be crewed |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN the Union at turn 1 with no research, THEN `credit_income` is exactly **700** | Logic |
| AC-2 | GIVEN the Union at full research, THEN `credit_income` is exactly **2,800** | Logic |
| AC-3 | GIVEN Union and Alliance both at Economy Tier II, THEN the Union's income (2,100) exceeds the Alliance's (2,000) — the crossover holds | Logic |
| AC-4 | GIVEN a Machinist crewing a Siege Mech, THEN the mech's `effective_attack` is 9 and its `effective_move_cost` is 2 | Logic |
| AC-5 | GIVEN that Machinist dies or disembarks, THEN attack returns to 8, `move_cost` to 3, and the mech becomes inert | Integration |
| AC-6 | GIVEN a Foreman crewing a vehicle, THEN no `crew_bonus` applies | Logic |
| AC-7 | GIVEN a Union Guard, THEN `EMBARK` into a `requires_pilot` vehicle is rejected | Integration |
| AC-8 | GIVEN a full Union build-out, THEN `effective_cap` is exactly **8** | Logic |
| AC-9 | GIVEN a Union Bulwark with no crew, THEN it fires at attack 5 | Integration |
| AC-10 | GIVEN a 5th Bulwark order, THEN it is rejected naming `max_defensive` | Integration |
| AC-11 | GIVEN a 4th Factory order, THEN it is rejected naming `max_factories` | Integration |
| AC-12 | GIVEN a Hauler carrying 4 Machinists is destroyed, THEN all 4 die and 4 cap slots free | Integration |
| AC-13 | GIVEN a Battery and an adjacent enemy, THEN the attack is rejected (`min_range` 2) | Logic |
| AC-14 | GIVEN `crew_bonus` reducing `move_cost` below `MIN_MOVE_COST`, THEN it floors at 1 | Logic |
| AC-15 | ★ GIVEN an Alliance-vs-Union AI batch, THEN neither wins more than **65%** across both seats | Integration |
| AC-16 | ★★ GIVEN an Alliance-vs-Union batch where the Alliance pressures early, THEN the Union wins at least **30%** (the early game must be survivable) | Integration |
| AC-17 | ★ GIVEN a Union-vs-Union mirror batch, THEN matches resolve on HQ destruction rather than the round cap (the slowest matchup must still terminate) | Integration |

## Open Questions

| # | Question | Owner |
|---|---|---|
| MUOQ-1 | ★★ **Is the early game survivable?** The one axis the comparison sheet cannot settle. A faction that must reach turn 15 is only interesting if reaching it is achievable against an opponent actively preventing it. **Measure with AC-16 before tuning anything else here** | game-designer + systems-designer |
| MUOQ-2 | ★★ **Does the Union mirror ever end?** Two compounding economies, eight Bulwarks and six heavy machines is the corpus's most likely candidate for a match that reaches the round cap — the exact failure the PIVOT verdict was about. AC-17 exists for this | economy-designer |
| MUOQ-3 | ★ **Is the Union too exposed to the Pirate?** More of its unit value lives in crew than any other faction's, so crew-killing hurts it most. That is thematically right and may be mechanically excessive — a single Independents specialist that reliably neuters 1,800-Credit machines | systems-designer |
| MUOQ-4 | **`REPAIR_AMOUNT` is wrong for this faction.** 4 hp against a 28-hp Siege Mech is 14%; against a 4-hp Machinist it is a full heal. A flat heal does not scale, and the Foreman exists to keep machines running. Options: a percentage heal (breaks the corpus's additive discipline), a larger vehicle-specific ability, or accept that the Foreman is for infantry | systems-designer |
| MUOQ-5 | **Should the Union have a disposable unit at all?** Currently none, deliberately, to hold it apart from the Protectorate. The cost is that a Union player who loses their crew has no cheap way to recover. ★ Recommend keeping the hole — it is what makes the faction distinct | user |
| MUOQ-6 | **The name.** *"Machinist's Union"* is the most mechanically honest name in the set — it says both what they field and how they are organised. ★ Recommend keeping it. **Naming call — the user's** | user |
