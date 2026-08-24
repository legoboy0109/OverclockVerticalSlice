# Faction — Galactic Protectorate

> **Status**: **DRAFT** (2026-08-24) — Tier 2 of the faction corpus v2.
> **Name**: ★ TBD. Flavour: Hoppean / Voluntarist Alliance.
> **Author**: user (direction) + agents · **Baseline**: `factions/democratic-alliance.md` (CR-10)
>
> ★★ **The faction flagged as most likely to be over-tuned** (`population-cap.md` PC-8). Its robots
> escape the population cap, which is a large advantage, and **upkeep is the only thing paying for
> it.** The CR-10 sheet below is written to test that claim rather than assert it — and the answer
> turned out to be more interesting than expected.
>
> ★ **Needs the most Tier-1 systems of any faction**: damage types (EMF, `BURST`, `LINE`,
> `INCENDIARY`), transports carrying vehicles, autonomy tech, and abilities. **Wave 3 at the
> earliest.**

---

## Overview

The **Galactic Protectorate** is the only **bimodal** faction: it fields simultaneously the cheapest
and the most expensive units in the game, and almost nothing between them.

Its line is a **humanoid infantry robot** — cheap to buy, weak, and expensive to keep running. It
does not count against the population cap, so the Protectorate can always put *something* on the
board, but every machine bleeds Credits every turn. Behind that screen stand three **human
specialists** — demolitions, anti-armour, support — who are frail, costly, and capable of deciding a
fight outright.

Its vehicles follow the same split: two **mechs** that are essentially better robots, and two
**tanks** with the heaviest guns in the game, moderate armour, and a pronounced weakness to EMF.
Through its tech tree the mechs can be upgraded to **run without pilots** — which is the faction's
central strategic arc, because until that research lands its machines consume the human capacity it
has least of.

Its thesis: **machines are expendable, people are not, and the tech tree is how you stop needing
people.**

## Player Fantasy

**The feeling: "spend the machines, protect the people."**

- **Two economies of loss.** Losing a robot is a shrug. Losing an anti-armour specialist is a
  disaster. No other faction has such a sharp internal distinction between its own units, and the
  player should feel it every time they choose who leads.
- **The screen and the scalpel.** Robots go first, absorb, and die. The specialists arrive behind
  them and end things. That two-layer rhythm is the faction's signature.
- **★ Autonomy as liberation.** Before the mech autonomy tech, every machine needs a person inside
  it, and people are the thing you cannot make more of. After it, the machines run themselves. The
  research should feel like the faction *becoming what it wants to be* — the most narratively loaded
  tech in the game.
- **Bleeding by design.** The Protectorate is always slightly broke. Its army is expensive to hold
  and it knows it, so it wants engagements *now*.

**The failure mode to avoid:** robots being so cheap and so numerous that the specialists never
matter. If the optimal Protectorate line is "spam robots, ignore the humans", the faction has
collapsed into a worse Solar Federation. The guard is robot **upkeep** — see below, where it does
almost all the balancing work in this document.

## Detailed Design

### Roster — Infantry

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `move` | `upkeep` | Cap | Notes |
|---|---|---:|---:|---:|---:|---:|---:|:---:|---|
| ★ **Servitor** *(humanoid robot)* | The entire line | **200** | 4 | 2 | 1 | 2 | ★ **300** | ★ **exempt** | `can_pilot` ✔ with ★ `crew_bonus: attack −1` · `resistances {EMF: −2}` |
| **Demolitions Specialist** | Break structures | **600** | 3 | 4 | 1 | 2 | **300** | counts | `DEMOLISH` |
| **Lance Specialist** *(anti-armour)* | Kill machines | **700** | 3 | 7 | 2 | 2 | **300** | counts | `EMF` · `can_target {GROUND_VEHICLE, AIR}` |
| **Support Specialist** | Enable | **600** | 3 | 1 | 1 | 2 | **300** | counts | `REPAIR`, `SPOT` |

