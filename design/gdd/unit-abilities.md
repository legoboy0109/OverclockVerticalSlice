# Unit Abilities

> **Status**: **DRAFT** (2026-08-24) — Tier 1 of the faction corpus v2.
> **Author**: user (direction) + agents · **System #**: 19 (new)
> **Owning GDD for**: the ability catalogue, ability pricing, and the activation contract
>
> ★★ **This document is what makes CR-3 survivable.** `faction-identity.md` v2 narrowed CR-3 from
> *"a faction may never introduce a new verb"* to *"a faction may never introduce an **unpriced**
> verb"* — and that narrowing is only safe because **this document owns the catalogue and sets every
> price.** A faction picks from the catalogue (D8). It never adds to it. If factions could author
> abilities, CR-3 would be unenforceable and Pillar 1 would be a suggestion.

---

## Overview

**Unit Abilities** is the framework for actions beyond move and attack. It defines a **shared,
base-game catalogue** of abilities, each with a fixed AP and/or Credit price, and the rules by which
a unit activates one. A `UnitTypeDef` declares which catalogue entries it carries; a faction's
identity comes from *which of its units carry what* (D8), never from bespoke rules.

The user's direction requires this at once: the Solar Federation fields a **healer**, a **suicide
bomber** and a **pilot**; the Protectorate a **demolitions**, **anti-armour** and **support**
specialist; the Independents a **pirate** that steals vehicles. Under framework v1 every one of
those was illegal. Under v2 each is a catalogue entry with a price, available in principle to any
faction and granted in practice to the ones whose identity calls for it.

**The discipline that keeps this from becoming unbounded:** an ability is added to the catalogue by
ordinary design work, reviewed on its own merits, and **never as a side effect of authoring a
faction.** A faction GDD that needs a new ability blocks on this document being revised first.

## Player Fantasy

**The feeling: "my specialists change what is possible, not just what is efficient."**

Move and attack are a *rate*. An ability is a *possibility* — the healer means a wounded veteran is
worth retreating rather than spending, the pirate means an unattended tank is an opportunity rather
than scenery, the demolitions charge means a fortified position has an answer.

- **A reason to look at the board differently.** Each ability adds a question the player asks every
  turn once they own it.
- **Specialists as investments.** A support unit does nothing on its own — its value is entirely in
  what it enables, which is a genuinely different kind of unit to own and protect.
- **Legibility above all.** An ability that a player cannot predict the outcome of is a Pillar 2
  violation. Every ability here is deterministic and previewable.

## Detailed Rules

**AB-1 — An ability is a catalogue entry, owned here.** Each entry fixes: `id`, `ap_cost`,
`credit_cost`, `range`, `target_filter`, `cooldown`, `uses_per_match`, and its effect. Those values
are **base-game** and identical for every faction that carries the ability.

**AB-2 — A unit declares which entries it carries.** `abilities: List[AbilityId]` on `UnitTypeDef`.
A unit may carry zero or several.

**AB-3 — Every ability is priced in AP and/or Credits (CR-3).** `ap_cost ≥ 1` for every entry —
there are **no free abilities**. Some also cost Credits. A zero-cost ability is a schema error, not
a design choice.

**AB-4 — Activation is an action and follows the existing action contract.** An ability goes through
`apply_action` like move, attack, build and produce: validated, priced, committed, and announced as
an event. It respects the AP budget, the deficit lock where it costs Credits, and determinism.

**AB-5 — One activation per unit per turn**, unless the entry says otherwise. Combined with
`has_attacked`, a unit generally does one meaningful thing per turn.

**AB-6 — Abilities are deterministic and previewable.** No RNG (Pillar 2). Every ability exposes a
preview equivalent to `preview_damage` — the player sees the outcome before committing.

**AB-7 — Cooldowns and limited uses.** `cooldown` in turns (0 = none); `uses_per_match` (0 =
unlimited). Both are per-unit state, reset never within a match.

**AB-8 — Faction access (D8).** A faction grants abilities by putting them on its units. It may not
change a price, a range, or an effect. ★ **If a faction wants a cheaper heal, it does not get one —
it gets a unit that is cheaper, or tougher, or that also does something else.**

## The Catalogue

> Each entry states the faction need that motivated it. Entries are added by revising this document,
> never by a faction GDD.

