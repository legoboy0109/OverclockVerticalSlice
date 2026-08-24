# Faction — Democratic Alliance of Planets

> **Status**: **DRAFT** (2026-08-24) — Tier 2 of the faction corpus v2. **The balance baseline.**
> **Name**: ★ TBD (user, 2026-08-24: *"Final Names TBD"*). Flavour: Warhawk Social Democracy.
> **Author**: user (direction) + agents · **Framework**: `faction-identity.md` v2
>
> ★★ **This faction is the reference every other faction is measured against (CR-10).** Its numbers
> are not "the Alliance's balance" — they are *the game's* balance. A change here propagates to five
> comparison sheets. Change it last and deliberately, never as a local fix.
>
> ★ **It is also the faction the game already ships.** Its four infantry are the Scout, Trooper,
> Heavy and Sniper currently in `data/units/`, unchanged. That is not a coincidence to be tidied
> away — it means the baseline is the only faction whose values have ever been played, and it is why
> it is the right reference.

---

## Overview

The **Democratic Alliance of Planets** is the generalist. It fields a full spread across all three
unit classes — three infantry tiers plus a marksman, three ground vehicles, three aircraft — with no
outstanding strength and no exploitable hole. Its structures are conventional, its defences are
manned, and its tech tree is a straight line with no tricks.

Its thesis is **completeness**: whatever the situation calls for, the Alliance owns a serviceable
answer. It never owns the *best* answer. Every other faction beats it at something specific and
loses to it somewhere else.

Mechanically it is defined by what it *does not* do: no cap exemptions, no autonomous units, no
promotion, no stealing, no faction-wide vulnerability. Every modifier in its `FactionDef` is
identity (Δ = 0). **The Alliance is the game with nothing added and nothing taken away**, which is
precisely what makes it usable as a control.

## Player Fantasy

**The feeling: "I have an answer for that."**

The Alliance player is never surprised into helplessness and never handed a free win. The fantasy is
**competence and adaptability** rather than a signature trick — the satisfaction of reading a
situation correctly and having the right tool already built.

- **Nothing is off the table.** Enemy air? Build a fighter. Fortified line? Bring artillery. Fast
  flank? Your own scouts are just as fast.
- **Skill shows cleanly.** With no gimmick carrying you, outcomes read as *decisions*. This makes
  the Alliance the correct faction to learn on and the correct faction to test balance against.
- **No dread, no coasting.** No unwinnable matchups, and no matchup where the faction plays itself.
- ★ **The intended failure feeling is "I got outplayed", never "I got countered."** If an Alliance
  player ever feels the *faction* lost the game rather than the player, this design has failed and
  CR-10's comparison sheet is where to look.

**The risk this faction carries, stated plainly:** the generalist is the easiest faction to make
boring. A faction defined by not having a hook can read as the "no faction" option. The mitigation
is **breadth as its own identity** — the Alliance is the only faction with a genuinely full roster
across all three classes, and being the only one who can do *everything* is a real strategic
position, not an absence.

## Detailed Design

### Roster — Infantry

★ **All four ship today and are unchanged.** `hp` values are the real shipped ones (3–10), which are
lower than a casual reading suggests: a Sniper's attack of 6 one-shots most of the roster.

| Unit | Role | `produce_cost` | `hp` | `attack` | `range` | `move_cost` | `soft_move_cap` | `upkeep` | `can_pilot` |
|---|---|---:|---:|---:|---:|---:|---:|---:|:---:|
| **Light Infantry** *(Scout)* | Screen, scout, crew | **200** | 3 | 2 | 1 | 1 | 4 | **100** | ★ **yes** |
| **Medium Infantry** *(Trooper)* | The line | **400** | 6 | 3 | 2 | 2 | 3 | **200** | ★ **yes** |
| **Heavy Infantry** *(Heavy)* | Push and hold | **700** | 10 | 5 | 2 | 3 | 2 | **300** | no |
| **Sniper** | Reach and threat | **500** | 3 | 6 | 3 | 2 | 3 | **200** | no |

- All are `INFANTRY`, all `counts_toward_cap = true`, all `damage_type = KINETIC`, all
  `resistances = {}` (neutral across the board — the baseline defines "no resistance").
- ★ **Light and Medium can pilot** (TP-5c). This is the Alliance's generalist answer to crewing: it
  needs no dedicated pilot unit, and any Light Infantry can go drive the tank. Solar's specialist
  Pilot and the Union's pilot-focused infantry are differentiations *against* this baseline.
