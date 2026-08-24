# Unit Classes

> **Status**: **DRAFT** (2026-08-24) — Tier 1 of the faction corpus v2.
> **Author**: user (direction) + agents · **System #**: 17 (new — supersedes the deferred #14 "Vehicle & Mech Tier")
> **Owning GDD for**: the infantry / ground vehicle / air taxonomy and what each class means
>
> ★ **This is the largest single addition in the corpus.** The game today has exactly one kind of
> thing that moves: a unit on the ground. Four of the six factions field vehicles and aircraft, and
> those are not "units with bigger numbers" — they interact with terrain, with each other, and with
> the board differently. Getting this taxonomy right is what stops each faction inventing its own.

---

## Overview

**Unit Classes** defines the three kinds of unit the game recognises — **Infantry**, **Ground
Vehicle**, and **Air** — and what membership means mechanically. A class is not flavour; it
determines how a unit moves over terrain, what may target it, whether it occupies a tile the way
infantry does, whether it can be carried, and whether it counts against the population cap by
default.

The class system exists so that **CR-9 holds**: a faction never gets a rules exception, it gets
access to a class. The Machinist's Union does not have "special vehicle rules" — it has *more and
better vehicles*, drawn from the same class the Alliance draws its tank from.

Classes are **base-game, symmetric content**. Every rule here applies identically to every faction.
What differs per faction (D2) is *which classes it fields and how well* — the Solar Federation's
ground vehicles are mostly transports; the Independents' vehicles are mediocre by design; the
Machinist's Union's are its entire identity.

## Player Fantasy

**The feeling: "different tools, different problems."**

A game with one unit class is a game of numbers. Three classes make it a game of **answers** — you
do not merely have a stronger army, you have the *right* army for what is in front of you. The
intended feelings:

- **Infantry are the ground truth.** They take and hold, they use cover, they are what the board is
  measured in. Everything else supports or breaks them.
- **Vehicles are commitment.** Expensive, powerful, and awkward — they cannot go everywhere, and
  losing one is an event.
- **Air is tempo made literal.** It ignores the terrain everyone else is fighting through and
  arrives where it is not expected. It should feel *fast* and *fragile* — a scalpel that is punished
  for lingering.
- **Rock-paper-scissors without the arbitrariness.** Anti-air should exist because aircraft are
  vulnerable to it in a way that makes intuitive sense, not because a table says so.

## Detailed Rules

**UC-1 — Three classes, closed set.** `INFANTRY`, `GROUND_VEHICLE`, `AIR`. Every `UnitTypeDef`
declares exactly one. Structures are not units and have no class.

**UC-2 — Terrain interaction differs by class.** This is the primary mechanical meaning of a class.

| | Infantry | Ground Vehicle | Air |
|---|---|---|---|
| Enters difficult terrain | Yes, at the terrain's cost | ★ **No** — blocked entirely | Yes, at flat cost |
| Benefits from Cover (`COVER_DR`) | **Yes** | ★ **No** | **No** |
| Terrain movement cost | Per `grid-terrain.md` | Per `grid-terrain.md` | ★ **Flat `AIR_MOVE_COST` regardless of terrain** |
| Elevation affects it | Yes | Yes | ★ **No** |

> ★ **Vehicles being blocked by difficult terrain, and gaining nothing from cover, is what makes
> them a commitment rather than an upgrade.** Without it a vehicle is strictly better than infantry
> at the same price and the class collapses into a tier list. `grid-terrain.md`'s existing terrain
> types acquire real tactical weight the moment vehicles exist: a chokepoint of difficult terrain is
> an anti-vehicle wall that infantry walk through.

**UC-3 — Occupancy.** One unit per tile regardless of class — **including air.** Aircraft occupy the
tile they end on and block it.

> *Rationale, stated because the alternative is tempting:* letting air stack over ground units would
> double the board's density, break the isometric renderer's one-occupant-per-cell assumption
> (ADR-0013, `pick_regions`), and make the board unreadable — which is a **Pillar 3 hard gate** the
> project has already failed once. Air's advantage is *reach*, not *stacking*.

