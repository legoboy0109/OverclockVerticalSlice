# Population Cap

> **Status**: **DRAFT** (2026-08-24) — Tier 1 of the faction corpus v2.
> **Author**: user (direction) + agents · **System #**: 16 (new)
> **Owning GDD for**: the infantry cap, its raise curve, and cap exemption
>
> ★ **Paired system.** Population Cap and `unit-upkeep.md` both bound army size and must be tuned
> together: **the cap says how many units you may field, upkeep says how long you can afford them.**
> A cap set below the upkeep equilibrium makes upkeep inert; a cap far above it is decorative.
> Owned as **OQ-13** in `faction-identity.md`. **User confirmed this split, 2026-08-24.**

---

## Overview

**Population Cap** limits how many units a player may have on the board at once, independently of
whether they can afford them. It exists for three reasons, in order of importance:

1. **It is a primary faction identity lever.** Three of the six factions define themselves partly
   through it — the **Solar Federation** has a higher cap than anyone (its thesis is *volume*), the
   **Independents** have a lower one that is expensive to raise (few but exceptional), and the
   **Galactic Protectorate**'s robots are **cap-exempt** but less economical, which is the entire
   shape of that faction's tradeoff.
2. **It bounds the board, not the wallet.** Upkeep bounds what you can *sustain*; the cap bounds
   what can be *present*. Without it, a rich player on a 12×10 board can simply flood it, and the
   game becomes a stacking problem rather than a positional one.
3. **It makes unit quality meaningful.** If you can field unlimited bodies, a strong expensive unit
   is never worth more than several cheap ones. A cap is what makes "better unit" a real category
   rather than an efficiency calculation.

The cap is **raisable** — it is a thing you invest in, not a fixed wall — and the *cost curve* of
raising it is itself a faction lever.

## Player Fantasy

**The feeling: "my army has a shape I chose, not just a size I could afford."**

A cap forces composition decisions. With 8 slots, taking a Heavy means not taking two Scouts, and
that is a real strategic identity rather than an arithmetic one. The intended feelings:

- **Scarcity of slots, not just Credits.** Losing a unit hurts in a second, distinct way — you lost
  a *slot's worth of investment*, and the replacement costs time as well as money.
- **Investment tension.** Raising the cap competes directly with using the army you already have.
  Spending on capacity is spending on the future, which is exactly the tempo tradeoff Pillar 1
  cares about.
- **Faction character felt immediately.** A Solar Federation player should notice they can field
  more bodies within the first few turns; an Independents player should feel every slot is precious.
- **★ For the Protectorate specifically:** the fantasy is *"my humans are precious and my machines
  are expendable."* Cap-exempt robots mean the player can always field *something*, but doing so
  quietly bleeds them — a texture no other faction has.

## Detailed Rules

**PC-1 — The cap counts living units, not structures.** Structures are bounded by Base &
Production's `production_cap` and by build costs; they are not in scope here.

**PC-2 — The cap is checked at production, not continuously.** A player may not produce a unit that
would take them above their cap. A player *already* above their cap (possible only via a cap
reduction, PC-6) is not forced to lose units — they simply cannot produce until back under.

**PC-3 — Units under production count against the cap.** A unit in a producer's queue occupies its
slot from the moment production is committed. *Rationale: otherwise a player queues past the cap and
the check does nothing.*

**PC-4 — Exemption is a per-unit property, not a per-faction one.** A `UnitTypeDef` declares
`counts_toward_cap: bool`. This is what makes the Protectorate's robots work, and it is available to
any faction's unit design (CR-9 — general machinery, faction access).

**PC-5 — The cap is raised by investment.** A player raises their cap by `CAP_RAISE_STEP` units per
purchase, at a cost that **escalates**:

> Escalating rather than flat is deliberate. A flat cost makes "buy capacity forever" strictly
> correct once income allows it, which recreates the unbounded-economy failure the PIVOT identified,
> one layer up. An escalating curve gives capacity a natural stopping point.

**PC-6 — The cap can fall.** If the structure or tech granting capacity is destroyed or lost, the
cap drops. Units above the new cap are **not destroyed** (see PC-2) — the player is production-locked
until attrition brings them under. ★ This is a genuine strategic target: attacking capacity is a way
to attack an army's *future* rather than its present, and it is the mechanism that makes the Holy
Cosmic Empire's stated *"highly vulnerable to tech base disruption"* real.

