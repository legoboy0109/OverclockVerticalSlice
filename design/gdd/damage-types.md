# Damage Types

> **Status**: **DRAFT** (2026-08-24) — Tier 1 of the faction corpus v2.
> **Author**: user (direction) + agents · **System #**: 18 (new)
> **Owning GDD for**: damage type tags, per-type resistance, and area-of-effect shapes
>
> ★ **This system EXTENDS `combat-resolution.md`'s formula. It does not replace it.** The one
> combat formula stays deterministic and stays the single resolution path (Pillar 2). Damage types
> add **one term** to it and nothing else. If this document ever appears to require a second damage
> path, that is a defect in this document.
>
> ★ **This is base-game, symmetric content — NOT a faction lever** (CR-9). Every faction plays by
> identical damage-type rules. Factions differ only in *which units deal and resist which types*.

---

## Overview

**Damage Types** give attacks a *kind* as well as a magnitude. An attack tagged `KINETIC` and one
tagged `EMF` may both read 6 attack, but land very differently on a robot than on a rifleman.

The system exists because the user's faction direction requires it: the **Galactic Protectorate**'s
tanks are *"powerful… but weak to EMF damage"* and one of them deals *"EMF damage indirect"*, its
mech is an *"AoE close quarters anti-armor vehicle"*, and its aircraft has a *"ground strafing run
attack (AoE in a line)"*. None of that is expressible against a single untyped damage number.

It also does something the corpus needs independently: **it is what makes "anti-armour" and
"anti-air" real categories** rather than just bigger numbers pointed at particular classes, and it
gives the Protectorate's cheap-robots-vs-elite-humans thesis a mechanical edge — machines are
vulnerable to a type flesh is not.

**Design constraint held throughout: three types, not ten.** Every additional type multiplies the
matchup matrix and the amount a player must hold in their head. Pillar 3 is about legibility, and a
board where you cannot predict a hit is illegible.

## Player Fantasy

**The feeling: "the right tool, not just the bigger gun."**

- **Recognition.** Seeing an enemy tank should trigger *"that is what my EMF gun is for"* — a small
  puzzle solved, not a numbers comparison.
- **Composition as insurance.** An army of one damage type is efficient right up until it meets its
  counter, and then it is helpless. That tension is the point.
- **Faction texture without faction rules.** The Protectorate's robots should feel *materially
  different* to fight — and they do, because they are made of something an EMF weapon hurts.
- **Never a gotcha.** A player must be able to *see* a matchup before committing. `preview_damage`
  (already an Approved contract in `combat-resolution.md`) becomes load-bearing here — it must show
  the type interaction, not just a number.

## Detailed Rules

**DT-1 — Three damage types, closed set.** `KINETIC`, `EMF`, `INCENDIARY`.

| Type | Reads as | Strong against | Weak against |
|---|---|---|---|
| `KINETIC` | Bullets, shells, the default | Nothing in particular — the baseline | Nothing in particular |
| `EMF` | Electromagnetic, disruption | ★ **Machines** — vehicles, aircraft, robots. Default −2 resistance (DT-9b), so EMF is *the* anti-armour language | **Organic infantry** — default +2 |
| `INCENDIARY` | Fire, napalm | **Organic infantry, units in cover** (it burns them out) | **Armoured vehicles** |

> ★ **`KINETIC` is deliberately neutral, and this is the most important line in the document.** It
> is the type an existing unit gets by default, which means **every currently shipped unit keeps
> behaving exactly as it does today** and the entire Approved combat corpus stays valid. Damage
> types are additive to the game, not a rebalance of it.

**DT-2 — Every attack declares a type; every unit declares resistances.** `damage_type` on the
attacking unit (or ability); `resistances: Map[DamageType → int]` on the defending `UnitTypeDef`.
Absent entries are 0.

**DT-3 — Resistance is a flat modifier in the existing formula, not a multiplier.**

> *Rationale, and it is load-bearing:* `combat-resolution.md`'s damage formula is entirely additive
> with a `MIN_DAMAGE = 1` floor, and its `defense` + `COVER_DR` stacking has an Approved,
> carefully-reasoned floor-lock analysis behind it. A multiplier would invalidate that analysis and
> reopen the floor-lock trap that document already paid to close. **Additive keeps every existing
> guarantee intact.**

