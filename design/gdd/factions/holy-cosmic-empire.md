# Faction — Holy Cosmic Empire

> **Status**: **DRAFT** (2026-08-24) — Tier 2 of the faction corpus v2. **The last of the six.**
> **Name**: ★ TBD. Flavour: Theocratic Monarchy.
> **Author**: user (direction) + agents · **Baseline**: `factions/democratic-alliance.md` (CR-10)
>
> ★★ **The only faction that promotes** (`promotion-veterancy.md` PV-8, user decision 2026-08-24).
> Every merit hook, rank display and rank-aware AI valuation exists for this faction alone, which is
> why promotion should be the **last** Tier-1 system built.
>
> ★ **Also the third faction with a late-game curve**, after the Machinist's Union and (weakly) the
> Alliance. Keeping it distinct from the Union was a design requirement — see § "Held apart from
> the Union".

---

## Overview

The **Holy Cosmic Empire** is an army that **appreciates**. Its units begin ordinary — slightly
below baseline, in fact — and grow permanently stronger by fighting. A Levy that survives its first
two kills is better than anything the Alliance can produce; one that survives eleven is the single
most dangerous unit in the game.

Its vehicles are built around **defense** rather than hit points — they reduce incoming damage
instead of absorbing more of it — and a **linear doctrine tech tree** raises the whole vehicle line
in fixed steps.

And all of it is **conditional**. The Empire's ranks are sustained by its **Cathedral**. Lose that
building and the army does not merely stop improving; it starts **falling back down the ladder, one
rank per turn**, until the Cathedral is rebuilt. No other faction can be *un-developed* by an attack.

Its thesis: **invest, compound, and defend the thing that makes it all real.**

## Player Fantasy

**The feeling: "this one has been with me since the first turn."**

- **★ Attachment, which no other faction offers.** A veteran is not an asset, it is a *character*.
  Players who name a unit are playing the Empire correctly.
- **Investment made visible.** Every fight a unit survives makes it better, so the player is always
  building something — not on the board, but *in* a specific piece.
- **Loss that genuinely lands.** Losing a rank-3 Champion should be the worst moment available in
  the game. That ache is the direction's *"makes losses more impactful"* and it must not be softened.
- **★ Dread, on purpose.** An Empire player watching an enemy move toward their Cathedral is
  experiencing something no other faction can feel: the threat is not to their army's *life* but to
  everything their army has *become*.
- **Hierarchy as texture.** The roster spans the ladder — a Levy starts at the bottom, a Knight
  starts already promoted. Rank is the faction's organising fiction and its central mechanic at once.

**The failure mode to avoid:** promotion as a snowball. A unit that gets stronger by winning is the
classic rich-get-richer shape, and this project has *just been measured* failing at exactly that in
its economy. The guards are the escalating merit thresholds, the hard rank cap, and — uniquely —
that the whole curve is **reversible by an attack**.

## Detailed Design

### Roster — Infantry

★ **The hierarchy is literal.** Units are produced at different starting ranks via `starting_merit`,
using the existing merit machinery rather than any new rule.

| Unit | Role | `cost` | `hp` | `atk` | `rng` | `move` | `upkeep` | `starting_merit` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| **Levy** | The bottom of the ladder | **300** | 5 | **2** | 2 | 2 | **200** | 0 *(rank 0)* | ★ Below baseline at rank 0 · `can_pilot` ✔ |
| **Knight** | Enters already promoted | **700** | 7 | 4 | 2 | 2 | **250** | ★ **6** *(rank 1)* | `can_pilot` ✔ |
| **Confessor** | Sustain and enable | **600** | 4 | 2 | 1 | 2 | **250** | 0 | `REPAIR`, `SPOT` |
| **Inquisitor** | Reach | **700** | 4 | 6 | 3 | 2 | **250** | 0 | `DEMOLISH` |