| id | Effect | `ap_cost` | `credit_cost` | Range | Cooldown | Motivated by |
|---|---|---:|---:|---:|---:|---|
| `REPAIR` | Restore `REPAIR_AMOUNT` hp to one friendly unit. Cannot exceed max hp; cannot target self | 2 | **100** | 1 | 1 | Solar healer; Protectorate support |
| `DEMOLISH` | Attack with `DEMOLISH_BONUS` added vs **structures only**. No effect on units | 3 | 0 | 1 | 2 | Protectorate demolitions |
| `SELF_DESTRUCT` | Destroy self; deal `SELF_DESTRUCT_DAMAGE` in a `BURST` centred on self. ★ Hits friendlies (DT-8) | 1 | 0 | 0 | — (`uses_per_match` 1) | Solar suicide bomber |
| `CAPTURE_VEHICLE` | ★ **Board** an adjacent **unpiloted ground** vehicle: the actor moves into it and becomes its pilot, and ownership transfers with them. Ground only — an aircraft cannot be boarded. Subject to the new owner's population cap | 3 | 0 | 1 | 1 | ★ Independents pirate |
| `PARADROP` | Deploy a carried unit to any empty tile within `PARADROP_RANGE` of the transport, ignoring terrain and pathing | 3 | 0 | 3 | 2 | Solar paratrooper transport |
| `EMBARK` / `DISEMBARK` | Load into / unload from an adjacent transport. See `transport-and-pilots.md` | 1 | 0 | 1 | 0 | Alliance, Solar, Protectorate transports |
| `FORTIFY` | Gain `FORTIFY_DEFENSE` defense until the start of this unit's next turn. Ends if the unit moves | 1 | 0 | 0 | 0 | Machinist's Union early defence; Empire vehicles |
| `SPOT` | Extend one friendly unit's `attack_range` by `SPOT_BONUS` for this turn, if the target of that attack is adjacent to the spotter | 2 | 0 | 2 | 1 | Protectorate support; Alliance artillery |

**Constants:**

| Constant | Default | Note |
|---|---:|---|
| `REPAIR_AMOUNT` | **4** hp | Against an hp band of 6–14, meaningful without erasing a trade |
| `DEMOLISH_BONUS` | **+4** vs structures | HQ has 40 hp — a demolition unit should threaten it, not delete it. ★ Not a Credit value; unaffected by the ×100 rescale |
| `SELF_DESTRUCT_DAMAGE` | **6** | ★ Must not one-shot the roster's mid-tier or the ability becomes mandatory |
| `PARADROP_RANGE` | **3** tiles | |
| `FORTIFY_DEFENSE` | **+2** | Against a 2–6 attack band, a real but not absolute tilt |
| `SPOT_BONUS` | **+1** tile | |

> ### ★ `CAPTURE_VEHICLE` resolves as boarding, not as a remote seizure
>
> **Revised 2026-08-24** to match the direction's *"moving onto an unpiloted vehicle"*. The actor
> does not seize the vehicle from a distance — **it climbs in and becomes the crew.** Mechanically
> this is `EMBARK` into an enemy vehicle, plus an ownership transfer.
>
> Three things fall out of that, all of them good:
> 1. **The captor is now inside the tank**, so it is itself exposed to a `targets_crew` attack. The
>    vehicle can be stolen straight back by the same trick. ★ Symmetry that costs no extra rules.
> 2. **The captor is off the board as a separate unit** — it is cargo now (TP-1), untargetable
>    directly, and its own body is not available for anything else.
> 3. **No new occupancy rule is needed.** The tile stays one-occupant; the vehicle is the occupant
>    and the pirate is inside it.
>
> **Ground only.** An aircraft in flight cannot be boarded, which also means no faction's air is at
> risk of theft — a limit worth stating before someone designs around it.

> ★ **`CAPTURE_VEHICLE` is the entry to watch.** It is the only ability that transfers ownership of
> an existing asset, which means its value scales with *the opponent's* investment rather than the
> user's — the one shape that reliably becomes degenerate. Its guards: it requires an **unpiloted**
> vehicle (so the opponent must have made a mistake or taken a loss), costs 3 AP, has a cooldown,
> and is capped by population. **Watch it in playtest specifically.**

## Formulas