**DT-4 — Resistance may be negative — that is what "weak to" means.** The Protectorate's tank is
*weak to EMF*, expressed as `resistances[EMF] = -2`, which *increases* damage taken. `MIN_DAMAGE = 1`
still floors the result; there is no upper clamp.

**DT-5 — Resistance never removes a hit.** `MIN_DAMAGE = 1` is untouched. A landed attack always
takes at least 1 hp regardless of resistance. Immunity does not exist.

**DT-6 — `INCENDIARY` ignores `COVER_DR`.** An incendiary attack against a unit in cover applies
`cover_reduction = 0`. This is the type's identity — you burn people out of cover — and it gives the
Protectorate's napalm tank a clear tactical role that is not just "more damage".

**DT-7 — Area of effect: three shapes, closed set.** An attack or ability declares an `area_shape`:

| Shape | Covers | Used by |
|---|---|---|
| `SINGLE` | The target tile only. **The default; every existing unit uses it** | Everything shipped today |
| `BURST` | Target tile + all orthogonally adjacent tiles | Protectorate's close-quarters anti-armour mech |
| `LINE` | A straight run of `area_length` tiles from the attacker through the target | Protectorate's strafing aircraft |

**DT-8 — Area damage hits everything, including friendlies.** Every unit in the shape takes damage,
resolved independently per target through the standard formula. **There is no friendly-fire
exemption.** *Rationale: an AoE that only hits enemies is strictly good and has no placement
decision in it; friendly fire is what makes an area weapon a skill expression rather than a bigger
number.*

**DT-9 — Area resolution order is deterministic.** ★ **This rule is load-bearing and one other
system was corrected to preserve it:** `promotion-veterancy.md` PV-6 originally promoted a unit
mid-burst, which would have let an early target's death change a later target's damage. It now
applies rank changes **after the whole attack resolves**. Any future mechanic that mutates an
attacker's stats during resolution must defer the same way.
 Targets resolve in a fixed board order (row-major
by tile coordinate), each through the standard formula, with all deaths applied after all damage.
No target's death changes another's damage within the same attack. **Pillar 2 requires this
explicitly.**

**DT-9b — ★ Machines are EMF-vulnerable by default.** `GROUND_VEHICLE` and `AIR` units carry an
implicit `resistances[EMF] = −2` unless their definition overrides it. Infantry carry an implicit
`resistances[EMF] = +2`.

> ★ **Why this is a default rather than per-unit authoring.** Without it, "anti-armour" has no
> mechanical meaning — a faction wanting an anti-tank specialist would have to be handed a big flat
> attack number, which also makes it good against infantry, which is exactly what a specialist
> should not be. Making EMF *the* anti-machine damage type gives every faction a language for
> anti-armour that costs no new machinery and stays symmetric (CR-9).
>
> A unit may still override: the Galactic Protectorate's tanks are *"weak to EMF"* **beyond** the
> baseline (−3, not −2), which keeps that trait distinctive rather than merely shared. A faction
> wanting EMF-hardened armour sets 0 or positive and pays for it elsewhere.

**DT-10 — Structures and damage types.** Structures carry resistances like units. They remain
cover-immune per `combat-resolution.md` Rule 6 — an Approved rule that closes a real floor-lock trap
and **must not be reopened here.**

## Formulas

### The extended damage formula — one added term

```
damage(attacker, defender) =
    max( MIN_DAMAGE,
         effective_attack(attacker)
         − cover_reduction(defender, attacker.damage_type)
         − defense(defender)
         − resistance(defender, attacker.damage_type) )        ← the only new term
```

```
cover_reduction(defender, type) =
    (defender is a unit) AND defender.tile.is_cover AND type != INCENDIARY   ?  COVER_DR  :  0

resistance(defender, type) = defender.resistances[type]   (default 0, may be negative)
```

```
area_tiles(attacker, target, shape) =
    SINGLE :  { target }
    BURST  :  { target } ∪ orthogonal_neighbours(target)
    LINE   :  the first `area_length` on-board tiles along the ray attacker → target
```

**Worked examples** (against the shipped roster, `COVER_DR = 1`, `MIN_DAMAGE = 1`):

