# Transport & Pilots

> **Status**: **DRAFT** (2026-08-24) — Tier 1 of the faction corpus v2.
> **Author**: user (direction) + agents · **System #**: 20 (new)
> **Owning GDD for**: unit carriage, and vehicle crewing / unpiloted state
>
> ★ **Two related mechanics, one document, deliberately.** Carriage (a unit inside a transport) and
> crewing (a unit *operating* a vehicle) share almost all their machinery — a unit that exists but
> is not on a tile — and splitting them would duplicate every edge case. **The Independents' pirate
> is meaningless without the unpiloted state defined here**, and the Machinist's Union's entire
> identity is *"infantry primarily focused on piloting"*.

---

## Overview

**Transport & Pilots** introduces the idea that a unit can exist without standing on a tile of its
own. Two forms:

- **Carried** — a unit is inside a transport. It moves with the transport, cannot act, and is not
  targetable independently.
- **Crewing** — a unit is operating a vehicle. The vehicle is the thing on the board; the pilot is
  inside it. Remove the pilot and the vehicle becomes **unpiloted**: inert, immobile, and
  **stealable**.

This is what the user's direction needs in four places at once: the Alliance and Solar transports,
Solar's paratrooper transport and dedicated **pilot** unit, the Protectorate's *"autonomous
transport that can pick up multiple infantry or one mech vehicle"* and its mechs that *"can be
upgraded through the tech tree to run autonomously without pilots"*, and — most sharply — the
Independents' pirate, which *"can steal opposing player's vehicles by either moving onto an
unpiloted vehicle, or by attacking the pilot directly and then taking control."*

**The unpiloted state is the load-bearing idea.** It is what turns an enemy vehicle from a target
into an *objective*, gives the Machinist's Union a real vulnerability to match its power, and makes
the Protectorate's autonomy tech a genuine upgrade rather than flavour.

## Player Fantasy

**The feeling: "that tank is not destroyed. It is *available*."**

- **Vehicles as terrain-with-value.** An abandoned mech in the middle of the board is a prize both
  players can see and race for. Nothing in the game currently creates that.
- **Crew as a vulnerability worth protecting.** For the Machinist's Union, losing a pilot is worse
  than losing hp — the machine is intact and now belongs to whoever reaches it.
- **Logistics as a real decision.** A transport is a tempo instrument: it converts Credits into
  *reach*. Loading, moving and unloading should feel like a plan, not a chore.
- **★ For the Independents, larceny as a strategy.** *"I cannot build a tank. I can take yours."*
  That is the most distinctive fantasy in the whole faction set and it deserves to work well.

## Detailed Rules

**TP-1 — A carried unit is not on the board.** It occupies no tile, is not targetable, cannot be
attacked, cannot act, and does not block movement. It **does** count toward the population cap
(`population-cap.md`) — otherwise loading a transport is a cap-dodge.

**TP-2 — Transports declare capacity by size.** `transport_capacity: int` and
`transport_accepts: Set[UnitClass]`. Each carried unit consumes `transport_size` slots (default 1;
a mech or vehicle is larger). This expresses *"multiple infantry or one mech vehicle"* with one
number rather than a special case.

**TP-3 — Embark and disembark are abilities, not free moves.** `EMBARK` and `DISEMBARK` are
catalogue entries (`unit-abilities.md`), each costing 1 AP, range 1. **A unit cannot embark and
disembark in the same turn**, and disembarking ends the unit's turn — otherwise a transport becomes
a free extension of every passenger's movement.

**TP-4 — Destroying a transport destroys its cargo.** All carried units die with it.

> *Rationale, stated because the alternative is tempting:* ejecting survivors is more forgiving but
> creates an unsolvable placement problem (where do four units go if the transport died in a
> corridor?), can exceed the population cap, and makes a loaded transport *safer* than the units
> walking. **A loaded transport is a high-value target. That is the decision.**