> ### ★★ The Servitor is where this entire faction is balanced
>
> Read the two numbers together: **200 to buy, 300 a turn to keep.** It is the *cheapest* unit in
> the game to acquire and, per point of combat value, by far the **most expensive to hold** — an
> Alliance Heavy (attack 5, 10 hp) also costs 300 upkeep. That is the direction's *"less economical
> than standard infantry of other factions"* made literal, and it is the sole price of cap exemption.
>
> **What that buys and what it costs.** The Protectorate can field an unbounded *number* of
> Servitors — no cap, no Barracks requirement, no ceiling. What it cannot do is *sustain* them:
> every Servitor is a permanent 300/turn drain that buys 2 attack and 4 hp. **Upkeep replaces the
> cap as this faction's army-size limit**, and it is a harsher limiter than a cap, because it scales
> with what you already own rather than stopping at a wall.
>
> ★ **This is the honest answer to PC-8's over-tune flag.** The Protectorate is *not* uncapped in any
> way that matters — it is capped by a different, tighter mechanism. The CR-10 sheet below shows it
> ends up with the **smallest sustainable army in the game.**
>
> **Servitors are EMF-vulnerable** (−2, the DT-9b machine default, despite being infantry). They are
> machines and read as machines — an enemy anti-armour weapon works on them, which is a genuine and
> deliberate soft spot no other faction's line unit has.

> **The three specialists share one profile: 3 hp, 300 upkeep, 600–700 Credits.** They die to a
> single hit from almost anything and cost more than double a Servitor. ★ They are *"high damage/
> value potential, but frail and expensive"* exactly as directed — and because they count against a
> cap of only **7**, the Protectorate can never field many.

### Roster — Ground Vehicles

★ Mechs and tanks are deliberately different *kinds* of thing, not two tiers of one thing.

| Unit | Class | `cost` | `hp` | `atk` | `rng` | `move` | `upkeep` | `requires_pilot` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|:---:|---|
| **Sentinel Mech** *(general purpose)* | mech | **1,200** | 20 | 6 | 2 | 2 | **500** | ✔ *(until autonomy)* | A bigger, tougher Servitor. `resistances {EMF: −2}` |
| **Breaker Mech** *(close-quarters AoE anti-armour)* | mech | **1,500** | 18 | 6 | **1** | 2 | **600** | ✔ *(until autonomy)* | `EMF` · `area_shape = BURST` · `resistances {EMF: −2}` |
| **Lance Tank** *(anti-armour, indirect)* | tank | **1,800** | 22 | 8 | **3** | 2 | **700** | ✔ always | `EMF` · `min_range` 2 · ★ `resistances {EMF: −3}` |
| **Cinder Tank** *(napalm + machine gun)* | tank | **1,900** | 22 | 7 | **4** | 2 | **700** | ✔ always | ★ Dual profile — see below · ★ `resistances {EMF: −3}` |

**★ The Cinder Tank's two weapons.** The direction specifies *"a long range napalm gun and close
quarters machine gun"*. Expressed as two attack profiles on one unit, selected by range at the
moment of attack — no new machinery, just a second entry in the unit's attack table:

| Profile | Range | `attack` | `damage_type` | Note |
|---|---:|---:|---|---|
| Napalm gun | 2–4 (`min_range` 2) | 7 | `INCENDIARY` | ★ Ignores `COVER_DR` (DT-6) |
| Machine gun | 1 | 4 | `KINETIC` | The close-in fallback |

> This makes it the only unit in the game with **no dead zone** — most long-range units are helpless
> when closed on, and this one is merely worse. Priced accordingly at 1,900 and 700 upkeep.

> ### ★ Both tanks are EMF-weak at −3, beyond the −2 machine default
>
> `damage-types.md` DT-9b already makes every vehicle EMF-vulnerable. The Protectorate's tanks are
> *more* so, which is what keeps the direction's *"weak to EMF damage"* a distinguishing trait rather
> than a shared one. Against a Solar Lance Team (attack 6, EMF) a Lance Tank takes **9** per hit — it
> dies in three to a 400-Credit specialist. ★ **The heaviest guns in the game sit on the most
> counterable chassis**, and every faction now has EMF access, so this is a real and universal
> answer rather than a theoretical one.

