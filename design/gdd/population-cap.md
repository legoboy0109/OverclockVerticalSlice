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

**PC-5 — ★ The cap is raised by building Barracks, and Barracks are capped in number.** *(User
decision, 2026-08-24 — resolves PCOQ-3. Supersedes the earlier purchase-curve model.)*

Each completed **Barracks** — the reworked Production Outpost — grants `cap_per_barracks` additional
infantry slots. A faction may build at most **`max_barracks`**, a per-faction value (D3).

> ★ **Why a hard per-faction maximum rather than an escalating cost curve.** An escalating cost is a
> *soft* brake that a rich player eventually buys through — and the PIVOT verdict is precisely about
> a game where the rich player never stops buying. A hard count is unambiguous, is legible to the
> player ("2 of 3 Barracks"), takes a *known* amount of map space, and is a clean faction lever: the
> Independents' *"lower base infantry cap and more expensive to increase the cap"* becomes a low
> `max_barracks`, which is far easier to reason about than a cost curve.
>
> **It is also attackable** (PC-6). Destroying a Barracks lowers the enemy's cap — a way to attack an
> army's future rather than its present, which is exactly the kind of reason-to-attack the PIVOT
> found the game lacking.

**PC-6 — The cap can fall.** If the structure or tech granting capacity is destroyed or lost, the
cap drops. Units above the new cap are **not destroyed** (see PC-2) — the player is production-locked
until attrition brings them under. ★ This is a genuine strategic target: attacking capacity is a way
to attack an army's *future* rather than its present, and it is the mechanism that makes the Holy
Cosmic Empire's stated *"highly vulnerable to tech base disruption"* real.

**PC-7 — Faction access (D3).** A faction sets `base_infantry_cap`, its **`max_barracks`**, the
`cap_per_barracks` value, and — through its own unit definitions — which of its units are exempt.

**PC-8 — ★ Vehicles are capped through their crew, not directly.** *(User decision, 2026-08-24 —
resolves PCOQ-1.)* The cap counts **infantry only**. Vehicles and aircraft are never counted
directly. They are bounded instead by the fact that **a vehicle with `requires_pilot = true` consumes
an infantry slot for its pilot** (`transport-and-pilots.md` TP-1: a crewing unit is carried, and
carried units count).

> ★ **Why this is the right shape.** It needs no new machinery, and it makes the tradeoff *legible
> in the fiction*: a tank is not abstractly "worth three infantry", it literally takes a soldier off
> the line to drive it. It also gives `requires_pilot` a second, larger job — it is no longer just a
> vulnerability (crew-killing, capture) but **the primary limiter on how much armour a faction can
> field at once.**
>
> **Consequence for the Galactic Protectorate:** its autonomous units escape this on *both* counts —
> `counts_toward_cap = false` for its robotic infantry, and `requires_pilot = false` for its
> autonomous mechs, so they consume no slot even indirectly. That is a genuinely large advantage,
> and **upkeep is the only thing paying for it.** ★ Flag for CR-10's comparison sheet: the
> Protectorate is the faction most likely to come out over-tuned, and this is the axis to check.
>
> **Consequence for the Machinist's Union:** its vehicles are powerful but each one costs a body,
> so a Union army is *small and heavy* rather than merely heavy. That matches its stated thesis
> better than an uncapped vehicle count would have.

## Formulas

