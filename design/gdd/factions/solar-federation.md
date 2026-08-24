# Faction — Solar Federation

> **Status**: **DRAFT** (2026-08-24) — Tier 2 of the faction corpus v2.
> **Name**: ★ TBD. Flavour: Technocratic Socialists.
> **Author**: user (direction) + agents · **Baseline**: `factions/democratic-alliance.md` (CR-10)
>
> ★ **The wave-1 asymmetry partner.** Solar is the only faction expressible with almost no new
> systems — no promotion, no damage types, no stealing, and its ground vehicles are transports
> rather than a tank line. **An Alliance-vs-Solar match is the cheapest real test of whether Pillar 4
> works at all**, and Pillar 4 has never been validated in this project.

---

## Overview

The **Solar Federation** fights with **volume and specialisation**. One ordinary soldier — cheap,
fast, unremarkable — backed by three narrow specialists who each do exactly one thing well. Its
economy is smaller than the baseline's, its units are individually weaker, and it fields
substantially more of them, moves them further, and replaces them faster.

Its structures follow the same logic: **autonomous** defences that build in a single turn, cost
almost nothing, need no crew, and barely hurt. Solar holds ground with quantity of presence rather
than quality of position.

What it does **not** have is a tank. Its ground vehicles are armed transports — logistics with a gun
bolted on. Against armour, Solar's answer is infantry, aircraft, or numbers. ★ That hole is
deliberate and is the faction's main structural weakness.

## Player Fantasy

**The feeling: "no single one of them matters, and that is the point."**

The Alliance player protects their Heavy. The Solar player spends three Citizens to achieve the same
thing and does not flinch. The intended feelings:

- **Freedom from attachment.** Losses are routine and replacement is fast. A Solar player should
  feel able to *try things* — trades that would be reckless for anyone else are ordinary here.
- **Coverage.** More bodies moving further means Solar is simply *present* in more places, and
  presence wins map arguments.
- **Specialists as punctuation.** The line is uniform; the Medic, the Volunteer and the Pilot are
  the moments where the player does something clever.
- ★ **The Volunteer is the faction's emotional signature.** A unit whose best use is dying, on
  purpose, at a moment of your choosing. That should feel decisive rather than grim — a Solar player
  spending a Volunteer is *committing*, and it is the one moment their disposable army becomes a
  weapon rather than a resource.

**The failure mode to avoid:** "more units" becoming a chore rather than a strength — a player
shuffling eleven pieces to accomplish what an Alliance player does with six. See the next section;
this was nearly a real problem.

## ★★ Why volume nearly did not work — a finding that outlives this faction

Working Solar's numbers through surfaced a structural interaction that **is not obvious and applies
to every volume-based design in the game**:

> **AP is a flat shared budget. It does not scale with army size.**

So fielding more units does **not** grant more actions. ★ **This finding is what drove the user's
2026-08-24 AP rescale from 10 to 30** (`ap-economy.md` SCALE banner): at 10 AP and the Alliance's
typical `move_cost` of 2, *five* units exhausted the whole turn, and an eleventh, twelfth and
thirteenth would simply have stood still every turn. A faction whose thesis is "more bodies" would
have been handed an army it structurally cannot use.

**At 30 AP the problem is mitigated for everyone**, which is the point of the rescale — but it is
mitigated *proportionally*, so the relative advantage below is unchanged.

**What makes Solar work is that its units are cheap in AP, not just in Credits.** The Citizen
Trooper has `move_cost` **1**, so a 30-AP turn moves *thirty* single tiles of Solar infantry against
*fifteen* of the Alliance's. Volume converts into tempo instead of into idle pieces — and it does so
at any AP budget, because the advantage is a **ratio**.

★ **This is the deciding difference between Solar and the baseline**, more than cost and more than
the cap. It also means the faction's identity is only partly economic — it is really about **AP
efficiency**, which sits directly on Pillar 1. And it gives a concrete rule for the rest of the
corpus:

> **Any faction whose identity is "more units" must also be cheap in AP, or its identity does not
> function.** Recorded here rather than in a faction doc's open questions because the Machinist's
> Union's *opposite* thesis — few, expensive, powerful — is correspondingly safe: a small army has
> AP to spare, and its units can afford to cost 3 AP a move.

## Detailed Design

### Roster — Infantry

★ One line unit and three specialists, per the direction. All `INFANTRY`, `counts_toward_cap = true`,
`damage_type = KINETIC`, `can_target = {INFANTRY, GROUND_VEHICLE}`.

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `move_cost` | `soft_cap` | `upkeep` | Abilities |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| **Citizen Trooper** | The entire line | **300** | 4 | 3 | 2 | ★ **1** | 4 | ★ **100** | — |
| **Pilot** | Crews vehicles, better | **200** | 3 | 1 | 1 | 1 | 3 | **100** | ★ `crew_bonus: attack +1` |
| **Medic** | Sustain | **400** | 4 | 1 | 1 | 1 | 3 | **200** | `REPAIR` |
| **Volunteer** | Delete a position | **300** | 3 | 2 | 1 | 1 | 4 | **100** | `SELF_DESTRUCT` |
| ★ **Lance Team** | **Anti-armour** | **400** | 3 | 6 | 1 | 1 | 3 | **200** | — · `damage_type = EMF` · `can_target = {GROUND_VEHICLE, AIR}` |

> ### ★ The Lance Team — Solar's anti-armour answer (added 2026-08-24, user decision)
>
> Solar was authored with **no answer to armour at all**, and that was flagged as possibly crossing
> from "a strong weakness" into "an unwinnable matchup" — the *"got countered, not outplayed"*
> failure the Alliance document names. The user's call was to grant exactly **one** option.
>
> **It is a hard specialist, not a generalist patch.** `can_target = {GROUND_VEHICLE, AIR}` means it
> **cannot shoot infantry at all** — against an infantry army it is a 400-Credit body that does
> nothing. At range 1 it must stand next to a tank to fire, with 3 hp. It answers armour by being
> *brought deliberately*, and it dies for it.
>
> **It uses EMF** (`damage-types.md` DT-9b), so against a vehicle's default −2 EMF resistance its
> attack of 6 lands as **8** — three hits on an Alliance Tank rather than four. ★ It also works
> before damage types ship: with EMF inert in waves 1–2 it simply deals 6, which is playable, and
> **its base attack should be re-checked when DT lands** (SFOQ-6).
>
> **Why this is the right shape for Solar specifically:** it is *another specialist*, which is the
> faction's stated identity (*"one standard infantry unit with economical stats and multiple
> specialists"*). It costs a cap slot like everything else, so bringing anti-armour means bringing
> fewer Citizens. And it keeps the faction's real weakness intact — Solar still has no armour of its
> own and still cannot absorb a hit.

**Against the baseline's line unit** (Alliance Medium Infantry: cost 400, hp 6, atk 3, rng 2, move 2,
upkeep 200):

> The Citizen Trooper is **25% cheaper, half the upkeep, twice the mobility, and 33% more fragile.**
> Crucially, at 4 hp it dies to a single Alliance Heavy hit (attack 5) where the Trooper survives —
> so Solar's line does not merely trade *slightly* worse, it loses specific breakpoints. That is the
> right shape: Solar wins on tempo and count, and loses every straight exchange.

**★ `can_pilot` is false on every Solar unit except the Pilot.** Unlike the Alliance — where any
Light or Medium infantry can drive — Solar *must* build specialists to crew anything. That is a real
constraint (a vehicle needs a 200-Credit Pilot and a cap slot before it functions) paid for by
`crew_bonus`: a Solar-crewed vehicle hits harder than the same vehicle would under anyone else.

### Roster — Ground Vehicles

★ **"Primarily transports with manned guns"** — Solar has **no tank.** Both vehicles carry infantry
and both have a weapon secondary to that job. All `requires_pilot = true`,
`counts_toward_cap = false` (crew consumes a slot, PC-8), `transport_accepts = {INFANTRY}`.