**TP-5 — Crewed vehicles: `requires_pilot`.** ★★ **This flag now carries far more weight than it
did when this document was drafted.** Following the user's 2026-08-24 decision that the population
cap counts **infantry only**, `requires_pilot` is **the game's primary limiter on how much armour a
faction can field** — a crewing pilot is a carried unit, carried units count toward the cap
(TP-1), and so every piloted vehicle costs its owner an infantry slot. See `population-cap.md` PC-8.
It is no longer merely a vulnerability; it is a balance mechanism, and changing it on any unit
changes that faction's army size.

A `UnitTypeDef` with `requires_pilot = true` is non-functional without one. A vehicle is either **piloted** (fully functional) or **unpiloted**
(cannot move, cannot attack, cannot use abilities — but still occupies its tile, still has hp, and
is still destructible).

**TP-6 — Pilots enter and leave through `EMBARK`/`DISEMBARK`.** Crewing uses the same machinery as
carriage; a pilot is cargo that happens to enable the vehicle. A vehicle may hold exactly one pilot.

**TP-7 — Killing the pilot without killing the vehicle.** ★ The direction's *"attacking the pilot
directly"*. Resolved as: when a **crewed** vehicle takes damage from an attack whose
`targets_crew = true`, the damage applies **to the pilot's hp**, not the vehicle's. If the pilot
dies, the vehicle becomes unpiloted and is left intact. `targets_crew` is an attack property
available to any faction (CR-9) and is the Independents' pirate's signature.

**TP-8 — An unpiloted vehicle can be claimed.** By `CAPTURE_VEHICLE` (adjacent, 3 AP) or by a
friendly pilot embarking into it. Both are subject to the claimer's population cap.

**TP-9 — Autonomous units never have this vulnerability.** `requires_pilot = false` — the
Protectorate's robots and autonomous transports, and its mechs after the autonomy tech. They cannot
be crew-killed and cannot be captured. **This is precisely what the Protectorate's tech tree is
buying**, and it is why that tech is worth its cost.

**TP-10 — A carried unit's upkeep still applies.** It exists; it is paid for.

## Formulas

```
transport_load(t)      = Σ transport_size(u) for every u carried by t
can_embark(u, t)       = adjacent(u, t)
                         AND u.unit_class IN t.transport_accepts
                         AND transport_load(t) + transport_size(u) <= t.transport_capacity
                         AND u has not disembarked this turn
                         AND u.ap_available >= EMBARK_AP_COST

is_functional(v)       = NOT v.requires_pilot OR v.pilot != null

damage_target(attack, defender) =
    (attack.targets_crew AND defender.requires_pilot AND defender.pilot != null)
        ? defender.pilot
        : defender

can_capture(actor, v)  = adjacent(actor, v)
                         AND v.requires_pilot AND v.pilot == null
                         AND population_has_room(owner_of(actor), v)
```

| Constant | Default | Note |
|---|---:|---|
| `EMBARK_AP_COST` / `DISEMBARK_AP_COST` | **1** AP each | Per `unit-abilities.md` |
| `transport_size` (infantry) | **1** | |
| `transport_size` (vehicle / mech) | **3** | ★ Makes "multiple infantry **or** one mech" fall out of capacity 3 |
| Pilot `hp` band | **4–6** | ★ Deliberately low — crew-killing must be a *viable* play, not a theoretical one |

**Indicative transports:**

| Transport | Capacity | Accepts | Note |
|---|---:|---|---|
| Alliance transport | 3 | `INFANTRY` | Three infantry |
| Solar paratrooper transport | 3 | `INFANTRY` | Carries `PARADROP` |
| Protectorate autonomous transport | 3 | `INFANTRY`, `GROUND_VEHICLE` | ★ Three infantry **or** one mech; `requires_pilot = false` |

## Edge Cases

