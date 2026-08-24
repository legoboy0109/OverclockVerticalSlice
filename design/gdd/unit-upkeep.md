# Unit Upkeep

> **Status**: **DRAFT** (2026-08-24) — authored as Tier 1 of the faction corpus v2.
> **Author**: user (direction: "upkeep sounds right") + agents
> **System #**: 15 (new) · **Owning GDD for**: the Credit drain, `net_credit_income`, per-entity `upkeep`
>
> ★ **This is the one Tier-1 document that gets implemented in Sprint 6.** The other six are design
> ahead of build. It is written to a higher standard for that reason, and its Acceptance Criteria
> are meant to be turned directly into tests.
>
> **Why this system exists — measured, not speculative.** The vertical slice returned a **PIVOT**
> verdict (`production/vertical-slice/REPORT.md`). Root cause, in one sentence: *the economy is
> unbounded, so building always outscores fighting, so nobody ever marches on the objective, so no
> game is ever won.* Credits peaked at **5,724** on one side and were still climbing linearly at
> turn 200; economy actions outscored manoeuvring by **12–20×** and, with an unbounded stock, were
> permanently affordable. **The game has faucets and no drains. This is the drain.**

---

## Overview

**Unit Upkeep** turns Credit income from a *gross* faucet into a **net** one. Every unit and most
structures carry an `upkeep` value in Credits; at each player's start of turn the sum of their
upkeep is subtracted from their income before anything is banked. What you keep is what is left
over.

This does three things the game currently cannot do:

1. **It bounds the stock.** An army is not a one-time purchase but a standing commitment, so Credits
   can no longer accumulate without limit. There is an **equilibrium army size** at which income and
   upkeep meet, and past it, expanding makes you poorer.
2. **It is one half of the economy's bound — the other half is the finite research tree.** Income
   plateaus at a hard 25/turn once the three economy tiers are researched (`research-tech.md`);
   upkeep is what stops the plateau from simply accumulating. ★ **Neither half works alone**, and
   the pairing is the design. See § "The economy's ceiling".
3. **It creates the comeback pressure the swing-back playtest has never been able to find.** A
   losing player's smaller army is *cheaper to sustain*, so falling behind partially pays for
   itself. Losing units is not purely bad news. This is the mechanism S5-04 was written to measure
   and could not, because it did not exist.

Upkeep is also the domain (**D9**) through which several factions express their central tradeoff:
the Galactic Protectorate's robots dodge the population cap and pay for it in upkeep; the
Machinist's Union's vehicles are powerful and expensive to keep running.

## Player Fantasy

**The feeling: "this army is mine to keep — and keeping it costs me."**

Before upkeep, a produced unit was free forever. The only question was whether you could afford the
purchase. That makes every acquisition strictly good and turns the game into an accumulation race
with no reason to ever commit — which is precisely what the simulation measured.

With upkeep, an army is a *position you are holding*, and holding it has a rate. The intended
feelings:

- **Weight.** Fielding a Heavy is a decision you keep making every turn, not once.
- **Pressure to use what you bought.** An idle army is a bleeding wound. If you have paid for
  eleven turns of a standing force, you want it *doing* something — which is the exact pressure the
  game currently lacks.
- **Relief in loss, occasionally.** Losing an over-extended army hurts, but it also lightens the
  load. That ambivalence is the emotional signature of a good attrition economy, and it is where
  comebacks come from.
- **A real ceiling you can feel approaching.** As net income narrows toward zero, the player should
  *notice* — which is a HUD requirement, not just a maths one.

**The failure mode to avoid: upkeep as pure nuisance.** If it reads as a tax that punishes play
without changing decisions, it has failed. The test is whether players start making *different*
choices — disbanding, trading, timing attacks around their income — not whether they complain about
the number.

## Detailed Rules

**UR-1 — Every entity declares an `upkeep`.** `upkeep: int ≥ 0`, in Credits per turn, on
`UnitTypeDef` and `StructureDef`. It is data, never computed at runtime from anything mutable.