> ### ★★ The Levy is the faction in one unit
>
> **Attack 2 at rank 0** — the weakest line unit in the game, weaker than a Protectorate Servitor.
> It costs 300 and it loses almost every opening exchange.
>
> Then it promotes:
>
> | Rank | Merit | `atk` | `hp` | `rng` | Roughly |
> |---|---:|---:|---:|---:|---|
> | 0 | 0 | **2** | 5 | 2 | worse than anything |
> | 1 | 6 | **3** | 5 | 2 | baseline line infantry |
> | 2 | 16 | **3** | **7** | 2 | tougher than an Alliance Trooper |
> | 3 | 32 | ★ **4** | ★ **9** | ★ **3** | ★ a Heavy's body with a Sniper's reach, on a 300-Credit unit |
>
> ★ **The survivability half matters more than the attack half**, exactly as
> `promotion-veterancy.md` found when its example was rescaled: +4 hp on a 5-hp body is an 80%
> increase and takes the unit from *"dies to one Sniper hit"* to *"survives one"*. **An Empire
> veteran's real power is that it keeps existing**, which is also why it accumulates more merit —
> the compounding is in survival, not damage.
>
> **A Knight at `starting_merit` 6 enters play at rank 1**, already a competent soldier for 700
> Credits, and needs only 10 more merit to reach rank 2. It is how an Empire player buys progress
> instead of earning it — at more than double the price.

### Roster — Ground Vehicles

★ **Built on `defense`, not hit points.** This is a deliberately different survivability axis from
every other faction's: `combat-resolution.md`'s formula subtracts `defense` from incoming damage, so
an Empire vehicle takes *less per hit* rather than surviving *more hits*.

| Unit | Role | `cost` | `hp` | ★ `def` | `atk` | `rng` | `move` | `upkeep` | Notes |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| **Aegis Walker** | Line vehicle | **1,400** | 18 | ★ **3** | 5 | 2 | 2 | **500** | |
| **Cathedral Tank** | The heavy | **1,900** | 22 | ★ **3** | 6 | 2 | 2 | **600** | |
| **Reliquary** | Transport | **1,200** | 18 | ★ **2** | — | — | 2 | **400** | `capacity` 3, unarmed |

> ### ★★ High `defense` hard-counters low-attack armies — a real cross-faction hazard
>
> `damage = max(MIN_DAMAGE, attack − cover − defense − resistance)`, and `MIN_DAMAGE` is **1**.
> Against an Aegis Walker at `defense` 3:
>
> | Attacker | `attack` | Damage dealt |
> |---|---:|---:|
> | Solar Citizen Trooper | 3 | ★ **1** (floored) |
> | Protectorate Servitor | 2 | ★ **1** (floored) |
> | Alliance Medium Infantry | 3 | ★ **1** (floored) |
> | Alliance Heavy | 5 | 2 |
> | Alliance Sniper | 6 | 3 |
> | Solar Lance Team (EMF) | 6 → **8** | **5** |
> | Protectorate Lance Tank (EMF) | 8 → **10** | **7** |
>
> ★★ **An 18-hp Walker takes eighteen hits from a Solar Citizen.** That is not a tilt, it is a
> wall — and it is exactly the *"got countered, not outplayed"* failure the Alliance document names.
> **This is the single most dangerous interaction in the corpus** and it exists because of the
> `MIN_DAMAGE` floor rather than any number chosen here.
>
> **Why it is nonetheless acceptable, and what makes it so:** every faction has an EMF answer, and
> EMF bypasses the problem entirely — the vehicle's own −2 machine default (DT-9b) turns a 6-attack
> specialist into 8 effective, which cuts through `defense` 3 for a real 5. ★ **The counter to
> Empire armour is anti-armour**, which is legible, universally available, and precisely what a
> composition puzzle should look like.
>
> ⚠ **But it makes the EMF specialist mandatory rather than optional in this matchup**, and a Solar
> or Union player who did not bring one has no answer at all. **Flagged as HCEOQ-2 and as a
> first-priority item for CR-10's matchup grid.** If it proves too sharp, the fix is `defense` 2,
> not a change to `MIN_DAMAGE` — that floor is load-bearing everywhere else.

### Roster — Air