### Roster — Air

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `upkeep` | `can_target` | Notes |
|---|---|---:|---:|---:|---:|---:|---|---|
| **Strafer** | Ground attack run | **1,400** | 7 | 5 | 2 | **500** | `{INFANTRY, GROUND_VEHICLE}` | ★ `area_shape = LINE`, `area_length` 4 |
| ★ **Autonomous Lifter** | Heavy transport | **1,500** | 8 | — | — | **500** | `{}` unarmed | ★ `requires_pilot` **false** · `capacity` **3**, accepts `{INFANTRY, GROUND_VEHICLE}` |
| **Talon** | Air superiority | **1,500** | 7 | **8** | 2 | **500** | ★ `{AIR}` **only** | Highest anti-air attack in the game |

> **The Autonomous Lifter** is the direction's *"autonomous transport that can pick up multiple
> infantry or one mech vehicle"* — capacity 3 with a mech at `transport_size` 3 (`transport-and-pilots.md`)
> makes that fall straight out of the existing numbers with no special case. Being pilot-free, it
> costs no human capacity, and it is the only aircraft in the corpus that can lift a vehicle.
>
> **The Talon** at attack 8 one-shots every aircraft in the game (air hp band 5–9). ★ Air superiority
> here is genuinely *superiority* — but it is air-only, so a Talon against a ground army is 1,500
> Credits and 500/turn of nothing.

### Tech tree

Full base access (Attack, Defense, Economy I–III) plus **one unique branch**:

| Tech | `research_cost` | `ap_surcharge` | `research_time` | Effect |
|---|---:|---:|---:|---|
| ★ **Mech Autonomy** | **2,000** | 2 | 3 turns | Sets `requires_pilot = false` on **Sentinel** and **Breaker** mechs. Existing crewed mechs eject their pilot on completion (the pilot survives and returns to the board). Tanks are **not** affected |

> ### ★★ Why Mech Autonomy is the faction's whole strategic arc
>
> Before it, every mech needs a crew — and a crew is a **Servitor at 300/turn with a −1 attack
> penalty**, or one of the seven human slots the faction cannot spare. After it, mechs are free of
> both. The research is worth roughly **300 upkeep and +1 attack per mech, permanently.**
>
> It is deliberately expensive (2,000 — over half an Economy Tier III) and deliberately does **not**
> cover tanks. Tanks always need people. That keeps the human cap relevant all game and stops the
> faction from becoming fully automated, which would erase its own tension.

### Structures and economy

| | Protectorate | Alliance | Δ |
|---|---:|---:|---|
| `BASE_INCOME` / tiers / ceiling | 1,000 / +500 / **2,500** | same | ★ none |
| `base_infantry_cap` | **3** | 4 | −1 |
| `max_barracks` | **2** | 3 | −1 |
| **Human ceiling** | ★ **7** | 10 | −30% |
| Servitor ceiling | ★ **none** (upkeep-bound) | — | — |
| `max_factories` | **3** | 2 | ★ +1 |
| `max_airfields` | 1 | 1 | — |
| `max_defensive` | 2 | 3 | −1 |
| Defensive Structure | `requires_pilot` **false**, `attack` 3 | manned, `attack` 4 | ★ autonomous but weaker |

★ **Its economy is exactly the baseline.** The Protectorate is not an economic faction in either
direction — every difference it has is in what it spends on. That is deliberate: with two variables
already moving hard (cap exemption and upkeep), a third would make the faction impossible to reason
about.

## Formulas

No new formulas. `FactionDef` deltas:

```
Δ_base_income = 0 · Δ_econ_tier_bonus = 0        ★ economy is baseline
Δ_base_cap = −1 · Δ_max_barracks = −1            (human ceiling 7)
Δ_max_factories = +1 · Δ_max_defensive = −1
Δ_upkeep_rate = 0                                 ★ high upkeep is authored per-unit (D9-own)
```