| Attacker | Defender | Terms | Damage |
|---|---|---|---|
| Sniper (atk 6, `KINETIC`) | Trooper in cover, def 0, res 0 | `6 − 1 − 0 − 0` | **5** (unchanged from today) |
| EMF tank (atk 6, `EMF`) | Protectorate robot, `res[EMF] = -2` | `6 − 0 − 0 − (−2)` | **8** |
| EMF tank (atk 6, `EMF`) | Alliance infantry, `res[EMF] = +2` | `6 − 0 − 0 − 2` | **4** |
| Napalm tank (atk 5, `INCENDIARY`) | Infantry in cover, `res[INC] = 0` | `5 − 0 − 0 − 0` (DT-6) | **5** |
| Napalm tank (atk 5, `INCENDIARY`) | Vehicle, `res[INC] = +3` | `5 − 0 − 0 − 3` | **2** |

> ★ **Resistance band: −3 to +3.** Outside it, types stop being a tilt and become a hard counter —
> at ±5 against a 6-attack roster, half the matchups are decided before the attack lands, which is
> the opposite of Pillar 2's "you can see the outcome coming and it is fair".

| Constant | Default | Note |
|---|---:|---|
| `RESISTANCE_MIN` / `RESISTANCE_MAX` | **−3 / +3** | Schema-enforced at load |
| `LINE_DEFAULT_LENGTH` | **4** tiles | Per-ability overridable |
| `AREA_AP_SURCHARGE` | **+1** AP | Area attacks cost more than `attack_cost`; hitting four tiles for the price of one is not a decision |

## Edge Cases

- **Resistance driving damage below 1:** floored at `MIN_DAMAGE = 1` (DT-5). Existing behaviour, unchanged.
- **Negative resistance with no upper clamp:** intended. A tank badly countered takes a lot. The −3 band is the guard.
- **`INCENDIARY` against a structure:** structures are cover-immune anyway, so DT-6 is a no-op there — no interaction, no special case.
- **A `LINE` attack passing through a friendly:** the friendly is hit (DT-8). This is the placement decision.
- **A `LINE` attack running off-board:** truncates at the board edge; no wraparound, no error.
- **A `BURST` centred at the board edge:** covers only on-board neighbours.
- **An area attack whose only target is a friendly:** legal. The player may do this; it is their mistake to make. ★ The UI must warn (see AC-13) but must not block — blocking would mean the game second-guessing a deliberate sacrifice play.
- **Area attack and counterattack:** ★ **only the primary target may counter** (if `can_counterattack`), not every unit in the area. Otherwise a burst into three counter-capable units takes three free counters, which makes area weapons strictly bad.
- **Two area attacks in one turn:** legal if AP allows, including `AREA_AP_SURCHARGE` each.
- **A unit with a type it has no resistance entry for:** resolves at 0. Absent means neutral, never an error.

## Dependencies