```
can_activate(unit, ability, target) =
    ability IN unit.abilities
    AND unit.ap_available >= ability.ap_cost
    AND owner.credits >= ability.credit_cost
    AND NOT owner.in_deficit                        (if ability.credit_cost > 0)
    AND unit.ability_used_this_turn == false
    AND unit.cooldown_remaining[ability] == 0
    AND unit.uses_remaining[ability] != 0
    AND distance(unit, target) <= ability.range
    AND target matches ability.target_filter

activate(unit, ability, target):
    spend ap_cost AP; spend credit_cost Credits
    apply effect (deterministic)
    unit.ability_used_this_turn := true
    unit.cooldown_remaining[ability] := ability.cooldown
    decrement uses_remaining if limited
    emit AbilityUsedEvent
```

`REPAIR`: `new_hp = min(max_hp, current_hp + REPAIR_AMOUNT)`
`DEMOLISH`: `damage = max(MIN_DAMAGE, effective_attack + DEMOLISH_BONUS − defense)` — structures are cover-immune, so no cover term
`SELF_DESTRUCT`: standard damage formula per target over `BURST`, then destroy self

## Edge Cases

- **`REPAIR` on a full-hp unit:** rejected at validation — spending AP for nothing is a trap, not a choice.
- **`REPAIR` on an enemy:** rejected by `target_filter`.
- **`SELF_DESTRUCT` adjacent to friendlies:** they take damage (DT-8). UI warns, does not block.
- **`SELF_DESTRUCT` as the last unit:** legal, and may lose the game. The player's call.
- **`DEMOLISH` targeting a unit:** rejected — it is structure-only, not merely structure-preferring.
- **`CAPTURE_VEHICLE` at population cap:** rejected (`population-cap.md` AC-10).
- **`CAPTURE_VEHICLE` on a *piloted* vehicle:** rejected. The pirate must first remove the pilot — that is the two-step play the direction describes (*"or by attacking the pilot directly and then taking control"*).
- **`PARADROP` onto an occupied tile:** rejected; the target must be empty and on-board.
- **`PARADROP` from a moving transport:** legal if the transport has AP; the drop is the carried unit's action, the AP is the transport's. ★ See ABOQ-2 — whose budget pays is genuinely ambiguous.
- **`FORTIFY` then move:** the bonus ends on the move, not at end of turn.
- **A unit with an ability it can never use** (e.g. `CAPTURE_VEHICLE` in a match with no vehicles): legal, simply inert.
- **Cooldown at end of match:** irrelevant; no state persists between matches.
- **An ability killing its own user** (`SELF_DESTRUCT`): the unit is removed after damage resolution, following `combat-resolution.md`'s death ordering so the death event fires correctly for the renderer's death echo.

## Dependencies