- `can_target = {INFANTRY, GROUND_VEHICLE}` for all four. ★ **No infantry can hit aircraft.**

### Roster — Ground Vehicles

All `GROUND_VEHICLE`: blocked by difficult terrain, no cover benefit, `requires_pilot = true`,
`counts_toward_cap = false` (but each costs an infantry slot for its crew, PC-8).

| Unit | Role | `produce_cost` | `hp` | `attack` | `range` | `move_cost` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---|
| **Transport** | Move infantry | **1,000** | 16 | — | — | 2 | **400** | `transport_capacity` 3, accepts `{INFANTRY}`. Unarmed. `can_target = {}` |
| **Tank** | The armoured answer | **1,400** | 22 | 7 | 2 | 2 | **500** | `resistances = {INCENDIARY: +2, EMF: −2}` (EMF is the DT-9b default) |
| **Artillery** | Break a static line | **1,600** | 16 | 8 | **5** | 2 | **500** | `min_range` **2** — cannot fire adjacent. `area_shape = BURST` |

> ★ **The Artillery is the Alliance's most interesting unit and its most dangerous to balance.**
> Range 5 on a 12×10 board reaches a long way, and `BURST` hits four tiles. Its guards are: it costs
> 1,600 Credits *and* an infantry slot, it cannot fire at anything adjacent (`min_range` 2), it takes
> `AREA_AP_SURCHARGE` on every shot, it has infantry-tier hp, and **its burst hits friendlies**
> (DT-8). It is meant to be answered by getting close to it. Watch it in playtest before anything
> else on this sheet.

### Roster — Air

All `AIR`: flat `AIR_MOVE_COST` 1 over any terrain, no cover, cannot capture or hold (UC-6),
`requires_pilot = true`, `counts_toward_cap = false`.

| Unit | Role | `produce_cost` | `hp` | `attack` | `range` | `upkeep` | `can_target` |
|---|---|---:|---:|---:|---:|---:|---|
| **Fighter** | Air superiority | **1,200** | 7 | 6 | 2 | **400** | ★ `{AIR}` **only** |
| **Bomber** | Strike ground | **1,400** | 6 | 7 | 1 | **500** | `{INFANTRY, GROUND_VEHICLE}`, `area_shape = BURST` |
| **Helicopter** | Flexible gunship | **1,200** | 9 | 5 | 2 | **400** | `{INFANTRY, GROUND_VEHICLE, AIR}` — the generalist's generalist |

> ★ **The Helicopter is the Alliance in miniature** — it can hit anything and is best against
> nothing. It is also the faction's **UC-5 compliance**: the Alliance can always answer air, because
> the Helicopter and the Fighter both exist. Note the Fighter is deliberately *unable* to hit ground,
> so an all-Fighter build is not a general-purpose army.

### Structures

| Structure | Produces | Max | `build_cost` | `build_time` | `hp` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| **HQ** | Light Infantry | 1 | — | — | 40 | **0** | `defense` 2. The win condition |
| **Barracks** | `{INFANTRY}` | **3** | **600** | 2 | 12 | **100** | ★ +2 infantry cap each |
| **Factory** | `{GROUND_VEHICLE}` | **2** | **1,000** | 3 | 14 | **200** | ★ Reuses the retired Economy Outpost art |
| **Airfield** | `{AIR}` | **1** | **1,200** | 3 | 12 | **200** | |
| **Research Lab** | — | 1 | **800** | 2 | 10 | **200** | ★ The whole economy |
| **Defensive Structure** | — | **3** | **500** | 2 | 10 | **100** | `attack` 4, `range` 2, `can_counterattack`. ★ **Manned** — see below |

**★ "Manned defence structures" (user direction) — what it means mechanically.** The Alliance's
Defensive Structure `requires_pilot = true`: it needs an infantry crew to fire, and so **costs an
infantry slot like a vehicle does.** An uncrewed one is a wall — it has hp and blocks a tile, but
does not shoot. This is the direct counterpart to the Solar Federation's *"cheap autonomous defence
structures that build quickly but have lower damage"*, and it is what makes that contrast a real
tradeoff rather than a stat difference: **Alliance defences hit harder but consume army capacity;
Solar's are free to hold but weak.**

### Economy, cap and tech

| | Value | vs baseline |
|---|---|---|
| `BASE_INCOME` | **1,000** | — (defines it) |
| Economy tiers | I/II/III at 1,000 / 2,000 / 3,500 Credits, **+500** each | — |
| Income ceiling | **2,500** | — |
| `base_infantry_cap` | **4** | — |
| `cap_per_barracks` | 2 · `max_barracks` **3** | — |
| **Infantry ceiling** | **10** | — |
| Tech tree | Attack, Defense, Economy I–III | ★ All available, no denials, no unique branches |
| Promotion | **none** | Empire only (PV-8) |