**PC-7 — Faction access (D3).** A faction sets `base_infantry_cap`, the `cap_raise_cost_curve`
parameters, and — through its own unit definitions — which of its units are exempt.

## Formulas

```
effective_cap(player) = base_infantry_cap(faction_of(player))
                      + CAP_RAISE_STEP × cap_purchases(player)
                      + Σ cap_bonus(s) for every COMPLETED structure s owned by player

current_population(player) = count of units u owned by player
                             where u.is_alive AND u.counts_toward_cap
                             (includes units in production, PC-3)

can_produce(player, unit)  = (not unit.counts_toward_cap)
                             OR (current_population(player) + 1 <= effective_cap(player))

cap_raise_cost(player)     = CAP_RAISE_BASE_COST
                             + CAP_RAISE_ESCALATION × cap_purchases(player)
```

**Baseline values** (Democratic Alliance = the balance reference, CR-10):

| Constant | Default | Note |
|---|---:|---|
| `base_infantry_cap` | **6** | The Alliance baseline |
| `CAP_RAISE_STEP` | **2** | Units gained per purchase |
| `CAP_RAISE_BASE_COST` | **8** Credits | First raise |
| `CAP_RAISE_ESCALATION` | **4** Credits | Added per prior purchase |
| `CAP_HARD_CEILING` | **14** | Absolute maximum regardless of purchases |

**The raise curve, worked:** 8 → 12 → 16 → 20 Credits for caps of 8 → 10 → 12 → 14.
Cumulative cost to reach the ceiling: **56 Credits.**

> ★ **Cross-check against upkeep — these two numbers must agree.** `unit-upkeep.md` puts the
> equilibrium army at **7–9 units** at a developed economy. The baseline cap of 6, raisable to
> 8–10 for 8–20 Credits, sits **just under to just at** that equilibrium. That is the intended
> relationship: **the cap binds first, and upkeep binds shortly after.** A player raising their cap
> is deliberately buying their way into a position where upkeep starts to hurt — which is a real
> decision rather than a free upgrade. If either number moves, re-check this paragraph.

**Per-faction caps** (provisional — CR-10 comparison owed):

| Faction | `base_infantry_cap` | Raise cost | Note |
|---|---:|---|---|
| Democratic Alliance | 6 | baseline | The reference |
| Solar Federation | **8** | baseline | ★ Its *actual* differentiator — see OQ-14 |
| Galactic Protectorate | 5 | baseline | Low, but robots are exempt |
| Holy Cosmic Empire | 6 | baseline | Cap is not its lever; promotion is |
| Independents | **4** | **×1.5 escalation** | Few but exceptional; capacity is expensive |
| Machinist's Union | 5 | baseline | Vehicles carry its weight, not infantry |

## Edge Cases