| Unit | `cost` | `hp` | `atk` | `rng` | `move_cost` | `capacity` | `upkeep` |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Gun Truck** | **900** | 12 | 4 | 1 | 2 | **2** | **300** |
| **Armoured Transport** | **1,300** | 18 | 3 | 1 | 2 | **4** | **400** |

> ★ **The Armoured Transport's capacity of 4 is the largest in the game** and is Solar's real
> vehicle identity: it moves a third of a Solar army in one piece. That is powerful and it is
> *fragile by design* — TP-4 means destroying it kills everything inside. **A Solar player who loads
> four Citizens into one transport has put a third of their army in a single 18-hp box.**
> Deliberately a high-stakes option rather than a free logistics upgrade.
>
> **No anti-armour ground option.** Against an Alliance Tank (22 hp, attack 7), Solar's ground answer
> is to swarm it or to bring the Gunship. This is the faction's clearest hole.

### Roster — Air

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `upkeep` | `can_target` |
|---|---|---:|---:|---:|---:|---:|---|
| **Interceptor** | ★ General-purpose, weak at all of it | **1,100** | 6 | **4** | 2 | **400** | `{INFANTRY, GROUND_VEHICLE, AIR}` |
| **Gunship** | Manned gun helicopter | **1,200** | 8 | 5 | 1 | **400** | `{INFANTRY, GROUND_VEHICLE}` |
| **Paratrooper Transport** | Reach | **1,300** | 7 | — | — | **400** | `{}` — unarmed. `capacity` 3, carries `PARADROP` |

> The **Interceptor** is the direction's *"general purpose fighter with weak all around stats"* read
> literally: it can hit anything, and its attack of 4 means it kills almost nothing outright. Against
> the Alliance Fighter (attack 6, air-only) it loses a straight dogfight — but the Alliance Fighter
> cannot touch ground, and the Interceptor can. **Flexibility bought with effectiveness**, which is
> the faction in one unit.
>
> The **Paratrooper Transport** is Solar's tempo weapon: `PARADROP` places a carried unit on any
> empty tile within 3, ignoring terrain and pathing entirely. Combined with `move_cost` 1 infantry,
> Solar can put pressure almost anywhere on the board within a turn.

### Structures

| Structure | Produces | Max | `cost` | `build_time` | `hp` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| **HQ** | Citizen Trooper | 1 | — | — | 40 | **0** | `defense` 2 |
| **Barracks** | `{INFANTRY}` | ★ **4** | **600** | 2 | 12 | **100** | +2 cap each |
| **Factory** | `{GROUND_VEHICLE}` | 2 | **1,000** | 3 | 14 | **200** | |
| **Airfield** | `{AIR}` | 1 | **1,200** | 3 | 12 | **200** | |
| **Research Lab** | — | 1 | **800** | 2 | 10 | **200** | |
| ★ **Autonomous Defence Node** | — | ★ **5** | ★ **300** | ★ **1** | 8 | **100** | `attack` **2**, `range` 2, `requires_pilot` **false**, `can_counterattack`. ★ `can_target` includes **`AIR`** |

**★ The Defence Node is the direction's *"cheap autonomous defence structures that build quickly but
have lower damage"*, and it is the sharpest contrast in the corpus.** Against the Alliance's manned
Defensive Structure (cost 5, build 2, attack 4, **requires a crew**):

| | Alliance | Solar |
|---|---|---|
| Cost | 500 | **300** |
| Build time | 2 turns | **1 turn** |
| Attack | **4** | 2 |
| Crew required | ★ **yes — an infantry slot** | ★ **no** |
| Max | 3 | **5** |

> Solar can blanket a position in five nodes for 1,500 Credits and five turns, **spending no army
> capacity at all**, and they shoot at aircraft. The Alliance's are twice as lethal but each one
> takes a soldier off the line. That is a genuine strategic difference rather than a stat tweak, and
> it is the clearest evidence in the corpus that the manned/autonomous axis was worth building.
>
> ★ **This is also the row most likely to be over-tuned.** Cheap, fast, crewless, numerous *and*
> anti-air is a lot of "yes" in one structure. Its guards are 8 hp and an attack of 2 — it dies to
> one Sniper shot and barely scratches a Tank. **Watch it in playtest before anything else here.**