| System | Relationship |
|---|---|
| **Combat Resolution** (#6) | ★ **Hard — this system is an extension of it.** Adds one term to the damage formula, one clause to `cover_reduction`, and the area loop. `MIN_DAMAGE`, `COVER_DR`, `defense` stacking and structure cover-immunity are all **unchanged** |
| **Unit System** (#4) | Hard — `damage_type`, `resistances`, `area_shape`, `area_length` on `UnitTypeDef` |
| **Unit Classes** (#17) | Soft — types and classes are orthogonal by design. EMF hurts *machines*, which is a resistance value, not a class check. ★ Deliberate: class-keyed damage would hard-code "vehicles are machines" and break the Protectorate's robotic *infantry* |
| **Command & Action Interface** (#9) | ★ Hard — `preview_damage` must show the type interaction, and area attacks need an area preview before commit |
| **Game HUD** (#10) | Hard — a unit's type and notable resistances must be inspectable |
| **AI Opponent** (#11) | ★★ Hard — target selection must account for resistance, or the AI will fire EMF into infantry all game. Area attacks additionally need multi-target scoring, which its current one-target-at-a-time model has no shape for |
| **Board Renderer** | Hard — area shapes need a telegraph overlay; the existing move/attack highlight is the natural home |

## Tuning Knobs

| Knob | Default | Safe range | Effect / failure at extremes |
|---|---|---|---|
| `RESISTANCE_MIN`/`MAX` | −3 / +3 | ±2 to ±4 | ★ The core dial. At ±1 types are noise; at ±5 they are hard counters and the matchup is decided before the attack |
| `AREA_AP_SURCHARGE` | +1 | 0–2 | At 0, area weapons are strictly better than single-target. At 3+ they cost most of a turn and nobody uses them |
| `LINE_DEFAULT_LENGTH` | 4 | 3–6 | At 6+ on a 12×10 board a strafing run crosses half the map and hits most of an army |
| `INCENDIARY` ignores cover | on | on/off | Off makes `INCENDIARY` a plain damage tilt with no identity |
| Friendly fire in areas | on | on/off | ★ Off makes area weapons decision-free. Strongly recommend on |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN an attacker with `damage_type = KINETIC` and a defender with no resistances, THEN damage equals the value the pre-damage-type formula produced (**regression: no shipped matchup changes**) | Logic |
| AC-2 | GIVEN `resistances[EMF] = 2` and an `EMF` attacker of attack 6 vs def 0 out of cover, THEN damage is 4 | Logic |
| AC-3 | GIVEN `resistances[EMF] = -2` and the same attacker, THEN damage is 8 | Logic |
| AC-4 | GIVEN resistance high enough to drive the result below 1, THEN damage is exactly `MIN_DAMAGE` (1) | Logic |
| AC-5 | GIVEN an `INCENDIARY` attacker and a unit on a cover tile, THEN `cover_reduction` is 0 | Logic |
| AC-6 | GIVEN a `KINETIC` attacker and the same defender, THEN `cover_reduction` is `COVER_DR` | Logic |
| AC-7 | GIVEN a structure defender, THEN `cover_reduction` is 0 for every damage type (Rule 6 preserved) | Logic |
| AC-8 | GIVEN a `BURST` attack, THEN every unit on the target tile and its orthogonal neighbours takes damage, each resolved through the standard formula | Integration |
| AC-9 | GIVEN a `BURST` containing a friendly unit, THEN that friendly takes damage | Integration |
| AC-10 | GIVEN an area attack, THEN all damage is computed before any death is applied, and results are identical across repeated runs of the same state | Logic |
| AC-11 | GIVEN a `LINE` attack toward the board edge, THEN it truncates at the edge with no error | Logic |
| AC-12 | GIVEN an area attack hitting multiple counter-capable defenders, THEN only the primary target may counterattack | Integration |
| AC-13 | GIVEN an area attack that would hit a friendly, THEN the UI warns before commit but does not block | UI (advisory) |
| AC-14 | GIVEN any `UnitTypeDef`, THEN every resistance value is within `[RESISTANCE_MIN, RESISTANCE_MAX]`, and out-of-band values fail load | Config-Data |
| AC-15 | GIVEN `preview_damage`, THEN its result equals the damage actually applied, including type and area terms | Integration |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| DTOQ-1 | ★ **Three types, or four?** The direction names EMF and napalm explicitly; `KINETIC` is the neutral baseline. A fourth (`EXPLOSIVE`, anti-structure) is tempting for the demolitions specialist — but the Protectorate's demolitions unit may be better expressed as **high attack vs structures via resistance on the structure side**, which needs no new type. Recommend holding at three | user + systems-designer | Before faction rosters |
| DTOQ-2 | ★★ **Does the AI need this before or after the factions ship?** An AI that ignores resistance will fire EMF into infantry all game and read as broken. It is the same shape of problem as OQ-15 in `faction-identity.md` and probably the same work item | ai-programmer | With OQ-15 |
| DTOQ-3 | **Should `EMF` disable rather than damage?** *"EMF damage indirect"* in the direction may mean a status effect (a stunned machine) rather than a damage tilt. Status effects are a **materially larger** system — durations, stacking, visual state, save/load — and none exists. Recommend damage-tilt for now and treat disable as a later ability | user | Faction authoring |
| DTOQ-4 | **Does area attack need `min_range`?** `combat-resolution.md` already has `min_range` for the artillery pattern. A burst mech at melee range and an artillery piece that cannot fire close are different profiles; both should be expressible | systems-designer | Faction authoring |