| Unit | Role | `cost` | `hp` | `def` | `atk` | `rng` | `upkeep` | `can_target` |
|---|---|---:|---:|---:|---:|---:|---:|---|
| **Seraph** | Ground attack | **1,400** | 7 | ★ **2** | 6 | 2 | **500** | `{INFANTRY, GROUND_VEHICLE}` |
| **Dominion** | Air superiority | **1,500** | 7 | ★ **2** | 7 | 2 | **500** | ★ `{AIR}` **only** |

★ Defense 2 on aircraft is significant against the 4–8 air-attack band, and it is the Empire's
answer to having no numerical advantage anywhere.

### ★ The linear doctrine tech tree

The direction's *"power increasing based on the linear tech tree"*. **Strictly sequential** — each
requires the previous — which is what makes it *linear* rather than a menu.

| Tech | `research_cost` | `ap_surcharge` | `time` | Effect |
|---|---:|---:|---:|---|
| **Doctrine I** | 1,200 | 1 | 2 | +1 `attack` to all Empire **vehicles** |
| **Doctrine II** | 2,200 | 1 | 3 | +1 `defense` to all Empire **vehicles** |
| **Doctrine III** | 3,600 | 2 | 3 | +1 `attack`, +1 `defense` to all Empire **vehicles** |

Full base tech access as well (Attack, Defense, Economy I–III). ★ A fully-doctrined Cathedral Tank
is **attack 8, defense 5** — at which point only EMF and the heaviest guns in the game hurt it at
all. It is also 7,000 Credits of research away, which against a 30-round match is most of a game.

> **Doctrine bonuses are permanent and survive the Cathedral's destruction.** They are researched
> knowledge, not sustained privilege. ★ Only **ranks** decay — see below. Keeping these two apart is
> deliberate: one vulnerability mechanic, clearly legible, rather than two overlapping ones.

### ★★ The Cathedral, and `rank_requires_support`

The Empire's Research Lab is its **Cathedral**, and it does one extra job: it sustains the army's
ranks (`promotion-veterancy.md` PV-7).

**If no completed, living Cathedral exists at the Empire's start of turn, every Empire unit drops
one rank.** Every turn. Until it is rebuilt.

- Rank floors at 0. **No unit is destroyed** by this.
- ★ **Merit is retained.** Rebuilding the Cathedral lets units re-promote instantly to whatever
  rank their merit supports. Recovery is real, not a restart.
- `rank_requires_support = true` is a **faction-declared property**, and the Empire is the only
  faction that declares it. Opting into a vulnerability in exchange for power is CR-9 working.

> ### ★ This is what makes the Empire's tech vulnerability distinct — and it resolves RTOQ-NEW-1
>
> When income moved to research, **every** faction became vulnerable to losing its Research Lab, and
> the Empire's stated *"highly vulnerable to tech base disruption"* stopped being distinguishing.
>
> The resolution: **everyone loses income growth; only the Empire loses what it has already
> built.** Killing an Alliance Lab caps their future. Killing an Empire Cathedral **un-develops
> their present** — a rank-3 Champion becomes a rank-0 Levy in three turns, and every unit does it
> at once. ★ It is the only mechanism in the game that takes value *back*, and it is why the Empire
> plays the whole match with something to protect.

### Structures and economy

| | Empire | Alliance | Δ |
|---|---:|---:|---|
| `BASE_INCOME` / tiers / ceiling | 1,000 / +500 / **2,500** | same | ★ none |
| `base_infantry_cap` | **4** | 4 | — |
| `max_barracks` | **3** | 3 | — |
| **Infantry ceiling** | **10** | 10 | — |
| `max_factories` / `max_airfields` | 2 / 1 | 2 / 1 | — |
| `max_defensive` | 3 | 3 | — |
| ★ **Cathedral** (Research Lab) | 1 · **900** · `hp` 12 | 1 · 800 · `hp` 10 | ★ dearer and tougher |

★ **Everything except the Cathedral is exactly baseline.** Deliberate: the Empire already carries
two large moving parts (promotion and doctrine) plus a unique failure mode, and a third variable in
its economy or cap would make it impossible to reason about. **Its identity is entirely in what
happens to its units over time.**