### Economy and cap

| | Solar | Alliance | Δ |
|---|---:|---:|---|
| `BASE_INCOME` | **800** | 1,000 | ★ −200 (intercept) |
| Economy tier bonus | **+400** each | +500 each | ★ −100 (slope) |
| Tier costs | 1,000 / 2,000 / 3,500 | same | — |
| **Income ceiling** | ★ **2,000** | 2,500 | **−20%** |
| `base_infantry_cap` | **5** | 4 | +1 |
| `max_barracks` | ★ **4** | 3 | +1 |
| **Infantry ceiling** | ★ **13** | 10 | **+30%** |
| Tech tree | full access, base cost | same | — |
| Promotion | none | none | — |

**Both income levers are used deliberately** (`faction-identity.md` D4): the **intercept** (−200 on
`BASE_INCOME`) makes Solar poorer from turn 1 and never stops; the **slope** (−100 per tier) means the
gap *widens* as both players research, so Solar's disadvantage compounds exactly as the Alliance's
economy matures. Solar wants the game decided before that gap opens.

## Formulas

Solar introduces no new formulas. Its `FactionDef` carries:

```
Δ_base_income      = −200
Δ_econ_tier_bonus  = −100      (per tier; ceiling 2,000 vs baseline 2,500)
Δ_base_cap         = +1
Δ_max_barracks     = +1
Δ_max_defensive    = +2
Δ_upkeep_rate      =  0        ★ NOT a rate delta — Solar's low upkeep is authored per-unit (D9-own)
```

> ★ Note the last line. It would be tempting to express "Solar's stuff is cheap to keep" as a global
> `Δ_upkeep_rate`, but that would apply to its *structures* too and make its Defence Node spam free.
> Authoring low upkeep on the **units** and leaving structures at baseline is deliberate.

### CR-10 comparison sheet — Solar vs the Democratic Alliance

*Required before this faction may ship. Computed at a fully-researched economy with a realistic
build (2 Barracks, 1 Factory, 1 Lab).*

| Axis | Alliance | Solar | Winner |
|---|---:|---:|---|
| Income ceiling | 2,500 | 2,000 | **Alliance** |
| Credits for army after structures | 1,900 | 1,400 | **Alliance** |
| Mean infantry upkeep | ~200 | ~125 | **Solar** |
| **Sustainable infantry** | **~9** | ★ **~11** | **Solar** |
| Infantry ceiling (cap) | 10 | 13 | **Solar** |
| Cost per hp (line unit) | 67 | 75 | **Alliance** |
| Cost per attack (line unit) | 133 | 100 | **Solar** |
| **Army attack total** (sustainable) | ~34 | ~33 | ≈ tie |
| **Army hp total** (sustainable) | ~50 | ~44 | **Alliance** |
| Tiles moved per turn (30 AP) | ~15 | ★ **~30** | **Solar** |
| Anti-armour ground option | Tank (atk 7) | ★ Lance Team (EMF, effective 8 — but cannot touch infantry) | **Alliance**, narrowly |
| Defensive coverage per Credit | low | ★ **high** | **Solar** |
| Cheap anti-air | Fighter (1,200) | ★ Defence Node (300) | **Solar** |
| Single-unit peak damage | Artillery 8 | Gunship 5 | **Alliance** |