### CR-10 comparison sheet — Protectorate vs the Democratic Alliance

*Computed at full research (income 2,500), realistic build (2 Barracks, 1 Factory, 1 Lab = 600
upkeep), leaving **1,900/turn** for an army.*

| Axis | Alliance | Protectorate | Winner |
|---|---:|---:|---|
| Income ceiling | 2,500 | 2,500 | tie |
| Credits for army | 1,900 | 1,900 | tie |
| Mean unit upkeep | ~200 | ★ **~300–700** | **Alliance** |
| **Sustainable unit count** | **~9** | ★ **~5** | ★ **Alliance, decisively** |
| Population cap ceiling | 10 | 7 humans + ∞ robots | mixed |
| Line unit quality (atk/hp) | 3 / 6 | ★ 2 / 4 | **Alliance** |
| Peak single-unit attack | Artillery 8 | Lance Tank 8 (**EMF, effective 10 vs armour**) | **Protectorate** |
| Anti-armour | Tank atk 7 | ★ 3 dedicated EMF platforms | ★ **Protectorate, decisively** |
| Anti-air | Fighter atk 6 | Talon atk **8** | **Protectorate** |
| Vulnerability to EMF | Tank −2 | ★ **Everything**: robots −2, mechs −2, tanks −3 | ★ **Alliance, decisively** |
| Board presence when broke | 0 | ★ Servitors (200 each) | **Protectorate** |
| Specialists lost per bad trade | replaceable | ★ catastrophic (600–700, 3 hp) | **Alliance** |
| Tiles moved per turn (30 AP) | ~15 | ~15 | tie |

**Verdict against CR-10.2: PASS — and the over-tune flag is answered.**