The Cathedral is dearer (900) and tougher (12 hp) than a normal Lab because the Empire cannot afford
to lose it — a small mitigation, not a solution.

## ★ Held apart from the Machinist's Union

Both are late-game factions. The separation:

| | Machinist's Union | Holy Cosmic Empire |
|---|---|---|
| What grows | ★ **The economy** — income compounds | ★ **The units** — the same pieces get better |
| Curve driver | Research tiers (slope lever) | Merit earned by fighting |
| How to reach it | Survive and expand | ★ **Fight** — you cannot promote by building |
| ★ **Is the curve reversible?** | ★ **No** — research is permanent | ★★ **Yes** — kill the Cathedral |
| Early game | very weak | ordinary-to-weak |
| Bounded by | time | merit thresholds and the rank cap |
| Vulnerability | being rushed | ★ losing one specific building |

**Verdict: distinct, and in a way that matters at the table.** The Union's late game is *inevitable*
if it survives; the Empire's is *contested every turn it holds*. ★ And they push in opposite
directions on tempo — the Union wants to avoid fighting early, the Empire **must** fight to grow at
all. An Empire that turtles is an Empire that never promotes.

## Formulas

No new formulas. `FactionDef`:

```
Δ_base_income = 0 · Δ_econ_tier_bonus = 0 · Δ_base_cap = 0 · Δ_max_barracks = 0
Δ_research_lab_cost = +100 · Δ_research_lab_hp = +2
rank_requires_support = true                    ★ the only faction that declares it
promotion_enabled     = true                    ★ the only faction that declares it
```

### CR-10 comparison sheet — Empire vs the Democratic Alliance

*Two columns, as with the Union. **Rank 0** = a fresh Empire army. **Rank 2** = a developed one
(~5 kills per unit) with Doctrines I–II. Income 2,500, realistic build, 1,900/turn for army.*

| Axis | Alliance | Empire **rank 0** | Empire **rank 2** | Winner |
|---|---:|---:|---:|---|
| Income ceiling | 2,500 | 2,500 | 2,500 | tie |
| Sustainable units | ~9 | ~8 | ~8 | Alliance, slightly |
| Infantry ceiling | 10 | 10 | 10 | tie |
| Line unit `attack` | 3 | ★ **2** | 3 | **Alliance** |
| Line unit `hp` | 6 | 5 | ★ **7** | **split** |
| Best infantry | Heavy 5/10 | Knight 4/7 | ★ Champion Levy 4/9 **rng 3** | **split** |
| Vehicle survivability | 22 hp | 18 hp + ★ **def 3** | 18 hp + ★ **def 4** | ★ **Empire, decisively** |
| Vulnerability to low-attack armies | normal | ★★ **near-immune** | ★★ **immune** | ★ **Empire, decisively** |
| Vulnerability to EMF | Tank −2 | −2 | −2 | tie |
| ★ **Value that can be taken back** | none | ★★ **all accumulated rank** | ★★ **all of it** | ★ **Alliance, decisively** |
| Must fight to develop | no | ★ **yes** | yes | **Alliance** |
| Peak single unit | Artillery 8 | — | ★ Doctrine-III Tank 8/def 5 | **Empire** |

**Verdict against CR-10.2: PASS.** The Empire is behind at rank 0 on nearly every row, ahead at
rank 2 on durability and peak quality, and **carries a category of risk no other faction has** — an
opponent who reaches the Cathedral undoes the entire investment.

> ★ **The honest concern is not the sheet, it is the shape.** A faction that grows by fighting and
> can be reset by one building has **higher variance than any other in the corpus except the
> Independents**. It will produce both the best and the worst matches. HCEOQ-1.

## Edge Cases

