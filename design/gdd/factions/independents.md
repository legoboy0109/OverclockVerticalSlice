# Faction — Independents

> **Status**: **DRAFT** (2026-08-24) — Tier 2 of the faction corpus v2.
> **Name**: ★ TBD. Flavour: Revolutionary Rebels.
> **Author**: user (direction) + agents · **Baseline**: `factions/democratic-alliance.md` (CR-10)
>
> ★★ **The only faction whose power scales with the *opponent's* investment.** Everything else in
> the corpus is bounded by what a player builds; the Independents are partly bounded by what their
> enemy builds, which is a shape that reliably goes degenerate if it is not watched. It is also, by
> some distance, the most distinctive fantasy in the set.

---

## Overview

The **Independents** are poor, few, and very good at their jobs. The smallest economy in the game,
the tightest population ceiling, the worst vehicles, a single scavenged aircraft — and an infantry roster made **entirely of
specialists**, each of which does something no line unit can.

Their signature is the **Pirate**, who does not fight vehicles so much as *acquire* them: shoot the
crew out of an enemy tank, climb in, drive away. The Independents' armour strategy is not to build
armour. It is to take yours.

This makes them the only faction that must be played **opportunistically**. They cannot out-produce
anyone, cannot out-earn anyone, and cannot win a straight exchange of equal armies. What they can do
is convert the enemy's mistakes into their own material — and against a careless opponent, that
compounds faster than any economy in the game.

## Player Fantasy

**The feeling: "we don't have one of those. We'll take yours."**

- **★ Theft as the core loop.** No other faction has a unit whose best turn is spent *not fighting*.
  Spotting an unattended tank, killing its driver and stealing it should be the highlight of a
  match — and it is a three-step plan the player assembles themselves.
- **Poverty that sharpens.** With the worst economy and the tightest cap, every Independent unit is
  a decision. Nothing is spare, nothing is expendable, and losing a specialist genuinely hurts.
- **Asymmetric respect.** An opponent facing the Independents has to *change how they play* — park
  vehicles carefully, keep crews alive, never leave armour unattended. ★ That behavioural pressure
  is the faction's real weapon, and it works even on turns the Pirate does nothing.
- **The underdog arc.** Starting behind and ending the match driving the enemy's best vehicle is
  the fantasy in one sentence.