> ★ **The finding worth recording.** PC-8 flagged the Protectorate as the likely over-tune because
> its robots dodge both the population cap and the pilot requirement. Working the numbers through,
> **the opposite is true: it has the smallest sustainable army in the game (~5 against the Alliance's
> ~9 and Solar's ~11).** Cap exemption turns out to be worth much less than it looks once upkeep is
> the real constraint, because **a cap stops at a wall and upkeep keeps taking.** The exemption buys
> the Protectorate the ability to *always field something* — never zero units, never production-
> locked by a cap — which is a resilience advantage, not a scale one.
>
> ★ **Its actual weakness is EMF, and it is severe.** The Protectorate is the only faction where
> *every unit type* is EMF-vulnerable — robots (−2), mechs (−2), tanks (−3). Any opponent bringing
> a single anti-armour specialist has a weapon that works on the entire army, including its
> infantry. That is a real, targetable, universal answer, and it is what makes the faction's
> firepower fair.

## Edge Cases

- **All 7 human slots filled, wanting more bodies:** build Servitors. Always available, always affordable to *buy*, never affordable to *hold* indefinitely.
- **Mech Autonomy completing while mechs are crewed:** each pilot ejects and returns to the board (needing no new slot — a crewing unit already held one, PC-8). If the ejecting unit is a Servitor it simply rejoins the line.
- **A Servitor crewing a vehicle:** legal, costs no cap slot, and applies `crew_bonus: attack −1`. ★ The faction's standard practice before autonomy, and the reason the tech is worth 2,000.
- **A human specialist crewing a vehicle:** legal, no penalty — but it spends one of seven slots and takes a 700-Credit unit out of the fight. Almost always wrong; occasionally the only option.
- **Lance Tank at range 1:** cannot fire (`min_range` 2). Its counterplay is closing.
- **Cinder Tank at range 1:** fires the machine gun at 4. ★ No dead zone — the design point.
- **Cinder Tank napalm against a unit in cover:** `COVER_DR` does not apply (DT-6).
- **Autonomous Lifter carrying a mech, destroyed:** the mech dies with it (TP-4). ★ 1,500 + 1,200 Credits in one hit — the largest single loss available in the game.
- **Protectorate facing a faction with no EMF:** its tanks lose their principal weakness. ★ Check per matchup — a faction with no EMF answer may find the Protectorate genuinely oppressive. UC-5's anti-air requirement has a natural sibling here (POQ-3).
- **A Servitor army with zero humans:** legal, and a real fallback position. Weak (attack 2 across the board) but never eliminated.
- **Protectorate mirror:** two EMF-heavy armies that are both EMF-vulnerable. ★ Likely extremely fast and worth measuring.

## Dependencies

| System | What this faction needs | Wave |
|---|---|---|
| **Unit Upkeep** (#15) | ★ **Load-bearing** — upkeep *is* this faction's balance | Sprint 6 |
| **Population Cap** (#16) | ★ `counts_toward_cap = false` on Servitors | Wave 1 |
| **Unit Classes** (#17) | Mechs, tanks, air | Wave 2 |
| **Transport & Pilots** (#20) | ★ `crew_bonus` (negative), `requires_pilot`, vehicle-carrying transport | Wave 2 |
| **Unit Abilities** (#19) | `DEMOLISH`, `REPAIR`, `SPOT`, `EMBARK`/`DISEMBARK` | Wave 2 |
| **Damage Types** (#18) | ★★ **Hard blocker** — `EMF`, `INCENDIARY`, `BURST`, `LINE`, and the DT-9b defaults. Without it the tanks, both mechs, the Lance Specialist and the Strafer all lose their identities | Wave 3 |
| **Research** (#8 rev) | ★ Mech Autonomy — a tech that changes unit *behaviour*, not stats | Wave 3 |
| **Promotion** (#21) | none | — |

★ **This faction cannot ship before wave 3**, and unlike Solar it has no meaningful reduced form —
strip damage types and you remove the point of nine of its twelve units.

## Tuning Knobs

| Knob | Default | Guidance |
|---|---|---|
| ★ **Servitor `upkeep`** | **300** | ★★ **The single most important number in this document.** It is the entire price of cap exemption. At 200 the Protectorate fields ~9 free-of-cap robots and becomes the strongest faction; at 400 the robot line is unaffordable and the faction has no line at all. **Tune this before anything else here** |
| Servitor `cost` | 200 | Cheap to buy is the fantasy; cheap to *hold* is the failure |
| Human ceiling (`base_cap` + `max_barracks`) | 3 + 2 → 7 | Sets how many specialists can ever exist at once |
| Tank `resistances[EMF]` | −3 | ★ The faction's principal weakness. At −1 it merges into the vehicle default and stops being an identity |
| Mech Autonomy cost | 2,000 | Must be expensive enough that it is a real mid-game commitment, cheap enough to reach before turn 30 |
| Tank upkeep | 700 | With 1,900 available, two tanks and nothing else is the ceiling. That top-heaviness is intended |
| Talon `attack` | 8 | One-shots the entire air band. Reduce to 6–7 if air becomes unplayable against the Protectorate |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a Protectorate player at their human cap, THEN Servitor production still succeeds | Integration |
| AC-2 | GIVEN 20 Servitors owned, THEN `current_population` counts none of them | Logic |
| AC-3 | GIVEN a Servitor crewing a vehicle, THEN the vehicle's `effective_attack` is 1 lower than uncrewed-baseline, and no cap slot is consumed | Integration |
| AC-4 | GIVEN a human specialist crewing a vehicle, THEN no attack penalty applies and one cap slot is consumed | Integration |
| AC-5 | GIVEN Mech Autonomy completes with crewed mechs on the board, THEN each mech's `requires_pilot` becomes false and each pilot returns to the board as a live unit | Integration |
| AC-6 | GIVEN Mech Autonomy is held, THEN Lance and Cinder Tanks still require pilots | Logic |
| AC-7 | GIVEN a Lance Tank and an `EMF` attacker of attack 6, THEN damage is 9 (`6 − (−3)`) | Logic |
| AC-8 | GIVEN a Servitor and an `EMF` attacker of attack 6, THEN damage is 8 (`6 − (−2)`) | Logic |
| AC-9 | GIVEN a Cinder Tank and a target at range 1, THEN the machine-gun profile (attack 4, `KINETIC`) resolves | Integration |
| AC-10 | GIVEN a Cinder Tank and a target at range 3, THEN the napalm profile (attack 7, `INCENDIARY`) resolves and ignores `COVER_DR` | Integration |
| AC-11 | GIVEN a Cinder Tank and a target at range 5, THEN there is no legal attack | Logic |
| AC-12 | GIVEN a Lance Tank and an adjacent enemy, THEN the attack is rejected (`min_range` 2) | Logic |
| AC-13 | GIVEN an Autonomous Lifter carrying a Sentinel Mech, THEN `transport_load` is 3 and no further unit may embark | Logic |
| AC-14 | GIVEN that Lifter is destroyed, THEN the carried mech is destroyed with it | Integration |
| AC-15 | GIVEN a Strafer attacking, THEN every unit along a 4-tile line from attacker through target takes damage, friendlies included | Integration |
| AC-16 | GIVEN a Talon and a ground-only board, THEN it has no legal targets | Logic |
| AC-17 | GIVEN a Protectorate Defensive Structure with no crew, THEN it fires at attack 3 | Integration |
| AC-18 | ★ GIVEN an Alliance-vs-Protectorate AI batch, THEN neither faction wins more than **65%** across both seats | Integration |
| AC-19 | ★ GIVEN a Protectorate player with 1,900 Credits/turn available, THEN a sustained army of more than **6** units drives them into deficit within 5 turns (the upkeep-as-limiter regression) | Integration |

## Open Questions

| # | Question | Owner |
|---|---|---|
| POQ-1 | ★★ **Is Servitor upkeep at 300 the right price for cap exemption?** The whole faction rests on it, and the CR-10 sheet says it currently over-corrects — the Protectorate has the *smallest* sustainable army in the game. That may be correct (it has the best individual units) or it may mean 250 is fairer. **Measure before adjusting**; it is exactly the kind of number simulation answers well | economy-designer |
| POQ-2 | ★ **Is "always able to field something" too strong in a losing position?** A Protectorate player reduced to their HQ can still buy Servitors at 200 while an Alliance player at cap-lock and low Credits genuinely cannot act. That is a real comeback mechanism — possibly the best in the corpus — but it may also make the faction impossible to close out, which is the *exact* failure the PIVOT verdict was about | game-designer |
| POQ-3 | ★ **Should there be a UC-5-style "every faction needs an EMF answer" rule?** The Protectorate is uniquely EMF-vulnerable, which is fair only if opponents can exploit it. A faction with no EMF weapon faces an army whose principal weakness it cannot touch. Recommend adding it to CR-10's review checklist rather than as a hard rule | systems-designer |
| POQ-4 | **Does the two-profile Cinder Tank need new machinery?** It is modelled as two entries in one unit's attack table selected by range. `combat-resolution.md` has `min_range` and single-profile attacks; whether multi-profile is a small addition or a real change needs a look before it is promised | systems-designer |
| ~~POQ-5~~ | ✅ **CHECKED 2026-08-24 when the Union was authored** — see `factions/machinists-union.md` § "Held apart from the Protectorate". They share *"vehicles are good"* and nothing else. The Protectorate is **bimodal** (200-Credit robots + 700-Credit specialists, nothing between), cap-exempt, economically flat, and bounded by **upkeep**; the Union is **uniform** (no disposable tier at all), always crewed, economically **compounding**, and bounded by **time**. ★ The sharpest test: **the Protectorate never loses to a rush** — it can always buy Servitors — **while the Union nearly does**, and that is its defining vulnerability | ✅ closed |
| POQ-6 | **The name.** *"Galactic Protectorate"* reads imperial/centralised; *"Hoppean/Voluntarist"* reads the opposite. The mechanics — private specialists, contracted machines, no mass conscription — serve the voluntarist reading. **Naming call — the user's** | user |