| System | Relationship |
|---|---|
| **Command & Action Interface** (#9) | ★ Hard — abilities are actions; needs targeting, preview, and an activation affordance per ability |
| **AP & Credits Economy** (#3) | Hard — AP and Credit pricing |
| **Unit Upkeep** (#15) | Hard — the deficit lock applies to Credit-costing abilities |
| **Combat Resolution** (#6) | Hard — `DEMOLISH` and `SELF_DESTRUCT` route through the standard damage formula |
| **Damage Types** (#18) | Hard — `SELF_DESTRUCT` uses `BURST` |
| **Transport & Pilots** (#20) | ★ Hard — `EMBARK`/`DISEMBARK`/`PARADROP`/`CAPTURE_VEHICLE` are all defined against it |
| **Population Cap** (#16) | Hard — `CAPTURE_VEHICLE` is capped |
| **Unit System** (#4) | Hard — `abilities` list, per-unit cooldown and uses state |
| **Game HUD** (#10) | ★ Hard — the HUD has **no ability affordance at all** today; this is real UI work |
| **AI Opponent** (#11) | ★★ Hard — the AI's action space is currently move/attack/build/produce/research. Every ability is a new branch it must score, and `CAPTURE_VEHICLE` in particular needs opponent-asset valuation it has no model for |
| **Faction Identity** (#12) | Hard — D8, access only |

## Tuning Knobs

| Knob | Default | Safe range | Effect / failure at extremes |
|---|---|---|---|
| `REPAIR_AMOUNT` | 4 | 2–6 | At 6+ against an 8-hp unit, healing outpaces damage and combat stalls — the failure mode a game that already struggles to resolve can least afford |
| `SELF_DESTRUCT_DAMAGE` | 6 | 4–8 | ★ At 8+ it one-shots most infantry and becomes the only Solar opening worth playing |
| `DEMOLISH_BONUS` | +4 | 2–6 | At 6+ a single specialist threatens an HQ too quickly; below 2 the ability is not worth its 3 AP |
| Ability `ap_cost` floor | 1 | fixed | ★ **Not tunable.** A 0-AP ability violates CR-3 |
| `uses_per_match` on `SELF_DESTRUCT` | 1 | fixed | The unit dies; more than 1 is meaningless |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN any catalogue entry, THEN `ap_cost ≥ 1` — a 0-AP ability fails load (CR-3 enforcement) | Config-Data |
| AC-2 | GIVEN a unit without an ability in its list, THEN activation is rejected | Logic |
| AC-3 | GIVEN insufficient AP, THEN activation is rejected and no state changes | Logic |
| AC-4 | GIVEN a Credit-costing ability and a player in deficit, THEN activation is rejected | Integration |
| AC-5 | GIVEN a unit that has activated this turn, THEN a second activation is rejected | Logic |
| AC-6 | GIVEN an ability on cooldown, THEN activation is rejected until the cooldown elapses | Logic |
| AC-7 | GIVEN `REPAIR` on a full-hp friendly, THEN it is rejected and no AP is spent | Logic |
| AC-8 | GIVEN `REPAIR` on a wounded friendly, THEN hp increases by `REPAIR_AMOUNT` capped at max | Logic |
| AC-9 | GIVEN `DEMOLISH` targeting a unit, THEN it is rejected | Logic |
| AC-10 | GIVEN `DEMOLISH` on a structure, THEN damage equals `max(1, atk + DEMOLISH_BONUS − defense)` | Logic |
| AC-11 | GIVEN `SELF_DESTRUCT`, THEN every unit in the burst including friendlies takes damage, and the user is destroyed after damage resolves | Integration |
| AC-12 | GIVEN `CAPTURE_VEHICLE` on a piloted vehicle, THEN it is rejected | Integration |
| AC-13 | GIVEN `CAPTURE_VEHICLE` on an adjacent unpiloted **ground** vehicle with a free population slot, THEN the actor becomes its pilot, ownership transfers, and the actor is thereafter carried (untargetable directly) | Integration |
| AC-13b | GIVEN `CAPTURE_VEHICLE` targeting an **aircraft**, THEN it is rejected | Logic |
| AC-13c | GIVEN a captured vehicle whose new pilot is killed by a `targets_crew` attack, THEN the vehicle becomes unpiloted again and is capturable by either side | Integration |
| AC-14 | GIVEN `CAPTURE_VEHICLE` with the new owner at cap, THEN it is rejected | Integration |
| AC-15 | GIVEN identical state and identical activation, THEN results are identical across runs (no RNG) | Logic |
| AC-16 | GIVEN any ability, THEN a preview is available whose stated outcome matches the applied outcome | Integration |
| AC-17 | GIVEN a `FactionDef` whose unit references an ability id absent from the catalogue, THEN load fails (CR-8) | Config-Data |
| AC-18 | GIVEN two factions carrying the same ability, THEN its cost, range and effect are identical for both (CR-3(c) — no faction re-prices a verb) | Config-Data |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| ABOQ-1 | ★★ **Is eight entries the right catalogue size for a first pass?** Each is a new action branch in the FSM, the HUD, the AI and the test suite. Eight roughly triples the game's action space. Recommend implementing in waves — `EMBARK`/`DISEMBARK`/`REPAIR` first (needed by the most factions), `CAPTURE_VEHICLE` last (most degenerate potential) | producer + user | Sprint planning |
| ABOQ-2 | **Whose AP does `PARADROP` spend — the transport's or the passenger's?** Transport's is simpler and matches the "the transport does the dropping" reading; passenger's makes a full transport more flexible. Genuinely ambiguous in the direction | systems-designer | With `transport-and-pilots.md` |
| ABOQ-3 | ★ **Does `REPAIR` break the game's ability to resolve?** The PIVOT was caused by matches that never end. A healer is, structurally, a mechanism for making combat *less* decisive. `REPAIR_AMOUNT` must be tuned against the damage band deliberately, and the AI-vs-AI regression must be re-run with a healer present | economy-designer + systems-designer | Before Solar Federation ships |
| ABOQ-4 | **Should abilities be a separate budget from `has_attacked`?** AB-5 makes them compete, so a healer that heals cannot also shoot. That is probably right for specialists, but it makes a generalist carrying one ability strictly worse than one without | systems-designer | Playtest |