**UR-2 — Upkeep is charged at start of turn, against income, per player.** At a player's
start-of-turn economy step, `net_credit_income` (Formulas) is added to their banked Credits. Upkeep
is **never** charged at any other time — not on production, not on the opponent's turn, not
mid-turn. One charge, one moment, once per player per round.

**UR-3 — Only *completed*, *living* entities pay.** An entity pays upkeep from the turn after it
becomes active and stops the moment it is destroyed.
- A unit pays from the start-of-turn **after** the turn it was produced. You never pay upkeep on a
  unit the same turn you bought it.
- A structure **under construction pays nothing.** It begins paying the first start-of-turn at which
  its `build_status` is `COMPLETED`. *(Rationale: `build_time` is already a deliberate
  vulnerable-investment window per Base & Production; charging upkeep during it double-taxes the
  same design intent.)*
- A destroyed entity pays nothing from that moment on, including the same turn it died.

**UR-4 — The HQ never pays upkeep.** It cannot be voluntarily given up, so charging for it is a flat
tax on existing, not a decision. `upkeep = 0`, fixed, not a faction lever.

**UR-5 — ★ Every structure except the HQ pays upkeep.** *(Rewritten 2026-08-24. This rule
originally argued that Economy Outposts specifically must pay; that structure has since been
deleted, but the general principle it rested on is what survives and it is the important half.)*

**A structure that generates value must still cost something to hold**, or the optimal line is to
build it repeatedly and never field an army. That is the degenerate strategy this system exists to
kill, and it is not specific to any one structure — it would re-emerge around the Research Lab, the
Barracks, or anything else exempted.

The **Research Lab in particular pays upkeep (2)** even though it is now the sole engine of economic
growth. Exempting it would make "build a Lab, research everything, sit" free, which is the same
failure in a new costume.

Only the HQ is exempt, and only because it cannot be given up (UR-4).

**UR-6 — Deficit: the bank drains, then production locks.** When `total_upkeep > credit_income`, net
income is negative and the shortfall is drawn from banked Credits.
- Banked Credits **floor at 0** and never go negative.
- While a player is **in deficit** — meaning their bank is 0 and their upkeep still exceeds their
  income — they **cannot produce, build, or research.** Every other action (move, attack, disband)
  remains available.
- There is **no attrition, no forced disband, and no unit destruction from unpaid upkeep.** A death
  spiral is not a comeback mechanism; it is the opposite of one, and this system's whole purpose is
  to *create* comeback pressure. A player in deficit is locked out of expanding until they lose
  units or take ground, both of which resolve it naturally.

**UR-7 — Disband.** A player may voluntarily destroy their own unit, costing `DISBAND_AP_COST` AP
and refunding `DISBAND_REFUND_RATE` × its `produce_cost` in Credits (rounded down).
- This is the escape valve UR-6 needs — without it, a player who over-extends has no *agency* in
  fixing it, only the hope of losing units in combat.
- It is a **priced verb** (AP cost, partial refund), so it satisfies CR-3. It is **base-game content
  available to every faction**, per CR-9 — not a faction ability.
- It cannot target an enemy unit, a structure, or the HQ.

**UR-8 — Upkeep is visible before it is paid.** The player must be able to see their gross income,
total upkeep and net income **during their turn**, before the charge lands, and must be able to see
what a prospective purchase would do to that net figure before committing. A drain the player
discovers only after it has happened is a feel-bug, not a mechanic. *(Contract on Game HUD; see
Dependencies.)*

**UR-9 — Faction access (D9).** A faction owns its units' `upkeep` values directly (D9-own, since it
owns the units) and may additionally carry a global `Δ_upkeep_rate` (D9-mod) applied to the derived
default. Every authored value is subject to the schema floor `upkeep ≥ 0` at load.

## Formulas

### Net income — the one formula that matters