**The failure mode to avoid:** the Pirate being either irrelevant (nobody ever leaves a vehicle
unpiloted, so the faction is simply poor) or oppressive (theft is easy, so the faction plays with
the opponent's army). **Both failures live in the same dial** — how hard it is to create an
unpiloted vehicle. See the tuning notes.

## Detailed Design

### Roster — Infantry

★ **Every infantry unit is a specialist. There is no generic line unit**, which is the direction's
*"highly effective infantry specialists"* taken at its word.

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `move` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| **Partisan** | The nearest thing to a line | **300** | 5 | 3 | 2 | 1 | ★ **150** | `can_pilot` ✔ · `FORTIFY` |
| ★ **Pirate** | Steal vehicles | **500** | 4 | 3 | 1 | 1 | **200** | ★ `targets_crew` ✔ · `CAPTURE_VEHICLE` · `can_pilot` ✔ |
| **Saboteur** | Break structures | **500** | 3 | 4 | 1 | 1 | **200** | `DEMOLISH` |
| **Marksman** | Reach | **600** | 3 | 7 | **4** | 1 | **200** | `SPOT` · ★ longest range in the game |
| **Missile Team** | Anti-air | **500** | 3 | 6 | 3 | 1 | **150** | ★ `can_target {AIR, GROUND_VEHICLE}` · `EMF` |

> ★ **Note the 150s.** The Partisan and Missile Team sit between the corpus's usual 100/200 steps.
> That precision is only possible because of the ×100 rescale — at the old scale both would have
> been forced to 1 or 2, and the Partisan at 2 would have made the faction unplayably poor. **This
> is the granularity the rescale was for, being used.**

> ### ★★ The Pirate, in full
>
> Two capabilities, and the direction specifies both:
>
> 1. **`targets_crew` attacks** (`transport-and-pilots.md` TP-7). When the Pirate attacks a *crewed*
>    vehicle, damage lands on the **pilot**, not the machine. Kill the pilot and the vehicle is left
>    intact and inert.
> 2. **`CAPTURE_VEHICLE`** (`unit-abilities.md`). The Pirate boards an adjacent unpiloted ground
>    vehicle, **becomes its pilot**, and ownership transfers with them.
>
> Together they are the direction's *"either moving onto an unpiloted vehicle, or by attacking the
> pilot directly and then taking control"* — a **two-turn play** at minimum: shoot the crew, then
> board. Both halves cost AP, and the window between them is the opponent's chance to respond by
> re-crewing, destroying their own vehicle, or killing the Pirate.
>
> ★ **The Pirate ends up inside the stolen vehicle**, which is the elegant part: it is now cargo,
> untargetable directly — and itself vulnerable to a `targets_crew` attack. **A stolen tank can be
> stolen straight back**, by the same trick, with no extra rules. That symmetry is what stops theft
> being one-directional.
>
> **Its limits, all deliberate:** ground vehicles only (no boarding aircraft); requires a *free
> population slot*, which on a cap of 7 is a real constraint; costs 3 AP; and the Pirate's own
> attack of 3 makes it poor at anything else.

### Roster — Ground Vehicles

★ **Deliberately mediocre**, per the direction. Every one is worse than its Alliance counterpart at
a lower price — and that is the point: the Independents' *good* vehicles are the ones they take.

★ **All `requires_pilot = true`**, `counts_toward_cap = false` (the crew consumes an infantry slot,
`population-cap.md` PC-8), `resistances {EMF: −2}` (DT-9b default). The Partisan and the Pirate both
`can_pilot`. *(Declared explicitly 2026-08-24 — the cross-review found this table omitted it.)*

> ★ **The Independents crew stolen vehicles the same way.** `CAPTURE_VEHICLE` makes the Pirate the
> new vehicle's pilot, so a stolen tank is a *piloted* tank subject to every ordinary rule — it can
> be crew-killed, it costs a slot, and it can be taken back. **Theft grants no exemption from the
> pilot requirement**, which is what keeps the mechanic symmetric.

| Unit | `cost` | `hp` | `atk` | `rng` | `move` | `capacity` | `upkeep` | vs Alliance |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **Technical** | **800** | 12 | 4 | 1 | 2 | 2 | **300** | vs Transport (1,000/16 hp/unarmed): armed but flimsy |
| **Scrap Tank** | **1,300** | 18 | 5 | 2 | 2 | — | **400** | ★ vs Tank (1,400/22 hp/atk 7): **cheaper and clearly worse** |

> The Scrap Tank exists so the Independents *can* field armour, not so they *want* to. Against an
> Alliance Tank it loses: 18 hp and attack 5 against 22 and 7. ★ **Its real job is being the thing
> you build while waiting to steal something better.**

### Roster — Air

★ **One aircraft, added 2026-08-24 (user decision, resolving IOQ-4).** The Independents were
originally authored with no air at all; every other faction fields it, and a permanent class-level
hole is a different thing from a weakness.

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `upkeep` | `capacity` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| ★ **Buzzard** | Scavenged lifter-gunship | **1,300** | ★ **6** | 3 | 1 | **400** | ★ **2** | `requires_pilot` ✔ · accepts `{INFANTRY}` · carries **`PARADROP`** · `can_target {INFANTRY, GROUND_VEHICLE}` |

> ### ★★ The Buzzard exists to deliver the Pirate
>
> It is not a gunship with a cargo bay bolted on — **it is the faction's signature mechanic given
> reach.** `PARADROP` places a carried unit on any empty tile within 3, ignoring terrain and
> pathing. Loading a **Pirate** and dropping it beside an unattended enemy vehicle converts the
> Independents' whole design from *"wait for the opponent to be careless near me"* into *"go and
> find the carelessness."*
>
> ★ **That is the right kind of aircraft for this faction** — it does not fix any of their
> weaknesses (still poor, still few, still bad at straight fights) and it does not make them
> generally stronger. It makes the thing they are *already* built to do reachable.
>
> **It is priced hard, three times over:**
> - **6 hp — the most fragile aircraft in the game.** An Alliance Fighter (attack 6) or a
>   Protectorate Talon (attack 8) kills it outright in one hit.
> - **It costs 2 of only 7 cap slots to use** — one for its own pilot, one for the Pirate inside
>   (carried units count, TP-1). A Buzzard mission is a fifth of the faction's army capacity.
> - **If it is shot down loaded, the Pirate dies with it** (TP-4). A failed raid costs 1,300 + 500
>   Credits and two slots.
>
> **The Airfield is a real commitment for them:** 1,200 Credits and 200/turn upkeep against an income
> ceiling of **1,600** — 12.5% of their whole economy just to hold the building. ★ An Independents
> player who builds one has made a strategic bet on raiding, and given up something else to do it.
>
> **UC-5 is still met by the Missile Team**, not the Buzzard — the Buzzard cannot target air at all.
> Their anti-air remains a man-portable specialist, which keeps the "we don't have an air force, we
> have *a plane*" reading intact.

### Structures and economy

| | Independents | Alliance | Δ |
|---|---:|---:|---|
| `BASE_INCOME` | **800** | 1,000 | ★ −200 (intercept) |
| Economy tier bonus | **+400** | +500 | ★ −100 (slope) |
| ★ **Economy Tier III** | **DENIED** | available | ★ tech denial |
| **Income ceiling** | ★ **1,600** | 2,500 | ★ **−36%, the lowest in the game** |
| `base_infantry_cap` | **3** | 4 | −1 |
| `max_barracks` | **2** | 3 | −1 |
| Barracks `build_cost` | ★ **900** | 600 | ★ +50% |
| **Infantry ceiling** | ★ **7** | 10 | −30% |
| `max_factories` | 1 | 2 | −1 |
| `max_airfields` | ★ **1** | 1 | — *(was 0; corrected 2026-08-24)* |
| `max_defensive` | 3 | 3 | — |

**★ All three income levers are used at once, which is unique in the corpus:** the **intercept**
(−200, poor from turn 1), the **slope** (−100 per tier, the gap widens as both sides research), and
a **tech denial** on Economy Tier III — the sanctioned "big" binary lever (`faction-identity.md`
CR-2.5). Together they produce a ceiling of **1,600 against the baseline's 2,500**.

**The expensive Barracks** is the direction's *"more expensive to increase the cap"*, expressed as
build cost rather than a raise curve now that the cap comes from structures (PC-5). Reaching the
ceiling of 7 costs the Independents **1,800 Credits** — the same absolute price the Alliance pays
for a ceiling of 10, on 64% of the income.

## Formulas

No new formulas. `FactionDef` deltas:

```
Δ_base_income      = −200
Δ_econ_tier_bonus  = −100
tech_available[ECONOMY_TIER_III] = false        ★ the binary lever
Δ_base_cap         = −1 · Δ_max_barracks = −1
Δ_barracks_cost    = +300
Δ_max_factories    = −1 · Δ_max_airfields =  0   ★ (baseline 1 — corrected 2026-08-24)
Δ_upkeep_rate      = 0                           (low upkeep authored per-unit)
```

### CR-10 comparison sheet — Independents vs the Democratic Alliance

*At full available research (income **1,600**), realistic build (2 Barracks, 1 Factory, 1 Lab = 600
upkeep), leaving **1,000/turn** for an army.*

| Axis | Alliance | Independents | Winner |
|---|---:|---:|---|
| Income ceiling | 2,500 | ★ **1,600** | ★ **Alliance, decisively** |
| Credits for army | 1,900 | **1,000** | **Alliance** |
| Mean infantry upkeep | ~200 | ~180 | Independents, slightly |
| **Sustainable units** | **~9** | ★ **~5–6** | ★ **Alliance, decisively** |
| Infantry ceiling | 10 | 7 | **Alliance** |
| Cost to reach ceiling | 1,800 → 10 | 1,800 → 7 | **Alliance** |
| Line unit quality | 3 atk / 6 hp | 3 atk / 5 hp | Alliance, slightly |
| Longest range | Artillery 5 | Marksman 4 (Artillery has 5) | **Alliance** |
| Own vehicle quality | Tank 22 hp / 7 atk | ★ Scrap 18 / 5 | ★ **Alliance, decisively** |
| Air | 3 aircraft | ★ **1** (Buzzard — fragile, unarmed vs air) | ★ **Alliance, decisively** |
| Anti-air | Fighter, Helicopter | Missile Team only (the Buzzard cannot hit air) | **Alliance** |
| ★ **Can gain material without spending** | no | ★ **yes — theft, now with air delivery** | ★ **Independents, uniquely** |
| Behavioural pressure on opponent | none | ★ high | **Independents** |
| Board presence when broke | 0 | 0 | tie |

**Verdict against CR-10.2: PASS, with a caveat that is not a number.**

> The Independents lose almost every measurable axis, several of them decisively, and win exactly
> one: **they can acquire material the opponent paid for.** That single axis is not measurable in
> the way the others are, because **its value is set by opponent behaviour rather than by any
> constant in this document.**
>
> ★ **Against a careful opponent the Independents are simply the worst faction in the game** —
> poorest economy, smallest army, no air, bad vehicles, and a 500-Credit Pirate with nothing to
> steal. **Against a careless one they play with a stolen army.** That variance is the design, and
> it is also the thing most likely to make the faction unfun at one end or the other.
>
> This is the clearest case in the corpus of a faction that **cannot be validated by the comparison
> sheet alone** and must be judged in playtest against a human who is actively trying not to lose
> vehicles.

## Edge Cases

- **Pirate kills a crew, but the vehicle is destroyed before boarding:** nothing gained. The two-turn window is the counterplay.
- **Pirate boards, then the vehicle is destroyed:** the Pirate dies with it (TP-4). ★ Stealing a tank puts a 500-Credit specialist inside a target.
- **Stolen vehicle re-stolen:** fully legal and symmetric — the enemy kills the Pirate through `targets_crew` and boards it back.
- **Pirate captures with no free population slot:** rejected (`population-cap.md` AC-10). On a cap of 7 this bites often, and is a real constraint.
- **Pirate `targets_crew` against an autonomous vehicle** (Protectorate mechs post-autonomy, the Autonomous Lifter, Solar's Defence Node): falls through to normal damage. ★ **The Protectorate's autonomy tech is a hard counter to the Pirate**, and the Independents' answer is to strike before it lands.
- **Capturing a vehicle whose class the Independents cannot build:** legal and delightful — an Independents player driving a Protectorate Lance Tank is the fantasy working.
- **Capturing an aircraft:** rejected — ground only.
- **Independents facing an all-infantry army:** the Pirate has nothing to steal and is a mediocre 500-Credit soldier. ★ The faction's worst matchup, and it is a *composition* counter rather than a stat one.
- **A stolen vehicle's upkeep:** paid by the new owner, at the vehicle's own value. ★ Stealing a Protectorate Lance Tank means inheriting **700/turn** against a 1,600 income — theft is not free, and a poor faction can be *bankrupted by its own prize*. Deliberate, and probably the best single guard on this faction.
- **Buzzard shot down while carrying a Pirate:** both die (TP-4). ★ 1,800 Credits and two of seven cap slots lost in one hit — the most concentrated risk the faction can take.
- **Paradropping a Pirate beside a crewed vehicle:** legal, but the Pirate must still shoot the crew out first and then board — the drop buys *position*, never the steal itself.
- **Buzzard facing enemy air:** it has no anti-air capability and 6 hp. It must be escorted by ground-based Missile Teams or kept away from contested air entirely.
- **Independents mirror:** two poor armies with no air and mutual theft. Likely slow; worth measuring.

## Dependencies

| System | What this faction needs | Wave |
|---|---|---|
| **Unit Upkeep** (#15) | Its low upkeep, and the stolen-vehicle upkeep guard | Sprint 6 |
| **Population Cap** (#16) | Low cap, expensive Barracks, capture gating | Wave 1 |
| **Research** (#8 rev) | ★ Tech denial on Economy Tier III | Wave 1 |
| **Unit Abilities** (#19) | `CAPTURE_VEHICLE`, `DEMOLISH`, `FORTIFY`, `SPOT`, ★ `PARADROP` | Wave 2 |
| **Transport & Pilots** (#20) | ★★ **Hard blocker** — `targets_crew`, unpiloted state, boarding | Wave 2 |
| **Unit Classes** (#17) | Vehicles and air | Wave 2 |
| **Damage Types** (#18) | `EMF` on the Missile Team | Wave 3 |
| **Promotion** (#21) | none | — |

★ **The Pirate needs `targets_crew`, which `transport-and-pilots.md` TPOQ-2 flags as the first case
in the corpus where the entity attacked is not the entity damaged.** That is an event-ordering
change touching ADR-0004 and S5-06's animation path. **This faction is why that work must be done
properly rather than patched.**

## Tuning Knobs

| Knob | Default | Guidance |
|---|---|---|
| ★ **`targets_crew` availability** | Pirate only | ★★ **The dial the whole faction lives on.** It sets how easily an unpiloted vehicle can be *created*. Give it to a second unit and theft becomes routine; take it away and the Pirate can only exploit enemy carelessness, which may never happen |
| `CAPTURE_VEHICLE` AP cost | 3 | Raise to make the two-turn play harder to complete; lower only if playtest shows theft never lands |
| Pirate `cost` / `hp` | 500 / 4 | It must be worth building even in matches where it steals nothing. At 4 hp it dies to most things in one hit |
| Income ceiling | 1,600 | ★ The lowest in the game. If the faction proves unviable, **raise this before weakening the theft mechanic** — poverty is easier to tune than a signature |
| Barracks `build_cost` | 900 | The direction's "more expensive to increase the cap" |
| Marksman `range` | 4 | Longest infantry range in the game; the faction's answer to being outnumbered |
| Scrap Tank quality | 18 hp / atk 5 | ★ Must stay clearly worse than a real tank. If it becomes competitive, theft stops mattering |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN the Independents at full available research, THEN `credit_income` is exactly **1,600** | Logic |
| AC-2 | GIVEN an Independents player, THEN Economy Tier III never appears as a legal research target | Integration |
| AC-3 | GIVEN a full Independents build-out, THEN `effective_cap` is exactly **7** | Logic |
| AC-4 | **[REVISED 2026-08-24]** GIVEN an Independents player, THEN exactly one Airfield may be built and the **Buzzard** is its only producible aircraft | Integration |
| AC-4b | GIVEN a Buzzard carrying a Pirate, WHEN `PARADROP` targets an empty tile within 3, THEN the Pirate is placed there and may act on a subsequent turn | Integration |
| AC-4c | GIVEN a loaded Buzzard is destroyed, THEN the carried Pirate is destroyed with it and both cap slots free | Integration |
| AC-4d | GIVEN a Buzzard and an enemy `AIR` unit, THEN the aircraft is not a legal target | Logic |
| AC-5 | GIVEN a Pirate attacking a crewed enemy vehicle, THEN the pilot's hp decreases and the vehicle's does not | Integration |
| AC-6 | GIVEN that attack kills the pilot, THEN the vehicle becomes unpiloted and is not destroyed | Integration |
| AC-7 | GIVEN a Pirate adjacent to an unpiloted enemy ground vehicle with a free cap slot, THEN `CAPTURE_VEHICLE` transfers ownership and the Pirate becomes its pilot | Integration |
| AC-8 | GIVEN that capture, THEN the Pirate is thereafter carried — absent from legal targets and from `pick_regions` | Integration |
| AC-9 | GIVEN a captured vehicle, THEN its upkeep is charged to the new owner at the vehicle's own value | Integration |
| AC-10 | GIVEN the new owner cannot afford that upkeep, THEN they enter deficit normally (no special case) | Integration |
| AC-11 | GIVEN a Pirate targeting an aircraft with `CAPTURE_VEHICLE`, THEN it is rejected | Logic |
| AC-12 | GIVEN a Pirate `targets_crew` attack against a `requires_pilot = false` unit, THEN normal damage applies to that unit | Logic |
| AC-13 | GIVEN a stolen vehicle whose Pirate pilot is killed by an enemy `targets_crew` attack, THEN it becomes unpiloted and either side may board it | Integration |
| AC-14 | GIVEN a Pirate capture attempt at population cap, THEN it is rejected | Integration |
| AC-15 | GIVEN a Missile Team, THEN infantry never appear in its legal targets, and `AIR` and `GROUND_VEHICLE` do | Integration |
| AC-16 | ★ GIVEN an Alliance-vs-Independents AI batch, THEN neither wins more than **65%** across both seats | Integration |
| AC-17 | ★ GIVEN an AI batch where the AI never leaves a vehicle unpiloted, THEN the Independents still win at least **25%** (the faction must be viable without theft) | Integration |

## Open Questions

| # | Question | Owner |
|---|---|---|
| IOQ-1 | ★★ **Is the Independents' variance acceptable?** Against a careful opponent they are the worst faction in the game; against a careless one they play with a stolen army. No constant in this document sets that — **opponent behaviour does.** This is a faction-design judgement, not a balance calculation. **Design call — the user's**, and the one I would most want played before it is trusted | user + game-designer |
| IOQ-2 | ★★ **Can the AI ever leave a vehicle unpiloted?** If the AI never makes that mistake, the Pirate is dead weight in every AI match — which is most of the game's content. Conversely, an AI that parks vehicles badly hands the Independents free wins. ★ **The Independents may be the faction that most needs the AI to be *good*, not merely competent** (`faction-identity.md` OQ-15) | ai-programmer |
| IOQ-3 | **Is stealing a Protectorate tank actually good for the Independents?** Inheriting 700/turn upkeep against a 1,600 income is 44% of their whole economy for one vehicle. ★ Theft may be self-limiting in a way that is *better* than any rule I could write — but it needs measuring, because it could equally mean theft is never worth doing | economy-designer |
| ~~IOQ-4~~ | ✅ **RESOLVED 2026-08-24 (user): grant them at least one aircraft.** The **Buzzard**, a scavenged lifter-gunship whose real job is `PARADROP`-ing a Pirate next to an unattended enemy vehicle — it extends the faction's signature rather than patching a weakness. Priced hard: 6 hp (most fragile aircraft in the game), 2 of 7 cap slots per mission, and cargo dies with it. ★ They still cannot **steal** aircraft (`CAPTURE_VEHICLE` is ground-only), so "we have a plane, not an air force" survives | ✅ closed |
| IOQ-5 | ★ **Does `targets_crew` belong to more than the Pirate?** Giving it to a second faction would make the unpiloted state common enough to matter generally — but it would also dilute the Independents' signature. Recommend **Pirate-only** until playtest says otherwise | systems-designer |
| IOQ-6 | **The name.** *"Independents"* is neutral to the point of invisible next to five loaded names, and *"Revolutionary Rebels"* is more evocative than the mechanics, which read as **scavengers and opportunists** rather than ideologues. **Naming call — the user's** | user |