**"Straightforward tech tree" (user direction):** the Alliance has access to every base tech at base
cost with no unique branches and no denials. It is the only faction for which the tech tree is
simply the tech tree.

## Formulas

The Alliance introduces **no new formulas**. Every value above feeds the existing shared formulas
unchanged, and its `FactionDef` is identity across every MOD domain:

```
Δ_base_income = 0 · Δ_econ_tier_bonus = 0 · Δ_econ_tier_cost = 0
Δ_upkeep_rate = 0 · Δ_build_cost = 0 · Δ_build_time = 0 · Δ_production_cap = 0
```

★ **This is the load-bearing property of the whole document.** Because every Alliance delta is zero,
`effective_X(entity, alliance_player) == base_X(entity)` for every domain — which makes the Alliance
the regression anchor v1's AC-4a was built around, and lets any drift in the modifier-resolution
path be caught by a test that needs no faction-specific fixture.

**Sustainability check** (the CR-10 comparison sheet's anchor row):

```
income at full research                          2,500
structure upkeep (2 Barracks, 1 Factory, 1 Lab)  −  600
                                                 ───────
available for army                               1,900
```

At a mean infantry upkeep of 200, that is **8–9 infantry** against a cap of **10** — the intended
"you can field a little more than you can comfortably keep". Add a Tank (upkeep 500, plus a crew at
200) and the sustainable infantry count drops by three and a half. **Armour is expensive twice: once
in Credits, once in bodies.**

## Edge Cases

- **All three Barracks destroyed:** cap falls to `base_infantry_cap` 4. Units above it survive; production locks until attrition resolves it (PC-6).
- **Research Lab destroyed before Economy III:** income growth stops permanently at whatever tier was completed. Rebuilding the Lab restores access to the remaining tiers; completed tiers are never lost.
- **A Tank built with no free infantry slot:** rejected (BP-NEW-4). The Alliance must plan crew capacity before armour.
- **A Tank whose crew is killed via `targets_crew`:** becomes unpiloted and inert, and is capturable. The Alliance has no answer to this beyond re-crewing — ★ it is the faction's flat, unmitigated exposure to the Independents.
- **Uncrewed Defensive Structure:** blocks its tile, has hp, does not fire. A legal and sometimes deliberate state — build the wall now, crew it when threatened.
- **Fighter facing a ground-only army:** it has no legal targets at all and is dead weight. Correct and intended (UC-4).
- **Artillery adjacent to an enemy:** cannot fire (`min_range` 2). Its counterplay is closing distance.
- **Artillery burst including friendlies:** they take damage (DT-8). UI warns, does not block.
- **Alliance vs Alliance mirror:** fully legal and is the balance floor (CR-5). ★ Any imbalance in a mirror is the map or the first-move advantage, never the faction — which makes the mirror the correct test for map fairness.

## Dependencies

| System | What this faction needs from it | Wave |
|---|---|---|
| **Unit Upkeep** (#15) | All upkeep values | ★ Sprint 6 |
| **Population Cap** (#16) | `base_infantry_cap`, Barracks cap grants | Wave 1 |
| **Base & Production** (#7 rev) | Barracks / Factory / Airfield, per-structure maximums | Wave 1 |
| **AP & Credits Economy** (#3 rev) + **Research** (#8 rev) | Research-driven income | Wave 1 |
| **Unit Classes** (#17) | Vehicles and air | Wave 2 |
| **Transport & Pilots** (#20) | `requires_pilot`, `can_pilot`, `EMBARK` | Wave 2 |
| **Unit Abilities** (#19) | `EMBARK`/`DISEMBARK` only | Wave 2 |
| **Damage Types** (#18) | `BURST` for Artillery and Bomber; Tank's `INCENDIARY` resistance | Wave 3 |
| **Promotion** (#21) | ★ **none** | — |

★ **Wave 1 note:** the Alliance's four infantry, HQ, Barracks, Research Lab and Defensive Structure
are all buildable with only Wave-1 systems. **A playable, complete Alliance-vs-Alliance mirror match
exists before vehicles or air are built at all** — which makes this faction the natural first
target and the cheapest possible proof that the reworked economy resolves matches.

## Tuning Knobs

| Knob | Default | Guidance |
|---|---|---|
| Infantry stat block | as shipped | ★ **Do not touch casually.** These are the only values in the game that have ever been played, and five comparison sheets are keyed to them |
| Artillery `range` / `min_range` | 5 / 2 | ★ The most dangerous number on this sheet. Reduce range before touching the burst |
| Tank `hp` | 22 | Against a 6-attack roster, four clean hits — three for an EMF weapon at the DT-9b default. Above ~26 it stops being answerable by infantry |
| Air `hp` | 6–9 | Deliberately inside the infantry band. Cut this before cutting reach |
| `max_barracks` / `max_factories` / `max_airfields` | 3 / 2 / 1 | ★ Sets the Alliance's map footprint and its fixed upkeep floor |
| Defensive Structure `requires_pilot` | **true** | ★ The "manned" identity. Flipping it to false makes the Alliance strictly better and erases Solar's contrast |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN the Alliance `FactionDef`, THEN every MOD-domain delta is 0 and `effective_X(e, alliance) == base_X(e)` for every domain (the regression anchor) | Logic |
| AC-2 | GIVEN the Alliance roster, THEN its four infantry match `data/units/{scout,trooper,heavy,sniper}.tres` exactly | Config-Data |
| AC-3 | GIVEN a full Alliance build-out, THEN `effective_cap` is exactly 10 | Logic |
| AC-4 | GIVEN all three economy tiers researched, THEN `credit_income` is exactly **2,500** | Logic |
| AC-5 | GIVEN a Tank production order with no free infantry slot for its crew, THEN it is rejected | Integration |
| AC-6 | GIVEN an uncrewed Alliance Defensive Structure, THEN it does not fire and does not counterattack, and still blocks its tile | Integration |
| AC-7 | GIVEN a crewed one, THEN it fires at `attack` 4 / `range` 2 and counterattacks | Integration |
| AC-8 | GIVEN an Alliance Fighter and a board with no `AIR` units, THEN it has no legal targets | Logic |
| AC-9 | GIVEN Artillery and an adjacent enemy, THEN the attack is rejected (`min_range` 2) | Logic |
| AC-10 | GIVEN the Alliance roster, THEN at least one unit has `can_target` including `AIR` (UC-5) | Config-Data |
| AC-11 | GIVEN an Alliance-vs-Alliance mirror, THEN both players' effective values are identical for every domain | Integration |
| AC-12 | GIVEN a 4th Barracks build order, THEN it is rejected with a reason naming `max_barracks` | Integration |
| AC-13 | GIVEN any Alliance unit, THEN `merit` and `rank` are absent or permanently 0 (no promotion) | Logic |
| AC-14 | ★ GIVEN an Alliance-vs-Alliance AI simulation batch, THEN matches resolve on **HQ destruction** rather than the round cap, from both seats (**the PIVOT regression**) | Integration |

## Open Questions

| # | Question | Owner |
|---|---|---|
| DAOQ-1 | ★★ **The faction's name.** User has it as TBD. "Democratic Alliance of Planets" is descriptive but long for a HUD, and the flavour note (*Warhawk Social Democracy*) suggests the tension — a democracy that is nonetheless the militarist baseline — is the interesting part. **Design/naming call — the user's** | user |
| DAOQ-2 | ★ **Is the generalist boring?** The known failure mode of a baseline faction. Current mitigation is breadth (only faction with a full three-class roster) and the Helicopter. **The honest test is whether anyone picks it once the others exist** — if nobody does, it is a control and not a faction, which may be acceptable but should be a decision | user + game-designer |
| DAOQ-3 | **Is the Artillery too strong at range 5 / BURST?** Flagged twice above. Recommend playtesting it before any other Alliance unit | systems-designer |
| DAOQ-4 | **Should the HQ produce Light Infantry only, as today?** Preserved from the shipped design (HQ makes Scout; outposts make the rest). With Barracks capped at 3, an Alliance player who loses all Barracks falls back to Light Infantry only — a reasonable last stand, but worth confirming it is intended rather than inherited | game-designer |
| ~~DAOQ-5~~ | ✅ **RESOLVED 2026-08-24.** The Alliance keeps `can_pilot` on Light and Medium infantry — that *is* the generalist answer. Solar's specialist is made better rather than merely necessary via **`crew_bonus`** (`transport-and-pilots.md` TP-5d, new general machinery): its Pilot grants the crewed vehicle +1 attack. So the Alliance can crew *anything with anyone*, and Solar crews *better but only with specialists*. Both are real positions | ✅ closed |