```
total_upkeep(player)      = Σ upkeep(e) for every entity e owned by player
                            where e.is_alive AND e.build_status == COMPLETED AND e.kind != HQ

net_credit_income(player) = credit_income(player) − total_upkeep(player)

banked_credits(player)   := max(0, banked_credits(player) + net_credit_income(player))
```

`credit_income(player)` is **unchanged** and still owned by AP & Credits Economy — the full four-term
formula including the Economy-Tech term and its tier cap. Upkeep subtracts from its result; it never
reaches inside it.

### Default upkeep — derived, then overridable

```
default_upkeep(entity) = ceil(produce_cost(entity) / UPKEEP_DIVISOR)
```

with `UPKEEP_DIVISOR = 3`. Any entity may override the derived value with an explicit `upkeep`; the
derivation exists so that a designer authoring a new unit gets a sane number for free and only
overrides it deliberately.

**Against the current roster:**

| Unit | `produce_cost` | derived `upkeep` |
|---|---:|---:|
| Scout | 2 | **1** |
| Trooper | 4 | **2** |
| Sniper | 5 | **2** |
| Heavy | 7 | **3** |

| Structure | `build_cost` | `upkeep` | Note |
|---|---:|---:|---|
| HQ | — | **0** | UR-4, fixed — the only exemption |
| Barracks *(was Production Outpost)* | 6 | **1** | Max 3 (Alliance); also grants infantry cap |
| Factory | 10 | **2** | Max 2; produces ground vehicles |
| Airfield | 12 | **2** | Max 1; produces aircraft |
| Research Lab | 8 | **2** | ★ Pays despite being the economy engine — UR-5 |
| Defensive Structure | 5 | **1** | Max 3 |
| ~~Economy Outpost~~ | ~~6~~ | ~~1~~ | **DELETED 2026-08-24** — income moved to research |

*(Structure values are authored, not derived — `build_cost` and `produce_cost` are different scales.)*

### ★★ The economy's ceiling — SUPERSEDED and replaced, 2026-08-24

> **What this section used to say, and why it is gone.** The original draft derived a self-bounding
> property from the Economy Outpost income curve: income tiered down (+2 per outpost for the first
> four, +1 after) while upkeep stayed flat at 1, so the fifth outpost was net-zero and the economy
> found its own ceiling. **That mechanism no longer exists — the user re-based income onto research
> and deleted the Economy Outpost on 2026-08-24.** There is no outpost count to tier against.
>
> ★ **It has been replaced by something strictly stronger, so this is an upgrade rather than a
> loss.** The tiering curve was a *soft* brake — it flattened the growth but never stopped it, and a
> patient player still accumulated forever, just more slowly. Research is **finite**:

```
credit_income(player) = BASE_INCOME (10) + Σ ECON_TIER_BONUS for each completed economy tier
                      = 10, 15, 20, or 25.  Nothing else.  Ever.
```

**Three tiers exist. Once all three are researched, the economy cannot grow again at any price.**
That is a hard ceiling, not an asymptote — and it is the property this system needed.

**The bound now has two independent halves, and both are needed:**

| Half | Mechanism | What it stops |
|---|---|---|
| **Income ceiling** | Finite research tiers — max 25/turn (`research-tech.md`) | The *rate* growing without limit |
| **Upkeep drain** | This document | The *stock* accumulating without limit |

Neither alone is sufficient. A hard income ceiling with no drain still accumulates — just linearly
at a fixed rate, which is exactly what the simulation measured at 5,724 and climbing. A drain with
no ceiling loses to any income curve that outruns it. **Together, income plateaus at 25 and upkeep
eats most of it, so banked Credits stabilise instead of climbing.**

### Worked — where the Credits actually go

At full research (income **25**) with a realistic Alliance build (2 Barracks, 1 Factory, 1 Research
Lab):

```
gross income            25
structure upkeep       − 6   (Barracks 1+1, Factory 2, Lab 2)
                       ────
available for army      19
army of 8 @ mean 2     −16
                       ────
net per turn            +3
```