**UC-4 — Targeting is class-gated.** A `UnitTypeDef` declares `can_target: Set[UnitClass]`.
- Most units target `{INFANTRY, GROUND_VEHICLE}` and **cannot hit air at all.**
- Anti-air units target `{AIR}`, often exclusively.
- A unit with no legal target class present simply has no legal targets — this is the intended
  pressure, not a bug.

**UC-5 — Air must be answerable.** ★ **Every faction that can be attacked by air must have access to
at least one unit or structure that can target `AIR`.** A faction with no answer to aircraft is not
"asymmetric", it is unplayable against half the roster. This is a **CR-10 review gate item**, checked
per faction.

**UC-6 — Air does not capture, hold, or build.** Aircraft cannot capture objectives, cannot be the
unit that occupies a structure, and cannot be produced from a Production Outpost without an
air-capable producer. Their role is strike and reach.

**UC-7 — ★ Class and the population cap: infantry only, with vehicles capped through their crew.**
*(User decision, 2026-08-24.)* `INFANTRY` counts toward the population cap; `GROUND_VEHICLE` and
`AIR` never do. Vehicles are not uncapped, though — **a vehicle with `requires_pilot = true` spends
an infantry slot on its crew** (`population-cap.md` PC-8), so armour competes with boots for the
same ceiling. A faction fielding heavy armour therefore fields *fewer soldiers*, which is a
tradeoff the player can see rather than a number in a table.

`counts_toward_cap` remains a per-unit property, not a per-class one (PC-4), so the Protectorate's
robotic **infantry** can be cap-exempt while still being infantry.