```
effective_cap(player) = base_infantry_cap(faction_of(player))
                      + cap_per_barracks × completed_barracks_count(player)
                      + Σ cap_bonus(t) for every completed tech t held by player

can_build_barracks(player) = completed_barracks_count(player)
                             + under_construction_barracks_count(player)
                             < max_barracks(faction_of(player))

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
| `base_infantry_cap` | **4** | The Alliance baseline, with no Barracks built |
| `cap_per_barracks` | **2** | Infantry slots per completed Barracks |
| `max_barracks` (Alliance) | **3** | ★ Per-faction (D3) |
| Barracks `build_cost` | **6** Credits | Unchanged from the Production Outpost it replaces |
| Barracks `produces_classes` | `{INFANTRY}` | ★ Vehicles need a Factory, aircraft an Airfield (`base-production.md` BP-NEW-1) |
| Barracks `upkeep` | **1** | Unchanged |

**Worked, Alliance:** 4 base + (3 Barracks × 2) = **10 infantry** at full build-out, for
**18 Credits** and 3 tiles of map. The cap is now a *known, bounded, visible* quantity — a player
can look at the board and know both sides' ceilings.

> ★ **Cross-check against upkeep — these two numbers must agree.** `unit-upkeep.md` puts the
> equilibrium army at **7–9 units** at a developed economy. An Alliance player at full build-out
> caps at **10 infantry**, plus whatever vehicles their remaining slots crew. That sits **just above**
> the upkeep equilibrium, which is the intended relationship: **you can build to your cap, but you
> cannot comfortably sustain a full one.** The cap is the wall; upkeep is what makes you stop before
> you reach it. If either number moves, re-check this paragraph.
>
> ✅ **Re-checked 2026-08-24 against the new research-driven income.** At a fully-researched economy
> (income **25**) with a realistic build (2 Barracks, 1 Factory, 1 Lab = 6 upkeep), **19** Credits
> are available for an army, sustaining **8–9 units** at a roster mean upkeep of ~2. The Alliance's
> full-build-out cap is **10 infantry**. The relationship holds: **cap 10, sustainable 8–9** — you
> can always field a little more than you can comfortably keep.

**Per-faction caps** (provisional — CR-10 comparison owed):

| Faction | `base_infantry_cap` | `max_barracks` | Ceiling | Note |
|---|---:|---:|---:|---|
| Democratic Alliance | 4 | 3 | **10** | The reference |
| Solar Federation | **5** | **4** | **13** | ★ Its *actual* differentiator — volume (see OQ-14) |
| Galactic Protectorate | 3 | 2 | **7** | Low — but its robots are cap-exempt *and* pilot-free (PC-8) |
| Holy Cosmic Empire | 4 | 3 | **10** | Cap is not its lever; promotion is |
| Independents | **3** | **2** | **7** | Few but exceptional; capacity is genuinely scarce |
| Machinist's Union | 4 | 2 | **8** | ★ Small army — and every vehicle spends one of those slots on a crew |

## Edge Cases

- **Producing a cap-exempt unit while at cap:** permitted (PC-4). This is the Protectorate's core loop.
- **A player above cap after a cap reduction:** no forced losses; production-locked until under (PC-2/PC-6).
- **Cancelling a queued unit:** frees its slot immediately (mirrors Base & Production's cancel/refund).
- **A unit destroyed while in production:** frees its slot; the producer's queue entry is voided.
- **A vehicle produced with no free infantry slot for its crew:** ★ rejected. Producing a `requires_pilot` vehicle requires an available slot for the pilot, or an existing free pilot to crew it — otherwise a player could build armour they can never operate. See PCOQ-4.
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
| ~~PCOQ-1~~ | ✅ **RESOLVED 2026-08-24 (user): infantry cap only — and vehicles are bounded *through their crew*.** Neither a separate vehicle cap nor a multi-slot cost is needed, because **a vehicle requires a pilot, a pilot is infantry, and infantry are capped** (PC-8). Fielding a tank spends an infantry slot on its crew. ★ This is a better answer than either option offered: it needs no new machinery, it makes `requires_pilot` load-bearing rather than flavour, and it gives the Protectorate's autonomous robots a *second* distinct meaning — they escape the cap on both counts and pay in upkeep. See PC-8 | — | ✅ closed |
| ~~PCOQ-2~~ | ✅ **DISSOLVED 2026-08-24 by PC-8.** The question assumed a crewing pilot might not hold a slot. It does — a pilot is carried and carried units count (TP-1) — so a pilot leaving its vehicle needs no *new* slot and the disembark always succeeds. The abandoned vehicle needs none either, since vehicles are never counted directly. ★ A player at cap may therefore abandon a vehicle to return its crew to the line, which is a genuine tactical option rather than an edge case | — | ✅ closed |
| ~~PCOQ-3~~ | ✅ **RESOLVED 2026-08-24 (user): a structure — the Barracks**, which is the reworked Production Outpost, with a **per-faction maximum quantity**. This is the attackable option PC-6 wanted, and the per-faction max is a clean new identity lever (D3) | — | ✅ closed |