**A player at a developed position banks about 3 Credits a turn, not 30.** And at full structural
build-out (10 structures, 14 upkeep) they are *negative* before fielding a single soldier — which is
why `base-production.md`'s per-faction structure maximums and this system are one design, not two.

### Equilibrium army size — the number to tune against

At a fully-researched economy (income 25) with a realistic build (2 Barracks, 1 Factory, 1 Lab):

```
credit_income    = 25          (BASE_INCOME 10 + three economy tiers × 5)
structure_upkeep = 6           (Barracks 1+1, Factory 2, Research Lab 2)
income available for army = 19
```

At a roster mean upkeep of ~2, that sustains an army of **≈ 8–9 units**, with anything above it
drawing down the bank. The infantry cap at full Alliance build-out is **10**
(`population-cap.md`), so **the cap is the wall and upkeep is what makes you stop just short of
it** — you can always field one or two more than you can comfortably keep.

> **`TARGET_EQUILIBRIUM_ARMY` (7–9 units) is the tuning target, and `UPKEEP_DIVISOR` is the dial
> that moves it.** Tune the divisor to hit the army size, not the other way around — the army size
> is the thing with a felt meaning.

### Disband

```
disband_refund(unit) = floor(produce_cost(unit) × DISBAND_REFUND_RATE)      # rate 0.5
disband_ap_cost      = DISBAND_AP_COST                                      # 1
```

## Edge Cases

- **A unit produced this turn:** pays nothing this turn (UR-3). First charge is next start-of-turn.
- **A structure completing this turn:** pays from this start-of-turn if `COMPLETED` at the moment the
  economy step runs; the ordering is fixed by `game-state-turn-manager.md`'s existing step sequence
  (build progress resolves before the economy step) and must not be reordered.
- **A structure destroyed while under construction:** never paid, nothing to refund.
- **Bank at 0 with a deficit:** bank stays 0 (never negative); produce/build/research are blocked
  (UR-6). Move, attack and disband remain legal.
- **Deficit resolving mid-turn:** the lock is evaluated at the economy step and holds for the whole
  turn, even if the player disbands into solvency. *Rationale: a lock that flickers within a turn is
  unreadable, and re-evaluating it after each action invites a confusing dance around the boundary.*
  The disband still counts — it resolves the deficit for the **next** turn.
- **A player with zero units and zero structures except the HQ:** `total_upkeep = 0`, income is
  fully banked. Correct — a player reduced to their HQ should be recovering income, not taxed.
- **Both players in deficit simultaneously:** legal and independent; each resolves their own.
- **Upkeep exceeding income by more than the bank holds:** the bank floors at 0 and the excess is
  simply not charged — there is no debt ledger. Deliberate: a hidden negative balance is exactly
  the kind of invisible state that makes an economy unreadable.
- **Disband as an exploit:** producing and immediately disbanding at `DISBAND_REFUND_RATE = 0.5`
  loses half the cost and a point of AP, so it is strictly bad as a loop. ★ **But confirm this
  against the AI's scoring** — an agent that mis-values the refund could churn. Covered by AC-14.
- **A faction whose `Δ_upkeep_rate` would drive an entity's upkeep below 0:** floored at 0 at load,
  and load fails if an entity is *authored* negative (schema, not clamp — v2 framework convention).

## Dependencies

**Upstream — hard:**