- **Cathedral destroyed with rank-3 units on the board:** every unit drops to rank 2 next turn, rank 1 the turn after, rank 0 the turn after that. ★ Three turns to undo a whole match's investment.
- **Cathedral rebuilt after decay:** merit was retained (PV-7), so every unit re-promotes instantly to its merit's rank. Recovery is immediate and complete.
- **Cathedral destroyed and rebuilt in the same turn:** support is evaluated once at start of turn; rebuilding later stops the *next* drop, not this one.
- **A Knight killed at rank 1 before earning anything:** 700 Credits lost with nothing accumulated. ★ Buying rank is the *risky* purchase, not the safe one.
- **An Empire unit crewing a vehicle:** legal (Levy and Knight `can_pilot`). ★ **It earns no merit while crewing** — the vehicle fights, not the pilot — so putting a promising veteran in a tank stops its growth. A real and interesting cost.
- **A promoted unit captured by an Independents Pirate:** rank transfers with the unit (`promotion-veterancy.md`). ★ Stealing an Empire veteran is the single biggest swing available in the game.
- **A captured Empire unit under a non-Empire owner:** it keeps its rank but cannot promote further, and does not decay (the new owner has no Cathedral requirement). ★ Worth an explicit test — see AC-14.
- **Empire vehicle vs an all-Solar-Citizen army:** 1 damage per hit. Solar must bring Lance Teams; this is the matchup HCEOQ-2 exists for.
- **Doctrine III with no Cathedral:** the doctrine bonuses persist; only ranks decay. Deliberate.
- **Empire mirror:** two armies promoting off each other, both with a Cathedral to protect. ★ Likely the corpus's most *dramatic* matchup, and the one where a single successful raid decides everything.

## Dependencies