- **Transport destroyed with cargo:** cargo dies (TP-4). Population slots free immediately.
- **Embarking into a full transport:** rejected at validation.
- **A mech embarking into a capacity-3 transport carrying one infantry:** rejected — 1 + 3 > 3.
- **Disembarking with no adjacent free tile:** rejected. The transport must move somewhere with room.
- **Embark-then-disembark same turn:** rejected (TP-3).
- **An unpiloted vehicle blocking a tile:** it does. It is an obstacle as well as a prize — a genuinely interesting board state.
- **Attacking an unpiloted vehicle normally:** damage applies to the vehicle; it can be destroyed rather than captured. Denying a capture by destroying the prize is a legitimate play.
- **`targets_crew` against an unpiloted vehicle:** falls through to normal vehicle damage (the `damage_target` conditional fails), so the attack is never wasted.
- **`targets_crew` against a `requires_pilot = false` unit:** same fall-through. The Protectorate is immune by construction, not by exception (TP-9).
- **Pilot killed while the vehicle is inside a transport:** ★ not possible — cargo is untargetable (TP-1).
- **A pilot disembarking at population cap:** the pilot already counted while crewing, so no *new* slot is needed and the disembark succeeds. The vehicle it leaves becomes unpiloted and needs no slot of its own (vehicles are never counted directly, PC-8). ★ Net effect: a player at cap may freely abandon a vehicle to put its crew back on the line — a real tactical option, and a deliberate one.
- **Capturing a vehicle whose class the capturing faction never fields:** legal, and delightful. An Independents player driving a Union mech is the fantasy working.
- **Two units adjacent to one unpiloted vehicle:** first to act claims it. Turn order decides; deterministic, no contest rule needed.

## Dependencies