**UC-8 — Class is immutable.** A unit never changes class, including through promotion or tech. A
tech that "upgrades" a mech (the Protectorate's autonomous mechs) changes its properties, not its
class.

**UC-9 — Faction access (D2).** A faction declares which classes it fields. **A faction may field
none of a class** — that is a legitimate identity statement, subject to UC-5.

## Formulas

```
can_enter(unit, tile) =
    tile is on-board
    AND tile is unoccupied
    AND NOT (unit.unit_class == GROUND_VEHICLE AND tile.terrain.is_difficult)

move_cost_for(unit, tile) =
    unit.unit_class == AIR  ?  AIR_MOVE_COST  :  terrain_move_cost(unit, tile)

cover_dr_for(unit, tile) =
    unit.unit_class == INFANTRY AND tile.has_cover  ?  COVER_DR  :  0

can_attack(attacker, defender) =
    defender.unit_class IN attacker.can_target
    AND distance <= effective_attack_range(attacker)
```

| Constant | Default | Note |
|---|---:|---|
| `AIR_MOVE_COST` | **1** AP/tile | Flat, terrain-independent. ★ This is what makes air *feel* fast |
| `AIR_ATTACK_COST` | **2** AP | Same as ground, for now — see `combat-resolution.md`'s flat `attack_cost` and the deferred per-unit cost in the post-gate backlog |

**Indicative class profiles** (per-faction values live in the faction GDDs):

| | Infantry | Ground Vehicle | Air |
|---|---|---|---|
| `produce_cost` band | 2–7 | 10–16 | 10–14 |
| `hp` band | **3–10** | **16–24** | **5–9** |
| `attack` band | 2–6 | 6–8 | 4–7 |
| `upkeep` band | 1–3 | 4–6 | 4–5 |
| Typical `move_cost` | 1–3 | 2 (flat ground only) | 1 |
| Typical reach/turn | 2–5 tiles | 4–5 tiles | ★ 8–10 tiles |

> ⚠ **Corrected 2026-08-24 against the shipped roster.** An earlier draft of this table proposed an
> infantry `hp` band of 6–14. The actual shipped values are **Scout 3 · Sniper 3 · Trooper 6 ·
> Heavy 10** — the roster is far more fragile than that draft assumed, and every other band here has
> been rescaled against the real numbers. ★ The practical consequence is large: at these hp values a
> single Sniper hit (attack 6) **kills any 6-hp unit outright**, so vehicle hp had to come down from
> the 18–30 first proposed. A 30-hp vehicle against a 6-attack roster takes five clean hits to kill
> and would simply dominate the board.

> ★ **Air's fragility is the balance lever, not its cost.** The `hp` band above deliberately sits
> *inside* the infantry range (5–9 against infantry's 3–10), not the vehicle range: air trades
> survivability for reach. At these numbers a Sniper (attack 6) or a Defensive Structure (attack 4)
> that **can** target air will kill or nearly kill an aircraft in one hit — which is exactly the
> pressure that stops air dominating. If air feels oppressive in playtest, cut hp before cutting
> reach; reach is the fantasy.

## Edge Cases

- **A vehicle adjacent to difficult terrain with no other route:** it is genuinely stuck. Correct and intended — terrain is an anti-vehicle tool.
- **A vehicle produced onto difficult terrain:** production placement must validate `can_enter`; rejected at the produce call site, not after placement.
- **Air ending its turn over enemy territory:** nothing special happens. There is no fuel, no attrition, no forced return. *Rationale: fuel is a second upkeep system on one class, and upkeep already exists.*
- **An air unit as the only remaining unit:** legal. It cannot capture (UC-6), so it can harass but not win alone — the player must still produce ground forces.
- **A faction with no anti-air facing a faction with air:** blocked at review by UC-5/CR-10, not at runtime.
- **A transported unit's class:** carried units retain their own class; the transport's class governs movement while carrying.
- **Terrain becoming difficult under a vehicle** (if terrain ever mutates): the vehicle is not destroyed or teleported — it may remain and may leave to any legal tile. It simply cannot re-enter.
- **A vehicle on a cover tile:** occupies it normally, gains no `COVER_DR` (UC-2). ★ It also does not *deny* the cover to infantry permanently — it just occupies the tile.

## Dependencies

| System | Relationship |
|---|---|
| **Grid & Terrain** (#5) | ★ **Hard, and this is the big one.** `is_difficult` must exist as a terrain property; today terrain distinguishes plain vs cover, not passability by class |
| **Movement System** (#4/#6) | ★ Hard — `can_enter` and `move_cost_for` become class-aware. **Dijkstra monotonicity still requires `move_cost ≥ 1` for every class**, which `AIR_MOVE_COST = 1` satisfies |
| **Combat Resolution** (#6) | Hard — `can_target` gating and class-conditional `COVER_DR` |
| **Unit System** (#4) | Hard — `unit_class` and `can_target` on `UnitTypeDef` |
| **Base & Production** (#7) | Hard — producer/class matching (UC-6); placement validates `can_enter` |
| **Population Cap** (#16) | Soft — default per class, overridable per unit (PCOQ-1) |
| **Board Renderer** (#?) | ★ Hard — three classes need distinguishable silhouettes at isometric scale, and air needs a height cue that does not break the one-occupant-per-cell model (ADR-0013). **This is a Pillar 3 risk** |
| **AI Opponent** (#11) | ★★ Hard — the AI has no concept of class. It cannot currently reason about "my ground units cannot hit that aircraft" |
| **Faction Identity** (#12) | Hard — D2 |

## Tuning Knobs

| Knob | Default | Safe range | Effect / failure at extremes |
|---|---|---|---|
| `AIR_MOVE_COST` | 1 | 1–2 | ★ At 1 with 10 AP, air crosses most of a 12×10 board in a turn — that is the fantasy. At 2 air is merely fast infantry and the class loses its point. **Cannot go below 1** (Dijkstra monotonicity) |
| Air `hp` band | 5–9 | 4–12 | The primary air balance lever. Cut this before cutting reach |
| Vehicle difficult-terrain block | on | on/off | ★ Turning it off collapses the vehicle class into "better infantry". Strongly recommend it stays on |
| Vehicle `COVER_DR` eligibility | none | none/partial | Same concern as above |
| Vehicle `produce_cost` band | 10–16 | 8–20 | Against infantry at 2–7, a vehicle should read as 2–3 infantry's worth of commitment — **plus the infantry slot its crew occupies** (PC-8), which is the larger cost in practice |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a `GROUND_VEHICLE` and a difficult-terrain tile, THEN that tile never appears in its reachable set and a move onto it is rejected | Logic |
| AC-2 | GIVEN an `INFANTRY` unit and the same tile, THEN it is reachable at the terrain's cost | Logic |
| AC-3 | GIVEN an `AIR` unit, THEN every on-board unoccupied tile within budget is reachable at `AIR_MOVE_COST` per tile regardless of terrain | Logic |
| AC-4 | GIVEN a `GROUND_VEHICLE` on a cover tile under attack, THEN damage is computed with `COVER_DR = 0` | Logic |
| AC-5 | GIVEN an `INFANTRY` unit on the same tile under the same attack, THEN `COVER_DR` applies | Logic |
| AC-6 | GIVEN an attacker whose `can_target` excludes `AIR`, THEN no `AIR` unit appears in its legal targets at any range | Logic |
| AC-7 | GIVEN an anti-air unit and an adjacent ground unit, THEN the ground unit is not a legal target if `can_target == {AIR}` | Logic |
| AC-8 | GIVEN any tile, THEN at most one unit of any class occupies it | Logic |
| AC-9 | GIVEN an `AIR` unit, THEN it cannot capture, cannot occupy a structure, and cannot be produced by a non-air-capable producer | Integration |
| AC-10 | GIVEN a vehicle production order targeting difficult terrain, THEN it is rejected before placement | Integration |
| AC-11 | GIVEN any shipping `FactionDef`, THEN it has at least one unit or structure whose `can_target` includes `AIR` | Config-Data |
| AC-12 | GIVEN any `UnitTypeDef`, THEN `unit_class` is exactly one of the three and `move_cost ≥ 1` | Config-Data |
| AC-13 | GIVEN a promoted or tech-upgraded unit, THEN its `unit_class` is unchanged | Logic |
| AC-14 | GIVEN a board with all three classes present, THEN each is distinguishable in grayscale at the shipping camera | Visual (advisory — Pillar 3) |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| UCOQ-1 | ★★ **Does air break Pillar 3?** Aircraft need a height cue at isometric scale, and ADR-0013 assumes one occupant per cell with bottom-centre ground-contact pivots. A hovering unit has no ground contact, so its pivot rule and its Y-sort order are both undefined. **This is the same class of problem that produced S5-01's 1408px cell-drift bug.** Needs a renderer spike before any air unit is authored | godot-specialist + art-director | Before air ships |
| UCOQ-2 | **Does `grid-terrain.md` already have a difficult-terrain concept, or is one owed?** Terrain currently distinguishes plain vs cover. `is_difficult` may be a new property, a re-use of cover, or a third type — and it becomes load-bearing the moment vehicles exist | systems-designer | Before vehicles ship |
| UCOQ-3 | ★ **Should air be attackable by anything at range, or only by dedicated anti-air?** Exclusive anti-air is cleaner and makes air feel special, but it means a player who did not build anti-air simply loses to air, which is a hard counter — the kind of thing Pillar 2's anti-luck stance dislikes. Recommend a middle position: most units cannot reach air, but a few generalists can at reduced effect | user + systems-designer | With `damage-types.md` |
| UCOQ-4 | **Is there a fourth class — naval, orbital, artillery?** The Alliance's roster names artillery, which is currently a `GROUND_VEHICLE` with long range rather than its own class. Recommend keeping three; artillery is a *role*, not a class | systems-designer | Faction authoring |