| System | What this faction needs | Wave |
|---|---|---|
| **Unit Upkeep** (#15) | baseline | Sprint 6 |
| **Population Cap** (#16) | baseline | Wave 1 |
| **Unit Classes** (#17) | vehicles, air | Wave 2 |
| **Transport & Pilots** (#20) | `requires_pilot`, `can_pilot` | Wave 2 |
| **Unit Abilities** (#19) | `REPAIR`, `SPOT`, `DEMOLISH` | Wave 2 |
| **Damage Types** (#18) | EMF defaults (as a *victim*) | Wave 3 |
| ★★ **Promotion & Veterancy** (#21) | ★★ **Hard blocker — the entire faction.** Merit, ranks, `starting_merit`, and PV-7 support decay | ★ **Wave 4** |
| **Research** (#8 rev) | The linear doctrine branch | Wave 3 |
| **Combat Resolution** (#6) | ★ `defense` on vehicles — the field exists and is Approved but **has never shipped a non-zero value on a unit** | Wave 2 |

★ **Last faction to be buildable**, and the only one gated on a system built solely for it. ★ Also
note the last row: `defense` is an Approved field that no shipped entity uses except structures.
**The Empire is the first real exercise of it**, and `combat-resolution.md`'s floor-lock analysis
should be re-read before its values are trusted.

## Tuning Knobs

| Knob | Default | Guidance |
|---|---|---|
| ★ Vehicle `defense` | **3** | ★★ **The most dangerous number in the corpus.** At 3 it floors most infantry to `MIN_DAMAGE`. Reduce to 2 before touching anything else if the matchup grid shows a hard counter |
| Levy `attack` at rank 0 | **2** | Deliberately the weakest in the game. Raising it removes the faction's growth arc |
| `RANK_THRESHOLD` | `[0, 6, 16, 32]` | ★ Owned by `promotion-veterancy.md`, but the Empire is the only consumer — effectively an Empire dial. Escalation is the anti-snowball guard |
| Knight `starting_merit` | 6 | Buying rank 1. Higher makes the purchase-versus-earn choice more lopsided |
| Cathedral `hp` / `cost` | 12 / 900 | ★ How hard the faction's single point of failure is to reach |
| Rank decay rate | 1 rank/turn | ★ Three turns to undo everything. At 2/turn the vulnerability becomes fatal rather than severe |
| Doctrine costs | 1,200 / 2,200 / 3,600 | 7,000 total — deliberately most of a match |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a newly produced Knight, THEN its `merit` is 6 and its rank is 1 | Logic |
| AC-2 | GIVEN a newly produced Levy, THEN its rank is 0 and `effective_attack` is 2 | Logic |
| AC-3 | GIVEN a Levy reaching 32 merit, THEN `effective_attack` 4, `effective_max_hp` 9, `effective_attack_range` 3 | Logic |
| AC-4 | GIVEN an Empire player with no living completed Cathedral at start of turn, THEN every Empire unit drops exactly one rank and retains its merit | Integration |
| AC-5 | GIVEN the Cathedral is rebuilt, THEN every unit re-promotes to the rank its retained merit supports | Integration |
| AC-6 | GIVEN rank decay at rank 0, THEN rank stays 0 and no unit is destroyed | Logic |
| AC-7 | GIVEN Doctrine I is held, THEN every Empire vehicle's `effective_attack` is +1 and no infantry value changes | Logic |
| AC-8 | GIVEN the Cathedral is destroyed while Doctrines are held, THEN doctrine bonuses persist unchanged | Integration |
| AC-9 | GIVEN an Aegis Walker (`defense` 3) attacked by a unit of `attack` 3 out of cover, THEN damage is exactly `MIN_DAMAGE` (1) | Logic |
| AC-10 | GIVEN the same Walker attacked by a Solar Lance Team (`attack` 6, EMF), THEN damage is 5 | Logic |
| AC-11 | GIVEN an Empire unit crewing a vehicle, THEN it earns no merit from that vehicle's kills | Integration |
| AC-12 | GIVEN a fully-doctrined Cathedral Tank, THEN `effective_attack` is 8 and `effective_defense` is 5 | Logic |
| AC-13 | GIVEN a promoted Empire unit is destroyed, THEN no rank or merit persists anywhere in state | Integration |
| AC-14 | ★ GIVEN an Empire unit captured by another faction, THEN it retains its rank, earns no further merit, and does **not** decay when the Empire's Cathedral dies | Integration |
| AC-15 | GIVEN any non-Empire faction, THEN `promotion_enabled` is false and no unit accrues merit | Config-Data |
| AC-16 | ★ GIVEN an Alliance-vs-Empire AI batch, THEN neither wins more than **65%** across both seats | Integration |
| AC-17 | ★★ GIVEN a batch where one side targets the Cathedral deliberately, THEN the Empire wins no more than **40%** — the vulnerability must be real and exploitable | Integration |
| AC-18 | ★ GIVEN an Empire mirror batch, THEN matches resolve on HQ destruction rather than the round cap | Integration |

## Open Questions

| # | Question | Owner |
|---|---|---|
| HCEOQ-1 | ★★ **Is the variance acceptable?** A faction that grows by fighting and can be reset by one building will produce both the best and worst matches in the corpus. Combined with the Independents, that is **two of six factions whose quality depends on opponent behaviour rather than on numbers.** Worth deciding whether that is the intended texture of the game or one faction too many | user + game-designer |
| HCEOQ-2 | ★★ **Does vehicle `defense` 3 hard-counter low-attack factions?** An 18-hp Walker takes eighteen hits from a Solar Citizen because of the `MIN_DAMAGE` floor. EMF is the universal answer, but that makes an EMF specialist *mandatory* in this matchup rather than optional. **First priority on CR-10's matchup grid.** If too sharp, fix with `defense` 2 — never by touching `MIN_DAMAGE` | systems-designer |
| HCEOQ-3 | ★ **Does promotion re-create the snowball the PIVOT diagnosed?** (`promotion-veterancy.md` PVOQ-1.) Must be validated by the AI-vs-AI batch — the same tool that caught the economy defect will catch this one. **The Empire is the only faction that can trigger it** | economy-designer |
| HCEOQ-4 | **Should the Empire earn merit while crewing?** Currently no, which makes putting a veteran in a tank a real cost. Thematically right; it may make Empire vehicles feel like a trap | systems-designer |
| HCEOQ-5 | ★ **Is three turns of decay the right severity?** Fast enough to be terrifying, slow enough to fight back. But an Empire that loses its Cathedral at turn 25 of a 30-round match effectively loses the game on one building | game-designer |
| HCEOQ-6 | **The name.** *"Holy Cosmic Empire"* and *"Theocratic Monarchy"* agree with each other and with the mechanics — hierarchy, investiture, a cathedral that sanctifies rank. ★ The most internally consistent name in the set. Recommend keeping it. **Naming call — the user's** | user |