**Verdict against CR-10.2** (*"a faction must be unable to win the comparison on every axis at
once"*): **PASS.** Solar loses decisively on economy, army durability, anti-armour and peak damage;
it wins on count, tempo, defensive coverage and cheap anti-air. ★ **Re-checked after the Lance Team was added:** the anti-armour axis moves from a Solar *hole* to a Solar *narrow answer*, which does not flip any other row — the Lance Team cannot shoot infantry, so it buys no general strength. The two armies land at near-identical
total attack from opposite directions, which is the shape a good matchup wants.

★ **The axis to watch is "tiles moved per turn."** Doubling a faction's effective board mobility is a
very large advantage and it is not intuitively priced. If Solar dominates in playtest, `move_cost`
is the first dial to touch — **before** cost, upkeep or the cap.

## Edge Cases

- **All Pilots dead:** every Solar vehicle is inert until a new Pilot is built and walks to it. ★ A real faction-specific vulnerability the Alliance does not share, and a prime `CAPTURE_VEHICLE` window.
- **Armoured Transport destroyed carrying 4:** all four die (TP-4). A third of a Solar army in one hit.
- **Volunteer detonating adjacent to friendlies:** they take damage (DT-8). With Solar's high unit density this is a *frequent* consideration, not a rare one.
- **Medic repairing a Medic:** legal. `REPAIR` cannot target self, but two Medics can sustain each other — ★ watch for a stalling pair (`unit-abilities.md` ABOQ-3, which flags healing against a game already struggling to resolve).
- **Solar at 13 infantry with 30 AP:** ★ at `move_cost` 1 a Solar player *can* now move every unit and still have AP for attacks — which is exactly what the AP rescale was for. The constraint that remains is Credits and the cap, not action budget.
- **Defence Node vs an Alliance Tank:** attack 2 against 22 hp and `INCENDIARY` resistance does essentially nothing. Solar's nodes hold against infantry and aircraft, not armour.
- **Solar vs Solar mirror:** legal. Two swarms of fast, fragile units on a 12×10 board — ★ likely the fastest-resolving matchup in the game, and worth measuring for exactly that reason.
- **Paradrop onto a tile adjacent to the enemy HQ:** legal and is Solar's most aggressive line. Bounded by the transport surviving to get within 3.

## Dependencies

Identical to the Alliance's, **minus** damage types (Solar has no resistances and no `LINE` attacks),
**plus**:

| System | What Solar needs | Wave |
|---|---|---|
| **Unit Abilities** (#19) | ★ `REPAIR`, `SELF_DESTRUCT`, `PARADROP`, `EMBARK`/`DISEMBARK` | Wave 2 |
| **Transport & Pilots** (#20) | ★ `crew_bonus` (TP-5d), `can_pilot`, large-capacity transports | Wave 2 |

★ **Wave-1 subset:** Citizen Trooper, Volunteer, Barracks, Research Lab and the Autonomous Defence
Node need **no** Tier-1 system beyond upkeep and the population cap — the Volunteer needs
`SELF_DESTRUCT`, which is one catalogue entry. **A reduced Alliance-vs-Solar match is playable in
wave 1**, and that match is the first real Pillar-4 evidence this project has ever had.

## Tuning Knobs

| Knob | Default | Guidance |
|---|---|---|
| Citizen Trooper `move_cost` | ★ **1** | **The faction's single most important number.** It is what converts volume into tempo. Raising it to 2 does not weaken Solar slightly — it *deletes the faction's thesis* |
| Citizen Trooper `hp` | 4 | Sits below the Alliance Heavy's attack of 5, so it dies in one hit where the Trooper survives. That breakpoint is intentional |
| Defence Node cost / build / max | 3 / 1 / 5 | ★ The most likely over-tune on this sheet. Reduce `max` before raising cost — cheap-and-fast is the identity, *numerous* is the risk |
| `Δ_base_income` / `Δ_econ_tier_bonus` | −2 / −1 | The intercept/slope pair. Together they set how urgently Solar must win |
| Infantry ceiling | 13 | Above ~15 the player cannot meaningfully command the army even at `move_cost` 1 |
| Pilot `crew_bonus` | +1 attack | ★ Keep at +1 (TP-5d). Larger and unpiloted vehicles stop being worth fielding |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN Solar at full research, THEN `credit_income` is exactly **2,000** | Logic |
| AC-2 | GIVEN a full Solar build-out, THEN `effective_cap` is exactly **13** | Logic |
| AC-3 | GIVEN a Solar Citizen Trooper and a full 30-AP turn on open terrain, THEN 30 single-tile moves are affordable | Integration |
| AC-4 | GIVEN any Solar unit other than the Pilot, THEN `can_pilot` is false and `EMBARK` into a `requires_pilot` vehicle is rejected | Integration |
| AC-5 | GIVEN a Solar Pilot crewing a Gun Truck, THEN the vehicle's `effective_attack` is 5 (4 + `crew_bonus` 1) | Logic |
| AC-6 | GIVEN that Pilot dies or disembarks, THEN the vehicle's `effective_attack` returns to 4 and it becomes inert | Integration |
| AC-7 | GIVEN a Solar Armoured Transport carrying 4 units is destroyed, THEN all 4 die and 4 cap slots free | Integration |
| AC-8 | GIVEN a Solar Autonomous Defence Node with no crew, THEN it fires at `attack` 2 (it never requires one) | Integration |
| AC-9 | GIVEN that Node and an adjacent `AIR` unit, THEN the aircraft is a legal target | Integration |
| AC-10 | GIVEN a 6th Defence Node build order, THEN it is rejected naming `max_defensive` | Integration |
| AC-11 | GIVEN a Solar Volunteer detonating beside friendly Citizens, THEN the friendlies take damage | Integration |
| AC-12 | GIVEN a Solar Lance Team, THEN infantry never appear in its legal targets at any range, and a `GROUND_VEHICLE` at range 1 does | Integration |
| AC-13 | GIVEN the Solar roster, THEN at least one unit or structure targets `AIR` (UC-5) | Config-Data |
| AC-14 | GIVEN any Solar unit, THEN `merit`/`rank` are absent or permanently 0 | Logic |
| AC-15 | ★ GIVEN an Alliance-vs-Solar AI batch, THEN neither faction wins more than **65%** across both seats (the CR-10 playtest gate) | Integration |

## Open Questions

| # | Question | Owner |
|---|---|---|
| SFOQ-1 | ★★ **Is doubled board mobility priced correctly?** `move_cost` 1 across a whole roster is the largest single advantage granted anywhere in the corpus, and it is the mechanism that makes the faction work. It could equally be the thing that makes it dominant. **Measure it first** | systems-designer |
| SFOQ-2 | ★ **Can the AI play Solar at all?** Solar needs `EMBARK`, `PARADROP`, `REPAIR` and `SELF_DESTRUCT` used well — multi-turn plans against a single-action greedy AI (`transport-and-pilots.md` TPOQ-4, `faction-identity.md` OQ-15). **Solar may be the faction that forces the AI-planning work**, which is an argument for doing it early while it is cheap |
| SFOQ-3 | **Does the Medic pair stall matches?** Two Medics sustaining each other is a soft lock, in a game whose PIVOT verdict was *"matches never resolve"*. `REPAIR_AMOUNT` must be checked against the damage band with Solar specifically in mind | economy-designer |
| ~~SFOQ-4~~ | ✅ **RESOLVED 2026-08-24 (user): grant exactly one anti-armour option.** The **Lance Team** — EMF, effective 8 vs vehicles, range 1, 3 hp, and **cannot target infantry at all.** A hard specialist rather than a generalist patch: it must be brought deliberately, it costs a cap slot, and against an infantry army it does nothing. Solar still has no armour of its own | ✅ closed |
| SFOQ-6 | ★ **Re-check the Lance Team when damage types ship.** It is authored at attack 6 so it is playable in waves 1–2 with EMF inert. Once DT-9b's default −2 vehicle resistance lands, its effective damage becomes 8 — a 33% jump that arrives silently with an unrelated system. Recommend dropping the base to 4–5 at that point, and adding a regression that pins its effective damage against a standard Tank across both states | systems-designer |
| SFOQ-5 | ★ **The name.** *"Solar Federation"* and *"Technocratic Socialists"* pull in different directions — one is geographic, the other ideological. The faction's mechanics read as **collective, industrial, disposable**, which the ideological reading serves better. **Naming call — the user's** | user |