| System | Relationship |
|---|---|
| **Unit Abilities** (#19) | ★ Hard — `EMBARK`, `DISEMBARK`, `PARADROP`, `CAPTURE_VEHICLE` all live in that catalogue |
| **Unit Classes** (#17) | Hard — `transport_accepts` is class-keyed; `transport_size` differs by class |
| **Population Cap** (#16) | ★ Hard — carried units count (TP-1); capture is capped; PCOQ-2 open |
| **Combat Resolution** (#6) | ★ Hard — `targets_crew` redirects the damage target. **This is the first time in the corpus that the entity attacked is not the entity damaged**, and it needs care in the event ordering the renderer depends on (ADR-0004, and S5-06's `DamageEvent` in particular) |
| **Unit System** (#4) | Hard — `requires_pilot`, `pilot`, `transport_capacity`, `transport_accepts`, `transport_size`, `carried_by` |
| **Game State** (#2) | ★ Hard — carried units are **live entities not on the board**. `entities()` currently implies board presence; the renderer's sprite feed and `pick_regions` both assume every entity has a tile |
| **Unit Upkeep** (#15) | Soft — carried units still pay (TP-10) |
| **Board Renderer** | ★ Hard — a transport must visibly indicate it is loaded, and an unpiloted vehicle must read as inert at a glance. Both are Pillar 3 concerns |
| **AI Opponent** (#11) | ★★ Hard — loading, transporting, unloading and capturing are all multi-turn plans. **The AI is single-action greedy and has no planning horizon at all.** This is the single hardest AI item in the corpus |

## Tuning Knobs

| Knob | Default | Safe range | Effect / failure at extremes |
|---|---|---|---|
| `transport_capacity` | 3 | 2–4 | At 4+ one transport moves a whole army and the board becomes two blobs. At 1 transports are not worth their cost |
| Pilot `hp` | 4–6 | 3–8 | ★ The dial that decides whether crew-killing is real. Above ~8 nobody bothers and the Independents lose their identity; below 3 vehicles are too fragile to field |
| `transport_size` (vehicle) | 3 | 2–4 | Governs the "infantry or one mech" tradeoff directly |
| `EMBARK_AP_COST` | 1 | 1–2 | At 2, loading three units costs 6 AP of a 10 AP turn and transports become unusable |
| `CAPTURE_VEHICLE` cost | 3 AP | 2–4 | See `unit-abilities.md` — the ability most likely to be degenerate |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a carried unit, THEN it occupies no tile, is absent from legal targets, and does not block movement | Integration |
| AC-2 | GIVEN a carried unit, THEN it still counts toward its owner's population cap | Integration |
| AC-3 | GIVEN a carried unit, THEN it still contributes upkeep | Integration |
| AC-4 | GIVEN a transport at capacity, THEN a further embark is rejected | Logic |
| AC-5 | GIVEN a transport of capacity 3 carrying one infantry, THEN a `transport_size = 3` vehicle cannot embark | Logic |
| AC-6 | GIVEN a transport is destroyed, THEN every carried unit is destroyed and their population slots free | Integration |
| AC-7 | GIVEN a unit that embarked this turn, THEN disembarking this turn is rejected | Logic |
| AC-8 | GIVEN a disembark with no adjacent free legal tile, THEN it is rejected | Logic |
| AC-9 | GIVEN a `requires_pilot` vehicle with no pilot, THEN move, attack and ability activation are all rejected, and it still occupies its tile and retains hp | Integration |
| AC-10 | GIVEN an attack with `targets_crew` against a crewed vehicle, THEN the pilot's hp decreases and the vehicle's does not | Integration |
| AC-11 | GIVEN that attack kills the pilot, THEN the vehicle becomes unpiloted and is not destroyed | Integration |
| AC-12 | GIVEN an attack with `targets_crew` against a `requires_pilot = false` unit, THEN normal damage applies to that unit | Logic |
| AC-13 | GIVEN an adjacent unpiloted vehicle and a free population slot, THEN `CAPTURE_VEHICLE` transfers ownership | Integration |
| AC-14 | GIVEN an adjacent **piloted** vehicle, THEN `CAPTURE_VEHICLE` is rejected | Integration |
| AC-15 | GIVEN a friendly pilot embarking into an owned unpiloted vehicle, THEN it becomes functional | Integration |
| AC-16 | GIVEN two units able to capture the same vehicle, THEN the first to act claims it and the second's attempt is rejected — deterministically across repeated runs | Integration |
| AC-17 | GIVEN a loaded transport, THEN the board visibly indicates it carries units; GIVEN an unpiloted vehicle, THEN it visibly reads as inert | Visual (advisory) |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| TPOQ-1 | ★★ **`GameState.entities()` assumes board presence.** Carried units are live entities without a tile — the first such thing in the corpus. The sprite feed, `pick_regions`, the AI's board scan and the win-check all iterate entities expecting a position. **This is an architectural change, not a feature**, and it needs an ADR before implementation. Related: S5-06's death echo already introduced a "live entity in an unusual state" exemption, so there is precedent to follow | technical-director | ADR before build |
| TPOQ-2 | ★ **Does `targets_crew` break the event ordering the renderer depends on?** It is the first case where the attacked entity is not the damaged entity. `DamageEvent` carries `target_id`; a crew hit means that id is a unit that is not on the board. ADR-0004's ordering and S5-06's lunge/recoil both assume otherwise | godot-gdscript-specialist | With implementation |
| TPOQ-3 | **Should an unpiloted vehicle decay?** Left alone it sits forever, which may make late boards cluttered with abandoned hardware. A decay timer would prevent that but adds a per-turn state nobody asked for. Recommend **no decay** initially and watch it in playtest | systems-designer | Playtest |
| TPOQ-4 | ★ **Is the AI going to be able to play any of this?** Transports require a plan spanning several turns and the AI is single-action greedy. A faction whose identity is transports (Solar) may be **unplayable by the AI** in a way that makes it unplayable *against*, which is most of the game's content. Possibly the strongest argument for sequencing Solar Federation early — it surfaces the problem while it is still cheap to solve | ai-programmer + producer | Sprint planning |