- **Producing a cap-exempt unit while at cap:** permitted (PC-4). This is the Protectorate's core loop.
- **A player above cap after a cap reduction:** no forced losses; production-locked until under (PC-2/PC-6).
- **Cancelling a queued unit:** frees its slot immediately (mirrors Base & Production's cancel/refund).
- **A unit destroyed while in production:** frees its slot; the producer's queue entry is voided.
- **Raising the cap at the hard ceiling:** the purchase is rejected, not silently consumed.
- **Cap of 0:** legal only if every one of the faction's units is exempt; otherwise load fails, since a faction that cannot field an army is a data error.
- **Transported units** (`transport-and-pilots.md`): a unit inside a transport **still counts**. It exists, it just is not standing on a tile. *Rationale: otherwise loading a transport is a cap-dodge.*
- **A pilot ejected from a destroyed vehicle:** if the pilot becomes a unit, it takes a slot; if none is free, ★ see **PCOQ-2**, which is unresolved.
- **Stolen units** (Independents' pirate): count against the **new** owner's cap. Stealing while at cap is rejected — a real constraint on the pirate, and probably a good one.

## Dependencies

| System | Relationship |
|---|---|
| **Base & Production** (#7) | Hard — the production gate is enforced at the produce call site |
| **Unit System** (#4) | Hard — `counts_toward_cap` on `UnitTypeDef` |
| **Unit Upkeep** (#15) | ★ Hard, paired — the two bounds must be tuned together (OQ-13) |
| **Research/Tech** (#8) | Soft — techs may grant `cap_bonus`; the Empire's spine depends on it |
| **Faction Identity** (#12) | Hard — D3 |
| **Game HUD** (#10) | Hard — current/max population must be visible at all times; a player who cannot produce must be told *why* |
| **AI Opponent** (#11) | Hard — must respect the cap and must value raising it. ★ It currently has no concept of a bounded army |
| **Transport & Pilots** (#20) | Soft — carried units count; ejected pilots are PCOQ-2 |

## Tuning Knobs

| Knob | Default | Safe range | Effect / failure at extremes |
|---|---|---|---|
| `base_infantry_cap` | 6 | 3–10 | ★ Primary faction lever. Below 3 the board feels empty and single losses are catastrophic; above 10 the cap stops binding before upkeep does and becomes decorative |
| `CAP_RAISE_STEP` | 2 | 1–3 | At 1 raising feels pointless; at 4+ a single purchase transforms the game |
| `CAP_RAISE_BASE_COST` | 8 | 5–15 | Below 5 raising is auto-correct; above 15 nobody raises and the cap is a fixed wall |
| `CAP_RAISE_ESCALATION` | 4 | 2–8 | ★ The brake. At 0 the curve is flat and "buy capacity forever" returns — the PIVOT failure one layer up |
| `CAP_HARD_CEILING` | 14 | 10–20 | The absolute backstop. Should sit above where upkeep already makes expansion painful, so it rarely binds |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a player at `current_population == effective_cap`, WHEN they attempt to produce a cap-counting unit, THEN it is rejected with a reason naming the cap | Integration |
| AC-2 | GIVEN the same state, WHEN they produce a unit with `counts_toward_cap = false`, THEN it succeeds | Integration |
| AC-3 | GIVEN a unit committed to production, THEN `current_population` includes it before it is deployed | Logic |
| AC-4 | GIVEN a queued unit is cancelled, THEN `current_population` decreases by 1 immediately | Logic |
| AC-5 | GIVEN `cap_purchases = k`, THEN `cap_raise_cost` equals `CAP_RAISE_BASE_COST + CAP_RAISE_ESCALATION × k` | Logic |
| AC-6 | GIVEN a player at `CAP_HARD_CEILING`, WHEN they attempt to raise, THEN it is rejected and no Credits are spent | Logic |
| AC-7 | GIVEN a structure granting `cap_bonus` is destroyed, THEN `effective_cap` decreases by that bonus and no owned unit is destroyed | Integration |
| AC-8 | GIVEN a player above cap after such a loss, THEN production is rejected until `current_population < effective_cap` | Integration |
| AC-9 | GIVEN a unit loaded into a transport, THEN it still counts toward the cap | Integration |
| AC-10 | GIVEN a pirate stealing a unit while its new owner is at cap, THEN the steal is rejected | Integration |
| AC-11 | GIVEN any `FactionDef`, THEN `base_infantry_cap ≥ 0`, and a cap of 0 fails load unless every unit in that faction's roster is cap-exempt | Config-Data |
| AC-12 | GIVEN a player at cap, THEN the HUD shows current/max population and the produce affordance is visibly disabled with a stated reason | UI (advisory) |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| PCOQ-1 | ★ **Does the cap cover vehicles and air, or infantry only?** The user's direction says *"infantry cap"* throughout, which implies vehicles are bounded by cost and upkeep alone. That is coherent — but it means a vehicle-heavy faction (Machinist's Union) is effectively uncapped, and the Union is *already* the late-game faction. Recommend either a **separate vehicle cap** or making vehicles cost multiple infantry slots. **Design call — the user's** | user | Before `factions/machinists-union.md` |
| PCOQ-2 | **What happens to a pilot ejected into a full population?** Options: the pilot is lost, the eject is blocked (the vehicle cannot be abandoned), or the cap is temporarily exceeded. Interacts with the Independents' pirate, which is built on unpiloted vehicles | systems-designer | With `transport-and-pilots.md` |
| PCOQ-3 | **Is the cap raised by a purchase, a structure, or a tech?** Formulas support all three. A structure is the most attackable (good — PC-6) and the most legible; a tech fits the Empire best. Recommend **structure-granted, with tech modifiers** | systems-designer | With `factions/*.md` |