| System | What is consumed | What is owed |
|---|---|---|
| **AP & Credits Economy** (#3) | `credit_income(player)` — unchanged | Expose gross income so upkeep can be subtracted from it without reaching inside the formula |
| **Game State & Turn Manager** (#2) | The start-of-turn step sequence | **Step 4b changes**: currently adds `credit_income` to the bank; now adds `net_credit_income`. ★ Build progress must resolve **before** the economy step (already true — do not reorder) |
| **Base & Production** (#7) | `build_status`, `produce_cost`, `build_cost` | `upkeep` field on `StructureDef`; the produce/build **deficit lock** (UR-6) |
| **Unit System** (#4) | `produce_cost` | `upkeep` field on `UnitTypeDef` |
| **Research/Tech** (#8) | — | Research is blocked while in deficit (UR-6) |
| **Command & Action Interface** (#9) | — | The **disband** action (UR-7): target validation, AP cost, refund |

**Downstream — hard:**

| System | Impact |
|---|---|
| **Game HUD** (#10) | ★ UR-8: gross / upkeep / net must be visible during the turn, and a prospective purchase's effect on net previewable. **The HUD currently shows a single Credits figure and no income breakdown at all** |
| **AI Opponent** (#11) | ★★ **This is the point of the whole exercise.** The AI must value a unit at its *lifetime* cost, not its purchase price, or it will over-build into deficit exactly as it over-builds today. Its economy scoring is written against a one-time cost model |
| **Faction Identity** (#12) | D9 — factions own their units' upkeep and may delta the global rate |

## Tuning Knobs

| Knob | Default | Safe range | What it affects / what breaks at extremes |
|---|---|---|---|
| `UPKEEP_DIVISOR` | **3** | 2–5 | ★ **The primary dial.** Lower = harsher, smaller armies, faster games. At 2, the equilibrium army drops to ~5 and the board may feel empty. At 5+, upkeep stops biting and the unbounded-stock defect returns |
| `TARGET_EQUILIBRIUM_ARMY` | **7–9 units** | 5–12 | Not a code constant — the *design target* the divisor is tuned to hit. Stated as a knob because it is the number with felt meaning |
| Research Lab `upkeep` | **2** | 1–3 | ★ Load-bearing (UR-5). At 0, "build a Lab, research everything, sit" is free and the accumulation defect returns around a different structure |
| Structure maximums | per faction | see `base-production.md` | ★ **Tuned jointly with this system.** They decide the fixed upkeep floor a player carries before fielding any army at all |
| `DISBAND_REFUND_RATE` | **0.5** | 0.25–0.6 | Above ~0.6 invites produce/disband churn; at 0 disband becomes pure loss and players will not use the escape valve UR-6 depends on |
| `DISBAND_AP_COST` | **1** | 0–2 | At 0 disbanding is free and spammable; at 3+ a player in deficit cannot afford to fix it |
| `Δ_upkeep_rate` (per faction) | 0 | small | Faction lever (D9-mod). Subject to CR-10's baseline comparison |

**Knob interactions:** `UPKEEP_DIVISOR` and the **population cap** (`population-cap.md`) must be
tuned **as a pair** — the cap says how many units you may field, upkeep says how many you can
afford. If the cap sits below the upkeep equilibrium, upkeep is inert and the cap is doing all the
work; if far above, the cap is decorative. **OQ-13 in `faction-identity.md` owns this.**

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a player with entities whose upkeep sums to `U` and gross income `I`, WHEN their start-of-turn economy step runs, THEN banked Credits increase by exactly `I − U` | Logic |
| AC-2 | GIVEN `U > I` and a bank of `B ≥ U − I`, WHEN the economy step runs, THEN the bank decreases by exactly `U − I` and never below 0 | Logic |
| AC-3 | GIVEN `U > I` and a bank of 0, WHEN the economy step runs, THEN the bank remains exactly 0 — never negative, and no debt is recorded anywhere in state | Logic |
| AC-4 | GIVEN a unit produced on turn `T`, THEN it contributes 0 upkeep at turn `T`'s economy step and its full upkeep at turn `T+1`'s | Logic |
| AC-5 | GIVEN a structure with `build_status != COMPLETED`, THEN it contributes 0 upkeep | Logic |
| AC-6 | GIVEN a structure completing during turn `T`'s build step, THEN it contributes its upkeep at turn `T`'s economy step (build resolves before economy) | Integration |
| AC-7 | GIVEN a destroyed entity, THEN it contributes 0 upkeep from that moment, including the same turn it died | Logic |
| AC-8 | GIVEN any player state, THEN the HQ contributes exactly 0 upkeep | Logic |
| AC-9 | GIVEN a player in deficit (bank 0, `U > I`), WHEN they attempt to produce, build or research, THEN each is rejected with a reason naming the deficit | Integration |
| AC-10 | GIVEN a player in deficit, WHEN they attempt to move, attack or disband, THEN each is permitted | Integration |
| AC-11 | GIVEN a player in deficit who disbands into solvency mid-turn, THEN produce/build/research remain locked for the remainder of that turn and are available the next turn | Integration |
| AC-12 | GIVEN a unit with `produce_cost = P`, WHEN disbanded, THEN the unit is removed, the owner gains `floor(P × 0.5)` Credits and spends `DISBAND_AP_COST` AP | Logic |
| AC-13 | GIVEN a disband targeting an enemy unit, a structure, or the HQ, THEN it is rejected | Logic |
| AC-14 | ★ GIVEN an AI-controlled player with ample Credits across a full simulated match, THEN it does not produce-and-disband the same unit type more than twice in any 10-turn window (anti-churn regression on the refund rate) | Integration |
| AC-15 | **[REWRITTEN 2026-08-24 — the outpost curve it tested no longer exists]** GIVEN a player holding all three economy tiers, THEN `credit_income` is exactly **25** and no further action of any kind increases it (the hard ceiling holds) | Logic |
| AC-16 | GIVEN any entity definition loaded from data, THEN `upkeep ≥ 0`, and a negative authored value fails load with an error naming the entity | Config-Data |
| AC-17 | GIVEN an entity with no explicit `upkeep`, THEN its effective upkeep equals `ceil(produce_cost / UPKEEP_DIVISOR)` | Logic |
| AC-18 | ★ GIVEN the AI-vs-AI simulation batch run with upkeep active, THEN peak banked Credits on any side stays below **150** across a full match (was 5,724 — this is the regression that proves the PIVOT's root cause is fixed) | Integration |
| AC-19 | GIVEN a player's turn, THEN the HUD displays gross income, total upkeep and net income as three distinct readable figures before the next economy step | UI (advisory) |
| AC-20 | GIVEN a player considering a purchase, THEN the resulting change to net income is previewable before commit | UI (advisory) |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| UOQ-1 | ★★ **Is the deficit rule right?** UR-6 chooses *bank drains → floor at 0 → production locked*, over the two alternatives: (a) attrition damage to units, which is more dramatic but risks a death spiral and directly undercuts the comeback pressure this system exists to create; (b) income simply floors at 0 with no lock, which is gentler but removes the pressure entirely. **Design call — the user's.** | user | Before implementation |
| UOQ-2 | **Should structures under construction pay?** UR-3 says no, reasoning that `build_time` is already a deliberate vulnerability window. Charging would make expansion meaningfully riskier and slow the game further — arguably desirable given the PIVOT | systems-designer | With playtest |
| UOQ-3 | **Does upkeep scale with unit damage/veterancy?** A promoted unit (`promotion-veterancy.md`) is worth more — should it cost more to keep? Interacts directly with the Holy Cosmic Empire's thesis that *"losses are more impactful"* | systems-designer | With `promotion-veterancy.md` |
| UOQ-4 | ★ **The AI needs a lifetime-cost model, not a purchase-price one.** It currently scores a unit at `produce_cost`. Under upkeep, a Heavy at 7 Credits with upkeep 3 costs 7 + 3×(remaining turns) — a completely different number. Without this the AI will over-build into deficit exactly as it over-builds today, and the PIVOT fix will not show in AI-vs-AI results | ai-programmer | Sprint 6, alongside implementation |
| UOQ-5 | **Is `net_credit_income` the right HUD primitive, or should gross and upkeep be equally prominent?** UR-8 requires all three; their relative weight is a UX call | ux-designer | `/ux-design` HUD pass |
